# W2-SIM / CORE-EXPEDIENTE: reloj y fases (§3.2): horarios, pasar en limpio sin cupo por franja (GDD_v3 §1.6), franjas cruzadas, día 6 sólo T, escenas fijas M6/M7,
# anuncios (oficina, uno por día, sáb -> lun, prólogo -> día 1), informes, salidas y el día 10 fijo hasta el epílogo.
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Clock = preload("res://core/sim/clock.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const TimeKey = preload("res://core/util/timekey.gd")

func _at(day: int, slot: String):
	var s = Kit.new_sim()
	var e: String = Kit.advance_to(s, day, slot)
	eq(e, "", "avance a %d.%s" % [day, slot])
	return s

func _gos(s) -> Array:
	var out: Array = []
	for ev in s.st.events:
		if ev.type == "go":
			out.append(ev)
	return out

func test_place_open_windows():
	var r = Kit.repo()
	var s = Kit.new_sim()
	var st = s.st
	eq(Clock.place_open(r, st, "L2", "sala", 1, "M").open, true)
	eq(Clock.place_open(r, st, "L2", "sala", 6, "T"), {"open": false, "reason": "horario"}, "domingo cerrada")
	eq(Clock.place_open(r, st, "L2", "sala", 6, "M").reason, "dia", "el día 6 no tiene M")
	eq(Clock.place_open(r, st, "L4", "consulta", 1, "T").reason, "horario")
	eq(Clock.place_open(r, st, "L4", "estudio", 6, "T").open, true)
	eq(Clock.place_open(r, st, "L8", "interior", 7, "M").open, false, "from 7.T")
	eq(Clock.place_open(r, st, "L8", "interior", 7, "T").open, true)
	eq(Clock.place_open(r, st, "L8", "interior", 9, "T").open, true)
	eq(Clock.place_open(r, st, "L8", "interior", 9, "N").open, false, "to 9.T")
	eq(Clock.place_open(r, st, "L3", "interior", 6, "T").open, true, "OR entre ventanas")
	eq(Clock.place_open(r, st, "L9", "x", 1, "M").reason, "sin_horario")
	# needs (DSL) y flags de cierre del registro §3.9
	eq(Clock.place_open(r, st, "L5", "forasteros", 8, "T").open, true)
	st.flags["forasteros_cerrada"] = true
	eq(Clock.place_open(r, st, "L5", "forasteros", 8, "T").reason, "needs")
	eq(Clock.place_open(r, st, "L5", "porteria", 8, "T").open, true, "la portería sigue")
	st.flags["consulta_cerrada_hasta"] = 5   # HB4 el día 3 + 2 días (inclusive)
	eq(Clock.place_open(r, st, "L4", "consulta", 4, "M").reason, "orden")
	eq(Clock.place_open(r, st, "L4", "consulta", 5, "M").reason, "orden")
	eq(Clock.place_open(r, st, "L4", "estudio", 6, "T").open, true, "la visita del domingo no se cierra")
	eq(Clock.place_open(r, st, "L4", "consulta", 7, "M").open, true, "vuelva usted el lunes")
	# cierres de efectos (WorldModel.close)
	WorldModel.close(st, "L6", TimeKey.parse("3.M"), TimeKey.parse("3.N"))
	eq(Clock.place_open(r, st, "L6", "registro", 3, "M").reason, "cerrado")
	eq(Clock.place_open(r, st, "L6", "registro", 4, "M").open, true)

# GDD_v3 §1.6: pasar en limpio no tiene cupo por franja ni gasta tiempo; sin intentos limitados; no en el epílogo.
func test_confirm_has_no_slot_quota():
	var s = _at(1, "M")
	no(s.q_clock().has("passes_left"), "v3: sin pasadas por franja")
	no(s.q_clock().has("lot_size"))
	for i in 3:
		var r: Dictionary = s.apply({"t": "dq_confirm", "q": "Q1"})
		eq(String(r.get("err", "")), "formal", "hoja vacía: error de forma, no «Algo no cierra.»: %s" % str(r))
	eq(int(s.st.ded.dossier.attempts.get("Q1", 0)), 0, "los errores de forma no registran intento")
	ok(s.apply({"t": "go", "place": "L3", "area": "calle"}).ok)
	eq(String(s.apply({"t": "dq_confirm", "q": "Q1"}).err), "formal", "también fuera de casa (la cinta Expediente): no es error de fase")
	ok(s.apply({"t": "leave"}).ok)
	eq([s.q_clock().day, s.q_clock().slot], [1, "M"], "pasar en limpio no gasta la franja")

func test_crossed_tks():
	var a := {"day": 0, "slot": "N"}
	eq(Clock.crossed_tks(a, {"day": 1, "slot": "M"}), [4, 10, 11])
	eq(Clock.crossed_tks({"day": 5, "slot": "night"}, {"day": 6, "slot": "T"}), [60, 62], "6.M no es franja")
	eq(Clock.crossed_tks({"day": 2, "slot": "M"}, {"day": 2, "slot": "M"}), [])
	eq(Clock.crossed_tks({"day": 9, "slot": "night"}, {"day": 10, "slot": "M"}), [100, 101])
	eq(Clock.crossed_tks({"day": 10, "slot": "N"}, {"day": 11, "slot": "dawn"}), [104, 110])

func test_day6_only_T():
	var s = _at(5, "N")
	ok(s.apply({"t": "end_slot"}).ok)
	eq(s.q_clock().phase, "night")
	ok(s.apply({"t": "report_submit", "mode": "nada", "items": []}).ok, "informe 2")
	ok(s.apply({"t": "sleep"}).ok)
	var c: Dictionary = s.q_clock()
	eq([c.day, c.slot, c.phase], [6, "T", "desk"])
	eq(c.date_label, "domingo 1 de abril")
	ok(s.apply({"t": "end_slot"}).ok)
	eq([s.q_clock().day, s.q_clock().phase], [6, "night"], "del T del domingo a la noche")

func test_fixed_scene_M6_at_dawn():
	var s = _at(4, "N")
	ok(s.apply({"t": "end_slot"}).ok)
	var r: Dictionary = s.apply({"t": "sleep"})
	ok(r.ok, str(r))
	var c: Dictionary = s.q_clock()
	eq([c.day, c.slot, c.phase, c.scene], [5, "dawn", "scene", "M6"])
	var sc: Dictionary = s.q_scene()
	eq(sc.scene, "M6")
	eq(sc.lines.size(), 1)
	eq(sc.lines[0].id, "donde")
	eq(s.apply({"t": "go", "place": "L3", "area": "calle"}).err, "fase", "en escena sólo leave y libres")
	ok(s.apply({"t": "leave"}).ok)
	eq([s.q_clock().slot, s.q_clock().phase], ["M", "desk"])
	eq(s.q_scene(), {}, "la escena terminó")

func test_fixed_scene_M7_at_night_and_variants():
	var s = _at(7, "N")
	s.st.flags["informes_vacios"] = 2
	ok(s.apply({"t": "end_slot"}).ok)
	var c: Dictionary = s.q_clock()
	eq([c.day, c.slot, c.phase, c.scene], [7, "night", "scene", "M7"])
	var ids: Array = []
	for l in s.q_scene().lines:
		ids.append(l.id)
	eq(ids, ["inteligente", "trichinopolis", "mudo"], "variante append por flag_gte")
	ok(s.st.world.plates.has("PL.M7"), "lámina de M7 archivada")
	ok(s.apply({"t": "leave"}).ok)
	eq(s.q_clock().phase, "night")

func test_ads_office_and_publication():
	var r = Kit.repo()
	eq(Clock.ad_pub_day(r, 0), 1, "prólogo -> día 1")
	eq(Clock.ad_pub_day(r, 1), 2)
	eq(Clock.ad_pub_day(r, 5), 7, "sáb -> lun")
	eq(Clock.ad_pub_day(r, 9), 10)
	var s = _at(1, "N")
	eq(s.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_park_lane"}}).err, "oficina_cerrada", "la oficina cierra a las 18 h")
	var s2 = _at(5, "M")
	var r1: Dictionary = s2.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_park_lane"}})
	ok(r1.ok, str(r1))
	eq(r1.pub_day, 7)
	eq(s2.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_vere_street"}}).err, "uno_por_dia")
	ok(s2.apply({"t": "end_slot"}).ok)
	eq(s2.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_vere_street"}}).err, "uno_por_dia", "también en T")
	var before: int = s2.st.events.size()
	eq(Kit.advance_to(s2, 7, "M"), "")
	var found := false
	for i in range(before, s2.st.events.size()):
		var ev: Dictionary = s2.st.events[i]
		if ev.type == "ad":
			found = true
			eq(ev.tk, TimeKey.parse("7.dawn"), "evento al amanecer de la publicación")
			eq(ev.pub_day, 7)
	ok(found, "se emitió el anuncio del sábado el lunes")

func test_reports_due_and_errors():
	var s = _at(1, "N")
	ok(s.apply({"t": "end_slot"}).ok)
	eq(s.apply({"t": "report_submit", "mode": "nada", "items": []}).err, "sin_informe", "el día 1 no hay informe")
	ok(s.apply({"t": "sleep"}).ok)
	eq(Kit.advance_to(s, 2, "N"), "")
	ok(s.apply({"t": "end_slot"}).ok)
	ok(s.q_report_status().due)
	eq(s.q_report_status().n, 1)
	ok(s.q_clock().report_due)
	eq(s.apply({"t": "sleep"}).err, "informe_pendiente")
	ok(s.apply({"t": "report_submit", "mode": "nada", "items": []}).ok)
	eq(s.apply({"t": "report_submit", "mode": "nada", "items": []}).err, "ya_entregado")
	no(s.q_report_status().due)
	ok(s.apply({"t": "sleep"}).ok)

func test_go_rules():
	var s = _at(1, "M")
	eq(s.apply({"t": "go", "place": "L2", "area": "sala"}).err, "asiento", "la Sala exige asiento")
	eq(s.apply({"t": "go", "place": "L1", "area": "buhardilla"}).err, "cerrado", "ya está en casa")
	eq(s.apply({"t": "go", "place": "L4", "area": "estudio"}).err, "cerrado")
	var r: Dictionary = s.apply({"t": "go", "place": "L1", "area": "tienda"})
	ok(r.ok, str(r))
	no(s.q_clock().outing_done, "bajar a la tienda no gasta franja")
	eq(_gos(s).size(), 0, "la tienda es ciega: sin evento go")
	ok(s.apply({"t": "leave"}).ok)
	var r2: Dictionary = s.apply({"t": "go", "place": "L3"})
	ok(r2.ok, "área por defecto")
	eq(s.q_scene().area, "calle", "primera abierta en orden alfabético salvo el hogar")
	ok(s.q_clock().outing_done)
	ok(s.apply({"t": "leave"}).ok)
	eq(s.apply({"t": "go", "place": "L5", "area": "porteria"}).err, "ya_salio")
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok, "la tienda sí, aunque ya salió")
	eq(_gos(s).size(), 1, "sólo el go a L3")
	var ev: Dictionary = _gos(s)[0]
	eq(ev.place, "L3")
	eq(ev.streets, ["Baker Street", "Blandford Street"])
	ok(String(ev.hour).contains(":"), ev.hour)

func test_day10_fixed_flow_to_done():
	var s = _at(9, "N")
	ok(s.apply({"t": "end_slot"}).ok)
	ok(s.apply({"t": "sleep"}).ok)
	var c: Dictionary = s.q_clock()
	eq([c.day, c.slot, c.phase], [10, "M", "confront"])
	eq(s.q_scene().scene, "HC07", "el librero en la tienda")
	eq(s.apply({"t": "end_slot"}).err, "fase", "el día 10 no tiene escritorio")
	ok(s.apply({"t": "confront", "step": 1, "item": {}}).ok, "callar")
	ok(s.apply({"t": "confront", "step": 2, "item": {"kind": "clip", "id": "ok1"}}).ok)
	ok(s.apply({"t": "confront", "step": 3, "item": {"kind": "clip", "id": "mal"}}).ok)
	eq(s.q_clock().phase, "confront")
	ok(s.apply({"t": "confront", "step": 4, "item": {}}).ok)
	eq(s.q_clock().phase, "final_report")
	ok(s.q_report_status().due and s.q_report_status().final)
	eq(String(s.apply({"t": "dq_confirm", "q": "Q1"}).err), "formal", "el día 10 todavía se pasa en limpio (no es error de fase)")
	ok(s.apply({"t": "report_submit", "mode": "quemar", "items": []}).ok)
	c = s.q_clock()
	eq([c.day, c.slot, c.phase], [10, "T", "parklane"])
	eq(s.q_scene().scene, "HC08")
	ok(s.apply({"t": "leave"}).ok)
	eq(s.q_clock().phase, "night_choice")
	eq(s.apply({"t": "night_choice", "where": "otro"}).err, "forma")
	ok(s.apply({"t": "night_choice", "where": "baker_street"}).ok)
	c = s.q_clock()
	eq([c.day, c.phase], [TimeKey.DAY_E, "epilogue"])
	eq(s.st.flags.noche_final, "baker_street")
	var hc09: Array = []
	for d in s.q_diary():
		if d.kind == "line":
			hc09.append(String(d.parsed.plain))
	ok(hc09.has("Un silbido y un largo tintineo de vidrio roto."), "variante de HC09 por la elección")
	eq(s.q_scene().scene, "EPI")
	ok(s.apply({"t": "publish_errata", "yes": true}).ok)
	eq(s.st.flags.publica_errata, true)
	eq(s.apply({"t": "publish_errata", "yes": false}).err, "ya_decidido")
	ok(s.apply({"t": "leave"}).ok)
	eq(s.q_clock().phase, "done")
	eq(s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D29b@L4", "part": 0, "block": 0}, "from": 0, "len": 4}).err, "fin")
	eq(s.apply({"t": "dq_confirm", "q": "Q1"}).err, "fin")
	eq(s.apply({"t": "leave"}).err, "fin")

func test_prologue_sleep_requires_tutorial():
	var s = Kit.new_sim()
	eq(s.apply({"t": "sleep"}).err, "tutorial")
	var acts: Array = Kit.prologue()
	for i in acts.size() - 1:
		ok(s.apply(acts[i]).ok, str(acts[i]))
	var r: Dictionary = s.apply({"t": "sleep"})
	ok(r.ok, str(r))
	eq(r.arrivals, 1, "el Times del 27 en la bandeja")
	eq([s.q_clock().day, s.q_clock().phase, s.q_clock().slot], [1, "desk", "M"])
