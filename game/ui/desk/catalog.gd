# ui/desk/catalog.gd — Sala de Lectura: catálogo general y papeletas (GDD§5 L2, §7.5). Dueño: W3-SHELL. Panel (capa escena).
# Se busca por cualquier entidad del índice del jugador (q_index); el catálogo devuelve hasta 5 asientos mezclados con
# obras de época sin relación (q_catalog). Pedir = papeleta (acción comprometida «slip»: confirmación en dos pasos con
# el asiento a la vista). Tres papeletas por visita: se ven como tres tiras de papel en la mesa (sin número). Lo pedido
# queda «sobre su mesa» y se lee en el lector. open() · close() · señales closed, read_requested(view).
# GDD_v2 §C.3 (revelado progresivo): al principio, el buscador y «Recientes» (≤8 entradas del índice, lo último que entró);
#   la lista entera del índice ya no se despliega como menú (escribir en el buscador la recorre). Las fichas aparecen al
#   elegir una entrada; «Sobre mi mesa» después del primer pedido (bandera cat.mesa). En el encabezado, «Asiento 214 ·
#   cambiar»: el asiento lo sigue llevando el `go` (no cambia el sim); cambiarlo vale para la próxima visita
#   (Catalog.seat_pref, que el mapa usa como asiento por defecto; sin elección, el último usado o 214).
# Dueño desde v2: DESPEJE-UI.
extends Control

signal closed
signal read_requested(view: String)

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const SLIPS := 3
const RES_MIN_H := 140.0
const RECENT_N := 8
const UiFlags = preload("res://ui/kit/ui_flags.gd")
var _remeasure := 0
static var seat_pref := 0       # asiento elegido con «cambiar» para la próxima visita (sesión; 0 = sin elección)

# Asiento por defecto para el próximo `go` a la Sala de Lectura: la elección de «cambiar», o el último usado, o 214.
static func next_seat(sim) -> int:
	if seat_pref > 0:
		return seat_pref
	if sim != null and sim.has_method("q_seat"):
		return int(sim.q_seat())
	return 214

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
var _res_scroll: ScrollContainer
var _mid: VBoxContainer
var _right: VBoxContainer
var _recent_label: Label
var _help: Label
var _seat_btn: Button

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
	slips_row = HBoxContainer.new()
	slips_row.add_theme_constant_override("separation", 6)
	top.add_child(slips_row)
	head_seat = Widgets.label("", "SourceLine")
	head_seat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(head_seat)
	_seat_btn = Widgets.ink_button(Widgets.t("v2d.cat.cambiar"), _ask_seat)
	_seat_btn.name = "CambiarAsiento"
	Widgets.restyle(_seat_btn, func():
		var tin := Widgets.ti()
		_seat_btn.add_theme_font_size_override("font_size", 15 if tin == null else tin.px("small")))
	top.add_child(_seat_btn)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	top.add_child(gap)
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
	filter_edit = LineEdit.new()
	filter_edit.name = "Buscar"
	filter_edit.placeholder_text = Widgets.t("shell.cat.filtro")
	filter_edit.clear_button_enabled = true
	filter_edit.text_changed.connect(func(_t): _fill_index())
	left.add_child(filter_edit)
	_help = Widgets.marginal(Widgets.t("v2d.cat.ayuda"))
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size = Vector2(250, 0)
	left.add_child(_help)
	_recent_label = Widgets.label(Widgets.t("v2d.cat.recientes"), "SourceLine")
	left.add_child(_recent_label)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(250, 300)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	index_list = VBoxContainer.new()
	index_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(index_list)
	# resultados
	var mid := VBoxContainer.new()
	_mid = mid
	mid.custom_minimum_size = Vector2(340, 0)
	mid.add_theme_constant_override("separation", 8)
	cols.add_child(mid)
	mid.add_child(Widgets.label(Widgets.t("shell.cat.asientos"), "SourceLine"))
	# las fichas se desplazan dentro de la hoja: nunca bajan hasta debajo de la banda de la escena (W4: la quinta ficha
	# quedaba tapada, con su «Pedir» sin clic)
	_res_scroll = ScrollContainer.new()
	_res_scroll.name = "Fichas"
	_res_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(_res_scroll)
	results = VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 8)
	_res_scroll.add_child(results)
	# mesa: papeletas y lo pedido
	var right := VBoxContainer.new()
	_right = right
	right.custom_minimum_size = Vector2(230, 0)
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	right.add_child(Widgets.label(Widgets.t("shell.cat.mesa"), "SourceLine"))
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
	var free_h := vs.y - inset
	# las fichas toman su alto natural; si la hoja no cabe sobre la banda, se acortan y se desplazan con la rueda
	var need := results.get_combined_minimum_size().y
	_res_scroll.custom_minimum_size = Vector2(0, need)
	sheet.size = Vector2.ZERO
	sheet.reset_size()
	var room := free_h - 32.0
	if sheet.size.y > room:
		_res_scroll.custom_minimum_size.y = maxf(RES_MIN_H, need - (sheet.size.y - room))
		sheet.size = Vector2.ZERO
		sheet.reset_size()
	sheet.position = Vector2((vs.x - sheet.size.x) * 0.5, maxf(16.0, (free_h - sheet.size.y) * 0.5)).floor()

func refresh() -> void:
	var sim = _sim()
	if sim == null:
		return
	head_seat.text = Widgets.t("shell.cat.asiento", {"n": seat}) if seat > 0 else ""
	if seat_pref > 0 and seat_pref != seat:
		head_seat.text += " · " + Widgets.t("v2d.cat.proxima", {"n": seat_pref})
	if seat > 0:
		head_seat.text += " ·"
	_seat_btn.visible = seat > 0
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
	_recent_label.visible = f == ""
	_help.visible = _entity == ""
	for x in (sim.q_index() if f != "" else recent_rows(sim)):
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
	# buscar algo que no está en el índice: decirlo (playtest v2: la lista quedaba vacía sin explicación)
	if f != "" and index_list.get_child_count() == 0:
		var nl := Widgets.marginal(Widgets.t("v2d.cat.sin_indice", {"que": filter_edit.text.strip_edges()}))
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size = Vector2(220, 0)
		index_list.add_child(nl)

# «Recientes»: las entradas del índice que entraron último (las entidades de los recortes, del más nuevo al más viejo);
# si no alcanzan, las demás en el orden del índice. Hasta RECENT_N.
static func recent_rows(sim) -> Array:
	var rows := {}
	var order: Array = []
	for x in sim.q_index():
		if String(x.get("kind", "")) == "act_ref":
			continue
		rows[String(x.get("id", ""))] = x
		order.append(String(x.get("id", "")))
	var out: Array = []
	var seen := {}
	var cl: Array = sim.q_clips()
	for k in range(cl.size() - 1, -1, -1):
		for e in cl[k].get("ents", []):
			var id := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
			if rows.has(id) and not seen.has(id):
				seen[id] = true
				out.append(rows[id])
				if out.size() >= RECENT_N:
					return out
	for id in order:
		if not seen.has(id):
			seen[id] = true
			out.append(rows[id])
			if out.size() >= RECENT_N:
				break
	return out

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
		results.remove_child(c)
		c.queue_free()
	_res_scroll.scroll_vertical = 0
	# la hoja se reacomoda con cada búsqueda (antes sólo al abrir), cuando el autowrap ya midió las fichas
	if visible and is_inside_tree():
		_place.call_deferred()
		_remeasure = 2
		set_process(true)
	_mid.visible = _entity != ""
	if sim == null:
		return
	if _entity == "":
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
		else:
			# toda ficha se pide igual (W4: «Pedir» sólo en las que son documentos del caso delataba cuáles importan; el
			# catálogo mezcla ruido y hay que saber qué pedir). Lo que no se sirve se sabe después de la papeleta.
			var req := did if did != "" and _bm_copy(sim.repo, did) else ""
			var b := Widgets.ink_button(Widgets.t("shell.cat.pedir"), func(): _ask_slip(req, String(r.get("label", ""))))
			b.name = "Pedir"
			h.add_child(b)
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
	_right.visible = UiFlags.on(UiFlags.of(sim), "cat.mesa") or not desk.is_empty()
	var used: int = int(sim.q_slips_used()) if sim.has_method("q_slips_used") else desk.size()
	var left := maxi(0, SLIPS - used)
	for i in left:
		var sl := Slip.new()
		# qué son: los pedidos que quedan en esta visita (playtest v2: las tres fichas no se explicaban)
		sl.tooltip_text = Widgets.t("v2d.cat.pedidos")
		sl.mouse_filter = Control.MOUSE_FILTER_PASS
		slips_row.add_child(sl)
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
	# una ficha que ya trae comillas («El problema final», The Strand…) no se vuelve a entrecomillar
	var key := "shell.cat.papeleta_sin" if label.strip_edges().begins_with("«") else "shell.cat.papeleta"
	var body := Widgets.rich("DocBody", Widgets.t(key, {"titulo": label, "n": seat}))
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
			_do_slip(did, label))

# La confirmación de la papeleta a la vista (tests y drivers): el panel con la señal decided, o null.
func confirm_panel() -> Control:
	if _confirm == null or not is_instance_valid(_confirm):
		return null
	for ch in _confirm.find_children("*", "", true, false):
		if ch.has_signal("decided"):
			return ch
	return null

# Una papeleta se gasta siempre (W4): con documento del caso servido hoy, el ejemplar llega a la mesa; si no (obra de
# época que la Sala no sirve, o fuera de su ventana), el ujier vuelve con las manos vacías y la papeleta queda gastada.
func _do_slip(did: String, label := "") -> void:
	var a := {"t": "slip", "doc": did} if did != "" else {"t": "slip", "doc": "", "noise": label}
	var r: Dictionary = shell.act(a) if shell != null else {}
	if not bool(r.get("ok", false)):
		if shell != null:
			shell.note(shell.err_text(String(r.get("err", ""))))
		refresh()
		return
	if shell != null:
		shell.play("sfx.papel")
	refresh()
	var view := String(r.get("view", ""))
	if view == "":
		if shell != null:
			shell.note(Widgets.t("shell.cat.no_esta"))
		return
	read_requested.emit(view)

# «cambiar»: el asiento para la próxima visita (el de hoy ya lo llevó el `go`). Dos pasos, como todo lo que cuenta.
func _ask_seat() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.queue_free()
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(Widgets.label(Widgets.t("v2d.cat.asiento_q"), ""))
	var sp := SpinBox.new()
	sp.name = "Asiento"
	sp.min_value = 1
	sp.max_value = 999
	sp.step = 1
	sp.rounded = true
	sp.value = seat_pref if seat_pref > 0 else (seat if seat > 0 else 214)
	sp.custom_minimum_size = Vector2(110, 0)
	box.add_child(sp)
	var c := Widgets.confirm(box, Widgets.t("kit.confirm.ok"), Widgets.t("kit.confirm.back"), Widgets.t("v2d.cat.cambiar_t"))
	var wrap := Control.new()
	wrap.name = "CambioAsiento"
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
			seat_pref = int(sp.value)
			refresh())

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
