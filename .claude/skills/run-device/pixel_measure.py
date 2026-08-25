#!/usr/bin/env python3
"""Measure a screenshot against a design — colours, spacing, element extents.

Answers "is that button actually 44pt and is that blue actually #1D4AAB" with a
number, for a device capture (`adb exec-out screencap -p`) compared against a
Figma render (`dart run .claude/skills/figma-screen/figma_fetch.dart image <node-id>`).

Runs on a bare `python3` with no `pip install` — the PNG reader is hand-rolled
on stdlib `zlib`, because this is a Dart repo and requiring a Python
environment just to look at a screenshot is not a reasonable ask. Reads 8-bit
non-interlaced PNG, which is what both of those sources produce; anything else
raises rather than silently misreading.

Coordinates go in and come out in LOGICAL pixels. Pass `--scale` — the device
pixel ratio for a capture (`adb shell wm density` / 160), the export multiplier
for a Figma render — and a 1080-wide phone screenshot at `--scale 3` compares
directly against a 786-wide 2x export at `--scale 2`.

  .claude/skills/run-device/pixel_measure.py info    <png>
  .claude/skills/run-device/pixel_measure.py bands   <png> --scale N [--x0 L --x1 L] [--thresh 140]
  .claude/skills/run-device/pixel_measure.py sample  <png> --scale N --at X,Y [--at X,Y ...]
  .claude/skills/run-device/pixel_measure.py bbox    <png> --scale N [--y0 L --y1 L] [--dark]
  .claude/skills/run-device/pixel_measure.py profile <a.png> <b.png> --scale-a N --scale-b N [--x L]

Two things worth knowing before you trust a number it gives you:

* Colour is exact. Tokens should match to the byte, so treat any delta as a
  real finding. A uniform ratio across all three channels means something is
  compositing over your colour, and that ratio is its alpha.
* Ink extents are not layout. Where glyphs land is a fact about the text
  rasteriser, and Flutter and Figma size text boxes differently — comparing
  gaps between text rows invents 3-5pt of drift that isn't there. For anything
  positional, read `absoluteBoundingBox` out of the node JSON that
  `figma_fetch.dart` writes to docs/redesign/figma/ and compare against the
  constants in the widget. Use this tool for colour, gradients and extents.
"""

import argparse
import struct
import sys
import zlib

_CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}


class Img:
    """Decoded PNG. Pixels stay as a flat bytearray; tuples are built on demand.

    The naive shape (a list of lists of tuples) allocates one tuple per pixel —
    several million for a phone screenshot — and dominates the runtime. Scans
    below read luminance straight out of the buffer instead.
    """

    __slots__ = ('w', 'h', 'buf', 'nch', 'stride', 'pal')

    def __init__(self, w, h, buf, nch, pal):
        self.w, self.h, self.buf, self.nch, self.pal = w, h, buf, nch, pal
        self.stride = w * nch

    def rgb(self, x, y):
        o = y * self.stride + x * self.nch
        b = self.buf
        if self.pal is not None:
            i = b[o] * 3
            return (self.pal[i], self.pal[i + 1], self.pal[i + 2])
        if self.nch <= 2:
            v = b[o]
            return (v, v, v)
        return (b[o], b[o + 1], b[o + 2])

    def lum(self, x, y):
        o = y * self.stride + x * self.nch
        b = self.buf
        if self.pal is not None:
            i = b[o] * 3
            return 0.299 * self.pal[i] + 0.587 * self.pal[i + 1] + 0.114 * self.pal[i + 2]
        if self.nch <= 2:
            return float(b[o])
        return 0.299 * b[o] + 0.587 * b[o + 1] + 0.114 * b[o + 2]


def load(path):
    data = open(path, 'rb').read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError('%s is not a PNG' % path)
    pos, idat, pal = 8, [], None
    w = h = ctype = None
    while pos < len(data):
        (ln,) = struct.unpack('>I', data[pos:pos + 4])
        typ = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', body)
            if depth != 8:
                raise ValueError('%s: %d-bit PNG, only 8-bit supported' % (path, depth))
            if interlace:
                raise ValueError('%s: interlaced PNG not supported' % path)
        elif typ == b'PLTE':
            pal = body
        elif typ == b'IDAT':
            idat.append(body)
        elif typ == b'IEND':
            break
        pos += 12 + ln
    raw = zlib.decompress(b''.join(idat))
    nch = _CHANNELS[ctype]
    stride = w * nch
    out = bytearray(stride * h)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]
        p += 1
        line = bytearray(raw[p:p + stride])
        p += stride
        if f == 1:
            for i in range(nch, stride):
                line[i] = (line[i] + line[i - nch]) & 255
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(nch):
                line[i] = (line[i] + (prev[i] >> 1)) & 255
            for i in range(nch, stride):
                line[i] = (line[i] + ((line[i - nch] + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(nch):
                line[i] = (line[i] + prev[i]) & 255
            for i in range(nch, stride):
                a, b, c = line[i - nch], prev[i], prev[i - nch]
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        elif f != 0:
            raise ValueError('%s: bad filter %d on row %d' % (path, f, y))
        out[y * stride:(y + 1) * stride] = line
        prev = line
    return Img(w, h, out, nch, pal if ctype == 3 else None)


def hexc(c):
    return '#%02X%02X%02X' % c


def find_bands(img, y0, y1, x0, x1, thresh, minpx=3, joingap=3):
    """Row ranges containing >= minpx pixels darker than `thresh`."""
    rows = [y for y in range(y0, y1)
            if sum(1 for x in range(x0, x1) if img.lum(x, y) < thresh) >= minpx]
    out = []
    for y in rows:
        if out and y - out[-1][1] <= joingap:
            out[-1][1] = y
        else:
            out.append([y, y])
    return out


def darkest(img, y0, y1, x0, x1):
    best, got = 1e9, None
    for y in range(y0, y1 + 1):
        for x in range(x0, x1):
            v = img.lum(x, y)
            if v < best:
                best, got = v, img.rgb(x, y)
    return got


def find_bbox(img, y0, y1, bright):
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(img.w):
            v = img.lum(x, y)
            if (v > 247) if bright else (v < 60):
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def _span(a, s):
    return '%.1f' % (a / s)


def cmd_info(a):
    img = load(a.png)
    print('%s  %dx%d px  %d channels%s' % (a.png, img.w, img.h, img.nch,
                                           '  (palette)' if img.pal else ''))


def cmd_bands(a):
    img = load(a.png)
    s = a.scale
    x0 = int(a.x0 * s) if a.x0 is not None else int(img.w * 0.1)
    x1 = int(a.x1 * s) if a.x1 is not None else int(img.w * 0.9)
    print('bands in x %.1f-%.1f logical, luminance < %d' % (x0 / s, x1 / s, a.thresh))
    for b in find_bands(img, 0, img.h, x0, x1, a.thresh):
        c = darkest(img, b[0], b[1], x0, x1)
        print('  y %7s - %-7s  height %6s  darkest %s'
              % (_span(b[0], s), _span(b[1], s), _span(b[1] - b[0] + 1, s), hexc(c)))


def cmd_sample(a):
    img = load(a.png)
    s = a.scale
    for pt in a.at:
        x, y = (float(v) for v in pt.split(','))
        px_, py = int(x * s), int(y * s)
        if not (0 <= px_ < img.w and 0 <= py < img.h):
            print('  %8s  out of bounds' % pt)
            continue
        print('  %8s  %s' % (pt, hexc(img.rgb(px_, py))))


def cmd_bbox(a):
    img = load(a.png)
    s = a.scale
    y0 = int(a.y0 * s) if a.y0 is not None else 0
    y1 = int(a.y1 * s) if a.y1 is not None else img.h
    box = find_bbox(img, y0, y1, bright=not a.dark)
    if box is None:
        print('  nothing matched')
        return
    x0, by0, x1, by1 = box
    print('  x %s - %s  (width %s)' % (_span(x0, s), _span(x1, s), _span(x1 - x0 + 1, s)))
    print('  y %s - %s  (height %s)' % (_span(by0, s), _span(by1, s), _span(by1 - by0 + 1, s)))
    print('  centre x %s   (frame centre %s)' % (_span((x0 + x1) / 2, s), _span(img.w / 2, s)))


def cmd_profile(a):
    ia, ib = load(a.a), load(a.b)
    sa, sb = a.scale_a, a.scale_b
    xa, xb = int(a.x * sa), int(a.x * sb)
    top = a.to if a.to is not None else int(min(ia.h / sa, ib.h / sb))
    print('vertical colour profile at logical x=%.0f' % a.x)
    print('%8s  %-9s %-9s  %s' % ('y', a.a.split('/')[-1], a.b.split('/')[-1], 'delta'))
    worst = 0
    for y in range(0, top + 1, a.step):
        ya, yb = int(y * sa), int(y * sb)
        if ya >= ia.h or yb >= ib.h:
            break
        ca, cb = ia.rgb(xa, ya), ib.rgb(xb, yb)
        d = max(abs(m - n) for m, n in zip(ca, cb))
        worst = max(worst, d)
        print('%8d  %-9s %-9s  %s' % (y, hexc(ca), hexc(cb), d if d else ''))
    print('worst delta %d/255' % worst)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)

    q = sub.add_parser('info', help='dimensions and colour type')
    q.add_argument('png')
    q.set_defaults(fn=cmd_info)

    q = sub.add_parser('bands', help='find horizontal text/ink bands')
    q.add_argument('png')
    q.add_argument('--scale', type=float, required=True)
    q.add_argument('--x0', type=float, help='logical left bound of the scan')
    q.add_argument('--x1', type=float, help='logical right bound of the scan')
    q.add_argument('--thresh', type=float, default=140)
    q.set_defaults(fn=cmd_bands)

    q = sub.add_parser('sample', help='colour at logical points')
    q.add_argument('png')
    q.add_argument('--scale', type=float, required=True)
    q.add_argument('--at', action='append', required=True, metavar='X,Y')
    q.set_defaults(fn=cmd_sample)

    q = sub.add_parser('bbox', help='bounding box of bright (default) or dark pixels')
    q.add_argument('png')
    q.add_argument('--scale', type=float, required=True)
    q.add_argument('--y0', type=float)
    q.add_argument('--y1', type=float)
    q.add_argument('--dark', action='store_true', help='match dark pixels instead')
    q.set_defaults(fn=cmd_bbox)

    q = sub.add_parser('profile', help='compare two images down a vertical line')
    q.add_argument('a')
    q.add_argument('b')
    q.add_argument('--scale-a', type=float, required=True, dest='scale_a')
    q.add_argument('--scale-b', type=float, required=True, dest='scale_b')
    q.add_argument('--x', type=float, default=8, help='logical x to sample down')
    q.add_argument('--to', type=int, help='logical y to stop at')
    q.add_argument('--step', type=int, default=20)
    q.set_defaults(fn=cmd_profile)

    a = p.parse_args()
    try:
        a.fn(a)
    except (ValueError, FileNotFoundError) as e:
        print('error: %s' % e, file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
