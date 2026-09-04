# In the emulator

Reading opcodes is not enough for everything. Some things can only be settled
by watching what the machine actually does, and for that there are eight
openMSX scripts in `tools/`.

They all follow the same pattern: a breakpoint at `INIT` (0x406C) to arm the
watchpoints **after** page 1 really is the cartridge, blind input driven by
fixed-seed random keypresses, and a real-time watchdog in case something hangs.

```
"C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
    -cart kingsvalley.rom -script tools/omsx_task_trace.tcl
```

## `omsx_task_trace.tcl` — the task cycle

A write watchpoint on 0xE000, the active task index, taking a screenshot and
the PC on every change. Ninety seconds of menu and demo.

The full cycle came out like this, identified **from the screenshots**, not
guessed:

```
0 (Konami logo) -> 1 (title) -> 3 -> 4 (room name) -> 5 (room at rest)
  -> 6 (the demo moves) -> [4 again, repeats] -> 7 (pause) -> 0
```

**The surprise that nearly ruined the batch**: the 0→1 and 1→3 transitions are
not fired by each task's natural frame cascade — which does exist and reads
fine in the opcodes — but by `revisa_teclado_y_salta_menu` (0x4644). The PC of
the write, measured, lands at 0x4663 and 0x4679, inside that routine. Because
the test script presses keys from 1.5 seconds in, the "skip with a keypress"
path always beats the natural wait.

Without that second `PC=` field in the log, the comment would have credited the
transitions to the wrong routine.

## `omsx_dump_sala.tcl` — the room buffer

A breakpoint at 0x6B09, the `exx` that closes the unpacking of **one band**,
and a dump of 0xE700 onwards.

An earlier attempt used 0x6D3B — the first `ret` that appears around there in
the listing — and gave row 0 right and 0xFF for the rest: that `ret` closes a
**different** routine, not the real end of the unpacking. With the right
breakpoint: **0 differences across 352 cells** of room 1 against the Python
decoder.

Two corrections came out of that check that static reading had not caught:

- The wall pattern's stride is **44 bytes**, not 22. The 22 is the row loop's
  counter, not the multiplier for the address: two identical numbers by
  coincidence. At 44 it fits the four block sizes exactly (176/44 = 4,
  132/44 = 3, no remainder).
- The buffer's row step is not +0x50 — the literal operand of the `ld a,050h` —
  but **+0x60**: to that 0x50 you must add the sixteen the row itself already
  advanced while writing. Without this adjustment row 0 matched by luck and
  nothing else did.

## `omsx_dump_sprites.tcl` — the attribute table

Dumps VRAM 0x3B00-0x3B7F and RAM 0xE0B0-0xE12F at seven moments, and also
searches for which name table cells use patterns 0x51, 0x52, 0x53 and 0x5C.

It confirmed three things: that the name table is 768 bytes from 0x3800 and
ends exactly at 0x3AFF, back to back with the attribute table; that the buffer
values are plausible Y/X/pattern/colour, with Y=0xE1 (−31) on the entries
parked off screen; and that the pattern `parpadea_patron_borde` rewrites
(0x0288/8 = 0x51 exactly) is byte for byte the same index the four corners of
the stone frame use in all five sampled rooms.

## `omsx_check_4644.tcl` — the write that never lands

0x403E does real self-modifying code: it writes a `pop hl` + `ret` over the
first byte of task 1. But it does so **identically every time** without reading
any state that changes, and that did not add up.

Breakpoints at 0x4644, 0x403E and 0x40E4, 120 emulated seconds. The real
result: 0x403E runs **92 times** — so it is a normal path, not some rare case —
but the first byte of task 1 still reads 0x10 on all nine occasions that task
runs afterwards, because the write lands in **0x4000-0x7FFF, which is ROM**.

What that measurement could not tell us is *why*. It is a **copy protection**:
harmless in a cartridge, lethal in a copy loaded into RAM. See
[Findings](FINDINGS.html).

## `omsx_dump_mapa.tcl` — the whole room, elements included

`omsx_dump_sala.tcl` stops in the middle of unpacking one band, which only
proves the walls. This one stops at 0x4176, the first place where
`carga_la_sala` and `reparte_entidades_de_la_sala` have both finished and
nothing has painted the entrance door yet, and dumps the complete 23x96 map
buffer from 0xE700.

The demo only ever plays pyramid 5, so the level is **forced** at 0x6A90 — both
0xE054 and 0xE055, because the first thing that routine does is copy one over
the other — and the machine is reset between levels.

    python3 tools/mapas.py --comprueba kingsvalley.rom 0x4000 work/omsx_mapa

**Fifteen dumps, 31,680 cells compared, 0 differences.**

## `omsx_vram_sala.tcl` — the picture itself

The same forcing, but stopping at 0x4185, with the room already on screen and
the sprites in place, and dumping all 16 KB of VRAM plus the eight VDP
registers. Then, two emulated seconds later, the sprite attribute table again —
the mummies are not there when the room is built, they arrive on a timer — which
is where the explorer's two colours and each mummy type's colour were read.

    python3 tools/mapas.py --vram kingsvalley.rom 0x4000 work/omsx_vram

**Fifteen levels; name table, pattern table, colour table and sprite pattern
table; 0 differences.** Of the pattern and colour tables only the tiles the
screen actually uses are required to match — the rest of those tables is
leftovers from the title screen that the game neither rewrites nor reads.

## `omsx_vram_menus.tcl` — the title screen and the valley map

The rooms were compared against the machine; the menu screens were not, and
two mistakes hid there. This dumps both.

The title screen is caught at 0x43B7, the end of `dibuja_titulo_y_texto_ya`.
The valley map is harder: it only comes up when a pyramid is cleared, and the
demo never clears one. It is forced at 0x4176 — a point that runs every time a
room is built — by **blanking the whole name table** and then setting PC to
0x41C0, the pair of calls that build the map. Blanking first is what makes the
dump conclusive: whatever appears in the name table afterwards was written by
the map's own code.

    cd tools && python pantallas.py --vram ../kingsvalley.rom 0x4000         ../work/omsx_menus

**Two screens; name table, pattern table and colour table; 0 differences.**

## `omsx_barrido_huecos.tcl` and `omsx_quien_lee.tcl`

Both generic: the first sweeps the unclassified gaps setting read watchpoints,
and the second answers "who reads this address" by setting a watchpoint and
recording the PC.

## What is NOT checked against a running machine

This needs saying just as plainly:

- The **final screen** and the **Konami logo screen** have not been compared
  byte for byte against the emulator's VRAM. The title screen, the valley map
  and the fifteen pyramids have, and they match exactly.
- That **0xE130 is the frame counter** of the screen at rest is deduced from
  how it is used — incremented once per frame and compared against two
  deadlines, 0x58 and 0xE0 — not measured.
- How long **each stage** of task 0's cascade lasts has not been measured: the
  test script's input always gets there first.
