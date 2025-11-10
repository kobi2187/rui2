
# src/themes/base.nim
proc defaultTypography*(): TypographyScheme =
  TypographyScheme(
    fontFamily: "Inter",
    h1: TextStyle(size: 96, weight: Light),
    h2: TextStyle(size: 60, weight: Light),
    h3: TextStyle(size: 48, weight: Regular),
    body1: TextStyle(size: 16, weight: Regular),
    body2: TextStyle(size: 14, weight: Regular),
    button: TextStyle(size: 14, weight: Medium, letterSpacing: 1.25)
  )

proc defaultSpacing*(): SpacingScheme =
  SpacingScheme(
    unit: 8.0,
    scale: [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 8.0]
  )