
# widgets/slider.nim
type
  Slider* = ref object of Widget
    value*: float32
    minValue*: float32
    maxValue*: float32
    onChange*: proc(newValue: float32)

method draw*(slider: Slider) =
  var value = slider.value
  if GuiSlider(
    Rectangle(
      x: slider.rect.x,
      y: slider.rect.y,
      width: slider.rect.width,
      height: slider.rect.height
    ),
    "",
    $value,
    addr value,
    slider.minValue,
    slider.maxValue
  ):
    slider.value = value
    if slider.onChange != nil:
      slider.onChange(value)
