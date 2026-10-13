# PROGRESIÓN (GDD_v2 §B.3–§B.5, §B.8, §F.3): el mapa crece cuando Lisle se entera (lee, oye o recorta un nombre) y, si no,
# a la hora garantizada; las novedades de Crane atrasan sus ejemplares; el grafo usa sólo la garantía; `read` es libre,
# ciega y reproducible. Datos reales (y el fixture del sim para la compatibilidad sin `reveal`).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const GameSim = preload("res://core/sim/game_sim.gd")
const Reveal = preload("res://core/sim/reveal.gd")
const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Av = preload("res://core/graph/availability.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const J = preload("res://core/util/j.gd")

func _clip_tramo(s, view: String, tid: String) -> String:
	var v: Dictionary = s.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					var r: Dictionary = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(tr.from), "len": int(tr.to) - int(tr.from)})
					return String(r.get("clip", ""))
	return ""

# Prólogo v2 mínimo sobre datos reales: abrir el encargo (hoja 1), recortar el aviso, el aviso y dormir.
func _sim(seed := 7):
	var s = GameSim.new(repo(), seed)
	ok(s.apply({"t": "read", "view": "D23@L1", "part": 0}).ok, "abrir el encargo")
	ok(_clip_tramo(s, "D23@L1", "aviso") != "", "recortar el aviso")
	ok(s.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok, "aviso")
	ok(s.apply({"t": "sleep"}).ok, "dormir")
	return s

func _ids(s) -> Array:
	var out: Array = []
	for p in s.q_places():
		if not out.has(String(p.id)):
			out.append(String(p.id))
	out.sort()
	return out

func _known_place(s, L: String) -> bool:
	return Reveal.place_known(s.st, s.repo, L)

func test_day1_three_places():
	var s = _sim()
	eq(String(s.q_clock().phase), "desk")
	eq(_ids(s), ["L1", "L2", "L4"], "día 1: casa (con la tienda), Sala de Lectura y consultorio")
	var shop := false
	for p in s.q_places():
		if String(p.id) == "L1":
			shop = String(p.area) == "tienda" and bool(p.free)
	ok(shop, "la tienda de Crane está")
	for p in s.q_places():
		if String(p.id) == "L2" or String(p.id) == "L4":
			ok(bool(p.new), "nuevo el día 1: %s" % p.id)
			ok(String(p.hours) != "", "horario en una línea: %s" % p.id)

func test_guarantees_without_reading():
	var s = _sim()
	eq(Kit.advance_to(s, 1, "N"), "")
	no(_known_place(s, "L3"), "Baker Street todavía no (1.N)")
	eq(Kit.advance_to(s, 2, "M"), "")
	ok(_known_place(s, "L3"), "Baker Street a más tardar el 2.dawn")
	no(_known_place(s, "L6"))
	eq(Kit.advance_to(s, 3, "M"), "")
	ok(_known_place(s, "L6"), "Somerset House a más tardar el 3.dawn")
	no(_known_place(s, "L7"))
	eq(Kit.advance_to(s, 5, "M"), "")
	ok(_known_place(s, "L7"), "Park Lane el 5.dawn")
	no(_known_place(s, "L8"))
	eq(Kit.advance_to(s, 7, "M"), "")
	no(_known_place(s, "L8"), "Camden House no antes de la tarde del 7")
	eq(Kit.advance_to(s, 7, "T"), "")
	ok(_known_place(s, "L8"), "Camden House el 7.T")
	if not _known_place(s, "L5"):
		eq(Kit.advance_to(s, 8, "M"), "")
	ok(_known_place(s, "L5"), "Diógenes a más tardar el 8.dawn")
	eq(int(s.st.world.revealed.get("L3", -1)), TimeKey.parse("2.dawn"), "revelado en su garantía")

func test_read_reveals_early():
	var s = GameSim.new(repo(), 7)
	no(_known_place(s, "L3"))
	# una crónica de los tomos que nombre Baker Street: en cuanto se muestra su hoja, el lugar entra al mapa
	var hit := ""
	for x in s.q_accessible():
		if String(x.holder) != "tomo":
			continue
		var v: Dictionary = s.q_view(String(x.view))
		for pi in (v.pages as Array).size():
			for b in v.pages[pi]:
				for m in b.get("parsed", {}).get("mentions", []):
					if String(m.ent) == "baker_street" or String(m.ent) == "221b":
						hit = "%s|%d" % [x.view, pi]
				if hit != "":
					break
			if hit != "":
				break
		if hit != "":
			break
	ok(hit != "", "algún tomo nombra Baker Street")
	if hit == "":
		return
	var h0: Dictionary = s.st.world.revealed.duplicate()
	var r: Dictionary = s.apply({"t": "read", "view": hit.get_slice("|", 0), "part": int(hit.get_slice("|", 1))})
	ok(r.ok, str(r))
	ok(_known_place(s, "L3"), "leer la hoja revela Baker Street ya en el prólogo")
	ne(s.st.world.revealed, h0)
	eq(s.st.events.size(), 0, "`read` no emite evento público (ceguera)")
	eq(s.q_read(hit.get_slice("|", 0)), [int(hit.get_slice("|", 1))])

func test_hear_and_clip_reveal():
	var s = GameSim.new(repo(), 7)
	no(_known_place(s, "L6"))
	Reveal.hear(s.st, s.repo, "Pregunte en [[somerset_house|Somerset House]], señor.")
	Reveal.update(s.st, s.repo)
	ok(_known_place(s, "L6"), "oír el nombre revela Somerset House")
	# ents_all: el Diógenes necesita saber qué es el club Y dónde queda
	no(_known_place(s, "L5"))
	Reveal.learn(s.st, ["pall_mall"])
	Reveal.update(s.st, s.repo)
	no(_known_place(s, "L5"), "sólo Pall Mall no alcanza")
	Reveal.learn(s.st, ["club_diogenes"])
	Reveal.update(s.st, s.repo)
	ok(_known_place(s, "L5"), "club y calle: el Diógenes entra al mapa")

func test_clip_teaches_known():
	var s = GameSim.new(repo(), 7)
	var c := _clip_tramo(s, "D23@L1", "aviso")
	ok(c != "")
	for e in s.q_clip(c).ents:
		ok(Reveal.is_known(s.st, String(e.id)), "lo recortado se sabe: %s" % e.id)

func test_unrevealed_is_closed():
	var s = _sim()
	var r: Dictionary = s.can({"t": "go", "place": "L6", "area": "sala"})
	eq(r, {"ok": false, "err": "cerrado"}, "un lugar que no está en el mapa no se elige")
	var op: Dictionary = load("res://core/sim/clock.gd").place_open(s.repo, s.st, "L6", "sala", 1, "M")
	eq(String(op.reason), "desconocido")
	for p in s.q_places():
		ne(String(p.id), "L6", "ni con la persiana baja")

func test_revealed_never_closes():
	var s = _sim()
	Reveal.learn(s.st, ["somerset_house"])
	Reveal.update(s.st, s.repo)
	var t0 := int(s.st.world.revealed.L6)
	s.st.world.known = {}
	Reveal.update(s.st, s.repo)
	ok(_known_place(s, "L6"), "lo revelado no se vuelve a cerrar")
	eq(int(s.st.world.revealed.L6), t0)

func test_stock_delays_crane_copies():
	var r = repo()
	var want := {"D04@Crane": "2.M", "D07@Crane": "2.M", "D09@Crane": "3.M", "D10@Crane": "3.M", "D42@Crane": "3.M", "D43@Crane": "4.M", "D44@Crane": "4.M"}
	for cid in want:
		var cp: Dictionary = r.copy(cid)
		ok(not cp.is_empty(), "ejemplar %s existe (schedule.stock)" % cid)
		if cp.is_empty():
			continue
		eq(String(cp.copy.get("from", "")), String(want[cid]), cid)
		var t := TimeKey.parse(String(want[cid]))
		var s = GameSim.new(r, 7)
		no(WorldModel.copy_available(s.st, r, cid, t - 1), "%s no antes de %s" % [cid, want[cid]])
		ok(WorldModel.copy_available(s.st, r, cid, t), "%s desde %s" % [cid, want[cid]])
		ok(r.stock_tk(cid) > 0, "novedad de Crane")
	# lo que estaba desde el principio sigue igual (cuatro papeles el día 1)
	for cid in ["D03@Crane", "D17@Crane", "D40@Crane", "D41@Crane"]:
		var cp2: Dictionary = r.copy(cid)
		if not cp2.is_empty():
			ok(not cp2.copy.has("from") or TimeKey.of(cp2.copy.from) <= TimeKey.parse("1.M"), "%s en la tienda el día 1" % cid)

func test_availability_uses_guarantee_only():
	var r = repo()
	var before_l3 := Av.range_mask(0, TimeKey.idx(1, "N"))
	eq(Av.area_open(r, "L3", "interior") & before_l3, 0, "L3 sin franjas antes del 2.M")
	ok(Av.area_open(r, "L3", "interior") & (1 << TimeKey.idx(2, "M")) != 0, "L3 abre el 2.M")
	eq(Av.area_open(r, "L6", "sala") & Av.range_mask(0, TimeKey.idx(2, "N")), 0, "L6 sin franjas antes del 3.M")
	eq(Av.area_open(r, "L5", "porteria") & Av.range_mask(0, TimeKey.idx(7, "N")), 0, "portería sin franjas antes del 8.M")
	ok(Av.area_open(r, "L5", "forasteros") != 0, "la Sala de Visitas conserva su ventana")
	eq(Av.area_open(r, "L7", "exterior") & Av.range_mask(0, TimeKey.idx(4, "N")), 0)
	eq(Av.area_open(r, "L8", "interior") & Av.range_mask(0, TimeKey.idx(7, "M")), 0)
	ok(Av.area_open(r, "L2", "sala") & (1 << TimeKey.idx(1, "M")) != 0, "L2 desde el 1.M")

func test_read_replays_to_same_hash():
	var s = _sim()
	ok(s.apply({"t": "read", "view": "D23@L1", "part": 2}).ok)
	eq(s.apply({"t": "read", "view": "D23@L1", "part": 99}).err, "parte")
	eq(s.apply({"t": "read", "view": "D46@L5", "part": 0}).err, "inaccesible")
	var s2 = GameSim.replay(s.repo, 7, s.actions_log())
	eq(s2.replay_errors, 0)
	eq(s2.state_hash(), s.state_hash(), "replay con `read` da el mismo estado (T9)")
	eq(s2.st.world.known, s.st.world.known)

func test_no_reveal_spec_means_all_known():
	var s = Kit.new_sim()
	for L in ["L2", "L3", "L4", "L5", "L6", "L7", "L8"]:
		ok(Reveal.place_known(s.st, s.repo, L), "sin schedule.reveal todo está en el mapa: " + L)

func test_reveal_data_shape():
	var r = repo()
	var rv: Dictionary = r.schedule().get("reveal", {})
	eq(rv.keys().size(), 7)
	no(rv.has("L1"), "la casa no se revela: siempre está")
	for L in rv:
		ok(TimeKey.of(rv[L].get("by", "")) >= 0, L)
		for e in rv[L].get("ents", []) + rv[L].get("ents_all", []):
			ok(not r.entity(String(e)).is_empty(), "entidad %s de %s" % [e, L])
	eq(r.map().get("places", {}).get("L8", {}).has("show"), false, "map.json ya no decide qué aparece")
	for L in r.map().get("places", {}):
		ok(String(r.map().places[L].get("hours", "")) != "", "horario de %s" % L)
