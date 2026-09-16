## Keyboard navigation — what the focus chain actually does today
##
## Probe, not a spec. These cases record current behaviour so a change to focus
## handling has something to break. Where current behaviour is wrong the test
## says so in its name and asserts the wrong thing deliberately, so the fix
## flips a red test rather than silently changing an untested path.

import std/unittest
import rui
import std/[options, monotimes]

proc keyEvent(key: KeyboardKey): GuiEvent =
  GuiEvent(kind: evKeyDown, key: key, timestamp: getMonoTime())

proc buildForm(): tuple[root: Widget, a, b, c: Widget] =
  ## A label and three inputs in a stack — a plausible little form.
  let root = newVStack(spacing = 4.0)
  let heading = newLabel(text = "Heading", fontSize = 14.0)
  let a = newTextInput(initialText = "a")
  let b = newTextInput(initialText = "b")
  let c = newButton(text = "Submit")
  root.addChild(heading)
  root.addChild(a)
  root.addChild(b)
  root.addChild(c)
  (Widget(root), Widget(a), Widget(b), Widget(c))

suite "focus chain composition":

  test "EVERY widget lands in the focus chain, not just the focusable ones":
    # collectFocusableWidgets adds every visible+enabled widget and carries a
    # `TODO: Add isFocusable field to Widget type`. So the root stack and a
    # static Label are tab stops.
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)

    # root + heading + 3 controls = 5, when only 3 should be reachable.
    check fm.focusChain.len == 5
    check fm.focusChain[0] == root              # the container itself
    check fm.focusChain[1].getTypeName() == "Label"

  test "an invisible or disabled subtree is skipped":
    let (root, a, _, _) = buildForm()
    a.visible = false
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    for w in fm.focusChain:
      check w != a

  test "hiding a parent removes its children too":
    let root = newVStack(spacing = 4.0)
    let box = newVStack(spacing = 2.0)
    let inner = newTextInput(initialText = "x")
    box.addChild(inner)
    root.addChild(box)
    box.visible = false

    let fm = newFocusManager()
    fm.buildFocusChain(Widget(root))
    check fm.focusChain.len == 1                # just the root

suite "tab order":

  test "Tab advances and wraps":
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)

    fm.nextFocus(root)
    let first = fm.getFocusedWidget()
    check first != nil

    for _ in 1 ..< fm.focusChain.len:
      fm.nextFocus(root)
    fm.nextFocus(root)
    check fm.getFocusedWidget() == first        # wrapped

  test "prevFocus walks backwards and wraps":
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)

    fm.nextFocus(root)
    let first = fm.getFocusedWidget()
    fm.prevFocus(root)
    check fm.getFocusedWidget() == fm.focusChain[^1]
    fm.nextFocus(root)
    check fm.getFocusedWidget() == first

  test "focus order is tree order, so it follows layout only by accident":
    # Depth-first over `children`. Reordering children for visual reasons
    # silently reorders the tab sequence.
    let (root, a, b, c) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    check fm.focusChain[2] == a
    check fm.focusChain[3] == b
    check fm.focusChain[4] == c

  test "setFocus sets focused on the widget and clears the previous one":
    let (root, a, b, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)

    fm.setFocus(a)
    check a.focused
    fm.setFocus(b)
    check b.focused
    check not a.focused

suite "key routing":

  test "Tab is consumed by the focus manager":
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    check fm.handleKeyboardEvent(keyEvent(Tab), root)

  test "a non-navigation key reaches the focused widget":
    let (root, a, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    fm.setFocus(a)
    # TextInput handles Home by moving its caret.
    check fm.handleKeyboardEvent(keyEvent(Home), root)

  test "with nothing focused, a key press goes nowhere":
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    check not fm.handleKeyboardEvent(keyEvent(Home), root)

  test "navigation keys are configurable":
    let (root, _, _, _) = buildForm()
    let fm = newFocusManager()
    # Qualified: rui_core re-exports raylib wholesale and rui_drawing has an
    # ArrowDirection.Down, so the bare name is ambiguous here.
    fm.setNavigationKeys(@[KeyboardKey.Down], @[KeyboardKey.Up])
    fm.buildFocusChain(root)

    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), root)
    let afterDown = fm.getFocusedWidget()
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Up), root)
    check fm.getFocusedWidget() != afterDown

  test "NOTHING scopes keys to a container":
    # There is no notion of "inside" a container: a key either hits the focus
    # manager's global navigation keys or the one focused widget. A list that
    # wants Up/Down for its rows and a container that wants Up/Down to move
    # between containers cannot both have them.
    let root = newVStack(spacing = 4.0)
    let list = newListBox(items = @["a", "b", "c"], visibleRows = 3)
    root.addChild(list)

    let fm = newFocusManager()
    fm.setNavigationKeys(@[KeyboardKey.Down], @[KeyboardKey.Up])
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(list))

    # Down is swallowed by the focus manager before the ListBox ever sees it,
    # so the list's own row navigation is unreachable.
    check fm.handleKeyboardEvent(keyEvent(KeyboardKey.Down), Widget(root))
    check list.focusIndex == 0                 # never moved
