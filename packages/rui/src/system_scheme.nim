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

# ----------------------------------------------------------------------------
# Motion: whether the desktop wants animations
#
#   Linux    `gsettings get org.gnome.desktop.interface enable-animations`
#            ("false": animations off -> none)
#   macOS    `defaults read com.apple.universalaccess reduceMotion`
#            ("1": Reduce motion -> reduced; macOS keeps its fades)
#   Windows  `reg query "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate`
#            ("0": window animations off -> none)
#
# Anything else -- no tool, no answer -- is full motion.
# ----------------------------------------------------------------------------

proc parseSystemMotion*(output: string): Motion =
  ## What the platform tools print, as a motion level. Unrecognised is full.
  let o = output.toLowerAscii().strip()
  if o == "false": motionNone                                  # GNOME
  elif o == "1": motionReduced                                 # macOS
  elif "minanimate" in o and o.endsWith("0"): motionNone       # Windows
  else: motionFull

proc detectSystemMotion*(): Motion =
  ## Ask the platform. Never raises, never returns `motionSystem`.
  try:
    when defined(linux):
      result = parseSystemMotion(execProcess("gsettings",
        args = ["get", "org.gnome.desktop.interface", "enable-animations"],
        options = {poUsePath, poStdErrToStdOut}))
    elif defined(macosx):
      result = parseSystemMotion(execProcess("defaults",
        args = ["read", "com.apple.universalaccess", "reduceMotion"],
        options = {poUsePath, poStdErrToStdOut}))
    elif defined(windows):
      result = parseSystemMotion(execProcess("reg",
        args = ["query", r"HKCU\Control Panel\Desktop\WindowMetrics", "/v", "MinAnimate"],
        options = {poUsePath, poStdErrToStdOut}))
    else:
      result = motionFull
  except CatchableError:
    result = motionFull

proc effectiveMotion*(preferred: Motion, system: Motion): Motion =
  ## The level in force: the user's choice, or the desktop's when they chose
  ## to follow it.
  if preferred == motionSystem: system else: preferred
