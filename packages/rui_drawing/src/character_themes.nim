## Themes with a personality: comic book, 90s soda, cyberpunk, woodshop,
## apothecary, reading paper, terminal, blueprint, synthwave, Swiss.
##
## Each is a `BrandSpec` (brand_themes.nim). The personality comes from the
## palette, the geometry (borders, corners, hard shadows, control sizes), the
## type, and a picture tiled behind everything (tiles.nim: wood planks,
## parchment, halftone dots, graph paper, scanlines...). The
## usability does not change from one to the next: every theme passes the same
## checks as the shipped brands (WCAG AA for every caption, a 3:1 focus ring,
## readable placeholders and selections), so where a palette's colour fails
## them for text (a pure #FF0000 on white does), the nearest shade that passes
## is used.
##
## Fonts are named with fallbacks: the first one installed is used, and the
## system's sans, serif or monospace when none is. Each has a heading font
## (titles, Label(heading = true)) beside its body font.
##
## ```nim
## app.setTheme("comic")       # or "soda", "cyberpunk", "blueprint", "swiss", ...
## ```

import theme_sys_core
import brand_themes

proc comicSpec*(): BrandSpec =
  ## Comic book and pop art: ink-black outlines, flat 4 px shadows with no
  ## blur, bold yellow for the main action, tooltips as speech bubbles,
  ## halftone dots behind.
  BrandSpec(name: "Comic", accent: hex"#FFD000", onAccent: hex"#111111",
            canvas: hex"#F4F1DE", surface: hex"#FFFDF4", text: hex"#111111",
            border: hex"#111111", radius: 4, borderWidth: 3, shadow: 4,
            shadowColor: hex"#111111", boldCaptions: true, uppercaseCaptions: true,
            fontFamily: "Inter, Montserrat, Helvetica, sans-serif",
            headingFont: "Bangers, Impact, Anton, Montserrat ExtraBold, sans-serif",
            controlHeight: 40, focusRingWidth: 3,
            info: hex"#1D4ED8", success: hex"#1E7B34", warning: hex"#9A5800",
            danger: hex"#C1121F",
            background: "tile:halftone", backgroundTint: hex"#E63946",
            backgroundOpacity: 0.13,
            speechBubbleTips: true)

proc sodaSpec*(): BrandSpec =
  ## A 90s soda commercial: neon teal and magenta on midnight navy, bubbly
  ## corners, glossy buttons, carbonation behind.
  BrandSpec(name: "Soda", dark: true, accent: hex"#00F0FF", onAccent: hex"#0F0C1B",
            canvas: hex"#0F0C1B", surface: hex"#1C1733", text: hex"#F4F1FF",
            border: hex"#3E3370", radius: 18, controlHeight: 40, paddingX: 22,
            boldCaptions: true,
            fontFamily: "Nunito, Plus Jakarta Sans, sans-serif",
            headingFont: "Fredoka, Comfortaa, Nunito, sans-serif",
            info: hex"#C9A2FF", success: hex"#CCFF00", warning: hex"#FFD23F",
            danger: hex"#FF4FA3",
            background: "tile:bubbles", backgroundTint: hex"#00F0FF",
            backgroundOpacity: 0.11,
            gloss: 0.6)

proc cyberpunkSpec*(): BrandSpec =
  ## Cyberpunk HUD: laser cyan on deep space, notched corners, thin outlines,
  ## a neon glow only round the focused control, scanlines behind.
  BrandSpec(name: "Cyberpunk", dark: true, accent: hex"#00F5FF", onAccent: hex"#0B0D17",
            canvas: hex"#0B0D17", surface: hex"#161A2D", text: hex"#E2F6FF",
            border: hex"#2B3560", radius: 2, uppercaseCaptions: true,
            fontFamily: "JetBrains Mono, Space Grotesk, DejaVu Sans Mono, monospace",
            headingFont: "Orbitron, Space Grotesk, JetBrains Mono, monospace",
            info: hex"#00F5FF", success: hex"#3DFF9A", warning: hex"#FF9900",
            danger: hex"#FF3D7F",
            background: "tile:scanlines", backgroundTint: hex"#00F5FF",
            backgroundOpacity: 0.055,
            cornerCut: 8, focusGlow: 7)

proc woodshopSpec*(): BrandSpec =
  ## Artisan woodworking: walnut ink, oak for actions, pine and brass; buttons
  ## softly bevelled and fields carved in; light oak planks behind (at half
  ## strength, so text on them still reads).
  BrandSpec(name: "Woodshop", accent: hex"#8B5A2B", onAccent: hex"#FFFDF9",
            canvas: hex"#F7F4EF", surface: hex"#FFFDF9", text: hex"#3D2314",
            border: hex"#C5A059", radius: 6, borderWidth: 1.5, shadow: 1,
            shadowColor: hex"#3D231433",
            fontFamily: "Fira Sans, Lora, sans-serif",
            headingFont: "Zilla Slab, Arvo, Rockwell, DejaVu Serif, serif",
            info: hex"#2D4A3E", success: hex"#2D5F3A", warning: hex"#7E5A12",
            danger: hex"#9B2C1F",
            background: "tile:wood", backgroundOpacity: 0.45,
            relief: 2.5)

proc apothecarySpec*(): BrandSpec =
  ## Antique apothecary: sepia ink on aged parchment, wax-seal red, fine 1 px
  ## strokes, a classical serif, on a parchment tile.
  BrandSpec(name: "Apothecary", accent: hex"#8B0000", onAccent: hex"#F5EBE0",
            canvas: hex"#F5EBE0", surface: hex"#FBF5EC", text: hex"#2B2118",
            border: hex"#9E7B66", radius: 2,
            fontFamily: "EB Garamond, Source Serif 4, serif",
            headingFont: "Cinzel, Playfair Display, EB Garamond, serif",
            fontSize: 15, padding: 9,
            info: hex"#1B3B2B", success: hex"#1B3B2B", warning: hex"#7A5212",
            danger: hex"#8B0000",
            background: "tile:parchment", backgroundOpacity: 0.85)

proc paperSpec*(): BrandSpec =
  ## Yellowed paper for reading: charcoal ink on vintage paper, rust
  ## highlights, no glare, no gradients, a reading serif.
  BrandSpec(name: "Paper", accent: hex"#A94442", onAccent: hex"#FFFBF0",
            canvas: hex"#F4ECD8", surface: hex"#F8F2E2", text: hex"#2C2C2A",
            border: hex"#D6C9A8", radius: 3,
            fontFamily: "Charter, Literata, Merriweather, serif",
            headingFont: "Literata, Charter, Merriweather, serif",
            fontSize: 15, padding: 9,
            info: hex"#3E5C76", success: hex"#3F6B3A", warning: hex"#7D5A14",
            danger: hex"#A94442",
            background: "tile:paper", backgroundOpacity: 0.8)

proc terminalSpec*(): BrandSpec =
  ## 1980s terminal: phosphor green on black, square, monospaced, hover and
  ## selection inverted, scanlines behind.
  BrandSpec(name: "Terminal", dark: true, accent: hex"#00FF66", onAccent: hex"#050505",
            canvas: hex"#050505", surface: hex"#08110B", text: hex"#33FF88",
            border: hex"#1D6B3C", radius: 0, highContrast: true, noTransitions: true,
            fontFamily: "IBM Plex Mono, Fira Code, DejaVu Sans Mono, monospace",
            headingFont: "VT323, IBM Plex Mono, DejaVu Sans Mono, monospace",
            info: hex"#33DDFF", success: hex"#00FF66", warning: hex"#FFB000",
            danger: hex"#FF5F56",
            background: "tile:scanlines", backgroundTint: hex"#00FF66",
            backgroundOpacity: 0.07)

proc terminalAmberSpec*(): BrandSpec =
  ## The amber monitor.
  BrandSpec(name: "Terminal Amber", dark: true, accent: hex"#FFB000", onAccent: hex"#050505",
            canvas: hex"#050505", surface: hex"#120D04", text: hex"#FFC233",
            border: hex"#6B4A10", radius: 0, highContrast: true, noTransitions: true,
            fontFamily: "IBM Plex Mono, Fira Code, DejaVu Sans Mono, monospace",
            headingFont: "VT323, IBM Plex Mono, DejaVu Sans Mono, monospace",
            info: hex"#FFD27A", success: hex"#D4E157", warning: hex"#FFB000",
            danger: hex"#FF6E40",
            background: "tile:scanlines", backgroundTint: hex"#FFB000",
            backgroundOpacity: 0.07)

proc blueprintSpec*(): BrandSpec =
  ## An architectural blueprint: white ink on cyanotype blue, outlines drawn
  ## as dimension lines, graph paper behind, graph-yellow for the main action.
  BrandSpec(name: "Blueprint", dark: true, accent: hex"#FFD166", onAccent: hex"#003366",
            canvas: hex"#003366", surface: hex"#063C72", text: hex"#FFFFFF",
            border: hex"#7FA7D1", radius: 0,
            fontFamily: "Roboto Mono, DejaVu Sans Mono, monospace",
            headingFont: "Architects Daughter, DIN, Roboto Mono, monospace",
            info: hex"#9AD0FF", success: hex"#8EE69B", warning: hex"#FFD166",
            danger: hex"#FF9A8F",
            background: "tile:graph", backgroundTint: hex"#1A5276",
            dimensionLines: true)

proc synthwaveSpec*(): BrandSpec =
  ## Vaporwave sunset: peach and mint on deep indigo, hierarchy by hue, a
  ## violet grid behind.
  BrandSpec(name: "Synthwave", dark: true, accent: hex"#FF758C", onAccent: hex"#12002B",
            canvas: hex"#12002B", surface: hex"#200B45", text: hex"#F7EBFF",
            border: hex"#4F2C85", radius: 10, boldCaptions: true,
            fontFamily: "Outfit, Inter, sans-serif",
            headingFont: "Kanit, Outfit, sans-serif",
            info: hex"#70E0D6", success: hex"#7CF5A6", warning: hex"#FFC46B",
            danger: hex"#FF6B8B",
            background: "tile:grid", backgroundTint: hex"#8A2BE2",
            backgroundOpacity: 0.13,
            focusGlow: 7, gloss: 0.2)

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
