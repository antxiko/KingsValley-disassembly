# The cartridge

**King's Valley**, Konami, 1985. Cartridge **RC-727**, 16,384 bytes, mapped
into the MSX's page 1 (0x4000-0x7FFF).

```
sha256  a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73
```

## The header

The first ten bytes of the dump are:

```
41 42 6C 40 00 00 00 00 00 00
```

`41 42` is the `AB` marker the BIOS looks for to know a cartridge is there. The
next two are the address of **INIT**, little-endian: `6C 40` = **0x406C**. The
rest — `STATEMENT`, `DEVICE`, `TEXT` — is zero: the cartridge declares only
INIT, and everything else hangs off that.

## How it boots

`arranca_el_juego` (0x406C) does four things and no more:

1. Hooks the interrupt **by hand**: writes a 0xC3 (`jp`) into `H.KEYI`
   (0xFD9A) and the address 0x401A behind it. It uses no BIOS hook; it builds
   the instruction byte by byte.
2. Puts the stack at 0xE700.
3. Clears 0xE000-0xE6FF with an `ldir`.
4. Calls `prepara_pantalla` and **falls into an empty loop**.

From there the whole game runs **inside the interrupt**. The main loop does not
exist: it is a `jr` to itself. It is the same pattern the Sky Jaguar and
Konami's Golf disassemblies already document for this same family of Konami
cartridges, so it is not a fresh reading but terminology already validated in
two other projects.

## How the 16 KB break down

```
traced code         9,803 bytes    59.83 %
declared data       6,581 bytes    40.17 %
unexplained                 0       0.00 %
```

The 6,581 bytes of data are not "what was left over": they are 117 blocks
declared one by one in `kingsvalley.notes` with a `D` directive saying what
they are, and an `F` giving the width of their structure — a word, seven bytes,
two bytes per entry. That is the series' rule: every table separated and named.

## The VDP registers

`tabla_registros_vdp` (0x45C0) is eight raw bytes, R0 to R7:

```
02 E2 0E 7F 07 76 03 E4
```

- **R0 = 0x02** — SCREEN 2.
- **R1 = 0xE2** — 16 KB, display on, interrupt enabled, and **16×16 sprites**.
- **R2 = 0x0E** — name table at 0x0E × 0x400 = **0x3800**.
- **R3 = 0x7F**, **R4 = 0x07** — this is where the surprise is; see
  [Findings](FINDINGS.html). In SCREEN 2 they are not addresses but base plus
  mask, and what they say is **colour at 0x0000 and patterns at 0x2000**, the
  other way round from usual.
- **R5 = 0x76** — sprite attributes at 0x3B00.
- **R6 = 0x03** — sprite patterns at 0x1800.
- **R7 = 0xE4** — border and background colours.

## The VRAM map

With those registers, the 16 KB of VRAM look like this:

```
0x0000 - 0x17FF   COLOUR table       (768 tiles x 8 bytes, three thirds)
0x1800 - 0x1FFF   SPRITE patterns    (64 sprites of 16x16)
0x2000 - 0x37FF   PATTERN table      (768 tiles x 8 bytes, three thirds)
0x3800 - 0x3AFF   NAME table         (768 cells, 24 rows x 32)
0x3B00 - 0x3B7F   SPRITE attributes  (32 entries Y/X/pattern/colour)
```

The name table ends exactly at 0x3AFF and the attribute table starts at 0x3B00,
back to back. That was checked in the emulator in an earlier batch, by dumping
both regions at once.

## The RAM map

The game uses 0xE000 up into 0xF000-something. The busiest parts:

```
0xE000  active task index               0xE003  frame counter
0xE004  task counter                    0xE009  this frame's input
0xE010  PSG sound engine block          0xE049  score, in BCD
0xE043  high score, in BCD              0xE050  round counter
0xE054  room number                     0xE0B0  sprite buffer (32 x 4)
0xE134  the explorer's record           0xE14E  enemy descriptors
0xE164  how many enemies                0xE16A  the enemies (22 B each)
0xE1C5  7-byte entities                 0xE1F5  9-byte entities
0xE264  17-byte entities                0xE2CC  another 9-byte list
0xE31E  blocks that open (7 B)          0xE3FF  traps (9 B)
0xE700  the room buffer, 96-byte row stride
```

## Konami's hidden mark

Konami hid the catalogue number and the title in katakana at the end of many of
its cartridges. **Manuel Pazos**
([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)) found it, and he should
be credited.

This cartridge **has it**, ending exactly at 0x7FFF:

```
RC-727    O U   KE   NO   TA   NI
```

`OU KE NO TA NI` is **王家の谷**, the game's Japanese title: the *Valley of the
Kings*.

The search is done with `tools/busca_marca_konami.py`, which scans all 16,384
positions, not just the end: there are cartridges in this family where the mark
is not where you expect, and taking a negative on faith without sweeping the
whole ROM is the easy way to get it wrong.

## The two script interpreters

Almost everything the cartridge draws is compressed as **scripts** for one of
two different interpreters. They must not be confused, because the same bytes
read with the other one give noise:

- **`dibuja_guion` (0x451A)** — the graphics one. One command byte: the count
  is its low seven bits, and bit 7 decides between copying that many bytes
  verbatim or repeating the next byte that many times. `0x00` ends and `0x80`
  chains by reading a fresh VRAM address.
- **`escribe_guion_de_texto` (0x4051)** — the text one. It starts with a word
  that is the VRAM address, then single characters, `0xFE` changes address and
  carries on, and `0xFF` ends.

One stretch of ROM can serve both: 0x47FE is a graphics script that writes
letters into the name table, and 0x480E — sixteen bytes further on, inside the
same stretch — is a text script that starts halfway and shares the tail.
