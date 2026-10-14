# devtools/drivers/v3mundo_guion.gd — UI-MUNDO: regenera tests/fixtures/w3shell/guion_dia1.jsonl (el guion de las
# capturas: el tutorial v3 del prólogo + dormir, sobre el dataset fixture de W3-SHELL).
#   ./godot.sh --headless -s devtools/drivers/v3mundo_guion.gd
extends SceneTree

const W = preload("res://tests/fixtures/w3shell/walk.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var repo = W.repo()
	var sim = GameSim.new(repo, 1894)
	var acts: Array = []
	var act := func(a: Dictionary) -> Dictionary:
		var r: Dictionary = sim.apply(a)
		if bool(r.get("ok", false)):
			acts.append(a.duplicate(true))
		return r
	W.errs = []
	W.tutorial(sim, act)
	act.call({"t": "sleep"})
	print("errores: ", W.errs)
	var p := ProjectSettings.globalize_path("res://tests/fixtures/w3shell/guion_dia1.jsonl")
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(W.jsonl(acts))
	f.close()
	print("escrito ", p, " (", acts.size(), " acciones)")
	quit(0)
