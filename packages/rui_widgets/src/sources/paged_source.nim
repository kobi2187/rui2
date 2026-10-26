## PagedSource: a RowSource over a file or database, read in the background.
##
## The UI thread never reads data. It keeps a small cache of pages (256 rows
## each, stored by column) and, when the list says which rows are about to be
## drawn, asks the worker for any page it does not have. Rows whose page has not
## arrived are `rsPending` and draw as placeholders; when the page lands, `poll`
## (run every frame by the App) puts it in the cache, tells the listeners, and
## the rows repaint with their text. Counting a big file also happens in the
## background, in slices, so the row count grows while it is being scanned.
##
## One worker thread per source owns the reader (its file mapping or its SQLite
## connection -- connections cannot cross threads). Jobs and results travel as
## plain values over channels. `mode = smInline` runs the same reader on the
## calling thread, finishing the count at once and reading pages when asked: for
## tests and tiny data, and the reason the reading code needs no threads.

import std/[tables, sets, os]
import rui_core
import column_page, row_source, readers

{.push warning[Deprecated]: off.}

const
  PageSize* = 256
  CountSlice = 32 * 1024 * 1024      ## bytes scanned per counting step
  DefaultCachePages = 96

type
  SourceMode* = enum smThread, smInline

  JobKind = enum jkPage, jkConfigure, jkStop
  Job = object
    kind: JobKind
    pageNo: int
    generation: int
    spec: ReaderSpec

  ResultKind = enum rkOpened, rkCount, rkPage, rkConfigured, rkError
  Result = object
    kind: ResultKind
    generation: int
    pageNo: int
    count: int
    done: bool
    columns: seq[string]
    page: ColumnPage
    error: string

  WorkerCtx = object
    spec: ReaderSpec
    jobs: ptr Channel[Job]
    results: ptr Channel[Result]

  PagedSource* = ref object of RowSource
    spec: ReaderSpec
    mode: SourceMode
    names: seq[string]
    total: int
    counting: bool
    opened*: bool
    error*: string
    generation: int
    cache: Table[int, ColumnPage]
    lru: seq[int]
    requested: HashSet[int]
    maxPages: int
    thread: ptr Thread[WorkerCtx]
    jobs: ptr Channel[Job]
    results: ptr Channel[Result]
    inline: Reader
    notes: seq[SeqChange]            ## inline mode: changes waiting for poll

proc workerMain(ctx: WorkerCtx) {.thread.} =
  var reader: Reader
  proc wake() = {.cast(gcsafe).}: wakeMain()
  try:
    reader = newReader(ctx.spec)
    let cols = reader.open()
    ctx.results[].send Result(kind: rkOpened, columns: cols)
  except CatchableError as e:
    ctx.results[].send Result(kind: rkError, error: e.msg)
    wake()
    return
  var counting = true
  var counted = 0
  var generation = 0
  var waiting: seq[Job]            # pages past what is counted so far: read once it is
  proc readOne(job: Job) =
    try:
      let page = reader.readPage(job.pageNo, PageSize)
      ctx.results[].send Result(kind: rkPage, pageNo: job.pageNo,
                                generation: job.generation, page: page)
    except CatchableError as e:
      ctx.results[].send Result(kind: rkError, error: e.msg)
  while true:
    var job: Job
    var have = false
    if counting:
      let polled = ctx.jobs[].tryRecv()
      have = polled.dataAvailable
      if have: job = polled.msg
    else:
      job = ctx.jobs[].recv()
      have = true
    if have:
      case job.kind
      of jkStop:
        break
      of jkPage:
        # A page the count has not reached yet would come back short (or
        # empty) and be kept as if whole: hold it until the count passes it.
        if counting and (job.pageNo + 1) * PageSize > counted: waiting.add job
        else: readOne(job)
      of jkConfigure:
        generation = job.generation
        try:
          let n = reader.configure(job.spec)
          counted = n
          ctx.results[].send Result(kind: rkConfigured, generation: generation, count: n)
        except CatchableError as e:
          ctx.results[].send Result(kind: rkError, error: e.msg)
      wake()
    else:
      let step = reader.countStep(CountSlice)
      counted = step.count
      ctx.results[].send Result(kind: rkCount, count: step.count, done: step.done)
      if step.done: counting = false
      var still: seq[Job]
      for j in waiting:
        if counting and (j.pageNo + 1) * PageSize > counted: still.add j
        else: readOne(j)
      waiting = still
      wake()
  reader.close()

proc touch(s: PagedSource, pageNo: int) =
  let i = s.lru.find(pageNo)
  if i >= 0: s.lru.delete(i)
  s.lru.add pageNo

proc store(s: PagedSource, pageNo: int, page: ColumnPage) =
  s.cache[pageNo] = page
  s.touch pageNo
  while s.lru.len > s.maxPages:
    s.cache.del s.lru[0]
    s.lru.delete(0)

proc newPagedSource*(spec: ReaderSpec, mode = smThread,
                     cachePages = DefaultCachePages): PagedSource =
  result = PagedSource(spec: spec, mode: mode, maxPages: cachePages,
                       cache: initTable[int, ColumnPage](), requested: initHashSet[int](),
                       counting: true)
  if mode == smInline:
    result.inline = newReader(spec)
    result.names = result.inline.open()
    var step = result.inline.countStep(high(int) div 2)
    while not step.done: step = result.inline.countStep(high(int) div 2)
    result.total = step.count
    result.counting = false
    result.opened = true
  else:
    result.jobs = createShared(Channel[Job])
    result.results = createShared(Channel[Result])
    result.jobs[].open()
    result.results[].open()
    result.thread = createShared(Thread[WorkerCtx])
    createThread(result.thread[], workerMain,
                 WorkerCtx(spec: spec, jobs: result.jobs, results: result.results))

method count*(s: PagedSource): int = s.total
method columns*(s: PagedSource): seq[string] = (if s.names.len > 0: s.names else: @["value"])
method busy*(s: PagedSource): bool = s.counting or s.requested.len > 0

method cell*(s: PagedSource, row, col: int): string =
  if row < 0 or row >= s.total: return ""
  let pageNo = row div PageSize
  if pageNo notin s.cache: return ""
  s.touch pageNo
  s.cache[pageNo].cell(row - pageNo * PageSize, col)

method rowState*(s: PagedSource, row: int): RowState =
  if row div PageSize in s.cache: rsReady else: rsPending

proc request(s: PagedSource, pageNo: int) =
  if pageNo < 0 or pageNo * PageSize >= max(s.total, 1) and not s.counting: return
  if pageNo in s.cache or pageNo in s.requested: return
  if s.mode == smInline:
    s.store(pageNo, s.inline.readPage(pageNo, PageSize))
    s.notes.add SeqChange(kind: scReplace, index: pageNo * PageSize, count: PageSize)
  else:
    s.requested.incl pageNo
    s.jobs[].send Job(kind: jkPage, pageNo: pageNo, generation: s.generation)

method want*(s: PagedSource, first, last: int) =
  ## The rows about to be drawn, and a page either side of them.
  if s.total == 0 and not s.counting: return
  let a = max(0, first div PageSize - 1)
  let b = last div PageSize + 1
  for p in countup(first div PageSize, last div PageSize): s.request p
  s.request a
  s.request b

method poll*(s: PagedSource): bool =
  if s.mode == smInline:
    for note in s.notes:
      s.notify note
      result = true
    s.notes.setLen(0)
    return
  if s.thread == nil: return       # closed: its queues are gone
  while true:
    let got = s.results[].tryRecv()
    if not got.dataAvailable: break
    let r = got.msg
    case r.kind
    of rkOpened:
      s.names = r.columns
      s.opened = true
      result = true
      s.notify SeqChange(kind: scReset)
    of rkCount:
      if r.count > s.total:
        let old = s.total
        s.total = r.count
        s.notify SeqChange(kind: scInsert, index: old, count: r.count - old)
        result = true
      if r.done: s.counting = false
    of rkPage:
      s.requested.excl r.pageNo
      if r.generation == s.generation:
        s.store(r.pageNo, r.page)
        s.notify SeqChange(kind: scReplace, index: r.pageNo * PageSize, count: r.page.rowCount)
        result = true
    of rkConfigured:
      if r.generation == s.generation:
        s.total = r.count
        s.counting = false
        s.cache.clear()
        s.lru.setLen(0)
        s.requested.clear()
        s.notify SeqChange(kind: scReset)
        result = true
    of rkError:
      s.error = r.error
      s.counting = false
      result = true

method canSort*(s: PagedSource): bool = s.spec.kind == skSqlite
method canFilter*(s: PagedSource): bool = s.spec.kind == skSqlite

proc reconfigure(s: PagedSource) =
  inc s.generation
  s.cache.clear()
  s.lru.setLen(0)
  s.requested.clear()
  if s.mode == smInline:
    s.total = s.inline.configure(s.spec)
    s.notify SeqChange(kind: scReset)
  else:
    s.jobs[].send Job(kind: jkConfigure, generation: s.generation, spec: s.spec)

method sortBy*(s: PagedSource, column: string, dir: SortDir) =
  if not s.canSort: return
  s.spec.sortColumn = column
  s.spec.sortDir = dir
  s.reconfigure()

method setFilters*(s: PagedSource, filters: seq[ColumnFilter]) =
  if not s.canFilter: return
  s.spec.filters = filters
  s.reconfigure()

method close*(s: PagedSource) =
  s.stopPolling()                  # nothing left to poll once the worker goes
  if s.mode == smInline:
    if s.inline != nil:
      s.inline.close()
      s.inline = nil
    return
  if s.thread == nil: return
  s.jobs[].send Job(kind: jkStop)
  joinThread(s.thread[])
  s.jobs[].close()
  s.results[].close()
  deallocShared(s.thread)
  deallocShared(s.jobs)
  deallocShared(s.results)
  s.thread = nil

proc newLinesSource*(path: string, mode = smThread): PagedSource =
  ## Every line of a text file as a row. Opens instantly and counts in the
  ## background; lines are read as they are drawn.
  newPagedSource(ReaderSpec(kind: skLines, path: path), mode)

proc newDelimitedSource*(path: string, delimiter = ',', header = true,
                         mode = smThread): PagedSource =
  ## A CSV (`,`) or TSV (`\t`) file: one record per row, quoted fields and
  ## embedded newlines included. With `header` the first record names the columns.
  newPagedSource(ReaderSpec(kind: skDelimited, path: path, delimiter: delimiter,
                            header: header), mode)

proc newSqliteSource*(path: string, tableOrQuery: string, mode = smThread): PagedSource =
  ## A SQLite table, or any SELECT. Sorting and filtering are done by the database.
  newPagedSource(ReaderSpec(kind: skSqlite, path: path, query: tableOrQuery), mode)

proc waitIdle*(s: PagedSource, timeoutMs = 5000): bool =
  ## Poll until nothing is being counted or fetched (tests, tools). False on timeout.
  var waited = 0
  while waited <= timeoutMs:
    discard s.poll()
    if s.opened and not s.busy: return true
    sleep 5
    waited += 5
  false

{.pop.}
