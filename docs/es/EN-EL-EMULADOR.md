# En el emulador

Leer opcodes no basta para todo. Algunas cosas sólo se pueden cerrar mirando lo
que la máquina hace de verdad, y para eso hay ocho guiones de openMSX en
`tools/`.

Todos siguen el mismo patrón: un breakpoint en `INIT` (0x406C) para armar los
watchpoints **después** de que la página 1 sea de verdad el cartucho, entrada
conducida a ciegas con pulsaciones al azar de semilla fija, y un perro guardián
en tiempo real por si algo se cuelga.

```
"C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
    -cart kingsvalley.rom -script tools/omsx_task_trace.tcl
```

## `omsx_task_trace.tcl` — el ciclo de las tareas

Watchpoint de escritura en 0xE000, el índice de la tarea activa, con captura de
pantalla y PC en cada cambio. Noventa segundos de menú y demo.

El ciclo completo salió así, identificado **por las capturas**, no adivinado:

```
0 (logo Konami) -> 1 (título) -> 3 -> 4 (nombre de sala) -> 5 (sala en reposo)
  -> 6 (la demo se mueve) -> [4 otra vez, repite] -> 7 (pausa) -> 0
```

**La sorpresa que casi arruina la tanda**: las transiciones 0→1 y 1→3 no las
dispara la cascada natural de fotogramas de cada tarea —que existe y se lee
bien en los opcodes— sino `revisa_teclado_y_salta_menu` (0x4644). El PC de la
escritura, medido, cae en 0x4663 y 0x4679, dentro de esa rutina. Como el guion
de prueba pulsa teclas desde el segundo 1,5, el camino «saltar con una tecla»
gana siempre a la espera natural.

Sin ese segundo campo `PC=` en el registro, el comentario habría atribuido las
transiciones a la rutina equivocada.

## `omsx_dump_sala.tcl` — el buffer de la sala

Breakpoint en 0x6B09, el `exx` que cierra el desempaquetado de **una banda**, y
volcado de 0xE700 en adelante.

Antes se probó en 0x6D3B —el primer `ret` que aparece en el listado por ahí— y
daba la fila 0 bien y 0xFF en el resto: ese `ret` cierra **otra** rutina, no el
final real del desempaquetado. Con el breakpoint bueno: **0 diferencias en 352
celdas** de la sala 1 contra el decodificador de Python.

De esa comprobación salieron dos correcciones que la lectura estática no había
cazado:

- El paso del patrón de pared es de **44 bytes**, no de 22. El 22 es el
  contador del bucle de filas, no el multiplicador de la dirección: dos números
  iguales por coincidencia. Con 44 encaja exacto con los cuatro tamaños de
  bloque (176/44 = 4, 132/44 = 3, sin resto).
- El salto de fila del buffer no es +0x50 —el operando literal del
  `ld a,050h`— sino **+0x60**: a esos 0x50 hay que sumarles los dieciséis que
  ya avanzó la propia fila escribiéndose. Sin este ajuste la fila 0 cuadraba
  por casualidad y todo lo demás no.

## `omsx_dump_sprites.tcl` — la tabla de atributos

Vuelca la VRAM 0x3B00-0x3B7F y la RAM 0xE0B0-0xE12F en siete instantes, y
además busca qué celdas de la tabla de nombres usan los patrones 0x51, 0x52,
0x53 y 0x5C.

Confirmó tres cosas: que la tabla de nombres mide 768 bytes desde 0x3800 y
acaba justo en 0x3AFF, pegada a la de atributos; que los valores del buffer son
Y/X/patrón/color plausibles, con Y=0xE1 (−31) en las entradas aparcadas fuera
de pantalla; y que el patrón que reescribe `parpadea_patron_borde` (0x0288/8 =
0x51 exacto) es byte a byte el mismo índice que usan las cuatro esquinas del
marco de piedra en las cinco salas muestreadas.

## `omsx_check_4644.tcl` — la escritura que nunca llega

0x403E hace código automodificante: escribe un `pop hl` + `ret` encima del
primer byte de la tarea 1. Pero lo hace **idéntico cada vez** sin leer ningún
estado que cambie, y eso no encajaba.

Breakpoints en 0x4644, 0x403E y 0x40E4, 120 segundos emulados. Resultado real:
0x403E se ejecuta **92 veces** —o sea que es ruta normal, no un caso raro—,
pero el primer byte de la tarea 1 sigue leyendo 0x10 las nueve veces que esa
tarea corre después, porque la escritura cae en **0x4000-0x7FFF, que es ROM**.

Lo que esa medición no podía decir es *por qué*. Es una **protección
anticopia**: inofensiva en un cartucho, letal en una copia cargada en RAM. Ver
[Hallazgos](HALLAZGOS.html).

## `omsx_dump_mapa.tcl` — la sala entera, con sus elementos

`omsx_dump_sala.tcl` para en mitad del desempaquetado de una banda, y eso sólo
demuestra las paredes. Éste para en 0x4176, el primer sitio donde
`carga_la_sala` y `reparte_entidades_de_la_sala` ya han terminado y todavía no
ha pintado nadie la puerta de entrada, y vuelca el buffer de mapa entero,
23x96, desde 0xE700.

La demo sólo juega la pirámide 5, así que el nivel se **fuerza** en 0x6A90
—0xE054 y 0xE055 las dos, porque lo primero que hace esa rutina es copiar una
sobre la otra— y la máquina se reinicia entre nivel y nivel.

    python3 tools/mapas.py --comprueba kingsvalley.rom 0x4000 work/omsx_mapa

**Quince volcados, 31.680 celdas comparadas, 0 diferencias.**

## `omsx_vram_sala.tcl` — la imagen misma

El mismo forzado, pero parando en 0x4185, con la sala ya en pantalla y los
sprites puestos, y volcando los 16 KB de VRAM y los ocho registros del VDP.
Después, dos segundos emulados más tarde, otra vez la tabla de atributos de
sprites: las momias no están cuando se monta la sala, llegan con un
temporizador, y de ahí salen los dos colores del explorador y el color de cada
tipo de momia.

    python3 tools/mapas.py --vram kingsvalley.rom 0x4000 work/omsx_vram

**Quince niveles; tabla de nombres, de patrones, de color y de patrones de
sprites; 0 diferencias.** De las tablas de patrones y color sólo se exigen los
tiles que la pantalla usa de verdad: el resto son restos de la pantalla de
título que el juego ni reescribe ni mira.

## `omsx_vram_menus.tcl` — la pantalla de título y el mapa del valle

Las salas estaban comparadas contra la máquina; las pantallas de menú no, y
ahí se escondían dos errores. Esto vuelca las dos.

La de título se pilla en 0x43B7, el final de `dibuja_titulo_y_texto_ya`. El
mapa del valle es más difícil: sólo sale al pasarse una pirámide, y la demo no
se pasa ninguna. Se fuerza en 0x4176 —un punto que se ejecuta cada vez que se
monta una sala— **borrando la tabla de nombres entera** y poniendo el PC en
0x41C0, que es la pareja de llamadas que monta el mapa. Borrar antes es lo que
hace concluyente el volcado: lo que aparezca después en la tabla de nombres lo
ha escrito el código del mapa y nadie más.

    cd tools && python pantallas.py --vram ../kingsvalley.rom 0x4000         ../work/omsx_menus

**Dos pantallas; tabla de nombres, de patrones y de color; 0 diferencias.**

## `omsx_barrido_huecos.tcl` y `omsx_quien_lee.tcl`

Los dos genéricos: el primero recorre los huecos sin clasificar poniendo
watchpoints de lectura, y el segundo contesta a «quién lee esta dirección»
poniendo un watchpoint y anotando el PC.

## Lo que NO está comprobado en caliente

Hay que decirlo con la misma claridad:

- La **pantalla final** y la del **logotipo de Konami** no se han comparado
  byte a byte contra la VRAM del emulador. La de título, el mapa del valle y
  las quince pirámides sí, y cuadran exactamente.
- Que **0xE130 sea el contador de fotogramas** de la pantalla en reposo está
  deducido de cómo se usa —se incrementa una vez por fotograma y se compara
  contra dos plazos, 0x58 y 0xE0—, no medido.
- Cuánto **dura cada etapa** de la cascada de la tarea 0 no se ha medido: la
  entrada del guion de prueba se adelanta siempre.
