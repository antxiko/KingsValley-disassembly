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
        claim="Dos protecciones anticopia que solo se disparan si el "
              "cartucho corre desde RAM, quince piramides dibujadas byte a "
              "byte contra la VRAM de una maquina de verdad, y las figuras "
              "que miran al otro lado, que no estan en la ROM: se fabrican "
              "dandole la vuelta a los bits.",
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
        claim="Two copy protections that only fire if the cartridge runs "
              "from RAM, fifteen pyramids drawn and matched byte for byte "
              "against a real machine's VRAM, and the figures facing the "
              "other way, which are not in the ROM at all: they are made by "
              "reversing the bits.",
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
         'las salas pares miden <b>64 columnas</b>, 512 pixeles, y no caben '
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
        ('Seis listas de entidades, y que es cada una',
         '<p>El juego lleva seis tablas paralelas de entidades y cada una '
         'tiene su propia rutina de acceso. No hay que suponer el tamano de '
         'cada entrada: esta en la <b>multiplicacion</b>. 0x6A12 hace i, 3i, '
         '7i con B llevando las potencias de dos, o sea paso <b>7</b>; '
         '0x65A5 llega a 9i; 0x5AF6 entra a media cadena y llega a 17i; y '
         '0x73D3 hace 2i, 6i, 22i.</p>'
         '<p>Leer el descriptor de nivel byte a byte dice que hay en cada '
         'una: paso 7 las <b>puertas de salida</b> y las <b>puertas '
         'giratorias</b>, paso 9 las <b>gemas</b> y los <b>muros trampa</b>, '
         'paso 17 los <b>cuchillos ya lanzados</b> y paso 22 las '
         '<b>momias</b>. Las de paso 7 y 9 comparten indice, pero no son la '
         'misma entidad partida en dos: son las puertas y las gemas, y lo '
         'que comparten es una variable de contador.</p>'),
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
        ('El cartucho se defiende, dos veces',
         '<p>Dos rutinas escriben dentro del propio espacio del cartucho, y '
         'corriendo desde ROM ninguna hace nada. No son codigo muerto: son '
         '<b>proteccion anticopia</b>, y que no hagan nada es la gracia. Un '
         'cartucho pirateado es una copia en RAM, y ahi las escrituras si '
         'cuelan.</p>'
         '<p><b>0x403E</b> machaca el primer byte de la tarea 1 con un '
         '<code>pop hl</code> + <code>ret</code>; <b>0x409C</b> escribe DE '
         'encima de 0x43C0, que es el <b>operando</b> del <code>jp nc</code> '
         'de 0x43BF. Las identifico <b>Manuel Pazos</b> en su desensamblado '
         'de 2009; este proyecto tenia una escrita como parche fallido y la '
         'otra como direccion de relleno.</p>'),
        ('Esta es la primera version, y hay una segunda',
         '<p>En <b>0x5817</b> nuestra ROM tiene las tres comparaciones '
         'sueltas que la segunda compilacion sustituye por dos restas, y la '
         'firma de la segunda no aparece en ninguno de los 16.384 bytes. Lo '
         'desensamblado aqui es la <b>version 1</b>, con sus fallos: lanzar '
         'un cuchillo mientras la puerta se abre corrompe sus tiles, '
         'lanzarlo pegado a un objeto lo atraviesa, y dos muros trampa estan '
         'mal colocados.</p>'),
        ('Cada sala es el doble de ancha de lo que parece',
         '<p>El <code>pop de</code> de <b>0x6B0E</b> devuelve el puntero a '
         'la banda que se <b>acaba</b> de desempaquetar, asi que el '
         '<code>cp 030h</code> de dos instrucciones despues mira ESA banda y '
         'no la siguiente: la banda 0x3x se dibuja <b>y ademas</b> cierra la '
         'lista. Leido al reves se pierde una banda por sala.</p>'
         '<p>El arreglo no es una opinion: el buffer de sala se comparo '
         'contra la RAM de una maquina de verdad en las quince piramides, '
         '<b>31.680 celdas sin una diferencia</b>, y las pantallas dibujadas '
         'contra su VRAM -nombres, patrones, color y sprites-, tambien con '
         '<b>cero</b>.</p>'),
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
         'the even-numbered rooms are <b>64 columns</b>, 512 pixels, which '
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
        ('Six entity lists, and what each of them is',
         '<p>The game carries six parallel entity tables and each has its own '
         'accessor. You do not have to guess how big an entry is: it is in '
         'the <b>multiplication</b>. 0x6A12 does i, 3i, 7i with B carrying '
         'the powers of two, so stride <b>7</b>; 0x65A5 reaches 9i; 0x5AF6 '
         'joins the same chain halfway and reaches 17i; and 0x73D3 does 2i, '
         '6i, 22i.</p>'
         '<p>Reading the level descriptor byte by byte says what each one '
         'holds: stride 7 the <b>exit doors</b> and the <b>revolving '
         'doors</b>, stride 9 the <b>jewels</b> and the <b>trap walls</b>, '
         'stride 17 the <b>knives already thrown</b> and stride 22 the '
         '<b>mummies</b>. The stride-7 and stride-9 lists share an index, but '
         'they are not one entity split in two: they are the doors and the '
         'jewels, and what they share is a counter variable.</p>'),
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
        ('The cartridge defends itself, twice',
         '<p>Two routines write into the cartridge&rsquo;s own address space, '
         'and '
         'from ROM neither does anything. They are not dead code: they are '
         '<b>copy protection</b>, and doing nothing is the whole point. A '
         'pirated cartridge is a copy in RAM, and there the writes land.</p>'
         '<p><b>0x403E</b> smashes the first byte of task 1 with a '
         '<code>pop hl</code> + <code>ret</code>; <b>0x409C</b> writes DE '
         'over 0x43C0, which is the <b>operand</b> of the <code>jp nc</code> '
         'at 0x43BF. <b>Manuel Pazos</b> identified both in his 2009 '
         'disassembly; this project had one written up as a failed patch and '
         'the other as a fill address.</p>'),
        ('This is the first version, and there is a second',
         '<p>At <b>0x5817</b> our ROM has the three separate comparisons the '
         'second build replaces with two subtractions, and the second '
         'build&rsquo;s signature appears nowhere in the 16,384 bytes. What is '
         'disassembled here is <b>version 1</b>, bugs included: throwing a '
         'knife while the door opens corrupts its tiles, throwing it against '
         'an object passes through it, and two trap walls sit in the wrong '
         'place.</p>'),
        ('Every room is twice as wide as it looks',
         '<p>The <code>pop de</code> at <b>0x6B0E</b> restores the pointer to '
         'the band that has <b>just</b> been unpacked, so the '
         '<code>cp 030h</code> two instructions later tests THAT band, not '
         'the next one: the 0x3x band is drawn <b>and</b> ends the list. Read '
         'the other way round it loses one band per room.</p>'
         '<p>The fix is not an opinion: the room buffer was compared against '
         'the RAM of a real machine for all fifteen pyramids, <b>31,680 '
         'cells with no difference</b>, and the drawn screens against its '
         'VRAM - name, pattern, colour and sprite tables - also with '
         '<b>zero</b>.</p>'),
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
    ("sala_01.png",
     "<b>La primera piramide, entera y con todo dentro</b>: las cuatro gemas "
     "con sus destellos, las ocho escaleras, el cuchillo del suelo, la puerta "
     "de salida con su palanca y las dos momias en su sitio de partida. No es "
     "una captura: es el descriptor del nivel desempaquetado con las mismas "
     "cuentas que <code>carga_la_sala</code>, y comparado byte a byte contra "
     "la RAM y la VRAM de una maquina de verdad",
     "<b>The first pyramid, whole and with everything in it</b>: the four "
     "jewels with their sparkles, the eight ladders, the knife on the floor, "
     "the exit door with its lever and the two mummies where they start. Not "
     "a screenshot: it is the level descriptor unpacked with the same "
     "arithmetic <code>carga_la_sala</code> uses, and compared byte for byte "
     "against the RAM and VRAM of a real machine"),
    ("sala_02.png",
     "<b>La segunda piramide.</b> Las salas pares tienen cuatro bandas de "
     "dieciseis columnas: <b>64 en total, dos pantallas</b>, y de ahi que la "
     "X del explorador necesite dos bytes enteros. Aqui hay ademas siete "
     "picos, dos puertas giratorias y dos muros trampa",
     "<b>The second pyramid.</b> Even-numbered rooms have four bands of "
     "sixteen columns: <b>64 in all, two screens</b>, which is why the "
     "explorer's X needs two whole bytes. This one also has seven pickaxes, "
     "two revolving doors and two trap walls"),
    ("sala_10.png",
     "<b>La decima piramide</b>, con el mismo dibujo de ladrillo y otro "
     "color. Lo unico que cambia entre un grupo de cuatro salas y el "
     "siguiente son los ocho bytes de color que "
     "<code>columna_decorativa</code> escribe en los tiles 0x40 a 0x44",
     "<b>The tenth pyramid</b>, same brick artwork, different colour. The "
     "only thing that changes between one group of four rooms and the next "
     "is the eight bytes of colour <code>columna_decorativa</code> writes "
     "into tiles 0x40 to 0x44"),
    ("figuras.png",
     "<b>Todas las figuras del cartucho, con su nombre.</b> El explorador "
     "tiene tres juegos de sprites -con las manos vacias, con el cuchillo y "
     "con el pico- que se cargan en la MISMA direccion de VRAM, y por eso "
     "solo puede haber uno a la vez. Mirando al otro lado no hay dibujos: se "
     "fabrican al vuelo dandole la vuelta a los bits. Los rotulos de esta "
     "lamina estan escritos con la tipografia del propio cartucho",
     "<b>Every figure in the cartridge, named.</b> The explorer has three "
     "sprite sets -empty-handed, with the knife and with the pickaxe- that "
     "load into the SAME VRAM address, which is why only one can be there at "
     "a time. There is no artwork for facing the other way: it is made on the "
     "fly by reversing the bits. The captions on this sheet are written in "
     "the cartridge's own typeface"),
    ("pantalla_de_sala.png",
     "El <b>mapa del valle</b>: las quince piramides y el rotulo GOAL. No es "
     "una lista de niveles sino un <b>anillo</b>, y cada puerta de cada "
     "piramide lleva escrito a cual de ellas lleva. Lo monta "
     "<code>monta_el_mapa_del_valle</code> (0x773C) con tres guiones: dos "
     "para los patrones y el color, y el tercero -0x7908- para los sprites",
     "The <b>valley map</b>: the fifteen pyramids and the GOAL sign. It is "
     "not a list of levels but a <b>ring</b>, and every door in every pyramid "
     "carries the number of the pyramid it leads to. "
     "<code>monta_el_mapa_del_valle</code> (0x773C) builds it from three "
     "scripts: two for the patterns and colour, and the third -0x7908- for "
     "the sprites"),
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
