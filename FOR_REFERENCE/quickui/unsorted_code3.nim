# constraints.nim
import kiwi

type
  LayoutSolver* = ref object
    solver: Solver
    vars: Table[string, Variable]

  Widget* = ref object
    # Add to existing Widget type
    layoutSolver*: LayoutSolver

proc solve*(layout: LayoutSolver) =
  layout.solver.updateVariables()
  # Update widget geometries from solved constraints