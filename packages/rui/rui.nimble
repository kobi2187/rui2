version     = "0.2.0"
author      = "RUI2 Contributors"
description = "RUI2: fast, lightweight reactive UI framework for Nim built on raylib. Umbrella package re-exporting all subsystems."
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
requires "https://github.com/kobi2187/rui_hittest >= 0.2.0"
requires "https://github.com/kobi2187/rui_events >= 0.2.0"
requires "https://github.com/kobi2187/rui_drawing >= 0.2.0"
requires "https://github.com/kobi2187/rui_scripting >= 0.2.0"
requires "https://github.com/kobi2187/rui_widgets >= 0.2.0"
