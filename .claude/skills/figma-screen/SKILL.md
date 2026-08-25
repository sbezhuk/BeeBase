---
name: figma-screen
description: Implement a screen from the FT Design Figma file against the new design system. Requires a Figma node link or node id as argument.
disable-model-invocation: true
arguments: [figma-node]
argument-hint: '<Figma node link or node id, e.g. 259-4727>'
---

# Implement a Figma screen

Build the screen at `$ARGUMENTS` using the new design system under
`lib/presentation/design_system/`.

This skill holds **procedure and project rules only — never token values.**
Colours, type, and spacing live in code and change over time; anything restated
here would go stale silently and get followed with confidence. Always read the
token files.

## Prerequisites

If `$ARGUMENTS` is empty, stop and ask for a Figma node link or id.

File key: `AmUyG0SdHzI74BhYlXQq91` (FT Design). Screens live on the `Drafts`
page; the design system lives on `• Design system` (`17:2`).

**Read the design over REST, not over MCP.** The seat is a View seat on a
Professional plan — 6 MCP tool calls *per month*. Routine screen reading must
not touch that budget; use `.claude/skills/figma-screen/figma_fetch.dart`, which goes over the REST
API on a separate, far larger quota:

```bash
export FIGMA_TOKEN=$(cat ~/.figma_token)   # or: set -a; . ./.env.figma; set +a
dart run .claude/skills/figma-screen/figma_fetch.dart node  <node-id>   # tree → docs/redesign/figma/
dart run .claude/skills/figma-screen/figma_fetch.dart image <node-id>   # render, for reading intent
dart run .claude/skills/figma-screen/figma_fetch.dart images 'id=a.svg,id=b.svg'   # many assets, ONE call
```

Icons usually should not come from Figma at all — see **Icons** below.

⚠️ **Never loop `image` to export a screen's icons — use `images`.** The
`/v1/images` render endpoint is rate limited *per request* and far harder than
the node endpoint. Exporting twelve icons one at a time exhausted the render
quota for **over eleven hours** during the Profile migration and left that
screen unable to render; the same twelve in one `images` call cost one request.

⚠️ **A 429 can take `node` down with it.** The budget is per token across the
whole REST API, not per endpoint — on 2026-08-15 the Profile Edit migration
found `/v1/files/…/nodes` returning 429 with `retry-after: 71536` (~20 h), with
no way to read *any* screen until it cleared. Do not assume, as this skill
previously said, that node fetches survive a blocked render quota.

**Read `retry-after` before deciding anything.** `figma_fetch.dart` prints it as
a wall-clock reset time on every failure that carries it. It separates "wait a
few minutes" from "this is tomorrow's problem, find another way in" — and only
the second one justifies spending MCP budget or asking for a hand export.

### Icons — try Lucide first, Figma only for the rest

**Most glyphs in FT Design are stock [Lucide][lucide], and Figma is the wrong
place to get those.** Pull them from source: it needs no token, costs no render
quota, and gives the same vector.

```bash
dart run .claude/skills/figma-screen/lucide_fetch.dart \
  list-checks user-plus log-out fishing-rod trash-2=trash square-pen=edit
```

- The Figma layer name is usually the Lucide name — read it off the node tree.
- Lucide renames glyphs over time and Figma may carry the old one: `user-circle`
  is now `circle-user`, `edit` is now `square-pen`. On a 404, check
  <https://lucide.dev/icons>.
- `=<our-name>` renames on the way in. **Asset names follow the design's
  vocabulary, not upstream's** — `trash-2=trash`, `square-pen=edit`. The
  left-hand side keeps provenance so a re-fetch is exact.

#### Lucide is the app's icon set — keep it that way

The Figma file is not consistent about this. The Profile frame alone reaches for
`tabler-icon-fish-hook` (**Tabler**) and `marker-pin-01` (**Untitled UI**). The
app should not inherit that: mixed sets read as mismatched stroke weights and
optical sizing sitting side by side in the same list.

**There is no Tabler or Untitled UI in the codebase, and none should be added.**
When the design reaches outside Lucide:

1. **Look for a faithful Lucide equivalent.** Lucide is 1768 icons and covers
   more than its Figma-side naming suggests — the Tabler fish hook became
   Lucide's `fishing-rod` this way, which also removed a blocked Figma export.
2. **Record the substitution in the ledger**, under the screen. Swapping a glyph
   the design specified is a design decision; the designer confirms it.
3. **If nothing faithful exists, export from Figma and flag it as an exception.**
   Do not force a poor match — a wrong glyph is worse than a second icon set,
   and this skill otherwise treats the design file as authoritative. Keep
   exceptions countable: a growing list is the signal to fix Figma rather than
   keep absorbing it.

Anything genuinely custom (the FT wordmark) is not an exception to this — it is
simply not an icon-set question, and comes from `figma_fetch.dart images`.

The durable fix is upstream, in the Figma file. Until then every screen makes
this call on its own and the app drifts from the design a little at a time — see
"Figma cleanup" in the ledger.

Icons are **SVG assets, not an icon font**: a `String` path on `AppAssets`,
rendered with `flutter_svg`, tinted at the call site with a `ColorFilter`. Do not
add `lucide_icons_flutter` or a similar package — the reasoning, and what it
would cost, is recorded under "Icon sources" in `docs/redesign/MIGRATION.md`.

Lucide is MIT. Its SVGs are a 24 grid at `stroke-width="2"`, so a glyph drawn at
20 renders its strokes at ~1.67 — if a design adjusts stroke weight, compare on
device.

[lucide]: https://lucide.dev/icons

### What REST gives you, and the one thing it does not

REST is the source of truth for *values*, and is equal or better than MCP on
all of them — raw `absoluteBoundingBox`, unrounded fills and effects, exact
`fontSize` / `lineHeightPx` / `letterSpacing`. The `/v1/images` endpoint is
Figma's own rasteriser, so asset exports are byte-identical to MCP's.

**Style names come back too.** The node response carries a top-level `styles`
dictionary resolving style ids to names — `"20:461" → "Title 2 (28)/SemiBold"`,
`"258:3209" → "Neutral/Black 950"`. Typography is fully checkable this way.

**Variables are the gap.** They come back as opaque ids only —
`{"type":"VARIABLE_ALIAS","id":"VariableID:126:392"}`. Resolving those to names
(`Main colours/Main 300`) needs `/v1/files/:key/variables/local`, which is
Enterprise-only. So map colours back through `palette.dart` **by value** —
every ramp step is there. A colour that matches no primitive is a finding, not
something to round off.

### Spending the MCP budget

The 6 calls reset monthly. Spend them on **validating the naming we inferred**,
never on reading a screen REST can read:

- `get_variable_defs` on a node whose bindings are unresolved returns the names
  for every variable that node uses. One call covers a whole screen — the Log In
  screen, for instance, binds only 5 distinct variables.
- **Record every resolved name the moment you get it**, as the `// figma:`
  annotation on the matching constant in `palette.dart`. A call spent twice on
  the same node is a call wasted.
- Prefer the free route when someone with edit access is available: a Figma
  plugin running `figma.variables.getLocalVariablesAsync()` dumps every variable
  on any plan, which is the `docs/redesign/ft.tokens.json` export the drift
  check wants. That retires this budget problem outright.

## Steps

1. **Load the general Figma skill first.** Invoke `figma:figma-design-to-code`
   and follow it for the mechanics of reading the design. This skill layers
   project specifics on top; it does not replace it.

2. **Read the token layer before writing anything:**
   - `design_system/token/app_colors.dart` — semantic roles, the only colour API
   - `design_system/token/app_typography.dart` — the type ramp
   - `design_system/token/palette.dart` — primitives; read for context, never
     reference from a screen

3. **Read the ledger** at `docs/redesign/MIGRATION.md` to see which design
   system components already exist. Reuse before building. The single most
   common failure on this project is inventing a second Button.

4. **Map every bound variable to a semantic role.** What the design binds is a
   primitive (`Main colours/Main 300`, or over REST the hex it resolves to);
   screens must not consume those. Find or add the semantic role that expresses
   the *intent*.

5. **Source the icons early** — see **Icons** above. Walk the node tree's
   `INSTANCE` names, split them into Lucide and not-Lucide, fetch the Lucide
   ones with `lucide_fetch.dart`, and batch whatever is left into a single
   `figma_fetch.dart images` call. Do this *before* implementing: a missing
   asset is not a compile error, so `flutter analyze` stays clean and the screen
   fails only when you finally run it.

6. **Implement**, following the rules below.

7. **Update the ledger**: screen status, and any component you added.

8. **Verify**: `flutter analyze` must be clean, then format **only the files you
   touched, at 120 columns**:

   ```bash
   dart format --line-length 120 <the files you changed>
   ```

   Do **not** run bare `dart format .`. The repo is formatted at 120 columns but
   nothing on disk records that — `analysis_options.yaml` has no `formatter:`
   block, and its `include:` of `package:flutter_lints/flutter.yaml` fails to
   resolve unless `flutter pub get` has been run, so `dart format` silently
   falls back to its 80-column default and rewrites ~400 files. Recovering that
   means reverting everything you did not mean to touch.

9. **Look at it on the device.** Analyze proves it compiles, not that it
   matches. Confirm every icon actually drew — a missing or `foreignObject` SVG
   renders as a blank or a flat blob, and nothing upstream of this catches it. Use the `run-device` skill to screenshot the built screen and
   compare it against the Figma render. Ignore the chrome on both sides — the
   `DEBUG` banner and system bars on the device, the mockup status bar and home
   indicator in Figma.

## Rules

**Design system**
- Screens and components read `context.colors.*` and `AppTypography.*`. Never a
  raw `Color(0x…)`, never a raw `TextStyle(`, never `Palette.*` outside
  `app_colors.dart`.
- If a screen needs a style the design system lacks, **add it to the design
  system** — a new semantic role, or a new component. Never inline it. Inlining
  is how the previous design system ended up with one colour token serving five
  different roles across 494 call sites.
- Add semantic roles only when a design calls for one. No speculative roles.
- New components go in `design_system/component/`, built from tokens only.
- Assets are named from `AppAssets`, never the frozen `AppImage`, and live under
  `assets/design_system/`. **Flutter's `assets:` entries are not recursive** — a
  new subdirectory needs its own line in `pubspec.yaml` (`assets/design_system/`
  does *not* cover `assets/design_system/icon/`). A missing entry fails at
  runtime, not at analyze.
- An icon and the label beside it are one unit and share a colour, so a menu-row
  style component should tint both from a single text role rather than carrying
  a parallel `icon*` role. Add `icon*` roles only for glyphs with no label —
  `iconBrand` exists for the wordmark and the edit affordance.

**Comments — no Figma references in code**
- Doc comments and inline comments must not mention Figma: no node ids, no
  "Figma calls this `category`", no "Figma draws 305 where this uses 297". A
  reader of the code cannot open the file to check any of it, and the design
  keeps moving — frames get redrawn and renumbered, and the comment goes stale
  with nothing to catch it.

  ```dart
  // ❌ /// A one-off composition rather than a design system component: Figma
  //     /// draws it as a plain frame on this screen (`346:5757`), not as a
  //     /// reusable component.
  // ✅ /// A one-off composition for this screen, not a design system component.
  ```

- Say what the code does and why, in the code's own terms. Most of these
  comments survive the edit intact — the design provenance is the part that adds
  nothing to someone reading the widget.
- Where a **deviation from the design** is genuinely worth recording, it belongs
  in `docs/redesign/MIGRATION.md` under the screen, where a designer will look
  and where it can be resolved. Not in a `///` comment nobody will revisit.
- **The one exception is `palette.dart`.** Its `// figma:` annotations are
  provenance for a primitive's source variable, and this skill depends on them:
  they are how a name resolved with MCP budget stops being resolved twice. Keep
  that form, keep it to the token layer.

**Frozen code — do not touch**
- `lib/presentation/component/` and `lib/presentation/widgets/` are the old
  design system. No new work there, no edits, no deletions until nothing
  imports them. They are what keeps unmigrated screens rendering.
- Do not modify `AppColor`, `AppFont`, or `AppTextStyles`.
- Migrating a screen means pointing it at the new system, not editing the old.

**Project conventions** (see `CLAUDE.md` for the full set)
- `package:ft_mobile/...` imports only — `always_use_package_imports` is enforced.
- `prefer_single_quotes`, `require_trailing_commas`, `prefer_const_constructors`.
  `unused_import`, `dead_code`, and `invalid_assignment` are **errors**.
- `snake_case` files, `PascalCase` classes, target ≤200 lines per file.
- Dimensions come from `context.spacing` / `context.appSize` / `context.appRadius`
  — these are the older extensions and are still current. Only colour and type
  are being replaced.
- Pages implement `AutoRouteWrapper` and provide their cubit in `wrappedRoute`.
  Provide a cubit in exactly one place.
- State is a `sealed class`; cubits emit via a private emitter mixin. Copy the
  pattern from a similar existing feature rather than inventing one.
- After editing routes or models, regenerate:
  `flutter pub run build_runner build --delete-conflicting-outputs`

**Localisation**
- User-facing strings go through `'some.dotted.key'.tr()` against
  `assets/langs/en-US.json`. Pick the key nested under the screen you are on.
- **There is no localisation codegen step to run.** Nothing imports `LocaleKeys`
  or `CodegenLoader` and `lib/generated/` does not exist — keys are only ever
  used as raw dotted strings, so adding one needs nothing but the JSON edit.
  `flutter pub run easy_localization:generate` fails with "Source path does not
  exist" (it defaults to `resources/langs`, not `assets/langs`) and is a no-op
  for this project either way.
- Keep the JSON's **4-space indentation**. Rewriting the file with a JSON
  library at a different indent turns a 5-line change into a 1000-line diff.

## Known design-file inconsistencies

Carry these in mind; they are unresolved in Figma and will mislead you:

- The Typography page is labelled **DM Sans**, but every bound text variable is
  **Noto Sans**. The variables are correct.
- Duplicate colour collections exist — `Neutral/White 50`, `Neutral colours/
  Neutral 50`, and `Neutral/Neutral 50 (White)` are all the same value.
- `Main/Shade 600` comes from a second `Main` collection and does not sit on the
  `Main colours` ramp. It is mapped in `palette.dart` as an explicit outlier.
- Frame names are stale: the ramp labelled **MAIN** sits in a frame named
  `complementary`; the ramp labelled **ACCENT** sits in one named `primary`.
- Figma defines two different things called `Title 1` — a Noto Sans 36 text
  style and a Shippori Mincho 32 display style.
- Shippori Mincho is not bundled; its two display styles are unimplemented. See
  the note in `app_typography.dart` before using them.
- Some icons are drawn with **conic gradients** (the Google mark,
  `Icons/Logo/Google`). Figma exports those as CSS `conic-gradient` inside
  `foreignObject` elements, which `flutter_svg` cannot render — the result
  silently collapses to a single flat fill. Check any exported SVG for
  `foreignObject` before using it; if present, export a 4× PNG instead.
- Design frames carry an Android status bar and home indicator. Those belong to
  the mockup, not the screen — do not implement them; `SafeArea` covers it.
- **The top app bar's ground is `#FFFBFB`, which is on no ramp.** It is a bound
  variable, but from an *external library* collection (its id is prefixed
  `9219e3f6…/18823:137`, unlike the local `VariableID:126:389` style), so REST
  cannot name it. `Neutral 50` is `#FBFBFF` — the same three channels with R and
  B transposed, so this is almost certainly a typo in the library. Migrated
  screens paint the bar from `surface` (`#FBFBFF`); the two differ by 4/255 in
  two channels and are indistinguishable on device. Confirm with a designer and
  fix it in Figma rather than adding a primitive for it.
- Design frames may show a **bottom nav bar belonging to the New IA**
  (Feed / Locations / Record / Explore / Profile) even on screens that are not
  themselves blocked on that question. The nav bar is the tab shell's, not the
  screen's — implement the screen, leave the shell to `main/main_page`.

If you hit a *new* inconsistency, record it here rather than working around it
silently.
