# devtools/drivers/w2placesc_rb.gd — W2-PLACES-C. Capturas de la lámina del Reichenbach (data/plates/RB.json):
# cada variante (fina, journal, foto) × cada encuadre, con grabado; y una toma sin grabado por variante.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pc res://devtools/drivers/w2placesc_rb.gd
# Salida: .work/shots/w2pc_rb_<variante>_<encuadre>.png, w2pc_rb_<variante>_crudo.png
# Env W2PC_ONLY=<variante> limita a una variante.
extends RefCounted

const WR = preload("res://world/world_root.gd")
const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var plate: Dictionary = PC.load_json("res://data/plates/RB.json")
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	var only := OS.get_environment("W2PC_ONLY")
	for v in ["fina", "journal", "foto"]:
		if only != "" and only != v: continue
		var snap := PC.snapshot(plate, "*", "T", 0, v)
		wr.show_plate(snap, plate)
		for f in plate["frames"]:
			wr.set_frame(str(f["id"]), true)
			await tool.frames(8)
			await tool.snap("rb_%s_%s" % [v, f["id"]])
		wr.set_frame("otra_orilla", true)
		var post = wr.engraving_post()
		if post != null and post.has_method("set_enabled"): post.set_enabled(false)
		wr.set_engraving(false)
		await tool.frames(4)
		await tool.snap("rb_%s_crudo" % v)
		wr.set_engraving(true)
		if post != null and post.has_method("set_enabled"): post.set_enabled(true)
