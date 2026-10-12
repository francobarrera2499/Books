# world/props/street.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2.
# Origen = centro del pie; frente +Z. Las luces se marcan con un Marker3D "light_anchor" (meta light=true, color,
# energy, range): DioramaBuilder / lighting.gd deciden si encienden un OmniLight3D ahí (§7.7).
extends RefCounted

const M = preload("res://world/materials.gd")

static func light_anchor(parent: Node3D, pos: Vector3, col: Color = Color("ffc87a"), energy: float = 1.4, rng: float = 7.0, kind: String = "gas") -> Marker3D:
	var mk := Marker3D.new()
	mk.name = "light_anchor"
	mk.position = pos
	mk.set_meta("light", true)
	mk.set_meta("color", col)
	mk.set_meta("energy", energy)
	mk.set_meta("range", rng)
	mk.set_meta("lamp_kind", kind)
	parent.add_child(mk)
	return mk

static func _lantern_head(parent: Node3D, c: Vector3, s: float, light: bool, kind: String = "farol") -> void:
	# farol de cuatro caras: base, vidrios, montantes, techo piramidal y remate
	M.cyl(parent, s * 0.32, s * 0.22, s * 0.18, c + Vector3(0, -s * 0.55, 0), "hierro", Vector3.ZERO, 4).rotation_degrees.y = 45
	M.box(parent, Vector3(s * 0.62, s * 0.9, s * 0.62), c, "vidrio")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(parent, Vector3(s * 0.05, s * 0.95, s * 0.05), c + Vector3(sx * s * 0.31, 0, sz * s * 0.31), "hierro")
	var roof := M.cyl(parent, 0.0, s * 0.62, s * 0.38, c + Vector3(0, s * 0.64, 0), "hierro", Vector3.ZERO, 4)
	roof.rotation_degrees.y = 45
	M.box(parent, Vector3(s * 0.74, s * 0.05, s * 0.74), c + Vector3(0, s * 0.46, 0), "hierro")
	M.sphere(parent, s * 0.07, c + Vector3(0, s * 0.88, 0), "hierro")
	M.cyl(parent, s * 0.03, s * 0.03, s * 0.14, c + Vector3(0, s * 0.98, 0), "hierro", Vector3.ZERO, 6)
	M.sphere(parent, s * 0.12, c + Vector3(0, -s * 0.1, 0), "gas_emisivo" if light else "vela", Vector3(1, 1.3, 1), 10)
	if light: light_anchor(parent, c, Color("ffc274"), 3.2, 9.0, kind)

# ======================================================================================
# gas_lamp(h,light): farola de gas de hierro fundido con travesaño para la escalera del farolero.
static func build_gas_lamp(p: Dictionary) -> Node3D:
	var root := M.root("gas_lamp")
	var h := M.pf(p, "h", 3.4)
	var light := M.pb(p, "light", true)
	M.cyl(root, 0.16, 0.2, 0.12, Vector3(0, 0.06, 0), "hierro", Vector3.ZERO, 8)
	M.cyl(root, 0.12, 0.15, 0.55, Vector3(0, 0.395, 0), "hierro", Vector3.ZERO, 16)
	for k in 8:
		var a := TAU * k / 8.0
		M.box(root, Vector3(0.02, 0.5, 0.02), Vector3(cos(a) * 0.13, 0.4, sin(a) * 0.13), "hierro")
	M.torus(root, 0.08, 0.14, Vector3(0, 0.7, 0), "hierro")
	M.cyl(root, 0.045, 0.07, h - 1.2, Vector3(0, 0.7 + (h - 1.2) / 2, 0), "hierro", Vector3.ZERO, 12)
	M.torus(root, 0.04, 0.075, Vector3(0, h - 0.5, 0), "hierro")
	M.box(root, Vector3(0.62, 0.035, 0.035), Vector3(0, h - 0.62, 0), "hierro")
	for sx: float in [-1.0, 1.0]:
		M.sphere(root, 0.03, Vector3(sx * 0.31, h - 0.62, 0), "hierro")
	M.cyl(root, 0.05, 0.05, 0.1, Vector3(0, h - 0.43, 0), "hierro", Vector3.ZERO, 8)
	_lantern_head(root, Vector3(0, h - 0.06, 0), 0.5, light)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.08, 0, -0.08), Vector3(0.08, h - 0.35, 0.08)), M.aabb_mm(Vector3(-0.17, h - 0.35, -0.17), Vector3(0.17, h + 0.4, 0.17))])
	return root

# ======================================================================================
# wall_lamp: farol de pared en ménsula. Origen = pie de la pared; h = altura de montaje; sale a +Z.
# Extras: light (def true), kind ("farol" calle | "gas" interior: clase de lámpara para Lighting).
static func build_wall_lamp(p: Dictionary) -> Node3D:
	var root := M.root("wall_lamp")
	var y := M.pf(p, "h", 2.6)
	var light := M.pb(p, "light", true)
	M.box(root, Vector3(0.14, 0.24, 0.03), Vector3(0, y, 0.015), "hierro")
	M.rod_ab(root, 0.018, Vector3(0, y + 0.06, 0.02), Vector3(0, y + 0.06, 0.46), "hierro")
	M.rod_ab(root, 0.012, Vector3(0, y - 0.1, 0.02), Vector3(0, y + 0.04, 0.38), "hierro")
	M.torus(root, 0.05, 0.065, Vector3(0, y - 0.0, 0.2), "hierro", Vector3(0, 90, 90))
	_lantern_head(root, Vector3(0, y + 0.28, 0.46), 0.36, light, M.ps(p, "kind", "farol"))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.12, y - 0.15, 0), Vector3(0.12, y + 0.6, 0.6))])
	return root

# ======================================================================================
# caballo de primitivas (mira a +Z)
static func _horse(parent: Node3D, pos: Vector3, mat: String = "caoba") -> void:
	var hz := Node3D.new(); hz.name = "horse"; hz.position = pos; hz.scale = Vector3.ONE * 1.08; parent.add_child(hz)
	M.capsule(hz, 0.3, 1.5, Vector3(0, 1.22, 0), mat, Vector3(90, 0, 0), Vector3(0.92, 1, 1.05))
	M.capsule_ab(hz, 0.17, Vector3(0, 1.38, 0.62), Vector3(0, 1.78, 0.92), mat)
	M.capsule_ab(hz, 0.11, Vector3(0, 1.86, 0.98), Vector3(0, 1.62, 1.28), mat)
	M.sphere(hz, 0.08, Vector3(0, 1.58, 1.33), mat)
	for sx: float in [-1.0, 1.0]:
		M.cyl(hz, 0.0, 0.035, 0.12, Vector3(sx * 0.06, 2.0, 0.98), mat, Vector3(-10, 0, sx * -10), 6)
		for sz: float in [-1.0, 1.0]:
			var lx := sx * 0.17
			var lz := sz * 0.52
			M.capsule_ab(hz, 0.075, Vector3(lx, 1.05, lz), Vector3(lx, 0.55, lz + 0.02 * sz), mat)
			M.capsule_ab(hz, 0.045, Vector3(lx, 0.55, lz + 0.02 * sz), Vector3(lx, 0.08, lz), mat)
			M.cyl(hz, 0.06, 0.07, 0.07, Vector3(lx, 0.035, lz), "madera_negra", Vector3.ZERO, 8)
	M.capsule_ab(hz, 0.06, Vector3(0, 1.32, -0.76), Vector3(0, 0.7, -0.88), "madera_negra")
	M.capsule_ab(hz, 0.05, Vector3(0, 1.9, 0.9), Vector3(0, 1.55, 0.7), "madera_negra")  # crin
	# arreos: collera y sillín
	M.torus(hz, 0.14, 0.19, Vector3(0, 1.5, 0.66), "cuero", Vector3(62, 0, 0), Vector3(1, 1, 1.25))
	M.box(hz, Vector3(0.66, 0.12, 0.24), Vector3(0, 1.5, 0.05), "cuero")

static func _wheel(parent: Node3D, c: Vector3, r: float, spokes: int) -> void:
	M.torus(parent, r - 0.04, r, c, "madera_negra", Vector3(0, 0, 90))
	M.cyl(parent, 0.07, 0.07, 0.16, c, "madera_negra", Vector3(0, 0, 90), 12)
	for k in spokes:
		var a := TAU * k / spokes
		M.rod_ab(parent, 0.012, c, c + Vector3(0, cos(a) * (r - 0.03), sin(a) * (r - 0.03)), "madera_negra")

# ======================================================================================
# cab(kind:"hansom"|"growler"): coche de alquiler con caballo; mira a +Z (el caballo adelante). Extras: horse (def true).
static func build_cab(p: Dictionary) -> Node3D:
	var root := M.root("cab")
	var kind := M.ps(p, "kind", "hansom")
	var body := "madera_negra"
	if kind == "growler":
		for sz: float in [-1.0, 1.0]:
			var wr := 0.55 if sz > 0 else 0.68
			for sx: float in [-1.0, 1.0]:
				_wheel(root, Vector3(sx * 0.72, wr, sz * 0.75), wr, 12)
		M.box(root, Vector3(1.3, 1.25, 1.6), Vector3(0, 1.55, -0.1), body)
		M.box(root, Vector3(1.36, 0.06, 1.66), Vector3(0, 2.2, -0.1), body)
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.02, 0.5, 0.6), Vector3(sx * 0.66, 1.75, -0.1), "vidrio")
			M.box(root, Vector3(0.025, 0.9, 0.62), Vector3(sx * 0.655, 1.45, -0.1), "tela_oscura")
			M.box(root, Vector3(0.02, 0.06, 1.6), Vector3(sx * 0.66, 1.2, -0.1), "laton")
		M.box(root, Vector3(0.9, 0.12, 0.6), Vector3(0, 1.75, 0.95), body)
		M.box(root, Vector3(0.9, 0.5, 0.06), Vector3(0, 1.5, 1.22), body)
		# baca
		for sx: float in [-1.0, 1.0]:
			M.rod(root, 0.012, 1.5, Vector3(sx * 0.6, 2.3, -0.1), "hierro", Vector3(90, 0, 0))
		M.box(root, Vector3(0.9, 0.35, 0.6), Vector3(0, 2.4, -0.4), "tela_media")
		for sx: float in [-1.0, 1.0]:
			M.rod_ab(root, 0.025, Vector3(sx * 0.4, 1.0, 1.0), Vector3(sx * 0.35, 1.05, 2.9), "madera_media")
		if M.pb(p, "horse", true): _horse(root, Vector3(0, 0, 2.4))
		root.set_meta("occ", [M.aabb_mm(Vector3(-0.8, 0.2, -1.0), Vector3(0.8, 2.6, 1.3))])
		return root
	# hansom: dos ruedas grandes, caja con portezuelas bajas, pescante alto atrás
	for sx: float in [-1.0, 1.0]:
		_wheel(root, Vector3(sx * 0.85, 0.8, 0.0), 0.8, 14)
	M.rod(root, 0.035, 1.8, Vector3(0, 0.8, 0), "hierro", Vector3(0, 0, 90))
	M.box(root, Vector3(1.2, 1.3, 1.0), Vector3(0, 1.75, -0.15), body)
	M.box(root, Vector3(1.24, 0.1, 1.1), Vector3(0, 2.44, -0.15), body)
	M.box(root, Vector3(1.0, 0.05, 0.9), Vector3(0, 1.15, 0.0), body)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, 0.55, 0.06), Vector3(sx * 0.52, 1.45, 0.38), body)
		M.box(root, Vector3(0.025, 0.8, 0.85), Vector3(sx * 0.61, 1.85, -0.18), "tela_oscura")
		M.box(root, Vector3(0.02, 0.35, 0.4), Vector3(sx * 0.62, 2.0, -0.12), "vidrio")
		_lantern_head(root, Vector3(sx * 0.66, 2.0, 0.36), 0.2, false)
	# portezuelas bajas plegadas
	M.box(root, Vector3(1.0, 0.5, 0.04), Vector3(0, 1.42, 0.42), body)
	# pescante y cochero vacío (asiento)
	M.box(root, Vector3(0.5, 0.08, 0.4), Vector3(0, 2.75, -0.85), body)
	M.box(root, Vector3(0.5, 0.35, 0.05), Vector3(0, 2.92, -1.03), body)
	M.rod_ab(root, 0.03, Vector3(0, 2.7, -0.85), Vector3(0, 2.45, -0.62), "hierro")
	M.box(root, Vector3(0.36, 0.04, 0.3), Vector3(0, 1.2, -0.95), "hierro")
	for sx: float in [-1.0, 1.0]:
		M.rod_ab(root, 0.03, Vector3(sx * 0.45, 1.2, 0.2), Vector3(sx * 0.38, 1.25, 2.8), "madera_media")
	if M.pb(p, "horse", true): _horse(root, Vector3(0, 0, 2.15))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.95, 0.0, -1.1), Vector3(0.95, 3.0, 0.5))])
	return root

# ======================================================================================
# crocus_bed(w,d): macizo de azafranes (MultiMesh) en tierra con bordillo. Extras: seed, trampled (fracción pisada).
static func build_crocus_bed(p: Dictionary) -> Node3D:
	var root := M.root("crocus_bed")
	var w := M.pf(p, "w", 2.0); var d := M.pf(p, "d", 0.8)
	var seed := M.seed_of(p, "crocus")
	var tr := clampf(M.pf(p, "trampled", 0.0), 0.0, 1.0)
	M.box(root, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), "tierra")
	for sz: float in [-1.0, 1.0]:
		M.box(root, Vector3(w + 0.08, 0.12, 0.04), Vector3(0, 0.06, sz * (d / 2 + 0.02)), "piedra_portland")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, 0.12, d), Vector3(sx * (w / 2 + 0.02), 0.06, 0), "piedra_portland")
	var n := int(w * d * 70)
	var cups: Array = []; var cc: Array = []; var stems: Array = []
	var pal := [M.color("azafran"), M.color("azafran_lila"), M.color("vela")]
	for i in n:
		var x := (M.rnd(seed, i, 0) - 0.5) * (w - 0.08)
		var z := (M.rnd(seed, i, 1) - 0.5) * (d - 0.08)
		var trampled := tr > 0 and (x + w / 2) / w < tr and absf(z) < d * 0.3
		var sh := M.rr(seed, i, 2, 0.04, 0.08) * (0.25 if trampled else 1.0)
		stems.append(Transform3D(Basis.from_scale(Vector3(0.006, sh, 0.006)), Vector3(x, 0.1 + sh / 2, z)))
		var tilt := Vector3((M.rnd(seed, i, 3) - 0.5) * 20, 0, (M.rnd(seed, i, 4) - 0.5) * 20)
		if trampled: tilt = Vector3(80, M.rnd(seed, i, 5) * 360, 0)
		cups.append(Transform3D(Basis.from_euler(tilt * PI / 180.0), Vector3(x, 0.1 + sh + 0.02, z)))
		cc.append(pal[int(M.rnd(seed, i, 6) * 3) % 3])
	M.multi_boxes(root, stems, [], "cesped")
	M.multi_boxes(root, cups, cc, "lomo", M.cyl_mesh(0.018, 0.006, 0.045, 6))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.12, d / 2))])
	return root

# ======================================================================================
# lawn_strip(w,d): franja de césped con cordón de piedra.
static func build_lawn_strip(p: Dictionary) -> Node3D:
	var root := M.root("lawn_strip")
	var w := M.pf(p, "w", 4.0); var d := M.pf(p, "d", 1.0)
	M.box(root, Vector3(w, 0.06, d), Vector3(0, 0.03, 0), "cesped")
	for sz: float in [-1.0, 1.0]:
		M.box(root, Vector3(w, 0.1, 0.08), Vector3(0, 0.05, sz * (d / 2 + 0.04)), "piedra_portland")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2 - 0.08), Vector3(w / 2, 0.1, d / 2 + 0.08))])
	return root

# ======================================================================================
# sign_board(text_key): tablero pintado con letras (Label3D, fuente imprenta). Extras: text (literal), w, h,
# mount ("wall" contra la pared, origen = centro inferior | "posts" sobre dos postes), paint, ink, y (altura en pared).
static func build_sign_board(p: Dictionary) -> Node3D:
	var root := M.root("sign_board")
	var txt := M.text_of(p, "text_key")
	var w := M.pf(p, "w", maxf(0.6, 0.075 * txt.length() + 0.2))
	var h := M.pf(p, "h", 0.4)
	var paint := M.ps(p, "paint", "madera_negra")
	var ink := Color(M.ps(p, "ink", "e8dcc0"))
	var mount := M.ps(p, "mount", "wall")
	var y := M.pf(p, "y", 0.0)
	var z := 0.02
	if mount == "posts":
		y = M.pf(p, "y", 1.2)
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.06, y + h, 0.06), Vector3(sx * (w / 2 - 0.05), (y + h) / 2, 0), "madera_media")
		z = 0.05
	M.box(root, Vector3(w, h, 0.03), Vector3(0, y + h / 2, z), paint)
	M.box(root, Vector3(w + 0.04, 0.025, 0.04), Vector3(0, y + h + 0.0125, z), paint)
	M.box(root, Vector3(w + 0.04, 0.025, 0.04), Vector3(0, y - 0.0125, z), paint)
	if txt != "":
		var px := minf(h * 0.55 / 48.0, (w - 0.08) / (48.0 * 0.82 * maxf(txt.length(), 1)))
		var lb := M.label3d(root, txt, Vector3(0, y + h / 2, z + 0.017), px, 48, ink)
		lb.name = "text"
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, y, z - 0.02), Vector3(w / 2, y + h, z + 0.02))])
	return root

# ======================================================================================
# kiosk: quiosco de diarios con toldo, mostrador con pilas de periódicos y carteles de titulares.
static func build_kiosk(p: Dictionary) -> Node3D:
	var root := M.root("kiosk")
	var w := M.pf(p, "w", 1.8); var d := M.pf(p, "d", 1.2); var h := M.pf(p, "h", 2.4)
	var mat := M.ps(p, "mat", "pintura_verde")
	M.box(root, Vector3(w, h, 0.05), Vector3(0, h / 2, -d / 2 + 0.025), mat)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, h, d), Vector3(sx * (w / 2 - 0.025), h / 2, 0), mat)
	M.box(root, Vector3(w, 0.95, 0.05), Vector3(0, 0.475, d / 2 - 0.025), mat)
	M.box(root, Vector3(w + 0.1, 0.05, 0.45), Vector3(0, 0.97, d / 2 + 0.17), "madera_media")
	M.box(root, Vector3(w + 0.3, 0.06, d + 0.5), Vector3(0, h + 0.03, 0.15), mat, Vector3(6, 0, 0))
	M.box(root, Vector3(w + 0.3, 0.22, 0.03), Vector3(0, h - 0.06, d / 2 + 0.4), "lienzo")
	var seed := M.seed_of(p, "kiosk")
	for k in 4:
		var x := -w / 2 + 0.25 + k * (w - 0.5) / 3.0
		for j in 6:
			M.box(root, Vector3(0.32, 0.008, 0.24), Vector3(x + (M.rnd(seed, k, j) - 0.5) * 0.02, 1.0 + j * 0.009, d / 2 + 0.17), "papel" if j % 2 == 0 else "papel_viejo", Vector3(0, (M.rnd(seed, k, j + 7) - 0.5) * 10, 0))
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.5, 0.75, 0.02), Vector3(sx * (w / 2 + 0.03), 1.35, d / 2 - 0.25), "papel", Vector3(0, sx * 90, 0))
		for l in 4:
			M.box(root, Vector3(0.4, 0.04, 0.005), Vector3(sx * (w / 2 + 0.045), 1.6 - l * 0.13, d / 2 - 0.25), "tinta", Vector3(0, sx * 90, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# ======================================================================================
# pavement(w,d,kind:"madera"|"granito"|"losas"): calzada de tarugos de madera o adoquines de granito, o vereda de losas.
# Extras: kerb ("+z" | "-z" | "": cordón de granito en ese borde), gutter.
static func build_pavement(p: Dictionary) -> Node3D:
	var root := M.root("pavement")
	var w := M.pf(p, "w", 6.0); var d := M.pf(p, "d", 4.0)
	var kind := M.ps(p, "kind", "granito")
	var mat := "adoquin"
	match kind:
		"madera": mat = "tarugo"
		"losas": mat = "piedra_portland"
		_: mat = "adoquin"
	var th := 0.12 if kind == "losas" else 0.04
	M.box(root, Vector3(w, th, d), Vector3(0, th / 2 - (0.0 if kind == "losas" else 0.0), 0), mat)
	var kerb := M.ps(p, "kerb", "")
	if kerb != "":
		var sz := 1.0 if kerb == "+z" else -1.0
		M.box(root, Vector3(w, 0.16, 0.2), Vector3(0, 0.08, sz * (d / 2 - 0.1)), "piedra_portland")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, th, d / 2))])
	return root

# ======================================================================================
# post_box: buzón de pie hexagonal (Penfold) con remate de capullo y boca.
static func build_post_box(p: Dictionary) -> Node3D:
	var root := M.root("post_box")
	var mat := M.ps(p, "mat", "pintura_roja")
	M.cyl(root, 0.3, 0.32, 0.12, Vector3(0, 0.06, 0), mat, Vector3.ZERO, 6)
	M.cyl(root, 0.26, 0.28, 1.05, Vector3(0, 0.645, 0), mat, Vector3.ZERO, 6)
	M.cyl(root, 0.34, 0.27, 0.12, Vector3(0, 1.23, 0), mat, Vector3.ZERO, 6)
	M.cyl(root, 0.18, 0.33, 0.14, Vector3(0, 1.36, 0), mat, Vector3.ZERO, 6)
	M.sphere(root, 0.07, Vector3(0, 1.48, 0), mat, Vector3(1, 1.4, 1))
	M.cyl(root, 0.0, 0.05, 0.1, Vector3(0, 1.6, 0), mat, Vector3.ZERO, 6)
	M.box(root, Vector3(0.24, 0.035, 0.04), Vector3(0, 1.08, 0.255), "carbon")
	M.box(root, Vector3(0.3, 0.06, 0.05), Vector3(0, 1.12, 0.26), mat)
	M.box(root, Vector3(0.18, 0.12, 0.01), Vector3(0, 0.8, 0.27), "vela")
	M.box(root, Vector3(0.3, 0.5, 0.012), Vector3(0, 0.45, 0.265), mat)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.32, 0, -0.32), Vector3(0.32, 1.6, 0.32))])
	return root
