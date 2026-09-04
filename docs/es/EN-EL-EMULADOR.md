# En el emulador

Leer opcodes no basta para todo. Algunas cosas sólo se pueden cerrar mirando lo
que la máquina hace de verdad, y para eso hay cinco guiones de openMSX en
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

## `omsx_check_4644.tcl` — el parche que no hace nada

`L_403E` hace código automodificante: parchea el primer byte de la tarea 1 con
un `pop hl` + `ret`, neutralizándola. Pero lo hace **idéntico cada vez** sin
leer ningún estado que cambie, y eso no encajaba.

Breakpoints en 0x4644, 0x403E y 0x40E4, 120 segundos emulados. Resultado real:
0x403E se ejecuta **92 veces** —o sea que es ruta normal, no un caso raro—,
pero el primer byte de la tarea 1 sigue leyendo 0x10 las nueve veces que esa
tarea corre después.

La explicación es sencilla y no se veía leyendo: la escritura cae en
**0x4000-0x7FFF, que es ROM**. No tiene ningún efecto. Es un no-op.

## `omsx_barrido_huecos.tcl` y `omsx_quien_lee.tcl`

Los dos genéricos: el primero recorre los huecos sin clasificar poniendo
watchpoints de lectura, y el segundo contesta a «quién lee esta dirección»
poniendo un watchpoint y anotando el PC.

## Lo que NO está comprobado en caliente

Hay que decirlo con la misma claridad:

- Las **pantallas dibujadas** por `tools/pantallas.py` —el título, las salas
  con sus gráficos, la pantalla final— **no se han comparado byte a byte contra
  la VRAM del emulador**. Se han mirado, y salen reconocibles y coherentes: el
  logotipo de Konami sale nítido, lo que sólo puede pasar si la lectura de R3 y
  R4 es correcta. Pero mirar no es comparar.
- El **mapa de las salas** sí estaba comprobado (0 diferencias en 352 celdas),
  pero con el decodificador anterior, el que sólo daba pared o hueco. La
  traducción de celda a número de tile y los colores por grupo de nivel no lo
  están.
- Que **0xE130 sea el contador de fotogramas** de la pantalla en reposo está
  deducido de cómo se usa —se incrementa una vez por fotograma y se compara
  contra dos plazos, 0x58 y 0xE0—, no medido.
- Cuánto **dura cada etapa** de la cascada de la tarea 0 no se ha medido: la
  entrada del guion de prueba se adelanta siempre.
