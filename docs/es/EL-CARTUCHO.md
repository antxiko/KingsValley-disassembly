# El cartucho

**King's Valley**, Konami, 1985. Cartucho **RC-727**, 16.384 bytes, mapeado en
la página 1 del MSX (0x4000-0x7FFF).

```
sha256  a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73
```

## La cabecera

Los diez primeros bytes del volcado son:

```
41 42 6C 40 00 00 00 00 00 00
```

`41 42` es la marca `AB` que la BIOS busca para saber que hay un cartucho. Los
dos siguientes son la dirección de **INIT**, en little-endian: `6C 40` =
**0x406C**. El resto —`STATEMENT`, `DEVICE`, `TEXT`— está a cero: el cartucho
declara sólo INIT, y de ahí cuelga todo lo demás.

## Cómo arranca

`arranca_el_juego` (0x406C) hace cuatro cosas y ninguna más:

1. Engancha la interrupción **a mano**: escribe un 0xC3 (`jp`) en `H.KEYI`
   (0xFD9A) y detrás la dirección 0x401A. No usa ningún gancho de la BIOS;
   fabrica la instrucción byte a byte.
2. Pone la pila en 0xE700.
3. Borra 0xE000-0xE6FF con un `ldir`.
4. Llama a `prepara_pantalla` y **cae en un bucle vacío**.

A partir de ahí el juego entero corre **dentro de la interrupción**. El bucle
principal no existe: es un `jr` a sí mismo. Es el mismo patrón que ya
documentan los desensamblados de Sky Jaguar y de Konami's Golf para esta misma
familia de cartuchos Konami, así que no es una lectura nueva sino terminología
ya validada en otros dos proyectos.

## El reparto de los 16 KB

```
código trazado      9.803 bytes    59,83 %
datos declarados    6.581 bytes    40,17 %
sin explicar                0      0,00 %
```

Los 6.581 bytes de datos no son "lo que sobra": son 117 bloques declarados uno
a uno en `kingsvalley.notes` con una directiva `D` que dice qué son, y una `F`
que dice la anchura de su estructura —una palabra, siete bytes, dos bytes por
entrada—. Es la norma de la serie: cada tabla separada y con su nombre.

## Los registros del VDP

`tabla_registros_vdp` (0x45C0) son ocho bytes crudos, R0 a R7:

```
02 E2 0E 7F 07 76 03 E4
```

- **R0 = 0x02** — SCREEN 2.
- **R1 = 0xE2** — 16 KB, pantalla encendida, interrupción activa, y **sprites
  de 16×16**.
- **R2 = 0x0E** — tabla de nombres en 0x0E × 0x400 = **0x3800**.
- **R3 = 0x7F**, **R4 = 0x07** — aquí está la sorpresa; ver
  [Hallazgos](HALLAZGOS.html). En SCREEN 2 no son direcciones sino base más
  máscara, y lo que dicen es **color en 0x0000 y patrones en 0x2000**, al revés
  de lo habitual.
- **R5 = 0x76** — atributos de sprites en 0x3B00.
- **R6 = 0x03** — patrones de sprites en 0x1800.
- **R7 = 0xE4** — colores de borde y fondo.

## El mapa de la VRAM

Con esos registros, los 16 KB de VRAM quedan así:

```
0x0000 - 0x17FF   tabla de COLOR      (768 tiles x 8 bytes, tres tercios)
0x1800 - 0x1FFF   patrones de SPRITE  (64 sprites de 16x16)
0x2000 - 0x37FF   tabla de PATRON     (768 tiles x 8 bytes, tres tercios)
0x3800 - 0x3AFF   tabla de NOMBRES    (768 celdas, 24 filas x 32)
0x3B00 - 0x3B7F   atributos de SPRITE (32 entradas Y/X/patron/color)
```

La tabla de nombres acaba justo en 0x3AFF y la de atributos empieza en 0x3B00,
pegadas. Eso se comprobó en el emulador en una tanda anterior, volcando las dos
zonas a la vez.

## El mapa de la RAM

El juego usa de 0xE000 a 0xF000 largos. Lo más denso:

```
0xE000  índice de la tarea activa        0xE003  contador de fotogramas
0xE004  contador de la tarea             0xE009  entrada del fotograma
0xE010  bloque del motor de sonido PSG   0xE049  marcador, en BCD
0xE043  récord, en BCD                   0xE050  contador de rondas
0xE054  número de sala                   0xE0B0  buffer de sprites (32 x 4)
0xE134  registro del explorador          0xE14E  descriptor de los enemigos
0xE164  cuántos enemigos                 0xE16A  los enemigos (22 B cada uno)
0xE1C5  entidades de 7 bytes             0xE1F5  entidades de 9 bytes
0xE264  entidades de 17 bytes            0xE2CC  otra lista de 9 bytes
0xE31E  bloques que se abren (7 B)       0xE3FF  trampas (9 B)
0xE700  buffer de la sala, paso de fila 96 bytes
```

## La marca oculta de Konami

Konami escondió el número de catálogo y el título en katakana al final de
muchos de sus cartuchos. Lo descubrió **Manuel Pazos**
([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)), y hay que citarlo.

Este cartucho **la lleva**, cerrando justo en 0x7FFF:

```
RC-727    O U   KE   NO   TA   NI
```

`OU KE NO TA NI` es **王家の谷**, el título japonés del juego: el *Valle de los
Reyes*.

La búsqueda se hace con `tools/busca_marca_konami.py`, que rastrea las 16.384
posiciones, no sólo el final: hay cartuchos de esta familia donde la marca no
está donde se espera, y dar un negativo por bueno sin barrer la ROM entera es
la manera fácil de equivocarse.

## Los dos intérpretes de guiones

Casi todo lo que el cartucho dibuja está comprimido como **guiones** para uno
de dos intérpretes distintos. No hay que confundirlos, porque los mismos bytes
leídos con el otro dan ruido:

- **`dibuja_guion` (0x451A)** — el de gráficos. Un byte de comando: la cuenta
  son sus siete bits bajos, y el bit 7 decide entre copiar tantos bytes tal
  cual o repetir el siguiente byte esa cantidad de veces. `0x00` acaba y
  `0x80` encadena leyendo una dirección VRAM nueva.
- **`escribe_guion_de_texto` (0x4051)** — el de texto. Empieza con una palabra
  que es la dirección de VRAM, siguen caracteres sueltos, `0xFE` cambia de
  dirección y sigue, y `0xFF` acaba.

Un mismo tramo de ROM puede servir a los dos: 0x47FE es un guion de gráficos
que escribe letras en la tabla de nombres, y 0x480E —dieciséis bytes más
adelante, dentro del mismo tramo— es un guion de texto que empieza a media
altura y comparte la cola.
