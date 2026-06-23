## Text Format Parser
##
## Simple line-based format for scripting commands and responses.
## Alternative to JSON format - easier for shell scripts and AutoHotKey-style automation.
##
## Commands format: id selector command [value]
## Response format: id result

import std/[strutils, parseutils, options, json, os]

# ============================================================================
# Types
# ============================================================================

type
  CommandType* = enum
    ctRead      # Read widget value/state
    ctWrite     # Write value to widget (e.g., set text)
    ctInvoke    # Invoke widget action (e.g., click button)
    ctCustom    # Widget-specific custom command (e.g., custom:inc)

  TextCommand* = object
    ## Parsed text command from commands.txt
    id*: string           # Message ID for matching responses
    selector*: string     # Widget selector path
    case cmdType*: CommandType
    of ctRead, ctInvoke:
      discard
    of ctWrite:
      value*: string      # Value to write
    of ctCustom:
      customCmd*: string  # Custom command name (after "custom:")

  TextResponse* = object
    ## Response to write to responses.txt
    id*: string           # Matching command ID
    success*: bool
    case isValue*: bool
    of true:
      value*: string      # Actual value (for reads) or OK/Fail
    of false:
      values*: seq[string]  # List of values [a, b, c]

# ============================================================================
# Command Parsing
# ============================================================================

proc parseCommand*(line: string): Option[TextCommand] =
  ## Parse a single command line
  ## Format: id selector command [value]
  ## Example: "1 loginButton invoke"
  ## Example: "2 usernameInput write john_doe"
  ## Example: "3 form/* read"

  let parts = line.splitWhitespace(maxsplit = 3)
  if parts.len < 3:
    return none(TextCommand)

  let id = parts[0]
  let selector = parts[1]
  let cmdStr = parts[2]

  # Parse command type
  if cmdStr == "read":
    return some(TextCommand(
      id: id,
      selector: selector,
      cmdType: ctRead
    ))
  elif cmdStr == "invoke":
    return some(TextCommand(
      id: id,
      selector: selector,
      cmdType: ctInvoke
    ))
  elif cmdStr == "write":
    if parts.len < 4:
      return none(TextCommand)  # Write requires value
    return some(TextCommand(
      id: id,
      selector: selector,
      cmdType: ctWrite,
      value: parts[3]
    ))
  elif cmdStr.startsWith("custom:"):
    let customCmd = cmdStr[7..^1]  # Skip "custom:"
    return some(TextCommand(
      id: id,
      selector: selector,
      cmdType: ctCustom,
      customCmd: customCmd
    ))
  else:
    return none(TextCommand)

proc parseCommandFile*(path: string): seq[TextCommand] =
  ## Parse entire commands.txt file
  ## Returns sequence of commands
  result = @[]

  if not fileExists(path):
    return

  for line in lines(path):
    let trimmed = line.strip()
    if trimmed.len == 0 or trimmed.startsWith("#"):
      continue  # Skip empty lines and comments

    let cmd = parseCommand(trimmed)
    if cmd.isSome:
      result.add(cmd.get())

# ============================================================================
# Response Writing
# ============================================================================

proc formatList(values: seq[string]): string =
  ## Format list as [a, b, c]
  if values.len == 0:
    return "[]"
  result = "["
  for i, val in values:
    if i > 0:
      result.add(", ")
    result.add(val)
  result.add("]")

proc formatResponse*(resp: TextResponse): string =
  ## Format response as text line
  ## Format: id result
  result = resp.id & " "

  if resp.isValue:
    result.add(resp.value)
  else:
    result.add(formatList(resp.values))

proc writeResponseFile*(path: string, responses: seq[TextResponse]) =
  ## Write responses to responses.txt
  var lines: seq[string] = @[]
  for resp in responses:
    lines.add(formatResponse(resp))

  writeFile(path, lines.join("\n") & "\n")

proc writeResponse*(path: string, resp: TextResponse) =
  ## Write single response to responses.txt
  writeFile(path, formatResponse(resp) & "\n")

# ============================================================================
# Convenience Constructors
# ============================================================================

proc newSuccessResponse*(id: string): TextResponse =
  ## Create OK response
  TextResponse(
    id: id,
    success: true,
    isValue: true,
    value: "OK"
  )

proc newFailResponse*(id: string, error: string = "Fail"): TextResponse =
  ## Create Fail response
  TextResponse(
    id: id,
    success: false,
    isValue: true,
    value: error
  )

proc newValueResponse*(id: string, value: string): TextResponse =
  ## Create response with value
  TextResponse(
    id: id,
    success: true,
    isValue: true,
    value: value
  )

proc newListResponse*(id: string, values: seq[string]): TextResponse =
  ## Create response with list of values
  TextResponse(
    id: id,
    success: true,
    isValue: false,
    values: values
  )

# ============================================================================
# Command Translation
# ============================================================================

proc translateToAction*(cmd: TextCommand, widgetType: string): (string, JsonNode) =
  ## Translate generic command to widget-specific action
  ## Returns (action, params) tuple for handleScriptAction

  case cmd.cmdType
  of ctRead:
    # Read maps to different actions depending on widget type
    case widgetType
    of "Button", "Label":
      return ("getText", newJObject())
    of "TextInput":
      return ("getText", newJObject())
    of "CheckBox":
      return ("getChecked", newJObject())
    else:
      return ("getState", newJObject())  # Generic state query

  of ctWrite:
    # Write maps to setting value
    case widgetType
    of "TextInput":
      return ("setText", %*{"text": cmd.value})
    of "CheckBox":
      let checked = cmd.value in ["true", "1", "yes", "on"]
      return ("setChecked", %*{"checked": checked})
    of "Slider", "NumberInput":
      return ("setValue", %*{"value": cmd.value})
    else:
      return ("setValue", %*{"value": cmd.value})

  of ctInvoke:
    # Invoke is widget-specific but usually unambiguous
    case widgetType
    of "Button":
      return ("click", newJObject())
    of "TextInput":
      return ("submit", newJObject())
    of "CheckBox":
      return ("toggle", newJObject())
    else:
      return ("invoke", newJObject())

  of ctCustom:
    # Custom commands are passed through
    return ("custom:" & cmd.customCmd, newJObject())

proc canInvoke*(widgetType: string): bool =
  ## Check if widget type supports invoke command
  widgetType in ["Button", "TextInput", "CheckBox", "MenuItem"]

proc canWrite*(widgetType: string): bool =
  ## Check if widget type supports write command
  widgetType in ["TextInput", "CheckBox", "Slider", "NumberInput", "ComboBox"]

proc canRead*(widgetType: string): bool =
  ## All widgets can be read
  true
