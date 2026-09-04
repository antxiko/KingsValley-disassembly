# Comprueba si la ruta condicional de avanza_un_cuadro (0xe002 bit 6 a
# cero -> llamada fabricada a 0x4644 -> L_403E, el parche automodificante)
# llega a darse jugando de verdad. Mismo patron que omsx_quien_lee.tcl:
# breakpoints armados DESPUES de INIT (0x406c), entrada a ciegas por menu +
# partida forzada, ventana de tiempo emulado + perro guardian real.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_check_4644.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 120]}]

set LOG [open "$::SALIDA/check_4644.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }

say "arrancando: vigilando 0x4644, 0x403e y 0x40e4 (tarea 1)"

set ::n4644 0
set ::n403e 0
set ::n40e4 0
set ::armado 0

debug set_bp 0x406c {} {
    if {!$::armado} {
        set ::armado 1
        debug set_bp 0x4644 {} {
            incr ::n4644
            say [format "0x4644 alcanzado (%d): e002=0x%02X e000=0x%02X" $::n4644 [debug read memory 0xe002] [debug read memory 0xe000]]
        }
        debug set_bp 0x403e {} {
            incr ::n403e
            say [format "0x403e (L_403E, el parche) alcanzado (%d)" $::n403e]
        }
        debug set_bp 0x40e4 {} {
            incr ::n40e4
            say [format "0x40e4 (tarea 1) alcanzado (%d): primer byte ahora = 0x%02X" $::n40e4 [debug read memory 0x40e4]]
        }
        say "INIT (0x406C) alcanzado: breakpoints armados"
    }
}

# --- conducir a ciegas: menu, demo, y una partida forzada -------------------
proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
set ::DIRS {0x10 0x20 0x40 0x80}
expr {srand(23)}
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
    say [format "RESUMEN: 0x4644=%d veces, 0x403e=%d veces, 0x40e4(tarea1)=%d veces" $::n4644 $::n403e $::n40e4]
    say "FIN"
    exit 0
}
after time $::SEG informe

after realtime 180 {
    say "PERRO GUARDIAN a los 180 s reales"
    exit 1
}
