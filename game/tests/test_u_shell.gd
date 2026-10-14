# Tests de W3-SHELL / UI-MUNDO (ARCHITECTURE §2.3, §6.1, §6.3, §6.7; GDD§5, §7.1, §14; GDD_v3 §5.4, §6.4): arranque
# (args), capas, HUD, pila de paneles, atajos (Tab/E/C/Esc; sin M ni L), el plano desde la pared (persianas sin clic,
# viaje pieza -> lugar -> pieza), visita, volver, franjas, noche, dormir, amanecer y bandeja, cintas del HUD sólo fuera
# de la buhardilla, arrastre 2D -> 3D para presentar (DropCatcher3D con el pick real del diorama), --script y --screen.
# Headless, sobre la Shell real y el autoload Game con el dataset «fixture» (data/ estructural + tests/fixtures/integ,
# armado una vez por proceso por tests/fixtures/w3shell/walk.gd). Capturas: devtools/drivers/w3shell_flujo.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 150
const MainScript = preload("res://main.gd")
const Shell = preload("res://ui/shell.gd")
const Layers = preload("res://ui/layers.gd")
const DeskHud = preload("res://ui/desk/desk_hud.gd")
const Objects = preload("res://ui/desk/objects.gd")
const Chips = preload("res://ui/drag/chips.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")

var sh = null
var g = null
var old_size := Vector2i.ZERO

class Dummy extends Control:
	signal closed
	var closes := 0
	var backs := 0
	var back_ret := false
	func close() -> void:
		closes += 1
		visible = false
		closed.emit()
	func back() -> bool:
		backs += 1
		return back_ret

class FakeWorld extends RefCounted:
	var hit := ""
	func pick_character(_p: Vector2) -> String:
		return hit

func before_each() -> void:
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)
	g = tree.root.get_node("Game")
	W.errs = []

func after_each() -> void:
	if g != null and g.sim != null:
		g.end_session()
	if sh != null and is_instance_valid(sh):
		sh.free()
	sh = null
	if g != null:
		g.repo_override = null
		g.save_path = g.SAVE_PATH
	if tree.root.gui_is_dragging():
		tree.root.gui_cancel_drag()
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

# ------------------------------------------------------------------ utilidades
func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

func settle(max_frames := 900) -> void:
	for i in max_frames:
		await tree.process_frame
		if i < 3:
			continue
		var gs = sh.game_screen if sh != null else null
		if sh != null and not sh.is_busy() and (gs == null or gs.idle()):
			return
	fail("la Shell no quedó quieta")

func act(a: Dictionary) -> Dictionary:
	return g.act(a)

func boot_game(extra := {}) -> void:
	g.repo_override = W.repo()
	ok(g.repo_override != null, "dataset fixture")
	if g.repo_override != null:
		eq((g.repo_override.errors() as Array).slice(0, 6), [], "dataset fixture sin errores")
	var opts := {"new": true, "seed": 1894, "fast": true, "mute": true, "save": tmp_dir().path_join("partida.jsonl")}
	opts.merge(extra, true)
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(1)
	await sh.boot(opts)
	await settle()

func confirm(m) -> bool:
	if m == null:
		return false
	var c = m
	if not c.has_signal("decided"):
		for ch in m.find_children("*", "", true, false):
			if ch.has_signal("decided"):
				c = ch
				break
	if not c.has_signal("decided"):
		return false
	c.decided.emit(true)
	return true

func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e

# Eventos por Input (como el mouse real): el destino de un arrastre se resuelve con la posición del mouse de Input.
func motion(p: Vector2) -> void:
	Input.warp_mouse(p)
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func release(p: Vector2) -> void:
	Input.warp_mouse(p)
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func click_marker(m: Control) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	m._gui_input(e)

func phase() -> String:
	return String(g.sim.q_clock().phase)

# ------------------------------------------------------------------ puros
func test_parse_args() -> void:
	var o: Dictionary = MainScript.parse_args(["--new", "--seed=42", "--script=res://x.jsonl", "--screen=place:L4.consulta", "--fast", "--mute", "--data=fixture", "--save=user://a.jsonl", "--raro"])
	ok(o.new and o.fast and o.mute and not o["continue"], "banderas")
	eq(o.seed, 42)
	eq(o.script, "res://x.jsonl")
	eq(o.screen, "place:L4.consulta")
	eq(o.data, "fixture")
	eq(o.save, "user://a.jsonl")
	var e: Dictionary = MainScript.parse_args([])
	ok(not e.new and not e["continue"] and e.screen == "" and e.seed == 0, "sin argumentos: título")
	ok(MainScript.parse_args(["--continue"])["continue"], "--continue")

func test_layers_and_hud() -> void:
	eq([Layers.DROP, Layers.HUD, Layers.BOOKS, Layers.READER, Layers.SCENE, Layers.MAP, Layers.MODAL, Layers.SUBS, Layers.FADE, Layers.DRAG],
		[5, 10, 20, 30, 40, 50, 60, 90, 100, 120], "capas del contrato §2.3")
	eq(DeskHud.money(0), Widgets.t("shell.money.d", {"n": 0}), "0 peniques")
	eq(DeskHud.money(474), "%s %s %s" % [Widgets.t("shell.money.l", {"n": 1}), Widgets.t("shell.money.s", {"n": 19}), Widgets.t("shell.money.d", {"n": 6})], "£1 19s. 6d.")
	eq(DeskHud.money(252), "%s %s" % [Widgets.t("shell.money.l", {"n": 1}), Widgets.t("shell.money.s", {"n": 1})], "sin componentes en cero")
	var h := DeskHud.new()
	tree.root.add_child(h)
	await frames(1)
	h.refresh({"day": 1, "slot": "M", "phase": "desk", "weekday": "mar", "coins_d": 474}, {"date": "1894-03-27", "weekday": "mar"})
	eq(h.day_label.text, "27")
	eq(h.wd_label.text, Widgets.t("core.wd.mar"))
	ok(h.month_label.text.contains(Widgets.t("core.mes.3")), "mes: " + h.month_label.text)
	eq(h.slot_label.text, Widgets.t("shell.hud.franja", {"franja": Widgets.t("core.slot.M"), "horas": Widgets.t("core.slot_horas.M")}))
	eq(h.coins_label.text, DeskHud.money(474))
	h.refresh({"day": 1, "slot": "N", "phase": "night", "coins_d": 0}, {"date": "1894-03-27", "weekday": "mar"})
	eq(h.slot_label.text, Widgets.t("core.slot.night"), "de noche, sin las horas de la franja N")
	var hits := []
	h.calendar_pressed.connect(func(): hits.append(1))
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	h.card.gui_input.emit(e)
	eq(hits.size(), 1, "clic en el calendario")
	h.free()

func test_map_json_and_objects() -> void:
	var r = repo()
	var mp: Dictionary = r.map()
	ok(mp.has("places") and mp.has("streets") and mp.has("river") and mp.has("objects"), "map.json completo")
	var sz: Array = mp.size_mm
	for id in mp.places:
		ok(not r.place(String(id)).is_empty(), "lugar del mapa existe: " + String(id))
		var xy: Array = mp.places[id].xy
		ok(float(xy[0]) >= 0 and float(xy[0]) <= float(sz[0]) and float(xy[1]) >= 0 and float(xy[1]) <= float(sz[1]), "dentro de la hoja: " + String(id))
	for id in r.places():
		ok(mp.places.has(id), "todo lugar tiene marcador: " + String(id))
	var homes: Array = mp.places.keys().filter(func(k): return bool(mp.places[k].get("home", false)))
	eq(homes, ["L1"], "una sola casa")
	var dos := ["tray", "map", "notebook", "dossier", "scissors", "calendar", "compose", "sleep", "catalog", "go", "leave", "docs"]
	for pid in mp.objects:
		if String(pid).begins_with("_"):
			continue
		var pl: Dictionary = r.place(String(pid))
		if pl.is_empty():
			pl = r.plate(String(pid))
		ok(not pl.is_empty() or String(pid) == "*", "objetos de un lugar o lámina existente: " + String(pid))
		var node_ids := {}
		for n in pl.get("nodes", []):
			node_ids[String(n.get("id", ""))] = true
		for nid in mp.objects[pid]:
			var b: Dictionary = mp.objects[pid][nid]
			has(dos, String(b.get("do", "")), "acción conocida %s/%s" % [pid, nid])
			if not String(nid).ends_with("*") and not node_ids.is_empty() and not node_ids.has(String(nid)):
				fail("nodo inexistente %s/%s" % [pid, nid])
	# GDD_v3 §6.3–§6.4: una sola forma de hacer cada cosa
	for pid in ["L1", "PRO", "M7"]:
		for gone in ["pliegos", "calendario", "tijera", "cama", "sello", "escritorio", "atril", "ventana", "libro_mayor"]:
			no((mp.objects.get(pid, {}) as Dictionary).has(gone), "%s/%s ya no se usa (sólo se mira o no es interactivo)" % [pid, gone])
	eq(String(Objects.binding(r, "L1", "tintero").get("do", "")), "compose", "sólo el tintero escribe")
	eq(String(Objects.binding(r, "L1", "mapa").get("do", "")), "map", "el plano, en la pared")
	eq(String(Objects.binding(r, "L1", "expediente").get("do", "")), "dossier", "la carpeta del expediente")
	eq(String(Objects.binding(r, "L1", "estantes_1").get("do", "")), "docs", "comodín estantes_*")
	eq(String(Objects.binding(r, "PRO", "bandeja").get("do", "")), "tray")
	ok(Objects.binding(r, "L5", "nada_de_nada").is_empty(), "sin vínculo: sólo examinar")

func test_stack_protocol() -> void:
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(2)
	var root := Layers.root_of(sh.layers.books)
	var a := Dummy.new()
	var b := Dummy.new()
	var c := Dummy.new()
	for d in [a, b, c]:
		root.add_child(d)
	sh.push(a, "a")
	sh.push(b, "b")
	eq(sh.top(), b)
	sh.push(c, "c")
	eq(sh.stack.size(), 2, "a lo sumo 2 paneles apilados")
	eq(a.closes, 1, "al abrir un tercero se cierra el de abajo")
	eq(sh.top_kind(), "c")
	c.back_ret = true
	ok(sh.pop(), "pop consumido por back()")
	eq([c.backs, c.closes], [1, 0])
	eq(sh.top(), c)
	c.back_ret = false
	ok(sh.pop())
	eq(c.closes, 1, "pop cierra el de arriba")
	eq(sh.top(), b)
	b.visible = false
	await frames(1)
	eq(sh.top(), null, "un panel que se oculta solo sale de la pila")
	no(sh.pop(), "pila vacía")
	eq(sh.open_panel("nada"), null, "clase desconocida")
	sh.busy(true)
	eq(sh.open_panel("map"), null, "en transición no se abren paneles")
	ok(sh.router.shortcut("fe_expediente"), "el atajo se consume durante una transición")
	sh.busy(false)
	sh.note("uno")
	sh.note("dos")
	sh.note("tres")
	sh.note("tres")
	eq(sh.notes(), ["dos", "tres"], "dos avisos de Lisle a la vista como mucho, sin repetidos")
	eq(sh.err_text("cerrado"), Widgets.t("sim.err.cerrado"))
	eq(sh.err_text("zzz_desconocido"), Widgets.t("core.err.desconocido"))

func test_drop_catcher_and_drag_layer() -> void:
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(2)
	var dc = sh.drop_catcher
	var fw := FakeWorld.new()
	fw.hit = "watson"
	dc.world = fw
	var ph := ["desk"]
	dc.phase_fn = func(): return ph[0]
	var src := Control.new()
	src.size = Vector2(40, 20)
	Layers.root_of(sh.layers.hud).add_child(src)
	var data := Chips.data("clip", "RC0001")
	ok(Chips.presentable(data) and not Chips.presentable(Chips.data("ent", "x")) and not Chips.valid({"kind": "clip"}), "datos de arrastre")
	eq(dc.mouse_filter, Control.MOUSE_FILTER_IGNORE, "inactivo fuera de un arrastre")
	src.force_drag(data, Widgets.chip("«x»", data))
	await frames(2)
	no(dc.armed, "en el escritorio no se presenta")
	eq(dc.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	ok(sh.drag_layer.dragging(), "DragLayer sigue el arrastre")
	ok(sh.drag_layer.adopted(), "la vista previa nativa pasa a la capa 120 (un solo chip, encima de todo)")
	tree.root.gui_cancel_drag()
	await frames(2)
	no(sh.drag_layer.dragging())
	ph[0] = "visit"
	src.force_drag(data, Widgets.chip("«x»", data))
	await frames(2)
	ok(dc.armed, "en una visita el 3D recibe")
	eq(dc.mouse_filter, Control.MOUSE_FILTER_STOP)
	ok(dc._can_drop_data(Vector2(800, 400), data), "sobre un personaje")
	no(dc._can_drop_data(Vector2(800, 400), Chips.data("ent", "watson")), "una entidad del índice no se presenta")
	fw.hit = ""
	no(dc._can_drop_data(Vector2(800, 400), data), "fuera de un personaje")
	fw.hit = "watson"
	var got := []
	dc.present_requested.connect(func(cid, d): got.append([cid, d]))
	motion(Vector2(800, 400))
	await frames(2)
	release(Vector2(800, 400))
	await frames(3)
	eq(got.size(), 1, "soltar sobre el personaje pide presentar")
	if got.size() == 1:
		eq(got[0][0], "watson")
		eq(got[0][1], data)
	no(dc.armed, "al terminar el arrastre")
	eq(dc.mouse_filter, Control.MOUSE_FILTER_IGNORE)

# ------------------------------------------------------------------ flujo de juego
func test_flow_prologue_visit_night_dawn() -> void:
	await boot_game()
	var gs = sh.game_screen
	ok(gs != null, "pantalla de juego")
	if gs == null:
		return
	eq(phase(), "prologue")
	eq(gs.state().mode, "plate", "prólogo: lámina")
	eq(gs.cur_plate, "PL.prologo")
	eq(gs.hud.day_label.text, "26")
	no(gs.tutor.visible and gs.speech.visible, "la nota del instructor espera a que termine la presentación")
	for i in 40:
		if not gs.speech.visible:
			break
		# verificador v3: «Seguir» a la vista en cada línea, también en la última (si no, nada decía cómo seguir)
		ok(gs.speech.more.visible, "«Seguir» a la vista (%d)" % i)
		gs.speech.advance()
	await frames(2)
	ok(gs.tutor.visible, "nota del instructor")
	var n0: int = g.sim.actions_log().size()
	gs.calendar()
	eq(gs.modal(), null, "antes de completar el tutorial no se duerme")
	eq(g.sim.actions_log().size(), n0)
	var t: Dictionary = W.tutorial(g.sim, act)
	eq(W.errs, [], "tutorial")
	await settle()
	gs.calendar()
	ok(gs.modal() != null, "dormir: confirmación en dos pasos")
	ok(confirm(gs.modal()))
	await settle()
	var c: Dictionary = g.sim.q_clock()
	eq([int(c.day), String(c.slot), String(c.phase)], [1, "M", "desk"], "amanecer -> escritorio del martes")
	eq(gs.state().mode, "hub")
	eq(gs.hud.day_label.text, "27")
	ok(sh.is_open("tray"), "la bandeja se abre sola: la mañana es la respuesta")
	ok(sh.panel("tray").list.get_child_count() >= 1, "lo llegado está en la bandeja")
	# atajos (GDD_v3 §6.4): Tab, E, C; sin cintas en la buhardilla (todo está sobre la mesa)
	ok(sh.router.shortcut("fe_volver"))
	no(sh.is_open("tray"), "Esc cierra la bandeja")
	no(gs.hud.books_box.visible, "en la buhardilla no hay cintas en el HUD")
	ok(sh.router.shortcut("fe_cuaderno"))
	ok(sh.is_open("notebook"), "Tab: cuaderno")
	ok(sh.router.shortcut("fe_expediente"))
	ok(sh.is_open("dossier"), "E: expediente")
	ok(sh.stack.size() <= 2, "nunca más de 2 paneles")
	sh.close_all()
	await settle()
	no(sh.router.shortcut("fe_mapa"), "M ya no hace nada (el plano está en la pared)")
	no(sh.is_open("map"))
	ok(sh.router.shortcut("fe_tijera"))
	ok(gs.scissors_on, "C: la tijera en la mano (para las tarjetas)")
	ok(sh.router.shortcut("fe_volver"))
	no(gs.scissors_on, "Esc deja la tijera")
	# un clic en el expediente lo abre en el acto
	gs.on_node("expediente")
	await frames(2)
	ok(sh.is_open("dossier"), "clic en la carpeta: el expediente")
	sh.close_all()
	await settle()
	# el plano de la pared -> Kensington (consulta) -> visita con Watson
	gs.on_node("mapa")
	await frames(2)
	ok(sh.is_open("map"), "clic en el plano de la pared: el plano")
	var ms = sh.panel("map")
	var mk = ms.marker("L4")
	ok(mk != null and mk.is_open(), "Kensington abierto por la mañana")
	ms._on_marker(mk)
	ok(ms._popup != null, "dos áreas: tarjeta de áreas")
	var consulta := {}
	for a in ms.place_state("L4").areas:
		if String(a.area) == "consulta":
			consulta = a
	ms._confirm_go(consulta)
	ok(confirm(ms._popup), "confirmación del viaje")
	await settle()
	eq(phase(), "visit")
	eq(gs.cur_place, "L4")
	eq(gs.state().mode, "plate", "visita: diorama")
	no(sh.is_open("map"), "el mapa se cierra al llegar")
	ok(sh.is_open("scene"), "Watson en la consulta: panel de escena")
	ok(sh.world.input_enabled, "con la banda de la escena se sigue mirando y tocando el diorama")
	ok(gs.hud.books_box.visible, "fuera de casa, las cintas «Cuaderno» y «Expediente»")
	# presentar por arrastre al 3D (pick real del diorama)
	for i in 30:
		if sh.world.is_plate_ready():
			break
		await tree.physics_frame
	await tree.physics_frame
	var pos: Vector2 = gs.char_screen_pos("watson")
	ok(pos.x >= 0.0 and pos.y >= 0.0, "Watson en pantalla: %s" % str(pos))
	eq(sh.drop_catcher.char_at(pos), "watson", "el 3D resuelve al personaje bajo el cursor")
	var src := Control.new()
	src.size = Vector2(30, 20)
	Layers.root_of(sh.layers.hud).add_child(src)
	var data := Chips.data("clip", String(t.aviso))
	var got := []
	sh.drop_catcher.present_requested.connect(func(cid, _d): got.append(cid))
	src.force_drag(data, Widgets.chip("«x»", data))
	await frames(2)
	ok(sh.drop_catcher.armed, "DropCatcher3D activo durante el arrastre en la visita")
	motion(pos)
	await frames(2)
	release(pos)
	await frames(4)
	eq(got, ["watson"], "soltar sobre Watson pide presentar")
	var sp = sh.panel("scene")
	if sp != null and "present_bar" in sp and sp.present_bar != null:
		ok(sp.present_bar.visible, "segundo paso: la frase de Lisle con «Mostrar» / «Guardar»")
	src.queue_free()
	if sp != null and "present_bar" in sp and sp.present_bar != null and sp.present_bar.visible:
		sp.present_bar.keep()
	# leer durante la visita: la banda de la escena baja bajo el lector y vuelve al cerrarlo
	ok(sh.open_view(sh.panel("map").baedeker_view()), "la página Baedeker se abre en el lector")
	eq(sh.panel("scene").layer, Layers.READER - 1, "la banda de la escena queda debajo del lector")
	ok(sh.is_open("scene"), "y sigue abierta")
	ok(sh.router.shortcut("fe_volver"))
	no(sh.reader_open())
	eq(sh.panel("scene").layer, Layers.SCENE, "al cerrar el lector vuelve a su capa")
	# volver a casa (confirmación) -> escritorio con la salida hecha
	gs._leave(false)
	ok(gs.modal() != null, "volver: confirmación")
	ok(confirm(gs.modal()))
	await settle()
	c = g.sim.q_clock()
	eq([String(c.phase), bool(c.outing_done)], ["desk", true], "de vuelta en el escritorio")
	eq(gs.state().mode, "hub")
	eq(gs.state().frame, "escritorio", "al volver, la buhardilla mirando el escritorio (GDD_v3 §5.4: pieza -> lugar -> pieza)")
	no(gs.back(), "en el escritorio no hay nada que volver")
	# láminas archivadas (GDD§5): se vuelven a mirar y a recortar desde el mapa
	var ap: Array = sh.archived_plates().map(func(x): return String(x.id))
	ok(ap.has("PL.L4.1.M") and ap.has("PL.prologo"), "láminas archivadas: %s" % str(ap))
	eq(ap[0], "PL.L4.1.M", "la más reciente primero")
	sh.open_panel("map")
	await frames(2)
	var msl = sh.panel("map")
	msl.open_plates()
	await frames(2)
	var bt: Button = null
	for b in msl.find_children("Lamina_*", "Button", true, false):
		if String(b.get_meta("plate", "")) == "PL.L4.1.M":
			bt = b
	ok(bt != null, "la lámina de Kensington en la lista")
	if bt != null:
		bt.pressed.emit()
		await settle()
		no(sh.is_open("map"), "elegir una lámina cierra el mapa")
		ok(gs._doc_plate and gs.cur_plate == "PL.L4.1.M", "la lámina en el 3D: %s" % gs.cur_plate)
		ok(gs._leave_btn.visible and gs._leave_btn.text == Widgets.t("shell.nav.lamina"), "«Dejar la lámina» con el mouse")
		var nodes: Array = g.sim.q_plate("PL.L4.1.M").nodes
		var n0c: int = g.sim.q_clips().size()
		var rc: Dictionary = act({"t": "clip_plate", "plate": gs.cur_plate, "hits": [{"node": String(nodes[0]), "cover": 0.9, "tight": true}], "touched": [String(nodes[0])], "area_frac": 0.05})
		ok(bool(rc.get("ok", false)), "se recorta en la lámina archivada: %s" % str(rc))
		eq(g.sim.q_clips().size(), n0c + 1)
		ok(gs.back(), "volver deja la lámina")
		no(gs._doc_plate)
		eq(gs.state().mode, "hub")
	# un recorte de lámina en el cuaderno (doble clic -> su ejemplar) abre la lámina
	sh._on_source_requested("RC0001", "PL.prologo")
	await settle()
	ok(gs._doc_plate and gs.cur_plate == "PL.prologo", "doble clic en un recorte de lámina: la lámina")
	gs._on_leave_btn()
	await settle()
	no(gs._doc_plate)
	sh._on_source_requested("RC0001", "D23@L1")
	await settle()
	no(gs._doc_plate, "un documento no es una lámina")
	# mapa con la salida hecha: todo con persiana, ningún clic gasta nada (T26 en la UI)
	sh.open_panel("map")
	await frames(2)
	ms = sh.panel("map")
	var n1: int = g.sim.actions_log().size()
	for m in ms.markers.get_children():
		if m.home:
			continue
		no(m.is_open(), "persiana: " + String(m.place_id))
		click_marker(m)
	eq(g.sim.actions_log().size(), n1, "ningún clic sobre una persiana actúa")
	ok(ms._popup == null or not is_instance_valid(ms._popup), "ni abre nada")
	eq(ms.status.text, Widgets.t("shell.map.ya_salio"))
	sh.close_kind("map")
	# cerrar franjas con el calendario: M -> T -> N -> noche
	for s in ["T", "N", "night"]:
		gs.calendar()
		ok(confirm(gs.modal()), "cerrar la franja")
		await settle()
		c = g.sim.q_clock()
		eq(String(c.slot) if s != "night" else String(c.phase), s)
	ok(gs.hud.slot_label.text.begins_with(Widgets.t("core.slot.night")), "calendario: noche")
	# dormir -> ritual del amanecer -> miércoles
	gs.calendar()
	ok(confirm(gs.modal()), "dormir")
	await settle()
	c = g.sim.q_clock()
	eq([int(c.day), String(c.phase)], [2, "desk"], "miércoles por la mañana")
	eq(gs.hud.day_label.text, "28")

# GDD_v3 §4.3–§4.4, §6.8 (UI-MUNDO): la pieza con la ventana abierta por los techos. Al entrar suena la corriente (una
# vez por entrada); abrir la tarjeta de un nodo con «aviso» es notar la intrusión (acción libre examine, nace Q8); el
# estante lista lo que falta («no está») y tocarlo también la nota.
func test_intrusion_nodes_and_missing_on_the_shelf() -> void:
	await boot_game()
	var gs = sh.game_screen
	W.tutorial(g.sim, act)
	act({"t": "sleep"})
	await settle()
	sh.close_all()
	await settle()
	eq(phase(), "desk")
	var pl: Dictionary = g.sim.repo.place("L1")
	if not (pl.get("variants", {}) as Dictionary).has("techos"):
		pending_content("L1 sin la variante «techos» (REACCIONES)")
		return
	var now := int(g.sim.q_clock().tk)
	g.sim.st.world.place_variants["L1"] = "techos"
	g.sim.st.world.copies["D03@tomo"] = {"from_tk": now - 1, "until_tk": now + 30}
	var lay := {"variant": "techos", "from_tk": now, "to_tk": now + 20, "rid": "HA5"}
	g.sim.st.react.world.variants["L1"] = {"variant": "techos", "from_tk": now, "to_tk": now + 20, "rid": "HA5", "layers": [lay]}
	gs._techos_heard = {}
	gs.techos_played = 0
	gs._show_hub("general", g.sim.q_clock())
	await frames(4)
	ok(sh.world.node_body("ventana_abierta") != null, "la ventana abierta (nodo de la variante)")
	eq(gs.techos_played, 1, "al entrar con «techos», la corriente de aire")
	gs._show_hub("general", g.sim.q_clock())
	eq(gs.techos_played, 1, "una vez por intrusión: no se repite al volver a entrar")
	var x0: Transform3D = sh.world.camera().global_transform
	gs.on_node("ventana_abierta")
	await frames(3)
	ok(gs.exam.visible, "su tarjeta")
	ok(String(gs.exam.title_label.text).length() > 0, "con su nombre")
	ok(sh.world.camera().global_transform.is_equal_approx(x0), "sin mover la cámara")
	var noticed = g.sim.st.ded.get("dossier", {}).get("noticed", {})
	ok(typeof(noticed) == TYPE_DICTIONARY and (noticed as Dictionary).has("HA5"), "abrir la tarjeta es notar la intrusión: %s" % str(noticed))
	gs.exam.hide_card()
	# el estante: lo que falta
	if g.sim.q_missing().is_empty():
		pending_content("q_missing() vacío con un original retirado (CORE)")
		return
	gs.on_node("estante")
	await frames(3)
	ok(gs.exam.visible, "la tarjeta del estante")
	var falta: Button = null
	for b in (gs.exam.links_box.get_children() + gs.exam.links_list.get_children()):
		if b is Button and String(b.text).begins_with(Widgets.t("mundo.estante.falta", {"titulo": ""}).strip_edges()):
			falta = b
	ok(falta != null, "lo que falta, con «No está»")
	if falta != null:
		falta.pressed.emit()
		await frames(2)
		has(sh.notes(), Widgets.t("mundo.estante.no_esta"), "«No está. La dejé acá anoche.»")

# GDD_v3 §6.4 + GDD_v2 §C.1 (verificador UI-MUNDO): la tarjeta del estante nunca muestra más de 7 renglones; las crónicas
# del cliente quedan a la vista y, si no entran, los demás papeles de casa van un nivel abajo («Mis papeles» / «Volver»).
func test_shelf_card_two_levels() -> void:
	await boot_game()
	var gs = sh.game_screen
	W.tutorial(g.sim, act)
	act({"t": "sleep"})
	await settle()
	sh.close_all()
	await settle()
	eq(phase(), "desk")
	var btns := func() -> Array:
		return (gs.exam.links_box.get_children() + gs.exam.links_list.get_children()).filter(func(x): return x is Button and not x.is_queued_for_deletion())
	gs.on_node("estante")
	await frames(3)
	ok(gs.exam.visible, "la tarjeta del estante")
	var top: Array = btns.call()
	ok(top.size() <= 7, "≤7 renglones a la vista (%d)" % top.size())
	var fina := false
	var grp: Button = null
	for x in top:
		if String(x.text).begins_with("«El problema final»") or String(x.text).contains("«El problema final»"):
			fina = true
		if String(x.text) == Widgets.t("mundo.estante.papeles"):
			grp = x
	ok(fina, "«El problema final» a la vista, sin un clic de más")
	if grp == null:
		ok(top.size() <= 7, "todo entra en un nivel")
		return
	grp.pressed.emit()
	await frames(3)
	var sub: Array = btns.call()
	ok(sub.size() >= 3 and sub.size() <= 8, "«Mis papeles»: Volver y los papeles (%d)" % sub.size())
	eq(String(sub[0].text), Widgets.t("cam.tomos.volver"), "primero, «Volver»")
	var leer := 0
	for x in sub:
		if not String(x.text).contains("«El problema final», The Strand"):
			leer += 1
	ok(leer == sub.size(), "las crónicas no se repiten abajo")
	sub[0].pressed.emit()
	await frames(3)
	eq(btns.call().size(), top.size(), "«Volver» deja el primer nivel como estaba")

func test_sunday_shutters() -> void:
	await boot_game()
	W.tutorial(g.sim, act)
	act({"t": "sleep"})
	ok(W.advance_to(g.sim, act, 6, "T"), "domingo 1 de abril, tarde: %s" % str(W.errs))
	await settle()
	eq(String(g.sim.q_clock().weekday), "dom")
	sh.open_panel("map")
	await frames(2)
	var ms = sh.panel("map")
	var n0: int = g.sim.actions_log().size()
	var closed := 0
	for p in g.sim.q_places():
		if bool(p.get("free", false)):
			continue
		var st: Dictionary = ms.place_state(String(p.id))
		var m = ms.marker(String(p.id))
		if not ms.shown(String(p.id)):
			eq(m, null, "lugar todavía no conocido: sin marcador " + String(p.id))
			continue
		ok(m != null, "marcador " + String(p.id))
		eq(m.is_open(), bool(st.open), "estado del marcador = q_places: " + String(p.id))
		if not m.is_open():
			closed += 1
			click_marker(m)
	ok(closed >= 2, "el domingo hay persianas (Sala de Lectura, Somerset House): %d" % closed)
	eq(g.sim.actions_log().size(), n0, "T26: ningún clic sobre un lugar cerrado gasta la franja")
	var l2 = ms.marker("L2")
	no(l2.is_open(), "la Sala de Lectura cierra el domingo")
	ms._on_hover(l2, true)
	ok(ms._hover.visible, "el motivo se lee al pasar el mouse")
	# GDD_v3 §5.3: «qué hay», «por qué está» y el horario; cerrado, además «Cerrado ahora» (GDD_v2 §C.3)
	ok(ms._hover.text.replace(String.chr(10), " ").begins_with(Widgets.t("plano.que_hay.L2")), "primero, qué hay: " + ms._hover.text)
	ok(ms._hover.text.contains(Widgets.t("prog.map.cerrado_ahora")), ms._hover.text)
	ok(ms._hover.text.contains(String(g.sim.repo.map().places.L2.hours)), "el horario de la Sala: " + ms._hover.text)
	var r: Dictionary = await ms.travel("L2", "sala", 214)
	no(bool(r.get("ok", true)), "el sim rechaza el viaje a un lugar cerrado")
	eq(g.sim.actions_log().size(), n0, "y no queda registrado")
	no(sh.is_busy(), "sin transición colgada")

func test_esc_options_and_typing() -> void:
	await boot_game()
	var gs = sh.game_screen
	gs.speech.clear()
	gs.exam.hide_card()
	# GDD_v3 §6.6: sin posiciones intermedias de la cámara; Esc o clic derecho cierran el panel abierto y, con nada
	# abierto, abren las Opciones
	sh.router._unhandled_input(key(KEY_ESCAPE))
	eq(sh.top_kind(), "options", "Esc sin nada que cerrar: Opciones (con «Volver al título»)")
	sh.router._unhandled_input(key(KEY_ESCAPE))
	eq(sh.top_kind(), "", "Esc cierra las Opciones")
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	sh.router._input(rc)
	eq(sh.top_kind(), "options", "el clic derecho sin nada abierto: Opciones")
	sh.router._input(rc)
	eq(sh.top_kind(), "", "y las cierra")
	var le := LineEdit.new()
	Layers.root_of(sh.layers.modal).add_child(le)
	le.grab_focus()
	await frames(1)
	sh.router._input(key(KEY_TAB))
	no(sh.is_open("notebook"), "Tab escribiendo en un campo no abre el cuaderno")
	le.release_focus()
	le.queue_free()
	await frames(1)
	sh.router._input(key(KEY_TAB))
	ok(sh.is_open("notebook"), "Tab: cuaderno")
	sh.router._input(key(KEY_TAB))
	no(sh.is_open("notebook"), "Tab otra vez lo cierra")
	var nb = sh.panel("notebook")
	eq(nb.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED, "mientras se va (fundido) no recibe clics")
	await tree.create_timer(0.6).timeout
	eq(nb.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED, "después se restituye")

func test_script_and_screen_args() -> void:
	var r = W.repo()
	var sim0 = GameSim.new(r, 1894)
	W.tutorial(sim0, func(a): return sim0.apply(a))
	sim0.apply({"t": "sleep"})
	eq(W.errs, [], "guion")
	var path := tmp_dir().path_join("guion.jsonl")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(W.jsonl(sim0.actions_log()))
	f.close()
	# el guion de las capturas (tests/fixtures/w3shell/guion_dia1.jsonl) sigue siendo válido sobre el dataset fixture
	var sim1 = GameSim.new(r, 1894)
	var n_ok := 0
	var lines := FileAccess.get_file_as_string("res://tests/fixtures/w3shell/guion_dia1.jsonl").split(char(10))
	for ln in lines:
		if ln.strip_edges() == "" or ln.begins_with("#"):
			continue
		var res: Dictionary = sim1.apply(J.parse_str(ln))
		if bool(res.get("ok", false)):
			n_ok += 1
		else:
			fail("guion_dia1: %s -> %s" % [ln, str(res.get("err", ""))])
	ok(n_ok >= 4, "guion_dia1: acciones aceptadas %d" % n_ok)
	eq(sim1.state_hash(), sim0.state_hash(), "guion_dia1.jsonl = tutorial + dormir")
	await boot_game({"script": path, "screen": "map"})
	eq(g.sim.state_hash(), sim0.state_hash(), "--script aplica las acciones en orden")
	eq(phase(), "desk")
	eq(sh.top_kind(), "map", "--screen=map")
	g.end_session()
	sh.free()
	sh = null
	await boot_game({"screen": "place:L4.consulta"})
	eq(sh.game_screen.state().mode, "plate", "--screen=place:L4.consulta")
	eq(sh.game_screen.cur_place, "L4")
	g.end_session()
	sh.free()
	sh = null
	await boot_game({"screen": "reader:D23@L1"})
	ok(sh.reader_open(), "--screen=reader:D23@L1")
	eq(sh.top_kind(), "reader")
	no(sh.world.input_enabled, "con el lector arriba el 3D no recibe clics")
	ok(sh.router.shortcut("fe_cuaderno"))
	ok(sh.is_open("notebook") and not sh.reader_open(), "Tab con el lector abierto: se deja la hoja y se abre el cuaderno")
	ok(sh.router.shortcut("fe_volver"))
	sh.open_reader("D23@L1")
	ok(sh.router.shortcut("fe_volver"))
	no(sh.reader_open(), "Esc cierra el lector")

# Calendario completo con la Shell a la vista (pasivo, como test_i_integration): cada fase arma su pantalla sin errores
# del motor — escenas fijas (M6, M7), noche con informe, confrontación, informe final, Park Lane, noche del jueves,
# epílogo — y al final se vuelve al título.
func test_passive_calendar_through_ui() -> void:
	await boot_game()
	var gs = sh.game_screen
	W.tutorial(g.sim, act)
	eq(W.errs, [], "tutorial")
	act({"t": "sleep"})
	await settle()
	var seen := {}
	var modes := {}
	for i in 400:
		if sh.screen_id != "game":
			break
		var c: Dictionary = g.sim.q_clock()
		var ph := String(c.phase)
		seen[ph] = true
		if gs != null and is_instance_valid(gs):
			modes[ph] = String(gs.mode)
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			"confront":
				if sh.is_open("tray"):
					ok(sh.top_kind() == "tray", "día 10: primero la bandeja del amanecer (el Times del jueves)")
					sh.close_kind("tray")
					await settle()
				ok(sh.is_open("confront"), "confrontación: la vista se abre sola")
				no(sh.is_open("report"), "sin el informe encima")
				a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				ok(sh.is_open("report"), "informe final: el compositor se abre solo")
				no(sh.is_open("confront"), "la confrontación terminada ya no está")
				a = {"t": "report_submit", "mode": "nada", "items": []}
			"night_choice":
				ok(gs.modal() != null, "noche del jueves: elegir dónde pasarla")
				eq(sh.top(), null, "sin paneles de la tarde encima")
				a = {"t": "night_choice", "where": "casa"}
			"epilogue", "done":
				break
		var r: Dictionary = act(a)
		if not bool(r.get("ok", false)):
			fail("%s en %s -> %s" % [str(a), ph, str(r.get("err", ""))])
			break
		await settle()
	# (las escenas fijas M6/M7 son contenido de la ola 3: el dataset fixture no las trae; la fase scene se cubre con PRO)
	for ph in ["desk", "night", "confront", "final_report", "parklane", "night_choice"]:
		ok(seen.has(ph), "pasó por la fase " + ph)
	eq(modes.get("parklane", ""), "plate", "Park Lane: lámina")
	eq(modes.get("confront", ""), "hub", "confrontación: la tienda de Crane")
	await settle()
	eq(sh.screen_id, "epilogue", "epílogo")
	eq(String(g.sim.q_clock().phase), "epilogue")

# Verificación (W3-SHELL): salidas con el mouse y textos que un jugador nuevo lee. El mapa se cierra con su botón; en una
# escena fija sin panel (Park Lane del dataset fixture) el epígrafe dice dónde y «Continuar» sigue; el mismo subtítulo no
# se apila; la confirmación de dormir lleva el día en minúscula a mitad de frase; los enlaces de examen dicen «Leer:».
func test_mouse_exits_and_texts() -> void:
	await boot_game()
	var gs = sh.game_screen
	# examinar el estante del prólogo (los tomos son decoración en la lámina, GDD_v3 §6.4): lo legible se ofrece con «Leer: …»
	# (playtest v3: con líneas de Pell sin leer, un clic en el 3D sólo pasa a la siguiente; acá ya se leyeron)
	ok(gs.speech.showing() and not gs.speech.queue.is_empty(), "la presentación de Pell, con más líneas")
	var n_q: int = gs.speech.queue.size()
	gs.on_node("estante")
	await frames(2)
	eq(gs.speech.queue.size(), n_q - 1, "un clic en el 3D pasa a la siguiente línea, no las borra")
	no(gs.exam.visible, "y no usa el objeto")
	gs.speech.clear()
	gs.on_node("estante")
	await frames(3)
	var links: Array = (gs.exam.links_box.get_children() + gs.exam.links_list.get_children()).filter(func(b): return b is Button and not b.is_queued_for_deletion())
	ok(not links.is_empty(), "el estante ofrece algo para leer")
	for b in links:
		ok(String(b.text).begins_with(Widgets.t("shell.exam.leer", {"titulo": ""})), "enlace con «Leer:» (%s)" % b.text)
	gs.exam.hide_card()
	W.tutorial(g.sim, act)
	eq(W.errs, [], "tutorial")
	await settle()
	ok(sh.notes().has(Widgets.t("shell.pro.dormir")), "tras el último paso: cómo se duerme (el calendario)")
	gs.calendar()
	await frames(2)
	var m = gs.modal()
	ok(m != null, "dormir pide confirmación")
	var txt := ""
	for l in m.find_children("*", "Label", true, false):
		txt += (l as Label).text + " "
	for r in m.find_children("*", "RichTextLabel", true, false):
		txt += (r as RichTextLabel).get_parsed_text() + " "
	ok(txt.contains("Mañana es martes"), "«Mañana es martes…» (%s)" % txt.strip_edges())
	confirm(m)
	await settle()
	sh.close_all()
	# subtítulos: el mismo sonido dos veces = una línea
	sh._on_subtitle("papel que cruje", 2.0)
	sh._on_subtitle("papel que cruje", 2.0)
	var same := 0
	for c in sh._subs.get_children():
		if c is Label and (c as Label).text == "papel que cruje" and not c.is_queued_for_deletion():
			same += 1
	eq(same, 1, "subtítulo repetido no se apila")
	# mapa: botón propio para cerrarlo
	sh.open_panel("map")
	await frames(3)
	var ms = sh.panel("map")
	ok(ms.close_btn != null and ms.close_btn.is_visible_in_tree(), "el mapa muestra «Cerrar el mapa»")
	eq(ms.close_btn.text, Widgets.t("shell.map.volver"))
	ms.close_btn.pressed.emit()
	await frames(2)
	no(sh.is_open("map"), "«Cerrar el mapa» lo cierra")
	# hasta Park Lane (escena fija sin panel en el fixture): epígrafe y «Continuar»
	var reached := false
	for i in 300:
		var ph := phase()
		if ph == "parklane":
			reached = true
			break
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			"confront":
				a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			_:
				break
		if not bool(act(a).get("ok", false)):
			break
		await settle()
	ok(reached, "llega a Park Lane")
	if not reached:
		return
	await settle()
	if not sh.is_open("scene"):
		ok(gs._leave_btn.is_visible_in_tree(), "Park Lane sin panel: botón a la vista")
		eq(gs._leave_btn.text, Widgets.t("shell.nav.seguir"), "dice «Continuar»")
		gs._leave_btn.pressed.emit()
		await settle()
		ne(phase(), "parklane", "«Continuar» sigue (%s)" % phase())
