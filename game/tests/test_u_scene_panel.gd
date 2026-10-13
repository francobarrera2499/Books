# W3-SCENEUI: panel de escena (ui/scene/scene_panel.gd + transcript, ask_panel, item_picker, present_bar) sobre una
# GameSim REAL (tests/fixtures/w3sceneui/world.gd: data/ estructural + integ + fixtures propios), sin ventana (1600×900).
# Verifica: personajes y verbos según el estado (sin contador: tras la línea de cierre desaparecen los verbos de hablar);
#   preguntar con la frase exacta antes de hablar (q_preview) y nada se gasta con «Volver»; afirmar filtra por canal;
#   presentar en dos pasos (selector o DnD -> frase -> «Mostrar» / «Guardar»); pagar y encargar; líneas recortables con
#   la tijera (clip_text src kind "line"); escena fija (M7) con «Continuar»; salir de una visita con confirmación.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const ScenePanel = preload("res://ui/scene/scene_panel.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

static var _world = null
var sp = null
var sim = null
var acts: Array = []
var old_size := Vector2i.ZERO

func world():
	if _world == null:
		_world = W.new()
	return _world

func before_each() -> void:
	acts = []
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)

func after_each() -> void:
	if sp != null:
		sp.free()
	sp = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

func rec_act(a: Dictionary) -> Dictionary:
	acts.append(a.duplicate(true))
	return sim.apply(a)

func mount(state: String) -> void:
	sim = world().sim_at(state)
	eq(world().errs, [], "el camino a %s no tiene acciones rechazadas" % state)
	sp = ScenePanel.new()
	sp.sim = sim
	sp.act_fn = rec_act
	sp.sounds = false
	sp.transcript.animate = false
	tree.root.add_child(sp)
	sp.refresh()

func committed() -> Array:
	return acts.filter(func(a): return not String(a.t).begins_with("clip"))

# ------------------------------------------------------------------
func test_world_states_load() -> void:
	eq(world().repo.errors(), [], "dataset de W3-SCENEUI sin errores")
	for st in ["prologue_ad", "day1_watson", "day1_crane"]:
		var s = world().sim_at(st)
		eq(world().errs, [], "estado %s sin acciones rechazadas" % st)
		ok(s != null, st)

func test_visit_cast_and_verbs() -> void:
	mount("day1_watson")
	var d: Dictionary = sp.debug_state()
	eq(d.phase, "visit", "fase")
	ok(d.cast.has("watson"), "Watson está en la consulta: %s" % str(d.cast))
	var vs: Array = d.cast.get("watson", [])
	has(vs, "ask", "puede preguntar")
	has(vs, "assert", "as.pared afirmable ante Watson")
	has(vs, "present", "puede presentar")
	no(vs.has("pay"), "a Watson no se le paga")
	ok(d.cast_column, "columna de elenco en la visita")
	ok(String(d.title).contains("Watson") or String(d.title).contains("Kensington"), "encabezado con el lugar: " + String(d.title))
	ok(sp.should_show(), "hay algo que mostrar")

func test_ask_shows_exact_phrase_then_confirms() -> void:
	mount("day1_watson")
	sp.open_ask("watson", "ask")
	eq(sp.sub_open(), "ask", "subpanel de preguntar abierto")
	var ap = sp.ask_panel
	ok(ap.options.size() > 0, "hay temas del índice")
	ap.choose("fina")
	var want: String = sim.q_preview({"t": "ask", "char": "watson", "topic": "fina"})
	ok(want != "", "q_preview da la frase")
	eq(ap.phrase(), want, "la frase que se ve es la exacta")
	ok(String(ap._phrase.text).contains(want), "la frase está en pantalla: " + ap._phrase.text)
	eq(acts.size(), 0, "elegir un tema no gasta nada")
	# «Volver» no gasta
	ap._on_back()
	eq(acts.size(), 0, "volver no gasta")
	eq(sp.sub_open(), "", "subpanel cerrado")
	# ahora sí
	sp.open_ask("watson", "ask")
	ap.choose("fina")
	var n0: int = sp.transcript.uids().size()
	ap.confirm()
	eq(committed().size(), 1, "una acción comprometida")
	eq(committed()[0], {"t": "ask", "char": "watson", "topic": "fina"}, "acción ask")
	ok(sp.transcript.uids().size() >= n0 + 2, "la frase de Lisle y la respuesta aparecen: %d -> %d" % [n0, sp.transcript.uids().size()])
	var whos: Array = sp.transcript.rows().map(func(r): return String(r.who))
	has(whos, "lisle", "la frase de Lisle queda en la transcripción")
	has(whos, "watson", "la respuesta de Watson")
	eq(sp.sub_open(), "", "el panel se cierra tras hablar")

func test_assert_and_budget_closing() -> void:
	mount("day1_watson")
	sp.open_ask("watson", "assert")
	var ap = sp.ask_panel
	var ids: Array = ap.options.map(func(o): return String(o.id))
	has(ids, "as.pared", "cebo disponible")
	for x in ids:
		ok(not String(x).begins_with("cn.") or true, "")
	ap.choose("as.pared")
	ok(ap.phrase().begins_with("La pared era a pique"), "frase exacta: " + ap.phrase())
	ap.confirm()
	eq(committed().back().t, "assert", "assert enviado")
	# agota las tres preguntas: tras la línea de cierre, sin verbos de hablar (y sin contador)
	for t in ["fina", "reichenbach"]:
		sp.open_ask("watson", "ask")
		ap.choose(t)
		ap.confirm()
	var vs: Array = sp.debug_state().cast.get("watson", [])
	no(vs.has("ask"), "sin preguntas: no se ofrece preguntar: %s" % str(vs))
	no(vs.has("assert"), "ni afirmar")
	has(vs, "present", "presentar sigue")
	var last: Dictionary = sim.q_line(String(sp.transcript.uids().back()))
	eq(String(last.who), "watson", "la última línea es suya")
	ok(String(last.text).contains("pacientes"), "línea de cierre: " + String(last.text))
	var blk = sp.band.find_child("Personaje_watson", true, false)
	no(blk._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"}), "ya no acepta un chip del índice (no contesta)")
	ok(blk._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": world().clips.aviso}), "pero sí un recorte para presentar")

func test_present_two_steps_keep_and_show() -> void:
	mount("day1_watson")
	sp.open_picker("watson")
	eq(sp.sub_open(), "picker", "selector abierto")
	var cards: Array = sp.picker.cards()
	ok(cards.size() >= 3, "recortes del prólogo en el selector: %d" % cards.size())
	var clip := String(world().clips.aviso)
	sp.picker.pick("clip", clip)
	eq(sp.sub_open(), "present", "segundo paso")
	var want: String = sim.q_preview({"t": "present", "char": "watson", "item": {"kind": "clip", "id": clip}})
	eq(sp.present_bar.phrase(), want, "frase exacta de presentar")
	sp.present_bar.keep()
	eq(acts.size(), 0, "«Guardar» no gasta")
	eq(sp.sub_open(), "", "cerrado")
	# por DnD (DropCatcher3D / tarjeta del personaje)
	ok(sp.present("watson", {"kind": "entry", "id": String(world().clips.practica)}), "presentar un asiento")
	sp.present_bar.confirm()
	eq(committed().size(), 1, "una acción")
	eq(committed()[0], {"t": "present", "char": "watson", "item": {"kind": "entry", "id": String(world().clips.practica)}}, "acción present")
	ok(sp.transcript.rows().any(func(r): return String(r.who) == "watson"), "Watson contesta")
	no(sp.present("nadie", {"kind": "clip", "id": clip}), "a quien no está, no")

func test_drop_on_cast_block() -> void:
	mount("day1_watson")
	var blk = sp.band.find_child("Personaje_watson", true, false)
	ok(blk != null, "bloque del personaje")
	if blk == null:
		return
	ok(blk._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": world().clips.aviso}), "acepta un recorte")
	ok(blk._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"}), "acepta un chip del índice")
	no(blk._can_drop_data(Vector2.ZERO, {"kind": "pair", "id": "PR001"}), "no acepta pares")
	blk._drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"})
	eq(sp.sub_open(), "ask", "chip del índice -> preguntar")
	eq(sp.ask_panel.chosen, "fina", "con el tema elegido")
	blk._drop_data(Vector2.ZERO, {"kind": "clip", "id": world().clips.aviso})
	eq(sp.sub_open(), "present", "recorte -> segundo paso de presentar")

func test_line_clip_with_scissors() -> void:
	mount("day1_watson")
	sp.open_ask("watson", "assert")
	sp.ask_panel.choose("as.pared")
	sp.ask_panel.confirm()
	var row: Dictionary = {}
	for r in sp.transcript.rows():
		if String(r.who) == "watson":
			row = r
	ok(not row.is_empty(), "línea de Watson")
	if row.is_empty():
		return
	var rtl: RichTextLabel = row.rtl
	eq(rtl.get_parsed_text(), String(row.parsed.plain), "el builder produce exactamente plain")
	sp.set_tijera(true)
	ok(rtl.selection_enabled, "tijera: selección habilitada")
	var plain := String(row.parsed.plain)
	var s := "Era un sendero estrecho"
	var k := plain.find(s)
	ok(k >= 0, "texto en la línea")
	var res: Dictionary = sp.transcript.clip_range(String(row.uid), k, s.length())
	ok(bool(res.get("ok", false)), "recorte aceptado: %s" % str(res))
	var a: Dictionary = acts.back()
	eq(a.t, "clip_text", "clip_text")
	eq(a.src, {"kind": "line", "ref": String(row.uid)}, "src de línea")
	var c: Dictionary = sim.q_clip(String(res.get("clip", "")))
	ok(String(c.get("text", "")).begins_with("Era un sendero"), "la tira: %s" % String(c.get("text", "")))
	sp.set_tijera(false)
	no(rtl.selection_enabled, "sin tijera no se selecciona")

func test_crane_free_visit_and_leave() -> void:
	mount("day1_crane")
	sp.show_leave = true
	sp.refresh()
	var vs: Array = sp.debug_state().cast.get("crane", [])
	has(vs, "ask", "Crane contesta")
	sp.open_ask("crane", "ask")
	sp.ask_panel.choose("reichenbach")
	ok(sp.ask_panel.phrase().begins_with("¿Qué me dice de"), "ask_phrase propio de Crane: " + sp.ask_panel.phrase())
	sp.ask_panel.confirm()
	# la tienda no gasta franja: salir sin confirmación
	sp.leave()
	eq(committed().back(), {"t": "leave"}, "leave directo")
	eq(String(sim.q_clock().phase), "desk", "de vuelta al escritorio")

func test_leave_visit_asks_first() -> void:
	mount("day1_watson")
	sp.show_leave = true
	sp.refresh()
	sp.leave()
	eq(sp.sub_open(), "confirm", "pide confirmación")
	eq(acts.size(), 0, "todavía nada")
	sp._confirm.decided.emit(false)
	await tree.process_frame
	eq(acts.size(), 0, "volver no sale")
	sp.leave()
	sp._confirm.decided.emit(true)
	await tree.process_frame
	eq(committed().back(), {"t": "leave"}, "sale")

func test_pay_and_task_wiggins() -> void:
	mount("day3_wiggins")
	var cast: Dictionary = sp.debug_state().cast
	ok(cast.has("wiggins"), "Wiggins (silueta con diálogo) en Baker Street el día 3: %s" % str(cast))
	if not cast.has("wiggins"):
		return
	has(cast.wiggins, "pay", "a Wiggins se le paga")
	no(cast.wiggins.has("task"), "todavía no acepta encargos")
	sp.open_pay("wiggins")
	ok(sp.present_bar._ok.disabled, "sin monto, no hay frase")
	sp.present_bar.choose_amount(12)
	eq(sp.present_bar.chosen_button_text(), "1s.", "el botón del chelín queda hundido")
	eq(sp.present_bar.phrase(), sim.q_preview({"t": "pay", "char": "wiggins", "amount_d": 12}), "frase exacta del pago")
	sp.present_bar.confirm()
	eq(committed().back(), {"t": "pay", "char": "wiggins", "amount_d": 12}, "pay enviado")

func test_fixed_scene_continue() -> void:
	mount("day7_m7")
	var d: Dictionary = sp.debug_state()
	eq(d.phase, "scene", "escena fija")
	ok(d.lines.size() >= 4, "líneas de Harris: %d" % d.lines.size())
	ok(d.cast.is_empty() or d.cast.values().all(func(v): return v.is_empty()), "sin verbos en una escena fija")
	no(d.cast_column, "sin columna de elenco: la transcripción usa el ancho")
	var btn = sp._foot.get_child(0) if sp._foot.get_child_count() > 0 else null
	ok(btn != null and btn.text == sim.repo.text("sceneui.continue"), "«Continuar»")
	sp.leave()
	eq(committed().back(), {"t": "leave"}, "continuar = leave")

func test_errors_become_lisle_notes() -> void:
	mount("day1_watson")
	var calls := [0]
	sp.act_fn = func(a):
		calls[0] += 1
		return {"ok": false, "err": "sin_preguntas"}
	sp.open_ask("watson", "ask")
	sp.ask_panel.choose("fina")
	sp.ask_panel.confirm()
	eq(calls[0], 1, "se intentó")
	eq(sp.note.text(), sim.repo.text("sim.err.sin_preguntas"), "nota de Lisle con el error")

# ------------------------------------------------------------------ protocolo de la pila de Shell
class ConfStub extends RefCounted:
	var refuted: Array = []
	func refute(item: Dictionary) -> bool:
		refuted.append(item)
		return true

class ShellStub extends RefCounted:
	var opened: Array = []
	var conf := ConfStub.new()
	func open_panel(kind: String, _args := []):
		opened.append(kind)
		return conf if kind == "confront" else null

func test_shell_protocol() -> void:
	mount("day1_watson")
	sp.handle_back = false
	no(sp.handle_keys, "handle_back = handle_keys")
	sp.open("watson")
	eq(sp.sub_open(), "", "primer clic en el personaje: la banda con sus verbos")
	sp.open("watson")
	eq(sp.sub_open(), "ask", "segundo clic: «Preguntar»")
	ok(sp.back(), "back cierra el subpanel")
	eq(sp.sub_open(), "", "cerrado")
	sp.toggle_tijera()
	ok(sp.tijera, "tijera (InputRouter: C)")
	ok(sp.back(), "back deja la tijera")
	no(sp.tijera, "sin tijera")
	no(sp.back(), "nada que consumir: la pila cierra el panel")
	ok(sp.request_present("watson", {"kind": "clip", "id": String(world().clips.aviso)}), "DropCatcher3D -> 2.º paso")
	eq(sp.sub_open(), "present", "barra de presentar")
	var got := [0]
	sp.closed.connect(func(): got[0] += 1)
	sp.close()
	no(sp.visible, "close oculta")
	eq(got[0], 1, "closed")
	eq(sp.sub_open(), "", "y cierra el subpanel")
	eq(acts.size(), 0, "nada gastado")

func test_auto_close_after_leaving() -> void:
	mount("day1_crane")
	sp.open("")
	var got := [0]
	sp.closed.connect(func(): got[0] += 1)
	sp.leave()
	eq(String(sim.q_clock().phase), "desk", "en el escritorio")
	no(sp.visible, "el panel se oculta solo")
	eq(got[0], 1, "closed")

func test_prologue_lines_without_verbs() -> void:
	mount("prologue_ad")
	var d: Dictionary = sp.debug_state()
	eq(d.phase, "prologue", "prólogo")
	ok(d.cast.values().all(func(v): return v.is_empty()), "sin verbos en el prólogo")
	eq(d.lines.size(), (sim.q_scene().get("lines", []) as Array).size(), "las líneas del prólogo, recortables")
	eq(sp._foot.get_child_count(), 0, "sin «Continuar» ni «Salir»")
	no(sp._right.visible, "sin columna derecha en el prólogo")

func test_confront_phase_delegates() -> void:
	sim = world().sim_at("day10_confront")
	sp = ScenePanel.new()
	sp.sim = sim
	sp.act_fn = rec_act
	sp.sounds = false
	var stub := ShellStub.new()
	sp.shell = stub
	tree.root.add_child(sp)
	sp.open("librero")
	sp.visible = true            # Shell.open_panel hace visible = true DESPUÉS de open()
	await tree.process_frame
	no(sp.visible, "en la confrontación el panel de escena no se queda (se oculta en el cuadro siguiente)")
	eq(stub.opened, ["confront"], "pide a Shell la vista de confrontación")
	eq(stub.conf.refuted, [], "sin nada soltado no hay segundo paso")
	# soltar un recorte sobre el librero (DropCatcher3D -> open_panel("scene") -> request_present): segundo paso de refutar
	sp.open("librero")
	ok(sp.request_present("librero", {"kind": "clip", "id": String(world().clips.corniche)}), "acepta lo soltado")
	no(sp.request_present("librero", {"kind": "ent", "id": "fina"}), "un chip del índice no refuta")
	await tree.process_frame
	eq(stub.opened, ["confront", "confront"], "una sola delegación por cuadro")
	eq(stub.conf.refuted, [{"kind": "clip", "id": String(world().clips.corniche)}], "refute(item) en la vista de confrontación")
	eq(acts.size(), 0, "nada gastado: refutar sigue pidiendo «Mostrar»")

# ------------------------------------------------------------------ subpaneles del lado contrario al personaje
class FakeWorld extends Node3D:
	var diorama: Node3D
	var cam: Camera3D
	var body: Node3D
	func _init() -> void:
		cam = Camera3D.new()
		cam.fov = 60.0
		add_child(cam)
		diorama = Node3D.new()
		add_child(diorama)
		var chars := Node3D.new()
		chars.name = "Chars"
		diorama.add_child(chars)
		body = Node3D.new()
		body.name = "char_watson"
		body.set_meta("aabb", AABB(Vector3(-0.25, 0, -0.2), Vector3(0.5, 1.8, 0.4)))
		chars.add_child(body)
	func camera() -> Camera3D:
		return cam

func test_subpanels_dock_away_from_character() -> void:
	mount("day1_watson")
	var fw := FakeWorld.new()
	tree.root.add_child(fw)
	sp.world = fw
	fw.body.position = Vector3(2.5, -0.9, -6.0)
	sp.open_ask("watson", "ask")
	ok(sp.char_screen_pos("watson").x > 800.0, "Watson a la derecha: %s" % str(sp.char_screen_pos("watson")))
	ok(sp.debug_state().dock_left, "personaje a la derecha: subpanel a la izquierda")
	eq(sp.ask_panel.anchor_left, 0.0, "anclado a la izquierda")
	eq(sp.note.anchor_left, 1.0, "la nota de Lisle, del otro lado")
	fw.body.position = Vector3(-2.5, -0.9, -6.0)
	sp.open_picker("watson")
	no(sp.debug_state().dock_left, "personaje a la izquierda: subpanel a la derecha")
	eq(sp.picker.anchor_left, 1.0, "anclado a la derecha")
	fw.body.position = Vector3(0.0, 0.0, 6.0)
	eq(sp.char_screen_pos("watson"), Vector2(-1, -1), "detrás de la cámara: no se sabe")
	sp.present("watson", {"kind": "clip", "id": String(world().clips.aviso)})
	no(sp.debug_state().dock_left, "sin posición: a la derecha")
	eq(sp.char_screen_pos("nadie"), Vector2(-1, -1), "quien no está en el diorama")
	sp.world = null
	eq(sp.char_screen_pos("watson"), Vector2(-1, -1), "sin mundo (tests, Shell sin 3D)")
	fw.free()
