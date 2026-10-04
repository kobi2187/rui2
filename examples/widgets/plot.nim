## Plot: lines, areas, bars and scatter points on shared, round axes, in the
## theme's colours.
##
##   nim c -r -d:useGraphics examples/widgets/plot.nim [theme]

import rui
import std/[os, math, options]

let app = newApp("RUI2 - Plot", 760, 560)
app.setTheme(if paramCount() >= 1: paramStr(1) else: "daylight")

var growth, curves: seq[tuple[x, y: float]]
for i in 0 .. 11:
  growth.add (float(i), 20.0 + float(i) * 4.0 + 6.0 * sin(float(i)))
  curves.add (float(i), 50.0 + 30.0 * sin(float(i) / 2.0))

let root = ui:
  VStack(spacing = 12.0, padding = 16.0):
    Row(spacing = 12.0):
      Expanded():
        Plot(title = "Revenue (lines)", series = @[
          lineSeries("2025", growth),
          areaSeries("trend", curves)])
      Expanded():
        Plot(title = "Orders by quarter (bars)",
             xLabels = @["Q1", "Q2", "Q3", "Q4"],
             series = @[
               barSeries("2024", @[(0.0, 12.0), (1.0, 18.0), (2.0, 9.0), (3.0, 22.0)]),
               barSeries("2025", @[(0.0, 15.0), (1.0, 20.0), (2.0, 14.0), (3.0, 25.0)])])
    Plot(title = "Samples (scatter)", series = @[
      scatterSeries("a", @[(1.0, 2.0), (2.0, 3.5), (3.0, 2.8), (4.0, 5.0), (5.0, 4.2), (6.0, 6.5)]),
      scatterSeries("b", @[(1.0, 1.0), (2.0, 1.8), (3.0, 3.1), (4.0, 2.9), (5.0, 3.7), (6.0, 4.0)])]).frame(height = 220)

app.setRootWidget(root)
app.run()
