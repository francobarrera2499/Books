# v3pieza_cortina (REACCIONES-PIEZA, verificación GDD_v3 §4.3): la cortina al entrar con la ventana abierta («techos»),
# en el tiempo: 0,3 s, 1,2 s, 2,4 s y en reposo (6 s). Desde el encuadre del escritorio, como en el juego.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3pc res://devtools/drivers/v3pieza_cortina.gd
extends RefCounted

const WR = preload("res://world/world_root.gd")
const DataRepo = preload("res://core/data/data_repo.gd")

func _snap(pl: Dictionary, variant: String) -> Dictionary:
	var vd: Dictionary = pl.get("variants", {}).get(variant, {}) if variant != "" else {}
	var hide: Array = vd.get("hide_nodes", [])
	var nodes: Array = []
	for n in pl.get("nodes", []) + vd.get("add_nodes", []):
		if String(n.get("area", "*")) == "tienda" or hide.has(String(n.id)) or nodes.has(String(n.id)):
			continue
		nodes.append(String(n.id))
	return {"id": "PL.L1.v3pc.%s" % variant, "place": "L1", "area": "buhardilla", "day": 4, "slot": "M", "variant": variant,
		"nodes": nodes, "chars": [], "silhouettes": [], "frame": "escritorio"}

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var rp = DataRepo.load_dir("res://data")
	var pl: Dictionary = rp.place("L1")
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_frame("escritorio", true)
	wr.show_plate(_snap(pl, "techos"), pl)
	wr.set_orbit_enabled(false)
	wr.set_frame("escritorio", true)
	var t0 := Time.get_ticks_msec()
	for mark in [0.3, 1.2, 2.4, 6.0]:
		while (Time.get_ticks_msec() - t0) / 1000.0 < mark:
			await tool.frames(1)
		await tool.snap("t%02d" % int(mark * 10))
