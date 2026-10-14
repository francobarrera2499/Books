# world/props/l1.gd — W2-PLACES-A. Props propios de L1 (buhardilla de Holywell Street y tienda de Crane) y de las
# láminas PRO (prólogo) y M7. Contrato: docs/ARCHITECTURE.md §7.2 / §7.3: static func build_<fn>(p) -> Node3D con
# meta "occ" (Array de AABB o Transform3D locales). Origen = centro de la base; frente +Z; metros.
# Determinista (Materials.rnd, sin randf). Sólo PrimitiveMesh y MultiMesh de cajas.
# Uso en data/places/L1.json, data/plates/PRO.json y data/plates/M7.json: "type": "l1.<función>".
extends RefCounted

const M = preload("res://world/materials.gd")
const MQ = preload("res://world/characters/mannequin.gd")
const S = preload("res://world/props/street.gd")
const A = preload("res://world/props/architecture.gd")

static func _spine(seed: int, i: int) -> Color:
	var pal := [Color("5a3a2a"), Color("6a2e26"), Color("3e4a3c"), Color("2f3440"), Color("7a6448"), Color("4a4036"),
		Color("8a7050"), Color("2c2a2c"), Color("a08a60"), Color("5e4e3c"), Color("b8a888"), Color("3a2a20")]
	var c: Color = pal[int(M.rnd(seed, i, 99) * pal.size()) % pal.size()]
	var f := 0.8 + 0.4 * M.rnd(seed, i, 98)
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

# fila de lomos parados entre x0 y x1 (coords locales), apoyados en y0, profundidad d centrada en z
static func _spines(xf: Array, cc: Array, seed: int, salt: int, x0: float, x1: float, y0: float, hmax: float, d: float, z: float) -> void:
	var x := x0
	var i := 0
	while x < x1 - 0.015 and i < 300:
		var t := M.rr(seed, i, salt, 0.018, 0.05)
		if x + t > x1: break
		var bh := hmax * M.rr(seed, i, salt + 1, 0.62, 0.98)
		var bd := d * M.rr(seed, i, salt + 2, 0.7, 0.95)
		xf.append(M.xf_box(Vector3(t - 0.002, bh, bd), Vector3(x + t / 2, y0 + bh / 2, z)))
		cc.append(_spine(seed, i + salt * 31))
		x += t + (0.0015 if M.rnd(seed, i, salt + 3) < 0.85 else 0.02)
		i += 1

# ======================================================================================
# marker: nodo vacío (ancla lógica). Sirve para que un nodo apunte con `prop` a un personaje (mismo id): el esquema
# exige que `prop` sea un id de props, y RectClip/Picker tratan prop == id de personaje como «parte del personaje».
static func build_marker(p: Dictionary) -> Node3D:
	var n := M.root("marker")
	n.set_meta("occ", [])
	return n

# ======================================================================================
# reading_stand (atril): base, tablero inclinado con una hoja y pinza de latón. Extras: angle (grados), sheet (bool).
static func build_reading_stand(p: Dictionary) -> Node3D:
	var root := M.root("reading_stand")
	var w := M.pf(p, "w", 0.42); var d := M.pf(p, "d", 0.3)
	var ang := M.pf(p, "angle", 32.0)
	M.box(root, Vector3(w, 0.018, d), Vector3(0, 0.009, 0), "madera_oscura")
	var b := Node3D.new(); b.name = "board"; b.position = Vector3(0, 0.03, d * 0.32); b.rotation_degrees = Vector3(-ang, 0, 0)
	root.add_child(b)
	var bh := 0.34
	M.box(b, Vector3(w - 0.02, bh, 0.014), Vector3(0, bh / 2, -0.007), "madera_media")
	M.box(b, Vector3(w - 0.02, 0.025, 0.035), Vector3(0, 0.012, 0.012), "madera_oscura")
	if M.pb(p, "sheet", true):
		M.box(b, Vector3(0.21, 0.3, 0.002), Vector3(0, 0.17, 0.002), "papel")
		for l in 11:
			M.box(b, Vector3(0.15 if l % 4 != 3 else 0.09, 0.003, 0.0008), Vector3(-0.01 if l % 4 != 3 else -0.04, 0.29 - l * 0.022, 0.0035), "tinta")
		M.box(b, Vector3(0.05, 0.02, 0.012), Vector3(0, bh - 0.02, 0.006), "laton")
	# pata trasera
	M.beam_ab(root, Vector3(0, 0.02, -d * 0.35), Vector3(0, 0.03 + bh * 0.7 * cos(deg_to_rad(ang)), d * 0.32 - bh * 0.7 * sin(deg_to_rad(ang))), 0.02, 0.012, "madera_oscura")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.32, d / 2))])
	return root

# ======================================================================================
# notebook (cuaderno de recortes): tapas negras, cerrado, con tiras de papel pegadas que asoman. Extras: w, h, t, strips.
static func build_notebook(p: Dictionary) -> Node3D:
	var root := M.root("notebook")
	var w := M.pf(p, "w", 0.18); var h := M.pf(p, "h", 0.24); var t := M.pf(p, "t", 0.03)
	var seed := M.seed_of(p, "nb")
	M.box(root, Vector3(w, 0.004, h), Vector3(0, 0.002, 0), "tela_oscura")
	M.box(root, Vector3(w - 0.006, t - 0.008, h - 0.006), Vector3(0.002, t / 2, 0), "papel_viejo")
	M.box(root, Vector3(w, 0.004, h), Vector3(0, t - 0.002, 0), "tela_oscura")
	M.box(root, Vector3(0.012, t, h), Vector3(-w / 2 + 0.006, t / 2, 0), "cuero")
	M.box(root, Vector3(0.004, t * 0.6, h * 0.98), Vector3(w / 2 - 0.004, t / 2, 0), "papel_viejo")
	var n := M.pi_(p, "strips", 7)
	for i in n:
		var z := -h / 2 + 0.03 + (h - 0.06) * M.rnd(seed, i, 0)
		var lx := M.rr(seed, i, 1, 0.02, 0.06)
		M.box(root, Vector3(lx + 0.02, 0.0015, M.rr(seed, i, 2, 0.012, 0.022)), Vector3(w / 2 + lx / 2 - 0.01, 0.006 + t * M.rnd(seed, i, 3) * 0.8, z), "papel")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -h / 2), Vector3(w / 2, t, h / 2))])
	return root

# ======================================================================================
# thick_book (concordancia): cuaderno grueso de tapas de hule con fichas sujetas con alfileres que asoman por arriba.
static func build_thick_book(p: Dictionary) -> Node3D:
	var root := M.root("thick_book")
	var w := M.pf(p, "w", 0.22); var h := M.pf(p, "h", 0.29); var t := M.pf(p, "t", 0.065)
	var seed := M.seed_of(p, "tb")
	M.box(root, Vector3(w, 0.005, h), Vector3(0, 0.0025, 0), "pintura_verde")
	M.box(root, Vector3(w - 0.008, t - 0.01, h - 0.008), Vector3(0.003, t / 2, 0), "papel_viejo")
	M.box(root, Vector3(w, 0.005, h), Vector3(0, t - 0.0025, 0), "pintura_verde")
	M.box(root, Vector3(0.014, t, h), Vector3(-w / 2 + 0.007, t / 2, 0), "cuero")
	# cinta elástica
	M.box(root, Vector3(0.012, t + 0.004, h + 0.004), Vector3(w * 0.3, t / 2, 0), "tela_oscura")
	for i in 9:
		var x := -w / 2 + 0.03 + (w - 0.06) * M.rnd(seed, i, 0)
		M.box(root, Vector3(0.035, 0.0015, M.rr(seed, i, 1, 0.025, 0.05)), Vector3(x, 0.01 + (t - 0.02) * M.rnd(seed, i, 2), -h / 2 - 0.012), "papel")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -h / 2), Vector3(w / 2, t, h / 2))])
	return root

# ======================================================================================
# spectacles_case: estuche de cuero para anteojos, abierto y vacío.
static func build_spectacles_case(p: Dictionary) -> Node3D:
	var root := M.root("spectacles_case")
	M.box(root, Vector3(0.15, 0.022, 0.05), Vector3(0, 0.011, 0), "cuero")
	M.box(root, Vector3(0.14, 0.004, 0.04), Vector3(0, 0.0215, 0), "terciopelo")
	var lid := Node3D.new(); lid.position = Vector3(0, 0.022, -0.025); lid.rotation_degrees = Vector3(-105, 0, 0); root.add_child(lid)
	M.box(lid, Vector3(0.15, 0.008, 0.05), Vector3(0, 0.004, 0.025), "cuero")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.075, 0, -0.04), Vector3(0.075, 0.07, 0.025))])
	return root

# ======================================================================================
# banknotes: billetes de cinco libras (blancos, grandes) en un fajo con una cinta.
static func build_banknotes(p: Dictionary) -> Node3D:
	var root := M.root("banknotes")
	var n := M.pi_(p, "n", 6)
	var seed := M.seed_of(p, "bn")
	for i in n:
		var g := Node3D.new(); g.position = Vector3(M.rr(seed, i, 0, -0.01, 0.01), 0.0012 * i, M.rr(seed, i, 1, -0.008, 0.008))
		g.rotation_degrees = Vector3(0, M.rr(seed, i, 2, -6, 6), 0); root.add_child(g)
		M.box(g, Vector3(0.21, 0.0012, 0.13), Vector3(0, 0.0006, 0), "vela")
		M.box(g, Vector3(0.05, 0.0004, 0.03), Vector3(-0.06, 0.0014, -0.03), "tinta")
		M.box(g, Vector3(0.12, 0.0004, 0.004), Vector3(0.02, 0.0014, 0.03), "tinta")
	M.box(root, Vector3(0.025, 0.012, 0.135), Vector3(0.05, 0.006, 0), "pintura_roja")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.11, 0, -0.07), Vector3(0.11, 0.012, 0.07))])
	return root

# ======================================================================================
# clipping (recorte de diario suelto, doblado). Extras: w, h.
static func build_clipping(p: Dictionary) -> Node3D:
	var root := M.root("clipping")
	var w := M.pf(p, "w", 0.12); var h := M.pf(p, "h", 0.2)
	M.box(root, Vector3(w, 0.0015, h), Vector3(0, 0.001, 0), "papel_viejo")
	for l in 14:
		M.box(root, Vector3(w * 0.8, 0.0005, 0.003), Vector3(0, 0.0022, -h / 2 + 0.015 + l * (h - 0.03) / 14.0), "tinta")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -h / 2), Vector3(w / 2, 0.004, h / 2))])
	return root

# ======================================================================================
# loose_papers: hojas sueltas desparramadas (registro M1, escritorio). Extras: n, w (radio de dispersión), seed, crumpled.
static func build_loose_papers(p: Dictionary) -> Node3D:
	var root := M.root("loose_papers")
	var n := M.pi_(p, "n", 7)
	var r := M.pf(p, "w", 0.6)
	var seed := M.seed_of(p, "lp")
	for i in n:
		var g := Node3D.new()
		g.position = Vector3(M.rr(seed, i, 0, -r, r), 0.0015 * (i + 1), M.rr(seed, i, 1, -r * 0.6, r * 0.6))
		g.rotation_degrees = Vector3(M.rr(seed, i, 2, -3, 3), M.rr(seed, i, 3, 0, 360), 0)
		root.add_child(g)
		var pw := M.rr(seed, i, 4, 0.18, 0.22); var ph := M.rr(seed, i, 5, 0.24, 0.31)
		M.box(g, Vector3(pw, 0.0015, ph), Vector3.ZERO, "papel" if i % 3 != 2 else "papel_viejo")
		for l in 6:
			M.box(g, Vector3(pw * 0.7, 0.0004, 0.003), Vector3(0, 0.001, -ph / 2 + 0.03 + l * 0.035), "tinta")
	if M.pb(p, "crumpled", false):
		for i in 3:
			M.sphere(root, 0.035, Vector3(M.rr(seed, i, 7, -r, r), 0.03, M.rr(seed, i, 8, -r * 0.5, r * 0.5)), "papel", Vector3(1, 0.8, 0.9), 8)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# drawer_out: cajón del escritorio sacado y volcado sobre el piso (registro M1).
static func build_drawer_out(p: Dictionary) -> Node3D:
	var root := M.root("drawer_out")
	var w := M.pf(p, "w", 0.5); var d := M.pf(p, "d", 0.55)
	var g := Node3D.new(); g.rotation_degrees = Vector3(0, 0, 12); root.add_child(g)
	M.box(g, Vector3(w, 0.012, d), Vector3(0, 0.03, 0), "madera_oscura")
	M.box(g, Vector3(w, 0.09, 0.02), Vector3(0, 0.075, d / 2), "madera_media")
	M.box(g, Vector3(w, 0.07, 0.015), Vector3(0, 0.065, -d / 2), "madera_oscura")
	for sx: float in [-1.0, 1.0]:
		M.box(g, Vector3(0.015, 0.07, d), Vector3(sx * w / 2, 0.065, 0), "madera_oscura")
	M.torus(g, 0.012, 0.022, Vector3(0, 0.08, d / 2 + 0.015), "laton", Vector3(90, 0, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.02, 0, -d / 2), Vector3(w / 2 + 0.02, 0.15, d / 2 + 0.03))])
	return root

# ======================================================================================
# footprint (pisada): huella de bota grande y pesada, marcada en el polvo/ceniza del piso. Extras: s (escala).
static func build_footprint(p: Dictionary) -> Node3D:
	var root := M.root("footprint")
	var s := M.pf(p, "s", 1.0)
	var mat := M.ps(p, "mat", "ceniza")
	# suela (punta redonda) y taco separados, marcados en ceniza y polvo sobre las tablas
	M.box(root, Vector3(0.11 * s, 0.003, 0.14 * s), Vector3(0, 0.0015, 0.05 * s), mat)
	M.cyl(root, 0.055 * s, 0.055 * s, 0.003, Vector3(0, 0.0015, 0.12 * s), mat, Vector3.ZERO, 14)
	M.box(root, Vector3(0.09 * s, 0.003, 0.07 * s), Vector3(0, 0.0015, -0.11 * s), mat)
	# tachas del clavado
	for k in 6:
		M.box(root, Vector3(0.008, 0.0035, 0.008), Vector3((k % 2 - 0.5) * 0.06 * s, 0.002, 0.02 * s + (k / 2) * 0.045 * s), "carbon")
	root.set_meta("occ", [])
	return root

# ======================================================================================
# rug: alfombra gastada con guarda. Extras: w, d, mat.
static func build_rug(p: Dictionary) -> Node3D:
	var root := M.root("rug")
	var w := M.pf(p, "w", 1.6); var d := M.pf(p, "d", 1.1)
	M.box(root, Vector3(w, 0.008, d), Vector3(0, 0.004, 0), M.ps(p, "mat", "terciopelo"))
	M.box(root, Vector3(w - 0.16, 0.0085, d - 0.16), Vector3(0, 0.0045, 0), "tela_media")
	M.box(root, Vector3(w - 0.3, 0.009, d - 0.3), Vector3(0, 0.005, 0), M.ps(p, "mat", "terciopelo"))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# washstand (lavamanos): mesita con palangana, jarra y toalla.
static func build_washstand(p: Dictionary) -> Node3D:
	var root := M.root("washstand")
	var w := M.pf(p, "w", 0.6); var d := M.pf(p, "d", 0.42); var h := 0.76
	M.box(root, Vector3(w, 0.03, d), Vector3(0, h - 0.015, 0), "madera_clara")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.035, h - 0.03, 0.035), Vector3(sx * (w / 2 - 0.03), (h - 0.03) / 2, sz * (d / 2 - 0.03)), "madera_clara")
	M.box(root, Vector3(w - 0.06, 0.02, d - 0.06), Vector3(0, 0.18, 0), "madera_clara")
	M.box(root, Vector3(w, 0.12, 0.02), Vector3(0, h + 0.06, -d / 2 + 0.01), "madera_clara")
	M.cyl(root, 0.16, 0.08, 0.08, Vector3(0, h + 0.04, 0.02), "vela", Vector3.ZERO, 20)
	M.cyl(root, 0.05, 0.075, 0.24, Vector3(0.12, 0.2 + 0.12, 0.0), "vela", Vector3.ZERO, 14)
	M.torus(root, 0.025, 0.04, Vector3(0.18, 0.36, 0.0), "vela", Vector3(90, 0, 90))
	M.box(root, Vector3(0.02, 0.3, 0.2), Vector3(w / 2 + 0.01, h - 0.12, 0.0), "lienzo")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.12, d / 2))])
	return root

# ======================================================================================
# peg_rail: percha de pared con gabán, sombrero y bufanda. Origen = pie de la pared; frente +Z. Extras: y, hat.
static func build_peg_rail(p: Dictionary) -> Node3D:
	var root := M.root("peg_rail")
	var y := M.pf(p, "y", 1.7)
	M.box(root, Vector3(0.6, 0.08, 0.02), Vector3(0, y, 0.01), "madera_oscura")
	for k in 3:
		var x := -0.2 + k * 0.2
		M.rod_ab(root, 0.01, Vector3(x, y, 0.02), Vector3(x, y + 0.03, 0.11), "madera_negra")
	# gabán colgado (largo)
	M.cyl(root, 0.12, 0.16, 1.05, Vector3(-0.15, y - 0.6, 0.12), "tela_oscura", Vector3(3, 0, 0), 12).scale = Vector3(1.15, 1, 0.6)
	M.sphere(root, 0.1, Vector3(-0.15, y - 0.08, 0.1), "tela_oscura", Vector3(1.7, 0.5, 0.8))
	# sombrero de copa baja (hongo) colgado
	var hp := Node3D.new(); hp.position = Vector3(0.18, y + 0.02, 0.13); hp.rotation_degrees = Vector3(-70, 0, 0); root.add_child(hp)
	M.hemi(hp, 0.09, Vector3(0, 0.06, 0), "fieltro", Vector3.ZERO, Vector3(1, 1.0, 1.1))
	M.cyl(hp, 0.09, 0.09, 0.06, Vector3(0, 0.03, 0), "fieltro", Vector3.ZERO, 18)
	M.cyl(hp, 0.14, 0.14, 0.01, Vector3(0, 0.0, 0), "fieltro", Vector3.ZERO, 20)
	# bufanda
	M.box(root, Vector3(0.06, 0.55, 0.012), Vector3(0.0, y - 0.25, 0.12), "tela_media", Vector3(0, 0, 4))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.3, y - 1.15, 0), Vector3(0.3, y + 0.15, 0.3))])
	return root

# ======================================================================================
# gas_bracket: brazo de gas de pared con globo de vidrio esmerilado. Origen = pie de la pared; frente +Z.
# Marca "light" = {kind: gas} (Lighting lo enciende de noche). Extras: y (altura de la llama), lit, shadow.
static func build_gas_bracket(p: Dictionary) -> Node3D:
	var root := M.root("gas_bracket")
	var y := M.pf(p, "y", 1.85)
	M.cyl(root, 0.035, 0.035, 0.02, Vector3(0, y - 0.12, 0.01), "laton", Vector3(90, 0, 0), 12)
	M.rod_ab(root, 0.009, Vector3(0, y - 0.12, 0.02), Vector3(0, y - 0.12, 0.2), "laton")
	M.rod_ab(root, 0.009, Vector3(0, y - 0.12, 0.2), Vector3(0, y - 0.05, 0.22), "laton")
	M.sphere(root, 0.012, Vector3(0, y - 0.12, 0.2), "laton")
	M.cyl(root, 0.03, 0.022, 0.03, Vector3(0, y - 0.04, 0.22), "laton", Vector3.ZERO, 12)
	var lit := M.pb(p, "lit", true)
	M.sphere(root, 0.075, Vector3(0, y + 0.03, 0.22), "vela", Vector3(1, 1.05, 1), 16)
	M.sphere(root, 0.02, Vector3(0, y + 0.0, 0.22), "gas_emisivo" if lit else "vela", Vector3(1, 1.5, 1), 8)
	var fl := Node3D.new(); fl.name = "flame"; fl.position = Vector3(0, y + 0.03, 0.22); root.add_child(fl)
	if lit:
		fl.set_meta("light", {"kind": "gas", "shadow": M.pb(p, "shadow", false)})
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.08, y - 0.15, 0), Vector3(0.08, y + 0.11, 0.3))])
	return root

# ======================================================================================
# counter_lamp: mechero de gas de mostrador, bajo (llama a ~0,22 m sobre la tapa), con tubo y tulipa abierta.
# Lleva su propia OmniLight3D SIEMPRE encendida (no marcada con meta "light": la tienda es oscura todo el día) con
# sombras: es la luz que proyecta hasta el techo la sombra del librero (GDD §5, §14.4; el nodo lo dice en su examen).
# Extras: energy, range, shadow (def true), color, stand (alto de un pie de hierro: mechero de pie; 0 = sobre el mostrador).
static func build_counter_lamp(p: Dictionary) -> Node3D:
	var base := M.root("counter_lamp")
	var stand := M.pf(p, "stand", 0.0)
	var root := base
	if stand > 0.0:
		# pie de hierro (mechero de pie): base de tres patas y columna
		for k in 3:
			var a := TAU * k / 3.0
			M.beam_ab(base, Vector3(0, 0.08, 0), Vector3(cos(a) * 0.22, 0.0, sin(a) * 0.22), 0.035, 0.02, "hierro")
		M.cyl(base, 0.03, 0.04, stand, Vector3(0, stand / 2, 0), "hierro", Vector3.ZERO, 10)
		M.torus(base, 0.03, 0.05, Vector3(0, stand * 0.6, 0), "hierro")
		root = Node3D.new(); root.position = Vector3(0, stand, 0); base.add_child(root)
	M.cyl(root, 0.07, 0.085, 0.03, Vector3(0, 0.015, 0), "laton", Vector3.ZERO, 18)
	M.cyl(root, 0.012, 0.016, 0.15, Vector3(0, 0.105, 0), "laton", Vector3.ZERO, 10)
	M.torus(root, 0.012, 0.026, Vector3(0, 0.06, 0), "laton")
	M.cyl(root, 0.025, 0.018, 0.03, Vector3(0, 0.19, 0), "laton", Vector3.ZERO, 10)
	M.cyl(root, 0.03, 0.026, 0.07, Vector3(0, 0.24, 0), "vidrio", Vector3.ZERO, 12)
	M.sphere(root, 0.014, Vector3(0, 0.22, 0), "gas_emisivo", Vector3(1, 1.7, 1), 8)
	# tubo de goma hasta el borde del mostrador
	M.arc(root, Vector3(-0.12, 0.03, 0.0), 0.1, Vector3.RIGHT, Vector3.UP, 0.0, PI * 0.9, 6, 0.008, "carbon")
	var o := OmniLight3D.new()
	o.name = "CounterGas"
	o.position = Vector3(0, 0.23, 0)
	o.light_color = Color(M.ps(p, "color", "ffb45e"))
	o.light_energy = M.pf(p, "energy", 3.2)
	o.omni_range = M.pf(p, "range", 6.5)
	o.omni_attenuation = 1.0
	o.light_specular = 0.0
	o.shadow_enabled = M.pb(p, "shadow", true)
	o.shadow_bias = 0.03
	o.set_meta("always_on", true)
	# la lámpara no se hace sombra a sí misma (tubo, tulipa, pie)
	for gi in base.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(o)
	if stand > 0.0:
		base.set_meta("occ", [M.aabb_mm(Vector3(-0.09, stand, -0.09), Vector3(0.09, stand + 0.28, 0.09)), M.aabb_mm(Vector3(-0.04, 0, -0.04), Vector3(0.04, stand, 0.04))])
	else:
		base.set_meta("occ", [M.aabb_mm(Vector3(-0.09, 0, -0.09), Vector3(0.09, 0.28, 0.09))])
	return base

# ======================================================================================
# shop_window (escaparate de Crane, visto desde adentro): marco de madera, vidrio en cuarterones, gradas con libros
# acostados y parados de espaldas a la tienda. Origen = centro del pie del vano (a la altura del antepecho);
# frente +Z = interior. Extras: w, h, depth (fondo de las gradas), seed.
static func build_shop_window(p: Dictionary) -> Node3D:
	var root := M.root("shop_window")
	var w := M.pf(p, "w", 2.3); var h := M.pf(p, "h", 1.9)
	var dep := M.pf(p, "depth", 0.55)
	var seed := M.seed_of(p, "sw")
	var fr := 0.07
	# marco perimetral y montantes
	M.box(root, Vector3(w, fr, 0.12), Vector3(0, h - fr / 2, 0), "madera_negra")
	M.box(root, Vector3(w, fr, 0.12), Vector3(0, fr / 2, 0), "madera_negra")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(fr, h, 0.12), Vector3(sx * (w / 2 - fr / 2), h / 2, 0), "madera_negra")
	var cols := 4; var rows := 3
	var bars: Array = []
	for i in range(1, cols):
		bars.append(M.xf_box(Vector3(0.03, h - 2 * fr, 0.05), Vector3(-w / 2 + w * i / cols, h / 2, 0)))
	for j in range(1, rows):
		bars.append(M.xf_box(Vector3(w - 2 * fr, 0.03, 0.05), Vector3(0, fr + (h - 2 * fr) * j / rows, 0)))
	M.multi_boxes(root, bars, [], "madera_negra")
	M.box(root, Vector3(w - 2 * fr, h - 2 * fr, 0.006), Vector3(0, h / 2, -0.02), "vidrio")
	# gradas (tres escalones) con libros
	var xf: Array = []; var cc: Array = []
	for k in 3:
		var sy := 0.0 + k * 0.17
		var sz := 0.06 + (2 - k) * dep / 3.0
		M.box(root, Vector3(w - 0.12, 0.025, dep / 3.0), Vector3(0, sy + 0.012, sz + dep / 6.0), "madera_media")
		M.box(root, Vector3(w - 0.12, sy + 0.012, 0.02), Vector3(0, (sy + 0.012) / 2, sz + dep / 3.0), "madera_oscura")
		var x := -w / 2 + 0.1
		var i := 0
		while x < w / 2 - 0.15 and i < 40:
			var bw := M.rr(seed, i, k, 0.12, 0.2)
			var bh := M.rr(seed, i, k + 5, 0.16, 0.24)
			if M.rnd(seed, i, k + 9) < 0.55:
				# acostado
				xf.append(M.xf_box(Vector3(bw, M.rr(seed, i, k + 11, 0.02, 0.04), bh), Vector3(x + bw / 2, sy + 0.04, sz + dep / 6.0), Vector3(0, M.rr(seed, i, k + 13, -10, 10), 0)))
			else:
				# parado, apoyado hacia la calle (se ve la contratapa)
				xf.append(M.xf_box(Vector3(bw, bh, 0.03), Vector3(x + bw / 2, sy + 0.025 + bh / 2 * 0.95, sz + 0.02), Vector3(-14, 0, 0)))
			cc.append(_spine(seed, i + k * 50))
			x += bw + 0.04
			i += 1
	M.multi_boxes(root, xf, cc)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -0.06), Vector3(w / 2, fr, 0.06)), M.aabb_mm(Vector3(-w / 2, h - fr, -0.06), Vector3(w / 2, h, 0.06)),
		M.aabb_mm(Vector3(-w / 2, 0, -0.06), Vector3(-w / 2 + fr, h, 0.06)), M.aabb_mm(Vector3(w / 2 - fr, 0, -0.06), Vector3(w / 2, h, 0.06)),
		M.aabb_mm(Vector3(-w / 2 + 0.06, 0, 0.06), Vector3(w / 2 - 0.06, 0.4, 0.06 + dep))])
	return root

# ======================================================================================
# shop_door: puerta de tienda con hoja de vidrio en la mitad superior, montante y campanilla de resorte.
# Origen = centro del umbral; frente +Z = interior. Extras: w, h, open (0..1), depth.
static func build_shop_door(p: Dictionary) -> Node3D:
	var root := M.root("shop_door")
	var w := M.pf(p, "w", 0.95); var h := M.pf(p, "h", 2.35)
	var dep := M.pf(p, "depth", 0.16)
	var of := clampf(M.pf(p, "open", 0.0), 0.0, 1.0)
	var fan := 0.42
	var dh := h - fan
	M.box(root, Vector3(0.05, h, dep), Vector3(-w / 2 + 0.025, h / 2, 0), "madera_negra")
	M.box(root, Vector3(0.05, h, dep), Vector3(w / 2 - 0.025, h / 2, 0), "madera_negra")
	M.box(root, Vector3(w, 0.06, dep), Vector3(0, dh + 0.03, 0), "madera_negra")
	M.box(root, Vector3(w, 0.05, dep), Vector3(0, h - 0.025, 0), "madera_negra")
	M.box(root, Vector3(w - 0.1, fan - 0.11, 0.006), Vector3(0, dh + fan / 2, 0), "vidrio")
	for k in 3:
		M.box(root, Vector3(0.02, fan - 0.11, 0.03), Vector3(-w / 2 + 0.05 + (w - 0.1) * (k + 1) / 4.0, dh + fan / 2, 0), "madera_negra")
	var hinge := Node3D.new(); hinge.position = Vector3(-w / 2 + 0.05, 0, dep / 2 - 0.03); hinge.rotation_degrees = Vector3(0, -of * 95.0, 0); root.add_child(hinge)
	var lw := w - 0.1
	var leaf := Node3D.new(); leaf.position = Vector3(lw / 2, 0, 0); hinge.add_child(leaf)
	M.box(leaf, Vector3(lw, dh * 0.5, 0.045), Vector3(0, dh * 0.25 + 0.01, 0), "madera_oscura")
	M.box(leaf, Vector3(lw, 0.08, 0.045), Vector3(0, dh - 0.04, 0), "madera_oscura")
	for sx: float in [-1.0, 1.0]:
		M.box(leaf, Vector3(0.08, dh * 0.5, 0.045), Vector3(sx * (lw / 2 - 0.04), dh * 0.75, 0), "madera_oscura")
	M.box(leaf, Vector3(lw - 0.16, dh * 0.5 - 0.08, 0.006), Vector3(0, dh * 0.73, 0), "vidrio")
	M.box(leaf, Vector3(0.02, dh * 0.5 - 0.08, 0.025), Vector3(0, dh * 0.73, 0), "madera_oscura")
	M.box(leaf, Vector3(lw * 0.6, dh * 0.3, 0.012), Vector3(0, dh * 0.25, 0.028), "madera_media")
	M.sphere(leaf, 0.025, Vector3(lw / 2 - 0.08, 1.0, 0.05), "laton")
	M.box(leaf, Vector3(0.22, 0.03, 0.004), Vector3(0, dh * 0.53, 0.026), "laton")
	# campanilla de resorte sobre la puerta (adentro)
	M.rod_ab(root, 0.005, Vector3(w / 2 - 0.2, dh + 0.02, dep / 2), Vector3(w / 2 - 0.2, dh - 0.08, dep / 2 + 0.12), "laton")
	M.hemi(root, 0.035, Vector3(w / 2 - 0.2, dh - 0.12, dep / 2 + 0.12), "laton", Vector3(180, 0, 0))
	var occ := [M.aabb_mm(Vector3(-w / 2, dh, -dep / 2), Vector3(w / 2, h, dep / 2)), M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(-w / 2 + 0.05, h, dep / 2)),
		M.aabb_mm(Vector3(w / 2 - 0.05, 0, -dep / 2), Vector3(w / 2, h, dep / 2))]
	if of < 0.3: occ.append(M.aabb_mm(Vector3(-w / 2, 0, -0.03), Vector3(w / 2, dh * 0.5, 0.05)))
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# paper_lot: lote de papel de imprenta vendido al peso: pliegos de pruebas sueltos atados con bramante en cruz.
static func build_paper_lot(p: Dictionary) -> Node3D:
	var root := M.root("paper_lot")
	var w := M.pf(p, "w", 0.42); var d := M.pf(p, "d", 0.32); var n := M.pi_(p, "n", 3)
	var seed := M.seed_of(p, "pl")
	var y := 0.0
	for b in n:
		var hh := M.rr(seed, b, 0, 0.07, 0.12)
		var g := Node3D.new(); g.position = Vector3(M.rr(seed, b, 1, -0.03, 0.03), y, M.rr(seed, b, 2, -0.02, 0.02))
		g.rotation_degrees = Vector3(0, M.rr(seed, b, 3, -12, 12), 0); root.add_child(g)
		var xf: Array = []; var cc: Array = []
		var k := 0
		var yy := 0.0
		while yy < hh and k < 40:
			var th := 0.004
			xf.append(M.xf_box(Vector3(w * M.rr(seed, b * 50 + k, 4, 0.94, 1.0), th, d * M.rr(seed, b * 50 + k, 5, 0.94, 1.0)), Vector3(M.rr(seed, b * 50 + k, 6, -0.012, 0.012), yy + th / 2, M.rr(seed, b * 50 + k, 7, -0.012, 0.012)), Vector3(0, M.rr(seed, b * 50 + k, 8, -3, 3), 0)))
			var f := 0.86 + 0.14 * M.rnd(seed, b * 50 + k, 9)
			cc.append(M.color("papel_viejo") * Color(f, f, f))
			yy += th; k += 1
		M.multi_boxes(g, xf, cc)
		M.box(g, Vector3(w + 0.02, 0.006, 0.012), Vector3(0, yy + 0.002, 0), "lienzo")
		M.box(g, Vector3(0.012, 0.006, d + 0.02), Vector3(0, yy + 0.003, 0), "lienzo")
		for sx: float in [-1.0, 1.0]:
			M.box(g, Vector3(0.006, yy, 0.012), Vector3(sx * (w / 2 + 0.006), yy / 2, 0), "lienzo")
		y += yy + 0.006
	# etiqueta de precio
	M.box(root, Vector3(0.08, 0.002, 0.05), Vector3(0.1, y + 0.002, 0.05), "papel")
	M.label3d(root, M.ps(p, "price", "AL PESO"), Vector3(0.1, y + 0.004, 0.05), 0.0004, 40, Color("1b1712")).rotation_degrees = Vector3(-90, 0, 0)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.04, 0, -d / 2 - 0.04), Vector3(w / 2 + 0.04, y, d / 2 + 0.04))])
	return root

# ======================================================================================
# photo_box: caja de cartón con fotografías-recuerdo en pie (tarjetas montadas), una afuera apoyada.
static func build_photo_box(p: Dictionary) -> Node3D:
	var root := M.root("photo_box")
	var w := M.pf(p, "w", 0.3); var d := M.pf(p, "d", 0.22); var h := 0.1
	var seed := M.seed_of(p, "ph")
	M.box(root, Vector3(w, 0.01, d), Vector3(0, 0.005, 0), "lienzo")
	M.box(root, Vector3(w, h, 0.008), Vector3(0, h / 2, d / 2), "lienzo")
	M.box(root, Vector3(w, h, 0.008), Vector3(0, h / 2, -d / 2), "lienzo")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.008, h, d), Vector3(sx * w / 2, h / 2, 0), "lienzo")
	var n := 14
	for i in n:
		var z := -d / 2 + 0.02 + (d - 0.04) * i / float(n - 1)
		var g := Node3D.new(); g.position = Vector3(M.rr(seed, i, 0, -0.01, 0.01), 0.01, z); g.rotation_degrees = Vector3(M.rr(seed, i, 1, -12, 8), 0, 0); root.add_child(g)
		M.box(g, Vector3(w - 0.03, 0.15, 0.003), Vector3(0, 0.075, 0), "papel_viejo")
		M.box(g, Vector3(w - 0.07, 0.1, 0.0035), Vector3(0, 0.085, 0.0), "madera_media" if i % 3 else "ceniza")
	# una tarjeta afuera, apoyada en la caja: una cascada (vista de lejos)
	var t := Node3D.new(); t.position = Vector3(0, 0.0, d / 2 + 0.06); t.rotation_degrees = Vector3(-72, 0, 0); root.add_child(t)
	M.box(t, Vector3(0.22, 0.003, 0.16), Vector3(0, 0.0, 0.08), "papel_viejo")
	M.box(t, Vector3(0.18, 0.0035, 0.11), Vector3(0, 0.0, 0.085), "roca")
	M.box(t, Vector3(0.025, 0.004, 0.1), Vector3(0.01, 0.0, 0.085), "vela")
	M.box(t, Vector3(0.06, 0.004, 0.004), Vector3(-0.04, 0.0, 0.06), "carbon")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.17, d / 2 + 0.1))])
	return root

# ======================================================================================
# newspaper_bundle: pila de diarios atrasados doblados y atados con cordel. Extras: n, w, d.
static func build_newspaper_bundle(p: Dictionary) -> Node3D:
	var root := M.root("newspaper_bundle")
	var w := M.pf(p, "w", 0.38); var d := M.pf(p, "d", 0.28); var n := M.pi_(p, "n", 26)
	var seed := M.seed_of(p, "nw")
	var xf: Array = []; var cc: Array = []
	for i in n:
		var th := 0.006
		xf.append(M.xf_box(Vector3(w, th, d), Vector3(M.rr(seed, i, 0, -0.015, 0.015), th * (i + 0.5), M.rr(seed, i, 1, -0.01, 0.01)), Vector3(0, M.rr(seed, i, 2, -4, 4), 0)))
		var f := 0.8 + 0.2 * M.rnd(seed, i, 3)
		cc.append(M.color("papel_viejo") * Color(f, f, f * 0.95))
	M.multi_boxes(root, xf, cc)
	var hh := n * 0.006
	M.box(root, Vector3(w + 0.01, 0.005, 0.01), Vector3(0, hh + 0.002, 0), "lienzo")
	M.box(root, Vector3(0.01, 0.005, d + 0.01), Vector3(0.05, hh + 0.002, 0), "lienzo")
	# la de arriba: cabecera con renglones
	for l in 3:
		M.box(root, Vector3(w * 0.7, 0.0008, 0.012 if l == 0 else 0.004), Vector3(0, hh + 0.0005, -d / 2 + 0.03 + l * 0.025), "tinta")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, hh + 0.01, d / 2))])
	return root

# ======================================================================================
# magazine_stack: números sueltos de revista apilados, con tapas claras y titular (la Strand: tapa celeste clara).
static func build_magazine_stack(p: Dictionary) -> Node3D:
	var root := M.root("magazine_stack")
	var n := M.pi_(p, "n", 9)
	var seed := M.seed_of(p, "mg")
	var y := 0.0
	for i in n:
		var g := Node3D.new(); g.position = Vector3(M.rr(seed, i, 0, -0.012, 0.012), y, M.rr(seed, i, 1, -0.012, 0.012)); g.rotation_degrees = Vector3(0, M.rr(seed, i, 2, -7, 7), 0); root.add_child(g)
		M.box(g, Vector3(0.17, 0.008, 0.245), Vector3(0, 0.004, 0), "papel_viejo")
		M.box(g, Vector3(0.17, 0.001, 0.245), Vector3(0, 0.0085, 0), "lienzo" if i % 2 else "papel")
		M.box(g, Vector3(0.12, 0.0012, 0.02), Vector3(0, 0.009, -0.09), "tinta")
		y += 0.0095
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.1, 0, -0.14), Vector3(0.1, y, 0.14))])
	return root

# ======================================================================================
# book_table: mesa de saldos con pilas de libros y un cartel de precio parado. Extras: w, d, sign (texto), seed.
static func build_book_table(p: Dictionary) -> Node3D:
	var root := M.root("book_table")
	var w := M.pf(p, "w", 1.3); var d := M.pf(p, "d", 0.75); var h := 0.78
	var seed := M.seed_of(p, "bt")
	M.box(root, Vector3(w, 0.035, d), Vector3(0, h - 0.0175, 0), "madera_oscura")
	M.box(root, Vector3(w - 0.08, 0.08, d - 0.08), Vector3(0, h - 0.07, 0), "madera_oscura")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.05, h - 0.035, 0.05), Vector3(sx * (w / 2 - 0.05), (h - 0.035) / 2, sz * (d / 2 - 0.05)), "madera_oscura")
	var xf: Array = []; var cc: Array = []
	var piles := maxi(int(w / 0.24), 2)
	for k in piles:
		for r in 2:
			var px := -w / 2 + 0.14 + (w - 0.28) * k / float(piles - 1)
			var pz := (-0.17 if r == 0 else 0.17)
			var y := h
			var nb := 2 + int(M.rnd(seed, k, r) * 5)
			for i in nb:
				var bw := M.rr(seed, k * 10 + i, r, 0.13, 0.2)
				var bd := M.rr(seed, k * 10 + i, r + 3, 0.18, 0.26)
				var bt := M.rr(seed, k * 10 + i, r + 6, 0.02, 0.05)
				xf.append(M.xf_box(Vector3(bw, bt, bd), Vector3(px + M.rr(seed, k * 10 + i, r + 9, -0.015, 0.015), y + bt / 2, pz), Vector3(0, M.rr(seed, k * 10 + i, r + 12, -15, 15), 0)))
				cc.append(_spine(seed, k * 20 + i + r * 7))
				y += bt
	M.multi_boxes(root, xf, cc)
	var txt := M.ps(p, "sign", "")
	if txt != "":
		var sg := Node3D.new(); sg.position = Vector3(0, h, 0.0); root.add_child(sg)
		M.box(sg, Vector3(0.36, 0.2, 0.006), Vector3(0, 0.12, 0), "papel")
		M.box(sg, Vector3(0.02, 0.06, 0.08), Vector3(0, 0.03, -0.03), "madera_media")
		var lb := M.label3d(sg, txt, Vector3(0, 0.12, 0.004), 0.0011, 48, Color("1b1712"))
		lb.width = 300.0; lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, h - 0.12, -d / 2), Vector3(w / 2, h + 0.12, d / 2))])
	return root

# ======================================================================================
# stair_glimpse: escalera estrecha que se ve por una puerta entreabierta (hueco oscuro con peldaños).
# Origen = centro del umbral, del lado de afuera del cuarto; la escalera sube (dir "up") o baja ("down") hacia −Z.
static func build_stair_glimpse(p: Dictionary) -> Node3D:
	var root := M.root("stair_glimpse")
	var w := M.pf(p, "w", 0.85)
	var up := M.ps(p, "dir", "up") == "up"
	var depth := 1.6
	# caja oscura del hueco
	M.box(root, Vector3(w + 0.3, 2.6, 0.05), Vector3(0, 1.3, -depth), "interior_oscuro")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, 2.6, depth), Vector3(sx * (w / 2 + 0.15), 1.3, -depth / 2), "yeso_sucio")
	M.box(root, Vector3(w + 0.3, 0.05, depth), Vector3(0, 2.6, -depth / 2), "yeso_sucio")
	for i in 6:
		var y := (i + 1) * 0.19 if up else -(i + 1) * 0.19 + 0.0
		var z := -0.15 - i * 0.24
		M.box(root, Vector3(w, 0.04, 0.26), Vector3(0, y, z), "madera_media")
		M.box(root, Vector3(w, 0.19, 0.03), Vector3(0, y - 0.095, z + 0.12), "madera_oscura")
	M.box(root, Vector3(0.05, 0.05, depth), Vector3(w / 2 + 0.08, 0.95 + (0.5 if up else -0.5), -depth / 2), "caoba", Vector3(-30 if up else 30, 0, 0))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# own_front: fachada de la casa de Lisle (planta baja = tienda de Crane, dos pisos y el frontón de la buhardilla).
# Muro plano (sin vanos de la buhardilla ni de la tienda: los ponen los cuartos) que tapa el hueco entre ambos.
# Origen = centro del pie (vereda); frente +Z = calle (en L1 se gira 180°). Extras: w, y0 (piso 1), y1 (piso de la buhardilla), sign.
static func build_own_front(p: Dictionary) -> Node3D:
	var root := M.root("own_front")
	var w := M.pf(p, "w", 5.12)
	var y0 := M.pf(p, "y0", 3.25); var y1 := M.pf(p, "y1", 6.33)
	var t := 0.16
	# piso 1 y 2 (entramado sobre revoque), con dos ventanas por piso
	var mid := (y0 + y1) / 2.0
	for k in 2:
		var b := y0 + k * (y1 - y0) / 2.0
		var fh := (y1 - y0) / 2.0
		M.box(root, Vector3(w, fh, t), Vector3(0, b + fh / 2, -t / 2), "yeso_sucio")
		M.box(root, Vector3(w + 0.1, 0.18, 0.24), Vector3(0, b + 0.09, 0.02), "madera_negra")
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.75, 1.2, 0.03), Vector3(sx * 1.3, b + 0.95, 0.005), "interior_oscuro")
			M.box(root, Vector3(0.85, 0.06, 0.06), Vector3(sx * 1.3, b + 0.35, 0.03), "madera_negra")
			M.box(root, Vector3(0.85, 0.06, 0.06), Vector3(sx * 1.3, b + 1.58, 0.03), "madera_negra")
			M.box(root, Vector3(0.05, 1.2, 0.05), Vector3(sx * 1.3, b + 0.95, 0.03), "madera_negra")
			M.box(root, Vector3(0.85, 0.04, 0.05), Vector3(sx * 1.3, b + 0.95, 0.03), "madera_negra")
		M.box(root, Vector3(0.12, fh, 0.05), Vector3(-w / 2 + 0.06, b + fh / 2, 0.02), "madera_negra")
		M.box(root, Vector3(0.12, fh, 0.05), Vector3(w / 2 - 0.06, b + fh / 2, 0.02), "madera_negra")
	# rótulo de la tienda (faja sobre la vidriera)
	M.box(root, Vector3(w, 0.5, 0.12), Vector3(0, y0 - 0.32, 0.04), "madera_negra")
	var sign_txt := M.ps(p, "sign", "")
	if sign_txt != "":
		M.label3d(root, sign_txt, Vector3(0, y0 - 0.32, 0.105), 0.0055, 56, Color("e8dcc0"))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, y0, -t), Vector3(w / 2, y1, 0.0))])
	return root

# ======================================================================================
# holywell_row: hilera de casas viejas de Holywell Street, enfrente: planta baja de librería (vidriera de cuarterones,
# faja con rótulo), pisos altos de entramado y revoque que salen sobre la calle (pisos salientes), frontones con
# aleros y canaletas; alguna de ladrillo. Origen = centro del pie de la línea de planta baja; frente +Z; fondo −Z.
# p.houses: [{w, floors, gable, brick, sign, moon, stall, shut, door:"left"|"right"}] (si falta: n casas por seed).
# Extras: seed, jetty. Media luna (moon): placa en el primer piso, centrada en x = w/2 − 0,62, y = 4,1, z = jetty + 0,08.
static func build_holywell_row(p: Dictionary) -> Node3D:
	var root := M.root("holywell_row")
	var seed := M.seed_of(p, "hw")
	var jet := M.pf(p, "jetty", 0.3)
	var houses: Array = p.get("houses", [])
	if houses.is_empty():
		for i in M.pi_(p, "n", 5):
			houses.append({"w": M.rr(seed, i, 0, 3.4, 4.6), "floors": 2 + int(M.rnd(seed, i, 1) * 2), "gable": M.rnd(seed, i, 2) < 0.6})
	var tot := 0.0
	for hd in houses: tot += float(hd.get("w", 4.0))
	var x := -tot / 2.0
	var occ: Array = []
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var hw := float(hd.get("w", 4.0))
		var g := Node3D.new(); g.name = "house_%d" % i; g.position = Vector3(x + hw / 2.0, 0, 0); root.add_child(g)
		occ.append_array(_house(g, hd, hw, jet, seed + i * 17))
		x += hw
	root.set_meta("occ", occ)
	return root

static func _house(g: Node3D, hd: Dictionary, hw: float, jet: float, seed: int) -> Array:
	var gh := 3.15
	var floors := int(hd.get("floors", 2))
	var brick := bool(hd.get("brick", false))
	var j := 0.0 if brick else jet
	var fhs := [2.6, 2.45, 2.3]
	var depth := 4.0
	var occ: Array = []
	var gx: Vector3 = g.position
	# ---- planta baja: frente de tienda
	var shut := bool(hd.get("shut", false))
	M.box(g, Vector3(hw, gh, 0.1), Vector3(0, gh / 2, -0.25), "interior_oscuro")
	for sx: float in [-1.0, 1.0]:
		M.box(g, Vector3(0.22, gh, 0.2), Vector3(sx * (hw / 2 - 0.11), gh / 2, -0.05), "madera_negra")
	M.box(g, Vector3(hw, 0.52, 0.16), Vector3(0, gh - 0.3, -0.02), "madera_negra")
	M.box(g, Vector3(hw + 0.04, 0.06, 0.24), Vector3(0, gh - 0.02, 0.0), "madera_negra")
	var sign_txt := str(hd.get("sign", ""))
	if sign_txt != "":
		M.label3d(g, sign_txt, Vector3(0, gh - 0.3, 0.065), 0.0045, 56, Color("e8dcc0"))
	var door_left := M.rnd(seed, 1, 1) < 0.5
	if str(hd.get("door", "")) != "": door_left = str(hd.get("door", "")) == "left"
	var dw := 0.92
	var dx := (-hw / 2 + 0.22 + dw / 2 + 0.05) if door_left else (hw / 2 - 0.22 - dw / 2 - 0.05)
	# puerta (hoja oscura con vidrio alto) y montante
	M.box(g, Vector3(dw, 2.3, 0.06), Vector3(dx, 1.15, -0.12), "madera_oscura")
	M.box(g, Vector3(dw - 0.2, 0.9, 0.065), Vector3(dx, 1.62, -0.11), "interior_oscuro")
	M.box(g, Vector3(dw + 0.08, 0.06, 0.12), Vector3(dx, 2.33, -0.08), "madera_negra")
	M.sphere(g, 0.025, Vector3(dx + (0.32 if door_left else -0.32), 1.05, -0.07), "laton")
	# vidriera de cuarterones con libros
	var wx0 := (dx + dw / 2 + 0.12) if door_left else (-hw / 2 + 0.3)
	var wx1 := (hw / 2 - 0.3) if door_left else (dx - dw / 2 - 0.12)
	var ww := wx1 - wx0
	var wcx := (wx0 + wx1) / 2.0
	var sill := 0.62
	var wh := gh - 0.62 - sill - 0.05
	M.box(g, Vector3(ww + 0.1, sill, 0.14), Vector3(wcx, sill / 2, -0.06), "madera_negra")
	if shut:
		# postigos cerrados (tablas verticales)
		var nb := int(ww / 0.18)
		for k in nb:
			M.box(g, Vector3(ww / nb - 0.012, wh, 0.03), Vector3(wx0 + ww * (k + 0.5) / nb, sill + wh / 2, -0.04), "madera_media" if k % 2 else "madera_oscura")
	else:
		var bars: Array = []
		var cols := maxi(int(ww / 0.32), 2)
		var rows := 3
		for k in range(0, cols + 1):
			bars.append(M.xf_box(Vector3(0.035, wh, 0.06), Vector3(wx0 + ww * k / cols, sill + wh / 2, -0.06)))
		for r in range(0, rows + 1):
			bars.append(M.xf_box(Vector3(ww, 0.035, 0.06), Vector3(wcx, sill + wh * r / rows, -0.06)))
		M.multi_boxes(g, bars, [], "madera_negra")
		var xf: Array = []; var cc: Array = []
		for r in 3:
			var sy := sill + 0.06 + r * wh / 3.0
			M.box(g, Vector3(ww - 0.06, 0.02, 0.22), Vector3(wcx, sy - 0.012, -0.2), "madera_media")
			_spines(xf, cc, seed, r * 7 + 3, wx0 + 0.04, wx1 - 0.04, sy, minf(wh / 3.0 - 0.06, 0.3), 0.16, -0.2)
		M.multi_boxes(g, xf, cc)
	occ.append(M.aabb_mm(gx + Vector3(-hw / 2, 0, -depth), gx + Vector3(hw / 2, gh, 0.0)))
	# caballete de libros en la vereda
	if bool(hd.get("stall", false)):
		var sx0 := wcx
		for sxx: float in [-1.0, 1.0]:
			var tx := sx0 + sxx * (ww / 2 - 0.2)
			M.beam_ab(g, Vector3(tx, 0, 0.25), Vector3(tx, 0.82, 0.55), 0.04, 0.04, "madera_media")
			M.beam_ab(g, Vector3(tx, 0, 0.85), Vector3(tx, 0.82, 0.55), 0.04, 0.04, "madera_media")
		var tw := ww - 0.25
		M.box(g, Vector3(tw, 0.03, 0.62), Vector3(sx0, 0.84, 0.55), "madera_media", Vector3(8, 0, 0))
		var xf2: Array = []; var cc2: Array = []
		var bx := sx0 - tw / 2 + 0.05
		var bi := 0
		while bx < sx0 + tw / 2 - 0.1 and bi < 60:
			var bw := M.rr(seed, bi, 31, 0.12, 0.17)
			for row in 2:
				xf2.append(M.xf_box(Vector3(bw - 0.01, M.rr(seed, bi, 32 + row, 0.02, 0.04), 0.22), Vector3(bx + bw / 2, 0.88 + row * 0.0, 0.42 + row * 0.27), Vector3(8, M.rr(seed, bi, 34 + row, -8, 8), 0)))
				cc2.append(_spine(seed, bi * 3 + row))
			bx += bw
			bi += 1
		M.multi_boxes(g, xf2, cc2)
		M.box(g, Vector3(tw + 0.1, 0.012, 0.75), Vector3(sx0, 1.85, 0.5), "lienzo", Vector3(-6, 0, 0))
		occ.append(M.aabb_mm(gx + Vector3(sx0 - tw / 2, 0.8, 0.2), gx + Vector3(sx0 + tw / 2, 0.95, 0.9)))
	# ---- pisos altos
	var y := gh
	var fz := 0.0
	for k in floors:
		var fh: float = fhs[mini(k, 2)]
		fz += j
		# viga de vuelo (bressumer) con ménsulas
		M.box(g, Vector3(hw + 0.02, 0.2, 0.26), Vector3(0, y + 0.06, fz - 0.1), "madera_negra")
		if j > 0.0:
			for b in 3:
				var bxp := -hw / 2 + 0.25 + (hw - 0.5) * b / 2.0
				M.prism(g, Vector3(0.12, 0.34, j + 0.02), Vector3(bxp, y - 0.2, fz - j / 2 - 0.08), "madera_negra", Vector3(-90, 0, 0), 0.0)
		var face := Node3D.new(); face.position = Vector3(0, y, fz); g.add_child(face)
		var mat := "ladrillo_hollin" if brick else ("estuco" if M.rnd(seed, k, 5) < 0.5 else "yeso_sucio")
		M.box(face, Vector3(hw, fh, 0.18), Vector3(0, fh / 2, -0.09), mat)
		var nwin := 2 if hw < 4.2 else 3
		var wins: Array = []
		for wi in nwin:
			var wxc := -hw / 2 + hw * (wi + 0.5) / nwin
			var wwid := minf(0.95, hw / nwin - 0.45)
			var whh := fh * 0.5
			var wy := fh * 0.28
			wins.append([wxc, wwid, wy, whh])
			M.box(face, Vector3(wwid, whh, 0.04), Vector3(wxc, wy + whh / 2, 0.005), "interior_oscuro")
			# marco y cuarterones emplomados
			var lb: Array = []
			lb.append(M.xf_box(Vector3(wwid + 0.08, 0.06, 0.06), Vector3(wxc, wy - 0.03, 0.03)))
			lb.append(M.xf_box(Vector3(wwid + 0.08, 0.06, 0.06), Vector3(wxc, wy + whh + 0.03, 0.03)))
			lb.append(M.xf_box(Vector3(0.05, whh, 0.05), Vector3(wxc - wwid / 2, wy + whh / 2, 0.03)))
			lb.append(M.xf_box(Vector3(0.05, whh, 0.05), Vector3(wxc + wwid / 2, wy + whh / 2, 0.03)))
			lb.append(M.xf_box(Vector3(0.04, whh, 0.04), Vector3(wxc, wy + whh / 2, 0.03)))
			for r in range(1, 4):
				lb.append(M.xf_box(Vector3(wwid, 0.012, 0.03), Vector3(wxc, wy + whh * r / 4.0, 0.02)))
			for c in [-0.25, 0.25]:
				lb.append(M.xf_box(Vector3(0.012, whh, 0.03), Vector3(wxc + c * wwid, wy + whh / 2, 0.02)))
			M.multi_boxes(face, lb, [], "madera_negra" if not brick else "vela")
			if M.rnd(seed, k * 7 + wi, 9) < 0.35:
				# visillo a medio correr
				M.box(face, Vector3(wwid * 0.45, whh * 0.85, 0.01), Vector3(wxc - wwid * 0.25, wy + whh * 0.55, 0.015), "lienzo")
		if not brick:
			# entramado: postes, soleras y riostras en cruz de San Andrés bajo las ventanas
			var tb: Array = []
			var posts: Array = [-hw / 2 + 0.06, hw / 2 - 0.06]
			for wv in wins:
				posts.append(wv[0] - wv[1] / 2 - 0.08)
				posts.append(wv[0] + wv[1] / 2 + 0.08)
			for px in posts:
				tb.append(M.xf_box(Vector3(0.11, fh, 0.05), Vector3(px, fh / 2, 0.01)))
			tb.append(M.xf_box(Vector3(hw, 0.1, 0.05), Vector3(0, fh - 0.05, 0.01)))
			tb.append(M.xf_box(Vector3(hw, 0.08, 0.05), Vector3(0, fh * 0.28 - 0.07, 0.01)))
			M.multi_boxes(face, tb, [], "madera_negra")
			for wv in wins:
				var a0: float = wv[0] - wv[1] / 2
				var a1: float = wv[0] + wv[1] / 2
				var y0b := 0.05
				var y1b: float = wv[2] - 0.12
				if y1b - y0b > 0.2:
					M.beam_ab(face, Vector3(a0, y0b, 0.02), Vector3(a1, y1b, 0.02), 0.07, 0.04, "madera_negra")
					M.beam_ab(face, Vector3(a1, y0b, 0.02), Vector3(a0, y1b, 0.02), 0.07, 0.04, "madera_negra")
		else:
			# impostas de piedra en el ladrillo
			M.box(face, Vector3(hw, 0.08, 0.04), Vector3(0, 0.04, 0.02), "piedra_portland")
		occ.append(M.aabb_mm(gx + Vector3(-hw / 2, y, -depth), gx + Vector3(hw / 2, y + fh, fz)))
		y += fh
	# ---- remate: frontón con alero o cornisa con buhardilla
	var top_z := fz
	if bool(hd.get("gable", true)) and not brick:
		var gh2 := minf(hw * 0.55, 2.4)
		var gz := top_z + j * 0.6
		M.box(g, Vector3(hw + 0.04, 0.16, 0.24), Vector3(0, y + 0.05, gz - 0.1), "madera_negra")
		M.prism(g, Vector3(hw, gh2, 0.16), Vector3(0, y + gh2 / 2 + 0.08, gz - 0.1), "yeso_sucio")
		# ventanuco del frontón
		M.box(g, Vector3(0.5, 0.55, 0.04), Vector3(0, y + 0.55, gz - 0.0), "interior_oscuro")
		M.box(g, Vector3(0.6, 0.05, 0.06), Vector3(0, y + 0.27, gz + 0.01), "madera_negra")
		M.box(g, Vector3(0.6, 0.05, 0.06), Vector3(0, y + 0.85, gz + 0.01), "madera_negra")
		M.box(g, Vector3(0.04, 0.55, 0.05), Vector3(0, y + 0.55, gz + 0.01), "madera_negra")
		M.beam_ab(g, Vector3(0, y + 0.1, gz + 0.01), Vector3(0, y + gh2, gz + 0.01), 0.1, 0.05, "madera_negra")
		# aleros: tejado volado y tablas de borde (vuelan 0,45 m sobre la calle)
		var ov := 0.45
		var half := hw / 2.0 + 0.15
		var ang := atan2(gh2, hw / 2.0)
		var rl := sqrt(half * half + (gh2 + 0.15) * (gh2 + 0.15))
		for sx: float in [-1.0, 1.0]:
			var a := Vector3(sx * half, y + 0.0, gz + ov)
			var b := Vector3(0, y + gh2 + 0.15, gz + ov)
			M.beam_ab(g, a, b, 0.18, 0.05, "madera_negra")
			# faldón del tejado hacia atrás
			var rf := M.box(g, Vector3(rl, 0.08, depth + ov), Vector3(sx * half / 2, y + (gh2 + 0.15) / 2 + 0.02, gz - depth / 2 + ov / 2), "pizarra")
			rf.rotation = Vector3(0, 0, -sx * ang)
		M.box(g, Vector3(0.06, 0.06, depth + ov), Vector3(0, y + gh2 + 0.17, gz - depth / 2 + ov / 2), "madera_negra")
		occ.append(M.aabb_mm(gx + Vector3(-hw / 2, y, -depth), gx + Vector3(hw / 2, y + gh2, gz)))
		y += gh2
	else:
		# cornisa con alero corrido y canaleta, tejado y buhardilla
		var ez := top_z
		M.box(g, Vector3(hw + 0.04, 0.22, 0.5), Vector3(0, y + 0.11, ez + 0.15), "madera_negra" if not brick else "piedra_portland")
		M.cyl(g, 0.06, 0.06, hw, Vector3(0, y + 0.1, ez + 0.45), "hierro", Vector3(0, 0, 90), 10)
		var rr := M.box(g, Vector3(hw, 0.08, 2.4), Vector3(0, y + 0.75, ez - 0.75), "pizarra")
		rr.rotation_degrees = Vector3(38, 0, 0)
		M.box(g, Vector3(0.8, 0.95, 0.7), Vector3(0, y + 0.65, ez - 0.25), "pizarra")
		M.box(g, Vector3(0.55, 0.6, 0.04), Vector3(0, y + 0.62, ez + 0.11), "interior_oscuro")
		M.box(g, Vector3(0.62, 0.05, 0.06), Vector3(0, y + 0.95, ez + 0.12), "vela")
		M.box(g, Vector3(0.04, 0.6, 0.05), Vector3(0, y + 0.62, ez + 0.12), "vela")
		occ.append(M.aabb_mm(gx + Vector3(-hw / 2, y, -depth), gx + Vector3(hw / 2, y + 1.2, ez + 0.4)))
		y += 1.2
	# chimenea
	var cx := M.rr(seed, 3, 3, -hw * 0.3, hw * 0.3)
	M.box(g, Vector3(0.7, 1.4, 0.55), Vector3(cx, y + 0.3, top_z - 1.6), "ladrillo_hollin")
	for k in 2:
		M.cyl(g, 0.07, 0.09, 0.4, Vector3(cx - 0.15 + k * 0.3, y + 1.2, top_z - 1.6), "cobre", Vector3.ZERO, 10)
	# letrero de la media luna con cara (Holywell Street, n.º 36: GDD/london_period §3.8)
	if bool(hd.get("moon", false)):
		var my := gh + 0.95
		var mx := hw / 2 - 0.62
		# placa redonda clavada al revoque del primer piso, con dos grapas de hierro
		var mn := Node3D.new(); mn.position = Vector3(mx, my, j + 0.08); g.add_child(mn)
		M.cyl(mn, 0.42, 0.42, 0.05, Vector3.ZERO, "laton", Vector3(90, 0, 0), 32)
		M.cyl(mn, 0.35, 0.35, 0.056, Vector3(0.15, 0.04, 0), "madera_negra", Vector3(90, 0, 0), 32)
		M.sphere(mn, 0.035, Vector3(-0.2, 0.1, 0.035), "madera_negra")
		M.box(mn, Vector3(0.05, 0.1, 0.03), Vector3(-0.27, -0.02, 0.035), "laton")
		M.box(mn, Vector3(0.1, 0.025, 0.03), Vector3(-0.21, -0.16, 0.035), "madera_negra")
		for sy: float in [-1.0, 1.0]:
			M.box(mn, Vector3(0.06, 0.02, 0.1), Vector3(0, sy * 0.43, -0.03), "hierro")
		occ.append(M.aabb_mm(gx + Vector3(mx - 0.42, my - 0.42, j), gx + Vector3(mx + 0.42, my + 0.42, j + 0.12)))
	return occ

# ======================================================================================
# reflection: el reflejo de Lisle en el vidrio negro de la ventana (lámina del prólogo): figura alta y delgada,
# de anteojos de color, aplanada sobre el plano del vidrio y a escala de reflejo (≈ la mitad). Origen = pie de la
# figura sobre el plano; frente +Z = hacia el cuarto. Extras: s (escala, def 0.5).
static func build_reflection(p: Dictionary) -> Node3D:
	var root := M.root("reflection")
	var s := M.pf(p, "s", 0.5)
	var fig := Node3D.new(); fig.name = "lisle"; root.add_child(fig)
	var spec := {"h": 1.9, "sh": 0.4, "g": 0.115, "coat": "frock", "coat_mat": "tela_media", "arms": {"r": "side", "l": "pocket"}, "hat": "", "pose": "de_pie"}
	MQ._body(fig, spec, "de_pie", 1894)
	# anteojos de color: dos discos y el puente
	var head_y := 1.9 * 0.3 + 1.9 * 0.5 + 1.9 * 0.03 + 1.9 * 0.064 * 0.92
	for sx: float in [-1.0, 1.0]:
		M.cyl(fig, 0.026, 0.026, 0.01, Vector3(sx * 0.038, head_y + 0.02, 0.12), "tinta", Vector3(90, 0, 0), 12)
	M.box(fig, Vector3(0.03, 0.006, 0.008), Vector3(0, head_y + 0.025, 0.125), "tinta")
	fig.scale = Vector3(s, s, s * 0.04)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# trunk: baúl de viaje con flejes (debajo de la cama o al pie). Extras: w, h, d.
static func build_trunk(p: Dictionary) -> Node3D:
	var root := M.root("trunk")
	var w := M.pf(p, "w", 0.8); var h := M.pf(p, "h", 0.42); var d := M.pf(p, "d", 0.48)
	M.box(root, Vector3(w, h * 0.75, d), Vector3(0, h * 0.375, 0), "cuero")
	M.box(root, Vector3(w + 0.01, h * 0.25, d + 0.01), Vector3(0, h * 0.75 + h * 0.125, 0), "cuero")
	for k in 3:
		var x := -w / 2 + 0.1 + (w - 0.2) * k / 2.0
		M.box(root, Vector3(0.03, h + 0.012, d + 0.014), Vector3(x, h / 2, 0), "madera_negra")
	M.box(root, Vector3(0.07, 0.06, 0.01), Vector3(0, h * 0.72, d / 2 + 0.008), "laton")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# ======================================================================================
# Versiones de props de small.gd con oclusor explícito. En headless (tests) el renderer dummy no guarda las
# transformaciones de un MultiMesh y Materials.aabb_of devuelve un cubo de 1 m para los props hechos con
# MultiMesh (regla, monedas, resma, libro abierto, plano): un cubo así taparía todo el escritorio en los tests
# de oclusión y recorte. Con ventana el cálculo es correcto; acá se fija la caja a mano en ambos casos.
const SM = preload("res://world/props/small.gd")

# desk_ruler: small.ruler (len) con oclusor de su tamaño real.
static func build_desk_ruler(p: Dictionary) -> Node3D:
	var n := SM.build_ruler(p)
	var L := M.pf(p, "len", 0.3)
	n.set_meta("occ", [M.aabb_mm(Vector3(-L / 2, 0, -0.016), Vector3(L / 2, 0.0068, 0.016))])
	return n

# desk_coins: small.coins (n) con oclusor de su tamaño real.
static func build_desk_coins(p: Dictionary) -> Node3D:
	var n := SM.build_coins(p)
	var k := clampi(M.pi_(p, "n", 6), 1, 40)
	n.set_meta("occ", [M.aabb_mm(Vector3(-0.066, 0, -0.056), Vector3(0.066, 0.004 + 0.0022 * (k / 2), 0.056))])
	return n

# paper_pile: small.paper_stack (n, w, h) con oclusor de su tamaño real.
static func build_paper_pile(p: Dictionary) -> Node3D:
	var n := SM.build_paper_stack(p)
	var k := clampi(M.pi_(p, "n", 12), 1, 200)
	var w := M.pf(p, "w", 0.21); var h := M.pf(p, "h", 0.3)
	n.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.01, 0, -h / 2 - 0.01), Vector3(w / 2 + 0.01, 0.0025 * k, h / 2 + 0.01))])
	return n

# ledger_open: small.open_ledger_book (w, h) con oclusor de su tamaño real.
static func build_ledger_open(p: Dictionary) -> Node3D:
	var n := SM.build_open_ledger_book(p)
	var w := M.pf(p, "w", 0.48); var h := M.pf(p, "h", 0.34)
	n.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.01, 0, -h / 2 - 0.01), Vector3(w / 2 + 0.01, 0.03, h / 2 + 0.01))])
	return n

# wall_map: small.map_board (w, h, y) con oclusor de su tamaño real (tablero contra la pared).
static func build_wall_map(p: Dictionary) -> Node3D:
	var n := SM.build_map_board(p)
	var w := M.pf(p, "w", 0.9); var h := M.pf(p, "h", 0.65); var y0 := M.pf(p, "y", 0.0)
	n.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, y0, 0), Vector3(w / 2, y0 + h, 0.03))])
	return n

# ======================================================================================
# GDD_v3 §4.3, §6.1, §6.4 (REACCIONES-PIEZA): la pieza v3. La ventana de la buhardilla deja de ser parte del muro
# (el vano del ático es "void") y se arma con props propios para que las intrusiones la cambien con `move`:
# sash_frame (marco, hoja alta, repisa y alféizar), sash_lower (hoja baja: `hoja_ventana`), sash_lock (`traba`),
# curtain (`cortina`, con vaivén de 4 s cuando la variante la gira hacia adentro), desk_drawer (`cajon`, se abre en
# «registrada»), dossier_folder (`expediente`, reemplaza al libro de conclusiones), soot_print (hollín en el alféizar
# con la suela chica), lock_scratches (rayones nuevos alrededor del ojo de la cerradura).

# sash_frame: guillotina sin la hoja baja (la hoja baja es sash_lower, aparte). Origen = centro inferior del marco, en el
# plano medio del muro; frente +Z = interior. Extras: w, h, depth, panes (de la hoja alta), paint, sill_in (repisa).
static func build_sash_frame(p: Dictionary) -> Node3D:
	var root := M.root("sash_frame")
	var w := M.pf(p, "w", 1.0); var h := M.pf(p, "h", 1.25)
	var dep := M.pf(p, "depth", 0.128)
	var paint := M.ps(p, "paint", "vela")
	var fr := 0.06
	M.box(root, Vector3(w, fr, dep), Vector3(0, h - fr / 2, 0), paint)
	M.box(root, Vector3(w, fr * 0.8, dep), Vector3(0, fr * 0.4, 0), paint)
	M.box(root, Vector3(fr, h, dep), Vector3(-w / 2 + fr / 2, h / 2, 0), paint)
	M.box(root, Vector3(fr, h, dep), Vector3(w / 2 - fr / 2, h / 2, 0), paint)
	var iw := w - 2 * fr
	var ih := h - fr - fr * 0.8
	var sh := ih / 2.0 + 0.02
	A._sash(root, iw, sh, Vector3(0, fr * 0.8 + ih - sh / 2.0, -0.025), M.pi_(p, "panes", 4), paint, false)
	# guías de la hoja baja (junquillos) y el gancho de la traba en el travesaño de la hoja alta
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.012, ih, 0.012), Vector3(sx * (iw / 2 - 0.006), fr * 0.8 + ih / 2, 0.05), paint)
	M.box(root, Vector3(0.05, 0.012, 0.02), Vector3(0, fr * 0.8 + ih - sh + 0.051, -0.025), "laton")
	# alféizar de piedra afuera y repisa de madera adentro
	M.box(root, Vector3(w + 0.14, 0.06, 0.16), Vector3(0, -0.03, -dep / 2 - 0.06), "piedra_portland")
	if M.pb(p, "sill_in", true):
		M.box(root, Vector3(w + 0.12, 0.03, 0.12), Vector3(0, -0.015, dep / 2 + 0.056), "madera_media")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, h - fr, -dep / 2), Vector3(w / 2, h, dep / 2)), M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(w / 2, fr * 0.8, dep / 2)),
		M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(-w / 2 + fr, h, dep / 2)), M.aabb_mm(Vector3(w / 2 - fr, 0, -dep / 2), Vector3(w / 2, h, dep / 2))])
	return root

# sash_lower: la hoja baja de la guillotina, suelta. Origen = centro del canto inferior de la hoja; frente +Z. Extras: w
# (ancho interior del marco), h (alto de la hoja), panes, paint. Sólo ocluye su marco (por el vidrio se ve la calle).
static func build_sash_lower(p: Dictionary) -> Node3D:
	var root := M.root("sash_lower")
	var w := M.pf(p, "w", 0.88); var h := M.pf(p, "h", 0.591)
	A._sash(root, w, h, Vector3(0, h / 2, 0), M.pi_(p, "panes", 4), M.ps(p, "paint", "vela"), true)
	var s := 0.045
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -0.02), Vector3(w / 2, s * 1.4, 0.02)), M.aabb_mm(Vector3(-w / 2, h - s, -0.02), Vector3(w / 2, h, 0.02)),
		M.aabb_mm(Vector3(-w / 2, 0, -0.02), Vector3(-w / 2 + s, h, 0.02)), M.aabb_mm(Vector3(w / 2 - s, 0, -0.02), Vector3(w / 2, h, 0.02))])
	return root

# sash_lock: traba de guillotina (pestillo de latón) sobre el travesaño alto de la hoja baja. Origen = base del pestillo;
# la palanca apunta a −X cerrada; girada (rot de la variante) queda levantada. Extras: s (escala).
static func build_sash_lock(p: Dictionary) -> Node3D:
	var root := M.root("sash_lock")
	var s := M.pf(p, "s", 1.0)
	M.box(root, Vector3(0.05 * s, 0.006, 0.026 * s), Vector3(0, 0.003, 0), "laton")
	M.cyl(root, 0.007 * s, 0.009 * s, 0.012, Vector3(0, 0.012, 0), "laton", Vector3.ZERO, 10)
	var lev := Node3D.new(); lev.name = "lever"; lev.position = Vector3(0, 0.018, 0); root.add_child(lev)
	M.box(lev, Vector3(0.045 * s, 0.006, 0.012 * s), Vector3(-0.022 * s, 0, 0), "laton")
	M.sphere(lev, 0.007 * s, Vector3(-0.046 * s, 0.002, 0), "laton")
	root.set_meta("occ", [])
	return root

# Vaivén de la cortina al entrar con la ventana abierta (GDD_v3 §4.3: «la cortina se mueve 4 s»). Sólo si la cortina
# quedó girada hacia adentro (move de la variante «techos»): entonces la tela además se embolsa (los tramos de abajo se
# abren un poco más, como una tela con viento) y oscila 4 s hasta quedarse quieta. Determinista.
# Verificador v3 (decisión 6: «un poco de viento… cambio sutil»): embolsado 4° por tramo y vaivén de 2,5–4,5° por tramo
# (antes 7° y 6–12°: la tela llegaba casi a la horizontal y se leía como una tabla volando).
class CurtainSway extends Node3D:
	var t := 0.0
	var dur := 4.0
	var segs: Array = []
	var base: Array = []
	func _ready() -> void:
		var par := get_parent() as Node3D
		var tilted := par != null and absf(par.transform.basis.get_euler().x) > deg_to_rad(5.0)
		var n: Node = par.get_node_or_null("cloth") if par != null else null
		while n != null:
			segs.append(n)
			n = n.get_node_or_null("next")
		if segs.is_empty() or not tilted:
			set_process(false)
			return
		# embolsado: cada tramo de abajo, un poco más hacia el cuarto (el giro de la variante es hacia −X)
		var sgn := signf(par.transform.basis.get_euler().x)
		for k in segs.size():
			var s: Node3D = segs[k]
			if k > 0:
				s.rotation.x = sgn * deg_to_rad(4.0 * k)
			base.append(s.rotation.x)
		set_process(true)
	func _process(dt: float) -> void:
		t += dt
		var k := maxf(0.0, 1.0 - t / dur)
		for i in segs.size():
			var a := deg_to_rad(2.5 + 1.0 * i) * k * sin(TAU * 0.7 * t + 0.5 * i) + deg_to_rad(0.8) * k * sin(TAU * 1.9 * t + 0.6 + i)
			(segs[i] as Node3D).rotation.x = float(base[i]) + a
		if t >= dur:
			set_process(false)

# curtain: cortina de tela liviana colgada de una varilla, recogida a un costado. Origen = punto de la varilla del que
# cuelga (arriba); cae hacia −Y; frente +Z. Extras: w (ancho), h (caída), mat, n (tramos), pleats (pliegues por tramo).
# La tela es una cadena de tramos ("cloth" → "next" → …), cada uno con su pivote arriba, plegada en acordeón.
static func build_curtain(p: Dictionary) -> Node3D:
	var root := M.root("curtain")
	var w := M.pf(p, "w", 0.4); var h := M.pf(p, "h", 1.32)
	var mat := M.ps(p, "mat", "tela_media")
	var n := maxi(1, M.pi_(p, "n", 3))
	var pl := maxi(2, M.pi_(p, "pleats", 6))
	M.rod_ab(root, 0.008, Vector3(-w / 2 - 0.08, 0.03, 0), Vector3(w / 2 + 0.08, 0.03, 0), "laton")
	for sx: float in [-1.0, 1.0]:
		M.sphere(root, 0.014, Vector3(sx * (w / 2 + 0.09), 0.03, 0), "laton")
	var parent := root
	var sh := h / float(n)
	for s in n:
		var seg := Node3D.new(); seg.name = "cloth" if s == 0 else "next"
		seg.position = Vector3(0, 0, 0) if s == 0 else Vector3(0, -sh, 0)
		parent.add_child(seg)
		# acordeón: paños angostos girados alternadamente, como una tela fruncida
		var pw := w / float(pl)
		for k in pl:
			var x := -w / 2 + pw * (k + 0.5)
			var ang := 28.0 if k % 2 == 0 else -28.0
			M.box(seg, Vector3(pw / cos(deg_to_rad(28.0)) + 0.004, sh + 0.004, 0.005), Vector3(x, -sh / 2, 0.0), mat, Vector3(0, ang, 0))
		if s == n - 1:
			M.box(seg, Vector3(w + 0.01, 0.025, 0.03), Vector3(0, -sh + 0.012, 0.0), mat)
		parent = seg
	# argollas sobre la varilla
	for k in 5:
		M.torus(root, 0.006, 0.012, Vector3(-w / 2 + w * k / 4.0, 0.03, 0), "laton", Vector3(0, 0, 90))
	root.add_child(CurtainSway.new())
	root.set_meta("occ", [])
	return root

# desk_drawer: el cajón del centro del escritorio, como pieza aparte (se abre 12 cm en «registrada»). Origen = centro de
# la cara del frente; frente +Z; la caja se mete en el escritorio hacia −Z. Adentro, la prueba de imprenta doblada.
static func build_desk_drawer(p: Dictionary) -> Node3D:
	var root := M.root("desk_drawer")
	var w := M.pf(p, "w", 0.52); var h := M.pf(p, "h", 0.07); var d := M.pf(p, "d", 0.4)
	M.box(root, Vector3(w, h, 0.014), Vector3(0, 0, -0.007), "madera_media")
	M.torus(root, 0.01, 0.019, Vector3(0, 0.004, 0.012), "laton", Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.012, h - 0.012, d), Vector3(sx * (w / 2 - 0.02), -0.006, -d / 2 - 0.014), "madera_oscura")
	M.box(root, Vector3(w - 0.04, 0.008, d), Vector3(0, -h / 2 + 0.004, -d / 2 - 0.014), "madera_oscura")
	M.box(root, Vector3(w - 0.04, h - 0.012, 0.012), Vector3(0, -0.006, -d - 0.008), "madera_oscura")
	# la prueba de imprenta doblada en cuatro y un par de papeles
	M.box(root, Vector3(0.16, 0.006, 0.12), Vector3(-0.08, -h / 2 + 0.012, -0.08), "papel_viejo", Vector3(0, 8, 0))
	M.box(root, Vector3(0.2, 0.003, 0.14), Vector3(0.1, -h / 2 + 0.01, -0.12), "papel", Vector3(0, -5, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, -h / 2, -0.014), Vector3(w / 2, h / 2, 0.0))])
	return root

# dossier_folder: el Expediente Holmes. Carpeta de cartón cerrada, atada con cinta roja, «Holmes» a pluma en la tapa;
# asoman hojas. Origen = centro de la base; frente +Z (lomo a −X). Extras: w, h, t.
static func build_dossier_folder(p: Dictionary) -> Node3D:
	var root := M.root("dossier_folder")
	var w := M.pf(p, "w", 0.25); var h := M.pf(p, "h", 0.33); var t := M.pf(p, "t", 0.022)
	M.box(root, Vector3(w, 0.003, h), Vector3(0, 0.0015, 0), "mimbre")
	M.box(root, Vector3(w - 0.012, t - 0.006, h - 0.012), Vector3(0.004, t / 2, 0), "papel_viejo")
	# hojas que asoman por el canto
	for k in 3:
		M.box(root, Vector3(0.006, 0.0025, 0.08 + 0.03 * k), Vector3(w / 2 + 0.002, 0.006 + 0.004 * k, -0.06 + 0.05 * k), "papel")
	M.box(root, Vector3(w, 0.003, h), Vector3(0, t - 0.0015, 0), "mimbre")
	M.box(root, Vector3(0.014, t, h), Vector3(-w / 2 + 0.007, t / 2, 0), "mimbre")
	# cinta roja: un tramo por la tapa y un moño
	M.box(root, Vector3(w + 0.004, t + 0.004, 0.012), Vector3(0, t / 2, 0.03), "pintura_roja")
	M.box(root, Vector3(0.05, 0.003, 0.012), Vector3(0.05, t + 0.002, 0.03), "pintura_roja", Vector3(0, 35, 0))
	M.box(root, Vector3(0.05, 0.003, 0.012), Vector3(0.05, t + 0.002, 0.03), "pintura_roja", Vector3(0, -35, 0))
	# rótulo de papel con «Holmes» a pluma (playtest v3: grande, que se lea desde el escritorio y no se confunda con una hoja)
	M.box(root, Vector3(0.18, 0.001, 0.07), Vector3(0.0, t + 0.0012, -0.075), "papel")
	M.label3d(root, "Holmes", Vector3(0.0, t + 0.0022, -0.075), 0.00085, 48, Color("1b1712"), "manuscrito").rotation_degrees = Vector3(-90, 0, 0)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -h / 2), Vector3(w / 2 + 0.004, t + 0.004, h / 2))])
	return root

# soot_print: hollín de los techos sobre la repisa del alféizar, con la marca de una suela chica (de muchacho). Origen =
# centro, apoyado; frente +Z (la punta de la suela mira al cuarto). Extras: s, seed.
static func build_soot_print(p: Dictionary) -> Node3D:
	var root := M.root("soot_print")
	var s := M.pf(p, "s", 0.62)
	var seed := M.seed_of(p, "sp")
	for i in 7:
		M.box(root, Vector3(M.rr(seed, i, 0, 0.03, 0.08), 0.0012, M.rr(seed, i, 1, 0.012, 0.03)), Vector3(M.rr(seed, i, 2, -0.12, 0.12), 0.0006, M.rr(seed, i, 3, -0.035, 0.035)), "carbon", Vector3(0, M.rr(seed, i, 4, -40, 40), 0))
	# suela chica: punta redonda y taco, sin tachas (botín de muchacho)
	M.box(root, Vector3(0.08 * s, 0.0016, 0.1 * s), Vector3(0.02, 0.001, 0.02 * s), "carbon")
	M.cyl(root, 0.04 * s, 0.04 * s, 0.0016, Vector3(0.02, 0.001, 0.075 * s), "carbon", Vector3.ZERO, 12)
	M.box(root, Vector3(0.065 * s, 0.0016, 0.05 * s), Vector3(0.02, 0.001, -0.06 * s), "carbon")
	root.set_meta("occ", [])
	return root

# lock_scratches: rayones nuevos, claros, alrededor del ojo de la cerradura (ganzúa). Se apoya sobre la bocallave de la
# puerta: plano XY, frente +Z. Extras: n, seed.
static func build_lock_scratches(p: Dictionary) -> Node3D:
	var root := M.root("lock_scratches")
	var seed := M.seed_of(p, "ls")
	var n := M.pi_(p, "n", 9)
	for i in n:
		var a := M.rr(seed, i, 0, 0.0, 360.0)
		var r := M.rr(seed, i, 1, 0.006, 0.02)
		M.box(root, Vector3(M.rr(seed, i, 2, 0.008, 0.02), 0.0012, 0.0006), Vector3(cos(deg_to_rad(a)) * r * 0.6, sin(deg_to_rad(a)) * r, 0.0003), "vela", Vector3(0, 0, a + M.rr(seed, i, 3, -25, 25)))
	# el ojo de la cerradura
	M.box(root, Vector3(0.006, 0.014, 0.0008), Vector3(0, -0.004, 0.0002), "carbon")
	M.cyl(root, 0.0045, 0.0045, 0.0008, Vector3(0, 0.004, 0.0002), "carbon", Vector3(90, 0, 0), 10)
	root.set_meta("occ", [])
	return root

# ash_flakes: ceniza negra y escamosa de cheroot sobre el cuero del escritorio (registro M1, GDD_v3 §4.3), con la colilla.
# Origen = centro, apoyado; frente +Z. Extras: r (radio de dispersión), seed.
static func build_ash_flakes(p: Dictionary) -> Node3D:
	var root := M.root("ash_flakes")
	var r := M.pf(p, "r", 0.035)
	var seed := M.seed_of(p, "af")
	# un montoncito chato y escamas alrededor
	M.sphere(root, 0.014, Vector3(0.0, 0.002, 0.0), "ceniza", Vector3(1.4, 0.3, 1.0), 10)
	for i in 11:
		var a := M.rr(seed, i, 0, 0.0, TAU)
		var d := M.rr(seed, i, 1, 0.006, r)
		var s := M.rr(seed, i, 2, 0.004, 0.009)
		M.box(root, Vector3(s, 0.0015, s * M.rr(seed, i, 3, 0.5, 1.0)), Vector3(cos(a) * d, 0.001, sin(a) * d), "carbon" if i % 3 == 0 else "ceniza", Vector3(0, M.rr(seed, i, 4, 0, 90), 0))
	# la colilla del cheroot (tabaco oscuro, la punta quemada)
	var c := Node3D.new(); c.position = Vector3(0.03, 0.006, 0.012); c.rotation_degrees = Vector3(0, 28, 90); root.add_child(c)
	M.cyl(c, 0.0055, 0.0065, 0.042, Vector3.ZERO, "cuero", Vector3.ZERO, 10)
	M.cyl(c, 0.0056, 0.0056, 0.006, Vector3(0, 0.024, 0), "ceniza", Vector3.ZERO, 10)
	root.set_meta("occ", [])
	return root
