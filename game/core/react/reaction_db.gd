# core/react/reaction_db.gd — índice y gramática de data/reactions/*.json (§4.9, GDD§9.1). Dueño: W2-REACT.
# compile(repo) se cachea en repo.cache["react_db"]. Expone además el motor genérico de disparo que usan HolmesAgent,
# MoranAgent y Director (collect), la selección de rastro, las variables de plantilla y un lint de gramática.
#
# GRAMÁTICA QUE INTERPRETA EL MOTOR (contrato operativo para W2-STRUCT; ejemplo completo: tests/fixtures/react/data/)
# disparador.evento   tipo | [tipos]. Públicos (§3.6): go slip say show pay task ad telegram letter order_copy report.
#                     Internos: "tiempo" (+ tk; también schedule.column), "reaccion" (entrega de otra reacción: campos
#                     rid iid voice lado channel how reply_to_ad soft copies day), "inactividad" (HB13: campo slots).
# disparador.match    {campo: valor | [valores]} (AND). Claves especiales:
#   any: [match, …]             OR de sub-matches
#   topic_group: g | [g]        slip: lists.slip_topics[topic] ∈ g; say/show: topic, bait_topic, canary o alguna entidad
#                               visible ∈ lists.topic_groups[g]
#   bait | canary | to_s: bool  presencia de bait_topic | canary | to_s
#   says_alive: bool            ev.says_alive, afirmación de kind "vive"/says_alive, o algo visible del grupo "vive"
#   cat: c | [c]                report: algún items[].cats contiene alguna (show: item.cats si el emisor las incluye)
#   doc: d | [d]                ev.doc o algún item.doc_ids
#   ent: e | [e]                alguna entidad visible (ents, item.ents, valores de item.entry_values, topic)
#   ad: "AD:prologo"            el aviso del prólogo (ev.ad "AD:prologo"/"AD.prologo", ev.prologue, o primer aviso publicado
#                               el día schedule.ads.prologue_pub_day)
#   channel | sensor            de la observación (Sensors)
#   otro campo                  igualdad (pertenencia si el valor pedido es lista) contra lo observado (obs.content), la
#                               observación o el evento/ev.item (Moran y respuestas, que no pasan por sensores)
# disparador.una_vez_por [campos]   una instancia por combinación de valores; ["*"] = una sola vez en la partida
# disparador.contador "campo" | "nombre:campo" | "nombre:"   contador compartido por nombre; clave "nombre=valor(campo)".
#                     Se incrementa UNA vez por evento si el evento pasa el match de alguna regla que lo usa.
# disparador.n_in [n…] | n_gte n    valor del contador (ya incrementado) con el que dispara
# disparador.acumula "dia"           mientras la instancia sigue en cola, otra observación del mismo día se suma a su
#                                    ancla (anchor.itinerary; HA3: «Kensington a las diez, el Strand a las tres»)
# disparador.relacion [{si: match, copias: [ejemplar…]} | {mostrado: true}]   v3 (HA5/HA6, GDD_v3 §4.2): la regla sólo
#                     dispara si hay en casa un original P relacionado con el acto (la primera entrada cuyo `si` pasa,
#                     el primer ejemplar en casa; {mostrado}: el original del recorte mostrado); queda en anchor.relacionada
#                     (efectos retirar/devolver copias "relacionada", corta copias "relacionada"). Sin original, no dispara
#                     ni gasta su una_vez_por.
# latencia intrusion (v3)            K-BM/K-T: en esa salida (Director.on_leave); K-W/K-H: (D+1).M; si no sale, de noche
# garantizada_si {canal, n}          garantizada si la observación es de ese canal y el contador vale n: no la bloquean
#                                    condiciones, canal cerrado ni watson_expuesto (T15)
# tipo garantizada_por_acto          ídem (sus condiciones sólo pueden ser de calendario: T15)
# condiciones        DSL §4.18; ctx {st, repo, ev, anchor, tk, counters:{n}}; contadores del motor en st.react.counters:
#                    "fired.<rid>" (instancias creadas), "delivered.<rid>", "moran.respuesta_s" y las claves de contador
# efecto[] filtros   si_canal (c|[c]), si_n (n|[n]), si_cond (DSL), resultado (sólo si anchor.resultado coincide; si no,
#                    no se aplica: HB12 lo resuelve Dialogue); carta: entrega (correo|en_mano|mostrador_crane|lugar:Lx;
#                    se pasa tal cual a WorldModel.deliver), firma, title, plantilla_por, copia_de (campo del ancla →
#                    meta.copia_de); cerrar target "canal:*" y corta acceso "canal:*" = canal de la instancia;
#                    v3: alterar_lugar dias (la variante dura hasta el amanecer de día+dias; conviven); devolver al
#                    "amanecer" + marca {texto, mano} (vuelve solo al amanecer siguiente, con la marca al margen);
#                    silueta desde: día | "d.S" | "+n" (relativo a la entrega); linea_siguiente_comunicacion tpl: rastro.
# rastro[] elección  sólo rastros con texto (texto|tono): when (DSL) → tpl == ancla[plantilla_por] →
#                    "<valor del contador>.<n>" → "<valor del contador>" → topic/bait_topic/canary → "<n>" (sólo con
#                    contador) → código de canal ("kbm") → id de canal ("K-BM") → único → "texto"/"default" →
#                    Det.pick(seed, [rid, iid, día]). tono {alto, bajo}: alternativa por confianza de Holmes.
#                    Rastros con nodo (N:/S:/L:/M:): fragmentos de otros dueños; se registran TODOS los que pasan when
#                    (st.react.world.nodes; los N: los ve WorldModel.snapshot vía Effects.extra_nodes).
#                    Placeholders: ${seat} ${title} ${hour} ${hora} ${phrase} ${text} ${streets} ${itinerario} ${act_day}
#                    ${act_date} ${ch} ${addr} ${n} ${topic} ${channel}. [[@act|…]] = entidad del acto ancla.
# lado/voz           voz A exige obs.to_mycroft; voz B obs.to_holmes; lado mycroft obs.to_mycroft; lado holmes to_holmes.
#                    lado moran: MoranAgent (sin sensores de Holmes). lado respuesta: ciego (D27, D28).
# tipo columna       ocurre aunque el jugador no haga nada: por tiempo (schedule.column / evento tiempo) o por un acto
#                    (HC06 al entrar en la Sala de Forasteros): el Director la evalúa sobre el evento crudo, sin canales.
extends RefCounted

const L = preload("res://core/util/log.gd")
const J = preload("res://core/util/j.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Det = preload("res://core/util/det.gd")
const Markup = preload("res://core/text/markup.gd")

const PUBLIC_EVENTS := ["go", "slip", "say", "show", "pay", "task", "ad", "telegram", "letter", "order_copy", "report"]
const INTERNAL_EVENTS := ["tiempo", "reaccion", "inactividad"]
const CHANNELS := ["K-T", "K-BM", "K-W", "K-H", "K-S"]
const LATENCIES := ["voz_a", "voz_b", "fija", "inmediata", "siguiente_salida", "siguiente_comunicacion", "dias", "intrusion"]
const DOC_OPS := ["carta", "columna", "noticia"]
const CUT_OPS := ["retirar", "cerrar", "arrancar"]
const MATCH_SPECIAL := ["any", "topic_group", "bait", "canary", "says_alive", "to_s", "cat", "doc", "ent", "ad", "channel", "sensor"]
const DISP_KEYS := ["evento", "match", "una_vez_por", "contador", "n_in", "n_gte", "tk", "acumula", "relacion"]
# v3 (GDD_v3 §4.2): dónde está «en casa» un original P (estante de la pieza); los demás holders no son de Lisle.
const HOME_HOLDERS := ["L1", "tomo"]
const EFFECT_FILTERS := ["si_canal", "si_n", "si_cond"]
const COMMON_EV := ["type", "tk", "day", "slot", "seq", "act"]
const ANCHOR_FIELDS := ["place", "area", "char", "kind", "topic", "assertion", "bait_topic", "canary", "doc", "title", "seat",
	"hour", "phrase", "text", "streets", "ad", "form", "to", "n", "rid", "iid", "voice", "how", "channel", "task", "amount_d",
	"to_s", "says_alive", "pub_day", "mode", "slots", "copies", "reply_to_ad", "soft", "privado_kw", "relacionada"]
const HOURS := ["doce", "una", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once"]
# variables que vars_for define para los rastros
const VARS := ["seat", "title", "hour", "hora", "phrase", "text", "topic", "n", "form", "to", "task", "amount_d", "place",
	"channel", "ch", "streets", "itinerario", "addr", "act_day", "act_date"]

# ---------------- índice ----------------
static func _empty() -> Dictionary:
	return {"ids": [], "by_event": {}, "time": {}}

static func compile(repo) -> Dictionary:
	if repo == null:
		return _empty()
	var c = repo.cache.get("react_db")
	if c != null:
		return c
	var db := _empty()
	for r in repo.reactions():
		var id := String(r.get("id", ""))
		if id == "":
			continue
		db.ids.append(id)
		for e in evento_list(r):
			if not db.by_event.has(e):
				db.by_event[e] = []
			db.by_event[e].append(id)
		if evento_list(r).has("tiempo"):
			var d = r.get("disparador", {})
			var lat = r.get("latencia", {})
			var t := TimeKey.of(d.get("tk", lat.get("tk", "")) if typeof(d) == TYPE_DICTIONARY else "")
			if t >= 0:
				_add_time(db, t, id)
	for e in repo.schedule().get("column", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var t2 := TimeKey.of(e.get("tk", ""))
		if t2 >= 0 and String(e.get("r", "")) != "":
			_add_time(db, t2, String(e.r))
	repo.cache["react_db"] = db
	return db

static func _add_time(db: Dictionary, t: int, id: String) -> void:
	var k := str(t)
	if not db.time.has(k):
		db.time[k] = []
	if not db.time[k].has(id):
		db.time[k].append(id)

static func candidates(repo, ev_type: String) -> Array:
	var db := compile(repo)
	var out: Array = []
	for id in db.by_event.get(ev_type, []):
		var r: Dictionary = repo.reaction(id)
		if not r.is_empty():
			out.append(r)
	return out

static func time_rids(repo, t: int) -> Array:
	return compile(repo).time.get(str(t), [])

# ---------------- accesores de regla ----------------
static func evento_list(rule: Dictionary) -> Array:
	var d = rule.get("disparador", {})
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var e = d.get("evento", [])
	if typeof(e) == TYPE_ARRAY:
		var out: Array = []
		for x in e:
			out.append(String(x))
		return out
	return [String(e)] if String(e) != "" else []

static func disp(rule: Dictionary) -> Dictionary:
	var d = rule.get("disparador", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func latency_type(rule: Dictionary) -> String:
	var l = rule.get("latencia", {})
	return String(l.get("tipo", "")) if typeof(l) == TYPE_DICTIONARY else ""

static func voice(rule: Dictionary) -> String:
	return String(rule.get("voz", "")).to_upper()

static func lado(rule: Dictionary) -> String:
	return String(rule.get("lado", ""))

static func is_column(rule: Dictionary) -> bool:
	return String(rule.get("tipo", "")) == "columna"

static func is_optional(rule: Dictionary) -> bool:
	return String(rule.get("tipo", "")) == "opcional"

# prio §5.3: 0 columna · 1 voz B · 2 voz A · 3 Moran · 4 respuestas
static func prio(rule: Dictionary) -> int:
	if is_column(rule):
		return 0
	if lado(rule) == "respuesta" or String(rule.get("tipo", "")) == "respuesta":
		return 4
	if lado(rule) == "moran":
		return 3
	if voice(rule) == "B":
		return 1
	return 2

# D2: fuerte = nivel ≥ 3 ∧ tipo ≠ columna ∧ ¬exento (exento_d2; exento_d2_desde_dia ≤ día; toda voz B)
static func is_strong(rule: Dictionary, day: int) -> bool:
	if int(rule.get("nivel", 0)) < 3 or is_column(rule):
		return false
	if bool(rule.get("exento_d2", false)) or voice(rule) == "B":
		return false
	if rule.has("exento_d2_desde_dia") and rule.exento_d2_desde_dia != null and day >= int(rule.exento_d2_desde_dia):
		return false
	return true

# "K-BM" → "kbm" (código de lists.medios[].ch y de las etiquetas acto_*/ancla_*)
static func ch_code(channel: String) -> String:
	return channel.replace("-", "").to_lower()

# ---------------- campos observados ----------------
# Con observación (lado Holmes/Mycroft) sólo se ve obs.content, la observación y los campos comunes del evento.
static func field(ev: Dictionary, obs, name: String):
	if obs != null:
		var c = obs.get("content", {})
		if typeof(c) == TYPE_DICTIONARY and c.has(name):
			return c[name]
		if obs.has(name) and not name.begins_with("_") and name != "content":
			return obs[name]
		if typeof(c) == TYPE_DICTIONARY and typeof(c.get("item")) == TYPE_DICTIONARY and c.item.has(name):
			return c.item[name]
		if COMMON_EV.has(name):
			return ev.get(name)
		return null
	if ev.has(name):
		return ev[name]
	if typeof(ev.get("item")) == TYPE_DICTIONARY and ev.item.has(name):
		return ev.item[name]
	return null

static func _src(ev: Dictionary, obs) -> Dictionary:
	if obs != null:
		var c = obs.get("content", {})
		var out: Dictionary = c.duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
		for k in COMMON_EV:
			if ev.has(k) and not out.has(k):
				out[k] = ev[k]
		return out
	return ev

static func _as_arr(v) -> Array:
	if v == null:
		return []
	if typeof(v) == TYPE_ARRAY:
		return v
	return [v]

static func _s(v) -> String:
	if v == null:
		return ""
	if typeof(v) == TYPE_FLOAT and v == floorf(v):
		return str(int(v))
	if typeof(v) == TYPE_ARRAY:
		var ps := PackedStringArray()
		for x in v:
			ps.append(_s(x))
		return ",".join(ps)
	return str(v)

static func _same(a, b) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if typeof(a) == TYPE_STRING_NAME:
		a = String(a)
	if typeof(b) == TYPE_STRING_NAME:
		b = String(b)
	if typeof(a) != typeof(b):
		return false
	return a == b

static func visible_ents(src: Dictionary) -> Array:
	var out: Array = []
	for e in _as_arr(src.get("ents")):
		if not out.has(e):
			out.append(e)
	var it = src.get("item")
	if typeof(it) == TYPE_DICTIONARY:
		for e in _as_arr(it.get("ents")):
			if not out.has(e):
				out.append(e)
		for v in _entry_values(it.get("entry_values")):
			if not out.has(v):
				out.append(v)
	for f in ["topic", "bait_topic", "canary"]:
		var t = src.get(f)
		if t != null and String(t) != "" and not out.has(String(t)):
			out.append(String(t))
	return out

static func _entry_values(ev_vals) -> Array:
	var out: Array = []
	match typeof(ev_vals):
		TYPE_DICTIONARY:
			var ks: Array = ev_vals.keys()
			ks.sort()
			for k in ks:
				for x in _entry_values(ev_vals[k]):
					out.append(x)
		TYPE_ARRAY:
			for x in ev_vals:
				for y in _entry_values(x):
					out.append(y)
		TYPE_STRING, TYPE_STRING_NAME:
			if String(ev_vals) != "":
				out.append(String(ev_vals))
	return out

static func docs_of(src: Dictionary) -> Array:
	var out: Array = []
	if src.get("doc") != null and String(src.doc) != "":
		out.append(String(src.doc))
	var it = src.get("item")
	if typeof(it) == TYPE_DICTIONARY:
		for d in _as_arr(it.get("doc_ids")):
			if not out.has(d):
				out.append(d)
	return out

static func cats_of(src: Dictionary) -> Array:
	var out: Array = []
	for it in _as_arr(src.get("items")):
		if typeof(it) == TYPE_DICTIONARY:
			for c in _as_arr(it.get("cats")):
				if not out.has(c):
					out.append(c)
	var it2 = src.get("item")
	if typeof(it2) == TYPE_DICTIONARY:
		for c in _as_arr(it2.get("cats")):
			if not out.has(c):
				out.append(c)
	for c in _as_arr(src.get("cats")):
		if not out.has(c):
			out.append(c)
	return out

static func assertion(repo, id) -> Dictionary:
	if repo == null or id == null:
		return {}
	for a in repo.lists().get("assertions", []):
		if typeof(a) == TYPE_DICTIONARY and String(a.get("id", "")) == String(id):
			return a
	return {}

static func groups_hit(repo, src: Dictionary, groups: Array) -> Array:
	var tg: Dictionary = repo.lists().get("topic_groups", {}) if repo != null else {}
	var vals := visible_ents(src)
	var out: Array = []
	for g in groups:
		var members: Array = tg.get(String(g), [])
		for v in vals:
			if members.has(v) or String(v) == String(g):
				out.append(String(g))
				break
	return out

static func says_alive(repo, src: Dictionary) -> bool:
	if bool(src.get("says_alive", false)):
		return true
	var a := assertion(repo, src.get("assertion"))
	if not a.is_empty() and (bool(a.get("says_alive", false)) or String(a.get("kind", "")) == "vive"):
		return true
	return not groups_hit(repo, src, ["vive"]).is_empty()

static func is_prologue_ad(repo, src: Dictionary, st = null) -> bool:
	if String(src.get("type", "ad")) != "ad":
		return false
	var a := String(src.get("ad", ""))
	if a == "AD:prologo" or a == "AD.prologo" or bool(src.get("prologue", false)):
		return true
	var pd := 1
	if repo != null:
		pd = int(repo.schedule().get("ads", {}).get("prologue_pub_day", 1))
	if int(src.get("pub_day", src.get("day", -1))) != pd:
		return false
	# primer aviso publicado ese día
	if st != null:
		for e in st.events:
			if typeof(e) == TYPE_DICTIONARY and String(e.get("type", "")) == "ad":
				return int(e.get("seq", -1)) == int(src.get("seq", -2))
	return true

# ---------------- match ----------------
static func match_ok(repo, m, ev: Dictionary, obs, st = null) -> bool:
	if m == null or typeof(m) != TYPE_DICTIONARY:
		return true
	var keys: Array = m.keys()
	keys.sort()
	for k in keys:
		var ks := String(k)
		if ks.begins_with("_"):
			continue
		if not _match_one(repo, ks, m[k], ev, obs, st):
			return false
	return true

static func _match_one(repo, k: String, want, ev: Dictionary, obs, st) -> bool:
	var src := _src(ev, obs)
	match k:
		"any":
			for sub in _as_arr(want):
				if match_ok(repo, sub, ev, obs, st):
					return true
			return false
		"topic_group":
			var gs := _as_arr(want)
			if String(src.get("type", ev.get("type", ""))) == "slip":
				var sg := String(repo.lists().get("slip_topics", {}).get(String(src.get("topic", "")), ""))
				for g in gs:
					if String(g) == sg:
						return true
				return false
			return not groups_hit(repo, src, gs).is_empty()
		"bait":
			return (_s(field(ev, obs, "bait_topic")) != "") == bool(want)
		"canary":
			var cv = field(ev, obs, "canary")
			var has := cv != null and typeof(cv) != TYPE_BOOL and _s(cv) != ""
			if typeof(cv) == TYPE_BOOL:
				has = cv
			return has == bool(want)
		"to_s":
			return bool(field(ev, obs, "to_s") if field(ev, obs, "to_s") != null else false) == bool(want)
		"says_alive":
			return says_alive(repo, src) == bool(want)
		"cat":
			var cats := cats_of(src)
			for c in _as_arr(want):
				if cats.has(c):
					return true
			return false
		"doc":
			var ds := docs_of(src)
			for d in _as_arr(want):
				if ds.has(d):
					return true
			return false
		"ent":
			var es := visible_ents(src)
			for e in _as_arr(want):
				if es.has(e):
					return true
			return false
		"ad":
			if String(want) == "AD:prologo":
				return is_prologue_ad(repo, src, st)
			return _s(src.get("ad")) == String(want)
		"channel", "sensor":
			var got = obs.get(k) if obs != null else src.get(k)
			for w in _as_arr(want):
				if _s(got) == String(w):
					return true
			return false
	var v = field(ev, obs, k)
	if typeof(want) == TYPE_ARRAY:
		if typeof(v) == TYPE_ARRAY:
			for x in v:
				for w in want:
					if _same(x, w):
						return true
			return false
		for w in want:
			if _same(v, w):
				return true
		return false
	if typeof(v) == TYPE_ARRAY:
		for x in v:
			if _same(x, want):
				return true
		return false
	return _same(v, want)

# ---------------- lado, canal, contadores ----------------
static func side_ok(rule: Dictionary, obs: Dictionary) -> bool:
	var v := voice(rule)
	if v == "A":
		return bool(obs.get("to_mycroft", false))
	if v == "B":
		return bool(obs.get("to_holmes", false))
	if lado(rule) == "mycroft":
		return bool(obs.get("to_mycroft", false))
	return bool(obs.get("to_holmes", false))

static func channel_ok(rule: Dictionary, obs: Dictionary) -> bool:
	var c := String(rule.get("canal", ""))
	if CHANNELS.has(c):
		return String(obs.get("channel", "")) == c
	return true

static func inst_channel(rule: Dictionary, obs) -> String:
	var c := String(rule.get("canal", ""))
	if CHANNELS.has(c):
		return c
	if obs != null and (c == "*" or c == ""):
		return String(obs.get("channel", ""))
	return c

static func counter_spec(rule: Dictionary) -> Dictionary:
	var c = disp(rule).get("contador", "")
	if typeof(c) != TYPE_STRING or String(c) == "":
		return {}
	var s := String(c)
	if s.contains(":"):
		return {"name": s.get_slice(":", 0), "field": s.substr(s.find(":") + 1)}
	return {"name": s, "field": s}

static func counter_key(rule: Dictionary, ev: Dictionary, obs) -> String:
	var sp := counter_spec(rule)
	if sp.is_empty():
		return ""
	var v = "" if String(sp.field) == "" else field(ev, obs, String(sp.field))
	return "%s=%s" % [sp.name, _s(v)]

static func counter_value_field(rule: Dictionary) -> String:
	var sp := counter_spec(rule)
	return "" if sp.is_empty() else String(sp.field)

static func bump(st, key: String) -> int:
	var cs: Dictionary = st.react.counters
	cs[key] = int(cs.get(key, 0)) + 1
	return int(cs[key])

static func n_ok(rule: Dictionary, n: int) -> bool:
	var d := disp(rule)
	if d.has("n_in") and typeof(d.n_in) == TYPE_ARRAY and not d.n_in.is_empty():
		var hit := false
		for x in d.n_in:
			if int(x) == n:
				hit = true
		if not hit:
			return false
	if d.has("n_gte") and n < int(d.n_gte):
		return false
	return true

static func once_key(rule: Dictionary, ev: Dictionary, obs) -> String:
	var u = disp(rule).get("una_vez_por", null)
	if typeof(u) != TYPE_ARRAY or u.is_empty():
		return ""
	var rid := String(rule.get("id", ""))
	if u.has("*"):
		return rid + "|*"
	var ps := PackedStringArray()
	for f in u:
		ps.append("%s=%s" % [f, _s(field(ev, obs, String(f)))])
	return rid + "|" + "|".join(ps)

static func is_guaranteed(rule: Dictionary, obs, n: int) -> bool:
	if String(rule.get("tipo", "")) == "garantizada_por_acto":
		return true
	return garantizada_si_ok(rule, obs, n)

static func garantizada_si_ok(rule: Dictionary, obs, n: int) -> bool:
	var g = rule.get("garantizada_si")
	if typeof(g) != TYPE_DICTIONARY or g.is_empty() or obs == null:
		return false
	if g.has("canal") and String(obs.get("channel", "")) != String(g.canal):
		return false
	if g.has("n") and n != int(g.n):
		return false
	return true

static func _flag(st, name: String) -> bool:
	var v = st.flags.get(name)
	match typeof(v):
		TYPE_NIL: return false
		TYPE_BOOL: return v
		TYPE_INT, TYPE_FLOAT: return v != 0
		TYPE_STRING: return String(v) != ""
	return true

# ---------------- motor genérico de disparo ----------------
# Devuelve candidatas {rid, channel, anchor, n, guaranteed, once, src_ev, act_tk, imm, counter} (o accumulate_into).
# mode: "all" | "queue" (sin inmediatas) | "imm" (sólo inmediatas). bumped: claves de contador ya incrementadas por
# este evento (compartido entre las observaciones del mismo evento y con Director.immediate).
# col_mode: "exclude" (agentes: las reacciones de columna no dependen de canales) | "only" (pasada del Director sobre el
# evento crudo: columnas disparadas por un acto, p. ej. HC06 al entrar en la Sala de Forasteros).
# ev.reaction | ev._reaction (Dialogue → Director.immediate: resultado especial ya decidido, p. ej. M4 ante Pell) da por cumplido el match
# de esa regla (no el lado ni el canal).
static func collect(st, repo, ev: Dictionary, obs, sides: Array, bumped: Dictionary, mode := "all", skip := [], col_mode := "exclude") -> Array:
	var out: Array = []
	var et := String(ev.get("type", ""))
	var forced := String(ev.get("reaction", ev.get("_reaction", "")))
	var matched: Array = []
	for rule in candidates(repo, et):
		var rid := String(rule.get("id", ""))
		if skip.has(rid) or not sides.has(lado(rule)):
			continue
		if (col_mode == "exclude" and is_column(rule)) or (col_mode == "only" and not is_column(rule)):
			continue
		var imm := latency_type(rule) == "inmediata"
		if (mode == "queue" and imm) or (mode == "imm" and not imm):
			continue
		if obs != null and (not side_ok(rule, obs) or not channel_ok(rule, obs)):
			continue
		if forced != rid and not match_ok(repo, disp(rule).get("match", {}), ev, obs, st):
			continue
		matched.append(rule)
	var nmap := {}
	for rule in matched:
		var key := counter_key(rule, ev, obs)
		if key == "":
			continue
		if not bumped.has(key):
			bumped[key] = bump(st, key)
		nmap[String(rule.id)] = int(bumped[key])
	for rule in matched:
		var rid := String(rule.id)
		if String(rule.get("tipo", "")) == "silencio":
			continue
		var n := int(nmap.get(rid, 0))
		if not n_ok(rule, n):
			continue
		var g := is_guaranteed(rule, obs, n)
		var gsi := garantizada_si_ok(rule, obs, n)
		var channel := inst_channel(rule, obs)
		if not g:
			if is_optional(rule) and CHANNELS.has(channel) and _flag(st, "canal_cerrado." + channel):
				continue
			if voice(rule) == "B" and _flag(st, "watson_expuesto") and rid != "HB10":
				continue
		var anchor := build_anchor(repo, rule, ev, obs)
		if not gsi:
			var ctx := {"st": st, "repo": repo, "ev": _src(ev, obs), "anchor": anchor, "tk": int(ev.get("tk", 0)), "counters": {"n": n}}
			if not Cond.eval(rule.get("condiciones", {}), ctx):
				continue
		# v3 (GDD_v3 §4.2): HA5/HA6 sólo si hay en casa un original P relacionado con el acto (se lleva ése)
		if disp(rule).has("relacion"):
			var rel := relacion_copy(st, repo, rule, ev, obs)
			if rel == "":
				continue
			anchor["relacionada"] = [rel]
		var ok := once_key(rule, ev, obs)
		if ok != "" and st.react.once.has(ok):
			if String(disp(rule).get("acumula", "")) == "dia":
				var into := _queued_same_day(st, rid, int(ev.get("day", TimeKey.day_of(int(ev.get("tk", 0))))))
				if into != "":
					out.append({"rid": rid, "accumulate_into": into, "anchor": anchor})
			continue
		out.append({"rid": rid, "channel": channel, "anchor": anchor, "n": n, "guaranteed": g, "once": ok,
			"src_ev": int(ev.get("seq", 0)), "act_tk": int(ev.get("tk", 0)), "imm": latency_type(rule) == "inmediata",
			"counter": counter_key(rule, ev, obs)})
	return out

static func _copy(v):
	return v.duplicate(true) if typeof(v) in [TYPE_ARRAY, TYPE_DICTIONARY] else v

static func _queued_same_day(st, rid: String, day: int) -> String:
	for inst in st.react.queue:
		if String(inst.rid) == rid and TimeKey.day_of(int(inst.act_tk)) == day:
			return String(inst.iid)
	return ""

static func build_anchor(repo, rule: Dictionary, ev: Dictionary, obs) -> Dictionary:
	var src := _src(ev, obs)
	var a := {}
	for k in COMMON_EV:
		if src.has(k):
			a[k] = src[k]
	if not a.has("day") and a.has("tk"):
		a["day"] = TimeKey.day_of(int(a.tk))
	for f in ANCHOR_FIELDS:
		if src.has(f) and src[f] != null:
			a[f] = _copy(src[f])
	for f in _as_arr(rule.get("ancla", [])):
		var fs := String(f)
		if fs == "act_day":
			continue
		var v = src.get(fs)
		if v != null:
			a[fs] = _copy(v)
	if obs != null:
		a["channel"] = String(obs.get("channel", ""))
		if bool(src.get("privado_kw", false)):
			a["privado_kw"] = true
	if String(src.get("type", "")) == "report":
		a["cats"] = cats_of(src)
		a["copies"] = report_p_copies(repo, src)
	if typeof(src.get("item")) == TYPE_DICTIONARY:
		a["item"] = src.item.duplicate(true)
	return a

# «Esos originales» de un informe (M1): sólo ejemplares de clase P de los elementos que Moran lee como original_p
# (recortes; un asiento se lee por sus valores, no por su procedencia, GDD§7.3). Un elemento lleva copies/cls como
# conjuntos sin correspondencia (un asiento mezcla ejemplares I, P y C): cada ejemplar se filtra por su propia clase
# (data/docs: copies[].class o class del documento); si no está en data (documento runtime R.<…>), vale la del
# elemento sólo cuando éste es únicamente P. Nunca un ejemplar I (D9, GDD§10.1).
static func report_p_copies(repo, src: Dictionary) -> Array:
	var copies: Array = []
	for it in _as_arr(src.get("items")):
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var cl := _as_arr(it.get("cls"))
		var cats := _as_arr(it.get("cats"))
		var kind := String(it.get("kind", "clip"))
		if not (cats.has("original_p") or (kind != "entry" and cl.has("P"))):
			continue
		var only_p := not cl.is_empty()
		for k in cl:
			if String(k) != "P":
				only_p = false
		for c in _as_arr(it.get("copies")):
			var k2 := copy_class(repo, String(c))
			if k2 == "P" or (k2 == "" and only_p):
				if not copies.has(c):
					copies.append(c)
	copies.sort()
	return copies

# Clase de un ejemplar según data/docs ("" si no está: documento runtime o ejemplar desconocido).
static func copy_class(repo, copy_id: String) -> String:
	if repo == null or copy_id == "":
		return ""
	var cp = repo.copy(copy_id)
	if typeof(cp) != TYPE_DICTIONARY or cp.is_empty():
		return ""
	var c = cp.get("copy", {})
	var d = cp.get("doc", {})
	if typeof(c) == TYPE_DICTIONARY and String(c.get("class", "")) != "":
		return String(c.class)
	if typeof(d) == TYPE_DICTIONARY:
		return String(d.get("class", ""))
	return ""

# ---------------- v3: el original relacionado (HA5/HA6, GDD_v3 §4.2) ----------------
# disparador.relacion: [{si: match, copias: [ejemplar…]} | {mostrado: true}] en orden: la primera entrada cuyo `si` pasa
# (ReactionDB.match_ok sobre lo observado) da su lista; de ella, el primer original P que esté en casa ahora. {mostrado}
# = el original que el jugador acaba de mostrar (evento show: item.doc_ids/origins → su ejemplar de casa, o el documento
# recibido de la bandeja). "" si no hay ninguno (la reacción no dispara y no gasta su única vez).
static func relacion_copy(st, repo, rule: Dictionary, ev: Dictionary, obs) -> String:
	var spec = disp(rule).get("relacion", [])
	var tk := int(ev.get("tk", 0))
	for r in _as_arr(spec):
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if bool(r.get("mostrado", false)):
			var c := shown_original(st, repo, ev, obs, tk)
			if c != "":
				return c
			continue
		if r.has("si") and not match_ok(repo, r.si, ev, obs, st):
			continue
		for c in _as_arr(r.get("copias", [])):
			if copy_at_home(st, repo, String(c), tk):
				return String(c)
		# la entrada aplicó pero ninguno de sus originales está en casa: se prueban las siguientes
	return ""

# El original P mostrado: un documento estático con ejemplar de casa (P) o una instancia recibida en la bandeja.
static func shown_original(st, repo, ev: Dictionary, obs, tk: int) -> String:
	var src := _src(ev, obs)
	var ids: Array = []
	for f in ["doc"]:
		if src.get(f) != null and String(src[f]) != "":
			ids.append(String(src[f]))
	var it = src.get("item")
	if typeof(it) == TYPE_DICTIONARY:
		for k in ["origins", "doc_ids"]:
			for d in _as_arr(it.get(k)):
				if not ids.has(String(d)):
					ids.append(String(d))
	for d in ids:
		if typeof(st.world) == TYPE_DICTIONARY and typeof(st.world.get("docs")) == TYPE_DICTIONARY and st.world.docs.has(d):
			if copy_at_home(st, repo, d, tk):
				return d
			continue
		if repo == null:
			continue
		for c in repo.doc(d).get("copies", []):
			if typeof(c) == TYPE_DICTIONARY and copy_at_home(st, repo, String(c.get("id", "")), tk):
				return String(c.id)
	return ""

# ¿El original P está ahora en la pieza? Ejemplar de holder L1/tomo, clase P, en su ventana from/to y sin retirar (Effects:
# st.react.world.withdrawn/torn; WorldModel: st.world.copies). Una instancia runtime (carta recibida) cuenta si se entregó
# en la bandeja y no está retirada. Lee el estado sin precargar sim/ ni effects.gd (ciclo).
static func copy_at_home(st, repo, copy_id: String, tk: int) -> bool:
	if copy_id == "":
		return false
	var w: Dictionary = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
	var rw = st.react.get("world", {}) if typeof(st.react) == TYPE_DICTIONARY else {}
	if typeof(rw) != TYPE_DICTIONARY:
		rw = {}
	var wd = rw.get("withdrawn", {}).get(copy_id) if typeof(rw.get("withdrawn")) == TYPE_DICTIONARY else null
	if typeof(wd) == TYPE_DICTIONARY and tk >= int(wd.get("from_tk", 0)) and (int(wd.get("to_tk", -1)) < 0 or tk < int(wd.get("to_tk", -1))):
		return false
	if typeof(rw.get("torn")) == TYPE_DICTIONARY and rw.torn.has(copy_id):
		return false
	var own = w.get("copies", {}).get(copy_id) if typeof(w.get("copies")) == TYPE_DICTIONARY else null
	if typeof(own) == TYPE_DICTIONARY:
		var u := int(own.get("until_tk", -1))
		if tk >= int(own.get("from_tk", -1)) and (u < 0 or tk <= u):
			return false
	if typeof(w.get("docs")) == TYPE_DICTIONARY and w.docs.has(copy_id):
		var d = w.docs[copy_id]
		if typeof(d) != TYPE_DICTIONARY or not bool(d.get("delivered", false)) or String(d.get("where", "")) != "tray":
			return false
		var cls := String(d.get("meta", {}).get("class", "P")) if typeof(d.get("meta")) == TYPE_DICTIONARY else "P"
		return cls == "P"
	if repo == null:
		return false
	var cp = repo.copy(copy_id)
	if typeof(cp) != TYPE_DICTIONARY or cp.is_empty():
		return false
	var c: Dictionary = cp.get("copy", {})
	if not HOME_HOLDERS.has(String(c.get("holder", ""))):
		return false
	if copy_class(repo, copy_id) != "P":
		return false
	if c.has("from") and tk < TimeKey.of(c.from):
		return false
	if c.has("to") and tk > TimeKey.of(c.to):
		return false
	return true

# ---------------- efectos y rastro ----------------
static func effects_of(rule: Dictionary, soft: bool) -> Array:
	if soft:
		var vb = rule.get("variante_blanda")
		if typeof(vb) == TYPE_DICTIONARY:
			return _as_arr(vb.get("efecto", []))
	return _as_arr(rule.get("efecto", []))

static func effect_applies(st, repo, e: Dictionary, inst: Dictionary) -> bool:
	if e.has("si_canal"):
		var hit := false
		for c in _as_arr(e.si_canal):
			if String(c) == String(inst.get("channel", "")):
				hit = true
		if not hit:
			return false
	if e.has("si_n"):
		var hit2 := false
		for x in _as_arr(e.si_n):
			if int(x) == int(inst.get("n", 0)):
				hit2 = true
		if not hit2:
			return false
	if e.has("resultado") and _s(inst.get("anchor", {}).get("resultado", "")) != _s(e.resultado):
		return false
	if e.has("si_cond"):
		var ctx := {"st": st, "repo": repo, "anchor": inst.get("anchor", {}), "tk": int(inst.get("due_tk", 0)), "counters": {"n": int(inst.get("n", 0))}}
		if not Cond.eval(e.si_cond, ctx):
			return false
	return true

static func effects_for(st, repo, rule: Dictionary, inst: Dictionary, soft: bool) -> Array:
	var out: Array = []
	for e in effects_of(rule, soft):
		if typeof(e) == TYPE_DICTIONARY and effect_applies(st, repo, e, inst):
			out.append(e)
	return out

# Primer efecto documental que aplica (columna > noticia > carta). Ley 5 / T23: lo observado en privado (K-W, K-H)
# nunca sale en la columna ni en las noticias.
static func doc_effect(st, repo, rule: Dictionary, inst: Dictionary, soft: bool) -> Dictionary:
	var effs := effects_for(st, repo, rule, inst, soft)
	var best := {}
	for want in ["columna", "noticia", "carta"]:
		for e in effs:
			if String(e.get("op", "")) == want:
				best = e
				break
		if not best.is_empty():
			break
	if best.is_empty():
		return {}
	if ["columna", "noticia"].has(String(best.op)) and (is_private(inst) or bool(inst.get("en_persona", false))):
		var b2: Dictionary = best.duplicate()
		b2["op"] = "carta"
		return b2
	return best

static func is_private(inst: Dictionary) -> bool:
	var ch := String(inst.get("channel", ""))
	return ch == "K-W" or ch == "K-H" or bool(inst.get("anchor", {}).get("privado_kw", false))

static func rastro_by_tpl(rule: Dictionary, tpl: String) -> Dictionary:
	for r in _as_arr(rule.get("rastro", [])):
		if typeof(r) == TYPE_DICTIONARY and String(r.get("tpl", "")) == tpl:
			return r
	return {}

static func select_rastro(st, repo, rule: Dictionary, inst: Dictionary) -> Dictionary:
	var anchor: Dictionary = inst.get("anchor", {})
	var n := int(inst.get("n", 0))
	var ctx := {"st": st, "repo": repo, "anchor": anchor, "tk": int(inst.get("due_tk", anchor.get("tk", 0))), "counters": {"n": n}}
	var cands: Array = []
	for r in _as_arr(rule.get("rastro", [])):
		if typeof(r) == TYPE_DICTIONARY and (r.has("texto") or r.has("tono")) and Cond.eval(r.get("when", {}), ctx):
			cands.append(r)
	if cands.is_empty():
		return {}
	var keys: Array = []
	for e in _as_arr(rule.get("efecto", [])):
		if typeof(e) == TYPE_DICTIONARY and e.has("plantilla_por"):
			keys.append(_s(anchor.get(String(e.plantilla_por), "")))
	var cf := counter_value_field(rule)
	var has_counter := not counter_spec(rule).is_empty()
	if cf != "":
		var v := _s(anchor.get(cf, ""))
		if v != "":
			keys.append(v + "." + str(n))
			keys.append(v)
	for f in ["topic", "bait_topic", "canary"]:
		var t := _s(anchor.get(f, ""))
		if t != "":
			if has_counter:
				keys.append(t + "." + str(n))
			keys.append(t)
	if has_counter:
		keys.append(str(n))
	keys.append(ch_code(String(inst.get("channel", ""))))
	keys.append(String(inst.get("channel", "")))
	for k in keys:
		if k == "":
			continue
		for r in cands:
			if String(r.get("tpl", "")) == k:
				return r
	if cands.size() == 1:
		return cands[0]
	for r in cands:
		if ["texto", "default"].has(String(r.get("tpl", ""))):
			return r
	var day := TimeKey.day_of(int(inst.get("due_tk", anchor.get("tk", 0))))
	# plantilla al azar (Det) sin repetir la última de la misma reacción, entregada o en cola (playtest v2: HB13 mandó la
	# misma carta dos días seguidos)
	var last := ""
	if typeof(st.react) == TYPE_DICTIONARY:
		for lst in [st.react.get("delivered", []), st.react.get("queue", [])]:
			for x in lst:
				if typeof(x) == TYPE_DICTIONARY and String(x.get("rid", "")) == String(rule.get("id", "")) and String(x.get("iid", "")) != String(inst.get("iid", "")) and String(x.get("tpl", "")) != "":
					last = String(x.tpl)
	var pool := cands
	if last != "" and cands.size() > 1:
		pool = cands.filter(func(r): return String(r.get("tpl", "")) != last)
		if pool.is_empty():
			pool = cands
	return Det.pick(int(st.seed), [String(rule.get("id", "")), String(inst.get("iid", "")), day], pool)

# Rastros que son fragmentos del mundo (nodo: "N:L1.ceniza", "S:M7.x", "L:char.línea", "M:…"): todos los que pasan `when`.
static func nodo_rastros(st, repo, rule: Dictionary, inst: Dictionary) -> Array:
	var anchor: Dictionary = inst.get("anchor", {})
	var ctx := {"st": st, "repo": repo, "anchor": anchor, "tk": int(inst.get("due_tk", anchor.get("tk", 0))), "counters": {"n": int(inst.get("n", 0))}}
	var out: Array = []
	for r in _as_arr(rule.get("rastro", [])):
		if typeof(r) == TYPE_DICTIONARY and r.has("nodo") and Cond.eval(r.get("when", {}), ctx):
			out.append(r)
	return out

# ---------------- variables de plantilla ----------------
static func vars_for(st, repo, rule: Dictionary, inst: Dictionary) -> Dictionary:
	var a: Dictionary = inst.get("anchor", {})
	var v := {}
	for k in ["seat", "title", "hour", "phrase", "text", "topic", "n", "form", "to", "task", "amount_d", "place"]:
		v[k] = _s(a.get(k, ""))
	v["channel"] = String(inst.get("channel", ""))
	v["ch"] = ch_code(String(inst.get("channel", "")))
	v["n"] = str(int(inst.get("n", 0)))
	v["streets"] = streets_text(a.get("streets"))
	v["hora"] = hour_words(_s(a.get("hour", "")))
	v["itinerario"] = itinerary(a)
	v["addr"] = ""
	if a.has("char") and repo != null:
		v["addr"] = String(repo.dialogue(String(a.char)).get("addr", ""))
	var day := int(a.get("day", TimeKey.day_of(int(a.get("tk", inst.get("act_tk", 0))))))
	v["act_day"] = weekday_name(repo, day)
	v["act_date"] = date_text(repo, day)
	return v

static func streets_text(s) -> String:
	var arr := _as_arr(s)
	if arr.is_empty():
		return ""
	if arr.size() == 1:
		return String(arr[0])
	var head := PackedStringArray()
	for i in arr.size() - 1:
		head.append(String(arr[i]))
	return ", ".join(head) + " y " + String(arr[arr.size() - 1])

# "10:00" → "las diez", "13:00" → "la una", "15:30" → "las tres y media"
static func hour_words(h: String) -> String:
	if not h.contains(":"):
		return h
	var hh := int(h.get_slice(":", 0))
	var mm := int(h.get_slice(":", 1))
	var add := ""
	if mm == 15:
		add = " y cuarto"
	elif mm == 30:
		add = " y media"
	elif mm == 45:
		hh += 1
		add = " menos cuarto"
	elif mm != 0:
		return h
	var w: String = HOURS[hh % 12]
	return ("la " if hh % 12 == 1 else "las ") + w + add

# HA3: «Kensington High Street a las diez, el Strand a las tres» (primera calle de cada salida del día)
static func itinerary(a: Dictionary) -> String:
	var legs: Array = []
	legs.append({"streets": a.get("streets"), "hour": a.get("hour")})
	for x in _as_arr(a.get("itinerary")):
		if typeof(x) == TYPE_DICTIONARY:
			legs.append(x)
	var ps := PackedStringArray()
	for leg in legs:
		var st_arr := _as_arr(leg.get("streets"))
		if st_arr.is_empty():
			continue
		var hw := hour_words(_s(leg.get("hour", "")))
		ps.append(String(st_arr[0]) + ((" a " + hw) if hw != "" else ""))
	return ", ".join(ps)

static func day_row(repo, day: int) -> Dictionary:
	if repo == null:
		return {}
	for d in repo.schedule().get("days", []):
		if typeof(d) == TYPE_DICTIONARY and int(d.get("day", -1)) == day:
			return d
	return {}

static func weekday_name(repo, day: int) -> String:
	var row := day_row(repo, day)
	if row.is_empty():
		return ""
	var wd := Cond.wd_norm(String(row.get("weekday", "")))
	var t: String = repo.text("core.wd." + wd)
	return "" if t == "core.wd." + wd else t

static func date_text(repo, day: int) -> String:
	var row := day_row(repo, day)
	var date := String(row.get("date", ""))
	if date.length() < 10:
		return ""
	var m := int(date.substr(5, 2))
	var d := int(date.substr(8, 2))
	var mes: String = repo.text("core.mes.%d" % m)
	return "%d de %s" % [d, mes]

static func mmdd(repo, day: int) -> String:
	var date := String(day_row(repo, day).get("date", ""))
	return date.substr(5, 2) + date.substr(8, 2) if date.length() >= 10 else ""

static func day_has(repo, day: int, key: String) -> bool:
	var row := day_row(repo, day)
	return bool(row.get(key, false))

static func _placeholders(src: String) -> Array:
	var out: Array = []
	var i := src.find("${")
	while i >= 0:
		var e := src.find("}", i + 2)
		if e < 0:
			break
		out.append(src.substr(i + 2, e - i - 2))
		i = src.find("${", e)
	return out

# ---------------- lint de gramática (para datos reales; lo usan los tests) ----------------
static func lint(repo) -> Array:
	var errs: Array = []
	var known_events := PUBLIC_EVENTS + INTERNAL_EVENTS
	for r in repo.reactions():
		var id := String(r.get("id", "?"))
		for e in evento_list(r):
			if not known_events.has(e):
				errs.append("%s: evento desconocido '%s'" % [id, e])
		var d := disp(r)
		for k in d:
			if not DISP_KEYS.has(String(k)) and not String(k).begins_with("_"):
				errs.append("%s: disparador.%s desconocido" % [id, k])
		if evento_list(r).has("tiempo") and TimeKey.of(d.get("tk", r.get("latencia", {}).get("tk", ""))) < 0:
			var in_col := false
			for c in repo.schedule().get("column", []):
				if String(c.get("r", "")) == id:
					in_col = true
			if not in_col:
				errs.append("%s: evento tiempo sin tk ni entrada en schedule.column" % id)
		var lt := latency_type(r)
		if not LATENCIES.has(lt):
			errs.append("%s: latencia '%s' desconocida" % [id, lt])
		if not ["holmes", "mycroft", "moran", "respuesta"].has(lado(r)):
			errs.append("%s: lado '%s' desconocido" % [id, lado(r)])
		var canal := String(r.get("canal", ""))
		if ["holmes", "mycroft"].has(lado(r)) and not (CHANNELS.has(canal) or canal == "*"):
			if not (is_column(r) or evento_list(r).has("tiempo") or evento_list(r).has("inactividad")):
				errs.append("%s: canal '%s' (lado %s) no es K-x ni *" % [id, canal, lado(r)])
		for e in effects_of(r, false) + effects_of(r, true):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			for k in e:
				var ks := String(k)
				if ks.begins_with("si_") and not EFFECT_FILTERS.has(ks):
					errs.append("%s: filtro de efecto %s desconocido" % [id, ks])
		var tpls := {}
		for rs in _as_arr(r.get("rastro", [])):
			if typeof(rs) == TYPE_DICTIONARY:
				if tpls.has(rs.get("tpl", "")):
					errs.append("%s: rastro tpl '%s' duplicado" % [id, rs.get("tpl", "")])
				tpls[rs.get("tpl", "")] = true
				var srcs: Array = [String(rs.get("texto", ""))]
				if typeof(rs.get("tono")) == TYPE_DICTIONARY:
					for k in rs.tono:
						srcs.append(String(rs.tono[k]))
				for src in srcs:
					for ph in _placeholders(src):
						if not VARS.has(ph):
							errs.append("%s: rastro %s usa ${%s}, que el motor no define" % [id, rs.get("tpl", ""), ph])
		var needs_doc := false
		for e in effects_of(r, false):
			if typeof(e) == TYPE_DICTIONARY and DOC_OPS.has(String(e.get("op", ""))):
				needs_doc = true
		if needs_doc:
			var has_text := false
			for rs in _as_arr(r.get("rastro", [])):
				if typeof(rs) == TYPE_DICTIONARY and (rs.has("texto") or rs.has("tono")):
					has_text = true
			if not has_text:
				errs.append("%s: efecto documental sin rastro con texto" % id)
	return errs
