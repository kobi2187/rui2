## The recipes in docs/sizing.md, built and laid out as written, so the page
## cannot drift from what compiles.

import std/unittest
import rui

proc lay(root: Widget) =
  discard root.measure(tight(400, 600))
  root.arrange(Rect(x: 0, y: 0, width: 400, height: 600))

suite "docs/sizing.md recipes":
  test "keep a widget's own size":
    let root = ui:
      Column(crossAxisAlignment = CrossAxisAlignment.stretch):
        TextInput(placeholder = "Email")
        Button(text = "Sign in").ownSize
        Button(text = "Help").align(Alignment.centerLeft)
    lay(root)
    check root.children[1].children[0].bounds.width < 400

  test "a fixed shape":
    let accent = Color(r: 90, g: 140, b: 220, a: 255)
    let root = ui:
      Column():
        ImageWidget(imagePath = "cover.png").aspect(16 / 9)
        Container(color = accent).aspect(1)
        Panel().fraction(width = 0.5)
        Panel().fraction(width = 0.8, height = 0.5)
    lay(root)
    check root.children.len == 4

  test "equal heights, equal widths":
    let root = ui:
      Column():
        Row(crossAxisAlignment = CrossAxisAlignment.stretch, spacing = 8.0).sameHeight:
          Card(): Label(text = "short")
          Separator(vertical = true)
          Card(): Label(text = "a much longer text that wraps onto lines", wrap = true)
        Column(crossAxisAlignment = CrossAxisAlignment.stretch).sameWidth:
          Button(text = "Open")
          Button(text = "Save as...")
    lay(root)
    let buttons = root.children[1].children[0].children
    check buttons[0].bounds.width == buttons[1].bounds.width

  test "place things over each other":
    let root = ui:
      Stack():
        ImageWidget(imagePath = "map.png").cover
        Badge(text = "3").at(right = 8, top = 8)
        Label(text = "Paris").at(left = 12, bottom = 12)
        ProgressBar(initialValue = 40).at(left = 0, right = 0, bottom = 0)
    lay(root)
    check root.children[3].bounds.width == 400

  test "gaps, and sharing the room":
    let longName = "a rather long name"
    let root = ui:
      Column():
        Label(text = "Title")
        Gap(12)
        Label(text = "Body")
        Row(spacing = 8.0):
          TextInput(placeholder = "Search").flex
          Button(text = "Go")
        Row():
          Label(text = longName).flexible
          Badge(text = "new")
    lay(root)
    check root.children[2].bounds.y - root.children[0].bounds.y >= 12

  test "cap a size where there is no limit; overflow a slot":
    let tint = Color(r: 220, g: 220, b: 240, a: 255)
    let root = ui:
      Column():
        ScrollView():
          Column():
            Container(color = tint).limit(height = 200)
        SizedBox(width = 48, height = 48):
          ImageWidget(imagePath = "logo.png").overflow(maxWidth = 96, maxHeight = 96)
    lay(root)
    check root.children.len == 2

  test "hide":
    let saved = newLink(false)
    let root = ui:
      Column():
        Label(text = "Saved").showIf(saved.value)
        Label(text = "Saved").showIf(saved.value, keepSize = true)
        Spinner().offstage
    lay(root)
    check root.children[0].bounds.height == 0
    check root.children[1].bounds.height > 0
