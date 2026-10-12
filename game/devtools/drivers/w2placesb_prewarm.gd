# devtools/drivers/w2placesb_prewarm.gd — W2-PLACES-B. «Entrada al lugar sin tirón visible» (§10): para L3, L7, L8 y
# PARK mide, con ventana, el peor cuadro al entrar en frío (proceso nuevo: pipelines sin compilar) y al entrar después
# de WorldRoot.prewarm detrás de un fundido (como hará Shell). Tiempo real: sólo diagnóstico (devtools), nunca lógica.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pbw res://devtools/drivers/w2placesb_prewarm.gd
extends RefCounted

const WR = preload("res://world/world_root.gd")
const DRV = preload("res://devtools/drivers/w2placesb_lugares.gd")

func _worst(tool, n: int) -> float:
	var worst := 0.0
	var t := Time.get_ticks_usec()
	for i in n:
		await tool.process_frame
		var t2 := Time.get_ticks_usec()
		worst = maxf(worst, (t2 - t) / 1000.0)
		t = t2
	return worst

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var repo = load("res://core/data/data_repo.gd").load_dir("res://data")
	var sample: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/places/sample.json"))
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	# [lugar, área, día, franja]; cada lugar se mide dos veces: en frío (primera vez en el proceso) y precalentado
	var specs := [["L3", "calle", 8, "M"], ["L7", "exterior", 6, "T"], ["L8", "interior", 8, "M"], ["PARK", "*", 10, "T"], ["L3", "interior", 9, "T"]]
	var rows: Array = []
	for warm in [false, true]:
		for sp in specs:
			var place: Dictionary = repo.place(sp[0])
			if place.is_empty(): place = repo.plate(sp[0])
			var snap: Dictionary = DRV.snapshot(repo, place, sp[1], sp[2], sp[3])
			# salir a otro lugar (el fixture) para que la entrada sea una reconstrucción completa
			wr.show_plate({"id": "x", "place": "SAMPLE", "area": "estudio", "slot": "M"}, sample)
			await _worst(tool, 3)
			if warm:
				await wr.prewarm(place)
				await _worst(tool, 2)
			var t0 := Time.get_ticks_usec()
			wr.show_plate(snap, place)
			var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var first := await _worst(tool, 1)
			var rest := await _worst(tool, 10)
			rows.append("%-5s %-9s %-8s armado=%6.1f ms  primer cuadro=%6.1f ms  peor de los 10 siguientes=%5.1f ms" % [sp[0], sp[1], "precal." if warm else "en frío", build_ms, first, rest])
	for r in rows: print("PREWARM ", r)
	await tool.snap("ultimo")
