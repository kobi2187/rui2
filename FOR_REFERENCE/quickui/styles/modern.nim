# styles/modern.nim
import ../core/types

proc modernTheme*(): Theme =
  result = Theme(
    colors: ThemeColors(
      background: Color(r: 250, g: 250, b: 250),
      text: Color(r: 33, g: 33, b: 33),
      primary: Color(r: 0, g: 122, b: 255),
      secondary: Color(r: 100, g: 100, b: 100),
      accent: Color(r: 255, g: 59, b: 48)
    ),
    spacing: ThemeSpacing(
      small: (x: 4, y: 4),
      medium: (x: 8, y: 8),
      large: (x: 16, y: 16)
    ),
    typography: TypographyScheme(
      h1: FontStyle(size: 24, weight: Bold),
      body: FontStyle(size: 16, weight: Regular)
    )
  )

# styles/dark.nim
proc darkTheme*(): Theme =
  result = Theme(
    colors: ThemeColors(
      background: Color(r: 30, g: 30, b: 30),
      text: Color(r: 240, g: 240, b: 240)
      # ... etc
    )
  )

# constraints/common.nim
proc centerIn*(widget: Widget, container: Widget) =
  widget.constraints.add:
    widget.centerX == container.centerX
    widget.centerY == container.centerY

proc fillParent*(widget: Widget, padding: float32 = 0) =
  widget.constraints.add:
    widget.left == parent.left + padding
    widget.right == parent.right - padding
    widget.top == parent.top + padding
    widget.bottom == parent.bottom - padding

# Usage:
import styles/[modern, dark]
import constraints/common

let app = container:
  style: modernTheme()  # or darkTheme()
  
  panel:
    constraints:
      centerIn(parent)
      width = 80%
      height = 90%