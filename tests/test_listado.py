#!/usr/bin/env python3
"""Comprobaciones sobre el listado generado y sobre la web.

Ninguna necesita el cartucho: se hacen sobre src/kingsvalley.asm,
src/kingsvalley.notes y el trazado. Vigilan que el listado no se degrade sin
que nadie se entere -que no desaparezcan comentarios, que no vuelvan a
aparecer bloques sin identificar- y que las cifras publicadas en la web sean
las del arbol y no las que habia cuando se escribio el texto.
"""
import json
import os
import re
import sys
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, "src", "kingsvalley.asm")
NOTES = os.path.join(RAIZ, "src", "kingsvalley.notes")
ENTRIES = os.path.join(RAIZ, "src", "kingsvalley.entries")
TRACE = os.path.join(RAIZ, "work", "kingsvalley.trace.json")
DOCS = os.path.join(RAIZ, "docs")
ORG, FIN = 0x4000, 0x8000

# Los demas juegos de la serie. Que el nombre de otro salga en una pagina de
# este es casi siempre un copia y pega: ya paso con cinco ficheros LICENSE y
# con el pie de catorce paginas de otro proyecto.
OTROS_JUEGOS = (
    "Tennis", "Pitfall", "Temptations", "Stardust", "Ale Hop", "Colt 36",
    "Antarctic", "Athletic Land", "Monkey Academy", "F-1 Spirit", "Pippols",
    "Time Pilot", "Frogger", "Super Cobra", "Billiards", "Mahjong",
    "Hyper Rally", "Hyper Sports", "Nemesis", "Demonia", "Cabbage",
    "Hole in One", "Casio World Open", "3D Golf", "Baseball",
    "Yie Ar Kung-Fu",
)


def lee(ruta):
    with open(ruta, encoding="utf-8") as f:
        return f.read()


def bloques_del_listado(lineas):
    """Los mismos bloques que cuenta tools/densidad.py, con su misma logica.

    Dos detalles suyos hay que respetar o las cifras no cuadran: una etiqueta
    solo cuenta si su linea no lleva nada mas (salvo un comentario), y una
    linea es de INSTRUCCION cuando su direccion viene pegada al punto y coma
    (";4323"), mientras que las de datos llevan un espacio ("; 4323"). Por eso
    los bloques DATA_ salen con cero instrucciones y no cuentan como rutina.
    """
    bloques, nombre, ini, n, c = [], "(cabecera)", 0, 0, 0
    for ln in lineas:
        m = re.match(r"^([A-Za-z_][A-Za-z_0-9]*):\s*(;.*)?$", ln)
        if m:
            if n:
                bloques.append((nombre, ini, n, c))
            nombre, ini, n, c = m.group(1), 0, 0, 0
            continue
        m = re.match(r"^	.*;([0-9a-f]{4})(.*)$", ln)
        if not m:
            continue
        if not ini:
            ini = int(m.group(1), 16)
        n += 1
        if ";" in m.group(2):
            c += 1
    if n:
        bloques.append((nombre, ini, n, c))
    return bloques


class TestListado(unittest.TestCase):
    """El listado en si."""

    @classmethod
    def setUpClass(cls):
        cls.asm = lee(ASM)
        cls.lineas = cls.asm.splitlines()

    def test_no_quedan_bloques_sin_identificar(self):
        """Cada bloque de datos tiene que tener nombre y explicacion.

        mkasm.py escribe "DATOS sin identificar" en los bloques que no tienen
        una directiva D en el .notes. Que vuelva a aparecer uno significa que
        el trazado ha cambiado y hay bytes que ya nadie explica.
        """
        sueltos = [l for l in self.lineas if "DATOS sin identificar" in l]
        self.assertEqual(
            sueltos, [],
            "han vuelto a aparecer bloques sin identificar:\n"
            + "\n".join(sueltos))

    def test_todas_las_rutinas_llegan_al_liston(self):
        """Ninguna rutina por debajo del 10 % de densidad de comentario.

        Es el liston de la serie, y se mide igual que densidad.py: solo cuentan
        las rutinas de SEIS instrucciones o mas, porque por debajo de eso un
        solo comentario ya distorsiona el porcentaje.
        """
        flojas = ["%s 0x%04X (%d/%d)" % (nom, ini, c, n)
                  for nom, ini, n, c in bloques_del_listado(self.lineas)
                  if n >= 6 and c * 100 // n < 10]
        self.assertEqual(flojas, [],
                         "rutinas por debajo del 10 %%: %s" % ", ".join(flojas))

    def test_hay_al_menos_dos_mil_comentarios(self):
        """Un suelo para que un cambio no se lleve por delante el trabajo.

        En el momento de escribir esto son 2.467. El suelo esta en 2.000 para
        que quepan reorganizaciones sin dar un falso positivo, pero no un
        borrado masivo.
        """
        comentados = sum(1 for l in self.lineas
                         if re.search(r";[0-9a-f]{4}\s+;", l))
        self.assertGreaterEqual(comentados, 2000,
                                "solo quedan %d comentarios de linea"
                                % comentados)

    def test_las_etiquetas_son_snake_case(self):
        """mkasm.py no acepta parentesis ni espacios en un nombre de rutina.

        Cuando pasa, no da error: funde el bloque con el anterior y esa rutina
        desaparece de la cuenta sin avisar. Paso una vez y costo encontrarlo.
        """
        malas = []
        for linea in self.lineas:
            m = re.match(r"^([^\s:]+):", linea)
            if m and not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", m.group(1)):
                malas.append(m.group(1))
        self.assertEqual(malas, [], "etiquetas con caracteres raros: %s" % malas)


class TestCobertura(unittest.TestCase):
    """El presupuesto de los 16 KB."""

    def test_el_trazado_cubre_el_cartucho_entero(self):
        """Codigo trazado mas datos declarados tienen que dar los 16.384.

        Es la misma cuenta que presupuesto.py, hecha aqui sobre el trazado
        para que `make test` la cace aunque nadie corra sanity. El trazado
        guarda sus bloques como ["c"|"d", inicio, fin].
        """
        if not os.path.exists(TRACE):
            self.skipTest("falta el trazado; corre `make trace` primero")
        with open(TRACE, encoding="utf-8") as f:
            trace = json.load(f)
        explicado = set()
        for tipo, ini, fin in trace["blocks"]:
            explicado.update(range(max(ini, ORG), min(fin, FIN)))
        for linea in lee(NOTES).splitlines():
            m = re.match(r"^D\s+(0x[0-9a-fA-F]+)\s+(0x[0-9a-fA-F]+)", linea)
            if m:
                explicado.update(range(int(m.group(1), 16),
                                       int(m.group(2), 16)))
        sin_explicar = sorted(set(range(ORG, FIN)) - explicado)
        self.assertEqual(
            sin_explicar, [],
            "%d bytes sin explicar, el primero en 0x%04X"
            % (len(sin_explicar), sin_explicar[0] if sin_explicar else 0))

    def test_las_entradas_estan_justificadas(self):
        """Cada punto de entrada lleva su razon escrita al lado.

        Una entrada sin justificar es una direccion que alguien metio a mano
        para que el trazado cuadrase, y eso es exactamente lo que no se puede
        hacer sin dejar constancia.
        """
        sin_razon = []
        for linea in lee(ENTRIES).splitlines():
            limpia = linea.strip()
            if not limpia or limpia.startswith("#"):
                continue
            if "#" not in limpia:
                sin_razon.append(limpia)
        self.assertEqual(sin_razon, [],
                         "entradas sin justificacion: %s" % sin_razon)


class TestNotas(unittest.TestCase):
    """El fichero de notas, que es donde vive lo entendido."""

    @classmethod
    def setUpClass(cls):
        cls.notes = lee(NOTES)

    def test_cada_bloque_de_datos_tiene_nombre_y_explicacion(self):
        """Ninguna directiva D puede quedarse en un nombre a secas.

        La norma de la serie es que cada bloque diga QUE es y COMO se sabe. Un
        bloque con nombre y sin explicacion esta bautizado, no entendido, que
        es justo lo que el nombre disimula.
        """
        pelados = []
        for m in re.finditer(
                r"^D\s+0x[0-9a-fA-F]+\s+0x[0-9a-fA-F]+\s+(\S+)(.*)$",
                self.notes, re.MULTILINE):
            if len(m.group(2).strip()) < 20:
                pelados.append(m.group(1))
        self.assertEqual(pelados, [],
                         "bloques D sin explicacion: %s" % pelados[:10])

    def test_las_anchuras_declaradas_apuntan_a_un_bloque(self):
        """Toda F tiene que caer en la direccion de arranque de una D.

        La F que se escribe con la direccion equivocada no da error: se aplica
        al bloque de al lado y le pone una anchura que no es la suya, y la
        tabla sale partida donde no toca. Es un fallo silencioso, y este test
        es la unica forma de cazarlo.
        """
        inicios = set(re.findall(r"^D\s+(0x[0-9a-fA-F]+)", self.notes,
                                 re.MULTILINE))
        inicios = {d.lower() for d in inicios}
        huerfanas = [f for f in re.findall(r"^F\s+(0x[0-9a-fA-F]+)",
                                           self.notes, re.MULTILINE)
                     if f.lower() not in inicios]
        self.assertEqual(huerfanas, [],
                         "anchuras que no caen en ningun bloque: %s"
                         % huerfanas)

    def test_las_suposiciones_estan_marcadas(self):
        """Tiene que seguir habiendo SUPOSICIONes escritas.

        No es un test de calidad: es un canario. Un listado de este tamano sin
        una sola suposicion marcada significa casi siempre que alguien ha
        dejado de marcarlas, no que se hayan resuelto todas.
        """
        self.assertGreater(self.notes.count("SUPOSICION"), 5,
                           "ya no quedan suposiciones marcadas; "
                           "revisa si de verdad se han resuelto")


class TestWeb(unittest.TestCase):
    """La web: que las cifras sean las del arbol y no las del texto viejo."""

    def test_no_se_nombra_otro_juego_de_la_serie(self):
        """El nombre de otro juego en estas paginas es un copia y pega.

        Ya paso con cinco ficheros LICENSE y con el pie de catorce paginas.
        Konami's Golf y Sky Jaguar se permiten porque el texto los cita a
        proposito: comparten el patron del bucle dentro de la interrupcion.
        """
        permitidos = ("Golf", "Sky Jaguar")
        fallos = []
        for carpeta, _dirs, ficheros in os.walk(DOCS):
            for fich in ficheros:
                if not fich.endswith((".md", ".html")):
                    continue
                texto = lee(os.path.join(carpeta, fich))
                for juego in OTROS_JUEGOS:
                    if juego in permitidos:
                        continue
                    if juego in texto:
                        # Konami's Tennis se nombra a proposito en la pagina
                        # de preguntas abiertas, contando que su plantilla
                        # dejo aqui una etiqueta falsa.
                        if juego == "Tennis" and "jugador2" in texto:
                            continue
                        fallos.append("%s en %s" % (juego, fich))
        self.assertEqual(fallos, [], "nombres de otros juegos: %s" % fallos)

    def test_las_cifras_de_la_portada_son_las_del_listado(self):
        """Las cifras publicadas se recuentan sobre el listado.

        Es la trampa mas facil de esta serie: cambiar el listado y dejar en la
        web el numero de antes.
        """
        make_web = lee(os.path.join(RAIZ, "tools", "make_web.py"))
        m = re.search(r"^RUTINAS\s*=\s*(\d+)", make_web, re.MULTILINE)
        self.assertIsNotNone(m, "make_web.py no declara RUTINAS")
        publicadas = int(m.group(1))

        reales = len(bloques_del_listado(lee(ASM).splitlines()))
        self.assertEqual(
            publicadas, reales,
            "la web dice %d rutinas y el listado tiene %d"
            % (publicadas, reales))

    def test_la_suma_de_bytes_da_el_cartucho(self):
        """CODIGO + DATOS de la web tienen que dar 16.384 exactos."""
        make_web = lee(os.path.join(RAIZ, "tools", "make_web.py"))
        codigo = int(re.search(r"^CODIGO\s*=\s*(\d+)", make_web,
                               re.MULTILINE).group(1))
        datos = int(re.search(r"^DATOS\s*=\s*(\d+)", make_web,
                              re.MULTILINE).group(1))
        self.assertEqual(codigo + datos, 16384,
                         "%d + %d = %d, y el cartucho son 16384"
                         % (codigo, datos, codigo + datos))


def rom_del_listado():
    """Reconstruye los BYTES DE DATOS del cartucho leyendo el listado.

    El cartucho no viaja con el repositorio, pero src/kingsvalley.asm si, y
    cada fila de datos lleva su direccion en el comentario -eso lo pone
    mkasm.py-. Con las filas `defb` y `defw` se rehace un buffer de 16 KB con
    todas las zonas de datos en su sitio, que es lo unico que el descriptor de
    nivel necesita leer. Asi estos tests corren en un clon pelado, sin cartucho
    y sin `make`.
    """
    rom = bytearray(FIN - ORG)
    for linea in lee(ASM).splitlines():
        m = re.match(r"\s*(defb|defw)\s+([^;]+);\s*([0-9a-f]{4})", linea)
        if not m:
            continue
        que, cuerpo, addr = m.group(1), m.group(2), int(m.group(3), 16)
        p = addr - ORG
        for tok in cuerpo.split(","):
            tok = tok.strip()
            if not re.fullmatch(r"[0-9][0-9a-fA-F]*h", tok):
                continue
            v = int(tok[:-1], 16)
            if que == "defb":
                rom[p] = v & 0xFF
                p += 1
            else:
                rom[p] = v & 0xFF
                rom[p + 1] = (v >> 8) & 0xFF
                p += 2
    return bytes(rom)


class TestMapas(unittest.TestCase):
    """El decodificador de piramides de tools/mapas.py.

    Contra la RAM y la VRAM de una maquina de verdad se comprueba con
    `mapas.py --comprueba` y `mapas.py --vram`, que necesitan los volcados de
    openMSX y el cartucho. Aqui se comprueba lo que SI se puede sin nada de
    eso, leyendo el listado publicado.
    """

    def _mapas(self):
        sys.path.insert(0, os.path.join(RAIZ, "tools"))
        import mapas
        return mapas, rom_del_listado()

    def test_los_descriptores_encajan_uno_detras_de_otro(self):
        """Cada descriptor de nivel acaba donde empieza el siguiente.

        Es la prueba de que el descriptor se esta leyendo entero y bien: si
        sobrara o faltara un byte en cualquiera de los ocho bloques -bandas,
        puertas, momias, gemas, cuchillos, picos, giratorias, trampas,
        escaleras- la cadena se rompe.
        """
        mapas, rom = self._mapas()
        tramos = sorted((mapas.Descriptor(rom, n).inicio,
                         mapas.Descriptor(rom, n).fin, n)
                        for n in range(1, 16))
        for (_i, fin, nivel), (inicio, _f, siguiente) in zip(tramos,
                                                             tramos[1:]):
            self.assertEqual(
                fin, inicio,
                "el descriptor del nivel %d acaba en 0x%04X y el del %d "
                "empieza en 0x%04X" % (nivel, fin, siguiente, inicio))

    def test_los_anchos_son_32_o_64(self):
        """Las salas impares miden 32 columnas y las pares 64.

        Guardian del error que este proyecto publico: leer el centinela de
        banda en el byte siguiente en vez de en el actual daba 16 y 48.
        """
        mapas, rom = self._mapas()
        for nivel in range(1, 16):
            esperado = 32 if nivel % 2 else 64
            self.assertEqual(
                mapas.Descriptor(rom, nivel).ancho, esperado,
                "el nivel %d tendria que medir %d columnas"
                % (nivel, esperado))

    def test_las_cifras_publicadas_de_cada_piramide(self):
        """Las gemas, momias y demas que dice la web salen del descriptor."""
        mapas, rom = self._mapas()
        gemas = sum(len(mapas.Descriptor(rom, n).gemas) for n in range(1, 16))
        momias = sum(len(mapas.Descriptor(rom, n).momias)
                     for n in range(1, 16))
        self.assertEqual(78, gemas)
        self.assertEqual(34, momias)
        for pagina in ("THE-GAME.md", os.path.join("es", "EL-JUEGO.md")):
            texto = lee(os.path.join(DOCS, pagina))
            self.assertIn("**78**", texto,
                          "%s no publica las 78 gemas" % pagina)
            self.assertIn("**34**", texto,
                          "%s no publica las 34 momias" % pagina)

    def test_la_web_no_vuelve_a_decir_48_columnas(self):
        """Ninguna pagina puede volver a publicar los anchos viejos."""
        malos = []
        for carpeta, _d, ficheros in os.walk(DOCS):
            for fn in ficheros:
                if not fn.endswith((".md", ".html")):
                    continue
                texto = lee(os.path.join(carpeta, fn))
                for frase in ("48 columnas", "48 columns", "384 pixel",
                              "384 píxel"):
                    if frase in texto:
                        malos.append("%s: %s" % (fn, frase))
        self.assertEqual([], malos, "anchos viejos publicados: %s" % malos)


if __name__ == "__main__":
    unittest.main()
