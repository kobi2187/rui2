version     = "0.2.0"
author      = "RUI2 Contributors"
description = "RUI2 drawing: primitives, effects, the theme system (state x intent), text cache, and theme-aware widget primitives."
srcDir      = "src"
# license   = "TODO: choose a license"

requires "nim >= 2.0.0"
# naylib's version is date-based (25.42.0 is 2025 week 42), so the upper bound
# says "this year's line". A rollover to 26.x is where raylib itself moves, and
# is worth a look rather than an automatic upgrade: naylib's move-only GPU types
# are the part that breaks, and they break at compile time in generated widget
# code, which is the least legible place to find out.
requires "naylib >= 25.42.0 & < 26.0.0"
requires "yaml >= 2.2.0 & < 3.0.0"
requires "https://github.com/kobi2187/rui_core >= 0.2.0"

# System dependencies (not Nimble packages):
#   pango, pangocairo, cairo  -- resolved at compile time via pkg-config.
#   Debian/Ubuntu: apt-get install libpango1.0-dev libcairo2-dev
# See src/pango_binding.nim.
