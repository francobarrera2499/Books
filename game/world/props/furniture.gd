# world/props/furniture.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2.
# Origen = centro del piso de la huella; frente (lado del usuario) hacia +Z. Devuelven Node3D con meta "occ".
extends RefCounted

const M = preload("res://world/materials.gd")

static func _spine(seed: int, i: int) -> Color:
	var pal := [Color("5a3a2a"), Color("6a2e26"), Color("3e4a3c"), Color("2f3440"), Color("7a6448"), Color("4a4036"),
		Color("8a7050"), Color("2c2a2c"), Color("a08a60"), Color("5e4e3c"), Color("b8a888"), Color("3a2a20")]
	var c: Color = pal[int(M.rnd(seed, i, 99) * pal.size()) % pal.size()]
	var f := 0.8 + 0.4 * M.rnd(seed, i, 98)
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

# pata torneada: fuste con anillos y bulbo
static func _turned_leg(parent: Node3D, pos: Vector3, h: float, r: float, mat: String) -> void:
	M.cyl(parent, r * 0.8, r * 0.55, h * 0.55, pos + Vector3(0, h * 0.275, 0), mat, Vector3.ZERO, 10)
	M.sphere(parent, r * 1.25, pos + Vector3(0, h * 0.6, 0), mat, Vector3(1, 1.3, 1), 10)
	M.cyl(parent, r, r, h * 0.32, pos + Vector3(0, h * 0.84, 0), mat, Vector3.ZERO, 10)
	M.cyl(parent, r * 1.3, r * 1.3, 0.025, pos + Vector3(0, h * 0.7, 0), mat, Vector3.ZERO, 10)

# ======================================================================================
# desk(w,d,h,drawers): escritorio de pedestales con tapa de cuero. Extras: pigeonholes (casillero trasero), mat.
static func build_desk(p: Dictionary) -> Node3D:
	var root := M.root("desk")
	var w := M.pf(p, "w", 1.4); var d := M.pf(p, "d", 0.75); var h := M.pf(p, "h", 0.76)
	var nd := clampi(M.pi_(p, "drawers", 3), 1, 6)
	var mat := M.ps(p, "mat", "madera_oscura")
	var top_t := 0.035
	M.box(root, Vector3(w, top_t, d), Vector3(0, h - top_t / 2, 0), mat)
	M.box(root, Vector3(w - 0.1, 0.004, d - 0.1), Vector3(0, h + 0.002, 0), "cuero")
	M.box(root, Vector3(w + 0.012, 0.012, d + 0.012), Vector3(0, h - top_t - 0.006, 0), "madera_negra")
	var pw := minf(0.42, w * 0.3)
	var ph := h - top_t - 0.08
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (w / 2 - pw / 2 - 0.02)
		M.box(root, Vector3(pw, ph, d - 0.06), Vector3(cx, 0.08 + ph / 2, 0), mat)
		M.box(root, Vector3(pw + 0.02, 0.08, d - 0.04), Vector3(cx, 0.04, 0), "madera_negra")
		var dh := (ph - 0.03) / nd
		for k in nd:
			var cy := 0.08 + 0.015 + dh * (k + 0.5)
			M.box(root, Vector3(pw - 0.05, dh - 0.025, 0.015), Vector3(cx, cy, (d - 0.06) / 2 + 0.006), "madera_media")
			M.torus(root, 0.012, 0.022, Vector3(cx, cy + 0.005, (d - 0.06) / 2 + 0.02), "laton", Vector3(90, 0, 0))
	# cajón central y faldón
	M.box(root, Vector3(w - 2 * pw - 0.06, 0.1, d - 0.08), Vector3(0, h - top_t - 0.05, -0.01), mat)
	M.box(root, Vector3(w - 2 * pw - 0.14, 0.07, 0.012), Vector3(0, h - top_t - 0.05, (d - 0.08) / 2 - 0.004), "madera_media")
	M.torus(root, 0.012, 0.022, Vector3(0, h - top_t - 0.05, (d - 0.08) / 2 + 0.01), "laton", Vector3(90, 0, 0))
	M.box(root, Vector3(w - 2 * pw - 0.04, ph - 0.12, 0.02), Vector3(0, 0.08 + (ph - 0.12) / 2, -d / 2 + 0.05), mat)
	var occ := [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, d / 2))]
	if M.pb(p, "pigeonholes", false):
		var gh := 0.38
		var gd := 0.26
		var gz := -d / 2 + gd / 2 + 0.01
		M.box(root, Vector3(w - 0.06, 0.02, gd), Vector3(0, h + gh, gz), mat)
		M.box(root, Vector3(w - 0.06, gh, 0.012), Vector3(0, h + gh / 2, gz - gd / 2), mat)
		var cols := 6
		for c in cols + 1:
			M.box(root, Vector3(0.012, gh, gd), Vector3(-(w - 0.06) / 2 + (w - 0.06) * c / cols, h + gh / 2, gz), mat)
		M.box(root, Vector3(w - 0.06, 0.012, gd), Vector3(0, h + gh * 0.5, gz), mat)
		var seed := M.seed_of(p, "desk")
		for c in cols:
			for r in 2:
				if M.rnd(seed, c, r) < 0.7:
					var cx2 := -(w - 0.06) / 2 + (w - 0.06) * (c + 0.5) / cols
					var n := 2 + int(M.rnd(seed, c, r + 5) * 4)
					for k in n:
						M.box(root, Vector3((w - 0.06) / cols * 0.75, 0.004, gd * 0.8), Vector3(cx2, h + 0.01 + gh * 0.5 * r + 0.006 * k, gz + 0.02), "papel" if k % 2 == 0 else "papel_viejo", Vector3(90 if M.rnd(seed, c, k) < 0.5 else 80, 0, 0) if false else Vector3.ZERO)
		occ.append(M.aabb_mm(Vector3(-w / 2, h, gz - gd / 2), Vector3(w / 2, h + gh + 0.02, gz + gd / 2)))
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# table(w,d,h,round): mesa de patas torneadas o velador redondo de pie central. Extras: mat, cloth (mantel).
static func build_table(p: Dictionary) -> Node3D:
	var root := M.root("table")
	var w := M.pf(p, "w", 1.2); var d := M.pf(p, "d", 0.8); var h := M.pf(p, "h", 0.74)
	var mat := M.ps(p, "mat", "madera_oscura")
	if M.pb(p, "round", false):
		var r := w / 2.0
		M.cyl(root, r, r, 0.035, Vector3(0, h - 0.0175, 0), mat, Vector3.ZERO, 32)
		M.cyl(root, r - 0.02, r - 0.02, 0.05, Vector3(0, h - 0.06, 0), mat, Vector3.ZERO, 32)
		M.cyl(root, 0.045, 0.06, h - 0.25, Vector3(0, 0.12 + (h - 0.25) / 2, 0), mat, Vector3.ZERO, 12)
		M.sphere(root, 0.09, Vector3(0, 0.2, 0), mat, Vector3(1, 0.8, 1), 12)
		for k in 3:
			var a := TAU * k / 3.0 + PI / 6.0
			var d0 := Vector3(sin(a), 0, cos(a))
			M.beam_ab(root, d0 * 0.05 + Vector3(0, 0.2, 0), d0 * minf(r * 0.62, 0.36) + Vector3(0, 0.03, 0), 0.045, 0.06, mat)
			M.sphere(root, 0.03, d0 * minf(r * 0.62, 0.36) + Vector3(0, 0.025, 0), mat, Vector3(1, 0.7, 1), 8)
		if M.pb(p, "cloth", false):
			M.cyl(root, r + 0.02, r + 0.12, 0.3, Vector3(0, h - 0.13, 0), "tela_clara", Vector3.ZERO, 24)
		root.set_meta("occ", [M.aabb_mm(Vector3(-r, h - 0.1, -r), Vector3(r, h, r)), M.aabb_mm(Vector3(-0.06, 0, -0.06), Vector3(0.06, h, 0.06))])
		return root
	M.box(root, Vector3(w, 0.035, d), Vector3(0, h - 0.0175, 0), mat)
	M.box(root, Vector3(w - 0.12, 0.09, d - 0.12), Vector3(0, h - 0.08, 0), mat)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_turned_leg(root, Vector3(sx * (w / 2 - 0.07), 0, sz * (d / 2 - 0.07)), h - 0.035, 0.03, mat)
	if M.pb(p, "cloth", false):
		M.box(root, Vector3(w + 0.1, 0.25, d + 0.1), Vector3(0, h - 0.11, 0), "tela_clara")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, h - 0.13, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# ======================================================================================
# chair(style): "comedor" (respaldo de globo), "windsor", "bentwood" (Thonet), "oficina" (de capitán). Mira a +Z.
static func build_chair(p: Dictionary) -> Node3D:
	var root := M.root("chair")
	var style := M.ps(p, "style", "comedor")
	var mat := M.ps(p, "mat", "madera_oscura")
	var sh := 0.46
	var tilt := deg_to_rad(9.0)
	var vb := Vector3(0, cos(tilt), -sin(tilt))   # «arriba» del respaldo (inclinado hacia atrás)
	match style:
		"bentwood":
			M.cyl(root, 0.21, 0.21, 0.035, Vector3(0, sh, 0), "mimbre", Vector3.ZERO, 24)
			M.torus(root, 0.195, 0.225, Vector3(0, sh - 0.02, 0), "madera_negra")
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4
				M.rod_ab(root, 0.014, Vector3(cos(a) * 0.17, sh - 0.02, sin(a) * 0.17), Vector3(cos(a) * 0.23, 0.0, sin(a) * 0.23), "madera_negra")
			M.torus(root, 0.17, 0.19, Vector3(0, 0.2, 0), "madera_negra")
			var b0 := Vector3(0, sh, -0.19)
			for sx: float in [-1.0, 1.0]:
				M.capsule_ab(root, 0.013, b0 + Vector3(sx * 0.15, 0, 0), b0 + Vector3(sx * 0.15, 0, 0) + vb * 0.42, "madera_negra")
			M.arc(root, b0 + vb * 0.42, 0.15, Vector3.RIGHT, vb, 0.0, PI, 10, 0.013, "madera_negra")
			M.arc(root, b0 + vb * 0.26, 0.085, Vector3.RIGHT, vb, 0.0, TAU, 14, 0.011, "madera_negra")
		"windsor":
			M.box(root, Vector3(0.44, 0.045, 0.4), Vector3(0, sh, 0), mat)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					M.rod_ab(root, 0.016, Vector3(sx * 0.17, sh, sz * 0.15), Vector3(sx * 0.21, 0, sz * 0.19), mat)
			M.rod_ab(root, 0.01, Vector3(-0.19, 0.18, 0), Vector3(0.19, 0.18, 0), mat)
			var c := Vector3(0, sh, -0.17) + vb * 0.3
			M.arc(root, c, 0.2, Vector3.RIGHT, vb, 0.0, PI, 12, 0.016, mat)
			for sx: float in [-1.0, 1.0]:
				M.capsule_ab(root, 0.016, c + Vector3(sx * 0.2, 0, 0), Vector3(sx * 0.19, sh, -0.16), mat)
			for k in 7:
				var x := -0.15 + 0.05 * k
				var top := 0.3 + sqrt(maxf(0.2 * 0.2 - x * x, 0.0))
				M.rod_ab(root, 0.007, Vector3(x, sh, -0.17), Vector3(x, sh, -0.17) + vb * top, mat)
		"oficina":
			M.box(root, Vector3(0.46, 0.05, 0.42), Vector3(0, sh, 0), mat)
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					M.rod_ab(root, 0.018, Vector3(sx * 0.18, sh, sz * 0.16), Vector3(sx * 0.21, 0, sz * 0.19), mat)
			var c2 := Vector3(0, sh + 0.26, 0.0)
			M.arc(root, c2, 0.22, Vector3.RIGHT, Vector3.BACK * -1.0, -0.15, PI + 0.15, 12, 0.024, mat)
			for k in 7:
				var a := PI * (k + 0.5) / 7.0
				var top_p := c2 + Vector3(cos(a) * 0.22, 0, -sin(a) * 0.22)
				M.rod_ab(root, 0.009, Vector3(cos(a) * 0.19, sh, -sin(a) * 0.18), top_p, mat)
			for sx: float in [-1.0, 1.0]:
				M.rod_ab(root, 0.012, Vector3(sx * 0.2, sh, 0.12), c2 + Vector3(sx * 0.215, -0.01, 0.06), mat)
		_:
			M.box(root, Vector3(0.44, 0.05, 0.42), Vector3(0, sh, 0.01), mat)
			M.box(root, Vector3(0.4, 0.035, 0.38), Vector3(0, sh + 0.04, 0.02), "cuero")
			for sx: float in [-1.0, 1.0]:
				_turned_leg(root, Vector3(sx * 0.18, 0, 0.17), sh - 0.025, 0.02, mat)
				M.box(root, Vector3(0.035, sh, 0.035), Vector3(sx * 0.18, sh / 2, -0.17), mat, Vector3(-6, 0, 0))
			# respaldo de globo: montantes que se cierran en un óvalo
			var b1 := Vector3(0, sh, -0.19)
			var oc := b1 + vb * 0.5
			for sx: float in [-1.0, 1.0]:
				M.capsule_ab(root, 0.017, b1 + Vector3(sx * 0.17, 0, 0), oc + Vector3(sx * 0.16, -0.06, 0), mat)
			M.arc(root, oc, 0.16, Vector3.RIGHT, vb, -0.35, PI + 0.35, 14, 0.018, mat)
			M.box(root, Vector3(0.3, 0.03, 0.025), b1 + vb * 0.24, mat, Vector3(-9, 0, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.22, 0, -0.22), Vector3(0.22, sh + 0.05, 0.22))])
	return root

# ======================================================================================
# armchair(wing): butacón tapizado capitoné (wing = orejero). Extras: mat (cuero|terciopelo|tela_media).
static func build_armchair(p: Dictionary) -> Node3D:
	var root := M.root("armchair")
	var wing := M.pb(p, "wing", false)
	var mat := M.ps(p, "mat", "cuero")
	var W := 0.82; var D := 0.82
	var sh := 0.42
	M.box(root, Vector3(W - 0.04, 0.24, D - 0.08), Vector3(0, 0.1 + 0.12, 0.02), mat)
	M.capsule(root, 0.09, W - 0.26, Vector3(0, sh - 0.02, 0.06), mat, Vector3(0, 0, 90), Vector3(1, 0.7, 2.6))
	var bh := 0.95 if wing else 0.78
	M.box(root, Vector3(W - 0.08, bh, 0.2), Vector3(0, 0.1 + bh / 2, -D / 2 + 0.1), mat, Vector3(-8, 0, 0))
	M.capsule(root, 0.1, W - 0.08, Vector3(0, 0.1 + bh - 0.02, -D / 2 + 0.06), mat, Vector3(0, 0, 90))
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.14, 0.42, D - 0.06), Vector3(sx * (W / 2 - 0.07), 0.1 + 0.21, 0.0), mat)
		M.capsule(root, 0.085, D - 0.02, Vector3(sx * (W / 2 - 0.06), 0.6, 0.02), mat, Vector3(90, 0, 0), Vector3(1.05, 1, 1))
		M.sphere(root, 0.1, Vector3(sx * (W / 2 - 0.06), 0.58, D / 2 - 0.03), mat, Vector3(0.95, 1, 0.5))
		if wing:
			var wg := M.box(root, Vector3(0.09, 0.42, 0.3), Vector3(sx * (W / 2 - 0.05), 0.82, -D / 2 + 0.22), mat)
			wg.rotation_degrees = Vector3(0, sx * -18, 0)
			M.capsule(root, 0.06, 0.42, Vector3(sx * (W / 2 - 0.03), 0.84, -D / 2 + 0.36), mat)
		for sz: float in [-1.0, 1.0]:
			M.cyl(root, 0.025, 0.018, 0.1, Vector3(sx * (W / 2 - 0.08), 0.05, sz * (D / 2 - 0.08)), "madera_oscura", Vector3.ZERO, 8)
	# botones del capitoné
	for r in 3:
		for c in 4:
			M.sphere(root, 0.012, Vector3(-0.21 + 0.14 * c + (0.07 if r % 2 else 0.0), 0.5 + r * 0.14, -D / 2 + 0.215 - r * 0.02), "madera_negra")
	root.set_meta("occ", [M.aabb_mm(Vector3(-W / 2, 0, -D / 2), Vector3(W / 2, 0.68, D / 2)), M.aabb_mm(Vector3(-W / 2, 0, -D / 2), Vector3(W / 2, 0.1 + bh, -D / 2 + 0.2))])
	return root

# ======================================================================================
# bookshelf(w,h,rows,fill,gap{row,from,to},seed): estantería con lomos variados (MultiMesh).
# gap: hueco en la fila `row` entre las fracciones `from`..`to` del ancho; deja marca de polvo. Extras: d, mat, glazed.
static func build_bookshelf(p: Dictionary) -> Node3D:
	var root := M.root("bookshelf")
	var w := M.pf(p, "w", 1.6); var h := M.pf(p, "h", 2.1)
	var rows := clampi(M.pi_(p, "rows", 5), 1, 12)
	var fill := clampf(M.pf(p, "fill", 0.85), 0.0, 1.0)
	var d := M.pf(p, "d", 0.34)
	var mat := M.ps(p, "mat", "madera_oscura")
	var seed := M.seed_of(p, "shelf")
	var gap = p.get("gap", null)
	var st := 0.03
	var plinth := 0.1
	var cornice := 0.08
	M.box(root, Vector3(st, h, d), Vector3(-w / 2 + st / 2, h / 2, 0), mat)
	M.box(root, Vector3(st, h, d), Vector3(w / 2 - st / 2, h / 2, 0), mat)
	M.box(root, Vector3(w, 0.015, d), Vector3(0, h / 2, -d / 2 + 0.0075), mat, Vector3(90, 0, 0))
	M.box(root, Vector3(w - 2 * st, h - plinth, 0.012), Vector3(0, plinth + (h - plinth) / 2, -d / 2 + 0.006), "madera_negra")
	M.box(root, Vector3(w + 0.02, plinth, d + 0.02), Vector3(0, plinth / 2, 0.005), mat)
	M.box(root, Vector3(w + 0.08, cornice, d + 0.06), Vector3(0, h - cornice / 2, 0.02), mat)
	M.box(root, Vector3(w + 0.12, 0.025, d + 0.09), Vector3(0, h + 0.0125, 0.03), mat)
	var inner_h := h - plinth - cornice
	var rh := inner_h / rows
	var bx: Array = []; var bc: Array = []
	var bands: Array = []
	var dust: Array = []
	var x_in0 := -w / 2 + st
	var x_in1 := w / 2 - st
	var span := x_in1 - x_in0
	var idx := 0
	for r in rows:
		var y0 := plinth + rh * r
		M.box(root, Vector3(w - 2 * st, 0.022, d - 0.02), Vector3(0, y0 + 0.011, 0.0), mat)
		M.box(root, Vector3(w - 2 * st, 0.03, 0.02), Vector3(0, y0 + 0.008, d / 2 - 0.012), mat)
		var gx0 := 9.0; var gx1 := -9.0
		if gap is Dictionary and int(gap.get("row", -1)) == r:
			gx0 = x_in0 + span * float(gap.get("from", 0.4))
			gx1 = x_in0 + span * float(gap.get("to", 0.6))
			# marca de polvo donde estaban los lomos
			dust.append(M.xf_box(Vector3(gx1 - gx0 - 0.01, 0.002, d - 0.12), Vector3((gx0 + gx1) / 2, y0 + 0.023, 0.0)))
		var row_fill := clampf(fill + (M.rnd(seed, r, 7) - 0.5) * 0.2, 0.0, 1.0)
		var x := x_in0 + 0.005
		var limit := x_in0 + span * row_fill
		var guard := 0
		var lean_done := false
		while x < x_in1 - 0.02 and guard < 400:
			guard += 1
			if x >= gx0 - 0.005 and x < gx1:
				x = gx1 + 0.003; continue
			if x > limit:
				# fin de la corrida: un libro inclinado contra el anterior, luego vacío
				if not lean_done and x < x_in1 - 0.2 and x < gx0 - 0.1 or (not lean_done and x > gx1 and x < x_in1 - 0.2):
					var lh := minf(rh * 0.78, 0.33)
					var lt := 0.035
					var ang := 18.0 + 10.0 * M.rnd(seed, r, 11)
					var c := Vector3(x + sin(deg_to_rad(ang)) * lh / 2 + lt / 2, y0 + 0.022 + cos(deg_to_rad(ang)) * lh / 2, 0.02)
					bx.append(M.xf_box(Vector3(lt, lh, d * 0.68), c, Vector3(0, 0, -ang)))
					bc.append(_spine(seed, idx)); idx += 1
					lean_done = true
				if gx1 > x and gx0 < x_in1: x = maxf(x, gx1 + 0.003); limit = x_in1; continue
				break
			var t := M.rr(seed, idx, 1, 0.018, 0.055)
			var bh := minf(rh - 0.04, M.rr(seed, idx, 2, 0.62, 0.97) * minf(rh - 0.03, 0.36))
			var bd := M.rr(seed, idx, 3, 0.62, 0.8) * d
			if x + t > x_in1 - 0.004: break
			if gx0 < 9.0 and x < gx0 and x + t > gx0 - 0.002:
				x = gx1 + 0.003; continue
			if M.rnd(seed, idx, 4) < 0.06 and rh > 0.22:
				# pila acostada
				var n := 2 + int(M.rnd(seed, idx, 5) * 3)
				var pw := minf(0.24, x_in1 - x - 0.01)
				if pw > 0.12:
					var yy := y0 + 0.022
					for k in n:
						var th := M.rr(seed, idx, 20 + k, 0.025, 0.045)
						bx.append(M.xf_box(Vector3(pw * M.rr(seed, idx, 30 + k, 0.82, 1.0), th, bd), Vector3(x + pw / 2, yy + th / 2, d / 2 - bd / 2 - 0.02), Vector3(0, (M.rnd(seed, idx, 40 + k) - 0.5) * 8.0, 0)))
						bc.append(_spine(seed, idx + 1000 + k))
						yy += th
					x += pw + 0.006; idx += 1
					continue
			var c2 := Vector3(x + t / 2, y0 + 0.022 + bh / 2, d / 2 - bd / 2 - 0.02 + M.rr(seed, idx, 6, -0.015, 0.0))
			bx.append(M.xf_box(Vector3(t, bh, bd), c2))
			var col := _spine(seed, idx)
			bc.append(col)
			if M.rnd(seed, idx, 8) < 0.45 and t > 0.022:
				for k in 2:
					bands.append(M.xf_box(Vector3(t + 0.002, 0.008, 0.004), Vector3(c2.x, c2.y + bh * (0.32 - 0.62 * k) * 0.5 + bh * 0.3 * k, c2.z + bd / 2 + 0.001)))
			x += t + (0.001 if M.rnd(seed, idx, 9) < 0.8 else 0.006)
			idx += 1
	if bx.size() > 0: M.multi_boxes(root, bx, bc, "lomo")
	if bands.size() > 0: M.multi_boxes(root, bands, [], "laton")
	if dust.size() > 0: M.multi_boxes(root, dust, [], "papel_viejo")
	if M.pb(p, "glazed", false):
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(w / 2 - 0.02, inner_h, 0.008), Vector3(sx * w / 4, plinth + inner_h / 2, d / 2 + 0.01), "vidrio")
			M.box(root, Vector3(0.03, inner_h, 0.02), Vector3(sx * 0.015, plinth + inner_h / 2, d / 2 + 0.01), mat)
	root.set_meta("occ", [
		M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(-w / 2 + st, h, d / 2)),
		M.aabb_mm(Vector3(w / 2 - st, 0, -d / 2), Vector3(w / 2, h, d / 2)),
		M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, -d / 2 + 0.02)),
		M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, plinth, d / 2)),
		M.aabb_mm(Vector3(-w / 2, h - cornice, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# ======================================================================================
# counter(w,d,h): mostrador de tienda con tableros, zócalo y tapa volada. Extras: mat, ledger (libro abierto), bell.
static func build_counter(p: Dictionary) -> Node3D:
	var root := M.root("counter")
	var w := M.pf(p, "w", 2.4); var d := M.pf(p, "d", 0.6); var h := M.pf(p, "h", 0.95)
	var mat := M.ps(p, "mat", "madera_oscura")
	M.box(root, Vector3(w + 0.08, 0.045, d + 0.08), Vector3(0, h - 0.0225, 0.02), mat)
	M.box(root, Vector3(w + 0.1, 0.02, d + 0.1), Vector3(0, h - 0.05, 0.02), "madera_negra")
	M.box(root, Vector3(w, h - 0.12, 0.04), Vector3(0, 0.08 + (h - 0.12) / 2, d / 2 - 0.02), mat)
	M.box(root, Vector3(w + 0.03, 0.1, d + 0.03), Vector3(0, 0.05, 0.0), "madera_negra")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, h - 0.05, d), Vector3(sx * (w / 2 - 0.02), (h - 0.05) / 2, 0), mat)
	var np := maxi(int(w / 0.55), 1)
	for k in np:
		var cx := -w / 2 + w * (k + 0.5) / np
		M.box(root, Vector3(w / np - 0.1, h - 0.36, 0.012), Vector3(cx, 0.12 + (h - 0.36) / 2 + 0.04, d / 2 + 0.004), "madera_media")
		M.box(root, Vector3(w / np - 0.16, h - 0.42, 0.012), Vector3(cx, 0.12 + (h - 0.36) / 2 + 0.04, d / 2 + 0.012), mat)
	# estantes detrás (lado −Z)
	for k in 2:
		M.box(root, Vector3(w - 0.1, 0.02, d - 0.12), Vector3(0, 0.3 + k * 0.3, -0.02), mat)
	if M.pb(p, "bell", false):
		M.hemi(root, 0.045, Vector3(w * 0.3, h, 0.1), "laton")
		M.sphere(root, 0.012, Vector3(w * 0.3, h + 0.05, 0.1), "laton")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, d / 2))])
	return root

# ======================================================================================
# stool: taburete alto de mostrador.
static func build_stool(p: Dictionary) -> Node3D:
	var root := M.root("stool")
	var h := M.pf(p, "h", 0.7)
	var mat := M.ps(p, "mat", "madera_media")
	M.cyl(root, 0.18, 0.17, 0.04, Vector3(0, h - 0.02, 0), mat, Vector3.ZERO, 20)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		M.rod_ab(root, 0.018, Vector3(cos(a) * 0.12, h - 0.03, sin(a) * 0.12), Vector3(cos(a) * 0.2, 0, sin(a) * 0.2), mat)
	M.torus(root, 0.15, 0.17, Vector3(0, h * 0.32, 0), mat)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.2, 0, -0.2), Vector3(0.2, h, 0.2))])
	return root

# ======================================================================================
# bed(w,d): cama de hierro con perillas de latón, colchón, almohada y frazada. Cabecera hacia −Z.
static func build_bed(p: Dictionary) -> Node3D:
	var root := M.root("bed")
	var w := M.pf(p, "w", 1.0); var d := M.pf(p, "d", 1.95)
	var mh := 0.5
	for end: float in [-1.0, 1.0]:
		var z := end * d / 2
		var top := 1.15 if end < 0 else 0.85
		for sx: float in [-1.0, 1.0]:
			M.rod(root, 0.018, top, Vector3(sx * w / 2, top / 2, z), "hierro")
			M.sphere(root, 0.035, Vector3(sx * w / 2, top + 0.02, z), "laton")
		M.rod(root, 0.012, w, Vector3(0, top - 0.05, z), "hierro", Vector3(0, 0, 90))
		M.rod(root, 0.012, w, Vector3(0, mh - 0.12, z), "hierro", Vector3(0, 0, 90))
		var nb := 7
		for k in nb:
			var x := -w / 2 + w * (k + 1) / (nb + 1)
			M.rod(root, 0.007, top - 0.05 - (mh - 0.12), Vector3(x, (top - 0.05 + mh - 0.12) / 2, z), "hierro")
		M.torus(root, 0.06, 0.075, Vector3(0, (top + mh) / 2, z), "laton", Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		M.rod(root, 0.015, d, Vector3(sx * w / 2, mh - 0.15, 0), "hierro", Vector3(90, 0, 0))
	M.box(root, Vector3(w - 0.04, 0.18, d - 0.06), Vector3(0, mh - 0.06, 0), "lienzo")
	M.capsule(root, 0.08, w - 0.2, Vector3(0, mh + 0.08, -d / 2 + 0.22), "papel", Vector3(0, 0, 90), Vector3(1, 0.7, 2.2))
	M.box(root, Vector3(w + 0.06, 0.05, d * 0.66), Vector3(0, mh + 0.05, d * 0.15), "tela_media")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.02, 0.3, d * 0.66), Vector3(sx * (w / 2 + 0.03), mh - 0.1, d * 0.15), "tela_media")
	M.box(root, Vector3(w + 0.06, 0.06, 0.3), Vector3(0, mh + 0.065, -d * 0.18), "papel_viejo")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, mh + 0.1, d / 2))])
	return root

# ======================================================================================
# stove(h): estufa de hierro (de «tortuga») con caño hasta h. Extras: lit (resplandor en la puertita).
static func build_stove(p: Dictionary) -> Node3D:
	var root := M.root("stove")
	var h := M.pf(p, "h", 2.4)
	var bh := 0.62
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		M.cyl(root, 0.02, 0.03, 0.12, Vector3(cos(a) * 0.17, 0.06, sin(a) * 0.17), "hierro", Vector3.ZERO, 8)
	M.cyl(root, 0.24, 0.24, 0.04, Vector3(0, 0.14, 0), "hierro", Vector3.ZERO, 20)
	M.cyl(root, 0.2, 0.22, bh - 0.2, Vector3(0, 0.16 + (bh - 0.2) / 2, 0), "hierro", Vector3.ZERO, 20)
	M.cyl(root, 0.26, 0.24, 0.05, Vector3(0, bh - 0.02, 0), "hierro", Vector3.ZERO, 20)
	M.sphere(root, 0.2, Vector3(0, bh, 0), "hierro", Vector3(1, 0.45, 1))
	for k in 6:
		M.torus(root, 0.205, 0.225, Vector3(0, 0.2 + k * 0.06, 0), "hierro")
	M.box(root, Vector3(0.18, 0.15, 0.03), Vector3(0, 0.32, 0.215), "hierro")
	M.box(root, Vector3(0.12, 0.06, 0.01), Vector3(0, 0.32, 0.232), "gas_emisivo" if M.pb(p, "lit", false) else "carbon")
	M.box(root, Vector3(0.05, 0.015, 0.02), Vector3(0.06, 0.4, 0.235), "laton")
	M.cyl(root, 0.065, 0.065, h - bh, Vector3(0, bh + (h - bh) / 2, 0), "hierro", Vector3.ZERO, 12)
	M.torus(root, 0.06, 0.08, Vector3(0, bh + 0.5, 0), "hierro")
	# carbonera
	var sc := Node3D.new(); sc.position = Vector3(0.42, 0, 0.1); root.add_child(sc)
	M.cyl(sc, 0.13, 0.11, 0.3, Vector3(0, 0.15, 0), "cobre", Vector3(-12, 0, 0), 14)
	M.sphere(sc, 0.1, Vector3(0, 0.3, 0.03), "carbon", Vector3(1, 0.35, 1))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.26, 0, -0.26), Vector3(0.26, bh + 0.1, 0.26)), M.aabb_mm(Vector3(-0.07, bh, -0.07), Vector3(0.07, h, 0.07))])
	return root

# ======================================================================================
# fireplace(w,h,mantel): chimenea de mármol con repisa, hogar de hierro, carbones y guardafuego. Respaldo en z=0.
# Extras: mantel (alto de repisa, def 1.15), mirror (espejo sobre la repisa), lit, mat, breast (pecho saliente).
static func build_fireplace(p: Dictionary) -> Node3D:
	var root := M.root("fireplace")
	var w := M.pf(p, "w", 1.5); var h := M.pf(p, "h", 1.2)
	var mh := M.pf(p, "mantel", h)
	var mat := M.ps(p, "mat", "piedra_portland")
	var dz := 0.22
	if M.pb(p, "breast", true):
		M.box(root, Vector3(w + 0.5, M.pf(p, "breast_h", 3.0), 0.3), Vector3(0, M.pf(p, "breast_h", 3.0) / 2, 0.15), "papel_pintado")
		dz += 0.3
	var z0 := dz - 0.22
	var ow := w * 0.52; var oh := mh * 0.62
	for sx: float in [-1.0, 1.0]:
		var px := sx * (ow / 2 + (w - ow) / 4)
		M.box(root, Vector3((w - ow) / 2, mh - 0.08, 0.16), Vector3(px, (mh - 0.08) / 2, z0 + 0.08), mat)
		M.box(root, Vector3((w - ow) / 2 - 0.06, mh * 0.5, 0.02), Vector3(px, mh * 0.42, z0 + 0.17), mat)
		M.box(root, Vector3(0.12, 0.08, 0.2), Vector3(sx * (w / 2 - 0.06), mh - 0.12, z0 + 0.1), mat)
	M.box(root, Vector3(ow, mh - 0.08 - oh, 0.16), Vector3(0, oh + (mh - 0.08 - oh) / 2, z0 + 0.08), mat)
	M.box(root, Vector3(w + 0.16, 0.05, 0.3), Vector3(0, mh - 0.025, z0 + 0.12), mat)
	M.box(root, Vector3(w + 0.1, 0.03, 0.26), Vector3(0, mh - 0.065, z0 + 0.11), mat)
	# hogar (hierro, arco) y fondo
	M.box(root, Vector3(ow, oh, 0.04), Vector3(0, oh / 2, z0 - 0.02), "carbon")
	M.box(root, Vector3(ow - 0.04, oh - 0.04, 0.03), Vector3(0, oh / 2, z0 + 0.06), "hierro")
	M.box(root, Vector3(ow * 0.62, oh * 0.55, 0.05), Vector3(0, oh * 0.32, z0 + 0.07), "carbon")
	M.torus(root, ow * 0.27, ow * 0.33, Vector3(0, oh * 0.55, z0 + 0.075), "hierro", Vector3(90, 0, 0), Vector3(1, 1, 0.8))
	# reja con carbones
	for k in 5:
		M.rod(root, 0.008, ow * 0.6, Vector3(0, 0.08 + k * 0.035, z0 + 0.12), "hierro", Vector3(0, 0, 90))
	var lit := M.pb(p, "lit", false)
	for k in 9:
		var cx := -ow * 0.25 + ow * 0.5 * (k % 3) / 2.0
		M.sphere(root, 0.035, Vector3(cx + (k / 3) * 0.01, 0.12 + (k / 3) * 0.04, z0 + 0.1 - (k / 3) * 0.01), "gas_emisivo" if lit and k % 2 == 0 else "carbon", Vector3(1, 0.8, 1), 8)
	# solera y guardafuego de latón
	M.box(root, Vector3(w + 0.3, 0.03, 0.45), Vector3(0, 0.015, z0 + 0.32), mat)
	M.box(root, Vector3(w * 0.85, 0.08, 0.015), Vector3(0, 0.07, z0 + 0.5), "laton")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.015, 0.08, 0.3), Vector3(sx * w * 0.425, 0.07, z0 + 0.35), "laton")
	# atizador apoyado
	M.rod_ab(root, 0.008, Vector3(w / 2 + 0.08, 0.02, z0 + 0.3), Vector3(w / 2 - 0.02, 0.7, z0 + 0.2), "hierro")
	M.sphere(root, 0.018, Vector3(w / 2 - 0.02, 0.71, z0 + 0.2), "laton")
	if M.pb(p, "mirror", false):
		M.box(root, Vector3(w * 0.9, 0.9, 0.04), Vector3(0, mh + 0.5, z0 + 0.02), "madera_negra")
		M.box(root, Vector3(w * 0.84, 0.84, 0.01), Vector3(0, mh + 0.5, z0 + 0.045), "agua")
		M.box(root, Vector3(w * 0.84, 0.05, 0.012), Vector3(0, mh + 0.62, z0 + 0.048), "cielo", Vector3(0, 0, 18))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -0.05), Vector3(w / 2, mh, z0 + 0.25))])
	return root

# ======================================================================================
# coat_stand(hat): perchero de pie. hat: "bowler_crepe" | "bowler" | "top" | "cap" | "" ; Extras: coat (abrigo colgado), umbrella.
static func build_coat_stand(p: Dictionary) -> Node3D:
	var root := M.root("coat_stand")
	var h := M.pf(p, "h", 1.85)
	var mat := M.ps(p, "mat", "madera_oscura")
	M.cyl(root, 0.022, 0.03, h, Vector3(0, h / 2, 0), mat, Vector3.ZERO, 10)
	M.sphere(root, 0.04, Vector3(0, h + 0.02, 0), mat)
	for k in 3:
		var a := TAU * k / 3.0
		M.rod_ab(root, 0.016, Vector3(0, 0.2, 0), Vector3(cos(a) * 0.3, 0.0, sin(a) * 0.3), mat)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4
		var tip := Vector3(cos(a) * 0.17, h - 0.06, sin(a) * 0.17)
		M.rod_ab(root, 0.01, Vector3(0, h - 0.18, 0), tip, mat)
		M.sphere(root, 0.018, tip, mat)
	var hat := M.ps(p, "hat", "")
	if hat != "":
		var hp := Node3D.new(); hp.name = "hat"; hp.position = Vector3(0, h + 0.04, 0.0); root.add_child(hp)
		hp.rotation_degrees = Vector3(-14, 25, 0)
		match hat:
			"bowler", "bowler_crepe":
				M.hemi(hp, 0.1, Vector3(0, 0.07, 0), "fieltro", Vector3.ZERO, Vector3(1, 1.0, 1.1))
				M.cyl(hp, 0.1, 0.1, 0.07, Vector3(0, 0.035, 0), "fieltro", Vector3.ZERO, 20)
				M.cyl(hp, 0.15, 0.15, 0.012, Vector3(0, 0.0, 0), "fieltro", Vector3.ZERO, 24)
				if hat == "bowler_crepe":
					M.cyl(hp, 0.104, 0.104, 0.05, Vector3(0, 0.035, 0), "crespon", Vector3.ZERO, 20)
					M.box(hp, Vector3(0.06, 0.16, 0.012), Vector3(0.0, -0.04, -0.105), "crespon", Vector3(8, 0, 0))
			"top":
				M.cyl(hp, 0.095, 0.09, 0.2, Vector3(0, 0.1, 0), "fieltro", Vector3.ZERO, 20)
				M.cyl(hp, 0.15, 0.15, 0.012, Vector3(0, 0.0, 0), "fieltro", Vector3.ZERO, 24)
			"cap":
				M.hemi(hp, 0.1, Vector3(0, 0.0, 0), "tela_media", Vector3.ZERO, Vector3(1, 0.6, 1))
				M.box(hp, Vector3(0.14, 0.01, 0.12), Vector3(0, 0.0, 0.12), "tela_media")
	if M.pb(p, "coat", false):
		M.cyl(root, 0.08, 0.17, 0.95, Vector3(0.0, h - 0.66, 0.12), "tela_oscura", Vector3(8, 0, 0), 12)
		M.sphere(root, 0.08, Vector3(0, h - 0.18, 0.1), "tela_oscura", Vector3(1.5, 0.7, 1))
	if M.pb(p, "umbrella", false):
		M.cyl(root, 0.012, 0.05, 0.85, Vector3(0.2, 0.43, 0.05), "tela_oscura", Vector3(0, 0, -8), 8)
		M.torus(root, 0.02, 0.03, Vector3(0.14, 0.88, 0.05), "madera_negra", Vector3(90, 0, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.05, 0, -0.05), Vector3(0.05, h, 0.05))])
	return root

# ======================================================================================
# reading_desk_radial(n,r): mesas radiales de la Sala de Lectura con mampara central y sillas; anillo central del
# superintendente. Extras: r_in (def 0.38 r), chairs (def true), lamps.
static func build_reading_desk_radial(p: Dictionary) -> Node3D:
	var root := M.root("reading_desk_radial")
	var n := clampi(M.pi_(p, "n", 9), 1, 40)
	var r := M.pf(p, "r", 8.0)
	var r_in := M.pf(p, "r_in", r * 0.38)
	var mat := M.ps(p, "mat", "madera_oscura")
	var dh := 0.74
	# anillos centrales (catálogo y superintendente)
	M.cyl(root, r_in * 0.55, r_in * 0.55, 1.05, Vector3(0, 0.525, 0), mat, Vector3.ZERO, 40)
	M.cyl(root, r_in * 0.56, r_in * 0.56, 0.04, Vector3(0, 1.07, 0), "cuero", Vector3.ZERO, 40)
	M.cyl(root, r_in * 0.3, r_in * 0.3, 1.35, Vector3(0, 0.675, 0), mat, Vector3.ZERO, 32)
	M.cyl(root, r_in * 0.31, r_in * 0.31, 0.04, Vector3(0, 1.37, 0), "madera_negra", Vector3.ZERO, 32)
	M.torus(root, r_in * 0.8, r_in * 0.86, Vector3(0, 0.95, 0), mat, Vector3.ZERO, Vector3(1, 6, 1))
	var L := r - r_in
	var chairs := M.pb(p, "chairs", true)
	for i in n:
		var a := TAU * i / n
		var arm := Node3D.new(); arm.name = "desk_%d" % i; root.add_child(arm)
		arm.rotation = Vector3(0, -a, 0)
		var cxr := r_in + L / 2
		M.box(arm, Vector3(L, 0.04, 1.3), Vector3(cxr, dh, 0), mat)
		M.box(arm, Vector3(L - 0.1, 0.004, 1.2), Vector3(cxr, dh + 0.022, 0), "cuero")
		M.box(arm, Vector3(L, 0.36, 0.06), Vector3(cxr, dh + 0.2, 0), mat)
		M.box(arm, Vector3(L, 0.03, 0.22), Vector3(cxr, dh + 0.38, 0), mat)
		for k in int(L / 1.8) + 1:
			var x := r_in + 0.2 + k * (L - 0.4) / maxf(int(L / 1.8), 1)
			M.box(arm, Vector3(0.08, dh, 1.1), Vector3(x, dh / 2, 0), mat)
		var ns := int(L / 1.1)
		for k in ns:
			var x := r_in + 0.6 + k * 1.1
			for sz: float in [-1.0, 1.0]:
				# atril abatible y tintero
				M.box(arm, Vector3(0.36, 0.02, 0.26), Vector3(x, dh + 0.06, sz * 0.38), "madera_media", Vector3(sz * -20, 0, 0))
				M.cyl(arm, 0.02, 0.02, 0.03, Vector3(x + 0.3, dh + 0.035, sz * 0.12), "vidrio", Vector3.ZERO, 8)
				if chairs:
					var ch := build_chair({"style": "comedor", "mat": mat})
					ch.position = Vector3(x, 0, sz * 0.95)
					ch.rotation = Vector3(0, PI if sz > 0 else 0.0, 0)
					arm.add_child(ch)
	root.set_meta("occ", [M.aabb_mm(Vector3(-r_in * 0.55, 0, -r_in * 0.55), Vector3(r_in * 0.55, 1.07, r_in * 0.55))])
	return root

# ======================================================================================
# index_shelves(w,h): estantes bajos de catálogo/índices con tapa en atril y folios uniformes numerados.
static func build_index_shelves(p: Dictionary) -> Node3D:
	var root := M.root("index_shelves")
	var w := M.pf(p, "w", 2.4); var h := M.pf(p, "h", 1.05)
	var d := M.pf(p, "d", 0.6)
	var mat := M.ps(p, "mat", "madera_oscura")
	var seed := M.seed_of(p, "index")
	M.box(root, Vector3(w, 0.08, d), Vector3(0, 0.04, 0), mat)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, h, d), Vector3(sx * (w / 2 - 0.02), h / 2, 0), mat)
	M.box(root, Vector3(w, h - 0.1, 0.02), Vector3(0, 0.08 + (h - 0.1) / 2, -d / 2 + 0.01), mat)
	# tapa en atril
	M.box(root, Vector3(w + 0.06, 0.035, d * 0.75), Vector3(0, h + 0.07, 0.04), mat, Vector3(14, 0, 0))
	M.box(root, Vector3(w + 0.06, 0.04, 0.04), Vector3(0, h - 0.0, d / 2 - 0.02), mat)
	var rows := 2
	var rh := (h - 0.12) / rows
	var bx: Array = []; var bc: Array = []
	var base := Color("3a2a20")
	for r in rows:
		var y0 := 0.08 + r * rh
		M.box(root, Vector3(w - 0.08, 0.02, d - 0.04), Vector3(0, y0 + 0.01, 0), mat)
		var x := -w / 2 + 0.05
		var i := 0
		while x < w / 2 - 0.09 and i < 200:
			var t := 0.06 + 0.012 * M.rnd(seed, i, r)
			var bh := rh - 0.06
			bx.append(M.xf_box(Vector3(t - 0.003, bh, d * 0.8), Vector3(x + t / 2, y0 + 0.02 + bh / 2, 0.0)))
			var f := 0.85 + 0.3 * M.rnd(seed, i, r + 9)
			bc.append(Color(base.r * f, base.g * f, base.b * f))
			x += t; i += 1
		# rótulos claros en los lomos (tejuelos)
		var lb: Array = []
		var xx := -w / 2 + 0.08
		while xx < w / 2 - 0.1:
			lb.append(M.xf_box(Vector3(0.04, 0.05, 0.004), Vector3(xx, y0 + 0.02 + (rh - 0.06) * 0.72, d * 0.4 + 0.003)))
			xx += 0.066
		M.multi_boxes(root, lb, [], "papel")
	M.multi_boxes(root, bx, bc, "lomo")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.1, d / 2))])
	return root

# ======================================================================================
# cabinet(w,h,d): armario de dos puertas con tableros, cornisa y zócalo. Extras: glazed (puertas vidriadas con libros), mat.
static func build_cabinet(p: Dictionary) -> Node3D:
	var root := M.root("cabinet")
	var w := M.pf(p, "w", 1.0); var h := M.pf(p, "h", 1.9); var d := M.pf(p, "d", 0.45)
	var mat := M.ps(p, "mat", "madera_oscura")
	var glazed := M.pb(p, "glazed", false)
	if glazed:
		var ch := h - 0.18
		M.box(root, Vector3(0.025, ch, d), Vector3(-w / 2 + 0.0125, 0.1 + ch / 2, 0), mat)
		M.box(root, Vector3(0.025, ch, d), Vector3(w / 2 - 0.0125, 0.1 + ch / 2, 0), mat)
		M.box(root, Vector3(w, ch, 0.02), Vector3(0, 0.1 + ch / 2, -d / 2 + 0.01), "madera_negra")
		M.box(root, Vector3(w, 0.03, d), Vector3(0, 0.115, 0), mat)
		M.box(root, Vector3(w, 0.03, d), Vector3(0, 0.1 + ch - 0.015, 0), mat)
		M.box(root, Vector3(w, h - 0.18 - (h - 0.3) - 0.02, 0.025), Vector3(0, 0.12 + (h - 0.3) + (h - 0.18 - (h - 0.3)) / 2 - 0.01, d / 2 + 0.0125), mat)
	else:
		M.box(root, Vector3(w, h - 0.18, d), Vector3(0, 0.1 + (h - 0.18) / 2, 0), mat)
	M.box(root, Vector3(w + 0.03, 0.1, d + 0.03), Vector3(0, 0.05, 0), "madera_negra")
	M.box(root, Vector3(w + 0.09, 0.08, d + 0.07), Vector3(0, h - 0.04, 0.02), mat)
	var dw := (w - 0.06) / 2
	var dh := h - 0.3
	for sx: float in [-1.0, 1.0]:
		var cx := sx * (dw / 2 + 0.01)
		if glazed:
			var dz := d / 2 + 0.0125
			M.box(root, Vector3(dw, 0.06, 0.025), Vector3(cx, 0.12 + 0.03, dz), mat)
			M.box(root, Vector3(dw, 0.06, 0.025), Vector3(cx, 0.12 + dh - 0.03, dz), mat)
			M.box(root, Vector3(0.05, dh, 0.025), Vector3(cx - dw / 2 + 0.025, 0.12 + dh / 2, dz), mat)
			M.box(root, Vector3(0.05, dh, 0.025), Vector3(cx + dw / 2 - 0.025, 0.12 + dh / 2, dz), mat)
			for k in range(1, 3):
				M.box(root, Vector3(dw - 0.08, 0.02, 0.02), Vector3(cx, 0.12 + dh * k / 3.0, dz), mat)
			M.box(root, Vector3(dw - 0.1, dh - 0.1, 0.004), Vector3(cx, 0.12 + dh / 2, dz), "vidrio")
		else:
			M.box(root, Vector3(dw, dh, 0.025), Vector3(cx, 0.12 + dh / 2, d / 2 + 0.0125), mat)
			for k in 2:
				var ph := dh * (0.55 if k == 1 else 0.3)
				var py := 0.12 + (dh * 0.08 + ph / 2 if k == 0 else dh * 0.42 + ph / 2)
				M.box(root, Vector3(dw - 0.12, ph, 0.012), Vector3(cx, py, d / 2 + 0.028), "madera_media")
		M.sphere(root, 0.018, Vector3(sx * 0.05, 0.12 + dh * 0.5, d / 2 + 0.04), "laton")
	if glazed:
		var seed := M.seed_of(p, "cab")
		var bx: Array = []; var bc: Array = []
		for r in 4:
			var y0 := 0.15 + r * dh / 4
			M.box(root, Vector3(w - 0.06, 0.015, d - 0.06), Vector3(0, y0, 0), mat)
			var x := -w / 2 + 0.05
			var i := 0
			while x < w / 2 - 0.07 and i < 60:
				var t := M.rr(seed, i, r, 0.02, 0.045)
				var bh := M.rr(seed, i, r + 4, 0.6, 0.9) * (dh / 4 - 0.03)
				bx.append(M.xf_box(Vector3(t, bh, d * 0.6), Vector3(x + t / 2, y0 + 0.008 + bh / 2, 0.02)))
				bc.append(_spine(seed, i + r * 50))
				x += t + 0.002; i += 1
		M.multi_boxes(root, bx, bc, "lomo")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h, d / 2 + 0.03))])
	return root

# ======================================================================================
# crate(w,h,d,label): cajón de tablas con listones y etiqueta legible (Label3D; label = clave de ui_text o texto).
static func build_crate(p: Dictionary) -> Node3D:
	var root := M.root("crate")
	var w := M.pf(p, "w", 0.8); var h := M.pf(p, "h", 0.55); var d := M.pf(p, "d", 0.5)
	var mat := M.ps(p, "mat", "madera_clara")
	var seed := M.seed_of(p, "crate")
	M.box(root, Vector3(w - 0.04, h - 0.04, d - 0.04), Vector3(0, h / 2, 0), "interior_oscuro")
	var nb := maxi(int(h / 0.13), 2)
	var bh := h / nb
	for k in nb:
		var y := bh * (k + 0.5)
		var f := 0.9 + 0.2 * M.rnd(seed, k, 1)
		var col := M.color(mat) * f
		for face in 4:
			var m: MeshInstance3D
			match face:
				0: m = M.box(root, Vector3(w, bh - 0.012, 0.02), Vector3(0, y, d / 2 - 0.01), mat)
				1: m = M.box(root, Vector3(w, bh - 0.012, 0.02), Vector3(0, y, -d / 2 + 0.01), mat)
				2: m = M.box(root, Vector3(0.02, bh - 0.012, d - 0.04), Vector3(w / 2 - 0.01, y, 0), mat)
				3: m = M.box(root, Vector3(0.02, bh - 0.012, d - 0.04), Vector3(-w / 2 + 0.01, y, 0), mat)
			m.material_override = M.mat_color(Color(col.r, col.g, col.b))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.05, h, 0.05), Vector3(sx * (w / 2 - 0.02), h / 2, sz * (d / 2 - 0.02)), "madera_media")
	# tapa
	var lid_open := M.pf(p, "lid_open", 0.0)
	var lid := Node3D.new(); lid.position = Vector3(0, h, -d / 2); root.add_child(lid)
	lid.rotation_degrees = Vector3(-lid_open * 70.0, 0, 0)
	for k in 4:
		M.box(lid, Vector3(w + 0.02, 0.02, d / 4 - 0.008), Vector3(0, 0.01, d / 8 + k * d / 4), mat)
	M.box(lid, Vector3(0.05, 0.022, d), Vector3(-w / 2 + 0.06, 0.03, d / 2), "madera_media")
	M.box(lid, Vector3(0.05, 0.022, d), Vector3(w / 2 - 0.06, 0.03, d / 2), "madera_media")
	var txt := M.text_of(p, "label")
	if txt != "":
		M.box(root, Vector3(minf(w * 0.7, 0.5), minf(h * 0.4, 0.2), 0.004), Vector3(0, h * 0.55, d / 2 + 0.003), "papel")
		var lb := M.label3d(root, txt, Vector3(0, h * 0.55, d / 2 + 0.007), 0.0016, 48, Color("1b1712"))
		lb.width = minf(w * 0.7, 0.5) / 0.0016
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, h + 0.03, d / 2))])
	return root

# ======================================================================================
# gasolier (extra): araña de gas colgada del cielo raso, tres brazos con tulipas. h = alto del cielo raso; cuelga drop m.
static func build_gasolier(p: Dictionary) -> Node3D:
	var root := M.root("gasolier")
	var h := M.pf(p, "h", 3.0)
	var drop := M.pf(p, "drop", 0.85)
	var arms := clampi(M.pi_(p, "arms", 3), 1, 8)
	var lit := M.pb(p, "lit", true)
	var y0 := h - drop
	M.cyl(root, 0.08, 0.08, 0.02, Vector3(0, h - 0.01, 0), "laton", Vector3.ZERO, 16)
	M.rod(root, 0.012, drop - 0.1, Vector3(0, h - (drop - 0.1) / 2 - 0.02, 0), "laton")
	M.sphere(root, 0.06, Vector3(0, y0 + 0.1, 0), "laton", Vector3(1, 1.3, 1))
	M.cyl(root, 0.0, 0.03, 0.08, Vector3(0, y0 + 0.0, 0), "laton", Vector3(180, 0, 0), 10)
	var S = load("res://world/props/street.gd")
	for k in arms:
		var a := TAU * k / arms
		var d := Vector3(cos(a), 0, sin(a))
		var tip := d * 0.32 + Vector3(0, y0 + 0.12, 0)
		M.arc(root, Vector3(0, y0 + 0.1, 0) + d * 0.16, 0.16, -d, Vector3.DOWN, 0.0, PI, 6, 0.008, "laton")
		M.capsule_ab(root, 0.008, tip + Vector3(0, -0.02, 0), tip + Vector3(0, 0.06, 0), "laton")
		M.cyl(root, 0.06, 0.03, 0.09, tip + Vector3(0, 0.1, 0), "vela", Vector3.ZERO, 14)
		M.sphere(root, 0.012, tip + Vector3(0, 0.08, 0), "gas_emisivo" if lit else "vela", Vector3(1, 1.5, 1), 8)
		if lit: S.light_anchor(root, tip + Vector3(0, 0.09, 0), Color("ffb45e"), 1.6, 5.5, "gas")
	root.set_meta("occ", [])
	return root
