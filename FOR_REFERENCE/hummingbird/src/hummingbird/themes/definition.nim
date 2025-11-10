# src/quickui/themes/definition.nim
type
  ColorRole* = enum
    crPrimary, crSecondary, crBackground, crSurface,
    crError, crWarning, crSuccess
    # etc...

  SpacingRole* = enum
    srSmall, srMedium, srLarge

  FontRole* = enum
    frHeadline, frBody, frCaption

  ThemeDefinition* = object
    colors*: Table[ColorRole, Color]
    spacing*: Table[SpacingRole, float32]
    typography*: Table[FontRole, FontStyle]
    # More theme aspects...

  # ... other defaults
