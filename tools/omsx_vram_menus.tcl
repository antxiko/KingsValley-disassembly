# Vuelca la VRAM de VERDAD de las pantallas de menu, para comparar contra lo
# que dibuja tools/pantallas.py. Las salas ya estaban comprobadas
# (omsx_vram_sala.tcl); estas no lo estaban, y de ahi salieron dos errores: el
# rotulo de la web era el logotipo de KONAMI en vez del del JUEGO, y el mapa
# del valle salia sin su tabla de nombres.
#
#   0x43b7  final de dibuja_titulo_y_texto_ya: el titulo del juego ya esta
#           dibujado entero y el aviso revelado.
#   0x41c6  justo despues de monta_el_mapa_del_valle. Se espera medio segundo
#           mas para que los sprites de los digitos y las flechas esten ya
#           puestos.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_vram_menus.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx_menus}]
file mkdir $::SALIDA
set LOG [open "$::SALIDA/menus.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

proc vuelca {etiqueta} {
    set f [open "$::SALIDA/vram_$etiqueta.bin" w]
    fconfigure $f -translation binary
    puts -nonewline $f [debug read_block VRAM 0 16384]
    close $f
    set r {}
    for {set k 0} {$k < 8} {incr k} {
        lappend r [format %02X [debug read {VDP regs} $k]]
    }
    set g [open "$::SALIDA/info_$etiqueta.txt" w]
    puts $g "regs [join $r { }]"
    puts $g "sala [debug read memory 0xe054]"
    puts $g "destino [debug read memory 0xe055]"
    puts $g "e057 [debug read memory 0xe057]"
    close $g
    say "volcado $etiqueta"
}

set ::HECHO_TITULO 0
set ::HECHO_MAPA 0

debug set_bp 0x43b7 {} {
    if {$::HECHO_TITULO} { return }
    set ::HECHO_TITULO 1
    vuelca titulo
    if {$::HECHO_MAPA} { say FIN; exit 0 }
}

# EL MAPA DEL VALLE solo sale al pasarse una piramide, y la demo no se pasa
# ninguna. Se fuerza: en 0x4176 -que si se ejecuta cada vez que se monta una
# sala- se BORRA la tabla de nombres entera y se pone el PC en 0x41c0, que es
# la pareja de llamadas que monta el mapa. Borrar antes es lo que hace que el
# volcado sea concluyente: lo que aparezca en la tabla de nombres lo ha
# escrito el codigo del mapa y nadie mas.
debug set_bp 0x4176 {} {
    if {$::HECHO_MAPA} { return }
    set ::HECHO_MAPA 1
    for {set i 0} {$i < 768} {incr i} {
        debug write VRAM [expr {0x3800 + $i}] 0
    }
    reg pc 0x41c0
    after time 0.5 {
        vuelca mapa
        if {$::HECHO_TITULO} { say FIN; exit 0 }
    }
}

proc pulsa {fila masc dur} { keymatrixdown $fila $masc; after time $dur [list keymatrixup $fila $masc] }
after time 1.5 { pulsa 8 0x01 0.3 }
after time 4.0 { pulsa 8 0x01 0.3 }

after time 200 { say "FIN por tiempo: titulo=$::HECHO_TITULO mapa=$::HECHO_MAPA"; exit 1 }
after realtime 180 { say "PERRO GUARDIAN"; exit 1 }
