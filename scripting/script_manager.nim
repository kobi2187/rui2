## Script Manager
##
## Handles file-based communication protocol for GUI automation.
## Polls for command files, processes them, and writes responses.

import std/[os, json, times, options, strutils]
import messages, selectors, text_format
import ../core/types

export messages, selectors, text_format

# ============================================================================
# Types
# ============================================================================

type
  CommandFormat* = enum
    cfJson    # JSON format (commands.json / responses.json)
    cfText    # Text format (commands.txt / responses.txt)

  ScriptManager* = ref object
    ## Manages file-based scripting communication
    workDir*: string               # Directory for command/response files
    commandPathJson*: string       # Path to commands.json
    responsePathJson*: string      # Path to responses.json
    commandPathText*: string       # Path to commands.txt
    responsePathText*: string      # Path to responses.txt
    lockPath*: string              # Path to .lock file

    widgetTree*: WidgetTree        # Reference to app's widget tree

    pollInterval*: float64         # Seconds between polls (default: 1.0)
    lastPoll*: float64             # Last poll timestamp

    enabled*: bool                 # Master enable/disable
    isProcessing*: bool            # Currently processing commands (lock held)

# ============================================================================
# Initialization
# ============================================================================

proc newScriptManager*(workDir: string, widgetTree: WidgetTree): ScriptManager =
  ## Create a new script manager
  ## workDir: Directory where command/response files will be placed
  ##          Typically the same directory as the app executable
  result = ScriptManager(
    workDir: workDir,
    commandPathJson: workDir / "commands.json",
    responsePathJson: workDir / "responses.json",
    commandPathText: workDir / "commands.txt",
    responsePathText: workDir / "responses.txt",
    lockPath: workDir / ".lock",
    widgetTree: widgetTree,
    pollInterval: 1.0,  # Poll every 1 second
    lastPoll: 0.0,
    enabled: true,
    isProcessing: false
  )

  # Ensure work directory exists
  if not dirExists(workDir):
    createDir(workDir)

  # Clean up any leftover files from previous run
  if fileExists(result.lockPath):
    removeFile(result.lockPath)
  if fileExists(result.responsePathJson):
    removeFile(result.responsePathJson)
  if fileExists(result.responsePathText):
    removeFile(result.responsePathText)

# ============================================================================
# File Operations
# ============================================================================

proc createLock(sm: ScriptManager) =
  ## Create lock file to indicate we're processing
  writeFile(sm.lockPath, $epochTime())
  sm.isProcessing = true

proc releaseLock(sm: ScriptManager) =
  ## Remove lock file
  if fileExists(sm.lockPath):
    removeFile(sm.lockPath)
  sm.isProcessing = false

proc detectCommandFormat(sm: ScriptManager): Option[CommandFormat] =
  ## Check which command file exists
  ## Text format takes priority over JSON
  if fileExists(sm.commandPathText):
    return some(cfText)
  elif fileExists(sm.commandPathJson):
    return some(cfJson)
  else:
    return none(CommandFormat)

proc getWidgetTypeName(widget: Widget): string =
  ## Get widget type name for command translation
  ## This is a simple implementation - could be improved with actual type info
  if widget.stringId.contains("button") or widget.stringId.contains("btn"):
    return "Button"
  elif widget.stringId.contains("input") or widget.stringId.contains("text"):
    return "TextInput"
  elif widget.stringId.contains("check"):
    return "CheckBox"
  else:
    return "Widget"  # Generic

proc processTextCommand(sm: ScriptManager, cmd: TextCommand): TextResponse =
  ## Process a single text command and return text response

  # Handle wildcard reads (list children)
  if cmd.cmdType == ctRead and cmd.selector.contains("*"):
    let widgets = sm.findWidgets(cmd.selector)
    var ids: seq[string] = @[]
    for w in widgets:
      if w.stringId.len > 0:
        ids.add(w.stringId)
    return newListResponse(cmd.id, ids)

  # Find widget
  let widgetOpt = sm.findWidget(cmd.selector)
  if widgetOpt.isNone:
    return newFailResponse(cmd.id, "Widget not found")

  let widget = widgetOpt.get()

  # Get widget type for command translation
  let widgetType = widget.getWidgetTypeName()

  # Translate command to action
  let (action, params) = cmd.translateToAction(widgetType)

  # Execute action
  let result = widget.handleScriptAction(action, params)

  # Convert JSON result to text response
  if result.hasKey("success") and result["success"].getBool():
    # Success case
    if result.hasKey("text"):
      return newValueResponse(cmd.id, result["text"].getStr())
    elif result.hasKey("value"):
      return newValueResponse(cmd.id, $result["value"])
    else:
      return newSuccessResponse(cmd.id)
  else:
    # Error case
    let error = if result.hasKey("error"): result["error"].getStr() else: "Fail"
    return newFailResponse(cmd.id, error)

proc cleanupCommandFile(sm: ScriptManager, format: CommandFormat) =
  ## Delete command file after processing
  case format
  of cfJson:
    if fileExists(sm.commandPathJson):
      removeFile(sm.commandPathJson)
  of cfText:
    if fileExists(sm.commandPathText):
      removeFile(sm.commandPathText)

# ============================================================================
# Widget Tree Operations
# ============================================================================

proc findWidget(sm: ScriptManager, path: string): Option[Widget] =
  ## Find a widget by path using CSS-like selectors
  return sm.widgetTree.findWidget(path)

proc findWidgets(sm: ScriptManager, path: string): seq[Widget] =
  ## Find all widgets matching path (supports wildcards)
  return sm.widgetTree.findWidgets(path)

proc queryWidget(sm: ScriptManager, widget: Widget, fields: seq[string]): JsonNode =
  ## Query widget state
  ## If fields is empty, return all state
  ## Otherwise, return only requested fields

  # Check if reading is blocked
  if widget.blockReading:
    return %*{
      "id": widget.stringId,
      "type": "Widget",
      "blocked": true,
      "message": "Reading blocked for this widget"
    }

  # Get full state
  let fullState = widget.getScriptableState()

  # If no specific fields requested, return full state
  if fields.len == 0:
    return fullState

  # Filter to requested fields
  result = newJObject()
  for field in fields:
    if fullState.hasKey(field):
      result[field] = fullState[field]

proc executeAction(sm: ScriptManager, widget: Widget, action: string,
                  params: JsonNode): JsonNode =
  ## Execute an action on a widget

  # Check if widget is scriptable
  if not widget.scriptable:
    return %*{
      "success": false,
      "error": "Widget is not scriptable"
    }

  # Delegate to widget's handler
  return widget.handleScriptAction(action, params)

# ============================================================================
# Message Processing
# ============================================================================

proc processQuery(sm: ScriptManager, msg: ScriptMessage): ScriptMessage =
  ## Process a query message
  let widgets = sm.findWidgets(msg.queryPath)

  if widgets.len == 0:
    # No widgets found
    return newErrorMessage(msg.id, msg.clientId,
      "No widgets found matching path: " & msg.queryPath, 404)

  # Query each widget
  var data = newJObject()
  for widget in widgets:
    let widgetData = sm.queryWidget(widget, msg.fields)
    data[widget.stringId] = widgetData

  return newResponseMessage(msg.id, msg.clientId, true, data)

proc processCommand(sm: ScriptManager, msg: ScriptMessage): ScriptMessage =
  ## Process a command message
  let widgetOpt = sm.findWidget(msg.targetPath)

  if widgetOpt.isNone:
    return newErrorMessage(msg.id, msg.clientId,
      "Widget not found: " & msg.targetPath, 404)

  let widget = widgetOpt.get()
  let result = sm.executeAction(widget, msg.action, msg.params)

  # Check if action returned error
  if result.hasKey("error"):
    return newErrorMessage(msg.id, msg.clientId,
      result["error"].getStr(), 400)

  return newResponseMessage(msg.id, msg.clientId, true, result)

proc processMessage(sm: ScriptManager, msg: ScriptMessage): ScriptMessage =
  ## Process a message and return response
  case msg.kind
  of mkQuery:
    return sm.processQuery(msg)
  of mkCommand:
    return sm.processCommand(msg)
  else:
    return newErrorMessage(msg.id, msg.clientId,
      "Unsupported message kind: " & $msg.kind, 400)

# ============================================================================
# Polling
# ============================================================================

proc poll*(sm: ScriptManager) =
  ## Poll for command files and process them
  ## Called from main application loop

  if not sm.enabled:
    return

  let now = epochTime()

  # Check if it's time to poll
  if now - sm.lastPoll < sm.pollInterval:
    return

  sm.lastPoll = now

  # Detect command format
  let formatOpt = sm.detectCommandFormat()
  if formatOpt.isNone:
    return  # No command file

  let format = formatOpt.get()

  # Process command file
  try:
    # Create lock
    sm.createLock()

    case format
    of cfText:
      # Process text format
      let commands = parseCommandFile(sm.commandPathText)
      var responses: seq[TextResponse] = @[]

      for cmd in commands:
        let resp = sm.processTextCommand(cmd)
        responses.add(resp)

      # Write all responses
      writeResponseFile(sm.responsePathText, responses)

    of cfJson:
      # Process JSON format (single command)
      try:
        let content = readFile(sm.commandPathJson)
        let jsonNode = parseJson(content)
        let msg = parseMessage(jsonNode)

        # Process message
        let response = sm.processMessage(msg)

        # Write response
        let respJson = response.toJson()
        writeFile(sm.responsePathJson, $respJson)

      except CatchableError as e:
        # Failed to parse - write error response
        let errorMsg = newErrorMessage("unknown", "system",
          "Failed to parse command file: " & e.msg, 400)
        let respJson = errorMsg.toJson()
        writeFile(sm.responsePathJson, $respJson)

    # Cleanup
    sm.cleanupCommandFile(format)
    sm.releaseLock()

  except CatchableError as e:
    # Error during processing
    case format
    of cfText:
      let errorResp = newFailResponse("0", "Error: " & e.msg)
      writeResponse(sm.responsePathText, errorResp)
    of cfJson:
      let errorMsg = newErrorMessage("unknown", "system",
        "Error processing command: " & e.msg, 500)
      let respJson = errorMsg.toJson()
      writeFile(sm.responsePathJson, $respJson)

    sm.releaseLock()

# ============================================================================
# Control
# ============================================================================

proc enable*(sm: ScriptManager) =
  ## Enable scripting system
  sm.enabled = true

proc disable*(sm: ScriptManager) =
  ## Disable scripting system
  sm.enabled = false
  sm.releaseLock()

proc setPolling*(sm: ScriptManager, intervalSeconds: float64) =
  ## Set polling interval in seconds
  sm.pollInterval = intervalSeconds

proc isBeingScripted*(sm: ScriptManager): bool =
  ## Check if app is currently being scripted (processing commands)
  ## Returns true while lock file is held
  sm.isProcessing
