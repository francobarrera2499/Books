# world/props/l3.gd — W2-PLACES-B. Lugar L3 (Baker Street: calle, vestíbulo y salita del 221B, oficina del agente de
# fincas, Camden House enfrente). También lo usan l7.gd / l8.gd (casas de terraza, puertas condicionales).
# Contrato: docs/ARCHITECTURE.md §7.2 (props `"l3.<función>"` → static func build_<función>(p) -> Node3D con meta "occ").
#
# Geometría condicionada por nodos (extensión propia, sin tocar DioramaBuilder): un prop o una parte de un prop puede
# depender de la presencia de un NODO en la instantánea (la que decide día/franja/flags con `when`, §4.11). La pieza es
# un `Gate` (Node3D con script): en _ready busca el diorama (ancestro con meta "nodes_index") y se muestra si alguno de
# `need` está en la instantánea (o `need` vacío) y ninguno de `exclude`. Si es raíz de prop y queda oculta, apaga sus
# oclusores (capa 0): lo que no se ve no tapa ni se clica. Fuera del árbol (sin _ready) todo queda visible.
#   - "l3.gated": envuelve cualquier prop: p = {need:[ids] | node:id, exclude:[ids], type:"<mód>.<fn>", p:{...}}.
#   - build_casa: ventanas con estados alternativos por nodo (`alts`).
# Requiere que la instantánea traiga `nodes` filtrados por `when` (WorldModel.snapshot / q_plate, §3.7). Sin `nodes`
# (precalentado) se construyen todos los nodos: se ve el primer estado alternativo (sirve para compilar pipelines).
# Funciones: gated · sin_ocluir · casa · hilera · descanso · penumbra · paquete_shag · cajon · tablero_llaves · planos ·
#   baldosas · bandeja_tarjetas · paraguero · tablero_alquiler · cartel_papel. Materiales: mat_polvo(densidad, escala)
#   (vidrio y alféizar sucios, alpha scissor), mat_luz_persiana, mat_baldosas.
# Todo determinista (Materials.rnd); sin randf.
extends RefCounted

const M = preload("res://world/materials.gd")
const ARCH = preload("res://world/props/architecture.gd")
const FURN = preload("res://world/props/furniture.gd")
const SMALL = preload("res://world/props/small.gd")
const STREET = preload("res://world/props/street.gd")

# ======================================================================================
# Gate
class Gate extends Node3D:
	var need: Array = []
	var exclude: Array = []

	func _ready() -> void:
		apply()

	func diorama() -> Node:
		var cur: Node = get_parent()
		while cur != null:
			if cur.has_meta("nodes_index"):
				return cur
			cur = cur.get_parent()
		return null

	static func decide(idx: Dictionary, p_need: Array, p_exclude: Array) -> bool:
		var on := p_need.is_empty()
		for n in p_need:
			if idx.has(str(n)):
				on = true
		for n in p_exclude:
			if idx.has(str(n)):
				on = false
		return on

	func apply() -> void:
		var d := diorama()
		if d == null:
			return
		var on := decide(d.get_meta("nodes_index", {}), need, exclude)
		visible = on
		set_meta("gate_on", on)
		if has_meta("prop_id"):
			var pb: Dictionary = d.get_meta("prop_bodies", {})
			for b in pb.get(str(get_meta("prop_id")), []):
				if is_instance_valid(b) and b is CollisionObject3D:
					if not on:
						if not b.has_meta("gate_layer"):
							b.set_meta("gate_layer", b.collision_layer)
						b.collision_layer = 0
					elif b.has_meta("gate_layer"):
						b.collision_layer = int(b.get_meta("gate_layer"))

static func gate(name: String, need: Array, exclude: Array = []) -> Node3D:
	var g := Gate.new()
	g.name = name
	g.need = need.duplicate()
	g.exclude = exclude.duplicate()
	g.set_meta("gate", true)
	return g

# reaplica todas las puertas de un diorama (útil fuera de _ready: tests, capturas)
static func apply_gates(d: Node) -> int:
	var n := 0
	for g in d.find_children("*", "Node3D", true, false):
		if g.has_meta("gate") and g.has_method("apply"):
			g.apply()
			n += 1
	return n

static func _arr(v) -> Array:
	if v is Array:
		return v
	if v == null or str(v) == "":
		return []
	return [str(v)]

# ======================================================================================
# gated: envoltorio de cualquier prop (también "figure.<rasgo>" y "crowd.make") con puerta por nodo.
static func build_gated(p: Dictionary) -> Node3D:
	var need := _arr(p.get("need", p.get("node", null)))
	var g := gate("gated", need, _arr(p.get("exclude", null)))
	var DB: Script = load("res://world/diorama_builder.gd")
	var inner_p: Dictionary = (p.get("p", {}) as Dictionary).duplicate() if p.get("p", {}) is Dictionary else {}
	if not inner_p.has("id"): inner_p["id"] = str(p.get("id", "gated"))
	var inner: Node3D = DB.build_prop(str(p.get("type", "")), inner_p)
	g.add_child(inner)
	var occ: Array = []
	for b in inner.get_meta("occ", []):
		occ.append(b)
	g.set_meta("occ", occ)
	return g

# sin_ocluir: envuelve un prop y le quita los oclusores (lámparas de pared, colgantes finos: no tapan nada que importe)
static func build_sin_ocluir(p: Dictionary) -> Node3D:
	var DB: Script = load("res://world/diorama_builder.gd")
	var inner_p: Dictionary = (p.get("p", {}) as Dictionary).duplicate() if p.get("p", {}) is Dictionary else {}
	if not inner_p.has("id"): inner_p["id"] = str(p.get("id", "sin_ocluir"))
	var root := M.root("sin_ocluir")
	root.add_child(DB.build_prop(str(p.get("type", "")), inner_p))
	root.set_meta("occ", [])
	return root

# ======================================================================================
# Materiales propios (cacheados; deterministas)
static var _mats := {}

# vidrio sucio: manchas de polvo opacas (alpha scissor: el grabado no ve lo transparente; esto sí se dibuja). Ruido de
# valor en dos octavas, repetible, filtrado lineal → manchas de borde redondeado (no motas sueltas que el contorno del
# grabado convertiría en cuadraditos). density ∈ [0, 1]: fracción cubierta aproximada.
static func _vnoise(cells: int, salt: int, x: float, y: float) -> float:
	var gx := x * cells
	var gy := y * cells
	var x0 := int(floor(gx)); var y0 := int(floor(gy))
	var fx := gx - x0; var fy := gy - y0
	fx = fx * fx * (3.0 - 2.0 * fx); fy = fy * fy * (3.0 - 2.0 * fy)
	var a := M.rnd(salt, posmod(x0, cells), posmod(y0, cells))
	var b := M.rnd(salt, posmod(x0 + 1, cells), posmod(y0, cells))
	var c := M.rnd(salt, posmod(x0, cells), posmod(y0 + 1, cells))
	var d := M.rnd(salt, posmod(x0 + 1, cells), posmod(y0 + 1, cells))
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)

static func mat_polvo(density: float = 0.55, scale: float = 1.6) -> Material:
	var key := "polvo:%.2f:%.2f" % [density, scale]
	if _mats.has(key): return _mats[key]
	var S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var base := M.color("yeso_sucio")
	var vals: Array = []
	for y in S:
		for x in S:
			var u := x / float(S); var v := y / float(S)
			vals.append(0.62 * _vnoise(6, 911, u, v) + 0.38 * _vnoise(16, 919, u, v))
	var sorted := vals.duplicate()
	sorted.sort()
	var thr: float = sorted[clampi(int((1.0 - clampf(density, 0.0, 1.0)) * (S * S - 1)), 0, S * S - 1)]
	for y in S:
		for x in S:
			var n: float = vals[y * S + x]
			var a := clampf((n - thr) * 10.0 + 0.5, 0.0, 1.0) if density < 0.999 else 1.0
			var f := 0.72 + 0.4 * n
			img.set_pixel(x, y, Color(base.r * f, base.g * f, base.b * f, a))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 1.0
	m.metallic_specular = 0.2
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	_mats[key] = m
	return m

# persiana iluminada desde adentro (noche): emisiva tibia
static func mat_luz_persiana() -> Material:
	if _mats.has("luz_persiana"): return _mats["luz_persiana"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f2dcae")
	m.emission_enabled = true
	m.emission = Color("ffcf86")
	m.emission_energy_multiplier = 1.6
	m.roughness = 1.0
	_mats["luz_persiana"] = m
	return m

# baldosas del vestíbulo (damero de terracota y piedra, con guarda)
static func mat_baldosas() -> Material:
	if _mats.has("baldosas"): return _mats["baldosas"]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var a := M.color("piedra_portland")
	var b := M.color("pintura_roja") * 1.15
	var j := M.color("madera_negra")
	img.fill(j)
	for r in 8:
		for c in 8:
			var col := a if (r + c) % 2 == 0 else b
			var f := 0.92 + 0.12 * M.rnd(917, r, c)
			img.fill_rect(Rect2i(c * 16 + 1, r * 16 + 1, 14, 14), Color(col.r * f, col.g * f, col.b * f))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 0.64, 1.0 / 0.64, 1.0 / 0.64)
	m.roughness = 1.0
	m.metallic_specular = 0.25
	_mats["baldosas"] = m
	return m

static func _set_mat(mi: MeshInstance3D, m: Material) -> MeshInstance3D:
	mi.material_override = m
	return mi

# tablero pintado de un agente (letras negras): papel con algo de luz propia para que la sombra no lo cubra de rayado
# cruzado bajo el grabado (sin esto «SE ALQUILA» sólo se leía a la mañana). Sutil: de noche no parece un cartel luminoso.
static func mat_tablero() -> Material:
	if _mats.has("tablero"): return _mats["tablero"]
	var m := StandardMaterial3D.new()
	m.albedo_color = M.color("papel")
	m.emission_enabled = true
	m.emission = M.color("papel")
	m.emission_energy_multiplier = 0.32
	m.roughness = 1.0
	_mats["tablero"] = m
	return m

# tamaño de píxel de un Label3D para que todo su texto (renglones con \n, sin autowrap) quepa en w × h metros; tope max_px.
# Usa las métricas de la fuente del rótulo (determinista para una misma fuente).
static func fit_px(lb: Label3D, w: float, h: float, max_px: float) -> float:
	var f: Font = lb.font if lb.font != null else ThemeDB.fallback_font
	if f == null: return max_px
	var lines := lb.text.split("\n")
	var mw := 1.0
	for l in lines:
		mw = maxf(mw, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, lb.font_size).x)
	var line_px := f.get_height(lb.font_size) + lb.line_spacing
	return minf(max_px, minf(w / mw, h / maxf(lines.size() * line_px, 1.0)))

# ======================================================================================
# casa: frente de casa de terraza londinense con estado por ventana. Origen = pie de la fachada (vereda, y=0), frente +Z;
# el muro ocupa z ∈ [−t, 0]. Parámetros:
#  w, h (alto del cuerpo, sin pretil), parapet, levels (nivel de piso de cada planta, planta baja primero), bays,
#  door_bay (−1 = sin puerta), style ("stock_brick" | "estuco"), seed, number (placa sobre la puerta), door_paint,
#  broad {"<planta>": n} (n ventanas anchas en esa planta, p. ej. el primer piso del 221B), area (patio inglés con verja
#  y escalones; def true), area_d, hollow ["p:k"] (sin fondo oscuro: hay un cuarto de verdad detrás), hollow_door,
#  dusty (todo el vidrio sucio, sin persianas ni cortinas: casa vacía), win {"p:k": estado}, alts [{node, keys:[...],
#  state:{...}}] (estado alternativo condicionado por nodo; el primero presente gana; por defecto, si ninguno),
#  shop {sign, door_bay, letters} (planta baja de oficina/tienda, sin mercadería; detrás un cuarto real).
# Estado de ventana: open (0..1, hoja de abajo), blind (0..1 bajada), blind_mat (material; def lienzo), curtains (bool), curtain_out,
#  lit (fondo iluminado), bust (silueta de un hombre sentado en la persiana iluminada), dusty (bool), dark (fondo).
# Ventanas: claves "p:k" (planta p desde 0, k desde la izquierda −X local). Meta "windows": {clave: {x, sill, w, h}}.
static func build_casa(p: Dictionary) -> Node3D:
	var root := M.root("casa")
	var w := M.pf(p, "w", 6.6)
	var levels: Array = p.get("levels", [0.6, 4.0, 7.3, 10.1])
	var body_h := M.pf(p, "h", 12.6)
	var parapet := M.pf(p, "parapet", 0.7)
	var bays := maxi(M.pi_(p, "bays", 3), 1)
	var door_bay := M.pi_(p, "door_bay", 0)
	var style := M.ps(p, "style", "stock_brick")
	var seed := M.seed_of(p, "casa")
	var t := 0.3
	var brick := "ladrillo_stock" if style == "stock_brick" else "estuco"
	if M.ps(p, "brick", "") != "": brick = M.ps(p, "brick", "")
	var stucco := "estuco"
	var shop: Dictionary = p.get("shop", {}) if p.get("shop", {}) is Dictionary else {}
	var is_shop := not shop.is_empty()
	if is_shop: door_bay = M.pi_(shop, "door_bay", door_bay)
	var dusty := M.pb(p, "dusty", false)
	var hollow: Array = p.get("hollow", []) if p.get("hollow", []) is Array else []
	var win_over: Dictionary = p.get("win", {}) if p.get("win", {}) is Dictionary else {}
	var alts: Array = p.get("alts", []) if p.get("alts", []) is Array else []
	var broad: Dictionary = p.get("broad", {}) if p.get("broad", {}) is Dictionary else {}
	var bay_w := w / bays
	var nf := levels.size()
	var lv := func(i: int) -> float: return float(levels[i]) if i < nf else body_h
	# ---- vanos
	var ops: Array = []
	var wins := {}
	var door_x := -w / 2 + bay_w * (door_bay + 0.5)
	for f in nf:
		var f0: float = lv.call(f)
		var f1: float = lv.call(f + 1)
		var fh := f1 - f0
		if f == 0:
			if is_shop:
				var g0 := 0.0
				var sh_top := minf(f1 - 0.75, 3.4)
				ops.append({"x": door_x, "w": 1.0, "h": 2.5, "sill": g0 + 0.02, "kind": "shopdoor"})
				# vidriera corrida en los demás vanos
				var segs: Array = []
				for b in bays:
					if b == door_bay: continue
					segs.append(-w / 2 + bay_w * (b + 0.5))
				for k in segs.size():
					var sx: float = segs[k]
					ops.append({"x": sx, "w": bay_w * 0.86, "h": sh_top - 0.62, "sill": 0.62, "kind": "shopwin", "key": "0:%d" % k})
			else:
				var k0 := 0
				for b in bays:
					var cx := -w / 2 + bay_w * (b + 0.5)
					if b == door_bay:
						ops.append({"x": cx, "w": minf(bay_w * 0.5, 1.15), "h": minf(fh - 0.75, 3.05), "sill": f0, "kind": "door"})
					else:
						ops.append({"x": cx, "w": minf(bay_w * 0.5, 1.12), "h": fh * 0.6, "sill": f0 + 0.75, "kind": "window", "key": "0:%d" % k0, "floor": 0})
						k0 += 1
		else:
			var cnt := int(broad.get(str(f), 0))
			var top_floor := f == nf - 1
			var sill := f0 + (0.5 if f == 1 else (0.42 if top_floor else 0.45))
			var wh := fh * (0.66 if f == 1 else (0.6 if top_floor else 0.62))
			if cnt > 0:
				for k in cnt:
					var cx2 := -w / 2 + w * (k + 0.5) / cnt
					ops.append({"x": cx2, "w": minf(w / cnt * 0.48, 1.55), "h": wh, "sill": sill, "kind": "window", "key": "%d:%d" % [f, k], "floor": f})
			else:
				for b in bays:
					var cx3 := -w / 2 + bay_w * (b + 0.5)
					ops.append({"x": cx3, "w": minf(bay_w * 0.45, 1.1), "h": wh * (0.9 if top_floor else 1.0), "sill": sill, "kind": "window", "key": "%d:%d" % [f, b], "floor": f})
	# ---- muro
	var wn := Node3D.new(); wn.name = "wall"; wn.position = Vector3(0, 0, -t / 2); root.add_child(wn)
	var bands: Array = []
	var ground_h: float = lv.call(1)
	if is_shop: bands.append([0.0, ground_h, "madera_negra"])
	elif style == "stock_brick": bands.append([0.0, ground_h, stucco])
	var wboxes := ARCH.wall_strips(wn, w, t, [[-w / 2, body_h]], ops, brick, bands)
	var occ: Array = []
	for b in wboxes: occ.append(wn.transform * b)
	# almohadillado de la planta baja (líneas horizontales del estuco)
	if not is_shop and style == "stock_brick":
		var ny := int(ground_h / 0.42)
		for k in range(1, ny):
			M.box(root, Vector3(w + 0.01, 0.025, 0.012), Vector3(0, k * ground_h / ny, 0.004), "yeso_sucio")
	# medianeras visibles al costado (cuerpo detrás)
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.12, body_h + parapet, 0.5), Vector3(sx * (w / 2 - 0.06), (body_h + parapet) / 2, -0.25 - t), brick)
	# ---- contenido de vanos
	var wmeta := {}
	for o in ops:
		var kind: String = o["kind"]
		var ox: float = o["x"]; var ow: float = o["w"]; var oh: float = o["h"]; var os: float = o["sill"]
		var key := str(o.get("key", ""))
		match kind:
			"window":
				# dintel y alféizar exterior (compartidos por todos los estados)
				M.box(root, Vector3(ow + 0.12, 0.16, 0.05), Vector3(ox, os + oh + 0.08, 0.02), stucco if style == "estuco" else "ladrillo_hollin")
				if style == "estuco" and int(o.get("floor", 0)) == 1:
					M.box(root, Vector3(ow + 0.36, 0.1, 0.12), Vector3(ox, os + oh + 0.24, 0.05), stucco)
					M.box(root, Vector3(0.1, oh, 0.06), Vector3(ox - ow / 2 - 0.08, os + oh / 2, 0.02), stucco)
					M.box(root, Vector3(0.1, oh, 0.06), Vector3(ox + ow / 2 + 0.08, os + oh / 2, 0.02), stucco)
				var base_st := {"open": 0.0, "blind": 0.0, "curtains": false, "dusty": dusty, "dark": true}
				if not dusty:
					# persianas a medio bajar en algunas ventanas (vida en la fachada), deterministas
					if M.rnd(seed, int(ox * 7 + 3), int(os * 3)) < 0.4:
						base_st["blind"] = M.rr(seed, int(ox * 5), int(os * 5), 0.2, 0.5)
					base_st["curtains"] = M.rnd(seed, int(ox * 11), int(os * 2)) < 0.55
				if hollow.has(key): base_st["dark"] = false
				if win_over.has(key) and win_over[key] is Dictionary:
					for kk in win_over[key]: base_st[kk] = win_over[key][kk]
				# estados alternativos por nodo
				var my_alts: Array = []
				for a in alts:
					if a is Dictionary and (a.get("keys", []) as Array).has(key):
						my_alts.append(a)
				var holder := Node3D.new(); holder.name = "win_" + key.replace(":", "_"); holder.position = Vector3(ox, os, -0.12)
				root.add_child(holder)
				if my_alts.is_empty():
					_window(holder, ow, oh, base_st, seed, int(o.get("floor", 0)), nf)
				else:
					var prev: Array = []
					for a in my_alts:
						var st2 := base_st.duplicate()
						for kk in (a.get("state", {}) as Dictionary): st2[kk] = a["state"][kk]
						var nid := str(a.get("node", ""))
						var g := gate("alt_" + nid, [nid], prev)
						holder.add_child(g)
						_window(g, ow, oh, st2, seed, int(o.get("floor", 0)), nf)
						prev.append(nid)
					var gd := gate("alt_default", [], prev)
					holder.add_child(gd)
					_window(gd, ow, oh, base_st, seed, int(o.get("floor", 0)), nf)
				wmeta[key] = {"x": ox, "sill": os, "w": ow, "h": oh}
			"door":
				var nh := Node3D.new(); nh.name = "door"; nh.position = Vector3(ox, os, -0.12); root.add_child(nh)
				var dh := oh * 0.78
				var dr := ARCH.build_door({"w": ow, "h": dh, "paint": M.ps(p, "door_paint", "madera_negra"), "depth": 0.12, "panels": 6})
				nh.add_child(dr)
				# la puerta cerrada tapa (lo de adentro no se clica desde la calle)
				occ.append(M.aabb_mm(Vector3(ox - ow / 2, os, -t), Vector3(ox + ow / 2, os + dh, 0.0)))
				# montante con radios
				M.box(nh, Vector3(ow, 0.05, 0.1), Vector3(0, dh + 0.025, 0), "vela")
				var fan_h := oh - dh
				var fan := M.box(nh, Vector3(ow - 0.08, fan_h - 0.08, 0.006), Vector3(0, dh + fan_h / 2, -0.02), "interior_oscuro")
				if dusty: _set_mat(M.box(nh, Vector3(ow - 0.08, fan_h - 0.08, 0.004), Vector3(0, dh + fan_h / 2, 0.0), "vela"), mat_polvo(0.6))
				for k in 5:
					var a2 := PI * (k + 1) / 6.0
					var c := Vector3(0, dh + 0.05, 0.02)
					M.beam_ab(nh, c, c + Vector3(cos(a2) * ow * 0.45, sin(a2) * (fan_h - 0.1), 0), 0.02, 0.02, "vela")
				# portada
				for sx: float in [-1.0, 1.0]:
					M.box(root, Vector3(0.16, oh + 0.1, 0.12), Vector3(ox + sx * (ow / 2 + 0.1), os + (oh + 0.1) / 2, 0.06), stucco)
				M.box(root, Vector3(ow + 0.6, 0.22, 0.22), Vector3(ox, os + oh + 0.2, 0.1), stucco)
				M.box(root, Vector3(ow + 0.7, 0.06, 0.28), Vector3(ox, os + oh + 0.34, 0.12), stucco)
				var num := M.ps(p, "number", "")
				if num != "":
					# placa esmaltada clara con el número (tinta oscura: se lee bajo el grabado)
					M.box(root, Vector3(0.66, 0.28, 0.02), Vector3(ox, os + oh + 0.2, 0.235), "vela")
					M.box(root, Vector3(0.7, 0.32, 0.012), Vector3(ox, os + oh + 0.2, 0.226), "madera_negra")
					var lb := M.label3d(root, num, Vector3(ox, os + oh + 0.2, 0.247), 0.0046, 48, Color("1b1712"))
					lb.name = "numero"
				wmeta["door"] = {"x": ox, "sill": os, "w": ow, "h": oh}
			"shopdoor":
				var nh2 := Node3D.new(); nh2.name = "door"; nh2.position = Vector3(ox, os, -0.12); root.add_child(nh2)
				nh2.add_child(ARCH.build_door({"w": ow, "h": oh, "paint": "madera_negra", "depth": 0.12}))
				occ.append(M.aabb_mm(Vector3(ox - ow / 2, os, -t), Vector3(ox + ow / 2, os + oh, 0.0)))
				wmeta["door"] = {"x": ox, "sill": os, "w": ow, "h": oh}
			"shopwin":
				var nh3 := Node3D.new(); nh3.name = "shopwin_" + key.replace(":", "_"); nh3.position = Vector3(ox, os, -0.12); root.add_child(nh3)
				M.box(nh3, Vector3(ow, oh, 0.01), Vector3(0, oh / 2, 0), "vidrio")
				for k in 2:
					M.box(nh3, Vector3(0.035, oh, 0.05), Vector3(-ow / 2 + ow * (k + 1) / 3.0, oh / 2, 0.01), "madera_negra")
				M.box(nh3, Vector3(ow, 0.05, 0.08), Vector3(0, oh - 0.45, 0.01), "madera_negra")
				M.box(nh3, Vector3(ow + 0.05, 0.08, 0.2), Vector3(0, -0.04, 0.08), "madera_negra")
				# zócalo de la vidriera
				M.box(root, Vector3(ow + 0.06, os, 0.1), Vector3(ox, os / 2, 0.02), "madera_negra")
				var letters := M.ps(shop, "letters", "")
				if letters != "":
					# rótulo pintado sobre el vidrio: letras oscuras sobre una franja clara (legible en el grabado)
					M.box(nh3, Vector3(ow * 0.8, 0.2, 0.004), Vector3(0, oh * 0.55, 0.012), "papel")
					var l2 := M.label3d(nh3, letters, Vector3(0, oh * 0.55, 0.016), 0.0026, 48, Color("1b1712"))
					l2.name = "letras"
				wmeta[key] = {"x": ox, "sill": os, "w": ow, "h": oh}
	# ---- impostas, cornisa, pretil, techo, chimeneas
	for f in range(1, nf):
		M.box(root, Vector3(w + 0.04, 0.12, 0.08), Vector3(0, float(levels[f]), 0.04), stucco)
	if is_shop:
		var fy: float = ground_h - 0.6
		M.box(root, Vector3(w, 0.55, 0.12), Vector3(0, fy + 0.27, 0.08), "madera_negra")
		M.box(root, Vector3(w + 0.1, 0.08, 0.22), Vector3(0, fy + 0.58, 0.1), "madera_negra")
		for sx: float in [-1.0, 1.0]:
			M.box(root, Vector3(0.22, ground_h, 0.14), Vector3(sx * (w / 2 - 0.11), ground_h / 2, 0.07), "madera_negra")
		var sign_txt := M.ps(shop, "sign", "")
		if sign_txt != "":
			M.box(root, Vector3(w * 0.78, 0.38, 0.02), Vector3(0, fy + 0.27, 0.15), "papel")
			var l3 := M.label3d(root, sign_txt, Vector3(0, fy + 0.27, 0.162), minf(0.006, w * 0.72 / (48.0 * 0.62 * maxf(sign_txt.length(), 1))), 48, Color("1b1712"))
			l3.name = "rotulo"
	M.box(root, Vector3(w + 0.1, 0.18, 0.32), Vector3(0, body_h - 0.09, 0.12), stucco)
	M.box(root, Vector3(w + 0.16, 0.06, 0.4), Vector3(0, body_h + 0.02, 0.15), stucco)
	if parapet > 0:
		M.box(root, Vector3(w, parapet, t), Vector3(0, body_h + parapet / 2, -t / 2), brick)
		M.box(root, Vector3(w + 0.06, 0.06, t + 0.06), Vector3(0, body_h + parapet + 0.03, -t / 2), "piedra_portland")
	M.box(root, Vector3(w, 0.06, 1.2), Vector3(0, body_h + 0.45, -0.75), "pizarra", Vector3(-24, 0, 0))
	if M.pb(p, "chimneys", true):
		for sx: float in [-1.0, 1.0]:
			var cxp := sx * (w / 2 - 0.35)
			var top := body_h + parapet
			M.box(root, Vector3(0.6, 1.2, 0.5), Vector3(cxp, top + 0.6, -0.5), brick)
			M.box(root, Vector3(0.68, 0.08, 0.58), Vector3(cxp, top + 1.22, -0.5), "piedra_portland")
			for k in 3:
				M.cyl(root, 0.06, 0.08, 0.35, Vector3(cxp - 0.18 + k * 0.18, top + 1.43, -0.5), "cobre", Vector3.ZERO, 10)
	# ---- patio inglés con verja y escalones al portal
	var f0g: float = lv.call(0)
	if M.pb(p, "area", not is_shop):
		var ad := M.pf(p, "area_d", 1.3)
		var gap_w := (minf(bay_w * 0.5, 1.15) + 0.5) if door_bay >= 0 else 0.0
		var rl := ARCH.build_railing({"len": w, "h": 1.0, "plinth": true, "gap_x": door_x if door_bay >= 0 else 1e9, "gap_w": gap_w})
		rl.position = Vector3(0, 0, ad)
		root.add_child(rl)
		for b in rl.get_meta("occ", []): occ.append(rl.transform * b)
		# pozo del sótano (oscuro) salvo el puente de la entrada
		var pits: Array = [[-w / 2 + 0.06, door_x - gap_w / 2], [door_x + gap_w / 2, w / 2 - 0.06]] if door_bay >= 0 else [[-w / 2 + 0.06, w / 2 - 0.06]]
		for seg in pits:
			if float(seg[1]) - float(seg[0]) > 0.05:
				M.box(root, Vector3(float(seg[1]) - float(seg[0]), 0.01, ad - 0.2), Vector3((float(seg[0]) + float(seg[1])) / 2, 0.006, ad / 2 - 0.02), "interior_oscuro")
		if door_bay >= 0 and f0g > 0.05:
			var nst := maxi(int(round(f0g / 0.16)), 1)
			for k in nst:
				var sy := f0g * (k + 1) / nst
				var dz := ad * (nst - k) / nst
				M.box(root, Vector3(gap_w - 0.1, f0g / nst, dz), Vector3(door_x, sy - f0g / nst / 2, dz / 2), "piedra_portland")
			occ.append(M.aabb_mm(Vector3(door_x - gap_w / 2, 0, 0), Vector3(door_x + gap_w / 2, f0g, ad)))
	elif door_bay >= 0 and f0g > 0.05:
		var nst2 := maxi(int(round(f0g / 0.16)), 1)
		for k in nst2:
			M.box(root, Vector3(1.4, f0g / nst2, 0.3 * (nst2 - k)), Vector3(door_x, f0g * (k + 0.5) / nst2, 0.15 * (nst2 - k)), "piedra_portland")
	occ.append(M.aabb_mm(Vector3(-w / 2, body_h, -t), Vector3(w / 2, body_h + parapet, 0.0)))
	root.set_meta("occ", occ)
	root.set_meta("windows", wmeta)
	return root

# una ventana de guillotina con su estado; origen = centro inferior del vano, plano del marco
static func _window(parent: Node3D, ow: float, oh: float, st: Dictionary, seed: int, floor_i: int, nf: int) -> void:
	var open := clampf(float(st.get("open", 0.0)), 0.0, 1.0)
	var panes := 4 if floor_i == nf - 1 else 2
	var sw := ARCH.build_sash_window({"w": ow, "h": oh, "panes": panes, "paint": "vela", "depth": 0.1, "open_frac": open})
	parent.add_child(sw)
	var lit := bool(st.get("lit", false))
	var back_z := -0.3 - 0.06 + 0.12
	if lit:
		# cuarto iluminado: la persiana bajada brilla; la silueta del busto se recorta sobre ella
		_set_mat(M.box(parent, Vector3(ow + 0.02, oh + 0.02, 0.04), Vector3(0, oh / 2, back_z), "vela"), mat_luz_persiana())
	elif bool(st.get("dark", true)):
		M.box(parent, Vector3(ow + 0.02, oh + 0.02, 0.04), Vector3(0, oh / 2, back_z), "interior_oscuro")
	var blind := clampf(float(st.get("blind", 0.0)), 0.0, 1.0)
	if blind > 0.0:
		var bh := oh * blind - 0.06
		var bm := M.box(parent, Vector3(ow - 0.1, bh, 0.008), Vector3(0, oh - 0.05 - bh / 2, -0.07), str(st.get("blind_mat", "lienzo")))
		if lit: _set_mat(bm, mat_luz_persiana())
		M.box(parent, Vector3(ow - 0.08, 0.025, 0.02), Vector3(0, oh - 0.05 - bh, -0.07), "madera_media")
	if bool(st.get("bust", false)):
		# sombra de un hombre sentado, de perfil, sobre la persiana iluminada («black silhouettes», EMPT): respaldo del
		# sillón, hombros cuadrados, cuello, cabeza alta con nariz aguileña. Plana, pegada a la persiana del lado de la calle.
		# Hombros, cuello y cabeza van en la hoja de ARRIBA (por encima del travesaño del medio, que si no corta el busto
		# por los hombros y la cabeza queda flotando como una bola en un palo): el busto se lee entero de un vistazo.
		var sil := Node3D.new(); sil.name = "busto"; sil.position = Vector3(-ow * 0.04, 0.0, -0.062); parent.add_child(sil)
		var u := minf(ow, oh * 0.75)
		M.box(sil, Vector3(u * 0.66, oh * 0.42, 0.004), Vector3(-u * 0.06, oh * 0.21, 0), "carbon")                # respaldo
		M.box(sil, Vector3(u * 0.56, oh * 0.2, 0.004), Vector3(0, oh * 0.46, 0), "carbon")                         # torso
		M.prism(sil, Vector3(u * 0.62, oh * 0.11, 0.004), Vector3(0, oh * 0.615, 0), "carbon")                     # hombros caídos
		for sx: float in [-1.0, 1.0]:
			M.sphere(sil, oh * 0.04, Vector3(sx * u * 0.265, oh * 0.565, 0), "carbon", Vector3(1.3, 1.0, 0.05))  # hombros redondos
		M.box(sil, Vector3(u * 0.1, oh * 0.08, 0.004), Vector3(u * 0.02, oh * 0.65, 0), "carbon")                   # cuello
		M.sphere(sil, u * 0.1, Vector3(u * 0.03, oh * 0.75, 0), "carbon", Vector3(0.88, 1.2, 0.04))                # cabeza
		M.box(sil, Vector3(u * 0.065, u * 0.04, 0.004), Vector3(u * 0.13, oh * 0.745, 0), "carbon", Vector3(0, 0, -28))  # nariz
		M.box(sil, Vector3(u * 0.055, u * 0.035, 0.004), Vector3(u * 0.1, oh * 0.7, 0), "carbon")                    # mentón
	if bool(st.get("curtains", false)):
		var cm := "terciopelo" if seed % 2 == 0 else "tela_media"
		for side: float in [-1.0, 1.0]:
			for f in 3:
				M.cyl(parent, 0.035, 0.05, oh - 0.1, Vector3(side * (ow / 2 - 0.1 - f * 0.05), oh / 2 - 0.02, -0.16 - 0.015 * (f % 2)), cm, Vector3.ZERO, 8)
	if bool(st.get("curtain_out", false)):
		# cortina que el aire saca por la hoja abierta: tela que asoma y cuelga afuera, sobre el alféizar
		var cmat := "lienzo"
		var a := Vector3(-ow * 0.18, oh * 0.48, -0.1)
		var b := Vector3(-ow * 0.12, -0.02, 0.2)
		M.beam_ab(parent, a, b, ow * 0.32, 0.02, cmat)
		M.beam_ab(parent, b, b + Vector3(0.03, -0.42, 0.06), ow * 0.3, 0.02, cmat)
		M.beam_ab(parent, Vector3(ow * 0.2, oh * 0.46, -0.12), Vector3(ow * 0.24, 0.05, -0.05), ow * 0.18, 0.02, cmat)
	if bool(st.get("dusty", false)):
		# polvo de meses sobre las dos hojas (motas opacas: el grabado las ve)
		var fr := 0.06
		var iw := ow - 2 * fr
		var ih := oh - fr - fr * 0.8
		var sh := ih / 2.0
		var y_low := fr * 0.8 + open * (ih / 2.0 - 0.04)
		_set_mat(M.box(parent, Vector3(iw - 0.07, sh - 0.07, 0.003), Vector3(0, fr * 0.8 + ih - sh / 2.0 + 0.01, -0.02), "vela"), mat_polvo(0.64))
		_set_mat(M.box(parent, Vector3(iw - 0.07, sh - 0.07, 0.003), Vector3(0, y_low + sh / 2.0 + 0.01, 0.031), "vela"), mat_polvo(0.72))

# ======================================================================================
# hilera: fila de casas de terraza a lo largo de X local (vecinas de fondo). p: n, w (ancho de cada una), seed, style,
# styles (lista alternada), area, h_var (variación de alto), shop_at (índice con planta comercial), sign, dusty_at.
# Cada casa: build_casa con puerta y persianas variadas por semilla. Origen = centro del pie de la fila.
static func build_hilera(p: Dictionary) -> Node3D:
	var root := M.root("hilera")
	var n := maxi(M.pi_(p, "n", 3), 1)
	var w := M.pf(p, "w", 6.6)
	var seed := M.pi_(p, "seed", 21)
	var styles: Array = p.get("styles", [M.ps(p, "style", "stock_brick")])
	var occ: Array = []
	for i in n:
		var cx := -w * n / 2.0 + w * (i + 0.5)
		var hv := M.pf(p, "h_var", 0.8) * (M.rnd(seed, i, 1) - 0.5)
		var levels: Array = p.get("levels", [0.6, 4.0, 7.3, 10.1])
		var q := {"w": w - 0.02, "h": M.pf(p, "h", 12.6) + hv, "levels": levels, "bays": M.pi_(p, "bays", 3),
			"door_bay": int(M.rnd(seed, i, 2) * 3) % 3, "style": str(styles[i % styles.size()]), "seed": seed * 31 + i,
			"area": M.pb(p, "area", true), "chimneys": true}
		if i == M.pi_(p, "shop_at", -1):
			q["shop"] = {"sign": M.ps(p, "sign", ""), "door_bay": 0}
			q["levels"] = [0.1] + levels.slice(1)
			q["area"] = false
		if i == M.pi_(p, "dusty_at", -1):
			q["dusty"] = true
		var c := build_casa(q)
		c.position = Vector3(cx, 0, 0)
		c.name = "casa_%d" % i
		root.add_child(c)
		for b in c.get_meta("occ", []):
			occ.append(c.transform * b)
	root.set_meta("occ", occ)
	return root

# ======================================================================================
# descanso: rellano del primer piso al tope de la escalera (vista desde el vestíbulo), con balaustrada sobre el hueco,
# zócalo inferior y, detrás de la puerta entreabierta, un cuarto en penumbra. Origen = centro del borde delantero del
# rellano a nivel del piso de la planta baja; el rellano ocupa z ∈ [−d, 0] a altura h. p: w, d, h, rail_from, rail_to (x).
static func build_descanso(p: Dictionary) -> Node3D:
	var root := M.root("descanso")
	var w := M.pf(p, "w", 2.4); var d := M.pf(p, "d", 1.8); var h := M.pf(p, "h", 3.4)
	M.box(root, Vector3(w, 0.18, d), Vector3(0, h - 0.09, -d / 2), "madera_media")
	M.box(root, Vector3(w, 0.03, d), Vector3(0, h + 0.015, -d / 2), "suelo_tablas")
	# alfombra del rellano y faldón
	M.box(root, Vector3(w * 0.5, 0.006, d * 0.8), Vector3(M.pf(p, "runner_x", 0.0), h + 0.033, -d / 2), "terciopelo")
	M.box(root, Vector3(w, 0.22, 0.03), Vector3(0, h - 0.07, 0.015), "madera_oscura")
	# balaustrada sobre el hueco (desde rail_from hasta rail_to en x)
	var r0 := M.pf(p, "rail_from", -0.2); var r1 := M.pf(p, "rail_to", w / 2)
	var n := int((r1 - r0) / 0.13)
	for k in n + 1:
		var x := r0 + (r1 - r0) * k / maxf(n, 1)
		M.cyl(root, 0.014, 0.018, 0.84, Vector3(x, h + 0.45, -0.06), "madera_oscura", Vector3.ZERO, 8)
	M.box(root, Vector3(r1 - r0 + 0.1, 0.06, 0.07), Vector3((r0 + r1) / 2, h + 0.9, -0.06), "caoba")
	M.cyl(root, 0.05, 0.06, 1.0, Vector3(r0, h + 0.5, -0.06), "caoba", Vector3.ZERO, 8)
	M.sphere(root, 0.06, Vector3(r0, h + 1.05, -0.06), "caoba")
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, h - 0.2, -d), Vector3(w / 2, h + 0.03, 0.03))])
	return root

# fondo oscuro detrás de una puerta (cuarto en penumbra); p: w, h, y. Opcional `light` (franja de luz por la rendija).
static func build_penumbra(p: Dictionary) -> Node3D:
	var root := M.root("penumbra")
	var w := M.pf(p, "w", 1.4); var h := M.pf(p, "h", 2.4)
	M.box(root, Vector3(w, h, 0.05), Vector3(0, h / 2, 0), "interior_oscuro")
	for sx: float in [-1.0, 1.0]:
		M.box(root, Vector3(0.05, h, 0.5), Vector3(sx * w / 2, h / 2, 0.25), "interior_oscuro")
	M.box(root, Vector3(w, 0.05, 0.5), Vector3(0, h, 0.25), "interior_oscuro")
	root.set_meta("occ", [])
	return root

# ======================================================================================
# paquete_shag: una libra de tabaco en paquete de papel atado con hilo y faja del estanco; al lado, la tira de la faja.
static func build_paquete_shag(p: Dictionary) -> Node3D:
	var root := M.root("paquete_shag")
	M.box(root, Vector3(0.2, 0.08, 0.13), Vector3(0, 0.04, 0), "papel_viejo")
	M.box(root, Vector3(0.205, 0.004, 0.02), Vector3(0, 0.08, 0), "lienzo")
	M.box(root, Vector3(0.02, 0.084, 0.135), Vector3(0, 0.042, 0), "lienzo")
	M.box(root, Vector3(0.06, 0.002, 0.135), Vector3(0.05, 0.081, 0), "pintura_roja")
	# hebras sueltas sobre la mesa
	var seed := M.seed_of(p, "shag")
	for k in 9:
		M.box(root, Vector3(M.rr(seed, k, 1, 0.01, 0.03), 0.004, 0.003), Vector3(0.14 + M.rr(seed, k, 2, -0.02, 0.05), 0.002, M.rr(seed, k, 3, -0.06, 0.06)), "madera_oscura", Vector3(0, M.rr(seed, k, 4, 0, 180), 0))
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.1, 0, -0.07), Vector3(0.1, 0.085, 0.07))])
	return root

# ======================================================================================
# cajon_grenoble: cajón de gran velocidad con etiqueta legible (texto literal p.label) y la marca a plantilla en el
# costado. Wrapper de furniture.crate (sin su etiqueta chica) con una etiqueta grande de papel.
static func build_cajon(p: Dictionary) -> Node3D:
	var w := M.pf(p, "w", 0.7); var h := M.pf(p, "h", 0.95); var d := M.pf(p, "d", 0.6)
	var root := FURN.build_crate({"w": w, "h": h, "d": d, "mat": "madera_clara", "seed": M.pi_(p, "seed", 9)})
	root.name = "cajon"
	var txt := M.ps(p, "label", "")
	if txt != "":
		# etiqueta grande; el texto (renglones explícitos con \n, sin autowrap) se escala para caber ENTERO en el papel:
		# con autowrap el primer renglón («G.V. — GRENOBLE») quedaba fuera del papel, tinta sobre madera oscura.
		var lw := minf(w * 0.88, 0.64)
		var lh := minf(h * 0.6, 0.56)
		var ly := h * 0.56
		M.box(root, Vector3(lw, lh, 0.004), Vector3(0, ly, d / 2 + 0.004), "papel")
		var lb := M.label3d(root, txt, Vector3(0, ly, d / 2 + 0.008), 0.0012, 48, Color("1b1712"))
		lb.autowrap_mode = TextServer.AUTOWRAP_OFF
		lb.pixel_size = fit_px(lb, lw - 0.05, lh - 0.05, 0.0014)
		lb.name = "etiqueta"
	var side := M.ps(p, "stencil", "")
	if side != "":
		var l2 := M.label3d(root, side, Vector3(w / 2 + 0.012, h * 0.5, 0), 0.0024, 48, Color("1b1712"))
		l2.rotation_degrees = Vector3(0, 90, 0)
		l2.name = "plantilla"
	return root

# ======================================================================================
# tablero_llaves: tablero de pared con ganchos, llaves y rótulos de cartón. Origen = centro inferior contra la pared (+Z).
static func build_tablero_llaves(p: Dictionary) -> Node3D:
	var root := M.root("tablero_llaves")
	var w := M.pf(p, "w", 1.1); var h := M.pf(p, "h", 0.8); var y := M.pf(p, "y", 1.2)
	var seed := M.seed_of(p, "llaves")
	M.box(root, Vector3(w, h, 0.03), Vector3(0, y + h / 2, 0.015), "madera_oscura")
	M.box(root, Vector3(w + 0.06, 0.05, 0.05), Vector3(0, y + h + 0.025, 0.025), "madera_negra")
	var rows := 4; var cols := int(w / 0.13)
	for r in rows:
		for c in cols:
			var x := -w / 2 + 0.08 + c * (w - 0.16) / maxf(cols - 1, 1)
			var yy := y + h - 0.12 - r * (h - 0.2) / (rows - 1)
			M.cyl(root, 0.005, 0.005, 0.03, Vector3(x, yy, 0.045), "laton", Vector3(90, 0, 0), 6)
			if M.rnd(seed, r, c) < 0.78:
				M.box(root, Vector3(0.012, 0.075, 0.006), Vector3(x, yy - 0.05, 0.05), "hierro")
				M.torus(root, 0.008, 0.016, Vector3(x, yy - 0.005, 0.05), "hierro", Vector3(90, 0, 0))
				M.box(root, Vector3(0.05, 0.03, 0.002), Vector3(x + 0.012, yy - 0.1, 0.052), "papel_viejo", Vector3(0, 0, M.rr(seed, r, c + 40, -12, 12)))
	root.set_meta("occ", [M.aabb_mm(Vector3(-w / 2, y, 0), Vector3(w / 2, y + h, 0.06))])
	return root

# ======================================================================================
# planos: hojas de planos de casas clavadas en la pared (rectángulos con trazos). Origen = centro inferior contra la pared.
static func build_planos(p: Dictionary) -> Node3D:
	var root := M.root("planos")
	var n := M.pi_(p, "n", 3); var y := M.pf(p, "y", 1.35)
	var seed := M.seed_of(p, "planos")
	var sw := 0.42; var shh := 0.32
	var x0 := -(n - 1) * (sw + 0.08) / 2
	for k in n:
		var cx := x0 + k * (sw + 0.08)
		var cy := y + (0.06 if k % 2 == 0 else -0.05)
		var rz := M.rr(seed, k, 1, -2.5, 2.5)
		var sheet := Node3D.new(); sheet.position = Vector3(cx, cy, 0.006); sheet.rotation_degrees = Vector3(0, 0, rz); root.add_child(sheet)
		M.box(sheet, Vector3(sw, shh, 0.003), Vector3.ZERO, "papel")
		# planta de una casa: muros y tabiques
		M.box(sheet, Vector3(sw * 0.8, 0.008, 0.002), Vector3(0, shh * 0.32, 0.002), "tinta")
		M.box(sheet, Vector3(sw * 0.8, 0.008, 0.002), Vector3(0, -shh * 0.32, 0.002), "tinta")
		M.box(sheet, Vector3(0.008, shh * 0.64, 0.002), Vector3(-sw * 0.4, 0, 0.002), "tinta")
		M.box(sheet, Vector3(0.008, shh * 0.64, 0.002), Vector3(sw * 0.4, 0, 0.002), "tinta")
		var nt := 2 + int(M.rnd(seed, k, 2) * 3)
		for j in nt:
			var tx := M.rr(seed, k, 10 + j, -sw * 0.3, sw * 0.3)
			M.box(sheet, Vector3(0.006, shh * M.rr(seed, k, 20 + j, 0.2, 0.64), 0.002), Vector3(tx, 0, 0.002), "tinta")
		M.box(sheet, Vector3(sw * 0.5, 0.012, 0.002), Vector3(0, shh * 0.42, 0.002), "tinta")
		for c in 2:
			M.sphere(sheet, 0.008, Vector3((c - 0.5) * sw * 0.9, shh * 0.45, 0.004), "laton")
	root.set_meta("occ", [])
	return root

# ======================================================================================
# baldosas: piso de baldosas del vestíbulo (losa delgada encima del piso del cuarto). p: w, d.
static func build_baldosas(p: Dictionary) -> Node3D:
	var root := M.root("baldosas")
	var w := M.pf(p, "w", 2.4); var d := M.pf(p, "d", 3.0)
	_set_mat(M.box(root, Vector3(w, 0.012, d), Vector3(0, 0.006, 0), "piedra_portland"), mat_baldosas())
	root.set_meta("occ", [])
	return root

# ======================================================================================
# bandeja_tarjetas: bandeja de plata para tarjetas de visita sobre la mesa del vestíbulo, vacía.
static func build_bandeja_tarjetas(p: Dictionary) -> Node3D:
	var root := M.root("bandeja_tarjetas")
	M.cyl(root, 0.11, 0.1, 0.012, Vector3(0, 0.006, 0), "laton", Vector3.ZERO, 20)
	M.torus(root, 0.1, 0.112, Vector3(0, 0.014, 0), "laton")
	root.set_meta("occ", [])
	return root

# ======================================================================================
# paraguero: paragüero de hierro con dos paraguas y un bastón.
static func build_paraguero(p: Dictionary) -> Node3D:
	var root := M.root("paraguero")
	M.cyl(root, 0.13, 0.12, 0.55, Vector3(0, 0.275, 0), "hierro", Vector3.ZERO, 14)
	M.torus(root, 0.12, 0.14, Vector3(0, 0.55, 0), "hierro")
	M.cyl(root, 0.03, 0.06, 0.85, Vector3(-0.04, 0.6, 0.02), "tela_oscura", Vector3(4, 0, 5), 8)
	M.cyl(root, 0.03, 0.055, 0.82, Vector3(0.05, 0.58, -0.03), "tela_media", Vector3(-5, 0, -4), 8)
	M.rod_ab(root, 0.011, Vector3(0.0, 0.05, 0.05), Vector3(0.06, 1.0, 0.09), "madera_negra")
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.14, 0, -0.14), Vector3(0.14, 0.6, 0.14))])
	return root

# ======================================================================================
# tablero_alquiler: tablero de agente de fincas en lo alto de un poste, dentro del patio: «SE ALQUILA» grande y una
# línea chica. Tablero claro con marco oscuro y letras negras (legible bajo el grabado). Origen = pie del poste; frente +Z.
# p: text, sub, w, h, y (alto del borde inferior del tablero).
static func build_tablero_alquiler(p: Dictionary) -> Node3D:
	var root := M.root("tablero_alquiler")
	var w := M.pf(p, "w", 1.5); var h := M.pf(p, "h", 0.8); var y := M.pf(p, "y", 1.75)
	M.box(root, Vector3(0.08, y + h * 0.6, 0.08), Vector3(0, (y + h * 0.6) / 2, -0.06), "madera_media")
	M.box(root, Vector3(w + 0.08, h + 0.08, 0.04), Vector3(0, y + h / 2, 0.0), "madera_negra")
	_set_mat(M.box(root, Vector3(w, h, 0.02), Vector3(0, y + h / 2, 0.025), "papel"), mat_tablero())
	var txt := M.ps(p, "text", "SE ALQUILA")
	var sub := M.ps(p, "sub", "")
	var big := M.label3d(root, txt, Vector3(0, y + h * (0.62 if sub != "" else 0.5), 0.037), minf(h * 0.4 / 48.0, (w - 0.12) / (48.0 * 0.66 * maxf(txt.length(), 1))), 48, Color("1b1712"))
	big.name = "text"
	if sub != "":
		var sm := M.label3d(root, sub, Vector3(0, y + h * 0.22, 0.037), minf(h * 0.16 / 48.0, (w - 0.1) / (48.0 * 0.5 * maxf(sub.length(), 1))), 48, Color("1b1712"))
		sm.name = "sub"
	root.set_meta("occ", [M.aabb_mm(Vector3(-0.05, 0, -0.1), Vector3(0.05, y, -0.02)), M.aabb_mm(Vector3(-w / 2 - 0.04, y - 0.04, -0.02), Vector3(w / 2 + 0.04, y + h + 0.04, 0.04))])
	return root

# ======================================================================================
# cartel_papel: aviso de papel pegado (p.ej. en una vidriera): hoja clara con texto oscuro. Origen = centro.
static func build_cartel_papel(p: Dictionary) -> Node3D:
	var root := M.root("cartel_papel")
	var w := M.pf(p, "w", 0.5); var h := M.pf(p, "h", 0.36)
	M.box(root, Vector3(w, h, 0.003), Vector3.ZERO, "papel")
	var txt := M.text_of(p, "text_key")
	if txt != "":
		var lines := txt.split("\n").size()
		var lb := M.label3d(root, txt, Vector3(0, 0, 0.004), minf(h * 0.62 / (48.0 * lines), (w - 0.06) / (48.0 * 0.62 * maxf(_longest(txt), 1))), 48, Color("1b1712"))
		lb.name = "text"
	root.set_meta("occ", [])
	return root

static func _longest(s: String) -> int:
	var m := 0
	for l in s.split("\n"):
		m = maxi(m, l.length())
	return m
