# devtools/drivers/slice_script.gd — lectura de los guiones de W4-SLICE (devtools/scripts/slice_<final>.jsonl).
# Lo usan tests/test_slice_*.gd y los drivers slice_*. Formato: una acción JSON por línea (GameSim.apply, §3.5); «#» comenta;
# cabecera «# seed: N», «# expect: F1», «# content: <hash>»; «# ── <tk> · …» marca la franja (anotación de slice_record).
extends RefCounted

const J = preload("res://core/util/j.gd")

const DIR := "res://devtools/scripts"
const KEYS := ["f1", "f2", "f3a", "f4"]

static func path(key: String) -> String:
	return DIR.path_join("slice_%s.jsonl" % key)

# {ok, err, seed, expect, content, actions:[Dictionary], lines:[int] (línea 1-based de cada acción), marks:{índice: [comentarios]}}
static func load_script(p: String) -> Dictionary:
	var out := {"ok": false, "err": "", "seed": 0, "expect": "", "content": "", "actions": [], "lines": [], "marks": {}}
	if not FileAccess.file_exists(p):
		out.err = "no existe " + p
		return out
	var txt := FileAccess.get_file_as_string(p)
	var pend: Array = []
	var ln := 0
	for raw in txt.split("\n"):
		ln += 1
		var s := String(raw).strip_edges()
		if s == "":
			continue
		if s.begins_with("#"):
			var body := s.substr(1).strip_edges()
			if body.begins_with("seed:"):
				out.seed = int(body.substr(5).strip_edges())
			elif body.begins_with("expect:"):
				out.expect = body.substr(7).strip_edges()
			elif body.begins_with("content:"):
				out.content = body.substr(8).strip_edges()
			else:
				pend.append(body)
			continue
		var a = J.parse_str(s)   # enteros como int (igual que EventLog y Shell.run_script)
		if typeof(a) != TYPE_DICTIONARY or String(a.get("t", "")) == "":
			out.err = "línea %d ilegible: %s" % [ln, s.left(120)]
			return out
		if not pend.is_empty():
			out.marks[(out.actions as Array).size()] = pend
			pend = []
		out.actions.append(a)
		out.lines.append(ln)
	out.ok = out.seed != 0 and out.expect != "" and not (out.actions as Array).is_empty()
	if not out.ok and out.err == "":
		out.err = "cabecera incompleta (seed/expect) o sin acciones"
	return out
