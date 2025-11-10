

# Calendar widget
defineWidget Calendar:
  props:
    selectedDate: DateTime
    highlightedDates: HashSet[DateTime]
    onDateSelect: proc(date: DateTime)

  render:
    # Draw month/year navigation
    let headerRect = Rectangle(
      x: widget.rect.x,
      y: widget.rect.y,
      width: widget.rect.width,
      height: 24
    )

    if GuiButton(headerRect.left(20), "<"):
      widget.selectedDate = widget.selectedDate - 1.months

    GuiLabel(headerRect, widget.selectedDate.format("MMMM yyyy"))

    if GuiButton(headerRect.right(20), ">"):
      widget.selectedDate = widget.selectedDate + 1.months

    # Draw weekday headers
    for i, day in ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]:
      GuiLabel(getDayRect(i), day)

    # Draw days
    let monthDays = getDaysInMonth(widget.selectedDate)
    for day in monthDays:
      let dayRect = getDayRect(day)
      let isHighlighted = day in widget.highlightedDates

      if GuiButton(dayRect, $day.dayOfMonth, isHighlighted):
        if widget.onDateSelect != nil:
          widget.onDateSelect(day)