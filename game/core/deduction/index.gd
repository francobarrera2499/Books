# core/deduction/index.gd — índice del jugador (GDD§8.2). Dueño: W2-DED. Contrato: ARCHITECTURE §3.8 (v3: GDD_v3 §1).
# st.ded.index: {ent: {"n": orden de entrada, "label": etiqueta runtime ("" para entidades de data)}}.
# Entidades runtime: "act.<seq>" (kind act_ref, §3.6); su etiqueta es la superficie recortada («asiento 214, mar. 27»).
# Extensiones (fuera del contrato mínimo): ensure(st) (estado st.ded completo e idempotente; lo usan clipper/dossier/
#   validator), label(), kind(), rows() (= q_index), is_runtime(), sort_key().
# known(st, repo) -> [ids] ordenados por la forma de índice (sin tildes, sin mayúsculas, ñ tras n), desempate por id;
#   label() devuelve el nombre natural (display) para mostrar.
extends RefCounted

const L = preload("res://core/util/log.gd")

# v3 (GDD_v3 §1): sin pares, folios, asientos, sellos, práctica ni pasadas; el Expediente vive en st.ded.dossier.
const DED_DICTS := ["clips", "index", "dossier"]
const DED_ARRAYS := []

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
		keys[id] = sort_key(index_label(st, repo, String(id)))
	ids.sort_custom(func(a, b):
		if keys[a] == keys[b]:
			return String(a) < String(b)
		return keys[a] < keys[b])
	return ids

# q_index: [{id, label, kind, index}] en el orden de known() (label = nombre natural; index = forma de catálogo, la que
# muestra y agrupa por letra la pestaña «Índice» del cuaderno).
static func rows(st, repo) -> Array:
	var out: Array = []
	for id in known(st, repo):
		out.append({"id": id, "label": label(st, repo, id), "kind": kind(repo, id), "index": index_label(st, repo, id)})
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
	return display(repo, id)

# Forma de índice (catálogo invertido: «Watson, John H., doctor», «Times, The»): SÓLO para ordenar (playtest v2: a la vista
# va el nombre natural, display()).
static func index_label(st, repo, id: String) -> String:
	if is_runtime(id):
		return label(st, repo, id)
	var e: Dictionary = repo.entity(id) if repo != null else {}
	if e.is_empty():
		return id
	return String(e.get("index", e.get("name", id)))

# Nombre natural de una entidad para mostrar (listas, pies de recortes, selectores): su «name» sin el artículo inicial y
# con mayúscula («el doctor Watson» -> «Doctor Watson», «el Times del 27 de marzo» -> «Times del 27 de marzo»). Sin
# «name», la forma de índice.
const ARTICLES := ["el ", "la ", "los ", "las ", "un ", "una ", "unos ", "unas "]
static func display(repo, id: String) -> String:
	if repo == null:
		return id
	var e: Dictionary = repo.entity(id)
	if e.is_empty():
		return id
	var n := String(e.get("name", ""))
	if n == "":
		return String(e.get("index", id))
	for a in ARTICLES:
		if n.begins_with(a) and n.length() > a.length():
			n = n.substr(a.length())
			break
	return n.substr(0, 1).to_upper() + n.substr(1)

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
