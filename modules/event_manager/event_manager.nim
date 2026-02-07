## Event Manager - Refactored in Forth Style
##
## Clean, readable, composable event processing
## Each function does ONE thing clearly

import ../../core/types
import ./event_manager_helpers
import std/[heapqueue, monotimes, times, tables]

# ============================================================================
# Event Manager Type
# ============================================================================

type
  EventManager* = ref object
    configs: Table[EventKind, EventConfig]
    queue: HeapQueue[GuiEvent]
    lastEvents: Table[EventKind, GuiEvent]
    sequences: Table[EventKind, EventSequence]
    throttleLastTime: Table[EventKind, MonoTime]
    timings*: Table[EventKind, EventTiming]
    currentBudget*: Duration
    defaultBudget*: Duration

# ============================================================================
# Initialization
# ============================================================================

proc initEventTables*(): tuple[
  configs: Table[EventKind, EventConfig],
  lastEvents: Table[EventKind, GuiEvent],
  sequences: Table[EventKind, EventSequence],
  throttleTimes: Table[EventKind, MonoTime],
  timings: Table[EventKind, EventTiming]
] =
  ## Initialize all event manager tables
  (
    initTable[EventKind, EventConfig](),
    initTable[EventKind, GuiEvent](),
    initTable[EventKind, EventSequence](),
    initTable[EventKind, MonoTime](),
    initTable[EventKind, EventTiming]()
  )

proc newEventManager*(defaultBudget = initDuration(milliseconds = 8)): EventManager =
  ## Create a new EventManager with default configuration
  let tables = initEventTables()

  EventManager(
    configs: tables.configs,
    queue: initHeapQueue[GuiEvent](),
    lastEvents: tables.lastEvents,
    sequences: tables.sequences,
    throttleLastTime: tables.throttleTimes,
    timings: tables.timings,
    currentBudget: defaultBudget,
    defaultBudget: defaultBudget
  )

proc setEventConfig*(em: EventManager, kind: EventKind, config: EventConfig) =
  ## Override default configuration for an event type
  em.configs[kind] = config

# ============================================================================
# Event Pattern Routing
# ============================================================================

proc getConfig*(em: EventManager, kind: EventKind): EventConfig =
  ## Get configuration for event kind (with fallback)
  em.configs.getOrDefault(kind, getDefaultConfig(kind))

proc addNormalEvent*(em: EventManager, event: GuiEvent) =
  ## Add event directly to queue (normal pattern)
  em.queue.push(event)

proc addReplaceableEvent*(em: EventManager, event: GuiEvent) =
  ## Cache event for later (replaceable pattern)
  em.lastEvents[event.kind] = event

proc addDebouncedEvent*(em: EventManager, event: GuiEvent) =
  ## Add event to debounce sequence
  var seq = em.sequences.getOrDefault(event.kind, initSequence())
  addToSequence(seq, event)
  em.sequences[event.kind] = seq

proc addBatchedEvent*(em: EventManager, event: GuiEvent, config: EventConfig) =
  ## Add event to batch sequence
  var seq = em.sequences.getOrDefault(event.kind, initSequence())
  addToSequence(seq, event)
  em.sequences[event.kind] = seq

  # Process batch immediately if size reached
  if shouldProcessBatchImmediately(seq, config):
    for ev in seq.events:
      em.queue.push(ev)
    em.sequences.del(event.kind)

proc addThrottledEvent*(em: EventManager, event: GuiEvent, config: EventConfig) =
  ## Add event if throttle interval has passed
  let lastTime = em.throttleLastTime.getOrDefault(event.kind, MonoTime())

  if hasThrottleIntervalPassed(lastTime, config.throttleInterval):
    em.queue.push(event)
    em.throttleLastTime[event.kind] = getCurrentTime()

proc addOrderedEvent*(em: EventManager, event: GuiEvent) =
  ## Add event directly to preserve order (critical for keyboard/clicks)
  em.queue.push(event)

# ============================================================================
# Event Collection - Main Entry Point
# ============================================================================

proc routeEvent*(em: EventManager, event: GuiEvent, config: EventConfig) =
  ## Route event based on pattern
  if shouldAddToQueue(config.pattern):
    addNormalEvent(em, event)
  elif shouldReplaceInCache(config.pattern):
    addReplaceableEvent(em, event)
  elif shouldThrottle(config.pattern):
    addThrottledEvent(em, event, config)
  elif shouldAddToSequence(config.pattern):
    if isDebouncedPattern(config.pattern):
      addDebouncedEvent(em, event)
    elif isBatchedPattern(config.pattern):
      addBatchedEvent(em, event, config)
    elif isOrderedPattern(config.pattern):
      addOrderedEvent(em, event)

proc addEvent*(em: EventManager, event: GuiEvent) =
  ## Add an event to the manager (applies coalescing based on pattern)
  let config = getConfig(em, event.kind)
  routeEvent(em, event, config)

# ============================================================================
# Replaceable Events Processing
# ============================================================================

proc flushReplaceableEvents*(em: EventManager) =
  ## Move replaceable events to queue
  for kind, event in em.lastEvents:
    em.queue.push(event)
  em.lastEvents.clear()

# ============================================================================
# Sequence Processing - Helpers
# ============================================================================

proc flushSequenceEvents*(em: EventManager, seq: EventSequence) =
  ## Add all events from sequence to queue
  for event in seq.events:
    em.queue.push(event)

proc flushLastEvent*(em: EventManager, seq: EventSequence) =
  ## Add only last event from sequence to queue
  if hasEvents(seq):
    em.queue.push(getLastEvent(seq))

# ============================================================================
# Sequence Processing - Pattern-Specific
# ============================================================================

proc processDebounced*(em: EventManager, kind: EventKind, seq: EventSequence,
                      config: EventConfig): bool =
  ## Process debounced sequence if ready
  if shouldProcessDebounced(seq, config):
    flushLastEvent(em, seq)
    return true
  false

proc processBatched*(em: EventManager, kind: EventKind, seq: EventSequence,
                    config: EventConfig): bool =
  ## Process batched sequence if ready
  if shouldProcessBatch(seq, config):
    flushSequenceEvents(em, seq)
    return true
  false

proc processOrdered*(em: EventManager, kind: EventKind, seq: EventSequence,
                    config: EventConfig): bool =
  ## Process ordered sequence if timed out
  if shouldProcessOrdered(seq, config):
    flushSequenceEvents(em, seq)
    return true
  false

# ============================================================================
# Sequence Update - Main Logic
# ============================================================================

proc updateSequence*(em: EventManager, kind: EventKind, seq: EventSequence): bool =
  ## Update one sequence, return true if processed
  let config = getConfig(em, kind)

  case config.pattern
  of epDebounced:
    processDebounced(em, kind, seq, config)
  of epBatched:
    processBatched(em, kind, seq, config)
  of epOrdered:
    processOrdered(em, kind, seq, config)
  else:
    false

proc collectProcessedSequences*(em: EventManager): seq[EventKind] =
  ## Find and process all ready sequences
  result = @[]
  for kind, seq in em.sequences:
    if updateSequence(em, kind, seq):
      result.add(kind)

proc removeProcessedSequences*(em: EventManager, toDelete: seq[EventKind]) =
  ## Remove sequences that were processed
  for kind in toDelete:
    em.sequences.del(kind)

proc updateSequences*(em: EventManager) =
  ## Process all pending sequences
  let toDelete = collectProcessedSequences(em)
  removeProcessedSequences(em, toDelete)

# ============================================================================
# Frame Update
# ============================================================================

proc update*(em: EventManager) =
  ## Process pattern-based events (called once per frame)
  flushReplaceableEvents(em)
  updateSequences(em)

# ============================================================================
# Event Processing - Single Event
# ============================================================================

proc peekEvent*(em: EventManager): GuiEvent =
  ## Look at next event without removing
  em.queue[0]

proc popEvent*(em: EventManager): GuiEvent =
  ## Remove and return next event
  em.queue.pop()

proc processOneEvent*(em: EventManager,
                     handler: proc(event: GuiEvent),
                     startTime: MonoTime): Duration =
  ## Process single event and return duration
  let event = popEvent(em)
  let eventStart = getCurrentTime()

  handler(event)

  let duration = measureEventDuration(eventStart)
  recordEventTime(em.timings, event.kind, duration)

  duration

# ============================================================================
# Budget Checking
# ============================================================================

proc canProcessEvent*(em: EventManager, timeSpent, budget: Duration, processedAny: bool): bool =
  ## Check if we can process another event
  if em.queue.len == 0:
    return false

  let event = peekEvent(em)
  let defaultEstimate = initDuration(milliseconds = 1)
  let estimatedTime = getEstimatedTime(em.timings, event.kind, defaultEstimate)

  not wouldExceedBudget(timeSpent, estimatedTime, budget, processedAny)

# ============================================================================
# Time-Budgeted Processing
# ============================================================================

proc processEventsWithBudget*(em: EventManager,
                              budget: Duration,
                              handler: proc(event: GuiEvent)): tuple[count: int, timeSpent: Duration] =
  ## Process events within time budget
  var count = 0
  var timeSpent = initDuration()

  while canProcessEvent(em, timeSpent, budget, count > 0):
    let eventDuration = processOneEvent(em, handler, getCurrentTime())
    timeSpent = timeSpent + eventDuration
    inc count

  (count, timeSpent)

proc processEvents*(em: EventManager,
                   budget: Duration,
                   handler: proc(event: GuiEvent)): int {.discardable.} =
  ## Process events from queue with time budget (returns count)
  let (count, _) = processEventsWithBudget(em, budget, handler)
  count

# ============================================================================
# Status Queries
# ============================================================================

proc queueLength*(em: EventManager): int =
  ## Get number of events in queue
  em.queue.len

proc hasPendingEvents*(em: EventManager): bool =
  ## Check if there are events pending
  em.queue.len > 0 or
  em.lastEvents.len > 0 or
  em.sequences.len > 0

# ============================================================================
# Statistics
# ============================================================================

proc formatTimingLine*(kind: EventKind, timing: EventTiming): string =
  ## Format one line of timing stats
  "  " & $kind & ": " &
  "count=" & $timing.count & ", " &
  "avg=" & $timing.avgTime.inMilliseconds & "ms, " &
  "max=" & $timing.maxTime.inMilliseconds & "ms\n"

proc getStats*(em: EventManager): string =
  ## Get event processing statistics
  result = "Event Manager Stats:\n"
  result &= "  Queue length: " & $em.queue.len & "\n"
  result &= "  Replaceable pending: " & $em.lastEvents.len & "\n"
  result &= "  Sequences pending: " & $em.sequences.len & "\n"
  result &= "  Current budget: " & $em.currentBudget.inMilliseconds & "ms\n"
  result &= "\nTiming stats:\n"

  for kind, timing in em.timings:
    result &= formatTimingLine(kind, timing)
