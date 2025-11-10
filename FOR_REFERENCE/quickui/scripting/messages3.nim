# messages.nim
import threading/channels
import os, json

type
  GuiMessage* = object
    targetId*: string    # Which widget
    action*: string      # What to do
    params*: JsonNode    # How to do it
    
  MessageQueue* = ref object
    internalChan: Channel[GuiMessage]  # For same-process communication
    ipcFilePath: string                # For inter-process communication
    running: bool

proc newMessageQueue*(): MessageQueue =
  result = MessageQueue(
    internalChan: newChannel[GuiMessage](),
    ipcFilePath: getTempDir() / "quickui_messages.queue",
    running: true
  )
  # Create the IPC file if it doesn't exist
  if not fileExists(result.ipcFilePath):
    writeFile(result.ipcFilePath, "")

proc processMessages*(queue: MessageQueue, app: Widget) {.thread.} =
  while queue.running:
    # Check internal channel (fast path)
    if queue.internalChan.tryRecv(msg):
      app.handleMessage(msg)
      continue
      
    # Check IPC file (slow path)
    if fileExists(queue.ipcFilePath):
      try:
        let content = readFile(queue.ipcFilePath)
        if content.len > 0:
          # Clear file immediately
          writeFile(queue.ipcFilePath, "")
          # Process message
          let msg = parseJson(content).to(GuiMessage)
          app.handleMessage(msg)
      except:
        echo "Error processing IPC message: ", getCurrentExceptionMsg()
    
    # Don't burn CPU
    sleep(10)

# Main GUI App
proc main() =
  let app = initApp()
  let msgQueue = newMessageQueue()
  
  # Start message processing thread
  spawn msgQueue.processMessages(app)
  
  # Main GUI loop
  while not windowShouldClose():
    # Normal GUI stuff...
    app.update()
    app.render()

# Client API (can be used from other processes)
proc sendGuiMessage*(targetId, action: string, params: JsonNode = newJObject()): bool =
  let msg = GuiMessage(
    targetId: targetId,
    action: action,
    params: params
  )
  try:
    # Write to the IPC file
    writeFile(getTempDir() / "quickui_messages.queue", $(%*msg))
    result = true
  except:
    result = false

# Example client usage (from another program)
import quickui/client

proc automateGui() =
  # Click a button
  discard sendGuiMessage("mainWindow/saveButton", "click")
  
  # Set some text
  discard sendGuiMessage("mainWindow/nameInput", "setText", 
    %*{"text": "John Doe"})