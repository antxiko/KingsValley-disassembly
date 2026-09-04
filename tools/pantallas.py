#!/usr/bin/env python3
"""Dibuja las pantallas completas de King's Valley desde los bytes del cartucho.

No hay ni una captura de emulador aqui dentro: se ejecuta EL INTERPRETE DE
GUIONES DEL PROPIO CARTUCHO sobre una VRAM de 16 KB en memoria, y luego se
revela esa VRAM como SCREEN 2.

EL LENGUAJE DE GUIONES (0x451a, `dibuja_guion` en el listado)
------------------------------------------------------------
Cada comando empieza por un byte B0:

    C = B0 & 0x7F
    si C != 0:
        si B0 != C  (bit 7 puesto) -> COPIA CRUDA de C bytes del guion
        si B0 == C  (bit 7 a cero) -> RELLENO: lee UN byte y lo repite C veces
    si C == 0:
        si B0 == 0x00 -> FIN del guion
        si B0 == 0x80 -> ENCADENA: lee un word con una direccion VRAM nueva,
                         rearma la escritura ahi y sigue con el mismo guion

El VDP autoincrementa la direccion despues de cada byte, asi que un guion
escribe un tramo continuo de VRAM. `dibuja_guion_con_direccion` (0x4514) es la
variante que lee la direccion inicial del propio guion, en vez de recibirla.

LA GEOMETRIA: R3 Y R4 VAN AL REVES DE LO HABITUAL
-------------------------------------------------
tabla_registros_vdp (0x45c0) vale 02 E2 0E 7F 07 76 03 E4. En SCREEN 2 los
registros 3 y 4 no son una direccion, son BASE + MASCARA:

    R3 = 0x7F -> bit 7 a 0   -> tabla de COLOR   en 0x0000 (mascara 0x7F: sin
                                                 restringir)
    R4 = 0x07 -> bit 2 a 1   -> tabla de PATRON  en 0x2000 (mascara 3: sin
                                                 restringir)
    R2 = 0x0E ->                tabla de NOMBRE  en 0x3800

O sea: los colores ABAJO y los patrones ARRIBA, al reves de la disposicion
tipica (patrones en 0x0000, colores en 0x2000). Leerlo al reves da formas
correctas y colores a franjas. Lo confirma el propio cartucho: 0x4831 dibuja
el logo con `ld hl,06300h`, y 0x6300 enmascarado a 14 bits es 0x2300, dentro
de la tabla de patrones; y 0x4837 rellena en 0x0300, dentro de la de color.

Uso: pantallas.py <rom> <org> <carpeta>
"""
import os
import struct
import sys
import zlib

ORG = 0x4000
VRAM_MASC = 0x3FFF

BASE_COLOR = 0x0000
BASE_PATRON = 0x2000
BASE_NOMBRE = 0x3800

# La paleta fija del TMS9918, tal cual.
PALETA = [
    (0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
    (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
    (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
    (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255),
]


class Vram:
    """Una VRAM de 16 KB con el mismo autoincremento que el VDP."""

    def __init__(self):
        self.b = bytearray(0x4000)
        self.p = 0
        self.tope = 0

    def arma(self, direccion):
        # SETWRT se queda con 14 bits: `and 3fh` sobre H (BIOS 0x0053).
        self.p = direccion & VRAM_MASC

    def escribe(self, valor):
        self.b[self.p] = valor & 0xFF
        if self.p > self.tope:
            self.tope = self.p
        self.p = (self.p + 1) & VRAM_MASC


def dibuja_guion(rom, org, vram, guion, direccion=None):
    """El interprete de 0x451a. Devuelve el guion ya consumido."""
    if direccion is not None:
        vram.arma(direccion)
    else:
        # dibuja_guion_con_direccion (0x4514): la direccion viene delante.
        lo = rom[guion - org]
        hi = rom[guion - org + 1]
        vram.arma(lo | (hi << 8))
        guion += 2
    while True:
        b0 = rom[guion - org]
        guion += 1
        cuenta = b0 & 0x7F
        if cuenta == 0:
            if b0 == 0x00:
                return guion
            # b0 == 0x80: encadena a otra direccion y sigue
            lo = rom[guion - org]
            hi = rom[guion - org + 1]
            guion += 2
            vram.arma(lo | (hi << 8))
            continue
        if b0 != cuenta:  # bit 7 puesto: copia cruda
            for _ in range(cuenta):
                vram.escribe(rom[guion - org])
                guion += 1
        else:  # bit 7 a cero: relleno
            valor = rom[guion - org]
            guion += 1
            for _ in range(cuenta):
                vram.escribe(valor)
    return guion


def guion_x3(rom, org, vram, guion, direccion):
    """dibuja_guion_x3_tercios (0x44f1): el mismo guion en los tres tercios."""
    for tercio in range(3):
        dibuja_guion(rom, org, vram, guion, direccion + tercio * 0x800)


def rellena_x3(vram, direccion, cuenta, valor):
    """rellena_x3_tercios (0x44e0)."""
    for tercio in range(3):
        vram.arma(direccion + tercio * 0x800)
        for _ in range(cuenta):
            vram.escribe(valor)


def rellena(vram, direccion, cuenta, valor):
    vram.arma(direccion)
    for _ in range(cuenta):
        vram.escribe(valor)


def escribe_guion_de_texto(rom, org, vram, guion, borrar=False):
    """El OTRO interprete, el de 0x4051. No tiene nada que ver con el de
    0x451a: aqui el guion empieza con un word que es la direccion VRAM, siguen
    caracteres sueltos, 0xFE cambia de direccion y sigue, y 0xFF acaba. Los
    caracteres van en ASCII MENOS 0x20 (los bytes 2B 2F 2E 21 2D 29 mas 0x20
    dan KONAMI), y se escriben tal cual en la tabla de nombres: el indice de
    tile de cada letra ES su codigo. Con borrar=True escribe 0x00 en vez del
    texto, que es como el cartucho lo hace desaparecer."""
    i = guion - org
    vram.arma(rom[i] | (rom[i + 1] << 8))
    i += 2
    while True:
        b = rom[i]
        i += 1
        if b == 0xFF:
            return
        if b == 0xFE:
            vram.arma(rom[i] | (rom[i + 1] << 8))
            i += 2
            continue
        vram.escribe(0x00 if borrar else b)


def _invierte(b):
    """0x4584: ocho `rr c` / `rla` seguidos dan el byte con los bits del
    reves. Es un ESPEJO HORIZONTAL de la fila de 8 pixeles, no una copia."""
    return int('{:08b}'.format(b)[::-1], 2)


def voltea_patrones(vram, origen, destino, cuantos):
    """L_4568 (FlipPatrones en el listado de Pazos): vuelca `cuantos`
    patrones de 8 bytes invirtiendo cada byte, y lo repite en los TRES
    tercios de la tabla. OJO: el `pop hl` de 0x457f recupera el origen
    ORIGINAL, no el avanzado, asi que los tres tercios se leen todos del
    PRIMERO; sale bien porque el cartucho escribe los tres iguales."""
    for tercio in range(3):
        d = destino + tercio * 0x800
        for i in range(cuantos * 8):
            vram.arma(d + i)
            vram.escribe(_invierte(vram.b[(origen + i) & VRAM_MASC]))


def voltea_sprites(vram, origen, destino, cuantos):
    """L_454C (flipSprites): el espejo de un sprite de 16x16 no es solo
    invertir los bytes, hay que INTERCAMBIAR las dos mitades. Eso lo hace el
    baile de 0x4556-0x455c: escribe 16 bytes, resta 0x20 a E -o sea retrocede
    16- y repite mientras el bit 4 de E siga a cero. Por eso pasandole
    destino=0x1b10 el sprite acaba en 0x1b00 con las columnas cambiadas."""
    for n in range(cuantos):
        base_o = origen + n * 0x20
        e = (destino + n * 0x20) & 0xFF
        d_alto = (destino + n * 0x20) & 0xFF00
        i = 0
        while True:
            for k in range(0x10):
                vram.arma(d_alto | ((e + k) & 0xFF))
                vram.escribe(_invierte(vram.b[(base_o + i) & VRAM_MASC]))
                i += 1
            e = (e - 0x10) & 0xFF
            if e & 0x10:
                break


def franja_de_patrones(vram, direccion, primero, cuantos):
    """escribe_franja_de_patrones (0x4866): indices consecutivos, y devuelve
    la fila siguiente (entrada + 0x20) y el indice siguiente."""
    vram.arma(direccion)
    a = primero
    for _ in range(cuantos):
        vram.escribe(a)
        a = (a + 1) & 0xFF
    return (direccion + 0x20) & 0xFFFF, a


def revela_screen2(vram):
    """Convierte la VRAM en una imagen de 256x192 pixeles."""
    px = [[(0, 0, 0)] * 256 for _ in range(192)]
    for fila in range(24):
        tercio = fila // 8
        for col in range(32):
            nombre = vram.b[BASE_NOMBRE + fila * 32 + col]
            base = tercio * 0x800 + nombre * 8
            for y in range(8):
                forma = vram.b[BASE_PATRON + base + y]
                color = vram.b[BASE_COLOR + base + y]
                tinta = PALETA[color >> 4]
                fondo = PALETA[color & 0x0F]
                for x in range(8):
                    bit = (forma >> (7 - x)) & 1
                    px[fila * 8 + y][col * 8 + x] = tinta if bit else fondo
    return px


def png(fn, px, escala=2):
    alto = len(px)
    ancho = len(px[0])
    filas = bytearray()
    for y in range(alto):
        for _ in range(escala):
            filas.append(0)
            for x in range(ancho):
                r, g, b = px[y][x]
                for _ in range(escala):
                    filas += bytes((r, g, b))
    def trozo(tipo, datos):
        return (struct.pack(">I", len(datos)) + tipo + datos
                + struct.pack(">I", zlib.crc32(tipo + datos) & 0xFFFFFFFF))
    cab = struct.pack(">IIBBBBB", ancho * escala, alto * escala, 8, 2, 0, 0, 0)
    with open(fn, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(trozo(b"IHDR", cab))
        f.write(trozo(b"IDAT", zlib.compress(bytes(filas), 9)))
        f.write(trozo(b"IEND", b""))



TABLA_ATRIBUTOS = 0x5D68
# tabla_5050_indice: los tres juegos de sprites del jugador (0x51e9 con las
# manos vacias, 0x52a5 con el cuchillo, 0x53d8 con el pico). Los tres se
# cargan en la MISMA direccion, 0x1800, asi que solo uno puede estar puesto.
TABLA_SPRITES_JUGADOR = 0x5050


def traduce_celda_a_patron(rom, org, celda):
    """traduce_celda_a_patron (0x5d52): el nibble ALTO de la celda (x2) saca un
    puntero de tabla_de_atributos y el nibble BAJO indexa dentro de la lista a
    la que apunta. Es lo que convierte el buffer de sala en numeros de tile."""
    alto = (celda >> 4) & 0x0F
    bajo = celda & 0x0F
    d = TABLA_ATRIBUTOS + alto * 2
    ptr = rom[d - org] | (rom[d - org + 1] << 8)
    return rom[ptr - org + bajo]


def rotulo_horizontal(vram, direccion, c, a):
    """rotulo_horizontal (0x76a7): un rotulo que se estira. Escribe el patron
    C en la celda de HL y rellena hacia un lado con C+1, bajando una fila
    (0x20) por vuelta y creciendo una celda cada vez, hasta pasar de 0x3A80.
    Con A=0 el relleno va hacia la izquierda; con A distinto de 0, hacia la
    derecha (el `dec hl` de 0x76b6 mas los dos `inc hl` de 0x76ba)."""
    b = 0
    hl = direccion
    while True:
        cursor = hl
        for _ in range(b):
            vram.arma(cursor)
            vram.escribe((c + 1) & 0xFF)
            cursor = (cursor - 1) & 0xFFFF
            if a != 0:
                cursor = (cursor + 2) & 0xFFFF
        b += 1
        vram.arma(cursor)
        vram.escribe(c)
        hl = (hl + 0x20) & 0xFFFF
        if hl >= 0x3A80:
            return


def rectangulo(rom, org, vram, guion, direccion, filas, ancho):
    """dibuja_rectangulo_vram (0x65af): filas de `ancho` bytes, con 0x20 de
    salto entre fila y fila."""
    i = guion - org
    for f in range(filas):
        vram.arma(direccion + f * 0x20)
        for _ in range(ancho):
            vram.escribe(rom[i])
            i += 1


def vram_de_juego(rom, org, lleva=0):
    """La VRAM del juego: prepara_sala_nueva (0x4fc9), EN SU ORDEN, con los
    dos volteos que antes faltaban. `lleva` es el nibble alto de 0xe144 -el
    objeto que lleva el jugador: 0 nada, 1 cuchillo, 2 pico-, que es lo que
    decide cual de los tres juegos de sprites se carga en 0x1800."""
    vram = Vram()
    guion_x3(rom, org, vram, 0x5613, 0x2200)         # patrones del juego
    guion_x3(rom, org, vram, 0x5754, 0x0228)         # y su color
    # 0x4ff0: quince patrones volteados de 0x2340 a 0x23b8. Son los que el
    # juego necesita en espejo: la puerta de salida y las escaleras que van
    # hacia el otro lado. Sin esto los tiles 0x77-0x85 salen en blanco.
    voltea_patrones(vram, 0x2340, 0x23B8, 0x0F)
    guion_x3(rom, org, vram, 0x57B8, 0x03B8)         # el color de los volteados
    hl = 0x2430
    for _ in range(6):
        guion_x3(rom, org, vram, 0x574A, hl)         # la MISMA gema, seis veces
        hl += 8
    guion_x3(rom, org, vram, 0x57CD, 0x0430)         # y seis colores distintos
    dibuja_guion(rom, org, vram, 0x5571)
    dibuja_guion(rom, org, vram, 0x5511)             # la momia, en 0x1940
    voltea_sprites(vram, 0x1940, 0x1C50, 3)          # 0x502e: la momia en espejo
    # repinta_marcador (0x5031): el juego de sprites del jugador que toque
    d = TABLA_SPRITES_JUGADOR + 2 * lleva
    dibuja_guion(rom, org, vram,
                 rom[d - org] | (rom[d - org + 1] << 8))
    voltea_sprites(vram, 0x1800, 0x1B10, 0x0A)       # y sus diez, en espejo
    escribe_guion_de_texto(rom, org, vram, 0x47AA)   # SCORE / HI / REST
    escribe_guion_de_texto(rom, org, vram, 0x480E)   # (c)KONAMI + PYRAMID
    return vram


def sala_completa(rom, org, nivel):
    """Un nivel ENTERO con sus graficos, a su ancho real (16 o 48 columnas
    segun cuantas bandas tenga), no recortado a la ventana de 32 que ve el
    jugador. Devuelve la imagen ya en pixeles."""
    vram = vram_de_juego(rom, org)
    grupo = ((nivel - 1) >> 2) & 3
    guion = 0x6DC4 + 9 * grupo
    hl = 0x0200
    for _ in range(5):
        guion_x3(rom, org, vram, guion, hl)
        hl += 8
    import graficos
    rejilla = graficos.mapa_de_sala(rom, nivel, org)
    ancho = len(rejilla[0])
    px = [[(0, 0, 0)] * (ancho * 8) for _ in range(22 * 8)]
    for f in range(22):
        # la fila f de la sala se dibuja en la fila f+1 de la pantalla, que es
        # donde la pone vuelca_la_vista (0x3820 = fila 1): de ahi sale el
        # TERCIO de la tabla de patrones que le toca a cada fila
        tercio = (f + 1) // 8
        for c in range(ancho):
            tile = traduce_celda_a_patron(
                rom, org, 0x12 if rejilla[f][c] else 0x00)
            base = tercio * 0x800 + tile * 8
            for y in range(8):
                forma = vram.b[BASE_PATRON + base + y]
                color = vram.b[BASE_COLOR + base + y]
                tinta = PALETA[color >> 4]
                fondo = PALETA[color & 0x0F]
                for x in range(8):
                    bit = (forma >> (7 - x)) & 1
                    px[f * 8 + y][c * 8 + x] = tinta if bit else fondo
    return px


def sala_dibujada(rom, org, nivel, pantalla=0):
    """Una sala de verdad, con sus graficos: monta la VRAM del marco de juego,
    desempaqueta la sala igual que carga_la_sala (pared=0x12, hueco=0x00, ver
    0x6af6) y vuelca la ventana de 22x32 celdas por vuelca_la_vista (0x5d31),
    traduciendo cada celda con traduce_celda_a_patron."""
    import graficos
    vram = vram_de_juego(rom, org)
    # columna_decorativa (0x6da0): el COLOR de los tiles 0x40-0x44 -los de la
    # pared y el suelo- no lo pone prepara_sala_nueva, lo pone esta rutina, y
    # DEPENDE DEL GRUPO DE CUATRO NIVELES: guion = 0x6dc4 + 9*grupo, con
    # grupo = ((nivel-1) >> 2) & 3. Por eso cada tanda de cuatro salas tiene
    # su propio color de piedra. Sin esto los tiles salen negro sobre negro.
    grupo = ((nivel - 1) >> 2) & 3
    guion = 0x6DC4 + 9 * grupo
    hl = 0x0200
    for _ in range(5):
        guion_x3(rom, org, vram, guion, hl)
        hl += 8
    rejilla = graficos.mapa_de_sala(rom, nivel, org)
    ancho = len(rejilla[0])
    for f in range(22):
        vram.arma(0x3820 + f * 0x20)
        for c in range(32):
            col = c + pantalla * 32
            # borra_sala (0x6d92) rellena de 0x14 todo lo que las bandas no
            # cubren, no de 0x00: por eso las salas de una sola banda tienen
            # fondo de verdad en las columnas de la derecha
            if col < ancho:
                celda = 0x12 if rejilla[f][col] else 0x00
            else:
                celda = 0x14
            vram.escribe(traduce_celda_a_patron(rom, org, celda))
    return vram


# --------------------------------------------------------------------------
# Las pantallas, cada una replicando la secuencia REAL de llamadas del
# cartucho. Los numeros de esta seccion salen del listado, no de probar.
# --------------------------------------------------------------------------

def pantalla_de_titulo(rom, org):
    """dibuja_grupo_del_titulo (0x42cc), mas el scroll del logo ya terminado."""
    vram = Vram()

    # prepara_scroll_del_logo (0x4823): el dibujo del logo de Konami en la
    # tabla de patrones (0x6300 -> 0x2300) y el relleno de color de 0x0300.
    guion_x3(rom, org, vram, 0x4874, 0x6300)
    rellena_x3(vram, 0x0300, 0xD8, 0xF0)

    # rellena_franja_borde (0x44cf)
    guion_x3(rom, org, vram, 0x467D, 0x2080)
    rellena_x3(vram, 0x0080, 0x180, 0xF0)

    # el resto del grupo del titulo
    guion_x3(rom, org, vram, 0x47A7, 0x0008)
    guion_x3(rom, org, vram, 0x490B, 0x2480)
    guion_x3(rom, org, vram, 0x4A97, 0x0480)
    hl = 0x44D8
    for _ in range(22):
        guion_x3(rom, org, vram, 0x4AAB, hl)
        hl += 0x10
    rellena_x3(vram, hl, 0x10, 0x40)

    # tarea_0_desplaza_logo (0x4842) hasta agotar los 14 pasos: el puntero de
    # nombre baja 0x20 en cada paso desde 0x3AAA, y en cada uno escribe tres
    # franjas de indices consecutivos (3, 11 y 12 celdas) desde 0x60.
    puntero = 0x3AAA
    for _ in range(14):
        puntero = (puntero - 0x20) & 0xFFFF
        fila, a = franja_de_patrones(vram, puntero, 0x60, 3)
        fila, a = franja_de_patrones(vram, fila, a, 11)
        fila, a = franja_de_patrones(vram, fila, a, 12)
        # el `xor a / call rellena_vram` de 0x485d, con BC=0x000C: borra las
        # doce celdas de la fila siguiente, que es lo que limpia el rastro que
        # el paso anterior dejo por debajo
        rellena(vram, fila, 0x0C, 0x00)

    # el guion de 0x47fe, que tarea_0 dibuja en 0x40db. OJO: este va con el
    # interprete de 0x451a (la llamada es a dibuja_guion_con_direccion), no
    # con el de texto, aunque acabe escribiendo letras en la tabla de nombres
    dibuja_guion(rom, org, vram, 0x47FE)
    # y el (c)KONAMI 1985 + PUSH SPACE KEY de cierra_aviso_titulo (0x43f0)
    escribe_guion_de_texto(rom, org, vram, 0x47C1)
    return vram


def pantalla_de_juego(rom, org):
    """prepara_sala_nueva (0x4fc9): el marco de la sala, sin sala dentro."""
    return vram_de_juego(rom, org)


def pantalla_final(rom, org):
    """tarea_10_pantalla_final (0x761e)."""
    vram = Vram()
    guion_x3(rom, org, vram, 0x76D6, 0x2480)
    guion_x3(rom, org, vram, 0x7707, 0x0480)
    rotulo_horizontal(vram, 0x391F, 0x90, 0)
    rotulo_horizontal(vram, 0x3A03, 0x92, 0)
    rotulo_horizontal(vram, 0x3A2B, 0x92, 0)
    rotulo_horizontal(vram, 0x3A04, 0x94, 1)
    rotulo_horizontal(vram, 0x3A2C, 0x94, 1)
    rectangulo(rom, org, vram, 0x7723, 0x3A1E, 3, 2)
    rellena(vram, 0x3A60, 0x20, 0x96)
    escribe_guion_de_texto(rom, org, vram, 0x47AA)
    # pinta_celdas_sueltas (0x7696): seis celdas de la fila 0x39xx con 0x97
    for k in range(6):
        bajo = rom[0x7729 - org + k]
        vram.arma(0x3900 | bajo)
        vram.escribe(0x97)
    return vram


def pantalla_de_sala(rom, org):
    """monta_pantalla_de_sala (0x773c)."""
    vram = Vram()
    guion_x3(rom, org, vram, 0x7836, 0x2600)
    guion_x3(rom, org, vram, 0x78DF, 0x0600)
    dibuja_guion(rom, org, vram, 0x7908)
    return vram


BASE_SPRITES = 0x1800
# Todos los guiones del cartucho cuyo primer word cae en 0x1800-0x1FFF, que
# es donde R6=0x03 pone la tabla de patrones de sprites (0x03 * 0x800). Entre
# los seis llenan las 2 KB completas: 64 sprites de 16x16.
GUIONES_DE_SPRITE = (
    (0x51E9, "marcador, herramienta 1 (tabla_5050_indice)"),
    (0x52A5, "marcador, herramienta 2"),
    (0x53D8, "marcador, herramienta 3"),
    (0x5511, "los que carga prepara_sala_nueva en 0x1940"),
    (0x5571, "los que carga prepara_sala_nueva en 0x1EA0"),
    (0x7908, "los de monta_pantalla_de_sala, en 0x1F20"),
)


def hoja_de_sprites(rom, org, columnas=16):
    """Los sprites de 16x16 que repinta_marcador (0x5031) carga en la tabla de
    patrones de sprites. Los tres guiones de tabla_5050_indice empiezan por el
    word 00 18 = VRAM 0x1800, que es justo donde R6=0x03 pone esa tabla
    (0x03 * 0x800). R1 vale 0xE2, con el bit 1 puesto: sprites de 16x16, o sea
    32 bytes cada uno, en cuatro cuadrantes de 8x8 por COLUMNAS (arriba-izq,
    abajo-izq, arriba-der, abajo-der)."""
    vram = Vram()
    for guion, _que in GUIONES_DE_SPRITE:
        dibuja_guion(rom, org, vram, guion)
    cuantos = 64  # las 2 KB de la tabla, a 32 bytes por sprite de 16x16
    filas = (cuantos + columnas - 1) // columnas
    px = [[(20, 20, 28)] * (columnas * 17) for _ in range(filas * 17)]
    for n in range(cuantos):
        base = BASE_SPRITES + n * 32
        ox = (n % columnas) * 17
        oy = (n // columnas) * 17
        for cuadrante in range(4):
            cx = (cuadrante // 2) * 8
            cy = (cuadrante % 2) * 8
            for y in range(8):
                b = vram.b[base + cuadrante * 8 + y]
                for x in range(8):
                    if (b >> (7 - x)) & 1:
                        px[oy + cy + y][ox + cx + x] = (255, 255, 255)
    return px, cuantos


PANTALLAS = [
    ("titulo", pantalla_de_titulo),
    ("marco_de_juego", pantalla_de_juego),
    ("pantalla_final", pantalla_final),
    ("pantalla_de_sala", pantalla_de_sala),
]


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    carpeta = sys.argv[3]
    os.makedirs(carpeta, exist_ok=True)
    # el ROTULO: el recorte de la pantalla de titulo donde el cartucho pinta
    # su logotipo. No es un montaje: son las mismas filas de la misma VRAM
    px_tit = revela_screen2(pantalla_de_titulo(rom, org))
    recorte = [fila[9 * 8:24 * 8] for fila in px_tit[6 * 8:12 * 8]]
    png(os.path.join(carpeta, "rotulo.png"), recorte, escala=4)
    print("  rotulo    %s" % os.path.join(carpeta, "rotulo.png"))

    # Las salas ya no se dibujan aqui: las dibuja tools/mapas.py, que ademas
    # de la pared mete las gemas, las escaleras, los picos, los cuchillos, las
    # puertas y las momias. Y la hoja de sprites la sustituye
    # tools/figuras.py, que ademas dice que es cada figura.
    for nombre, fn in PANTALLAS:
        vram = fn(rom, org)
        px = revela_screen2(vram)
        salida = os.path.join(carpeta, "%s.png" % nombre)
        png(salida, px)
        usados = sum(1 for b in vram.b[BASE_NOMBRE:BASE_NOMBRE + 768] if b)
        print("  %-18s %s  (%d celdas de nombre distintas de 0)"
              % (nombre, salida, usados))
    return 0


if __name__ == "__main__":
    sys.exit(main())
