# devtools/drivers/w4fix_replay.gd — mide la reanudación (GameSim.replay) sobre el registro de un bot real (W4 fix core_data).
# ./godot.sh --headless -s devtools/drivers/w4fix_replay.gd -- [bot] [cortes separados por coma]
extends SceneTree
const BotData = preload("res://devtools/bots/bot_data.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const J = preload("res://core/util/j.gd")
func _init():
	_run.call_deferred()
func _run():
	var args := OS.get_cmdline_user_args()
	var bot := String(args[0]) if args.size() > 0 else "recorta_todo"
	var cuts: Array = []
	if args.size() > 1:
		for c in String(args[1]).split(","):
			cuts.append(int(c))
	var repo = BotData.repo("real")
	var out: Array = []
	var t0 := Time.get_ticks_msec()
	var r := RunBots.run_one(repo, bot, 1, 20000, 900000, out)
	var lg: Array = out[0].sim.actions_log()
	print("BOT %s: %d acciones, ending %s, play %d ms" % [bot, lg.size(), r.get("ending", ""), Time.get_ticks_msec() - t0])
	# desglose: ms por tipo de acción en el último tercio del registro (sin copia de reversión)
	var sp = GameSim.new(repo, 1)
	var per := {}
	var third := lg.size() * 2 / 3
	for i in lg.size():
		var ta := Time.get_ticks_usec()
		sp._apply(lg[i], true, false)
		if i >= third:
			var k := String(lg[i].t)
			if not per.has(k):
				per[k] = [0, 0.0]
			per[k][0] += 1
			per[k][1] += (Time.get_ticks_usec() - ta) / 1000.0
	for k in per:
		print("TIPO %s n=%d total_ms=%.0f media_ms=%.1f" % [k, per[k][0], per[k][1], per[k][1] / maxf(1, per[k][0])])
	if cuts.is_empty():
		cuts = [lg.size()]
	for n in cuts:
		var part := lg.slice(0, mini(n, lg.size()))
		var t1 := Time.get_ticks_msec()
		var s = GameSim.replay(repo, 1, part)
		var dt := Time.get_ticks_msec() - t1
		var same := ""
		if part.size() == lg.size():
			same = " hash igual %s" % str(s.state_hash() == out[0].sim.state_hash())
		var t2 := Time.get_ticks_usec()
		s.apply({"t": "link", "a": "RC0001", "b": "RC0002", "note": ""})
		var one := (Time.get_ticks_usec() - t2) / 1000.0
		print("REPLAY n=%d ms=%d errores=%d una_libre_ms=%.1f%s" % [part.size(), dt, int(s.replay_errors), one, same])
	quit(0)
