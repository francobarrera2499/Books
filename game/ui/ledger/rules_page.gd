# ui/ledger/rules_page.gd — primera página del libro de conclusiones (GDD_v2 §B.6.1, §A.3, §C.3). Dueño: DESPEJE-UI.
# Izquierda: «Lo que me preguntaron»: las preguntas que ya se dijeron o se entregaron, citadas TEXTUALMENTE con quién y
#   cuándo (GameSim.q_questions: Pell en el encargo, el mayor, Mycroft…). No se marcan resueltas ni pendientes: son citas,
#   como el diario. Debajo, plegado, «Cómo se anota una conclusión» (rules.1–5, texto fijo, sin ningún dato del caso).
# Derecha: en blanco salvo una ayuda de una línea («Nueva hoja») hasta que se abre la primera hoja. Se fue el «Modo de
#   asentar» de cuatro párrafos y la lista de plantillas (los tipos se eligen al escribir: §C.3).
# Constructores estáticos; host = Ledger. build_left/build_right conservan el nombre (Ledger y el modo acoplado los usan).
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")

static func _num(host, text: String, color: Color, first_line_px: int) -> Label:
	var n := Widgets.label(text, "")
	n.custom_minimum_size = Vector2(host.MARGIN_W, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	n.add_theme_font_override("font", host.font("imprenta"))
	n.add_theme_font_size_override("font_size", int(round(first_line_px * 0.82)))
	n.add_theme_color_override("font_color", color)
	# la cifra en la misma línea base que el primer renglón
	n.add_theme_constant_override("line_spacing", 0)
	n.add_theme_stylebox_override("normal", Paper.empty([0, int(round(first_line_px * 0.18)), 0, 0]))
	return n

static func questions(sim) -> Array:
	if sim == null or not sim.has_method("q_questions"):
		return []
	var q = sim.q_questions()
	return q if typeof(q) == TYPE_ARRAY else []

static func build_left(host) -> Control:
	var sim = host.sim_ref()
	var v := VBoxContainer.new()
	v.name = "Preguntas"
	v.add_theme_constant_override("separation", 14)
	var title := Model.tx(sim, "preg.titulo") if Model.has_text(sim, "preg.titulo") else Model.tx(sim, "rules.title")
	v.add_child(host.indent(Widgets.label(title, "DocTitle")))
	v.add_child(host.indent(Widgets.rule()))
	var px: int = host.px("doc")
	var qs := questions(sim)
	for i in qs.size():
		var q: Dictionary = qs[i]
		var row := VBoxContainer.new()
		row.name = "Pregunta%d" % (i + 1)
		row.add_theme_constant_override("separation", 0)
		var who := Model.tx(sim, "preg.quien_dia", {"quien": String(q.get("quien", "")), "dia": String(q.get("dia", ""))}) \
			if Model.has_text(sim, "preg.quien_dia") else "%s, %s:" % [String(q.get("quien", "")), String(q.get("dia", ""))]
		var wl := Widgets.label(_cap(who), "SourceLine")
		row.add_child(host.indent(wl))
		var txt := Label.new()
		txt.name = "Cita"
		txt.text = "«%s»" % String(q.get("text", "")).strip_edges()
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_theme_font_override("font", host.font("imprenta", true))
		txt.add_theme_font_size_override("font_size", px)
		txt.add_theme_color_override("font_color", Paper.ink("negra"))
		row.add_child(host.indent(txt))
		v.add_child(row)
	# «Cómo se anota una conclusión», plegado (se recuerda abierto o cerrado en la sesión)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var fold := Widgets.fold(Model.tx(sim, "v2d.lg.como"), "ledger.como", false)
	fold.name = "ComoSeAnota"
	var c: VBoxContainer = fold.get_meta("content")
	c.add_theme_constant_override("separation", 10)
	var rules := Model.rules(sim)
	var rpx: int = host.px("ui")
	for i in rules.size():
		var row2 := HBoxContainer.new()
		row2.name = "Regla%d" % (i + 1)
		row2.add_theme_constant_override("separation", host.MARGIN_SEP)
		row2.add_child(_num(host, "%d." % (i + 1), Paper.ink("roja"), rpx))
		row2.add_child(host.rich_text(String(rules[i]), "imprenta", rpx))
		c.add_child(row2)
	(fold.get_meta("header") as Button).add_theme_font_size_override("font_size", rpx)
	v.add_child(host.indent(fold))
	return v

# La página de enfrente: una sola línea de ayuda hasta el primer uso de «Nueva hoja» (§C.1: ayudas de una línea).
static func build_right(host) -> Control:
	var sim = host.sim_ref()
	var v := VBoxContainer.new()
	v.name = "Enfrente"
	if sim == null:
		return v
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 120)
	v.add_child(sp)
	var flags: Dictionary = host.flags if "flags" in host else {}
	var folios: Array = sim.q_ledger().get("folios", [])
	if folios.is_empty() and UiFlags.on(flags, "lg.hoja_nueva"):
		var l := Widgets.marginal(host.plain(Model.tx(sim, "v2d.lg.ayuda.hoja")))
		l.name = "AyudaHoja"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", Paper.ink("tenue"))
		v.add_child(host.indent(l))
	return v

static func _cap(s: String) -> String:
	return s if s == "" else s.left(1).to_upper() + s.substr(1)
