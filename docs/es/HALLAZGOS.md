# Hallazgos

Lo que apareció al desmontar el cartucho, con la evidencia de cada cosa.

## La tabla de colores va debajo de la de patrones

En SCREEN 2 lo normal es poner los patrones en 0x0000 y los colores en 0x2000.
Este cartucho lo hace **al revés**, y eso no se ve en ninguna dirección del
código: se ve en los registros.

`tabla_registros_vdp` (0x45C0) vale `02 E2 0E 7F 07 76 03 E4`. En SCREEN 2 los
registros 3 y 4 **no son una dirección**: son base más máscara.

- **R3 = 0x7F** — su bit 7 está a **cero**, así que la tabla de color va a
  0x0000. Los siete bits bajos son una máscara, y a 0x7F no restringen nada.
- **R4 = 0x07** — su bit 2 está a **uno**, así que la tabla de patrones va a
  0x2000. Los dos bits bajos, a 3, tampoco restringen.

El propio código lo confirma sin dejar sitio a la duda: `prepara_scroll_del_logo`
(0x4823) dibuja el logotipo con `ld hl,06300h`, y 0x6300 enmascarado a catorce
bits —que es lo que hace SETWRT— es **0x2300**, dentro de la tabla de patrones.
Dos instrucciones más abajo rellena en 0x0300, dentro de la de color.

Leerlo al derecho tiene un síntoma característico: las **formas salen bien** y
los **colores salen a franjas**.

## El explorador se mueve en veinticuatro bits

La X no es un byte ni dos: son tres. `avanza_posicion_24_bits` (0x73F6) suma la
velocidad con `add hl,de` sobre 0xE138/0xE139 y propaga el acarreo a 0xE13A con
`adc a,c`.

El byte de menos peso es la **fracción**, en 1/256 de píxel, y los dos de más
peso son justo los que `lee_celda_de_sala` toma como X entera para mirar una
celda. Los dos usos encajan sin tener que ajustar nada.

Hace falta tanta X porque **la sala es más ancha que la pantalla**: las salas
pares miden 48 columnas, 384 píxeles, y no caben en un byte. Cuando el
explorador sale por un lateral, `sale_por_el_lateral` (0x4BBC) manda a la tarea
9, y ésta hace `ld (0e139h),bc` con la X baja en 0xF0 o en 0x04 —el borde
opuesto— y el byte alto cambiado en uno: un salto de **256 píxeles**, una
pantalla entera.

Tres rutinas independientes coinciden en el mismo formato sin copiarse la cifra
la una de la otra.

## Ochenta y siete bytes de código que parecían datos

Cinco recorridos de entidades hacen `ld hl,<cierre>` y `push hl` antes de
despachar, de modo que el `ret` de la rutina despachada **no vuelve al
llamador**: cae en el cierre, que sube el índice y repite el bucle.

Un trazador estático no puede seguir eso, porque la dirección viaja por la pila
como si fuera un dato. Por eso 87 bytes salían como «sin identificar» en el
presupuesto, y por eso ese presupuesto llevaba fallando desde el principio del
proyecto.

Los cinco tienen la misma forma —`ld hl,<índice>` / `inc (hl)` / `cp (hl)` /
`jp nz,<cuerpo>`— y el cuerpo al que saltan es exactamente la etiqueta que los
apila. Declarados en el `.entries`, el presupuesto cierra en cero.

## Dos rutinas que no llama nadie, y una de ellas dice algo

- **0x4501**, diecinueve bytes, decodifican como otra variante de dibujar un
  guion en los tres tercios, ésta con el contador en el juego de registros
  alterno.
- **0x4542**, diez bytes, son la pareja de `prepara_escritura_vdp` **para
  LEER** de la VRAM: llama a SETRD (BIOS 0x0050) y coge el puerto de lectura de
  la variable de sistema 0x0007, igual que la otra coge el de escritura de
  0x0006.

Ninguna de las dos se llama, y eso no es una impresión: los pares de bytes
**01 45** y **42 45** no aparecen en ningún sitio de los 16.384, comprobado
byte a byte en los dos órdenes posibles.

La segunda cuenta algo del diseño del juego: **este cartucho nunca lee de la
VRAM**. Escribe y se olvida. Todo el estado vive en RAM, incluido un buffer
completo de la sala.

## Seis listas de entidades, seis pasos distintos

Seis tablas paralelas, cada una con su rutina de acceso, y el tamaño de cada
entrada no hay que suponerlo: está en la multiplicación. 0x6A12 hace i, 3i, 7i
con B llevando las potencias de dos; 0x65A5 llega a 9i; 0x5AF6 entra a media
cadena y llega a 17i; 0x73D3 hace 2i, 6i, 22i.

Las de paso 7 y 9 comparten índice: son dos bloques de campos de la **misma**
entidad, partidos en dos zonas de memoria.

## El parpadeo de los sprites está repartido a propósito

`actualiza_tabla_de_sprites` (0x4B75) escribe siempre los mismos cuatro sprites
en la tabla de atributos, pero empezando cada fotograma por uno distinto de un
anillo de cuatro entradas en 0xE0C8, que gira con un contador en 0xE061.

No es un adorno. En el MSX1 sólo se ven **cuatro sprites por línea de barrido**
y gana el de número más bajo; al girar el orden de escritura, el que se pierde
cambia en cada fotograma y los cuatro parpadean por igual en vez de desaparecer
siempre el mismo. Encaja con que 0x4364 aparque exactamente diez sprites a
partir de esa misma dirección.

## El color de la piedra cambia cada cuatro salas

Las salas salían negras sobre negro al dibujarlas hasta dar con quién pone el
color de los tiles de pared y suelo. No es `prepara_sala_nueva`, que carga sus
patrones: es `columna_decorativa` (0x6DA0), y el guion que usa depende del
**grupo de cuatro niveles** —0x6DC4 más 9 por grupo, con el grupo sacado de
`(nivel-1) >> 2` y topado en 3—.

Por eso las cuatro primeras salas son de piedra ocre y las siguientes cambian
de color con el **mismo dibujo de ladrillo**: lo único que cambia son los ocho
bytes de color de los tiles 0x40 a 0x44.

## Los textos van en ASCII menos 0x20

Los rótulos no están en ASCII ni en una fuente propia con tabla de traducción:
están en ASCII **desplazado 0x20 hacia abajo**. Los bytes `2B 2F 2E 21 2D 29`
más 0x20 dan `4B 4F 4E 41 4D 49` = **KONAMI**, y con la misma suma salen SCORE,
HI, REST, PUSH SPACE KEY, PLAY START, GAME OVER, SOFTWARE y PYRAMID. El 0x00 es
el espacio y el 0x1A el símbolo de copyright.

Como los caracteres se escriben tal cual en la tabla de nombres, el **índice de
tile de cada letra es su propio código**.

## Un tramo de ROM que sirve a dos intérpretes

0x47FE es un guion de **gráficos** (lo llama `dibuja_guion_con_direccion`) que
escribe una barra decorativa y la palabra SOFTWARE en la tabla de nombres, y
acaba en el 0x00 de 0x480D.

0x480E —justo detrás— es un guion de **texto** que escribe el copyright y la
palabra PYRAMID. Pero 0x480E también cae *dentro* del tramo que recorrería el
primero si se leyera de otra manera. Son dos lenguajes distintos compartiendo
bytes contiguos, y leer uno con el intérprete del otro da ruido reconocible: al
dibujar la pantalla de título salieron bandas de KKKK y NNNN hasta separarlos.

## El bucle principal no existe

`arranca_el_juego` (0x406C) engancha la interrupción escribiendo un `jp` a mano
en 0xFD9A, borra la RAM de trabajo, prepara la pantalla y **cae en un bucle
vacío**. Todo el juego corre dentro de la interrupción.

No es una lectura nueva: es el mismo patrón que ya documentan los
desensamblados de Sky Jaguar y Konami's Golf para esta familia de cartuchos.

## Sí lleva la marca oculta de Konami

Konami escondió su número de catálogo y el título en katakana al final de
muchos cartuchos; lo descubrió **Manuel Pazos**
([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)).

Éste la lleva, cerrando en 0x7FFF:

```
RC-727    O U   KE   NO   TA   NI
```

**OU KE NO TA NI** es 王家の谷, el título japonés del juego: el *Valle de los
Reyes*.
