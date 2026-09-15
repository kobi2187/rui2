import pango_text, pango_binding
echo "font desc: ", fontDescString("", 14.0)
echo "bold:      ", fontDescString("DejaVu Sans", 18.0, bold = true)
let m = measureTextPango("Hello, RUI2", fontDescString("", 18.0))
echo "measure 'Hello, RUI2' @18: w=", m.width, " h=", m.height, " baseline=", m.baseline
let m2 = measureTextPango("Hello, RUI2", fontDescString("", 36.0))
echo "measure same @36:          w=", m2.width, " h=", m2.height
let m3 = measureTextPango("שלום עולם مرحبا 你好", fontDescString("", 18.0))
echo "measure mixed BiDi/CJK:    w=", m3.width, " h=", m3.height
