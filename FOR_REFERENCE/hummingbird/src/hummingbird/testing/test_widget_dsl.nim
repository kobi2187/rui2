# test/macro/test_widget_dsl.nim
import unittest, macros
import quickui

suite "Widget DSL Tests":
  test "Widget definition matches manual implementation":
    # Test DSL version
    defineWidget TestButton:
      props:
        text: string
        onClick: proc()
      
      render:
        button(text = widget.text):
          onClick = widget.onClick

    # Manual version
    type TestButtonManual = ref object of Widget
      text: string
      onClick: proc()

    proc renderManual(widget: TestButtonManual) =
      button(text = widget.text):
        onClick = widget.onClick

    # Compare ASTs
    check sameStructure(
      getAst(TestButton),
      getAst(TestButtonManual)
    )


