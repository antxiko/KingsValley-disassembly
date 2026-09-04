# El juego

**King's Valley** es un juego de laberintos en pirámides: el explorador entra
en una cámara, recoge las gemas que hay repartidas por ella y sale por la
puerta que se abre cuando las ha cogido todas. Por el camino hay momias que lo
matan al tocarlo, suelo de ladrillo que se puede picar para abrir agujeros,
puertas giratorias, cuchillos que lanzar y muros trampa que caen del techo.

Todo lo que sigue está sacado del binario, no de jugar. Cuando algo no se ha
podido confirmar, se dice.

## Quince pirámides, en anillo

`tabla_de_habitaciones` (0x6D68) tiene diecinueve palabras: las **quince
primeras** son un puntero al descriptor de cada nivel, y las cuatro últimas la
base de cada uno de los cuatro tipos de patrón de pared.

Cada descriptor empieza con hasta cuatro bytes de **banda**. Una banda son
dieciséis columnas de pared, y su byte da el tipo (nibble alto) y el índice
dentro de ese tipo (nibble bajo). La lista termina **en** la banda cuyo nibble
alto vale 3 —y esa banda se dibuja también, que es el detalle que este proyecto
tenía mal—. Ver [Hallazgos](HALLAZGOS.html).

Bien contadas, las salas se reparten con mucho orden:

- las **impares** (1, 3, 5...) tienen **dos** bandas: 32 columnas, una pantalla.
- las **pares** (2, 4, 6...) tienen **cuatro**: 64 columnas, dos pantallas.

Las de dos pantallas son la razón de que la posición horizontal del explorador
necesite dos bytes enteros.

Detrás de las bandas el descriptor enumera, en este orden: las cuatro
**puertas de salida**, las **momias**, las **gemas**, los **cuchillos**, los
**picos**, las **puertas giratorias**, los **muros trampa** y las
**escaleras**. Cada descriptor acaba exactamente donde empieza el siguiente, y
por eso sabemos que la lectura es correcta hasta el último byte.

Cada puerta lleva escrito el número de la pirámide a la que da, y esos números
forman un **anillo cerrado**: de la 1 a la 2, a la 3... a la 15 y otra vez a la
1. La pantalla que sale entre pirámide y pirámide es el mapa del valle, con las
quince en un sendero serpenteante y la palabra GOAL al final.

| # | col. | gemas | momias | cuchillos | picos | giratorias | trampas | escaleras |
|---|---|---|---|---|---|---|---|---|
| 1 | 32 | 4 | 2 | 1 | 0 | 0 | 0 | 8 |
| 2 | 64 | 5 | 3 | 3 | 7 | 2 | 2 | 13 |
| 3 | 32 | 5 | 2 | 2 | 3 | 0 | 1 | 7 |
| 4 | 64 | 6 | 2 | 3 | 9 | 1 | 0 | 16 |
| 5 | 32 | 4 | 2 | 1 | 5 | 0 | 1 | 10 |
| 6 | 64 | 6 | 3 | 2 | 10 | 1 | 2 | 16 |
| 7 | 32 | 5 | 2 | 2 | 3 | 0 | 0 | 8 |
| 8 | 64 | 5 | 3 | 4 | 7 | 1 | 3 | 12 |
| 9 | 32 | 4 | 1 | 2 | 6 | 0 | 0 | 7 |
| 10 | 64 | 6 | 3 | 3 | 6 | 0 | 3 | 13 |
| 11 | 32 | 5 | 2 | 1 | 4 | 2 | 0 | 10 |
| 12 | 64 | 6 | 3 | 3 | 8 | 2 | 1 | 12 |
| 13 | 32 | 5 | 2 | 1 | 8 | 0 | 0 | 10 |
| 14 | 64 | 6 | 2 | 2 | 12 | 1 | 0 | 11 |
| 15 | 32 | 6 | 2 | 2 | 6 | 0 | 0 | 8 |
| **total** | | **78** | **34** | **32** | **94** | **10** | **13** | **161** |

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

El **nibble alto** del byte de una celda dice de qué clase es, y el bajo elige
una entrada dentro de esa clase. `traduce_celda_a_patron` (0x5D52) lo convierte
en un número de tile con la tabla de 0x5D68:

| nibble | qué es |
|---|---|
| `0x0x` | hueco: por donde se anda y por donde se cae |
| `0x1x` | suelo y pared, más los arranques de escalera sobre la plataforma |
| `0x2x` | **peldaños de escalera** — 0x20/0x21 hacia la derecha, 0x22/0x23 hacia la izquierda |
| `0x3x` | un **cuchillo** posado en el suelo (0x31 y 0x32 si cayó sobre un peldaño) |
| `0x4x` | una **gema** —0x43 a 0x48, una por color— y sus tres destellos |
| `0x5x` | una **puerta giratoria** |
| `0x6x`, `0x7x` | la **puerta de salida** y la **palanca** que la abre |
| `0x8x` | un **pico** |

Una versión anterior de esta página ponía `0x5x` como "el bloque que se puede
picar" y `0x2x`/`0x3x` como "las dos que aceptan el movimiento en diagonal", las
dos clasificadas por su uso porque nadie las había dibujado. Dibujadas, son una
puerta giratoria y una escalera: el movimiento en diagonal es subir.

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

## Picar, y los siete estados del explorador

La máquina de estados de 0xE134 tiene siete estados, y
`avanza_estado_del_jugador` (0x4C59) le da un paso por fotograma, apilando
`monta_sprite_del_jugador` como dirección de retorno para que el muñeco se
redibuje saliera por donde saliera:

| estado | qué está haciendo |
|---|---|
| 0 | andando |
| 1 | saltando |
| 2 | cayendo |
| 3 | en una escalera |
| 4 | **lanzando el cuchillo** |
| 5 | **picando con el pico** |
| 6 | **cruzando una puerta giratoria** |

Sólo los estados 0 y 3 aceptan entrada nueva; en los demás está a medias de
algo y el mando no cuenta.

Lo que hace el botón depende de **lo que lleve en las manos**, que es el nibble
alto de 0xE144: 0 nada, 1 el cuchillo, 2 el pico. Ese mismo nibble elige uno de
los tres juegos de sprites, y como los tres se cargan en la misma dirección de
VRAM, el explorador se dibuja con las manos vacías, con un cuchillo o con un
pico.

Picar abre un **agujero** en el suelo de ladrillo, y por él se cuelan el
explorador y las momias. Los agujeros son su propia lista, siete bytes por
entrada, en 0xE31E; `marca_el_agujero_que_se_abre` (0x69C9) busca el que está
justo donde está picando y le pone el bit 0 del campo 0, y a partir de ahí
`anima_bloques_que_se_abren` lo abre en seis pasos, uno cada ocho fotogramas.

Empujar contra una **puerta giratoria** dieciséis fotogramas seguidos lo pasa
al estado 6 con el efecto de sonido 0x03. El contador de esa racha está en
0xE146 y se reinicia en cuanto se rompe.

## La salida, y la palanca

Una puerta de salida es una estampa de tres filas por cinco columnas, escrita
en el buffer de sala con su esquina dieciséis píxeles a la izquierda y ocho
píxeles por encima de las coordenadas de la puerta. Tiene tres estados
—cerrada, cerrándose y abierta—, cada uno una tabla de quince bytes en 0x67C5,
0x67D4 y 0x67E3.

Hasta que no están todas las gemas sólo se ve la puerta por la que se ha
entrado, y se dibuja **abierta**. Cogidas todas, aparecen las salidas,
cerradas, con una **palanca** al lado; tocar la palanca abre el camino. Pasarse
una pirámide por primera vez vale además 2.000 puntos.

## Las momias

Los enemigos son la lista de **22 bytes por entrada** que empieza en 0xE16A,
con la cuenta en 0xE164. `mueve_los_enemigos` (0x6F5C) la recorre y despacha
cada una por su estado con `tabla_6f78`, que tiene nueve entradas.

Cada momia tiene un **tipo**, y hay cinco. El tipo es el tercer byte de su
descriptor **más el número de veces que se ha terminado el juego**, topado en 4
—o sea que el valle se endurece cada vuelta que se le da—. La tabla de 0x6D3C
da a cada tipo su velocidad en el nibble alto y su color en el bajo, y las dos
cosas están comprobadas contra la tabla de atributos de sprites de una máquina
en marcha:

| tipo | velocidad | color | cuántas lo usan |
|---|---|---|---|
| 0 | 5 | blanca | 10 |
| 1 | 5 | rojo claro | 4 |
| 2 | 10 | azul oscuro | 9 |
| 3 | 10 | rojo | 7 |
| 4 | 11 | amarillo oscuro | 4 |

Las momias buscan camino: `busca_camino` (0x734A) mira a los dos lados, baja
hasta cinco filas de la columna clasificando lo que encuentra y se queda con el
más corto.

`busca_enemigo_que_toca` (0x5C84) lleva los choques con el jugador. Sólo matan
las momias de tipo 0 a 3 y las de tipo 7, tienen que estar en la misma pantalla
y, si una de las dos está en el estado 3, la otra también. Cuando el golpe
cuenta suena el efecto 0x1D y 0xE053 se pone a cero, que es la señal de que el
explorador ha muerto.

## Los muros trampa

Hay una sexta lista, de nueve bytes por entrada, en 0xE3FF: los **muros
trampa**. Un bloque de ladrillos se suelta del techo y va bajando por una
columna cada 32 fotogramas, matando lo que pille por delante —la sonda de
0x68DA devuelve cierto con los patrones 0x19 y 0x1A, y de ahí se sale por la
misma puerta que las momias, efecto 0x1D y 0xE053 a cero—.

Vienen en el descriptor de nivel, dos bytes cada uno, y **no están en el mapa
hasta que se disparan**: trece repartidos por las quince pirámides. Esta página
decía que no se había podido confirmar qué era esa lista. Ya se puede: el
descriptor les da su propio bloque, y son los `MurosTrampa` del desensamblado
de Manuel Pazos.

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
(la demo se mueve) → vuelta a la 4 → 7 (pausa) → 0 otra vez. Una vuelta entera
dura 57,6 segundos de tiempo emulado, y la pirámide que juega es siempre la
**quinta**.
