; ==========================================================================
; KING'S VALLEY - Konami - MSX1 - cartucho RC-727 de 16 KB en la pagina 1
; ==========================================================================
; Generado por tools/mkasm.py a partir del trazado de flujo real.
; Los comentarios provienen de tools/../src/*.notes y estan anclados a
; direccion, de modo que sobreviven a un retrazado.
; ==========================================================================

	org 0x04000


; ----------------------------------------------------------------------
; Etiquetas que no caen en ninguna posicion emitida del listado
; (destinos fuera del binario o dentro de una instruccion).
; ----------------------------------------------------------------------
L_4F0F:	equ 0x04f0f

; ----------------------------------------------------------------------
; Direcciones que solo aparecen como VALOR -en un `ld`, no en
; un salto-: son punteros que el codigo se pasa o numeros que
; casualmente coinciden con una direccion. No hay nada que
; trazar en ellas; el equ existe para que el listado ensamble.
; ----------------------------------------------------------------------
l404ch:	equ 0x0404c

; ----------------------------------------------------------------------
; DATOS cabecera_del_cartucho: AB, y la direccion de INIT; el resto a cero
;   0x4000..0x4010  (16 bytes)
DATA_cabecera_del_cartucho:
	defw 04241h,0406ch,00000h,00000h,00000h,00000h,00000h,00000h	; 4000

; ======================================================================
; CODIGO 0x4010..0x40ba  (170 bytes)
; ======================================================================


suma_a_hl:		; HL += A con acarreo a H: sumador de 16 bits partido en 8+8, usado por todo el cartucho para indexar tablas con A
	add a,l			;4010   ; A+L: si no hay acarreo (ret nc) ya esta
	ld l,a			;4011
	ret nc			;4012
	inc h			;4013   ; hubo acarreo: sube H
	ret			;4014
suma_a_de:		; El mismo truco que suma_a_hl pero sobre DE, para cuando el puntero a avanzar viaja en DE en vez de HL
	add a,e			;4015   ; A+E: sin acarreo, ya esta
	ld e,a			;4016
	ret nc			;4017
	inc d			;4018   ; hubo acarreo: sube D
	ret			;4019
interrupcion:		; Un cuadro de juego: la engancha arranca_el_juego en H.KEYI (0xfd9a) y TODO el motor corre aqui dentro, cada VBLANK -mismo patron que el resto de la familia Konami de esta epoca (ver skyjaguar.notes: "el juego entero corre dentro de la interrupcion")-
	call 0013eh		;401a   ; BIOS RDVDP - Reads VDP status register | RDVDP: acusa recibo de la interrupcion leyendo S#0 (limpia el flag F del VDP)
	di			;401d
	call tick_sonido		;401e   ; tick_sonido primero de todo: el reproductor PSG se sirve con prioridad, cada cuadro
	ld hl,0e005h		;4021   ; 0xe005 es el candado de reentrada: si ya esta puesto, esta interrupcion se ha colado sobre otra en curso y se salta el cuerpo del cuadro
	bit 0,(hl)		;4024
	jr nz,interrupcion_rearma		;4026
	inc (hl)			;4028
	ei			;4029
	call lee_entrada_del_jugador		;402a
	call avanza_un_cuadro		;402d   ; avanza_un_cuadro: sube el contador de fotogramas y despacha la tarea activa
	xor a			;4030
	ld (0e005h),a		;4031   ; libera el candado (0xe005=0) al terminar el cuerpo del cuadro
interrupcion_rearma:		; Segunda lectura de S#0: si el VDP ya tiene OTRA interrupcion pendiente (bit 7 de S#0, flag F) antes de salir, corre tick_sonido una vez mas en vez de perderla -mismo "no perder un cuadro" que interrupcion_rearma en golf.notes-
	call 0013eh		;4034   ; BIOS RDVDP - Reads VDP status register | RDVDP otra vez: A = S#0 actual
	or a			;4037
	di			;4038
	call m,tick_sonido		;4039   ; bit 7 de S#0 cae en el flag de signo: call m dispara solo si ya hay otra F pendiente
	ei			;403c
	ret			;403d
proteccion_anticopia_tarea_1:		; Proteccion anticopia: machaca el primer byte de la tarea 1 (0x40e4) con el 0xe1 ("pop hl") que hay en 0x404c y le pone un 0xc9 (ret) detras. Corriendo desde ROM la escritura no hace nada -medido en caliente, tools/omsx_check_4644.tcl, 92 ejecuciones y el byte nunca cambia-; corriendo desde RAM revienta el titulo. Es ReadKeys_AC en el desensamblado de Manuel Pazos
	ld hl,040e4h		;403e   ; HL=0x40e4: el arranque de la tarea 1, que en un cartucho de verdad es ROM y no se deja escribir
	ld a,(l404ch)		;4041   ; A = byte de 0x404c (0xe1, "pop hl", el propio opcode de despacha_tabla_siguiente): la trampa se sirve de un byte que ya estaba
	ld (hl),a			;4044   ; escribe A en 0x40e4 y 0xc9 en 0x40e5: en ROM es un no-op silencioso, en RAM deja la tarea 1 en "pop hl / ret"
	inc hl			;4045
	ld (hl),0c9h		;4046
	jp L_45E8		;4048
despacha_tabla_siguiente:		; Entrada dual del salto por tabla en linea (ver la cabecera del fichero, se llama asi SIETE veces en todo el cartucho): por 0x404b dobla A primero, por 0x404c entra con A ya doblado; pop hl recupera la tabla que sigue pegada al call, y palabra_de_tabla la indexa
	add a,a			;404b   ; A *= 2: indice de tarea -> offset de word
L_404C:
	pop hl			;404c
	call palabra_de_tabla		;404d   ; pop hl = la tabla que sigue al call, no una direccion de retorno real
	jp (hl)			;4050   ; jp (hl): salta a la entrada elegida sin dejar rastro en la pila
escribe_guion_de_texto:		; Interprete de un guion de texto empotrado: por 0x4051 BORRA (C=0, cada byte sale como 0x00) o por 0x4055 escribe el texto real (C=0xff, sin enmascarar). El guion en (DE) empieza con un word -direccion VRAM de partida- seguido de los bytes de caracter, hasta 0xff (fin) o 0xfe (word siguiente: nueva direccion VRAM + continua)
	ld c,000h		;4051   ; C=0: modo borrado
	jr L_4057		;4053
L_4055:
	ld c,0ffh		;4055   ; C=0xff: modo normal, sin enmascarar
L_4057:
	ex de,hl			;4057   ; lee el word en (DE): la direccion VRAM de partida del guion, no una direccion de retorno
	ld e,(hl)			;4058
	inc hl			;4059
	ld d,(hl)			;405a
	ex de,hl			;405b   ; HL = esa direccion VRAM; DE avanza a los bytes de caracter que siguen justo detras del word
	inc de			;405c
L_405D:
	ld a,(de)			;405d   ; B=A+1: sale por ret z si A era 0xff (fin del guion)
	inc de			;405e
	ld b,a			;405f
	inc b			;4060
	ret z			;4061
	inc b			;4062   ; si A era 0xfe (B llega a 0 tras el segundo inc b): hay un word VRAM+continuacion nuevo, vuelve a leerlo
	jr z,L_4057		;4063
	and c			;4065
	call 0004dh		;4066   ; BIOS WRTVRM - Writes data in VRAM | WRTVRM: escribe A&C -el byte real o 0x00 segun el modo- y avanza HL
	inc hl			;4069
	jr L_405D		;406a
arranca_el_juego:		; INIT del cartucho: apaga interrupciones, modo IM1, fabrica a mano un `jp interrupcion` en H.KEYI (0xfd9a-0xfd9c, el gancho que la BIOS salta en cada VBLANK), pone SP=0xe700, borra a cero toda la RAM de trabajo 0xe000-0xe6ff, llama a prepara_pantalla y cae en bucle_muerto
	di			;406c   ; di/im1: nada se ejecuta a medias mientras se engancha la interrupcion
	im 1		;406d
	ld a,0c3h		;406f   ; 0xc3 = opcode jp: fabrica el salto a interrupcion byte a byte en H.KEYI
	ld (0fd9ah),a		;4071
	ld hl,interrupcion		;4074
	ld (0fd9bh),hl		;4077
	ld sp,0e700h		;407a   ; SP=0xe700: la pila crece hacia abajo dentro de la misma zona que se acaba de borrar; 0xe700 en si es donde empieza el buffer de sala de carga_la_sala, fuera del alcance de la pila
	ld hl,0e000h		;407d   ; ldir borra 0xe000-0xe6ff (0x700 bytes) de un tiron: toda la zona de trabajo arranca limpia
	ld de,0e001h		;4080
	ld bc,006ffh		;4083
	ld (hl),000h		;4086
	ldir		;4088
	ld a,001h		;408a
	ld (0e005h),a		;408c
	call prepara_pantalla		;408f   ; prepara_pantalla antes de abrir interrupciones
	xor a			;4092
	ld (0e005h),a		;4093
	call 0013eh		;4096   ; BIOS RDVDP - Reads VDP status register
	ei			;4099   ; ei: a partir de aqui la interrupcion puede saltar en cualquier momento
bucle_muerto:		; El programa "principal" no hace nada mas: todo el juego pasa a vivir dentro de la interrupcion (mismo patron que BUCLE_MUERTO en skyjaguar.notes)
	jr bucle_muerto		;409a
L_409C:
	ld (043c0h),de		;409c   ; LA SEGUNDA PROTECCION ANTICOPIA: escribe DE encima de 0x43c0, que no es un dato sino el OPERANDO del `jp nc,cierra_aviso_titulo` de 0x43bf. En ROM no pasa nada; desde RAM el dibujo del titulo salta a donde diga DE. Es VRAM_writeAC en el desensamblado de Manuel Pazos
	jp rellena_vram		;40a0
avanza_un_cuadro:		; Lo que interrupcion llama cada VBLANK: sube el contador de fotogramas (0xe003) y, si 0xe002 no tiene el bit 6 puesto, pasa antes por 0x4644 (llamada condicional fabricada con push hl+ret, confirmado: 0x4644 acaba en ret) antes de despachar la tarea activa
	ld hl,0e003h		;40a3   ; 0xe003: contador de fotogramas, +1 cada interrupcion; el motor de sonido lo usa como compuerta de "cada 8 cuadros" (and 007h/ret nz) en varios sitios
	inc (hl)			;40a6
	ld bc,(0e000h)		;40a7   ; BC=(0xe000): C=indice de la tarea activa (0-10, indexa tabla_de_tareas), B=su subcontador interno
	ld a,(0e002h)		;40ab   ; 0xe002 bit 6 a cero: hace falta un paso extra (0x4644) antes del despacho -bandera de un modo especial, cual exactamente no esta confirmado-
	bit 6,a		;40ae
	jr nz,despacha_tarea_activa		;40b0
	ld hl,04644h		;40b2
	push hl			;40b5
despacha_tarea_activa:		; A=C (el indice de tarea) y salta por despacha_tabla_siguiente/tabla_de_tareas
	ld a,c			;40b6
	call despacha_tabla_siguiente		;40b7

; ----------------------------------------------------------------------
; DATOS tabla_de_tareas: 11 entradas, indexadas por el byte bajo del contador
;   de 0xe000
;   0x40ba..0x40d0  (22 bytes)
DATA_tabla_de_tareas:
	defw 040d0h,0410dh,04115h,0429fh,04141h,041d5h,041f5h,04243h	; 40ba
	defw 04266h,0427bh,0429ch	; 40ca  -> tarea_8_suma_ronda tarea_9_cambia_de_pantalla L_429C

; ======================================================================
; CODIGO 0x40d0..0x4323  (595 bytes)
; ======================================================================


tarea_0_logo_konami:		; Tarea activa nada mas arrancar (indice 0 de tabla_de_tareas). Mientras nadie pulse ninguna tecla, mantiene el logo de Konami en pantalla organizado en cascada de tres etapas por el subcontador B de 0xe000 alto (0xe001): casi todos los fotogramas solo hace scroll (tarea_0_borra_y_r7 seguido de "en marcha" real); cuando esa cascada se agota ademas limpia VRAM y pone el color de borde; y cuando las TRES cascadas coinciden a la vez, redibuja el logo entero (tarea_0_dibuja_logo). SUPOSICION: cuantos fotogramas dura cada etapa, no medido -revisa_teclado_y_salta_menu se adelanta siempre en las pruebas de esta tanda-
	djnz tarea_0_borra_y_r7		;40d0   ; B baja un paso cada fotograma; casi siempre cae aqui (tarea_0_borra_y_r7)
	ld a,(0e003h)		;40d2   ; la vez que B llega a 0: solo actua uno de cada dos fotogramas (bit 0 del contador de 0xe003)
	rra			;40d5
	ret nc			;40d6
	call tarea_0_desplaza_logo		;40d7   ; desplaza el logo un paso (tarea_0_desplaza_logo); si sigue desplazando, nada mas que hacer este fotograma
	ret nz			;40da
	ld de,047feh		;40db   ; con el desplazamiento parado, dibuja el guion de 0x47fe (formato CON direccion)
	call dibuja_guion_con_direccion		;40de
	xor a			;40e1
	jr guarda_contador_de_etapa		;40e2   ; fin de esta etapa: solo suma 1 al "orden" (0xe001), NO cambia de tarea
tarea_0_borra_y_r7:		; Etapa intermedia de la cascada: se alcanza cuando el subcontador de la etapa anterior llega a 0. Es tambien la VICTIMA de la proteccion anticopia de 0x403e, que intenta machacar el PRIMER byte de aqui: en un cartucho de verdad esto es ROM y la escritura no cuela, en una copia en RAM si
	djnz tarea_0_dibuja_o_avanza		;40e4   ; igual que arriba: lo normal es caer en la etapa "en marcha" real (tarea_0_dibuja_o_avanza)
	ld hl,0e004h		;40e6
	dec (hl)			;40e9   ; la vez que TAMBIEN se agota: contador propio de esta etapa (0xe004)
	ret nz			;40ea
	call L_44A1		;40eb   ; limpia 768 bytes de VRAM en 0x7800 (rellena_vram)
	call pon_registro_vdp_7		;40ee   ; color de borde/fondo (pon_registro_vdp_7)
	xor a			;40f1
	ld (0e00ah),a		;40f2   ; reinicia el contador de revelado (0xe00a) para la proxima vez que haga falta
	jr L_410A		;40f5   ; fin de esta etapa, sin cambiar de tarea
tarea_0_dibuja_o_avanza:		; Etapa mas profunda de la cascada: solo se alcanza cuando las DOS cascadas anteriores coinciden en 0
	djnz tarea_0_dibuja_logo		;40f7   ; igual: lo normal es caer en "dibuja el logo entero" (tarea_0_dibuja_logo)
	call revela_texto_aviso		;40f9   ; la vez que esto TAMBIEN se agota: un paso mas del aviso (revela_texto_aviso)
	ret c			;40fc   ; si el aviso sigue "en marcha" (acarreo), nada mas que hacer
	xor a			;40fd
	jp L_41AD		;40fe   ; aviso completo: avanza a la tarea 1, con su contador de fotogramas a 0
tarea_0_dibuja_logo:		; Redibuja el logo de Konami entero: la etapa MENOS frecuente de la cascada
	call L_44A1		;4101   ; limpia la misma franja de VRAM que la etapa anterior
	call dibuja_grupo_del_titulo		;4104   ; dibuja el grupo completo de guiones del logo (dibuja_grupo_del_titulo: Konami + King's Valley + piramide)
	call carga_registros_vdp		;4107   ; recarga los 8 registros del VDP
L_410A:
	jp avanza_orden		;410a   ; fin: solo suma 1 al "orden" (0xe001)
tarea_1_titulo_natural:		; Tarea 1 (pantalla de titulo) por el camino LENTO: cuenta 0xe004 fotogramas y, al llegar a 0, pasa a la tarea 2 via avanza_siguiente_tarea. El camino rapido (pulsar SPACE) la salta entera: fuerza_tarea_3_si_hay_input pone la tarea directamente en 3, verificado en caliente
	ld hl,0e004h		;410d   ; cuenta atras el contador de esta tarea
	dec (hl)			;4110
	ret nz			;4111   ; mientras no llegue a 0, nada que hacer
	jp L_41AB		;4112   ; pasa a la tarea 2 (arranca_partida), que se reenvia sola a la 4
arranca_partida:		; Tarea 2: en el camino natural la alcanza tarea_1_titulo_natural, pero se reenvia SOLA a la tarea 4 (juego/demo) en el mismo fotograma, dejando inicializadas variables de partida. Por el camino rapido (SPACE) nunca se pasa por aqui: fuerza_tarea_3_si_hay_input salta directo a la tarea 3
	ld hl,00004h		;4115   ; (0xe000) := 4: la SIGUIENTE tarea sera la 4, con el subcontador a 0
	ld (0e000h),hl		;4118
	ld l,000h		;411b   ; (0xe062) := 0: SUPOSICION, variable de partida sin identificar (posicion o sala inicial)
	ld (0e062h),hl		;411d
	ld a,l			;4120
	ld (0e058h),a		;4121   ; (0xe058) := 0: SUPOSICION, otra variable de partida sin identificar
	call copia_tabla_inicial		;4124   ; copia_tabla_inicial: el estado de arranque de vidas/puntuacion
	ld hl,00805h		;4127
	ld (0e055h),hl		;412a   ; (0xe055) := 0x0805: SUPOSICION, sin identificar
	ld hl,04aceh		;412d
	ld (0e080h),hl		;4130   ; (0xe080) := 0x4ace: SUPOSICION, puntero a datos sin identificar
	ld a,008h		;4133
	ld (0e082h),a		;4135   ; (0xe082) := 8: SUPOSICION, sin identificar
	ret			;4138
guarda_contador_de_etapa:		; Guarda A en 0xe004 (el contador de fotogramas de la PROXIMA etapa dentro de la misma tarea) y cae en avanza_orden
	ld (0e004h),a		;4139   ; A trae el contador que se quiere para la proxima etapa
avanza_orden:		; Suma 1 al "orden" (0xe001), el sub-paso dentro de la tarea activa; NO toca el indice de tarea (0xe000)
	ld hl,0e001h		;413c   ; HL = direccion de 0xe001
	inc (hl)			;413f   ; lo incrementa
	ret			;4140
tarea_4_nombre_de_sala:		; Muestra el nombre de sala (SCORE/HI/REST/PYRAMID-nn) antes de que la demo empiece a moverse. Verificado en caliente: dura siempre 200 fotogramas exactos en las cinco veces observadas -el numero SI esta medido, aunque la cascada interna (B y 0xe004) que lo produce no se ha desenredado del todo, ver SUPOSICION abajo-
	ld a,(0e051h)		;4141   ; bit 0 de (0xe051): SUPOSICION, decide si esta tarea ya esta "activa" (rama con L_4bE4/L_4b75, sin explorar esta tanda) o todavia "esperando" (avanza_siguiente_tarea via tarea_4_espera, abajo)
	rra			;4144
	jp nc,tarea_4_espera		;4145   ; si el bit esta a 0 (el caso medido en esta tanda): a tarea_4_espera
	ld a,b			;4148
	or a			;4149
	jr z,L_4151		;414a
	push bc			;414c
	call parpadea_patron_borde		;414d
	pop bc			;4150
L_4151:
	djnz L_415A		;4151
	ld hl,0e004h		;4153
	dec (hl)			;4156
	ret nz			;4157
	jr guarda_contador_de_etapa		;4158
L_415A:
	djnz tarea_4_espera_a_jugar		;415a
	call actualiza_tabla_de_sprites		;415c
	jp L_6DE8		;415f
tarea_4_paso_de_entrada:		; Un paso de la entrada a la sala: espera al temporizador de 0x4330, aparca los sprites y baja el contador de 0xE050
	call temporizador_de_dos_contadores		;4162
	ret p			;4165   ; P: el temporizador todavia no ha llegado
	call aparca_buffer_de_sprites		;4166   ; aparca los sprites del buffer
	ld hl,0e050h		;4169   ; HL = 0xE050, el contador de rondas
	dec (hl)			;416c   ; baja uno
	ld a,(0e05eh)		;416d   ; (0xE05E): SUPOSICION, un marcador que aqui no cambia el camino
	or a			;4170
	jr nz,tarea_4_monta_la_sala		;4171
tarea_4_monta_la_sala:		; Monta la sala entera: carga_la_sala via 0x432a, el estado de la sala, la escena de premio, el sprite del jugador, la SAT, los enemigos y el rotulo; y deja 0x10 fotogramas para el paso siguiente
	call L_432A		;4173   ; borra y carga la sala
	call despacha_estado_de_la_sala		;4176   ; el estado general de la sala
	call monta_escena_de_premio		;4179   ; la escena de premio
	call monta_sprite_del_jugador		;417c   ; el sprite del jugador
	call actualiza_tabla_de_sprites		;417f   ; vuelca el buffer de sprites a la SAT
	call coloca_al_jugador_en_la_sala		;4182   ; prepara todos los enemigos
	call L_4404		;4185   ; y el rotulo de 0x4404
	ld a,010h		;4188   ; 0x10 fotogramas para el paso siguiente
	jr guarda_contador_de_etapa		;418a
tarea_4_espera_a_jugar:		; Agotadas las dos cascadas, apaga la marca de sala resuelta, refresca el estado de la sala, suena el efecto 0x8b en el modo especial y deja 0xE053 en 1 antes de pasar a la tarea 5
	djnz tarea_4_paso_de_entrada		;418c   ; mientras B no se agote, sigue en el paso anterior
	ld hl,0e004h		;418e   ; HL = 0xE004, la segunda cascada
	dec (hl)			;4191
	ret nz			;4192   ; mientras quede, espera
	xor a			;4193
	ld (0e133h),a		;4194   ; (0xE133) := 0: la sala arranca sin resolver
	call despacha_estado_de_la_sala		;4197   ; refresca el estado de la sala
	ld a,(0e002h)		;419a   ; (0xe002) bit 6: solo en el modo especial hay efecto
	bit 6,a		;419d
	jr z,L_41A6		;419f
	ld a,08bh		;41a1
	call reproduce_efecto		;41a3   ; efecto de sonido 0x8b
L_41A6:
	ld hl,0e053h		;41a6
	ld (hl),001h		;41a9
L_41AB:
	ld a,020h		;41ab
L_41AD:
	ld (0e004h),a		;41ad
L_41B0:
	ld hl,0e000h		;41b0
	inc (hl)			;41b3
L_41B4:
	xor a			;41b4
	ld (0e001h),a		;41b5
	ret			;41b8
tarea_4_espera:		; La rama "esperando" de la tarea 4: cuenta dos cascadas de fotogramas (B, y luego 0xe004) antes de pasar a la tarea 5. Verificado en caliente: PC=0x41b3 (avanza_siguiente_tarea) en las CUATRO transiciones 4->5 observadas
	djnz tarea_4_cuenta_ronda		;41b9   ; primera cascada (B); casi siempre cae aqui, sigue esperando
	ld hl,0e004h		;41bb   ; la vez que B se agota: segunda cascada (0xe004)
	dec (hl)			;41be
	ret nz			;41bf
	call L_4407		;41c0   ; con las dos agotadas: dibuja el nombre de sala (L_4407, sin explorar el detalle esta tanda) y algo mas (L_773c, sin explorar)
	call monta_el_mapa_del_valle		;41c3
	jr L_41A6		;41c6   ; marca (0xe053)=1 y avanza a la tarea 5 (avanza_siguiente_tarea)
tarea_4_cuenta_ronda:		; El otro paso de la cascada de la tarea 4: espera al temporizador, baja el contador de rondas y deja 1 fotograma para el paso siguiente
	call temporizador_de_dos_contadores		;41c8
	ret p			;41cb   ; P: el temporizador todavia no ha llegado
	ld hl,0e050h		;41cc   ; HL = 0xE050, el contador de rondas
	dec (hl)			;41cf   ; baja uno
	ld a,001h		;41d0   ; 1 fotograma para el paso siguiente
	jp guarda_contador_de_etapa		;41d2
tarea_5_sala_en_reposo:		; La sala se ve quieta (SUPOSICION: el jugador/enemigos de la demo todavia no se mueven) hasta que (0xe053) se pone a 0 -por quien, no explorado esta tanda-, momento en que avanza a la tarea 6. Verificado en caliente: PC=0x41b3 en las CUATRO transiciones 5->6 observadas
	ld a,(0e051h)		;41d5   ; bit 0 de (0xe051): SUPOSICION, decide entre dos rutinas de logica de juego/enemigos sin explorar (L_4b0c/L_77b7)
	rra			;41d8
	push af			;41d9
	call c,bucle_de_juego		;41da
	pop af			;41dd
	call nc,pantalla_en_reposo		;41de
	ld a,(0e00dh)		;41e1   ; (0xe00d): SUPOSICION, alguna condicion especial; si esta puesta fuerza la tarea a 7 directamente (fin de demo anticipado)
	or a			;41e4
	jr z,L_41EE		;41e5
	ld a,007h		;41e7
	ld (0e000h),a		;41e9
	jr L_41B0		;41ec
L_41EE:
	ld a,(0e053h)		;41ee   ; (0xe053): mientras siga puesto (el jugador/demo "quieto"), espera
	or a			;41f1
	ret nz			;41f2
	jr L_41AB		;41f3   ; a 0: avanza a la tarea 6 (avanza_siguiente_tarea)
tarea_6_juego_en_marcha:		; El esqueleto/jugador se mueve de verdad. Verificado en caliente: PC=0x4238 en las CUATRO transiciones 6->4 (repite la misma sala de la demo) observadas
	ld a,(0e010h)		;41f5   ; (0xe010): si esta puesto ("ocupado", SUPOSICION), esta tarea no hace nada este fotograma
	or a			;41f8
	ret nz			;41f9
	ld a,(0e002h)		;41fa   ; vuelve a mirar el bit 6 de 0xe002 (el "modo especial" que fuerza_tarea_3_si_hay_input enciende)
	bit 6,a		;41fd
	jr nz,tarea_6_decide_repetir		;41ff   ; si esta puesto: a tarea_6_decide_repetir; si no (SUPOSICION, caso no observado en esta tanda): fuerza la tarea a 0 directamente
	xor a			;4201
	jp L_4238		;4202
tarea_6_decide_repetir:		; (0xe050) dice si quedan mas pyramides/rondas de demo -SUPOSICION, el nombre exacto de la variable no esta confirmado-: si quedan, repite la sala (tarea 4 otra vez); si no, un efecto de cierre y pasa a la tarea 7
	ld a,(0e050h)		;4205   ; (0xe050) != 0: quedan mas rondas de demo
	or a			;4208
	jr nz,tarea_6_repite_demo		;4209
	xor a			;420b
	ld hl,03929h		;420c   ; si no quedan: borra 5 filas x 12 celdas (SUPOSICION: la franja de SCORE/HI/REST)
	ld b,005h		;420f
L_4211:
	push bc			;4211
	xor a			;4212
	ld bc,0000ch		;4213
	call rellena_vram		;4216   ; rellena_vram, una fila a la vez
	ld a,020h		;4219
	call suma_a_hl		;421b   ; siguiente fila
	pop bc			;421e
	djnz L_4211		;421f
	ld a,09ah		;4221   ; efecto de sonido 0x9a
	call reproduce_efecto		;4223
	ld de,047f2h		;4226   ; dibuja un guion mas (0x47f2, sin explorar el contenido esta tanda)
	call L_4055		;4229
	ld a,006h		;422c
	ld (0e000h),a		;422e   ; reescribe la tarea activa a 6 (sin cambiarla: solo rearma el contador de abajo)
	ld a,0b8h		;4231   ; contador de fotogramas de la tarea 7: 0xb8 (184)
	jp L_41AD		;4233   ; avanza a la tarea 7 (guarda_contador_y_avanza_tarea, con el contador propio de arriba en vez del 0x20 por defecto)
tarea_6_repite_demo:		; Quedan mas rondas: fuerza la tarea directamente a 4 (repite la sala), verificado en caliente (PC=0x4238)
	ld a,004h		;4236   ; A=4: la tarea directamente al indice 4
L_4238:
	ld (0e000h),a		;4238   ; (0xe000) := A: escribe el indice de tarea sin pasar por avanza_siguiente_tarea (que solo sabe sumar 1)
	ld a,020h		;423b   ; contador de fotogramas por defecto para la tarea que empieza (0x20)
	ld (0e004h),a		;423d
	jp L_41B4		;4240   ; limpia el "orden" (limpia_orden_de_tarea)
tarea_7_fin_demo:		; Pausa final tras la ultima ronda de la demo (el contador de 0xb8 fotogramas que dejo tarea_6_decide_repetir) y reinicia el ciclo entero. Verificado en caliente: PC=0x4238 en la unica transicion 7->0 observada
	ld hl,0e003h		;4243   ; bit 0 del contador de fotogramas (0xe003): solo actua uno de cada dos
	ld a,(hl)			;4246
	and 001h		;4247
	ret z			;4249
	inc hl			;424a   ; la vez que ademas se agota el contador propio (0xe004): revisa el teclado tambien aqui (revisa_teclado_y_salta_menu)
	dec (hl)			;424b
	ret nz			;424c
	call revisa_teclado_y_salta_menu		;424d
	ld a,(0e000h)		;4250   ; si la tarea SIGUE siendo la 7 (nadie la ha cambiado mientras tanto): a tarea_7_reinicia
	cp 007h		;4253
	ld de,0e002h		;4255
	jr z,tarea_7_reinicia		;4258
	ld a,(de)			;425a   ; si no: solo apaga el bit 6 de 0xe002 (el "modo especial"), sin tocar la tarea
	and 0bfh		;425b
	ld (de),a			;425d
	ret			;425e
tarea_7_reinicia:		; Apaga el bit 6 de 0xe002 y fuerza la tarea a 0: el logo de Konami vuelve a arrancar, cerrando el ciclo completo
	ld a,(de)			;425f   ; apaga el bit 6 de 0xe002 (el "modo especial" que fuerza_tarea_3_si_hay_input habia encendido)
	and 0bfh		;4260
	ld (de),a			;4262
	xor a			;4263   ; A=0
	jr L_4238		;4264   ; fuerza la tarea a 0 (comparte tarea_6_repite_demo/0x4238, con A=0 en vez de 4)
tarea_8_suma_ronda:		; Tarea 8: suena el efecto 0x20, sube el contador de 0xE050, suma 1 en BCD al de 0xE051, limpia 0xE00D y vuelve a la tarea 4
	ld a,020h		;4266   ; efecto de sonido 0x20
	call reproduce_efecto		;4268
	ld hl,0e050h		;426b   ; HL = 0xE050
	inc (hl)			;426e   ; sube uno
	inc hl			;426f
	ld a,(hl)			;4270
	add a,001h		;4271   ; el contador siguiente sube 1...
	daa			;4273   ; ...en BCD
	ld (hl),a			;4274
	xor a			;4275
	ld (0e00dh),a		;4276   ; (0xE00D) := 0: se limpia la senal de fin de demo
	jr tarea_6_repite_demo		;4279   ; y de vuelta a la tarea 4
tarea_9_cambia_de_pantalla:		; Tarea 9: cuando el contador de 0x5cf5 se agota, devuelve la tarea a la 5 y teletransporta al jugador al borde OPUESTO de la pantalla contigua -X=0xF0 o X=0x04 y el byte alto de la X mas o menos uno, o sea 256 pixeles de salto-, y lo redibuja
	call cuenta_atras_de_cuatro		;427b   ; el contador de 0x5cf5; C = todavia no toca
	ret c			;427e
	ld hl,0e000h		;427f   ; HL = 0xE000, la tarea activa
	ld (hl),005h		;4282   ; de vuelta a la tarea 5
	ld a,(0e136h)		;4284   ; A = (0xe136), a que lado mira
	rra			;4287
	ld a,(0e13ah)		;4288   ; A = el byte ALTO de la X del jugador
	ld c,0f0h		;428b   ; C = 0xF0: el borde derecho
	ld b,a			;428d   ; B = el byte alto de antes
	dec b			;428e   ; menos uno: la pantalla anterior
	jr c,L_4295		;428f
	inc b			;4291   ; por el otro lado: mas uno, la pantalla siguiente
	inc b			;4292
	ld c,004h		;4293   ; y C = 0x04, el borde izquierdo
L_4295:
	ld (0e139h),bc		;4295   ; escribe la X entera de golpe: baja en 0xe139, alta en 0xe13a
	jp monta_sprite_del_jugador		;4299   ; y redibuja al jugador en su sitio nuevo
L_429C:
	jp tarea_10_reinicia_al_jugador		;429c
tarea_3_texto_de_arranque:		; Tarea 3: cuenta atras 0xE004 dibujando alternativamente el guion de texto 0x47e1 y el de 0x4055 segun el bit 2 del contador; al agotarse borra la RAM de trabajo y pasa a la tarea 4
	djnz tarea_3_arranca		;429f   ; mientras B no se agote, sigue en el paso siguiente
	ld hl,0e004h		;42a1   ; HL = 0xE004, el contador
	dec (hl)			;42a4
	jr z,tarea_3_termina		;42a5   ; agotado: borra y avanza
	bit 2,(hl)		;42a7   ; bit 2 del contador: alterna entre las dos formas de dibujar
	ld de,047e1h		;42a9   ; DE = el guion 0x47e1
	jp nz,escribe_guion_de_texto		;42ac
	jp L_4055		;42af
tarea_3_termina:		; El contador se agoto: borra la RAM de trabajo y pasa a la tarea 4
	call borra_ram_de_trabajo		;42b2   ; borra la RAM de trabajo
	jp L_41AB		;42b5   ; y avanza de tarea
tarea_3_arranca:		; Primer paso de la tarea 3: efecto 0x97 y 0x50 fotogramas de contador
	ld a,097h		;42b8   ; efecto de sonido 0x97
	call reproduce_efecto		;42ba
	ld a,050h		;42bd   ; (0xE004) := 0x50
	ld (0e004h),a		;42bf
	jp avanza_orden		;42c2   ; y avanza el orden
pon_registro_vdp_7:		; Programa el registro 7 del VDP (color de borde/fondo) directamente por BIOS, sin pasar por carga_registros_vdp
	ld b,0e0h		;42c5   ; B = el valor a programar en el registro
	ld c,007h		;42c7
	jp 00047h		;42c9   ; BIOS WRTVDP - Writes data in the VDP-register | WRTVDP (BIOS 0x0047), por jp: vuelve directo al llamador de pon_registro_vdp_7
dibuja_grupo_del_titulo:		; Dibuja TODO lo que se ve en la pantalla de titulo: el logo de Konami (prepara_scroll_del_logo) y de ahi para abajo el nombre "King's Valley" mas la piramide y 22 columnas de fondo, seis guiones en total (ver las notas de guion_xxx de mas arriba)
	call prepara_scroll_del_logo		;42cc   ; el logo de Konami (prepara_scroll_del_logo)
	call rellena_franja_borde		;42cf   ; una franja de borde (rellena_franja_borde)
	ld hl,00008h		;42d2
	ld de,047a7h		;42d5
	call dibuja_guion_x3_tercios		;42d8   ; un guion mas (0x47a7) del grupo del logo
L_42DB:
	ld de,0490bh		;42db   ; el nombre "King's Valley" (guion 0x490b)
	ld hl,02480h		;42de
	call dibuja_guion_x3_tercios		;42e1   ; la piramide (guion 0x4a97)
	ld de,04a97h		;42e4
	ld hl,00480h		;42e7
	call dibuja_guion_x3_tercios		;42ea
	ld hl,044d8h		;42ed
	ld b,016h		;42f0
L_42F2:
	push bc			;42f2   ; 22 columnas de fondo (guion 0x4aab), una fila mas abajo cada vez
	push hl			;42f3
	ld de,04aabh		;42f4
	call dibuja_guion_x3_tercios		;42f7
	pop hl			;42fa
	ld bc,00010h		;42fb
	add hl,bc			;42fe
	pop bc			;42ff
	djnz L_42F2		;4300
	ld a,040h		;4302
	ld bc,00010h		;4304
	jp rellena_x3_tercios		;4307   ; remata con un relleno solido de los tres tercios (rellena_x3_tercios)
borra_ram_de_trabajo:		; Pone a cero los 0xE8 bytes de RAM de trabajo desde 0xE049 (el marcador y todo el estado de partida) propagando un cero con ldir
	ld hl,0e049h		;430a   ; HL = 0xE049, el principio de la RAM de trabajo
	ld bc,000e7h		;430d   ; BC = 0xE7 bytes a propagar
	ld d,h			;4310
	ld e,l			;4311
	inc e			;4312
	ld (hl),000h		;4313   ; el primer byte a cero...
	ldir		;4315   ; ...y el ldir lo arrastra por el resto
copia_tabla_inicial:		; Copia los 7 bytes de tabla_inicial_e050 a la RAM de trabajo (0xE050): el valor de arranque de esas variables
	ld hl,04323h		;4317   ; HL = origen (tabla_inicial_e050)
	ld de,0e050h		;431a   ; DE = destino en RAM de trabajo
	ld bc,00007h		;431d
	ldir		;4320   ; ldir copia los 7 bytes
	ret			;4322

; ----------------------------------------------------------------------
; DATOS tabla_inicial_e050: Siete bytes copiados a 0xE050 por el ldir de
;   0x431a
;   0x4323..0x432a  (7 bytes)
DATA_tabla_inicial_e050:
	defb 005h,001h,000h,002h,001h,001h,008h	; 4323

; ======================================================================
; CODIGO 0x432a..0x4501  (471 bytes)
; ======================================================================


L_432A:
	call prepara_sala_nueva		;432a
	jp carga_la_sala		;432d
temporizador_de_dos_contadores:		; Baja a la vez el contador de fotogramas y el de 0xE004; con el segundo en negativo devuelve M, y si no borra 24 filas de VRAM a partir de la que dice el contador
	ld hl,0e003h		;4330   ; HL = 0xE003, el contador de fotogramas
	dec (hl)			;4333   ; baja uno
	inc hl			;4334
	dec (hl)			;4335   ; y el de 0xE004 tambien
	ret m			;4336   ; en negativo: todavia no toca
	ld a,(hl)			;4337   ; A = el contador
	ld h,038h		;4338   ; la fila alta es 0x38: la tabla de nombres
	xor 01fh		;433a   ; xor 0x1F: la fila se cuenta al reves
	ld l,a			;433c
	ld b,018h		;433d   ; B = 24 filas
	xor a			;433f
borra_una_fila:		; Escribe un cero en la celda y salta 32 bytes: la misma columna de la fila siguiente
	call 0004dh		;4340   ; BIOS WRTVRM - Writes data in VRAM | un cero en esta celda
	ld de,00020h		;4343   ; 32 bytes: la fila siguiente
	add hl,de			;4346
	djnz borra_una_fila		;4347
aparca_sat:		; Rellena los 128 bytes de la tabla de atributos de sprites con 0xC3: una Y de 195, por debajo de la pantalla, que esconde los 32 sprites de golpe
	ld hl,03b00h		;4349   ; HL = VRAM 0x3B00, la tabla de atributos de sprites
	ld bc,00080h		;434c   ; BC = 128 bytes: las 32 entradas
	ld a,0c3h		;434f   ; 0xC3 = 195: una Y por debajo de las 192 lineas, fuera de pantalla
	call rellena_vram		;4351
	xor a			;4354
	ret			;4355
aparca_buffer_de_sprites:		; Deja en 0xE1 (-31) la Y de las 32 entradas del buffer de sprites de RAM: las aparca todas fuera de pantalla
	ld b,020h		;4356   ; B = 32 entradas
aparca_n_sprites:		; Aparca las B entradas del buffer que empiezan en 0xE0B0
	ld hl,0e0b0h		;4358   ; HL = 0xE0B0, el principio del buffer
aparca_desde_hl:		; Escribe 0xE1 en la Y de B entradas consecutivas a partir de HL, saltando de cuatro en cuatro
	ld (hl),0e1h		;435b   ; 0xE1 = -31: la Y que deja el sprite fuera de pantalla
	inc hl			;435d   ; los otros tres bytes de la entrada, sin tocar
	inc hl			;435e
	inc hl			;435f
	inc hl			;4360
	djnz aparca_desde_hl		;4361
	ret			;4363
aparca_diez_sprites:		; Aparca las diez entradas del buffer que empiezan en 0xE0C8, las del anillo de parpadeo y las siguientes
	ld hl,0e0c8h		;4364   ; HL = 0xE0C8, el anillo de parpadeo
	ld b,00ah		;4367   ; B = 10 entradas
	jr aparca_desde_hl		;4369
dibuja_numero_de_sala:		; Dibuja el guion 0x480e y luego el numero de sala en VRAM 0x3AF3: (0xE058)*15 mas (0xE054)
	ld de,0480eh		;436b   ; DE = el guion 0x480e
	call L_4055		;436e
	ld a,(0e058h)		;4371   ; A = (0xE058), la vuelta de la partida
	ld b,a			;4374   ; B lo guarda
	add a,a			;4375   ; x16...
	add a,a			;4376
	add a,a			;4377
	add a,a			;4378
	sub b			;4379   ; ...menos uno: x15, las salas de una vuelta
	ld b,a			;437a
	ld a,(0e054h)		;437b   ; mas (0xE054), la sala de esta vuelta
	add a,b			;437e
	ld hl,03af3h		;437f   ; HL = VRAM 0x3AF3, donde va el numero de sala
	jp L_438B		;4382
dibuja_contador_de_rondas:		; Dibuja en VRAM 0x381D el contador de rondas de 0xE050
	ld hl,0381dh		;4385   ; HL = VRAM 0x381D
	ld a,(0e050h)		;4388   ; A = (0xE050), las rondas que quedan
L_438B:
	call L_4393		;438b
	ld b,001h		;438e
	jp L_447D		;4390
L_4393:
	ld b,a			;4393
	sub 064h		;4394
	jr nc,L_4393		;4396
	ld c,000h		;4398
divide_entre_diez:		; Divide B entre diez restando de diez en diez y contando en el nibble alto de C: convierte un binario pequeno en BCD
	ld a,b			;439a   ; A = el resto que va quedando
	sub 00ah		;439b   ; menos diez
	jr c,junta_las_dos_cifras		;439d   ; por debajo de diez, se acabo
	push af			;439f
	ld a,c			;43a0
	add a,010h		;43a1   ; una decena mas en el nibble alto de C
	ld c,a			;43a3
	pop af			;43a4
	ld b,a			;43a5
	jr nz,divide_entre_diez		;43a6   ; mientras quede, otra vuelta
junta_las_dos_cifras:		; Junta en A el nibble alto (las decenas) y el bajo (las unidades)
	ld a,c			;43a8   ; A = las decenas
	or b			;43a9   ; mas las unidades
	ret			;43aa
dibuja_titulo_y_texto_ya:		; Dibuja el titulo "King's Valley" (la mitad de guiones de dibuja_grupo_del_titulo que no es el logo de Konami) y revela el aviso (PUSH SPACE KEY/PLAY START) entero, sin esperar fotograma a fotograma: la llama revisa_teclado_y_salta_menu cuando el jugador se salta la espera natural
	call L_42DB		;43ab   ; dibuja el titulo (guiones 490b/4a97/4aab x22, ver dibuja_grupo_del_titulo)
	xor a			;43ae
	ld (0e00ah),a		;43af   ; arranca a cero el contador de revelado del aviso
L_43B2:
	call revela_texto_aviso		;43b2   ; revela un paso mas del aviso
	jr c,L_43B2		;43b5   ; mientras siga "en marcha" (acarreo puesto), sigue llamando en el MISMO fotograma: por eso aqui el texto aparece de golpe, y no fotograma a fotograma como en la espera natural
	ret			;43b7
revela_texto_aviso:		; Un paso del aviso de la pantalla de titulo: escribe una columna mas de dos filas de texto en VRAM, eligiendo entre dos textos segun el contador (0xe00a, 0-21) -SUPOSICION: PUSH SPACE KEY para 0-8, PLAY START para 9-21, no confirmado cual dibujo es cual, solo que hay dos bases VRAM distintas-
	ld hl,0e00ah		;43b8   ; A = paso actual (0xe00a), y lo sube para el siguiente
	ld a,(hl)			;43bb
	inc (hl)			;43bc
	cp 016h		;43bd   ; si ya paso de 22 el aviso esta completo: a la transicion final (cierra_aviso_titulo)
	jp nc,cierra_aviso_titulo		;43bf
	ld hl,038a7h		;43c2   ; base VRAM del primer texto
	cp 009h		;43c5   ; los primeros 9 pasos usan el primer texto...
	jr c,L_43CC		;43c7
	ld hl,03904h		;43c9   ; ...los siguientes, el segundo (base VRAM distinta)
L_43CC:
	ld c,a			;43cc   ; C = el paso: el indice de columna dentro del texto
	add a,l			;43cd   ; HL += paso: la celda VRAM de esta columna en la fila de arriba
	ld l,a			;43ce
	ld a,c			;43cf
	add a,a			;43d0
	add a,09bh		;43d1   ; C = paso*2 + 0x9b: el indice de caracter en la tabla de patrones (dos filas por letra)
	ld c,a			;43d3
	ld b,002h		;43d4   ; B=2: dos filas por letra
L_43D6:
	ld a,c			;43d6
	call 0004dh		;43d7   ; BIOS WRTVRM - Writes data in VRAM | escribe el patron de esta fila
	ld a,020h		;43da
	call suma_a_hl		;43dc   ; siguiente fila, una mas abajo en VRAM
	inc c			;43df   ; siguiente indice de patron
	djnz L_43D6		;43e0   ; repite las dos filas
	ld a,l			;43e2
	sub 0ech		;43e3   ; SUPOSICION: ajuste para los ultimos pasos del segundo texto (mas corto que el primero), aritmetica exacta sin confirmar
	cp 002h		;43e5
	jr nc,L_43EE		;43e7
	add a,0c7h		;43e9
	call 0004dh		;43eb   ; BIOS WRTVRM - Writes data in VRAM
L_43EE:
	scf			;43ee   ; acarreo puesto: "sigo en marcha", lo leen dibuja_titulo_y_texto_ya y la espera natural de la tarea 0
	ret			;43ef
cierra_aviso_titulo:		; Cuando el contador de revelado llega a 22: dibuja un guion mas (SUPOSICION: probablemente el marco/cursor de seleccion, sin confirmar) y quita el acarreo para que quien llama sepa que ya termino
	ld de,047c1h		;43f0   ; dibuja el guion de 0x47c1
	call L_4055		;43f3
	ld de,04abch		;43f6   ; otro guion mas, con su propia direccion y repeticion (L_65af, sin explorar esta tanda)
	ld hl,03892h		;43f9
	ld bc,00306h		;43fc
	call dibuja_rectangulo_vram		;43ff
	xor a			;4402   ; A=0: sin acarreo, el aviso ha terminado
	ret			;4403
L_4404:
	call dibuja_numero_de_sala		;4404
L_4407:
	ld de,047aah		;4407
	call L_4055		;440a
	call dibuja_contador_de_rondas		;440d
	jr L_446B		;4410
suma_al_marcador:		; Suma DE al marcador de seis cifras en BCD (0xE049-0xE04B), da vida extra al pasar el umbral de 0xE052 y actualiza el record de 0xE043-0xE045 si el marcador lo supera. Solo cuenta con el bit 6 de 0xe002 puesto
	ld a,(0e002h)		;4412   ; (0xe002): sin el bit 6, la puntuacion no cuenta
	add a,a			;4415
	ret p			;4416
	ld hl,0e049h		;4417   ; HL = 0xE049, el marcador
	ld a,(hl)			;441a
	add a,e			;441b   ; las dos cifras bajas, mas E
	daa			;441c   ; daa: la suma es en BCD, no en binario
	ld (hl),a			;441d
	ld e,a			;441e
	inc l			;441f
	ld a,(hl)			;4420   ; las dos cifras del medio, con el acarreo y D
	adc a,d			;4421
	daa			;4422   ; daa otra vez
	ld (hl),a			;4423
	ld d,a			;4424
	inc hl			;4425
	jr nc,actualiza_el_record		;4426   ; sin desbordar, no hay vida extra que revisar
	ld a,(hl)			;4428
	add a,001h		;4429   ; las dos cifras altas suben una
	daa			;442b   ; y su daa
	ld (hl),a			;442c
	jr nc,revisa_vida_extra		;442d
	ld bc,09999h		;442f
	ld (0e043h),bc		;4432
	ld (0e044h),bc		;4436
	jr L_446B		;443a
revisa_vida_extra:		; El marcador ha pasado de las cuatro cifras: si supera el umbral de 0xE052, sube el umbral 2 en BCD (topado en 0xFF) y da una ronda mas
	ld a,(0e052h)		;443c   ; A = (0xE052), el umbral de la proxima vida extra
	cp (hl)			;443f   ; contra las cifras altas del marcador
	jr nc,actualiza_el_record		;4440   ; sin llegar, nada
	push de			;4442
	push hl			;4443
	add a,002h		;4444   ; el umbral sube 2, en BCD
	daa			;4446
	jr nc,L_444B		;4447
	ld a,0ffh		;4449   ; al desbordar se queda en 0xFF: no habra mas vidas extra
L_444B:
	ld (0e052h),a		;444b   ; guardado
	call avanza_ronda		;444e   ; y una ronda mas
	pop hl			;4451
	pop de			;4452
actualiza_el_record:		; Compara el marcador con el record de 0xE043-0xE045 y, si lo supera, lo copia y lo repinta; en cualquier caso repinta el marcador
	ld a,(0e045h)		;4453   ; A = las cifras altas del record
	ld b,(hl)			;4456   ; B = las del marcador
	sub b			;4457   ; la resta: quien es mayor
	jr c,guarda_el_record		;4458   ; el marcador gana: nuevo record
	jr nz,repinta_el_marcador		;445a   ; el record gana: solo repinta el marcador
	ld hl,(0e043h)		;445c   ; las cuatro cifras bajas del record
	sbc hl,de		;445f   ; contra las del marcador
	jr nc,repinta_el_marcador		;4461   ; el record sigue ganando
guarda_el_record:		; Copia el marcador al record y lo repinta en VRAM 0x3811
	ld (0e043h),de		;4463   ; las cuatro cifras bajas
	ld a,b			;4467
	ld (0e045h),a		;4468   ; y las dos altas
L_446B:
	ld de,0e045h		;446b   ; DE = 0xE045, el record
	ld hl,03811h		;446e   ; HL = VRAM 0x3811, donde va el record
	call L_447A		;4471
repinta_el_marcador:		; Repinta las tres cifras del marcador en VRAM 0x3807
	ld hl,03807h		;4474   ; HL = VRAM 0x3807, donde va el marcador
	ld de,0e04bh		;4477   ; DE = 0xE04B, las cifras altas del marcador
L_447A:
	ld b,003h		;447a
L_447C:
	ld a,(de)			;447c
L_447D:
	push bc			;447d
	call parte_en_dos_nibbles		;447e
	ld a,b			;4481
	add a,010h		;4482
	call 0004dh		;4484   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;4487
	ld a,c			;4488
	add a,010h		;4489
	call 0004dh		;448b   ; BIOS WRTVRM - Writes data in VRAM
	dec de			;448e
	inc hl			;448f
	pop bc			;4490
	djnz L_447C		;4491
	ret			;4493
parte_en_dos_nibbles:		; Devuelve en B el nibble alto de A y en C el bajo, sin tocar A
	push af			;4494   ; guarda A: el llamador lo necesita entero
	rra			;4495   ; cuatro rra: el nibble alto baja
	rra			;4496
	rra			;4497
	rra			;4498
	and 00fh		;4499   ; B = el nibble alto
	ld b,a			;449b
	pop af			;449c
	and 00fh		;449d   ; C = el nibble bajo
	ld c,a			;449f
	ret			;44a0
L_44A1:
	call aparca_sat		;44a1
	ld hl,07800h		;44a4
	ld bc,00300h		;44a7
	xor a			;44aa
rellena_vram:		; Arma VRAM en HL (prepara_escritura_vdp) y escribe A en el puerto de datos BC veces seguidas: relleno solido de un valor
	call prepara_escritura_vdp		;44ab   ; arma el puntero VRAM
L_44AE:
	ex af,af'			;44ae
L_44AF:
	ex af,af'			;44af   ; exx+ex af,af': entra al juego de registros que trae el C de prepara_escritura_vdp, sin perder el BC/A del llamador
	exx			;44b0
	out (c),a		;44b1   ; out (c),a: escribe el byte de relleno; el VDP autoincrementa la VRAM tras SETWRT
	exx			;44b3
	ex af,af'			;44b4
	dec bc			;44b5   ; BC cuenta lo que falta
	ld a,b			;44b6
	or c			;44b7
	jr nz,L_44AF		;44b8   ; repite hasta BC=0
	ex af,af'			;44ba
	ret			;44bb
relleno_de_guion:		; Variante de rellena_vram para el interprete: el valor a repetir se lee del propio guion en vez de venir en A
	ld a,(de)			;44bc   ; A = el byte de relleno, tomado de (DE)
	inc de			;44bd   ; avanza el guion un byte
	jr L_44AE		;44be
copia_guion_a_vram:		; Arma VRAM en HL y copia BC bytes de (DE) tal cual, sin repetir: la otra mitad del lenguaje de guiones
	call prepara_escritura_vdp		;44c0
L_44C3:
	ld a,(de)			;44c3   ; A = byte crudo del guion
	exx			;44c4
	out (c),a		;44c5   ; lo escribe en VRAM
	exx			;44c7
	inc de			;44c8   ; avanza el guion
	dec bc			;44c9   ; BC cuenta lo que falta
	ld a,b			;44ca
	or c			;44cb
	jr nz,L_44C3		;44cc   ; repite hasta BC=0
	ret			;44ce
rellena_franja_borde:		; Dibuja un guion mas del grupo del logo (0x467d) y rellena una franja de la pantalla con 0xf0: SUPOSICION, probablemente el color de fondo alrededor del logo, sin confirmar en caliente
	ld de,0467dh		;44cf   ; dibuja el guion 0x467d
	ld hl,02080h		;44d2
	call dibuja_guion_x3_tercios		;44d5
	ld a,0f0h		;44d8   ; remata con un relleno solido de los tres tercios (rellena_x3_tercios)
	ld hl,00080h		;44da
	ld bc,00180h		;44dd
rellena_x3_tercios:		; Como dibuja_guion_x3_tercios pero con rellena_vram directo (A/HL/BC ya puestos por el llamador) en vez de leer un guion
	ld d,003h		;44e0   ; D=3 tercios
L_44E2:
	push bc			;44e2
	push de			;44e3
	call rellena_vram		;44e4   ; rellena este tercio
	ld de,00800h		;44e7
	add hl,de			;44ea   ; el siguiente, 0x800 mas arriba
	pop de			;44eb
	pop bc			;44ec
	dec d			;44ed
	jr nz,L_44E2		;44ee   ; repite los tres
	ret			;44f0
dibuja_guion_x3_tercios:		; Ejecuta el mismo guion TRES veces, subiendo VRAM +0x800 cada vez: pinta el mismo dibujo en los tres tercios de SCREEN 2
	ld b,003h		;44f1   ; B=3 tercios
L_44F3:
	push bc			;44f3
	push de			;44f4
	call dibuja_guion		;44f5   ; dibuja este tercio completo
	ld de,00800h		;44f8
	add hl,de			;44fb   ; el siguiente tercio, 0x800 mas arriba en VRAM
	pop de			;44fc
	pop bc			;44fd
	djnz L_44F3		;44fe   ; repite los tres
	ret			;4500

; ----------------------------------------------------------------------
; DATOS codigo_muerto_4501: Diecinueve bytes que decodifican como codigo
;   valido (exx / ld b,3 / exx / push bc / push de / call 0x44c0 / ld
;   de,0x0800 / add hl,de / pop de / pop bc / exx / djnz / ret): otra variante
;   de dibujar un guion en los tres tercios, esta con el contador en el juego
;   de registros alterno. NADIE la llama: el par de bytes 01 45 no aparece en
;   ninguna parte de los 16 KB del cartucho, comprobado byte a byte. Codigo
;   muerto
;   0x4501..0x4514  (19 bytes)
DATA_codigo_muerto_4501:
	defb 0d9h,006h,003h,0d9h,0c5h,0d5h,0cdh,0c0h,044h,011h,000h,008h,019h,0d1h,0c1h,0d9h,010h,0f1h,0c9h	; 4501  ........D..........

; ======================================================================
; CODIGO 0x4514..0x4542  (46 bytes)
; ======================================================================


dibuja_guion_con_direccion:		; Variante de dibuja_guion que primero lee dos bytes de (DE) como direccion VRAM inicial (el formato "CON direccion" de las notas de guion_xxx), en vez de recibir HL ya puesto
	ex de,hl			;4514   ; HL := DE, la direccion donde esta el puntero a leer
	ld e,(hl)			;4515   ; E = byte bajo del puntero
	inc hl			;4516
	ld d,(hl)			;4517   ; D = byte alto: DE = el puntero, la direccion VRAM real
	ex de,hl			;4518   ; HL := el puntero (destino VRAM); DE := direccion del puntero + 1
	inc de			;4519   ; DE avanza al primer byte del guion, justo detras del puntero de 16 bits
dibuja_guion:		; El interprete de guiones: arma VRAM en HL y ejecuta comandos de (DE) hasta un 0x00 final (lenguaje documentado arriba: bit 7 puesto = copia cruda, bit 7 a cero = relleno, 0x80 exacto = encadena a OTRO guion via un puntero nuevo)
	call prepara_escritura_vdp		;451a   ; arma VRAM en HL para este tramo
L_451D:
	ld a,(de)			;451d   ; C = B0 & 0x7f: la cuenta, sin el bit de modo
	and 07fh		;451e
	ld c,a			;4520
	ld a,(de)			;4521   ; vuelve a leer el mismo byte crudo en A, para distinguir 0x00 de 0x80 mas abajo
	inc de			;4522
	jr nz,despacha_comando_guion		;4523   ; si la cuenta enmascarada no es 0 hay un comando de verdad: al despachador
	cp c			;4525   ; compara el B0 crudo con 0 (C): solo son iguales si B0 era exactamente 0x00
	jr nz,dibuja_guion_con_direccion		;4526   ; si no eran iguales, B0 era 0x80: encadena releyendo un puntero nuevo (otro guion)
	ret			;4528   ; iguales de verdad (B0=0x00): fin del guion
despacha_comando_guion:		; Decide relleno o copia cruda segun el bit 7 de B0, con la cuenta ya en C
	ld b,000h		;4529
	cp c			;452b   ; compara el B0 crudo con la cuenta enmascarada: iguales -> el bit 7 estaba a 0 (relleno); distintos -> estaba a 1 (copia cruda)
	push af			;452c
	call nz,L_44C3		;452d   ; bit 7 a 1: copia cruda de (B0&0x7f) bytes
	pop af			;4530
	call z,relleno_de_guion		;4531   ; bit 7 a 0: relleno, lee un byte mas y lo repite (B0&0x7f) veces
	jr L_451D		;4534   ; vuelve a leer el siguiente comando
prepara_escritura_vdp:		; SETWRT(HL) por BIOS y deja en C el puerto de datos del VDP (variable de sistema en 0x0006, mismo truco que en el resto de la serie), todo con el AF y BC alternativos para no tocar los del llamador
	ex af,af'			;4536   ; cambia al AF alternativo: lo que se traiga en C no debe pisar el AF real del llamador
	call 00053h		;4537   ; BIOS SETWRT - Enables VDP to write | SETWRT (BIOS 0x0053): arma la VRAM en HL para escribir
	exx			;453a
	ld a,(00006h)		;453b   ; 0x0006 es la variable de sistema de la BIOS con el puerto de datos del VDP
	ld c,a			;453e
	exx			;453f   ; vuelve al AF y BC reales: C ya esta listo para 'out (c),a' sin que el llamador note nada
	ex af,af'			;4540
	ret			;4541

; ----------------------------------------------------------------------
; DATOS codigo_muerto_4542: Diez bytes que decodifican como la pareja de
;   prepara_escritura_vdp para LEER (call SETRD 0x0050 / exx / ld a,(0x0007) /
;   ld c,a / exx / ret; 0x0007 es la variable de la BIOS con el puerto de
;   LECTURA del VDP, igual que 0x0006 es el de escritura). NADIE la llama: el
;   par 42 45 no aparece en ninguna parte del cartucho. Codigo muerto: el
;   juego nunca lee de la VRAM
;   0x4542..0x454c  (10 bytes)
DATA_codigo_muerto_4542:
	defb 0cdh,050h,000h,0d9h,03ah,007h,000h,04fh,0d9h,0c9h	; 4542  .P..:..O..

; ======================================================================
; CODIGO 0x454c..0x45c0  (116 bytes)
; ======================================================================


voltea_sprites:		; Voltea C sprites de 16x16 en la VRAM. El espejo de un sprite de 16x16 no es solo invertir sus bytes: hay que INTERCAMBIAR ADEMAS sus dos mitades, y eso es lo que hace el baile de 0x4556-0x455c, que escribe 16 bytes, retrocede 16 (`sub 020h`) y repite mientras el bit 4 de E siga a cero. Por eso pasandole destino 0x1b10 el sprite acaba en 0x1b00
	push de			;454c
L_454D:
	ld b,010h		;454d
copia_fila_de_bloque:		; Una fila de voltea_sprites: 16 bytes, y luego el retroceso de 16 que salta a la otra mitad del sprite
	call voltea_una_celda_de_vram		;454f   ; un byte, volteado
	inc hl			;4552
	inc e			;4553   ; la columna siguiente
	djnz copia_fila_de_bloque		;4554
	ld a,e			;4556
	sub 020h		;4557   ; el salto de fila: 0x20 hacia atras
	ld e,a			;4559
	bit 4,e		;455a   ; bit 4 de E: decide si sigue en el mismo tercio
	jr z,L_454D		;455c
	pop de			;455e
	ld a,020h		;455f
	call suma_a_de		;4561   ; el destino avanza 0x20
	dec c			;4564   ; y una fila menos
	jr nz,voltea_sprites		;4565
	ret			;4567
voltea_patrones:		; Voltea C patrones de 8 bytes en los TRES tercios de la tabla. OJO con el `pop hl` de 0x457f: recupera el origen ORIGINAL, no el avanzado, asi que los tres tercios se leen todos del PRIMERO. Sale bien de milagro, porque el cartucho escribe los tres tercios iguales
	ld b,003h		;4568
L_456A:
	push bc			;456a
	push hl			;456b
	push de			;456c
L_456D:
	ld b,008h		;456d
copia_celda_del_bloque:		; Un byte de voltea_patrones: origen y destino avanzan a la vez
	call voltea_una_celda_de_vram		;456f   ; un byte, volteado
	inc hl			;4572
	inc de			;4573
	djnz copia_celda_del_bloque		;4574   ; hasta acabar la fila
	dec c			;4576   ; y una fila menos
	jr nz,L_456D		;4577
	pop hl			;4579
	ld de,00800h		;457a   ; 0x800: el tercio siguiente de la tabla de patrones
	add hl,de			;457d
	ex de,hl			;457e
	pop hl			;457f
	pop bc			;4580
	djnz L_456A		;4581
	ret			;4583
invierte_los_bits:		; Da la vuelta a los ocho bits de A: ocho `rr c` que sacan el bit bajo y ocho `rla` que lo meten por arriba. Es el espejo horizontal de una fila de 8 pixeles
	push bc			;4584
	ld c,a			;4585
	ld b,008h		;4586
L_4588:
	rr c		;4588
	rla			;458a
	djnz L_4588		;458b
	pop bc			;458d
	ret			;458e
voltea_una_celda_de_vram:		; Lee un byte de VRAM (RDVRM), le da la vuelta con invierte_los_bits y lo escribe en la direccion de DE (WRTVRM), dejando HL y DE como estaban
	call 0004ah		;458f   ; BIOS RDVRM - Reads the content of VRAM
	call invierte_los_bits		;4592
	ex de,hl			;4595
	call 0004dh		;4596   ; BIOS WRTVRM - Writes data in VRAM
	ex de,hl			;4599
	ret			;459a
prepara_pantalla:		; Silencia el mezclador del PSG (0xb8: los tres tonos sin ruido, el mismo valor que conmuta_ruido_canal_c usa en juego), toca un efecto y borra los 16 KB completos de VRAM antes de cargar los registros VDP
	ld a,0b8h		;459b   ; 0xb8 al mezclador del PSG: tonos ABC sin ruido, igual que en juego
	call L_7B2E		;459d
	ld a,020h		;45a0
	call reproduce_efecto		;45a2   ; efecto 0x20 -SUPOSICION: probablemente silencio/reset del reproductor antes de arrancar, no confirmado en caliente-
	ld de,00000h		;45a5
	ld bc,04000h		;45a8
	xor a			;45ab
	call L_409C		;45ac   ; DE=0, BC=0x4000, A=0: borra los 16 KB completos de VRAM desde la direccion 0
carga_registros_vdp:		; Programa los registros R0-R7 del VDP, uno a uno via BIOS WRTVDP, desde la tabla de 8 bytes en 0x45c0
	ld hl,045c0h		;45af   ; HL=tabla de 8 bytes (un valor por registro), D=8 registros por escribir
	ld d,008h		;45b2
	ld c,000h		;45b4
L_45B6:
	ld b,(hl)			;45b6
	call 00047h		;45b7   ; BIOS WRTVDP - Writes data in the VDP-register | WRTVDP: B=valor, C=numero de registro (0-7 correlativo)
	inc hl			;45ba
	inc c			;45bb
	dec d			;45bc
	jr nz,L_45B6		;45bd
	ret			;45bf

; ----------------------------------------------------------------------
; DATOS tabla_registros_vdp: 8 bytes: valores crudos de R0 a R7 que programa
;   carga_registros_vdp; no desglosados bit a bit en esta tanda
;   0x45c0..0x45c8  (8 bytes)
DATA_tabla_registros_vdp:
	defb 002h,0e2h,00eh,07fh,007h,076h,003h,0e4h	; 45c0  .....v..

; ======================================================================
; CODIGO 0x45c8..0x467d  (181 bytes)
; ======================================================================


lee_entrada_del_jugador:		; Lee la entrada del fotograma: en la tarea 5 sin el modo especial la saca del guion de la demo (0x4621), y en el resto del teclado y el joystick (0x45e8)
	ld hl,0e002h		;45c8   ; HL = 0xe002
	bit 6,(hl)		;45cb   ; bit 6: el modo especial
	jr nz,L_45DB		;45cd
	ld a,(0e000h)		;45cf   ; A = la tarea activa
	cp 005h		;45d2   ; solo la tarea 5 usa el guion de la demo
	jr nz,L_45DB		;45d4
entrada_desde_el_guion:		; Toma la entrada del guion de la demo en vez del mando
	call guion_de_la_demo		;45d6   ; el guion de la demo
	jr L_45DE		;45d9
L_45DB:
	call L_45E8		;45db   ; en los demas casos, teclado y joystick
L_45DE:
	ld hl,0e009h		;45de   ; HL = 0xe009, donde vive la entrada del fotograma
guarda_entrada_y_flanco:		; Guarda A en (HL) y deja en (HL-1) solo los bits RECIEN pulsados: los que estan en A y no estaban en la muestra anterior
	ld c,(hl)			;45e1   ; C = la muestra anterior
	ld (hl),a			;45e2   ; guarda la muestra nueva
	xor c			;45e3   ; los bits que han cambiado
	and (hl)			;45e4   ; y de esos, solo los que estan puestos ahora: el flanco de subida
	dec hl			;45e5
	ld (hl),a			;45e6   ; guardado en el byte anterior
	ret			;45e7
L_45E8:
	ld e,08fh		;45e8
	ld a,00fh		;45ea
	call 00093h		;45ec   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,00eh		;45ef
	di			;45f1
	call 00096h		;45f2   ; BIOS RDPSG - Reads value from PSG-register
	ei			;45f5
	cpl			;45f6
	and 03fh		;45f7
	push af			;45f9
	ld a,007h		;45fa
	call 00141h		;45fc   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;45ff
	rrca			;4600
	and 020h		;4601
	ld e,a			;4603
	ld a,008h		;4604
	call 00141h		;4606   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;4609
	rrca			;460a
	rrca			;460b
	ld b,a			;460c
	and 004h		;460d
	or e			;460f
	ld c,a			;4610
	ld a,b			;4611
	rrca			;4612
	rrca			;4613
	ld b,a			;4614
	and 018h		;4615
	or c			;4617
	ld c,a			;4618
	ld a,b			;4619
	rrca			;461a
	and 003h		;461b
	or c			;461d
	pop bc			;461e
	or b			;461f
	ret			;4620
guion_de_la_demo:		; Lee el paso siguiente del guion de la demo: (0xE080) apunta al guion y (0xE082) cuenta lo que le queda al paso actual; el valor 0xFF acaba la demo poniendo 0xE053 a cero
	ld hl,0e082h		;4621   ; HL = 0xE082, lo que queda del paso actual
	dec (hl)			;4624   ; baja uno
	ld b,(hl)			;4625   ; B = lo que queda
	ld hl,(0e080h)		;4626   ; HL = (0xE080), el guion
	ld a,(hl)			;4629   ; A = la entrada de este paso
	push af			;462a
	ld a,b			;462b
	or a			;462c   ; todavia queda paso: se repite la misma entrada
	jr nz,L_4642		;462d
	inc hl			;462f
	ld a,(hl)			;4630   ; A = la duracion del paso siguiente
	cp 0ffh		;4631   ; 0xFF acaba el guion
	jr nz,L_463B		;4633
	xor a			;4635
	ld (0e053h),a		;4636   ; (0xE053) := 0: se acabo la demo
	jr L_4642		;4639
L_463B:
	ld (0e082h),a		;463b   ; la duracion nueva
	inc hl			;463e
	ld (0e080h),hl		;463f   ; y el guion avanza
L_4642:
	pop af			;4642
	ret			;4643
revisa_teclado_y_salta_menu:		; Se cuela cada fotograma mientras 0xe002 bit 6 siga a 0: revisa si hay alguna tecla recien pulsada y, si la hay, salta a mano el logo/el aviso de titulo en vez de esperar a que la cascada de fotogramas de la tarea 0/1 termine sola. Verificado en caliente (tools/omsx_task_trace.tcl): las unicas transiciones 0->1 y 1->3 de 90 s de menu+demo tienen el PC en 0x4663 y 0x4679, dentro de esta rutina
	call proteccion_anticopia_tarea_1		;4644   ; primero, la proteccion anticopia de 0x403e: desde ROM no hace nada, desde RAM machaca la tarea 1
	ld hl,0e041h		;4647   ; HL=0xe041: la muestra de teclado guardada la vez anterior
	call guarda_entrada_y_flanco		;464a   ; compara la muestra nueva (A -SUPOSICION: se asume dejada por el codigo de mas arriba en el mismo fotograma, no se ha confirmado quien la deja-) con la guardada y devuelve solo los bits recien pulsados (flanco de subida)
	or a			;464d   ; sin ninguna tecla nueva, no hay nada que forzar
	ret z			;464e
	push af			;464f
	ld a,020h		;4650   ; pitido de "tecla pulsada" (reproduce_efecto)
	call reproduce_efecto		;4652
	pop af			;4655
	ld b,a			;4656   ; B guarda los bits recien pulsados para el segundo tramo (fuerza_tarea_3_si_hay_input)
	xor a			;4657
	ld (0e004h),a		;4658   ; arranca a cero el contador de fotogramas de la tarea de titulo
	ld a,001h		;465b
	ld hl,0e000h		;465d
	cp (hl)			;4660   ; si la tarea activa YA es la 1, no hace falta forzar nada aqui: al segundo tramo
	jr z,fuerza_tarea_3_si_hay_input		;4661
	ld (hl),a			;4663   ; fuerza la tarea a 1 (titulo): CUALQUIER tecla salta el logo de Konami; verificado en caliente, PC=0x4663 en la transicion 0->1
	call L_44A1		;4664   ; limpia la franja de VRAM que ocupaba el logo (rellena_vram)
	call pon_registro_vdp_7		;4667   ; registro 7 del VDP: color de borde para la pantalla de titulo
	jp dibuja_titulo_y_texto_ya		;466a   ; dibuja el titulo "King's Valley" y revela el texto de aviso entero de un tiron (dibuja_titulo_y_texto_ya), no fotograma a fotograma como en la espera natural
fuerza_tarea_3_si_hay_input:		; Segundo tramo de revisa_teclado_y_salta_menu: si la tecla recien pulsada trae alguno de los bits 4-5 (SUPOSICION: probablemente SPACE, el "PUSH SPACE KEY" en pantalla, sin confirmar bit a bit con SNSMAT), arranca la partida/demo de verdad
	ld a,b			;466d   ; recupera los bits recien pulsados guardados en B
	and 030h		;466e   ; se queda solo con los bits 4 y 5
	ret z			;4670   ; ninguno de los dos puesto: nada que forzar todavia
	ld hl,0e002h		;4671
	set 6,(hl)		;4674   ; pone a 1 el bit 6 de 0xe002: el "modo especial" que hace que avanza_un_cuadro deje de llamar a revisa_teclado_y_salta_menu cada fotograma
	ld hl,00003h		;4676
	ld (0e000h),hl		;4679   ; fuerza la tarea a 3 directamente (se salta la 2, que en el camino natural se reenvia sola a la 4): verificado en caliente, PC=0x4679 en la unica transicion 1->3 observada
	ret			;467c

; ----------------------------------------------------------------------
; DATOS guion_467d: Guion para L_451a, cargado por L_44cf (parte del grupo de
;   L_42cc)
;   0x467d..0x47a7  (298 bytes)
DATA_guion_467d:
	defb 08bh,000h,01ch,022h,063h,063h,063h,022h,01ch,000h,018h,038h,004h,018h,0ceh,07eh	; 467d  ..."ccc"...8...~
	defb 000h,03eh,063h,003h,00eh,03ch,070h,07fh,000h,03eh,063h,003h,00eh,003h,063h,03eh	; 468d  .>c..<p..>c...c>
	defb 000h,00eh,01eh,036h,066h,066h,07fh,006h,000h,07fh,060h,07eh,063h,003h,063h,03eh	; 469d  ...6ff....`~c.c>
	defb 000h,03eh,063h,060h,07eh,063h,063h,03eh,000h,07fh,063h,006h,00ch,018h,018h,018h	; 46ad  .>c`~cc>..c.....
	defb 000h,03eh,063h,063h,03eh,063h,063h,03eh,000h,03eh,063h,063h,03fh,003h,063h,03eh	; 46bd  .>cc>cc>.>cc?.c>
	defb 03ch,042h,099h,0a1h,0a1h,099h,042h,03ch,018h,03ch,018h,008h,010h,027h,000h,001h	; 46cd  <B....B<.<...'..
	defb 07eh,004h,000h,0c1h,01ch,036h,063h,063h,07fh,063h,063h,000h,07eh,063h,063h,07eh	; 46dd  ~....6cc.cc.~cc~
	defb 063h,063h,07eh,000h,03eh,063h,060h,060h,060h,063h,03eh,000h,07ch,066h,063h,063h	; 46ed  cc~.>c```c>.|fcc
	defb 063h,066h,07ch,000h,07fh,060h,060h,07eh,060h,060h,07fh,000h,07fh,060h,060h,07eh	; 46fd  cf|..``~``...``~
	defb 060h,060h,060h,000h,03eh,063h,060h,067h,063h,063h,03fh,000h,063h,063h,063h,07fh	; 470d  ```.>c`gcc?.ccc.
	defb 063h,063h,063h,000h,03ch,005h,018h,083h,03ch,000h,01fh,004h,006h,08bh,066h,03ch	; 471d  ccc.<...<.....f<
	defb 000h,063h,066h,06ch,078h,07ch,06eh,067h,000h,006h,060h,093h,07fh,000h,063h,077h	; 472d  .cflx|ng..`...cw
	defb 07fh,07fh,06bh,063h,063h,000h,063h,073h,07bh,07fh,06fh,067h,063h,000h,03eh,005h	; 473d  ..kcc.cs{.ogc.>.
	defb 063h,0a3h,03eh,000h,07eh,063h,063h,063h,07eh,060h,060h,000h,03eh,063h,063h,063h	; 474d  c.>.~ccc~``.>ccc
	defb 06fh,066h,03dh,000h,07eh,063h,063h,062h,07ch,066h,063h,000h,03eh,063h,060h,03eh	; 475d  of=.~ccb|fc.>c`>
	defb 003h,063h,03eh,000h,07eh,006h,018h,001h,000h,006h,063h,082h,03eh,000h,004h,063h	; 476d  .c>.~.....c.>..c
	defb 0a4h,036h,01ch,008h,000h,063h,063h,06bh,06bh,07fh,077h,022h,000h,063h,076h,03ch	; 477d  .6...cckk.w".cv<
	defb 01ch,01eh,037h,063h,000h,066h,066h,07eh,03ch,018h,018h,018h,000h,07fh,007h,00eh	; 478d  ..7c.ff~<.......
	defb 01ch,038h,070h,07fh,000h,003h,024h,004h,000h,000h	; 479d  .8p...$...

; ----------------------------------------------------------------------
; DATOS guion_47a7: Guion para L_451a, cargado por L_42cc en 0x42d5
;   0x47a7..0x47aa  (3 bytes)
DATA_guion_47a7:
	defb 008h,0ffh,000h	; 47a7

; ----------------------------------------------------------------------
; DATOS guion_texto_marcadores: Guion de texto (ASCII-0x20) con los tres
;   rotulos fijos de la pantalla de juego: "REST " en VRAM 0x3818, "SCORE " en
;   0x3801 y "HI " en 0x380E. Lo dibuja 0x4407
;   0x47aa..0x47c1  (23 bytes)
DATA_guion_texto_marcadores:
	defb 018h,038h,032h,025h,033h,034h,020h,0feh,001h,038h,033h,023h,02fh,032h,025h,020h,0feh,00eh,038h,028h,029h,020h,0ffh	; 47aa  .82%34 ..83#/2% ..8() .

; ----------------------------------------------------------------------
; DATOS guion_texto_titulo: Guion de texto: el (c)KONAMI 1985 en VRAM 0x39AA y
;   el "PUSH SPACE KEY" en 0x3A49. Lo dibuja cierra_aviso_titulo (0x43f0)
;   0x47c1..0x47e1  (32 bytes)
DATA_guion_texto_titulo:
	defb 0aah,039h,01ah,02bh,02fh,02eh,021h,02dh,029h,000h,011h,019h,018h,015h,0feh,049h,03ah,030h,035h,033h,028h,000h,033h,030h,021h,023h,025h,000h,02bh,025h,039h,0ffh	; 47c1  .9.+/.!-)......I:053(.30!#%.+%9.

; ----------------------------------------------------------------------
; DATOS guion_texto_play_start: Guion de texto: "  PLAY START  " en VRAM
;   0x3A49, el mismo sitio que ocupaba PUSH SPACE KEY. Lo dibuja la tarea 3
;   (0x42a9)
;   0x47e1..0x47f2  (17 bytes)
DATA_guion_texto_play_start:
	defb 049h,03ah,000h,000h,030h,02ch,021h,039h,000h,033h,034h,021h,032h,034h,000h,000h,0ffh	; 47e1  I:..0,!9.34!24...

; ----------------------------------------------------------------------
; DATOS guion_texto_game_over: Guion de texto: "GAME OVER" en VRAM 0x396B. Lo
;   dibuja tarea_6_decide_repetir (0x4226)
;   0x47f2..0x47fe  (12 bytes)
DATA_guion_texto_game_over:
	defb 06bh,039h,027h,021h,02dh,025h,000h,02fh,036h,025h,032h,0ffh	; 47f2  k9'!-%./6%2.

; ----------------------------------------------------------------------
; DATOS guion_texto_software: Guion de texto en VRAM 0x394A: cinco bytes de
;   dibujo y luego "SOFTWARE ". El llamador no se ha identificado en esta
;   pasada
;   0x47fe..0x480e  (16 bytes)
DATA_guion_texto_software:
	defb 04ah,039h,00ch,07ah,016h,000h,088h,033h,02fh,026h,034h,037h,021h,032h,025h,000h	; 47fe  J9.z...3/&47!2%.

; ----------------------------------------------------------------------
; DATOS guion_texto_pyramid: Guion de texto: el (c)KONAMI en VRAM 0x3AE1 y
;   "PYRAMID " en 0x3AEB, justo delante del numero de sala que escribe
;   dibuja_numero_de_sala (0x436b), que es quien lo dibuja
;   0x480e..0x4823  (21 bytes)
DATA_guion_texto_pyramid:
	defb 0e1h,03ah,01ah,02bh,02fh,02eh,021h,02dh,029h,0feh,0ebh,03ah,030h,039h,032h,021h,02dh,029h,024h,020h,0ffh	; 480e  .:.+/.!-)..:092!-)$ .

; ======================================================================
; CODIGO 0x4823..0x4874  (81 bytes)
; ======================================================================


prepara_scroll_del_logo:		; Arma el scroll del logo de Konami: cuenta 0xe00a=14 pasos, deja el puntero de patron inicial en 0xe00e, dibuja el patron grafico del logo (guion_dibujo_4874) en la tabla de patrones y rellena una franja con 0xf0
	ld a,00eh		;4823   ; 0xe00a=14: cuantos pasos de scroll le quedan a tarea_0_desplaza_logo
	ld (0e00ah),a		;4825
	ld hl,03aaah		;4828   ; 0xe00e: el puntero de patron de partida (lo mueve tarea_0_desplaza_logo)
	ld (0e00eh),hl		;482b
	ld de,04874h		;482e
	ld hl,06300h		;4831   ; dibuja el patron del logo en la tabla de patrones (VRAM 0x6300)
	call dibuja_guion_x3_tercios		;4834
	ld hl,00300h		;4837
	ld bc,000d8h		;483a
	ld a,0f0h		;483d
	jp rellena_x3_tercios		;483f   ; remata con un relleno solido de los tres tercios (rellena_x3_tercios)
tarea_0_desplaza_logo:		; Un paso del scroll del logo: sube el puntero de patron 0xe00e en 32 (una fila) y escribe una franja de indices de patron nuevos en su lugar
	ld hl,(0e00eh)		;4842   ; HL = puntero de patron actual (0xe00e)
	ld de,0ffe0h		;4845   ; -32: sube una fila (el patron "entra" por abajo)
	add hl,de			;4848
	ld (0e00eh),hl		;4849   ; guarda el nuevo puntero para el siguiente paso
	ld a,060h		;484c   ; primera franja: 3 indices de patron desde 0x60
	ld b,003h		;484e
	call escribe_franja_de_patrones		;4850   ; escribe_franja_de_patrones
	ld bc,00b0ch		;4853   ; segunda franja: 11 indices mas, siguiendo la cuenta
	call escribe_franja_de_patrones		;4856
	ld b,c			;4859   ; tercera franja: los que queden (C, de la carga anterior)
	call escribe_franja_de_patrones		;485a
	xor a			;485d
	call rellena_vram		;485e   ; SUPOSICION: limpia algo con relleno de 0 a partir de aqui, la cuenta BC que le llega no se ha verificado
	ld hl,0e00ah		;4861
	dec (hl)			;4864   ; cuenta atras el contador de revelado (0xe00a): cuando llegue a 0, tarea_0_logo_konami da el scroll por terminado
	ret			;4865
escribe_franja_de_patrones:		; Escribe B indices de patron consecutivos (empezando en A) en B celdas VRAM consecutivas desde HL, y devuelve HL+0x20 (la fila siguiente) para encadenar otra franja
	push hl			;4866   ; guarda el HL de entrada para calcular la fila siguiente al final
L_4867:
	call 0004dh		;4867   ; BIOS WRTVRM - Writes data in VRAM | escribe el indice actual
	inc hl			;486a   ; siguiente celda VRAM
	inc a			;486b   ; siguiente indice de patron
	djnz L_4867		;486c   ; repite las B celdas de esta franja
	pop de			;486e
	ld hl,00020h		;486f   ; la fila siguiente: 0x20 mas que el HL de entrada
	add hl,de			;4872
	ret			;4873

; ----------------------------------------------------------------------
; DATOS guion_dibujo_4874: Guion para L_451a, cargado por L_4823 (parte del
;   grupo de L_42cc)
;   0x4874..0x490b  (151 bytes)
DATA_guion_dibujo_4874:
	defb 00fh,000h,001h,001h,006h,000h,082h,0ffh,0feh,008h,00fh,084h,0c3h,0c7h,0cfh,0dfh	; 4874  ................
	defb 003h,0ffh,089h,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,007h,007h,005h,000h,083h,003h	; 4884  ................
	defb 0cfh,0dfh,005h,000h,083h,0e1h,0f9h,07dh,005h,000h,083h,0efh,0ffh,0f7h,005h,000h	; 4894  .......}........
	defb 083h,007h,08fh,09eh,005h,000h,083h,0f0h,0f8h,078h,005h,000h,083h,0f7h,0ffh,0fbh	; 48a4  .........x......
	defb 005h,000h,08bh,08fh,0dfh,0f7h,00ch,01eh,01eh,00ch,000h,01eh,09eh,09eh,008h,00fh	; 48b4  ................
	defb 090h,0ffh,0ffh,0dfh,0cfh,0c7h,0c3h,0c1h,0c0h,007h,087h,0c7h,0efh,0ffh,0ffh,0ffh	; 48c4  ................
	defb 0fch,004h,0deh,084h,09eh,09fh,00fh,003h,005h,03dh,083h,07dh,0f9h,0e1h,008h,0e3h	; 48d4  .........=.}....
	defb 090h,0dch,0c0h,0c7h,0deh,0dch,0deh,0cfh,0c3h,03ch,07ch,0fch,03ch,03ch,07ch,0fch	; 48e4  .........<|.<<|.
	defb 0deh,008h,0f1h,008h,0e3h,008h,0deh,088h,038h,044h,0bah,0aah,0b2h,0aah,044h,038h	; 48f4  ........8D....D8
	defb 003h,000h,001h,0ffh,004h,000h,000h	; 4904

; ----------------------------------------------------------------------
; DATOS guion_490b: Guion para L_451a, cargado por L_42cc en 0x42db
;   0x490b..0x4a97  (396 bytes)
DATA_guion_490b:
	defb 0ach,000h,003h,007h,000h,01fh,03fh,07fh,000h,000h,003h,007h,00fh,000h,000h,000h	; 490b  ......?.........
	defb 0ffh,000h,0ffh,0ffh,0ffh,000h,000h,001h,0ffh,001h,003h,001h,00eh,003h,03eh,007h	; 491b  ..............>.
	defb 0fch,00fh,0fch,0f8h,01fh,0f0h,0f0h,0e0h,03fh,07fh,0c0h,0c0h,080h,004h,0ffh,094h	; 492b  ........?.......
	defb 080h,0c0h,0e0h,000h,0f8h,000h,0feh,000h,0ffh,000h,000h,0ffh,000h,000h,000h,0ffh	; 493b  ................
	defb 080h,000h,000h,0f0h,003h,000h,002h,0ffh,003h,000h,004h,0ffh,08dh,080h,000h,000h	; 494b  ................
	defb 000h,0f8h,0fch,0feh,0ffh,03fh,06fh,037h,017h,00fh,009h,007h,097h,00fh,01fh,0c7h	; 495b  .....?o7........
	defb 083h,007h,00eh,03ch,0f8h,0f0h,07ch,01eh,01eh,00eh,00fh,00fh,00fh,08fh,0c7h,087h	; 496b  ...<..|.........
	defb 00fh,007h,000h,00fh,008h,007h,088h,087h,0efh,0cfh,000h,080h,000h,01fh,09eh,003h	; 497b  ................
	defb 00fh,006h,00eh,089h,08fh,09fh,000h,000h,000h,078h,0fch,0deh,08eh,007h,00eh,089h	; 498b  .........x......
	defb 01fh,0bfh,000h,000h,000h,00fh,01fh,038h,030h,004h,060h,08eh,070h,070h,03fh,01fh	; 499b  .......80.`.pp?.
	defb 00fh,000h,000h,000h,0f9h,0f3h,0f3h,071h,070h,071h,003h,070h,003h,0f0h,0adh,0e0h	; 49ab  .......qpq.p....
	defb 000h,000h,003h,08fh,0deh,0dfh,08fh,087h,001h,000h,038h,01ch,03eh,03fh,01fh,00fh	; 49bb  ..........8.>?..
	defb 000h,000h,0f0h,0fch,00eh,006h,0c0h,0f0h,0f8h,07ch,01ch,01eh,03eh,0feh,0fch,0f8h	; 49cb  .........|..>...
	defb 07fh,0f1h,07bh,011h,007h,01fh,007h,007h,003h,003h,001h,001h,004h,000h,0a9h,0c3h	; 49db  ..{.............
	defb 08fh,03bh,061h,001h,003h,003h,086h,086h,0cch,0d8h,0f8h,0f0h,0f0h,060h,060h,08fh	; 49eb  .;a..........``.
	defb 0dbh,0dfh,087h,08eh,00eh,01fh,01eh,038h,030h,030h,074h,07ch,07ch,03ch,018h,0feh	; 49fb  .......800t||<..
	defb 0f3h,077h,03eh,07ch,0fch,09eh,01eh,01eh,003h,00fh,003h,007h,083h,00fh,007h,003h	; 4a0b  .w>|............
	defb 009h,001h,086h,003h,087h,08ch,0cdh,0e7h,0e0h,006h,0c0h,003h,0c3h,088h,0e1h,0c0h	; 4a1b  ................
	defb 08eh,03fh,0ffh,0ffh,00fh,007h,008h,003h,087h,083h,087h,0cfh,0c8h,0cbh,08fh,0c0h	; 4a2b  .?..............
	defb 006h,080h,003h,086h,0aeh,0c3h,081h,01dh,07fh,0ffh,0ffh,03fh,01fh,00fh,00fh,00fh	; 4a3b  ...........?....
	defb 00eh,00dh,00dh,00eh,00fh,00fh,00fh,08fh,09fh,0bfh,01fh,0ffh,007h,01eh,038h,060h	; 4a4b  ..............8`
	defb 0c0h,018h,07ch,0cch,000h,000h,001h,083h,0ffh,0ffh,0feh,03fh,073h,02fh,00fh,007h	; 4a5b  ..|........?s/..
	defb 003h,001h,001h,004h,000h,08ch,080h,080h,001h,003h,08fh,07bh,003h,087h,0ceh,0dch	; 4a6b  ...........{....
	defb 0f8h,0f8h,006h,0f0h,085h,0f8h,0fch,080h,0c0h,080h,00eh,000h,084h,060h,070h,03fh	; 4a7b  .............`p?
	defb 03fh,003h,000h,085h,070h,070h,0f0h,0e0h,0c0h,003h,000h,000h	; 4a8b  ?...pp......

; ----------------------------------------------------------------------
; DATOS guion_4a97: Guion para L_451a, cargado por L_42cc en 0x42e4
;   0x4a97..0x4aab  (20 bytes)
DATA_guion_4a97:
	defb 01ch,0e0h,088h,0f0h,0e0h,0f0h,0e0h,0f0h,0e0h,0e0h,0f0h,003h,0e0h,002h,0f0h,003h	; 4a97  ................
	defb 0e0h,02ch,0f0h,000h	; 4aa7

; ----------------------------------------------------------------------
; DATOS guion_4aab: Guion para L_451a, cargado por L_42cc en 0x42f4 (x22, uno
;   por columna)
;   0x4aab..0x4abc  (17 bytes)
DATA_guion_4aab:
	defb 003h,060h,08dh,080h,080h,090h,090h,0a0h,0b0h,0e0h,030h,070h,050h,050h,040h,040h	; 4aab  .`........0pPP@@
	defb 000h	; 4abb

; ----------------------------------------------------------------------
; DATOS bloque_de_celdas_3x6: Las 18 celdas del rectangulo de 3 filas por 6
;   columnas que cierra_aviso_titulo dibuja en VRAM 0x3892 (0x43f6-0x43ff:
;   DE=0x4abc, HL=0x3892, BC=0x0306). Las medidas cuadran exactas: 3*6 = 18
;   bytes
;   0x4abc..0x4ace  (18 bytes)
DATA_bloque_de_celdas_3x6:
	defb 000h,000h,093h,096h,000h,000h	; 4abc
	defb 000h,090h,094h,097h,098h,000h	; 4ac2
	defb 091h,092h,095h,099h,099h,09ah	; 4ac8

; ----------------------------------------------------------------------
; DATOS guion_de_la_demo: El guion que pilota al jugador en la demo, en
;   parejas (entrada, duracion) y terminado en 0xFF. arranca_partida (0x412d)
;   lo carga en 0xE080 con la duracion inicial 8 en 0xE082, y guion_de_la_demo
;   (0x4621) lo va leyendo. Los valores de entrada son los mismos bits que
;   deja lee_entrada_del_jugador
;   0x4ace..0x4b0c  (62 bytes)
DATA_guion_de_la_demo:
	defb 008h,098h	; 4ace
	defb 006h,038h	; 4ad0
	defb 008h,068h	; 4ad2
	defb 005h,008h	; 4ad4
	defb 014h,080h	; 4ad6
	defb 004h,008h	; 4ad8
	defb 014h,048h	; 4ada
	defb 008h,048h	; 4adc
	defb 005h,030h	; 4ade
	defb 008h,040h	; 4ae0
	defb 005h,030h	; 4ae2
	defb 008h,040h	; 4ae4
	defb 005h,090h	; 4ae6
	defb 009h,038h	; 4ae8
	defb 004h,008h	; 4aea
	defb 014h,068h	; 4aec
	defb 004h,008h	; 4aee
	defb 014h,010h	; 4af0
	defb 004h,008h	; 4af2
	defb 014h,048h	; 4af4
	defb 008h,048h	; 4af6
	defb 005h,0a0h	; 4af8
	defb 009h,008h	; 4afa
	defb 018h,040h	; 4afc
	defb 008h,008h	; 4afe
	defb 018h,090h	; 4b00
	defb 009h,048h	; 4b02
	defb 004h,058h	; 4b04
	defb 008h,008h	; 4b06
	defb 018h,080h	; 4b08
	defb 006h,0ffh	; 4b0a

; ======================================================================
; CODIGO 0x4b0c..0x4c09  (253 bytes)
; ======================================================================


bucle_de_juego:		; El bucle de juego de un fotograma: si la sala esta resuelta (0xE133) y los dos canales de sonido han callado, suena el efecto 0x8b y lo apaga; luego cae en la cadena completa de rutinas del fotograma
	ld hl,0e133h		;4b0c   ; HL = 0xE133, la marca de sala resuelta
	ld a,(hl)			;4b0f
	or a			;4b10
	jr z,cadena_del_fotograma		;4b11   ; sin resolver: directo a la cadena
	ld a,(0e012h)		;4b13   ; (0xE012), un contador de canal del motor de sonido
	ld b,a			;4b16
	ld a,(0e020h)		;4b17   ; (0xE020), el del otro canal
	or b			;4b1a
	jr nz,cadena_del_fotograma		;4b1b   ; mientras alguno suene, se espera
	ld (hl),a			;4b1d   ; los dos callados: se apaga la marca
	ld a,08bh		;4b1e
	call reproduce_efecto		;4b20   ; efecto de sonido 0x8b
cadena_del_fotograma:		; La cadena completa de un fotograma de juego: sprites, salida por el lateral, parpadeo del borde, pausa, enemigos, entidades, jugador, objetos, trampas, choques y bloques; y al final la tecla que aborta la partida
	call actualiza_tabla_de_sprites		;4b23   ; vuelca el buffer de sprites a la SAT
	call sale_por_el_lateral		;4b26   ; mira si el jugador sale por un lateral
	call parpadea_patron_borde		;4b29   ; el parpadeo del borde de piedra
	ld a,(0e132h)		;4b2c   ; (0xE132): con el puesto, el fotograma va por otro camino
	and a			;4b2f
	jp nz,L_6DE8		;4b30
	call revisa_pausa_y_alterna_rotulo		;4b33   ; la tecla de pausa
	call mueve_los_enemigos		;4b36   ; mueve los enemigos
	call recorre_entidades		;4b39   ; recorre las entidades de la sala
	call avanza_estado_del_jugador		;4b3c   ; un paso de la maquina de estados del jugador
	call recorre_entidades_17		;4b3f
	call recorre_entidades_grandes		;4b42   ; las entidades grandes
	call recoge_objetos		;4b45   ; recoge los objetos que toque el jugador
	call despacha_estado_de_la_sala		;4b48   ; el estado general de la sala
	call mueve_el_muro_trampa		;4b4b   ; mueve las trampas
	call recoge_de_la_otra_lista		;4b4e   ; y la otra lista de recogibles
	call busca_enemigo_que_toca		;4b51   ; mira si algun enemigo ha tocado al jugador
	call anima_bloques_que_se_abren		;4b54   ; y anima los bloques que se estan abriendo
	ld a,(0e002h)		;4b57   ; (0xe002) bit 6: fuera del modo especial ya se acabo el fotograma
	bit 6,a		;4b5a
	ret z			;4b5c
	ld a,006h		;4b5d   ; fila 6 del teclado
	call 00141h		;4b5f   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;4b62
	bit 6,a		;4b63
	jr z,L_4B74		;4b65
	xor a			;4b67
	ld (0e053h),a		;4b68   ; (0xE053) := 0 y (0xE05E) := 1: la tecla de abortar mata la partida
	inc a			;4b6b
	ld (0e05eh),a		;4b6c
	ld a,01dh		;4b6f   ; efecto de sonido 0x1d
	call reproduce_efecto		;4b71
L_4B74:
	ret			;4b74
actualiza_tabla_de_sprites:		; Vuelca el buffer de trabajo de sprites (0xE0B0, RAM) a la tabla de atributos de sprites de verdad (VRAM 0x3B00-0x3B7F, 32 entradas Y/X/patron/color, confirmado en caliente con tools/omsx_dump_sprites.tcl: la tabla de nombre mide 768 B desde 0x3800 -R2=0x0E, tanda 4- y termina justo en 0x3AFF)
	ld de,0e0b0h		;4b75   ; DE = 0xE0B0, inicio del buffer de sprites en RAM
	ld hl,03b00h		;4b78   ; HL = VRAM 0x3B00, inicio de la tabla de atributos de sprites
	ld bc,00018h		;4b7b   ; BC = 24 bytes = 6 sprites (Y,X,patron,color x6)
	call copia_guion_a_vram		;4b7e   ; copia los primeros 6 sprites tal cual, sin animar
	ld hl,0e061h		;4b81   ; HL -> 0xE061: contador que gira el punto de partida de un anillo de 4 sprites
	inc (hl)			;4b84   ; cuenta un fotograma mas
	ld a,(hl)			;4b85   ; A = el contador
	and 003h		;4b86   ; A mod 4: indice 0..3 dentro del anillo de 4 sprites (0xE0C8-0xE0D7)
	ld c,a			;4b88   ; C = ese indice (se reusa mas abajo como contador de vueltas del bucle)
	add a,a			;4b89   ; A *= 2
	add a,a			;4b8a   ; A *= 4: offset en bytes (4 bytes por sprite)
	ld de,0e0c8h		;4b8b   ; DE = 0xE0C8, base del anillo de 4 sprites
	call suma_a_de		;4b8e   ; DE += offset: apunta al sprite del anillo que toca leer esta vez
	ld hl,03b18h		;4b91   ; HL = VRAM 0x3B18 (sprites 6-9 de la tabla de atributos)
	ld b,004h		;4b94   ; B = 4 sprites a escribir
L_4B96:
	push bc			;4b96   ; guarda el contador de vueltas (se pisaria con el BC de la copia)
	ld bc,00004h		;4b97   ; BC = 4 bytes, un sprite
	call copia_guion_a_vram		;4b9a   ; copia un sprite del anillo a VRAM (DE avanza +4 solo, dentro de la llamada)
	pop bc			;4b9d   ; recupera el contador de vueltas
	ld a,004h		;4b9e   ; el siguiente sprite en VRAM va 4 bytes mas alla
	call suma_a_hl		;4ba0   ; HL (destino VRAM) += 4: aqui no hay auto-incremento, el llamador lo lleva a mano
	inc c			;4ba3   ; cuenta una vuelta mas dentro del anillo de 4
	ld a,c			;4ba4   ; A = el contador de vueltas
	cp 004h		;4ba5   ; si ya dio la 4a vuelta del anillo...
	jr nz,L_4BAE		;4ba7
	ld de,0e0c8h		;4ba9   ; ...vuelve DE al principio del anillo (envuelve)
	ld c,000h		;4bac   ; ...y reinicia el contador de vueltas a 0
L_4BAE:
	djnz L_4B96		;4bae   ; repite hasta escribir los 4 sprites del anillo
	ld de,0e0d8h		;4bb0   ; DE = 0xE0D8, el resto del buffer, sin animar
	ld hl,03b28h		;4bb3   ; HL = VRAM 0x3B28 (sprites 10-31 de la tabla de atributos)
	ld bc,00058h		;4bb6   ; BC = 88 bytes = 22 sprites
	jp copia_guion_a_vram		;4bb9   ; copia el resto tal cual y devuelve (jp, no call: reusa el ret de copia_guion_a_vram)
sale_por_el_lateral:		; Comprueba si el jugador ha llegado al borde de la pantalla por el lado hacia el que mira: por debajo de X=2 o por encima de X=0xF4. Si es asi, deja 0x20 fotogramas, marca 0xE147, aparca todos los sprites y manda a la tarea 9, que es la que lo teletransporta al borde opuesto
	ld a,(0e136h)		;4bbc   ; A = (0xe136), a que lado mira
	rra			;4bbf   ; su bit 0
	ld a,(0e139h)		;4bc0   ; A = la X del jugador (byte bajo)
	jr nc,L_4BCA		;4bc3
	cp 002h		;4bc5   ; mirando a un lado: sale si la X baja de 2
	ret nc			;4bc7   ; todavia no: sigue jugando
	jr c,prepara_cambio_de_pantalla		;4bc8
L_4BCA:
	cp 0f4h		;4bca   ; mirando al otro: sale si la X pasa de 0xF4
	ret c			;4bcc   ; todavia no: sigue jugando
prepara_cambio_de_pantalla:		; El jugador ha salido por el lateral: 0x20 fotogramas de contador, 0xE147 marcado, sprites aparcados en VRAM y en el buffer, y la tarea a la 9
	ld a,020h		;4bcd   ; (0xE004) := 0x20
	ld (0e004h),a		;4bcf
	ld a,001h		;4bd2   ; (0xE147) := 1
	ld (0e147h),a		;4bd4
	call aparca_sat		;4bd7   ; aparca los sprites en la SAT
	call aparca_buffer_de_sprites		;4bda   ; y en el buffer de RAM
	ld a,009h		;4bdd   ; (0xE000) := 9: la tarea que teletransporta
	ld (0e000h),a		;4bdf
	pop hl			;4be2   ; descarta el retorno del llamador: el fotograma se corta aqui
	ret			;4be3
parpadea_patron_borde:		; Hace parpadear (cada 2 fotogramas, ciclo de 4 fases con (0xe003)>>1 & 3) los tiles decorativos del borde de piedra: reescribe el patron 0x51-0x53 entero (las esquinas, tabla_brillo_borde_1) y las 3 filas inferiores del patron 0x5C (una celda suelta, SUPOSICION en su identidad exacta, tabla_brillo_borde_2) en las TRES copias por tercio de la tabla de patrones (rellena_x3_tercios)
	ld a,(0e003h)		;4be4   ; A = contador de fotogramas (0xe003)
	rra			;4be7   ; A >>= 1: la fase cambia cada 2 fotogramas
	and 003h		;4be8   ; A &= 3: fase 0..3, ciclo completo cada 8 fotogramas
	push af			;4bea   ; guarda la fase (AF) para la segunda mitad de la rutina
	ld hl,04c09h		;4beb   ; HL = tabla_brillo_borde_1 (el valor de relleno de esta fase)
	ld de,00288h		;4bee   ; DE = VRAM 0x0288 = tile 0x51 (verificado: la esquina del marco usa este mismo indice de patron)
	ld bc,00018h		;4bf1   ; BC = 24 bytes = 3 tiles completos (0x51, 0x52, 0x53)
	call aplica_relleno_de_brillo		;4bf4   ; aplica el relleno de esta fase a los 3 tiles, en los tres tercios (L_4c01, con call: retorna aqui)
	pop af			;4bf7   ; recupera la fase
	ld bc,00003h		;4bf8   ; BC = 3 bytes esta vez, no el tile entero
	ld de,002e5h		;4bfb   ; DE = VRAM 0x02E5 = tile 0x5C, filas 5-7 (las 3 inferiores, no el tile completo)
	ld hl,04c0dh		;4bfe   ; HL = tabla_brillo_borde_2 (cae de largo en L_4c01, sin call: ver nota)
aplica_relleno_de_brillo:		; Cola compartida de parpadea_patron_borde: HL(tabla)+=fase, lee el byte de esa fase y rellena con rellena_x3_tercios el VRAM/cuenta que dejo el llamador. Se llega aqui DE DOS FORMAS -con call (primera mitad, que SI retorna a 0x4bf7) y cayendo de largo sin call (segunda mitad): como rellena_x3_tercios termina en un ret propio, esa segunda pasada devuelve directamente al llamador de parpadea_patron_borde, sin ret propio aqui-, ahorrando un byte a cambio de una lectura mas dificil
	call suma_a_hl		;4c01   ; HL += fase: selecciona el byte de esta fase dentro de la tabla de 4
	ld a,(hl)			;4c04   ; A = el valor de relleno de esta fase
	ex de,hl			;4c05   ; HL = la direccion VRAM que trajo el llamador (estaba en DE)
	jp rellena_x3_tercios		;4c06   ; rellena los 3 tercios con A, BC veces cada uno

; ----------------------------------------------------------------------
; DATOS tabla_brillo_borde_1: Los 4 valores de relleno solido para el patron
;   0x51-0x53 (las esquinas del borde), uno por fase de parpadea_patron_borde
;   0x4c09..0x4c0d  (4 bytes)
DATA_tabla_brillo_borde_1:
	defb 010h,0f0h,0a0h,0a0h	; 4c09

; ----------------------------------------------------------------------
; DATOS tabla_brillo_borde_2: Los 4 valores de relleno solido para las 3 filas
;   inferiores del patron 0x5C, misma fase que tabla_brillo_borde_1
;   0x4c0d..0x4c11  (4 bytes)
DATA_tabla_brillo_borde_2:
	defb 016h,0f6h,0a6h,0a6h	; 4c0d

; ======================================================================
; CODIGO 0x4c11..0x4c52  (65 bytes)
; ======================================================================


revisa_pausa_y_alterna_rotulo:		; Solo actua en el "modo especial" (bit 6 de 0xe002, el que enciende una tecla en el menu): mira la fila 6 del teclado, detecta el flanco de la tecla de pausa (bit 5) y alterna con ella el biestable de 0xe067. Con la pausa activa descarta el retorno del llamador (pop hl) para congelar el resto del fotograma; sin ella, alterna cada 8 fotogramas el rotulo de 7 caracteres de VRAM 0x3AF6. SUPOSICION: que el bit 5 sea la tecla de pausa no esta medido en caliente, sale de que ese bit alterna un biestable que congela el fotograma
	ld a,(0e002h)		;4c11   ; (0xe002) bit 6: fuera del modo especial esta rutina no hace nada
	bit 6,a		;4c14
	ret z			;4c16
	ld a,006h		;4c17   ; fila 6 de la matriz de teclado
	call 00141h		;4c19   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;4c1c   ; la matriz devuelve 0 = pulsada; se invierte para trabajar con 1 = pulsada
	ld hl,0e065h		;4c1d   ; HL = 0xe065, la muestra anterior de esta misma fila
	call guarda_entrada_y_flanco		;4c20   ; deja en A solo los bits recien pulsados (flanco de subida) y guarda la muestra nueva
	bit 5,a		;4c23   ; bit 5 del flanco = la tecla de pausa acaba de pulsarse
	inc hl			;4c25   ; HL avanza a 0xe067, el biestable de pausa activa
	inc hl			;4c26
	ld a,(hl)			;4c27   ; A = el estado actual de la pausa
	jr nz,alterna_biestable_de_pausa		;4c28   ; con flanco: a alterna_biestable_de_pausa, que le da la vuelta
	and a			;4c2a   ; sin flanco y sin pausa activa: no hay nada que hacer
	ret z			;4c2b
	call alterna_rotulo_de_pausa		;4c2c   ; sin flanco pero con la pausa activa: alterna el rotulo y...
	pop hl			;4c2f   ; ...descarta la direccion de retorno del llamador, de modo que el fotograma se corta aqui y el juego queda congelado
	ret			;4c30
alterna_biestable_de_pausa:		; Da la vuelta al biestable de pausa (0xe067) con un xor 1; si ha quedado a 0 (se acaba de despausar) cae en la rama que repinta el rotulo con la tabla alternativa
	xor 001h		;4c31   ; da la vuelta al bit 0: pausa on <-> off
	ld (hl),a			;4c33   ; guarda el biestable ya volteado
	and a			;4c34
	jr z,L_4C46		;4c35   ; si ha quedado a 0 (se despausa) sigue en 0x4c46 para repintar el rotulo
	ret			;4c37   ; si ha quedado a 1 (se pausa) vuelve sin mas: el congelado lo hara el pop hl de arriba
alterna_rotulo_de_pausa:		; Cada 8 fotogramas cambia los 7 caracteres de VRAM 0x3AF6 entre dos textos, eligiendo con el bit 4 del contador de fotogramas: tabla_alterna_1_de_2 (0x4c52) o la de 0x6575
	ld a,(0e003h)		;4c38   ; A = contador de fotogramas (0xe003)
	ld b,a			;4c3b   ; B guarda el contador entero, que hace falta entero mas abajo
	and 007h		;4c3c   ; solo uno de cada 8 fotogramas: el resto no toca nada
	ret nz			;4c3e
	bit 4,b		;4c3f   ; bit 4 del contador: cambia de texto cada 16 fotogramas
	ld de,04c52h		;4c41   ; con el bit a 0: el primero de los dos textos (tabla_alterna_1_de_2)
	jr z,L_4C49		;4c44
L_4C46:
	ld de,06575h		;4c46   ; con el bit a 1, o entrando desde alterna_biestable_de_pausa: el segundo texto, en 0x6575
L_4C49:
	ld hl,03af6h		;4c49   ; destino: VRAM 0x3AF6, los 7 caracteres del rotulo
	ld bc,00007h		;4c4c   ; BC = 7 bytes, el largo del rotulo
	jp copia_guion_a_vram		;4c4f   ; copia y vuelve directo al llamador (jp, no call)

; ----------------------------------------------------------------------
; DATOS tabla_alterna_1_de_2: Siete bytes; la alternativa es 0x6575, elegida
;   por el bit 4 de (0xe003)
;   0x4c52..0x4c59  (7 bytes)
DATA_tabla_alterna_1_de_2:
	defb 030h,021h,035h,033h,029h,02eh,027h	; 4c52

; ======================================================================
; CODIGO 0x4c59..0x4c7f  (38 bytes)
; ======================================================================


avanza_estado_del_jugador:		; Da un paso a la maquina de estados del jugador: apila monta_sprite_del_jugador como retorno, refresca 0xe135 con la entrada del mando cuando el estado lo permite (0 = en pie, o 3), y despacha por tabla_4c7f segun 0xe134
	ld hl,04cfah		;4c59   ; apila 0x4cfa: al terminar el estado que sea, se monta el sprite del jugador sin necesidad de otro call
	push hl			;4c5c
	ld a,(0e134h)		;4c5d   ; A = estado del jugador (0xe134)
	and a			;4c60   ; estado 0 (en pie/andando): si acepta entrada nueva
	jr z,L_4C67		;4c61
	cp 003h		;4c63   ; estado 3: tambien la acepta; cualquier otro no, esta a medias de una accion
	jr nz,L_4C79		;4c65
L_4C67:
	ld hl,0e135h		;4c67   ; HL = 0xe135, la copia de la entrada que usara el estado
	ld a,(0e009h)		;4c6a   ; (0xe009): la entrada cruda del fotograma
	ld (hl),a			;4c6d   ; guarda la entrada tal cual en 0xe135
	and a			;4c6e   ; sin nada pulsado no hay direccion nueva que fijar
	jr z,L_4C79		;4c6f
	rra			;4c71   ; dos rra + and 3: baja los bits de izquierda/derecha de la entrada a la posicion 0-1
	rra			;4c72
	and 003h		;4c73
	jr z,L_4C79		;4c75   ; si esos dos bits estan a 0 (solo arriba/abajo), no cambia hacia donde mira
	inc hl			;4c77   ; HL avanza a 0xe136 y guarda ahi la direccion nueva (bit 0 = a que lado mira)
	ld (hl),a			;4c78
L_4C79:
	ld a,(0e134h)		;4c79   ; A = el estado del jugador otra vez
	call despacha_tabla_siguiente		;4c7c   ; salta a la entrada que le toque de tabla_4c7f (7 estados)

; ----------------------------------------------------------------------
; DATOS tabla_4c7f: 7 entradas, llamada L_404B desde 0x4c7c
;   0x4c7f..0x4c8d  (14 bytes)
DATA_tabla_4c7f:
	defw 04c8dh,04d6dh,04d97h,04da1h,04dfch,04e56h,04f93h	; 4c7f

; ======================================================================
; CODIGO 0x4c8d..0x4d40  (179 bytes)
; ======================================================================


estado_0_jugador_en_pie:		; Estado 0: el jugador esta de pie o andando. Con el bit 4 de 0xe008 puesto (el boton) reparte segun lo que lleve en las manos, que dice el nibble alto de 0xe144: 0 nada, 1 el cuchillo -y lo lanza-, 2 el pico -y pica-. Si no, sigue por el camino normal de andar
	ld a,(0e008h)		;4c8d   ; (0xe008) bit 4: SUPOSICION, marca que hay una accion en curso que atender antes que el andar normal
	bit 4,a		;4c90
	jr z,jugador_anda_o_cae		;4c92   ; sin accion pendiente: al camino normal de andar
	ld a,(0e144h)		;4c94   ; (0xe144), nibble alto: el OBJETO QUE LLEVA EL JUGADOR -0 nada, 1 el cuchillo, 2 el pico-, que es lo que decide que hace el boton
	and 0f0h		;4c97
	jp z,estado_0_accion_tipo_0		;4c99   ; nibble alto 0: a 0x4d50
	cp 010h		;4c9c   ; nibble alto 1: lleva el CUCHILLO, y el boton lo lanza (0x4dbf)
	jp nz,pico_busca_donde_picar		;4c9e   ; nibble alto 2: lleva el PICO, y el boton pica (0x4e9f)
	jp cuchillo_busca_sitio		;4ca1
jugador_anda_o_cae:		; El camino normal del estado 0: si no hay suelo bajo los pies arranca la caida; si lo hay, aplica el movimiento y, cuando lleva 16 fotogramas seguidos empujando contra una PUERTA GIRATORIA (celda del tipo 0x5x), pasa al estado 6 -cruzarla- con el efecto 0x03
	call hay_suelo_bajo_los_pies		;4ca4   ; comprueba el suelo bajo los dos pies (hay_suelo_bajo_los_pies); C = no hay suelo
	jp c,arranca_la_caida		;4ca7   ; sin suelo: arranca la caida
	xor a			;4caa   ; con suelo: limpia el marcador de 0xe14d
	ld (0e14dh),a		;4cab
	call mueve_al_jugador		;4cae   ; aplica el movimiento pedido por la entrada; Z = no se ha movido
	ret z			;4cb1
	ld hl,0e135h		;4cb2   ; HL = 0xe135, la entrada de este fotograma
	ld a,(hl)			;4cb5
	and 00ch		;4cb6   ; bits 2-3 de la entrada
	jp z,pose_quieto		;4cb8   ; sin esos bits: solo la animacion de andar
	ld hl,0e13eh		;4cbb   ; (0xe13e)++: el contador de fase de animacion avanza
	inc (hl)			;4cbe
	call mira_celda_hacia_donde_empuja		;4cbf   ; mira que hay en la celda hacia la que empuja; NC = nada que hacer
	jr nc,L_4CF0		;4cc2
	ld a,(hl)			;4cc4   ; A = el byte de esa celda
	and 0f0h		;4cc5
	cp 050h		;4cc7   ; nibble alto 5: SUPOSICION, la clase de bloque que se puede picar
	jr nz,L_4CF7		;4cc9
	ld a,(hl)			;4ccb
	and 00fh		;4ccc
	sub 001h		;4cce   ; nibble bajo -1, comparado con 2: solo los subtipos 1 y 2 valen
	cp 002h		;4cd0
	jr c,L_4CF7		;4cd2
	ld hl,0e146h		;4cd4   ; (0xe146)++: cuenta los fotogramas seguidos empujando contra ese bloque
	inc (hl)			;4cd7
	ld a,010h		;4cd8   ; hacen falta 16 seguidos para que cuente
	cp (hl)			;4cda
	jp nz,L_4CF7		;4cdb
	ld a,006h		;4cde
	ld (0e134h),a		;4ce0   ; estado := 6, la fase larga con contador
	ld a,020h		;4ce3
	ld (0e145h),a		;4ce5   ; (0xe145) := 0x20, el contador de esa fase
	ld a,003h		;4ce8
	call reproduce_efecto		;4cea   ; efecto de sonido 0x03
	jp marca_el_agujero_que_se_abre		;4ced   ; y a 0x69c9 a rematar
L_4CF0:
	xor a			;4cf0   ; se rompio la racha: el contador de empuje vuelve a 0
	ld (0e146h),a		;4cf1
L_4CF4:
	call avanza_al_jugador		;4cf4   ; remata por 0x73ef y luego la animacion de andar
L_4CF7:
	jp pose_de_andar		;4cf7
monta_sprite_del_jugador:		; Escribe las DOS entradas de sprite del jugador (0xE0C0 y 0xE0C4 del buffer, o sea los sprites 4 y 5) a partir del registro de posicion: Y = (0xe137)-2, X = (0xe139), y el numero de patron que sale de traducir la pose (0xe13f) por la tabla de 0x4d46, mas 0x60 si mira al otro lado. El segundo sprite usa el patron +4, la mitad de abajo del muneco de 16x16
	ld hl,0e137h		;4cfa   ; HL = 0xe137, la Y del jugador
	ld c,(hl)			;4cfd   ; C = Y
	inc hl			;4cfe   ; HL salta a 0xe139, la X (byte bajo)
	inc hl			;4cff
	ld b,(hl)			;4d00   ; B = X
	ld a,(0e13fh)		;4d01   ; A = (0xe13f), la pose actual
	ld hl,0e0c0h		;4d04   ; HL = 0xE0C0: los sprites 4 y 5 del buffer, los del jugador
	dec c			;4d07   ; Y -= 2: el sprite se dibuja dos lineas por encima de la Y logica
	dec c			;4d08
	bit 0,a		;4d09   ; bit 0 de la pose: con el puesto, devuelve una de esas dos lineas (el bote del paso)
	jr z,L_4D0E		;4d0b
	inc c			;4d0d
L_4D0E:
	ld de,04d46h		;4d0e   ; DE = 0x4d46, la tabla que traduce la pose en numero de patron
	call suma_a_de		;4d11   ; DE += pose
	ld a,(de)			;4d14   ; A = el numero de patron de esa pose
	ld d,a			;4d15   ; D lo guarda: hace falta otra vez para el segundo sprite
	call escribe_una_entrada_de_sprite		;4d16   ; llama a la cola de aqui abajo y luego CAE en ella: escribe las dos entradas con un solo cuerpo
escribe_una_entrada_de_sprite:		; Cola compartida de monta_sprite_del_jugador: escribe una entrada Y/X/patron (el color se salta), aplica el reflejo horizontal (+0x60 si mira al otro lado) y deja D apuntando al patron de la siguiente entrada (+4)
	ld (hl),c			;4d19   ; Y de la entrada
	inc hl			;4d1a
	ld (hl),b			;4d1b   ; X de la entrada
	inc hl			;4d1c
	ld a,(0e136h)		;4d1d   ; bit 0 de (0xe136): a que lado mira el jugador
	rra			;4d20
	ld a,d			;4d21
	jr nc,L_4D26		;4d22
	add a,060h		;4d24   ; mirando al otro lado, el patron esta 0x60 = 96 mas alla: el mismo dibujo reflejado
L_4D26:
	ld (hl),a			;4d26   ; numero de patron
	ld a,d			;4d27
	add a,004h		;4d28   ; el patron de la entrada siguiente esta 4 mas alla (medio muneco de 16x16)
	ld d,a			;4d2a
	inc hl			;4d2b   ; salta el byte de color y deja HL en la entrada siguiente
	inc hl			;4d2c
	ret			;4d2d
pose_de_andar:		; Traduce el contador de animacion (0xe13e) en el numero de pose (0xe13f): dos rra y &7, o sea una pose nueva cada 4 fotogramas, con ocho poses en el ciclo
	ld hl,0e13eh		;4d2e   ; HL = 0xe13e, el contador de animacion
L_4D31:
	ld a,(hl)			;4d31   ; A = el contador
	rra			;4d32   ; dos rra: la pose cambia cada 4 fotogramas
	rra			;4d33
	and 007h		;4d34   ; &7: ocho poses en el ciclo
	inc hl			;4d36   ; HL avanza a 0xe13f y guarda ahi la pose
	ld (hl),a			;4d37
	ret			;4d38
pose_quieto:		; Sin los bits de accion pulsados: pone a 0 el contador de accion (0xe145) y fija la pose 1, saltando con un jr los dos bytes de DATA_resto_4d40
	xor a			;4d39   ; (0xe145) := 0: no hay accion en curso
	ld (0e145h),a		;4d3a
	inc a			;4d3d   ; A := 1, la pose de estar de pie
	jr $+4		;4d3e   ; salta los dos bytes de DATA_resto_4d40 y entra en guarda_pose

; ----------------------------------------------------------------------
; DATOS resto_4d40: Dos bytes (3E 02, "ld a,02h") que un jr incondicional
;   salta siempre; sin entrada conocida
;   0x4d40..0x4d42  (2 bytes)
DATA_resto_4d40:
	defb 03eh,002h	; 4d40

; ======================================================================
; CODIGO 0x4d42..0x4d46  (4 bytes)
; ======================================================================


guarda_pose:		; Guarda en 0xe13f el numero de pose que se dibujara este fotograma. Punto de entrada compartido por casi todos los estados
	ld (0e13fh),a		;4d42   ; (0xe13f) := A, la pose de este fotograma
	ret			;4d45

; ----------------------------------------------------------------------
; DATOS tabla_pose_a_patron: Los diez numeros de patron del jugador, uno por
;   pose: monta_sprite_del_jugador (0x4d0e) indexa esta tabla con (0xe13f) y
;   usa el valor como patron del primer sprite, mas 4 para el segundo y mas
;   0x60 si mira al otro lado
;   0x4d46..0x4d50  (10 bytes)
DATA_tabla_pose_a_patron:
	defb 008h	; 4d46
	defb 000h	; 4d47
	defb 010h	; 4d48
	defb 008h	; 4d49
	defb 000h	; 4d4a
	defb 010h	; 4d4b
	defb 000h	; 4d4c
	defb 010h	; 4d4d
	defb 018h	; 4d4e
	defb 020h	; 4d4f

; ======================================================================
; CODIGO 0x4d50..0x4db9  (105 bytes)
; ======================================================================


estado_0_accion_tipo_0:		; Rama del estado 0 con el nibble alto de 0xe144 a cero: si el jugador tiene Y valida y la celda que mira (L_7428) no es del tipo 0x1x, guarda la entrada cruda en 0xe143 y salta al despachador de 0x70cf
	ld hl,0e137h		;4d50   ; HL = 0xe137, la Y del jugador
	ld a,(hl)			;4d53
	and a			;4d54   ; con Y=0 no hay nada que hacer
	ret z			;4d55
	call puede_avanzar		;4d56   ; mira la celda hacia la que va (0x7428); NC = no hay celda que valga
	ret nc			;4d59
	ex de,hl			;4d5a   ; HL = la celda que devolvio en DE
	ld a,(hl)			;4d5b
	and 0f0h		;4d5c   ; nibble alto 1 = suelo solido: no se puede, vuelve
	cp 010h		;4d5e
	ret z			;4d60
L_4D61:
	ld a,(0e009h)		;4d61   ; A = la entrada cruda de este fotograma (0xe009)
	ld (0e143h),a		;4d64   ; la guarda en 0xe143 para que la use el paso siguiente
	ld hl,0e134h		;4d67   ; HL = 0xe134 (el registro entero del jugador) y despacha por 0x70cf
	jp fija_rumbo_nuevo		;4d6a
estado_1_jugador:		; Estado 1: llama a 0x74e8 con el registro de direccion y luego a 0x7478 con IX apuntando al registro del jugador; si esa comprobacion sale a cero, pasa al estado 3 y sigue por estado_3_o_cae
	ld hl,0e136h		;4d6d   ; HL = 0xe136, la direccion a la que mira
	call avanza_guion_de_movimiento		;4d70
	ld hl,0e134h		;4d73   ; IX = 0xe134: el registro completo del jugador, que 0x7478 espera indexado
	push hl			;4d76
	pop ix		;4d77
	call decide_si_el_registro_sigue		;4d79   ; la comprobacion de 0x7478; NZ = todavia no toca cambiar
	ret nz			;4d7c
	ld a,003h		;4d7d
	ld (0e134h),a		;4d7f   ; estado := 3
	jr estado_3_o_cae		;4d82
vuelve_al_estado_0:		; Suena el efecto 0x02 y devuelve el jugador al estado 0 (en pie). Es la salida "no ha pasado nada" de la caida
	ld a,002h		;4d84   ; efecto de sonido 0x02
	call reproduce_efecto		;4d86
	xor a			;4d89
	ld (0e134h),a		;4d8a   ; estado := 0, otra vez en pie
	ret			;4d8d
arranca_la_caida:		; Sin suelo bajo los pies: limpia 0xe03b, suena el efecto 0x01 y cae en estado_3_o_cae
	xor a			;4d8e
	ld (0e03bh),a		;4d8f   ; (0xe03b) := 0: SUPOSICION, marcador que la caida limpia
	ld a,001h		;4d92
	call reproduce_efecto		;4d94   ; efecto de sonido 0x01, el de empezar a caer
estado_3_o_cae:		; Deja que 0x7558 mueva el registro del jugador un paso; si devuelve NC (ya no puede seguir) vuelve al estado 0 con el efecto 0x02
	ld hl,0e134h		;4d97   ; HL = 0xe134, el registro del jugador entero
	call da_un_paso_de_caida		;4d9a   ; 0x7558 da el paso; NC = se acabo
	jp nc,vuelve_al_estado_0		;4d9d   ; se acabo: de vuelta al estado 0
	ret			;4da0
estado_3_jugador:		; Estado 3: solo actua si la entrada trae los bits 2-3; limpia 0xe05f, prueba 0x7571 con B=1 y, segun salga, remata con la animacion de andar
	ld hl,0e135h		;4da1   ; HL = 0xe135, la entrada de este fotograma
	ld a,(hl)			;4da4
	and 00ch		;4da5   ; bits 2-3 de la entrada
	ret z			;4da7   ; sin esos bits, este estado no hace nada
	ld b,001h		;4da8   ; B := 1, el parametro que espera 0x7571
	xor a			;4daa
	ld (0e05fh),a		;4dab   ; (0xe05f) := 0: SUPOSICION, marcador que este estado limpia
	call avanza_registro_alineado		;4dae   ; la prueba de 0x7571
	jr z,L_4DB6		;4db1
	jp pose_de_andar		;4db3   ; con NZ: solo la animacion de andar
L_4DB6:
	xor a			;4db6   ; con Z: A := 0 y salta los dos bytes de DATA_resto_4db9 para entrar en guarda_estado
	jr $+4		;4db7

; ----------------------------------------------------------------------
; DATOS resto_4db9: Dos bytes (3E 03, "ld a,03h") que un jr incondicional
;   salta siempre; sin entrada conocida
;   0x4db9..0x4dbb  (2 bytes)
DATA_resto_4db9:
	defb 03eh,003h	; 4db9

; ======================================================================
; CODIGO 0x4dbb..0x5050  (661 bytes)
; ======================================================================


guarda_estado:		; Guarda en 0xe134 el estado que trae A. Entrada compartida, alcanzada saltando los dos bytes muertos de DATA_resto_4db9
	ld (0e134h),a		;4dbb   ; (0xe134) := A, el estado nuevo del jugador
	ret			;4dbe
cuchillo_busca_sitio:		; Rama del estado 0 cuando el jugador lleva el CUCHILLO: mira si tiene sitio para lanzarlo -la celda a un lado, offset -1 o +0x12 en X segun a que lado mire- y, si no hay pared, arranca el lanzamiento (estado 4, contador 0x15); si hay pared, exige ademas que la X este alineada a 4 y mira dos pixeles mas alla, por si le cabe el cuchillo por encima. CORRECCION (2026-09-04): esto se llamaba "pico_busca_bloque" y no es el pico, es el cuchillo -el nibble 1 de 0xe144 es el cuchillo, y el juego de sprites que carga es GFX_ProtaKnife-
	xor a			;4dbf   ; (0xe131) := 0: el contador de "bloques encontrados" de esta pasada
	ld (0e131h),a		;4dc0
	ld hl,0e136h		;4dc3   ; HL = 0xe136, a que lado mira; HL avanza a 0xe137 para la comprobacion
	ld a,(hl)			;4dc6
	inc hl			;4dc7
	rra			;4dc8   ; bit 0: a que lado mira
	ld bc,0ff00h		;4dc9   ; mirando a un lado, B = -1 (un pixel a la izquierda)
	jr c,L_4DD0		;4dcc
	ld b,012h		;4dce   ; mirando al otro, B = +0x12 (18 pixeles a la derecha, el ancho del muneco)
L_4DD0:
	push bc			;4dd0
	call sondea_una_celda		;4dd1   ; mira la celda con ese desplazamiento; Z = es del tipo 0x1x
	pop bc			;4dd4
	jr z,cuchillo_afina_alineacion		;4dd5   ; hay pared: sigue afinando en 0x4de4, a ver si cabe por encima
L_4DD7:
	ld a,015h		;4dd7   ; no hay pared: (0xe145) := 0x15, el contador de la animacion de lanzar
	ld (0e145h),a		;4dd9
	ld a,004h		;4ddc
	ld (0e134h),a		;4dde   ; estado := 4, el de lanzar el cuchillo
	jp pose_8		;4de1   ; y la pose 8
cuchillo_afina_alineacion:		; Continuacion de cuchillo_busca_sitio cuando la celda de al lado era pared: solo deja lanzar con la X alineada a 4 dentro de la celda, y mira una fila mas arriba por si hay hueco -el caso de estar metido en un agujero con sitio libre sobre la cabeza-; si tambien es solida, cuenta uno en 0xe131 y lanza igual
	dec c			;4de4   ; C -= 1: el ajuste de fila baja uno
	ld hl,0e139h		;4de5   ; HL = 0xe139, la X del jugador
	ld a,(hl)			;4de8
	and 007h		;4de9   ; X mod 8, comparado con 4: solo vale la posicion alineada a media celda
	cp 004h		;4deb
	ret nz			;4ded   ; fuera de esa alineacion, no se pica
	dec hl			;4dee   ; HL vuelve a 0xe137 para la segunda comprobacion
	dec hl			;4def
	call sondea_una_celda		;4df0   ; mira otra vez con el ajuste ya bajado
	ld a,c			;4df3   ; C = 0 quiere decir que tambien era solida
	or a			;4df4
	ret nz			;4df5
	ld hl,0e131h		;4df6   ; (0xe131)++: cuenta que hay bloque a los dos lados
	inc (hl)			;4df9
	jr L_4DD7		;4dfa
estado_4_lanza_el_cuchillo:		; Estado 4 (lanzando el cuchillo): mientras el bit 4 de 0xe145 siga puesto cuenta atras; al llegar a nibble bajo 0 crea una entidad nueva -EL CUCHILLO QUE SALE VOLANDO- copiando la posicion del jugador desplazada, y deja la pose 9 (o la 8 si no hubo sitio doble)
	ld hl,0e145h		;4dfc   ; HL = 0xe145, el contador del picado
	bit 4,(hl)		;4dff   ; bit 4 puesto = todavia en la primera mitad del golpe
	jr z,estado_4_termina		;4e01
	dec (hl)			;4e03   ; cuenta atras un fotograma
	ld a,(hl)			;4e04
	and 00fh		;4e05   ; solo actua cuando el nibble bajo llega a 0
	ret nz			;4e07
	ld hl,0e261h		;4e08   ; (0xe261) se copia sobre (0xe262): SUPOSICION, dos punteros/indices de la lista de entidades
	ld a,(hl)			;4e0b
	inc hl			;4e0c
	ld (hl),a			;4e0d
	xor a			;4e0e
	call campo_de_cuchillo		;4e0f   ; pide una entidad libre (0x5af6); HL apunta a ella
	ld (hl),004h		;4e12   ; el primer campo de la entidad := 4
	ld a,(0e136h)		;4e14   ; los dos bits de direccion del jugador, copiados a la entidad
	and 003h		;4e17
	inc hl			;4e19
	ld (hl),a			;4e1a
	ld a,(0e131h)		;4e1b   ; (0xe131): hubo bloque a los dos lados?
	or a			;4e1e
	jr z,L_4E40		;4e1f   ; no: solo la pose 9
	dec hl			;4e21
	ld (hl),007h		;4e22   ; si: el primer campo de la entidad pasa a 7
	inc hl			;4e24
	inc hl			;4e25
	ld de,0e137h		;4e26   ; DE = 0xe137, la posicion del jugador, que se va a copiar a la entidad
	ld a,(de)			;4e29
	sub 008h		;4e2a   ; Y de la entidad := Y del jugador - 8 (una celda mas arriba)
	ld (hl),a			;4e2c
	inc hl			;4e2d
	inc hl			;4e2e
	inc de			;4e2f
	inc de			;4e30
	ld a,(de)			;4e31   ; X baja de la entidad := X baja del jugador + 4
	add a,004h		;4e32
	ld (hl),a			;4e34
	inc hl			;4e35
	inc de			;4e36
	ld a,(de)			;4e37   ; X alta de la entidad := X alta del jugador, tal cual
	ld (hl),a			;4e38
	ld a,004h		;4e39
	call suma_a_hl		;4e3b   ; cuatro bytes mas alla, el ultimo campo de la entidad a 0
	ld (hl),000h		;4e3e
L_4E40:
	ld a,009h		;4e40   ; pose 9
	jp guarda_pose_y_vuelve		;4e42
pose_8:		; Fija la pose 8. Entrada compartida por las dos ramas del pico
	ld a,008h		;4e45   ; A := 8, la pose del pico
guarda_pose_y_vuelve:		; Guarda A en 0xe13f (la pose) y vuelve. Igual que guarda_pose, pero con su propio ret
	ld (0e13fh),a		;4e47   ; (0xe13f) := A
	ret			;4e4a
estado_4_termina:		; Segunda mitad del lanzamiento (bit 4 de 0xe145 ya a cero): cuenta atras hasta 0 y devuelve el jugador al estado 0, limpiando 0xe144 -o sea, dejando de llevar el cuchillo, que ya ha salido volando-
	ld hl,0e145h		;4e4b   ; HL = 0xe145, el contador
	dec (hl)			;4e4e   ; mientras no llegue a 0, nada
	ret nz			;4e4f
	xor a			;4e50
	ld (0e134h),a		;4e51   ; estado := 0, otra vez en pie
	jr limpia_accion_pendiente		;4e54
estado_5_picando:		; Estado 5 (PICANDO con el pico): cuenta atras 0xe145; en los fotogramas intermedios alterna la pose entre 8 y 9, y cada vez que el nibble bajo llega a 0 avanza el paso del agujero -restando 3 a 0xe148 y llamando a 0x68e5 en la fase larga-. Cuando 0xe148 se agota, remata con 0x4faa, pose 1 y vuelta al estado 0
	ld hl,0e145h		;4e56   ; HL = 0xe145, el contador de la accion
	dec (hl)			;4e59   ; cuenta atras un fotograma
	ld a,(hl)			;4e5a
	and 00fh		;4e5b   ; nibble bajo: en los fotogramas intermedios solo cambia la pose
	jr z,L_4E6A		;4e5d
	ld a,(hl)			;4e5f
	bit 4,a		;4e60   ; bit 4 del contador: alterna entre las poses 9 y 8
	ld a,009h		;4e62
	jr z,L_4E67		;4e64
	dec a			;4e66
L_4E67:
	jp guarda_pose		;4e67
L_4E6A:
	ld a,(hl)			;4e6a   ; el nibble bajo ha llegado a 0: toca avanzar el paso
	bit 4,a		;4e6b   ; bit 4: en la primera mitad B=4, en la segunda B=8
	ld b,004h		;4e6d
	jr nz,L_4E80		;4e6f
	ld b,008h		;4e71
	push bc			;4e73
	push hl			;4e74
	ld hl,0e148h		;4e75   ; (0xe148) -= 3: el contador largo del empuje baja de tres en tres
	dec (hl)			;4e78
	dec (hl)			;4e79
	dec (hl)			;4e7a
	call avanza_el_empuje		;4e7b   ; 0x68e5 hace el trabajo pesado de mover el bloque
	pop hl			;4e7e
	pop bc			;4e7f
L_4E80:
	ld a,(hl)			;4e80
	and 0f0h		;4e81   ; recompone el contador: nibble alto intacto, nibble bajo = B, y da la vuelta al bit 4
	or b			;4e83
	xor 010h		;4e84
	ld (hl),a			;4e86
	ld a,(0e148h)		;4e87   ; (0xe148): mientras quede, sigue empujando
	and a			;4e8a
	ret nz			;4e8b
	call realinea_x_del_jugador		;4e8c   ; agotado: remata con 0x4faa (realinea la X)
	ld a,001h		;4e8f   ; pose 1, de pie
	call guarda_pose		;4e91
	xor a			;4e94
	ld (0e134h),a		;4e95   ; estado := 0
limpia_accion_pendiente:		; Pone a 0 la accion pendiente (0xe144) y repinta el marcador de 0x5031
	xor a			;4e98   ; A := 0
guarda_accion_pendiente:		; Guarda A en 0xe144 (la accion pendiente) y repinta el marcador que dibuja 0x5031
	ld (0e144h),a		;4e99   ; (0xe144) := A
	jp carga_sprites_del_jugador		;4e9c   ; y repinta el marcador correspondiente
pico_busca_donde_picar:		; Rama del estado 0 cuando el jugador lleva el PICO (nibble alto de 0xe144 = 2). Exige suelo, prueba 0x51b5/0x51b6 con la direccion invertida y, segun el resultado, calcula en el scratch de 0xe149 la celda que va a picar
	ld hl,0e137h		;4e9f   ; HL = 0xe137, la posicion del jugador
	call sondea_los_dos_pies		;4ea2   ; sin suelo bajo los pies, no hace nada
	ret nz			;4ea5
	dec hl			;4ea6   ; HL = 0xe136, la direccion
	push hl			;4ea7
	call lee_direccion_y_mira		;4ea8   ; la prueba de 0x51b5
	pop hl			;4eab
	jr nc,calcula_celda_objetivo		;4eac   ; NC: sigue por el camino de abajo
	ld a,(hl)			;4eae   ; da la vuelta a los dos bits de direccion
	xor 003h		;4eaf
	ld b,a			;4eb1
	push hl			;4eb2
	call mira_celda_con_direccion		;4eb3   ; y repite la prueba con la direccion invertida
	pop hl			;4eb6
	jp c,candidata_por_el_otro_lado		;4eb7   ; con C: a 0x4f47, que rellena el scratch por el otro camino
calcula_celda_objetivo:		; Monta en DE la posicion candidata (Y+0x10, o sea una celda mas abajo) y elige el desplazamiento en X segun la pose: 0x10 en las poses bajas, 0x0810 en las altas
	ld e,(hl)			;4eba   ; E = Y del jugador
	inc hl			;4ebb
	ld a,(hl)			;4ebc
	add a,010h		;4ebd   ; D = la parte alta + 0x10: una celda por debajo
	ld d,a			;4ebf
	inc hl			;4ec0
	inc hl			;4ec1
	ld a,(hl)			;4ec2   ; A = la pose actual
	ld bc,00010h		;4ec3   ; BC = 0x0010, los dos desplazamientos por defecto
	and 007h		;4ec6   ; pose mod 8, comparada con 5
	cp 005h		;4ec8
	jr c,L_4ECF		;4eca
	ld bc,00810h		;4ecc   ; poses 5-7: BC = 0x0810, desplazamientos distintos
L_4ECF:
	ld a,e			;4ecf   ; bit 0 de la Y: elige B o C
	rra			;4ed0
L_4ED1:
	ld a,b			;4ed1
	jr c,comprueba_y_guarda_candidata		;4ed2
	ld a,c			;4ed4
comprueba_y_guarda_candidata:		; Suma el desplazamiento elegido a la X, descarta el resultado si se sale de la sala (los tres bits altos a 0 o a 1), guarda la posicion candidata en el scratch de 0xe149 y, si la celda de ahi es del tipo 0x1x con subtipo menor que 4 y la de una fila mas abajo no es 0x5x mientras la de en medio es 0x0x o 0x2x, pasa al estado 5 con contador 0x15
	add a,(hl)			;4ed5   ; A = el desplazamiento elegido + la X
	ld e,a			;4ed6   ; E = la X candidata
	and 0f8h		;4ed7   ; los tres bits altos a 0: se sale por un lado, descarta
	ret z			;4ed9
	cp 0f8h		;4eda   ; los tres bits altos a 1: se sale por el otro, descarta
	ret z			;4edc
	ld hl,0e149h		;4edd   ; HL = 0xe149, el scratch de posicion candidata (mismo formato Y/?/Xbaja/Xalta)
	push hl			;4ee0
	ld (hl),d			;4ee1   ; Y de la candidata
	inc hl			;4ee2
	inc hl			;4ee3
	ld (hl),e			;4ee4   ; X baja de la candidata
	inc de			;4ee5
	inc hl			;4ee6
	ld a,(0e13ah)		;4ee7   ; X alta: la misma que la del jugador
	ld (hl),a			;4eea
	pop hl			;4eeb
	call lee_celda_propia		;4eec   ; lee la celda de la posicion candidata
	and 0f0h		;4eef
	cp 010h		;4ef1   ; tiene que ser del tipo 0x1x
	ret nz			;4ef3
	ld a,(hl)			;4ef4
	and 00fh		;4ef5
	cp 004h		;4ef7   ; y de subtipo menor que 4
	ret nc			;4ef9
	ld a,060h		;4efa
	call suma_a_hl		;4efc   ; HL += 0x60 = 96: una fila mas abajo en el buffer de sala
	ld a,(hl)			;4eff
	and 0f0h		;4f00
	cp 050h		;4f02   ; si esa es del tipo 0x5x, no vale
	ret z			;4f04
	ld bc,0ff40h		;4f05   ; HL -= 0xC0 = 192: dos filas mas arriba de donde estaba
	add hl,bc			;4f08
	ld a,(hl)			;4f09
	and 0f0h		;4f0a   ; tipo 0x0x (hueco) o 0x2x: cualquier otro no vale
	jr z,$+3		;4f0c   ; UN SALTO A MEDIA INSTRUCCION: `jr z,$+3` no cae en el `cp 020h` de 0x4f0e sino en su SEGUNDO byte, y ahi el 0x20 se decodifica como `jr nz,...`. Como se llega con Z puesto, ese `jr nz` nunca salta y el efecto es saltarse la comprobacion. Rareza del programador original, no un fallo
	cp 020h		;4f0e
	ret nz			;4f10
	ld hl,0e134h		;4f11   ; estado := 5, el de empujar
	ld (hl),005h		;4f14
	inc hl			;4f16
	inc hl			;4f17
	ld a,(hl)			;4f18   ; bit 0 de 0xe136: a que lado mira
	rra			;4f19
	inc hl			;4f1a
	inc hl			;4f1b
	inc hl			;4f1c
	ld a,(hl)			;4f1d   ; A = la X, que hay que realinear
	jr nc,L_4F30		;4f1e
	and 007h		;4f20   ; mirando a un lado: si el resto mod 8 es 5 o mas, redondea a la media celda siguiente
	cp 005h		;4f22
	ld a,(hl)			;4f24
	jr c,L_4F2D		;4f25
	add a,004h		;4f27
	and 0f8h		;4f29
	add a,002h		;4f2b
L_4F2D:
	ld (hl),a			;4f2d
	jr arranca_empuje		;4f2e
L_4F30:
	and 007h		;4f30   ; mirando al otro: si el resto mod 8 esta entre 1 y 3, alinea a multiplo de 4
	sub 001h		;4f32
	cp 003h		;4f34
	ld a,(hl)			;4f36
	jr c,L_4F3B		;4f37
	and 0fch		;4f39
L_4F3B:
	ld (hl),a			;4f3b
arranca_empuje:		; Deja el contador largo del empuje (0xe148) en 0x15 y el estado en 5
	ld a,015h		;4f3c   ; (0xe148) := 0x15, los pasos del empuje
	ld (0e148h),a		;4f3e
	ld a,005h		;4f41
	ld (0e134h),a		;4f43   ; estado := 5
	ret			;4f46
candidata_por_el_otro_lado:		; El camino de 0x4eba cuando la prueba con la direccion invertida dio C: copia la posicion desde donde apunta HL al scratch de 0xe149 (sumandole 0x10 a la X si mira al otro lado), arranca el empuje, y comprueba la celda propia para decidir si ademas sube la Y de la candidata 8 pixeles y acorta el empuje a 9 pasos. Remata siempre con el efecto 0x45
	ld de,0e149h		;4f47   ; DE = 0xe149, el scratch de posicion candidata
	inc hl			;4f4a
	ld a,(hl)			;4f4b   ; Y de la candidata
	ld (de),a			;4f4c
	inc hl			;4f4d
	inc de			;4f4e
	inc de			;4f4f
	inc hl			;4f50
	ld a,(0e136h)		;4f51   ; bit 0 de 0xe136: a que lado mira
	rra			;4f54
	ld a,(hl)			;4f55
	jr c,L_4F5A		;4f56
	add a,010h		;4f58   ; mirando al otro lado, la X candidata va 0x10 pixeles mas alla
L_4F5A:
	ld (de),a			;4f5a   ; X baja de la candidata
	and 0f8h		;4f5b   ; los tres bits altos a 0 o a 1: se sale de la sala, descarta
	ret z			;4f5d
	cp 0f8h		;4f5e
	ret z			;4f60
	inc hl			;4f61
	inc de			;4f62
	ld a,(hl)			;4f63   ; X alta de la candidata
	ld (de),a			;4f64
	call arranca_empuje		;4f65   ; arranca el empuje (contador 0x15, estado 5)
	ld a,002h		;4f68
	ld (0e145h),a		;4f6a   ; (0xe145) := 2, el contador corto de la accion
	ld hl,0e137h		;4f6d   ; HL = 0xe137: mira ahora la celda del propio jugador
	call lee_celda_propia		;4f70
	ld a,(0e136h)		;4f73   ; bit 0 de 0xe136: a que lado mira
	rra			;4f76
	jr c,L_4F7B		;4f77
	inc hl			;4f79   ; mirando a un lado, mira dos celdas mas alla
	inc hl			;4f7a
L_4F7B:
	ld a,(hl)			;4f7b
	and 0f0h		;4f7c
	cp 010h		;4f7e   ; si esa celda es del tipo 0x1x, deja la candidata como esta
	jr z,L_4F8E		;4f80
	ld hl,0e149h		;4f82
	ld a,(hl)			;4f85
	add a,008h		;4f86   ; si no: la Y de la candidata baja 8 pixeles (una celda)
	ld (hl),a			;4f88
	ld a,009h		;4f89
	ld (0e148h),a		;4f8b   ; y el empuje se acorta a 9 pasos
L_4F8E:
	ld a,045h		;4f8e   ; efecto de sonido 0x45, el de activar algo
	jp reproduce_efecto		;4f90
estado_6_puerta_giratoria:		; Estado 6 (PASANDO POR UNA PUERTA GIRATORIA): cada dos fotogramas cuenta atras 0xe145; mientras dura, avanza la animacion de andar -el jugador cruza la puerta-; al agotarse vuelve al estado 0
	ld a,(0e003h)		;4f93   ; bit 0 del contador de fotogramas: solo actua uno de cada dos
	and 001h		;4f96
	ret nz			;4f98
	ld hl,0e145h		;4f99   ; HL = 0xe145, el contador de la fase
	dec (hl)			;4f9c   ; cuenta atras
	jr z,termina_estado_6		;4f9d
	ld hl,0e13eh		;4f9f   ; mientras dure: sigue avanzando la animacion de andar
	inc (hl)			;4fa2
	jp L_4CF4		;4fa3
termina_estado_6:		; El contador de la fase 6 se agoto: estado := 0 (A ya vale 0 al llegar aqui)
	ld (0e134h),a		;4fa6   ; estado := 0
	ret			;4fa9
realinea_x_del_jugador:		; Prueba dos celdas con 0x7441 (desplazamientos 0x040c y 0x0b0c) para decidir si la X del jugador se redondea hacia arriba (+4) o hacia abajo, y la alinea a multiplo de 4
	ld hl,0e137h		;4faa   ; HL = 0xe137, la posicion del jugador
	ld bc,0040ch		;4fad   ; BC = 0x040c: cuatro pixeles a un lado, doce hacia abajo
	call sondea_a_tres_alturas		;4fb0   ; la primera prueba
	ld b,004h		;4fb3   ; por defecto, redondea sumando 4
	jr nc,alinea_x_a_cuatro		;4fb5
	ld bc,00b0ch		;4fb7   ; BC = 0x0b0c: once pixeles al otro lado, la misma altura
	call sondea_a_tres_alturas		;4fba
	ret c			;4fbd   ; si esa tambien da C, deja la X como esta
	ld b,000h		;4fbe   ; si no, alinea sin sumar nada
alinea_x_a_cuatro:		; Suma B a la X del jugador y la alinea a multiplo de 4 (and 0xFC)
	ld hl,0e139h		;4fc0   ; HL = 0xe139, la X del jugador
	ld a,(hl)			;4fc3
	add a,b			;4fc4   ; X += B (0 o 4)
	and 0fch		;4fc5   ; y se alinea a multiplo de 4
	ld (hl),a			;4fc7
	ret			;4fc8
prepara_sala_nueva:		; Borra los seis bytes de estado del jugador (0xe130-0xe135) y repinta de cero el marco de la sala: el borde de arriba, el de abajo, el rotulo del lateral y las seis franjas repetidas. Lo llama 0x432a justo antes de carga_la_sala
	ld hl,0e130h		;4fc9   ; HL = 0xe130, el principio del bloque de estado del jugador
	ld de,0e131h		;4fcc
	ld bc,00500h		;4fcf   ; BC = 5 bytes a propagar con el ldir (6 en total con el primero)
	xor a			;4fd2
	ld (hl),a			;4fd3   ; pone el primer byte a 0...
	ldir		;4fd4   ; ...y el ldir arrastra ese 0 por los cinco siguientes
	ld hl,02200h		;4fd6   ; el guion 0x5613 en VRAM 0x2200
	ld de,05613h		;4fd9
	call dibuja_guion_x3_tercios		;4fdc
	ld hl,00228h		;4fdf   ; el guion 0x5754 en VRAM 0x0228
	ld de,05754h		;4fe2
	call dibuja_guion_x3_tercios		;4fe5
	ld hl,02340h		;4fe8
	ld de,023b8h		;4feb
	ld c,00fh		;4fee   ; C = 15 PATRONES a voltear con 0x4568: los tiles 0x68-0x76 (la puerta de salida, la palanca y las escaleras) se copian del reves a 0x77-0x85. El cartucho no guarda esos dibujos dos veces: los fabrica al vuelo
	call voltea_patrones		;4ff0
	ld de,057b8h		;4ff3   ; el guion 0x57b8 en VRAM 0x03b8
	ld hl,003b8h		;4ff6
	call dibuja_guion_x3_tercios		;4ff9
	ld b,006h		;4ffc   ; seis repeticiones del mismo guion, una cada 8 filas
	ld hl,02430h		;4ffe
repite_franja_seis_veces:		; Bucle que dibuja el guion 0x574a seis veces, bajando 8 filas de VRAM en cada vuelta
	ld de,0574ah		;5001   ; DE = el guion 0x574a
	push hl			;5004
	push bc			;5005
	call dibuja_guion_x3_tercios		;5006   ; lo dibuja en los tres tercios
	pop bc			;5009
	pop hl			;500a
	ld de,00008h		;500b   ; la vuelta siguiente, 8 filas mas abajo
	add hl,de			;500e
	djnz repite_franja_seis_veces		;500f
	ld de,057cdh		;5011   ; rematado el bucle, el guion 0x57cd en VRAM 0x0430
	ld hl,00430h		;5014
	call dibuja_guion_x3_tercios		;5017
	ld de,05571h		;501a   ; dos guiones mas con su direccion incluida
	call dibuja_guion_con_direccion		;501d
	ld de,05511h		;5020
	call dibuja_guion_con_direccion		;5023
	ld hl,01940h		;5026
	ld de,01c50h		;5029
	ld c,003h		;502c   ; C = 3 SPRITES a voltear: la momia de 0x1940 se copia en espejo a 0x1c50, o sea al patron 0x88
	call voltea_sprites		;502e
carga_sprites_del_jugador:		; Carga el juego de sprites que corresponde a lo que el jugador lleva en las manos: el nibble alto de 0xe144 indexa tabla_5050_indice -0x51e9 con las manos vacias, 0x52a5 con el cuchillo, 0x53d8 con el pico- y lo dibuja en VRAM 0x1800, rematando con el volteo de sus diez sprites a 0x1b10, que es el patron 0x60. Los tres se cargan en la MISMA direccion: en la VRAM solo puede haber uno
	ld a,(0e144h)		;5031   ; A = (0xe144), el objeto que lleva el jugador
	rra			;5034   ; tres rra y &0x1e: el nibble alto pasa a indice de palabra (x2)
	rra			;5035
	rra			;5036
	and 01eh		;5037
	ld hl,05050h		;5039   ; HL = tabla_5050_indice, los tres juegos de sprites: manos vacias, cuchillo, pico
	call palabra_de_tabla		;503c   ; HL = el guion que toca
	ex de,hl			;503f
	ld hl,01800h		;5040   ; destino: VRAM 0x1800
	push hl			;5043
	call dibuja_guion_con_direccion		;5044   ; lo dibuja
	pop hl			;5047
	ld de,01b10h		;5048   ; y remata copiando 10 filas a VRAM 0x1b10
	ld c,00ah		;504b
	jp voltea_sprites		;504d

; ----------------------------------------------------------------------
; DATOS tabla_5050_indice: 3 punteros (0x51e9, 0x52a5, 0x53d8), indexados por
;   L_5031 igual que tabla_de_atributos
;   0x5050..0x5056  (6 bytes)
DATA_tabla_5050_indice:
	defw 051e9h,052a5h,053d8h	; 5050  -> DATA_guion_51e9 DATA_guion_52a5 DATA_guion_53d8

; ----------------------------------------------------------------------
; DATOS resto_5056: Tres bytes (21 37 E1 = "ld hl,0e137h") que quedan detras
;   de tabla_5050_indice y delante de 0x5059; ningun salto aterriza en ellos
;   0x5056..0x5059  (3 bytes)
DATA_resto_5056:
	defb 021h,037h,0e1h	; 5056

; ======================================================================
; CODIGO 0x5059..0x50f6  (157 bytes)
; ======================================================================


hay_hueco_delante:		; Mira la celda que hay delante del jugador -a 15 pixeles a un lado o a 11 al otro, segun el bit 0 del byte anterior a HL- y devuelve Z si es del tipo 0x1x (solida), o C si no
	push hl			;5059
	dec hl			;505a   ; HL-1: el byte de direccion que hay justo antes de la posicion
	ld a,(hl)			;505b
	inc hl			;505c
	ld bc,0050fh		;505d   ; BC = 0x050f: cinco filas hacia abajo, quince pixeles a un lado
	rra			;5060   ; bit 0 de la direccion
	jr c,L_5065		;5061
	ld b,00bh		;5063   ; al otro lado, once pixeles en vez de quince
L_5065:
	call lee_celda_de_sala		;5065
	pop hl			;5068
	and 0f0h		;5069   ; nibble alto 1 = solida
	cp 010h		;506b
	ret z			;506d
	scf			;506e   ; no es solida: devuelve C
	ret			;506f
hay_suelo_bajo_los_pies:		; Comprueba con dos sondas (6 y 10 pixeles a los lados, 0x11 hacia abajo) si hay suelo bajo el jugador. Si lo hay devuelve Z; si no, alinea antes la X a multiplo de 4 -para que la caida empiece cuadrada con la rejilla- y devuelve C
	ld hl,0e137h		;5070   ; HL = 0xe137, la posicion del jugador
hay_suelo_bajo:		; Igual que hay_suelo_bajo_los_pies pero para la posicion que traiga el llamador en HL, no solo la del jugador
	call sondea_los_dos_pies		;5073   ; las dos sondas bajo los pies
	ret z			;5076   ; con Z hay suelo: vuelve sin tocar nada
	inc hl			;5077   ; sin suelo: HL avanza a la X (dos bytes mas alla)
	inc hl			;5078
	ld a,(hl)			;5079
	and 007h		;507a   ; X mod 8, comparada con 4: decide si redondea hacia arriba
	cp 004h		;507c
	ld a,(hl)			;507e
	jr nc,L_5083		;507f
	add a,004h		;5081   ; por debajo de 4, suma 4 antes de alinear
L_5083:
	and 0fch		;5083   ; alinea la X a multiplo de 4
	ld (hl),a			;5085
	scf			;5086   ; devuelve C: no hay suelo
	ret			;5087
sondea_los_dos_pies:		; Lanza sondea_una_celda dos veces, a 6 y a 10 pixeles a los lados de la posicion y 0x11 pixeles por debajo: si cualquiera de las dos da suelo, el jugador se sostiene
	ld bc,00611h		;5088   ; BC = 0x0611: seis pixeles a un lado, 0x11 hacia abajo (el pie de delante)
	call sondea_una_celda		;508b   ; la primera sonda
	ret z			;508e   ; con Z ya hay suelo, no hace falta la segunda
	ld bc,00a11h		;508f   ; BC = 0x0a11: diez pixeles, el otro pie
sondea_una_celda:		; Lee la celda desplazada (B,C) desde la posicion de HL y la clasifica: Z si es del tipo 0x1x (suelo), Z tambien si es 0x5x, y en el caso especial de que el estado del registro (HL-3) sea 2 devuelve el tipo en A y baja B. Es la sonda basica que usan todas las comprobaciones de suelo y pared
	push hl			;5092
	call lee_celda_de_sala		;5093   ; lee la celda desplazada
	ex de,hl			;5096   ; HL = el puntero al buffer de sala que devolvio
	pop hl			;5097
	dec hl			;5098   ; HL-3 desde la posicion: el byte de estado del registro
	dec hl			;5099
	dec hl			;509a
	ld b,(hl)			;509b   ; B = el estado
	inc hl			;509c   ; HL vuelve a la posicion
	inc hl			;509d
	inc hl			;509e
	and 0f0h		;509f   ; solo interesa el nibble alto de la celda
	ld c,a			;50a1   ; C lo guarda
	cp 010h		;50a2   ; tipo 0x1x: suelo solido, devuelve Z
	ret z			;50a4
	ld a,b			;50a5
	cp 002h		;50a6   ; estado 2: caso especial, sigue en 0x50ae
	ld a,c			;50a8
	jr z,apoyo_del_estado_2		;50a9
	cp 050h		;50ab   ; cualquier otro estado: solo el tipo 0x5x cuenta como apoyo
	ret			;50ad
apoyo_del_estado_2:		; Caso especial del estado 2 dentro de sondea_una_celda: devuelve el tipo de celda tal cual y baja B en uno
	ld a,c			;50ae   ; A = el tipo de celda, sin comparar con nada
	dec b			;50af   ; B (el estado) baja uno
	ret			;50b0
lee_celda_propia:		; Envoltorio de lee_celda_de_sala con desplazamiento (B,C)=(0,0): lee la celda de sala en la posicion EXACTA que trae el llamador, sin desplazarla
	push de			;50b1
	push bc			;50b2
	ld bc,00000h		;50b3   ; BC=0 antes de entrar en lee_celda_de_sala: sin desplazamiento de fila ni de columna, la celda que se lee es la de la posicion tal cual
	call lee_celda_de_sala		;50b6
	pop bc			;50b9
	pop de			;50ba
	ret			;50bb
lee_celda_de_sala:		; Con HL=puntero a una posicion (byte suelto en (HL), palabra de 16 bits en (HL+2)/(HL+3)) y BC=(desplazamiento de fila con signo, ajuste de fila): calcula fila*96+columna y devuelve en A el byte del buffer de sala (0xE700+) en esa celda
	ld a,(hl)			;50bc
	add a,c			;50bd   ; A = (HL)+C, luego >>3 y &0x1F: convierte un byte "en bruto" (mas el ajuste C) en un indice de fila 0-31 -el mismo truco de 3 `rra` que tabla_de_atributos usa para nibbles, aqui sobre bits distintos-
	rra			;50be
	rra			;50bf
	rra			;50c0
	and 01fh		;50c1
	ld e,a			;50c3
	ld d,000h		;50c4
	ex de,hl			;50c6
	add hl,hl			;50c7   ; fila*32 (`add hl,hl` x5) mas fila*64 (duplicando ese resultado) = fila*96: el mismo stride de fila que confirmo la CORRECCION de carga_la_sala, con aritmetica independiente
	add hl,hl			;50c8
	add hl,hl			;50c9
	add hl,hl			;50ca
	add hl,hl			;50cb
	push bc			;50cc
	ld b,h			;50cd
	ld c,l			;50ce
	add hl,hl			;50cf
	add hl,bc			;50d0
	pop bc			;50d1
	ex de,hl			;50d2
	inc hl			;50d3
	inc hl			;50d4
	ld a,(hl)			;50d5   ; lee la posicion de 16 bits que trae el llamador en (HL+2)/(HL+3), formato low/high -HL en si mismo es un PUNTERO a un registro de posicion, no la posicion-
	inc hl			;50d6
	ld h,(hl)			;50d7
	ld l,a			;50d8
	push bc			;50d9
	ld c,b			;50da
	ld b,000h		;50db
	bit 7,c		;50dd   ; B (el segundo parametro) se extiende de signo a 16 bits (`bit 7,c / dec b`) antes de sumarlo: es un desplazamiento CON SIGNO sobre la posicion, para poder mirar celdas "por delante" o "por detras"
	jr z,L_50E2		;50df
	dec b			;50e1
L_50E2:
	add hl,bc			;50e2
	ld a,l			;50e3
	pop bc			;50e4
	srl h		;50e5   ; tres `srl h / rra`: desplaza la posicion (ya con el ajuste de B sumado) 3 bits a la derecha -SUPOSICION: la posicion se guarda en octavos de celda (subpixel), y este /8 la convierte en columna entera; no verificado en caliente-
	rra			;50e7
	srl h		;50e8
	rra			;50ea
	srl h		;50eb
	rra			;50ed
	ld l,a			;50ee
	add hl,de			;50ef
	ld de,0e700h		;50f0
	add hl,de			;50f3   ; fila*96 + columna + 0xE700: la misma base y el mismo stride que usa carga_la_sala para escribir, aqui para LEER
	ld a,(hl)			;50f4
	ret			;50f5

; ----------------------------------------------------------------------
; DATOS resto_50f6: Dos bytes (37 C9 = "scf / ret") entre lee_celda_de_sala y
;   0x50f8; ningun salto aterriza en ellos
;   0x50f6..0x50f8  (2 bytes)
DATA_resto_50f6:
	defb 037h,0c9h	; 50f6

; ======================================================================
; CODIGO 0x50f8..0x5168  (112 bytes)
; ======================================================================


celda_alineada_libre:		; Solo actua con la posicion alineada a celda (X mod 8 = 0): mira la celda 8 pixeles a un lado y 0x10 por debajo y devuelve Z si es del tipo 0x1x
	ld a,(hl)			;50f8   ; X mod 8: solo con la posicion cuadrada en la rejilla
	and 007h		;50f9
	ret nz			;50fb
	push bc			;50fc
	ld bc,00810h		;50fd   ; BC = 0x0810: ocho pixeles a un lado, 0x10 por debajo
	call lee_celda_de_sala		;5100
	and 0f0h		;5103   ; nibble alto 1 = solida
	cp 010h		;5105
	pop bc			;5107
	ret z			;5108
	and a			;5109   ; cualquier otra cosa: devuelve NZ y sin C
	ret			;510a
mueve_al_jugador:		; Aplica al jugador el movimiento que pide la entrada de 0xe135: si los bits 0-1 dicen que hay direccion y la celda en diagonal (una fila abajo, una columna a un lado) es de las que aceptan el movimiento diagonal (0x2x o 0x3x), pasa al estado 3 y desplaza la Y segun la tabla de 0x5168, que dibuja el perfil del escalon
	ld hl,0e135h		;510b   ; HL = 0xe135, la entrada de este fotograma
mueve_registro:		; Igual que mueve_al_jugador, pero para el registro que traiga el llamador en HL: lo usan tambien las entidades
	ld a,(hl)			;510e   ; A = la entrada del registro
	and 003h		;510f   ; bits 0-1: hay direccion pedida
	jr z,$+95		;5111   ; sin direccion: se va al final sin hacer nada
	rra			;5113
	jr nc,$+95		;5114   ; el bit 0 tiene que estar puesto
	inc hl			;5116   ; HL avanza cuatro bytes hasta la X del registro
	inc hl			;5117
	inc hl			;5118
	inc hl			;5119
	ld a,(hl)			;511a
	and 007h		;511b   ; X mod 8: la posicion dentro de la celda
	jr z,$+83		;511d   ; con la X cuadrada, se va al final
	sub 005h		;511f   ; resto por debajo de 5: B = 0x22; a partir de 5: B = 0x21
	ld b,022h		;5121
	jr c,L_5126		;5123
	dec b			;5125
L_5126:
	dec hl			;5126   ; HL vuelve a la Y del registro
	dec hl			;5127
	push hl			;5128
	call lee_celda_propia		;5129   ; lee la celda de esa posicion; HL queda apuntando al buffer de sala
	ld a,061h		;512c
	call suma_a_hl		;512e   ; HL += 0x61 = 97: una fila mas abajo (96) y una columna a la derecha
	ld a,(hl)			;5131   ; A = esa celda diagonal; C la guarda
	ld c,a			;5132
	pop hl			;5133
	cp b			;5134   ; comparada con el tipo esperado (0x21 o 0x22)
	jr z,aplica_paso_diagonal		;5135
	push af			;5137
	ld a,b			;5138
	add a,010h		;5139   ; si no cuadra, prueba tambien con 0x10 mas: los tipos 0x31/0x32
	ld b,a			;513b
	pop af			;513c
	cp b			;513d
	jr nz,$+50		;513e   ; sigue sin cuadrar: no hay movimiento diagonal, se va al final
aplica_paso_diagonal:		; La celda diagonal acepta el paso: guarda en 0xe143 el sentido (bit 0 invertido del tipo de celda), desplaza la Y segun la tabla de 0x5168 indexada por X mod 8, y deja el registro en estado 3
	and 001h		;5140   ; bit 0 del tipo de celda, invertido: el sentido del escalon
	xor 001h		;5142
	ld b,a			;5144
	ld a,(0e14dh)		;5145   ; (0xe14d): con el puesto, no se toca el sentido guardado
	and a			;5148
	jr nz,desplaza_y_por_tabla		;5149
	ld a,b			;514b
	ld (0e143h),a		;514c   ; (0xe143) := el sentido del escalon
desplaza_y_por_tabla:		; Suma a la Y del registro el valor que la tabla de 0x5168 (0,-1,-2,-3,-4,-3,-2,-1) asigna a la X mod 8, y deja el estado del registro en 3
	inc hl			;514f   ; HL avanza a la X del registro
	inc hl			;5150
	ld a,(hl)			;5151   ; A = la X
	dec hl			;5152   ; HL vuelve a la Y
	dec hl			;5153
	ld de,05168h		;5154   ; DE = la tabla de perfil de 0x5168
	and 007h		;5157   ; X mod 8: la posicion dentro de la celda
	call suma_a_de		;5159   ; DE += esa posicion
	ld a,(de)			;515c   ; A = el desplazamiento de Y de esa posicion
	add a,(hl)			;515d   ; Y += ese desplazamiento
	ld (hl),a			;515e
	dec hl			;515f   ; HL-3: el byte de estado del registro
	dec hl			;5160
	dec hl			;5161
	ld (hl),003h		;5162   ; estado := 3
	xor a			;5164   ; devuelve Z y sin C: se ha movido
	cp 000h		;5165
	ret			;5167

; ----------------------------------------------------------------------
; DATOS perfil_del_escalon: Los ocho desplazamientos de Y del paso en diagonal
;   (00 FF FE FD FC FD FE FF = 0,-1,-2,-3,-4,-3,-2,-1), uno por cada posicion
;   de la X dentro de la celda. desplaza_y_por_tabla (0x5154) los indexa con X
;   mod 8: dibujan el perfil en V del escalon
;   0x5168..0x5170  (8 bytes)
DATA_perfil_del_escalon:
	defb 000h	; 5168
	defb 0ffh	; 5169
	defb 0feh	; 516a
	defb 0fdh	; 516b
	defb 0fch	; 516c
	defb 0fdh	; 516d
	defb 0feh	; 516e
	defb 0ffh	; 516f

; ======================================================================
; CODIGO 0x5170..0x51e9  (121 bytes)
; ======================================================================


sin_movimiento:		; Devuelve A=0xFF con NZ: la salida "no se ha podido mover" que comparten mueve_registro y sube_un_escalon
	xor a			;5170   ; A = 0xFF con NZ
	dec a			;5171
	ret			;5172
sube_un_escalon:		; Variante de mueve_registro para el otro tipo de escalon: exige que la X mod 8 valga exactamente 4 y que la celda dos filas mas abajo y una columna a la derecha sea del tipo 0x16 o 0x17; entonces sube la Y cuatro pixeles y deja el estado en 3
	inc hl			;5173   ; HL avanza cuatro bytes hasta la X del registro
	inc hl			;5174
	inc hl			;5175
	inc hl			;5176
	ld a,(hl)			;5177
	and 007h		;5178   ; X mod 8, que aqui tiene que valer exactamente 4
	cp 004h		;517a
	jr nz,sin_movimiento		;517c   ; cualquier otra alineacion: no se puede
	dec hl			;517e   ; HL vuelve a la Y del registro
	dec hl			;517f
	push hl			;5180
	call lee_celda_propia		;5181   ; lee la celda de esa posicion
	ld a,0c1h		;5184
	call suma_a_hl		;5186   ; HL += 0xC1 = 193: dos filas mas abajo (192) y una columna a la derecha
	ld a,(hl)			;5189   ; A = esa celda; C la guarda
	ld c,a			;518a
	pop hl			;518b
	cp 016h		;518c   ; solo los tipos 0x16 y 0x17 valen
	jr z,guarda_sentido_del_escalon		;518e
	cp 017h		;5190
	jr nz,sin_movimiento		;5192
guarda_sentido_del_escalon:		; Guarda en 0xe143 el bit 0 del tipo de celda (el sentido del escalon) salvo que 0xe14d lo bloquee, y cae en sube_cuatro_pixeles
	ld a,(0e14dh)		;5194   ; (0xe14d): con el puesto, no se toca el sentido guardado
	and a			;5197
	jr nz,sube_cuatro_pixeles		;5198
	ld a,c			;519a
	and 001h		;519b
	ld (0e143h),a		;519d   ; (0xe143) := bit 0 del tipo de celda
sube_cuatro_pixeles:		; Sube la Y del registro cuatro pixeles y le deja el estado en 3
	ld a,(hl)			;51a0   ; Y += 4
	add a,004h		;51a1
	ld (hl),a			;51a3
	dec hl			;51a4   ; HL-3: el byte de estado del registro
	dec hl			;51a5
	dec hl			;51a6
	ld (hl),003h		;51a7   ; estado := 3
	xor a			;51a9   ; devuelve Z y sin C: se ha movido
	cp 000h		;51aa
	ret			;51ac
mira_celda_hacia_donde_empuja:		; Con la entrada del jugador: si trae los bits 2-3 puestos, mira que hay en la celda hacia la que empuja y devuelve C cuando es del tipo que corresponde (0x5x si la pose esta alineada, 0x1x si no)
	ld hl,0e135h		;51ad   ; HL = 0xe135, la entrada de este fotograma
mira_celda_del_registro:		; Igual, pero para el registro que traiga el llamador
	ld a,(hl)			;51b0   ; A = la entrada del registro
	and 00ch		;51b1   ; bits 2-3: sin ellos no se empuja
	ret z			;51b3
	inc hl			;51b4   ; HL avanza al byte de direccion
lee_direccion_y_mira:		; Entrada que salta la comprobacion de la entrada: toma B del byte de direccion que apunta HL y sigue
	ld b,(hl)			;51b5   ; B = el byte de direccion
mira_celda_con_direccion:		; Nucleo compartido: lee la celda de la posicion (HL+1), elige el tipo que hay que encontrar segun la pose -0x5x con la pose alineada, 0x1x con la pose 4- y la busca en esa celda y en la de una fila mas abajo, devolviendo C si la encuentra
	inc hl			;51b6   ; HL avanza a la posicion; DE guarda una copia del puntero
	ld d,h			;51b7
	ld e,l			;51b8
	call lee_celda_propia		;51b9   ; lee la celda de esa posicion
	inc de			;51bc   ; DE+2: la X del registro
	inc de			;51bd
	ld a,(de)			;51be
	and 007h		;51bf   ; X mod 8: la alineacion dentro de la celda
	ld c,050h		;51c1   ; por defecto se busca el tipo 0x5x
	jr z,L_51CB		;51c3   ; con la X cuadrada, se busca 0x5x
	cp 004h		;51c5   ; con la X en la posicion 4 se busca 0x1x; con cualquier otra, no se busca nada
	ld c,010h		;51c7
	jr nz,celda_no_encontrada		;51c9
L_51CB:
	bit 0,b		;51cb   ; bit 0 de la direccion: mirando a un lado, la celda es la de al lado
	jr nz,L_51D4		;51cd
	inc hl			;51cf   ; mirando al otro y con la X no cuadrada, dos celdas mas alla
	and a			;51d0
	jr z,L_51D4		;51d1
	inc hl			;51d3
L_51D4:
	ld a,(hl)			;51d4   ; el nibble alto de la celda
	and 0f0h		;51d5
	cp c			;51d7   ; si coincide con el tipo buscado, encontrada
	jr z,celda_encontrada		;51d8
	ld a,060h		;51da   ; si no, prueba una fila mas abajo (HL += 0x60 = 96)
	call suma_a_hl		;51dc
	ld a,(hl)			;51df
	and 0f0h		;51e0
	cp c			;51e2   ; tampoco: no hay nada que empujar
	jr nz,celda_no_encontrada		;51e3
celda_encontrada:		; Devuelve C: la celda buscada esta ahi
	scf			;51e5   ; C = encontrada
	ret			;51e6
celda_no_encontrada:		; Devuelve NC: no hay ninguna celda del tipo buscado
	and a			;51e7   ; NC = no encontrada
	ret			;51e8

; ----------------------------------------------------------------------
; DATOS guion_51e9: Guion CON direccion (L_4514), destino VRAM 0x1800,
;   apuntado por tabla_5050_indice[0]
;   0x51e9..0x52a5  (188 bytes)
DATA_guion_51e9:
	defb 000h,018h,086h,000h,001h,003h,000h,007h,008h,003h,000h,08dh,001h,002h,002h,001h	; 51e9  ................
	defb 000h,000h,001h,000h,0c0h,0e0h,000h,0f0h,008h,003h,000h,087h,0c0h,060h,000h,0c0h	; 51f9  .............`..
	defb 000h,000h,0c0h,003h,000h,08ch,003h,000h,003h,007h,003h,001h,000h,001h,001h,000h	; 5209  ................
	defb 001h,001h,004h,000h,093h,0e0h,000h,0f0h,0e0h,0f0h,0c0h,000h,080h,0e0h,000h,080h	; 5219  ................
	defb 080h,000h,000h,001h,003h,000h,007h,008h,003h,000h,003h,003h,002h,009h,003h,000h	; 5229  ................
	defb 085h,0c0h,0e0h,000h,0f0h,008h,003h,000h,087h,0c0h,000h,0c0h,0c0h,000h,000h,0e0h	; 5239  ................
	defb 003h,000h,086h,003h,000h,003h,007h,003h,001h,003h,000h,002h,006h,005h,000h,093h	; 5249  ................
	defb 0e0h,000h,0f0h,0f0h,0e0h,0c0h,000h,0e0h,000h,000h,0c0h,0c0h,000h,000h,001h,003h	; 5259  ................
	defb 000h,007h,008h,003h,000h,002h,003h,002h,001h,089h,000h,00ch,008h,000h,0c0h,0e0h	; 5269  ................
	defb 000h,0f0h,008h,003h,000h,086h,060h,0c0h,0c0h,0c8h,088h,018h,004h,000h,08ch,003h	; 5279  ......`.........
	defb 000h,003h,007h,003h,001h,004h,00ch,004h,002h,007h,002h,004h,000h,08bh,0e0h,000h	; 5289  ................
	defb 0f0h,0f0h,0e0h,0c0h,080h,030h,020h,000h,070h,001h,000h,000h	; 5299  .....0 .p...

; ----------------------------------------------------------------------
; DATOS guion_52a5: Guion CON direccion (L_4514), destino VRAM 0x1800,
;   apuntado por tabla_5050_indice[1]
;   0x52a5..0x53d8  (307 bytes)
DATA_guion_52a5:
	defb 000h,018h,086h,000h,001h,003h,000h,007h,008h,003h,000h,08ch,001h,003h,003h,001h	; 52a5  ................
	defb 000h,000h,001h,000h,0c0h,0e4h,00ch,0fch,004h,00ch,087h,0d6h,0f0h,084h,0cah,000h	; 52b5  ................
	defb 000h,0c0h,003h,000h,086h,003h,000h,003h,007h,003h,001h,004h,000h,002h,001h,004h	; 52c5  ................
	defb 000h,093h,0e0h,000h,0f0h,0f0h,0e0h,0c0h,008h,00ch,070h,000h,080h,080h,000h,000h	; 52d5  ..........p.....
	defb 001h,003h,000h,007h,008h,003h,000h,003h,003h,002h,009h,003h,000h,084h,0c8h,0d8h	; 52e5  ................
	defb 018h,0f8h,004h,018h,087h,07ch,000h,0d4h,0c0h,000h,000h,0e0h,003h,000h,086h,003h	; 52f5  .....|..........
	defb 000h,003h,007h,003h,001h,003h,000h,002h,006h,005h,000h,082h,0e0h,000h,003h,0e0h	; 5305  ................
	defb 08eh,0c0h,080h,0f8h,000h,000h,0c0h,0c0h,000h,000h,001h,003h,000h,007h,008h,003h	; 5315  ................
	defb 000h,002h,003h,002h,001h,092h,000h,00ch,008h,000h,0c2h,0e6h,006h,0f6h,00eh,006h	; 5325  ................
	defb 006h,00fh,060h,0e5h,0c0h,0c8h,088h,018h,004h,000h,08ch,003h,000h,003h,007h,003h	; 5335  ..`.............
	defb 001h,004h,00ch,008h,002h,007h,002h,004h,000h,096h,0e0h,000h,0f0h,0f0h,0e0h,0c0h	; 5345  ................
	defb 09eh,018h,000h,000h,070h,000h,000h,0c0h,0e1h,077h,030h,003h,020h,004h,002h,001h	; 5355  ....p....w0. ...
	defb 003h,003h,003h,000h,091h,00eh,000h,0c0h,0e0h,000h,0f0h,088h,050h,020h,000h,0e0h	; 5365  ............P ..
	defb 0c0h,080h,080h,000h,000h,038h,003h,000h,086h,00bh,01ch,00fh,01bh,01dh,00eh,003h	; 5375  .....8..........
	defb 000h,083h,003h,007h,006h,004h,000h,08ch,0e0h,000h,070h,0a0h,0c0h,0e0h,000h,000h	; 5385  ..........p.....
	defb 060h,070h,030h,030h,003h,000h,08ah,001h,003h,004h,008h,004h,000h,003h,002h,007h	; 5395  `p00............
	defb 003h,003h,000h,08dh,00eh,000h,000h,0c0h,0e0h,010h,008h,010h,020h,040h,000h,080h	; 53a5  ............ @..
	defb 040h,003h,000h,081h,070h,004h,000h,08bh,003h,007h,003h,001h,000h,001h,000h,004h	; 53b5  @...p...........
	defb 006h,006h,00ch,005h,000h,08ch,0e0h,0f0h,0e0h,0c0h,080h,0e0h,070h,090h,0e0h,060h	; 53c5  ............p..`
	defb 060h,000h,000h	; 53d5

; ----------------------------------------------------------------------
; DATOS guion_53d8: Guion CON direccion (L_4514), destino VRAM 0x1800,
;   apuntado por tabla_5050_indice[2]
;   0x53d8..0x5511  (313 bytes)
DATA_guion_53d8:
	defb 000h,018h,096h,000h,001h,003h,000h,067h,004h,018h,00ch,006h,001h,003h,003h,001h	; 53d8  .......g........
	defb 000h,000h,001h,000h,0c0h,0e0h,000h,0f0h,008h,003h,000h,002h,0c0h,08fh,080h,0c0h	; 53e8  ................
	defb 000h,000h,0c0h,000h,008h,010h,003h,010h,033h,027h,023h,021h,002h,003h,000h,002h	; 53f8  ........3'#!....
	defb 001h,004h,000h,096h,0e0h,000h,0f0h,0f0h,0e0h,0c0h,020h,010h,078h,000h,080h,080h	; 5408  .......... .x...
	defb 000h,000h,001h,003h,000h,007h,060h,020h,008h,004h,003h,003h,002h,009h,003h,000h	; 5418  ......` ........
	defb 085h,0c0h,0e0h,000h,0f0h,008h,003h,000h,095h,0c0h,000h,0c0h,0c0h,000h,000h,0e0h	; 5428  ................
	defb 000h,000h,008h,01bh,010h,013h,017h,063h,041h,040h,000h,000h,006h,006h,005h,000h	; 5438  .......cA@......
	defb 097h,0e0h,000h,0f0h,0f0h,0e0h,0c0h,000h,0e0h,000h,000h,0c0h,0c0h,000h,000h,001h	; 5448  ................
	defb 003h,000h,007h,048h,080h,018h,00eh,003h,003h,001h,089h,000h,00ch,008h,000h,0c0h	; 5458  ...H............
	defb 0e0h,000h,0f0h,008h,003h,000h,086h,060h,0e8h,0c0h,0c8h,088h,018h,003h,000h,08dh	; 5468  .......`........
	defb 010h,033h,020h,023h,067h,0e3h,081h,084h,08ch,008h,002h,007h,002h,004h,000h,08bh	; 5478  .3 #g...........
	defb 0e0h,000h,0f0h,0f0h,0e0h,0c0h,090h,010h,000h,000h,070h,003h,000h,085h,001h,003h	; 5488  ..........p.....
	defb 000h,007h,008h,003h,000h,003h,003h,003h,000h,091h,00eh,000h,000h,0f0h,010h,0f0h	; 5498  ................
	defb 010h,010h,000h,020h,0a0h,040h,080h,080h,000h,000h,01ch,003h,000h,086h,003h,000h	; 54a8  ... .@..........
	defb 003h,00fh,007h,003h,003h,000h,093h,003h,007h,006h,000h,010h,0f8h,004h,0e2h,000h	; 54b8  ................
	defb 0e0h,0e0h,0f0h,0d0h,040h,080h,060h,060h,030h,018h,003h,000h,09eh,001h,003h,004h	; 54c8  ....@.``0.......
	defb 008h,004h,000h,003h,002h,007h,003h,000h,000h,008h,00eh,000h,000h,0c0h,0e0h,010h	; 54d8  ................
	defb 008h,010h,020h,080h,040h,0a0h,050h,018h,008h,000h,060h,004h,000h,08bh,003h,007h	; 54e8  .. .@.P...`.....
	defb 003h,001h,000h,001h,000h,004h,006h,004h,004h,005h,000h,08ch,0e0h,0f0h,0e0h,0c0h	; 54f8  ................
	defb 000h,080h,040h,0a2h,0c2h,042h,046h,00ch,000h	; 5508  ..@..BF..

; ----------------------------------------------------------------------
; DATOS guion_5511: Guion CON direccion (L_4514), destino VRAM 0x1940, cargado
;   directo en 0x5020
;   0x5511..0x5571  (96 bytes)
DATA_guion_5511:
	defb 040h,019h,082h,000h,003h,004h,007h,086h,003h,003h,007h,004h,007h,007h,004h,003h	; 5511  @...............
	defb 092h,000h,0c0h,0e0h,040h,0e0h,0e0h,0c0h,080h,0e0h,080h,060h,080h,080h,000h,000h	; 5521  ....@......`....
	defb 080h,000h,003h,004h,007h,08eh,003h,003h,007h,004h,007h,007h,01fh,01eh,011h,001h	; 5531  ................
	defb 000h,0c0h,0e0h,040h,003h,0e0h,08bh,0c0h,080h,0e0h,0b0h,0c0h,0c0h,080h,080h,0c0h	; 5541  ...@............
	defb 000h,003h,004h,007h,09ah,003h,003h,007h,006h,005h,001h,003h,007h,00eh,008h,000h	; 5551  ................
	defb 0c0h,0e0h,040h,0e0h,000h,0e0h,0c0h,0e0h,078h,048h,0c0h,0e8h,0f8h,018h,000h,000h	; 5561  ..@.....xH......

; ----------------------------------------------------------------------
; DATOS guion_5571: Guion CON direccion (L_4514), destino VRAM 0x1ea0, cargado
;   directo en 0x501a
;   0x5571..0x5613  (162 bytes)
DATA_guion_5571:
	defb 0a0h,01eh,002h,000h,08dh,020h,000h,008h,004h,000h,000h,0b0h,000h,000h,004h,008h	; 5571  ..... ..........
	defb 000h,020h,003h,000h,08dh,082h,000h,088h,090h,000h,000h,00dh,000h,000h,090h,088h	; 5581  . ..............
	defb 000h,082h,00ah,000h,002h,044h,085h,07eh,010h,010h,07eh,044h,018h,000h,008h,0ffh	; 5591  .....D.~..~D....
	defb 010h,000h,08fh,044h,07eh,010h,010h,07eh,044h,044h,07eh,010h,010h,07eh,044h,044h	; 55a1  ...D~..~DD~..~DD
	defb 07eh,010h,011h,000h,010h,0ffh,012h,000h,08ch,001h,00ah,01fh,01fh,00fh,017h,03fh	; 55b1  ~..............?
	defb 01fh,007h,00fh,00bh,006h,004h,000h,08ch,080h,0e0h,0f0h,0f0h,0e0h,0f0h,0e8h,0f8h	; 55c1  ................
	defb 0f8h,0d0h,0f0h,0c0h,006h,000h,087h,002h,007h,003h,005h,007h,003h,001h,009h,000h	; 55d1  ................
	defb 086h,0c0h,0a0h,0f0h,0d0h,0e0h,0a0h,006h,000h,087h,0c0h,0e0h,074h,038h,01ch,02eh	; 55e1  ............t8..
	defb 004h,019h,000h,087h,003h,007h,02eh,01ch,038h,074h,020h,019h,000h,087h,040h,0e8h	; 55f1  ........8t ...@.
	defb 070h,038h,05ch,00eh,006h,019h,000h,087h,002h,017h,00eh,01ch,03ah,070h,060h,019h	; 5601  p8\.........:p`.
	defb 000h,000h	; 5611

; ----------------------------------------------------------------------
; DATOS guion_5613 (tramo): Guion para L_451a (sin direccion), cargado en
;   0x4fd9
;   0x5613..0x569c  (137 bytes)  de 0x5613..0x574a (311 bytes)
DATA_guion_5613:
	defb 003h,0feh,081h,000h,003h,0efh,083h,000h,0ffh,0ffh,006h,000h,003h,0ffh,005h,000h	; 5613  ................
	defb 084h,080h,0c1h,063h,000h,003h,0f7h,082h,000h,081h,004h,000h,089h,0c1h,0e3h,000h	; 5623  ...c............
	defb 0c0h,0e0h,074h,038h,01ch,028h,006h,000h,092h,005h,003h,007h,002h,000h,000h,060h	; 5633  ..t8.(.........`
	defb 0e0h,0c0h,080h,000h,080h,050h,0e0h,070h,0b8h,01ch,00ch,004h,000h,08ch,001h,000h	; 5643  .....P.p........
	defb 001h,003h,007h,006h,000h,000h,040h,0e0h,0c0h,0a0h,003h,000h,084h,024h,018h,018h	; 5653  ......@......$..
	defb 07eh,003h,018h,088h,020h,018h,00ch,00ch,01ah,033h,061h,0c0h,026h,000h,0a2h,049h	; 5663  ~... ....3a.&..I
	defb 02ah,002h,001h,004h,002h,000h,006h,000h,000h,040h,080h,020h,040h,000h,060h,000h	; 5673  *........@. @.`.
	defb 000h,0ffh,080h,0eeh,0eeh,080h,0bbh,0bbh,080h,0ffh,001h,0efh,0efh,001h,0bbh,0bbh	; 5683  ................
	defb 001h,030h,000h,082h,07eh,081h,003h,018h,002h	; 5693  .0..~....

; ----------------------------------------------------------------------
; DATOS resto_569c: Dos bytes (3C 85) que un jr incondicional salta siempre;
;   sin entrada conocida
;   0x569c..0x569e  (2 bytes)
DATA_resto_569c:
	defb 03ch,085h	; 569c

; ----------------------------------------------------------------------
; DATOS guion_5613 (tramo): Guion para L_451a (sin direccion), cargado en
;   0x4fd9
;   0x569e..0x574a  (172 bytes)  de 0x5613..0x574a (311 bytes)
DATA_guion_5613_569E:
	defb 018h,07eh,0e7h,0c3h,0c3h,003h,0e7h,083h,0ffh,081h,07eh,006h,000h,005h,0f0h,083h	; 569e  .~........~.....
	defb 0b0h,010h,0d0h,004h,00fh,002h,00eh,084h,008h,00bh,070h,070h,006h,0f0h,008h,00fh	; 56ae  ..........pp....
	defb 081h,0ffh,004h,000h,087h,0fch,0f0h,0c0h,0ffh,0fch,0f0h,0c0h,008h,000h,002h,001h	; 56be  ................
	defb 002h,00fh,002h,000h,003h,01fh,08dh,0ffh,000h,000h,0ffh,000h,0ffh,000h,000h,0ffh	; 56ce  ................
	defb 000h,000h,00ah,00ah,004h,00eh,002h,00ah,002h,0e0h,004h,0a0h,002h,0e0h,008h,03fh	; 56de  ...............?
	defb 008h,070h,0b0h,0ffh,0ddh,0ddh,081h,0f7h,0f7h,081h,0ddh,0ddh,081h,0f7h,0f7h,081h	; 56ee  .p..............
	defb 0ddh,0ddh,081h,0f7h,0f7h,081h,0ddh,0ddh,081h,0f7h,0ffh,00fh,00dh,00dh,008h,00fh	; 56fe  ................
	defb 00fh,008h,00dh,00dh,008h,00fh,00fh,008h,00dh,00dh,008h,0d0h,010h,070h,070h,010h	; 570e  .............pp.
	defb 0d0h,0d0h,010h,003h,00fh,09dh,008h,00dh,00dh,008h,00fh,0f9h,003h,000h,06eh,02eh	; 571e  ..............n.
	defb 000h,00eh,006h,0f9h,003h,000h,0f0h,000h,0e0h,0e0h,0efh,000h,0eeh,06eh,02eh,000h	; 572e  .............n..
	defb 00eh,006h,002h,003h,000h,085h,0f0h,000h,0e0h,0e0h,0efh,000h	; 573e  ............

; ----------------------------------------------------------------------
; DATOS guion_574a: Guion para L_451a, cargado 6 veces en bucle desde 0x5001;
;   0x57b8 (100 B dentro) se llama tambien aparte, en 0x4ff3
;   0x574a..0x57cd  (131 bytes)
DATA_guion_574a:
	defb 088h,000h,03ch,07eh,0bfh,09fh,0dfh,07eh,03ch,000h,003h,0f0h,005h,0a0h,005h,0f0h	; 574a  ..<~...~<.......
	defb 003h,0a0h,007h,0f0h,004h,0a0h,005h,0f0h,005h,0a0h,003h,0f0h,005h,0a0h,003h,0f0h	; 575a  ................
	defb 005h,0a0h,003h,0f0h,004h,090h,004h,060h,020h,000h,018h,0a0h,040h,050h,082h,090h	; 576a  .......` ...@P..
	defb 096h,003h,0f6h,003h,0a6h,081h,060h,003h,06ah,004h,06fh,081h,096h,007h,090h,081h	; 577a  ......`.j.o.....
	defb 03eh,004h,03ah,003h,030h,081h,03eh,003h,03ah,006h,030h,08eh,03eh,03fh,03fh,03eh	; 578a  >.:.0.>.:.0.>??>
	defb 03fh,03fh,03eh,03fh,03eh,03fh,03fh,03eh,03fh,03fh,005h,0eah,003h,0a0h,081h,0eah	; 579a  ??>?>??>??......
	defb 007h,0a0h,005h,0f0h,083h,0e0h,0f0h,0e0h,003h,0f0h,002h,0e0h,00bh,0feh,008h,050h	; 57aa  ...............P
	defb 008h,0f0h,008h,050h,008h,0f0h,038h,030h,082h,0eah,0f9h,006h,0f0h,082h,0eah,0efh	; 57ba  ...P..80........
	defb 016h,0f0h,000h	; 57ca

; ----------------------------------------------------------------------
; DATOS guion_57cd: Guion para L_451a, cargado en 0x5011; cierra justo donde
;   ya habia codigo conocido (0x57da)
;   0x57cd..0x57da  (13 bytes)
DATA_guion_57cd:
	defb 008h,040h,008h,070h,008h,0d0h,008h,0a0h,008h,020h,008h,0e0h,000h	; 57cd  .@.p..... ...

; ======================================================================
; CODIGO 0x57da..0x57e9  (15 bytes)
; ======================================================================


recorre_entidades_17:		; Recorre la lista de 17 bytes desde el indice 0 y despacha cada entidad por su campo 0 con tabla_57e9 (10 entradas), dejando apilado 0x5adf como cierre
	xor a			;57da   ; indice de entidad := 0
	ld (0e262h),a		;57db
L_57DE:
	ld hl,05adfh		;57de   ; apila 0x5adf: el cierre del recorrido
	push hl			;57e1
	xor a			;57e2
	call campo_de_cuchillo		;57e3   ; campo 0 de la entidad
	call despacha_tabla_siguiente		;57e6   ; salta por tabla_57e9 (10 estados)

; ----------------------------------------------------------------------
; DATOS tabla_57e9: 10 entradas, llamada L_404B desde 0x57e6
;   0x57e9..0x57fd  (20 bytes)
DATA_tabla_57e9:
	defw 057fdh,05837h,05837h,05837h,05838h,05894h,059c4h,059e0h	; 57e9
	defw 05a47h,05ab6h	; 57f9  -> entidad_espera_alineada remata_paso_de_entidad

; ======================================================================
; CODIGO 0x57fd..0x588f  (146 bytes)
; ======================================================================


entidad_estampa_su_celda:		; Entrada 0 de tabla_57e9: cuenta un paso, lee la celda donde esta la entidad y, si no es del tipo 0x3x, la guarda en su campo 10
	xor a			;57fd
	call campo_de_cuchillo		;57fe   ; campo 0 de la entidad
	inc (hl)			;5801   ; cuenta un paso
	inc hl			;5802
	inc hl			;5803
	call lee_celda_propia		;5804   ; lee su celda de sala
	ex de,hl			;5807
	ld a,00ah		;5808
	call campo_de_cuchillo		;580a   ; campo 10 de la entidad
	ld a,(de)			;580d   ; A = la celda; B la guarda entera
	ld b,a			;580e
	and 0f0h		;580f   ; nibble alto
	cp 030h		;5811   ; el tipo 0x3x no se guarda
	jr z,entidad_marca_su_celda		;5813
	ld (hl),b			;5815   ; los demas, al campo 10
entidad_marca_su_celda:		; Escribe en la celda de sala el tipo que corresponde -0x31 se deja, 0x21 y 0x22 suben 0x10, y cualquier otro pasa a 0x30- y dibuja el patron 0x4b si esta visible
	ld a,b			;5816   ; A = la celda
	cp 031h		;5817   ; el tipo 0x31 tiene su propio camino
	jr z,L_5833		;5819
	cp 021h		;581b   ; el tipo 0x21...
	jr z,L_5823		;581d
	cp 022h		;581f   ; ...y el 0x22 suben 0x10
	jr nz,L_5827		;5821
L_5823:
	add a,010h		;5823   ; mas 0x10: pasan a 0x31 y 0x32
	jr L_5829		;5825
L_5827:
	ld a,030h		;5827   ; cualquier otro pasa a 0x30
L_5829:
	ld (de),a			;5829   ; escrito en la celda de sala
	xor a			;582a
	call campo_de_cuchillo		;582b   ; campo 0 de la entidad
	ld a,04bh		;582e   ; patron 0x4b, el de la entidad
	jp dibuja_si_esta_visible		;5830   ; dibujado si esta visible
L_5833:
	ld a,031h		;5833
	jr L_5829		;5835
L_5837:
	ret			;5837
crea_entidad_desde_el_jugador:		; Rellena una entidad de la lista de 17 bytes a partir del estado del jugador: copia once bytes de plantilla desde 0x6573 al campo 6, cuenta un paso, copia cinco bytes mas desde 0xe136 (direccion y posicion), alinea la X a multiplo de 8 con el bit 2 puesto segun a que lado mire, y guarda en el campo 10 la celda de sala donde ha caido
	ld a,006h		;5838   ; efecto de sonido 0x06, el de crear la entidad
	call reproduce_efecto		;583a
	ld a,006h		;583d
	call campo_de_cuchillo		;583f   ; campo 6 de la entidad
	ex de,hl			;5842
	ld hl,06573h		;5843   ; HL = la plantilla de 0x6573
	ld bc,0000bh		;5846   ; once bytes de plantilla
	ldir		;5849
	call cuenta_un_paso_de_entidad		;584b   ; cuenta un paso en el campo 0
	inc hl			;584e
	ld de,0e136h		;584f   ; DE = 0xe136, la direccion del jugador
	ex de,hl			;5852
	ld a,(hl)			;5853   ; A = el byte de direccion, que hace falta para alinear la X
	ld bc,00005h		;5854   ; cinco bytes: direccion y posicion del jugador, copiados tal cual
	ldir		;5857
	dec de			;5859
	dec de			;585a
	dec hl			;585b
	dec hl			;585c
	ld b,008h		;585d   ; por defecto la X se corre 8 pixeles
	rr a		;585f   ; bit 0 de la direccion: a que lado mira
	jr nc,alinea_x_de_la_entidad		;5861
	ld b,000h		;5863   ; mirando al otro lado, no se corre nada
alinea_x_de_la_entidad:		; Alinea a multiplo de 8 la X de la entidad recien creada y le pone el bit 2, dejandola en el centro de la celda; luego guarda en el campo 10 la celda de sala correspondiente
	ld a,(hl)			;5865   ; A = la X copiada del jugador
	add a,b			;5866   ; mas el desplazamiento de 8 o 0
	and 0f8h		;5867   ; alineada a multiplo de 8
	set 2,a		;5869   ; con el bit 2 puesto: el centro de la celda
	ld (de),a			;586b
	dec de			;586c
	dec de			;586d
	ex de,hl			;586e
	call lee_celda_propia		;586f   ; lee la celda de sala de esa posicion
	ex de,hl			;5872
	ld a,00ah		;5873
	call campo_de_cuchillo		;5875   ; campo 10 de la entidad
	ex de,hl			;5878
	ldi		;5879   ; y guarda ahi los dos bytes de esa celda
	ldi		;587b
	ret			;587d
patron_de_la_entidad:		; Traduce el campo 4 de la entidad (dos bits, tras dos rra) en un numero de patron leyendo la tabla de 0x588f (0x45, 0x46, 0x48, 0x49, 0x4b)
	ld a,004h		;587e   ; campo 4 de la entidad
	call campo_de_cuchillo		;5880
	rra			;5883   ; dos rra y &3: se queda con dos bits del campo
	rra			;5884
	and 003h		;5885
	ld de,0588fh		;5887   ; DE = la tabla de patrones de 0x588f
	call suma_a_de		;588a   ; DE += ese indice
	ld a,(de)			;588d   ; A = el numero de patron
	ret			;588e

; ----------------------------------------------------------------------
; DATOS patrones_de_entidad: Los cinco numeros de patron de la entidad grande
;   (0x45, 0x46, 0x48, 0x49, 0x4B), indexados por patron_de_la_entidad
;   (0x5887) con dos bits del campo 4
;   0x588f..0x5894  (5 bytes)
DATA_patrones_de_entidad:
	defb 045h	; 588f
	defb 046h	; 5890
	defb 048h	; 5891
	defb 049h	; 5892
	defb 04bh	; 5893

; ======================================================================
; CODIGO 0x5894..0x5a3f  (427 bytes)
; ======================================================================


mueve_entidad_grande:		; Paso completo de una entidad de la lista de 17 bytes: lee su posicion del campo 6, la avanza con 0x73f6 y, segun en que multiplo de 4 y de 8 caiga, la redibuja, comprueba si ha llegado a una celda del tipo 0x5x -y entonces cuenta uno y estampa el bloque- o la deja quieta
	ld a,006h		;5894   ; campo 6 de la entidad
	call campo_de_cuchillo		;5896
	ld e,(hl)			;5899   ; DE = lo que hay ahi, un puntero
	inc hl			;589a
	ld d,(hl)			;589b
	ld a,003h		;589c   ; campo 3 de la entidad
	call campo_de_cuchillo		;589e
	call avanza_posicion_24_bits		;58a1   ; le da un paso con 0x73f6
	ld a,d			;58a4
	and 003h		;58a5   ; D mod 4: solo actua en uno de cada cuatro
	ret nz			;58a7
	ld a,d			;58a8
	and 007h		;58a9   ; D mod 8: si cae en cero, camino distinto
	jr z,entidad_en_celda_alineada		;58ab
	ld a,d			;58ad
	cp 008h		;58ae   ; por debajo de 8 no hace nada
	ret c			;58b0
	cp 0fch		;58b1   ; y por encima de 0xFC tampoco: son los margenes
	ret nc			;58b3
	call patron_de_la_entidad		;58b4   ; A = el numero de patron de la entidad
	dec hl			;58b7   ; HL retrocede cuatro bytes hasta la posicion
	dec hl			;58b8
	dec hl			;58b9
	dec hl			;58ba
	call dibuja_si_esta_visible		;58bb   ; comprueba si toca dibujar y calcula la direccion de VRAM
	inc a			;58be   ; el patron siguiente
	inc hl			;58bf
	call 0004dh		;58c0   ; BIOS WRTVRM - Writes data in VRAM | y lo escribe en la tabla de nombres
	ld a,001h		;58c3
	call campo_de_cuchillo		;58c5   ; campo 1 de la entidad
	push hl			;58c8
	ld a,(hl)			;58c9   ; A = ese campo
	inc hl			;58ca
	push af			;58cb
	call lee_celda_propia		;58cc   ; lee la celda de sala donde esta
	pop af			;58cf
	rra			;58d0   ; bit 0 del campo 1: elige entre esta celda y la de al lado
	jr c,entidad_encuentra_bloque		;58d1
	inc hl			;58d3
entidad_encuentra_bloque:		; Comprueba si la celda que ha alcanzado la entidad es del tipo 0x5x: si lo es, cuenta uno en el campo anterior y estampa el bloque en pantalla pasando el byte por 0x5d52
	ld a,(hl)			;58d4   ; nibble alto de la celda
	and 0f0h		;58d5
	cp 050h		;58d7   ; el tipo 0x5x es el que interesa
	pop hl			;58d9
	ret nz			;58da   ; cualquier otro: no hay nada que hacer
	dec hl			;58db
	inc (hl)			;58dc   ; cuenta uno en el campo anterior
	push hl			;58dd
	ld a,00ah		;58de   ; campo 10 de la entidad
	call campo_de_cuchillo		;58e0
	ex de,hl			;58e3
	pop hl			;58e4
	push de			;58e5
	call traduce_celda_a_patron		;58e6   ; la traduccion de 0x5d52
	call dibuja_si_esta_visible		;58e9
	pop de			;58ec
	ret nz			;58ed   ; si no toca dibujar, se queda solo con el buffer
	inc hl			;58ee
	inc de			;58ef
	ld a,(de)			;58f0
	call traduce_celda_a_patron		;58f1   ; traduce el segundo byte
	jp 0004dh		;58f4   ; BIOS WRTVRM - Writes data in VRAM | y lo escribe en la tabla de nombres
entidad_en_celda_alineada:		; El camino de mueve_entidad_grande cuando la posicion cae justo en multiplo de 8: prepara IX con el campo 1, dibuja el patron y lee la celda contigua para decidir por donde sigue
	ld a,001h		;58f7
	call campo_de_cuchillo		;58f9   ; campo 1 de la entidad
	push hl			;58fc
	pop ix		;58fd   ; IX = ese campo, que las rutinas de abajo indexan
	call patron_de_la_entidad		;58ff   ; A = el numero de patron
	ld b,a			;5902
	xor a			;5903
	call campo_de_cuchillo		;5904   ; campo 0 de la entidad
	ld a,b			;5907
	call dibuja_si_esta_visible		;5908   ; dibuja el patron
	ld a,002h		;590b
	call campo_de_cuchillo		;590d   ; campo 2, la posicion
	call lee_celda_propia		;5910   ; lee la celda de sala de ahi
	ld a,(ix+000h)		;5913   ; (IX+0), el campo 1
	inc hl			;5916
	rr a		;5917   ; su bit 0 decide si mira la celda de al lado o la de dos mas alla
	push af			;5919
	jr nc,intercambia_celdas_de_entidad		;591a
	dec hl			;591c
	dec hl			;591d
intercambia_celdas_de_entidad:		; Segun el bit que saco el rr previo, intercambia los campos 9 y 10 de la entidad (las dos celdas que lleva guardadas) en un orden o en el otro, dejando en D la que sale y metiendo en su sitio la celda leida
	pop af			;591e
	ld a,(hl)			;591f   ; A = la celda leida
	jr nc,intercambia_celdas_al_reves		;5920
	ld d,(ix+00ah)		;5922   ; D = el campo 10, la que sale
	ld c,(ix+009h)		;5925   ; C = el campo 9
	ld (ix+00ah),c		;5928   ; el campo 10 pasa a ser el 9
	ld (ix+009h),a		;592b   ; y el 9 recibe la celda nueva
	jr dibuja_celda_que_sale		;592e
intercambia_celdas_al_reves:		; El mismo intercambio de campos 9 y 10 en el orden contrario
	ld d,(ix+009h)		;5930   ; D = el campo 9, la que sale
	ld c,(ix+00ah)		;5933   ; C = el campo 10
	ld (ix+009h),c		;5936   ; el campo 9 pasa a ser el 10
	ld (ix+00ah),a		;5939   ; y el 10 recibe la celda nueva
dibuja_celda_que_sale:		; Si la entidad esta en la misma pantalla que el jugador (mismo byte alto de X), traduce con 0x5d52 la celda que acaba de salir y la escribe en la tabla de nombres, ajustando la columna segun el bit 0 del campo 1
	ld b,(ix+004h)		;593c   ; B = el campo 4 de la entidad, su byte alto de X
	ld a,(0e13ah)		;593f   ; A = el byte alto de la X del jugador
	cp b			;5942   ; si no coinciden, la entidad esta en otra pantalla: no se dibuja
	jr nz,comprueba_choque_de_entidad		;5943
	ld a,d			;5945
	call traduce_celda_a_patron		;5946   ; traduce la celda que sale a numero de patron
	push af			;5949
	ld a,002h		;594a
	call campo_de_cuchillo		;594c   ; campo 2 de la entidad
	ld d,(hl)			;594f   ; D = su Y
	inc hl			;5950
	inc hl			;5951
	ld e,(hl)			;5952   ; E = su X
	call direccion_vram_de_pixel		;5953   ; direccion de VRAM de ese pixel
	dec hl			;5956
	ld a,(ix+000h)		;5957   ; bit 0 del campo 1: ajusta la columna
	rra			;595a
	jr nc,L_595F		;595b
	inc hl			;595d
	inc hl			;595e
L_595F:
	pop af			;595f
	call 0004dh		;5960   ; BIOS WRTVRM - Writes data in VRAM | y escribe el patron
comprueba_choque_de_entidad:		; Guarda IX y DE, lanza busca_choque_con_entidad y, si no hubo choque, sigue por el camino normal contando un paso en el campo 0
	push ix		;5963
	push de			;5965
	call busca_choque_con_entidad		;5966   ; el recorrido de choques
	pop de			;5969
	pop ix		;596a
	jr nc,entidad_mira_celda_contigua		;596c   ; sin choque: sigue por el camino normal
	xor a			;596e
	call campo_de_cuchillo		;596f   ; campo 0 de la entidad
	jr cuenta_y_dibuja_entidad		;5972
entidad_mira_celda_contigua:		; Lee la celda contigua a la entidad (a un lado o al otro segun el bit 0 de IX+0) y la clasifica con celda_es_solida; el tipo 0x40 tambien la frena
	ld a,002h		;5974
	call campo_de_cuchillo		;5976   ; campo 2, la posicion de la entidad
	push hl			;5979
	call lee_celda_propia		;597a   ; lee la celda de sala de ahi
	dec hl			;597d
	ld a,(ix+000h)		;597e   ; (IX+0), el campo 1
	rra			;5981   ; su bit 0 elige la celda de un lado o la del otro
	jr c,L_5986		;5982
	inc hl			;5984
	inc hl			;5985
L_5986:
	ld a,(hl)			;5986   ; A = la celda; B se la queda
	ld b,a			;5987
	pop hl			;5988
	call celda_es_solida		;5989   ; la clasifica
	jr nz,entidad_en_celda_vacia		;598c   ; no es solida: la entidad se para
	ld a,b			;598e
	cp 040h		;598f   ; el tipo 0x40 tambien la para
	jr z,entidad_en_celda_vacia		;5991
	dec hl			;5993
	dec hl			;5994
cuenta_y_dibuja_entidad:		; Cuenta un paso en el campo que apunta HL y sigue a dibujar la entidad si esta en la pantalla del jugador
	inc (hl)			;5995   ; un paso mas
	inc hl			;5996
	ld b,(hl)			;5997   ; B = el campo siguiente
	inc hl			;5998
	inc hl			;5999
	inc hl			;599a
dibuja_entidad_si_visible:		; Solo dibuja si el byte alto de X de la entidad coincide con el del jugador (misma pantalla): entonces coge el patron del campo que toque segun el bit 0 de B, lo traduce y lo escribe en la tabla de nombres
	inc hl			;599b
	ld a,(0e13ah)		;599c   ; A = el byte alto de la X del jugador
	cp (hl)			;599f   ; si no coincide, la entidad esta en otra pantalla
	ret nz			;59a0
	ld a,005h		;59a1   ; HL += 5: el campo del patron
	call suma_a_hl		;59a3
	rr b		;59a6   ; bit 0 de B: elige entre dos patrones
	jr nc,L_59AB		;59a8
	inc hl			;59aa
L_59AB:
	ld a,(hl)			;59ab   ; A = el patron
	call traduce_celda_a_patron		;59ac   ; lo traduce a numero de celda
	call direccion_vram_de_pixel		;59af   ; direccion de VRAM de esa posicion
	jp 0004dh		;59b2   ; BIOS WRTVRM - Writes data in VRAM | y lo escribe
entidad_en_celda_vacia:		; La celda contigua no era solida: solo se sigue dibujando si vale 0x00 (hueco) o 0xF8 (el centinela de fin de sala)
	dec hl			;59b5
	ld b,(hl)			;59b6   ; B = el campo anterior
	inc hl			;59b7
	inc hl			;59b8
	inc hl			;59b9
	xor a			;59ba
	cp (hl)			;59bb   ; la celda vale 0: hueco, sigue
	jr z,dibuja_entidad_si_visible		;59bc
	ld a,0f8h		;59be   ; y 0xF8, el centinela, tambien
	cp (hl)			;59c0
	jr z,dibuja_entidad_si_visible		;59c1
	ret			;59c3   ; cualquier otra cosa: la entidad se queda parada
da_la_vuelta_a_la_entidad:		; Cuenta un paso, invierte los dos bits de direccion del campo 1, alinea la X a multiplo de 8 (con +4 segun el sentido) y pone a cero el campo cinco mas alla
	call cuenta_un_paso_de_entidad		;59c4   ; un paso en el campo 0
	inc hl			;59c7
	ld a,(hl)			;59c8
	xor 003h		;59c9   ; da la vuelta a los dos bits de direccion
	ld (hl),a			;59cb
	inc hl			;59cc
	inc hl			;59cd
	inc hl			;59ce
	rra			;59cf   ; bit 0 del resultado: el sentido nuevo
	ld a,(hl)			;59d0
	jr c,alinea_x_de_entidad_a_ocho		;59d1
	add a,004h		;59d3   ; en un sentido, la X se adelanta cuatro pixeles antes de alinear
alinea_x_de_entidad_a_ocho:		; Alinea a multiplo de 8 la X de la entidad y pone a cero el campo cinco bytes mas alla
	and 0f8h		;59d5   ; alineada a multiplo de 8
	ld (hl),a			;59d7
	ld a,005h		;59d8
	call suma_a_hl		;59da   ; HL += 5: el campo del contador
	ld (hl),000h		;59dd   ; puesto a cero: el movimiento arranca de nuevo
	ret			;59df
entidad_cae_por_la_curva:		; Cada cuatro fotogramas avanza el campo 3 de la entidad, le suma a la Y el valor que la curva de 0x5a3f asigna al campo 9, y comprueba la celda de debajo: si es solida (o de los tipos 0x41/0x42) sale por 0x5a30, que cuenta el aterrizaje
	ld a,(0e003h)		;59e0   ; A = contador de fotogramas
	and 003h		;59e3   ; mod 4: la caida avanza uno de cada cuatro fotogramas
	jp nz,remata_paso_de_entidad		;59e5
	ld a,001h		;59e8
	call campo_de_cuchillo		;59ea   ; campo 1 de la entidad
	push hl			;59ed
	ld a,(hl)			;59ee   ; A = ese campo
	inc hl			;59ef
	inc hl			;59f0
	inc hl			;59f1
	inc (hl)			;59f2   ; el campo 3 sube uno
	rra			;59f3   ; bit 0 del campo 1: el sentido
	jr nc,aplica_la_curva_de_caida		;59f4
	dec (hl)			;59f6   ; en un sentido, el campo 3 baja dos: queda en -1
	dec (hl)			;59f7
aplica_la_curva_de_caida:		; Suma a la Y de la entidad el valor de la curva de 0x5a3f indexada por su campo 9, y mira la celda cuatro filas mas abajo y ocho pixeles a un lado para saber si ha aterrizado
	pop hl			;59f8
	call ajusta_campo_de_paso		;59f9   ; la puesta a punto de 0x70ff
	ld a,009h		;59fc
	call campo_de_cuchillo		;59fe   ; campo 9 de la entidad: la fase de la caida
	ld a,(hl)			;5a01
	ld hl,05a3fh		;5a02   ; HL = la curva de 0x5a3f (-5,-2,-1,0,0,1,2,5)
	call suma_a_hl		;5a05
	ld b,(hl)			;5a08   ; B = el desplazamiento de Y de esta fase
	ld a,002h		;5a09
	call campo_de_cuchillo		;5a0b   ; campo 2, la posicion
	ld a,(hl)			;5a0e
	add a,b			;5a0f   ; Y += el desplazamiento de la curva
	ld (hl),a			;5a10
	push hl			;5a11
	ld bc,00408h		;5a12   ; BC = 0x0408: cuatro filas abajo, ocho pixeles a un lado
	call lee_celda_de_sala		;5a15   ; lee esa celda
	ld a,(hl)			;5a18
	call celda_es_solida		;5a19   ; la clasifica
	pop hl			;5a1c
	jr nz,entidad_aterriza		;5a1d   ; es solida: ha aterrizado
	ld a,b			;5a1f
	cp 041h		;5a20   ; el tipo 0x41 tambien frena
	jr z,entidad_aterriza		;5a22
	cp 042h		;5a24   ; y el 0x42
	jr z,entidad_aterriza		;5a26
	and 0f0h		;5a28
	cp 010h		;5a2a   ; el 0x1x cuenta como suelo
	jr nz,$+93		;5a2c
	jr $+81		;5a2e
entidad_aterriza:		; Cuenta uno en el campo 7 de la entidad; al llegar a 8 cuenta ademas un paso en el campo 0, y en cualquier caso remata por 0x5ab6
	ld a,007h		;5a30
	call suma_a_hl		;5a32   ; HL += 7: el contador de aterrizaje
	inc (hl)			;5a35   ; sube uno
	ld a,(hl)			;5a36
	cp 008h		;5a37   ; al llegar a 8, la entidad cambia de paso
	jp z,cuenta_un_paso_de_entidad		;5a39
	jp remata_paso_de_entidad		;5a3c

; ----------------------------------------------------------------------
; DATOS curva_de_caida: Los ocho desplazamientos de Y de la caida (FB FE FF 00
;   00 01 02 05 = -5,-2,-1,0,0,1,2,5), indexados por el campo 9 de la entidad
;   en aplica_la_curva_de_caida (0x5a02). Pasan de negativos a positivos
;   cruzando por cero: es el arco de un salto o una caida, no una gravedad
;   constante
;   0x5a3f..0x5a47  (8 bytes)
DATA_curva_de_caida:
	defb 0fbh	; 5a3f
	defb 0feh	; 5a40
	defb 0ffh	; 5a41
	defb 000h	; 5a42
	defb 000h	; 5a43
	defb 001h	; 5a44
	defb 002h	; 5a45
	defb 005h	; 5a46

; ======================================================================
; CODIGO 0x5a47..0x5b84  (317 bytes)
; ======================================================================


entidad_espera_alineada:		; Cada cuatro fotogramas alinea el campo 2 de la entidad a multiplo de 4 y, si los dos bits bajos no eran cero, se va directo al remate de 0x5ab6
	ld a,(0e003h)		;5a47   ; A = contador de fotogramas
	and 003h		;5a4a   ; mod 4: uno de cada cuatro
	jp nz,remata_paso_de_entidad		;5a4c
	ld a,002h		;5a4f
	call campo_de_cuchillo		;5a51   ; campo 2 de la entidad
	ld a,(hl)			;5a54
	and 0fch		;5a55
	ld (hl),a			;5a57
	ld d,(hl)			;5a58
	ld a,d			;5a59
	and 003h		;5a5a
	jp nz,avanza_entidad_cuatro		;5a5c
entidad_mira_debajo:		; Lee la celda que hay una fila mas abajo (HL += 0x60 = 96, el stride del buffer de sala) y la clasifica: si no es solida, ni 0x41 ni 0x42, y ademas es del tipo 0x1x, la entidad se aparca; si no, pasa a tipo 7
	call lee_celda_propia		;5a5f   ; lee la celda de la posicion
	ld a,060h		;5a62   ; HL += 0x60 = 96: la fila de debajo
	call suma_a_hl		;5a64
	ld a,(hl)			;5a67
	call celda_es_solida		;5a68   ; la clasifica
	jp nz,avanza_entidad_cuatro		;5a6b
	ld a,b			;5a6e
	cp 041h		;5a6f   ; el tipo 0x41 la deja seguir
	jp z,avanza_entidad_cuatro		;5a71
	cp 042h		;5a74   ; y el 0x42
	jp z,avanza_entidad_cuatro		;5a76
	and 0f0h		;5a79
	cp 010h		;5a7b   ; el tipo 0x1x: aparca la entidad
	jr nz,entidad_pasa_a_tipo_7		;5a7d
aparca_y_borra_entidad:		; Aparca el sprite de la entidad fuera de pantalla y le pone el campo 0 a cero: queda libre
	call aparca_entidad_grande		;5a7f   ; aparca el sprite
	xor a			;5a82
	call campo_de_cuchillo		;5a83   ; campo 0 de la entidad
	ld (hl),000h		;5a86   ; a cero: la entidad queda libre
	ret			;5a88
entidad_pasa_a_tipo_7:		; Deja el campo 0 de la entidad en 7 y pone a cero el campo nueve bytes mas alla
	xor a			;5a89
	call campo_de_cuchillo		;5a8a   ; campo 0 de la entidad
	ld (hl),007h		;5a8d   ; := 7, el tipo nuevo
	ld a,009h		;5a8f
	call suma_a_hl		;5a91   ; HL += 9: el campo lejano
	ld (hl),000h		;5a94   ; puesto a cero
	ret			;5a96
avanza_entidad_cuatro:		; Suma cuatro a la posicion de la entidad (cuatro inc seguidos), la alinea a multiplo de 4 y remata por 0x5ab6
	ld a,002h		;5a97
	call campo_de_cuchillo		;5a99   ; campo 2 de la entidad
	inc (hl)			;5a9c
	inc (hl)			;5a9d
	inc (hl)			;5a9e
	inc (hl)			;5a9f
	ld a,(hl)			;5aa0
	and 0fch		;5aa1   ; alineada a multiplo de 4
	ld (hl),a			;5aa3
	jp remata_paso_de_entidad		;5aa4
celda_es_solida:		; Clasifica el byte de una celda: devuelve Z si su nibble alto es 0x1x, 0x3x, 0x8x o 0x4x -las cuatro clases que frenan a una entidad- y deja el byte entero en B para que el llamador pueda afinar
	ld b,a			;5aa7   ; B guarda el byte entero de la celda
	and 0f0h		;5aa8   ; solo el nibble alto clasifica
	cp 010h		;5aaa   ; 0x1x: suelo o pared
	ret z			;5aac
	cp 030h		;5aad   ; 0x3x
	ret z			;5aaf
	cp 080h		;5ab0   ; 0x8x
	ret z			;5ab2
	cp 040h		;5ab3   ; y 0x4x, la ultima; cualquier otra devuelve NZ
	ret			;5ab5
remata_paso_de_entidad:		; Si la entidad esta en la pantalla del jugador, copia su posicion al bloque de sprites que le corresponde y le da un color que cambia cada cuatro fotogramas
	ld a,005h		;5ab6
	call campo_de_cuchillo		;5ab8   ; campo 5 de la entidad
	ld a,(0e13ah)		;5abb   ; A = el byte alto de la X del jugador
	cp (hl)			;5abe   ; si no coincide, la entidad esta en otra pantalla y no se dibuja
	jr nz,aparca_entidad_grande		;5abf
	dec hl			;5ac1   ; HL retrocede tres bytes hasta la posicion
	dec hl			;5ac2
	dec hl			;5ac3
	push hl			;5ac4
	call posicion_de_entidad_grande		;5ac5   ; DE = el hueco de sprite de esta entidad
	ex de,hl			;5ac8
	pop hl			;5ac9
	ld a,(hl)			;5aca   ; Y del sprite
	ld (de),a			;5acb
	inc hl			;5acc
	inc hl			;5acd
	ld a,(hl)			;5ace   ; X del sprite
	inc de			;5acf
	ld (de),a			;5ad0
	inc de			;5ad1
	ld a,(0e003h)		;5ad2   ; A = contador de fotogramas
	and 00ch		;5ad5   ; &0x0C mas 0xF0: un color que cambia cada cuatro fotogramas
	add a,0f0h		;5ad7
	ex de,hl			;5ad9
	ld (hl),a			;5ada   ; el numero de patron
	inc hl			;5adb
	ld (hl),00fh		;5adc   ; y el color, 0x0F
	ret			;5ade
cierra_recorrido_de_17:		; Cierre del bucle de recorre_entidades_17, alcanzado por el `ret` de la rutina despachada gracias al `push hl` de 0x57e1: sube el indice de 0xE262 y vuelve al cuerpo del bucle mientras no llegue al tope de 0xE263
	ld hl,0e262h		;5adf   ; HL = 0xE262, el indice de la entidad grande
	inc (hl)			;5ae2   ; sube uno
	ld a,(hl)			;5ae3
	inc hl			;5ae4   ; HL = 0xE263, el tope
	cp (hl)			;5ae5
	jp nz,L_57DE		;5ae6   ; mientras queden, otra entidad
	ret			;5ae9
aparca_entidad_grande:		; Deja en 0xE0 el byte que apunta posicion_de_entidad_grande: aparca el sprite de esa entidad fuera de la pantalla
	call posicion_de_entidad_grande		;5aea
	ld (hl),0e0h		;5aed   ; 0xE0 = -32: la Y que deja el sprite fuera de la pantalla
	ret			;5aef
cuenta_un_paso_de_entidad:		; Suma uno al campo 0 de la entidad activa de la lista de 17 bytes
	xor a			;5af0   ; campo 0 = el tipo/contador de la entidad
	call campo_de_cuchillo		;5af1
	inc (hl)			;5af4   ; y lo incrementa
	ret			;5af5
campo_de_cuchillo:		; Devuelve en HL la direccion del campo A del CUCHILLO activo (base 0xE264, 17 bytes por cuchillo, indice en 0xE262) y en A su contenido. El paso 17 sale de la cadena 2i-4i-8i-16i mas i. La lista de 17 bytes son los cuchillos que el explorador ha lanzado: hasta cuatro
	push bc			;5af6   ; BC se conserva: los llamadores lo usan como parametro propio
	ld hl,0e264h		;5af7   ; HL = 0xE264, la base de la lista de 17 bytes
	call suma_a_hl		;5afa   ; HL += el numero de campo que trae A
	ld a,(0e262h)		;5afd   ; A = (0xE262), el indice de la entidad activa
	ld b,a			;5b00   ; B guarda el indice: hace falta entero para el ultimo add
	add a,a			;5b01   ; A = 2i, y sigue en la cadena de 0x65a6 (4i, 8i, 16i, +i = 17i)
	call indexa_paso_17		;5b02
	pop bc			;5b05
	ret			;5b06
direccion_vram_de_pixel:		; Convierte una posicion en pixeles (D=Y, E=X) en la direccion de la tabla de nombres del VDP: HL = 0x3800 + (Y/8)*32 + X/8. Lo hace con un desplazamiento de 3 bits sobre HL entero (cuatro rra y tres rr l entrelazados) y quedandose con los dos bits altos de Y para la parte alta. La base 0x3800 es la que fija el registro R2=0x0E, ya confirmada en la tanda 4
	push af			;5b07   ; guarda AF: el llamador trae banderas que hacen falta despues, y el primer rra rota a traves del acarreo
	ld h,d			;5b08   ; HL = DE, la posicion en pixeles
	ld l,e			;5b09
	ld a,h			;5b0a   ; A = Y
	rra			;5b0b   ; cuatro rra sobre Y solo: prepara el desplazamiento de 3 bits del par
	rra			;5b0c
	rra			;5b0d
	rra			;5b0e
	rr l		;5b0f   ; los tres rr l entrelazados bajan los bits de Y a L y sacan los tres de menos peso de X
	rra			;5b11
	rr l		;5b12
	rra			;5b14
	rr l		;5b15
	and 003h		;5b17   ; de A solo quedan los dos bits altos de Y (la fila / 8, parte alta)
	add a,038h		;5b19   ; base 0x3800 de la tabla de nombres
	ld h,a			;5b1b   ; H = la parte alta ya completa
	pop af			;5b1c   ; recupera las banderas del llamador intactas
	ret			;5b1d
posicion_de_entidad_grande:		; Calcula con 0x71ed la direccion dentro del bloque de 0xE0EC que corresponde a la entidad grande activa (indice de 0xE262)
	ld a,(0e262h)		;5b1e   ; A = el indice de la entidad grande activa
	ld hl,0e0ech		;5b21   ; HL = 0xE0EC, la base del bloque paralelo de esa lista
	jp ranura_de_sprite		;5b24
busca_choque_con_entidad:		; Recorre la lista de 0xE164 comparando la posicion de la entidad grande activa contra la de cada una: si coinciden en el byte alto de X y las cajas de 0x5b84 se solapan, hay choque
	ld c,000h		;5b27   ; C := 0, el indice del recorrido
prueba_un_choque:		; Cuerpo del bucle de busca_choque_con_entidad: prepara la entidad C y descarta los tipos que no chocan
	ld a,c			;5b29   ; A = el indice de esta vuelta
	call prepara_enemigo		;5b2a
	ld a,(ix+000h)		;5b2d   ; campo 0 del registro que apunta IX: el tipo
	cp 004h		;5b30   ; los tipos por debajo de 4 si chocan
	jr c,compara_cajas		;5b32
	cp 007h		;5b34   ; el tipo 7 tambien; los demas no
	jr nz,siguiente_choque		;5b36
compara_cajas:		; Compara la posicion de la entidad grande activa con la del registro de IX: primero el byte alto de la X (tienen que estar en la misma pantalla) y luego las dos cajas con la tabla de 0x5b84
	ld a,002h		;5b38   ; campo 2 de la entidad grande: su posicion
	call campo_de_cuchillo		;5b3a
	ld d,(hl)			;5b3d   ; D = la Y
	inc hl			;5b3e
	inc hl			;5b3f
	ld e,(hl)			;5b40   ; E = la X baja
	inc hl			;5b41
	ld a,(hl)			;5b42   ; A = la X alta
	cp (ix+006h)		;5b43   ; tiene que coincidir con la del otro registro: misma pantalla
	jr nz,siguiente_choque		;5b46
	push bc			;5b48
	ld c,(ix+003h)		;5b49   ; C = la X del registro de IX
	ld b,(ix+005h)		;5b4c   ; B = su X alta
	ld hl,05b84h		;5b4f   ; HL = la tabla de 0x5b84 (8,0x18,8,0x18): el ancho y el alto de la caja
	call cajas_se_solapan		;5b52   ; la comparacion de cajas de 0x5ce7; C = se solapan
	pop bc			;5b55
	jr c,aplica_el_choque		;5b56
siguiente_choque:		; Final del bucle: sube el indice y repite mientras no llegue al numero de 0xE164
	inc c			;5b58   ; el indice sube uno
	ld hl,0e164h		;5b59   ; HL = 0xE164, el numero de registros de esa lista
	ld a,c			;5b5c
	cp (hl)			;5b5d
	jp nz,prueba_un_choque		;5b5e   ; mientras queden, otra vuelta
	and a			;5b61   ; recorrida entera sin choque: devuelve NC
	ret			;5b62
aplica_el_choque:		; Hay choque: dibuja el aviso de 0x4412 con DE=0x0100, suena el efecto 0x08, deja el registro de IX en tipo 6 con subtipo 4, le alinea la X a multiplo de 8 y le pone 0x22 en el campo 0x11
	ld de,00100h		;5b63
	call suma_al_marcador		;5b66   ; el aviso de 0x4412
	ld a,008h		;5b69
	call reproduce_efecto		;5b6b   ; efecto de sonido 0x08, el del choque
	ld (ix+000h),006h		;5b6e   ; campo 0 := 6, el tipo de "chocado"
	ld (ix+001h),004h		;5b72   ; campo 1 := 4
	ld a,(ix+003h)		;5b76
	and 0f8h		;5b79   ; la X se alinea a multiplo de 8
	ld (ix+003h),a		;5b7b
	ld (ix+011h),022h		;5b7e   ; campo 0x11 := 0x22
	scf			;5b82   ; devuelve C: ha habido choque
	ret			;5b83

; ----------------------------------------------------------------------
; DATOS caja_de_entidad_grande: Los cuatro bytes de caja (08 18 08 18) que
;   busca_choque_con_entidad (0x5b4f) pasa a cajas_se_solapan: semiancho y
;   semialto de las dos cajas del choque
;   0x5b84..0x5b88  (4 bytes)
DATA_caja_de_entidad_grande:
	defb 008h,018h,008h,018h	; 5b84

; ======================================================================
; CODIGO 0x5b88..0x5c28  (160 bytes)
; ======================================================================


recorre_entidades_grandes:		; Recorre la lista de 17 bytes (indice 0xE262, tope 0xE263) buscando la que tenga el campo 0 a 1 y pase la prueba de 0x5cd6; la primera que lo cumpla se anota en 0xE261. Solo corre si no hay accion pendiente (0xe144 a cero)
	ld a,(0e144h)		;5b88   ; (0xe144): con una accion pendiente, este recorrido no se hace
	and a			;5b8b
	ret nz			;5b8c
	ld hl,0e262h		;5b8d   ; indice de entidad grande := 0
	ld (hl),a			;5b90
	inc hl			;5b91
	cp (hl)			;5b92   ; con el tope tambien a 0 no hay ninguna entidad viva
	ret z			;5b93
prueba_una_entidad_grande:		; Cuerpo del bucle: mira el campo 0 de la entidad activa y, si vale exactamente 1 y 0x5cd6 devuelve C, salta a anotarla
	xor a			;5b94   ; campo 0 de la entidad grande
	call campo_de_cuchillo		;5b95
	call posicion_y_pantalla_1		;5b98   ; la comprobacion previa de 0x5bdd
	jr nz,siguiente_entidad_grande		;5b9b
	cp 001h		;5b9d   ; el campo 0 tiene que valer exactamente 1
	jr nz,siguiente_entidad_grande		;5b9f
	call choca_con_el_jugador		;5ba1   ; la prueba de verdad; C = esta es
	jr c,anota_entidad_grande		;5ba4
siguiente_entidad_grande:		; Final del bucle de recorre_entidades_grandes: sube el indice y repite mientras no llegue al tope de 0xE263
	ld hl,0e262h		;5ba6   ; HL = 0xE262, el indice
	inc (hl)			;5ba9   ; sube uno
	ld a,(hl)			;5baa
	inc hl			;5bab   ; HL = 0xE263, el tope
	cp (hl)			;5bac   ; mientras no llegue al tope, otra entidad
	jr nz,prueba_una_entidad_grande		;5bad
	ret			;5baf
anota_entidad_grande:		; La entidad que ha pasado la prueba se anota en 0xE261, suena el efecto 0x04 y se sigue con el resto de su tratamiento
	ld a,(0e262h)		;5bb0   ; A = el indice de la que ha pasado
	ld (0e261h),a		;5bb3   ; (0xE261) := ese indice: la entidad elegida
	ld a,004h		;5bb6
	call reproduce_efecto		;5bb8   ; efecto de sonido 0x04
	ld a,010h		;5bbb
	call guarda_accion_pendiente		;5bbd
	xor a			;5bc0
	call campo_de_cuchillo		;5bc1
	inc (hl)			;5bc4
	ld d,h			;5bc5
	ld e,l			;5bc6
	push hl			;5bc7
	ld bc,0000ah		;5bc8
	add hl,bc			;5bcb
	ld b,(hl)			;5bcc
	pop hl			;5bcd
	inc hl			;5bce
	inc hl			;5bcf
	call lee_celda_propia		;5bd0
	ld (hl),b			;5bd3
	ld h,d			;5bd4
	ld l,e			;5bd5
	ld a,b			;5bd6
	call traduce_celda_a_patron		;5bd7
	jp dibuja_si_esta_visible		;5bda
posicion_y_pantalla_1:		; Salta un byte y cae en posicion_y_pantalla: lo usan los llamadores cuyo puntero llega uno antes
	inc hl			;5bdd   ; un byte de ajuste
posicion_y_pantalla_2:		; Salta otro byte mas y cae en posicion_y_pantalla
	inc hl			;5bde   ; otro byte de ajuste
posicion_y_pantalla:		; Carga en D la Y y en E la X del registro que apunta HL, y compara su byte alto de X con el del jugador: devuelve Z solo si estan en la misma pantalla. A se conserva entero a traves de B
	ld d,(hl)			;5bdf   ; D = la Y del registro
	inc hl			;5be0
	inc hl			;5be1
	ld e,(hl)			;5be2   ; E = la X del registro
	inc hl			;5be3
	ld b,a			;5be4   ; B guarda A, que el llamador necesita intacto
	ld c,(hl)			;5be5   ; C = el byte alto de la X del registro
	ld a,(0e13ah)		;5be6   ; A = el byte alto de la X del jugador
	cp c			;5be9   ; Z solo si estan en la misma pantalla
	ld a,b			;5bea   ; y A vuelve como estaba
	ret			;5beb
dibuja_si_esta_visible:		; Escribe A en la tabla de nombres, en la celda donde cae el registro que apunta HL, pero solo si esta en la misma pantalla que el jugador
	call posicion_y_pantalla_1		;5bec   ; la posicion y la comprobacion de pantalla
	ret nz			;5bef   ; en otra pantalla: no se dibuja nada
	call direccion_vram_de_pixel		;5bf0   ; direccion de VRAM de esa posicion
	jp 0004dh		;5bf3   ; BIOS WRTVRM - Writes data in VRAM | y escribe el patron
recoge_objetos:		; Recorre la lista de entidades de 9 bytes buscando la que este en la pantalla del jugador, con el nibble bajo del campo 0 distinto de cero, y cuya caja se solape con la del jugador: al encontrarla suma 0x0500 al marcador, suena el efecto 0x09 y le pone el campo 1 a 2
	xor a			;5bf6   ; indice de entidad := 0
	ld (0e1f4h),a		;5bf7
prueba_un_objeto:		; Cuerpo del bucle de recoge_objetos: descarta las entidades de otra pantalla, las de nibble bajo cero y las que no chocan con el jugador
	xor a			;5bfa   ; campo 0 de la entidad de 9 bytes
	call campo_de_entidad_9		;5bfb
	call posicion_y_pantalla_1		;5bfe   ; la comprobacion de pantalla
	jr nz,siguiente_objeto		;5c01   ; en otra pantalla: a la siguiente
	and 00fh		;5c03   ; nibble bajo del campo 0: a cero no cuenta
	jr z,siguiente_objeto		;5c05
	call choca_con_el_jugador		;5c07   ; la comparacion de cajas contra el jugador
	jr nc,siguiente_objeto		;5c0a   ; sin choque: a la siguiente
	ld de,00500h		;5c0c   ; suma 0x0500 al marcador
	call suma_al_marcador		;5c0f
	ld a,009h		;5c12
	call reproduce_efecto		;5c14   ; efecto de sonido 0x09, el de recoger
	ld a,001h		;5c17
	call campo_de_entidad_9		;5c19   ; campo 1 de la entidad
	ld (hl),002h		;5c1c   ; := 2, el estado de "recogida"
siguiente_objeto:		; Final del bucle de recoge_objetos: sube el indice y repite mientras no llegue al tope de 0xE1F3
	ld hl,0e1f4h		;5c1e   ; HL = 0xE1F4, el indice
	inc (hl)			;5c21   ; sube uno
	ld a,(hl)			;5c22
	dec hl			;5c23   ; HL = 0xE1F3, el tope
	cp (hl)			;5c24
	jr nz,prueba_un_objeto		;5c25   ; mientras queden, otra vuelta
	ret			;5c27

; ----------------------------------------------------------------------
; DATOS tabla_buscador_1_de_2: Cuatro bytes, tabla base de L_5cd9 (llamada
;   desde 0x5cd6)
;   0x5c28..0x5c2c  (4 bytes)
DATA_tabla_buscador_1_de_2:
	defb 005h,011h,001h,009h	; 5c28

; ======================================================================
; CODIGO 0x5c2c..0x5cd2  (166 bytes)
; ======================================================================


recoge_de_la_otra_lista:		; Lo mismo que recoge_objetos pero sobre la lista de 0xE2CC (tope en 0xE2CB): al encontrar el choque suena el efecto 0x04, borra la entidad y su celda de sala, anota el indice en 0xE2CA y deja la accion pendiente en 0x20
	ld a,(0e144h)		;5c2c   ; (0xe144): con una accion pendiente, este recorrido no se hace
	and a			;5c2f
	ret nz			;5c30
	ld hl,0e2cbh		;5c31   ; HL = 0xE2CB, el numero de entidades de esta lista
	ld a,(hl)			;5c34
	or a			;5c35
	ret z			;5c36   ; con cero, no hay nada que recorrer
	xor a			;5c37
	ld (0e1f4h),a		;5c38   ; indice := 0
	inc hl			;5c3b
prueba_una_de_la_otra_lista:		; Cuerpo del bucle: descarta las de otra pantalla, las de campo 0 a cero y las que no chocan
	xor a			;5c3c
	call campo_de_la_otra_lista		;5c3d   ; campo 0 de esta lista
	call posicion_y_pantalla_2		;5c40   ; la comprobacion de pantalla
	jr nz,siguiente_de_la_otra_lista		;5c43   ; en otra pantalla: a la siguiente
	and a			;5c45   ; campo 0 a cero: a la siguiente
	jr z,siguiente_de_la_otra_lista		;5c46
	call choca_con_el_jugador		;5c48   ; la comparacion de cajas contra el jugador
	jr nc,siguiente_de_la_otra_lista		;5c4b   ; sin choque: a la siguiente
	ld a,004h		;5c4d
	call reproduce_efecto		;5c4f   ; efecto de sonido 0x04
	xor a			;5c52
	call campo_de_la_otra_lista		;5c53   ; campo 0 de la entidad
	ld (hl),000h		;5c56   ; := 0: la entidad desaparece
	push hl			;5c58
	inc hl			;5c59
	call lee_celda_propia		;5c5a   ; lee su celda de sala
	xor a			;5c5d
	ld (hl),a			;5c5e   ; y la borra tambien ahi
	pop hl			;5c5f
	dec hl			;5c60
	call dibuja_si_esta_visible		;5c61   ; y borra el dibujo de la pantalla
	ld a,(0e1f4h)		;5c64   ; A = el indice de la entidad recogida
	ld (0e2cah),a		;5c67   ; anotado en 0xE2CA
	ld a,020h		;5c6a   ; accion pendiente := 0x20
	jp guarda_accion_pendiente		;5c6c
siguiente_de_la_otra_lista:		; Final del bucle: sube el indice y repite mientras no llegue al tope de 0xE2CB
	ld hl,0e1f4h		;5c6f   ; HL = 0xE1F4, el indice
	inc (hl)			;5c72   ; sube uno
	ld a,(0e2cbh)		;5c73   ; A = (0xE2CB), el tope de esta lista
	cp (hl)			;5c76   ; mientras queden, otra vuelta
	jr nz,prueba_una_de_la_otra_lista		;5c77
	ret			;5c79
campo_de_la_otra_lista:		; Devuelve el campo A de la entidad activa de la lista de 0xE2CC, con el mismo paso 9 que la lista de 0xE1F5
	ld a,(0e1f4h)		;5c7a   ; A = el indice de entidad
	ld hl,0e2cch		;5c7d   ; HL = 0xE2CC, la base de esta lista
	ld b,a			;5c80   ; B = el indice, para el paso 9
	jp indexa_y_lee		;5c81   ; y la multiplicacion por 9
busca_enemigo_que_toca:		; Recorre la lista de registros de 0xE164 buscando un enemigo del tipo 0-3 o 7 que este en la pantalla del jugador, en el mismo estado (o los dos en el estado 3) y cuya caja se solape con la del jugador usando tabla_buscador_2_de_2: si lo encuentra suena el efecto 0x1d y pone 0xE053 a cero, que es lo que mata la partida
	ld c,000h		;5c84   ; C := 0, el indice del recorrido
prueba_un_enemigo:		; Cuerpo del bucle: prepara el registro C y descarta los tipos que no matan
	ld a,c			;5c86   ; A = el indice de esta vuelta
	call prepara_enemigo		;5c87
	ld hl,(0e162h)		;5c8a   ; HL = (0xE162), el puntero al registro preparado
	ld a,(hl)			;5c8d
	cp 004h		;5c8e   ; los tipos por debajo de 4 si matan
	jr c,compara_estados		;5c90
	cp 007h		;5c92   ; el tipo 7 tambien; los demas no
	jr nz,siguiente_enemigo		;5c94
compara_estados:		; El jugador y el enemigo tienen que estar en estados compatibles: si alguno esta en el estado 3, los dos tienen que estarlo
	ld a,(0e134h)		;5c96   ; A = el estado del jugador
	ld b,a			;5c99   ; B se lo queda
	cp 003h		;5c9a   ; el jugador en el estado 3: hace falta comparar
	jr z,exige_mismo_estado		;5c9c
	ld a,(hl)			;5c9e   ; el enemigo en el estado 3: tambien
	cp 003h		;5c9f
	jr nz,compara_cajas_con_enemigo		;5ca1   ; ninguno de los dos: no hace falta comparar estados
exige_mismo_estado:		; Con uno de los dos en el estado 3, solo cuenta el choque si el otro esta en el mismo estado
	ld a,b			;5ca3
	cp (hl)			;5ca4   ; los dos estados tienen que coincidir
	jr nz,siguiente_enemigo		;5ca5
compara_cajas_con_enemigo:		; Exige que el enemigo este en la pantalla del jugador y compara las dos cajas con tabla_buscador_2_de_2
	ld a,(0e13ah)		;5ca7   ; A = el byte alto de la X del jugador
	cp (ix+006h)		;5caa   ; contra el del enemigo: misma pantalla
	jr nz,siguiente_enemigo		;5cad
	ld d,(ix+003h)		;5caf   ; D = la Y del enemigo
	ld e,(ix+005h)		;5cb2   ; E = su X
	ld hl,05cd2h		;5cb5   ; HL = tabla_buscador_2_de_2, la caja de este choque
	call choca_con_el_jugador_con_tabla		;5cb8   ; la comparacion
	jr c,el_enemigo_mata		;5cbb   ; con C: el enemigo ha tocado al jugador
siguiente_enemigo:		; Final del bucle: sube el indice y repite mientras no llegue al numero de 0xE164
	inc c			;5cbd   ; el indice sube uno
	ld hl,0e164h		;5cbe   ; HL = 0xE164, el numero de registros
	ld a,c			;5cc1
	cp (hl)			;5cc2
	jp nz,prueba_un_enemigo		;5cc3   ; mientras queden, otra vuelta
	and a			;5cc6   ; recorrida entera sin tocar: devuelve NC
	ret			;5cc7
el_enemigo_mata:		; El enemigo ha tocado al jugador: suena el efecto 0x1d y 0xE053 se pone a cero, que es la senal que tarea_5_sala_en_reposo espera para arrancar la muerte
	ld a,01dh		;5cc8   ; efecto de sonido 0x1d
	call reproduce_efecto		;5cca
	xor a			;5ccd
	ld (0e053h),a		;5cce   ; (0xE053) := 0: la senal de que el jugador ha muerto
	ret			;5cd1

; ----------------------------------------------------------------------
; DATOS tabla_buscador_2_de_2: Cuatro bytes, tabla base de L_5cd9 (llamada
;   desde 0x5cb5)
;   0x5cd2..0x5cd6  (4 bytes)
DATA_tabla_buscador_2_de_2:
	defb 005h,00ah,008h,010h	; 5cd2

; ======================================================================
; CODIGO 0x5cd6..0x5d68  (146 bytes)
; ======================================================================


choca_con_el_jugador:		; Comprueba si la caja del jugador (posicion de 0xe137/0xe139) se solapa con la que trae el llamador, usando tabla_buscador_1_de_2
	ld hl,05c28h		;5cd6   ; HL = tabla_buscador_1_de_2, la caja de este tipo de choque
choca_con_el_jugador_con_tabla:		; Igual que choca_con_el_jugador pero con la tabla de caja que traiga HL: la usa tambien el buscador de 0x5c84 con tabla_buscador_2_de_2
	push bc			;5cd9   ; BC se conserva: los llamadores lo llevan como indice de bucle
	ld a,(0e137h)		;5cda   ; C = la Y del jugador
	ld c,a			;5cdd
	ld a,(0e139h)		;5cde   ; B = la X del jugador
	ld b,a			;5ce1
	call cajas_se_solapan		;5ce2   ; y la comparacion de cajas
	pop bc			;5ce5
	ret			;5ce6
cajas_se_solapan:		; Comparacion de cajas: con (B,C) = la posicion de uno, (E,D) = la del otro y HL apuntando a una tabla de cuatro bytes (semiancho1, semiancho2, semialto1, semialto2), devuelve C si las dos cajas se solapan en X Y en Y. La resta con acarreo hace de comparacion sin signo en las dos cuentas
	ld a,b			;5ce7   ; A = X de uno
	sub e			;5ce8   ; menos X del otro: la distancia horizontal
	sub (hl)			;5ce9   ; menos el primer semiancho
	inc hl			;5cea
	add a,(hl)			;5ceb   ; mas el segundo: si desborda, se solapan en X
	jr nc,L_5CF4		;5cec   ; sin solape en X ya no hay choque posible
	ld a,c			;5cee   ; A = Y de uno
	sub d			;5cef   ; menos Y del otro
	inc hl			;5cf0
	sub (hl)			;5cf1   ; menos el primer semialto
	inc hl			;5cf2
	add a,(hl)			;5cf3   ; mas el segundo: el acarreo final dice si hay choque
L_5CF4:
	ret			;5cf4
cuenta_atras_de_cuatro:		; Baja de cuatro en cuatro el contador de 0xE004; devuelve Z al llegar a 0xFC, y si no calcula el desplazamiento de pantalla que toca y devuelve C si 0xE147 esta marcado
	ld hl,0e004h		;5cf5   ; HL = 0xE004, el contador
	dec (hl)			;5cf8   ; cuatro veces menos uno: baja de cuatro en cuatro
	dec (hl)			;5cf9
	dec (hl)			;5cfa
	dec (hl)			;5cfb
	ld a,(hl)			;5cfc
	cp 0fch		;5cfd   ; al llegar a 0xFC, se acabo
	ret z			;5cff
	ld a,(0e136h)		;5d00   ; A = (0xe136), a que lado mira
	rra			;5d03
	ld a,(hl)			;5d04   ; A = el contador
	jr c,comprueba_marca_de_cambio		;5d05
	sub 020h		;5d07   ; mirando al otro lado, la cuenta se invierte (0x20 menos el contador)
	neg		;5d09
comprueba_marca_de_cambio:		; Aplica el desplazamiento y devuelve C solo si 0xE147 esta marcado
	call desplaza_la_vista		;5d0b   ; aplica el desplazamiento de pantalla
	ld a,(0e147h)		;5d0e   ; (0xE147): la marca de cambio de pantalla
	and a			;5d11
	ret z			;5d12   ; sin marca, no hay cambio
	scf			;5d13   ; con marca, devuelve C
	ret			;5d14
desplaza_la_vista:		; Calcula la esquina del buffer de sala que hay que volcar: parte de 0xE760, le suma 0x20 columnas si el byte alto de la X mas el modo de 0xe136 da 3, y le anade el desplazamiento fino que trae B
	ld b,a			;5d15   ; B = el desplazamiento fino
	ld hl,0e13ah		;5d16   ; HL = 0xE13A, el byte alto de la X
	ld a,(0e136h)		;5d19   ; A = (0xe136), el modo
	cp 003h		;5d1c   ; el modo 3 cuenta como 1
	jr nz,L_5D22		;5d1e
	ld a,001h		;5d20
L_5D22:
	add a,(hl)			;5d22   ; mas el byte alto de la X
	cp 003h		;5d23   ; si da 3, la vista se corre 0x20 columnas
	ld a,020h		;5d25
	jr z,L_5D2A		;5d27
	xor a			;5d29   ; si no, no se corre
L_5D2A:
	add a,b			;5d2a   ; mas el desplazamiento fino
	ld de,0e760h		;5d2b   ; DE = 0xE760, la esquina de la sala
	call suma_a_de		;5d2e
vuelca_la_vista:		; Vuelca a la tabla de nombres (desde VRAM 0x3820) la ventana del buffer de sala que empieza en DE, traduciendo cada celda con traduce_celda_a_patron
	ld hl,03820h		;5d31   ; HL = VRAM 0x3820, la primera fila util de la pantalla
	call prepara_escritura_vdp		;5d34
	ld b,016h		;5d37
L_5D39:
	push bc			;5d39
	push de			;5d3a
	ld b,020h		;5d3b
escribe_fila_de_celdas:		; Escribe una fila de B celdas del buffer de sala en el puerto de datos del VDP, traduciendo cada byte con traduce_celda_a_patron
	ld a,(de)			;5d3d   ; A = el byte del buffer de sala
	call traduce_celda_a_patron		;5d3e   ; traducido a numero de patron
	exx			;5d41
	out (c),a		;5d42   ; al puerto de datos del VDP
	exx			;5d44
	inc de			;5d45
	djnz escribe_fila_de_celdas		;5d46   ; hasta acabar la fila
	pop de			;5d48
	ld a,060h		;5d49   ; 0x60 = 96: el stride de fila del buffer de sala
	call suma_a_de		;5d4b
	pop bc			;5d4e
	djnz L_5D39		;5d4f   ; y la fila siguiente
	ret			;5d51
traduce_celda_a_patron:		; Convierte un byte del buffer de sala en el numero de patron que se escribe en la tabla de nombres: el nibble alto (x2) saca un puntero de tabla_de_atributos y el nibble bajo indexa dentro de la lista a la que apunta
	push hl			;5d52   ; C guarda el byte entero de la celda
	ld c,a			;5d53
	rra			;5d54   ; tres rra y &0x1E: el nibble alto pasa a indice de palabra
	rra			;5d55
	rra			;5d56
	and 01eh		;5d57
	ld hl,05d68h		;5d59   ; HL = tabla_de_atributos, los 14 punteros
	call palabra_de_tabla		;5d5c   ; HL = la lista de ese nibble alto
	ld a,c			;5d5f   ; A = el byte de la celda otra vez
	and 00fh		;5d60   ; su nibble bajo
	call suma_a_hl		;5d62   ; HL += ese nibble
	ld a,(hl)			;5d65   ; A = el numero de patron
	pop hl			;5d66
	ret			;5d67

; ----------------------------------------------------------------------
; DATOS tabla_de_atributos: 14 punteros validos de 16 posibles
;   (2*nibble_alto), indexados por L_5d52
;   0x5d68..0x5d84  (28 bytes)
DATA_tabla_de_atributos:
	defw 05d84h,05d86h,05d94h,05d98h,05d9bh,05da4h,05da8h,05db8h	; 5d68
	defw 05dc2h,05dc3h,05dc4h,05dc6h,05dc7h,05dc8h	; 5d78

; ----------------------------------------------------------------------
; DATOS tabla_de_atributos_grupos: 14 grupos de 1 a 16 bytes (uno por puntero
;   de tabla_de_atributos), numero de patron final indexado por el nibble bajo
;   0x5d84..0x5dca  (70 bytes)
DATA_tabla_de_atributos_grupos:
	defb 000h,000h	; 5d84
	defb 000h,000h,040h,040h,041h,073h,074h,083h,082h,040h,042h,043h,044h,044h	; 5d86  ..@@Ast..@BCDD
	defb 075h,076h,085h,084h	; 5d94
	defb 04bh,04bh,04bh	; 5d98
	defb 051h,052h,053h,086h,087h,088h,089h,08ah,08bh	; 5d9b  QRS......
	defb 068h,069h,078h,077h	; 5da4
	defb 06ch,07bh,06dh,07ch,06eh,07dh,063h,064h,065h,066h,067h,06fh,05fh,060h,07eh,070h	; 5da8  l{m|n}cdefgo_`~p
	defb 071h,080h,07fh,072h,061h,062h,081h,05ch,05dh,05eh	; 5db8  q..rab.\]^
	defb 04ch	; 5dc2
	defb 04eh	; 5dc3
	defb 04fh,050h	; 5dc4
	defb 000h	; 5dc6
	defb 000h	; 5dc7
	defb 043h,044h	; 5dc8

; ----------------------------------------------------------------------
; DATOS patrones_pared_tipo0: 4 patrones de pared de 44 bytes (22 filas x 2
;   bytes, 1 bit/celda), tipo de pared 0 de tabla_de_habitaciones
;   0x5dca..0x5e7a  (176 bytes)
DATA_patrones_pared_tipo0:
	defb 0c0h,000h,080h,000h,080h,000h,081h,0ffh,0ffh,000h,080h,000h,080h,000h,0ffh,0c0h,080h,000h,080h,000h,080h,000h,09fh,0ffh,080h,000h,080h,000h,080h,000h,080h,000h,08fh,0f0h,080h,003h,080h,000h,0f0h,000h,0fch,000h,0ffh,0ffh	; 5dca  ............................................
	defb 0c0h,000h,080h,000h,080h,000h,0ffh,0ffh,0c0h,000h,0c0h,000h,0c0h,0ffh,0f8h,0ffh,080h,00fh,080h,00fh,080h,0f1h,080h,0f1h,080h,00fh,080h,00fh,080h,0ffh,080h,0ffh,080h,0f8h,0fch,0f8h,080h,0ffh,080h,000h,080h,000h,080h,000h	; 5df6  ............................................
	defb 0c0h,000h,080h,000h,080h,000h,0ffh,0f8h,080h,000h,080h,000h,0fch,000h,080h,000h,080h,0ffh,080h,0ffh,0ffh,0ffh,080h,0ffh,080h,0f0h,080h,0f0h,0ffh,0ffh,080h,000h,080h,000h,080h,000h,0ffh,0ffh,080h,000h,080h,000h,080h,000h	; 5e22  ............................................
	defb 0c0h,000h,080h,000h,080h,000h,0ffh,0ffh,0c0h,000h,0c0h,000h,0c0h,000h,0ffh,0f0h,080h,000h,080h,000h,0f0h,000h,080h,000h,080h,000h,080h,000h,0ffh,0ffh,0ffh,080h,080h,080h,080h,080h,09ch,0ffh,080h,000h,080h,000h,0f0h,000h	; 5e4e  ............................................

; ----------------------------------------------------------------------
; DATOS patrones_pared_tipo1: 3 patrones de pared de 44 bytes, tipo de pared 1
;   de tabla_de_habitaciones
;   0x5e7a..0x5efe  (132 bytes)
DATA_patrones_pared_tipo1:
	defb 000h,000h,000h,000h,000h,000h,0ffh,0c0h,000h,000h,000h,00fh,0feh,000h,0c0h,000h,0c0h,000h,0ffh,0ffh,000h,000h,000h,000h,000h,000h,000h,000h,0ffh,0f0h,000h,000h,000h,000h,00fh,0ffh,000h,000h,000h,000h,000h,000h,00fh,0ffh	; 5e7a  ............................................
	defb 000h,000h,000h,000h,000h,000h,0ffh,000h,003h,0c0h,003h,0ffh,000h,080h,000h,080h,0f0h,080h,0f0h,0ffh,0f0h,000h,0f0h,000h,0f0h,000h,0f3h,0f0h,0f0h,000h,000h,000h,000h,000h,000h,01fh,0ffh,080h,000h,000h,000h,000h,001h,0ffh	; 5ea6  ............................................
	defb 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,003h,0ffh,0fch,000h,0fch,000h,0fch,000h,0fch,0ffh,000h,0fch,000h,0fch,0fch,0fch,0fch,0fch,0fch,000h,0fch,000h,000h,000h,000h,07fh,0ffh,0c0h,000h,000h,000h,000h,000h,00fh	; 5ed2  ............................................

; ----------------------------------------------------------------------
; DATOS patrones_pared_tipo2: 3 patrones de pared de 44 bytes, tipo de pared 2
;   de tabla_de_habitaciones
;   0x5efe..0x5f82  (132 bytes)
DATA_patrones_pared_tipo2:
	defb 000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,0ffh,0fch,000h,000h,000h,000h,000h,000h,0ffh,0ffh,000h,000h,000h,000h,03ch,00fh,000h,03fh,000h,0ffh,003h,0f1h,00fh,0f1h,0ffh,0ffh,000h,000h,000h,000h,000h,000h,0ffh,0ffh	; 5efe  ........................<..?................
	defb 000h,000h,000h,000h,000h,000h,000h,00fh,000h,0f0h,0ffh,000h,000h,000h,000h,01fh,001h,0f8h,0ffh,0f8h,00fh,0ffh,00ch,000h,00ch,000h,00ch,000h,00fh,0ffh,003h,0ffh,000h,003h,0f0h,003h,003h,0f0h,000h,000h,000h,000h,0ffh,0ffh	; 5f2a  ............................................
	defb 000h,000h,000h,000h,000h,000h,001h,0ffh,001h,000h,0ffh,000h,000h,01fh,000h,000h,000h,000h,0f0h,000h,003h,0ffh,000h,000h,000h,000h,000h,000h,007h,0ffh,000h,000h,000h,000h,0fch,000h,000h,0ffh,000h,000h,000h,000h,0ffh,0f8h	; 5f56  ............................................

; ----------------------------------------------------------------------
; DATOS patrones_pared_tipo3: 4 patrones de pared de 44 bytes, tipo de pared 3
;   de tabla_de_habitaciones
;   0x5f82..0x6032  (176 bytes)
DATA_patrones_pared_tipo3:
	defb 000h,003h,000h,001h,000h,001h,000h,001h,007h,0ffh,000h,001h,000h,001h,000h,001h,000h,001h,0ffh,0ffh,000h,001h,000h,001h,000h,001h,000h,001h,000h,001h,000h,001h,000h,001h,0ffh,0ffh,000h,001h,000h,001h,000h,001h,0ffh,0ffh	; 5f82  ............................................
	defb 000h,003h,000h,001h,000h,001h,0ffh,0ffh,000h,001h,000h,001h,0ffh,0f1h,000h,001h,000h,001h,000h,001h,0ffh,0ffh,000h,001h,000h,001h,000h,001h,000h,001h,000h,001h,03fh,0ffh,000h,001h,000h,001h,000h,001h,000h,001h,0ffh,0ffh	; 5fae  ................................?...........
	defb 000h,003h,000h,001h,000h,001h,0ffh,0f1h,000h,021h,000h,021h,0ffh,0f9h,000h,011h,000h,011h,000h,011h,0ffh,0f1h,000h,011h,000h,011h,000h,011h,0ffh,0f1h,000h,011h,000h,011h,000h,011h,0ffh,091h,000h,01fh,000h,01fh,000h,01fh	; 5fda  .........!.!................................
	defb 000h,003h,000h,001h,000h,001h,0ffh,081h,000h,0ffh,000h,001h,000h,001h,003h,0ffh,000h,001h,000h,001h,000h,001h,0ffh,0f9h,000h,001h,000h,001h,000h,001h,000h,001h,00fh,0f1h,0c0h,001h,000h,001h,000h,00fh,000h,03fh,0ffh,0ffh	; 6006  .........................................?..

; ----------------------------------------------------------------------
; DATOS datos_nivel_6032: Datos de nivel (0xE054=1): descriptores de sala +
;   parametros, leidos por L_6a90-L_6d67; formato interno no decodificado
;   campo a campo
;   0x6032..0x6065  (51 bytes)
DATA_datos_nivel_6032:
	defb 000h,033h,0ffh,0ffh,0ffh,048h,078h,024h,002h,048h,048h,000h,048h,0b0h,002h,004h	; 6032  .3...Hx$.HH.H...
	defb 070h,018h,018h,031h,018h,0e0h,042h,0a0h,010h,054h,078h,0d0h,001h,080h,078h,000h	; 6042  p..1..B..Tx...x.
	defb 000h,000h,008h,030h,028h,030h,0c9h,050h,028h,050h,0c9h,078h,041h,078h,0b0h,0a0h	; 6052  ...0(0.P(P.xAx..
	defb 050h,0a0h,0a1h	; 6062

; ----------------------------------------------------------------------
; DATOS datos_nivel_6065: Datos de nivel (0xE054=2), mismo formato que
;   datos_nivel_6032
;   0x6065..0x60c8  (99 bytes)
DATA_datos_nivel_6065:
	defb 000h,011h,021h,030h,0ffh,0ffh,070h,030h,018h,078h,0d1h,034h,003h,018h,0d0h,000h	; 6065  ..!0..p0.x.4....
	defb 030h,088h,004h,060h,061h,001h,005h,055h,050h,090h,077h,060h,0b8h,088h,018h,049h	; 6075  0..`a..UP.w`...I
	defb 069h,030h,061h,043h,068h,051h,003h,010h,038h,0a0h,0c0h,018h,0d1h,007h,010h,0b8h	; 6085  i0aChQ..8.......
	defb 040h,018h,040h,0c8h,080h,070h,090h,008h,048h,069h,090h,0d1h,002h,002h,020h,076h	; 6095  @.@..p..Hi.... v
	defb 002h,028h,046h,002h,078h,079h,080h,091h,00dh,030h,041h,050h,030h,060h,0d1h,078h	; 60a5  .(F.xy...0AP0`.x
	defb 051h,080h,0e0h,0a0h,050h,0a8h,091h,040h,013h,040h,0d2h,080h,093h,0a0h,022h,0a0h	; 60b5  Q...P..@.@....".
	defb 052h,0a0h,0b3h	; 60c5

; ----------------------------------------------------------------------
; DATOS datos_nivel_60c8: Datos de nivel (0xE054=5), mismo formato que
;   datos_nivel_6032
;   0x60c8..0x610d  (69 bytes)
DATA_datos_nivel_60c8:
	defb 002h,030h,0ffh,0ffh,0a0h,068h,068h,078h,0e0h,044h,002h,010h,0b8h,003h,080h,038h	; 60c8  .0...hhx.D.....8
	defb 000h,004h,030h,018h,0d8h,087h,050h,048h,079h,050h,078h,048h,068h,070h,001h,0a0h	; 60d8  ..0...PHyPxHhp..
	defb 080h,005h,018h,0f0h,038h,010h,078h,010h,090h,0e8h,0a8h,008h,000h,001h,0a0h,018h	; 60e8  ....8.x.........
	defb 00ah,028h,019h,040h,099h,048h,028h,068h,028h,080h,0a9h,088h,028h,088h,051h,0a0h	; 60f8  .(.@.H(h(...(.Q.
	defb 0a0h,0a0h,0c9h,0a8h,031h	; 6108

; ----------------------------------------------------------------------
; DATOS datos_nivel_610d: Datos de nivel (0xE054=4), mismo formato que
;   datos_nivel_6032
;   0x610d..0x6173  (102 bytes)
DATA_datos_nivel_610d:
	defb 000h,010h,020h,030h,038h,051h,038h,0ffh,098h,0d8h,058h,0ffh,002h,010h,018h,000h	; 610d  .. 08Q8...X.....
	defb 078h,0d9h,001h,006h,030h,030h,010h,052h,080h,078h,077h,098h,010h,048h,018h,0e1h	; 611d  x...00.R.xw..H..
	defb 061h,078h,051h,053h,080h,069h,003h,068h,0b0h,018h,0a9h,080h,0b9h,009h,040h,038h	; 612d  axQS.i.h......@8
	defb 040h,090h,050h,078h,068h,028h,018h,0f1h,058h,029h,070h,0b9h,090h,011h,090h,0e9h	; 613d  @.Pxh(..X)p.....
	defb 001h,000h,028h,022h,000h,010h,028h,098h,030h,041h,040h,0d1h,050h,050h,068h,089h	; 614d  ..("..(.0A@.PPh.
	defb 078h,040h,080h,0d0h,0a0h,048h,0a8h,089h,040h,01bh,040h,0abh,058h,01bh,058h,062h	; 615d  x@...H..@.@.X.Xb
	defb 080h,09bh,0a0h,02ah,0a0h,0cbh	; 616d

; ----------------------------------------------------------------------
; DATOS datos_nivel_6173: Datos de nivel (0xE054=3), mismo formato que
;   datos_nivel_6032
;   0x6173..0x61b3  (64 bytes)
DATA_datos_nivel_6173:
	defb 003h,033h,0ffh,0ffh,060h,028h,028h,048h,0b0h,041h,002h,008h,090h,000h,060h,010h	; 6173  .3..`((H.A....`.
	defb 002h,005h,034h,018h,0d8h,047h,050h,0e0h,078h,048h,010h,086h,088h,058h,075h,0a8h	; 6183  ..4..GP.xH...Xu.
	defb 018h,002h,030h,0b0h,078h,0a0h,003h,010h,008h,020h,010h,058h,008h,000h,001h,078h	; 6193  ..0.x.... .X...x
	defb 080h,007h,030h,019h,030h,0c9h,050h,090h,050h,0c9h,068h,050h,078h,0c8h,0a0h,089h	; 61a3  ..0.0.P.P.hPx...

; ----------------------------------------------------------------------
; DATOS datos_nivel_61b3: Datos de nivel (0xE054=6), mismo formato que
;   datos_nivel_6032
;   0x61b3..0x6220  (109 bytes)
DATA_datos_nivel_61b3:
	defb 002h,011h,022h,032h,0ffh,0ffh,080h,058h,074h,080h,0a1h,054h,003h,010h,0c0h,002h	; 61b3  .."2...Xt..T....
	defb 078h,0e0h,001h,040h,039h,000h,006h,033h,020h,0d8h,048h,040h,0d8h,056h,058h,058h	; 61c3  x..@9..3 .H@.VXX
	defb 070h,068h,068h,064h,028h,0e1h,075h,048h,091h,002h,0a8h,008h,068h,029h,00ah,010h	; 61d3  phhd(.uH....h)..
	defb 008h,038h,008h,058h,008h,060h,078h,078h,030h,098h,040h,058h,039h,068h,0c9h,090h	; 61e3  .8.X.`xx0.@X9h..
	defb 0e1h,0a8h,0e1h,001h,002h,058h,07eh,002h,0a0h,018h,080h,0a0h,010h,028h,019h,038h	; 61f3  .....X~......(.8
	defb 060h,038h,071h,048h,028h,060h,0c1h,068h,011h,088h,011h,0a0h,0c9h,0a8h,058h,028h	; 6203  `8qH(`.h......X(
	defb 06ah,048h,0abh,068h,052h,068h,0b3h,088h,05ah,0a0h,03bh,0a8h,0a2h	; 6213  jH.hRh..Z.;..

; ----------------------------------------------------------------------
; DATOS datos_nivel_6220: Datos de nivel (0xE054=8), mismo formato que
;   datos_nivel_6032
;   0x6220..0x6282  (98 bytes)
DATA_datos_nivel_6220:
	defb 000h,012h,022h,031h,0ffh,0ffh,0a0h,098h,078h,098h,0d1h,091h,003h,018h,0b0h,004h	; 6220  .."1....x.......
	defb 098h,0e0h,002h,060h,071h,000h,005h,030h,058h,0a0h,045h,080h,070h,057h,018h,018h	; 6230  ...`q..0X.E.pW..
	defb 079h,040h,011h,083h,068h,059h,004h,010h,070h,078h,058h,048h,0b1h,088h,041h,007h	; 6240  y@..hY..pxXH..A.
	defb 040h,020h,040h,0e0h,068h,028h,020h,031h,038h,069h,038h,0b1h,090h,0b1h,001h,002h	; 6250  @ @.h( 18i8.....
	defb 058h,036h,003h,048h,050h,070h,0a1h,078h,021h,00ch,030h,011h,050h,038h,078h,040h	; 6260  X6.HPp.x!.0.P8x@
	defb 0a0h,048h,0a8h,0c1h,028h,0cah,048h,04bh,048h,093h,078h,0e2h,0a0h,02ah,0a0h,093h	; 6270  .H..(.HKH.x..*..
	defb 0a8h,06ah	; 6280

; ----------------------------------------------------------------------
; DATOS datos_nivel_6282: Datos de nivel (0xE054=11), mismo formato que
;   datos_nivel_6032
;   0x6282..0x62cc  (74 bytes)
DATA_datos_nivel_6282:
	defb 003h,032h,0ffh,0ffh,0a0h,038h,0c4h,0a0h,098h,0a4h,002h,020h,0a0h,002h,0a0h,078h	; 6282  .2...8..... ...x
	defb 003h,005h,052h,028h,0e0h,068h,030h,058h,086h,068h,058h,040h,090h,0e8h,035h,0a0h	; 6292  ..R(.h0X.hX@..5.
	defb 010h,001h,068h,038h,004h,038h,0b8h,058h,008h,058h,098h,0a8h,0e0h,002h,002h,078h	; 62a2  ..h8.8.X.X.....x
	defb 062h,002h,078h,09ah,000h,00ah,028h,088h,030h,041h,048h,011h,048h,099h,068h,020h	; 62b2  b.x...(.0AH.H.h 
	defb 068h,079h,068h,0b8h,088h,079h,0a8h,060h,0a8h,0c0h	; 62c2  hyh..y.`..

; ----------------------------------------------------------------------
; DATOS datos_nivel_62cc: Datos de nivel (0xE054=7), mismo formato que
;   datos_nivel_6032
;   0x62cc..0x630c  (64 bytes)
DATA_datos_nivel_62cc:
	defb 003h,030h,0ffh,0ffh,060h,048h,064h,078h,0d0h,084h,002h,010h,0a8h,002h,028h,018h	; 62cc  .0..`Hdx......(.
	defb 000h,005h,030h,018h,0d8h,045h,030h,048h,069h,048h,010h,052h,088h,020h,071h,088h	; 62dc  ..0..E0HiH.R. q.
	defb 058h,002h,010h,070h,080h,0e8h,003h,010h,008h,018h,0f0h,058h,030h,000h,000h,008h	; 62ec  X..p.......X0...
	defb 030h,031h,040h,0e0h,068h,011h,068h,069h,080h,091h,088h,068h,0a0h,0d8h,0a8h,031h	; 62fc  01@.h.hi...h...1

; ----------------------------------------------------------------------
; DATOS datos_nivel_630c: Datos de nivel (0xE054=9), mismo formato que
;   datos_nivel_6032
;   0x630c..0x634a  (62 bytes)
DATA_datos_nivel_630c:
	defb 001h,032h,040h,0b8h,088h,0ffh,0a0h,020h,0a8h,0ffh,001h,020h,090h,002h,004h,061h	; 630c  .2@.... ... ...a
	defb 048h,050h,042h,068h,098h,057h,080h,018h,074h,088h,050h,002h,030h,018h,088h,088h	; 631c  HPBh.W..t.P.0...
	defb 006h,010h,0d8h,048h,0d0h,058h,068h,058h,070h,058h,0a8h,098h,078h,000h,000h,007h	; 632c  ...H.XhXpX..x...
	defb 028h,058h,028h,0b8h,048h,089h,068h,0c0h,088h,0a0h,0a8h,059h,0a8h,0c0h	; 633c  (X(.H.h....Y..

; ----------------------------------------------------------------------
; DATOS datos_nivel_634a: Datos de nivel (0xE054=10), mismo formato que
;   datos_nivel_6032
;   0x634a..0x63aa  (96 bytes)
DATA_datos_nivel_634a:
	defb 002h,012h,020h,031h,0ffh,0ffh,0a0h,070h,0b8h,098h,0b1h,094h,003h,078h,090h,003h	; 634a  .. 1...p.....x..
	defb 018h,049h,003h,098h,091h,004h,006h,041h,040h,088h,053h,068h,018h,037h,068h,068h	; 635a  .I.....A@.Sh.7hh
	defb 064h,010h,0e1h,075h,040h,011h,086h,058h,071h,003h,0a8h,008h,048h,0e9h,080h,069h	; 636a  d..u@..Xq...H..i
	defb 006h,010h,010h,030h,0e8h,058h,008h,078h,028h,030h,031h,038h,0b1h,000h,003h,0a0h	; 637a  ...0.X.x(018....
	defb 021h,038h,021h,040h,0e1h,00dh,038h,040h,040h,0c9h,048h,020h,088h,040h,0a8h,038h	; 638a  !8!@..8@@.H .@.8
	defb 0a8h,0c1h,028h,0cah,040h,04ah,048h,093h,058h,01bh,078h,09bh,0a0h,02ah,0a0h,0e2h	; 639a  ..(.@JH.X.x..*..

; ----------------------------------------------------------------------
; DATOS datos_nivel_63aa: Datos de nivel (0xE054=15), mismo formato que
;   datos_nivel_6032
;   0x63aa..0x63f3  (73 bytes)
DATA_datos_nivel_63aa:
	defb 001h,031h,040h,0b8h,0e2h,0ffh,078h,018h,018h,0ffh,002h,020h,090h,000h,078h,010h	; 63aa  .1@...x.... ..x.
	defb 003h,006h,030h,030h,018h,045h,040h,060h,069h,058h,068h,078h,078h,060h,061h,080h	; 63ba  ..00.E@`iXhxx`a.
	defb 048h,034h,088h,070h,002h,028h,0c0h,0a8h,010h,006h,010h,008h,010h,0f0h,028h,040h	; 63ca  H4.p.(........(@
	defb 048h,040h,050h,070h,068h,0d8h,000h,000h,008h,028h,068h,028h,0a9h,048h,098h,048h	; 63da  H@Pph....(h(.H.H
	defb 0e0h,078h,0b9h,0a0h,0b8h,0a8h,030h,0a8h,051h	; 63ea  .x....0.Q

; ----------------------------------------------------------------------
; DATOS datos_nivel_63f3: Datos de nivel (0xE054=12), mismo formato que
;   datos_nivel_6032
;   0x63f3..0x6457  (100 bytes)
DATA_datos_nivel_63f3:
	defb 003h,010h,021h,031h,0ffh,0ffh,060h,0a0h,0b4h,070h,0e1h,0d4h,003h,018h,0e0h,002h	; 63f3  ..!1..`..p......
	defb 028h,050h,004h,098h,089h,000h,006h,030h,040h,098h,045h,048h,010h,069h,088h,020h	; 6403  (P.....0@.EH.i. 
	defb 078h,018h,049h,071h,068h,039h,054h,080h,071h,003h,068h,0d0h,088h,031h,010h,0a1h	; 6413  x.Iqh9T.q.h..1..
	defb 008h,010h,0f1h,020h,010h,020h,048h,068h,040h,0a0h,018h,038h,091h,088h,059h,0a0h	; 6423  ... . Hh@..8..Y.
	defb 0f1h,002h,000h,038h,0aah,002h,058h,05eh,001h,098h,0e1h,00ch,030h,029h,040h,0d0h	; 6433  ...8..X^....0)@.
	defb 068h,019h,080h,0c0h,088h,071h,0a0h,0c1h,0a8h,070h,028h,0bbh,048h,0aah,078h,0b3h	; 6443  h....q...p(.H.x.
	defb 0a0h,052h,0a0h,0bbh	; 6453

; ----------------------------------------------------------------------
; DATOS datos_nivel_6457: Datos de nivel (0xE054=13), mismo formato que
;   datos_nivel_6032
;   0x6457..0x64a3  (76 bytes)
DATA_datos_nivel_6457:
	defb 002h,033h,0ffh,0ffh,080h,018h,0c8h,070h,0c8h,0e4h,002h,028h,0d0h,003h,080h,060h	; 6457  .3.....p...(...`
	defb 001h,005h,030h,018h,0d8h,042h,028h,028h,057h,050h,068h,068h,058h,050h,074h,068h	; 6467  ..0..B((WPhhXPth
	defb 068h,001h,0a8h,040h,008h,010h,008h,020h,008h,038h,010h,058h,008h,078h,030h,088h	; 6477  h..@... .8.X.x0.
	defb 0d0h,098h,008h,098h,050h,000h,000h,00ah,028h,011h,030h,0b0h,048h,028h,050h,0d1h	; 6487  ....P...(.0.H(P.
	defb 068h,019h,078h,0a0h,088h,048h,0a0h,0a9h,0a8h,020h,0a8h,068h	; 6497  h.x..H... .h

; ----------------------------------------------------------------------
; DATOS datos_nivel_64a3: Datos de nivel (0xE054=14), mismo formato que
;   datos_nivel_6032; ultimo bloque (96 B, no 107: cierra en 0x6503, donde
;   empieza L_6503 -codigo real, saltado desde 0x6ea1 con `jp L_6503`, no otro
;   grupo de nivel-)
;   0x64a3..0x6503  (96 bytes)
DATA_datos_nivel_64a3:
	defb 001h,012h,021h,033h,0ffh,098h,071h,0f1h,038h,0d8h,0d8h,0ffh,002h,0a0h,080h,003h	; 64a3  ..!3..q.8.......
	defb 020h,010h,002h,006h,030h,048h,050h,043h,068h,050h,068h,088h,080h,081h,038h,049h	; 64b3   ...0HPChPh...8I
	defb 044h,068h,049h,057h,088h,049h,002h,0a8h,048h,080h,089h,00ch,010h,008h,010h,010h	; 64c3  DhIW.I..H.......
	defb 010h,018h,010h,068h,028h,0a0h,030h,010h,058h,060h,040h,040h,010h,0b1h,030h,031h	; 64d3  ...h(.0.X`@@..01
	defb 048h,069h,068h,0a9h,001h,000h,080h,0a2h,000h,00bh,028h,068h,030h,019h,0a8h,030h	; 64e3  Hih.......(h0..0
	defb 0a8h,0c9h,030h,06bh,030h,0c3h,040h,013h,050h,0cbh,078h,0c2h,0a0h,02ah,0a0h,08bh	; 64f3  ..0k0.@.P.x..*..

; ======================================================================
; CODIGO 0x6503..0x652a  (39 bytes)
; ======================================================================


marca_bits_de_partida:		; Cruza con OR los dos bytes de (HL) contra DE: enciende en la mascara de partida los bits que trae DE
	ld c,(hl)			;6503   ; C = el byte bajo
	inc hl			;6504
	ld b,(hl)			;6505   ; B = el alto
	ld a,b			;6506
	or d			;6507   ; el alto, con OR de D
	ld (hl),a			;6508
	dec hl			;6509
	ld a,c			;650a
	or e			;650b   ; y el bajo, con OR de E
	ld (hl),a			;650c
	ret			;650d
bit_de_la_sala:		; Devuelve en DE un unico bit puesto, desplazado tantas veces como diga (0xE054): la mascara de la sala actual
	ld de,00001h		;650e   ; DE := 1, el bit de partida
	ld a,(0e054h)		;6511   ; A = (0xE054), el numero de sala
	ld b,a			;6514   ; B = ese numero, las veces que hay que desplazar
L_6515:
	dec b			;6515
	ret z			;6516
	sla e		;6517
	rl d		;6519
	jr L_6515		;651b
recorre_entidades:		; Recorre la lista de entidades desde el indice 0 y despacha cada una por su campo 1 usando tabla_652a (cuatro entradas, de las que solo la 2 hace algo)
	xor a			;651d   ; indice de entidad := 0, se empieza por la primera
	ld (0e1f4h),a		;651e
despacha_una_entidad:		; Cuerpo del bucle: lee el campo 1 de la entidad activa y salta por tabla_652a
	xor a			;6521   ; campo 0 de la entidad de 9 bytes
	call campo_de_entidad_9		;6522
	inc hl			;6525   ; HL avanza al campo 1
	ld a,(hl)			;6526   ; A = el campo 1, que dice que hacer con esta entidad
	call despacha_tabla_siguiente		;6527   ; salta por tabla_652a (4 entradas)

; ----------------------------------------------------------------------
; DATOS tabla_652a: 4 entradas, llamada L_404B desde 0x6527
;   0x652a..0x6532  (8 bytes)
DATA_tabla_652a:
	defw 06532h,06532h,06535h,06532h	; 652a  -> entidad_sin_trabajo entidad_sin_trabajo entidad_dibuja_bloque entidad_sin_trabajo

; ======================================================================
; CODIGO 0x6532..0x6573  (65 bytes)
; ======================================================================


entidad_sin_trabajo:		; Las tres entradas de tabla_652a que no hacen nada: van directas al final del bucle
	jp siguiente_entidad		;6532   ; nada que hacer con esta entidad, al siguiente indice
entidad_dibuja_bloque:		; La unica entrada util de tabla_652a: limpia el nibble bajo del campo 0, cuenta uno en el campo 1, calcula la direccion de VRAM de la entidad (8 pixeles mas arriba), borra ahi una celda y dibuja un bloque de 3x1 con el guion de 0x6575; luego cuenta uno en 0xe1f2 y remata por 0x663a
	xor a			;6535   ; campo 0 de la entidad
	call campo_de_entidad_9		;6536
	ld a,(hl)			;6539
	and 0f0h		;653a   ; se queda solo con el nibble alto
	ld (hl),a			;653c
	inc hl			;653d
	inc (hl)			;653e   ; campo 1++: cuenta un fotograma de esta animacion
	inc hl			;653f
	ld a,(hl)			;6540   ; campo 2 = la Y de la entidad
	sub 008h		;6541   ; ocho pixeles mas arriba: una celda
	ld d,a			;6543
	inc hl			;6544
	inc hl			;6545
	ld e,(hl)			;6546   ; campo 4 = la X
	call direccion_vram_de_pixel		;6547   ; direccion de VRAM de ese pixel
	xor a			;654a
	call 0004dh		;654b   ; BIOS WRTVRM - Writes data in VRAM | escribe un 0 ahi: borra la celda
	ld bc,0001fh		;654e   ; HL += 0x1F: la celda de abajo a la izquierda
	add hl,bc			;6551
	ld de,06575h		;6552   ; DE = el guion de 0x6575
	ld bc,00103h		;6555   ; BC = 1 fila de 3 celdas
	call dibuja_rectangulo_vram		;6558   ; lo dibuja
	ld a,002h		;655b
	call campo_de_entidad_9		;655d   ; campo 2 de la entidad: su posicion
	call lee_celda_propia		;6560   ; lee la celda de sala donde esta
	ld de,06575h		;6563
	call estampa_bloque_en_sala		;6566   ; y estampa ahi el mismo bloque en el buffer de sala
	ld hl,0e1f2h		;6569   ; (0xe1f2)++: la cuenta de bloques colocados
	inc (hl)			;656c
	call limpia_entidades_grandes		;656d
	jp siguiente_entidad		;6570

; ----------------------------------------------------------------------
; DATOS plantilla_de_entidad: Los once bytes de plantilla que
;   crea_entidad_desde_el_jugador (0x5843) copia al campo 6 de una entidad
;   recien creada
;   0x6573..0x657e  (11 bytes)
DATA_plantilla_de_entidad:
	defb 000h,002h,000h,000h,000h,000h,000h,000h,000h,000h,000h	; 6573  ...........

; ----------------------------------------------------------------------
; DATOS tabla_patrones_de_empuje: Los diecinueve numeros de patron del empuje,
;   indexados por el contador de 0xE148 en empuje_estampa_patron (0x6922). Los
;   primeros bytes son ademas el guion de 3 celdas que entidad_dibuja_bloque
;   dibuja desde 0x6575, y los siete de 0x6575 son la segunda de las dos
;   tablas de rotulo que alterna_rotulo_de_pausa elige
;   0x657e..0x6591  (19 bytes)
DATA_tabla_patrones_de_empuje:
	defb 000h	; 657e
	defb 000h	; 657f
	defb 000h	; 6580
	defb 000h	; 6581
	defb 000h	; 6582
	defb 000h	; 6583
	defb 044h	; 6584
	defb 000h	; 6585
	defb 000h	; 6586
	defb 043h	; 6587
	defb 000h	; 6588
	defb 000h	; 6589
	defb 000h	; 658a
	defb 000h	; 658b
	defb 000h	; 658c
	defb 044h	; 658d
	defb 000h	; 658e
	defb 000h	; 658f
	defb 043h	; 6590

; ======================================================================
; CODIGO 0x6591..0x65f0  (95 bytes)
; ======================================================================


siguiente_entidad:		; Final del bucle de recorre_entidades: sube el indice y vuelve a empezar mientras no llegue al numero de entidades vivas (0xE1F3)
	ld hl,0e1f4h		;6591   ; HL = 0xE1F4, el indice de entidad
	inc (hl)			;6594   ; el indice sube uno
	ld a,(hl)			;6595
	dec hl			;6596   ; HL = 0xE1F3, el numero de entidades vivas
	cp (hl)			;6597   ; al llegar al tope, se acabo el recorrido
	ret z			;6598
	jp despacha_una_entidad		;6599   ; si no, otra entidad
campo_de_entidad_9:		; Devuelve en HL la direccion del campo A de la entidad activa de la lista de 9 bytes (base 0xE1F5, indice en 0xE1F4), y en A su contenido
	ld hl,0e1f5h		;659c   ; HL = 0xE1F5, la base de la lista de 9 bytes
	call suma_a_hl		;659f   ; HL += el numero de campo
	ld a,(0e1f4h)		;65a2   ; A = (0xE1F4), el indice de la entidad activa
indexa_paso_9:		; Multiplica A por 9 (2i, 4i, 8i, mas i) y lo suma a HL, devolviendo en A el byte de esa direccion. Es la cola compartida de campo_de_entidad_9
	ld b,a			;65a5   ; B guarda el indice entero para el ultimo add
indexa_paso_17:		; Entrada a media cadena: con A=2i ya hecho, sigue hasta 16i y suma B, dando el paso 17 de la lista grande
	add a,a			;65a6   ; A = 4i
indexa_y_lee:		; Ultimos tres pasos comunes a las dos cadenas: dobla dos veces mas, suma el indice suelto que guarda B, suma el resultado a HL y devuelve el byte
	add a,a			;65a7   ; A = 8i
	add a,a			;65a8   ; A = 16i (o 8i si se entro por indexa_paso_9)
	add a,b			;65a9   ; mas el indice suelto: 17i, o 9i
	call suma_a_hl		;65aa   ; HL += el desplazamiento de la entidad
	ld a,(hl)			;65ad   ; A = el byte de ese campo
	ret			;65ae
dibuja_rectangulo_vram:		; Copia B filas de C bytes desde DE a la tabla de nombres, avanzando 32 bytes (una fila de pantalla) entre fila y fila: dibuja un rectangulo de celdas
	push bc			;65af   ; guarda el contador de filas, que la copia pisaria
	ld b,000h		;65b0   ; B=0 para que copia_guion_a_vram cuente solo con C
	call copia_guion_a_vram		;65b2   ; copia una fila
	ld a,020h		;65b5   ; HL += 32: la fila siguiente de la pantalla
	call suma_a_hl		;65b7
	pop bc			;65ba
	djnz dibuja_rectangulo_vram		;65bb   ; repite hasta acabar las filas
	ret			;65bd
estampa_bloque_en_sala:		; Estampa en el buffer de sala el mismo bloque de 1+3 celdas que dibuja_rectangulo_vram pinta en pantalla: una celda en la fila de arriba y tres en la de abajo, con el salto de 0x5E+2 = 96 bytes entre filas que es el stride de fila del buffer
	ld bc,0ffa0h		;65be   ; HL -= 0x60 = 96: una fila mas arriba en el buffer de sala
	add hl,bc			;65c1
	ex de,hl			;65c2
	ldi		;65c3   ; la celda de arriba
	ld bc,0005eh		;65c5   ; 0x5E mas los dos que avanzo el ldi: 96, el stride de fila del buffer de sala
	ex de,hl			;65c8
	add hl,bc			;65c9
	ex de,hl			;65ca
	ld c,003h		;65cb   ; las tres celdas de la fila de abajo
	ldir		;65cd
	ex de,hl			;65cf
	ret			;65d0
despacha_estado_de_la_sala:		; Arranca el recorrido de entidades desde cero y despacha por el nibble alto del campo 4 de la primera entidad, con tabla_65f0 (9 entradas). Deja apilado 0x674e como retorno, que es lo que cierra el recorrido
	xor a			;65d1   ; indice de entidad := 0
	ld (0e1f4h),a		;65d2
	ld (0e1c2h),a		;65d5   ; (0xe1c2) := 0: SUPOSICION, marcador que este despacho limpia
L_65D8:
	ld hl,0674eh		;65d8   ; apila 0x674e: el cierre del recorrido, que se ejecuta al volver
	push hl			;65db
	xor a			;65dc
	call campo_de_entidad_7		;65dd   ; campo 0 de la entidad de 7 bytes
	inc a			;65e0   ; con 0xFF (entidad libre) no hay nada que despachar
	ret z			;65e1
	inc hl			;65e2   ; HL avanza al campo 4
	inc hl			;65e3
	inc hl			;65e4
	inc hl			;65e5
	ld a,(hl)			;65e6
	rra			;65e7   ; el nibble alto de ese campo es el indice del despacho
	rra			;65e8
	rra			;65e9
	rra			;65ea
	and 00fh		;65eb
	call despacha_tabla_siguiente		;65ed   ; salta por tabla_65f0 (9 entradas)

; ----------------------------------------------------------------------
; DATOS tabla_65f0: 9 entradas, llamada L_404B desde 0x65ed
;   0x65f0..0x6602  (18 bytes)
DATA_tabla_65f0:
	defw 06602h,0661eh,06651h,0667bh,066c7h,0667bh,0661dh,0672ch	; 65f0
	defw 06629h	; 6600  -> sala_arranca_con_cero

; ======================================================================
; CODIGO 0x6602..0x67b7  (437 bytes)
; ======================================================================


sala_comprueba_final:		; Entrada 0 de tabla_65f0: si el contador de bloques colocados (0xE1F2) ha alcanzado su meta (0xE1F3), pone 0xE133 a 1, suena el efecto 0x94, marca los bloques y deja el campo 4 de la entidad en 0x10
	ld hl,0e1f2h		;6602   ; HL = 0xE1F2, los bloques ya colocados
	ld a,(hl)			;6605   ; A = ese contador
	inc hl			;6606
	cp (hl)			;6607   ; contra la meta de 0xE1F3
	ret nz			;6608   ; sin alcanzarla, no pasa nada
	ld a,001h		;6609
	ld (0e133h),a		;660b   ; (0xE133) := 1: la sala queda resuelta
	ld a,094h		;660e
	call reproduce_efecto		;6610   ; efecto de sonido 0x94, el de resolver la sala
	call estampa_todos_los_bloques		;6613   ; revisa la lista de bloques
	ld a,004h		;6616
	call campo_de_entidad_7		;6618   ; campo 4 de la entidad
	ld (hl),010h		;661b   ; := 0x10
entrada_vacia_de_la_sala:		; Entrada de tabla_65f0 que no hace nada
	ret			;661d   ; nada que hacer
sala_arranca_animacion:		; Entrada 1 de tabla_65f0: prepara la animacion con A=2 si la tarea activa es la 4, o con A=0 si no, deja el campo 4 en 0x20 y dibuja el bloque
	ld a,(0e000h)		;661e   ; A = la tarea activa
	cp 004h		;6621   ; en la tarea 4 se usa A=2
	push af			;6623
	ld a,002h		;6624
	jr z,L_662B		;6626
	pop af			;6628
sala_arranca_con_cero:		; Entrada 8 de tabla_65f0: la misma que sala_arranca_animacion pero forzando A=0
	push af			;6629   ; guarda las banderas
	xor a			;662a   ; A := 0
L_662B:
	call dibujo_del_paso		;662b   ; la preparacion de 0x67ae
	ld a,004h		;662e
	call campo_de_entidad_7		;6630   ; campo 4 de la entidad
	ld (hl),020h		;6633   ; := 0x20
	call dibuja_bloque_de_sala		;6635   ; y dibuja el bloque en la sala
	pop af			;6638
	ret z			;6639
limpia_entidades_grandes:		; Recorre la lista de 17 bytes y, a las que tengan el campo 0 a 1, se lo pone a 0: las libera
	ld hl,0e262h		;663a   ; HL = 0xE262, el indice
	ld (hl),000h		;663d   ; puesto a cero: se empieza por la primera
	inc hl			;663f
	ld b,(hl)			;6640   ; B = (0xE263), el tope
libera_una_entidad:		; Cuerpo del bucle: si el campo 0 vale exactamente 1, lo deja a 0
	xor a			;6641
	call campo_de_cuchillo		;6642   ; campo 0 de la entidad
	ld a,(hl)			;6645   ; A = ese campo
	dec a			;6646   ; vale 1?
	jr nz,siguiente_a_liberar		;6647
	ld (hl),a			;6649   ; entonces a 0: la entidad queda libre
siguiente_a_liberar:		; Final del bucle: sube el indice y repite hasta agotar el tope
	ld hl,0e262h		;664a   ; HL = 0xE262, el indice
	inc (hl)			;664d   ; sube uno
	djnz libera_una_entidad		;664e
	ret			;6650
sala_bloque_toca_al_jugador:		; Entrada 2 de tabla_65f0: solo con el jugador en el estado 1, compara la caja del bloque -desplazada 8 pixeles arriba y 16 a un lado- con la del jugador usando la tabla de 0x67b7; si tocan, marca 0xE133, deja el contador de fotogramas en 0x14 y el campo 1 en 0x30
	ld a,(0e134h)		;6651   ; A = el estado del jugador
	cp 001h		;6654   ; solo el estado 1 dispara esto
	ret nz			;6656
	call posicion_de_la_entidad_7		;6657   ; posicion del bloque y comprobacion de pantalla
	ret nz			;665a   ; en otra pantalla: nada
	ld a,d			;665b
	sub 008h		;665c   ; Y -= 8: una celda mas arriba
	ld d,a			;665e
	ld a,e			;665f
	sub 010h		;6660   ; X -= 0x10: dos celdas a un lado
	ld e,a			;6662
	push hl			;6663
	ld hl,067b7h		;6664   ; HL = la caja de 0x67b7
	call choca_con_el_jugador_con_tabla		;6667   ; la comparacion contra el jugador
	pop hl			;666a
	ret nc			;666b   ; sin tocarse: nada
	ld a,001h		;666c
	ld (0e133h),a		;666e   ; (0xE133) := 1
	ld a,014h		;6671
	ld (0e003h),a		;6673   ; (0xE003) := 0x14: el contador de fotogramas se reinicia
	inc hl			;6676
	ld (hl),030h		;6677   ; campo 1 := 0x30
	jr avanza_animacion_de_sala		;6679
sala_cada_32_fotogramas:		; Entrada 3 y 5 de tabla_65f0: solo actua uno de cada 32 fotogramas
	ld a,(0e003h)		;667b   ; A = contador de fotogramas
	and 01fh		;667e   ; mod 32: uno de cada 32
	ret nz			;6680
avanza_animacion_de_sala:		; Libera las entidades grandes, avanza el campo 4 de la entidad y, cuando su nibble bajo llega a 4, salta al paso siguiente (0x70 en la tarea 4, o +0x10 en las demas) contando uno en 0xE1C2
	call limpia_entidades_grandes		;6681   ; libera las entidades grandes
	ld a,004h		;6684
	call campo_de_entidad_7		;6686   ; campo 4 de la entidad
	inc (hl)			;6689   ; avanza uno
	ld a,(hl)			;668a
	and 00fh		;668b   ; nibble bajo del campo 4
	cp 004h		;668d   ; al llegar a 4, toca cambiar de paso
	jr nz,dibuja_paso_de_la_sala		;668f
	ld a,(0e000h)		;6691   ; A = la tarea activa
	cp 004h		;6694   ; en la tarea 4: campo 4 := 0x70
	jr nz,L_669C		;6696
	ld (hl),070h		;6698
	jr L_66A0		;669a
L_669C:
	ld a,(hl)			;669c
	add a,010h		;669d   ; en las demas: el nibble alto sube uno
	ld (hl),a			;669f
L_66A0:
	ld hl,0e1c2h		;66a0   ; (0xE1C2)++: cuenta un paso mas de la animacion
	inc (hl)			;66a3
	ret			;66a4
dibuja_paso_de_la_sala:		; Traduce el campo 4 en un indice de dibujo -invirtiendo el nibble bajo si el nibble alto es 0x5- y, cuando ese indice vale 1, suena ademas el efecto 0x8d
	ld a,(hl)			;66a5
	and 0f0h		;66a6   ; nibble alto del campo 4
	cp 050h		;66a8   ; el tipo 0x5x se cuenta al reves
	ld a,(hl)			;66aa
	jr nz,L_66B3		;66ab
	and 00fh		;66ad   ; nibble bajo
	sub 004h		;66af   ; 4 menos ese nibble: la cuenta invertida
	neg		;66b1
L_66B3:
	and 00fh		;66b3   ; el indice, ya normalizado
	dec a			;66b5
	cp 001h		;66b6   ; cuando vale 1, hay efecto de sonido
	jr nz,L_66C1		;66b8
	push af			;66ba
	ld a,08dh		;66bb   ; efecto 0x8d
	call reproduce_efecto		;66bd
	pop af			;66c0
L_66C1:
	call dibujo_del_paso		;66c1   ; monta el dibujo de este paso
	jp dibuja_bloque_de_sala		;66c4   ; y lo estampa en la sala
sala_recoge_el_premio:		; Entrada 4 de tabla_65f0: si el bloque toca al jugador con la caja de 0x67bb, aparca diez sprites, deja el campo 4 en 0x50, copia dos bytes a 0xE055, calcula 0xE057 segun el indice, coloca los cuatro sprites de la figura grande, suena el efecto 0x20 y reinicia el estado del jugador
	call posicion_de_la_entidad_7		;66c7   ; posicion del bloque y comprobacion de pantalla
	ret nz			;66ca   ; en otra pantalla: nada
	ld hl,067bbh		;66cb   ; HL = la caja de 0x67bb
	call choca_con_el_jugador_con_tabla		;66ce   ; la comparacion contra el jugador
	ret nc			;66d1   ; sin tocarse: nada
	call aparca_diez_sprites		;66d2   ; aparca los diez sprites desde 0xE0C8
	exx			;66d5
	ld a,004h		;66d6
	call campo_de_entidad_7		;66d8   ; campo 4 de la entidad
	ld (hl),050h		;66db   ; := 0x50, el paso de "recogido"
	inc hl			;66dd
	ld bc,00002h		;66de   ; dos bytes copiados a 0xE055
	ld de,0e055h		;66e1
	ldir		;66e4
	exx			;66e6
	ld a,(0e1f4h)		;66e7   ; A = el indice de entidad
	inc a			;66ea
	cp 001h		;66eb   ; con el indice 0, el valor va tal cual
	jr z,coloca_figura_grande		;66ed
	dec a			;66ef
	add a,a			;66f0   ; x2, comparado con 6
	cp 006h		;66f1
	jr nz,coloca_figura_grande		;66f3
	ld a,008h		;66f5   ; en ese caso, 8
coloca_figura_grande:		; Guarda en 0xE057 el valor calculado y coloca los cuatro cuartos de la figura de 32x32 en el buffer de sprites, 0x10 pixeles a un lado y 0x11 mas arriba de la posicion del bloque
	ld (0e057h),a		;66f7   ; (0xE057) := el valor calculado
	ld hl,0e0b0h		;66fa   ; HL = 0xE0B0, el principio del buffer de sprites
	ld a,010h		;66fd   ; X += 0x10
	add a,e			;66ff
	ld e,a			;6700
	ld a,d			;6701
	sub 011h		;6702   ; Y -= 0x11
	ld d,a			;6704
	ld b,002h		;6705   ; B = 2 filas de sprites
aparca_cuatro_sprites:		; Escribe la misma posicion (D,E) en cuatro entradas seguidas del buffer de sprites, en dos filas de dos separadas 16 pixeles: coloca los cuatro cuartos de una figura de 32x32
	ld c,002h		;6707   ; C = 2 sprites por fila
escribe_par_de_sprites:		; Escribe Y y X en una entrada del buffer y salta al siguiente sprite (4 bytes)
	ld (hl),d			;6709   ; Y del sprite
	inc hl			;670a
	ld (hl),e			;670b   ; X del sprite
	inc hl			;670c
	inc hl			;670d   ; salta el patron y el color: la entrada siguiente
	inc hl			;670e
	dec c			;670f
	jr nz,escribe_par_de_sprites		;6710
	ld a,d			;6712   ; la fila de abajo, 16 pixeles mas abajo
	add a,010h		;6713
	ld d,a			;6715
	djnz aparca_cuatro_sprites		;6716
	ld a,020h		;6718   ; efecto de sonido 0x20
	call reproduce_efecto		;671a
	xor a			;671d
	ld (0e130h),a		;671e   ; (0xE130) := 0: el contador de la pantalla en reposo
	inc a			;6721
	ld (0e132h),a		;6722   ; (0xE132) := 1
	inc a			;6725
	ld (0e136h),a		;6726   ; (0xE136) := 2: el jugador mirando de frente
	pop hl			;6729   ; descarta los dos niveles de retorno apilados: el fotograma se corta aqui
	pop hl			;672a
	ret			;672b
entidad_borra_o_dibuja:		; Segun lo que devuelva 0x6d49, deja el campo 4 de la entidad a 0 (borrada) o a 0x20, o pasa a dibujar el guion de 0x6575
	call decide_si_aparece		;672c
	push af			;672f   ; guarda las banderas de 0x6d49 mientras se pide el campo
	ld a,004h		;6730   ; campo 4 de la entidad de 7 bytes
	call campo_de_entidad_7		;6732
	pop af			;6735
	ld (hl),000h		;6736   ; por defecto lo deja a 0
	jr z,L_673D		;6738
	ld (hl),020h		;673a   ; con NZ: el campo 4 queda en 0x20
	ret			;673c
L_673D:
	ld de,06575h		;673d   ; con Z: DE = el guion de 0x6575 y sigue mas abajo
	jr dibuja_bloque_de_sala		;6740
campo_de_entidad_7:		; Devuelve en HL la direccion del campo A de la entidad activa de la lista de 7 bytes (base 0xE1C5, mismo indice 0xE1F4 que la lista de 9), y en A su contenido
	ld hl,0e1c5h		;6742   ; HL = 0xE1C5, la base de la lista de 7 bytes
	call suma_a_hl		;6745   ; HL += el numero de campo
	ld a,(0e1f4h)		;6748   ; A = (0xE1F4), el mismo indice que la lista de 9 bytes
	jp indexa_paso_7		;674b   ; y la multiplicacion por 7
cierra_recorrido_de_la_sala:		; Cierre del bucle de despacha_estado_de_la_sala, alcanzado por el `ret` de la rutina despachada gracias al `push hl` de 0x65db: sube el indice de 0xE1F4 y vuelve mientras no llegue a CUATRO -aqui el tope es una constante, no una variable-
	ld hl,0e1f4h		;674e   ; HL = 0xE1F4, el indice
	inc (hl)			;6751   ; sube uno
	ld a,004h		;6752   ; el tope de este recorrido es fijo: cuatro entradas
	cp (hl)			;6754
	jp nz,L_65D8		;6755   ; mientras queden, otra vuelta
	ret			;6758
dibuja_bloque_de_sala:		; Copia tres filas de cinco celdas desde DE al buffer de sala (con el stride de 0x5B+5 = 96 bytes por fila) y, si 0x5bde lo aprueba, las estampa tambien en la pantalla pasando cada byte por 0x5d52
	xor a			;6759   ; campo 0 de la entidad de 7 bytes
	call campo_de_entidad_7		;675a
	ld bc,0f0f8h		;675d   ; BC = 0xF0F8: desplazamiento con signo, 16 pixeles arriba y 8 a la izquierda
	push de			;6760
	call lee_celda_de_sala		;6761   ; lee la celda de sala de esa esquina
	pop de			;6764
	ex de,hl			;6765
	push hl			;6766
	ld b,003h		;6767   ; B = 3 filas
copia_fila_de_sala:		; Una fila del bloque: cinco celdas al buffer de sala y luego el salto de 0x5B+5 = 96 bytes a la fila siguiente
	push bc			;6769
	ld bc,00005h		;676a   ; BC = 5 celdas de ancho
	ldir		;676d
	ld a,05bh		;676f   ; 0x5B mas los cinco que avanzo el ldir: 96, el stride de fila del buffer de sala
	call suma_a_de		;6771
	pop bc			;6774
	djnz copia_fila_de_sala		;6775
	xor a			;6777
	call campo_de_entidad_7		;6778
	dec hl			;677b   ; HL-1 antes de la comprobacion de 0x5bde
	call posicion_y_pantalla_2		;677c
	pop hl			;677f   ; NZ: no hay que dibujarlo en pantalla, solo en el buffer
	ret nz			;6780
	push hl			;6781
	call direccion_vram_de_pixel		;6782   ; direccion de VRAM de esa posicion
	pop de			;6785
	ld bc,0ffdeh		;6786   ; HL -= 0x22: la esquina de arriba a la izquierda en pantalla
	add hl,bc			;6789
	ld b,003h		;678a   ; B = 3 filas otra vez
fila_en_pantalla:		; Una fila del bloque en pantalla: cinco celdas, cada byte traducido por 0x5d52 antes de escribirlo
	ld c,005h		;678c   ; C = 5 celdas de ancho
celda_en_pantalla:		; Una celda: traduce el byte del buffer de sala al numero de patron con 0x5d52 y lo escribe en la tabla de nombres
	push bc			;678e
	ld a,(de)			;678f   ; A = el byte del buffer de sala
	call traduce_celda_a_patron		;6790   ; lo traduce a numero de patron
	call 0004dh		;6793   ; BIOS WRTVRM - Writes data in VRAM | y lo escribe en la tabla de nombres
	inc hl			;6796
	inc de			;6797
	pop bc			;6798
	dec c			;6799
	dec c			;679a
	inc c			;679b
	jr nz,celda_en_pantalla		;679c
	ld a,01bh		;679e
	call suma_a_hl		;67a0
	djnz fila_en_pantalla		;67a3
	ret			;67a5
posicion_de_la_entidad_7:		; Devuelve la posicion de la entidad activa de la lista de 7 bytes y comprueba si esta en la pantalla del jugador
	xor a			;67a6   ; campo 0 de la entidad de 7 bytes
	call campo_de_entidad_7		;67a7
	dec hl			;67aa   ; HL-1 antes de la comprobacion de posicion
	jp posicion_y_pantalla_2		;67ab
dibujo_del_paso:		; Coge de la tabla de punteros de 0x67bf el guion de dibujo que corresponde al indice A y lo deja en HL
	add a,a			;67ae   ; x2: la tabla tiene dos bytes por entrada
	ld hl,067bfh		;67af   ; HL = la tabla de punteros de 0x67bf
	call palabra_de_tabla		;67b2   ; HL = el guion que toca
	ex de,hl			;67b5
	ret			;67b6

; ----------------------------------------------------------------------
; DATOS caja_del_bloque_1: Los cuatro bytes de caja (08 10 03 05) que
;   sala_bloque_toca_al_jugador (0x6664) pasa a choca_con_el_jugador_con_tabla
;   0x67b7..0x67bb  (4 bytes)
DATA_caja_del_bloque_1:
	defb 008h,010h,003h,005h	; 67b7

; ----------------------------------------------------------------------
; DATOS caja_del_bloque_2: Los cuatro bytes de caja (01 02 04 06) que
;   sala_recoge_el_premio (0x66cb) pasa a choca_con_el_jugador_con_tabla
;   0x67bb..0x67bf  (4 bytes)
DATA_caja_del_bloque_2:
	defb 001h,002h,004h,006h	; 67bb

; ----------------------------------------------------------------------
; DATOS tabla_guiones_del_paso: Tres punteros (0x67c5, 0x67d4, 0x67e3) a los
;   guiones de dibujo del paso de la sala, indexados por dibujo_del_paso
;   (0x67af)
;   0x67bf..0x67c5  (6 bytes)
DATA_tabla_guiones_del_paso:
	defw 067c5h,067d4h,067e3h	; 67bf  -> DATA_guiones_del_paso_de_sala 0x67d4 0x67e3

; ----------------------------------------------------------------------
; DATOS guiones_del_paso_de_sala: Los tres guiones de celdas a los que apunta
;   tabla_guiones_del_paso, de 15, 15 y 15 bytes: los dibujos de cada paso de
;   la animacion de la sala
;   0x67c5..0x67f2  (45 bytes)
DATA_guiones_del_paso_de_sala:
	defb 077h,000h,060h,061h,000h,079h,000h,062h,063h,000h,000h,000h,064h,065h,000h	; 67c5  w.`a.y.bc...de.
	defb 078h,06bh,06ch,06dh,06eh,079h,06fh,070h,071h,072h,000h,073h,074h,075h,076h	; 67d4  xklmnyopqr.stuv
	defb 078h,060h,066h,067h,061h,079h,062h,000h,068h,063h,000h,064h,069h,06ah,065h	; 67e3  x`fgayb.hc.dije

; ======================================================================
; CODIGO 0x67f2..0x6a68  (630 bytes)
; ======================================================================


mueve_el_muro_trampa:		; Mueve un MURO TRAMPA de la lista de 0xE3FF: un bloque de ladrillos que se desprende del techo y baja por la columna cada 32 fotogramas, matando lo que pille por delante (la salida de 0x6844). Los trae el descriptor de nivel, dos bytes por trampa, y no estan en el mapa hasta que se disparan. Deja de ser SUPOSICION desde 2026-09-04: lo confirman el descriptor -donde ocupan su propio bloque, ver tools/mapas.py- y el nombre que le da el desensamblado de Manuel Pazos (MurosTrampa)
	ld hl,0e3fdh		;67f2   ; HL = 0xE3FD, el indice de esta lista
	ld (hl),000h		;67f5   ; puesto a cero
	inc hl			;67f7
	ld a,(hl)			;67f8   ; A = (0xE3FE), cuantas hay
	or a			;67f9
	ret z			;67fa   ; sin ninguna, no hay nada que mover
L_67FB:
	ld hl,cierra_recorrido_de_trampas		;67fb   ; apila 0x68cf: el cierre del recorrido
	push hl			;67fe
	xor a			;67ff
	call campo_de_lista_e3ff		;6800   ; campo 0 de la primera
	and a			;6803
	jp z,trampa_busca_columna		;6804   ; a cero: al camino de 0x6877
	dec a			;6807   ; distinto de 1: nada que hacer
	ret nz			;6808
	ld a,(0e003h)		;6809   ; mod 32: este camino avanza uno de cada 32 fotogramas
	and 01fh		;680c
	ret nz			;680e
	inc hl			;680f
	ld a,(hl)			;6810   ; A = el campo 1
	add a,004h		;6811   ; avanza cuatro
	ld (hl),a			;6813
	and 007h		;6814   ; mod 8: decide entre los patrones 0x19 y 0x1A
	ld c,019h		;6816
	jr nz,L_681B		;6818
	inc c			;681a
L_681B:
	push hl			;681b
	call lee_celda_propia		;681c   ; lee la celda de sala donde esta
	ex de,hl			;681f
	pop hl			;6820
	ld a,(hl)			;6821
	and 007h		;6822   ; los tres bits bajos del campo 1
	jr nz,la_trampa_comprueba_al_jugador		;6824
	ld a,(de)			;6826
	and a			;6827   ; con la celda a cero y el campo alineado, sigue en 0x684e
	jr nz,trampa_sobre_suelo		;6828
la_trampa_comprueba_al_jugador:		; Estampa el patron de la trampa y, si el jugador esta en el estado 0 o 3 y la sonda de 0x68da lo alcanza, lo mata con el efecto 0x1d
	call estampa_patron_de_trampa		;682a   ; estampa el patron de la trampa
	ld hl,0e134h		;682d   ; HL = 0xe134, el estado del jugador
	ld a,(hl)			;6830
	or a			;6831
	ret nz			;6832
	ld hl,0e137h		;6833
	ld bc,00500h		;6836
	call sonda_de_la_trampa		;6839
	jr c,la_trampa_mata		;683c
	ld b,00bh		;683e
	call sonda_de_la_trampa		;6840   ; la sonda de 0x68da
	ret nc			;6843   ; no alcanza: el jugador se salva
la_trampa_mata:		; El peligro ha alcanzado al jugador: efecto 0x1d y 0xE053 a cero, la misma senal de muerte que usa el_enemigo_mata
	ld a,01dh		;6844   ; efecto de sonido 0x1d
	call reproduce_efecto		;6846
	xor a			;6849
	ld (0e053h),a		;684a   ; (0xE053) := 0: la senal de que el jugador ha muerto
	ret			;684d
trampa_sobre_suelo:		; Si la celda de debajo es del tipo 0x1x, la trampa se para y estampa el patron 0x13 o 0x14; si no, retrocede cuatro el campo 1
	ld a,(de)			;684e
	and 0f0h		;684f   ; nibble alto de la celda
	cp 010h		;6851   ; tipo 0x1x: suelo, la trampa se para
	jr z,trampa_se_para		;6853
	inc hl			;6855
	ld a,(hl)			;6856   ; si no: el campo 1 retrocede cuatro
	sub 004h		;6857
	ld (hl),a			;6859
	ret			;685a
trampa_se_para:		; La trampa ha llegado al suelo: cuenta uno en el campo anterior y estampa el patron 0x13 (o 0x14 si la celda vale 0x14)
	dec hl			;685b
	inc (hl)			;685c   ; cuenta uno en el campo anterior
	inc hl			;685d
	ld a,(de)			;685e   ; A = la celda de debajo
	cp 014h		;685f   ; vale 0x14?
	ld c,013h		;6861   ; patron 0x13 por defecto
	jr nz,L_6866		;6863
	inc c			;6865   ; con 0x14, el patron 0x14
L_6866:
	call estampa_patron_de_trampa		;6866
	ret			;6869
estampa_patron_de_trampa:		; Escribe C en el buffer de sala y lo dibuja tambien en pantalla si esta visible
	ld a,c			;686a   ; escribe el patron en el buffer de sala
	ld (de),a			;686b
	push hl			;686c
	call traduce_celda_a_patron		;686d   ; lo traduce a numero de celda
	dec hl			;6870
	dec hl			;6871
	call dibuja_si_esta_visible		;6872   ; y lo dibuja si esta en la pantalla del jugador
	pop hl			;6875
	ret			;6876
trampa_busca_columna:		; El camino con el campo 0 a cero: solo actua si la trampa esta en la misma columna Y fila que el jugador, y entonces sube por la columna del buffer de sala contando filas vacias hasta topar
	inc hl			;6877
	ld d,h			;6878   ; DE = el campo 1 de la entidad
	ld e,l			;6879
	inc hl			;687a
	inc hl			;687b
	ld c,(hl)			;687c   ; C y B = los campos 3 y 4: su X de 16 bits
	inc hl			;687d
	ld b,(hl)			;687e
	ld hl,(0e139h)		;687f   ; HL = (0xe139), la X del jugador
	and a			;6882
	sbc hl,bc		;6883   ; la resta: cero si estan en la misma columna
	ret nz			;6885   ; columnas distintas: nada
	ld a,(de)			;6886   ; A = la Y de la trampa
	ld hl,0e137h		;6887   ; HL = 0xe137, la Y del jugador
	cp (hl)			;688a   ; filas distintas: nada
	ret nz			;688b
	ld h,d			;688c
	ld l,e			;688d
	call lee_celda_propia		;688e   ; lee la celda de sala de la trampa
	ld b,000h		;6891   ; B := 0, el contador de filas vacias
sube_una_fila:		; Sube una fila del buffer de sala (HL -= 0x60 = 96) contando las vacias, y para al llegar a 0xE760 o al topar con una celda no vacia
	push hl			;6893
	push de			;6894
	and a			;6895
	ld de,0e760h		;6896   ; DE = 0xE760, el tope de la subida
	sbc hl,de		;6899   ; la resta: C si ya se ha pasado
	pop de			;689b
	jr c,marca_tope_de_columna		;689c   ; pasado el tope: sale por 0x68ad
	pop hl			;689e
	ld a,(hl)			;689f   ; A = la celda de esta fila
	and a			;68a0
	jr nz,aplica_caida_de_la_trampa		;68a1   ; no esta vacia: se para aqui
	inc b			;68a3   ; una fila vacia mas
	ld a,l			;68a4
	sub 060h		;68a5   ; HL -= 0x60 = 96: la fila de arriba
	ld l,a			;68a7
	jr nc,L_68AB		;68a8
	dec h			;68aa
L_68AB:
	jr sube_una_fila		;68ab
marca_tope_de_columna:		; Se ha llegado al tope: escribe 0x12 en esa celda
	pop hl			;68ad
	ld (hl),012h		;68ae   ; patron 0x12 en la celda del tope
aplica_caida_de_la_trampa:		; Con el numero de filas vacias contado: resta a la Y de la trampa filas*8-4 y cuenta uno en el campo anterior, dejando el contador de fotogramas a cero
	ld a,b			;68b0
	add a,a			;68b1   ; filas x8
	add a,a			;68b2
	add a,a			;68b3
	sub 004h		;68b4   ; menos 4
	ld b,a			;68b6
	ex de,hl			;68b7
	ld a,(hl)			;68b8
	sub b			;68b9   ; la Y de la trampa baja eso
	ld (hl),a			;68ba
	dec hl			;68bb
	inc (hl)			;68bc   ; y cuenta uno en el campo anterior
	xor a			;68bd
	ld (0e003h),a		;68be   ; (0xE003) := 0: el contador de fotogramas se reinicia
	ret			;68c1
campo_de_lista_e3ff:		; Devuelve el campo A de la entidad activa de la lista de 0xE3FF (indice 0xE3FD, tope 0xE3FE), con el mismo paso 9 que la lista de 0xE1F5
	ld hl,0e3ffh		;68c2   ; HL = 0xE3FF, la base de esta lista
	call suma_a_hl		;68c5   ; HL += el numero de campo
	ld a,(0e3fdh)		;68c8   ; A = el indice de la entidad activa
	ld b,a			;68cb   ; B = el indice, para la cadena del paso 9
	jp indexa_y_lee		;68cc
cierra_recorrido_de_trampas:		; Cierre del bucle de mueve_la_trampa, alcanzado por el `ret` de la rutina despachada gracias al `push hl` de 0x67fe: sube el indice de 0xE3FD y vuelve mientras no llegue al tope de 0xE3FE
	ld hl,0e3fdh		;68cf   ; HL = 0xE3FD, el indice de la trampa
	inc (hl)			;68d2   ; sube uno
	ld a,(hl)			;68d3
	inc hl			;68d4   ; HL = 0xE3FE, el tope
	cp (hl)			;68d5
	jp nz,L_67FB		;68d6   ; mientras queden, otra trampa
	ret			;68d9
sonda_de_la_trampa:		; Sonda la celda (B,C) y devuelve Z si el byte de (DE) esta entre 0x19 y 0x1A: los dos patrones que de verdad matan
	push bc			;68da
	call sondea_una_celda		;68db   ; la sonda
	ld a,(de)			;68de   ; A = el byte de (DE)
	sub 019h		;68df   ; entre 0x19 y 0x1A: los patrones que matan
	cp 002h		;68e1
	pop bc			;68e3
	ret			;68e4
avanza_el_empuje:		; Un paso del empuje del estado 5: mientras 0xE148 no sea cero, avanza el contador de animacion (salvo en el paso 0x12), estampa el patron que toca de la tabla de 0x657e y suena el efecto 0x45
	ld hl,0e148h		;68e5   ; HL = 0xE148, el contador del empuje
	ld a,(hl)			;68e8
	and a			;68e9
	ret z			;68ea   ; a cero: no hay empuje en curso
	ld a,(hl)			;68eb
	cp 012h		;68ec   ; el paso 0x12 no avanza la animacion
	inc hl			;68ee
	jr z,empuje_mira_la_celda		;68ef
	inc (hl)			;68f1   ; los demas la avanzan de tres en tres
	inc (hl)			;68f2
	inc (hl)			;68f3
empuje_mira_la_celda:		; Lee la celda donde cae el empuje y, en el paso 9, la pasa por 0x4494 para decidir si sigue
	ld b,a			;68f4   ; B = el paso del empuje
	push hl			;68f5
	call lee_celda_propia		;68f6   ; lee la celda de sala
	ex de,hl			;68f9
	pop hl			;68fa
	ld a,b			;68fb
	cp 009h		;68fc   ; solo el paso 9 hace la comprobacion fina
	jr nz,empuje_borra_la_celda		;68fe
	ld a,(de)			;6900
	call parte_en_dos_nibbles		;6901   ; la comprobacion de 0x4494
	ld a,b			;6904
	cp 001h		;6905   ; el resultado tiene que valer 1
	jr nz,cancela_el_empuje		;6907
	ld a,c			;6909
	cp 004h		;690a   ; y el segundo, entre 4 y 8
	jr c,empuje_borra_la_celda		;690c
	cp 009h		;690e
	jr nz,cancela_el_empuje		;6910
empuje_borra_la_celda:		; Si el campo anterior vale 3 o 0x0C, borra la celda; luego estampa el patron que la tabla de 0x657e asigna al paso y suena el efecto 0x45
	dec hl			;6912
	ld a,(hl)			;6913   ; A = el campo anterior
	inc hl			;6914
	cp 00ch		;6915   ; vale 0x0C?
	jr z,L_691D		;6917
	cp 003h		;6919   ; o vale 3?
	jr nz,empuje_estampa_patron		;691b
L_691D:
	xor a			;691d
	ld (de),a			;691e   ; entonces la celda se borra
empuje_estampa_patron:		; Coge de la tabla de 0x657e el patron del paso actual y lo dibuja si esta visible, rematando con el efecto 0x45
	ld a,(0e148h)		;691f   ; A = (0xE148), el paso del empuje
	ld de,0657eh		;6922   ; DE = la tabla de patrones de 0x657e
	call suma_a_de		;6925
	ld a,(de)			;6928   ; A = el patron de este paso
	dec hl			;6929
	dec hl			;692a
	call dibuja_si_esta_visible		;692b   ; y lo dibuja si esta visible
	ld a,045h		;692e   ; efecto de sonido 0x45
	jp reproduce_efecto		;6930
cancela_el_empuje:		; Pone 0xE148 a cero: el empuje se corta
	xor a			;6933
	ld (0e148h),a		;6934   ; (0xE148) := 0: se acabo el empuje
	ret			;6937
anima_bloques_que_se_abren:		; Recorre los bloques de la lista de 0xE31E (7 bytes por entrada, tope en 0xE31D) y anima los que tengan el bit 0 del campo 0 puesto
	ld hl,0e31eh		;6938   ; HL = 0xE31E, la base de la lista de bloques
	ld a,(0e31dh)		;693b   ; A = (0xE31D), cuantos bloques hay
	ld b,a			;693e   ; B = ese numero, el contador del bucle
	or a			;693f
	ret z			;6940   ; sin bloques, no hay nada que animar
busca_bloque_marcado:		; Cuerpo del bucle: salta los bloques sin el bit 0 puesto, avanzando de siete en siete
	bit 0,(hl)		;6941   ; bit 0 del campo 0: marcado para abrirse
	jr nz,anima_un_bloque		;6943
	ld de,00007h		;6945   ; no marcado: siete bytes mas alla, el bloque siguiente
	add hl,de			;6948
	djnz busca_bloque_marcado		;6949
	ret			;694b
anima_un_bloque:		; Un bloque marcado: cada 8 fotogramas avanza su contador de animacion (campo 6); en el paso 5 lo cierra, y en los demas dibuja el rectangulo que corresponda con la tabla de 0x6a68
	ld a,(0e003h)		;694c   ; A = contador de fotogramas
	and 007h		;694f   ; mod 8: la animacion avanza uno de cada ocho
	ret nz			;6951
	push hl			;6952
	pop ix		;6953   ; IX = este bloque, para indexar sus campos
	ld a,(ix+006h)		;6955   ; A = el campo 6, el paso de la animacion
	inc (ix+006h)		;6958   ; y avanza al paso siguiente
	cp 005h		;695b   ; en el paso 5 se acaba de abrir
	jr z,cierra_el_bloque		;695d
	add a,a			;695f   ; el paso x8: el desplazamiento dentro de la tabla de dibujos
	add a,a			;6960
	add a,a			;6961
	ld b,a			;6962   ; B lo guarda
	ld a,(ix+005h)		;6963   ; campo 5: decide si la animacion va en un sentido o en el otro
	cp 008h		;6966
	ld a,b			;6968
	jr z,dibuja_paso_del_bloque		;6969
	ld a,020h		;696b   ; en el otro sentido, el desplazamiento se cuenta desde 0x20
	sub b			;696d
dibuja_paso_del_bloque:		; Monta el rectangulo de este paso: origen en la tabla de 0x6a68, alto sacado del campo 0 y posicion de los campos 1 y 3, y lo dibuja solo si el bloque esta en la pantalla del jugador
	ld de,06a68h		;696e   ; DE = la tabla de dibujos de 0x6a68
	call suma_a_de		;6971
	ld c,002h		;6974   ; C := 2, el ancho en celdas
	ld a,(ix+000h)		;6976   ; campo 0 del bloque
	srl a		;6979   ; su mitad, mas 2: el alto en filas
	add a,c			;697b
	ld b,a			;697c
	ld h,(ix+003h)		;697d   ; H = el campo 3
	ld l,(ix+001h)		;6980   ; L = el campo 1: la posicion en pantalla
	ld a,(0e13ah)		;6983   ; A = el byte alto de la X del jugador
	cp (ix+004h)		;6986   ; contra el campo 4 del bloque: misma pantalla
	ret nz			;6989   ; en otra pantalla, no se dibuja
	call vram_con_ejes_cambiados		;698a   ; la preparacion de 0x6a5e
	jp dibuja_rectangulo_vram		;698d   ; y dibuja el rectangulo
cierra_el_bloque:		; Ultimo paso de la animacion: quita el bit 0 del campo 0 (el bloque deja de estar marcado) y da la vuelta a los bits 2-3 del campo 5, que es el sentido de la animacion
	res 0,(ix+000h)		;6990   ; quita la marca: el bloque ya esta abierto
	ld a,00ch		;6994
	xor (ix+005h)		;6996   ; da la vuelta a los bits 2-3 del campo 5: el sentido cambia
	ld (ix+005h),a		;6999
estampa_bloque_abierto:		; Escribe en el buffer de sala las dos columnas de celdas del bloque ya abierto, empezando por el patron 0x50 (o 0x52 si el bit 2 del campo 6 esta puesto) y bajando fila a fila con el stride de 96 bytes
	push ix		;699c
	pop hl			;699e   ; HL = el bloque
	inc hl			;699f   ; HL avanza al campo 1
	push hl			;69a0
	pop de			;69a1
	call lee_celda_propia		;69a2   ; lee la celda de sala de esa posicion
	dec de			;69a5
	ld a,(de)			;69a6   ; A = el campo 0 del bloque
	rra			;69a7   ; dos bits de ese campo, mas 2: cuantas filas ocupa
	and 003h		;69a8
	add a,002h		;69aa
	ld b,a			;69ac
	ld a,005h		;69ad
	call suma_a_de		;69af   ; DE += 5: el campo 6
	ld a,(de)			;69b2
	bit 2,a		;69b3   ; su bit 2 elige el patron de partida
	ld a,050h		;69b5   ; patron 0x50 por defecto
	jr z,L_69BB		;69b7
	inc a			;69b9   ; con el bit puesto, 0x52
	inc a			;69ba
L_69BB:
	ld c,a			;69bb
escribe_par_de_celdas:		; Escribe dos celdas seguidas (C y C+1) en el buffer de sala y baja una fila (0x5F mas el inc hl = 96)
	ld (hl),c			;69bc   ; la celda izquierda
	inc hl			;69bd
	inc c			;69be   ; la derecha, un patron mas
	ld (hl),c			;69bf
	ld a,05fh		;69c0   ; 0x5F mas el inc de arriba: 96, el stride de fila del buffer
	call suma_a_hl		;69c2
	dec c			;69c5
	djnz escribe_par_de_celdas		;69c6
	ret			;69c8
marca_el_agujero_que_se_abre:		; Recorre la lista de agujeros buscando el que este exactamente donde el jugador esta picando -misma Y y una X a 8 pixeles al lado segun a que lado mire- y le pone el bit 0 del campo 0, que es lo que hace que 0x6938 lo empiece a abrir. Picar no rompe un bloque suelto: abre un AGUJERO en el suelo de ladrillo, y por ahi se cuela el explorador y se cuelan las momias
	xor a			;69c9   ; indice de bloque := 0
	ld (0e31ch),a		;69ca
prueba_un_bloque:		; Cuerpo del bucle: monta la posicion que tendria que tener el bloque para estar donde pica el jugador
	xor a			;69cd   ; campo 0 del bloque
	call campo_de_bloque		;69ce
	push hl			;69d1
	inc hl			;69d2
	add a,a			;69d3   ; dos add y &0x18: los dos bits altos del campo pasan a multiplos de 8
	add a,a			;69d4
	and 018h		;69d5
	add a,(hl)			;69d7   ; mas el campo 1: la Y que tendria que tener el bloque
	ld d,a			;69d8
	ld a,(0e136h)		;69d9   ; bit 0 de (0xe136): a que lado mira el jugador
	rra			;69dc
	ld a,008h		;69dd   ; por defecto, 8 pixeles a un lado
	jr c,compara_posicion_de_bloque		;69df
	neg		;69e1   ; al otro lado, -8
compara_posicion_de_bloque:		; Compara la posicion montada con la del jugador (0xe137 como parte alta, 0xe139 como baja): si coinciden exactamente, marca el bloque y pone a cero su campo 6
	inc hl			;69e3
	inc hl			;69e4
	add a,(hl)			;69e5   ; mas el campo 3: la X que tendria que tener el bloque
	ld e,a			;69e6
	ld hl,0e137h		;69e7   ; HL = 0xe137, la posicion del jugador
	ld a,(hl)			;69ea   ; A = la Y del jugador
	inc hl			;69eb
	inc hl			;69ec
	ld l,(hl)			;69ed   ; HL = la Y en la parte alta y la X en la baja
	ld h,a			;69ee
	and a			;69ef
	sbc hl,de		;69f0   ; la resta: cero si el bloque esta justo ahi
	pop hl			;69f2
	jr nz,siguiente_bloque		;69f3   ; no es este: al siguiente
	set 0,(hl)		;69f5   ; bit 0 del campo 0: el bloque queda marcado para abrirse
	ld a,006h		;69f7
	call suma_a_hl		;69f9   ; HL += 6: el campo del contador de animacion
	ld (hl),000h		;69fc   ; puesto a cero: la animacion empieza de cero
	ret			;69fe
siguiente_bloque:		; Final del bucle: sube el indice y repite mientras no llegue al tope de 0xE31D
	ld hl,0e31ch		;69ff   ; HL = 0xE31C, el indice
	inc (hl)			;6a02   ; sube uno
	ld a,(hl)			;6a03
	inc hl			;6a04   ; HL = 0xE31D, el tope
	cp (hl)			;6a05   ; mientras queden, otro bloque
	jr nz,prueba_un_bloque		;6a06
	ret			;6a08
campo_de_bloque:		; Devuelve el campo A del bloque activo de la lista de 0xE31E (indice 0xE31C, tope 0xE31D), con paso 7
	ld hl,0e31eh		;6a09   ; HL = 0xE31E, la base de la lista de bloques
	call suma_a_hl		;6a0c   ; HL += el numero de campo
	ld a,(0e31ch)		;6a0f   ; A = el indice del bloque activo
indexa_paso_7:		; Multiplica A por 7 (i, 3i, 7i, con B llevando la potencia de dos) y lo suma a HL, devolviendo el byte
	ld b,a			;6a12   ; B = i
	sla b		;6a13   ; B = 2i
	add a,b			;6a15   ; A = 3i
	sla b		;6a16   ; B = 4i
	add a,b			;6a18   ; A = 7i
	call suma_a_hl		;6a19   ; HL += 7i
	ld a,(hl)			;6a1c   ; A = el byte de ese campo
	ret			;6a1d
estampa_todos_los_bloques:		; Recorre la lista de bloques que se abren y estampa cada uno en el buffer de sala y en pantalla; sin bloques no hace nada
	xor a			;6a1e
	ld hl,0e31dh		;6a1f   ; HL = 0xE31D, cuantos bloques hay
	cp (hl)			;6a22
	ret z			;6a23   ; sin bloques, nada que estampar
	ld (0e31ch),a		;6a24   ; indice de bloque := 0
	inc hl			;6a27
estampa_un_bloque_completo:		; Un bloque: su alto sale de los bits 1-2 del campo 0 mas 2, escribe las parejas de celdas en el buffer de sala y, si esta en la pantalla del jugador, tambien en la tabla de nombres
	push hl			;6a28
	ld a,(hl)			;6a29   ; A = el campo 0 del bloque
	rra			;6a2a
	and 003h		;6a2b   ; sus bits 1-2
	add a,002h		;6a2d   ; mas 2: el alto en filas
	ld b,a			;6a2f
	push bc			;6a30
	inc hl			;6a31
	push hl			;6a32
	call lee_celda_propia		;6a33   ; lee su celda de sala
	ld c,000h		;6a36   ; C := 0, el patron de partida
	call escribe_par_de_celdas		;6a38   ; escribe las parejas de celdas
	pop hl			;6a3b
	call posicion_y_pantalla		;6a3c   ; comprueba si esta en la pantalla del jugador
	pop bc			;6a3f
	ld c,002h		;6a40   ; C := 2, el ancho en celdas
	jr nz,siguiente_bloque_a_estampar		;6a42   ; en otra pantalla: no se dibuja
	call direccion_vram_de_pixel		;6a44   ; direccion de VRAM de esa posicion
	ld de,06575h		;6a47
	call dibuja_rectangulo_vram		;6a4a
siguiente_bloque_a_estampar:		; Final del bucle: siete bytes mas alla, y repite mientras no llegue al tope de 0xE31D
	pop hl			;6a4d
	ld de,00007h		;6a4e   ; HL += 7: el bloque siguiente
	add hl,de			;6a51
	exx			;6a52
	ld hl,0e31ch		;6a53   ; HL = 0xE31C, el indice
	inc (hl)			;6a56   ; sube uno
	ld a,(hl)			;6a57
	inc hl			;6a58
	cp (hl)			;6a59   ; contra el tope de 0xE31D
	exx			;6a5a
	jr nz,estampa_un_bloque_completo		;6a5b
	ret			;6a5d
vram_con_ejes_cambiados:		; Igual que direccion_vram_de_pixel pero con la posicion en HL y los dos bytes al reves: los intercambia antes de llamar
	push de			;6a5e
	ex de,hl			;6a5f   ; HL y DE, intercambiados
	ld a,d			;6a60   ; y ademas D y E entre si
	ld d,e			;6a61
	ld e,a			;6a62
	call direccion_vram_de_pixel		;6a63   ; ya en el orden que espera direccion_vram_de_pixel
	pop de			;6a66
	ret			;6a67

; ----------------------------------------------------------------------
; DATOS dibujos_del_bloque: Los cinco dibujos de dos celdas de la animacion
;   del bloque que se abre, ocho bytes cada uno (68 69 / 6A 6B / 54 55 / 7A 79
;   / 78 77, repetidos cuatro veces). dibuja_paso_del_bloque (0x696e) indexa
;   esta tabla con el paso x8
;   0x6a68..0x6a90  (40 bytes)
DATA_dibujos_del_bloque:
	defb 068h,069h,068h,069h,068h,069h,068h,069h	; 6a68  hihihihi
	defb 06ah,06bh,06ah,06bh,06ah,06bh,06ah,06bh	; 6a70  jkjkjkjk
	defb 054h,055h,054h,055h,054h,055h,054h,055h	; 6a78  TUTUTUTU
	defb 07ah,079h,07ah,079h,07ah,079h,07ah,079h	; 6a80  zyzyzyzy
	defb 078h,077h,078h,077h,078h,077h,078h,077h	; 6a88  xwxwxwxw

; ======================================================================
; CODIGO 0x6a90..0x6d3c  (684 bytes)
; ======================================================================


carga_la_sala:		; Prepara una sala: borra el buffer de RAM 0xE700+ a 0x14 y desempaqueta los patrones de pared de hasta 4 bandas del nivel (0xE054)
	xor a			;6a90
	ld (0e05eh),a		;6a91
	ld (0e05bh),a		;6a94
	call borra_sala		;6a97   ; borra el buffer entero de la sala anterior (L_6D92 lo rellena de 0x14)
	inc a			;6a9a
	ld (0e053h),a		;6a9b
	call aparca_buffer_de_sprites		;6a9e
	ld hl,0e055h		;6aa1
	ld a,(hl)			;6aa4
	dec hl			;6aa5
	ld (hl),a			;6aa6
	call columna_decorativa		;6aa7
	ld hl,06d68h		;6aaa   ; HL = tabla_de_habitaciones[(0xE054)-1] via L_6D41: puntero al bloque de datos de este nivel
	ld a,(0e054h)		;6aad
	dec a			;6ab0
	add a,a			;6ab1
	call palabra_de_tabla		;6ab2
	ex de,hl			;6ab5
	ld b,004h		;6ab6
	ld ix,0e700h		;6ab8   ; IX = 0xE700, la banda de destino de la PRIMERA banda (cada banda son 16 columnas, ver 0x6b09)
bucle_de_bandas:		; Lee un byte descriptor de sala, localiza y desempaqueta su patron de pared; repite hasta 4 veces o hasta el centinela (nibble alto del siguiente byte = 3)
	ld a,(de)			;6abc
	push bc			;6abd
	push de			;6abe
	ld hl,06d86h		;6abf
	ld c,a			;6ac2
	rra			;6ac3
	rra			;6ac4
	rra			;6ac5
	and 01eh		;6ac6   ; nibble alto del descriptor, x2: indice de palabra en la tabla de tipos de pared (0x6d86, cola de tabla_de_habitaciones)
	call palabra_de_tabla		;6ac8
	ld a,c			;6acb   ; nibble bajo del descriptor: indice de patron dentro de ese tipo
	and 00fh		;6acc
	push hl			;6ace
	ld h,000h		;6acf   ; indice*44 (los `add hl,hl` seguidos dan *48, luego `sbc hl,de` resta *4): byte de inicio del patron de 44 bytes -ver CORRECCION mas abajo, no son 22-
	ld l,a			;6ad1
	add hl,hl			;6ad2
	add hl,hl			;6ad3
	ld d,h			;6ad4
	ld e,l			;6ad5
	add hl,hl			;6ad6
	add hl,hl			;6ad7
	ld b,h			;6ad8
	ld c,l			;6ad9
	add hl,hl			;6ada
	add hl,bc			;6adb
	ld b,h			;6adc
	ld c,l			;6add
	pop hl			;6ade
	add hl,bc			;6adf
	and a			;6ae0
	sbc hl,de		;6ae1
	push ix		;6ae3   ; DE = banda de destino actual (copiada de IX antes del desempaquetado)
	pop de			;6ae5
	exx			;6ae6
	ld b,016h		;6ae7
fila_de_la_banda:		; 22 filas (B'=0x16 en el registro alterno): cada una desempaqueta 2 bytes fuente (16 bits) en 16 celdas de destino
	exx			;6ae9
	ld b,002h		;6aea   ; 2 bytes fuente por fila = 16 celdas de destino
byte_a_bits:		; Un byte fuente, sus 8 bits convertidos en 8 celdas
	push bc			;6aec
	ld b,008h		;6aed
	ld c,(hl)			;6aef
vuelca_un_bit:		; `rl c` saca primero el bit MAS significativo; 0->hueco (0x00), 1->pared (0x12)
	rl c		;6af0
	ld a,000h		;6af2
	jr nc,L_6AF8		;6af4
	ld a,012h		;6af6
L_6AF8:
	ld (de),a			;6af8
	inc de			;6af9
	djnz vuelca_un_bit		;6afa
	inc hl			;6afc
	pop bc			;6afd
	djnz byte_a_bits		;6afe
	ld a,050h		;6b00   ; avanza DE 0x50 mas alla de lo que ya sumaron los 16 `inc de` de la fila: el salto real entre filas es 16+80=0x60, no 0x50 (verificado contra RAM real, ver .notes mas abajo)
	call suma_a_de		;6b02
	exx			;6b05
	djnz fila_de_la_banda		;6b06
	exx			;6b08
	ld bc,00010h		;6b09   ; banda siguiente: IX += 0x10 (16 columnas mas alla, ver mapa_de_sala en graficos.py)
	add ix,bc		;6b0c
	pop de			;6b0e
	pop bc			;6b0f
	ld a,(de)			;6b10   ; CUIDADO: el `pop de` de 0x6b0e ha devuelto el puntero a la banda que se ACABA de desempaquetar, asi que aqui se relee ESA banda, no la siguiente. O sea que la banda cuyo nibble alto vale 3 se dibuja Y ADEMAS cierra la lista: las salas tienen una banda mas de las que parece -32 columnas las impares y 64 las pares, no 16 y 48-. Comprobado contra la RAM de una maquina de verdad, 31.680 celdas sin una diferencia (tools/omsx_dump_mapa.tcl y tools/mapas.py --comprueba)
	inc de			;6b11
	and 0f0h		;6b12
	cp 030h		;6b14
	jr z,reparte_entidades_de_la_sala		;6b16
	djnz bucle_de_bandas		;6b18
reparte_entidades_de_la_sala:		; Segunda mitad de carga_la_sala. Las CUATRO entradas de la lista de 7 bytes son las PUERTAS de la piramide: el 0xFF del descriptor marca la que no existe, la que coincide con (0xE056) es la de entrada -y se pinta abierta- y el resto quedan cerradas o invisibles segun diga 0x6d49, que mira si esa piramide ya se ha pasado. De cada una se guardan ademas la piramide de DESTINO (nibble alto) y la direccion de la flecha del mapa (nibble bajo)
	ld hl,0e1c4h		;6b1a   ; HL = 0xE1C4
	ld (hl),004h		;6b1d   ; := 4, las cuatro entradas fijas de esta lista
	inc hl			;6b1f
	ex de,hl			;6b20
	exx			;6b21
	ld b,000h		;6b22   ; B := 0, el contador de las cuatro
reparte_una_de_las_cuatro:		; Una entrada: el 0xFF del descriptor marca la que no existe (se copia tal cual y se saltan sus siete bytes); el resto se descomprime
	exx			;6b24
	ld a,(hl)			;6b25   ; A = el byte del descriptor
	inc a			;6b26   ; 0xFF marca la entrada que no existe
	jr nz,rellena_una_de_las_cuatro		;6b27
	dec a			;6b29
	ld (de),a			;6b2a   ; la copia tal cual...
	inc hl			;6b2b
	ld a,007h		;6b2c
	call suma_a_de		;6b2e   ; ...y salta los siete bytes del hueco
	jr siguiente_de_las_cuatro		;6b31
rellena_una_de_las_cuatro:		; Descomprime la posicion de esta entrada y decide su primer byte: 0x10 si es la que corresponde al valor de 0xE056, y si no 0x00 u 0x80 segun lo que diga 0x6d49
	call descomprime_posicion		;6b33   ; descomprime la posicion
	ld a,(0e056h)		;6b36   ; A = (0xE056)
	srl a		;6b39   ; su mitad, topada en 3
	cp 004h		;6b3b
	jr nz,L_6B40		;6b3d
	dec a			;6b3f
L_6B40:
	exx			;6b40
	cp b			;6b41   ; comparada con el indice de esta entrada
	exx			;6b42
	ld a,010h		;6b43   ; por defecto, el byte vale 0x10
	jr z,escribe_los_tres_bytes		;6b45   ; si coincide, se queda en 0x10
	push de			;6b47
	call decide_si_aparece		;6b48   ; si no, lo decide 0x6d49
	ld a,000h		;6b4b   ; con Z, 0x00
	jr z,L_6B51		;6b4d
	ld a,080h		;6b4f   ; sin Z, 0x80
L_6B51:
	pop de			;6b51
escribe_los_tres_bytes:		; Guarda el byte de tipo y los dos que devuelve 0x4494 al traducir el byte del descriptor
	ld (de),a			;6b52   ; el byte de tipo
	inc de			;6b53
	ld a,(hl)			;6b54   ; A = el byte del descriptor
	call parte_en_dos_nibbles		;6b55   ; lo traduce en la pareja (B,C)
	ld a,b			;6b58
	ld (de),a			;6b59   ; el primero
	inc de			;6b5a
	ld a,c			;6b5b
	ld (de),a			;6b5c   ; y el segundo
	inc de			;6b5d
	inc hl			;6b5e
siguiente_de_las_cuatro:		; Final del bucle de las cuatro entradas fijas, y de ahi al reparto de los enemigos
	exx			;6b5f
	inc b			;6b60   ; una entrada mas
	ld a,004h		;6b61   ; hasta cuatro
	cp b			;6b63
	jr nz,reparte_una_de_las_cuatro		;6b64
	exx			;6b66
	ld a,(hl)			;6b67   ; A = cuantos ENEMIGOS trae la sala
	ld (0e164h),a		;6b68   ; anotado en 0xE164, el tope de la lista de enemigos
	inc hl			;6b6b
	ld b,a			;6b6c
	add a,a			;6b6d   ; x3: tres bytes de descriptor por enemigo
	add a,b			;6b6e
	ld b,000h		;6b6f
	ld c,a			;6b71
	ld de,0e14eh		;6b72
	ldir		;6b75   ; copiados de golpe a 0xE14E
	ld de,0e1f3h		;6b77   ; DE = 0xE1F3, el tope de la lista de objetos
	ld a,(hl)			;6b7a   ; A = cuantos objetos trae la sala
	ldi		;6b7b
	inc de			;6b7d
	ld b,a			;6b7e
reparte_una_gema:		; Una GEMA de la lista de 9 bytes: su campo 0 conserva el nibble alto del descriptor -que es su COLOR, de 3 a 8- con el bit 0 puesto para marcarla activa, su campo 1 vale 1, y la posicion se descomprime
	push bc			;6b7f
	ld a,(hl)			;6b80   ; A = el byte del descriptor
	and 0f0h		;6b81   ; conserva el nibble alto...
	or 001h		;6b83   ; ...y le pone el bit 0
	ld (de),a			;6b85
	inc hl			;6b86
	inc de			;6b87
	ld a,001h		;6b88   ; el campo siguiente vale 1
	ld (de),a			;6b8a
	inc de			;6b8b
	call descomprime_posicion		;6b8c   ; y la posicion, descomprimida
	inc de			;6b8f   ; los tres bytes que quedan del registro
	inc de			;6b90
	inc de			;6b91
	pop bc			;6b92
	djnz reparte_una_gema		;6b93
	push hl			;6b95
	xor a			;6b96
	ld (0e1f4h),a		;6b97
estampa_los_objetos:		; Recorre los objetos ya repartidos: los que 0x6d49 descarta pasan a campo 1 = 3, y los que se quedan estampan su bloque de sala con el guion de 0x6d8e y guardan su patron con 0x40 sumado
	xor a			;6b9a
	call campo_de_entidad_9		;6b9b   ; campo 0 del objeto
	call decide_si_aparece		;6b9e   ; la decision de 0x6d49
	jr z,estampa_un_objeto		;6ba1   ; con Z, el objeto se queda
	ld a,(hl)			;6ba3   ; descartado: conserva el nibble alto...
	and 0f0h		;6ba4
	ld (hl),a			;6ba6
	inc hl			;6ba7
	ld (hl),003h		;6ba8   ; ...y su campo 1 pasa a 3
	jr siguiente_objeto_a_estampar		;6baa
estampa_un_objeto:		; El objeto se queda: estampa su bloque en el buffer de sala con el guion de 0x6d8e y guarda en su celda el patron que devuelve 0x4494 mas 0x40
	inc hl			;6bac
	inc hl			;6bad
	call lee_celda_propia		;6bae   ; lee su celda de sala
	push hl			;6bb1
	ld de,06d8eh		;6bb2   ; DE = el guion de bloque de 0x6d8e
	call estampa_bloque_en_sala		;6bb5   ; lo estampa
	xor a			;6bb8
	call campo_de_entidad_9		;6bb9   ; campo 0 del objeto
	call parte_en_dos_nibbles		;6bbc   ; lo traduce en la pareja (B,C)
	ld a,b			;6bbf
	add a,040h		;6bc0   ; mas 0x40: el patron del objeto en la sala
	pop hl			;6bc2
	ld (hl),a			;6bc3
siguiente_objeto_a_estampar:		; Final del bucle de estampado, y de ahi al reparto de la lista de 17 bytes
	ld hl,0e1f4h		;6bc4
	inc (hl)			;6bc7   ; el indice sube uno
	ld a,(hl)			;6bc8
	dec hl			;6bc9
	cp (hl)			;6bca   ; contra el tope de 0xE1F3
	jr nz,estampa_los_objetos		;6bcb
	pop hl			;6bcd
	ld de,0e263h		;6bce   ; DE = 0xE263, el tope de la lista de 17
	ld a,(hl)			;6bd1
	ld (de),a			;6bd2   ; anotado
	inc hl			;6bd3
	inc de			;6bd4
	or a			;6bd5
	jr z,reparte_la_lista_e2cc		;6bd6   ; con cero, esa lista se salta entera
	ld b,a			;6bd8
reparte_una_de_diecisiete:		; Una entidad de la lista de 17 bytes: solo la posicion descomprimida, y el salto de 0x0B+2 = 13 bytes hasta la siguiente
	push bc			;6bd9
	inc de			;6bda
	inc de			;6bdb
	call descomprime_posicion		;6bdc   ; la posicion, descomprimida
	ld a,00bh		;6bdf
	call suma_a_de		;6be1   ; 0x0B mas los dos inc de arriba: el paso dentro del descriptor
	pop bc			;6be4
	djnz reparte_una_de_diecisiete		;6be5
reparte_la_lista_e2cc:		; Reparte la lista de 0xE2CC: anota su tope en 0xE2CB y da a cada entrada un campo 0 igual a 1 mas su posicion descomprimida
	ld de,0e2cbh		;6be7   ; DE = 0xE2CB, el tope de esta lista
	ld a,(hl)			;6bea
	ld (de),a			;6beb   ; anotado
	inc de			;6bec
	inc hl			;6bed
	and a			;6bee
	jr z,reparte_los_bloques		;6bef   ; con cero, esta lista se salta entera
	ld b,a			;6bf1
reparte_una_de_e2cc:		; Una entrada de la lista de 0xE2CC: campo 0 a 1 y la posicion descomprimida
	push bc			;6bf2
	ld a,001h		;6bf3   ; el campo 0 vale 1
	ld (de),a			;6bf5
	inc de			;6bf6
	call descomprime_posicion		;6bf7   ; y la posicion, descomprimida
	pop bc			;6bfa
	djnz reparte_una_de_e2cc		;6bfb
	push hl			;6bfd
	ld hl,0e2cbh		;6bfe   ; HL = 0xE2CB, para recorrerla otra vez y marcar sus celdas
	ld b,(hl)			;6c01   ; B = cuantas hay
	inc hl			;6c02
	inc hl			;6c03
marca_celda_de_e2cc:		; Escribe 0x80 en la celda de sala de cada entrada de la lista de 0xE2CC
	push bc			;6c04
	push hl			;6c05
	call lee_celda_propia		;6c06   ; lee su celda de sala
	ld (hl),080h		;6c09   ; y le pone 0x80
	pop hl			;6c0b
	ld a,005h		;6c0c
	call suma_a_hl		;6c0e   ; HL += 5: la entrada siguiente
	pop bc			;6c11
	djnz marca_celda_de_e2cc		;6c12
	pop hl			;6c14
reparte_los_bloques:		; Anota en 0xE31D cuantos bloques que se abren trae la sala y reparte sus campos
	ld a,(hl)			;6c15   ; A = cuantos bloques
	inc hl			;6c16
	ld de,0e31dh		;6c17   ; DE = 0xE31D, el tope de la lista de bloques
	ld (de),a			;6c1a
	or a			;6c1b
	jr z,reparte_las_trampas		;6c1c   ; sin bloques, se salta entera
	inc de			;6c1e
	ld b,a			;6c1f
reparte_un_bloque:		; Un bloque: copia dos bytes tal cual y parte el tercero en tres campos -la X alineada a 8, el bit 1 y los bits que acaban en 0x0C-
	push bc			;6c20
	ldi		;6c21   ; los dos primeros bytes, tal cual
	ldi		;6c23
	inc de			;6c25
	ld a,(hl)			;6c26   ; A = el byte empaquetado
	and 0f8h		;6c27   ; sus bits altos: la X alineada a 8
	ld (de),a			;6c29
	inc de			;6c2a
	ld a,(hl)			;6c2b   ; su bit 1, bajado a la posicion 0
	rra			;6c2c
	rra			;6c2d
	and 001h		;6c2e
	ld (de),a			;6c30
	inc de			;6c31
	ld a,(hl)			;6c32   ; y sus bits altos, subidos a la mascara 0x0C
	rla			;6c33
	rla			;6c34
	and 00ch		;6c35
	ld (de),a			;6c37
	inc de			;6c38
	inc de			;6c39
	inc hl			;6c3a
	pop bc			;6c3b
	djnz reparte_un_bloque		;6c3c
	push hl			;6c3e
	ld ix,0e31eh		;6c3f   ; IX = 0xE31E, para estampar los bloques recien repartidos
estampa_un_bloque:		; Estampa en el buffer de sala el bloque numero (0xE31C) y pasa al siguiente, siete bytes mas alla
	call estampa_bloque_abierto		;6c43   ; estampa este bloque
	ld de,00007h		;6c46   ; IX += 7: el bloque siguiente
	add ix,de		;6c49
	ld hl,0e31ch		;6c4b
	inc (hl)			;6c4e   ; el indice sube uno
	ld a,(hl)			;6c4f
	inc hl			;6c50
	cp (hl)			;6c51   ; contra el tope de 0xE31D
	jr nz,estampa_un_bloque		;6c52
	pop hl			;6c54
reparte_las_trampas:		; Anota en 0xE3FE cuantas trampas trae la sala y descomprime la posicion de cada una
	ld de,0e3feh		;6c55   ; DE = 0xE3FE, el tope de la lista de trampas
	ld a,(hl)			;6c58   ; A = cuantas hay
	ldi		;6c59
	or a			;6c5b
	jr z,reparte_los_adornos		;6c5c   ; sin trampas, se salta entera
	ld b,a			;6c5e
reparte_una_trampa:		; Una trampa: solo su posicion descomprimida
	push bc			;6c5f
	inc de			;6c60
	call descomprime_posicion		;6c61   ; la posicion, descomprimida
	pop bc			;6c64
	djnz reparte_una_trampa		;6c65
reparte_los_adornos:		; Ultimo tramo del descriptor: B adornos, cada uno con su posicion en 0xE083 y una columna de celdas que se pinta de arriba abajo
	ex de,hl			;6c67
	ld a,(de)			;6c68   ; B = cuantos adornos quedan
	ld b,a			;6c69
	inc de			;6c6a
	and a			;6c6b
	ret z			;6c6c   ; sin adornos, se acabo el descriptor
reparte_un_adorno:		; Un adorno: monta su registro en 0xE083 partiendo el byte empaquetado en X (alineada a 8), un bit en B y otro en el campo siguiente
	push bc			;6c6d
	ld hl,0e083h		;6c6e   ; HL = 0xE083, el registro de trabajo del adorno
	ex de,hl			;6c71
	push de			;6c72
	ldi		;6c73   ; la Y, copiada tal cual
	xor a			;6c75
	ld (de),a			;6c76   ; el hueco de la fraccion
	inc de			;6c77
	ld a,(hl)			;6c78
	and 0f8h		;6c79   ; la X, alineada a 8
	ld (de),a			;6c7b
	ld a,(hl)			;6c7c
	and 001h		;6c7d   ; bit 0 del byte empaquetado, guardado en B
	ld b,a			;6c7f
	inc de			;6c80
	ld a,(hl)			;6c81
	rra			;6c82   ; y su bit 1, en el campo siguiente
	and 001h		;6c83
	ld (de),a			;6c85
	pop de			;6c86
	ex de,hl			;6c87
	push de			;6c88
	call lee_celda_propia		;6c89   ; lee su celda de sala
pinta_columna_del_adorno:		; Baja por la columna del buffer de sala escribiendo la pareja de celdas del adorno hasta topar con una celda no vacia, que recibe la pareja de remate
	ld a,(hl)			;6c8c   ; A = la celda de esta fila
	and a			;6c8d
	jr nz,remata_columna_del_adorno		;6c8e   ; no esta vacia: esta es la de remate
	ld c,020h		;6c90   ; C := 0x20, la pareja de relleno
	call escribe_pareja_de_celdas		;6c92   ; la escribe
	and a			;6c95
	push bc			;6c96
	ld bc,0ff9eh		;6c97   ; el salto de fila: -0x62, o -0x60 con el bit de B puesto
	jr z,L_6C9E		;6c9a
	inc bc			;6c9c
	inc bc			;6c9d
L_6C9E:
	add hl,bc			;6c9e   ; la fila siguiente
	pop bc			;6c9f
	jr pinta_columna_del_adorno		;6ca0
remata_columna_del_adorno:		; La celda no vacia cierra la columna: recibe la pareja 0x15 (o 0x17) y se pasa al adorno siguiente
	ld c,015h		;6ca2   ; C := 0x15, la pareja de remate
	call escribe_pareja_de_celdas		;6ca4   ; la escribe
	pop de			;6ca7
	inc de			;6ca8   ; el adorno siguiente del descriptor
	pop bc			;6ca9
	djnz reparte_un_adorno		;6caa
	ret			;6cac
escribe_pareja_de_celdas:		; Escribe en dos celdas seguidas los patrones C y C+1, subiendolos dos si B no es cero
	ld a,b			;6cad   ; B a cero: la pareja va tal cual
	and a			;6cae
	jr z,L_6CB3		;6caf
	inc c			;6cb1   ; si no, dos patrones mas alla
	inc c			;6cb2
L_6CB3:
	ld (hl),c			;6cb3   ; la celda izquierda
	inc c			;6cb4
	inc hl			;6cb5
	ld (hl),c			;6cb6   ; y la derecha
	ret			;6cb7
coloca_al_jugador_en_la_sala:		; Deja 0xE147 en 1, calcula la esquina del buffer de sala que corresponde a la pantalla del jugador (0xE13A x32 desde 0xE760), refresca sprites y marcador, y luego prepara uno a uno todos los enemigos de la sala
	ld a,001h		;6cb8   ; (0xE147) := 1
	ld (0e147h),a		;6cba
	ld a,(0e13ah)		;6cbd   ; A = el byte alto de la X del jugador: en que pantalla esta
	add a,a			;6cc0   ; x32: cada pantalla son 32 columnas del buffer
	add a,a			;6cc1
	add a,a			;6cc2
	add a,a			;6cc3
	add a,a			;6cc4
	ld de,0e760h		;6cc5   ; DE = 0xE760 + eso: la esquina de esa pantalla
	call suma_a_de		;6cc8
	call vuelca_la_vista		;6ccb   ; la preparacion de 0x5d31
	call actualiza_tabla_de_sprites		;6cce   ; vuelca el buffer de sprites a la SAT
	call recorre_entidades_17		;6cd1   ; y refresca el marcador
	xor a			;6cd4
	ld (0e165h),a		;6cd5   ; indice de enemigo := 0
prepara_todos_los_enemigos:		; Bucle que prepara los enemigos de la sala uno a uno hasta agotar el tope de 0xE164
	call prepara_un_enemigo		;6cd8   ; prepara este enemigo
	ld hl,0e165h		;6cdb
	inc (hl)			;6cde   ; el indice sube uno
	ld a,(hl)			;6cdf
	dec hl			;6ce0
	cp (hl)			;6ce1   ; contra el tope de 0xE164
	jr nz,prepara_todos_los_enemigos		;6ce2
	ret			;6ce4
prepara_un_enemigo:		; Rellena el registro de 22 bytes de un enemigo: tipo 4, posicion sacada de los tres bytes que el descriptor dejo en 0xE14E, y una variante elegida sumando (0xE058) al tercer byte y topandola en 4, que indexa tabla_de_cinco
	call prepara_enemigo_activo		;6ce5   ; prepara el enemigo activo, con IX apuntando a su registro
	push ix		;6ce8
	pop hl			;6cea
	ld (hl),004h		;6ceb   ; campo 0 := 4, el tipo de enemigo
	inc hl			;6ced
	inc hl			;6cee
	inc hl			;6cef
	ld de,0e14eh		;6cf0   ; DE = 0xE14E, los tres bytes por enemigo del descriptor
	ld a,(0e165h)		;6cf3   ; A = el indice de este enemigo
	ld c,a			;6cf6
	add a,a			;6cf7   ; x3: tres bytes por enemigo
	add a,c			;6cf8
	call suma_a_de		;6cf9
	ex de,hl			;6cfc
	ldi		;6cfd   ; la Y, copiada tal cual
	inc de			;6cff
	ld a,(hl)			;6d00
	and 0f8h		;6d01   ; la X, alineada a 8
	ld (de),a			;6d03
	inc de			;6d04
	ld a,(hl)			;6d05
	and 001h		;6d06   ; y la pantalla, el bit 0
	ld (de),a			;6d08
	inc de			;6d09
	inc hl			;6d0a
	ld a,(hl)			;6d0b   ; C = el tercer byte, la variante base
	ld c,a			;6d0c
	ld a,(0e058h)		;6d0d   ; A = (0xE058), que sube con el avance de la partida
	add a,c			;6d10
	cp 005h		;6d11   ; sumados, y topados en 4
	jr c,aplica_variante_de_enemigo		;6d13
	ld a,004h		;6d15
aplica_variante_de_enemigo:		; Coge de tabla_de_cinco el byte de la variante y lo reparte: su nibble alto al campo 0, la variante al campo 13, y los dos que devuelve 0x4494 al campo 16
	ld c,a			;6d17   ; C = la variante, ya topada
	ex de,hl			;6d18
	ld de,06d3ch		;6d19   ; DE = tabla_de_cinco
	call suma_a_de		;6d1c
	ld a,(de)			;6d1f   ; A = el byte de esta variante; B lo guarda entero
	ld b,a			;6d20
	and 0f0h		;6d21   ; solo el nibble alto va al campo 0
	ld (hl),a			;6d23
	ld a,00ah		;6d24
	call suma_a_hl		;6d26   ; HL += 10
	ld (hl),010h		;6d29   ; ese campo := 0x10
	inc hl			;6d2b
	inc hl			;6d2c
	inc hl			;6d2d
	ld (hl),c			;6d2e   ; y el campo 13 := la variante
	inc de			;6d2f
	call ranura_de_sprite_del_enemigo		;6d30   ; la preparacion de 0x71e7
	inc hl			;6d33
	inc hl			;6d34
	inc hl			;6d35
	ld a,b			;6d36
	call parte_en_dos_nibbles		;6d37   ; el byte de la variante, traducido en la pareja (B,C)
	ld (hl),c			;6d3a   ; y C al ultimo campo
	ret			;6d3b

; ----------------------------------------------------------------------
; DATOS tabla_de_cinco: Cinco bytes, uno por cada valor de C (0 a 4, fijado
;   por el clamp de 0x6d11)
;   0x6d3c..0x6d41  (5 bytes)
DATA_tabla_de_cinco:
	defb 05fh,059h,0a4h,0a8h,0bah	; 6d3c

; ======================================================================
; CODIGO 0x6d41..0x6d68  (39 bytes)
; ======================================================================


palabra_de_tabla:		; HL = palabra de 16 bits en (tabla base=HL) + A; el mismo ayudante generico que usan tabla_de_atributos y tabla_de_tareas
	call suma_a_hl		;6d41
	ld a,(hl)			;6d44   ; lee la palabra completa: byte bajo primero (A=(HL)), luego byte alto (H=(HL+1))
	inc hl			;6d45
	ld h,(hl)			;6d46
	ld l,a			;6d47
	ret			;6d48
decide_si_aparece:		; Decide si una entidad aparece en esta partida: cruza con AND los dos bytes de (0xE062) contra los que devuelve 0x650e y suma los resultados. Devuelve Z cuando no queda ningun bit en comun
	ld bc,(0e062h)		;6d49   ; BC = (0xE062), la mascara de la partida
	push bc			;6d4d
	call bit_de_la_sala		;6d4e   ; la mascara de la entidad, en DE
	pop bc			;6d51
	ld a,b			;6d52   ; los bytes altos, cruzados con AND
	and d			;6d53
	ld b,a			;6d54
	ld a,c			;6d55   ; los bajos, tambien
	and e			;6d56
	add a,b			;6d57   ; sumados: Z si no coinciden en ningun bit
	ret			;6d58
descomprime_posicion:		; Descomprime al formato de registro los DOS bytes con que el descriptor del nivel guarda una posicion: copia la Y tal cual, deja un hueco, y parte el segundo byte en la X (alineada a 8, bits altos) y la pantalla (bit 0). Es el ayudante que usa todo el reparto de entidades de la sala
	ldi		;6d59   ; la Y, copiada tal cual
	inc de			;6d5b   ; deja el hueco de la fraccion de X
	ld a,(hl)			;6d5c   ; A = el byte empaquetado
	and 0f8h		;6d5d   ; sus bits 3-7 son la X, alineada a 8
	ld (de),a			;6d5f
	inc de			;6d60
	ld a,(hl)			;6d61   ; y su bit 0 es la pantalla: el byte alto de la X
	and 001h		;6d62
	ld (de),a			;6d64
	inc de			;6d65
	inc hl			;6d66
	ret			;6d67

; ----------------------------------------------------------------------
; DATOS tabla_de_habitaciones: 19 punteros: 15 indexados por nivel via 0xE054
;   y los 4 ultimos reutilizados como base de cada tipo de pared; confirmada
;   leyendo y con watchpoint en openMSX
;   0x6d68..0x6d8e  (38 bytes)
DATA_tabla_de_habitaciones:
	defw 06032h,06065h,06173h,0610dh,060c8h,061b3h,062cch,06220h	; 6d68
	defw 0630ch,0634ah,06282h,063f3h,06457h,064a3h,063aah,05dcah	; 6d78
	defw 05e7ah,05efeh,05f82h	; 6d88  -> DATA_patrones_pared_tipo1 DATA_patrones_pared_tipo2 DATA_patrones_pared_tipo3

; ----------------------------------------------------------------------
; DATOS brillos_de_la_gema: Los cuatro bytes que rodean a una gema al
;   sembrarla: 0x40 el destello de arriba, 0x41 el de la izquierda, 0x00 el
;   hueco donde va la propia gema y 0x42 el destello de la derecha. Los copia
;   el bucle de 0x6795 una fila por encima y luego a los lados
;   0x6d8e..0x6d92  (4 bytes)
DATA_brillos_de_la_gema:
	defb 040h	; 6d8e
	defb 041h	; 6d8f
	defb 000h	; 6d90
	defb 042h	; 6d91

; ======================================================================
; CODIGO 0x6d92..0x6dc4  (50 bytes)
; ======================================================================


borra_sala:		; Rellena 0xE760-0xF000 (0x8A0 = 2208 bytes) de 0x14: el fondo que el desempaquetado de carga_la_sala deja donde no llega ninguna banda
	ld hl,0e760h		;6d92
	ld de,0e761h		;6d95
	ld bc,008a0h		;6d98   ; 0x8A0 = 2208 bytes hasta 0xF000; pero empieza en 0xE760, 0x60 (una fila) DESPUES de donde escribe la banda 0 (0xE700): la fila 0 del buffer nunca se borra aqui -SUPOSICION: no hace falta, porque el desempaquetado siempre reescribe sus propias columnas de la fila 0 antes de leerlas-
	ld (hl),014h		;6d9b
	ldir		;6d9d
	ret			;6d9f
columna_decorativa:		; Dibuja 5 veces el mismo guion de 9 bytes en VRAM, 8 pixeles mas abajo cada vez: una columna de 40 px, una por grupo de 4 niveles
	ld a,(0e054h)		;6da0
	dec a			;6da3
	rra			;6da4
	rra			;6da5
	and 003h		;6da6   ; (0xE054-1) rra x2, and 3: grupo de 4 niveles (0-3), no el nivel en si
	ld hl,06dc4h		;6da8
	call indexa_paso_9		;6dab   ; HL = 0x6dc4 + 9*grupo: direccion DIRECTA del guion (no un puntero, ver L_65A5)
	ex de,hl			;6dae
	ld hl,00200h		;6daf
	ld b,005h		;6db2
repite_guion_cinco_veces:		; Dibuja el mismo guion cinco veces seguidas, avanzando el destino en VRAM 8 bytes cada vez: la columna decorativa de 40 pixeles
	push bc			;6db4
	push de			;6db5
	push hl			;6db6
	call dibuja_guion_x3_tercios		;6db7   ; dibuja el guion 5 veces, avanzando el destino en VRAM 8 bytes cada vez (bucle en 0x6db4-6dc1)
	pop hl			;6dba
	ld de,00008h		;6dbb   ; 8 bytes: la columna siguiente
	add hl,de			;6dbe
	pop de			;6dbf
	pop bc			;6dc0
	djnz repite_guion_cinco_veces		;6dc1   ; hasta las cinco repeticiones
	ret			;6dc3

; ----------------------------------------------------------------------
; DATOS guion_6dc4: Guion de 9 bytes para L_44f1 (entrada directa), grupo de
;   nivel 0 de L_6da0/L_65a5, dibujado 5 veces (columna de 40 px)
;   0x6dc4..0x6dcd  (9 bytes)
DATA_guion_6dc4:
	defb 002h,0a0h,002h,060h,002h,0a0h,002h,060h,000h	; 6dc4  ...`...`.

; ----------------------------------------------------------------------
; DATOS guion_6dcd: Guion de 9 bytes para L_44f1, grupo de nivel 1 de
;   L_6da0/L_65a5
;   0x6dcd..0x6dd6  (9 bytes)
DATA_guion_6dcd:
	defb 002h,040h,002h,070h,002h,040h,002h,070h,000h	; 6dcd  .@.p.@.p.

; ----------------------------------------------------------------------
; DATOS guion_6dd6: Guion de 9 bytes para L_44f1, grupo de nivel 2 de
;   L_6da0/L_65a5
;   0x6dd6..0x6ddf  (9 bytes)
DATA_guion_6dd6:
	defb 002h,060h,002h,0a0h,002h,060h,002h,0a0h,000h	; 6dd6  .`...`...

; ----------------------------------------------------------------------
; DATOS guion_6ddf: Guion de 9 bytes para L_44f1, grupo de nivel 3 de
;   L_6da0/L_65a5
;   0x6ddf..0x6de8  (9 bytes)
DATA_guion_6ddf:
	defb 002h,0c0h,002h,0b0h,002h,0c0h,002h,030h,000h	; 6ddf  .......0.

; ======================================================================
; CODIGO 0x6de8..0x6dee  (6 bytes)
; ======================================================================


L_6DE8:
	ld a,(0e130h)		;6de8
	call despacha_tabla_siguiente		;6deb

; ----------------------------------------------------------------------
; DATOS tabla_6dee: 4 entradas, llamada L_404B desde 0x6deb
;   0x6dee..0x6df6  (8 bytes)
DATA_tabla_6dee:
	defw 06df6h,06e56h,06e7dh,06eb0h	; 6dee  -> sala_sube_al_jugador sala_espera_animacion sala_reparte_premio sala_termina

; ======================================================================
; CODIGO 0x6df6..0x6f47  (337 bytes)
; ======================================================================


sala_sube_al_jugador:		; Entrada 0 de tabla_6dee: cada 4 fotogramas fija la velocidad en 0x01E0, avanza al jugador y -en la tarea 4- lo va subiendo pixel a pixel con la pose 1, o lo baja hasta que la Y del primer sprite lo alcanza
	ld hl,0e13eh		;6df6
	ld a,(0e003h)		;6df9   ; A = contador de fotogramas
	and 003h		;6dfc   ; mod 4: uno de cada cuatro
	ret nz			;6dfe
	ld hl,001e0h		;6dff   ; velocidad := 0x01E0
	ld (0e13bh),hl		;6e02
	call avanza_al_jugador		;6e05   ; avanza la posicion del jugador
	ld a,(0e000h)		;6e08   ; A = la tarea activa
	cp 004h		;6e0b   ; solo la tarea 4 sube
	jr nz,sala_baja_al_jugador		;6e0d
	ld hl,0e137h		;6e0f
	inc (hl)			;6e12   ; la Y del jugador sube un pixel
	ld a,(hl)			;6e13
	and 007h		;6e14   ; cada ocho pixeles, una celda completa
	jr nz,sala_avanza_pose		;6e16
	ld a,001h		;6e18
	ld (0e13fh),a		;6e1a   ; pose 1, de pie
	call monta_sprite_del_jugador		;6e1d   ; y lo redibuja
	jr sala_fija_velocidad_lenta		;6e20
sala_baja_al_jugador:		; El camino fuera de la tarea 4: baja la Y del jugador un pixel por vuelta hasta que su X mas 8 alcanza la del primer sprite del buffer
	ld hl,0e137h		;6e22
	dec (hl)			;6e25   ; la Y del jugador baja un pixel
	inc hl			;6e26
	inc hl			;6e27
	ld a,(hl)			;6e28   ; A = la X del jugador
	add a,008h		;6e29   ; mas 8
	ld hl,0e0b1h		;6e2b   ; contra la X del primer sprite del buffer
	cp (hl)			;6e2e
	jr c,sala_avanza_pose		;6e2f   ; todavia no llega: solo la animacion
	call aparca_buffer_de_sprites		;6e31   ; ya llega: aparca los sprites
	jr sala_fija_velocidad_lenta		;6e34
sala_avanza_pose:		; Avanza la pose del jugador (mod 8) y lo redibuja
	ld hl,0e13fh		;6e36
	inc (hl)			;6e39   ; la pose sube una
	and 007h		;6e3a   ; mod 8: ocho poses en el ciclo
	ld (hl),a			;6e3c
	jp monta_sprite_del_jugador		;6e3d
sala_fija_velocidad_lenta:		; Deja la velocidad en 0x00A8, aparca cuatro sprites, cuenta uno en 0xE130 y reinicia el contador de fotogramas a 0x20
	ld bc,000a8h		;6e40   ; velocidad := 0x00A8, mas lenta
	ld (0e13bh),bc		;6e43
	ld b,004h		;6e47   ; B = 4 sprites a aparcar
	call aparca_n_sprites		;6e49
	ld hl,0e130h		;6e4c
	inc (hl)			;6e4f   ; (0xE130)++: el contador de esta pantalla
	ld a,020h		;6e50
	ld (0e003h),a		;6e52   ; (0xE003) := 0x20
	ret			;6e55
sala_espera_animacion:		; Entrada 1 de tabla_6dee: deja correr el despacho de la sala y, cuando 0xE1C2 se pone, suena el efecto 0x20 y avanza (fuera de la tarea 4), o deja 0x28 fotogramas de espera si esta en la tarea 4
	call despacha_estado_de_la_sala		;6e56   ; el despacho de estado de la sala
	ld a,(0e1c2h)		;6e59   ; (0xE1C2): mientras siga a cero, se espera
	or a			;6e5c
	ret z			;6e5d
	ld a,(0e000h)		;6e5e   ; A = la tarea activa
	cp 004h		;6e61   ; en la tarea 4, la espera de 0x28
	jr z,sala_espera_40_fotogramas		;6e63
	ld a,020h		;6e65
	call reproduce_efecto		;6e67   ; efecto de sonido 0x20
	ld hl,0e130h		;6e6a
	inc (hl)			;6e6d   ; (0xE130)++
	xor a			;6e6e
	ld (0e1f4h),a		;6e6f   ; indice de entidad := 0
	ret			;6e72
sala_espera_40_fotogramas:		; En la tarea 4: deja el contador en 0x28 fotogramas y avanza el orden
	ld a,028h		;6e73   ; (0xE004) := 0x28
	ld (0e004h),a		;6e75
	ld hl,0e001h		;6e78
	inc (hl)			;6e7b   ; y avanza el orden de la tarea
	ret			;6e7c
sala_reparte_premio:		; Entrada 2 de tabla_6dee: agotado el contador, si 0x6d49 lo aprueba suma 0x2000 al marcador con el efecto 0x8f; en cualquier caso cuenta 0xE130, deja 0x70 fotogramas y actualiza la mascara de partida de 0xE062
	ld hl,0e004h		;6e7d   ; HL = 0xE004, el contador
	dec (hl)			;6e80
	ret p			;6e81   ; mientras quede, espera
	call decide_si_aparece		;6e82   ; la decision de 0x6d49
	jr nz,sala_actualiza_mascara		;6e85
	ld de,02000h		;6e87   ; suma 0x2000 al marcador
	call suma_al_marcador		;6e8a
	ld a,08fh		;6e8d
	call reproduce_efecto		;6e8f   ; efecto de sonido 0x8f
sala_actualiza_mascara:		; Cuenta uno en 0xE130, deja 0x70 fotogramas y actualiza la mascara de partida de 0xE062
	ld hl,0e130h		;6e92
	inc (hl)			;6e95   ; (0xE130)++
	ld a,070h		;6e96
	ld (0e004h),a		;6e98   ; (0xE004) := 0x70
	call bit_de_la_sala		;6e9b   ; la mascara de 0x650e
	ld hl,0e062h		;6e9e   ; HL = 0xE062, la mascara de la partida
	jp marca_bits_de_partida		;6ea1
avanza_ronda:		; Cuenta uno en 0xE050, suena el efecto 0x8a y remata por 0x4385
	ld hl,0e050h		;6ea4
	inc (hl)			;6ea7   ; (0xE050)++: una ronda mas
	ld a,08ah		;6ea8
	call reproduce_efecto		;6eaa   ; efecto de sonido 0x8a
	jp dibuja_contador_de_rondas		;6ead
sala_termina:		; Entrada 3 de tabla_6dee: cuenta atras 0xE004 y, al agotarse, pone 0xE132 a cero y manda a la tarea 8
	ld hl,0e003h		;6eb0
	ld a,(hl)			;6eb3   ; A = contador de fotogramas
	and 003h		;6eb4
	inc hl			;6eb6
	dec (hl)			;6eb7   ; el contador de 0xE004 baja uno
	ret nz			;6eb8   ; mientras quede, espera
	xor a			;6eb9
	ld (0e132h),a		;6eba   ; (0xE132) := 0
	ld a,008h		;6ebd
	ld (0e000h),a		;6ebf   ; (0xE000) := 8: a la tarea 8
	ret			;6ec2
monta_escena_de_premio:		; Copia los 16 bytes de plantilla de sprites de 0x6f4c al buffer, ajusta dos colores, y coloca al jugador y la figura grande en la posicion de la entidad que dice 0xE056
	ld de,0e0b0h		;6ec3   ; DE = 0xE0B0, el buffer de sprites
	ld hl,06f4ch		;6ec6   ; HL = la plantilla de 0x6f4c
	ld bc,00010h		;6ec9   ; 16 bytes: cuatro sprites
	ldir		;6ecc
	ld a,00eh		;6ece
	ld (0e0c3h),a		;6ed0   ; el color del sprite 4 := 0x0E
	ld a,006h		;6ed3
	ld (0e0c7h),a		;6ed5   ; y el del sprite 5 := 0x06
	ld a,(0e056h)		;6ed8   ; A = (0xE056)
	srl a		;6edb   ; su mitad, topada en 3
	cp 004h		;6edd
	jr nz,coloca_jugador_junto_al_premio		;6edf
	dec a			;6ee1
coloca_jugador_junto_al_premio:		; Copia al registro del jugador la posicion de la entidad elegida, ocho pixeles mas arriba y ocho a un lado, y le carga los cinco bytes de plantilla de 0x6f47
	ld hl,0e1c5h		;6ee2   ; HL = 0xE1C5, la lista de 7 bytes
	call indexa_paso_7		;6ee5   ; HL += 7 * indice
	push hl			;6ee8
	ld de,0e137h		;6ee9   ; DE = 0xE137, el registro del jugador
	ld a,(hl)			;6eec
	sub 008h		;6eed   ; Y := la de la entidad menos 8
	ld (de),a			;6eef
	inc de			;6ef0
	inc hl			;6ef1
	ldi		;6ef2
	ld a,(hl)			;6ef4
	add a,008h		;6ef5   ; X := la de la entidad mas 8
	ld (de),a			;6ef7
	inc de			;6ef8
	inc hl			;6ef9
	ldi		;6efa
	ld bc,00005h		;6efc   ; BC = 5 bytes de plantilla
	ld hl,06f47h		;6eff   ; HL = la plantilla de 0x6f47
	ldir		;6f02
	call monta_sprite_del_jugador		;6f04   ; y monta el sprite del jugador
	ld a,(0e056h)		;6f07   ; A = (0xE056) otra vez
	srl a		;6f0a   ; su mitad, topada en 3
	cp 004h		;6f0c
	jr nz,coloca_figura_del_premio		;6f0e
	dec a			;6f10
coloca_figura_del_premio:		; Deja el indice en 0xE1F4, pone el campo 4 de esa entidad en 0x50 y coloca los cuatro cuartos de la figura de 32x32 en el buffer de sprites
	ld (0e1f4h),a		;6f11   ; (0xE1F4) := el indice
	ld a,004h		;6f14
	call campo_de_entidad_7		;6f16   ; campo 4 de la entidad de 7 bytes
	ld (hl),050h		;6f19   ; := 0x50, el paso de "recogido"
	pop hl			;6f1b
	ld d,(hl)			;6f1c   ; D = su Y
	inc hl			;6f1d
	inc hl			;6f1e
	ld e,(hl)			;6f1f   ; E = su X
	ld hl,0e0b0h		;6f20   ; HL = 0xE0B0, el buffer de sprites
	ld a,010h		;6f23
	add a,e			;6f25   ; X += 0x10
	ld e,a			;6f26
	ld a,d			;6f27
	sub 011h		;6f28   ; Y -= 0x11
	ld d,a			;6f2a
	ld b,002h		;6f2b   ; B = 2 filas de sprites
fila_de_la_figura:		; Una fila de la figura grande: dos sprites, y luego 16 pixeles mas abajo
	ld c,002h		;6f2d   ; C = 2 sprites por fila
escribe_sprite_de_la_figura:		; Escribe Y y X en una entrada del buffer y salta a la siguiente
	ld (hl),d			;6f2f   ; Y del sprite
	inc hl			;6f30
	ld (hl),e			;6f31   ; X del sprite
	inc hl			;6f32
	inc hl			;6f33   ; salta el patron y el color
	inc hl			;6f34
	dec c			;6f35
	jr nz,escribe_sprite_de_la_figura		;6f36
	ld a,d			;6f38
	add a,010h		;6f39   ; la fila de abajo, 16 pixeles mas abajo
	ld d,a			;6f3b
	djnz fila_de_la_figura		;6f3c
	xor a			;6f3e
	ld (0e130h),a		;6f3f   ; (0xE130) := 0
	inc a			;6f42
	ld (0e136h),a		;6f43   ; (0xE136) := 1
	ret			;6f46

; ----------------------------------------------------------------------
; DATOS plantilla_registro_del_premio: Los cinco bytes que
;   coloca_jugador_junto_al_premio (0x6eff) copia al final del registro del
;   jugador en la escena de premio
;   0x6f47..0x6f4c  (5 bytes)
DATA_plantilla_registro_del_premio:
	defb 0c8h,000h,000h,001h,001h	; 6f47

; ----------------------------------------------------------------------
; DATOS plantilla_sprites_del_premio: Los dieciseis bytes (cuatro entradas
;   Y/X/patron/color) que monta_escena_de_premio (0x6ec6) copia al principio
;   del buffer de sprites
;   0x6f4c..0x6f5c  (16 bytes)
DATA_plantilla_sprites_del_premio:
	defb 0e0h,0b0h,0d8h,001h	; 6f4c
	defb 0e0h,0b0h,0dch,003h	; 6f50
	defb 0e0h,0b0h,0e0h,001h	; 6f54
	defb 0e0h,0b0h,0e4h,003h	; 6f58

; ======================================================================
; CODIGO 0x6f5c..0x6f78  (28 bytes)
; ======================================================================


mueve_los_enemigos:		; Recorre los enemigos de la sala y despacha cada uno por su estado: los bits 2-7 del campo 1, desplazados dos, indexan tabla_6f78 (9 estados). Deja apilado 0x7075 como cierre
	xor a			;6f5c   ; indice de enemigo := 0
	ld (0e165h),a		;6f5d
despacha_un_enemigo:		; Cuerpo del bucle: prepara el enemigo, saca su estado del campo 1 y salta por tabla_6f78
	call prepara_enemigo_activo		;6f60   ; prepara el enemigo activo (IX y DE al registro)
	exx			;6f63   ; al juego de registros alterno
	ld h,d			;6f64
	ld l,e			;6f65
	ld b,(hl)			;6f66   ; B = el campo 0
	inc hl			;6f67
	ld a,(hl)			;6f68   ; A = el campo 1
	srl a		;6f69   ; dos desplazamientos: los bits 2-7 pasan a ser el estado
	srl a		;6f6b
	inc hl			;6f6d
	ld (hl),a			;6f6e   ; guardado en el campo 2
	ld a,b			;6f6f   ; A = el campo 0, que es lo que espera el despacho
	exx			;6f70
	ld hl,07075h		;6f71   ; apila 0x7075: el cierre de este enemigo
	push hl			;6f74
	call despacha_tabla_siguiente		;6f75   ; salta por tabla_6f78 (9 estados)

; ----------------------------------------------------------------------
; DATOS tabla_6f78: 9 entradas (no 10: los dos primeros bytes de la tarea 0,
;   "dd 7e" = ld a,(ix+11h), decodifican tambien como el word 0x7edd, que
;   parecia una 10a entrada valida hasta trazar 0x6f8a como codigo), llamada
;   L_404B desde 0x6f75
;   0x6f78..0x6f8a  (18 bytes)
DATA_tabla_6f78:
	defw 06f8ah,070e6h,07132h,0713ch,07172h,07190h,071b8h,071fch	; 6f78
	defw 07255h	; 6f88  -> enemigo_estado_8

; ======================================================================
; CODIGO 0x6f8a..0x7070  (230 bytes)
; ======================================================================


enemigo_estado_0:		; Estado 0: si el campo 0x11 esta a cero, el enemigo pasa a tipo 7 y recarga ese contador desde la tabla de 0x7070 con el campo 0x14 como indice
	ld a,(ix+011h)		;6f8a   ; (IX+0x11), el contador de este estado
	or a			;6f8d   ; con el contador vivo, sigue en 0x6fa2
	jr nz,enemigo_cuenta_atras		;6f8e
	ld (ix+000h),007h		;6f90   ; campo 0 := 7
	ld a,(ix+014h)		;6f94   ; (IX+0x14) indexa la tabla de recarga
	ld de,07070h		;6f97   ; DE = la tabla de 0x7070
	call suma_a_de		;6f9a
	ld a,(de)			;6f9d
	ld (ix+011h),a		;6f9e   ; y el contador queda recargado
	ret			;6fa1
enemigo_cuenta_atras:		; Cada 16 fotogramas baja en uno el contador de 0x11 del enemigo
	ld a,(0e003h)		;6fa2   ; A = contador de fotogramas
	and 00fh		;6fa5   ; mod 16: uno de cada dieciseis
	jr nz,enemigo_anda_o_cae		;6fa7
	dec (ix+011h)		;6fa9   ; el contador del enemigo baja uno
enemigo_anda_o_cae:		; El cuerpo del andar de un enemigo: descarta el retorno apilado, decide su rumbo con 0x7278, y luego -si no esta en el modo del bit 4- comprueba el suelo y aplica el movimiento; si no hay suelo, cae
	pop hl			;6fac   ; descarta el retorno: el cierre se reapila abajo
	call decide_rumbo_del_enemigo		;6fad   ; decide el rumbo del enemigo
	ld hl,07075h		;6fb0   ; reapila 0x7075, el cierre
	push hl			;6fb3
	ld a,(ix+001h)		;6fb4   ; A = el campo 1
	bit 4,a		;6fb7   ; bit 4: el modo especial de 0x70c1
	jp nz,enemigo_prueba_avanzar		;6fb9
	push ix		;6fbc
	pop hl			;6fbe
	inc hl			;6fbf   ; HL avanza al campo 1 del registro
	push hl			;6fc0
	inc hl			;6fc1
	inc hl			;6fc2
	call hay_suelo_bajo		;6fc3   ; comprueba el suelo bajo el enemigo
	pop hl			;6fc6
	jp c,enemigo_sin_suelo		;6fc7   ; sin suelo: a la caida de 0x7113
	push hl			;6fca
	ld a,001h		;6fcb   ; (0xE14D) := 1: bloquea que el paso diagonal toque el sentido guardado
	ld (0e14dh),a		;6fcd
	call mueve_registro		;6fd0   ; aplica el movimiento pedido
	pop hl			;6fd3
	jp z,enemigo_fija_rumbo		;6fd4   ; con Z se ha movido en diagonal: a 0x7054
	call mira_celda_del_registro		;6fd7   ; mira que hay en la celda hacia la que va
	push af			;6fda
	ld a,015h		;6fdb   ; el campo 0x15 del registro
	call campo_del_enemigo		;6fdd
	pop af			;6fe0
	ld a,(hl)			;6fe1   ; A = ese campo
	jr nc,enemigo_agota_contador		;6fe2   ; sin C, el camino de 0x6ffa
	and 0f0h		;6fe4   ; con C: el nibble alto mas 0x1F
	add a,01fh		;6fe6
	ld (hl),a			;6fe8
	cp 0afh		;6fe9   ; al llegar a 0xAF, el enemigo cambia de estado
	jr nz,enemigo_prueba_dar_la_vuelta		;6feb
enemigo_pasa_a_estado_8:		; Deja el enemigo en campo 0 = 8, campo 1 = 4 y el contador 0x11 en 0x22
	ld (ix+000h),008h		;6fed   ; campo 0 := 8
	ld (ix+001h),004h		;6ff1   ; campo 1 := 4
	ld (ix+011h),022h		;6ff5   ; y el contador := 0x22
	ret			;6ff9
enemigo_agota_contador:		; Camino sin C: con el campo en 0xF0 no toca nada, y si no, cada 32 fotogramas lo baja en uno
	cp 0f0h		;6ffa   ; el valor 0xF0 no se toca
	jr z,enemigo_avanza		;6ffc
	ld a,(0e003h)		;6ffe   ; A = contador de fotogramas
	and 01fh		;7001   ; mod 32: uno de cada treinta y dos
	jr nz,enemigo_avanza		;7003
	dec (hl)			;7005   ; el campo baja uno
	jr nz,enemigo_avanza		;7006
enemigo_avanza:		; Coge la velocidad de los campos 7 y 8 del enemigo y avanza su posicion de 24 bits, rematando con el paso de animacion de 0x704b
	ld e,(ix+007h)		;7008   ; E = el campo 7, byte bajo de la velocidad
	ld d,(ix+008h)		;700b   ; D = el campo 8, byte alto
	ld a,004h		;700e   ; el campo 4 del registro
	call campo_del_enemigo		;7010
	call avanza_posicion_24_bits		;7013   ; avanza la posicion de 24 bits
	call paso_de_animacion_del_enemigo		;7016   ; y el paso de animacion
	ret			;7019
enemigo_prueba_dar_la_vuelta:		; Con el campo anterior a cero, mira la celda con la direccion INVERTIDA: si la encuentra, el enemigo pasa a estado 7 con el contador a 0xFF
	dec hl			;701a
	ld a,(hl)			;701b   ; A = el campo anterior
	or a			;701c
	jr nz,enemigo_da_la_vuelta		;701d   ; distinto de cero: a 0x7035
	call campo_3_del_enemigo		;701f
	dec hl			;7022
	ld a,(hl)			;7023
	xor 003h		;7024   ; da la vuelta a los dos bits de direccion
	ld b,a			;7026
	call mira_celda_con_direccion		;7027   ; y mira la celda con esa direccion
	jr nc,enemigo_da_la_vuelta		;702a   ; no la encuentra: a 0x7035
	ld (ix+011h),0ffh		;702c   ; contador 0x11 := 0xFF
	ld (ix+000h),007h		;7030   ; campo 0 := 7
	ret			;7034
enemigo_da_la_vuelta:		; Si el enemigo no puede avanzar, invierte los bits 2-3 de su campo 1: se da la vuelta
	call campo_3_del_enemigo		;7035   ; la preparacion de 0x71f2
	cp 008h		;7038   ; por debajo de 8 no comprueba si cabe
	jr c,invierte_rumbo_del_enemigo		;703a
	call puede_avanzar		;703c   ; comprueba si puede avanzar
	jp c,rumbo_desde_ix		;703f   ; puede: sigue de largo
invierte_rumbo_del_enemigo:		; Da la vuelta a los bits 2-3 del campo 1 del enemigo
	ld a,(ix+001h)		;7042
	xor 00ch		;7045   ; los bits 2-3, invertidos
	ld (ix+001h),a		;7047   ; guardado
	ret			;704a
paso_de_animacion_del_enemigo:		; Cuenta uno en el campo 10 del enemigo y traduce el resultado en pose con la misma rutina que usa el jugador
	ld a,00ah		;704b   ; el campo 10 del registro
	call campo_del_enemigo		;704d
	inc (hl)			;7050   ; cuenta un paso
	jp L_4D31		;7051   ; y lo traduce en pose
enemigo_fija_rumbo:		; El enemigo se ha movido en diagonal: guarda en el campo 15 el bit de sentido y recompone el campo 1 con 8 o 4, invirtiendo los bits 2-3 si hace falta
	ld a,(ix+001h)		;7054   ; A = el campo 1
	rra			;7057   ; su bit 0, el sentido
	ld a,c			;7058
	ld b,008h		;7059   ; por defecto, 8
	jr nc,L_7061		;705b
	ld b,004h		;705d   ; con el otro sentido, 4, y el bit se invierte
	xor 001h		;705f
L_7061:
	and 001h		;7061
	ld (ix+00fh),a		;7063   ; el campo 15 := el bit de sentido
	and a			;7066
	ld a,b			;7067
	jr z,L_706C		;7068
	xor 00ch		;706a   ; con el bit puesto, los bits 2-3 se invierten
L_706C:
	ld (ix+001h),a		;706c   ; y el campo 1 queda recompuesto
	ret			;706f

; ----------------------------------------------------------------------
; DATOS recarga_del_contador: Los cinco valores (03 03 00 00 03) con que
;   enemigo_estado_0 (0x6f97) recarga el contador de 0x11 del enemigo,
;   indexados por su variante (campo 0x14)
;   0x7070..0x7075  (5 bytes)
DATA_recarga_del_contador:
	defb 003h	; 7070
	defb 003h	; 7071
	defb 000h	; 7072
	defb 000h	; 7073
	defb 003h	; 7074

; ======================================================================
; CODIGO 0x7075..0x70b6  (65 bytes)
; ======================================================================


dibuja_sprite_del_enemigo:		; Cierre del bucle de despacha_un_enemigo, alcanzado por el `ret` del estado despachado gracias al `push hl` de 0x6f74: monta la entrada de sprite del enemigo -posicion de los campos 3 y 5, patron sacado de patrones_del_enemigo con el campo 11- y cae en siguiente_enemigo_a_mover. Si el enemigo esta en otra pantalla, lo aparca en 0xE0
	ld c,(ix+003h)		;7075   ; C = el campo 3, la Y del enemigo
	ld b,(ix+005h)		;7078   ; B = el campo 5, su X
	call ranura_de_sprite_del_enemigo		;707b   ; HL = su ranura del buffer de sprites
	ld a,(0e13ah)		;707e   ; A = el byte alto de la X del jugador
	cp (ix+006h)		;7081   ; contra el campo 6 del enemigo: misma pantalla
	jr nz,aparca_enemigo_de_otra_pantalla		;7084   ; en otra pantalla: se aparca fuera
	dec c			;7086   ; la Y del sprite sube dos lineas
	dec c			;7087
	ld a,(ix+00bh)		;7088   ; A = el campo 11, la pose del enemigo
	push af			;708b
	rra			;708c   ; su bit 0 devuelve una de esas dos lineas: el bote del paso
	jr c,patron_del_sprite_del_enemigo		;708d
	inc c			;708f
patron_del_sprite_del_enemigo:		; Traduce la pose del enemigo en numero de patron con patrones_del_enemigo y escribe la entrada Y/X/patron, sumandole 0x60 si mira al otro lado -el mismo reflejo horizontal que usa el jugador-
	pop af			;7090   ; recupera la pose
	ld de,070b6h		;7091   ; DE = patrones_del_enemigo
	call suma_a_de		;7094   ; DE += la pose
	ld a,(de)			;7097   ; A = el numero de patron de esa pose
	ld d,a			;7098   ; D lo guarda
	ld (hl),c			;7099   ; Y del sprite
	inc hl			;709a
	ld (hl),b			;709b   ; X del sprite
	inc hl			;709c
	ld a,(ix+002h)		;709d   ; A = el campo 2, el rumbo del enemigo
	rra			;70a0   ; su bit 0: a que lado mira
	ld a,d			;70a1
	jr nc,L_70A6		;70a2
	add a,060h		;70a4   ; mirando al otro lado, el patron esta 0x60 = 96 mas alla
L_70A6:
	ld (hl),a			;70a6   ; numero de patron
	jr siguiente_enemigo_a_mover		;70a7   ; y al enemigo siguiente
aparca_enemigo_de_otra_pantalla:		; El enemigo esta en otra pantalla: su sprite se aparca en Y=0xE0, fuera de la pantalla
	ld (hl),0e0h		;70a9   ; 0xE0 = -32: fuera de la pantalla
siguiente_enemigo_a_mover:		; Final del bucle de mueve_los_enemigos: sube el indice y repite mientras no llegue al tope de 0xE164
	ld hl,0e165h		;70ab   ; HL = 0xE165, el indice de enemigo
	inc (hl)			;70ae   ; sube uno
	ld a,(hl)			;70af
	dec hl			;70b0
	cp (hl)			;70b1   ; contra el tope de 0xE164
	ret nc			;70b2
	jp despacha_un_enemigo		;70b3   ; mientras queden, otro enemigo

; ----------------------------------------------------------------------
; DATOS patrones_del_enemigo: Los once numeros de patron del enemigo (2C 28 30
;   2C 28 30 28 30 E8 EC D4) que el cierre de 0x7075 indexa para dibujar su
;   sprite
;   0x70b6..0x70c1  (11 bytes)
DATA_patrones_del_enemigo:
	defb 02ch	; 70b6
	defb 028h	; 70b7
	defb 030h	; 70b8
	defb 02ch	; 70b9
	defb 028h	; 70ba
	defb 030h	; 70bb
	defb 028h	; 70bc
	defb 030h	; 70bd
	defb 0e8h	; 70be
	defb 0ech	; 70bf
	defb 0d4h	; 70c0

; ======================================================================
; CODIGO 0x70c1..0x7167  (166 bytes)
; ======================================================================


enemigo_prueba_avanzar:		; Si el campo 3 del enemigo llega a 8 y puede_avanzar lo aprueba, le pone el rumbo nuevo
	call campo_3_del_enemigo		;70c1   ; el campo 3 del enemigo
	ld a,(hl)			;70c4
	cp 008h		;70c5   ; por debajo de 8 no se comprueba
	ret c			;70c7
	call puede_avanzar		;70c8   ; mira si cabe por delante
	ret nc			;70cb   ; no cabe: se queda como esta
rumbo_desde_ix:		; Deja HL apuntando al registro del enemigo y cae en fija_rumbo_nuevo
	push ix		;70cc   ; HL = el registro del enemigo
	pop hl			;70ce
fija_rumbo_nuevo:		; Deja el registro en estado 1, le quita el bit 4 del campo 1, pone el campo 10 en 2 y le carga el guion de movimiento de 0x754b
	ld (hl),001h		;70cf   ; campo 0 := 1
	inc hl			;70d1
	res 4,(hl)		;70d2   ; quita el bit 4 del campo 1
	ld a,00ah		;70d4
	call suma_a_hl		;70d6   ; HL += 10
	ld (hl),002h		;70d9   ; ese campo := 2
	inc hl			;70db
	ld de,0754bh		;70dc   ; DE = el guion de movimiento de 0x754b
	ld (hl),e			;70df   ; byte bajo del puntero al guion
	inc hl			;70e0
	ld (hl),d			;70e1   ; y byte alto
	inc hl			;70e2
	ld (hl),000h		;70e3   ; el campo siguiente, a cero
	ret			;70e5
enemigo_sigue_el_guion:		; Estado 1: avanza el guion de movimiento del enemigo, ajusta su campo con 0x70ff y, si decide_si_el_registro_sigue dice que no puede, lo manda a la caida de 0x7132
	call campo_3_del_enemigo		;70e6   ; el campo 3 del registro
	dec hl			;70e9
	push hl			;70ea
	push ix		;70eb
	call avanza_guion_de_movimiento		;70ed   ; avanza un paso del guion de movimiento
	pop ix		;70f0
	pop hl			;70f2
	call ajusta_campo_de_paso		;70f3   ; el ajuste de 0x70ff
	push ix		;70f6
	pop hl			;70f8
	call decide_si_el_registro_sigue		;70f9   ; mira si el enemigo puede seguir
	jr z,enemigo_cae		;70fc   ; no puede: a la caida
	ret			;70fe
ajusta_campo_de_paso:		; Compara el campo tres bytes mas alla con 0 o 0xFF segun el bit 0 del primero; si coinciden, sube el campo siguiente y, si no queda a cero, lo baja dos
	ld a,(hl)			;70ff   ; A = el primer campo
	inc hl			;7100
	inc hl			;7101
	inc hl			;7102
	ld b,000h		;7103   ; B := 0 por defecto
	rra			;7105   ; bit 0 del campo: decide el valor esperado
	jr nc,compara_y_ajusta		;7106
	dec b			;7108   ; con el bit puesto, B := 0xFF
compara_y_ajusta:		; Compara B con el campo y, si coinciden, sube el siguiente y lo baja dos si no ha quedado a cero
	ld a,b			;7109   ; A = el valor esperado
	cp (hl)			;710a   ; contra el campo
	inc hl			;710b
	ret nz			;710c   ; no coinciden: nada que ajustar
	inc (hl)			;710d   ; el campo siguiente sube uno
	and a			;710e
	ret z			;710f   ; si queda a cero, se deja
	dec (hl)			;7110   ; si no, baja dos: queda en -1
	dec (hl)			;7111
	ret			;7112
enemigo_sin_suelo:		; El enemigo se ha quedado sin suelo: salvo que su campo 0x14 valga 0 o 3, o su campo 0x10 valga 1, comprueba si puede avanzar y, si puede, le fija el rumbo nuevo; si no, cae
	ld a,(ix+014h)		;7113   ; (IX+0x14), la variante del enemigo
	and a			;7116
	jr z,enemigo_cae		;7117   ; la variante 0 cae directamente
	cp 003h		;7119
	jr z,enemigo_cae		;711b   ; y la 3 tambien
	ld a,(ix+010h)		;711d   ; (IX+0x10), la distancia al jugador
	cp 001h		;7120
	jr z,enemigo_cae		;7122   ; con 1, cae directamente
	call campo_3_del_enemigo		;7124
	ld a,(hl)			;7127   ; el campo 3 del registro
	cp 008h		;7128   ; por debajo de 8 no se comprueba
	jr c,enemigo_cae		;712a
	call puede_avanzar		;712c   ; mira si cabe por delante
	jp c,rumbo_desde_ix		;712f   ; cabe: rumbo nuevo en vez de caida
enemigo_cae:		; El enemigo cae: le da un paso con 0x7558
	push ix		;7132   ; HL = el registro del enemigo
	pop hl			;7134
	call da_un_paso_de_caida		;7135   ; el paso de la caida
	jp nc,L_7164		;7138
	ret			;713b
enemigo_estado_3:		; Estado 3: solo con los bits 2-3 del campo 1 puestos; coge de la tabla de 0x716d la mascara de fotogramas que le toca a su variante y avanza un paso alineado
	push ix		;713c
	pop hl			;713e
	inc hl			;713f   ; HL avanza al campo 1
	ld a,(hl)			;7140
	and 00ch		;7141   ; bits 2-3: sin ellos no se mueve
	ret z			;7143
	ld a,(ix+014h)		;7144   ; (IX+0x14), la variante del enemigo
	ld de,0716dh		;7147   ; DE = la tabla de mascaras de 0x716d
	call suma_a_de		;714a
	ld a,(de)			;714d   ; B = la mascara de esta variante
	ld b,a			;714e
	ld a,001h		;714f
	ld (0e05fh),a		;7151   ; (0xE05F) := 1, dos veces seguidas
	ld (0e05fh),a		;7154
	call avanza_registro_alineado		;7157   ; el paso alineado
	jr z,L_7160		;715a
	call paso_de_animacion_del_enemigo		;715c   ; se ha movido: solo la animacion
	ret			;715f
L_7160:
	ld (ix+011h),000h		;7160
L_7164:
	xor a			;7164
	jr $+4		;7165

; ----------------------------------------------------------------------
; DATOS resto_7167: Dos bytes (3E 03, "ld a,03h") que un jr incondicional
;   salta siempre; sin entrada conocida
;   0x7167..0x7169  (2 bytes)
DATA_resto_7167:
	defb 03eh,003h	; 7167

; ======================================================================
; CODIGO 0x7169..0x716d  (4 bytes)
; ======================================================================


L_7169:
	ld (ix+000h),a		;7169
	ret			;716c

; ----------------------------------------------------------------------
; DATOS mascaras_de_fotograma: Las cinco mascaras de fotograma del estado 3,
;   una por variante de enemigo: enemigo_estado_3 (0x7147) las indexa con el
;   campo 0x14 y avanza_registro_alineado las usa con `and (0xe003)` para
;   mover cada variante a un ritmo distinto
;   0x716d..0x7172  (5 bytes)
DATA_mascaras_de_fotograma:
	defb 003h	; 716d
	defb 000h	; 716e
	defb 001h	; 716f
	defb 000h	; 7170
	defb 003h	; 7171

; ======================================================================
; CODIGO 0x7172..0x754a  (984 bytes)
; ======================================================================


enemigo_estado_4:		; Estado 4: cada dos fotogramas baja el contador de 0x11 y, al agotarse, sube el estado, recarga el contador a 0x82 y suena el efecto 0x87
	pop hl			;7172   ; descarta el retorno apilado: se cierra a mano
	ld a,(0e003h)		;7173   ; A = contador de fotogramas
	and 001h		;7176   ; mod 2: uno de cada dos
	jp nz,siguiente_enemigo_a_mover		;7178
	dec (ix+011h)		;717b   ; el contador del enemigo baja uno
	jp nz,siguiente_enemigo_a_mover		;717e
	inc (ix+000h)		;7181   ; agotado: el estado sube uno
	ld (ix+011h),082h		;7184   ; y el contador se recarga a 0x82
	ld a,087h		;7188   ; efecto de sonido 0x87
	call reproduce_efecto		;718a
	jp siguiente_enemigo_a_mover		;718d
enemigo_estado_5:		; Estado 5: deja el campo 1 en 8 y cuenta atras el contador de 0x11; mientras vale 7 o mas alterna cada 32 fotogramas la pose entre 8 y 9, y al agotarse remata por 0x7164
	ld (ix+001h),008h		;7190   ; campo 1 := 8
	dec (ix+011h)		;7194   ; el contador baja uno
	jp z,L_71B0		;7197   ; agotado: al remate
	ld a,(ix+011h)		;719a
	cp 007h		;719d   ; por debajo de 7, otro camino
	jr c,L_71B3		;719f
	ld b,a			;71a1
	and 01fh		;71a2   ; mod 32: uno de cada treinta y dos
	ret nz			;71a4
	bit 5,b		;71a5   ; bit 5 del contador: alterna la pose
	ld a,008h		;71a7   ; pose 8...
	jr z,L_71AC		;71a9
	inc a			;71ab   ; ...o 9
L_71AC:
	ld (ix+00bh),a		;71ac   ; guardada en el campo 11
	ret			;71af
L_71B0:
	call L_7164		;71b0
L_71B3:
	ld (ix+00bh),002h		;71b3
	ret			;71b7
enemigo_estado_6:		; Estado 6: campo 1 en 8, cuenta atras el contador de 0x11 con la pose 10 cada 32 fotogramas, y al agotarse aparca el enemigo y pasa al siguiente
	ld (ix+001h),008h		;71b8   ; campo 1 := 8
	dec (ix+011h)		;71bc   ; el contador baja uno
	ld a,(ix+011h)		;71bf
	ld b,a			;71c2
	jr z,L_71CE		;71c3   ; agotado: aparca el enemigo
	and 01fh		;71c5   ; mod 32: uno de cada treinta y dos
	ret nz			;71c7
	ld a,00ah		;71c8   ; pose 10
	ld (ix+00bh),a		;71ca   ; guardada en el campo 11
	ret			;71cd
L_71CE:
	call aparca_al_enemigo		;71ce   ; aparca el enemigo
	pop hl			;71d1   ; y descarta el retorno para pasar al siguiente
	jp siguiente_enemigo_a_mover		;71d2
aparca_al_enemigo:		; Aparca el sprite del enemigo fuera de pantalla (Y = 0xE0), lo deja en estado 4 con el contador en 0x80 y la pose 9
	call ranura_de_sprite_del_enemigo		;71d5   ; la ranura de sprite de este enemigo
	ld (hl),0e0h		;71d8   ; Y := 0xE0: fuera de pantalla
	ld (ix+000h),004h		;71da   ; campo 0 := 4
	ld (ix+011h),080h		;71de   ; contador := 0x80
	ld (ix+00bh),009h		;71e2   ; pose := 9
	ret			;71e6
ranura_de_sprite_del_enemigo:		; Devuelve en HL la entrada del buffer de sprites que le toca al enemigo activo: 0xE0C8 + 4*indice
	ld a,(0e165h)		;71e7   ; A = el indice del enemigo activo
	ld hl,0e0c8h		;71ea   ; HL = 0xE0C8, la base de las ranuras de enemigo
ranura_de_sprite:		; Suma a HL cuatro veces A: la entrada numero A del buffer de sprites que empiece donde diga el llamador
	add a,a			;71ed   ; A = 2*indice
	add a,a			;71ee   ; A = 4*indice: cuatro bytes por entrada
	jp suma_a_hl		;71ef   ; HL += eso, y vuelve al llamador
campo_3_del_enemigo:		; Devuelve en HL el campo 3 del enemigo activo, el que se usa para las comprobaciones de avance
	ld a,003h		;71f2   ; A := 3, el campo del avance
campo_del_enemigo:		; Devuelve en HL el campo A del enemigo activo, partiendo del puntero que prepara_enemigo dejo en 0xE162
	ld hl,(0e162h)		;71f4   ; HL = (0xE162), el registro del enemigo activo
	call suma_a_hl		;71f7   ; HL += el numero de campo
	ld a,(hl)			;71fa
	ret			;71fb
enemigo_estado_7:		; Estado 7: con el contador de 0x11 vivo deja la pose 2 y el campo 2 con los dos bits bajos del contador, y cada 32 fotogramas lo baja; con el contador a cero, o a 0xE0, cambia de rumbo
	ld a,(ix+011h)		;71fc   ; (IX+0x11), el contador
	or a			;71ff   ; a cero: al camino de 0x7219
	jr z,enemigo_vuelve_al_estado_0		;7200
	cp 0e0h		;7202   ; el valor 0xE0 tiene su propio camino
	jr z,enemigo_da_media_vuelta		;7204
	ld (ix+00bh),002h		;7206   ; pose := 2
	and 003h		;720a   ; los dos bits bajos del contador
	ld (ix+002h),a		;720c   ; guardados en el campo 2
	ld a,(0e003h)		;720f   ; A = contador de fotogramas
	and 01fh		;7212   ; mod 32: uno de cada treinta y dos
	ret nz			;7214
	dec (ix+011h)		;7215   ; el contador baja uno
	ret nz			;7218
enemigo_vuelve_al_estado_0:		; Rehace el rumbo del enemigo y lo devuelve al estado 0
	call rehace_rumbo_del_enemigo		;7219   ; rehace el rumbo
	ld (ix+000h),000h		;721c   ; campo 0 := 0
	ret			;7220
enemigo_da_media_vuelta:		; El contador vale 0xE0: invierte los bits 2-3 del campo 1, guarda el rumbo en el campo 2 y mira dos celdas (a 0xFC y a 0x10FC) para decidir si sigue o cambia de estado
	ld a,(ix+001h)		;7221
	xor 00ch		;7224   ; los bits 2-3, invertidos
	ld (ix+001h),a		;7226
	rra			;7229   ; dos rra y &3: el rumbo baja a los bits 0-1
	rra			;722a
	and 003h		;722b
	ld (ix+002h),a		;722d   ; guardado en el campo 2
	call campo_3_del_enemigo		;7230
	ld bc,000fch		;7233   ; BC = 0x00FC: cuatro pixeles por encima
	call lee_celda_de_sala		;7236   ; lee esa celda
	ld b,a			;7239
	and 0f0h		;723a
	cp 010h		;723c   ; el tipo 0x1x: sigue por 0x70c1
	jp nz,enemigo_prueba_avanzar		;723e
	call campo_3_del_enemigo		;7241
	ld bc,010fch		;7244   ; BC = 0x10FC: dieciseis pixeles a un lado
	call lee_celda_de_sala		;7247   ; y lee tambien esa
	ld b,a			;724a
	and 0f0h		;724b
	cp 010h		;724d
	jp nz,enemigo_prueba_avanzar		;724f
	jp enemigo_pasa_a_estado_8		;7252
enemigo_estado_8:		; Estado 8: campo 1 en 8, cuenta atras el contador con la pose 10 cada 32 fotogramas, y al agotarse aparca el enemigo, lo recarga a 0xFF, lo vuelve a preparar de cero y pasa al siguiente
	ld (ix+001h),008h		;7255   ; campo 1 := 8
	dec (ix+011h)		;7259   ; el contador baja uno
	ld a,(ix+011h)		;725c
	ld b,a			;725f
	jr z,L_726A		;7260   ; agotado: al remate
	and 01fh		;7262   ; mod 32: uno de cada treinta y dos
	ret nz			;7264
	ld (ix+00bh),00ah		;7265   ; pose 10
	ret			;7269
L_726A:
	call aparca_al_enemigo		;726a   ; aparca el enemigo
	ld (ix+011h),0ffh		;726d   ; contador := 0xFF
	call prepara_un_enemigo		;7271   ; y lo vuelve a preparar de cero
	pop hl			;7274   ; descarta el retorno y pasa al siguiente
	jp siguiente_enemigo_a_mover		;7275
decide_rumbo_del_enemigo:		; Decide hacia donde va el enemigo comparando su posicion con la del jugador: si estan en la misma pantalla mira la X, y si no, mira si la diferencia de pantallas y la franja de 0x50-0xB0 lo justifican; el resultado (4 u 8) va al campo 1
	exx			;7278   ; al juego de registros alterno
	ld hl,00006h		;7279   ; HL = DE + 6: el campo 6 del enemigo, su byte alto de X
	add hl,de			;727c
	ld a,(0e13ah)		;727d   ; A = el byte alto de la X del jugador
	ld b,(hl)			;7280   ; B = el del enemigo
	cp (hl)			;7281   ; misma pantalla: no hay nada que decidir aqui
	jr z,sin_cambio_de_rumbo		;7282
	dec hl			;7284   ; HL-1: la X baja del enemigo
	ld a,(hl)			;7285
	ld c,050h		;7286   ; C := 0x50, el borde de la franja
	cp c			;7288   ; por debajo de 0x50: a 0x7292
	jr c,compara_pantallas		;7289
	ld c,0b0h		;728b   ; C := 0xB0, el otro borde
	cp c			;728d
	jr c,sin_cambio_de_rumbo		;728e   ; dentro de la franja: no se decide nada
	inc b			;7290   ; B += 2: dos pantallas mas alla
	inc b			;7291
compara_pantallas:		; Ajusta la cuenta de pantallas y compara con la del jugador; si no cuadra, no se cambia el rumbo
	dec b			;7292   ; B -= 1
	ld a,(0e13ah)		;7293   ; A = la pantalla del jugador
	cp b			;7296   ; no cuadra: no se cambia el rumbo
	jr nz,sin_cambio_de_rumbo		;7297
	xor a			;7299   ; C = -C: el borde, cambiado de signo
	sub c			;729a
	ld c,a			;729b
	cp 050h		;729c   ; el borde 0x50 tiene su propio camino
	ld a,(0e139h)		;729e   ; A = la X baja del jugador
	jr z,compara_con_el_otro_borde		;72a1
	cp c			;72a3   ; por debajo del borde: no se cambia el rumbo
	jr c,sin_cambio_de_rumbo		;72a4
fija_rumbo_por_pantalla:		; Compara la pantalla del jugador con el campo siguiente del enemigo y deja el rumbo en 8 o en 4
	inc hl			;72a6
	ld a,(0e13ah)		;72a7   ; A = la pantalla del jugador
	cp (hl)			;72aa   ; contra el campo siguiente del enemigo
	ld a,008h		;72ab   ; rumbo 8 por defecto
	jr c,guarda_rumbo		;72ad
	ld a,004h		;72af   ; o rumbo 4 si el jugador queda al otro lado
guarda_rumbo:		; Guarda el rumbo en el campo 1 del enemigo y vuelve al juego de registros normal
	ld h,d			;72b1   ; HL = DE, el registro del enemigo
	ld l,e			;72b2
	inc hl			;72b3   ; HL avanza al campo 1
	ld (hl),a			;72b4   ; el rumbo, guardado
	exx			;72b5   ; de vuelta al juego de registros normal
	ret			;72b6
compara_con_el_otro_borde:		; Con el borde 0x50: solo cambia el rumbo si la X del jugador queda por debajo
	cp c			;72b7   ; contra el borde
	jr c,fija_rumbo_por_pantalla		;72b8
sin_cambio_de_rumbo:		; Vuelve al juego de registros normal sin tocar el rumbo
	exx			;72ba   ; de vuelta al juego de registros normal
	ret			;72bb
rehace_rumbo_del_enemigo:		; Recalcula el rumbo del enemigo: contador 0x11 a 5, rastrea el camino, clasifica la distancia al jugador y reparte segun salga 0, 1 o 2
	ld a,005h		;72bc   ; contador := 5
	ld (ix+011h),a		;72be
	call busca_camino		;72c1   ; rastrea los caminos posibles
	call clasifica_distancia_al_jugador		;72c4   ; y clasifica la distancia al jugador
	and a			;72c7
	jr z,rumbo_hacia_el_jugador		;72c8   ; distancia 0: el camino de 0x72d0
	dec a			;72ca
	jr z,L_7316		;72cb   ; distancia 1: el de 0x7316
	dec a			;72cd
	jr z,lee_camino_encontrado		;72ce   ; distancia 2: lee el camino encontrado
rumbo_hacia_el_jugador:		; Compara pantalla y X con las del jugador y deja el rumbo en 8
	ld a,(0e13ah)		;72d0   ; A = la pantalla del jugador
	cp (ix+006h)		;72d3   ; contra la del enemigo
	jr nz,L_72DE		;72d6
	ld a,(0e139h)		;72d8   ; A = la X del jugador
	cp (ix+005h)		;72db   ; contra la del enemigo
L_72DE:
	ld a,008h		;72de   ; rumbo 8
	jr nc,recorre_hasta_el_jugador		;72e0
	ld a,004h		;72e2
recorre_hasta_el_jugador:		; Guarda el rumbo en el campo 1 y recorre hasta 32 celdas del buffer de sala desde el enemigo hacia el jugador, parando al llegar a su celda o al topar con una del tipo 0x1x
	ld (ix+001h),a		;72e4   ; el rumbo, guardado en el campo 1
	ld c,a			;72e7   ; C lo conserva: decide el sentido del recorrido
	ld hl,0e137h		;72e8   ; HL = 0xe137, la posicion del jugador
	call lee_celda_propia		;72eb   ; su celda de sala
	ex de,hl			;72ee
	call campo_3_del_enemigo		;72ef   ; el campo 3 del enemigo
	call lee_celda_propia		;72f2   ; y su celda de sala
	ld b,020h		;72f5   ; B = 32 celdas como mucho
una_celda_del_recorrido:		; Una celda del recorrido: para si es la del jugador o si es del tipo 0x1x, y si no avanza segun el bit 2 del rumbo
	and a			;72f7
	push hl			;72f8
	sbc hl,de		;72f9   ; la resta: cero si ya es la celda del jugador
	pop hl			;72fb
	ret z			;72fc   ; llegado: se acabo
	ld a,(hl)			;72fd   ; A = la celda
	and 0f0h		;72fe
	cp 010h		;7300   ; tipo 0x1x: pared, se acabo
	jr z,L_730E		;7302
	dec hl			;7304
	bit 2,c		;7305   ; bit 2 del rumbo: hacia que lado avanza
	jr nz,L_730B		;7307
	inc hl			;7309
	inc hl			;730a
L_730B:
	djnz una_celda_del_recorrido		;730b   ; hasta 32 celdas
	ret			;730d
L_730E:
	ld a,i		;730e
	rra			;7310
	or c			;7311
	rra			;7312
	call c,lee_camino_encontrado		;7313
L_7316:
	ld hl,0e168h		;7316
	ld a,(hl)			;7319
	and a			;731a
guarda_en_campo_1:		; Guarda A en (IX+1) salvo que valga cero
	ret z			;731b
	ld (ix+001h),a		;731c   ; (IX+1) := A
	ret			;731f
lee_camino_encontrado:		; Deja en (IX+1) el resultado del rastreo de 0xE166
	ld hl,0e166h		;7320   ; HL = 0xE166, el byte de resultado del rastreo
	ld a,(hl)			;7323   ; A = ese byte
	and a			;7324
	jr guarda_en_campo_1		;7325
clasifica_distancia_al_jugador:		; Deja en (IX+0x10) un numero de 0 a 2 segun lo lejos que este el enemigo del jugador en la coordenada que prepara 0x71f2: 0 si esta dentro de una ventana de 0x12 pixeles, 1 o 2 segun de que lado quede
	ld b,000h		;7327   ; B := 0, el valor por defecto
	ld de,0e137h		;7329   ; DE = 0xE137, la posicion del jugador
	call campo_3_del_enemigo		;732c   ; la preparacion de 0x71f2, que deja HL en la del enemigo
	ld a,(0e134h)		;732f   ; A = el estado del jugador
	cp 003h		;7332   ; en el estado 3 se salta la ventana
	jr z,decide_lado		;7334
	ld a,(de)			;7336   ; A = la coordenada del jugador
	sub (hl)			;7337   ; menos la del enemigo: la distancia
	ld c,a			;7338
	sub 00ah		;7339   ; la ventana: entre -0x0A y +0x08
	add a,012h		;733b
	jr c,L_7345		;733d   ; dentro de la ventana: se queda en 0
decide_lado:		; Fuera de la ventana: 1 si el jugador queda a un lado, 2 si queda al otro
	inc b			;733f   ; B := 1
	ld a,(de)			;7340   ; la resta otra vez, ahora solo por el signo
	sub (hl)			;7341
	jr nc,L_7345		;7342
	inc b			;7344   ; sin acarreo se queda en 1; con acarreo, B := 2
L_7345:
	ld a,b			;7345
	ld (ix+010h),a		;7346   ; (IX+0x10) := el resultado
	ret			;7349
busca_camino:		; Pone a cero los cuatro bytes de 0xE166 y lanza dos pasadas del rastreo de celdas: una con la direccion tal cual y otra con los bits 2-3 invertidos, para mirar hacia los dos lados
	ld b,004h		;734a   ; B = 4 bytes a borrar
	ld hl,0e166h		;734c   ; HL = 0xE166, el bloque de resultado del rastreo
borra_resultado:		; Pone a cero los cuatro bytes del bloque de resultado
	ld (hl),000h		;734f   ; un byte a cero
	inc hl			;7351   ; la direccion siguiente
	djnz borra_resultado		;7352   ; hasta los cuatro bytes
	push ix		;7354   ; HL = el registro del enemigo
	pop hl			;7356
	inc hl			;7357   ; HL avanza al campo 1
	ex af,af'			;7358   ; al juego alterno de A: el byte de direccion se conserva entre las dos pasadas
	ld a,(hl)			;7359   ; A' = el byte de direccion
	ex af,af'			;735a
	inc hl			;735b   ; HL avanza a la posicion
	inc hl			;735c
	push hl			;735d
	call rastrea_un_lado		;735e   ; la primera pasada, con la direccion tal cual
	pop hl			;7361
	ex af,af'			;7362
	xor 00ch		;7363   ; invierte los bits 2-3 de la direccion: la segunda pasada mira al otro lado
	ex af,af'			;7365
rastrea_un_lado:		; Una pasada del rastreo: lee la celda ocho pixeles a un lado y baja por la columna clasificando lo que encuentra
	call campo_3_del_enemigo		;7366   ; la preparacion de 0x71f2
	ld bc,00008h		;7369   ; BC = 0x0808: ocho pixeles a un lado y ocho de altura
	ld b,c			;736c
	call lee_celda_de_sala		;736d   ; lee esa celda
	ex af,af'			;7370
	dec hl			;7371
	bit 2,a		;7372   ; bit 2 del byte de direccion guardado: elige columna
	jr nz,L_7378		;7374
	inc hl			;7376
	inc hl			;7377
L_7378:
	ex af,af'			;7378
	ld b,000h		;7379   ; B := 0, el contador de filas rastreadas
baja_una_fila:		; Cada vuelta del rastreo: ajusta la columna segun el bit 2 y clasifica la celda -0x1x corta el rastreo, 0x2x y 0x3x (menos el 0x30 exacto) anotan un camino del tipo 1
	ex af,af'			;737b
	dec hl			;737c
	bit 2,a		;737d   ; bit 2 del byte de direccion: la columna de esta pasada
	jr nz,L_7383		;737f
	inc hl			;7381
	inc hl			;7382
L_7383:
	ex af,af'			;7383
	ld a,(hl)			;7384   ; A = la celda
	and 0f0h		;7385
	cp 010h		;7387   ; tipo 0x1x: pared, se acaba el rastreo
	ret z			;7389
	cp 020h		;738a   ; tipo 0x2x: camino
	jr z,anota_camino_tipo_1		;738c
	cp 030h		;738e   ; tipo 0x3x: tambien, salvo el 0x30 exacto
	jr nz,mira_fila_de_abajo		;7390
	ld a,(hl)			;7392
	cp 030h		;7393
	jr z,mira_fila_de_abajo		;7395
anota_camino_tipo_1:		; Anota en 0xE167 un camino del tipo 1 a la distancia B
	ld c,001h		;7397   ; C := 1, el tipo de camino
	ld de,0e167h		;7399   ; DE = 0xE167, donde se anota
	call anota_camino		;739c
mira_fila_de_abajo:		; Mira la celda de la fila siguiente (HL += 0x60 = 96): si tiene nibble alto y su nibble bajo llega a 5, anota un camino del tipo 2, y repite hasta cinco filas
	push hl			;739f
	ld a,060h		;73a0   ; HL += 0x60 = 96: la fila de abajo
	call suma_a_hl		;73a2
	ld a,(hl)			;73a5   ; A = esa celda; C se la queda
	ld c,a			;73a6
	pop hl			;73a7
	and 0f0h		;73a8
	jr z,anota_camino_tipo_2		;73aa   ; nibble alto a cero: camino del tipo 2 directo
	ld a,c			;73ac
	and 00fh		;73ad   ; nibble bajo, comparado con 5
	cp 005h		;73af
	call nc,anota_camino_tipo_2		;73b1   ; de 5 en adelante, tambien camino del tipo 2
	inc b			;73b4   ; una fila mas rastreada
	ld a,005h		;73b5   ; hasta cinco filas
	cp b			;73b7
	jr nz,baja_una_fila		;73b8
	ret			;73ba
anota_camino_tipo_2:		; Anota en 0xE169 un camino del tipo 2
	ld c,002h		;73bb   ; C := 2, el tipo de camino
	ld de,0e169h		;73bd   ; DE = 0xE169, donde se anota
anota_camino:		; Guarda la distancia B en (DE) solo si es MENOR que la anotada antes, y mete el tipo C en los dos bits bajos del byte anterior: se queda con el camino mas corto de los encontrados
	ld a,(de)			;73c0   ; A = la distancia anotada antes
	cp b			;73c1   ; si la de ahora no es menor, no se cambia nada
	ret nc			;73c2
	ld a,b			;73c3
	ld (de),a			;73c4   ; la distancia nueva, que es mejor
	dec de			;73c5   ; DE-1: el byte del tipo
	ex af,af'			;73c6
	push af			;73c7
	and 0fch		;73c8   ; conserva los seis bits altos y mete el tipo en los dos bajos
	or c			;73ca
	ld (de),a			;73cb
	pop af			;73cc
	ex af,af'			;73cd
	ret			;73ce
prepara_enemigo_activo:		; Prepara el enemigo cuyo indice esta en 0xE165
	ld hl,0e165h		;73cf   ; HL = 0xE165, el indice del enemigo activo
	ld a,(hl)			;73d2   ; A = ese indice
prepara_enemigo:		; Deja preparado el enemigo numero A: calcula 0xE16A + 22*A, guarda el puntero en 0xE162 y lo deja tambien en IX y en DE. El paso 22 sale de la cadena 2a-6a-22a con B llevando las potencias de dos
	ld b,a			;73d3   ; B = a
	sla b		;73d4   ; B = 2a
	ld a,b			;73d6   ; A = 2a
	sla b		;73d7   ; B = 4a
	add a,b			;73d9   ; A = 6a
	sla b		;73da   ; B = 8a
	sla b		;73dc   ; B = 16a
	add a,b			;73de   ; A = 22a: el paso de esta lista
	exx			;73df   ; al juego de registros alterno: HL y DE de aqui son de trabajo
	ld hl,0e16ah		;73e0   ; HL = 0xE16A, la base de la lista de enemigos
	call suma_a_hl		;73e3   ; HL += 22*A
	push hl			;73e6
	ld (0e162h),hl		;73e7   ; el puntero queda en 0xE162, donde lo esperan los llamadores
	pop ix		;73ea   ; y tambien en IX, que es como lo indexan las rutinas de 0x74xx
	ex de,hl			;73ec   ; y en DE
	exx			;73ed
	ret			;73ee
avanza_al_jugador:		; Avanza la posicion del jugador con su propia velocidad: HL = 0xE138 (el par fraccion+pixel bajo de la X) y DE = (0xE13B), la velocidad
	ld hl,0e138h		;73ef   ; HL = 0xE138, el byte de menos peso de la X de 24 bits
	ld de,(0e13bh)		;73f2   ; DE = (0xE13B), la velocidad de 16 bits
avanza_posicion_24_bits:		; Suma la velocidad DE a la posicion de 24 bits que empieza en (HL): los dos bytes bajos con add hl,de y el tercero -que es (IX+2)- con adc, propagando el acarreo. Si el bit 0 de (IX-2) esta puesto, niega antes la velocidad entera (complemento a dos de DE y complemento de C), que es como el mismo codigo sirve para ir a los dos lados
	push ix		;73f6
	push hl			;73f8   ; dos copias de HL: una para leer la posicion y otra para escribirla
	push hl			;73f9
	ld a,(hl)			;73fa   ; HL = la posicion de 16 bits que hay en (HL)
	inc hl			;73fb
	ld h,(hl)			;73fc
	ld l,a			;73fd
	pop ix		;73fe   ; IX = el puntero original: los campos vecinos se indexan desde el
	ld b,(ix+002h)		;7400   ; B = (IX+2), el byte de mas peso de la posicion
	ld c,(ix+005h)		;7403   ; C = (IX+5), la extension de signo de la velocidad
	ld a,(ix-002h)		;7406   ; (IX-2): el byte de direccion, 0xE136 para el jugador
	rra			;7409   ; su bit 0 decide el sentido
	jr nc,L_7416		;740a
	ld a,c			;740c   ; niega C, D y E: el complemento a dos de la velocidad entera
	cpl			;740d
	ld c,a			;740e
	ld a,d			;740f
	cpl			;7410
	ld d,a			;7411
	ld a,e			;7412
	cpl			;7413
	ld e,a			;7414
	inc de			;7415
L_7416:
	add hl,de			;7416   ; los dos bytes bajos de la posicion
	ld a,b			;7417
	adc a,c			;7418   ; y el tercero con el acarreo: los 24 bits completos
	ld b,a			;7419
	ld a,(ix+001h)		;741a
	ex de,hl			;741d
	pop hl			;741e
	ld (hl),e			;741f   ; guarda la posicion nueva donde estaba
	inc hl			;7420
	ld (hl),d			;7421
	ld (ix+002h),b		;7422   ; y el byte de mas peso en su campo
	pop ix		;7425
	ret			;7427
puede_avanzar:		; Decide si un registro puede seguir avanzando: si el campo dos bytes antes vale 0x10, basta la comprobacion de 0x745e; si no, ademas sondea tres alturas (0x04, y luego 0x08 menos) a 3 o 12 pixeles a un lado segun la direccion
	push hl			;7428
	dec hl			;7429   ; HL-2: el campo que decide el modo de comprobacion
	dec hl			;742a
	ld a,(hl)			;742b
	pop hl			;742c
	cp 010h		;742d   ; con 0x10, solo hace falta la comprobacion basica
	jr z,sonda_basica		;742f
	call sonda_basica		;7431   ; la comprobacion basica; NC = no se puede
	ret nc			;7434
	dec hl			;7435   ; HL-1: el byte de direccion
	ld a,(hl)			;7436
	inc hl			;7437
	ld bc,00304h		;7438   ; BC = 0x0304: tres pixeles a un lado, cuatro de altura
	rr a		;743b   ; bit 0 de la direccion
	jr c,sondea_a_tres_alturas		;743d
	ld b,00ch		;743f   ; al otro lado, doce pixeles
sondea_a_tres_alturas:		; Sonda la celda (B,C) y, segun salga, baja ocho pixeles y vuelve a sondear una o dos veces mas: es la comprobacion de que cabe un cuerpo de tres celdas de alto
	push bc			;7441
	call sondea_una_celda		;7442   ; la primera sonda
	pop bc			;7445
	jr z,sondea_dos_mas_abajo		;7446   ; con Z (hay algo), a la cadena de abajo
	call sonda_ocho_mas_abajo		;7448   ; sin Z: una sonda ocho pixeles mas abajo
	ret z			;744b   ; si esa da Z, no se puede
	scf			;744c   ; se puede: devuelve C
	ret			;744d
sondea_dos_mas_abajo:		; Con la primera sonda ocupada: prueba dos alturas mas (ocho pixeles cada vez) y una ultima a ocho pixeles al lado
	call sonda_ocho_mas_abajo		;744e   ; ocho pixeles mas abajo
	ret z			;7451   ; ocupada: no se puede
	call sonda_ocho_mas_abajo		;7452   ; y ocho mas
	ret z			;7455   ; ocupada: no se puede
	ld b,008h		;7456   ; B = 8: la ultima sonda, ocho pixeles al lado
	call sondea_una_celda		;7458
	ret z			;745b   ; ocupada: no se puede
	scf			;745c   ; libre: devuelve C, se puede avanzar
	ret			;745d
sonda_basica:		; Prueba las dos celdas a 4 y a 10 pixeles a los lados y dos por encima (0xFE): devuelve Z si cualquiera de las dos esta ocupada, y C si las dos estan libres
	ld bc,004feh		;745e   ; BC = 0x04FE: cuatro pixeles a un lado, dos por encima
	call sondea_una_celda		;7461   ; ocupada: devuelve Z
	ret z			;7464
	ld bc,00afeh		;7465   ; BC = 0x0AFE: diez pixeles al otro lado, la misma altura
	call sondea_una_celda		;7468
	ret z			;746b   ; ocupada: devuelve Z
	scf			;746c   ; las dos libres: devuelve C
	ret			;746d
sonda_ocho_mas_abajo:		; Baja ocho pixeles el ajuste de altura y repite la sonda, conservando BC para la vuelta siguiente
	ld a,c			;746e   ; C -= 8: ocho pixeles mas abajo
	sub 008h		;746f
	ld c,a			;7471
	push bc			;7472
	call sondea_una_celda		;7473   ; y sondea ahi
	pop bc			;7476
	ret			;7477
decide_si_el_registro_sigue:		; Decide si un registro puede seguir su movimiento: cuando 0xE143 vale 0x10 y la X esta en la posicion 4 de la celda, sondea tres alturas (0x00, 0x08, 0x0E) y, si todas estan ocupadas, alinea la X a multiplo de 8 y devuelve Z; si no, mira ademas 0xE14 y el hueco de delante
	inc hl			;7478
	ld a,(0e143h)		;7479   ; A = (0xE143), el sentido guardado del escalon
	cp 010h		;747c   ; con 0x10 se salta la comprobacion fina
	inc hl			;747e
	ld d,(hl)			;747f   ; D = el byte de direccion del registro
	inc hl			;7480
	jr z,mira_hueco_y_pies		;7481
	ld a,(ix+005h)		;7483   ; (IX+5), la X del registro
	and 007h		;7486   ; X mod 8, que aqui tiene que valer 4
	cp 004h		;7488
	jr nz,mira_hueco_y_pies		;748a
	ld a,d			;748c   ; bit 0 de la direccion
	rra			;748d
	ld bc,00300h		;748e   ; BC = 0x0300: tres pixeles a un lado, sin ajuste de altura
	jr c,L_7495		;7491
	ld b,00ch		;7493   ; al otro lado, doce pixeles
L_7495:
	push de			;7495
	call sondea_una_celda		;7496   ; la primera sonda
	pop de			;7499
	jr z,sonda_altura_alta		;749a   ; libre: a la comprobacion de 0x74d6
sonda_altura_media:		; Segunda y tercera sondas del registro, a 0x08 y a 0x0E de altura
	ld a,d			;749c
	ld bc,00308h		;749d   ; BC = 0x0308: ocho pixeles de altura
	rra			;74a0   ; bit 0 de la direccion
	jr c,L_74A5		;74a1
	ld b,00ch		;74a3   ; al otro lado, doce pixeles
L_74A5:
	push de			;74a5
	call sondea_una_celda		;74a6   ; la segunda sonda
	pop de			;74a9
	jr z,para_el_registro		;74aa   ; ocupada: se para
	ld a,d			;74ac
	rra			;74ad
	ld bc,0030eh		;74ae   ; BC = 0x030E: catorce pixeles de altura
	jr c,L_74B5		;74b1
	ld b,00ch		;74b3
L_74B5:
	call sondea_una_celda		;74b5   ; la tercera sonda
	jr z,para_el_registro		;74b8   ; ocupada: se para
mira_hueco_y_pies:		; Con el campo 0x0E del registro puesto, mira si hay hueco delante y, si lo hay, comprueba tambien los pies antes de dejarlo seguir
	ld a,(ix+00eh)		;74ba   ; (IX+0x0E), el campo que habilita esta comprobacion
	and a			;74bd
	jr z,el_registro_sigue		;74be   ; a cero: el registro sigue sin mas
	call hay_hueco_delante		;74c0   ; mira si hay hueco delante
	jp c,comprueba_los_pies		;74c3   ; con C: comprueba tambien los pies
para_el_registro:		; Alinea a multiplo de 8 la X del registro y devuelve Z: el registro no puede seguir
	ld a,(hl)			;74c6   ; A = la X del registro
	and 0f8h		;74c7   ; alineada a multiplo de 8
	ld (hl),a			;74c9
	xor a			;74ca   ; devuelve Z: parado
	and a			;74cb
	ret			;74cc
comprueba_los_pies:		; Con hueco delante, todavia se para si las sondas de los pies encuentran suelo
	call sondea_los_dos_pies		;74cd   ; las dos sondas de los pies
	jr z,para_el_registro		;74d0   ; con suelo: se para igual
el_registro_sigue:		; Devuelve NZ: el registro puede seguir avanzando
	xor a			;74d2   ; devuelve NZ: puede seguir
	cp 001h		;74d3
	ret			;74d5
sonda_altura_alta:		; Cuarta sonda, a 0x14 de altura: si esta ocupada el registro se para, y si no vuelve a la cadena de 0x749c
	ld a,d			;74d6
	ld bc,00314h		;74d7   ; BC = 0x0314: veinte pixeles de altura
	rra			;74da   ; bit 0 de la direccion
	jr c,L_74DF		;74db
	ld b,00ch		;74dd   ; al otro lado, doce pixeles
L_74DF:
	push de			;74df
	call sondea_una_celda		;74e0   ; la sonda
	pop de			;74e3
	jr z,para_el_registro		;74e4   ; ocupada: se para
	jr sonda_altura_media		;74e6   ; libre: repite la cadena de alturas
avanza_guion_de_movimiento:		; Interprete del guion de movimiento de un registro: salvo en la tarea 10, pone a cero 0xE004 antes de empezar
	ld a,(0e000h)		;74e8   ; A = la tarea activa
	cp 00ah		;74eb   ; en la tarea 10 no se toca el contador
	jr z,lee_paso_del_guion		;74ed
	xor a			;74ef
	ld (0e004h),a		;74f0   ; (0xE004) := 0
lee_paso_del_guion:		; Cuerpo del interprete: coge de (IX+0x0A)/(IX+0x0B) el puntero al guion, lee el byte siguiente y lo suma a la Y del registro; 0xFF acaba el guion (con un paso de 4) y 0xFE marca el punto de repeticion, poniendo (IX+0x0C) a 1 y retrocediendo el puntero
	push hl			;74f3
	push hl			;74f4
	ld a,00ah		;74f5   ; HL += 10: el campo del puntero al guion
	call suma_a_hl		;74f7
	ld e,(hl)			;74fa   ; DE = el puntero al guion
	inc hl			;74fb
	ld d,(hl)			;74fc
	inc hl			;74fd
	ld b,(hl)			;74fe   ; B = el byte siguiente, que decide el signo del paso
	pop hl			;74ff
	pop ix		;7500   ; IX = el registro, para indexar sus campos
	dec hl			;7502   ; HL-1: el byte de direccion del registro
	ld a,(hl)			;7503
	inc hl			;7504
	inc hl			;7505
	inc hl			;7506
	inc hl			;7507   ; HL avanza al campo de la animacion
	and 00ch		;7508   ; bits 2-3 de la direccion
	jr z,aplica_paso_del_guion		;750a
	dec (hl)			;750c   ; con ellos puestos, la animacion baja uno
	bit 2,a		;750d   ; bit 2: si esta puesto se queda ahi
	jr nz,aplica_paso_del_guion		;750f
	inc (hl)			;7511   ; si no, sube dos: queda en +1
	inc (hl)			;7512
aplica_paso_del_guion:		; Lee el byte del guion: 0xFF acaba (paso fijo de 4), y si no, lo escala x4 cuando 0xE004 vale 2 y lo niega si B no es cero
	ld a,(de)			;7513   ; A = el byte del guion
	inc a			;7514
	jr z,paso_final_del_guion		;7515   ; 0xFF: fin del guion
	dec a			;7517
	ld c,a			;7518   ; C guarda el paso
	ld a,(0e004h)		;7519   ; A = (0xE004)
	dec a			;751c
	dec a			;751d   ; vale 2?
	ld a,c			;751e
	jr nz,niega_paso_si_procede		;751f
	add a,a			;7521   ; si vale 2, el paso se multiplica por cuatro
	add a,a			;7522
niega_paso_si_procede:		; Si B no es cero, niega el paso antes de aplicarlo
	dec b			;7523
	inc b			;7524   ; B a cero: el paso va tal cual
	jr nz,guarda_puntero_del_guion		;7525
	neg		;7527   ; si no, cambiado de signo
guarda_puntero_del_guion:		; Aplica el paso, avanza el puntero del guion (una posicion, o ninguna si B no es cero), lo guarda en (IX+0x0A)/(IX+0x0B) y, si el byte al que ha llegado es 0xFE, marca (IX+0x0C) y sigue retrocediendo
	call suma_paso_a_la_y		;7529   ; aplica el paso a la Y del registro
	inc de			;752c   ; el puntero avanza una posicion
	ld a,b			;752d
	and a			;752e   ; B a cero: avanza de verdad
	jr z,escribe_puntero_del_guion		;752f
	dec de			;7531   ; si no, retrocede: el guion se lee al reves
retrocede_puntero:		; Retrocede una posicion mas el puntero del guion
	dec de			;7532   ; una posicion atras
escribe_puntero_del_guion:		; Guarda el puntero en los campos 0x0A/0x0B del registro y comprueba si el byte al que apunta es 0xFE, la marca de repeticion
	ld (ix+00ah),e		;7533   ; byte bajo del puntero
	ld (ix+00bh),d		;7536   ; byte alto
	ld a,(de)			;7539   ; A = el byte al que apunta ahora
	cp 0feh		;753a   ; 0xFE es la marca de repeticion
	ret nz			;753c
	ld (ix+00ch),001h		;753d   ; (IX+0x0C) := 1: queda anotada
	jr retrocede_puntero		;7541   ; y sigue retrocediendo hasta pasarla
paso_final_del_guion:		; El guion se ha acabado (0xFF): el ultimo paso vale 4
	ld a,004h		;7543   ; A := 4, el paso de cierre
suma_paso_a_la_y:		; Suma A a la Y del registro (dos bytes antes de donde apunta HL)
	dec hl			;7545   ; HL-2: la Y del registro
	dec hl			;7546
	add a,(hl)			;7547   ; Y += el paso
	ld (hl),a			;7548   ; y la guarda
	ret			;7549

; ----------------------------------------------------------------------
; DATOS guion_de_movimiento: El guion de catorce pasos (FF 04 02 02 02 01 01
;   02 00 01 01 00 00 FE) que fija_rumbo_nuevo carga en el enemigo desde
;   0x754b: lee_paso_del_guion lo va sumando a la Y, el 0xFF acaba y el 0xFE
;   marca el punto de repeticion. Se entra en 0x754b, un byte dentro, de modo
;   que el 0xFF inicial solo se ve leyendo el guion hacia atras
;   0x754a..0x7558  (14 bytes)
DATA_guion_de_movimiento:
	defb 0ffh	; 754a
	defb 004h	; 754b
	defb 002h	; 754c
	defb 002h	; 754d
	defb 002h	; 754e
	defb 001h	; 754f
	defb 001h	; 7550
	defb 002h	; 7551
	defb 000h	; 7552
	defb 001h	; 7553
	defb 001h	; 7554
	defb 000h	; 7555
	defb 000h	; 7556
	defb 0feh	; 7557

; ======================================================================
; CODIGO 0x7558..0x75d4  (124 bytes)
; ======================================================================


da_un_paso_de_caida:		; Deja el registro en estado 2, le alinea la X a multiplo de 4 y comprueba el suelo: si lo hay, redondea la X y devuelve NZ; si no, devuelve Z y el registro sigue cayendo
	ld (hl),002h		;7558   ; estado := 2, cayendo
	inc hl			;755a
	inc hl			;755b
	inc hl			;755c
	ld a,(hl)			;755d   ; A = la X del registro
	and 0fch		;755e   ; alineada a multiplo de 4
	ld (hl),a			;7560
	push hl			;7561
	call hay_suelo_bajo		;7562   ; comprueba el suelo bajo el registro
	pop hl			;7565
	ret nc			;7566   ; sin suelo: sigue cayendo
	ld a,(hl)			;7567
	add a,004h		;7568   ; con suelo: la X se redondea a la media celda siguiente
	and 0fch		;756a
	ld (hl),a			;756c
	xor a			;756d   ; devuelve NZ: ha aterrizado
	sub 001h		;756e
	ret			;7570
avanza_registro_alineado:		; Mueve un registro un paso: solo actua en los fotogramas que deja pasar la mascara de B, exige que la celda de destino este libre si la X esta cuadrada, y ajusta la Y con el bit 0 de la suma del contador
	ld a,(0e003h)		;7571   ; A = contador de fotogramas
	and b			;7574   ; mascara de B: el llamador decide cada cuantos fotogramas se mueve
	ret nz			;7575
	inc hl			;7576   ; HL avanza al campo siguiente; C se lo queda
	ld c,(hl)			;7577
	inc hl			;7578
	inc hl			;7579
	inc hl			;757a
	ld a,(hl)			;757b   ; A = la X del registro
	dec hl			;757c
	dec hl			;757d
	and 003h		;757e   ; X mod 4: solo con la X cuadrada hace falta comprobar la celda
	jr nz,aplica_paso_del_registro		;7580
	push hl			;7582
	call celda_alineada_libre		;7583   ; la celda de destino tiene que estar libre
	pop hl			;7586
	ret z			;7587   ; si no lo esta, no se mueve
aplica_paso_del_registro:		; Suma el paso al registro: sube la X en uno (o la baja en uno si el bit 0 de C esta puesto) y sigue con el ajuste de Y
	ld a,c			;7588
	inc hl			;7589   ; HL apunta a la X
	inc hl			;758a
	inc (hl)			;758b   ; la X sube uno
	rra			;758c   ; bit 0 de C: el sentido del paso
	jr nc,ajusta_y_del_registro		;758d
	dec (hl)			;758f   ; con el bit puesto, la X baja dos: queda en -1 respecto de donde estaba
	dec (hl)			;7590
ajusta_y_del_registro:		; Lee el campo que esta diez bytes mas alla, cuenta uno en el campo cinco mas atras y sube o baja la Y un pixel segun el bit 0 de la suma con C
	push hl			;7591
	ld a,00ah		;7592   ; HL += 10: el campo lejano del registro
	call suma_a_hl		;7594
	ld a,(hl)			;7597   ; A = ese campo
	dec hl			;7598
	dec hl			;7599
	dec hl			;759a
	dec hl			;759b
	dec hl			;759c
	inc (hl)			;759d   ; el campo cinco mas atras sube uno
	pop hl			;759e
	add a,c			;759f   ; A += C
	ld b,001h		;75a0   ; por defecto la Y sube un pixel
	bit 0,a		;75a2   ; bit 0 del resultado: decide el sentido
	jr z,L_75A8		;75a4
	ld b,0ffh		;75a6   ; con el bit puesto, la Y baja un pixel
L_75A8:
	dec hl			;75a8
	dec hl			;75a9
	ld a,(hl)			;75aa   ; Y += el paso
	add a,b			;75ab
	ld (hl),a			;75ac
	xor a			;75ad   ; devuelve Z y sin C: se ha movido
	cp 001h		;75ae
	ret			;75b0
tarea_10_reinicia_al_jugador:		; Tarea 10: vuelca la tabla de sprites y, en el primer paso del orden, recarga los doce bytes del registro del jugador desde la plantilla de 0x7730, lo redibuja y deja en 0xE080/0xE082 el guion de parametros de 0x75d4
	push bc			;75b1
	call actualiza_tabla_de_sprites		;75b2   ; vuelca el buffer de sprites a la SAT
	pop bc			;75b5
	djnz $+34		;75b6   ; solo el primer paso del orden hace lo de abajo
	ld hl,07730h		;75b8   ; HL = 0x7730, la plantilla del registro del jugador
	ld de,0e134h		;75bb   ; DE = 0xE134, el registro del jugador
	ld bc,0000ch		;75be   ; BC = 12 bytes: estado, entrada, direccion, posicion y lo que sigue
	ldir		;75c1
	call monta_sprite_del_jugador		;75c3   ; y lo redibuja con la plantilla ya cargada
	ld hl,075d4h		;75c6   ; (0xE080) := 0x75d4, el guion de parametros
	ld (0e080h),hl		;75c9
	ld a,088h		;75cc
	ld (0e082h),a		;75ce   ; (0xE082) := 0x88, su contador
L_75D1:
	jp avanza_orden		;75d1

; ----------------------------------------------------------------------
; DATOS parametros_75d4: Cuatro bytes; su direccion se guarda en (0xe080) por
;   0x75c6, no se leen aqui
;   0x75d4..0x75d8  (4 bytes)
DATA_parametros_75d4:
	defb 004h,01bh,014h,0ffh	; 75d4

; ======================================================================
; CODIGO 0x75d8..0x76d6  (254 bytes)
; ======================================================================


tarea_10_paso_2:		; Segundo paso: da un paso a la maquina de estados del jugador y, cuando 0xE053 se libera, prepara la direccion y deja el contador en 2
	djnz tarea_10_paso_3		;75d8
	call entrada_desde_el_guion		;75da   ; la puesta a punto de 0x45d6
	call avanza_estado_del_jugador		;75dd   ; un paso de la maquina de estados del jugador
	ld a,(0e053h)		;75e0   ; (0xE053): mientras siga puesto, se espera aqui
	and a			;75e3
	ret nz			;75e4
	call L_4D61		;75e5   ; la rutina de accion de 0x4d61
	ld hl,0e136h		;75e8   ; (0xE136) := 0, mirando al lado por defecto
	ld (hl),a			;75eb
	dec a			;75ec
	dec hl			;75ed
	ld (hl),a			;75ee   ; (0xE135) := 0xFF, entrada a tope
	ld a,002h		;75ef
	ld (0e004h),a		;75f1   ; (0xE004) := 2, el contador del paso siguiente
	jr $-35		;75f4
tarea_10_paso_3:		; Tercer paso: sigue dando pasos a la maquina de estados hasta que 0xE142 se pone
	djnz tarea_10_paso_4		;75f6
	call avanza_estado_del_jugador		;75f8   ; un paso de la maquina de estados
	ld a,(0e142h)		;75fb   ; (0xE142): mientras siga a cero, se sigue aqui
	or a			;75fe
	ret z			;75ff
	jr $-47		;7600
tarea_10_paso_4:		; Cuarto paso: llama a 0x6ea4 y a 0x7811 y deja el contador en 0xD0 fotogramas
	djnz tarea_10_paso_5		;7602
	call avanza_ronda		;7604   ; la rutina de 0x6ea4
	call dibuja_marcadores_finales		;7607   ; y la de 0x7811
	ld a,0d0h		;760a   ; (0xE004) := 0xD0, la espera larga del paso siguiente
	ld (0e004h),a		;760c
	jr $-62		;760f
tarea_10_paso_5:		; Quinto paso: agota el contador de 0xD0 fotogramas y pasa a la tarea 8
	djnz tarea_10_pantalla_final		;7611
	ld hl,0e004h		;7613   ; HL = 0xE004, el contador
	dec (hl)			;7616   ; mientras quede, espera
	ret nz			;7617
	ld a,008h		;7618
	ld (0e000h),a		;761a   ; (0xE000) := 8: a la tarea 8
	ret			;761d
tarea_10_pantalla_final:		; Sexto paso: monta la pantalla final. Aparca los sprites, deja la accion pendiente en 0x20, suena el efecto 0x8b, borra la sala entera (los 0x721 bytes del buffer de 0xE700), dibuja los dos guiones grandes de 0x76d6 y 0x7707, y remata con cinco rotulos y una franja de patron 0x96
	call aparca_buffer_de_sprites		;761e   ; aparca todos los sprites del buffer
	call temporizador_de_dos_contadores		;7621   ; el temporizador de 0x4330; P = todavia no toca
	ret p			;7624
	ld a,020h		;7625   ; accion pendiente := 0x20
	call guarda_accion_pendiente		;7627
	ld a,08bh		;762a   ; efecto de sonido 0x8b
	call reproduce_efecto		;762c
	call borra_sala		;762f   ; borra el dibujo de la sala
	ld hl,0e700h		;7632   ; y borra tambien el buffer de sala entero
	ld de,0e701h		;7635
	ld bc,00720h		;7638   ; 0x720 bytes: las 22 filas de 96 mas el remate
	ld (hl),000h		;763b
	ldir		;763d
	ld hl,02480h		;763f   ; el guion 0x76d6 en VRAM 0x2480
	ld de,076d6h		;7642
	call dibuja_guion_x3_tercios		;7645
	ld hl,00480h		;7648   ; el guion 0x7707 en VRAM 0x0480
	ld de,07707h		;764b
	call dibuja_guion_x3_tercios		;764e
	ld hl,0391fh		;7651   ; el primer rotulo, patron base 0x90
	ld c,090h		;7654
	xor a			;7656
	call rotulo_horizontal		;7657
	ld hl,03a03h		;765a   ; el segundo y el tercero, patron base 0x92
	ld c,092h		;765d
	call rotulo_horizontal		;765f
	ld hl,03a2bh		;7662
	call rotulo_horizontal		;7665
	ld hl,03a04h		;7668   ; el cuarto y el quinto, patron base 0x94, con el flanco puesto
	ld c,094h		;766b
	inc a			;766d
	call rotulo_horizontal		;766e
	ld hl,03a2ch		;7671
	call rotulo_horizontal		;7674
	ld de,07723h		;7677   ; un rectangulo de 3x2 celdas desde 0x7723 en VRAM 0x3a1e
	ld bc,00302h		;767a
	ld hl,03a1eh		;767d
	call dibuja_rectangulo_vram		;7680
	ld a,096h		;7683   ; una franja de 32 celdas con el patron 0x96
	ld hl,03a60h		;7685
	ld bc,00020h		;7688
	call rellena_vram		;768b
	call L_4407		;768e   ; el nombre de la sala
	ld de,07729h		;7691   ; y seis celdas sueltas con el patron 0x97, cuyas posiciones estan en 0x7729
	ld b,006h		;7694
pinta_celdas_sueltas:		; Escribe el patron 0x97 en las seis celdas de la fila 0x39xx cuyos bytes bajos lista la tabla de 0x7729
	ld a,(de)			;7696   ; A = el byte bajo de la celda
	ld l,a			;7697
	ld h,039h		;7698   ; la fila alta es siempre 0x39
	ld a,097h		;769a   ; patron 0x97
	call 0004dh		;769c   ; BIOS WRTVRM - Writes data in VRAM
	inc de			;769f
	djnz pinta_celdas_sueltas		;76a0
	ld hl,0e001h		;76a2   ; y avanza el orden de la tarea
	inc (hl)			;76a5
	ret			;76a6
rotulo_horizontal:		; Dibuja un rotulo que se estira: escribe el patron C en la celda de HL y va rellenando hacia la izquierda con C+1, bajando una fila (32 celdas) en cada vuelta hasta pasar de VRAM 0x3a80
	ld b,000h		;76a7   ; B := 0, el ancho arranca a cero y crece solo
fila_del_rotulo:		; Una fila del rotulo: rellena B celdas hacia la izquierda con el patron C+1 y remata con C
	push hl			;76a9
	push bc			;76aa
	dec b			;76ab   ; con B a cero, esta fila solo lleva la celda de remate
	inc b			;76ac
	jr z,remate_del_rotulo		;76ad
celda_de_relleno:		; Una celda de relleno del rotulo, con el patron C+1
	ex af,af'			;76af
	ld a,c			;76b0   ; A = C+1, el patron de relleno
	inc a			;76b1
	call 0004dh		;76b2   ; BIOS WRTVRM - Writes data in VRAM | lo escribe
	ex af,af'			;76b5
	dec hl			;76b6   ; una celda a la izquierda
	and a			;76b7   ; con el flanco a cero avanza de una en una; con el flanco puesto, de dos en dos
	jr z,L_76BC		;76b8
	inc hl			;76ba
	inc hl			;76bb
L_76BC:
	djnz celda_de_relleno		;76bc
remate_del_rotulo:		; Cierra la fila escribiendo el patron C (sin el +1) y salta a la fila siguiente, parando al pasar de VRAM 0x3a80
	pop bc			;76be
	inc b			;76bf   ; el ancho crece una celda para la fila siguiente
	ex af,af'			;76c0
	ld a,c			;76c1   ; A = C, el patron de remate
	call 0004dh		;76c2   ; BIOS WRTVRM - Writes data in VRAM | lo escribe
	ex af,af'			;76c5
	pop hl			;76c6
	ld de,00020h		;76c7   ; HL += 32: la fila siguiente
	add hl,de			;76ca
	push hl			;76cb
	and a			;76cc
	ld de,03a80h		;76cd   ; tope: VRAM 0x3a80
	sbc hl,de		;76d0
	pop hl			;76d2
	jr c,fila_del_rotulo		;76d3   ; mientras no se pase, otra fila
	ret			;76d5

; ----------------------------------------------------------------------
; DATOS guion_dibujo_76d6: Guion para L_451a, cargado en 0x7642
;   0x76d6..0x7707  (49 bytes)
DATA_guion_dibujo_76d6:
	defb 088h,000h,002h,006h,000h,00fh,02fh,06fh,000h,003h,0feh,081h,000h,003h,0efh,088h	; 76d6  ....../o........
	defb 000h,001h,003h,007h,00fh,01fh,03fh,07fh,009h,0ffh,087h,080h,0c0h,0e0h,0f0h,0f8h	; 76e6  ......?.........
	defb 0fch,0feh,009h,0ffh,087h,055h,0aah,055h,0aah,066h,099h,066h,008h,000h,081h,0c0h	; 76f6  .....U.U.f.f....
	defb 000h	; 7706

; ----------------------------------------------------------------------
; DATOS guion_7707: Guion para L_451a, cargado en 0x764b
;   0x7707..0x7723  (28 bytes)
DATA_guion_7707:
	defb 088h,060h,060h,0a0h,0a0h,060h,060h,0a0h,0a0h,002h,060h,002h,0a0h,002h,060h,002h	; 7707  .``..``...`...`.
	defb 0a0h,010h,080h,010h,060h,004h,08ah,004h,06ah,008h,050h,000h	; 7717  ....`...j.P.

; ----------------------------------------------------------------------
; DATOS bloque_final_3x2: Las seis celdas del rectangulo de 3x2 que
;   tarea_10_pantalla_final dibuja en VRAM 0x3A1E (0x7677-0x7680: DE=0x7723,
;   BC=0x0302)
;   0x7723..0x7729  (6 bytes)
DATA_bloque_final_3x2:
	defb 063h,064h	; 7723
	defb 000h,065h	; 7725
	defb 066h,067h	; 7727

; ----------------------------------------------------------------------
; DATOS celdas_sueltas_finales: Los seis bytes bajos de las celdas de la fila
;   0x39xx que pinta_celdas_sueltas (0x7696) rellena con el patron 0x97
;   0x7729..0x772f  (6 bytes)
DATA_celdas_sueltas_finales:
	defb 009h	; 7729
	defb 016h	; 772a
	defb 038h	; 772b
	defb 067h	; 772c
	defb 074h	; 772d
	defb 08eh	; 772e

; ----------------------------------------------------------------------
; DATOS plantilla_registro_del_jugador: Los doce bytes con que
;   tarea_10_reinicia_al_jugador (0x75b8-0x75c1) recarga el registro del
;   jugador de 0xE134: estado, entrada, direccion, posicion y el resto de
;   campos. La copia empieza en 0x7730, un byte dentro de este bloque
;   0x772f..0x773c  (13 bytes)
DATA_plantilla_registro_del_jugador:
	defb 0a9h,000h,004h,001h,088h,000h,0f0h,000h,0c0h,000h,000h,000h	; 772f  ............
	defb 000h	; 773b

; ======================================================================
; CODIGO 0x773c..0x7836  (250 bytes)
; ======================================================================


monta_el_mapa_del_valle:		; Prepara EL MAPA DEL VALLE, la pantalla que sale entre piramide y piramide: aparca los sprites, dibuja los guiones de 0x7836, 0x78df y 0x7908 -el sendero con las quince piramides y el rotulo GOAL-, pone a cero el contador de reposo (0xE130) y el de 0xE140, suena el efecto 0x91 y monta los digitos de (0xE054) y (0xE057). Las quince piramides no son una lista: son un ANILLO, y cada puerta de cada piramide dice a cual lleva (ver reparte_entidades_de_la_sala)
	call aparca_buffer_de_sprites		;773c   ; aparca todos los sprites del buffer
	ld de,07836h		;773f   ; el guion 0x7836 en VRAM 0x2600
	ld hl,02600h		;7742
	call dibuja_guion_x3_tercios		;7745
	ld de,078dfh		;7748   ; el guion 0x78df en VRAM 0x0600
	ld hl,00600h		;774b
	call dibuja_guion_x3_tercios		;774e
	ld de,07908h		;7751   ; y el guion 0x7908, que ya trae su propia direccion
	call dibuja_guion_con_direccion		;7754
	xor a			;7757
	ld (0e130h),a		;7758   ; (0xE130) := 0: el contador de fotogramas de la pantalla en reposo arranca de cero
	ld (0e140h),a		;775b   ; (0xE140) := 0: y el contador lento tambien
	ld a,091h		;775e   ; efecto de sonido 0x91
	call reproduce_efecto		;7760
	ld a,(0e054h)		;7763   ; A = (0xE054)
	call coloca_sprites_de_digito		;7766   ; lo pasa por 0x7823
	ld a,(0e057h)		;7769   ; A = (0xE057), el que se convierte en sprites
	ld de,07a6eh		;776c   ; DE = la tabla de patrones de 0x7a6e
monta_digitos:		; Convierte A en la posicion y el patron de una pareja de sprites: divide A entre dos (topandolo en 3), suma a la posicion base de 0xE0FC los dos desplazamientos que da la tabla de 0x7a66, y coge de la tabla que trae DE el numero de patron
	push de			;776f   ; guarda la tabla de patrones que trajo el llamador
	srl a		;7770   ; A /= 2
	cp 004h		;7772   ; topado en 3: no hay mas de cuatro posiciones
	jr nz,aplica_desplazamiento_de_digito		;7774
	dec a			;7776
aplica_desplazamiento_de_digito:		; Suma a la posicion de 0xE0FC los dos bytes (Y,X) que la tabla de 0x7a66 asigna a este indice, y escribe el resultado en 0xE100
	push af			;7777   ; guarda el indice: hace falta otra vez al final
	add a,a			;7778   ; x2: la tabla de 0x7a66 tiene dos bytes por entrada
	ld hl,07a66h		;7779   ; HL = la tabla de desplazamientos de 0x7a66
	call suma_a_hl		;777c
	ld de,0e0fch		;777f   ; DE = 0xE0FC, la posicion base
	ld bc,0e100h		;7782   ; BC = 0xE100, donde se escribe la posicion ya desplazada
	ld a,(de)			;7785   ; Y base + desplazamiento
	add a,(hl)			;7786
	ld (bc),a			;7787
	inc hl			;7788
	inc de			;7789
	inc bc			;778a
	ld a,(de)			;778b   ; X base + desplazamiento
	add a,(hl)			;778c
	ld (bc),a			;778d
	inc bc			;778e
	pop af			;778f   ; recupera el indice
	pop de			;7790
	call suma_a_de		;7791   ; DE = la tabla de patrones + el indice
	ld a,(de)			;7794   ; A = el numero de patron
	ld (bc),a			;7795   ; y lo escribe detras de la posicion
	ret			;7796
reposo_dispara_guion:		; Deja en 0xE0FC el par de bytes 0x97/0x7B, llama a la rutina de color con A=1 y devuelve el primer byte a 0xC3
	ld hl,0e0fch		;7797
	push hl			;779a
	ld (hl),097h		;779b   ; 0x97 y 0x7B en 0xE0FC/0xE0FD: la posicion de los sprites del aviso
	inc hl			;779d
	ld (hl),07bh		;779e
	ld a,001h		;77a0   ; A := 1, el indice que usara la tabla de color
	call monta_digitos_con_tabla_7a72		;77a2
	pop hl			;77a5
	ld (hl),0c3h		;77a6   ; y el primer byte vuelve a 0xC3, que deja el sprite fuera de pantalla
	ret			;77a8
reposo_dibuja_contadores:		; Pasa (0xE055) por 0x7823 y luego monta con la tabla de 0x7a72 los sprites del contador de (0xE056)
	ld a,(0e055h)		;77a9   ; A = (0xE055)
	call coloca_sprites_de_digito		;77ac
	ld a,(0e056h)		;77af   ; A = (0xE056), el que se convierte en sprites
monta_digitos_con_tabla_7a72:		; Entrada a monta_digitos con la tabla de desplazamientos de 0x7a72
	ld de,07a72h		;77b2   ; DE = la tabla de 0x7a72
	jr monta_digitos		;77b5
pantalla_en_reposo:		; La rama de tarea_5_sala_en_reposo que corre en la DEMO: cicla cada 8 fotogramas el color de los sprites 19 y 20 con la tabla de 0x7a40, refresca la tabla de sprites y la pausa, y lleva el contador de fotogramas de 0xE130 con dos plazos: a los 0x58 llama a 0x77a9 y a los 0xE0 escribe 0xE1 en 0xE00D, que es lo que corta la demo y manda a la tarea 7
	ld a,(0e003h)		;77b7   ; A = contador de fotogramas (0xe003)
	and 007h		;77ba   ; mod 8: el ciclo de color tiene ocho pasos
	ld hl,07a40h		;77bc   ; HL = la tabla de ocho colores de 0x7a40
	call suma_a_hl		;77bf
	ld a,(hl)			;77c2   ; A = el color de este paso
	ld (0e0ffh),a		;77c3   ; color del sprite 19 (0xE0B0 + 19*4 + 3)
	ld (0e103h),a		;77c6   ; y el mismo color para el sprite 20
	call actualiza_tabla_de_sprites		;77c9   ; vuelca el buffer de sprites a la SAT
	call revisa_pausa_y_alterna_rotulo		;77cc   ; y atiende la tecla de pausa
	ld hl,0e054h		;77cf   ; HL = 0xE054
	ld a,(hl)			;77d2   ; A = (0xE054)
	inc hl			;77d3
	sub (hl)			;77d4   ; A -= (0xE055): la diferencia entre esos dos contadores de partida
	ld hl,0e130h		;77d5   ; HL = 0xE130, el contador de fotogramas de esta pantalla
	inc (hl)			;77d8   ; un fotograma mas
	cp 00eh		;77d9   ; la diferencia vale 14?
	ld a,(hl)			;77db   ; A = el contador de fotogramas
	jr z,reposo_con_diferencia_14		;77dc   ; con la diferencia en 14, a 0x77ea
	cp 058h		;77de   ; primer plazo: a los 0x58 fotogramas, 0x77a9
	jr z,reposo_dibuja_contadores		;77e0
	cp 0e0h		;77e2   ; segundo plazo: a los 0xE0 fotogramas
	ret nz			;77e4
	inc a			;77e5
	ld (0e00dh),a		;77e6   ; (0xE00D) := 0xE1: la senal que corta la demo y manda a la tarea 7
	ret			;77e9
reposo_con_diferencia_14:		; El camino de pantalla_en_reposo cuando (0xE054)-(0xE055) vale 14: a los 0x58 fotogramas dispara 0x7797, y si no, espera a que 0xE010 se libere para ir subiendo 0xE140 hasta 0x80 y avanzar entonces el contador de 0xE058
	cp 058h		;77ea   ; el mismo plazo de 0x58 fotogramas, aqui con otro destino
	jr z,reposo_dispara_guion		;77ec
	ld a,(0e010h)		;77ee   ; (0xE010): mientras siga ocupado, no se avanza
	or a			;77f1
	ret nz			;77f2
	ld hl,0e140h		;77f3   ; HL = 0xE140, el contador lento de esta rama
	ld a,(hl)			;77f6
	inc (hl)			;77f7   ; sube uno
	cp 080h		;77f8   ; hasta 0x80 no pasa nada
	ret nz			;77fa
	ld hl,0e058h		;77fb   ; al llegar: (0xE058)++ y el contador lento vuelve a 0
	inc (hl)			;77fe
	xor a			;77ff
	inc hl			;7800
	ld (hl),a			;7801
	ld d,h			;7802
	ld e,l			;7803
	inc de			;7804
	ld bc,0000ah		;7805
	ld a,c			;7808
	ldir		;7809
	call L_4238		;780b
	jp L_41B4		;780e
dibuja_marcadores_finales:		; Dibuja el guion 0x7a76 y suma dos veces 0x5000 al marcador: la bonificacion de la pantalla final
	ld de,07a76h		;7811   ; DE = el guion 0x7a76
	call dibuja_guion_con_direccion		;7814
	ld de,05000h		;7817   ; 0x5000 al marcador
	call suma_al_marcador		;781a
	ld de,05000h		;781d   ; y otros 0x5000
	jp suma_al_marcador		;7820
coloca_sprites_de_digito:		; Coge de la tabla de 0x7a48 la pareja de bytes (Y,X) que le toca al indice A-1 y la deja en 0xE0FC, rematando con 0xE4 en el tercer byte
	dec a			;7823   ; A-1: la tabla se indexa desde cero
	add a,a			;7824   ; x2: dos bytes por entrada
	ld hl,07a48h		;7825   ; HL = la tabla de posiciones de 0x7a48
	call suma_a_hl		;7828
	ld de,0e0fch		;782b   ; DE = 0xE0FC, la ranura de sprite del digito
	ldi		;782e   ; la Y y la X, copiadas
	ldi		;7830
	ex de,hl			;7832
	ld (hl),0e4h		;7833   ; y 0xE4 en el byte siguiente
	ret			;7835

; ----------------------------------------------------------------------
; DATOS guion_dibujo_7836: Guion para L_451a, cargado por L_773c
;   0x7836..0x78df  (169 bytes)
DATA_guion_dibujo_7836:
	defb 0a0h,001h,003h,007h,00fh,01fh,03fh,00fh,003h,080h,0c0h,0e0h,0f0h,0f8h,0fch,0f0h	; 7836  ......?.........
	defb 0c0h,001h,003h,007h,00fh,01fh,03fh,00fh,003h,080h,0c0h,0e0h,0f0h,0f8h,0fch,0f0h	; 7846  ......?.........
	defb 0c0h,005h,000h,081h,0ffh,00fh,080h,081h,0ffh,007h,000h,081h,0ffh,007h,000h,081h	; 7856  ................
	defb 0ffh,00ah,001h,008h,003h,008h,0c0h,0a3h,0ffh,038h,049h,081h,09dh,049h,038h,0ffh	; 7866  .........8I..I8.
	defb 0ffh,0e1h,013h,012h,013h,012h,0e2h,0ffh,0ffh,0c8h,068h,028h,0e8h,028h,02fh,0ffh	; 7876  ..........h(.(/.
	defb 001h,003h,007h,00fh,01fh,03fh,07fh,07fh,0f0h,0f9h,0fdh,007h,0ffh,003h,0dfh,091h	; 7886  .....?..........
	defb 0cbh,089h,080h,000h,081h,0d1h,0f3h,0f3h,0fbh,0ffh,0ffh,00fh,01fh,03fh,03fh,07fh	; 7896  .............??.
	defb 07fh,005h,0ffh,08ah,0f7h,0f3h,0d7h,083h,085h,0f8h,0f8h,0f0h,0fah,0feh,005h,0ffh	; 78a6  ................
	defb 004h,07fh,007h,03fh,007h,07fh,004h,03fh,00bh,00fh,00dh,01fh,004h,080h,00ch,0c0h	; 78b6  ...?...?........
	defb 003h,0f0h,00ch,0e0h,00bh,0f0h,006h,0e0h,006h,080h,004h,000h,007h,080h,00ch,0c0h	; 78c6  ................
	defb 007h,080h,006h,000h,004h,080h,002h,0c0h,000h	; 78d6  .........

; ----------------------------------------------------------------------
; DATOS guion_78df: Guion para L_451a, cargado en 0x7748
;   0x78df..0x7908  (41 bytes)
DATA_guion_78df:
	defb 005h,08fh,003h,06fh,005h,09fh,008h,08fh,083h,061h,06fh,06fh,005h,09fh,083h,081h	; 78df  ...o.....aoo....
	defb 08fh,08fh,030h,01fh,011h,06fh,006h,04fh,002h,06fh,006h,04fh,002h,06fh,006h,04fh	; 78ef  ..0..o.O.o.O.o.O
	defb 081h,06fh,008h,0e0h,078h,0f0h,048h,0f0h,000h	; 78ff  .o..x.H..

; ----------------------------------------------------------------------
; DATOS guion_7908: Guion CON direccion (L_4514), destino VRAM 0x1f20, cargado
;   en 0x7751 y por L_773c
;   0x7908..0x7a40  (312 bytes)
DATA_guion_7908:
	defb 020h,01fh,088h,006h,009h,010h,020h,040h,0c0h,030h,00fh,00ah,000h,085h,080h,040h	; 7908   ..... @.0.....@
	defb 020h,030h,0c0h,009h,000h,084h,010h,038h,07ch,0feh,003h,038h,032h,000h,087h,010h	; 7918   0.....8|..82...
	defb 018h,0fch,0feh,0fch,018h,010h,003h,038h,084h,0feh,07ch,038h,010h,032h,000h,087h	; 7928  .......8..|8.2..
	defb 010h,030h,07eh,0feh,07eh,030h,010h,080h,067h,038h,091h,020h,000h,030h,039h,032h	; 7938  .0~.~0..g8. .092
	defb 021h,02dh,029h,024h,01bh,033h,000h,02dh,021h,030h,000h,020h,04fh,000h,085h,0cfh	; 7948  !-)$.3.-!0. O...
	defb 0d0h,001h,001h,0d2h,004h,001h,088h,0d0h,0d3h,001h,001h,001h,0d2h,0d0h,0d5h,00fh	; 7958  ................
	defb 000h,081h,0d8h,010h,001h,081h,0dch,00eh,000h,092h,0dbh,001h,0c0h,0c3h,0c7h,0c7h	; 7968  ................
	defb 0c2h,0c3h,0c7h,0c7h,0c2h,0c3h,0c7h,0c8h,001h,001h,001h,0dfh,00eh,000h,081h,0d9h	; 7978  ................
	defb 00ch,001h,085h,0c9h,001h,001h,001h,0e0h,00eh,000h,092h,0dah,001h,001h,0c4h,0c7h	; 7988  ................
	defb 0c2h,0c3h,0c7h,0c7h,0c7h,0c2h,0c3h,0c7h,0c2h,0c1h,001h,001h,0e1h,00eh,000h,084h	; 7998  ................
	defb 0d7h,001h,001h,0c5h,00dh,001h,081h,0ddh,00eh,000h,003h,001h,089h,0c6h,0c2h,0c3h	; 79a8  ................
	defb 0c7h,0c7h,0c2h,0c3h,0c7h,0c8h,005h,001h,081h,0e2h,00eh,000h,081h,0d6h,00ah,001h	; 79b8  ................
	defb 081h,0c9h,005h,001h,081h,0e3h,00eh,000h,08dh,0d8h,001h,0c4h,0c2h,0c3h,0c7h,0c2h	; 79c8  ................
	defb 0c3h,0c7h,0c7h,0c7h,0c2h,0c1h,004h,001h,081h,0e4h,00eh,000h,083h,0dbh,001h,0c5h	; 79d8  ................
	defb 00eh,001h,081h,0dfh,00eh,000h,092h,0d9h,001h,0c6h,0c7h,0c7h,0c7h,0c2h,0c3h,0c7h	; 79e8  ................
	defb 0c2h,0c3h,0c7h,0c7h,0c2h,0c1h,001h,001h,0e0h,00eh,000h,081h,0dah,00ch,001h,085h	; 79f8  ................
	defb 0c9h,001h,001h,001h,0deh,00eh,000h,081h,0d7h,008h,001h,089h,0c4h,0c7h,0c7h,0c7h	; 7a08  ................
	defb 0c2h,0c1h,001h,001h,0e5h,00eh,000h,007h,001h,085h,0cah,0cch,0cdh,0ceh,0cbh,005h	; 7a18  ................
	defb 001h,081h,0e6h,00eh,000h,084h,0d6h,0d1h,0d4h,0d1h,004h,001h,08ah,0d4h,001h,001h	; 7a28  ................
	defb 001h,0d1h,0d1h,001h,001h,0d1h,0e7h,000h	; 7a38  ........

; ----------------------------------------------------------------------
; DATOS colores_del_aviso: Los ocho colores por los que pantalla_en_reposo
;   (0x77bc) hace ciclar los sprites 19 y 20, uno por cada valor de (0xe003)
;   mod 8
;   0x7a40..0x7a48  (8 bytes)
DATA_colores_del_aviso:
	defb 001h	; 7a40
	defb 006h	; 7a41
	defb 006h	; 7a42
	defb 00ah	; 7a43
	defb 00ah	; 7a44
	defb 006h	; 7a45
	defb 006h	; 7a46
	defb 006h	; 7a47

; ----------------------------------------------------------------------
; DATOS posiciones_de_digito: Las parejas (Y,X) que coloca_sprites_de_digito
;   (0x7825) copia a 0xE0FC, indexadas por A-1
;   0x7a48..0x7a66  (30 bytes)
DATA_posiciones_de_digito:
	defb 03fh,04ah	; 7a48
	defb 03fh,06ah	; 7a4a
	defb 03fh,08ah	; 7a4c
	defb 04fh,0a2h	; 7a4e
	defb 04fh,08ah	; 7a50
	defb 04fh,062h	; 7a52
	defb 05fh,05ah	; 7a54
	defb 05fh,07ah	; 7a56
	defb 06fh,092h	; 7a58
	defb 06fh,06ah	; 7a5a
	defb 06fh,052h	; 7a5c
	defb 07fh,06ah	; 7a5e
	defb 07fh,082h	; 7a60
	defb 07fh,0a2h	; 7a62
	defb 08fh,0a2h	; 7a64

; ----------------------------------------------------------------------
; DATOS desplazamientos_de_digito: Las parejas (Y,X) que
;   aplica_desplazamiento_de_digito (0x7779) suma a la posicion base de 0xE0FC
;   0x7a66..0x7a6e  (8 bytes)
DATA_desplazamientos_de_digito:
	defb 0f9h,002h	; 7a66
	defb 008h,002h	; 7a68
	defb 0f9h,0f1h	; 7a6a
	defb 0f9h,004h	; 7a6c

; ----------------------------------------------------------------------
; DATOS patrones_de_digito_1: Los cuatro numeros de patron que monta_digitos
;   usa cuando el llamador entra por 0x776c (monta_pantalla_de_sala)
;   0x7a6e..0x7a72  (4 bytes)
DATA_patrones_de_digito_1:
	defb 0e8h	; 7a6e
	defb 0f0h	; 7a6f
	defb 0f4h	; 7a70
	defb 0ech	; 7a71

; ----------------------------------------------------------------------
; DATOS patrones_de_digito_2: Los cuatro numeros de patron que monta_digitos
;   usa cuando el llamador entra por monta_digitos_con_tabla_7a72 (0x77b2)
;   0x7a72..0x7a76  (4 bytes)
DATA_patrones_de_digito_2:
	defb 0f0h	; 7a72
	defb 0e8h	; 7a73
	defb 0ech	; 7a74
	defb 0f4h	; 7a75

; ----------------------------------------------------------------------
; DATOS guion_7a76: Guion CON direccion (L_4514), destino VRAM 0x38c9, cargado
;   en 0x7811
;   0x7a76..0x7a9e  (40 bytes)
DATA_guion_7a76:
	defb 0c9h,038h,08fh,023h,02fh,02eh,027h,032h,021h,034h,035h,02ch,021h,034h,029h,02fh	; 7a76  .8.#/.'2!45,!4)/
	defb 02eh,033h,02eh,000h,090h,033h,030h,025h,023h,029h,021h,02ch,000h,022h,02fh,02eh	; 7a86  .3...30%#)!,."/.
	defb 035h,033h,000h,000h,011h,004h,010h,000h	; 7a96  53......

; ======================================================================
; CODIGO 0x7a9e..0x7b8e  (240 bytes)
; ======================================================================


reproduce_efecto:		; Punto de entrada publico (28 llamadas desde el juego): desactiva interrupciones, llama a asigna_canal_y_nota con A=codigo de sonido y restaura todos los registros
	di			;7a9e
	push hl			;7a9f
	push de			;7aa0
	push bc			;7aa1
	push af			;7aa2
	push ix		;7aa3
	call asigna_canal_y_nota		;7aa5   ; protege TODO el trabajo del motor de sonido de una interrupcion a mitad, ademas de no tocar ningun registro del llamador
	pop ix		;7aa8
	pop af			;7aaa
	pop bc			;7aab
	pop de			;7aac
	pop hl			;7aad
	ei			;7aae   ; reactiva las interrupciones justo antes del `ret`, no antes: mientras se restauran los registros el hardware sigue esperando
	ret			;7aaf
asigna_canal_y_nota:		; Con A=codigo de sonido (bit7=empieza con bytes de control, bit6=percusion, bits5-0=nota 0-63), elige el canal fisico y cuantas copias lanzar, y descarta la peticion si ya suena algo de mas prioridad
	ld c,a			;7ab0   ; C = parametro completo (con los bits 6/7); A se enmascara a la nota (0-63) para las comparaciones que siguen
	and 03fh		;7ab1
	ld b,002h		;7ab3
	ld hl,0e012h		;7ab5
	cp 00bh		;7ab8   ; notas graves (<11): 1 copia, en el bloque de canal de 0xE02C; notas medias (11-16): 2 copias; agudas (>=17): 3 copias, ambas en el bloque de 0xE010
	jr c,grupo_grave		;7aba
	cp 011h		;7abc
	jr c,L_7AC7		;7abe
	inc b			;7ac0
	jr L_7AC7		;7ac1
grupo_grave:		; notas <11: una sola copia y bloque 0xE02C en vez de 0xE010
	dec b			;7ac3
	ld hl,0e02eh		;7ac4
L_7AC7:
	ld a,(hl)			;7ac7   ; compara la nota nueva (C, sin los bits 6/7) contra la que ya suena en el canal elegido (el campo +02, bits5-0): si la nueva es de menor prioridad, `ret c` y no suena
	and 03fh		;7ac8
	ld e,a			;7aca
	ld a,c			;7acb
	and 03fh		;7acc
	cp e			;7ace
	ret c			;7acf
	add a,a			;7ad0
	ld de,07cf4h		;7ad1   ; DE = 0x7cf4 + nota*2: puntero de 16 bits a la palabra de la tabla_periodos_nota que da inicio al guion de esa nota
	call suma_a_de		;7ad4
	dec hl			;7ad7   ; HL retrocede 2 bytes, del campo +02 (que acaba de leer) a la BASE del bloque de canal (+00), para que arranca_guion pueda escribir el bloque entero
	dec hl			;7ad8
arranca_guion:		; Inicializa el bloque de canal (duracion=1, puntero de guion tomado de la tabla) y, si B>1, repite la misma inicializacion B-1 veces mas 10 bytes mas adelante y con la palabra SIGUIENTE de la tabla
	push hl			;7ad9
	pop ix		;7ada
	ld (hl),001h		;7adc   ; duracion=1 y duracion-restante=1: la primera nota se dispara en el siguiente tick sin esperar
	inc hl			;7ade
	ld (hl),001h		;7adf
	inc hl			;7ae1
	ld (hl),c			;7ae2   ; el campo +02 (estado) se copia del parametro ORIGINAL sin enmascarar: aqui es donde bit6/bit7 quedan grabados en el canal para el resto de la nota
	inc hl			;7ae3
	ld a,(de)			;7ae4
	ld (hl),a			;7ae5
	inc hl			;7ae6
	inc de			;7ae7
	ld a,(de)			;7ae8
	ld (hl),a			;7ae9
	ld (ix+009h),000h		;7aea
	ld a,00ah		;7aee   ; HL += 10 y DE += 2: SUPOSICION, la segunda/tercera copia (B=2 o 3) escribe 10 bytes mas alla del bloque de 14 bytes del canal, dentro de los campos +0A-+0D del MISMO bloque, no en el siguiente canal de la tabla de 0xE010/E01E/E02C -no verificado en caliente, el solape exacto con esos campos no esta comprobado nota a nota-
	call suma_a_hl		;7af0
	inc de			;7af3
	djnz arranca_guion		;7af4
	ret			;7af6
procesa_marca_de_bucle:		; Cuando el guion trae el byte 0xFE: lleva la cuenta de vueltas en +09 y, si no ha llegado al limite (el byte siguiente al 0xFE), salta el puntero de guion a la pareja de bytes que vienen despues; si ha llegado, lo deja pasar y sigue leyendo
	inc hl			;7af7
	ld a,(ix+009h)		;7af8   ; compara +09 (vueltas ya dadas) con el byte que sigue al 0xFE (el limite de vueltas del bucle)
	inc a			;7afb
	cp (hl)			;7afc
	jr z,ultima_vuelta		;7afd
	jp m,vuelta_pendiente		;7aff
	dec a			;7b02
vuelta_pendiente:		; actualiza el contador de vueltas (+09) y toma el puntero de 16 bits que sigue al 0xFE como nuevo destino del guion
	ld (ix+009h),a		;7b03   ; (ix+009h) = numero de vuelta ya cumplida, para compararlo la proxima vez que se llegue aqui
	inc hl			;7b06
	ld a,(hl)			;7b07
	ld (ix+003h),a		;7b08
	inc hl			;7b0b
	ld a,(hl)			;7b0c
	ld (ix+004h),a		;7b0d
	jr sigue_tras_bucle		;7b10
ultima_vuelta:		; contador de vueltas a 0, salta los 2 bytes de destino sin usarlos y avanza el guion 1 byte con procesa_pulso_de_canal
	inc hl			;7b12   ; se salta el puntero de destino sin leerlo: cuando el bucle ya se ha repetido las veces que tocaba, el guion sigue LINEAL despues de los 3 bytes del 0xFE
	inc hl			;7b13
	xor a			;7b14
	ld (ix+009h),a		;7b15
	call avanza_guion		;7b18
sigue_tras_bucle:		; +00 (duracion restante) se incrementa en 1 -de compensar el `dec` que le espera al volver a entrar por procesa_pulso_de_canal- y vuelve a procesa_pulso_de_canal
	inc (ix+000h)		;7b1b
	jp procesa_pulso_de_canal		;7b1e
conmuta_ruido_canal_c:		; Solo actua si C=5 (el canal C, la tercera copia del bucle de tick_sonido): pone el registro 7 del PSG (mezclador) a 0xB8 (los tres tonos, sin ruido) si D=1, o 0x9C (tono A+B, ruido C) si D=0
	ld a,c			;7b21
	cp 005h		;7b22
	ret nz			;7b24
	dec d			;7b25
	jr z,L_7B2C		;7b26
	ld a,09ch		;7b28   ; 0x9c: activa el generador de ruido en el canal C y apaga su tono -para percusion-; 0xb8: los tres canales en modo tono normal
	jr L_7B2E		;7b2a
L_7B2C:
	ld a,0b8h		;7b2c
L_7B2E:
	ld (0e03ah),a		;7b2e
	ld e,a			;7b31
	ld a,007h		;7b32
	jp 00093h		;7b34   ; BIOS WRTPSG - Writes data to PSG-register
tick_sonido:		; Llamada una vez por interrupcion de video (L_401A): re-escribe el ultimo valor del mezclador y recorre los tres bloques de canal (0xE010/E01E/E02C) dando un pulso a cada uno
	ld a,(0e03ah)		;7b37
	call L_7B2E		;7b3a
	ld c,001h		;7b3d   ; C=1 (registro PSG del tono agudo del canal A) y sube de 2 en 2 -1,3,5- para pasar al canal B y luego al C en cada vuelta del bucle
	ld ix,0e010h		;7b3f
	exx			;7b43
	ld b,003h		;7b44
	ld de,0000eh		;7b46   ; DE=0x0E=14: el tamano de un bloque de canal, para que `add ix,de` pase al siguiente
bucle_de_tick:		; Por canal: si el estado (+02) va a agotarse este tick (valor 1) llama primero a guion_especial_canal_c; si el canal sigue activo (+02 != 0) le da un pulso con procesa_pulso_de_canal
	exx			;7b49
	ld a,(ix+002h)		;7b4a   ; A = +02 de este canal; `dec a` + `call z` detecta el valor 1 (a punto de acabar) SIN modificar el +02 real, es una copia en A
	push af			;7b4d
	dec a			;7b4e
	call z,guion_especial_canal_c		;7b4f
	pop af			;7b52
	or a			;7b53
	call nz,procesa_pulso_de_canal		;7b54
	inc c			;7b57   ; C += 2: pasa al registro PSG del siguiente canal (agudo de A=1 -> B=3 -> C=5) para la vuelta siguiente del bucle
	inc c			;7b58
	exx			;7b59
	add ix,de		;7b5a
	djnz bucle_de_tick		;7b5c
	ret			;7b5e
guion_especial_canal_c:		; Solo actua sobre el canal C (C=5): SUPOSICION, cuando la nota esta a punto de apagarse le fuerza un puntero de guion distinto del normal -o reinicia desde una plantilla fija de 4 bytes en 0x7b91, o avanza +8 el puntero anterior-, en vez de dejar que procesa_pulso_de_canal lea el siguiente byte del guion normal; el proposito musical exacto (que efecto usa este guion aparte) no esta verificado en caliente
	ld a,c			;7b5f
	cp 005h		;7b60   ; `cp 005h / ret c`: solo sigue para C=5 (canal C); para A(C=1) o B(C=3) vuelve sin tocar nada
	ret c			;7b62
	ld hl,0e03eh		;7b63
	ld de,07b91h		;7b66
	ld a,(0e03bh)		;7b69   ; 0xE03B=0: reinicia desde la plantilla de 4 bytes de 0x7b91 (copiada con lddr); 0xE03B!=0: en vez de reiniciar, suma 8 al puntero de 16 bits guardado en 0xE03D/E03E (con acarreo) y sigue desde ahi
	cp 001h		;7b6c
	jr c,reinicia_con_plantilla		;7b6e
	ld a,008h		;7b70
	add a,(hl)			;7b72
	ld (hl),a			;7b73
	dec hl			;7b74
	jr nc,guarda_guion_canal_c		;7b75
	inc (hl)			;7b77
guarda_guion_canal_c:		; guarda el puntero calculado (HL-1) como el guion del canal C, igual que hace procesa_marca_de_bucle con el guion normal
	dec hl			;7b78   ; dec hl: el puntero quedo un byte adelantado (o por el `inc hl` x3 de reinicia_con_plantilla, o por la suma de 8 de guion_especial_canal_c), se corrige aqui antes de guardarlo
	ld (ix+003h),l		;7b79
	ld (ix+004h),h		;7b7c
	ret			;7b7f
reinicia_con_plantilla:		; copia hacia atras (lddr) los 4 bytes de 0x7b91 a 0xE03B-E03E antes de calcular el puntero
	push bc			;7b80
	ex de,hl			;7b81
	ld bc,00004h		;7b82
	lddr		;7b85   ; lddr hacia atras (HL y DE decrecen): copia los 4 bytes en el MISMO orden aunque el destino este mas bajo que el origen
	ex de,hl			;7b87
	pop bc			;7b88
	inc hl			;7b89
	inc hl			;7b8a
	inc hl			;7b8b
	jr guarda_guion_canal_c		;7b8c

; ----------------------------------------------------------------------
; DATOS tabla_e03b: Cuatro bytes copiados a 0xE03B-0xE03E por el lddr de
;   0x7b80 (puntero final en 0x7b66)
;   0x7b8e..0x7b92  (4 bytes)
DATA_tabla_e03b:
	defb 001h,021h,0b0h,061h	; 7b8e

; ======================================================================
; CODIGO 0x7b92..0x7cea  (344 bytes)
; ======================================================================


procesa_pulso_de_canal:		; Un tick de un canal ya activo: si toca tono (bit6 de +02 a 0) le dice al mezclador que este canal usa tono; si el estado es negativo (fase de caida) va a procesa_caida; si no, cuenta atras la duracion de la nota y, si aun no llega a 0, no hace nada mas este tick
	bit 6,a		;7b92
	ld d,001h		;7b94
	call z,conmuta_ruido_canal_c		;7b96   ; solo si bit6=0 (tono, no percusion) llama a conmuta_ruido_canal_c con D=1: en modo percusion no hace falta, ya lo puso escribe_periodo_de_ruido
	ld a,(ix+002h)		;7b99
	or a			;7b9c
	jp m,procesa_caida		;7b9d   ; bit7 de +02 puesto = fase de caida (la nota ya solto la tecla y se esta apagando): salta a procesa_caida en vez de leer un comando nuevo
	dec (ix+000h)		;7ba0
	ret nz			;7ba3
lee_comando_de_guion:		; Lee el siguiente byte del guion: 0xFE = marca de bucle (procesa_marca_de_bucle), 0xFF = fin de guion (silencia el canal), el resto es un comando de nota o de control
	ld l,(ix+003h)		;7ba4
	ld h,(ix+004h)		;7ba7
	ld a,(hl)			;7baa
	cp 0feh		;7bab   ; 0xFE es la marca de repeticion (bucle), 0xFF es el silencio final; ningun otro valor del guion puede confundirse con ellos porque las notas ocupan como mucho el rango 0x00-0xCF (ver lee_comando_de_guion mas abajo)
	jp z,procesa_marca_de_bucle		;7bad
	jr nc,fin_de_guion		;7bb0
	bit 7,(ix+002h)		;7bb2   ; si el bit7 de +02 esta puesto (se llega aqui tras una fase de caida completa, ver procesa_caida) el byte se interpreta como posible comando de control (0xD0 en adelante); si no, se asume nota corriente y se pasa directo a compara_nibble_de_nota
	jp nz,procesa_comando_de_control		;7bb6
	and 0f0h		;7bb9
	cp 020h		;7bbb
	ld a,(hl)			;7bbd
	jr nz,compara_nibble_de_nota		;7bbe
	and 00fh		;7bc0
	ld (ix+001h),a		;7bc2
	inc hl			;7bc5
	ld a,(hl)			;7bc6
compara_nibble_de_nota:		; El nibble alto del byte distingue una nota de ruido (0x1_, un periodo de ruido explicito) de una nota de tono corriente
	ld b,a			;7bc7
	and 0f0h		;7bc8
	cp 010h		;7bca   ; 0x1_: la nota es de RUIDO (periodo explicito en el propio comando), no de tono; cualquier otro nibble alto sigue por el camino de tono normal
	jr nz,nota_de_tono		;7bcc
	ld a,(hl)			;7bce
	and 01fh		;7bcf
	ld e,a			;7bd1
	inc hl			;7bd2
	bit 4,(hl)		;7bd3
	ld b,(hl)			;7bd5
	jr nz,escribe_periodo_de_ruido		;7bd6   ; bit4 del byte siguiente al del ruido: si esta puesto usa el periodo (E) tal cual, si no le resta 0x10 antes de escribirlo -SUPOSICION: un ajuste fino de un semitono, no verificado en caliente-
	ld a,e			;7bd8
	sub 010h		;7bd9
	ld e,a			;7bdb
escribe_periodo_de_ruido:		; Envia el periodo de ruido (E, con -0x10 si el bit4 del byte siguiente estaba puesto) al registro 6 del PSG (el periodo de ruido es GLOBAL, compartido por los tres canales) y activa el ruido en el canal C via conmuta_ruido_canal_c
	res 4,b		;7bdc
	dec hl			;7bde
	ld a,006h		;7bdf   ; reg 6 del PSG = periodo de ruido (unico y global, no hay uno por canal en el AY-3-8910)
	call 00093h		;7be1   ; BIOS WRTPSG - Writes data to PSG-register
	ld d,000h		;7be4
	call conmuta_ruido_canal_c		;7be6
	inc hl			;7be9
nota_de_tono:		; Si el canal esta en modo percusion (bit6 de +02) trata el byte como parametro directo; si no, sigue el camino de tono normal con nibbles de nota+duracion
	bit 6,(ix+002h)		;7bea   ; en modo percusion el mismo byte que en tono normal seria "nibble alto+nibble bajo de nota" se pasa entero como parametro B a dispara_duracion_y_volumen, sin separar nibbles
	jr z,tono_con_periodo_explicito		;7bee
	ld a,(hl)			;7bf0
	call avanza_guion		;7bf1
	ld a,b			;7bf4
	jr dispara_duracion_y_volumen		;7bf5
tono_con_periodo_explicito:		; Combina el nibble alto del comando con el byte siguiente (XOR) y escribe el periodo de 16 bits resultante directo en el PSG via escribe_periodo, sin pasar por la tabla_periodos_nota
	and 0f0h		;7bf7
	ld b,a			;7bf9
	xor (hl)			;7bfa   ; D = nibble alto del comando XOR el byte siguiente (E): SUPOSICION, una forma de codificar el periodo alto en menos bytes que un word completo, no verificada con partituras reales
	ld d,a			;7bfb
	inc hl			;7bfc
	ld e,(hl)			;7bfd
	call avanza_guion		;7bfe
	ex de,hl			;7c01
	call escribe_periodo		;7c02   ; escribe DE en el PSG (via escribe_periodo) ANTES de terminar de calcular la forma/volumen: el tono suena con el periodo nuevo aunque el volumen se ajuste despues
	ld a,b			;7c05
	rrca			;7c06
	rrca			;7c07
	rrca			;7c08
	rrca			;7c09
dispara_duracion_y_volumen:		; Copia la duracion (+01) al contador (+00), calcula cuando debe empezar la fase de caida (+08 = +0C + duracion) y va a escribe_volumen
	ld h,a			;7c0a
	ld e,(ix+001h)		;7c0b   ; +01 (duracion en ticks, calculada por calcula_duracion o fijada por dispara_nota) se copia a +00: es el contador que procesa_pulso_de_canal ira bajando cada tick
	ld (ix+000h),e		;7c0e
	ld a,(ix+00ch)		;7c11
	add a,e			;7c14
	ld (ix+008h),a		;7c15
	jr escribe_volumen		;7c18
fin_de_guion:		; Byte 0xFF: pone a 0 los contadores de repeticion (+09) y de nibble guardado (+0B), silencia el canal en el mezclador (conmuta_ruido_canal_c con D=1, modo tono) y borra el estado (+02=0), dejando el canal libre para la siguiente peticion
	xor a			;7c1a
	ld (ix+009h),a		;7c1b
	ld (ix+00bh),a		;7c1e
	ld d,001h		;7c21
	call conmuta_ruido_canal_c		;7c23
	xor a			;7c26
	ld (ix+002h),a		;7c27   ; +02=0: la comprobacion `or a; call nz,procesa_pulso_de_canal` de bucle_de_tick ya no volvera a llamar a este canal hasta la proxima asigna_canal_y_nota
	ld h,a			;7c2a
	jr escribe_volumen		;7c2b
procesa_caida:		; Cuenta atras el contador de caida (+00); si tambien llega a 0 vuelve a lee_comando_de_guion; si no, ajusta el limite auxiliar (+08) contra +0D y hace bajar el volumen (+07) un paso via escribe_volumen
	dec (ix+000h)		;7c2d   ; mismo campo +00 que ya conto la duracion de la nota, reutilizado ahora como cuenta atras de la caida
	jp z,lee_comando_de_guion		;7c30
	dec (ix+008h)		;7c33   ; +08 (el limite auxiliar) tambien baja cada tick, en paralelo a +00: cuando los dos coinciden se compara contra +0D mas abajo
	ld a,(ix+008h)		;7c36
	cp (ix+000h)		;7c39
	jr nz,ajusta_limite_de_caida		;7c3c
	ld e,a			;7c3e
	ld a,(ix+00dh)		;7c3f
	cp e			;7c42
	ld a,e			;7c43
	jr nc,un_paso_de_caida		;7c44
	ret			;7c46
ajusta_limite_de_caida:		; decrementa el limite auxiliar (+08) cuando no coincide todavia con el contador principal
	dec (ix+008h)		;7c47   ; +08 sigue bajando solo hasta alcanzar a +00; a partir de ahi ajusta_limite_de_caida ya no se llama (ver la comparacion de procesa_caida)
un_paso_de_caida:		; resta 1 al volumen guardado (+07); si ya era negativo no escribe nada mas (nota completamente apagada)
	ld a,(ix+007h)		;7c4a
	dec a			;7c4d   ; `dec a / ret m`: en cuanto +07 pasa de 0 a negativo, el volumen deja de bajarse y de escribirse: la nota queda en silencio para siempre hasta la proxima asigna_canal_y_nota
	ret m			;7c4e
	ld (ix+007h),a		;7c4f
	ld h,a			;7c52
escribe_volumen:		; Calcula el registro de volumen del PSG (8, 9 o 10 segun el canal A/B/C, con `rrca`+0x88 sobre C=1/3/5) y le escribe H
	ld a,c			;7c53
	rrca			;7c54
	add a,088h		;7c55   ; `rrca` + 0x88 sobre C=1/3/5 da 8/9/10 modulo 256: el mismo truco aritmetico que separa canal A/B/C en otras rutinas, sin tabla de consulta
	ld e,h			;7c57
	jp 00093h		;7c58   ; BIOS WRTPSG - Writes data to PSG-register
procesa_comando_de_control:		; Lee una posible cadena de bytes de control (0xD0-0xFF) antes de la nota: 0xD_ guarda un nibble en +0A, 0xF_ guarda dos bytes en +0C/+0D, 0xE_ con el bit 3 puesto guarda un nibble en +0B y VUELVE a leer otro byte de control
	ld a,(hl)			;7c5b   ; se llega aqui solo cuando lee_comando_de_guion detecto bit7=1 en +02 (justo tras una caida completa): el guion puede traer varios bytes de "configuracion" antes de la proxima nota real
	and 0f0h		;7c5c
	cp 0d0h		;7c5e
	ld a,(hl)			;7c60
	jr nz,L_7C6A		;7c61
	and 00fh		;7c63
	ld (ix+00ah),a		;7c65   ; 0xD_: nibble bajo -> +0A (el multiplicador de duracion que usa +0A en compara_nibble_de_nota mas abajo)
	inc hl			;7c68
	ld a,(hl)			;7c69
L_7C6A:
	cp 0f0h		;7c6a   ; byte < 0xF0: no es un comando 0xF, se salta directo a comando_0e con el byte ya leido en A
	jr c,comando_0e		;7c6c
	and 00fh		;7c6e
	ld (ix+006h),a		;7c70   ; 0xF_: nibble bajo -> +06 (forma por defecto), y los DOS bytes que siguen -> +0C y +0D (limites de la fase de caida)
	inc hl			;7c73
	ld a,(hl)			;7c74
	ld (ix+00ch),a		;7c75
	inc hl			;7c78
	ld a,(hl)			;7c79
	ld (ix+00dh),a		;7c7a
	inc hl			;7c7d
	ld a,(hl)			;7c7e
comando_0e:		; Si el bit 3 del nibble esta puesto, lo guarda en +0B y vuelve a procesa_comando_de_control (pueden encadenarse varios comandos de control seguidos); si no, es el ultimo y cae en dispara_nota
	cp 0e0h		;7c7f
	jr c,dispara_nota		;7c81
	and 00fh		;7c83
	bit 3,a		;7c85   ; bit3 del nibble: distingue los dos "tipos" de comando 0xE (uno alimenta +0B y encadena, el otro alimenta +05 -la octava- y es el ultimo de la cadena)
	jr z,comando_0e_sin_bit3		;7c87
	ld (ix+00bh),a		;7c89
	inc hl			;7c8c
	jr procesa_comando_de_control		;7c8d
comando_0e_sin_bit3:		; guarda el nibble en +05 (la octava) en vez de +0B
	ld (ix+005h),a		;7c8f
	inc hl			;7c92
	ld a,(hl)			;7c93
dispara_nota:		; El nibble bajo del byte es la duracion en unidades de +0A: si es 0 usa +0A directo, si no lo multiplica por el nibble (bucle en calcula_duracion)
	and 00fh		;7c94
	ld b,a			;7c96
	ld a,(ix+00ah)		;7c97
	jr z,nota_final		;7c9a
calcula_duracion:		; A += (+0A), repetido B veces: multiplicacion de +0A por el nibble de duracion via sumas sucesivas
	add a,(ix+00ah)		;7c9c
	djnz calcula_duracion		;7c9f
nota_final:		; Guarda la duracion calculada en +01, lee y consume el byte de NOTA (avanza el guion con avanza_guion), y separa su nibble alto (octava) del nibble bajo
	ld (ix+001h),a		;7ca1
	ld a,(hl)			;7ca4
	call avanza_guion		;7ca5
	and 0f0h		;7ca8   ; el nibble ALTO del byte de nota, rotado 4 veces a B: es el INDICE dentro de tabla_periodos_nota (0-9 validos), no la octava -la octava de verdad esta en +05, ver arranca_con_forma_elegida y el bucle de abajo-
	rrca			;7caa
	rrca			;7cab
	rrca			;7cac
	rrca			;7cad
	ld b,a			;7cae
	sub 00ch		;7caf   ; resta 12 al indice: si ERA 12 (0x0C) A queda en 0 y ese 0 es lo que se guarda como forma en +07; en cualquier otro valor se descarta A y se usa la forma por defecto de +06 -SUPOSICION: 0x0C parece un codigo de nota especial (silencio o repetir), pero B sigue valiendo 12 para el indice de tabla_periodos_nota de la linea siguiente, fuera de las 10 entradas validas (0-9); no esta comprobado si una partitura real llega a usar ese valor-
	jr z,arranca_con_forma_elegida		;7cb1
	ld a,(ix+006h)		;7cb3
arranca_con_forma_elegida:		; Guarda en +07 el valor que trae A (0 si el indice era 0x0C, la forma por defecto de +06 en cualquier otro caso), dispara duracion/volumen y calcula el periodo final: base de tabla_periodos_nota[B] desplazado a la izquierda tantas veces como octavas hay en +05
	ld (ix+007h),a		;7cb6
	call dispara_duracion_y_volumen		;7cb9
	ld a,b			;7cbc
	ld hl,07ceah		;7cbd
	call suma_a_hl		;7cc0   ; HL = 0x7cea + B (el indice 0-9 de antes): byte base de tabla_periodos_nota para esta nota dentro de la octava
	ld l,(hl)			;7cc3
	ld h,000h		;7cc4
	ld a,(ix+005h)		;7cc6
	or a			;7cc9
	jr z,bit_de_redondeo		;7cca
	ld b,a			;7ccc   ; B = +05 (la octava, guardada por un comando de control anterior): el bucle de abajo dobla el periodo base una vez por octava -periodo mayor = frecuencia menor, asi que mas octavas de +05 significa un tono MAS GRAVE, no mas agudo-
L_7CCD:
	add hl,hl			;7ccd
	djnz L_7CCD		;7cce
bit_de_redondeo:		; si +0B tiene algo guardado, suma 1 al periodo final antes de escribirlo
	ld a,(ix+00bh)		;7cd0
	or a			;7cd3
	jr z,escribe_periodo		;7cd4
	inc hl			;7cd6
escribe_periodo:		; Escribe un periodo de 16 bits en el PSG: el byte alto en el registro de tono fino (C=1/3/5) y el bajo en el registro de tono grueso (C-1=0/2/4)
	ld a,c			;7cd7
	ld e,h			;7cd8
	call 00093h		;7cd9   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,c			;7cdc
	dec a			;7cdd
	ld e,l			;7cde
	jp 00093h		;7cdf   ; BIOS WRTPSG - Writes data to PSG-register
avanza_guion:		; Ayudante de una instruccion: avanza el puntero de guion un byte y lo guarda en +03/+04 (el mismo patron que palabra_de_tabla pero de un solo byte)
	inc hl			;7ce2
	ld (ix+003h),l		;7ce3
	ld (ix+004h),h		;7ce6
	ret			;7ce9

; ----------------------------------------------------------------------
; DATOS tabla_periodos_nota: 10 bytes, periodo base por nota dentro de la
;   octava (0-9), leido byte a byte por L_7cb9 (ld hl,07ceah / L_4010) y
;   desplazado por octava
;   0x7cea..0x7cf4  (10 bytes)
DATA_tabla_periodos_nota:
	defb 06ah,064h,05fh,059h,054h,050h,04bh,047h,043h,03fh	; 7cea  jd_YTPKGC?

; ----------------------------------------------------------------------
; DATOS datos_motor_sonido_7cf4: 771 B: tabla de punteros de 16 bits por nota
;   (indexada nota*2 desde 0x7cf4 por L_7ab0/L_4015) mas las partituras que
;   esos punteros senalan, interpretadas por L_7ba4-L_7ce9; limites internos
;   de cada partitura no decodificados
;   0x7cf4..0x7ff7  (771 bytes)
DATA_datos_motor_sonido_7cf4:
	defb 03ch,038h,03ah,07dh,03ah,07dh,0b3h,07dh,08ch,07dh,098h,07dh,09fh,07dh,03bh,07dh	; 7cf4  <8:}:}.}.}.}.};}
	defb 062h,07dh,078h,07dh,055h,07fh,005h,07eh,05ch,07eh,062h,07fh,07eh,07fh,0dfh,07fh	; 7d04  b}x}U..~\~b.~...
	defb 0ebh,07fh,09ah,07fh,0b0h,07fh,0c8h,07fh,09ah,07eh,09bh,07eh,0b4h,07eh,008h,07fh	; 7d14  .........~.~.~..
	defb 009h,07fh,02eh,07fh,0ceh,07eh,0cfh,07eh,0e6h,07eh,0cfh,07dh,0e1h,07dh,0f3h,07dh	; 7d24  .....~.~.~.}.}.}
	defb 03ah,07dh,03ah,07dh,03ah,07dh,0ffh,0d1h,0fch,003h,003h,0e2h,000h,0c0h,010h,0c0h	; 7d34  :}:}:}..........
	defb 020h,0c0h,020h,0c0h,040h,080h,040h,080h,0ceh,0fdh,000h,0c0h,010h,0c0h,020h,0c0h	; 7d44   . .@.@....... .
	defb 020h,0c0h,040h,080h,040h,080h,0ceh,0d2h,0c6h,0feh,002h,03bh,07dh,0ffh,021h,0e0h	; 7d54   .@.@......;}.!.
	defb 0a0h,0e0h,0c0h,0e0h,0e0h,0d0h,060h,0d0h,080h,0d0h,0a0h,0d0h,020h,0c0h,040h,0c0h	; 7d64  ......`..... .@.
	defb 060h,0c0h,080h,0ffh,022h,0d0h,054h,000h,000h,0d0h,050h,000h,000h,0d0h,047h,0d0h	; 7d74  `...".T...P...G.
	defb 042h,000h,000h,0d0h,038h,0d0h,033h,0ffh,022h,0c1h,052h,0e0h,074h,0c0h,091h,0f0h	; 7d84  B...8.3.".R.t...
	defb 074h,0d0h,075h,0ffh,022h,01ch,01fh,008h,016h,00ch,0ffh,021h,0e0h,078h,0c0h,070h	; 7d94  t.u."......!.x.p
	defb 0c0h,068h,0e0h,063h,0d0h,05ah,0d0h,053h,0b0h,053h,090h,053h,050h,053h,0ffh,026h	; 7da4  .h.c.Z.S.S.SPS.&
	defb 0f6h,094h,0f6h,08fh,0f6h,08fh,0f6h,08ah,0e6h,085h,0e6h,080h,0d6h,07ah,0d6h,075h	; 7db4  .............z.u
	defb 0c6h,070h,0c6h,06ah,0b6h,085h,0a6h,070h,096h,06ah,0ffh,026h,0e1h,080h,0e2h,080h	; 7dc4  .p.j...p.j.&....
	defb 0d2h,000h,0d3h,000h,0c2h,080h,0c3h,080h,0b3h,000h,0b4h,000h,0ffh,026h,0e0h,080h	; 7dd4  .............&..
	defb 0e1h,080h,0d1h,000h,0d2h,000h,0c1h,080h,0c2h,080h,0b2h,000h,0b3h,000h,0ffh,026h	; 7de4  ...............&
	defb 0e1h,000h,0e1h,000h,0d1h,080h,0d2h,080h,0c2h,000h,0c3h,000h,0b2h,080h,0b3h,080h	; 7df4  ................
	defb 0ffh,0d8h,0fch,003h,003h,0e2h,042h,050h,042h,050h,080h,0c0h,090h,0c0h,0b0h,090h	; 7e04  ......BPBP......
	defb 080h,050h,042h,050h,041h,021h,011h,021h,043h,082h,090h,082h,090h,0b0h,0c0h,0e1h	; 7e14  .PBPA!.!C.......
	defb 000h,0c0h,030h,000h,0e2h,0b0h,090h,080h,090h,0b0h,090h,080h,0c0h,050h,0c0h,042h	; 7e24  ..0..........P.B
	defb 050h,041h,0b0h,090h,0b0h,0e1h,000h,030h,040h,030h,0c0h,000h,0c0h,0e2h,0b2h,0e1h	; 7e34  PA.....0@0......
	defb 000h,0e2h,0b1h,0b0h,090h,0b0h,0e1h,000h,030h,040h,060h,040h,030h,000h,0e2h,0b2h	; 7e44  ........0@`@0...
	defb 0e1h,000h,0e2h,0b3h,0feh,0ffh,005h,07eh,0d8h,0fch,003h,003h,0e3h,041h,080h,080h	; 7e54  .......~.....A..
	defb 040h,0c0h,081h,0feh,004h,061h,07eh,051h,090h,090h,050h,0c0h,091h,0feh,002h,06bh	; 7e64  @....a~Q..P....k
	defb 07eh,041h,080h,080h,040h,0c0h,081h,0feh,002h,075h,07eh,031h,090h,090h,0e4h,0b0h	; 7e74  ~A..@....u~1....
	defb 0c0h,0e3h,091h,0feh,003h,07fh,07eh,031h,090h,090h,0e4h,0b0h,0e3h,030h,060h,0b0h	; 7e84  ......~1.....0`.
	defb 0feh,0ffh,05ch,07eh,0feh,0ffh,0e8h,0d6h,0fch,001h,001h,0e1h,001h,011h,041h,051h	; 7e94  ..\~..........AQ
	defb 041h,011h,001h,0e2h,0a1h,0e1h,000h,010h,000h,010h,000h,010h,000h,010h,003h,0ffh	; 7ea4  A...............
	defb 0d6h,0fbh,001h,001h,0e3h,0b1h,0e2h,011h,041h,051h,041h,011h,001h,0e3h,0a1h,0e2h	; 7eb4  ........AQA.....
	defb 000h,010h,000h,010h,000h,010h,000h,010h,003h,0ffh,0e8h,0dah,0fch,002h,002h,0e1h	; 7ec4  ................
	defb 073h,0b3h,0a3h,083h,080h,070h,040h,030h,040h,0c0h,070h,0c0h,0d5h,080h,0a0h,0dah	; 7ed4  s....p@0@.p.....
	defb 083h,0ffh,0dah,0fdh,002h,002h,0e2h,070h,080h,0a0h,0b0h,0e1h,020h,0c0h,0e2h,0b0h	; 7ee4  .......p.... ...
	defb 0c0h,0a0h,0c0h,080h,0c0h,0d5h,0a0h,0b0h,0dah,0a2h,080h,070h,040h,030h,040h,0c0h	; 7ef4  ...........p@0@.
	defb 070h,0c0h,084h,0ffh,0e8h,0d4h,0fch,001h,001h,0e0h,021h,0c1h,0e1h,091h,0c1h,0e0h	; 7f04  p.........!.....
	defb 001h,0e1h,0a1h,091h,0c1h,071h,0a1h,0e0h,011h,0e1h,0a1h,097h,031h,021h,031h,061h	; 7f14  .....q......1!1a
	defb 091h,071h,091h,0a1h,091h,071h,061h,031h,027h,0ffh,0d3h,0fbh,001h,001h,0e1h,0c0h	; 7f24  .q...qa1'.......
	defb 0d4h,021h,0c1h,0e2h,091h,0c1h,0e1h,001h,0e2h,0a1h,091h,0c1h,071h,0a1h,0e1h,011h	; 7f34  .!..........q...
	defb 0e2h,0a1h,097h,031h,021h,031h,061h,091h,071h,091h,0a1h,091h,071h,061h,031h,027h	; 7f44  ...1!1a.q...qa1'
	defb 0ffh,0d4h,0fdh,003h,003h,0e2h,070h,060h,070h,0e1h,070h,060h,071h,0ffh,0d1h,0fch	; 7f54  ......p`p.p`q...
	defb 001h,001h,0e3h,001h,001h,051h,051h,021h,021h,071h,071h,0ceh,051h,051h,091h,091h	; 7f64  .....QQ!!qq.QQ..
	defb 071h,071h,0b1h,0b1h,091h,091h,0e3h,001h,001h,0ffh,0d1h,0fch,001h,001h,0e2h,001h	; 7f74  qq..............
	defb 001h,051h,051h,021h,021h,071h,071h,0cfh,051h,051h,091h,091h,071h,071h,0b1h,0b1h	; 7f84  .QQ!!qq.QQ..qq..
	defb 091h,091h,0e1h,001h,001h,0ffh,0d6h,0fch,003h,003h,0e2h,0b2h,0b0h,0d7h,0b0h,070h	; 7f94  ...............p
	defb 0d8h,090h,0d6h,0b1h,0e1h,020h,020h,041h,000h,040h,07bh,0ffh,0d6h,0fch,003h,003h	; 7fa4  .....  A.@{.....
	defb 0e2h,072h,070h,0d7h,070h,020h,0d8h,050h,0d6h,071h,0b0h,0b0h,0e1h,001h,0e2h,090h	; 7fb4  .rp.p .P.q......
	defb 0e2h,000h,02bh,0ffh,0d6h,0fch,003h,003h,0e2h,022h,020h,0d7h,020h,0e3h,0b0h,0d8h	; 7fc4  ..+......" . ...
	defb 0e2h,020h,0d6h,021h,070h,070h,091h,050h,090h,0bbh,0ffh,0d4h,0fch,003h,003h,0e1h	; 7fd4  . .!pp.P........
	defb 070h,0e0h,040h,070h,040h,070h,0ffh,0d4h,0fch,003h,003h,0e1h,040h,0e0h,000h,040h	; 7fe4  p.@p@p......@..@
	defb 000h,040h,0ffh	; 7ff4

; ----------------------------------------------------------------------
; DATOS marca_konami: La marca oculta de Konami (Manuel Pazos): titulo en
;   katakana al reves, longitud, RC-727 en BCD y 0xAA de cierre. Ninguna
;   instruccion la lee
;   0x7ff7..0x8000  (9 bytes)
DATA_marca_konami:
	defb 095h,08fh,098h,088h,082h,084h,006h,027h,0aah	; 7ff7  .......'.
