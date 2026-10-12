# devtools/drivers/w2placesc_prewarm.gd — W2-PLACES-C. «Entrada al lugar sin tirón visible» (§10): para cada lugar de
# este paquete mide, con ventana, el peor cuadro al entrar SIN precalentar (proceso nuevo: pipelines fríos) y, para el
# lugar siguiente, CON WorldRoot.prewarm detrás de un fundido (como hará Shell). Imprime una tabla y guarda una captura
# de control. Tiempo real: sólo diagnóstico (devtools), nunca lógica.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pc res://devtools/drivers/w2placesc_prewarm.gd
extends RefCounted

const WR = preload("res://world/world_root.gd")
const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")

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
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	var specs := [["L4", "consulta", 3, "M", ""], ["L5", "porteria", 3, "T", ""], ["L5", "forasteros", 8, "N", ""], ["L6", "sala", 3, "M", ""],
		["plate:RB", "*", 0, "T", "journal"], ["plate:RB", "*", 0, "T", "foto"]]
	var rows: Array = []
	# referencia: el primer lugar entra en frío (proceso nuevo, sin precalentar)
	for i in specs.size() + 1:
		var sp: Array = specs[0] if i == 0 else specs[i - 1]
		var warm := i > 0
		var pid: String = sp[0]
		var place := PC.load_json("res://data/places/%s.json" % pid) if not pid.begins_with("plate:") else PC.load_json("res://data/plates/%s.json" % pid.substr(6))
		var snap := PC.snapshot(place, sp[1], sp[3], sp[2], sp[4])
		if warm:
			wr.show_plate(PC.snapshot(PC.load_json("res://tests/fixtures/places/sample.json"), "estudio", "M", 3), PC.load_json("res://tests/fixtures/places/sample.json"))
			await _worst(tool, 3)
			await wr.prewarm(place)
		await _worst(tool, 3)
		wr.show_plate(snap, place)
		var first := await _worst(tool, 1)
		var rest := await _worst(tool, 10)
		rows.append("%-9s %-10s %-8s %-9s primer cuadro=%6.1f ms  peor de los 10 siguientes=%5.1f ms" % [pid, sp[1], sp[4], "precal." if warm else "en frío", first, rest])
	for r in rows: print("PREWARM ", r)
	await tool.snap("prewarm_ultimo")
