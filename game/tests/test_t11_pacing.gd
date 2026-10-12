# T11 (W2-REACT): ritmo (GDD§7.7, §9.8 D2). Sobre guiones fijos (pasivo y tests/fixtures/react/t11_activo.jsonl):
#   ≤1.000 palabras nuevas por mañana en la bandeja (reacciones + Times del día si existe en datos);
#   nunca más de 2 franjas seguidas sin material nuevo (reacción, documento, escena; salir a un lugar es material);
#   ≤1 reacción disparada fuerte por mañana y una mañana de calma después (exenciones de D2; el día 10 fusiona).
extends "res://tests/test_base.gd"

const H = preload("res://tests/fixtures/react/harness.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")

const MAX_WORDS := 1000

func after_each() -> void:
	H.cleanup()

func _scripts() -> Dictionary:
	return {"pasivo": [], "activo": H.load_jsonl("res://tests/fixtures/react/t11_activo.jsonl")}

func _times_words(r, day: int) -> int:
	var md := RDB.mmdd(r, day)
	if md == "" or not RDB.day_has(r, day, "times"):
		return 0
	return int(r.doc("D15." + md).get("words", 0))

func _check(r, label: String, script: Array) -> void:
	var h = H.new(r, 9)
	h.play(script)
	for v in _violations(r, h, label):
		fail(v)

func _violations(r, h, label: String) -> Array:
	var out: Array = []
	# 1) palabras por mañana
	var words := {}
	for i in h.delivered():
		var t := int(i.delivered_tk)
		if TimeKey.slot_of(t) != "dawn" or String(i.get("how", "")) == "fusionada":
			continue
		var d := TimeKey.day_of(t)
		words[d] = int(words.get(d, 0)) + int(i.get("words", 0))
	for d in range(1, 11):
		var total := int(words.get(d, 0)) + _times_words(r, d)
		if total > MAX_WORDS:
			out.append("%s: %d palabras nuevas la mañana del día %d" % [label, total, d])
	# 2) franjas sin material
	var material := {}
	for i in h.delivered():
		var t := int(i.delivered_tk)
		if RDB._as_arr(i.get("applied", [])).is_empty():
			continue
		material[_slot_of_delivery(t)] = true
	for d in range(1, 11):
		if RDB.day_has(r, d, "times"):
			material[_first_slot(d)] = true
	for e in h.st.events:
		if String(e.type) == "go":
			material[int(e.tk)] = true
	var run := 0
	var worst := 0
	var where := ""
	for k in range(TimeKey.idx_count()):
		var f := TimeKey.from_idx(k)
		if int(f.day) < 1:
			continue
		var stk := TimeKey.tk(int(f.day), String(f.slot))
		if material.has(stk):
			run = 0
		else:
			run += 1
			if run > worst:
				worst = run
				where = TimeKey.label(stk)
	if worst > 2:
		out.append("%s: %d franjas seguidas sin material (hasta %s)" % [label, worst, where])
	# 3) fuertes
	var strong := {}
	for i in h.delivered():
		if bool(i.get("strong", false)) and not bool(i.get("overflow", false)):
			var d := TimeKey.day_of(int(i.delivered_tk))
			strong[d] = int(strong.get(d, 0)) + 1
	for d in strong:
		if int(d) >= 10:
			continue
		if int(strong[d]) > 1:
			out.append("%s: %d fuertes el día %d" % [label, strong[d], d])
		if strong.has(int(d) - 1):
			out.append("%s: sin mañana de calma tras la fuerte del día %d" % [label, int(d) - 1])
	print("T11 %s: palabras %s · peor racha %d · fuertes %s" % [label, str(words), worst, str(strong)])
	return out

static func _first_slot(d: int) -> int:
	for k in range(TimeKey.idx_count()):
		var f := TimeKey.from_idx(k)
		if int(f.day) == d:
			return TimeKey.tk(d, String(f.slot))
	return -1

# Una entrega al amanecer cuenta para la primera franja del día; una entrega a la noche, para nada jugable (pasa a
# la mañana siguiente por el amanecer); una en franja, para esa franja.
static func _slot_of_delivery(t: int) -> int:
	var s := TimeKey.slot_of(t)
	if s == "dawn":
		return _first_slot(TimeKey.day_of(t))
	if s == "night":
		return _first_slot(TimeKey.day_of(t) + 1)
	return t

func test_pacing_fixture():
	var r = fixture_repo("react/data")
	var s := _scripts()
	for k in s:
		_check(r, "fixture/" + k, s[k])

func test_pacing_real_data():
	var r = repo()
	if r.reactions().is_empty() or r.schedule().get("column", []).is_empty():
		pending_content("data/reactions y schedule.column (W2-STRUCT)")
		return
	var s := _scripts()
	for k in s:
		_check(r, "data/" + k, s[k])

# Controles negativos: el detector ve violaciones fabricadas.
func test_detector_sees_violations():
	var r = fixture_repo("react/data")
	var h = H.new(r)
	h.play([], "10.night")
	h.st.react.delivered.append({"iid": "R.X.1", "rid": "HB9", "delivered_tk": TimeKey.parse("6.dawn"), "strong": true, "applied": ["carta"], "words": 10})
	h.st.react.delivered.append({"iid": "R.X.2", "rid": "HB3", "delivered_tk": TimeKey.parse("6.dawn"), "strong": true, "applied": ["noticia"], "words": 990})
	h.st.react.delivered.append({"iid": "R.X.3", "rid": "M2", "delivered_tk": TimeKey.parse("7.T"), "strong": true, "applied": ["carta"], "words": 10})
	var v := _violations(r, h, "falso")
	var s := str(v)
	ok(s.contains("2 fuertes el día 6"), s)
	ok(s.contains("calma tras la fuerte del día 6"), s)
	ok(s.contains("palabras nuevas la mañana del día 6"), s)
	var h2 = H.new(r)
	h2.play([], "10.night")
	h2.st.react.delivered = []
	ok(str(_violations(r, h2, "vacío")).contains("franjas seguidas sin material"), "sin nada: rachas largas")
