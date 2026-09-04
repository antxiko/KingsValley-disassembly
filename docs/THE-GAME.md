# The game

**King's Valley** is a maze game set in pyramids: the explorer enters a
chamber, collects the jewels scattered around it, and leaves through the door
that opens once he has them all. Along the way there are mummies that kill him
on contact, blocks that can be dug out, and traps that fall.

Everything below comes from the binary, not from playing. Where something could
not be confirmed, it says so.

## Fifteen pyramids

`tabla_de_habitaciones` (0x6D68) holds twenty-one words: the **first fifteen**
are a pointer to each level's descriptor, and the last four are reused as the
base of each of the four wall pattern types.

Each descriptor starts with up to four **band** bytes. A band is sixteen
columns of wall, and its byte gives the type (high nibble) and the index within
that type (low nibble). The list ends when the next byte has a high nibble of 3.

Counted that way, the fifteen rooms split very regularly:

- the **odd** ones (1, 3, 5, 7, 9, 11, 13, 15) have **one** band: 16 columns.
- the **even** ones (2, 4, 6, 8, 10, 12, 14) have **three**: 48 columns.

The 48-column ones are wider than the screen, which is why the explorer's
horizontal position needs two whole bytes. See [Findings](FINDINGS.html).

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

A cell byte's **high nibble** says what class it is. The classification comes
from how each one is used, not from looking at them:

| nibble | what it is |
|---|---|
| `0x0x` | hole: what you walk through and fall through |
| `0x1x` | floor or solid wall; what `hay_suelo_bajo_los_pies` demands |
| `0x2x`, `0x3x` | the only two that accept the diagonal step |
| `0x5x` | the block that can be dug out (subtypes 1 and 2) |

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

## Digging

When the explorer pushes against a `0x5x` block for **sixteen consecutive
frames**, `jugador_anda_o_cae` moves him to state 6 with sound effect 0x03. The
counter for that run is at 0xE146 and resets the moment it is broken.

The blocks that open are a separate list, seven bytes per entry, at 0xE31E.
`marca_bloque_que_se_abre` (0x69C9) searches it for the one directly in front
and sets bit 0 of its field 0; from there,
`anima_bloques_que_se_abren` opens it in six steps, one every eight frames.

## The mummies

The enemies are the **22-bytes-per-entry** list starting at 0xE16A, with the
count at 0xE164. `mueve_los_enemigos` (0x6F5C) walks the list and dispatches
each one by its state through `tabla_6f78`, which has nine entries.

Each enemy has a **variant** (field 0x14) obtained by adding the game's
progress (0xE058) to the third byte of its descriptor and clamping to 4. The
variant sets its speed: `enemigo_estado_3` uses it to pick a frame mask from
the table at 0x716D, so each variant moves at a different rate.

Enemies also look for a route: `busca_camino` (0x734A) scans both ways, walks
down up to five rows of the column classifying what it finds, and keeps the
shorter of the two.

`busca_enemigo_que_toca` (0x5C84) handles collisions with the player. Only
enemies of type 0 to 3 and type 7 kill, they must be on the same screen, and if
either of the two is in state 3 the other must be as well. When the hit counts,
sound effect 0x1D plays and 0xE053 goes to zero, which is the signal that the
explorer has died.

## The traps

There is a sixth list, nine bytes per entry, at 0xE3FF, which
`mueve_la_trampa` (0x67F2) sends down the column. Its exact identity could not
be confirmed; what **is** measured is that it **kills**: the probe at 0x68DA
returns true when it finds patterns 0x19 or 0x1A, and then it leaves by the
same door as the enemies — effect 0x1D and 0xE053 to zero.

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
→ back to 4 → 7 (pause) → 0 again.
