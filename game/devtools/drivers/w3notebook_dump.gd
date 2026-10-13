# W3-NOTEBOOK: vuelca (headless) lo que el cuaderno lee del recorrido de integración (q_clips, q_index, q_pairs, q_diary,
# q_marginalia). ./godot.sh --headless -s devtools/shot.gd -- res://devtools/blank.tscn nbdump res://devtools/drivers/w3notebook_dump.gd
extends RefCounted

const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const J = preload("res://core/util/j.gd")

func drive(tool, scene) -> void:
	var sim = NbWalk.sim()
	print("ERRS ", NbWalk.errs)
	if sim == null:
		return
	for c in sim.q_clips():
		print("CLIP ", J.stringify_canon(c))
	print("INDEX ", J.stringify_canon(sim.q_index()))
	for p in sim.q_pairs():
		print("PAIR ", J.stringify_canon(p))
	for d in sim.q_diary():
		var x: Dictionary = d.duplicate()
		x.erase("parsed")
		print("DIARY ", J.stringify_canon(x))
	print("MARG ", J.stringify_canon(sim.q_marginalia()))
	print("CLOCK ", J.stringify_canon(sim.q_clock()))
