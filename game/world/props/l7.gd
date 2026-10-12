# world/props/l7.gd — W2-PLACES-B. Lugar L7 (Park Lane 427, exterior) y lámina PARK (día 10, 18 h).
# Contrato: docs/ARCHITECTURE.md §7.2 (`"l7.<función>"` → build_<función>(p) -> Node3D con meta "occ").
# EMPT [C]: murete y reja de no más de cinco pies; macizo de azafranes en flor bajo la ventana; franja angosta de
# césped entre la casa y la calle; parada de coches a cien yardas; el parque enfrente. La caída de libros de la lámina
# PARK es la única animación del juego (GDD§5, HC08): visual, en tiempo real, con pose final determinista.
extends RefCounted

const M = preload("res://world/materials.gd")
const ARCH = preload("res://world/props/architecture.gd")
const STREET = preload("res://world/props/street.gd")
const SMALL = preload("res://world/props/small.gd")

# ======================================================================================
# murete_reja: murete de ladrillo con albardilla y reja encima; el conjunto no pasa de cinco pies (1,52 m).
# A lo largo de X local, centrado. p: len, wall_h, rail_h, gate_x, gate_w (portillo de hierro abierto a medias), piers.
static func build_murete_reja(p: Dictionary) -> Node3D:
	var root := M.root("murete_reja")
	var L := M.pf(p, "len", 7.0)
	var wh := M.pf(p, "wall_h", 0.6)
	var rh := M.pf(p, "rail_h", 0.86)
	var gx := M.pf(p, "gate_x", 1e9); var gw := M.pf(p, "gate_w", 0.0)
	var segs: Array = [[-L / 2, L / 2]]
	if gw > 0.0 and absf(gx) < L / 2:
		segs = [[-L / 2, gx - gw / 2], [gx + gw / 2, L / 2]]
	var occ: Array = []
	for s in segs:
		var a: float = s[0]; var b: float = s[1]
		if b - a < 0.05: continue
		M.box(root, Vector3(b - a, wh, 0.24), Vector3((a + b) / 2, wh / 2, 0), "ladrillo_stock")
		M.box(root, Vector3(b - a + 0.02, 0.06, 0.3), Vector3((a + b) / 2, wh + 0.03, 0), "piedra_portland")
		var rl := ARCH.build_railing({"len": b - a, "h": rh, "plinth": false, "spacing": 0.11})
		rl.position = Vector3((a + b) / 2, wh + 0.06, 0)
		root.add_child(rl)
		occ.append(M.aabb_mm(Vector3(a, 0, -0.12), Vector3(b, wh + 0.06, 0.12)))
		# pilares en los extremos
		for x in [a, b]:
			M.box(root, Vector3(0.34, wh + 0.42, 0.34), Vector3(x, (wh + 0.42) / 2, 0), "ladrillo_stock")
			M.box(root, Vector3(0.4, 0.07, 0.4), Vector3(x, wh + 0.455, 0), "piedra_portland")
			M.sphere(root, 0.1, Vector3(x, wh + 0.56, 0), "piedra_portland")
			occ.append(M.aabb_mm(Vector3(x - 0.17, 0, -0.17), Vector3(x + 0.17, wh + 0.5, 0.17)))
	if gw > 0.0 and absf(gx) < L / 2:
		# portillo entreabierto hacia adentro (−Z)
		var hinge := Node3D.new(); hinge.name = "portillo"; hinge.position = Vector3(gx - gw / 2 + 0.17, 0.05, 0)
		hinge.rotation_degrees = Vector3(0, 35, 0)
		root.add_child(hinge)
		var gl := gw - 0.36
		var g := ARCH.build_railing({"len": gl, "h": wh + rh - 0.1, "plinth": false, "spacing": 0.11})
		g.position = Vector3(gl / 2, 0, 0)
		hinge.add_child(g)
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# lazo_luto: lazo de crespón negro atado al llamador de una puerta (casa de luto). Origen = pie de la puerta en su plano;
# frente +Z. p: y (alto del llamador).
static func build_lazo_luto(p: Dictionary) -> Node3D:
	var root := M.root("lazo_luto")
	var y := M.pf(p, "y", 1.8)
	M.torus(root, 0.045, 0.06, Vector3(0, y, 0.03), "laton", Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		M.sphere(root, 0.08, Vector3(sx * 0.085, y + 0.07, 0.05), "crespon", Vector3(1.1, 0.6, 0.25))
	M.sphere(root, 0.035, Vector3(0, y + 0.07, 0.06), "crespon")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, 0.42, 0.01), Vector3(sx * 0.04, y - 0.14, 0.055), "crespon", Vector3(0, 0, sx * 9))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# macizo_azafranes: macizo de azafranes en plena flor (EMPT: «a bed of crocuses in full bloom»): tierra oscura con bordillo,
# hojas finas y copas grandes y claras (lila, amarillo, blanco) bien tupidas: se leen bajo el grabado. Intacto: nadie pisó.
# Origen = centro, a lo largo de X local. p: w, d, seed, density (flores por m²).
static func build_macizo_azafranes(p: Dictionary) -> Node3D:
	var root := M.root("macizo_azafranes")
	var w := M.pf(p, "w", 2.8); var d := M.pf(p, "d", 1.0)
	var seed := M.seed_of(p, "azafranes")
	M.box(root, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), "tierra")
	for sz: float in [-1.0, 1.0]:
		M.box(root, Vector3(w + 0.08, 0.13, 0.05), Vector3(0, 0.065, sz * (d / 2 + 0.025)), "piedra_portland")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, 0.13, d), Vector3(sx * (w / 2 + 0.025), 0.065, 0), "piedra_portland")
	var n := int(w * d * M.pf(p, "density", 150.0))
	var cups: Array = []; var cc: Array = []; var leaves: Array = []
	var pal := [Color("d8d0e8"), Color("e8d890"), Color("f2ede0"), Color("b8a8d0")]
	for i in n:
		var x := (M.rnd(seed, i, 0) - 0.5) * (w - 0.1)
		var z := (M.rnd(seed, i, 1) - 0.5) * (d - 0.1)
		var sh := M.rr(seed, i, 2, 0.05, 0.09)
		var tilt := Vector3((M.rnd(seed, i, 3) - 0.5) * 16, 0, (M.rnd(seed, i, 4) - 0.5) * 16)
		cups.append(Transform3D(Basis.from_euler(tilt * PI / 180.0), Vector3(x, 0.1 + sh + 0.025, z)))
		cc.append(pal[int(M.rnd(seed, i, 6) * pal.size()) % pal.size()])
		for k in 2:
			var a := M.rr(seed, i, 7 + k, 0, 180)
			leaves.append(Transform3D(Basis.from_euler(Vector3(deg_to_rad(M.rr(seed, i, 9 + k, -12, 12)), deg_to_rad(a), 0)) * Basis.from_scale(Vector3(0.004, sh * 1.1, 0.012)), Vector3(x + 0.01 * (k - 0.5), 0.1 + sh * 0.55, z)))
	M.multi_boxes(root, leaves, [], "cesped")
	M.multi_boxes(root, cups, cc, "lomo", M.cyl_mesh(0.028, 0.009, 0.055, 6))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.13, d / 2))])
	return root

# ======================================================================================
# jardin: suelo del jardín delantero (tierra con bordes de piedra) y sendero de losas hasta la puerta.
# Rectángulo w (X local) × d (Z local), origen en el centro a nivel de vereda. p: path_x, path_w.
static func build_jardin(p: Dictionary) -> Node3D:
	var root := M.root("jardin")
	var w := M.pf(p, "w", 7.0); var d := M.pf(p, "d", 2.8)
	M.box(root, Vector3(w, 0.1, d), Vector3(0, 0.05, 0), "tierra")
	var px := M.pf(p, "path_x", 2.4); var pw := M.pf(p, "path_w", 1.1)
	M.box(root, Vector3(pw, 0.12, d), Vector3(px, 0.06, 0), "piedra_portland")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, 0.14, d), Vector3(px + sx * pw / 2, 0.07, 0), "piedra_portland")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0.1, d / 2))])
	return root

# ======================================================================================
# arbol: plátano de Londres a principios de abril: tronco moteado, ramas desnudas, ramitas y alguna bolita de semillas
# colgando (las del invierno). Ramas en dos MultiMesh (pocas instancias de nodo: el lugar se arma rápido). Determinista.
static func _seg(a: Vector3, b: Vector3, r: float) -> Transform3D:
	var d := b - a
	var l := d.length()
	if l < 0.0001:
		return Transform3D(Basis.from_scale(Vector3(r, 0.001, r)), a)
	var up := d / l
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	return Transform3D(Basis(x * r, up * l, z * r), (a + b) * 0.5)

static func build_arbol(p: Dictionary) -> Node3D:
	var root := M.root("arbol")
	var h := M.pf(p, "h", 11.0)
	var seed := M.seed_of(p, "arbol")
	var trunk_h := h * 0.38
	var r0 := M.pf(p, "r", 0.22)
	M.cyl(root, r0 * 0.8, r0, trunk_h, Vector3(0, trunk_h / 2, 0), "madera_media", Vector3.ZERO, 10)
	# manchas de corteza (plátano)
	var spots: Array = []
	for k in 6:
		var a := M.rr(seed, k, 1, 0, TAU)
		var y := M.rr(seed, k, 2, 0.4, trunk_h - 0.3)
		spots.append(M.xf_box(Vector3(0.16, 0.22, 0.02), Vector3(cos(a) * r0 * 0.92, y, sin(a) * r0 * 0.92), Vector3(0, -rad_to_deg(a) + 90, 0)))
	M.multi_boxes(root, spots, [], "papel_viejo")
	var top := Vector3(0, trunk_h, 0)
	var nb := 4 + int(M.rnd(seed, 0, 3) * 2)
	var big: Array = []
	var thin: Array = []
	var buds: Array = []
	for i in nb:
		var az := TAU * i / nb + M.rr(seed, i, 4, -0.4, 0.4)
		var el := M.rr(seed, i, 5, 0.75, 1.15)
		var ln := h * M.rr(seed, i, 6, 0.32, 0.42)
		var dir := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el))
		var b1 := top + dir * ln
		big.append(_seg(top, b1, r0 * 0.42))
		for j in 3:
			var az2 := az + M.rr(seed, i * 7 + j, 7, -0.9, 0.9)
			var el2 := el + M.rr(seed, i * 7 + j, 8, -0.2, 0.35)
			var ln2 := ln * M.rr(seed, i * 7 + j, 9, 0.45, 0.7)
			var d2 := Vector3(cos(az2) * cos(el2), sin(el2), sin(az2) * cos(el2))
			var b2 := b1 + d2 * ln2
			big.append(_seg(b1, b2, r0 * 0.16))
			for k in 4:
				var q := i * 31 + j * 5 + k
				var tip := b2 + Vector3(M.rr(seed, q, 10, -0.7, 0.7), M.rr(seed, q, 11, -0.1, 0.8), M.rr(seed, q, 12, -0.7, 0.7))
				thin.append(_seg(b2, tip, 0.022))
				var tw := tip + Vector3(M.rr(seed, q, 14, -0.35, 0.35), M.rr(seed, q, 15, 0.0, 0.4), M.rr(seed, q, 16, -0.35, 0.35))
				thin.append(_seg(tip, tw, 0.01))
				if M.rnd(seed, q, 13) < 0.5:
					buds.append(M.xf_box(Vector3.ONE * M.rr(seed, q, 17, 0.1, 0.16), tw + Vector3(0, -0.12, 0)))
	M.multi_boxes(root, big, [], "madera_media", M.cyl_mesh(0.8, 1.0, 1.0, 8))
	M.multi_boxes(root, thin, [], "madera_oscura", M.cyl_mesh(0.7, 1.0, 1.0, 5))
	if not buds.is_empty():
		M.multi_boxes(root, buds, [], "cesped", M.sphere_mesh(0.5, false, 8))
	root.set_meta("occ", [M.aabb_mm(Vector3(-r0, 0, -r0), Vector3(r0, trunk_h, r0))])
	return root

# ======================================================================================
# borde_parque: vereda del parque con verja alta de hierro, césped y una fila de plátanos detrás. A lo largo de X local;
# la verja en z=0, el parque hacia −Z. p: len, trees (n), depth (fondo del césped), seed, gap (claro sin árboles en x).
static func build_borde_parque(p: Dictionary) -> Node3D:
	var root := M.root("borde_parque")
	var L := M.pf(p, "len", 60.0)
	var depth := M.pf(p, "depth", 26.0)
	var seed := M.pi_(p, "seed", 5)
	var occ: Array = []
	var rl := ARCH.build_railing({"len": L, "h": 1.35, "plinth": true, "spacing": 0.14})
	root.add_child(rl)
	for b in rl.get_meta("occ", []): occ.append(b)
	M.box(root, Vector3(L, 0.08, depth), Vector3(0, 0.04, -depth / 2 - 0.15), "cesped")
	var n := maxi(M.pi_(p, "trees", 8), 0)
	var gap = p.get("gap", null)
	for i in n:
		var x := -L / 2 + L * (i + 0.5) / n + M.rr(seed, i, 1, -1.2, 1.2)
		if gap is Array and gap.size() >= 2 and x > float(gap[0]) and x < float(gap[1]):
			continue
		var t := build_arbol({"h": M.rr(seed, i, 2, 9.5, 13.0), "r": M.rr(seed, i, 3, 0.2, 0.28), "seed": seed * 17 + i})
		t.position = Vector3(x, 0.05, -M.rr(seed, i, 4, 2.2, 3.4))
		t.rotation_degrees = Vector3(0, M.rr(seed, i, 5, 0, 360), 0)
		root.add_child(t)
		for b in t.get_meta("occ", []): occ.append(t.transform * b)
	# segunda fila, más lejos (masa del parque)
	for i in n:
		var x2 := -L / 2 + L * (i + 0.25) / n + M.rr(seed, i, 6, -2.0, 2.0)
		var t2 := build_arbol({"h": M.rr(seed, i, 7, 10.0, 14.0), "r": 0.24, "seed": seed * 29 + i})
		t2.position = Vector3(x2, 0.05, -M.rr(seed, i, 8, 9.0, 16.0))
		t2.rotation_degrees = Vector3(0, M.rr(seed, i, 9, 0, 360), 0)
		root.add_child(t2)
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# parada: parada de coches de alquiler con refugio de cocheros (casilla verde de techo a dos aguas) y coches en fila.
# A lo largo de X local (la fila mira a +X). p: n_cabs, seed.
static func build_parada(p: Dictionary) -> Node3D:
	var root := M.root("parada")
	var occ: Array = []
	# refugio de cocheros
	var hut := Node3D.new(); hut.name = "refugio"; hut.position = Vector3(-6.0, 0, -0.4); root.add_child(hut)
	M.box(hut, Vector3(4.2, 2.3, 2.0), Vector3(0, 1.15, 0), "pintura_verde")
	M.prism(hut, Vector3(4.5, 0.9, 2.3), Vector3(0, 2.75, 0), "pizarra", Vector3(0, 90, 0))
	for k in 3:
		M.box(hut, Vector3(0.6, 0.5, 0.02), Vector3(-1.3 + k * 1.3, 1.6, 1.01), "interior_oscuro")
	M.box(hut, Vector3(0.12, 0.6, 0.12), Vector3(1.4, 3.3, 0), "hierro")
	occ.append(M.aabb_mm(hut.position + Vector3(-2.1, 0, -1.0), hut.position + Vector3(2.1, 3.2, 1.0)))
	var n := M.pi_(p, "n_cabs", 3)
	var seed := M.pi_(p, "seed", 3)
	for i in n:
		var cab := STREET.build_cab({"kind": "growler" if i % 2 == 0 else "hansom"})
		cab.position = Vector3(-1.0 + i * 4.6, 0, 0.8)
		cab.rotation_degrees = Vector3(0, 90, 0)
		root.add_child(cab)
		for b in cab.get_meta("occ", []): occ.append(cab.transform * b)
		# cochero en el pescante o junto al caballo
		var MQ = load("res://world/characters/mannequin.gd")
		var fig: Node3D = MQ.make("cochero_%d" % i, "", "de_pie" if i % 2 == 0 else "apoyado")
		fig.position = cab.position + Vector3(0.6 + M.rr(seed, i, 1, 0, 0.5), 0, -1.1)
		fig.rotation_degrees = Vector3(0, M.rr(seed, i, 2, 120, 240), 0)
		root.add_child(fig)
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# libros_caidos: libros desparramados en la vereda (lámina PARK). Uno muestra el título «The Origin of Tree Worship».
# Con p.anim (def true) caen desde los brazos del librero (p.from: [x,y,z] local) al entrar al árbol: la única animación
# del juego. Pose final determinista; la animación es sólo visual (tiempo real). p: seed, title, delay, dur.
class Caida extends Node3D:
	var finals: Array = []      # Transform3D finales por libro
	var starts: Array = []
	var spins: Array = []
	var delay := 0.6
	var dur := 0.9
	var t := 0.0
	var playing := false

	func _ready() -> void:
		play()

	func play() -> void:
		t = -delay
		playing = true
		_pose(0.0)
		set_process(true)

	func finish() -> void:
		playing = false
		_pose(1.0)
		set_process(false)

	func _process(dt: float) -> void:
		if not playing:
			set_process(false)
			return
		t += dt
		if t >= dur:
			finish()
			return
		_pose(clampf(t / dur, 0.0, 1.0))

	func _pose(u: float) -> void:
		var kids := get_children()
		for i in mini(kids.size(), finals.size()):
			var b: Node3D = kids[i]
			var f: Transform3D = finals[i]
			var s: Transform3D = starts[i]
			var k := clampf(u * (1.0 + 0.15 * i) - 0.15 * i, 0.0, 1.0)   # caen escalonados
			var fall := k * k                                             # gravedad
			var pos := s.origin.lerp(f.origin, k)
			pos.y = lerpf(s.origin.y, f.origin.y, fall)
			if k >= 1.0:
				b.transform = f
				continue
			var q := s.basis.get_rotation_quaternion().slerp(f.basis.get_rotation_quaternion(), k)
			var spin: Vector3 = spins[i]
			b.transform = Transform3D(Basis(q) * Basis.from_euler(spin * sin(k * PI)), pos)

static var _tapa: Material = null
static func _mat_tapa() -> Material:
	if _tapa == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("ece2c8")
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tapa = m
	return _tapa

static func build_libros_caidos(p: Dictionary) -> Node3D:
	var root := M.root("libros_caidos")
	var seed := M.seed_of(p, "libros")
	var anim := M.pb(p, "anim", true)
	var cai := Caida.new()
	cai.name = "caida"
	cai.delay = M.pf(p, "delay", 0.6)
	cai.dur = M.pf(p, "dur", 0.9)
	root.add_child(cai)
	var from := M.v3(p.get("from", null), Vector3(-0.3, 1.15, -0.4))
	var title := M.ps(p, "title", "The Origin of\nTree Worship")
	var specs := [[0.17, 0.24, 0.045, "cuero"], [0.2, 0.28, 0.03, "papel"], [0.19, 0.27, 0.05, "tela_oscura"], [0.13, 0.2, 0.025, "caoba"], [0.16, 0.23, 0.035, "tela_media"]]
	# pose final en abanico, sin encimarse: el del título queda arriba y a la vista
	var spots := [Vector2(-0.36, -0.08), Vector2(0.04, 0.06), Vector2(0.42, 0.14), Vector2(-0.14, 0.38), Vector2(0.24, -0.3)]
	for i in specs.size():
		var sp: Array = specs[i]
		var bw: float = sp[0]; var bh: float = sp[1]; var bt: float = sp[2]
		var bk := Node3D.new(); bk.name = "libro_%d" % i
		var body := M.box(bk, Vector3(bw, bt, bh), Vector3(0, bt / 2, 0), str(sp[3]))
		M.box(bk, Vector3(bw - 0.012, bt - 0.01, bh - 0.006), Vector3(0.006, bt / 2, 0), "papel_viejo")
		body.position = Vector3(0, bt / 2, 0)
		if i == 1:
			# tapa clara con el título en tinta oscura; la tapa no se sombrea (como papel al sol): se lee con cualquier luz
			var cover := M.box(bk, Vector3(bw - 0.01, 0.002, bh - 0.01), Vector3(0, bt + 0.001, 0), "papel")
			cover.material_override = _mat_tapa()
			var lb := M.label3d(bk, title, Vector3(0, bt + 0.003, 0), 0.00058, 48, Color("1b1712"))
			lb.rotation_degrees = Vector3(-90, 0, 0)
			lb.shaded = false
			lb.name = "titulo"
		# pose final: tirados en la vereda, abiertos en abanico (uno abierto boca abajo)
		var sp2: Vector2 = spots[i]
		var fx := sp2.x + M.rr(seed, i, 1, -0.04, 0.04)
		var fz := sp2.y + M.rr(seed, i, 2, -0.04, 0.04)
		var ry := M.rr(seed, i, 3, -70, 70)
		if i == 1:
			ry = 18.0
		var fb := Basis.from_euler(Vector3(0, deg_to_rad(ry), 0))
		if i == 3: fb = fb * Basis.from_euler(Vector3(0, 0, deg_to_rad(8)))
		var final := Transform3D(fb, Vector3(fx, 0.0, fz))
		var start := Transform3D(Basis.from_euler(Vector3(deg_to_rad(80), deg_to_rad(ry * 0.3), 0)), from + Vector3(0.02 * i, 0.05 * i, 0.03 * i))
		cai.finals.append(final)
		cai.starts.append(start)
		cai.spins.append(Vector3(M.rr(seed, i, 4, -2.5, 2.5), M.rr(seed, i, 5, -1.5, 1.5), M.rr(seed, i, 6, -2.5, 2.5)))
		bk.transform = final
		cai.add_child(bk)
	if not anim:
		cai.delay = 0.0
		cai.dur = 0.0001
	root.set_meta("occ", [])
	return root
