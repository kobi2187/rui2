## Popular palettes and design systems, as rui brands.
##
## Each is a `BrandSpec` (brand_themes.nim): the published palette's
## background, surface, text, accent and status colours, and the design
## system's rounding and type where it has a recognisable one. They are
## translations, not pixel copies: every one passes the same checks as the
## shipped brands (WCAG AA for every caption, a 3:1 focus ring, readable
## placeholders), so where a palette's own text colour falls short of that
## (Solarized's body grey does), the nearest palette shade that passes is used.
##
## ```nim
## app.setTheme("nord")        # or "dracula", "catppuccin-mocha", "material", ...
## ```

import std/options
import theme_sys_core
import brand_themes

# --- editor and terminal palettes -------------------------------------------

proc nordSpec*(): BrandSpec =
  ## Nord: Polar Night, Snow Storm and Frost (nordtheme.com).
  BrandSpec(name: "Nord", dark: true, accent: hex"#88C0D0", onAccent: hex"#2E3440",
            canvas: hex"#2E3440", surface: hex"#3B4252", text: hex"#ECEFF4",
            border: hex"#4C566A", radius: 4,
            info: hex"#81A1C1", success: hex"#A3BE8C", warning: hex"#EBCB8B",
            danger: hex"#BF616A")

proc nordLightSpec*(): BrandSpec =
  ## Nord on Snow Storm, with the deep Frost blue.
  BrandSpec(name: "Nord Light", accent: hex"#5E81AC", onAccent: hex"#FFFFFF",
            canvas: hex"#E5E9F0", surface: hex"#ECEFF4", text: hex"#2E3440",
            border: hex"#D8DEE9", radius: 4,
            info: hex"#5E81AC", success: hex"#4F7A3A", warning: hex"#8A6A1F",
            danger: hex"#A3434D")

proc draculaSpec*(): BrandSpec =
  ## Dracula (draculatheme.com): purple on the night background.
  BrandSpec(name: "Dracula", dark: true, accent: hex"#BD93F9", onAccent: hex"#282A36",
            canvas: hex"#282A36", surface: hex"#343746", text: hex"#F8F8F2",
            border: hex"#44475A", radius: 6,
            info: hex"#8BE9FD", success: hex"#50FA7B", warning: hex"#F1FA8C",
            danger: hex"#FF5555")

proc solarizedLightSpec*(): BrandSpec =
  ## Solarized (ethanschoonover.com/solarized), light: base3 paper. Text is
  ## base02 rather than base00, which is too faint for AA on base3.
  BrandSpec(name: "Solarized Light", accent: hex"#268BD2", onAccent: hex"#002B36",
            canvas: hex"#EEE8D5", surface: hex"#FDF6E3", text: hex"#073642",
            border: hex"#D6CFB8", radius: 4,
            info: hex"#1F6FA8", success: hex"#5F6F00", warning: hex"#8A5A00",
            danger: hex"#B3261E")

proc solarizedDarkSpec*(): BrandSpec =
  ## Solarized, dark: base03 night, base1 text.
  BrandSpec(name: "Solarized Dark", dark: true, accent: hex"#268BD2", onAccent: hex"#FDF6E3",
            canvas: hex"#002B36", surface: hex"#073642", text: hex"#EEE8D5",
            border: hex"#2A4F5A", radius: 4,
            info: hex"#2AA198", success: hex"#859900", warning: hex"#B58900",
            danger: hex"#DC322F")

proc gruvboxSpec*(): BrandSpec =
  ## Gruvbox dark (github.com/morhetz/gruvbox): retro warm, orange accent.
  BrandSpec(name: "Gruvbox", dark: true, accent: hex"#FE8019", onAccent: hex"#282828",
            canvas: hex"#282828", surface: hex"#3C3836", text: hex"#EBDBB2",
            border: hex"#504945", radius: 2,
            info: hex"#83A598", success: hex"#B8BB26", warning: hex"#FABD2F",
            danger: hex"#FB4934")

proc catppuccinLatteSpec*(): BrandSpec =
  ## Catppuccin Latte (catppuccin.com): the light flavour, mauve accent.
  BrandSpec(name: "Catppuccin Latte", accent: hex"#8839EF", onAccent: hex"#FFFFFF",
            canvas: hex"#E6E9EF", surface: hex"#EFF1F5", text: hex"#4C4F69",
            border: hex"#CCD0DA", radius: 8,
            info: hex"#1E66F5", success: hex"#40A02B", warning: hex"#DF8E1D",
            danger: hex"#D20F39")

proc catppuccinMochaSpec*(): BrandSpec =
  ## Catppuccin Mocha: the darkest flavour.
  BrandSpec(name: "Catppuccin Mocha", dark: true, accent: hex"#CBA6F7", onAccent: hex"#1E1E2E",
            canvas: hex"#181825", surface: hex"#1E1E2E", text: hex"#CDD6F4",
            border: hex"#45475A", radius: 8,
            info: hex"#89B4FA", success: hex"#A6E3A1", warning: hex"#F9E2AF",
            danger: hex"#F38BA8")

proc oneDarkSpec*(): BrandSpec =
  ## One Dark (Atom): the blue accent on its grey-blue.
  BrandSpec(name: "One Dark", dark: true, accent: hex"#61AFEF", onAccent: hex"#21252B",
            canvas: hex"#21252B", surface: hex"#282C34", text: hex"#DCDFE4",
            border: hex"#3E4451", radius: 4,
            info: hex"#56B6C2", success: hex"#98C379", warning: hex"#E5C07B",
            danger: hex"#E06C75")

proc tokyoNightSpec*(): BrandSpec =
  ## Tokyo Night: the city at night, a soft blue accent.
  BrandSpec(name: "Tokyo Night", dark: true, accent: hex"#7AA2F7", onAccent: hex"#1A1B26",
            canvas: hex"#16161E", surface: hex"#1A1B26", text: hex"#C0CAF5",
            border: hex"#292E42", radius: 6,
            info: hex"#7DCFFF", success: hex"#9ECE6A", warning: hex"#E0AF68",
            danger: hex"#F7768E")

# --- design systems ----------------------------------------------------------

proc materialSpec*(): BrandSpec =
  ## A Material 3 look (m3.material.io): the baseline purple, pill buttons,
  ## generous controls, Roboto where it is installed.
  BrandSpec(name: "Material", accent: hex"#6750A4", onAccent: hex"#FFFFFF",
            canvas: hex"#FEF7FF", surface: hex"#FFFFFF", text: hex"#1D1B20",
            border: hex"#CAC4D0", radius: 20, fontFamily: "Roboto, sans-serif",
            padding: 10, paddingX: 24, controlHeight: 40, rowHeight: 48,
            info: hex"#6750A4", success: hex"#386A20", warning: hex"#7A5900",
            danger: hex"#B3261E")

proc fluentSpec*(): BrandSpec =
  ## A Fluent look (Windows 11): the system blue, 4 px corners, Segoe UI where
  ## it is installed.
  BrandSpec(name: "Fluent", accent: hex"#0067C0", onAccent: hex"#FFFFFF",
            canvas: hex"#F3F3F3", surface: hex"#FBFBFB", text: hex"#1A1A1A",
            border: hex"#E0E0E0", radius: 4, fontFamily: "Segoe UI, sans-serif",
            controlHeight: 32,
            info: hex"#0067C0", success: hex"#0F7B0F", warning: hex"#9D5D00",
            danger: hex"#C42B1C")

proc adwaitaSpec*(): BrandSpec =
  ## A GNOME Adwaita look (libadwaita): the GNOME blue, Cantarell where it is
  ## installed.
  BrandSpec(name: "Adwaita", accent: hex"#3584E4", onAccent: hex"#FFFFFF",
            canvas: hex"#FAFAFA", surface: hex"#FFFFFF", text: hex"#1E1E1E",
            border: hex"#DEDDDA", radius: 6, fontFamily: "Cantarell, sans-serif",
            controlHeight: 34,
            info: hex"#1C71D8", success: hex"#26A269", warning: hex"#9C6E03",
            danger: hex"#C01C28")

proc adwaitaDarkSpec*(): BrandSpec =
  ## Adwaita's dark style.
  BrandSpec(name: "Adwaita Dark", dark: true, accent: hex"#78AEED", onAccent: hex"#1E1E1E",
            canvas: hex"#1E1E1E", surface: hex"#303030", text: hex"#FFFFFF",
            border: hex"#454545", radius: 6, fontFamily: "Cantarell, sans-serif",
            controlHeight: 34,
            info: hex"#99C1F1", success: hex"#8FF0A4", warning: hex"#F8E45C",
            danger: hex"#FF7B63")

proc cupertinoSpec*(): BrandSpec =
  ## A Cupertino look (as Flutter names it): the system blue, quiet greys,
  ## rounded controls.
  BrandSpec(name: "Cupertino", accent: hex"#007AFF", onAccent: hex"#FFFFFF",
            canvas: hex"#F2F2F7", surface: hex"#FFFFFF", text: hex"#1C1C1E",
            border: hex"#D1D1D6", radius: 10,
            fontFamily: "SF Pro Text, Helvetica Neue, sans-serif",
            info: hex"#0062CC", success: hex"#248A3D", warning: hex"#9A5B00",
            danger: hex"#D70015")

proc popularThemes*(): seq[tuple[key: string, theme: Theme]] =
  ## Every popular palette and design system, by registry name.
  @[("nord", brandTheme(nordSpec())),
    ("nord-light", brandTheme(nordLightSpec())),
    ("dracula", brandTheme(draculaSpec())),
    ("solarized-light", brandTheme(solarizedLightSpec())),
    ("solarized-dark", brandTheme(solarizedDarkSpec())),
    ("gruvbox", brandTheme(gruvboxSpec())),
    ("catppuccin-latte", brandTheme(catppuccinLatteSpec())),
    ("catppuccin-mocha", brandTheme(catppuccinMochaSpec())),
    ("one-dark", brandTheme(oneDarkSpec())),
    ("tokyo-night", brandTheme(tokyoNightSpec())),
    ("material", brandTheme(materialSpec())),
    ("fluent", brandTheme(fluentSpec())),
    ("adwaita", brandTheme(adwaitaSpec())),
    ("adwaita-dark", brandTheme(adwaitaDarkSpec())),
    ("cupertino", brandTheme(cupertinoSpec()))]
