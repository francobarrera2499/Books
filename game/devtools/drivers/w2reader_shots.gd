# Driver de capturas W2-READER (ARCHITECTURE §9.4, §10 W2-READER).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2reader res://devtools/drivers/w2reader_shots.gd
# Capturas (.work/shots/w2reader_<nombre>.png):
#   d05            D05 de data_min (Journal de Genève, papel hueso)
#   d05_zoom       D05 a 220 % con la tijera y una selección en curso
#   carta          carta a máquina (Remington, papel del Diógenes recortado) de tests/fixtures/reader
#   carta_lupa     la misma con la lupa sobre «s», «t», «e»
#   carta_regla    la misma con la regla y «Anotar la medida»
#   rasante_izq / rasante_der   D29b de data_min con la lámpara a la izquierda y a la derecha de los surcos
#   rasante_sin    D29b con la lámpara lejos (los surcos no se ven) · rasante_lupa  la lupa sobre los surcos
#   telegrama      telegrama (fixture) · strand_p2 (D03 de data_min, hoja 2 de 2) · galerada (D02, registro, <sc>, <del>)
#   times          número del Times (fixture, texto largo)
#   d05_hc / carta_hc / rasante_hc   alto contraste
#   error          línea de Lisle tras un recorte que cruza un punto
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const ViewModel = preload("res://ui/reader/view_model.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const Repo = preload("res://core/data/data_repo.gd")

var tool
var reader
var mini
var fx

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	mini = Repo.load_dir("res://tests/fixtures/data_min")
	fx = Repo.load_dir("res://tests/fixtures/reader")
	for e in fx.errors():
		print("FIXTURE ERR ", e)
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = _fake_act
	scene.add_child(reader)
	var ti = tool.root.get_node("ThemeInstaller")
	await tool.frames(2)
	await _settle_window()

	_open(mini, "D05@BM")
	await tool.frames(6)
	await tool.snap("d05")
	reader.set_tijera(true)
	reader.set_zoom(2.2, _word_pos(0, "Los guías"))
	await tool.frames(3)
	await _drag_select(0, "Los guías", "ningún cuerpo")
	await tool.snap("d05_zoom")
	_release()
	await tool.frames(4)
	await tool.snap("d05_tira")
	await tool.frames(30)
	reader.set_tijera(false)

	_open(fx, "D25@L1")
	await tool.frames(6)
	await tool.snap("carta")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	var at := _word_pos(0, "ahorraré")
	_mm(at, 0)
	await tool.frames(4)
	await tool.snap("carta_lupa")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	await tool.frames(4)
	await tool.snap("carta_regla")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla

	_open(mini, "D29b@L4")
	await tool.frames(4)
	var r: RichTextLabel = reader.block_rtl(0)
	var line := r.get_character_line(r.get_parsed_text().find("Recibí"))
	var gy: float = (r.get_global_transform_with_canvas() * Vector2(0, r.get_line_offset(line) + r.get_line_height(line) * 0.5)).y
	var left: float = (r.get_global_transform_with_canvas() * Vector2(0, 0)).x
	var right: float = (r.get_global_transform_with_canvas() * Vector2(r.size.x, 0)).x
	_mm(Vector2(left - 40.0, gy - 30.0), 0)
	await tool.frames(3)
	await tool.snap("rasante_izq")
	_mm(Vector2(right + 40.0, gy + 30.0), 0)
	await tool.frames(3)
	await tool.snap("rasante_der")
	_mm(Vector2(maxf(5.0, left - 900.0), maxf(5.0, gy - 600.0)), 0)
	reader.point_at(Vector2(left - 900.0, gy - 600.0))
	await tool.frames(3)
	await tool.snap("rasante_sin")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla
	_mm(Vector2(left + 150.0, gy + 6.0), 0)
	await tool.frames(4)
	await tool.snap("rasante_lupa")
	pass  # GDD_v2 §C.4: el lector ya no tiene lupa ni regla

	_open(fx, "D27@L1")
	await tool.frames(4)
	await tool.snap("telegrama")
	_open(mini, "D03@Crane")
	await tool.frames(3)
	reader.go_page(1)
	await tool.frames(4)
	await tool.snap("strand_p2")
	_open(mini, "D02@L1")
	await tool.frames(4)
	await tool.snap("galerada")
	_open(fx, "D15.0327@L1")
	await tool.frames(4)
	await tool.snap("times")

	ti.set_high_contrast(true)
	await tool.frames(2)
	_open(mini, "D05@BM")
	await tool.frames(4)
	await tool.snap("d05_hc")
	_open(fx, "D25@L1")
	await tool.frames(4)
	await tool.snap("carta_hc")
	_open(mini, "D29b@L4")
	await tool.frames(4)
	await tool.snap("rasante_hc")
	ti.set_high_contrast(false)
	await tool.frames(2)

	_open(mini, "D05@BM")
	reader.set_tijera(true)
	await tool.frames(3)
	await _drag_select(0, "uno solo", "Los guías")
	_release()
	await tool.frames(30)
	await tool.snap("error")
	reader.close()
	await tool.frames(2)

func _open(repo, ref: String) -> void:
	var v := ViewModel.from_repo(repo, ref)
	if v.is_empty():
		print("SIN VISTA ", ref)
		return
	reader.open_view(v)

func _fake_act(a: Dictionary) -> Dictionary:
	print("ACT ", a)
	if a.t == "clip_text":
		var pt: Dictionary = reader.page.parsed[int(a.src.block)]
		var pv := SelectionMapper.preview(pt, int(a.from), int(a.len))
		if not pv.ok:
			return {"ok": false, "err": pv.err}
		return {"ok": true, "clip": "RC0001", "text": pv.text}
	return {"ok": true, "clip": "RC0002", "text": "Mide 219 por 178 milímetros."}

# Posición (canvas) del inicio de la palabra `w` en el bloque i (texto de una sola fuente por línea).
func _word_pos(i: int, w: String, end := false) -> Vector2:
	var r: RichTextLabel = reader.block_rtl(i)
	var plain := r.get_parsed_text()
	var k := plain.find(w)
	if end:
		k += w.length()
	var line := r.get_character_line(maxi(0, k - (1 if end else 0)))
	var lr: Vector2i = r.get_line_range(line)
	var f: Font = r.get_theme_font("normal_font")
	var fs: int = r.get_theme_font_size("normal_font_size")
	var x := f.get_string_size(plain.substr(lr.x, k - lr.x), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := r.get_line_offset(line) + r.get_line_height(line) * 0.5
	return r.get_global_transform_with_canvas() * Vector2(x + (-3.0 if end else 3.0), y)

func _drag_select(i: int, a: String, b: String) -> void:
	var p0 := _word_pos(i, a)
	var p1 := _word_pos(i, b, true)
	_mm(p0, 0)
	await tool.frames(1)
	await _sync_mouse(p0)
	_mb(p0, true)
	await tool.frames(1)
	for k in range(1, 13):
		_mm(p0.lerp(p1, float(k) / 12.0))
		await tool.frames(1)
	await _sync_mouse(p1)
	await tool.create_timer(0.15).timeout
	await tool.frames(2)
	_last = p1

var _last := Vector2.ZERO

func _release() -> void:
	_mb(_last, false)

# Ventana quieta y con foco antes de mover el cursor del sistema (ver w2reader_t19.gd).
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

# Con ventana, RichTextLabel actualiza la selección con la posición real del mouse: se mueve el cursor del sistema
# (Input.warp_mouse) y además se inyecta el evento (Input.parse_input_event). En headless warp_mouse no hace nada.
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
