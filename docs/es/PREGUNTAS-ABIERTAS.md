# Preguntas abiertas

El binario está explicado al 100 % y todas las rutinas tienen nombre. Eso no
quiere decir que todo esté entendido. Lo que sigue es lo que queda flojo, dicho
sin adornos.

## Cuál de las dos compilaciones jugó la gente

Este cartucho es la **versión 1**, y la versión 2 le arregla cuatro fallos.
Cuál de las dos se vendió dónde, y en qué orden, no es algo que el binario
pueda contestar —y la norma de esta serie es no deducir una historia editorial
de un binario—. Un volcado de la versión 2 al lado de éste permitiría
compararlas instrucción a instrucción, como se hizo con otro cartucho de esta
serie que también tiene dos compilaciones.

## Para qué eran las cuatro entradas muertas de la tabla de tiles

La tabla de 0x5D68 tiene, en esta versión, cuatro punteros para las clases de
celda `0x9x`, `0xAx`, `0xBx` y `0xCx` que ningún descriptor de nivel llega a
producir. Apuntan a los patrones 0x4E, 0x4F y 0x50 y a dos bytes a cero. La
versión 2 los quita del todo.

Algo usó esas clases en algún momento del desarrollo. Qué, no lo sabemos.

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

## El sonido

Las tablas de música y efectos están localizadas y con nombre —`SFX_Momia`,
`MUS_Ingame`, `MUS_GameOver` y una docena más— pero el formato del propio
reproductor no se ha desmontado, y nada se ha comparado contra los registros
del PSG de una máquina en marcha.

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
