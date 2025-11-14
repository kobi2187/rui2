# RUI Scripting Examples

This directory contains example scripts demonstrating how to use the RUI scripting system.

## Examples

### `simple_test.nim`
Basic scripting example showing:
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

## Creating Your Own Scripts

### Basic Template

```nim
import ../client
import std/json

proc main() =
  # Create client
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

### Available Operations

**Text Input:**
- `setText(path, text)` - Set text in input
- `getText(path)` - Get text from input
- `clear(path)` - Clear input

**Button:**
- `click(path)` - Click button
- `enable(path)` - Enable button
- `disable(path)` - Disable button

**Focus:**
- `focus(path)` - Focus widget
- `blur(path)` - Remove focus

**Query:**
- `query(path)` - Get widget state
- `query(path, @["field1", "field2"])` - Get specific fields

**Waiting:**
- `waitForWidget(path, timeout)` - Wait for widget to appear
- `waitForCondition(path, field, value, timeout)` - Wait for field value

## Tips

1. **Widget IDs**: Widgets must have `stringId` set to be accessible
2. **Scriptable**: Set `widget.scriptable = true` to allow control
3. **Privacy**: Set `widget.blockReading = true` for passwords
4. **Paths**: Use CSS-like paths: `"form/button"`, `"form/*"`, etc.
5. **Timeout**: Default timeout is 5 seconds, adjust with `client.setTimeout(10.0)`

## Enabling Scripting in Your App

```nim
import rui2/core/app

let app = newApp()
app.enableScripting(getCurrentDir())  # Use app's directory

# Set widget IDs
myButton.stringId = "submitButton"
myButton.scriptable = true

myInput.stringId = "usernameInput"
myInput.scriptable = true
myInput.blockReading = false  # Allow reading

passwordInput.stringId = "passwordInput"
passwordInput.scriptable = true
passwordInput.blockReading = true  # Block reading for security
```

## How It Works

1. External script creates `commands.json` in app directory
2. RUI app polls for this file every ~1 second
3. App creates `.lock` file while processing
4. App processes command and writes `responses.json`
5. App deletes `commands.json` and `.lock`
6. External script reads `responses.json`
7. Process repeats

All communication is **local file-based** for security.
