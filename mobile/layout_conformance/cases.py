#!/usr/bin/env python3
"""cases.py -- the layout conformance cases, in Flutter's vocabulary, as JSON.

    python3 cases.py > cases.json

One case is a widget tree laid out in a viewport. Both toolkits build it from
the same JSON -- Flutter in test/layout_conformance_test.dart, RUI in
rui_runner.nim -- and report every node's rect; compare.py diffs them.

A node is {"w": "<Flutter widget>", "p": {props}, "c": [children]}. Props are
Flutter's names and meanings (padding is [left, top, right, bottom]; an
alignment is [x, y]; null or a missing key means "not given"). Every node gets
an id from its path ("0", "0.1", "0.1.2"), so containers are compared as well
as leaves.

Leaves:
  Box(w, h)  SizedBox(width: w, height: h) -- a fixed size, *within* what the
             parent allows (Flutter clamps it to the parent's constraints)
  Fill()     Container() with a colour and no child: as big as allowed
  Text(s, size, wrap)  Roboto at `size` logical pixels

Cases carry `tags`: what they exercise. `expect` notes what Flutter does when it
is remarkable (an overflow, an error), for the reader of the report.
"""
import itertools
import json
import sys

CASES = []


def n(w, *children, **p):
    node = {"w": w, "p": {k: v for k, v in p.items() if v is not None}}
    if children:
        node["c"] = list(children)
    return node


def Box(w=None, h=None): return n("Box", width=w, height=h)
def Fill(): return n("Fill")
def Text(s, size=16, wrap=True): return n("Text", text=s, size=size, wrap=wrap)


def case(name, tree, size=(300, 200), tags=(), expect=None, compare="xywh"):
    CASES.append({"name": name, "size": list(size), "tree": tree,
                  "tags": list(tags), "expect": expect, "compare": compare})


MAIN = ["start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly"]
CROSS = ["start", "center", "end", "stretch"]

# --- Row / Column / Flex ------------------------------------------------------
for d in ["Row", "Column"]:
    for m in MAIN:
        case(f"{d}/main/{m}", n(d, Box(40, 30), Box(60, 20), Box(30, 40), mainAxisAlignment=m),
             tags=["flex", "main-axis"])
    for c in CROSS:
        case(f"{d}/cross/{c}", n(d, Box(40, 30), Box(60, 20), Box(30, 40), crossAxisAlignment=c),
             tags=["flex", "cross-axis"])
    for m, size in itertools.product(["min", "max"], ["start", "center", "end"]):
        case(f"{d}/mainAxisSize.{m}/in-center/{size}",
             n("Center", n(d, Box(40, 30), Box(60, 20), mainAxisSize=m, mainAxisAlignment=size)),
             tags=["flex", "main-axis-size"])
    case(f"{d}/spacing", n(d, Box(40, 30), Box(60, 20), Box(30, 40), spacing=12),
         tags=["flex", "spacing"])
    case(f"{d}/spacing+spaceBetween", n(d, Box(40, 30), Box(60, 20), spacing=12,
                                         mainAxisAlignment="spaceBetween"), tags=["flex", "spacing"])
    case(f"{d}/verticalDirection.up", n(d, Box(40, 30), Box(60, 20), verticalDirection="up"),
         tags=["flex", "direction"])
    case(f"{d}/textDirection.rtl", n(d, Box(40, 30), Box(60, 20), textDirection="rtl"),
         tags=["flex", "direction", "rtl"])
    case(f"{d}/empty", n(d), tags=["flex", "edge"])
    case(f"{d}/empty/in-center/min", n("Center", n(d, mainAxisSize="min")), tags=["flex", "edge"])

case("Row/stretch/fixed-height-child-is-forced",
     n("Row", Box(40, 30), Box(60, None), crossAxisAlignment="stretch"),
     tags=["flex", "cross-axis", "constraints"],
     expect="Flutter: a stretched child gets a tight height; the 30-high box is 200 high")
case("Row/stretch/align-keeps-child-size",
     n("Row", n("Align", Box(40, 30), alignment=[0, -1]), Box(60, 20), crossAxisAlignment="stretch"),
     tags=["flex", "cross-axis", "constraints"],
     expect="the idiom for 'stretch the row but not this child': the Align is stretched, the box is not")
case("Column/stretch/fill", n("Column", Fill(), n("SizedBox", Fill(), height=40), crossAxisAlignment="stretch"),
     tags=["flex", "cross-axis"])
case("Row/expanded/1-2", n("Row", n("Expanded", Fill(), flex=1), n("Expanded", Fill(), flex=2)),
     tags=["flex", "expanded"])
case("Row/expanded+fixed", n("Row", Box(50, 20), n("Expanded", Fill()), Box(70, 20)),
     tags=["flex", "expanded"])
case("Row/flexible.loose/small-child",
     n("Row", n("Flexible", Box(30, 20)), n("Flexible", Box(30, 20))),
     tags=["flex", "flexible"], expect="loose: each child keeps 30 px; the rest stays empty")
case("Row/flexible.loose/large-child-capped",
     n("Row", n("Flexible", Box(400, 20)), Box(50, 20)),
     tags=["flex", "flexible", "constraints"],
     expect="the 400-wide box is capped at its 250 px share")
case("Row/flexible.tight", n("Row", n("Flexible", Box(30, 20), fit="tight"), Box(50, 20)),
     tags=["flex", "flexible"])
case("Row/spacer", n("Row", Box(40, 20), n("Spacer"), Box(40, 20), n("Spacer", flex=2), Box(40, 20)),
     tags=["flex", "spacer"])
case("Row/expanded+mainAxisAlignment.center",
     n("Row", n("Expanded", Fill()), Box(40, 20), mainAxisAlignment="center"),
     tags=["flex", "expanded"], expect="an Expanded takes the free space, so alignment does nothing")
case("Row/overflow", n("Row", Box(200, 20), Box(200, 20)),
     tags=["flex", "overflow", "edge"], expect="Flutter: overflows by 100 px (debug stripes); children keep 200")
case("Row/overflow/end", n("Row", Box(200, 20), Box(200, 20), mainAxisAlignment="end"),
     tags=["flex", "overflow", "edge"])
case("Row/expanded/no-room", n("Row", Box(300, 20), n("Expanded", Fill())),
     tags=["flex", "overflow", "edge"], expect="the Expanded gets 0 px")
case("Column/in-row/stretch-height",
     n("Row", n("Column", Box(40, 30), Box(40, 30)), Box(40, 20), crossAxisAlignment="stretch"),
     tags=["flex", "nesting"])
case("Column/expanded-in-column-in-row",
     n("Row", n("Column", Box(40, 30), n("Expanded", Fill())), n("Expanded", Fill())),
     tags=["flex", "nesting", "expanded"])
case("Row/in-column/min",
     n("Column", n("Row", Box(40, 30), Box(40, 30), mainAxisSize="min"), Box(100, 20)),
     tags=["flex", "nesting", "main-axis-size"])
case("Row/in-column/default-stretches-width",
     n("Column", n("Row", Box(40, 30)), crossAxisAlignment="start"),
     tags=["flex", "nesting"], expect="a Row is as wide as its parent allows (300), even in a start-aligned Column")
case("Flex/direction.vertical", n("Flex", Box(40, 30), Box(60, 20), direction="vertical"),
     tags=["flex"])
case("Column/expanded-in-scroll",
     n("SingleChildScrollView", n("Column", Box(40, 30), n("Expanded", Fill()))),
     tags=["flex", "unbounded", "edge", "scroll"],
     expect="Flutter: error -- Expanded in a Column with unbounded height")
case("Row/expanded-in-unbounded-row",
     n("SingleChildScrollView", n("Row", n("Expanded", Fill()), Box(40, 20)), scrollDirection="horizontal"),
     tags=["flex", "unbounded", "edge", "scroll"], expect="Flutter: error -- unbounded width")
case("Expanded/outside-flex", n("Center", n("Expanded", Box(40, 40))),
     tags=["flex", "edge", "misuse"], expect="Flutter: error -- Expanded must be in a Flex")

# --- Padding / SizedBox / ConstrainedBox / Container ---------------------------
case("Padding/fills-parent", n("Padding", Fill(), padding=[10, 20, 30, 40]), tags=["box", "padding"])
case("Padding/in-center", n("Center", n("Padding", Box(40, 30), padding=[10, 20, 30, 40])),
     tags=["box", "padding"])
case("Padding/negative-room", n("Center", n("SizedBox", n("Padding", Fill(), padding=[30, 30, 30, 30]),
                                            width=40, height=40)),
     tags=["box", "padding", "edge"], expect="the child gets 0x0; nothing negative")
case("SizedBox/tight-root-wins", n("SizedBox", Fill(), width=50, height=50),
     tags=["box", "constraints"], expect="the viewport's tight constraints beat the 50x50: it is 300x200")
case("SizedBox/in-center", n("Center", n("SizedBox", Fill(), width=50, height=50)), tags=["box"])
case("SizedBox/width-only", n("Center", n("SizedBox", Box(30, 30), width=80)), tags=["box"])
case("SizedBox/larger-than-parent",
     n("Center", n("SizedBox", n("SizedBox", Fill(), width=500, height=20), width=100, height=50)),
     tags=["box", "constraints", "edge"], expect="the inner box is clamped to 100x50")
case("SizedBox/expand", n("Center", n("SizedBox", Fill(), width="inf", height="inf")), tags=["box"])
case("SizedBox/shrink", n("Center", n("SizedBox", Fill(), width=0, height=0)), tags=["box", "edge"])
case("Box/in-row-taller-than-row",
     n("Center", n("SizedBox", n("Row", Box(40, 300)), width=300, height=50)),
     tags=["box", "constraints", "edge"], expect="clamped to the Row's 50 height")
case("ConstrainedBox/min", n("Center", n("ConstrainedBox", Box(20, 20), minWidth=100, minHeight=60)),
     tags=["box", "constraints"], expect="a 20x20 SizedBox inside a min 100x60 is 100x60")
case("ConstrainedBox/max", n("Center", n("ConstrainedBox", Box(200, 200), maxWidth=100, maxHeight=60)),
     tags=["box", "constraints"])
case("ConstrainedBox/max-with-fill", n("Center", n("ConstrainedBox", Fill(), maxWidth=100, maxHeight=60)),
     tags=["box", "constraints"])
case("LimitedBox/in-unbounded", n("SingleChildScrollView", n("LimitedBox", Fill(), maxHeight=80)),
     tags=["box", "constraints", "unbounded"])
case("UnconstrainedBox", n("SizedBox", n("UnconstrainedBox", Box(400, 20)), width=100, height=50),
     tags=["box", "constraints", "overflow"])
case("OverflowBox", n("Center", n("SizedBox", n("OverflowBox", Fill(), maxWidth=200, maxHeight=200),
                                  width=50, height=50)),
     tags=["box", "constraints", "overflow"])
case("Container/empty-fills", n("Container", color="#80F00000"), tags=["container"],
     expect="a Container without child and size is as big as allowed")
case("Container/empty-in-center", n("Center", n("Container", color="#80F00000")),
     tags=["container", "edge"], expect="in a Center (loose), an empty Container still expands")
case("Container/with-child-shrinks", n("Center", n("Container", Box(40, 30), color="#80F00000")),
     tags=["container"])
case("Container/size+padding+margin",
     n("Center", n("Container", Fill(), width=100, height=80, padding=[10, 10, 10, 10],
                   margin=[5, 5, 5, 5])), tags=["container"],
     expect="width/height include the padding, not the margin")
case("Container/alignment-expands",
     n("Center", n("Container", Box(40, 30), alignment=[1, 1])), tags=["container"],
     expect="with an alignment, a Container fills the parent and aligns its child")
case("Container/constraints", n("Center", n("Container", Box(20, 20), minWidth=80, minHeight=50)),
     tags=["container", "constraints"])

# --- Align / Center ----------------------------------------------------------
for a in [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1], [0.5, -0.5]]:
    case(f"Align/{a[0]},{a[1]}", n("Align", Box(40, 30), alignment=a), tags=["align"])
case("Align/widthFactor", n("Center", n("Align", Box(40, 30), alignment=[1, 0], widthFactor=2,
                                        heightFactor=1.5)), tags=["align"])
case("Center/heightFactor", n("Column", n("Center", Box(40, 30), heightFactor=2), Box(20, 20)),
     tags=["align"])
case("Center/in-column/takes-all-width", n("Column", n("Center", Box(40, 30)), Box(20, 20)),
     tags=["align", "nesting"])
case("Align/in-unbounded", n("SingleChildScrollView", n("Align", Box(40, 30), alignment=[1, 0])),
     tags=["align", "unbounded"], expect="unbounded height: the Align is as tall as its child")

# --- Stack / Positioned / IndexedStack ----------------------------------------
case("Stack/loose", n("Stack", Box(80, 60), Box(40, 30)), tags=["stack"],
     expect="the root's tight constraints make the Stack 300x200; children at natural size, top-left")
case("Stack/loose/in-center", n("Center", n("Stack", Box(80, 60), Box(40, 30))), tags=["stack"],
     expect="sized to the biggest non-positioned child")
case("Stack/alignment.center", n("Stack", Box(80, 60), Box(40, 30), alignment=[0, 0]), tags=["stack"])
case("Stack/alignment.bottomRight/in-center",
     n("Center", n("Stack", Box(80, 60), Box(40, 30), alignment=[1, 1])), tags=["stack"])
case("Stack/fit.expand", n("Stack", Box(80, 60), Box(40, 30), fit="expand"), tags=["stack"])
case("Stack/fit.passthrough/in-center",
     n("Center", n("Stack", Box(80, 60), fit="passthrough")), tags=["stack"])
for pos in [dict(left=10, top=20), dict(right=10, bottom=20), dict(left=10, right=10, top=5),
            dict(left=10, top=10, right=10, bottom=10), dict(left=10, width=50, bottom=0),
            dict(top=10, height=30), dict(right=0, width=60, height=40)]:
    label = ",".join(f"{k}={v}" for k, v in pos.items())
    case(f"Positioned/{label}", n("Stack", Fill(), n("Positioned", Box(40, 30), **pos)),
         tags=["stack", "positioned"])
case("Positioned/fill", n("Stack", Box(40, 30), n("Positioned", Fill(), left=0, top=0, right=0, bottom=0)),
     tags=["stack", "positioned"])
case("Positioned/only-positioned/in-center", n("Center", n("Stack", n("Positioned", Box(40, 30), left=10))),
     tags=["stack", "positioned", "edge"], expect="no plain child: the Stack takes the biggest size")
case("Positioned/outside-the-stack",
     n("Center", n("SizedBox", n("Stack", Fill(), n("Positioned", Box(40, 30), left=-20, top=70)),
                   width=100, height=80)),
     tags=["stack", "positioned", "overflow"], expect="negative offset and past the bottom; clipped by default")
case("Positioned/directional-rtl", n("Stack", Fill(), n("Positioned", Box(40, 30), start=10, top=10),
                                     textDirection="rtl"),
     tags=["stack", "positioned", "rtl"])
case("IndexedStack/sizes-to-largest", n("Center", n("IndexedStack", Box(80, 30), Box(40, 60), index=1)),
     tags=["stack"], expect="as big as its biggest child, even when that one is hidden")

# --- Wrap ---------------------------------------------------------------------
kids = [Box(70, 20), Box(90, 30), Box(50, 20), Box(110, 25), Box(60, 20)]
case("Wrap/basic", n("Wrap", *kids), tags=["wrap"])
case("Wrap/spacing", n("Wrap", *kids, spacing=10, runSpacing=6), tags=["wrap", "spacing"])
for a in MAIN:
    case(f"Wrap/alignment.{a}", n("Wrap", *kids, alignment=a), tags=["wrap"])
for a in ["start", "center", "end"]:
    case(f"Wrap/crossAxisAlignment.{a}", n("Wrap", *kids, crossAxisAlignment=a), tags=["wrap"])
for a in ["start", "center", "end", "spaceBetween"]:
    case(f"Wrap/runAlignment.{a}", n("Wrap", *kids, runAlignment=a), tags=["wrap"])
case("Wrap/direction.vertical", n("Wrap", *kids, direction="vertical"), tags=["wrap", "direction"])
case("Wrap/child-wider-than-run", n("Wrap", Box(40, 20), Box(400, 20), Box(40, 20)),
     tags=["wrap", "overflow", "edge"])
case("Wrap/in-center/shrinks", n("Center", n("Wrap", Box(40, 20), Box(40, 20), spacing=5)),
     tags=["wrap"])
case("Wrap/rtl", n("Wrap", *kids, textDirection="rtl"), tags=["wrap", "rtl"])

# --- Table / GridView ---------------------------------------------------------
def row(*cells): return n("TableRow", *cells)


case("Table/flex-default", n("Table", row(Box(40, 20), Box(60, 30)), row(Box(80, 20), Box(20, 20))),
     tags=["table"])
case("Table/fixed+intrinsic+flex",
     n("Table", row(Box(40, 20), Box(60, 30), Box(10, 10)), row(Box(80, 20), Box(20, 20), Box(10, 10)),
       columnWidths={"0": ["fixed", 50], "1": ["intrinsic"], "2": ["flex", 1]}),
     tags=["table"])
case("Table/fraction", n("Table", row(Box(40, 20), Box(40, 20)),
                         columnWidths={"0": ["fraction", 0.3], "1": ["flex", 1]}), tags=["table"])
for v in ["top", "middle", "bottom", "fill"]:
    case(f"Table/verticalAlignment.{v}",
         n("Table", row(Box(40, 20), Box(40, 50)), defaultVerticalAlignment=v), tags=["table"])
case("Table/in-center/intrinsic", n("Center", n("Table", row(Box(40, 20), Box(60, 30)),
                                               defaultColumnWidth=["intrinsic"])),
     tags=["table"])
case("GridView/count-2", n("GridView", *[Fill() for _ in range(5)], crossAxisCount=2),
     tags=["grid", "scroll"])
case("GridView/count-3/spacing/aspect", n("GridView", *[Fill() for _ in range(7)], crossAxisCount=3,
                                         mainAxisSpacing=8, crossAxisSpacing=4, childAspectRatio=1.5),
     tags=["grid", "scroll"])
case("GridView/maxCrossAxisExtent", n("GridView", *[Fill() for _ in range(6)], maxCrossAxisExtent=90),
     tags=["grid", "scroll"])

# --- Aspect / fractional / intrinsic -------------------------------------------
case("AspectRatio/in-center", n("Center", n("AspectRatio", Fill(), aspectRatio=2)), tags=["ratio"],
     expect="as wide as allowed (300), half as tall (150)")
case("AspectRatio/height-limited", n("AspectRatio", Fill(), aspectRatio=0.5), tags=["ratio"])
case("FractionallySizedBox", n("FractionallySizedBox", Fill(), widthFactor=0.5, heightFactor=0.25),
     tags=["ratio"])
case("FractionallySizedBox/alignment",
     n("FractionallySizedBox", Fill(), widthFactor=0.5, alignment=[1, 1]), tags=["ratio"])
case("IntrinsicHeight/row-of-unequal",
     n("Center", n("IntrinsicHeight", n("Row", Box(40, 30), n("Container", width=20, color="#ff0000"),
                                         Box(40, 60), crossAxisAlignment="stretch"))),
     tags=["intrinsic"], expect="the stretched Container is as tall as the tallest box (60)")
case("IntrinsicWidth/column-of-unequal",
     n("Center", n("IntrinsicWidth", n("Column", Box(40, 30), Box(90, 20), n("Container", height=10,
                                                                       color="#ff0000"),
                                        crossAxisAlignment="stretch"))),
     tags=["intrinsic"], expect="every child as wide as the widest (90)")
case("Offstage", n("Column", n("Offstage", Box(40, 30)), Box(50, 20)), tags=["visibility"])
case("Visibility/gone", n("Column", n("Visibility", Box(40, 30), visible=False), Box(50, 20)),
     tags=["visibility"])
case("Visibility/maintainSize",
     n("Column", n("Visibility", Box(40, 30), visible=False, maintainSize=True), Box(50, 20)),
     tags=["visibility"])

# --- Scrolling ----------------------------------------------------------------
case("SingleChildScrollView/column-of-boxes",
     n("SingleChildScrollView", n("Column", *[Box(100, 60) for _ in range(5)])), tags=["scroll"],
     expect="the column is 300 tall, laid out in full past the 200 px viewport")
case("SingleChildScrollView/padding",
     n("SingleChildScrollView", n("Column", Box(100, 60)), padding=[8, 8, 8, 8]), tags=["scroll"])
case("ListView/children", n("ListView", *[Box(100, 50) for _ in range(6)]), tags=["scroll", "list"],
     expect="children stretched to the full width")
case("ListView/itemExtent", n("ListView", *[Box(100, 50) for _ in range(6)], itemExtent=30),
     tags=["scroll", "list"])
case("ListView/horizontal", n("ListView", *[Box(60, 50) for _ in range(6)], scrollDirection="horizontal"),
     tags=["scroll", "list"])

# --- Text in layouts (Roboto; widths only) --------------------------------------
LONG = "Layout wraps text at the width its parent allows, not at the screen's"
case("Text/in-column/wraps", n("Column", Text(LONG), crossAxisAlignment="start"),
     tags=["text", "constraints"], compare="xw",
     expect="Text gets loose constraints of the column's width and wraps inside it")
case("Text/in-row/expanded-wraps", n("Row", Box(50, 20), n("Expanded", Text(LONG))),
     tags=["text", "flex"], compare="xw")
case("Text/in-row/unwrapped-overflows", n("Row", Box(50, 20), Text(LONG)),
     tags=["text", "flex", "overflow"], compare="xw",
     expect="without Expanded the Text gets unbounded width and overflows the Row")
case("Text/in-padding-in-center", n("Center", n("Padding", Text("short"), padding=[8, 8, 8, 8])),
     tags=["text"], compare="xw")

def assign_ids(node, path="0"):
    node["id"] = path
    for i, child in enumerate(node.get("c", [])):
        assign_ids(child, f"{path}.{i}")


for c in CASES:
    assign_ids(c["tree"])

if __name__ == "__main__":
    json.dump({"cases": CASES}, sys.stdout, indent=1)
