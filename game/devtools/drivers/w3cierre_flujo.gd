# Cierre de la ola 3: el juego real (data/ real) jugado por el bot deductor a través del Shell, con capturas de lo que
# este cierre cambió: (1) recortar en casa (hub) con el rectángulo de la UI; (2) el pliego del club en la Sala de
# Forasteros (D46: «Leer» desde el nodo, lector, regla y «Anotar la medida»); (3) la confrontación sobre la lámina de
# HC07 (tienda del día 10, con los nodos del librero) y (4) al terminar, de vuelta al escritorio para el informe final.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3cierre res://devtools/drivers/w3cierre_flujo.gd --mute
# Salida: «CIERRE OK|FALLA <paso> …» y «CIERRE RESUMEN n fallas». Capturas: .work/shots/w3cierre_<paso>.png
extends RefCounted

const RunBots = preload("res://devtools/bots/run_bots.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

var tool
var shell
var g
var bot
var fails := 0

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(4)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	g.save_path = "user://saves/w3cierre.jsonl"
	shell.fast = true
	shell.new_game(1)
	await _idle()
	bot = RunBots.make("deductor")
	bot.setup(g.sim, 1)
	var done := {}
	for i in 4000:
		await _idle()
		if shell.screen_id != "game" or g.sim == null:
			break
		var c: Dictionary = g.sim.q_clock()
		var ph := String(c.phase)
		if not done.has("hub") and ph == "desk" and int(c.day) == 3:
			done["hub"] = true
			await _hub_clip()
		var sc: Dictionary = g.sim.q_scene()
		if not done.has("d46") and ph == "visit" and String(sc.get("place", "")) == "L5" and String(sc.get("area", "")) == "forasteros":
			done["d46"] = true
			await _d46()
		if ph == "confront" and not done.has("conf"):
			done["conf"] = true
			await _confront_plate()
		if ph == "final_report" and done.has("conf") and not done.has("conf_fin"):
			# terminada la confrontación (Clock.on_confront_done): de vuelta al escritorio, el informe final
			done["conf_fin"] = true
			await tool.frames(40)
			await tool.snap("4_conf_fin")
			var gs = shell.game_screen
			_chk(String(gs.mode) == "hub" and String(gs.frame) == "escritorio", "4_vuelta_a_la_buhardilla", str([gs.mode, gs.frame]))
		if ph == "final_report":
			break
		if not bot.step():
			break
	for k in ["hub", "d46", "conf", "conf_fin"]:
		_chk(done.has(k), "paso_" + k, "")
	print("CIERRE RESUMEN %d fallas" % fails)
	g.end_session()

func _chk(cond: bool, step: String, info: String) -> void:
	if cond:
		print("CIERRE OK ", step)
	else:
		fails += 1
		print("CIERRE FALLA ", step, " ", info)

func _idle() -> void:
	var i := 0
	while i < 900 and not (shell.screen_id != "game" or (shell.game_screen != null and shell.game_screen.idle())):
		await tool.frames(1)
		i += 1
	await tool.frames(2)

# Rectángulo de pantalla que cubre un nodo del diorama (proyección de su caja).
func _node_rect(nid: String) -> Rect2:
	var body: Node3D = shell.world.node_body(nid)
	var cam: Camera3D = shell.world.camera()
	if body == null or cam == null:
		return Rect2()
	var aabb := AABB()
	var first := true
	for n in body.find_children("*", "VisualInstance3D", true, false) + ([body] if body is VisualInstance3D else []):
		var vi := n as VisualInstance3D
		var bb: AABB = vi.global_transform * vi.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	if first:
		aabb = AABB(body.global_position - Vector3(0.3, 0, 0.3), Vector3(0.6, 1.7, 0.6))
	var r := Rect2()
	var f2 := true
	for k in 8:
		var p := cam.unproject_position(aabb.get_endpoint(k))
		r = Rect2(p, Vector2.ZERO) if f2 else r.expand(p)
		f2 = false
	return r.grow(6.0)

func _hub_clip() -> void:
	var gs = shell.game_screen
	shell.close_all()   # la bandeja del amanecer tapa la ventana
	await tool.frames(10)
	gs.go_frame("ventana")
	await tool.frames(40)
	await tool.snap("1_hub_ventana")
	var before: int = g.sim.st.ded.get("clips", {}).size()
	var rect := _node_rect("sil_wiggins")
	_chk(rect.size.x > 4.0, "1_silueta_visible", str(rect))
	gs._on_rect(rect)
	await tool.frames(30)
	await tool.snap("1_hub_recortado")
	var ids: Array = g.sim.st.ded.get("clips", {}).keys()
	ids.sort()
	_chk(ids.size() == before + 1, "1_recorte_en_casa", str(rect))
	if ids.size() > before:
		var cl: Dictionary = Clipper.get_clip(g.sim.st, String(ids[-1]))
		_chk(String(cl.get("plate", "")).begins_with("PL.L1.3.") and String(cl.get("origin", "")).begins_with("PL.L1"), "1_lamina_archivada", str([cl.get("plate"), cl.get("origin"), cl.get("tags")]))
	gs.go_frame("escritorio")
	await tool.frames(20)

func _d46() -> void:
	var gs = shell.game_screen
	await tool.frames(30)
	await tool.snap("2_forasteros")
	gs._examine("papel_mesa", {})
	await tool.frames(20)
	await tool.snap("2_examen_papel")
	var views: Array = []
	for v in g.sim.q_accessible():
		views.append(String(v.view))
	_chk(views.has("D46@L5"), "2_pliego_legible", str(views))
	gs._read("D46@L5")
	await tool.frames(30)
	var rd = shell.reader
	rd.set_regla(true)
	await tool.frames(20)
	await tool.snap("2_lector_regla")
	var before: int = g.sim.st.ded.get("clips", {}).size()
	rd._do_measure()
	await tool.frames(30)
	await tool.snap("2_medida")
	var ids: Array = g.sim.st.ded.get("clips", {}).keys()
	ids.sort()
	_chk(ids.size() == before + 1, "2_medida_anotada", "")
	if ids.size() > before:
		var cl: Dictionary = Clipper.get_clip(g.sim.st, String(ids[-1]))
		_chk(String(cl.get("text", "")).contains("244") and (cl.get("tags", []) as Array).has("a:vinculo_mycroft"), "2_medida_etiquetas", str([cl.get("text"), cl.get("tags")]))
	shell.close_kind("reader")
	await tool.frames(10)

func _confront_plate() -> void:
	await tool.frames(40)
	await tool.snap("3_confrontacion")
	var sc: Dictionary = g.sim.q_scene()
	_chk(String(sc.get("plate", "")) == "PL.HC07", "3_lamina_hc07", str(sc.get("plate", "")))
	var snap: Dictionary = g.sim.q_plate("PL.HC07")
	_chk((snap.get("nodes", []) as Array).has("librero_dedos") and (snap.get("nodes", []) as Array).has("librero_sombra"), "3_nodos_del_librero", str(snap.get("nodes", [])))
	_chk(String(shell.game_screen.cur_plate) == "PL.HC07", "3_ui_muestra_hc07", String(shell.game_screen.cur_plate))
