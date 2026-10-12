# core/deduction/index.gd — índice del jugador (GDD§8.2). Dueño: W2-DED. Contrato: ARCHITECTURE §3.8.
# st.ded.index: {ent: {"n": orden de entrada, "label": etiqueta runtime ("" para entidades de data)}}.
# Entidades runtime: "act.<seq>" (kind act_ref, §3.6); su etiqueta es la superficie recortada («asiento 214, mar. 27»).
# Extensiones (fuera del contrato mínimo): ensure(st) (estado st.ded completo e idempotente; lo usan clipper/ledger/
#   validator), label(), kind(), rows() (= q_index), is_runtime(), sort_key().
# known(st, repo) -> [ids] ordenados por etiqueta de índice (sin tildes, sin mayúsculas, ñ tras n), desempate por id.
extends RefCounted

const L = preload("res://core/util/log.gd")

const DED_DICTS := ["clips", "pairs", "folios", "entries", "index", "sealed"]
const DED_ARRAYS := ["practice", "passes"]

# st.ded con todas sus claves (§3.3). Idempotente: nunca pisa lo existente.
static func ensure(st) -> Dictionary:
	if typeof(st.ded) != TYPE_DICTIONARY:
		st.ded = {}
	var d: Dictionary = st.ded
	for k in DED_DICTS:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			d[k] = {}
	for k in DED_ARRAYS:
		if typeof(d.get(k)) != TYPE_ARRAY:
			d[k] = []
	return d

static func is_runtime(id: String) -> bool:
	return id.begins_with("act.")

# ents: [id] o [{id, label}] (label sólo cuenta para entidades runtime; la primera etiqueta queda).
static func add_entities(st, repo, ents: Array) -> void:
	add(st, repo, ents, true)

static func add(st, repo, ents: Array, notify: bool) -> Array:
	var idx: Dictionary = ensure(st).index
	var added: Array = []
	for e in ents:
		var id := ""
		var label := ""
		if typeof(e) == TYPE_DICTIONARY:
			id = String(e.get("id", ""))
			label = String(e.get("label", ""))
		else:
			id = String(e)
		if id == "":
			continue
		if idx.has(id):
			if label != "" and String(idx[id].get("label", "")) == "" and is_runtime(id):
				idx[id]["label"] = label
			continue
		if not is_runtime(id) and repo.entity(id).is_empty():
			L.w("index", "entidad inexistente ignorada: " + id)
			continue
		idx[id] = {"n": idx.size(), "label": label if is_runtime(id) else ""}
		added.append(id)
	if notify and not added.is_empty() and st is Object and st.has_method("note"):
		st.note("index", {"added": added})
	return added

static func has(st, ent: String) -> bool:
	if typeof(st.ded) != TYPE_DICTIONARY:
		return false
	var idx = st.ded.get("index", {})
	return typeof(idx) == TYPE_DICTIONARY and idx.has(ent)

static func known(st, repo) -> Array:
	var idx: Dictionary = ensure(st).index
	var ids: Array = idx.keys()
	var keys := {}
	for id in ids:
		keys[id] = sort_key(label(st, repo, String(id)))
	ids.sort_custom(func(a, b):
		if keys[a] == keys[b]:
			return String(a) < String(b)
		return keys[a] < keys[b])
	return ids

# q_index: [{id, label, kind}] en el orden de known().
static func rows(st, repo) -> Array:
	var out: Array = []
	for id in known(st, repo):
		out.append({"id": id, "label": label(st, repo, id), "kind": kind(repo, id)})
	return out

# Entidad runtime: etiqueta del acto en st.world.acts (W2-SIM: «asiento 214, mar. 27») > superficie recortada > id.
static func label(st, repo, id: String) -> String:
	if is_runtime(id):
		var w = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
		var acts = w.get("acts", {})
		if typeof(acts) == TYPE_DICTIONARY and typeof(acts.get(id)) == TYPE_DICTIONARY and String(acts[id].get("label", "")) != "":
			return String(acts[id].label)
		var idx = ensure(st).index
		var lb := String(idx.get(id, {}).get("label", "")) if idx.has(id) else ""
		return lb if lb != "" else id
	var e: Dictionary = repo.entity(id)
	if e.is_empty():
		return id
	return String(e.get("index", e.get("name", id)))

static func kind(repo, id: String) -> String:
	if is_runtime(id):
		return "act_ref"
	return String(repo.entity(id).get("kind", ""))

const _FOLD := {"á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "í": "i", "ì": "i",
	"î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "ö": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ñ": "n~", "ç": "c"}

static func sort_key(s: String) -> String:
	var t := s.to_lower()
	var i := 0
	while i < t.length() and not (t[i].to_upper() != t[i].to_lower() or (t.unicode_at(i) >= 48 and t.unicode_at(i) <= 57)):
		i += 1
	t = t.substr(i)
	var out := PackedStringArray()
	for k in t.length():
		var c := t[k]
		out.append(_FOLD.get(c, c))
	return "".join(out)
