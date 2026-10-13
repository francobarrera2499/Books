# Driver de capturas del guardián de contenido: documentos reales en el lector (W2-READER), sobre data/ real.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3guard res://devtools/drivers/w3guard_lector.gd --docs=D17@Crane:2,D15.0405@L1:1
# Capturas: .work/shots/w3guard_<doc>_p<n>.png (sin --docs: D17@Crane y D15.0405@L1).
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const Repo = preload("res://core/data/data_repo.gd")

var tool
var reader
var repo

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	repo = Repo.fresh("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = func(_a): return {"ok": false}
	scene.add_child(reader)
	await tool.frames(4)
	var spec := "D17@Crane:2,D15.0405@L1:1"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--docs="):
			spec = String(a).substr(7)
	for item in spec.split(",", false):
		var cp := String(item).get_slice(":", 0)
		var n := int(String(item).get_slice(":", 1)) if String(item).contains(":") else 1
		var v: Dictionary = ViewModel.from_repo(repo, cp)
		if v.is_empty():
			print("SIN VISTA ", cp)
			continue
		for i in n:
			reader.open_view(v)
			await tool.frames(3)
			if i > 0:
				reader.go_page(i)
			await tool.frames(6)
			await tool.snap("%s_p%d" % [cp.get_slice("@", 0).replace(".", "_"), i + 1])
		reader.close()
		await tool.frames(2)
