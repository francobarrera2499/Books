# T19 con ventana (W2-READER, ARCHITECTURE §9.2, §10): arrastre real de la tijera a 1600×900.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2reader_t19 res://devtools/drivers/w2reader_t19.gd
# Por cada caso: mueve el cursor del sistema (Input.warp_mouse; con ventana RichTextLabel arrastra la selección con la
# posición real del mouse) e inyecta los eventos con Input.parse_input_event; Game.act se sustituye por un act_fn que
# resuelve como el sim (ClipRules.snap + inherit). Imprime «T19V PASS|FAIL <caso> …» y «T19V: n/m» y captura cada caso
# con la selección en curso (.work/shots/w2reader_t19_<caso>.png).
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const Repo = preload("res://core/data/data_repo.gd")

var tool
var reader
var acts: Array = []
var passed := 0
var total := 0

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var mini = Repo.load_dir("res://tests/fixtures/data_min")
	var fx = Repo.load_dir("res://tests/fixtures/reader")
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = _act
	scene.add_child(reader)
	await tool.frames(2)
	await _settle_window()
	print("T19V ventana ", DisplayServer.window_get_size(), " ", DisplayServer.get_name(), " foco=", DisplayServer.window_is_focused())
	await _case("d05", mini, "D05@BM", 1.0, "Los guías no hallaron ningún cuerpo", "aucun_corps", "a:refuta_rio_cuerpo")
	await _case("d05_zoom", mini, "D05@BM", 2.4, "Más arriba hay una cornisa que no se ve desde el sendero, «une corniche que l'on ne voit pas du sentier»", "corniche", "a:cornisa_existe")
	await _case("carta", fx, "D25@L1", 1.0, "Asiento 214, martes por la mañana: pidió usted el Journal de Genève del 6 de mayo de 1891.", "ancla", "a:ancla_kbm")
	await _case("rasante", mini, "D29b@L4", 1.0, "Recibí del señor Mycroft los papeles del 3 de mayo", "surcos", "a:dispuso_bienes")
	await _case("galerada", mini, "D02@L1", 1.0, "En la roca, a la altura del hombro, una raspadura reciente", "clausula", "a:raspadura_registrada")
	await _case("times", fx, "D15.0327@L1", 1.0, "Se busca testigo de lo ocurrido en la cascada del Reichenbach", "aviso_lisle", "a:acto_kt")
	print("T19V: %d/%d" % [passed, total])
	reader.close()
	await tool.frames(2)

func _act(a: Dictionary) -> Dictionary:
	acts.append(a)
	if a.t != "clip_text":
		return {"ok": false, "err": "desconocido"}
	var pt: Dictionary = reader.view.pages[int(a.src.part)][int(a.src.block)].parsed
	var pv := SelectionMapper.preview(pt, int(a.from), int(a.len))
	if not pv.ok:
		return {"ok": false, "err": pv.err}
	return {"ok": true, "clip": "RC%04d" % acts.size(), "text": pv.text}

func _case(name: String, repo, ref: String, zoom: float, text: String, tramo: String, tag: String) -> void:
	total += 1
	acts.clear()
	reader.open_view(ViewModel.from_repo(repo, ref))
	reader.set_tijera(true)
	await tool.frames(3)
	var r: RichTextLabel = reader.block_rtl(0)
	var plain := r.get_parsed_text()
	var from := plain.find(text)
	if zoom != 1.0:
		reader.set_zoom(zoom, r.get_global_transform_with_canvas() * SelectionMapper.char_local_pos(r, from))
		await tool.frames(2)
	var pts := SelectionMapper.drag_points(r, from, from + text.length())
	_mm(pts[0], 0)
	await tool.frames(2)
	await _sync_mouse(pts[0])
	_mb(pts[0], true)
	await tool.frames(2)
	for i in range(1, 13):
		_mm(pts[0].lerp(pts[1], float(i) / 12.0))
		await tool.frames(1)
	await _sync_mouse(pts[1])
	await tool.create_timer(0.2).timeout
	await tool.frames(2)
	await tool.snap("t19_" + name)
	_mb(pts[1], false)
	await tool.frames(4)
	var msg := ""
	var ok := false
	if acts.size() != 1:
		msg = "acciones=%d" % acts.size()
	else:
		var a: Dictionary = acts[0]
		var pv := SelectionMapper.preview(reader.view.pages[0][0].parsed, int(a.from), int(a.len))
		ok = a.src == {"kind": "doc", "ref": ref, "part": 0, "block": 0} and pv.tramo == tramo and pv.tags.has(tag)
		msg = "src=%s from=%d len=%d tramo=%s tags=%s «%s»" % [str(a.src), a.from, a.len, pv.tramo, str(pv.tags), pv.text.left(50)]
	if ok:
		passed += 1
	print("T19V %s %s %s" % ["PASS" if ok else "FAIL", name, msg])
	reader.set_tijera(false)

# La ventana recién creada puede moverse (centrado) o no tener el foco: warp_mouse es relativo a la ventana con foco y
# RichTextLabel extiende la selección con la posición REAL del mouse. Se espera a que la ventana quede quieta y con
# foco antes del primer caso (la primera corrida tras abrir la ventana fallaba de vez en cuando por esto).
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

# Mueve el cursor del sistema a pos y espera a que la ventana lo reporte ahí (hasta 30 frames).
func _sync_mouse(pos: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		Input.warp_mouse(pos)
		await tool.frames(1)
		if tool.root.get_viewport().get_mouse_position().distance_to(pos) < 1.5:
			return
	print("T19V aviso: el cursor no llegó a ", pos, " (está en ", tool.root.get_viewport().get_mouse_position(), ")")

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
