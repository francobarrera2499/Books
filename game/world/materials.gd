# world/materials.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2.
# Materiales compartidos (albedo cálido casi monocromo; el grabado cuantiza) + kit de geometría para props.
# NOTA: el contrato dice `Materials.get(id)`, pero `get` choca con Object.get (error de parseo en 4.7):
# la función es `Materials.mat(id)`. Todo es estático y determinista (sin randf: `rnd(seed, i, k)`).
# Uso desde props de lugar (l#.gd): const M = preload("res://world/materials.gd"); M.box(parent, size, pos, "madera_oscura")
extends RefCounted

const COLORS := {
	# base del contrato §7.2
	"madera_oscura": "5a4632", "madera_clara": "8a7050", "papel": "e8dcc0", "yeso": "cfc6b4",
	"ladrillo_stock": "9a8a6a", "ladrillo_hollin": "4a4036", "piedra_portland": "bdb7a8",
	"hierro": "2e2c2a", "laton": "a08040", "paño": "3a3a3e", "pano": "3a3a3e", "cuero": "5a3a2a",
	# extras (mismo criterio de paleta)
	"madera_media": "6f5a40", "madera_negra": "2f251c", "caoba": "4e3024", "papel_viejo": "d8c8a4",
	"papel_pintado": "b9a888", "yeso_sucio": "a89f8c", "suelo_tablas": "7a6448", "estuco": "d6cdb8",
	"pizarra": "4a4a4c", "adoquin": "777068", "tarugo": "5e4e3c", "tierra": "4a3c2c", "cesped": "5d6447",
	"azafran": "c9b25a", "azafran_lila": "8c7a9a", "tela_oscura": "2c2a2c", "tela_media": "5a5048",
	"tela_clara": "a89a84", "terciopelo": "5a2e2a", "piel": "c8a888", "maniqui": "8a7e70",
	"maniqui_oscuro": "3a3430", "carbon": "1e1c1a", "ceniza": "8a8680", "tinta": "1b1712",
	"vela": "efe6d2", "cobre": "8a5a3a", "mimbre": "a08a60", "fieltro": "2a2826", "crespon": "151413",
	"bronce": "6a5a3a", "lienzo": "c8bc9c", "pintura_verde": "3e4a3c", "pintura_roja": "6a2e26",
	"lomo": "ffffff", "cielo": "c9c4b8", "interior_oscuro": "201c18", "agua": "8a9490", "roca": "7a7468",
}
const TEXTURED := {
	"ladrillo_stock": "brick", "ladrillo_hollin": "brick", "suelo_tablas": "boards", "papel_pintado": "wallpaper",
	"adoquin": "setts", "tarugo": "blocks", "pizarra": "slate", "cesped": "grass", "estuco": "ashlar",
	"piedra_portland": "ashlar",
}
const TEX_SCALE := {"brick": 1.0 / 0.9, "boards": 1.0 / 1.2, "wallpaper": 1.0 / 0.64, "setts": 1.0 / 0.8,
	"blocks": 1.0 / 0.9, "slate": 1.0 / 0.9, "grass": 1.0 / 0.5, "ashlar": 1.0 / 1.8}

static var _mats := {}
static var _meshes := {}
static var _texs := {}

# ---------- determinismo ----------
static func rnd(seed: int, i: int, k: int = 0) -> float:
	var x: int = (seed * 374761393 + i * 668265263 + k * 2246822519 + 1442695041) & 0xFFFFFFFF
	x = ((x ^ (x >> 15)) * 0x2C1B3C6D) & 0xFFFFFFFF
	x = ((x ^ (x >> 12)) * 0x297A2D39) & 0xFFFFFFFF
	x = x ^ (x >> 15)
	return float(x & 0xFFFFFF) / 16777216.0

static func rr(seed: int, i: int, k: int, a: float, b: float) -> float:
	return a + (b - a) * rnd(seed, i, k)

static func seed_of(p: Dictionary, salt: String = "") -> int:
	if p.has("seed"): return int(p["seed"]) + salt.hash() % 9973
	return salt.hash() & 0xFFFF

# ---------- parámetros ----------
static func pf(p: Dictionary, k: String, d: float) -> float:
	return float(p[k]) if p.has(k) and p[k] != null else d
static func pi_(p: Dictionary, k: String, d: int) -> int:
	return int(p[k]) if p.has(k) and p[k] != null else d
static func pb(p: Dictionary, k: String, d: bool) -> bool:
	return bool(p[k]) if p.has(k) and p[k] != null else d
static func ps(p: Dictionary, k: String, d: String) -> String:
	return str(p[k]) if p.has(k) and p[k] != null else d
static func v3(a, d: Vector3 = Vector3.ZERO) -> Vector3:
	if a is Vector3: return a
	if a is Array and a.size() >= 3: return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return d

# ---------- materiales ----------
static func color(id: String) -> Color:
	return Color(COLORS.get(id, "ff00ff"))

static func mat(id: String) -> Material:
	if _mats.has(id): return _mats[id]
	var m := StandardMaterial3D.new()
	m.resource_name = id
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.25
	m.albedo_color = color(id)
	match id:
		"vidrio":
			m.albedo_color = Color(0.78, 0.8, 0.78, 0.25)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.metallic_specular = 0.6
			m.roughness = 0.15
		"gas_emisivo":
			m.albedo_color = Color("f4d9a0")
			m.emission_enabled = true
			m.emission = Color("ffbf6a")
			m.emission_energy_multiplier = 2.2
		"lomo":
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.albedo_color = Color.WHITE
		"interior_oscuro":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_:
			if not COLORS.has(id):
				push_warning("Materials: material desconocido '%s'" % id)
	if TEXTURED.has(id):
		var kind: String = TEXTURED[id]
		m.albedo_texture = tex(kind, id)
		m.albedo_color = Color.WHITE
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		var s: float = TEX_SCALE[kind]
		m.uv1_scale = Vector3(s, s, s)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[id] = m
	return m

# material de color libre (cacheado por color): para variaciones deterministas
static func mat_color(c: Color) -> Material:
	var key := "#" + c.to_html(false)
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.25
	_mats[key] = m
	return m

# ---------- texturas procedurales (fill_rect: rápidas y deterministas) ----------
static func tex(kind: String, id: String) -> Texture2D:
	var key := kind + ":" + id
	if _texs.has(key): return _texs[key]
	var base := color(id)
	var img: Image
	match kind:
		"brick": img = _tex_brick(base)
		"boards": img = _tex_boards(base)
		"wallpaper": img = _tex_wallpaper(base)
		"setts": img = _tex_setts(base)
		"blocks": img = _tex_blocks(base)
		"slate": img = _tex_slate(base)
		"grass": img = _tex_grass(base)
		"ashlar": img = _tex_ashlar(base)
		_: img = Image.create(8, 8, false, Image.FORMAT_RGB8); img.fill(base)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_texs[key] = t
	return t

static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

static func _fill_wrap(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var W := img.get_width()
	x = ((x % W) + W) % W
	if x + w <= W:
		img.fill_rect(Rect2i(x, y, w, h), c)
	else:
		img.fill_rect(Rect2i(x, y, W - x, h), c)
		img.fill_rect(Rect2i(0, y, x + w - W, h), c)

static func _tex_brick(base: Color) -> Image:
	# 0,9 m = 288 px: ladrillo 225 x 75 mm (72 x 24 px), junta 3 px; sogas con medio desfase
	var img := Image.create(288, 288, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 1.32))
	for row in 12:
		var off := 0 if row % 2 == 0 else 36
		for col in 4:
			var f := 0.82 + 0.3 * rnd(17, row, col + 7)
			if rnd(23, row, col) < 0.08: f *= 0.72
			_fill_wrap(img, col * 72 + off, row * 24, 69, 21, _shade(base, f))
	return img

static func _tex_boards(base: Color) -> Image:
	# 1,2 m = 256 px; tablas de 15 cm a lo largo de X con juntas de testa escalonadas
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 0.45))
	var bw := 32
	for b in 8:
		var y0 := b * bw
		var joint := int(rnd(31, b, 0) * 200) + 28
		var f1 := 0.85 + 0.28 * rnd(37, b, 1)
		var f2 := 0.85 + 0.28 * rnd(37, b, 2)
		img.fill_rect(Rect2i(0, y0, 256, bw - 2), _shade(base, f1))
		img.fill_rect(Rect2i(joint, y0, 256 - joint, bw - 2), _shade(base, f2))
		img.fill_rect(Rect2i(joint, y0, 2, bw - 2), _shade(base, 0.45))
		for g in 3:
			var gy := y0 + 4 + int(rnd(41, b, g) * (bw - 10))
			img.fill_rect(Rect2i(0, gy, 256, 1), _shade(base, f1 * 0.9))
	return img

static func _tex_wallpaper(base: Color) -> Image:
	# 0,64 m = 128 px: listas verticales y un motivo de rombos pequeños (papel pintado victoriano)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(base)
	for s in 4:
		img.fill_rect(Rect2i(s * 32 + 14, 0, 4, 128), _shade(base, 0.86))
		img.fill_rect(Rect2i(s * 32 + 2, 0, 1, 128), _shade(base, 0.92))
	for s in 4:
		for r in 4:
			var cx := s * 32 + (30 if r % 2 == 0 else 14)
			var cy := r * 32 + 16
			for d in 4:
				_fill_wrap(img, cx - d, cy - (3 - d), 1 + 2 * d, 1, _shade(base, 0.8))
				_fill_wrap(img, cx - d, cy + (3 - d), 1 + 2 * d, 1, _shade(base, 0.8))
	return img

static func _tex_setts(base: Color) -> Image:
	# adoquines de granito 10 x 20 cm; 0,8 m = 256 px
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 0.5))
	for row in 8:
		var off := 0 if row % 2 == 0 else 32
		for col in 4:
			_fill_wrap(img, col * 64 + off + 3, row * 32 + 3, 58, 26, _shade(base, 0.78 + 0.4 * rnd(53, row, col + 5)))
	return img

static func _tex_blocks(base: Color) -> Image:
	# tarugos de madera 22,5 x 7,5 cm en hiladas; 0,9 m = 288 px
	var img := Image.create(288, 288, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 0.55))
	for row in 12:
		var off := int(rnd(59, row, 0) * 72)
		for col in 4:
			_fill_wrap(img, col * 72 + off + 1, row * 24 + 1, 70, 22, _shade(base, 0.82 + 0.3 * rnd(61, row, col + 5)))
	return img

static func _tex_slate(base: Color) -> Image:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 0.6))
	for row in 8:
		var off := 0 if row % 2 == 0 else 32
		for col in 4:
			_fill_wrap(img, col * 64 + off + 1, row * 32, 62, 29, _shade(base, 0.85 + 0.3 * rnd(67, row, col + 5)))
	return img

static func _tex_grass(base: Color) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(base)
	for i in 220:
		var x := int(rnd(71, i, 0) * 64)
		var y := int(rnd(71, i, 1) * 61)
		img.fill_rect(Rect2i(x, y, 1, 3), _shade(base, 0.7 + 0.6 * rnd(71, i, 2)))
	return img

static func _tex_ashlar(base: Color) -> Image:
	# sillería / estuco con juntas: bloques de 0,6 x 0,3 m; 1,8 m = 258 px (bloque 85 x 43 px)
	var img := Image.create(255, 258, false, Image.FORMAT_RGB8)
	img.fill(_shade(base, 0.72))
	for row in 6:
		var off := 0 if row % 2 == 0 else 43
		for col in 3:
			_fill_wrap(img, col * 85 + off + 1, row * 43 + 1, 83, 41, _shade(base, 0.95 + 0.08 * rnd(73, row, col + 5)))
	return img

# ---------- mallas compartidas ----------
static func _mesh(key: String, maker: Callable) -> Mesh:
	if _meshes.has(key): return _meshes[key]
	var m: Mesh = maker.call()
	_meshes[key] = m
	return m

static func unit_box() -> Mesh:
	return _mesh("box", func(): var b := BoxMesh.new(); b.size = Vector3.ONE; return b)

static func cyl_mesh(r_top: float, r_bot: float, h: float, sides: int = 16) -> Mesh:
	var key := "cyl:%.4f:%.4f:%.4f:%d" % [r_top, r_bot, h, sides]
	return _mesh(key, func():
		var c := CylinderMesh.new(); c.top_radius = r_top; c.bottom_radius = r_bot; c.height = h
		c.radial_segments = sides; c.rings = 1; return c)

static func sphere_mesh(r: float, hemi: bool = false, seg: int = 16) -> Mesh:
	var key := "sph:%.4f:%s:%d" % [r, str(hemi), seg]
	return _mesh(key, func():
		var s := SphereMesh.new(); s.radius = r; s.height = r * (1.0 if hemi else 2.0); s.is_hemisphere = hemi
		s.radial_segments = seg; s.rings = maxi(seg / 2, 6); return s)

static func capsule_mesh(r: float, h: float) -> Mesh:
	var key := "cap:%.4f:%.4f" % [r, h]
	return _mesh(key, func():
		var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, 2.0 * r + 0.001)
		c.radial_segments = 14; c.rings = 6; return c)

static func prism_mesh(size: Vector3, ltr: float) -> Mesh:
	var key := "pri:%.4f:%.4f:%.4f:%.3f" % [size.x, size.y, size.z, ltr]
	return _mesh(key, func():
		var p := PrismMesh.new(); p.size = size; p.left_to_right = ltr; return p)

static func torus_mesh(r_in: float, r_out: float) -> Mesh:
	var key := "tor:%.4f:%.4f" % [r_in, r_out]
	return _mesh(key, func():
		var t := TorusMesh.new(); t.inner_radius = r_in; t.outer_radius = r_out
		t.rings = 24; t.ring_segments = 8; return t)

# ---------- constructores de nodos ----------
static func _mi(parent: Node3D, mesh: Mesh, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(m)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mi(parent, unit_box(), pos, m, rot_deg, Vector3(maxf(size.x, 0.001), maxf(size.y, 0.001), maxf(size.z, 0.001)))

# caja definida por sus extremos (mín, máx), sin rotación
static func box_mm(parent: Node3D, a: Vector3, b: Vector3, m: String) -> MeshInstance3D:
	return box(parent, (b - a).abs(), (a + b) * 0.5, m)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, sides: int = 16) -> MeshInstance3D:
	return _mi(parent, cyl_mesh(r_top, r_bot, h, sides), pos, m, rot_deg)

static func rod(parent: Node3D, r: float, h: float, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return cyl(parent, r, r, h, pos, m, rot_deg, 8)

# varilla entre dos puntos
static func rod_ab(parent: Node3D, r: float, a: Vector3, b: Vector3, m: String, sides: int = 8) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var mi := MeshInstance3D.new()
	mi.mesh = cyl_mesh(r, r, maxf(l, 0.001), sides)
	mi.material_override = mat(m)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if l > 0.0001:
		var up := d / l
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var x := ref.cross(up).normalized()
		var z := x.cross(up).normalized()
		mi.basis = Basis(x, up, z)
	return mi

# caja entre dos puntos (eje largo a lo largo de a→b), sección w x t
static func beam_ab(parent: Node3D, a: Vector3, b: Vector3, w: float, t: float, m: String) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var mi := MeshInstance3D.new()
	mi.mesh = unit_box()
	mi.material_override = mat(m)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if l > 0.0001:
		var up := d / l
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var x := ref.cross(up).normalized()
		var z := x.cross(up).normalized()
		mi.basis = Basis(x * w, up * l, z * t)
	return mi

static func sphere(parent: Node3D, r: float, pos: Vector3, m: String, scl: Vector3 = Vector3.ONE, seg: int = 16) -> MeshInstance3D:
	return _mi(parent, sphere_mesh(r, false, seg), pos, m, Vector3.ZERO, scl)

static func hemi(parent: Node3D, r: float, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return _mi(parent, sphere_mesh(r, true, 20), pos, m, rot_deg, scl)

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return _mi(parent, capsule_mesh(r, h), pos, m, rot_deg, scl)

# cápsula entre dos puntos (extremos = centros de las semiesferas)
static func capsule_ab(parent: Node3D, r: float, a: Vector3, b: Vector3, m: String) -> MeshInstance3D:
	var d := b - a
	var l := d.length()
	var mi := MeshInstance3D.new()
	mi.mesh = capsule_mesh(r, l + 2.0 * r)
	mi.material_override = mat(m)
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if l > 0.0001:
		var up := d / l
		var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var x := ref.cross(up).normalized()
		var z := x.cross(up).normalized()
		mi.basis = Basis(x, up, z)
	return mi

static func prism(parent: Node3D, size: Vector3, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, ltr: float = 0.5) -> MeshInstance3D:
	return _mi(parent, prism_mesh(size, ltr), pos, m, rot_deg)

static func torus(parent: Node3D, r_in: float, r_out: float, pos: Vector3, m: String, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	return _mi(parent, torus_mesh(r_in, r_out), pos, m, rot_deg, scl)

# arco de cápsulas: centro c, radio rad, vectores unitarios u (ángulo 0) y v (ángulo 90°), de a0 a a1 (radianes)
static func arc(parent: Node3D, c: Vector3, rad: float, u: Vector3, v: Vector3, a0: float, a1: float, n: int, r: float, m: String) -> void:
	var prev := c + (u * cos(a0) + v * sin(a0)) * rad
	for i in range(1, n + 1):
		var a := lerpf(a0, a1, float(i) / n)
		var p := c + (u * cos(a) + v * sin(a)) * rad
		capsule_ab(parent, r, prev, p, m)
		prev = p

# MultiMesh de cajas unitarias con color por instancia (lomos de libros, flores, multitudes de piezas)
static func multi_boxes(parent: Node3D, xforms: Array, colors: Array, m: String = "lomo", mesh: Mesh = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh if mesh != null else unit_box()
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors: mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat(m)
	parent.add_child(mmi)
	return mmi

static func xf_box(size: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)) * Basis.from_scale(size)
	return Transform3D(b, pos)

# ---------- texto 3D (rótulos): fuente de ThemeInstaller (imprenta) (prohibida la fuente del sistema) ----------
static func label3d(parent: Node3D, text: String, pos: Vector3, px: float = 0.004, size: int = 48, col: Color = Color("1b1712"), slot: String = "imprenta") -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = size
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = pos
	var ti = _autoload("ThemeInstaller")
	if ti != null and ti.has_method("font"):
		var f = ti.font(slot)
		if f != null: l.font = f
	parent.add_child(l)
	return l

static func _autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

# texto desde ui_text (clave) o literal
static func text_of(p: Dictionary, key_field: String = "text_key") -> String:
	if p.has("text") and str(p["text"]) != "": return str(p["text"])
	var k := str(p.get(key_field, ""))
	if k == "": return ""
	var d = _autoload("Data")
	if d != null and d.has_method("repo"):
		var r = d.repo()
		if r != null and r.has_method("text"):
			var t: String = r.text(k)
			if t != "" and t != k: return t
	return k

# ---------- AABB / oclusión ----------
static func aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in _all_geo(n):
		var a: AABB = mi.get_aabb()
		if mi is MultiMeshInstance3D:
			# la AABB de un MultiMesh no se calcula fuera del render (headless): se arma con las instancias
			var mm: MultiMesh = (mi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or mm.instance_count == 0: continue
			var ma := mm.mesh.get_aabb()
			a = mm.get_instance_transform(0) * ma
			for i in range(1, mm.instance_count):
				a = a.merge(mm.get_instance_transform(i) * ma)
		var t: Transform3D = _rel_xform(n, mi)
		var w := t * a
		if first: out = w; first = false
		else: out = out.merge(w)
	return out

static func _all_geo(n: Node) -> Array:
	var r: Array = []
	for c in n.get_children():
		if c is GeometryInstance3D and (c is MeshInstance3D or c is MultiMeshInstance3D):
			r.append(c)
		if c is Node3D:
			r.append_array(_all_geo(c))
	return r

static func _rel_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D: t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

# fija meta "occ" (Array[AABB] local). Sin cajas → AABB total.
static func set_occ(n: Node3D, boxes: Array = []) -> Node3D:
	var occ: Array = []
	if boxes.is_empty():
		occ.append(aabb_of(n))
	else:
		for b in boxes:
			if b is AABB: occ.append(b)
	n.set_meta("occ", occ)
	return n

static func aabb_mm(a: Vector3, b: Vector3) -> AABB:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return AABB(lo, hi - lo)

static func aabb_c(c: Vector3, s: Vector3) -> AABB:
	return AABB(c - s * 0.5, s)

static func root(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	return n
