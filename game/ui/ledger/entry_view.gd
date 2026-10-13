# ui/ledger/entry_view.gd — página derecha del libro mayor: el asiento abierto (§6.6, GDD§8.4–8.5). Dueño: W3-LEDGER.
# Constructor estático; `host` = Ledger. Por cada línea de la plantilla (numerada en el margen; las opcionales dicen
# «si hace falta»): sus campos «Campo: ___» (clic -> elector con el índice filtrado por tipo o la lista cerrada; soltar
# un chip del índice {"kind":"ent"}) y su ranura «según» (recortes/pares como tiras; «añadir» -> elector de recortes;
# soltar {"kind":"clip"|"pair"}; la cruz quita). Junto a la línea, en lápiz, el chequeo formal en la voz de Lisle
# («Falta un según.»); al pie, los avisos del asiento («Una sola fuente no es prueba.», «Demasiado papel.»).
# A lápiz se escribe a mano (gris); en tinta, de imprenta (negro) y con el «Visto». Pie: «Al sello» (lote) o
# «Pasar en limpio» (práctica, C1) y «Borrar» (sólo lápiz).
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")

static func empty(host) -> Control:
	var v := VBoxContainer.new()
	v.name = "SinAsiento"
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 120)
	v.add_child(sp)
	var l := Widgets.marginal(host.plain(Model.tx(host.sim_ref(), "ledger.elija")))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(host.indent(l))
	return v

static func build(host, vm: Dictionary, marked: bool) -> Control:
	var sim = host.sim_ref()
	var eid := String(vm.id)
	var ink := String(vm.ink)
	var editable := bool(vm.editable) and Model.tut_allows(sim, "entry_set")
	var v := VBoxContainer.new()
	v.name = "Asiento_" + eid
	v.add_theme_constant_override("separation", 12)
	# --- cabecera
	var head := HBoxContainer.new()
	head.name = "Cabecera"
	head.add_theme_constant_override("separation", 12)
	# la cabecera se arrastra como el renglón de la página: presentar el asiento abierto en una escena
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.mouse_default_cursor_shape = Control.CURSOR_DRAG
	head.set_drag_forwarding(func(_p): return host.drag_entry(eid, head), Callable(), Callable())
	var t := Widgets.label(Model.tx(sim, "ledger.asiento", {"n": int(vm.n)}), "DocTitle")
	head.add_child(t)
	var tn := Widgets.label(String(vm.tname), "Caption")
	tn.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(tn)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(fill)
	if ink == "tinta":
		var st := Widgets.stamp(Model.tx(sim, "ledger.sello"), "roja", -7.0)
		st.name = "VistoGrande"
		head.add_child(st)
		host.maybe_animate_stamp(eid, st)
	var state := Widgets.label(Model.tx(sim, "ledger.tinta" if ink == "tinta" else "ledger.lapiz") + ((" · " + Model.tx(sim, "ledger.practica")) if bool(vm.practice) else ""), "SourceLine")
	state.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(state)
	v.add_child(host.indent(head))
	v.add_child(host.indent(Widgets.rule()))
	# --- un asiento en blanco dice cómo se llena (forma, nunca contenido); desaparece al escribir algo
	if not bool(vm.started) and ink != "tinta" and editable:
		var hint := Widgets.marginal(host.plain(Model.tx(sim, "ledger.asiento.ayuda")))
		hint.name = "Ayuda"
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", Paper.ink("tenue"))
		v.add_child(host.indent(hint))
	# --- líneas
	for ln in vm.lines:
		v.add_child(_line(host, eid, ln, ink, editable))
	# --- avisos del asiento (chequeo formal: forma, no contenido)
	if not (vm.notes as Array).is_empty() and ink != "tinta":
		var nv := VBoxContainer.new()
		nv.name = "Avisos"
		nv.add_theme_constant_override("separation", 0)
		for code in vm.notes:
			var n := Widgets.marginal(host.plain(Model.tx(sim, "formal." + String(code))))
			n.name = "Aviso_" + String(code)
			n.add_theme_color_override("font_color", Paper.ink("roja"))
			nv.add_child(n)
		v.add_child(host.indent(nv))
	# --- pie
	if ink != "tinta":
		var foot := HBoxContainer.new()
		foot.name = "Pie"
		foot.add_theme_constant_override("separation", 16)
		if bool(vm.practice):
			var pb := Widgets.button(Model.tx(sim, "ledger.pasar_practica"))
			pb.name = "Practicar"
			pb.disabled = not Model.tut_allows(sim, "practice")
			pb.pressed.connect(func(): host.on_practice(eid))
			foot.add_child(pb)
		else:
			var cb := CheckBox.new()
			cb.name = "AlSello"
			cb.text = Model.tx(sim, "ledger.al_sello")
			cb.focus_mode = Control.FOCUS_NONE
			cb.button_pressed = marked
			cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			cb.toggled.connect(func(_on): host.on_lot(eid))
			foot.add_child(cb)
		var f2 := Control.new()
		f2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(f2)
		var del := Widgets.ink_button(Model.tx(sim, "ledger.borrar"))
		del.name = "Borrar"
		del.disabled = not Model.tut_allows(sim, "entry_delete")
		del.pressed.connect(func(): host.on_delete(eid))
		foot.add_child(del)
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 6)
		v.add_child(sp)
		v.add_child(host.indent(foot))
	return v

static func _line(host, eid: String, ln: Dictionary, ink: String, editable: bool) -> Control:
	var sim = host.sim_ref()
	var li := int(ln.i)
	var row := HBoxContainer.new()
	row.name = "Linea%d" % li
	row.add_theme_constant_override("separation", host.MARGIN_SEP)
	var num := Widgets.label("%d" % (li + 1), "SourceLine")
	num.custom_minimum_size = Vector2(host.MARGIN_W, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(num)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	if bool(ln.optional):
		var o := Widgets.label(Model.tx(sim, "ledger.opcional"), "SourceLine")
		o.add_theme_color_override("font_color", Paper.ink("tenue"))
		body.add_child(o)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 18)
	flow.add_theme_constant_override("v_separation", 6)
	body.add_child(flow)
	for f in ln.fields:
		flow.add_child(_field(host, eid, li, f, ink, editable))
	# según
	var sg := HBoxContainer.new()
	sg.name = "Segun"
	sg.add_theme_constant_override("separation", 8)
	var sl := Widgets.label(Model.tx(sim, "ledger.segun"), "SourceLine")
	sl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sg.add_child(sl)
	var slot := PanelContainer.new()
	slot.name = "Ranura"
	slot.theme_type_variation = "SlotSegun"
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(0, 34)
	sg.add_child(slot)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	slot.add_child(chips)
	for c in ln.support:
		chips.add_child(host.support_chip(c, ink != "tinta" and editable, func(): host.on_support_remove(eid, li, String(c.id))))
	if ink != "tinta":
		var add := Widgets.ink_button("+ " + Model.tx(sim, "ledger.segun.add"))
		add.name = "Anadir"
		add.mouse_filter = Control.MOUSE_FILTER_PASS
		add.disabled = not editable
		add.add_theme_font_size_override("font_size", host.px("small") + 1)
		add.pressed.connect(func(): host.on_support_add(eid, li, add))
		chips.add_child(add)
		slot.set_drag_forwarding(Callable(), func(_p, data): return editable and host.can_drop_support(data),
			func(_p, data): host.drop_support(eid, li, data))
	body.add_child(sg)
	if bool(ln.falta_segun) and ink != "tinta":
		var n := Widgets.marginal(host.plain(Model.tx(sim, "formal.falta_segun")))
		n.name = "FaltaSegun"
		n.add_theme_color_override("font_color", Paper.ink("roja"))
		body.add_child(n)
	return row

static func _field(host, eid: String, li: int, f: Dictionary, ink: String, editable: bool) -> Control:
	var h := HBoxContainer.new()
	h.name = "Campo_" + String(f.id)
	h.add_theme_constant_override("separation", 6)
	var lab := Widgets.label(String(f.label), "")
	h.add_child(lab)
	var val := String(f.value)
	if ink == "tinta":
		var l: Label = host.ink_label(String(f.text), "tinta", "ui")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(host.text_width(String(f.text), "imprenta", host.px("ui"), 420.0), 0)
		h.add_child(l)
		host.maybe_animate_ink(eid, l)
		return h
	var b: Button = host.blank_button(String(f.text), val != "")
	b.name = "Valor"
	b.disabled = not editable
	var acc: Dictionary = f.accept
	b.pressed.connect(func(): host.on_field(eid, li, String(f.id), acc, val, b))
	b.set_drag_forwarding(Callable(), func(_p, data): return editable and host.can_drop_field(data, acc),
		func(_p, data): host.drop_field(eid, li, String(f.id), data))
	h.add_child(b)
	return h
