# messages.nim
type
  Direction* = enum
    ToGui, FromGui

  MessageKind* = enum
    mkCommand      # Client sending command to GUI
    mkQuery        # Client requesting state
    mkStateUpdate  # GUI responding with state
    mkEvent       # GUI notifying about event

  GuiMessage* = object
    id*: string     # Message ID for matching queries with responses
    clientId*: string
    timestamp*: int64
    case kind*: MessageKind
    of mkCommand:
      targetId*: string
      action*: string
      params*: JsonNode
    of mkQuery:
      queryPath*: string  # Which widgets to query
    of mkStateUpdate:
      widgetStates*: JsonNode
    of mkEvent:
      eventType*: string
      eventData*: JsonNode

  MessageFile = object
    inPath: string    # Client -> GUI
    outPath: string   # GUI -> Client
    lock: FileLock

proc getWidgetState*(widget: Widget): JsonNode =
  case widget.kind
  of wkButton:
    result = %*{
      "kind": "button",
      "enabled": Button(widget).enabled,
      "text": Button(widget).text
    }
  of wkTextInput:
    result = %*{
      "kind": "textInput",
      "text": TextInput(widget).text,
      "enabled": TextInput(widget).enabled,
      "focused": TextInput(widget).focused
    }
  # Add more widget types...

proc collectStates*(app: Widget, path: string): JsonNode =
  # Collect states of widgets matching path
  # path can be like "mainWindow/*" or "mainWindow/form/inputs/*"
  result = %*{}
  for widget in app.findWidgets(path):
    result[widget.id] = widget.getWidgetState()

# GUI side
proc processMessages*(queue: MessageQueue, app: Widget) {.thread.} =
  while queue.running:
    # Process incoming messages
    for msgStr in queue.msgFile.readMessages(ToGui):
      try:
        let msg = parseJson(msgStr).to(GuiMessage)
        if not checkControl(msg.clientId): continue

        case msg.kind
        of mkCommand:
          app.handleMessage(msg)
        of mkQuery:
          # Collect and send back state
          let states = app.collectStates(msg.queryPath)
          let response = GuiMessage(
            kind: mkStateUpdate,
            id: msg.id,
            clientId: msg.clientId,
            timestamp: getTime().toUnix,
            widgetStates: states
          )
          queue.msgFile.writeMessage($(%*response), FromGui)
        else: discard
      except:
        echo "Error processing message: ", getCurrentExceptionMsg()

    sleep(10)

# Client side
type
  GuiClient* = ref object
    id*: string
    msgFile: MessageFile
    lastMessageId: int
    subscriptions: Table[string, proc(state: JsonNode)]

proc queryState*(client: GuiClient, path: string): JsonNode =
  if not checkControl(client.id):
    raise newException(ControlError, "No GUI control")

  let msgId = $inc(client.lastMessageId)
  let query = GuiMessage(
    kind: mkQuery,
    id: msgId,
    clientId: client.id,
    queryPath: path
  )

  # Send query
  client.msgFile.writeMessage($(%*query), ToGui)

  # Wait for response with timeout
  var tries = 0
  while tries < 50: # 5 second timeout
    for msgStr in client.msgFile.readMessages(FromGui):
      let msg = parseJson(msgStr).to(GuiMessage)
      if msg.id == msgId:
        return msg.widgetStates
    sleep(100)
    inc tries

  raise newException(TimeoutError, "Query timeout")

proc subscribe*(client: GuiClient, path: string,
               callback: proc(state: JsonNode)) =
  client.subscriptions[path] = callback
  # Send subscription request...

# Example usage:
let client = GuiClient(id: generateUUID())

if client.acquireControl():
  try:
    # Query current state
    let formState = client.queryState("mainWindow/form/*")
    echo "Current form state: ", formState

    # Subscribe to changes
    client.subscribe "mainWindow/form/nameInput", proc(state: JsonNode) =
      echo "Name input changed to: ", state["text"].getStr()

    # Send command
    client.sendMessage("mainWindow/form/nameInput",
                      "setText", %*{"text": "John"})

    # Query again to verify
    let newState = client.queryState("mainWindow/form/nameInput")
    echo "New state: ", newState
  finally:
    client.releaseControl()
