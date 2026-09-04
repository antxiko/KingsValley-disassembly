# Vuelca el buffer de mapa COMPLETO de cada piramide -no solo la pared: con
# las escaleras, las gemas y sus destellos, los picos, los cuchillos y las
# puertas giratorias ya puestos- para comprobar contra el emulador lo que
# calcula tools/mapas.py.
#
# omsx_dump_sala.tcl para en 0x6b09, en mitad del desempaquetado de UNA banda:
# eso solo demuestra la pared. Aqui se para DESPUES de todo:
#
#   0x6a90  entrada de carga_la_sala. Ahi se FUERZA el nivel (0xE054) al que
#           toque capturar, porque el guion de la demo solo juega el primero.
#   0x4176  la llamada a despacha_estado_de_la_sala, el primer sitio en el
#           que carga_la_sala y reparte_entidades_de_la_sala ya han acabado
#           y todavia NO ha pintado nadie la puerta de entrada (eso lo hace
#           AI_Salidas, dentro de esa misma llamada) ni los cuchillos (los
#           pone el estado 0 de su propia maquina, un fotograma despues).
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_dump_mapa.tcl
#
# Variables de entorno: KV_SALIDA (carpeta), KV_SEG (segundos emulados).

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx_mapa}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 240]}]

set LOG [open "$::SALIDA/dump_mapa.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

# Los niveles que quedan por capturar, en orden
set ::PENDIENTES {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15}
set ::FORZADO 0

say "arrancando: fuerza (0xE054) en 0x6a90 y vuelca en 0x4176"

debug set_bp 0x6a90 {} {
    if {[llength $::PENDIENTES] == 0} { return }
    set ::FORZADO [lindex $::PENDIENTES 0]
    # OJO: 0x6aa1-0x6aa6 copia 0xE055 (la piramide de DESTINO) sobre 0xE054
    # (la actual) nada mas empezar, asi que hay que forzar las dos. La demo,
    # por su cuenta, juega siempre la piramide 5.
    debug write memory 0xe055 $::FORZADO
    debug write memory 0xe054 $::FORZADO
    say "forzando nivel $::FORZADO"
}

debug set_bp 0x4176 {} {
    if {$::FORZADO == 0} { return }
    set nivel [debug read memory 0xe054]
    if {$nivel != $::FORZADO} { return }
    set f [open [format "$::SALIDA/mapa_%02d.txt" $nivel] w]
    puts $f [format "nivel=%d" $nivel]
    # 23 filas x 96 = 0x8A0 bytes: el buffer entero desde 0xE700
    for {set i 0} {$i < 0x8A0} {incr i} {
        puts $f [format "%02X" [debug read memory [expr {0xe700 + $i}]]]
    }
    close $f
    say "nivel $nivel volcado"
    set ::PENDIENTES [lrange $::PENDIENTES 1 end]
    set ::FORZADO 0
    if {[llength $::PENDIENTES] == 0} {
        say "FIN: todos los niveles volcados"
        exit 0
    }
    # Reiniciar es mas rapido y mas seguro que esperar otra vuelta del ciclo
    # de tareas: con el nivel forzado el guion de la demo deja de encajar con
    # el mapa y la maquina se queda en cualquier sitio.
    after time 0.1 { reset ; arranca }
}

# La demo se mueve sola; solo hace falta arrancarla.
proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
proc arranca {} { after time 1.5 { pulsa 8 0x01 0.3 } }
arranca

proc informe {} {
    say [format "FIN por tiempo: quedaban %s" $::PENDIENTES]
    exit [expr {[llength $::PENDIENTES] == 0 ? 0 : 1}]
}
after time $::SEG informe

after realtime 300 {
    say "PERRO GUARDIAN a los 300 s reales"
    exit 1
}
