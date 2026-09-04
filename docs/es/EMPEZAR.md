# Empezar

Este repositorio contiene el desensamblado comentado de **King's Valley**
(Konami, 1985), el cartucho **RC-727** de 16 KB para MSX1.

La ROM **no se distribuye aquí**. Hace falta ponerla en la raíz del repositorio
con el nombre `kingsvalley.rom`. Para comprobar que es la misma:

```
shasum -a 256 kingsvalley.rom
a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73
```

## Lo que hace `make`

```
make listado    genera src/kingsvalley.asm desde el trazado y las notas
make verify     reensambla el listado y compara con la ROM, byte a byte
make sanity     las cuatro comprobaciones que el reensamblado NO cubre
make densidad   cuenta cuánto del listado está comentado
make imagenes   dibuja los bloques gráficos declarados, para mirarlos
make web        genera la web bilingüe de docs/
```

`make` a secas hace `listado`, `verify`, `sanity` y `test`.

## Por qué `verify` es la prueba que importa

Un desensamblado se puede escribir de muchas maneras, y casi todas están mal de
alguna forma que no se nota. La única prueba que no admite discusión es
reensamblar el listado y comprobar que sale **exactamente la misma ROM**: los
16.384 bytes, en el mismo orden, con el mismo sha256.

Eso es lo que hace `make verify`, y se ha ejecutado después de cada tanda de
trabajo. Si alguna vez falla, el listado está mal, por bonito que se lea.

## Lo que NO cubre el reensamblado

Que los bytes salgan iguales no dice nada sobre si los hemos **entendido**. Un
bloque de datos leído como si fuera código produce el mismo binario y una
mentira en el listado. Por eso `make sanity` corre cuatro comprobaciones
aparte:

- **`check_trace.py`**: ninguna zona declarada como datos en el `.nocode` puede
  haber salido trazada como código.
- **`check_datos_como_codigo.py`**: cruza las 110 zonas de datos declaradas
  contra el trazado real.
- **`check_entradas.py`**: ningún punto de entrada puede caer dentro de una
  zona de datos.
- **`presupuesto.py`**: ni un byte del cartucho sin asignar. Este es el
  exigente, y hoy pasa: **0 bytes sin explicar**.

## Los ficheros que se editan a mano

Sólo tres, y los tres viven en `src/`:

- **`kingsvalley.entries`** — los puntos de entrada que el trazado estático no
  puede deducir solo: el `INIT` de la cabecera, el gancho de la interrupción,
  los once destinos de la tabla de tareas y los cierres de bucle que el
  cartucho apila con `push`. Cada uno con su justificación escrita al lado.
- **`kingsvalley.nocode`** — las zonas que el trazador no debe seguir leyendo
  como código, con la razón de cada una.
- **`kingsvalley.notes`** — las directivas `L` (nombre y descripción de una
  rutina), `C` (comentario de una línea) y `D`/`F` (un bloque de datos, su
  nombre y la anchura de su estructura). Es el fichero grande, y es donde vive
  todo lo que se ha entendido.

`src/kingsvalley.asm` **se genera**: no se edita nunca a mano.

## Las imágenes

Ninguna imagen de la web es una captura de emulador. Todas las dibuja
`tools/pantallas.py` desde los bytes de la ROM, ejecutando en Python los dos
intérpretes de guiones que corre el Z80. Ver [El código](EL-CODIGO.html) para
cómo funcionan.
