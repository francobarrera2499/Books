# ui/epilogue/credits.gd — colofón sobre el sonido de la tijera (W4-EPILOGUE; GDD §12.3, ARCHITECTURE §2.3 Credits).
# Cada renglón del colofón (ui_text epilogo.creditos.NN de W3-CT-LISLE) es una tira de papel recortada que se pega en
# la hoja, una por corte de tijera (sfx.tijera; el subtítulo «un corte de tijera» lo da Audio). Sin música. Clic = la
# tira siguiente ya; skip() (Esc) = todas y termina. Al final, una pausa y finished. Animaciones ≤0,4 s, sin rebote.
#   open(sim, shell) · start() · step() -> bool · skip() · finished · strips() -> Array (tests)
extends Control

signal finished

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const Model = preload("res://ui/epilogue/epilogue_model.gd")

const STEP_S := 1.7
const HOLD_S := 3.0
const MAX_W := 620.0

var sim = null
var shell = null
var fast := false
var lines: Array = []
var _i := 0
var _done := false
var _box: VBoxContainer
var _timer: Timer

# Tira de papel cortada a tijera: bordes laterales apenas dentados, sombra corta.
class Strip extends PanelContainer:
	var seed := 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", Paper.empty([18, 7, 18, 8]))
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hc := Paper.hc_on()
		if not hc:
			draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.28))
		var pts := PackedVector2Array()
		var n := maxi(3, int(r.size.y / 6.0))
		for k in n + 1:
			var y := r.size.y * float(k) / float(n)
			pts.append(Vector2(_j(k, 0) * 1.6, y))
		for k in range(n, -1, -1):
			var y := r.size.y * float(k) / float(n)
			pts.append(Vector2(r.size.x - _j(k, 1) * 1.6, y))
		draw_colored_polygon(pts, Paper.paper("strand"))
		if not hc:
			draw_texture_rect(Paper.grain_texture(), r, true, Color(1, 1, 1, 0.06))
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(0, 0, 0), 1.0)
	func _j(k: int, side: int) -> float:
		return absf(sin(float(seed * 31 + k * 7 + side * 13) * 1.37))

func _init() -> void:
	name = "Creditos"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("16120e")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	_box = VBoxContainer.new()
	_box.name = "Hoja"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 9)
	cc.add_child(_box)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)

func open(p_sim = null, p_shell = null) -> void:
	sim = p_sim
	shell = p_shell
	if shell != null and "fast" in shell:
		fast = bool(shell.fast)
	lines = Model.credits(sim)

func start() -> void:
	_i = 0
	_done = false
	if lines.is_empty():
		_finish.call_deferred()
		return
	step()

func strips() -> Array:
	return _box.get_children().filter(func(c): return c is Strip)

# Pega la tira siguiente. false si ya no quedan.
func step() -> bool:
	if _i >= lines.size():
		return false
	var parsed: Dictionary = lines[_i]
	var big := _i < 2
	var s := Strip.new()
	s.seed = _i + 3
	s.name = "Tira%02d" % (_i + 1)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rtl := TextBuilder.make_rtl("imprenta")
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ti := TextBuilder.ti_node()
	var px: int = (ti.px("title") if big else ti.px("small") + 1) if ti != null else (34 if big else 16)
	if _i == 0:
		px = int(round(float(px) * 0.62))
	TextBuilder.build(rtl, parsed, {"slot": "imprenta", "size": px})
	var f: Font = rtl.get_theme_font("normal_font")
	var natural := f.get_string_size(String(parsed.get("plain", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 8.0
	if big:
		# títulos (versalitas: más anchas que la medida simple): un solo renglón
		rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
		var has_sc := (parsed.get("styles", []) as Array).any(func(st): return String(st.get("kind", "")) == "sc")
		rtl.custom_minimum_size = Vector2(natural * (1.32 if has_sc else 1.0) + 12.0, 0)
	else:
		rtl.custom_minimum_size = Vector2(minf(MAX_W, natural), 0)
	s.add_child(rtl)
	_box.add_child(s)
	_i += 1
	_snip()
	if not fast and is_inside_tree():
		s.modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
	if _i < lines.size():
		_wait(STEP_S)
	else:
		_wait(HOLD_S)
	return true

func _snip() -> void:
	if shell != null and shell.has_method("play"):
		shell.play("sfx.tijera")

func _wait(s: float) -> void:
	if fast or not is_inside_tree():
		return
	_timer.start(s)

func _on_timer() -> void:
	if _done:
		return
	if not step():
		_finish()

func skip() -> void:
	while step():
		pass
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	_timer.stop()
	finished.emit()

func click() -> void:
	if _done:
		return
	_timer.stop()
	if not step():
		_finish()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		click()
