# Driver de verificación W3-CT-TRACES (sin capturas; headless). Juega con mis documentos sobre un dataset aislado:
# data/ estructural + tests/fixtures/integ (lo que el recorrido de integración necesita) + mis docs y mis entidades
# (y las de los demás WPs: sólo entidades, ningún doc ajeno). Lo arma en .work/traces/iso/data en cada corrida.
#   1. recorrido de integración (prólogo → amanecer del día 4) con mis docs presentes;
#   2. día 4: Sala de Lectura, papeletas D13/D14/D12, recortes y asiento C8 (T7) con D13#muestra97 + D12#n97;
#      portería del Diógenes: D31 muestra las entradas hasta el viernes 30 y no las de abril;
#   3. día 5: papeletas D19/D20/D45; asientos C4 (D03@tomo#a_mycroft + D19#indice) y C14 (D20#subasta + D45#duelo);
#   4. pasivo hasta la tarde del 9: portería, D31 ya trae París (#ruta) y se recorta #telegramas;
#   5. día 10 (confrontación): el libro de ventas de Crane trae la entrada del librero; asiento C12 (D33#direccion +
#      D17#church_street + D12#dedicatoria). Validator.entry_ok sin gastar pasada.
# D17 (W3-CT-MORAN) se copia sólo como pareja de C12.R3. Imprime OK/PROBLEMA por chequeo.
# ./godot.sh --headless -s devtools/drivers/w3cttraces_walk.gd
extends SceneTree

var Integ = null   # load() en tiempo de ejecución: el test usa el autoload Game
const DataRepo = preload("res://core/data/data_repo.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Validator = preload("res://core/deduction/validator.gd")

const MINE := ["D12", "D13", "D14", "D18", "D19", "D20", "D22", "D30", "D31", "D33", "D34", "D35", "D45", "D17"]

var _t = null
var _bad := 0

func _init() -> void:
	_run.call_deferred()

func _ok(c: bool, msg: String) -> void:
	print(("OK       " if c else "PROBLEMA ") + msg)
	if not c:
		_bad += 1

func _plain(sim, view: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var s := ""
	for pg in v.get("pages", []):
		for b in pg:
			s += String(b.get("parsed", {}).get("plain", "")) + "\n"
	return s

func _clip(sim, view: String, tid: String) -> String:
	var cid: String = _t._clip_tramo(sim, view, tid)
	var cl: Dictionary = Clipper.get_clip(sim.st, cid) if cid != "" else {}
	_ok(cid != "", "recorte %s#%s -> %s tags=%s ents=%s" % [view, tid, cid, str(cl.get("tags", [])), str(cl.get("ents", []))])
	return cid

func _act(sim, a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if not r.get("ok", false):
		_ok(false, "acción %s -> %s" % [str(a), str(r)])
	return r

# Avanza en pasivo hasta que pred(sim) sea verdadero (o 400 pasos).
func _until(sim, pred: Callable) -> bool:
	for _i in 400:
		if pred.call(sim):
			return true
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
				return false
		if not _act(sim, a).get("ok", false):
			return false
	return false

func _run() -> void:
	Integ = load("res://tests/test_i_integration.gd")
	var root := _build_iso()
	DataRepo.clear_cache(root)
	var repo = DataRepo.fresh(root)
	_ok(repo.errors().is_empty(), "dataset aislado sin errores %s" % str(repo.errors().slice(0, 5)))
	_t = Integ.new()
	_t._cur = "w3cttraces_walk.gd::walk"
	var sim = _t._walk(repo)
	_ok(sim != null and _t._errs.is_empty(), "recorrido de integración con mis docs presentes %s" % str(_t._errs.slice(0, 5)))
	if sim == null:
		quit(1)
		return
	_t._errs = []
	# --- día 4, mañana: Sala de Lectura; C8.R1 (D13 + D12) ---
	_until(sim, func(s): return String(s.q_clock().phase) == "desk")
	print("reloj: ", sim.q_clock().day, " ", sim.q_clock().slot)
	_act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	for d in ["D13", "D14", "D12"]:
		var r := _act(sim, {"t": "slip", "doc": d})
		_ok(r.get("ok", false), "papeleta %s -> %s" % [d, str(r.get("view", ""))])
	var c97 := _clip(sim, "D13@BM", "muestra97")
	_clip(sim, "D13@BM", "jartum")
	_clip(sim, "D14@BM", "opusculo")
	var c_ama := _clip(sim, "D14@BM", "amarillo")
	var cn97 := _clip(sim, "D12@BM", "n97")
	var c_ded := _clip(sim, "D12@BM", "dedicatoria")
	_act(sim, {"t": "leave"})
	_entry(sim, "C8", "T7", c97, [[0, "persona", "holmes"], [1, "estado", "vivo"]], [[0, cn97], [1, c97]])
	# --- día 4, tarde: portería del Diógenes (D31 hasta el viernes 30) ---
	_until(sim, func(s): return String(s.q_clock().slot) == "T" and String(s.q_clock().phase) == "desk")
	print("reloj: ", sim.q_clock().day, " ", sim.q_clock().slot)
	_act(sim, {"t": "go", "place": "L5", "area": "porteria"})
	var p4 := _plain(sim, "D31@L5")
	_ok(p4.contains("Vie. 30 mar.") and not p4.contains("Sáb. 31") and not p4.contains("abr."), "D31 el día 4 llega hasta el viernes 30")
	_clip(sim, "D31@L5", "para_mholmes")
	_act(sim, {"t": "leave"})
	# --- día 5, mañana: Sala de Lectura; C4.R2 (D03 + D19) y C14.R2 (D20 + D45) ---
	_until(sim, func(s): return int(s.q_clock().day) == 5 and String(s.q_clock().phase) == "desk")
	print("reloj: ", sim.q_clock().day, " ", sim.q_clock().slot)
	_act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	for d in ["D19", "D20", "D45"]:
		var r2 := _act(sim, {"t": "slip", "doc": d})
		_ok(r2.get("ok", false), "papeleta %s -> %s" % [d, str(r2.get("view", ""))])
	var c_ind := _clip(sim, "D19@BM", "indice")
	_clip(sim, "D19@BM", "presume")
	var c_sub := _clip(sim, "D20@BM", "subasta")
	var c_due := _clip(sim, "D45@BM", "duelo")
	_act(sim, {"t": "leave"})
	var c_amy := _clip(sim, "D03@tomo", "a_mycroft")
	_entry(sim, "C4", "T5", c_amy, [[0, "persona", "holmes"], [0, "hizo", "ceder"], [0, "que", "bienes"], [1, "a", "mycroft"], [4, "cuando", "en_vida"]], [[0, c_amy], [1, c_amy], [4, c_ind]])
	_entry(sim, "C14", "T5", c_sub, [[0, "persona", "watson"], [0, "hizo", "vender"], [0, "que", "tomos"], [3, "donde", "subasta_de_paddington"], [4, "cuando", "enero_1894"]], [[0, c_sub], [3, c_sub], [4, c_due]])
	# --- pasivo hasta la tarde del 9: portería ---
	_until(sim, func(s): return int(s.q_clock().day) == 9 and String(s.q_clock().slot) == "T" and String(s.q_clock().phase) == "desk")
	print("reloj: ", sim.q_clock().day, " ", sim.q_clock().slot)
	_act(sim, {"t": "go", "place": "L5", "area": "porteria"})
	var p9 := _plain(sim, "D31@L5")
	_ok(p9.contains("Grenoble") and p9.contains("París"), "D31 el 9 por la tarde trae Grenoble y París")
	_clip(sim, "D31@L5", "telegramas")
	_clip(sim, "D31@L5", "ruta")
	_act(sim, {"t": "leave"})
	# --- día 10: el libro de ventas tras el librero; C12.R3 (D33 + D17 + D12) ---
	_until(sim, func(s): return int(s.q_clock().day) == 10)
	print("reloj: ", sim.q_clock().day, " ", sim.q_clock().slot, " ", sim.q_clock().phase, " delivered.HC07=", sim.st.react.counters.get("delivered.HC07", 0))
	var p10 := _plain(sim, "D33@Crane")
	print("D33 día 10:\n", p10)
	_ok(p10.contains("Church Street") == (int(sim.st.react.counters.get("delivered.HC07", 0)) > 0), "D33: la entrada del jueves aparece sólo tras HC07")
	if p10.contains("Church Street"):
		var c_dir := _clip(sim, "D33@Crane", "direccion")
		var c_chu := _clip(sim, "D17@Crane", "church_street")
		_entry(sim, "C12", "T3", c_dir, [[0, "persona", "librero"], [1, "es", "holmes"]], [[0, c_dir], [0, c_chu], [1, c_ded]])
	for e in _t._errs:
		_ok(false, String(e))
	print("W3-CT-TRACES walk: %d problemas" % _bad)
	quit(0 if _bad == 0 else 1)

# Abre un folio con el primer recorte, arma el asiento y pide al validador la conclusión (sin gastar pasada).
func _entry(sim, cid: String, tpl: String, first: String, sets: Array, sups: Array) -> void:
	if first == "":
		_ok(false, "%s: sin recorte para abrir el folio" % cid)
		return
	var fo := String(_act(sim, {"t": "folio_open", "clip": first}).get("folio", ""))
	var en := String(_act(sim, {"t": "entry_new", "folio": fo, "template": tpl}).get("entry", ""))
	for s in sets:
		_act(sim, {"t": "entry_set", "entry": en, "line": int(s[0]), "field": String(s[1]), "value": String(s[2])})
	for s in sups:
		_act(sim, {"t": "entry_support_add", "entry": en, "line": int(s[0]), "item": String(s[1])})
	var v: Dictionary = Validator.entry_ok(sim.st, sim.repo, en)
	_ok(bool(v.get("ok", false)) and String(v.get("cid", "")) == cid, "asiento %s (%s) valida %s: %s formal=%s" % [en, tpl, cid, str(v), str(sim.q_entry(en).get("formal", []))])
const SKIP_DIRS := ["docs", "dialogue", "scenes", "catalog"]

func _build_iso() -> String:
	var base := ProjectSettings.globalize_path("res://").simplify_path()
	var dst := base.path_join("../.work/traces/iso/data").simplify_path()
	_rm_tree(dst)
	_copy_tree(base.path_join("data"), dst, "")
	_copy_tree(base.path_join("tests/fixtures/integ"), dst, "*")
	for d in MINE:
		DirAccess.copy_absolute(base.path_join("data/docs/%s.json" % d), dst.path_join("docs/%s.json" % d))
	return dst

func _copy_tree(src: String, dst: String, top: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	var da := DirAccess.open(src)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	for sd in da.get_directories():
		if top == "" and SKIP_DIRS.has(sd):
			continue
		_copy_tree(src.path_join(sd), dst.path_join(sd), sd if top == "" else top)

func _rm_tree(p: String) -> void:
	var da := DirAccess.open(p)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(p.path_join(f))
	for sd in da.get_directories():
		_rm_tree(p.path_join(sd))
	DirAccess.remove_absolute(p)
