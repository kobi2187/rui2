version     = "0.2.0"
author      = "RUI2 Contributors"
description = "RUI2 drawing: primitives, effects, the theme system (state x intent), text cache, and theme-aware widget primitives."
srcDir      = "src"
# license   = "TODO: choose a license"

requires "nim >= 2.0.0"
requires "naylib"
requires "yaml"
requires "https://github.com/kobi2187/rui_core >= 0.2.0"

# System dependencies (not Nimble packages):
#   pango, pangocairo, cairo  -- resolved at compile time via pkg-config.
#   Debian/Ubuntu: apt-get install libpango1.0-dev libcairo2-dev
# See src/pango_binding.nim.
