# BARRIDO de varios huecos "sin explicar" a la vez: un watchpoint de LECTURA
# por rango, todos armados en INIT (0x406C), y una sesion mas larga de menu +
# demo + partida forzada. Triaje rapido: que rangos tienen lector de verdad
# (y desde que PC) y cuales siguen sin ninguna lectura en la ventana medida
# -eso NO prueba que no se lean nunca, solo que esta partida no los toco-.
#
#   "C:/Program Files/openMSX/openmsx.exe" -machine C-BIOS_MSX1_EU \
#       -cart kingsvalley.rom -script tools/omsx_barrido_huecos.tcl
#
# KV_SALIDA (carpeta), KV_SEG (duracion emulada, por defecto 240).

proc opcion {nombre porDefecto} {
    global env
    if {[info exists env($nombre)]} { return $env($nombre) }
    return $porDefecto
}
set ::SALIDA [opcion KV_SALIDA {C:/Users/Antxiko/Documents/DES_ASM/KINGSVALLEY_DISAM/work/omsx3}]
file mkdir $::SALIDA
set ::SEG [expr {[opcion KV_SEG 240]}]
set LOG [open "$::SALIDA/barrido.log" w]
proc say {m} { global LOG; puts $LOG "\[[format %8.2f [machine_info time]]\] $m"; flush $LOG }
set throttle off

# (nombre, inicio, fin-inclusive) de cada hueco a vigilar.
set ::RANGOS {
    {4542_454b 0x4542 0x454B}
    {45c0_45c7 0x45C0 0x45C7}
    {4c09_4c10 0x4C09 0x4C10}
    {4c8d_4cf9 0x4C8D 0x4CF9}
    {4d2e_4d3f 0x4D2E 0x4D3F}
    {4d42_4d60 0x4D42 0x4D60}
    {4d6d_4e98 0x4D6D 0x4E98}
    {4e9f_4fc8 0x4E9F 0x4FC8}
    {50f6_51e8 0x50F6 0x51E8}
    {57fd_5af5 0x57FD 0x5AF5}
    {5b1e_5b87 0x5B1E 0x5B87}
    {6532_659b 0x6532 0x659B}
    {6602_6741 0x6602 0x6741}
    {674e_67f1 0x674E 0x67F1}
    {68cf_68d9 0x68CF 0x68D9}
    {68e5_6937 0x68E5 0x6937}
    {69c9_6a11 0x69C9 0x6A11}
    {6a1e_6a5d 0x6A1E 0x6A5D}
    {6a68_6a8f 0x6A68 0x6A8F}
    {6df6_6ea3 0x6DF6 0x6EA3}
    {6eb0_6ec2 0x6EB0 0x6EC2}
    {6f47_6f5b 0x6F47 0x6F5B}
    {6f8c_70ce 0x6F8C 0x70CE}
    {70e6_7166 0x70E6 0x7166}
    {7169_71e6 0x7169 0x71E6}
    {71f2_73ce 0x71F2 0x73CE}
    {73ef_75b0 0x73EF 0x75B0}
}

set ::armado 0
foreach r $::RANGOS {
    lassign $r nombre a b
    set ::hit($nombre) [dict create]
    set ::n($nombre) 0
}

debug set_bp 0x406c {} {
    if {!$::armado} {
        set ::armado 1
        foreach r $::RANGOS {
            lassign $r nombre a b
            debug set_watchpoint read_mem [list [expr $a] [expr $b]] {} [subst -nocommands {
                dict incr ::hit($nombre) [reg PC]
                incr ::n($nombre)
            }]
        }
        say "INIT (0x406C) alcanzado: [llength $::RANGOS] watchpoints armados"
    }
}

# --- conducir a ciegas: menu, demo, y varias partidas forzadas ------------
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
    after time 0.4 paso
}
after time 1.5 { pulsa 8 0x01 0.3 }
after time 3.0 { paso }

proc informe {} {
    foreach r $::RANGOS {
        lassign $r nombre a b
        set n $::n($nombre)
        set d [dict size $::hit($nombre)]
        say [format "%-14s 0x%04X-0x%04X  lecturas=%-8d PC=%d" $nombre $a $b $n $d]
        if {$n > 0} {
            set l {}
            dict for {pc v} $::hit($nombre) { lappend l [list $v $pc] }
            set l [lsort -integer -index 0 -decreasing $l]
            foreach e [lrange $l 0 7] { say [format "    PC=0x%04X  %d veces" [lindex $e 1] [lindex $e 0]] }
        }
    }
    say "FIN"
    exit 0
}
after time $::SEG informe

after realtime 200 {
    say "PERRO GUARDIAN a los 200 s reales"
    exit 1
}
