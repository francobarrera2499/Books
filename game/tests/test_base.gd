# Base de tests (ARCHITECTURE §9.1). Dueño: W1-ENG.
# Cada archivo: extends "res://tests/test_base.gd"; métodos test_* (pueden usar await; watchdog del runner).
# Constantes opcionales del archivo: TIMEOUT_S (s), SLOW (sólo con --slow), WINDOW (sólo con --window, con ventana).
# skip(reason) no corta la función: usar `skip("..."); return`.
# Nombres reservados (no declarar en los tests): tree, slow, repo, fixture_repo, tmp_dir, ok, no, eq, ne, near, has,
# fail, skip, expect_error, content_strict, pending_content, before_each, after_each y los que empiezan con "_".
# El runner tipa la instancia como Object: los tests pueden ser corrutinas (await) sin aviso de depuración.
extends RefCounted

var _fails: Array = []
var _cur := ""
var _skip := ""
var _expected: Array = []
var _tmp := ""
var tree: SceneTree
var slow := false            # true con --slow (modo completo de T3, etc.)

func fail(msg: String) -> void:
	_fails.append("%s: %s" % [_cur, msg])

func ok(cond: bool, msg := "expected true") -> void:
	if not cond:
		fail(msg)

func no(cond: bool, msg := "expected false") -> void:
	if cond:
		fail(msg)

func eq(a, b, msg := "") -> void:
	if typeof(a) != typeof(b) and not ((typeof(a) in [TYPE_INT, TYPE_FLOAT]) and (typeof(b) in [TYPE_INT, TYPE_FLOAT])):
		fail("%s expected %s (%s) got %s (%s)" % [msg, str(b), type_string(typeof(b)), str(a), type_string(typeof(a))])
		return
	if a != b:
		fail("%s expected %s got %s" % [msg, str(b), str(a)])

func ne(a, b, msg := "") -> void:
	if typeof(a) == typeof(b) and a == b:
		fail("%s expected != %s" % [msg, str(b)])

func near(a, b, eps := 1e-6, msg := "") -> void:
	if absf(float(a) - float(b)) > eps:
		fail("%s expected %s ± %s got %s" % [msg, str(b), str(eps), str(a)])

func has(container, item, msg := "") -> void:
	if not container.has(item):
		fail("%s %s no contiene %s" % [msg, str(container).left(200), str(item)])

func skip(reason: String) -> void:
	_skip = reason

# El test falla si NO se registra un error del motor que contenga substr; los que lo contienen no cuentan como falla.
func expect_error(substr: String) -> void:
	if not _expected.has(substr):
		_expected.append(substr)

# .work/tests/<archivo>/ creado y vaciado (una vez por test). Ruta absoluta del sistema.
func tmp_dir() -> String:
	if _tmp != "":
		return _tmp
	var stem := _cur.get_slice("::", 0).get_basename()
	if stem == "":
		stem = "anon"
	var p := ProjectSettings.globalize_path("res://").path_join("../.work/tests/" + stem).simplify_path()
	if not p.replace("\\", "/").contains("/.work/tests/"):
		fail("tmp_dir fuera de .work/tests: " + p)
		return ""
	DirAccess.make_dir_recursive_absolute(p)
	_clear_dir(p)
	_tmp = p
	return p

static func _clear_dir(p: String) -> void:
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_clear_dir(p.path_join(d))
		DirAccess.remove_absolute(p.path_join(d))

# DataRepo de res://data (cacheado por root).
func repo():
	return load("res://core/data/data_repo.gd").load_dir("res://data")

# DataRepo de res://tests/fixtures/<name> (cacheado por root).
func fixture_repo(name := "data_min"):
	return load("res://core/data/data_repo.gd").load_dir("res://tests/fixtures/" + name)

# tests/content_gate.json {"strict": bool} (W4-QA). Ausente -> false.
func content_strict() -> bool:
	var p := "res://tests/content_gate.json"
	if not FileAccess.file_exists(p):
		return false
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return false
	return bool(j.data.get("strict", false))

# Faltante de contenido: SKIP si no es estricto, FAIL si lo es.
func pending_content(msg: String) -> void:
	if content_strict():
		fail("contenido pendiente: " + msg)
	else:
		skip("contenido pendiente: " + msg)

func before_each() -> void:
	pass

func after_each() -> void:
	pass
