# world/props/l6.gd — W2-PLACES-C. Props propios de L6, Somerset House (sala de búsquedas: calendars de sucesiones,
# índices trimestrales de defunciones, mostrador del chelín, mesa de testamentos sin extractos; GDD§5, D18).
# Convención §7.2: origen = centro del piso de la huella (o del pie, para cosas de pared), frente +Z, meta "occ".
extends RefCounted

const M = preload("res://world/materials.gd")

# calendar_shelves(w,h,d,rows): estantería de pared con los calendars encuadernados: tomos grandes iguales, uno por año,
# con tejuelo claro. Mira a +Z.
static func build_calendar_shelves(p: Dictionary) -> Node3D:
	var root := M.root("calendar_shelves")
	var w := M.pf(p, "w", 4.0); var h := M.pf(p, "h", 2.6); var d := M.pf(p, "d", 0.5)
	var rows := clampi(M.pi_(p, "rows", 4), 1, 8)
	var seed := M.seed_of(p, "calendars")
	var mat := M.ps(p, "mat", "madera_media")
	M.box(root, Vector3(w, h, 0.03), Vector3(0, h / 2, -d / 2 + 0.015), "madera_negra")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, h, d), Vector3(sx * (w / 2 - 0.02), h / 2, 0), mat)
	var bays := maxi(int(w / 1.0), 1)
	for b in range(1, bays):
		M.box(root, Vector3(0.03, h, d), Vector3(-w / 2 + w * b / bays, h / 2, 0), mat)
	M.box(root, Vector3(w + 0.06, 0.08, d + 0.04), Vector3(0, h + 0.04, 0.02), mat)
	M.box(root, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), "madera_negra")
	var rh := (h - 0.12) / rows
	var bx: Array = []; var bc: Array = []; var lb: Array = []
	for r in rows:
		var y0 := 0.1 + r * rh
		M.box(root, Vector3(w - 0.06, 0.025, d - 0.03), Vector3(0, y0 + 0.012, 0), mat)
		var x := -w / 2 + 0.05
		var i := 0
		while x < w / 2 - 0.12 and i < 80:
			var t := 0.075 + 0.012 * M.rnd(seed, r, i)
			var vh := minf(rh - 0.06, 0.44)
			# un hueco cada tanto (tomo en consulta)
			if M.rnd(seed, r, i + 300) < 0.05:
				x += t + 0.01
				i += 1
				continue
			var f := 0.85 + 0.25 * M.rnd(seed, r, i + 100)
			var base := Color("4a3a2a") if r % 2 == 0 else Color("5a4632")
			bx.append(M.xf_box(Vector3(t - 0.004, vh, d * 0.78), Vector3(x + t / 2, y0 + 0.025 + vh / 2, d * 0.08)))
			bc.append(Color(base.r * f, base.g * f, base.b * f))
			lb.append(M.xf_box(Vector3(t * 0.6, 0.05, 0.004), Vector3(x + t / 2, y0 + 0.025 + vh * 0.78, d * 0.47 + 0.002)))
			x += t
			i += 1
	M.multi_boxes(root, bx, bc, "lomo")
	M.multi_boxes(root, lb, [], "papel")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.08, -d / 2 + 0.03)),
		M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(-w / 2 + 0.04, h, d / 2)), M.aabb_mm(Vector3(w / 2 - 0.04, 0, -d / 2), Vector3(w / 2, h, d / 2)),
		M.aabb_mm(Vector3(-w / 2, h, -d / 2), Vector3(w / 2, h + 0.08, d / 2))])
	return root

# lectern_table(w): mesa larga con tapa en atril; un tomo grande abierto y otro cerrado. Mira a +Z (lector del lado +Z).
static func build_lectern_table(p: Dictionary) -> Node3D:
	var root := M.root("lectern_table")
	var w := M.pf(p, "w", 2.4); var d := 0.7; var h := 0.95
	var mat := "madera_media"
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.06, h - 0.05, d - 0.1), Vector3(sx * (w / 2 - 0.08), (h - 0.05) / 2, 0), mat)
	M.box(root, Vector3(w - 0.16, 0.05, 0.05), Vector3(0, 0.25, 0), mat)
	var top := Node3D.new(); top.position = Vector3(0, h, 0); top.rotation_degrees = Vector3(14, 0, 0); root.add_child(top)
	M.box(top, Vector3(w, 0.04, d), Vector3.ZERO, mat)
	M.box(top, Vector3(w, 0.03, 0.03), Vector3(0, 0.03, d / 2 - 0.015), "madera_oscura")
	# tomo abierto (páginas en V) y uno cerrado
	for s: float in [-1.0, 1.0]:
		var pg := Node3D.new(); pg.position = Vector3(-0.35 + s * 0.17, 0.035, -0.02); pg.rotation_degrees = Vector3(0, 0, -s * 5); top.add_child(pg)
		M.box(pg, Vector3(0.33, 0.03, 0.46), Vector3.ZERO, "papel")
		for l in 14:
			M.box(pg, Vector3(0.26, 0.0008, 0.0015), Vector3(0, 0.0155, -0.2 + l * 0.03), "tinta")
	M.box(top, Vector3(0.7, 0.012, 0.5), Vector3(-0.35, 0.022, -0.02), "cuero")
	M.box(top, Vector3(0.34, 0.07, 0.47), Vector3(0.55, 0.055, -0.02), "madera_oscura", Vector3(0, 8, 0))
	M.box(top, Vector3(0.2, 0.004, 0.06), Vector3(0.55, 0.092, 0.12), "papel", Vector3(0, 8, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.12, d / 2))])
	return root

# will_table: mesa de testamentos: atril con un testamento desplegado (sello de lacre), barandilla de latón y un cartel
# chico «Se prohíbe tomar extractos». Mira a +Z.
static func build_will_table(p: Dictionary) -> Node3D:
	var root := M.root("will_table")
	var w := M.pf(p, "w", 1.4); var d := 0.8; var h := 0.78
	var mat := "madera_oscura"
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.cyl(root, 0.03, 0.025, h - 0.04, Vector3(sx * (w / 2 - 0.07), (h - 0.04) / 2, sz * (d / 2 - 0.07)), mat, Vector3.ZERO, 8)
	M.box(root, Vector3(w, 0.05, d), Vector3(0, h - 0.025, 0), mat)
	M.box(root, Vector3(w - 0.1, 0.004, d - 0.1), Vector3(0, h + 0.002, 0), "pano")
	var lec := Node3D.new(); lec.position = Vector3(0, h + 0.004, -0.05); lec.rotation_degrees = Vector3(28, 0, 0); root.add_child(lec)
	M.box(lec, Vector3(0.62, 0.025, 0.46), Vector3(0, 0.0125, 0), "madera_media")
	M.box(lec, Vector3(0.56, 0.004, 0.4), Vector3(0, 0.028, 0), "papel_viejo")
	for l in 12:
		M.box(lec, Vector3(0.44, 0.001, 0.002), Vector3(0, 0.031, -0.16 + l * 0.026), "tinta")
	M.cyl(lec, 0.03, 0.03, 0.006, Vector3(0.18, 0.032, 0.14), "pintura_roja", Vector3.ZERO, 14)
	M.box(lec, Vector3(0.62, 0.02, 0.02), Vector3(0, 0.03, 0.23), "laton")
	# barandilla: el público no toca
	for sx: float in [-1.0, 1.0]:
		M.rod(root, 0.012, 0.32, Vector3(sx * (w / 2 - 0.05), h + 0.16, d / 2 - 0.05), "laton")
	M.rod_ab(root, 0.012, Vector3(-w / 2 + 0.05, h + 0.32, d / 2 - 0.05), Vector3(w / 2 - 0.05, h + 0.32, d / 2 - 0.05), "laton")
	var sg := Node3D.new(); sg.position = Vector3(w / 2 - 0.22, h + 0.004, 0.18); root.add_child(sg)
	M.box(sg, Vector3(0.26, 0.16, 0.012), Vector3(0, 0.1, 0), "papel")
	M.box(sg, Vector3(0.02, 0.06, 0.06), Vector3(0, 0.0, -0.02), "madera_negra")
	var lb := M.label3d(sg, M.ps(p, "notice", "PROHIBIDO TOMAR EXTRACTOS"), Vector3(0, 0.1, 0.008), 0.0009, 48, Color("1b1712"))
	lb.width = 0.24 / 0.0009
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, h - 0.05, -d / 2), Vector3(w / 2, h, d / 2)),
		M.aabb_mm(Vector3(-0.3, h, -0.3), Vector3(0.3, h + 0.25, 0.15))])
	return root

# copy_box: caja de madera con ranura para los pedidos de copia oficial (llegan por correo). Rótulo «COPIAS».
static func build_copy_box(p: Dictionary) -> Node3D:
	var root := M.root("copy_box")
	M.box(root, Vector3(0.34, 0.24, 0.24), Vector3(0, 0.12, 0), "madera_media")
	M.box(root, Vector3(0.36, 0.03, 0.26), Vector3(0, 0.255, 0), "madera_oscura")
	M.box(root, Vector3(0.18, 0.012, 0.02), Vector3(0, 0.27, 0.0), "carbon")
	M.box(root, Vector3(0.24, 0.07, 0.004), Vector3(0, 0.15, 0.122), "papel")
	var lb := M.label3d(root, M.ps(p, "text", "COPIAS"), Vector3(0, 0.15, 0.126), 0.0011, 48, Color("1b1712"))
	lb.name = "text"
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.17, 0, -0.13), Vector3(0.17, 0.28, 0.13))])
	return root

# wall_clock: reloj redondo de oficina para colgar; origen = centro, contra la pared, mira a +Z.
static func build_wall_clock(p: Dictionary) -> Node3D:
	var root := M.root("wall_clock")
	var r := M.pf(p, "r", 0.22)
	M.cyl(root, r + 0.03, r + 0.03, 0.08, Vector3(0, 0, 0.04), "madera_negra", Vector3(90, 0, 0), 28)
	M.cyl(root, r, r, 0.01, Vector3(0, 0, 0.085), "vela", Vector3(90, 0, 0), 28)
	var hr := M.pf(p, "hour", 11.2)
	var ah := -TAU * hr / 12.0
	var am := -TAU * fposmod(hr, 1.0)
	var c := Vector3(0, 0, 0.092)
	M.beam_ab(root, c, c + Vector3(-sin(ah) * r * 0.5, cos(ah) * r * 0.5, 0), 0.016, 0.003, "tinta")
	M.beam_ab(root, c, c + Vector3(-sin(am) * r * 0.8, cos(am) * r * 0.8, 0), 0.01, 0.003, "tinta")
	for k in 12:
		var a := TAU * k / 12.0
		M.box(root, Vector3(0.008, 0.03, 0.002), c + Vector3(sin(a) * r * 0.86, cos(a) * r * 0.86, -0.002), "tinta", Vector3(0, 0, -rad_to_deg(a)))
	root.set_meta("occ", [M.aabb_mm(Vector3(-r - 0.03, -r - 0.03, 0), Vector3(r + 0.03, r + 0.03, 0.095))])
	return root

# colonnade(w,h,n): pórtico de piedra de Portland: n columnas con basa y capitel, entablamento y frontón. Mira a +Z.
static func build_colonnade(p: Dictionary) -> Node3D:
	var root := M.root("colonnade")
	var w := M.pf(p, "w", 8.0); var h := M.pf(p, "h", 9.0)
	var n := clampi(M.pi_(p, "n", 6), 2, 12)
	var r := M.pf(p, "r", 0.32)
	var st := "piedra_portland"
	M.box(root, Vector3(w + 0.6, 0.5, 1.4), Vector3(0, 0.25, 0), st)
	for k in n:
		var x := -w / 2 + w * k / (n - 1)
		M.box(root, Vector3(r * 2.6, 0.25, r * 2.6), Vector3(x, 0.62, 0), st)
		M.cyl(root, r * 0.9, r, h - 1.4, Vector3(x, 0.75 + (h - 1.4) / 2, 0), st, Vector3.ZERO, 18)
		M.box(root, Vector3(r * 2.7, 0.3, r * 2.7), Vector3(x, h - 0.5, 0), st)
		M.cyl(root, r * 1.25, r * 0.95, 0.25, Vector3(x, h - 0.75, 0), st, Vector3.ZERO, 18)
	M.box(root, Vector3(w + 1.0, 0.9, 1.2), Vector3(0, h + 0.1, 0), st)
	M.box(root, Vector3(w + 1.2, 0.15, 1.35), Vector3(0, h + 0.6, 0.02), st)
	M.prism(root, Vector3(w + 1.0, 1.6, 1.1), Vector3(0, h + 1.48, 0), st)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.3, 0, -0.7), Vector3(w / 2 + 0.3, 0.5, 0.7)),
		M.aabb_mm(Vector3(-w / 2 - 0.5, h - 0.35, -0.6), Vector3(w / 2 + 0.5, h + 2.3, 0.7))])
	return root

# register_book(w,h): libro de registro abierto con oclusor explícito (ver l5.build_register_book).
static func build_register_book(p: Dictionary) -> Node3D:
	var root = load("res://world/props/small.gd").build_open_ledger_book(p)
	var w := M.pf(p, "w", 0.48); var h := M.pf(p, "h", 0.34)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.01, 0, -h / 2 - 0.01), Vector3(w / 2 + 0.01, 0.03, h / 2 + 0.01))])
	return root
