# Driver de capturas W3-CT-TIMES: el Times día por día, D40, D41 y D42 en el lector (W2-READER).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3cttimes res://devtools/drivers/w3cttimes_lector.gd [-- --only=<sub>] [--data=<ruta absoluta>]
# Capturas (.work/shots/w3cttimes_<nombre>.png):
#   t0331_p1, t0403_p1, t0403_p2, t0405_p1   números estáticos (ejemplar de la bandeja, sin partida)
#   t0327_aviso   D15.0327@L1, columna con el aviso del prólogo (runtime, recorrido de test_i_integration)
#   t0330_s       D15.0330@L1, columna con la respuesta «—S.» de HC10 (runtime)
#   d40, d41, d42 tienda de Crane
# Además imprime el recorte real de D15.0403#whist y #nadie_oyo (etiquetas y entidades: R4) y q_catalog de algunas
# entidades (ruido del catálogo). --data: dataset alternativo para el recorrido (p. ej. .work/times/data_walk si
# data/ trae un archivo ajeno roto); sin él usa res://data.
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Repo = preload("res://core/data/data_repo.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

var tool
var reader
var repo

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var only := ""
	var root := "res://data"
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--only="):
			only = String(a).substr(7)
		if String(a).begins_with("--data="):
			root = String(a).substr(7)
	repo = Repo.fresh(root)
	for e in repo.errors():
		print("DATA ERR ", e)
	reader = Reader.new()
	reader.sounds = false
	scene.add_child(reader)
	await tool.frames(4)
	var plan := [["D15.0331@L1", "t0331", [0]], ["D15.0403@L1", "t0403", [0, 1]], ["D15.0405@L1", "t0405", [0]],
		["D40@Crane", "d40", [0]], ["D41@Crane", "d41", [0]], ["D42@Crane", "d42", [0]]]
	for row in plan:
		if only != "" and not String(row[1]).contains(only):
			continue
		var v: Dictionary = ViewModel.from_repo(repo, String(row[0]))
		for i in row[2]:
			await _show(v, int(i), String(row[1]) + ("" if (row[2] as Array).size() == 1 and String(row[1]).begins_with("d") else "_p%d" % (int(i) + 1)))
	if only == "" or only == "runtime":
		await _runtime()
	if only == "" or only == "catalogo":
		var sim = GameSim.new(repo, 1894)
		for ent in ["holmes", "watson", "reichenbach", "moran", "tigre", "ronald_adair", "sigerson", "whist"]:
			var labels: Array = []
			for r in sim.q_catalog(ent):
				labels.append(("[doc %s] " % r.doc if String(r.doc) != "" else "") + String(r.label))
			print("CATALOGO ", ent, ": ", labels)
	reader.close()
	await tool.frames(2)

func _runtime() -> void:
	var t = load("res://tests/test_i_integration.gd").new()
	t._cur = "w3cttimes_lector.gd::runtime"
	var sim = t._walk(repo)
	if sim == null or not t._errs.is_empty():
		print("RECORRIDO CON PROBLEMAS ", t._errs)
		if sim == null:
			return
	reader.act_fn = func(a): return sim.apply(a)
	await _show(sim.q_view("D15.0327@L1"), 1, "t0327_aviso")
	await _show(sim.q_view("D15.0330@L1"), 1, "t0330_s")
	# avanzar hasta el día 8 para recortar el Times de la indagatoria (dormir día a día)
	for i in 200:
		var c: Dictionary = sim.q_clock()
		var ph := String(c.phase)
		if int(c.day) >= 8 and ph == "desk":
			break
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if sim.q_report_status().due else {"t": "sleep"}
			_:
				print("FASE ", ph)
				break
		var r: Dictionary = sim.apply(a)
		if not r.get("ok", false):
			print("AVANCE ", a, " -> ", r, " ", c)
			break
	print("RELOJ ", sim.q_clock())
	var v: Dictionary = sim.q_view("D15.0403@L1")
	for tid in ["whist", "nadie_oyo", "nada_falta", "puerta"]:
		var done := false
		for pi in (v.get("pages", []) as Array).size():
			for bi in (v.pages[pi] as Array).size():
				for tr in v.pages[pi][bi].parsed.tramos:
					if String(tr.id) == tid and not done:
						done = true
						var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D15.0403@L1", "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
						if r.get("ok", false):
							var c: Dictionary = Clipper.get_clip(sim.st, String(r.clip))
							print("CLIP #", tid, " tags=", c.get("tags", []), " ents=", c.get("ents", []), " origin=", c.get("origin", ""))
						else:
							print("CLIP #", tid, " -> ", r)
		if not done:
			print("SIN TRAMO #", tid, " (vista ", v.is_empty(), ")")

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
