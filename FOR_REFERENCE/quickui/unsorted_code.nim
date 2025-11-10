Error handling improvements:

type
  MessageError* = object of CatchableError
  ParseError* = object of MessageError
  TimeoutError* = object of MessageError
  StateError* = object of MessageError

proc readMessages(mf: MessageFile, direction: Direction): seq[string] =
  try:
    acquireLock(mf.lock)
    let path = if direction == ToGui: mf.inPath else: mf.outPath
    let content = readFile(path)
    if content.len > 0:
      var pos = 0
      while pos < content.len:
        let colonPos = content.find(':', pos)
        if colonPos == -1: break  # No more messages
        
        try:
          let msgLen = parseInt(content[pos..<colonPos])
          if colonPos + msgLen + 1 > content.len:
            # Incomplete message, leave in file
            break
          
          let msg = content[colonPos+1..colonPos+msgLen]
          result.add(msg)
          pos = colonPos + msgLen + 2  # +2 for colon and newline
        except ValueError:
          # Invalid length prefix, skip to next message
          pos = content.find('\n', pos)
          if pos == -1: break
          inc pos
          continue
      
      # Remove processed messages
      if pos > 0:
        writeFile(path, content[pos..^1])
  finally:
    releaseLock(mf.lock)