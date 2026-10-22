## While a modal is open, the page behind it is a still picture.
##
## A modal dialog asks one question and nothing behind it can be used until
## it is answered, so nothing behind it needs to run either. When a modal
## opens (`freezeBehind`), the App renders the page once more without it and
## keeps that picture -- through the theme's backdrop look: dimmed, blurred,
## faded, done once -- as the modal's `backdrop`. From then on only the
## modal's own subtree is laid out and painted. The page is not visible: its
## animations, caret blink and decorations stop asking for frames because
## nothing calls them, and the window idles while the dialog waits. Whatever
## changed in the page meanwhile (data arriving, say) is still marked dirty,
## and is drawn the frame the last modal closes.
##
## The picture is taken again if the window is resized or the theme changes
## while the modal is open: one pass of the page at the new size, then still
## again. Modals stack: a message box over a file dialog freezes the dialog
## too, and closing it returns to the dialog, still over a frozen page.

import types
import animation
import raylib
import std/[options, sets]

type FrozenPage = object
  modal: Widget
  backdrop: Option[RenderTexture2D]    # the page as it was, in the theme's backdrop look
  pictureCurrent: bool                 # backdrop shows the page's last pass
  pagePassed: bool                     # the page had its last pass behind this modal
  size: Size                           # the root's size then
  epoch: int                           # settleEpoch then (a theme change retakes it)

var frozen: seq[FrozenPage]            # open modals, the newest last
var watched: HashSet[pointer]          # modals that thaw when disposed

proc thaw*(modal: Widget)

proc freezeBehind*(modal: Widget) =
  ## `modal` has opened: the page behind it stops (see the module comment).
  for f in frozen:
    if f.modal == modal: return
  frozen.add FrozenPage(modal: modal)
  # A modal thrown away while open must not leave the page frozen. Once per
  # modal, however often it opens.
  let key = cast[pointer](modal)
  if key notin watched:
    watched.incl key
    modal.disposers.add proc() =
      watched.excl key
      thaw(modal)

proc thaw*(modal: Widget) =
  ## `modal` has closed: drop its picture; the page (or the modal below)
  ## runs again.
  for i in countdown(frozen.high, 0):
    if frozen[i].modal == modal:
      frozen.delete(i)               # its texture is unloaded by its destructor
      return

proc rootOf(w: Widget): Widget =
  result = w
  while result.parent != nil: result = result.parent

proc frozenBy*(root: Widget): Widget =
  ## The modal the page under `root` is frozen behind (the newest one open in
  ## that tree), or nil. One taken out of the tree no longer counts.
  for i in countdown(frozen.high, 0):
    let m = frozen[i].modal
    if m.visible and m != root and m.rootOf == root: return m
  nil

proc needsPagePass*(modal: Widget, root: Widget): bool =
  ## Whether the page behind `modal` must be laid out (and pictured) once
  ## more: it has not been since the modal opened, the window has another
  ## size, the root was relaid, or the theme changed.
  let size = Size(width: root.bounds.width, height: root.bounds.height)
  for f in frozen:
    if f.modal == modal:
      return not f.pagePassed or f.size != size or f.epoch != settleEpoch or
             root.layoutDirty
  false

proc pagePassed*(modal: Widget, root: Widget) =
  ## The page behind `modal` has just had that pass; its picture is now old.
  for f in frozen.mitems:
    if f.modal == modal:
      f.pagePassed = true
      f.pictureCurrent = false
      f.size = Size(width: root.bounds.width, height: root.bounds.height)
      f.epoch = settleEpoch

proc needsPicture*(modal: Widget): bool =
  ## Whether the picture behind `modal` has to be taken (again).
  for f in frozen:
    if f.modal == modal: return not f.pictureCurrent
  false

proc setBackdrop*(modal: Widget, picture: sink RenderTexture2D) =
  var at = -1
  for i in 0 .. frozen.high:
    if frozen[i].modal == modal: at = i
  if at >= 0:
    frozen[at].backdrop = some(picture)
    frozen[at].pictureCurrent = true

proc backdropOf*(modal: Widget): ptr RenderTexture2D =
  ## The still picture `modal` draws behind its panel once the App has taken
  ## it, or nil. Borrowed: good until the modal closes or it is retaken.
  for f in frozen.mitems:
    if f.modal == modal and f.backdrop.isSome: return addr f.backdrop.get
  nil

proc thawAll*() =
  ## Forget every frozen page: for an App shutting down (the pictures are GPU
  ## textures and must go before the window does), and for tests.
  frozen.setLen(0)
