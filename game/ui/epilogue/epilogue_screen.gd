# ui/epilogue/epilogue_screen.gd — pantalla del epílogo (W4-EPILOGUE; ARCHITECTURE §2.3: Epilogue -> Credits ->
# BluePencil -> Title; GDD §12.1–12.3). La crea Shell.show_epilogue (capa modal) al entrar en la fase `epilogue`; ella
# misma encadena los créditos y el lápiz azul y, al cerrar el libro, `leave` (-> done) y vuelta al título.
# Estadios (cada uno sólo si tiene material; clic o «Seguir» avanza; mouse primero, Espacio/Intro también):
#   noche        HC09 (la noche fría y ventosa del jueves) según noche_final: lámina 3D (Baker Street a las 22 h, con
#                la silueta en la persiana, o la buhardilla), una línea por clic con su sonido (cuartos, arpa, silbido,
#                vidrio, silbato; _sonido/_encuadre de epilogue_ui.json).
#   final        END.<F> (escena del final, GDD §12.1) en el diario de Lisle, sobre la buhardilla de la mañana siguiente.
#   ficha        la ficha «L» del índice de Holmes (endings card + card_add de las variantes: «Cuatro de cuatro.»).
#                En el fichero, justo detrás asoma la de «Lestrade» (EE12).
#   tiempo       «Octubre de 1903», en negro.
#   lectura      la Strand (D38@L1) borrosa bajo la vista de Lisle y la lupa; su diario a la derecha (epilogo.json en el
#                orden de _orden con las variantes acumulables; las líneas de Crane de la escena EPI después de la
#                llegada). La lupa se posa en lo que el párrafo recuerda (_lente). Marcas de variante en la hoja
#                (esquina doblada y nota azul de S. H. en F1; el subrayado si watson_expuesto). En F2/F3/F4: la oferta
#                de publicar la fe de erratas, en dos pasos (Clock publish_errata).
#   tijera       el último gesto: tomar la tijera y cortar al hombre alto y delgado de anteojos de color (_corte).
#                clip_text real sobre D38@L1 (la oración entera). Otra oración: «Ésa no es la mía.».
#   concordancia la tira vuela a la última hoja de la concordancia (D21, «El problema final… Fin de la concordancia»),
#                Lisle escribe la ficha (epilogo.14.ficha); la posdata si publicó.
#   estante      (C14: tomos_devueltos) la última lámina: el estudio del doctor con el segundo estante completo.
#   creditos     credits.gd (colofón sobre la tijera).   lapiz   blue_pencil.gd (libro mayor corregido a lápiz azul).
# Para tests y drivers: advance(), choose_publish(yes), confirm(ok), set_scissors(on), do_cut(page, from, len),
# state() -> Dictionary. Animaciones ≤0,4 s (la escritura de la ficha se completa con un clic). Sin brillos ni contadores.
extends Control

signal closed
signal stage_changed(stage: String)

const Model = preload("res://ui/epilogue/epilogue_model.gd")
const StrandView = preload("res://ui/epilogue/strand_view.gd")
const Credits = preload("res://ui/epilogue/credits.gd")
const BluePencil = preload("res://ui/epilogue/blue_pencil.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const M = preload("res://world/materials.gd")
const Markup = preload("res://core/text/markup.gd")

const STAGES := ["noche", "final", "ficha", "tiempo", "lectura", "tijera", "concordancia", "estante", "creditos", "lapiz"]
const TITLE_HOLD_S := 2.6
const CARD_PEEK := 62.0
const WRITE_CPS := 34.0
const MARGIN := 36.0
const CREAM := Color("ece3cf")
const DESK := Color("231c15")

var shell = null
var sim = null
var fast := false
var sounds := true
var stage := ""
var beats: Array = []
var beat_i := -1
var info := {}
var cut := {}
var misses := 0
var done := false
var shelf_added := 0

var _busy := false
var _writing: Tween = null
var _bg: ColorRect
var _lamp: TextureRect
var _vignette: TextureRect
var _veil: ColorRect
var _caption: PanelContainer
var _cap_text: RichTextLabel
var _diary: PanelContainer
var _dscroll: ScrollContainer
var _dlist: VBoxContainer
var _b_next: Button
var _b_tijera: Button
var _offer: HBoxContainer = null
var _card_box: VBoxContainer
var _title: Label
var _strand: Control
var _conc: PanelContainer
var _conc_slot: Control
var _conc_ficha: RichTextLabel
var _plate_cap: PanelContainer
var _modal: Control = null
var _fly: Control = null
var _credits: Control = null
var _pencil: Control = null
var _marks: Array = []
var _diary_left := false
var _timer: Timer

func _init() -> void:
	name = "Epilogo"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg = ColorRect.new()
	_bg.name = "Fondo"
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0, 0, 0, 0)
	add_child(_bg)
	_lamp = _radial("Lampara", Color(1.0, 0.84, 0.56, 0.26), Color(1.0, 0.84, 0.56, 0.0))
	add_child(_lamp)
	_veil = ColorRect.new()
	_veil.name = "Velo"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(0.03, 0.025, 0.02, 0.0)
	add_child(_veil)
	_strand = StrandView.new()
	_strand.name = "Strand"
	_strand.mouse_filter = Control.MOUSE_FILTER_STOP
	_strand.visible = false
	_strand.cut_requested.connect(_on_cut)
	_strand.page_turned.connect(func(_i): _play("sfx.pagina"))
	add_child(_strand)
	_vignette = _radial("Vineta", Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.62), 0.42)
	add_child(_vignette)
	_build_diary()
	_build_caption()
	_build_card()
	_build_title()
	_build_conc()
	_build_plate_cap()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func():
		if stage == "tiempo" and not _busy:
			_next_stage())
	add_child(_timer)
	_show_only([])

# Luz de lámpara / viñeta: gradiente radial a pantalla completa (sin archivos).
static func _radial(n: String, c0: Color, c1: Color, inner := 0.0) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	if inner > 0.0:
		g.add_point(inner, c0)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var t := TextureRect.new()
	t.name = n
	t.texture = gt
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	if inner > 0.0:
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.visible = false
	return t

func _build_diary() -> void:
	_diary = Widgets.sheet("cuaderno", {"pad": 30})
	_diary.name = "Diario"
	_diary.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_diary)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 10)
	_diary.add_child(v)
	_dscroll = ScrollContainer.new()
	_dscroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_dscroll)
	_dlist = VBoxContainer.new()
	_dlist.name = "Parrafos"
	_dlist.mouse_filter = Control.MOUSE_FILTER_PASS
	_dlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dlist.add_theme_constant_override("separation", 14)
	_dscroll.add_child(_dlist)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	_b_tijera = Widgets.ink_button(Model.tx(null, "epilogue.tijera"), func(): set_scissors(not bool(_strand.scissors)))
	_b_tijera.name = "Tijera"
	foot.add_child(_b_tijera)
	_b_next = Widgets.ink_button(Model.tx(null, "epilogue.seguir"), advance)
	_b_next.name = "Seguir"
	foot.add_child(_b_next)

func _build_caption() -> void:
	_caption = PanelContainer.new()
	_caption.name = "Leyenda"
	_caption.mouse_filter = Control.MOUSE_FILTER_PASS
	Widgets.restyle(_caption, func(): _caption.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 22, "shadow": true})))
	add_child(_caption)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_theme_constant_override("separation", 18)
	_caption.add_child(h)
	_cap_text = TextBuilder.make_rtl("imprenta")
	_cap_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_cap_text)
	var b := Widgets.ink_button(Model.tx(null, "epilogue.seguir"), advance)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	h.add_child(b)
	# el alto real de la leyenda llega un cuadro después (el texto se mide con su ancho): reubicarla y subir los subtítulos
	_caption.minimum_size_changed.connect(func():
		if is_inside_tree():
			_layout.call_deferred())

func _build_card() -> void:
	var cc := CenterContainer.new()
	cc.name = "Ficha"
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	_card_box = VBoxContainer.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_theme_constant_override("separation", 12)
	cc.add_child(_card_box)

func _build_title() -> void:
	var cc := CenterContainer.new()
	cc.name = "Tiempo"
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	_title = Widgets.label("", "Heading")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_title)

func _build_conc() -> void:
	_conc = Widgets.sheet("cuaderno", {"ruled": true, "margin_line": 52, "pad": 34})
	_conc.name = "Concordancia"
	_conc.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_conc)
	# si la hoja (con la ficha ya reservada) no cabe sobre los subtítulos, se achica entera (ver _layout)
	_conc.minimum_size_changed.connect(func():
		if is_inside_tree() and _conc.visible:
			_layout.call_deferred())

func _build_plate_cap() -> void:
	_plate_cap = PanelContainer.new()
	_plate_cap.name = "Epigrafe"
	_plate_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(_plate_cap, func(): _plate_cap.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 14, "shadow": true})))
	var l := Widgets.label("", "Caption")
	l.name = "Texto"
	_plate_cap.add_child(l)
	add_child(_plate_cap)

# ------------------------------------------------------------------ disposición
func _vs() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return size if size.x > 10.0 and size.y > 10.0 else Vector2(1600, 900)

# Alto libre a la derecha: los subtítulos de los sonidos (Shell, capa 90) ocupan el pie derecho; las hojas no se meten debajo.
func _right_bottom() -> float:
	var vs := _vs()
	var b := vs.y - MARGIN
	if shell != null and shell.has_method("subs_rect"):
		var r: Rect2 = shell.subs_rect()
		if r.size.y > 0.0:
			b = minf(b, r.position.y - 10.0)
	return b

func _diary_rect() -> Rect2:
	var vs := _vs()
	var w := clampf(vs.x * 0.34, 440.0, 600.0)
	if _diary_left:
		# después del corte: el diario cuenta el gesto, una hoja corta a la izquierda
		return Rect2(MARGIN, vs.y * 0.2, w, vs.y * 0.6)
	return Rect2(vs.x - MARGIN - w, MARGIN, w, _right_bottom() - MARGIN)

func _layout() -> void:
	var vs := _vs()
	var dr := _diary_rect()
	_diary.position = dr.position
	_diary.size = dr.size
	_diary.custom_minimum_size = dr.size
	var cw0 := clampf(vs.x * 0.34, 440.0, 600.0)
	var cr := Rect2(vs.x - MARGIN - cw0, MARGIN, cw0, _right_bottom() - MARGIN)
	# la última hoja de la concordancia cabe entera sobre los subtítulos: si su contenido (cabeza, «El problema final»,
	# la tira y la ficha nueva, reservada desde el principio) pide más alto, la hoja se achica (escala) sin reflujo
	_conc.scale = Vector2.ONE
	_conc.custom_minimum_size = cr.size
	_conc.size = cr.size
	var need := maxf(cr.size.y, _conc.get_combined_minimum_size().y)
	var kc := clampf(cr.size.y / need, 0.5, 1.0)
	_conc.scale = Vector2(kc, kc)
	_conc.position = Vector2(cr.end.x - cr.size.x * kc, cr.position.y)
	var left := Rect2(MARGIN, MARGIN, cr.position.x - 2.0 * MARGIN, vs.y - 2.0 * MARGIN)
	_strand.position = left.position
	_strand.size = left.size
	var cw := minf(1000.0, vs.x - 160.0)
	_caption.custom_minimum_size = Vector2(cw, 0)
	_caption.size = Vector2(cw, 0)
	_caption.position = Vector2((vs.x - cw) * 0.5, vs.y - MARGIN - _caption.get_combined_minimum_size().y)
	_plate_cap.position = Vector2(MARGIN, vs.y - MARGIN - _plate_cap.get_combined_minimum_size().y)
	_lamp.position = Vector2(-vs.x * 0.15, -vs.y * 0.35)
	_lamp.size = Vector2(vs.x * 0.95, vs.y * 1.6)
	_subs_inset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

func _show_only(names: Array) -> void:
	_diary.visible = names.has("diary")
	_caption.visible = names.has("caption")
	(_card_box.get_parent() as Control).visible = names.has("card")
	(_title.get_parent() as Control).visible = names.has("title")
	_strand.visible = names.has("strand")
	_conc.visible = names.has("conc")
	_plate_cap.visible = names.has("plate_cap")
	_lamp.visible = names.has("lamp")
	_vignette.visible = names.has("lamp")

# ------------------------------------------------------------------ arranque (Shell: open())
func open() -> void:
	start()

func set_shell(s) -> void:
	shell = s

func start() -> void:
	if shell == null:
		# Shell.show_epilogue no fija `shell` (sólo open()): se busca hacia arriba (duck typing, sin class_name)
		var p := get_parent()
		while p != null:
			if p.has_method("show_epilogue") and p.has_method("act"):
				shell = p
				break
			p = p.get_parent()
	if sim == null:
		if shell != null and shell.has_method("sim"):
			sim = shell.sim()
		else:
			var g := _autoload("Game")
			sim = g.sim if g != null else null
	if shell != null and "fast" in shell:
		fast = bool(shell.fast)
	if shell != null and "sounds" in shell:
		sounds = bool(shell.sounds)
	_strand.fast = fast
	info = Model.info(sim)
	_b_next.text = Model.tx(sim, "epilogue.seguir")
	_b_tijera.text = Model.tx(sim, "epilogue.tijera")
	var w = _world()
	if w != null and w.has_method("set_input_enabled"):
		w.set_input_enabled(false)
	_layout()
	stage = ""
	_enter(_next_available(-1))

func _next_available(from_i: int) -> String:
	for i in range(from_i + 1, STAGES.size()):
		if _available(String(STAGES[i])):
			return String(STAGES[i])
	return ""

func _available(s: String) -> bool:
	match s:
		"noche":
			return sim != null and not (Model.night(sim).get("lines", []) as Array).is_empty()
		"final":
			return not Model.end_lines(sim).is_empty()
		"ficha":
			return String(info.get("card", "")) != ""
		"tiempo":
			return true
		"lectura":
			return sim != null and not Model.reading_beats(sim).is_empty()
		"tijera":
			return sim != null and not Model.cut_target(sim).is_empty() and not Model.strand_view(sim).is_empty()
		"concordancia":
			return sim != null
		"estante":
			var e := Model.setting(sim, "_estante")
			var repo = Model.repo_of(sim)
			return _world() != null and (info.get("epi", []) as Array).has(String(e.get("variant", "-"))) and repo != null \
				and not repo.place(String(e.get("place", ""))).is_empty()
		"creditos", "lapiz":
			return true
	return false

func _next_stage() -> void:
	if _busy or done:
		return
	var nx := _next_available(STAGES.find(stage))
	if nx == "":
		_finish()
		return
	_busy = true
	await _fade(1.0)
	if not is_inside_tree() and shell != null:
		return
	_enter(nx)
	await _fade(0.0)
	_busy = false

func _fade(a: float) -> void:
	if fast or shell == null or not shell.has_method("fade_out"):
		return
	if a > 0.5:
		await shell.fade_out()
	else:
		await shell.fade_in()

# ------------------------------------------------------------------ estadios
func _enter(s: String) -> void:
	stage = s
	beats = []
	beat_i = -1
	_veil.color.a = 0.0
	_bg.color = Color(0, 0, 0, 0)
	var w = _world()
	match s:
		"noche":
			var n := Model.night(sim)
			beats = n.lines
			_show_plate(String(n.place), String(n.area), int(n.tk), "night", String(n.frame))
			_ambience(String(n.place), "%d.night" % TimeKey.day_of(int(n.tk)))
			_veil.color.a = 0.12
			_show_only(["caption"])
			_next_beat()
		"final":
			var f := Model.setting(sim, "_final")
			for ln in Model.end_lines(sim):
				beats.append({"kind": "para", "key": String(ln.id), "parsed": ln.parsed, "lens": ""})
			_show_plate(String(f.get("place", "L1")), String(f.get("area", "")), Model._tk(f.get("tk", ""), 104), String(f.get("slot", "M")), String(f.get("frame", "")))
			_ambience(String(f.get("place", "L1")), String(f.get("slot", "M")))
			_veil.color.a = 0.18
			_diary_left = false
			_clear_diary()
			_layout()
			_show_only(["diary"])
			_b_tijera.visible = false
			_b_next.visible = true
			_next_beat()
		"ficha":
			_veil.color.a = 0.62
			_fill_card()
			_show_only(["card"])
		"tiempo":
			if w != null:
				w.visible = false
			_amb("")
			_bg.color = Color(0.02, 0.016, 0.012, 1.0)
			_title.text = Model.tx(sim, "epilogo.titulo")
			_title.add_theme_color_override("font_color", CREAM)
			var ti := TextBuilder.ti_node()
			_title.add_theme_font_size_override("font_size", int(round(float(ti.px("title") if ti != null else 34) * 1.25)))
			_show_only(["title"])
			if not fast and is_inside_tree():
				_timer.start(TITLE_HOLD_S)
		"lectura":
			if w != null:
				w.visible = false
			_bg.color = DESK
			_amb("clock.tic")
			_diary_left = false
			_clear_diary()
			_layout()
			_show_only(["diary", "lamp"])
			_b_tijera.visible = false
			_b_next.visible = true
			var v := Model.strand_view(sim)
			if not v.is_empty():
				_strand.setup(v, _strand.size if _strand.size.x > 10.0 else Vector2(900, 820))
				_marks = Model.page_marks(sim)
				var init: Array = []
				for m in _marks:
					if String(m.kind) == "nota_azul":
						init.append({"kind": "esquina", "page": int(m.page), "from": 0, "to": 0})
				_strand.set_marks(init, Model.tx(sim, "epilogue.nota_s_h"))
			beats = Model.reading_beats(sim)
			_next_beat()
		"tijera":
			_bg.color = DESK
			cut = Model.cut_target(sim)
			misses = 0
			_show_only(["diary", "lamp", "strand"])
			_b_next.visible = false
			_b_tijera.visible = true
			_b_tijera.text = Model.tx(sim, "epilogue.tijera")
			_strand.park(cut)
		"concordancia":
			_bg.color = DESK
			_enter_conc()
		"estante":
			var e := Model.setting(sim, "_estante")
			_amb("")
			_show_plate(String(e.place), String(e.get("area", "")), Model._tk(e.get("tk", ""), 104), String(e.get("slot", "T")), String(e.get("frame", "")))
			_fill_shelf(String(e.place), String(e.get("prop", "")), int(e.get("tomos", 5)))
			(_plate_cap.get_node("Texto") as Label).text = Model.tx(sim, "epilogue.estante.pie")
			_show_only(["plate_cap"])
			_layout()
		"creditos":
			if w != null:
				w.visible = false
			_amb("")
			_show_only([])
			_bg.color = Color(0, 0, 0, 1)
			_credits = Credits.new()
			add_child(_credits)
			_credits.open(sim, shell)
			_credits.finished.connect(func(): _next_stage(), CONNECT_ONE_SHOT)
			_credits.start()
		"lapiz":
			if _credits != null:
				_credits.queue_free()
				_credits = null
			_show_only([])
			_pencil = BluePencil.new()
			add_child(_pencil)
			_pencil.open(sim, shell)
			_pencil.finished.connect(_finish, CONNECT_ONE_SHOT)
			_pencil.start()
		"":
			_finish()
	_subs_inset()
	stage_changed.emit(stage)

# ------------------------------------------------------------------ avanzar
func advance() -> void:
	if _busy or done or _modal != null:
		return
	if _writing != null and _writing.is_valid():
		_writing.kill()
		_writing = null
		if _conc_ficha != null:
			_conc_ficha.visible_ratio = 1.0
		return
	match stage:
		"noche", "final", "lectura", "concordancia":
			if _offer != null:
				return
			_next_beat()
		"ficha", "tiempo", "estante":
			_timer.stop()
			_next_stage()
		"creditos":
			if _credits != null:
				_credits.click()
		_:
			pass

func _next_beat() -> void:
	beat_i += 1
	if beat_i >= beats.size():
		if stage == "lectura" and _available("tijera"):
			_enter("tijera")
			return
		_next_stage()
		return
	_show_beat(beats[beat_i])

func _show_beat(b: Dictionary) -> void:
	match stage:
		"noche":
			TextBuilder.build(_cap_text, b.parsed, {"slot": "imprenta", "size": _doc_px(1.08)})
			_layout.call_deferred()
			_fade_in(_caption)
			var f := String(b.get("frame", ""))
			var w = _world()
			if f != "" and w != null and w.rig.has_frame(f):
				w.set_frame(f, fast)
			_play_seq(b.get("sounds", []))
		"final":
			_diary_add(b)
		"lectura":
			_diary_add(b)
			var lens := String(b.get("lens", ""))
			if not _strand.visible and (lens != "" or String(b.key).begins_with("epilogo.03")) and not Model.strand_view(sim).is_empty():
				_strand.visible = true
				_fade_in(_strand)
			if lens != "" and _strand.visible:
				_strand.park(Model.tramo_at(sim, lens))
			_reveal_marks(String(b.key))
			if String(b.kind) == "offer":
				_show_offer(b)
		"concordancia":
			if String(b.kind) == "ficha":
				_write_ficha(b.parsed)
			else:
				_diary_add(b)

# Marcas de variante: aparecen cuando el diario las cuenta («k+variante»).
func _reveal_marks(key: String) -> void:
	var cur: Array = _strand.marks.duplicate(true)
	var changed := false
	var note_now := false
	for m in _marks:
		if key.ends_with("+" + String(m.variant)):
			var have := false
			for c in cur:
				if String(c.kind) == String(m.kind) and int(c.from) == int(m.from):
					have = true
			if not have:
				cur.append(m)
				changed = true
				note_now = note_now or String(m.kind) == "nota_azul"
	if changed:
		_strand.set_marks(cur, Model.tx(sim, "epilogue.nota_s_h"))
		if note_now:
			_strand.park_note()

# ------------------------------------------------------------------ diario
func _clear_diary() -> void:
	for c in _dlist.get_children():
		_dlist.remove_child(c)
		c.queue_free()

func _doc_px(k := 1.0) -> int:
	var ti := TextBuilder.ti_node()
	return int(round(float(ti.px("doc") if ti != null else 21) * k))

func _diary_add(b: Dictionary) -> Control:
	var node: Control
	match String(b.get("kind", "para")):
		"date":
			var l := Widgets.label(String(b.parsed.get("plain", "")), "DocTitle")
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			node = l
		"line":
			var v := VBoxContainer.new()
			v.mouse_filter = Control.MOUSE_FILTER_PASS
			v.add_theme_constant_override("separation", 2)
			if String(b.get("name", "")) != "":
				var n := Widgets.label(String(b.name), "SourceLine")
				n.mouse_filter = Control.MOUSE_FILTER_PASS
				v.add_child(n)
			var r := TextBuilder.make_rtl("imprenta")
			TextBuilder.build(r, b.parsed, {"slot": "imprenta", "size": _doc_px(0.98)})
			v.add_child(r)
			node = v
		"ficha":
			var r2 := TextBuilder.make_rtl("manuscrito")
			TextBuilder.build(r2, b.parsed, {"slot": "manuscrito", "size": _doc_px(0.95)})
			node = r2
		_:
			var r3 := TextBuilder.make_rtl("imprenta")
			TextBuilder.build(r3, b.parsed, {"slot": "imprenta", "size": _doc_px(1.0)})
			node = r3
	node.name = "P%02d" % _dlist.get_child_count()
	node.set_meta("key", String(b.get("key", "")))
	node.set_meta("plain", String(b.get("parsed", {}).get("plain", "")))
	_dlist.add_child(node)
	_fade_in(node)
	_scroll_end.call_deferred()
	return node

func _scroll_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(_dscroll):
		return
	var target := int(_dscroll.get_v_scroll_bar().max_value)
	if fast:
		_dscroll.scroll_vertical = target
	else:
		create_tween().tween_property(_dscroll, "scroll_vertical", target, 0.3)

func diary_texts() -> Array:
	var out: Array = []
	for c in _dlist.get_children():
		if not c.is_queued_for_deletion() and c.has_meta("plain"):
			out.append(String(c.get_meta("plain")))
	return out

func diary_keys() -> Array:
	var out: Array = []
	for c in _dlist.get_children():
		if not c.is_queued_for_deletion() and c.has_meta("key"):
			out.append(String(c.get_meta("key")))
	return out

# ------------------------------------------------------------------ la fe de erratas (F2/F3/F4): dos pasos
func _show_offer(b: Dictionary) -> void:
	_offer = HBoxContainer.new()
	_offer.name = "Oferta"
	_offer.add_theme_constant_override("separation", 16)
	_offer.add_child(Widgets.button(String(b.yes), func(): choose_publish(true)))
	_offer.add_child(Widgets.button(String(b.no), func(): choose_publish(false)))
	_dlist.add_child(_offer)
	_b_next.disabled = true
	_scroll_end.call_deferred()

func choose_publish(yes: bool) -> void:
	if _offer == null or _modal != null:
		return
	var body := Model.tx(sim, "epilogo.12.publicar." + ("si" if yes else "no"))
	var c = Widgets.confirm(body, Model.tx(sim, "epilogue.publicar.ok"), Model.tx(sim, "kit.confirm.back"), Model.tx(sim, "epilogue.publicar.titulo"))
	c.name = "Confirmar"
	c.set_meta("yes", yes)
	_strand.lens_on = false
	_strand.follow(Vector2(-9999, -9999))
	_modal = CenterContainer.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(dim)
	_modal.add_child(c)
	add_child(_modal)
	c.decided.connect(func(ok): confirm(ok), CONNECT_ONE_SHOT)

func confirm(ok: bool) -> void:
	if _modal == null:
		return
	_strand.lens_on = true
	_strand.follow(Vector2(-9999, -9999))
	var c := _modal.get_node_or_null("Confirmar")
	var yes := bool(c.get_meta("yes")) if c != null else false
	_modal.queue_free()
	_modal = null
	if not ok:
		return
	var r := _act({"t": "publish_errata", "yes": yes})
	if not bool(r.get("ok", false)) and String(r.get("err", "")) != "ya_decidido":
		_note_err(String(r.get("err", "")))
		return
	_play("sfx.sobre" if yes else "sfx.papel")
	if _offer != null:
		_offer.queue_free()
		_offer = null
	_b_next.disabled = false
	info = Model.info(sim)
	if not yes:
		_diary_add({"kind": "para", "key": Model.KEY_PUBLICAR + ".guardada", "parsed": Model.parse(sim, Model.tx(sim, Model.KEY_PUBLICAR + ".guardada")), "lens": ""})

# ------------------------------------------------------------------ la tijera: el último gesto
func set_scissors(on: bool) -> void:
	if stage != "tijera":
		on = false
	_strand.set_scissors(on)
	_b_tijera.text = Model.tx(sim, "epilogue.tijera.dejar" if on else "epilogue.tijera")
	if on:
		_play("sfx.papel")

func do_cut(page: int, from: int, length: int) -> void:
	_on_cut(page, from, length)

func _on_cut(page: int, from: int, length: int) -> void:
	if stage != "tijera" or _busy:
		return
	if not Model.hits_cut(sim, page, from, length):
		misses += 1
		_note(Model.tx(sim, "epilogue.tijera.otra"))
		if misses >= 2:
			_strand.park(cut)
		return
	var t := cut
	var r := _act({"t": "clip_text", "src": {"kind": "doc", "ref": String(t.view), "part": int(t.page), "block": 0},
		"from": int(t.from), "len": int(t.to) - int(t.from)})
	if not bool(r.get("ok", false)):
		push_warning("Epilogo: el recorte final no se registró (%s)" % String(r.get("err", "")))
	_play("sfx.tijera")
	_strand.set_scissors(false)
	_enter("concordancia")

# ------------------------------------------------------------------ concordancia: la tira, la ficha, la posdata
func _enter_conc() -> void:
	beats = Model.closing_beats(sim)
	beat_i = -1
	var data := Model.concordance(sim)
	for c in _conc.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_theme_constant_override("separation", 10)
	_conc.add_child(v)
	var cap := Widgets.label(String(data.title), "SourceLine")
	v.add_child(cap)
	if String(data.head) != "":
		v.add_child(_hand(String(data.head), 0.9))
	if String(data.body) != "":
		v.add_child(_hand(String(data.body), 0.9))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	v.add_child(sp)
	_conc_slot = Control.new()
	_conc_slot.name = "Tira"
	_conc_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_conc_slot)
	_conc_ficha = TextBuilder.make_rtl("manuscrito")
	_conc_ficha.name = "FichaNueva"
	# la ficha se compone ya (invisible) para que la hoja tenga desde el principio su alto final: la tira vuela a su
	# lugar definitivo y la hoja no crece ni se achica mientras Lisle escribe
	_conc_ficha.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	for b in beats:
		if String(b.get("kind", "")) == "ficha":
			TextBuilder.build(_conc_ficha, b.parsed, {"slot": "manuscrito", "size": _doc_px(1.12)})
			break
	_conc_ficha.visible_ratio = 0.0
	v.add_child(_conc_ficha)
	# la tira cortada: de la hoja de la Strand a la concordancia
	var strip := _make_strip(String(cut.get("text", "")))
	var from_rect: Rect2 = _strand.tramo_rect(int(cut.get("from", 0)), int(cut.get("to", 0))) if not cut.is_empty() else Rect2()
	_conc_slot.custom_minimum_size = Vector2(0, strip.get_combined_minimum_size().y + 6.0)
	_show_only(["strand", "conc", "lamp"])
	_diary_left = true
	_clear_diary()
	_b_next.visible = true
	_b_tijera.visible = false
	_layout()
	_fade_in(_conc)
	if String(cut.get("text", "")) != "" and from_rect.size.x > 2.0:
		_busy = true
		_fly = strip
		strip.top_level = true
		add_child(strip)
		strip.position = from_rect.position
		_land_strip.call_deferred(strip)
	else:
		strip.queue_free()
		_after_strip()

# Pegada la tira: la hoja de la Strand se va y el diario (ahora a la izquierda) cuenta el gesto.
func _after_strip() -> void:
	_busy = false
	_strand.visible = false
	_strand.modulate.a = 1.0
	_diary.visible = true
	_layout()
	_next_beat()

func _hand(text: String, k := 1.0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	var ti := TextBuilder.ti_node()
	if ti != null:
		l.add_theme_font_override("font", ti.font("manuscrito"))
	l.add_theme_font_size_override("font_size", int(round(float(TextBuilder.slot_size("manuscrito")) * k)))
	l.add_theme_color_override("font_color", Paper.ink("negra"))
	return l

func _make_strip(text: String) -> Control:
	var s = Credits.Strip.new()
	s.name = "TiraCortada"
	s.seed = 17
	var r := TextBuilder.make_rtl("imprenta")
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	TextBuilder.build(r, Model.parse(sim, Markup.escape(text)), {"slot": "imprenta", "size": int(_strand.doc_px())})
	var w := minf(_diary_rect().size.x - 80.0, maxf(240.0, _strand.tramo_rect(int(cut.get("from", 0)), int(cut.get("to", 0))).size.x if not cut.is_empty() else 400.0))
	r.custom_minimum_size = Vector2(w, 0)
	s.add_child(r)
	return s

func _land_strip(strip: Control) -> void:
	if not is_inside_tree() or not is_instance_valid(strip) or not is_instance_valid(_conc_slot):
		_after_strip()
		return
	await get_tree().process_frame
	if not is_instance_valid(strip) or not is_instance_valid(_conc_slot):
		_after_strip()
		return
	# la ranura toma el alto real de la tira (el RichTextLabel se mide recién dentro del árbol)
	_conc_slot.custom_minimum_size = Vector2(0, maxf(strip.size.y, strip.get_combined_minimum_size().y) + 12.0)
	await get_tree().process_frame
	if not is_instance_valid(strip) or not is_instance_valid(_conc_slot):
		_after_strip()
		return
	# la hoja pudo achicarse para caber (ficha reservada): un cuadro más para que la ranura tenga su lugar final
	_layout()
	await get_tree().process_frame
	if not is_instance_valid(strip) or not is_instance_valid(_conc_slot):
		_after_strip()
		return
	var target := _conc_slot.get_global_transform() * Vector2(4, 2)
	if fast:
		_settle_strip(strip)
		return
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(strip, "position", target, 0.4)
	tw.tween_property(strip, "rotation_degrees", -1.2, 0.4)
	tw.tween_property(strip, "scale", _conc.scale, 0.4)
	tw.tween_property(_strand, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(_settle_strip.bind(strip))

func _settle_strip(strip: Control) -> void:
	if is_instance_valid(strip) and is_instance_valid(_conc_slot):
		strip.top_level = false
		if strip.get_parent() != _conc_slot:
			strip.reparent(_conc_slot, false)
		strip.position = Vector2(4, 2)
		strip.rotation_degrees = -1.2
		strip.scale = Vector2.ONE
	_fly = null
	_play("sfx.papel")
	_after_strip()

func _write_ficha(parsed: Dictionary) -> void:
	if _conc_ficha == null:
		return
	TextBuilder.build(_conc_ficha, parsed, {"slot": "manuscrito", "size": _doc_px(1.12)})
	_conc_ficha.set_meta("plain", String(parsed.get("plain", "")))
	_play("sfx.plumin")
	if fast or not is_inside_tree():
		_conc_ficha.visible_ratio = 1.0
		return
	_conc_ficha.visible_ratio = 0.0
	var n := String(parsed.get("plain", "")).length()
	_writing = create_tween()
	_writing.tween_property(_conc_ficha, "visible_ratio", 1.0, maxf(0.4, float(n) / WRITE_CPS))
	_writing.finished.connect(func(): _writing = null)

# ------------------------------------------------------------------ ficha «L» del índice de Holmes
func _fill_card() -> void:
	for c in _card_box.get_children():
		c.queue_free()
	var cap := Widgets.label(Model.tx(sim, "epilogue.ficha.indice"), "Caption")
	cap.add_theme_color_override("font_color", CREAM)
	var ti0 := TextBuilder.ti_node()
	cap.add_theme_font_size_override("font_size", ti0.px("ui") if ti0 != null else 19)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(cap)
	# el fichero: la ficha de Lisle va justo después de la de «Lestrade» (EE12, GDD §13.12; easter_eggs.json la deja a
	# este WP), que asoma detrás con su primer renglón. Sin rótulo ni subrayado: quien lo note, lo nota.
	var card_sz := Vector2(600, 320)
	var stack := Control.new()
	stack.name = "Fichero"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.custom_minimum_size = card_sz + Vector2(0, CARD_PEEK)
	_card_box.add_child(stack)
	var prev_txt := Model.tx(sim, "epilogue.ficha.anterior")
	if prev_txt != "" and prev_txt != "epilogue.ficha.anterior":
		var back := Widgets.sheet("registro", {"ruled": true, "pad": 14})
		back.name = "FichaAnterior"
		back.custom_minimum_size = card_sz
		back.size = card_sz
		back.position = Vector2(-6, 0)
		back.pivot_offset = card_sz * 0.5
		back.rotation_degrees = -0.9
		back.modulate = Color(0.9, 0.88, 0.84)
		var bl := _hand(prev_txt, 0.95)
		bl.name = "Anterior"
		bl.autowrap_mode = TextServer.AUTOWRAP_OFF
		back.add_child(bl)
		bl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		stack.add_child(back)
	var card := Widgets.sheet("registro", {"ruled": true, "pad": 30})
	card.name = "Tarjeta"
	card.custom_minimum_size = card_sz
	card.position = Vector2(0, CARD_PEEK)
	card.size = card_sz
	stack.add_child(card)
	card.resized.connect(func(): stack.custom_minimum_size = Vector2(card_sz.x, CARD_PEEK + card.size.y))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var top := HBoxContainer.new()
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(fill)
	var letter := _hand(Model.tx(sim, "epilogue.ficha.letra"), 1.6)
	top.add_child(letter)
	v.add_child(top)
	var body := _hand(String(info.get("card", "")), 1.3)
	body.name = "Texto"
	v.add_child(body)
	# la ficha no se come el clic (W4: un clic sobre la ficha no avanzaba) y lleva su «Seguir» a la vista
	_ignore_mouse(stack)
	var chip := Widgets.paper_panel("carta", null, {"margin": 6, "shadow": true})
	chip.name = "SeguirFicha"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var b := Widgets.ink_button(Model.tx(sim, "epilogue.seguir"), advance)
	b.name = "Boton"
	chip.add_child(b)
	_card_box.add_child(chip)
	_fade_in(_card_box)

static func _ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

func card_text() -> String:
	var t = _card_box.find_child("Texto", true, false)
	return String(t.text) if t is Label else ""

# ------------------------------------------------------------------ láminas 3D
func _world():
	if shell != null and "world" in shell and shell.world != null and is_instance_valid(shell.world):
		return shell.world
	return null

func _show_plate(place: String, area: String, tk: int, slot: String, frame: String) -> void:
	var w = _world()
	var repo = Model.repo_of(sim)
	if w == null or repo == null or place == "":
		return
	var pl: Dictionary = repo.place(place)
	if pl.is_empty():
		return
	var snap := Model.snapshot(sim, place, area, tk, slot, frame)
	w.visible = true
	w.show_plate(snap, pl)
	if w.has_method("set_input_enabled"):
		w.set_input_enabled(false)
	if frame != "" and w.rig.has_frame(frame):
		w.set_frame(frame, true)

# Los cinco tomos vuelven al segundo estante (GDD §12.2 C14): cajas en el local del prop, como sus lomos vecinos.
func _fill_shelf(place: String, prop: String, n: int) -> void:
	shelf_added = 0
	var w = _world()
	var repo = Model.repo_of(sim)
	if w == null or repo == null or w.diorama == null:
		return
	var holder: Node3D = w.diorama.get_node_or_null("Props/" + prop.replace(".", "_"))
	if holder == null:
		return
	var tomos := Node3D.new()
	tomos.name = "TomosDevueltos"
	holder.add_child(tomos)
	for b in Model.shelf_volumes(repo.place(place), prop, n):
		var size: Vector3 = b.size
		var pos: Vector3 = b.pos
		M.box(tomos, size, pos, "cuero")
		for k in 2:
			M.box(tomos, Vector3(size.x + 0.002, 0.008, 0.004), Vector3(pos.x, pos.y + size.y * (0.32 - 0.22 * k), pos.z + size.z / 2.0 + 0.002), "laton")
		M.box(tomos, Vector3(size.x * 0.6, 0.035, 0.004), Vector3(pos.x, pos.y + size.y * 0.16, pos.z + size.z / 2.0 + 0.002), "carbon")
		shelf_added += 1

# ------------------------------------------------------------------ fin
func _finish() -> void:
	if done:
		return
	done = true
	if sim != null and String(sim.q_clock().get("phase", "")) == "epilogue":
		_act({"t": "leave"})
	_amb("")
	if shell != null and shell.has_method("set_subs_inset"):
		shell.set_subs_inset(0.0)
	if shell != null and shell.has_method("quit_to_title"):
		shell.quit_to_title()
	else:
		closed.emit()

func close() -> void:
	visible = false

# fe_volver (Esc / clic derecho): deja la tijera, cierra la confirmación, salta el colofón.
func back() -> bool:
	if _modal != null:
		var c := _modal.get_node_or_null("Confirmar")
		if c != null:
			c.decided.emit(false)
		else:
			confirm(false)
		return true
	if stage == "tijera" and bool(_strand.scissors):
		set_scissors(false)
		return true
	if stage == "creditos" and _credits != null:
		_credits.skip()
		return true
	# el lápiz azul es lo último: volver = cerrar el libro (vuelta al título), como su botón al pie
	if stage == "lapiz" and _pencil != null and is_instance_valid(_pencil) and _pencil.has_method("close_book"):
		return bool(_pencil.close_book())
	return false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()

func _unhandled_input(ev: InputEvent) -> void:
	if not is_visible_in_tree() or done:
		return
	if InputMap.has_action("fe_tijera") and ev.is_action_pressed("fe_tijera") and not ev.is_echo() and stage == "tijera":
		set_scissors(not bool(_strand.scissors))
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("ui_accept") and not ev.is_echo() and _pencil == null:
		advance()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------ utilidades
func _fade_in(n: CanvasItem) -> void:
	if fast or not is_inside_tree():
		n.modulate.a = 1.0
		return
	n.modulate.a = 0.0
	Widgets.fade(n, 1.0, 0.35)

func _autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	return ml.root.get_node_or_null(n) if ml is SceneTree else null

func _act(a: Dictionary) -> Dictionary:
	if shell != null and shell.has_method("act"):
		return shell.act(a)
	var g := _autoload("Game")
	if g != null and g.sim != null and g.sim == sim:
		return g.act(a)
	return sim.apply(a) if sim != null else {"ok": false, "err": "no_sim"}

func _play(id: String) -> void:
	if not sounds:
		return
	if shell != null:
		if shell.has_method("play"):
			shell.play(id)
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("has_sound") and au.has_sound(id):
		au.play(id)

func _play_seq(ids: Array) -> void:
	if ids.is_empty():
		return
	_play(String(ids[0]))
	if ids.size() > 1 and is_inside_tree() and not fast:
		var tw := create_tween()
		for k in range(1, ids.size()):
			tw.tween_interval(0.55)
			tw.tween_callback(_play.bind(String(ids[k])))

func _ambience(place: String, slot: String) -> void:
	if not sounds:
		return
	if shell != null and shell.has_method("ambience"):
		shell.ambience(place, slot)

func _amb(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au == null:
		return
	if id == "":
		au.stop_amb(1.0)
	elif au.has_method("has_sound") and au.has_sound(id):
		au.play_amb(id, 1.0)

func _note(text: String) -> void:
	if shell != null and shell.has_method("note"):
		shell.note(text)

func _note_err(err: String) -> void:
	if shell != null and shell.has_method("err_text"):
		_note(shell.err_text(err))

# Estado visible (tests y drivers).
func state() -> Dictionary:
	return {"stage": stage, "beat": beat_i, "beats": beats.size(), "diary": diary_texts(), "keys": diary_keys(),
		"offer": _offer != null, "modal": _modal != null, "scissors": bool(_strand.scissors), "strand": _strand.visible,
		"page": int(_strand.page_idx), "marks": (_strand.marks as Array).map(func(m): return String(m.kind)),
		"card": card_text(), "ficha": String(_conc_ficha.get_meta("plain", "")) if _conc_ficha != null else "",
		"strip": _conc_slot != null and is_instance_valid(_conc_slot) and _conc_slot.get_child_count() > 0, "done": done,
		"shelf": shelf_added, "caption": _cap_text.get_parsed_text() if _caption.visible else ""}

# Los subtítulos de los sonidos (capa 90, abajo a la derecha) suben por encima de la leyenda de la noche.
# Se calcula con la leyenda ya ubicada (_layout la pone al pie con su alto real): antes de medirse con su ancho, el
# texto pide un alto enorme y los subtítulos se iban fuera de la pantalla toda la noche.
func _subs_inset() -> void:
	if shell == null or not shell.has_method("set_subs_inset"):
		return
	if stage == "noche" and _caption.visible:
		var vs := _vs()
		shell.set_subs_inset(clampf(vs.y - _caption.position.y - 10.0, 0.0, vs.y * 0.45))
	else:
		shell.set_subs_inset(0.0)
