# ui/desk/catalog.gd — Sala de Lectura: catálogo general y papeletas (GDD§5 L2, §7.5). Dueño: W3-SHELL. Panel (capa escena).
# Se busca por cualquier entidad del índice del jugador (q_index); el catálogo devuelve hasta 5 asientos mezclados con
# obras de época sin relación (q_catalog). Pedir = papeleta (acción comprometida «slip»: confirmación en dos pasos con
# el asiento a la vista). Tres papeletas por visita: se ven como tres tiras de papel en la mesa (sin número). Lo pedido
# queda «sobre su mesa» y se lee en el lector. open() · close() · señales closed, read_requested(view).
extends Control

signal closed
signal read_requested(view: String)

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const SLIPS := 3
var _remeasure := 0

var shell = null
var seat := 0
var sheet: PanelContainer
var filter_edit: LineEdit
var index_list: VBoxContainer
var results: VBoxContainer
var desk_list: VBoxContainer
var slips_row: HBoxContainer
var head_seat: Label
var _entity := ""
var _confirm: Control = null

func _init() -> void:
	name = "Catalog"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _sim():
	var g = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return g.sim if g != null else null

func _ready() -> void:
	sheet = Widgets.sheet("registro", {"pad": 24})
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	sheet.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var h := Widgets.heading(Widgets.t("shell.cat.title"))
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(h)
	head_seat = Widgets.label("", "SourceLine")
	head_seat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(head_seat)
	top.add_child(Widgets.ink_button(Widgets.t("kit.close"), close))
	v.add_child(Widgets.rule())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	# índice (de lo que el jugador ya conoce)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(Widgets.label(Widgets.t("shell.cat.buscar"), "SourceLine"))
	filter_edit = LineEdit.new()
	filter_edit.placeholder_text = Widgets.t("shell.cat.filtro")
	filter_edit.text_changed.connect(func(_t): _fill_index())
	left.add_child(filter_edit)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	index_list = VBoxContainer.new()
	index_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(index_list)
	# resultados
	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(340, 0)
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	mid.add_child(Widgets.label(Widgets.t("shell.cat.asientos"), "SourceLine"))
	results = VBoxContainer.new()
	results.add_theme_constant_override("separation", 8)
	mid.add_child(results)
	# mesa: papeletas y lo pedido
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(230, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(Widgets.label(Widgets.t("shell.cat.mesa"), "SourceLine"))
	slips_row = HBoxContainer.new()
	slips_row.add_theme_constant_override("separation", 6)
	right.add_child(slips_row)
	desk_list = VBoxContainer.new()
	desk_list.add_theme_constant_override("separation", 6)
	right.add_child(desk_list)
	get_viewport().size_changed.connect(_place)
	set_process(false)

func open(p_seat = null) -> void:
	if p_seat != null:
		seat = int(p_seat)
	_entity = ""
	refresh()
	visible = true
	modulate.a = 0.0
	Widgets.fade(self, 1.0, 0.2)
	_place.call_deferred()
	_remeasure = 2
	set_process(true)

# Las etiquetas con autowrap miden su alto recién con el ancho puesto: se reacomoda dos cuadros después.
func _process(_dt: float) -> void:
	if _remeasure > 0:
		_remeasure -= 1
		if _remeasure == 0:
			_place()
			set_process(false)

func close() -> void:
	if not visible:
		return
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	visible = false
	closed.emit()

func back() -> bool:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
		_confirm = null
		return true
	return false

# Centrada en el alto libre sobre la banda de la escena (si está a la vista), nunca fuera de la pantalla.
func _place() -> void:
	if sheet == null or not is_inside_tree():
		return
	var vs := get_viewport().get_visible_rect().size
	var inset := 0.0
	if shell != null and shell.game_screen != null and shell.game_screen.has_method("_band_inset"):
		inset = float(shell.game_screen._band_inset())
	sheet.size = Vector2.ZERO
	sheet.reset_size()
	var free_h := vs.y - inset
	sheet.position = Vector2((vs.x - sheet.size.x) * 0.5, maxf(16.0, (free_h - sheet.size.y) * 0.5)).floor()

func refresh() -> void:
	var sim = _sim()
	if sim == null:
		return
	head_seat.text = Widgets.t("shell.cat.asiento", {"n": seat}) if seat > 0 else ""
	_fill_index()
	_fill_results()
	_fill_desk()

func _fill_index() -> void:
	var sim = _sim()
	for c in index_list.get_children():
		c.queue_free()
	if sim == null:
		return
	var f := filter_edit.text.strip_edges().to_lower() if filter_edit != null else ""
	for x in sim.q_index():
		if String(x.get("kind", "")) == "act_ref":
			continue
		var lab := String(x.get("label", x.get("id", "")))
		if f != "" and not lab.to_lower().contains(f):
			continue
		var id := String(x.get("id", ""))
		var b := Widgets.button(lab, func(): _search(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.theme_type_variation = "InkButton"
		b.toggle_mode = true
		b.button_pressed = id == _entity
		index_list.add_child(b)

func _search(entity: String) -> void:
	_entity = entity
	_fill_index()
	_fill_results()

func _bm_copy(repo, did: String) -> bool:
	for c in repo.doc(did).get("copies", []):
		if String(c.get("holder", "")) == "BM":
			return true
	return false

func _on_desk(sim) -> Dictionary:
	var out := {}
	for v in sim.q_accessible():
		if String(v.get("holder", "")) == "BM":
			out[String(v.get("doc", ""))] = String(v.get("view", ""))
	return out

func _fill_results() -> void:
	var sim = _sim()
	for c in results.get_children():
		c.queue_free()
	if sim == null:
		return
	if _entity == "":
		results.add_child(_note(Widgets.t("shell.cat.elija")))
		return
	var desk := _on_desk(sim)
	var rs: Array = sim.q_catalog(_entity)
	if rs.is_empty():
		results.add_child(_note(Widgets.t("shell.cat.nada")))
		return
	for r in rs:
		var card := PanelContainer.new()
		Widgets.restyle(card, func(): card.add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 12, "shadow": false})))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		card.add_child(h)
		var l := Widgets.label(String(r.get("label", "")), "")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var did := String(r.get("doc", ""))
		if did != "" and desk.has(did):
			var view := String(desk[did])
			h.add_child(Widgets.ink_button(Widgets.t("shell.cat.leer"), func(): read_requested.emit(view)))
		elif did != "" and _bm_copy(sim.repo, did):
			h.add_child(Widgets.ink_button(Widgets.t("shell.cat.pedir"), func(): _ask_slip(did, String(r.get("label", "")))))
		else:
			var no := Widgets.label(Widgets.t("shell.cat.no_se_presta"), "SmallLabel")
			h.add_child(no)
		results.add_child(card)

func _note(text: String) -> Label:
	var l := Widgets.marginal(text)
	l.custom_minimum_size = Vector2(320, 0)
	return l

func _fill_desk() -> void:
	var sim = _sim()
	for c in slips_row.get_children():
		c.queue_free()
	for c in desk_list.get_children():
		c.queue_free()
	if sim == null:
		return
	var desk := _on_desk(sim)
	for i in maxi(0, SLIPS - desk.size()):
		slips_row.add_child(Slip.new())
	for did in desk:
		var view := String(desk[did])
		var title := String(sim.repo.doc(String(did)).get("title", view))
		var b := Widgets.ink_button(title, func(): read_requested.emit(view))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(220, 0)
		desk_list.add_child(b)

func _ask_slip(did: String, label: String) -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	var body := Widgets.rich("DocBody", Widgets.t("shell.cat.papeleta", {"titulo": label, "n": seat}))
	body.custom_minimum_size = Vector2(440, 0)
	var c := Widgets.confirm(body, Widgets.t("shell.cat.pedir"), Widgets.t("kit.confirm.back"), Widgets.t("shell.cat.papeleta_t"))
	# centrada por un CenterContainer (el alto del texto se conoce con el ancho puesto) sobre un velo
	var wrap := Control.new()
	wrap.name = "Papeleta"
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(Paper.INKS["negra"], 0.3)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(dim)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(cc)
	cc.add_child(c)
	_confirm = wrap
	add_child(wrap)
	c.decided.connect(func(ok):
		wrap.queue_free()
		_confirm = null
		if ok:
			_do_slip(did))

# La confirmación de la papeleta a la vista (tests y drivers): el panel con la señal decided, o null.
func confirm_panel() -> Control:
	if _confirm == null or not is_instance_valid(_confirm):
		return null
	for ch in _confirm.find_children("*", "", true, false):
		if ch.has_signal("decided"):
			return ch
	return null

func _do_slip(did: String) -> void:
	var r: Dictionary = shell.act({"t": "slip", "doc": did}) if shell != null else {}
	if not bool(r.get("ok", false)):
		if shell != null:
			shell.note(shell.err_text(String(r.get("err", ""))))
		refresh()
		return
	if shell != null:
		shell.play("sfx.papel")
	refresh()
	read_requested.emit(String(r.get("view", "")))

# Papeleta en blanco (dibujada).
class Slip extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(30, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2(3, 2), Vector2(24, 40))
		draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.12))
		draw_rect(r, Paper.paper("carta"))
		draw_rect(r, Paper.ink("tenue"), false, 1.0)
		for k in 4:
			draw_line(Vector2(7, 12 + k * 7), Vector2(23, 12 + k * 7), Color(Paper.ink("tenue"), 0.6), 1.0)
