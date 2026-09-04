# QUIEN LEE DE VERDAD el bloque 0x5DCA-0x650D (1.860 B) de King's Valley.
#
# Dos tandas de busqueda estatica (grep de `ld hl/de/bc,XXXXh` literal, y de
# `pop de`/`ld de,(...)` antes de cada llamada al interprete de guiones) no
# encontraron NINGUN lector. Esto es la comprobacion dinamica: un watchpoint
# de LECTURA sobre el rango exacto, con el cartucho corriendo de verdad
# (menu, demo, y una partida forzada a base de pulsaciones). Si algun opcode
# lee un solo byte ahi dentro, se apunta el PC. Cero lecturas tras una
# ventana larga tambien es una respuesta: el bloque no se toca en ese tramo.
#
# Se arma DESPUES de que la maquina llega a INIT (0x406C): antes de eso, la
# pagina 1 puede no ser todavia el cartucho (la BIOS escanea ranuras), y un
# watchpoint puesto antes contaria ruido que no es del juego (mismo patron
# que ATHLETIC_DISAM/tools/omsx_quien_lee.tcl, pagado el 2026-08-17).
#
# Ademas cuenta, por contexto, quien escribe en el puerto 0x98 (VRAM) durante
# la misma ventana: si el bloque fuera un generador de patrones, su lector
# deberia terminar escribiendo ahi.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_quien_lee.tcl
#
# Variables de entorno opcionales: KV_SALIDA (carpeta), KV_SEG (duracion
# emulada en segundos, por defecto 120), KV_A/KV_B (rango, por defecto el
# bloque sin identificar).

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 120]}]
set ::A [expr {[opcion KV_A 0x5DCA]}]
set ::B [expr {[opcion KV_B 0x650D]}]

set LOG [open "$::SALIDA/quien_lee.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

say [format "arrancando: rango 0x%04X-0x%04X, ventana %s s emulados" $::A $::B $::SEG]

set ::lee [dict create]
set ::n_lee 0
set ::vram [dict create]
set ::n_vram 0
set ::armado 0

debug set_bp 0x406c {} {
    if {!$::armado} {
        set ::armado 1
        debug set_watchpoint read_mem [list $::A [expr {$::B}]] {} {
            dict incr ::lee [reg PC]
            incr ::n_lee
        }
        debug set_watchpoint write_io 0x98 {} {
            dict incr ::vram [reg PC]
            incr ::n_vram
        }
        say "INIT (0x406C) alcanzado: watchpoints armados"
    }
}

# --- conducir a ciegas: menu, demo, y una partida forzada -------------------
proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
set ::DIRS {0x10 0x20 0x40 0x80}
expr {srand(11)}
proc paso {} {
    set r [expr {rand()}]
    if {$r < 0.55} {
        set m [lindex $::DIRS [expr {int(rand()*4)}]]
        pulsa 8 $m [expr {0.15 + rand()*0.5}]
    } elseif {$r < 0.85} {
        pulsa 8 0x01 0.2
    }
    after time 0.5 paso
}
after time 1.5 { pulsa 8 0x01 0.3 }
after time 3.0 { paso }

proc informe {} {
    say [format "lecturas en 0x%04X-0x%04X: %d, %d PC distintos" $::A $::B $::n_lee [dict size $::lee]]
    set l {}
    dict for {pc v} $::lee { lappend l [list $v $pc] }
    set l [lsort -integer -index 0 -decreasing $l]
    foreach e $l { say [format "  LEE  PC=0x%04X  %d veces" [lindex $e 1] [lindex $e 0]] }

    say [format "escrituras a puerto 0x98 (VRAM): %d, %d PC distintos" $::n_vram [dict size $::vram]]
    set l2 {}
    dict for {pc v} $::vram { lappend l2 [list $v $pc] }
    set l2 [lsort -integer -index 0 -decreasing $l2]
    foreach e [lrange $l2 0 24] { say [format "  VRAM PC=0x%04X  %d veces" [lindex $e 1] [lindex $e 0]] }

    set f [open "$::SALIDA/quien_lee.txt" w]
    dict for {pc v} $::lee { puts $f [format "%04X %d" $pc $v] }
    close $f
    set f2 [open "$::SALIDA/vram_pcs.txt" w]
    dict for {pc v} $::vram { puts $f2 [format "%04X %d" $pc $v] }
    close $f2
    say "FIN"
    exit 0
}
after time $::SEG informe

# perro guardian de tiempo REAL: un guion roto no puede colgar el emulador
after realtime 180 {
    say "PERRO GUARDIAN a los 180 s reales"
    exit 1
}
