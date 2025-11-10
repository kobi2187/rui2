## Wrapper for pangolib_binding that works with RUI2
## Re-exports the Pango+Cairo→Raylib pipeline
##
## This wrapper provides a clean interface to pangolib_binding.
## The external pangolib_binding library must be available as a sibling directory.

import raylib
import std/[options, results]

# Try to import real pangolib_binding
# If not available, provide fallback types
when defined(usePango) and not defined(noPango):
  # Import from sibling directory pangolib_binding
  # From pango_integration/ we need to go ../.. to reach sibling
  when fileExists("../../pangolib_binding/src/pangotypes.nim"):
    import ../../pangolib_binding/src/[pangotypes, pangocore]
    export pangotypes, pangocore

    # Re-export main functions
    export initTextLayout, freeTextLayout
    export getCursorPosition, getTextIndexFromPosition

    const PangoAvailable* = true

  else:
    # pangolib_binding not found, provide fallback types
    const PangoAvailable* = false

    type
      PangoError* = enum
        peInitFailed
        peRenderFailed
        peInvalidInput
        pePangoNotAvailable

      PangoErrorInfo* = object
        kind*: PangoError
        message*: string

      TextLayout* = object
        text*: string
        texture*: Texture2D
        width*, height*: int32

    proc initTextLayout*(text: string, maxWidth: int32 = -1): Result[TextLayout, PangoErrorInfo] =
      ## Fallback when pangolib_binding not available
      err(PangoErrorInfo(
        kind: pePangoNotAvailable,
        message: "pangolib_binding not found. Install it as sibling directory to rui2, or use -d:noPango to disable Pango"
      ))

    proc freeTextLayout*(layout: var TextLayout) =
      ## Fallback cleanup (noop)
      if layout.texture.id != 0:
        unloadTexture(layout.texture)

    proc getCursorPosition*(layout: TextLayout, index: int): Result[(int32, int32), PangoErrorInfo] =
      ## Fallback cursor position
      err(PangoErrorInfo(
        kind: pePangoNotAvailable,
        message: "Pango not available"
      ))

    proc getTextIndexFromPosition*(layout: TextLayout, x, y: int32): Result[int, PangoErrorInfo] =
      ## Fallback index lookup
      err(PangoErrorInfo(
        kind: pePangoNotAvailable,
        message: "Pango not available"
      ))

else:
  # Pango explicitly disabled or not requested
  const PangoAvailable* = false

  type
    PangoError* = enum
      peInitFailed
      peRenderFailed
      peInvalidInput
      pePangoDisabled

    PangoErrorInfo* = object
      kind*: PangoError
      message*: string

    TextLayout* = object
      text*: string
      texture*: Texture2D
      width*, height*: int32

  proc initTextLayout*(text: string, maxWidth: int32 = -1): Result[TextLayout, PangoErrorInfo] =
    ## Pango disabled, return error
    err(PangoErrorInfo(
      kind: pePangoDisabled,
      message: "Pango support disabled. Compile with -d:usePango to enable"
    ))

  proc freeTextLayout*(layout: var TextLayout) =
    ## Cleanup (noop when disabled)
    if layout.texture.id != 0:
      unloadTexture(layout.texture)

  proc getCursorPosition*(layout: TextLayout, index: int): Result[(int32, int32), PangoErrorInfo] =
    err(PangoErrorInfo(kind: pePangoDisabled, message: "Pango disabled"))

  proc getTextIndexFromPosition*(layout: TextLayout, x, y: int32): Result[int, PangoErrorInfo] =
    err(PangoErrorInfo(kind: pePangoDisabled, message: "Pango disabled"))

# Helper procs that work regardless of Pango availability

proc isPangoAvailable*(): bool =
  ## Check if Pango is actually available at runtime
  PangoAvailable

proc renderTextWithRaylib*(text: string, fontSize: int32 = 20, color: Color = BLACK): Texture2D =
  ## Fallback: render text using Raylib
  ## Useful when Pango not available or for simple cases
  let textWidth = measureText(text.cstring, fontSize)
  let textHeight = fontSize + 4

  # Create render texture
  let renderTex = loadRenderTexture(textWidth, textHeight)

  beginTextureMode(renderTex)
  clearBackground(Color(r: 0, g: 0, b: 0, a: 0))  # Transparent background
  drawText(text.cstring, 0, 0, fontSize, color)
  endTextureMode()

  result = renderTex.texture

## Usage Instructions:
##
## 1. To use Pango, install pangolib_binding as sibling to rui2:
##    ```
##    /home/user/
##      ├── rui2/
##      └── pangolib_binding/
##          └── src/
##              ├── pangotypes.nim
##              └── pangocore.nim
##    ```
##
## 2. Compile with -d:usePango:
##    ```bash
##    nim c -d:usePango -d:useGraphics your_app.nim
##    ```
##
## 3. Check availability at runtime:
##    ```nim
##    if isPangoAvailable():
##      echo "Using Pango for text rendering"
##    else:
##      echo "Pango not available, using Raylib fallback"
##    ```
##
## 4. Use the API:
##    ```nim
##    let result = initTextLayout("Hello World", maxWidth = 400)
##    if result.isOk:
##      var layout = result.get()
##      defer: freeTextLayout(layout)
##      drawTexture(layout.texture, 100, 100, WHITE)
##    else:
##      echo "Error: ", result.error.message
##    ```
