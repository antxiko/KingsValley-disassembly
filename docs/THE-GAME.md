# The game

**King's Valley** is a maze game set in pyramids: the explorer enters a
chamber, collects the jewels scattered around it, and leaves through the door
that opens once he has them all. Along the way there are mummies that kill him
on contact, brick floors he can dig holes through, revolving doors, knives to
throw and trap walls that come down from the ceiling.

Everything below comes from the binary, not from playing. Where something could
not be confirmed, it says so.

## Fifteen pyramids, in a ring

`tabla_de_habitaciones` (0x6D68) holds nineteen words: the **first fifteen**
are a pointer to each level's descriptor, and the last four are the base of
each of the four wall pattern types.

Each descriptor starts with up to four **band** bytes. A band is sixteen
columns of wall, and its byte gives the type (high nibble) and the index within
that type (low nibble). The list ends **at** the band whose high nibble is 3 —
and that band is drawn too, which is the detail this project got wrong at
first. See [Findings](FINDINGS.html).

Counted properly, the rooms split very regularly:

- the **odd** ones (1, 3, 5 ...) have **two** bands: 32 columns, one screen.
- the **even** ones (2, 4, 6 ...) have **four**: 64 columns, two screens.

The two-screen rooms are why the explorer's horizontal position needs two whole
bytes.

After the bands the descriptor lists, in this order: the four **exit doors**,
the **mummies**, the **jewels**, the **knives**, the **pickaxes**, the
**revolving doors**, the **trap walls** and the **ladders**. Every descriptor
ends exactly where the next one begins, which is how we know the reading is
right down to the byte.

Each door carries the number of the pyramid it leads to, and laid out those
numbers make a **closed ring**: 1 to 2 to 3 ... to 15 and back to 1. The screen
between pyramids is the valley map, with the fifteen of them on a winding path
and the word GOAL at the end.

| # | columns | jewels | mummies | knives | pickaxes | revolving doors | trap walls | ladders |
|---|---|---|---|---|---|---|---|---|
| 1 | 32 | 4 | 2 | 1 | 0 | 0 | 0 | 8 |
| 2 | 64 | 5 | 3 | 3 | 7 | 2 | 2 | 13 |
| 3 | 32 | 5 | 2 | 2 | 3 | 0 | 1 | 7 |
| 4 | 64 | 6 | 2 | 3 | 9 | 1 | 0 | 16 |
| 5 | 32 | 4 | 2 | 1 | 5 | 0 | 1 | 10 |
| 6 | 64 | 6 | 3 | 2 | 10 | 1 | 2 | 16 |
| 7 | 32 | 5 | 2 | 2 | 3 | 0 | 0 | 8 |
| 8 | 64 | 5 | 3 | 4 | 7 | 1 | 3 | 12 |
| 9 | 32 | 4 | 1 | 2 | 6 | 0 | 0 | 7 |
| 10 | 64 | 6 | 3 | 3 | 6 | 0 | 3 | 13 |
| 11 | 32 | 5 | 2 | 1 | 4 | 2 | 0 | 10 |
| 12 | 64 | 6 | 3 | 3 | 8 | 2 | 1 | 12 |
| 13 | 32 | 5 | 2 | 1 | 8 | 0 | 0 | 10 |
| 14 | 64 | 6 | 2 | 2 | 12 | 1 | 0 | 11 |
| 15 | 32 | 6 | 2 | 2 | 6 | 0 | 0 | 8 |
| **total** | | **78** | **34** | **32** | **94** | **10** | **13** | **161** |

## How a room is drawn

`carga_la_sala` (0x6A90) does not draw into VRAM: it **unpacks bit by bit** the
wall pattern into a RAM buffer starting at 0xE700. Each pattern byte gives eight
cells, and each bit says wall (0x12) or hole (0x00). Whatever the bands do not
cover has already been filled with 0x14 by `borra_sala`.

The buffer has a **row stride of 96 bytes**, not 16 or 48. That figure comes
from two independent directions: from the unpacking's `ld a,050h` plus the
sixteen `inc de` the row itself already advanced (16+80=96), and from the
arithmetic in `lee_celda_de_sala`, which multiplies the row by 96 with five
`add hl,hl` and one addition. Two different routines — one writing the buffer,
one reading it — land on the same number without copying it from each other.

Only afterwards does `vuelca_la_vista` (0x5D31) copy a 22-row by 32-column
window of that buffer into the name table, translating each cell with
`traduce_celda_a_patron`.

## The cell types

A cell byte's **high nibble** says what class it is, and its low nibble picks
one entry inside that class. `traduce_celda_a_patron` (0x5D52) turns that into
a tile number through the table at 0x5D68:

| nibble | what it is |
|---|---|
| `0x0x` | hole: what you walk through and fall through |
| `0x1x` | floor and wall, plus the ends of a ladder where it meets a platform |
| `0x2x` | **ladder rungs** — 0x20/0x21 leaning right, 0x22/0x23 leaning left |
| `0x3x` | a **knife** lying on the floor (0x31 and 0x32 if it landed on a rung) |
| `0x4x` | a **jewel** — 0x43 to 0x48, one per colour — and its three sparkles |
| `0x5x` | a **revolving door** |
| `0x6x`, `0x7x` | the **exit door** and the **lever** that opens it |
| `0x8x` | a **pickaxe** |

An earlier version of this page had `0x5x` as "the block that can be dug out"
and `0x2x`/`0x3x` as "the two that accept the diagonal step", both classified by
use because nobody had drawn them. Drawn, they are a revolving door and a
ladder: the diagonal step is climbing.

## The explorer

His state lives in a record starting at 0xE134:

| address | what it is |
|---|---|
| `0xE134` | state, 0 to 6; indexes `tabla_4c7f` |
| `0xE135` | the processed controller input |
| `0xE136` | bit 0: which way he faces |
| `0xE137` | Y, in pixels |
| `0xE138` | X, fractional part (1/256 of a pixel) |
| `0xE139` | X, low byte |
| `0xE13A` | X, high byte |

The seven states are walking, digging, pushing and the transitions between
them. `avanza_estado_del_jugador` (0x4C59) steps the machine once a frame, and
pushes `monta_sprite_del_jugador` as the return address so the figure gets
redrawn on the way out whatever the state was.

Only states 0 and 3 accept fresh input; in the others the explorer is midway
through an action and the controller does not count.

## Digging, and the seven states of the explorer

The state machine at 0xE134 has seven states, and `avanza_estado_del_jugador`
(0x4C59) steps it once a frame, pushing `monta_sprite_del_jugador` as the
return address so the figure gets redrawn whatever the state was:

| state | what he is doing |
|---|---|
| 0 | walking |
| 1 | jumping |
| 2 | falling |
| 3 | on a ladder |
| 4 | **throwing the knife** |
| 5 | **digging with the pickaxe** |
| 6 | **going through a revolving door** |

Only states 0 and 3 accept fresh input; in the others he is midway through
something and the controller does not count.

What the button does depends on **what he is carrying**, which is the high
nibble of 0xE144: 0 nothing, 1 the knife, 2 the pickaxe. That same nibble picks
one of three sprite sets, all of which load into the same VRAM address, so he
is drawn empty-handed, with a knife or with a pickaxe.

Digging opens a **hole** in the brick floor, and the explorer and the mummies
fall through it. The holes are their own list, seven bytes per entry, at
0xE31E; `marca_el_agujero_que_se_abre` (0x69C9) finds the one right where he is
digging and sets bit 0 of its field 0, and from there
`anima_bloques_que_se_abren` opens it in six steps, one every eight frames.

Pushing against a **revolving door** for sixteen consecutive frames sends him
to state 6 with sound effect 0x03. The counter for that run is at 0xE146 and
resets the moment it is broken.

## The exit, and the lever

An exit door is a stamp of three rows by five columns, written into the room
buffer with its corner sixteen pixels left and eight pixels up from the door's
own coordinates. It has three states — closed, closing and open — each a
fifteen-byte table at 0x67C5, 0x67D4 and 0x67E3.

Until every jewel is collected only the door you came in through is visible,
and it is drawn **open**. Collect them all and the exits appear, closed, with a
**lever** beside them; touching the lever opens the way out. Clearing a pyramid
for the first time is also worth 2,000 points.

## The mummies

The enemies are the **22-bytes-per-entry** list starting at 0xE16A, with the
count at 0xE164. `mueve_los_enemigos` (0x6F5C) walks the list and dispatches
each one by its state through `tabla_6f78`, which has nine entries.

Each mummy has a **type**, and there are five. The type is the third byte of
its descriptor **plus the number of times the game has been finished**, clamped
at 4 — so the valley gets harder every time you go round it. The table at
0x6D3C gives each type its speed in the high nibble and its colour in the low
one, and both were checked against the sprite attribute table of a running
machine:

| type | speed | colour | how many use it |
|---|---|---|---|
| 0 | 5 | white | 10 |
| 1 | 5 | light red | 4 |
| 2 | 10 | dark blue | 9 |
| 3 | 10 | red | 7 |
| 4 | 11 | dark yellow | 4 |

Mummies also look for a route: `busca_camino` (0x734A) scans both ways, walks
down up to five rows of the column classifying what it finds, and keeps the
shorter of the two.

`busca_enemigo_que_toca` (0x5C84) handles collisions with the player. Only
mummies of type 0 to 3 and type 7 kill, they must be on the same screen, and if
either of the two is in state 3 the other must be as well. When the hit counts,
sound effect 0x1D plays and 0xE053 goes to zero, which is the signal that the
explorer has died.

## The trap walls

There is a sixth list, nine bytes per entry, at 0xE3FF: the **trap walls**. A
block of bricks comes loose from the ceiling and works its way down a column
every 32 frames, killing whatever it catches — the probe at 0x68DA returns true
for patterns 0x19 and 0x1A, and from there it leaves by the same door as the
mummies, effect 0x1D and 0xE053 to zero.

They are in the level descriptor, two bytes each, and they are **not on the map
until they trigger**: thirteen of them across the fifteen pyramids. This page
used to say the list's identity could not be confirmed. It can now: the
descriptor gives them their own block, and this is `MurosTrampa` in Manuel
Pazos' disassembly.

## The score

`suma_al_marcador` (0x4412) keeps six digits in **packed BCD** at
0xE049-0xE04B, with a `daa` after every addition. On passing the threshold at
0xE052 it grants an extra round and raises the threshold by 2, also in BCD,
clamping it at 0xFF — past that there are no more extra lives. Then it compares
against the high score at 0xE043-0xE045 and updates it if due.

All of this only counts with bit 6 of 0xE002 set, which is what tells a real
game from the demo.

## The demo

When nobody touches anything, the cartridge plays itself. It is not an
intelligence: it is a **recorded script**. `arranca_partida` puts the pointer
to 0x4ACE into 0xE080, and `guion_de_la_demo` (0x4621) reads it in (input,
duration) pairs until the 0xFF that ends it. The input values are exactly the
same bits the controller would leave.

The full menu cycle, measured in the emulator in an earlier batch, is task 0
(logo) → 1 (title) → 3 → 4 (room name) → 5 (room at rest) → 6 (the demo moves)
→ back to 4 → 7 (pause) → 0 again. One round takes 57.6 seconds of emulated
time, and the pyramid it plays is always the **fifth**.
