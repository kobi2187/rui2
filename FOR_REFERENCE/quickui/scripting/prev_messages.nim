# messages.nim
import os, json, locks
import threading/channels

type
  MessageFile* = object
    path: string
    lock: FileLock  # OS-level file locking

proc initMessageFile(path: string): MessageFile =
  result = MessageFile(path: path)
  # Create with proper permissions
  if not fileExists(path):
    writeFile(path, "")
  # Initialize file lock
  initFileLock(result.lock, path)

proc writeMessage(mf: var MessageFile, msg: string): bool =
  try:
    # Acquire exclusive lock - blocks other processes
    acquireLock(mf.lock)
    # Append message with length prefix and delimiter
    let msgWithLen = $msg.len & ":" & msg & "\n"
    mf.path.writeFile(msgWithLen)
    result = true
  finally:
    # Always release lock
    releaseLock(mf.lock)

proc readMessages(mf: var MessageFile): seq[string] =
  try:
    acquireLock(mf.lock)
    let content = readFile(mf.path)
    if content.len > 0:
      # Parse length-prefixed messages
      var i = 0
      while i < content.len:
        let colonPos = content.find(':', i)
        if colonPos == -1: break
        let msgLen = parseInt(content[i..<colonPos])
        let msg = content[colonPos+1..colonPos+msgLen]
        result.add(msg)
        i = colonPos + msgLen + 2  # +2 for colon and newline
      # Clear file after successful read
      writeFile(mf.path, "")
  finally:
    releaseLock(mf.lock)

type MessageQueue* = ref object
  internalChan: Channel[GuiMessage]
  msgFile: MessageFile
  running: bool

proc processMessages*(queue: MessageQueue, app: Widget) {.thread.} =
  while queue.running:
    # Internal channel first (fast path)
    if queue.internalChan.tryRecv(msg):
      app.handleMessage(msg)
      continue
    
    # Check file (with proper locking)
    for msgStr in queue.msgFile.readMessages():
      try:
        let msg = parseJson(msgStr).to(GuiMessage)
        app.handleMessage(msg)
      except:
        echo "Error processing message: ", getCurrentExceptionMsg()
    
    sleep(10)

# Client side
proc sendGuiMessage*(targetId, action: string, params: JsonNode = newJObject()): bool =
  var msgFile = initMessageFile(getMessageFilePath())
  let msg = %*GuiMessage(
    targetId: targetId,
    action: action,
    params: params
  )
  result = msgFile.writeMessage($msg)