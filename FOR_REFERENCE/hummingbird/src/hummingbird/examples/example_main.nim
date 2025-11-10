# Custom widgets in separate modules
# time_widget.nim
defineWidget TimeSetter:
  # NTP time setter implementation...

# converter_widget.nim
defineWidget AudioConverter:
  # Audio converter implementation...

# todo_widget.nim
defineWidget TodoList:
  # Todo list implementation...

# main_app.nim
type
  TabKind = enum
    tkTime, tkConverter, tkTodo
    
  AppState = object
    currentTab: Store[TabKind]
    timeState: TimeSyncState
    converterState: ConverterState
    todoState: TodoState

defineWidget MainApp:
  props:
    state: AppState

  render:
    vstack:
      spacing = 0

      # Top bar with tabs
      Panel:
        height = 48
        background = theme.surface
        elevation = 2

        TabBar:
          selected = widget.state.currentTab.get().ord
          tabs = @[
            Tab(text: "Time Sync", icon: some(iconClock)),
            Tab(text: "Converter", icon: some(iconMusic)),
            Tab(text: "Todo", icon: some(iconList))
          ]
          onSelect = proc(index: int) =
            widget.state.currentTab.set(TabKind(index))

      # Main content
      case widget.state.currentTab.get()
      of tkTime:
        TimeSetter(state: widget.state.timeState)
      of tkConverter:
        AudioConverter(state: widget.state.converterState)
      of tkTodo:
        TodoList(state: widget.state.todoState)

# main.nim
proc main() =
  var state = AppState(
    currentTab: Store[TabKind](value: tkTime),
    timeState: initTimeSyncState(),
    converterState: initConverterState(),
    todoState: initTodoState()
  )

  app.run:
    title = "QuickUI Utilities"
    size = (800, 600)
    
    # Basic window features
    onClose = proc(): bool =
      # Handle unsaved changes
      result = true
    
    onResize = proc(newSize: tuple[w, h: int]) =
      # Handle resize if needed
      discard

    # Error handling
    try:
      MainApp(state: state)
    except:
      ErrorDialog:
        message = getCurrentExceptionMsg()
        details = getStackTrace()

when isMainModule:
  main()

# app_types.nim
type
  AppState* = object
    # Shared state types

# widgets/
# widgets/time_setter.nim
# widgets/audio_converter.nim
# widgets/todo_list.nim

# themes/
# themes/light.nim
# themes/dark.nim

# state/
# state/init.nim - State initialization
# state/persistence.nim - State saving/loading

# main.nim
import
  widgets/[time_setter, audio_converter, todo_list],
  themes/[light, dark],
  state/[init, persistence]

proc initApp(): AppState =
  # Initialize all state
  result = AppState()
  # Load saved state
  try:
    result = loadSavedState()
  except:
    log.warn "Could not load saved state"

proc main() =
  # Initialize
  var state = initApp()
  
  # Set up error handling
  setErrorHandler(proc(e: ref Exception) =
    log.error e.msg
    showErrorDialog(e.msg)
  )

  # Run app
  app.run:
    title = "My App"
    icon = "assets/icon.png"
    
    # Window setup
    defaultSize = (800, 600) 
    minSize = (400, 300)
    
    # State persistence
    onClose = proc(): bool =
      try:
        saveState(state)
        result = true
      except:
        result = showUnsavedDialog()
    
    # Main app widget
    try:
      MainApp(state: state)
    except:
      ErrorScreen:
        error = getCurrentException()
        onRetry = proc() = main()

when isMainModule:
  main()