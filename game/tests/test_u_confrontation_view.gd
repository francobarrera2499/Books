# W3-SCENEUI: la confrontación con el librero (ui/scene/confrontation_view.gd) sobre una GameSim REAL
# (tests/fixtures/w3sceneui/world.gd, estado day10_confront), sin ventana (1600×900). GDD §8.8, ARCHITECTURE §5.7, §6.7.
# Verifica: afirmación vigente con su número; paciencia a la vista (paquete y sombrero) que se va con cada error; callar en
#   dos pasos y sin error; refutar en dos pasos (selector -> frase -> «Mostrar» / «Guardar»), también soltando sobre la
#   afirmación; tres errores -> se va (incompleta) y «Seguir»; transcripción de las líneas S.HC07 (recortables); protocolo
#   de la pila de Shell (back/close/closed).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const CV = preload("res://ui/scene/confrontation_view.gd")

static var _world = null
var cv = null
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
	if cv != null and is_instance_valid(cv):
		cv.free()
	cv = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

func rec_act(a: Dictionary) -> Dictionary:
	acts.append(a.duplicate(true))
	return sim.apply(a)

func mount() -> void:
	sim = world().sim_at("day10_confront")
	eq(world().errs, [], "camino a la confrontación sin acciones rechazadas")
	cv = CV.new()
	cv.sim = sim
	cv.act_fn = rec_act
	cv.sounds = false
	cv.animate = false
	cv.transcript.animate = false
	tree.root.add_child(cv)
	cv.refresh()

func confronts() -> Array:
	return acts.filter(func(a): return String(a.t) == "confront")

func clip(name: String) -> String:
	return String(world().clips.get(name, ""))

# ------------------------------------------------------------------
func test_opening_statement_and_patience() -> void:
	mount()
	var d: Dictionary = cv.debug_state()
	eq(d.step, 1, "primera afirmación")
	eq(d.errors, 0, "sin errores")
	no(d.done, "en curso")
	var stmt: Dictionary = sim.q_confront().statement
	ok(String(d.quote).contains(String(sim.repo.parse_text(String(stmt.text)).plain)), "la afirmación a la vista: " + String(d.quote))
	eq(cv._roman.text, "I", "número romano")
	eq(d.patience, {"paquete": 1.0, "sombrero": 1.0}, "paquete y sombrero sobre el mostrador")
	ok(d.lines.size() >= 1, "la afirmación también queda en la transcripción (recortable)")
	ok(cv._b_refute.visible and cv._b_silence.visible, "«Refutar…» y «Callar»")
	no(cv._b_follow.visible, "sin «Seguir» mientras dura")
	ok(String(cv._title.text).contains(sim.repo.text("sceneui.lugar.L1.tienda")), "encabezado: la tienda de Crane")

func test_silence_two_steps_not_an_error() -> void:
	mount()
	cv.ask_silence()
	ok(cv.debug_state().silence_pending, "callar pide un segundo paso")
	eq(acts.size(), 0, "todavía nada")
	no(cv._buttons.visible, "los botones dejan lugar a la confirmación")
	cv.cancel_silence()
	no(cv.debug_state().silence_pending, "volver")
	eq(acts.size(), 0, "volver no gasta")
	cv.ask_silence()
	cv.confirm_silence()
	eq(confronts().size(), 1, "una acción")
	eq(confronts()[0], {"t": "confront", "step": 1, "item": {}}, "callar = item vacío")
	var d: Dictionary = cv.debug_state()
	eq(d.step, 2, "pasa a la segunda afirmación")
	eq(d.errors, 0, "callar no es error")
	eq(cv._roman.text, "II", "número II")
	eq(d.patience, {"paquete": 1.0, "sombrero": 1.0}, "la paciencia intacta")

func test_refute_two_steps_hit() -> void:
	mount()
	cv.ask_silence()
	cv.confirm_silence()
	cv.open_refute()
	ok(cv.picker.visible, "selector de recortes y preguntas")
	ok(cv.picker.cards().size() >= 5, "recortes en el selector: %d" % cv.picker.cards().size())
	cv.picker.pick("clip", clip("corniche"))
	no(cv.picker.visible, "el selector se cierra")
	ok(cv.confirm_bar.visible, "segundo paso")
	var want: String = sim.q_preview({"t": "present", "char": "librero", "item": {"kind": "clip", "id": clip("corniche")}})
	eq(cv.confirm_bar.phrase(), want, "la frase de Lisle antes de mostrar")
	eq(cv.confirm_bar.action(), {"t": "confront", "step": 2, "item": {"kind": "clip", "id": clip("corniche")}}, "acción confront")
	cv.confirm_bar.keep()
	eq(acts.size(), 1, "«Guardar» no gasta (sólo el callar anterior)")
	cv.refute({"kind": "clip", "id": clip("corniche")})
	cv.confirm_bar.confirm()
	var res: Dictionary = sim.q_confront()
	eq(int(res.step), 3, "acierto: avanza a la III")
	eq(int(res.hits), 1, "un acierto")
	eq(cv.debug_state().errors, 0, "sin errores")

func test_picker_leaves_statement_visible() -> void:
	mount()
	cv.ask_silence()
	cv.confirm_silence()       # II: la afirmación larga (dos renglones a 1600×900)
	await tree.process_frame
	await tree.process_frame
	cv.open_refute()
	await tree.process_frame
	await tree.process_frame
	var b: Rect2 = cv.banner.get_global_rect()
	var p: Rect2 = cv.picker.get_global_rect()
	ok(cv.picker.list_height() < 300.0, "la lista se achica: %s" % cv.picker.list_height())
	ok(p.position.y >= b.end.y, "el selector no tapa la afirmación (%s >= %s)" % [p.position.y, b.end.y])
	ok(p.end.y <= 900.0 - 236.0 - 24.0, "ni la transcripción")
	ok(p.size.y >= 200.0, "sigue siendo usable: %s" % p.size.y)
	# aprovecha el alto libre (antes el título con autowrap inflaba el mínimo medido y la lista quedaba en 140 px)
	ok(p.position.y - b.end.y <= 40.0, "sin hueco grande sobre el selector: %s -> %s" % [b.end.y, p.position.y])

func test_final_text_display_keeps_signature_together() -> void:
	var CB = load("res://ui/compose/compose_base.gd")
	var s := "A propósito de «El problema final»: la pared era a pique. —E. L."
	var d: String = CB.display_text(s)
	no(d.contains("—E"), "raya pegada con U+2060")
	ok(d.contains("E. L."), "iniciales sin corte")
	eq(CB.undisplay(d), s, "lo visible es lo enviado")
	eq(CB.display_text("uno — dos"), "uno — dos", "raya suelta intacta")

func test_three_errors_he_leaves() -> void:
	mount()
	var bad := {"kind": "clip", "id": clip("aviso")}
	cv.refute(bad)
	cv.confirm_bar.confirm()
	var d: Dictionary = cv.debug_state()
	eq(d.errors, 1, "primer error")
	eq(d.step, 1, "un error no avanza")
	eq(d.patience.paquete, 0.0, "recoge el paquete")
	eq(d.patience.sombrero, 1.0, "el sombrero sigue")
	cv.refute(bad)
	cv.confirm_bar.confirm()
	d = cv.debug_state()
	eq(d.errors, 2, "segundo error")
	eq(d.patience.sombrero, 0.0, "se pone el sombrero")
	cv.refute({"kind": "pregunta", "id": "Q1"})
	cv.confirm_bar.confirm()
	d = cv.debug_state()
	ok(d.done, "tercer error: se va")
	eq(String(sim.st.flags.get("confront_estado", "")), "incompleta", "confrontación incompleta")
	no(cv._b_refute.visible, "ya no se refuta")
	no(cv._b_silence.visible, "ni se calla")
	ok(cv._b_follow.visible, "«Seguir»")
	eq(cv._roman.text, "", "sin número")
	ok(String(d.quote) != "", "queda a la vista su última línea: " + String(d.quote))
	no(cv.refute(bad), "terminada: no hay segundo paso")
	var got := [false, false]
	cv.finished.connect(func(): got[0] = true)
	cv.closed.connect(func(): got[1] = true)
	cv._on_follow()
	ok(got[0], "finished")
	ok(got[1], "closed")
	no(cv.visible, "se oculta")

func test_all_silent_finishes_without_errors() -> void:
	mount()
	for i in 4:
		cv.ask_silence()
		cv.confirm_silence()
	var d: Dictionary = cv.debug_state()
	ok(d.done, "cuatro silencios terminan la escena")
	eq(d.errors, 0, "ningún error")
	eq(confronts().size(), 4, "cuatro acciones")
	for i in 4:
		eq(int(confronts()[i].step), i + 1, "paso %d" % (i + 1))

func test_transcript_lines_in_order() -> void:
	mount()
	cv.refute({"kind": "clip", "id": clip("aviso")})
	cv.confirm_bar.confirm()
	var uids: Array = cv.transcript.uids()
	ok(uids.size() >= 3, "afirmación, «Eso prueba…» y el paquete: %s" % str(uids))
	var want: Array = []
	for e in sim.q_diary():
		if String(e.get("kind", "")) == "line" and String(e.get("origin", "")) == "S.HC07":
			want.append(String(e.line))
	eq(uids, want, "las líneas S.HC07 del diario, en orden")
	for r in cv.transcript.rows():
		eq((r.rtl as RichTextLabel).get_parsed_text(), String(r.parsed.plain), "texto exacto (mapeo de la tijera)")
	# recortable con la tijera
	cv.toggle_tijera()
	ok(cv.tijera, "tijera")
	var row: Dictionary = cv.transcript.rows()[0]
	var plain := String(row.parsed.plain)
	var n := plain.find(".")
	var res: Dictionary = cv.transcript.clip_range(String(row.uid), 0, n + 1 if n > 0 else plain.length())
	ok(bool(res.get("ok", false)), "recorte de una línea del librero: %s" % str(res))
	eq(acts.back().src, {"kind": "line", "ref": String(row.uid)}, "src de línea")

func _echoes() -> Array:
	var out: Array = []
	for r in cv.transcript.rows():
		if bool(r.get("local", false)):
			out.append({"who": String(r.who), "text": (r.rtl as RichTextLabel).get_parsed_text(), "sel": (r.rtl as RichTextLabel).selection_enabled})
	return out

func test_echo_rows_for_what_lisle_did() -> void:
	mount()
	var n0: int = cv.transcript.uids().size()
	cv.ask_silence()
	cv.confirm_silence()
	var ec := _echoes()
	eq(ec.size(), 1, "callar deja una fila de Lisle")
	eq(ec[0].who, "lisle", "es de Lisle")
	eq(ec[0].text, sim.repo.text("sceneui.conf.eco.callar"), "«(Calla.)»")
	var phrase: String = sim.q_preview({"t": "present", "char": "librero", "item": {"kind": "clip", "id": clip("corniche")}})
	cv.refute({"kind": "clip", "id": clip("corniche")})
	cv.confirm_bar.confirm()
	ec = _echoes()
	eq(ec.size(), 2, "refutar deja otra")
	eq(ec[1].text, phrase, "la frase con que Lisle mostró el recorte")
	# orden: la fila local queda justo antes de la respuesta del librero
	var rows: Array = cv.transcript.rows()
	var k := -1
	for i in rows.size():
		if bool(rows[i].get("local", false)) and (rows[i].rtl as RichTextLabel).get_parsed_text() == phrase:
			k = i
	ok(k >= 0 and k + 1 < rows.size() and String(rows[k + 1].who) == "librero", "después de la frase, el librero contesta")
	# no es recortable ni cuenta como línea dicha
	cv.toggle_tijera()
	ok(cv.tijera, "tijera")
	no(_echoes().any(func(e): return e.sel), "las filas locales no se seleccionan con la tijera")
	var want: Array = []
	for e in sim.q_diary():
		if String(e.get("kind", "")) == "line" and String(e.get("origin", "")) == "S.HC07":
			want.append(String(e.line))
	eq(cv.transcript.uids(), want, "uids() sigue siendo sólo lo que el sim dijo")
	ok(cv.transcript.uids().size() > n0, "y crece con las respuestas")
	# un error del sim no deja eco
	cv.act_fn = func(_a): return {"ok": false, "err": "paso"}
	cv.ask_silence()
	cv.confirm_silence()
	eq(_echoes().size(), 2, "sin eco si la acción fue rechazada")

func test_drop_on_statement() -> void:
	mount()
	ok(cv._banner_can_drop(Vector2.ZERO, {"kind": "clip", "id": clip("kanzel")}), "acepta un recorte")
	ok(cv._banner_can_drop(Vector2.ZERO, {"kind": "pregunta", "id": "Q1"}), "acepta una pregunta del expediente")
	no(cv._banner_can_drop(Vector2.ZERO, {"kind": "ent", "id": "fina"}), "no acepta chips del índice")
	cv._banner_drop(Vector2.ZERO, {"kind": "clip", "id": clip("kanzel")})
	ok(cv.confirm_bar.visible, "soltar abre el segundo paso")
	eq(acts.size(), 0, "nada se gasta al soltar")

func test_shell_protocol_back() -> void:
	mount()
	cv.handle_back = false
	no(cv.handle_keys, "handle_back = handle_keys")
	cv.open_refute()
	ok(cv.back(), "back cierra el selector")
	no(cv.picker.visible, "selector cerrado")
	cv.refute({"kind": "clip", "id": clip("kanzel")})
	ok(cv.back(), "back = «Guardar»")
	no(cv.confirm_bar.visible, "segundo paso cerrado")
	cv.ask_silence()
	ok(cv.back(), "back cancela el callar")
	no(cv.debug_state().silence_pending, "callar cancelado")
	ok(cv.back(), "durante la confrontación no se sale")
	ok(cv.visible, "sigue a la vista")
	eq(acts.size(), 0, "nada gastado")

func test_errors_become_lisle_notes() -> void:
	mount()
	cv.act_fn = func(_a): return {"ok": false, "err": "paso"}
	cv.ask_silence()
	cv.confirm_silence()
	eq(cv.note.text(), sim.repo.text("sceneui.err.paso"), "nota de Lisle")
