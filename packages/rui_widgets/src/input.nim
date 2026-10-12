## Input Widgets - Aggregator Module
##
## Text entry and other editable controls.
##
## One text widget, TextArea, whose properties limit it into the three roles:
## Label (`editable = false`), TextInput (`multiline = false`) and TextArea.
## TextBuffer holds the caret and selection; text_content measures and draws.

import input/text_buffer
export text_buffer
import input/textarea
export textarea

import input/picker_values
export picker_values
import input/popup_field
import input/autocomplete
export autocomplete
import input/timepicker
export timepicker
import input/datepicker
export datepicker
import input/colorpicker
export colorpicker
