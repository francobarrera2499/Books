# devtools/drivers/w4novato_trays.gd — W4 playtest (diagnóstico): rehace la partida del novato (.work/w4nov/save_epilogo.jsonl)
# y lista, para cada día, lo que llegó a la bandeja (q_tray) y las líneas del diario, para ver si cada mañana hubo una
# respuesta perceptible y qué llegó el día 10 (antes de la confrontación).
# ./godot.sh --headless -s devtools/drivers/w4novato_trays.gd
extends SceneTree

const GameSim = preload("res://core/sim/game_sim.gd")

func _init() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join("../.work/w4nov/save_epilogo.jsonl")
	var f := FileAccess.open(path, FileAccess.READ)
	var head: Dictionary = JSON.parse_string(f.get_line())
	var acts: Array = []
	while not f.eof_reached():
		var ln := f.get_line().strip_edges()
		if ln != "":
			acts.append(JSON.parse_string(ln))
	var repo = load("res://core/data/data_repo.gd").fresh("res://data")
	var sim = GameSim.replay(repo, int(head.seed), acts)
	print("TRAYS acciones=%d fase=%s" % [acts.size(), String(sim.q_clock().phase)])
	for d in range(1, 11):
		var items: Array = sim.q_tray(d)
		print("TRAYS día %d: %s" % [d, str(items.map(func(it): return "%s «%s» (%s)" % [String(it.view), String(it.title), String(it.how)]))])
	quit(0)
