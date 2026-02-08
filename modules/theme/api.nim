## Theme Module - Public API
##
## Usage:
##   import modules/theme/api
##
##   let tm = newThemeManager()
##   tm.setTheme("dark")
##   let t = tm.loadFromFile("custom.yaml")  # supports extends
##   tm.register("custom", t)
##   var corp = tm.derive("light", "Corporate")
##   corp.base[Default].cornerRadius = some(0.0f32)
##   tm.register("corporate", corp)

import ./theme_types
import ./theme_sys_core
import ./builtin_themes
import ./theme_manager

export theme_types
export theme_sys_core
export builtin_themes
export theme_manager
