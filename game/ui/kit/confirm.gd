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

func _decide(ok: bool) -> void:
	if _done:
		return
	_done = true
	decided.emit(ok)
