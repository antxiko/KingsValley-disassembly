# omsx_vram.tcl - Vuelca la VRAM de verdad del cartucho, para comprobar los PNG.
#
# Para que sirve: tools/pantallas.py y tools/sprites.py montan las imagenes de
# la web ejecutando en Python los pasos del cartucho (el interprete de guiones
# 0x445F, el de listas de tiles 0x43EA, la replica de VRAM 0x442D y el
# descompresor de figuras 0x5932). Mirar el dibujo no basta: hay que comparar
# sus bytes con los que el VDP tiene de verdad. Esto deja correr el juego y en
# varios instantes vuelca los 16 KB de VRAM, los ocho registros del VDP y las
# variables que dicen QUE se estaba dibujando.
#
# No pone NINGUN punto de ruptura: los volcados van por reloj emulado, que es
# lo unico que no ahoga al emulador.
#
# Variables de entorno:
#   KV_SALIDA  carpeta de salida (por defecto work/omsx)
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine Philips_VG_8020 \
#       -cart kingsvalley.rom -script tools/omsx_vram.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx}]
file mkdir $::SALIDA
set ::n 0

proc vuelca {etiqueta} {
    set i [format %02d $::n]
    incr ::n
    # los 16 KB de VRAM tal cual los ve el VDP
    set datos [debug read_block VRAM 0 16384]
    set f [open $::SALIDA/vram_$i.bin w]
    fconfigure $f -translation binary
    puts -nonewline $f $datos
    close $f
    # los ocho registros, que dicen donde esta cada tabla
    set r {}
    for {set k 0} {$k < 8} {incr k} {
        lappend r [format %02X [debug read {VDP regs} $k]]
    }
    set f [open $::SALIDA/info_$i.txt w]
    puts $f [format {etiqueta %s} $etiqueta]
    puts $f [format {tiempo %s} [machine_info time]]
    puts $f [format {regs %s} [join $r { }]]
    # Las variables de trabajo empiezan en 0xE000. Los nombres de aqui son los
    # que el listado ya tiene confirmados, NO los de la plantilla: este fichero
    # venia copiado de Konami's Tennis con etiquetas suyas -jugador1..jugador4
    # en 0xE100/0xE130/0xE160/0xE190- que aqui eran falsas. 0xE130, en
    # concreto, no es ningun jugador: es el contador de fotogramas de la
    # pantalla en reposo (0x77b7 lo sube una vez por fotograma y lo compara
    # contra 0x58 y 0xE0).
    foreach {nombre dir} {tarea_activa 0xE000 orden 0xE001 modo_especial 0xE002
                          fotogramas 0xE003 contador_tarea 0xE004
                          entrada 0xE009 fin_de_demo 0xE00D
                          reposo 0xE130 estado_jugador 0xE134
                          mira_hacia 0xE136 jugador_y 0xE137
                          jugador_x_baja 0xE139 jugador_x_alta 0xE13A
                          sala 0xE054 enemigos 0xE164} {
        puts $f [format {%s %d} $nombre [debug read memory $dir]]
    }
    close $f
    catch { screenshot -raw $::SALIDA/pant_$i.png }
}

# --- la barra de espacio, para elegir en el menu ---------------------------
proc pulsa {} {
    keymatrixdown 8 0x01
    after time 0.3 suelta
}
proc suelta {} {
    keymatrixup 8 0x01
}

# --- calendario -------------------------------------------------------------
# La portada sale al arrancar y despues el menu; si nadie toca nada el juego
# entra solo en la demostracion, asi que la pista aparece sin jugar.
# Los volcados van cuando la pantalla YA esta montada: antes de los 9 s el
# cartucho esta a medio pintar el titulo y la VRAM no es comparable con nada.
after time  9.0 { vuelca menu }
after time 11.0 { vuelca menu }
after time 13.0 { vuelca menu }
after time 15.0 { vuelca menu }
after time 20.0 { vuelca pista }
after time 26.0 { vuelca pista }
after time 32.0 { vuelca pista }
after time 38.0 { vuelca pista }
after time 44.0 { vuelca pista }
after time 50.0 { vuelca pista }
after time 56.0 { vuelca pista }
after time 60.0 { vuelca pista }
after time 62.0 { exit }

# perro guardian de tiempo REAL: un guion roto no puede colgar el emulador
after realtime 240 {
    puts {PERRO GUARDIAN a los 240 s reales}
    exit
}
