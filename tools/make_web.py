#!/usr/bin/env python3
"""Genera la portada de la web de King's Valley, en los dos idiomas.

El diseno es el compartido por la serie (tools/estilo_web.py) y la pagina sale
autocontenida, con las imagenes embebidas como data URI.

Las imagenes NO son ilustraciones ni capturas: las dibuja tools/pantallas.py a
partir de los propios bytes de la ROM, ejecutando en Python los mismos
interpretes de guiones que corre el Z80. Ninguna se ha retocado.

Uso: make_web.py <docs/imagenes> <salida.html> <idioma>
"""
import base64
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from estilo_web import ESTILO                                   # noqa: E402

# Las cifras salen de contar sobre el listado generado, no de escribirlas a
# ojo: 16384 = 9803 + 6581, que es lo que imprime tools/presupuesto.py
# (make sanity). RUTINAS son las etiquetas con nombre propio y DENSIDAD la
# proporcion de instrucciones comentadas, las dos de tools/densidad.py.
CODIGO = 9803
DATOS = 6581
RUTINAS = 651
NIVELES = 15
SPRITES = 64
DENSIDAD = "45,5"
DENSIDAD_EN = "45.5"


def mil(n, idioma):
    return f"{n:,}".replace(",", "." if idioma == "es" else ",")


TXT = {
    "es": dict(
        titulo="King's Valley - desensamblado comentado",
        aviso="<b>Aqui no hay ninguna captura.</b> Todas las imagenes estan "
              "<b>dibujadas desde los bytes de la ROM</b>, ejecutando en "
              "Python los dos interpretes de guiones que corre el Z80. El "
              "listado y las cifras se reproducen con <code>make</code>, y el "
              "reensamblado devuelve la ROM <b>byte a byte</b>.",
        claim="La tabla de colores debajo de la de patrones, la posicion del "
              "explorador en veinticuatro bits, seis listas de entidades con "
              "seis pasos distintos, y ochenta y siete bytes de codigo "
              "escondidos detras de un <code>push</code>.",
        ficha=["Konami - <b>(c) Konami 1985</b>",
               "Cartucho <b>RC-727</b>, 16 KB",
               "MSX1 - <b>pagina 1</b>", "Volcado <b>a8f807a0...</b>"],
        nav=[("#numbers", "Las cifras"), ("#findings", "Hallazgos"),
             ("#screens", "Lo que dibuja")],
        docnav=[("EMPEZAR.html", "Empezar"), ("EL-JUEGO.html", "El juego"),
                ("EL-CARTUCHO.html", "El cartucho"),
                ("EL-CODIGO.html", "El codigo"),
                ("HALLAZGOS.html", "Hallazgos"),
                ("EN-EL-EMULADOR.html", "En el emulador"),
                ("PREGUNTAS-ABIERTAS.html", "Preguntas abiertas")],
        otro=("../", "In English"),
        h_num="El cartucho en cifras", h_find="Lo que aparecio al desmontarlo",
        h_scr="Lo que el cartucho dibuja",
        cifras=[("100 %", "del binario explicado"),
                (str(RUTINAS), "rutinas con nombre"),
                (DENSIDAD + " %", "del listado comentado"),
                (mil(CODIGO, "es"), "bytes de codigo"),
                (mil(DATOS, "es"), "bytes de datos"),
                ("0", "bytes sin identificar")],
        nota_scr="Debajo de cada imagen esta de donde sale y que se esta "
                 "viendo.",
        pie_leg="Esto es trabajo de documentacion y preservacion: el codigo y "
                "los graficos siguen siendo de sus autores y de Konami, y la "
                "imagen del cartucho no se distribuye.",
    ),
    "en": dict(
        titulo="King's Valley - a commented disassembly",
        aviso="<b>Not one capture here.</b> Every picture is <b>drawn from "
              "the bytes of the ROM</b>, by running in Python the same two "
              "script interpreters the Z80 runs. The listing and the numbers "
              "are reproducible with <code>make</code>, and reassembling "
              "gives back the ROM <b>byte for byte</b>.",
        claim="The colour table underneath the pattern table, the explorer's "
              "position in twenty-four bits, six entity lists with six "
              "different strides, and eighty-seven bytes of code hidden "
              "behind a <code>push</code>.",
        ficha=["Konami - <b>(c) Konami 1985</b>",
               "An <b>RC-727</b> 16 KB cartridge",
               "MSX1 - <b>page 1</b>", "Dump <b>a8f807a0...</b>"],
        nav=[("#numbers", "The numbers"), ("#findings", "What turned up"),
             ("#screens", "What it draws")],
        docnav=[("GETTING-STARTED.html", "Getting started"),
                ("THE-GAME.html", "The game"),
                ("THE-CARTRIDGE.html", "The cartridge"),
                ("THE-CODE.html", "The code"),
                ("FINDINGS.html", "Findings"),
                ("IN-THE-EMULATOR.html", "In the emulator"),
                ("OPEN-QUESTIONS.html", "Open questions")],
        otro=("es/", "En castellano"),
        h_num="The cartridge in numbers",
        h_find="What turned up when we took it apart",
        h_scr="What the cartridge draws",
        cifras=[("100%", "of the binary explained"),
                (str(RUTINAS), "named routines"),
                (DENSIDAD_EN + "%", "of the listing commented"),
                (mil(CODIGO, "en"), "bytes of code"),
                (mil(DATOS, "en"), "bytes of data"),
                ("0", "bytes unidentified")],
        nota_scr="Under each picture is where it comes from and what is on it.",
        pie_leg="This is documentation and preservation work: the code and "
                "artwork still belong to their authors and to Konami, and the "
                "cartridge image is not distributed.",
    ),
}

HALLAZGOS = {
    "es": [
        ('La tabla de colores va debajo de la de patrones',
         '<p>En SCREEN 2 lo normal es poner los patrones en 0x0000 y los '
         'colores en 0x2000. Este cartucho lo hace <b>al reves</b>, y no se '
         've en ninguna direccion: se ve en los registros. '
         '<code>tabla_registros_vdp</code> (0x45C0) vale '
         '<b>02 E2 0E 7F 07 76 03 E4</b>, y en SCREEN 2 los registros 3 y 4 '
         'no son una direccion sino <b>base mas mascara</b>: el bit 7 de R3 '
         'a cero pone el color en 0x0000, y el bit 2 de R4 a uno pone los '
         'patrones en 0x2000.</p>'
         '<p>El propio codigo lo confirma sin ambiguedad: 0x4831 dibuja el '
         'logotipo con <code>ld hl,06300h</code>, y 0x6300 enmascarado a '
         'catorce bits es <b>0x2300</b>, dentro de la tabla de patrones. '
         'Leerlo al derecho da formas correctas y colores a franjas.</p>'),
        ('El explorador se mueve en veinticuatro bits',
         '<p>La X no es un byte ni dos: son <b>tres</b>. 0x73F6 suma la '
         'velocidad con <code>add hl,de</code> sobre 0xE138/0xE139 y propaga '
         'el acarreo a 0xE13A con <code>adc a,c</code>. El byte de menos peso '
         'es la <b>fraccion</b>, en 1/256 de pixel, y los dos de mas peso son '
         'justo los que <code>lee_celda_de_sala</code> toma como X entera '
         'para mirar celdas.</p>'
         '<p>Hace falta tanta X porque la sala es mas ancha que la pantalla: '
         'las salas pares miden <b>48 columnas</b>, 384 pixeles, y no caben '
         'en un byte. Cuando el explorador sale por un lateral, la tarea 9 '
         'hace <code>ld (0e139h),bc</code> y le cambia el byte alto en uno: '
         'un salto de <b>256 pixeles</b>, una pantalla entera.</p>'),
        ('Ochenta y siete bytes de codigo que parecian datos',
         '<p>Cinco recorridos de entidades hacen '
         '<code>ld hl,&lt;cierre&gt; / push hl</code> antes de despachar, de '
         'modo que el <code>ret</code> de la rutina despachada <b>no vuelve '
         'al llamador</b>: cae en el cierre, que sube el indice y repite el '
         'bucle. Un trazador estatico no puede seguir eso, porque la '
         'direccion viaja por la pila como si fuera un dato.</p>'
         '<p>Por eso 87 bytes salian como "sin identificar". Los cinco '
         'cierres tienen la misma forma -<code>ld hl,&lt;indice&gt; / inc '
         '(hl) / cp (hl) / jp nz,&lt;cuerpo&gt;</code>- y el cuerpo al que '
         'saltan es exactamente la etiqueta que los apila.</p>'),
        ('Dos rutinas que no llama nadie, y una de ellas dice algo',
         '<p>0x4501 son diecinueve bytes que decodifican como otra variante '
         'de dibujar un guion en los tres tercios. 0x4542 son diez bytes que '
         'son la <b>pareja de <code>prepara_escritura_vdp</code> para '
         'LEER</b> de la VRAM: llama a SETRD y coge el puerto de lectura de '
         '0x0007, igual que la otra coge el de escritura de 0x0006.</p>'
         '<p>Ninguna se llama, y no es una impresion: los pares de bytes '
         '<b>01 45</b> y <b>42 45</b> no aparecen en ningun sitio de los '
         '16.384, comprobado byte a byte. La segunda cuenta algo del diseno '
         'del juego: <b>este cartucho nunca lee de la VRAM</b>. Escribe y se '
         'olvida.</p>'),
        ('Seis listas de entidades, seis pasos distintos',
         '<p>El juego lleva seis tablas paralelas de entidades y cada una '
         'tiene su propia rutina de acceso. No hay que suponer el tamano de '
         'cada entrada: esta en la <b>multiplicacion</b>. 0x6A12 hace i, 3i, '
         '7i con B llevando las potencias de dos, o sea paso <b>7</b>; '
         '0x65A5 llega a 9i; 0x5AF6 entra a media cadena y llega a 17i; y '
         '0x73D3 hace 2i, 6i, 22i.</p>'
         '<p>Las de paso 7 y 9 comparten indice (0xE1F4): son dos bloques de '
         'campos de la <b>misma</b> entidad, partidos en dos zonas de '
         'memoria.</p>'),
        ('El parpadeo de los sprites esta repartido a proposito',
         '<p><code>actualiza_tabla_de_sprites</code> escribe siempre los '
         'mismos cuatro sprites en la tabla de atributos, pero empezando '
         'cada fotograma por uno distinto de un anillo de cuatro entradas, '
         'que gira con un contador en 0xE061.</p>'
         '<p>No es un adorno. En el MSX1 solo se ven <b>cuatro sprites por '
         'linea</b> y gana el de numero mas bajo; al girar el orden de '
         'escritura, el que se pierde cambia en cada fotograma y los cuatro '
         'parpadean por igual en vez de desaparecer siempre el mismo.</p>'),
        ('El color de la piedra cambia cada cuatro salas',
         '<p>Las salas salian negras sobre negro hasta dar con quien pone el '
         'color de los tiles de pared y suelo. No es <code>'
         'prepara_sala_nueva</code>: es <code>columna_decorativa</code> '
         '(0x6DA0), y el guion que usa depende del <b>grupo de cuatro '
         'niveles</b> -0x6DC4 mas 9 por grupo, con el grupo sacado de '
         '<code>(nivel-1) &gt;&gt; 2</code>-.</p>'
         '<p>Por eso las cuatro primeras salas son de piedra ocre y las '
         'siguientes cambian de color, con el <b>mismo dibujo de '
         'ladrillo</b>: lo unico que cambia son los ocho bytes de color.</p>'),
        ('Los textos van en ASCII menos 0x20',
         '<p>Los rotulos del cartucho no estan en ASCII ni en una fuente '
         'propia con tabla: estan en ASCII <b>desplazado 0x20 hacia '
         'abajo</b>. Los bytes <b>2B 2F 2E 21 2D 29</b> mas 0x20 dan '
         '<b>KONAMI</b>, y con la misma suma salen SCORE, HI, REST, PUSH '
         'SPACE KEY, PLAY START, GAME OVER, SOFTWARE y PYRAMID. El 0x00 es '
         'el espacio y el 0x1A el simbolo de copyright.</p>'),
        ('Si lleva la marca oculta de Konami',
         '<p>Konami escondio su numero de catalogo y el titulo en katakana al '
         'final de muchos cartuchos; lo descubrio <b>Manuel Pazos</b> '
         '(<a href="https://twitter.com/ManuelPazosMSX">@ManuelPazosMSX</a>). '
         'Este lo lleva, cerrando en 0x7FFF: <b>RC-727</b> y '
         '<b>OU KE NO TA NI</b>, que es el titulo japones del juego, '
         '<b>王家の谷</b>, el Valle de los Reyes.</p>'),
    ],
    "en": [
        ('The colour table sits underneath the pattern table',
         '<p>In SCREEN 2 the usual layout puts patterns at 0x0000 and colours '
         'at 0x2000. This cartridge does it <b>the other way round</b>, and '
         'you cannot see that in any address: you see it in the registers. '
         '<code>tabla_registros_vdp</code> (0x45C0) holds '
         '<b>02 E2 0E 7F 07 76 03 E4</b>, and in SCREEN 2 registers 3 and 4 '
         'are not an address but <b>base plus mask</b>: bit 7 of R3 clear '
         'puts colour at 0x0000, and bit 2 of R4 set puts patterns at '
         '0x2000.</p>'
         '<p>The code settles it: 0x4831 draws the wordmark with '
         '<code>ld hl,06300h</code>, and 0x6300 masked to fourteen bits is '
         '<b>0x2300</b>, inside the pattern table. Read it the usual way and '
         'the shapes come out right and the colours come out striped.</p>'),
        ('The explorer moves in twenty-four bits',
         '<p>X is not one byte, nor two: it is <b>three</b>. 0x73F6 adds the '
         'velocity with <code>add hl,de</code> over 0xE138/0xE139 and carries '
         'into 0xE13A with <code>adc a,c</code>. The lowest byte is the '
         '<b>fraction</b>, in 1/256 of a pixel, and the top two are exactly '
         'the ones <code>lee_celda_de_sala</code> takes as the whole-pixel X '
         'when it looks up a cell.</p>'
         '<p>It needs that much X because a room is wider than the screen: '
         'the even-numbered rooms are <b>48 columns</b>, 384 pixels, which '
         'will not fit in a byte. When the explorer walks off the side, task '
         '9 does <code>ld (0e139h),bc</code> and changes the high byte by '
         'one: a <b>256-pixel</b> jump, one whole screen.</p>'),
        ('Eighty-seven bytes of code that looked like data',
         '<p>Five entity loops do <code>ld hl,&lt;closer&gt; / push hl</code> '
         'before dispatching, so the <code>ret</code> of whatever they '
         'dispatch to <b>does not return to the caller</b>: it falls into the '
         'closer, which bumps the index and goes round again. A static '
         'tracer cannot follow that, because the address travels through the '
         'stack as if it were data.</p>'
         '<p>That is why 87 bytes were showing as "unidentified". All five '
         'closers have the same shape -<code>ld hl,&lt;index&gt; / inc (hl) / '
         'cp (hl) / jp nz,&lt;body&gt;</code>- and the body they jump to is '
         'exactly the label that pushed them.</p>'),
        ('Two routines nobody calls, and one of them tells you something',
         '<p>0x4501 is nineteen bytes that decode as another variant of '
         'drawing a script across the three thirds. 0x4542 is ten bytes that '
         'are the <b>counterpart of <code>prepara_escritura_vdp</code> for '
         'READING</b> VRAM: it calls SETRD and takes the read port from '
         '0x0007, just as the other takes the write port from 0x0006.</p>'
         '<p>Neither is called, and that is not an impression: the byte pairs '
         '<b>01 45</b> and <b>42 45</b> appear nowhere in the 16,384, checked '
         'byte by byte. The second one says something about how the game is '
         'built: <b>this cartridge never reads VRAM back</b>. It writes and '
         'forgets.</p>'),
        ('Six entity lists, six different strides',
         '<p>The game carries six parallel entity tables and each has its own '
         'accessor. You do not have to guess how big an entry is: it is in '
         'the <b>multiplication</b>. 0x6A12 does i, 3i, 7i with B carrying '
         'the powers of two, so stride <b>7</b>; 0x65A5 reaches 9i; 0x5AF6 '
         'joins the same chain halfway and reaches 17i; and 0x73D3 does 2i, '
         '6i, 22i.</p>'
         '<p>The stride-7 and stride-9 lists share an index (0xE1F4): they '
         'are two blocks of fields of the <b>same</b> entity, split across '
         'two areas of memory.</p>'),
        ('Sprite flicker is shared out on purpose',
         '<p><code>actualiza_tabla_de_sprites</code> always writes the same '
         'four sprites into the attribute table, but each frame it starts '
         'from a different one of a four-entry ring, rotated by a counter at '
         '0xE061.</p>'
         '<p>It is not decoration. On the MSX1 only <b>four sprites per '
         'scanline</b> are shown and the lowest-numbered ones win; rotating '
         'the write order means the one that drops out changes every frame, '
         'so all four flicker evenly instead of the same one always '
         'vanishing.</p>'),
        ('The stone changes colour every four rooms',
         '<p>The rooms came out black on black until we found who sets the '
         'colour of the wall and floor tiles. It is not '
         '<code>prepara_sala_nueva</code>: it is '
         '<code>columna_decorativa</code> (0x6DA0), and the script it uses '
         'depends on the <b>group of four levels</b> -0x6DC4 plus 9 per '
         'group, with the group taken from <code>(level-1) &gt;&gt; 2</code>-.'
         '</p><p>That is why the first four rooms are ochre stone and the '
         'next ones change colour with the <b>same brick artwork</b>: the '
         'only thing that changes is eight bytes of colour.</p>'),
        ('The text is ASCII minus 0x20',
         '<p>The cartridge’s labels are not in ASCII, and not in a '
         'private font with a lookup table either: they are ASCII '
         '<b>shifted down by 0x20</b>. The bytes <b>2B 2F 2E 21 2D 29</b> '
         'plus 0x20 give <b>KONAMI</b>, and the same sum gives SCORE, HI, '
         'REST, PUSH SPACE KEY, PLAY START, GAME OVER, SOFTWARE and PYRAMID. '
         '0x00 is the space and 0x1A the copyright sign.</p>'),
        ("It does carry Konami's hidden mark",
         '<p>Konami hid its catalogue number and the title in katakana at the '
         'end of many cartridges; <b>Manuel Pazos</b> '
         '(<a href="https://twitter.com/ManuelPazosMSX">@ManuelPazosMSX</a>) '
         'found it. This one has it, ending at 0x7FFF: <b>RC-727</b> and '
         '<b>OU KE NO TA NI</b>, the game’s Japanese title, '
         '<b>王家の谷</b>, the Valley of the Kings.</p>'),
    ],
}

GALERIA = [
    ("titulo.png",
     "<b>La pantalla de titulo</b>, montada con los pasos del propio "
     "cartucho: el guion de 0x4874 deja el dibujo del logotipo en la tabla de "
     "patrones, los catorce pasos de <code>tarea_0_desplaza_logo</code> "
     "escriben sus veintiseis tiles en la tabla de nombres, y los guiones de "
     "texto de 0x47FE y 0x47C1 ponen SOFTWARE, el copyright y el aviso",
     "<b>The title screen</b>, built with the cartridge's own steps: the "
     "script at 0x4874 lays the wordmark's artwork into the pattern table, "
     "the fourteen steps of <code>tarea_0_desplaza_logo</code> write its "
     "twenty-six tiles into the name table, and the text scripts at 0x47FE "
     "and 0x47C1 add SOFTWARE, the copyright and the prompt"),
    ("sala_02.png",
     "<b>La segunda piramide</b>, entera. Las salas pares tienen tres bandas "
     "de dieciseis columnas: <b>48 en total</b>, mas ancho que la pantalla, y "
     "de ahi que la X del explorador necesite dos bytes enteros. El dibujo "
     "sale de desempaquetar bit a bit el patron de pared, igual que "
     "<code>carga_la_sala</code>",
     "<b>The second pyramid</b>, whole. Even-numbered rooms have three bands "
     "of sixteen columns: <b>48 in all</b>, wider than the screen, which is "
     "why the explorer's X needs two full bytes. The picture comes from "
     "unpacking the wall pattern bit by bit, exactly as "
     "<code>carga_la_sala</code> does"),
    ("sala_06.png",
     "<b>La sexta piramide</b>, con el mismo dibujo de ladrillo y otro color. "
     "Lo unico que cambia entre un grupo de cuatro salas y el siguiente son "
     "los ocho bytes de color que <code>columna_decorativa</code> escribe en "
     "los tiles 0x40 a 0x44",
     "<b>The sixth pyramid</b>, same brick artwork, different colour. The "
     "only thing that changes between one group of four rooms and the next "
     "is the eight bytes of colour <code>columna_decorativa</code> writes "
     "into tiles 0x40 to 0x44"),
    ("sala_01.png",
     "<b>La primera piramide.</b> Las salas impares tienen una sola banda de "
     "dieciseis columnas y caben de sobra en una pantalla: el explorador "
     "nunca llega a cambiar el byte alto de su X",
     "<b>The first pyramid.</b> Odd-numbered rooms have a single band of "
     "sixteen columns and fit inside one screen with room to spare: the "
     "explorer never gets to change the high byte of his X"),
    ("sprites.png",
     "Los <b>64 sprites de 16x16</b> de la tabla 0x1800-0x1FFF, tal como los "
     "dejan los seis guiones del cartucho que escriben ahi. Se reconocen las "
     "posturas del explorador andando y picando, la joya y las herramientas. "
     "Las filas vacias son las que ningun guion localizado llena",
     "The <b>64 16x16 sprites</b> of the 0x1800-0x1FFF table, as the "
     "cartridge's six scripts that write there leave them. The explorer's "
     "walking and digging poses are recognisable, along with the jewel and "
     "the tools. The empty rows are the ones no located script fills"),
    ("pantalla_de_sala.png",
     "La <b>pantalla entre salas</b>, con la piramide y sus joyas. La monta "
     "<code>monta_pantalla_de_sala</code> (0x773C) con tres guiones: dos para "
     "los patrones y el color, y el tercero -0x7908- para los sprites, que "
     "empieza por el word 0x1F20 y por eso va a la tabla de sprites",
     "The <b>between-rooms screen</b>, with the pyramid and its jewels. "
     "<code>monta_pantalla_de_sala</code> (0x773C) builds it from three "
     "scripts: two for the patterns and colour, and the third -0x7908- for "
     "the sprites, which starts with the word 0x1F20 and so lands in the "
     "sprite table"),
    ("pantalla_final.png",
     "La <b>pantalla final</b>, con sus rotulos que se estiran. No son un "
     "dibujo: <code>rotulo_horizontal</code> (0x76A7) escribe un tile de "
     "remate y va rellenando hacia un lado, bajando una fila y creciendo una "
     "celda en cada vuelta hasta pasar de la VRAM 0x3A80",
     "The <b>final screen</b>, with its labels that stretch. They are not "
     "artwork: <code>rotulo_horizontal</code> (0x76A7) writes one end tile "
     "and fills sideways, dropping a row and growing one cell each time "
     "round until it passes VRAM 0x3A80"),
    ("marco_de_juego.png",
     "El <b>marco de la pantalla de juego</b> sin sala dentro, tal como lo "
     "deja <code>prepara_sala_nueva</code> (0x4FC9). Los tiles de pared ya "
     "estan cargados pero todavia sin color: ese lo pone "
     "<code>columna_decorativa</code> despues, y es lo que hace que cada "
     "grupo de cuatro salas tenga su piedra",
     "The <b>game screen's frame</b> with no room in it, as "
     "<code>prepara_sala_nueva</code> (0x4FC9) leaves it. The wall tiles are "
     "loaded but still colourless: <code>columna_decorativa</code> supplies "
     "that afterwards, and it is what gives each group of four rooms its own "
     "stone"),
]


def img64(ruta):
    with open(ruta, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    imgdir, salida, idioma = argv[1:4]
    t = TXT[idioma]

    # El "logotipo" de la cabecera no es un montaje ni una captura: es el rotulo
    # que el propio cartucho pinta en su pantalla de titulo, dibujado desde la
    # ROM por graficos.py. Si el PNG no esta, el trabajo NO esta hecho: se cae
    # al texto, y eso se ve.
    ruta_logo = os.path.join(imgdir, "rotulo.png")
    cabecera = (f'<img src="{img64(ruta_logo)}" alt="King&#39;s Valley">'
                if os.path.exists(ruta_logo) else "<h1>King&#39;s Valley</h1>")

    nav = "".join(f'<a href="{h}">{x}</a>' for h, x in t["nav"])
    nav += "".join(f'<a href="{h}">{x}</a>' for h, x in t["docnav"])
    nav += (f'<a href="{t["otro"][0]}" style="margin-left:auto;color:var(--oro)">'
            f'{t["otro"][1]}</a>')

    cifras = "".join(f'<div class="cifra"><b>{v}</b><span>{e}</span></div>'
                     for v, e in t["cifras"])
    halls = "".join(f'<div class="hall"><h3>{tit}</h3>{cuerpo}</div>'
                    for tit, cuerpo in HALLAZGOS[idioma])
    imgs = ""
    faltan = []
    for fich, es, en in GALERIA:
        ruta = os.path.join(imgdir, fich)
        if not os.path.exists(ruta):
            faltan.append(fich)
            continue
        pie = es if idioma == "es" else en
        imgs += (f'<figure><img src="{img64(ruta)}" alt="{pie}">'
                 f'<figcaption>{pie}</figcaption></figure>')
    if faltan:
        print("  (faltan %d imagenes: %s)" % (len(faltan), " ".join(faltan)))

    html = f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{t['titulo']}</title>
<style>{ESTILO}</style>
<header class="top">
  {cabecera}
  <p class="claim">{t['claim']}</p>
  <p class="ficha">{' - '.join(t['ficha'])}</p>
</header>
<p class="ficha" style="border:1px solid var(--oro);padding:.8em 1em;margin:1.5em 0">
{t['aviso']}</p>
<nav>{nav}</nav>
<section id="numbers">
  <h2>{t['h_num']}</h2>
  <div class="cifras">{cifras}</div>
</section>
<section id="findings"><h2>{t['h_find']}</h2>{halls}</section>
<section id="screens">
  <h2>{t['h_scr']}</h2>
  <p class="n">{t['nota_scr']}</p>
  <div class="galeria">{imgs}</div>
</section>
<footer><p>{t['pie_leg']}</p></footer>
"""
    with open(salida, "w", encoding="utf-8") as f:
        f.write(html)
    print("  %s: %d KB (%s)" % (salida, len(html) // 1024, idioma))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
