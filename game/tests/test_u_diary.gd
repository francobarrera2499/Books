# W2-SIM: diario D36: plantillas de lists.diary (búsqueda por lugar/área/personaje), una oración por línea con su
# tramo de etiquetas, fecha «Mar. 27» sin cortar la oración, contracciones, entidad del acto (etiqueta legible),
# llegadas (una por vista), líneas dichas con el origen de su escena, «en casa».
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Diary = preload("res://core/sim/diary.gd")
const Markup = preload("res://core/text/markup.gd")

func _at(day: int, slot: String):
	var s = Kit.new_sim()
	eq(Kit.advance_to(s, day, slot), "", "avance a %d.%s" % [day, slot])
	return s

func _acts(s) -> Array:
	var out: Array = []
	for d in s.q_diary():
		if d.kind == "act":
			out.append(d)
	return out

func test_template_keys():
	var r = Kit.repo()
	eq(Diary.template_key(r, {"type": "go"}, "L3", "interior"), "go.L3")
	eq(Diary.template_key(r, {"type": "go"}, "L3", "calle"), "go.L3.calle")
	eq(Diary.template_key(r, {"type": "go"}, "L4", "consulta"), "go")
	eq(Diary.template_key(r, {"type": "say", "char": "watson"}, "L4", "consulta"), "say.watson")
	eq(Diary.template_key(r, {"type": "say", "char": "portero"}, "L5", "porteria"), "say")
	eq(Diary.template_key(r, {"type": "nada"}, "", ""), "")

func test_dates_and_money():
	var r = Kit.repo()
	eq(Diary.fecha_plain(r, 1), "mar. 27")
	eq(Diary.fecha_markup(r, 1), "Mar\\. 27")
	eq(Markup.parse(Diary.fecha_markup(r, 4) + ", M: algo.").sentences.size(), 1, "el punto de «Vie.» no corta")
	eq(Diary.franja(r, "M"), "M")
	eq(Diary.franja(r, "dawn"), "amanecer")
	eq(Diary.franja(r, "night"), "noche")
	eq(Diary.money_words(r, 12), "un chelín")
	eq(Diary.money_words(r, 30), "dos chelines y seis peniques")
	eq(Diary.money_words(r, 6), "seis peniques")
	eq(Diary.money_words(r, 1), "un penique")
	eq(Diary.clause(r, "Se busca testigo de lo de Reichenbach. Escribir a E. L., Holywell Street.", true), "Se busca testigo de lo de Reichenbach")
	eq(Diary.clause(r, "Uno dos tres cuatro cinco seis", true, 3), "Uno dos tres")
	eq(Diary.clause(r, "Mr. Holmes vive, doctor."), "Mr. Holmes vive, doctor.", "abreviatura de lists.abbrev")

func test_walk_lines_are_one_sentence_with_tags():
	var s = Kit.new_sim()
	Kit.run(s, Kit.load_jsonl(Kit.WALK))
	var acts := _acts(s)
	ok(acts.size() >= 8, str(acts.size()))
	for d in acts:
		var p: Dictionary = d.parsed
		eq(p.errors, [], d.text)
		eq(p.sentences.size(), 1, "una oración: " + p.plain)
		ok(p.words.size() <= 40, "≤40 palabras: " + p.plain)
		eq(d.origin, "D36")
		var key := String(d.key)
		var tags: Array = Kit.repo().lists().diary[key].get("tags", [])
		if tags.size() > 0:
			eq(p.tramos.size(), 1, key)
			eq(p.tramos[0].from, 0, "el tramo cubre la línea: " + key)
			eq(p.tramos[0].to, p.plain.length(), key)
		var act_ment := false
		for m in p.mentions:
			if String(m.ent) == String(d.act):
				act_ment = true
		ok(act_ment, "[[@act|…]] = entidad del acto: " + p.plain)
	var plains: Array = []
	for d in acts:
		plains.append(d.parsed.plain)
	has(plains, "Mar. 27, M: Sala de Lectura, asiento 214; pedí Journal de Genève, miércoles 6 de mayo de 1891.")
	has(plains, "Mar. 27, amanecer: sale mi aviso en el Times: «Se busca testigo de lo de Reichenbach…»")
	has(plains, "Mié. 28, M: Kensington; le dije al doctor: «La pared era a pique, ¿no, doctor?»")
	has(plains, "Mar. 27, T: Baker Street, visita al 221B.")
	has(plains, "Mié. 28, noche: entregué el informe 1: sin novedad.")
	var slip_d: Dictionary = {}
	for d in acts:
		if d.type == "slip":
			slip_d = d
	eq(slip_d.parsed.tramos[0].tags.a, ["acto_kbm"])
	var ents: Array = []
	for m in slip_d.parsed.mentions:
		ents.append(m.ent)
	has(ents, "journal_de_geneve", "el título lleva la mención del documento")

func test_act_entities_and_labels():
	var s = Kit.new_sim()
	Kit.run(s, Kit.load_jsonl(Kit.WALK))
	var labels := {}
	for ev in s.st.events:
		var a: Dictionary = s.q_act(ev.act)
		eq(a.kind, "act_ref")
		eq(a.id, ev.act)
		labels[ev.type] = a.label
	eq(labels.slip, "asiento 214, mar. 27")
	eq(labels.go, "Baker Street, jue. 29")
	eq(labels.report, "informe 1, mié. 28")
	eq(labels.ad, "mi aviso del jue. 29")

func test_contraction_and_generic_say():
	var s = _at(1, "M")
	ok(s.apply({"t": "go", "place": "L5", "area": "porteria"}).ok)
	ok(s.apply({"t": "ask", "char": "portero", "topic": "mycroft"}).ok)
	var last: Dictionary = _acts(s)[-1]
	eq(last.key, "say")
	ok(String(last.parsed.plain).contains("le dije al portero:"), last.parsed.plain)
	ok(String(last.parsed.plain).contains("Club Diógenes, Pall Mall;"), last.parsed.plain)

# Contracciones con borde de palabra (bug: «para el» -> «paral» con un replace ciego de «a el »).
func test_contraction_word_boundary():
	var r = Kit.repo()
	var txt := Diary.compose(r, "say", {"fecha": "Mar. 27", "franja": "M", "lugar": "Club Diógenes", "quien": "el portero",
		"frase": "Es para el doctor; nadie puede el domingo"})
	ok(txt.contains("le dije al portero"), txt)
	ok(txt.contains("Es para el doctor; nadie puede el domingo"), txt)
	no(txt.contains("paral") or txt.contains("pudel"), txt)

func test_stay_home_line():
	var s = _at(1, "M")
	ok(s.apply({"t": "end_slot"}).ok)
	var found := false
	for d in s.q_diary():
		if d.kind == "private" and d.key == "stay":
			found = true
			eq(d.parsed.plain, "Mar. 27, M: en casa.")
	ok(found)

func test_arrivals_once_per_view_and_lines_with_origin():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	var arr: Array = []
	for d in s.q_diary():
		if d.kind == "arrival":
			arr.append(d)
	eq(arr.size(), 1)
	eq(arr[0].parsed.plain, "Mar. 27, amanecer: Recibido: el Times.")
	Diary.on_arrival(s.st, s.repo, "D15.0327@L1")
	var n := 0
	for d in s.q_diary():
		if d.kind == "arrival":
			n += 1
	eq(n, 1, "una por vista")
	var lines: Array = []
	for d in s.q_diary():
		if d.kind == "line":
			lines.append(d)
	ok(lines.size() >= 3)
	eq(lines[0].origin, "S.PRO")
	var cace: Dictionary = {}
	for d in lines:
		if String(d.parsed.plain).begins_with("Cacé"):
			cace = d
	eq(cace.parsed.tramos[0].tags.a, ["cazador"], "el diario conserva tramos y etiquetas de la línea")
	var g: Dictionary = Diary.get_line(s.st, s.repo, cace.id)
	eq(g.origin, "S.PRO")
	eq(g.parsed.plain, cace.parsed.plain)
	eq(Diary.get_line(s.st, s.repo, "DY.9999"), {})

func test_blind_shop_visit_line():
	var s = _at(1, "M")
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	var last: Dictionary = s.q_diary()[-1]
	eq(last.kind, "private", "acto ciego: sin evento ni entidad de acto")
	eq(last.parsed.plain, "Mar. 27, M: bajé a la tienda de Crane.")
	eq(last.act, "")
