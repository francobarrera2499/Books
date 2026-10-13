# Driver de capturas W3-CT-REICH: los documentos del Reichenbach en el lector (W2-READER), sobre data/ real.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctreich res://devtools/drivers/w3ctreich_lector.gd [--only=<nombre>]
# Capturas (.work/shots/w3ctreich_<nombre>.png):
#   d03_p1..p6   «El problema final» impreso (Crane)
#   d02          galerada de Lisle (buhardilla)          d04   pruebas americanas canceladas (Crane)
#   d05          Journal de Genève (BM)                  d06   The Times, despacho de Reuter (BM)
#   d07          fotografía-recuerdo, epígrafe (Crane)   d08   guía de Suiza (BM)
#   d29a, d29b, d29c   papeles de Watson (L4)            d29b_lupa   la lupa (luz rasante) sobre los surcos
#   d02_tira     recorte real (GameSim, prólogo) del tramo #clausula de la galerada (D02@L1): imprime ents y etiquetas
# Imprime por hoja el llenado del papel y el alto justo (paper_mm[1]) para que el texto ocupe la hoja.
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
	var plan := [["D03@Crane", "d03", 6], ["D02@L1", "d02", 1], ["D04@Crane", "d04", 1], ["D05@BM", "d05", 1], ["D06@BM", "d06", 1],
		["D07@Crane", "d07", 1], ["D08@BM", "d08", 1], ["D29a@L4", "d29a", 1], ["D29b@L4", "d29b", 1], ["D29c@L4", "d29c", 1]]
	for row in plan:
		if only != "" and not Array(only.split(",")).any(func(o): return String(row[1]).contains(o)):
			continue
		var v: Dictionary = ViewModel.from_repo(repo, String(row[0]))
		for i in int(row[2]):
			await _show(v, i, String(row[1]) + ("" if int(row[2]) == 1 else "_p%d" % (i + 1)))
	if only == "" or Array(only.split(",")).has("lupa"):
		var v2: Dictionary = ViewModel.from_repo(repo, "D29b@L4")
		reader.open_view(v2)
		await tool.frames(4)
		reader.set_lupa(true)
		var at := _word_pos(0, "Mycroft")
		if at != Vector2.ZERO:
			Input.warp_mouse(at)
			reader.point_at(at)
			await tool.frames(4)
			await tool.snap("d29b_lupa")
		reader.set_lupa(false)
		reader.close()
		await tool.frames(2)
	if only == "" or Array(only.split(",")).has("tira"):
		await _clip_tira("D02@L1", "clausula", "d02_tira")

func _clip_tira(view_id: String, tid: String, name: String) -> void:
	var v: Dictionary = ViewModel.from_repo(repo, view_id)
	var pg := -1
	var blk := -1
	var tr := {}
	for i in (v.get("pages", []) as Array).size():
		for j in (v.pages[i] as Array).size():
			for t in v.pages[i][j].parsed.tramos:
				if String(t.id) == tid:
					pg = i
					blk = j
					tr = t
	if pg < 0:
		print("SIN TRAMO #", tid)
		return
	reader.open_view(v)
	await tool.frames(3)
	reader.go_page(pg)
	await tool.frames(4)
	var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view_id, "part": pg, "block": blk}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
	print("CLIP #%s -> %s" % [tid, str(r)])
	if r.get("ok", false):
		var c: Dictionary = Clipper.get_clip(sim.st, String(r.clip))
		print("  tags=", c.get("tags", []), " ents=", c.get("ents", []), " origin=", c.get("origin", ""))
	await tool.frames(2)
	await tool.snap(name)
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
	var pv = reader.page
	if pv != null:
		# alto de papel que llenaría la hoja: contenido + 2 márgenes (page_view.margins_mm)
		var cmm: float = pv.content_height() / pv.px_per_mm
		var fit_y: float = cmm + 20.0 if cmm + 20.0 < 133.0 else cmm / 0.85
		print("HOJA %s paper_mm=%s contenido=%.0f mm llenado=%.0f%% overflow=%s alto_justo=%.0f mm" % [name, str(v.paper_mm), cmm, 100.0 * cmm / maxf(1.0, pv.margins_mm().size.y), str(pv.overflow), fit_y])
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
