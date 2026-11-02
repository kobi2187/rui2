# Making RUI obvious again: a simplification plan

RUI grew by features: widgets, themes, effects, each added where it fit at the
time. Each addition was sound on its own, but together they left the same job
done in several ways. This plan steps back and looks at the whole. For each
problem it gives the evidence and the fix, and it lists the fixes in the order
worth doing them. Nothing here changes what an app can do; it changes how many
ideas a reader has to hold to understand how RUI does it.

## The shape today

| Package | Files | Lines | Job |
|---|---:|---:|---|
| `rui_core` | 33 | 7,074 | widget type, DSL macros, the two-pass loop, Links, timers, overlays, popups, pointer state, preferences |
| `rui_drawing` | 27 | 8,040 | shapes and shaders, text, themes and theme files, themed control parts, backgrounds, glass, backdrops |
| `rui_events` | 6 | 1,358 | event manager, focus manager, focus groups |
| `rui_hittest` | 3 | 615 | interval-tree hit testing |
| `rui_widgets` | 159 | 21,318 | every widget, plus shared behaviour (press, choice, scroll_drag, popup_field...) |
| `rui` | 10 | 2,655 | the App: window, frame loop, routing, overlays, focus rings, help |
| `rui_scripting`, `rui_windows`, `rui_shaped` | 19 | 2,970 | automation, in-app windows, shaped windows |

The core ideas are good and stay:
- Every widget paints into its own cached texture, and its parent composites
  those textures.
- Layout is measure, then arrange.
- Shared behaviour is plain library code that a widget calls.
- The theme is data: State × Intent → Props.

## What has drifted

### 1. Two widget macros that are one

`definePrimitive` and `defineWidget` generate identical code: the two macros in
`rui_core/widget_dsl.nim` differ only in their comments. They are used 80 and
34 times. `ARCHITECTURE.md` still describes a distinction ("a primitive has no
`layout`") that no longer exists. A reader learns two names, and then a rule
that the code doesn't keep.

### 2. Three ways to paint past your bounds

- **Overlay `chrome`:** a callback the App runs in screen space under a
  floating widget. It draws menus' soft shadows and the frosted glass.
- **`effectReach`:** the texture margin added in this round. It draws the focus
  glow and Aqua's soft shadows.
- **Bounds enlarged to hold the effect:** a Button's hard drop shadow is inside
  its bounds, and `bodyRect` works out the smaller body. Its layout size
  includes a shadow that isn't part of the control.

A fourth, `drawFloatingShadow`, is called from chrome and from modals. These
are four answers to one question.

### 3. Two vocabularies for the same effects

ThemeProps describes a surface twice:

| Idea | Old field (read by `drawThemedRect`) | New field (read by `boxFinish`) |
|---|---|---|
| gradient | `gradientStart`, `gradientEnd`, `gradientDirection` | `gradient` |
| glow | `glowColor`, `glowRadius` | `focusGlowRadius`, `focusGlowColor` → `glow` |
| inset depth | `insetShadowDepth`, `insetShadowOpacity` | `relief` (negative) |
| soft shadow | `dropShadowBlur` | `softShadow` |

The old set is read only by `drawThemedRect`, which only Card, Drawer and
SidePane call. It goes through a registry of rectangle effects
(`drawing_effects.nim` plus `effects/rect_effects.nim`, about 700 lines). The
new set goes through `BoxFinish` and the box shader, and every control uses it.
A theme author can't tell which fields do anything where.

### 4. Each new theme setting costs six edits

The theme-wide looks were added one at a time as top-level fields:
- `tipShape`, `glass`, `fizz`, `pulse`;
- `titleColor`, `backdrop`, `hint`;
- the `assets.background*` fields;
- `typography.headingFont`.

Adding one means editing:
1. the `Theme` object;
2. the `ThemeFile` fields;
3. the file reader (`toTheme`);
4. the file writer (`themeToJson`);
5. `BrandSpec` and the `brandTheme` mapping;
6. `BrandFile` and `toBrandSpec`.

Each setting's name, type, default and meaning are spread over three files.
Adding `glass` this round touched all six. Nothing groups the settings either:
looks, surfaces and behaviours sit side by side.

### 5. The UI's shared state is in twelve places

Widgets have no reference to the App, by design, so per-UI state lives in
module-level variables "like `currentTheme`". There are twelve such modules:
- the theme and its text defaults;
- the pointer and its capture;
- repaint timers and widget timers;
- open popups and the pending focus request;
- the overlay layer;
- input mode (mouse or touch) and motion preferences;
- the page that glass blurs.

The design is right, but nothing lists this state in one place. Each module
resets on its own, and a reader finds the state only by tripping over it.

### 6. Drawing is layered by accident

`rui_drawing` has:
- raw shapes (`primitives/`);
- themed control parts (`widget_primitives.nim`, 956 lines);
- the legacy effect registry (`drawing_effects`, `effects/`);
- surfaces (`backdrop`, `theme_background`, `tiles`, `textures`).

Some parts never reach the theme. The scroll bar is drawn by
`primitives/controls.drawScrollbar` in fixed translucent tints, which is why
Aqua couldn't have a gel thumb. `drawTooltip` is another.

### 7. The App does everything the widgets can't

`rui/app.nim` is 1,459 lines. It holds:
- the window and the frame loop;
- event routing glue and the focus rings;
- the help overlay and overlay compositing;
- the glass page and the frozen modal page;
- the scripting indicator;
- theme switching.

Each part is reasonable, but together the file is the hardest one in the
project to read.

### 8. The architecture document describes an older RUI

`ARCHITECTURE.md` gets several basics wrong:
- it lists seven packages, but there are nine (`rui_windows` and `rui_shaped`
  are missing);
- it says the tree still uses flat `core/` and `widgets/` directories, which it
  doesn't;
- it describes the two-macro distinction from item 1.

## The plan, in order

Each step is a pull request of its own and leaves RUI working. Each is checked
by the layout snapshots, the visual goldens and the GL tests. The first steps
are cheap and clear the way for the rest.

### Step 1. One widget macro (small, low risk) -- done

- Keep `defineWidget` as the only macro.
- Keep `definePrimitive` as a one-line deprecated alias, so nothing breaks.
- Move the 80 uses over, mechanically.
- Say in one sentence what a widget is: a type with props, state, actions,
  events, and optional `init`, `layout` and `render`.

### Step 2. Correct the architecture document (small) -- done

Fix the package list, the directory claim and the macro section now. Then
rewrite it around the four ideas above once steps 3 to 6 land, so it stays
true.

### Step 3. One way past the bounds: `effectReach` (medium)

- **Hard drop shadow:** it becomes a finish term, a shadow with an offset and no
  blur, drawn through effect reach. A Button's bounds become its body, and
  `bodyRect` goes. Layout snapshots will change: buttons lose the shadow's few
  pixels.
- **Floating panels:** their soft shadow moves to effect reach too. The overlay
  layer already composites a texture's margin.
- **Chrome:** it stays for the one thing that really needs screen space, glass,
  which reads the page under the panel. Rename it to say so:
  `drawBehind`, documented as "for effects that read what is behind".

Afterwards there's one rule: "paint past your bounds with `effectReach`".

### Step 4. One effect vocabulary: `BoxFinish` (medium)

- Make the finish the only description of a surface. ThemeProps holds the
  finish terms once:
  - shape: `cornerCut`;
  - surface: `gloss`, `gradient`, `caustic`, `relief`;
  - outline: `dimensionLines`;
  - effects past the bounds: `softShadow`, the shadow offset, the glow.
- Card, Drawer and SidePane draw with `drawBox` and the finish, like every
  control.
- The file reader still accepts the old field names and maps them onto the
  finish (`gradientStart`/`End` → `gradient`, `insetShadowDepth` → a negative
  `relief`), so existing theme files keep loading.
- Delete `drawThemedRect`, the effect registry and the legacy rectangle effects
  (about 700 lines).
- Bevels (BeOS) stay as they are. They're a real style of their own, and
  `relief` doesn't replace them.

### Step 5. Declare each theme setting once (medium, the biggest payoff later)

Describe every setting in one table: its name, type, default, a sentence of
meaning, and its scope:
- per state (in ThemeProps);
- theme-wide;
- brand-only.

A small macro generates from that table:
- the `ThemeFile` fields, the reader and the writer;
- the `BrandSpec` and `BrandFile` fields and their mapping;
- the reference section of `docs/themes.md`.

Group the theme-wide settings by what they are:

| Group | Settings |
|---|---|
| `typography` | body and heading fonts |
| `surfaces` | window background (tile, picture, tint), glass, modal backdrop |
| `chrome` | title bars, tooltip shape, the help overlay's hints |
| `behaviour` | transitions, pulse, fizz, motion defaults |

A new look then becomes one table row and the code that draws it.

### Step 6. Name the UI context (medium, mostly mechanical)

- Gather the twelve modules' per-UI state into one documented object in
  `rui_core/context.nim`, as fields of one global `ui`: theme, pointer, focus
  request, popups, overlays, timers, input mode, motion and the glass page.
- Give it one `reset` (tests and multi-app use need this), and a page listing
  what is in it and why it is global.
- Widgets keep reading it directly. The design doesn't change; it just becomes
  visible.

### Step 7. Drawing in three layers (medium)

| Layer | Contents |
|---|---|
| **Shapes** | the shader-drawn box, shadow, segment, triangle and image, plus text |
| **Parts** | every themed piece of a control (box, check box, radio, slider, progress, scroll bar, tooltip, tab, menu row), each drawn from ThemeProps with the finish |
| **Surfaces** | what is behind the widgets: window background, tiles, glass, modal backdrop |

The scroll bar and the tooltip move into Parts, which closes Aqua's scroll-bar
gap as a side effect. `primitives/controls` folds into Parts.

### Step 8. Split the App by job (small to medium)

The App becomes an index of a few files, one per job:
- window and frame loop;
- compositing (root, overlays, glass page, frozen page);
- focus rings and help.

Routing is already in a file of its own.

## What this buys

| Topic | Before | After |
|---|---|---|
| Widget macros | two names, one meaning | one |
| Painting past the bounds | four mechanisms | one, plus a named exception for glass |
| Effect vocabulary | two | one, with a compatibility map for old theme files |
| Adding a theme setting | six edits in three files | one table row |
| Shared UI state | twelve modules | one documented object |
| Drawing layers | four, accidental | three, deliberate |
| `app.nim` | 1,459 lines | a few files with one job each |
| Architecture doc | out of date | describes the RUI you're reading |

About 1,000 lines go: the effect registry, the duplicate macro body,
`bodyRect`, and the per-field file plumbing that the generated code replaces.
