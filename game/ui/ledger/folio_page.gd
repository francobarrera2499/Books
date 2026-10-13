# ui/ledger/folio_page.gd — página izquierda del libro mayor para «Varios», un folio o «Erratas inocentes» (§6.6).
# Dueño: W3-LEDGER. Constructor estático; `host` = Ledger (callbacks y estilo).
#   título · (folio) el recorte que lo abrió, pegado como tira (se arrastra como recorte) · (Varios/Erratas) su nota ·
#   renglones de asiento: en el margen la casilla «Al sello» (a lápiz, no práctica) o el «Visto» chico (en tinta);
#   «Asiento n · Plantilla» y el resumen de lo escrito (lápiz gris a mano / tinta negra de imprenta). Clic = abrir en
#   la página derecha; arrastrar = presentar el asiento (datos {"kind":"entry","id"}) · «Nuevo asiento».
# GDD_v2 §C.3: la casilla «Al sello» sólo existe con el panel del sello (bandera lg.sello); debajo de «Nueva conclusión»,
#   una ayuda de una línea hasta que se escribe la primera.
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")

class EntryRow extends PanelContainer:
	signal clicked
	var eid := ""
	var selected := false
	var _n: StyleBox
	var _h: StyleBox
	var _s: StyleBox
	func setup(p_eid: String, p_sel: bool) -> void:
		eid = p_eid
		selected = p_sel
		name = "Renglon_" + eid
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_n = Paper.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), [0, 0, 0, 0], 2, [0, 6, 8, 6])
		_h = Paper.flat(Color(Paper.ink("negra"), 0.04), Color(0, 0, 0, 0), [0, 0, 0, 0], 2, [0, 6, 8, 6])
		_s = Paper.flat(Color(Paper.ink("negra"), 0.075), Color(Paper.ink("lapiz"), 0.7), [0, 0, 0, 0], 2, [0, 6, 8, 6])
		add_theme_stylebox_override("panel", _s if selected else _n)
		mouse_entered.connect(func(): if not selected: add_theme_stylebox_override("panel", _h))
		mouse_exited.connect(func(): if not selected: add_theme_stylebox_override("panel", _n))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			accept_event()
			clicked.emit()

static func build(host, pinfo: Dictionary, rows: Array, selected: String, lot: Array) -> Control:
	var sim = host.sim_ref()
	var v := VBoxContainer.new()
	v.name = "Pagina"
	v.add_theme_constant_override("separation", 10)
	var title := Widgets.label(String(pinfo.get("title", "")), "DocTitle")
	v.add_child(host.indent(title))
	var kind := String(pinfo.get("kind", ""))
	if kind == "folio":
		var head: Dictionary = pinfo.get("head", {})
		var hv := VBoxContainer.new()
		hv.add_theme_constant_override("separation", 4)
		hv.add_child(Widgets.label(Model.tx(sim, "ledger.folio.sub"), "SourceLine"))
		hv.add_child(host.clip_strip(head, true))
		v.add_child(host.indent(hv))
	elif String(pinfo.get("sub", "")) != "":
		var sub := Widgets.marginal(host.plain(String(pinfo.sub)))
		v.add_child(host.indent(sub))
	v.add_child(host.indent(Widgets.rule()))
	if rows.is_empty():
		var e := Widgets.label(Model.tx(sim, "ledger.vacia"), "SmallLabel")
		v.add_child(host.indent(e))
	for r in rows:
		v.add_child(_row(host, r, String(r.vm.id) == selected, lot))
	var add := Widgets.ink_button("+  " + Model.tx(sim, "ledger.nuevo_asiento"))
	add.name = "NuevoAsiento"
	add.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add.disabled = not Model.tut_allows(sim, "entry_new")
	add.pressed.connect(func(): host.on_new_entry(add))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	v.add_child(sp)
	v.add_child(host.indent(add))
	if sim != null and _no_entries(sim):
		var hl := Widgets.marginal(host.plain(Model.tx(sim, "v2d.lg.ayuda.conclusion")))
		hl.name = "AyudaConclusion"
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.add_theme_color_override("font_color", Paper.ink("tenue"))
		v.add_child(host.indent(hl))
	return v

static func _no_entries(sim) -> bool:
	var q: Dictionary = sim.q_ledger()
	if not (q.get("varios", []) as Array).is_empty() or not (q.get("erratas", []) as Array).is_empty():
		return false
	for fo in q.get("folios", []):
		if not (fo.get("entries", []) as Array).is_empty():
			return false
	return true

static func _row(host, r: Dictionary, sel: bool, lot: Array) -> Control:
	var sim = host.sim_ref()
	var vm: Dictionary = r.vm
	var eid := String(vm.id)
	var ink := String(vm.ink)
	var row := EntryRow.new()
	row.setup(eid, sel)
	row.clicked.connect(func(): host.on_select(eid))
	row.set_drag_forwarding(func(_p): return host.drag_entry(eid, row), Callable(), Callable())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", host.MARGIN_SEP)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	# margen: casilla del lote o «Visto» chico
	var m := CenterContainer.new()
	m.custom_minimum_size = Vector2(host.MARGIN_W, 0)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(m)
	if ink == "tinta":
		var st := Widgets.stamp(Model.tx(sim, "ledger.sello"), "roja", -8.0, true)
		st.name = "Visto"
		m.add_child(st)
		host.maybe_animate_stamp(eid, st)
	elif not bool(vm.practice) and UiFlags.on(host.flags if "flags" in host else {}, "lg.sello"):
		var cb := CheckBox.new()
		cb.name = "AlSello"
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = lot.has(eid)
		cb.tooltip_text = Model.tx(sim, "ledger.al_sello")
		cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cb.toggled.connect(func(_on): host.on_lot(eid))
		m.add_child(cb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(body)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 8)
	var t := Widgets.label("%s · %s" % [Model.tx(sim, "ledger.asiento", {"n": int(vm.n)}), String(vm.tname)], "")
	t.add_theme_font_override("font", host.font("imprenta"))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(t)
	var state := Widgets.label(Model.tx(sim, "ledger.tinta" if ink == "tinta" else "ledger.lapiz") + ((" · " + Model.tx(sim, "ledger.practica")) if bool(vm.practice) else ""), "SourceLine")
	state.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(state)
	body.add_child(head)
	var summ := String(r.get("summary", ""))
	if summ != "":
		var s: Label = host.ink_label(Model.short(summ, 140), ink, "ui" if ink != "tinta" else "small")
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(s)
		if ink == "tinta":
			host.maybe_animate_ink(eid, s)
	return row
