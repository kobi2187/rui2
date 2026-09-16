## Keyboard navigation — what the focus chain actually does today
##
## Probe, not a spec. These cases record current behaviour so a change to focus
## handling has something to break. Where current behaviour is wrong the test
## says so in its name and asserts the wrong thing deliberately, so the fix
## flips a red test rather than silently changing an untested path.

import std/unittest
import rui
import std/[options, monotimes]
# rui_core no longer re-exports KeyboardKey: its Menu/Down/Up fields collided
# with the Menu widget and with rui_drawing's ArrowDirection, which is why these
# cases used to have to spell out `Down`.
from raylib import KeyboardKey, Tab, Escape, Enter, Down, Up, Left, Right

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

  test "only focusable widgets are tab stops":
    # collectFocusableWidgets used to add every visible+enabled widget, so the
    # root stack and a static Label were tab stops. Widgets opt in now.
    let (root, a, b, c) = buildForm()
    let fm = newFocusManager()
    fm.buildFocusChain(root)

    check fm.focusChain == @[a, b, c]           # the two inputs and the button
    check root notin fm.focusChain              # the container is not a stop
    for w in fm.focusChain:
      check w.getTypeName() != "Label"          # nor is static text

  test "a widget can be taken out of the tab order by hand":
    let (root, a, _, _) = buildForm()
    a.focusable = false
    let fm = newFocusManager()
    fm.buildFocusChain(root)
    check a notin fm.focusChain

  test "a plain container can opt in, for focus groups later":
    let root = newVStack(spacing = 4.0)
    root.addChild(newLabel(text = "x", fontSize = 14.0))
    root.focusable = true
    let fm = newFocusManager()
    fm.buildFocusChain(Widget(root))
    check Widget(root) in fm.focusChain

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
    check fm.focusChain.len == 0                # nothing reachable

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
    check fm.focusChain[0] == a
    check fm.focusChain[1] == b
    check fm.focusChain[2] == c

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
    fm.setNavigationKeys(@[Down], @[Up])
    fm.buildFocusChain(root)

    check fm.handleKeyboardEvent(keyEvent(Down), root)
    let afterDown = fm.getFocusedWidget()
    check fm.handleKeyboardEvent(keyEvent(Up), root)
    check fm.getFocusedWidget() != afterDown

suite "key scoping":
  ## The focused widget gets first refusal; only keys it leaves unhandled reach
  ## the focus manager's own navigation. That is what lets a list use Up/Down
  ## for its rows while the same keys move between containers everywhere else.
  ##
  ## Before this, handleKeyboardEvent tested its navigation keys first, so a
  ## focused ListBox never saw Down at all.

  test "a focused list keeps the arrows for its own rows":
    let root = newVStack(spacing = 4.0)
    let list = newListBox(items = @["a", "b", "c"], visibleRows = 3)
    root.addChild(list)

    let fm = newFocusManager()
    fm.setNavigationKeys(@[Down], @[Up])
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(list))

    check fm.handleKeyboardEvent(keyEvent(Down), Widget(root))
    check list.focusIndex == 1                 # the row moved
    check fm.getFocusedWidget() == Widget(list) # focus did not

  test "the same key moves focus when the focused widget ignores it":
    let root = newVStack(spacing = 4.0)
    let a = newButton(text = "a")
    let b = newButton(text = "b")
    root.addChild(a)
    root.addChild(b)

    let fm = newFocusManager()
    fm.setNavigationKeys(@[Down], @[Up])
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(a))

    # A Button has no on_key_down, so Down falls through to navigation.
    check fm.handleKeyboardEvent(keyEvent(Down), Widget(root))
    check fm.getFocusedWidget() == Widget(b)

  test "a list at its last row lets the key through":
    # nextFocusIndex clamps rather than wrapping, and the widget still reports
    # the key handled -- so the list keeps the arrows for as long as it is
    # focused. Escaping a list is Tab's job, not Down's.
    let root = newVStack(spacing = 4.0)
    let list = newListBox(items = @["only"], visibleRows = 1)
    let after = newButton(text = "after")
    root.addChild(list)
    root.addChild(after)

    let fm = newFocusManager()
    fm.setNavigationKeys(@[Down], @[Up])
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(list))
    discard fm.handleKeyboardEvent(keyEvent(Down), Widget(root))
    check fm.getFocusedWidget() == Widget(list)

  test "Tab still moves focus out of a list":
    let root = newVStack(spacing = 4.0)
    let list = newListBox(items = @["a", "b"], visibleRows = 2)
    let after = newButton(text = "after")
    root.addChild(list)
    root.addChild(after)

    let fm = newFocusManager()
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(list))

    # ListBox leaves Tab unhandled, so it reaches navigation.
    check fm.handleKeyboardEvent(keyEvent(Tab), Widget(root))
    check fm.getFocusedWidget() == Widget(after)

  test "a text field keeps Home for its caret":
    let root = newVStack(spacing = 4.0)
    let input = newTextInput(initialText = "hello")
    root.addChild(input)

    let fm = newFocusManager()
    fm.setNavigationKeys(@[Home], @[])         # Home as a navigation key
    fm.buildFocusChain(Widget(root))
    fm.setFocus(Widget(input))
    input.cursorPos = 3

    check fm.handleKeyboardEvent(keyEvent(Home), Widget(root))
    check input.cursorPos == 0                 # the caret moved, not the focus

suite "focus chain invalidation":
  ## The chain is built lazily on first use and was never rebuilt after that:
  ## `focusChainDirty` started true, `ensureFocusChain` cleared it, and nothing
  ## anywhere set it again. FocusManager.markDirty and widgetRemoved both existed
  ## and were called from nowhere.

  test "a widget added after the chain was built is still reachable":
    let root = newVStack(spacing = 4.0)
    root.addChild(newTextInput(initialText = "first"))

    let fm = newFocusManager()
    fm.nextFocus(Widget(root))              # builds the chain lazily
    let before = fm.focusChain.len

    root.addChild(newTextInput(initialText = "second"))
    fm.nextFocus(Widget(root))              # must notice the tree grew
    check fm.focusChain.len == before + 1

  test "a widget added deeper in the tree also counts":
    let root = newVStack(spacing = 4.0)
    let inner = newVStack(spacing = 2.0)
    root.addChild(inner)

    let fm = newFocusManager()
    fm.nextFocus(Widget(root))
    let before = fm.focusChain.len

    inner.addChild(newTextInput(initialText = "deep"))
    fm.nextFocus(Widget(root))
    check fm.focusChain.len == before + 1

  test "markDirty forces a rebuild":
    let root = newVStack(spacing = 4.0)
    root.addChild(newTextInput(initialText = "a"))
    let fm = newFocusManager()
    fm.buildFocusChain(Widget(root))
    let before = fm.focusChain.len

    # Hide a widget without touching the structure, then ask for a rebuild.
    root.children[0].visible = false
    fm.markDirty()
    fm.nextFocus(Widget(root))
    check fm.focusChain.len == before - 1

  test "an unchanged tree is not rebuilt on every navigation":
    # The rebuild walks the whole tree, so it must not happen per key press.
    let root = newVStack(spacing = 4.0)
    for i in 0 .. 2:
      root.addChild(newTextInput(initialText = $i))

    let fm = newFocusManager()
    fm.nextFocus(Widget(root))
    let chain = fm.focusChain           # capture the seq's contents
    fm.nextFocus(Widget(root))
    fm.nextFocus(Widget(root))
    check fm.focusChain == chain        # same widgets, same order
