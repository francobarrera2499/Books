# devtools/bots/bot_data.gd — dataset sobre el que juegan los bots (W3-BOTS; ARCHITECTURE §9.3).
# Modos:
#   "fixture": estructura de res://data (todo salvo docs/, dialogue/, scenes/, catalog/ y las entidades de contenido) +
#              contenido mínimo de res://tests/fixtures/integ (integrador ola 2) + res://tests/fixtures/bots (este WP; pisa
#              a integ si coinciden). Con esto hay ≥1 ruta ★ completa de cada conclusión obligatoria (ver la _nota de cada
#              archivo de tests/fixtures/bots). Se copia a .work/bots/fx_<firma de las fuentes>/ (una vez; seguro entre
#              procesos concurrentes) y se carga con DataRepo.fresh.
#   "real":    res://data tal cual (cuando la ola 3 publique el contenido). content_report() dice qué falta.
#   cualquier otra cosa: ruta de un root de datos (res://… o absoluta).
# No escribe fuera de .work. Sin azar (el reloj sólo decide qué fx_* viejos se borran).
extends RefCounted

const DataRepo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const INTEG := "res://tests/fixtures/integ"
const BOTS := "res://tests/fixtures/bots"
const CONTENT_DIRS := ["docs/", "dialogue/", "scenes/", "catalog/"]

static func work_dir(sub := "") -> String:
	var p := ProjectSettings.globalize_path("res://").path_join("../.work/bots").simplify_path()
	if sub != "":
		p = p.path_join(sub)
	DirAccess.make_dir_recursive_absolute(p)
	return p

static func rel_files(root: String, rel := "") -> Array:
	var out: Array = []
	var dir := root.path_join(rel) if rel != "" else root
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json") and not f.begins_with("_"):
			out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d.begins_with("_"):
			continue
		out.append_array(rel_files(root, rel.path_join(d) if rel != "" else d))
	out.sort()
	return out

# Archivo estructural de data/ (dueños W1/W2): todo lo que no es contenido de la ola 3.
static func structural(rel: String) -> bool:
	for d in CONTENT_DIRS:
		if rel.begins_with(d):
			return false
	if rel.begins_with("entities/"):
		var f := rel.get_file()
		# v2_*: entidades del sistema v2 (papeles de fisica.json); v3_core / v3_reacciones: de los paquetes de estructura v3
		return f == "core.json" or f == "struct.json" or f.begins_with("places_") or f.begins_with("v2_") or f == "v3_core.json" or f == "v3_reacciones.json"
	return true

static func _clear(p: String) -> void:
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_clear(p.path_join(d))
		DirAccess.remove_absolute(p.path_join(d))

static func _copy_tree(src: String, dst: String, filter: Callable) -> void:
	for rel in rel_files(src):
		if filter.is_valid() and not filter.call(rel):
			continue
		var to := dst.path_join(rel)
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		DirAccess.copy_absolute(src.path_join(rel), to)

# Arma el dataset «fixture» en dst (absoluta, bajo .work) y devuelve dst.
static func build_fixture(dst: String) -> String:
	if not dst.replace("\\", "/").contains("/.work/"):
		push_error("bot_data: destino fuera de .work: " + dst)
		return ""
	DirAccess.make_dir_recursive_absolute(dst)
	_clear(dst)
	_copy_tree(ProjectSettings.globalize_path("res://data"), dst, func(rel): return structural(rel))
	_copy_tree(ProjectSettings.globalize_path(INTEG), dst, Callable())
	_copy_tree(ProjectSettings.globalize_path(BOTS), dst, Callable())
	return dst

# Firma de las fuentes del dataset «fixture» (md5 de rutas + contenidos): cambia si cambia cualquier archivo fuente.
static func fixture_sig() -> String:
	var parts: PackedStringArray = []
	var data_root := ProjectSettings.globalize_path("res://data")
	for root in [data_root, ProjectSettings.globalize_path(INTEG), ProjectSettings.globalize_path(BOTS)]:
		for rel in rel_files(root):
			if root == data_root and not structural(rel):
				continue
			parts.append(String(rel) + "=" + FileAccess.get_md5(root.path_join(rel)))
	return "|".join(parts).md5_text().left(12)

# Dataset «fixture» compartido y a prueba de procesos concurrentes: .work/bots/fx_<firma>/ (se arma una vez en un
# directorio propio del proceso y se renombra; si otro proceso ganó, se usa el suyo). Borra los fx_* viejos (>30 min).
static func fixture_dir() -> String:
	var sig := fixture_sig()
	var base := work_dir()
	var final := base.path_join("fx_" + sig)
	if FileAccess.file_exists(final.path_join(".ok")):
		return final
	var tmp := base.path_join("fx_%s_tmp%d" % [sig, OS.get_process_id()])
	build_fixture(tmp)
	var f := FileAccess.open(tmp.path_join(".ok"), FileAccess.WRITE)
	if f != null:
		f.store_string(sig)
		f.close()
	if DirAccess.rename_absolute(tmp, final) != OK or not FileAccess.file_exists(final.path_join(".ok")):
		_clear(tmp)
		DirAccess.remove_absolute(tmp)
		if not FileAccess.file_exists(final.path_join(".ok")):
			return tmp if DirAccess.dir_exists_absolute(tmp) else final
	_gc(base, "fx_" + sig)
	return final

static func _gc(base: String, keep: String) -> void:
	for d in DirAccess.get_directories_at(base):
		if not d.begins_with("fx_") or d == keep or d.begins_with(keep):
			continue
		var p := base.path_join(d)
		var mark := p.path_join(".ok")
		var t := FileAccess.get_modified_time(mark) if FileAccess.file_exists(mark) else 0
		if t > 0 and Time.get_unix_time_from_system() - t < 1800:
			continue
		if t == 0:
			continue
		_clear(p)
		DirAccess.remove_absolute(p)
	# restos del esquema anterior (directorio único, carreras entre procesos)
	var old := base.path_join("data_fixture")
	if DirAccess.dir_exists_absolute(old):
		_clear(old)
		DirAccess.remove_absolute(old)

# DataRepo del modo pedido. dst = directorio de trabajo para "fixture" ("" = .work/bots/fx_<firma>, compartido).
static func repo(mode := "fixture", dst := ""):
	match mode:
		"fixture":
			var d := dst
			if d != "":
				build_fixture(d)
			else:
				d = fixture_dir()
			DataRepo.clear_cache(d)
			return DataRepo.fresh(d)
		"real":
			DataRepo.clear_cache("res://data")
			return DataRepo.fresh("res://data")
	# otra raíz: sólo dentro del proyecto (regla del usuario: nada fuera de C:\Dev\books)
	if not inside_project(mode):
		push_error("bot_data: raíz de datos fuera del proyecto: " + mode)
		return DataRepo.fresh(fixture_dir())
	DataRepo.clear_cache(mode)
	return DataRepo.fresh(mode)

static func inside_project(p: String) -> bool:
	if p.begins_with("res://"):
		return not p.contains("..")
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path().replace("\\", "/").to_lower().trim_suffix("/") + "/"
	var ap := p.replace("\\", "/").simplify_path().to_lower()
	return p.is_absolute_path() and (ap + "/").begins_with(root)

# ¿Puede jugarse en serio este dataset? {ok, errors:[...], docs:int, routes:{cid: [ids de rutas ★ completas]}, missing:[cid]}
# (missing = obligatoria sin ninguna ruta ★ elegible sin fragmentos faltantes).
static func content_report(r) -> Dictionary:
	# El largo de los tramos y exámenes etiquetados (≤30 palabras, GDD_v3 §6.2) es una regla de redacción: se informa
	# aparte (long) y no vuelve injugable el dataset.
	var all_e: Array = r.errors()
	var errs: Array = all_e.filter(func(e): return not String(e).contains("(máx. 30, GDD_v3 §6.2)"))
	var out := {"ok": true, "errors": errs.slice(0, 12), "long": all_e.size() - errs.size(), "docs": (r.docs() as Dictionary).size(), "routes": {}, "missing": []}
	if not out.errors.is_empty():
		out.ok = false
	for cid in RouteDB.mandatory(r):
		var ids: Array = []
		for rt in RouteDB.routes(r, String(cid)):
			if bool(rt.get("star", false)) and bool(rt.get("eligible", false)) and (rt.get("missing", []) as Array).is_empty():
				ids.append(String(rt.id))
		out.routes[String(cid)] = ids
		if ids.is_empty():
			out.missing.append(String(cid))
	if out.docs == 0 or not out.missing.is_empty():
		out.ok = false
	return out
