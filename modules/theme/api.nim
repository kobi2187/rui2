## Theme Module - Public API
##
## Theme system for RUI2 with state/intent-based property lookup and caching.
##
## Usage:
##   import modules/theme/api
##
##   let theme = createLightTheme()
##   let props = theme.getThemeProps(Default, Hovered)
##   # props.backgroundColor, props.cornerRadius, etc.
##
## Built-in themes: light, dark, beos, joy, wide
##
## Custom themes:
##   var theme = newTheme("My Theme")
##   theme.base[Default] = makeThemeProps(backgroundColor = makeColor(255, 255, 255), ...)
##   theme.states[Default][Pressed] = makeThemeProps(backgroundColor = makeColor(200, 200, 200))

import ./theme_types
import ./theme_sys_core
import ./builtin_themes

export theme_types
export theme_sys_core
export builtin_themes
