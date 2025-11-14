## Script Manager
##
## Handles file-based communication protocol for GUI automation.
## Polls for command files, processes them, and writes responses.

import std/[os, json, times, options, strutils]
import messages, selectors
import ../core/types

export messages, selectors

# ============================================================================
# Types
# ============================================================================

type
  ScriptManager* = ref object
    ## Manages file-based scripting communication
    workDir*: string               # Directory for command/response files
    commandPath*: string           # Path to commands.json
    responsePath*: string          # Path to responses.json
    lockPath*: string              # Path to .lock file

    widgetTree*: WidgetTree        # Reference to app's widget tree

    pollInterval*: float64         # Seconds between polls (default: 1.0)
    lastPoll*: float64             # Last poll timestamp

    enabled*: bool                 # Master enable/disable

# ============================================================================
# Initialization
# ============================================================================

proc newScriptManager*(workDir: string, widgetTree: WidgetTree): ScriptManager =
  ## Create a new script manager
  ## workDir: Directory where command/response files will be placed
  ##          Typically the same directory as the app executable
  result = ScriptManager(
    workDir: workDir,
    commandPath: workDir / "commands.json",
    responsePath: workDir / "responses.json",
    lockPath: workDir / ".lock",
    widgetTree: widgetTree,
    pollInterval: 1.0,  # Poll every 1 second
    lastPoll: 0.0,
    enabled: true
  )

  # Ensure work directory exists
  if not dirExists(workDir):
    createDir(workDir)

  # Clean up any leftover files from previous run
  if fileExists(result.lockPath):
    removeFile(result.lockPath)
  if fileExists(result.responsePath):
    removeFile(result.responsePath)

# ============================================================================
# File Operations
# ============================================================================

proc createLock(sm: ScriptManager) =
  ## Create lock file to indicate we're processing
  writeFile(sm.lockPath, $epochTime())

proc releaseLock(sm: ScriptManager) =
  ## Remove lock file
  if fileExists(sm.lockPath):
    removeFile(sm.lockPath)

proc hasCommandFile(sm: ScriptManager): bool =
  ## Check if command file exists
  fileExists(sm.commandPath)

proc readCommandFile(sm: ScriptManager): Option[ScriptMessage] =
  ## Read and parse command file
  ## Returns None if file doesn't exist or can't be parsed
  if not sm.hasCommandFile():
    return none(ScriptMessage)

  try:
    let content = readFile(sm.commandPath)
    let jsonNode = parseJson(content)
    let msg = parseMessage(jsonNode)
    return some(msg)
  except CatchableError as e:
    # Failed to parse - write error response
    let errorMsg = newErrorMessage("unknown", "system",
      "Failed to parse command file: " & e.msg, 400)
    sm.writeResponse(errorMsg)
    return none(ScriptMessage)

proc writeResponse(sm: ScriptManager, msg: ScriptMessage) =
  ## Write response to file
  let jsonNode = msg.toJson()
  writeFile(sm.responsePath, $jsonNode)

proc cleanupCommandFile(sm: ScriptManager) =
  ## Delete command file after processing
  if fileExists(sm.commandPath):
    removeFile(sm.commandPath)

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

  # Check for command file
  if not sm.hasCommandFile():
    return

  # Process command file
  try:
    # Create lock
    sm.createLock()

    # Read command
    let msgOpt = sm.readCommandFile()
    if msgOpt.isNone:
      return  # Error already written by readCommandFile

    let msg = msgOpt.get()

    # Process message
    let response = sm.processMessage(msg)

    # Write response
    sm.writeResponse(response)

    # Cleanup
    sm.cleanupCommandFile()
    sm.releaseLock()

  except CatchableError as e:
    # Error during processing
    let errorMsg = newErrorMessage("unknown", "system",
      "Error processing command: " & e.msg, 500)
    sm.writeResponse(errorMsg)
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
