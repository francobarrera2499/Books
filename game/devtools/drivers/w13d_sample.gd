# devtools/drivers/w13d_sample.gd — W1-3D. Capturas del fixture tests/fixtures/places/sample.json vía WorldRoot.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w13d res://devtools/drivers/w13d_sample.gd
# Salida: .work/shots/w13d_sample_<frame>.png (mañana, con grabado si W1-POST está), w13d_sample_<frame>_<franja>.png,
#         w13d_sample_<frame>_crudo.png (sin grabado), w13d_sample_orbita.png, w13d_sample_examinar.png, w13d_sample_registrada.png
# Env W13D_QUICK=1: sólo los encuadres en M (con y sin grabado).
extends RefCounted

const WR = preload("res://world/world_root.gd")

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var place: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/places/sample.json"))
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	var frames_ids: Array = []
	for f in place["frames"]: frames_ids.append(str(f["id"]))
	var all_nodes: Array = []
	for n in place["nodes"]: all_nodes.append(str(n["id"]))
	var quick := OS.get_environment("W13D_QUICK") != ""
	var slots := ["M"] if quick else ["M", "T", "N"]
	for slot in slots:
		var snap := {"id": "PL.SAMPLE.3.%s" % slot, "place": "SAMPLE", "area": "estudio", "day": 3, "slot": slot, "variant": "",
			"nodes": all_nodes, "chars": [{"id": "watson", "pose": "de_pie", "trait": "bombin_crespon"}],
			"silhouettes": ["wiggins", "m3_hombres", "cochero"], "frame": "puerta"}
		wr.show_plate(snap, place)
		for f in frames_ids:
			wr.set_frame(f, true)
			await tool.frames(6)
			await tool.snap("sample_%s" % f if slot == "M" else "sample_%s_%s" % [f, slot])
			if slot == "M":
				wr.set_engraving(false)
				var post = wr.engraving_post()
				if post != null and post.has_method("set_enabled"): post.set_enabled(false)
				await tool.frames(3)
				await tool.snap("sample_%s_crudo" % f)
				if post != null and post.has_method("set_enabled"): post.set_enabled(true)
				wr.set_engraving(true)
	if quick: return
	var snapm := {"id": "PL.SAMPLE.3.M", "place": "SAMPLE", "area": "estudio", "day": 3, "slot": "M", "variant": "",
		"nodes": all_nodes, "chars": [{"id": "watson", "pose": "de_pie", "trait": "bombin_crespon"}],
		"silhouettes": ["wiggins", "m3_hombres", "cochero"], "frame": "puerta"}
	wr.show_plate(snapm, place)
	wr.set_frame("puerta", true)
	wr.rig.orbit_by(22.0, 8.0)
	await tool.frames(6)
	await tool.snap("sample_orbita")
	wr.set_frame("escritorio", true)
	wr.examine("lupa")
	await tool.frames(6)
	await tool.snap("sample_examinar")
	var nodes_v: Array = all_nodes.duplicate(); nodes_v.append("ceniza")
	var snapv := {"id": "PL.SAMPLE.4.M", "place": "SAMPLE", "area": "estudio", "day": 4, "slot": "M", "variant": "registrada",
		"nodes": nodes_v, "chars": [], "silhouettes": ["wiggins"], "frame": "escritorio"}
	wr.show_plate(snapv, place)
	await tool.frames(6)
	await tool.snap("sample_registrada")
