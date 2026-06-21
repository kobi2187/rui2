## Login Form Test Example
##
## Demonstrates automated testing of a login form using the scripting API.
## This shows how to:
## - Fill in form fields
## - Click buttons
## - Wait for results
## - Verify state changes

import ../client
import std/[json, os]

proc testLoginFlow(client: ScriptClient) =
  echo "Testing Login Flow"
  echo "=================="
  echo ""

  # Step 1: Clear any existing text
  echo "1. Clearing form fields..."
  discard client.clear("usernameInput")
  discard client.clear("passwordInput")
  echo "   ✓ Fields cleared"
  echo ""

  # Step 2: Fill in username
  echo "2. Entering username..."
  if not client.setText("usernameInput", "admin"):
    echo "   ✗ Failed to set username"
    return
  echo "   ✓ Username entered"
  echo ""

  # Step 3: Fill in password
  echo "3. Entering password..."
  if not client.setText("passwordInput", "admin123"):
    echo "   ✗ Failed to set password"
    return
  echo "   ✓ Password entered"
  echo ""

  # Step 4: Verify input values (password should be blocked)
  echo "4. Verifying input values..."
  let usernameText = client.getText("usernameInput")
  if usernameText.isSome:
    echo "   Username: ", usernameText.get()
  else:
    echo "   ✗ Could not read username"

  # Password should be blocked
  let passwordText = client.getText("passwordInput")
  if passwordText.isNone:
    echo "   ✓ Password correctly blocked from reading"
  else:
    echo "   ✗ WARNING: Password was readable (should be blocked!)"
  echo ""

  # Step 5: Click login button
  echo "5. Clicking login button..."
  if not client.click("loginButton"):
    echo "   ✗ Failed to click login button"
    return
  echo "   ✓ Login button clicked"
  echo ""

  # Step 6: Wait for result
  echo "6. Waiting for login result..."
  if client.waitForWidget("loginStatus", timeout = 5.0):
    let status = client.query("loginStatus", @["text"])
    if status.isSome:
      echo "   Login status: ", status.get().pretty()
    else:
      echo "   ✗ Could not read status"
  else:
    echo "   ✗ Login status did not appear"
  echo ""

  echo "Test completed!"

proc testInvalidLogin(client: ScriptClient) =
  echo "Testing Invalid Login"
  echo "====================="
  echo ""

  # Try invalid credentials
  echo "1. Entering invalid credentials..."
  discard client.setText("usernameInput", "wronguser")
  discard client.setText("passwordInput", "wrongpass")
  echo "   ✓ Invalid credentials entered"
  echo ""

  echo "2. Clicking login..."
  discard client.click("loginButton")
  echo ""

  echo "3. Waiting for error message..."
  if client.waitForWidget("errorMessage", timeout = 3.0):
    let error = client.query("errorMessage", @["text"])
    if error.isSome:
      echo "   Error message: ", error.get().pretty()
    else:
      echo "   ✗ Could not read error"
  else:
    echo "   ✗ No error message appeared"
  echo ""

proc main() =
  echo "RUI Login Form Automation Test"
  echo "==============================="
  echo ""

  # Setup client
  let appDir = getCurrentDir()
  let client = newScriptClient(appDir, "login_tester")

  # Check app is running
  if not client.isAppResponding():
    echo "ERROR: RUI app is not responding"
    echo "Make sure the login app is running with scripting enabled"
    quit(1)

  echo "✓ Connected to app"
  echo ""

  # Run tests
  testLoginFlow(client)
  echo ""
  echo "=" .repeat(50)
  echo ""
  testInvalidLogin(client)

when isMainModule:
  main()
