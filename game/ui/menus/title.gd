# ui/menus/title.gd — pantalla de título (ARCHITECTURE §2.3). Dueño: W3-SHELL.
# Sobre la buhardilla de noche (el 3D de fondo, con su grabado): una galerada con el título y el menú en tinta.
# Continuar (si hay partida) · Partida nueva (si hay partida: confirmación en dos pasos, se pierde lo guardado) ·
# Opciones · Salir. Tras el primer cuadro genera el banco de sonido (Audio.warm, §2.2) salvo --fast.
extends Control

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

var shell = null
var sheet: PanelContainer
var menu: VBoxContainer
var _confirm: Control = null

func _init() -> void:
	name = "Title"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	var shade := ColorRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(Paper.INKS["negra"], 0.18)
	add_child(shade)
	sheet = Widgets.sheet("strand", {"pad": 40})
	sheet.custom_minimum_size = Vector2(440, 0)
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var over := Widgets.label(Widgets.t("shell.title.over"), "SourceLine")
	over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over.uppercase = true
	v.add_child(over)
	var t := Widgets.heading(Widgets.t("shell.title.name"))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", int(round(_px("title") * 1.55)))
	v.add_child(t)
	var sub := Widgets.label(Widgets.t("shell.title.sub"), "Caption")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(Widgets.rule())
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 4)
	v.add_child(menu)
	var foot := Widgets.marginal(Widgets.t("shell.title.pie"))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	_build_menu()
	get_viewport().size_changed.connect(_place)
	_place.call_deferred()
	_warm.call_deferred()

func _px(kind: String) -> int:
	var ti := Widgets.ti()
	return 34 if ti == null else int(ti.px(kind))

func _place() -> void:
	var vs := get_viewport().get_visible_rect().size
	sheet.reset_size()
	sheet.position = Vector2(maxf(30.0, vs.x * 0.08), maxf(20.0, (vs.y - sheet.size.y) * 0.5)).floor()

func _has_save() -> bool:
	# una partida ya terminada (epílogo cerrado) no se ofrece para continuar (W4)
	if shell != null and shell.has_method("can_continue"):
		return bool(shell.can_continue())
	var g = get_tree().root.get_node_or_null("Game")
	return g != null and bool(g.has_save())

func _old_save() -> bool:
	var g = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return g != null and g.has_method("save_too_old") and bool(g.save_too_old())

func _build_menu() -> void:
	for c in menu.get_children():
		c.queue_free()
	if _has_save():
		menu.add_child(_item(Widgets.t("shell.title.continuar"), _continue))
	elif _old_save():
		# GDD_v3 §1.7: guardado de antes de la v3: se avisa y sólo se ofrece partida nueva
		var note := Widgets.marginal(Widgets.t("v3core.save.otra_version"))
		note.name = "OtraVersion"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		menu.add_child(note)
	menu.add_child(_item(Widgets.t("shell.title.nueva"), _new))
	menu.add_child(_item(Widgets.t("shell.title.opciones"), _options))
	menu.add_child(_item(Widgets.t("shell.title.salir"), _quit))

func _item(text: String, cb: Callable) -> Button:
	var b := Widgets.ink_button(text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b

func _continue() -> void:
	if shell == null:
		return
	# guardado de otra versión del texto: se dice antes y se elige (el registro original queda aparte, partida.<hash>.jsonl)
	var g = get_tree().root.get_node_or_null("Game")
	if g != null and g.has_method("save_other_version") and bool(g.save_other_version()):
		if _confirm != null and is_instance_valid(_confirm):
			_confirm.queue_free()
		var c := Widgets.confirm(Widgets.t("shell.title.otra_version"), Widgets.t("shell.title.seguir"), Widgets.t("shell.title.volver"), Widgets.t("shell.title.continuar"))
		_confirm = c
		add_child(c)
		c.reset_size()
		var vs := get_viewport().get_visible_rect().size
		c.position = ((vs - c.size) * 0.5).floor()
		c.decided.connect(func(ok):
			c.queue_free()
			_confirm = null
			if ok and shell != null:
				shell.continue_game())
		return
	shell.continue_game()

func _new() -> void:
	if not _has_save() and not _old_save():
		if shell != null:
			shell.new_game()
		return
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	var c := Widgets.confirm(Widgets.t("shell.title.nueva_aviso"), Widgets.t("shell.title.nueva_ok"), Widgets.t("kit.confirm.back"), Widgets.t("shell.title.nueva"))
	_confirm = c
	add_child(c)
	c.reset_size()
	var vs := get_viewport().get_visible_rect().size
	c.position = ((vs - c.size) * 0.5).floor()
	c.decided.connect(func(ok):
		c.queue_free()
		_confirm = null
		if ok and shell != null:
			shell.new_game())

func _options() -> void:
	if shell != null:
		shell.open_panel("options")

func _quit() -> void:
	get_tree().quit()

func back() -> bool:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
		_confirm = null
		return true
	return false

func _warm() -> void:
	if shell == null or shell.fast or not shell.sounds:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var au = get_tree().root.get_node_or_null("Audio")
	if au != null and au.has_method("warm") and not (au.has_method("is_warm") and au.is_warm()):
		au.warm()
	if shell != null:
		shell.ambience("L1", "night")
