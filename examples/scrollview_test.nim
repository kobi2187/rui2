## ScrollView Test - RUI2 Example
##
## Demonstrates ScrollView container with:
## 1. Vertical scrolling with mouse wheel
## 2. Automatic scrollbars (show only when content overflows)
## 3. Content clipping to viewport
## 4. Both vertical and horizontal scrolling support

import ../rui
import std/strformat

# ============================================================================
# Define Helper Functions
# ============================================================================

proc onItemClick(index: int) =
  ## Click handler for list items
  echo &"Item {index} clicked!"

# ============================================================================
# Build Widget Tree
# ============================================================================

proc buildUI(): Widget =
  ## Build the UI with ScrollView containing many items
  result = VStack(spacing = 10, padding = 10):
    # Title
    Label(text = "ScrollView Demo - Use mouse wheel to scroll")

    # ScrollView with vertical scrolling
    ScrollView:
      VStack(spacing = 5, padding = 5):
        # Generate many items to demonstrate scrolling
        for i in 1..50:
          Button(
            text = &"Item {i} - Click me!",
            onClick = proc() = onItemClick(i)
          )

    # Instructions
    Label(text = "Scroll with mouse wheel. Scrollbars show when content overflows.")

# ============================================================================
# Main - Create App and Run
# ============================================================================

when isMainModule:
  echo "Starting RUI2 ScrollView Test..."

  # Create the app
  let app = newApp(
    title = "ScrollView Test",
    width = 500,
    height = 400,
    fps = 60
  )

  # Build and set the widget tree
  let ui = buildUI()
  app.setRootWidget(ui)

  echo "ScrollView test ready:"
  echo "  - 50 items in scrollable area"
  echo "  - Use mouse wheel to scroll"
  echo "  - Scrollbars appear automatically"
  echo ""

  # Start the main loop
  app.start()

  echo "App closed."
