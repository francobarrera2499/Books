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
# v3 UI-MUNDO (GDD_v3 §5.4, §6.3–§6.6): un clic USA el objeto en el acto (abre su panel o su tarjeta) y la cámara no se
#   mueve (riel de world/camera_rig.gd); bajo el mouse sólo el contorno blanco y el cursor (lupa / mano). Sin etiqueta
#   flotante, sin «mirar alrededor», sin «‹ Alejarse», sin el rectángulo de tijera sobre el 3D (todo lo del 3D se recorta
#   del texto de su tarjeta de examen). El plano está sólo en la pared; el tintero es el único lugar para escribir. Las
#   cintas «Cuaderno» y «Expediente» del HUD, sólo fuera de la buhardilla (hud.cintas). Nodos con «aviso» (intrusiones)
#   y faltantes del estante emiten la acción libre examine (§4.4). Al entrar a la buhardilla con la variante «techos»,
#   una ráfaga (Audio.play_event("intrusion_techos")) una vez por entrada.
extends Node

const Layers = preload("res://ui/layers.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const DeskHud = preload("res://ui/desk/desk_hud.gd")
const Tray = preload("res://ui/desk/tray.gd")
const Dawn = preload("res://ui/desk/dawn.gd")
const ExamineCard = preload("res://ui/desk/examine_card.gd")
const Speech = preload("res://ui/desk/speech.gd")
const Catalog = preload("res://ui/desk/catalog.gd")
const Objects = preload("res://ui/desk/objects.gd")
const Chips = preload("res://ui/drag/chips.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const Effects = preload("res://core/react/effects.gd")
const Cursors = preload("res://ui/desk/cursors.gd")

const HUB := "L1"
const HUB_FRAME := "general"     # alias del punto de inicio del riel de la buhardilla (el escritorio, world/camera.json)
const PARK_PLATE := "PARK"
const BAND_PANELS := ["scene", "confront"]   # bandas abajo (y la afirmación arriba): el diorama sigue a la vista, se examina y se recorta
const CAPTION_S := 4.5
const SCENE_PANEL := "res://ui/scene/scene_panel.gd"

var shell = null
var hud: Control
var nav: Control
var exam: PanelContainer
var speech: PanelContainer
var tutor: PanelContainer
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
var _leave_btn: Button
var _catalog_after_read := false
var _tray_shown := {}             # día -> true: la bandeja de ese día ya se mostró (sola o a pedido) en esta sesión
var _confront_after_tray := false
var _world_seen := {}             # "<id>|<tk>" -> true: eventos del mundo ya mostrados (sonido, velo)
var _tutor_layer: CanvasLayer
var _tut_wait: Array = []         # notas del instructor que esperan a que termine la presentación (cola de la tarjeta)
var _tut_framed := false          # el primer paso ya llevó la vista al escritorio
var _tut_started := false         # ya se mostró una nota del instructor (sólo la primera espera a la presentación)
var _techos_heard := {}           # from_tk de la intrusión por los techos cuya ráfaga ya sonó (una vez por intrusión)
var techos_played := 0            # ráfagas pedidas en esta sesión (tests, drivers)

const TUTOR_LAYER := 35   # playtest v2: por encima del lector (30): el paso «recortar» llega al abrir el encargo
const EXAM_LINKS_MAX := 4         # §C.1: tarjeta de examen con ≤4 enlaces; más → lista en dos niveles (tomos)
const TUTOR_FRAME := "escritorio"
const TUTOR_FRAME_FOLDER := "expediente"   # PRO: la carpeta de cerca (primer paso del prólogo)

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
	if not w.rig.frame_changed.is_connected(_on_frame_changed):
		w.rig.frame_changed.connect(_on_frame_changed)
	Cursors.install()
	shell.drop_catcher.present_requested.connect(_on_present)
	shell.panel_opened.connect(func(_k): _sync_overlays())
	shell.panel_closed.connect(func(_k): _sync_overlays())
	shell.panel_closed.connect(_on_panel_closed_kind)
	var sim = _sim()
	if sim != null and not sim.actions_log().is_empty():
		for ln in sim.q_scene().get("lines", []):
			_seen_lines[String(ln.uid)] = true
	# los eventos del mundo de antes de esta sesión (partida continuada) ya pasaron: no se repiten
	if sim != null:
		for e in Effects.world_events(sim.st):
			_world_seen[_wev_key(e)] = true
	await _sync(true, instant)
	_started = true

func _exit_tree() -> void:
	Cursors.uninstall()

func leave_screen() -> void:
	var g = shell.game() if shell != null else null
	if g != null and g.sim_changed.is_connected(_on_changed):
		g.sim_changed.disconnect(_on_changed)
	var w = shell.world if shell != null else null
	if w != null and w.node_clicked.is_connected(on_node):
		w.node_clicked.disconnect(on_node)
		w.character_clicked.disconnect(on_char)
		w.empty_clicked.disconnect(_on_empty)
	if w != null and w.rig.frame_changed.is_connected(_on_frame_changed):
		w.rig.frame_changed.disconnect(_on_frame_changed)
	if w != null and w.has_method("set_usable"):
		w.set_usable({}, {})
	if shell != null and shell.drop_catcher.present_requested.is_connected(_on_present):
		shell.drop_catcher.present_requested.disconnect(_on_present)
	set_scissors(false)
	for n in [hud, nav, exam, speech, tutor, tray, catalog, caption, _tutor_layer]:
		if n != null and is_instance_valid(n):
			n.queue_free()

func _build_ui() -> void:
	var hr := Layers.root_of(shell.layers.hud)
	hud = DeskHud.new()
	hud.calendar_pressed.connect(calendar)
	hud.book_pressed.connect(func(k): shortcut_panel(k))
	hr.add_child(hud)
	nav = Control.new()
	nav.name = "Nav"
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hr.add_child(nav)
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
	exam.scissors_toggled.connect(func(on): set_scissors(on))
	exam.scissors_ok = func() -> bool: return _flag(ui_flags(), "desk.tijera")
	hr.add_child(exam)
	speech = Speech.new(false)
	speech.clipped.connect(on_clipped)
	speech.emptied.connect(_on_speech_emptied)
	hr.add_child(speech)
	# la nota del instructor va en su propia capa, ENCIMA de los libros (20) y debajo del lector (30): los pasos del
	# cuaderno y del libro mayor se hacen con el libro abierto y la nota quedaba tapada (W4); con un libro abierto se
	# acopla en un margen libre (_tutor_dock)
	_tutor_layer = CanvasLayer.new()
	_tutor_layer.name = "TutorLayer"
	_tutor_layer.layer = TUTOR_LAYER
	add_child(_tutor_layer)
	var tr := Control.new()
	tr.name = "Root"
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutor_layer.add_child(tr)
	tutor = Speech.new(true)
	tutor.clipped.connect(on_clipped)
	tutor.link_ok = func(ent: String) -> bool: return _node_for_ent(ent) != ""
	tutor.link_cb = _on_tutor_link
	tr.add_child(tutor)
	tray = Tray.new()
	tray.shell = shell
	tray.read_requested.connect(func(v): shell.open_reader(v))
	Layers.root_of(shell.layers.books).add_child(tray)
	catalog = Catalog.new()
	catalog.shell = shell
	catalog.read_requested.connect(_read_from_catalog)
	Layers.root_of(shell.layers.scene).add_child(catalog)

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
		if tutor != null and tutor.visible:
			tutor.dock = _tutor_dock()

# La esquina del HUD (calendario, cintas) la tapa un panel acoplado que no es a pantalla entera: el cuaderno a la izquierda
# (junto al expediente o en una visita), la carpeta del expediente, un subpanel de la escena («Preguntar», presentar,
# elegir) o el mapa.
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
	if shell.is_open("dossier"):
		var ex = shell.panel("dossier")
		if ex != null and ex.has_method("debug_state"):
			var er = ex.debug_state().get("rect", Rect2())
			if er is Rect2 and (er as Rect2).size.x > 0.0 and (er as Rect2).grow(8.0).intersects(hr):
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
			# la transición la lleva la Shell: esta pantalla se libera al pasar al epílogo y una corrutina suya no volvería
			# (W4: «continuar» una partida en el epílogo dejaba colgado gs.start() y un error del motor)
			if ph == "done":
				shell.quit_to_title()
			else:
				shell.go_epilogue()
		return
	var key := _key(c, sc)
	if first:
		_enter(c, sc)
		await shell.fade_in(0.0 if instant else shell.FADE_S)
		# primera carga (Partida nueva / Continuar): la bandeja sólo si tiene algo sin leer (playtest v3: se abría en cada
		# «Continuar» con todo leído) y sin repetir los eventos del amanecer ya vistos
		_after_enter(c, sc, true, true)
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
	refresh_affordances()
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
	var f := ui_flags()
	hud.set_flags(f)
	hud.set_guide(guide_texts(f))

# Tira «Pendientes» (GDD_v2 §B.6.2, GDD_v3 §6.9): las líneas de Game.sim.q_guide() ({key, vars} -> ui_text; una clave sin
# texto no se muestra). ≤3 líneas.
func guide_texts(f := {}) -> Array:
	var out: Array = []
	var sim = _sim()
	if sim == null or not bool(f.get("desk.pendientes", false)):
		return out
	if sim.has_method("q_guide"):
		for ln in sim.q_guide():
			if typeof(ln) != TYPE_DICTIONARY:
				continue
			var k := String(ln.get("key", ""))
			var t := Widgets.t(k, ln.get("vars", {}))
			if t != "" and t != k:
				out.append(t)
	return out.slice(0, 3)

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
			# la tienda de Crane del día 10: la lámina de la escena (HC07) si la trae (sus nodos se recortan); si no, el hub.
			# Si la bandeja del día no se vio (el Times del jueves), primero el escritorio con la bandeja (W4: «la mañana es
			# la respuesta»); al cerrarla, la tienda y la confrontación.
			var pid3 := String(sc.get("plate", ""))
			if _tray_pending(int(c.day)):
				_confront_after_tray = true
				_show_hub(HUB_FRAME, c)
			elif pid3 != "" and not sim.q_plate(pid3).is_empty():
				_show_plate(sim.q_plate(pid3), "mostrador")
			else:
				_show_hub("mostrador", c)
		_:
			# dentro del hub se conserva el encuadre; al volver de una visita o escena, al escritorio
			var f := frame if mode == "hub" and _in_attic() and shell.world.rig.has_frame(frame) else HUB_FRAME
			_show_hub(f, c)
	_ambience(c, sc)

func _after_enter(c: Dictionary, sc: Dictionary, new_day: bool, first := false) -> void:
	var sim = _sim()
	var ph := String(c.phase)
	if ph == "visit":
		_world_events("salida")
	elif new_day and not first:
		_world_events("amanecer")
	match ph:
		"visit":
			var pl: Dictionary = _place_def(cur_place)
			if not _scene_panel(sc, ph) and (not bool(sc.get("free", false)) or String(sc.get("area", "")) != ""):
				_show_caption(_visit_title(sc), place_epigraph(pl, String(sc.get("area", ""))))
		"scene", "parklane":
			# sin panel (nadie habla todavía): el epígrafe dice dónde estoy y «Continuar» (abajo a la izquierda) sigue
			if not _scene_panel(sc, ph):
				_show_caption(_scene_title(sc, c), place_epigraph(_place_def(cur_place), String(sc.get("area", ""))))
		"prologue":
			if new_day or not _started:
				_show_caption(String(_place_def(cur_place).get("name", "")), String(_place_def(cur_place).get("epigraph", "")))
		"confront":
			if _confront_after_tray:
				open_tray()
			else:
				shell.open_panel("confront")
		"final_report":
			shell.note(Widgets.t("shell.final.nota"))
			shell.open_panel("report")
			if _tray_pending(int(c.day)):
				open_tray()
		"night":
			if bool(sim.q_report_status().get("due", false)):
				shell.note(Widgets.t("shell.night.informe"), 9.0)
				# playtest v3: la cámara mira la puerta, donde espera el chico (antes quedaba en el escritorio)
				if mode == "hub" and _in_attic() and shell.world.rig.has_frame("puerta"):
					shell.world.set_frame("puerta")
		"night_choice":
			_night_choice()
		"desk":
			# también los días que empiezan con una escena (M6 el día 5): la bandeja se ofrece una vez por día.
			# Playtest v3: la primera vez que se ve la pieza revuelta (techos / registrada) la bandeja no se abre sola: tapaba
			# la cortina, la ventana y los papeles. Queda en el escritorio (y en Pendientes) para cuando se la busque.
			if fresh_intrusion():
				pass
			elif (new_day and not first and not sim.q_tray(int(c.day)).is_empty()) or _tray_pending(int(c.day)):
				open_tray()

# Eventos del mundo (Effects.world_events, op evento_mundo de las reacciones) con forma en pantalla según
# data/map.json world_events: sonido (su subtítulo lo describe) y un velo breve. Cada uno una vez, en el primer momento
# «on» (salida | amanecer) desde que ocurrió. Devuelve los ids mostrados (tests).
func _world_events(on: String) -> Array:
	var shown: Array = []
	var sim = _sim()
	var repo = _repo()
	if sim == null or repo == null:
		return shown
	var spec = repo.map().get("world_events", {})
	if typeof(spec) != TYPE_DICTIONARY:
		return shown
	var now := int(sim.q_clock().get("tk", 0))
	for e in Effects.world_events(sim.st):
		var k := _wev_key(e)
		if _world_seen.has(k):
			continue
		var s = spec.get(String(e.get("id", "")), null)
		if typeof(s) != TYPE_DICTIONARY:
			_world_seen[k] = true
			continue
		if String(s.get("on", "")) != on or int(e.get("tk", 0)) > now:
			continue
		_world_seen[k] = true
		shown.append(String(e.get("id", "")))
		if String(s.get("sound", "")) != "":
			shell.play(String(s.sound))
		if String(s.get("veil", "")) != "":
			_veil()
	return shown

static func _wev_key(e: Dictionary) -> String:
	return "%s|%d" % [String(e.get("id", "")), int(e.get("tk", 0))]

# Polvo: un velo pálido sobre la lámina que se asienta en un segundo (tres tramos de ≤0,4 s).
func _veil() -> void:
	var hr := Layers.root_of(shell.layers.hud)
	var v := ColorRect.new()
	v.name = "Polvo"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.color = Color(Paper.paper("registro"), 0.0)
	hr.add_child(v)
	hr.move_child(v, 0)
	var tw := v.create_tween()
	tw.tween_property(v, "color:a", 0.0 if shell.fast else 0.38, 0.0 if shell.fast else 0.25)
	tw.tween_interval(0.0 if shell.fast else 0.4)
	tw.tween_property(v, "color:a", 0.0, 0.0 if shell.fast else 0.4)
	tw.tween_callback(v.queue_free)

# La bandeja de ese día tiene papeles SIN LEER y todavía no se mostró en esta sesión (playtest v3: al «Continuar», la
# bandeja ya leída se volvía a abrir sola y tapaba la vuelta a la pieza, p. ej. la intrusión).
func _tray_pending(day: int) -> bool:
	var sim = _sim()
	if sim == null or _tray_shown.has(day):
		return false
	for it in sim.q_tray(day):
		if not bool(it.get("read", false)):
			return true
	return false

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
	frame = String(shell.world.rig.cur) if String(shell.world.rig.cur) != "" else p_frame
	_update_nav()
	refresh_affordances()
	_techos_wind(c)

# ¿La vista es la buhardilla (riel del área «buhardilla» del hub)?
func _in_attic() -> bool:
	if mode != "hub" or shell == null or shell.world == null:
		return false
	return String(shell.world.snap.get("cam_area", shell.world.snap.get("area", ""))) in ["buhardilla", "", "*"]

# GDD_v3 §4.3: al entrar a la pieza con la variante «techos» activa, una ráfaga corta (una vez por entrada); la cortina la
# mueve world/props/l1.gd. Con «registrada», nada suena.
# Playtest v3: sonaba en cada cambio de turno y en cada «Continuar» mientras duraba la variante; ahora UNA vez por
# intrusión (su from_tk), y sólo en la primera vuelta a la pieza después de ella (no al día siguiente ni al continuar).
func _techos_wind(c: Dictionary) -> void:
	var v := String(shell.world.snap.get("variant", ""))
	if not v.contains("techos") or not _in_attic():
		return
	var ft := techos_from_tk()
	if ft < 0 or _techos_heard.has(ft):
		return
	_techos_heard[ft] = true
	var now := int(c.get("tk", -1))
	if now < 0:
		var sim = _sim()
		now = int(sim.q_clock().get("tk", -1)) if sim != null else -1
	if now >= 0 and now > ft + 1:
		return
	techos_played += 1
	shell.play_event("intrusion_techos")

# ¿La pieza muestra AHORA, por primera vez en esta sesión, una intrusión recién ocurrida (capa techos o registrada que
# empezó hace ≤1 franja)? Marca la intrusión como vista.
var _intrusion_seen := {}
func fresh_intrusion() -> bool:
	var sim = _sim()
	if sim == null or mode != "hub" or not _in_attic() or typeof(sim.st.react) != TYPE_DICTIONARY:
		return false
	var r = sim.st.react.get("world", {}).get("variants", {}).get("L1")
	if typeof(r) != TYPE_DICTIONARY:
		return false
	var now := int(sim.q_clock().get("tk", 0))
	var ls: Array = r.get("layers", []) if typeof(r.get("layers")) == TYPE_ARRAY else [r]
	var fresh := false
	for l in ls:
		if typeof(l) != TYPE_DICTIONARY or not ["techos", "registrada"].has(String(l.get("variant", ""))):
			continue
		var f := int(l.get("from_tk", 0))
		var u := int(l.get("to_tk", -1))
		var key := "%s|%d" % [String(l.variant), f]
		if now >= f and (u < 0 or now < u) and now <= f + 1 and not _intrusion_seen.has(key):
			_intrusion_seen[key] = true
			fresh = true
	return fresh

# from_tk de la capa «techos» activa en la pieza (-1 si no hay).
func techos_from_tk() -> int:
	var sim = _sim()
	if sim == null or typeof(sim.st.react) != TYPE_DICTIONARY:
		return -1
	var r = sim.st.react.get("world", {}).get("variants", {}).get("L1")
	if typeof(r) != TYPE_DICTIONARY:
		return -1
	var now := int(sim.q_clock().get("tk", 0))
	var best := -1
	var ls: Array = r.get("layers", []) if typeof(r.get("layers")) == TYPE_ARRAY else [r]
	for l in ls:
		if typeof(l) != TYPE_DICTIONARY or String(l.get("variant", "")) != "techos":
			continue
		var f := int(l.get("from_tk", 0))
		var u := int(l.get("to_tk", -1))
		if now >= f and (u < 0 or now < u):
			best = maxi(best, f)
	return best

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
	refresh_affordances()
	if tutor != null:
		tutor.refresh_links()

# Puntos del riel de la cámara del área a la vista (world/camera.json o los encuadres del lugar).
func frames() -> Array:
	return shell.world.frames()

func _on_frame_changed(id: String) -> void:
	frame = id

func go_frame(f: String) -> void:
	if not shell.world.rig.has_frame(f):
		return
	exam.hide_card()
	frame = f
	shell.world.set_frame(f)
	_update_nav()

func _update_nav() -> void:
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
	shell.world.set_input_enabled(not panel_up)
	# las bandas del borde nunca giran con un panel abierto. La banda de escena/confrontación NO cuenta como panel (el
	# mundo sigue vivo arriba de ella; sobre la banda misma no gira porque es un control)
	shell.world.edge_enabled = not panel_up
	var sim = _sim()
	tutor.visible = sim != null and String(sim.q_clock().phase) == "prologue" and not tutor.current.is_empty()
	var inset := _band_inset()
	exam.bottom_inset = inset
	speech.bottom_inset = inset
	_update_nav()

# Epígrafe al pie (lugar y su frase, como las láminas de Paget). keep: queda mientras se mira (láminas archivadas); si
# no, se va solo a los CAPTION_S segundos.
# Epígrafe del lugar: el del área de la visita si el lugar lo declara (epigraph_by_area), si no el general.
static func place_epigraph(pl: Dictionary, area: String) -> String:
	var by = pl.get("epigraph_by_area", {})
	if typeof(by) == TYPE_DICTIONARY and area != "" and by.has(area):
		return String(by[area])
	return String(pl.get("epigraph", ""))

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
	var repo = _repo()
	# se presentó él mismo en una línea («Josiah Pell, procurador…»): desde entonces, su nombre (W4)
	if who != "" and who != "lisle" and SimLink.introduced_by_line(_sim(), who):
		return SimLink.proper_name(repo, who)
	if labels.has(who):
		return String(labels[who])
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
		# la nota fija espera a que la presentación termine (W4: «Antes de irnos, enséñeme…» aparecía antes de que Pell
		# terminara de presentarse, dos tarjetas del mismo que hablaba)
		# (si el jugador ya avanza un paso sin haber leído la presentación, la nota se muestra igual: es lo que hace ahora)
		if not _tut_started and _tut_wait.is_empty() and (speech.visible or (not fresh.is_empty() and not shell.is_open("scene"))):
			_tut_wait = tut.duplicate()
		else:
			var all := _tut_wait + tut
			_tut_wait.clear()
			_push_tutor(all)
	if String(c.phase) != "prologue":
		tutor.visible = false
		_tut_wait.clear()
	if fresh.is_empty():
		return
	if shell.is_open("scene") or String(c.phase) == "confront":
		# el panel de escena (W3-SCENEUI) las muestra; en la confrontación, su transcripción (la tarjeta flotante tapaba
		# al librero y su sombra, que es una pista, y duplicaba la primera línea: W4)
		if String(c.phase) == "confront":
			speech.clear()
		return
	exam.hide_card()
	_hide_caption()
	speech.push_lines(fresh)
	speech.set_scissors(scissors_on)

func _push_tutor(tut: Array) -> void:
	if tut.is_empty():
		return
	_tut_started = true
	tutor.push_lines(tut)
	tutor.set_scissors(scissors_on)
	# el último paso del tutorial enseña la forma de cerrar el tiempo: el calendario (nota de Lisle, sin contenido)
	for it in tut:
		if String(it.id) == "t_sleep":
			shell.note(Widgets.t("shell.pro.dormir"), 9.0)
	# el primer paso pide algo de la mesa: la vista va al escritorio (W4: desde el encuadre de la lámina el encargo es una
	# hoja detrás del respaldo de la silla y la concordancia queda detrás de Harris)
	# playtest v3: el primer paso («abra el expediente») encuadra la carpeta de cerca, con «Holmes» en la tapa a la vista
	# (desde el escritorio entero se confundía con una hoja)
	if not _tut_framed and mode == "plate" and shell.world.rig.has_frame(TUTOR_FRAME):
		_tut_framed = true
		var first := TUTOR_FRAME_FOLDER if shell.world.rig.has_frame(TUTOR_FRAME_FOLDER) else TUTOR_FRAME
		if frame != first:
			go_frame(first)
	_sync_overlays()

func _on_speech_emptied() -> void:
	if _tut_wait.is_empty():
		return
	var sim = _sim()
	if sim == null or String(sim.q_clock().phase) != "prologue":
		_tut_wait.clear()
		return
	var w := _tut_wait.duplicate()
	_tut_wait.clear()
	_push_tutor(w)

# Nodo de la lámina actual que nombra una entidad (id igual o etiqueta e:/mención del examen); "" si ninguno.
func _node_for_ent(ent: String) -> String:
	if ent == "" or shell == null or shell.world == null:
		return ""
	var idx: Dictionary = shell.world.diorama.get_meta("nodes_index", {}) if shell.world.diorama != null and is_instance_valid(shell.world.diorama) else {}
	if idx.has(ent):
		return ent
	var repo = _repo()
	for n in _place_def(cur_place).get("nodes", []):
		if typeof(n) != TYPE_DICTIONARY:
			continue
		var nid := String(n.get("id", ""))
		if nid != "" and idx.has(nid) and Objects.node_ents(repo, n).has(ent):
			return nid
	return ""

# Clic en una mención subrayada de la nota del instructor: la vista va a la mesa y se examina el objeto.
func _on_tutor_link(ent: String) -> void:
	var nid := _node_for_ent(ent)
	if nid == "" or scissors_on:
		return
	if mode == "plate" and frame != TUTOR_FRAME and shell.world.rig.has_frame(TUTOR_FRAME):
		go_frame(TUTOR_FRAME)
	on_node(nid)

# Margen libre donde acoplar la nota del instructor con un libro abierto (prólogo); Rect2() = su lugar de siempre.
func _tutor_dock() -> Rect2:
	if shell == null:
		return Rect2()
	var vs: Vector2 = tutor.get_viewport().get_visible_rect().size if tutor.is_inside_tree() else Vector2(1600, 900)
	var hud_bottom := 0.0
	if hud != null and hud.has_method("cover_rect"):
		var hr: Rect2 = hud.cover_rect()
		hud_bottom = hr.end.y
	var top0 := maxf(hud_bottom + 16.0, 120.0)
	# con el lector abierto (prólogo: el encargo), en el margen izquierdo, debajo de la ficha del documento: el paso
	# «recortar» llega justo al abrirlo (playtest v2)
	if shell.reader_open() and shell.reader != null:
		var hd = shell.reader.get("_header")
		if hd is Control and (hd as Control).is_visible_in_tree():
			var hrc: Rect2 = (hd as Control).get_global_rect()
			var w0 := maxf(hrc.size.x, 300.0)
			var top1 := hrc.end.y + 16.0
			return Rect2(hrc.position.x, top1, w0, maxf(160.0, vs.y - top1 - 120.0))
	# con la carpeta del expediente abierta, en la solapa del índice, debajo de las preguntas (UI-EXPEDIENTE: tutor_rect)
	if shell.is_open("dossier"):
		var ex = shell.panel("dossier")
		if ex != null and ex.has_method("tutor_rect"):
			var r: Rect2 = ex.tutor_rect()
			if r.size.x >= 170.0 and r.size.y >= 120.0:
				return r
	if shell.is_open("notebook") and not shell.is_open("dossier"):
		var nb = shell.panel("notebook")
		if nb != null and nb.has_method("book_rect"):
			var br: Rect2 = nb.book_rect()
			var left := br.position.x - 24.0
			var right := vs.x - br.end.x - 24.0
			var h := vs.y - top0 - 24.0
			if left >= right and left >= 170.0:
				return Rect2(12.0, top0, minf(left, 360.0), h)
			if right >= 170.0:
				var w := minf(right, 360.0)
				return Rect2(vs.x - 12.0 - w, maxf(top0, 130.0), w, h)
	return Rect2()

# ------------------------------------------------------------------ objetos y personajes
# GDD_v3 §6.4–§6.6: un clic USA el objeto en el acto (su panel; si no tiene, su tarjeta de examen) y la cámara no se
# mueve. Con la tijera en la mano también: la tarjeta que se abre se recorta.
func on_node(node_id: String) -> void:
	var sim = _sim()
	var repo = _repo()
	if sim == null:
		return
	# playtest v3: un clic en el 3D con líneas todavía sin leer (la presentación de Pell en el prólogo) las borraba todas;
	# ahora pasa a la siguiente línea y no usa el objeto. Con la última línea a la vista, el clic la cierra y sigue.
	if speech.showing() and not speech.queue.is_empty():
		speech.advance()
		return
	speech.clear()
	_hide_caption()
	var b := Objects.binding(repo, cur_place, node_id)
	var dothis := String(b.get("do", ""))
	var c: Dictionary = sim.q_clock()
	var ph := String(c.phase)
	var live := binding_live(dothis, ph)
	# la silueta de un personaje de la visita (Wiggins desde el día 3) se trata como a los demás: su figura abre la
	# conversación, no una tarjeta de examen (W4)
	if node_id.begins_with("sil_") and ["visit", "scene", "parklane"].has(ph) and _labels(sim.q_scene()).has(node_id.substr(4)):
		on_char(node_id.substr(4))
		return
	if live:
		match dothis:
			"tray":
				open_tray()
				return
			"map", "notebook", "dossier":
				exam.hide_card()
				if scissors_on:
					set_scissors(false)
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
			"go":
				_go_free(String(b.get("place", "")), String(b.get("area", "")))
				return
			"leave":
				_leave(true)
				return
			"compose":
				# el tintero: con una sola cosa para escribir, se abre directo; con varias, su tarjeta las ofrece
				var cl := _compose_links(ph)
				if cl.size() == 1:
					exam.hide_card()
					(cl[0].cb as Callable).call()
					return
	_examine(node_id, b)

# Banderas de revelado (GDD_v2 §C.2: Game.sim.q_ui()); sin ellas (datos viejos, tests de respaldo) todo vale.
func ui_flags() -> Dictionary:
	var sim = _sim()
	if sim != null and sim.has_method("q_ui"):
		var f = sim.q_ui()
		if f is Dictionary:
			return f
	return {}

func _flag(f: Dictionary, k: String) -> bool:
	return bool(f.get(k, true))

# ¿El vínculo de un objeto (data/map.json objects) sirve AHORA? Lo que sirve lleva la mano (§6.5); lo demás, la lupa.
func binding_live(dothis: String, ph: String, f := {}) -> bool:
	if f.is_empty():
		f = ui_flags()
	var sim = _sim()
	match dothis:
		"tray":
			return _flag(f, "desk.bandeja") and ph in ["desk", "night", "final_report", "night_choice", "prologue", "confront"]
		"map":
			return _flag(f, "desk.mapa")
		"notebook":
			return _flag(f, "hud.cuaderno")
		"dossier":
			return _flag(f, "desk.expediente")
		"scissors":
			return _flag(f, "desk.tijera")
		"calendar":
			return _flag(f, "desk.calendario")
		"compose":
			return _flag(f, "desk.tintero") and ph in ["prologue", "desk"] and not _compose_links(ph, f).is_empty()
		"sleep":
			if ph == "night":
				return true
			return ph == "prologue" and sim != null and bool(sim.q_tutorial().get("complete", false))
		"catalog":
			return ph == "visit"
		"go":
			return ph == "desk"
		"leave":
			return ph == "visit"
		"docs":
			return true
	return false

func _char_talkable(cid: String, ph: String, sc: Dictionary) -> bool:
	var repo = _repo()
	if repo == null:
		return false
	return ["visit", "scene", "confront", "parklane", "prologue"].has(ph) and (not repo.dialogue(cid).is_empty() or _labels(sc).has(cid))

# Lo que se USA (cursor de mano, §6.5): vínculos vivos de map.json, salidas, personajes en primer plano y las siluetas
# con las que se habla. Lo demás se mira (lupa). Nada se marca en el dibujo hasta pasar el mouse (contorno blanco).
func refresh_affordances() -> void:
	var sim = _sim()
	var w = shell.world if shell != null else null
	if sim == null or w == null or w.diorama == null or not w.has_method("set_usable"):
		return
	var repo = _repo()
	var ph := String(sim.q_clock().phase)
	var sc: Dictionary = sim.q_scene()
	var f := ui_flags()
	var use := {}
	var hand := {}
	var idx: Dictionary = w.diorama.get_meta("nodes_index", {})
	# playtest v3 (Somerset House): en una visita, un objeto cuya tarjeta ofrece leer o pedir un papel también se USA
	# (mano); antes la única acción útil quedaba escondida tras la lupa
	var doc_ents := {}
	var doc_views := {}
	if ph == "visit":
		for v in sim.q_accessible():
			doc_views[String(v.get("view", ""))] = true
			var de := String(repo.doc(String(v.get("doc", ""))).get("entity", ""))
			if de != "":
				doc_ents[de] = true
	for nid in idx:
		var id := String(nid)
		if id.begins_with("sil_"):
			if ["visit", "scene", "parklane"].has(ph) and _labels(sc).has(id.substr(4)):
				hand["n:" + id] = true
			continue
		var b := Objects.binding(repo, cur_place, id)
		if binding_live(String(b.get("do", "")), ph, f):
			use["n:" + id] = true
		elif not doc_ents.is_empty():
			var ndf := _node_def(id)
			var own := Objects.own_doc(_place_def(cur_place), ndf)
			if own != "" and doc_views.has(own):
				use["n:" + id] = true
				continue
			for e in Objects.node_ents(repo, ndf):
				if doc_ents.has(String(e)):
					use["n:" + id] = true
					break
	var ci: Dictionary = w.diorama.get_meta("chars_index", {})
	# playtest v3: a las 22 el chico de Pell (en la puerta) se USA: el clic abre el informe (antes mostraba la lupa)
	var report_due: bool = (ph == "night" or ph == "final_report") and sim.has_method("q_report_status") and bool(sim.q_report_status().get("due", false))
	for cid in ci:
		if _char_talkable(String(cid), ph, sc) or (report_due and not ["harris", "watson"].has(String(cid))):
			use["c:" + String(cid)] = true
	w.set_usable(use, hand)

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s

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
	# «aviso» (intrusiones, GDD_v3 §4.3–§4.4): lo trae la definición del nodo de la variante (snap.node_defs)
	var defs = snap.get("node_defs", {})
	if typeof(defs) == TYPE_DICTIONARY and typeof(defs.get(node_id)) == TYPE_DICTIONARY and String(defs[node_id].get("aviso", "")) != "":
		d["aviso"] = String(defs[node_id].aviso)
	elif not d.has("aviso"):
		for vd in _place_def(cur_place).get("variants", {}).values():
			if typeof(vd) != TYPE_DICTIONARY:
				continue
			for n in vd.get("add_nodes", []):
				if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) == node_id and String(n.get("aviso", "")) != "":
					d["aviso"] = String(n.aviso)
	return d

func _examine(node_id: String, b: Dictionary, sub := "") -> void:
	var sim = _sim()
	var repo = _repo()
	var nd := _node_def(node_id)
	var title := String(nd.get("noun", node_id.replace("_", " ")))
	var parsed: Dictionary = repo.parse_text(String(nd.get("examine", "")))
	var links: Array = []
	var dothis := String(b.get("do", ""))
	var ph := String(sim.q_clock().phase)
	# §4.4: abrir la tarjeta de un nodo con «aviso» (la ventana abierta, la cerradura rayada…) es notar la intrusión
	if String(nd.get("aviso", "")) != "":
		shell.act({"t": "examine", "ref": "hub/" + node_id})
	var view_doc := {}
	for v in sim.q_accessible():
		view_doc[String(v.get("view", ""))] = String(v.get("doc", ""))
	var docs: Array = Objects.docs_for(sim, repo, _place_def(cur_place), nd, b)
	var vias: Array = b.get("via", []) if typeof(b.get("via", [])) == TYPE_ARRAY else []
	var head := Widgets.t("shell.exam.leer_lista")
	# §6.4 el estante de la pieza: los papeles de casa y lo que falta («No está.»). GDD_v2 §C.1 (≤7 renglones a la vista):
	# las crónicas del cliente (vistas «@tomo», y la que falte) van a la vista; con más de 7 renglones, los demás papeles
	# de casa (notas de lectura, la Pall Mall, la prueba de imprenta, lo devuelto, y el que falte) van un nivel abajo, en
	# «Mis papeles» (ahí los busca el jugador).
	if vias.has("tome") and mode == "hub":
		head = Widgets.t("mundo.estante.cabeza")
		var top: Array = []
		var papers: Array = []
		for d in docs:
			var view0 := String(d.view)
			var lk := {"text": Widgets.t("shell.exam.leer", {"titulo": String(d.title)}), "short": String(d.title), "cb": func(): _read(view0)}
			if view0.ends_with("@tomo"):
				top.append(lk)
			else:
				papers.append(lk)
		# playtest v3: lo que falta va PRIMERO y a la vista (antes quedaba dentro de «Mis papeles», cortado en
		# «…jueves 2 de noviembre de 18...» sin que se leyera el «no está»), con un rótulo corto que empieza por «No está»
		if sim.has_method("q_missing"):
			var miss: Array = []
			for m in sim.q_missing():
				var cp := String(m.get("copy", ""))
				var fl := Widgets.t("mundo.estante.falta", {"titulo": short_title(String(m.get("title", cp)))})
				miss.append({"text": fl, "short": fl, "cb": func(): _missing(cp)})
			top = miss + top
		var group := Widgets.t("mundo.estante.papeles")
		if top.size() + papers.size() > 7 and papers.size() > 1 and top.size() > 6:
			papers = top.slice(6) + papers   # ≤7 renglones con «Mis papeles»: lo que no entra baja un nivel
			top = top.slice(0, 6)
		if top.size() + papers.size() <= 7 or papers.size() <= 1:
			links = top + papers
		elif sub == "papeles":
			head = group
			links = [{"text": Widgets.t("cam.tomos.volver"), "short": Widgets.t("cam.tomos.volver"), "cb": func(): _examine(node_id, b, "")}] + papers
		else:
			links = top + [{"text": group, "short": group, "cb": func(): _examine(node_id, b, "papeles")}]
		exam.show_card(title, parsed, links, {"kind": "node", "ref": cur_plate + "/" + node_id}, node_id, head)
		exam.set_scissors(scissors_on)
		return
	# §C.3 estantes y mostrador de Crane: lo más nuevo primero; con más de 4, en dos niveles (cada tanda de novedades y
	# «lo de siempre»)
	if (vias.has("shelf") or vias.has("counter")) and sim.has_method("q_stock"):
		var batches: Array = sim.q_stock()
		var tk_of := {}
		for bt in batches:
			for cp in bt.get("copies", []):
				tk_of[String(cp)] = int(bt.tk)
		docs.sort_custom(func(a, c):
			var ta := int(tk_of.get(String(a.view), -1))
			var tc := int(tk_of.get(String(c.view), -1))
			return ta > tc if ta != tc else String(a.title) < String(c.title))
		if docs.size() > EXAM_LINKS_MAX:
			var groups: Array = []
			for bt in batches:
				var items: Array = docs.filter(func(d): return int(tk_of.get(String(d.view), -1)) == int(bt.tk))
				if not items.is_empty():
					groups.append({"key": "s%d" % int(bt.tk), "label": Widgets.t("cam.estantes.tanda", {"dia": _day_label(int(bt.day))}), "items": items})
			var rest: Array = docs.filter(func(d): return not tk_of.has(String(d.view)))
			if not rest.is_empty():
				groups.append({"key": "resto", "label": Widgets.t("cam.estantes.resto"), "items": rest})
			if sub == "":
				for gr in groups:
					var gk := String(gr.key)
					links.append({"text": String(gr.label), "short": String(gr.label), "cb": func(): _examine(node_id, b, gk)})
				head = Widgets.t("cam.estantes.cabeza")
			else:
				links.append({"text": Widgets.t("cam.estantes.volver"), "short": Widgets.t("cam.estantes.volver"), "cb": func(): _examine(node_id, b, "")})
				for gr in groups:
					if String(gr.key) == sub:
						head = String(gr.label)
						for d in gr.items:
							var view2 := String(d.view)
							links.append({"text": Widgets.t("shell.exam.leer", {"titulo": String(d.title)}), "short": String(d.title), "cb": func(): _read(view2)})
			exam.show_card(title, parsed, links, {"kind": "node", "ref": cur_plate + "/" + node_id}, node_id, head)
			exam.set_scissors(scissors_on)
			return
	for d in docs:
		var view := String(d.view)
		var title_d := String(d.title)
		links.append({"text": Widgets.t("shell.exam.leer", {"titulo": title_d}), "short": title_d, "cb": func(): _read(view)})
		# copia certificada por correo (Somerset House, GDD §7.4–7.5): un verbo más de lo que se mira «de memoria» (W4: no
		# tenía ningún control y sólo se podía por la API)
		var did := String(view_doc.get(view, "")) if ph == "visit" else ""
		if did != "" and bool(sim.can({"t": "order_copy", "doc": did}).get("ok", false)):
			links.append({"text": Widgets.t("shell.copia.pedir", {"titulo": title_d, "precio": _price_text(_copy_price_d())}),
				"short": Widgets.t("shell.copia.corto"), "cb": func(): _ask_order_copy(did, title_d)})
	var note := ""
	if dothis == "compose" and binding_live("compose", ph):
		links.append_array(_compose_links(ph))
	elif dothis == "compose" and ph in ["night", "night_choice", "final_report"]:
		# playtest v3: de noche el tintero pasa a lupa; Lisle dice por qué ya no sirve
		var due: bool = sim.has_method("q_report_status") and bool(sim.q_report_status().get("due", false))
		note = Widgets.t("mundo.tintero.noche_informe" if due else "mundo.tintero.noche")
	if dothis == "sleep" and binding_live("sleep", ph):
		links.append({"text": Widgets.t("shell.cal.dormir"), "cb": func(): _ask_sleep()})
	exam.show_card(title, parsed, links, {"kind": "node", "ref": cur_plate + "/" + node_id}, node_id, head, note)
	exam.set_scissors(scissors_on)

# Título corto de un papel (hasta la primera coma, ≤44 letras): «Prueba de imprenta de «El problema final»».
static func short_title(t: String) -> String:
	var s := t.strip_edges()
	var k := s.find(", ")
	if k > 0:
		s = s.substr(0, k)
	if s.length() > 44:
		s = s.substr(0, 43).strip_edges() + "…"
	return s

# Un faltante del estante (§4.3–§4.4): Lisle lo busca, no está; tocarlo es notar la intrusión (acción libre examine).
func _missing(copy: String) -> void:
	if copy == "":
		return
	shell.act({"t": "examine", "ref": "missing/" + copy})
	shell.note(Widgets.t("mundo.estante.no_esta"))

# «martes 27» (etiqueta del día en schedule, en minúscula; "" si no está)
func _day_label(d: int) -> String:
	var repo = _repo()
	if repo == null:
		return ""
	for x in repo.schedule().get("days", []):
		if int(x.get("day", -1)) == d:
			var l := String(x.get("label", ""))
			return l.substr(0, 1).to_lower() + l.substr(1)
	return ""

func _copy_price_d() -> int:
	var repo = _repo()
	return int(repo.schedule().get("money_d", {}).get("somerset", 12)) if repo != null else 12

# «un chelín», «dos chelines», «seis peniques» (dinero de 1894 en palabras cortas, ui_text).
func _price_text(d: int) -> String:
	if d > 0 and d % 12 == 0:
		var n := d / 12
		return Widgets.t("shell.dinero.chelin") if n == 1 else Widgets.t("shell.dinero.chelines", {"n": n})
	return Widgets.t("shell.dinero.peniques", {"n": d})

func _ask_order_copy(did: String, title: String) -> void:
	exam.hide_card()
	var body := Widgets.t("shell.copia.cuerpo", {"titulo": title, "precio": _price_text(_copy_price_d())})
	_open_modal(body, Widgets.t("shell.copia.ok"), Widgets.t("kit.confirm.back"), Widgets.t("shell.copia.t"), func():
		var r: Dictionary = shell.act({"t": "order_copy", "doc": did})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
		else:
			shell.play("sfx.papel")
			shell.note(Widgets.t("shell.copia.hecho")))

# Lo que se puede escribir ahora (§C.1: nada visible que todavía no se pueda usar): el aviso si alguna forma se puede
# llenar (cmp.forma.*), telegrama y carta si hay un destino posible (cmp.telegrama, cmp.carta).
func _compose_links(ph: String, f := {}) -> Array:
	var out: Array = []
	if f.is_empty():
		f = ui_flags()
	if ph == "prologue" or ph == "desk":
		var any_form := true
		var seen := false
		for k in f:
			if String(k).begins_with("cmp.forma."):
				if not seen:
					any_form = false
					seen = true
				if bool(f[k]):
					any_form = true
		if any_form:
			out.append({"text": Widgets.t("shell.compose.ad"), "cb": func(): _compose("ad")})
	if ph == "desk":
		if _flag(f, "cmp.telegrama"):
			out.append({"text": Widgets.t("shell.compose.telegram"), "cb": func(): _compose("telegram")})
		if _flag(f, "cmp.carta"):
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
	if speech.showing() and not speech.queue.is_empty():
		speech.advance()   # playtest v3: primero las líneas que quedan (presentación del prólogo)
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
			if _confront_after_tray:
				if shell.is_open("tray"):
					shell.close_kind("tray")
				else:
					_confront_from_tray()
			else:
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
	# el correo sale al terminar el turno: se dice sólo si hay algo escrito sin mandar (playtest v2)
	var sim0 = _sim()
	var mail_out := false
	if sim0 != null and typeof(sim0.st.scenes) == TYPE_DICTIONARY:
		for m in sim0.st.scenes.get("mail", []):
			if typeof(m) == TYPE_DICTIONARY and not bool(m.get("sent", false)):
				mail_out = true
	if mail_out:
		body += " " + Widgets.t("shell.cal.correo")
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
	var sim = _sim()
	if sim != null:
		_tray_shown[int(sim.q_clock().day)] = true
	tray.open(-1)
	shell.push(tray, "tray")

# Día 10: cerrada la bandeja del amanecer, a la tienda (fundido) y la confrontación.
func _confront_from_tray() -> void:
	var sim = _sim()
	if sim == null or String(sim.q_clock().phase) != "confront" or not is_inside_tree():
		_confront_after_tray = false
		return
	if shell.is_busy() or _syncing:
		get_tree().create_timer(0.2).timeout.connect(_confront_from_tray)
		return
	_confront_after_tray = false
	shell.busy(true)
	await shell.fade_out()
	var c: Dictionary = sim.q_clock()
	var sc: Dictionary = sim.q_scene()
	_enter(c, sc)
	await shell.fade_in()
	shell.busy(false)
	_after_enter(c, sc, false)
	_refresh_hud(c)
	_sync_overlays()

# Leer desde el catálogo: el catálogo (capa de escena, sobre el lector) se aparta mientras se lee y vuelve después,
# si la visita a la Sala sigue.
func _read_from_catalog(v: String) -> void:
	if v == "":
		return
	shell.close_kind("catalog")
	if shell.open_reader(v):
		_catalog_after_read = true

func _on_panel_closed_kind(k: String) -> void:
	# prólogo: todo lo que piden Pell y Harris está sobre la mesa (encargo, tijera, tintero, calendario); al cerrar un
	# panel la vista vuelve al escritorio y no a la lámina entera, donde el tintero es un punto (playtest v2)
	var simp = _sim()
	if simp != null and String(simp.q_clock().phase) == "prologue" and mode == "plate" and shell.top() == null \
			and shell.world.rig.has_frame(TUTOR_FRAME) \
			and frame != TUTOR_FRAME:
		go_frame(TUTOR_FRAME)
	if k == "tray" and _confront_after_tray:
		_confront_from_tray.call_deferred()
		return
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
		# confrontación: con el puntero sobre la tienda (fuera de la afirmación y la banda), la tijera es la de la lámina
		if String(shell.top_kind()) == "confront" and (scissors_on or _pointer_on_world()):
			set_scissors(not scissors_on)
			return true
		if top.has_method("toggle_tijera"):
			top.toggle_tijera()
			return true
		if top.has_method("set_tijera") and "tijera" in top:
			top.set_tijera(not bool(top.tijera))
			return true
		return false
	set_scissors(not scissors_on)
	return true

func _pointer_on_world() -> bool:
	if not is_inside_tree():
		return false
	var h := get_viewport().gui_get_hovered_control()
	return h == null or h == exam or (exam != null and exam.is_ancestor_of(h))

# Tijera fuera del lector (C o el ícono de la tarjeta): recorta el texto de las tarjetas de examen y de las líneas dichas
# (GDD_v3 §6.2: todo lo del 3D se recorta del texto de su tarjeta). No hay rectángulo sobre el 3D.
func set_scissors(on: bool) -> void:
	if on and not _flag(ui_flags(), "desk.tijera"):
		on = false
	scissors_on = on
	if exam == null:
		return
	exam.set_scissors(on)
	speech.set_scissors(on)
	tutor.set_scissors(on)
	_scissors_cursor(on)
	# playtest v3: tomar la tijera no suena a «un corte de tijera» (no se cortó nada); el cursor ya lo dice
	_sync_overlays()

var _scissors_cur := false
func _scissors_cursor(on: bool) -> void:
	if on == _scissors_cur or DisplayServer.get_name() == "headless":
		_scissors_cur = on
		return
	_scissors_cur = on
	Input.set_custom_mouse_cursor(Cursors.scissors() if on else null, Input.CURSOR_IBEAM, Vector2(6, 6))

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
# Volver ANTES de la pila (InputRouter): lo que está por encima de todo panel o es un modo de la mano. La confirmación
# propia (capa 60) se cierra; la tijera sobre el 3D se deja (W4: con la banda de escena abierta el clic derecho cerraba
# la banda y la tijera seguía en la mano, y cada clic en un objeto o personaje no hacía nada); la tarjeta de examen se
# cierra antes que la banda que está debajo.
func front_back() -> bool:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
		_modal = null
		return true
	if shell == null:
		return false
	var tk := String(shell.top_kind())
	var bare := tk == "" or BAND_PANELS.has(tk)
	if not bare:
		return false
	if scissors_on:
		set_scissors(false)
		return true
	if exam != null and exam.visible:
		exam.hide_card()
		return true
	return false

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
	return false

func shortcut_panel(kind: String) -> bool:
	var sim = _sim()
	if sim == null or shell.is_busy():
		return false
	# v3 (§5.4, §6.4): el plano sólo desde la pared de la buhardilla (no hay tecla ni cinta); acá, el cuaderno (Tab) y el
	# expediente (E), en cualquier lugar (sus cintas del HUD sólo fuera de la buhardilla: en casa están sobre la mesa)
	if kind == "notebook" or kind == "dossier":
		if kind == "dossier" and not _flag(ui_flags(), "desk.expediente"):
			return false
		exam.hide_card()
		if scissors_on:
			set_scissors(false)
		# el lector es a pantalla completa (capa 30): un libro (capa 20) quedaría debajo; se deja la hoja y se abre el libro
		if shell.reader_open() and not shell.is_open(kind):
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
