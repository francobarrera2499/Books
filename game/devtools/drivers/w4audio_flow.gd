# W4-AUDIO: una partida real con el Shell (guion de W4-SLICE aplicado acción por acción con Shell.act, para que
# GameScreen pase por cada fase, visita y amanecer) y registro de lo que suena: ambiente (Audio.current_amb y volumen)
# en cada momento nuevo, subtítulos de cada amanecer y de la noche final (HC09, avanzando el epílogo golpe a golpe).
# El bus Master queda en silencio: la lógica de audio corre igual y no sale nada por los parlantes.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4audio res://devtools/drivers/w4audio_flow.gd --new --seed=1 [--guion=res://devtools/scripts/slice_f1.jsonl] [--hasta=N]
# Sólo la noche: --script=<guion sin la línea night_choice> --noche=baker_street|casa (entra en la elección y la hace).
# Salida: «W4AUDIO <momento> -> <ambiente> <dB>», «W4AUDIO AMANECER …», «W4AUDIO NOCHE …», «W4AUDIO RESUMEN …»;
# capturas .work/shots/w4audio_amanecer_<día>.png (el primero) y w4audio_noche_<n>.png.
extends RefCounted

const J = preload("res://core/util/j.gd")

var tool
var shell
var g
var au
var subs: Array = []
var moments := {}
var problems: Array = []

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	au = tool.root.get_node("Audio")
	if shell == null or g == null or au == null:
		print("W4AUDIO sin Shell/Game/Audio")
		return
	AudioServer.set_bus_mute(0, true)
	au.subtitle.connect(func(t: String, _s: float) -> void: subs.append(t))
	var path := "res://devtools/scripts/slice_f1.jsonl"
	var hasta := 100000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--guion="): path = a.substr(8)
		elif a.begins_with("--hasta="): hasta = int(a.substr(8))
	await _wait_idle(600)
	if g.sim == null:
		print("W4AUDIO sin partida (¿falta --new?)")
		return
	if String(g.sim.q_clock().phase) == "night_choice":   # --script= hasta la elección: --noche=baker_street|casa
		var where := "baker_street"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--noche="): where = arg.substr(8)
		await _wait_s(1.5)
		subs.clear()
		shell.act({"t": "night_choice", "where": where})
		await _wait_idle(1200)
		await _night()
		print("W4AUDIO RESUMEN noche, %d problemas" % problems.size())
		for p in problems: print("W4AUDIO PROBLEMA ", p)
		return
	await _record("inicio")
	var acts: Array = []
	for ln in FileAccess.get_file_as_string(path).split("\n"):
		var s := ln.strip_edges()
		if s == "" or s.begins_with("#"): continue
		var a = J.parse_str(s)
		if typeof(a) == TYPE_DICTIONARY: acts.append(a)
	var dawn_n := 0
	for i in mini(acts.size(), hasta):
		var a: Dictionary = acts[i]
		var day0 := int(g.sim.q_clock().day)
		subs.clear()
		var r: Dictionary = shell.act(a)
		if not bool(r.get("ok", false)):
			problems.append("acción %d %s -> %s" % [i, JSON.stringify(a), str(r.get("err", ""))])
		await tool.frames(3)
		var newday := int(g.sim.q_clock().day) != day0
		if newday and String(g.sim.q_clock().phase) != "epilogue":
			await tool.frames(30)
			if dawn_n == 0: await tool.snap("amanecer_%d" % int(g.sim.q_clock().day))
			dawn_n += 1
		await _wait_idle(1200)
		if newday and String(g.sim.q_clock().phase) != "epilogue":
			await _wait_s(2.6)   # el lechero y la persiana entran a los 4,5 y 6,75 s
			print("W4AUDIO AMANECER día %d: %s" % [int(g.sim.q_clock().day), " | ".join(subs)])
			_check_dawn(int(g.sim.q_clock().day))
		await _record("acción %d (%s)" % [i, String(a.get("t", ""))])
		if shell.screen_id == "epilogue": break
	if shell.screen_id == "epilogue":
		await _night()
	print("W4AUDIO RESUMEN %d momentos, %d problemas" % [moments.size(), problems.size()])
	for p in problems: print("W4AUDIO PROBLEMA ", p)
	g.end_session()

func _wait_idle(max_frames: int) -> void:
	for k in max_frames:
		await tool.frames(1)
		var gs = shell.game_screen
		var syncing: bool = gs != null and is_instance_valid(gs) and bool(gs.get("_syncing"))
		if not shell.is_busy() and not syncing and k > 4: return

func _wait_s(s: float) -> void:
	await tool.create_timer(s).timeout

# Un momento nuevo (fase, día, franja, lugar de la visita o escena): espera el fundido y anota qué suena.
func _record(why: String) -> void:
	var c: Dictionary = g.sim.q_clock()
	var sc: Dictionary = g.sim.q_scene()
	var gs = shell.game_screen
	var place := String(gs.get("cur_place")) if gs != null and is_instance_valid(gs) else "?"
	var key := "%s %d.%s %s %s" % [String(c.phase), int(c.day), String(c.slot), place, String(sc.get("area", ""))]
	if moments.has(key): return
	await _wait_s(1.1)
	var amb := String(au.current_amb())
	var vol: float = au._amb[au._amb_cur].volume_db if au._nodes_ready else -80.0
	moments[key] = amb
	print("W4AUDIO %-44s -> %-18s %6.1f dB   (%s)" % [key, amb, vol, why])
	if amb == "" and not ["epilogue", "done"].has(String(c.phase)):
		problems.append("silencio en " + key)

func _check_dawn(day: int) -> void:
	for want in ["campanas de St Clement Danes", "en la calle, cascos y latas que tintinean"]:
		if not subs.has(want): problems.append("amanecer del día %d sin «%s»" % [day, want])
	var sunday := day == 6
	if subs.has("abajo, una persiana que sube y golpea") == sunday:
		problems.append("amanecer del día %d: persiana de Crane %s" % [day, "un domingo" if sunday else "ausente"])

# La noche final (HC09) en el epílogo: cada golpe con su sonido.
func _night() -> void:
	for k in 40:   # el fundido y show_epilogue llegan después del act
		if shell.screen_id == "epilogue": break
		await _wait_s(0.25)
	await _wait_s(1.0)
	var ep = shell.screen
	if ep == null or not ep.has_method("state"):
		problems.append("sin pantalla de epílogo")
		return
	var n := 0
	while String(ep.state().get("stage", "")) == "noche" and n < 12:
		await _wait_s(4.0)
		if String(ep.state().get("stage", "")) != "noche": break
		var amb := String(au.current_amb())
		print("W4AUDIO NOCHE golpe %d (amb %s): %s" % [int(ep.state().get("beat", -1)), amb, " | ".join(subs)])
		await tool.snap("noche_%d" % n)
		subs.clear()
		ep.advance()
		n += 1
		await tool.frames(5)
