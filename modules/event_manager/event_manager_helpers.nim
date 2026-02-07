## Event Manager Helpers - Forth Style
##
## Small, composable functions for event processing
## Each function does ONE thing clearly

import ../../core/types
import std/[monotimes, times, tables]

# ============================================================================
# Predicates - Time Checks
# ============================================================================

proc hasElapsed*(since: MonoTime, duration: Duration): bool =
  ## Check if duration has elapsed since time
  let now = getMonoTime()
  (now - since) >= duration

proc isDefaultMonoTime*(time: MonoTime): bool =
  ## Check if MonoTime is uninitialized
  time == default(MonoTime)

proc hasThrottleIntervalPassed*(lastTime: MonoTime, interval: Duration): bool =
  ## Check if throttle interval has passed
  isDefaultMonoTime(lastTime) or hasElapsed(lastTime, interval)

# ============================================================================
# Predicates - Pattern Checks
# ============================================================================

proc isNormalPattern*(pattern: EventPattern): bool =
  ## Check if pattern is normal (no coalescing)
  pattern == epNormal

proc isReplaceablePattern*(pattern: EventPattern): bool =
  ## Check if pattern is replaceable
  pattern == epReplaceable

proc isDebouncedPattern*(pattern: EventPattern): bool =
  ## Check if pattern is debounced
  pattern == epDebounced

proc isThrottledPattern*(pattern: EventPattern): bool =
  ## Check if pattern is throttled
  pattern == epThrottled

proc isBatchedPattern*(pattern: EventPattern): bool =
  ## Check if pattern is batched
  pattern == epBatched

proc isOrderedPattern*(pattern: EventPattern): bool =
  ## Check if pattern is ordered
  pattern == epOrdered

# ============================================================================
# Predicates - Sequence State
# ============================================================================

proc isQuietPeriod*(seq: EventSequence, debounceTime: Duration): bool =
  ## Check if debounce quiet period has passed
  hasElapsed(seq.lastEventTime, debounceTime)

proc hasMaxTimeExceeded*(seq: EventSequence, maxTime: Duration): bool =
  ## Check if max sequence time exceeded
  hasElapsed(seq.startTime, maxTime)

proc isBatchSizeReached*(seq: EventSequence, batchSize: int): bool =
  ## Check if batch has reached target size
  seq.events.len >= batchSize

# ============================================================================
# Queries - Sequence Access
# ============================================================================

proc getLastEvent*(seq: EventSequence): GuiEvent =
  ## Get last event from sequence
  seq.events[^1]

proc hasEvents*(seq: EventSequence): bool =
  ## Check if sequence has any events
  seq.events.len > 0

proc getEventCount*(seq: EventSequence): int =
  ## Get number of events in sequence
  seq.events.len

# ============================================================================
# Actions - Sequence Modification
# ============================================================================

proc initSequence*(): EventSequence =
  ## Create new empty event sequence
  EventSequence(
    events: @[],
    startTime: default(MonoTime),
    lastEventTime: default(MonoTime)
  )

proc addToSequence*(seq: var EventSequence, event: GuiEvent) =
  ## Add event to sequence
  seq.events.add(event)
  seq.lastEventTime = getMonoTime()
  if isDefaultMonoTime(seq.startTime):
    seq.startTime = getMonoTime()

proc clearSequence*(seq: var EventSequence) =
  ## Clear sequence events
  seq.events = @[]
  seq.startTime = default(MonoTime)
  seq.lastEventTime = default(MonoTime)

# ============================================================================
# Actions - Timing Statistics
# ============================================================================

proc initTiming*(): EventTiming =
  ## Create new timing entry
  EventTiming(
    count: 0,
    totalTime: initDuration(),
    avgTime: initDuration(),
    maxTime: initDuration()
  )

proc updateTiming*(timing: var EventTiming, eventDuration: Duration) =
  ## Update timing statistics with new measurement
  timing.count += 1
  timing.totalTime = timing.totalTime + eventDuration
  timing.avgTime = timing.totalTime div timing.count
  timing.maxTime = max(timing.maxTime, eventDuration)

proc recordEventTime*(timings: var Table[EventKind, EventTiming],
                     kind: EventKind, duration: Duration) =
  ## Record timing for event kind
  var timing = timings.getOrDefault(kind, initTiming())
  updateTiming(timing, duration)
  timings[kind] = timing

# ============================================================================
# Queries - Time Estimation
# ============================================================================

proc getEstimatedTime*(timings: Table[EventKind, EventTiming],
                      kind: EventKind, default: Duration): Duration =
  ## Get estimated processing time for event kind
  if kind in timings:
    timings[kind].avgTime
  else:
    default

proc wouldExceedBudget*(timeSpent, estimatedTime, budget: Duration, processedAny: bool): bool =
  ## Check if processing would exceed budget
  processedAny and (timeSpent + estimatedTime) > budget

# ============================================================================
# Event Pattern Routing - Predicates
# ============================================================================

proc shouldAddToQueue*(pattern: EventPattern): bool =
  ## Check if event should be added directly to queue
  isNormalPattern(pattern) or isOrderedPattern(pattern)

proc shouldReplaceInCache*(pattern: EventPattern): bool =
  ## Check if event should replace cached event
  isReplaceablePattern(pattern)

proc shouldAddToSequence*(pattern: EventPattern): bool =
  ## Check if event should be added to sequence
  isDebouncedPattern(pattern) or isBatchedPattern(pattern)

proc shouldThrottle*(pattern: EventPattern): bool =
  ## Check if event should be throttled
  isThrottledPattern(pattern)

# ============================================================================
# Sequence Processing - Debounced
# ============================================================================

proc shouldProcessDebounced*(seq: EventSequence, config: EventConfig): bool =
  ## Check if debounced sequence should be processed
  isQuietPeriod(seq, config.debounceTime)

proc getDebounceEvent*(seq: EventSequence): GuiEvent =
  ## Get event to process from debounced sequence (last only)
  if hasEvents(seq):
    getLastEvent(seq)
  else:
    default(GuiEvent)

# ============================================================================
# Sequence Processing - Batched
# ============================================================================

proc shouldProcessBatch*(seq: EventSequence, config: EventConfig): bool =
  ## Check if batch should be processed
  hasMaxTimeExceeded(seq, config.maxSequenceTime)

proc shouldProcessBatchImmediately*(seq: EventSequence, config: EventConfig): bool =
  ## Check if batch should be processed immediately
  isBatchSizeReached(seq, config.batchSize)

# ============================================================================
# Sequence Processing - Ordered
# ============================================================================

proc shouldProcessOrdered*(seq: EventSequence, config: EventConfig): bool =
  ## Check if ordered sequence has timed out
  hasMaxTimeExceeded(seq, config.maxSequenceTime)

# ============================================================================
# Default Configurations
# ============================================================================

proc getDefaultConfig*(kind: EventKind): EventConfig =
  ## Get default configuration for event kind
  const defaults = {
    evMouseMove: EventConfig(pattern: epReplaceable),
    evMouseHover: EventConfig(pattern: epReplaceable),
    evMouseDown: EventConfig(
      pattern: epOrdered,
      maxSequenceTime: initDuration(milliseconds = 500)
    ),
    evMouseUp: EventConfig(
      pattern: epOrdered,
      maxSequenceTime: initDuration(milliseconds = 500)
    ),
    evKeyDown: EventConfig(
      pattern: epOrdered,
      maxSequenceTime: initDuration(milliseconds = 500)
    ),
    evKeyUp: EventConfig(
      pattern: epOrdered,
      maxSequenceTime: initDuration(milliseconds = 500)
    ),
    evChar: EventConfig(
      pattern: epOrdered,
      maxSequenceTime: initDuration(milliseconds = 500)
    ),
    evWindowResize: EventConfig(
      pattern: epDebounced,
      debounceTime: initDuration(milliseconds = 350)
    ),
    evMouseWheel: EventConfig(
      pattern: epThrottled,
      throttleInterval: initDuration(milliseconds = 50)
    ),
    evTouchMove: EventConfig(
      pattern: epBatched,
      batchSize: 5,
      maxSequenceTime: initDuration(milliseconds = 100)
    )
  }.toTable

  defaults.getOrDefault(kind, EventConfig(pattern: epNormal))

# ============================================================================
# Timing Measurement
# ============================================================================

proc measureEventDuration*(startTime: MonoTime): Duration =
  ## Calculate duration since start time
  getMonoTime() - startTime

proc getCurrentTime*(): MonoTime =
  ## Get current monotonic time
  getMonoTime()

# ============================================================================
# Budget Management
# ============================================================================

proc hasRemainingBudget*(timeSpent, budget: Duration): bool =
  ## Check if there's budget remaining
  timeSpent < budget

proc calcRemainingBudget*(timeSpent, budget: Duration): Duration =
  ## Calculate remaining budget
  budget - timeSpent
