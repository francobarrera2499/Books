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
	eq(ids, ["read", "clip", "ad", "sleep"], "GDD_v2 §B.7: el prólogo enseña leer, recortar, el aviso y dormir")
	eq(Tutorial.DAY1.map(func(x): return x.id), ["d1_clip", "d1_link", "d1_folio", "d1_entry", "d1_practice"])
	for x in Tutorial.DAY1:
		ok(String(x.line_key).begins_with("tut.d1."), "las notas de Lisle son ui_text tut.d1.*")
		eq(x.instructor, "lisle")
	var s = Kit.new_sim()
	var stp: Dictionary = Tutorial.step(s.st)
	for k in ["id", "instructor", "line_id", "verb"]:
		ok(stp.has(k), k)
	eq(stp.instructor, "pell")
	eq(stp.id, "read")

func _read_d23(s) -> Dictionary:
	return s.apply({"t": "read", "view": "D23@L1", "part": 0})

func test_one_verb_per_step():
	var s = Kit.new_sim()
	var p: Array = Kit.prologue()
	no(Tutorial.allowed(s.st, {"t": "link"}), "juntar antes de recortar")
	no(Tutorial.allowed(s.st, {"t": "folio_open"}))
	no(Tutorial.allowed(s.st, {"t": "compose_ad"}))
	no(Tutorial.allowed(s.st, {"t": "sleep"}))
	no(Tutorial.allowed(s.st, {"t": "go"}), "lo que no es del tutorial")
	ok(Tutorial.allowed(s.st, {"t": "read"}))
	# leer otra cosa no completa «abrir el encargo»
	ok(s.apply({"t": "read", "view": "D03@tomo", "part": 0}).ok)
	eq(Tutorial.step(s.st).id, "read")
	ok(_read_d23(s).ok)
	eq(Tutorial.step(s.st).id, "clip")
	ok(_said_ids(s).has("t_clip"), "la línea del paso nuevo se dice al empezar")
	ok(Tutorial.allowed(s.st, {"t": "clip_measure"}), "cualquier recorte en el paso de recortar")
	ok(Tutorial.allowed(s.st, {"t": "link"}), "desde recortar, la primera conclusión no se traba (no la enseña el prólogo)")
	no(Tutorial.allowed(s.st, {"t": "sleep"}))
	ok(s.apply(p[0]).ok)
	eq(Tutorial.step(s.st).id, "ad")
	eq(Tutorial.step(s.st).instructor, "harris")
	no(Tutorial.complete(s.st))
	ok(s.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok)
	eq(Tutorial.step(s.st).id, "sleep")
	ok(Tutorial.complete(s.st))
	no(Tutorial.practice_done(s.st), "el prólogo no practica")
	ok(s.apply({"t": "sleep"}).ok)
	eq(Tutorial.step(s.st), {}, "fuera del prólogo no hay paso que bloquee")
	ok(Tutorial.allowed(s.st, {"t": "go"}), "fuera del prólogo todo pasa por las fases")

# Recortar el encargo en el paso «read» lo da por abierto (no se recorta lo que no se tiene delante).
func test_clip_completes_read():
	var s = Kit.new_sim()
	ok(Tutorial.allowed(s.st, {"t": "clip_text"}))
	ok(s.apply(Kit.prologue()[0]).ok)
	eq(Tutorial.step(s.st).id, "ad")
	has(Tutorial.verbs_taught(s.st), "read")
	has(Tutorial.verbs_taught(s.st), "clip_text")

# Día 1: la primera conclusión guía sin bloquear; confirmar pide la práctica (practica_pendiente).
func test_day1_first_conclusion():
	var s = Kit.new_sim()
	for a in Kit.prologue_v2():
		ok(s.apply(a).ok, str(a))
	eq(s.q_clock().phase, "desk")
	eq(s.q_clock().day, 1)
	var d1: Dictionary = s.q_tutorial().day1
	eq(d1.get("id", ""), "d1_link", "dos recortes del prólogo: el paso actual es juntar")
	eq(d1.get("line_key", ""), "tut.d1.link")
	has(Tutorial.verbs_taught(s.st), "link", "el paso actual enseña su verbo")
	no(Tutorial.verbs_taught(s.st).has("pass_clean"))
	ok(s.apply({"t": "entry_new", "folio": "varios", "template": "T1"}).ok, "no bloquea: se puede adelantar")
	eq(s.apply({"t": "pass_clean", "entries": ["AS001", "AS002"]}).err, "practica_pendiente")
	eq(s.q_clock().passes_left, 1, "no gasta")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok, "se puede salir antes")
	ok(s.apply({"t": "leave"}).ok)
	for a in Kit.day1_practice("AS002"):
		ok(s.apply(a).ok, str(a))
	ok(Tutorial.practice_done(s.st))
	eq(s.q_tutorial().day1, {}, "primera conclusión hecha")
	has(Tutorial.verbs_taught(s.st), "pass_clean")
	ok(s.apply({"t": "pass_clean", "entries": ["AS001", "AS002"]}).ok, "con la práctica hecha, confirma")

func test_verbs_taught_in_context():
	var s = Kit.new_sim()
	eq(Tutorial.verbs_taught(s.st), [])
	Kit.run(s, Kit.prologue())
	var v: Array = Tutorial.verbs_taught(s.st)
	for x in ["read", "clip_text", "link", "folio_open", "entry_new", "practice", "pass_clean", "compose_ad", "sleep", "go", "end_slot"]:
		has(v, x)
	no(v.has("slip"))
	no(v.has("report_submit"))
	eq(v.find("clip_text") < v.find("go"), true, "orden de enseñanza")
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 3}).ok)
	has(Tutorial.verbs_taught(s.st), "slip", "el bibliotecario enseña el pedido al llegar")
	ok(s.apply({"t": "leave"}).ok)
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	for x in ["ask", "assert", "present"]:
		has(Tutorial.verbs_taught(s.st), x, "Crane, interlocutor gratuito")
	ok(s.apply({"t": "leave"}).ok)
	eq(Kit.advance_to(s, 2, "N"), "")
	no(Tutorial.verbs_taught(s.st).has("report_submit"), "la noche del 1 no tiene informe")
	ok(s.apply({"t": "end_slot"}).ok)
	has(Tutorial.verbs_taught(s.st), "report_submit", "el chico de Pell en la noche de informe")

# ---------------- W4: el prólogo no se bloquea (datos reales) ----------------
# Recorte lo que recorte el novato en el paso «clip» (cualquier tramo de D23@L1, o la línea del propio instructor), el
# paso «ad» tiene opciones en la forma «testigo» SIN otro recorte: lo que nombra Harris en PRO.t_ad entra al índice
# (GameSim._say_tutorial_line). Luego aviso y dormir.
const TIMEOUT_S := 120
const GameSimR = preload("res://core/sim/game_sim.gd")
const ComposersR = preload("res://core/scenes/composers.gd")

func _w4_find(v: Dictionary, tid: String) -> Dictionary:
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					return {"part": pi, "block": bi, "from": int(tr.from), "to": int(tr.to)}
	return {}

func _w4_clip(sim, view: String, w: Dictionary) -> String:
	var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": int(w.part), "block": int(w.block)}, "from": int(w.from), "len": int(w.to) - int(w.from)})
	return String(r.get("clip", "")) if bool(r.get("ok", false)) else ""

func _w4_clip_line(sim, lid: String, ent: String) -> String:
	for uid in sim.st.world.get("lines", {}):
		if String(sim.st.world.lines[uid].get("id", "")) != lid:
			continue
		for m in sim.q_line(String(uid)).get("parsed", {}).get("mentions", []):
			if String(m.ent) == ent:
				var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "line", "ref": String(uid)}, "from": int(m.from), "len": int(m.to) - int(m.from)})
				return String(r.get("clip", "")) if bool(r.get("ok", false)) else ""
	return ""

func _w4_rest_and_finish(sim, rp, redh: Dictionary, label: String) -> void:
	var ca := _w4_clip(sim, "D01.REDH@tomo", _w4_find(redh, "abril"))
	var co := _w4_clip(sim, "D01.REDH@tomo", _w4_find(redh, "octubre"))
	ok(ca != "" and co != "", label + ": REDH #abril y #octubre")
	ok(sim.apply({"t": "link", "a": ca, "b": co, "note": ""}).ok, label + ": cotejo")
	var rf: Dictionary = sim.apply({"t": "folio_open", "clip": ca})
	var re: Dictionary = sim.apply({"t": "entry_new", "folio": String(rf.get("folio", "")), "template": "T1"})
	var e := String(re.get("entry", ""))
	for x in [[0, "fuente_a", "redh"], [0, "dice_a", "abril_27_1890"], [1, "fuente_b", "redh"], [1, "dice_b", "octubre_9_1890"]]:
		sim.apply({"t": "entry_set", "entry": e, "line": int(x[0]), "field": String(x[1]), "value": String(x[2])})
	sim.apply({"t": "entry_support_add", "entry": e, "line": 0, "item": ca})
	sim.apply({"t": "entry_support_add", "entry": e, "line": 1, "item": co})
	ok(sim.apply({"t": "practice", "entry": e}).ok, label + ": práctica")
	eq(String(sim.q_tutorial().get("step", {}).get("id", "")), "ad", label + ": paso ad")
	var opts: Array = ComposersR.options(sim.st, rp, "testigo", "suceso")
	ok(not opts.is_empty(), label + ": la forma «testigo» tiene opciones sin recortar la línea de Harris")
	if opts.is_empty():
		return
	var ad: Dictionary = sim.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": String(opts[0].id)}})
	ok(ad.get("ok", false), label + ": aviso " + str(ad))
	var sl: Dictionary = sim.apply({"t": "sleep"})
	ok(sl.get("ok", false), label + ": dormir " + str(sl))

func test_w4_prologue_never_blocks_real_data():
	var rp = repo()
	var probe = GameSimR.new(rp, 7)
	var v: Dictionary = probe.q_view("D23@L1")
	var redh: Dictionary = probe.q_view("D01.REDH@tomo")
	var tramos: Array = []
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				tramos.append({"id": String(tr.id), "part": pi, "block": bi, "from": int(tr.from), "to": int(tr.to)})
	ok(tramos.size() > 0, "D23@L1 tiene tramos")
	for t in tramos:
		var sim = GameSimR.new(rp, 7)
		if _w4_clip(sim, "D23@L1", t) == "":
			continue   # un tramo que no es recortable solo (no es un recorte que el novato pueda hacer)
		_w4_rest_and_finish(sim, rp, redh, "D23#" + String(t.id))
	# sólo la línea del instructor (Pell, t_clip; se dice al abrir el encargo) como primer recorte
	var s2 = GameSimR.new(rp, 7)
	ok(s2.apply({"t": "read", "view": "D23@L1", "part": 0}).ok, "abrir el encargo")
	ok(_w4_clip_line(s2, "t_clip", "suceso_reichenbach") != "", "la línea t_clip de Pell se recorta")
	_w4_rest_and_finish(s2, rp, redh, "t_clip")
