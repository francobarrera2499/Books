# tests/fixtures/w3sceneui/world.gd — mundo de prueba de W3-SCENEUI: una GameSim REAL (sin dobles) sobre los datos
# estructurales de data/ + el contenido mínimo de tests/fixtures/integ (integrador) + tests/fixtures/w3sceneui/data
# (D08, crane, wiggins, M7). Lo usan tests/test_u_scene_panel.gd, test_u_confrontation_view.gd, test_u_*_composer.gd y
# devtools/drivers/w3sceneui_*.gd para llevar la partida a cada estado de la UI con acciones de §3.5.
# Uso: var W = load("res://tests/fixtures/w3sceneui/world.gd"); var w = W.new(); var sim = w.sim_at("day1_watson")
#   estados: prologue_ad · day1_watson · day1_crane · day1_desk_T · day2_report · day3_wiggins · day7_m7 ·
#            day10_confront · day10_final
#   w.clips {nombre: id} (recortes hechos en el camino) · w.errs (acciones rechazadas) · w.repo
extends RefCounted

const DataRepo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")

const INTEG := "res://tests/fixtures/integ"
const OWN := "res://tests/fixtures/w3sceneui/data"
const CONTENT_DIRS := ["docs/", "dialogue/", "scenes/", "catalog/"]
const STRUCT_ENTITIES := ["entities/core.json", "entities/struct.json", "entities/places_a.json", "entities/places_b.json", "entities/places_c.json", "entities/v2_fisica.json",
	"entities/v3_core.json", "entities/v3_reacciones.json", "entities/v3_contenido.json"]
const SEED := 1894

var repo = null
var errs: Array = []
var clips := {}
var root := ""

func _init(dst := "") -> void:
	root = dst if dst != "" else ProjectSettings.globalize_path("res://").path_join("../.work/tests/w3sceneui_data").simplify_path()
	repo = _build_repo()

static func _rel_files(base: String, rel := "") -> Array:
	var out: Array = []
	var dir := base.path_join(rel) if rel != "" else base
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d.begins_with("_"):
			continue
		out.append_array(_rel_files(base, rel.path_join(d) if rel != "" else d))
	return out

static func _structural(rel: String) -> bool:
	for d in CONTENT_DIRS:
		if rel.begins_with(d):
			return false
	if rel.begins_with("entities/"):
		return STRUCT_ENTITIES.has(rel)
	return true

static func _clear(p: String) -> void:
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_clear(p.path_join(d))
		DirAccess.remove_absolute(p.path_join(d))

func _build_repo():
	if not root.replace("\\", "/").contains("/.work/"):
		errs.append("destino fuera de .work: " + root)
		return null
	DirAccess.make_dir_recursive_absolute(root)
	_clear(root)
	var real := ProjectSettings.globalize_path("res://data")
	for rel in _rel_files(real):
		if _structural(rel):
			_copy(real.path_join(rel), root.path_join(rel))
	for src in [INTEG, OWN]:
		var base := ProjectSettings.globalize_path(src)
		for rel in _rel_files(base):
			_copy(base.path_join(rel), root.path_join(rel))
	DataRepo.clear_cache(root)
	return DataRepo.fresh(root)

static func _copy(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	DirAccess.copy_absolute(from, to)

# ---------------- acciones ----------------
func act(sim, a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if not r.get("ok", false):
		errs.append("%s -> %s" % [J.stringify_canon(a), J.stringify_canon(r)])
	return r

# v3 (GDD_v3 §6.2): un recorte mide ≤15 palabras; el tramo entero si cabe, si no la ventana legal que más lo cubre.
func clip_tramo(sim, view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			var p: Dictionary = v.pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				if String(t.id) == tid:
					var span := best_window(p, int(t.from), int(t.to))
					return String(act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(span[0]), "len": int(span[1]) - int(span[0])}).get("clip", ""))
	errs.append("sin tramo %s#%s" % [view, tid])
	return ""

static func best_window(p: Dictionary, a: int, b: int) -> Array:
	var words: Array = p.get("words", [])
	var idx: Array = []
	for k in words.size():
		if int(words[k][0]) >= a and int(words[k][1]) <= b:
			idx.append(k)
	if idx.size() <= ClipRules.MAX_WORDS:
		return [a, b]
	var best := [int(words[idx[0]][0]), int(words[idx[ClipRules.MAX_WORDS - 1]][1])]
	var bcov := -1
	for st in range(0, idx.size() - ClipRules.MAX_WORDS + 1):
		var f := int(words[idx[st]][0])
		var e := int(words[idx[st + ClipRules.MAX_WORDS - 1]][1])
		var sn: Dictionary = ClipRules.snap(p, f, e - f)
		if not bool(sn.get("ok", false)):
			continue
		var cov := mini(int(sn.to), b) - maxi(int(sn.from), a)
		if cov > bcov:
			bcov = cov
			best = [int(sn.from), int(sn.to)]
	return best

func clip_tagged(sim, view: String, tag: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var k := tag.get_slice(":", 0)
	var val := tag.get_slice(":", 1)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			var p: Dictionary = v.pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				var tv = t.tags.get(k, [])
				if (tv is Array and tv.has(val)) or (not (tv is Array) and String(tv) == val):
					var span := best_window(p, int(t.from), int(t.to))
					return String(act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(span[0]), "len": int(span[1]) - int(span[0])}).get("clip", ""))
	errs.append("sin tramo con %s en %s" % [tag, view])
	return ""

# Prólogo hasta el paso del aviso (Harris lo dicta), v3 (GDD_v3 §6.9): leer y recortar el encargo; un recorte de la
# crónica del cliente. Sin libro de conclusiones: la pregunta Q1 queda en el expediente (clips["q1"] = "Q1").
func prologue_to_ad(sim) -> void:
	act(sim, {"t": "read", "view": "D23@L1", "part": 0})
	clips["aviso"] = clip_tramo(sim, "D23@L1", "aviso")
	clips["sheer_tomo"] = clip_tramo(sim, "D03@tomo", "sheer")
	clips["q1"] = "Q1"

func prologue_done(sim) -> void:
	prologue_to_ad(sim)
	act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	act(sim, {"t": "sleep"})

# Día 1: M en la consulta de Watson (no se sale), o completo: M Watson (cebo), T Sala de Lectura (D05, D08) y tienda.
func day1(sim, stop := "") -> void:
	act(sim, {"t": "go", "place": "L4", "area": "consulta"})
	if stop == "watson":
		return
	act(sim, {"t": "assert", "char": "watson", "assertion": "as.pared"})
	act(sim, {"t": "leave"})
	act(sim, {"t": "end_slot"})
	act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	act(sim, {"t": "slip", "doc": "D05"})
	act(sim, {"t": "slip", "doc": "D08"})
	clips["marque"] = clip_tramo(sim, "D05@BM", "marque")
	clips["corniche"] = clip_tramo(sim, "D05@BM", "corniche")
	clips["kanzel"] = clip_tramo(sim, "D08@BM", "kanzel")
	clips["meiringen"] = clip_tramo(sim, "D08@BM", "meiringen")
	act(sim, {"t": "leave"})
	act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	if stop == "crane":
		return
	clips["sheer"] = clip_tramo(sim, "D03@Crane", "sheer")
	act(sim, {"t": "leave"})
	if stop == "desk_T":
		return
	act(sim, {"t": "end_slot"})
	act(sim, {"t": "end_slot"})
	act(sim, {"t": "sleep"})

func passive_until(sim, pred: Callable, max_steps := 300) -> void:
	for _i in max_steps:
		if pred.call(sim):
			return
		var c: Dictionary = sim.q_clock()
		var a := {}
		match String(c.phase):
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if sim.q_report_status().due else {"t": "sleep"}
			"confront":
				a = {"t": "confront", "step": int(sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			_:
				return
		if not act(sim, a).get("ok", false):
			return

func sim_at(state: String):
	errs = []
	clips = {}
	var sim = GameSim.new(repo, SEED)
	match state:
		"prologue_ad":
			prologue_to_ad(sim)
		"day1_watson":
			prologue_done(sim)
			day1(sim, "watson")
		"day1_crane":
			prologue_done(sim)
			day1(sim, "crane")
		"day1_desk_T":
			prologue_done(sim)
			day1(sim, "desk_T")
		"day2_report":
			prologue_done(sim)
			day1(sim)
			# día 2: la carta de HA1 llega; se recorta su ancla (acto propio citado)
			for inst in sim.st.react.delivered:
				if String(inst.rid) == "HA1":
					clips["ancla"] = clip_tagged(sim, String(inst.view), "a:ancla_kbm")
			passive_until(sim, func(s): return String(s.q_clock().phase) == "night" and s.q_report_status().due)
		"day3_wiggins":
			prologue_done(sim)
			day1(sim)
			passive_until(sim, func(s): return int(s.q_clock().day) == 3 and String(s.q_clock().phase) == "desk")
			act(sim, {"t": "go", "place": "L3", "area": "calle"})
		"day7_m7":
			prologue_done(sim)
			day1(sim)
			passive_until(sim, func(s): return String(s.q_clock().phase) == "scene" and int(s.q_clock().day) == 7)
		"day10_confront", "day10_final":
			prologue_done(sim)
			day1(sim)
			for inst in sim.st.react.delivered:
				if String(inst.rid) == "HA1":
					clips["ancla"] = clip_tagged(sim, String(inst.view), "a:ancla_kbm")
			passive_until(sim, func(s): return String(s.q_clock().phase) == "confront")
			if state == "day10_final":
				passive_until(sim, func(s): return String(s.q_clock().phase) == "final_report")
	return sim
