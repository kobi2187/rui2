# RUI Scripting Examples

This directory contains example scripts demonstrating how to use the RUI scripting system in both **text format** (AutoHotKey, shell scripts) and **JSON format** (Nim client library).

## Text Format Examples

### `commands.txt` / `responses.txt`
Simple line-based command/response examples showing the text format.

### `autohotkey_example.ahk`
Complete AutoHotKey script for Windows automation:
- Send commands to RUI app
- Wait for responses
- Hotkey-triggered automation
- Form filling and button clicking

**Usage:** Load in AutoHotKey and press Ctrl+Shift+L

### `shell_script_example.sh`
Bash script for Linux/Mac automation:
- Command-line RUI app control
- Response parsing
- Sequential command execution

**Usage:**
```bash
chmod +x shell_script_example.sh
./shell_script_example.sh /path/to/rui/app
```

## JSON Format Examples (Nim Client)

### `simple_test.nim`
Basic scripting example using JSON format:
- Connecting to a RUI app
- Querying widget state
- Setting text in inputs
- Clicking buttons
- Waiting for widgets

**Usage:**
```bash
nim c -r simple_test.nim
```

### `login_test.nim`
Complete automated test for a login form:
- Filling in form fields
- Verifying blocked fields (passwords)
- Clicking submit
- Waiting for results
- Testing error cases

**Usage:**
```bash
nim c -r login_test.nim
```

## Text Format vs JSON Format

**Use Text Format when:**
- Writing shell scripts, AutoHotKey scripts, Python scripts
- Simple automation tasks
- Line-based processing is easier
- No need for complex nested data

**Use JSON Format when:**
- Writing Nim programs with the client library
- Need structured responses
- Complex queries with multiple fields
- Programmatic control with type safety

Both formats support the same operations and work identically!

## Creating Your Own Text Format Scripts

### Basic Template (Bash)

```bash
#!/bin/bash
APP_DIR="/path/to/rui/app"
COMMAND_FILE="$APP_DIR/commands.txt"
RESPONSE_FILE="$APP_DIR/responses.txt"

# Write command (format: id selector command [value])
echo "1 myButton invoke" > "$COMMAND_FILE"

# Wait for response (poll until .lock disappears)
while [ -f "$APP_DIR/.lock" ]; do sleep 0.1; done

# Read response
cat "$RESPONSE_FILE"
```

### Text Format Commands

**Format:** `id selector command [value]`

Commands:
- `read` - Query widget state/value
- `write value` - Set widget value
- `invoke` - Trigger widget action (click, submit, etc.)
- `custom:name` - Widget-specific command

Examples:
```
1 loginButton read          # Get button text
2 usernameInput write john  # Set text
3 loginButton invoke        # Click button
4 form/* read               # List children (returns TypeName:widgetId)
5 counter custom:inc        # Custom command
6 Button:submitBtn invoke   # Can optionally specify type
```

## Creating Your Own JSON Format Scripts

### Basic Template (Nim)

```nim
import ../client
import std/json

proc main() =
  # Create client (uses JSON format internally)
  let client = newScriptClient("/path/to/app/dir", "my_client")

  # Check connection
  if not client.isAppResponding():
    echo "App not responding"
    quit(1)

  # Your automation code here
  discard client.setText("myInput", "Hello!")
  discard client.click("myButton")

  # Query results
  let result = client.query("resultLabel")
  if result.isSome:
    echo "Result: ", result.get()

when isMainModule:
  main()
```

### Available Operations (JSON Client)

**Text Input:**
- `setText(path, text)` - Set text in input
- `getText(path)` - Get text from input
- `clear(path)` - Clear input

**Button:**
- `click(path)` - Click button

**Query:**
- `query(path)` - Get widget state
- `query(path, @["field1", "field2"])` - Get specific fields

**Waiting:**
- `waitForWidget(path, timeout)` - Wait for widget to appear
- `waitForCondition(path, field, value, timeout)` - Wait for field value

## Tips

1. **Widget IDs**: Widgets must have `stringId` set to be accessible
2. **App-Level Control**: Enable scripting with `app.enableScripting(dir)`
3. **Privacy**: Set `widget.blockReading = true` for passwords
4. **Paths**: Use CSS-like paths: `"form/button"`, `"form/*"`, etc.
5. **Operate vs Modify**: Scripts can operate app (click, type) but not modify it (change labels, enable/disable)

## Enabling Scripting in Your App

```nim
import rui2/core/app

let app = newApp()
app.enableScripting(getCurrentDir())  # Enable scripting for entire app

# Set widget IDs for access
myButton.stringId = "submitButton"

myInput.stringId = "usernameInput"
myInput.blockReading = false  # Allow reading (default)

passwordInput.stringId = "passwordInput"
passwordInput.blockReading = true  # Block reading for security
```

## How It Works

1. External script creates command file (`.txt` or `.json`) in app directory
2. RUI app polls for this file every ~1 second
3. App creates `.lock` file while processing
4. App processes commands and writes response file
5. App deletes command file and `.lock`
6. External script reads response file
7. Process repeats

**Text format takes priority** if both commands.txt and commands.json exist.

All communication is **local file-based** for security.
