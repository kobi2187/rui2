## Script Manager
##
## Handles file-based communication protocol for GUI automation.
## Polls for command files, processes them, and writes responses.

import std/[os, json, times, options, strutils]
import messages, selectors, text_format
import rui_core

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

    onKey*: proc(keyName: string): bool
      ## Synthesise a key press, for the `key` command. **Test-only.**
      ##
      ## Scripting here is deliberately semantic: a script addresses a control
      ## by id and operates it directly -- `agree invoke`, `progress write
      ## value=40` -- rather than emulating input. A script should not have to
      ## know where focus is or what a widget's key bindings are, and this
      ## subsystem is not an input-emulation layer.
      ##
      ## The exception is driving the focus machinery itself, which cannot be
      ## exercised any other way. `App.enableScripting` sets this only under
      ## `-d:ruiTestKeys`, so an ordinary build leaves it nil and the `key`
      ## command reports that the host has not wired it up.
      ##
      ## A closure rather than a direct reference, so rui_scripting does not
      ## need to depend on rui_events to relay a key.

    onInspect*: proc(selector: string, what: string): Option[string]
      ## Answer an `inspect` command. **Test-only.**
      ##
      ## Reports on the framework rather than on the UI's own data: where a
      ## widget actually ends up on screen once clipping is applied, which
      ## frame it last repainted on, what sits under a point, the shape of the
      ## tree. An application has no use for any of it, and a script that
      ## needed it would be testing rui rather than driving a UI -- so it is
      ## gated separately from the public verbs.
      ##
      ## `none` means the host declined: an unknown inspector, or a selector
      ## that matched nothing. `App.enableScripting` sets this only under
      ## `-d:ruiInspect`, so an ordinary build leaves it nil and the `inspect`
      ## command reports that the host has not wired it up.
      ##
      ## Takes the selector rather than a Widget, because two of the
      ## inspectors -- `tree` and `settle` -- are about the app and have no
      ## widget to address.
      ##
      ## A closure rather than a direct reference, for the same reason `onKey`
      ## is one: rui_scripting would otherwise need to know about layout,
      ## hit-testing and the frame loop to answer.

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

proc answerKey(sm: ScriptManager, cmd: TextCommand): TextResponse =
  ## A key press resolves no selector: it goes wherever focus is, which is the
  ## whole point of being able to test it.
  if sm.onKey == nil:
    return newFailResponse(cmd.id, "Key injection not wired up by the host")
  if sm.onKey(cmd.keyName):
    return newSuccessResponse(cmd.id)
  newFailResponse(cmd.id, "Key not handled: " & cmd.keyName)

proc answerInspect(sm: ScriptManager, cmd: TextCommand): TextResponse =
  ## Inspection resolves no selector here either: `tree` and `settle` address
  ## the app rather than a widget, and the host resolves the rest itself.
  if sm.onInspect == nil:
    return newFailResponse(cmd.id,
      "Inspection not available: build with -d:ruiInspect")
  let answer = sm.onInspect(cmd.selector, cmd.what)
  if answer.isNone:
    return newFailResponse(cmd.id, "Cannot inspect: " & cmd.what)
  newValueResponse(cmd.id, answer.get())

proc answerWildcardRead(sm: ScriptManager, cmd: TextCommand): TextResponse =
  ## `form/* read` lists the matching widgets as "TypeName:widgetId".
  let widgets = sm.widgetTree.findWidgets(cmd.selector)
  var ids: seq[string] = @[]
  for w in widgets:
    if w.stringId.len > 0:
      ids.add(w.getTypeName() & ":" & w.stringId)
  newListResponse(cmd.id, ids)

proc splitSelector(selector: string): tuple[id, explicitType: string] =
  ## "Button:save" names the type as well as the id; a bare "save" does not.
  ## The type is advisory -- it is passed to translateToAction, which today
  ## ignores it.
  let colon = selector.find(':')
  if colon <= 0:
    return (selector, "")
  (selector[colon + 1 .. ^1], selector[0 ..< colon])

proc succeeded(res: JsonNode): bool =
  res.hasKey("success") and res["success"].getBool()

proc asTextResponse(res: JsonNode, id: string): TextResponse =
  ## The generic bridge answers in JSON; the text protocol wants one line.
  if not res.succeeded:
    return newFailResponse(id,
      if res.hasKey("error"): res["error"].getStr() else: "Fail")
  if res.hasKey("text"):
    return newValueResponse(id, res["text"].getStr())
  if res.hasKey("value"):
    return newValueResponse(id, $res["value"])
  newSuccessResponse(id)

proc processTextCommand(sm: ScriptManager, cmd: TextCommand): TextResponse =
  ## Process a single text command and return text response.
  ##
  ## Two verbs are intercepted before any selector is resolved -- `key` and
  ## `inspect` -- because neither addresses a widget. Everything else resolves
  ## the selector and goes through the widget's own scripting bridge.
  case cmd.cmdType
  of ctKey: return sm.answerKey(cmd)
  of ctInspect: return sm.answerInspect(cmd)
  of ctRead:
    if cmd.selector.contains("*"):
      return sm.answerWildcardRead(cmd)
  else: discard

  let (selector, explicitType) = splitSelector(cmd.selector)
  let widgetOpt = sm.widgetTree.findWidget(selector)
  if widgetOpt.isNone:
    return newFailResponse(cmd.id, "Widget not found")

  let widget = widgetOpt.get()
  let widgetType = if explicitType.len > 0: explicitType else: widget.getTypeName()
  let (action, params) = cmd.translateToAction(widgetType)
  widget.handleScriptAction(action, params).asTextResponse(cmd.id)

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
  ## Note: Scripting access control is managed at app level, not per-widget

  # Delegate to widget's handler
  return widget.handleScriptAction(action, params)

# ============================================================================
# Message Processing
# ============================================================================

proc processQuery(sm: ScriptManager, msg: ScriptMessage): ScriptMessage =
  ## Process a query message
  let widgets = sm.widgetTree.findWidgets(msg.queryPath)

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
  let res = sm.executeAction(widget, msg.action, msg.params)

  # Check if action returned error
  if res.hasKey("error"):
    return newErrorMessage(msg.id, msg.clientId,
      res["error"].getStr(), 400)

  return newResponseMessage(msg.id, msg.clientId, true, res)

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
