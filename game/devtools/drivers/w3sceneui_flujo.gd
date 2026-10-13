# devtools/drivers/w3sceneui_flujo.gd — W3-SCENEUI: capturas del flujo completo de la UI de escenas y compositores sobre
# una GameSim REAL (tests/fixtures/w3sceneui/world.gd) con el WorldRoot real detrás (grabado de W1-POST).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3sceneui res://devtools/drivers/w3sceneui_flujo.gd
# Env: W3SU_ONLY="escena,conf,anuncio,correo,informe,hc" (secciones; por defecto todas) · W3SU_RAW=1 (sin grabado)
# Salida: .work/shots/w3sceneui_<nombre>.png
#   escena: visita (Watson), preguntar (frase previa), respuesta, afirmar, presentar_elegir, presentar_frase, presentado,
#           tijera (selección sobre una línea), crane, wiggins_pagar, m7 (escena fija)
#   conf:   conf_inicio, conf_callar (2.º paso), conf_refutar (selector), conf_frase, conf_acierto, conf_error1 (paquete),
#           conf_error2 (sombrero), conf_fin (se va)
#   anuncio: anuncio_prologo, anuncio_forma, anuncio_confirmar · correo: telegrama, carta · informe: informe, informe_elegir,
#           informe_confirmar, informe_final · hc: alto contraste de visita, confrontación e informe
extends RefCounted

const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const WR = preload("res://world/world_root.gd")
const ScenePanel = preload("res://ui/scene/scene_panel.gd")
const ConfrontationView = preload("res://ui/scene/confrontation_view.gd")
const AdComposer = preload("res://ui/compose/ad_composer.gd")
const TelegramComposer = preload("res://ui/compose/telegram_composer.gd")
const ReportComposer = preload("res://ui/compose/report_composer.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

var tool
var scene
var w
var wr = null
var only: Array = []

func drive(p_tool, p_scene) -> void:
	tool = p_tool
	scene = p_scene
	for c in scene.get_children():
		c.queue_free()
	var env := OS.get_environment("W3SU_ONLY")
	only = Array(env.split(",", false)) if env != "" else []
	w = W.new()
	if not w.repo.errors().is_empty():
		print("DATASET CON ERRORES ", w.repo.errors().slice(0, 5))
	wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	if OS.get_environment("W3SU_RAW") != "":
		wr.set_engraving(false)
	await tool.frames(2)
	if _on("escena"):
		await _escena()
	if _on("conf"):
		await _conf()
	if _on("anuncio"):
		await _anuncio()
	if _on("correo"):
		await _correo()
	if _on("informe"):
		await _informe()
	if _on("hc"):
		await _hc()
	print("ERRORES DEL CAMINO ", w.errs)

func _on(sec: String) -> bool:
	return only.is_empty() or only.has(sec)

# ------------------------------------------------------------------ 3D de fondo
func _show_visit(sim) -> void:
	var snap: Dictionary = sim.q_visit_plate()
	if snap.is_empty():
		return
	var pl: Dictionary = sim.repo.place(String(snap.get("place", "")))
	if pl.is_empty():
		pl = sim.repo.plate(String(snap.get("place", "")))
	wr.show_plate(snap, pl)
	wr.set_orbit_enabled(false)
	var fid := _frame_for(pl, String(snap.get("area", "")))
	if fid != "":
		wr.set_frame(fid, true)
	await tool.frames(4)

func _show_shop(sim, frame := "mostrador") -> void:
	var snap: Dictionary = WorldModel.snapshot(sim.st, sim.repo, "L1", "tienda", "")
	snap["id"] = "PL.tienda.drv"
	wr.show_plate(snap, sim.repo.place("L1"))
	wr.set_orbit_enabled(false)
	wr.set_frame(frame, true)
	await tool.frames(4)

func _show_hub(sim, frame := "escritorio") -> void:
	var c: Dictionary = sim.q_clock()
	var slot := String(c.get("slot", "M"))
	if not ["M", "T", "N"].has(slot):
		slot = "N"
	wr.show_hub(frame, slot)
	await tool.frames(4)

static func _frame_for(pl: Dictionary, area: String) -> String:
	for f in pl.get("frames", []):
		var a := String(f.get("area", "*"))
		if a == area or a == "*":
			return String(f.get("id", ""))
	var fr: Array = pl.get("frames", [])
	return String(fr[0].get("id", "")) if not fr.is_empty() else ""

func _panel(sim) -> Node:
	var sp = ScenePanel.new()
	sp.sim = sim
	sp.act_fn = func(a): return sim.apply(a)
	sp.sounds = false
	sp.world = wr                  # subpaneles del lado contrario al personaje
	scene.add_child(sp)
	sp.refresh()
	return sp

# Espera en cuadros y además en tiempo real (los tweens de 0,3–0,4 s terminan aunque el cuadro sea muy rápido).
func _wait(n := 12, secs := 0.0) -> void:
	await tool.frames(n)
	if secs > 0.0:
		await tool.create_timer(secs).timeout

# ------------------------------------------------------------------ escena
func _escena() -> void:
	var sim = w.sim_at("day1_watson")
	await _show_visit(sim)
	var sp = _panel(sim)
	await _wait(12, 0.8)
	await tool.snap("visita")
	sp.open_ask("watson", "ask")
	sp.ask_panel.choose("fina")
	await _wait()
	await tool.snap("preguntar")
	sp.ask_panel.confirm()
	await _wait(12, 0.6)
	await tool.snap("respuesta")
	sp.open_ask("watson", "assert")
	sp.ask_panel.choose("as.pared")
	await _wait()
	await tool.snap("afirmar")
	sp.ask_panel.confirm()
	await _wait(12, 0.6)
	sp.open_picker("watson")
	await _wait()
	await tool.snap("presentar_elegir")
	sp.picker.pick("clip", String(w.clips.aviso))
	await _wait()
	await tool.snap("presentar_frase")
	sp.present_bar.confirm()
	await _wait(12, 0.6)
	await tool.snap("presentado")
	# tijera: arrastre REAL sobre una línea de Watson (RichTextLabel extiende la selección con la posición real del
	# cursor: se mueve el cursor del sistema con warp_mouse, como el driver T19 de W2-READER)
	sp.set_tijera(true)
	await _settle_window()
	await _wait(4)
	var row := {}
	for r in sp.transcript.rows():
		if String(r.who) == "watson" and String(r.parsed.plain).contains("sendero estrecho"):
			row = r
	if not row.is_empty():
		var rtl: RichTextLabel = row.rtl
		var plain := rtl.get_parsed_text()
		var s := "Era un sendero estrecho"
		var k := plain.find(s)
		if k < 0:
			k = 0
			s = plain.substr(0, mini(20, plain.length()))
		var pts := SelectionMapper.drag_points(rtl, k, k + s.length())
		await _sync_mouse(pts[0])
		_mm(pts[0], 0)
		await tool.frames(1)
		_mb(pts[0], true)
		for i in range(1, 9):
			_mm(pts[0].lerp(pts[1], float(i) / 8.0))
			await tool.frames(1)
		await _sync_mouse(pts[1])
		await tool.create_timer(0.2).timeout
		print("TIJERA seleccionado: «%s»" % rtl.get_selected_text())
		await tool.snap("tijera")
		_mb(pts[1], false)
		await _wait(5)
		await tool.snap("tijera_tira")
		await _wait(6, 0.5)
		print("TIJERA recortes: ", sp.sim.q_clips().size(), " nota: ", sp.note.text())
	sp.set_tijera(false)
	sp.queue_free()
	await _wait(2)
	# Crane: tienda (gratis), «Subir a la buhardilla»
	sim = w.sim_at("day1_crane")
	await _show_visit(sim)
	sp = _panel(sim)
	sp.show_leave = true
	sp.refresh()
	sp.open_ask("crane", "ask")
	sp.ask_panel.choose("fina")
	sp.ask_panel.confirm()
	await _wait(12, 1.2)
	await tool.snap("crane")
	sp.queue_free()
	await _wait(2)
	# Wiggins: pagar
	sim = w.sim_at("day3_wiggins")
	await _show_visit(sim)
	sp = _panel(sim)
	await _wait(6)
	sp.open_pay("wiggins")
	sp.present_bar.choose_amount(12)
	await _wait()
	await tool.snap("wiggins_pagar")
	sp.queue_free()
	await _wait(2)
	# M7: escena fija
	sim = w.sim_at("day7_m7")
	var pm: Dictionary = sim.repo.plate("M7")
	var snap: Dictionary = sim.q_visit_plate()
	if not snap.is_empty() and not pm.is_empty():
		wr.show_plate(snap, pm)
		wr.set_frame(_frame_for(pm, "buhardilla"), true)
	await _wait(4)
	sp = _panel(sim)
	await _wait(12, 1.2)
	await tool.snap("m7")
	sp.queue_free()
	await _wait(2)

# ------------------------------------------------------------------ confrontación
func _conf() -> void:
	var sim = w.sim_at("day10_confront")
	await _show_shop(sim)
	var cv = ConfrontationView.new()
	cv.sim = sim
	cv.act_fn = func(a): return sim.apply(a)
	cv.sounds = false
	scene.add_child(cv)
	cv.refresh()
	await _wait(12, 0.8)
	await tool.snap("conf_inicio")
	cv.ask_silence()
	await _wait()
	await tool.snap("conf_callar")
	cv.confirm_silence()           # I callada
	await _wait(10, 0.5)
	cv.open_refute()
	await _wait()
	await tool.snap("conf_refutar")
	cv.picker.pick("clip", String(w.clips.corniche))
	await _wait()
	await tool.snap("conf_frase")
	cv.confirm_bar.confirm()       # II acierto
	await _wait(12, 0.6)
	await tool.snap("conf_acierto")
	cv.refute({"kind": "clip", "id": String(w.clips.aviso)})
	cv.confirm_bar.confirm()       # III error 1: el paquete
	await _wait(12, 0.7)
	await tool.snap("conf_error1")
	if w.clips.has("ancla") and String(w.clips.ancla) != "":
		cv.refute({"kind": "clip", "id": String(w.clips.ancla)})
		cv.confirm_bar.confirm()   # III acierto (ancla)
		await _wait(10, 0.5)
	cv.refute({"kind": "clip", "id": String(w.clips.sheer)})
	cv.confirm_bar.confirm()       # IV error 2: el sombrero
	await _wait(12, 0.7)
	await tool.snap("conf_error2")
	cv.refute({"kind": "entry", "id": String(w.clips.practica)})
	cv.confirm_bar.confirm()       # IV error 3: se va
	await _wait(12, 0.7)
	await tool.snap("conf_fin")
	print("CONF ", cv.debug_state())
	cv.queue_free()
	await _wait(2)

# ------------------------------------------------------------------ anuncio
func _anuncio() -> void:
	var sim = w.sim_at("prologue_ad")
	await _show_hub(sim, "escritorio")
	var ac = AdComposer.new()
	ac.sim = sim
	ac.act_fn = func(a): return sim.apply(a)
	ac.sounds = false
	scene.add_child(ac)
	ac.open()
	ac.choose_form("testigo")
	ac.set_field("suceso", "suceso_reichenbach")
	await _wait()
	await tool.snap("anuncio_prologo")
	ac.queue_free()
	await _wait(2)
	sim = w.sim_at("day1_desk_T")
	await _show_hub(sim, "escritorio")
	ac = AdComposer.new()
	ac.sim = sim
	ac.act_fn = func(a): return sim.apply(a)
	ac.sounds = false
	scene.add_child(ac)
	ac.open()
	ac.choose_form("a_proposito")
	ac.set_field("fuente", "fina")
	await _wait()
	await tool.snap("anuncio_forma")
	ac.set_field("afirmacion", "as.pared")
	ac.send()
	await _wait()
	await tool.snap("anuncio_confirmar")
	ac.queue_free()
	await _wait(2)

# ------------------------------------------------------------------ telegrama y carta
func _correo() -> void:
	var sim = w.sim_at("day1_desk_T")
	await _show_hub(sim, "escritorio")
	var tc = TelegramComposer.new()
	tc.sim = sim
	tc.act_fn = func(a): return sim.apply(a)
	tc.sounds = false
	scene.add_child(tc)
	tc.open_mode("telegram")
	tc.set_to("meiringen")
	tc.set_part(0, "cornisa")
	tc.refresh()
	tc.set_part(1, "nidero")
	tc.refresh()
	await _wait()
	await tool.snap("telegrama")
	tc.close()
	tc.open_mode("letter")
	tc.set_to("watson")
	tc.set_part(0, "as.pared")
	tc.refresh()
	await _wait()
	await tool.snap("carta")
	tc.queue_free()
	await _wait(2)

# ------------------------------------------------------------------ informe
func _informe() -> void:
	var sim = w.sim_at("day2_report")
	await _show_hub(sim, "escritorio")
	var rc = ReportComposer.new()
	rc.sim = sim
	rc.act_fn = func(a): return sim.apply(a)
	rc.sounds = false
	scene.add_child(rc)
	rc.open()
	await _wait()
	await tool.snap("informe_vacio")
	rc.add_item({"kind": "clip", "id": String(w.clips.marque)})
	rc.add_item({"kind": "entry", "id": String(w.clips.practica)})
	await _wait()
	await tool.snap("informe")
	rc.open_picker(2)
	await _wait()
	await tool.snap("informe_elegir")
	rc.picker.close()
	rc.send()
	await _wait()
	await tool.snap("informe_confirmar")
	rc.queue_free()
	await _wait(2)
	sim = w.sim_at("day10_final")
	await _show_hub(sim, "escritorio")
	rc = ReportComposer.new()
	rc.sim = sim
	rc.act_fn = func(a): return sim.apply(a)
	rc.sounds = false
	scene.add_child(rc)
	rc.open()
	rc.set_mode("quemar")
	await _wait()
	await tool.snap("informe_final")
	rc.queue_free()
	await _wait(2)

# ------------------------------------------------------------------ alto contraste
func _hc() -> void:
	var ti = tool.root.get_node_or_null("ThemeInstaller")
	if ti == null:
		return
	ti.set_high_contrast(true)
	await _wait(2)
	var sim = w.sim_at("day1_watson")
	await _show_visit(sim)
	var sp = _panel(sim)
	sp.open_ask("watson", "assert")
	sp.ask_panel.choose("as.pared")
	sp.ask_panel.confirm()
	sp.open_ask("watson", "ask")
	sp.ask_panel.choose("fina")
	await _wait(12, 1.2)
	await tool.snap("hc_visita")
	sp.queue_free()
	sim = w.sim_at("day10_confront")
	await _show_shop(sim)
	var cv = ConfrontationView.new()
	cv.sim = sim
	cv.act_fn = func(a): return sim.apply(a)
	cv.sounds = false
	scene.add_child(cv)
	cv.refresh()
	cv.refute({"kind": "clip", "id": String(w.clips.aviso)})
	cv.confirm_bar.confirm()
	await _wait(12, 1.2)
	await tool.snap("hc_conf")
	cv.queue_free()
	sim = w.sim_at("day2_report")
	await _show_hub(sim)
	var rc = ReportComposer.new()
	rc.sim = sim
	rc.act_fn = func(a): return sim.apply(a)
	rc.sounds = false
	scene.add_child(rc)
	rc.open()
	rc.add_item({"kind": "clip", "id": String(w.clips.marque)})
	await _wait()
	await tool.snap("hc_informe")
	rc.queue_free()
	ti.set_high_contrast(false)
	await _wait(2)

# ------------------------------------------------------------------ mouse
# La ventana recién creada puede moverse o no tener el foco (warp_mouse es relativo a la ventana con foco).
func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	var last := DisplayServer.window_get_position()
	var still := 0
	for _i in 120:
		await tool.frames(1)
		var p := DisplayServer.window_get_position()
		still = still + 1 if p == last else 0
		last = p
		if still >= 10 and DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _sync_mouse(pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		Input.warp_mouse(pos)
		await tool.frames(1)
		if tool.root.get_viewport().get_mouse_position().distance_to(pos) < 1.5:
			return
	print("aviso: el cursor no llegó a ", pos, " (está en ", tool.root.get_viewport().get_mouse_position(), ")")

func _mb(pos: Vector2, pressed: bool) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)

func _mm(pos: Vector2, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = mask
	Input.parse_input_event(e)
