# Driver de capturas W3-CT-DLG-B: las escenas y diálogos del paquete en el panel de escena (W3-SCENEUI) y en la vista de
# la confrontación, sobre una GameSim REAL con data/ real y el WorldRoot detrás (lámina o lugar de cada escena).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ctdlgb res://devtools/drivers/w3ctdlgb_escenas.gd
# Capturas (.work/shots/w3ctdlgb_<nombre>.png):
#   pro      prólogo (PL.prologo): Pell y Harris, primera línea del instructor
#   crane    tienda de Crane, día 1: dos preguntas (deuda, «El problema final»)
#   m6       sábado al amanecer: Pell y la pregunta del mayor
#   m7       lunes 22 h (PL.M7): Harris en persona
#   hc06     Sala de Forasteros, día 8: Mycroft (a)–(g)
#   hc06_b   después de preguntarle por el doctor (duelo)
#   hc07     jueves 9:30: la confrontación con el librero (vista propia)
#   hc08     Park Lane, 18 h (PL.PARK)
# El camino lo hace el bot pasivo (devtools/bots); este driver sólo interviene donde hace falta.
extends RefCounted

const Repo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const WR = preload("res://world/world_root.gd")
const ScenePanel = preload("res://ui/scene/scene_panel.gd")
const ConfrontationView = preload("res://ui/scene/confrontation_view.gd")

var tool
var scene
var sim
var repo
var wr = null
var bot = null

func drive(p_tool, p_scene) -> void:
	tool = p_tool
	scene = p_scene
	for c in scene.get_children():
		c.queue_free()
	repo = Repo.fresh("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
	sim = GameSim.new(repo, 1894)
	bot = RunBots.make("pasivo")
	bot.setup(sim, 1894)
	wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	await tool.frames(2)
	# prólogo
	await _plate_shot("PRO", "pro")
	_until("1.M")
	# Crane, día 1
	_act({"t": "go", "place": "L1", "area": "tienda"})
	await _show_visit()
	var sp = _panel()
	for topic in ["lisle", "fina"]:
		sp.open_ask("crane", "ask")
		sp.ask_panel.choose(topic)
		sp.ask_panel.confirm()
		await _wait(8, 0.4)
	await _wait(12, 1.0)
	await tool.snap("crane")
	sp.queue_free()
	_act({"t": "leave"})
	_until("5.dawn")
	await _hub_shot("m6")
	_until("7.night")
	await _plate_shot("M7", "m7")
	_until("8.T")
	if String(sim.q_clock().phase) == "desk":
		_act({"t": "go", "place": "L5", "area": "forasteros"})
		await _show_visit()
		sp = _panel()
		await _wait(12, 1.2)
		await tool.snap("hc06")
		sp.open_ask("mycroft", "ask")
		if sim.q_index().any(func(x): return String(x.id) == "watson"):
			sp.ask_panel.choose("watson")
		else:
			sp.ask_panel.choose("holmes")
		sp.ask_panel.confirm()
		await _wait(12, 1.2)
		await tool.snap("hc06_b")
		sp.queue_free()
		_act({"t": "leave"})
	_until("10.M")
	if String(sim.q_clock().phase) == "confront":
		await _show_shop()
		var cv = ConfrontationView.new()
		cv.sim = sim
		cv.act_fn = func(a): return sim.apply(a)
		cv.sounds = false
		scene.add_child(cv)
		cv.refresh()
		await _wait(12, 1.0)
		await tool.snap("hc07")
		cv.queue_free()
	_until("10.T")
	if String(sim.q_clock().phase) == "parklane":
		var pm: Dictionary = repo.plate("PARK")
		var snap: Dictionary = sim.q_visit_plate()
		if not snap.is_empty() and not pm.is_empty():
			wr.show_plate(snap, pm)
			wr.set_frame(_frame_for(pm, "exterior"), true)
		await _wait(4)
		sp = _panel()
		await _wait(12, 1.2)
		await tool.snap("hc08")
		sp.queue_free()
	print("FIN w3ctdlgb: ", sim.q_clock().date_label, " ", sim.q_clock().phase)

func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if not bool(r.get("ok", false)):
		print("  (rechazada) ", a, " -> ", r)
	return r

func _until(tk: String) -> void:
	var until := TimeKey.of(tk)
	var steps := 0
	while steps < 5000 and int(sim.q_clock().tk) < until and String(sim.q_clock().phase) != "done":
		steps += 1
		if not bot.step():
			break

func _panel() -> Node:
	var sp = ScenePanel.new()
	sp.sim = sim
	sp.act_fn = func(a): return sim.apply(a)
	sp.sounds = false
	sp.world = wr
	scene.add_child(sp)
	sp.refresh()
	return sp

func _wait(n := 12, secs := 0.0) -> void:
	await tool.frames(n)
	if secs > 0.0:
		await tool.create_timer(secs).timeout

static func _frame_for(pl: Dictionary, area: String) -> String:
	for f in pl.get("frames", []):
		var a := String(f.get("area", "*"))
		if a == area or a == "*":
			return String(f.get("id", ""))
	var fr: Array = pl.get("frames", [])
	return String(fr[0].get("id", "")) if not fr.is_empty() else ""

func _show_visit() -> void:
	var snap: Dictionary = sim.q_visit_plate()
	if snap.is_empty():
		return
	var pl: Dictionary = repo.place(String(snap.get("place", "")))
	if pl.is_empty():
		pl = repo.plate(String(snap.get("place", "")))
	wr.show_plate(snap, pl)
	wr.set_orbit_enabled(false)
	var fid := _frame_for(pl, String(snap.get("area", "")))
	if fid != "":
		wr.set_frame(fid, true)
	await tool.frames(4)

func _show_shop() -> void:
	var WorldModel = load("res://core/sim/world_model.gd")
	var snap: Dictionary = WorldModel.snapshot(sim.st, repo, "L1", "tienda", "")
	snap["id"] = "PL.tienda.dlgb"
	wr.show_plate(snap, repo.place("L1"))
	wr.set_orbit_enabled(false)
	wr.set_frame("mostrador", true)
	await tool.frames(4)

func _plate_shot(plate_id: String, name: String) -> void:
	var pm: Dictionary = repo.plate(plate_id)
	var snap: Dictionary = sim.q_visit_plate()
	if not snap.is_empty() and not pm.is_empty():
		wr.show_plate(snap, pm)
		wr.set_frame(_frame_for(pm, "buhardilla"), true)
	await _wait(4)
	var sp = _panel()
	await _wait(12, 1.2)
	await tool.snap(name)
	sp.queue_free()
	await _wait(2)

func _hub_shot(name: String) -> void:
	wr.show_hub("escritorio", "M")
	await _wait(4)
	var sp = _panel()
	await _wait(12, 1.2)
	await tool.snap(name)
	sp.queue_free()
	await _wait(2)
