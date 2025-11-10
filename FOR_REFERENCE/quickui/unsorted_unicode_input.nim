type
  Rune = distinct uint32  # Unicode codepoint
  
  TextBuffer = object
    runes: seq[Rune]     # Store as Unicode codepoints
    cursor: int          # Position in runes (not bytes)
    selection: Option[Slice[int]]

  TextInput = ref object
    buffer: TextBuffer
    placeholder: string
    width: float32
    height: float32
    multiline: bool

proc handleInput(input: TextInput, rune: Rune) =
  input.buffer.runes.insert(rune, input.buffer.cursor)
  inc input.buffer.cursor

proc handleDelete(input: TextInput) =
  if input.buffer.cursor > 0:
    input.buffer.runes.delete(input.buffer.cursor - 1)
    dec input.buffer.cursor