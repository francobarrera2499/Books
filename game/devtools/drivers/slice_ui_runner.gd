# devtools/drivers/slice_ui_runner.gd — juega un guion de W4-SLICE (devtools/scripts/slice_<final>.jsonl) por la UI REAL:
# main.tscn → Shell → GameScreen con el autoload Game y data/ real. Lo usan devtools/drivers/slice_ui.gd (con ventana y
# capturas de cada día) y tests/test_slice_ui.gd (headless, sin capturas).
# Cada acción del guion se hace con el widget que la hace en el juego (la misma función que llama su botón o su API de
# automatización, que «hace lo mismo que los clics»), y se comprueba que el registro de la partida recibió EXACTAMENTE esa
# acción; si el widget no la produce, se aplica con Game.act y cuenta como «respaldo» (falla de UI):
#   go             mapa (clic en el marcador → tarjeta de áreas → confirmación con el asiento) · tienda de Crane: el objeto
#                  «puerta» del hub (data/map.json {do: go}) con GameScreen.on_node
#   leave          «Salir» del panel de escena (con su confirmación) / «Continuar» / botón de salir del GameScreen
#   end_slot/sleep calendario del escritorio → confirmación · night_choice: el modal de la noche (opción → confirmación)
#   ask/assert     panel de escena → «Preguntar»/«Afirmar» → tema → confirmar
#   report_submit  compositor del informe (modo, ítems, entregar) · confront: vista de la confrontación (refutar/callar)
#   compose_*      compositores de anuncio, telegrama y carta
#   pass_clean, folio_open, entry_new, entry_set, entry_support_add, practice: el libro mayor (API de sus clics; el lote
#                  con on_lot, el clic de la casilla «Al sello», para que las ranuras del sello lo muestren)
#   link           cuaderno (soltar una tarjeta sobre otra → formulario del cotejo) · clip_measure: lector con la regla
#   epílogo        la pantalla de W4-EPILOGUE (advance = clic en «Seguir»; la oferta de publicar en dos pasos; la tijera
#                  sobre la Strand con do_cut; «Cerrar el libro» del lápiz azul aplica leave y vuelve al título)
#   el resto (recortes de texto y de láminas, papeletas, copia en Somerset House): Game.act, con el lector abierto en la
#   hoja del recorte (los recortes con el mouse real los cubre devtools/drivers/w3int_flow.gd, prólogo a día 3).
# Además, en cada acción: la pantalla está en el modo de la fase (§2.3: hub / lámina / confrontación / informe / epílogo).
# tool: objeto con frames(n) y snap(name) (shot.gd); snaps=false no captura.
extends RefCounted

const S = preload("res://devtools/drivers/slice_script.gd")
const Actions = preload("res://core/sim/actions.gd")
const Clock = preload("res://core/sim/clock.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

var tool
var shell
var g
var snaps := true
var key := "f1"
var prefix := ""
var fast := true                # Shell.fast (sin fundidos, ritual del amanecer ni coche); false = a la velocidad del juego
var save_path := ""            # registro de la partida (por defecto user://saves/slice_<final>.jsonl)
var prof := {}                 # verbo -> [n, ms de la acción, ms de antes] (perfil; no decide nada)
var fails: Array = []          # problemas de UI (modo equivocado, acción no aceptada o distinta, estadio del epílogo que no llega)
var fallbacks := {}            # verbo -> n (el widget no produjo la acción: se aplicó con Game.act)
var via_ui := {}               # verbo -> n
var via_api := {}              # verbo -> n
var shots: Array = []
var notes_seen: Array = []     # [«tk · verbo · nota»] avisos de Lisle tras una acción del guion (sólo informativo: no decide fallas)
var _n := 0
var _day_snapped := {}
var _visit_snapped := {}
var _last_verb := ""
var _ending := ""
var _hash := ""
var _phase := ""
var _log_n := 0
var _fast_until := -1           # índice de acción hasta el que se juega sin esperar a la UI (ramas f2/f3a)

func setup(p_tool, p_shell, p_g) -> void:
	tool = p_tool
	shell = p_shell
	g = p_g

# Juega el guion `key`. fast_to_phase: hasta la primera acción en esa fase se aplica con Game.act sin capturas (para las
# ramas que comparten la investigación con f1). Devuelve el resumen.
func run(p_key: String, fast_to_phase := "") -> Dictionary:
	key = p_key
	if prefix == "":
		prefix = "slice_" + key
	var sc := S.load_script(S.path(key))
	if not bool(sc.ok):
		fails.append("guion ilegible: " + String(sc.err))
		return summary(sc)
	g.save_path = save_path if save_path != "" else "user://saves/slice_%s.jsonl" % key
	for suf in ["", ".bak", ".tmp"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	shell.fast = fast
	shell.sounds = false
	if not g.sim_changed.is_connected(_on_sim_changed):
		g.sim_changed.connect(_on_sim_changed)
	await shell.new_game(int(sc.seed))
	# GDD_v2 §B.4: el lector emite `read` la primera vez que muestra cada hoja. El guion ya trae sus `read` (si los
	# tiene): aquí el lector no emite por su cuenta y cada `read` del guion se hace abriendo esa hoja (_ui_read).
	var rd0 = shell.ensure_reader()
	rd0.emit_read = false
	rd0.reset_read_memory()
	await idle()
	if g.sim == null or shell.game_screen == null:
		fails.append("no arrancó la partida")
		return summary(sc)
	var actions: Array = sc.actions
	if fast_to_phase != "":
		_fast_until = -1
		var probe = load("res://core/sim/game_sim.gd").new(g.sim.repo, int(sc.seed))
		for i in actions.size():
			if String(probe.q_clock().phase) == fast_to_phase:
				_fast_until = i
				break
			probe.apply(actions[i])
	for i in actions.size():
		var a: Dictionary = actions[i]
		if g.sim == null:
			fails.append("la sesión se cerró antes de la acción %d de %d (pantalla %s)" % [i, actions.size(), String(shell.screen_id)])
			break
		if i < _fast_until:
			var rf: Dictionary = g.act(a)
			if not bool(rf.get("ok", false)):
				fails.append("#%d %s rechazada (rápido): %s" % [i, J.stringify_canon(a).left(120), String(rf.get("err", ""))])
			if i + 1 == _fast_until:
				await idle()
				await snap("rama_" + String(g.sim.q_clock().phase))
			continue
		var t_a := Time.get_ticks_msec()
		await before(a, i, sc.marks.get(i, []))
		var t_b := Time.get_ticks_msec()
		await do_action(a, i)
		await idle()
		var pk := String(a.t)
		var pv: Array = prof.get(pk, [0, 0, 0])
		prof[pk] = [int(pv[0]) + 1, int(pv[1]) + Time.get_ticks_msec() - t_b, int(pv[2]) + t_b - t_a]
		if g.sim == null:
			if i + 1 < actions.size():
				fails.append("la sesión se cerró tras la acción %d de %d (%s; pantalla %s)" % [i, actions.size(), J.stringify_canon(a).left(80), String(shell.screen_id)])
			break
		after(a, i)
		if String(g.sim.q_clock().phase) == "done" or shell.screen_id != "game" and String(g.sim.q_clock().phase) != "epilogue":
			if i + 1 < actions.size() and String(g.sim.q_clock().phase) == "done":
				fails.append("la partida terminó antes del final del guion (acción %d de %d)" % [i + 1, actions.size()])
			break
	await finish(sc)
	return summary(sc)

func summary(sc: Dictionary) -> Dictionary:
	if g != null and g.sim != null:
		after({"t": "fin"}, -1)
	return {"key": key, "expect": String(sc.get("expect", "")), "ending": _ending, "phase": _phase,
		"actions": (sc.get("actions", []) as Array).size(), "log": _log_n,
		"fails": fails, "fallbacks": fallbacks, "via_ui": via_ui, "via_api": via_api, "shots": shots.size(), "hash": _hash,
		"notes": notes_seen.slice(0, 40), "prof": prof}

# ------------------------------------------------------------------ espera y capturas
func idle(max_frames := 1200) -> void:
	var i := 0
	while i < max_frames:
		var gs = shell.game_screen
		if shell.screen_id != "game" or (gs != null and gs.idle() and not _map_busy()):
			break
		await tool.frames(1)
		i += 1
	await fr(3)

func _map_busy() -> bool:
	var m = shell.panel("map")
	return m != null and is_instance_valid(m) and m.has_method("traveling") and m.traveling()

func snap(name: String) -> void:
	if not snaps:
		return
	_n += 1
	var c: Dictionary = g.sim.q_clock() if g.sim != null else {"day": 11}
	var d := int(c.get("day", 0))
	var nm := "d%02d_%03d_%s" % [d, _n, name]
	await wait_s(0.45)   # fundidos y entradas de la UI (≤0,4 s) terminados
	await tool.snap(nm)
	shots.append("%s_%s.png" % [prefix, nm])

func gs():
	return shell.game_screen

# ------------------------------------------------------------------ antes y después de cada acción
func before(a: Dictionary, i: int, marks: Array) -> void:
	var c: Dictionary = g.sim.q_clock()
	var d := int(c.day)
	var ph := String(c.phase)
	var t := String(a.t)
	# el amanecer de cada día: la bandeja (o la escena del amanecer) tal como la deja el ritual
	if not _day_snapped.has(d):
		_day_snapped[d] = true
		await fr(20)
		await settle_lines()
		await snap("prologo" if d <= 0 else ("epilogo_inicio" if ph == "epilogue" else "amanecer"))
		# como el jugador: lee la presentación hasta el final («Seguir») antes de ponerse a trabajar
		if ph == "prologue" and gs() != null and gs().speech != null:
			for k in 40:
				if not gs().speech.visible:
					break
				gs().speech.advance()
				await fr(2)
			await idle()
		if gs() != null and gs().tray != null and gs().tray.visible:
			# el jugador deja la bandeja después de mirarla (como su «volver»: el día 10 la confrontación se abre después)
			shell.close_kind("tray")
			await fr(4)
			await idle()
	# cada visita, al entrar (lámina y panel de escena)
	if ph == "visit":
		var vid := String(g.sim.q_scene().get("id", ""))
		if not _visit_snapped.has(vid):
			_visit_snapped[vid] = true
			var sc: Dictionary = g.sim.q_scene()
			await settle_lines()
			await snap("%s_%s_%s" % [String(c.slot), String(sc.get("place", "")), String(sc.get("area", ""))])
	elif ["scene", "parklane"].has(ph) and not _visit_snapped.has(ph + str(c.tk)):
		_visit_snapped[ph + str(c.tk)] = true
		await settle_lines()
		await snap("%s_%s" % [ph, String(g.sim.q_scene().get("id", ""))])
	# las familias de paneles: al pasar a otra, se cierra lo que quedó abierto (como el jugador)
	var fam := _family(t)
	if fam != _last_verb:
		for k in ["ledger", "notebook", "map", "ad", "telegram", "letter"]:
			if shell.is_open(k) and _family_panel(fam) != k:
				shell.close_kind(k)
		if shell.reader_open() and fam != "reader":
			shell.close_kind("reader")
			if shell.reader != null and shell.reader.visible:
				shell.reader.close()
		await tool.frames(2)
	_last_verb = fam
	_check_mode(ph, "antes de #%d %s" % [i, t])

func _track() -> void:
	if g == null or g.sim == null:
		return
	var en: Dictionary = g.sim.q_ending()
	if not en.is_empty():
		_ending = String(en.get("ending", ""))
	_hash = g.sim.state_hash()
	_phase = String(g.sim.q_clock().phase)
	_log_n = g.sim.actions_log().size()

func after(a: Dictionary, i: int) -> void:
	var t := String(a.t)
	_track()
	if g.sim == null:
		return
	for n in shell.notes():
		var s := "%s · %s · %s" % [TimeKey.label(int(g.sim.q_clock().tk)), t, String(n)]
		if not notes_seen.has(s):
			notes_seen.append(s)

static func _family(t: String) -> String:
	if t in ["pass_clean", "folio_open", "entry_new", "entry_set", "entry_support_add", "entry_support_remove", "entry_delete", "practice"]:
		return "ledger"
	if t == "link":
		return "notebook"
	if t in ["clip_text", "clip_measure"]:
		return "reader"
	return t

static func _family_panel(fam: String) -> String:
	return fam if fam in ["ledger", "notebook"] else ""

func _check_mode(ph: String, where: String) -> void:
	var gsc = gs()
	if ph == "epilogue":
		if String(shell.screen_id) != "epilogue":
			fails.append("%s: fase epilogue sin la pantalla del epílogo (%s)" % [where, String(shell.screen_id)])
		return
	if ph == "done":
		return
	if gsc == null or shell.screen_id != "game":
		fails.append("%s: fuera de la pantalla de juego (%s) en fase %s" % [where, shell.screen_id, ph])
		return
	match ph:
		"visit":
			var want := String(g.sim.q_visit_plate().get("id", ""))
			if String(gsc.mode) != "plate" or String(gsc.cur_plate) != want:
				fails.append("%s: la visita no muestra su lámina (%s %s, quiere %s)" % [where, gsc.mode, gsc.cur_plate, want])
		"desk", "night", "final_report", "night_choice", "prologue":
			if ph != "prologue" and String(gsc.mode) != "hub":
				fails.append("%s: fase %s fuera del hub (%s %s)" % [where, ph, gsc.mode, gsc.cur_plate])
		"confront":
			if not shell.is_open("confront"):
				fails.append("%s: confrontación sin su vista" % where)

# ------------------------------------------------------------------ hacer la acción
func do_action(a: Dictionary, i: int) -> void:
	var t := String(a.t)
	var n0: int = g.sim.actions_log().size()
	var tried := false
	if String(g.sim.q_clock().phase) == "epilogue":
		await _do_epilogue(a, i, n0)
		return
	match t:
		"go":
			tried = true
			await _ui_go(a)
		"leave":
			tried = await _ui_leave(a)
		"end_slot", "sleep":
			tried = await _ui_calendar(t)
		"night_choice":
			tried = true
			await _ui_night(String(a.get("where", "")))
		"ask", "assert":
			tried = await _ui_talk(a)
		"report_submit":
			tried = true
			await _ui_report(a)
		"confront":
			tried = await _ui_confront(a)
		"compose_ad":
			tried = true
			await _ui_ad(a)
		"compose_telegram", "compose_letter":
			tried = true
			await _ui_mail(a)
		"pass_clean", "folio_open", "entry_new", "entry_set", "entry_support_add", "practice":
			tried = await _ui_ledger(a)
		"link":
			tried = await _ui_link(a)
		"clip_measure":
			tried = await _ui_measure(a)
		"read":
			tried = await _ui_read(a)
		"slip":
			tried = await _ui_slip(a)
		"order_copy":
			tried = await _ui_order_copy(a)
		"clip_text":
			await _show_source(a)
	if g.sim == null:
		return
	var lg: Array = g.sim.actions_log()
	if tried and lg.size() == n0 + 1 and _same(lg[-1], a):
		via_ui[t] = int(via_ui.get(t, 0)) + 1
		_track()
		return
	if lg.size() > n0:
		# el widget aplicó otra cosa (o más de una): es una falla de UI y el guion ya no se puede seguir al pie de la letra
		fails.append("#%d %s: el widget aplicó %s" % [i, J.stringify_canon(a).left(120), J.stringify_canon(lg.slice(n0)).left(240)])
		return
	if tried:
		fallbacks[t] = int(fallbacks.get(t, 0)) + 1
	else:
		via_api[t] = int(via_api.get(t, 0)) + 1
	var r: Dictionary = g.act(a)
	if not bool(r.get("ok", false)):
		fails.append("#%d %s rechazada: %s" % [i, J.stringify_canon(a).left(120), String(r.get("err", ""))])
	_track()
	# acciones de días con panel propio: capturas puntuales
	await idle()

static func _same(x: Dictionary, y: Dictionary) -> bool:
	return J.stringify_canon(Actions.normalize(x)) == J.stringify_canon(Actions.normalize(y))

# ---------------- verbos
func _press_confirm(cf) -> bool:
	if cf == null or not is_instance_valid(cf):
		return false
	var b = cf.get("ok_button")
	if b is Button and is_instance_valid(b):
		(b as Button).pressed.emit()
		return true
	if cf.has_signal("decided"):
		cf.decided.emit(true)
		return true
	return false

func _press_modal_ok() -> bool:
	await fr(3)
	var m = gs().modal() if gs() != null else null
	if m == null:
		return false
	for c in m.find_children("*", "", true, false):
		if c.get("ok_button") is Button:
			return _press_confirm(c)
	return false

func _ui_go(a: Dictionary) -> void:
	var place := String(a.get("place", ""))
	var area := String(a.get("area", ""))
	if Clock.is_free(g.sim.repo, place, area):
		# la tienda de Crane: el objeto del hub que baja (data/map.json: binding {do: go}), como su clic
		var node := _hub_go_node(place, area)
		if node != "":
			gs().on_node(node)
		await idle()
		return
	var mp = shell.open_panel("map")
	await fr(6)
	if mp == null:
		return
	var st: Dictionary = mp.place_state(place)
	var pick := {}
	for ar in st.get("areas", []):
		if String(ar.get("area", "")) == area and bool(ar.get("can_go", false)):
			pick = ar
	if pick.is_empty():
		fails.append("mapa: %s.%s no se ofrece (%s)" % [place, area, str(st).left(200)])
		shell.close_kind("map")
		return
	if int(a.get("seat", 0)) > 0:
		mp.seat = int(a.seat)   # el asiento que el jugador escribe en la confirmación (la SpinBox arranca en él)
	# clic en el marcador (lo mismo que hace su botón: Marker.pressed_cb); con varias áreas, la tarjeta de áreas -> la suya
	var m = mp.marker(place)
	if m == null or not ("pressed_cb" in m) or not (m.pressed_cb as Callable).is_valid():
		fails.append("mapa: sin marcador para %s" % place)
		shell.close_kind("map")
		return
	var before := _confirms(mp)
	(m.pressed_cb as Callable).call(m)
	await fr(4)
	if _confirms(mp).size() <= before.size():
		var want := _area_label(pick)
		var hit := false
		for b in mp.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and String((b as Button).text).strip_edges() == want:
				(b as Button).pressed.emit()
				hit = true
				break
		if not hit:
			fails.append("mapa: la tarjeta de áreas de %s no ofrece «%s»" % [place, want])
		await fr(4)
	if not _snapped_map:
		_snapped_map = true
		await snap("mapa_confirmar")
	var cfs := _confirms(mp)
	if cfs.is_empty() or not _press_confirm(cfs[-1]):
		shell.close_kind("map")
		return
	await idle()

# Papeleta por el catálogo de la Sala de Lectura, como el jugador (hallazgo del playtest: se pedía por API y no se veía
# el bloqueo del catálogo): una entidad del índice cuya búsqueda lista el documento, su ficha y «Pedir», y la papeleta.
func _ui_slip(a: Dictionary) -> bool:
	var did := String(a.get("doc", ""))
	var gsc = gs()
	if gsc == null or not gsc.has_method("open_catalog"):
		return false
	var ent := ""
	var label := ""
	for x in g.sim.q_index():
		if ent != "" or String(x.get("kind", "")) == "act_ref":
			continue
		for r in g.sim.q_catalog(String(x.get("id", ""))):
			if String(r.get("doc", "")) == did:
				ent = String(x.get("id", ""))
				label = String(r.get("label", ""))
	if ent == "":
		fails.append("catálogo: ninguna entidad del índice lista %s" % did)
		return false
	gsc.open_catalog()
	await fr(4)
	var cat = gsc.catalog
	if cat == null or not cat.visible:
		fails.append("catálogo: no se abrió")
		return false
	cat._search(ent)   # el botón del índice (Widgets.button -> _search)
	await fr(4)
	var pedir: Button = null
	for card in cat.results.get_children():
		var lab := ""
		for l in card.find_children("*", "Label", true, false):
			lab += String((l as Label).text)
		if lab.strip_edges() == label.strip_edges():
			for b in card.find_children("*", "Button", true, false):
				if String((b as Button).name).begins_with("Pedir"):
					pedir = b
	if pedir == null:
		fails.append("catálogo: la ficha «%s» no tiene «Pedir» (buscando %s)" % [label, ent])
		cat.close()
		return false
	pedir.pressed.emit()
	await fr(4)
	await snap("catalogo_papeleta")
	var cfs := _confirms(cat.get_parent())
	if cfs.is_empty() or not _press_confirm(cfs[-1]):
		fails.append("catálogo: sin confirmación de la papeleta")
		cat.close()
		return false
	await fr(4)
	cat.close()
	await idle()
	return true

# Copia certificada en Somerset House, como el jugador: el nodo de los índices cuyo documento es el pedido, su tarjeta de
# examen y «Pedir copia certificada (un chelín)», confirmado en el modal.
func _ui_order_copy(a: Dictionary) -> bool:
	var did := String(a.get("doc", ""))
	var gsc = gs()
	if gsc == null or not gsc.has_method("on_node"):
		return false
	# la tarjeta ofrece el documento cuya entidad nombra el examen del nodo (ui/desk/objects.gd docs_for)
	var dent := String(g.sim.repo.doc(did).get("entity", ""))
	var nid := ""
	for n in gsc._place_def(String(g.sim.q_scene().get("place", "L6"))).get("nodes", []):
		if nid == "" and dent != "" and String(n.get("examine", "")).contains("[[" + dent + "|"):
			nid = String(n.get("id", ""))
	if nid == "":
		fails.append("copia: ningún nodo del lugar abre %s" % did)
		return false
	# como el jugador: cierra el lector (y la tijera) y vuelve a la sala antes de tocar los índices
	if shell.reader_open():
		shell.close_kind("reader")
		await fr(3)
	if bool(gsc.get("scissors_on")):
		gsc.toggle_scissors()
		await fr(2)
	gsc.on_node(nid)
	await fr(4)
	var btn: Button = null
	if gsc.exam != null:
		for b in gsc.exam.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and String((b as Button).text).begins_with(Widgets.t("shell.copia.corto")):
				btn = b
	if btn == null:
		fails.append("copia: la tarjeta de %s no ofrece «%s»" % [nid, Widgets.t("shell.copia.corto")])
		return false
	btn.pressed.emit()
	await fr(3)
	await snap("copia_certificada")
	if not await _press_modal_ok():
		var m = gsc.modal()
		var done := false
		if m != null:
			for ch in m.find_children("*", "", true, false):
				if ch.has_signal("decided"):
					ch.decided.emit(true)
					done = true
					break
		if not done:
			fails.append("copia: sin confirmación")
			return false
	await idle()
	return true

# Confirmaciones (Widgets.confirm: tienen ok_button) visibles dentro de un nodo.
func _confirms(root) -> Array:
	var out: Array = []
	if root == null or not is_instance_valid(root) or not (root is Node):
		return out
	for c in root.find_children("*", "", true, false):
		if c.get("ok_button") is Button and (c as CanvasItem).is_visible_in_tree() and not c.is_queued_for_deletion():
			out.append(c)
	return out

# Rótulo del botón de un área en la tarjeta del mapa (map_screen._area_name: area_name con mayúscula inicial).
static func _area_label(a: Dictionary) -> String:
	var an := String(a.get("area_name", a.get("area", "")))
	return an.substr(0, 1).to_upper() + an.substr(1)
var _snapped_map := false

func _ui_leave(a: Dictionary) -> bool:
	var ph := String(g.sim.q_clock().phase)
	if ph == "epilogue":
		return false
	var sp = shell.panel("scene")
	if sp != null and is_instance_valid(sp) and shell.is_open("scene"):
		sp.leave()
		await fr(3)
		var cfs := _confirms(sp)   # «¿Salir?» de una visita con costo (dos pasos)
		if not cfs.is_empty():
			_press_confirm(cfs[-1])
		await idle()
		return true
	var lb = gs().find_child("Leave", true, false)   # el botón de salir del GameScreen
	if lb is Button and (lb as Button).is_visible_in_tree():
		(lb as Button).pressed.emit()
	else:
		gs().calendar()   # escena sin panel: el calendario sigue (leave)
	await fr(2)
	if gs().modal() != null:
		await _press_modal_ok()
	await idle()
	return true

func _ui_calendar(t: String) -> bool:
	var ph := String(g.sim.q_clock().phase)
	if t == "sleep" and not ["night", "prologue"].has(ph):
		return false
	if t == "end_slot" and ph != "desk":
		return false
	if t == "sleep" and ph == "night" and not _night_snapped.has(int(g.sim.q_clock().day)):
		_night_snapped[int(g.sim.q_clock().day)] = true
		await snap("noche")
	gs().calendar()
	await fr(3)
	var ok := await _press_modal_ok()
	await idle()
	return ok
var _night_snapped := {}

func _ui_night(where: String) -> void:
	gs()._night_choice()
	await fr(4)
	await snap("noche_final_elegir")
	var m = gs().modal()
	if m == null:
		return
	var label: String = Widgets.t("shell.noche.baker" if where == "baker_street" else "shell.noche.casa")
	for b in m.find_children("*", "Button", true, false):
		if String((b as Button).text) == label:
			(b as Button).pressed.emit()
			break
	await fr(4)
	await _press_modal_ok()
	await idle()

func _ui_talk(a: Dictionary) -> bool:
	var sp = shell.panel("scene")
	if sp == null or not shell.is_open("scene"):
		return false
	var mode := "assert" if String(a.t) == "assert" else "ask"
	var cid := String(a.get("char", ""))
	sp.open_ask(cid, mode)
	await fr(3)
	var ap = sp.ask_panel
	ap.choose(String(a.get("assertion", "")) if mode == "assert" else String(a.get("topic", "")))
	await fr(2)
	if not _talk_snapped:
		_talk_snapped = true
		await snap("preguntar_" + cid)
	ap.confirm()
	await idle()
	if not _said_snapped.has(int(g.sim.q_clock().day)):
		_said_snapped[int(g.sim.q_clock().day)] = true
		await settle_lines()
		await snap("dicho_" + cid)
	return true
var _talk_snapped := false
var _said_snapped := {}

func _ui_report(a: Dictionary) -> void:
	var rc = shell.panel("report") if shell.is_open("report") else shell.open_panel("report")
	await fr(6)
	if rc == null:
		return
	var mode := String(a.get("mode", "nada"))
	rc.set_mode(mode)
	for it in a.get("items", []):
		rc.add_item(it)
	await fr(4)
	await snap("informe_" + mode)
	rc.confirm_send()
	await idle()

func _ui_confront(a: Dictionary) -> bool:
	var cv = shell.panel("confront")
	if cv == null or not shell.is_open("confront"):
		cv = shell.open_panel("confront")
		await fr(6)
	if cv == null:
		return false
	var item: Dictionary = a.get("item", {})
	if item.is_empty():
		cv.ask_silence()
		await tool.frames(2)
		cv.confirm_silence()
	else:
		if not cv.refute(item):
			return false
		await fr(3)
		await snap("confrontacion_%d" % int(a.get("step", 0)))
		cv.confirm_bar.confirm()
	await settle_lines()
	await snap("confrontacion_%d_respuesta" % int(a.get("step", 0)))
	await idle()
	return true

func _ui_ad(a: Dictionary) -> void:
	var ac = shell.open_panel("ad")
	await fr(6)
	if ac == null:
		return
	ac.choose_form(String(a.get("form", "")))
	var f: Dictionary = a.get("fields", {})
	for k in f:
		ac.set_field(String(k), String(f[k]))
	await fr(3)
	await snap("anuncio_" + String(a.get("form", "")))
	ac.confirm_send()
	await idle()
	if shell.is_open("ad"):
		shell.close_kind("ad")

func _ui_mail(a: Dictionary) -> void:
	var kind := "telegram" if String(a.t) == "compose_telegram" else "letter"
	var tc = shell.open_panel(kind, [kind])
	await fr(6)
	if tc == null:
		return
	tc.set_to(String(a.get("to", "")))
	var parts: Array = a.get("parts", [])
	for i in parts.size():
		tc.set_part(i, String(parts[i]))
	await fr(3)
	await snap(kind)
	tc.confirm_send()
	await idle()
	if shell.is_open(kind):
		shell.close_kind(kind)

func _ui_ledger(a: Dictionary) -> bool:
	var lg = shell.panel("ledger") if shell.is_open("ledger") else shell.open_panel("ledger")
	await fr(3)
	if lg == null:
		return false
	match String(a.t):
		"pass_clean":
			# las casillas «Al sello» con su clic (on_lot = toggle_lot + refresh): el lote se ve en las ranuras del sello
			var want: Array = (a.get("entries", []) as Array).map(func(x): return String(x))
			for e in (lg.lot as Array).duplicate():
				if not want.has(String(e)):
					lg.on_lot(String(e))
			for e in want:
				if not (lg.lot as Array).has(e):
					lg.on_lot(e)
			await fr(2)
			lg.stamp()
			await fr(4)
			await snap("sello")
			var cf = lg.confirm_dialog() if lg.has_method("confirm_dialog") else null
			if cf != null and _press_confirm(cf):
				pass
			else:
				lg.confirm_stamp()
			await fr(16)
			await snap("libro_mayor_pasada")
		"folio_open":
			lg.new_folio_from(String(a.get("clip", "")))
		"entry_new":
			var fo := String(a.get("folio", ""))
			if fo != "" and fo != "varios":
				lg.show_page(fo)
			elif fo == "varios":
				lg.show_page("varios")
			lg.new_entry(String(a.get("template", "")))
		"entry_set":
			lg.set_field(String(a.entry), int(a.line), String(a.field), String(a.value))
		"entry_support_add":
			lg.add_support(String(a.entry), int(a.line), String(a.item))
		"practice":
			lg.practice(String(a.entry))
	await fr(2)
	return true

func _ui_link(a: Dictionary) -> bool:
	var nb = shell.panel("notebook") if shell.is_open("notebook") else shell.open_panel("notebook")
	await fr(4)
	if nb == null or not nb.has_method("request_link"):
		return false
	nb.request_link(String(a.get("a", "")), String(a.get("b", "")))
	await fr(4)
	var form = nb.overlay_panel() if nb.has_method("overlay_panel") else null
	if form == null:
		return false
	var le = form.get_meta("note_edit") if form.has_meta("note_edit") else null
	if le is LineEdit:
		(le as LineEdit).text = String(a.get("note", ""))
	await snap("cotejo")
	_press_confirm(form)
	await fr(6)
	return true

# GDD_v2 §C.4: la regla y «Anotar la medida» ya no existen; clip_measure (partidas viejas) va por Game.act.
func _ui_measure(_a: Dictionary) -> bool:
	return false

# `read` del guion: abrir esa hoja en el lector (el lector la anota la primera vez que la muestra) y cerrarlo.
func _ui_read(a: Dictionary) -> bool:
	var view := String(a.get("view", ""))
	var part := int(a.get("part", 0))
	var rd = shell.ensure_reader()
	rd.reset_read_memory()
	rd.emit_read = part == 0
	if not shell.open_reader(view):
		rd.emit_read = false
		return false
	await fr(4)
	if part > 0:
		rd.emit_read = true
		rd.go_page(part)
		await fr(3)
	rd.emit_read = false
	if rd.visible:
		rd.close()
		await fr(3)
	return true

# Recorte de texto (Game.act): antes, el documento abierto en el lector en su hoja (lo que el jugador tendría delante).
var _views_shown := {}
func _show_source(a: Dictionary) -> void:
	var src: Dictionary = a.get("src", {})
	if String(src.get("kind", "")) != "doc":
		return
	var view := String(src.get("ref", ""))
	if not shell.reader_open() or String(shell.reader.view.get("view", "")) != view:
		if not shell.open_reader(view):
			fails.append("lector: %s no se abre" % view)
			return
		await fr(6)
	var rd = shell.reader
	if int(src.get("part", 0)) != int(rd.page_idx):
		rd.go_page(int(src.get("part", 0)))
		await fr(4)
	if not _views_shown.has(view):
		_views_shown[view] = true
		if _views_shown.size() <= 12 or view.begins_with("R.") or view.begins_with("D15."):
			await snap("lector_" + view.replace("@", "_").replace(".", "_"))

# ------------------------------------------------------------------ final
func finish(sc: Dictionary) -> void:
	if g.sim_changed.is_connected(_on_sim_changed):
		g.sim_changed.disconnect(_on_sim_changed)
	await idle()
	await fr(30)
	await snap("fin_" + String(shell.screen_id))
	if g.sim != null:
		after({"t": "fin"}, -1)
	var want_n: int = (sc.get("actions", []) as Array).size()
	if _log_n != want_n:
		fails.append("el registro de la partida tiene %d de las %d acciones del guion" % [_log_n, want_n])
	if _ending != String(sc.get("expect", "")):
		fails.append("final %s, se esperaba %s" % [_ending, String(sc.get("expect", ""))])

# Las líneas nuevas del panel de escena y de la confrontación entran escalonadas (0,14 s) con un fundido de 0,3 s: antes de
# una captura se espera (en tiempo real, tope max_s) a que todas se vean. Sin capturas no se espera.
func settle_lines(max_s := 6.0) -> void:
	if not snaps:
		return
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		var all_in := true
		for k in ["scene", "confront"]:
			var p = shell.panel(k)
			if p == null or not is_instance_valid(p) or not shell.is_open(k) or not ("transcript" in p) or p.transcript == null:
				continue
			for r in p.transcript.rows():
				var row = r.get("row")
				if row is CanvasItem and is_instance_valid(row) and (row as CanvasItem).modulate.a < 0.99:
					all_in = false
		if all_in:
			break
		await tool.frames(2)
	await fr(4)

func wait_s(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await tool.frames(1)

# Cuadros de espera tras una acción de UI: con capturas, los pedidos (la imagen se asienta); sin capturas (tests headless),
# lo mínimo para que corran los call_deferred (la espera real es idle(), que mira GameScreen.idle()).
func fr(n: int) -> void:
	await tool.frames(n if snaps else mini(n, 2))

# ------------------------------------------------------------------ epílogo (pantalla de W4-EPILOGUE)
# Al cerrar el libro la pantalla aplica leave y vuelve al título (Game.end_session: g.sim = null). Para verificar esa última
# acción, cada cambio del sim deja anotado el estado (y, en el epílogo, la última acción del registro).
var _last_act := {}
func _on_sim_changed(_kind: String, _payload: Dictionary) -> void:
	_track()
	if g != null and g.sim != null and ["epilogue", "done"].has(String(g.sim.q_clock().phase)):
		var lg: Array = g.sim.actions_log()
		_last_act = lg[-1] if not lg.is_empty() else {}

func _epi():
	var s = shell.screen
	if s != null and is_instance_valid(s) and s.has_method("state") and s.has_method("advance") and String(shell.screen_id) == "epilogue":
		return s
	return null

var _epi_seen := {}
func _epi_snap(epi) -> void:
	var stg := String(epi.state().get("stage", ""))
	if stg != "" and not _epi_seen.has(stg):
		_epi_seen[stg] = true
		await snap("epilogo_" + stg)

# Avanza (clic) hasta que pred(state) se cumpla; captura cada estadio nuevo. false si no llegó.
func _epi_until(epi, pred: Callable, max_n := 160) -> bool:
	for k in max_n:
		if epi == null or not is_instance_valid(epi) or g.sim == null:
			return false
		await _epi_snap(epi)
		if pred.call(epi.state()):
			return true
		epi.advance()
		await epi_pause()
	return pred.call(epi.state()) if epi != null and is_instance_valid(epi) else false

func _do_epilogue(a: Dictionary, i: int, n0: int) -> void:
	var t := String(a.t)
	var epi = _epi()
	var tried := false
	if epi != null:
		match t:
			"publish_errata":
				tried = true   # si la oferta no aparece, la acción cae al respaldo (falla), nunca a la API en silencio
				if not await _epi_until(epi, func(s): return bool(s.get("offer", false))):
					fails.append("#%d epílogo: la oferta de publicar la fe de erratas no apareció (%s)" % [i, str(epi.state() if is_instance_valid(epi) else {}).left(160)])
				else:
					await snap("epilogo_oferta")
					epi.choose_publish(bool(a.get("yes", false)))
					await fr(4)
					var cfs := _confirms(epi)
					if cfs.is_empty() or not _press_confirm(cfs[-1]):
						epi.confirm(true)
					await fr(6)
			"clip_text":
				var src: Dictionary = a.get("src", {})
				tried = true
				if not await _epi_until(epi, func(s): return String(s.get("stage", "")) == "tijera"):
					fails.append("#%d epílogo: el estadio de la tijera no llegó (%s)" % [i, str(epi.state() if is_instance_valid(epi) else {}).left(160)])
				else:
					epi.set_scissors(true)
					await fr(4)
					await snap("epilogo_tijera")
					epi.do_cut(int(src.get("part", 0)), int(a.get("from", 0)), int(a.get("len", 0)))
					await fr(8)
			"leave":
				tried = true
				for k in 240:
					if g.sim == null or String(shell.screen_id) != "epilogue" or not is_instance_valid(epi):
						break
					await _epi_snap(epi)
					var st: Dictionary = epi.state()
					if String(st.get("stage", "")) == "lapiz":
						# el libro mayor corregido a lápiz azul: «Cerrar el libro» (su botón) cierra el epílogo
						var close_b: Button = null
						for b in epi.find_children("*", "Button", true, false):
							if (b as Button).is_visible_in_tree() and String((b as Button).text).to_lower().contains("cerrar"):
								close_b = b
						if close_b != null:
							await epi_pause()
							await snap("epilogo_lapiz_azul")
							close_b.pressed.emit()
							await fr(8)
							continue
					epi.advance()
					await epi_pause()
				await fr(10)
	# verificación: el registro recibió exactamente esta acción (con la sesión ya cerrada, lo anotado al cambiar el sim)
	var n1: int = g.sim.actions_log().size() if g.sim != null else _log_n
	var last: Dictionary = (g.sim.actions_log()[-1] if g.sim != null and n1 > 0 else _last_act)
	if tried and n1 == n0 + 1 and _same(last, a):
		via_ui[t] = int(via_ui.get(t, 0)) + 1
		_track()
		return
	if n1 > n0:
		fails.append("#%d %s (epílogo): la pantalla aplicó otra cosa (%d acciones; última %s)" % [i, J.stringify_canon(a).left(120), n1 - n0, J.stringify_canon(last).left(160)])
		return
	if g.sim == null:
		fails.append("#%d %s (epílogo): la sesión se cerró sin aplicarla" % [i, J.stringify_canon(a).left(120)])
		return
	if tried:
		fallbacks[t] = int(fallbacks.get(t, 0)) + 1
	else:
		via_api[t] = int(via_api.get(t, 0)) + 1
	var r: Dictionary = g.act(a)
	if not bool(r.get("ok", false)):
		fails.append("#%d %s rechazada (epílogo): %s" % [i, J.stringify_canon(a).left(120), String(r.get("err", ""))])
	_track()

func epi_pause() -> void:
	if snaps:
		await wait_s(0.45)
	else:
		await fr(6)

# Nodo del hub cuyo objeto lleva a (place, area) gratis (data/map.json objects: {do: "go", place, area}).
func _hub_go_node(place: String, area: String) -> String:
	var objs = g.sim.repo.map().get("objects", {})
	var stack: Array = [objs]
	while not stack.is_empty():
		var o = stack.pop_back()
		if typeof(o) != TYPE_DICTIONARY:
			continue
		for k in o:
			var v = o[k]
			if typeof(v) == TYPE_DICTIONARY:
				if String(v.get("do", "")) == "go" and String(v.get("place", "")) == place and String(v.get("area", "")) == area:
					return String(k)
				stack.append(v)
	return ""
