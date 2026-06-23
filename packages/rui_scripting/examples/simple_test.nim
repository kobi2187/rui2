## Simple Scripting Test Example
##
## This example demonstrates how to use the scripting client
## to control a RUI application programmatically.

import ../client
import std/[json, os]

proc main() =
  echo "RUI Scripting Test Example"
  echo "=========================="
  echo ""

  # Create a client pointing to the app's script directory
  # Adjust this path to match your RUI app's executable directory
  let appDir = getCurrentDir()  # Or specify absolute path
  let client = newScriptClient(appDir, "test_client")

  echo "Connecting to RUI app at: ", appDir
  echo "Client ID: ", client.id
  echo ""

  # Check if app is responding
  if not client.isAppResponding():
    echo "ERROR: RUI app is not responding"
    echo "Make sure the app is running and scripting is enabled"
    quit(1)

  echo "✓ App is responding"
  echo ""

  # Example 1: Query a button
  echo "Example 1: Querying button state"
  echo "---------------------------------"
  let buttonState = client.query("loginButton")
  if buttonState.isSome:
    echo "Button state: ", buttonState.get().pretty()
  else:
    echo "Button not found (this is OK if it doesn't exist)"
  echo ""

  # Example 2: Set text in a text input
  echo "Example 2: Setting text in input"
  echo "---------------------------------"
  if client.setText("usernameInput", "testuser"):
    echo "✓ Text set successfully"
  else:
    echo "✗ Failed to set text (widget may not exist)"
  echo ""

  # Example 3: Query text input state
  echo "Example 3: Querying text input"
  echo "-------------------------------"
  let inputState = client.query("usernameInput")
  if inputState.isSome:
    echo "Input state: ", inputState.get().pretty()
  else:
    echo "Input not found"
  echo ""

  # Example 4: Click a button
  echo "Example 4: Clicking button"
  echo "--------------------------"
  if client.click("submitButton"):
    echo "✓ Button clicked successfully"
  else:
    echo "✗ Failed to click button (widget may not exist)"
  echo ""

  # Example 5: Wait for a widget to appear
  echo "Example 5: Waiting for widget"
  echo "------------------------------"
  echo "Waiting for 'resultLabel' (timeout: 3s)..."
  if client.waitForWidget("resultLabel", timeout = 3.0):
    echo "✓ Widget appeared"
    let state = client.query("resultLabel")
    if state.isSome:
      echo "Label state: ", state.get().pretty()
  else:
    echo "✗ Widget did not appear (timeout)"
  echo ""

  # Example 6: Query all widgets matching a pattern
  echo "Example 6: Query multiple widgets"
  echo "----------------------------------"
  let allButtons = client.query("*")  # Query all widgets
  if allButtons.isSome:
    echo "Found widgets: ", allButtons.get().pretty()
  else:
    echo "No widgets found"
  echo ""

  echo "Test completed!"

# Run the test
when isMainModule:
  main()
