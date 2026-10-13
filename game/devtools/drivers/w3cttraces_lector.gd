# Driver de capturas W3-CT-TRACES: mis documentos en el lector (W2-READER), sobre data/ real (ViewModel.from_repo).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3cttraces res://devtools/drivers/w3cttraces_lector.gd [--only=d13,d31,lupa]
# Capturas (.work/shots/w3cttraces_<nombre>.png): una por página de D12, D13, D14, D18, D19, D20, D22, D30, D31, D33,
# D34, D35 y D45, y «d30_lupa» (la «s» alzada de la Remington bajo la lupa en el libro de recibos).
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Repo = preload("res://core/data/data_repo.gd")

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
	var plan := [["D12@BM", "d12"], ["D13@BM", "d13"], ["D14@BM", "d14"], ["D18@L6", "d18"], ["D19@BM", "d19"],
		["D20@BM", "d20"], ["D22@BM", "d22"], ["D30@L3", "d30"], ["D31@L5", "d31"], ["D33@Crane", "d33"],
		["D34@BM", "d34"], ["D35@BM", "d35"], ["D45@BM", "d45"]]
	for row in plan:
		if only != "" and not only.split(",").has(String(row[1])):
			continue
		var v: Dictionary = ViewModel.from_repo(repo, String(row[0]))
		if String(row[0]) == "D31@L5":
			# from_repo trae todas las versiones de la hoja en curso: se muestra la de la tarde del 9 (p1 + p1b + p2f)
			v.pages = (v.pages as Array).filter(func(pg): return ["p1", "p1b", "p2f"].has(String(pg[0].get("part", ""))))
		var n: int = (v.get("pages", []) as Array).size()
		print("VISTA ", row[0], " páginas=", n)
		for i in n:
			await _show(v, i, String(row[1]) + ("" if n == 1 else "_p%d" % (i + 1)))
	if only == "" or only.split(",").has("lupa"):
		var v2: Dictionary = ViewModel.from_repo(repo, "D30@L3")
		reader.open_view(v2)
		await tool.frames(4)
		pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
		var at := _word_pos(0, "Recibos")
		if at != Vector2.ZERO:
			Input.warp_mouse(at)
			reader.point_at(at)
			await tool.frames(4)
			await tool.snap("d30_lupa")
		pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
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
	reader.close()
	await tool.frames(2)

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
