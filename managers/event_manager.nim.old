## Event Manager for RUI
##
## Handles pattern-based event coalescing and priority queue processing
## with time-budgeted execution.
##
## Key features:
## - Pattern-based coalescing (replaceable, debounced, throttled, batched, ordered)
## - Priority queue with FIFO ordering within same priority
## - Time-budgeted processing to maintain 60 FPS
## - Historical timing statistics for adaptive budget allocation
## - Order preservation for critical events (keyboard, clicks)

import ../core/types
import std/[heapqueue, monotimes, times]

# ============================================================================
# Event Configuration
# ============================================================================

type
  EventConfig* = object
    pattern*: EventPattern
    debounceTime*: Duration        # For epDebounced
    throttleInterval*: Duration    # For epThrottled
    batchSize*: int                # For epBatched
    maxSequenceTime*: Duration     # For epBatched, epOrdered

  EventSequence = object
    events: seq[GuiEvent]
    startTime: MonoTime
    lastEventTime: MonoTime

# Default configurations for different event types
const DefaultEventConfigs* = {
  # Mouse events - replaceable (only last matters)
  evMouseMove: EventConfig(
    pattern: epReplaceable
  ),
  evMouseHover: EventConfig(
    pattern: epReplaceable
  ),

  # Mouse actions - ordered (sequence matters)
  evMouseDown: EventConfig(
    pattern: epOrdered,
    maxSequenceTime: initDuration(milliseconds = 500)
  ),
  evMouseUp: EventConfig(
    pattern: epOrdered,
    maxSequenceTime: initDuration(milliseconds = 500)
  ),

  # Keyboard - ordered (CRITICAL: text input requires exact sequence)
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

  # Window events - debounced (wait for quiet period)
  evWindowResize: EventConfig(
    pattern: epDebounced,
    debounceTime: initDuration(milliseconds = 350)
  ),

  # Scroll - throttled (rate limited)
  evMouseWheel: EventConfig(
    pattern: epThrottled,
    throttleInterval: initDuration(milliseconds = 50)
  ),

  # Touch - batched (for gesture recognition)
  evTouchMove: EventConfig(
    pattern: epBatched,
    batchSize: 5,
    maxSequenceTime: initDuration(milliseconds = 100)
  ),
}.toTable

# ============================================================================
# Event Manager
# ============================================================================

type
  EventManager* = ref object
    # Configuration
    configs: Table[EventKind, EventConfig]

    # Priority queue for time-budgeted processing
    queue: HeapQueue[GuiEvent]

    # Pattern-specific collections
    lastEvents: Table[EventKind, GuiEvent]          # For epReplaceable
    sequences: Table[EventKind, EventSequence]      # For epDebounced, epBatched, epOrdered
    throttleLastTime: Table[EventKind, MonoTime]    # For epThrottled

    # Timing statistics
    timings*: Table[EventKind, EventTiming]

    # Budget management
    currentBudget*: Duration
    defaultBudget*: Duration

# ============================================================================
# Initialization
# ============================================================================

proc newEventManager*(defaultBudget = initDuration(milliseconds = 8)): EventManager =
  ## Create a new EventManager with default configuration
  result = EventManager(
    configs: DefaultEventConfigs,
    queue: initHeapQueue[GuiEvent](),
    lastEvents: initTable[EventKind, GuiEvent](),
    sequences: initTable[EventKind, EventSequence](),
    throttleLastTime: initTable[EventKind, MonoTime](),
    timings: initTable[EventKind, EventTiming](),
    currentBudget: defaultBudget,
    defaultBudget: defaultBudget
  )

proc setEventConfig*(em: EventManager, kind: EventKind, config: EventConfig) =
  ## Override default configuration for an event type
  em.configs[kind] = config

# ============================================================================
# Event Collection (Pattern-Based Coalescing)
# ============================================================================

proc addEvent*(em: EventManager, event: GuiEvent) =
  ## Add an event to the manager (applies coalescing based on pattern)
  let config = em.configs.getOrDefault(event.kind, EventConfig(pattern: epNormal))

  case config.pattern
  of epNormal:
    # Process immediately - add directly to queue
    em.queue.push(event)

  of epReplaceable:
    # Only keep last event (e.g., mouse move)
    # Will be added to queue in update()
    em.lastEvents[event.kind] = event

  of epDebounced:
    # Accumulate events, process after quiet period
    var seq = em.sequences.getOrDefault(event.kind)
    seq.events.add(event)
    seq.lastEventTime = getMonoTime()
    if seq.startTime == default(MonoTime):
      seq.startTime = getMonoTime()
    em.sequences[event.kind] = seq

  of epThrottled:
    # Rate limited - only process if interval elapsed
    let now = getMonoTime()
    let lastTime = em.throttleLastTime.getOrDefault(event.kind, MonoTime())

    if lastTime == MonoTime() or (now - lastTime) >= config.throttleInterval:
      em.queue.push(event)
      em.throttleLastTime[event.kind] = now
    # else: drop event (throttled)

  of epBatched:
    # Collect related events for batch processing
    var seq = em.sequences.getOrDefault(event.kind)
    seq.events.add(event)
    seq.lastEventTime = getMonoTime()
    if seq.startTime == default(MonoTime):
      seq.startTime = getMonoTime()
    em.sequences[event.kind] = seq

    # Process batch if size reached
    if seq.events.len >= config.batchSize:
      # Add all events in batch to queue (maintaining order)
      for ev in seq.events:
        em.queue.push(ev)
      em.sequences.del(event.kind)

  of epOrdered:
    # CRITICAL: Preserve exact sequence for keyboard/clicks
    # Add immediately to queue to maintain FIFO order
    em.queue.push(event)

# ============================================================================
# Event Processing
# ============================================================================

proc update*(em: EventManager) =
  ## Process pattern-based events (called once per frame)
  ## Handles debounced, batched, and replaceable events
  let now = getMonoTime()

  # Process replaceable events (only last one)
  for kind, event in em.lastEvents:
    em.queue.push(event)
  em.lastEvents.clear()

  # Check debounced and batched sequences
  var toDelete: seq[EventKind] = @[]

  for kind, seq in em.sequences:
    let config = em.configs[kind]

    case config.pattern
    of epDebounced:
      # Process if quiet period has passed
      if (now - seq.lastEventTime) >= config.debounceTime:
        # Add only the last event
        if seq.events.len > 0:
          em.queue.push(seq.events[^1])
        toDelete.add(kind)

    of epBatched:
      # Process if max sequence time exceeded
      if (now - seq.startTime) >= config.maxSequenceTime:
        # Add all events in batch
        for event in seq.events:
          em.queue.push(event)
        toDelete.add(kind)

    of epOrdered:
      # Ordered events are added immediately in addEvent()
      # This case shouldn't happen, but handle timeout
      if (now - seq.startTime) >= config.maxSequenceTime:
        for event in seq.events:
          em.queue.push(event)
        toDelete.add(kind)

    else:
      discard

  # Clean up processed sequences
  for kind in toDelete:
    em.sequences.del(kind)

# ============================================================================
# Time-Budgeted Processing
# ============================================================================

proc processEvents*(em: EventManager,
                   budget: Duration,
                   handler: proc(event: GuiEvent)): int {.discardable.} =
  ## Process events from queue with time budget
  ## Returns number of events processed
  ##
  ## Budget management:
  ## - Uses historical timing data to estimate event processing time
  ## - Defers events that would exceed budget to next frame
  ## - Maintains FIFO order within same priority

  result = 0
  let startTime = getMonoTime()
  var timeSpent = initDuration()

  while em.queue.len > 0:
    let event = em.queue[0]  # Peek without popping

    # Estimate time for this event
    let estimatedTime = if event.kind in em.timings:
      em.timings[event.kind].avgTime
    else:
      initDuration(milliseconds = 1)  # Default estimate

    # Check if we have budget left
    if result > 0 and (timeSpent + estimatedTime) > budget:
      # Would exceed budget, defer to next frame
      break

    # Pop and process
    discard em.queue.pop()
    let eventStartTime = getMonoTime()

    handler(event)

    let eventDuration = getMonoTime() - eventStartTime

    # Update timing statistics
    var timing = em.timings.getOrDefault(event.kind)
    timing.count += 1
    timing.totalTime = timing.totalTime + eventDuration
    timing.avgTime = timing.totalTime div timing.count
    timing.maxTime = max(timing.maxTime, eventDuration)
    em.timings[event.kind] = timing

    timeSpent = timeSpent + eventDuration
    inc result

proc queueLength*(em: EventManager): int =
  ## Get number of events in queue
  em.queue.len

proc hasPendingEvents*(em: EventManager): bool =
  ## Check if there are events pending
  em.queue.len > 0 or
  em.lastEvents.len > 0 or
  em.sequences.len > 0

# ============================================================================
# Debug/Stats
# ============================================================================

proc getStats*(em: EventManager): string =
  ## Get event processing statistics
  result = "Event Manager Stats:\n"
  result &= "  Queue length: " & $em.queue.len & "\n"
  result &= "  Replaceable pending: " & $em.lastEvents.len & "\n"
  result &= "  Sequences pending: " & $em.sequences.len & "\n"
  result &= "  Current budget: " & $em.currentBudget.inMilliseconds & "ms\n"
  result &= "\nTiming stats:\n"
  for kind, timing in em.timings:
    result &= "  " & $kind & ": "
    result &= "count=" & $timing.count & ", "
    result &= "avg=" & $timing.avgTime.inMilliseconds & "ms, "
    result &= "max=" & $timing.maxTime.inMilliseconds & "ms\n"
