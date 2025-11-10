
# Date/Time picker
defineWidget DateTimePicker:
  props:
    value*: DateTime
    showTime*: bool
    minDate*: Option[DateTime]
    maxDate*: Option[DateTime]
    onChange*: proc(dt: DateTime)

  render:
    var year = widget.value.year
    var month = widget.value.month.int
    var day = widget.value.monthDay

    # Calendar header
    GuiLabel(widget.getHeaderRect(), $widget.value.month & " " & $year)

    # Calendar grid
    let firstDay = dateTime(year, month.Month, 1)
    let startOffset = firstDay.weekDay.int

    for i in 0..<42: # 6 weeks * 7 days
      let cellDay = i - startOffset + 1
      if cellDay > 0 and cellDay <= getDaysInMonth(month.Month, year):
        let cellRect = widget.getDayRect(i div 7, i mod 7)
        if GuiButton(cellRect, $cellDay):
          widget.value = dateTime(year, month.Month, cellDay)
          if widget.onChange != nil:
            widget.onChange(widget.value)

    # Time picker if enabled
    if widget.showTime:
      var hour = widget.value.hour
      var minute = widget.value.minute

      if GuiSpinner(widget.getHourRect(), "", addr hour, 0, 23, true):
        widget.value = widget.value.withHour(hour)
        if widget.onChange != nil:
          widget.onChange(widget.value)

      if GuiSpinner(widget.getMinuteRect(), "", addr minute, 0, 59, true):
        widget.value = widget.value.withMinute(minute)
        if widget.onChange != nil:
          widget.onChange(widget.value)