# La música

Todo lo que suena aquí sale de ejecutar el motor de sonido del cartucho (`tick_sonido`, 0x7B37, y `reproduce_efecto`, 0x7A9E, que le reparte los canales; lo llama la interrupción en 0x401E) en un Z80 emulado, cuadro a cuadro y a 60 por segundo, igual que lo llama el juego. Lo que el motor escribe en el PSG pasa a sonido con un AY-3-8910 (`tools/musica.py`). Cada MP3 es la pieza entera hasta donde vuelve a empezar, más 8 segundos de la vuelta apagándose; las que no se repiten acaban donde acaba el motor.

## Cotejado con openMSX

Las escrituras al PSG se han comparado cuadro a cuadro con las de openMSX (C-BIOS MSX1 japonés). En todos los cuadros el PSG queda igual:

- la música de la sala (0x8B), sus primeros 219 cuadros;
- el mapa del valle (0x91) entero, 168 cuadros;
- el arranque de la tarea 3 (0x97), 244 cuadros de 261, tal como el juego lo pide.

El timbre no está cotejado: es el de un AY-3-8910 de manual, no una grabación del emulador. Las sondas están en `tools/omsx_psg.tcl` y `tools/coteja_psg.py`.

## Cómo se pide una pieza

`reproduce_efecto` recibe el número en A. Los números bajos son efectos y del 0x87 en adelante hay música. Cada ficha ocupa catorce bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, que el arranque deja en 0xB8. Las pistas «de la tabla» están en la tabla de pistas pero ninguna rutina las pide con un `ld a`.

## Las músicas

**La música de la sala** (0x8B)

Lo pide `bucle_de_juego`, `tarea_4_espera_a_jugar` y `tarea_10_pantalla_final`; dura 12,8 s y vuelve a empezar en el segundo 0,0.

<audio controls preload="none" src="../audio/musica_8B.mp3?v=90456473"></audio>

**El mapa del valle** (0x91)

Lo pide `monta_el_mapa_del_valle`; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_91.mp3?v=cb00e77b"></audio>

**El arranque de la tarea 3** (0x97)

Lo pide `tarea_3_arranca`: efecto 0x97 y 0x50 fotogramas de contador; dura 4,3 s.

<audio controls preload="none" src="../audio/musica_97.mp3?v=7c1a0b34"></audio>

**La sala resuelta** (0x94)

Lo pide `sala_comprueba_final`; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_94.mp3?v=daadb3d3"></audio>

**La pieza del 0x4211** (0x9A)

Lo pide `L_4211`; dura 4,9 s.

<audio controls preload="none" src="../audio/musica_9A.mp3?v=fbbeaf18"></audio>

**La pieza del 0x66B3** (0x8D)

Lo pide `L_66B3`; dura 1,0 s.

<audio controls preload="none" src="../audio/musica_8D.mp3?v=faa6b0d1"></audio>

**Pista 0x83 de la tabla** (0x83)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 29,6 s.

<audio controls preload="none" src="../audio/musica_83.mp3?v=f22ab15c"></audio>

**Pista 0x8C de la tabla** (0x8C)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 2,0 s y vuelve a empezar en el segundo 0,9.

<audio controls preload="none" src="../audio/musica_8C.mp3?v=a9f21cf9"></audio>

**Pista 0x90 de la tabla** (0x90)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_90.mp3?v=a224b183"></audio>

**Pista 0x92 de la tabla** (0x92)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_92.mp3?v=513cad87"></audio>

**Pista 0x93 de la tabla** (0x93)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 2,8 s.

<audio controls preload="none" src="../audio/musica_93.mp3?v=eb74c83c"></audio>

**Pista 0x95 de la tabla** (0x95)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,3 s.

<audio controls preload="none" src="../audio/musica_95.mp3?v=99a222df"></audio>

**Pista 0x96 de la tabla** (0x96)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,3 s.

<audio controls preload="none" src="../audio/musica_96.mp3?v=f496c627"></audio>

**Pista 0x98 de la tabla** (0x98)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,9 s.

<audio controls preload="none" src="../audio/musica_98.mp3?v=feb29eac"></audio>

**Pista 0x99 de la tabla** (0x99)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 4,9 s.

<audio controls preload="none" src="../audio/musica_99.mp3?v=394ffd87"></audio>
