# ui/compose/report_composer.gd — el informe a Moran: sobre con tres ranuras (GDD §7.3, ARCHITECTURE §5.7, §6.7).
# Dueño: W3-SCENEUI. CanvasLayer modal (capa 60; marco en compose_base.gd).
# Uso (Shell: noche de informe, el chico de Pell en la puerta; día 10, informe final):
#   var rc = ReportComposer.new(); add_child(rc); rc.open()
#   Tres ranuras: soltar un recorte o una pregunta del expediente (DnD {"kind":"clip"|"pregunta","id"}, GDD_v3 §6.10) o
#   «Elegir…» (selector, 2.º panel).
#   «Sin novedad» (modo nada). Final (q_report_status().final): además «Quemarlo» y, sólo si alguien la ofreció
#   (offered_erratum), «La errata a medida». El texto final exacto (q_preview report_submit) se ve siempre;
#   «Entregar» -> confirmación -> report_submit {mode, items}.
#   API extra: add_item(item) -> bool · remove_item(i) · set_mode(m) · items · mode · status.
# Si no hay informe debido, el sobre queda en blanco y «Entregar» deshabilitado (nota de Lisle).
extends "res://ui/compose/compose_base.gd"

const ItemPicker = preload("res://ui/scene/item_picker.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")
const MAX_ITEMS := 3

class Slot extends PanelContainer:
	var idx := 0
	var owner_rc = null
	func _can_drop_data(_at: Vector2, data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and ["clip", "pregunta"].has(String(data.get("kind", ""))) and owner_rc != null and owner_rc.slots_enabled()
	func _drop_data(_at: Vector2, data) -> void:
		owner_rc.add_item({"kind": String(data.get("kind", "")), "id": String(data.get("id", ""))}, idx)

var items: Array = []           # [{kind, id}]
var mode := "items"             # items | nada | quemar | errata
var status := {}
var picker
var _slots: Array = []          # [{panel, body, src, choose, remove}]
var _modes := {}
var _modes_row: HBoxContainer
var _pick_slot := -1

func _init() -> void:
	super()
	name = "ReportComposer"

func _paper() -> String:
	return "carta"

func _width() -> float:
	return 860.0

func _title_text() -> String:
	if bool(status.get("final", false)):
		return link.t("sceneui.rep.title.final")
	return link.t("sceneui.rep.title", {"n": int(status.get("n", 0))})

func _sub_text() -> String:
	if bool(status.get("final", false)):
		return link.t("sceneui.rep.sub.final")
	return link.t("sceneui.rep.sub.h" if via_h() else "sceneui.rep.sub")

# Tras M4 (pell_despedido) el chico ya no viene: el informe va a la lista de correos de Charing Cross, a nombre de H.
# (el mismo flag con que Composers arma el encabezado del texto final).
func via_h() -> bool:
	var st = link.st()
	return st != null and typeof(st.flags) == TYPE_DICTIONARY and bool(st.flags.get("pell_despedido", false))

func _send_label() -> String:
	return link.t("sceneui.rep.send")

func _confirm_title() -> String:
	return _title_text()

func _confirm_extra() -> String:
	if mode == "quemar":
		return link.t("sceneui.rep.confirm.quemar")
	if bool(status.get("final", false)):
		return ""
	return link.t("sceneui.rep.confirm.h" if via_h() else "sceneui.rep.confirm.chico")

func _final_slot() -> String:
	return "manuscrito"

func _incomplete_text() -> String:
	return link.t("sceneui.rep.vacio") if bool(status.get("due", false)) else link.t("sceneui.rep.no_debido")

func _stamp_text(_res: Dictionary) -> String:
	return link.t("sceneui.rep.sello.quemado") if mode == "quemar" else link.t("sceneui.rep.sello")

func _build_body(v: VBoxContainer) -> void:
	for i in MAX_ITEMS:
		var p := Slot.new()
		p.idx = i
		p.owner_rc = self
		p.name = "Ranura%d" % i
		p.theme_type_variation = "SlotSegun"
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		p.add_child(h)
		var num := Label.new()
		num.text = "%d." % (i + 1)
		num.custom_minimum_size = Vector2(28, 0)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(num)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_theme_constant_override("separation", 1)
		h.add_child(mid)
		var body_l := Label.new()
		body_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mid.add_child(body_l)
		var src := Widgets.source_line("")
		mid.add_child(src)
		var choose := Widgets.ink_button(link.t("sceneui.rep.choose"), open_picker.bind(i))
		choose.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(choose)
		var rem := Widgets.ink_button(link.t("sceneui.rep.remove"), remove_item.bind(i))
		rem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(rem)
		v.add_child(p)
		_slots.append({"panel": p, "body": body_l, "src": src, "choose": choose, "remove": rem, "mid": mid})
	_modes_row = HBoxContainer.new()
	_modes_row.add_theme_constant_override("separation", 8)
	for m in ["nada", "quemar", "errata"]:
		var b := Widgets.ink_tab(link.t("sceneui.rep." + m))
		b.toggled.connect(func(on): set_mode(m if on else "items"))
		_modes[m] = b
		_modes_row.add_child(b)
	v.add_child(_modes_row)

func _ensure_built() -> void:
	var was := _built
	super._ensure_built()
	if not was:
		picker = ItemPicker.new(link)
		picker.picked.connect(func(it): add_item(it, _pick_slot))
		picker.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		picker.grow_horizontal = Control.GROW_DIRECTION_BOTH
		picker.grow_vertical = Control.GROW_DIRECTION_BOTH
		picker.custom_minimum_size = Vector2(660, 0)
		root.add_child(picker)

func _on_open() -> void:
	status = link.qd("q_report_status")
	items = []
	mode = "items"
	picker.close()
	if not bool(status.get("due", false)):
		note.say(link.err_text("sin_informe"))

func open(arg := "") -> void:
	status = link.qd("q_report_status")
	super.open(arg)

func slots_enabled() -> bool:
	return mode == "items" and bool(status.get("due", false))

func open_picker(i := -1) -> void:
	if not slots_enabled():
		return
	_pick_slot = i
	# playtest v3: lo que ya está en el informe no se ofrece otra vez (salvo lo de la ranura que se reemplaza)
	var ex: Array = []
	for k in items.size():
		if k != i:
			ex.append(items[k])
	picker.open(link.t("sceneui.rep.picker"), ["clip", "pregunta"], {"exclude": ex})

func add_item(item: Dictionary, at := -1) -> bool:
	if not ["clip", "pregunta"].has(String(item.get("kind", ""))) or String(item.get("id", "")) == "":
		return false
	var it := {"kind": String(item.kind), "id": String(item.id)}
	for x in items:
		if x.kind == it.kind and x.id == it.id:
			note.say(link.t("sceneui.rep.repetido"))
			return false
	if mode != "items":
		set_mode("items")
	if at >= 0 and at < items.size():
		items[at] = it
	elif items.size() < MAX_ITEMS:
		items.append(it)
	else:
		return false
	refresh()
	link.play("sfx.papel")
	return true

func remove_item(i: int) -> void:
	if i >= 0 and i < items.size():
		items.remove_at(i)
		refresh()

func set_mode(m: String) -> void:
	if not ["items", "nada", "quemar", "errata"].has(m):
		return
	if m == "quemar" and not bool(status.get("final", false)):
		return
	if m == "errata" and not (bool(status.get("final", false)) and bool(status.get("offered_erratum", false))):
		return
	mode = m
	if m != "items":
		items = []
	refresh()

func _refresh_body() -> void:
	var final := bool(status.get("final", false))
	_modes["quemar"].visible = final
	_modes["errata"].visible = final and bool(status.get("offered_erratum", false))
	for m in _modes:
		_modes[m].set_pressed_no_signal(mode == m)
	var en := slots_enabled()
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var has := i < items.size()
		var body_l: Label = s.body
		var src: Label = s.src
		body_l.add_theme_font_override("font", SimLink.font("imprenta"))
		body_l.add_theme_font_size_override("font_size", int(round(SimLink.px("doc") * 0.86)))
		var mid: VBoxContainer = s.mid
		var old_card := mid.get_node_or_null("Tarjeta")
		if old_card != null:
			mid.remove_child(old_card)
			old_card.queue_free()
		body_l.visible = true
		if has:
			var info: Dictionary = link.item_info(items[i])
			var head := String(info.get("title", ""))
			# «¿Qué no contó Watson? Raspadura» (sin el punto de más tras «?»: playtest v3)
			var sep := " " if head.right(1) in ["?", "!", ".", "…", ":"] else ". "
			body_l.text = (head + sep if head != "" else "") + SimLink.short(String(info.get("body", "")), 140)
			body_l.add_theme_color_override("font_color", Paper.ink("negra"))
			src.text = String(info.get("source", ""))
			# GDD_v3 §6.2: un recorte en el sobre es la misma tarjeta del cuaderno (letra del documento, línea de fuente)
			var c: Dictionary = link.qd("q_clip", [String(items[i].id)]) if String(items[i].kind) == "clip" else {}
			if not c.is_empty():
				var tj := ClipCard.tarjeta(link.sim(), c, 300.0, {"name": "Tarjeta"})
				tj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				mid.add_child(tj)
				body_l.visible = false
				src.text = ""
		else:
			body_l.text = link.t("sceneui.rep.slot.empty") if en else ""
			body_l.add_theme_color_override("font_color", Paper.ink("tenue"))
			src.text = ""
		src.visible = src.text != ""
		s.choose.visible = en and not has and i == items.size()
		s.remove.visible = has
		(s.panel as Control).modulate.a = 1.0 if en or has else 0.45
	send_button.text = _send_label() if mode != "quemar" else link.t("sceneui.rep.send.quemar")

func _action() -> Dictionary:
	if not bool(status.get("due", false)):
		return {}
	if mode == "items" and items.is_empty():
		return {}
	return {"t": "report_submit", "mode": mode, "items": items.duplicate(true) if mode == "items" else []}

func back() -> bool:
	if picker != null and picker.visible:
		picker.close()
		return true
	return super.back()
