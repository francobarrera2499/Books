# T09 (W2-SIM): determinismo. replay ×2 del mismo registro = mismo state_hash; guardar -> cargar -> guardar = bytes
# idénticos (EventLog y el autoload Game). Además: misma semilla = mismo estado; integración con los módulos reales
# (lo que acepten) también re-ejecuta idéntico.
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Fakes = preload("res://tests/fixtures/sim/fakes.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const J = preload("res://core/util/j.gd")

func _walked(p_seed := 5):
	var s = Kit.new_sim(p_seed)
	var res := Kit.run(s, Kit.load_jsonl(Kit.WALK))
	eq(Kit.first_fail(res), "")
	return s

func test_replay_twice_same_hash():
	var s = _walked()
	var alog: Array = s.actions_log()
	var a = GameSim.replay(Kit.repo(), 5, alog, Fakes.new().handlers())
	var b = GameSim.replay(Kit.repo(), 5, alog, Fakes.new().handlers())
	eq(a.replay_errors, 0)
	eq(b.replay_errors, 0)
	eq(a.state_hash(), b.state_hash())
	eq(a.state_hash(), s.state_hash(), "igual al vivo")
	eq(J.stringify_canon(a.canon()), J.stringify_canon(s.canon()))

func test_same_seed_same_state_other_seed_may_differ():
	var a = _walked(5)
	var b = _walked(5)
	eq(a.state_hash(), b.state_hash())
	var c = _walked(6)
	ne(a.st.seed, c.st.seed)
	eq(a.st.events.size(), c.st.events.size(), "la semilla sólo decide sabores")

func test_eventlog_write_read_write_bytes():
	var s = _walked()
	var d := tmp_dir()
	var p1 := d.path_join("a.jsonl")
	var p2 := d.path_join("b.jsonl")
	var hdr := EventLog.make_header(5, Kit.repo().content_hash())
	ok(EventLog.new(p1).write(hdr, s.actions_log()))
	var r: Dictionary = EventLog.read(p1)
	ok(r.ok, str(r))
	eq(r.actions.size(), s.actions_log().size())
	ok(EventLog.new(p2).write(r.header, r.actions))
	eq(FileAccess.get_file_as_bytes(p1), FileAccess.get_file_as_bytes(p2), "bytes idénticos")
	var re = GameSim.replay(Kit.repo(), int(r.header.seed), r.actions, Fakes.new().handlers())
	eq(re.state_hash(), s.state_hash(), "lo leído reproduce el estado")
	eq(re.actions_log(), s.actions_log(), "lo leído == lo normalizado en vivo")

func test_game_autoload_save_load_save():
	var d := tmp_dir()
	var old := [Game.save_path, Game.repo_override, Game.sim_handlers]
	Game.save_path = d.path_join("partida.jsonl")
	Game.repo_override = Kit.repo()
	Game.sim_handlers = Fakes.new().handlers()
	ok(Game.new_session(5))
	for a in Kit.load_jsonl(Kit.WALK):
		ok(Game.act(a).ok, str(a))
	ok(Game.flush())
	var bytes1 := FileAccess.get_file_as_bytes(Game.save_path)
	var h1: String = Game.sim.state_hash()
	Game.end_session()
	ok(Game.continue_session())
	eq(Game.sim.state_hash(), h1, "cargar reproduce el estado")
	Game._dirty = true
	ok(Game.flush())
	eq(FileAccess.get_file_as_bytes(Game.save_path), bytes1, "guardar otra vez = mismos bytes")
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
	Game.sim_handlers = old[2]

func test_seed_zero_derives_from_content():
	var d := tmp_dir()
	var old := [Game.save_path, Game.repo_override, Game.sim_handlers]
	Game.save_path = d.path_join("p.jsonl")
	Game.repo_override = Kit.repo()
	Game.sim_handlers = Fakes.new().handlers()
	ok(Game.new_session(0))
	var s1: int = Game.sim.st.seed
	ok(s1 != 0)
	ok(Game.new_session(0))
	eq(Game.sim.st.seed, s1, "sin Time: misma semilla para el mismo contenido")
	eq(Game.header().content, Kit.repo().content_hash())
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
	Game.sim_handlers = old[2]

# Con los manejadores reales de los demás paquetes (los que ya existan): lo aceptado se re-ejecuta idéntico.
func test_integration_real_modules_replay():
	var s = GameSim.new(Kit.repo(), 9)
	for a in Kit.load_jsonl(Kit.WALK):
		s.apply(a)
	var alog: Array = s.actions_log()
	ok(alog.size() >= 1, "algo se aceptó")
	var a2 = GameSim.replay(Kit.repo(), 9, alog)
	var b2 = GameSim.replay(Kit.repo(), 9, alog)
	eq(a2.replay_errors, 0)
	eq(a2.state_hash(), b2.state_hash())
	eq(a2.state_hash(), s.state_hash())

# Partida completa (prólogo -> done) con los módulos reales: lo aceptado se re-ejecuta idéntico y el registro
# guardado reproduce los mismos bytes.
func test_integration_real_modules_full_game():
	var s = GameSim.new(Kit.repo(), 21)
	for a in Kit.load_jsonl(Kit.WALK):
		var rw: Dictionary = s.apply(a)
		ok(rw.ok, "%s -> %s" % [str(a), str(rw)])
	eq(Kit.advance_to(s, 9, "N"), "")
	var tail := [{"t": "end_slot"}, {"t": "sleep"}, {"t": "confront", "step": 1}, {"t": "confront", "step": 2},
		{"t": "confront", "step": 3}, {"t": "confront", "step": 4}, {"t": "report_submit", "mode": "nada", "items": []},
		{"t": "leave"}, {"t": "night_choice", "where": "baker_street"}, {"t": "publish_errata", "yes": true}, {"t": "leave"}]
	var phases: Array = []
	for a in tail:
		var r: Dictionary = s.apply(a)
		ok(r.ok, "%s -> %s" % [str(a), str(r)])
		phases.append(String(s.q_clock().phase))
	eq(phases, ["night", "confront", "confront", "confront", "confront", "final_report", "parklane", "night_choice", "epilogue",
		"epilogue", "done"], "día 10 fijo hasta el final")
	var alog: Array = s.actions_log()
	var a2 = GameSim.replay(Kit.repo(), 21, alog)
	eq(a2.replay_errors, 0)
	eq(a2.state_hash(), s.state_hash())
	var d := tmp_dir()
	var hdr := EventLog.make_header(21, Kit.repo().content_hash())
	ok(EventLog.new(d.path_join("x.jsonl")).write(hdr, alog))
	var r: Dictionary = EventLog.read(d.path_join("x.jsonl"))
	ok(EventLog.new(d.path_join("y.jsonl")).write(r.header, r.actions))
	eq(FileAccess.get_file_as_bytes(d.path_join("x.jsonl")), FileAccess.get_file_as_bytes(d.path_join("y.jsonl")))
	eq(GameSim.replay(Kit.repo(), 21, r.actions).state_hash(), s.state_hash())
