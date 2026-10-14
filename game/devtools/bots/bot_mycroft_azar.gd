# devtools/bots/bot_mycroft_azar.gd — presentador al azar ante Mycroft (W3-BOTS; §9.3, GDD §9.6 HB12, HC06, T10):
# juega como el deductor (rutas ★, crédito ante Moran, confrontación con el grupo correcto), pero el día 8 o 9, en una
# franja T/N con la Sala de Forasteros abierta, va al Diógenes y le presenta a Mycroft recortes o asientos AL AZAR (hasta
# MAX_PRESENTS por visita, o hasta que Mycroft acepte o se vaya). Primer error tolerado; el segundo cierra la Sala
# (forasteros_cerrada; la portería y D31 siguen). Si por azar presenta Q3 en tinta (sin pruebas de S.HC06), Mycroft ofrece la
# errata a medida (HB12) — nunca un final mejor que el del deductor. Prefiere franjas que el itinerario deja libres; si el
# 9.N llega sin visita, va igual y replanifica.
extends "res://devtools/bots/bot_deductor.gd"

const MAX_PRESENTS := 3
const L5 := "L5"
const SALA := "forasteros"

var _visited := false

func _init_bot() -> void:
	bot_name = "mycroft_azar"
	conf_cover = true

func pol_outing() -> Dictionary:
	var c: Dictionary = _c()
	var day := int(c.day)
	var slot := String(c.slot)
	if not _visited and (day == 8 or day == 9) and ["T", "N"].has(slot) and _sala_open():
		var free := not itinerary.has(_idx())
		if free or (day == 9 and slot == "N"):
			_visited = true
			if not free:
				replan_next = true
			return {"place": L5, "area": SALA}
	return super.pol_outing()

func _sala_open() -> bool:
	var c: Dictionary = _c()
	return bool(Clock.place_open(repo, sim.st, L5, SALA, int(c.day), String(c.slot)).open)

func pol_in_visit() -> void:
	var v: Dictionary = sim.st.world.get("visit", {})
	if String(v.get("place", "")) != L5 or String(v.get("area", "")) != SALA:
		return
	for k in MAX_PRESENTS:
		var m: Dictionary = sim.st.scenes.get("mycroft", {}) if typeof(sim.st.scenes) == TYPE_DICTIONARY else {}
		if bool(m.get("ok", false)) or bool(m.get("gone", false)):
			return
		var items: Array = []
		for cl in _clip_ids():
			items.append({"kind": "clip", "id": String(cl)})
		for h in (sim.q_dossier().get("inked", []) as Array) + (sim.q_dossier().get("open", []) as Array):
			items.append({"kind": "pregunta", "id": String(h.id)})
		if items.is_empty():
			return
		var it: Dictionary = rnd_pick(items, "mycroft")
		var r := act({"t": "present", "char": "mycroft", "item": it}, true)
		var m2: Dictionary = sim.st.scenes.get("mycroft", {}) if typeof(sim.st.scenes) == TYPE_DICTIONARY else {}
		stats.mycroft.append({"item": it, "ok": bool(r.get("ok", false)), "err": String(r.get("err", "")),
			"outcome": String(r.get("outcome", "")), "accepted": bool(m2.get("ok", false)), "gone": bool(m2.get("gone", false))})
		if not bool(r.get("ok", false)):
			return
