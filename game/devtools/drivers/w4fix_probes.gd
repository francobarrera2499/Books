# devtools/drivers/w4fix_probes.gd — corre las sondas con guion (bot_guion) sobre data/ real e imprime lo entregado.
extends SceneTree
const BotData = preload("res://devtools/bots/bot_data.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const BEATS := [
	{"tk": "1.M", "go": ["L4", "consulta"], "acts": [{"t": "assert", "char": "watson", "assertion": "cn.chelsea"}]},
	{"tk": "4.M", "go": ["L4", "consulta"], "acts": [{"t": "assert", "char": "watson", "assertion": "cn.boda"}]},
	{"tk": "3.T", "go": ["L3", "calle"], "acts": [{"t": "pay", "char": "wiggins", "amount_d": 12}]},
	{"tk": "5.M", "go": ["L3", "calle"], "acts": [{"t": "assert", "char": "wiggins", "assertion": "cn.edimburgo"}]},
	{"tk": "6.M", "go": ["L3", "calle"], "acts": [{"t": "assert", "char": "wiggins", "assertion": "cn.chelsea"}]},
]
func _init():
	_run.call_deferred()
func _run():
	var repo = BotData.repo("real")
	for mode in ["beats", "leak"]:
		var b = load("res://devtools/bots/bot_guion.gd").new()
		var sim = GameSim.new(repo, 1)
		b.budget_ms = 600000
		b.setup(sim, 1)
		if mode == "beats":
			b.beats = BEATS.duplicate(true)
		else:
			b.leak_reports = [1, 2]
		var r: Dictionary = b.play(20000)
		print("PROBE %s: %s rank %d sellos %s errores %s oráculo %s runaway %s" % [mode, r.ending, int(r.rank), str(r.sealed), str((r.errors as Array).slice(0, 3)), str(r.oracle), r.runaway])
		print("PROBE %s variantes %s flags %s" % [mode, str(r.variants), str(sim.st.flags)])
		print("PROBE %s entregadas %s" % [mode, str(b.delivered())])
		print("PROBE %s beats %s" % [mode, str(b.beat_log)])
	quit(0)
