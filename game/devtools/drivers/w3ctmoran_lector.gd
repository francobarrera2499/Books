# Driver de capturas W3-CT-MORAN: los documentos de Moran en el lector (W2-READER), sobre data/ real.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctmoran res://devtools/drivers/w3ctmoran_lector.gd
# Capturas (.work/shots/w3ctmoran_<nombre>.png):
#   d09_p1, d09_p2   Pall Mall Gazette, las dos cartas del coronel (ejemplar del BM)
#   d10_p1..p3       Heavy Game of the Western Himalayas (tienda de Crane)
#   d11_p1, d11_p2   Three Months in the Jungle (BM)
#   d16              Daily Graphic del 3 de abril (bandeja, día 8)
#   d17_p1, d17_p2   Kelly's de 1894 (al pie de p1, la edición de 1893) (Crane)
#   d32_p1, d32_p2   libro de llaves del agente (L3, desde el día 7 con la hoja de abril)
#   d39              tratado del binomio (BM)
#   d09_tira         recorte real (GameSim, prólogo) del tramo #desague del recorte de Pell (D09@L1): imprime ents y etiquetas
#   d10_lupa         la lupa sobre «cabrito» en el capítulo VII
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Repo = preload("res://core/data/data_repo.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

var tool
var reader
var sim
var repo

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	repo = Repo.fresh("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
	sim = GameSim.new(repo, 1894)
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = func(a): return sim.apply(a)
	scene.add_child(reader)
	await tool.frames(4)
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).substr(7)
	var plan := [["D09@BM", "d09", 2], ["D10@Crane", "d10", 3], ["D11@BM", "d11", 2], ["D16@Crane", "d16", 1], ["D17@Crane", "d17", 2], ["D32@L3", "d32", 2], ["D39@BM", "d39", 1]]
	for row in plan:
		if only != "" and not String(row[1]).contains(only):
			continue
		var v: Dictionary = ViewModel.from_repo(repo, String(row[0]))
		for i in int(row[2]):
			await _show(v, i, String(row[1]) + ("" if int(row[2]) == 1 else "_p%d" % (i + 1)))
	if only == "" or only == "tira":
		await _clip_tira()
	if only == "" or only == "lupa":
		var v2: Dictionary = ViewModel.from_repo(repo, "D10@Crane")
		reader.open_view(v2)
		await tool.frames(3)
		reader.go_page(1)
		await tool.frames(4)
		pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
		var at := _word_pos(0, "cabrito")
		if at != Vector2.ZERO:
			Input.warp_mouse(at)
			reader.point_at(at)
			await tool.frames(4)
			await tool.snap("d10_lupa")
		pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
		reader.close()
		await tool.frames(2)

func _clip_tira() -> void:
	var v: Dictionary = sim.q_view("D09@L1")
	if v.is_empty():
		print("SIN VISTA D09@L1 (prólogo)")
		return
	var pg := -1
	var blk := -1
	var tr := {}
	for i in (v.get("pages", []) as Array).size():
		for j in (v.pages[i] as Array).size():
			for t in v.pages[i][j].parsed.tramos:
				if String(t.id) == "desague":
					pg = i
					blk = j
					tr = t
	if pg < 0:
		print("SIN TRAMO #desague")
		return
	reader.open_view(v)
	await tool.frames(3)
	reader.go_page(pg)
	await tool.frames(4)
	var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D09@L1", "part": pg, "block": blk}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
	print("CLIP #desague -> ", r)
	if r.get("ok", false):
		var c: Dictionary = Clipper.get_clip(sim.st, String(r.clip))
		print("  tags=", c.get("tags", []), " ents=", c.get("ents", []), " origin=", c.get("origin", ""))
	await tool.frames(2)
	await tool.snap("d09_tira")
	reader.close()
	await tool.frames(2)

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
