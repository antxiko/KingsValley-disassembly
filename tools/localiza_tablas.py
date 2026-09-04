#!/usr/bin/env python3
"""Ancla las etiquetas de datos de OTRO desensamblado a NUESTRAS direcciones.

Manuel Pazos publico en 2009 un desensamblado comentado de este cartucho
(https://github.com/GuillianSeed/Kings-Valley). Su fuente lleva los datos
escritos literalmente en directivas `db`, y eso permite no creerse nada: se
extraen esos bytes y se buscan en kingsvalley.rom. Si una secuencia aparece en
un unico sitio, la direccion de esa tabla en NUESTRA ROM queda demostrada byte
a byte, sin adoptar ninguna afirmacion suya.

Asi se anclaron las ~110 tablas de datos del cartucho -mapas de nivel, patrones
de pared, graficos, colores, musica- y con ellas los nombres que este proyecto
ha adoptado, cada uno comprobado despues contra el codigo que lo usa.

OJO CON LAS DOS VERSIONES: su fuente compila las dos compilaciones de la ROM
con la constante VERSION2. La nuestra es la PRIMERA (comprobado en 0x5817), asi
que aqui VERSION2 vale 0 y los bloques `IF (VERSION2)` se descartan.

Uso: localiza_tablas.py <kvalley.asm de Pazos> <kingsvalley.rom> [etiqueta ...]
"""
import re
import sys

VERSION2 = 0  # nuestra rom es la version 1 (comprobado: 0x5817)


def valor(tok):
    tok = tok.strip()
    if not tok:
        return None
    if tok.startswith('#'):
        return int(tok[1:], 16) & 0xFF
    if re.fullmatch(r'[0-9][0-9A-Fa-f]*[hH]', tok):
        return int(tok[:-1], 16) & 0xFF
    if re.fullmatch(r'-?\d+', tok):
        return int(tok) & 0xFF
    if re.fullmatch(r'[01]{8}b', tok):
        return int(tok[:-1], 2)
    return None  # una etiqueta u otra cosa: corta el bloque


def lee_bloques(ruta):
    """Devuelve [(etiqueta, [bytes])] con los db seguidos de cada etiqueta."""
    bloques = []
    actual = None
    pila = [True]
    for linea in open(ruta, encoding='latin-1'):
        limpia = linea.split(';')[0].rstrip()
        if not limpia.strip():
            continue
        m = re.match(r'\s*(IF|ELSE|ENDIF)\s*(.*)', limpia, re.I)
        if m:
            que = m.group(1).upper()
            if que == 'IF':
                cond = m.group(2).strip().strip('()')
                vale = VERSION2 if cond == 'VERSION2' else (not VERSION2)
                pila.append(bool(vale))
            elif que == 'ELSE':
                pila[-1] = not pila[-1]
            else:
                pila.pop()
            continue
        if not all(pila):
            continue
        m = re.match(r'([A-Za-z_][A-Za-z0-9_]*):\s*(.*)', limpia)
        if m:
            actual = m.group(1)
            bloques.append((actual, []))
            resto = m.group(2)
        else:
            resto = limpia.strip()
        if not bloques:
            continue
        m = re.match(r'db\s+(.*)', resto, re.I)
        if not m:
            if resto:  # cualquier otra cosa (una instruccion) cierra el bloque
                actual = None
            continue
        if actual is None:
            continue
        for tok in m.group(1).split(','):
            v = valor(tok)
            if v is None:
                actual = None
                break
            bloques[-1][1].append(v)
    return [(n, bytes(b)) for n, b in bloques if b]


def main():
    asm, rom_path = sys.argv[1], sys.argv[2]
    filtro = sys.argv[3:]
    rom = open(rom_path, 'rb').read()
    for nombre, datos in lee_bloques(asm):
        if filtro and nombre not in filtro:
            continue
        if len(datos) < 4:
            continue
        sitios = [0x4000 + m.start()
                  for m in re.finditer(re.escape(datos), rom)]
        estado = (' '.join('0x%04X' % s for s in sitios) if sitios
                  else 'NO APARECE')
        print('%-18s %4d bytes  %s' % (nombre, len(datos), estado))
    return 0


if __name__ == '__main__':
    sys.exit(main())
