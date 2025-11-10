# Available constraint expressions
proc width*(widget: Widget): Expression
proc height*(widget: Widget): Expression
proc left*(widget: Widget): Expression
proc right*(widget: Widget): Expression
proc top*(widget: Widget): Expression
proc bottom*(widget: Widget): Expression
proc centerX*(widget: Widget): Expression
proc centerY*(widget: Widget): Expression

# Constraint operators
proc `==`*(a, b: Expression): Constraint
proc `>=`*(a, b: Expression): Constraint  
proc `<=`*(a, b: Expression): Constraint
proc `+`*(a: Expression, b: float32): Expression
proc `-`*(a: Expression, b: float32): Expression
proc `*`*(a: Expression, b: float32): Expression
proc `/`*(a: Expression, b: float32): Expression

# Size specifiers
proc fill*(): SizeSpec
proc fixed*(value: float32): SizeSpec
proc percent*(value: float32): SizeSpec
proc ratio*(value: float32): SizeSpec

# Margin/padding
type EdgeInsets* = object
  left*, top*, right*, bottom*: float32

proc EdgeInsets*(
  left, top, right, bottom: float32
): EdgeInsets

proc EdgeInsets*(
  horizontal, vertical: float32
): EdgeInsets

proc EdgeInsets*(
  all: float32
): EdgeInsets