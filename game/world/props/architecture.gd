# world/props/architecture.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.2 (biblioteca base).
# Convención de props: origen = centro del piso de la huella; Y arriba; frente hacia +Z; metros.
# Cada build_* devuelve Node3D con meta "occ" (Array[AABB] local). Los cuartos además crean grupos de corte
# (meta "cut_n" normal interior, "cut_p" punto del plano, "occ" cajas locales al prop): WorldRoot oculta el muro
# (y desactiva su oclusor) cuando la cámara queda del lado de afuera → diorama en corte («casa de muñecas»).
extends RefCounted

const M = preload("res://world/materials.gd")

# ======================================================================================
# Muro genérico por franjas: perfil superior lineal a trozos + vanos rectangulares.
# Coordenadas locales del muro: x a lo largo (−L/2..L/2), y arriba, grosor en z (−t/2..t/2), cara interior +z.
# profile: [[x, top_y], ...] con x crecientes. openings: [{x, w, h, sill}] (x = centro).
# bands: [[y0, y1, mat]] materiales por altura (opcional). Devuelve cajas AABB en coords del muro.
static func wall_strips(parent: Node3D, L: float, t: float, profile: Array, openings: Array, mat: String, bands: Array = [], arch_tops: bool = false) -> Array:
	var xs: Array = []
	for pt in profile: xs.append(clampf(float(pt[0]), -L / 2.0, L / 2.0))
	xs.append(-L / 2.0); xs.append(L / 2.0)
	for o in openings:
		var ox := float(o["x"]); var ow := float(o["w"])
		xs.append(clampf(ox - ow / 2.0, -L / 2.0, L / 2.0)); xs.append(clampf(ox + ow / 2.0, -L / 2.0, L / 2.0))
		if arch_tops and bool(o.get("arch", false)):
			for k in range(1, 8):
				xs.append(ox - ow / 2.0 + ow * k / 8.0)
	xs.sort()
	var uniq: Array = []
	for x in xs:
		if uniq.is_empty() or x - uniq[-1] > 0.0005: uniq.append(x)
	var boxes: Array = []
	for i in uniq.size() - 1:
		var x0: float = uniq[i]; var x1: float = uniq[i + 1]
		var sw := x1 - x0
		if sw < 0.001: continue
		var xm := (x0 + x1) * 0.5
		var t0 := _prof(profile, x0); var t1 := _prof(profile, x1)
		var tmin := minf(t0, t1); var tmax := maxf(t0, t1)
		var holes: Array = []
		for o in openings:
			var ox := float(o["x"]); var ow := float(o["w"])
			if ox - ow / 2.0 <= x0 + 0.0005 and ox + ow / 2.0 >= x1 - 0.0005:
				var s := float(o.get("sill", 0.0)); var oh := float(o["h"])
				var top := s + oh
				if arch_tops and bool(o.get("arch", false)):
					var r := ow / 2.0
					var dx := absf(xm - ox)
					top = s + oh - r + sqrt(maxf(r * r - dx * dx, 0.0))
				holes.append([s, top])
		holes.sort_custom(func(a, b): return a[0] < b[0])
		var cur := 0.0
		var spans: Array = []
		for hseg in holes:
			if hseg[0] > cur + 0.001: spans.append([cur, minf(hseg[0], tmin)])
			cur = maxf(cur, hseg[1])
		if tmin > cur + 0.001: spans.append([cur, tmin])
		for sp in spans:
			if sp[1] - sp[0] < 0.001: continue
			for piece in _split_bands(sp[0], sp[1], bands, mat):
				M.box(parent, Vector3(sw, piece[1] - piece[0], t), Vector3(xm, (piece[0] + piece[1]) * 0.5, 0), piece[2])
			boxes.append(M.aabb_mm(Vector3(x0, sp[0], -t / 2), Vector3(x1, sp[1], t / 2)))
		if tmax - tmin > 0.002 and cur <= tmin + 0.001:
			var ltr := 0.0 if t0 > t1 else 1.0
			var m2: String = _band_mat(tmin, tmax, bands, mat)
			M.prism(parent, Vector3(sw, tmax - tmin, t), Vector3(xm, (tmin + tmax) * 0.5, 0), m2, Vector3.ZERO, ltr)
			boxes.append(M.aabb_mm(Vector3(x0, tmin, -t / 2), Vector3(x1, tmax, t / 2)))
	return boxes

static func _prof(profile: Array, x: float) -> float:
	if profile.size() == 1: return float(profile[0][1])
	if x <= float(profile[0][0]): return float(profile[0][1])
	for i in profile.size() - 1:
		var a = profile[i]; var b = profile[i + 1]
		if x <= float(b[0]) + 0.00001:
			var span := float(b[0]) - float(a[0])
			if span < 0.00001: return float(b[1])
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / span)
	return float(profile[-1][1])

static func _split_bands(y0: float, y1: float, bands: Array, mat: String) -> Array:
	if bands.is_empty(): return [[y0, y1, mat]]
	var cuts: Array = [y0, y1]
	for b in bands:
		for y in [float(b[0]), float(b[1])]:
			if y > y0 + 0.001 and y < y1 - 0.001: cuts.append(y)
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		out.append([cuts[i], cuts[i + 1], _band_mat(cuts[i], cuts[i + 1], bands, mat)])
	return out

static func _band_mat(y0: float, y1: float, bands: Array, mat: String) -> String:
	var ym := (y0 + y1) * 0.5
	for b in bands:
		if ym >= float(b[0]) and ym < float(b[1]): return str(b[2])
	return mat

static func cut_group(parent: Node3D, name: String, n_in: Vector3, p: Vector3) -> Node3D:
	var g := Node3D.new()
	g.name = name
	g.set_meta("cut_n", n_in)
	g.set_meta("cut_p", p)
	g.set_meta("occ", [])
	parent.add_child(g)
	return g

# ======================================================================================
# room(w,d,h,openings[{wall,kind,x,w,h,sill}],slope?)
# wall ∈ n(−Z) s(+Z) e(+X) w(−X); x = coordenada del mundo a lo largo del muro (X para n/s, Z para e/w).
# kind: window (sash_window), door (door), void (vano libre). Extras de opening: open, panes, curtains, paint.
# slope (opcional): {"wall": "n", "knee": 1.4, "run": 1.6} o lista de ellos → cielo raso inclinado junto a ese muro.
# Extras: wall (mat), floor (mat), ceiling (mat), t (grosor), dado (alto de friso; 0 = sin), dado_mat, cornice (bool).
static func build_room(p: Dictionary) -> Node3D:
	var root := M.root("room")
	var w := M.pf(p, "w", 5.0); var d := M.pf(p, "d", 4.4); var h := M.pf(p, "h", 3.0)
	var t := M.pf(p, "t", 0.16)
	var wall_m := M.ps(p, "wall", "papel_pintado")
	var slopes := {}
	var sl = p.get("slope", null)
	if sl is Dictionary: sl = [sl]
	if sl is Array:
		for s in sl:
			if s is Dictionary and s.has("wall"):
				slopes[str(s["wall"])] = {"knee": float(s.get("knee", h * 0.5)), "run": maxf(float(s.get("run", 1.5)), 0.05)}
	var ceil_fn := func(x: float, z: float) -> float:
		var c := h
		for side in slopes:
			var sp: Dictionary = slopes[side]
			var dist := 0.0
			match side:
				"n": dist = z + d / 2.0
				"s": dist = d / 2.0 - z
				"e": dist = w / 2.0 - x
				"w": dist = x + w / 2.0
			dist = maxf(dist, 0.0)
			c = minf(c, sp["knee"] + (h - sp["knee"]) * dist / sp["run"])
		return c
	# piso
	M.box(root, Vector3(w + 2 * t, 0.06, d + 2 * t), Vector3(0, -0.03, 0), M.ps(p, "floor", "suelo_tablas"))
	var occ_floor := [M.aabb_mm(Vector3(-w / 2 - t, -0.06, -d / 2 - t), Vector3(w / 2 + t, 0.0, d / 2 + t))]
	var ops: Array = p.get("openings", [])
	for side: String in ["n", "s", "e", "w"]:
		var along_x := side == "n" or side == "s"
		var L := (w + 2 * t) if along_x else d
		var sign := -1.0 if (side == "n" or side == "w") else 1.0
		var n_in := Vector3.ZERO
		var center := Vector3.ZERO
		var basis := Basis.IDENTITY
		# mapa x_mundo → x_local del muro
		var flip := 1.0
		match side:
			"n": n_in = Vector3(0, 0, 1); center = Vector3(0, 0, -d / 2 - t / 2); basis = Basis.IDENTITY; flip = 1.0
			"s": n_in = Vector3(0, 0, -1); center = Vector3(0, 0, d / 2 + t / 2); basis = Basis(Vector3.UP, PI); flip = -1.0
			"e": n_in = Vector3(-1, 0, 0); center = Vector3(w / 2 + t / 2, 0, 0); basis = Basis(Vector3.UP, -PI / 2); flip = 1.0
			"w": n_in = Vector3(1, 0, 0); center = Vector3(-w / 2 - t / 2, 0, 0); basis = Basis(Vector3.UP, PI / 2); flip = -1.0
		var g := cut_group(root, "wall_" + side, n_in, center + n_in * (t / 2.0))
		var wn := Node3D.new(); wn.name = "body"; g.add_child(wn)
		wn.transform = Transform3D(basis, center)
		# perfil
		var bx: Array = [-L / 2.0, L / 2.0]
		for s2 in slopes:
			var r2: float = slopes[s2]["run"]
			if along_x and (s2 == "e" or s2 == "w"):
				bx.append(flip * ((w / 2.0 - r2) if s2 == "e" else (-w / 2.0 + r2)))
			if (not along_x) and (s2 == "n" or s2 == "s"):
				bx.append(flip * ((d / 2.0 - r2) if s2 == "s" else (-d / 2.0 + r2)))
		bx.sort()
		var prof: Array = []
		for lx in bx:
			var wx := float(lx) * flip
			var c: float
			if along_x: c = ceil_fn.call(wx, -d / 2.0 if side == "n" else d / 2.0)
			else: c = ceil_fn.call(w / 2.0 if side == "e" else -w / 2.0, wx)
			prof.append([lx, c])
		var my_ops: Array = []
		for o in ops:
			if str(o.get("wall", "")) == side:
				var oo: Dictionary = o.duplicate()
				oo["x"] = float(o.get("x", 0.0)) * flip
				oo["w"] = float(o.get("w", 1.0)); oo["h"] = float(o.get("h", 2.0)); oo["sill"] = float(o.get("sill", 0.0))
				my_ops.append(oo)
		for o in my_ops:
			var top: float = o["sill"] + o["h"]
			if top > _prof(prof, o["x"] - o["w"] / 2.0) + 0.001 or top > _prof(prof, o["x"] + o["w"] / 2.0) + 0.001:
				push_warning("room: el vano %s del muro %s supera el cielo raso en sus bordes (x=%.2f)" % [o.get("kind", "?"), side, o["x"] * flip])
		var boxes := wall_strips(wn, L, t, prof, my_ops, wall_m)
		var occ: Array = []
		for b in boxes: occ.append(wn.transform * b)
		# zócalo y friso y cornisa en la cara interior (z local = +t/2)
		var inner := Node3D.new(); inner.name = "trim"; wn.add_child(inner)
		var skirt_ops: Array = []
		for o in my_ops:
			if o["sill"] < 0.2: skirt_ops.append(o)
		_trim_run(inner, L, t / 2.0 + 0.012, 0.0, 0.2, 0.024, skirt_ops, "madera_oscura", w if along_x else d, along_x)
		var dado := M.pf(p, "dado", 0.0)
		if dado > 0.0:
			var dado_ops: Array = []
			for o in my_ops:
				if o["sill"] < dado + 0.03 and o["sill"] + o["h"] > dado - 0.03: dado_ops.append(o)
			_trim_run(inner, L, t / 2.0 + 0.004, 0.2, dado, 0.008, dado_ops, M.ps(p, "dado_mat", "madera_media"), w if along_x else d, along_x)
			_trim_run(inner, L, t / 2.0 + 0.014, dado - 0.02, dado + 0.025, 0.028, dado_ops, "madera_oscura", w if along_x else d, along_x)
		if M.pb(p, "cornice", true):
			var flat := true
			for pt in prof:
				if absf(float(pt[1]) - h) > 0.01: flat = false
			if flat:
				_trim_run(inner, L, t / 2.0 + 0.05, h - 0.1, h, 0.1, [], "yeso", w if along_x else d, along_x)
		# contenido de vanos
		for o in my_ops:
			var kind := str(o.get("kind", "void"))
			var holder := Node3D.new(); holder.name = "op_" + kind
			wn.add_child(holder)
			holder.position = Vector3(o["x"], o["sill"], 0)
			if kind == "window":
				var sw := build_sash_window({"w": o["w"], "h": o["h"], "open_frac": o.get("open", 0.0), "panes": o.get("panes", 2), "paint": o.get("paint", "vela"), "depth": t * 0.8})
				holder.add_child(sw)
				# repisa interior
				M.box(holder, Vector3(o["w"] + 0.12, 0.03, 0.12), Vector3(0, -0.015, t / 2.0 + 0.04), "madera_media")
				if bool(o.get("curtains", false)):
					_curtains(holder, o["w"], o["h"], t / 2.0 + 0.09, M.ps(o, "curtain_mat", "terciopelo"))
			elif kind == "door":
				var dr := build_door({"w": o["w"], "h": o["h"], "open_frac": o.get("open", 0.0), "paint": o.get("paint", "madera_oscura"), "depth": t})
				holder.add_child(dr)
				if float(o.get("open", 0.0)) < 0.3:
					for b in dr.get_meta("occ", []): occ.append(wn.transform * holder.transform * b)
		g.set_meta("occ", occ)
	# cielo raso: plano y faldones
	var x0: float = -w / 2.0 + (slopes["w"]["run"] if slopes.has("w") else 0.0)
	var x1: float = w / 2.0 - (slopes["e"]["run"] if slopes.has("e") else 0.0)
	var z0: float = -d / 2.0 + (slopes["n"]["run"] if slopes.has("n") else 0.0)
	var z1: float = d / 2.0 - (slopes["s"]["run"] if slopes.has("s") else 0.0)
	var ceil_m := M.ps(p, "ceiling", "yeso")
	if x1 > x0 + 0.01 and z1 > z0 + 0.01:
		var gc := cut_group(root, "ceiling", Vector3.DOWN, Vector3(0, h, 0))
		M.box(gc, Vector3(x1 - x0 + 0.02, 0.06, z1 - z0 + 0.02), Vector3((x0 + x1) / 2, h + 0.03, (z0 + z1) / 2), ceil_m)
		gc.set_meta("occ", [M.aabb_mm(Vector3(x0, h, z0), Vector3(x1, h + 0.06, z1))])
	for side in slopes:
		var sp: Dictionary = slopes[side]
		var knee: float = sp["knee"]; var run: float = sp["run"]
		var rise := h - knee
		var length := sqrt(run * run + rise * rise)
		var ang := atan2(rise, run)
		var gs: Node3D
		var pc: Vector3
		var n_in: Vector3
		var mi: MeshInstance3D
		match side:
			"e":
				pc = Vector3(w / 2.0 - run / 2.0, knee + rise / 2.0, 0)
				n_in = Vector3(-sin(ang), -cos(ang), 0)
				gs = cut_group(root, "slope_e", n_in, pc)
				mi = M.box(gs, Vector3(length + 0.1, 0.07, d + 2 * t), pc - n_in * 0.035, ceil_m, Vector3(0, 0, -rad_to_deg(ang)))
			"w":
				pc = Vector3(-w / 2.0 + run / 2.0, knee + rise / 2.0, 0)
				n_in = Vector3(sin(ang), -cos(ang), 0)
				gs = cut_group(root, "slope_w", n_in, pc)
				mi = M.box(gs, Vector3(length + 0.1, 0.07, d + 2 * t), pc - n_in * 0.035, ceil_m, Vector3(0, 0, rad_to_deg(ang)))
			"n":
				pc = Vector3(0, knee + rise / 2.0, -d / 2.0 + run / 2.0)
				n_in = Vector3(0, -cos(ang), sin(ang))
				gs = cut_group(root, "slope_n", n_in, pc)
				mi = M.box(gs, Vector3(w + 2 * t, 0.07, length + 0.1), pc - n_in * 0.035, ceil_m, Vector3(-rad_to_deg(ang), 0, 0))
			"s":
				pc = Vector3(0, knee + rise / 2.0, d / 2.0 - run / 2.0)
				n_in = Vector3(0, -cos(ang), -sin(ang))
				gs = cut_group(root, "slope_s", n_in, pc)
				mi = M.box(gs, Vector3(w + 2 * t, 0.07, length + 0.1), pc - n_in * 0.035, ceil_m, Vector3(rad_to_deg(ang), 0, 0))
		if gs != null:
			gs.set_meta("occ", [mi.transform])  # caja orientada (Transform3D con escala = tamaño)
			# vigas a la vista (cabios) para leer el faldón
			var nb := int((d if side in ["e", "w"] else w) / 0.6)
			for k in nb + 1:
				var u := -((d if side in ["e", "w"] else w) / 2.0) + k * ((d if side in ["e", "w"] else w) / maxf(nb, 1))
				var a: Vector3; var b: Vector3
				match side:
					"e": a = Vector3(w / 2.0, knee, u); b = Vector3(w / 2.0 - run, h, u)
					"w": a = Vector3(-w / 2.0, knee, u); b = Vector3(-w / 2.0 + run, h, u)
					"n": a = Vector3(u, knee, -d / 2.0); b = Vector3(u, h, -d / 2.0 + run)
					"s": a = Vector3(u, knee, d / 2.0); b = Vector3(u, h, d / 2.0 - run)
				M.beam_ab(gs, a + n_in * 0.04, b + n_in * 0.04, 0.07, 0.07, "madera_media")
	root.set_meta("occ", occ_floor)
	return root

# moldura corrida a lo largo del muro (coords del muro), cortada por vanos
static func _trim_run(parent: Node3D, L: float, z: float, y0: float, y1: float, depth: float, ops: Array, mat: String, inner_len: float, along_x: bool) -> void:
	var a := -inner_len / 2.0
	var b := inner_len / 2.0
	var segs: Array = [[a, b]]
	for o in ops:
		var o0: float = o["x"] - o["w"] / 2.0 - 0.06
		var o1: float = o["x"] + o["w"] / 2.0 + 0.06
		var ns: Array = []
		for s in segs:
			if o1 <= s[0] or o0 >= s[1]: ns.append(s); continue
			if o0 > s[0]: ns.append([s[0], o0])
			if o1 < s[1]: ns.append([o1, s[1]])
		segs = ns
	for s in segs:
		if s[1] - s[0] > 0.01:
			M.box(parent, Vector3(s[1] - s[0], y1 - y0, depth), Vector3((s[0] + s[1]) / 2.0, (y0 + y1) / 2.0, z - depth / 2.0 + 0.004), mat)

static func _curtains(parent: Node3D, ow: float, oh: float, z: float, mat: String) -> void:
	# cortinas pesadas recogidas a los lados + barral de latón
	M.rod(parent, 0.015, ow + 0.6, Vector3(0, oh + 0.12, z), "laton", Vector3(0, 0, 90))
	for side: float in [-1.0, 1.0]:
		var cx := side * (ow / 2.0 + 0.12)
		for f in 4:
			var fx := cx + side * (f - 1.5) * 0.06
			M.cyl(parent, 0.045, 0.06, oh + 0.3, Vector3(fx, (oh + 0.12) / 2.0 - 0.05, z + 0.02 * (f % 2)), mat, Vector3.ZERO, 8)
		M.torus(parent, 0.04, 0.07, Vector3(cx, oh * 0.45, z + 0.04), "laton", Vector3(90, 0, 0), Vector3(1.6, 1, 1))

# ======================================================================================
# attic(w,d,h,slope): buhardilla con faldones a ambos lados largos (e/w), muros piñón n/s. slope = grados del faldón.
# Extras: knee (alto del muro bajo, def 1.1), openings (como room; usar n/s para ventanas), wall, floor.
static func build_attic(p: Dictionary) -> Node3D:
	var w := M.pf(p, "w", 4.6); var h := M.pf(p, "h", 2.9)
	var knee := M.pf(p, "knee", 1.1)
	var ang := deg_to_rad(clampf(M.pf(p, "slope", 45.0), 15.0, 75.0))
	var run := minf((h - knee) / tan(ang), w / 2.0 - 0.3)
	var q := p.duplicate()
	q["w"] = w; q["h"] = h
	q["slope"] = [{"wall": "e", "knee": knee, "run": run}, {"wall": "w", "knee": knee, "run": run}]
	if not q.has("wall"): q["wall"] = "papel_pintado"
	var r := build_room(q)
	r.name = "attic"
	return r

# ======================================================================================
# sash_window(w,h,open_frac,panes): guillotina. Origen = centro inferior del marco; frente (+Z) = interior.
# Extras: paint (mat del marco), depth, sill_out (alféizar exterior de piedra, def true).
static func build_sash_window(p: Dictionary) -> Node3D:
	var root := M.root("sash_window")
	var w := M.pf(p, "w", 1.0); var h := M.pf(p, "h", 1.6)
	var of := clampf(M.pf(p, "open_frac", 0.0), 0.0, 1.0)
	var panes := M.pi_(p, "panes", 2)
	var paint := M.ps(p, "paint", "vela")
	var dep := M.pf(p, "depth", 0.12)
	var fr := 0.06
	# marco
	M.box(root, Vector3(w, fr, dep), Vector3(0, h - fr / 2, 0), paint)
	M.box(root, Vector3(w, fr * 0.8, dep), Vector3(0, fr * 0.4, 0), paint)
	M.box(root, Vector3(fr, h, dep), Vector3(-w / 2 + fr / 2, h / 2, 0), paint)
	M.box(root, Vector3(fr, h, dep), Vector3(w / 2 - fr / 2, h / 2, 0), paint)
	var iw := w - 2 * fr
	var ih := h - fr - fr * 0.8
	var sh := ih / 2.0 + 0.02
	var y_low := fr * 0.8 + of * (ih / 2.0 - 0.04)
	_sash(root, iw, sh, Vector3(0, fr * 0.8 + ih - sh / 2.0, -0.025), panes, paint, false)
	_sash(root, iw, sh, Vector3(0, y_low + sh / 2.0, 0.025), panes, paint, true)
	# alféizar de piedra exterior
	if M.pb(p, "sill_out", true):
		M.box(root, Vector3(w + 0.14, 0.06, 0.16), Vector3(0, -0.03, -dep / 2 - 0.06), "piedra_portland")
	# sólo el marco ocluye: por el vidrio se ve (Wiggins en la calle, etc.)
	var occ := [M.aabb_mm(Vector3(-w / 2, h - fr, -dep / 2), Vector3(w / 2, h, dep / 2)), M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(w / 2, fr * 0.8, dep / 2)),
		M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(-w / 2 + fr, h, dep / 2)), M.aabb_mm(Vector3(w / 2 - fr, 0, -dep / 2), Vector3(w / 2, h, dep / 2))]
	root.set_meta("occ", occ)
	return root

static func _sash(parent: Node3D, w: float, h: float, c: Vector3, panes: int, paint: String, lower: bool) -> void:
	var s := 0.045
	var n := Node3D.new(); n.name = "sash_low" if lower else "sash_up"; n.position = c; parent.add_child(n)
	M.box(n, Vector3(w, s * (1.4 if not lower else 1.0), 0.04), Vector3(0, h / 2 - s * 0.5, 0), paint)
	M.box(n, Vector3(w, s * (1.0 if not lower else 1.4), 0.04), Vector3(0, -h / 2 + s * 0.5, 0), paint)
	M.box(n, Vector3(s, h, 0.04), Vector3(-w / 2 + s / 2, 0, 0), paint)
	M.box(n, Vector3(s, h, 0.04), Vector3(w / 2 - s / 2, 0, 0), paint)
	M.box(n, Vector3(w - 2 * s, h - 2 * s, 0.006), Vector3(0, 0, 0), "vidrio")
	var cols := 1; var rows := 1
	match panes:
		1: cols = 1; rows = 1
		2: cols = 2; rows = 1
		3: cols = 3; rows = 1
		4: cols = 2; rows = 2
		6: cols = 3; rows = 2
		8: cols = 4; rows = 2
		9: cols = 3; rows = 3
		12: cols = 4; rows = 3
		_: cols = maxi(1, panes / 2); rows = 2 if panes > 3 else 1
	for i in range(1, cols):
		M.box(n, Vector3(0.022, h - 2 * s, 0.03), Vector3(-w / 2 + s + (w - 2 * s) * i / cols, 0, 0), paint)
	for j in range(1, rows):
		M.box(n, Vector3(w - 2 * s, 0.022, 0.03), Vector3(0, -h / 2 + s + (h - 2 * s) * j / rows, 0), paint)
	if lower:
		for sx: float in [-0.25, 0.25]:
			M.box(n, Vector3(0.04, 0.02, 0.02), Vector3(sx * w, -h / 2 + 0.02, 0.03), "laton")
		M.box(n, Vector3(0.07, 0.015, 0.03), Vector3(0, h / 2 - 0.005, 0.02), "laton")

# ======================================================================================
# door(w,h,open_frac): puerta de cuatro tableros con marco y moldura. Origen = centro del umbral; frente +Z.
# Abre hacia +Z girando sobre la bisagra izquierda (−X). Extras: paint, depth (grosor del muro), panels (4|6), fanlight.
static func build_door(p: Dictionary) -> Node3D:
	var root := M.root("door")
	var w := M.pf(p, "w", 0.9); var h := M.pf(p, "h", 2.1)
	var of := clampf(M.pf(p, "open_frac", 0.0), 0.0, 1.0)
	var paint := M.ps(p, "paint", "madera_oscura")
	var dep := M.pf(p, "depth", 0.16)
	var trim := "madera_media" if paint != "madera_media" else "madera_oscura"
	# jambas y dintel (forro) + molduras en ambas caras
	M.box(root, Vector3(0.04, h, dep), Vector3(-w / 2 + 0.02, h / 2, 0), trim)
	M.box(root, Vector3(0.04, h, dep), Vector3(w / 2 - 0.02, h / 2, 0), trim)
	M.box(root, Vector3(w, 0.04, dep), Vector3(0, h - 0.02, 0), trim)
	for zf: float in [1.0, -1.0]:
		M.box(root, Vector3(0.09, h + 0.09, 0.025), Vector3(-w / 2 - 0.03, (h + 0.09) / 2, zf * (dep / 2 + 0.012)), trim)
		M.box(root, Vector3(0.09, h + 0.09, 0.025), Vector3(w / 2 + 0.03, (h + 0.09) / 2, zf * (dep / 2 + 0.012)), trim)
		M.box(root, Vector3(w + 0.24, 0.1, 0.03), Vector3(0, h + 0.05, zf * (dep / 2 + 0.015)), trim)
	# hoja
	var hinge := Node3D.new(); hinge.name = "hinge"; hinge.position = Vector3(-w / 2 + 0.04, 0, dep / 2 - 0.03)
	root.add_child(hinge)
	hinge.rotation_degrees = Vector3(0, -of * 100.0, 0)
	var lw := w - 0.08; var lh := h - 0.05
	var leaf := Node3D.new(); leaf.name = "leaf"; leaf.position = Vector3(lw / 2, 0, 0); hinge.add_child(leaf)
	M.box(leaf, Vector3(lw, lh, 0.045), Vector3(0, lh / 2 + 0.01, 0), paint)
	var six := M.pi_(p, "panels", 4) == 6
	var rows: Array = [[0.12, 0.42], [0.47, 0.95]] if not six else [[0.1, 0.38], [0.42, 0.68], [0.72, 0.95]]
	for zf: float in [1.0, -1.0]:
		for r in rows:
			for cx: float in [-0.25, 0.25]:
				var py0: float = r[0] * lh; var py1: float = r[1] * lh
				M.box(leaf, Vector3(lw * 0.36, py1 - py0, 0.012), Vector3(cx * lw, (py0 + py1) / 2 + 0.01, zf * 0.026), "madera_negra" if paint == "madera_oscura" else trim)
				M.box(leaf, Vector3(lw * 0.3, py1 - py0 - 0.06, 0.008), Vector3(cx * lw, (py0 + py1) / 2 + 0.01, zf * 0.034), paint)
		M.sphere(leaf, 0.028, Vector3(lw / 2 - 0.08, 0.98, zf * 0.05), "laton")
		M.box(leaf, Vector3(0.04, 0.09, 0.006), Vector3(lw / 2 - 0.08, 0.9, zf * 0.026), "laton")
	if M.pb(p, "fanlight", false):
		M.box(root, Vector3(w, 0.06, dep), Vector3(0, h + 0.03, 0), trim)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -dep / 2), Vector3(w / 2, h, dep / 2))])
	return root

# ======================================================================================
# facade(w,h,floors,bays,door_bay,shop_front,style:"stock_brick"|"estuco"): fachada de terraza londinense.
# Origen = centro del pie de la fachada (vereda, y=0); frente +Z; el edificio se extiende hacia −Z (depth).
# Extras: depth (def 0.8), area (verjas del patio inglés, def !shop_front), steps (escalones al portal), sign (rótulo),
# number (número del portal), chimneys (def true), parapet (def true), blinds (persianas a medio bajar por seed), seed.
static func build_facade(p: Dictionary) -> Node3D:
	var root := M.root("facade")
	var w := M.pf(p, "w", 6.0); var h := M.pf(p, "h", 12.0)
	var floors := maxi(M.pi_(p, "floors", 4), 1)
	var bays := maxi(M.pi_(p, "bays", 3), 1)
	var door_bay := M.pi_(p, "door_bay", 0)
	var shop := M.pb(p, "shop_front", false)
	var style := M.ps(p, "style", "stock_brick")
	var seed := M.seed_of(p, "facade")
	var t := 0.3
	var depth := M.pf(p, "depth", 0.8)
	var brick := "ladrillo_stock" if style == "stock_brick" else "estuco"
	if M.ps(p, "brick", "") != "": brick = M.ps(p, "brick", "")
	var stucco := "estuco"
	# alturas de piso: planta baja más alta, piano nobile, luego decrecientes
	var weights: Array = []
	for f in floors: weights.append([1.25, 1.15, 1.0, 0.9, 0.8, 0.75][mini(f, 5)])
	var tot := 0.0
	for x in weights: tot += x
	var parapet_h := 0.7 if M.pb(p, "parapet", true) else 0.0
	var body_h := h - parapet_h
	var fl_y: Array = [0.0]
	for f in floors: fl_y.append(fl_y[-1] + body_h * weights[f] / tot)
	var bay_w := w / bays
	var ops: Array = []
	var ground_h: float = fl_y[1]
	for f in floors:
		var fh: float = fl_y[f + 1] - fl_y[f]
		for b in bays:
			var cx := -w / 2 + bay_w * (b + 0.5)
			if f == 0:
				if shop:
					if b == door_bay:
						ops.append({"x": cx, "w": minf(bay_w * 0.55, 1.1), "h": 2.4, "sill": 0.15, "kind": "shopdoor"})
					else:
						ops.append({"x": cx, "w": bay_w * 0.86, "h": fh - 1.25, "sill": 0.6, "kind": "shopwin"})
				elif b == door_bay:
					ops.append({"x": cx, "w": minf(bay_w * 0.5, 1.15), "h": minf(fh - 0.55, 3.0), "sill": 0.45, "kind": "door"})
				else:
					ops.append({"x": cx, "w": minf(bay_w * 0.48, 1.15), "h": fh * 0.6, "sill": fh * 0.25, "kind": "window"})
			else:
				var wh := fh * (0.62 if f == 1 else 0.58)
				ops.append({"x": cx, "w": minf(bay_w * 0.45, 1.1), "h": wh, "sill": fl_y[f] + fh * 0.18, "kind": "window", "floor": f})
	# muro
	var bands: Array = []
	if style == "stock_brick" and not shop: bands.append([0.0, ground_h, stucco])
	if shop: bands.append([0.0, ground_h, "madera_negra"])
	var wn := Node3D.new(); wn.name = "wall"; wn.position = Vector3(0, 0, -t / 2); root.add_child(wn)
	var wall_ops: Array = []
	for o in ops:
		var oo: Dictionary = o.duplicate()
		wall_ops.append(oo)
	var wboxes := wall_strips(wn, w, t, [[-w / 2, body_h]], wall_ops, brick, bands)
	var focc: Array = []
	for b in wboxes: focc.append(wn.transform * b)
	# cuerpo del edificio detrás (oscuro: no se ve salvo por los vanos)
	M.box(root, Vector3(w - 0.02, body_h - 0.02, 0.05), Vector3(0, body_h / 2, -depth), "interior_oscuro")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.14, h, depth), Vector3(sx * (w / 2 - 0.07), h / 2, -depth / 2 - 0.02), brick)
	for o in ops:
		var kind: String = o["kind"]
		var ox: float = o["x"]; var ow: float = o["w"]; var oh: float = o["h"]; var os: float = o["sill"]
		var nh := Node3D.new(); nh.name = "op_" + kind; nh.position = Vector3(ox, os, -0.12); root.add_child(nh)
		M.box(root, Vector3(ow + 0.02, oh + 0.02, 0.04), Vector3(ox, os + oh / 2, -t - 0.06), "interior_oscuro")
		match kind:
			"window":
				nh.add_child(build_sash_window({"w": ow, "h": oh, "panes": 2 if int(o.get("floor", 0)) != floors - 1 else 4, "paint": "vela", "depth": 0.1, "open_frac": 0.15 if M.rnd(seed, int(ox * 10), int(os)) < 0.15 else 0.0}))
				# dintel de ladrillo a sardinel / arquitrabe de estuco
				M.box(root, Vector3(ow + 0.12, 0.16, 0.05), Vector3(ox, os + oh + 0.08, 0.02), stucco if style == "estuco" else "ladrillo_hollin")
				if M.pb(p, "blinds", true) and M.rnd(seed, int(ox * 7 + 3), int(os * 3)) < 0.45:
					var bl := M.rr(seed, int(ox * 5), int(os * 5), 0.2, 0.55)
					M.box(nh, Vector3(ow - 0.12, oh * bl, 0.01), Vector3(0, oh - oh * bl / 2 - 0.06, -0.08), "lienzo")
				if style == "estuco" and int(o.get("floor", 0)) == 1:
					# frontón triangular sobre el piano nobile
					M.prism(root, Vector3(ow + 0.3, 0.28, 0.1), Vector3(ox, os + oh + 0.32, 0.04), stucco)
			"door":
				nh.add_child(build_door({"w": ow, "h": oh * 0.78, "paint": M.ps(p, "door_paint", "madera_negra"), "depth": 0.12, "panels": 6}))
				# montante (fanlight) con radios
				var fy := oh * 0.78
				M.box(nh, Vector3(ow, 0.05, 0.1), Vector3(0, fy + 0.025, 0), "vela")
				M.box(nh, Vector3(ow - 0.08, oh - fy - 0.08, 0.006), Vector3(0, fy + (oh - fy) / 2, 0), "vidrio")
				for k in 5:
					var a := PI * (k + 1) / 6.0
					var c := Vector3(0, fy + 0.05, 0.02)
					M.beam_ab(nh, c, c + Vector3(cos(a) * ow * 0.45, sin(a) * (oh - fy - 0.1), 0), 0.02, 0.02, "vela")
				# portada: pilastras + entablamento
				for sx: float in [-1.0, 1.0]:
					M.box(root, Vector3(0.16, oh + 0.1, 0.12), Vector3(ox + sx * (ow / 2 + 0.1), os + (oh + 0.1) / 2, 0.06), stucco)
				M.box(root, Vector3(ow + 0.6, 0.22, 0.22), Vector3(ox, os + oh + 0.2, 0.1), stucco)
				M.box(root, Vector3(ow + 0.7, 0.06, 0.28), Vector3(ox, os + oh + 0.34, 0.12), stucco)
				# escalones
				var nsteps := maxi(int(os / 0.15), 1)
				for k in nsteps:
					var sy := os * (k + 1) / nsteps
					M.box(root, Vector3(ow + 0.5, os / nsteps, 0.32 * (nsteps - k)), Vector3(ox, sy - os / nsteps / 2, 0.16 * (nsteps - k)), "piedra_portland")
				var num := M.ps(p, "number", "")
				if num != "":
					M.label3d(root, num, Vector3(ox, os + oh * 0.86, 0.035), 0.004, 40, Color("efe6d2"))
			"shopwin":
				M.box(nh, Vector3(ow, oh, 0.01), Vector3(0, oh / 2, 0), "vidrio")
				for k in 3:
					M.box(nh, Vector3(0.035, oh, 0.05), Vector3(-ow / 2 + ow * (k + 1) / 4.0, oh / 2, 0.01), "madera_negra")
				M.box(nh, Vector3(ow, 0.05, 0.08), Vector3(0, oh - 0.4, 0.01), "madera_negra")
				M.box(nh, Vector3(ow + 0.05, 0.08, 0.2), Vector3(0, -0.04, 0.08), "madera_negra")
				# mercadería tras el vidrio: estantes con libros (tienda de viejo) o bultos
				for k in 3:
					M.box(nh, Vector3(ow * 0.9, 0.02, 0.25), Vector3(0, 0.25 + k * 0.45, -0.2), "madera_media")
					var bx: Array = []; var bc: Array = []
					var xx := -ow * 0.44
					var i := 0
					while xx < ow * 0.43 and i < 80:
						var bw := M.rr(seed, i, k * 13, 0.025, 0.06)
						var bh := M.rr(seed, i, k * 17, 0.18, 0.32)
						bx.append(M.xf_box(Vector3(bw, bh, 0.16), Vector3(xx + bw / 2, 0.26 + k * 0.45 + bh / 2, -0.2)))
						bc.append(_spine_color(seed, i + k * 100))
						xx += bw + 0.004; i += 1
					M.multi_boxes(nh, bx, bc)
			"shopdoor":
				nh.add_child(build_door({"w": ow, "h": oh, "paint": "madera_negra", "depth": 0.12}))
	# impostas por piso, cornisa, pretil, chimeneas
	for f in range(1, floors):
		M.box(root, Vector3(w + 0.04, 0.12, 0.08), Vector3(0, fl_y[f], 0.04), stucco)
	if shop:
		var fy: float = ground_h - 0.55
		M.box(root, Vector3(w, 0.5, 0.12), Vector3(0, fy + 0.25, 0.08), "madera_negra")
		M.box(root, Vector3(w + 0.1, 0.08, 0.22), Vector3(0, fy + 0.54, 0.1), "madera_negra")
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.22, ground_h, 0.14), Vector3(sx * (w / 2 - 0.11), ground_h / 2, 0.07), "madera_negra")
		var sign_txt := M.text_of(p, "sign_key")
		if sign_txt == "": sign_txt = M.ps(p, "sign", "")
		if sign_txt != "":
			M.label3d(root, sign_txt, Vector3(0, fy + 0.25, 0.145), 0.006, 56, Color("e8dcc0"))
	M.box(root, Vector3(w + 0.1, 0.18, 0.32), Vector3(0, body_h - 0.09, 0.12), stucco)
	M.box(root, Vector3(w + 0.16, 0.06, 0.4), Vector3(0, body_h + 0.02, 0.15), stucco)
	if parapet_h > 0:
		M.box(root, Vector3(w, parapet_h, t), Vector3(0, body_h + parapet_h / 2, -t / 2), brick)
		M.box(root, Vector3(w + 0.06, 0.06, t + 0.06), Vector3(0, h + 0.03, -t / 2), "piedra_portland")
	# techo de pizarra detrás del pretil
	M.box(root, Vector3(w, 0.06, depth * 1.3), Vector3(0, body_h + 0.45, -depth * 0.65), "pizarra", Vector3(-24, 0, 0))
	if M.pb(p, "chimneys", true):
		for sx: float in [-1.0, 1.0]:
			var cxp := sx * (w / 2 - 0.35)
			M.box(root, Vector3(0.6, 1.2, 0.5), Vector3(cxp, h + 0.6, -0.5), brick)
			M.box(root, Vector3(0.68, 0.08, 0.58), Vector3(cxp, h + 1.22, -0.5), "piedra_portland")
			for k in 3:
				M.cyl(root, 0.06, 0.08, 0.35, Vector3(cxp - 0.18 + k * 0.18, h + 1.43, -0.5), "cobre", Vector3.ZERO, 10)
	if M.pb(p, "area", not shop):
		var rl := build_railing({"len": w, "h": 1.05, "plinth": true, "gap_x": -w / 2 + bay_w * (door_bay + 0.5), "gap_w": minf(bay_w * 0.5, 1.15) + 0.5})
		rl.position = Vector3(0, 0, 1.4)
		root.add_child(rl)
	focc.append(M.aabb_mm(Vector3(-w / 2, body_h, -t), Vector3(w / 2, h, 0.0)))
	root.set_meta("occ", focc)
	return root

static func _spine_color(seed: int, i: int) -> Color:
	var pal := [Color("5a3a2a"), Color("6a2e26"), Color("3e4a3c"), Color("2f3440"), Color("7a6448"), Color("4a4036"), Color("8a7050"), Color("2c2a2c"), Color("a08a60"), Color("5e4e3c")]
	var c: Color = pal[int(M.rnd(seed, i, 99) * pal.size()) % pal.size()]
	var f := 0.82 + 0.36 * M.rnd(seed, i, 98)
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1))

# ======================================================================================
# dome(r,ribs): cúpula vista desde adentro (Sala de Lectura): tambor con ventanas, casquete, nervios, óculo y linterna.
# Origen = centro del arranque del tambor (y=0). Extras: drum (alto del tambor, def 0.32 r), windows (def = ribs).
static func build_dome(p: Dictionary) -> Node3D:
	var root := M.root("dome")
	var r := M.pf(p, "r", 6.0)
	var ribs := maxi(M.pi_(p, "ribs", 20), 4)
	var drum := M.pf(p, "drum", r * 0.32)
	# tambor: pilares radiales y paños de ventana luminosos
	for i in ribs:
		var a := TAU * i / ribs
		var a2 := TAU * (i + 0.5) / ribs
		var pc := Vector3(cos(a) * r, drum / 2, sin(a) * r)
		var pier := M.box(root, Vector3(0.35, drum, r * TAU / ribs * 0.35), pc, "yeso")
		pier.rotation = Vector3(0, -a, 0)
		var wc := Vector3(cos(a2) * (r + 0.05), drum * 0.55, sin(a2) * (r + 0.05))
		var win := M.box(root, Vector3(0.05, drum * 0.7, r * TAU / ribs * 0.55), wc, "cielo")
		win.rotation = Vector3(0, -a2, 0)
		var wall := M.box(root, Vector3(0.1, drum, r * TAU / ribs * 0.7), Vector3(cos(a2) * (r + 0.15), drum / 2, sin(a2) * (r + 0.15)), "yeso_sucio")
		wall.rotation = Vector3(0, -a2, 0)
	M.torus(root, r - 0.05, r + 0.35, Vector3(0, drum, 0), "yeso", Vector3.ZERO, Vector3(1, 0.6, 1))
	# casquete (caras hacia adentro)
	var sm := SphereMesh.new(); sm.radius = r + 0.2; sm.height = r + 0.2; sm.is_hemisphere = true
	sm.radial_segments = 48; sm.rings = 16; sm.flip_faces = true
	var cap := MeshInstance3D.new(); cap.mesh = sm; cap.material_override = M.mat("yeso"); cap.position = Vector3(0, drum, 0)
	cap.scale = Vector3(1, 0.82, 1)
	root.add_child(cap)
	# nervios: arcos por segmentos desde el tambor al óculo
	var oc := r * 0.16
	for i in ribs:
		var a := TAU * i / ribs
		var prev := Vector3.ZERO
		for k in 13:
			var th := lerpf(0.0, acos(oc / (r + 0.1)), k / 12.0)
			var rr := (r + 0.1) * cos(th)
			var pt := Vector3(cos(a) * rr, drum + (r + 0.1) * sin(th) * 0.82, sin(a) * rr)
			if k > 0: M.beam_ab(root, prev, pt, 0.18, 0.22, "yeso")
			prev = pt
	# casetones: anillos horizontales
	for k: float in [0.35, 0.62, 0.84]:
		var th: float = acos(clampf(k, 0, 1))
		M.torus(root, (r + 0.05) * k - 0.08, (r + 0.05) * k + 0.08, Vector3(0, drum + (r + 0.05) * sin(th) * 0.82, 0), "yeso")
	# óculo y linterna
	var oy := drum + sqrt(maxf((r + 0.1) * (r + 0.1) - oc * oc, 0)) * 0.82
	M.torus(root, oc - 0.1, oc + 0.15, Vector3(0, oy, 0), "yeso")
	M.cyl(root, oc - 0.05, oc - 0.05, 0.9, Vector3(0, oy + 0.45, 0), "cielo", Vector3.ZERO, 24)
	M.cyl(root, oc * 0.3, oc, 0.4, Vector3(0, oy + 1.1, 0), "yeso", Vector3.ZERO, 24)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# stairs(n,w,rise,run): escalera recta que sube hacia −Z desde el origen (primer escalón en z∈[−run,0]).
# Extras: rail ("left"|"right"|"both"|"none", def "right"), runner (alfombra con varillas, def true), mat.
static func build_stairs(p: Dictionary) -> Node3D:
	var root := M.root("stairs")
	var n := maxi(M.pi_(p, "n", 12), 1)
	var w := M.pf(p, "w", 0.95); var rise := M.pf(p, "rise", 0.18); var run := M.pf(p, "run", 0.26)
	var mat := M.ps(p, "mat", "madera_media")
	for i in n:
		var y1 := (i + 1) * rise
		M.box(root, Vector3(w, rise, run), Vector3(0, y1 - rise / 2, -i * run - run / 2), mat)
		M.box(root, Vector3(w + 0.02, 0.025, run + 0.03), Vector3(0, y1 - 0.0125, -i * run - run / 2 + 0.015), "madera_oscura")
	# macizo bajo la escalera
	var H := n * rise; var D := n * run
	M.prism(root, Vector3(D, H, w), Vector3(0, H / 2, -D / 2), mat, Vector3(0, 90, 0), 1.0)
	if M.pb(p, "runner", true):
		for i in n:
			var y1 := (i + 1) * rise
			M.box(root, Vector3(w * 0.6, 0.006, run), Vector3(0, y1 + 0.003, -i * run - run / 2), "terciopelo")
			M.box(root, Vector3(w * 0.6, rise, 0.006), Vector3(0, y1 - rise / 2, -i * run + 0.003), "terciopelo")
			M.rod(root, 0.006, w * 0.66, Vector3(0, i * rise + 0.01, -i * run + 0.01), "laton", Vector3(0, 0, 90))
	var rail := M.ps(p, "rail", "right")
	var sides: Array = []
	if rail == "left" or rail == "both": sides.append(-1.0)
	if rail == "right" or rail == "both": sides.append(1.0)
	for sx in sides:
		var x: float = sx * (w / 2 - 0.04)
		for i in n:
			for b in 2:
				var z := -i * run - run * (0.25 + 0.5 * b)
				var y0 := (i + 1) * rise
				M.cyl(root, 0.014, 0.018, 0.86, Vector3(x, y0 + 0.43, z), "madera_oscura", Vector3.ZERO, 8)
		var a := Vector3(x, rise + 0.9, -run * 0.25)
		var b2 := Vector3(x, n * rise + 0.9, -n * run + run * 0.25)
		M.beam_ab(root, a, b2, 0.06, 0.05, "caoba")
		M.cyl(root, 0.05, 0.06, 1.05, Vector3(x, 0.525, -0.05), "caoba", Vector3.ZERO, 8)
		M.sphere(root, 0.065, Vector3(x, 1.1, -0.05), "caoba")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -D), Vector3(w / 2, H, 0))])
	return root

# ======================================================================================
# railing(len,h): verja de hierro con lanzas; a lo largo de X, centrada. Extras: plinth (zócalo de piedra), gap_x/gap_w (portillo), spacing.
static func build_railing(p: Dictionary) -> Node3D:
	var root := M.root("railing")
	var L := M.pf(p, "len", 3.0); var h := M.pf(p, "h", 1.0)
	var sp := M.pf(p, "spacing", 0.12)
	var y0 := 0.0
	if M.pb(p, "plinth", true):
		M.box(root, Vector3(L, 0.22, 0.24), Vector3(0, 0.11, 0), "piedra_portland")
		y0 = 0.22
	var gx := M.pf(p, "gap_x", 1e9); var gw := M.pf(p, "gap_w", 0.0)
	var segs: Array = [[-L / 2, L / 2]]
	if gw > 0 and absf(gx) < L:
		segs = [[-L / 2, gx - gw / 2], [gx + gw / 2, L / 2]]
	var bars: Array = []
	var tips: Array = []
	for s in segs:
		var a: float = s[0]; var b: float = s[1]
		if b - a < 0.05: continue
		M.box(root, Vector3(b - a, 0.025, 0.025), Vector3((a + b) / 2, y0 + 0.08, 0), "hierro")
		M.box(root, Vector3(b - a, 0.025, 0.025), Vector3((a + b) / 2, y0 + h - 0.12, 0), "hierro")
		var nb := int((b - a) / sp)
		for k in nb + 1:
			var x := a + (b - a) * k / maxf(nb, 1)
			bars.append(M.xf_box(Vector3(0.016, h - 0.05, 0.016), Vector3(x, y0 + (h - 0.05) / 2, 0)))
			tips.append(Transform3D(Basis.IDENTITY, Vector3(x, y0 + h - 0.02, 0)))
		# postes de extremo con remate
		for x in [a, b]:
			M.box(root, Vector3(0.05, h + 0.05, 0.05), Vector3(x, y0 + (h + 0.05) / 2, 0), "hierro")
			M.sphere(root, 0.04, Vector3(x, y0 + h + 0.08, 0), "hierro")
	M.multi_boxes(root, bars, [], "hierro")
	if not tips.is_empty():
		M.multi_boxes(root, tips, [], "hierro", M.cyl_mesh(0.0, 0.02, 0.09, 6))
	# una verja se ve a través (barrotes cada `spacing`): sólo ocluyen el zócalo y los postes de extremo,
	# así lo que está detrás (macizo, figura, ventana del sótano) se puede clicar y recortar (§7.6)
	var occ: Array = []
	if y0 > 0.0: occ.append(M.aabb_mm(Vector3(-L / 2, 0, -0.12), Vector3(L / 2, y0, 0.12)))
	for s in segs:
		if float(s[1]) - float(s[0]) < 0.05: continue
		for x in [float(s[0]), float(s[1])]:
			occ.append(M.aabb_mm(Vector3(x - 0.025, y0, -0.025), Vector3(x + 0.025, y0 + h + 0.12, 0.025)))
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# eave(len,depth): alero saliente de pizarra con canaleta y ménsulas. Origen = línea del muro (y=0, z=0); sale hacia +Z.
static func build_eave(p: Dictionary) -> Node3D:
	var root := M.root("eave")
	var L := M.pf(p, "len", 3.0); var dp := M.pf(p, "depth", 0.6)
	var pitch := M.pf(p, "pitch", 30.0)
	var rad := deg_to_rad(pitch)
	var back_h := tan(rad) * dp
	M.box(root, Vector3(L, 0.05, dp / cos(rad) + 0.3), Vector3(0, back_h / 2 + 0.03, dp / 2 - 0.12), "pizarra", Vector3(pitch, 0, 0))
	M.box(root, Vector3(L, 0.14, 0.03), Vector3(0, -0.06, dp), "madera_negra")
	M.box(root, Vector3(L, 0.02, dp), Vector3(0, -0.12, dp / 2), "madera_media")
	M.cyl(root, 0.06, 0.06, L, Vector3(0, -0.02, dp + 0.07), "hierro", Vector3(0, 0, 90), 10)
	var nb := maxi(int(L / 0.7), 1)
	for k in nb + 1:
		var x := -L / 2 + L * k / nb
		M.prism(root, Vector3(0.08, 0.3, dp * 0.8), Vector3(x, -0.27, dp * 0.4), "madera_oscura", Vector3(-90, 0, 0), 0.0)
	root.set_meta("occ", [M.aabb_mm(Vector3(-L / 2, -0.45, 0), Vector3(L / 2, back_h + 0.1, dp + 0.13))])
	return root

# ======================================================================================
# arch(w,h): arco de medio punto con dovelas y clave, en un paño de muro. w = luz, h = altura a la clave (intradós).
# Extras: t (grosor), mat (def ladrillo_stock), stone (dovelas, def piedra_portland), wall_w (ancho total).
static func build_arch(p: Dictionary) -> Node3D:
	var root := M.root("arch")
	var w := M.pf(p, "w", 1.6); var h := M.pf(p, "h", 2.6)
	var t := M.pf(p, "t", 0.35)
	var r := w / 2.0
	var spring := maxf(h - r, 0.2)
	var W := M.pf(p, "wall_w", w + 1.0)
	var top := h + 0.55
	var mat := M.ps(p, "mat", "ladrillo_stock")
	var stone := M.ps(p, "stone", "piedra_portland")
	wall_strips(root, W, t, [[-W / 2, top]], [{"x": 0.0, "w": w, "h": h, "sill": 0.0, "arch": true}], mat, [], true)
	var nv := 11
	for k in nv:
		var a0 := PI * k / nv
		var a1 := PI * (k + 1) / nv
		var am := (a0 + a1) / 2
		var rm := r + 0.13
		var c := Vector3(cos(am) * rm, spring + sin(am) * rm, 0)
		var key := k == nv / 2
		var vb := M.box(root, Vector3(0.27 if not key else 0.36, r * (a1 - a0) + 0.005, t + (0.04 if not key else 0.08)), c + Vector3(0, 0.03 if key else 0.0, 0), stone)
		vb.rotation = Vector3(0, 0, am)
	# impostas
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.32, 0.1, t + 0.06), Vector3(sx * (r + 0.1), spring - 0.05, 0), stone)
	root.set_meta("occ", [M.aabb_mm(Vector3(-W / 2, 0, -t / 2), Vector3(-r, top, t / 2)), M.aabb_mm(Vector3(r, 0, -t / 2), Vector3(W / 2, top, t / 2)), M.aabb_mm(Vector3(-r, h, -t / 2), Vector3(r, top, t / 2))])
	return root
