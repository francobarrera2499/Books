# devtools/bots/bot_guion.gd — deductor con guion (sondas de T10 sobre data/ real; no es uno de los 11 bots de §9.3).
# Juega como el deductor (oráculo de rutas ★) y además:
#   beats: [{tk:"1.M", go:[lugar, área], acts:[acciones]}] — en esa franja, si todavía no salió, va a ese lugar, hace las
#          acciones (pueden fallar: se registran en beat_log) y vuelve (canarios a Watson, pagar y engañar a Wiggins…).
#   leak_reports: [n] — en esos informes entrega un recorte de las notas privadas de Watson (D01N@tomo, «nov. 93»):
#          M3 la primera vez y, tras HB9, watson_expuesto (V.expuesto).
# Origen: guiones de la auditoría de sistemas (.work/audit_sys/ab_beats.gd, beats_canary.json, ab_m3.gd).
extends "res://devtools/bots/bot_deductor.gd"

var beats: Array = []
var leak_reports: Array = []
var beat_log: Array = []     # [{tk, a, ok, err}]
var _done := {}

func _init_bot() -> void:
	super._init_bot()
	bot_name = "guion"

func pol_desk_extra() -> void:
	var c: Dictionary = _c()
	var tk := int(c.tk)
	for i in beats.size():
		var bt: Dictionary = beats[i]
		if _done.has(i) or TimeKey.of(String(bt.tk)) != tk or bool(c.get("outing_done", false)):
			continue
		_done[i] = true
		var r := _go(String(bt.go[0]), String(bt.go[1]))
		beat_log.append({"tk": String(bt.tk), "a": "go %s.%s" % [bt.go[0], bt.go[1]], "ok": bool(r.get("ok", false)), "err": String(r.get("err", ""))})
		if not bool(r.get("ok", false)):
			continue
		for a in bt.get("acts", []):
			var r2 := act(a, true)
			beat_log.append({"tk": String(bt.tk), "a": J.stringify_canon(a), "ok": bool(r2.get("ok", false)), "err": String(r2.get("err", ""))})
		_harvest()
		act({"t": "leave"}, true)
		return

func _leak_clip() -> String:
	var v: Dictionary = sim.q_view("D01N@tomo")
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var plain := String(pages[pi][bi].get("parsed", {}).get("plain", ""))
			var k := plain.find("nov. 93")
			if k >= 0:
				var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": "D01N@tomo", "part": pi, "block": bi}, "from": k, "len": 7}, true)
				return String(r.get("clip", ""))
	return ""

func pol_report(n: int, final: bool) -> Dictionary:
	if not final and leak_reports.has(n):
		var id := _leak_clip()
		if id != "":
			return {"mode": "items", "items": [{"kind": "clip", "id": id}]}
	return super.pol_report(n, final)

# Reacciones entregadas (rid) en orden, para las sondas.
func delivered() -> Array:
	var out: Array = []
	for inst in sim.st.react.get("delivered", []):
		if typeof(inst) == TYPE_DICTIONARY:
			out.append(String(inst.get("rid", "")))
	return out
