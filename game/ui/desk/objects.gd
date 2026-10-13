# ui/desk/objects.gd — qué hace cada objeto del 3D al tocarlo (ARCHITECTURE §6.7). Dueño: W3-SHELL. Estática.
# Los vínculos objeto -> acción son DATOS: data/map.json "objects" {lugar|lámina: {nodo: {do, …}}} (comodín "*" al
# final del id de nodo; lugar "*" = cualquiera). Nada del caso en código.
#   do: tray · map · notebook · ledger · scissors · calendar · compose · sleep · catalog · frame {frame} ·
#       go {place, area} · leave · docs {via:[…], rest:bool}
# Documentos de un objeto (docs_for): vistas legibles ahora (q_accessible) cuya entidad de documento está entre las
# entidades del objeto (etiquetas e: y menciones de su examen), más las de las vías del vínculo (tome, shelf, counter,
# desk) y, con rest, los papeles de escritorio que ningún otro objeto reclama (lo que está suelto sobre la mesa).
# La bandeja tiene su propio panel: lo llegado por la bandeja no se repite como «suelto».
extends RefCounted

static func objects(repo) -> Dictionary:
	if repo == null or not repo.has_method("map"):
		return {}
	var o = repo.map().get("objects", {})
	return o if typeof(o) == TYPE_DICTIONARY else {}

static func _match(table: Dictionary, node: String) -> Dictionary:
	if table.has(node) and typeof(table[node]) == TYPE_DICTIONARY:
		return table[node]
	var keys: Array = table.keys()
	keys.sort()
	for k in keys:
		var ks := String(k)
		if ks.ends_with("*") and node.begins_with(ks.substr(0, ks.length() - 1)) and typeof(table[k]) == TYPE_DICTIONARY:
			return table[k]
	return {}

static func binding(repo, place: String, node: String) -> Dictionary:
	var o := objects(repo)
	var t = o.get(place, {})
	var b := _match(t, node) if typeof(t) == TYPE_DICTIONARY else {}
	var star = o.get("*", null)
	if b.is_empty() and typeof(star) == TYPE_DICTIONARY:
		b = _match(star, node)
	return b

# Entidades de un nodo: e: de sus etiquetas + menciones del examen.
static func node_ents(repo, node_def: Dictionary) -> Array:
	var out: Array = []
	for t in node_def.get("tags", []):
		var s := String(t)
		if s.begins_with("e:"):
			out.append(s.substr(2))
	for e in node_def.get("ents", []):
		if not out.has(String(e)):
			out.append(String(e))
	var ex := String(node_def.get("examine", ""))
	if ex != "" and repo != null:
		for m in repo.parse_text(ex).get("mentions", []):
			if not out.has(String(m.ent)):
				out.append(String(m.ent))
	return out

static func _tray_views(sim) -> Dictionary:
	var out := {}
	var day := int(sim.q_clock().get("day", 0))
	for d in range(0, day + 1):
		for it in sim.q_tray(d):
			out[String(it.view)] = true
	return out

static func _doc_entity(repo, sim, did: String) -> String:
	var d: Dictionary = repo.doc(did)
	if not d.is_empty():
		return String(d.get("entity", ""))
	return ""

# [{view, title}] (orden estable por título y vista).
static func docs_for(sim, repo, place_def: Dictionary, node_def: Dictionary, b: Dictionary) -> Array:
	if sim == null or repo == null:
		return []
	var ents := node_ents(repo, node_def)
	var vias: Array = b.get("via", []) if typeof(b.get("via", [])) == TYPE_ARRAY else []
	var rest := bool(b.get("rest", false))
	var tray := _tray_views(sim) if rest else {}
	var claimed := {}
	if rest:
		for n in place_def.get("nodes", []):
			if typeof(n) == TYPE_DICTIONARY and String(n.get("id", "")) != String(node_def.get("id", "")):
				for e in node_ents(repo, n):
					claimed[e] = true
	var out: Array = []
	var seen := {}
	for v in sim.q_accessible():
		var view := String(v.get("view", ""))
		var ent := _doc_entity(repo, sim, String(v.get("doc", "")))
		var hit := ent != "" and ents.has(ent)
		if not hit and vias.has(String(v.get("via", ""))):
			hit = true
			if String(v.get("via", "")) == "desk" and rest:
				hit = not tray.has(view) and not claimed.has(ent) and String(v.get("holder", "")) == "L1" and not view.begins_with("R.") and not view.begins_with("AD.")
		if hit and not seen.has(view):
			seen[view] = true
			out.append({"view": view, "title": String(v.get("title", view))})
	out.sort_custom(func(a, c):
		if String(a.title) != String(c.title):
			return String(a.title) < String(c.title)
		return String(a.view) < String(c.view))
	return out
