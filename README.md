# King's Valley — a commented disassembly

A complete, commented disassembly of **King's Valley** (Konami, 1985), the
16 KB **RC-727** cartridge for the MSX1.

📖 **[Read the site](https://antxiko.github.io/KingsValley-disassembly/)** ·
🇪🇸 [En castellano](README.es.md)

```
100.00 %  of the binary explained          0  bytes unidentified
   9,803  bytes of traced code           651  named routines
   6,581  bytes of declared data        45.5 %  of the listing commented
```

Reassembling the listing gives back the ROM **byte for byte**:
`a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73`.

## The ROM is not here

This repository does not distribute the cartridge image. Put your own copy in
the root as `kingsvalley.rom` and check it with:

```sh
shasum -a 256 kingsvalley.rom
```

## Build it

```sh
make            # listing + verify + sanity + tests
make verify     # reassemble and compare against the ROM, byte for byte
make sanity     # the four checks reassembling does not cover
make densidad   # how much of the listing is commented
make web        # the bilingual site in docs/
```

## What turned up

- **The colour table sits underneath the pattern table.** R3=0x7F and R4=0x07
  are not addresses in SCREEN 2 — they are base plus mask — and what they say
  is colour at 0x0000, patterns at 0x2000, the other way round from usual.
- **The explorer moves in twenty-four bits**: a fractional byte in 1/256 of a
  pixel plus two whole-pixel bytes, because the even-numbered rooms are 48
  columns wide and will not fit in one.
- **Eighty-seven bytes of code that looked like data**: five entity loops push
  their own closer so the dispatched routine's `ret` falls into it. No static
  tracer can follow that.
- **Two routines nobody calls**, and one of them is the VRAM *read* helper —
  which tells you this cartridge never reads VRAM back.
- **Sprite flicker is shared out on purpose**, by rotating which of four ring
  entries gets written first each frame.
- **The stone changes colour every four rooms**, from eight bytes written by a
  routine that had nothing to do with loading the room.
- **It does carry Konami's hidden mark** (found by
  [Manuel Pazos](https://twitter.com/ManuelPazosMSX)): `RC-727` and
  `OU KE NO TA NI` — 王家の谷, the Valley of the Kings.

Full detail on the site, under
[Findings](https://antxiko.github.io/KingsValley-disassembly/FINDINGS.html).

## Every picture is drawn from the ROM

Not one emulator capture. `tools/pantallas.py` runs the cartridge's own two
script interpreters over a 16 KB VRAM image in Python, then reveals it as
SCREEN 2 — the title screen, all fifteen pyramids with their real brick
graphics, the sprite sheet and the menu screens.

## Layout

```
src/kingsvalley.notes     what has been understood: names, comments, data blocks
src/kingsvalley.entries   entry points static tracing cannot deduce
src/kingsvalley.nocode    regions the tracer must not read as code
src/kingsvalley.asm       GENERATED — never edited by hand
tools/                    tracer, listing builder, checks, renderers, openMSX scripts
docs/                     the bilingual site
```

## Licence

The tools, the comments and the analysis are MIT (see [LICENSE](LICENSE)). The
game itself is not: see [LEGAL-NOTICE.md](LEGAL-NOTICE.md). This is
preservation, study and documentation work.
