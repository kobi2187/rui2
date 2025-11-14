# RUI2 Scripting System - Overview

## Simple File-Based Control Protocol

The RUI2 scripting system provides **local programmatic control** over GUI applications through a simple, secure file-based protocol. No network sockets, no complex IPC - just files.

## How It Works

### Security: Local Only
To avoid security/hacking issues, **only local file-based communication is supported**. We chose file-based over traditional IPC for simplicity and language-agnostic access.

### The Protocol Flow

1. **External program** creates a command file in the RUI app's folder (where the executable resides)
2. **Commands** can:
   - **read** - Query widget state
   - **write** - Set widget values (operate, not modify!)
   - **invoke** - Trigger widget actions (click button, submit form)
   - **custom:X** - Widget-specific commands (inc, dec, etc.)
3. **RUI app** polls every ~1 second for the command file
4. When detected:
   - Creates `.lock` file to indicate processing
   - Processes all commands
   - Writes results to response file
   - Deletes command file and `.lock` file
5. **External program** reads response file
6. Process repeats - external program can create new command file, etc.

### Two Formats

**Text Format** (`commands.txt` / `responses.txt`):
- Simple line-based format for shell scripts, AutoHotKey, etc.
- Format: `id selector command [value]`
- Responses: `id result` (OK/Fail/value/[list])
- Uses numeric IDs for matching responses

**JSON Format** (`commands.json` / `responses.json`):
- Structured format for programmatic clients
- No need for numeric IDs - uses message structure
- Better for complex queries and nested data
- Supports all JSON data types

Both formats are equivalent in functionality. **Text format takes priority** if both exist.

### Important: Operate vs. Modify

Users can **operate** the app (click buttons, type text, query state) but **cannot modify** it (can't change button labels, widget properties, etc.). This is by design for security.

### Privacy Protection

Widgets can block sensitive fields (like passwords) from being queried. Any field the RUI user marks as `blockReading=true` cannot be read via scripting.

## Why Build This In From Day One?

Rather than hack in automation/testing capabilities later, we design for programmatic control from the beginning. This enables:

- **Automated Testing** - Test UI without visual confirmation
- **External Tools** - Other programs can control/query the GUI
- **Accessibility** - Screen readers and automation tools
- **Dev Tools** - Inspect and modify widget state on the fly

## Example Usage

### Text Format (`commands.txt`)
```
# Command format: id selector command [value]
1 loginButton read
2 usernameInput write john_doe
3 passwordInput write secret123
4 loginButton invoke
5 loginForm/* read
6 statusLabel read
```

### Text Response (`responses.txt`)
```
1 Login
2 OK
3 OK
4 OK
5 [usernameInput, passwordInput, loginButton]
6 Login successful
```

### JSON Format (`commands.json`)
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

### JSON Response (`responses.json`)
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
