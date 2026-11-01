## Themes with a personality: comic book, 90s soda, cyberpunk, woodshop,
## apothecary, reading paper, terminal, blueprint, synthwave, Swiss.
##
## Each is a `BrandSpec` (brand_themes.nim). The personality comes from the
## palette, the geometry (borders, corners, hard shadows, control sizes), the
## type, and a faint texture behind everything made in code (patterns.nim). The
## usability does not change from one to the next: every theme passes the same
## checks as the shipped brands (WCAG AA for every caption, a 3:1 focus ring,
## readable placeholders and selections), so where a palette's colour fails
## them for text (a pure #FF0000 on white does), the nearest shade that passes
## is used.
##
## Fonts are named with fallbacks: the first one installed is used, and the
## system's sans, serif or monospace when none is.
##
## ```nim
## app.setTheme("comic")       # or "soda", "cyberpunk", "blueprint", "swiss", ...
## ```

import theme_sys_core
import brand_themes

proc comicSpec*(): BrandSpec =
  ## Comic book and pop art: ink-black outlines, flat 4 px shadows with no
  ## blur, bold yellow for the main action, halftone dots behind.
  BrandSpec(name: "Comic", accent: hex"#FFD000", onAccent: hex"#111111",
            canvas: hex"#F4F1DE", surface: hex"#FFFDF4", text: hex"#111111",
            border: hex"#111111", radius: 4, borderWidth: 3, shadow: 4,
            shadowColor: hex"#111111", boldCaptions: true, uppercaseCaptions: true,
            fontFamily: "Inter, Montserrat, Helvetica, sans-serif",
            controlHeight: 40, focusRingWidth: 3,
            info: hex"#1D4ED8", success: hex"#1E7B34", warning: hex"#9A5800",
            danger: hex"#C1121F",
            pattern: "halftone", patternInk: hex"#E6394622")

proc sodaSpec*(): BrandSpec =
  ## A 90s soda commercial: neon teal and magenta on midnight navy, bubbly
  ## corners, carbonation behind.
  BrandSpec(name: "Soda", dark: true, accent: hex"#00F0FF", onAccent: hex"#0F0C1B",
            canvas: hex"#0F0C1B", surface: hex"#1C1733", text: hex"#F4F1FF",
            border: hex"#3E3370", radius: 18, controlHeight: 40, paddingX: 22,
            boldCaptions: true,
            fontFamily: "Nunito, Plus Jakarta Sans, Fredoka, sans-serif",
            info: hex"#C9A2FF", success: hex"#CCFF00", warning: hex"#FFD23F",
            danger: hex"#FF4FA3",
            pattern: "bubbles", patternInk: hex"#00F0FF1C")

proc cyberpunkSpec*(): BrandSpec =
  ## Cyberpunk HUD: laser cyan on deep space, thin outlines, glow only on
  ## focus, scanlines behind.
  BrandSpec(name: "Cyberpunk", dark: true, accent: hex"#00F5FF", onAccent: hex"#0B0D17",
            canvas: hex"#0B0D17", surface: hex"#161A2D", text: hex"#E2F6FF",
            border: hex"#2B3560", radius: 2, uppercaseCaptions: true,
            fontFamily: "JetBrains Mono, Space Grotesk, DejaVu Sans Mono, monospace",
            info: hex"#00F5FF", success: hex"#3DFF9A", warning: hex"#FF9900",
            danger: hex"#FF3D7F",
            pattern: "scanlines", patternInk: hex"#00F5FF0E")

proc woodshopSpec*(): BrandSpec =
  ## Artisan woodworking: walnut ink on canvas, oak for actions, pine and
  ## brass, wood grain behind.
  BrandSpec(name: "Woodshop", accent: hex"#8B5A2B", onAccent: hex"#FFFDF9",
            canvas: hex"#F7F4EF", surface: hex"#FFFDF9", text: hex"#3D2314",
            border: hex"#C5A059", radius: 6, borderWidth: 1.5, shadow: 1,
            shadowColor: hex"#3D231433",
            fontFamily: "Fira Sans, Zilla Slab, Arvo, sans-serif",
            info: hex"#2D4A3E", success: hex"#2D5F3A", warning: hex"#7E5A12",
            danger: hex"#9B2C1F",
            pattern: "grain", patternInk: hex"#8B5A2B16")

proc apothecarySpec*(): BrandSpec =
  ## Antique apothecary: sepia ink on aged parchment, wax-seal red, fine 1 px
  ## strokes, a classical serif, parchment fibres behind.
  BrandSpec(name: "Apothecary", accent: hex"#8B0000", onAccent: hex"#F5EBE0",
            canvas: hex"#F5EBE0", surface: hex"#FBF5EC", text: hex"#2B2118",
            border: hex"#9E7B66", radius: 2,
            fontFamily: "EB Garamond, Source Serif 4, Playfair Display, serif",
            fontSize: 15, padding: 9,
            info: hex"#1B3B2B", success: hex"#1B3B2B", warning: hex"#7A5212",
            danger: hex"#8B0000",
            pattern: "fibre", patternInk: hex"#9E7B6630")

proc paperSpec*(): BrandSpec =
  ## Yellowed paper for reading: charcoal ink on vintage paper, rust
  ## highlights, no glare, no gradients, a reading serif.
  BrandSpec(name: "Paper", accent: hex"#A94442", onAccent: hex"#FFFBF0",
            canvas: hex"#F4ECD8", surface: hex"#F8F2E2", text: hex"#2C2C2A",
            border: hex"#D6C9A8", radius: 3,
            fontFamily: "Charter, Literata, Merriweather, serif",
            fontSize: 15, padding: 9,
            info: hex"#3E5C76", success: hex"#3F6B3A", warning: hex"#7D5A14",
            danger: hex"#A94442",
            pattern: "fibre", patternInk: hex"#2C2C2A10")

proc terminalSpec*(): BrandSpec =
  ## 1980s terminal: phosphor green on black, square, monospaced, hover and
  ## selection inverted, scanlines behind.
  BrandSpec(name: "Terminal", dark: true, accent: hex"#00FF66", onAccent: hex"#050505",
            canvas: hex"#050505", surface: hex"#08110B", text: hex"#33FF88",
            border: hex"#1D6B3C", radius: 0, highContrast: true, noTransitions: true,
            fontFamily: "IBM Plex Mono, Fira Code, VT323, DejaVu Sans Mono, monospace",
            info: hex"#33DDFF", success: hex"#00FF66", warning: hex"#FFB000",
            danger: hex"#FF5F56",
            pattern: "scanlines", patternInk: hex"#00FF6612")

proc terminalAmberSpec*(): BrandSpec =
  ## The amber monitor.
  BrandSpec(name: "Terminal Amber", dark: true, accent: hex"#FFB000", onAccent: hex"#050505",
            canvas: hex"#050505", surface: hex"#120D04", text: hex"#FFC233",
            border: hex"#6B4A10", radius: 0, highContrast: true, noTransitions: true,
            fontFamily: "IBM Plex Mono, Fira Code, VT323, DejaVu Sans Mono, monospace",
            info: hex"#FFD27A", success: hex"#D4E157", warning: hex"#FFB000",
            danger: hex"#FF6E40",
            pattern: "scanlines", patternInk: hex"#FFB00012")

proc blueprintSpec*(): BrandSpec =
  ## An architectural blueprint: white ink on cyanotype blue, graph-paper
  ## grid, sharp corners, graph-yellow for the main action.
  BrandSpec(name: "Blueprint", dark: true, accent: hex"#FFD166", onAccent: hex"#003366",
            canvas: hex"#003366", surface: hex"#063C72", text: hex"#FFFFFF",
            border: hex"#7FA7D1", radius: 0,
            fontFamily: "Roboto Mono, DIN, DejaVu Sans Mono, monospace",
            info: hex"#9AD0FF", success: hex"#8EE69B", warning: hex"#FFD166",
            danger: hex"#FF9A8F",
            pattern: "graph", patternInk: hex"#1A5276")

proc synthwaveSpec*(): BrandSpec =
  ## Vaporwave sunset: peach and mint on deep indigo, hierarchy by hue, a
  ## violet grid behind.
  BrandSpec(name: "Synthwave", dark: true, accent: hex"#FF758C", onAccent: hex"#12002B",
            canvas: hex"#12002B", surface: hex"#200B45", text: hex"#F7EBFF",
            border: hex"#4F2C85", radius: 10, boldCaptions: true,
            fontFamily: "Outfit, Kanit, sans-serif",
            info: hex"#70E0D6", success: hex"#7CF5A6", warning: hex"#FFC46B",
            danger: hex"#FF6B8B",
            pattern: "grid", patternInk: hex"#8A2BE222")

proc swissSpec*(): BrandSpec =
  ## Swiss / International style: white, off-black, one red; no corners, no
  ## shadows, no texture, thick rules.
  BrandSpec(name: "Swiss", accent: hex"#E00000", onAccent: hex"#FFFFFF",
            canvas: hex"#FFFFFF", surface: hex"#FFFFFF", text: hex"#1A1A1A",
            border: hex"#1A1A1A", radius: 0, borderWidth: 2, boldCaptions: true,
            fontFamily: "Helvetica Now, Neue Haas Grotesk, Helvetica Neue, Inter, Helvetica, sans-serif",
            info: hex"#002FA7", success: hex"#1A7F37", warning: hex"#8F5A00",
            danger: hex"#E00000")

proc swissKleinSpec*(): BrandSpec =
  ## Swiss with International Klein Blue.
  var s = swissSpec()
  s.name = "Swiss Klein"
  s.accent = hex"#002FA7"
  s.info = hex"#002FA7"
  s

proc swissDarkSpec*(): BrandSpec =
  ## Swiss on deep dark.
  BrandSpec(name: "Swiss Dark", dark: true, accent: hex"#FF3B30", onAccent: hex"#111111",
            canvas: hex"#111111", surface: hex"#111111", text: hex"#F5F5F5",
            border: hex"#F5F5F5", radius: 0, borderWidth: 2, boldCaptions: true,
            fontFamily: "Helvetica Now, Neue Haas Grotesk, Helvetica Neue, Inter, Helvetica, sans-serif",
            info: hex"#6E8BFF", success: hex"#4ADE80", warning: hex"#FFB020",
            danger: hex"#FF3B30")

proc characterThemes*(): seq[tuple[key: string, theme: Theme]] =
  ## Every themed personality, by registry name.
  @[("comic", brandTheme(comicSpec())),
    ("soda", brandTheme(sodaSpec())),
    ("cyberpunk", brandTheme(cyberpunkSpec())),
    ("woodshop", brandTheme(woodshopSpec())),
    ("apothecary", brandTheme(apothecarySpec())),
    ("paper", brandTheme(paperSpec())),
    ("terminal", brandTheme(terminalSpec())),
    ("terminal-amber", brandTheme(terminalAmberSpec())),
    ("blueprint", brandTheme(blueprintSpec())),
    ("synthwave", brandTheme(synthwaveSpec())),
    ("swiss", brandTheme(swissSpec())),
    ("swiss-klein", brandTheme(swissKleinSpec())),
    ("swiss-dark", brandTheme(swissDarkSpec()))]
