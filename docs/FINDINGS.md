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
numbered rooms are 64 columns, 512 pixels, which will not fit in a byte. When
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

Manuel Pazos marked the same two stretches as unused code in 2009, working
independently. Two readings sixteen years apart landing on the same two
addresses is about as good as this kind of evidence gets.

## Six entity lists, and what each of them is

Six parallel tables, each with its own accessor, and the size of an entry does
not have to be guessed: it is in the multiplication. 0x6A12 does i, 3i, 7i with
B carrying the powers of two; 0x65A5 reaches 9i; 0x5AF6 joins the chain halfway
and reaches 17i; 0x73D3 does 2i, 6i, 22i.

Reading the level descriptor byte by byte says what each one holds:

| stride | list | what it is |
|---|---|---|
| 7 | 0xE1C4 | the four **exit doors** of the pyramid |
| 7 | 0xE31E | the **revolving doors** |
| 9 | 0xE1F3 | the **jewels**, one byte of which is the colour |
| 9 | 0xE3FF | the **trap walls** |
| 17 | 0xE264 | the **knives already thrown**, up to four |
| 22 | 0xE16A | the **mummies** |

An earlier version of this page said the stride-7 and stride-9 lists were "two
blocks of fields of the same entity" because they share an index. They are not:
they are the doors and the jewels, and what they share is one counter variable,
`ElemEnProceso`, because the same loop walks both.

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

## The cartridge defends itself, twice

Two routines write into the cartridge's own address space. Running from ROM
neither of them does anything, and it is tempting to file them as dead code.
They are not: they are **copy protection**, and the fact that they do nothing
is the whole point. A pirated cartridge is a copy loaded into RAM — and in RAM
the writes land.

- **0x403E** copies the byte `0xE1` (`pop hl`) over the first byte of task 1
  and a `0xC9` (`ret`) behind it. In RAM, the title screen's task is destroyed.
  It runs 92 times in two minutes of play, measured with a breakpoint; the
  target byte never changes.
- **0x409C** writes DE over **0x43C0**, which is not data: it is the operand of
  the `jp nc,cierra_aviso_titulo` at 0x43BF. In RAM, drawing the title jumps
  wherever DE happened to point.

**Manuel Pazos** identified both in his 2009 disassembly
([GuillianSeed/Kings-Valley](https://github.com/GuillianSeed/Kings-Valley)),
as `ReadKeys_AC` and `VRAM_writeAC`. This project had 0x403E written up as a
failed patch and 0x409C as a fill address, and both were wrong.

## This is the first version, and there is a second

The cartridge exists in two builds. At **0x5817** ours has
`fe 31 28 18 fe 21 28 04 fe 22 20 04` — the three separate `cp` comparisons
that the second version replaces with two subtractions — and the second
version's signature `e6 f0 fe 30 e1 c8 34 3e 04 be` appears nowhere in the
16,384 bytes.

So what is disassembled here is **version 1**, bugs included. Pazos lists what
version 2 fixes: throwing a knife while the exit door is opening corrupts the
door's tiles; throwing it while standing against an object passes straight
through the object; a trap wall that hits an object erases it instead of
stopping, because the code decrements the fractional X instead of the Y; and
two trap walls, in pyramids 10 and 12, sit in the wrong place.

## Every room is twice as wide as its band list looks

`carga_la_sala` unpacks the room from a list of band bytes, and stops at the
band whose high nibble is 3. The trap is at **0x6B0E**: the `pop de` there
restores the pointer to the band that has *just* been unpacked, so the `cp 030h`
two instructions later tests **that** band, not the next one. The 0x3x band is
drawn **and** ends the list.

Read the other way round it loses one band per room. The real widths are
**32 columns for the odd rooms and 64 for the even ones** — one screen and two
screens — not 16 and 48 as this project published.

The fix is not an opinion: the room buffer this project now computes was
compared against the RAM of a real machine for all fifteen pyramids, **31,680
cells with no difference at all**, and then the drawn screens were compared
against that machine's VRAM — name table, pattern table, colour table and
sprite pattern table — with **zero differences** as well.

## The figures facing the other way are not in the cartridge

There is one drawing of the explorer and one of the mummy, both facing right.
The mirrored versions are **manufactured at run time**: 0x4584 reverses the
eight bits of a byte, 0x458F applies that to one byte of VRAM, and two loops on
top of it flip whole figures — ten sprites of the explorer to pattern 0x60 and
three of the mummy to pattern 0x88.

Mirroring a 16x16 sprite is not just reversing its bytes: its two halves have to
be swapped as well, and that is what the odd little dance at 0x4556-0x455C does
— write sixteen bytes, step back sixteen, repeat while bit 4 of E is clear.

The same trick flips fifteen *tiles*, 0x68 to 0x76 into 0x77 to 0x85: the exit
door, the lever and the ladders that lean the other way.

## The valley is a ring, not a ladder

Each of the four door slots in a level descriptor carries the number of the
pyramid it leads to. Laid out, the fifteen pyramids form a **closed loop**:
1 to 2 to 3 ... to 15 and back to 1. Every pyramid but the first has a door
back the way you came.

And it does not reset when you finish. Each mummy's type is its descriptor byte
**plus the number of times the game has been completed**, clamped at 4. The
five types differ in speed and colour, from the white one at speed 5 to the
dark yellow one at speed 11. Finish the game four times and every mummy in the
valley is the fastest kind.

## A jump into the middle of an instruction

At 0x4F0C there is a `jr z,$+3`. Three bytes ahead is not an instruction
boundary: it is the **second byte** of the `cp 020h` at 0x4F0E, and that 0x20
on its own decodes as `jr nz`. Since the jump only happens with Z set, the
`jr nz` it lands on never fires, and the effect is to skip the comparison.

It reassembles byte for byte either way. It is worth pointing at because a
disassembler that insists on instruction boundaries will quietly get this one
wrong.

## The map's parchment is white because of the title screen

The valley map is a parchment with fifteen pyramids on it. Its interior is
tile 0x01, and the reason it looks white is a colour byte written by the
**title screen** — the script at 0x47A7, which fills the colour of tile 0x01
with 0xFF. Nothing writes there again for the rest of the game.

So the map screen cannot be reconstructed on its own: drawn on a clean VRAM
the parchment comes out black. That is exactly how it was published here until
it was compared against the machine.

The same comparison caught a second one. **The title screen and the Konami
logo are two different screens.** Task 0 scrolls the Konami wordmark up; task 1
erases it, along with the word SOFTWARE, and paints KING'S VALLEY on top —
twenty-two steps, one per column, two consecutive patterns each from 0x9B on,
plus the foot of the G, which drops one row further. This project had the two
confused, and the site carried the Konami logo where the game's should be.

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

## A note on where some of this came from

**Manuel Pazos** published a fully annotated disassembly of this cartridge in
2009: [GuillianSeed/Kings-Valley](https://github.com/GuillianSeed/Kings-Valley).
The two copy protections, the existence of a second build, the names of the
game's pieces — mummy, jewel, pickaxe, knife, lever, revolving door, trap wall —
and the shape of the level descriptor come from reading it. Everything on this
page was then checked against this cartridge's own bytes, and where his reading
and ours disagreed, the disagreement is written down rather than smoothed over.
