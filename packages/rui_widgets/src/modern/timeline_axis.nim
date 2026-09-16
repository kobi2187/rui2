## Timeline scales and the time-to-pixel axis.
##
## Split out of timeline.nim: none of this needs a widget or a window, so it can
## be checked against a table of instants.
##
## The projection lives in a `TimelineAxis` value rather than in procs over the
## widget for a structural reason: the widget type does not exist until
## definePrimitive has expanded, and the widget body needs the geometry. A value
## the widget can build from itself (see `axisOf`) is the way round that.

import rui_core
import std/[times, json]

import raylib

type
  TimelineEvent* = object
    id*: string
    title*: string
    description*: string
    startTime*: DateTime
    endTime*: DateTime         # Only meaningful when isDuration
    color*: Color
    isDuration*: bool
    data*: JsonNode

  TimeScale* = enum
    tsMinute = "Minutes"
    tsHour = "Hours"
    tsDay = "Days"
    tsWeek = "Weeks"
    tsMonth = "Months"
    tsYear = "Years"

const
  AxisHeight* = 30.0'f32        ## Time labels live above this line.
  EventAreaTop* = 50.0'f32      ## First event row starts here.
  InstantWidth* = 4.0'f32

proc secondsPerUnit*(scale: TimeScale): float =
  ## Seconds in one unit of `scale`. Month and year are the usual approximations.
  case scale
  of tsMinute: 60.0
  of tsHour: 3600.0
  of tsDay: 86_400.0
  of tsWeek: 604_800.0
  of tsMonth: 2_592_000.0      # 30 days
  of tsYear: 31_536_000.0      # 365 days

proc gridInterval*(scale: TimeScale): Duration =
  case scale
  of tsMinute: initDuration(minutes = 5)
  of tsHour: initDuration(hours = 1)
  of tsDay: initDuration(days = 1)
  of tsWeek: initDuration(weeks = 1)
  of tsMonth: initDuration(days = 30)
  of tsYear: initDuration(days = 365)

proc labelFormat*(scale: TimeScale): string =
  case scale
  of tsMinute, tsHour: "HH:mm"
  of tsDay, tsWeek, tsMonth: "MMM dd"
  of tsYear: "yyyy"

type
  TimelineAxis* = object
    ## The time-to-pixel projection, pulled out of the widget so the geometry
    ## helpers can be defined before it. A proc taking `Timeline` cannot be:
    ## the type does not exist until definePrimitive has expanded, and the
    ## widget's own body needs these helpers.
    originX*: float32
    areaTop*: float32
    startTime*: DateTime
    pixelsPerSecond*: float32
    scrollOffset*: float32
    eventHeight*: float32
    eventSpacing*: float32

proc timeToPixel*(axis: TimelineAxis, time: DateTime): float32 =
  ## Screen x for an instant, taking the pan offset into account.
  let secondsFromStart = float32((time - axis.startTime).inSeconds)
  axis.originX + secondsFromStart * axis.pixelsPerSecond - axis.scrollOffset

proc pixelToTime*(axis: TimelineAxis, pixel: float32): DateTime =
  ## The instant under a screen x.
  let seconds = if axis.pixelsPerSecond == 0: 0.0
                else: float((pixel - axis.originX + axis.scrollOffset) /
                            axis.pixelsPerSecond)
  axis.startTime + initDuration(seconds = int64(seconds))

proc eventRectFor*(axis: TimelineAxis, index: int, evt: TimelineEvent): Rect =
  ## Where event `index` is drawn. Hit-testing and painting both call this, so a
  ## click can never land somewhere other than what was drawn.
  let startX = axis.timeToPixel(evt.startTime)
  let endX = if evt.isDuration: axis.timeToPixel(evt.endTime)
             else: startX + InstantWidth
  Rect(
    x: startX,
    y: axis.areaTop + float32(index) * (axis.eventHeight + axis.eventSpacing),
    width: max(endX - startX, InstantWidth),
    height: axis.eventHeight
  )

