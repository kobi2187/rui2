
# widgets/progress.nim
type
  ProgressBar* = ref object of Widget
    value*: float32
    maxValue*: float32
    showText*: bool

method draw*(pb: ProgressBar) =
  GuiProgressBar(
    Rectangle(
      x: pb.rect.x,
      y: pb.rect.y,
      width: pb.rect.width,
      height: pb.rect.height
    ),
    "",
    $pb.value,
    0,
    pb.maxValue
  )