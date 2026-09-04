# El juego

**King's Valley** es un juego de laberintos en pirámides: el explorador entra
en una cámara, recoge las joyas que hay repartidas por ella y sale por la
puerta que se abre cuando las ha cogido todas. Por el camino hay momias que lo
matan al tocarlo, bloques que se pueden picar y trampas que caen.

Todo lo que sigue está sacado del binario, no de jugar. Cuando algo no se ha
podido confirmar, se dice.

## Quince pirámides

`tabla_de_habitaciones` (0x6D68) tiene veintiuna palabras: las **quince
primeras** son un puntero al descriptor de cada nivel, y las cuatro últimas se
reutilizan como base de cada uno de los cuatro tipos de patrón de pared.

Cada descriptor empieza con hasta cuatro bytes de **banda**. Cada banda son
dieciséis columnas de pared, y su byte dice el tipo (nibble alto) y el índice
dentro de ese tipo (nibble bajo). La lista se acaba cuando el byte siguiente
tiene el nibble alto a 3.

Contadas así, las quince salas se reparten de una manera muy regular:

- las **impares** (1, 3, 5, 7, 9, 11, 13, 15) tienen **una** banda: 16 columnas.
- las **pares** (2, 4, 6, 8, 10, 12, 14) tienen **tres**: 48 columnas.

Las de 48 columnas son más anchas que la pantalla, y de ahí que la posición
horizontal del explorador necesite dos bytes enteros. Ver
[Hallazgos](HALLAZGOS.html).

## Cómo se dibuja una sala

`carga_la_sala` (0x6A90) no dibuja en la VRAM: **desempaqueta bit a bit** el
patrón de pared en un buffer de RAM que empieza en 0xE700. Cada byte del patrón
da ocho celdas, y cada bit dice pared (0x12) o hueco (0x00). Lo que las bandas
no cubren lo rellena antes `borra_sala` con 0x14.

El buffer tiene un **paso de fila de 96 bytes**, no de 16 ni de 48. Esa cifra
sale por dos caminos independientes: del `ld a,050h` del desempaquetado más los
dieciséis `inc de` que ya avanzó la propia fila (16+80=96), y de la aritmética
de `lee_celda_de_sala`, que multiplica la fila por 96 con cinco `add hl,hl` y
una suma. Dos rutinas distintas —una que escribe el buffer y otra que lo lee—
coinciden en el mismo número sin copiarlo la una de la otra.

Sólo después, `vuelca_la_vista` (0x5D31) copia una ventana de 22 filas por 32
columnas de ese buffer a la tabla de nombres, traduciendo cada celda con
`traduce_celda_a_patron`.

## Los tipos de celda

El **nibble alto** del byte de una celda dice de qué clase es. La clasificación
sale de cómo se usa cada una, no de mirarlas:

| nibble | qué es |
|---|---|
| `0x0x` | hueco: por donde se anda y por donde se cae |
| `0x1x` | suelo o pared sólida; es lo que `hay_suelo_bajo_los_pies` exige |
| `0x2x`, `0x3x` | las dos únicas que aceptan el paso en diagonal |
| `0x5x` | el bloque que se puede picar (subtipos 1 y 2) |

## El explorador

Su estado vive en un registro que empieza en 0xE134:

| dirección | qué es |
|---|---|
| `0xE134` | estado, de 0 a 6; indexa `tabla_4c7f` |
| `0xE135` | la entrada del mando ya procesada |
| `0xE136` | bit 0: hacia qué lado mira |
| `0xE137` | Y, en píxeles |
| `0xE138` | X, parte fraccionaria (1/256 de píxel) |
| `0xE139` | X, byte bajo |
| `0xE13A` | X, byte alto |

Los siete estados son el andar, el picar, el empujar y las transiciones entre
ellos. `avanza_estado_del_jugador` (0x4C59) da un paso a la máquina cada
fotograma, y apila `monta_sprite_del_jugador` como retorno para que el muñeco
se redibuje al terminar sea cual sea el estado.

Sólo los estados 0 y 3 aceptan entrada nueva; en los demás el explorador está a
medias de una acción y el mando no cuenta.

## Picar

Cuando el explorador empuja contra un bloque del tipo `0x5x` durante
**dieciséis fotogramas seguidos**, `jugador_anda_o_cae` lo pasa al estado 6 con
el efecto de sonido 0x03. El contador de esa racha está en 0xE146 y se pone a
cero en cuanto se rompe.

Los bloques que se abren son una lista aparte, de siete bytes por entrada, en
0xE31E. `marca_bloque_que_se_abre` (0x69C9) busca en ella el que esté justo
delante y le pone el bit 0 del campo 0; a partir de ahí,
`anima_bloques_que_se_abren` lo va abriendo en seis pasos, uno cada ocho
fotogramas.

## Las momias

Los enemigos son la lista de **22 bytes por entrada** que empieza en 0xE16A,
con el número en 0xE164. `mueve_los_enemigos` (0x6F5C) recorre la lista y
despacha cada uno por su estado con `tabla_6f78`, que tiene nueve entradas.

Cada enemigo tiene una **variante** (campo 0x14) que sale de sumar el avance de
la partida (0xE058) al tercer byte de su descriptor y topar el resultado en 4.
La variante decide su velocidad: `enemigo_estado_3` la usa para elegir una
máscara de fotogramas de la tabla de 0x716D, de modo que cada variante se mueve
a un ritmo distinto.

Los enemigos también buscan camino: `busca_camino` (0x734A) rastrea hacia los
dos lados, baja hasta cinco filas por la columna clasificando lo que encuentra,
y se queda con el camino más corto de los dos.

`busca_enemigo_que_toca` (0x5C84) comprueba los choques contra el jugador. Sólo
matan los enemigos de tipo 0 a 3 y el 7, tienen que estar en la misma pantalla,
y si alguno de los dos está en el estado 3 el otro también tiene que estarlo.
Cuando el choque cuenta, suena el efecto 0x1D y 0xE053 se pone a cero, que es
la señal de que el explorador ha muerto.

## Las trampas

Hay una sexta lista, de nueve bytes por entrada, en 0xE3FF, que
`mueve_la_trampa` (0x67F2) hace bajar por la columna. Su identidad exacta no se
ha podido confirmar; lo que sí está medido es que **mata**: la sonda de 0x68DA
devuelve cierto cuando encuentra los patrones 0x19 o 0x1A, y entonces sale por
la misma puerta que los enemigos —efecto 0x1D y 0xE053 a cero—.

## El marcador

`suma_al_marcador` (0x4412) lleva seis cifras en **BCD empaquetado** en
0xE049-0xE04B, con un `daa` después de cada suma. Al pasar el umbral de 0xE052
da una ronda extra y sube el umbral en 2, también en BCD, topándolo en 0xFF —a
partir de ahí no hay más vidas extra—. Después compara con el récord de
0xE043-0xE045 y lo actualiza si procede.

Todo esto sólo cuenta con el bit 6 de 0xE002 puesto, que es el que distingue
una partida de verdad de la demo.

## La demo

Cuando nadie toca nada, el cartucho juega solo. No es una inteligencia: es un
**guion grabado**. `arranca_partida` deja en 0xE080 el puntero a 0x4ACE, y
`guion_de_la_demo` (0x4621) lo va leyendo en parejas de (entrada, duración)
hasta el 0xFF que lo acaba. Los valores de entrada son exactamente los mismos
bits que dejaría el mando.

El ciclo completo del menú, medido en el emulador en una tanda anterior, es
tarea 0 (logo) → 1 (título) → 3 → 4 (nombre de sala) → 5 (sala en reposo) → 6
(la demo se mueve) → vuelta a la 4 → 7 (pausa) → 0 otra vez.
