# core/util/timekey.gd — TimeKey y franjas jugables. Dueño: W1-ENG. Contrato: ARCHITECTURE §3.2, §3.8.
# Días: 0 = P (26-mar, noche), 1..10, 11 = E (oct. 1903). Franjas: dawn, M, T, N, night. tk = día*10 + ORD.
# Índice jugable (29): P.N, 1.M..5.N, 6.T, 7.M..10.N. Texto: "4.dawn", "7.N", "P.N", "E.dawn".
extends RefCounted

const ORD := {"dawn": 0, "M": 1, "T": 2, "N": 3, "night": 4}
const SLOTS := ["dawn", "M", "T", "N", "night"]
const DAY_P := 0
const DAY_E := 11

static var _idx_list: Array = []

static func tk(day: int, slot: String) -> int:
	if not ORD.has(slot):
		return -1
	return day * 10 + ORD[slot]

# "4.dawn" -> 40, "P.N" -> 3, "E.dawn" -> 110, "10.M" -> 101. Inválido -> -1.
static func parse(s: String) -> int:
	var t := s
	var dot := t.find(".")
	if dot <= 0:
		return -1
	var dp := t.substr(0, dot)
	var sp := t.substr(dot + 1)
	if not ORD.has(sp):
		return -1
	var day := -1
	if dp == "P":
		day = DAY_P
	elif dp == "E":
		day = DAY_E
	elif dp.is_valid_int():
		day = dp.to_int()
	if day < 0 or day > DAY_E:
		return -1
	return day * 10 + ORD[sp]

# Variante tolerante: int/float tal cual; String por parse(); otro -> -1.
static func of(v) -> int:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			return int(v)
		TYPE_STRING, TYPE_STRING_NAME:
			return parse(String(v))
	return -1

static func day_of(t: int) -> int:
	return int(t / 10)

static func slot_of(t: int) -> String:
	var o := t % 10
	return SLOTS[o] if o >= 0 and o < SLOTS.size() else ""

static func label(t: int) -> String:
	var day := day_of(t)
	var slot := slot_of(t)
	if slot == "" or t < 0:
		return "?"
	var dp := "P" if day == DAY_P else ("E" if day == DAY_E else str(day))
	return dp + "." + slot

static func _build() -> void:
	if not _idx_list.is_empty():
		return
	_idx_list.append({"day": 0, "slot": "N"})
	for day in range(1, 11):
		if day == 6:
			_idx_list.append({"day": 6, "slot": "T"})
		else:
			for s in ["M", "T", "N"]:
				_idx_list.append({"day": day, "slot": s})

static func idx(day: int, slot: String) -> int:
	_build()
	for i in _idx_list.size():
		if _idx_list[i].day == day and _idx_list[i].slot == slot:
			return i
	return -1

static func idx_count() -> int:
	_build()
	return _idx_list.size()

static func from_idx(i: int) -> Dictionary:
	_build()
	if i < 0 or i >= _idx_list.size():
		return {}
	return _idx_list[i].duplicate()

# Índice jugable de un tk ("d.S" o int): exacto si la franja es jugable; si no, -1.
static func idx_of_tk(t) -> int:
	var k := of(t)
	if k < 0:
		return -1
	return idx(day_of(k), slot_of(k))

# Primer índice jugable con tk >= t (p. ej. "4.dawn" -> índice de 4.M). idx_count() si no hay.
static func idx_at_or_after(t) -> int:
	var k := of(t)
	_build()
	for i in _idx_list.size():
		if tk(_idx_list[i].day, _idx_list[i].slot) >= k:
			return i
	return _idx_list.size()
