# Vuelca el mapa de sala que deja en RAM 0xE700+ la rutina L_6A90, para
# comprobar el algoritmo de desempaquetado calculado a mano (leyendo los
# opcodes 0x6acf-0x6ae1 y el bucle 0x6ae7-0x6b08) contra lo que hace de
# verdad el Z80 al cargar una sala real durante una partida.
#
# Breakpoint en 0x6b09 (justo despues del `exx` final del bucle de
# desempaquetado de UNA banda, antes de `ld bc,00010h / add ix,bc` que pasa
# a la siguiente banda): en ese instante las 22 filas x 16 bytes de la banda
# actual ya estan escritas en 0xE700+ y (0xE054) -el nivel actual- tambien.
# (Descartado 0x6d3b: es el `ret` de OTRA rutina que cae a continuacion en
# el listado, no el cierre real de L_6A90 -confirmado porque volcar ahi daba
# 0xFF, RAM sin tocar, en las filas 1-21).
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_dump_sala.tcl
#
# Variables de entorno opcionales: KV_SALIDA (carpeta), KV_SEG (duracion
# emulada en segundos, por defecto 90), KV_MAX (num. de salas a capturar,
# por defecto 6).

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 90]}]
set ::MAX [expr {[opcion KV_MAX 6]}]

set LOG [open "$::SALIDA/dump_sala.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

say [format "arrancando: breakpoint 0x6b09, hasta %d salas, ventana %s s" $::MAX $::SEG]

set ::n 0

debug set_bp 0x6b09 {} {
    if {$::n >= $::MAX} { return }
    set nivel [debug read memory 0xe054]
    set f [open [format "$::SALIDA/sala_%02d_nivel_%02d.txt" $::n $nivel] w]
    puts $f [format "nivel=%d" $nivel]
    # 0x900 bytes cubren de sobra las 4 bandas x 22 filas x stride real
    for {set i 0} {$i < 0x900} {incr i} {
        set b [debug read memory [expr {0xe700 + $i}]]
        puts $f [format "%02X" $b]
    }
    close $f
    say [format "sala %d capturada: nivel=%d" $::n $nivel]
    incr ::n
}

proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
set ::DIRS {0x10 0x20 0x40 0x80}
expr {srand(7)}
proc paso {} {
    set r [expr {rand()}]
    if {$r < 0.6} {
        set m [lindex $::DIRS [expr {int(rand()*4)}]]
        pulsa 8 $m [expr {0.15 + rand()*0.5}]
    } elseif {$r < 0.9} {
        pulsa 8 0x01 0.2
    }
    after time 0.4 paso
}
after time 1.5 { pulsa 8 0x01 0.3 }
after time 3.0 { paso }

proc informe {} {
    say [format "FIN: %d salas capturadas" $::n]
    exit 0
}
after time $::SEG informe

after realtime 180 {
    say "PERRO GUARDIAN a los 180 s reales"
    exit 1
}
