# ui/kit/widgets.gd — fábrica de controles del kit (estática). Dueño: W1-THEME. Contrato: ARCHITECTURE §6.1–6.2.
# Uso: const Widgets = preload("res://ui/kit/widgets.gd")
# Todo sale con theme_type_variation del Theme único (theme_builder.gd); nada fija colores a mano salvo vía
# restyle() (se reaplica con ThemeInstaller.theme_changed: alto contraste y escala). Textos fijos: Widgets.t(clave)
# (ui_text vía Data.repo().text). Sin brillos ni resaltados (§6.1); animaciones ≤0,4 s sin rebote (fade()).
#
#   t(key, vars={}) -> String                      texto de ui_text (si no hay repo: la clave)
#   label(text, variation="") -> Label             heading(text) · doc_title(text) · source_line(text) · caption(text)
#   small(text) · marginal(text) (nota a lápiz, voz de Lisle) · subtitle(text)
#   rich(variation="DocBody", text="") -> RichTextLabel   (fit_content, sin bbcode, sin selección: el lector la activa)
#   button(text, cb) · ink_button(text, cb) · ink_tab(text, group=null) -> Button
#   paper_panel(paper="cuaderno", child=null, opts={}) -> PanelContainer   (Paper.style; opts de Paper.style)
#   sheet(paper="cuaderno", opts={}) -> Sheet (ui/kit/sheet.gd: grano, renglones, margen)
#   chip(text, data={}) -> PanelContainer          (meta "data" = {"kind","id"} para DnD; vista previa = otro chip)
#   slot_segun(content=null, label_text="") -> HBoxContainer   («según» + ranura; meta "slot" = PanelContainer)
#   blank(label_text, value="", min_w=140) -> HBoxContainer   («Campo: ___»; meta "value" = Label del valor)
#   stamp(text, ink="roja", angle_deg=-6.0, small_stamp=false) -> Control  (sello «Visto»; chico: «Recibido: …»; meta "label")
#   rule() -> HSeparator (InkRule)
#   confirm(body, ok_text="", back_text="", title="") -> Confirm (ui/kit/confirm.gd; señal decided(ok))
#   fade(node, to_alpha, seconds=0.25) -> Tween
#   restyle(node, fn) -> void                      llama fn ahora y en cada theme_changed (hijo Restyler)
#   fold(title, key="", open=false) -> VBoxContainer  sección plegada (GDD_v2 §C: lo que no hace falta, plegado): un
#     renglón «› Título» que despliega («– Título» desplegado; los glifos ▸▾ no están en las fuentes); meta "content" = VBoxContainer donde va lo plegado, meta "header" = el botón;
#     key != "" recuerda abierto/cerrado en la sesión (no es estado de la partida)
extends RefCounted

const Paper = preload("res://ui/kit/paper.gd")
const Sheet = preload("res://ui/kit/sheet.gd")
const Confirm = preload("res://ui/kit/confirm.gd")
const Restyler = preload("res://ui/kit/restyler.gd")
const MAX_ANIM_S := 0.4
const FOLD_CLOSED := "› "
const FOLD_OPEN := "– "

static func _root_node(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

static func ti() -> Node:
	return _root_node("ThemeInstaller")

static func t(key: String, vars := {}) -> String:
	var data := _root_node("Data")
	if data != null and data.has_method("repo"):
		var r = data.repo()
		if r != null and r.has_method("text"):
			var s = r.text(key, vars)
			if s is String and s != "":
				return s
	return key

static func label(text: String, variation := "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l

static func heading(text: String) -> Label:
	return label(text, "Heading")

static func doc_title(text: String) -> Label:
	return label(text, "DocTitle")

static func source_line(text: String) -> Label:
	var l := label(text, "SourceLine")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func caption(text: String) -> Label:
	var l := label(text, "Caption")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func small(text: String) -> Label:
	return label(text, "SmallLabel")

static func marginal(text: String) -> Label:
	var l := label(text, "Marginal")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func subtitle(text: String) -> Label:
	var l := label(text, "Subtitle")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.custom_minimum_size = Vector2(360, 0)
	return l

static func rich(variation := "DocBody", text := "") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = variation
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.context_menu_enabled = false
	r.shortcut_keys_enabled = false
	r.drag_and_drop_selection_enabled = false
	r.threaded = false
	if text != "":
		r.add_text(text)
	return r

static func button(text: String, cb := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func ink_button(text: String, cb := Callable()) -> Button:
	var b := button(text, cb)
	b.theme_type_variation = "InkButton"
	return b

static func ink_tab(text: String, group: ButtonGroup = null) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = "InkTab"
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	if group != null:
		b.button_group = group
	return b

static func paper_panel(paper := "cuaderno", child: Control = null, opts := {}) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "PaperPanel"
	if paper != "cuaderno" or not opts.is_empty():
		var o := {"margin": 22}
		o.merge(opts, true)
		restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style(paper, o)))
	if child != null:
		p.add_child(child)
	return p

static func sheet(paper := "cuaderno", opts := {}) -> PanelContainer:
	return Sheet.new(paper, opts)

static func chip(text: String, data := {}) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Chip"
	p.set_meta("data", data)
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var l := label(text, "ChipLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p

static func slot_segun(content: Control = null, label_text := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := label(label_text if label_text != "" else t("kit.segun"), "SourceLine")
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	var s := PanelContainer.new()
	s.theme_type_variation = "SlotSegun"
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 0)
	if content != null:
		s.add_child(content)
	h.add_child(s)
	h.set_meta("slot", s)
	return h

static func blank(label_text: String, value := "", min_w := 140.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(label(label_text + ":", ""))
	var v := label(value, "Blank")
	v.custom_minimum_size = Vector2(min_w, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	h.set_meta("value", v)
	return h

# Devuelve un Control contenedor (los Container anulan la rotación de sus hijos directos); meta "label" = el Label.
static func stamp(text: String, ink := "roja", angle_deg := -6.0, small_stamp := false) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := label(text, "StampLabel")
	l.uppercase = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.rotation_degrees = angle_deg
	l.modulate.a = 0.9
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(l)
	holder.set_meta("label", l)
	var ang := deg_to_rad(angle_deg)
	var sync := func():
		var ms := l.get_combined_minimum_size()
		var bb := Vector2(absf(ms.x * cos(ang)) + absf(ms.y * sin(ang)), absf(ms.x * sin(ang)) + absf(ms.y * cos(ang)))
		l.size = ms
		l.position = (bb - ms) * 0.5
		l.pivot_offset = ms * 0.5
		holder.custom_minimum_size = bb.ceil()
	l.minimum_size_changed.connect(sync)
	l.resized.connect(func(): l.pivot_offset = l.size * 0.5)
	sync.call()
	if ink != "roja" or small_stamp:
		restyle(l, func():
			var c := Paper.ink(ink)
			l.add_theme_color_override("font_color", c)
			var w := 2 if small_stamp else 3
			var sb := Paper.flat(Color(0, 0, 0, 0), c, [w, w, w, w], 4 if small_stamp else 7, [8, 0, 8, 1] if small_stamp else [14, 1, 14, 3])
			l.add_theme_stylebox_override("normal", sb)
			if small_stamp:
				var tin := ti()
				l.add_theme_font_size_override("font_size", 15 if tin == null else tin.px("small")))
	return holder

static func rule() -> HSeparator:
	var r := HSeparator.new()
	r.theme_type_variation = "InkRule"
	return r

static func confirm(body = "", ok_text := "", back_text := "", title := "") -> PanelContainer:
	var ok := ok_text if ok_text != "" else t("kit.confirm.ok")
	var back := back_text if back_text != "" else t("kit.confirm.back")
	return Confirm.new(body, ok, back, title)

static func fade(node: CanvasItem, to_alpha: float, seconds := 0.25) -> Tween:
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", to_alpha, minf(seconds, MAX_ANIM_S))
	return tw

static func restyle(node: Control, fn: Callable) -> void:
	fn.call()
	node.add_child(Restyler.new(fn), false, Node.INTERNAL_MODE_BACK)

static var _folds := {}

static func fold(title: String, key := "", open := false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.name = "Plegado"
	var on: bool = bool(_folds.get(key, open)) if key != "" else open
	var hb := ink_button("")
	hb.name = "Desplegar"
	hb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var c := VBoxContainer.new()
	c.name = "Contenido"
	c.add_theme_constant_override("separation", 6)
	var sync := func(o: bool):
		hb.text = (FOLD_OPEN if o else FOLD_CLOSED) + title
		c.visible = o
		v.set_meta("open", o)
	hb.pressed.connect(func():
		var o := not bool(v.get_meta("open", false))
		if key != "":
			_folds[key] = o
		sync.call(o))
	v.add_child(hb)
	v.add_child(c)
	v.set_meta("content", c)
	v.set_meta("header", hb)
	sync.call(on)
	return v

# Abre o cierra un plegado desde fuera (tests, drivers).
static func set_fold(v: Control, open: bool) -> void:
	if v == null or not v.has_meta("header"):
		return
	if bool(v.get_meta("open", false)) != open:
		(v.get_meta("header") as Button).pressed.emit()
