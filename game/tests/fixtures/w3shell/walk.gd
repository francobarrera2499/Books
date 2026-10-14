# tests/fixtures/w3shell/walk.gd — ayudas de W3-SHELL para tests y drivers (dueño: W3-SHELL).
# Dataset «fixture» (data/ estructural + tests/fixtures/integ, como test_i_integration) armado una vez por proceso en
# .work/tests/_w3shell_data (o la ruta que se pida), tutorial del prólogo por acciones de §3.5 y avance del calendario.
# act: Callable(Dictionary) -> Dictionary (Game.act o sim.apply). Todo devuelve errores legibles, sin push_error.
extends RefCounted

const Fallback = preload("res://ui/desk/fallback.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")

static var _dir := ""
static var errs: Array = []

static func data_dir() -> String:
	if _dir != "" and DirAccess.dir_exists_absolute(_dir):
		return _dir
	var dst := ProjectSettings.globalize_path("res://").path_join("../.work/tests/_w3shell_data").simplify_path()
	_dir = Fallback.build_fixture_dir(dst)
	return _dir

static func repo():
	var DR = load("res://core/data/data_repo.gd")
	var d := data_dir()
	if d == "":
		return null
	return DR.load_dir(d)

# Recorta el tramo #tid de una vista accesible (v3, GDD_v3 §6.2: ≤15 palabras; el tramo entero si cabe, si no la ventana
# legal que más lo cubre). "" si no se pudo (errs lo dice).
static func clip(sim, act: Callable, view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var parsed: Dictionary = pages[pi][bi].get("parsed", {})
			for tr in parsed.get("tramos", []):
				if String(tr.id) == tid:
					var span := best_window(parsed, int(tr.from), int(tr.to))
					var r: Dictionary = act.call({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(span[0]), "len": int(span[1]) - int(span[0])})
					if not bool(r.get("ok", false)):
						errs.append("clip %s#%s: %s" % [view, tid, str(r.get("err", ""))])
					return String(r.get("clip", ""))
	errs.append("sin tramo %s#%s" % [view, tid])
	return ""

# [from, to) del recorte legal (≤15 palabras, una oración) que más cubre [a, b).
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

# Tutorial del prólogo completo, v3 (GDD_v3 §6.9): leer el encargo, recortar el aviso del pie, aviso de testigos con el
# tintero. Devuelve {aviso} (sin pares, folios ni asientos: ya no existen).
static func tutorial(sim, act: Callable) -> Dictionary:
	var out := {}
	_ok(act, {"t": "read", "view": "D23@L1", "part": 0})
	out.aviso = clip(sim, act, "D23@L1", "aviso")
	_ok(act, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	if not bool(sim.q_tutorial().get("complete", false)):
		errs.append("tutorial incompleto: %s" % str(sim.q_tutorial()))
	return out

static func _ok(act: Callable, a: Dictionary) -> Dictionary:
	var r: Dictionary = act.call(a)
	if not bool(r.get("ok", false)):
		errs.append("%s -> %s" % [str(a), str(r.get("err", ""))])
	return r

# Un paso del calendario sin salir: escena fija -> leave; escritorio -> end_slot; noche -> informe (si toca) y sleep.
# false si no se pudo avanzar.
static func step(sim, act: Callable) -> bool:
	var c: Dictionary = sim.q_clock()
	match String(c.phase):
		"scene", "parklane", "visit":
			return bool(act.call({"t": "leave"}).get("ok", false))
		"desk":
			return bool(act.call({"t": "end_slot"}).get("ok", false))
		"night":
			if bool(sim.q_report_status().get("due", false)):
				if not bool(act.call({"t": "report_submit", "mode": "nada", "items": []}).get("ok", false)):
					return false
			return bool(act.call({"t": "sleep"}).get("ok", false))
	return false

# Avanza hasta (día, franja) en fase desk. true si llegó.
static func advance_to(sim, act: Callable, day: int, slot: String, max_steps := 80) -> bool:
	for i in max_steps:
		var c: Dictionary = sim.q_clock()
		if int(c.day) == day and String(c.slot) == slot and String(c.phase) == "desk":
			return true
		if int(c.day) > day:
			return false
		if not step(sim, act):
			errs.append("no avanza desde %s" % str(c))
			return false
	return false

# Acciones aceptadas como JSONL (para --script).
static func jsonl(actions: Array) -> String:
	var lines: Array = ["# W3-SHELL: acciones de prueba (una por línea)"]
	for a in actions:
		lines.append(JSON.stringify(a))
	return "\n".join(lines) + "\n"
