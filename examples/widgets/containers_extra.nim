## Panels, groups, tabs and bars
##
## Column (main/cross axis alignment), Panel, GroupBox, Spacer, StatusBar and
## TabControl.
##
##   nim c -r -d:useGraphics examples/widgets/containers_extra.nim
##
## Widgets carry stringIds, so tools/ui_test.sh can drive this too.

import rui
import std/[options, os]

let app = newApp("RUI2 - Panels and tabs", 620, 560)

proc named[T](x: T, id: string): T =
  x.stringId = id
  x

let root = newVStack(spacing = 12.0, padding = 16.0).named("root")
let summary = newLabel(text = "tab 1", fontSize = 15.0).named("summary")
root.addChild(summary)

# Panel: a frame that insets whatever it holds.
let panel = newPanel(padding = 10.0, cornerRadius = 6.0).named("panel")
panel.bounds = Rect(x: 0, y: 0, width: 560, height: 60)
panel.addChild(newLabel(text = "Inside a Panel", fontSize = 14.0).named("panelText"))
root.addChild(panel)

# GroupBox: a frame with a title, holding a RadioGroup.
let group = newGroupBox(title = "Shipping", padding = 10.0,
                        titleHeight = 20.0).named("group")
let radios = newRadioGroup(options = @["Standard", "Express", "Overnight"],
                           initialSelectedIndex = 0, spacing = 24.0).named("radios")
radios.onSelect = proc(index: int) =
  summary.text = "shipping -> " & radios.options[index]
  summary.isDirty = true
  summary.layoutDirty = true
group.addChild(radios)
root.addChild(group)

# Column with cross-axis alignment, which VStack does not offer.
root.addChild(newLabel(text = "Column, CrossCenter:", fontSize = 14.0).named("t1"))
let column = newColumn(spacing = 6.0, mainAxisAlignment = MainStart,
                       crossAxisAlignment = CrossCenter).named("column")
column.bounds = Rect(x: 0, y: 0, width: 560, height: 90)
for (caption, id) in [("short", "colA"), ("a longer line", "colB"),
                      ("mid", "colC")]:
  column.addChild(newLabel(text = caption, fontSize = 14.0).named(id))
root.addChild(column)

# TabControl: one child per tab, the inactive ones hidden rather than skipped.
root.addChild(newLabel(text = "TabControl:", fontSize = 14.0).named("t2"))
let tabs = newTabControl(tabs = @["First", "Second", "Third"],
                         initialActiveTab = 0, tabBarHeight = 28.0).named("tabs")
tabs.bounds = Rect(x: 0, y: 0, width: 560, height: 120)
for i, caption in ["Content of tab one", "Content of tab two",
                   "Content of tab three"]:
  let page = newVStack(spacing = 4.0, padding = 8.0).named("page" & $i)
  page.addChild(newLabel(text = caption, fontSize = 14.0).named("pageText" & $i))
  # A Spacer soaks up whatever room is left in the page.
  page.addChild(newSpacer(minHeight = 8.0).named("pageSpacer" & $i))
  tabs.addChild(page)
tabs.onTabChanged = proc(newTab: int) =
  summary.text = "tab " & $(newTab + 1)
  summary.isDirty = true
  summary.layoutDirty = true
root.addChild(tabs)

# StatusBar: left message, right-aligned detail.
let status = newStatusBar(text = "Ready", rightText = "Ln 1, Col 1",
                          barHeight = 24.0).named("status")
status.bounds = Rect(x: 0, y: 0, width: 560, height: 24)
root.addChild(status)

app.setRootWidget(root)
let scriptDir = getAppDir() / "script"
app.enableScripting(scriptDir)
app.setScriptPollInterval(0.05)
app.start()
