# Utilidades de tests de W2-SIM: repo de fixtures, sim con dobles, guiones JSONL y avance del calendario por acciones.
extends RefCounted

const GameSim = preload("res://core/sim/game_sim.gd")
const Fakes = preload("res://tests/fixtures/sim/fakes.gd")
const J = preload("res://core/util/j.gd")

const ROOT := "res://tests/fixtures/sim"
const WALK := "res://tests/fixtures/sim/walk_p_d3.jsonl"

static func repo():
	return load("res://core/data/data_repo.gd").load_dir(ROOT)

static func new_sim(p_seed := 7, f = null):
	if f == null:
		f = Fakes.new()
	return GameSim.new(repo(), p_seed, f.handlers())

static func load_jsonl(path: String) -> Array:
	var out: Array = []
	var txt := FileAccess.get_file_as_string(path)
	for ln in txt.split("\n"):
		var s := ln.strip_edges()
		if s == "" or s.begins_with("#"):
			continue
		var v = J.parse_str(s)
		if typeof(v) == TYPE_DICTIONARY:
			out.append(v)
	return out

# Aplica en orden; devuelve [{a, r}] y corta en el primer ok:false si stop.
static func run(sim, actions: Array, stop := true) -> Array:
	var out: Array = []
	for a in actions:
		var r: Dictionary = sim.apply(a)
		out.append({"a": a, "r": r})
		if stop and not r.get("ok", false):
			break
	return out

static func first_fail(results: Array) -> String:
	for x in results:
		if not x.r.get("ok", false):
			return "%s -> %s" % [J.stringify_canon(x.a), J.stringify_canon(x.r)]
	return ""

# Guion del prólogo (tutorial completo con los dobles).
static func prologue() -> Array:
	return [
		{"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": 0, "block": 0}, "from": 0, "len": 41},
		{"t": "clip_text", "src": {"kind": "doc", "ref": "D03@tomo", "part": 0, "block": 0}, "from": 0, "len": 42},
		{"t": "link", "a": "RC0001", "b": "RC0002", "note": "contradice"},
		{"t": "folio_open", "clip": "RC0002"},
		{"t": "entry_new", "folio": "FO001", "template": "T1"},
		{"t": "entry_set", "entry": "AS001", "line": 0, "field": "fuente_a", "value": "fina"},
		{"t": "entry_support_add", "entry": "AS001", "line": 0, "item": "RC0001"},
		{"t": "entry_support_add", "entry": "AS001", "line": 0, "item": "RC0002"},
		{"t": "practice", "entry": "AS001"},
		{"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}},
		{"t": "sleep"},
	]

# Avanza sólo con acciones de reloj (quedarse en casa, informes «sin novedad», dormir, salir de escenas) hasta
# (day, slot) en fase desk. Devuelve "" o el error.
static func advance_to(sim, day: int, slot: String, max_steps := 200) -> String:
	for _i in max_steps:
		var c: Dictionary = sim.q_clock()
		if int(c.day) == day and String(c.slot) == slot and String(c.phase) == "desk":
			return ""
		if int(c.day) > day:
			return "se pasó: %s" % str(c)
		var a := {}
		match String(c.phase):
			"prologue":
				for x in prologue():
					var r0: Dictionary = sim.apply(x)
					if not r0.get("ok", false):
						return "prólogo: %s -> %s" % [str(x), str(r0)]
				continue
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene":
				a = {"t": "leave"}
			"night":
				if sim.q_report_status().due:
					a = {"t": "report_submit", "mode": "nada", "items": []}
				else:
					a = {"t": "sleep"}
			_:
				return "fase inesperada " + String(c.phase)
		var r: Dictionary = sim.apply(a)
		if not r.get("ok", false):
			return "%s -> %s (%s)" % [str(a), str(r), str(c)]
	return "demasiados pasos"
