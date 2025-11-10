## Simple Counter App - RUI2 Example
##
## Demonstrates the clean, explicit RUI2 API:
## 1. import rui
## 2. Define store (Link[T] state)
## 3. Build widget tree (returns Widget)
## 4. Create app, set root, start

import ../rui
import std/strformat

# ============================================================================
# 1. Define Store - Reactive State
# ============================================================================

type AppStore = object
  ## Application state using reactive Link[T] primitives
  counter: Link[int]
  message: Link[string]
  clicks: Link[int]

var store = AppStore(
  counter: newLink(0),
  message: newLink("Welcome to RUI2!"),
  clicks: newLink(0)
)

# ============================================================================
# 2. Define Helper Functions - Regular Nim Code
# ============================================================================

proc incrementCounter() =
  ## Increment counter and update message
  let newCount = store.counter.get() + 1
  store.counter.set(newCount)
  store.message.set(&"Counter: {newCount}")
  store.clicks.set(store.clicks.get() + 1)

proc decrementCounter() =
  ## Decrement counter and update message
  let newCount = store.counter.get() - 1
  store.counter.set(newCount)
  store.message.set(&"Counter: {newCount}")
  store.clicks.set(store.clicks.get() + 1)

proc resetCounter() =
  ## Reset counter to zero
  store.counter.set(0)
  store.message.set("Counter reset!")
  store.clicks.set(store.clicks.get() + 1)

# ============================================================================
# 3. Build Widget Tree - Returns Widget
# ============================================================================

proc buildUI(): Widget =
  ## Build the UI widget tree
  ## Returns a Widget that can be inspected or modified
  result = VStack(spacing = 10):
    # Title
    Label(text = "RUI2 Counter Demo")

    # Message display
    Label(text = store.message.get())

    # Counter display
    Label(text = &"Count: {store.counter.get()}")

    # Control buttons
    HStack(spacing = 5):
      Button(
        text = "-",
        onClick = decrementCounter
      )

      Button(
        text = "Reset",
        onClick = resetCounter
      )

      Button(
        text = "+",
        onClick = incrementCounter
      )

    # Stats
    Label(text = &"Total clicks: {store.clicks.get()}")

# ============================================================================
# 4. Main - Create App and Run
# ============================================================================

when isMainModule:
  echo "Starting RUI2 Counter App..."

  # Create the app
  let app = newApp(
    title = "Counter Demo",
    width = 400,
    height = 300,
    fps = 60
  )

  # Build and set the widget tree
  let ui = buildUI()
  app.setRootWidget(ui)

  echo "Widget tree built:"
  echo "  Root: VStack"
  echo "  Children: 5 widgets"
  echo ""
  echo "App configured:"
  echo "  Theme: ", app.currentTheme.name
  echo "  Text cache: initialized"
  echo ""

  # Start the main loop
  app.start()

  echo "App closed."
