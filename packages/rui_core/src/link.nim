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

proc `value=`*[T](link: Link[T], newVal: T) =
  ## Set a new value and mark dependent widgets dirty
  ##
  ## IMMEDIATE MODE: Widgets read the value every frame when rendering.
  ## We just mark them dirty so they know to re-render.
  ##
  ## When a value changes:
  ## 1. Store new value
  ## 2. Mark all dependent widgets dirty (O(1) per widget, direct refs!)
  ## 3. Widgets will read the new value on next render pass
  ## 4. Call onChange callback if set (optional, for logging/side effects)
  ##
  ## Performance: O(n) where n = number of widgets bound to THIS link
  ##              NOT O(total widgets in tree)!

  if link.val != newVal:
    let oldVal = link.val
    link.val = newVal

    # Mark all dependent widgets dirty. They read the new value on next render.
    for widget in link.dependentWidgets:
      widget.layoutDirty = true  # Content change may affect size

      # Propagate layoutDirty to parent container (relayout may be needed)
      if widget.parent != nil:
        widget.parent.layoutDirty = true

      # Mark the leaf->root render line dirty so the rebuilt texture composites
      # all the way to the screen; unaffected sibling subtrees keep their caches.
      widget.markDirtyToRoot()

      # Note: tree.anyDirty will be set in the main loop
      # when checking for layout updates

    # Call onChange callback (optional, for side effects)
    if link.onChange != nil:
      link.onChange(oldVal, newVal)

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
  widget.onRefresh = some(proc() {.closure.} =
    # Chain, so several links can drive one widget.
    if existing.isSome:
      existing.get()()
    apply(link.value)
  )

  # Seed the initial value.
  apply(link.value)
  widget.layoutDirty = true
  widget.markDirtyToRoot()

proc unbind*[T](link: Link[T], widget: Widget) =
  ## Stop tracking this widget. The refresh hook is left in place: it is a
  ## closure chain and may serve other links.
  link.removeDependent(widget)
