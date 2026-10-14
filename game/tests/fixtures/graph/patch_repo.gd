# tests/fixtures/graph/patch_repo.gd — envoltorio de un DataRepo para casos negativos de W2-GRAPH (nada se escribe a disco).
# PatchRepo.new(base, {questions:{id: dict|null}, dossier:{...}, reactions:{id: dict|null}, docs:{id: dict|null},
#   schedule:{...}, places:{id: dict|null}, scenes:{id: dict|null}}). null = borrar. Implementa los métodos de DataRepo
#   que usa core/graph y un `cache` propio (los cachés del grafo no se mezclan con los del repo base).
extends RefCounted

const Markup = preload("res://core/text/markup.gd")

var base
var cache := {}
var _p := {}
var _parsed := {}

func _init(b, patch := {}) -> void:
	base = b
	_p = patch.duplicate(true)

func _ov(kind: String) -> Dictionary:
	var d = _p.get(kind, {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _get_one(kind: String, id: String, fallback: Dictionary) -> Dictionary:
	var o := _ov(kind)
	if o.has(id):
		return o[id] if typeof(o[id]) == TYPE_DICTIONARY else {}
	return fallback

func _merged(kind: String, base_dict: Dictionary) -> Dictionary:
	var out := {}
	for k in base_dict:
		out[k] = base_dict[k]
	var o := _ov(kind)
	for k in o:
		if typeof(o[k]) == TYPE_DICTIONARY:
			out[k] = o[k]
		else:
			out.erase(k)
	return out

func errors() -> Array:
	return []

# v3 (GDD_v3 §1.7): preguntas del Expediente. patch {questions:{id: dict|null}, dossier:{...meta}}.
func question(id: String) -> Dictionary:
	return _get_one("questions", id, base.question(id) if base.has_method("question") else {})

func questions() -> Array:
	var ids := {}
	var order := {}
	if base.has_method("questions"):
		for q in base.questions():
			ids[String(q.id)] = true
			order[String(q.id)] = int(q.get("orden", 0))
	for k in _ov("questions"):
		ids[k] = true
		if typeof(_ov("questions")[k]) == TYPE_DICTIONARY:
			order[k] = int(_ov("questions")[k].get("orden", 0))
	var keys: Array = ids.keys()
	keys.sort_custom(func(a, b): return int(order.get(a, 0)) < int(order.get(b, 0)) or (int(order.get(a, 0)) == int(order.get(b, 0)) and String(a) < String(b)))
	var out: Array = []
	for k in keys:
		var q := question(String(k))
		if not q.is_empty():
			out.append(q)
	return out

func dossier() -> Dictionary:
	if _p.has("dossier"):
		return _p.dossier
	return base.dossier() if base.has_method("dossier") else {}

func is_inactive(did: String) -> bool:
	return base.is_inactive(did) if base.has_method("is_inactive") else false

func inactive_docs() -> Array:
	return base.inactive_docs() if base.has_method("inactive_docs") else []

func files() -> Dictionary:
	return base.files() if base.has_method("files") else {}

func text(key: String, vars := {}) -> String:
	return base.text(key, vars) if base.has_method("text") else key

func reaction(id: String) -> Dictionary:
	return _get_one("reactions", id, base.reaction(id))

func reactions() -> Array:
	var ids := {}
	for r in base.reactions():
		ids[String(r.id)] = true
	for k in _ov("reactions"):
		ids[k] = true
	var keys: Array = ids.keys()
	keys.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	var out: Array = []
	for k in keys:
		var r := reaction(String(k))
		if not r.is_empty():
			out.append(r)
	return out

func doc(id: String) -> Dictionary:
	return _get_one("docs", id, base.doc(id))

func docs() -> Dictionary:
	return _merged("docs", base.docs())

func copy(copy_id: String) -> Dictionary:
	var o := _ov("docs")
	for did in o:
		var d = o[did]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		for c in d.get("copies", []):
			if String(c.get("id", "")) == copy_id:
				var cc: Dictionary = c.duplicate()
				if not cc.has("class"):
					cc["class"] = d.get("class", "I")
				return {"copy": cc, "doc": did}
	var b: Dictionary = base.copy(copy_id)
	if not b.is_empty() and o.has(String(b.doc)):
		return {}
	return b

func parsed(doc_id: String, part_id: String) -> Dictionary:
	if not _ov("docs").has(doc_id):
		return base.parsed(doc_id, part_id)
	var key := doc_id + "|" + part_id
	if _parsed.has(key):
		return _parsed[key]
	for p in doc(doc_id).get("parts", []):
		if String(p.get("id", "")) == part_id:
			var pt := Markup.parse(String(p.get("text", "")), base.markup_ctx())
			_parsed[key] = pt
			return pt
	return {}

func entity(id: String) -> Dictionary:
	return base.entity(id)

func entities() -> Dictionary:
	return base.entities()

func lists() -> Dictionary:
	return base.lists()

func markup_ctx() -> Dictionary:
	return base.markup_ctx()

func schedule() -> Dictionary:
	if _p.has("schedule"):
		return _p.schedule
	return base.schedule()

func place(id: String) -> Dictionary:
	return _get_one("places", id, base.place(id))

func places() -> Dictionary:
	return _merged("places", base.places())

func plate(id: String) -> Dictionary:
	return base.plate(id)

func plates() -> Dictionary:
	return base.plates()

func scene(id: String) -> Dictionary:
	return _get_one("scenes", id, base.scene(id))

func scenes() -> Dictionary:
	return _merged("scenes", base.scenes())

func dialogue(char_id: String) -> Dictionary:
	return base.dialogue(char_id)

func dialogues() -> Dictionary:
	return base.dialogues()

# v2 (GDD_v2 §C.5): descripción física (RouteDB R:<rid>.fisica) y tramos de documento.
func fisica() -> Dictionary:
	return base.fisica() if base.has_method("fisica") else {}

func doc_tramo(doc_id: String, tid: String) -> Dictionary:
	if not _ov("docs").has(doc_id):
		return base.doc_tramo(doc_id, tid)
	for p in doc(doc_id).get("parts", []):
		for t in parsed(doc_id, String(p.get("id", ""))).get("tramos", []):
			if String(t.id) == tid:
				var r: Dictionary = t.duplicate()
				r["part"] = p.id
				return r
	return {}

func map() -> Dictionary:
	return base.map() if base.has_method("map") else {}

func parse_text(src: String, vars := {}, act := "") -> Dictionary:
	return base.parse_text(src, vars, act)
