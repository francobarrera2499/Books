# devtools/drivers/w2placesc_lugares.gd — W2-PLACES-C. Capturas de L4, L5 y L6 (data/places/*.json) por área × franja ×
# encuadre, con grabado, y una toma sin grabado por área (para revisar la geometría).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w2pc res://devtools/drivers/w2placesc_lugares.gd
# Salida: .work/shots/w2pc_<lugar>_<área>_<franja>_<encuadre>.png y w2pc_<lugar>_<área>_crudo.png
# Env: W2PC_ONLY=L4|L5|L6 (un lugar), W2PC_SLOT=M (una franja), W2PC_VARIANT=prestadas (variante de L4), W2PC_RAW=1 (sólo crudo).
extends RefCounted

const WR = preload("res://world/world_root.gd")
const PC = preload("res://tests/fixtures/w2placesc/place_checks.gd")

# lugar → [[área, día, [franjas]]] según el horario de GDD§5 (L4 consulta M; domingo T en el estudio; L5 portería
# cualquier franja, Forasteros días 8–9 T/N; L6 M y T)
const PLAN := {
	"L4": [["consulta", 3, ["M"]], ["estudio", 6, ["T"]]],
	"L5": [["porteria", 3, ["M", "T", "N"]], ["forasteros", 8, ["T", "N"]]],
	"L6": [["sala", 3, ["M", "T"]]],
}

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	var only := OS.get_environment("W2PC_ONLY")
	var only_slot := OS.get_environment("W2PC_SLOT")
	var variant := OS.get_environment("W2PC_VARIANT")
	var raw_only := OS.get_environment("W2PC_RAW") != ""
	for pid in PLAN:
		if only != "" and only != pid: continue
		var place: Dictionary = PC.load_json("res://data/places/%s.json" % pid)
		if place.is_empty(): continue
		for plan in PLAN[pid]:
			var area: String = plan[0]
			for slot in plan[2]:
				if only_slot != "" and only_slot != slot: continue
				var snap := PC.snapshot(place, area, slot, int(plan[1]), variant)
				wr.show_plate(snap, place)
				await tool.frames(4)
				if not raw_only:
					for f in PC.frames_for(place, area):
						wr.set_frame(f, true)
						await tool.frames(6)
						await tool.snap("%s_%s_%s_%s%s" % [pid, area, slot, f, ("_" + variant) if variant != "" else ""])
				if slot == plan[2][0]:
					var post = wr.engraving_post()
					wr.set_frame(PC.frames_for(place, area)[0], true)
					if post != null and post.has_method("set_enabled"): post.set_enabled(false)
					wr.set_engraving(false)
					for f in PC.frames_for(place, area):
						if not raw_only and f != PC.frames_for(place, area)[0]: continue
						wr.set_frame(f, true)
						await tool.frames(4)
						await tool.snap("%s_%s_crudo_%s" % [pid, area, f])
					wr.set_engraving(true)
					if post != null and post.has_method("set_enabled"): post.set_enabled(true)
