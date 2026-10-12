# T25 (W2-SIM): guardado por compromiso (GDD§7.6, §5.5). «Matar» el proceso justo después de mostrar el resultado de
# una pasada fallida, de un error ante Mycroft y de una respuesta en la confrontación: al recargar, figuran como hechos
# y no se pueden repetir. Game.act escribe ANTES de devolver toda acción comprometida; las libres se difieren.
# «Matar» = no llamar a flush/end_session: se lee el archivo tal como quedó en disco y se re-ejecuta.
extends "res://tests/test_base.gd"

const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")
const Fakes = preload("res://tests/fixtures/sim/fakes.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const Actions = preload("res://core/sim/actions.gd")
const J = preload("res://core/util/j.gd")

var _old := []

func before_each() -> void:
	_old = [Game.save_path, Game.repo_override, Game.sim_handlers]

func after_each() -> void:
	Game._dirty = false
	Game.end_session()
	Game.save_path = _old[0]
	Game.repo_override = _old[1]
	Game.sim_handlers = _old[2]

func _start(name: String) -> void:
	Game.save_path = tmp_dir().path_join(name)
	Game.repo_override = Kit.repo()
	Game.sim_handlers = Fakes.new().handlers()
	ok(Game.new_session(3), "nueva partida")

# Estado que vería un proceso nuevo que lee el disco ahora mismo.
func _killed_and_reloaded():
	var r: Dictionary = EventLog.read(Game.save_path)
	ok(r.ok, str(r))
	return GameSim.replay(Kit.repo(), int(r.header.seed), r.actions, Fakes.new().handlers())

func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = Game.act(a)
	ok(r.ok, "%s -> %s" % [str(a), str(r)])
	return r

# Avanza con Game.act (stay home, informes «sin novedad», dormir) hasta (day, slot) en desk/confront.
func _advance(day: int, slot: String) -> void:
	for _i in 200:
		var c: Dictionary = Game.sim.q_clock()
		if int(c.day) == day and String(c.slot) == slot and String(c.phase) in ["desk", "confront"]:
			return
		match String(c.phase):
			"prologue":
				for a in Kit.prologue():
					_act(a)
			"desk":
				_act({"t": "end_slot"})
			"visit", "scene":
				_act({"t": "leave"})
			"night":
				if Game.sim.q_report_status().due:
					_act({"t": "report_submit", "mode": "nada", "items": []})
				else:
					_act({"t": "sleep"})
			_:
				fail("fase " + String(c.phase))
				return
	fail("no llegó a %d.%s" % [day, slot])

func _last_line() -> String:
	var lines := FileAccess.get_file_as_string(Game.save_path).strip_edges().split("\n")
	return lines[lines.size() - 1]

func test_commit_written_before_return_free_actions_deferred():
	_start("a.jsonl")
	ok(Game.has_save(), "la cabecera se escribe al empezar")
	var a := {"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": 0, "block": 0}, "from": 0, "len": 9}
	_act(a)
	var txt := FileAccess.get_file_as_string(Game.save_path)
	eq(txt.strip_edges().split("\n").size(), 1, "la acción libre todavía no está en disco (debounce)")
	ok(Game._dirty)
	for x in Kit.prologue().slice(1, 10):
		_act(x)
	var ad: Dictionary = Kit.prologue()[9]
	eq(_last_line(), J.stringify_canon(Actions.normalize(ad)), "la comprometida ya está en disco al volver")
	eq(FileAccess.get_file_as_string(Game.save_path).strip_edges().split("\n").size(), 11, "con todo lo anterior")
	no(Game._dirty)
	# una acción rechazada no se escribe
	var before := FileAccess.get_file_as_bytes(Game.save_path)
	no(Game.act({"t": "go", "place": "L2", "seat": 1}).ok)
	eq(FileAccess.get_file_as_bytes(Game.save_path), before)

func test_failed_pass_survives_kill():
	_start("pass.jsonl")
	_advance(1, "M")
	_act({"t": "entry_new", "folio": "varios", "template": "T1"})
	var r := _act({"t": "pass_clean", "entries": ["AS001", "AS002"]})
	no(r.inked, "pasada fallida")
	var s2 = _killed_and_reloaded()
	eq(s2.replay_errors, 0)
	eq(s2.q_clock().passes_left, 0, "la pasada gastada figura al recargar")
	eq(s2.st.ded.passes.size(), 1)
	ok(s2.st.ded.entries.has("AS002"), "la acción libre previa también (va con el compromiso)")
	eq(s2.apply({"t": "pass_clean", "entries": ["AS001", "AS002"]}).err, "sin_pasada", "no se puede deshacer ni repetir")
	eq(s2.state_hash(), Game.sim.state_hash())

func test_mycroft_error_survives_kill():
	_start("mycroft.jsonl")
	_advance(8, "T")
	_act({"t": "go", "place": "L5", "area": "forasteros"})
	var r := _act({"t": "present", "char": "mycroft", "item": {"kind": "entry", "id": "AS001"}})
	eq(r.outcome, "error")
	var s2 = _killed_and_reloaded()
	eq(s2.st.scenes._fake_mycroft.errors, 1, "el error figura")
	var shows := 0
	for ev in s2.st.events:
		if ev.type == "show":
			shows += 1
	eq(shows, 1)
	_act({"t": "present", "char": "mycroft", "item": {"kind": "entry", "id": "AS001"}})
	var s3 = _killed_and_reloaded()
	eq(s3.st.flags.get("forasteros_cerrada", false), true, "el segundo error cierra la Sala")
	_act({"t": "leave"})
	_act({"t": "end_slot"})
	for p in Game.sim.q_places():
		if p.id == "L5" and p.area == "forasteros":
			no(p.open, "persiana baja")

func test_confrontation_answer_survives_kill():
	_start("confront.jsonl")
	_advance(10, "M")
	eq(Game.sim.q_clock().phase, "confront")
	var r := _act({"t": "confront", "step": 1, "item": {"kind": "clip", "id": "mal"}})
	eq(r.errors, 1)
	var s2 = _killed_and_reloaded()
	eq(s2.st.scenes._fake_confront.errors, 1, "la respuesta figura")
	eq(s2.st.scenes._fake_confront.step, 1)
	eq(s2.apply({"t": "confront", "step": 1, "item": {}}).err, "paso", "no se responde dos veces")
	eq(s2.state_hash(), Game.sim.state_hash())

func test_truncated_last_line_and_other_version():
	_start("trunc.jsonl")
	for a in Kit.prologue():
		_act(a)
	var h: String = Game.sim.state_hash()
	var n: int = Game.sim.actions_log().size()
	Game.end_session()
	var f := FileAccess.open(Game.save_path, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("{\"t\":\"go\",\"pla")
	f.close()
	ok(Game.continue_session())
	eq(Game.sim.actions_log().size(), n, "la línea truncada se descarta")
	eq(Game.sim.state_hash(), h)
	no(FileAccess.get_file_as_string(Game.save_path).contains("\"pla"), "se reescribió el registro canónico")
	Game.end_session()
	# otra versión del contenido: aviso y se intenta igual
	var txt := FileAccess.get_file_as_string(Game.save_path)
	var lines := txt.split("\n")
	var hdr = J.parse_str(lines[0])
	hdr["content"] = "otra"
	lines[0] = J.stringify_canon(hdr)
	var fw := FileAccess.open(Game.save_path, FileAccess.WRITE)
	fw.store_string("\n".join(lines))
	fw.close()
	var got: Array = []
	var cb := func(k): got.append(k)
	Game.notice.connect(cb)
	ok(Game.continue_session())
	Game.notice.disconnect(cb)
	has(got, "core.save.otra_version")
	eq(Game.sim.state_hash(), h)

func test_no_save_and_signals():
	Game.save_path = tmp_dir().path_join("nada.jsonl")
	Game.repo_override = Kit.repo()
	Game.sim_handlers = Fakes.new().handlers()
	no(Game.has_save())
	no(Game.continue_session())
	eq(Game.act({"t": "end_slot"}).err, "no_sim")
	var kinds: Array = []
	var cb := func(k, p): kinds.append(k)
	Game.sim_changed.connect(cb)
	var started := [0]
	var cs := func(): started[0] += 1
	Game.session_started.connect(cs)
	ok(Game.new_session(4))
	eq(started[0], 1)
	_act(Kit.prologue()[0])
	Game.sim_changed.disconnect(cb)
	Game.session_started.disconnect(cs)
	ok(kinds.size() > 0, "sim_changed reexpide GameSim.changed")
	no(kinds.has("reaction"))

func test_free_actions_debounced_and_close_request_flush():
	_start("deb.jsonl")
	var a: Dictionary = Kit.prologue()[0]
	_act(a)
	ok(Game._dirty)
	eq(FileAccess.get_file_as_string(Game.save_path).strip_edges().split("\n").size(), 1)
	await tree.create_timer(Game.DEBOUNCE_S + 0.5).timeout
	no(Game._dirty, "el debounce escribió")
	eq(FileAccess.get_file_as_string(Game.save_path).strip_edges().split("\n").size(), 2)
	_act(Kit.prologue()[1])
	ok(Game._dirty)
	Game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	no(Game._dirty, "al cerrar la ventana se escribe")
	eq(FileAccess.get_file_as_string(Game.save_path).strip_edges().split("\n").size(), 3)
