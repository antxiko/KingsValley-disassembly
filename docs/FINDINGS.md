# Findings

What turned up when the cartridge was taken apart, with the evidence for each.

## The colour table sits underneath the pattern table

In SCREEN 2 the usual layout puts patterns at 0x0000 and colours at 0x2000.
This cartridge does it **the other way round**, and that is not visible in any
address in the code: it is visible in the registers.

`tabla_registros_vdp` (0x45C0) holds `02 E2 0E 7F 07 76 03 E4`. In SCREEN 2
registers 3 and 4 are **not an address**: they are base plus mask.

- **R3 = 0x7F** — its bit 7 is **clear**, so the colour table goes to 0x0000.
  The low seven bits are a mask, and at 0x7F they restrict nothing.
- **R4 = 0x07** — its bit 2 is **set**, so the pattern table goes to 0x2000.
  The low two bits, at 3, restrict nothing either.

The code itself settles it beyond doubt: `prepara_scroll_del_logo` (0x4823)
draws the wordmark with `ld hl,06300h`, and 0x6300 masked to fourteen bits —
which is what SETWRT does — is **0x2300**, inside the pattern table. Two
instructions further down it fills at 0x0300, inside the colour table.

Reading it the usual way has a characteristic symptom: the **shapes come out
right** and the **colours come out striped**.

## The explorer moves in twenty-four bits

X is not one byte, nor two: it is three. `avanza_posicion_24_bits` (0x73F6)
adds the velocity with `add hl,de` over 0xE138/0xE139 and carries into 0xE13A
with `adc a,c`.

The lowest byte is the **fraction**, in 1/256 of a pixel, and the top two are
exactly the ones `lee_celda_de_sala` takes as the whole-pixel X when it looks
up a cell. The two uses fit without adjusting anything.

It needs that much X because **the room is wider than the screen**: even-
numbered rooms are 48 columns, 384 pixels, which will not fit in a byte. When
the explorer walks off the side, `sale_por_el_lateral` (0x4BBC) sends him to
task 9, which does `ld (0e139h),bc` with the low X at 0xF0 or 0x04 — the
opposite edge — and the high byte changed by one: a **256-pixel** jump, one
whole screen.

Three independent routines agree on the same format without copying the figure
from one another.

## Eighty-seven bytes of code that looked like data

Five entity loops do `ld hl,<closer>` and `push hl` before dispatching, so that
the `ret` of the dispatched routine **does not return to the caller**: it falls
into the closer, which bumps the index and goes round again.

A static tracer cannot follow that, because the address travels through the
stack as if it were data. That is why 87 bytes were showing as "unidentified"
in the budget, and why that budget had been failing since the start of the
project.

All five have the same shape — `ld hl,<index>` / `inc (hl)` / `cp (hl)` /
`jp nz,<body>` — and the body they jump to is exactly the label that pushed
them. Declared in the `.entries`, the budget closes at zero.

## Two routines nobody calls, and one of them tells you something

- **0x4501**, nineteen bytes, decode as another variant of drawing a script
  across the three thirds, this one with the counter in the alternate register
  set.
- **0x4542**, ten bytes, are the counterpart of `prepara_escritura_vdp` **for
  READING** VRAM: it calls SETRD (BIOS 0x0050) and takes the read port from
  system variable 0x0007, just as the other takes the write port from 0x0006.

Neither is called, and that is not an impression: the byte pairs **01 45** and
**42 45** appear nowhere in the 16,384, checked byte by byte in both possible
orders.

The second one says something about the design of the game: **this cartridge
never reads VRAM back**. It writes and forgets. All the state lives in RAM,
including a complete copy of the room.

## Six entity lists, six different strides

Six parallel tables, each with its own accessor, and the size of an entry does
not have to be guessed: it is in the multiplication. 0x6A12 does i, 3i, 7i with
B carrying the powers of two; 0x65A5 reaches 9i; 0x5AF6 joins the chain halfway
and reaches 17i; 0x73D3 does 2i, 6i, 22i.

The stride-7 and stride-9 lists share an index: they are two blocks of fields
of the **same** entity, split across two areas of memory.

## Sprite flicker is shared out on purpose

`actualiza_tabla_de_sprites` (0x4B75) always writes the same four sprites into
the attribute table, but each frame it starts from a different one of a
four-entry ring at 0xE0C8, rotated by a counter at 0xE061.

It is not decoration. On the MSX1 only **four sprites per scanline** are shown
and the lowest-numbered ones win; rotating the write order means the one that
drops out changes every frame, so all four flicker evenly instead of the same
one always vanishing. It fits with 0x4364 parking exactly ten sprites from that
same address.

## The stone changes colour every four rooms

The rooms came out black on black when first drawn, until we found who sets the
colour of the wall and floor tiles. It is not `prepara_sala_nueva`, which loads
their patterns: it is `columna_decorativa` (0x6DA0), and the script it uses
depends on the **group of four levels** — 0x6DC4 plus 9 per group, with the
group taken from `(level-1) >> 2` and clamped to 3.

That is why the first four rooms are ochre stone and the next ones change
colour with the **same brick artwork**: the only thing that changes is eight
bytes of colour on tiles 0x40 to 0x44.

## The text is ASCII minus 0x20

The labels are not in ASCII, nor in a private font with a lookup table: they
are ASCII **shifted down by 0x20**. The bytes `2B 2F 2E 21 2D 29` plus 0x20
give `4B 4F 4E 41 4D 49` = **KONAMI**, and the same sum gives SCORE, HI, REST,
PUSH SPACE KEY, PLAY START, GAME OVER, SOFTWARE and PYRAMID. 0x00 is the space
and 0x1A the copyright sign.

Since the characters are written straight into the name table, **each letter's
tile index is its own code**.

## One stretch of ROM serving two interpreters

0x47FE is a **graphics** script (called by `dibuja_guion_con_direccion`) that
writes a decorative bar and the word SOFTWARE into the name table, and ends at
the 0x00 at 0x480D.

0x480E — right behind it — is a **text** script that writes the copyright and
the word PYRAMID. But 0x480E also falls *inside* the stretch the first one
would cover if read differently. Two different languages sharing adjacent
bytes, and reading one with the other's interpreter gives recognisable noise:
drawing the title screen produced bands of KKKK and NNNN until they were told
apart.

## The main loop does not exist

`arranca_el_juego` (0x406C) hooks the interrupt by writing a `jp` by hand into
0xFD9A, clears the working RAM, sets up the screen and **falls into an empty
loop**. The whole game runs inside the interrupt.

This is not a fresh reading: it is the same pattern the Sky Jaguar and Konami's
Golf disassemblies already document for this family of cartridges.

## It does carry Konami's hidden mark

Konami hid its catalogue number and the title in katakana at the end of many
cartridges; **Manuel Pazos**
([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)) found it.

This one has it, ending at 0x7FFF:

```
RC-727    O U   KE   NO   TA   NI
```

**OU KE NO TA NI** is 王家の谷, the game's Japanese title: the *Valley of the
Kings*.
