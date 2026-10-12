## Is a theme readable? WCAG contrast arithmetic and a check over a whole theme.
##
## `contrastProblems` looks at what a control actually shows in each state --
## caption against its background, and the focus ring against what it is drawn
## over -- and reports every pair below the threshold. A theme author runs it
## on their own theme; the high-contrast themes shipped here are held to the
## strict thresholds in the tests.

import std/[options, math, strformat]
import theme_sys_core
import theme_types
import rui_core

proc linear(channel: uint8): float =
  let c = float(channel) / 255.0
  if c <= 0.03928: c / 12.92 else: pow((c + 0.055) / 1.055, 2.4)

proc luminance*(c: Color): float =
  ## Relative luminance, 0 (black) to 1 (white).
  0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)

proc contrastRatio*(a, b: Color): float =
  ## WCAG contrast ratio, 1 (identical) to 21 (black on white).
  let la = luminance(a)
  let lb = luminance(b)
  (max(la, lb) + 0.05) / (min(la, lb) + 0.05)

proc over*(top, under: Color): Color =
  ## `top` drawn over `under`, by top's alpha.
  let a = float(top.a) / 255.0
  proc mix(t, u: uint8): uint8 = uint8(round(float(t) * a + float(u) * (1 - a)))
  Color(r: mix(top.r, under.r), g: mix(top.g, under.g), b: mix(top.b, under.b), a: 255)

type ContrastProblem* = object
  where*: string       ## "danger / hovered: caption"
  ratio*, needed*: float

proc `$`*(p: ContrastProblem): string =
  &"{p.where}: contrast {p.ratio:.2f}, wanted {p.needed:.1f}"

const
  IntentLabels = ["default", "info", "success", "warning", "danger"]
  CheckedStates = [Normal, Hovered, Pressed, Selected]

proc contrastProblems*(theme: Theme, textRatio = 4.5, uiRatio = 3.0): seq[ContrastProblem] =
  ## Every caption/background pair under `textRatio` (4.5 is WCAG AA, 7 is AAA)
  ## and every focus ring under `uiRatio` (3 is the AA floor for UI parts).
  ## Disabled controls are exempt: being hard to read is how they say "disabled".
  for intent in ThemeIntent:
    for state in CheckedStates:
      let props = theme.getThemeProps(intent, state)
      if props.backgroundColor.isSome and props.foregroundColor.isSome:
        let bg = props.backgroundColor.get.over(Color(r: 255, g: 255, b: 255, a: 255))
        let ratio = contrastRatio(props.foregroundColor.get, bg)
        if ratio < textRatio:
          result.add ContrastProblem(
            where: IntentLabels[ord(intent)] & " / " & ($state).toLowerAscii & ": caption",
            ratio: ratio, needed: textRatio)
    let focused = theme.getThemeProps(intent, Focused)
    if focused.focusRingColor.isSome or focused.borderColor.isSome:
      # The ring is drawn outside the control, so it is seen against the window
      # behind it, not against the control's own fill.
      let canvas = theme.canvasColor
      let ring = focused.focusRingColor.get(focused.borderColor.get(canvas))
      let ratio = contrastRatio(ring.over(canvas), canvas)
      if focused.focusRingWidth.get(2.0) > 0 and ratio < uiRatio:
        result.add ContrastProblem(
          where: IntentLabels[ord(intent)] & " / focused: focus ring",
          ratio: ratio, needed: uiRatio)
