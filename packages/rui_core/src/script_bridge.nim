## The scripting verb set, as ordinary code.
##
## Every widget answers the same small vocabulary -- read, gettext, write,
## invoke, and the name of any action it declares -- and that vocabulary used to
## be *generated into* each of them: 203 lines of `quote do` emitting a complete
## command interpreter per widget type, 47 times over, at a cyclomatic
## complexity of 43 against a repo whose next-worst routine was 16.
##
## It lives here once now, as procs you can read, step through and test. What
## the DSL emits is a `ScriptDescriptor`: the widget's field names paired with
## setters, its action names paired with invokers, and nothing else. Data, not
## control flow.
##
## The point of the split is that the descriptor is ordinary data a hand-written
## widget can build for itself:
##
## ```nim
## type Gauge = ref object of Widget
##   level: float32
##
## let GaugeScript = ScriptDescriptor(
##   typeName: "Gauge",
##   defaultField: "level",
##   fields: @[scriptField("level", proc(w: Widget, v: JsonNode): bool =
##                                    scriptAssign(Gauge(w).level, v))])
##
## method handleScriptAction*(w: Gauge, action: string, params: JsonNode): JsonNode =
##   dispatchScriptAction(w, GaugeScript, action, params)
## ```
##
## No macro involved, same scripting support.

import std/[json, strutils, options]
import types

type
  ScriptField* = object
    ## One writable field: its name as a script spells it, and how to set it.
    name*: string
    assign*: proc(widget: Widget, value: JsonNode): bool {.closure.}
      ## Returns false when the JSON cannot be coerced into the field's type.

  ScriptAction* = object
    ## One declared action, and the names a script may call it by.
    ##
    ## `aliases` holds lowercased spellings -- `onToggle` is reachable as both
    ## "ontoggle" and "toggle", which is why a script can say `click` for
    ## `onClick`.
    aliases*: seq[string]
    invoke*: proc(widget: Widget): bool {.closure.}
      ## Fires the handler if one is attached. False means the action exists but
      ## nothing is listening, which is not an error.

  ScriptDescriptor* = object
    ## Everything the dispatcher needs to know about one widget type.
    typeName*: string
    fields*: seq[ScriptField]
    actions*: seq[ScriptAction]
    defaultField*: string
      ## Written when a script says `write <value>` with no field name.
    getText*: proc(widget: Widget): string {.closure.}
      ## nil when the widget has no text to read.
    toggle*: proc(widget: Widget): Option[bool] {.closure.}
      ## Flips a checkable widget and returns the new value. nil otherwise.

# ---------------------------------------------------------------------------
# Field coercion, and the four "does this widget have one?" questions
#
# These are templates rather than procs because each one asks `when compiles`
# about a field that only some widget types have. Keeping them here rather than
# inside the DSL is what holds buildScriptActionMethod down to emission: a
# `when`/`else` written inside a `quote do` still counts as a branch of the
# macro that quotes it, so every guard left in the macro showed up in its
# cyclomatic complexity even though it was data being emitted, not control flow
# being executed.
# ---------------------------------------------------------------------------

proc asBool*(node: JsonNode): Option[bool] =
  ## A script writing a checkbox may say true, 1, "yes" or "on". Text is what
  ## the file protocol actually carries, so the string spellings are not a
  ## convenience -- they are the common case.
  case node.kind
  of JBool: some(node.getBool())
  of JInt: some(node.getInt() != 0)
  of JString: some(node.getStr().toLowerAscii() in ["true", "1", "yes", "on"])
  else: none(bool)

proc asInteger*(node: JsonNode): Option[BiggestInt] =
  case node.kind
  of JInt: some(node.getInt().BiggestInt)
  of JFloat: some(node.getFloat().BiggestInt)
  of JString:
    try: some(parseBiggestInt(node.getStr()))
    except ValueError: none(BiggestInt)
  else: none(BiggestInt)

proc asNumber*(node: JsonNode): Option[float] =
  case node.kind
  of JFloat: some(node.getFloat())
  of JInt: some(node.getInt().float)
  of JString:
    try: some(parseFloat(node.getStr()))
    except ValueError: none(float)
  else: none(float)

proc asText*(node: JsonNode): string =
  ## Never fails: anything that is not already a string is rendered as json,
  ## which is more useful to a script than a refusal.
  if node.kind == JString: node.getStr() else: $node

template takeInto(opt, dst: untyped): bool =
  ## Assign a coerced value if the coercion produced one.
  block:
    let coerced = opt
    if coerced.isSome:
      dst = typeof(dst)(coerced.get())
      true
    else:
      false

template scriptAssign*(dst: untyped, node: JsonNode): bool =
  ## Coerce a JSON value (or a text-format string) into `dst`.
  ## Returns false when the value cannot be represented in dst's type.
  when dst is bool: takeInto(asBool(node), dst)
  elif dst is SomeInteger: takeInto(asInteger(node), dst)
  elif dst is SomeFloat: takeInto(asNumber(node), dst)
  elif dst is string:
    dst = asText(node)
    true
  else: false

template assignField*(dst: untyped, node: JsonNode): bool =
  ## `scriptAssign` for a field that may not exist on this widget type.
  when compiles(scriptAssign(dst, node)): scriptAssign(dst, node)
  else: false

template textOrEmpty*(w: untyped): string =
  ## The widget's text, or "" when it has none.
  when compiles($w.text): $w.text
  else: ""

template fireAction*(handler: untyped): bool =
  ## Call a no-argument action handler. False when the field does not exist on
  ## this type, or exists with nothing attached.
  when compiles(handler.get()()):
    if handler.isSome:
      handler.get()()
      true
    else: false
  else: false

template fireAction*(handler, arg: untyped): bool =
  ## Same, for a handler taking the widget's own state as its argument.
  when compiles(handler.get()(arg)):
    if handler.isSome:
      handler.get()(arg)
      true
    else: false
  else: false

template flipIfCheckable*(w: untyped): Option[bool] =
  ## Flip `w.checked` and notify `w.onToggle`, or `none` if this type has no
  ## `checked` field. Note the doubled parens in `compiles((a = b))`: inside a
  ## call's argument list Nim reads `a = b` as a named argument rather than an
  ## assignment, and the single-paren form silently answers false.
  when compiles((w.checked = not w.checked)):
    w.checked = not w.checked
    discard fireAction(w.onToggle, w.checked)
    some(w.checked)
  else:
    none(bool)

proc baseScriptableState*(widget: Widget, typeName: string): JsonNode =
  ## The half of a state report that is the same for every widget. Never
  ## withheld by `blockReading`: a script that cannot see a widget's geometry
  ## cannot address it at all, and hiding the id would break the selector
  ## syntax rather than protect anything.
  %*{
    "id": widget.stringId,
    "type": typeName,
    "visible": widget.visible,
    "enabled": widget.enabled,
    "focused": widget.focused,
    "bounds": {
      "x": widget.bounds.x,
      "y": widget.bounds.y,
      "width": widget.bounds.width,
      "height": widget.bounds.height
    }
  }

template reportField*(dst: JsonNode, widget: Widget, key: string,
                      value: untyped) =
  ## Add one prop or state field to a report, if json can represent it and the
  ## widget is not withholding its contents. A field of a type that is neither
  ## json-encodable nor stringable is skipped rather than refused, so adding an
  ## exotic field to a widget cannot break its scripting.
  if not widget.blockReading:
    when compiles(%value): dst[key] = %value
    elif compiles($value): dst[key] = %($value)

proc scriptField*(name: string,
                  assign: proc(widget: Widget, value: JsonNode): bool {.closure.}):
                 ScriptField =
  ScriptField(name: name, assign: assign)

proc scriptAction*(aliases: seq[string],
                   invoke: proc(widget: Widget): bool {.closure.}): ScriptAction =
  ScriptAction(aliases: aliases, invoke: invoke)

# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------

proc ok*(): JsonNode = %*{"success": true}
proc ok*(key: string, value: JsonNode): JsonNode =
  result = %*{"success": true}
  result[key] = value
proc fail*(reason: string): JsonNode = %*{"success": false, "error": reason}

# ---------------------------------------------------------------------------
# Verbs
# ---------------------------------------------------------------------------

const
  ReadVerbs = ["read", "getstate", "query", "state"]
  WriteVerbs = ["write", "set", "settext", "setvalue"]
  ToggleVerbs = ["toggle", "click"]

proc findField(desc: ScriptDescriptor, name: string): int =
  ## Index of the field a script means, or -1. Compared with cmpIgnoreStyle, so
  ## `maxLength`, `maxlength` and `max_length` all land on the same field.
  for i, f in desc.fields:
    if cmpIgnoreStyle(f.name, name) == 0:
      return i
  -1

proc findAction(desc: ScriptDescriptor, wanted: string): int =
  for i, a in desc.actions:
    if wanted in a.aliases:
      return i
  -1

proc doRead(widget: Widget): JsonNode =
  ok("value", widget.getScriptableState())

proc doGetText(widget: Widget, desc: ScriptDescriptor): JsonNode =
  if desc.getText == nil:
    return fail("Widget has no text field")
  if widget.blockReading:
    return fail("Reading blocked")
  ok("text", %desc.getText(widget))

proc writtenValue(params: JsonNode): JsonNode =
  ## `text` is accepted in place of `value`, so `settext foo` reads naturally.
  if params.hasKey("value"): params["value"]
  elif params.hasKey("text"): params["text"]
  else: newJNull()

proc writtenField(desc: ScriptDescriptor, params: JsonNode): string =
  ## The field a write names, or the widget's default when it names none.
  if params.hasKey("field"): params["field"].getStr()
  else: desc.defaultField

proc doWrite(widget: Widget, desc: ScriptDescriptor, params: JsonNode): JsonNode =
  let value = writtenValue(params)
  if value.kind == JNull:
    return fail("Missing 'value' parameter")

  let name = desc.writtenField(params)
  if name.len == 0:
    return fail("Widget has no writable field")

  let idx = desc.findField(name)
  if idx < 0:
    return fail("Unknown writable field: " & name)

  if not desc.fields[idx].assign(widget, value):
    return fail("Bad value for " & name)

  # A written field almost always changes what is drawn and how big it is, and
  # a script has no other way to say so.
  widget.isDirty = true
  widget.layoutDirty = true
  ok()

proc doToggle(widget: Widget, desc: ScriptDescriptor): Option[JsonNode] =
  ## Flip first, then notify -- so a handler reading the state sees the new
  ## value rather than the one it is replacing.
  ##
  ## `none` means this widget has nothing to flip, and the caller should treat
  ## the word as an ordinary action name instead. That matters for `click`,
  ## which is both a toggle alias and Button's alias for `onClick`.
  if desc.toggle == nil:
    return none(JsonNode)
  let now = desc.toggle(widget)
  if now.isNone:
    return none(JsonNode)
  widget.isDirty = true
  some(ok("checked", %now.get()))

proc doInvoke(widget: Widget, desc: ScriptDescriptor, wanted: string): JsonNode =
  let idx = desc.findAction(wanted)
  if idx < 0:
    return fail("Unknown or unsupported action for this widget: " & wanted)
  if not widget.enabled:
    return fail("Widget is disabled")
  let fired = desc.actions[idx].invoke(widget)
  widget.isDirty = true
  result = ok("invoked", %wanted)
  if not fired:
    # The action exists, nothing is listening. Reporting that as a failure would
    # make a script that only wanted to poke the widget look broken.
    result["note"] = %"no handler attached"

proc dispatchVerb(widget: Widget, desc: ScriptDescriptor,
                  params: JsonNode, act: string): Option[JsonNode] =
  ## The fixed vocabulary, the part that is the same for every widget.
  ## `none` when the command is naming an action instead.
  if act in ReadVerbs: return some(doRead(widget))
  if act == "gettext": return some(doGetText(widget, desc))
  if act in WriteVerbs: return some(doWrite(widget, desc, params))
  none(JsonNode)

proc requestedAction(act: string, params: JsonNode): string =
  ## Which action a command is asking for. `invoke` carries the name in its
  ## params; every other verb is the name.
  if act != "invoke":
    return act
  if params.hasKey("action"):
    params["action"].getStr().toLowerAscii()
  else:
    ""

proc dispatchScriptAction*(widget: Widget, desc: ScriptDescriptor,
                           action: string, params: JsonNode): JsonNode =
  ## Answer one scripted command against one widget.
  ##
  ## Verb order matters in one place only: toggle/click is tried before the
  ## general action lookup, so `click` on a checkable widget flips the state
  ## before notifying rather than firing a handler against the old value.
  let act = action.toLowerAscii()

  let verb = dispatchVerb(widget, desc, params, act)
  if verb.isSome:
    return verb.get()

  # `invoke` names its action in the params; anything else names it directly.
  let wanted = requestedAction(act, params)
  if wanted.len == 0:
    return fail("Missing 'action' parameter")

  if wanted in ToggleVerbs:
    let flipped = doToggle(widget, desc)
    if flipped.isSome:
      return flipped.get()

  doInvoke(widget, desc, wanted)
