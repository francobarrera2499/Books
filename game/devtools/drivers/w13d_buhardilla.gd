# devtools/drivers/w13d_buhardilla.gd — W1-3D. Buhardilla de demostración armada con la biblioteca base (NO es L1:
# L1 es de W2-PLACES-A). Verifica attic() desde adentro, ventana a la calle con aleros enfrente y luz de gas de noche.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w13d res://devtools/drivers/w13d_buhardilla.gd
extends RefCounted

const WR = preload("res://world/world_root.gd")

func _place() -> Dictionary:
	return {"id": "BUH", "name": "Buhardilla de prueba", "frames": [
		{"id": "escritorio", "area": "*", "pos": [0.9, 1.45, 1.3], "look": [-0.6, 0.85, -0.9], "fov": 50},
		{"id": "ventana", "area": "*", "pos": [0.2, 1.5, 0.9], "look": [0.0, 1.35, -3.0], "fov": 50},
		{"id": "pared", "area": "*", "pos": [-0.6, 1.5, -0.4], "look": [1.6, 1.0, 0.8], "fov": 55}],
		"light": {"M": "manana_perla", "T": "tarde", "N": "gas"},
		"props": [
			{"id": "cuarto", "type": "architecture.attic", "pos": [0, 0, 0], "rot": 0, "p": {"w": 4.6, "d": 4.0, "h": 2.7, "slope": 42, "knee": 1.0,
				"openings": [{"wall": "n", "kind": "window", "x": 0.0, "w": 0.9, "h": 1.25, "sill": 0.85, "panes": 4}, {"wall": "s", "kind": "door", "x": 0.2, "w": 0.8, "h": 2.0, "open": 0.2}]}},
			{"id": "escritorio", "type": "furniture.desk", "pos": [-0.75, 0, -1.4], "rot": 0, "p": {"w": 1.3, "d": 0.7, "pigeonholes": false}},
			{"id": "silla", "type": "furniture.chair", "pos": [-0.75, 0, -0.75], "rot": 160, "p": {"style": "windsor"}},
			{"id": "tomos", "type": "small.tome_set", "pos": [-1.15, 0.762, -1.62], "rot": 0, "p": {"n": 5}},
			{"id": "lampara", "type": "small.desk_lamp", "pos": [-0.25, 0.762, -1.6], "rot": 0, "p": {}},
			{"id": "libro", "type": "small.open_ledger_book", "pos": [-0.75, 0.762, -1.3], "rot": 4, "p": {}},
			{"id": "tijera", "type": "small.scissors", "pos": [-0.35, 0.762, -1.25], "rot": -40, "p": {}},
			{"id": "bandeja", "type": "small.tray", "pos": [-1.25, 0.762, -1.25], "rot": 10, "p": {}},
			{"id": "calendario", "type": "small.desk_calendar", "pos": [-0.15, 0.762, -1.35], "rot": -20, "p": {"text": "27", "text2": "MARZO"}},
			{"id": "estufa", "type": "furniture.stove", "pos": [1.55, 0, -1.2], "rot": -30, "p": {"h": 2.0, "lit": true}},
			{"id": "cama", "type": "furniture.bed", "pos": [1.55, 0, 0.75], "rot": 0, "p": {"w": 0.95, "d": 1.9}},
			{"id": "estante", "type": "furniture.bookshelf", "pos": [-2.0, 0, 0.6], "rot": 90, "p": {"w": 1.4, "h": 0.95, "rows": 2, "d": 0.3, "seed": 21}},
			{"id": "mapa", "type": "small.map_board", "pos": [-0.9, 1.25, 1.98], "rot": 180, "p": {}},
			{"id": "enfrente", "type": "architecture.facade", "pos": [0.0, -9.0, -9.5], "rot": 0, "p": {"w": 8.0, "h": 12.0, "floors": 4, "bays": 4, "door_bay": 1, "seed": 6, "chimneys": true}},
			{"id": "alero", "type": "architecture.eave", "pos": [0.0, 2.9, -9.6], "rot": 0, "p": {"len": 8.0, "depth": 0.7}}
		], "nodes": []}

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var place := _place()
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	for slot in ["M", "N"]:
		wr.show_plate({"id": "BUH." + slot, "place": "BUH", "area": "*", "slot": slot, "frame": "escritorio"}, place)
		wr.set_orbit_enabled(false)
		for f in ["escritorio", "ventana", "pared"]:
			wr.set_frame(f, true)
			await tool.frames(6)
			await tool.snap("buh_%s_%s" % [f, slot])
