# King's Valley (Konami, MSX1) - desensamblado
#
# El orden de las cosas: trazar el flujo -> generar el listado -> comprobar que
# vuelve a dar la ROM byte a byte -> las comprobaciones que el reensamblado NO
# cubre.
#
# La ROM no se distribuye. Hace falta en la raiz como kingsvalley.rom, y
# `make comprueba` verifica el sha256.

ROM      = kingsvalley.rom
SHA      = a8f807a0be90db6a01c43a948215a8761d1d7b92358279d6f2ce2dcfefab5d73
SRC      = src
WORK     = work
ORG      = 0x4000
TITULO   = KING'S VALLEY - Konami - MSX1 - cartucho RC-727 de 16 KB en la pagina 1

all: listado verify sanity test

$(ROM):
	@echo "=================================================================="
	@echo " Falta $(ROM), y este repositorio NO lo distribuye."
	@echo ""
	@echo " Es King's Valley (Konami, RC-727) para MSX, 16384 bytes exactos."
	@echo " Ponlo aqui con ese nombre. Para comprobar que es el mismo:"
	@echo "     shasum -a 256 $(ROM)"
	@echo "     $(SHA)"
	@echo "=================================================================="
	@false

comprueba: $(ROM)
	@echo "$(SHA)  $(ROM)" | shasum -a 256 -c -

# El trazado sigue el flujo desde los puntos de entrada. Los que no se pueden
# deducir estaticamente -ganchos de interrupcion, destinos de saltos
# indirectos- estan declarados en el .entries, cada uno con su justificacion.
$(WORK)/kingsvalley.trace.json: $(ROM) $(SRC)/kingsvalley.entries $(SRC)/kingsvalley.nocode
	@mkdir -p $(WORK)
	python3 tools/z80trace.py $(ROM) $(ORG) $(SRC)/kingsvalley.entries \
	        $(WORK)/kingsvalley $(SRC)/kingsvalley.nocode

trace: $(WORK)/kingsvalley.trace.json

listado: $(WORK)/kingsvalley.trace.json $(SRC)/kingsvalley.notes
	python3 tools/mkasm.py $(ROM) $(ORG) $(WORK)/kingsvalley.trace.json \
	        $(SRC)/kingsvalley.notes work/msx.sym $(SRC)/kingsvalley.asm "$(TITULO)"

# La prueba que decide si el desensamblado es fiable.
verify: $(SRC)/kingsvalley.asm $(ROM)
	@sh tools/verify_build.sh $(SRC)/kingsvalley.asm $(ROM) $(ORG)

# Lo que el reensamblado NO puede cazar: que unos datos se esten leyendo como
# codigo. El binario sale identico igual, porque los bytes no cambian; lo unico
# que cambia es lo que decimos de ellos.
sanity: $(WORK)/kingsvalley.trace.json
	@echo "=================================================================="
	@echo " ningun byte declarado como datos puede salir como codigo"
	@echo "=================================================================="
	@python3 tools/check_trace.py $(WORK)/kingsvalley.trace.json $(SRC)/kingsvalley.nocode
	@python3 tools/check_datos_como_codigo.py $(WORK) $(SRC)
	@echo "=================================================================="
	@echo " ningun punto de entrada puede caer dentro de una zona de datos"
	@echo "=================================================================="
	@python3 tools/check_entradas.py $(SRC)/kingsvalley.entries $(SRC)/kingsvalley.notes \
	        $(SRC)/kingsvalley.nocode
	@echo "=================================================================="
	@echo " ni un byte del cartucho sin asignar"
	@echo "=================================================================="
	@python3 tools/presupuesto.py $(WORK) $(SRC)

densidad:
	@python3 tools/densidad.py $(SRC)/kingsvalley.asm

test:
	@echo "=================================================================="
	@echo " Tests"
	@echo "=================================================================="
	@python3 -m unittest discover -s tests -v

# Dibuja los bloques de datos graficos declarados en el .notes, para MIRARLOS.
imagenes: $(ROM)
	@mkdir -p work/gfx
	python3 tools/dibuja.py $(ROM) $(ORG) $(SRC)/kingsvalley.notes work/gfx

# LA WEB
#
# Bilingue: el ingles en docs/ y el castellano en docs/es/. Las paginas se
# escriben en markdown y se convierten con md2html.py; la portada la monta
# make_web.py, que declara las cifras medidas de ESTE cartucho.
web: $(ROM)
	python3 tools/pantallas.py $(ROM) $(ORG) docs/imagenes
	python3 tools/mapas.py $(ROM) $(ORG) docs/imagenes
	cd tools && python3 figuras.py ../$(ROM) $(ORG) ../docs/imagenes
	python3 tools/md2html.py docs en
	python3 tools/md2html.py docs/es es
	python3 tools/make_web.py docs/imagenes docs/index.html en
	python3 tools/make_web.py docs/imagenes docs/es/index.html es
	python3 tools/check_enlaces.py docs

clean:
	rm -rf $(WORK)/kingsvalley.trace.json $(WORK)/kingsvalley.blocks

.PHONY: all comprueba trace listado verify sanity test densidad imagenes web clean
