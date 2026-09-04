# Open questions

The binary is 100 % explained and every routine has a name. That does not mean
everything is understood. What follows is what is still loose, said plainly.

## The enemy sprites

The sprite sheet on the site comes from the cartridge's **six scripts** whose
first word falls in 0x1800-0x1FFF, which is where R6 puts the sprite pattern
table. Between them they leave the explorer in his poses, the jewel and the
tools.

But the sheet has **empty rows in the middle**, and the mummies have to be
somewhere. The script — or scripts — that load them is still to be located. It
may be that they are loaded per room, or from a routine that has not yet been
crossed with that address.

## What exactly the 0xE3FF list is

`mueve_la_trampa` (0x67F2) walks a list of nine bytes per entry and sends its
elements down the room buffer's column. What **is** measured is that it can
kill: the probe at 0x68DA returns true for patterns 0x19 and 0x1A, and from
there it leaves by the same door as the enemies.

What is not settled is **what it is**. It could be a falling rock, a dart, or
something that has not occurred to us. Drawing patterns 0x19 and 0x1A on their
own would settle it.

## Cell types 0x2x and 0x3x

They are classified by **how they are used**: they are the only two classes
`mueve_al_jugador` accepts for the diagonal step, and `sube_un_escalon`
additionally demands subtypes 0x16 and 0x17. The profile table at 0x5168
(0, −1, −2, −3, −4, −3, −2, −1) draws a V in Y according to the X within the
cell.

But **what they look like** — whether they are steps, a ramp, a ladder — has
not been confirmed by drawing them. The classification by use is solid; the
name is not.

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

## The drawn screens, not compared against VRAM

None of the new screens — title, rooms with graphics, final screen — has been
compared byte for byte against an emulator VRAM dump. They come out
recognisable, and the Konami wordmark comes out crisp, which already rules out
the R3/R4 reading being inverted. But that is looking, not measuring, and the
series' rule is to measure.

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
