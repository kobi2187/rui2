## Which text engine is linked. Pango (with Cairo, GLib and fontconfig) on the
## desktop; on Android, where none of those exist, a self-contained engine on
## stb_truetype. `-d:ruiTextStb` picks the stb engine on the desktop too, to
## see on the host what a phone will draw (mobile/compare/).
##
## An engine provides: `engineName`, `engineSetOptions`, `engineMeasure`,
## `engineCharAttrs`, `moveCaretVisually`, `softBreaks`, `cursorPosition`,
## `indexFromPosition`, `engineRasteriseA8`, `engineRasteriseArgb32`,
## `paragraphDir` -- the signatures in text_engine_pango.nim.

when defined(android) or defined(ruiTextStb):
  import text_engine_stb
  export text_engine_stb
else:
  import text_engine_pango
  export text_engine_pango
