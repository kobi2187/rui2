## Reactive Link[T] system for RUI
##
## Links provide automatic UI updates when data changes.
## Uses direct widget references for O(1) dirty marking.

import types

# ============================================================================
# Link[T] Creation
# ============================================================================

proc newLink*[T](initialValue: T): Link[T] =
  ## Create a new Link with an initial value
  result = Link[T](
    val: initialValue,
    dependentWidgets: initHashSet[Widget](),
    onChange: nil
  )

# ============================================================================
# Value Access
# ============================================================================

proc value*[T](link: Link[T]): T =
  ## Get the current value of the link
  link.val

# ----------------------------------------------------------------------------
# Transactions
#
# `transaction: a.set(1); b.set(2)` stores every value immediately -- reads
# inside the block see them -- but announces each changed link once, at the
# end: its dependents are marked, its onChange and observers run a single
# time, and derived links recompute from the final values. Without it, each
# set announced itself.
# ----------------------------------------------------------------------------

var
  transactionDepth = 0
  pendingAnnouncements: seq[proc() {.closure.}]

proc announce[T](link: Link[T], oldVal: T) =
  ## Tell the world `link` changed from `oldVal` to its current value.
  ##
  ## IMMEDIATE MODE: widgets read the value every frame when rendering, so
  ## announcing is just marking dependents dirty -- O(n) in the widgets bound
  ## to THIS link, not in the whole tree -- and running the callbacks.
  for widget in link.dependentWidgets:
    widget.layoutDirty = true  # Content change may affect size

    # Propagate layoutDirty to parent container (relayout may be needed)
    if widget.parent != nil:
      widget.parent.layoutDirty = true

    # Mark the leaf->root render line dirty so the rebuilt texture composites
    # all the way to the screen; unaffected sibling subtrees keep their caches.
    widget.markDirtyToRoot()

  if link.onChange != nil:
    link.onChange(oldVal, link.val)
  for observe in link.observers:
    observe()

proc `value=`*[T](link: Link[T], newVal: T) =
  ## Set a new value and mark dependent widgets dirty (see `announce`).
  ## Inside a `transaction` the announcement waits for the block's end.
  if link.val == newVal:
    return
  if transactionDepth == 0:
    let oldVal = link.val
    link.val = newVal
    announce(link, oldVal)
    return

  if not link.held:
    link.held = true
    link.heldFrom = link.val
    pendingAnnouncements.add proc() =
      link.held = false
      # Set back to where it started: nothing changed, so nothing to announce.
      if link.val != link.heldFrom:
        announce(link, link.heldFrom)
  link.val = newVal

proc beginTransaction*() =
  inc transactionDepth

proc endTransaction*() =
  ## Close one level; the outermost close announces everything at once.
  dec transactionDepth
  if transactionDepth == 0:
    let pending = pendingAnnouncements
    pendingAnnouncements = @[]
    for announceIt in pending:
      announceIt()

template transaction*(body: untyped) =
  ## Batch sets: every link set inside is announced once, afterwards, however
  ## often it was set. Nests; only the outermost block announces.
  ##
  ##   transaction:
  ##     first.set("Ada")
  ##     last.set("Lovelace")        # one repaint, one onChange each
  beginTransaction()
  try:
    body
  finally:
    endTransaction()

# ============================================================================
# Widget Binding
# ============================================================================

proc addDependent*[T](link: Link[T], widget: Widget) =
  ## Register a widget as dependent on this link
  ##
  ## When the link's value changes, the widget will be marked dirty.
  ##
  ## This is called automatically by the DSL:
  ##   Label: text: bind <- store.counter
  ##
  ## Or manually:
  ##   store.counter.addDependent(myLabel)
  link.dependentWidgets.incl(widget)

proc removeDependent*[T](link: Link[T], widget: Widget) =
  ## Unregister a widget from this link
  ##
  ## Called when widget is destroyed or binding changes
  link.dependentWidgets.excl(widget)

proc hasDependent*[T](link: Link[T], widget: Widget): bool =
  ## Check if a widget is dependent on this link
  widget in link.dependentWidgets

proc dependentCount*[T](link: Link[T]): int =
  ## Get the number of widgets depending on this link
  link.dependentWidgets.len

# ============================================================================
# Utility Functions
# ============================================================================

proc setOnChange*[T](link: Link[T], callback: proc(oldVal, newVal: T)) =
  ## Set a callback to be called when the value changes
  ##
  ## Useful for logging, validation, or side effects:
  ##   counter.setOnChange proc(old, new: int) =
  ##     echo "Counter: ", old, " → ", new
  link.onChange = callback

proc clearOnChange*[T](link: Link[T]) =
  ## Remove the onChange callback
  link.onChange = nil

# ============================================================================
# Debug Helpers
# ============================================================================

proc `$`*[T](link: Link[T]): string =
  ## String representation for debugging
  "Link[" & $T & "](" & $link.val & ", " & $link.dependentCount & " deps)"

# ============================================================================
# Convenience Methods (Aliases for .value)
# ============================================================================

proc get*[T](link: Link[T]): T =
  ## Convenience method - same as .value
  ## Read the current value of the link
  link.val

proc set*[T](link: Link[T], newVal: T) =
  ## Convenience method - same as .value = newVal
  ## Set a new value and mark dependent widgets dirty
  link.value = newVal

# ============================================================================
# Binding
#
# `Link.set` marks its dependent widgets dirty, but a widget holds plain props
# (a Label holds a `string`, not a `Link[string]`), so being dirty alone never
# changed what it displayed. `bindTo` closes that: it registers the dependency
# *and* installs a refresh hook that copies the current value into the widget
# before each layout. One registration, and the value flows.
# ============================================================================

proc bindTo*[T](link: Link[T], widget: Widget,
                apply: proc(value: T) {.closure.}) =
  ## One-way binding: whenever `link` changes, `apply` runs with the new value
  ## and the widget is re-laid-out and repainted.
  ##
  ##   store.count.bindTo(label, proc(v: int) = label.text = "Count: " & $v)
  ##
  ## `apply` also runs once immediately, so the widget starts in sync.
  link.addDependent(widget)

  let existing = widget.onRefresh
  widget.onRefresh = proc() =
    # Chain, so several links can drive one widget.
    if existing != nil:
      existing()
    apply(link.value)

  # Seed the initial value.
  apply(link.value)
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc unbind*[T](link: Link[T], widget: Widget) =
  ## Stop tracking this widget. The refresh hook is left in place: it is a
  ## closure chain and may serve other links.
  link.removeDependent(widget)


# ============================================================================
# Derived links
# ============================================================================

proc derive*[A, T](a: Link[A], compute: proc(x: A): T): Link[T] =
  ## A link computed from another, kept current as it changes. It is an
  ## ordinary `Link[T]`: bind widgets to it, read it, derive from it again.
  ## Only its own dependents are dirtied, and only when its value actually
  ## changes -- a source change that leaves the result equal costs nothing.
  ##
  ##   let label = derive(first, proc(s: string): string = "Hello, " & s)
  ##
  ## Setting a derived link by hand is allowed but will be overwritten by the
  ## next source change.
  let target = newLink(compute(a.val))
  a.observers.add proc() = target.value = compute(a.val)
  target

proc derive*[A, B, T](a: Link[A], b: Link[B],
                      compute: proc(x: A, y: B): T): Link[T] =
  ## Derived from two links: `derive(a, b, proc(x, y): int = x + y)`.
  let target = newLink(compute(a.val, b.val))
  let refresh = proc() = target.value = compute(a.val, b.val)
  a.observers.add refresh
  b.observers.add refresh
  target

proc derive*[A, B, C, T](a: Link[A], b: Link[B], c: Link[C],
                         compute: proc(x: A, y: B, z: C): T): Link[T] =
  ## Derived from three links.
  let target = newLink(compute(a.val, b.val, c.val))
  let refresh = proc() = target.value = compute(a.val, b.val, c.val)
  a.observers.add refresh
  b.observers.add refresh
  c.observers.add refresh
  target
