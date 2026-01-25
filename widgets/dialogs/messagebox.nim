## MessageBox Widget - RUI2
##
## A modal dialog for displaying messages and getting user confirmation.
## Supports different types: Info, Warning, Error, Question.
## Uses defineWidget with built-in buttons.

import ../../core/widget_dsl
import std/options

when defined(useGraphics):
  import raylib

type
  MessageBoxType* = enum
    mbInfo
    mbWarning
    mbError
    mbQuestion

  MessageBoxButtons* = enum
    mbOK                # Just OK button
    mbOKCancel          # OK and Cancel
    mbYesNo             # Yes and No
    mbYesNoCancel       # Yes, No, and Cancel

  MessageBoxResult* = enum
    mrNone = 0
    mrOK = 1
    mrCancel = 2
    mrYes = 3
    mrNo = 4

defineWidget(MessageBox):
  props:
    title: string = "Message"
    message: string = ""
    messageType: MessageBoxType = mbInfo
    buttons: MessageBoxButtons = mbOK
    width: float = 400.0
    height: float = 200.0

  state:
    isVisible: bool
    result: MessageBoxResult

  actions:
    onClose(result: MessageBoxResult)

  layout:
    # Center the dialog on screen (would need screen size)
    # For now, use fixed position
    widget.bounds.width = widget.width
    widget.bounds.height = widget.height

    # TODO: Layout internal buttons

  events:
    on_key_down:
      # ESC closes the dialog
      when defined(useGraphics):
        # Would check for ESC key
        if widget.isVisible:
          widget.isVisible = false
          widget.result = mrCancel
          if widget.onClose.isSome:
            widget.onClose.get()(mrCancel)
          return true
      return false

  render:
    when defined(useGraphics):
      if widget.isVisible:
        # Draw semi-transparent overlay
        DrawRectangle(
          0, 0,
          GetScreenWidth(),
          GetScreenHeight(),
          Color(r: 0, g: 0, b: 0, a: 128)
        )

        # Draw dialog background
        DrawRectangleRec(widget.bounds, Color(r: 250, g: 250, b: 250, a: 255))

        # Draw border
        DrawRectangleLinesEx(widget.bounds, 2.0, Color(r: 100, g: 100, b: 100, a: 255))

        # Draw title bar
        DrawRectangle(
          widget.bounds.x.cint,
          widget.bounds.y.cint,
          widget.bounds.width.cint,
          30,
          Color(r: 60, g: 120, b: 180, a: 255)
        )

        DrawText(
          widget.title.cstring,
          (widget.bounds.x + 10).cint,
          (widget.bounds.y + 8).cint,
          14,
          Color(r: 255, g: 255, b: 255, a: 255)
        )

        # Draw icon based on type
        let iconY = widget.bounds.y + 50
        let iconText = case widget.messageType:
                       of mbInfo: "ℹ"
                       of mbWarning: "⚠"
                       of mbError: "✖"
                       of mbQuestion: "?"

        DrawText(
          iconText.cstring,
          (widget.bounds.x + 20).cint,
          iconY.cint,
          32,
          Color(r: 60, g: 120, b: 180, a: 255)
        )

        # Draw message text
        # TODO: Word wrap for long messages
        DrawText(
          widget.message.cstring,
          (widget.bounds.x + 70).cint,
          (iconY + 8).cint,
          14,
          Color(r: 60, g: 60, b: 60, a: 255)
        )

        # Draw buttons at bottom
        let buttonY = widget.bounds.y + widget.bounds.height - 50
        var buttonX = widget.bounds.x + widget.bounds.width - 110

        case widget.buttons:
        of mbOK:
          if GuiButton(
            Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
            "OK".cstring
          ):
            widget.isVisible = false
            widget.result = mrOK
            if widget.onClose.isSome:
              widget.onClose.get()(mrOK)

        of mbOKCancel:
          if GuiButton(
            Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
            "OK".cstring
          ):
            widget.isVisible = false
            widget.result = mrOK
            if widget.onClose.isSome:
              widget.onClose.get()(mrOK)

          buttonX -= 90
          if GuiButton(
            Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
            "Cancel".cstring
          ):
            widget.isVisible = false
            widget.result = mrCancel
            if widget.onClose.isSome:
              widget.onClose.get()(mrCancel)

        of mbYesNo:
          if GuiButton(
            Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
            "No".cstring
          ):
            widget.isVisible = false
            widget.result = mrNo
            if widget.onClose.isSome:
              widget.onClose.get()(mrNo)

          buttonX -= 90
          if GuiButton(
            Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
            "Yes".cstring
          ):
            widget.isVisible = false
            widget.result = mrYes
            if widget.onClose.isSome:
              widget.onClose.get()(mrYes)

        of mbYesNoCancel:
          # TODO: Three buttons
          discard
    else:
      # Non-graphics mode
      if widget.isVisible:
        echo "╔═══ ", widget.title, " ", "═".repeat(max(0, 30 - widget.title.len)), "═╗"
        echo "║ ", widget.message
        echo "╚", "═".repeat(35), "╝"
