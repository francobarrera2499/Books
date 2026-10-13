# core/sim/reveal.gd — progresión del mundo (GDD_v2 §B.3–§B.5). Dueño: PROGRESIÓN.
# Un lugar del mapa se suma cuando Lisle se entera de él (lee, oye o recorta su nombre) o, a más tardar, a su hora
# garantizada (schedule.reveal.<L>.by). Nada se desbloquea por acertar: sólo por lo leído/oído/recortado y por el reloj.
# Lo revelado no se vuelve a cerrar (los horarios y cortes de siempre siguen valiendo aparte).
# st.world:
#   known:    {entidad: tk}            lo que Lisle vio (hojas leídas), oyó (líneas dichas) o recortó. NO es el índice: el
#                                      índice sigue creciendo sólo con recortes; `known` sólo decide el mapa.
#   read:     {vista: [partes]}        hojas mostradas por el lector (acción libre `read`, ciega: sin evento público)
#   revealed: {lugar: tk}              lugares de schedule.reveal ya sumados al mapa (L1 y los que no figuran: siempre)
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

static func learn(st, ents: Array, tk := -1) -> void:
	var k := _w(st, "known")
	var t := tk if tk >= 0 else now_tk(st)
	for e in ents:
		var s := String(e)
		if s != "" and not s.begins_with("act.") and not k.has(s):
			k[s] = t

static func learn_parsed(st, parsed, tk := -1) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var ents: Array = []
	for m in parsed.get("mentions", []):
		if typeof(m) == TYPE_DICTIONARY:
			ents.append(String(m.get("ent", "")))
	learn(st, ents, tk)

# Línea dicha (escena, diálogo, confrontación): lo nombrado se «oye».
static func hear(st, repo, text: String, act := "") -> void:
	if text.strip_edges() == "":
		return
	learn_parsed(st, repo.parse_text(text, {}, act))

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
			learn_parsed(st, b.get("parsed", {}))
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
		var by := TimeKey.of(s.get("by", ""))
		if by >= 0 and t >= by:
			hit = true
		if not hit:
			for e in s.get("ents", []):
				if known.has(String(e)):
					hit = true
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
			rv[L] = t
			out.append(String(L))
			st.note("map", {"revealed": String(L)})
	return out

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
