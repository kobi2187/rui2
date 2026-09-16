# packages/rui_widgets/src/dialogs/messagebox.nim

## Purpose

Modal message and confirmation dialog: Info, Warning, Error or Question, with
one of four button sets.

## Public interface

- `MessageBoxType*` — `mbInfo`, `mbWarning`, `mbError`, `mbQuestion`.
- `MessageBoxButtons*` — `mbOK`, `mbOKCancel`, `mbYesNo`, `mbYesNoCancel`.
- `MessageBoxResult*` — `mrNone`, `mrOK`, `mrCancel`, `mrYes`, `mrNo`.
- `DialogButton*` — `label`, `res`, `rect`.
- `newMessageBox*(title = "Message", message = "", messageType = mbInfo,
  buttons = mbOK, dialogWidth = 400.0, dialogHeight = 200.0, onClose)`.
- `show*(widget: MessageBox)` — display it; resets `dialogResult` to `mrNone`.
- `dialogButtons*(panel: Rect, buttons: MessageBoxButtons): seq[DialogButton]` —
  button rects, laid out right to left along the bottom. **Hit-testing and
  painting both read this**, so a click always lands on the button drawn there.
- State: `isVisible`, `dialogResult`, `hoverResult`.

Escape cancels (or OKs, when `mbOK` is the only button); Enter takes the first,
affirmative button. The modal swallows every click, including misses.

## Usage pattern

```nim
let confirm = newMessageBox(title = "Confirm", message = "Discard changes?",
                            messageType = mbQuestion, buttons = mbYesNoCancel)
confirm.onClose = some(proc(res: MessageBoxResult) {.closure.} = ...)
confirm.show()
```

Add it **last** among its siblings so it composites over them.

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where the buttons were raygui `GuiButton`
calls fired from inside `render`, `mbYesNoCancel` was `# TODO: Three buttons /
discard`, and the message ran off the panel edge (`# TODO: Word wrap`). All
three are handled now.

**Two enum mappings exist as procs with declared return types** —
`intentFor` and `alertLevelFor`. `rui_core` re-exports raylib wholesale, so
`Info`, `Warning`, `Error` and `Default` are ambiguous inside a macro body
where there is no expected type to resolve against; a proc's declared return
type supplies one. `AlertLevel` is `Info`/`Alert`/`Critical`, which is not the
same set as `ThemeIntent`.
</content>
