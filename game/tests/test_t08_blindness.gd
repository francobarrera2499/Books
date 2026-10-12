# T08 (W2-REACT): ceguera de Holmes y Moran (GDD§9.1, §15.5; ARCHITECTURE §3.1, §5.3).
# Mismo registro de actos públicos + distinto cuaderno → mismas entregas. react/ nunca lee st.ded (salvo report_cats:
# lo que Moran lee de los elementos del propio informe). Las condiciones de reacciones no miran lo sellado.
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const Director = preload("res://core/react/director.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const J = preload("res://core/util/j.gd")

const NOTEBOOKS := [
	{},
	{"clips": {"RC0001": {"id": "RC0001", "tags": ["a:cornisa_existe", "c:holmes_vive"], "ents": ["cornisa"], "cls": "I"},
		"RC0002": {"id": "RC0002", "tags": ["a:harris_es_moran", "f:secreto_camden"], "ents": ["camden_house"], "cls": "C"}},
	 "pairs": {"PR001": {"a": "RC0001", "b": "RC0002"}}, "folios": {"FO001": {"head_clip": "RC0001"}},
	 "entries": {"AS001": {"template": "T7", "lines": [{"fields": {"persona": "holmes"}}, {"fields": {"estado": "vivo"}}], "ink": "tinta"}},
	 "sealed": {"C2": "AS001", "C6": "AS002", "C10": "AS003"}, "passes": [{"tk": 12, "ok": false}], "practice": [1, 2, 3]},
	{"clips": {}, "entries": {"AS009": {"template": "T8", "lines": [{"fields": {"lugar": "montpellier"}}]}}, "sealed": {"C13": "AS009"}},
]

func after_each() -> void:
	H.cleanup()

func _scripts() -> Array:
	return [[], H.load_jsonl("res://tests/fixtures/react/t11_activo.jsonl")]

func _run(r, script: Array, notebook: Dictionary) -> String:
	var h = H.new(r, 5)
	h.st.ded = notebook.duplicate(true)
	h.play(script)
	return h.signature()

func test_same_public_acts_same_deliveries():
	var r = fixture_repo("react/data")
	for script in _scripts():
		var base := _run(r, script, NOTEBOOKS[0])
		for i in range(1, NOTEBOOKS.size()):
			eq(_run(r, script, NOTEBOOKS[i]), base, "cuaderno %d (guion de %d actos)" % [i, script.size()])

func test_different_public_acts_differ():
	var r = fixture_repo("react/data")
	var s := _scripts()
	ne(_run(r, s[0], {}), _run(r, s[1], {}), "control: los actos públicos sí cambian las entregas")

func test_private_event_types_are_ignored():
	var r = fixture_repo("react/data")
	var h = H.new(r)
	h.advance_to("3.M")
	var before := h.signature()
	for t in ["clip", "pair", "folio", "entry", "pass", "practice", "confront", "night_choice", "clip_text", "pass_clean"]:
		Director.on_public_event(h.st, r, {"seq": 99, "tk": 31, "day": 3, "slot": "M", "type": t, "act": "act.99", "item": {"tags": ["a:x"]}})
	eq(h.signature(), before, "D6: nada reacciona a fracasos ni actos privados")

func test_real_data_blind():
	var r = repo()
	if r.reactions().is_empty() or r.schedule().is_empty():
		pending_content("data/reactions y data/schedule.json (W2-STRUCT)")
		return
	for script in _scripts():
		eq(_run(r, script, NOTEBOOKS[1]), _run(r, script, NOTEBOOKS[0]), "datos reales")

# ---------------- estático ----------------
func test_react_never_reads_notebook():
	var dir := "res://core/react/"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(dir + f)
		var fn := ""
		var n := 0
		for line in src.split("\n"):
			n += 1
			var l := String(line)
			if l.begins_with("static func ") or l.begins_with("func "):
				fn = l.get_slice("(", 0).get_slice(" ", l.get_slice("(", 0).get_slice_count(" ") - 1)
			var code := l.get_slice("#", 0)
			if not code.contains(".ded"):
				continue
			if f == "moran_agent.gd" and ["_clip", "_entry", "_sealed"].has(fn):
				continue
			fail("%s:%d (%s) lee st.ded: %s" % [f, n, fn, l.strip_edges()])

const SEALED_ATOMS := ["sealed", "sealed_all", "sealed_count"]

func _cond_atoms(c, out: Array) -> void:
	if typeof(c) == TYPE_DICTIONARY:
		for k in c:
			out.append(String(k))
			_cond_atoms(c[k], out)
	elif typeof(c) == TYPE_ARRAY:
		for x in c:
			_cond_atoms(x, out)

func _check_conditions(r, label: String) -> void:
	for rule in r.reactions():
		var atoms: Array = []
		_cond_atoms(rule.get("condiciones", {}), atoms)
		for rs in RDB._as_arr(rule.get("rastro", [])):
			if typeof(rs) == TYPE_DICTIONARY:
				_cond_atoms(rs.get("when", {}), atoms)
		for e in RDB.effects_of(rule, false) + RDB.effects_of(rule, true):
			if typeof(e) == TYPE_DICTIONARY:
				_cond_atoms(e.get("si_cond", {}), atoms)
		for a in SEALED_ATOMS:
			if atoms.has(a):
				fail("%s %s: condición «%s» mira el libro mayor" % [label, rule.id, a])

func test_reaction_conditions_never_look_at_ledger():
	_check_conditions(fixture_repo("react/data"), "fixture")
	var r = repo()
	if r.reactions().is_empty():
		pending_content("data/reactions (W2-STRUCT)")
		return
	_check_conditions(r, "data")
