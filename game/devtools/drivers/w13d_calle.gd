# devtools/drivers/w13d_calle.gd — W1-3D. Escena de calle armada sólo con la biblioteca base (no es un lugar del juego):
# terrazas de ladrillo enfrentadas, verjas, faroles, coche de alquiler, transeúntes. Día (tarde) y noche (farol_calle).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w13d res://devtools/drivers/w13d_calle.gd
extends RefCounted

const WR = preload("res://world/world_root.gd")
const DB = preload("res://world/diorama_builder.gd")

func _place() -> Dictionary:
	var props: Array = []
	var xs := [-13.0, -6.5, 0.0, 6.5, 13.0]
	for i in xs.size():
		props.append({"id": "norte_%d" % i, "type": "architecture.facade", "pos": [xs[i], 0.12, -7.0], "rot": 0,
			"p": {"w": 6.5, "h": 12.5 + (i % 2) * 0.8, "floors": 4, "bays": 3, "door_bay": i % 3, "seed": 10 + i, "number": str(219 + i * 2)}})
		props.append({"id": "sur_%d" % i, "type": "architecture.facade", "pos": [xs[i] + 3.0, 0.12, 9.0], "rot": 180,
			"p": {"w": 6.5, "h": 12.0, "floors": 4, "bays": 3, "door_bay": (i + 1) % 3, "seed": 30 + i, "shop_front": i == 2, "sign": "ESTANCO" if i == 2 else ""}})
	props.append({"id": "vereda_n", "type": "street.pavement", "pos": [0, 0, -4.4], "rot": 0, "p": {"w": 36, "d": 5.2, "kind": "losas", "kerb": "+z"}})
	props.append({"id": "vereda_s", "type": "street.pavement", "pos": [0, 0, 6.6], "rot": 0, "p": {"w": 36, "d": 4.8, "kind": "losas", "kerb": "-z"}})
	props.append({"id": "calzada", "type": "street.pavement", "pos": [0, -0.04, 1.1], "rot": 0, "p": {"w": 36, "d": 6.2, "kind": "madera"}})
	for k in 4:
		props.append({"id": "farol_%d" % k, "type": "street.gas_lamp", "pos": [-12.0 + k * 8.0, 0.12, -2.2], "rot": 0, "p": {"h": 3.6}})
	props.append({"id": "coche", "type": "street.cab", "pos": [2.0, -0.02, 1.0], "rot": 90, "p": {"kind": "hansom"}})
	props.append({"id": "coche2", "type": "street.cab", "pos": [-9.0, -0.02, 2.6], "rot": -90, "p": {"kind": "growler"}})
	props.append({"id": "buzon", "type": "street.post_box", "pos": [5.5, 0.12, -2.4], "rot": 0, "p": {}})
	props.append({"id": "gente", "type": "crowd.make", "pos": [-3.0, 0.12, -3.6], "rot": 0, "p": {"n": 7, "seed": 5, "w": 9.0, "d": 1.6}})
	props.append({"id": "gente2", "type": "crowd.make", "pos": [6.0, 0.12, 6.0], "rot": 0, "p": {"n": 5, "seed": 8, "w": 6.0, "d": 1.4}})
	return {"id": "CALLE", "name": "Calle de prueba", "frames": [
		{"id": "vereda", "area": "*", "pos": [9.0, 1.7, 5.4], "look": [-2.0, 3.0, -6.0], "fov": 55, "orbit": {"pivot": [0, 2, -3], "yaw": 25, "pitch": 10}},
		{"id": "alto", "area": "*", "pos": [-4.0, 8.5, 5.5], "look": [-1.0, 1.0, -5.0], "fov": 50}],
		"light": {"T": "tarde", "N": "farol_calle"}, "props": props, "nodes": [],
		"silhouettes": {"wiggins": {"frame": "vereda", "pos": [-1.0, 0.12, -3.0], "rot": 120}}}

func drive(tool, scene) -> void:
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	var place := _place()
	var t0 := Time.get_ticks_msec()
	var d := DB.build(place, {"id": "x", "slot": "T", "silhouettes": ["wiggins"]})
	print("BUILD_MS calle ", Time.get_ticks_msec() - t0, " nodos=", d.find_children("*", "", true, false).size())
	d.free()
	var wr = WR.new()
	scene.add_child(wr)
	wr.set_fast(true)
	for slot in ["T", "N"]:
		wr.show_plate({"id": "CALLE." + slot, "place": "CALLE", "area": "*", "slot": slot, "silhouettes": ["wiggins"], "frame": "vereda"}, place)
		for f in ["vereda", "alto"]:
			wr.set_frame(f, true)
			await tool.frames(6)
			await tool.snap("calle_%s_%s" % [f, slot])
