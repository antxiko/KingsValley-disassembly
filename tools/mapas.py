#!/usr/bin/env python3
"""Descomprime la PIRAMIDE ENTERA de cada nivel desde los bytes del cartucho.

graficos.py saca solo el mapa de pared/hueco. Aqui se lee el descriptor
COMPLETO -el mismo que carga_la_sala (0x6a90) y reparte_entidades_de_la_sala
(0x6b1a) recorren- y se reconstruye el buffer de mapa de la RAM tal y como
queda justo antes del primer fotograma: ladrillos, escaleras, gemas con sus
destellos, picos, cuchillos, puertas giratorias y las puertas de salida, mas
las posiciones de partida de las momias.

EL DESCRIPTOR DE UN NIVEL (puntero en tabla_de_habitaciones, 0x6d68)
--------------------------------------------------------------------
    bandas      1 byte cada una, hasta 4; nibble alto = tipo de pared
                (indexa la cola de la tabla, 0x6d86), nibble bajo = patron
                dentro de ese tipo. La lista TERMINA en la banda cuyo nibble
                alto vale 3, y esa banda TAMBIEN se desempaqueta.
    puertas     4 entradas. 0xFF = no existe (1 byte). Si existe, 3 bytes:
                Y, X (bit 0 = pantalla), y un byte con la piramide de destino
                (nibble alto) y la direccion de la flecha (nibble bajo).
    momias      1 byte de cuenta + 3 por momia: Y, X (bit 0 = pantalla), tipo.
    gemas       1 byte de cuenta + 3 por gema: color (nibble alto), Y, X.
    cuchillos   1 byte de cuenta + 2 por cuchillo: Y, X.
    picos       1 byte de cuenta + 2 por pico: Y, X.
    giratorias  1 byte de cuenta + 3 por puerta: altura (bits 2-1), Y, X
                (bit 2 = pantalla, bits 1-0 = sentido de giro).
    trampas     1 byte de cuenta + 2 por muro trampa: Y, X.
    escaleras   1 byte de cuenta + 2 por escalera: Y, X (bit 0 = sentido,
                bit 1 = pantalla).

EL BUFFER DE MAPA
-----------------
23 filas de 96 celdas desde 0xE700, con la fila 0 tapada por el marcador.
La celda de unas coordenadas es (Y>>3)*96 + ((pantalla*256 + X)>>3), que es
lo que calcula 0x6df6. El nibble alto de cada celda dice de que familia es y
el bajo indexa dentro de ella: eso lo traduce traduce_celda_a_patron (0x5d52)
con la tabla de 0x5d68.

CREDITO
-------
Los NOMBRES de los elementos -gema, pico, cuchillo, momia, puerta giratoria,
muro trampa, palanca- y la estructura del descriptor salen del desensamblado
que Manuel Pazos publico en 2009 (https://github.com/GuillianSeed/Kings-Valley).
Cada direccion y cada campo de este fichero esta comprobado despues contra
nuestros propios bytes; lo que no cuadraba esta dicho en el .notes.

Uso: mapas.py <rom> <org> <carpeta>
"""
import os
import sys

ORG = 0x4000
TABLA_HABITACIONES = 0x6D68     # indexPiramides
TABLA_TIPOS_PARED = 0x6D86      # la cola de la misma tabla: 4 tipos de pared
TABLA_ATRIBUTOS = 0x5D68        # indexTiles, la que usa traduce_celda_a_patron

FILAS = 22                      # las que desempaqueta carga_la_sala (0x6ae5)
FILAS_BUFFER = 23               # una mas: la que asoma por abajo
# OJO CON LA FILA 0: el desempaquetado escribe 22 filas desde 0xE700, pero la
# ventana que vuelca coloca_al_jugador_en_la_sala (0x6cc5) empieza en 0xE760,
# UNA FILA MAS ABAJO. O sea que la primera fila del patron de pared NO SE VE
# nunca, y la ultima fila de la pantalla es la fila 22, que nadie desempaqueta
# y se queda con el 0x14 de borra_sala: el borde inferior.
PRIMERA_FILA_VISIBLE = 1
ANCHO_BUFFER = 96               # el stride de una fila: tres pantallas de 32
ANCHO_BANDA = 16
STRIDE_PATRON = 44

# Los identificadores de celda que este fichero escribe, con el nombre que
# les da la tabla de 0x5d68 (ver el credito de la cabecera).
CELDA_VACIA = 0x00
CELDA_LADRILLO = 0x12
CELDA_FONDO = 0x14              # con lo que borra_sala (0x6d92) rellena
CELDA_ESCALERA_FIN = 0x15       # peldano de arranque, sobre la plataforma
CELDA_PELDANO = 0x20
CELDA_CUCHILLO = 0x30
CELDA_BRILLO = 0x40             # 0x40 arriba, 0x41 izquierda, 0x42 derecha
CELDA_GEMA = 0x43               # +0..5 segun el color
CELDA_GIRATORIA = 0x50
CELDA_PICO = 0x80

COLORES_DE_GEMA = ("azul oscuro", "azul claro", "magenta",
                   "amarilla", "verde", "gris")


def _rb(rom, addr, org=ORG):
    return rom[addr - org]


def _rw(rom, addr, org=ORG):
    return _rb(rom, addr, org) | (_rb(rom, addr + 1, org) << 8)


def celda(y, x, pantalla=0):
    """0x6df6 (getMapOffset): (Y>>3)*96 + ((pantalla*256 + X)>>3)."""
    return ((y >> 3) & 0x1F) * ANCHO_BUFFER + (((pantalla << 8) | x) >> 3)


class Descriptor:
    """El descriptor de un nivel, ya desmenuzado."""

    def __init__(self, rom, nivel, org=ORG):
        self.nivel = nivel
        self.rom = rom
        self.org = org
        p = _rw(rom, TABLA_HABITACIONES + 2 * (nivel - 1), org)
        self.inicio = p

        # --- bandas de pared (0x6abc-0x6b18) ---------------------------
        # OJO: el `pop de` de 0x6b0e devuelve el puntero a la banda que se
        # ACABA de desempaquetar, asi que el `cp 030h` de 0x6b14 mira ESA
        # banda, no la siguiente: la banda 0x3x se dibuja y ademas cierra la
        # lista. Por eso las salas tienen una banda mas de las que parece.
        self.bandas = []
        for _ in range(4):
            banda = _rb(rom, p, org)
            self.bandas.append(banda)
            p += 1
            if (banda & 0xF0) == 0x30:
                break

        # --- las cuatro puertas de salida (0x6b1a) ---------------------
        self.puertas = []
        for _ in range(4):
            y = _rb(rom, p, org)
            if y == 0xFF:
                self.puertas.append(None)
                p += 1
                continue
            bx = _rb(rom, p + 1, org)
            info = _rb(rom, p + 2, org)
            self.puertas.append({
                "y": y, "x": bx & 0xF8, "pantalla": bx & 1,
                "piramide": info >> 4, "flecha": info & 0x0F})
            p += 3

        # --- momias (0x6b67) -------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.momias = []
        for _ in range(n):
            y, bx, tipo = (_rb(rom, p, org), _rb(rom, p + 1, org),
                           _rb(rom, p + 2, org))
            self.momias.append({"y": y, "x": bx & 0xF8,
                                "pantalla": bx & 1, "tipo": tipo})
            p += 3

        # --- gemas (0x6b7a) --------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.gemas = []
        for _ in range(n):
            color = _rb(rom, p, org) >> 4
            y, bx = _rb(rom, p + 1, org), _rb(rom, p + 2, org)
            self.gemas.append({"color": color, "y": y, "x": bx & 0xF8,
                               "pantalla": bx & 1})
            p += 3

        # --- cuchillos -------------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.cuchillos = []
        for _ in range(n):
            y, bx = _rb(rom, p, org), _rb(rom, p + 1, org)
            self.cuchillos.append({"y": y, "x": bx & 0xF8,
                                   "pantalla": bx & 1})
            p += 2

        # --- picos -----------------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.picos = []
        for _ in range(n):
            y, bx = _rb(rom, p, org), _rb(rom, p + 1, org)
            self.picos.append({"y": y, "x": bx & 0xF8, "pantalla": bx & 1})
            p += 2

        # --- puertas giratorias ----------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.giratorias = []
        for _ in range(n):
            alto = _rb(rom, p, org)
            y = _rb(rom, p + 1, org)
            bx = _rb(rom, p + 2, org)
            self.giratorias.append({
                "alto": ((alto >> 1) & 3) + 2, "y": y, "x": bx & 0xF8,
                "pantalla": (bx >> 2) & 1, "sentido": (bx << 2) & 0x0C})
            p += 3

        # --- muros trampa ----------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.trampas = []
        for _ in range(n):
            y, bx = _rb(rom, p, org), _rb(rom, p + 1, org)
            self.trampas.append({"y": y, "x": bx & 0xF8, "pantalla": bx & 1})
            p += 2

        # --- escaleras -------------------------------------------------
        n = _rb(rom, p, org)
        p += 1
        self.escaleras = []
        for _ in range(n):
            y, bx = _rb(rom, p, org), _rb(rom, p + 1, org)
            self.escaleras.append({"y": y, "x": bx & 0xF8,
                                   "sentido": bx & 1, "pantalla": (bx >> 1) & 1})
            p += 2

        self.fin = p

    @property
    def ancho(self):
        """Columnas de sala de verdad: 16 por banda."""
        return len(self.bandas) * ANCHO_BANDA

    def __len__(self):
        return self.fin - self.inicio


def patron_de_pared(rom, base, indice, org=ORG):
    """22 filas x 16 celdas desde los 44 bytes del patron (0x6ae9)."""
    addr = base + STRIDE_PATRON * indice
    filas = []
    for _f in range(FILAS):
        fila = []
        for _k in range(2):
            byte = _rb(rom, addr, org)
            addr += 1
            for bit in range(7, -1, -1):
                fila.append((byte >> bit) & 1)
        filas.append(fila)
    return filas


def buffer_de_sala(rom, nivel, org=ORG, con_elementos=True,
                   cuchillos=False):
    """El buffer de mapa de la RAM tal y como queda tras carga_la_sala.

    Devuelve una lista de FILAS listas de ANCHO_BUFFER identificadores.
    """
    d = Descriptor(rom, nivel, org)
    # borra_sala (0x6d92) rellena de 0x14 desde la fila 1
    mapa = [[CELDA_FONDO] * ANCHO_BUFFER for _ in range(FILAS_BUFFER)]

    # unpackMap: cada banda, 16 columnas mas a la derecha
    bases = [_rw(rom, TABLA_TIPOS_PARED + 2 * i, org) for i in range(4)]
    for i, banda in enumerate(d.bandas):
        tipo, indice = (banda >> 4) & 0x0F, banda & 0x0F
        rejilla = patron_de_pared(rom, bases[tipo], indice, org)
        for f in range(FILAS):
            for c in range(ANCHO_BANDA):
                mapa[f][i * ANCHO_BANDA + c] = (
                    CELDA_LADRILLO if rejilla[f][c] else CELDA_VACIA)

    if not con_elementos:
        return d, mapa

    def pon(off, valor):
        f, c = divmod(off, ANCHO_BUFFER)
        if 0 <= f < FILAS_BUFFER and 0 <= c < ANCHO_BUFFER:
            mapa[f][c] = valor

    def lee(off):
        f, c = divmod(off, ANCHO_BUFFER)
        if 0 <= f < FILAS_BUFFER and 0 <= c < ANCHO_BUFFER:
            return mapa[f][c]
        return CELDA_FONDO

    # --- escaleras (getStairs, 0x6cab): peldanos hacia arriba hasta topar
    for e in d.escaleras:
        off = celda(e["y"], e["x"], e["pantalla"])
        paso = -0x61 if e["sentido"] == 0 else -0x5F
        base_peldano = CELDA_PELDANO + (2 if e["sentido"] else 0)
        base_arranque = CELDA_ESCALERA_FIN + (2 if e["sentido"] else 0)
        while lee(off) == CELDA_VACIA:
            pon(off, base_peldano)
            pon(off + 1, base_peldano + 1)
            off += paso
        pon(off, base_arranque)
        pon(off + 1, base_arranque + 1)

    # --- puertas giratorias (putGiratMap, 0x6a27)
    for g in d.giratorias:
        off = celda(g["y"], g["x"], g["pantalla"])
        c = CELDA_GIRATORIA + (2 if (g["sentido"] & 4) else 0)
        for _ in range(g["alto"]):
            pon(off, c)
            pon(off + 1, c + 1)
            off += ANCHO_BUFFER

    # --- gemas, con sus tres destellos (putBrillosMap, 0x6795)
    for g in d.gemas:
        off = celda(g["y"], g["x"], g["pantalla"])
        pon(off - ANCHO_BUFFER, CELDA_BRILLO)
        pon(off - 1, CELDA_BRILLO + 1)
        pon(off + 1, CELDA_BRILLO + 2)
        pon(off, CELDA_GEMA + (g["color"] - 3))

    # --- picos: un solo identificador (getPicos)
    for pico in d.picos:
        pon(celda(pico["y"], pico["x"], pico["pantalla"]), CELDA_PICO)

    # --- cuchillos: NO los pone carga_la_sala. Los estampa el estado 0 de
    #     su propia maquina (initCuchillo, 0x580b), un fotograma mas tarde:
    #     0x31/0x32 si el cuchillo cae sobre un peldano, 0x30 si no. Por eso
    #     van aparte, y por eso la comprobacion contra la RAM real no los pide.
    for k in (d.cuchillos if cuchillos else ()):
        off = celda(k["y"], k["x"], k["pantalla"])
        debajo = lee(off)
        if debajo == 0x31:
            pon(off, 0x31)
        elif debajo in (0x21, 0x22):
            pon(off, debajo + 0x10)
        else:
            pon(off, CELDA_CUCHILLO)

    return d, mapa


def traduce_celda_a_patron(rom, celda_id, org=ORG):
    """traduce_celda_a_patron (0x5d52)."""
    d = TABLA_ATRIBUTOS + ((celda_id >> 4) & 0x0F) * 2
    ptr = _rw(rom, d, org)
    return _rb(rom, ptr + (celda_id & 0x0F), org)


# Las tres estampas de 3x5 celdas de una salida (idxAnimExit): cerrada,
# cerrandose y abierta. La puerta se pinta con su esquina en X-16, Y-8.
ANIM_SALIDA = (0x67C5, 0x67D4, 0x67E3)
# tiposMomia (0x6d3c): nibble alto = velocidad, nibble bajo = color MSX.
TIPOS_DE_MOMIA = 0x6D3C
# framesMomia (0x70b6): el patron de sprite de cada pose.
FRAMES_MOMIA = 0x70B6


def indice_de_entrada(puerta_entrada):
    """getDoors4 (0x6b36): la puerta por la que se entra sale de (0xE056)
    partido por dos, y el 4 se topa en 3."""
    i = puerta_entrada >> 1
    return 3 if i == 4 else i


def estampa_una_puerta(rom, mapa, p, frame, org=ORG):
    """drawPuerta (0x6624): la estampa de 3x5 celdas de una salida, con el
    origen en X-16, Y-8 (el `ld bc,0f0f8h` de 0x6626)."""
    guion = ANIM_SALIDA[frame]
    off = celda(p["y"] - 8, p["x"] - 16, p["pantalla"])
    for f in range(3):
        for c in range(5):
            fila, col = divmod(off + f * ANCHO_BUFFER + c, ANCHO_BUFFER)
            if 0 <= fila < FILAS_BUFFER and 0 <= col < ANCHO_BUFFER:
                mapa[fila][col] = _rb(rom, guion + f * 5 + c, org)


def estampa_puertas(rom, mapa, d, entrada=None, otras=True, org=ORG):
    """Las salidas de la piramide. La de ENTRADA se pinta abierta -es por
    donde acaba de aparecer el explorador, paintEntrada con GameStatus 4-; las
    demas no se ven hasta que estan todas las gemas, y entonces salen
    CERRADAS. Con otras=False se pinta solo la de entrada, que es el estado
    exacto en el que el emulador deja la tabla de nombres al montar la sala."""
    for i, p in enumerate(d.puertas):
        if not p:
            continue
        if i == entrada:
            estampa_una_puerta(rom, mapa, p, 2, org)
        elif otras:
            estampa_una_puerta(rom, mapa, p, 0, org)


def _pinta_sprite(px, vram, patron, x, y, color):
    """Un sprite de 16x16 encima de la imagen: cuatro cuadrantes de 8x8
    ordenados por COLUMNAS (arriba-izq, abajo-izq, arriba-der, abajo-der)."""
    import pantallas
    base = 0x1800 + patron * 8
    for cuadrante in range(4):
        cx = (cuadrante // 2) * 8
        cy = (cuadrante % 2) * 8
        for fy in range(8):
            b = vram.b[(base + cuadrante * 8 + fy) & 0x3FFF]
            for fx in range(8):
                if (b >> (7 - fx)) & 1:
                    iy, ix = y + cy + fy, x + cx + fx
                    if 0 <= iy < len(px) and 0 <= ix < len(px[0]):
                        px[iy][ix] = pantallas.PALETA[color]


def dibuja_sala(rom, org, nivel, puertas=True, momias=True,
                entrada=None):
    """La piramide entera con sus graficos de verdad, a su ancho real."""
    import pantallas
    vram = pantallas.vram_de_juego(rom, org)
    # columna_decorativa (0x6da0): el color de la piedra, por grupo de cuatro
    grupo = ((nivel - 1) >> 2) & 3
    guion = 0x6DC4 + 9 * grupo
    hl = 0x0200
    for _ in range(5):
        pantallas.guion_x3(rom, org, vram, guion, hl)
        hl += 8

    d, mapa = buffer_de_sala(rom, nivel, org, cuchillos=True)
    if puertas:
        estampa_puertas(rom, mapa, d, entrada, True, org)

    ancho = d.ancho
    px = [[(0, 0, 0)] * (ancho * 8) for _ in range(FILAS * 8)]
    for i in range(FILAS):
        f = i + PRIMERA_FILA_VISIBLE
        # la fila f del buffer se pinta en la fila f de la pantalla, y de ahi
        # sale el tercio de la tabla de patrones que le toca
        tercio = f // 8
        for c in range(ancho):
            tile = traduce_celda_a_patron(rom, mapa[f][c], org)
            base = tercio * 0x800 + tile * 8
            for y in range(8):
                forma = vram.b[pantallas.BASE_PATRON + base + y]
                color = vram.b[pantallas.BASE_COLOR + base + y]
                tinta = pantallas.PALETA[color >> 4]
                fondo = pantallas.PALETA[color & 0x0F]
                for x in range(8):
                    bit = (forma >> (7 - x)) & 1
                    px[i * 8 + y][c * 8 + x] = tinta if bit else fondo

    if momias:
        patron = _rb(rom, FRAMES_MOMIA + 1, org)   # pose "pies juntos"
        for m in d.momias:
            tipo = min(m["tipo"], 4)
            color = _rb(rom, TIPOS_DE_MOMIA + tipo, org) & 0x0F
            _pinta_sprite(px, vram, patron,
                          (m["pantalla"] << 8) + m["x"], m["y"] - 9, color)
    return d, px


def resumen(rom, org=ORG):
    """Una linea por nivel con todo lo que trae."""
    lineas = []
    for nivel in range(1, 16):
        d = Descriptor(rom, nivel, org)
        lineas.append(
            "nivel %2d  0x%04X %3d bytes  %d bandas (%2d col)  "
            "%d puertas  %d momias  %d gemas  %d cuchillos  %d picos  "
            "%d giratorias  %d trampas  %d escaleras"
            % (nivel, d.inicio, len(d), len(d.bandas), d.ancho,
               sum(1 for p in d.puertas if p), len(d.momias), len(d.gemas),
               len(d.cuchillos), len(d.picos), len(d.giratorias),
               len(d.trampas), len(d.escaleras)))
    return lineas


def comprueba(ruta_rom, org, carpeta):
    """Compara celda a celda lo que calcula buffer_de_sala con los volcados
    de RAM que saca tools/omsx_dump_mapa.tcl de una maquina de verdad."""
    import glob
    rom = open(ruta_rom, "rb").read()
    total = fallos = vistos = 0
    for fn in sorted(glob.glob(os.path.join(carpeta, "mapa_*.txt"))):
        lineas = open(fn).read().split("\n")
        nivel = int(lineas[0].split("=")[1])
        volcado = [int(x, 16) for x in lineas[1:] if x.strip()]
        _d, mapa = buffer_de_sala(rom, nivel, org)
        d = 0
        # la fila 0 no se compara: borra_sala (0x6d92) empieza en 0xE760 y la
        # deja con lo que hubiera de la sala anterior fuera de las bandas
        for f in range(PRIMERA_FILA_VISIBLE, FILAS_BUFFER):
            for c in range(ANCHO_BUFFER):
                off = f * ANCHO_BUFFER + c
                total += 1
                if off < len(volcado) and volcado[off] != mapa[f][c]:
                    d += 1
                    if d <= 3:
                        print("      fila %2d col %2d: maquina %02X, "
                              "calculado %02X"
                              % (f, c, volcado[off], mapa[f][c]))
        vistos += 1
        fallos += d
        print("  nivel %2d: %s" % (nivel, "OK" if d == 0 else
                                   "%d DIFERENCIAS" % d))
    print("%d volcados, %d celdas comparadas, %d diferencias"
          % (vistos, total, fallos))
    return 0 if fallos == 0 and vistos else 1


def comprueba_vram(ruta_rom, org, carpeta):
    """Compara byte a byte las TRES tablas que forman la imagen -nombres,
    patrones y color- y la de patrones de sprites, contra los 16 KB de VRAM
    que tools/omsx_vram_sala.tcl saca de una maquina de verdad con la sala ya
    montada. De los patrones y el color solo se exigen los tiles que la
    pantalla usa: el resto de la tabla son restos de la pantalla de titulo que
    el juego nunca reescribe ni mira."""
    import glob
    import pantallas
    rom = open(ruta_rom, "rb").read()
    fallos = vistos = 0
    for fn in sorted(glob.glob(os.path.join(carpeta, "vram_*.bin"))):
        nivel = int(os.path.basename(fn)[5:7])
        v = open(fn, "rb").read()
        texto = open(os.path.join(carpeta, "info_%02d.txt" % nivel)).read()
        info = dict(l.split(None, 1) for l in texto.splitlines() if l.strip())
        vram = pantallas.vram_de_juego(rom, org, int(info["lleva"]) >> 4)
        grupo = ((nivel - 1) >> 2) & 3
        hl = 0x0200
        for _ in range(5):
            pantallas.guion_x3(rom, org, vram, 0x6DC4 + 9 * grupo, hl)
            hl += 8
        d, mapa = buffer_de_sala(rom, nivel, org, cuchillos=True)
        estampa_puertas(rom, mapa, d,
                        indice_de_entrada(int(info["puerta_entrada"])),
                        False, org)
        pant = int(info["pantalla_del_jugador"])
        dn = dp = dc = ds = 0
        usados = set()
        for f in range(PRIMERA_FILA_VISIBLE, FILAS_BUFFER):
            for c in range(32):
                real = v[pantallas.BASE_NOMBRE + f * 32 + c]
                mio = traduce_celda_a_patron(rom, mapa[f][c + pant * 32], org)
                usados.add((f // 8, real))
                if real != mio:
                    dn += 1
        for tercio, t in usados:
            base = tercio * 0x800 + t * 8
            for k in range(8):
                dp += vram.b[pantallas.BASE_PATRON + base + k] !=                     v[pantallas.BASE_PATRON + base + k]
                dc += vram.b[pantallas.BASE_COLOR + base + k] !=                     v[pantallas.BASE_COLOR + base + k]
        for i in range(0x1800, 0x2000):
            ds += vram.b[i] != v[i]
        malo = dn + dp + dc + ds
        fallos += malo
        vistos += 1
        print("  nivel %2d: nombres %d, patron %d, color %d, sprites %d  %s"
              % (nivel, dn, dp, dc, ds, "OK" if malo == 0 else "MAL"))
    print("%d volcados de VRAM, %d diferencias" % (vistos, fallos))
    return 0 if fallos == 0 and vistos else 1


def main():
    if len(sys.argv) >= 5 and sys.argv[1] == "--vram":
        return comprueba_vram(sys.argv[2], int(sys.argv[3], 0), sys.argv[4])
    if len(sys.argv) >= 5 and sys.argv[1] == "--comprueba":
        return comprueba(sys.argv[2], int(sys.argv[3], 0), sys.argv[4])
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    import pantallas
    rom = open(sys.argv[1], "rb").read()
    org = int(sys.argv[2], 0)
    for linea in resumen(rom, org):
        print(linea)
    if len(sys.argv) < 4:
        return 0
    carpeta = sys.argv[3]
    os.makedirs(carpeta, exist_ok=True)
    for nivel in range(1, 16):
        d, px = dibuja_sala(rom, org, nivel)
        salida = os.path.join(carpeta, "sala_%02d.png" % nivel)
        pantallas.png(salida, px, escala=2)
        print("  sala %2d  %s  (%d columnas, %d gemas, %d momias)"
              % (nivel, salida, d.ancho, len(d.gemas), len(d.momias)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
