# world/props/l5.gd — W2-PLACES-C. Props propios de L5, el club Diógenes (portería y Sala de Forasteros; GDD§5, GREE):
# «Through the glass paneling I caught a glimpse of a large and luxurious room, in which a considerable number of men were
# sitting about and reading papers, each in his own little nook» · «a small chamber which looked out into Pall Mall» ·
# «the bow-window of the club». Convención §7.2: origen = centro del piso de la huella, frente +Z, meta "occ".
extends RefCounted

const M = preload("res://world/materials.gd")
const MQ = preload("res://world/characters/mannequin.gd")
const FU = preload("res://world/props/furniture.gd")

# glass_screen(w,h): mampara de caoba: zócalo de tableros hasta 0,9 m y vidrio arriba con travesaños; puerta doble al
# centro. Llena un vano; origen = centro del umbral, frente +Z. Sólo el zócalo y los montantes tapan.
static func build_glass_screen(p: Dictionary) -> Node3D:
	var root := M.root("glass_screen")
	var w := M.pf(p, "w", 2.6); var h := M.pf(p, "h", 2.9)
	var mat := "caoba"
	var t := 0.06
	var dado := 0.9
	var dw := M.pf(p, "door_w", 1.0)
	var occ: Array = []
	# zócalo a los lados de la puerta
	for sx: float in [-1.0, 1.0]:
		var x0 := sx * dw / 2.0
		var x1 := sx * w / 2.0
		var cx := (x0 + x1) / 2.0
		var pw := absf(x1 - x0)
		M.box(root, Vector3(pw, dado, t), Vector3(cx, dado / 2, 0), mat)
		M.box(root, Vector3(pw - 0.12, dado - 0.2, 0.012), Vector3(cx, dado / 2, t / 2 + 0.006), "madera_oscura")
		occ.append(M.aabb_mm(Vector3(minf(x0, x1), 0, -t / 2), Vector3(maxf(x0, x1), dado, t / 2)))
		# montantes y travesaños del vidrio
		for k in 3:
			var mx := lerpf(x0, x1, k / 2.0)
			M.box(root, Vector3(0.05, h - dado, t), Vector3(mx, dado + (h - dado) / 2, 0), mat)
		for r in 3:
			M.box(root, Vector3(pw, 0.04, t * 0.8), Vector3(cx, dado + (h - dado) * (0.33 * (r + 1)), 0), mat)
		M.box(root, Vector3(pw, h - dado, 0.004), Vector3(cx, dado + (h - dado) / 2, 0), "vidrio")
	# puerta doble vidriada (cerrada)
	for sx: float in [-1.0, 1.0]:
		var cx := sx * dw / 4.0
		M.box(root, Vector3(dw / 2 - 0.01, 0.95, t * 0.7), Vector3(cx, 0.475, 0), mat)
		M.box(root, Vector3(0.05, h - 0.35 - 0.95, t * 0.7), Vector3(cx - sx * (dw / 4 - 0.025), 0.95 + (h - 1.3) / 2, 0), mat)
		M.box(root, Vector3(0.05, h - 0.35 - 0.95, t * 0.7), Vector3(cx + sx * (dw / 4 - 0.025), 0.95 + (h - 1.3) / 2, 0), mat)
		M.box(root, Vector3(dw / 2 - 0.1, h - 1.3, 0.004), Vector3(cx, 0.95 + (h - 1.3) / 2, 0), "vidrio")
		M.sphere(root, 0.018, Vector3(sx * 0.06, 1.05, t / 2 + 0.02), "laton")
		occ.append(M.aabb_mm(Vector3(minf(0.0, sx * dw / 2), 0, -t / 2), Vector3(maxf(0.0, sx * dw / 2), 0.95, t / 2)))
	M.box(root, Vector3(w, 0.35, t), Vector3(0, h - 0.175, 0), mat)                 # dintel con montante ciego
	M.box(root, Vector3(w + 0.1, 0.06, t + 0.04), Vector3(0, h + 0.03, 0), mat)
	occ.append(M.aabb_mm(Vector3(-w / 2, h - 0.35, -t / 2), Vector3(w / 2, h + 0.06, t / 2)))
	root.set_meta("occ", occ)
	return root

# pigeonholes(w,h,cols,rows): casillero de pared para la correspondencia de los socios; origen = centro inferior contra
# la pared, frente +Z. Algunas casillas con cartas.
static func build_pigeonholes(p: Dictionary) -> Node3D:
	var root := M.root("pigeonholes")
	var w := M.pf(p, "w", 1.6); var h := M.pf(p, "h", 1.1); var d := 0.28
	var cols := M.pi_(p, "cols", 8); var rows := M.pi_(p, "rows", 5)
	var seed := M.seed_of(p, "casillero")
	M.box(root, Vector3(w, h, 0.02), Vector3(0, h / 2, 0.01), "madera_negra")
	for c in cols + 1:
		M.box(root, Vector3(0.018, h, d), Vector3(-w / 2 + w * c / cols, h / 2, d / 2), "caoba")
	for r in rows + 1:
		M.box(root, Vector3(w, 0.018, d), Vector3(0, h * r / rows, d / 2), "caoba")
	for c in cols:
		for r in rows:
			if M.rnd(seed, c, r) < 0.45:
				var cx := -w / 2 + w * (c + 0.5) / cols
				var cy := h * r / rows + 0.02
				M.box(root, Vector3(w / cols * 0.7, h / rows * 0.55, 0.02), Vector3(cx, cy + h / rows * 0.28, d * 0.6), "papel" if M.rnd(seed, c, r + 9) < 0.6 else "papel_viejo", Vector3(-8, 0, 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, 0, 0), Vector3(w / 2, h, 0.03))])
	return root

# card_tray: bandeja de plata con tarjetas de visita.
static func build_card_tray(p: Dictionary) -> Node3D:
	var root := M.root("card_tray")
	var seed := M.seed_of(p, "tarjetas")
	M.cyl(root, 0.12, 0.11, 0.012, Vector3(0, 0.006, 0), "vela", Vector3.ZERO, 24)
	M.torus(root, 0.11, 0.125, Vector3(0, 0.012, 0), "ceniza")
	for k in 4:
		M.box(root, Vector3(0.085, 0.002, 0.05), Vector3(M.rr(seed, k, 1, -0.03, 0.03), 0.014 + k * 0.002, M.rr(seed, k, 2, -0.02, 0.02)), "papel", Vector3(0, M.rr(seed, k, 3, -30.0, 30.0), 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.125, 0, -0.125), Vector3(0.125, 0.025, 0.125))])
	return root

# stationery: atril de papel del club: pliegos crema con el membrete (franja oscura arriba) y sobres.
static func build_stationery(_p: Dictionary) -> Node3D:
	var root := M.root("stationery")
	M.box(root, Vector3(0.3, 0.02, 0.22), Vector3(0, 0.01, 0), "caoba")
	M.box(root, Vector3(0.3, 0.24, 0.02), Vector3(0, 0.12, -0.1), "caoba")
	for k in 3:
		var z := -0.07 + k * 0.05
		var hh := 0.2 - k * 0.04
		M.box(root, Vector3(0.21, hh, 0.006), Vector3(0, 0.02 + hh / 2, z), "vela", Vector3(-8, 0, 0))
		M.box(root, Vector3(0.12, 0.012, 0.002), Vector3(0, 0.02 + hh - 0.025, z + 0.004), "tinta", Vector3(-8, 0, 0))
		M.box(root, Vector3(0.012, 0.012, 0.002), Vector3(0, 0.02 + hh - 0.045, z + 0.004), "tinta", Vector3(-8, 0, 0))
		M.box(root, Vector3(0.025, hh, 0.02), Vector3(-0.13, 0.02 + hh / 2, z), "caoba")
		M.box(root, Vector3(0.025, hh, 0.02), Vector3(0.13, 0.02 + hh / 2, z), "caoba")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.15, 0, -0.11), Vector3(0.15, 0.25, 0.11))])
	return root

# long_case_clock: reloj de pie de caoba (esfera, péndulo tras el vidrio). Mira a +Z.
static func build_long_case_clock(p: Dictionary) -> Node3D:
	var root := M.root("long_case_clock")
	var h := M.pf(p, "h", 2.2)
	var mat := "caoba"
	M.box(root, Vector3(0.5, 0.35, 0.32), Vector3(0, 0.175, 0), mat)
	M.box(root, Vector3(0.36, h - 0.85, 0.24), Vector3(0, 0.35 + (h - 0.85) / 2, 0), mat)
	M.box(root, Vector3(0.24, h - 1.15, 0.01), Vector3(0, 0.5 + (h - 1.15) / 2, 0.125), "madera_oscura")
	M.cyl(root, 0.05, 0.05, 0.01, Vector3(0, 0.75, 0.13), "laton", Vector3(90, 0, 0), 16)
	M.box(root, Vector3(0.48, 0.5, 0.3), Vector3(0, h - 0.25, 0), mat)
	M.cyl(root, 0.17, 0.17, 0.012, Vector3(0, h - 0.25, 0.152), "vela", Vector3(90, 0, 0), 24)
	var c := Vector3(0, h - 0.25, 0.16)
	M.beam_ab(root, c, c + Vector3(0.0, 0.1, 0), 0.01, 0.003, "tinta")
	M.beam_ab(root, c, c + Vector3(0.12, 0.03, 0), 0.007, 0.003, "tinta")
	for k in 12:
		var a := TAU * k / 12.0
		M.box(root, Vector3(0.006, 0.02, 0.002), c + Vector3(sin(a) * 0.14, cos(a) * 0.14, -0.002), "tinta", Vector3(0, 0, -rad_to_deg(a)))
	M.prism(root, Vector3(0.5, 0.18, 0.3), Vector3(0, h + 0.09, 0), mat)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.25, 0, -0.16), Vector3(0.25, h + 0.18, 0.17))])
	return root

# notice(w,h,text,text2): cartel enmarcado de pared con texto (Label3D, imprenta). Origen = centro, contra la pared; +Z.
static func build_notice(p: Dictionary) -> Node3D:
	var root := M.root("notice")
	var w := M.pf(p, "w", 0.6); var h := M.pf(p, "h", 0.42)
	M.box(root, Vector3(w, h, 0.025), Vector3(0, 0, 0.0125), "madera_negra")
	M.box(root, Vector3(w - 0.06, h - 0.06, 0.006), Vector3(0, 0, 0.027), "papel")
	var t1 := M.text_of(p, "text_key")
	if t1 == "": t1 = M.ps(p, "text", "")
	if t1 != "":
		var l1 := M.label3d(root, t1, Vector3(0, h * 0.14, 0.032), minf(0.0026, (w - 0.1) / (48.0 * 0.7 * maxf(t1.length(), 1))), 48, Color("1b1712"))
		l1.name = "text"
	var t2 := M.ps(p, "text2", "")
	if t2 != "":
		var l2 := M.label3d(root, t2, Vector3(0, -h * 0.18, 0.032), 0.0012, 48, Color("1b1712"))
		l2.width = (w - 0.1) / 0.0012
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD
		l2.name = "text2"
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, -h / 2, 0), Vector3(w / 2, h / 2, 0.03))])
	return root

# bow_window(w,depth,h,sill): mirador de tres hojas que sale de un vano hacia −Z (afuera). Origen = centro del pie del vano
# sobre la cara exterior del muro; el piso del mirador sigue al del cuarto. Los marcos tapan; el vidrio no.
static func build_bow_window(p: Dictionary) -> Node3D:
	var root := M.root("bow_window")
	var w := M.pf(p, "w", 2.4); var dp := M.pf(p, "depth", 0.85); var h := M.pf(p, "h", 2.7); var sill := M.pf(p, "sill", 0.45)
	var A = load("res://world/props/architecture.gd")
	var occ: Array = []
	var fw := w - 2.0 * dp           # hoja del frente
	M.box(root, Vector3(w, 0.06, dp), Vector3(0, -0.03, -dp / 2), "suelo_tablas")
	# frente
	var front := Node3D.new(); front.position = Vector3(0, 0, -dp); root.add_child(front)
	M.box(front, Vector3(fw, sill, 0.18), Vector3(0, sill / 2, 0), "estuco")
	var sw = A.build_sash_window({"w": fw, "h": h - sill, "panes": 4, "paint": "vela", "depth": 0.1})
	sw.position = Vector3(0, sill, 0); front.add_child(sw)
	occ.append(M.aabb_mm(Vector3(-fw / 2, 0, -dp - 0.09), Vector3(fw / 2, sill, -dp + 0.09)))
	# lados a 45°
	for sx: float in [-1.0, 1.0]:
		var side := Node3D.new(); root.add_child(side)
		var sl := dp * sqrt(2.0)
		side.position = Vector3(sx * (fw / 2 + dp / 2), 0, -dp / 2)
		side.rotation_degrees = Vector3(0, -sx * 45.0, 0)
		M.box(side, Vector3(sl, sill, 0.18), Vector3(0, sill / 2, 0), "estuco")
		var s2 = A.build_sash_window({"w": sl, "h": h - sill, "panes": 2, "paint": "vela", "depth": 0.1})
		s2.position = Vector3(0, sill, 0); side.add_child(s2)
		occ.append(M.aabb_mm(Vector3(minf(sx * fw / 2, sx * w / 2), 0, -dp), Vector3(maxf(sx * fw / 2, sx * w / 2), sill, 0)))
	# techo de plomo y cornisa
	M.box(root, Vector3(w + 0.2, 0.18, dp + 0.15), Vector3(0, h + 0.09, -dp / 2 - 0.05), "estuco")
	M.box(root, Vector3(w + 0.3, 0.06, dp + 0.25), Vector3(0, h + 0.21, -dp / 2 - 0.08), "hierro")
	occ.append(M.aabb_mm(Vector3(-w / 2 - 0.1, h, -dp - 0.2), Vector3(w / 2 + 0.1, h + 0.25, 0)))
	# asiento de ventana con almohadón
	M.box(root, Vector3(fw, 0.08, 0.36), Vector3(0, sill - 0.04, -dp + 0.26), "terciopelo")
	root.set_meta("occ", occ)
	return root

# reading_nook(seed): rincón de un socio: butaca de orejas, mesita con lámpara y un caballero sentado con el diario
# abierto delante de la cara (figura genérica; no es personaje). Mira a +Z.
static func build_reading_nook(p: Dictionary) -> Node3D:
	var root := M.root("reading_nook")
	var seed := M.seed_of(p, "socio")
	var ch := FU.build_armchair({"wing": true, "mat": "cuero" if M.rnd(seed, 1, 1) < 0.6 else "terciopelo"})
	root.add_child(ch)
	var fig := MQ.make("socio_%d" % (seed % 97), "", "sentado")
	fig.position = Vector3(0, 0.0, 0.02)
	root.add_child(fig)
	var paper := Node3D.new(); paper.position = Vector3(0, 1.0, 0.42); paper.rotation_degrees = Vector3(-14, M.rr(seed, 2, 2, -10.0, 10.0), 0); root.add_child(paper)
	M.box(paper, Vector3(0.62, 0.44, 0.008), Vector3.ZERO, "papel")
	for r in 6:
		M.box(paper, Vector3(0.26, 0.006, 0.002), Vector3(-0.15 if r % 2 == 0 else 0.15, 0.15 - r * 0.05, 0.006), "tinta")
	M.box(paper, Vector3(0.008, 0.44, 0.012), Vector3(0, 0, 0.002), "papel_viejo")
	var tx := 0.62 if M.rnd(seed, 3, 3) < 0.5 else -0.62
	var tb = FU.build_table({"w": 0.42, "d": 0.42, "h": 0.6, "round": true})
	tb.position = Vector3(tx, 0, 0.1); root.add_child(tb)
	var lamp = load("res://world/props/small.gd").build_desk_lamp({})
	lamp.position = Vector3(tx, 0.6, 0.05); root.add_child(lamp)
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.45, 0, -0.45), Vector3(0.45, 1.25, 0.6))])
	return root

# snuff_box: tabaquera de carey abierta, con unos granos de rapé derramados.
static func build_snuff_box(_p: Dictionary) -> Node3D:
	var root := M.root("snuff_box")
	M.box(root, Vector3(0.08, 0.018, 0.055), Vector3(0, 0.009, 0), "caoba")
	var lid := Node3D.new(); lid.position = Vector3(0, 0.018, -0.0275); lid.rotation_degrees = Vector3(-70, 0, 0); root.add_child(lid)
	M.box(lid, Vector3(0.08, 0.006, 0.055), Vector3(0, 0.0, 0.0275), "caoba")
	M.box(root, Vector3(0.07, 0.003, 0.045), Vector3(0, 0.017, 0), "tierra")
	for k in 5:
		M.sphere(root, 0.004, Vector3(0.05 + k * 0.01, 0.002, 0.02 - k * 0.006), "tierra")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.04, 0, -0.04), Vector3(0.1, 0.07, 0.03))])
	return root

# register_book(w,h): libro de registro abierto (envuelve small.open_ledger_book con su oclusor real: la AABB que arma la
# base para geometría sólo-MultiMesh sale 1×1×1 con el renderer headless).
static func build_register_book(p: Dictionary) -> Node3D:
	var root = load("res://world/props/small.gd").build_open_ledger_book(p)
	var w := M.pf(p, "w", 0.48); var h := M.pf(p, "h", 0.34)
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2 - 0.01, 0, -h / 2 - 0.01), Vector3(w / 2 + 0.01, 0.03, h / 2 + 0.01))])
	return root

# club_paper(n): pliegos de papel crema del club, apenas corridos, con la franja del membrete grabado.
static func build_club_paper(p: Dictionary) -> Node3D:
	var root := M.root("club_paper")
	var n := clampi(M.pi_(p, "n", 5), 1, 20)
	var seed := M.seed_of(p, "papel_club")
	for k in n:
		var r := M.rr(seed, k, 1, -6.0, 6.0)
		M.box(root, Vector3(0.2, 0.002, 0.26), Vector3(M.rr(seed, k, 2, -0.01, 0.01), 0.001 + k * 0.0022, M.rr(seed, k, 3, -0.01, 0.01)), "vela", Vector3(0, r, 0))
	var top := 0.001 + (n - 1) * 0.0022 + 0.0012
	M.box(root, Vector3(0.11, 0.001, 0.012), Vector3(0, top, -0.1), "tinta")
	M.box(root, Vector3(0.012, 0.001, 0.012), Vector3(0, top, -0.08), "tinta")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.11, 0, -0.14), Vector3(0.11, top + 0.002, 0.14))])
	return root
