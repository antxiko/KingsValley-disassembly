#!/usr/bin/env python3
"""Dibuja las figuras del cartucho CON NOMBRE: el explorador, la momia, las
armas y los objetos.

docs/imagenes/sprites.png era un volcado en blanco y negro de las 2 KB de la
tabla de patrones de sprites, con filas vacias en medio y sin decir que era
cada cosa. Las filas vacias tenian dos causas, las dos comprobadas aqui:

1. Los TRES juegos de sprites del explorador -manos vacias (0x51e9), con el
   cuchillo (0x52a5) y con el pico (0x53d8)- se cargan en la MISMA direccion,
   0x1800, asi que en la VRAM solo puede haber uno a la vez.
2. Las figuras miradas hacia el otro lado NO estan en la ROM: se fabrican en
   caliente volteando bit a bit las que si estan (L_454C, 0x454c). El
   explorador tiene diez volteadas en 0x1b00 (patron 0x60) y la momia tres en
   0x1c40 (patron 0x88).

Los ROTULOS de esta lamina estan escritos con la TIPOGRAFIA DEL CARTUCHO: el
guion 0x467d que rellena_franja_borde carga en VRAM 0x2080, o sea el patron
0x10. Cada letra es su codigo ASCII menos 0x20, que es justo su numero de
patron (ver "The text is ASCII minus 0x20" en la pagina de hallazgos).

CREDITO
-------
Los nombres -momia, gema, pico, cuchillo, palanca, puerta giratoria- y las
tablas que dicen que pose es cada patron salen del desensamblado que Manuel
Pazos publico en 2009 (https://github.com/GuillianSeed/Kings-Valley), y estan
comprobados contra la tabla de atributos de sprites de una maquina de verdad
(tools/omsx_vram_sala.tcl).

Uso: figuras.py <rom> <org> <carpeta>
"""
import os
import sys

import pantallas

ORG = 0x4000
FONDO = (20, 20, 28)

# --- lo que dice el cartucho de cada figura --------------------------------
# framesProta (0x4d46): que sprite usa cada fotograma del explorador.
POSES_DEL_EXPLORADOR = (
    (0x00, "PIES JUNTOS"),
    (0x08, "ANDANDO"),
    (0x10, "PIES SEPARADOS"),
    (0x18, "ACCION 1"),
    (0x20, "ACCION 2"),
)
JUEGOS_DEL_EXPLORADOR = (
    (0, "CON LAS MANOS VACIAS"),
    (1, "CON EL CUCHILLO"),
    (2, "CON EL PICO"),
)
# El explorador son DOS sprites, uno encima del otro: el de arriba en color
# 0x0E y el de abajo en 0x06. Medido en la SAT real (sprites 4 y 5).
COLOR_ARRIBA = 0x0E
COLOR_ABAJO = 0x06

# framesMomia (0x70b6)
POSES_DE_LA_MOMIA = (
    (0x28, "PIES JUNTOS"),
    (0x2C, "PIE ATRAS"),
    (0x30, "PIES SEPARADOS"),
)
OTROS_SPRITES = (
    (0xE8, "NUBE GRANDE"),
    (0xEC, "NUBE PEQUENA"),
    (0xD4, "DESTELLO"),
    (0xD8, "LADRILLOS DE LA PUERTA"),
)
TIPOS_DE_MOMIA = 0x6D3C     # nibble alto velocidad, nibble bajo color

# Los OBJETOS no son sprites: son tiles del mapa. Aqui van con el numero de
# celda que les da el descriptor de nivel y el nombre de la tabla de 0x5d68.
OBJETOS = (
    ((0x43,), "GEMA AZUL OSCURO"),
    ((0x44,), "GEMA AZUL CLARO"),
    ((0x45,), "GEMA MAGENTA"),
    ((0x46,), "GEMA AMARILLA"),
    ((0x47,), "GEMA VERDE"),
    ((0x48,), "GEMA GRIS"),
    ((0x80,), "PICO"),
    ((0x30,), "CUCHILLO EN EL SUELO"),
    ((0x78, 0x77), "PALANCA"),
    ((0x50, 0x51), "PUERTA GIRATORIA"),
)
# Los cinco patrones del cuchillo mientras gira por el aire, framesCuchillo
# (0x588f). No son celdas de mapa: los escribe dibuja_entidad_si_visible
# directamente en la tabla de nombres.
GIRO_DEL_CUCHILLO = 0x588F

FUENTE_GUION = 0x467D
FUENTE_BASE = 0x2080        # VRAM: el patron 0x10


def _vram_con_fuente(rom, org):
    v = pantallas.Vram()
    pantallas.guion_x3(rom, org, v, FUENTE_GUION, FUENTE_BASE)
    return v


def escribe(px, fuente, texto, x, y, color=(150, 150, 165)):
    """Un rotulo con la tipografia del cartucho. Cada letra es su ASCII menos
    0x20, y ese numero ES su patron."""
    for i, ch in enumerate(texto):
        code = (ord(ch) - 0x20) & 0xFF
        # La fuente del cartucho solo trae CIFRAS (0x10-0x19) y MAYUSCULAS
        # (0x21-0x3A). Lo demas no es una letra sino un tile del juego, asi
        # que no se dibuja: el 0x1A, por ejemplo -que en ASCII menos 0x20
        # seria el dos puntos- es el signo de copyright.
        if not (0x10 <= code <= 0x19 or 0x21 <= code <= 0x3A):
            continue
        base = pantallas.BASE_PATRON + code * 8
        for fy in range(8):
            b = fuente.b[base + fy]
            for fx in range(8):
                if (b >> (7 - fx)) & 1:
                    iy, ix = y + fy, x + i * 8 + fx
                    if 0 <= iy < len(px) and 0 <= ix < len(px[0]):
                        px[iy][ix] = color


def sprite(px, vram, patron, x, y, color):
    """Un sprite de 16x16 desde la tabla de patrones de sprites: cuatro
    cuadrantes de 8x8 ordenados por COLUMNAS."""
    base = 0x1800 + patron * 8
    for cuadrante in range(4):
        cx, cy = (cuadrante // 2) * 8, (cuadrante % 2) * 8
        for fy in range(8):
            b = vram.b[(base + cuadrante * 8 + fy) & 0x3FFF]
            for fx in range(8):
                if (b >> (7 - fx)) & 1:
                    iy, ix = y + cy + fy, x + cx + fx
                    if 0 <= iy < len(px) and 0 <= ix < len(px[0]):
                        px[iy][ix] = pantallas.PALETA[color]


def tile(px, vram, patron, x, y, tercio=0):
    """Un tile de 8x8 de la tabla de patrones, con su color."""
    base = tercio * 0x800 + patron * 8
    for fy in range(8):
        forma = vram.b[pantallas.BASE_PATRON + base + fy]
        color = vram.b[pantallas.BASE_COLOR + base + fy]
        tinta = pantallas.PALETA[color >> 4]
        papel = pantallas.PALETA[color & 0x0F]
        for fx in range(8):
            iy, ix = y + fy, x + fx
            if 0 <= iy < len(px) and 0 <= ix < len(px[0]):
                px[iy][ix] = tinta if (forma >> (7 - fx)) & 1 else papel


def lamina(rom, org=ORG):
    """La lamina entera."""
    fuente = _vram_con_fuente(rom, org)
    import mapas

    ancho, alto = 8 * 58, 8 * 73
    px = [[FONDO] * ancho for _ in range(alto)]
    COL = 8 * 26            # la columna donde empiezan los dibujos
    ORO = (230, 210, 140)
    GRIS = (110, 110, 130)

    def titulo(texto, y):
        escribe(px, fuente, texto, 8, y, ORO)
        return y + 18

    def rotulo(texto, y, alto_dibujo=8):
        escribe(px, fuente, texto, 16, y + (alto_dibujo - 8) // 2)

    y = titulo("EL EXPLORADOR", 10)
    for lleva, nombre in JUEGOS_DEL_EXPLORADOR:
        vram = pantallas.vram_de_juego(rom, org, lleva)
        rotulo(nombre, y, 16)
        x = COL
        for patron, _p in POSES_DEL_EXPLORADOR:
            # son DOS sprites en la MISMA posicion, uno de cada color: asi es
            # como el MSX1 saca una figura de dos colores
            sprite(px, vram, patron, x, y, COLOR_ARRIBA)
            sprite(px, vram, patron + 4, x, y, COLOR_ABAJO)
            # y la misma pose mirando al otro lado: +0x60, la copia volteada
            sprite(px, vram, patron + 0x60, x + 20, y, COLOR_ARRIBA)
            sprite(px, vram, patron + 0x64, x + 20, y, COLOR_ABAJO)
            x += 48
        y += 26
    escribe(px, fuente, "CINCO POSES CADA UNA DE FRENTE Y VOLTEADA", 16, y,
            GRIS)
    y += 24

    vram = pantallas.vram_de_juego(rom, org, 0)
    y = titulo("LA MOMIA", y)
    rotulo("SUS TRES POSES", y, 16)
    x = COL
    for patron, _p in POSES_DE_LA_MOMIA:
        sprite(px, vram, patron, x, y, 0x0F)
        sprite(px, vram, patron + 0x60, x + 20, y, 0x0F)
        x += 48
    y += 26
    rotulo("LOS CINCO TIPOS", y, 16)
    x = COL
    for tipo in range(5):
        car = mapas._rb(rom, TIPOS_DE_MOMIA + tipo, org)
        sprite(px, vram, POSES_DE_LA_MOMIA[0][0], x, y, car & 0x0F)
        escribe(px, fuente, "%d" % (car >> 4), x + 4, y + 18, GRIS)
        x += 32
    y += 30
    escribe(px, fuente, "DEBAJO DE CADA UNA SU VELOCIDAD", 16, y, GRIS)
    y += 24

    y = titulo("LAS OTRAS FIGURAS", y)
    escribe(px, fuente, "NUBE GRANDE Y PEQUENA", 16, y)
    escribe(px, fuente, "DESTELLO Y LADRILLOS", 16, y + 10, GRIS)
    x = COL
    for patron, _nombre in OTROS_SPRITES:
        sprite(px, vram, patron, x, y, 0x0F)
        x += 32
    y += 30

    y = titulo("LAS ARMAS Y LOS OBJETOS", y)
    escribe(px, fuente, "NO SON SPRITES SINO TILES DEL MAPA", 16, y, GRIS)
    y += 14
    for celdas, nombre in OBJETOS:
        rotulo(nombre, y)
        x = COL
        for c in celdas:
            tile(px, vram, mapas.traduce_celda_a_patron(rom, c, org), x, y)
            x += 8
        y += 12
    rotulo("EL CUCHILLO EN EL AIRE", y)
    x = COL
    for k in range(5):
        tile(px, vram, mapas._rb(rom, GIRO_DEL_CUCHILLO + k, org), x, y)
        x += 12
    y += 26

    y = titulo("LA SALIDA", y)
    for i, nombre in enumerate(("CERRADA", "CERRANDOSE", "ABIERTA")):
        rotulo(nombre, y, 24)
        guion = mapas.ANIM_SALIDA[i]
        for f in range(3):
            for c in range(5):
                celda = mapas._rb(rom, guion + f * 5 + c, org)
                tile(px, vram, mapas.traduce_celda_a_patron(rom, celda, org),
                     COL + c * 8, y + f * 8)
        y += 32
    return px


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    carpeta = sys.argv[3]
    os.makedirs(carpeta, exist_ok=True)
    px = lamina(rom, org)
    salida = os.path.join(carpeta, "figuras.png")
    pantallas.png(salida, px, escala=2)
    print("  figuras   %s" % salida)
    return 0


if __name__ == "__main__":
    sys.exit(main())
