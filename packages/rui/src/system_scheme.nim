## The operating system's light/dark preference.
##
## raylib knows nothing about it, so it is asked of the platform once, at
## startup, in the cheapest way each one offers. Anything that fails -- no such
## tool, no answer -- means light, so a missing signal never breaks an app.
##
##   Linux    `gsettings get org.gnome.desktop.interface color-scheme`
##   macOS    `defaults read -g AppleInterfaceStyle`   ("Dark" when dark)
##   Windows  `reg query ...\Themes\Personalize /v AppsUseLightTheme`  (0x0 = dark)

import std/[osproc, strutils]
import rui_core

proc parseSystemScheme*(output: string): ColorScheme =
  ## What the platform tools print, as a scheme. Unrecognised output is light.
  let o = output.toLowerAscii()
  if "prefer-dark" in o or o.strip() == "dark" or "'dark'" in o:
    schemeDark
  elif "appsuselighttheme" in o and "0x0" in o:
    schemeDark
  else:
    schemeLight

proc detectSystemScheme*(): ColorScheme =
  ## Ask the platform. Never raises, never returns `schemeSystem`.
  try:
    when defined(linux):
      result = parseSystemScheme(execProcess("gsettings",
        args = ["get", "org.gnome.desktop.interface", "color-scheme"],
        options = {poUsePath, poStdErrToStdOut}))
    elif defined(macosx):
      result = parseSystemScheme(execProcess("defaults",
        args = ["read", "-g", "AppleInterfaceStyle"],
        options = {poUsePath, poStdErrToStdOut}))
    elif defined(windows):
      result = parseSystemScheme(execProcess("reg",
        args = ["query", r"HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                "/v", "AppsUseLightTheme"],
        options = {poUsePath, poStdErrToStdOut}))
    else:
      result = schemeLight
  except CatchableError:
    result = schemeLight

proc effectiveScheme*(preferred: ColorScheme, system: ColorScheme): ColorScheme =
  ## The scheme to show: the user's choice, or the system's when they chose to
  ## follow it.
  if preferred == schemeSystem: system else: preferred
