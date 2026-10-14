# devtools/drivers/v3exp_vista.gd — UI-EXPEDIENTE: capturas de la carpeta y el cuaderno SIN depender de core/sim (doble
# suelto v3exp_fake.gd sobre data/ real), con eventos reales de mouse y teclado, sin --fast:
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3vista res://devtools/drivers/v3exp_vista.gd
# Sirve para revisar el aspecto mientras otros paquetes cambian el núcleo; el recorrido completo sobre la partida real
# es v3exp_flujo.gd. Capturas: .work/shots/v3vista_<paso>.png. Salida: «V3VISTA OK|FALLA …».
extends RefCounted

const Fake = preload("res://devtools/drivers/v3exp_fake.gd")
const Expediente = preload("res://ui/expediente/expediente.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")
const BluePencil = preload("res://ui/epilogue/blue_pencil.gd")
const Paper = preload("res://ui/kit/paper.gd")

var tool
var vp: Viewport
var fk
var ex
var sh
var fails := 0
var _last := Vector2.ZERO
var ids := {}

class MiniShell extends Node:
	signal panel_opened(kind: String)
	signal panel_closed(kind: String)
	var panels := {}
	var sim_ref = null
	func is_open(kind: String) -> bool:
		return panels.has(kind) and is_instance_valid(panels[kind]) and bool(panels[kind].visible)
	func panel(kind: String):
		return panels.get(kind)
	func open_panel(kind: String, _args := []):
		if kind != "notebook":
			return null
		var n = panels.get(kind)
		if n == null:
			n = Notebook.new()
			n.sounds = false
			n.sim_override = sim_ref
			n.act_fn = func(a): return sim_ref.apply(a)
			var layer := CanvasLayer.new()
			layer.layer = 20
			add_child(layer)
			layer.add_child(n)
			n.set_shell(self)
			panels[kind] = n
		n.open()
		panel_opened.emit(kind)
		return n
	func close_kind(kind: String) -> void:
		var n = panels.get(kind)
		if n != null:
			n.close()
		panel_closed.emit(kind)

func drive(p_tool, scene) -> void:
	tool = p_tool
	# vigía: un error en mitad de la corrutina dejaría a shot.gd esperando con la ventana abierta
	tool.create_timer(300.0).timeout.connect(func():
		print("V3VISTA VIGIA: se corta a los 300 s")
		tool.quit(2))
	vp = tool.root.get_viewport()
	await tool.frames(5)
	var bg := ColorRect.new()
	bg.color = Color("5b4a3a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(bg)
	var r = load("res://core/data/data_repo.gd").load_dir("res://data")
	fk = Fake.new(null, r)
	_data()
	sh = MiniShell.new()
	sh.sim_ref = fk
	scene.add_child(sh)
	ex = Expediente.new()
	ex.sim = fk
	ex.handle_back = true
	sh.panels["dossier"] = ex
	scene.add_child(ex)
	ex.set_shell(sh)
	ex.open()
	await tool.frames(30)
	var nb = sh.panel("notebook")
	_check(nb != null and String(nb.layout) == "left", "cuaderno acoplado a la izquierda")
	await tool.snap("01_abierto")
	# arrastrar dos recortes del cuaderno a las ranuras (eventos reales)
	await _drag(_card(nb, ids.a), ex.rect_of("prueba", 0).get_center(), "02_arrastrando")
	await _wait(0.4)
	_check(ex.debug_state().proofs[0] == ids.a, "prueba 1 por arrastre")
	await _drag(_card(nb, ids.c), ex.rect_of("prueba", 1).get_center())
	await _wait(0.4)
	_check(ex.debug_state().proofs[1] == ids.c, "prueba 2 por arrastre")
	# la respuesta con el selector y el buscador
	await _click(ex.rect_of("respuesta").get_center())
	await _wait(0.4)
	await tool.snap("03_selector")
	await _type("raspa")
	await _wait(0.3)
	await tool.snap("04_buscar")
	var p = ex.picker()
	if p != null:
		await _click(p.row_rect("raspadura").get_center())
	await _wait(0.5)
	_check(ex.debug_state().answer == "Raspadura", "respuesta elegida en el selector")
	await tool.snap("05_lapiz")
	await _click(ex.rect_of("pasar").get_center())
	await _wait(0.4)
	_check(ex.debug_state().no_cierra, "«Algo no cierra.»")
	await tool.snap("06_no_cierra")
	await _drag(_card(nb, ids.b), ex.rect_of("prueba", 1).get_center())
	await _wait(0.4)
	await _click(ex.rect_of("pasar").get_center())
	await _wait(0.5)
	await tool.snap("07_escribiendo")
	await _wait(1.6)
	_check(ex.debug_state().state == "tinta", "tinta")
	await tool.snap("08_tinta")
	# otra hoja: misma papel -> forma
	await _click(ex.row_rect("Q2").get_center())
	await _wait(0.4)
	await _drag(_card(nb, ids.a), ex.rect_of("prueba", 0).get_center())
	await _drag(_card(nb, ids.d), ex.rect_of("prueba", 1).get_center())
	await _wait(0.4)
	await tool.snap("09_mismo_papel")
	await _rclick(ex.rect_of("prueba", 1).get_center())
	await _wait(0.4)
	_check(ex.debug_state().proofs[1] == "", "clic derecho saca la prueba")
	await _click(ex.rect_of("en_tinta").get_center())
	await _wait(0.3)
	await tool.snap("10_q2")
	# el cuaderno solo (tarjetas)
	_key(KEY_ESCAPE)
	await _wait(0.6)
	_check(not ex.is_open() and not sh.is_open("notebook"), "Esc cierra carpeta y cuaderno")
	sh.open_panel("notebook")
	await _wait(0.6)
	await tool.snap("11_cuaderno")
	sh.close_kind("notebook")
	# lápiz azul
	fk.blue = [{"kind": "missing", "q": "Q2", "note": "Falta: lo que no se ve desde el sendero."},
		{"kind": "wrong", "q": "Q2", "note": "Corríjalo: la cornisa no se ve desde el sendero."}]
	fk.drafts["Q2"] = {"answer": "sendero", "proofs": [ids.a, ids.c]}
	var bp = BluePencil.new()
	bp.fast = true
	scene.add_child(bp)
	bp.open(fk, null)
	await _wait(0.6)
	await tool.snap("12_lapiz_azul")
	print("V3VISTA RESUMEN %d fallas" % fails)

func _data() -> void:
	ids.a = fk.add_clip({"text": "Una ojeada me bastó para ver que la senda terminaba de pronto en la pared.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», The Strand Magazine, diciembre de 1893 · crónica", "ents": ["reichenbach", "pared"]})
	ids.b = fk.add_clip({"text": "Une marque fraîche sur la roche, comme celle d'un clou de soulier.", "origin": "D05", "doc": "D05",
		"src_line": "Journal de Genève, 7 de mayo de 1891 · prensa extranjera", "ents": ["reichenbach"]})
	ids.c = fk.add_clip({"text": "Más arriba del final del sendero hay una cornisa que no se ve desde abajo.", "origin": "D08", "doc": "D08",
		"src_line": "Baedeker, Suiza, 1891 · guía de viaje", "ents": ["reichenbach"]})
	ids.d = fk.add_clip({"text": "Lo dejé allí, apoyado en la roca, con los brazos cruzados, mirando el agua.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», The Strand Magazine, diciembre de 1893 · crónica", "ents": ["reichenbach"]})
	ids.e = fk.add_clip({"text": "Aviso: se busca testigo de lo ocurrido en el Reichenbach el 4 de mayo de 1891.", "origin": "D23", "doc": "D23",
		"src_line": "Encargo del señor Pell, lunes 26 de marzo de 1894 · papel privado", "ents": ["reichenbach"]})
	fk.options = []
	for o in [["raspadura", "Raspadura", "concepto"], ["marca_en_la_roca", "Marca en la roca", "concepto"], ["cornisa", "Cornisa", "lugar"],
			["sendero", "Sendero de Reichenbach", "lugar"], ["pared", "Pared de roca", "objeto"], ["baston", "Bastón de alpinista", "objeto"],
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
		"ink_text": "La pared no era lisa. Más arriba del final del sendero hay una cornisa que no se ve desde abajo."})
	fk.add_question({"id": "Q3", "text": "¿Quién me escribe las cartas sin firma?", "origin": "Me lo pregunté al recibir la primera carta a máquina.",
		"doubts": ["¿Cómo sabe lo que hice, y dónde pudo verlo?", "¿De dónde sale este papel, y quién lo usa?", "¿Qué sé de la gente que rodeaba a Holmes?"],
		"acepta": ["persona"], "ok_answers": [], "ok_pairs": []})

func _card(nb, id: String) -> Vector2:
	var c = nb.page("recortes").card(id) if nb != null else null
	return (c.strip as Control).get_global_rect().get_center() if c != null else Vector2(-1, -1)

# Pantalla de diseño -> ventana (con --resolution distinta de 1600x900 el lienzo se estira; como v3mundo_base._win).
func _win(p: Vector2) -> Vector2:
	var vs: Vector2 = tool.root.get_visible_rect().size
	var ws := Vector2(DisplayServer.window_get_size())
	if vs.x <= 0.0 or vs.y <= 0.0 or ws.x <= 0.0:
		return p
	var sc := minf(ws.x / vs.x, ws.y / vs.y)
	return p * sc + (ws - vs * sc) * 0.5

func _mm(pos: Vector2, mask := 0) -> void:
	var wp := _win(pos)
	Input.warp_mouse(wp)
	var ev := InputEventMouseMotion.new()
	ev.position = wp
	ev.global_position = wp
	ev.relative = pos - _last
	ev.button_mask = mask
	_last = pos
	Input.parse_input_event(ev)

func _btn(p: Vector2, pressed: bool, idx := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = idx
	ev.pressed = pressed
	ev.position = _win(p)
	ev.global_position = ev.position
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if idx == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	Input.parse_input_event(ev)

func _sync(pos: Vector2, mask := 0) -> void:
	for _i in 20:
		_mm(pos, mask)
		await tool.frames(1)
		if vp.get_mouse_position().distance_to(pos) < 1.5:
			return

func _click(p: Vector2) -> void:
	if p.x < 0.0:
		_check(false, "clic sin destino")
		return
	await _sync(p)
	_btn(p, true)
	await tool.frames(1)
	_btn(p, false)
	await tool.frames(4)

func _rclick(p: Vector2) -> void:
	await _sync(p)
	_btn(p, true, MOUSE_BUTTON_RIGHT)
	await tool.frames(1)
	_btn(p, false, MOUSE_BUTTON_RIGHT)
	await tool.frames(4)

func _drag(a: Vector2, b: Vector2, shot := "") -> void:
	if a.x < 0.0 or b.x < 0.0:
		_check(false, "arrastre sin origen/destino")
		return
	await _sync(a)
	_btn(a, true)
	await tool.frames(2)
	for k in range(1, 25):
		_mm(a.lerp(b, float(k) / 24.0), MOUSE_BUTTON_MASK_LEFT)
		await tool.frames(1)
	await _sync(b, MOUSE_BUTTON_MASK_LEFT)
	await tool.frames(3)
	if shot != "":
		await tool.snap(shot)
	_btn(b, false)
	await tool.frames(8)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)

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

func _check(c: bool, what: String) -> void:
	if not c:
		fails += 1
	print("V3VISTA %s %s" % ["OK" if c else "FALLA", what])
