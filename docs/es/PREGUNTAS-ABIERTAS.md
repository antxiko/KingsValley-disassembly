# Preguntas abiertas

El binario está explicado al 100 % y todas las rutinas tienen nombre. Eso no
quiere decir que todo esté entendido. Lo que sigue es lo que queda flojo, dicho
sin adornos.

## Los sprites de los enemigos

La hoja de sprites de la web sale de los **seis guiones** del cartucho cuyo
primer word cae en 0x1800-0x1FFF, que es donde R6 pone la tabla de patrones de
sprites. Entre los seis dejan el explorador en sus posturas, la joya y las
herramientas.

Pero la hoja tiene **filas vacías en el medio**, y las momias tienen que estar
en alguna parte. Falta localizar el guion —o los guiones— que las carga. Puede
que se carguen por sala, o desde una rutina que todavía no se ha cruzado con
esa dirección.

## Qué es exactamente la lista de 0xE3FF

`mueve_la_trampa` (0x67F2) recorre una lista de nueve bytes por entrada y hace
bajar sus elementos por la columna del buffer de sala. Lo que **sí** está
medido es que puede matar: la sonda de 0x68DA devuelve cierto con los patrones
0x19 y 0x1A, y de ahí sale por la misma puerta que los enemigos.

Lo que no está cerrado es **qué es**. Podría ser una roca que cae, un dardo, o
algo que no se nos ocurre. Los patrones 0x19 y 0x1A dibujados aparte lo
resolverían.

## Los tipos de celda 0x2x y 0x3x

Están clasificados por **cómo se usan**: son las dos únicas clases que
`mueve_al_jugador` acepta para el paso en diagonal, y `sube_un_escalon` exige
además los subtipos 0x16 y 0x17. La tabla de perfil de 0x5168
(0, −1, −2, −3, −4, −3, −2, −1) dibuja una V en la Y según la X dentro de la
celda.

Pero **qué dibujo tienen** esas celdas —si son escalones, una rampa, una
escalera— no se ha confirmado dibujándolas. La clasificación por uso es sólida;
el nombre no.

## Cuánto dura cada etapa de la tarea 0

La cascada de la tarea 0 tiene tres niveles de contador anidados y se lee bien
en los opcodes, pero **no se ha medido cuántos fotogramas dura cada etapa**: el
guion de prueba del emulador pulsa teclas desde el segundo 1,5, y
`revisa_teclado_y_salta_menu` se adelanta siempre a la espera natural.

Para medirlo haría falta un guion que no toque nada durante el minuto largo que
tarda el ciclo en cerrarse solo.

## Las variables de partida de `arranca_partida`

`arranca_partida` (0x4115) deja inicializadas varias variables cuyo papel exacto
no se ha cerrado: 0xE062, 0xE058, 0xE055, 0xE080 y 0xE082. De 0xE080 y 0xE082
sí se sabe que son el puntero y el contador del guion de la demo. De las otras
tres se sabe dónde se leen, pero no qué representan.

## 0xE130, deducido pero no medido

Que 0xE130 sea el **contador de fotogramas de la pantalla en reposo** está
deducido de cómo se usa: `pantalla_en_reposo` (0x77B7) lo incrementa una vez
por fotograma y lo compara contra 0x58 y 0xE0, y al segundo plazo escribe 0xE1
en 0xE00D, que es justo lo que corta la demo. Lo confirma que 0x6718 lo pone a
cero al entrar en esa pantalla.

Es consistente por tres caminos, pero **no se ha puesto un watchpoint**. Se
señala porque la tanda anterior tenía apuntada ahí la etiqueta «jugador2»,
heredada sin verificar de la plantilla de Konami's Tennis, y esa etiqueta era
falsa. Conviene no cambiar una etiqueta sin comprobar por otra.

## Las pantallas dibujadas, sin comparar contra la VRAM

Ninguna de las pantallas nuevas —título, salas con gráficos, pantalla final— se
ha comparado byte a byte contra un volcado de VRAM del emulador. Salen
reconocibles, y el logotipo de Konami sale nítido, lo que ya descarta que la
lectura de R3/R4 esté al revés. Pero eso es mirar, no medir, y la norma de la
serie es medir.

## El primer guion de 0x47FE

El tramo 0x47FE-0x480D es un guion de gráficos que escribe una barra decorativa
y la palabra SOFTWARE. Sus **cinco primeros bytes** (0x0C, 0x7A, 0x16, 0x00,
0x88) no son letras: son índices de tile de algún adorno. No se ha mirado qué
dibujan.

## Y la de siempre

Nadie ha jugado una partida entera con el listado delante, comprobando sobre la
marcha que cada cosa hace lo que dice el comentario. Los desensamblados
anteriores de esta serie han enseñado que eso destapa errores que ni leer ni
medir cazan.
