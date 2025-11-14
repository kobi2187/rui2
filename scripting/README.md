# RUI2 Scripting System - Overview

## Simple File-Based Control Protocol

The RUI2 scripting system provides **local programmatic control** over GUI applications through a simple, secure file-based protocol. No network sockets, no complex IPC - just files.

## How It Works

### Security: Local Only
To avoid security/hacking issues, **only local file-based communication is supported**. We chose file-based over traditional IPC for simplicity and language-agnostic access.

### The Protocol Flow

1. **External program** creates a `commands.json` file in the RUI app's folder (where the executable resides)
2. **Commands** can:
   - **Query** widget state using CSS-like syntax (e.g., `mainWindow/form/button`)
   - **Modify** widget values
   - **Invoke** widget actions (e.g., click a button)
3. **RUI app** polls every ~1 second for the commands file
4. When detected:
   - Creates `.lock` file to indicate processing
   - Processes all commands
   - Writes results to `responses.json`
   - Deletes `commands.json` and `.lock` file
5. **External program** reads `responses.json`
6. Process repeats - external program can create new commands file, etc.

### Privacy Protection

Widgets can block sensitive fields (like passwords) from being queried. Any field the RUI user marks as private/blocked cannot be read via scripting.

### Format

Originally planned as line-based, now using **JSON format** for commands and responses for better structure and extensibility.

## Why Build This In From Day One?

Rather than hack in automation/testing capabilities later, we design for programmatic control from the beginning. This enables:

- **Automated Testing** - Test UI without visual confirmation
- **External Tools** - Other programs can control/query the GUI
- **Accessibility** - Screen readers and automation tools
- **Dev Tools** - Inspect and modify widget state on the fly

## Example Usage

### Command File (`commands.json`)
```json
{
  "id": "msg_001",
  "clientId": "my_script",
  "timestamp": 1699564800,
  "kind": "query",
  "queryPath": "mainWindow/loginForm/*",
  "fields": ["text", "enabled"],
  "recursive": false
}
```

### Response File (`responses.json`)
```json
{
  "id": "msg_001",
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
      // Note: "text" field omitted (blockReading = true)
    }
  }
}
```

## Files in This Directory

- **`messages.nim`** - Core message types and JSON serialization
- **`script_manager.nim`** - File polling, command processing, widget tree execution
- **`selectors.nim`** - CSS-like path parsing and widget matching
- **`client.nim`** - Client library for external programs to use
- **`testing.nim`** - Test framework built on the scripting system

## See Also

- `SCRIPTING_SYSTEM_DESIGN.md` - Comprehensive technical design document
- `FOR_REFERENCE/quickui/scripting/` - Original quickui implementation
