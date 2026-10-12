# Driver W1-POST: calle de Londres armada con los props de W1-3D (fachadas, farolas, coche, maniquíes, multitud)
# para ver los presets de exterior bajo el grabado. Sólo capturas (depende de world/props de W1-3D).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w1post_calle res://devtools/drivers/w1post_calle.gd
extends RefCounted

const Lighting = preload("res://world/lighting.gd")
const EngravingPost = preload("res://world/post/engraving_post.gd")
const SHOTS := [["manana_perla", "M"], ["dia_ventana", "M"], ["tarde", "T"], ["dorada_parklane", "N"], ["farol_calle", "N"], ["gas", "N"], ["noche_viento", "N"], ["electrica_fria", "M"]]

static func prop(parent: Node3D, typ: String, p: Dictionary, pos: Vector3, rot := 0.0) -> Node3D:
	var parts := typ.split(".")
	var scr = load("res://world/props/%s.gd" % parts[0])
	var n: Node3D = scr.call("build_" + parts[1], p)
	n.position = pos
	n.rotation_degrees.y = rot
	parent.add_child(n)
	return n

static func build(parent: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "Calle"
	parent.add_child(root)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	prop(props, "street.pavement", {"w": 40.0, "d": 9.0, "kind": "madera"}, Vector3(0, 0, 0))
	prop(props, "street.pavement", {"w": 40.0, "d": 3.0, "kind": "losas", "kerb": "+z"}, Vector3(0, 0, -6.0))
	prop(props, "street.pavement", {"w": 40.0, "d": 3.0, "kind": "losas", "kerb": "-z"}, Vector3(0, 0, 6.0))
	var x := -14.0
	var styles := ["stock_brick", "estuco", "stock_brick", "stock_brick", "estuco"]
	for i in 5:
		prop(props, "architecture.facade", {"w": 6.0, "h": 13.0, "floors": 4, "bays": 3, "door_bay": i % 3, "shop_front": i == 2, "style": styles[i], "seed": 30 + i, "number": str(221 + i)}, Vector3(x + i * 6.0, 0, -7.5))
	for i in 3:
		prop(props, "architecture.facade", {"w": 7.0, "h": 12.0, "floors": 4, "bays": 3, "style": "stock_brick", "seed": 50 + i}, Vector3(-10.0 + i * 7.0, 0, 7.5), 180.0)
	for lx in [-9.0, 0.0, 9.0]:
		prop(props, "street.gas_lamp", {"h": 3.4, "light": true}, Vector3(lx, 0, -4.7))
	prop(props, "street.cab", {"kind": "hansom"}, Vector3(3.5, 0, 1.2), 80.0)
	prop(props, "street.post_box", {}, Vector3(-4.0, 0, -5.0))
	var MQ = load("res://world/characters/mannequin.gd")
	var w: Node3D = MQ.make("wiggins", "gorra_larga")
	w.position = Vector3(-2.0, 0, -5.2)
	w.rotation_degrees.y = 20.0
	props.add_child(w)
	var h: Node3D = MQ.make("harris", "chistera_bigote")
	h.position = Vector3(1.0, 0, -4.4)
	h.rotation_degrees.y = -30.0
	props.add_child(h)
	var CR = load("res://world/characters/crowd.gd")
	var cr: Node3D = CR.make({"n": 8, "seed": 5, "w": 10.0, "d": 1.6, "wrapped": true})
	cr.position = Vector3(8.0, 0, 5.6)
	props.add_child(cr)
	var cam := Camera3D.new()
	cam.fov = 44.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(-6.5, 1.75, 4.2), Vector3(4.0, 3.0, -6.0))
	cam.current = true
	var post := EngravingPost.attach(cam)
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	parent.add_child(canvas)
	var band := ColorRect.new()
	band.color = Color("efe6d2")
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -78
	canvas.add_child(band)
	var cap := Label.new()
	var ff = load("res://assets/fonts/IMFeENit28P.ttf")
	if ff is Font:
		cap.add_theme_font_override("font", ff)
	cap.add_theme_font_size_override("font_size", 34)
	cap.add_theme_color_override("font_color", Color("1b1712"))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.anchor_left = 0.0
	cap.anchor_right = 1.0
	cap.anchor_top = 1.0
	cap.anchor_bottom = 1.0
	cap.offset_top = -64
	cap.offset_bottom = -16
	canvas.add_child(cap)
	return {"root": root, "cam": cam, "post": post, "caption": cap}

func drive(tool, scene) -> void:
	var sc := build(scene)
	for s in SHOTS:
		var look := Lighting.apply(sc.root, s[0], s[1])
		sc.post.set_look(look)
		sc.caption.text = "Baker Street — %s, franja %s" % [s[0], s[1]]
		await tool.frames(6)
		await tool.snap("%s_%s" % [s[0], s[1]])
	sc.post.set_enabled(false)
	for rp in ["tarde", "noche_viento"]:
		Lighting.apply(sc.root, rp, "N")
		sc.caption.text = "sin grabado: " + rp
		await tool.frames(4)
		await tool.snap("raw_" + rp)
