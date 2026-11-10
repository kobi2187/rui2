/* The few stb_truetype calls text_engine_stb.nim needs, behind plain C
 * functions. raylib bundles stb_truetype but compiles it static (private to
 * rtext.c), so this file compiles its own private copy from the same header;
 * the two never see each other's symbols. */
#define STBTT_STATIC
#define STB_TRUETYPE_IMPLEMENTATION
#include <stdlib.h>
#include "external/stb_truetype.h"

void *rui_stb_open(const unsigned char *data, int len) {
  (void)len;
  stbtt_fontinfo *f = (stbtt_fontinfo *)malloc(sizeof(stbtt_fontinfo));
  if (!f) return NULL;
  int offset = stbtt_GetFontOffsetForIndex(data, 0);
  if (offset < 0 || !stbtt_InitFont(f, data, offset)) { free(f); return NULL; }
  return f;
}
float rui_stb_scale_em(void *f, float px) {
  return stbtt_ScaleForMappingEmToPixels((stbtt_fontinfo *)f, px);
}
void rui_stb_vmetrics(void *f, int *ascent, int *descent, int *gap) {
  stbtt_GetFontVMetrics((stbtt_fontinfo *)f, ascent, descent, gap);
}
int rui_stb_glyph(void *f, int codepoint) {
  return stbtt_FindGlyphIndex((stbtt_fontinfo *)f, codepoint);
}
int rui_stb_advance(void *f, int glyph) {
  int adv, lsb;
  stbtt_GetGlyphHMetrics((stbtt_fontinfo *)f, glyph, &adv, &lsb);
  return adv;
}
int rui_stb_kern(void *f, int g1, int g2) {
  return stbtt_GetGlyphKernAdvance((stbtt_fontinfo *)f, g1, g2);
}
void rui_stb_box(void *f, int glyph, float scale, float shiftX,
                 int *x0, int *y0, int *x1, int *y1) {
  stbtt_GetGlyphBitmapBoxSubpixel((stbtt_fontinfo *)f, glyph, scale, scale,
                                  shiftX, 0.0f, x0, y0, x1, y1);
}
void rui_stb_render(void *f, unsigned char *out, int w, int h, int stride,
                    float scale, float shiftX, int glyph) {
  stbtt_MakeGlyphBitmapSubpixel((stbtt_fontinfo *)f, out, w, h, stride,
                                scale, scale, shiftX, 0.0f, glyph);
}
