# ui/map/map_screen.gd — el mapa de época con su página de horarios (GDD§5 «Viaje», ARCHITECTURE §6.7). Dueño: W3-SHELL.
# Panel de la capa 50 (Shell.open_panel("map")). Plano dibujado (map_draw.gd) con un marcador por lugar de map.json;
# estado por franja de Game.sim.q_places(): abierto -> clic; cerrado -> persiana baja, SIN clic (T26: ningún clic
# gasta una franja en un lugar cerrado); el motivo se lee al pasar el mouse. Lugares con varias áreas: tarjeta de
# áreas. Viajar: confirmación en dos pasos (lugar, área, franja; en la Sala de Lectura, el asiento) -> Game.act(go)
# (comprometida: se escribe antes de animar) -> trayecto del coche con cascos (≈3 s, clic para saltar) -> visita.
# Página Baedeker pegada a la derecha (schedule.baedeker): clic -> lector. Debajo, «Láminas de lo visto»: las láminas
# archivadas de visitas y escenas (GDD§5: se vuelven a mirar y recortar), más recientes primero; clic -> la lámina en el
# 3D (Shell.open_plate). open() · close() · back() · señal closed.
extends Control

signal closed
signal traveled(place: String, area: String)

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const MapDraw = preload("res://ui/map/map_draw.gd")
const Cond = preload("res://core/util/cond.gd")

const TRAVEL_S := 3.0
const MARK_R := 7.0

var shell = null
var board: Control
var map: Control                # MapDraw
var markers: Control
var baedeker: PanelContainer
var plates_tab: PanelContainer
var header: Label
var status: Label
var close_strip: PanelContainer
var close_btn: Button
var _dim: ColorRect
var _popup: Control = null
var _hover: Label
var _places := []               # q_places() de la última apertura
var _traveling := false
var _skip := false
var seat := 0
var _remeasure := 0

func _init() -> void:
	name = "MapScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _sim():
	var g = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return g.sim if g != null else null

func _repo():
	var s = _sim()
	if s != null:
		return s.repo
	var d = get_tree().root.get_node_or_null("Data") if is_inside_tree() else null
	return d.repo() if d != null else null

func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(Paper.INKS["negra"], 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	board = Control.new()
	board.name = "Board"
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	map = MapDraw.new()
	board.add_child(map)
	markers = Control.new()
	markers.name = "Markers"
	markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.add_child(markers)
	# cuándo y, si hace falta, por qué no se sale: tira de papel con tinta (sobre el velo oscuro la letra clara no se leía)
	var hp := PanelContainer.new()
	hp.name = "Header"
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(hp, func():
		var sb := Paper.style("carta", {"margin": 8, "shadow": true, "shadow_size": 5})
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		hp.add_theme_stylebox_override("panel", sb))
	board.add_child(hp)
	var hb := VBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 0)
	hp.add_child(hb)
	header = Widgets.label("", "Caption")
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(header)
	status = Widgets.marginal("")
	status.autowrap_mode = TextServer.AUTOWRAP_OFF   # una línea: la tira se ajusta a su largo
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(status)
	# salida con el mouse a la vista (como «Volver» del cuaderno o «Cerrar» de la bandeja); clic derecho y Esc también
	close_strip = PanelContainer.new()
	close_strip.name = "Cerrar"
	close_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(close_strip, func():
		var sb := Paper.style("carta", {"margin": 4, "shadow": true, "shadow_size": 5})
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		close_strip.add_theme_stylebox_override("panel", sb))
	close_btn = Widgets.ink_button(Widgets.t("shell.map.volver"), func(): close())
	close_btn.name = "CerrarMapa"
	close_strip.add_child(close_btn)
	board.add_child(close_strip)
	baedeker = _make_baedeker()
	board.add_child(baedeker)
	plates_tab = _make_plates_tab()
	board.add_child(plates_tab)
	_hover = Widgets.label("", "SmallLabel")
	_hover.visible = false
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(_hover, func(): _hover.add_theme_stylebox_override("normal", Paper.style("carta", {"margin": 6, "shadow": false})))
	add_child(_hover)
	get_viewport().size_changed.connect(_layout)
	set_process(false)

func open() -> void:
	var repo = _repo()
	if repo == null:
		return
	map.setup(repo.map())
	_close_popup()
	visible = true
	_refresh()
	_layout()
	_remeasure = 2
	set_process(true)
	modulate.a = 0.0
	Widgets.fade(self, 1.0, 0.22)
	if shell != null:
		shell.play("sfx.papel")

# La página Baedeker (texto con autowrap) mide su alto recién con el ancho puesto: se reacomoda dos cuadros después.
func _process(_dt: float) -> void:
	if _remeasure > 0:
		_remeasure -= 1
		if _remeasure == 0:
			baedeker.size = Vector2.ZERO
			_layout()
			set_process(false)

func close() -> void:
	if _traveling:
		_skip = true
		return
	if not visible:
		return
	_close_popup()
	visible = false
	closed.emit()

func back() -> bool:
	if _traveling:
		_skip = true
		return true
	if _popup != null and is_instance_valid(_popup):
		_close_popup()
		return true
	return false

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if _traveling:
			_skip = true
		elif _popup != null and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_popup()
		accept_event()

# ------------------------------------------------------------------ armado
func _layout() -> void:
	if not visible or map == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var avail := Vector2(vs.x * 0.70, vs.y - 170.0)
	map.fit(avail)
	var bw := minf(330.0, vs.x * 0.22)
	var total := map.size.x + 24.0 + bw
	board.position = Vector2(maxf(16.0, (vs.x - total) * 0.5), maxf(96.0, (vs.y - map.size.y) * 0.5 + 30.0)).floor()
	map.position = Vector2.ZERO
	markers.position = Vector2.ZERO
	markers.size = map.size
	var hb: Control = board.get_node("Header")
	hb.custom_minimum_size = Vector2.ZERO
	hb.size = Vector2.ZERO
	hb.reset_size()
	hb.position = Vector2((map.size.x - hb.size.x) * 0.5, -hb.size.y - 12.0).floor()
	baedeker.custom_minimum_size = Vector2(bw, 0)
	baedeker.reset_size()
	baedeker.position = Vector2(map.size.x + 24.0, 30.0)
	close_strip.reset_size()
	close_strip.position = Vector2(map.size.x + 24.0 + bw - close_strip.size.x, -close_strip.size.y - 12.0).floor()
	plates_tab.custom_minimum_size = Vector2(bw * 0.8, 0)
	plates_tab.reset_size()
	plates_tab.position = Vector2(map.size.x + 24.0 + bw * 0.12, minf(baedeker.position.y + baedeker.size.y + 22.0, map.size.y - plates_tab.size.y))
	_place_markers()

func _refresh() -> void:
	var sim = _sim()
	var repo = _repo()
	if sim == null or repo == null:
		_places = []
	else:
		_places = sim.q_places()
		var c: Dictionary = sim.q_clock()
		var info := _day_info(repo, int(c.day))
		var ht := Widgets.t("shell.map.cuando", {"dia": String(c.get("date_label", "")), "franja": Widgets.t("core.slot." + String(c.slot)), "horas": Widgets.t("core.slot_horas." + String(c.slot))}) if String(c.phase) == "desk" else String(info.get("label", c.get("date_label", "")))
		header.text = ht.substr(0, 1).to_upper() + ht.substr(1)
		status.text = _status_text(c)
		status.visible = status.text != ""
		if is_inside_tree():
			_layout.call_deferred()
	_build_markers()

func _status_text(c: Dictionary) -> String:
	match String(c.get("phase", "")):
		"desk":
			return Widgets.t("shell.map.ya_salio") if bool(c.get("outing_done", false)) else ""
		"visit":
			return Widgets.t("shell.map.fuera")
		"night", "prologue":
			return Widgets.t("shell.map.noche")
	return Widgets.t("shell.map.no_ahora")

static func _day_info(repo, d: int) -> Dictionary:
	for x in repo.schedule().get("days", []):
		if int(x.get("day", -1)) == d:
			return x
	return {}

func by_place() -> Dictionary:
	var out := {}
	for p in _places:
		var id := String(p.get("id", ""))
		if not out.has(id):
			out[id] = []
		out[id].append(p)
	return out

# Estado de un lugar del mapa: {open: algún área elegible, areas:[…], reason: motivo del primero cerrado, home}.
func place_state(id: String) -> Dictionary:
	var bp := by_place()
	var areas: Array = []
	for p in bp.get(id, []):
		if bool(p.get("free", false)):
			continue
		areas.append(p)
	var any := false
	var reason := ""
	for p in areas:
		if bool(p.get("can_go", false)):
			any = true
		elif reason == "" and not bool(p.get("open", false)):
			reason = String(p.get("reason", ""))
	return {"open": any, "areas": areas, "reason": reason, "home": areas.is_empty()}

func _build_markers() -> void:
	for c in markers.get_children():
		c.queue_free()
	var repo = _repo()
	if repo == null:
		return
	var mp: Dictionary = repo.map().get("places", {})
	var ids: Array = mp.keys()
	ids.sort()
	for id in ids:
		if not shown(String(id)):
			continue
		var m := Marker.new()
		m.place_id = String(id)
		m.data = mp[id]
		m.state = place_state(String(id))
		m.home = bool(mp[id].get("home", false))
		m.label_text = String(mp[id].get("label", id))
		m.pressed_cb = _on_marker
		m.hover_cb = _on_hover
		markers.add_child(m)
	_place_markers()

# map.json places.<L>.show (DSL §4.18) decide si el marcador existe ya para Lisle; sin show, siempre.
func shown(id: String) -> bool:
	var repo = _repo()
	if repo == null:
		return false
	var spec = repo.map().get("places", {}).get(id, {})
	if typeof(spec) != TYPE_DICTIONARY or not spec.has("show"):
		return true
	var sim = _sim()
	if sim == null:
		return false
	return Cond.eval(spec.show, {"st": sim.st, "repo": sim.repo})

func _place_markers() -> void:
	for m in markers.get_children():
		if m is Marker:
			m.place_at(map.mm_to_px((m as Marker).data.get("xy", [0, 0])), map.px_per_mm)

func marker(id: String) -> Control:
	for m in markers.get_children():
		if m is Marker and (m as Marker).place_id == id:
			return m
	return null

func _make_baedeker() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Baedeker"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.rotation_degrees = -1.5
	Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("strand", {"margin": 16, "shadow": true, "shadow_size": 8})))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var t := Widgets.label(Widgets.t("shell.map.baedeker"), "SourceLine")
	t.uppercase = true
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var body := Widgets.rich("DocBody")
	body.name = "Text"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_size_override("normal_font_size", 14)
	v.add_child(body)
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			p.accept_event()
			open_baedeker())
	p.ready.connect(func():
		var repo = _repo()
		if repo != null:
			body.clear()
			body.add_text(String(repo.parse_text(String(repo.schedule().get("baedeker", ""))).get("plain", ""))))
	return p

# Una tira de papel con «Láminas de lo visto» (sin número: nada de contadores).
func _make_plates_tab() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Laminas"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.rotation_degrees = 1.2
	Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("registro", {"margin": 12, "shadow": true, "shadow_size": 6})))
	var t := Widgets.label(Widgets.t("shell.map.laminas"), "SourceLine")
	t.uppercase = true
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(t)
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			p.accept_event()
			open_plates())
	return p

# Lista de láminas archivadas sobre el mapa; elegir una cierra el mapa y la muestra en el 3D.
func open_plates() -> void:
	if _traveling or shell == null:
		return
	_close_popup()
	var p := PanelContainer.new()
	p.name = "ListaLaminas"
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 18, "shadow": true, "shadow_size": 10})))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(Widgets.label(Widgets.t("shell.map.laminas_t"), "DocTitle"))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var plates: Array = shell.archived_plates()
	if plates.is_empty():
		list.add_child(Widgets.marginal(Widgets.t("shell.map.laminas_nada")))
	for pl in plates:
		var pid := String(pl.id)
		var b := Widgets.ink_button(plate_label(pl), func():
			_close_popup()
			close()
			shell.open_plate(pid))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Lamina_" + pid.validate_node_name()
		b.set_meta("plate", pid)
		list.add_child(b)
	add_child(p)
	_popup = p
	var vs := get_viewport().get_visible_rect().size
	sc.custom_minimum_size = Vector2(360, minf(list.get_combined_minimum_size().y, vs.y * 0.55))
	p.reset_size()
	p.position = Vector2(clampf(plates_tab.get_global_rect().position.x - global_position.x - p.size.x + plates_tab.size.x, 10, vs.x - p.size.x - 10),
		clampf(plates_tab.get_global_rect().position.y - global_position.y - p.size.y - 10.0, 10, vs.y - p.size.y - 10)).floor()

# «Kensington — martes 27 de marzo, mañana».
func plate_label(pl: Dictionary) -> String:
	var repo = _repo()
	var name_s := String(repo.map().get("places", {}).get(String(pl.place), {}).get("label", pl.place)) if repo != null else String(pl.place)
	var info := _day_info(repo, int(pl.day)) if repo != null else {}
	var when := String(info.get("label", ""))
	if when != "" and String(pl.slot) != "":
		when += ", " + Widgets.t("core.slot." + String(pl.slot))
	return name_s if when == "" else "%s — %s" % [name_s, when]

func baedeker_view() -> Dictionary:
	var repo = _repo()
	if repo == null:
		return {}
	var parsed: Dictionary = repo.parse_text(String(repo.schedule().get("baedeker", "")))
	return {"view": "baedeker", "doc": "baedeker", "title": Widgets.t("shell.map.baedeker_t"), "src_line": Widgets.t("shell.map.baedeker_src"),
		"paper": "strand", "paper_mm": [120, 190], "font": "imprenta", "machine": null,
		"pages": [[{"doc": "baedeker", "origin": "", "copy": "baedeker", "part": "p1", "parsed": parsed}]]}

func open_baedeker() -> void:
	if shell != null:
		shell.open_view(baedeker_view())

# ------------------------------------------------------------------ elegir y viajar
func _on_hover(m, on: bool) -> void:
	if not on or m == null:
		_hover.visible = false
		return
	var st: Dictionary = m.state
	var txt := ""
	if bool(m.home):
		txt = Widgets.t("shell.map.casa")
	elif not bool(st.open):
		txt = _closed_text(st)
	if txt == "":
		_hover.visible = false
		return
	_hover.text = txt
	_hover.reset_size()
	_hover.visible = true
	_hover.position = (m as Control).get_global_rect().position - global_position + Vector2(0, 26)

func _closed_text(st: Dictionary) -> String:
	var sim = _sim()
	if sim != null:
		var c: Dictionary = sim.q_clock()
		if String(c.phase) != "desk":
			return _status_text(c)
		if bool(c.get("outing_done", false)):
			return Widgets.t("shell.map.ya_salio")
	var r := String(st.get("reason", ""))
	var k := "sim.cerrado." + r
	var s := Widgets.t(k)
	return s if s != k else Widgets.t("shell.map.cerrado")

func _on_marker(m) -> void:
	if _traveling or m == null or bool(m.home):
		return
	var st: Dictionary = m.state
	if not bool(st.open):
		return   # persiana: sin clic
	var open_areas: Array = st.areas.filter(func(p): return bool(p.get("can_go", false)))
	if open_areas.size() == 1 and st.areas.size() == 1:
		_confirm_go(open_areas[0])
	else:
		_area_popup(m, st.areas)

func _close_popup() -> void:
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null

func _area_popup(m, areas: Array) -> void:
	_close_popup()
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 16, "shadow": true, "shadow_size": 10})))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := Widgets.label(String(m.label_text), "DocTitle")
	v.add_child(t)
	for a in areas:
		var name_txt := _area_name(a)
		if bool(a.get("can_go", false)):
			var b := Widgets.ink_button(name_txt, func():
				_close_popup()
				_confirm_go(a))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			v.add_child(b)
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var sh := Shutter.new()
			sh.custom_minimum_size = Vector2(22, 16)
			row.add_child(sh)
			var l := Widgets.label(name_txt, "SmallLabel")
			row.add_child(l)
			var why := Widgets.label("— " + _closed_text({"reason": String(a.get("reason", ""))}), "SmallLabel")
			row.add_child(why)
			v.add_child(row)
	add_child(p)
	_popup = p
	p.reset_size()
	var at := (m as Control).get_global_rect().position - global_position + Vector2(18, 18)
	var vs := get_viewport().get_visible_rect().size
	p.position = Vector2(clampf(at.x, 10, vs.x - p.size.x - 10), clampf(at.y, 10, vs.y - p.size.y - 10))

func _area_name(a: Dictionary) -> String:
	var an := String(a.get("area_name", a.get("area", "")))
	return an.substr(0, 1).to_upper() + an.substr(1)

func _confirm_go(p: Dictionary) -> void:
	_close_popup()
	var sim = _sim()
	if sim == null:
		return
	var c: Dictionary = sim.q_clock()
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	var nm := Widgets.label(String(p.get("name", "")), "DocTitle")
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(440, 0)
	body.add_child(nm)
	var an := Widgets.label(_area_name(p), "Caption")
	an.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	an.custom_minimum_size = Vector2(440, 0)
	body.add_child(an)
	var txt := Widgets.rich("DocBody", Widgets.t("shell.map.ir_cuerpo", {"franja": Widgets.t("core.slot." + String(c.slot)),
		"dia": String(c.get("date_label", ""))}))
	txt.custom_minimum_size = Vector2(440, 0)
	body.add_child(txt)
	var seat_box: HBoxContainer = null
	var seat_edit: SpinBox = null
	if bool(p.get("needs_seat", false)):
		seat_box = HBoxContainer.new()
		seat_box.add_theme_constant_override("separation", 10)
		seat_box.add_child(Widgets.label(Widgets.t("shell.map.asiento"), "SourceLine"))
		seat_edit = SpinBox.new()
		seat_edit.min_value = 1
		seat_edit.max_value = 999
		seat_edit.step = 1
		seat_edit.rounded = true
		seat_edit.value = seat if seat > 0 else default_seat(sim)
		seat_edit.custom_minimum_size = Vector2(110, 0)
		seat_box.add_child(seat_edit)
		body.add_child(seat_box)
	var cf := Widgets.confirm(body, Widgets.t("shell.map.ir"), Widgets.t("kit.confirm.back"), Widgets.t("shell.map.ir_t"))
	add_child(cf)
	_popup = cf
	cf.reset_size()
	var vs := get_viewport().get_visible_rect().size
	cf.position = ((vs - cf.size) * 0.5).floor()
	cf.decided.connect(func(ok):
		cf.queue_free()
		_popup = null
		if ok:
			var s := int(seat_edit.value) if seat_edit != null else 0
			travel(String(p.get("id", "")), String(p.get("area", "")), s))

# Asiento por defecto: el último que eligió; si no, uno sembrado por la partida (sin azar global).
static func default_seat(sim) -> int:
	var s := int(sim.st.world.get("seat", 0)) if sim != null and sim.get("st") != null else 0
	if s > 0:
		return s
	var seed_v: int = int(sim.st.seed) if sim != null and sim.get("st") != null else 1894
	return 101 + absi(seed_v) % 380

# go (comprometida) y trayecto del coche. Devuelve el resultado de Game.act.
func travel(place: String, area: String, p_seat := 0) -> Dictionary:
	if _traveling or shell == null:
		return {"ok": false, "err": "ocupado"}
	var a := {"t": "go", "place": place, "area": area}
	if p_seat > 0:
		a["seat"] = p_seat
		seat = p_seat
	shell.busy(true)
	var r: Dictionary = shell.act(a)
	if not bool(r.get("ok", false)):
		shell.busy(false)
		shell.note(shell.err_text(String(r.get("err", ""))))
		_refresh()
		return r
	traveled.emit(place, area)
	await _ride(place)
	shell.busy(false)
	visible = false
	closed.emit()
	if shell.game_screen != null and shell.game_screen.has_method("request_sync"):
		shell.game_screen.request_sync()
	return r

func _ride(place: String) -> void:
	var repo = _repo()
	var mp: Dictionary = repo.map().get("places", {}) if repo != null else {}
	var home := Vector2.ZERO
	for id in mp:
		if bool(mp[id].get("home", false)):
			home = Vector2(float(mp[id].xy[0]), float(mp[id].xy[1]))
	var to_v = mp.get(place, {}).get("xy", [home.x, home.y])
	var to := Vector2(float(to_v[0]), float(to_v[1]))
	_traveling = true
	_skip = false
	for m in markers.get_children():
		if m is Marker:
			(m as Marker).enabled = false
	status.text = Widgets.t("shell.map.en_coche")
	status.visible = true
	_layout()
	var dur := TRAVEL_S
	if shell.fast:
		dur = 0.0
	else:
		shell.play_event("viaje")
	var t := 0.0
	while t < dur and not _skip and is_inside_tree():
		map.route = {"from": home, "to": to, "t": t / dur}
		map.queue_redraw()
		await get_tree().process_frame
		t += get_process_delta_time()
	map.route = {"from": home, "to": to, "t": 1.0}
	map.queue_redraw()
	if is_inside_tree():
		await get_tree().process_frame
	map.route = {}
	_traveling = false

func traveling() -> bool:
	return _traveling

# ------------------------------------------------------------------ marcador y persiana
class Marker extends Control:
	var place_id := ""
	var data := {}
	var state := {}
	var home := false
	var label_text := ""
	var enabled := true
	var pressed_cb: Callable
	var hover_cb: Callable
	var _hot := false
	var _scale := 1.0
	var _label_rect := Rect2()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func is_open() -> bool:
		return bool(state.get("open", false)) and not home and enabled

	func place_at(p: Vector2, px_per_mm: float) -> void:
		_scale = px_per_mm
		var f := _font()
		var fs := _fs()
		var tw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var off_v = data.get("label_off", [9, -6])
		var off := Vector2(float(off_v[0]), float(off_v[1])) * px_per_mm
		var right := String(data.get("align", "left")) == "right"
		var lp := off + (Vector2(-tw, 0) if right else Vector2.ZERO)
		_label_rect = Rect2(lp + Vector2(-4, -fs), Vector2(tw + 8, fs + 8))
		var bb := Rect2(Vector2(-12, -12), Vector2(24, 24)).merge(_label_rect)
		position = p + bb.position
		size = bb.size
		set_meta("origin", -bb.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_open() else Control.CURSOR_ARROW
		queue_redraw()

	func _font() -> Font:
		var ti = Widgets.ti()
		return ti.font("imprenta", true) if ti != null else ThemeDB.fallback_font

	func _fs() -> int:
		var ti = Widgets.ti()
		var k: float = 1.0 if ti == null else float(ti.text_scale)
		return int(round(clampf(6.2 * _scale, 13.0, 26.0) * k))

	func _own_point(p: Vector2) -> bool:
		var o: Vector2 = get_meta("origin", Vector2.ZERO)
		return Rect2(o + Vector2(-12, -12), Vector2(24, 24)).has_point(p) or _label_rect.has_point(p - o)

	func _has_point(p: Vector2) -> bool:
		if not _own_point(p):
			return false
		# si dos marcadores se pisan, el abierto gana el clic y el aviso (W4: la persiana de Camden House tapaba Baker
		# Street y el jugador leía «Cerrado a esta hora.» sobre el lugar abierto)
		if not is_open() and get_parent() != null:
			for s in get_parent().get_children():
				if s != self and s is Marker and (s as Marker).is_open() and (s as Marker)._own_point(position + p - (s as Marker).position):
					return false
		return true

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			accept_event()
			if is_open() and pressed_cb.is_valid():
				pressed_cb.call(self)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			_hot = true
			queue_redraw()
			if hover_cb.is_valid():
				hover_cb.call(self, true)
		elif what == NOTIFICATION_MOUSE_EXIT:
			_hot = false
			queue_redraw()
			if hover_cb.is_valid():
				hover_cb.call(self, false)

	func _draw() -> void:
		var o: Vector2 = get_meta("origin", Vector2.ZERO)
		var ink := Paper.ink("negra")
		var red := Paper.ink("roja")
		var open := is_open()
		var col := ink if (open or home) else Paper.ink("tenue")
		var r := MARK_R * clampf(_scale, 0.9, 1.8)
		if home:
			# casa: un cuadrado con techo (Holywell Street)
			var b := Rect2(o + Vector2(-r * 0.7, -r * 0.3), Vector2(r * 1.4, r))
			draw_rect(b, Color(red, 0.85))
			draw_colored_polygon(PackedVector2Array([o + Vector2(-r, -r * 0.3), o + Vector2(r, -r * 0.3), o + Vector2(0, -r * 1.2)]), Color(red, 0.85))
		else:
			draw_circle(o, r, Color(Paper.paper("carta"), 0.95))
			draw_arc(o, r, 0, TAU, 24, col, 1.6, true)
			draw_circle(o, r * 0.38, col)
			if _hot and open:
				draw_arc(o, r + 3.0, 0, TAU, 24, Color(col, 0.6), 1.0, true)
		var f := _font()
		var fs := _fs()
		var lp := _label_rect.position + o + Vector2(4, fs)
		var lr := Rect2(_label_rect.position + o, _label_rect.size)
		if not open and not home:
			# persiana baja sobre el marcador; el rótulo se sigue leyendo, en tinta tenue, entre las tablillas
			Shutter.draw_shutter(self, Rect2(o - Vector2(r + 2, r + 2), Vector2(r + 2, r + 2) * 2.0), 0.95)
			Shutter.draw_shutter(self, Rect2(lr.position + Vector2(-2, -2), lr.size + Vector2(4, 4)), 0.55)
			draw_string(f, lp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Paper.ink("tenue").darkened(0.25))
			return
		if not home:
			draw_rect(lr, Color(Paper.paper("carta"), 0.72))
		draw_string(f, lp, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col if not home else red)
		if _hot and open:
			draw_line(lp + Vector2(0, 3), lp + Vector2(_label_rect.size.x - 8, 3), Color(col, 0.7), 1.0)

class Shutter extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_shutter(self, Rect2(Vector2.ZERO, size), 0.9)
	# Persiana baja: tablillas horizontales de lata (tinta tenue sobre papel), con su barra de abajo.
	static func draw_shutter(ci: CanvasItem, r: Rect2, alpha: float) -> void:
		var ink := Paper.ink("negra")
		ci.draw_rect(r, Color(Paper.paper("registro").darkened(0.12), alpha))
		var y := r.position.y + 2.0
		while y < r.end.y - 2.0:
			ci.draw_line(Vector2(r.position.x + 1, y), Vector2(r.end.x - 1, y), Color(ink, 0.35 * alpha), 1.0)
			y += 4.0
		ci.draw_line(Vector2(r.position.x, r.end.y - 1), Vector2(r.end.x, r.end.y - 1), Color(ink, 0.7 * alpha), 2.0)
		ci.draw_rect(r, Color(ink, 0.5 * alpha), false, 1.0)
