---
name: run-device
description: Run and inspect the app on the connected Android device — screenshot it, drive it, read its logs. Use when asked to check something on the phone, verify a screen renders correctly, or reproduce a bug on a real device.
argument-hint: '[optional: what to look at, e.g. "the login screen"]'
---

# Run on the device

Build, launch, observe, and drive the app on a physically connected Android
device. Use this to confirm a change renders correctly in the real app, not
just that it compiles.

This skill holds **procedure only — never coordinates, never expected pixel
values.** Layouts change; anything restated here would go stale silently.
Always read positions off a fresh screenshot.

## Prerequisites

```bash
adb devices -l
```

- **No device** → stop and ask the user to connect the phone over USB with USB
  debugging enabled. Do not fall back to an emulator, the macOS target, or
  Chrome unless the user asks — the point of this skill is the real device.
- **`unauthorized`** → stop; the user must accept the RSA prompt on the phone.
- **More than one device** → pass `-s <serial>` on every `adb` call and
  `-d <serial>` to `flutter run`.

The app is `com.axon.ftmobile.pro`. That is `applicationId` **plus** the
`applicationIdSuffix` the debug build type adds — grepping `applicationId`
alone in `android/app/build.gradle.kts` gives you the wrong package.

## Getting the app running

Check what is already on screen before building anything:

```bash
adb shell dumpsys window displays | grep mCurrentFocus
```

**If you only need to look at the current state**, and the installed build
already contains the code you care about, work with what is running. A build
takes minutes; a screenshot takes a second.

**If you need your own changes on the device**, launch it yourself as a
background process so you own hot reload:

```bash
flutter run --flavor prod --target lib/main_prod.dart --pid-file /tmp/ft-run.pid
```

Then, after each edit:

```bash
kill -USR1 $(cat /tmp/ft-run.pid)   # hot reload
kill -USR2 $(cat /tmp/ft-run.pid)   # hot restart — needed for main(), DI, routes
```

The pid file appears once the signal handlers are hooked; wait for it to exist
before signalling. Signals are the only reliable path here — a background shell
has no writable stdin, so the interactive `r` / `R` keys are not available.

`.env` must exist at the repo root or the app will not start. See `CLAUDE.md`.

## Seeing the screen

```bash
adb exec-out screencap -p > shot.png
sips -Z 900 shot.png --out shot_small.png
```

Read the **downscaled** copy as an image. A raw capture is a multi-megabyte
full-resolution PNG and re-reading it every iteration is pure waste.

Write both into the session scratchpad, never into the repo. Number them per
iteration (`shot-01`, `shot-02`) so you can compare before and after a fix
rather than overwriting your own evidence.

If a capture catches a transition mid-animation, take another one. Do not
insert shell `sleep` calls to wait for the UI to settle.

## Driving the screen

Flutter paints to a single canvas, so `uiautomator dump` returns nothing
usable. There is no element tree to query — **every interaction is
coordinate-based, read off a screenshot you just took.**

The loop is: screenshot → locate the target → act → screenshot again.

```bash
adb shell input tap <x> <y>
adb shell input swipe <x1> <y1> <x2> <y2> <ms>   # scroll; longer ms = slower
adb shell input text 'hello%sworld'              # %s for spaces
adb shell input keyevent 4                       # back  (66 enter, 111 escape)
```

`input` coordinates are **physical pixels**, the same space as the full-size
capture. If you measured on the downscaled copy, scale back up by the ratio
first — `sips -Z 900` on a tall screen leaves the long side at 900, so the
factor is the original height over 900. Getting this wrong lands every tap
high and left of where you meant.

Never take coordinates from the Figma design. Only from the device.

## Reading logs

```bash
adb logcat -c                                       # clear, then reproduce
adb logcat -d -s flutter:V AndroidRuntime:E         # dump what happened
```

Flutter framework errors, `RenderFlex` overflow warnings, and failed asset
loads all surface under the `flutter` tag. Overflow warnings are worth grepping
for after any layout change — they are invisible in a screenshot on some
screens and are exactly the kind of drift this skill exists to catch.

## The login gate

Login is **Google OAuth only**. If a screenshot shows the Log In screen, stop
and ask the user to sign in on the device. You cannot complete the OAuth flow —
tapping the button opens a system account chooser you have no way to resolve,
and retrying just accumulates dismissed dialogs.

This is a one-time ask: the token is persisted, so the session survives hot
restarts and reinstalls of the same build. Guest mode bypasses
`AuthenticationGuard` entirely if the screen you need is reachable that way.

## Comparing against Figma

When verifying a redesigned screen, compare **content against content** — the
chrome on each side belongs to its medium, not to the design:

- The device capture carries a `DEBUG` banner, the real Android status bar, and
  the system navigation bar. None of these are drift.
- Figma frames carry their own mockup status bar and home indicator. See
  `figma-screen`; those are not implemented deliberately.

Check the logical size before comparing distances:

```bash
adb shell wm size && adb shell wm density
```

The current device reports 1080×2400 at 480 dpi — density 480 is a device pixel
ratio of 3, so 360×800 logical pixels. If the Figma frame is 360 wide, logical
distances map 1:1 and you can compare spacing directly. If it is any other
width, compare **proportions and token values**, not pixel measurements.

### Measure it, don't eyeball it

Two screenshots side by side will not tell you whether a 44pt button is 44pt.
Use `.claude/skills/run-device/pixel_measure.py` — a repo dev tool, not agent-private; keep it
working for the humans who also run it. Everything is in and out in **logical**
pixels: pass `--scale` (the device pixel ratio for a capture, the export
multiplier for a Figma render) and the two become directly comparable.

```bash
M=.claude/skills/run-device/pixel_measure.py
python3 $M info    shot-01.png
python3 $M bands   shot-01.png --scale 3 --x0 33 --x1 327   # text rows + colour
python3 $M bbox    shot-01.png --scale 3 --y0 50 --y1 233   # logo/icon extents
python3 $M sample  shot-01.png --scale 3 --at 180,400
python3 $M profile shot-01.png <figma>.png --scale-a 3 --scale-b 2 --x 6
```

`bands` reports the darkest colour per row group, which is how you check text
colour without knowing where the glyphs are. `profile` walks a vertical line
down both images and prints the per-channel delta — the way to check a gradient.

**Colour is where the render is authoritative, and it is exact.** Tokens should
match to the byte. Treat anything above ~4/255 as a real finding and chase it;
a uniform ratio across all three channels means something is compositing over
your colour, and the ratio is its alpha.

**Ink extents are not layout.** Where glyphs land in a render is a fact about
the text rasteriser, not about the design — Flutter and Figma size text boxes
differently, so measuring gaps between text tops will show 3–5pt of phantom
drift that does not exist. For anything positional, read intent from the node
JSON instead:

```bash
python3 -c "import json; d=json.load(open('docs/redesign/figma/<node>.json'))"
# walk `absoluteBoundingBox` on each child
```

Those are canvas-absolute, so subtract the frame's own `x`/`y` to get
frame-relative values, then compare against the constants in the widget. That
turns "about right" into "56 and 56". Reserve the render for colour, gradients,
blurs, and anything else the JSON cannot express.

**Compare positions relative to the safe area, not the frame top.** The Figma
frame's status bar is a fixed mockup height; the device's is whatever that
handset has. A gap specified below the status bar only matches if you measure
it from the real inset.

Report what you find. Do not silently fix drift mid-inspection — finish
looking, then decide what to change, then re-verify with a fresh screenshot
after a hot reload.

## Rules

- Screenshots and recordings live in the scratchpad. Never commit them.
- **Never `adb uninstall` or `pm clear` without asking.** It destroys the login
  session the user signed in for, and only they can restore it.
- Do not leave a `flutter run` alive when you finish. Kill it and say so.
- Do not switch to an emulator or the macOS/Chrome target because the device is
  inconvenient. Say the device is unavailable and stop.
- Reaching for `uiautomator`, Appium, or an accessibility dump on this app is a
  dead end — see above.
