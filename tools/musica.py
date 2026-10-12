#!/usr/bin/env python3
"""La musica del cartucho, ejecutando su motor de sonido (ver motor_musica.py).

Pide el sonido con `reproduce_efecto` (0x7A9E, A = numero; 28 llamadas desde el
juego) y corre `tick_sonido` (0x7B37), que la interrupcion llama cada cuadro
(0x401E). Tres fichas de 14 bytes desde 0xE010; la copia del registro 7 del
PSG, en 0xE03A.
Uso:  musica.py registros 0x8B [cuadros] | mp3 0x8B f.mp3 | todas docs/audio
      musica.py barrido 0x80 0xBF | emu
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor_musica  # noqa: E402
from motor_musica import P  # noqa: E402

TABLA = "ninguna llamada directa: está en la tabla de pistas"

PIEZAS = [
    P(0x8B, "La música de la sala", "The room tune",
      "`bucle_de_juego`, `tarea_4_espera_a_jugar` y `tarea_10_pantalla_final`"),
    P(0x91, "El mapa del valle", "The valley map",
      "`monta_el_mapa_del_valle`"),
    P(0x97, "El arranque de la tarea 3", "The start of task 3",
      "`tarea_3_arranca`: efecto 0x97 y 0x50 fotogramas de contador"),
    P(0x94, "La sala resuelta", "The solved room", "`sala_comprueba_final`"),
    P(0x9A, "La pieza del 0x4211", "The tune at 0x4211", "`L_4211`"),
    P(0x8D, "La pieza del 0x66B3", "The tune at 0x66B3", "`L_66B3`"),
] + [P(n, "Pista 0x%02X de la tabla" % n, "Table track 0x%02X" % n, TABLA)
     for n in (0x8C, 0x90, 0x92, 0x93, 0x95, 0x96, 0x98, 0x99)]

PAGINA = motor_musica.pagina_basica(
    "`tick_sonido`, 0x7B37, y `reproduce_efecto`, 0x7A9E, que le reparte los "
    "canales; lo llama la interrupción en 0x401E",
    "`tick_sonido`, 0x7B37, and `reproduce_efecto`, 0x7A9E, which hands it "
    "the channels; the interrupt calls it at 0x401E",
    "C-BIOS MSX1 japonés",
    [("la música de la sala (0x8B), sus primeros 219 cuadros",
      "the room tune (0x8B), its first 219 frames"),
     ("el mapa del valle (0x91) entero, 168 cuadros",
      "the valley map (0x91), whole, 168 frames"),
     ("el arranque de la tarea 3 (0x97), 244 cuadros de 261, tal como el "
      "juego lo pide",
      "the task 3 start (0x97), 244 frames of 261, as the game asks for it")],
    [("Cómo se pide una pieza",
      "`reproduce_efecto` recibe el número en A. Los números bajos son "
      "efectos y del 0x87 en adelante hay música. Cada ficha ocupa catorce "
      "bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, "
      "que el arranque deja en 0xB8. Las pistas «de la tabla» están en la "
      "tabla de pistas pero ninguna rutina las pide con un `ld a`; se omite "
      "la 0x83, de media hora sin repetirse.",
      "How a piece is asked for",
      "`reproduce_efecto` takes the number in A. Low numbers are effects "
      "and from 0x87 up there is music. Each record takes fourteen bytes "
      "from 0xE010 and 0xE03A holds the copy of the PSG mixer, which "
      "start-up leaves at 0xB8. The tracks marked «in the table» are in the "
      "track table but no routine asks for them with an `ld a`; 0x83, half "
      "an hour long without repeating, is left out.")])

CFG = dict(rom="kingsvalley.rom", org=0x4000, frame=0x7B37, pide=0x7A9E,
           ram=(0xE010, 0xE03B), ram0=[(0xE03A, 0xB8)],
           excluye=[0xE019, 0xE027, 0xE035], hz=60, psg0={7: 0xB8},
           piezas=PIEZAS, pagina=PAGINA,
           cotejado=[(0x8B, 769, 1), (0x91, 168, None)])

if __name__ == "__main__":
    sys.exit(motor_musica.main(CFG, sys.argv[1:]))
