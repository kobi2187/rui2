## Scripting Message Protocol
##
## File-based communication protocol for GUI automation and testing.
## Based on the quickui implementation, adapted for rui2.

import std/[json, times, options]
import ../core/types

export json, options

# ============================================================================
# Message Types
# ============================================================================

type
  MessageKind* = enum
    mkCommand      # Client sending command to GUI
    mkQuery        # Client requesting widget state
    mkResponse     # GUI responding to query
    mkEvent        # GUI notifying about event
    mkError        # Error occurred

  ScriptMessage* = object
    ## Message passed between client and GUI via files
    id*: string              # Message ID for matching responses
    clientId*: string        # Who sent this message
    timestamp*: int64        # Unix timestamp
    case kind*: MessageKind
    of mkCommand:
      targetPath*: string    # Widget path (CSS-like: "mainWindow/form/button")
      action*: string        # Action to perform (e.g., "click", "setText")
      params*: JsonNode      # Action parameters
    of mkQuery:
      queryPath*: string     # Path to query (supports wildcards: "form/*")
      fields*: seq[string]   # Specific fields to return (optional, empty = all)
      recursive*: bool       # Include children in query
    of mkResponse:
      success*: bool         # Was the request successful?
      data*: JsonNode        # Response data (widget state(s) or action result)
    of mkEvent:
      eventType*: string     # Event type (e.g., "click", "change", "focus")
      eventData*: JsonNode   # Event payload
    of mkError:
      errorMsg*: string      # Error message
      errorCode*: int        # Optional error code

  ControlFile* = ref object
    ## Manages file-based communication
    commandPath*: string       # Path to command file (client -> GUI)
    responsePath*: string      # Path to response file (GUI -> client)
    lockPath*: string          # Lock file path
    controlledBy*: Option[string]  # Current controller ID (only one at a time)

# ============================================================================
# Message Serialization
# ============================================================================

proc toJson*(msg: ScriptMessage): JsonNode =
  ## Convert message to JSON for file writing
  result = %*{
    "id": msg.id,
    "clientId": msg.clientId,
    "timestamp": msg.timestamp,
    "kind": $msg.kind
  }

  case msg.kind
  of mkCommand:
    result["targetPath"] = %msg.targetPath
    result["action"] = %msg.action
    result["params"] = msg.params
  of mkQuery:
    result["queryPath"] = %msg.queryPath
    result["fields"] = %msg.fields
    result["recursive"] = %msg.recursive
  of mkResponse:
    result["success"] = %msg.success
    result["data"] = msg.data
  of mkEvent:
    result["eventType"] = %msg.eventType
    result["eventData"] = msg.eventData
  of mkError:
    result["errorMsg"] = %msg.errorMsg
    result["errorCode"] = %msg.errorCode

proc parseMessage*(json: JsonNode): ScriptMessage =
  ## Parse JSON into ScriptMessage
  let kindStr = json["kind"].getStr()
  let kind = parseEnum[MessageKind](kindStr)

  result = ScriptMessage(
    id: json["id"].getStr(),
    clientId: json["clientId"].getStr(),
    timestamp: json["timestamp"].getInt(),
    kind: kind
  )

  case kind
  of mkCommand:
    result.targetPath = json["targetPath"].getStr()
    result.action = json["action"].getStr()
    result.params = json["params"]
  of mkQuery:
    result.queryPath = json["queryPath"].getStr()
    result.fields = @[]
    if json.hasKey("fields"):
      for field in json["fields"]:
        result.fields.add(field.getStr())
    result.recursive = json.getOrDefault("recursive").getBool(false)
  of mkResponse:
    result.success = json["success"].getBool()
    result.data = json["data"]
  of mkEvent:
    result.eventType = json["eventType"].getStr()
    result.eventData = json["eventData"]
  of mkError:
    result.errorMsg = json["errorMsg"].getStr()
    result.errorCode = json.getOrDefault("errorCode").getInt(0)

# ============================================================================
# Helper Constructors
# ============================================================================

proc newCommandMessage*(clientId, targetPath, action: string,
                       params: JsonNode = newJObject()): ScriptMessage =
  ## Create a command message
  ScriptMessage(
    id: $epochTime().int & "_" & clientId,
    clientId: clientId,
    timestamp: epochTime().int64,
    kind: mkCommand,
    targetPath: targetPath,
    action: action,
    params: params
  )

proc newQueryMessage*(clientId, queryPath: string,
                     fields: seq[string] = @[],
                     recursive = false): ScriptMessage =
  ## Create a query message
  ScriptMessage(
    id: $epochTime().int & "_" & clientId,
    clientId: clientId,
    timestamp: epochTime().int64,
    kind: mkQuery,
    queryPath: queryPath,
    fields: fields,
    recursive: recursive
  )

proc newResponseMessage*(requestId, clientId: string,
                        success: bool, data: JsonNode): ScriptMessage =
  ## Create a response message
  ScriptMessage(
    id: requestId,  # Use same ID as request for matching
    clientId: clientId,
    timestamp: epochTime().int64,
    kind: mkResponse,
    success: success,
    data: data
  )

proc newErrorMessage*(requestId, clientId: string,
                     errorMsg: string, errorCode = 0): ScriptMessage =
  ## Create an error message
  ScriptMessage(
    id: requestId,
    clientId: clientId,
    timestamp: epochTime().int64,
    kind: mkError,
    errorMsg: errorMsg,
    errorCode: errorCode
  )

proc newEventMessage*(clientId, eventType: string,
                     eventData: JsonNode): ScriptMessage =
  ## Create an event notification message
  ScriptMessage(
    id: $epochTime().int & "_" & clientId,
    clientId: clientId,
    timestamp: epochTime().int64,
    kind: mkEvent,
    eventType: eventType,
    eventData: eventData
  )
