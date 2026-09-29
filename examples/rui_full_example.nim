## Full RUI Example
##
## One small app that uses the pieces together: a tree written with `ui:`,
## state in `Link`s that the widgets showing it are bound to, input widgets
## writing back into those links, runtime theme switching, and a Spacer that
## pins the footer to the bottom of the window.
##
##   nim c -r -d:useGraphics examples/rui_full_example.nim

import rui  # Single import!

proc main() =
  echo ruiVersionString()

  let app = newApp(
    title = "RUI Full Example",
    width = 800,
    height = 600,
    resizable = true,
    minWidth = 600,
    minHeight = 400
  )

  # State lives in links; widgets that show it are bound, not polled.
  let name = newLink("")
  let volume = newLink(40.0'f32)
  let muted = newLink(false)

  var nameInput: TextInput
  var volumeSlider: Slider
  var muteBox: Checkbox
  var greeting, level: Label
  var meter: ProgressBar
  var lightBtn, darkBtn: Button

  let root = ui:
    VStack(spacing = 14.0, padding = 24.0):
      Label(text = "Settings", fontSize = 26.0, bold = true)
      Row(spacing = 10.0):
        Label(text = "Your name:", fontSize = 15.0)
        nameInput = TextInput(placeholder = "type a name")
      greeting = Label(text = "", fontSize = 15.0)
      Separator()
      volumeSlider = Slider(initialValue = 40.0, textLeft = "Volume")
      muteBox = Checkbox(text = "Mute")
      meter = ProgressBar(initialValue = 40.0)
      level = Label(text = "", fontSize = 13.0)
      Spacer()                      # takes the leftover height...
      HStack(spacing = 10.0):       # ...so this row sits at the bottom
        lightBtn = Button(text = "Light theme")
        darkBtn = Button(text = "Dark theme", intent = ThemeIntent.Info)

  # Display widgets follow their links.
  name.bindTo(greeting, proc(v: string) =
    greeting.text = if v.len == 0: "Hello, stranger." else: "Hello, " & v & "!")

  proc showLevel() =
    let v = if muted.get(): 0.0 else: float(volume.get())
    meter.value = v
    level.text = if muted.get(): "muted" else: $int(v) & "%"
  # Either link changes both widgets, so each is bound to both.
  for w in [Widget(meter), Widget(level)]:
    volume.bindTo(w, proc(v: float32) = showLevel())
    muted.bindTo(w, proc(v: bool) = showLevel())

  # Input widgets write back.
  nameInput.onChange = proc(t: string) = name.set(t)
  volumeSlider.onChange = proc(v: float32) = volume.set(v)
  muteBox.onToggle = proc(c: bool) = muted.set(c)

  lightBtn.onClick = proc() = app.setTheme("light")
  darkBtn.onClick = proc() = app.setTheme("dark")

  # The root is sized to the window, so the Spacer has leftover height to take.
  app.setRootWidget(root)
  app.run()

when isMainModule:
  main()
