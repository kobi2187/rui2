## Baby Step Test: Link[T] Without GUI
##
## Tests the Link[T] reactive system logic without graphics dependency

import ../../core/[types, link]
import std/strutils

# Create a mock widget for testing
proc newMockWidget(name: string, parent: Widget = nil): Widget =
  result = Widget(
    id: newWidgetId(),
    visible: true,
    enabled: true,
    isDirty: false,
    layoutDirty: false,
    parent: parent
  )
  echo "Created widget: ", name, " (id: ", result.id.int, ")"

proc main() =
  echo repeat("=", 60)
  echo "Link[T] Reactive System Test (No GUI)"
  echo repeat("=", 60)
  echo ""

  # Test 1: Basic Link creation and value access
  echo "[Test 1] Basic Link creation"
  let counter = newLink(0)
  echo "  ✓ Created Link[int] with initial value: ", counter.value
  echo ""

  # Test 2: Value change
  echo "[Test 2] Value change"
  counter.value = 42
  echo "  ✓ Changed value to: ", counter.value
  echo ""

  # Test 3: onChange callback
  echo "[Test 3] onChange callback"
  var callbackFired = false
  counter.setOnChange proc(old, new: int) =
    echo "  ✓ Callback fired: ", old, " → ", new
    callbackFired = true

  counter.value = 100
  assert callbackFired, "onChange callback should fire"
  echo "  ✓ Callback working correctly"
  echo ""

  # Test 4: Widget dependency tracking
  echo "[Test 4] Widget dependency tracking"
  let widget1 = newMockWidget("Label1")
  let widget2 = newMockWidget("Label2")

  counter.addDependent(widget1)
  counter.addDependent(widget2)

  echo "  ✓ Added 2 dependent widgets"
  echo "  ✓ Dependent count: ", counter.dependentCount
  assert counter.dependentCount == 2
  echo ""

  # Test 5: Dirty marking on value change
  echo "[Test 5] Dirty marking on value change"
  echo "  Before change:"
  echo "    widget1.isDirty = ", widget1.isDirty
  echo "    widget2.isDirty = ", widget2.isDirty

  counter.value = 200

  echo "  After change:"
  echo "    widget1.isDirty = ", widget1.isDirty
  echo "    widget2.isDirty = ", widget2.isDirty

  assert widget1.isDirty, "widget1 should be marked dirty"
  assert widget2.isDirty, "widget2 should be marked dirty"
  echo "  ✓ Both widgets marked dirty correctly"
  echo ""

  # Test 6: Parent propagation
  echo "[Test 6] Parent layoutDirty propagation"
  let container = newMockWidget("Container")
  let childWidget = newMockWidget("Child", container)

  let textLink = newLink("Hello")
  textLink.addDependent(childWidget)

  echo "  Before change:"
  echo "    child.layoutDirty = ", childWidget.layoutDirty
  echo "    container.layoutDirty = ", container.layoutDirty

  textLink.value = "Hello World"

  echo "  After change:"
  echo "    child.layoutDirty = ", childWidget.layoutDirty
  echo "    container.layoutDirty = ", container.layoutDirty

  assert childWidget.layoutDirty, "child should be marked layoutDirty"
  assert container.layoutDirty, "container should be marked layoutDirty (propagated)"
  echo "  ✓ layoutDirty propagated to parent correctly"
  echo ""

  # Test 7: Multiple Links on same widget
  echo "[Test 7] Multiple Links on same widget"
  let nameLink = newLink("John")
  let ageLink = newLink(30)
  let profileWidget = newMockWidget("ProfileCard")

  nameLink.addDependent(profileWidget)
  ageLink.addDependent(profileWidget)

  profileWidget.isDirty = false  # Reset
  profileWidget.layoutDirty = false

  nameLink.value = "Jane"
  assert profileWidget.isDirty, "widget should be dirty after name change"

  profileWidget.isDirty = false  # Reset
  ageLink.value = 31
  assert profileWidget.isDirty, "widget should be dirty after age change"

  echo "  ✓ Widget responds to multiple Links correctly"
  echo ""

  # Summary
  echo repeat("=", 60)
  echo "ALL TESTS PASSED ✓"
  echo repeat("=", 60)
  echo ""
  echo "Link[T] reactive system is working correctly:"
  echo "  ✓ Value storage and retrieval"
  echo "  ✓ Change detection"
  echo "  ✓ onChange callbacks"
  echo "  ✓ Widget dependency tracking"
  echo "  ✓ Automatic dirty marking"
  echo "  ✓ Parent propagation"
  echo "  ✓ Multiple Links per widget"
  echo ""
  echo "Ready to integrate with rendering and layout!"

when isMainModule:
  main()
