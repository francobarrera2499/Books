# ui/desk/game_screen.gd — la pantalla de juego: el escritorio de 1894 como centro (ARCHITECTURE §2.3, §6.3, §6.7).
# Dueño: W3-SHELL. La crea la Shell. Decide el modo leyendo Game.sim.q_clock().phase en cada sim_changed (agrupados
# por cuadro) y arma el 3D (WorldRoot), el HUD (calendario y monedas), el epígrafe, la tarjeta de examen, la nota del
# instructor (prólogo), las líneas dichas y la tijera sobre el diorama. Transiciones con fundido (≤0,4 s); al cambiar de
# día, el ritual del amanecer (dawn.gd) y después la bandeja.
#   prologue  lámina del prólogo (PL.prologo) + instructor (Pell/Harris)       desk/night  hub L1 (escritorio·ventana·pared)
#   visit     diorama del lugar (órbita) + panel de escena al tocar a alguien  scene       lámina fija (M6/M7) + líneas
#   confront  tienda de Crane + vista de confrontación (W3-SCENEUI)            final_report hub + informe final
#   parklane  lámina PARK + líneas                                            night_choice hub + elegir dónde pasar la noche
#   epilogue  pantalla de epílogo (W4-EPILOGUE; respaldo propio)
# Objetos del 3D: ui/desk/objects.gd (data/map.json "objects"). Todo con el mouse; atajos vía input_router.
# API para la Shell y el router: start(instant) · back() -> bool · toggle_scissors() -> bool · shortcut_panel(kind) ->
#   bool · request_sync() · debug_place(L) · show_doc_plate(plate) · on_clipped(result). Extras para drivers/tests:
#   on_node(id) · on_char(id) · calendar() · frames() · go_frame(id) · state() -> Dictionary.
extends Node

const Layers = preload("res://ui/layers.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const DeskHud = preload("res://ui/desk/desk_hud.gd")
const Tray = preload("res://ui/desk/tray.gd")
const Dawn = preload("res://ui/desk/dawn.gd")
const ExamineCard = preload("res://ui/desk/examine_card.gd")
const Scissors3D = preload("res://ui/desk/scissors3d.gd")
const Speech = preload("res://ui/desk/speech.gd")
const Catalog = preload("res://ui/desk/catalog.gd")
const Objects = preload("res://ui/desk/objects.gd")
const Chips = preload("res://ui/drag/chips.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

const HUB := "L1"
const HUB_FRAME := "escritorio"
const PARK_PLATE := "PARK"
const BAND_PANELS := ["scene"]
const CAPTION_S := 4.5
const SCENE_PANEL := "res://ui/scene/scene_panel.gd"

var shell = null
var hud: Control
var nav: Control
var exam: PanelContainer
var speech: PanelContainer
var tutor: PanelContainer
var scissors: Control
var tray: Control
var catalog: Control
var caption: PanelContainer      # epígrafe al pie, al estilo de las láminas de Paget: tira de papel
var _cap_v: VBoxContainer
var mode := ""                  # hub | plate
var cur_place := ""             # id de data/places o data/plates del 3D actual
var cur_plate := ""             # id de lámina para recortar (PL.L4.1.M, PL.prologo, hub)
var frame := HUB_FRAME
var scissors_on := false
var last_seat := 0
var _last := {}
var _seen_lines := {}
var _sync_q := false
var _pending := false
var _syncing := false
var _started := false
var _doc_plate := false
var _modal: Control = null
var _caption_tw: Tween = null
var _chev_l: Button
var _chev_r: Button
var _leave_btn: Button
var _catalog_after_read := false

func _init() -> void:
	name = "GameScreen"

func _sim():
	return shell.sim() if shell != null else null

func _repo():
	var s = _sim()
	return s.repo if s != null else null

# ------------------------------------------------------------------ arranque
func start(instant := false) -> void:
	_build_ui()
	var g = shell.game()
	if g != null and not g.sim_changed.is_connected(_on_changed):
		g.sim_changed.connect(_on_changed)
	var w = shell.world
	if not w.node_clicked.is_connected(on_node):
		w.node_clicked.connect(on_node)
		w.character_clicked.connect(on_char)
		w.empty_clicked.connect(_on_empty)
	shell.drop_catcher.present_requested.connect(_on_present)
	shell.panel_opened.connect(func(_k): _sync_overlays())
	shell.panel_closed.connect(func(_k): _sync_overlays())
	shell.panel_closed.connect(_on_panel_closed_kind)
	var sim = _sim()
	if sim != null and not sim.actions_log().is_empty():
		for ln in sim.q_scene().get("lines", []):
			_seen_lines[String(ln.uid)] = true
	await _sync(true, instant)
	_started = true

func leave_screen() -> void:
	var g = shell.game() if shell != null else null
	if g != null and g.sim_changed.is_connected(_on_changed):
		g.sim_changed.disconnect(_on_changed)
	var w = shell.world if shell != null else null
	if w != null and w.node_clicked.is_connected(on_node):
		w.node_clicked.disconnect(on_node)
		w.character_clicked.disconnect(on_char)
		w.empty_clicked.disconnect(_on_empty)
	if shell != null and shell.drop_catcher.present_requested.is_connected(_on_present):
		shell.drop_catcher.present_requested.disconnect(_on_present)
	set_scissors(false)
	for n in [hud, nav, exam, speech, tutor, scissors, tray, catalog, caption]:
		if n != null and is_instance_valid(n):
			n.queue_free()

func _build_ui() -> void:
	var hr := Layers.root_of(shell.layers.hud)
	scissors = Scissors3D.new()
	scissors.rect_done.connect(_on_rect)
	hr.add_child(scissors)
	hud = DeskHud.new()
	hud.calendar_pressed.connect(calendar)
	hud.book_pressed.connect(func(k): shortcut_panel(k))
	hud.folio_dropped.connect(drop_on_ledger)
	hr.add_child(hud)
	nav = Control.new()
	nav.name = "Nav"
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hr.add_child(nav)
	_chev_l = _chevron("‹", -1)
	_chev_r = _chevron("›", 1)
	_leave_btn = Widgets.ink_button("", _on_leave_btn)
	_leave_btn.name = "Leave"
	_leave_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_leave_btn.offset_left = 22
	_leave_btn.offset_bottom = -22
	_leave_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# sobre el grabado un botón de tinta no se lee: tira de papel (como las cintas de los libros)
	Widgets.restyle(_leave_btn, func():
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := Paper.style("carta", {"margin": 8, "shadow": st != "pressed", "shadow_size": 4})
			sb.content_margin_left = 16
			sb.content_margin_right = 16
			if st == "hover":
				sb.border_width_bottom = 2
				sb.border_color = Paper.ink("negra")
			_leave_btn.add_theme_stylebox_override(st, sb))
	nav.add_child(_leave_btn)
	caption = PanelContainer.new()
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Widgets.restyle(caption, func():
		var sb := Paper.style("carta", {"margin": 10, "shadow": true, "shadow_size": 6})
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		caption.add_theme_stylebox_override("panel", sb))
	caption.modulate.a = 0.0
	hr.add_child(caption)
	_cap_v = VBoxContainer.new()
	_cap_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_v.add_theme_constant_override("separation", 2)
	caption.add_child(_cap_v)
	exam = ExamineCard.new()
	exam.clipped.connect(on_clipped)
	hr.add_child(exam)
	speech = Speech.new(false)
	speech.clipped.connect(on_clipped)
	hr.add_child(speech)
	tutor = Speech.new(true)
	tutor.clipped.connect(on_clipped)
	hr.add_child(tutor)
	tray = Tray.new()
	tray.shell = shell
	tray.read_requested.connect(func(v): shell.open_reader(v))
	Layers.root_of(shell.layers.books).add_child(tray)
	catalog = Catalog.new()
	catalog.shell = shell
	catalog.read_requested.connect(_read_from_catalog)
	Layers.root_of(shell.layers.scene).add_child(catalog)

func _chevron(txt: String, dir: int) -> Button:
	var b := Widgets.ink_button(txt, func(): _step_frame(dir))
	b.add_theme_font_size_override("font_size", 46)
	b.modulate.a = 0.55
	b.mouse_entered.connect(func(): b.modulate.a = 0.95)
	b.mouse_exited.connect(func(): b.modulate.a = 0.55)
	b.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if dir < 0 else Control.PRESET_CENTER_RIGHT)
	if dir > 0:
		b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		b.position.x -= 14
	else:
		b.position.x += 14
	nav.add_child(b)
	return b

# ------------------------------------------------------------------ sincronía con el sim
func _on_changed(_kind: String, _payload: Dictionary) -> void:
	request_sync()

func request_sync() -> void:
	if _sync_q:
		return
	_sync_q = true
	_deferred_sync.call_deferred()

func _deferred_sync() -> void:
	_sync_q = false
	if shell == null or not is_inside_tree():
		return
	if shell.is_busy() or _syncing:
		_pending = true
		return
	_sync(false)

func _process(_dt: float) -> void:
	if _pending and shell != null and not shell.is_busy() and not _syncing:
		_pending = false
		_sync(false)
	if shell != null:
		var inset := 0.0 if shell.reader_open() else _band_inset()
		shell.set_subs_inset(inset + 8.0 if inset > 0.0 else 0.0)
		if hud != null:
			hud.set_covered(_hud_covered())

# La esquina del HUD (calendario, monedas, cintas) la tapa un panel acoplado que no es a pantalla entera: el cuaderno a la
# izquierda (junto al libro mayor o en una visita), un subpanel de la escena («Preguntar», presentar, elegir) o el mapa.
func _hud_covered() -> bool:
	var hr: Rect2 = hud.cover_rect()
	if hr.size.x <= 0.0:
		return false
	if shell.is_open("map"):
		return true   # el mapa trae su propia fecha y franja arriba; el calendario no se asoma por debajo del plano
	if shell.is_open("notebook"):
		var nb = shell.panel("notebook")
		if nb != null and "layout" in nb and String(nb.layout) != "full" and nb.has_method("book_rect") and (nb.book_rect() as Rect2).grow(8.0).intersects(hr):
			return true
	for k in ["scene", "confront"]:
		if not shell.is_open(k):
			continue
		var p = shell.panel(k)
		if p == null:
			continue
		for nm in ["ask_panel", "picker", "present_bar"]:
			var c = p.get(nm) if nm in p else null
			if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().intersects(hr):
				return true
	return false

# Un recorte soltado sobre la cinta del libro mayor (cerrado): el libro se abre en un folio nuevo encabezado por él.
func drop_on_ledger(data: Dictionary) -> void:
	var lg = shell.open_panel("ledger")
	if lg != null and lg.has_method("can_drop_folio") and lg.can_drop_folio(data):
		lg.drop_folio(data)

func _key(c: Dictionary, sc: Dictionary) -> Dictionary:
	return {"phase": String(c.phase), "visit": String(sc.get("id", "")), "scene": String(c.get("scene", "")), "day": int(c.day), "slot": String(c.slot)}

func _sync(first: bool, instant := false) -> void:
	var sim = _sim()
	if sim == null:
		return
	_syncing = true
	var c: Dictionary = sim.q_clock()
	var sc: Dictionary = sim.q_scene()
	var ph := String(c.phase)
	if ph == "epilogue" or ph == "done":
		_syncing = false
		_last = _key(c, sc)
		if shell.screen_id == "game":
			if ph == "done":
				shell.quit_to_title()
			else:
				await shell.fade_out()
				shell.show_epilogue()
				await shell.fade_in()
		return
	var key := _key(c, sc)
	if first:
		_enter(c, sc)
		await shell.fade_in(0.0 if instant else shell.FADE_S)
		_after_enter(c, sc, true)
	elif key != _last:
		var new_day := int(c.day) > int(_last.get("day", -1)) and ["night", "prologue", "scene"].has(String(_last.get("phase", "")))
		shell.busy(true)
		await shell.fade_out()
		# otro momento: la mesa limpia (paneles de la fase anterior y avisos de Lisle que ya no corresponden)
		shell.close_all()
		shell.clear_notes()
		if new_day:
			await _dawn(c)
			c = sim.q_clock()
			sc = sim.q_scene()
			key = _key(c, sc)
		_enter(c, sc)
		await shell.fade_in()
		shell.busy(false)
		_after_enter(c, sc, new_day)
	_last = key
	_refresh_hud(c)
	_update_lines(sim.q_scene(), c)
	_sync_overlays()
	_syncing = false

func _refresh_hud(c: Dictionary) -> void:
	var repo = _repo()
	var info := {}
	if repo != null:
		for d in repo.schedule().get("days", []):
			if int(d.get("day", -1)) == int(c.day):
				info = d
	hud.refresh(c, info)
	hud.visible = String(c.phase) != "epilogue"

# ------------------------------------------------------------------ modos
func _enter(c: Dictionary, sc: Dictionary) -> void:
	var sim = _sim()
	_close_transients()
	_doc_plate = false
	var ph := String(c.phase)
	match ph:
		"prologue":
			var pid := String(sc.get("plate", ""))
			if pid != "":
				_show_plate(sim.q_plate(pid), "lamina")
			else:
				_show_hub(HUB_FRAME, c)
		"visit":
			_show_plate(sim.q_visit_plate(), "")
		"scene", "parklane":
			var pid2 := String(sc.get("plate", ""))
			if pid2 == "" and ph == "parklane":
				pid2 = PARK_PLATE   # Park Lane a las 18 h: la lámina fija aunque la escena todavía no tenga la suya
			if pid2 != "" and not sim.q_plate(pid2).is_empty():
				_show_plate(sim.q_plate(pid2), "")
			else:
				_show_hub(HUB_FRAME, c)
		"confront":
			# la tienda de Crane del día 10: la lámina de la escena (HC07) si la trae (sus nodos se recortan); si no, el hub
			var pid3 := String(sc.get("plate", ""))
			if pid3 != "" and not sim.q_plate(pid3).is_empty():
				_show_plate(sim.q_plate(pid3), "mostrador")
			else:
				_show_hub("mostrador", c)
		_:
			# dentro del hub se conserva el encuadre; al volver de una visita o escena, al escritorio
			var f := frame if mode == "hub" and _hub_area(frame) == "buhardilla" else HUB_FRAME
			_show_hub(f, c)
	_ambience(c, sc)

func _after_enter(c: Dictionary, sc: Dictionary, new_day: bool) -> void:
	var sim = _sim()
	var ph := String(c.phase)
	match ph:
		"visit":
			var pl: Dictionary = _place_def(cur_place)
			if not _scene_panel(sc, ph) and (not bool(sc.get("free", false)) or String(sc.get("area", "")) != ""):
				_show_caption(_visit_title(sc), String(pl.get("epigraph", "")))
		"scene", "parklane":
			# sin panel (nadie habla todavía): el epígrafe dice dónde estoy y «Continuar» (abajo a la izquierda) sigue
			if not _scene_panel(sc, ph):
				_show_caption(_scene_title(sc, c), String(_place_def(cur_place).get("epigraph", "")))
		"prologue":
			if new_day or not _started:
				_show_caption(String(_place_def(cur_place).get("name", "")), String(_place_def(cur_place).get("epigraph", "")))
		"confront":
			shell.open_panel("confront")
		"final_report":
			shell.note(Widgets.t("shell.final.nota"))
			shell.open_panel("report")
		"night":
			if bool(sim.q_report_status().get("due", false)):
				shell.note(Widgets.t("shell.night.informe"))
		"night_choice":
			_night_choice()
		"desk":
			if new_day and not sim.q_tray(int(c.day)).is_empty():
				open_tray()

# Panel de escena (W3-SCENEUI) cuando hay a quién hablarle o algo dicho: personajes con sus verbos, líneas recortables,
# «Salir»/«Continuar». Su banda trae el título y el epígrafe; true si se abrió.
func _scene_panel(sc: Dictionary, ph: String) -> bool:
	if not ResourceLoader.exists(SCENE_PANEL):
		return false
	if (sc.get("chars", []) as Array).is_empty() and (sc.get("lines", []) as Array).is_empty():
		return false
	var p = shell.open_panel("scene")
	if p == null:
		return false
	if "show_leave" in p:
		p.show_leave = ph == "visit"
	if p.has_method("refresh"):
		p.refresh()
	_sync_overlays()
	return true

func _band_inset() -> float:
	if shell == null:
		return 0.0
	var best := 0.0
	for k in ["scene", "confront"]:
		if not shell.is_open(k):
			continue
		var p = shell.panel(k)
		if p == null or not ("band" in p) or p.band == null or not is_instance_valid(p.band) or not p.band.is_visible_in_tree():
			continue
		var vs: Vector2 = p.band.get_viewport().get_visible_rect().size
		best = maxf(best, vs.y - p.band.get_global_rect().position.y - 22.0)
	return best

func _visit_title(sc: Dictionary) -> String:
	var repo = _repo()
	var p := String(sc.get("place", ""))
	var name_s := String(_place_def(p).get("name", p))
	var a := String(sc.get("area", ""))
	var ad = _place_def(p).get("areas", {}).get(a, {}) if repo != null else {}
	if typeof(ad) == TYPE_DICTIONARY and String(ad.get("desc", "")) != "" and p == HUB:
		return String(ad.desc).substr(0, 1).to_upper() + String(ad.desc).substr(1)
	return name_s

# Escena fija o Park Lane: el lugar de la lámina y cuándo («Park Lane 427 · jueves 5 de abril, tarde»).
func _scene_title(sc: Dictionary, c: Dictionary) -> String:
	var name_s := String(_place_def(cur_place).get("name", ""))
	if name_s == "":
		name_s = String(_place_def(String(sc.get("place", ""))).get("name", ""))
	var when := String(c.get("date_label", ""))
	if when != "" and String(c.get("slot", "")) != "":
		when += ", " + Widgets.t("core.slot." + String(c.slot))
	if name_s == "" or when == "":
		return name_s
	return Widgets.t("shell.plate.titulo", {"lugar": name_s, "cuando": when})

func _place_def(id: String) -> Dictionary:
	var repo = _repo()
	if repo == null or id == "":
		return {}
	var p: Dictionary = repo.place(id)
	if p.is_empty():
		p = repo.plate(id)
	return p

func _light_slot(c: Dictionary) -> String:
	var ph := String(c.phase)
	if ph == "night" or ph == "night_choice":
		return "night"
	return String(c.slot)

func _show_hub(p_frame: String, c: Dictionary) -> void:
	mode = "hub"
	cur_place = HUB
	cur_plate = "hub"
	frame = p_frame
	shell.world.show_hub(p_frame, _light_slot(c))
	_update_nav()

func _show_plate(snap: Dictionary, p_frame: String) -> void:
	if snap.is_empty():
		var sim = _sim()
		_show_hub(HUB_FRAME, sim.q_clock() if sim != null else {"slot": "M", "phase": "desk"})
		return
	mode = "plate"
	cur_place = String(snap.get("place", ""))
	cur_plate = String(snap.get("id", ""))
	var pl := _place_def(cur_place)
	shell.world.show_plate(snap, pl)
	if p_frame != "" and shell.world.rig.has_frame(p_frame):
		shell.world.set_frame(p_frame, true)
	frame = String(shell.world.rig.cur)
	_update_nav()

# Área del encuadre f de L1 ("" si f no es un encuadre del hub: p. ej. el último de una visita).
func _hub_area(f: String) -> String:
	for fr in _place_def(HUB).get("frames", []):
		if String(fr.get("id", "")) == f:
			return String(fr.get("area", "*"))
	return ""

func frames() -> Array:
	var all: Array = shell.world.frames()
	if mode == "hub":
		var a := _hub_area(frame)
		return all.filter(func(f): return _hub_area(String(f)) == a)
	return all

func go_frame(f: String) -> void:
	if not shell.world.rig.has_frame(f):
		return
	exam.hide_card()
	frame = f
	shell.world.set_frame(f)
	_update_nav()

func _step_frame(dir: int) -> void:
	var fs := frames()
	if fs.size() < 2:
		return
	var i := fs.find(frame)
	go_frame(String(fs[(i + dir + fs.size()) % fs.size()]))

func _update_nav() -> void:
	var fs := frames()
	var many := fs.size() > 1 and not scissors_on
	_chev_l.visible = many
	_chev_r.visible = many
	var sim = _sim()
	var ph := String(sim.q_clock().phase) if sim != null else ""
	var fixed := ph == "scene" or ph == "parklane"
	_leave_btn.visible = (ph == "visit" or fixed or _doc_plate) and not scissors_on and (_doc_plate or not shell.is_open("scene"))
	if _doc_plate:
		_leave_btn.text = Widgets.t("shell.nav.lamina")
	elif fixed:
		_leave_btn.text = Widgets.t("shell.nav.seguir")
	elif ph == "visit":
		var sc: Dictionary = sim.q_scene()
		_leave_btn.text = Widgets.t("shell.nav.subir") if bool(sc.get("free", false)) and String(sc.get("place", "")) == HUB else Widgets.t("shell.nav.volver")

func _ambience(c: Dictionary, sc: Dictionary) -> void:
	var key := cur_place
	if mode == "plate":
		var org := String(_place_def(cur_place).get("origin", ""))
		if org != "":
			key = org
		elif String(sc.get("area", "")) != "":
			key = cur_place + "." + String(sc.area)
	elif String(c.phase) == "confront":
		key = HUB + ".tienda"
	shell.ambience(key, "%d.%s" % [int(c.day), _light_slot(c)])

# ------------------------------------------------------------------ amanecer
func _dawn(c: Dictionary) -> void:
	var repo = _repo()
	var info := {}
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == int(c.day):
			info = d
	var dw := Dawn.new()
	dw.shell = shell
	Layers.root_of(shell.layers.fade).add_child(dw)
	await dw.play({"label": String(info.get("label", c.get("date_label", ""))), "slot_label": Widgets.t("core.slot.dawn"),
		"sunday": String(info.get("weekday", "")) == "dom", "fast": shell.fast, "sounds": shell.sounds})
	dw.queue_free()

# ------------------------------------------------------------------ superposiciones
func _close_transients() -> void:
	exam.hide_card()
	speech.clear()
	set_scissors(false)
	_hide_caption()
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
	if is_instance_valid(catalog) and catalog.visible:
		catalog.close()
	if is_instance_valid(tray) and tray.visible:
		tray.close()

func _sync_overlays() -> void:
	if shell == null:
		return
	# la banda de la escena (abajo) no tapa el diorama: con ella arriba se sigue mirando, examinando y recortando
	var panel_up: bool = shell.top() != null and not BAND_PANELS.has(shell.top_kind())
	scissors.visible = scissors_on and not panel_up
	scissors.mouse_filter = Control.MOUSE_FILTER_STOP if (scissors_on and not panel_up) else Control.MOUSE_FILTER_IGNORE
	shell.world.set_input_enabled(not scissors_on and not panel_up)
	var sim = _sim()
	tutor.visible = sim != null and String(sim.q_clock().phase) == "prologue" and not tutor.current.is_empty()
	var inset := _band_inset()
	exam.bottom_inset = inset
	speech.bottom_inset = inset
	_update_nav()

# Epígrafe al pie (lugar y su frase, como las láminas de Paget). keep: queda mientras se mira (láminas archivadas); si
# no, se va solo a los CAPTION_S segundos.
func _show_caption(title: String, epigraph: String, keep := false) -> void:
	for ch in _cap_v.get_children():
		_cap_v.remove_child(ch)
		ch.queue_free()
	if title == "" and epigraph == "":
		_hide_caption()
		return
	var t := Widgets.label(title, "SourceLine")
	t.uppercase = true
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cap_v.add_child(t)
	if epigraph != "":
		var e := Widgets.label(epigraph, "Caption")
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.add_theme_font_size_override("font_size", int(round(float(_px("ui")) * 1.1)))
		_cap_v.add_child(e)
	caption.size = Vector2.ZERO
	caption.reset_size()
	var vs := caption.get_viewport().get_visible_rect().size
	caption.position = Vector2((vs.x - caption.size.x) * 0.5, vs.y - caption.size.y - 30.0 - _band_inset()).floor()
	if _caption_tw != null and _caption_tw.is_valid():
		_caption_tw.kill()
	caption.modulate.a = 0.0
	_caption_tw = caption.create_tween()
	_caption_tw.tween_property(caption, "modulate:a", 1.0, 0.4)
	if keep:
		return
	_caption_tw.tween_interval(0.0 if shell.fast else CAPTION_S)
	_caption_tw.tween_property(caption, "modulate:a", 0.0, 0.4)

func _hide_caption() -> void:
	if _caption_tw != null and _caption_tw.is_valid():
		_caption_tw.kill()
	caption.modulate.a = 0.0

func _px(kind: String) -> int:
	var ti := Widgets.ti()
	return 19 if ti == null else int(ti.px(kind))

# ------------------------------------------------------------------ líneas dichas
func _labels(sc: Dictionary) -> Dictionary:
	var out := {}
	for ch in sc.get("chars", []):
		out[String(ch.get("id", ""))] = String(ch.get("label", ""))
	return out

func _who_label(who: String, labels: Dictionary) -> String:
	if labels.has(who):
		return String(labels[who])
	var repo = _repo()
	if repo == null or who == "":
		return ""
	var dl: Dictionary = repo.dialogue(who)
	if dl.has("label"):
		return String(dl.label)
	var en: Dictionary = repo.entity(who)
	return String(en.get("noun", en.get("name", "")))

func _update_lines(sc: Dictionary, c: Dictionary) -> void:
	var labels := _labels(sc)
	var fresh: Array = []
	var tut: Array = []
	for ln in sc.get("lines", []):
		var uid := String(ln.get("uid", ""))
		if _seen_lines.has(uid):
			continue
		_seen_lines[uid] = true
		var item := {"uid": uid, "who_label": _who_label(String(ln.get("who", "")), labels), "parsed": ln.get("parsed", {}), "id": String(ln.get("id", ""))}
		if String(c.phase) == "prologue" and String(ln.get("id", "")).begins_with("t_"):
			tut.append(item)
		else:
			fresh.append(item)
	if not tut.is_empty():
		tutor.push_lines(tut)
		tutor.set_scissors(scissors_on)
		# el último paso del tutorial enseña la forma de cerrar el tiempo: el calendario (nota de Lisle, sin contenido)
		for it in tut:
			if String(it.id) == "t_sleep":
				shell.note(Widgets.t("shell.pro.dormir"), 9.0)
	if String(c.phase) != "prologue":
		tutor.visible = false
	if fresh.is_empty():
		return
	if shell.is_open("scene"):
		return   # el panel de escena (W3-SCENEUI) las muestra
	exam.hide_card()
	_hide_caption()
	speech.push_lines(fresh)
	speech.set_scissors(scissors_on)

# ------------------------------------------------------------------ objetos y personajes
func on_node(node_id: String) -> void:
	var sim = _sim()
	var repo = _repo()
	if sim == null or scissors_on:
		return
	speech.clear()
	_hide_caption()
	var b := Objects.binding(repo, cur_place, node_id)
	var dothis := String(b.get("do", ""))
	var c: Dictionary = sim.q_clock()
	var ph := String(c.phase)
	match dothis:
		"tray":
			if ph in ["desk", "night", "final_report", "night_choice"] or (ph == "prologue"):
				open_tray()
				return
		"map", "notebook", "ledger":
			shell.open_panel(dothis)
			return
		"scissors":
			toggle_scissors()
			return
		"calendar":
			calendar()
			return
		"catalog":
			open_catalog()
			return
		"frame":
			if mode == "hub" and shell.world.rig.has_frame(String(b.get("frame", ""))) and frame != String(b.frame):
				go_frame(String(b.frame))
				return
		"go":
			if ph == "desk":
				_go_free(String(b.get("place", "")), String(b.get("area", "")))
				return
		"leave":
			if ph == "visit":
				_leave(true)
				return
	_examine(node_id, b)

func _node_def(node_id: String) -> Dictionary:
	var sim = _sim()
	if sim == null:
		return {}
	var snap: Dictionary = shell.world.snap
	var d: Dictionary = Clipper.node_def(sim.st, sim.repo, snap, node_id)
	if d.is_empty():
		for n in _place_def(cur_place).get("nodes", []):
			if String(n.get("id", "")) == node_id:
				d = n.duplicate(true)
	return d

func _examine(node_id: String, b: Dictionary) -> void:
	var sim = _sim()
	var repo = _repo()
	var nd := _node_def(node_id)
	var title := String(nd.get("noun", node_id.replace("_", " ")))
	var parsed: Dictionary = repo.parse_text(String(nd.get("examine", "")))
	var links: Array = []
	var dothis := String(b.get("do", ""))
	var ph := String(sim.q_clock().phase)
	for d in Objects.docs_for(sim, repo, _place_def(cur_place), nd, b):
		var view := String(d.view)
		links.append({"text": Widgets.t("shell.exam.leer", {"titulo": String(d.title)}), "short": String(d.title), "cb": func(): _read(view)})
	if dothis == "compose":
		links.append_array(_compose_links(ph))
	if dothis == "sleep" and (ph == "night" or ph == "prologue"):
		links.append({"text": Widgets.t("shell.cal.dormir"), "cb": func(): _ask_sleep()})
	exam.show_card(title, parsed, links, {"kind": "node", "ref": cur_plate + "/" + node_id}, node_id, Widgets.t("shell.exam.leer_lista"))
	exam.set_scissors(scissors_on)

func _compose_links(ph: String) -> Array:
	var out: Array = []
	var sim = _sim()
	var ad_ok: bool = ph == "prologue" or ph == "desk"
	out.append({"text": Widgets.t("shell.compose.ad"), "cb": func(): _compose("ad"), "disabled": not ad_ok})
	if ph == "desk":
		out.append({"text": Widgets.t("shell.compose.telegram"), "cb": func(): _compose("telegram")})
		out.append({"text": Widgets.t("shell.compose.letter"), "cb": func(): _compose("letter")})
	return out

func _compose(kind: String) -> void:
	exam.hide_card()
	shell.open_panel(kind, [kind] if kind == "letter" or kind == "telegram" else [])

func _read(view: String) -> void:
	exam.hide_card()
	shell.open_reader(view)

func on_char(cid: String) -> void:
	var sim = _sim()
	if sim == null or scissors_on:
		return
	exam.hide_card()
	var ph := String(sim.q_clock().phase)
	var st: Dictionary = sim.q_report_status()
	if (ph == "night" or ph == "final_report") and bool(st.get("due", false)) and not ["harris", "watson"].has(cid):
		shell.open_panel("report")
		return
	var repo = _repo()
	var talk: bool = ["visit", "scene", "confront", "parklane", "prologue"].has(ph) and (not repo.dialogue(cid).is_empty() or _labels(sim.q_scene()).has(cid))
	if talk and ResourceLoader.exists(SCENE_PANEL):
		shell.open_panel("scene", [cid])
		return
	if ph == "confront":
		shell.open_panel("confront")
		return
	var lbl := _who_label(cid, _labels(sim.q_scene()))
	var en: Dictionary = repo.entity(cid)
	var txt := Widgets.t("shell.char.alguien", {"quien": lbl if lbl != "" else String(en.get("noun", cid))})
	exam.show_card(lbl, repo.parse_text(txt), [], {}, "")
	if talk:
		shell.open_panel("scene", [cid])

func _on_empty(_pos: Vector2) -> void:
	exam.hide_card()

# ------------------------------------------------------------------ presentar (DnD sobre el 3D)
func _on_present(cid: String, data: Dictionary) -> void:
	var sim = _sim()
	if sim == null:
		return
	if ResourceLoader.exists(SCENE_PANEL):
		var p = shell.open_panel("scene", [cid])
		if p != null and p.has_method("request_present"):
			p.request_present(cid, data)
			return
	var a := {"t": "present", "char": cid, "item": {"kind": String(data.kind), "id": String(data.id)}}
	var phrase: String = sim.q_preview(a)
	var body := phrase if phrase != "" else Widgets.t("shell.present.cuerpo", {"que": Chips.label(data)})
	_open_modal(body, Widgets.t("shell.present.mostrar"), Widgets.t("shell.present.guardar"), Widgets.t("shell.present.t"), func():
		var r: Dictionary = shell.act(a)
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", "")))))

# ------------------------------------------------------------------ calendario, franjas, dormir, salir
func calendar() -> void:
	var sim = _sim()
	if sim == null or shell.is_busy():
		return
	var c: Dictionary = sim.q_clock()
	match String(c.phase):
		"desk":
			_ask_end_slot(c)
		"visit":
			_leave(false)
		"night":
			if bool(sim.q_report_status().get("due", false)):
				shell.note(Widgets.t("shell.night.informe"))
				shell.open_panel("report")
			else:
				_ask_sleep()
		"prologue":
			if bool(sim.q_tutorial().get("complete", false)):
				_ask_sleep()
			else:
				var cur: Dictionary = tutor.current
				shell.note(String(cur.get("parsed", {}).get("plain", "")) if not cur.is_empty() else Widgets.t("shell.pro.antes"))
		"scene", "parklane":
			var r: Dictionary = shell.act({"t": "leave"})
			if not bool(r.get("ok", false)):
				shell.note(shell.err_text(String(r.get("err", ""))))
		"final_report":
			shell.open_panel("report")
		"night_choice":
			_night_choice()
		"confront":
			shell.open_panel("confront")

func _next_slot_text(c: Dictionary) -> String:
	var repo = _repo()
	var slots: Array = []
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == int(c.day):
			slots = d.get("slots", [])
	var i := slots.find(String(c.slot))
	if i >= 0 and i + 1 < slots.size():
		return Widgets.t("shell.cal.sigue", {"franja": Widgets.t("core.slot." + String(slots[i + 1]))})
	return Widgets.t("shell.cal.noche")

func _ask_end_slot(c: Dictionary) -> void:
	var franja := Widgets.t("core.slot." + String(c.slot))
	var body := Widgets.t("shell.cal.cerrar_cuerpo", {"franja": franja, "dia": String(c.get("date_label", "")), "sigue": _next_slot_text(c)})
	if not bool(c.get("outing_done", false)):
		body += "\n" + Widgets.t("shell.cal.en_casa")
	_open_modal(body, Widgets.t("shell.cal.cerrar_ok", {"franja": franja}), Widgets.t("kit.confirm.back"), Widgets.t("shell.cal.cerrar_t"), func():
		var r: Dictionary = shell.act({"t": "end_slot"})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
		else:
			shell.play("clock.cuartos"))

func _ask_sleep() -> void:
	var sim = _sim()
	var c: Dictionary = sim.q_clock()
	var repo = _repo()
	var nxt := ""
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == int(c.day) + 1:
			nxt = String(d.get("label", ""))
	nxt = nxt.substr(0, 1).to_lower() + nxt.substr(1)   # «Mañana es martes 27…» (va en medio de la frase)
	_open_modal(Widgets.t("shell.cal.dormir_cuerpo", {"manana": nxt}), Widgets.t("shell.cal.dormir"), Widgets.t("kit.confirm.back"), Widgets.t("shell.cal.dormir_t"), func():
		var r: Dictionary = shell.act({"t": "sleep"})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", "")))))

func _on_leave_btn() -> void:
	if _doc_plate:
		back()
		return
	var sim = _sim()
	if sim != null and ["scene", "parklane"].has(String(sim.q_clock().phase)):
		calendar()   # escena fija sin panel: seguir (leave), como el «Continuar» del panel de escena
		return
	_leave(false)

func _leave(direct: bool) -> void:
	var sim = _sim()
	if sim == null:
		return
	var sc: Dictionary = sim.q_scene()
	var free := bool(sc.get("free", false))
	if direct or free:
		var r: Dictionary = shell.act({"t": "leave"})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
		return
	_open_modal(Widgets.t("shell.leave.cuerpo", {"lugar": _visit_title(sc)}), Widgets.t("shell.leave.ok"), Widgets.t("kit.confirm.back"), Widgets.t("shell.leave.t"), func():
		var r: Dictionary = shell.act({"t": "leave"})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", "")))))

func _go_free(place: String, area: String) -> void:
	var r: Dictionary = shell.act({"t": "go", "place": place, "area": area})
	if not bool(r.get("ok", false)):
		var why := String(r.get("reason", ""))
		var k := "sim.cerrado." + why
		var s := Widgets.t(k)
		shell.note(s if why != "" and s != k else shell.err_text(String(r.get("err", ""))))

func _night_choice() -> void:
	if _modal != null and is_instance_valid(_modal):
		return
	var m := Modal.new()
	m.title_text = Widgets.t("shell.noche.t")
	m.body_text = Widgets.t("shell.noche.cuerpo")
	m.options = [
		{"text": Widgets.t("shell.noche.baker"), "note": Widgets.t("shell.noche.baker_nota"), "cb": func(): _choose_night("baker_street")},
		{"text": Widgets.t("shell.noche.casa"), "note": Widgets.t("shell.noche.casa_nota"), "cb": func(): _choose_night("casa")},
	]
	_show_modal(m)

func _choose_night(where: String) -> void:
	var label := Widgets.t("shell.noche.baker" if where == "baker_street" else "shell.noche.casa")
	_open_modal(Widgets.t("shell.noche.confirma", {"donde": label}), Widgets.t("shell.noche.ir"), Widgets.t("kit.confirm.back"), Widgets.t("shell.noche.t"), func():
		var r: Dictionary = shell.act({"t": "night_choice", "where": where})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
			_night_choice.call_deferred())

# ------------------------------------------------------------------ bandeja y catálogo
func open_tray() -> void:
	exam.hide_card()
	tray.open(-1)
	shell.push(tray, "tray")

# Leer desde el catálogo: el catálogo (capa de escena, sobre el lector) se aparta mientras se lee y vuelve después,
# si la visita a la Sala sigue.
func _read_from_catalog(v: String) -> void:
	if v == "":
		return
	shell.close_kind("catalog")
	if shell.open_reader(v):
		_catalog_after_read = true

func _on_panel_closed_kind(k: String) -> void:
	if k == "reader" and _catalog_after_read:
		_catalog_after_read = false
		var sim = _sim()
		if sim != null and String(sim.q_clock().phase) == "visit" and not shell.is_busy():
			open_catalog.call_deferred()

func open_catalog() -> void:
	exam.hide_card()
	var sim = _sim()
	var s := last_seat
	if s <= 0 and sim != null:
		s = int(sim.st.world.get("seat", 0))
	catalog.open(s)
	shell.push(catalog, "catalog")

# ------------------------------------------------------------------ tijera
func toggle_scissors() -> bool:
	if shell.reader_open() and shell.top() == shell.reader:
		shell.reader.set_tijera(not bool(shell.reader.tijera))
		return true
	var top = shell.top()
	if top != null:
		if top.has_method("toggle_tijera"):
			top.toggle_tijera()
			return true
		if top.has_method("set_tijera") and "tijera" in top:
			top.set_tijera(not bool(top.tijera))
			return true
		return false
	set_scissors(not scissors_on)
	return true

func set_scissors(on: bool) -> void:
	scissors_on = on
	if scissors == null:
		return
	exam.set_scissors(on)
	speech.set_scissors(on)
	tutor.set_scissors(on)
	scissors.set_active(on)
	if on:
		shell.play("sfx.tijera")
	_sync_overlays()

func _on_rect(rect: Rect2) -> void:
	var sim = _sim()
	if sim == null:
		return
	var r: Dictionary = shell.world.rect_clip(rect)
	var a := {"t": "clip_plate", "plate": cur_plate, "hits": r.get("hits", []), "touched": r.get("touched", []), "area_frac": float(r.get("area_frac", 0.0))}
	var res: Dictionary = shell.act(a)
	on_clipped(res)

func on_clipped(res: Dictionary) -> void:
	if not bool(res.get("ok", false)):
		var e := String(res.get("err", ""))
		shell.note(shell.err_text(e))
		return
	shell.play("sfx.tijera")
	var sim = _sim()
	var txt := String(res.get("text", ""))
	if txt == "" and sim != null:
		var cl: Dictionary = sim.q_clip(String(res.get("clip", "")))
		txt = String(cl.get("text", "")) if String(cl.get("text", "")) != "" else String(cl.get("caption", ""))
	_fly_strip(txt)

func _fly_strip(text: String) -> void:
	var hr := Layers.root_of(shell.layers.modal)
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 8, "shadow": true, "shadow_size": 4}))
	var l := Widgets.label(Chips.excerpt(text, 9), "ChipLabel")
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	hr.add_child(p)
	var vs := hr.get_viewport().get_visible_rect().size
	p.reset_size()
	p.position = hr.get_local_mouse_position() - p.size * 0.5
	var tw := p.create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "position", Vector2(30, vs.y - 60), 0.0 if shell.fast else 0.4)
	tw.parallel().tween_property(p, "scale", Vector2(0.4, 0.4), 0.0 if shell.fast else 0.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.0 if shell.fast else 0.2)
	tw.tween_callback(p.queue_free)

# ------------------------------------------------------------------ volver y atajos
func back() -> bool:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
		_modal = null
		return true
	if scissors_on:
		set_scissors(false)
		return true
	if exam.visible:
		exam.hide_card()
		if shell.world.is_examining():
			shell.world.back()
		return true
	if shell.world.is_examining():
		shell.world.back()
		return true
	if speech.visible:
		speech.advance()
		return true
	if _doc_plate:
		var sim = _sim()
		_doc_plate = false
		var c0: Dictionary = sim.q_clock()
		var sc0: Dictionary = sim.q_scene()
		_enter(c0, sc0)
		if ["visit", "scene", "parklane"].has(String(c0.phase)):
			_scene_panel(sc0, String(c0.phase))
		elif String(c0.phase) == "confront":
			shell.open_panel("confront")
		return true
	var sim2 = _sim()
	if sim2 != null and String(sim2.q_clock().phase) == "visit":
		_leave(false)
		return true
	if mode == "hub" and frame != HUB_FRAME and _hub_area(frame) == "buhardilla":
		go_frame(HUB_FRAME)
		return true
	return false

func shortcut_panel(kind: String) -> bool:
	var sim = _sim()
	if sim == null or shell.is_busy():
		return false
	if kind == "map" or kind == "notebook" or kind == "ledger":
		exam.hide_card()
		if scissors_on:
			set_scissors(false)
		# el lector es a pantalla completa (capa 30): un libro (capa 20) quedaría debajo; se deja la hoja y se abre el libro
		if kind != "map" and shell.reader_open() and not shell.is_open(kind):
			shell.close_kind("reader")
		shell.toggle_panel(kind)
		return true
	return false

# ------------------------------------------------------------------ depuración y láminas de documento
func debug_place(spec: String) -> void:
	var sim = _sim()
	if sim == null:
		return
	var place := spec.get_slice(".", 0)
	var area := spec.get_slice(".", 1) if spec.contains(".") else ""
	var WM = load("res://core/sim/world_model.gd")
	var snap: Dictionary = WM.snapshot(sim.st, sim.repo, place, area, "")
	snap["id"] = "DEBUG.%s" % place
	_close_transients()
	_show_plate(snap, "")

# Lámina de documento (D07, frontispicio de D10…) o lámina archivada de una visita/escena: se mira y se recorta (su id es
# el ejemplar); «Dejar la lámina» (o Esc) vuelve a lo de antes.
func show_doc_plate(plate: String) -> void:
	var sim = _sim()
	if sim == null:
		return
	var snap: Dictionary = sim.q_plate(plate)
	if snap.is_empty():
		shell.note(Widgets.t("shell.reader.no"))
		return
	_close_transients()
	_show_plate(snap, "")
	cur_plate = plate
	_doc_plate = true
	_update_nav()
	_show_caption(plate_title(snap), String(_place_def(cur_place).get("epigraph", "")), true)

# «Kensington · martes 27 de marzo, mañana» (lugar de la lámina y cuándo se la vio).
func plate_title(snap: Dictionary) -> String:
	var name_s := String(_place_def(String(snap.get("place", ""))).get("name", ""))
	var d := int(snap.get("day", -1))
	var sl := String(snap.get("slot", ""))
	var repo = _repo()
	var when := ""
	# sólo las láminas archivadas (PL.*) llevan fecha; las de documento (D07, RB…) no son de un día de Lisle
	if repo != null and d >= 0 and String(snap.get("id", "")).begins_with("PL."):
		for x in repo.schedule().get("days", []):
			if int(x.get("day", -1)) == d:
				when = String(x.get("label", ""))
		if when != "" and sl != "":
			when += ", " + Widgets.t("core.slot." + sl)
	return name_s if when == "" else Widgets.t("shell.plate.titulo", {"lugar": name_s, "cuando": when})

# Sin transición ni sincronía pendiente (tests y drivers esperan a esto).
func idle() -> bool:
	return _started and not _syncing and not _pending and not _sync_q and shell != null and not shell.is_busy()

# Posición en pantalla del personaje (centro de su caja) o (-1, -1). Para drivers y tests de presentar (DnD al 3D).
func char_screen_pos(cid: String) -> Vector2:
	var w = shell.world if shell != null else null
	if w == null or w.diorama == null or not is_instance_valid(w.diorama):
		return Vector2(-1, -1)
	var cam: Camera3D = w.camera()
	var b = w.diorama.get_node_or_null("Chars/char_" + cid)
	if cam == null or not (b is Node3D) or not cam.is_inside_tree():
		return Vector2(-1, -1)
	var aabb: AABB = b.get_meta("aabb", AABB(Vector3(-0.25, 0, -0.2), Vector3(0.5, 1.8, 0.4)))
	var p: Vector3 = (b as Node3D).global_transform * aabb.get_center()
	if cam.is_position_behind(p):
		return Vector2(-1, -1)
	return cam.unproject_position(p)

func state() -> Dictionary:
	return {"mode": mode, "place": cur_place, "plate": cur_plate, "frame": frame, "scissors": scissors_on,
		"exam": exam.visible, "speech": speech.visible, "tutor": tutor.visible, "doc_plate": _doc_plate,
		"modal": _modal != null and is_instance_valid(_modal)}

# ------------------------------------------------------------------ modales propios (capa 60)
func _open_modal(body: String, ok_text: String, back_text: String, title: String, on_ok: Callable) -> void:
	var m := Modal.new()
	m.title_text = title
	m.body_text = body
	m.ok_text = ok_text
	m.back_text = back_text
	m.on_ok = on_ok
	_show_modal(m)

func _show_modal(m: Control) -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = m
	Layers.root_of(shell.layers.modal).add_child(m)
	m.tree_exited.connect(func():
		if _modal == m:
			_modal = null)

func modal() -> Control:
	return _modal if _modal != null and is_instance_valid(_modal) else null

# Confirmación en dos pasos (texto final a la vista) u opciones (elección nocturna). El fondo atenúa el 3D.
class Modal extends Control:
	var title_text := ""
	var body_text := ""
	var ok_text := ""
	var back_text := ""
	var on_ok: Callable = Callable()
	var options: Array = []
	func _init() -> void:
		name = "Modal"
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _ready() -> void:
		var dim := ColorRect.new()
		dim.color = Color(Paper.INKS["negra"], 0.35)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(dim)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cc)
		if options.is_empty():
			var c := Widgets.confirm(body_text, ok_text, back_text, title_text)
			cc.add_child(c)
			c.decided.connect(_decided)
			return
		var p := PanelContainer.new()
		Widgets.restyle(p, func(): p.add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 28, "shadow": true, "shadow_size": 14})))
		cc.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 14)
		p.add_child(v)
		v.add_child(Widgets.doc_title(title_text))
		var b := Widgets.caption(body_text)
		b.custom_minimum_size = Vector2(520, 0)
		v.add_child(b)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
		for o in options:
			var card := VBoxContainer.new()
			card.custom_minimum_size = Vector2(240, 0)
			var bt := Widgets.button(String(o.text), o.cb)
			card.add_child(bt)
			var n := Widgets.marginal(String(o.get("note", "")))
			card.add_child(n)
			row.add_child(card)
	func _decided(ok: bool) -> void:
		var cb := on_ok
		queue_free()
		if ok and cb.is_valid():
			cb.call()
