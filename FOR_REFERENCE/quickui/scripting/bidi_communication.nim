# bidi_communication.nim
import typeinfo, macros
import widget_state

type
  StateQuery* = object
    path*: string           # Widget path to query
    fields*: seq[string]    # Optional specific fields to query
    recursive*: bool        # Include child widgets?

  StateResponse* = object
    widgetStates*: JsonNode
    timestamp*: int64
    success*: bool
    error*: Option[string]

proc queryWidgetState*(widget: Widget, query: StateQuery): StateResponse =
  try:
    var states = newJObject()

    # Find matching widgets
    let widgets = if query.path == "*":
      # Get all widgets
      widget.getAllWidgets()
    else:
      # Get widgets matching path
      widget.findWidgets(query.path)

    # Get state for each widget
    for w in widgets:
      var state = w.getWidgetState()

      # Filter specific fields if requested
      if query.fields.len > 0:
        let filtered = newJObject()
        for field in query.fields:
          if field in state["fields"]:
            filtered[field] = state["fields"][field]
        state["fields"] = filtered

      states[w.id] = state

      # Add children if recursive
      if query.recursive:
        for child in w.children:
          states[child.id] = child.getWidgetState()

    result = StateResponse(
      widgetStates: states,
      timestamp: getTime().toUnix,
      success: true
    )
  except:
    result = StateResponse(
      timestamp: getTime().toUnix,
      success: false,
      error: some(getCurrentExceptionMsg())
    )

# Usage example
let query = StateQuery(
  path: "mainWindow/form/*",
  fields: @["text", "enabled"],
  recursive: true
)

let response = queryWidgetState(mainWindow, query)
if response.success:
  echo response.widgetStates
else:
  echo "Query failed: ", response.error.get

# Client side
proc subscribeToChanges*(client: GuiClient,
                        query: StateQuery,
                        callback: proc(states: JsonNode)) =
  let msgId = client.nextMessageId()
  client.subscriptions[msgId] = callback

  let msg = GuiMessage(
    kind: mkSubscribe,
    id: msgId,
    clientId: client.id,
    query: query
  )

  client.msgFile.writeMessage($(%*msg), ToGui)

# Example usage in client:
client.subscribeToChanges(
  StateQuery(
    path: "mainWindow/form/textInputs/*",
    fields: @["text"],
    recursive: false
  ),
  proc(states: JsonNode) =
    for id, state in states:
      echo id, " text changed to: ", state["fields"]["text"]
)
