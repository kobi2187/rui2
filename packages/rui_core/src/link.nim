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
    dependentWidgets: initHashSet[Widget]()
  )

# ============================================================================
# Value Access
# ============================================================================

proc value*[T](link: Link[T]): T =
  ## Get the current value of the link
  link.val

proc `value=`*[T](link: Link[T], newVal: T) =
  ## Set a new value and mark every widget that depends on this link dirty.
  ##
  ## IMMEDIATE MODE: widgets read the value every frame when rendering, so a
  ## change needs no callback, only the dependents marked: O(n) in the widgets
  ## bound to THIS link, not in the whole tree. Marking is idempotent, so any
  ## number of sets in one frame cost one repaint.
  if link.val == newVal:
    return
  link.val = newVal
  for widget in link.dependentWidgets:
    widget.layoutDirty = true  # Content change may affect size

    # Propagate layoutDirty to parent container (relayout may be needed)
    if widget.parent != nil:
      widget.parent.layoutDirty = true

    # Mark the leaf->root render line dirty so the rebuilt texture composites
    # all the way to the screen; unaffected sibling subtrees keep their caches.
    widget.markDirtyToRoot()

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
# Debug Helpers
# ============================================================================

proc `$`*[T](link: Link[T]): string =
  ## String representation for debugging
  "Link[" & $T & "](" & $link.val & ", " & $link.dependentCount & " deps)"

# ============================================================================
# Convenience Methods (Aliases for .value)
# ============================================================================

proc setter*[T](link: Link[T]): proc (v: T) {.closure.} =
  ## A handler that writes its argument into the Link: the explicit way to get a
  ## widget's value back into state. Bindings are one-way (state -> widget, `->`);
  ## to write back, hang this on the widget's change action:
  ## `TextInput(text = name.value, onChange = name.setter)`.
  result = proc (v: T) = link.value = v

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

proc dependsOn*[T](widget: Widget, link: Link[T]) =
  ## The widget shows something that comes from `link`: when the link is set it is
  ## marked dirty. (`ui:` calls this for every `link.value` a property reads.)
  link.dependentWidgets.incl(widget)
  widget.disposers.add proc() = link.dependentWidgets.excl(widget)

proc refreshWith*(widget: Widget, apply: proc() {.closure.}) =
  ## Run `apply` before each layout of the widget (and chain with any earlier one):
  ## it re-reads the Links and assigns the widget's property.
  let earlier = widget.onRefresh
  widget.onRefresh = proc() =
    if earlier != nil: earlier()
    apply()
  widget.layoutDirty = true

proc bindTo*[T](link: Link[T], widget: Widget,
                apply: proc(value: T) {.closure.}) =
  ## One-way binding: whenever `link` changes, `apply` runs with the new value
  ## and the widget is re-laid-out and repainted.
  ##
  ##   store.count.bindTo(label, proc(v: int) = label.text = "Count: " & $v)
  ##
  ## `apply` also runs once immediately, so the widget starts in sync.
  link.addDependent(widget)
  widget.disposers.add proc() = link.removeDependent(widget)

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
