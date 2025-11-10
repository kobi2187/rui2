try:
  let client = GuiClient(id: generateUUID())

  if client.acquireControl():
    echo "Successfully acquired GUI control"

    # Do automation
    client.clickButton("saveButton")
    client.setText("nameInput", "John")

    # Release when done
    client.releaseControl()
  else:
    echo "Could not acquire GUI control"
except ControlError:
  echo "Lost control of GUI"
