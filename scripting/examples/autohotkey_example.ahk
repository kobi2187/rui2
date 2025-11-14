; AutoHotKey Example for RUI Scripting
; This demonstrates how to control a RUI app from AutoHotKey on Windows
;
; Prerequisites:
; - RUI app must be running with scripting enabled
; - Set AppDir to match your RUI app's directory

; Configuration
AppDir := "C:\path\to\your\rui\app"
CommandFile := AppDir . "\commands.txt"
ResponseFile := AppDir . "\responses.txt"
LockFile := AppDir . "\.lock"

; Wait for app to be ready (no lock file)
WaitForApp() {
    global LockFile
    Loop {
        if (!FileExist(LockFile)) {
            return true
        }
        Sleep, 100
    }
}

; Send command and wait for response
SendCommand(id, selector, command, value := "") {
    global CommandFile, ResponseFile, LockFile

    ; Build command line
    line := id . " " . selector . " " . command
    if (value != "") {
        line := line . " " . value
    }

    ; Delete old response file
    if (FileExist(ResponseFile)) {
        FileDelete, %ResponseFile%
    }

    ; Write command
    FileAppend, %line%`n, %CommandFile%

    ; Wait for lock to appear
    Loop {
        if (FileExist(LockFile)) {
            break
        }
        Sleep, 50
    }

    ; Wait for lock to disappear (processing complete)
    Loop {
        if (!FileExist(LockFile)) {
            break
        }
        Sleep, 50
    }

    ; Read response
    Sleep, 50  ; Small delay to ensure file is written
    if (FileExist(ResponseFile)) {
        FileRead, response, %ResponseFile%
        return response
    }
    return "No response"
}

; Example: Automate login
^+L::  ; Ctrl+Shift+L hotkey
    WaitForApp()

    ; Fill in username
    response := SendCommand(1, "usernameInput", "write", "testuser")
    MsgBox, Username set: %response%

    ; Fill in password
    response := SendCommand(2, "passwordInput", "write", "password123")
    MsgBox, Password set: %response%

    ; Click login button
    response := SendCommand(3, "loginButton", "invoke")
    MsgBox, Button clicked: %response%

    ; Wait a moment for login to process
    Sleep, 1000

    ; Check status
    response := SendCommand(4, "statusLabel", "read")
    MsgBox, Login status: %response%
return

; Example: Query form widgets
^+Q::  ; Ctrl+Shift+Q hotkey
    WaitForApp()
    response := SendCommand(1, "loginForm/*", "read")
    MsgBox, Form widgets: %response%
return
