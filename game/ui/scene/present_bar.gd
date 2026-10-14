# ui/scene/present_bar.gd — segundo paso de presentar (y de pagar o encargar): la frase exacta y «Mostrar» / «Guardar».
# Dueño: W3-SCENEUI. GDD §8.7 (botón Present de Ace Attorney), ARCHITECTURE §5.7, §6.1 (dos pasos), §6.7.
# Uso: var b = PresentBar.new(link); add_child(b)
#   open_present(char, label, item {kind:"clip"|"pregunta", id}) -> frase = q_preview({"t":"present",…})
#   open_pay(char, label, amounts := [6, 12, 30]) -> elegir monedas; frase = q_preview({"t":"pay",…})
#   open_task(char, label, tasks) -> elegir encargo; frase = q_preview({"t":"task",…})
#   open_confront(step, char, label, item) -> refutar en la confrontación: acción {"t":"confront","step","item"}; la frase
#     previa es la de presentar al librero (q_preview present; la confrontación no registra la frase de Lisle)
#   confirm() (= «Mostrar» / «Dar» / «Encargar») · keep() (= «Guardar»: se retira sin costo) · action() · phrase()
# Señales: done(res) (acción aceptada) · failed(err) · closed («Guardar» o fe_volver: nada se gasta).
extends PanelContainer

signal done(res: Dictionary)
signal failed(err: String)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")

var link
var kind := ""            # present | pay | task
var char_id := ""
var char_label := ""
var item := {}
var amount_d := 0
var task := ""
var conf_step := 0
var _title: Label
var _card: PanelContainer
var _card_body: Label
var _card_src: Label
var _phrase: Label
var _choices: HFlowContainer
var _ok: Button
var _keep: Button

func _init(p_link = null) -> void:
	link = p_link if p_link != null else SimLink.new()
	name = "Presentar"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 24, "margin_v": 18, "shadow_size": 12, "shadow_y": 5})))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	_title = Widgets.small("")
	v.add_child(_title)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(250, 0)
	_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	Widgets.restyle(_card, func(): _card.add_theme_stylebox_override("panel", Paper.style("diario_hueso", {"margin": 12, "margin_v": 8, "radius": 1, "shadow_size": 4, "shadow_y": 2})))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	_card.add_child(cv)
	_card_body = Label.new()
	_card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_body.custom_minimum_size = Vector2(226, 0)
	cv.add_child(_card_body)
	_card_src = Widgets.source_line("")
	cv.add_child(_card_src)
	_card.rotation_degrees = 0.0
	h.add_child(_card)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	h.add_child(right)
	_choices = HFlowContainer.new()
	_choices.add_theme_constant_override("h_separation", 8)
	_choices.add_theme_constant_override("v_separation", 6)
	right.add_child(_choices)
	_phrase = Label.new()
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phrase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(_phrase)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 18)
	_keep = Widgets.ink_button(link.t("sceneui.present.keep"), keep)
	row.add_child(_keep)
	_ok = Widgets.button(link.t("sceneui.present.ok"), confirm)
	row.add_child(_ok)
	v.add_child(row)
	Widgets.restyle(self, _restyle_text)

func _restyle_text() -> void:
	_card_body.add_theme_font_override("font", SimLink.font("imprenta"))
	_card_body.add_theme_font_size_override("font_size", int(round(SimLink.px("doc") * 0.82)))
	_phrase.add_theme_font_override("font", SimLink.font("imprenta", true))
	_phrase.add_theme_font_size_override("font_size", SimLink.px("doc"))

func open_confront(step: int, p_char: String, p_label: String, p_item: Dictionary) -> void:
	open_present(p_char, p_label, p_item)
	kind = "confront"
	conf_step = step
	_title.text = link.t("sceneui.conf.refute.title", {"quien": SimLink.cap(char_label)})
	_update()

func open_present(p_char: String, p_label: String, p_item: Dictionary) -> void:
	_reset("present", p_char, p_label)
	item = {"kind": String(p_item.get("kind", "")), "id": String(p_item.get("id", ""))}
	var info: Dictionary = link.item_info(item)
	_card.visible = true
	var head := String(info.get("title", ""))
	_card_body.text = (head + ". " if head != "" else "") + SimLink.short(String(info.get("body", "")), 160)
	_card_src.text = String(info.get("source", ""))
	_card_src.visible = _card_src.text != ""
	_title.text = link.t("sceneui.present.title", {"quien": SimLink.cap(char_label)})
	_ok.text = link.t("sceneui.present.ok")
	_show()

func open_pay(p_char: String, p_label: String, amounts: Array = [6, 12, 30]) -> void:
	_reset("pay", p_char, p_label)
	_title.text = link.t("sceneui.pay.title", {"quien": SimLink.cap(char_label)})
	_ok.text = link.t("sceneui.pay.ok")
	var group := ButtonGroup.new()
	for a in amounts:
		var b := _choice(load("res://core/scenes/deps.gd").money(int(a)), group)
		b.set_meta("value", int(a))
		b.pressed.connect(func(): amount_d = int(a); _update())
		_choices.add_child(b)
	_show()

func open_task(p_char: String, p_label: String, tasks: Array) -> void:
	_reset("task", p_char, p_label)
	_title.text = link.t("sceneui.task.title", {"quien": SimLink.cap(char_label)})
	_ok.text = link.t("sceneui.task.ok")
	var group := ButtonGroup.new()
	for tk in tasks:
		var b := _choice(link.t("sceneui.task." + String(tk)), group)
		b.set_meta("value", String(tk))
		b.pressed.connect(func(): task = String(tk); _update())
		_choices.add_child(b)
	_show()

func _choice(text: String, group: ButtonGroup) -> Button:
	var b := Widgets.button(text)
	b.toggle_mode = true
	b.button_group = group
	return b

func choose_amount(d: int) -> void:
	amount_d = d
	_sync_choice(d)
	_update()

func choose_task(t: String) -> void:
	task = t
	_sync_choice(t)
	_update()

# Elegir por API (drivers/tests) también deja hundido el botón correspondiente, como el clic.
func _sync_choice(v) -> void:
	for b in _choices.get_children():
		if b is Button and b.has_meta("value"):
			(b as Button).set_pressed_no_signal(b.get_meta("value") == v)

func chosen_button_text() -> String:
	for b in _choices.get_children():
		if b is Button and (b as Button).button_pressed:
			return (b as Button).text
	return ""

func action() -> Dictionary:
	match kind:
		"present":
			return {"t": "present", "char": char_id, "item": item.duplicate()}
		"pay":
			return {"t": "pay", "char": char_id, "amount_d": amount_d} if amount_d > 0 else {}
		"task":
			return {"t": "task", "char": char_id, "task": task} if task != "" else {}
		"confront":
			return {"t": "confront", "step": conf_step, "item": item.duplicate()}
	return {}

func phrase() -> String:
	if kind == "confront":
		return link.preview({"t": "present", "char": char_id, "item": item.duplicate()})
	var a := action()
	return link.preview(a) if not a.is_empty() else ""

func confirm() -> void:
	var a := action()
	if a.is_empty():
		return
	var res: Dictionary = link.act(a)
	if bool(res.get("ok", false)):
		visible = false
		done.emit(res)
	else:
		failed.emit(String(res.get("err", "")))

func keep() -> void:
	visible = false
	closed.emit()

func _reset(k: String, p_char: String, p_label: String) -> void:
	kind = k
	char_id = p_char
	char_label = p_label
	item = {}
	amount_d = 0
	task = ""
	_card.visible = false
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()

func _show() -> void:
	_choices.visible = kind == "pay" or kind == "task"
	visible = true
	_update()
	link.play("sfx.papel")

func _update() -> void:
	var ph := phrase()
	if ph == "":
		_phrase.text = link.t("sceneui.%s.pick" % kind) if link.has_t("sceneui.%s.pick" % kind) else ""
		_phrase.add_theme_color_override("font_color", Paper.ink("tenue"))
		_ok.disabled = true
	else:
		_phrase.text = "—" + ph
		_phrase.add_theme_color_override("font_color", Paper.ink("negra"))
		_ok.disabled = false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		keep()
		accept_event()
