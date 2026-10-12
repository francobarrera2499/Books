# Escena de prueba de W1-POST (cajas, cilindros, una figura, lámparas, rótulo 3D) + CanvasLayer con texto.
# No es un driver: la usan w1post_*.gd (capturas) y tests/test_t27_window.gd. Todo por código, sin .tscn.
#   var S = load("res://devtools/drivers/w1post_scene.gd")
#   var sc = S.build(parent)  -> {root, cam, post, canvas, caption, panel, info}
#   S.set_preset(sc, preset, slot)
extends RefCounted

const Lighting = preload("res://world/lighting.gd")
const EngravingPost = preload("res://world/post/engraving_post.gd")

const COL := {
	"madera_oscura": Color("5a4632"), "madera_clara": Color("8a7050"), "papel": Color("e8dcc0"),
	"yeso": Color("cfc6b4"), "ladrillo_stock": Color("9a8a6a"), "hierro": Color("2e2c2a"),
	"laton": Color("a08040"), "pano": Color("3a3a3e"), "cuero": Color("5a3a2a"), "cielo": Color("b8bcbc"),
	"piel": Color("c8a888"), "suelo": Color("7a6448"),
}

static var _mats := {}

static func mat(id: String) -> StandardMaterial3D:
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = COL.get(id, Color.GRAY)
	m.roughness = 1.0
	m.metallic = 0.0
	if id == "gas":
		m.albedo_color = Color("f4d9a0")
		m.emission_enabled = true
		m.emission = Color("ffbf6a")
		m.emission_energy_multiplier = 2.2
	_mats[id] = m
	return m

static func box(p: Node3D, size: Vector3, pos: Vector3, m: String, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees.y = rot_y
	mi.material_override = mat(m)
	p.add_child(mi)
	return mi

static func cyl(p: Node3D, r: float, h: float, pos: Vector3, m: String, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = 32
	mi.mesh = c
	mi.position = pos
	mi.material_override = mat(m)
	p.add_child(mi)
	return mi

static func sph(p: Node3D, r: float, pos: Vector3, m: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = pos
	mi.material_override = mat(m)
	p.add_child(mi)
	return mi

static func cap(p: Node3D, r: float, h: float, pos: Vector3, m: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	mi.mesh = c
	mi.position = pos
	mi.rotation_degrees = rot
	mi.material_override = mat(m)
	p.add_child(mi)
	return mi

# Figura de prueba: chistera de ópera y bigote enorme (silueta de Harris/Moran, §7.4).
static func figure(p: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var f := Node3D.new()
	f.name = "Figura"
	f.position = pos
	f.rotation_degrees.y = rot_y
	p.add_child(f)
	cyl(f, 0.075, 0.86, Vector3(-0.1, 0.43, 0), "pano")
	cyl(f, 0.075, 0.86, Vector3(0.1, 0.43, 0), "pano")
	cap(f, 0.21, 0.78, Vector3(0, 1.22, 0), "pano")
	box(f, Vector3(0.44, 0.5, 0.05), Vector3(0, 1.2, 0.19), "pano")
	cap(f, 0.06, 0.66, Vector3(-0.28, 1.2, 0.02), "pano", Vector3(0, 0, -8))
	cap(f, 0.06, 0.66, Vector3(0.28, 1.2, 0.02), "pano", Vector3(0, 0, 8))
	sph(f, 0.12, Vector3(0, 1.72, 0), "piel")
	cap(f, 0.028, 0.2, Vector3(-0.08, 1.67, 0.11), "hierro", Vector3(0, 0, 70))
	cap(f, 0.028, 0.2, Vector3(0.08, 1.67, 0.11), "hierro", Vector3(0, 0, -70))
	cyl(f, 0.2, 0.015, Vector3(0, 1.81, 0), "hierro")
	cyl(f, 0.105, 0.24, Vector3(0, 1.93, 0), "hierro", 0.11)
	return f

static func build(parent: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "W1PostScene"
	parent.add_child(root)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	# cuarto: piso, dos paredes, zócalo, ventana con cielo opaco
	box(props, Vector3(9, 0.1, 8), Vector3(0, -0.05, 0), "suelo")
	box(props, Vector3(9, 3.4, 0.12), Vector3(0, 1.7, -3.0), "yeso")
	box(props, Vector3(0.12, 3.4, 8), Vector3(-3.5, 1.7, 0), "yeso")
	box(props, Vector3(9, 0.18, 0.06), Vector3(0, 0.09, -2.92), "madera_oscura")
	box(props, Vector3(0.06, 0.18, 8), Vector3(-3.42, 0.09, 0), "madera_oscura")
	box(props, Vector3(9, 0.06, 0.08), Vector3(0, 1.0, -2.92), "madera_oscura")
	var wx := 1.6
	box(props, Vector3(1.3, 1.6, 0.05), Vector3(wx, 1.75, -2.93), "cielo")
	box(props, Vector3(1.42, 0.08, 0.1), Vector3(wx, 2.59, -2.9), "madera_clara")
	box(props, Vector3(1.42, 0.08, 0.16), Vector3(wx, 0.92, -2.88), "madera_clara")
	box(props, Vector3(0.08, 1.7, 0.1), Vector3(wx - 0.67, 1.75, -2.9), "madera_clara")
	box(props, Vector3(0.08, 1.7, 0.1), Vector3(wx + 0.67, 1.75, -2.9), "madera_clara")
	box(props, Vector3(1.3, 0.05, 0.07), Vector3(wx, 1.75, -2.9), "madera_clara")
	box(props, Vector3(0.05, 1.6, 0.07), Vector3(wx, 1.75, -2.9), "madera_clara")
	# mesa con libros, tintero y globo
	box(props, Vector3(1.7, 0.07, 0.95), Vector3(-0.6, 0.76, -0.9), "madera_oscura")
	for lx in [-1.35, 0.15]:
		for lz in [-1.3, -0.5]:
			cyl(props, 0.035, 0.73, Vector3(lx, 0.365, lz), "madera_oscura")
	box(props, Vector3(0.34, 0.07, 0.24), Vector3(-1.05, 0.835, -1.0), "cuero", 12.0)
	box(props, Vector3(0.3, 0.06, 0.22), Vector3(-1.04, 0.9, -1.0), "papel", -6.0)
	box(props, Vector3(0.32, 0.08, 0.23), Vector3(-1.06, 0.97, -1.02), "cuero", 20.0)
	box(props, Vector3(0.42, 0.01, 0.3), Vector3(-0.45, 0.8, -0.75), "papel", -8.0)
	cyl(props, 0.04, 0.08, Vector3(-0.1, 0.84, -1.05), "hierro")
	cyl(props, 0.012, 0.22, Vector3(-0.08, 0.92, -1.05), "madera_clara")
	sph(props, 0.16, Vector3(0.0, 1.02, -1.15), "papel")
	cyl(props, 0.03, 0.08, Vector3(0.0, 0.84, -1.15), "laton")
	# cajones apilados, barril, estufa con caño, columna
	box(props, Vector3(0.7, 0.6, 0.6), Vector3(2.4, 0.3, -2.3), "madera_clara", 8.0)
	box(props, Vector3(0.6, 0.45, 0.5), Vector3(2.35, 0.83, -2.3), "madera_clara", -10.0)
	cyl(props, 0.32, 0.9, Vector3(3.0, 0.45, -1.1), "madera_oscura", 0.28)
	cyl(props, 0.3, 0.75, Vector3(-2.9, 0.375, -2.3), "hierro")
	cyl(props, 0.06, 2.6, Vector3(-2.9, 2.05, -2.3), "hierro")
	cyl(props, 0.18, 3.4, Vector3(-2.2, 1.7, 1.6), "yeso")
	# figura
	figure(props, Vector3(0.75, 0, -0.35), -25.0)
	# lámpara de gas de pared (sombra: sí, como en la tienda de Crane) y farol de calle
	var arm := cyl(props, 0.02, 0.36, Vector3(-1.4, 2.2, -2.75), "laton")
	arm.rotation_degrees.x = 90.0
	var glass := sph(props, 0.09, Vector3(-1.4, 2.25, -2.56), "gas")
	glass.set_meta("light", {"kind": "gas", "shadow": true, "offset": [0.0, 0.0, 0.12]})
	cyl(props, 0.05, 2.7, Vector3(3.6, 1.35, 1.2), "hierro")
	var lantern := box(props, Vector3(0.26, 0.34, 0.26), Vector3(3.6, 2.85, 1.2), "gas")
	lantern.set_meta("light", "farol")
	# rótulo 3D (prueba de Label3D bajo el grabado: necesita alpha_cut para pasar por el prepass)
	var lab := Label3D.new()
	lab.name = "Rotulo"
	lab.text = "A. CRANE · LIBROS DE LANCE"
	lab.font = _font(false)
	lab.font_size = 96
	lab.pixel_size = 0.0035
	lab.modulate = Color("1b1712")
	lab.outline_size = 0
	lab.shaded = true
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lab.position = Vector3(-0.6, 2.75, -2.93)
	props.add_child(lab)
	# cámara + grabado
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 42.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(2.7, 1.75, 3.7), Vector3(-0.5, 1.05, -1.3))
	cam.current = true
	var post := EngravingPost.attach(cam)
	# capa de texto (fuera del grabado)
	var canvas := CanvasLayer.new()
	canvas.name = "Texto"
	canvas.layer = 30
	parent.add_child(canvas)
	var panel := ColorRect.new()
	panel.name = "Panel"
	panel.color = Color("f0e8d6")
	panel.position = Vector2(24, 24)
	panel.size = Vector2(520, 64)
	canvas.add_child(panel)
	var info := Label.new()
	info.name = "Info"
	info.add_theme_font_override("font", _font(false))
	info.add_theme_font_size_override("font_size", 26)
	info.add_theme_color_override("font_color", Color("1b1712"))
	info.position = Vector2(40, 36)
	info.text = "—"
	canvas.add_child(info)
	var band := ColorRect.new()
	band.name = "Banda"
	band.color = Color("efe6d2")
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -78
	canvas.add_child(band)
	var caption := Label.new()
	caption.name = "Epigrafe"
	caption.add_theme_font_override("font", _font(true))
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", Color("1b1712"))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -64
	caption.offset_bottom = -16
	caption.text = "—¿El Journal de Genève, señor? ¡Qué pregunta! Ñandú, «año» — 1894."
	canvas.add_child(caption)
	return {"root": root, "props": props, "cam": cam, "post": post, "canvas": canvas, "caption": caption, "panel": panel, "info": info}

static func set_preset(sc: Dictionary, preset: String, slot: String) -> Dictionary:
	var look := Lighting.apply(sc.root, preset, slot)
	sc.post.set_look(look)
	sc.info.text = "%s · %s · papel #%s" % [preset, slot, Color(look.paper).to_html(false)]
	return look

static func _font(italic: bool) -> Font:
	var ti = Engine.get_main_loop().root.get_node_or_null("ThemeInstaller") if Engine.get_main_loop() is SceneTree else null
	if ti != null and ti.has_method("font"):
		var f = ti.font("imprenta", italic)
		if f != null and f != ThemeDB.fallback_font:
			return f
	var path := "res://assets/fonts/IMFeENit28P.ttf" if italic else "res://assets/fonts/IMFeENrm28P.ttf"
	var ff = load(path)
	return ff if ff is Font else ThemeDB.fallback_font
