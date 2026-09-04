#!/usr/bin/env python3
"""Las figuras del cartucho, montadas como las monta el.

Una figura del jugador NO es un sprite: son CINCO sprites de 16x16 apilados.
Lo dice 0x58A9, que tras buscar la postura recorre cinco punteros seguidos
(`ld b,005h`) descomprimiendo 32 bytes en cada vuelta, y 0x58D4, que salta
esos diez bytes (`ld a,00ah`) para llegar al sexto puntero: la lista de las
cinco parejas (y,x) que dicen donde va cada uno.

    0x5961  tabla de 58 entradas, una por postura; seis estan a cero
            (indices 26 a 31), que son huecos de verdad, no relleno
    0x59D5  las descripciones, doce bytes cada una:
              cinco punteros a patron + un puntero a las cinco parejas (y,x)
    0x5B91  los patrones comprimidos y las listas de parejas, mezclados

El descompresor es 0x5932 y escribe siempre 32 bytes, con una sola regla:

    0x00 [n]   escribe n bytes a cero
    resto      el byte, tal cual

Los 32 bytes de un sprite de 16x16 del TMS9918 son el cuadrante izquierdo
entero (16 filas) y luego el derecho.

El color de cada uno de los cinco sale de la ficha del jugador, no de aqui: la
ficha se copia de 0x57EB (0x57BE la reparte en cuatro, de 41 bytes) y sus
bytes 0x10 a 0x23 son los veinte de atributos que 0x5920 vuelca al VDP, o sea
cuatro por sprite -y, x, patron y color-.

Uso: sprites.py <rom> mapa            que ocupa cada cosa, y que queda suelto
     sprites.py <rom> png <carpeta>   dibuja las figuras montadas
"""
import os
import sys

ORG = 0x4000
TABLA_POSTURAS = 0x5961
TABLA_PELOTA = 0x5528
FICHAS = 0x57EB          # las cuatro fichas de 41 bytes que reparte 0x57BE
LARGO_FICHA = 0x29

# Los quince colores del TMS9918, en RGB. Son los valores que publico Texas y
# que openMSX usa; el 0 es transparente y aqui sale como fondo.
PALETA = [
    (0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
    (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
    (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
    (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255),
]


def descomprime(rom, pos):
    """Devuelve (32 bytes, cuantos bytes de ROM se han gastado)."""
    fuera = bytearray()
    ini = pos
    while len(fuera) < 32:
        b = rom[pos]
        if b == 0:
            # 0 vale 256: 0x5943 carga la cuenta en B y la gasta con un djnz,
            # que decrementa antes de comprobar. Un `00 00` al final de un
            # patron es el modo barato de rellenar de ceros lo que quede.
            n = rom[pos + 1] or 256
            pos += 2
            fuera.extend(b"\0" * min(n, 32 - len(fuera)))
        else:
            fuera.append(b)
            pos += 1
    return bytes(fuera), pos - ini


def pal(rom, dir_):
    o = dir_ - ORG
    return rom[o] | (rom[o + 1] << 8)


def colores_de_las_fichas(rom):
    """Los cinco colores de sprite de cada uno de los cuatro jugadores."""
    fuera = []
    for j in range(4):
        o = FICHAS - ORG + j * LARGO_FICHA + 0x10
        fuera.append([rom[o + k * 4 + 3] & 0x0F for k in range(5)])
    return fuera


def posturas(rom):
    """[(indice, direccion de la descripcion, [5 patrones], [5 (y,x)])]."""
    n = (pal(rom, TABLA_POSTURAS) - TABLA_POSTURAS) // 2
    fuera = []
    for i in range(n):
        d = pal(rom, TABLA_POSTURAS + i * 2)
        if d == 0:                       # hueco de verdad de la tabla
            fuera.append((i, 0, None, None))
            continue
        pats = [pal(rom, d + k * 2) for k in range(5)]
        pos_ = pal(rom, d + 10)
        o = pos_ - ORG
        # (y,x) se SUMAN a la posicion del jugador con aritmetica de ocho
        # bits (0x58FF `add a,b`), asi que son desplazamientos con signo. El
        # 0xCF de la Y es la marca de escondido y no se toca (0x58FB).
        def con_signo(v):
            return v - 256 if v > 127 else v
        parejas = [(rom[o + k * 2] if rom[o + k * 2] == 0xCF
                    else con_signo(rom[o + k * 2]),
                    con_signo(rom[o + k * 2 + 1])) for k in range(5)]
        fuera.append((i, d, pats, parejas))
    return fuera


def pelotas(rom):
    """Los cinco tamanos de la pelota, en pares (subiendo, bajando)."""
    fuera = []
    for i in range(5):
        fuera.append(tuple(pal(rom, TABLA_PELOTA + i * 4 + k * 2)
                           for k in (0, 1)))
    return fuera


def rejilla(patron):
    """Los 32 bytes a una matriz de 16x16, deshaciendo los dos cuadrantes."""
    m = [[0] * 16 for _ in range(16)]
    for y in range(16):
        izq, der = patron[y], patron[16 + y]
        for x in range(8):
            m[y][x] = (izq >> (7 - x)) & 1
            m[y][8 + x] = (der >> (7 - x)) & 1
    return m


def monta(rom, pats, parejas, colores):
    """Las cinco capas puestas en su sitio, como las pone el VDP.

    Las parejas son (y, x) tal como van al atributo de sprite; se toman
    relativas a la menor de todas, que es lo que hace el juego al sumarles la
    posicion del jugador. Un 0xCF en la Y significa escondido (0x58FB).
    """
    piezas = [(y, x, rom and descomprime(rom, p - ORG)[0], c)
              for (y, x), p, c in zip(parejas, pats, colores)]
    vivas = [t for t in piezas if t[0] != 0xCF]
    if not vivas:
        return None
    y0 = min(t[0] for t in vivas)
    x0 = min(t[1] for t in vivas)
    an = max(t[1] for t in vivas) - x0 + 16
    al = max(t[0] for t in vivas) - y0 + 16
    lienzo = [[0] * an for _ in range(al)]
    # El VDP pinta el sprite 0 por encima de los demas, asi que se dibuja de
    # atras hacia delante para que el primero quede arriba.
    for y, x, patron, color in reversed(vivas):
        m = rejilla(patron)
        for dy in range(16):
            for dx in range(16):
                if m[dy][dx]:
                    lienzo[y - y0 + dy][x - x0 + dx] = color
    return lienzo


def png(ruta, lienzos, cols, escala=3, margen=3, fondo=(20, 20, 28)):
    import struct
    import zlib

    if not lienzos:
        return
    anc = max(len(l[0]) for l in lienzos) + margen * 2
    alt = max(len(l) for l in lienzos) + margen * 2
    filas = (len(lienzos) + cols - 1) // cols
    an, al = cols * anc * escala, filas * alt * escala
    img = [[fondo] * an for _ in range(al)]
    for i, l in enumerate(lienzos):
        cx = (i % cols) * anc + margen
        cy = (i // cols) * alt + margen
        for y, fila in enumerate(l):
            for x, c in enumerate(fila):
                if not c:
                    continue
                rgb = PALETA[c]
                for dy in range(escala):
                    for dx in range(escala):
                        img[(cy + y) * escala + dy][(cx + x) * escala + dx] = rgb
    crudo = b""
    for fila in img:
        crudo += b"\0" + b"".join(bytes(p) for p in fila)

    def trozo(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))

    with open(ruta, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(trozo(b"IHDR", struct.pack(">IIBBBBB", an, al, 8, 2, 0, 0, 0)))
        f.write(trozo(b"IDAT", zlib.compress(crudo, 9)))
        f.write(trozo(b"IEND", b""))


def cobertura(rom):
    """Que bytes del bloque de figuras quedan explicados, y por que."""
    marca = {}

    def pon(ini, n, quien):
        for a in range(ini, ini + n):
            marca[a] = quien

    ps = posturas(rom)
    pon(TABLA_POSTURAS, len(ps) * 2, "tabla de posturas")
    for i, d, pats, parejas in ps:
        if not d:
            continue
        pon(d, 12, "descripcion")
        pon(pal(rom, d + 10), 10, "parejas (y,x)")
        for p in pats:
            pon(p, descomprime(rom, p - ORG)[1], "patron")
    for a, b in pelotas(rom):
        for p in (a, b):
            pon(p, descomprime(rom, p - ORG)[1], "patron de pelota")
    pon(TABLA_PELOTA, 20, "tabla de la pelota")
    return marca


def main():
    if len(sys.argv) < 3:
        print(__doc__.strip())
        return 2
    rom = open(sys.argv[1], "rb").read()

    if sys.argv[2] == "mapa":
        ps = posturas(rom)
        vivas = [p for p in ps if p[1]]
        unicas = sorted({p[1] for p in vivas})
        print("tabla de posturas 0x%04X: %d entradas, %d a cero, %d descripciones"
              " distintas" % (TABLA_POSTURAS, len(ps), len(ps) - len(vivas),
                              len(unicas)))
        print("descripciones 0x%04X..0x%04X" % (unicas[0], unicas[-1] + 12))
        marca = cobertura(rom)
        ini, fin = TABLA_POSTURAS, 0x678D
        sueltos = [a for a in range(ini, fin) if a not in marca]
        print("bloque 0x%04X..0x%04X: %d de %d bytes explicados, %d sueltos"
              % (ini, fin, fin - ini - len(sueltos), fin - ini, len(sueltos)))
        if sueltos:
            tramos, a0 = [], sueltos[0]
            for a, b in zip(sueltos, sueltos[1:] + [None]):
                if b != a + 1:
                    tramos.append((a0, a + 1))
                    a0 = b
            print("tramos sueltos (%d):" % len(tramos))
            for a, b in tramos[:30]:
                print("  0x%04X..0x%04X  (%d)" % (a, b, b - a))
        fuera = [a for a in marca if not (ini <= a < fin)]
        if fuera:
            print("ojo: %d bytes marcados FUERA del bloque (0x%04X..0x%04X)"
                  % (len(fuera), min(fuera), max(fuera) + 1))

    elif sys.argv[2] == "png":
        carpeta = sys.argv[3]
        os.makedirs(carpeta, exist_ok=True)
        # Una hoja por ficha: las cuatro llevan los mismos dibujos pero
        # colores distintos, y ahi esta el pelo -negro en las fichas 1 y 2,
        # magenta en las 3 y 4-.
        vistas = []
        for _, d, pats, parejas in posturas(rom):
            if d:
                vistas.append((pats, parejas))
        for j, col in enumerate(colores_de_las_fichas(rom)):
            lienzos = [l for l in (monta(rom, p, q, col) for p, q in vistas) if l]
            nombre = "posturas_jugador%d.png" % (j + 1)
            png(os.path.join(carpeta, nombre), lienzos, cols=10)
            print("%s: %d figuras, colores %s" % (nombre, len(lienzos), col))
        # y la hoja de siempre, con la ficha 1
        png(os.path.join(carpeta, "posturas.png"),
            [l for l in (monta(rom, p, q, colores_de_las_fichas(rom)[0])
                         for p, q in vistas) if l], cols=10)

        # los cinco tamanos de la pelota
        bolas = []
        for a, b in pelotas(rom):
            for q in (a, b):
                bolas.append([[10 if c else 0 for c in f]
                              for f in rejilla(descomprime(rom, q - ORG)[0])])
        png(os.path.join(carpeta, "pelota.png"), bolas, cols=10, escala=4)
        print("pelota.png: %d dibujos (cinco tamanos, subiendo y bajando)"
              % len(bolas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
