# world/props/l2.gd — W2-PLACES-A. Props propios de L2: Sala de Lectura del British Museum (cúpula, estanterías en
# tres pisos con galerías, mesas radiales, anillos del catálogo, mostrador con canastilla, tarima del superintendente)
# y Sala de Periódicos. Contrato: docs/ARCHITECTURE.md §7.2 / §7.3: static func build_<fn>(p) -> Node3D con meta "occ"
# (AABB o Transform3D locales). Origen = centro de la sala (piso, y = 0) salvo que se diga otra cosa; frente +Z.
# Ángulos en grados sobre el plano XZ: posición = (cos a, 0, sin a) · r (a = 90° → +Z, la entrada).
# Determinista (Materials.rnd). MultiMesh para todo lo repetido (lomos, sillas, balaustres).
extends RefCounted

const M = preload("res://world/materials.gd")
const MQ = preload("res://world/characters/mannequin.gd")
const A = preload("res://world/props/architecture.gd")

static func _spine(seed: int, i: int) -> Color:
	var pal := [Color("5a3a2a"), Color("6a2e26"), Color("3e4a3c"), Color("2f3440"), Color("7a6448"), Color("4a4036"),
		Color("8a7050"), Color("2c2a2c"), Color("a08a60"), Color("5e4e3c"), Color("b8a888"), Color("3a2a20")]
	var c: Color = pal[int(M.rnd(seed, i, 99) * pal.size()) % pal.size()]
	var f := 0.8 + 0.4 * M.rnd(seed, i, 98)
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

# base que lleva +X a la dirección radial `a` y +Z a la tangente (−sin a, cos a): un objeto «a lo largo del radio»
static func radial_basis(a_deg: float) -> Basis:
	var a := deg_to_rad(a_deg)
	var u := Vector3(cos(a), 0, sin(a))
	var v := Vector3(-sin(a), 0, cos(a))
	return Basis(u, Vector3.UP, v)

# base que lleva +Z a mirar hacia el centro desde el ángulo `a` (muros, estantes del perímetro); +X = tangente
static func facing_center(a_deg: float) -> Basis:
	var a := deg_to_rad(a_deg)
	var z := Vector3(-cos(a), 0, -sin(a))
	var x := Vector3.UP.cross(z).normalized()
	return Basis(x, Vector3.UP, z)

static func polar(a_deg: float, r: float, y := 0.0) -> Vector3:
	var a := deg_to_rad(a_deg)
	return Vector3(cos(a) * r, y, sin(a) * r)

static func _in_gap(a_deg: float, gaps: Array, half_w_deg: float) -> bool:
	for g in gaps:
		var d := fposmod(a_deg - float(g) + 180.0, 360.0) - 180.0
		if absf(d) < half_w_deg: return true
	return false

# ======================================================================================
# reading_room: cáscara de la Sala de Lectura. Piso circular, estanterías en tres pisos con dos galerías de hierro,
# cornisa, cúpula (architecture.dome) y vanos de puerta con vestíbulo. Extras: r (21,3), tier_h (2,9), segs (48),
# doors: [{a, w, h, clock, vestibule (fondo), open_end}], dome (bool), ribs, drum, seed.
static func build_reading_room(p: Dictionary) -> Node3D:
	var root := M.root("reading_room")
	var R := M.pf(p, "r", 21.3)
	var th := M.pf(p, "tier_h", 2.9)
	var tiers := M.pi_(p, "tiers", 3)
	var segs := M.pi_(p, "segs", 48)
	var seed := M.seed_of(p, "rr")
	var doors: Array = p.get("doors", [{"a": 90.0, "w": 2.4, "h": 3.4, "clock": true}])
	var top := th * tiers
	# piso: entablonado y dos anillos de guarda
	M.cyl(root, R + 0.6, R + 0.6, 0.1, Vector3(0, -0.05, 0), "suelo_tablas", Vector3.ZERO, 96)
	M.torus(root, 6.35, 6.45, Vector3(0, 0.002, 0), "madera_negra", Vector3.ZERO, Vector3(1, 0.05, 1))
	M.torus(root, R - 2.3, R - 2.2, Vector3(0, 0.002, 0), "madera_negra", Vector3.ZERO, Vector3(1, 0.05, 1))
	var occ: Array = [M.aabb_mm(Vector3(-R - 0.6, -0.1, -R - 0.6), Vector3(R + 0.6, 0.0, R + 0.6))]
	var cw := TAU * R / segs
	var spines: Array = []; var scol: Array = []
	var shelves: Array = []; var uprights: Array = []
	var gal_floor: Array = []; var balusters: Array = []; var backs: Array = []
	var dw_deg_list: Array = []
	for d in doors:
		dw_deg_list.append(rad_to_deg(float(d.get("w", 2.4)) / R) * 0.5 + rad_to_deg(cw / R) * 0.5)
	for i in segs:
		var a := 360.0 * (i + 0.5) / segs
		var door_h := 0.0
		for k in doors.size():
			var dd := fposmod(a - float(doors[k].get("a", 90.0)) + 180.0, 360.0) - 180.0
			if absf(dd) < float(dw_deg_list[k]): door_h = float(doors[k].get("h", 3.4)) + 0.2
		var xf := Transform3D(facing_center(a), polar(a, R + 0.25))
		# fondo y pilastras
		var y0 := door_h
		backs.append(xf * M.xf_box(Vector3(cw + 0.02, top - y0, 0.06), Vector3(0, y0 + (top - y0) / 2, -0.22)))
		uprights.append(xf * M.xf_box(Vector3(0.08, top - y0, 0.48), Vector3(-cw / 2, y0 + (top - y0) / 2, 0)))
		occ.append(xf * M.xf_box(Vector3(cw + 0.02, top - y0, 0.5), Vector3(0, y0 + (top - y0) / 2, 0)))
		for t in tiers:
			var ty := t * th
			if ty + th <= y0 + 0.01: continue
			var sh_n := 5
			for s in sh_n:
				var sy := ty + 0.12 + s * (th - 0.2) / sh_n
				if sy < y0: continue
				shelves.append(xf * M.xf_box(Vector3(cw, 0.03, 0.42), Vector3(0, sy, 0.0)))
				var x := -cw / 2 + 0.05
				var k := 0
				var hmax := (th - 0.2) / sh_n - 0.07
				while x < cw / 2 - 0.08 and k < 40:
					var bw := M.rr(seed, i * 1000 + t * 100 + s * 20 + k, 1, 0.06, 0.18)
					if x + bw > cw / 2 - 0.05: bw = cw / 2 - 0.05 - x
					if bw < 0.03: break
					var bh := hmax * M.rr(seed, i * 1000 + t * 100 + s * 20 + k, 2, 0.72, 1.0)
					spines.append(xf * M.xf_box(Vector3(bw - 0.006, bh, 0.3), Vector3(x + bw / 2, sy + 0.015 + bh / 2, 0.02)))
					scol.append(_spine(seed, i * 977 + t * 131 + s * 17 + k))
					x += bw
					k += 1
			# galería (piso volado y baranda) sobre los pisos 1 y 2
			if t > 0:
				gal_floor.append(xf * M.xf_box(Vector3(cw + 0.02, 0.1, 0.95), Vector3(0, ty - 0.05, 0.62)))
				gal_floor.append(xf * M.xf_box(Vector3(cw + 0.02, 0.06, 0.05), Vector3(0, ty + 0.95, 1.08)))
				gal_floor.append(xf * M.xf_box(Vector3(cw + 0.02, 0.04, 0.04), Vector3(0, ty + 0.12, 1.08)))
				var nb := int(cw / 0.16)
				for b in nb:
					balusters.append(xf * M.xf_box(Vector3(0.022, 0.82, 0.022), Vector3(-cw / 2 + cw * (b + 0.5) / nb, ty + 0.53, 1.08)))
		# cornisa sobre el tercer piso
		gal_floor.append(xf * M.xf_box(Vector3(cw + 0.04, 0.32, 0.8), Vector3(0, top + 0.16, 0.25)))
	M.multi_boxes(root, backs, [], "madera_negra")
	M.multi_boxes(root, spines, scol)
	M.multi_boxes(root, shelves, [], "madera_oscura")
	M.multi_boxes(root, uprights, [], "madera_oscura")
	M.multi_boxes(root, gal_floor, [], "hierro")
	M.multi_boxes(root, balusters, [], "hierro")
	# vanos de puerta: dintel, jambas, vestíbulo claro y hojas de cuero abiertas; reloj sobre la entrada principal
	for d in doors:
		var a := float(d.get("a", 90.0))
		var dw := float(d.get("w", 2.4)); var dh := float(d.get("h", 3.4))
		var dn := Node3D.new(); dn.name = "door_%d" % int(a); dn.transform = Transform3D(facing_center(a), polar(a, R)); root.add_child(dn)
		M.box(dn, Vector3(dw + 0.5, 0.4, 0.6), Vector3(0, dh + 0.2, 0.0), "madera_negra")
		for sx: float in [-1.0, 1.0]:
			M.box(dn, Vector3(0.28, dh, 0.62), Vector3(sx * (dw / 2 + 0.14), dh / 2, 0.0), "madera_negra")
			# hoja de cuero tachonado, abierta hacia adentro
			var hg := Node3D.new(); hg.position = Vector3(sx * dw / 2, 0, 0.3); hg.rotation_degrees = Vector3(0, -sx * 80.0, 0); dn.add_child(hg)
			M.box(hg, Vector3(dw / 2 - 0.04, dh - 0.1, 0.06), Vector3(-sx * (dw / 4), (dh - 0.1) / 2, 0), "cuero")
			M.box(hg, Vector3(0.06, 0.3, 0.07), Vector3(-sx * (dw / 2 - 0.12), 1.0, 0.0), "laton")
		var vd := float(d.get("vestibule", 5.0))
		var vb := Node3D.new(); vb.position = Vector3(0, 0, -0.3); dn.add_child(vb)
		M.box(vb, Vector3(dw + 1.2, 0.08, vd), Vector3(0, -0.04, -vd / 2), "piedra_portland")
		M.box(vb, Vector3(dw + 1.2, 0.08, vd), Vector3(0, dh + 1.2, -vd / 2), "yeso")
		for sx: float in [-1.0, 1.0]:
			M.box(vb, Vector3(0.1, dh + 1.2, vd), Vector3(sx * (dw / 2 + 0.6), (dh + 1.2) / 2, -vd / 2), "estuco")
		if not bool(d.get("open_end", false)):
			M.box(vb, Vector3(dw + 1.2, dh + 1.2, 0.1), Vector3(0, (dh + 1.2) / 2, -vd), "estuco")
		var lamp := Node3D.new(); lamp.position = Vector3(0, dh + 0.7, -vd * 0.5); vb.add_child(lamp)
		M.sphere(lamp, 0.16, Vector3.ZERO, "vela", Vector3(1, 1, 1), 14)
		lamp.set_meta("light", {"kind": "electrica", "energy": 1.0, "range": 7.0})
		if bool(d.get("clock", false)):
			var ck := Node3D.new(); ck.position = Vector3(0, dh + 1.1, 0.33); dn.add_child(ck)
			M.cyl(ck, 0.52, 0.52, 0.08, Vector3.ZERO, "madera_negra", Vector3(90, 0, 0), 32)
			M.cyl(ck, 0.45, 0.45, 0.085, Vector3(0, 0, 0.005), "vela", Vector3(90, 0, 0), 32)
			M.beam_ab(ck, Vector3(0, 0, 0.05), Vector3(-0.17, 0.2, 0.05), 0.035, 0.01, "tinta")
			M.beam_ab(ck, Vector3(0, 0, 0.055), Vector3(0.0, 0.36, 0.055), 0.025, 0.01, "tinta")
			for k in 12:
				var ka := TAU * k / 12.0
				M.box(ck, Vector3(0.025, 0.07, 0.01), Vector3(sin(ka) * 0.38, cos(ka) * 0.38, 0.05), "tinta", Vector3(0, 0, -rad_to_deg(ka)))
		occ.append(dn.transform * M.xf_box(Vector3(dw + 0.5, 0.4, 0.6), Vector3(0, dh + 0.2, 0)))
	# cúpula sobre la cornisa
	if M.pb(p, "dome", true):
		var dm := A.build_dome({"r": R, "ribs": M.pi_(p, "ribs", 20), "drum": M.pf(p, "drum", 6.4)})
		dm.position = Vector3(0, top + 0.32, 0)
		root.add_child(dm)
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# radial_desks: mesas radiales de lectura (dobles, con mampara central, repisa alta, atriles plegables, tinteros,
# secantes, chapas con el número de puesto, ganchos para el sombrero) y sillas. Extras: n (16), a0 (11,25), r0 (6,6),
# r1 (18,6), spacing (1,1), skip [ángulos], seed. Puesto k de la mesa i, lado s (±1): x local = r0 + 0,6 + k·spacing.
static func build_radial_desks(p: Dictionary) -> Node3D:
	var root := M.root("radial_desks")
	var n := M.pi_(p, "n", 16)
	var a0 := M.pf(p, "a0", 11.25)
	var r0 := M.pf(p, "r0", 6.6); var r1 := M.pf(p, "r1", 18.6)
	var sp := M.pf(p, "spacing", 1.1)
	var skip: Array = p.get("skip", [])
	var seed := M.seed_of(p, "rd")
	var L := r1 - r0
	var dh := 0.74
	var wood: Array = []; var dark: Array = []; var leather: Array = []; var paper: Array = []; var brass: Array = []; var glass: Array = []
	var occ: Array = []
	var seats := int((L - 0.6) / sp)
	for i in n:
		var a := a0 + 360.0 * i / n
		var sk := false
		for s0 in skip:
			if absf(fposmod(a - float(s0) + 180.0, 360.0) - 180.0) < 1.0: sk = true
		if sk: continue
		var B := radial_basis(a)
		var X := Transform3D(B, Vector3.ZERO)
		var cx := r0 + L / 2
		# oclusores: cuerpo de la mesa (hasta la tapa) y mampara central; lo que está sobre la tapa se ve
		occ.append(X * M.xf_box(Vector3(L, dh + 0.03, 1.42), Vector3(cx, (dh + 0.03) / 2, 0)))
		occ.append(X * M.xf_box(Vector3(L, 0.5, 0.12), Vector3(cx, dh + 0.27, 0)))
		for s: float in [-1.0, 1.0]:
			wood.append(X * M.xf_box(Vector3(L, 0.045, 0.66), Vector3(cx, dh, s * 0.38)))
			leather.append(X * M.xf_box(Vector3(L - 0.08, 0.006, 0.56), Vector3(cx, dh + 0.025, s * 0.4)))
			dark.append(X * M.xf_box(Vector3(L, 0.12, 0.03), Vector3(cx, dh - 0.07, s * 0.7)))
		# mampara central, repisa alta y cabezales
		dark.append(X * M.xf_box(Vector3(L, 0.46, 0.07), Vector3(cx, dh + 0.25, 0)))
		wood.append(X * M.xf_box(Vector3(L + 0.04, 0.04, 0.26), Vector3(cx, dh + 0.5, 0)))
		for e: float in [r0, r1]:
			dark.append(X * M.xf_box(Vector3(0.08, dh + 0.5, 1.38), Vector3(e, (dh + 0.5) / 2, 0)))
		var npd := int(L / 1.8)
		for k in npd + 1:
			var px := r0 + 0.25 + (L - 0.5) * k / maxf(npd, 1)
			dark.append(X * M.xf_box(Vector3(0.07, dh - 0.05, 1.2), Vector3(px, (dh - 0.05) / 2, 0)))
		for k in seats:
			var x := r0 + 0.6 + k * sp
			for s: float in [-1.0, 1.0]:
				var folded := M.rnd(seed, i * 100 + k, int(s + 2)) < 0.5
				# atril plegable (alzado o plegado), tintero, secante, chapa con número, gancho
				if folded:
					wood.append(X * M.xf_box(Vector3(0.38, 0.018, 0.12), Vector3(x, dh + 0.04, s * 0.22)))
				else:
					wood.append(X * Transform3D(Basis.from_euler(Vector3(s * deg_to_rad(-38.0), 0, 0)) * Basis.from_scale(Vector3(0.38, 0.018, 0.26)), Vector3(x, dh + 0.12, s * 0.28)))
				glass.append(X * M.xf_box(Vector3(0.05, 0.04, 0.05), Vector3(x + 0.33, dh + 0.045, s * 0.12)))
				paper.append(X * M.xf_box(Vector3(0.36, 0.004, 0.26), Vector3(x - 0.05, dh + 0.03, s * 0.46)))
				paper.append(X * M.xf_box(Vector3(0.05, 0.035, 0.004), Vector3(x, dh + 0.42, s * 0.037)))
				brass.append(X * M.xf_box(Vector3(0.012, 0.012, 0.08), Vector3(x + 0.42, dh + 0.42, s * 0.07)))
				# silla de respaldo curvo (simplificada): asiento, respaldo, patas
				var cz := s * 1.02
				var cb := Basis(Vector3.UP, PI if s > 0 else 0.0)
				var C := X * Transform3D(cb, Vector3(x, 0, cz))
				wood.append(C * M.xf_box(Vector3(0.44, 0.045, 0.42), Vector3(0, 0.46, 0)))
				leather.append(C * M.xf_box(Vector3(0.4, 0.03, 0.38), Vector3(0, 0.5, 0.0)))
				wood.append(C * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-10.0), 0, 0)) * Basis.from_scale(Vector3(0.42, 0.42, 0.04)), Vector3(0, 0.74, -0.2)))
				for lx: float in [-0.18, 0.18]:
					for lz: float in [-0.17, 0.17]:
						wood.append(C * M.xf_box(Vector3(0.035, 0.46, 0.035), Vector3(lx, 0.23, lz)))
	M.multi_boxes(root, wood, [], "madera_oscura")
	M.multi_boxes(root, dark, [], "madera_negra")
	M.multi_boxes(root, leather, [], "cuero")
	M.multi_boxes(root, paper, [], "papel")
	M.multi_boxes(root, brass, [], "laton")
	M.multi_boxes(root, glass, [], "tinta")
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# center: tarima del superintendente con baranda y escritorio, mostrador circular (donde se dejan las papeletas y se
# devuelven los libros) y dos anillos de catálogo con atriles y folios iguales. Extras: gaps (ángulos de los pasos entre
# casilleros, def 0/90/180/270), gap_w (ancho del paso, m), gate (ángulo de la puerta del mostrador),
# slips: [ángulos con papeletas sobre un anillo], slips_r (radio, def 5,17 = anillo exterior), seed.
static func build_center(p: Dictionary) -> Node3D:
	var root := M.root("center")
	var seed := M.seed_of(p, "ce")
	var gaps: Array = p.get("gaps", [0.0, 90.0, 180.0, 270.0])
	var gap_w := M.pf(p, "gap_w", 1.2)
	var gate := M.pf(p, "gate", 270.0)
	var occ: Array = []
	# tarima
	M.cyl(root, 1.45, 1.5, 0.5, Vector3(0, 0.25, 0), "madera_oscura", Vector3.ZERO, 40)
	M.cyl(root, 1.46, 1.46, 0.03, Vector3(0, 0.51, 0), "cuero", Vector3.ZERO, 40)
	var posts: Array = []
	for k in 36:
		var a := 360.0 * k / 36.0
		if absf(fposmod(a - gate + 180.0, 360.0) - 180.0) < 12.0: continue
		posts.append(Transform3D(Basis.from_scale(Vector3(0.03, 0.85, 0.03)), polar(a, 1.38, 0.5 + 0.425)))
	M.multi_boxes(root, posts, [], "laton")
	M.torus(root, 1.36, 1.4, Vector3(0, 1.36, 0), "laton")
	var desk := Node3D.new(); desk.position = Vector3(0, 0.52, -0.2); root.add_child(desk)
	M.box(desk, Vector3(1.3, 0.76, 0.7), Vector3(0, 0.38, 0), "madera_oscura")
	M.box(desk, Vector3(1.34, 0.04, 0.74), Vector3(0, 0.78, 0), "cuero")
	M.box(desk, Vector3(1.3, 0.4, 0.3), Vector3(0, 0.98, -0.25), "madera_negra")
	var stk := Node3D.new(); stk.position = Vector3(0.3, 0.8, 0.05); desk.add_child(stk)
	M.box(stk, Vector3(0.3, 0.06, 0.22), Vector3(0, 0.03, 0), "papel")
	occ.append(M.aabb_mm(Vector3(-1.5, 0, -1.5), Vector3(1.5, 0.52, 1.5)))
	occ.append(M.aabb_mm(Vector3(-0.67, 0.52, -0.57), Vector3(0.67, 1.5, 0.17)))
	# mostrador circular
	var mr0 := 1.75; var mr1 := 2.3; var mh := 1.08
	var nseg := 40
	var top: Array = []; var panel: Array = []; var books: Array = []; var bcol: Array = []
	for k in nseg:
		var a := 360.0 * (k + 0.5) / nseg
		if absf(fposmod(a - gate + 180.0, 360.0) - 180.0) < 6.0: continue
		var B := facing_center(a)
		var chord := TAU * mr1 / nseg + 0.02
		var X := Transform3D(B, polar(a, (mr0 + mr1) / 2))
		top.append(X * M.xf_box(Vector3(chord + 0.02, 0.05, mr1 - mr0 + 0.08), Vector3(0, mh - 0.025, 0)))
		panel.append(X * M.xf_box(Vector3(chord, mh - 0.05, 0.05), Vector3(0, (mh - 0.05) / 2, -(mr1 - mr0) / 2)))
		panel.append(X * M.xf_box(Vector3(chord * 0.86, mh * 0.6, 0.02), Vector3(0, mh * 0.45, -(mr1 - mr0) / 2 - 0.03)))
		panel.append(X * M.xf_box(Vector3(chord, 0.04, mr1 - mr0 - 0.1), Vector3(0, 0.45, 0)))
		occ.append(X * M.xf_box(Vector3(chord, mh, mr1 - mr0), Vector3(0, mh / 2, 0)))
		# libros devueltos en la repisa interior
		if M.rnd(seed, k, 1) < 0.55:
			var yy := 0.47
			for b in 1 + int(M.rnd(seed, k, 2) * 3):
				var bt := M.rr(seed, k * 7 + b, 3, 0.03, 0.06)
				books.append(X * M.xf_box(Vector3(0.24, bt, 0.17), Vector3(M.rr(seed, k, 4, -0.08, 0.08), yy + bt / 2, 0.05), Vector3(0, M.rr(seed, k * 7 + b, 5, -20, 20), 0)))
				bcol.append(_spine(seed, k * 13 + b))
				yy += bt
	M.multi_boxes(root, top, [], "cuero")
	M.multi_boxes(root, panel, [], "madera_oscura")
	if not books.is_empty(): M.multi_boxes(root, books, bcol)
	# anillos de catálogo (casilleros bajos con atril inclinado y folios iguales)
	var rings := [[3.3, 3.95], [4.85, 5.5]]
	var cases: Array = []; var tops: Array = []; var vols: Array = []; var vcol: Array = []; var labels: Array = []; var folios: Array = []
	for ri in rings.size():
		var ra: float = rings[ri][0]; var rb: float = rings[ri][1]
		var rm := (ra + rb) / 2
		var gap_half := rad_to_deg(gap_w * 0.5 / rm)
		var step := rad_to_deg(0.9 / rm)
		var a := 0.0
		var k := 0
		while a < 360.0 and k < 400:
			var ac := a + step / 2
			if not _in_gap(ac, gaps, gap_half + step * 0.5):
				var B := facing_center(ac)
				var X := Transform3D(B, polar(ac, rm))
				var chord := deg_to_rad(step) * rm + 0.01
				cases.append(X * M.xf_box(Vector3(chord, 0.96, rb - ra - 0.08), Vector3(0, 0.48, 0)))
				for s: float in [-1.0, 1.0]:
					tops.append(X * Transform3D(Basis.from_euler(Vector3(s * deg_to_rad(12.0), 0, 0)) * Basis.from_scale(Vector3(chord + 0.01, 0.035, (rb - ra) / 2 + 0.03)), Vector3(0, 1.02, s * (rb - ra) / 4)))
					# folios en dos estantes por cara
					for sh in 2:
						var vx := -chord / 2 + 0.04
						var vi := 0
						while vx < chord / 2 - 0.06 and vi < 20:
							var vt := 0.07 + 0.015 * M.rnd(seed, ri * 9000 + k * 40 + vi, sh)
							vols.append(X * M.xf_box(Vector3(vt - 0.006, 0.34, 0.22), Vector3(vx + vt / 2, 0.1 + sh * 0.42 + 0.17, s * ((rb - ra) / 2 - 0.13))))
							var f := 0.82 + 0.25 * M.rnd(seed, ri * 9000 + k * 40 + vi, sh + 5)
							vcol.append(Color(0.24 * f, 0.17 * f, 0.12 * f))
							labels.append(X * M.xf_box(Vector3(0.035, 0.05, 0.004), Vector3(vx + vt / 2, 0.1 + sh * 0.42 + 0.25, s * ((rb - ra) / 2 - 0.018))))
							vx += vt
							vi += 1
					if M.rnd(seed, ri * 50 + k, 7) < 0.4:
						# un tomo del catálogo abierto sobre el atril
						folios.append(X * Transform3D(Basis.from_euler(Vector3(s * deg_to_rad(12.0), M.rr(seed, k, ri + 9, -0.2, 0.2), 0)) * Basis.from_scale(Vector3(0.5, 0.03, 0.34)), Vector3(0, 1.06, s * (rb - ra) / 4)))
				occ.append(X * M.xf_box(Vector3(chord, 1.1, rb - ra), Vector3(0, 0.55, 0)))
			a += step
			k += 1
	M.multi_boxes(root, cases, [], "madera_oscura")
	M.multi_boxes(root, tops, [], "madera_media")
	M.multi_boxes(root, vols, vcol)
	M.multi_boxes(root, labels, [], "papel")
	if not folios.is_empty(): M.multi_boxes(root, folios, [], "papel")
	# papeletas en blanco (blancas: libros; verdes: manuscritos) sobre el anillo exterior
	var slips_r := M.pf(p, "slips_r", 5.17)
	for sa in p.get("slips", []):
		var X2 := Transform3D(facing_center(float(sa)), polar(float(sa), slips_r))
		var g := Node3D.new(); g.transform = X2 * Transform3D(Basis.IDENTITY, Vector3(0, 1.06, 0.12)); g.rotation_degrees += Vector3(12, 0, 0); root.add_child(g)
		_slip_stacks(g, seed + int(float(sa) * 10))
	root.set_meta("occ", occ)
	return root

static func _slip_stacks(g: Node3D, seed: int) -> void:
	M.box(g, Vector3(0.36, 0.012, 0.14), Vector3(0, 0.006, 0), "madera_negra")
	for k in 2:
		var x := -0.08 + k * 0.17
		var n := 10 + int(M.rnd(seed, k, 1) * 10)
		for i in n:
			M.box(g, Vector3(0.11, 0.0018, 0.075), Vector3(x + M.rr(seed, k * 40 + i, 2, -0.004, 0.004), 0.013 + i * 0.002, M.rr(seed, k * 40 + i, 3, -0.004, 0.004)), "papel" if k == 0 else "pintura_verde")

# ======================================================================================
# slip_basket (canastilla del mostrador): cesto de mimbre bajo y ovalado, lleno de papeletas blancas y verdes.
static func build_slip_basket(p: Dictionary) -> Node3D:
	var root := M.root("slip_basket")
	var seed := M.seed_of(p, "sb")
	var c := M.cyl(root, 0.17, 0.14, 0.11, Vector3(0, 0.055, 0), "mimbre", Vector3.ZERO, 20)
	c.scale = Vector3(1.35, 1, 1)
	var ring := M.torus(root, 0.16, 0.18, Vector3(0, 0.11, 0), "madera_media")
	ring.scale = Vector3(1.35, 1, 1)
	for k in 5:
		M.torus(root, 0.15 + k * 0.004, 0.158 + k * 0.004, Vector3(0, 0.02 + k * 0.02, 0), "madera_media", Vector3.ZERO, Vector3(1.35, 0.6, 1))
	var xf: Array = []; var cc: Array = []
	for i in 22:
		var a := M.rnd(seed, i, 0) * TAU
		var rr := M.rnd(seed, i, 1) * 0.12
		xf.append(M.xf_box(Vector3(0.11, 0.002, 0.075), Vector3(cos(a) * rr * 1.3, 0.09 + i * 0.0025, sin(a) * rr), Vector3(M.rr(seed, i, 2, -15, 15), M.rr(seed, i, 3, 0, 180), M.rr(seed, i, 4, -15, 15))))
		cc.append(M.color("pintura_verde") if i % 5 == 3 else M.color("papel"))
	M.multi_boxes(root, xf, cc)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.24, 0, -0.18), Vector3(0.24, 0.16, 0.18))])
	return root

# ======================================================================================
# cotter_desk: lo que hay sobre el puesto del escribiente (sin él): resma de papel de cartas con el borde superior
# recortado, tiras sueltas, tijera, plumero y tintero. Origen = superficie de la mesa; frente +Z = hacia el lector.
static func build_cotter_desk(p: Dictionary) -> Node3D:
	var root := M.root("cotter_desk")
	var seed := M.seed_of(p, "cd")
	var xf: Array = []; var cc: Array = []
	for i in 30:
		xf.append(M.xf_box(Vector3(0.2, 0.0022, 0.244), Vector3(-0.06 + M.rr(seed, i, 0, -0.004, 0.004), 0.0011 + i * 0.0022, M.rr(seed, i, 1, -0.004, 0.004))))
		cc.append(M.color("papel") * Color(0.96 + 0.04 * M.rnd(seed, i, 2), 0.96, 0.92))
	M.multi_boxes(root, xf, cc)
	# tiras recortadas sueltas
	for i in 4:
		M.box(root, Vector3(0.19, 0.001, 0.011), Vector3(0.18 + M.rr(seed, i, 3, -0.03, 0.03), 0.001 + i * 0.001, -0.08 + i * 0.03), "papel", Vector3(0, M.rr(seed, i, 4, -30, 30), 0))
	# tijera abierta
	var sc := Node3D.new(); sc.position = Vector3(0.2, 0.004, 0.08); sc.rotation_degrees = Vector3(0, 35, 0); root.add_child(sc)
	for s: float in [-1.0, 1.0]:
		var gg := Node3D.new(); gg.rotation_degrees = Vector3(0, s * 14, 0); sc.add_child(gg)
		M.prism(gg, Vector3(0.012, 0.13, 0.002), Vector3(0, 0.002, -0.065), "hierro", Vector3(-90, 0, 0), 0.5)
		M.torus(gg, 0.011, 0.016, Vector3(s * 0.014, 0.003, 0.06), "hierro", Vector3.ZERO, Vector3(1, 1, 1.4))
	M.box(root, Vector3(0.05, 0.04, 0.05), Vector3(-0.27, 0.02, -0.08), "tinta")
	M.cyl(root, 0.004, 0.004, 0.17, Vector3(-0.25, 0.006, 0.06), "madera_negra", Vector3(0, 30, 90), 6)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.3, 0, -0.13), Vector3(0.3, 0.07, 0.13))])
	return root

# ======================================================================================
# seat_items: el puesto elegido: atril alzado con un libro abierto, secante nuevo y la chapa del número a la vista.
# Origen = superficie de la mesa; frente +Z = hacia el lector. Extras: number (texto de la chapa; "" = sin número).
static func build_seat_items(p: Dictionary) -> Node3D:
	var root := M.root("seat_items")
	var b := Node3D.new(); b.position = Vector3(0, 0.02, -0.05); b.rotation_degrees = Vector3(-35, 0, 0); root.add_child(b)
	M.box(b, Vector3(0.42, 0.3, 0.02), Vector3(0, 0.15, 0), "madera_oscura")
	M.box(b, Vector3(0.42, 0.03, 0.05), Vector3(0, 0.0, 0.025), "madera_oscura")
	for s: float in [-1.0, 1.0]:
		var pg := Node3D.new(); pg.position = Vector3(s * 0.095, 0.15, 0.016); pg.rotation_degrees = Vector3(0, -s * 6, 0); b.add_child(pg)
		M.box(pg, Vector3(0.18, 0.25, 0.012), Vector3.ZERO, "papel")
		for l in 9:
			M.box(pg, Vector3(0.13, 0.0035, 0.002), Vector3(0, 0.1 - l * 0.024, 0.007), "tinta")
	M.box(root, Vector3(0.36, 0.004, 0.26), Vector3(0.05, 0.002, 0.08), "papel")
	var num := M.ps(p, "number", "")
	var plate := Node3D.new(); plate.position = Vector3(0, 0.36, -0.36); root.add_child(plate)
	M.box(plate, Vector3(0.07, 0.045, 0.006), Vector3.ZERO, "laton")
	if num != "":
		M.label3d(plate, num, Vector3(0, 0, 0.004), 0.0006, 48, Color("1b1712"))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.22, 0, -0.2), Vector3(0.22, 0.2, 0.21))])
	return root

# ======================================================================================
# arc_lamps: lámparas eléctricas de arco (globos opalinos) colgadas de varillas largas (rod) o, con `wall` > 0, de brazos
# de hierro que salen del frente de la galería en el radio `wall`. Marca "light" = {kind: electrica} en cada globo.
# Extras: n (4), r (radio del globo), y (altura), a0 (ángulo del primero), rod (largo de la varilla), wall, energy, range.
static func build_arc_lamps(p: Dictionary) -> Node3D:
	var root := M.root("arc_lamps")
	var n := M.pi_(p, "n", 4)
	var r := M.pf(p, "r", 9.0); var y := M.pf(p, "y", 11.0)
	var a0 := M.pf(p, "a0", 45.0)
	var rod := M.pf(p, "rod", 12.0)
	var wall := M.pf(p, "wall", 0.0)
	for k in n:
		var a := a0 + 360.0 * k / n
		var c := polar(a, r, y)
		if wall > 0.0:
			# brazo de hierro desde el frente de la galería (radio `wall`) hasta el globo
			var top := polar(a, r, y + 0.55)
			M.rod_ab(root, 0.022, polar(a, wall, y + 0.75), top, "hierro")
			M.rod_ab(root, 0.014, polar(a, wall, y + 0.2), polar(a, (wall + r) * 0.5, y + 0.66), "hierro")
			M.rod(root, 0.012, 0.12, top + Vector3(0, -0.05, 0), "hierro")
		else:
			M.rod(root, 0.025, rod, c + Vector3(0, rod / 2 + 0.45, 0), "hierro")
		M.cyl(root, 0.12, 0.2, 0.18, c + Vector3(0, 0.4, 0), "hierro", Vector3.ZERO, 14)
		M.cyl(root, 0.06, 0.06, 0.25, c + Vector3(0, 0.22, 0), "laton", Vector3.ZERO, 10)
		M.sphere(root, 0.32, c, "vela", Vector3(1, 1.15, 1), 18)
		M.torus(root, 0.12, 0.17, c + Vector3(0, -0.33, 0), "hierro")
		var mk := Node3D.new(); mk.name = "globe_%d" % k; mk.position = c; root.add_child(mk)
		mk.set_meta("light", {"kind": "electrica", "energy": M.pf(p, "energy", 2.0), "range": M.pf(p, "range", 16.0)})
	root.set_meta("occ", [])
	return root

# ======================================================================================
# readers: lectores sentados en puestos de las mesas radiales (inclinados sobre el libro; uno escribe; sombreros en el
# gancho). Extras: seats: [[a_desk, r_local, s]], seed, desk (dict con dh). Las figuras no llevan rasgo de §7.4.
static func build_readers(p: Dictionary) -> Node3D:
	var root := M.root("readers")
	var seed := M.seed_of(p, "rdr")
	var kinds := [
		{"h": 1.76, "sh": 0.44, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "", "stoop": 18.0},
		{"h": 1.72, "sh": 0.42, "g": 0.15, "coat": "frock", "coat_mat": "tela_media", "arms": {"r": "front", "l": "forehead"}, "hat": "", "stoop": 22.0},
		{"h": 1.68, "sh": 0.4, "g": 0.13, "coat": "jacket", "coat_mat": "tela_media", "arms": {"r": "front", "l": "front"}, "hat": "", "stoop": 25.0},
		{"h": 1.62, "sh": 0.38, "g": 0.13, "coat": "dress", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "bonnet", "stoop": 12.0},
		{"h": 1.8, "sh": 0.46, "g": 0.15, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "", "stoop": 15.0, "mustache": "small"},
	]
	var seats: Array = p.get("seats", [])
	for i in seats.size():
		var st: Array = seats[i]
		var a := float(st[0]); var xr := float(st[1]); var s := float(st[2])
		var X := Transform3D(radial_basis(a), Vector3.ZERO)
		var cb := Basis(Vector3.UP, PI if s > 0 else 0.0)
		var spec: Dictionary = (kinds[int(M.rnd(seed, i, 1) * kinds.size()) % kinds.size()] as Dictionary).duplicate(true)
		spec["h"] = float(spec["h"]) * M.rr(seed, i, 2, 0.95, 1.04)
		var fig := Node3D.new(); fig.name = "reader_%d" % i
		MQ._body(fig, spec, "sentado", seed + i * 7)
		fig.transform = X * Transform3D(cb, Vector3(xr, 0, s * 1.06))
		root.add_child(fig)
		if M.rnd(seed, i, 3) < 0.5 and spec.get("coat", "") != "dress":
			# sombrero colgado del gancho de la repisa
			var hp := Node3D.new(); hp.transform = X * Transform3D(Basis.IDENTITY, Vector3(xr + 0.42, 1.08, s * 0.1)); root.add_child(hp)
			M.cyl(hp, 0.1, 0.095, 0.17 if M.rnd(seed, i, 4) < 0.5 else 0.08, Vector3(0, -0.05, 0), "fieltro", Vector3(90, 0, 0), 14)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# attendant: mozo de la sala con un carrito de libros (figura genérica de guardapolvo; no es personaje).
static func build_attendant(p: Dictionary) -> Node3D:
	var root := M.root("attendant")
	var seed := M.seed_of(p, "att")
	var fig := Node3D.new(); fig.name = "mozo"; root.add_child(fig)
	MQ._body(fig, {"h": 1.7, "sh": 0.42, "g": 0.14, "coat": "long", "coat_mat": "tela_media", "arms": {"r": "front", "l": "front"}, "hat": "flat_cap", "stoop": 8.0}, "de_pie", seed)
	var tr := Node3D.new(); tr.name = "trolley"; tr.position = Vector3(0, 0, 0.62); root.add_child(tr)
	M.box(tr, Vector3(0.55, 0.03, 0.8), Vector3(0, 0.75, 0.15), "madera_oscura")
	M.box(tr, Vector3(0.55, 0.03, 0.8), Vector3(0, 0.3, 0.15), "madera_oscura")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(tr, Vector3(0.03, 0.75, 0.03), Vector3(sx * 0.26, 0.375, 0.15 + sz * 0.38), "madera_negra")
			M.cyl(tr, 0.06, 0.06, 0.03, Vector3(sx * 0.26, 0.06, 0.15 + sz * 0.36), "hierro", Vector3(0, 0, 90), 12)
	M.rod_ab(tr, 0.015, Vector3(-0.27, 0.95, -0.25), Vector3(0.27, 0.95, -0.25), "laton")
	var xf: Array = []; var cc: Array = []
	for row in 2:
		var x := -0.24
		var i := 0
		while x < 0.22 and i < 20:
			var t := M.rr(seed, i, row, 0.03, 0.07)
			var bh := M.rr(seed, i, row + 3, 0.2, 0.3)
			xf.append(M.xf_box(Vector3(t - 0.003, bh, 0.2), Vector3(x + t / 2, 0.315 + row * 0.45 + bh / 2, 0.15 + (row - 0.5) * 0.3)))
			cc.append(_spine(seed, i + row * 30))
			x += t; i += 1
	M.multi_boxes(tr, xf, cc)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.3, 0, 0.3), Vector3(0.3, 1.0, 1.25))])
	root.set_meta("aabb", M.aabb_of(root))
	return root

# ======================================================================================
# newspaper_lectern: atril doble y largo de la Sala de Periódicos (se lee de pie): tableros inclinados con colecciones
# encuadernadas abiertas. Extras: l (largo), n (tomos abiertos por cara), seed.
static func build_newspaper_lectern(p: Dictionary) -> Node3D:
	var root := M.root("newspaper_lectern")
	var L := M.pf(p, "l", 6.0)
	var n := M.pi_(p, "n", 3)
	var seed := M.seed_of(p, "nl")
	var h := 1.12
	for s: float in [-1.0, 1.0]:
		M.box(root, Vector3(L, 0.04, 0.78), Vector3(0, h, s * 0.36), "madera_oscura", Vector3(s * 16, 0, 0))
		M.box(root, Vector3(L, 0.06, 0.05), Vector3(0, h - 0.12, s * 0.74), "madera_oscura")
	M.box(root, Vector3(L, 0.08, 0.1), Vector3(0, h + 0.1, 0), "madera_negra")
	var nl := int(L / 1.5) + 1
	for k in nl:
		var x := -L / 2 + 0.1 + (L - 0.2) * k / maxf(nl - 1, 1)
		M.box(root, Vector3(0.08, h, 1.1), Vector3(x, h / 2, 0), "madera_negra")
	M.box(root, Vector3(L, 0.04, 0.9), Vector3(0, 0.25, 0), "madera_oscura")
	# tomos encuadernados en la repisa baja
	var xf: Array = []; var cc: Array = []
	var x := -L / 2 + 0.15
	var i := 0
	while x < L / 2 - 0.2 and i < 80:
		var t := M.rr(seed, i, 1, 0.06, 0.1)
		xf.append(M.xf_box(Vector3(t - 0.004, 0.08, 0.6), Vector3(x + t / 2, 0.31, 0), Vector3(0, 0, 0)))
		cc.append(_spine(seed, i))
		x += t + (0.002 if M.rnd(seed, i, 2) < 0.7 else 0.25)
		i += 1
	M.multi_boxes(root, xf, cc)
	# colecciones abiertas sobre el atril (páginas grandes con columnas)
	for s: float in [-1.0, 1.0]:
		for k in n:
			if M.rnd(seed, k, int(s + 3)) < 0.25: continue
			var cxp := -L / 2 + L * (k + 0.5) / n
			var g := Node3D.new(); g.position = Vector3(cxp, h + 0.03, s * 0.36); g.rotation_degrees = Vector3(s * 16, M.rr(seed, k, int(s + 5), -4, 4), 0); root.add_child(g)
			for pg: float in [-1.0, 1.0]:
				M.box(g, Vector3(0.44, 0.012, 0.6), Vector3(pg * 0.225, 0.01, 0), "papel_viejo", Vector3(0, 0, -pg * 3))
				for c in 4:
					M.box(g, Vector3(0.085, 0.002, 0.5), Vector3(pg * 0.225 - 0.15 + c * 0.1, 0.018, 0.02), "ceniza")
				M.box(g, Vector3(0.38, 0.002, 0.04), Vector3(pg * 0.225, 0.018, -0.25), "tinta")
			M.box(g, Vector3(0.92, 0.02, 0.64), Vector3(0, 0.0, 0), "cuero")
	root.set_meta("occ", [M.aabb_mm(Vector3(-L / 2, 0, -0.85), Vector3(L / 2, h + 0.2, 0.85))])
	return root

# ======================================================================================
# folio_shelves: estantería de pared con colecciones encuadernadas de diarios (tomos grandes, iguales, con tejuelo de año).
# Origen = centro del pie contra la pared; frente +Z. Extras: w, h, rows, seed.
static func build_folio_shelves(p: Dictionary) -> Node3D:
	var root := M.root("folio_shelves")
	var w := M.pf(p, "w", 4.0); var h := M.pf(p, "h", 3.2)
	var rows := M.pi_(p, "rows", 5)
	var seed := M.seed_of(p, "fs")
	var d := 0.5
	M.box(root, Vector3(w, h, 0.04), Vector3(0, h / 2, -d / 2 + 0.02), "madera_negra")
	var up: Array = []
	var nu := int(w / 1.0) + 1
	for k in nu:
		up.append(M.xf_box(Vector3(0.05, h, d), Vector3(-w / 2 + w * k / maxf(nu - 1, 1), h / 2, 0)))
	M.multi_boxes(root, up, [], "madera_oscura")
	var xf: Array = []; var cc: Array = []; var lb: Array = []
	var rh := (h - 0.15) / rows
	for r in rows:
		var y0 := 0.1 + r * rh
		M.box(root, Vector3(w, 0.035, d), Vector3(0, y0, 0), "madera_oscura")
		var x := -w / 2 + 0.06
		var i := 0
		while x < w / 2 - 0.12 and i < 100:
			var t := M.rr(seed, i, r, 0.07, 0.11)
			var bh := minf(rh - 0.06, 0.52)
			xf.append(M.xf_box(Vector3(t - 0.004, bh, d * 0.85), Vector3(x + t / 2, y0 + 0.02 + bh / 2, 0.02)))
			var f := 0.8 + 0.3 * M.rnd(seed, i, r + 9)
			cc.append(Color(0.3 * f, 0.2 * f, 0.13 * f) if (i / 12) % 2 == 0 else Color(0.22 * f, 0.22 * f, 0.2 * f))
			lb.append(M.xf_box(Vector3(t * 0.6, 0.05, 0.004), Vector3(x + t / 2, y0 + 0.02 + bh * 0.8, d * 0.45 + 0.002)))
			x += t
			i += 1
	M.multi_boxes(root, xf, cc)
	M.multi_boxes(root, lb, [], "laton")
	M.box(root, Vector3(w + 0.06, 0.1, d + 0.06), Vector3(0, h + 0.05, 0.02), "madera_negra")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.1, d / 2))])
	return root

# ======================================================================================
# vestibule: pasillo o vestíbulo corto detrás de un vano (piso de piedra, paredes de estuco, cielo raso, una lámpara).
# Origen = centro del umbral; se extiende hacia −Z. Extras: w, h, d, light (bool).
static func build_vestibule(p: Dictionary) -> Node3D:
	var root := M.root("vestibule")
	var w := M.pf(p, "w", 2.4); var h := M.pf(p, "h", 3.4); var d := M.pf(p, "d", 4.0)
	M.box(root, Vector3(w, 0.08, d), Vector3(0, -0.04, -d / 2), "piedra_portland")
	M.box(root, Vector3(w, 0.08, d), Vector3(0, h + 0.04, -d / 2), "yeso")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.1, h, d), Vector3(sx * (w / 2 + 0.05), h / 2, -d / 2), "estuco")
	M.box(root, Vector3(w, h, 0.1), Vector3(0, h / 2, -d - 0.05), "estuco")
	if M.pb(p, "light", true):
		var lamp := Node3D.new(); lamp.position = Vector3(0, h - 0.4, -d * 0.5); root.add_child(lamp)
		M.sphere(lamp, 0.14, Vector3.ZERO, "vela", Vector3.ONE, 12)
		lamp.set_meta("light", {"kind": "electrica", "energy": 0.9, "range": 6.0})
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.1, 0, -d - 0.1), Vector3(-w / 2, h, 0)), M.aabb_mm(Vector3(w / 2, 0, -d - 0.1), Vector3(w / 2 + 0.1, h, 0)),
		M.aabb_mm(Vector3(-w / 2, 0, -d - 0.1), Vector3(w / 2, h, -d))])
	return root

# ======================================================================================
# pendant_lamps: lámparas eléctricas colgantes (pantalla cónica) en fila, para la Sala de Periódicos.
# Extras: n, l (largo de la fila, a lo largo de X), y (altura de la pantalla), drop (largo del cable).
static func build_pendant_lamps(p: Dictionary) -> Node3D:
	var root := M.root("pendant_lamps")
	var n := M.pi_(p, "n", 4); var L := M.pf(p, "l", 9.0)
	var y := M.pf(p, "y", 3.4); var drop := M.pf(p, "drop", 2.6)
	for k in n:
		var x := -L / 2 + L * (k + 0.5) / n
		M.rod(root, 0.008, drop, Vector3(x, y + drop / 2, 0), "hierro")
		M.cyl(root, 0.06, 0.3, 0.2, Vector3(x, y, 0), "pintura_verde", Vector3.ZERO, 16)
		M.sphere(root, 0.07, Vector3(x, y - 0.08, 0), "vela", Vector3.ONE, 10)
		var mk := Node3D.new(); mk.position = Vector3(x, y - 0.1, 0); root.add_child(mk)
		mk.set_meta("light", {"kind": "electrica", "energy": 1.1, "range": 7.0})
	root.set_meta("occ", [])
	return root

# ======================================================================================
# standing_readers: lectores de pie, inclinados sobre los atriles de la Sala de Periódicos. Extras: at: [[x, z, rot]], seed.
static func build_standing_readers(p: Dictionary) -> Node3D:
	var root := M.root("standing_readers")
	var seed := M.seed_of(p, "str")
	var kinds := [
		{"h": 1.78, "sh": 0.44, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "behind"}, "hat": "", "stoop": 20.0},
		{"h": 1.7, "sh": 0.42, "g": 0.15, "coat": "frock", "coat_mat": "tela_media", "arms": {"r": "hold_front", "l": "hold_front"}, "hat": "", "stoop": 16.0, "mustache": "small"},
		{"h": 1.74, "sh": 0.42, "g": 0.13, "coat": "long", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "pocket"}, "hat": "", "stoop": 24.0},
	]
	var at: Array = p.get("at", [[0.0, 0.0, 0.0]])
	for i in at.size():
		var e: Array = at[i]
		var spec: Dictionary = (kinds[int(M.rnd(seed, i, 1) * kinds.size()) % kinds.size()] as Dictionary).duplicate(true)
		var fig := Node3D.new(); fig.name = "sr_%d" % i
		MQ._body(fig, spec, "de_pie", seed + i * 5)
		fig.position = Vector3(float(e[0]), 0, float(e[1]))
		fig.rotation_degrees = Vector3(0, float(e[2]), 0)
		root.add_child(fig)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# clerk: empleado sentado a un escritorio de registro (figura genérica, no es personaje). Origen = pie de la silla;
# el escritorio queda hacia +Z.
static func build_clerk(p: Dictionary) -> Node3D:
	var root := M.root("clerk")
	var seed := M.seed_of(p, "clk")
	var desk := Node3D.new(); desk.position = Vector3(0, 0, 0.62); root.add_child(desk)
	M.box(desk, Vector3(1.2, 0.04, 0.62), Vector3(0, 0.76, 0), "madera_oscura")
	M.box(desk, Vector3(1.2, 0.74, 0.04), Vector3(0, 0.37, 0.29), "madera_oscura")
	for sx: float in [-1.0, 1.0]:
		M.box(desk, Vector3(0.04, 0.74, 0.6), Vector3(sx * 0.58, 0.37, 0), "madera_oscura")
	var lg := Node3D.new(); lg.position = Vector3(-0.1, 0.78, -0.05); desk.add_child(lg)
	M.box(lg, Vector3(0.5, 0.02, 0.36), Vector3(0, 0.01, 0), "papel")
	for l in 9:
		M.box(lg, Vector3(0.42, 0.001, 0.003), Vector3(0, 0.021, -0.15 + l * 0.035), "agua")
	M.box(desk, Vector3(0.05, 0.04, 0.05), Vector3(0.35, 0.8, 0.0), "tinta")
	var fig := Node3D.new(); fig.name = "empleado"; root.add_child(fig)
	MQ._body(fig, {"h": 1.72, "sh": 0.42, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "", "stoop": 14.0, "mustache": "small"}, "sentado", seed)
	var ch := Node3D.new(); root.add_child(ch)
	M.box(ch, Vector3(0.44, 0.045, 0.42), Vector3(0, 0.46, -0.05), "madera_oscura")
	M.box(ch, Vector3(0.42, 0.42, 0.04), Vector3(0, 0.72, -0.27), "madera_oscura", Vector3(-8, 0, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.6, 0, 0.3), Vector3(0.6, 0.8, 0.95))])
	return root

# ======================================================================================
# strip_basket: small.basket_strips (r, h) con oclusor explícito (el renderer dummy de los tests no guarda las
# transformaciones del MultiMesh de las tiras; ver l1.gd, «Versiones de props de small.gd con oclusor explícito»).
static func build_strip_basket(p: Dictionary) -> Node3D:
	var SM = load("res://world/props/small.gd")
	var n: Node3D = SM.build_basket_strips(p)
	var r := M.pf(p, "r", 0.16); var h := M.pf(p, "h", 0.32)
	n.set_meta("occ", [M.aabb_mm(Vector3(-r * 0.8, 0, -r * 0.8), Vector3(r * 0.8, h, r * 0.8))])
	return n
