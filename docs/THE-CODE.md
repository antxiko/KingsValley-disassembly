# The code

The listing's 651 routines all have a name and a description, and **45.5 %** of
the instructions carry a comment of their own. This page walks through the
pieces you need in order to read the rest.

## The task dispatcher

The game is a state machine with eleven tasks. `avanza_un_cuadro` (0x40A3)
bumps the frame counter and `despacha_tarea_activa` (0x40B6) jumps to whichever
task the low byte of 0xE000 names.

The dispatch uses a trick that shows up **seven times** in the cartridge:

```asm
    call L_404B
    defw target0, target1, target2, ...
```

`L_404B` (0x404B) does `add a,a`, recovers the return address with `pop hl` —
which is precisely the table following the `call` — and reads the right word
from there. Then `jp (hl)`. The table is never executed: it is **read** off the
stack.

All seven tables are declared in the `.nocode`, because otherwise the tracer
reads them as code and out comes a listing that reassembles fine and lies.

## The position record

The piece that opens up the rest of the game is not a player routine: it is
`lee_celda_de_sala` (0x50BC), read backwards. It takes a **pointer to a
position record** in HL and uses:

- `(HL+0)` plus an adjustment, shifted three bits: the **row**.
- `(HL+2)` and `(HL+3)` as a **16-bit** quantity, plus a signed offset, shifted
  three bits: the **column**.

That gives the format of the explorer's record, which starts at 0xE137, and
three bytes below it sits the state — confirmed by `sondea_una_celda` (0x5092),
which with HL at 0xE137 does `dec hl` three times and reads the result as the
state to compare against 2.

That same format is used by the entities, the enemies and the candidate
position scratch at 0xE149. Which is why the probe routines serve all of them.

## The 24-bit arithmetic

`avanza_posicion_24_bits` (0x73F6) is the engine behind every movement. It
comes in with HL pointing at a 16-bit pair and DE holding the velocity, and
does:

```asm
    add hl,de       ; the two low bytes
    ld a,b
    adc a,c         ; and the third, with the carry
```

That is **twenty-four bits**: fraction, low pixel, high pixel. For the explorer
those three bytes are 0xE138, 0xE139 and 0xE13A.

Bit 0 of `(IX-2)` — which for the explorer is 0xE136, the direction byte —
decides whether the velocity is **negated** before adding, with a two's
complement of DE and a complement of C. That is how the same code serves both
directions, and why that bit is "which way he faces".

## The six entity lists

Six parallel tables, each with its own accessor. You do not have to guess how
big an entry is: it is in the **multiplication**.

| routine | chain | stride | base | index | limit |
|---|---|---|---|---|---|
| 0x6A12 | i, 3i, 7i | **7** | 0xE1C5 | 0xE1F4 | — |
| 0x65A5 | 2i, 4i, 8i, +i | **9** | 0xE1F5 | 0xE1F4 | 0xE1F3 |
| 0x5AF6 | 2i, 4i, 8i, 16i, +i | **17** | 0xE264 | 0xE262 | 0xE263 |
| 0x73D3 | 2i, 6i, 22i | **22** | 0xE16A | 0xE165 | 0xE164 |
| 0x68C2 | 2i, 4i, 8i, +i | **9** | 0xE3FF | 0xE3FD | 0xE3FE |
| 0x6A09 | i, 3i, 7i | **7** | 0xE31E | 0xE31C | 0xE31D |

The first two **share an index** (0xE1F4): they are two blocks of fields of the
same entity, split across two areas of memory.

The chains are nested, too: `campo_de_entidad_17` prepares 2i and joins the
chain halfway at `indexa_paso_17`, which carries on to 16i;
`campo_de_entidad_9` joins one step earlier at `indexa_paso_9`, and the last
three `add`s are shared by both. It saves bytes at the cost of having to read
the whole chain to know the stride.

## The pushed loop closers

Five entity loops do this before dispatching:

```asm
    ld hl,<closer>
    push hl
    ...
    jp (hl)         ; off to whichever routine
```

The `ret` of the dispatched routine **does not return to the caller**: it falls
into the closer, which bumps the index and jumps back into the loop body. All
five closers have the same shape:

```asm
    ld hl,<index>
    inc (hl)
    ld a,(hl)
    inc hl
    cp (hl)
    jp nz,<body>
    ret
```

That is 87 bytes of code a static tracer cannot reach, because the address
travels through the stack as if it were data. They are declared in the
`.entries` with their justification.

## Drawing: two interpreters

`dibuja_guion` (0x451A) reads one-byte commands:

```
C = B0 & 0x7F
  C != 0 and bit 7 set    -> copy C raw bytes from the script into VRAM
  C != 0 and bit 7 clear  -> read ONE byte and repeat it C times
  B0 == 0x00              -> end
  B0 == 0x80              -> read a word with another VRAM address and carry on
```

Telling `0x00` from `0x80` is settled rather nicely: the byte is read twice,
once masked with `0x7F` and once raw, and the two are compared. If they match,
bit 7 was clear.

The VDP auto-increments after each write, so a script paints a continuous
stretch. `dibuja_guion_x3_tercios` (0x44F1) repeats the same script three times
0x800 apart: SCREEN 2's three thirds.

`escribe_guion_de_texto` (0x4051) is a different language altogether: a word
with the address, characters, `0xFE` to jump and `0xFF` to end. The characters
are in **ASCII minus 0x20**.

## The sound engine

The PSG player lives at 0x7A9E-0x7CE2, forty routines. Each channel is a
**fourteen-byte** structure, and there are three, at 0xE010, 0xE01E and 0xE02C.

PSG register 7 — the mixer — is used to switch channel C between tone and noise
note by note: `conmuta_ruido_canal_c` alternates 0x9C (tones A and B with noise
on C) and 0xB8 (all three tones, no noise). That is the percussion.

The note byte has two halves, and the high nibble is **not the octave**: it is
the index into `tabla_periodos_nota`, 0 to 9. The octave comes from a separate
field of the channel structure, set by an earlier control command.

## The score, in BCD

`suma_al_marcador` (0x4412) keeps six digits in packed BCD. You do not have to
deduce it: the `daa`s sit after every `add` and every `adc`.

Same with `divide_entre_diez` (0x439A), which turns a small binary into two
digits by subtracting ten at a time and counting in the high nibble.

## What the cartridge never does

Two code blocks are called by nobody: 0x4501 and 0x4542. The second is the
counterpart of `prepara_escritura_vdp` **for reading** VRAM — it calls SETRD and
takes the read port from system variable 0x0007, just as the other takes the
write port from 0x0006.

That it is there and unused says something about the design: **this cartridge
never reads VRAM back**. It writes and forgets. All the game state lives in
RAM, including a full copy of the room at 0xE700.
