# world/props/small.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2.
# Objetos chicos de escritorio y mano. Origen = centro de la base (apoyado en y=0); frente +Z.
extends RefCounted

const M = preload("res://world/materials.gd")
const F = preload("res://world/props/furniture.gd")

static func _occ_all(n: Node3D) -> Node3D:
	return M.set_occ(n)

# ======================================================================================
# book(w,h,t): libro cerrado. Por defecto acostado (huella w x h, alto t). Extras: standing, mat (tapa), seed.
static func build_book(p: Dictionary) -> Node3D:
	var root := M.root("book")
	var w := M.pf(p, "w", 0.15); var h := M.pf(p, "h", 0.22); var t := M.pf(p, "t", 0.035)
	var mat := M.ps(p, "mat", "cuero")
	var g := Node3D.new(); root.add_child(g)
	if M.pb(p, "standing", false):
		g.basis = Basis(Vector3.UP, -PI / 2) * Basis(Vector3.RIGHT, -PI / 2)
		g.position = Vector3(t / 2, h / 2, 0)
	var ct := 0.004
	M.box(g, Vector3(w, ct, h), Vector3(0, ct / 2, 0), mat)
	M.box(g, Vector3(w, ct, h), Vector3(0, t - ct / 2, 0), mat)
	M.box(g, Vector3(w - 0.008, t - 2 * ct, h - 0.008), Vector3(0.002, t / 2, 0), "papel")
	M.box(g, Vector3(0.008, t, h), Vector3(-w / 2 + 0.004, t / 2, 0), mat)
	M.box(g, Vector3(0.0095, t * 0.12, h * 0.98), Vector3(-w / 2 + 0.003, t * 0.3, 0), "laton")
	M.box(g, Vector3(0.0095, t * 0.12, h * 0.98), Vector3(-w / 2 + 0.003, t * 0.7, 0), "laton")
	return _occ_all(root)

# ======================================================================================
# book_pile(n): pila de n libros de tamaños y lomos variados, levemente girados.
static func build_book_pile(p: Dictionary) -> Node3D:
	var root := M.root("book_pile")
	var n := clampi(M.pi_(p, "n", 5), 1, 20)
	var seed := M.seed_of(p, "pile")
	var y := 0.0
	for i in n:
		var w := M.rr(seed, i, 0, 0.14, 0.24)
		var h := M.rr(seed, i, 1, 0.2, 0.3)
		var t := M.rr(seed, i, 2, 0.025, 0.06)
		var b := build_book({"w": w, "h": h, "t": t})
		var col := F._spine(seed, i)
		for mi in b.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).material_override == M.mat("cuero"):
				(mi as MeshInstance3D).material_override = M.mat_color(col)
		b.position = Vector3((M.rnd(seed, i, 3) - 0.5) * 0.03, y, (M.rnd(seed, i, 4) - 0.5) * 0.03)
		b.rotation_degrees = Vector3(0, (M.rnd(seed, i, 5) - 0.5) * 30, 0)
		root.add_child(b)
		y += t
	return _occ_all(root)

# ======================================================================================
# tome_set(n): juego de n tomos iguales encuadernados en piel, en pie entre sujetalibros; números en los lomos.
# Extras: numbers (def true), mat, h, t, missing (índices 0-based que faltan → hueco).
static func build_tome_set(p: Dictionary) -> Node3D:
	var root := M.root("tome_set")
	var n := clampi(M.pi_(p, "n", 5), 1, 20)
	var mat := M.ps(p, "mat", "cuero")
	var h := M.pf(p, "h", 0.26); var t := M.pf(p, "t", 0.055); var d := M.pf(p, "d", 0.19)
	var missing: Array = p.get("missing", [])
	var x0 := -n * t / 2
	var romans := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
	for i in n:
		if missing.has(i) or missing.has(float(i)): continue
		var cx := x0 + t * (i + 0.5)
		M.box(root, Vector3(t - 0.004, h, d), Vector3(cx, h / 2, 0), mat)
		M.box(root, Vector3(t - 0.012, h - 0.012, d - 0.01), Vector3(cx, h / 2, -0.006), "papel")
		for yy: float in [0.06, 0.2, 0.8, 0.92]:
			M.box(root, Vector3(t - 0.002, 0.006, 0.004), Vector3(cx, h * yy, d / 2 + 0.001), "laton")
		M.box(root, Vector3(t - 0.012, 0.05, 0.003), Vector3(cx, h * 0.72, d / 2 + 0.001), "madera_negra")
		if M.pb(p, "numbers", true):
			M.label3d(root, romans[i], Vector3(cx, h * 0.5, d / 2 + 0.003), 0.00055, 48, Color("a08040"))
	for sx: float in [-1.0, 1.0]:
		var bx := sx * (n * t / 2 + 0.012)
		M.box(root, Vector3(0.018, 0.18, 0.14), Vector3(bx, 0.09, 0), "bronce")
		M.box(root, Vector3(0.1, 0.008, 0.14), Vector3(bx + sx * 0.04, 0.004, 0), "bronce")
	return _occ_all(root)

# ======================================================================================
# paper_stack(n): pila de n hojas (resma) apenas desalineadas. Extras: w, h, seed.
static func build_paper_stack(p: Dictionary) -> Node3D:
	var root := M.root("paper_stack")
	var n := clampi(M.pi_(p, "n", 12), 1, 200)
	var w := M.pf(p, "w", 0.21); var h := M.pf(p, "h", 0.3)
	var seed := M.seed_of(p, "paper")
	var xf: Array = []; var cc: Array = []
	for i in n:
		var th := 0.0025
		xf.append(M.xf_box(Vector3(w, th, h), Vector3((M.rnd(seed, i, 0) - 0.5) * 0.012, th * (i + 0.5), (M.rnd(seed, i, 1) - 0.5) * 0.012), Vector3(0, (M.rnd(seed, i, 2) - 0.5) * 4, 0)))
		var f := 0.9 + 0.1 * M.rnd(seed, i, 3)
		cc.append(M.color("papel") * Color(f, f, f * 0.97))
	M.multi_boxes(root, xf, cc)
	return _occ_all(root)

# ======================================================================================
# letter: carta abierta con pliegues (tres paneles) y renglones manuscritos.
static func build_letter(p: Dictionary) -> Node3D:
	var root := M.root("letter")
	var w := M.pf(p, "w", 0.2); var h := M.pf(p, "h", 0.26)
	var ph := h / 3.0
	for k in 3:
		var z := -h / 2 + ph * (k + 0.5)
		var tilt := 0.0 if k == 1 else (6.0 if k == 0 else -6.0)
		var y := 0.006 if k != 1 else 0.002
		M.box(root, Vector3(w, 0.002, ph), Vector3(0, y, z), "papel", Vector3(tilt, 0, 0))
		for l in 4:
			var lw := w * (0.75 if l < 3 else 0.45)
			M.box(root, Vector3(lw, 0.0006, 0.004), Vector3(-w * 0.05 - (w * 0.15 if l == 3 else 0.0), y + 0.0015, z - ph * 0.32 + l * ph * 0.2), "tinta", Vector3(tilt, 0, 0))
	return _occ_all(root)

# ======================================================================================
# envelope: sobre con solapa y lacre.
static func build_envelope(p: Dictionary) -> Node3D:
	var root := M.root("envelope")
	var w := M.pf(p, "w", 0.16); var h := M.pf(p, "h", 0.1)
	M.box(root, Vector3(w, 0.004, h), Vector3(0, 0.002, 0), "papel_viejo")
	M.prism(root, Vector3(w, h * 0.55, 0.002), Vector3(0, 0.0045, -h / 2 + h * 0.275), "papel", Vector3(-90, 0, 0))
	M.cyl(root, 0.012, 0.012, 0.004, Vector3(0, 0.006, -h * 0.0), "pintura_roja", Vector3.ZERO, 10)
	M.box(root, Vector3(w * 0.5, 0.0006, 0.004), Vector3(0.01, 0.0045, h * 0.25), "tinta")
	M.box(root, Vector3(w * 0.35, 0.0006, 0.004), Vector3(0.02, 0.0045, h * 0.35), "tinta")
	M.box(root, Vector3(0.022, 0.0008, 0.026), Vector3(w / 2 - 0.02, 0.0045, -h / 2 + 0.02), "pintura_roja")
	return _occ_all(root)

# ======================================================================================
# basket_strips: cesto de mimbre con tiras de papel recortado asomando. Extras: n (tiras), seed.
static func build_basket_strips(p: Dictionary) -> Node3D:
	var root := M.root("basket_strips")
	var r := M.pf(p, "r", 0.16); var h := M.pf(p, "h", 0.32)
	var seed := M.seed_of(p, "basket")
	M.cyl(root, r, r * 0.8, h, Vector3(0, h / 2, 0), "mimbre", Vector3.ZERO, 20)
	for k in 6:
		M.torus(root, r * (0.8 + 0.2 * (k + 0.5) / 6.0) - 0.006, r * (0.8 + 0.2 * (k + 0.5) / 6.0) + 0.004, Vector3(0, h * (k + 0.5) / 6.0, 0), "madera_media", Vector3.ZERO, Vector3(1, 0.5, 1))
	M.torus(root, r - 0.012, r + 0.012, Vector3(0, h, 0), "madera_media")
	M.cyl(root, r - 0.01, r - 0.01, 0.01, Vector3(0, h - 0.06, 0), "papel_viejo", Vector3.ZERO, 16)
	var n := M.pi_(p, "n", 22)
	var xf: Array = []; var cc: Array = []
	for i in n:
		var a := M.rnd(seed, i, 0) * TAU
		var rr := M.rnd(seed, i, 1) * r * 0.7
		var len := M.rr(seed, i, 2, 0.1, 0.24)
		var tilt := Vector3(M.rr(seed, i, 3, -40, 40), M.rnd(seed, i, 4) * 180, M.rr(seed, i, 5, -40, 40))
		xf.append(M.xf_box(Vector3(0.018, len, 0.0015), Vector3(cos(a) * rr, h - 0.04 + len * 0.3, sin(a) * rr), tilt))
		var f := 0.88 + 0.12 * M.rnd(seed, i, 6)
		cc.append(M.color("papel") * Color(f, f, f))
	M.multi_boxes(root, xf, cc)
	return _occ_all(root)

# ======================================================================================
# ash_pile: montoncito de ceniza con colilla de cheroot.
static func build_ash_pile(p: Dictionary) -> Node3D:
	var root := M.root("ash_pile")
	var s := M.pf(p, "size", 1.0)
	M.sphere(root, 0.035 * s, Vector3(0, 0.004, 0), "ceniza", Vector3(1.3, 0.25, 1.0))
	M.sphere(root, 0.02 * s, Vector3(0.03 * s, 0.003, 0.015 * s), "ceniza", Vector3(1.0, 0.25, 0.8))
	M.cyl(root, 0.006, 0.007, 0.05, Vector3(-0.02 * s, 0.006, 0.0), "madera_media", Vector3(0, 30, 90), 8)
	M.cyl(root, 0.0065, 0.0065, 0.008, Vector3(-0.043 * s, 0.006, -0.013), "ceniza", Vector3(0, 30, 90), 8)
	return _occ_all(root)

# ======================================================================================
# scissors: tijera de cortar papel, cerrada a medias.
static func build_scissors(p: Dictionary) -> Node3D:
	var root := M.root("scissors")
	var open := M.pf(p, "open", 14.0)
	for s: float in [-1.0, 1.0]:
		var g := Node3D.new(); g.rotation_degrees = Vector3(0, s * open / 2, 0); root.add_child(g)
		M.prism(g, Vector3(0.012, 0.13, 0.002), Vector3(0, 0.004 + (0.001 if s > 0 else 0.0), -0.065), "hierro", Vector3(-90, 0, 0), 0.5)
		M.box(g, Vector3(0.008, 0.003, 0.05), Vector3(s * 0.006, 0.004, 0.025), "hierro")
		M.torus(g, 0.012, 0.018, Vector3(s * 0.015, 0.004, 0.06), "hierro", Vector3.ZERO, Vector3(1, 1, 1.4))
	M.cyl(root, 0.005, 0.005, 0.008, Vector3(0, 0.005, 0), "laton", Vector3.ZERO, 8)
	return _occ_all(root)

# ======================================================================================
# ruler: regla de boj con canto de latón y marcas.
static func build_ruler(p: Dictionary) -> Node3D:
	var root := M.root("ruler")
	var L := M.pf(p, "len", 0.3)
	M.box(root, Vector3(L, 0.006, 0.03), Vector3(0, 0.003, 0), "madera_clara")
	M.box(root, Vector3(L, 0.0065, 0.003), Vector3(0, 0.003, 0.0145), "laton")
	var xf: Array = []
	var n := int(L * 100)
	for i in n + 1:
		var lm := 0.012 if i % 10 == 0 else (0.008 if i % 5 == 0 else 0.004)
		xf.append(M.xf_box(Vector3(0.0006, 0.0005, lm), Vector3(-L / 2 + L * i / n, 0.0062, 0.013 - lm / 2)))
	M.multi_boxes(root, xf, [], "tinta")
	return _occ_all(root)

# ======================================================================================
# lens: lupa de mango con aro de latón.
static func build_lens(p: Dictionary) -> Node3D:
	var root := M.root("lens")
	var r := M.pf(p, "r", 0.045)
	M.torus(root, r, r + 0.007, Vector3(0, 0.008, 0), "laton")
	M.cyl(root, r, r, 0.004, Vector3(0, 0.008, 0), "vidrio", Vector3.ZERO, 24)
	M.cyl(root, 0.006, 0.006, 0.02, Vector3(0, 0.008, r + 0.015), "laton", Vector3(90, 0, 0), 8)
	M.cyl(root, 0.009, 0.011, 0.1, Vector3(0, 0.01, r + 0.075), "madera_negra", Vector3(90, 0, 0), 10)
	return _occ_all(root)

# ======================================================================================
# stamp: sello de goma con mango torneado + tampón en lata.
static func build_stamp(p: Dictionary) -> Node3D:
	var root := M.root("stamp")
	var dry := M.pb(p, "dry", false)
	M.box(root, Vector3(0.07, 0.015, 0.04), Vector3(0, 0.0075, 0), "madera_media")
	M.box(root, Vector3(0.066, 0.006, 0.036), Vector3(0, 0.003, 0), "tinta")
	M.cyl(root, 0.008, 0.012, 0.06, Vector3(0, 0.045, 0), "madera_oscura", Vector3.ZERO, 10)
	M.sphere(root, 0.02, Vector3(0, 0.085, 0), "madera_oscura", Vector3(1, 0.9, 1))
	var pad := Node3D.new(); pad.position = Vector3(0.1, 0, 0.0); root.add_child(pad)
	M.box(pad, Vector3(0.1, 0.014, 0.065), Vector3(0, 0.007, 0), "hierro")
	M.box(pad, Vector3(0.086, 0.002, 0.052), Vector3(0, 0.0145, 0), "ceniza" if dry else "tinta")
	return _occ_all(root)

# ======================================================================================
# ink_pot: tintero cuadrado de vidrio con tapa de latón y portaplumas al lado.
static func build_ink_pot(p: Dictionary) -> Node3D:
	var root := M.root("ink_pot")
	M.box(root, Vector3(0.06, 0.05, 0.06), Vector3(0, 0.025, 0), "vidrio")
	M.box(root, Vector3(0.045, 0.035, 0.045), Vector3(0, 0.0185, 0), "tinta")
	M.cyl(root, 0.014, 0.016, 0.018, Vector3(0, 0.058, 0), "laton", Vector3.ZERO, 12)
	M.cyl(root, 0.004, 0.004, 0.16, Vector3(0.06, 0.006, 0.02), "madera_negra", Vector3(0, 20, 90), 8)
	M.cyl(root, 0.0, 0.004, 0.02, Vector3(-0.015, 0.006, 0.05), "laton", Vector3(0, 20, 90), 6)
	return _occ_all(root)

# ======================================================================================
# clock_mantel: reloj de repisa con caja de arco, esfera y agujas. Extras: hour (0..12, def 10.1).
static func build_clock_mantel(p: Dictionary) -> Node3D:
	var root := M.root("clock_mantel")
	var mat := M.ps(p, "mat", "madera_negra")
	M.box(root, Vector3(0.3, 0.025, 0.13), Vector3(0, 0.0125, 0), mat)
	M.box(root, Vector3(0.24, 0.2, 0.11), Vector3(0, 0.125, 0), mat)
	M.cyl(root, 0.12, 0.12, 0.11, Vector3(0, 0.225, 0), mat, Vector3(90, 0, 0), 24)
	M.cyl(root, 0.075, 0.075, 0.01, Vector3(0, 0.2, 0.056), "laton", Vector3(90, 0, 0), 24)
	M.cyl(root, 0.066, 0.066, 0.012, Vector3(0, 0.2, 0.057), "vela", Vector3(90, 0, 0), 24)
	var hr := M.pf(p, "hour", 10.1)
	var ah := -TAU * hr / 12.0
	var am := -TAU * fposmod(hr, 1.0)
	var c := Vector3(0, 0.2, 0.065)
	M.beam_ab(root, c, c + Vector3(-sin(ah) * 0.035, cos(ah) * 0.035, 0), 0.006, 0.002, "tinta")
	M.beam_ab(root, c, c + Vector3(-sin(am) * 0.055, cos(am) * 0.055, 0), 0.004, 0.002, "tinta")
	for k in 12:
		var a := TAU * k / 12.0
		M.box(root, Vector3(0.004, 0.01, 0.002), c + Vector3(sin(a) * 0.058, cos(a) * 0.058, -0.002), "tinta", Vector3(0, 0, -rad_to_deg(a)))
	for sx: float in [-1.0, 1.0]:
		M.sphere(root, 0.014, Vector3(sx * 0.12, 0.0, 0.05), "laton", Vector3(1, 0.6, 1))
	return _occ_all(root)

# ======================================================================================
# coins: unas monedas (soberano, chelines, peniques) apiladas y sueltas. Extras: n, seed.
static func build_coins(p: Dictionary) -> Node3D:
	var root := M.root("coins")
	var n := clampi(M.pi_(p, "n", 6), 1, 40)
	var seed := M.seed_of(p, "coins")
	var xf: Array = []; var cc: Array = []
	var stack_h := 0.0
	for i in n:
		var kind := int(M.rnd(seed, i, 0) * 3)
		var r: float = [0.011, 0.012, 0.016][kind]
		var col: Color = [M.color("laton"), M.color("piedra_portland"), M.color("cobre")][kind]
		var pos: Vector3
		if i < n / 2:
			pos = Vector3(0, stack_h + 0.001, 0); stack_h += 0.0022
		else:
			pos = Vector3(M.rr(seed, i, 1, -0.05, 0.05), 0.001, M.rr(seed, i, 2, -0.04, 0.04))
		xf.append(Transform3D(Basis.from_scale(Vector3(r * 2, 0.002, r * 2)), pos))
		cc.append(col)
	M.multi_boxes(root, xf, cc, "lomo", M.cyl_mesh(0.5, 0.5, 1.0, 16))
	return _occ_all(root)

# ======================================================================================
# tray: bandeja de correspondencia de madera (dos pisos). Extras: w, d, letters (n sobres adentro).
static func build_tray(p: Dictionary) -> Node3D:
	var root := M.root("tray")
	var w := M.pf(p, "w", 0.34); var d := M.pf(p, "d", 0.26)
	var mat := M.ps(p, "mat", "madera_media")
	for lvl in 2:
		var y := lvl * 0.09
		M.box(root, Vector3(w, 0.008, d), Vector3(0, y + 0.004, 0), mat)
		M.box(root, Vector3(w, 0.05, 0.008), Vector3(0, y + 0.025, -d / 2), mat)
		M.box(root, Vector3(0.008, 0.05, d), Vector3(-w / 2, y + 0.025, 0), mat)
		M.box(root, Vector3(0.008, 0.05, d), Vector3(w / 2, y + 0.025, 0), mat)
		M.box(root, Vector3(w, 0.025, 0.008), Vector3(0, y + 0.0125, d / 2), mat)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.012, 0.1, 0.012), Vector3(sx * w / 2, 0.05, d / 2 - 0.02), mat)
	var n := M.pi_(p, "letters", 3)
	for i in n:
		var e := build_envelope({})
		e.position = Vector3(-0.02 + i * 0.012, 0.009 + i * 0.004, i * 0.01)
		e.rotation_degrees = Vector3(0, -4 + 5 * i, 0)
		root.add_child(e)
	return _occ_all(root)

# ======================================================================================
# desk_calendar: calendario perpetuo de escritorio con tarjetas (día grande). Extras: text (día), text2 (mes).
static func build_desk_calendar(p: Dictionary) -> Node3D:
	var root := M.root("desk_calendar")
	M.box(root, Vector3(0.14, 0.02, 0.08), Vector3(0, 0.01, 0), "madera_oscura")
	var card := Node3D.new(); card.name = "card"; card.position = Vector3(0, 0.02, -0.005); card.rotation_degrees = Vector3(-12, 0, 0); root.add_child(card)
	M.box(card, Vector3(0.12, 0.125, 0.015), Vector3(0, 0.0625, -0.008), "madera_oscura")
	M.box(card, Vector3(0.1, 0.1, 0.004), Vector3(0, 0.058, 0.0015), "papel")
	M.box(card, Vector3(0.1, 0.022, 0.0045), Vector3(0, 0.1, 0.0035), "pintura_roja")
	var day := M.ps(p, "text", "")
	var mon := M.ps(p, "text2", "")
	if day != "":
		M.label3d(card, day, Vector3(0, 0.05, 0.0045), 0.0011, 48, Color("1b1712"))
	if mon != "":
		M.label3d(card, mon, Vector3(0, 0.1, 0.0065), 0.0004, 40, Color("efe6d2"))
	return _occ_all(root)

# ======================================================================================
# map_board: plano de Londres clavado en un tablero de pared (Támesis, calles, parques). Origen = centro inferior contra la pared.
static func build_map_board(p: Dictionary) -> Node3D:
	var root := M.root("map_board")
	var w := M.pf(p, "w", 0.9); var h := M.pf(p, "h", 0.65)
	var y0 := M.pf(p, "y", 0.0)
	var seed := M.seed_of(p, "map")
	M.box(root, Vector3(w, h, 0.02), Vector3(0, y0 + h / 2, 0.01), "madera_media")
	M.box(root, Vector3(w - 0.06, h - 0.06, 0.003), Vector3(0, y0 + h / 2, 0.022), "papel_viejo")
	var x0 := -w / 2 + 0.04; var x1 := w / 2 - 0.04
	var yb := y0 + 0.04; var yt := y0 + h - 0.04
	# parques (Hyde Park, Regent's Park) como manchas
	M.box(root, Vector3(w * 0.16, h * 0.18, 0.002), Vector3(x0 + w * 0.14, y0 + h * 0.62, 0.0245), "cesped")
	M.box(root, Vector3(w * 0.12, h * 0.14, 0.002), Vector3(x0 + w * 0.3, y0 + h * 0.84, 0.0245), "cesped")
	# Támesis: serpentina de segmentos anchos
	var prev := Vector3(x0, y0 + h * 0.3, 0.025)
	for k in range(1, 15):
		var x := x0 + (x1 - x0) * k / 14.0
		var y := y0 + h * (0.34 + 0.1 * sin(k * 0.75 + 0.6) - 0.05 * cos(k * 1.3))
		var cur := Vector3(x, y, 0.025)
		M.beam_ab(root, prev, cur, 0.03, 0.002, "agua")
		prev = cur
	# calles: avenidas largas casi rectas + retícula fina
	var xf: Array = []
	for i in 7:
		var yy := yb + (yt - yb) * (i + 0.5) / 7.0
		var ang := M.rr(seed, i, 0, -9, 9)
		xf.append(M.xf_box(Vector3(w - 0.12, 0.0035, 0.0012), Vector3(0, yy, 0.0246), Vector3(0, 0, ang)))
	for i in 9:
		var xx := x0 + (x1 - x0) * (i + 0.5) / 9.0
		var ang2 := 90.0 + M.rr(seed, i, 1, -12, 12)
		xf.append(M.xf_box(Vector3(h - 0.12, 0.0025, 0.0012), Vector3(xx, y0 + h / 2, 0.0246), Vector3(0, 0, ang2)))
	for i in 24:
		var L := M.rr(seed, i, 2, 0.05, 0.12)
		xf.append(M.xf_box(Vector3(L, 0.0015, 0.0012), Vector3(M.rr(seed, i, 3, x0 + 0.05, x1 - 0.05), M.rr(seed, i, 4, yb + 0.03, yt - 0.03), 0.0246), Vector3(0, 0, 0.0 if i % 2 == 0 else 90.0)))
	M.multi_boxes(root, xf, [], "tinta")
	for k in 4:
		M.sphere(root, 0.008, Vector3((k % 2 - 0.5) * (w - 0.08), y0 + (0.04 if k < 2 else h - 0.04), 0.026), "laton")
	# página de horarios (Baedeker) pegada en un rincón
	M.box(root, Vector3(0.14, 0.2, 0.002), Vector3(w / 2 - 0.11, y0 + 0.14, 0.0262), "papel")
	for l in 8:
		M.box(root, Vector3(0.1, 0.0035, 0.0015), Vector3(w / 2 - 0.11, y0 + 0.21 - l * 0.02, 0.0278), "tinta")
	return _occ_all(root)

# ======================================================================================
# tobacco_tin: lata de tabaco chata con tapa.
static func build_tobacco_tin(p: Dictionary) -> Node3D:
	var root := M.root("tobacco_tin")
	M.box(root, Vector3(0.1, 0.022, 0.07), Vector3(0, 0.011, 0), "hierro")
	M.box(root, Vector3(0.102, 0.008, 0.072), Vector3(0, 0.024, 0), "laton")
	M.box(root, Vector3(0.06, 0.0015, 0.035), Vector3(0, 0.0285, 0), "pintura_roja")
	return _occ_all(root)

# ======================================================================================
# photo_frame: portarretrato de pie con fotografía (retrato oscuro sobre fondo claro).
static func build_photo_frame(p: Dictionary) -> Node3D:
	var root := M.root("photo_frame")
	var w := M.pf(p, "w", 0.14); var h := M.pf(p, "h", 0.19)
	var fm := M.ps(p, "mat", "laton")
	var g := Node3D.new(); g.rotation_degrees = Vector3(-12, 0, 0); root.add_child(g)
	M.box(g, Vector3(w, 0.016, 0.012), Vector3(0, 0.008, 0), fm)
	M.box(g, Vector3(w, 0.016, 0.012), Vector3(0, h - 0.008, 0), fm)
	M.box(g, Vector3(0.016, h, 0.012), Vector3(-w / 2 + 0.008, h / 2, 0), fm)
	M.box(g, Vector3(0.016, h, 0.012), Vector3(w / 2 - 0.008, h / 2, 0), fm)
	M.box(g, Vector3(w - 0.02, h - 0.02, 0.004), Vector3(0, h / 2, -0.002), "papel_viejo")
	M.sphere(g, 0.022, Vector3(0, h * 0.62, 0.001), "madera_oscura", Vector3(0.85, 1.05, 0.08))
	M.sphere(g, 0.042, Vector3(0, h * 0.3, 0.001), "madera_oscura", Vector3(1.05, 0.85, 0.08))
	M.box(g, Vector3(0.02, h * 0.7, 0.006), Vector3(0, h * 0.35, -0.03), fm, Vector3(-20, 0, 0))
	return _occ_all(root)

# ======================================================================================
# open_ledger_book: libro mayor abierto (páginas en V, renglones y columnas rojas).
static func build_open_ledger_book(p: Dictionary) -> Node3D:
	var root := M.root("open_ledger_book")
	var w := M.pf(p, "w", 0.48); var h := M.pf(p, "h", 0.34)
	var mat := M.ps(p, "mat", "cuero")
	M.box(root, Vector3(w + 0.02, 0.006, h + 0.02), Vector3(0, 0.003, 0), mat)
	for s: float in [-1.0, 1.0]:
		var pg := Node3D.new(); pg.position = Vector3(s * w / 4, 0.012, 0); pg.rotation_degrees = Vector3(0, 0, -s * 4); root.add_child(pg)
		M.box(pg, Vector3(w / 2 - 0.012, 0.014, h - 0.01), Vector3(0, 0, 0), "papel")
		var xf: Array = []
		for l in 18:
			xf.append(M.xf_box(Vector3(w / 2 - 0.04, 0.0006, 0.0012), Vector3(0, 0.0075, -h / 2 + 0.03 + l * (h - 0.05) / 18.0)))
		M.multi_boxes(pg, xf, [], "agua")
		for cx: float in [-0.12, 0.08, 0.15]:
			M.box(pg, Vector3(0.0015, 0.0006, h - 0.04), Vector3(cx * w * 0.5 / 0.25 * 0.5, 0.0076, 0), "pintura_roja")
		for l in 6:
			var lw := M.rr(31, l, int(s), 0.06, 0.14)
			M.box(pg, Vector3(lw, 0.0007, 0.003), Vector3(-0.04 + lw / 2 - 0.05, 0.0078, -h / 2 + 0.04 + l * 0.04), "tinta")
	M.cyl(root, 0.01, 0.01, h, Vector3(0, 0.018, 0), "papel", Vector3(90, 0, 0), 10)
	return _occ_all(root)

# ======================================================================================
# lantern: farol de mano (de ojo de buey) con chimenea y asa. Extras: lit.
static func build_lantern(p: Dictionary) -> Node3D:
	var root := M.root("lantern")
	var lit := M.pb(p, "lit", true)
	M.cyl(root, 0.07, 0.075, 0.03, Vector3(0, 0.015, 0), "hierro", Vector3.ZERO, 16)
	M.cyl(root, 0.06, 0.06, 0.15, Vector3(0, 0.105, 0), "hierro", Vector3.ZERO, 16)
	M.cyl(root, 0.035, 0.035, 0.02, Vector3(0, 0.12, 0.06), "laton", Vector3(90, 0, 0), 16)
	M.cyl(root, 0.03, 0.03, 0.012, Vector3(0, 0.12, 0.069), "gas_emisivo" if lit else "vidrio", Vector3(90, 0, 0), 16)
	M.cyl(root, 0.03, 0.06, 0.05, Vector3(0, 0.205, 0), "hierro", Vector3.ZERO, 16)
	M.cyl(root, 0.018, 0.018, 0.06, Vector3(0, 0.26, 0), "hierro", Vector3.ZERO, 10)
	M.cyl(root, 0.03, 0.03, 0.01, Vector3(0, 0.295, 0), "hierro", Vector3.ZERO, 10)
	# asa (aro vertical sobre la chimenea)
	M.arc(root, Vector3(0, 0.29, 0), 0.06, Vector3.RIGHT, Vector3.UP, 0.0, PI, 8, 0.005, "hierro")
	if lit:
		var S = load("res://world/props/street.gd")
		S.light_anchor(root, Vector3(0, 0.12, 0.1), Color("ffc87a"), 0.6, 3.0)
	return _occ_all(root)

# ======================================================================================
# desk_lamp (extra): lámpara de lectura de latón (depósito, tubo de vidrio y pantalla opalina). Extras: lit, shade (mat).
static func build_desk_lamp(p: Dictionary) -> Node3D:
	var root := M.root("desk_lamp")
	var lit := M.pb(p, "lit", true)
	M.cyl(root, 0.07, 0.08, 0.025, Vector3(0, 0.0125, 0), "laton", Vector3.ZERO, 20)
	M.cyl(root, 0.012, 0.02, 0.2, Vector3(0, 0.125, 0), "laton", Vector3.ZERO, 12)
	M.torus(root, 0.01, 0.03, Vector3(0, 0.12, 0), "laton")
	M.sphere(root, 0.065, Vector3(0, 0.27, 0), "laton", Vector3(1, 0.8, 1))
	M.cyl(root, 0.03, 0.035, 0.03, Vector3(0, 0.325, 0), "laton", Vector3.ZERO, 12)
	M.cyl(root, 0.022, 0.026, 0.16, Vector3(0, 0.42, 0), "vidrio", Vector3.ZERO, 12)
	M.sphere(root, 0.014, Vector3(0, 0.37, 0), "gas_emisivo" if lit else "vela", Vector3(1, 1.6, 1), 8)
	M.cyl(root, 0.075, 0.13, 0.11, Vector3(0, 0.4, 0), M.ps(p, "shade", "vela"), Vector3.ZERO, 20)
	M.torus(root, 0.12, 0.135, Vector3(0, 0.345, 0), "laton")
	if lit:
		var S = load("res://world/props/street.gd")
		S.light_anchor(root, Vector3(0, 0.37, 0), Color("ffc87a"), 1.2, 4.0, "gas")
	return _occ_all(root)
