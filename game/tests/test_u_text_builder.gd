# test_u_text_builder.gd — W2-READER. TextBuilder (§6.4), efectos Remington y versalitas, ViewModel, PageView y
# DocumentReader (sin ventana). Criterio de §10: rtl.get_parsed_text() == parsed.plain para todo documento existente
# (res://data, si ya hay documentos, más los fixtures data_min y reader).
extends "res://tests/test_base.gd"

const TextBuilder = preload("res://ui/reader/text_builder.gd")
const FxRemington = preload("res://ui/reader/fx_remington.gd")
const FxSmallCaps = preload("res://ui/reader/fx_smallcaps.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const PageView = preload("res://ui/reader/page_view.gd")
const Reader = preload("res://ui/reader/document_reader.gd")
const Markup = preload("res://core/text/markup.gd")
const Paper = preload("res://ui/kit/paper.gd")

var holder: Control = null

func before_each() -> void:
	holder = Control.new()
	holder.size = Vector2(1600, 900)
	tree.root.add_child(holder)

func after_each() -> void:
	if holder != null:
		holder.free()
	holder = null
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti != null and ti.high_contrast:
		ti.set_high_contrast(false)

func built(parsed: Dictionary, opts := {}) -> RichTextLabel:
	var r := TextBuilder.make_rtl(String(opts.get("slot", "imprenta")))
	r.size = Vector2(520, 10)
	holder.add_child(r)
	TextBuilder.build(r, parsed, opts)
	return r

func all_repos() -> Array:
	var out: Array = [fixture_repo("data_min"), fixture_repo("reader")]
	var real = repo()
	if not real.docs().is_empty():
		out.push_front(real)
	return out

# ------------------------------------------------------------------ get_parsed_text == plain
func test_parsed_text_equals_plain_every_doc() -> void:
	var n := 0
	for rp in all_repos():
		var ids: Array = rp.docs().keys()
		ids.sort()
		for id in ids:
			var d: Dictionary = rp.doc(id)
			for p in d.get("parts", []):
				var pt: Dictionary = rp.parsed(id, String(p.id))
				for hc in [false, true]:
					var m = d.get("machine")
					var r := built(pt, {"slot": String(d.get("font", "imprenta")), "machine": "" if m == null else String(m), "hc": hc})
					eq(r.get_parsed_text(), String(pt.plain), "%s/%s/%s hc=%s" % [rp.root, id, p.id, hc])
					r.free()
				n += 1
	ok(n >= 8, "se probaron %d partes" % n)

# Documentos runtime (cartas, columna, respuestas): sus plantillas viven en reactions/*.json (rastro[].texto, §4.9) y
# se rellenan con las variables del ancla antes de parsear. El lector los arma con el mismo builder.
func test_parsed_text_equals_plain_runtime_templates() -> void:
	var vars := {"seat": 214, "title": "Journal de Genève, 6 de mayo de 1891", "hour": "10:40", "phrase": "«A pique»",
		"streets": "Strand, Fleet Street", "act_day": "mar. 27", "ch": "kt", "addr": "Holywell Street", "text": "Busca usted testigos."}
	var n := 0
	for rp in [repo(), fixture_repo("data_min")]:
		for r in rp.reactions():
			var meta: Dictionary = r.get("doc", {}) if typeof(r.get("doc")) == TYPE_DICTIONARY else {}
			var m = meta.get("machine")
			var slot := String(meta.get("font", "maquina")) if meta.get("font") != null else "maquina"
			for t in r.get("rastro", []):
				if typeof(t) != TYPE_DICTIONARY or typeof(t.get("texto")) != TYPE_STRING:
					continue
				var pt: Dictionary = rp.parse_text(String(t.texto), vars, "act.1")
				var b := built(pt, {"slot": slot, "machine": "" if m == null else String(m)})
				eq(b.get_parsed_text(), String(pt.plain), "%s/%s/%s" % [rp.root, r.get("id", "?"), t.get("tpl", "?")])
				b.free()
				n += 1
	if n == 0:
		pending_content("ninguna plantilla de rastro con texto (W2-STRUCT)")

func test_parsed_text_equals_plain_synthetic() -> void:
	var names := {"watson": "el doctor Watson", "roca": "la roca"}
	var srcs := [
		"",
		"Una sola línea.",
		"\n\nDos saltos al comienzo y uno al final.\n",
		"<i>Itálica</i> y <b>negrita</b> y <b><i>ambas</i></b>; <sc>Versalitas Mixtas</sc>.",
		"<del>Tachado entero</del>, <ink=azul>azul</ink>, <ink=roja>roja <i>itálica</i></ink>, <ink=tenue>tenue</ink>.",
		"<f=manuscrito><ink=lapiz>nota a lápiz con <i>itálica</i></ink></f> y <f=maquina>a máquina</f>.",
		"{{#t1 a:x e:watson|Lo dijo [[watson]] junto a [[roca|una roca]].}} {{#t2|<rasante>Surco <i>oculto</i>.</rasante>}}",
		"Escapes: \\{ \\} \\[ \\] \\< \\\\ y punto\\. sin corte. Sr. Holmes, n.º 97.",
		"<i></i>Estilo vacío al comienzo<b></b> y al final<i></i>",
		"«Comillas» — raya — ¿pregunta? ¡exclamación! ñandú, pingüino, …",
		"Línea uno\n<i>Línea dos itálica\ncon salto adentro</i>\n<sc>fin final fiel</sc>",
	]
	for src in srcs:
		var pt := Markup.parse(src, {"names": names})
		for slot in ["imprenta", "maquina", "manuscrito"]:
			for mach in ["", "remington_cotter"]:
				var r := built(pt, {"slot": slot, "machine": mach})
				eq(r.get_parsed_text(), String(pt.plain), "[%s] %s %s" % [src.left(30), slot, mach])
				r.free()

func test_rasante_meta_and_material() -> void:
	var mini = fixture_repo("data_min")
	var r := built(mini.parsed("D29b", "p1"), {"slot": "manuscrito"})
	ok(bool(r.get_meta("fe_has_rasante", false)), "D29b tiene rasante")
	r.free()
	var r2 := built(mini.parsed("D05", "p1"), {})
	no(bool(r2.get_meta("fe_has_rasante", false)), "D05 sin rasante")
	r2.free()
	var pv = PageView.new()
	holder.add_child(pv)
	pv.setup(ViewModel.from_repo(mini, "D29b@L4"), 0, {"hc": false})
	ok(pv.has_rasante(), "la hoja de D29b lleva el shader rasante")
	var mat = pv.blocks[0].material
	ok(mat is ShaderMaterial and mat.shader != null and mat.shader.resource_path.ends_with("rasante.gdshader"), "material rasante")
	pv.set_light(Vector2(100, 200), 1.5)
	eq(mat.get_shader_parameter("light_pos"), Vector2(100, 200), "la lámpara sigue al puntero")
	near(float(mat.get_shader_parameter("reach")), PageView.LIGHT_REACH_MM * pv.px_per_mm * 1.5, 0.01, "alcance en mm")
	var pv2 = PageView.new()
	holder.add_child(pv2)
	pv2.setup(ViewModel.from_repo(mini, "D29b@L4"), 0, {"hc": true})
	no(pv2.has_rasante(), "alto contraste: sin shader (texto tenue)")

func test_rasante_shader_compiles() -> void:
	var sh: Shader = load("res://ui/reader/rasante.gdshader")
	ok(sh != null, "carga el shader")
	ok(sh.get_mode() == Shader.MODE_CANVAS_ITEM, "canvas_item")
	var names := []
	for u in sh.get_shader_uniform_list():
		names.append(u.name)
	for k in ["light_pos", "light_height", "reach", "marker"]:
		has(names, k, "uniform")
	eq(TextBuilder.MARKER, Color(0, 1, 0, 1), "marcador = uniform por defecto")
	for ink in Paper.INKS.values() + Paper.HC_INKS.values():
		ok(Color(ink).to_rgba32() != TextBuilder.MARKER.to_rgba32(), "ninguna tinta es el marcador")

# ------------------------------------------------------------------ Remington
func test_remington_installed_only_for_machine() -> void:
	var fx = fixture_repo("reader")
	var r := built(fx.parsed("D25", "p1"), {"slot": "maquina", "machine": "remington_cotter"})
	var found := false
	for e in r.custom_effects:
		if e is FxRemington:
			found = true
	ok(found, "la carta a máquina instala el efecto")
	eq(TextBuilder.remington().bbcode, "remington", "bbcode del efecto")
	var r2 := built(fx.parsed("D27", "p1"), {"slot": "maquina", "machine": ""})
	for e in r2.custom_effects:
		no(e is FxRemington, "el telegrama no es de la Remington")

func test_remington_defects_pure() -> void:
	var s := FxRemington.defect("s".unicode_at(0))
	near(s.dy_em, -0.08, 1e-6, "s alzada 0,08 em")
	near(FxRemington.defect("S".unicode_at(0)).dy_em, -0.08, 1e-6, "S (misma barra)")
	near(FxRemington.defect("t".unicode_at(0)).alpha, 0.65, 1e-6, "t pálida")
	near(FxRemington.defect("e".unicode_at(0)).deg, 3.0, 1e-6, "e girada 3°")
	var x := FxRemington.defect("x".unicode_at(0))
	eq([x.dy_em, x.alpha, x.deg], [0.0, 1.0, 0.0], "x sin defecto")
	for n in [0, 1, 17, 4096, 99999]:
		var a := FxRemington.h01(n, 1)
		eq(a, FxRemington.h01(n, 1), "jitter determinista")
		ok(a >= 0.0 and a <= 1.0, "jitter en [0,1]")
	ne(FxRemington.h01(10, 1), FxRemington.h01(11, 1), "jitter varía con range.x")

# El efecto identifica el carácter real con font_get_char_from_glyph_index (§6.4): con la fuente de la ranura máquina,
# moldeada por el TextServer, cada glifo vuelve a su carácter.
func test_remington_char_from_glyph() -> void:
	var ti = tree.root.get_node("ThemeInstaller")
	var f: Font = ti.font("maquina")
	var ts := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string("setas", f, 20)
	var glyphs: Array = ts.shaped_text_get_glyphs(line.get_rid())
	eq(glyphs.size(), 5, "5 glifos (sin ligaduras)")
	var fx := FxRemington.new()
	var got := ""
	for g in glyphs:
		got += String.chr(fx.char_of(g.font_rid, int(g.index), 20))
	eq(got, "setas", "glifo -> carácter")

func test_smallcaps_info() -> void:
	var ti = tree.root.get_node("ThemeInstaller")
	var f: Font = ti.font("imprenta")
	var ts := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string("aB.", f, 20)
	var glyphs: Array = ts.shaped_text_get_glyphs(line.get_rid())
	var sc := FxSmallCaps.new()
	var ia: Dictionary = sc.info(glyphs[0].font_rid, int(glyphs[0].index), 20)
	ok(not ia.is_empty(), "minúscula -> versalita")
	eq(int(ia.g), ts.font_get_glyph_index(glyphs[0].font_rid, 20, "A".unicode_at(0), 0), "glifo de la mayúscula")
	ok(sc.info(glyphs[1].font_rid, int(glyphs[1].index), 20).is_empty(), "mayúscula queda igual")
	ok(sc.info(glyphs[2].font_rid, int(glyphs[2].index), 20).is_empty(), "signo queda igual")

# ------------------------------------------------------------------ ViewModel
func test_view_model_from_repo() -> void:
	var mini = fixture_repo("data_min")
	var v := ViewModel.from_repo(mini, "D05@BM")
	eq(v.view, "D05@BM", "vista")
	eq(v.paper, "diario_hueso", "papel")
	eq(v.paper_mm, [300.0, 420.0], "medidas")
	eq(v.font, "imprenta", "ranura")
	eq(v.machine, "", "sin máquina")
	eq(v.pages.size(), 1, "una hoja")
	eq(v.pages[0][0].doc, "D05", "doc del bloque")
	eq(v.pages[0][0].parsed.plain, mini.parsed("D05", "p1").plain, "parsed")
	ok(String(v.src_line).contains("prensa extranjera"), "línea de fuente con el tipo")
	eq(ViewModel.from_repo(mini, "D03").pages.size(), 2, "D03 por id: dos hojas")
	ok(ViewModel.from_repo(mini, "NADA@X").is_empty(), "ejemplar inexistente")
	ok(ViewModel.from_repo(mini, "D99").is_empty(), "doc inexistente")
	var n := ViewModel.normalize({"pages": [[{"parsed": {"plain": "x"}}], {"blocks": [{"parsed": {"plain": "y"}}, "basura"]}]})
	eq(n.paper, "carta", "papel por defecto")
	eq(n.paper_mm, [178.0, 229.0], "medidas por defecto")
	eq(n.pages.size(), 2, "hojas normalizadas")
	eq(n.pages[1].size(), 1, "bloques inválidos descartados")

func test_fixture_reader_is_valid() -> void:
	var fx = fixture_repo("reader")
	eq(fx.errors(), [], "fixture del lector sin errores de esquema")
	eq(fx.docs().size(), 3, "carta, telegrama y Times")

# ------------------------------------------------------------------ PageView
func test_page_view_geometry_and_fit() -> void:
	for pair in [["data_min", "D05@BM"], ["data_min", "D02@L1"], ["reader", "D25@L1"], ["reader", "D27@L1"], ["reader", "D15.0327@L1"]]:
		var v := ViewModel.from_repo(fixture_repo(pair[0]), pair[1])
		var pv = PageView.new()
		holder.add_child(pv)
		pv.setup(v, 0)
		var p: float = pv.px_per_mm
		ok(p >= PageView.P_MIN and p <= PageView.P_MAX, "%s px/mm %.2f en rango" % [pair[1], p])
		no(pv.overflow, "%s: el texto cabe en el papel" % pair[1])
		near(pv.size.x, float(v.paper_mm[0]) * p, 0.01, "%s ancho = mm × px/mm" % pair[1])
		near(pv.size.y, float(v.paper_mm[1]) * p, 0.01, "%s alto = mm × px/mm" % pair[1])
		var cr: Rect2 = pv.content_rect_px()
		for b in pv.blocks:
			var r: RichTextLabel = b
			ok(r.position.x >= cr.position.x - 0.5 and r.position.x + r.size.x <= cr.end.x + 0.5, "%s bloque dentro del margen" % pair[1])
			ok(r.position.y + r.size.y <= cr.end.y + 1.0, "%s bloque dentro del alto" % pair[1])
		# misma px_per_mm forzada (lupa): mismos cortes de línea
		var pv2 = PageView.new()
		holder.add_child(pv2)
		pv2.setup(v, 0, {"px_per_mm": p, "interactive": false})
		eq(pv2.blocks[0].get_line_count(), pv.blocks[0].get_line_count(), "%s copia con las mismas líneas" % pair[1])
		eq(pv2.blocks[0].mouse_filter, Control.MOUSE_FILTER_IGNORE, "copia no interactiva")
		pv.free()
		pv2.free()

func test_page_view_text_scale_scales_page() -> void:
	var ti = tree.root.get_node("ThemeInstaller")
	var v := ViewModel.from_repo(fixture_repo("reader"), "D25@L1")
	var pv = PageView.new()
	holder.add_child(pv)
	pv.setup(v, 0)
	var p1: float = pv.px_per_mm
	var l1: int = pv.blocks[0].get_line_count()
	ti.set_text_scale(1.3)
	var pv2 = PageView.new()
	holder.add_child(pv2)
	pv2.setup(v, 0)
	ti.set_text_scale(1.0)
	ok(pv2.px_per_mm > p1 * 1.2, "con letra 1,3× la hoja crece (%.2f -> %.2f)" % [p1, pv2.px_per_mm])
	ok(absi(pv2.blocks[0].get_line_count() - l1) <= 1, "y conserva la medida de línea")

func test_tijera_toggles_selection() -> void:
	var pv = PageView.new()
	holder.add_child(pv)
	pv.setup(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"), 0)
	var r: RichTextLabel = pv.blocks[0]
	no(r.selection_enabled, "sin tijera no se selecciona")
	pv.set_tijera(true)
	ok(r.selection_enabled, "con tijera sí")
	no(r.drag_and_drop_selection_enabled, "sin DnD de selección")
	no(r.context_menu_enabled, "sin menú")
	no(r.shortcut_keys_enabled, "sin atajos")
	no(r.threaded, "sin hilo")
	no(r.bbcode_enabled, "sin BBCode")
	pv.set_tijera(false)
	no(r.selection_enabled, "se apaga")

# ------------------------------------------------------------------ DocumentReader (sin ventana)
func test_reader_open_zoom_pages_close() -> void:
	var rd = Reader.new()
	rd.sounds = false
	tree.root.add_child(rd)
	var closed := [0]
	rd.closed.connect(func(): closed[0] += 1)
	ok(rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D03@BM")), "abre")
	var st: Dictionary = rd.debug_state()
	eq(st.pages, 2, "dos hojas")
	eq(st.page, 0, "hoja 1")
	eq(rd.layer, 30, "capa 30")
	rd.set_zoom(9.0)
	near(rd.zoom, 3.0, 1e-6, "zoom máximo 300 %")
	rd.set_zoom(0.1)
	near(rd.zoom, 0.8, 1e-6, "zoom mínimo 80 %")
	var p0: float = rd.px_per_mm
	rd.go_page(1)
	eq(rd.page_idx, 1, "pasa de hoja")
	near(rd.px_per_mm, p0, 1e-6, "las hojas de una vista comparten px/mm")
	rd.go_page(5)
	eq(rd.page_idx, 1, "no pasa de la última")
	rd.set_regla(true)
	ok(rd.regla, "regla")
	rd.set_lupa(true)
	ok(rd.lupa, "lupa")
	rd.set_tijera(true)
	ok(rd.page.blocks[0].selection_enabled, "tijera llega a la hoja")
	rd.close()
	eq(closed[0], 1, "closed")
	no(rd.visible, "oculto")
	rd.free()

func test_reader_rebuilds_on_high_contrast() -> void:
	var ti = tree.root.get_node("ThemeInstaller")
	var rd = Reader.new()
	rd.sounds = false
	tree.root.add_child(rd)
	rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D29b@L4"))
	ok(rd.page.has_rasante(), "rasante con shader")
	ti.set_high_contrast(true)
	no(rd.page.has_rasante(), "alto contraste: la hoja se rearmó sin shader")
	eq(rd.page.blocks[0].get_parsed_text(), fixture_repo("data_min").parsed("D29b", "p1").plain, "mismo texto")
	ti.set_high_contrast(false)
	ok(rd.page.has_rasante(), "vuelve el shader")
	rd.free()

func test_reader_measure_offer() -> void:
	var rd = Reader.new()
	rd.sounds = false
	var acts: Array = []
	rd.act_fn = func(a): acts.append(a); return {"ok": true, "clip": "RC0009", "text": "Mide 219 por 178 milímetros."}
	tree.root.add_child(rd)
	rd.open_view(ViewModel.from_repo(fixture_repo("reader"), "D25@L1"))
	ok(rd.debug_state().measure, "la carta tiene measure")
	rd.set_regla(true)
	rd._do_measure()
	eq(acts.size(), 1, "una acción")
	eq(acts[0], {"t": "clip_measure", "src": {"kind": "doc", "ref": "D25@L1"}}, "clip_measure del ejemplar")
	rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM"))
	no(rd.debug_state().measure, "D05 sin measure: no se ofrece (§6.4)")
	rd.free()

func test_reader_plate_only_view() -> void:
	var rd = Reader.new()
	rd.sounds = false
	tree.root.add_child(rd)
	var got := [""]
	rd.plate_requested.connect(func(p): got[0] = p)
	ok(rd.open_view({"view": "D07@Crane", "title": "Fotografía", "plate": "RB.foto", "pages": []}), "una lámina se acepta")
	eq(got[0], "RB.foto", "pide la lámina 3D en vez de texto")
	no(rd.visible, "no muestra hoja")
	no(rd.open_view({"view": "X", "pages": []}), "vista vacía sin lámina: no abre")
	rd.free()

# Una apertura fallida no pisa la hoja que se está leyendo; una lámina reemplaza (cierra) la hoja abierta.
func test_reader_failed_open_keeps_page_and_plate_closes() -> void:
	var rd = Reader.new()
	rd.sounds = false
	tree.root.add_child(rd)
	ok(rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM")), "abre D05")
	no(rd.open_view({"view": "X", "pages": []}), "vista vacía: no abre")
	eq(rd.view.view, "D05@BM", "sigue la vista anterior (los recortes no van a un ref vacío)")
	ok(rd.visible and rd.page != null, "sigue la hoja")
	no(rd.open("NADA@X"), "ejemplar inexistente: no abre")
	eq(rd.view.view, "D05@BM", "sigue la vista anterior tras open() fallido")
	var closed := [0]
	var got := [""]
	rd.closed.connect(func(): closed[0] += 1)
	rd.plate_requested.connect(func(p): got[0] = p)
	ok(rd.open_view({"view": "D07@Crane", "title": "Fotografía", "plate": "RB.foto", "pages": []}), "lámina")
	eq(got[0], "RB.foto", "pide la lámina")
	eq(closed[0], 1, "la hoja abierta se cierra")
	no(rd.visible, "no queda una hoja vieja a la vista")
	rd.free()

# Abierto antes de entrar al árbol (Shell puede armarlo así): al entrar, la ficha y los útiles se ubican en pantalla.
func test_reader_open_before_tree_lays_out() -> void:
	var rd = Reader.new()
	rd.sounds = false
	ok(rd.open_view(ViewModel.from_repo(fixture_repo("data_min"), "D05@BM")), "abre fuera del árbol")
	tree.root.add_child(rd)
	await tree.process_frame
	await tree.process_frame
	var vp: Vector2 = tree.root.get_visible_rect().size
	ok(rd._tools.position.x > vp.x * 0.5, "útiles a la derecha (x=%.0f)" % rd._tools.position.x)
	ok(rd.visible, "visible")
	rd.free()

func test_ruler_last_number_fits() -> void:
	var Ruler = load("res://ui/reader/ruler.gd")
	var r = Ruler.new()
	holder.add_child(r)
	r.setup(3.0, Vector2(178, 219), false)
	var span_mm: float = r.length_mm - Ruler.LEAD_MM - Ruler.TAIL_MM
	ok(fmod(span_mm, 10.0) == 0.0 and span_mm >= 178.0 + 10.0, "marcas hasta un cm entero más allá del papel")
	ok(r.size.x >= (span_mm + Ruler.LEAD_MM + 3.0) * 3.0, "queda cola para el último número")
	r.free()
