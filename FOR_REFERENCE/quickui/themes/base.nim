# themes/base.nim
type
  Theme* = object
    colors*: ColorScheme
    typography*: TypographyScheme
    spacing*: SpacingScheme
    borders*: BorderScheme
    shadows*: ShadowScheme

  ColorScheme* = object
    primary*, secondary*, accent*: Color
    background*, surface*: Color
    text*, textSecondary*: Color
    disabled*: Color
    error*, warning*, success*: Color

  TypographyScheme* = object
    fontFamily*: string
    sizes*: FontSizes
    weights*: FontWeights

  SpacingScheme* = object
    unit*: float32
    scale*: array[8, float32]  # Multipliers: 0.25, 0.5, 1, 1.5, 2, 3, 4, 8

# themes/light.nim
proc lightTheme*(): Theme =
  Theme(
    colors: ColorScheme(
      primary: rgb(0, 122, 255),
      secondary: rgb(142, 142, 147),
      # ... other colors
    ),
    typography: TypographyScheme(
      fontFamily: "Inter",
      sizes: defaultFontSizes(),
      weights: defaultFontWeights()
    ),
    spacing: defaultSpacing()
  )

# themes/dark.nim
proc darkTheme*(): Theme =
  Theme(
    colors: ColorScheme(
      primary: rgb(10, 132, 255),
      secondary: rgb(142, 142, 147),
      background: rgb(28, 28, 30)
      # ... other colors
    )
  )

# themes/custom/material.nim
proc materialTheme*(): Theme =
  # Material Design theme

# themes/custom/nord.nim
proc nordTheme*(): Theme =
  # Nord color scheme theme

# constraints/layouts.nim
type
  LayoutConstraints* = object
    case kind*: LayoutKind
    of lkFlex:
      direction: FlowDirection
      gap: float32
      wrap: bool
    of lkGrid:
      columns: int
      rowGap, columnGap: float32
    of lkStack:
      alignment: Alignment

# constraints/common.nim
proc centerInParent*(widget: Widget) =
  widget.addConstraints:
    center = parent.center

proc fillParent*(widget: Widget, margin: float32 = 0) =
  widget.addConstraints:
    left = parent.left + margin
    right = parent.right - margin
    top = parent.top + margin
    bottom = parent.bottom - margin

# Example usage:
import themes/[light, dark]
import themes/custom/[material, nord]
import constraints/[layouts, common]

# User can pick theme:
let app = Application(
  theme: lightTheme()  # or darkTheme(), materialTheme(), etc.
)

# Or mix and match:
var customTheme = lightTheme()
customTheme.colors = nordTheme().colors

# Common layouts:
let panel = Panel().withConstraints:
  centerInParent()
  width = 80.percent
  height = 90.percent