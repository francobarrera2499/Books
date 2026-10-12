# W2-SIM: tutorial del prólogo (un verbo por paso con instructor) y verbos enseñados en contexto (T24).
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Tutorial = preload("res://core/sim/tutorial.gd")

func _said_ids(s) -> Array:
	var out: Array = []
	for uid in s.st.world.lines:
		out.append(s.st.world.lines[uid].id)
	return out

func test_steps_shape_and_lines_exist():
	var r = Kit.repo()
	var ids: Array = []
	for st in Tutorial.STEPS:
		ids.append(st.id)
		var lid := String(st.line_id)
		eq(lid.get_slice(".", 0), "PRO")
		var found := false
		for ln in r.scene("PRO").lines:
			if String(ln.id) == lid.get_slice(".", 1):
				found = true
		ok(found, "la línea del instructor existe en el fixture: " + lid)
	eq(ids, ["clip", "link", "folio", "entry", "practice", "ad", "sleep"])
	var s = Kit.new_sim()
	var stp: Dictionary = Tutorial.step(s.st)
	for k in ["id", "instructor", "line_id", "verb"]:
		ok(stp.has(k), k)
	eq(stp.instructor, "pell")

func test_one_verb_per_step():
	var s = Kit.new_sim()
	var p: Array = Kit.prologue()
	no(Tutorial.allowed(s.st, {"t": "link"}), "vincular antes de recortar")
	no(Tutorial.allowed(s.st, {"t": "compose_ad"}))
	no(Tutorial.allowed(s.st, {"t": "sleep"}))
	no(Tutorial.allowed(s.st, {"t": "go"}), "lo que no es del tutorial")
	ok(Tutorial.allowed(s.st, {"t": "clip_measure"}), "cualquier recorte en el paso de recortar")
	ok(s.apply(p[0]).ok)
	eq(Tutorial.step(s.st).id, "link")
	ok(_said_ids(s).has("t_link"), "la línea del paso nuevo se dice al empezar")
	ok(Tutorial.allowed(s.st, {"t": "clip_text"}), "lo ya enseñado sigue permitido")
	ok(s.apply(p[1]).ok, "recortar de nuevo no avanza ni falla")
	eq(Tutorial.step(s.st).id, "link")
	for i in range(2, 5):
		ok(s.apply(p[i]).ok, str(p[i]))
	eq(Tutorial.step(s.st).id, "entry")
	ok(s.apply(p[5]).ok)
	eq(Tutorial.step(s.st).id, "entry", "falta el según")
	ok(s.apply(p[6]).ok)
	eq(Tutorial.step(s.st).id, "practice")
	ok(s.apply(p[7]).ok, "otro según: ya en el paso de practicar")
	eq(Tutorial.step(s.st).instructor, "pell")
	ok(s.apply(p[8]).ok)
	eq(Tutorial.step(s.st).id, "ad", "practicar avanza aunque no entinte")
	eq(Tutorial.step(s.st).instructor, "harris")
	no(Tutorial.complete(s.st))
	ok(s.apply(p[9]).ok)
	eq(Tutorial.step(s.st).id, "sleep")
	ok(Tutorial.complete(s.st))
	ok(s.apply(p[10]).ok)
	eq(Tutorial.step(s.st), {}, "fuera del prólogo no hay paso")
	ok(Tutorial.allowed(s.st, {"t": "go"}), "fuera del prólogo todo pasa por las fases")

func test_verbs_taught_in_context():
	var s = Kit.new_sim()
	eq(Tutorial.verbs_taught(s.st), [])
	Kit.run(s, Kit.prologue())
	var v: Array = Tutorial.verbs_taught(s.st)
	for x in ["clip_text", "link", "folio_open", "entry_new", "practice", "pass_clean", "compose_ad", "sleep", "go", "end_slot"]:
		has(v, x)
	no(v.has("slip"))
	no(v.has("report_submit"))
	eq(v.find("clip_text") < v.find("go"), true, "orden de enseñanza")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 3}).ok)
	has(Tutorial.verbs_taught(s.st), "slip", "el ujier enseña la papeleta al llegar")
	ok(s.apply({"t": "leave"}).ok)
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	for x in ["ask", "assert", "present"]:
		has(Tutorial.verbs_taught(s.st), x, "Crane, interlocutor gratuito")
	ok(s.apply({"t": "leave"}).ok)
	eq(Kit.advance_to(s, 2, "N"), "")
	no(Tutorial.verbs_taught(s.st).has("report_submit"), "la noche del 1 no tiene informe")
	ok(s.apply({"t": "end_slot"}).ok)
	has(Tutorial.verbs_taught(s.st), "report_submit", "el chico de Pell en la noche de informe")
