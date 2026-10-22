## Decorations: lights, glows and ants along an outline.
##
## Each is its own object drawn above the widget it follows (decoration.nim),
## so the widget keeps its cached picture and a glow can reach past its edge.
## The window has lights round it too (`adornWindow`); a shaped window gets
## them along its traced outline (examples/shaped/lights.nim).
##
## With the user's `motion: reduced` they still run (only easing stops); with
## `none` the lights go and the "look here" glow and the ants stand still.
##
##   nim c -r -d:useGraphics examples/widgets/decorations.nim [theme]

import rui
import std/[os, math]

let app = newApp("RUI2 - Decorations", 700, 400)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "midnight")

var festive, urgent, selected, custom: Button
var glow: Decoration
let root = ui:
  Center():
    Column(spacing = 34.0, mainAxisSize = MainAxisSize.min,
           crossAxisAlignment = CrossAxisAlignment.center):
      Label(text = "Decorations follow their widget and repaint only themselves",
            fontSize = 15.0)
      Row(spacing = 26.0, mainAxisSize = MainAxisSize.min):
        festive = Button(text = "Festive").size(130, 44).named("festive")
        urgent = Button(text = "Needs you", intent = ThemeIntent.Warning,
                        onClick = proc() =
                          if glow != nil:
                            glow.remove()
                            glow = nil).size(130, 44).named("urgent")
        selected = Button(text = "Selected").size(130, 44).named("selected")
        custom = Button(text = "Comet").size(130, 44).named("comet")

festive.adorn(leds(spacing = 14))
glow = urgent.adorn(glowPulse())            # click it: dealt with, the glow goes
selected.adorn(marchingAnts(color = Color(r: 220, g: 220, b: 230, a: 255)), inset = -4)
# Your own painter: a bright head chasing round, its tail fading behind it.
custom.adorn(proc(path: Path, t: float32) =
  let head = t * 140
  for k in 0 ..< 14:
    let p = path.pointAt(head - k.float32 * 5)
    let a = uint8(255 * pow(0.8, k.float))
    let r = 3.5'f32 - k.float32 * 0.18
    discard drawSdfBox(Rect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r), r, 0,
                       Color(r: 120, g: 220, b: 255, a: a), Color(r: 120, g: 220, b: 255, a: a)),
  reach = 6)
app.adornWindow(leds(spacing = 22, size = 2.5), inset = 6)

app.setRootWidget(root)
# No enableScripting here: a scripted app settles every animation, and this
# one is about the motion.
app.start()
