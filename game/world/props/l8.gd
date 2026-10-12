# world/props/l8.gd — W2-PLACES-B. Lugar L8 (Camden House, interior): el cuarto delantero vacío de la planta baja.
# Contrato: docs/ARCHITECTURE.md §7.2 (`"l8.<función>"` → build_<función>(p) -> Node3D con meta "occ").
# EMPT [C]: «bare planking», «a wall from which the paper was hanging in ribbons», «the window was thick with dust»,
# la hoja de abajo «raised it for half a foot» sin ruido. GDD§5: polvo removido en el alféizar, ceniza de cheroot,
# guillotina engrasada, vista que domina la ventana del 221B.
extends RefCounted

const M = preload("res://world/materials.gd")
const ARCH = preload("res://world/props/architecture.gd")
const L3 = preload("res://world/props/l3.gd")

# ======================================================================================
# ventana: guillotina de seis paños por hoja con el vidrio sucio, postigos interiores, tablero del alféizar con polvo y,
# opcionalmente, aceite fresco en las poleas. Origen = centro inferior del vano en el plano medio del muro; +Z = interior.
# p: w, h, depth (grosor del muro), shutters ("open" | "closed"), dust_sill ("intact" | "removed"), oil (bool),
#    open_frac (hoja de abajo), dust (densidad del vidrio, def 0.62).
static func build_ventana(p: Dictionary) -> Node3D:
	var root := M.root("ventana")
	var w := M.pf(p, "w", 1.1); var h := M.pf(p, "h", 2.3)
	var dep := M.pf(p, "depth", 0.3)
	var open := M.pf(p, "open_frac", 0.0)
	var sw := ARCH.build_sash_window({"w": w, "h": h, "panes": 6, "paint": "madera_media", "depth": 0.1, "open_frac": open})
	root.add_child(sw)
	# vidrio sucio sobre las dos hojas
	var fr := 0.06
	var iw := w - 2 * fr
	var ih := h - fr - fr * 0.8
	var sh := ih / 2.0
	var y_low := fr * 0.8 + open * (ih / 2.0 - 0.04)
	var dd := M.pf(p, "dust", 0.62)
	var dl := M.pf(p, "dust_low", dd)
	var dsc := M.pf(p, "dust_scale", 6.0)
	L3._set_mat(M.box(root, Vector3(iw - 0.07, sh - 0.07, 0.003), Vector3(0, fr * 0.8 + ih - sh / 2.0 + 0.01, -0.02), "vela"), L3.mat_polvo(dd, dsc))
	if dl > 0.0:
		L3._set_mat(M.box(root, Vector3(iw - 0.07, sh - 0.07, 0.003), Vector3(0, y_low + sh / 2.0 + 0.01, 0.031), "vela"), L3.mat_polvo(dl, dsc))
	# derrame interior (jambas y dintel) hasta la cara del cuarto
	var rev := dep / 2.0
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.04, h, rev), Vector3(sx * (w / 2 + 0.02), h / 2, rev / 2 + 0.05), "yeso_sucio")
	M.box(root, Vector3(w + 0.08, 0.04, rev), Vector3(0, h + 0.02, rev / 2 + 0.05), "yeso_sucio")
	# tablero del alféizar (madera) con su polvo
	var bd := rev + 0.08
	M.box(root, Vector3(w + 0.2, 0.035, bd), Vector3(0, -0.0175, bd / 2), "madera_negra")
	var dust_mode := M.ps(p, "dust_sill", "intact")
	var dm := L3.mat_polvo(0.86, 9.0)
	if dust_mode == "removed":
		# polvo de meses a los lados; en el medio, barrido en un tramo del ancho de dos antebrazos (madera limpia)
		var clear := minf(w * 0.55, 0.62)
		var side := (w + 0.16 - clear) / 2.0
		for sx: float in [-1.0, 1.0]:
			L3._set_mat(M.box(root, Vector3(side, 0.004, bd - 0.03), Vector3(sx * (clear / 2 + side / 2), 0.002, bd / 2), "vela"), dm)
		# borde del polvo empujado (rebaba más densa) y marcas de dedos
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.03, 0.006, bd - 0.05), Vector3(sx * clear / 2, 0.003, bd / 2), "yeso_sucio")
		for k in 3:
			M.box(root, Vector3(0.012, 0.0035, 0.07), Vector3(-0.12 + k * 0.05, 0.0018, bd * 0.7), "yeso_sucio", Vector3(0, -10 + k * 8, 0))
	else:
		L3._set_mat(M.box(root, Vector3(w + 0.16, 0.004, bd - 0.03), Vector3(0, 0.002, bd / 2), "vela"), dm)
	if M.pb(p, "oil", false):
		# aceite fresco: chorreaduras oscuras en las jambas (poleas) y una gota en el alféizar
		for sx: float in [-1.0, 1.0]:
			var x := sx * (w / 2 - 0.035)
			M.box(root, Vector3(0.012, 0.16, 0.006), Vector3(x, h - 0.2, 0.052), "carbon")
			M.box(root, Vector3(0.008, 0.32, 0.006), Vector3(x, h * 0.55, 0.052), "carbon")
			M.sphere(root, 0.018, Vector3(x, h - 0.1, 0.052), "carbon", Vector3(1, 1, 0.4))
		M.sphere(root, 0.02, Vector3(w / 2 - 0.08, 0.004, bd * 0.4), "carbon", Vector3(1.4, 0.15, 1.0))
	# postigos interiores (de caja): abiertos plegados en el derrame o cerrados sobre el vidrio
	var shut := M.ps(p, "shutters", "open")
	var lw := w / 2.0
	if shut == "closed":
		for sx: float in [-1.0, 1.0]:
			var leaf := Node3D.new(); leaf.position = Vector3(sx * lw / 2, 0, rev - 0.02); root.add_child(leaf)
			M.box(leaf, Vector3(lw - 0.01, h - 0.04, 0.035), Vector3(0, h / 2, 0), "madera_media")
			for r in 3:
				M.box(leaf, Vector3(lw - 0.12, h / 3 - 0.14, 0.012), Vector3(0, h * (r + 0.5) / 3, 0.022), "madera_oscura")
			M.box(leaf, Vector3(0.02, 0.12, 0.02), Vector3(-sx * (lw / 2 - 0.05), h * 0.5, 0.03), "hierro")
		M.box(root, Vector3(w, 0.03, 0.05), Vector3(0, h * 0.5, rev + 0.02), "hierro")
	else:
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.035, h - 0.04, rev * 0.9), Vector3(sx * (w / 2 + 0.06), h / 2, rev / 2 + 0.06), "madera_media")
	var occ := [M.aabb_mm(Vector3(-w / 2 - 0.08, -0.04, 0.0), Vector3(w / 2 + 0.08, 0.0, bd))]
	if shut == "closed":
		occ.append(M.aabb_mm(Vector3(-w / 2, 0, rev - 0.04), Vector3(w / 2, h, rev)))
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# papel_tiras: papel pintado que cuelga en tiras de un muro, con yeso a la vista donde se cayó. Origen = pie del muro en
# su cara interior; las tiras se despegan hacia +Z. p: len (a lo largo de X), h (alto del muro), n, seed.
static func build_papel_tiras(p: Dictionary) -> Node3D:
	var root := M.root("papel_tiras")
	var L := M.pf(p, "len", 4.0); var h := M.pf(p, "h", 3.4)
	var n := M.pi_(p, "n", 6)
	var seed := M.seed_of(p, "papel")
	for i in n:
		var x := -L / 2 + L * (i + 0.5) / n + M.rr(seed, i, 1, -0.25, 0.25)
		var top := h * M.rr(seed, i, 2, 0.55, 0.92)
		var ln := M.rr(seed, i, 3, 0.45, 1.3)
		var sw := M.rr(seed, i, 4, 0.22, 0.48)
		# yeso descubierto detrás
		M.box(root, Vector3(sw + 0.04, ln + 0.1, 0.004), Vector3(x, top - ln / 2, 0.003), "yeso_sucio")
		# la tira, despegada y combada
		var a := Vector3(x, top, 0.01)
		var b := Vector3(x + M.rr(seed, i, 5, -0.08, 0.08), top - ln * 0.55, M.rr(seed, i, 6, 0.08, 0.2))
		var c := b + Vector3(M.rr(seed, i, 7, -0.06, 0.06), -ln * 0.45, M.rr(seed, i, 8, 0.05, 0.16))
		M.beam_ab(root, a, b, sw, 0.006, "papel_pintado")
		M.beam_ab(root, b, c, sw * M.rr(seed, i, 9, 0.6, 0.95), 0.006, "papel_pintado")
		# rizo en la punta
		M.cyl(root, 0.025, 0.025, sw * 0.7, c + Vector3(0, -0.01, 0.015), "papel_viejo", Vector3(0, 0, 90), 8)
	root.set_meta("occ", [])
	return root

# ======================================================================================
# polvo: capa de polvo (motas) sobre un piso o un mueble. p: w, d, density.
static func build_polvo(p: Dictionary) -> Node3D:
	var root := M.root("polvo")
	var w := M.pf(p, "w", 1.0); var d := M.pf(p, "d", 1.0)
	L3._set_mat(M.box(root, Vector3(w, 0.004, d), Vector3(0, 0.002, 0), "vela"), L3.mat_polvo(M.pf(p, "density", 0.45), 3.0))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# ceniza_suelo: montoncito de ceniza negra con la colilla de un cheroot y motas sueltas en las tablas.
static func build_ceniza_suelo(p: Dictionary) -> Node3D:
	var root := M.root("ceniza_suelo")
	var seed := M.seed_of(p, "ceniza")
	M.sphere(root, 0.05, Vector3(0, 0.008, 0), "carbon", Vector3(1.5, 0.22, 1.1))
	M.sphere(root, 0.03, Vector3(0.06, 0.006, 0.03), "ceniza", Vector3(1.2, 0.25, 1.0))
	M.cyl(root, 0.007, 0.006, 0.07, Vector3(-0.03, 0.009, 0.05), "madera_oscura", Vector3(90, 0, 70), 8)
	M.cyl(root, 0.0072, 0.0072, 0.012, Vector3(-0.062, 0.009, 0.062), "ceniza", Vector3(90, 0, 70), 8)
	for k in 9:
		M.box(root, Vector3(0.012, 0.003, 0.009), Vector3(M.rr(seed, k, 1, -0.18, 0.2), 0.0015, M.rr(seed, k, 2, -0.14, 0.16)), "carbon", Vector3(0, M.rr(seed, k, 3, 0, 90), 0))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# luz_calle: la luz de un farol de la calle que entra por una ventana (sin geometría): un ancla de lámpara de clase
# "farol" que Lighting enciende en los presets nocturnos y en farol_calle. p: energy (no se usa: la decide el preset),
# range.
static func build_luz_calle(p: Dictionary) -> Node3D:
	var root := M.root("luz_calle")
	var S = load("res://world/props/street.gd")
	S.light_anchor(root, Vector3.ZERO, Color("ffc274"), 3.2, M.pf(p, "range", 6.0), "farol")
	root.set_meta("occ", [])
	return root

# ======================================================================================
# caño_gas: caño de gas cortado que sale del cielo raso (sin araña: casa vacía). p: h (alto del cielo raso).
static func build_cano_gas(p: Dictionary) -> Node3D:
	var root := M.root("cano_gas")
	var h := M.pf(p, "h", 3.5)
	M.cyl(root, 0.1, 0.1, 0.02, Vector3(0, h - 0.01, 0), "yeso", Vector3.ZERO, 16)
	M.rod(root, 0.012, 0.35, Vector3(0, h - 0.18, 0), "laton")
	M.cyl(root, 0.02, 0.02, 0.03, Vector3(0, h - 0.37, 0), "laton", Vector3.ZERO, 8)
	root.set_meta("occ", [])
	return root
