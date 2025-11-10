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
    valueInternal: initialValue,
    dependentWidgets: initHashSet[Widget](),
    onChange: nil
  )

# ============================================================================
# Value Access
# ============================================================================

proc value*[T](link: Link[T]): T =
  ## Get the current value of the link
  link.valueInternal

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

  if link.valueInternal != newVal:
    let oldVal = link.valueInternal
    link.valueInternal = newVal

    # Mark all dependent widgets dirty
    # They will read the new value on next render pass
    for widget in link.dependentWidgets:
      widget.isDirty = true
      widget.layoutDirty = true  # Content change may affect size

      # Propagate layoutDirty to parent container
      if widget.parent != nil:
        widget.parent.layoutDirty = true

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
  "Link[" & $T & "](" & $link.value & ", " & $link.dependentCount & " deps)"

# ============================================================================
# Convenience Methods (Aliases for .value)
# ============================================================================

proc get*[T](link: Link[T]): T =
  ## Convenience method - same as .value
  ## Read the current value of the link
  link.value

proc set*[T](link: Link[T], val: T) =
  ## Convenience method - same as .value = val
  ## Set a new value and mark dependent widgets dirty
  link.value = val
