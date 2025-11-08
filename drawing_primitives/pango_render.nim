# Text Layout & Measurement
proc layout = pango.layout_new(context)
pango.layout_set_text(layout, text, -1)
let (width, height) = pango.layout_get_size(layout)
let lineCount = pango.layout_get_line_count(layout)

# Cursor & Selection
proc getPosition(layout: PangoLayout, index: int): tuple[x, y: int] =
  var rect: PangoRectangle
  pango.layout_index_to_pos(layout, index, addr rect)

# Hit Testing
proc getIndex(layout: PangoLayout, x, y: int): int =
  var index: int
  var trailing: int
  pango.layout_xy_to_index(layout, x * PANGO_SCALE, y * PANGO_SCALE, 
                          addr index, addr trailing)

# Logical Attributes (word boundaries etc)
var attrs: ptr PangoLogAttr
var nAttrs: int
pango.layout_get_log_attrs(layout, addr attrs, addr nAttrs)
# Gives word boundaries, sentence boundaries, line breaks etc

# Bidirectional Text
pango.layout_set_auto_dir(layout, true)  # Automatic direction handling

# Unicode handling
let text = "Hello"
let len = pango.utf8_strlen(text)  # Proper character count



=============================

type
  TextArea* = ref object of Widget
    layout: PangoLayout
    context: PangoContext
    # Cache
    textureCache: RenderTexture
    cacheValid: bool
    lastText: string
    lastWidth: float32
    # Cache invalidation triggers
    lastStyle: TextStyle
    lastSelection: TextSelection
    lastCursorPos: int

proc invalidateCache*(area: TextArea) =
  area.cacheValid = false

proc shouldUpdateCache(area: TextArea): bool =
  # Check if we need to re-render
  if not area.cacheValid: return true
  if area.text != area.lastText: return true
  if area.width != area.lastWidth: return true
  if area.style != area.lastStyle: return true
  if area.selection != area.lastSelection: return true
  if area.cursor.position != area.lastCursorPos: return true
  false

proc updateCache(area: TextArea) =
  # Create or resize texture if needed
  if area.textureCache == nil or
     area.textureCache.width != area.width.int32 or
     area.textureCache.height != area.height.int32:
    if area.textureCache != nil:
      unloadRenderTexture(area.textureCache)
    area.textureCache = loadRenderTexture(
      area.width.int32, 
      area.height.int32
    )

  # Setup Pango layout
  pango.layout_set_width(area.layout, 
    cint(area.width * PANGO_SCALE))
  pango.layout_set_text(area.layout, area.text, -1)
  
  # Set text attributes (style)
  var attrs = pango.attr_list_new()
  defer: pango.attr_list_unref(attrs)
  
  # Font
  let desc = pango.font_description_new()
  pango.font_description_set_family(desc, area.style.fontFamily)
  pango.font_description_set_size(desc, 
    cint(area.style.fontSize * PANGO_SCALE))
  pango.layout_set_font_description(area.layout, desc)
  
  # Begin rendering to texture
  beginTextureMode(area.textureCache)
  clearBackground(area.style.backgroundColor)
  
  # Draw selection if any
  if area.hasSelection:
    let (start, finish) = area.selection.getSortedRange()
    var selRect: PangoRectangle
    pango.layout_get_selection_bounds(area.layout, 
      cint(start), cint(finish), addr selRect)
    drawRectangle(
      selRect.x.int32 div PANGO_SCALE,
      selRect.y.int32 div PANGO_SCALE,
      selRect.width.int32 div PANGO_SCALE,
      selRect.height.int32 div PANGO_SCALE,
      area.style.selectionColor
    )

  # Draw text
  var cr = cairo.create(area.textureCache.surface)
  defer: cairo.destroy(cr)
  
  # Set color
  cairo.set_source_rgba(cr, 
    area.style.textColor.r.cdouble / 255,
    area.style.textColor.g.cdouble / 255,
    area.style.textColor.b.cdouble / 255,
    area.style.textColor.a.cdouble / 255
  )
  
  pango.cairo_show_layout(cr, area.layout)
  
  # Draw cursor if needed
  if area.editable and area.focused and area.cursor.visible:
    var cursorRect: PangoRectangle
    pango.layout_get_cursor_pos(area.layout, 
      cint(area.cursor.position), 
      addr cursorRect, nil)
    drawRectangle(
      cursorRect.x.int32 div PANGO_SCALE,
      cursorRect.y.int32 div PANGO_SCALE,
      2, # cursor width
      cursorRect.height.int32 div PANGO_SCALE,
      area.style.cursorColor
    )
  
  endTextureMode()
  
  # Update cache status
  area.lastText = area.text
  area.lastWidth = area.width
  area.lastStyle = area.style
  area.lastSelection = area.selection
  area.lastCursorPos = area.cursor.position
  area.cacheValid = true

method draw*(area: TextArea) =
  if area.shouldUpdateCache():
    area.updateCache()
  
  # Just draw the cached texture
  drawTexturePro(
    area.textureCache.texture,
    Rectangle(x: 0, y: 0, 
             width: area.width.float32,
             height: -area.height.float32), # Flip vertically
    Rectangle(x: area.x, y: area.y,
             width: area.width,
             height: area.height),
    Vector2(x: 0, y: 0),
    0.0f,
    White
  )