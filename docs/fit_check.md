# Does it fit? Checking an app on many phones

`tools/fit_check.sh` lays an app out at the screen size of each device in a
list. It reports, per device, whether everything fits, and if not, what and
where. It runs headless, so a dozen devices take a few seconds:

```bash
tools/fit_check.sh mobile/mockups/rui/mockups.nim -- 04_inbox
```

```
  iPhone SE                375x667    fits           0 errors,  0 small targets
  Galaxy S24               360x780    DOES NOT FIT   1 errors,  0 small targets
  Small phone              320x568    DOES NOT FIT   1 errors,  0 small targets
  Pixel 9 landscape        923x412    fits           0 errors,  0 small targets
  ...
```

and in `report.md`:

```
## Small phone (320x568)
- **cut** `.../Row[1]/Expanded/Column[1]/Label`: text needs 252 px, has 208
```

## What counts as not fitting

| kind | meaning | usual fix |
|---|---|---|
| `offscreen` | part of a widget is outside the screen, and no scroll view is there to reach it | a `ScrollView`, a `Wrap` instead of a `Row`, `.flex` / `.flexible` on what can give |
| `overflow` | a widget sticks out of its parent (Flutter's "RenderFlex overflowed by N pixels") | the same; or `.ownSize` / `OverflowBox` if the overflow is on purpose |
| `sideways` | a scroll view's content is wider than the view, so a list meant to scroll down scrolls sideways too | `ScrollView(wrapToWidth = true)` |
| `cut` | a label or button has less room than its text needs; for a wrapping label, fewer lines than it needs | `wrap = true`, a shorter text, `.flexible` |
| `small-target` (warning) | something to tap is under 44 px on a side (Apple's minimum; `--touch 48` uses Material's) | a bigger control, or padding inside its tap area |

Each problem is reported once, at the widget where it starts, not again for
everything inside it. A part that a scroll view or a `Clip` cuts away is
fine; the user can reach it or was meant not to see it. Hidden widgets (an
inactive tab, `Offstage`, `.showIf(false)`) are not checked.

## Options

```bash
tools/fit_check.sh --shots app.nim
```

`--shots` also renders each device on Xvfb and writes `<device>.png`, with
errors outlined in red and small targets in amber.

```bash
tools/fit_check.sh --devices "Watch=184x224,Kiosk=1080x1920" app.nim
```

`--devices` sets your own list of `name=WxH` sizes. The default list has
common phones (iPhone SE, 16, 16 Pro Max; Pixel 9; Galaxy S24, A15, Z Fold
folded; a 320-wide small phone), a phone in landscape, two tablets and a
laptop.

```bash
tools/fit_check.sh --touch 48 app.nim
```

`--touch 48` sets the tap-target minimum.

`-- args` passes arguments through to the app. Output goes to
`$RUI_FIT_OUT` (default `/tmp/rui_fit_check`). The exit status is 1 if any
device has an error, so a CI step can gate on it.

## Sizes and resolutions

Sizes are *logical* pixels (Android dp, iOS points), which is what layout
sees. A phone's resolution is that times its density (a Pixel 9's 412×923 dp
is 1080×2424 physical pixels). RUI does not scale by density yet, so today
only the logical size changes the layout.

## How it works, and using it from code

Two environment variables, which any RUI app honours:

- `RUI_WINDOW_SIZE=WxH` overrides the size the app asked `newApp` for. It
  works for a real window too, to see the app at a phone's size.
- `RUI_FIT_CHECK=<file>` lays the app out once without a window, writes the
  problems as JSON (`fitReport`) and exits.

The check itself is `fitIssues(root, window)` in
`packages/rui/src/fit_check.nim`. It is plain code over a laid-out tree, so a
test can call it directly:

```nim
let issues = fitIssues(root, Rect(width: 320, height: 568))
check issues.len == 0
```

`tests/test_fit_check.nim` has an example of each kind.
