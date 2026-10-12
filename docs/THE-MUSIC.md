# The music

Everything you hear here comes from running the cartridge's own sound engine (`tick_sonido`, 0x7B37, and `reproduce_efecto`, 0x7A9E, which hands it the channels; the interrupt calls it at 0x401E) on an emulated Z80, frame by frame at 60 per second, just as the game calls it. What the engine writes to the PSG is turned into sound with an AY-3-8910 (`tools/musica.py`). Each MP3 is the whole piece up to where it starts again, plus 8 seconds of the repeat fading out; those that do not repeat end where the engine ends.

## Checked against openMSX

The PSG writes have been compared frame by frame with those of openMSX (C-BIOS MSX1 japonés). In every frame the PSG ends up the same:

- the room tune (0x8B), its first 219 frames;
- the valley map (0x91), whole, 168 frames;
- the task 3 start (0x97), 244 frames of 261, as the game asks for it.

The timbre is not checked: it is a textbook AY-3-8910, not a recording of the emulator. The probes are `tools/omsx_psg.tcl` and `tools/coteja_psg.py`.

## How a piece is asked for

`reproduce_efecto` takes the number in A. Low numbers are effects and from 0x87 up there is music. Each record takes fourteen bytes from 0xE010 and 0xE03A holds the copy of the PSG mixer, which start-up leaves at 0xB8. The tracks marked «in the table» are in the track table but no routine asks for them with an `ld a`.

## The tunes

**The room tune** (0x8B)

Asked for by `bucle_de_juego`, `tarea_4_espera_a_jugar` y `tarea_10_pantalla_final`; lasts 12.8 s and starts again at second 0.0.

<audio controls preload="none" src="audio/musica_8B.mp3?v=90456473"></audio>

**The valley map** (0x91)

Asked for by `monta_el_mapa_del_valle`; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_91.mp3?v=cb00e77b"></audio>

**The start of task 3** (0x97)

Asked for by `tarea_3_arranca`: efecto 0x97 y 0x50 fotogramas de contador; lasts 4.3 s.

<audio controls preload="none" src="audio/musica_97.mp3?v=7c1a0b34"></audio>

**The solved room** (0x94)

Asked for by `sala_comprueba_final`; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_94.mp3?v=daadb3d3"></audio>

**The tune at 0x4211** (0x9A)

Asked for by `L_4211`; lasts 4.9 s.

<audio controls preload="none" src="audio/musica_9A.mp3?v=fbbeaf18"></audio>

**The tune at 0x66B3** (0x8D)

Asked for by `L_66B3`; lasts 1.0 s.

<audio controls preload="none" src="audio/musica_8D.mp3?v=faa6b0d1"></audio>

**Table track 0x83** (0x83)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 29.6 s.

<audio controls preload="none" src="audio/musica_83.mp3?v=f22ab15c"></audio>

**Table track 0x8C** (0x8C)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 2.0 s and starts again at second 0.9.

<audio controls preload="none" src="audio/musica_8C.mp3?v=a9f21cf9"></audio>

**Table track 0x90** (0x90)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_90.mp3?v=a224b183"></audio>

**Table track 0x92** (0x92)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_92.mp3?v=513cad87"></audio>

**Table track 0x93** (0x93)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 2.8 s.

<audio controls preload="none" src="audio/musica_93.mp3?v=eb74c83c"></audio>

**Table track 0x95** (0x95)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.3 s.

<audio controls preload="none" src="audio/musica_95.mp3?v=99a222df"></audio>

**Table track 0x96** (0x96)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.3 s.

<audio controls preload="none" src="audio/musica_96.mp3?v=f496c627"></audio>

**Table track 0x98** (0x98)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.9 s.

<audio controls preload="none" src="audio/musica_98.mp3?v=feb29eac"></audio>

**Table track 0x99** (0x99)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 4.9 s.

<audio controls preload="none" src="audio/musica_99.mp3?v=394ffd87"></audio>
