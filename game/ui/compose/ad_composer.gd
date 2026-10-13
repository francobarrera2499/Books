# ui/compose/ad_composer.gd — compositor de anuncios para la columna del Times (GDD §8.2, §3.2; ARCHITECTURE §5.7, §6.7).
# Dueño: W3-SCENEUI. CanvasLayer modal (capa 60; marco en compose_base.gd).
# Uso (Shell: objeto del escritorio o paso «aviso» del tutorial): var ac = AdComposer.new(); add_child(ac); ac.open()
#   Formas cerradas de lists.ad_forms (Composers.forms) disponibles hoy (form.when, DSL); la forma se lee como el texto
#   del aviso con sus huecos «___» en línea: cada hueco ofrece sólo lo que Composers.options permite (índice del jugador,
#   sin lugares de Londres ni material secreto_camden) o un chip del índice soltado encima.
#   El texto final exacto (q_preview compose_ad) se ve siempre; «Enviar a la oficina» abre la confirmación con el día
#   en que sale (prólogo: schedule.ads.prologue_pub_day; si no, el siguiente día con Times).
#   API extra: choose_form(id) · set_field(slot, value) -> bool · forms_available() · form_id · fields.
# Errores (oficina cerrada, uno por día, tutorial): nota de Lisle (ui_text sim.err.*); no se cierra.
extends "res://ui/compose/compose_base.gd"

const Composers = preload("res://core/scenes/composers.gd")
const Cond = preload("res://core/util/cond.gd")

var form_id := ""
var fields := {}
var _forms_row: HFlowContainer
var _galley: HFlowContainer
var _blanks := {}               # slot -> Blank
var _form_btns := {}

func _init() -> void:
	super()
	name = "AdComposer"

func _paper() -> String:
	return "diario_hueso"

func _width() -> float:
	return 820.0

func _title_text() -> String:
	return link.t("sceneui.ad.title")

func _sub_text() -> String:
	return link.t("sceneui.ad.sub.prologo") if String(link.qd("q_clock").get("phase", "")) == "prologue" else link.t("sceneui.ad.sub")

func _send_label() -> String:
	return link.t("sceneui.ad.send")

func _confirm_title() -> String:
	return link.t("sceneui.ad.confirm.title")

func _final_slot() -> String:
	return "imprenta"

func _stamp_text(_res: Dictionary) -> String:
	return link.t("sceneui.ad.sello")

func _build_body(v: VBoxContainer) -> void:
	var fl := Widgets.small(link.t("sceneui.ad.forma"))
	v.add_child(fl)
	_forms_row = HFlowContainer.new()
	_forms_row.add_theme_constant_override("h_separation", 6)
	_forms_row.add_theme_constant_override("v_separation", 6)
	v.add_child(_forms_row)
	_galley = HFlowContainer.new()
	_galley.name = "Galera"
	_galley.add_theme_constant_override("h_separation", 0)
	_galley.add_theme_constant_override("v_separation", 4)
	_galley.custom_minimum_size = Vector2(0, 64)
	v.add_child(_galley)
	final_label_text_key = "sceneui.ad.galera"

var final_label_text_key := ""

func _on_open() -> void:
	if final_label_text_key != "":
		final_label.text = link.t(final_label_text_key)
	_fill_forms()
	var av := forms_available()
	if form_id == "" or not av.has(form_id):
		form_id = String(av[0]) if not av.is_empty() else ""
		fields = {}
	choose_form(form_id)

func forms_available() -> Array:
	var r = link.repo()
	var st = link.st()
	var out: Array = []
	if r == null:
		return out
	for f in Composers.forms(r):
		if f.has("when") and st != null and not Cond.eval(f.when, {"st": st, "repo": r}):
			continue
		out.append(String(f.get("id", "")))
	return out

func choose_form(id: String) -> void:
	form_id = id
	for k in _form_btns:
		_form_btns[k].set_pressed_no_signal(k == id)
	var keep := fields.duplicate()
	fields = {}
	_build_galley()
	for s in keep:
		if _blanks.has(s):
			set_field(s, String(keep[s]))
	refresh()

func set_field(slot: String, value: String) -> bool:
	if not _blanks.has(slot):
		return false
	var ok: bool = _blanks[slot].set_value(value)
	return ok

func _form(id: String) -> Dictionary:
	var r = link.repo()
	if r == null:
		return {}
	for f in Composers.forms(r):
		if String(f.get("id", "")) == id:
			return f
	return {}

func _fill_forms() -> void:
	for c in _forms_row.get_children():
		_forms_row.remove_child(c)
		c.queue_free()
	_form_btns.clear()
	var group := ButtonGroup.new()
	for id in forms_available():
		var f := _form(id)
		var b := Widgets.ink_tab(String(f.get("label", id)), group)
		b.pressed.connect(choose_form.bind(String(id)))
		_form_btns[String(id)] = b
		_forms_row.add_child(b)

func _build_galley() -> void:
	for c in _galley.get_children():
		_galley.remove_child(c)
		c.queue_free()
	_blanks.clear()
	var f := _form(form_id)
	if f.is_empty():
		return
	var text := String(f.get("text", ""))
	var i := 0
	while i < text.length():
		var k := text.find("${", i)
		var seg := text.substr(i) if k < 0 else text.substr(i, k - i)
		_add_words(seg)
		if k < 0:
			break
		var e := text.find("}", k)
		if e < 0:
			break
		var slot := text.substr(k + 2, e - k - 2)
		var b := make_blank("___", func(val):
			if val == "":
				fields.erase(slot)
			else:
				fields[slot] = val)
		b.name = "Hueco_" + slot
		b.shown_fn = _printed
		b.set_options(_options(slot))
		_style_galley(b)
		_blanks[slot] = b
		_galley.add_child(b)
		i = e + 1

# Hueco lleno = lo que saldrá impreso («El problema final»), no el rótulo del índice («Problema final, El (Strand…)»).
func _printed(val: String) -> String:
	var r = link.repo()
	return Composers.piece_text(r, val) if r != null else ""

func _add_words(seg: String) -> void:
	var words := seg.split(" ", false)
	var lead_space := seg.begins_with(" ")
	for wi in words.size():
		var l := Label.new()
		var w := String(words[wi])
		var trailing := wi < words.size() - 1 or seg.ends_with(" ")
		l.text = (" " if lead_space and wi == 0 else "") + w + (" " if trailing else "")
		_style_galley(l)
		_galley.add_child(l)

func _style_galley(c: Control) -> void:
	c.add_theme_font_override("font", SimLink.font("imprenta"))
	c.add_theme_font_size_override("font_size", int(round(SimLink.px("doc") * 1.05)))
	if c is Label:
		c.add_theme_color_override("font_color", Paper.ink("negra"))
	elif c is Button:
		# el hueco se lee como parte del renglón: subrayado fino, sin caja ni márgenes que abran blancos en la galera
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(Paper.ink("negra"), 0.07) if st.begins_with("hover") or st == "pressed" else Color(0, 0, 0, 0)
			sb.border_color = Color(Paper.ink("tenue"), 0.9)
			sb.border_width_bottom = 1
			sb.content_margin_left = 2
			sb.content_margin_right = 1
			sb.content_margin_top = 0
			sb.content_margin_bottom = 1
			c.add_theme_stylebox_override(st, sb)
		c.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _options(slot: String) -> Array:
	var r = link.repo()
	var st = link.st()
	if r == null or st == null:
		return []
	return Composers.options(st, r, form_id, slot)

func _refresh_body() -> void:
	for s in _blanks:
		var keep := String(_blanks[s].value)
		_blanks[s].set_options(_options(s))
		if keep != "" and String(_blanks[s].value) == "":
			fields.erase(s)

func _action() -> Dictionary:
	var f := _form(form_id)
	if f.is_empty():
		return {}
	for s in f.get("slots", {}):
		if String(fields.get(s, "")) == "":
			return {}
	return {"t": "compose_ad", "form": form_id, "fields": fields.duplicate()}

func _confirm_extra() -> String:
	var c: Dictionary = link.qd("q_clock")
	var r = link.repo()
	if r == null:
		return ""
	var pub := -1
	var ads: Dictionary = r.schedule().get("ads", {})
	if String(c.get("phase", "")) == "prologue":
		pub = int(ads.get("prologue_pub_day", 1))
	else:
		pub = load("res://core/sim/clock.gd").ad_pub_day(r, int(c.get("day", 0)))
	if pub < 0:
		return ""
	return link.t("sceneui.ad.confirm.pub", {"fecha": link.day_label(pub)})
