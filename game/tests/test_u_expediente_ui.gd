# UI-EXPEDIENTE (GDD_v3 §6.1, §6.2, §1.6): la vista del Expediente Holmes (ui/expediente/*) y su vista-modelo, headless.
# Corre contra el doble suelto de devtools/drivers/v3exp_fake.gd (data/ real para textos y letras; recortes, índice y el
# expediente con el contrato de CORE: q_dossier, q_answer_options, dq_answer, dq_proof, dq_confirm), así la UI se prueba
# sin depender de qué cierra (eso es de CORE: test_u_dossier, T36). Un test de integración usa la GameSim REAL de CORE
# (test_real_core_q1_pencil_to_ink: recortes con las etiquetas de la ruta Q1.R2 -> tinta con el texto de dossier.json). Verifica: índice (encargo, ≤3 abiertas, «En tinta»
# plegado), hoja (pregunta, origen, dudas, Respuesta, dos ranuras-tarjeta, «Pasar en limpio» sólo con las tres llenas),
# selector con ≤7 a la vista y buscador, soltar recortes y fichas del índice, reemplazar y vaciar, chequeo de forma en la
# voz de Lisle, «Algo no cierra.» sin decir qué, tinta con el texto de Lisle (sin poder tocar nada), primera tinta sobria,
# preguntas arrastrables como ítem, sin contadores, el cuaderno acoplado a la izquierda y cerrado con la carpeta.
# Capturas con eventos reales: devtools/drivers/v3exp_flujo.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const Fake = preload("res://devtools/drivers/v3exp_fake.gd")
const Expediente = preload("res://ui/expediente/expediente.gd")
const Model = preload("res://ui/expediente/expediente_model.gd")
const Picker = preload("res://ui/expediente/answer_picker.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")
const Notebook = preload("res://ui/notebook/notebook.gd")

var ex = null
var nb = null
var fk = null
var old_size := Vector2i.ZERO

# Shell mínimo (protocolo por duck typing de ui/shell.gd): abre el cuaderno de verdad y sigue la pila.
class FakeShell extends Node:
	signal panel_opened(kind: String)
	signal panel_closed(kind: String)
	var panels := {}
	var opened: Array = []
	var sim_ref = null
	var reader_on := false
	func reader_open() -> bool:
		return reader_on
	func is_open(kind: String) -> bool:
		return panels.has(kind) and is_instance_valid(panels[kind]) and bool(panels[kind].visible)
	func panel(kind: String):
		return panels.get(kind)
	var opened_args: Array = []
	func open_panel(kind: String, _args := []):
		opened.append(kind)
		opened_args.append(_args)
		if kind != "notebook":
			return null
		var n = panels.get(kind)
		if n == null:
			n = Notebook.new()
			n.sounds = false
			n.sim_override = sim_ref
			n.act_fn = func(a): return sim_ref.apply(a)
			add_child(n)
			n.set_shell(self)
			panels[kind] = n
		n.open(String(_args[0]) if not _args.is_empty() else "")
		panel_opened.emit(kind)
		return n
	func close_kind(kind: String) -> void:
		var n = panels.get(kind)
		if n != null and n.has_method("close"):
			n.close()
			n.visible = false
		panel_closed.emit(kind)

func before_each() -> void:
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)

func after_each() -> void:
	for n in [ex, nb]:
		if n != null and is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	ex = null
	nb = null
	fk = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

func frames(n := 2) -> void:
	for i in n:
		await tree.process_frame

# El doble del expediente (suelto) con dos preguntas y cuatro recortes de papeles distintos.
func make_fake() -> Dictionary:
	fk = Fake.new(null, repo())
	var ids := {}
	ids.a = fk.add_clip({"text": "La senda termina de pronto en la pared de roca, sin salida alguna.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», crónica", "ents": ["reichenbach"]})
	ids.b = fk.add_clip({"text": "Une marque fraîche sur la roche, au-dessus du sentier.", "origin": "D05", "doc": "D05",
		"src_line": "Journal de Genève, 7 de mayo de 1891", "ents": ["reichenbach"]})
	ids.c = fk.add_clip({"text": "Más arriba del sendero hay una cornisa que no se ve desde abajo.", "origin": "D08", "doc": "D08",
		"src_line": "Guía Baedeker de Suiza", "ents": ["reichenbach"]})
	ids.d = fk.add_clip({"text": "El agua cae ahí con un ruido que tapa cualquier grito.", "origin": "D03", "doc": "D03",
		"src_line": "«El problema final», crónica", "ents": ["reichenbach"]})
	fk.options = []
	for i in 10:
		fk.options.append({"id": "op%02d" % i, "label": "Opción %02d" % i, "kind": "concepto"})
	fk.options.append({"id": "raspadura", "label": "Raspadura", "kind": "concepto"})
	fk.options.append({"id": "watson", "label": "Doctor Watson", "kind": "persona"})
	fk.add_question({"id": "Q1", "text": "¿Qué no contó Watson?", "origin": "La pregunta del cliente, en el encargo.",
		"doubts": ["¿Qué dice la crónica, palabra por palabra?", "¿Hay otra versión del texto?", "¿Qué publicaron los diarios suizos?"],
		"acepta": ["concepto", "objeto"], "ok_answers": ["raspadura"], "ok_pairs": [[ids.a, ids.b]],
		"ink_text": "Watson vio en la roca una raspadura fresca y la escribió. En la revista esa frase no está."})
	fk.add_question({"id": "Q2", "text": "¿Qué pasó en la cascada?", "origin": "Me lo pregunté leyendo «El problema final».",
		"doubts": ["¿Cómo era el sendero?", "¿Qué dijeron los guías?"], "acepta": ["concepto", "lugar", "objeto"],
		"ok_answers": ["op03"], "ok_pairs": [[ids.a, ids.c]], "ink_text": "La pared no era lisa."})
	return ids

func make_ex(with_shell := false) -> void:
	ex = Expediente.new()
	ex.sounds = false
	ex.sim = fk
	if with_shell:
		var sh := FakeShell.new()
		sh.sim_ref = fk
		nb = sh
		sh.panels["dossier"] = ex
		tree.root.add_child(sh)
		ex.set_shell(sh)
	tree.root.add_child(ex)

func all_text(n: Node, out: Array) -> Array:
	if n is Label:
		out.append(String(n.text))
	elif n is Button:
		out.append(String(n.text))
	elif n is RichTextLabel:
		out.append(n.get_parsed_text())
	for c in n.get_children():
		all_text(c, out)
	return out

func find(n: Node, nm: String) -> Node:
	if String(n.name) == nm:
		return n
	for c in n.get_children():
		var f := find(c, nm)
		if f != null:
			return f
	return null

# ------------------------------------------------------------------ modelo
func test_model_norm_full_and_pass() -> void:
	var h := Model.norm({"id": "Q9", "text": "¿?", "doubts": ["a", "b", "c", "d"], "answer": null, "proofs": [null, {"id": "RC0001"}],
		"formal": [{"code": "falta_respuesta"}, "mismo_papel"]})
	eq(h.doubts.size(), 3, "como mucho tres dudas")
	eq(h.state, "lapiz")
	no(Model.full(h), "sin respuesta no está llena")
	eq(h.formal, ["falta_respuesta", "mismo_papel"], "códigos de forma normalizados")
	eq(Model.live_formal(h), ["mismo_papel"], "antes de intentar sólo se dice «mismo papel»")
	h.answer = {"id": "x", "label": "Equis"}
	h.proofs[0] = {"id": "RC0002"}
	ok(Model.full(h), "respuesta y dos pruebas")
	ok(Model.can_pass(h), "con las tres ranuras llenas aparece «Pasar en limpio»")
	no(Model.can_pass(h, {"exp.pasar": false}), "la bandera de la partida manda")
	ok(Model.can_pass(h, {"exp.pasar": {"Q9": true}}), "bandera por hoja")
	h.state = "tinta"
	no(Model.can_pass(h), "en tinta no se pasa otra vez")
	eq(Model.answer_label(h), "Equis")
	eq(Model.words("  una  frase de cinco palabras "), 5)

func test_model_reads_fake_dossier() -> void:
	make_fake()
	var d := Model.dossier(fk)
	eq(d.open.map(func(x): return x.id), ["Q1", "Q2"], "abiertas en orden de aparición")
	eq(d.inked, [], "nada en tinta")
	eq(Model.encargo_view(fk), "D23@L1", "el encargo está a mano en el prólogo")
	var opts := Model.answer_options(fk, "Q1")
	ok(opts.size() >= 10, "opciones por los tipos que acepta la pregunta")
	no(opts.map(func(o): return o.id).has("watson"), "una persona no responde una pregunta que pide un concepto")
	eq(Model.formal_text(fk, "mismo_papel"), "Las dos pruebas salen del mismo papel.")
	eq(Model.err_text(fk, "fuera_de_lista"), "Esta pregunta pide otra clase de respuesta.")

# ------------------------------------------------------------------ vista
func test_open_shows_index_sheet_and_no_counters() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(3)
	var st: Dictionary = ex.debug_state()
	ok(st.open, "abierta")
	eq(st.selected, "Q1", "la primera abierta, elegida")
	eq(st.index_rows, ["Q1", "Q2"], "el índice lista las abiertas")
	ok(ex.rect_of("encargo").size.x > 0.0, "«El encargo» a la vista en el índice")
	no(st.has_ink_fold, "sin nada en tinta, sin «En tinta»")
	var txt: Array = all_text(ex, [])
	has(txt, "¿Qué no contó Watson?", "la pregunta")
	has(txt, "La pregunta del cliente, en el encargo.", "el origen")
	has(txt, "– ¿Hay otra versión del texto?", "las dudas de Lisle, a lápiz")
	has(txt, "Respuesta:", "la ranura de la respuesta")
	has(txt, "Pruebas:", "las ranuras de las pruebas")
	has(txt, "Soltar acá un recorte del cuaderno", "una ranura vacía dice qué hacer")
	has(txt, "Una respuesta y dos pruebas: dos recortes de papeles distintos, cada uno con lo que pide su rótulo.", "la hoja vacía explica la forma")
	no(st.pass, "sin las tres ranuras llenas no hay «Pasar en limpio»")
	eq(st.answer, "", "sin respuesta")
	# sin contadores: ningún número en lo que se ve (ni «2 de 10», ni intentos, ni «En tinta (n)»)
	var digits := RegEx.new()
	digits.compile("[0-9]")
	for t in txt:
		no(digits.search(String(t)) != null, "texto sin cifras: «%s»" % t)
	ok(ex.rect_of("prueba", 0).size.y >= 60.0 and ex.rect_of("prueba", 1).size.y >= 60.0, "dos ranuras con lugar para soltar")
	ok(ex.rect_of("respuesta").size.x >= 150.0, "la ranura de la respuesta se ve")

func test_select_other_question() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var got: Array = []
	ex.question_selected.connect(func(q): got.append(q))
	ex.select("Q2")
	await frames(2)
	eq(ex.debug_state().selected, "Q2")
	eq(got, ["Q2"])
	has(all_text(ex, []), "¿Qué pasó en la cascada?")
	ex.close()
	ex.open()
	await frames(2)
	eq(ex.debug_state().selected, "Q2", "al reabrir, la última hoja vista")

func test_answer_picker_seven_and_search() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.open_picker("Q1")
	await frames(2)
	var p = ex.picker()
	ok(p != null, "clic en la respuesta abre el selector")
	eq(p.visible_ids().size(), Picker.MAX_SHOWN, "a la vista, como mucho siete")
	ok(p.more_visible(), "con más opciones, se avisa que hay más (sin número)")
	ok(p.filter != null, "con más de siete, el buscador")
	p.filter_text("raspa")
	eq(p.visible_ids(), ["raspadura"], "el buscador encuentra entre todas, sin tildes")
	p.filter_text("zzz")
	eq(p.visible_ids(), [], "nada con esas letras")
	p.filter_text("")
	p.pick_id("raspadura")
	await frames(2)
	eq(ex.picker(), null, "elegir cierra el selector")
	eq(ex.debug_state().answer, "Raspadura", "la respuesta, a lápiz")
	eq(fk.acts_log[-1], {"t": "dq_answer", "q": "Q1", "value": "raspadura"}, "dq_answer")
	ex.open_picker("Q1")
	await frames(2)
	has(ex.picker().visible_ids(), "", "con respuesta puesta se puede dejar en blanco")
	ok(ex.back(), "Esc cierra primero el selector")
	eq(ex.picker(), null)
	ok(ex.is_open(), "y la carpeta sigue abierta")

func test_drop_proofs_replace_move_and_clear() -> void:
	var ids := make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var s0 = ex._proof_slots[0]
	ok(s0._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.a}), "una ranura acepta un recorte")
	no(s0._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "reichenbach"}), "no acepta una ficha del índice")
	no(s0._can_drop_data(Vector2.ZERO, {"kind": "pair", "id": "PA001"}), "ya no hay pares")
	s0._drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.a})
	await frames(2)
	eq(ex.debug_state().proofs, [ids.a, ""], "prueba 1 puesta")
	ex._proof_slots[1]._drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.c})
	await frames(2)
	eq(ex.debug_state().proofs, [ids.a, ids.c], "prueba 2 puesta")
	var txt: Array = all_text(ex, [])
	has(txt, "Más arriba del sendero hay una cornisa que no se ve desde abajo.", "la tarjeta muestra el recorte completo")
	has(txt, "Guía Baedeker de Suiza", "y su fuente en chico")
	var card: Control = find(ex._proof_slots[1], "Tarjeta")
	ok(card != null and String(card.get_meta("clip", "")) == ids.c, "la ranura muestra la tarjeta del recorte")
	ok(String(ex._proof_slots[1].tooltip_text).contains("Clic derecho"), "al pasar el mouse: cómo sacarla")
	# soltar sobre una ocupada reemplaza
	ex._proof_slots[1]._drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.b})
	await frames(2)
	eq(ex.debug_state().proofs, [ids.a, ids.b], "soltar sobre una ranura ocupada reemplaza")
	# el mismo recorte en la otra ranura se mueve
	ex._proof_slots[1]._drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.a})
	await frames(2)
	eq(ex.debug_state().proofs, ["", ids.a], "el recorte de la otra ranura se mueve")
	ex.clear_proof("Q1", 1)
	await frames(2)
	eq(ex.debug_state().proofs, ["", ""], "vaciar una ranura")

func test_answer_accepts_index_chip() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var a = ex._answer_btn
	ok(a._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "raspadura"}), "la respuesta acepta una ficha del índice")
	no(a._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": "RC0001"}), "no un recorte")
	a._drop_data(Vector2.ZERO, {"kind": "ent", "id": "raspadura"})
	await frames(2)
	eq(ex.debug_state().answer, "Raspadura")
	ex._answer_btn._drop_data(Vector2.ZERO, {"kind": "ent", "id": "watson"})
	await frames(2)
	eq(ex.debug_state().note, "Esta pregunta pide otra clase de respuesta.", "error de forma en la voz de Lisle")
	eq(ex.debug_state().answer, "Raspadura", "la respuesta anterior queda")

func test_same_paper_formal_does_not_count() -> void:
	var ids := make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.set_answer("Q1", "raspadura")
	ex.set_proof("Q1", 0, ids.a)
	ex.set_proof("Q1", 1, ids.d)
	await frames(2)
	has(all_text(ex, []), "Las dos pruebas salen del mismo papel.", "la forma se dice junto a las pruebas")
	ok(ex.debug_state().pass, "las tres llenas: el botón está")
	var r: Dictionary = ex.confirm("Q1")
	await frames(2)
	eq(String(r.get("err", "")), "formal")
	eq(int(fk.attempts.get("Q1", 0)), 0, "la forma no cuenta como intento")
	eq(ex.debug_state().note, "Las dos pruebas salen del mismo papel.", "Lisle lo dice")
	eq(ex.debug_state().state, "lapiz")
	no(ex.debug_state().no_cierra, "no es «Algo no cierra.»: es forma")

func test_pass_clean_wrong_then_ink() -> void:
	var ids := make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.set_answer("Q1", "raspadura")
	ex.set_proof("Q1", 0, ids.a)
	ex.set_proof("Q1", 1, ids.c)
	await frames(2)
	ok(ex.debug_state().pass, "«Pasar en limpio» con las tres ranuras llenas")
	var r: Dictionary = ex.confirm("Q1")
	await frames(2)
	no(bool(r.get("inked", true)), "no cierra")
	var st: Dictionary = ex.debug_state()
	ok(st.no_cierra, "«Algo no cierra.» debajo del botón")
	eq(st.state, "lapiz", "sigue en lápiz")
	eq(st.ink_text, "")
	has(all_text(ex, []), "Algo no cierra.")
	for t in all_text(ex, []):
		no(String(t).contains("respuesta") and String(t).contains("no cierra"), "nunca dice si falló la respuesta o una prueba")
	eq(st.proofs, [ids.a, ids.c], "el borrador queda como estaba")
	# cambiar una prueba borra el «no cierra» de esa hoja
	ex._proof_slots[1]._drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.b})
	await frames(2)
	no(ex.debug_state().no_cierra, "al cambiar el borrador ya no se ve el aviso viejo")
	var got: Array = []
	ex.inked.connect(func(q): got.append(q))
	r = ex.confirm("Q1")
	await frames(3)
	ok(bool(r.get("inked", false)), "cierra")
	eq(got, ["Q1"])
	st = ex.debug_state()
	eq(st.state, "tinta", "la hoja pasa a tinta")
	eq(st.ink_text, "Watson vio en la roca una raspadura fresca y la escribió. En la revista esa frase no está.", "con el texto de Lisle")
	eq(st.answer, "Raspadura")
	eq(st.proofs, [ids.a, ids.b], "con sus dos pruebas")
	eq(st.selected, "Q1", "la carpeta se queda en esa hoja")
	no(st.pass, "en tinta no hay botón")
	for ps in ex._proof_slots:
		no(ps.editable, "las pruebas en tinta no se tocan")
	no(ex._proof_slots[0]._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.c}), "no se suelta nada en tinta")
	ok(ex._ink_label.visible_ratio < 1.0, "Lisle escribe la tinta de a poco (revelado)")
	no(find(ex, "Respuesta") is Button, "la respuesta en tinta no es un botón")
	eq(st.index_rows.has("Q1"), true, "en el índice, bajo «En tinta»")
	ok(st.has_ink_fold, "aparece «En tinta»")
	eq(st.open_ids, ["Q2"])
	eq(st.inked_ids, ["Q1"])

func test_first_ink_sober_moment_only_once() -> void:
	var ids := make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.set_answer("Q1", "raspadura")
	ex.set_proof("Q1", 0, ids.a)
	ex.set_proof("Q1", 1, ids.b)
	ex.confirm("Q1")
	await tree.create_timer(0.6).timeout
	ok(ex.debug_state().dim > 0.05, "primera tinta: la luz baja")
	ok(ex.debug_state().dim <= 0.1001, "sólo un 10 %")
	await tree.create_timer(1.8).timeout
	near(ex.debug_state().dim, 0.0, 0.001, "a los dos segundos vuelve")
	ex.select("Q2")
	ex.set_answer("Q2", "op03")
	ex.set_proof("Q2", 0, ids.a)
	ex.set_proof("Q2", 1, ids.c)
	ex.confirm("Q2")
	await tree.create_timer(0.6).timeout
	near(ex.debug_state().dim, 0.0, 0.001, "la segunda tinta no repite el momento")
	eq(ex.debug_state().inked_ids, ["Q1", "Q2"])
	ok(ex.debug_state().ink_folded == false, "con una hoja en tinta elegida, «En tinta» desplegado")

func test_ink_sheet_rejects_edits() -> void:
	var ids := make_fake()
	fk.ink("Q2", "op03", [ids.a, ids.c])
	make_ex()
	ex.open("Q2")
	await frames(2)
	eq(ex.debug_state().state, "tinta")
	var r: Dictionary = ex.set_answer("Q2", "op01")
	eq(String(r.get("err", "")), "en_tinta")
	eq(ex.debug_state().note, "Lo que está en tinta ya no se toca.")
	ex.open_picker("Q2")
	eq(ex.picker(), null, "en tinta no hay selector")

func test_three_open_and_ink_folded() -> void:
	var ids := make_fake()
	fk.add_question({"id": "Q3", "text": "¿Quién me escribe las cartas sin firma?", "acepta": ["persona"]})
	fk.add_question({"id": "Q5", "text": "¿Quién me contesta firmando «S.»?", "acepta": ["persona"]})
	fk.ink("Q2", "op03", [ids.a, ids.c])
	make_ex()
	ex.open()
	await frames(2)
	var st: Dictionary = ex.debug_state()
	eq(st.open_ids, ["Q1", "Q3", "Q5"], "como mucho tres abiertas")
	ok(st.open_ids.size() <= 3)
	ok(st.has_ink_fold and st.ink_folded, "«En tinta» plegado mientras se trabaja una abierta")
	no(ex.rect_of("pregunta", 3).size.x > 0.0, "la de tinta no se ve con el plegado cerrado")

func test_question_rows_drag_as_items() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var row = ex._rows["Q2"]
	eq(row._get_drag_data(Vector2.ZERO), {"kind": "pregunta", "id": "Q2"}, "una pregunta se arrastra como ítem (informe, mostrar)")
	eq(ex._encargo_row._get_drag_data(Vector2.ZERO), null, "el encargo no")

func test_encargo_opens_reader_view() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var got: Array = []
	ex.encargo_requested.connect(func(v): got.append(v))
	ex.open_encargo()
	eq(got, ["D23@L1"], "«El encargo» abre D23 en el lector")

func test_clip_cards_never_show_more_than_fifteen_words() -> void:
	make_fake()
	var long_id: String = fk.add_clip({"text": "uno dos tres cuatro cinco seis siete ocho nueve diez once doce trece catorce quince dieciséis diecisiete",
		"origin": "D44", "doc": "D44", "src_line": "x"})
	make_ex()
	ex.open()
	await frames(2)
	ex.set_proof("Q1", 0, long_id)
	await frames(2)
	eq(ex.debug_state().max_words_shown, 15, "la tarjeta corta en quince palabras")
	eq(ClipCard.shown_text({"text": "a b c"}), "a b c")

func test_notebook_docks_left_and_closes_with_folder() -> void:
	var ids := make_fake()
	make_ex(true)
	ex.open()
	await frames(4)
	ok(nb.is_open("notebook"), "abrir la carpeta abre el cuaderno")
	var nbp = nb.panel("notebook")
	eq(nbp.layout, "left", "el cuaderno, a la izquierda")
	ok(nbp.narrow, "más angosto junto a la carpeta")
	no(nbp.backdrop, "sin velo: se ve la carpeta")
	var st: Dictionary = ex.debug_state()
	ok(st.side, "la carpeta, acoplada a la derecha")
	ok((st.rect as Rect2).position.x >= (nbp.book_rect() as Rect2).end.x - 1.0, "no se pisan")
	ok((st.rect as Rect2).end.x <= 1600.0 + 1.0, "entra en la pantalla")
	ok(float(st.scale) >= 0.85, "la carpeta se lee (escala %.2f)" % float(st.scale))
	# del cuaderno se arrastra un recorte (sin pares: la tarjeta no recibe nada)
	nbp.show_tab("recortes")
	await frames(2)
	var card = nbp.page("recortes").card(ids.a)
	ok(card != null, "la tarjeta del recorte en el cuaderno")
	eq(card._get_drag_data(Vector2.ZERO), {"kind": "clip", "id": ids.a}, "se arrastra como recorte")
	no(card.has_method("_can_drop_data") and card._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": ids.b}), "no recibe recortes (sin pares)")
	ex._proof_slots[0]._drop_data(Vector2.ZERO, card._get_drag_data(Vector2.ZERO))
	await frames(2)
	eq(ex.debug_state().proofs[0], ids.a, "de la tarjeta a la ranura, directo")
	ex.close()
	await frames(2)
	no(nb.is_open("notebook"), "la carpeta cierra el cuaderno que abrió")

func test_hint_proof_click_empty_slot() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.hint_proof()
	eq(ex.debug_state().note, "Arrastro un recorte del cuaderno hasta acá.", "clic en una ranura vacía: Lisle dice cómo")
	# sin un solo recorte (hud.cuaderno falso) no hay cuaderno que mostrar: Lisle dice de dónde salen
	fk.flags = {"hud.cuaderno": false}
	ex.close()
	ex.open()
	await frames(2)
	ex.hint_proof()
	eq(ex.debug_state().note, Model.tx(fk, "exp.prueba.sin_recortes"), "sin recortes todavía: de dónde salen")
	ne(ex.debug_state().note, "exp.prueba.sin_recortes", "el texto existe en ui_text")

# El cuaderno acoplado sale en Recortes (de ahí se arrastran las pruebas), aunque el jugador lo haya dejado en el Diario;
# abierto de antes en el Diario, también pasa a Recortes; en el Índice se queda (sus fichas sirven para la respuesta),
# salvo con un clic en una prueba vacía.
func test_docked_notebook_shows_clips() -> void:
	make_fake()
	make_ex(true)
	var sh = nb
	var nbp = sh.open_panel("notebook", ["diario"])
	await frames(2)
	eq(String(nbp.tab), "diario", "el jugador lo dejó en el Diario")
	sh.close_kind("notebook")
	await frames(2)
	ex.open()
	await frames(3)
	ok(sh.is_open("notebook"), "la carpeta abre el cuaderno")
	eq(String(nbp.tab), "recortes", "acoplado, en Recortes")
	eq(sh.opened_args[-1], ["recortes"], "lo pide en Recortes")
	ex.close()
	await frames(2)
	# ya abierto en el Diario
	sh.open_panel("notebook", ["diario"])
	await frames(2)
	ex.open()
	await frames(3)
	eq(String(nbp.tab), "recortes", "abierto de antes en el Diario: pasa a Recortes")
	ex.close()
	await frames(2)
	sh.close_kind("notebook")
	await frames(2)
	# ya abierto en el Índice: se queda (las fichas van a la Respuesta); un clic en una prueba vacía lo lleva a Recortes
	sh.open_panel("notebook", ["indice"])
	await frames(2)
	ex.open()
	await frames(3)
	eq(String(nbp.tab), "indice", "en el Índice se queda")
	ex.hint_proof()
	await frames(2)
	eq(String(nbp.tab), "recortes", "clic en una prueba vacía: Recortes")

func test_theme_and_high_contrast_rebuild() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(2)
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti == null:
		skip("sin ThemeInstaller")
		return
	ti.set_high_contrast(true)
	await frames(3)
	has(all_text(ex, []), "¿Qué no contó Watson?", "en alto contraste se reconstruye igual")
	ti.set_high_contrast(false)
	await frames(2)

# ------------------------------------------------------------------ integración con CORE (GameSim real)
# Partida nueva: Q1 está desde el inicio. Dos recortes con las etiquetas y claves de la ruta Q1.R2 (D03#sheer + D05#marque,
# dos papeles): con la respuesta equivocada «Algo no cierra.»; con «raspadura», tinta con el texto de data/dossier.json.
func test_real_core_q1_pencil_to_ink() -> void:
	var GS = load("res://core/sim/game_sim.gd")
	var r = repo()
	if GS == null or not GS.can_instantiate():
		fail("core/sim/game_sim.gd no compila")
		return
	var s = GS.new(r, 7)
	if not s.has_method("q_dossier"):
		pending_content("la GameSim todavía no tiene q_dossier (CORE)")
		return
	var q1: Dictionary = r.question("Q1") if r.has_method("question") else {}
	if q1.is_empty():
		pending_content("data/dossier.json sin Q1")
		return
	# el prólogo admite los verbos del expediente desde el paso «clip» (core/sim/tutorial.gd): se deja leído el encargo
	if typeof(s.st.world.get("tutorial")) == TYPE_DICTIONARY and int(s.st.world.tutorial.get("step", 0)) < 1:
		s.st.world.tutorial["step"] = 1
	var C = load("res://core/deduction/clipper.gd")
	var a: String = C.inject(s.st, r, {"text": "La senda termina de pronto en la pared.", "origin": "D03", "doc": "D03", "copy": "D03@Crane",
		"src_type": "cronica", "src_line": "«El problema final», crónica", "ents": ["fina", "reichenbach", "pared"], "tags": ["a:fina_impreso_sin_raspadura"]})
	var b: String = C.inject(s.st, r, {"text": "Une marque fraîche sur la roche.", "origin": "D05", "doc": "D05", "copy": "D05@BM",
		"src_type": "prensa_extranjera", "src_line": "Journal de Genève", "ents": ["reichenbach", "roca", "raspadura"], "tags": ["a:raspadura_registrada"]})
	ex = Expediente.new()
	ex.sounds = false
	ex.sim = s
	tree.root.add_child(ex)
	ex.open()
	await frames(2)
	has(ex.debug_state().open_ids, "Q1", "Q1 abierta desde el inicio")
	ex.select("Q1")
	var opts := Model.answer_options(s, "Q1").map(func(o): return String(o.id))
	has(opts, "raspadura", "la raspadura se puede elegir (está en el índice y es un concepto)")
	var wrong := ""
	for o in opts:
		if String(o) != "raspadura" and String(o) != "marca_en_la_roca":
			wrong = String(o)
			break
	ok(bool(ex.set_proof("Q1", 0, a).get("ok", false)), "prueba 1")
	ok(bool(ex.set_proof("Q1", 1, b).get("ok", false)), "prueba 2")
	if wrong != "":
		ok(bool(ex.set_answer("Q1", wrong).get("ok", false)), "respuesta equivocada a lápiz")
		await frames(2)
		var r1: Dictionary = ex.confirm("Q1")
		no(bool(r1.get("inked", true)), "con otra respuesta no cierra")
		ok(ex.debug_state().no_cierra, "«Algo no cierra.»")
	ok(bool(ex.set_answer("Q1", "raspadura").get("ok", false)), "respuesta")
	await frames(2)
	ok(ex.debug_state().pass, "«Pasar en limpio» a la vista")
	var r2: Dictionary = ex.confirm("Q1")
	await frames(2)
	ok(bool(r2.get("inked", false)), "cierra: %s" % str(r2))
	var st: Dictionary = ex.debug_state()
	eq(st.state, "tinta")
	var tinta := ""
	for v in q1.get("variantes", []):
		if bool(v.get("principal", false)):
			tinta = String(v.get("tinta", ""))
	eq(st.ink_text, tinta, "el texto en tinta es el de data/dossier.json")

# «El encargo» abre el lector como tercer panel: la Shell cierra el de abajo (el cuaderno). Al cerrar el lector, con la
# carpeta abierta, el cuaderno vuelve acoplado (de ahí salen las pruebas).
func test_notebook_returns_after_reading_encargo() -> void:
	make_fake()
	make_ex(true)
	ex.open()
	await frames(3)
	ok(nb.is_open("notebook"), "cuaderno abierto con la carpeta")
	# como Shell.push: el lector ya está, se cierra el de abajo y recién después se anuncia el lector
	nb.reader_on = true
	nb.close_kind("notebook")
	nb.panel_opened.emit("reader")
	await frames(2)
	no(nb.is_open("notebook"), "el lector se lleva el cuaderno (tope de dos paneles)")
	nb.reader_on = false
	nb.panel_closed.emit("reader")
	await frames(3)
	ok(nb.is_open("notebook"), "al cerrar el lector, el cuaderno vuelve")
	# cerrar el cuaderno a mano (Tab) no lo trae de vuelta
	nb.close_kind("notebook")
	nb.panel_closed.emit("reader")
	await frames(3)
	no(nb.is_open("notebook"), "cerrado a mano, queda cerrado")
	eq(nb.panel("notebook").layout, "left", "acoplado a la izquierda")

# Las hojas reales de CORE (tests/fixtures/v3/v3_fixture.gd: día 1; Q1 en lápiz con respuesta y una prueba, Q2 en tinta,
# Q3 abierta vacía) se ven como corresponde, y se terminan de llenar y pasar en limpio por la carpeta.
func test_core_fixture_pencil_ink_and_empty() -> void:
	var F = load("res://tests/fixtures/v3/v3_fixture.gd")
	if F == null:
		pending_content("falta tests/fixtures/v3/v3_fixture.gd (CORE)")
		return
	var s = F.sim(repo())
	var ids: Dictionary = s.get_meta("v3_clips")
	ex = Expediente.new()
	ex.sounds = false
	ex.sim = s
	tree.root.add_child(ex)
	ex.open("Q1")
	await frames(2)
	var st: Dictionary = ex.debug_state()
	has(st.open_ids, "Q1")
	has(st.open_ids, "Q3")
	eq(st.inked_ids, ["Q2"], "Q2 en tinta")
	ok(st.has_ink_fold, "«En tinta» en el índice")
	eq(st.state, "lapiz")
	ok(String(st.answer) != "", "la respuesta a lápiz se ve (%s)" % st.answer)
	eq(st.proofs, [String(ids.marque), ""], "una prueba puesta, la otra vacía")
	no(st.pass, "con una ranura vacía no hay «Pasar en limpio»")
	ex.select("Q2")
	await frames(2)
	st = ex.debug_state()
	eq(st.state, "tinta")
	ok(String(st.ink_text).length() > 20, "el texto de Lisle en tinta")
	for ps in ex._proof_slots:
		no(ps.editable, "en tinta no se toca")
	ex.select("Q3")
	await frames(2)
	has(all_text(ex, []), "Soltar acá un recorte del cuaderno", "Q3 vacía invita a soltar")
	# Q1: la segunda prueba (otro papel) y pasar en limpio con el validador real
	ex.select("Q1")
	await frames(2)
	ex._proof_slots[1]._drop_data(Vector2.ZERO, {"kind": "clip", "id": String(ids.sheer)})
	await frames(2)
	ok(ex.debug_state().pass, "tres ranuras llenas")
	var r: Dictionary = ex.confirm("Q1")
	await frames(2)
	ok(bool(r.get("ok", false)), "dq_confirm aceptado: %s" % str(r))
	if bool(r.get("inked", false)):
		eq(ex.debug_state().state, "tinta", "cierra: tinta")
		eq(ex.debug_state().inked_ids, ["Q2", "Q1"], "en orden de tinta")
	else:
		ok(ex.debug_state().no_cierra, "no cierra: sólo «Algo no cierra.»")

# Accesibilidad: con el texto a 1,3× y 1,6× nada se sale de la hoja ni del índice (lo largo se desplaza hacia abajo).
func test_text_scale_fits() -> void:
	var ids := make_fake()
	make_ex()
	ex.open()
	await frames(2)
	ex.set_answer("Q1", "raspadura")
	ex.set_proof("Q1", 0, ids.a)
	ex.set_proof("Q1", 1, ids.c)
	var ti = tree.root.get_node_or_null("ThemeInstaller")
	if ti == null:
		skip("sin ThemeInstaller")
		return
	for sc in [1.3, 1.6]:
		ti.set_text_scale(sc)
		await frames(4)
		ex.refresh()
		await frames(3)
		var sheet_w: float = ex._sheet_box.get_combined_minimum_size().x
		ok(sheet_w <= Expediente.SHEET_R.size.x - 60.0 + 1.0, "%.1f×: la hoja cabe a lo ancho (%d)" % [sc, sheet_w])
		var idx_w: float = ex._index.get_combined_minimum_size().x
		ok(idx_w <= Expediente.INDEX_R.size.x + 1.0, "%.1f×: el índice cabe a lo ancho (%d)" % [sc, idx_w])
		ok(ex.debug_state().pass, "%.1f×: «Pasar en limpio» sigue ahí" % sc)
	ti.set_text_scale(1.0)
	await frames(2)

func test_tutor_rect_inside_index_flap() -> void:
	make_fake()
	make_ex()
	ex.open()
	await frames(3)
	var r: Rect2 = ex.tutor_rect()
	ok(r.size.y >= 120.0, "queda lugar en la solapa para la nota del instructor")
	ok(r.position.y > ex.row_rect("Q2").end.y, "debajo de las preguntas")
	ok(Rect2(ex.debug_state().rect).encloses(r), "dentro de la carpeta")

# Con el lector encima de la carpeta (el encargo), la solapa no es lugar para la nota: caería sobre el documento
# (verificación v3: la nota tapaba el texto de D23).
func test_tutor_rect_empty_with_reader_on_top() -> void:
	make_fake()
	make_ex(true)
	ex.open()
	await frames(3)
	ok(ex.tutor_rect().size.y >= 120.0, "carpeta a la vista: hay lugar")
	nb.reader_on = true
	no(ex.tutor_rect().size.x > 0.0, "con el lector encima: Rect2()")
	nb.reader_on = false
	ok(ex.tutor_rect().size.y >= 120.0, "vuelve al cerrar el lector")
	ok(ex.rect_of("hoja").size.x > 0.0, "rect_of(\"hoja\"): la hoja de la pregunta")
