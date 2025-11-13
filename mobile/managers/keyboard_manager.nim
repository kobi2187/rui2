## Virtual Keyboard Manager
##
## Manages virtual keyboard state, animations, and layout adjustments
## for mobile platforms.

import ../types
import ../../core/types
import std/[options, monotimes, times]

# ============================================================================
# Keyboard Manager
# ============================================================================

type
  KeyboardManager* = ref object
    currentKeyboard*: KeyboardInfo
    previousKeyboard: KeyboardInfo
    targetWidget*: Option[Widget]  # Widget that triggered keyboard
    animationStartTime: MonoTime
    enabled*: bool

    # Callbacks
    onKeyboardShow*: proc(keyboardInfo: KeyboardInfo)
    onKeyboardHide*: proc()
    onKeyboardChange*: proc(oldInfo, newInfo: KeyboardInfo)
    onLayoutAdjustNeeded*: proc(keyboardHeight: float32)

# ============================================================================
# Initialization
# ============================================================================

proc newKeyboardManager*(): KeyboardManager =
  ## Create a new keyboard manager
  let defaultKeyboard = KeyboardInfo(
    state: ksHidden,
    height: 0.0f32,
    animationDuration: 0.25f32,  # 250ms standard iOS animation
    keyboardType: ktDefault
  )

  result = KeyboardManager(
    currentKeyboard: defaultKeyboard,
    previousKeyboard: defaultKeyboard,
    targetWidget: none(Widget),
    animationStartTime: getMonoTime(),
    enabled: true
  )

# ============================================================================
# Keyboard State Management
# ============================================================================

proc showKeyboard*(km: KeyboardManager, widget: Widget,
                   keyboardType: KeyboardType = ktDefault,
                   keyboardHeight: float32 = 300.0f32) =
  ## Show virtual keyboard for a widget
  if not km.enabled:
    return

  km.previousKeyboard = km.currentKeyboard
  km.targetWidget = some(widget)
  km.animationStartTime = getMonoTime()

  km.currentKeyboard = KeyboardInfo(
    state: ksShowing,
    height: keyboardHeight,
    animationDuration: 0.25f32,
    keyboardType: keyboardType
  )

  # Trigger callbacks
  if km.onKeyboardShow != nil:
    km.onKeyboardShow(km.currentKeyboard)

  if km.onLayoutAdjustNeeded != nil:
    km.onLayoutAdjustNeeded(keyboardHeight)

proc hideKeyboard*(km: KeyboardManager) =
  ## Hide virtual keyboard
  if not km.enabled:
    return

  km.previousKeyboard = km.currentKeyboard
  km.animationStartTime = getMonoTime()

  km.currentKeyboard.state = ksHiding

  # Will transition to hidden in update
  if km.onKeyboardHide != nil:
    km.onKeyboardHide()

  if km.onLayoutAdjustNeeded != nil:
    km.onLayoutAdjustNeeded(0.0f32)

proc updateKeyboard*(km: KeyboardManager, info: KeyboardInfo) =
  ## Update keyboard information (from system events)
  if not km.enabled:
    return

  let oldInfo = km.currentKeyboard
  km.currentKeyboard = info

  if km.onKeyboardChange != nil:
    km.onKeyboardChange(oldInfo, info)

  # Trigger layout adjustment if height changed
  if info.height != oldInfo.height and km.onLayoutAdjustNeeded != nil:
    km.onLayoutAdjustNeeded(info.height)

# ============================================================================
# Animation & State Updates
# ============================================================================

proc getAnimationProgress*(km: KeyboardManager): float32 =
  ## Get current animation progress (0.0 to 1.0)
  if km.currentKeyboard.state notin {ksShowing, ksHiding}:
    return 1.0f32

  let elapsed = getMonoTime() - km.animationStartTime
  let elapsedSec = elapsed.inMilliseconds.float32 / 1000.0
  let duration = km.currentKeyboard.animationDuration

  result = elapsedSec / duration
  if result > 1.0f32:
    result = 1.0f32

proc getCurrentHeight*(km: KeyboardManager): float32 =
  ## Get current animated keyboard height
  case km.currentKeyboard.state
  of ksHidden:
    0.0f32
  of ksVisible:
    km.currentKeyboard.height
  of ksShowing:
    # Animate from 0 to height
    let progress = km.getAnimationProgress()
    km.currentKeyboard.height * progress
  of ksHiding:
    # Animate from height to 0
    let progress = km.getAnimationProgress()
    km.currentKeyboard.height * (1.0 - progress)

proc update*(km: KeyboardManager) =
  ## Update keyboard state (call every frame)
  if not km.enabled:
    return

  # Check if animation finished
  if km.currentKeyboard.state == ksShowing:
    if km.getAnimationProgress() >= 1.0f32:
      km.currentKeyboard.state = ksVisible

  elif km.currentKeyboard.state == ksHiding:
    if km.getAnimationProgress() >= 1.0f32:
      km.currentKeyboard.state = ksHidden
      km.currentKeyboard.height = 0.0f32
      km.targetWidget = none(Widget)

# ============================================================================
# Query Functions
# ============================================================================

proc isKeyboardVisible*(km: KeyboardManager): bool =
  ## Check if keyboard is currently visible (or showing)
  km.currentKeyboard.state in {ksVisible, ksShowing}

proc isKeyboardHidden*(km: KeyboardManager): bool =
  ## Check if keyboard is completely hidden
  km.currentKeyboard.state == ksHidden

proc isAnimating*(km: KeyboardManager): bool =
  ## Check if keyboard is currently animating
  km.currentKeyboard.state in {ksShowing, ksHiding}

proc getKeyboardType*(km: KeyboardManager): KeyboardType =
  ## Get current keyboard type
  km.currentKeyboard.keyboardType

proc getTargetWidget*(km: KeyboardManager): Option[Widget] =
  ## Get widget that triggered keyboard
  km.targetWidget

# ============================================================================
# Layout Adjustment Helpers
# ============================================================================

proc calculateAdjustedBounds*(km: KeyboardManager, originalBounds: Rect,
                              focusedWidgetBounds: Rect): Rect =
  ## Calculate adjusted bounds to keep focused widget visible
  ## Returns new bounds with y offset to avoid keyboard
  result = originalBounds

  if not km.isKeyboardVisible():
    return

  let keyboardTop = originalBounds.height - km.getCurrentHeight()
  let widgetBottom = focusedWidgetBounds.y + focusedWidgetBounds.height

  # Check if widget would be obscured by keyboard
  if widgetBottom > keyboardTop:
    # Need to scroll up
    let offset = widgetBottom - keyboardTop + 20.0f32  # 20px padding
    result.y -= offset

proc shouldAdjustLayout*(km: KeyboardManager, widgetBounds: Rect): bool =
  ## Check if layout adjustment is needed for a widget
  if not km.isKeyboardVisible():
    return false

  # Get screen height (this would come from display manager in real use)
  # For now, use a placeholder
  let screenHeight = 800.0f32
  let keyboardTop = screenHeight - km.getCurrentHeight()
  let widgetBottom = widgetBounds.y + widgetBounds.height

  return widgetBottom > keyboardTop

proc getAvailableHeight*(km: KeyboardManager, screenHeight: float32): float32 =
  ## Get available screen height when keyboard is visible
  if km.isKeyboardVisible():
    screenHeight - km.getCurrentHeight()
  else:
    screenHeight

# ============================================================================
# Focus Management Integration
# ============================================================================

proc onWidgetFocused*(km: KeyboardManager, widget: Widget,
                      keyboardType: KeyboardType = ktDefault) =
  ## Called when a text input widget receives focus
  if not km.enabled:
    return

  # Auto-show keyboard for text input widgets
  # In real implementation, would check widget type
  km.showKeyboard(widget, keyboardType)

proc onWidgetBlurred*(km: KeyboardManager, widget: Widget) =
  ## Called when a text input widget loses focus
  if not km.enabled:
    return

  # Auto-hide keyboard when focus lost
  if km.targetWidget.isSome and km.targetWidget.get == widget:
    km.hideKeyboard()

# ============================================================================
# Keyboard Type Selection Helpers
# ============================================================================

proc getKeyboardTypeForWidget*(widget: Widget): KeyboardType =
  ## Suggest keyboard type based on widget properties
  ## This is a placeholder - real implementation would check widget type/properties
  ktDefault

proc setKeyboardType*(km: KeyboardManager, keyboardType: KeyboardType) =
  ## Change keyboard type while keyboard is visible
  if km.isKeyboardVisible():
    km.currentKeyboard.keyboardType = keyboardType

# ============================================================================
# Utility Functions
# ============================================================================

proc clear*(km: KeyboardManager) =
  ## Reset keyboard manager state
  km.hideKeyboard()
  km.targetWidget = none(Widget)

proc enable*(km: KeyboardManager) =
  ## Enable keyboard manager
  km.enabled = true

proc disable*(km: KeyboardManager) =
  ## Disable keyboard manager
  km.enabled = false
  km.clear()
