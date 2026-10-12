# T21 — fuentes (ARCHITECTURE §9.2, §6.2; GDD§14.3). Dueño: W1-THEME.
# 1) lint: la clase de fuente del sistema no aparece en ningún archivo de texto de res:// (la aguja se arma por concatenación);
# 2) runtime: allow_system_fallback == false (y sin fallbacks ni fuente del sistema) en ThemeDB.fallback_font, en toda
#    fuente del tema por defecto y en las 4 ranuras (regular/itálica/negrita);
# 3) cobertura: todo carácter de data/**/*.json (valores de texto; se omiten claves "_…") existe en cada ranura;
#    glifos prohibidos † ‡ ⅓ ℔ fallan siempre;
# 4) set_slot("maquina", "embedded") reinstala sin errores y se restaura (volver al archivo recupera su itálica); escala
#    (alcanza todo tamaño del tema por defecto), alto contraste, variaciones, papeles, kit; negritas rasterizadas a ≥3×.
extends "res://tests/test_base.gd"

const SLOTS := ["imprenta", "maquina", "manuscrito", "ui"]
const FORBIDDEN := [0x2020, 0x2021, 0x2153, 0x2114]   # † ‡ ⅓ ℔
const TEXT_EXT := ["gd", "tscn", "tres", "json", "cfg", "godot", "gdshader", "import", "txt", "md", "jsonl"]
const EXPECT_FAMILY := {"imprenta": "IM FELL English", "maquina": "Special Elite", "manuscrito": "Homemade Apple", "ui": "IM FELL English"}

var _own_ti: Node = null

func _ti() -> Node:
	var ti: Node = null
	if tree != null and tree.root != null:
		ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti == null:
		if _own_ti == null:
			_own_ti = load("res://autoload/theme_installer.gd").new()
			_own_ti.install()
		ti = _own_ti
	return ti

func after_each() -> void:
	var ti := _ti()
	if ti.text_scale != 1.0:
		ti.set_text_scale(1.0)
	if ti.high_contrast:
		ti.set_high_contrast(false)
	if _own_ti != null:
		_own_ti.free()
		_own_ti = null

func _walk_files(dir: String, exts: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = false
	for f in d.get_files():
		if exts.has(f.get_extension().to_lower()):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		_walk_files(dir.path_join(sub), exts, out)

func _chain_problems(f: Font, where: String) -> Array:
	var probs := []
	var needle := "System" + "Font"
	var cur: Font = f
	var guard := 0
	if f == null:
		return [where + ": fuente nula"]
	while cur != null and guard < 8:
		if cur.get_class() == needle:
			probs.append(where + ": es fuente del sistema")
			return probs
		if cur.fallbacks.size() > 0:
			probs.append(where + ": tiene fallbacks")
		if cur is FontFile:
			if (cur as FontFile).allow_system_fallback:
				probs.append(where + ": allow_system_fallback == true")
			if (cur as FontFile).data.size() == 0:
				probs.append(where + ": FontFile sin datos")
			return probs
		if cur is FontVariation:
			cur = (cur as FontVariation).base_font
		else:
			probs.append(where + ": clase inesperada " + cur.get_class())
			return probs
		guard += 1
	probs.append(where + ": sin FontFile raíz")
	return probs

# ------------------------------------------------------------------ 1) lint
func test_lint_no_system_font_in_sources():
	var needle := "System" + "Font"
	var files := []
	_walk_files("res://", TEXT_EXT, files)
	ok(files.size() > 5, "pocos archivos escaneados: %d" % files.size())
	for p in files:
		var s := FileAccess.get_file_as_string(p)
		if s.contains(needle):
			fail("%s contiene la clase de fuente del sistema" % p)

# ------------------------------------------------------------------ 2) runtime
func test_runtime_no_system_fallback():
	var ti := _ti()
	var probs := []
	probs.append_array(_chain_problems(ThemeDB.fallback_font, "ThemeDB.fallback_font"))
	var dt := ThemeDB.get_default_theme()
	probs.append_array(_chain_problems(dt.default_font, "default_theme.default_font"))
	var n := 0
	for ty in dt.get_font_type_list():
		for name in dt.get_font_list(ty):
			probs.append_array(_chain_problems(dt.get_font(name, ty), "default_theme %s/%s" % [ty, name]))
			n += 1
	ok(n >= 20, "el tema por defecto debería tener ≥20 fuentes, tiene %d" % n)
	for s in SLOTS:
		for it in [false, true]:
			probs.append_array(_chain_problems(ti.font(s, it), "ranura %s it=%s" % [s, it]))
			probs.append_array(_chain_problems(ti.font_bold(s, it), "ranura %s bold it=%s" % [s, it]))
	for p in probs:
		fail(p)
	ok(ti.is_ours(ThemeDB.fallback_font), "fallback_font no es del ThemeInstaller")
	ok(ThemeDB.fallback_font_size == ti.px("ui"), "fallback_font_size")

func test_slots_match_fonts_json():
	var ti := _ti()
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/fonts.json"))
	ok(cfg is Dictionary and cfg.get("slots") is Dictionary, "fonts.json inválido")
	if not (cfg is Dictionary):
		return
	for s in SLOTS:
		ok(cfg["slots"].has(s), "fonts.json sin ranura " + s)
		var e: Dictionary = cfg["slots"][s]
		var path := str(e["file"])
		ok(path == "embedded" or FileAccess.file_exists(path), "no existe " + path)
		var rf: FontFile = ti.root_file(ti.font(s))
		ok(rf != null, "sin FontFile en " + s)
		if rf == null:
			continue
		eq(rf.get_meta("fe_src", ""), path, "fuente de la ranura " + s)
		if path != "embedded":
			eq(rf.get_font_name(), EXPECT_FAMILY[s], "familia de " + s)
		ok(rf.multichannel_signed_distance_field, "MSDF en " + s)
		var rb: FontFile = ti.root_file(ti.font_bold(s))
		ok(rb != null and bool(rb.get_meta("fe_raster", false)) and not rb.multichannel_signed_distance_field, "negrita de " + s + " sobre copia sin MSDF")
		ok(rb != null and rb.oversampling >= 3.0, "negrita de " + s + " rasterizada a ≥3× (zoom del lector hasta 300 %)")
		if rb != null:
			eq(rb.get_meta("fe_src", ""), rf.get_meta("fe_src", ""), "negrita de " + s + " usa el mismo archivo")
			eq(rb.data.size(), rf.data.size(), "negrita de " + s + " mismos datos")
		if e.has("italic"):
			var ri: FontFile = ti.root_file(ti.font(s, true))
			eq(ri.get_meta("fe_src", ""), str(e["italic"]), "itálica de " + s)
			eq(ti.font(s, true).variation_transform, Transform2D.IDENTITY, "itálica con archivo no se inclina")
		else:
			ok(ti.font(s, true).variation_transform.x.y > 0.15, "itálica sintética inclinada en " + s)
	var liga := TextServerManager.get_primary_interface().name_to_tag("liga")
	eq(ti.font("maquina").opentype_features.get(liga, -1), 0, "máquina sin ligaduras")
	ok(absf(ti.font_bold("imprenta").variation_embolden - 0.6) < 0.001, "negrita = embolden 0,6")

# ------------------------------------------------------------------ 3) cobertura de glifos
func _collect(v, file: String, chars: Dictionary) -> void:
	if v is String:
		for i in v.length():
			var c: int = v.unicode_at(i)
			if c < 32:
				continue
			if not chars.has(c):
				chars[c] = file
	elif v is Array:
		for x in v:
			_collect(x, file, chars)
	elif v is Dictionary:
		for k in v.keys():
			if str(k).begins_with("_"):
				continue
			_collect(v[k], file, chars)

func test_glyph_coverage_data_json():
	var ti := _ti()
	var files := []
	_walk_files("res://data", ["json"], files)
	ok(files.size() >= 1, "no hay data/**/*.json")
	var chars := {}
	for p in files:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed == null:
			continue   # JSON inválido: lo reporta test_u_schema/DataRepo, no T21
		_collect(parsed, p, chars)
	var codes := chars.keys()
	codes.sort()
	for c in codes:
		if FORBIDDEN.has(c):
			fail("glifo prohibido %s (U+%04X) en %s" % [char(c), c, chars[c]])
			continue
		for s in SLOTS:
			for it in [false, true]:
				if not ti.font(s, it).has_char(c):
					fail("ranura %s%s sin glifo %s (U+%04X), usado en %s" % [s, " itálica" if it else "", char(c), c, chars[c]])

func test_spanish_typography_covered():
	# lo que la guía de redacción exige (§4.2): «» “” — ñ ¿¡ tildes, más ‘’ … £ ½
	var ti := _ti()
	var sample := "«»“”‘’—–…¿¡ñÑáéíóúÁÉÍÓÚüÜ£½ºª"
	for s in SLOTS:
		for i in sample.length():
			ok(ti.font(s).has_char(sample.unicode_at(i)), "ranura %s sin %s" % [s, sample[i]])

# ------------------------------------------------------------------ 4) reinstalación, escala, contraste
func test_set_slot_embedded_and_restore():
	var ti := _ti()
	ok(ti.embedded_size() > 1000, "no se capturó la fuente embebida")
	var hits := [0]
	var cb := func(): hits[0] += 1
	ti.theme_changed.connect(cb)
	ti.set_slot("maquina", "embedded")
	var rf: FontFile = ti.root_file(ti.font("maquina"))
	eq(rf.get_meta("fe_src", ""), "embedded", "máquina embebida")
	eq(rf.data.size(), ti.embedded_size(), "bytes de la embebida")
	ok(not rf.allow_system_fallback, "embebida sin fallback del sistema")
	ok(rf.has_char("ñ".unicode_at(0)), "embebida tiene ñ")
	var dt := ThemeDB.get_default_theme()
	eq(ti.root_file(dt.get_font("normal_font", "DocTyped")), rf, "DocTyped usa la máquina embebida")
	for p in _chain_problems(dt.get_font("mono_font", "DocBody"), "DocBody mono tras set_slot"):
		fail(p)
	ti.set_slot("nada", "embedded")   # ranura desconocida: aviso, sin efecto
	ti.reload_config()
	eq(ti.root_file(ti.font("maquina")).get_font_name(), "Special Elite", "restaurada")
	ok(hits[0] >= 2, "theme_changed emitido en set_slot y reload")
	ti.theme_changed.disconnect(cb)

func test_text_scale_and_px():
	var ti := _ti()
	for k in ["doc", "ui", "small", "title", "caption"]:
		ok(ti.px(k) >= 12, "px(%s) legible" % k)
	var base: int = ti.px("doc")
	ti.set_text_scale(1.5)
	eq(ti.px("doc"), int(round(base * 1.5)), "px escala")
	eq(ThemeDB.get_default_theme().get_font_size("normal_font_size", "DocBody"), ti.px("doc"), "tema reescalado")
	ti.set_text_scale(3.0)
	eq(ti.text_scale, 1.6, "tope 1,6")
	ti.set_text_scale(0.1)
	eq(ti.text_scale, 0.8, "piso 0,8")
	ti.set_text_scale(1.0)
	eq(ti.px("doc"), base, "vuelve")

func test_text_scale_reaches_every_font_size():
	# todo tamaño de fuente del tema por defecto (también los fijos de Godot: Header*, FoldableContainer…) sigue la escala
	var ti := _ti()
	var dt := ThemeDB.get_default_theme()
	var before := {}
	for ty in dt.get_font_size_type_list():
		for n in dt.get_font_size_list(ty):
			before["%s/%s" % [ty, n]] = dt.get_font_size(n, ty)
	ok(before.size() >= 20, "pocos tamaños en el tema por defecto: %d" % before.size())
	ti.set_text_scale(1.5)
	for k in before:
		var p: PackedStringArray = k.split("/")
		var now := dt.get_font_size(p[1], p[0])
		ok(now >= int(round(before[k] * 1.5)) - 1, "%s no sigue text_scale: %d → %d" % [k, before[k], now])
	ok(dt.default_font_size == ti.px("ui"), "default_font_size escalado")
	ti.set_text_scale(1.0)

func test_set_slot_back_to_file_keeps_its_italic():
	var ti := _ti()
	var cfg: Dictionary = ti.slot_paths()
	var imp: Dictionary = cfg.get("imprenta", {})
	if not imp.has("italic"):
		skip("fonts.json sin itálica propia para imprenta")
		return
	ti.set_slot("imprenta", "embedded")
	ok(ti.font("imprenta", true).variation_transform.x.y > 0.15, "embebida: itálica sintética")
	ti.set_slot("imprenta", str(imp["file"]))
	var ri: FontFile = ti.root_file(ti.font("imprenta", true))
	eq(ri.get_meta("fe_src", ""), str(imp["italic"]), "al volver al archivo de fonts.json recupera su itálica")
	eq(ti.font("imprenta", true).variation_transform, Transform2D.IDENTITY, "itálica propia sin inclinar")
	ti.reload_config()

func test_high_contrast_palette():
	var ti := _ti()
	var Paper = load("res://ui/kit/paper.gd")
	ti.set_high_contrast(true)
	var dt := ThemeDB.get_default_theme()
	eq(dt.get_color("font_color", "Label"), Color("000000"), "tinta negra en alto contraste")
	eq(Paper.paper("telegrama", 1), Color("ffffff"), "papel blanco")
	eq(Paper.ink("negra", 1), Color("000000"), "negra #000")
	ti.set_high_contrast(false)
	eq(dt.get_color("font_color", "Label"), Color("1b1712"), "tinta negra normal")

func test_type_variations_present():
	var TB = load("res://ui/kit/theme_builder.gd")
	var dt := ThemeDB.get_default_theme()
	for v in TB.REQUIRED:
		eq(String(dt.get_type_variation_base(v)), TB.VARIATIONS[v], "variación " + v)
	for v in TB.VARIATIONS.keys():
		ok(String(dt.get_type_variation_base(v)) != "", "variación extra " + v)

func test_paper_and_ink_hex():
	var Paper = load("res://ui/kit/paper.gd")
	var want := {"diario_hueso": "ece3cf", "strand": "f0e8d6", "diogenes_recortado": "f3ead6", "telegrama": "e6d3b0",
		"carta": "f1ead9", "registro": "e9e2d0", "libro_mayor": "efe6d2", "cuaderno": "f2ecdc"}
	for k in want:
		eq(Paper.paper(k, 0).to_html(false), want[k], "papel " + k)
	var inks := {"negra": "1b1712", "lapiz": "4a4a4a", "azul": "2b4a8a", "roja": "8a2b22", "tenue": "8c8270"}
	for k in inks:
		eq(Paper.ink(k, 0).to_html(false), inks[k], "tinta " + k)

func test_kit_widgets_build():
	_ti()
	var W = load("res://ui/kit/widgets.gd")
	var box := VBoxContainer.new()
	var nodes := [W.heading("Título"), W.doc_title("D05"), W.source_line("— fuente"), W.caption("epígrafe"),
		W.small("x"), W.marginal("Falta un según."), W.subtitle("campanas"), W.rich("DocBody", "«Hola» — ñ ¿¡"),
		W.rich("DocTyped", "STOP"), W.rich("DocHand", "querido"), W.button("Enviar"), W.ink_button("Mostrar"),
		W.ink_tab("Recortes"), W.paper_panel("telegrama"), W.sheet("libro_mayor", {"ruled": true, "margin_line": 40}),
		W.chip("Watson", {"kind": "ent", "id": "watson"}), W.slot_segun(null, "según"), W.blank("Quién"),
		W.stamp("Visto"), W.stamp("Recibido", "negra"), W.rule(), W.confirm("Texto final.", "Enviar", "Volver")]
	for n in nodes:
		ok(n is Control, "widget no es Control")
		box.add_child(n)
	eq(nodes[15].get_meta("data"), {"kind": "ent", "id": "watson"}, "chip lleva datos de arrastre")
	ok(nodes[16].get_meta("slot") is PanelContainer, "slot_segun expone la ranura")
	ok(nodes[18].get_meta("label") is Label, "stamp expone su Label")
	eq(nodes[18].get_meta("label").rotation_degrees, -6.0, "sello inclinado")
	var got := [null]
	nodes[21].decided.connect(func(v): got[0] = v)
	nodes[21].ok_button.pressed.emit()
	nodes[21].back_button.pressed.emit()
	eq(got[0], true, "confirm decide una sola vez")
	if tree != null and tree.root != null:
		tree.root.add_child(box)
		await tree.process_frame
		ok(box.get_combined_minimum_size().y > 100, "el kit tiene tamaño")
		var tw = W.fade(nodes[0], 0.0, 2.0)
		ok(tw is Tween, "fade devuelve Tween")
		tw.kill()
	box.free()
