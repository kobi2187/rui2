## Input Widgets - Aggregator Module
##
## Text entry and other editable controls.
##
## TextInput and TextArea are the same editing model -- TextBuffer for the
## caret and selection, text_content for measuring and drawing -- differing in
## whether Enter submits or inserts a newline, and whether Up and Down move by
## line or fall through to focus navigation.

import input/text_buffer
export text_buffer
import input/textinput
export textinput
import input/textarea
export textarea
