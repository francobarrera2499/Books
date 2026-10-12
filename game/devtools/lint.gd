# devtools/lint.gd — lint estático del código y de los datos. Dueño: W1-ENG. ARCHITECTURE §3.1, §11, §9.2 (T14).
# CLI (desde la raíz):  ./godot.sh --headless -s devtools/lint.gd [-- code|data|all] [-- <root de datos>]
#   code: determinismo en core/ (randi/randf/randomize/RandomNumberGenerator/Time./OS.get_ticks…), pureza de core/
#         (sin autoloads, Node, Input, get_tree, print salvo log.gd), class_name en game/, create_folio( fuera de
#         player_actions.gd (T14).
#   data: errores de DataRepo (esquema §4, marcado §4.3, referencias) sobre res://data (o el root indicado).
# Sale con 1 si hay hallazgos. Las reglas son static func: los tests las llaman (test_lint_determinism, test_t14_static).
# Los comentarios y los literales de texto se ignoran (se blanquean antes de buscar).
extends SceneTree

const CORE := "res://core"
const LOG_FILE := "res://core/util/log.gd"
const FOLIO_CALLER := "res://core/sim/player_actions.gd"

static var _rx := {}

static func _re(p: String) -> RegEx:
	if not _rx.has(p):
		var r := RegEx.new()
		r.compile(p)
		_rx[p] = r
	return _rx[p]

static func gd_files(root: String, exclude: Array = []) -> Array:
	var out: Array = []
	var r := root if root.ends_with("://") else root.trim_suffix("/")
	_walk(r, exclude, out)
	out.sort()
	return out

static func _walk(dir: String, exclude: Array, out: Array) -> void:
	for ex in exclude:
		if dir.begins_with(ex):
			return
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var p := _join(dir, f)
			var skip := false
			for ex in exclude:
				if p.begins_with(ex):
					skip = true
			if not skip:
				out.append(p)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		_walk(_join(dir, d), exclude, out)

# Blanquea comentarios y contenido de literales de texto (conserva saltos de línea y longitudes).
static func code_only(src: String) -> String:
	var out := PackedStringArray()
	var q := ""
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if q == "":
			if c == "#":
				while i < n and src[i] != "\n":
					out.append(" ")
					i += 1
				continue
			if c == "\"" or c == "'":
				if src.substr(i, 3) == c + c + c:
					q = c + c + c
					out.append("   ")
					i += 3
					continue
				q = c
				out.append(c)
				i += 1
				continue
			out.append(c)
			i += 1
		else:
			if c == "\\" and q.length() == 1:
				out.append("  ")
				i += 2
				continue
			if src.substr(i, q.length()) == q:
				out.append(q if q.length() == 1 else "   ")
				i += q.length()
				q = ""
				continue
			if c == "\n":
				if q.length() == 1:
					q = ""
				out.append("\n")
			else:
				out.append(" ")
			i += 1
	return "".join(out)

static func _scan(path: String, patterns: Array) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ["%s: no se pudo leer" % path]
	var code := code_only(f.get_as_text())
	f.close()
	var lines := code.split("\n")
	for ln in lines.size():
		for p in patterns:
			var m := _re(p[0]).search(lines[ln])
			if m != null:
				out.append("%s:%d: %s ('%s')" % [path, ln + 1, p[1], m.get_string().strip_edges()])
	return out

# §3.1 / D7: nada de azar ni reloj en core/.
static func determinism(root := CORE) -> Array:
	var pats := [
		["(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|rand_from_seed|seed)\\s*\\(", "azar global prohibido en core/ (usar Det)"],
		["\\bRandomNumberGenerator\\b", "RandomNumberGenerator prohibido en core/"],
		["\\bTime\\s*\\.", "Time prohibido en core/"],
		["\\bOS\\s*\\.\\s*(get_ticks\\w*|get_unix_time\\w*|get_system_time\\w*|delay_\\w*)", "reloj del sistema prohibido en core/"],
		["\\.\\s*shuffle\\s*\\(\\s*\\)", "Array.shuffle() usa el azar global (usar Det.shuffle)"],
		["\\.\\s*pick_random\\s*\\(", "pick_random() usa el azar global (usar Det.pick)"],
	]
	var out: Array = []
	for p in gd_files(root):
		out.append_array(_scan(p, pats))
	return out

# §1/§11: core/ es lógica pura sin nodos, entrada, autoloads ni print (salvo el logger).
static func core_purity(root := CORE) -> Array:
	var pats := [
		["(?<![\\w.])(Data|Game|Audio|ThemeInstaller)\\s*\\.", "core/ no referencia autoloads"],
		["^\\s*extends\\s+(Node|Node2D|Node3D|Control|CanvasItem|CanvasLayer)\\b", "core/ no extiende nodos"],
		["\\bInput\\s*\\.", "core/ no lee Input"],
		["(?<![\\w.])get_tree\\s*\\(", "core/ no usa el árbol de escena"],
	]
	var print_pat := [["(?<![\\w.])(print|print_rich|printraw|printerr|prints|printt)\\s*\\(", "nada de print en core/ (usar L.i/L.e)"]]
	var out: Array = []
	for p in gd_files(root):
		out.append_array(_scan(p, pats))
		if p != LOG_FILE:
			out.append_array(_scan(p, print_pat))
	return out

# §11: sin class_name en game/ (no resuelve en un clon limpio).
static func class_names(root := "res://") -> Array:
	var kw := "class" + "_" + "name"
	return _all(root, [["^\\s*" + kw + "\\b", kw + " prohibido"]], ["res://.godot"])

# T14 (GDD§15.5: «sólo PlayerActions llama a create_folio»): create_folio( sólo en player_actions.gd; en cualquier
# otro archivo (ledger.gd incluido) sólo cuenta su definición `func create_folio(`. tests/ queda fuera (tests unitarios).
static func create_folio_calls(root := "res://") -> Array:
	var tok := "create" + "_folio"
	var out: Array = []
	for p in gd_files(root, ["res://.godot", "res://tests"]):
		if p == FOLIO_CALLER:
			continue
		out.append_array(_scan(p, [["(?<!func )(?<!func\\t)\\b" + tok + "\\s*\\(", tok + " sólo desde player_actions.gd (T14)"]]))
	return out

static func _all(root: String, pats: Array, exclude: Array) -> Array:
	var out: Array = []
	for p in gd_files(root, exclude):
		out.append_array(_scan(p, pats))
	return out

static func code_findings() -> Array:
	var out: Array = []
	out.append_array(determinism())
	out.append_array(core_purity())
	out.append_array(class_names())
	out.append_array(create_folio_calls())
	return out

static func data_findings(root := "res://data") -> Array:
	var R = load("res://core/data/data_repo.gd")
	return R.fresh(root).errors()

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var mode := "all"
	var root := "res://data"
	for a in OS.get_cmdline_user_args():
		if a in ["code", "data", "all"]:
			mode = a
		elif a.begins_with("res://"):
			root = a
	var found: Array = []
	if mode in ["code", "all"]:
		var c := code_findings()
		print("== código: %d hallazgos" % c.size())
		for x in c:
			print("  ", x)
		found.append_array(c)
	if mode in ["data", "all"]:
		var d := data_findings(root)
		print("== datos (%s): %d hallazgos" % [root, d.size()])
		for x in d:
			print("  ", x)
		found.append_array(d)
	print("LINT: %d hallazgos" % found.size())
	quit(1 if found.size() > 0 else 0)

static func _join(dir: String, f: String) -> String:
	return dir + f if dir.ends_with("/") else dir + "/" + f
