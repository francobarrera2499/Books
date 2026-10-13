# ui/kit/confirm.gd — segundo paso de toda confirmación comprometida (§6.1). Dueño: W1-THEME.
# Uso: var c = Widgets.confirm("Texto final exacto", "Enviar", "Volver"); c.decided.connect(func(ok): ...)
# Muestra el texto final (String → RichTextLabel DocBody; Control → se inserta tal cual) y dos acciones:
# «Volver» (InkButton) y la confirmación (Button). Emite decided(ok) una sola vez. No maneja Esc/clic derecho:
# eso es de input_router (fe_volver = pop), que debe tratar el pop como «Volver».
extends PanelContainer

signal decided(ok: bool)

var body: Control
var ok_button: Button
var back_button: Button
var _done := false

func _init(p_body = "", ok_text := "Confirmar", back_text := "Volver", title := "") -> void:
	theme_type_variation = "ConfirmPanel"
	custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	if title != "":
		var h := Label.new()
		h.theme_type_variation = "DocTitle"
		h.text = title
		v.add_child(h)
	if p_body is Control:
		body = p_body
	else:
		var r := RichTextLabel.new()
		r.theme_type_variation = "DocBody"
		r.bbcode_enabled = false
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.selection_enabled = false
		r.context_menu_enabled = false
		r.shortcut_keys_enabled = false
		r.text = str(p_body)
		# sin ancho mínimo, fit_content+autowrap mide a ancho 0 (una letra por renglón) y el panel queda más alto que la pantalla
		r.custom_minimum_size = Vector2(400, 0)
		body = r
	v.add_child(body)
	var rule := HSeparator.new()
	rule.theme_type_variation = "InkRule"
	v.add_child(rule)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	back_button = Button.new()
	back_button.theme_type_variation = "InkButton"
	back_button.text = back_text
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(_decide.bind(false))
	row.add_child(back_button)
	ok_button = Button.new()
	ok_button.text = ok_text
	ok_button.focus_mode = Control.FOCUS_NONE
	ok_button.pressed.connect(_decide.bind(true))
	row.add_child(ok_button)

# Los llamadores hacen reset_size() y centran en el mismo cuadro, antes de que el texto conozca su ancho.
# Un cuadro después se re-mide y se re-centra (mismo centro, dentro de la pantalla); invisible hasta entonces.
func _ready() -> void:
	modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var center := position + size * 0.5
	reset_size()
	var vs := get_viewport().get_visible_rect().size
	# texto que no cabe: el cuerpo pasa a scroll con alto acotado (los botones siempre a la vista)
	if size.y > vs.y - 32.0 and body is RichTextLabel:
		var r := body as RichTextLabel
		var room := maxf(120.0, r.size.y - (size.y - (vs.y - 32.0)))
		r.fit_content = false
		r.scroll_active = true
		r.custom_minimum_size = Vector2(r.custom_minimum_size.x, room)
		await get_tree().process_frame
		if not is_inside_tree():
			return
		reset_size()
	var p := (center - size * 0.5).floor()
	p.x = clampf(p.x, 8.0, maxf(8.0, vs.x - size.x - 8.0))
	p.y = clampf(p.y, 8.0, maxf(8.0, vs.y - size.y - 8.0))
	if size.y > vs.y - 16.0 or size.x > vs.x - 16.0:
		p = ((vs - size) * 0.5).floor()
	position = p
	modulate.a = 1.0

func _decide(ok: bool) -> void:
	if _done:
		return
	_done = true
	decided.emit(ok)
