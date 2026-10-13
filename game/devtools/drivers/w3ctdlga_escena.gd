# devtools/drivers/w3ctdlga_escena.gd — W3-CT-DLG-A: capturas de los diálogos y escenas propios en la UI real de escena
# (ui/scene/scene_panel.gd de W3-SCENEUI) sobre una GameSim con data/ REAL, avanzada con el bot pasivo (PlaySession).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctdlga res://devtools/drivers/w3ctdlga_escena.gd
# Salida: .work/shots/w3ctdlga_<nombre>.png — watson (consulta, día 1), ujier (Sala de Lectura, día 1), agente (AGENTE,
# día 7), hudson (HC05, día 8). Env W3DA_ONLY="watson,ujier,agente,hudson" para elegir secciones.
extends RefCounted

const DataRepo = preload("res://core/data/data_repo.gd")
const PlaySession = preload("res://devtools/bots/play_session.gd")
const WR = preload("res://world/world_root.gd")
const ScenePanel = preload("res://ui/scene/scene_panel.gd")

var tool
var scene
var wr = null
var repo = null
var only: Array = []

func drive(p_tool, p_scene) -> void:
	tool = p_tool
	scene = p_scene
	for c in scene.get_children():
		c.queue_free()
	var env := OS.get_environment("W3DA_ONLY")
	only = Array(env.split(",", false)) if env != "" else []
	repo = DataRepo.fresh("res://data")
	if not repo.errors().is_empty():
		print("DATASET CON ERRORES ", repo.errors().slice(0, 5))
	wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	await tool.frames(2)
	if _on("watson"):
		await _visit("watson", ["bot pasivo hasta 1.M", '{"t": "go", "place": "L4", "area": "consulta"}'],
			[["watson", "ask", "fina"], ["watson", "ask", "lisle"]])
	if _on("ujier"):
		await _visit("ujier", ["bot pasivo hasta 1.T", '{"t": "go", "place": "L2", "area": "sala", "seat": 214}'],
			[["ujier", "ask", "holmes"], ["ujier", "ask", "fina"]])
	if _on("agente"):
		await _visit("agente", ["bot pasivo hasta 7.M", '{"t": "go", "place": "L3", "area": "agente"}'], [])
	if _on("hudson"):
		await _visit("hudson", ["bot pasivo hasta 8.M", '{"t": "go", "place": "L3", "area": "interior"}'],
			[["mrs_hudson", "ask", "holmes"]])

func _on(sec: String) -> bool:
	return only.is_empty() or only.has(sec)

func _session(cmds: Array):
	var ps = PlaySession.new(repo, 1)
	ps.echo = false
	for c in cmds:
		ps.exec(String(c))
	if ps.fails > 0:
		print("FALLAS DEL CAMINO: ", ps.fails, " ", "\n".join(ps.out.slice(maxi(0, ps.out.size() - 6))))
	return ps.sim

func _visit(name: String, cmds: Array, asks: Array) -> void:
	var sim = _session(cmds)
	await _show_visit(sim)
	var sp = ScenePanel.new()
	sp.sim = sim
	sp.act_fn = func(a): return sim.apply(a)
	sp.sounds = false
	sp.world = wr
	scene.add_child(sp)
	sp.refresh()
	await _wait(12, 0.8)
	await tool.snap(name)
	var i := 0
	for q in asks:
		i += 1
		if not _indexed(sim, String(q[2])):
			print("tema no indexado: ", q[2])
			continue
		sp.open_ask(String(q[0]), String(q[1]))
		sp.ask_panel.choose(String(q[2]))
		await _wait()
		sp.ask_panel.confirm()
		await _wait(12, 0.7)
		await tool.snap("%s_%d" % [name, i])
	for l in sim.q_scene().get("lines", []):
		print("[%s] %s: %s" % [name, l.get("who", ""), String(l.get("parsed", {}).get("plain", l.get("text", "")))])
	sp.queue_free()
	await _wait(2)

func _indexed(sim, ent: String) -> bool:
	for x in sim.q_index():
		if String(x.get("id", "")) == ent:
			return true
	return false

func _show_visit(sim) -> void:
	var snap: Dictionary = sim.q_visit_plate()
	if snap.is_empty():
		return
	var pl: Dictionary = sim.repo.place(String(snap.get("place", "")))
	if pl.is_empty():
		pl = sim.repo.plate(String(snap.get("place", "")))
	wr.show_plate(snap, pl)
	wr.set_orbit_enabled(false)
	var area := String(snap.get("area", ""))
	for f in pl.get("frames", []):
		if String(f.get("area", "*")) == area:
			wr.set_frame(String(f.get("id", "")), true)
			break
	await tool.frames(4)

func _wait(n := 12, secs := 0.0) -> void:
	await tool.frames(n)
	if secs > 0.0:
		await tool.create_timer(secs).timeout
