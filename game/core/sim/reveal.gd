# core/sim/reveal.gd — progresión del mundo (GDD_v2 §B.3–§B.5). Dueño: PROGRESIÓN.
# Un lugar del mapa se suma cuando Lisle se entera de él (lee, oye o recorta su nombre) o, a más tardar, a su hora
# garantizada (schedule.reveal.<L>.by). Nada se desbloquea por acertar: sólo por lo leído/oído/recortado y por el reloj.
# Lo revelado no se vuelve a cerrar (los horarios y cortes de siempre siguen valiendo aparte).
# st.world:
#   known:    {entidad: tk}            lo que Lisle vio (hojas leídas), oyó (líneas dichas) o recortó. NO es el índice: el
#                                      índice sigue creciendo sólo con recortes; `known` sólo decide el mapa.
#   read:     {vista: [partes]}        hojas mostradas por el lector (acción libre `read`, ciega: sin evento público)
#   revealed: {lugar: tk}              lugares de schedule.reveal ya sumados al mapa (L1 y los que no figuran: siempre)
#   known_via:    {entidad: {via, ref}}  cómo se enteró (GDD_v3 §5.3): leer (ref = documento) | oir (ref = personaje)
#   revealed_via: {lugar: {via, ref}}    por qué apareció en el plano: leer | oir | crane (ref = ítem donde.*) | garantia
# why(st, repo, L) -> {via, ref, text} (q_places().por_que): «Lo menciona: «<título>».» · «Lo dijo <nombre>.» ·
#   «Me lo dijo Crane.» · la línea plano.por_que.<L> (garantía de hora). reveal(st, repo, L, via) lo usa Crane (§5.2).
# schedule.reveal.<L> = {by: tk (garantía), ents?: [cualquiera], ents_all?: [todas], areas?: [áreas a las que se limita
#   la garantía en el grafo]}. El grafo (Availability) usa SÓLO `by`; los disparadores anticipados sólo suman franjas.
# Sin preload de world_model/clock (no hay ciclos): recibe lo leído ya parseado.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")

const HOME := "L1"

static func init_state(st, repo) -> void:
	st.world["known"] = {}
	st.world["read"] = {}
	st.world["revealed"] = {}
	st.world["known_via"] = {}
	st.world["revealed_via"] = {}

static func spec(repo) -> Dictionary:
	var r = repo.schedule().get("reveal", {}) if repo != null else {}
	return r if typeof(r) == TYPE_DICTIONARY else {}

static func _w(st, k: String) -> Dictionary:
	var d = st.world.get(k)
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
		st.world[k] = d
	return d

static func now_tk(st) -> int:
	if int(st.now_tk) >= 0:
		return int(st.now_tk)
	return TimeKey.tk(int(st.clock.get("day", 0)), String(st.clock.get("slot", "N")))

# ¿El lugar ya está en el mapa? (L1 y lo que no figura en schedule.reveal: siempre.)
static func place_known(st, repo, place: String) -> bool:
	if place == HOME or place == "":
		return true
	var sp := spec(repo)
	if not sp.has(place):
		return true
	return _w(st, "revealed").has(place)

static func revealed_tk(st, repo, place: String) -> int:
	if place == HOME or not spec(repo).has(place):
		return -1
	return int(_w(st, "revealed").get(place, -1))

static func is_known(st, ent: String) -> bool:
	return _w(st, "known").has(ent)

# via: {via: "leer"|"oir", ref} (por qué apareció un lugar, §5.3); vacío = sin fuente nombrable.
static func learn(st, ents: Array, tk := -1, via := {}) -> void:
	var k := _w(st, "known")
	var kv := _w(st, "known_via")
	var t := tk if tk >= 0 else now_tk(st)
	for e in ents:
		var s := String(e)
		if s != "" and not s.begins_with("act.") and not k.has(s):
			k[s] = t
			if not via.is_empty():
				kv[s] = via.duplicate()

static func learn_parsed(st, parsed, tk := -1, via := {}) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ents: Array = []
	for m in parsed.get("mentions", []):
		if typeof(m) == TYPE_DICTIONARY:
			ents.append(String(m.get("ent", "")))
	learn(st, ents, tk, via)

# Línea dicha (escena, diálogo, confrontación): lo nombrado se «oye».
static func hear(st, repo, text: String, act := "", who := "") -> void:
	if text.strip_edges() == "":
		return
	learn_parsed(st, repo.parse_text(text, {}, act), -1, {"via": "oir", "ref": who} if who != "" else {})

# Acción `read` {view, part}: la vista ya validada por el llamador (WorldModel.view) -> páginas.
static func act_read(st, repo, a: Dictionary, v: Dictionary) -> Dictionary:
	if v.is_empty():
		return {"ok": false, "err": "inaccesible"}
	var pages: Array = v.get("pages", [])
	var part := int(a.get("part", 0))
	if part < 0 or part >= pages.size():
		return {"ok": false, "err": "parte"}
	var view := String(a.get("view", ""))
	var rd := _w(st, "read")
	var parts: Array = rd.get(view, [])
	var first := not parts.has(part)
	if first:
		parts.append(part)
		parts.sort()
		rd[view] = parts
	for b in pages[part]:
		if typeof(b) == TYPE_DICTIONARY:
			learn_parsed(st, b.get("parsed", {}), -1, {"via": "leer", "ref": String(v.get("doc", b.get("doc", ""))), "title": String(v.get("title", ""))})
	update(st, repo)
	return {"ok": true, "first": first}

static func was_read(st, view: String) -> bool:
	return not (_w(st, "read").get(view, []) as Array).is_empty()

# Revela lo que corresponda ahora (después de cada apply y en cada tk cruzado). Devuelve los lugares revelados.
static func update(st, repo, tk := -1) -> Array:
	var sp := spec(repo)
	if sp.is_empty():
		return []
	var t := tk if tk >= 0 else now_tk(st)
	var rv := _w(st, "revealed")
	var known := _w(st, "known")
	var out: Array = []
	var ids: Array = sp.keys()
	ids.sort()
	for L in ids:
		if rv.has(L) or String(L).begins_with("_"):
			continue
		var s = sp[L]
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var hit := false
		var via := {}
		for e in s.get("ents", []):
			if known.has(String(e)):
				hit = true
				via = _via_of(st, [String(e)])
				break
		if not hit:
			var all: Array = s.get("ents_all", [])
			if not all.is_empty():
				hit = true
				for e in all:
					if not known.has(String(e)):
						hit = false
						break
				if hit:
					via = _via_of(st, all)
		var by := TimeKey.of(s.get("by", ""))
		if not hit and by >= 0 and t >= by:
			hit = true
			via = {"via": "garantia", "ref": String(L)}
		if hit:
			rv[L] = t
			if via.is_empty():
				via = {"via": "garantia", "ref": String(L)}
			_w(st, "revealed_via")[L] = via
			out.append(String(L))
			st.note("map", {"revealed": String(L)})
	return out

# La fuente (la más tardía: la que completó el disparo) de un conjunto de entidades ya sabidas.
static func _via_of(st, ents: Array) -> Dictionary:
	var known := _w(st, "known")
	var kv := _w(st, "known_via")
	var best := {}
	var bt := -1
	for e in ents:
		var s := String(e)
		if known.has(s) and int(known[s]) >= bt and kv.has(s):
			bt = int(known[s])
			best = kv[s]
	return best.duplicate()

# Revela un lugar por otra vía (Crane, GDD_v3 §5.2). Devuelve true si no estaba en el plano.
static func reveal(st, repo, place: String, via: Dictionary) -> bool:
	if place_known(st, repo, place):
		return false
	_w(st, "revealed")[place] = now_tk(st)
	_w(st, "revealed_via")[place] = via.duplicate()
	st.note("map", {"revealed": place})
	return true

# Por qué está un lugar en el plano (q_places().por_que): {via, ref, text}; L1 y lo que no figura en el plan: {}.
static func why(st, repo, place: String) -> Dictionary:
	if place == HOME or not spec(repo).has(place) or not place_known(st, repo, place):
		return {}
	var v: Dictionary = _w(st, "revealed_via").get(place, {"via": "garantia", "ref": place})
	var via := String(v.get("via", "garantia"))
	var text := ""
	match via:
		"leer":
			var title := String(v.get("title", ""))
			if title == "":
				title = String(repo.doc(String(v.get("ref", ""))).get("title", v.get("ref", "")))
			# un título que ya trae sus comillas («El intérprete griego», The Strand…) no se vuelve a envolver (playtest v3)
			var tq := title if title.begins_with("«") else "«%s»" % title
			text = _t(repo, "v3core.por_que.leer", {"titulo": tq}, "Lo menciona: %s." % tq)
		"oir":
			var who := String(v.get("ref", ""))
			var name := String(repo.dialogue(who).get("label", repo.entity(who).get("name", who)))
			text = _t(repo, "v3core.por_que.oir", {"quien": name}, "Lo dijo %s." % name)
		"crane":
			text = _t(repo, "v3core.por_que.crane", {}, "Me lo dijo Crane.")
		_:
			text = _t(repo, "plano.por_que." + place, {}, "")
	return {"via": via, "ref": String(v.get("ref", "")), "text": text}

static func _t(repo, key: String, vars: Dictionary, def: String) -> String:
	var s: String = repo.text(key, vars)
	return def if s == key else s

# Lugares revelados el día `day` (sello «Nuevo» del mapa y línea de Pendientes). Orden por id. Lo revelado en el
# prólogo (día 0, sin mapa) cuenta como nuevo el día 1, cuando se ve el mapa por primera vez.
static func revealed_on(st, repo, day: int) -> Array:
	var out: Array = []
	var rv := _w(st, "revealed")
	var ids: Array = rv.keys()
	ids.sort()
	for L in ids:
		var d := TimeKey.day_of(int(rv[L]))
		if d == day or (day == 1 and d == TimeKey.DAY_P):
			out.append(String(L))
	return out
