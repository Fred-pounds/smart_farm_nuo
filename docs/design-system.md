# Smart Farm — Design System

The farm is loud, physical and unpredictable. The interface answering for it
should be the opposite: **calm, precise, and quiet enough that a change on
screen means something changed on the farm.**

This document is the reasoning. The values live in
[`lib/theme/design_tokens.dart`](../lib/theme/design_tokens.dart) and
[`lib/theme/app_theme.dart`](../lib/theme/app_theme.dart); the components live
across [`lib/theme/`](../lib/theme/), re-exported by
[`theme.dart`](../lib/theme/theme.dart) so a screen imports one file.

---

## The three rules

### 1. Glass is the instrument housing, never the dial

Translucency carries *structure* — the navigation bar, the app header, sheets,
overlays. Every value a farmer acts on is painted opaque, on a solid panel, at
full contrast.

This is not taste. It follows from two facts about the product:

**It is read outdoors.** In daylight, text floated over a blurred backdrop is
the first thing to become unreadable. An unreadable reading is worse than a
missing one, because the farmer acts on a guess instead of noticing the gap.

**It runs on mid-range Android.** `BackdropFilter` forces everything beneath it
to be rendered to a texture and blurred, every frame it is visible. Two or
three on screen is comfortable. One per row in a scrolling list drops frames on
exactly the hardware these users have.

**The one exception is the Weather screen.** `WeatherGlassCard` is translucent
and carries content, and it earns that because the screen paints its own sky
gradient — so what sits under the blur is known and bounded rather than
arbitrary, and the subject genuinely is atmosphere. Nowhere else.

### 2. Brand hues fill; ink hues label

The brand accents are chosen for *fills*, and most of them fail WCAG AA as text
on a white card. Sky Blue `#4FC3F7` on white is **1.9:1**, where 4.5:1 is the
floor for body copy.

So every meaning carries two values:

| Use it for | Token | Light | Dark |
| --- | --- | --- | --- |
| Text, icons | `growth` | `#2E7D32` (6.4:1) | `#66BB6A` |
| Gauges, charts, gradients | `growthBright` | `#4CAF50` | `#66BB6A` |
| Text, icons | `water` | `#0277BD` (5.6:1) | `#4FC3F7` |
| Fills | `waterBright` | `#4FC3F7` | `#4FC3F7` |
| Text, icons | `sun` | `#B45C09` (4.7:1) | `#FFA726` |
| Fills | `sunBright` | `#FB8C00` | `#FFA726` |
| Text, icons | `alert` | `#C62828` (6.1:1) | `#EF5350` |
| Fills | `alertBright` | `#E53935` | `#EF5350` |

In dark mode the two tiers converge: a mid-tone accent on a near-black panel
already clears AA. Reaching for a `*Bright` value to colour a word is the one
way to break the palette's accessibility floor.

### 3. Colour is never the only signal

Roughly 1 in 12 men has some colour vision deficiency, and this app
distinguishes dry soil from wet for a living. Every coloured state carries a
word or a distinct icon too:

- `StatusPill` pairs a dot with a label rather than shipping a bare dot.
- Alert severity prints "Critical" / "Warning" / "Info" beside the tint.
- The four weather signal cards each have a fixed icon, so level (colour) and
  subject (shape) never collapse into one channel.
- Soil dry/wet uses the most CVD-safe pair available — warm ochre against cool
  blue — rather than the conventional red/green.

---

## Colour

Neither theme is derived from the other, and neither uses `ColorScheme.fromSeed`
for its accents. Generated schemes drift toward Material's own personality and
produce accents that are *almost* right — which on this dashboard means "dry"
and "wet" stop being instantly distinguishable.

**One accent per meaning.** Colour is a data channel here, so decorative colour
is not available:

| Token | Means |
| --- | --- |
| `growth` | Crops, health, confirmation. Primary accent. |
| `water` | Water, irrigation, rain. Never decorative. |
| `sun` | Heat, caution, "look at this soon". |
| `soilDry` / `soilWet` | Above / below the irrigation threshold. |
| `alert` | Faults needing action now. |

**Ink is three steps**, all at or above 4.5:1 on white:
`#1B1B1B` (16.1:1) → `#4B5563` (7.6:1) → `#6B7280` (4.8:1). The brief's
`#6B7280` is the *lightest* step rather than the middle one, because a fourth
step below it would not clear AA at 12px.

**Surfaces.** Light: canvas `#F7FAF7`, cards pure white. Dark: canvas `#101412`,
cards `#1A211D` — a dark grey with a green cast, so the app is recognisably
itself in both themes.

**Never hard-code a colour in a widget.** Read `context.farmColors`. A literal
`Colors.blue` looks fine in one theme, breaks in the other, and silently
detaches the value from its meaning.

---

## Type

**Plus Jakarta Sans**, bundled as one 176 KB variable font (weight axis
200–800) in `assets/fonts/`.

**Bundled, not fetched.** `google_fonts` downloads at first paint, and this app
has to render a moisture reading in a field with no signal. Styles select a
weight instance via `FontVariation('wght', n)` and also set `fontWeight`, so
matching stays sane if the face ever fails to load.

| Tier | Size | Weight | Use |
| --- | --- | --- | --- |
| `displayLarge` | 32 | 600 | The hero readout. One per screen. |
| `displayMedium` | 28 | 600 | A card's primary metric. |
| `displaySmall` | 22 | 600 | Numeric cells mid-hierarchy. |
| `titleLarge` | 20 | 600 | Section titles. |
| `titleMedium` | 16 | 600 | Card titles. |
| `bodyLarge` / `bodyMedium` | 15 / 14 | 400 | Prose. |
| `bodySmall` | 12 | 400 | Captions. |
| `labelSmall` | 11 | 700 | Eyebrows, uppercased at the call site. |

Two things distinguish this from Material's default:

**Live numerals use tabular figures.** On a real-time dashboard, proportional
digits make every sensor update look like a layout glitch as the number shifts
width character by character. Every numeric style is locked to
`FontFeature.tabularFigures()`.

**Large text gets negative tracking.** Default letter spacing at 28px+ reads
loose and consumer-grade; tightening it is most of what separates "app" from
"instrument".

**Bold is used sparingly.** Hierarchy comes from size and colour first, weight
last.

---

## Shape, depth, spacing, motion

**Radii are soft.** `radiusSm` 16 (chips, inputs, buttons) · `radiusMd` 20
(wells, tiles) · `radiusLg` 24 (the default panel) · `radiusXl` 28 (hero
surfaces, sheets). Nothing has a sharp corner except a full-bleed edge.

**Depth is earned.** `Tokens.restingShadow` lifts a card off the canvas;
`raisedShadow` is for the hero and nothing else. If two things on a screen are
raised, neither is. Uniform drop shadows on everything flatten the hierarchy
they are meant to express, which is the single most common reason a dashboard
reads as amateur.

**Spacing is a 4pt grid**, `Tokens.space1`–`space14`. Panels sit `space3`
apart; sections `space6`; pages gutter at `space5`.

**Motion reports, it does not perform.** Nothing bounces or overshoots — a live
reading that springs on arrival reads as the measurement itself being unstable.

| Token | Duration | For |
| --- | --- | --- |
| `motionFast` | 160ms | Segment switches, chip selection, press states. |
| `motionBase` | 240ms | Status dots, pill transitions. |
| `motionSlow` | 380ms | Entrance stagger, sky gradient changes. |
| `motionGauge` | 900ms | Gauges, score rings, meters, sparkline draw-on. |
| `motionShimmer` | 1400ms | One skeleton sweep. |

Three curves: `curveStandard` (easeOutCubic) for changes the user caused,
`curveData` (easeInOutCubic) for values arriving from the farm on their own,
`curveGauge` (easeOutQuart) for arcs filling.

Every repeating animation checks `MediaQuery.disableAnimations` and falls back
to a static render. Shimmer and scan sweeps are exactly the kind of motion that
setting exists to suppress.

---

## Component library

`import '../theme/theme.dart';` gets all of it.

### Surfaces — `glass.dart`

| Component | Use |
| --- | --- |
| `AmbientBackground` | The canvas: gradient plus two soft colour fields. Gradients only, no `BackdropFilter`, so it is nearly free. |
| `GlassSurface` | Nav bar, header, sheets. Falls back to opaque under high contrast. |
| `Panel` | **Where readings live.** Opaque, hairline border, resting shadow. `raised` for the hero, `tinted` + `accentBorder` for the one panel that is the subject. |
| `PanelWell` | A recess inside a panel. One step down, never up. |
| `Eyebrow` | The small uppercase label naming a value. |
| `StatusPill` | A dot and a word. Colour and text, never colour alone. |

### Composites — `components.dart`

| Component | Use |
| --- | --- |
| `SectionHeader` | 20px title with an optional trailing action. |
| `InsightCard` | The AI advice card: decision, reasoning, optional remedy and "Why?". |
| `StatTile` | Eyebrow / value / caption. The unit of every analytics row. |
| `SearchField` | Filled, sits on the canvas above a list. |
| `FilterChipRow` | Horizontally scrolling single-select. Scrolls rather than wraps, so the list below never shifts. |
| `TimelineEntry` | Rail-and-node wrapper that makes a list of dates read as a schedule. |
| `WeatherGlassCard` | The one content-bearing glass surface. Weather screen only. |
| `CropImage` | Image slot: tries `.jpg`, then `.jpeg`, then a painted emoji plate. See `assets/crops/README.md`. |
| `IllustrationBanner` | Art plus title plus message, as a band. |

### Readouts — `gauges.dart`

| Component | Use |
| --- | --- |
| `SoilScale` | Converts the raw probe reading to wetness. **The probe reads higher when drier** — every gauge routes through here so the inversion exists in exactly one place. |
| `MoistureGauge` | The hero: a 270° arc, a tick at the irrigation threshold, the reading in the middle. Pulses only when `pumpStatus` says water is actually moving. |
| `ScoreRing` | Crop suitability, model confidence. A ring answers "out of what" before the number is read. |
| `MeterBar` | The flat cousin, with an optional threshold mark. |

### Loading — `skeleton.dart`

`Shimmer` hosts one ticker and one `ShaderMask` for a whole group, so twelve
placeholder rows cost one animation rather than twelve — and they sweep in
phase, which reads as one surface loading rather than as noise.
`SkeletonBox` / `SkeletonLine` / `SkeletonCircle` are the shapes;
`HeroCardSkeleton`, `ListSkeleton` and `ChartSkeleton` are the compositions,
each matched to the real content's height so nothing reflows when data lands.

A spinner says "something is happening". A skeleton says "a reading is about to
appear *here*". On a dashboard the second is the useful message.

### Motion — `motion.dart`

`Haptics` names taps by meaning, not strength — `commandSent()` is the heaviest
because those are the taps that move water; `selection()` is a tick.
`FadeSlideIn` staggers a screen's sections into reading order (60ms per step,
capped at 420ms). `AnimatedCount` for figures that change meaningfully and
infrequently — deliberately *not* the live soil reading, which the farmer would
then have to wait to read. `PressableScale` shrinks a whole card on press,
because Material's ripple mostly happens out of sight under the finger on a
large rounded panel.

### Illustrations — `illustrations.dart`

Eight painted pieces: `soilSensor`, `irrigation`, `weather`, `aiScan`,
`cropGrowth`, `calendar`, `farmScene`, `offline`.

**Painted rather than imported** (Storyset / unDraw / Lottie were the obvious
route and were deliberately not taken):

- **They cannot follow the theme.** A flat SVG or Lottie ships its own palette.
  In dark mode it either glows white or disappears, and the usual fix — two
  copies of every asset — doubles the set and still misses the accent colours,
  which here carry meaning.
- **They cannot be tinted by state.** The diagnose hero is green while idle and
  amber while scanning; the empty-tasks art picks up whichever accent the
  screen is already using.
- **Weight and licence.** This is an offline-first field app. Eight painters are
  a few kilobytes of Dart with no attribution obligations and no `lottie`
  runtime, against roughly a megabyte of JSON and images.

Each is authored in a normalised 100×100 square and scaled once, so one piece
reads correctly at 52px inside a card and at 168px as a screen hero.

### Screen frame — `screen_chrome.dart`

`GlassScaffold` supplies the ambient canvas, the floating glass header, an
optional `TabBar`, and — importantly — the `contentPadding` its builder
receives. Callers never compute insets themselves; that is how content reliably
clears both the header and the navigation bar without each screen guessing at a
magic number.

`Section` groups panels under an eyebrow. `EmptyState` takes a `FarmArt` rather
than an icon: an empty Tasks screen showing a calendar is instantly placeable,
where the same screen showing a grey circle could be an error, a permission
prompt or a network failure. Every empty state names what would fill it and,
where one exists, offers the action that does.

---

## Widget hierarchy

```
SmartFarmApp
└── MaterialApp  ·  AppTheme.light / .dark  ·  fade-through page transitions
    └── HomeShell
        └── AmbientBackground                    gradient + colour fields
            └── Scaffold (extendBody)
                ├── IndexedStack                 all five tabs kept alive
                │   ├── DashboardScreen
                │   ├── WeatherScreen
                │   ├── CropsScreen
                │   ├── DiagnoseScreen
                │   └── TasksScreen
                └── _GlassNavBar                 blurred
                    ├── FieldActionNote          (Farm tab only)
                    ├── FieldActionBar           (Farm tab only) — the pump
                    └── NavigationBar            5 destinations
```

The pump lives in the navigation bar rather than on the dashboard because it is
the one control a farmer reaches for one-handed while standing in a field — and
because two ways to start the same pump on one screen raises the question of
which one the controller actually heard.

---

## Screen designs

### 1 · Farm dashboard — `dashboard_screen.dart`

```
┌──────────────────────────────────────────┐
│ Good morning            [💬]  [⚙]        │  FarmHeader — glass, blurred
│ Kwame's Farm                             │
├──────────────────────────────────────────┤
│ ☀ 31°C · Kumasi           ● All good     │  ConditionsStrip — on canvas
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │            SOIL MOISTURE             │ │  HeroFieldCard — raised
│ │              ╭───────╮               │ │
│ │            ╭─┤  62   ├─╮             │ │  MoistureGauge, 270° arc
│ │            │ │% moist│ │             │ │  tick = irrigation threshold
│ │            ╰─┤raw 1556├╯             │ │
│ │              ╰───────╯               │ │
│ │  PUMP           │       MODE         │ │
│ │  ● Idle         │   [Auto ][Manual]  │ │
│ └──────────────────────────────────────┘ │
│ ┌──────────────────────────────────────┐ │
│ │ [💧] FARM INSIGHT                    │ │  InsightCard — tinted
│ │      Hold irrigation                 │ │
│ │ 8 mm of rain is coming in 4 hours —  │ │
│ │ that saves about 800 litres.  [Why?] │ │
│ └──────────────────────────────────────┘ │
│ ┌────────────────┐ ┌───────────────────┐ │
│ │ ✓ All clear    │ │ ✓ 2 tasks today   │ │  FieldLinkTiles
│ └────────────────┘ └───────────────────┘ │
│                                          │
│ Conditions                               │  SectionHeader
│ ┌────────┬─────────┬─────────┐           │
│ │ SOIL   │ AIR     │ RAIN    │           │  ReadingsRow
│ └────────┴─────────┴─────────┘           │
│                                          │
│ Analytics                                │
│ [ soil moisture · 24h/3d/7d chart      ] │  MoistureChartCard
│ [ water used · 340 L today · meter     ] │  WaterUsageCard
│ [ temperature · 24h sparkline          ] │  TemperatureTrendCard
├──────────────────────────────────────────┤
│      [ Water now ]              [ ⚙ ]    │  FieldActionBar — thumb zone
│  Farm  Weather  Crops  Diagnose  Tasks   │  glass nav
└──────────────────────────────────────────┘
```

Reads top to bottom as one answer to "what is happening and do I need to act":
who and where → the reading → the decision → what needs you → the record.

### 2 · Weather — `weather_screen.dart`

Apple-Weather structure over a **dynamic sky gradient** (`SkyBackdrop`) tinted
by condition and time of day — which is also what makes the glass cards work,
since a blur over flat colour is just grey.

```
        ☁  (sky gradient, condition-tinted)
┌──────────────────────────────────────────┐
│           📍 Kumasi                      │
│              ⛅                          │  WeatherGlassCard
│              31°                         │
│          Partly cloudy                   │
│   Feels  Humidity  Wind   Rain now       │
│    33°     74%    9km/h   0.0mm          │
└──────────────────────────────────────────┘
  What this means for the farm
┌────────────────────┐┌────────────────────┐
│ 💧 IRRIGATION      ││ ☂ RAIN             │  2×2 signal grid
│ Hold off           ││ 12 mm              │  fixed order, always 4
│ 12 mm expected...  ││ Heavy rain likely  │
└────────────────────┘└────────────────────┘
┌────────────────────┐┌────────────────────┐
│ 🦠 DISEASE RISK    ││ 🧴 SPRAY WINDOW    │
│ High               ││ Postpone           │
└────────────────────┘└────────────────────┘
  [ controller handoff: what was sent to the ESP32 ]
  Next 24 hours   → horizontal hourly strip
  Seven days      → day rows on one shared temperature scale
```

The four cards are **always present and always in the same order**, so their
positions become learnable — a farmer checking whether to spray looks
bottom-right without reading the other three. A card that vanishes in fine
conditions is a card whose absence is ambiguous.

The thresholds behind them live in
[`logic/weather_advice.dart`](../lib/logic/weather_advice.dart), extracted from
the widget and covered by `test/weather_advice_test.dart`.

### 3 · Crops — `crops_screen.dart`

A catalogue, not a list.

```
  [ Scored against your conditions: soil / avg high / rain ]
  [ 🔍 Search crops                                       ]
  ( All )( Cereal )( Fruit )( Leafy vegetable )( Legume )…   scrolling filters
  Best matches right now                        September
┌──────────────────────────────────────────┐
│ ┌────┐  Tomato                     ╭───╮ │
│ │ 🍅 │  Excellent match            │ 86│ │  CropImage + ScoreRing
│ └────┘  Soil moisture suits it now ╰───╯ │
│  📅 Plant now   💧 High water         ›  │
└──────────────────────────────────────────┘
```

Search and filters exist because fourteen crops is enough that "where is
cassava" becomes a scroll rather than a glance. The score ring sits on the
*right* so the eye lands on the crop's name first.

**My Crops** tab: progress meter to harvest, current growth stage as a pill,
and what that stage asks for in a well.

### 4 · Diagnose — `diagnose_screen.dart`

Three states and no more: **ready → scanning → result**.

```
 READY                          SCANNING
┌──────────────────────┐   ┌──────────────────────┐
│    ┌ ─   🍃   ─ ┐    │   │ ┌─          ─┐       │
│      (aiScan art)    │   │ │  [ photo ]  │      │  ScanFrame — the
│    └ ─        ─ ┘    │   │ │ ══════════ │      │  farmer's own photo
│ Photograph a leaf    │   │ └─          ─┘       │  under a moving line
│ [ 📷 Take a photo  ] │   │   Analysing leaf     │
│ [ 🖼 From gallery   ] │   │ Reading · Matching · │  ScanStages
└──────────────────────┘   └──────────────────────┘
  [ Getting a good result — 5 tips ]
  [ 🔒 Photos never leave this phone ]
```

The scanning state gets a real animation rather than a spinner because
inference takes a second or two on a mid-range phone, and a spinner over that
duration reads as a stall. Showing the farmer's *own* photograph confirms the
model is looking at the right leaf, and makes a blurred shot obvious while
there is still time to retake it.

**Result screen** order is the design: photo (did it look at the right leaf?) →
verdict with a confidence ring → organic treatment → chemical treatment →
prevention → runners-up. Organic before chemical, because the cheaper and safer
option should be read first. Confidence gets a ring rather than a thin bar — it
is the number that decides whether the farmer acts on the rest of the screen.

### 5 · Tasks — `tasks_screen.dart`

```
  [Mo][Tu][We][Th][Fr][Sa][Su]…   CalendarStrip — 14 days, load dots
   28  29  30  31   1   2   3
        ●●      ●
  Overdue                              2
  ┃  ┌────────────────────────────────┐
  ●  │ [💧] Water at flowering  2d late│   TimelineEntry — filled node
  ┃  │ 🍅 Tomato · Field A · Flowering │
  ┃  └────────────────────────────────┘
  ●  │ …                              │
```

Two views of one list: no day selected shows everything bucketed by urgency
(the question a farmer opens with is "what is late and what is today"); tapping
a day filters to it. Fourteen days rather than a month grid, because
agronomically generated tasks cluster within days of each other and a month
view would be mostly empty cells.

---

## Responsive behaviour

The app is phone-first and portrait-first, which is what a farmer is holding.

- Every panel is width-fluid; nothing has a fixed pixel width except the
  fixed-size readouts (gauge, rings, day cells).
- Horizontal overflow is confined to deliberate scrollers: `FilterChipRow`,
  `CalendarStrip`, the hourly weather strip. Everything else wraps or
  ellipsises.
- Text that can grow — crop names, alert summaries, task titles — carries
  `maxLines` plus `TextOverflow.ellipsis`, so a long name cannot push a score
  ring off screen.
- `GlassScaffold` derives content padding from `MediaQuery` insets, so notches,
  gesture bars and the nav bar are handled once rather than per screen.
- `IntrinsicHeight` on the weather signal grid and the timeline keeps
  side-by-side cards equal height when one has more text.

Not yet done: a tablet or landscape layout. The two-column grids would want to
become three or four, and the dashboard would want the hero and analytics
side by side. Nothing in the token layer blocks that.

---

## Accessibility

- **Contrast.** Every ink and text-accent value is checked at 4.5:1 or better
  against its surface. See the brand-versus-ink table above.
- **Colour is never alone.** See rule 3.
- **Reduce motion.** `Shimmer`, `FadeSlideIn` and the diagnose scan line all
  check `MediaQuery.disableAnimations` and render statically.
- **High contrast.** `GlassSurface` and `WeatherGlassCard` fall back to opaque
  surfaces. Nothing depends on the blur being present to be usable.
- **Targets.** Buttons are 52dp minimum; the pump control and its mode button
  are 52dp square.
- **Semantics.** `MoistureGauge` and `ScoreRing` carry labels describing the
  value in words, because an arc's meaning is carried by colour and length,
  neither of which reaches a screen reader. The gauge's label describes the
  pump's *actual* state, never the requested one.

---

## Suggested packages

Deliberately **not added** — everything above is built from Flutter's SDK plus
the six packages already in `pubspec.yaml`. Each of these is what you would
reach for if a constraint changed:

| Package | What it would replace | Why it was not used |
| --- | --- | --- |
| `google_fonts` | The bundled font | Downloads at first paint. Fatal for an offline field app. |
| `lottie` | `illustrations.dart` | ~1 MB of runtime plus JSON that cannot follow the theme or be tinted by state. |
| `flutter_svg` | `illustrations.dart` | Same theming problem; would need two copies of every asset. |
| `shimmer` | `skeleton.dart` | One `ShaderMask` and one ticker is ~90 lines and shares a single animation across a group. |
| `flutter_animate` | `motion.dart` | Convenient, but the four motions this app needs are already tokenised. |
| `hugeicons` / `lucide_icons` | `Icons.*_rounded` | Material Symbols Rounded ship with Flutter at zero cost and zero risk. |
| `cached_network_image` | — | Would matter only if crop photography were fetched rather than bundled. |
| `dynamic_color` | The hand-picked palettes | Material You would let the OS repaint "dry soil". Not acceptable when colour is a data channel. |

Adding any of them is a defensible call — but each trades away something the
current build has, and the trade should be deliberate.

---

## Enforced invariants

Cheap to check, worth checking, because each one degrades silently if it
drifts:

```bash
# Glass surfaces: nav bar, GlassScaffold header, dashboard header,
# assistant composer, farm-setup action bar. All chrome, none carrying a
# reading. WeatherGlassCard is the one documented exception and is separate.
grep -rn "GlassSurface(" lib/ --include=*.dart | grep -v theme/glass.dart

# No raw Material Card — data belongs on Panel.
grep -rn "\bCard(" lib/ --include=*.dart | grep -v CardTheme

# No screen builds its own AppBar.
grep -rln "appBar: AppBar(" lib/screens/

# No hard-coded palette colours.
grep -rn "Colors\.\(blue\|grey\|green\|red\|orange\|amber\|teal\)" \
  lib/screens/ lib/widgets/

# No baseline Material icons — rounded and outlined families only.
grep -rno "Icons\.[a-z_0-9]*" lib/ --include=*.dart \
  | grep -v "_rounded\|_outlined"
```

All return clean as of this redesign, except the last, which returns
`nightlight_round` and `foggy` — neither has a `_rounded` variant, and both are
already Material Symbols shapes.

---

## Status

On the design system: the shell, navigation, dashboard, Weather, Crops, Crop
Detail, Diagnose, Diagnosis Result, Tasks, Settings, Alerts, Add Planting,
Assistant and Farm Setup. `flutter analyze` is clean; 131 tests pass.

Not yet done, in rough priority order:

- **Nothing has been seen running.** The work is verified by analyzer and tests
  only — no device or emulator was available in this environment. The light
  theme especially needs eyes on it.
- **Crop photography.** Maize has a photograph; the other thirteen crops fall
  back to painted emoji plates. See `assets/crops/README.md` — a partly-filled
  set reads as unfinished, so this is worth completing or reverting rather
  than leaving half done.
- **Widget tests for the chrome.** `GlassScaffold`'s inset arithmetic is the
  kind of thing that breaks quietly when someone adds a header row.
- **Tablet and landscape layouts.** See Responsive above.
- **The seeded name.** `SettingsService.defaultFarmerName` is `'Fredrick'` so
  this build greets its owner out of the box. It is device-local and editable
  under Settings › You, but the default must become `''` before the app
  reaches anyone else — an empty name falls back to greeting the farm.
