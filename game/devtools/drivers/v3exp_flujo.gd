# devtools/drivers/v3exp_flujo.gd — UI-EXPEDIENTE (GDD_v3 §7.2 P3): el Expediente Holmes con eventos REALES de mouse y
# teclado (warp_mouse + Input.parse_input_event), SIN --fast. Captura cada paso en .work/shots/<prefijo>_<paso>.png.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3exp res://devtools/drivers/v3exp_flujo.gd --mute
# Recorrido: partida nueva -> (prólogo) abre el expediente desde el escritorio (clic en la carpeta 3D; si el nodo o el
# panel «dossier» todavía no existen, se abre por la Shell y se informa RESPALDO) -> el cuaderno se acopla a la izquierda
# -> arrastra dos recortes del cuaderno a las ranuras -> elige la respuesta con el selector (tecleando en el buscador) ->
# «Pasar en limpio» con una prueba que no va -> «Algo no cierra.» -> cambia la prueba arrastrando otra encima ->
# «Pasar en limpio» -> tinta con el texto de Lisle (revelado) -> otra hoja: clic derecho saca una prueba -> Esc cierra
# carpeta y cuaderno.
# Datos: por defecto, el doble v3exp_fake.gd sobre la GameSim REAL de la partida (recortes inyectados con textos de las
# crónicas; el expediente con el contrato de CORE). DBG_REAL=1 usa el expediente real de CORE si ya existe (q_dossier y
# dq_*): los recortes se inyectan con las etiquetas y entidades de la ruta Q1.R2 y decide el validador de CORE.
# Salida: «V3EXP OK|FALLA <paso>», «V3EXP RESPALDO <paso>» y «V3EXP RESUMEN n fallas, m respaldos».
extends RefCounted

const Fake = preload("res://devtools/drivers/v3exp_fake.gd")
const Expediente = preload("res://ui/expediente/expediente.gd")

var tool
var shell
var g
var vp: Viewport
var ex = null
var nb = null
var fk = null
var real := false
var fails := 0
var fallbacks := 0
var _last := Vector2.ZERO
var ids := {}

func drive(p_tool, scene) -> void:
	tool = p_tool
	# vigía: un error en mitad de la corrutina dejaría a shot.gd esperando con la ventana abierta
	tool.create_timer(300.0).timeout.connect(func():
		print("V3EXP VIGIA: se corta a los 300 s")
		tool.quit(2))
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		print("V3EXP sin Shell")
		return
	g.save_path = "user://saves/v3exp.jsonl"
	for suf in ["", ".bak", ".tmp", ".fin"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	await shell.new_game(7)
	await _wait(2.0)
	if g.sim == null:
		_check(false, "partida nueva")
		_summary()
		return
	real = OS.get_environment("DBG_REAL") == "1" and g.sim.has_method("q_dossier")
	_setup_data()
	await _wait(0.5)
	await _snap("00_escritorio")
	await _open_dossier()
	if ex == null:
		_summary()
		return
	await _wait(0.8)
	nb = shell.panel("notebook") if shell.is_open("notebook") else null
	_check(nb != null, "el cuaderno se abre acoplado al abrir la carpeta")
	if nb != null:
		_check(String(nb.layout) == "left", "el cuaderno, a la izquierda")
		nb.show_tab("recortes")
	await _wait(0.4)
	await _snap("01_abierto")
	await _read_encargo()
	_tutor_into_folder()
	await _wait(0.3)
	await _snap("01c_nota_en_la_carpeta")
	await _fill_q1()
	await _pass_wrong()
	await _fix_and_ink()
	await _other_sheet()
	await _close_all()
	_summary()
	g.end_session()

# ------------------------------------------------------------------ datos
func _setup_data() -> void:
	if real:
		print("V3EXP datos: expediente REAL de CORE")
		fk = null
		var Clipper = load("res://core/deduction/clipper.gd")
		ids.a = Clipper.inject(g.sim.st, g.sim.repo, {"text": "Una ojeada me bastó para ver que la senda terminaba de pronto en la pared.", "origin": "D03", "doc": "D03", "copy": "D03@Crane", "src_type": "cronica",
			"src_line": "«El problema final», crónica", "ents": ["fina", "reichenbach", "pared"], "tags": ["a:fina_impreso_sin_raspadura"]})
		ids.b = Clipper.inject(g.sim.st, g.sim.repo, {"text": "Une marque fraîche sur la roche, comme celle d'un clou de soulier.", "origin": "D05", "doc": "D05", "copy": "D05@BM", "src_type": "prensa_extranjera",
			"src_line": "Journal de Genève, 7 de mayo de 1891", "ents": ["reichenbach", "roca", "raspadura"], "tags": ["a:raspadura_registrada"]})
		ids.c = Clipper.inject(g.sim.st, g.sim.repo, {"text": "Más arriba del final del sendero hay una cornisa que no se ve desde abajo.", "origin": "D08", "doc": "D08", "copy": "D08@BM", "src_type": "guia",
			"src_line": "Baedeker, Suiza, 1891", "ents": ["reichenbach", "cornisa"], "tags": ["a:cornisa_existe"]})
		return
	print("V3EXP datos: doble v3exp_fake sobre la GameSim real")
	fk = Fake.new(g.sim)
	ids.a = fk.add_clip({"text": "Una ojeada me bastó para ver que la senda terminaba de pronto en la pared.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», The Strand Magazine, diciembre de 1893 · crónica", "ents": ["reichenbach"]})
	ids.b = fk.add_clip({"text": "Une marque fraîche sur la roche, comme celle d'un clou de soulier.", "origin": "D05", "doc": "D05",
		"src_line": "Journal de Genève, 7 de mayo de 1891 · prensa extranjera", "ents": ["reichenbach"]})
	ids.c = fk.add_clip({"text": "Más arriba del final del sendero hay una cornisa que no se ve desde abajo.", "origin": "D08", "doc": "D08",
		"src_line": "Baedeker, Suiza, 1891 · guía de viaje", "ents": ["reichenbach"]})
	ids.d = fk.add_clip({"text": "Lo dejé allí, apoyado en la roca, con los brazos cruzados, mirando el agua.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», The Strand Magazine, diciembre de 1893 · crónica", "ents": ["reichenbach"]})
	fk.options = []
	for o in [["raspadura", "Raspadura", "concepto"], ["marca_en_la_roca", "Marca en la roca", "concepto"], ["cornisa", "Cornisa", "lugar"],
			["sendero", "Sendero de Reichenbach", "lugar"], ["pared", "Pared de roca", "objeto"], ["bastón", "Bastón de alpinista", "objeto"],
			["cigarrera", "Cigarrera", "objeto"], ["carta", "Carta de despedida", "objeto"], ["cascada", "Cascada de Reichenbach", "lugar"],
			["meiringen", "Meiringen", "lugar"], ["gobierno", "Gobierno", "concepto"]]:
		fk.options.append({"id": o[0], "label": o[1], "kind": o[2]})
	fk.add_question({"id": "Q1", "text": "¿Qué no contó Watson?", "origin": "La pregunta del cliente, en el encargo.",
		"doubts": ["¿Qué dice la crónica, palabra por palabra, del sendero y de la pared?", "¿Hay otra versión del texto, anterior a la que se imprimió?", "¿Qué publicaron los diarios suizos esos días?"],
		"acepta": ["concepto", "objeto"], "ok_answers": ["raspadura", "marca_en_la_roca"], "ok_pairs": [[ids.a, ids.b]],
		"ink_text": "Watson vio en la roca una raspadura fresca, como la que deja el clavo de una bota, y la escribió. En la revista esa frase no está: alguien la sacó antes de imprimir."})
	fk.add_question({"id": "Q2", "text": "¿Qué pasó en la cascada?", "origin": "Me lo pregunté leyendo «El problema final».",
		"doubts": ["¿Cómo era el sendero, y qué había más arriba?", "¿Qué dijeron los guías y la gente del lugar?", "¿Hay fotos o guías de viaje de la cascada?"],
		"acepta": ["lugar", "concepto", "objeto"], "ok_answers": ["cornisa"], "ok_pairs": [[ids.a, ids.c]],
		"ink_text": "La pared no era lisa. Más arriba del final del sendero hay una cornisa que no se ve desde abajo. Un hombre que llega ahí desaparece sin caer."})

# ------------------------------------------------------------------ abrir desde el escritorio
func _open_dossier() -> void:
	var opened := false
	# como un jugador nuevo: primero pasa lo que dicen Pell y Harris (clic en la tarjeta de lo dicho) y lee la nota
	await _speech_through()
	await _wait(0.8)
	await _snap("00a_tras_lo_dicho")
	var tut := _tutor_text()
	print("V3EXP nota del instructor: «%s»" % tut)
	_check(tut.to_lower().contains("expediente"), "la nota del instructor pide abrir el expediente")
	var body = shell.world.node_body("expediente") if shell.world.has_method("node_body") else null
	if body == null:
		print("V3EXP el escritorio no tiene el nodo 3D «expediente»")
	else:
		var p := _node_pos("expediente")
		print("V3EXP carpeta 3D en pantalla: %s" % str(p))
		if p.x >= 0.0:
			_mm(p)
			await tool.frames(4)
			await _snap("00a_sobre_la_carpeta")
			await _click(p)
			await _wait(0.8)
			opened = shell.is_open("dossier")
			if not opened:
				print("V3EXP tras el clic: arriba=%s" % str(shell.top_kind() if shell.has_method("top_kind") else "?"))
	_check(opened, "abrir el expediente con un clic en la carpeta del escritorio")
	if not opened:
		await _snap("00b_clic_carpeta")
		await _key(KEY_ESCAPE)   # la tarjeta de examen que haya abierto el clic (sin vínculo «dossier» en data/map.json)
		await _wait(0.4)
		fallbacks += 1
		print("V3EXP RESPALDO abrir: en el prólogo (lámina PRO) la carpeta no es un nodo clicable (data/plates/PRO.json nodes, CONTENIDO); el día 1 lo prueba v3exp_dia1.gd")
		var panels: Dictionary = shell.get_script().get_script_constant_map().get("PANELS", {})
		if panels.has("dossier"):
			ex = shell.open_panel("dossier")
		else:
			ex = Expediente.new()
			ex.sounds = false
			shell.add_child(ex)
			ex.set_shell(shell)
			ex.handle_back = false
			if fk != null:
				ex.sim = fk
			ex.open()
			shell.push(ex, "dossier")
			ex.call("_sync_with_shell")
	else:
		ex = shell.panel("dossier")
	if ex == null:
		_check(false, "panel del expediente")
		return
	if fk != null and ex.sim != fk:
		ex.set_sim(fk)
		ex.open("Q1")
	if shell.is_open("notebook"):
		shell.panel("notebook").refresh()

# Paso 1 del tutorial (GDD_v3 §6.9): «abra el expediente y lea el encargo». El lector entra como tercer panel (la
# Shell cierra el cuaderno) y al volver la carpeta lo trae de nuevo.
func _read_encargo() -> void:
	var r: Rect2 = ex.rect_of("encargo")
	_check(r.size.x > 0.0, "«El encargo» a la vista en el índice")
	if r.size.x <= 0.0:
		return
	var had_nb: bool = shell.is_open("notebook")
	await _click(r.get_center())
	await _wait(1.2)
	_check(shell.reader_open(), "clic en «El encargo» abre el lector")
	await _snap("01b_encargo")
	await _key(KEY_ESCAPE)
	await _wait(0.8)
	_check(not shell.reader_open() and ex.is_open(), "Esc deja el encargo y vuelve a la carpeta")
	if had_nb:
		_check(shell.is_open("notebook"), "el cuaderno vuelve acoplado")
	nb = shell.panel("notebook") if shell.is_open("notebook") else null
	if nb != null:
		nb.show_tab("recortes")
	await _wait(0.3)

# La nota del instructor (capa 35) se acopla con GameScreen._tutor_dock, que todavía no conoce la carpeta (UI-MUNDO):
# cae sobre la hoja y tapa la ranura de la respuesta. Parche propuesto: acoplarla en Expediente.tutor_rect() (la solapa
# del índice). Mientras tanto, el driver lo simula cada cuadro (después del _process de la pantalla) y lo informa.
var _tutor_sim := false
func _tutor_into_folder() -> void:
	var gsc = shell.game_screen
	var tut = gsc.get("tutor") if gsc != null and "tutor" in gsc else null
	if not (tut is Control) or not (tut as Control).is_visible_in_tree():
		return
	# la solapa del índice es SU lugar (tutor_rect): lo que no puede tapar es la hoja (respuesta, pruebas, botón)
	var tr: Rect2 = (tut as Control).get_global_rect()
	var over := false
	for k in [["hoja", 0], ["respuesta", 0], ["prueba", 0], ["prueba", 1]]:
		var rr: Rect2 = ex.rect_of(String(k[0]), int(k[1]))
		if rr.size.x > 0.0 and tr.intersects(rr):
			over = true
	print("V3EXP nota del instructor en %s" % str(tr))
	_check(not over, "la nota del instructor no tapa la hoja de la pregunta")
	if not over or _tutor_sim:
		return
	_tutor_sim = true
	fallbacks += 1
	print("V3EXP RESPALDO nota del instructor: se simula el parche propuesto (GameScreen._tutor_dock -> Expediente.tutor_rect())")
	# GameScreen recalcula el dock en cada _process: mientras la carpeta esté abierta se pausa ese _process y se pone el
	# dock que daría el parche (la solapa del índice)
	gsc.set_process(false)
	var follow := func():
		if is_instance_valid(tut) and is_instance_valid(ex) and ex.is_open():
			var r: Rect2 = ex.tutor_rect()
			if r.size.x > 0.0:
				tut.dock = r
	tool.process_frame.connect(follow)
	ex.closed.connect(func():
		tool.process_frame.disconnect(follow)
		if is_instance_valid(gsc):
			gsc.set_process(true), CONNECT_ONE_SHOT)

# ------------------------------------------------------------------ hoja Q1
func _card_pos(id: String) -> Vector2:
	if nb == null:
		return Vector2(-1, -1)
	var card = nb.page("recortes").card(id)
	if card == null:
		return Vector2(-1, -1)
	return (card.strip as Control).get_global_rect().get_center()

func _fill_q1() -> void:
	if nb == null:
		fallbacks += 1
		print("V3EXP RESPALDO pruebas por la API (sin cuaderno)")
		ex.set_proof("Q1", 0, ids.a)
		ex.set_proof("Q1", 1, ids.c)
	else:
		await _drag(_card_pos(ids.a), ex.rect_of("prueba", 0).get_center())
		await _wait(0.5)
		await _snap("02_una_prueba")
		_check(ex.debug_state().proofs[0] == ids.a, "arrastrar un recorte del cuaderno a la prueba 1")
		await _drag(_card_pos(ids.c), ex.rect_of("prueba", 1).get_center())
		await _wait(0.5)
		_check(ex.debug_state().proofs[1] == ids.c, "arrastrar otro recorte a la prueba 2")
	await _click(ex.rect_of("respuesta").get_center())
	await _wait(0.5)
	var p = ex.picker()
	_check(p != null, "clic en «Respuesta» abre el selector")
	if p == null:
		return
	await _snap("03_selector")
	_check(p.visible_ids().size() <= 7, "selector: como mucho siete a la vista")
	await _type("raspa")
	await _wait(0.4)
	await _snap("04_selector_buscar")
	var r: Rect2 = p.row_rect("raspadura")
	_check(r.size.x > 0.0, "el buscador encuentra «Raspadura»")
	await _click(r.get_center())
	await _wait(0.6)
	_check(ex.debug_state().answer == "Raspadura", "la respuesta queda a lápiz")
	_check(ex.debug_state().pass, "con las tres ranuras llenas aparece «Pasar en limpio»")
	await _snap("05_lapiz")
	await _snap_named("v3exp_lapiz")

func _pass_wrong() -> void:
	await _click(ex.rect_of("pasar").get_center())
	await _wait(0.5)
	var st: Dictionary = ex.debug_state()
	_check(st.no_cierra and st.state == "lapiz", "una prueba que no va: «Algo no cierra.» y la hoja sigue en lápiz")
	await _snap("06_no_cierra")
	await _snap_named("v3exp_no_cierra")
	await _wait(3.2)
	_check(not ex.debug_state().no_cierra, "«Algo no cierra.» se va solo (3 s)")

func _fix_and_ink() -> void:
	if nb != null:
		await _drag(_card_pos(ids.b), ex.rect_of("prueba", 1).get_center())
	else:
		ex.set_proof("Q1", 1, ids.b)
	await _wait(0.5)
	_check(ex.debug_state().proofs[1] == ids.b, "soltar sobre una prueba ocupada la reemplaza")
	await _click(ex.rect_of("pasar").get_center())
	await _wait(0.5)
	await _snap("07_tinta_escribiendo")
	await _wait(1.6)
	var st: Dictionary = ex.debug_state()
	_check(st.state == "tinta", "cierra: la hoja pasa a tinta")
	_check(String(st.ink_text).begins_with("Watson vio en la roca") or real, "con el texto de Lisle")
	_check(st.selected == "Q1", "la carpeta se queda en esa hoja")
	await _snap("08_tinta")
	await _snap_named("v3exp_tinta")

func _other_sheet() -> void:
	var r: Rect2 = ex.row_rect("Q2")
	if r.size.x <= 0.0:
		print("V3EXP (sin Q2 abierta: se salta la otra hoja)")
		return
	await _click(r.get_center())
	await _wait(0.5)
	_check(ex.debug_state().selected == "Q2", "clic en otra pregunta del índice")
	if nb != null:
		await _drag(_card_pos(ids.a), ex.rect_of("prueba", 0).get_center())
		await _wait(0.4)
		_check(ex.debug_state().proofs[0] == ids.a, "un recorte puede probar dos preguntas")
		await _snap("09_q2")
		await _rclick(ex.rect_of("prueba", 0).get_center())
		await _wait(0.4)
		_check(ex.debug_state().proofs[0] == "", "clic derecho en una prueba la saca")
		_check(ex.is_open(), "y la carpeta sigue abierta")
	var f: Rect2 = ex.rect_of("en_tinta")
	if f.size.x > 0.0:
		await _click(f.get_center())
		await _wait(0.4)
		await _snap("10_en_tinta_desplegado")

func _close_all() -> void:
	await _key(KEY_ESCAPE)
	await _wait(0.8)
	_check(not ex.is_open(), "Esc cierra la carpeta")
	_check(not shell.is_open("notebook"), "y el cuaderno que abrió")
	await _snap("11_cerrado")

func _speech_through(maxn := 40) -> void:
	var gsc = shell.game_screen
	var sp = gsc.get("speech") if gsc != null and "speech" in gsc else null
	if not (sp is Control):
		return
	var n := 0
	while (sp as Control).is_visible_in_tree() and n < maxn:
		await _click((sp as Control).get_global_rect().get_center())
		await _wait(0.35)
		n += 1
	print("V3EXP clics para pasar lo dicho: %d" % n)

func _tutor_text() -> String:
	var gsc = shell.game_screen
	var tut = gsc.get("tutor") if gsc != null and "tutor" in gsc else null
	if not (tut is Control) or not (tut as Control).is_visible_in_tree():
		return ""
	var out: Array = []
	for l in (tut as Control).find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out.append((l as Label).text)
	for r in (tut as Control).find_children("*", "RichTextLabel", true, false):
		if (r as RichTextLabel).is_visible_in_tree():
			out.append((r as RichTextLabel).get_parsed_text())
	return " / ".join(PackedStringArray(out))

# ------------------------------------------------------------------ mouse y teclado (como w3int_flow)
func _node_pos(id: String) -> Vector2:
	var b: Node3D = shell.world.node_body(id)
	var cam: Camera3D = shell.world.camera()
	if b == null or cam == null or cam.is_position_behind(b.global_position):
		return Vector2(-1, -1)
	var c := cam.unproject_position(b.global_position)
	for rr in range(0, 160, 6):
		for k in 16:
			var p := c + Vector2.from_angle(TAU * k / 16.0) * float(rr)
			if String(shell.world.pick(p).get("id", "")) == id:
				return p
			if rr == 0:
				break
	return Vector2(-1, -1)

func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	for _i in 60:
		await tool.frames(1)
		if DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _sync_mouse(pos: Vector2, mask := 0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _i in 30:
		_mm(pos, mask)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(pos) < 1.5:
			return

func _mm(pos: Vector2, mask := 0) -> void:
	Input.warp_mouse(pos)
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.relative = pos - _last
	ev.button_mask = mask
	_last = pos
	Input.parse_input_event(ev)

func _btn(p: Vector2, pressed: bool, idx := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	var m := MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	ev.button_mask = m if pressed else 0
	Input.parse_input_event(ev)

func _click(p: Vector2) -> void:
	if p.x < 0.0:
		_check(false, "clic sin destino")
		return
	_mm(p)
	await tool.frames(2)
	await _sync_mouse(p)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(4)

func _rclick(p: Vector2) -> void:
	_mm(p)
	await tool.frames(2)
	await _sync_mouse(p)
	_btn(p, true, MOUSE_BUTTON_RIGHT)
	await tool.frames(1)
	_btn(p, false, MOUSE_BUTTON_RIGHT)
	await tool.frames(4)

func _drag(a: Vector2, b: Vector2) -> void:
	if a.x < 0.0 or b.x < 0.0:
		_check(false, "arrastre sin origen o destino")
		return
	_mm(a)
	await tool.frames(2)
	await _sync_mouse(a)
	_btn(a, true)
	await tool.frames(2)
	for k in range(1, 25):
		_mm(a.lerp(b, float(k) / 24.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
		if k == 16:
			await _snap("arrastre")
	await _sync_mouse(b, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(3)
	_btn(b, false)
	await tool.frames(8)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
	await tool.frames(3)

func _type(text: String) -> void:
	for i in text.length():
		var ch := text[i]
		var e := InputEventKey.new()
		e.keycode = OS.find_keycode_from_string(ch.to_upper())
		e.physical_keycode = e.keycode
		e.unicode = ch.unicode_at(0)
		e.pressed = true
		Input.parse_input_event(e)
		var u := e.duplicate()
		u.pressed = false
		Input.parse_input_event(u)
		await tool.frames(2)

func _wait(sec: float) -> void:
	await tool.create_timer(sec).timeout

var _n := 0
func _snap(name: String) -> void:
	_n += 1
	await tool.snap(name)

# Copia con el nombre fijo de los criterios (v3exp_lapiz, v3exp_tinta, v3exp_no_cierra).
func _snap_named(full: String) -> void:
	await tool.frames(1)
	await RenderingServer.frame_post_draw
	var img: Image = tool.root.get_viewport().get_texture().get_image()
	var p: String = ProjectSettings.globalize_path("res://").path_join("../.work/shots/" + full + ".png").simplify_path()
	img.save_png(p)
	print("SNAP ", p)

func _check(c: bool, what: String) -> void:
	if c:
		print("V3EXP OK ", what)
	else:
		fails += 1
		print("V3EXP FALLA ", what)

func _summary() -> void:
	print("V3EXP RESUMEN %d fallas, %d respaldos" % [fails, fallbacks])
