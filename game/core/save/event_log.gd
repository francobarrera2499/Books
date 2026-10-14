# core/save/event_log.gd — guardado determinista por registro de acciones (§5.5). Dueño: W1-ENG. Contrato: §3.8.
# Archivo JSONL canónico: línea 1 = cabecera {"v":1,"seed":int,"content":hash,"engine":"4.7.2"}; luego una acción
# normalizada por línea (J.stringify_canon). Escritura atómica (J.write_atomic: .tmp -> .bak -> rename).
# read(): una última línea truncada/ilegible se descarta (sólo puede ser una acción cuyo resultado no se mostró).
#   Si falta el archivo, se intenta recuperar de .tmp y luego de .bak ("recovered").
#   Resultado: {ok, header, actions, err, dropped:int, recovered:""|"tmp"|"bak"}.
extends RefCounted

const J = preload("res://core/util/j.gd")

const VERSION := 3   # GDD_v3 §1.7: cabecera "v": 3; un guardado v < 3 no se repite (sólo partida nueva)

var path: String

func _init(p_path: String) -> void:
	path = p_path

func write(header: Dictionary, actions: Array) -> bool:
	return J.write_atomic(path, to_text(header, actions))

static func to_text(header: Dictionary, actions: Array) -> String:
	var lines := PackedStringArray()
	lines.append(J.stringify_canon(header))
	for a in actions:
		lines.append(J.stringify_canon(a))
	return "\n".join(lines) + "\n"

static func make_header(seed: int, content_hash: String) -> Dictionary:
	return {"v": VERSION, "seed": seed, "content": content_hash, "engine": "4.7.2"}

static func read(path: String) -> Dictionary:
	var src := path
	var recovered := ""
	var abs_path := J._abs(path)
	if not FileAccess.file_exists(abs_path):
		if FileAccess.file_exists(abs_path + ".tmp"):
			src = path + ".tmp"
			recovered = "tmp"
		elif FileAccess.file_exists(abs_path + ".bak"):
			src = path + ".bak"
			recovered = "bak"
		else:
			return {"ok": false, "header": {}, "actions": [], "err": "no_existe", "dropped": 0, "recovered": ""}
	var res := parse_text(J.read_text(src))
	if not res.ok and recovered == "tmp" and FileAccess.file_exists(abs_path + ".bak"):
		res = parse_text(J.read_text(path + ".bak"))
		recovered = "bak"
	res["recovered"] = recovered
	res["v"] = int(res.get("header", {}).get("v", 0))
	return res

static func parse_text(text: String) -> Dictionary:
	var lines := text.split("\n")
	# quitar vacías del final (el archivo termina en "\n")
	while lines.size() > 0 and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	if lines.is_empty():
		return {"ok": false, "header": {}, "actions": [], "err": "vacio", "dropped": 0}
	var header = J.parse_str(lines[0])
	if typeof(header) != TYPE_DICTIONARY or not header.has("v") or not header.has("seed"):
		return {"ok": false, "header": {}, "actions": [], "err": "cabecera", "dropped": 0}
	var actions: Array = []
	var dropped := 0
	for k in range(1, lines.size()):
		var a = J.parse_str(lines[k])
		if typeof(a) != TYPE_DICTIONARY:
			if k == lines.size() - 1:
				dropped = 1
				break
			return {"ok": false, "header": header, "actions": actions, "err": "linea_%d" % (k + 1), "dropped": 0}
		actions.append(a)
	return {"ok": true, "header": header, "actions": actions, "err": "", "dropped": dropped}
