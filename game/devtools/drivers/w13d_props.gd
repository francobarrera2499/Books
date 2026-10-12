# devtools/drivers/w13d_props.gd — W1-3D. Hojas de contacto de cada build_* de §7.2 (sin grabado).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w13d_props res://devtools/drivers/w13d_props.gd
# Salida: .work/shots/<prefijo>_sheet<NN>.png (3 x 2 por hoja). Env: W13D_ONLY="furniture.desk,small.lens" (filtro), W13D_ENGRAVE=1 (con grabado).
extends RefCounted

const DB = preload("res://world/diorama_builder.gd")
const M = preload("res://world/materials.gd")

const LIST := [
	["furniture.desk", {"pigeonholes": true}], ["furniture.table", {}], ["furniture.table", {"round": true, "w": 0.9}],
	["furniture.chair", {}], ["furniture.chair", {"style": "bentwood"}], ["furniture.chair", {"style": "windsor"}],
	["furniture.chair", {"style": "oficina"}], ["furniture.armchair", {}], ["furniture.armchair", {"wing": true, "mat": "terciopelo"}],
	["furniture.bookshelf", {"gap": {"row": 1, "from": 0.35, "to": 0.62}, "seed": 3}], ["furniture.counter", {"bell": true}], ["furniture.stool", {}],
	["furniture.bed", {}], ["furniture.stove", {"lit": true}], ["furniture.fireplace", {"mirror": true, "lit": true}],
	["furniture.coat_stand", {"hat": "bowler_crepe", "coat": true}], ["furniture.reading_desk_radial", {"n": 6, "r": 6.0}], ["furniture.index_shelves", {}],
	["furniture.cabinet", {}], ["furniture.cabinet", {"glazed": true}], ["furniture.crate", {"text": "GRENOBLE — FRÁGIL"}],
	["architecture.room", {"w": 4.0, "d": 3.4, "h": 2.9, "dado": 0.9, "openings": [{"wall": "n", "kind": "window", "x": 0.6, "w": 1.0, "h": 1.6, "sill": 0.85, "curtains": true}, {"wall": "w", "kind": "door", "x": 0.4, "w": 0.9, "h": 2.1, "open": 0.3}]}],
	["architecture.attic", {"w": 4.2, "d": 3.6, "h": 2.8, "slope": 40, "openings": [{"wall": "n", "kind": "window", "x": 0.0, "w": 0.8, "h": 1.1, "sill": 0.9}]}],
	["architecture.sash_window", {"open_frac": 0.3}], ["architecture.door", {"open_frac": 0.25}],
	["architecture.facade", {"w": 6.0, "h": 12.0, "floors": 4, "bays": 3, "door_bay": 0, "number": "221B", "seed": 5}],
	["architecture.facade", {"w": 5.0, "h": 10.0, "floors": 3, "bays": 3, "door_bay": 2, "shop_front": true, "sign": "A. CRANE — LIBROS", "seed": 9}],
	["architecture.facade", {"w": 7.0, "h": 13.0, "floors": 4, "bays": 3, "door_bay": 1, "style": "estuco", "seed": 2}],
	["architecture.dome", {"r": 6.0, "ribs": 16}], ["architecture.stairs", {"n": 17}], ["architecture.railing", {"len": 3.0}],
	["architecture.eave", {"len": 2.5}], ["architecture.arch", {}],
	["street.gas_lamp", {}], ["street.wall_lamp", {}], ["street.cab", {}], ["street.cab", {"kind": "growler"}],
	["street.crocus_bed", {}], ["street.lawn_strip", {}], ["street.sign_board", {"text": "SE ALQUILA", "mount": "posts"}],
	["street.kiosk", {}], ["street.pavement", {"kind": "madera", "w": 3, "d": 2}], ["street.pavement", {"kind": "granito", "w": 3, "d": 2, "kerb": "+z"}],
	["street.post_box", {}],
	["small.book", {}], ["small.book_pile", {"n": 6}], ["small.tome_set", {"n": 5}], ["small.paper_stack", {}], ["small.letter", {}],
	["small.envelope", {}], ["small.basket_strips", {}], ["small.ash_pile", {}], ["small.scissors", {}], ["small.ruler", {}],
	["small.lens", {}], ["small.stamp", {}], ["small.ink_pot", {}], ["small.clock_mantel", {}], ["small.coins", {}],
	["small.tray", {}], ["small.desk_calendar", {"text": "27", "text2": "MARZO"}], ["small.map_board", {}], ["small.tobacco_tin", {}],
	["small.photo_frame", {}], ["small.open_ledger_book", {}], ["small.lantern", {}],
	["small.desk_lamp", {}], ["furniture.gasolier", {"h": 1.2, "drop": 0.9}], ["crowd.make", {"n": 9, "seed": 4, "w": 3.0, "d": 1.5}],
]

var tool
var world: Node3D
var cam: Camera3D
var label: Label

func drive(t, scene) -> void:
	tool = t
	for c in scene.get_children(): c.queue_free()
	await tool.frames(2)
	world = Node3D.new(); scene.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("d8d2c4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8c0b0"); e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -35, 0); sun.light_energy = 1.0; sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new(); fill.rotation_degrees = Vector3(-20, 140, 0); fill.light_energy = 0.3
	world.add_child(fill)
	cam = Camera3D.new(); cam.fov = 35; world.add_child(cam); cam.current = true
	if OS.get_environment("W13D_ENGRAVE") != "" and ResourceLoader.exists("res://world/post/engraving_post.gd"):
		var EP = load("res://world/post/engraving_post.gd")
		var post = EP.attach(cam)
		var LT = load("res://world/lighting.gd")
		if post.has_method("set_look"): post.set_look(LT.look("dia_ventana", "M"))
	var cl := CanvasLayer.new(); scene.add_child(cl)
	label = Label.new(); label.position = Vector2(560, 60); label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("1b1712"))
	cl.add_child(label)
	var only := OS.get_environment("W13D_ONLY")
	var items: Array = []
	for it in LIST:
		if only == "" or only.split(",").has(it[0]): items.append(it)
	var tw := 500; var th := 450
	var sheet: Image = null
	var k := 0
	var sheet_i := 0
	for it in items:
		var n := DB.build_prop(it[0], it[1])
		world.add_child(n)
		var floor := M.box(world, Vector3(40, 0.02, 40), Vector3(0, -0.011, 0), "papel_viejo")
		var box := M.aabb_of(n)
		var c := box.get_center()
		var rad := maxf(box.size.length() * 0.5, 0.08)
		var dir := Vector3(0.55, 0.42, 1.0).normalized()
		if it[0] == "architecture.dome": dir = Vector3(0.0, -0.05, 1.0).normalized(); c = Vector3(0, 3.5, 0); rad = 2.0
		var dist := rad / sin(deg_to_rad(cam.fov) * 0.5) * 1.02
		cam.near = maxf(0.005, dist * 0.01)
		cam.fov = 35
		cam.global_transform = Transform3D(Basis.IDENTITY, c + dir * dist).looking_at(c, Vector3.UP)
		if it[0] == "architecture.dome":
			cam.fov = 70; cam.near = 0.05
			cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 3.5)).looking_at(Vector3(0, 5.0, -3.0), Vector3.UP)
		_cutaway(n)
		label.text = "%s %s" % [it[0], JSON.stringify(it[1]).substr(0, 40) if not (it[1] as Dictionary).is_empty() else ""]
		await tool.frames(3)
		await RenderingServer.frame_post_draw
		var img: Image = tool.root.get_viewport().get_texture().get_image()
		var crop := img.get_region(Rect2i(300, 0, 1000, 900))
		crop.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		if sheet == null:
			sheet = Image.create(tw * 3, th * 2, false, crop.get_format())
			sheet.fill(Color.WHITE)
		sheet.blit_rect(crop, Rect2i(0, 0, tw, th), Vector2i((k % 3) * tw, (k / 3) * th))
		k += 1
		n.queue_free(); floor.queue_free()
		if k == 6:
			_save(sheet, sheet_i); sheet = null; k = 0; sheet_i += 1
	if sheet != null: _save(sheet, sheet_i)

func _save(img: Image, i: int) -> void:
	var p: String = tool.out_dir.path_join("%s_sheet%02d.png" % [tool.prefix, i])
	img.save_png(p)
	print("SNAP ", p)

func _cutaway(n: Node3D) -> void:
	var cp := cam.global_position
	for g in n.find_children("*", "Node3D", true, false):
		if g.has_meta("cut_n"):
			var gx: Transform3D = M._rel_xform(world, g)
			var nn: Vector3 = (gx.basis * (g.get_meta("cut_n") as Vector3)).normalized()
			var pp: Vector3 = gx * (g.get_meta("cut_p") as Vector3)
			g.visible = (cp - pp).dot(nn) > 0.0
