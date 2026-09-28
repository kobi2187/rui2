## The clipboard, behind a seam.
##
## Widgets copy and paste through `clipboardText` / `setClipboardText`, never
## through raylib: the system clipboard needs a window, and a test has none.
## The default is an in-memory clipboard, which is what a test gets; an App
## installs the system one when it opens its window (`useClipboard`).

type
  Clipboard* = object
    get*: proc(): string {.closure.}
    put*: proc(text: string) {.closure.}

proc memoryClipboard*(): Clipboard =
  ## A clipboard that lives in this process only.
  var held = ""
  Clipboard(get: proc(): string = held,
            put: proc(text: string) = held = text)

var activeClipboard = memoryClipboard()

proc useClipboard*(c: Clipboard) =
  activeClipboard = c

proc clipboardText*(): string =
  activeClipboard.get()

proc setClipboardText*(text: string) =
  activeClipboard.put(text)
