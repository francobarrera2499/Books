# Driver de verificación W3-CT-REICH (sin capturas; corre también --headless).
# Recorre el prólogo → amanecer del día 4 de tests/test_i_integration.gd con MIS documentos (D03, D05 y el resto de
# D02–D08, D29a–c) sobre un dataset aislado: data/ estructural + data/docs de W3-CT-REICH + tests/fixtures/integ para lo
# demás que el recorrido necesita (D23, D01.REDH, D15.0327–0330, watson, PRO). Así el contenido a medio hacer de otros
# WPs no tapa los problemas propios. El driver arma el dataset en .work/reich/iso/data (lo borra y lo rehace en cada
# corrida): data/ sin docs/dialogue/scenes/catalog ni entidades de otros WPs de contenido, + tests/fixtures/integ, + mis docs.
# ./godot.sh --headless -s devtools/shot.gd -- res://devtools/blank.tscn w3ctreich res://devtools/drivers/w3ctreich_walk.gd
extends RefCounted

const Integ = preload("res://tests/test_i_integration.gd")
const DataRepo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

func drive(_tool, _scene) -> void:
	var root := _build_iso()
	DataRepo.clear_cache(root)
	var repo = DataRepo.fresh(root)
	print("ERRORES DE CARGA: ", repo.errors())
	for variant in ["nada", "m1"]:
		var t = Integ.new()
		t._cur = "w3ctreich_walk.gd::" + variant
		var sim = t._walk(repo, variant)
		print("RECORRIDO ", variant, ": ", "OK" if sim != null and t._errs.is_empty() else "PROBLEMAS")
		for e in t._errs:
			print("  ERR ", e)
		for f in t._frags:
			var cl: Dictionary = Clipper.get_clip(sim.st, String(f.clip)) if sim != null else {}
			var model: Dictionary = RouteDB.resolve(repo, String(f.ref), String(f.copy))
			var mt: Array = RouteDB.flat_tags(model.get("tags", [])) if not model.is_empty() else []
			print("  FRAG %s (%s) clip=%s tags=%s ents=%s modelo=%s" % [f.ref, f.copy, f.clip, str(cl.get("tags", [])), str(cl.get("ents", [])), str(mt)])
	# rutas de las conclusiones que usan mis documentos (T1 por conclusión): errores propios y pendientes ajenos
	for cid in ["C2", "C3", "C4", "C11"]:
		var l: Dictionary = RouteDB.lint(repo, cid)
		print("RUTAS %s errores=%s" % [cid, str(l.errors)])
		print("      %s pendientes=%s" % [cid, str(l.pending)])
	var fl: Dictionary = RouteDB.false_leads(repo)
	print("PISTAS FALSAS errores=%s" % str(fl.errors))
	for k in fl.leads:
		print("  LEAD %s ok=%s orígenes=%s" % [k, str(fl.leads[k].get("ok", false)), str(fl.leads[k].get("origins", []))])
	print("PENDIENTES T17=%s" % str(fl.get("pending", [])))
	# campos que el validador exige y que sólo este contenido puede indexar
	print("SIN ÍNDICE (C2,C3,C4,C11): %s" % str(Integ.unreachable_answers(repo, ["C2", "C3", "C4", "C11"])))

const MINE := ["D02", "D03", "D04", "D05", "D06", "D07", "D08", "D29a", "D29b", "D29c"]
const KEEP_ENT := ["core.json", "struct.json", "places_a.json", "places_b.json", "places_c.json", "ct_reich.json", "v2_fisica.json"]
const SKIP_DIRS := ["docs", "dialogue", "scenes", "catalog"]

func _build_iso() -> String:
	var base := ProjectSettings.globalize_path("res://").simplify_path()
	var dst := base.path_join("../.work/reich/iso/data").simplify_path()
	_rm_tree(dst)
	_copy_tree(base.path_join("data"), dst, "")
	_copy_tree(base.path_join("tests/fixtures/integ"), dst, "*")
	for d in MINE:
		DirAccess.copy_absolute(base.path_join("data/docs/%s.json" % d), dst.path_join("docs/%s.json" % d))
	return dst

# top == "" filtra (raíz de data/): sin SKIP_DIRS y en entities/ sólo KEEP_ENT; top == "*" copia todo.
func _copy_tree(src: String, dst: String, top: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	var da := DirAccess.open(src)
	if da == null:
		return
	for f in da.get_files():
		if top == "entities" and not KEEP_ENT.has(f):
			continue
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
