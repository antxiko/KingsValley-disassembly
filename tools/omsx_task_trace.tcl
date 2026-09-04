# Traza los cambios de TAREA ACTIVA (byte bajo de 0xe000, indexa
# tabla_de_tareas, 11 entradas) durante el arranque + menu + demo + una
# partida forzada. Cada vez que 0xe000 cambia de valor, apunta el tiempo
# emulado, el contador de fotogramas (0xe003) y una captura de pantalla -asi
# se puede VER que tarea corresponde a que fase (logo/menu/demo/juego) sin
# tener que descifrar cada rutina a mano.
#
# Mismo patron que omsx_check_4644.tcl: breakpoint en INIT (0x406c) para
# armar el watchpoint DESPUES de que la pagina 1 sea de verdad el cartucho,
# entrada a ciegas, perro guardian real.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_task_trace.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx/tareas}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 90]}]

set LOG [open "$::SALIDA/tareas.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }

say "arrancando: vigilando escrituras a 0xe000 (indice de tarea activa)"

set ::n 0
set ::anterior -1
set ::armado 0

proc registra {} {
    set actual [debug read memory 0xe000]
    if {$actual != $::anterior} {
        set i [format %02d $::n]
        incr ::n
        set fot [debug read memory 0xe003]
        say [format "tarea %d -> %d  (fotogramas=%d, %d-esimo cambio, PC=0x%04X)" $::anterior $actual $fot $::n [reg PC]]
        catch { screenshot -raw "$::SALIDA/tarea_${i}_de_${::anterior}_a_${actual}.png" }
        set ::anterior $actual
    }
}

debug set_bp 0x406c {} {
    if {!$::armado} {
        set ::armado 1
        debug set_watchpoint write_mem 0xe000 {} { registra }
        say "INIT (0x406C) alcanzado: watchpoint armado"
        registra
    }
}

# --- conducir a ciegas: menu, demo, y una partida forzada -------------------
proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
set ::DIRS {0x10 0x20 0x40 0x80}
expr {srand(7)}
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
    say [format "RESUMEN: %d cambios de tarea en %s s emulados" $::n $::SEG]
    say "FIN"
    exit 0
}
after time $::SEG informe

after realtime 180 {
    say "PERRO GUARDIAN a los 180 s reales"
    exit 1
}
