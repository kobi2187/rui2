# src/themes/types.nim
type
  ColorScheme* = object
    primary*, secondary*, accent*: Color
    background*, surface*: Color
    onPrimary*, onSecondary*, onBackground*: Color
    error*, success*, warning*: Color
    outline*, disabled*: Color

  TypographyScheme* = object
    fontFamily*: string
    h1*, h2*, h3*, h4*, h5*, h6*: TextStyle
    subtitle1*, subtitle2*: TextStyle
    body1*, body2*: TextStyle
    button*, caption*, overline*: TextStyle

  SpacingScheme* = object
    unit*: float32
    scale*: array[8, float32]  # 0.25, 0.5, 1, 1.5, 2, 3, 4, 8

  Theme* = object
    colors*: ColorScheme
    typography*: TypographyScheme
    spacing*: SpacingScheme

