# messages.nim
type
  ClientLock = object
    path: string       # Path to lock file
    clientId: string   # Unique ID of controlling client
    timestamp: int64   # When lock was acquired
    
  MessageFile = object
    path: string
    lock: FileLock
    clientLock: ClientLock  # Add client locking

  ControlError* = object of CatchableError

proc acquireControl*(clientId: string): bool =
  ## Try to become the controlling client
  let lockPath = getTempDir() / "quickui_control.lock"
  try:
    # Check if lock exists and is fresh
    if fileExists(lockPath):
      let lockInfo = readFile(lockPath).parseJson()
      let lockTime = lockInfo["timestamp"].getInt()
      # Check if lock is still valid (not stale)
      if getTime().toUnix - lockTime < 30:  # 30 sec timeout
        return false
    
    # Write our lock
    let lockInfo = %*{
      "clientId": clientId,
      "timestamp": getTime().toUnix
    }
    writeFile(lockPath, $lockInfo)
    result = true
  except:
    result = false

proc releaseControl*(clientId: string) =
  let lockPath = getTempDir() / "quickui_control.lock"
  try:
    if fileExists(lockPath):
      let lockInfo = readFile(lockPath).parseJson()
      if lockInfo["clientId"].getStr() == clientId:
        removeFile(lockPath)
  except:
    # Log error but don't throw
    echo "Error releasing control: ", getCurrentExceptionMsg()

proc checkControl(clientId: string): bool =
  let lockPath = getTempDir() / "quickui_control.lock"
  try:
    if not fileExists(lockPath): return false
    let lockInfo = readFile(lockPath).parseJson()
    result = lockInfo["clientId"].getStr() == clientId
  except:
    result = false

# Client API
proc sendGuiMessage*(clientId, targetId, action: string, 
                    params: JsonNode = newJObject()): bool =
  if not checkControl(clientId):
    raise newException(ControlError, 
      "Client does not have control of GUI")
  
  var msgFile = initMessageFile(getMessageFilePath())
  let msg = GuiMessage(
    clientId: clientId,  # Add client ID to message
    targetId: targetId,
    action: action,
    params: params
  )
  result = msgFile.writeMessage($(%*msg))

# Example client usage
proc automateGui() =
  let clientId = "<unique-client-id>"
  
  # Try to get control
  if not acquireControl(clientId):
    echo "Another application is controlling the GUI"
    return

  try:
    # Now we can send messages
    discard sendGuiMessage(clientId, 
      "mainWindow/saveButton", "click")
    
    discard sendGuiMessage(clientId,
      "mainWindow/nameInput", "setText", 
      %*{"text": "John Doe"})
  
  finally:
    # Always release control when done
    releaseControl(clientId)

# GUI app side
proc processMessages*(queue: MessageQueue, app: Widget) {.thread.} =
  while queue.running:
    let messages = queue.msgFile.readMessages()
    for msgStr in messages:
      try:
        let msg = parseJson(msgStr).to(GuiMessage)
        # Verify client still has control
        if checkControl(msg.clientId):
          app.handleMessage(msg)
        else:
          echo "Rejected message from client without control"
      except:
        echo "Error processing message: ", getCurrentExceptionMsg()
    
    sleep(10)