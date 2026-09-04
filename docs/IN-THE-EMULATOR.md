# In the emulator

Reading opcodes is not enough for everything. Some things can only be settled
by watching what the machine actually does, and for that there are five openMSX
scripts in `tools/`.

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

## `omsx_check_4644.tcl` — the patch that does nothing

`L_403E` does real self-modifying code: it patches the first byte of task 1
with a `pop hl` + `ret`, neutralising it. But it does so **identically every
time** without reading any state that changes, and that did not add up.

Breakpoints at 0x4644, 0x403E and 0x40E4, 120 emulated seconds. The real
result: 0x403E runs **92 times** — so it is a normal path, not some rare case —
but the first byte of task 1 still reads 0x10 on all nine occasions that task
runs afterwards.

The explanation is simple and did not show up on reading: the write lands in
**0x4000-0x7FFF, which is ROM**. It has no effect at all. It is a no-op.

## `omsx_barrido_huecos.tcl` and `omsx_quien_lee.tcl`

Both generic: the first sweeps the unclassified gaps setting read watchpoints,
and the second answers "who reads this address" by setting a watchpoint and
recording the PC.

## What is NOT checked against a running machine

This needs saying just as plainly:

- The **screens drawn** by `tools/pantallas.py` — the title, the rooms with
  their graphics, the final screen — have **not been compared byte for byte
  against the emulator's VRAM**. They have been looked at, and they come out
  recognisable and coherent: the Konami wordmark comes out crisp, which can
  only happen if the reading of R3 and R4 is right. But looking is not
  comparing.
- The **room map** was checked (0 differences across 352 cells), but with the
  earlier decoder, the one that only gave wall or hole. The cell-to-tile
  translation and the per-group colours are not.
- That **0xE130 is the frame counter** of the screen at rest is deduced from
  how it is used — incremented once per frame and compared against two
  deadlines, 0x58 and 0xE0 — not measured.
- How long **each stage** of task 0's cascade lasts has not been measured: the
  test script's input always gets there first.
