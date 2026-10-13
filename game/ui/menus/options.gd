# ui/menus/options.gd — opciones y accesibilidad (GDD§14.7, ARCHITECTURE §6.1). Dueño: W3-SHELL. Panel modal.
# Tamaño de letra (ThemeInstaller.set_text_scale 0,8–1,6), alto contraste, subtítulos (encendidos por defecto),
# volumen de ambiente y de efectos (buses Amb/Sfx), pantalla completa. Se guardan en user://opciones.cfg (cae en
# .work/appdata por godot.sh) y se aplican al arrancar (apply_saved). open() · close() · señal closed.
extends Control

signal closed

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const PATH := "user://opciones.cfg"

var shell = null
var sheet: PanelContainer
var _building := false

func _init() -> void:
	name = "Options"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _root(n: String) -> Node:
	var ml = Engine.get_main_loop()
	return ml.root.get_node_or_null(n) if ml is SceneTree else null

static func current() -> Dictionary:
	var ti := _root("ThemeInstaller")
	var au := _root("Audio")
	var o := {"text_scale": 1.0, "high_contrast": false, "subtitles": true, "amb_db": -3.0, "sfx_db": 0.0, "fullscreen": false}
	if ti != null:
		o.text_scale = float(ti.text_scale)
		o.high_contrast = bool(ti.high_contrast)
	if au != null:
		o.subtitles = bool(au.subtitles_on)
	var ia := AudioServer.get_bus_index("Amb")
	if ia >= 0:
		o.amb_db = AudioServer.get_bus_volume_db(ia)
	var isx := AudioServer.get_bus_index("Sfx")
	if isx >= 0:
		o.sfx_db = AudioServer.get_bus_volume_db(isx)
	return o

static func apply(o: Dictionary) -> void:
	var ti := _root("ThemeInstaller")
	var au := _root("Audio")
	if ti != null:
		if absf(float(ti.text_scale) - float(o.get("text_scale", 1.0))) > 0.001:
			ti.set_text_scale(float(o.get("text_scale", 1.0)))
		if bool(ti.high_contrast) != bool(o.get("high_contrast", false)):
			ti.set_high_contrast(bool(o.get("high_contrast", false)))
	if au != null:
		au.subtitles_on = bool(o.get("subtitles", true))
	for pair in [["Amb", "amb_db"], ["Sfx", "sfx_db"]]:
		var i := AudioServer.get_bus_index(String(pair[0]))
		if i >= 0 and o.has(pair[1]):
			AudioServer.set_bus_volume_db(i, float(o[pair[1]]))

static func save(o: Dictionary) -> void:
	var cf := ConfigFile.new()
	for k in o:
		cf.set_value("opciones", String(k), o[k])
	cf.save(PATH)

static func apply_saved() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	var o := current()
	for k in o:
		o[k] = cf.get_value("opciones", String(k), o[k])
	apply(o)
	if bool(o.get("fullscreen", false)) and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func open() -> void:
	_build()
	visible = true
	modulate.a = 0.0
	Widgets.fade(self, 1.0, 0.2)

func close() -> void:
	if not visible:
		return
	save(current_with_fullscreen())
	visible = false
	closed.emit()

func current_with_fullscreen() -> Dictionary:
	var o := current()
	o.fullscreen = DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return o

func _build() -> void:
	_building = true
	for c in get_children():
		c.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(Paper.INKS["negra"], 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	sheet = Widgets.sheet("cuaderno", {"pad": 30})
	sheet.custom_minimum_size = Vector2(520, 0)
	cc.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	sheet.add_child(v)
	v.add_child(Widgets.heading(Widgets.t("shell.opt.title")))
	v.add_child(Widgets.rule())
	var o := current()
	v.add_child(_slider(Widgets.t("shell.opt.letra"), 0.8, 1.6, 0.1, float(o.text_scale), func(x):
		var ti := _root("ThemeInstaller")
		if ti != null and not _building:
			ti.set_text_scale(x)))
	v.add_child(_check(Widgets.t("shell.opt.contraste"), bool(o.high_contrast), func(on):
		var ti := _root("ThemeInstaller")
		if ti != null:
			ti.set_high_contrast(on)))
	v.add_child(_check(Widgets.t("shell.opt.subtitulos"), bool(o.subtitles), func(on):
		var au := _root("Audio")
		if au != null:
			au.subtitles_on = on))
	v.add_child(_slider(Widgets.t("shell.opt.ambiente"), -40.0, 6.0, 1.0, float(o.amb_db), func(x): _bus("Amb", x)))
	v.add_child(_slider(Widgets.t("shell.opt.efectos"), -40.0, 6.0, 1.0, float(o.sfx_db), func(x): _bus("Sfx", x)))
	if DisplayServer.get_name() != "headless":
		v.add_child(_check(Widgets.t("shell.opt.pantalla"), DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(on):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)))
	v.add_child(Widgets.rule())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	if shell != null and shell.screen_id == "game":
		row.add_child(Widgets.ink_button(Widgets.t("shell.opt.titulo"), func():
			close()
			shell.quit_to_title()))
	row.add_child(Widgets.button(Widgets.t("kit.close"), close))
	_building = false

func _bus(n: String, db: float) -> void:
	var i := AudioServer.get_bus_index(n)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, db)

func _slider(label: String, lo: float, hi: float, step: float, val: float, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var l := Widgets.label(label, "")
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.custom_minimum_size = Vector2(240, 24)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.drag_ended.connect(func(_c): cb.call(s.value))
	h.add_child(s)
	return h

func _check(label: String, on: bool, cb: Callable) -> Control:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	return c
