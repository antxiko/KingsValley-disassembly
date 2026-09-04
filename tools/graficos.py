"""Decodifica el MAPA DE PARED/HUECO de las 15 salas desde la ROM.

L_6A90-L_6D67 (la rutina que prepara una sala) no dibuja en VRAM: desempaqueta
bit a bit un patron de pared en el buffer de RAM 0xE700+. Ese calculo se
replica aqui exactamente igual -tabla_de_habitaciones, patrones_pared_tipo0..3
de 44 bytes cada uno, hasta 4 bandas de 16 columnas por sala-.

Comprobado contra un volcado de RAM real, no solo por los opcodes:
tools/omsx_dump_sala.tcl pone un breakpoint en 0x6b09 (fin del desempaquetado
de una banda) y vuelca 0xE700+; decodificar esos mismos bytes con las
funciones de aqui da CERO diferencias en las 352 celdas de la sala 1 (la unica
alcanzada forzando pulsaciones al azar). Ver kingsvalley.notes, seccion
"CORRECCION (2026-09-03, tanda de graficos.py)".

Este modulo da la REJILLA (1 pared / 0 hueco) y la pinta con un color de
esquema. Para dibujar las salas con sus graficos de verdad -y el logotipo, los
sprites y las pantallas de menu- esta tools/pantallas.py, que ejecuta los dos
interpretes de guiones del cartucho sobre una VRAM en memoria. Es el que usa
la web; este se conserva porque su decodificador de rejilla es el que esta
comprobado contra RAM real, y pantallas.py lo importa.

Uso: graficos.py <rom> <org> <carpeta>
"""
import os
import struct
import sys
import zlib

ORG = 0x4000
TABLA_HABITACIONES = 0x6D68
NUM_NIVELES = 15
FILAS = 22
ANCHO_BANDA = 16
STRIDE_PATRON = 44

PARED = (222, 222, 230)
HUECO = (26, 24, 34)


def _rb(rom, addr, org):
    return rom[addr - org]


def _rw(rom, addr, org):
    return _rb(rom, addr, org) | (_rb(rom, addr + 1, org) << 8)


def tabla_de_habitaciones(rom, org=ORG):
    """Las 21 palabras de 0x6d68: 15 indexadas por nivel, las 4 ultimas
    reutilizadas como base de cada tipo de pared (ver L_6a90/L_6ac8)."""
    return [_rw(rom, TABLA_HABITACIONES + 2 * i, org) for i in range(21)]


def descriptores_de_sala(rom, ptr, org=ORG):
    """Hasta 4 bytes descriptor de sala, con la misma salida anticipada que
    L_6ABC (0x6b10-6b16): si el nibble alto del SIGUIENTE byte es 3, para."""
    de = ptr
    descs = []
    for _ in range(4):
        b = _rb(rom, de, org)
        descs.append(b)
        de += 1
        if (_rb(rom, de, org) & 0xF0) == 0x30:
            break
    return descs


def patron_de_pared(rom, base, indice, org=ORG):
    """22 filas x 16 celdas (2 bytes/fila, bit MSB primero) -> 1 pared/0 hueco.

    Replica exacta de L_6ae9-L_6b08: por cada uno de los 44 bytes del
    patron, sus 8 bits (empezando por el mas significativo, que es el que
    `rl c` saca primero) se convierten cada uno en una celda.
    """
    addr = base + STRIDE_PATRON * indice
    filas = []
    for _r in range(FILAS):
        fila = []
        for _k in range(2):
            byte = _rb(rom, addr, org)
            addr += 1
            for bit in range(7, -1, -1):
                fila.append((byte >> bit) & 1)
        filas.append(fila)
    return filas


def mapa_de_sala(rom, nivel, org=ORG):
    """La rejilla completa de una sala: una banda de 16 columnas por byte
    descriptor, pegadas en orden -igual que L_6ABC las coloca en 0xE700+
    (banda i en la columna 16*i)-."""
    tabla = tabla_de_habitaciones(rom, org)
    bases_pared = tabla[15:19]
    ptr = tabla[nivel - 1]
    bandas = []
    for d in descriptores_de_sala(rom, ptr, org):
        tipo, indice = (d >> 4) & 0xF, d & 0xF
        if tipo >= 4:
            # SUPOSICION (ver .notes): tipos 4/5 caen dentro de codigo ya
            # clasificado y ningun nivel real los usa; banda vacia si aparecen.
            bandas.append([[0] * ANCHO_BANDA for _ in range(FILAS)])
            continue
        bandas.append(patron_de_pared(rom, bases_pared[tipo], indice, org))
    return [sum((banda[f] for banda in bandas), []) for f in range(FILAS)]


def png(fn, grid, escala=8):
    alto, ancho = len(grid), len(grid[0])
    w, h = ancho * escala, alto * escala
    filas_px = []
    for fila in grid:
        linea = bytearray()
        for celda in fila:
            linea += bytes(PARED if celda else HUECO) * escala
        for _ in range(escala):
            filas_px.append(bytes(linea))
    raw = b"".join(b"\0" + f for f in filas_px)

    def chunk(t, d):
        return (struct.pack(">I", len(d)) + t + d
                + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF))
    with open(fn, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                 + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                 + chunk(b"IDAT", zlib.compress(raw))
                 + chunk(b"IEND", b""))


def comprueba(ruta_rom, org, carpeta_volcados):
    """Decodifica cada volcado de tools/omsx_dump_sala.tcl y lo compara
    celda a celda con lo que calculan aqui las mismas formulas."""
    import glob
    rom = open(ruta_rom, "rb").read()
    vistos = fallos = 0
    for fn in sorted(glob.glob(os.path.join(carpeta_volcados, "sala_*.txt"))):
        lineas = open(fn).read().split("\n")
        nivel = int(lineas[0].split("=")[1])
        dump = [int(x, 16) for x in lineas[1:] if x.strip()]
        grid = mapa_de_sala(rom, nivel, org)
        ancho = len(grid[0])
        d = 0
        for r in range(FILAS):
            for c in range(ancho):
                off = r * 0x60 + c
                esperado = 0x12 if grid[r][c] else 0x00
                if off >= len(dump) or dump[off] != esperado:
                    d += 1
        vistos += 1
        estado = "OK" if d == 0 else "%d DIFERENCIAS" % d
        print("  %s (nivel %d): %s" % (os.path.basename(fn), nivel, estado))
        fallos += d
    print("%d volcados, %d diferencias" % (vistos, fallos))
    return 0 if fallos == 0 else 1


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "--comprueba":
        if len(sys.argv) >= 5 and sys.argv[1] == "--comprueba":
            return comprueba(sys.argv[2], int(sys.argv[3], 0), sys.argv[4])
        print(__doc__)
        return 0
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    carpeta = sys.argv[3]
    os.makedirs(carpeta, exist_ok=True)

    for nivel in range(1, NUM_NIVELES + 1):
        grid = mapa_de_sala(rom, nivel, org)
        nombre = "sala_%02d.png" % nivel
        png(os.path.join(carpeta, nombre), grid)
        print("  %s (%d x %d celdas)" % (nombre, len(grid[0]), len(grid)))
    print("  (el rotulo y las pantallas de menu siguen sin decodificar: "
          "falta el lenguaje de guiones de L_451a/.../L_458f)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
