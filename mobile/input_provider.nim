## Mobile Input Provider Interface
##
## Abstract interface for mobile input providers.
## Implementations provide platform-specific touch event polling.

import types

# ============================================================================
# Input Provider Interface
# ============================================================================

type
  InputProvider* = ref object of RootObj
    ## Base type for mobile input providers
    gestureManager*: GestureManager

# ============================================================================
# Methods (to be overridden)
# ============================================================================

method update*(provider: InputProvider) {.base.} =
  ## Update input - call this every frame
  ## Override in derived types
  discard

method reset*(provider: InputProvider) {.base.} =
  ## Reset provider state
  ## Override in derived types
  discard

method getActiveTouchCount*(provider: InputProvider): int {.base.} =
  ## Get number of active touches
  ## Override in derived types
  result = 0

# ============================================================================
# Platform-Specific Providers
# ============================================================================

# Export platform-specific implementations
import platform/raylib_input
export raylib_input

# Re-export main type
export RaylibInputProvider, newRaylibInputProvider

# ============================================================================
# Helper: Create Platform Input Provider
# ============================================================================

proc createInputProvider*(gestureManager: GestureManager,
                         mouseSimulation: bool = true): RaylibInputProvider =
  ## Create appropriate input provider for current platform
  ##
  ## Currently always returns RaylibInputProvider.
  ## In the future, could detect platform and return iOS/Android specific providers.
  ##
  ## mouseSimulation: Enable mouse-as-touch for desktop testing
  newRaylibInputProvider(gestureManager, mouseSimulation)

# ============================================================================
# Usage Examples
# ============================================================================

when isMainModule:
  echo "Mobile Input Provider Interface"
  echo "================================"
  echo ""
  echo "Available providers:"
  echo "  - RaylibInputProvider: Uses raylib's touch input system"
  echo "  - (Future) AndroidInputProvider: Native Android input"
  echo "  - (Future) iOSInputProvider: Native iOS input"
  echo ""
  echo "Usage:"
  echo "  let gestureManager = newGestureManager()"
  echo "  let inputProvider = createInputProvider(gestureManager)"
  echo ""
  echo "  # In main loop:"
  echo "  inputProvider.update()  # Polls touch input and recognizes gestures"
