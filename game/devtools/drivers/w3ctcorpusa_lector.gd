# Driver de capturas W3-CT-CORPUS-A: el lector (W2-READER) sobre las historias del corpus vols. II–III (data/docs/D01/*).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctcorpusa res://devtools/drivers/w3ctcorpusa_lector.gd [IDS]
# IDS opcional: lista separada por comas de ejemplares (p. ej. D01.SCAN@tomo,D01.REDH@BM); por defecto las 12 historias @tomo.
# Capturas (.work/shots/w3ctcorpusa_<CODIGO>.png y <CODIGO>_p2… por hoja); con «zoom» en la lista agrega <CODIGO>_zoom (220 %, arriba del texto).
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const Repo = preload("res://core/data/data_repo.gd")

const ALL := ["SCAN", "REDH", "IDEN", "BOSC", "FIVE", "TWIS", "BLUE", "SPEC", "ENGR", "NOBL", "BERY", "COPP"]

var tool
var reader
var repo

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	repo = Repo.load_dir("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = func(a): return {"ok": true, "clip": "RC0001"}
	scene.add_child(reader)
	await tool.frames(3)
	var ids: Array = []
	var zoom := false
	var args := OS.get_cmdline_user_args()
	if args.size() > 3:
		for s in String(args[3]).split(",", false):
			if s == "zoom":
				zoom = true
			else:
				ids.append(s)
	if ids.is_empty():
		for c in ALL:
			ids.append("D01.%s@tomo" % c)
	for ref in ids:
		var v := ViewModel.from_repo(repo, String(ref))
		if v.is_empty():
			print("SIN VISTA ", ref)
			continue
		reader.open_view(v)
		await tool.frames(8)
		var code := String(ref).get_slice("@", 0).get_slice(".", 1)
		await tool.snap(code)
		for pg in range(1, reader.page_count()):
			reader.go_page(pg)
			await tool.frames(6)
			await tool.snap("%s_p%d" % [code, pg + 1])
		if reader.page_count() > 1:
			reader.go_page(0)
			await tool.frames(3)
		if zoom:
			reader.set_zoom(2.2, Vector2(800, 260))
			await tool.frames(6)
			await tool.snap(code + "_zoom")
			reader.set_zoom(1.0, Vector2(800, 450))
			await tool.frames(3)
	reader.close()
	await tool.frames(2)
