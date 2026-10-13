# W4-EPILOGUE: sonda headless (no captura). Juega un bot hasta el epílogo con data/ real e imprime lo que el epílogo lee.
# ./godot.sh --headless -s devtools/drivers/w4epilogue_probe.gd -- [bot] [semilla]
extends SceneTree

const RunBots = preload("res://devtools/bots/run_bots.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var bot_name := String(args[0]) if args.size() > 0 else "deductor"
	var seed := int(args[1]) if args.size() > 1 else 1
	var repo = root.get_node("Data").repo()
	print("errores repo: ", repo.errors().size())
	var b = RunBots.make(bot_name)
	var sim = GameSim.new(repo, seed)
	b.budget_ms = 300000
	b.setup(sim, seed)
	var t0 := Time.get_ticks_msec()
	for i in 20000:
		if String(sim.q_clock().phase) == "epilogue":
			break
		if not b.step():
			break
	print("ms: ", Time.get_ticks_msec() - t0, " fase: ", sim.q_clock().phase)
	var ep: Dictionary = sim.q_epilogue()
	print("ending: ", ep.get("ending", {}).get("ending", ""), " card: ", ep.get("ending", {}).get("card", ""))
	print("variants: ", ep.get("ending", {}).get("variants", []))
	print("noche: ", ep.get("noche_final", ""), " publica: ", ep.get("publica_errata", ""))
	print("scene: ", JSON.stringify(sim.q_scene()).left(600))
	print("bp: ", sim.q_blue_pencil())
	var acc: Array = sim.q_accessible()
	print("accesible D38: ", acc.filter(func(v): return String(v.view).begins_with("D38")))
	var v: Dictionary = sim.q_view("D38@L1")
	print("view keys: ", v.keys(), " pages: ", (v.get("pages", []) as Array).size())
	for pi in (v.get("pages", []) as Array).size():
		print(" page ", pi, " blocks ", v.pages[pi].size(), " ", v.pages[pi].map(func(bk): return [bk.get("doc", ""), String(bk.get("parsed", {}).get("plain", "")).left(60)]))
	print("tramo: ", repo.doc_tramo("D38", "hombre_alto"))
	print("ledger: ", JSON.stringify(sim.q_ledger()).left(800))
	print("tray: ", sim.q_tray())
	quit(0)
