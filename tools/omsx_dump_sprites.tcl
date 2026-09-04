# Vuelca la tabla de atributos de sprites (VRAM 0x3B00-0x3B7F, 32 entradas de
# 4 bytes) y el buffer de RAM que L_4B75 usa como origen (0xE0B0-0xE12F) en
# varios instantes, para comprobar si de verdad son datos de sprites (Y, X,
# patron, color) y no texto/HUD. Tambien vuelca la zona de nombre (VRAM
# 0x3800-0x3AFF) para tener las 24 filas completas alrededor.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_dump_sprites.tcl

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}

set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx/sprites}]
file mkdir $::SALIDA

set LOG [open "$::SALIDA/sprites.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }

proc hex2 {v} { format %02X $v }

proc vuelca {etiqueta} {
    global LOG
    set l [format {%s tarea=%d fot=%d} $etiqueta [debug read memory 0xe000] [debug read memory 0xe003]]
    puts $LOG $l
    puts $LOG "SAT (VRAM 3B00, 32 entradas Y/X/patron/color):"
    for {set i 0} {$i < 32} {incr i} {
        set y [debug read VRAM [expr {0x3B00 + $i*4}]]
        set x [debug read VRAM [expr {0x3B00 + $i*4 + 1}]]
        set p [debug read VRAM [expr {0x3B00 + $i*4 + 2}]]
        set c [debug read VRAM [expr {0x3B00 + $i*4 + 3}]]
        puts $LOG [format "  spr%02d Y=%02X X=%02X pat=%02X col=%02X" $i $y $x $p $c]
    }
    puts $LOG "RAM origen (0xE0B0, 128 bytes):"
    set fila ""
    for {set i 0} {$i < 128} {incr i} {
        set b [debug read memory [expr {0xE0B0 + $i}]]
        append fila [format "%02X " $b]
        if {($i % 16) == 15} { puts $LOG "  $fila"; set fila "" }
    }
    puts $LOG "Nombre (VRAM 3800-3AFF): celdas con patron 51/52/53/5C:"
    for {set i 0} {$i < 768} {incr i} {
        set v [debug read VRAM [expr {0x3800 + $i}]]
        if {$v == 0x51 || $v == 0x52 || $v == 0x53 || $v == 0x5C} {
            puts $LOG [format "  celda %d (fila %d col %d) = %02X" $i [expr {$i/32}] [expr {$i%32}] $v]
        }
    }
    flush $LOG
}

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
    after time 0.6 paso
}
after time 1.5 { pulsa 8 0x01 0.3 }
after time 3.0 { paso }

set ::armado 0
debug set_bp 0x406c {} {
    if {!$::armado} {
        set ::armado 1
        say "INIT alcanzado"
    }
}

after time 2.0 { vuelca "t=2s (logo/titulo)" }
after time 6.0 { vuelca "t=6s (tras pulsar start)" }
after time 10.0 { vuelca "t=10s" }
after time 16.0 { vuelca "t=16s" }
after time 24.0 { vuelca "t=24s" }
after time 34.0 { vuelca "t=34s" }
after time 45.0 { vuelca "t=45s" }

after time 50.0 { say "FIN"; exit 0 }
after realtime 120 { say "PERRO GUARDIAN a los 120s reales"; exit 1 }
