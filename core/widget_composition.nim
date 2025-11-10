## Widget Composition System
##
## Provides generic container templates for composing widgets declaratively.
## Supports any container widget (VStack, HStack, Grid, TabControl, etc.)

import types

# ============================================================================
# Container Builder Template
# ============================================================================

template buildContainer*(containerType: typed, body: untyped): untyped =
  ## Generic template for building any container widget with children
  ##
  ## Usage:
  ##   buildContainer(VStack):
  ##     spacing = 10
  ##     Label(text: "Hello")
  ##     Button(text: "Click")
  ##
  ## Expands to:
  ##   block:
  ##     let container = newVStack()
  ##     container.spacing = 10
  ##     container.addChild(newLabel("Hello"))
  ##     container.addChild(newButton("Click"))
  ##     container

  block:
    # Create the container instance
    let container {.inject.} = containerType

    # Process the body - can contain:
    # 1. Property assignments (spacing = 10)
    # 2. Child widget expressions (Button(...))
    body

    # Return the configured container
    container

# ============================================================================
# Smart Child Addition
# ============================================================================

template addTo*(parent: Widget, child: Widget) =
  ## Add a child to a parent container
  parent.addChild(child)

template addTo*(parent: Widget, children: openArray[Widget]) =
  ## Add multiple children to a parent container
  for child in children:
    parent.addChild(child)

# ============================================================================
# Composition Helpers
# ============================================================================

proc `+`*(parent: Widget, child: Widget): Widget =
  ## Operator for adding children: parent + child
  parent.addChild(child)
  result = parent

proc `+`*(parent: Widget, children: seq[Widget]): Widget =
  ## Operator for adding multiple children: parent + @[child1, child2]
  for child in children:
    parent.addChild(child)
  result = parent

# ============================================================================
# DSL Macro Support
# ============================================================================

macro composeWidget*(containerExpr: typed, body: untyped): untyped =
  ## Macro for composition inside defineWidget render blocks
  ##
  ## Usage in defineWidget:
  ##   render:
  ##     composeWidget(newVStack()):
  ##       spacing = 10
  ##       newLabel("Title")
  ##       newButton("Click")
  ##
  ## This is generic - works with ANY container widget!

  result = quote do:
    block:
      let container = `containerExpr`
      `body`
      container

# ============================================================================
# Container Templates for Common Patterns
# ============================================================================

template vstack*(body: untyped): untyped =
  ## Create a VStack container with children
  ## Usage:
  ##   vstack:
  ##     spacing = 10
  ##     Label(text: "Hello")
  ##     Button(text: "Click")
  buildContainer(newVStack(), body)

template hstack*(body: untyped): untyped =
  ## Create an HStack container with children
  buildContainer(newHStack(), body)

template column*(body: untyped): untyped =
  ## Create a Column container with children
  buildContainer(newColumn(), body)

template grid*(body: untyped): untyped =
  ## Create a Grid container with children
  buildContainer(newGrid(), body)

template scrollView*(body: untyped): untyped =
  ## Create a ScrollView container with children
  buildContainer(newScrollView(), body)

template tabControl*(body: untyped): untyped =
  ## Create a TabControl container with children
  buildContainer(newTabControl(), body)

template panel*(body: untyped): untyped =
  ## Create a Panel container with children
  buildContainer(newPanel(), body)

# ============================================================================
# Example Usage Patterns
# ============================================================================

when false:
  # Example 1: Simple VStack composition
  let ui1 = vstack:
    spacing = 10
    padding = EdgeInsets(all: 20)

    newLabel("Title")
    newButton("Click Me")
    newSlider(0, 100, 50)

  # Example 2: Nested containers
  let ui2 = vstack:
    spacing = 16

    newLabel("Settings")

    hstack:
      spacing = 8
      newLabel("Volume:")
      newSlider(0, 100, 75)

    hstack:
      spacing = 8
      newCheckbox("Enabled")
      newButton("Apply")

  # Example 3: Custom container (TabControl)
  let ui3 = tabControl:
    tabs = @["General", "Advanced"]

    # Tab 1 content
    vstack:
      newLabel("General Settings")
      newCheckbox("Option 1")

    # Tab 2 content
    vstack:
      newLabel("Advanced Settings")
      newSlider(0, 100, 50)

  # Example 4: Inside defineWidget
  defineWidget(SettingsPanel):
    props:
      onSave: proc()

    render:
      # Use composition directly in render
      vstack:
        spacing = 20
        padding = EdgeInsets(all: 16)

        # Header
        hstack:
          newLabel("Settings")
          newSpacer()
          newButton("Save", widget.onSave)

        # Form
        formRow:
          newLabel("Name:")
          newTextInput("")

        formRow:
          newLabel("Theme:")
          newComboBox(@["Light", "Dark"])

  # Example 5: Generic container usage
  proc makeCustomLayout(): Widget =
    # This works with ANY container, not just vstack/hstack!
    buildContainer(newCustomContainer()):
      customProp = 42
      newWidget1()
      newWidget2()

# ============================================================================
# Integration with defineWidget
# ============================================================================

# When defineWidget sees composition syntax in render block:
#
# render:
#   vstack:
#     Label(text: "Hello")
#     Button(text: "Click")
#
# It expands to:
#
# render:
#   result = vstack:
#     result.addChild(newLabel("Hello"))
#     result.addChild(newButton("Click"))
#
# The vstack template handles:
# 1. Creating the container (newVStack())
# 2. Executing the body (adds children, sets props)
# 3. Returning the configured container
#
# This is GENERIC - works for any container type!
