# Driver de capturas W3-CT-LISLE: los documentos de Lisle en el lector (W2-READER), sobre data/ real.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctlisle res://devtools/drivers/w3ctlisle_lector.gd
# Capturas (.work/shots/w3ctlisle_<nombre>.png):
#   d21_p1..p5        concordancia (manuscrito, cuaderno; un tomo por hoja), vista de la GameSim real en el prólogo
#   d23_p1..p4        encargo de Pell: minuta a máquina (2 pliegos), hoja del dictado y borrador del aviso, en el prólogo
#   d23_tira          tras recortar el tramo #aviso (acción real clip_text de la GameSim; imprime si indexó el suceso)
#   d38 / d38_p2      la Strand de octubre de 1903 (desde el DataRepo: el ejemplar sólo existe en el epílogo)
#   d38_lupa          la lupa sobre «anteojos de color»
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Repo = preload("res://core/data/data_repo.gd")

var tool
var reader
var sim

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var repo = Repo.fresh("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
	sim = GameSim.new(repo, 1894)
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = func(a): return sim.apply(a)
	scene.add_child(reader)
	await tool.frames(4)
	for i in 5:
		await _show(sim.q_view("D21@L1"), i, "d21_p%d" % (i + 1))
	for i in 4:
		await _show(sim.q_view("D23@L1"), i, "d23_p%d" % (i + 1))
	# recorte real del tramo #aviso (paso 1 del tutorial: «recorte una línea del encargo»)
	var v: Dictionary = sim.q_view("D23@L1")
	var pg: int = -1
	var blk: int = -1
	var tr := {}
	for i in (v.get("pages", []) as Array).size():
		for j in (v.pages[i] as Array).size():
			for t in v.pages[i][j].parsed.tramos:
				if String(t.id) == "aviso":
					pg = i
					blk = j
					tr = t
	if pg >= 0:
		reader.open_view(v)
		await tool.frames(3)
		reader.go_page(pg)
		await tool.frames(4)
		var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pg, "block": blk}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
		print("CLIP #aviso -> ", r)
		print("INDICE suceso_reichenbach: ", sim.q_index().any(func(x): return String(x.id) == "suceso_reichenbach"))
		await tool.frames(2)
		await tool.snap("d23_tira")
	reader.close()
	await tool.frames(2)
	await _show(ViewModel.from_repo(repo, "D38@L1"), 1, "d38_p2")
	await _show(ViewModel.from_repo(repo, "D38@L1"), 0, "d38")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	var at := _word_pos(0, "anteojos")
	if at != Vector2.ZERO:
		var e := InputEventMouseMotion.new()
		e.position = at
		e.global_position = at
		Input.warp_mouse(at)
		reader.point_at(at)
		await tool.frames(4)
		await tool.snap("d38_lupa")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	reader.close()
	await tool.frames(2)
	# Demostración del arreglo propuesto a W1-THEME / W2-READER (sólo en este driver; no toca sus archivos): en Homemade
	# Apple las mayúsculas S, G y R arrancan con un trazo que pisa el espacio anterior («laStrand», «ElGloriaScott») y la
	# «p» a principio de renglón queda cortada por el borde del RichTextLabel («srotector»). Espacio extra en la ranura
	# manuscrito + margen izquierdo en DocHand.
	var ti = tool.root.get_node_or_null("ThemeInstaller")
	if ti != null and ti.theme != null:
		for it in [false, true]:
			for f in [ti.font("manuscrito", it), ti.font_bold("manuscrito", it)]:
				if f is FontVariation:
					f.spacing_space = 5
		var sb := StyleBoxEmpty.new()
		sb.content_margin_left = 6
		ti.theme.set_stylebox("normal", "DocHand", sb)
		for pair in [[3, "d21_p4_fix"], [0, "d21_p1_fix"]]:
			reader.open_view(sim.q_view("D21@L1"))
			await tool.frames(3)
			if pair[0] > 0:
				reader.go_page(pair[0])
			await tool.frames(4)
			for n in reader.find_children("*", "RichTextLabel", true, false):
				if n.theme_type_variation == "DocHand":
					n.add_theme_stylebox_override("normal", sb)
			await tool.frames(4)
			await tool.snap(pair[1])

func _show(v: Dictionary, page: int, name: String) -> void:
	if v.is_empty():
		print("SIN VISTA ", name)
		return
	reader.open_view(v)
	await tool.frames(3)
	if page > 0:
		reader.go_page(page)
	await tool.frames(6)
	await tool.snap(name)

func _word_pos(i: int, w: String) -> Vector2:
	var r: RichTextLabel = reader.block_rtl(i)
	if r == null:
		return Vector2.ZERO
	var plain := r.get_parsed_text()
	var k := plain.find(w)
	if k < 0:
		return Vector2.ZERO
	var line := r.get_character_line(k)
	var lr: Vector2i = r.get_line_range(line)
	var f: Font = r.get_theme_font("normal_font")
	var fs: int = r.get_theme_font_size("normal_font_size")
	var x := f.get_string_size(plain.substr(lr.x, k - lr.x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := r.get_line_offset(line) + r.get_line_height(line) * 0.5
	return r.get_global_transform_with_canvas() * Vector2(x + 30.0, y)
