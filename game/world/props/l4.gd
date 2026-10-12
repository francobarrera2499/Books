# world/props/l4.gd — W2-PLACES-C. Props propios de L4 (consultorio y estudio del doctor Watson, Kensington; GDD§5).
# Convención §7.2: origen = centro del piso de la huella (o del pie, para cosas de pared), frente +Z, metros, meta "occ".
# Determinista (Materials.rnd). Lo genérico (escritorio, sillas, biblioteca con hueco, chimenea…) sale de la biblioteca
# base; acá va sólo lo que el consultorio necesita y la base no tiene.
extends RefCounted

const M = preload("res://world/materials.gd")
const SM = preload("res://world/props/small.gd")

# couch(len,w,h): diván de reconocimiento tapizado, cabecera alzada hacia −Z, sábana doblada a los pies.
static func build_couch(p: Dictionary) -> Node3D:
	var root := M.root("couch")
	var l := M.pf(p, "len", 1.8); var w := M.pf(p, "w", 0.68); var h := M.pf(p, "h", 0.5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.cyl(root, 0.025, 0.02, h - 0.12, Vector3(sx * (w / 2 - 0.05), (h - 0.12) / 2, sz * (l / 2 - 0.06)), "madera_oscura", Vector3.ZERO, 8)
	M.box(root, Vector3(w, 0.08, l), Vector3(0, h - 0.12, 0), "madera_oscura")
	M.box(root, Vector3(w - 0.02, 0.1, l - 0.02), Vector3(0, h - 0.03, 0), "cuero")
	# cabecera inclinada
	var hd := Node3D.new(); hd.position = Vector3(0, h + 0.02, -l / 2 + 0.05); root.add_child(hd)
	hd.rotation_degrees = Vector3(28, 0, 0)
	M.box(hd, Vector3(w - 0.04, 0.09, 0.5), Vector3(0, 0, 0.25), "cuero")
	M.box(hd, Vector3(w * 0.7, 0.07, 0.22), Vector3(0, 0.07, 0.2), "vela")   # almohada
	# sábana doblada a los pies
	M.box(root, Vector3(w - 0.12, 0.05, 0.3), Vector3(0, h + 0.045, l / 2 - 0.25), "vela")
	M.box(root, Vector3(w - 0.14, 0.03, 0.28), Vector3(0, h + 0.085, l / 2 - 0.26), "papel")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -l / 2), Vector3(w / 2, h + 0.1, l / 2))])
	return root

# instrument_cabinet(w,h,d): vitrina de instrumental: frascos rotulados, una balanza y un estuche; puertas vidriadas.
static func build_instrument_cabinet(p: Dictionary) -> Node3D:
	var root := M.root("instrument_cabinet")
	var w := M.pf(p, "w", 0.9); var h := M.pf(p, "h", 1.9); var d := M.pf(p, "d", 0.42)
	var seed := M.seed_of(p, "vitrina")
	var mat := "caoba"
	M.box(root, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), "madera_negra")
	M.box(root, Vector3(w, 0.75, d), Vector3(0, 0.1 + 0.375, 0), mat)            # cuerpo bajo cerrado
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(w / 2 - 0.06, 0.6, 0.012), Vector3(sx * w / 4, 0.48, d / 2 + 0.006), "madera_media")
		M.sphere(root, 0.014, Vector3(sx * 0.04, 0.5, d / 2 + 0.02), "laton")
	var y0 := 0.85
	var uh := h - y0 - 0.08
	M.box(root, Vector3(0.03, uh, d), Vector3(-w / 2 + 0.015, y0 + uh / 2, 0), mat)
	M.box(root, Vector3(0.03, uh, d), Vector3(w / 2 - 0.015, y0 + uh / 2, 0), mat)
	M.box(root, Vector3(w, uh, 0.02), Vector3(0, y0 + uh / 2, -d / 2 + 0.01), "madera_negra")
	M.box(root, Vector3(w + 0.06, 0.08, d + 0.05), Vector3(0, h - 0.04, 0.01), mat)
	for k in 3:
		var sy := y0 + 0.02 + k * uh / 3.0
		M.box(root, Vector3(w - 0.06, 0.015, d - 0.06), Vector3(0, sy, 0), "vela")
		var x := -w / 2 + 0.08
		var i := 0
		while x < w / 2 - 0.1 and i < 12:
			var r := M.rr(seed, i, k, 0.025, 0.05)
			var bh := M.rr(seed, i, k + 5, 0.1, 0.22)
			if k == 1 and i == 2:
				# balanza
				M.box(root, Vector3(0.18, 0.02, 0.08), Vector3(x + 0.09, sy + 0.02, 0.0), "laton")
				M.rod(root, 0.006, 0.16, Vector3(x + 0.09, sy + 0.1, 0.0), "laton")
				M.box(root, Vector3(0.2, 0.006, 0.01), Vector3(x + 0.09, sy + 0.18, 0.0), "laton")
				x += 0.22
			else:
				M.cyl(root, r, r, bh, Vector3(x + r, sy + 0.008 + bh / 2, M.rr(seed, i, k + 9, -0.06, 0.06)), "vela" if M.rnd(seed, i, k + 3) < 0.5 else "ceniza", Vector3.ZERO, 10)
				M.cyl(root, r * 0.45, r * 0.45, 0.03, Vector3(x + r, sy + 0.008 + bh + 0.015, M.rr(seed, i, k + 9, -0.06, 0.06)), "carbon", Vector3.ZERO, 8)
				M.box(root, Vector3(r * 1.4, bh * 0.35, 0.004), Vector3(x + r, sy + 0.008 + bh * 0.5, M.rr(seed, i, k + 9, -0.06, 0.06) + r + 0.002), "papel")
				x += r * 2.0 + 0.03
			i += 1
	# estuche de instrumentos en el estante de abajo
	M.box(root, Vector3(0.36, 0.06, 0.2), Vector3(0.12, y0 + 0.06, 0.02), "cuero")
	# puertas vidriadas (marcos; el vidrio no tapa)
	for sx: float in [-1.0, 1.0]:
		var cx := sx * w / 4
		var dz := d / 2 + 0.01
		M.box(root, Vector3(w / 2 - 0.02, 0.04, 0.02), Vector3(cx, y0 + 0.02, dz), mat)
		M.box(root, Vector3(w / 2 - 0.02, 0.04, 0.02), Vector3(cx, h - 0.1, dz), mat)
		for e: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.035, uh - 0.06, 0.02), Vector3(cx + e * (w / 4 - 0.02), y0 + uh / 2, dz), mat)
		M.box(root, Vector3(w / 2 - 0.06, uh - 0.1, 0.003), Vector3(cx, y0 + uh / 2, dz), "vidrio")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.86, d / 2)),
		M.aabb_mm(Vector3(-w / 2, 0.85, -d / 2), Vector3(-w / 2 + 0.03, h, d / 2)), M.aabb_mm(Vector3(w / 2 - 0.03, 0.85, -d / 2), Vector3(w / 2, h, d / 2)),
		M.aabb_mm(Vector3(-w / 2, 0.85, -d / 2), Vector3(w / 2, h, -d / 2 + 0.02)), M.aabb_mm(Vector3(-w / 2, h - 0.08, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# stethoscope: estetoscopio monoaural de madera (tubo torneado con campana y auricular), acostado. Extras: —.
static func build_stethoscope(_p: Dictionary) -> Node3D:
	var root := M.root("stethoscope")
	M.cyl(root, 0.011, 0.011, 0.17, Vector3(0, 0.012, 0), "madera_clara", Vector3(0, 0, 90), 10)
	M.cyl(root, 0.012, 0.022, 0.03, Vector3(-0.098, 0.022, 0), "madera_clara", Vector3(0, 0, 90), 12)
	M.cyl(root, 0.03, 0.03, 0.012, Vector3(0.092, 0.03, 0), "madera_media", Vector3(0, 0, 90), 14)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.115, 0, -0.03), Vector3(0.1, 0.06, 0.03))])
	return root

# framed(w,h,text?): papel enmarcado de pared (diploma). Origen = centro del marco contra la pared; frente +Z.
# Extras: mat (marco), paper, seal (sello de lacre), lines (renglones simulados).
static func build_framed(p: Dictionary) -> Node3D:
	var root := M.root("framed")
	var w := M.pf(p, "w", 0.5); var h := M.pf(p, "h", 0.4)
	var fm := M.ps(p, "mat", "madera_negra")
	M.box(root, Vector3(w, h, 0.025), Vector3(0, 0, 0.0125), fm)
	M.box(root, Vector3(w - 0.08, h - 0.08, 0.006), Vector3(0, 0, 0.027), M.ps(p, "paper", "papel"))
	var nl := M.pi_(p, "lines", 4)
	for k in nl:
		var lw := (w - 0.18) * (1.0 if k % 2 == 0 else 0.7)
		M.box(root, Vector3(lw, 0.008, 0.002), Vector3(0, h * 0.22 - k * (h * 0.5 / maxf(nl, 1)), 0.031), "tinta")
	M.box(root, Vector3(w * 0.5, 0.018, 0.002), Vector3(0, h * 0.32, 0.031), "tinta")
	if M.pb(p, "seal", true):
		M.cyl(root, 0.03, 0.03, 0.006, Vector3(w * 0.25, -h * 0.3, 0.031), "pintura_roja", Vector3(90, 0, 0), 14)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, h / 2, 0.035))])
	return root

# bench(len): banco de roble con respaldo para la sala de espera (largo en X, mira a +Z).
static func build_bench(p: Dictionary) -> Node3D:
	var root := M.root("bench")
	var l := M.pf(p, "len", 1.6)
	var mat := M.ps(p, "mat", "madera_media")
	M.box(root, Vector3(l, 0.05, 0.42), Vector3(0, 0.44, 0.02), mat)
	M.box(root, Vector3(l, 0.5, 0.04), Vector3(0, 0.75, -0.19), mat, Vector3(-6, 0, 0))
	M.box(root, Vector3(l, 0.06, 0.06), Vector3(0, 1.02, -0.22), mat)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, 0.44, 0.4), Vector3(sx * (l / 2 - 0.04), 0.22, 0.02), mat)
		M.box(root, Vector3(0.05, 0.26, 0.06), Vector3(sx * (l / 2 - 0.04), 0.6, 0.18), mat)
		M.box(root, Vector3(0.06, 0.04, 0.44), Vector3(sx * (l / 2 - 0.04), 0.72, 0.0), mat)
	root.set_meta("occ", [M.aabb_mm(Vector3(-l / 2, 0, -0.23), Vector3(l / 2, 0.47, 0.24)), M.aabb_mm(Vector3(-l / 2, 0.47, -0.25), Vector3(l / 2, 1.05, -0.15))])
	return root

# periodicals(n): pila de revistas delgadas, apenas abiertas en abanico.
static func build_periodicals(p: Dictionary) -> Node3D:
	var root := M.root("periodicals")
	var n := clampi(M.pi_(p, "n", 4), 1, 10)
	var seed := M.seed_of(p, "revistas")
	for k in n:
		var m := "papel" if k % 2 == 0 else "papel_viejo"
		M.box(root, Vector3(0.21, 0.008, 0.29), Vector3(M.rr(seed, k, 1, -0.02, 0.02), 0.005 + k * 0.009, M.rr(seed, k, 2, -0.02, 0.02)), m, Vector3(0, M.rr(seed, k, 3, -14.0, 14.0), 0))
		M.box(root, Vector3(0.12, 0.002, 0.04), Vector3(0, 0.0095 + k * 0.009, -0.08), "tinta", Vector3(0, M.rr(seed, k, 3, -14.0, 14.0), 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.16, 0, -0.18), Vector3(0.16, 0.01 + n * 0.009, 0.18))])
	return root

# umbrella_stand: paragüero de loza con dos bastones y un paraguas.
static func build_umbrella_stand(_p: Dictionary) -> Node3D:
	var root := M.root("umbrella_stand")
	M.cyl(root, 0.13, 0.11, 0.55, Vector3(0, 0.275, 0), "yeso", Vector3.ZERO, 16)
	M.torus(root, 0.11, 0.135, Vector3(0, 0.55, 0), "pintura_verde")
	M.torus(root, 0.1, 0.12, Vector3(0, 0.12, 0), "pintura_verde")
	M.rod_ab(root, 0.012, Vector3(-0.04, 0.05, 0.02), Vector3(-0.09, 0.95, 0.06), "madera_negra")
	M.torus(root, 0.025, 0.04, Vector3(-0.1, 0.97, 0.07), "madera_negra", Vector3(80, 20, 0))
	M.rod_ab(root, 0.012, Vector3(0.03, 0.05, -0.03), Vector3(0.07, 0.92, -0.08), "madera_clara")
	M.cyl(root, 0.012, 0.05, 0.75, Vector3(0.02, 0.5, 0.03), "tela_oscura", Vector3(-4, 0, 5), 8)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.14, 0, -0.14), Vector3(0.14, 0.97, 0.14))])
	return root

# galley_bundle: legajo de pruebas de imprenta (tiras largas) atado con un cordel; la primera con su encabezado.
static func build_galley_bundle(p: Dictionary) -> Node3D:
	var root := M.root("galley_bundle")
	var n := clampi(M.pi_(p, "n", 9), 1, 20)
	var seed := M.seed_of(p, "pruebas")
	for k in n:
		M.box(root, Vector3(0.16, 0.003, 0.5), Vector3(M.rr(seed, k, 1, -0.008, 0.008), 0.002 + k * 0.0035, M.rr(seed, k, 2, -0.01, 0.01)), "papel" if k % 3 else "papel_viejo", Vector3(0, M.rr(seed, k, 3, -2.0, 2.0), 0))
	var top := 0.004 + n * 0.0035
	for r in 14:
		M.box(root, Vector3(0.11 if r % 4 else 0.07, 0.0015, 0.006), Vector3(-0.005, top, -0.2 + r * 0.03), "tinta")
	M.box(root, Vector3(0.09, 0.002, 0.012), Vector3(0, top + 0.0005, -0.225), "tinta")
	M.box(root, Vector3(0.05, 0.002, 0.004), Vector3(0.05, top + 0.001, -0.05), "carbon", Vector3(0, 30, 0))
	for sz: float in [-0.12, 0.12]:
		M.box(root, Vector3(0.17, top + 0.004, 0.006), Vector3(0, top / 2, sz), "madera_clara")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.09, 0, -0.26), Vector3(0.09, top + 0.006, 0.26))])
	return root

# notebook_leaves: hojas de libreta escritas a lápiz, alisadas bajo un pisapapeles de latón.
static func build_notebook_leaves(p: Dictionary) -> Node3D:
	var root := M.root("notebook_leaves")
	var seed := M.seed_of(p, "hojas")
	for k in 3:
		M.box(root, Vector3(0.13, 0.002, 0.2), Vector3(k * 0.012, 0.002 + k * 0.0022, k * 0.01), "papel_viejo", Vector3(0, M.rr(seed, k, 1, -8.0, 8.0), 0))
	for r in 9:
		M.box(root, Vector3(0.09 if r % 3 else 0.06, 0.001, 0.003), Vector3(0.024, 0.0095, -0.07 + r * 0.018), "ceniza")
	M.cyl(root, 0.03, 0.035, 0.03, Vector3(0.05, 0.022, 0.06), "laton", Vector3.ZERO, 14)
	M.sphere(root, 0.012, Vector3(0.05, 0.042, 0.06), "laton")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.08, 0, -0.12), Vector3(0.11, 0.05, 0.12))])
	return root

# chest_open(w,h,d): cómoda de cuatro cajones; el de arriba sacado `open` m con un manuscrito atado con cinta.
static func build_chest_open(p: Dictionary) -> Node3D:
	var root := M.root("chest_open")
	var w := M.pf(p, "w", 1.1); var h := M.pf(p, "h", 0.95); var d := M.pf(p, "d", 0.5)
	var op := M.pf(p, "open", 0.26)
	var mat := M.ps(p, "mat", "madera_media")
	M.box(root, Vector3(w, h - 0.08, d), Vector3(0, 0.08 + (h - 0.08) / 2, 0), mat)
	M.box(root, Vector3(w + 0.04, 0.08, d + 0.03), Vector3(0, 0.04, 0), "madera_negra")
	M.box(root, Vector3(w + 0.05, 0.03, d + 0.04), Vector3(0, h + 0.015, 0.01), mat)
	var dh := (h - 0.12) / 4.0
	for k in 4:
		var cy := 0.1 + dh * (k + 0.5)
		if k == 3:
			# cajón abierto: frente, costados y fondo, con el manuscrito adentro
			var dz := d / 2 + op
			M.box(root, Vector3(w - 0.06, dh - 0.02, 0.022), Vector3(0, cy, dz - 0.011), mat)
			for sx: float in [-1.0, 1.0]:
				M.box(root, Vector3(0.015, dh - 0.05, op + 0.1), Vector3(sx * (w / 2 - 0.05), cy - 0.01, dz - (op + 0.1) / 2 - 0.02), "madera_clara")
			M.box(root, Vector3(w - 0.1, 0.01, op + 0.1), Vector3(0, cy - dh / 2 + 0.02, dz - (op + 0.1) / 2 - 0.02), "madera_clara")
			M.box(root, Vector3(w - 0.06, dh - 0.02, 0.01), Vector3(0, cy, d / 2 - 0.12), "interior_oscuro")
			var mz := dz - 0.16
			M.box(root, Vector3(0.24, 0.05, 0.32), Vector3(-0.12, cy - dh / 2 + 0.05, mz), "papel_viejo", Vector3(0, 6, 0))
			M.box(root, Vector3(0.245, 0.052, 0.012), Vector3(-0.12, cy - dh / 2 + 0.051, mz), "pintura_roja", Vector3(0, 6, 0))
			M.box(root, Vector3(0.012, 0.052, 0.325), Vector3(-0.12, cy - dh / 2 + 0.051, mz), "pintura_roja", Vector3(0, 6, 0))
			M.sphere(root, 0.015, Vector3(-0.2, cy + 0.006, dz + 0.012), "laton")
			M.sphere(root, 0.015, Vector3(0.2, cy + 0.006, dz + 0.012), "laton")
		else:
			M.box(root, Vector3(w - 0.06, dh - 0.02, 0.02), Vector3(0, cy, d / 2 + 0.01), mat)
			M.box(root, Vector3(w - 0.14, dh - 0.07, 0.006), Vector3(0, cy, d / 2 + 0.022), "madera_oscura")
			for sx: float in [-0.25, 0.25]:
				M.sphere(root, 0.015, Vector3(sx * w, cy, d / 2 + 0.03), "laton")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.03, d / 2 + 0.03))])
	return root

# mourning_portrait: portarretrato de pie con una cinta negra cruzada en una esquina.
static func build_mourning_portrait(p: Dictionary) -> Node3D:
	var root := SM.build_photo_frame(p)
	root.name = "mourning_portrait"
	var a := M.aabb_of(root)
	var c := a.get_center()
	M.box(root, Vector3(0.012, a.size.y * 0.55, 0.008), Vector3(c.x + a.size.x * 0.28, c.y + a.size.y * 0.24, a.end.z + 0.004), "crespon", Vector3(0, 0, 45))
	M.box(root, Vector3(0.012, a.size.y * 0.3, 0.008), Vector3(c.x + a.size.x * 0.4, c.y + a.size.y * 0.36, a.end.z + 0.006), "crespon", Vector3(0, 0, 45))
	root.set_meta("occ", [a])
	return root

# receipt: recibo tecleado sobre la mesa (variante «prestadas», HB5).
static func build_receipt(_p: Dictionary) -> Node3D:
	var root := M.root("receipt")
	M.box(root, Vector3(0.14, 0.002, 0.09), Vector3(0, 0.001, 0), "papel")
	for r in 4:
		M.box(root, Vector3(0.1 if r < 3 else 0.05, 0.001, 0.004), Vector3(-0.005, 0.0025, -0.03 + r * 0.016), "tinta")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.07, 0, -0.045), Vector3(0.07, 0.004, 0.045))])
	return root

# bookcase(w,h,base_h,gap_from,gap_to,seed): biblioteca de caoba («the cabinet behind me»): armario bajo de dos puertas y,
# arriba, tres estantes con juegos de tomos iguales (lomos claros, nervios dorados). En el SEGUNDO estante (contado desde
# arriba; también es el segundo desde abajo) falta una hilera entre gap_from..gap_to (x local): se ve el fondo oscuro y la
# marca de polvo donde estaban los lomos. Origen = centro del piso; frente +Z.
static func build_bookcase(p: Dictionary) -> Node3D:
	var root := M.root("bookcase")
	var w := M.pf(p, "w", 1.7); var h := M.pf(p, "h", 2.3); var bh := M.pf(p, "base_h", 0.85); var d := M.pf(p, "d", 0.36)
	var g0 := M.pf(p, "gap_from", 0.12); var g1 := M.pf(p, "gap_to", 0.45)
	var seed := M.seed_of(p, "biblioteca")
	var mat := "caoba"
	# armario bajo
	M.box(root, Vector3(w, bh - 0.08, d + 0.08), Vector3(0, 0.08 + (bh - 0.08) / 2, 0.04), mat)
	M.box(root, Vector3(w + 0.03, 0.08, d + 0.1), Vector3(0, 0.04, 0.04), "madera_negra")
	M.box(root, Vector3(w + 0.06, 0.04, d + 0.14), Vector3(0, bh, 0.05), mat)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(w / 2 - 0.05, bh - 0.22, 0.012), Vector3(sx * w / 4, 0.08 + (bh - 0.08) / 2, d / 2 + 0.085), "madera_oscura")
		M.sphere(root, 0.014, Vector3(sx * 0.05, bh * 0.55, d / 2 + 0.1), "laton")
	# cuerpo alto
	var y0 := bh + 0.02
	var top := h - 0.1
	M.box(root, Vector3(0.03, h - y0, d), Vector3(-w / 2 + 0.015, (y0 + h) / 2, 0), mat)
	M.box(root, Vector3(0.03, h - y0, d), Vector3(w / 2 - 0.015, (y0 + h) / 2, 0), mat)
	M.box(root, Vector3(w, h - y0, 0.02), Vector3(0, (y0 + h) / 2, -d / 2 + 0.01), "madera_negra")
	M.box(root, Vector3(w + 0.08, 0.1, d + 0.06), Vector3(0, h - 0.05, 0.02), mat)
	M.box(root, Vector3(w + 0.12, 0.03, d + 0.09), Vector3(0, h + 0.015, 0.03), mat)
	var sh := (top - y0) / 3.0
	var bx: Array = []; var bc: Array = []; var bands: Array = []; var labels: Array = []
	var pal := [Color("8a7050"), Color("a08a60"), Color("7a6448"), Color("b8a888"), Color("8c5a40"), Color("9a8a6a")]
	for s in 3:
		var sy := top - sh * (s + 1)                         # tabla del estante s (0 = arriba)
		M.box(root, Vector3(w - 0.06, 0.022, d - 0.02), Vector3(0, sy + 0.011, 0), mat)
		M.box(root, Vector3(w - 0.06, 0.03, 0.02), Vector3(0, sy + 0.008, d / 2 - 0.012), mat)
		var x := -w / 2 + 0.035
		var k := 0
		while x < w / 2 - 0.05 and k < 12:
			var n := 4 + int(M.rnd(seed, s, k) * 6.0)
			var t := M.rr(seed, s * 13 + k, 1, 0.045, 0.07)
			var vh := minf(sh - 0.05, M.rr(seed, s * 13 + k, 2, 0.24, 0.33))
			var col: Color = pal[int(M.rnd(seed, s * 13 + k, 3) * pal.size()) % pal.size()]
			for v in n:
				if x + t > w / 2 - 0.035: break
				if s == 1 and x + t > g0 and x < g1:
					x = g1 + 0.002
					continue
				var c := Vector3(x + t / 2, sy + 0.022 + vh / 2, d / 2 - 0.03 - (d - 0.08) / 2 + 0.01)
				bx.append(M.xf_box(Vector3(t - 0.003, vh, d - 0.08), c))
				bc.append(col)
				for b in 2:
					bands.append(M.xf_box(Vector3(t - 0.002, 0.008, 0.004), Vector3(c.x, c.y + vh * (0.32 - 0.22 * b), c.z + (d - 0.08) / 2 + 0.002)))
				labels.append(M.xf_box(Vector3(t * 0.6, 0.035, 0.004), Vector3(c.x, c.y + vh * 0.18, c.z + (d - 0.08) / 2 + 0.002)))
				x += t
			x += 0.004
			k += 1
		if s == 1:
			# marca de polvo donde estaban los cinco lomos
			M.box(root, Vector3(g1 - g0 - 0.01, 0.003, d - 0.1), Vector3((g0 + g1) / 2, sy + 0.0235, -0.01), "papel_viejo")
			M.box(root, Vector3(g1 - g0 - 0.01, 0.003, 0.012), Vector3((g0 + g1) / 2, sy + 0.0235, d / 2 - 0.06), "papel")
	M.multi_boxes(root, bx, bc, "lomo")
	M.multi_boxes(root, bands, [], "laton")
	M.multi_boxes(root, labels, [], "carbon")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, bh + 0.02, d / 2 + 0.1)),
		M.aabb_mm(Vector3(-w / 2, y0, -d / 2), Vector3(-w / 2 + 0.03, h, d / 2)), M.aabb_mm(Vector3(w / 2 - 0.03, y0, -d / 2), Vector3(w / 2, h, d / 2)),
		M.aabb_mm(Vector3(-w / 2, y0, -d / 2), Vector3(w / 2, h, -d / 2 + 0.02)), M.aabb_mm(Vector3(-w / 2, h - 0.1, -d / 2), Vector3(w / 2, h + 0.03, d / 2))])
	return root

# prescription_book: recetario abierto (talonario con matrices) y un lápiz; oclusor explícito.
static func build_prescription_book(_p: Dictionary) -> Node3D:
	var root := M.root("prescription_book")
	M.box(root, Vector3(0.24, 0.012, 0.17), Vector3(0, 0.006, 0), "cuero")
	for s: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.11, 0.01, 0.16), Vector3(s * 0.058, 0.016, 0), "papel", Vector3(0, 0, -s * 3))
	for r in 6:
		M.box(root, Vector3(0.07, 0.001, 0.002), Vector3(0.06, 0.022, -0.05 + r * 0.02), "tinta")
	M.rod_ab(root, 0.004, Vector3(-0.1, 0.026, 0.09), Vector3(0.02, 0.026, 0.11), "madera_clara")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.13, 0, -0.09), Vector3(0.13, 0.03, 0.12))])
	return root
