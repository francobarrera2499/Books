# world/props/plates.gd — W2-PLACES-C. Láminas fijas que no se visitan (ARCHITECTURE §7.2, §7.3; GDD§5 «Láminas»).
# build_reichenbach(p): la garganta del Reichenbach en tres variantes armadas a mano (GDD§14.4 «Variantes por fuente»):
#   "fina"    — lo que imprimió la Strand: sendero de tres pies, PARED LISA a un lado, precipicio al otro; el bastón.
#   "journal" — lo que dice el Journal de Genève: más arriba, una cornisa honda con musgo; a la altura del hombro, una
#               marca reciente; el bastón. El saliente que la tapa desde el sendero es otro prop (reichenbach_saliente).
#   "foto"    — la fotografía-recuerdo de Crane: la misma roca, sin gente ni bastón; la cornisa se lee como una línea
#               oscura sobre el final del sendero (nada dice que sea una cornisa).
# Coordenadas (m, Y arriba): pared A con cara z=0 sobre el sendero y z=PATH_W bajo él; el sendero (y=0) termina de golpe
# en x=PATH_END; la otra orilla es la pared B (cara z=GORGE); la cascada cae en la olla del fondo (cara x=HEAD_X) hasta el
# pozo (y=BOTTOM). La roca son masas grandes con tonos deterministas (Materials.rnd), siempre DETRÁS de las caras
# nominales (las anclas de nodos van sobre ellas). meta "occ": una caja por paño; el saliente tiene su propio prop para que
# la tijera lo tome como oclusor de la cornisa vista desde el sendero (rect_clip ignora los oclusores del propio prop).
extends RefCounted

const M = preload("res://world/materials.gd")

const PATH_W := 0.95
const PATH_END := 2.5
const GORGE := 16.0
const HEAD_X := 14.0
const BOTTOM := -28.0
const TOP_A := 14.0
const TOP_B := 2.0
const LEDGE_X0 := -4.6
const LEDGE_X1 := 2.4
const LEDGE_Y := 6.2        # piso de la cornisa (tope del saliente)
const LEDGE_TOP := 7.7      # techo del hueco (irregular: ±0,3)
const LEDGE_BACK := -1.5    # fondo del hueco
const BULGE_Y0 := 3.9
const BULGE_Z := 1.05
const BX0 := -10.0          # tramo de pared que arma el saliente
const BX1 := 4.6
const FALL_Z0 := 6.0
const FALL_Z1 := 8.6
const MARK := Vector3(0.75, 1.46, 0.0)
const STICK_BASE := Vector3(2.05, 0.04, 0.62)
const STICK_TOP := Vector3(1.88, 1.4, 0.07)

const SHADES := ["a29c8e", "9e9889", "a59f91", "9b9587", "a8a294", "a09a8c"]

static func _shade(seed: int, i: int, k: int, f: float) -> Material:
	var c := Color(SHADES[int(M.rnd(seed, i, k) * SHADES.size()) % SHADES.size()])
	f = clampf(f, 0.2, 1.3)
	return M.mat_color(Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1)))

static func _tint(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := M.box(parent, size, pos, "roca", rot)
	mi.material_override = mat
	return mi

# Paño de roca en masas grandes (pocos bordes: el grabado los convierte en líneas). Cada columna (ancho seg) se parte
# en hiladas (alto band) que retroceden entre 0,25 y rec m detrás de `face` y giran apenas en Y; surcos oscuros de
# estrato, alguna repisa y una grieta por hilada. Todo queda DETRÁS de la cara: las anclas de nodos van delante.
# axis "z": cara en z=face mirando a dir (+1 → +z); "x": cara en x=face mirando a dir. u = coordenada a lo largo.
# skip: [u0, v0, u1, v1] sin masas. dark: oscurece con la profundidad (el precipicio).
static func _cliff(parent: Node3D, seed: int, axis: String, face: float, dir: float, u0: float, u1: float, v0: float, v1: float,
		rec: float, seg: Vector2, band: Vector2, skip: Array = [], dark := true, tilt := 4.0) -> void:
	var u := u0
	var i := 0
	while u < u1 - 0.05 and i < 80:
		var w := minf(M.rr(seed, i, 1, seg.x, seg.y), u1 - u)
		if u1 - u - w < seg.x * 0.5: w = u1 - u
		var col_r := M.rr(seed, i, 2, rec * 0.3, rec)
		var v := v0
		var j := 0
		while v < v1 - 0.05 and j < 40:
			var h := minf(M.rr(seed, i * 37 + j, 3, band.x, band.y), v1 - v)
			if v1 - v - h < band.x * 0.5: h = v1 - v
			var cu := u + w / 2.0
			var cv := v + h / 2.0
			var cut := false
			for sk in skip:
				if u + w > float(sk[0]) + 0.01 and u < float(sk[2]) - 0.01 and v + h > float(sk[1]) + 0.01 and v < float(sk[3]) - 0.01: cut = true
			if not cut:
				var k := i * 37 + j
				var r := clampf(col_r + M.rr(seed, k, 4, -rec * 0.2, rec * 0.2), rec * 0.2, rec * 1.15)
				var yaw := M.rr(seed, k, 5, -tilt, tilt)
				var roll := M.rr(seed, k, 24, -tilt * 1.6, tilt * 1.6)
				var f := M.rr(seed, k, 6, 0.96, 1.04)
				if dark: f *= lerpf(1.0, 0.22, clampf(-cv / 11.0, 0.0, 1.0))
				var mat := _shade(seed, k, 7, f)
				var grv := _shade(seed, k, 8, f * 0.55)
				var dpt := 3.0
				var front := face - dir * r
				if axis == "z":
					_tint(parent, Vector3(w + 0.02, h + 0.02, dpt), Vector3(cu, cv, front - dir * dpt / 2.0), mat, Vector3(0, yaw, roll))
					for g in int(M.rr(seed, k, 9, 0.0, 2.99)):
						var gy := v + h * M.rr(seed, k, 10 + g, 0.15, 0.85)
						_tint(parent, Vector3(w * 0.96, 0.07, 0.05), Vector3(cu, gy, front + dir * 0.01), grv, Vector3(0, yaw, roll))
					if M.rnd(seed, k, 19) < 0.35:
						_tint(parent, Vector3(w * 0.7, 0.12, 0.3), Vector3(cu, v + h - 0.06, front + dir * 0.1), _shade(seed, k, 20, f * 1.12))
					if M.rnd(seed, k, 21) < 0.6:
						_tint(parent, Vector3(0.06, h, 0.05), Vector3(u + w * M.rr(seed, k, 23, 0.2, 0.8), cv, front + dir * 0.012), grv)
				else:
					_tint(parent, Vector3(dpt, h + 0.02, w + 0.02), Vector3(front - dir * dpt / 2.0, cv, cu), mat, Vector3(roll, yaw, 0))
					for g in int(M.rr(seed, k, 9, 0.0, 2.99)):
						var gy2 := v + h * M.rr(seed, k, 10 + g, 0.15, 0.85)
						_tint(parent, Vector3(0.05, 0.07, w), Vector3(front + dir * 0.01, gy2, cu), grv, Vector3(0, yaw, 0))
			v += h
			j += 1
		u += w
		i += 1

static func _pine(parent: Node3D, base: Vector3, h: float) -> void:
	M.cyl(parent, 0.05, 0.09, h * 0.3, base + Vector3(0, h * 0.15, 0), "madera_negra", Vector3.ZERO, 6)
	for k in 4:
		var r := h * (0.26 - 0.05 * k)
		M.cyl(parent, 0.0, r, h * 0.36, base + Vector3(0, h * (0.28 + 0.17 * k), 0), "pintura_verde", Vector3.ZERO, 7)

static func _bush(parent: Node3D, c: Vector3, r: float) -> void:
	M.sphere(parent, r, c, "pintura_verde", Vector3(1.4, 0.7, 1.1), 8)

# ======================================================================================
# reichenbach(variant:"fina"|"journal"|"foto"). Extras: seed.
static func build_reichenbach(p: Dictionary) -> Node3D:
	var variant := M.ps(p, "variant", "fina")
	if not ["fina", "journal", "foto"].has(variant): variant = "fina"
	var seed := M.seed_of(p, "rb")
	var root := M.root("reichenbach_" + variant)
	var occ: Array = []
	var ledge := variant != "fina"
	var people := variant != "foto"   # la foto-recuerdo: el paisaje sin el suceso (ni bastón ni marca)
	var rock := Node3D.new(); rock.name = "roca"; root.add_child(rock)
	# ---- pared A bajo el sendero: el precipicio (cara z=PATH_W hasta el final del sendero; después, a plomo en z=0)
	M.box_mm(rock, Vector3(-40, BOTTOM - 2, -8), Vector3(PATH_END, -0.04, PATH_W - 1.5), "carbon")
	M.box_mm(rock, Vector3(PATH_END, BOTTOM - 2, -8), Vector3(HEAD_X + 1, -0.04, -1.5), "carbon")
	occ.append(M.aabb_mm(Vector3(-40, BOTTOM - 2, -8), Vector3(PATH_END, 0.0, PATH_W)))
	occ.append(M.aabb_mm(Vector3(PATH_END, BOTTOM - 2, -8), Vector3(HEAD_X, 0.0, 0.0)))
	_cliff(rock, seed + 1, "z", PATH_W, 1.0, -40.0, PATH_END, BOTTOM - 1.0, -0.04, 0.5, Vector2(3.0, 6.0), Vector2(2.5, 6.0), [], true, 2.5)
	_cliff(rock, seed + 2, "z", 0.0, 1.0, PATH_END, HEAD_X, BOTTOM - 1.0, -0.04, 0.5, Vector2(3.0, 5.0), Vector2(2.5, 6.0), [], true, 2.5)
	# el sendero: tierra pisada cortada en la roca; pliegue oscuro al pie de la pared; piedras en el borde
	M.box_mm(root, Vector3(-40, -0.08, -0.25), Vector3(PATH_END, 0.03, PATH_W + 0.05), "tierra")
	M.box_mm(root, Vector3(-40, 0.0, -0.02), Vector3(PATH_END, 0.06, 0.05), "carbon")
	occ.append(M.aabb_mm(Vector3(-40, -0.08, -0.25), Vector3(PATH_END, 0.03, PATH_W)))
	for k in 16:
		var x := -16.0 + k * 1.15 + M.rr(seed, k, 31, -0.3, 0.3)
		if x > PATH_END - 0.3: break
		M.sphere(root, M.rr(seed, k, 32, 0.06, 0.12), Vector3(x, 0.05, PATH_W - 0.07), "roca", Vector3(1.4, 0.7, 1), 8)
	# ---- pared A sobre el sendero
	M.box_mm(rock, Vector3(-40, 0.0, -8), Vector3(HEAD_X + 1, TOP_A, -1.6), "carbon")
	if not ledge:
		# FINA: lisa y a pique. Un solo paño, sin salientes ni estratos; apenas vetas verticales de humedad.
		_tint(rock, Vector3(HEAD_X + 40, TOP_A, 1.6), Vector3((HEAD_X - 40) / 2.0, TOP_A / 2.0, -0.8), _shade(seed, 1, 1, 1.0))
		occ.append(M.aabb_mm(Vector3(-40, 0.0, -8), Vector3(HEAD_X, TOP_A, 0.0)))
		for k in 12:
			var x2 := -16.0 + k * 1.8 + M.rr(seed, k, 41, -0.4, 0.4)
			var y0 := M.rr(seed, k, 42, 1.5, 6.0)
			var sh := M.rr(seed, k, 44, 4.0, 10.0)
			_tint(rock, Vector3(M.rr(seed, k, 43, 0.06, 0.18), sh, 0.02), Vector3(x2, y0 + sh / 2.0, -0.005), _shade(seed, k, 45, 0.82))
	else:
		occ.append(M.aabb_mm(Vector3(-40, 0.0, -8), Vector3(LEDGE_X0, TOP_A, 0.0)))
		occ.append(M.aabb_mm(Vector3(LEDGE_X1, 0.0, -8), Vector3(HEAD_X, TOP_A, 0.0)))
		occ.append(M.aabb_mm(Vector3(LEDGE_X0, 0.0, -8), Vector3(LEDGE_X1, LEDGE_Y, 0.0)))
		occ.append(M.aabb_mm(Vector3(LEDGE_X0, LEDGE_TOP, -8), Vector3(LEDGE_X1, TOP_A, 0.15)))
		occ.append(M.aabb_mm(Vector3(LEDGE_X0, LEDGE_Y, -8), Vector3(LEDGE_X1, LEDGE_TOP, LEDGE_BACK)))
		# a ambos lados del tramo de la cornisa, roca en masas
		_cliff(rock, seed + 3, "z", 0.0, 1.0, -40.0, LEDGE_X0, 0.0, TOP_A, 0.3, Vector2(2.5, 5.0), Vector2(1.6, 3.6), [], false, 1.5)
		_cliff(rock, seed + 6, "z", 0.0, 1.0, LEDGE_X1, HEAD_X, 0.0, TOP_A, 0.3, Vector2(2.5, 4.5), Vector2(1.6, 3.6), [], false, 1.5)
		# tramo de la cornisa: roca lisa al pie (la marca), el hueco en sombra y el techo que vuela un poco
		_tint(rock, Vector3(LEDGE_X1 - LEDGE_X0, LEDGE_Y, 1.5), Vector3((LEDGE_X0 + LEDGE_X1) / 2.0, LEDGE_Y / 2.0, -0.75), _shade(seed, 2, 2, 1.04))
		_tint(rock, Vector3(LEDGE_X1 - LEDGE_X0 + 1.0, TOP_A - LEDGE_TOP - 0.6, 1.5), Vector3((LEDGE_X0 + LEDGE_X1) / 2.0, (TOP_A + LEDGE_TOP + 0.6) / 2.0, -0.75), _shade(seed, 3, 3, 0.96))
		# hueco: fondo en sombra con techo irregular (no es una ventana: es roca que se abre)
		var nseg := 7
		for q in nseg:
			var qx0 := LEDGE_X0 + (LEDGE_X1 - LEDGE_X0) * q / nseg
			var qx1 := LEDGE_X0 + (LEDGE_X1 - LEDGE_X0) * (q + 1) / nseg
			var top := LEDGE_TOP + M.rr(seed, q, 91, -0.35, 0.3)
			var back := LEDGE_BACK + M.rr(seed, q, 92, -0.2, 0.35)
			M.box_mm(rock, Vector3(qx0, LEDGE_Y, back - 0.4), Vector3(qx1 + 0.01, top, back), "carbon")
			M.box_mm(rock, Vector3(qx0, top - 0.03, back), Vector3(qx1 + 0.01, top + 0.5, 0.05 - M.rr(seed, q, 93, 0.0, 0.4)), "carbon")
			_tint(rock, Vector3(qx1 - qx0 + 0.05, 0.6, 0.7), Vector3((qx0 + qx1) / 2.0, top + 0.32, -0.3 + M.rr(seed, q, 94, -0.1, 0.25)), _shade(seed, q, 95, M.rr(seed, q, 96, 0.72, 0.92)), Vector3(0, M.rr(seed, q, 97, -5.0, 5.0), M.rr(seed, q, 98, -6.0, 6.0)))
		M.box_mm(rock, Vector3(LEDGE_X0 - 0.3, LEDGE_Y, LEDGE_BACK - 0.2), Vector3(LEDGE_X0, LEDGE_TOP + 0.3, 0.0), "carbon")
		M.box_mm(rock, Vector3(LEDGE_X1, LEDGE_Y, LEDGE_BACK - 0.2), Vector3(LEDGE_X1 + 0.3, LEDGE_TOP + 0.3, 0.0), "carbon")
		# piso de la cornisa: musgo (Journal) o roca en sombra (foto: no se distingue nada)
		if variant == "journal":
			M.box_mm(root, Vector3(LEDGE_X0, LEDGE_Y - 0.05, LEDGE_BACK), Vector3(LEDGE_X1, LEDGE_Y + 0.05, BULGE_Z - 0.05), "cesped")
			for k in 14:
				var mx := M.rr(seed, k, 51, LEDGE_X0 + 0.3, LEDGE_X1 - 0.3)
				var mz := M.rr(seed, k, 52, LEDGE_BACK + 0.2, BULGE_Z - 0.2)
				M.sphere(root, M.rr(seed, k, 53, 0.1, 0.2), Vector3(mx, LEDGE_Y + 0.04, mz), "cesped", Vector3(1.5, 0.45, 1.2), 8)
		else:
			M.box_mm(root, Vector3(LEDGE_X0, LEDGE_Y - 0.05, LEDGE_BACK), Vector3(LEDGE_X1, LEDGE_Y + 0.04, BULGE_Z - 0.05), "maniqui_oscuro")
	# ---- la otra orilla (pared B) y la olla del fondo (la cascada baja por una escotadura)
	M.box_mm(rock, Vector3(-40, BOTTOM - 2, GORGE + 1.6), Vector3(HEAD_X + 1, TOP_B, GORGE + 8), "carbon")
	occ.append(M.aabb_mm(Vector3(-40, BOTTOM - 2, GORGE), Vector3(HEAD_X, TOP_B, GORGE + 8)))
	_cliff(rock, seed + 4, "z", GORGE, -1.0, -40.0, HEAD_X, BOTTOM - 1.0, TOP_B, 0.6, Vector2(3.0, 6.0), Vector2(2.5, 5.5), [], true, 3.0)
	M.box_mm(root, Vector3(-40, TOP_B - 0.3, GORGE + 0.3), Vector3(HEAD_X + 8, TOP_B, GORGE + 20), "tierra")
	M.box_mm(root, Vector3(-40, TOP_B, GORGE + 2.5), Vector3(HEAD_X + 8, TOP_B + 0.05, GORGE + 20), "cesped")
	occ.append(M.aabb_mm(Vector3(-40, TOP_B - 0.3, GORGE), Vector3(HEAD_X + 8, TOP_B, GORGE + 20)))
	var head_top := TOP_A + 2.5
	M.box_mm(rock, Vector3(HEAD_X + 1.6, BOTTOM - 2, -8), Vector3(HEAD_X + 8, head_top, GORGE + 8), "carbon")
	occ.append(M.aabb_mm(Vector3(HEAD_X, BOTTOM - 2, -8), Vector3(HEAD_X + 8, head_top, GORGE + 8)))
	_cliff(rock, seed + 5, "x", HEAD_X, -1.0, -8.0, GORGE + 8.0, BOTTOM - 1.0, head_top, 0.6, Vector2(2.6, 4.5), Vector2(2.5, 5.5), [[FALL_Z0 - 0.3, BOTTOM - 2.0, FALL_Z1 + 0.3, head_top + 2.0]], true, 3.0)
	_tint(rock, Vector3(2.0, head_top - BOTTOM, FALL_Z1 - FALL_Z0 + 0.6), Vector3(HEAD_X + 1.6, (head_top + BOTTOM) / 2.0, (FALL_Z0 + FALL_Z1) / 2.0), _shade(seed, 4, 4, 0.5))
	# espolón de roca entre el final del sendero y la olla: tapa el pie de la cascada desde el sendero
	_cliff(rock, seed + 7, "x", HEAD_X - 4.0, -1.0, 0.0, FALL_Z0 + 1.2, BOTTOM - 1.0, -6.0, 0.4, Vector2(1.5, 2.5), Vector2(2.5, 5.0), [], true, 2.0)
	_tint(rock, Vector3(2.4, 0.5, FALL_Z0 + 1.2), Vector3(HEAD_X - 2.8, -6.2, (FALL_Z0 + 1.2) / 2.0), _shade(seed, 7, 7, 0.75), Vector3(0, 0, -6))
	M.box_mm(rock, Vector3(HEAD_X - 4.0, BOTTOM - 2, -0.5), Vector3(HEAD_X - 1.2, -6.4, FALL_Z0 + 1.2), "carbon")
	occ.append(M.aabb_mm(Vector3(HEAD_X - 4.0, BOTTOM - 2, -0.5), Vector3(HEAD_X - 1.2, -6.0, FALL_Z0 + 1.2)))
	# rimas: pinos contra el cielo y matas en los rellanos
	for k in 10:
		var px := -30.0 + k * 4.4 + M.rr(seed, k, 61, -1.0, 1.0)
		if px > -13.0 and px < 10.0: continue   # el claro desde donde se fotografía la pared
		_pine(root, Vector3(px, TOP_B, GORGE + 2.0 + M.rr(seed, k, 62, 0.0, 3.0)), M.rr(seed, k, 63, 4.0, 7.0))
	for k in 9:
		_pine(root, Vector3(-30.0 + k * 4.8 + M.rr(seed, k, 64, -1.0, 1.0), TOP_A, -1.8 - M.rr(seed, k, 65, 0.0, 4.0)), M.rr(seed, k, 66, 4.0, 7.5))
	for k in 6:
		_pine(root, Vector3(HEAD_X + 2.5 + M.rr(seed, k, 67, 0.0, 4.0), head_top, -4.0 + k * 3.0 + (3.4 if k >= 3 else 0.0)), M.rr(seed, k, 68, 4.0, 7.0))
	for k in 12:
		_bush(root, Vector3(M.rr(seed, k, 69, -30.0, -8.0), M.rr(seed, k, 70, -18.0, TOP_B - 1.0), GORGE - 0.15), M.rr(seed, k, 71, 0.3, 0.6))
	# ---- la cascada: tramos de bordes desparejos que se separan de la roca al caer; hilos claros; la olla de espuma
	var water := Node3D.new(); water.name = "cascada"; root.add_child(water)
	var lip := head_top - 1.0
	var y := lip
	var q := 0
	while y > BOTTOM + 0.1 and q < 30:
		var hh := minf(M.rr(seed, q, 70, 7.0, 12.0), y - BOTTOM)
		var dx := 0.025 * (lip - y)
		var z0 := FALL_Z0 + M.rr(seed, q, 71, -0.15, 0.1) - 0.012 * (lip - y)
		var z1 := FALL_Z1 + M.rr(seed, q, 72, -0.1, 0.15) + 0.012 * (lip - y)
		M.box_mm(water, Vector3(HEAD_X - 0.9 - dx, y - hh - 0.05, z0), Vector3(HEAD_X + 0.2 - dx, y, z1), "papel")
		y -= hh
		q += 1
	occ.append(M.aabb_mm(Vector3(HEAD_X - 2.0, BOTTOM, FALL_Z0), Vector3(HEAD_X + 0.2, lip, FALL_Z1)))
	M.box_mm(water, Vector3(HEAD_X - 1.1, lip - 0.3, FALL_Z0 - 0.3), Vector3(HEAD_X + 2.5, lip + 0.15, FALL_Z1 + 0.3), "vela")   # labio del salto
	for k in 7:
		var c := Vector3(HEAD_X - 2.6 - k * 1.7 + M.rr(seed, k, 81, -0.5, 0.5), BOTTOM + 1.2 + k * 1.5, (FALL_Z0 + FALL_Z1) * 0.5 + M.rr(seed, k, 83, -2.5, 1.0))
		M.sphere(water, 4.4 - k * 0.45, c, "vela", Vector3(1.5, 0.5, 1.3), 16)
	# el río en el fondo, blanco junto al salto
	M.box_mm(root, Vector3(-40, BOTTOM - 0.6, PATH_W - 1.0), Vector3(HEAD_X, BOTTOM, GORGE + 1.0), "agua")
	M.box_mm(root, Vector3(HEAD_X - 12.0, BOTTOM - 0.5, 1.0), Vector3(HEAD_X, BOTTOM + 0.05, GORGE - 1.0), "vela")
	# ---- lo que quedó del suceso (FINA y Journal; la foto es un recuerdo de turista)
	if people:
		var bt := Node3D.new(); bt.name = "baston"; root.add_child(bt)
		M.rod_ab(bt, 0.017, STICK_BASE, STICK_TOP, "madera_clara")
		M.cyl(bt, 0.0, 0.02, 0.1, STICK_BASE + Vector3(0, -0.01, 0.0), "hierro", Vector3(7, 0, 0), 6)
		M.torus(bt, 0.016, 0.026, STICK_TOP.lerp(STICK_BASE, 0.12), "cuero", Vector3(80, 0, 0))
		occ.append(M.aabb_mm(Vector3(1.8, 0.0, 0.04), Vector3(2.12, 1.45, 0.66)))
	if variant == "journal":
		var mk := Node3D.new(); mk.name = "marca"; root.add_child(mk)
		M.box(mk, Vector3(0.48, 0.045, 0.014), MARK + Vector3(0, 0, 0.006), "papel_viejo", Vector3(0, 0, -11))
		M.box(mk, Vector3(0.27, 0.024, 0.012), MARK + Vector3(0.06, -0.07, 0.005), "papel_viejo", Vector3(0, 0, -9))
		M.box(mk, Vector3(0.12, 0.02, 0.01), MARK + Vector3(-0.15, 0.07, 0.004), "yeso", Vector3(0, 0, -14))
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# reichenbach_saliente(variant): el saliente que vuela sobre el sendero (Journal y foto). Prop aparte para que tape la
# cornisa desde el sendero también para la tijera (rect_clip no cuenta los oclusores del propio prop del nodo).
static func build_reichenbach_saliente(p: Dictionary) -> Node3D:
	var variant := M.ps(p, "variant", "journal")
	var seed := M.seed_of(p, "rb_sal")
	var root := M.root("saliente_" + variant)
	var occ: Array = []
	# cuerpo: tres hiladas que vuelan cada vez más (de abajo hacia arriba)
	var rows := [[BULGE_Y0, BULGE_Y0 + 0.7, 0.45], [BULGE_Y0 + 0.7, BULGE_Y0 + 1.4, 0.8], [BULGE_Y0 + 1.4, LEDGE_Y, BULGE_Z]]
	for r in rows.size():
		var y0: float = rows[r][0]; var y1: float = rows[r][1]; var zf: float = rows[r][2]
		var x := BX0 + 0.3 * r
		var i := 0
		while x < BX1 - 0.3 * r - 0.05 and i < 60:
			var w := minf(M.rr(seed, i, r, 1.0, 2.4), BX1 - 0.3 * r - x)
			var zz := zf + M.rr(seed, i, r + 7, -0.08, 0.04)
			var mi := M.box_mm(root, Vector3(x, y0, -0.3), Vector3(x + w, y1 + 0.02, zz), "roca")
			mi.material_override = _shade(seed, i, r + 3, M.rr(seed, i, r + 5, 0.85, 1.05))
			x += w
			i += 1
		occ.append(M.aabb_mm(Vector3(BX0 + 0.3 * r, y0, -0.3), Vector3(BX1 - 0.3 * r, y1, zf)))
	# extremos que se funden con la pared
	for sx in [BX0, BX1]:
		var a := Vector3(sx - 0.6, BULGE_Y0 + 0.2, -0.3)
		var b := Vector3(sx + 0.6, LEDGE_Y + 0.6, 0.5)
		M.box_mm(root, a, b, "roca").material_override = _shade(seed, 9, 9, 0.9)
		occ.append(M.aabb_mm(a, b))
	root.set_meta("occ", occ)
	return root
