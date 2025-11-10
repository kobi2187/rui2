# We know exactly what each widget is and can do
type
  Scriptable = object
    id: string              # Clear identity
    allowedActions: set[ScriptAction]  # Explicit capabilities
    isScriptable: bool      # Can disable scripting per widget

  Button = ref object
    base: Scriptable
    onClick: proc()
    # ... other fields



# Part of the widget definition
defineWidget Button:
  props:
    text: string
    onClick: proc()

  scripting:  # New section in widget definition
    actions:
      click:
        widget.onClick()
      enable:
        widget.enabled = value.getBool()
      setText:
        widget.text = value.getStr()

# We can validate commands at compile time
proc validateScriptCommand(widget: Widget, cmd: ScriptCommand) =
  # We know exactly what commands each widget supports
  if cmd.action notin widget.allowedActions:
    raise newException(ScriptError,
      "Widget " & widget.id & " doesn't support action: " & cmd.action)

# Can automatically generate docs about scriptable widgets
proc generateScriptingDocs(app: App): string =
  for widget in app.widgets:
    if widget.isScriptable:
      result.add "Widget: " & widget.id & "\n"
      result.add "Supported actions:\n"
      for action in widget.allowedActions:
        result.add "  - " & $action & "\n"

type
  ScriptingPolicy = object
    allowedWidgets: HashSet[string]
    allowedActions: HashSet[string]
    requireAuth: bool

# Can implement proper security
proc handleScriptCommand(app: App, cmd: ScriptCommand) =
  if not app.policy.isAllowed(cmd):
    raise newException(SecurityError, "Command not allowed by policy")
