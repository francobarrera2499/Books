# Runner de tests (ARCHITECTURE §9.1). Dueño: W1-ENG.
# Uso (desde la raíz del repo):
#   ./godot.sh --headless -s tests/run_tests.gd [-- <filtro>] [--list] [--slow]
#   ./godot.sh -s tests/run_tests.gd -- --window [<filtro>]        (sólo tests con const WINDOW := true; SIN --headless)
# Corre res://tests/test_*.gd (salvo test_base.gd); métodos test_* en orden de declaración.
# - Logger (OS.add_logger): todo ERROR/SCRIPT/SHADER durante un test lo hace fallar, salvo expect_error(substr)
#   (una expectativa no cumplida también falla). Las advertencias no cuentan. Errores fuera de un test (autoloads,
#   carga) -> FAIL runner::fuera_de_tests.
# - Watchdog por test (TIMEOUT_S = 30 s; const TIMEOUT_S en el archivo lo cambia) para tests con await colgados.
#   Los tests síncronos deben tener bucles acotados.
# - const SLOW := true -> SKIP salvo --slow (los tests leen `slow` para el modo completo). const WINDOW := true -> SKIP
#   salvo --window (y con --window sólo corren esos).
# Salida: "PASS|FAIL|SKIP archivo::test" y "TESTS: n run, f failed, s skipped". Código 0/1.
extends SceneTree

const DEFAULT_TIMEOUT_S := 30.0
const TESTS_DIR := "res://tests"

class Cap extends Logger:
	var mutex := Mutex.new()
	var stack: Array = []
	var outside: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		var kind: String = ["ERROR", "WARNING", "SCRIPT", "SHADER"][error_type] if error_type >= 0 and error_type < 4 else "ERROR"
		var msg := "%s: %s%s (%s:%d %s)" % [kind, code, (" | " + rationale) if rationale != "" else "", file.get_file(), line, function]
		mutex.lock()
		if stack.is_empty():
			outside.append(msg)
		else:
			stack[stack.size() - 1].errors.append(msg)
		mutex.unlock()

	func _log_message(message: String, error: bool) -> void:
		pass

	func push_ctx() -> Dictionary:
		var c := {"errors": []}
		mutex.lock()
		stack.append(c)
		mutex.unlock()
		return c

	# Quita c y todo contexto huérfano por encima (p. ej. un run_one anidado abortado por error de script);
	# los errores de los huérfanos pasan a c para no perderlos.
	func pop_ctx(c: Dictionary) -> void:
		mutex.lock()
		var i := -1
		for k in range(stack.size() - 1, -1, -1):
			if is_same(stack[k], c):
				i = k
				break
		if i >= 0:
			for k in range(i + 1, stack.size()):
				c.errors.append_array(stack[k].errors)
			stack.resize(i)
		mutex.unlock()

var cap: Cap
var filter := ""
var list_only := false
var slow := false
var window := false

func _init() -> void:
	cap = Cap.new()
	OS.add_logger(cap)
	_run.call_deferred()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		match a:
			"--":
				pass
			"--list":
				list_only = true
			"--slow":
				slow = true
			"--window":
				window = true
			_:
				if a.begins_with("--"):
					printerr("run_tests: opción desconocida ", a)
				elif filter == "":
					filter = a

func test_files(p_filter := "") -> Array:
	var files: Array = []
	var d := DirAccess.open(TESTS_DIR)
	if d == null:
		return files
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd" and (p_filter == "" or _matches(f, p_filter)):
			files.append(f)
	files.sort()
	return files

# filtro: subcadena del archivo; varias separadas por coma (cualquiera).
static func _matches(f: String, p_filter: String) -> bool:
	for part in p_filter.split(",", false):
		if f.contains(part.strip_edges()):
			return true
	return false

static func test_methods(scr: Script) -> Array:
	var methods: Array = []
	for m in scr.get_script_method_list():
		var n := String(m.name)
		if n.begins_with("test_") and not methods.has(n):
			methods.append(n)
	return methods

# ["archivo::test"] sin correr nada (también lo usa el selfcheck).
func list_tests(p_filter := "") -> Array:
	var out: Array = []
	for f in test_files(p_filter):
		var c := cap.push_ctx()
		var scr = load(TESTS_DIR + "/" + f)
		cap.pop_ctx(c)
		if scr == null or not scr.can_instantiate():
			out.append(f + "::<carga>")
			continue
		for m in test_methods(scr):
			out.append(f + "::" + m)
	return out

# Motivo de SKIP por constantes del archivo ("" = corre).
func file_gate(consts: Dictionary) -> String:
	if consts.get("WINDOW", false):
		if not window:
			return "WINDOW (correr con -- --window, sin --headless)"
		if DisplayServer.get_name() == "headless":
			return "WINDOW requiere ventana (sin --headless)"
	elif window:
		return "__omitir__"
	if consts.get("SLOW", false) and not slow:
		return "SLOW (correr con -- --slow)"
	return ""

# Corre un archivo; devuelve [{name, status, fails, reason, ms}]. quiet = no imprime (selfcheck).
func run_file(path: String, quiet := false) -> Array:
	var fname := path.get_file()
	var results: Array = []
	var c := cap.push_ctx()
	var scr = load(path)
	cap.pop_ctx(c)
	if scr == null or not scr.can_instantiate():
		var r := {"name": fname + "::<carga>", "status": "FAIL", "fails": ["no carga (error de parseo/compilación)"] + c.errors, "reason": "", "ms": 0}
		_report(r, quiet)
		return [r]
	if not c.errors.is_empty():
		# compiló, pero el motor registró errores al cargarlo (dependencias, recursos): no se tragan en silencio
		var rl := {"name": fname + "::<carga>", "status": "FAIL", "fails": ["errores del motor al cargar el archivo"] + c.errors, "reason": "", "ms": 0}
		_report(rl, quiet)
		results.append(rl)
	var consts: Dictionary = scr.get_script_constant_map()
	var gate := file_gate(consts)
	if gate == "__omitir__":
		return results
	for m in test_methods(scr):
		var r: Dictionary
		if gate != "":
			r = {"name": fname + "::" + m, "status": "SKIP", "fails": [], "reason": gate, "ms": 0}
		else:
			r = await run_one(scr, m, fname, float(consts.get("TIMEOUT_S", DEFAULT_TIMEOUT_S)))
		_report(r, quiet)
		results.append(r)
	return results

func run_one(scr: Script, m: String, fname := "", timeout_s := DEFAULT_TIMEOUT_S) -> Dictionary:
	var label := fname + "::" + m
	var t0 := Time.get_ticks_msec()
	var ctx := cap.push_ctx()
	# Tipado Object a propósito: una llamada dinámica sobre Variant que devuelve GDScriptFunctionState dispara
	# "Trying to call an async function without await" en builds de depuración y aborta run_one.
	var t: Object = scr.new()
	t.set("tree", self)
	t.set("_cur", label)
	t.set("slow", slow)
	t.call("before_each")
	var timed_out := false
	var r = t.call(m)
	if r is Object and r.get_class() == "GDScriptFunctionState":
		var done := [false]
		r.completed.connect(func(_v = null): done[0] = true)
		while not done[0]:
			if Time.get_ticks_msec() - t0 > int(timeout_s * 1000.0):
				timed_out = true
				break
			await process_frame
	t.call("after_each")
	cap.pop_ctx(ctx)
	var fails: Array = t.get("_fails").duplicate()
	var expected: Array = t.get("_expected")
	var skip_reason: String = t.get("_skip")
	if timed_out:
		fails.append("%s: watchdog: no terminó en %.1f s" % [label, timeout_s])
	var matched := {}
	for e in ctx.errors:
		var excused := false
		for s in expected:
			if String(e).contains(s):
				matched[s] = true
				excused = true
		if not excused:
			fails.append("%s: error del motor: %s" % [label, e])
	for s in expected:
		if not matched.has(s):
			fails.append("%s: se esperaba un error con '%s' y no ocurrió" % [label, s])
	var status := "PASS"
	if not fails.is_empty():
		status = "FAIL"
	elif skip_reason != "":
		status = "SKIP"
	return {"name": label, "status": status, "fails": fails, "reason": skip_reason, "ms": Time.get_ticks_msec() - t0}

func _report(r: Dictionary, quiet: bool) -> void:
	if quiet:
		return
	var line: String = "%s %s" % [r.status, r.name]
	if r.status == "SKIP" and r.reason != "":
		line += "  (" + r.reason + ")"
	elif r.ms >= 1000:
		line += "  [%d ms]" % r.ms
	print(line)
	for f in r.fails:
		printerr("    ", f)

func _run() -> void:
	_parse_args()
	if list_only:
		for x in list_tests(filter):
			print(x)
		quit(0)
		return
	var run := 0
	var failed := 0
	var skipped := 0
	var all_fails: Array = []
	for f in test_files(filter):
		var res: Array = await run_file(TESTS_DIR + "/" + f)
		for r in res:
			match r.status:
				"SKIP":
					skipped += 1
				"FAIL":
					run += 1
					failed += 1
					all_fails.append(r.name)
				_:
					run += 1
	if not cap.outside.is_empty():
		failed += 1
		run += 1
		print("FAIL runner::fuera_de_tests")
		for e in cap.outside:
			printerr("    ", e)
		all_fails.append("runner::fuera_de_tests")
	if not all_fails.is_empty():
		printerr("FALLARON: ", ", ".join(all_fails))
	print("TESTS: %d run, %d failed, %d skipped" % [run, failed, skipped])
	OS.remove_logger(cap)
	quit(1 if failed > 0 or run + skipped == 0 else 0)
