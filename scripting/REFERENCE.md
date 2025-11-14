# RUI Scripting System - Complete Reference

## Overview

Two equivalent formats for controlling RUI apps:
- **Text format** - Simple line-based (commands.txt / responses.txt)
- **JSON format** - Structured messages (commands.json / responses.json)

**Text format takes priority** if both files exist.

---

## Text Format

### Command Syntax

```
id selector command [value]
```

- **id** - Numeric identifier for matching responses (1, 2, 3...)
- **selector** - Widget path (see Selector Syntax below)
- **command** - Operation to perform
- **value** - Optional parameter for write/custom commands

### Commands

| Command | Description | Requires Value | Example |
|---------|-------------|----------------|---------|
| `read` | Query widget state/value | No | `1 loginButton read` |
| `write` | Set widget value | Yes | `2 usernameInput write john` |
| `invoke` | Trigger action (click, submit, etc.) | No | `3 loginButton invoke` |
| `custom:X` | Widget-specific command | No | `4 counter custom:inc` |

### Selector Syntax

| Format | Description | Example |
|--------|-------------|---------|
| `widgetId` | Simple ID lookup | `loginButton` |
| `TypeName:widgetId` | Explicit type (optional) | `Button:loginButton` |
| `parent/*` | List direct children | `form/*` |
| `parent/**` | List all descendants | `window/**` |

### Response Syntax

```
id result
```

**Result types:**
- `OK` - Success (for write/invoke)
- `Fail` - Error occurred
- `<value>` - Actual value (for read commands)
- `[TypeName:id1, TypeName:id2, ...]` - List of widgets (wildcard queries)

### Example Session

**commands.txt:**
```
1 loginButton read
2 usernameInput write admin
3 passwordInput write secret123
4 loginButton invoke
5 loginForm/* read
```

**responses.txt:**
```
1 Login
2 OK
3 OK
4 OK
5 [TextInput:usernameInput, TextInput:passwordInput, Button:loginButton]
```

### Text Format Advantages

✓ Simple line-based format
✓ Easy for shell scripts, AutoHotKey, Python
✓ Multiple commands in one file
✓ No JSON parsing needed
✓ Human-readable and writable

### Text Format Limitations

✗ Less structured
✗ Single values only (no nested data)
✗ Sequential numeric IDs required
✗ Limited field selection (queries return full state)

---

## JSON Format

### Message Types

| Type | Direction | Purpose |
|------|-----------|---------|
| `mkCommand` | Client → App | Execute action on widget |
| `mkQuery` | Client → App | Query widget state |
| `mkResponse` | App → Client | Success response |
| `mkError` | App → Client | Error response |
| `mkEvent` | App → Client | Event notification (future) |

### Command Message

```json
{
  "id": "msg_001",
  "clientId": "test_client",
  "timestamp": 1699564800,
  "kind": "command",
  "targetPath": "loginButton",
  "action": "click",
  "params": {}
}
```

**Fields:**
- `id` - Unique message ID (any string)
- `clientId` - Client identifier
- `timestamp` - Unix timestamp
- `kind` - "command"
- `targetPath` - Widget selector (CSS-like)
- `action` - Action name (click, setText, etc.)
- `params` - JSON object with action parameters

### Query Message

```json
{
  "id": "msg_002",
  "clientId": "test_client",
  "timestamp": 1699564800,
  "kind": "query",
  "queryPath": "loginForm/*",
  "fields": ["text", "enabled"],
  "recursive": false
}
```

**Fields:**
- `queryPath` - Widget selector (supports wildcards)
- `fields` - Array of field names to return (empty = all)
- `recursive` - Include descendants

### Response Message

```json
{
  "id": "msg_001",
  "timestamp": 1699564801,
  "kind": "response",
  "success": true,
  "data": {
    "clicked": true
  }
}
```

**Fields:**
- `success` - Boolean success flag
- `data` - JSON object with results

### Error Message

```json
{
  "id": "msg_001",
  "timestamp": 1699564801,
  "kind": "error",
  "errorMsg": "Widget not found",
  "errorCode": 404
}
```

### JSON Format Advantages

✓ Structured, nested data
✓ No sequential IDs needed
✓ Supports complex queries
✓ Type-safe with Nim client library
✓ Can specify which fields to return
✓ Extensible message types

### JSON Format Limitations

✗ More verbose
✗ Requires JSON parsing
✗ Single command per file
✗ Harder to write manually

---

## Widget Actions by Type

### Button

| Action | Description | Parameters |
|--------|-------------|------------|
| `click` / `invoke` | Trigger onClick callback | None |
| `getText` / `read` | Get button text | None |
| `enable` | Enable button | None |
| `disable` | Disable button | None |

**Text format:**
```
1 submitBtn invoke
2 submitBtn read
```

**JSON format:**
```json
{"kind": "command", "targetPath": "submitBtn", "action": "click", "params": {}}
```

### TextInput

| Action | Description | Parameters |
|--------|-------------|------------|
| `setText` / `write` | Set text value | `text: string` |
| `getText` / `read` | Get text value | None |
| `clear` | Clear text | None |
| `focus` | Focus input | None |
| `blur` | Remove focus | None |
| `submit` / `invoke` | Trigger onSubmit | None |

**Text format:**
```
1 usernameInput write john
2 usernameInput read
3 usernameInput clear
4 usernameInput invoke
```

**JSON format:**
```json
{"kind": "command", "targetPath": "usernameInput", "action": "setText",
 "params": {"text": "john"}}
```

### Generic Widget

| Action | Description |
|--------|-------------|
| `getState` | Get full widget state |

---

## Command Translation

The system automatically translates generic commands to widget-specific actions:

### Text Format Translation

| Text Command | Widget Type | Translated Action |
|--------------|-------------|-------------------|
| `read` | Button | `getText` |
| `read` | TextInput | `getText` |
| `read` | CheckBox | `getChecked` |
| `read` | Any | `getState` |
| `write <val>` | TextInput | `setText` |
| `write <val>` | CheckBox | `setChecked` |
| `write <val>` | Slider | `setValue` |
| `invoke` | Button | `click` |
| `invoke` | TextInput | `submit` |
| `invoke` | CheckBox | `toggle` |
| `custom:X` | Any | `custom:X` |

**Type detection:**
- Uses actual widget type via `getTypeName()`
- Can be specified explicitly: `Button:submitBtn invoke`
- Wildcard queries return format: `TypeName:widgetId`

---

## Privacy & Security

### blockReading Flag

Widgets can block sensitive fields from being queried:

```nim
passwordInput.stringId = "passwordInput"
passwordInput.scriptable = true
passwordInput.blockReading = true  # ← Can't read text!
```

**Result:**
- `write` commands still work
- `read` commands return `"Reading blocked"` error
- State queries omit blocked fields

### scriptable Flag

Controls whether widget can be controlled at all:

```nim
criticalButton.scriptable = false  # ← Can't be scripted
```

### allowedActions Set

Restrict specific actions (future feature):

```nim
widget.allowedActions = {saSetText, saFocus}  # Only these actions
```

### Visual Indicator

While processing commands (`.lock` file exists):
- **Orange border** around window (4px thick)
- **"SCRIPTING" badge** in top-right corner
- Users always know when app is under external control

---

## Operate vs. Modify

**Users can OPERATE the app:**
- ✓ Click buttons
- ✓ Type text
- ✓ Query state
- ✓ Trigger callbacks

**Users CANNOT MODIFY the app:**
- ✗ Change button labels
- ✗ Modify widget properties
- ✗ Alter UI structure
- ✗ Change widget types

This is by design for security.

---

## Use Cases

### When to Use Text Format

- Shell scripts (bash, PowerShell)
- AutoHotKey automation
- Python scripts
- Simple automation tasks
- Multiple sequential commands
- Human-readable logs

### When to Use JSON Format

- Nim programs with client library
- Complex nested data
- Selective field queries
- Type-safe interactions
- Event-driven workflows
- Integration with JSON APIs

---

## Client Library (JSON Format Only)

The Nim client library provides high-level API:

```nim
import scripting/client

let client = newScriptClient("/path/to/app")

# High-level methods
client.setText("input", "value")
client.click("button")
let text = client.getText("label")

# Wait utilities
client.waitForWidget("dialog", timeout = 5.0)
client.waitForCondition("status", "text", %"Ready", timeout = 3.0)

# Raw query/command
let state = client.query("form/*")
let result = client.command("widget", "customAction", %*{"param": "value"})
```

---

## File Protocol Details

### Polling

- RUI app polls every ~1 second for command file
- Adjustable: `scriptManager.setPolling(0.5)`  # 500ms

### Lock File

- Created: When app starts processing commands
- Deleted: When processing completes
- Purpose: Prevents race conditions, enables visual indicator

### File Lifecycle

1. External program writes `commands.txt` or `commands.json`
2. RUI app detects file on next poll
3. App creates `.lock` file (visual indicator appears)
4. App processes all commands
5. App writes `responses.txt` or `responses.json`
6. App deletes command file and `.lock` (visual indicator disappears)
7. External program reads response file
8. External program can create new command file

### Directory Structure

```
/path/to/rui/app/
├── myapp              # RUI executable
├── commands.txt       # Client → App (text format)
├── responses.txt      # App → Client (text format)
├── commands.json      # Client → App (JSON format)
├── responses.json     # App → Client (JSON format)
└── .lock              # Processing indicator
```

---

## Error Handling

### Text Format Errors

**Response:**
```
1 Fail
2 Widget not found
3 Action not permitted
```

**Common errors:**
- `Widget not found`
- `Reading blocked`
- `Not scriptable`
- `Action not permitted`
- `Text exceeds maxLength`

### JSON Format Errors

**Response:**
```json
{
  "id": "msg_001",
  "kind": "error",
  "errorMsg": "Widget not found: loginButton",
  "errorCode": 404
}
```

**Error codes:**
- `400` - Bad request (invalid command)
- `404` - Widget not found
- `500` - Internal error

---

## Quick Reference

### Text Format Cheat Sheet

```bash
# Read operations
1 button read              # Get button text
2 input read               # Get input value
3 form/* read              # List children

# Write operations
4 input write hello        # Set text
5 checkbox write true      # Set checked

# Invoke operations
6 button invoke            # Click button
7 form invoke              # Submit form

# Custom operations
8 spinner custom:inc       # Increment
9 slider custom:reset      # Custom reset
```

### JSON Format Cheat Sheet

```json
// Query widget
{"kind": "query", "queryPath": "widget", "fields": [], "recursive": false}

// Execute command
{"kind": "command", "targetPath": "widget", "action": "click", "params": {}}

// Set text
{"kind": "command", "targetPath": "input", "action": "setText",
 "params": {"text": "value"}}
```

---

## Best Practices

1. **Set meaningful stringIds**
   ```nim
   button.stringId = "submitButton"  # Not "button1"
   ```

2. **Mark sensitive fields**
   ```nim
   passwordInput.blockReading = true
   ```

3. **Use explicit types when ambiguous**
   ```
   # Text format
   Button:submit invoke  # Clear which widget type
   ```

4. **Wait for completion**
   ```nim
   # Poll until .lock disappears
   while fileExists(".lock"): sleep(100)
   ```

5. **Handle timeouts**
   ```nim
   client.setTimeout(10.0)  # Longer timeout for slow operations
   ```

6. **Check for errors**
   ```nim
   let result = client.click("button")
   if not result:
     echo "Click failed"
   ```

---

## Summary

| Feature | Text Format | JSON Format |
|---------|-------------|-------------|
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Power** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Multiple commands** | ✓ (per file) | ✗ (one per file) |
| **Nested data** | ✗ | ✓ |
| **Type safety** | ✗ | ✓ (with Nim client) |
| **Field selection** | ✗ | ✓ |
| **Shell scripts** | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| **Programmatic** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

Choose based on your needs:
- **Text format** for simple automation, scripts, human interaction
- **JSON format** for complex queries, type safety, programmatic control
