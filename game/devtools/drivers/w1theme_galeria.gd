# Driver de captura W1-THEME: galería del kit (ARCHITECTURE §9.4, §10 W1-THEME).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w1theme res://devtools/drivers/w1theme_galeria.gd
# (si blank.tscn aún no existe, sirve res://main.tscn: el driver vacía la escena)
# Capturas: w1theme_galeria (papeles × variaciones con «» — ñ ¿¡), w1theme_galeria_hc (alto contraste),
# w1theme_galeria_embebida (set_slot("maquina","embedded") re-renderiza), w1theme_galeria_escala (text_scale 1,3),
# w1theme_galeria_tipos / _tipos_hc (muestrario: CADA variación de tipo con «» — ñ ¿¡, normal y alto contraste),
# w1theme_controles (tipos base y widgets: campos, casillas, menús, pestañas, confirmación, sellos).
extends RefCounted

const Paper = preload("res://ui/kit/paper.gd")
const W = preload("res://ui/kit/widgets.gd")

func drive(tool, scene) -> void:
	for c in scene.get_children():
		c.queue_free()
	var ti = tool.root.get_node("ThemeInstaller")
	var layer := CanvasLayer.new()
	scene.add_child(layer)
	var desk := ColorRect.new()
	desk.color = Paper.MESA
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(desk)
	var g := _gallery()
	layer.add_child(g)
	await tool.frames(6)
	await tool.snap("galeria")
	ti.set_high_contrast(true)
	await tool.frames(4)
	await tool.snap("galeria_hc")
	ti.set_high_contrast(false)
	ti.set_slot("maquina", "embedded")
	await tool.frames(4)
	await tool.snap("galeria_embebida")
	ti.reload_config()
	ti.set_text_scale(1.3)
	await tool.frames(4)
	await tool.snap("galeria_escala")
	ti.set_text_scale(1.0)
	g.queue_free()
	var tipos := _types()
	layer.add_child(tipos)
	await tool.frames(6)
	await tool.snap("galeria_tipos")
	ti.set_high_contrast(true)
	await tool.frames(4)
	await tool.snap("galeria_tipos_hc")
	ti.set_high_contrast(false)
	tipos.queue_free()
	var c2 := _controls()
	layer.add_child(c2)
	await tool.frames(6)
	await tool.snap("controles")
	ti.set_high_contrast(true)
	await tool.frames(4)
	await tool.snap("controles_hc")
	ti.set_high_contrast(false)
	await tool.frames(2)

# ------------------------------------------------------------------ galería de papeles
func _tag(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(Paper.PAPERS["cuaderno"], 0.7))
	l.add_theme_font_size_override("font_size", 14)
	return l

func _cell(grid: Control, tag: String, sheet: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_tag(tag))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sheet)
	grid.add_child(v)

func _vb(sheet: Control, sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	sheet.add_child(v)
	return v

func _styled(rtl: RichTextLabel, parts: Array) -> RichTextLabel:
	# parts: [["texto", "i"|"b"|"ink:azul"|"font:maquina"|""], ...] — como lo haría TextBuilder (push_*/pop)
	for p in parts:
		var k: String = p[1]
		var popn := 1
		if k == "i":
			rtl.push_italics()
		elif k == "b":
			rtl.push_bold()
		elif k.begins_with("ink:"):
			rtl.push_color(Paper.ink(k.substr(4)))
		elif k.begins_with("font:"):
			rtl.push_font(W.ti().font(k.substr(5)))
		else:
			popn = 0
		rtl.add_text(p[0])
		for i in popn:
			rtl.pop()
	return rtl

# Como lo debe hacer un consumidor con tintas/fuentes fijadas a mano: rearma el texto en cada theme_changed.
func _live(variation: String, parts: Array) -> RichTextLabel:
	var r := W.rich(variation)
	W.restyle(r, func():
		r.clear()
		_styled(r, parts))
	return r

func _gallery() -> Control:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 26)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	m.add_child(outer)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(grid)

	# 1 · diario_hueso — DocBody (imprenta), SourceLine, Caption; lápiz azul de Holmes
	var s1 := W.sheet("diario_hueso")
	var v1 := _vb(s1)
	v1.add_child(W.doc_title("Correspondencia"))
	v1.add_child(_live("DocBody", [["«La pared era ", ""], ["a pique", "i"], [" a un lado» —escribe el ", ""], ["Journal", "b"], ["—. ¿Y la raspadura? ¡Ni una palabra, señor! Año 1894; añádase la ñ.", ""]]))
	v1.add_child(_live("DocHand", [["No lo es.", "ink:azul"]]))
	v1.add_child(W.source_line("— The Times, martes 27 de marzo de 1894, p. 4"))
	_cell(grid, "diario_hueso · DocBody · DocHand azul · SourceLine", s1)

	# 2 · strand — DocTitle, DocBody, Caption (epígrafe de lámina)
	var s2 := W.sheet("strand")
	var v2 := _vb(s2)
	v2.add_child(W.heading("The Strand"))
	v2.add_child(W.rule())
	v2.add_child(_live("DocBody", [["Con el corazón apesadumbrado tomo la pluma —dice el doctor— para escribir estas últimas palabras. «¿Señor?» ¡Silencio!", ""]]))
	var cap := W.caption("—¿El Journal de Genève, señor? «Ni una línea.»")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v2.add_child(cap)
	_cell(grid, "strand · Heading · InkRule · DocBody · Caption", s2)

	# 3 · diogenes_recortado — DocTyped (máquina)
	var s3 := W.sheet("diogenes_recortado")
	var v3 := _vb(s3, 10)
	v3.add_child(_live("DocTyped", [["Señor Lisle:\nLea lo que quiera; no publique lo que no sabe. ¿Le ahorraré el trabajo? «Sí» —y basta—. ¡Año 1894!\n", ""], ["Un amigo de la exactitud.", "i"]]))
	v3.add_child(W.stamp("Recibido: 28-mar, amanecer", "negra", -2.0, true))
	_cell(grid, "diogenes_recortado · DocTyped · sello chico", s3)

	# 4 · telegrama — DocTyped en mayúsculas
	var s4 := W.sheet("telegrama", {"grain": true})
	var v4 := _vb(s4, 10)
	var tt := W.label("POST OFFICE TELEGRAPHS", "SmallLabel")
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v4.add_child(tt)
	v4.add_child(W.rule())
	v4.add_child(_live("DocTyped", [["LISLE HOLYWELL ST LONDRES = «LLEGO MAÑANA» STOP ¿RECIBIO PRUEBAS? STOP ¡URGE! — STEILER", ""]]))
	_cell(grid, "telegrama · DocTyped · SmallLabel", s4)

	# 5 · carta — DocHand (manuscrito) + Marginal
	var s5 := W.sheet("carta")
	var v5 := _vb(s5, 6)
	v5.add_child(_live("DocHand", [["Señor Lisle: le ruego no me nombre. ¿Mañana? «Sí» —en debida forma—. ¡Año 1894!", ""]]))
	v5.add_child(W.marginal("Mar. 27. Nadie corrige con lápiz blando una carta ajena. ¿Señal? «No.»"))
	_cell(grid, "carta · DocHand · Marginal (lápiz)", s5)

	# 6 · registro — campos «Campo: ___» y línea de fuente
	var s6 := W.sheet("registro")
	var v6 := _vb(s6, 10)
	v6.add_child(W.doc_title("Sala de Lectura"))
	v6.add_child(W.blank("Asiento", "214"))
	v6.add_child(W.blank("Pedido", "«Journal de Genève», 6-may-1891"))
	v6.add_child(W.blank("Lector", ""))
	v6.add_child(W.source_line("— Papeleta del Museo Británico, mañana del martes; año 1894. ¿Firma? ¡Ilegible!"))
	_cell(grid, "registro · Blank · DocTitle", s6)

	# 7 · libro_mayor — renglones, doble margen rojo, según, sello «Visto»
	var s7 := W.sheet("libro_mayor", {"ruled": true, "margin_line": 46.0, "margin_double": true, "pad": 22})
	s7.add_theme_stylebox_override("panel", Paper.empty([60, 14, 20, 14]))
	var v7 := _vb(s7, 9)
	v7.add_child(W.doc_title("Folio FO001"))
	v7.add_child(W.blank("Quién", "el señor «S.»"))
	var seg := W.slot_segun(W.chip("«No lo es.» — sobre S.W."), "según")
	v7.add_child(seg)
	var mg := W.marginal("Falta un según. ¿Una sola fuente? ¡Ñ!")
	v7.add_child(mg)
	var st := W.stamp("Visto")
	v7.add_child(st)
	_cell(grid, "libro_mayor · SlotSegun · Chip · Marginal · StampLabel", s7)

	# 8 · cuaderno — pestañas, chips, botones
	var s8 := W.sheet("cuaderno", {"margin_line": 0.0})
	var v8 := _vb(s8, 10)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	var grp := ButtonGroup.new()
	for n in ["Recortes", "Índice", "Pares", "Diario"]:
		var b := W.ink_tab(n, grp)
		tabs.add_child(b)
		if n == "Recortes":
			b.button_pressed = true
	v8.add_child(tabs)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	for n in ["Watson", "Mycroft Holmes", "Reichenbach", "«Journal»", "señora Hudson", "¿Moran?"]:
		chips.add_child(W.chip(n, {"kind": "ent", "id": n}))
	v8.add_child(chips)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 14)
	btns.add_child(W.button("Mostrar"))
	btns.add_child(W.ink_button("Guardar"))
	var dis := W.button("Enviar")
	dis.disabled = true
	btns.add_child(dis)
	v8.add_child(btns)
	v8.add_child(W.small("SmallLabel — «pequeño» — ñ ¿¡"))
	_cell(grid, "cuaderno · InkTab · Chip · Button · InkButton", s8)

	# 9 · PaperPanel (cuaderno) con las cinco tintas
	var p9 := W.paper_panel("cuaderno")
	var v9 := VBoxContainer.new()
	v9.add_theme_constant_override("separation", 8)
	p9.add_child(v9)
	v9.add_child(W.doc_title("Tintas"))
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 12)
	v9.add_child(ih)
	for k in ["negra", "lapiz", "azul", "roja", "tenue"]:
		var sw := VBoxContainer.new()
		var cr := ColorRect.new()
		cr.custom_minimum_size = Vector2(52, 16)
		W.restyle(cr, func(): cr.color = Paper.ink(k))
		sw.add_child(cr)
		var l := W.small(k)
		W.restyle(l, func(): l.add_theme_color_override("font_color", Paper.ink(k)))
		sw.add_child(l)
		ih.add_child(sw)
	v9.add_child(W.source_line("«Tinta azul»: el lápiz de Holmes — ¿ñ? ¡sí!"))
	_cell(grid, "PaperPanel · DocTitle · tintas", p9)

	# 10 · confirmación de dos pasos (ConfirmPanel sobre carta)
	var c10 := W.confirm("«Le ruego no me nombre.» ¿Envía usted la carta así —tal cual—? ¡Señor!", "Enviar", "Volver")
	c10.custom_minimum_size = Vector2(0, 0)
	_cell(grid, "ConfirmPanel · InkRule · InkButton · Button", c10)

	# 11 · subtítulo sobre el 3D
	var area := ColorRect.new()
	area.color = Color("25201b")
	area.custom_minimum_size = Vector2(0, 150)
	var sub := W.subtitle("arpa de boca, lejos — «St Clement Danes» ¿ñ? ¡sí!")
	sub.custom_minimum_size = Vector2(300, 0)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sub.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sub.offset_bottom = -14
	area.add_child(sub)
	_cell(grid, "Subtitle (capa 90, sobre el 3D)", area)

	# 12 · recortes sueltos: chips con datos de arrastre y línea de fuente
	var s12 := W.sheet("diario_hueso")
	var v12 := _vb(s12, 8)
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	for n in ["«La pared era a pique»", "matasellos S.W.", "Trichinópolis", "año 1894"]:
		fl.add_child(W.chip(n, {"kind": "clip", "id": n}))
	v12.add_child(fl)
	v12.add_child(W.rule())
	v12.add_child(W.source_line("— Diario de Lisle: «Recibido: sobre». ¿Señal? ¡Ninguna!"))
	_cell(grid, "Chip (arrastre) · InkRule · SourceLine", s12)
	return m

# ------------------------------------------------------------------ muestrario: cada variación con «» — ñ ¿¡
func _spec_tag(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	W.restyle(l, func(): l.add_theme_color_override("font_color", Paper.ink("tenue")))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.custom_minimum_size = Vector2(118, 0)
	return l

func _spec(grid: GridContainer, tag: String, c: Control) -> void:
	grid.add_child(_spec_tag(tag))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL if not (c is Button or c.theme_type_variation == "Chip") else Control.SIZE_SHRINK_BEGIN
	if c is Label:
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid.add_child(c)

func _spec_sheet(row: HBoxContainer) -> GridContainer:
	var s := W.sheet("cuaderno", {"pad": 20})
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(s)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 9)
	s.add_child(grid)
	return grid

func _types() -> Control:
	const M := "«¿Quién corrige?» —dijo—. ¡Año 1894, señor!"
	const M2 := "«¿Ñ?» —¡sí!"
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	m.add_child(row)

	# §6.2: las 12 variaciones contractuales
	var g1 := _spec_sheet(row)
	_spec(g1, "DocBody", _live("DocBody", [[M + " ", ""], ["cursiva ñ", "i"], [" · ", ""], ["negrita ¿¡", "b"]]))
	_spec(g1, "DocTyped", W.rich("DocTyped", M))
	_spec(g1, "DocHand", W.rich("DocHand", M))
	_spec(g1, "SourceLine", W.source_line("— " + M))
	_spec(g1, "Caption", W.caption(M))
	_spec(g1, "PaperPanel", W.paper_panel("cuaderno", W.label(M)))
	_spec(g1, "InkButton", W.ink_button(M))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	var grp := ButtonGroup.new()
	var t1 := W.ink_tab("«¿Índice?»", grp)
	t1.button_pressed = true
	tabs.add_child(t1)
	tabs.add_child(W.ink_tab("—¡Año, señor!—", grp))
	_spec(g1, "InkTab", tabs)
	_spec(g1, "SlotSegun", W.slot_segun(W.chip(M2), "según"))
	_spec(g1, "Chip", W.chip(M))
	_spec(g1, "StampLabel", W.stamp("¿Visto? «Ñ» —¡sí!"))
	_spec(g1, "Subtitle", W.subtitle(M))

	# extras del kit y estilos de DocBody
	var g2 := _spec_sheet(row)
	_spec(g2, "Heading", W.heading("«¿Quién?» —¡Año, señor!"))
	_spec(g2, "DocTitle", W.doc_title(M))
	_spec(g2, "Label", W.label(M))
	_spec(g2, "SmallLabel", W.small(M))
	_spec(g2, "ChipLabel", W.label(M, "ChipLabel"))
	_spec(g2, "Marginal", W.marginal(M))
	_spec(g2, "Blank", W.blank("Quién", M2))
	_spec(g2, "InkRule", W.rule())
	_spec(g2, "Button", W.button(M))
	_spec(g2, "DocBody estilos", _live("DocBody", [["itálica «ñ» ", "i"], ["negrita ¿¡ ", "b"], ["máquina —ñ— ", "font:maquina"], ["mano ¡ñ!", "font:manuscrito"]]))
	_spec(g2, "DocBody tintas", _live("DocBody", [["lápiz «ñ» ", "ink:lapiz"], ["azul ¿ñ? ", "ink:azul"], ["roja ¡ñ! ", "ink:roja"], ["tenue —ñ—", "ink:tenue"]]))
	return m

# ------------------------------------------------------------------ tipos base y widgets
func _controls() -> Control:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 28)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	m.add_child(h)

	# col 1: formulario en PaperPanel
	var p1 := PanelContainer.new()
	p1.theme_type_variation = "PaperPanel"
	p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(p1)
	var v1 := VBoxContainer.new()
	v1.add_theme_constant_override("separation", 12)
	p1.add_child(v1)
	v1.add_child(W.heading("Opciones"))
	var le := LineEdit.new()
	le.placeholder_text = "Buscar en recortes… «ñ» ¿¡"
	v1.add_child(le)
	var le2 := LineEdit.new()
	le2.text = "Reichenbach — «a pique»"
	v1.add_child(le2)
	var cb := CheckBox.new()
	cb.text = "Subtítulos de sonido"
	cb.button_pressed = true
	v1.add_child(cb)
	var cb2 := CheckBox.new()
	cb2.text = "Alto contraste"
	v1.add_child(cb2)
	var grp := ButtonGroup.new()
	for n in ["Tamaño normal", "Tamaño grande"]:
		var r := CheckBox.new()
		r.text = n
		r.button_group = grp
		r.button_pressed = n == "Tamaño normal"
		v1.add_child(r)
	var hs := HSlider.new()
	hs.min_value = 0.8
	hs.max_value = 1.6
	hs.step = 0.1
	hs.value = 1.0
	v1.add_child(W.small("Tamaño de texto"))
	v1.add_child(hs)
	var ob := OptionButton.new()
	for n in ["Imprenta", "Máquina", "Manuscrito"]:
		ob.add_item(n)
	v1.add_child(ob)
	var te := TextEdit.new()
	te.text = "Nota libre del par: «la mano cercana transmite a la lejana».\n¿Seguro? ¡Ñ!"
	te.custom_minimum_size = Vector2(0, 96)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v1.add_child(te)

	# col 2: pestañas, lista con scroll, menú emergente
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 14)
	v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v2)
	var tc := TabContainer.new()
	tc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v2.add_child(tc)
	var il := ItemList.new()
	il.name = "Índice"
	for n in ["Adair, Ronald", "Baker Street", "Camden House", "Diógenes, Club", "Hudson, señora", "Moran, coronel", "Mycroft Holmes", "Parker", "Reichenbach", "Steiler", "Watson, John H.", "Wiggins"]:
		il.add_item(n)
	il.select(4)
	tc.add_child(il)
	var sc := ScrollContainer.new()
	sc.name = "Diario"
	var dv := VBoxContainer.new()
	for i in 14:
		dv.add_child(W.label("Mar. %d, M: Sala de Lectura, asiento 214. Pedí el «Journal»." % (27 + i % 4), ""))
	sc.add_child(dv)
	tc.add_child(sc)
	var pm_host := W.paper_panel("carta", null, {"margin": 6, "shadow_size": 8})
	var pmv := VBoxContainer.new()
	pm_host.add_child(pmv)
	for n in ["Preguntar por…", "Afirmar…", "Presentar…"]:
		var b := W.ink_button(n)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pmv.add_child(b)
	v2.add_child(_tag("menú: InkButton sobre papel de carta"))
	v2.add_child(pm_host)

	# col 3: confirmación de dos pasos, sellos, subtítulo
	var v3 := VBoxContainer.new()
	v3.add_theme_constant_override("separation", 22)
	v3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v3)
	var c := W.confirm("«Señor Lisle: la pared no era a pique; véase el Journal de Genève del 6 de mayo de 1891.» ¿Lo envía usted así?", "Enviar", "Volver", "Telegrama a Meiringen")
	v3.add_child(c)
	var stamps := W.sheet("libro_mayor", {"pad": 18})
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(W.stamp("Visto"))
	row.add_child(W.stamp("Recibido: 30-mar, amanecer", "negra", 3.0, true))
	row.add_child(W.stamp("Archivado", "tenue", -9.0))
	stamps.add_child(row)
	v3.add_child(_tag("sellos: StampLabel roja · chico negra · tenue"))
	v3.add_child(stamps)
	v3.add_child(W.paper_panel("registro", W.source_line("Paper.paper_panel(\"registro\") — fuente: lista de correos, Charing Cross; ¿quién retira? «H.»")))
	var sub := W.subtitle("silbato policial, cerca")
	v3.add_child(sub)
	return m
