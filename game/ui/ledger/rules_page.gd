# ui/ledger/rules_page.gd — primera página del libro mayor (GDD§8.0, §6.6). Dueño: W3-LEDGER.
# Izquierda: «Reglas del asiento» (rules.1–6, texto fijo, sin ningún dato del caso), numeradas en el margen.
# Derecha: «Modo de asentar» (ledger.modo.*: sólo la forma, cómo se usa el libro) y «Plantillas» (las nueve, con la
# forma de sus líneas: «Hecho — Persona · Hizo · Qué o a quién / (A o contra)…»). Constructores estáticos; host = Ledger.
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")

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

static func build_left(host) -> Control:
	var sim = host.sim_ref()
	var v := VBoxContainer.new()
	v.name = "Reglas"
	v.add_theme_constant_override("separation", 16)
	v.add_child(host.indent(Widgets.label(Model.tx(sim, "rules.title"), "DocTitle")))
	v.add_child(host.indent(Widgets.rule()))
	var rules := Model.rules(sim)
	var px: int = host.px("doc")
	for i in rules.size():
		var row := HBoxContainer.new()
		row.name = "Regla%d" % (i + 1)
		row.add_theme_constant_override("separation", host.MARGIN_SEP)
		row.add_child(_num(host, "%d." % (i + 1), Paper.ink("roja"), px))
		row.add_child(host.rich_text(String(rules[i]), "imprenta", px))
		v.add_child(row)
	return v

static func build_right(host) -> Control:
	var sim = host.sim_ref()
	var v := VBoxContainer.new()
	v.name = "Modo"
	v.add_theme_constant_override("separation", 10)
	v.add_child(host.indent(Widgets.label(Model.tx(sim, "ledger.modo.titulo"), "DocTitle")))
	v.add_child(host.indent(Widgets.rule()))
	var steps := Model.how_to(sim)
	var px: int = host.px("ui")
	for i in steps.size():
		var row := HBoxContainer.new()
		row.name = "Paso%d" % (i + 1)
		row.add_theme_constant_override("separation", host.MARGIN_SEP)
		row.add_child(_num(host, "%d." % (i + 1), Paper.ink("lapiz"), px))
		row.add_child(host.rich_text(String(steps[i]), "imprenta", px))
		v.add_child(row)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	v.add_child(sp)
	v.add_child(host.indent(Widgets.label(Model.tx(sim, "ledger.plantillas"), "DocTitle")))
	v.add_child(host.indent(Widgets.rule()))
	if sim == null:
		return v
	var list := VBoxContainer.new()
	list.name = "Plantillas"
	list.add_theme_constant_override("separation", 5)
	var small: int = host.px("small")
	for t in Model.templates(sim):
		var r := RichTextLabel.new()
		r.name = "Plantilla_" + String(t.id)
		r.bbcode_enabled = false
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.selection_enabled = false
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.theme_type_variation = "DocBody"
		r.add_theme_font_size_override("normal_font_size", px)
		r.push_font(host.font("imprenta"), px)
		r.push_color(Paper.ink("negra"))
		r.add_text(String(t.name))
		r.pop()
		r.pop()
		r.push_font(host.font("imprenta", true), small + 1)
		r.push_color(Paper.ink("lapiz"))
		r.add_text("  —  " + String(t.shape))
		r.pop()
		r.pop()
		list.add_child(r)
	v.add_child(host.indent(list))
	return v
