# tests/fixtures/w3shell/walk.gd — ayudas de W3-SHELL para tests y drivers (dueño: W3-SHELL).
# Dataset «fixture» (data/ estructural + tests/fixtures/integ, como test_i_integration) armado una vez por proceso en
# .work/tests/_w3shell_data (o la ruta que se pida), tutorial del prólogo por acciones de §3.5 y avance del calendario.
# act: Callable(Dictionary) -> Dictionary (Game.act o sim.apply). Todo devuelve errores legibles, sin push_error.
extends RefCounted

const Fallback = preload("res://ui/desk/fallback.gd")

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

# Recorta el tramo #tid de una vista accesible. "" si no se pudo (errs lo dice).
static func clip(sim, act: Callable, view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					var r: Dictionary = act.call({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
					if not bool(r.get("ok", false)):
						errs.append("clip %s#%s: %s" % [view, tid, str(r.get("err", ""))])
					return String(r.get("clip", ""))
	errs.append("sin tramo %s#%s" % [view, tid])
	return ""

# Tutorial del prólogo completo (GDD§3.2): recortar, juntar, folio, asiento, práctica C1.10, aviso de testigos.
# Devuelve {aviso, abril, octubre, pair, folio, entry}.
static func tutorial(sim, act: Callable) -> Dictionary:
	var out := {}
	out.aviso = clip(sim, act, "D23@L1", "aviso")
	out.abril = clip(sim, act, "D01.REDH@tomo", "abril")
	out.octubre = clip(sim, act, "D01.REDH@tomo", "octubre")
	out.pair = String(_ok(act, {"t": "link", "a": out.abril, "b": out.octubre, "note": ""}).get("pair", ""))
	out.folio = String(_ok(act, {"t": "folio_open", "clip": out.abril}).get("folio", ""))
	out.entry = String(_ok(act, {"t": "entry_new", "folio": out.folio, "template": "T1"}).get("entry", ""))
	for x in [[0, "fuente_a", "redh"], [0, "dice_a", "abril_27_1890"], [1, "fuente_b", "redh"], [1, "dice_b", "octubre_9_1890"]]:
		_ok(act, {"t": "entry_set", "entry": out.entry, "line": x[0], "field": x[1], "value": x[2]})
	_ok(act, {"t": "entry_support_add", "entry": out.entry, "line": 0, "item": out.abril})
	_ok(act, {"t": "entry_support_add", "entry": out.entry, "line": 1, "item": out.octubre})
	_ok(act, {"t": "practice", "entry": out.entry})
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
