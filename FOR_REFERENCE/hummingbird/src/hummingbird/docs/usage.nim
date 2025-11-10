## Application Structure and Usage

### Basic Application Setup
```nim
# main.nim
import quickui

proc main() =
 # Initialize app state
 var appState = AppState(
   counter: Store[int](value: 0),
   theme: Store[ThemeMode](value: tmLight)
 )

 # Run the application
 app.run:
   # Configure window
   title = "My QuickUI App"
   size = (800, 600)
   minSize = (400, 300)
   
   # Set theme
   theme = if appState.theme.get() == tmLight: 
     lightTheme() 
   else: 
     darkTheme()
   
   # Main app widget
   MainAppWidget(state: appState)

when isMainModule:
 main()