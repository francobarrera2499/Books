# T26 (W2-SIM): ningún clic gasta franja en un lugar cerrado (GDD§5). En cada una de las 25 franjas libres, todo
# destino de q_places cerrado rechaza `go` sin mutar ni registrar ni escribir a disco; todo destino abierto se puede
# elegir (can). Los cierres por flags (§3.9) y por efectos se reflejan en el mapa.
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Fakes = preload("res://tests/fixtures/sim/fakes.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const TIMEOUT_S := 90.0

func _check_slot(s, label: String) -> Array:
	var counts := [0, 0]
	var h0: String = s.state_hash()
	var n0: int = s.actions_log().size()
	for p in s.q_places():
		var a := {"t": "go", "place": p.id, "area": p.area, "seat": 214}
		if p.open:
			counts[0] += 1
			ok(s.can(a).ok, "%s: abierto pero no elegible %s.%s (%s)" % [label, p.id, p.area, s.can(a).err])
		else:
			counts[1] += 1
			ok(p.reason != "", "%s: cerrado sin motivo" % label)
			no(p.can_go, "persiana baja")
			eq(s.can(a), {"ok": false, "err": "cerrado"}, "%s: %s.%s" % [label, p.id, p.area])
			var r: Dictionary = s.apply(a)
			eq(r.err, "cerrado", "%s: %s.%s" % [label, p.id, p.area])
			eq(s.state_hash(), h0, "%s: un clic en %s.%s no muta" % [label, p.id, p.area])
			eq(s.actions_log().size(), n0, "ni se registra")
			no(s.q_clock().outing_done, "ni gasta la franja")
	return counts

func test_every_free_slot():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	var seen := 0
	var open_total := 0
	var closed_total := 0
	for i in TimeKey.idx_count():
		var at := TimeKey.from_idx(i)
		if at.day == 0 or at.day == 10:
			continue
		eq(Kit.advance_to(s, at.day, at.slot), "")
		var c := _check_slot(s, "%d.%s" % [at.day, at.slot])
		open_total += c[0]
		closed_total += c[1]
		seen += 1
	eq(seen, 25, "25 franjas libres (GDD§7.2)")
	ok(open_total > 0 and closed_total > 0, "hay de los dos: %d/%d" % [open_total, closed_total])

func test_home_is_not_a_destination():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	for p in s.q_places():
		no(p.id == "L1" and p.area == "buhardilla", "el hogar no está en el mapa")
	var ids := {}
	for p in s.q_places():
		ids["%s.%s" % [p.id, p.area]] = p
	ok(ids.has("L1.tienda"))
	ok(ids["L1.tienda"].free)

func test_flag_and_effect_closures_on_map():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue())
	eq(Kit.advance_to(s, 4, "M"), "")
	s.st.flags["consulta_cerrada_hasta"] = 7
	WorldModel.close(s.st, "L6", TimeKey.parse("4.M"), TimeKey.parse("4.T"))
	_check_slot(s, "4.M cierres")
	var by := {}
	for p in s.q_places():
		by["%s.%s" % [p.id, p.area]] = p
	no(by["L4.consulta"].open)
	eq(by["L4.consulta"].reason, "orden")
	no(by["L6.registro"].open)
	eq(by["L6.registro"].reason, "cerrado")
	eq(Kit.advance_to(s, 4, "N"), "")
	ok(s.can({"t": "go", "place": "L5", "area": "porteria"}).ok)

func test_closed_click_does_not_touch_disk():
	var old := [Game.save_path, Game.repo_override, Game.sim_handlers]
	Game.save_path = tmp_dir().path_join("t26.jsonl")
	Game.repo_override = Kit.repo()
	Game.sim_handlers = Fakes.new().handlers()
	ok(Game.new_session(2))
	for a in Kit.prologue():
		ok(Game.act(a).ok)
	var bytes := FileAccess.get_file_as_bytes(Game.save_path)
	var r: Dictionary = Game.act({"t": "go", "place": "L4", "area": "estudio"})
	eq(r.err, "cerrado")
	eq(FileAccess.get_file_as_bytes(Game.save_path), bytes, "nada se escribe")
	no(Game._dirty)
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
	Game.sim_handlers = old[2]

# GDD_v2 §B.4/§B.9 (T26 ampliado): lo que todavía no está en el mapa no se lista (ni con persiana) y un `go` a ese lugar
# devuelve `cerrado` sin escribir a disco. Datos reales (schedule.reveal).
func test_unrevealed_not_listed_and_not_written():
	var old := [Game.save_path, Game.repo_override, Game.sim_handlers]
	Game.save_path = tmp_dir().path_join("t26_reveal.jsonl")
	Game.repo_override = repo()
	Game.sim_handlers = {}
	ok(Game.new_session(7))
	ok(Game.act({"t": "read", "view": "D23@L1", "part": 0}).ok)
	var v: Dictionary = Game.sim.q_view("D23@L1")
	var clipped := false
	for pi in (v.pages as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for tr in v.pages[pi][bi].parsed.tramos:
				if not clipped and String(tr.id) == "aviso":
					var sp: Array = load("res://devtools/bots/bot_base.gd").best_window(v.pages[pi][bi].parsed, int(tr.from), int(tr.to))
					clipped = Game.act({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}).ok
	ok(clipped)
	ok(Game.act({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok)
	ok(Game.act({"t": "sleep"}).ok)
	eq(String(Game.sim.q_clock().phase), "desk")
	for p in Game.sim.q_places():
		no(["L5", "L6", "L7", "L8"].has(String(p.id)), "no revelado no se lista: %s.%s" % [p.id, p.area])
	var bytes := FileAccess.get_file_as_bytes(Game.save_path)
	var n0: int = Game.sim.actions_log().size()
	var r: Dictionary = Game.act({"t": "go", "place": "L6", "area": "sala"})
	eq(r.err, "cerrado")
	eq(FileAccess.get_file_as_bytes(Game.save_path), bytes, "nada se escribe")
	eq(Game.sim.actions_log().size(), n0, "ni se registra")
	no(Game.sim.q_clock().outing_done, "ni gasta la franja")
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
	Game.sim_handlers = old[2]
