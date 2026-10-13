# Driver del guardián de contenido: «qué pasa si» los diffs propuestos a dueños ajenos se aplican. Headless. Desde la raíz:
#   ./godot.sh --headless -s devtools/drivers/w3guard_whatif.gd
# Copia data/ a .work/guard/ds y aplica SÓLO en la copia: (a) Wiggins como fuente de líneas en los lugares donde tiene
# silueta (emula el arreglo propuesto en availability.char_srcs: silueta con diálogo = personaje desde el día de su
# silueta); (b) conclusions C7.R1: M:D25 -> M:HA1.carta (la medida vive en el doc de la reacción); (c) scenes/HC06:
# measure/paper_mm al nivel de la escena (hoy en _measure_pendiente porque Schema._scene no los admite);
# (d) plates/RB: a:refuta_reuter en el nodo foto/linea. Luego RouteDB.lint en todas las conclusiones.
extends SceneTree

const DataRepo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

func _init() -> void:
	_run.call_deferred()

static func _copy_dir(a: String, b: String) -> void:
	DirAccess.make_dir_recursive_absolute(b)
	for f in DirAccess.get_files_at(a):
		DirAccess.copy_absolute(a.path_join(f), b.path_join(f))
	for d in DirAccess.get_directories_at(a):
		_copy_dir(a.path_join(d), b.path_join(d))

static func _rm(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_rm(p.path_join(d))
	DirAccess.remove_absolute(p)

static func _rd(p: String):
	return JSON.parse_string(FileAccess.get_file_as_string(p))

static func _wr(p: String, v) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(JSON.stringify(v, "  ", false))
	f.close()

func _run() -> void:
	var ds := ProjectSettings.globalize_path("res://").path_join("../.work/guard/ds").simplify_path()
	if not ds.replace("\\", "/").contains("/.work/guard/"):
		quit(1)
		return
	_rm(ds)
	_copy_dir(ProjectSettings.globalize_path("res://data"), ds)
	var only := OS.get_cmdline_user_args()
	var fixes: Array = ["wiggins", "d25", "hc06", "rb"] if only.is_empty() else only
	if fixes.has("wiggins"):
		for f in DirAccess.get_files_at(ds.path_join("places")):
			var p: String = ds.path_join("places").path_join(f)
			var pl = _rd(p)
			if typeof(pl) != TYPE_DICTIONARY or not pl.get("silhouettes", {}).has("wiggins"):
				continue
			var fr := String(pl.silhouettes.wiggins.get("frame", ""))
			var area := "*"
			for x in pl.get("frames", []):
				if String(x.get("id", "")) == fr:
					area = String(x.get("area", "*"))
			pl["characters"] = pl.get("characters", []) + [{"id": "wiggins", "area": area, "pos": [0, 0, 0], "when": {"day": {"gte": 3}}}]
			_wr(p, pl)
	if fixes.has("d25"):
		var cp := ds.path_join("conclusions.json")
		_wr(cp, JSON.parse_string(FileAccess.get_file_as_string(cp).replace("\"M:D25\"", "\"M:HA1.carta\"")))
	if fixes.has("hc06"):
		var hp := ds.path_join("scenes/HC06.json")
		var h = _rd(hp)
		if h.has("_measure_pendiente"):
			h["measure"] = h._measure_pendiente.measure
			h["paper_mm"] = h._measure_pendiente.paper_mm
			h.erase("_measure_pendiente")
		_wr(hp, h)
	if fixes.has("rb"):
		for f in DirAccess.get_files_at(ds.path_join("plates")):
			var pp: String = ds.path_join("plates").path_join(f)
			var s := FileAccess.get_file_as_string(pp)
			if s.contains("\"a:cornisa_existe\", \"e:fotografia_reichenbach\""):
				var fo := FileAccess.open(pp, FileAccess.WRITE)
				fo.store_string(s.replace("\"a:cornisa_existe\", \"e:fotografia_reichenbach\"", "\"a:cornisa_existe\", \"a:refuta_reuter\", \"e:fotografia_reichenbach\""))
				fo.close()
	var rp = DataRepo.fresh(ds)
	print("== errores de DataRepo en la copia: %d" % rp.errors().size())
	for e in rp.errors():
		print("  " + String(e))
	print("== RouteDB.lint (fixes: %s)" % str(fixes))
	for c in rp.conclusions():
		var res: Dictionary = RouteDB.lint(rp, String(c.id))
		if String(c.id).begins_with("C1."):
			continue
		for e in res.errors:
			print("  ERR " + String(e))
		for e in res.pending:
			print("  PEN " + String(e))
		for n in res.notes:
			if String(n).contains("C7.R7") or String(n).contains("C10.R4") or String(n).contains("C7.R1 "):
				print("  NOTE " + String(n))
	var t2: Dictionary = load("res://core/graph/cut_model.gd").static_check(rp)
	print("== T2 (CutModel.static_check): errors=%s pending=%s" % [str(t2.errors), str(t2.pending)])
	var t3: Dictionary = load("res://core/graph/invariant.gd").t3(rp, {"clock": Time.get_ticks_msec, "fuzz": 300})
	print("== T3 (Invariant.t3): %d estados, %d ms, failures=%s pending=%s" % [t3.states, t3.ms, str(t3.failures), str(t3.pending)])
	var fl: Dictionary = RouteDB.false_leads(rp)
	print("== RouteDB.false_leads (T17): errors=%s pending=%s leads=%d" % [str(fl.errors), str(fl.pending), fl.leads.size()])
	# rutas que los arreglos destraban: detalle
	for pair in [["C7", "C7.R7"], ["C7", "C7.R1"], ["C10", "C10.R4"], ["C10a", "C10a.R4"]]:
		for r in RouteDB.routes(rp, pair[0]):
			if String(r.id) == pair[1]:
				print("  %s: missing=%s frags=%s" % [r.id, str(r.missing), str(r.get("frags", []).map(func(x): return [x.get("ref", ""), x.get("tags", []), x.get("origin", "")]))])
	quit(0)
