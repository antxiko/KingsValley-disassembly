# El código

Las 651 rutinas del listado tienen nombre y descripción, y el **45,5 %** de las
instrucciones lleva comentario propio. Esta página recorre las piezas que hay
que entender para leer el resto.

## El despachador de tareas

El juego es una máquina de estados con once tareas. `avanza_un_cuadro` (0x40A3)
sube el contador de fotogramas y `despacha_tarea_activa` (0x40B6) salta a la
tarea que dice el byte bajo de 0xE000.

El despacho usa un truco que aparece **siete veces** en el cartucho:

```asm
    call L_404B
    defw destino0, destino1, destino2, ...
```

`L_404B` (0x404B) hace `add a,a`, recupera con `pop hl` la dirección de retorno
—que es justo la tabla que sigue al `call`— y lee de ahí la palabra que toca.
Luego `jp (hl)`. La tabla nunca se ejecuta: se **lee** desde la pila.

Las siete tablas están declaradas en el `.nocode`, porque si no el trazador las
lee como código y sale un listado que reensambla igual pero miente.

## El registro de posición

La pieza que abre todo el resto del juego no es una rutina de jugador: es
`lee_celda_de_sala` (0x50BC), leída al revés. Recibe en HL un **puntero a un
registro de posición** y usa:

- `(HL+0)` más un ajuste, desplazado tres bits: la **fila**.
- `(HL+2)` y `(HL+3)` como una cantidad de **16 bits**, más un desplazamiento
  con signo, desplazada tres bits: la **columna**.

De ahí sale el formato del registro del explorador, que empieza en 0xE137, y
tres bytes por debajo está el estado —lo confirma `sondea_una_celda` (0x5092),
que con HL en 0xE137 hace `dec hl` tres veces y lee el resultado como estado
para compararlo con 2—.

Ese mismo formato lo usan las entidades, los enemigos y el scratch de
posiciones candidatas de 0xE149. Por eso las rutinas de sonda sirven para
todos.

## La aritmética de 24 bits

`avanza_posicion_24_bits` (0x73F6) es el motor de todo movimiento. Entra con HL
apuntando a un par de 16 bits y DE con la velocidad, y hace:

```asm
    add hl,de       ; los dos bytes bajos
    ld a,b
    adc a,c         ; y el tercero, con el acarreo
```

Son **veinticuatro bits**: fracción, píxel bajo, píxel alto. Para el explorador
esos tres bytes son 0xE138, 0xE139 y 0xE13A.

El bit 0 de `(IX-2)` —que para el explorador es 0xE136, el byte de dirección—
decide si la velocidad se **niega** antes de sumarla, con un complemento a dos
de DE y un complemento de C. Por eso el mismo código sirve para ir a los dos
lados, y por eso ese bit es "hacia qué lado mira".

## Las seis listas de entidades

Seis tablas paralelas, cada una con su rutina de acceso. El tamaño de cada
entrada no hay que suponerlo: está en la **multiplicación**.

| rutina | cadena | paso | base | índice | tope |
|---|---|---|---|---|---|
| 0x6A12 | i, 3i, 7i | **7** | 0xE1C5 | 0xE1F4 | — |
| 0x65A5 | 2i, 4i, 8i, +i | **9** | 0xE1F5 | 0xE1F4 | 0xE1F3 |
| 0x5AF6 | 2i, 4i, 8i, 16i, +i | **17** | 0xE264 | 0xE262 | 0xE263 |
| 0x73D3 | 2i, 6i, 22i | **22** | 0xE16A | 0xE165 | 0xE164 |
| 0x68C2 | 2i, 4i, 8i, +i | **9** | 0xE3FF | 0xE3FD | 0xE3FE |
| 0x6A09 | i, 3i, 7i | **7** | 0xE31E | 0xE31C | 0xE31D |

Las dos primeras **comparan el mismo índice** (0xE1F4): son dos bloques de
campos de la misma entidad, partidos en dos zonas de memoria.

Las cadenas están además encajadas: `campo_de_entidad_17` prepara 2i y entra a
media cadena en `indexa_paso_17`, que sigue hasta 16i; `campo_de_entidad_9`
entra un paso antes, en `indexa_paso_9`, y los tres últimos `add` los comparten
las dos. Ahorra bytes a cambio de que haya que leer la cadena entera para saber
el paso.

## Los cierres de bucle apilados

Cinco recorridos de entidades hacen esto antes de despachar:

```asm
    ld hl,<cierre>
    push hl
    ...
    jp (hl)         ; a la rutina que toque
```

El `ret` de la rutina despachada **no vuelve al llamador**: cae en el cierre,
que sube el índice y salta otra vez al cuerpo del bucle. Los cinco cierres
tienen la misma forma:

```asm
    ld hl,<índice>
    inc (hl)
    ld a,(hl)
    inc hl
    cp (hl)
    jp nz,<cuerpo>
    ret
```

Son 87 bytes de código que un trazador estático no puede alcanzar, porque la
dirección viaja por la pila como si fuera un dato. Están declarados en el
`.entries` con su justificación.

## El dibujo: dos intérpretes

`dibuja_guion` (0x451A) lee comandos de un byte:

```
C = B0 & 0x7F
  C != 0 y bit 7 puesto  -> copia C bytes crudos del guion a la VRAM
  C != 0 y bit 7 a cero  -> lee UN byte y lo repite C veces
  B0 == 0x00             -> fin
  B0 == 0x80             -> lee una palabra con otra dirección VRAM y sigue
```

La distinción entre `0x00` y `0x80` está resuelta de una manera bonita: se lee
el byte dos veces, una enmascarada con `0x7F` y otra cruda, y se comparan. Si
son iguales, el bit 7 estaba a cero.

El VDP autoincrementa después de cada escritura, así que un guion pinta un
tramo continuo. `dibuja_guion_x3_tercios` (0x44F1) repite el mismo guion tres
veces a 0x800 de distancia: los tres tercios de SCREEN 2.

`escribe_guion_de_texto` (0x4051) es otro lenguaje distinto: palabra con la
dirección, caracteres, `0xFE` para saltar y `0xFF` para acabar. Los caracteres
van en **ASCII menos 0x20**.

## El motor de sonido

El reproductor PSG vive en 0x7A9E-0x7CE2, cuarenta rutinas. Cada canal es una
estructura de **catorce bytes**, y hay tres, en 0xE010, 0xE01E y 0xE02C.

El registro 7 del PSG —el mezclador— se usa para conmutar el canal C entre tono
y ruido nota a nota: `conmuta_ruido_canal_c` alterna 0x9C (tonos A y B con
ruido en C) y 0xB8 (los tres tonos sin ruido). Es la percusión.

El byte de nota tiene dos mitades, y el nibble alto **no es la octava**: es el
índice dentro de `tabla_periodos_nota`, de 0 a 9. La octava sale de un campo
aparte de la estructura de canal, fijado por un comando de control previo.

## El marcador, en BCD

`suma_al_marcador` (0x4412) lleva seis cifras en BCD empaquetado. No hay que
deducirlo: los `daa` están después de cada `add` y de cada `adc`.

Lo mismo con `divide_entre_diez` (0x439A), que convierte un binario pequeño en
dos cifras restando de diez en diez y contando en el nibble alto.

## Lo que el cartucho nunca hace

Dos bloques de código no los llama nadie: 0x4501 y 0x4542. El segundo es la
pareja de `prepara_escritura_vdp` **para leer** de la VRAM —llama a SETRD y coge
el puerto de lectura de la variable de sistema 0x0007, igual que la otra coge
el de escritura de 0x0006—.

Que esté ahí y no se use dice algo del diseño: **este cartucho nunca lee de la
VRAM**. Escribe y se olvida. Todo el estado del juego vive en la RAM, incluido
un buffer completo de la sala en 0xE700.
