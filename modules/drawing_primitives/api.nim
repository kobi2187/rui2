## Drawing Primitives Module - Public API
##
## Layered drawing system for RUI2 widgets.
##
## Layer 1: primitives/* (drawRect, drawText, drawLine, etc.)
## Layer 2: drawing_effects (bevels, gradients, shadows, glow, neumorphism)
## Layer 3: widget_primitives (drawButton, drawCheckbox, drawSlider, etc.)
##
## Usage:
##   import modules/drawing_primitives/api
##
##   # Low-level shapes
##   drawRect(rect, color)
##   drawRoundedRect(rect, radius, color)
##
##   # Effects
##   drawBeveledRect(rect, Raised, bgColor)
##   drawShadowedRect(rect, bgColor, shadowOffset=(4.0, 4.0))
##
##   # Widget primitives (theme-aware)
##   drawButton(rect, "Click me", themeProps)
##   drawCheckbox(rect, checked=true, themeProps)

import ./drawing_primitives
import ./drawing_effects
import ./widget_primitives

export drawing_primitives
export drawing_effects
export widget_primitives
