# T12 (W2-REACT): coherencia actor–lugar–fecha (GDD§9.8 D8). Toda reacción tiene un actor que puede estar físicamente
# donde ocurre su efecto, en cada fecha en que puede entregarse. Holmes no actúa en Londres antes del día 10 (sus manos
# son Cotter, Wiggins y las notas del Foreign Office); Mycroft no pisa 221B ni hace trabajo de campo; Wiggins sigue a
# Lisle desde el día 3; Steiler y el coronel sólo contestan por telegrama o carta.
extends "res://tests/test_base.gd"

const RDB = preload("res://core/react/reaction_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Latency = preload("res://core/react/latency.gd")

# actor → {from: primer día en Londres, to: último, remote: sólo por correo/telégrafo, field: hace trabajo de campo, l3: puede estar en 221B}
const ACTORS := {
	"holmes": {"from": 10, "to": 10, "field": true, "l3": true, "remote_author": true},
	"librero": {"from": 10, "to": 10, "field": true, "l3": false},
	"mycroft": {"from": 0, "to": 10, "field": false, "l3": false},
	"cotter": {"from": 0, "to": 10, "field": true, "l3": true},
	"wiggins": {"from": 3, "to": 10, "field": true, "l3": false},
	"mrs_hudson": {"from": 0, "to": 10, "field": true, "l3": true},
	"watson": {"from": 0, "to": 10, "field": true, "l3": true},
	"transportista": {"from": 0, "to": 10, "field": true, "l3": true},
	"crane": {"from": 0, "to": 10, "field": true, "l3": false},
	"moran": {"from": 0, "to": 10, "field": true, "l3": false},
	"harris": {"from": 0, "to": 10, "field": true, "l3": false},
	"parker": {"from": 0, "to": 10, "field": true, "l3": false},
	"hombres_de_moran": {"from": 0, "to": 10, "field": true, "l3": false},
	"hombre_del_abrigo": {"from": 0, "to": 10, "field": true, "l3": false},
	"pell": {"from": 0, "to": 10, "field": true, "l3": false},
	"chico_de_pell": {"from": 0, "to": 10, "field": true, "l3": false},
	"chico_del_agente": {"from": 0, "to": 10, "field": true, "l3": true},
	"lestrade": {"from": 0, "to": 10, "field": true, "l3": true},
	"foreign_office": {"from": 0, "to": 10, "field": false, "l3": false},
	"somerset_house": {"from": 0, "to": 10, "field": false, "l3": false},
	"steiler_joven": {"remote": true},
	"coronel_moriarty": {"remote": true},
}
# ops que no exigen trabajo de campo: textos, flags, dinero y la presencia del propio actor (escena, línea)
const TEXT_OPS := ["carta", "columna", "noticia", "linea_siguiente_comunicacion", "flag", "paga", "escena", "linea"]

# Días en que la reacción puede entregarse (cota segura).
static func delivery_days(repo, rule: Dictionary) -> Array:
	var ev := RDB.evento_list(rule)
	if ev.has("tiempo"):
		var t := TimeKey.of(RDB.disp(rule).get("tk", rule.get("latencia", {}).get("tk", "")))
		if t < 0:
			for c in repo.schedule().get("column", []):
				if String(c.get("r", "")) == String(rule.id):
					t = TimeKey.of(c.tk)
		return [TimeKey.day_of(t)] if t >= 0 else []
	var lo := 1
	var hi := 10
	var b := [lo, hi]
	_bounds(rule.get("condiciones", {}), b)
	lo = b[0]
	hi = b[1]
	var lt := RDB.latency_type(rule)
	var lat = rule.get("latencia", {})
	var add := 0
	match lt:
		"voz_a", "siguiente_salida":
			add = 1
		"dias":
			add = int(lat.get("n", 1))
	var out: Array = []
	if lt == "voz_b":
		for d in range(lo, hi + 1):
			var vd := Latency.voice_b_day(repo, d)
			if vd > 0 and not out.has(vd):
				out.append(vd)
		return out
	if lt == "fija":
		var f := TimeKey.of(lat.get("tk", ""))
		return [TimeKey.day_of(f)] if f >= 0 else []
	for d in range(lo + add, mini(hi + add, 10) + 1):
		out.append(d)
	return out

static func _bounds(c, b: Array) -> void:
	if typeof(c) != TYPE_DICTIONARY:
		return
	for k in c:
		if String(k) == "day":
			var v = c[k]
			if typeof(v) == TYPE_DICTIONARY:
				if v.has("gte"):
					b[0] = maxi(b[0], int(v.gte))
				if v.has("gt"):
					b[0] = maxi(b[0], int(v.gt) + 1)
				if v.has("lte"):
					b[1] = mini(b[1], int(v.lte))
				if v.has("eq"):
					b[0] = int(v.eq)
					b[1] = int(v.eq)
			else:
				b[0] = int(v)
				b[1] = int(v)
		elif String(k) == "all":
			for x in c[k]:
				_bounds(x, b)

static func _present(a: String, d: int, rule: Dictionary) -> bool:
	var info: Dictionary = ACTORS.get(a, {})
	if info.is_empty():
		return false
	if bool(info.get("remote", false)):
		return RDB.lado(rule) == "respuesta"
	return d >= int(info.get("from", 0)) and d <= int(info.get("to", 10))

static func _touches_l3(rule: Dictionary) -> bool:
	for e in RDB.effects_of(rule, false):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var s := str(e)
		if String(e.get("place", "")) == "L3" or String(e.get("char", "")) == "mrs_hudson" or s.contains("@L3") or s.contains("\"L3."):
			return true
	return false

# Devuelve las violaciones de una regla.
static func violations(repo, rule: Dictionary) -> Array:
	var out: Array = []
	var id := String(rule.get("id", "?"))
	var actors := RDB._as_arr(rule.get("actor", []))
	if String(rule.get("tipo", "")) == "silencio":
		return out
	if actors.is_empty():
		out.append("%s: sin actor" % id)
		return out
	for a in actors:
		if not ACTORS.has(String(a)):
			out.append("%s: actor desconocido %s" % [id, a])
		elif not repo.entities().is_empty() and repo.entity(String(a)).is_empty():
			out.append("%s: actor %s no es una entidad" % [id, a])
	var physical := false
	for e in RDB.effects_of(rule, false):
		if typeof(e) == TYPE_DICTIONARY and not TEXT_OPS.has(String(e.get("op", ""))):
			physical = true
	for d in delivery_days(repo, rule):
		var ok_any := false
		var ok_field := false
		for a in actors:
			if _present(String(a), int(d), rule):
				ok_any = true
				if bool(ACTORS[String(a)].get("field", false)) or bool(ACTORS[String(a)].get("remote", false)):
					ok_field = true
		if not ok_any:
			out.append("%s: ningún actor puede actuar el día %d (%s)" % [id, d, str(actors)])
		elif physical and not ok_field:
			out.append("%s: efecto físico el día %d sin actor de campo (%s)" % [id, d, str(actors)])
	if _touches_l3(rule):
		var ok3 := false
		for a in actors:
			if bool(ACTORS.get(String(a), {}).get("l3", false)) and String(a) != "holmes":
				ok3 = true
		if not ok3:
			out.append("%s: actúa en 221B sin quien pueda estar allí (Mycroft nunca pisa 221B)" % id)
	return out

func _check_repo(r, label: String) -> void:
	for rule in r.reactions():
		for v in violations(r, rule):
			fail("%s %s" % [label, v])

func test_fixture_actors():
	_check_repo(fixture_repo("react/data"), "fixture")

func test_real_data_actors():
	var r = repo()
	if r.reactions().is_empty():
		pending_content("data/reactions (W2-STRUCT)")
		return
	_check_repo(r, "data")

func test_negative_cases():
	var r = fixture_repo("react/data")
	var holmes_col := {"id": "X1", "tipo": "opcional", "lado": "holmes", "voz": "B", "actor": ["holmes"], "disparador": {"evento": "ad"},
		"condiciones": {}, "latencia": {"tipo": "voz_b"}, "efecto": [{"op": "columna"}], "rastro": []}
	ok(str(violations(r, holmes_col)).contains("ningún actor"), "Holmes solo no publica en Londres antes del 10")
	var wig := {"id": "X2", "tipo": "opcional", "lado": "mycroft", "voz": "A", "actor": ["wiggins"], "disparador": {"evento": "slip"},
		"condiciones": {}, "latencia": {"tipo": "voz_a"}, "efecto": [{"op": "silueta", "who": "x"}], "rastro": []}
	ok(str(violations(r, wig)).contains("día 2"), "Wiggins no está antes del día 3: " + str(violations(r, wig)))
	var my := {"id": "X3", "tipo": "opcional", "lado": "mycroft", "voz": "A", "actor": ["mycroft"], "disparador": {"evento": "go"},
		"condiciones": {}, "latencia": {"tipo": "voz_a"}, "efecto": [{"op": "retirar", "copy": "D30@L3"}], "rastro": []}
	var v3 := str(violations(r, my))
	ok(v3.contains("221B") and v3.contains("sin actor de campo"), v3)
	var ghost := {"id": "X4", "tipo": "opcional", "lado": "moran", "voz": "M", "actor": ["fantasma"], "disparador": {"evento": "report"},
		"condiciones": {}, "latencia": {"tipo": "dias", "n": 1}, "efecto": [{"op": "carta"}], "rastro": []}
	ok(str(violations(r, ghost)).contains("desconocido"))
	var hc07: Dictionary = r.reaction("HC07")
	eq(violations(r, hc07), [], "el librero en persona el día 10")
	eq(delivery_days(r, r.reaction("HB1")), [4, 5, 7, 8, 10], "días posibles de la voz B")
