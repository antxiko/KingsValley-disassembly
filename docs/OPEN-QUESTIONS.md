# Open questions

The binary is 100 % explained and every routine has a name. That does not mean
everything is understood. What follows is what is still loose, said plainly.

Four questions that used to be on this page are now closed, and the answers
are on the other pages: **the mummies' sprites** (they are at 0x1940, and the
mirrored ones are made at run time, not stored); **what cell types 0x2x and
0x3x look like** (ladder rungs); **what the 0xE3FF list is** (the trap walls);
and **whether the drawn screens match the machine** (they do — name table,
patterns, colour and sprites, zero differences across the fifteen pyramids).

## Which of the two builds people actually played

This cartridge is **version 1**, and version 2 fixes four bugs in it. Which of
the two shipped where, and in what order, is not something the binary can
answer — and this series' rule is not to deduce a release history from a
binary. A dump of version 2 next to this one would let the two be compared
instruction by instruction, the way another cartridge in this series with two
builds was handled.

## What the four dead entries in the tile table were for

The table at 0x5D68 has, in this version, four pointers for cell classes
`0x9x`, `0xAx`, `0xBx` and `0xCx` that no level descriptor ever produces. They
point at patterns 0x4E, 0x4F and 0x50 and at two zero bytes. Version 2 deletes
them outright.

Something used those classes at some point in development. What, we do not know.

## How long each stage of task 0 lasts

Task 0's cascade has three nested levels of counter and reads fine in the
opcodes, but **how many frames each stage lasts has not been measured**: the
emulator test script presses keys from 1.5 seconds in, and
`revisa_teclado_y_salta_menu` always beats the natural wait.

Measuring it would need a script that touches nothing for the long minute the
cycle takes to come round on its own.

## The game variables in `arranca_partida`

`arranca_partida` (0x4115) initialises several variables whose exact role has
not been closed: 0xE062, 0xE058, 0xE055, 0xE080 and 0xE082. For 0xE080 and
0xE082 we do know they are the pointer and counter for the demo script. For the
other three we know where they are read, but not what they represent.

## 0xE130, deduced but not measured

That 0xE130 is the **frame counter for the screen at rest** is deduced from how
it is used: `pantalla_en_reposo` (0x77B7) increments it once per frame and
compares it against 0x58 and 0xE0, and at the second deadline writes 0xE1 into
0xE00D, which is precisely what cuts the demo short. It is corroborated by
0x6718 zeroing it on entering that screen.

It is consistent along three paths, but **no watchpoint has been set**. This is
flagged because the previous batch had the label "jugador2" recorded there,
inherited unverified from the Konami's Tennis template, and that label was
false. It is worth not replacing one unchecked label with another.

## Sound

The music and effect tables are located and named — `SFX_Momia`, `MUS_Ingame`,
`MUS_GameOver` and a dozen more — but the driver's own format has not been
taken apart, and nothing has been compared against the PSG registers of a
running machine.

## The first script at 0x47FE

The stretch 0x47FE-0x480D is a graphics script that writes a decorative bar and
the word SOFTWARE. Its **first five bytes** (0x0C, 0x7A, 0x16, 0x00, 0x88) are
not letters: they are tile indices for some ornament. What they draw has not
been looked at.

## And the usual one

Nobody has played a whole game with the listing open, checking as they go that
each thing does what the comment says. Earlier disassemblies in this series
have shown that doing so turns up mistakes neither reading nor measuring
catches.
