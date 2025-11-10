## Layout & Constraint System

### Basic Layout Definition

# Core layout concepts
type 
 Layout* = object
   case kind*: LayoutKind
   of lkConstraints:
     constraints*: seq[Constraint]
   of lkFlex:
     direction*: FlexDirection
     spacing*: float32
   of lkGrid:
     columns*: int
     spacing*: float32

 Constraint* = object
   expr*: Expression  # Kiwi solver expression
   strength*: ConstraintStrength

 ConstraintStrength* = enum
   csWeak = 1
   csMedium = 1000
   csStrong = 1000000
   csRequired = float.high.int

# Layout DSL example
layout:
 panel:
   # Basic constraints
   width = 800
   height = 600
   center in parent
   
   # Child layouts
   hstack:
     spacing = 16
     padding = EdgeInsets(all: 16)
     
     # Sidebar
     panel:
       width = 200
       height = fill
       
     # Content
     panel:
       width = fill
       height = fill