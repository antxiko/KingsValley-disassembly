# Vuelca los 16 KB de VRAM de VERDAD con una piramide ya montada en pantalla,
# una por nivel, para comparar contra lo que dibuja tools/mapas.py.
#
# Mirar el PNG no vale: hay que comparar bytes. Con esto se comprueban de una
# vez las tres tablas que forman la imagen -nombres, patrones y color- y de
# paso la tabla de atributos de sprites, que es de donde salen los COLORES de
# las momias y del explorador.
#
#   0x6a90  entrada de carga_la_sala: se fuerza ahi el nivel (0xE054 y 0xE055,
#           porque 0x6aa1-0x6aa6 copia la segunda sobre la primera).
#   0x4185  ya han corrido monta_sprite_del_jugador, actualiza_tabla_de_sprites
#           y coloca_al_jugador_en_la_sala: la sala esta volcada a la tabla de
#           nombres y los sprites puestos.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_vram_sala.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx_vram}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 900]}]

set LOG [open "$::SALIDA/vram_sala.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

set ::PENDIENTES {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15}
set ::FORZADO 0

debug set_bp 0x6a90 {} {
    if {[llength $::PENDIENTES] == 0} { return }
    set ::FORZADO [lindex $::PENDIENTES 0]
    debug write memory 0xe055 $::FORZADO
    debug write memory 0xe054 $::FORZADO
}

debug set_bp 0x4185 {} {
    if {$::FORZADO == 0} { return }
    set nivel [debug read memory 0xe054]
    if {$nivel != $::FORZADO} { return }
    set f [open [format "$::SALIDA/vram_%02d.bin" $nivel] w]
    fconfigure $f -translation binary
    puts -nonewline $f [debug read_block VRAM 0 16384]
    close $f
    set r {}
    for {set k 0} {$k < 8} {incr k} {
        lappend r [format %02X [debug read {VDP regs} $k]]
    }
    set f [open [format "$::SALIDA/info_%02d.txt" $nivel] w]
    puts $f "nivel $nivel"
    puts $f "regs [join $r { }]"
    puts $f "pantalla_del_jugador [debug read memory 0xe13a]"
    puts $f "jugador_y [debug read memory 0xe137]"
    puts $f "jugador_x [debug read memory 0xe139]"
    puts $f "lleva [debug read memory 0xe144]"
    puts $f "puerta_entrada [debug read memory 0xe056]"
    close $f
    say "nivel $nivel volcado"
    # y dos segundos mas tarde, otra vez la tabla de atributos de sprites:
    # las momias no estan al montar la sala, aparecen con su temporizador
    set ::TARDE $nivel
    after time 2.0 { sat_tarde }
}

proc sat_tarde {} {
    if {$::TARDE == 0} { return }
    set f [open [format "$::SALIDA/sat_%02d.txt" $::TARDE] w]
    for {set i 0} {$i < 32} {incr i} {
        set b {}
        for {set k 0} {$k < 4} {incr k} {
            lappend b [format %02X [debug read VRAM [expr {0x3b00 + $i*4 + $k}]]]
        }
        puts $f "[join $b { }]"
    }
    close $f
    say "sat del nivel $::TARDE"
    set ::TARDE 0
    set ::PENDIENTES [lrange $::PENDIENTES 1 end]
    set ::FORZADO 0
    if {[llength $::PENDIENTES] == 0} { say "FIN"; exit 0 }
    reset
    arranca
}
set ::TARDE 0

proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
proc arranca {} { after time 1.5 { pulsa 8 0x01 0.3 } }
arranca

after time $::SEG { say "FIN por tiempo: quedaban $::PENDIENTES"; exit 1 }
after realtime 300 { say "PERRO GUARDIAN"; exit 1 }
