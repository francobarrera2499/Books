# core/react/holmes_agent.gd — Holmes (voz B) y las órdenes permanentes de Mycroft por Cotter (voz A).
# Dueño: W2-REACT. ARCHITECTURE §5.4, GDD§9.4–9.5. Sólo ve observaciones de Sensors (nunca st.ded: T8).
# observe(st, repo, obs, ev) -> candidatas de reglas lado holmes|mycroft (motor genérico de ReactionDB.collect):
#   Ley 2: contador por tema de cebo, global entre canales (contador "bait_topic"): n=1,2 → HB1; 3 → HB2 (falsa,
#          f:refutado); ≥4 → silencio (HB2b, tipo silencio). Canario por canal (contador "canario:channel"):
#          1.º → HA4; 2.º → HB11 (canal_cerrado.K-x; desde entonces sólo columna y garantizadas en ese canal).
#   HA1 primera papeleta por tema con slip_topics «holmes»; «silencio» → nada (HB14). HA3: primer go desde el día 3.
#   HB13 por inactividad (evento interno «inactividad» que emite el Director a la noche).
#   Tras watson_expuesto la voz B calla salvo HB10 y las garantizadas.
# st.react.holmes = {bait:{tema:n}, canary:{canal:n}, first_topic:{tema:tk}, posture, confidence, hb4, hb8b}
#   posture = max(posture, nivel) al entregar; confidence: +1 si un anuncio refuta HB2/HB3 (assertion.refutes),
#   +1 si tras HB9 un informe no trae watson_privado, −2 en HB9. Sólo elige el tono del rastro; nunca se muestra.
# obs puede traer claves internas del Director: _bumped (dict compartido por evento), _mode, _skip.
extends RefCounted

const RDB = preload("res://core/react/reaction_db.gd")

static func init_state(st, repo) -> void:
	if typeof(st.react) != TYPE_DICTIONARY:
		st.react = {}
	if typeof(st.react.get("holmes")) != TYPE_DICTIONARY:
		st.react["holmes"] = {}
	var h: Dictionary = st.react.holmes
	for k in ["bait", "canary", "first_topic"]:
		if typeof(h.get(k)) != TYPE_DICTIONARY:
			h[k] = {}
	for k in ["posture", "confidence", "hb4", "hb8b"]:
		if not h.has(k):
			h[k] = 0
	for k in ["counters", "once"]:
		if typeof(st.react.get(k)) != TYPE_DICTIONARY:
			st.react[k] = {}
	if typeof(st.react.get("queue")) != TYPE_ARRAY:
		st.react["queue"] = []

static func observe(st, repo, obs: Dictionary, ev: Dictionary) -> Array:
	init_state(st, repo)
	var bumped = obs.get("_bumped")
	if typeof(bumped) != TYPE_DICTIONARY:
		bumped = {}
		obs["_bumped"] = bumped
	_track(st, repo, obs, ev, bumped)
	var o: Dictionary = obs.duplicate()
	o.erase("_bumped")
	o.erase("_mode")
	o.erase("_skip")
	return RDB.collect(st, repo, ev, o, ["holmes", "mycroft"], bumped, String(obs.get("_mode", "all")), RDB._as_arr(obs.get("_skip", [])))

# Espejos legibles de la Ley 2 y del canario (una vez por evento y canal) y confianza por refutación.
static func _track(st, repo, obs: Dictionary, ev: Dictionary, bumped: Dictionary) -> void:
	var h: Dictionary = st.react.holmes
	var c: Dictionary = obs.get("content", {})
	if not bool(obs.get("to_holmes", false)) and not bool(obs.get("to_mycroft", false)):
		return
	var bt := RDB._s(c.get("bait_topic", ""))
	if bt != "" and bool(obs.get("to_holmes", false)) and not bumped.has("_h.bait"):
		bumped["_h.bait"] = true
		h.bait[bt] = int(h.bait.get(bt, 0)) + 1
	var cn := RDB._s(c.get("canary", ""))
	var ch := String(obs.get("channel", ""))
	if cn != "" and cn != "false" and ch != "" and not bumped.has("_h.canary." + ch):
		bumped["_h.canary." + ch] = true
		h.canary[ch] = int(h.canary.get(ch, 0)) + 1
	var tp := RDB._s(c.get("topic", ""))
	if tp != "" and not h.first_topic.has(tp):
		h.first_topic[tp] = int(ev.get("tk", 0))
	# confianza: un anuncio que refuta una corrección falsa ya entregada (assertion.refutes = [rid…])
	if String(ev.get("type", "")) == "ad" and not bumped.has("_h.refutes"):
		bumped["_h.refutes"] = true
		var a := RDB.assertion(repo, c.get("assertion", ""))
		for r in RDB._as_arr(a.get("refutes", [])):
			if int(st.react.counters.get("delivered." + String(r), 0)) > 0:
				h.confidence = int(h.confidence) + 1
				break

# Llamado por el Director al encolar (contadores propios del registro §3.9).
static func on_enqueued(st, repo, inst: Dictionary) -> void:
	var rid := String(inst.get("rid", ""))
	var h: Dictionary = st.react.holmes
	if rid == "HB4" or rid.begins_with("HB4_") or rid == "HB4b":
		h.hb4 = int(h.hb4) + 1
		st.flags["hb4_veces"] = int(h.hb4)
	elif rid == "HB8b":
		h.hb8b = int(h.hb8b) + 1

# Llamado por el Director al entregar.
static func on_delivered(st, repo, inst: Dictionary) -> void:
	var l := String(inst.get("lado", ""))
	if l != "holmes" and l != "mycroft":
		return
	var h: Dictionary = st.react.holmes
	h.posture = maxi(int(h.posture), int(inst.get("level", 0)))
	if String(inst.get("rid", "")) == "HB9":
		h.confidence = int(h.confidence) - 2

# Informe a Moran (Holmes no lo ve; el Director sí): tras HB9, un informe sin watson_privado sube la confianza.
static func on_report(st, repo, ev: Dictionary) -> void:
	if int(st.react.counters.get("delivered.HB9", 0)) <= 0:
		return
	if not RDB.cats_of(ev).has("watson_privado"):
		st.react.holmes.confidence = int(st.react.holmes.confidence) + 1

static func tone(st) -> String:
	if typeof(st.react) != TYPE_DICTIONARY or typeof(st.react.get("holmes")) != TYPE_DICTIONARY:
		return "bajo"
	return "alto" if int(st.react.holmes.get("confidence", 0)) >= 1 else "bajo"
