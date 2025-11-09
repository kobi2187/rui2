# RUI2 Scripting & Automation System

**Design Document**
**Date:** 2025-11-09
**Philosophy:** Built-in from day one, file-based, secure, testable

---

## Overview

The RUI2 scripting system enables external control and automation of GUI applications through a simple file-based protocol. This enables:

1. **Automated Testing** - Script UI interactions without visual confirmation
2. **Remote Control** - External programs can control the GUI
3. **Integration Testing** - Verify complex UI workflows programmatically
4. **Accessibility Tools** - Screen readers, automation tools can query/control UI
5. **Dev Tools** - Inspect widget tree, query state, modify values

## Design Principles

### 1. **File-Based Communication**
- Simple, language-agnostic protocol
- No network sockets (simpler, more secure)
- Lock file prevents race conditions
- Poll-based (GUI checks file periodically)

### 2. **Security First**
- Widgets can block sensitive data (passwords, etc.)
- Explicit permission system
- Client must acquire control
- Actions can be restricted per widget type

### 3. **CSS-Like Selectors**
- Familiar query syntax: `mainWindow/form/textInputs/*`
- Hierarchical widget paths
- Wildcard support
- Type-based queries

### 4. **Zero Visual Confirmation Needed**
- Query widget state programmatically
- Send commands, verify results via queries
- No need to see the UI to test it

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    External Client                       │
│  (Test script, automation tool, remote controller)      │
└────────────┬────────────────────────────────────────────┘
             │
             │ Writes commands to file
             ▼
┌─────────────────────────────────────────────────────────┐
│                   Command File                           │
│  /tmp/rui_app_1234/commands.json + lock file           │
└────────────┬────────────────────────────────────────────┘
             │
             │ GUI polls file (10-60Hz)
             ▼
┌─────────────────────────────────────────────────────────┐
│                  Script Manager                          │
│  • Read commands                                         │
│  • Validate permissions                                  │
│  • Execute on widget tree                                │
│  • Write responses                                       │
└────────────┬────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────┐
│                   Widget Tree                            │
│  • Query state                                           │
│  • Execute actions                                       │
│  • Respect privacy flags                                 │
└─────────────────────────────────────────────────────────┘
```

---

## Core Types

### Widget Extensions

```nim
# Add to core/types.nim Widget object:
type Widget* = ref object of RootObj
  # ... existing fields ...

  # Scripting fields
  stringId*: string              # CSS-like ID (e.g., "loginButton")
  scriptable*: bool              # Can be controlled via scripting
  blockReading*: bool            # Prevent reading sensitive data
  allowedActions*: set[ScriptAction]  # Permitted actions

  # Methods to implement per widget
  # method handleScriptAction*(action: string, params: JsonNode): JsonNode
  # method getScriptableState*(): JsonNode

type ScriptAction* = enum
  saClick,      # Click a button
  saSetText,    # Set text in input
  saGetText,    # Read text value
  saGetState,   # Query widget state
  saEnable,     # Enable/disable widget
  saFocus,      # Set focus
  saSetValue    # Set generic value
```

### Message Protocol

```nim
type
  MessageKind* = enum
    mkCommand      # Client sending command to GUI
    mkQuery        # Client requesting state
    mkResponse     # GUI responding to query
    mkEvent        # GUI notifying about event
    mkError        # Error occurred

  ScriptMessage* = object
    id*: string              # Message ID for matching responses
    clientId*: string        # Who sent this
    timestamp*: int64
    case kind*: MessageKind
    of mkCommand:
      targetPath*: string    # Widget path (CSS-like)
      action*: string        # Action to perform
      params*: JsonNode      # Action parameters
    of mkQuery:
      queryPath*: string     # Path to query (supports wildcards)
      fields*: seq[string]   # Specific fields to return (optional)
      recursive*: bool       # Include children
    of mkResponse:
      success*: bool
      data*: JsonNode        # Widget state(s) or action result
    of mkEvent:
      eventType*: string
      eventData*: JsonNode
    of mkError:
      errorMsg*: string

  ControlFile* = ref object
    commandPath*: string       # Path to command file
    responsePath*: string      # Path to response file
    lockPath*: string          # Lock file path
    controlledBy*: Option[string]  # Current controller ID
```

### Widget Path Syntax (CSS-like)

```
Examples:
  "loginButton"              # Direct ID lookup
  "mainWindow/form/*"        # All children of form
  "*/submitButton"           # Any submitButton at any level
  "form/inputs/TextInput"    # All TextInput widgets in inputs
  "#loginBtn"                # ID selector (future)
  ".primaryButton"           # Class selector (future)
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (2-3 hours)

**1.1 Add Widget Fields**
```nim
# Update core/types.nim
type Widget* = ref object of RootObj
  # ... existing ...
  stringId*: string
  scriptable*: bool
  blockReading*: bool
  allowedActions*: set[ScriptAction]
```

**1.2 Create Script Manager**
```nim
# New file: managers/script_manager.nim
type ScriptManager* = ref object
  app*: App
  controlFile*: ControlFile
  messageQueue*: seq[ScriptMessage]
  lastCheck*: float64
  pollInterval*: float64  # Default: 0.016 (60Hz)

proc newScriptManager*(app: App, workDir: string): ScriptManager
proc poll*(sm: ScriptManager)  # Called from main loop
proc processMessage*(sm: ScriptManager, msg: ScriptMessage): ScriptMessage
```

**1.3 File Protocol**
```nim
# In script_manager.nim
proc writeCommand*(cf: ControlFile, msg: ScriptMessage)
proc readCommands*(cf: ControlFile): seq[ScriptMessage]
proc writeResponse*(cf: ControlFile, msg: ScriptMessage)
proc acquireControl*(cf: ControlFile, clientId: string): bool
proc releaseControl*(cf: ControlFile, clientId: string)
```

### Phase 2: Widget Tree Queries (2 hours)

**2.1 Path Resolution**
```nim
# New file: scripting/selectors.nim
proc findWidgets*(root: Widget, path: string): seq[Widget]
proc matchesSelector*(widget: Widget, selector: string): bool
proc parsePath*(path: string): seq[PathSegment]

type PathSegment* = object
  kind*: SegmentKind
  value*: string

type SegmentKind* = enum
  skId,        # "buttonId"
  skWildcard,  # "*"
  skType       # "Button"
```

**2.2 State Extraction**
```nim
# Add to widgets via mixin/trait
proc getScriptableState*(widget: Widget): JsonNode =
  ## Default implementation - override in specific widgets
  result = %*{
    "id": widget.stringId,
    "type": $widget.type.name,
    "visible": widget.visible,
    "enabled": widget.enabled,
    "bounds": {
      "x": widget.bounds.x,
      "y": widget.bounds.y,
      "width": widget.bounds.width,
      "height": widget.bounds.height
    }
  }
```

### Phase 3: Widget-Specific Actions (1-2 hours)

**3.1 Button**
```nim
# In widgets/button.nim
method handleScriptAction*(widget: Button, action: string,
                           params: JsonNode): JsonNode =
  case action
  of "click":
    if widget.enabled and widget.scriptable:
      widget.onClick()
      return %*{"success": true}
  of "getText":
    if not widget.blockReading:
      return %*{"text": widget.text}
  of "setText":
    widget.text = params["text"].getStr()
    return %*{"success": true}
  else:
    return %*{"error": "Unknown action: " & action}

method getScriptableState*(widget: Button): JsonNode =
  result = procCall widget.Widget.getScriptableState()
  if not widget.blockReading:
    result["text"] = %widget.text
  result["pressed"] = %widget.pressed
```

**3.2 TextInput**
```nim
# In widgets/textinput.nim
method handleScriptAction*(widget: TextInput, action: string,
                           params: JsonNode): JsonNode =
  case action
  of "setText":
    if widget.scriptable:
      widget.text = params["text"].getStr()
      return %*{"success": true}
  of "getText":
    if not widget.blockReading:  # Respect privacy!
      return %*{"text": widget.text}
  of "clear":
    widget.text = ""
    return %*{"success": true}
  of "focus":
    widget.focused = true
    return %*{"success": true}
  else:
    return %*{"error": "Unknown action"}

method getScriptableState*(widget: TextInput): JsonNode =
  result = procCall widget.Widget.getScriptableState()
  if not widget.blockReading:
    result["text"] = %widget.text
  result["focused"] = %widget.focused
  result["placeholder"] = %widget.placeholder
```

### Phase 4: Client Library (1 hour)

**4.1 Nim Client**
```nim
# New file: scripting/client.nim
type ScriptClient* = ref object
  id*: string
  controlFile*: ControlFile
  lastMessageId*: int

proc newScriptClient*(appWorkDir: string): ScriptClient
proc acquireControl*(client: ScriptClient): bool
proc releaseControl*(client: ScriptClient)

proc query*(client: ScriptClient, path: string,
           fields: seq[string] = @[]): JsonNode
proc command*(client: ScriptClient, path: string,
             action: string, params: JsonNode = newJObject()): JsonNode

# High-level helpers
proc click*(client: ScriptClient, buttonPath: string)
proc setText*(client: ScriptClient, inputPath: string, text: string)
proc getText*(client: ScriptClient, widgetPath: string): string
proc waitForVisible*(client: ScriptClient, path: string, timeout: float)
```

### Phase 5: Testing Framework (1-2 hours)

**5.1 Test Types**
```nim
# New file: scripting/testing.nim
type
  TestAction* = object
    widgetPath*: string
    action*: string
    params*: JsonNode
    expect*: Option[JsonNode]  # Expected result

  UITest* = object
    name*: string
    description*: string
    setup*: seq[TestAction]
    actions*: seq[TestAction]
    teardown*: seq[TestAction]
    timeout*: float

  TestRunner* = ref object
    client*: ScriptClient
    results*: seq[TestResult]

proc runTest*(runner: TestRunner, test: UITest): TestResult
proc runSuite*(runner: TestRunner, tests: seq[UITest]): seq[TestResult]
```

---

## Security Model

### Widget Privacy Levels

```nim
# When creating password input:
let passwordInput = newTextInput()
passwordInput.stringId = "passwordField"
passwordInput.scriptable = true
passwordInput.blockReading = true  # ← CAN'T READ via scripting!
passwordInput.allowedActions = {saSetText, saGetState, saFocus}
```

### Control Acquisition

```nim
# Only one client can control at a time
proc acquireControl*(cf: ControlFile, clientId: string): bool =
  if cf.controlledBy.isSome:
    return false  # Already controlled
  cf.controlledBy = some(clientId)
  return true

# Must release when done
proc releaseControl*(cf: ControlFile, clientId: string) =
  if cf.controlledBy == some(clientId):
    cf.controlledBy = none(string)
```

### Action Restrictions

```nim
proc handleScriptAction*(widget: Widget, action: string,
                        params: JsonNode): JsonNode =
  # Check if action is allowed
  let scriptAction = parseScriptAction(action)
  if scriptAction notin widget.allowedActions:
    return %*{"error": "Action not permitted on this widget"}

  # Check if widget is scriptable at all
  if not widget.scriptable:
    return %*{"error": "Widget is not scriptable"}

  # Execute action...
```

---

## Example Usage

### Test Script

```nim
import rui2/scripting/client

# Create client
let client = newScriptClient("/tmp/myapp_1234")

try:
  # Acquire control
  if not client.acquireControl():
    echo "Could not acquire control"
    quit(1)

  # Test login flow
  client.setText("loginForm/username", "testuser")
  client.setText("loginForm/password", "secret123")
  client.click("loginForm/submitButton")

  # Wait for main window to appear
  client.waitForVisible("mainWindow", timeout = 5.0)

  # Query state
  let state = client.query("mainWindow/statusLabel")
  echo "Status: ", state["text"]

  # Verify success
  assert state["text"].getStr() == "Login successful"

finally:
  client.releaseControl()
```

### Widget Definition with Scripting

```nim
defineWidget LoginButton:
  props:
    text: string
    onClick: proc()

  init:
    widget.text = "Login"
    widget.stringId = "loginButton"
    widget.scriptable = true
    widget.blockReading = false
    widget.allowedActions = {saClick, saGetText, saGetState}

  # Standard widget code...
  render:
    drawButton(widget.bounds, widget.text, widget.theme)

  on_click:
    widget.onClick()

# Implement scripting methods
method handleScriptAction*(widget: LoginButton, action: string,
                           params: JsonNode): JsonNode =
  case action
  of "click":
    widget.onClick()
    %*{"success": true, "clicked": true}
  of "getText":
    %*{"text": widget.text}
  else:
    %*{"error": "Unknown action"}
```

---

## File Protocol Details

### Directory Structure
```
/tmp/myapp_12345/
├── commands.json       # Client → GUI
├── responses.json      # GUI → Client
├── control.lock        # Lock file
└── events.json         # GUI → Client (events)
```

### Message Format

**Command File** (`commands.json`):
```json
{
  "id": "msg_001",
  "clientId": "test_client_abc",
  "timestamp": 1699564800,
  "kind": "command",
  "targetPath": "loginForm/submitButton",
  "action": "click",
  "params": {}
}
```

**Response File** (`responses.json`):
```json
{
  "id": "msg_001",
  "timestamp": 1699564800,
  "kind": "response",
  "success": true,
  "data": {
    "clicked": true
  }
}
```

**Query Example**:
```json
{
  "id": "msg_002",
  "clientId": "test_client_abc",
  "timestamp": 1699564801,
  "kind": "query",
  "queryPath": "mainWindow/form/*",
  "fields": ["text", "enabled"],
  "recursive": false
}
```

**Query Response**:
```json
{
  "id": "msg_002",
  "timestamp": 1699564801,
  "kind": "response",
  "success": true,
  "data": {
    "usernameInput": {
      "text": "john_doe",
      "enabled": true
    },
    "passwordInput": {
      "enabled": true
      // Note: no "text" field (blockReading = true)
    },
    "submitButton": {
      "text": "Submit",
      "enabled": true
    }
  }
}
```

---

## Integration with Main Loop

```nim
# In core/app.nim main loop
type App* = ref object
  # ... existing fields ...
  scriptManager*: Option[ScriptManager]

proc mainLoop*(app: App) =
  while not windowShouldClose():
    # ... existing event handling ...

    # Poll scripting system (if enabled)
    if app.scriptManager.isSome:
      app.scriptManager.get().poll()

    # ... layout, render ...
```

---

## Benefits

1. **Testing Without Visual Confirmation**
   - Run tests headless
   - Fast iteration
   - CI/CD integration

2. **Automation**
   - Script repetitive tasks
   - Create macros
   - Remote control

3. **Debugging**
   - Inspect widget tree
   - Query any widget state
   - Modify values on the fly

4. **Accessibility**
   - Screen readers can query UI
   - Automation tools can control
   - Integration with assistive tech

5. **Language Agnostic**
   - Any language can write JSON files
   - Python, Ruby, Shell scripts can control GUI
   - No FFI needed

---

## Next Steps

1. ✅ Design document complete
2. Add widget fields to core/types.nim
3. Implement script_manager.nim
4. Create selector system (path parsing)
5. Add scripting methods to Button, Label, TextInput
6. Build client library
7. Create test examples
8. Write comprehensive tests

**Estimated Time:** 8-12 hours total for full implementation

---

**Design Status:** ✅ Complete
**Ready for Implementation:** Yes
**Dependencies:** None (fully decoupled)
