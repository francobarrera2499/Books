# core/util/j.gd — JSON canónico. Dueño: W1-ENG. Contrato: ARCHITECTURE §3.8, §4.2, §5.5.
# parse_*: todo float entero (|x| < 2^53) pasa a int, recursivo. Nunca push_error (errores -> null + last_error()).
# stringify_canon: claves ordenadas (orden de código), sin espacios, ints sin ".0"; floats enteros salen como int
# (coherente con parse_*); floats no enteros con var_to_str (repr. más corta que re-parsea igual).
extends RefCounted

const MAX_SAFE := 9007199254740992.0  # 2^53

static var _last_error := ""

static func last_error() -> String:
	return _last_error

static func parse_file(path: String):
	_last_error = ""
	if not FileAccess.file_exists(path):
		_last_error = "no_existe: " + path
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_last_error = "no_abre: %s (%d)" % [path, FileAccess.get_open_error()]
		return null
	var s := f.get_as_text()
	f.close()
	return parse_str(s)

static func parse_str(s: String):
	_last_error = ""
	var j := JSON.new()
	var err := j.parse(s)
	if err != OK:
		_last_error = "linea %d: %s" % [j.get_error_line(), j.get_error_message()]
		return null
	return ints(j.data)

# Convierte floats enteros a int, recursivo (también útil para datos armados en código).
static func ints(v):
	match typeof(v):
		TYPE_FLOAT:
			if is_finite(v) and absf(v) < MAX_SAFE and v == floorf(v):
				return int(v)
			return v
		TYPE_ARRAY:
			var out := []
			out.resize(v.size())
			for i in v.size():
				out[i] = ints(v[i])
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = ints(v[k])
			return d
	return v

static func stringify_canon(v) -> String:
	var parts := PackedStringArray()
	_emit(v, parts)
	return "".join(parts)

static func _emit(v, out: PackedStringArray) -> void:
	match typeof(v):
		TYPE_NIL:
			out.append("null")
		TYPE_BOOL:
			out.append("true" if v else "false")
		TYPE_INT:
			out.append(str(v))
		TYPE_FLOAT:
			if not is_finite(v):
				out.append("null")
			elif absf(v) < MAX_SAFE and v == floorf(v):
				out.append(str(int(v)))
			else:
				out.append(var_to_str(v))
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			out.append(quote(String(v)))
		TYPE_DICTIONARY:
			var keys := []
			for k in v:
				keys.append(String(k) if typeof(k) in [TYPE_STRING, TYPE_STRING_NAME] else str(k))
			var orig := {}
			for k in v:
				orig[String(k) if typeof(k) in [TYPE_STRING, TYPE_STRING_NAME] else str(k)] = v[k]
			keys.sort()
			out.append("{")
			var first := true
			for k in keys:
				if not first:
					out.append(",")
				first = false
				out.append(quote(k))
				out.append(":")
				_emit(orig[k], out)
			out.append("}")
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			out.append("[")
			for i in v.size():
				if i > 0:
					out.append(",")
				_emit(v[i], out)
			out.append("]")
		_:
			out.append(quote(var_to_str(v)))

static func quote(s: String) -> String:
	var b := PackedStringArray()
	b.append("\"")
	for i in s.length():
		var c := s.unicode_at(i)
		match c:
			34: b.append("\\\"")
			92: b.append("\\\\")
			10: b.append("\\n")
			13: b.append("\\r")
			9: b.append("\\t")
			8: b.append("\\b")
			12: b.append("\\f")
			_:
				if c < 32:
					b.append("\\u%04x" % c)
				else:
					b.append(s[i])
	b.append("\"")
	return "".join(b)

# Escritura atómica: path.tmp -> (path -> path.bak) -> rename(tmp, path). Crea el directorio.
static func write_atomic(path: String, text: String) -> bool:
	var p := _abs(path)
	var dir := p.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			_last_error = "no_crea_dir: " + dir
			return false
	var tmp := p + ".tmp"
	var bak := p + ".bak"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		_last_error = "no_abre_tmp: %s (%d)" % [tmp, FileAccess.get_open_error()]
		return false
	f.store_string(text)
	f.flush()
	var werr := f.get_error()
	f.close()
	if werr != OK:
		_last_error = "escritura: %d" % werr
		return false
	if FileAccess.file_exists(p):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		if DirAccess.rename_absolute(p, bak) != OK:
			_last_error = "rename_bak"
			return false
	if DirAccess.rename_absolute(tmp, p) != OK:
		_last_error = "rename_tmp"
		return false
	return true

static func _abs(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path

static func read_text(path: String) -> String:
	var p := _abs(path)
	if not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s
