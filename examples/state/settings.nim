## State block: a settings page. Several controls share one store; a summary
## label and a Reset button (one transaction) use it.
##
##   nim c -r -d:useGraphics examples/state/settings.nim

import rui
import std/strformat

proc buildUI*(): Widget =
  state:
    notifications: bool = true
    sounds: bool = false
    volume: float32 = 40
    nickname: string = "guest"
  let summary = derive(notifications, volume, nickname,
    proc (n: bool, v: float32, who: string): string =
      &"{who}: notifications {(if n: \"on\" else: \"off\")}, volume {int(v)}")

  proc reset() =
    transaction:                         # one repaint for all four writes
      notifications.value = true
      sounds.value = false
      volume.value = 40
      nickname.value = "guest"

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Settings", fontSize = 22.0, bold = true)
      Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
            columnSpacing = 12.0, rowSpacing = 10.0):
        TableRow():
          Label(text = "Nickname")
          TextInput(text = <-> nickname).named("nickname")
        TableRow():
          Label(text = "Volume")
          Slider(value = <-> volume, minValue = 0, maxValue = 100).named("volume")
      Checkbox(text = "Notifications", checked = <-> notifications).named("notifications")
      Checkbox(text = "Sounds", checked = <-> sounds).named("sounds")
      Label(text = -> summary).named("summary")
      Button(text = "Reset", onClick = reset).named("reset")

when isMainModule:
  let app = newApp("Settings", 420, 360)
  app.setRootWidget(buildUI())
  app.run()
