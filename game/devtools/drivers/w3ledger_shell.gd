# W3-LEDGER: el libro mayor dentro del juego de verdad (Shell + GameScreen + InputRouter + Cuaderno + panel de escena),
# con la partida del recorrido de integración (estructura de data/ + fixtures/integ) cargada en el autoload Game por
# guardar -> continuar. TODO con eventos reales de ratón y teclado (Input.parse_input_event), sin llamar a la API:
#   L abre el libro · Tab: cuaderno a la izquierda y libro a la derecha · clic en «Varios», «Nuevo asiento», plantilla ·
#   arrastrar un chip del Índice del cuaderno al campo «Persona:» · arrastrar una tarjeta de Recortes al «según» ·
#   lista cerrada por clic · tarjeta de Recortes -> pestaña «Nuevo folio» · Esc cierra el cuaderno y el libro vuelve
#   a dos páginas · ranura vacía del sello -> elegir
#   asiento · casilla «Al sello» · sello: chequeo formal (no gasta) · «Borrar» con confirmación · sello con dos pasos ->
#   golpe seco · visita a Kensington con Watson: L -> libro a la derecha, arriba de la banda, sin sello · arrastrar el
#   renglón de un asiento sobre Watson -> presentar en dos pasos.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ledger res://devtools/drivers/w3ledger_shell.gd
# Capturas (.work/shots/w3ledger_shell_<n>.png): 1_libro, 2_dos_libros, 3_arrastres, 3b_folio, 4_formal, 5_confirma,
#   6_seco, 7_visita, 8_presentar. Imprime SHELL OK|FALLA por paso (y SHELL RESUMEN n fallas).
extends RefCounted

const Integ = preload("res://tests/test_i_integration.gd")
const ShellScript = preload("res://ui/shell.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")

var tool
var shell
var game
var lg
var nb
var _last := Vector2.ZERO
var _fails := 0

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var t = Integ.new()
	t._cur = "w3ledger_shell.gd::drive"
	var repo = t._repo("fixture")
	var sim0 = t._walk(repo)
	if sim0 == null:
		print("SIN RECORRIDO ", t._errs)
		return
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/tests/w3ledger_shell")
	DirAccess.make_dir_recursive_absolute(dir)
	var save := dir.path_join("partida.jsonl")
	for f in [save, save + ".tmp", save + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	game = tool.root.get_node("Game")
	game.save_path = save
	game.repo_override = repo
	game.sim_handlers = {}
	game.new_session(Integ.SEED)
	for x in sim0.actions_log():
		var r: Dictionary = game.act(x)
		if not bool(r.get("ok", false)):
			print("RECHAZADA ", x, " ", r)
			break
	game.flush()
	_check(game.sim.state_hash() == sim0.state_hash(), "la partida guardada reproduce el recorrido")
	game.end_session()
	shell = ShellScript.new()
	scene.add_child(shell)
	await tool.frames(2)
	await _settle_window()
	shell.boot({"continue": true, "save": save, "fast": true, "mute": true, "new": false, "seed": 0, "script": "", "screen": "", "data": ""})
	await tool.frames(90)
	var gs = shell.game_screen
	_check(gs != null and game.sim != null, "pantalla de juego con la partida")
	if gs == null:
		return
	await _close_tray(gs)
	var sim = game.sim
	# 1. L: el libro a pantalla entera, en las reglas
	await _key(KEY_L)
	await tool.frames(14)
	lg = shell.panel("ledger")
	_check(lg != null and lg.is_open() and not lg.side and not lg.compact, "L abre el libro mayor a dos páginas")
	if lg == null:
		return
	_check(String(lg.page) == "reglas", "la primera vez, las reglas del asiento")
	await tool.snap("shell_1_libro")
	# 2. Tab: el cuaderno a la izquierda, el libro a la derecha (una página)
	await _key(KEY_TAB)
	await tool.frames(16)
	nb = shell.panel("notebook")
	_check(nb != null and nb.is_open() and nb.layout == "left", "Tab: el cuaderno a la izquierda")
	_check(lg.is_open() and lg.side and lg.compact, "el libro se acopla a la derecha, una página")
	var lr: Rect2 = lg.debug_state().rect
	_check(nb != null and lr.position.x >= nb.book_rect().end.x, "no se pisan: %s / %s" % [str(lr), str(nb.book_rect()) if nb != null else ""])
	await tool.snap("shell_2_dos_libros")
	# 3. clics: pestaña «Varios» -> «Nuevo asiento» -> plantilla «Estado»
	await _click_node(_find(lg, "Pestana_varios"))
	_check(String(lg.page) == "varios", "clic en la pestaña «Varios»")
	await _click_node(_find(lg, "NuevoAsiento"))
	_check(lg.picker() != null, "«Nuevo asiento» abre el elector de plantillas")
	if lg.picker() == null:
		return
	await _click_at(lg.picker().row_rect("T7").get_center())
	var e := String(lg.selected)
	_check(e != "" and String(sim.q_entry(e).get("template", "")) == "T7", "plantilla «Estado» elegida: %s" % e)
	# 4. arrastrar «Holmes, Mycroft» del Índice al campo «Persona:»
	nb.show_tab("indice")
	await tool.frames(12)
	var chip: Control = _find(nb, "Ent_mycroft")
	var field: Control = _valor(lg, "Campo_persona")
	_check(chip != null and field != null, "chip del índice y campo a la vista")
	if chip != null and field != null:
		await _drag(_center(chip), _center(field))
		_check(String(sim.q_entry(e).lines[0].fields.get("persona", "")) == "mycroft", "chip del índice -> «Persona:»")
	# 5. arrastrar una tarjeta de Recortes al «según» de la línea 1
	nb.show_tab("recortes")
	await tool.frames(16)
	var card := _first_card(nb)
	var slot: Control = _find(lg, "Ranura")
	_check(card != null and slot != null, "tarjeta de recorte y ranura del según a la vista")
	if card != null and slot != null:
		var cid := String(card.id)
		await _drag(_center(card.strip if card.strip != null else card), _center(slot))
		_check((sim.q_entry(e).lines[0].support as Array).has(cid), "tarjeta del cuaderno -> «según»: %s" % str(sim.q_entry(e).lines[0].support))
	# 6. lista cerrada por clic: «Estado en marzo de 1894:» -> «vivo»
	var est: Control = _valor(lg, "Campo_estado")
	if est != null:
		await _click_node(est)
		_check(lg.picker() != null, "clic en el blanco -> su lista cerrada")
		if lg.picker() != null:
			await _click_at(lg.picker().row_rect("vivo").get_center())
			_check(String(sim.q_entry(e).lines[1].fields.get("estado", "")) == "vivo", "lista cerrada por clic")
	await tool.frames(6)
	await tool.snap("shell_3_arrastres")
	# 6b. arrastrar una tarjeta de Recortes a la pestaña «Nuevo folio»: el libro pasa al folio encabezado por ese recorte
	# (si ya abría otro folio, lo reabre: un encabezado, un folio)
	var heads: Array = sim.q_ledger().folios.map(func(fo): return String(fo.head_clip))
	var n_folios: int = heads.size()
	var card2 := _first_card(nb, heads)
	var nf: Control = _find(lg, "NuevoFolio")
	_check(card2 != null and nf != null and nf.is_visible_in_tree(), "tarjeta y pestaña «Nuevo folio» a la vista")
	if card2 != null and nf != null:
		var hid := String(card2.id)
		await _drag(_center(card2.strip if card2.strip != null else card2), _center(nf))
		await tool.frames(6)
		var fid := ""
		for fo in sim.q_ledger().folios:
			if String(fo.head_clip) == hid:
				fid = String(fo.id)
		_check(fid != "" and String(lg.page) == fid, "recorte -> «Nuevo folio»: folio %s encabezado por %s (página %s)" % [fid, hid, lg.page])
		_check(sim.q_ledger().folios.size() == n_folios + 1, "un folio nuevo (%d -> %d)" % [n_folios, sim.q_ledger().folios.size()])
		await tool.snap("shell_3b_folio")
	# 7. Esc: se cierra lo de arriba (el cuaderno); el libro vuelve a dos páginas
	await _key(KEY_ESCAPE)
	await tool.frames(14)
	_check(not nb.is_open() and lg.is_open(), "Esc cierra el cuaderno y deja el libro")
	_check(not lg.side and not lg.compact, "el libro vuelve a pantalla entera")
	# 8. sello: ranura vacía -> elegir el asiento de Relación; casilla «Al sello» del nuevo
	var as6 := String(Model.page_entries(sim, "FO003")[0])
	var as4 := String(Model.page_entries(sim, "varios")[0])
	await _click_node(lg._seal.slot_node(0))
	_check(lg.picker() != null, "clic en la ranura vacía del sello -> elector de asientos")
	if lg.picker() != null:
		await _click_at(lg.picker().row_rect(as6).get_center())
	_check(lg.lot == [as6], "asiento de Relación al sello: %s" % str(lg.lot))
	lg.select_entry(e)
	await tool.frames(4)
	await _click_node(_find(_find(lg, "Pie"), "AlSello"))
	_check(lg.lot.size() == 2 and lg.lot.has(e), "casilla «Al sello»: %s" % str(lg.lot))
	var left0 := int(sim.q_clock().passes_left)
	await _click_node(lg._seal.stamp_box)
	await tool.frames(4)
	_check(lg.confirm_dialog() == null and int(sim.q_clock().passes_left) == left0, "chequeo formal antes de mojar el sello: no gasta")
	_check(String(lg.selected) == e and lg.last_note().begins_with(game.sim.repo.text("pass.formal")), "Lisle junto al asiento que falla: %s" % lg.last_note())
	await tool.snap("shell_4_formal")
	# «Borrar» con confirmación
	await _click_node(_find(_find(lg, "Pie"), "Borrar"))
	_check(lg.confirm_dialog() != null, "borrar pide confirmación")
	if lg.confirm_dialog() != null:
		await _click_node(lg.confirm_dialog().ok_button)
	_check(sim.q_entry(e).is_empty() and not lg.lot.has(e), "borrado y fuera del lote")
	# segundo del lote: el asiento flojo de «Varios»
	await tool.frames(4)
	await _click_node(lg._seal.slot_node(1))
	if lg.picker() != null:
		await _click_at(lg.picker().row_rect(as4).get_center())
	_check(lg.lot == [as6, as4], "lote de dos: %s" % str(lg.lot))
	await _click_node(lg._seal.stamp_box)
	_check(lg.confirm_dialog() != null, "el sello pide confirmación con lo que se pasa")
	await tool.frames(4)
	await tool.snap("shell_5_confirma")
	if lg.confirm_dialog() != null:
		await _click_node(lg.confirm_dialog().ok_button)
	await tool.frames(16)
	_check(int(sim.q_clock().passes_left) == 0 and String(sim.q_entry(as6).ink) == "lapiz", "golpe seco: se gastó la pasada, nada en tinta")
	_check(lg.last_note() == game.sim.repo.text("pass.fail"), "Lisle: «Alguno no se sostiene.»")
	_check(bool(lg._seal.pad.dry), "el tampón queda seco")
	await tool.snap("shell_6_seco")
	await _key(KEY_ESCAPE)
	await tool.frames(12)
	_check(not lg.is_open(), "Esc cierra el libro")
	# 9. visita: Kensington con Watson; L -> libro a la derecha, arriba de la banda; presentar un asiento
	var c: Dictionary = sim.q_clock()
	if String(c.phase) != "desk" or bool(c.get("outing_done", false)):
		print("SHELL (sin visita: fase ", c.phase, ")")
		_summary()
		return
	var r: Dictionary = game.act({"t": "go", "place": "L4"})
	_check(bool(r.get("ok", false)), "go L4: %s" % str(r.get("err", "")))
	await tool.frames(60)
	gs.on_char("watson")
	await tool.frames(20)
	_check(shell.is_open("scene"), "panel de escena abierto")
	var sp = shell.panel("scene")
	if sp != null and sp.has_method("close_sub"):
		sp.close_sub()   # el clic en el personaje abre «Preguntar»; aquí se va a presentar
	await tool.frames(8)
	await _key(KEY_L)
	await tool.frames(16)
	_check(lg.is_open() and lg.side, "en la visita el libro va a la derecha")
	_check(not lg._seal.visible, "el sello se quedó en el escritorio")
	_check(shell.is_open("scene") and shell.is_open("ledger"), "escena y libro a la vez (dos paneles)")
	var band = sp.get("band") if sp != null and is_instance_valid(sp) and "band" in sp else null
	_check(band is Control, "banda de la escena a la vista")
	if band is Control:
		var bt: float = band.get_global_rect().position.y
		var bottom: float = lg._stage.position.y + lg._book.size.y * lg._stage.scale.y
		_check(bottom <= bt + 0.5, "el libro termina arriba de la banda (%s <= %s)" % [bottom, bt])
	lg.show_page("FO003")
	await tool.frames(8)
	await tool.snap("shell_7_visita")
	var row: Control = _find(lg, "Renglon_" + as6)
	var who: Control = _find(sp, "Personaje_watson") if sp != null else null
	_check(row != null and who != null, "renglón del asiento y Watson en la banda")
	if row != null and who != null:
		await _drag(_center(row) + Vector2(-80, 0), _center(who))
		await tool.frames(10)
		var pb = sp.get("present_bar")
		_check(pb != null and pb.visible, "soltar el asiento sobre Watson -> presentar (primer paso)")
		await tool.snap("shell_8_presentar")
	_summary()
	game.end_session()

# ------------------------------------------------------------------ utilidades
func _summary() -> void:
	print("SHELL RESUMEN %d fallas" % _fails)

func _check(cnd: bool, what: String) -> void:
	if not cnd:
		_fails += 1
	print("SHELL %s %s" % ["OK" if cnd else "FALLA", what])

func _find(n: Node, nm: String) -> Node:
	if n == null:
		return null
	if n.name == nm:
		return n
	for ch in n.get_children():
		var f := _find(ch, nm)
		if f != null:
			return f
	return null

func _valor(root: Node, campo: String) -> Control:
	var h := _find(root, campo)
	return h.get_node_or_null("Valor") if h != null else null

# Primera tarjeta de recorte visible del cuaderno (salvo las de `skip`: p. ej. recortes que ya encabezan un folio).
func _first_card(n: Node, skip: Array = []) -> Node:
	if n.has_method("preview_text") and "id" in n and "strip" in n and String(n.get("id")) != "" and not skip.has(String(n.get("id"))) and (n as Control).is_visible_in_tree():
		return n
	for ch in n.get_children():
		var f := _first_card(ch, skip)
		if f != null:
			return f
	return null

func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()

# Cierra lo que el amanecer dejó abierto (bandeja) con la pila del Shell (Shell sólo libera lo que él creó).
func _close_tray(gs) -> void:
	for _i in 6:
		var top = shell.top()
		if top == null:
			break
		shell.pop()
		await tool.frames(8)
	if gs.has_method("back"):
		for _i in 3:
			if not gs.back():
				break
			await tool.frames(6)
	await tool.frames(20)

func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	var last := DisplayServer.window_get_position()
	var still := 0
	for _i in 120:
		await tool.frames(1)
		var p := DisplayServer.window_get_position()
		still = still + 1 if p == last else 0
		last = p
		if still >= 10 and DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	Input.parse_input_event(k)
	await tool.frames(2)
	var u := k.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await tool.frames(2)

func _mm(pos: Vector2, mask := 0) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last
	ev.button_mask = mask
	_last = pos
	Input.parse_input_event(ev)

func _btn(p: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

func _click_at(p: Vector2) -> void:
	_mm(p)
	await tool.frames(3)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(4)

func _click_node(c: Control) -> void:
	if c == null:
		_check(false, "nodo para hacer clic")
		return
	await _click_at(_center(c))

func _drag(a: Vector2, b: Vector2) -> void:
	_mm(a)
	await tool.frames(3)
	_btn(a, true)
	await tool.frames(2)
	for k in range(1, 13):
		_mm(a.lerp(b, float(k) / 12.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	_mm(b, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(2)
	_btn(b, false)
	await tool.frames(6)
