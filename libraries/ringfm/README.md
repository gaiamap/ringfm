# ringfm

Text measurement in pure Ring: real font metrics read straight from a TrueType file, with
wrapping, and a built-in estimate as a fallback when no font can be read. No C extension,
no external tool — one `.ring` file that also runs as a command line utility.

## Install

```
ringpm install ringfm
```

Requires **Ring 1.20** or later. No package dependencies: the library needs only
`stdlibcore.ring`, which ships with Ring.

## Quick start

```ring
load "ringfm.ring"

aResult = fm_measure("Hello, Ring!", "arial", 14, 0, ["widths", "info"])

? "" + aResult[:widths][1] + " px, measured from " + aResult[:info][:path]
```

## API

```ring
aResult = fm_measure(ctext, cfont, nsize, nmaxwidth, awant)
```

| argument | meaning |
|---|---|
| `ctext` | the text to measure; newlines in it always split it into lines |
| `cfont` | a path to a `.ttf` or `.ttc` file, or one of the family names this library knows (`arial`, `times`, `courier`, `helvetica`), looked up in the usual places on Windows, macOS and Linux. A name that is not found is substituted, and the substitution is reported |
| `nsize` | the point size the text will be set at |
| `nmaxwidth` | the width to wrap at, in pixels; zero means no wrapping, and the text is split on its own newlines only |
| `awant` | the parts to build: `"lines"`, `"widths"`, `"stats"`, `"info"` |

Pass `null` for any argument to take its global default.

The result is a list with one key per part asked for:

| key | contents |
|---|---|
| `:lines` | the text as laid out, one entry per line, wrapping included |
| `:widths` | the width in pixels of each of those lines, in the same order; an empty line measures zero |
| `:stats` | the same numbers as a report to read, with every line listed |
| `:info` | `[:font]` the family actually read, `[:path]` the file it came from, `[:measured]` false when the widths are the built-in estimate rather than real metrics, `[:substituted]` true when the font asked for was not found, `[:warnings]` |

The two flags in `:info` answer different questions: the widths can be the real metrics of a
font other than the one asked for, and one flag could not tell that case.

The library prints nothing and writes no file. Warnings go to `[:info][:warnings]` and the
caller decides whether to show them.

## Command line

```
ring <ringfolder>/libraries/ringfm/ringfm.ring "Hello World!" arial 14 200
```

It writes `fm_lines.txt`, `fm_widths.txt` and, when `$fmstats` is on, `fm_stats.txt` into
the current folder. Run it with no arguments for the usage screen and the current defaults.

## Defaults

`$fmtext`, `$fmfont`, `$fmsize`, `$fmmaxwidth` and `$fmstats` hold the defaults used when an
argument is left out. The other `$fm` globals hold the state of the font currently loaded.

## How the widths are obtained

The font file is read directly: the table directory, then `head` for the design grid, `hhea`
and `hmtx` for the advance widths, `cmap` format 4 to turn characters into glyph numbers, and
`name` for the family. A character's width is its advance in font units scaled by
`size / unitsPerEm`. When no font can be read the widths come from `fm_approxadvance`, a table
of typical proportions: good enough for layout, not exact — and `[:info][:measured]` says
which of the two the caller got.

## Samples

`samples/UsingRingFM/` — `fm_basic.ring`, `fm_wrap.ring`, `fm_fontfile.ring`,
`fm_stats.ring`.

## The test suite, and what it is for

The suite is installed with the library, in the same folder, and it is meant to be read as
much as run: it is the longest worked example of this library there is. The samples show one
call each; the suite shows every way the library can be driven, and states in each assertion
what the result is supposed to be.

Run it exactly like this — from the library's own folder, because its command line mode
starts `ringfm.ring` from the current directory:

```
cd <ringfolder>/libraries/ringfm
ring test_ringfm.ring
```

91 assertions. Expected output ends with `ALL TESTS PASSED (91/91)`. Everything written
goes into a single `test_fm/` subfolder beside it, which can be deleted afterwards.

### The modes, which are the point

Each mode is a different way of putting the library to work. Read the source of the one that
matches what you are trying to do.

| section | what it demonstrates |
|---|---|
| `MODE 1` | CLI (system + disk I/O) — the library file run as a program from another program, its output read back off disk |
| `MODE 2` | Library (load + direct API) — the ordinary way: `load` it and call `fm_measure` directly |
| `MODE 2R` | Repeated use, substituted font and composition — several calls in one process, what the globals carry between them, and what the two flags say when the font asked for is not the one measured |
| `MODE 3A` | Sandbox CLI/Disk (isolated subprocess) — a driver program written on the fly, run in a subprocess, its files collected afterwards |
| `MODE 3B` | Sandbox In-Memory (ring_state_* API) — a second Ring interpreter created inside the first with `ring_state_init`, the library loaded into it and called there, nothing touching the disk |

Modes 3A and 3B are worth reading even if you never need them: they show how a Ring program
can run another Ring program — as a subprocess, or as a second interpreter inside itself —
and how to get results back from either.

### One dependency, and it is not the library's

The suite calls `md5()` from the OpenSSL extension for its cumulative checksum. A standard
Ring installation provides it through `bin/load/openssllib.ring`. The library itself needs no
extension at all: if the suite will not start but the library does, this is why.

## License

MIT License — Copyright (c) 2026 Gaiamap.
