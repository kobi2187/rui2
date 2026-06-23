## Script Client Library
##
## High-level API for external programs to control RUI applications.
## Handles file I/O, message creation, and response parsing.

import std/[os, json, times, options, strutils]
import messages

export messages, json

# ============================================================================
# Types
# ============================================================================

type
  ScriptClient* = ref object
    ## Client for controlling RUI apps via file-based protocol
    id*: string                    # Unique client ID
    workDir*: string               # Directory for command/response files
    commandPath*: string           # Path to commands.json
    responsePath*: string          # Path to responses.json
    lockPath*: string              # Path to .lock file
    lastMessageId*: int            # Counter for unique message IDs
    timeout*: float64              # Timeout in seconds (default: 5.0)

# ============================================================================
# Initialization
# ============================================================================

proc newScriptClient*(workDir: string, clientId = ""): ScriptClient =
  ## Create a new script client
  ## workDir: Directory where the RUI app's command/response files are located
  ## clientId: Optional client ID (auto-generated if not provided)
  let id = if clientId.len > 0:
             clientId
           else:
             "client_" & $epochTime().int

  result = ScriptClient(
    id: id,
    workDir: workDir,
    commandPath: workDir / "commands.json",
    responsePath: workDir / "responses.json",
    lockPath: workDir / ".lock",
    lastMessageId: 0,
    timeout: 5.0
  )

# ============================================================================
# Message Sending
# ============================================================================

proc generateMessageId(client: ScriptClient): string =
  ## Generate unique message ID
  inc client.lastMessageId
  result = $epochTime().int & "_" & client.id & "_" & $client.lastMessageId

proc writeCommand(client: ScriptClient, msg: ScriptMessage) =
  ## Write command to file
  let jsonNode = msg.toJson()
  writeFile(client.commandPath, $jsonNode)

proc waitForResponse(client: ScriptClient, messageId: string): Option[ScriptMessage] =
  ## Wait for response file to appear and contain our message ID
  let startTime = epochTime()

  while epochTime() - startTime < client.timeout:
    # Check if response file exists
    if not fileExists(client.responsePath):
      sleep(100)  # Wait 100ms
      continue

    # Check if still locked (app is processing)
    if fileExists(client.lockPath):
      sleep(100)
      continue

    # Try to read response
    try:
      let content = readFile(client.responsePath)
      let jsonNode = parseJson(content)
      let response = parseMessage(jsonNode)

      # Check if this is our response
      if response.id == messageId:
        # Delete response file after reading
        removeFile(client.responsePath)
        return some(response)

    except CatchableError:
      # Failed to read or parse - might still be writing
      sleep(100)
      continue

    sleep(100)

  # Timeout
  return none(ScriptMessage)

proc sendMessage(client: ScriptClient, msg: ScriptMessage): Option[ScriptMessage] =
  ## Send a message and wait for response
  ## Returns None if timeout or error

  # Ensure no leftover files
  if fileExists(client.responsePath):
    removeFile(client.responsePath)

  # Write command
  client.writeCommand(msg)

  # Wait for response
  return client.waitForResponse(msg.id)

# ============================================================================
# High-Level API
# ============================================================================

proc query*(client: ScriptClient, path: string,
           fields: seq[string] = @[],
           recursive = false): Option[JsonNode] =
  ## Query widget(s) state
  ## Returns JSON with widget data, or None if failed

  let msg = newQueryMessage(client.id, path, fields, recursive)
  let response = client.sendMessage(msg)

  if response.isNone:
    return none(JsonNode)

  let resp = response.get()
  if resp.kind == mkResponse and resp.success:
    return some(resp.data)
  elif resp.kind == mkError:
    echo "Error: ", resp.errorMsg
    return none(JsonNode)
  else:
    return none(JsonNode)

proc command*(client: ScriptClient, path: string,
             action: string,
             params: JsonNode = newJObject()): Option[JsonNode] =
  ## Execute a command on a widget
  ## Returns result JSON, or None if failed

  let msg = newCommandMessage(client.id, path, action, params)
  let response = client.sendMessage(msg)

  if response.isNone:
    return none(JsonNode)

  let resp = response.get()
  if resp.kind == mkResponse and resp.success:
    return some(resp.data)
  elif resp.kind == mkError:
    echo "Error: ", resp.errorMsg
    return none(JsonNode)
  else:
    return none(JsonNode)

# ============================================================================
# Convenience Functions
# ============================================================================

proc click*(client: ScriptClient, path: string): bool =
  ## Click a button
  let result = client.command(path, "click")
  return result.isSome

proc setText*(client: ScriptClient, path: string, text: string): bool =
  ## Set text in a text input or label
  let params = %*{"text": text}
  let result = client.command(path, "setText", params)
  return result.isSome

proc getText*(client: ScriptClient, path: string): Option[string] =
  ## Get text from a widget
  let result = client.command(path, "getText")
  if result.isSome and result.get().hasKey("text"):
    return some(result.get()["text"].getStr())
  return none(string)

proc clear*(client: ScriptClient, path: string): bool =
  ## Clear text input
  let result = client.command(path, "clear")
  return result.isSome

proc focus*(client: ScriptClient, path: string): bool =
  ## Focus a widget
  let result = client.command(path, "focus")
  return result.isSome

proc blur*(client: ScriptClient, path: string): bool =
  ## Remove focus from a widget
  let result = client.command(path, "blur")
  return result.isSome

proc submit*(client: ScriptClient, path: string): bool =
  ## Submit a form/text input
  let result = client.command(path, "submit")
  return result.isSome

proc enable*(client: ScriptClient, path: string): bool =
  ## Enable a widget
  let result = client.command(path, "enable")
  return result.isSome

proc disable*(client: ScriptClient, path: string): bool =
  ## Disable a widget
  let result = client.command(path, "disable")
  return result.isSome

# ============================================================================
# Waiting and Polling
# ============================================================================

proc waitForWidget*(client: ScriptClient, path: string,
                   timeout: float64 = 5.0): bool =
  ## Wait for a widget to appear
  let startTime = epochTime()

  while epochTime() - startTime < timeout:
    let result = client.query(path)
    if result.isSome:
      return true
    sleep(200)  # Check every 200ms

  return false

proc waitForCondition*(client: ScriptClient, path: string,
                      field: string, expectedValue: JsonNode,
                      timeout: float64 = 5.0): bool =
  ## Wait for a widget field to have a specific value
  let startTime = epochTime()

  while epochTime() - startTime < timeout:
    let result = client.query(path, @[field])
    if result.isSome:
      let data = result.get()
      # Handle case where query returns multiple widgets
      if data.kind == JObject:
        for key, value in data:
          if value.hasKey(field) and value[field] == expectedValue:
            return true
    sleep(200)

  return false

proc getWidgetState*(client: ScriptClient, path: string): Option[JsonNode] =
  ## Get full state of a widget
  return client.query(path)

# ============================================================================
# Utilities
# ============================================================================

proc setTimeout*(client: ScriptClient, seconds: float64) =
  ## Set timeout for operations
  client.timeout = seconds

proc isAppResponding*(client: ScriptClient): bool =
  ## Check if the app is responding
  ## Tries a simple query with short timeout
  let oldTimeout = client.timeout
  client.timeout = 1.0
  let result = client.query("*")  # Query root
  client.timeout = oldTimeout
  return result.isSome
