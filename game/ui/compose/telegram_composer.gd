# ui/compose/telegram_composer.gd — telegramas y cartas con las mismas piezas que los anuncios (GDD §8.2, ARCHITECTURE §5.7,
# §6.7). Dueño: W3-SCENEUI. CanvasLayer modal (capa 60; marco en compose_base.gd).
# Uso (Shell, escritorio): var tc = TelegramComposer.new(); add_child(tc); tc.open("telegram") | tc.open("letter")
#   (open_mode(m) = open(m); Shell: open_panel("letter", ["letter"]))
#   «Destino: ___» (Composers.mail_options "to": personas o lugares del índice, sin lugares de Londres ni secreto_camden)
#   y «Sobre: ___» de 1 a 3 piezas (mail_options "parts": entidades del índice o afirmaciones con texto de aviso); cada
#   pieza llena abre la siguiente; un campo lleno se vacía desde su propio menú. Texto final exacto: q_preview
#   (compose_telegram / compose_letter). «Enviar» -> confirmación («sale al cerrar la franja»). Telegrama: papel ante y
#   máquina en mayúsculas; carta: papel de carta y letra manuscrita.
#   API extra: mode · set_to(id) -> bool · set_part(i, id) -> bool · parts().
extends "res://ui/compose/compose_base.gd"

const Composers = preload("res://core/scenes/composers.gd")
const MAX_PARTS := 3

var mode := "telegram"
var _to: Blank
var _parts: Array = []          # [Blank]
var _parts_box: HFlowContainer

func _init() -> void:
	super()
	name = "TelegramComposer"

func open_mode(m: String) -> void:
	open(m)

func _set_arg(arg: String) -> void:
	if arg == "letter" or arg == "telegram":
		mode = arg
	if _built and sheet.has_method("set_paper"):
		sheet.set_paper(_paper())

func _paper() -> String:
	return "telegrama" if mode == "telegram" else "carta"

func _width() -> float:
	return 780.0

func _title_text() -> String:
	return link.t("sceneui.tg.title" if mode == "telegram" else "sceneui.lt.title")

func _sub_text() -> String:
	return link.t("sceneui.tg.sub" if mode == "telegram" else "sceneui.lt.sub")

func _send_label() -> String:
	return link.t("sceneui.mail.send")

func _confirm_title() -> String:
	return _title_text()

func _confirm_extra() -> String:
	return link.t("sceneui.mail.sale")

func _final_slot() -> String:
	return "maquina" if mode == "telegram" else "manuscrito"

func _stamp_text(_res: Dictionary) -> String:
	return link.t("sceneui.mail.sello")

func _build_body(v: VBoxContainer) -> void:
	_to = make_blank("___")
	_to.name = "Destino"
	_to.clear_text = link.t("sceneui.mail.remove")
	v.add_child(blank_row(link.t("sceneui.mail.to"), _to))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = link.t("sceneui.mail.parts") + ":"
	l.custom_minimum_size = Vector2(120, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(l)
	_parts_box = HFlowContainer.new()
	_parts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_parts_box.add_theme_constant_override("h_separation", 10)
	_parts_box.add_theme_constant_override("v_separation", 4)
	h.add_child(_parts_box)
	v.add_child(h)
	for i in MAX_PARTS:
		var b := make_blank("___")
		b.name = "Pieza%d" % i
		b.clear_text = link.t("sceneui.mail.remove")
		_parts.append(b)
		_parts_box.add_child(b)

func _on_open() -> void:
	_to.set_value("")
	for b in _parts:
		b.set_value("")
	_final_restyle_paper()

func _final_restyle_paper() -> void:
	_style_final()

func set_to(id: String) -> bool:
	return _to.set_value(id)

func set_part(i: int, id: String) -> bool:
	if i < 0 or i >= _parts.size():
		return false
	return _parts[i].set_value(id)

func parts() -> Array:
	var out: Array = []
	for b in _parts:
		if String(b.value) != "" and not out.has(String(b.value)):
			out.append(String(b.value))
	return out

func _refresh_body() -> void:
	var r = link.repo()
	var st = link.st()
	var to_opts: Array = Composers.mail_options(st, r, "to") if r != null and st != null else []
	var part_opts: Array = Composers.mail_options(st, r, "parts") if r != null and st != null else []
	_to.set_options(to_opts)
	var used := parts()
	var show_next := true
	for i in _parts.size():
		var b: Blank = _parts[i]
		var own := String(b.value)
		var opts: Array = []
		for o in part_opts:
			if String(o.id) == own or not used.has(String(o.id)):
				opts.append(o)
		b.set_options(opts)
		b.visible = own != "" or show_next
		if own == "":
			show_next = false
	for b in _parts:
		b.add_theme_font_override("font", SimLink.font("imprenta"))

func _action() -> Dictionary:
	var to := String(_to.value)
	var ps := parts()
	if to == "" or ps.is_empty():
		return {}
	return {"t": "compose_telegram" if mode == "telegram" else "compose_letter", "to": to, "parts": ps}
