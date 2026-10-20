## Is a theme readable? WCAG contrast arithmetic and a check over a whole theme.
##
## `contrastProblems` looks at what a control actually shows in each state --
## caption against its background, and the focus ring against what it is drawn
## over -- and reports every pair below the threshold. A theme author runs it
## on their own theme; the high-contrast themes shipped here are held to the
## strict thresholds in the tests.

import std/[options, math, strformat, tables]
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

proc captionFills(props: ThemeProps): seq[(Color, string)] =
  ## Every fill the caption of `props` is drawn on: its background, and the
  ## hover and pressed fills that replace it under the pointer.
  if props.backgroundColor.isSome: result.add (props.backgroundColor.get, "caption")
  if props.hoverColor.isSome: result.add (props.hoverColor.get, "caption on hover")
  if props.pressedColor.isSome: result.add (props.pressedColor.get, "caption when pressed")

proc contrastProblems*(theme: Theme, textRatio = 4.5, uiRatio = 3.0): seq[ContrastProblem] =
  ## Every caption/background pair under `textRatio` (4.5 is WCAG AA, 7 is AAA)
  ## and every focus ring under `uiRatio` (3 is the AA floor for UI parts).
  ## Disabled controls are exempt: being hard to read is how they say "disabled".
  for intent in ThemeIntent:
    for state in CheckedStates:
      let props = theme.getThemeProps(intent, state)
      if props.foregroundColor.isSome:
        # The caption sits on the background, and on the hover and pressed fills
        # a widget paints behind the same caption while the pointer is on it.
        for (fill, what) in captionFills(props):
          let bg = fill.over(Color(r: 255, g: 255, b: 255, a: 255))
          let ratio = contrastRatio(props.foregroundColor.get.over(bg), bg)
          if ratio < textRatio:
            result.add ContrastProblem(
              where: IntentLabels[ord(intent)] & " / " & ($state).toLowerAscii & ": " & what,
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

proc inkMixed*(a, b: Color, t: float32): Color =
  ## `a` moved `t` of the way to `b`, opaque.
  let u = clamp(t, 0.0'f32, 1.0'f32)
  proc lerpByte(x, y: uint8): uint8 = uint8(float32(x) + (float32(y) - float32(x)) * u)
  Color(r: lerpByte(a.r, b.r), g: lerpByte(a.g, b.g), b: lerpByte(a.b, b.b), a: 255)

proc readableInk*(ink, bg: Color, minRatio: float): Color =
  ## `ink`, moved toward black or white -- whichever contrasts more with `bg` --
  ## in the smallest steps that reach `minRatio`. The hue is kept; only the
  ## lightness moves. An ink that already reads is returned unchanged.
  let opaqueBg = bg.over(Color(r: 255, g: 255, b: 255, a: 255))
  if contrastRatio(ink.over(opaqueBg), opaqueBg) >= minRatio: return ink
  let black = Color(r: 0, g: 0, b: 0, a: 255)
  let white = Color(r: 255, g: 255, b: 255, a: 255)
  let target = if contrastRatio(black, opaqueBg) >= contrastRatio(white, opaqueBg): black else: white
  for i in 1 .. 40:
    let c = inkMixed(ink, target, float32(i) / 40.0'f32)
    if contrastRatio(c.over(opaqueBg), opaqueBg) >= minRatio: return c
  target

proc setInk(theme: var Theme, intent: ThemeIntent, state: ThemeState,
            fg: Option[Color] = none(Color), ring: Option[Color] = none(Color),
            hover: Option[Color] = none(Color), pressed: Option[Color] = none(Color)) =
  ## Sets the caption ink, the hover or pressed fill, or the focus ring of one
  ## intent and state: the base for Normal, the state's override for the rest.
  template apply(p: var ThemeProps) =
    if fg.isSome: p.foregroundColor = fg
    if ring.isSome: p.focusRingColor = ring
    if hover.isSome: p.hoverColor = hover
    if pressed.isSome: p.pressedColor = pressed
  if state == Normal and ring.isNone:
    var p = theme.base.getOrDefault(intent)
    apply(p)
    theme.base[intent] = p
    return
  var table = theme.states.getOrDefault(intent)
  var p = table.getOrDefault(state)
  apply(p)
  table[state] = p
  theme.states[intent] = table

proc awayFrom*(fill, ink: Color, t: float32): Color =
  ## `fill` moved `t` of the way from `ink`: darker under a lighter ink, lighter
  ## under a darker one -- a shade of the fill that only gains contrast with it.
  let white = Color(r: 255, g: 255, b: 255, a: 255)
  let black = Color(r: 0, g: 0, b: 0, a: 255)
  inkMixed(fill, (if luminance(ink) > luminance(fill): black else: white), t)

proc makeReadable*(theme: var Theme, textRatio = 4.5, uiRatio = 3.0) =
  ## Brings every caption and focus ring of `theme` up to the given ratios -- the
  ## same pairs contrastProblems checks, the hover and pressed fills included. Only the failing pairs change, and only
  ## their ink (or ring): backgrounds, hue and every pair that already passes stay
  ## as the theme drew them, so a theme that is readable already is untouched.
  for intent in ThemeIntent:
    for state in [Normal, Hovered, Pressed, Selected]:
      var props = theme.getThemeProps(intent, state)
      if props.foregroundColor.isNone: continue
      let ink = props.foregroundColor.get
      if props.backgroundColor.isSome:
        let fixed = readableInk(ink, props.backgroundColor.get, textRatio)
        if fixed != ink:
          theme.setInk(intent, state, fg = some(fixed))
          props = theme.getThemeProps(intent, state)
      elif props.hoverColor.isSome:
        theme.setInk(intent, state, fg = some(readableInk(ink, props.hoverColor.get, textRatio)))
        props = theme.getThemeProps(intent, state)
      # A hover or pressed fill the caption does not read on -- typically one an
      # intent inherits from Default while setting its own background -- becomes
      # a shade of that background instead, moved away from the ink: still a
      # visible change under the pointer, and never less readable than at rest.
      let readInk = props.foregroundColor.get
      proc reads(fill: Color): bool =
        let bg = fill.over(Color(r: 255, g: 255, b: 255, a: 255))
        contrastRatio(readInk.over(bg), bg) >= textRatio
      let base = props.backgroundColor
      if base.isSome:
        if props.hoverColor.isSome and not reads(props.hoverColor.get):
          theme.setInk(intent, state, hover = some(awayFrom(base.get, readInk, 0.10)))
        if props.pressedColor.isSome and not reads(props.pressedColor.get):
          theme.setInk(intent, state, pressed = some(awayFrom(base.get, readInk, 0.20)))
    let focused = theme.getThemeProps(intent, Focused)
    if focused.focusRingColor.isSome or focused.borderColor.isSome:
      let canvas = theme.canvasColor
      let ring = focused.focusRingColor.get(focused.borderColor.get(canvas))
      if contrastRatio(ring.over(canvas), canvas) < uiRatio:
        theme.setInk(intent, Focused, ring = some(readableInk(ring, canvas, uiRatio)))

proc onFillInk*(fill: Color): Color =
  ## The ink that reads on a solid `fill` -- a checkmark in it, a caption on a
  ## pressed segment, the text on a progress bar's fill: white or black, whichever
  ## contrasts more. The theme's own text colour is no answer for this: it is the
  ## ink on the theme's background, and themes differ on what that is.
  let white = Color(r: 255, g: 255, b: 255, a: 255)
  let black = Color(r: 0, g: 0, b: 0, a: 255)
  if contrastRatio(white, fill) >= contrastRatio(black, fill): white else: black
