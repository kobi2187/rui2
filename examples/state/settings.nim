## State block: a settings page. Several controls share one store; every change
## goes through `set...` handlers, the summary is rewritten by `refresh`, and
## Reset writes everything in one transaction.
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
    summary: string = ""

  proc refresh() =
    summary.value = &"{nickname.value}: notifications {(if notifications.value: \"on\" else: \"off\")}, " &
                    &"volume {int(volume.value)}"
  refresh()

  proc reset() =
    transaction:                         # one repaint for all the writes
      notifications.value = true
      sounds.value = false
      volume.value = 40
      nickname.value = "guest"
    refresh()

  ui:
    VStack(spacing = 12.0, padding = 20.0):
      Label(text = "Settings", fontSize = 22.0, bold = true)
      Table(columnWidths = @[IntrinsicColumnWidth(), FlexColumnWidth()],
            columnSpacing = 12.0, rowSpacing = 10.0):
        TableRow():
          Label(text = "Nickname")
          TextInput(text = nickname.value, onChange = proc (s: string) =
            nickname.value = s
            refresh()).named("nickname")
        TableRow():
          Label(text = "Volume")
          Slider(value = volume.value, minValue = 0, maxValue = 100,
                 onChange = proc (v: float32) =
                   volume.value = v
                   refresh()).named("volume")
      Checkbox(text = "Notifications", checked = notifications.value,
               onToggle = proc (on: bool) =
                 notifications.value = on
                 refresh()).named("notifications")
      Checkbox(text = "Sounds", checked = sounds.value,
               onToggle = sounds.setter).named("sounds")
      Label(text = summary.value).named("summary")
      Button(text = "Reset", onClick = reset).named("reset")

when isMainModule:
  let app = newApp("Settings", 420, 360)
  app.setRootWidget(buildUI())
  app.run()
