## ListBox Widget - RUI2
##
## A list box widget for single or multi-select from a list of items.
## Features:
## - Virtual rendering: only renders visible items (handles millions of items)
## - Lazy loading: callback to fetch data on demand
## - Multi-selection support
## - Mouse wheel scrolling
## - Keyboard navigation

import ../../core/widget_dsl
import ../../drawing_primitives/drawing_effects
import std/[options, strutils, sets]

when defined(useGraphics):
  import raylib

definePrimitive(ListBox):
  props:
    items: seq[string] = @[]
    totalItemCount: int = -1     # -1 means use items.len, otherwise for lazy loading
    itemHeight: float = 20.0
    multiSelect: bool = false
    disabled: bool = false
    backgroundColor: Color = Color(r: 255, g: 255, b: 255, a: 255)
    selectedColor: Color = Color(r: 100, g: 150, b: 255, a: 150)
    hoverColor: Color = Color(r: 230, g: 240, b: 255, a: 255)
    textColor: Color = Color(r: 40, g: 40, b: 40, a: 255)

  state:
    selection: HashSet[int]      # Set of selected indices
    scrollY: float                # Vertical scroll offset (pixels)
    visibleStart: int             # First visible item index
    visibleEnd: int               # Last visible item index
    focusIndex: int               # Currently focused item
    hoverIndex: int               # Currently hovered item (-1 if none)

  actions:
    onSelect(selection: HashSet[int])
    onItemActivate(index: int)                   # Double-click or Enter
    onLoadMore(startIndex: int, count: int)      # Lazy loading callback
    onScrollNearEnd()                            # Triggered when scrolling near bottom

  events:
    on_mouse_wheel:
      if not widget.disabled:
        # Scroll with mouse wheel
        let itemH = widget.itemHeight
        let delta = event.wheelDelta
        let newScroll = widget.scrollY - (delta * itemH * 3.0)

        # Calculate max scroll
        let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len
        let totalHeight = totalItems.float * itemH
        let maxScroll = max(0.0, totalHeight - widget.bounds.height)

        widget.scrollY = clamp(newScroll, 0.0, maxScroll)

        # Check if near end (trigger lazy loading)
        let scrollRatio = if maxScroll > 0: widget.scrollY / maxScroll else: 0.0
        if scrollRatio > 0.8:  # Within 20% of bottom
          if widget.onScrollNearEnd.isSome:
            widget.onScrollNearEnd.get()()

        return true
      return false

  render:
    when defined(useGraphics):
      let itemH = widget.itemHeight
      let scroll = widget.scrollY

      # Determine total item count
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len
      let totalHeight = totalItems.float * itemH
      let viewHeight = widget.bounds.height
      let maxScroll = max(0.0, totalHeight - viewHeight)

      # Virtual rendering: calculate visible item range
      let bufferItems = 5  # Render extra items above/below viewport
      let visStart = max(0, int(scroll / itemH) - bufferItems)
      let visEnd = min(totalItems - 1, int((scroll + viewHeight) / itemH) + bufferItems)

      widget.visibleStart = visStart
      widget.visibleEnd = visEnd

      # Check if we need to load more data (lazy loading)
      if widget.onLoadMore.isSome and visEnd >= widget.items.len - 10:
        # We're near the end of loaded items, request more
        let needCount = min(100, totalItems - widget.items.len)
        if needCount > 0:
          widget.onLoadMore.get()(widget.items.len, needCount)

      # Draw background
      DrawRectangleRec(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.backgroundColor
      )

      # Begin scissor mode for clipping
      beginScissorMode(Rect(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: widget.bounds.width,
        height: widget.bounds.height
      ))

      # Get mouse state
      let mousePos = getMousePosition()
      let mouseInBounds = CheckCollisionPointRec(
        mousePos,
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        )
      )
      var newHovered = -1

      # Draw visible items
      for itemIdx in visStart..visEnd:
        if itemIdx >= totalItems:
          break

        let itemY = widget.bounds.y + (itemIdx.float * itemH) - scroll

        # Skip if completely outside bounds
        if itemY + itemH < widget.bounds.y or itemY > widget.bounds.y + widget.bounds.height:
          continue

        let itemRect = Rectangle(
          x: widget.bounds.x,
          y: itemY,
          width: widget.bounds.width,
          height: itemH
        )

        # Check hover
        if mouseInBounds and CheckCollisionPointRec(mousePos, itemRect):
          newHovered = itemIdx

        # Draw item background
        let isSelected = itemIdx in widget.selection
        let isHovered = itemIdx == widget.hoverIndex
        let isFocused = itemIdx == widget.focusIndex

        if isSelected:
          DrawRectangleRec(itemRect, widget.selectedColor)
        elif isHovered:
          DrawRectangleRec(itemRect, widget.hoverColor)

        # Draw focus indicator
        if isFocused and not isSelected:
          DrawRectangleLinesEx(
            itemRect,
            1.0,
            Color(r: 100, g: 150, b: 255, a: 255)
          )

        # Draw item text (if loaded)
        if itemIdx < widget.items.len:
          let text = widget.items[itemIdx]
          DrawText(
            text.cstring,
            (widget.bounds.x + 6.0).cint,
            (itemY + 2.0).cint,
            12,
            widget.textColor
          )
        else:
          # Item not loaded yet - show loading indicator
          DrawText(
            "Loading...".cstring,
            (widget.bounds.x + 6.0).cint,
            (itemY + 2.0).cint,
            12,
            Color(r: 150, g: 150, b: 150, a: 255)
          )

        # Handle item click
        if not widget.disabled and mouseInBounds and isMouseButtonPressed(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, itemRect):
            let ctrlDown = isKeyDown(KEY_LEFT_CONTROL) or isKeyDown(KEY_RIGHT_CONTROL)

            var newSelection = widget.selection

            if widget.multiSelect and ctrlDown:
              # Toggle selection
              if itemIdx in newSelection:
                newSelection.excl(itemIdx)
              else:
                newSelection.incl(itemIdx)
            else:
              # Single selection
              newSelection = [itemIdx].toHashSet

            widget.selection = newSelection
            widget.focusIndex = itemIdx

            if widget.onSelect.isSome:
              widget.onSelect.get()(newSelection)

      widget.hoverIndex = newHovered

      endScissorMode()

      # Draw scrollbar if needed
      if totalHeight > viewHeight:
        let scrollbarW = 12.0
        let scrollbarRect = Rectangle(
          x: widget.bounds.x + widget.bounds.width - scrollbarW,
          y: widget.bounds.y,
          width: scrollbarW,
          height: viewHeight
        )

        # Scrollbar track
        DrawRectangleRec(scrollbarRect, Color(r: 230, g: 230, b: 230, a: 255))

        # Scrollbar thumb
        let thumbHeight = max(20.0, viewHeight * (viewHeight / totalHeight))
        let thumbY = scrollbarRect.y + (scroll / maxScroll) * (viewHeight - thumbHeight)

        let thumbRect = Rectangle(
          x: scrollbarRect.x + 2.0,
          y: thumbY,
          width: scrollbarW - 4.0,
          height: thumbHeight
        )

        DrawRectangleRec(thumbRect, Color(r: 150, g: 150, b: 150, a: 255))

        # Handle scrollbar dragging
        if mouseInBounds and isMouseButtonDown(MOUSE_LEFT_BUTTON):
          if CheckCollisionPointRec(mousePos, scrollbarRect):
            let newScroll = ((mousePos.y - scrollbarRect.y) / viewHeight) * maxScroll
            widget.scrollY = clamp(newScroll, 0.0, maxScroll)

      # Draw border
      DrawRectangleLinesEx(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        1.0,
        Color(r: 180, g: 180, b: 180, a: 255)
      )
    else:
      # Non-graphics mode: just echo visible items
      echo "ListBox (Virtual):"
      let totalItems = if widget.totalItemCount >= 0: widget.totalItemCount else: widget.items.len
      echo "  Total items: ", totalItems
      echo "  Loaded items: ", widget.items.len
      echo "  Visible range: ", widget.visibleStart, " to ", widget.visibleEnd

      let selection = widget.selection
      for itemIdx in widget.visibleStart..min(widget.visibleEnd, widget.items.len - 1):
        let marker = if itemIdx in selection: "[X]" else: "[ ]"
        echo "  ", marker, " [", itemIdx, "] ", widget.items[itemIdx]
