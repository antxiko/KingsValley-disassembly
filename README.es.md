# King's Valley — desensamblado comentado

Desensamblado completo y comentado de **King's Valley** (Konami, 1985), el
cartucho **RC-727** de 16 KB para MSX1.

📖 **[Leer la web](https://antxiko.github.io/KingsValley-disassembly/es/)** ·
🇬🇧 [In English](README.md)

```
100,00 %  del binario explicado           0  bytes sin identificar
   9.803  bytes de código trazado       651  rutinas con nombre
   6.581  bytes de datos declarados    45,5 %  del listado comentado
```

Reensamblar el listado devuelve la ROM **byte a byte**:
`a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73`.

## La ROM no está aquí

Este repositorio no distribuye la imagen del cartucho. Pon tu copia en la raíz
como `kingsvalley.rom` y compruébala con:

```sh
shasum -a 256 kingsvalley.rom
```

## Compilarlo

```sh
make            # listado + verify + sanity + tests
make verify     # reensambla y compara con la ROM, byte a byte
make sanity     # las cuatro comprobaciones que el reensamblado no cubre
make densidad   # cuánto del listado está comentado
make web        # la web bilingüe en docs/
```

## Lo que apareció

- **La tabla de colores va debajo de la de patrones.** R3=0x7F y R4=0x07 no
  son direcciones en SCREEN 2 —son base más máscara— y lo que dicen es color
  en 0x0000 y patrones en 0x2000, al revés de lo habitual.
- **El explorador se mueve en veinticuatro bits**: un byte de fracción en
  1/256 de píxel más dos de píxel entero, porque las salas pares miden 48
  columnas y no caben en uno.
- **Ochenta y siete bytes de código que parecían datos**: cinco recorridos de
  entidades apilan su propio cierre para que el `ret` de la rutina despachada
  caiga en él. Ningún trazador estático puede seguir eso.
- **Dos rutinas que no llama nadie**, y una de ellas es la ayudante para
  *leer* de la VRAM —lo que cuenta que este cartucho nunca lee la VRAM—.
- **El parpadeo de los sprites está repartido a propósito**, girando cuál de
  cuatro entradas de un anillo se escribe primero en cada fotograma.
- **El color de la piedra cambia cada cuatro salas**, por ocho bytes que
  escribe una rutina que no tenía nada que ver con cargar la sala.
- **Sí lleva la marca oculta de Konami** (la halló
  [Manuel Pazos](https://twitter.com/ManuelPazosMSX)): `RC-727` y
  `OU KE NO TA NI` —王家の谷, el Valle de los Reyes—.

El detalle completo está en la web, en
[Hallazgos](https://antxiko.github.io/KingsValley-disassembly/es/HALLAZGOS.html).

## Todas las imágenes están dibujadas desde la ROM

Ni una captura de emulador. `tools/pantallas.py` ejecuta en Python los dos
intérpretes de guiones del propio cartucho sobre una VRAM de 16 KB en memoria
y luego la revela como SCREEN 2: la pantalla de título, las quince pirámides
con sus gráficos de ladrillo de verdad, la hoja de sprites y las pantallas de
menú.

## Cómo está organizado

```
src/kingsvalley.notes     lo entendido: nombres, comentarios, bloques de datos
src/kingsvalley.entries   puntos de entrada que el trazado no puede deducir
src/kingsvalley.nocode    zonas que el trazador no debe leer como código
src/kingsvalley.asm       GENERADO — nunca se edita a mano
tools/                    trazador, generador, comprobaciones, dibujo, openMSX
docs/                     la web bilingüe
```

## Licencia

Las herramientas, los comentarios y el análisis son MIT (ver
[LICENSE](LICENSE)). El juego no: ver [AVISO-LEGAL.md](AVISO-LEGAL.md). Esto es
trabajo de preservación, estudio y documentación.
