#!/usr/bin/env python3
"""El interprete de guiones de dibujo compartido, rehecho en Python.

DECODIFICADO de verdad leyendo el codigo (no es el fichero de Tennis: esta
version es la real de King's Valley, con su propio formato de opcodes).
La cadena de rutinas es L_44F1 -> L_451A -> L_4536(SETWRT) -> L_451D/L_4529
-> L_44C3 (copia cruda) / L_44BC (relleno), y L_4514 es un envoltorio que
antes de entrar en L_451A lee ademas una direccion de VRAM de dos bytes al
principio del guion.

  ENTRADA "directa" (L_451A, usada por L_44F1 con HL=VRAM ya puesto por
  quien llama):
      SETWRT(HL)
      bucle:
        B0 = byte en (DE); DE += 1
        si B0 == 0x00: fin del guion
        cuenta = B0 & 0x7f
        si bit 7 de B0 esta puesto (B0 >= 0x80):    -- COPIA CRUDA
            se leen 'cuenta' bytes seguidos del guion y se escriben tal
            cual en VRAM (uno a uno, L_44C3)
        si no (B0 = 0x01..0x7f):                    -- RELLENO
            se lee UN byte del guion y se escribe 'cuenta' veces en VRAM
            (L_44BC + el bucle de relleno L_44AE)
        vuelve al bucle

  ENTRADA "con direccion" (L_4514, usada por ejemplo desde la tabla de
  0x5050): los DOS primeros bytes del guion son la direccion de VRAM en
  little-endian (asi la lee `ex de,hl / ld e,(hl) / inc hl / ld d,(hl)`);
  tras esos dos bytes sigue exactamente el mismo formato de arriba.

Confirmado en el propio codigo (0x4514-0x45c0 del cartucho), no adivinado.
L_44F1 ademas repite el MISMO guion completo TRES veces, cada vez en una
direccion de VRAM 0x800 mas alta (el reparto por tercios de SCREEN 2, igual
que en Stardust): `push de / call L_451A / ld de,0800h / add hl,de / pop de`
-- el DE que se guarda con `push de` es el que se restaura, asi que las tres
pasadas leen el guion desde el mismo principio.
"""
import sys

ORG = 0x4000


class Vram:
    """8 KB (screen 2 real) de VRAM y el puntero de escritura (autoincrementa)."""

    def __init__(self, tam=0x4000):
        self.b = bytearray(tam)
        self.tam = tam
        self.p = 0
        self.tocado = bytearray(tam)

    def sitio(self, dir_):
        self.p = dir_ & (self.tam - 1)

    def escribe(self, v):
        self.b[self.p] = v
        self.tocado[self.p] = 1
        self.p = (self.p + 1) % self.tam


def guion(rom, pos, vram=None, limite=None):
    """Ejecuta el cuerpo del guion (sin direccion inicial). Devuelve la
    posicion tras el 0x00 de cierre."""
    limite = limite if limite is not None else len(rom)
    while True:
        if pos >= limite:
            raise ValueError("guion sin cierre 0x00 antes de 0x%04X" % (limite + ORG))
        b0 = rom[pos]
        pos += 1
        if b0 == 0x00:
            return pos
        cuenta = b0 & 0x7F
        if b0 & 0x80:                                   # copia cruda
            for _ in range(cuenta):
                v = rom[pos]
                pos += 1
                if vram:
                    vram.escribe(v)
        else:                                            # relleno
            v = rom[pos]
            pos += 1
            if vram:
                for _ in range(cuenta):
                    vram.escribe(v)


def guion_con_direccion(rom, pos, vram=None, limite=None):
    """L_4514: dos bytes de direccion VRAM (little-endian) y luego el guion."""
    dir_ = rom[pos] | (rom[pos + 1] << 8)
    pos += 2
    if vram:
        vram.sitio(dir_)
    return dir_, guion(rom, pos, vram, limite)


def main():
    if len(sys.argv) < 4:
        print(__doc__.strip())
        print("\nUso: guiones.py <rom> directo|condireccion <dir_hex> [vram_dir_hex]")
        return 2
    rom = open(sys.argv[1], "rb").read()
    modo = sys.argv[2]
    dir_ = int(sys.argv[3], 16)
    pos = dir_ - ORG
    v = Vram()
    if modo == "condireccion":
        vdir, fin = guion_con_direccion(rom, pos, v)
        print("guion con direccion en 0x%04X: VRAM destino 0x%04X, cuerpo hasta 0x%04X (%d bytes totales)"
              % (dir_, vdir, fin + ORG, fin - pos))
    else:
        if len(sys.argv) > 4:
            v.sitio(int(sys.argv[4], 16))
        fin = guion(rom, pos, v)
        print("guion directo en 0x%04X: hasta 0x%04X (%d bytes)" % (dir_, fin + ORG, fin - pos))
    print("bytes de VRAM tocados: %d" % sum(v.tocado))
    return 0


if __name__ == "__main__":
    sys.exit(main())
