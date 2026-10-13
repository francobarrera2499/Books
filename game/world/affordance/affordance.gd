# world/affordance/affordance.gd — afordancias del 3D (GDD_v2 §D.1, §D.3). Dueño: CÁMARA + AFORDANCIAS. Estática.
# Códigos en la RUGOSIDAD del material (canal A del buffer normal_roughness de Forward+, el que ya leen los looks):
#   0 escenario (1,00: todo material del mundo) · 1 examinable · 2 usable (permanente) · 3 bajo el mouse (temporal).
# Desvío del spec (§D.3 pedía 0,75/0,50/0,25 + LAMBERT sin especular en TODO material): para no tocar materials.gd ni la
# calibración de los looks, los códigos van pegados a 1,00 (ROUGH) y los materiales conservan su BRDF; el cambio de
# sombreado es ínfimo (rugosidad 0,88–0,96 con Burley y especular 0,25) y el buffer de 8 bits los separa por ≥5 pasos
# (r·127/255 → 127 · 122 · 117 · 112). El limitador de rugosidad de pantalla sólo sube valores < 0,18: no los toca.
# Cada dueño de código 1 o 2 lleva además una de IDS variantes (paso 2/255 dentro de su franja) para que «mirar alrededor»
# contornee también un objeto apoyado sobre otro examinable (el borde es donde cambia el valor).
# Decodificación (affordance.gdshader y cualquier look que quiera leerlos): Godot 4.7 guarda la rugosidad TAL CUAL en el
#   canal A (medido: 1,00 · 0,96 · 0,92 se leen así; la fórmula vieja r·127/255 con bit de dinámico daba todo «3»):
#   r = a (si a ≤ 0,5: a/(127/255); si 0,5 < a ≤ 0,6: (1 − a)/(127/255)); code = r > 0.98 ? 0 : r > 0.94 ? 1 : r > 0.90 ? 2 : 3.
# tag(diorama): reparte las GeometryInstance3D entre dueños («n:<nodo>», «c:<personaje>») y les pone código 1 (lo usable,
# 2, lo fija después la pantalla de juego: personajes con quien hablar, vínculos de map.json con su bandera).
# apply(diorama, usable, hover): rehace los códigos (WorldRoot lo llama al cambiar lo usable o el mouse).
# Reparto: silueta y personaje = todo su maniquí; nodo con prop = las mallas del prop cuyo centro cae en su ancla (+3 cm),
# el ancla más chica gana; si el prop es de un solo nodo y no es «arquitectura» (≤ 8× el volumen del ancla), todas.
# Nodos sin prop (sólo ancla: la sombra del librero) no tienen malla: etiqueta y cursor, sin contorno.
extends RefCounted

const ROUGH := [1.0, 0.9725, 0.9325, 0.88]  # primer valor de cada código; 1 y 2 tienen IDS variantes (8 bits: 248…242, 238…232)
const IDS := 4                               # variantes por dueño (paso 2/255): «mirar alrededor» separa objetos vecinos
const ID_STEP := 2.0 / 255.0
const GROW := 0.03
const ARCH_RATIO := 8.0

static var _coded := {}   # "<id material>:<code>" -> material duplicado

static func rough_for(code: int, vid: int) -> float:
	if code == 1 or code == 2:
		return float(ROUGH[code]) - ID_STEP * float(posmod(vid, IDS))
	return float(ROUGH[clampi(code, 0, 3)])

static func vid_of(owner: String) -> int:
	return posmod(owner.hash(), IDS)

static func coded_mat(orig: Material, code: int, vid := 0) -> Material:
	if code <= 0 or not (orig is BaseMaterial3D):
		return orig
	var bm := orig as BaseMaterial3D
	if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		return orig   # lo transparente no escribe el buffer normal_roughness
	var v := posmod(vid, IDS) if code == 1 or code == 2 else 0
	var k := "%d:%d:%d" % [orig.get_instance_id(), code, v]
	if _coded.has(k) and is_instance_valid(_coded[k]):
		return _coded[k]
	var d: BaseMaterial3D = bm.duplicate()
	d.roughness = rough_for(code, v)
	d.roughness_texture = null
	d.resource_name = "%s#aff%d" % [bm.resource_name, code]
	_coded[k] = d
	return d

static func code_of_rough(r: float) -> int:
	if r > 0.98: return 0
	if r > 0.94: return 1
	if r > 0.90: return 2
	return 3

static func _geoms(n: Node, out: Array) -> void:
	if n is GeometryInstance3D and (n is MeshInstance3D or n is MultiMeshInstance3D):
		out.append(n)
	for c in n.get_children():
		if c is CollisionObject3D and c != n and c.has_meta("node_id"):
			continue   # otro nodo (silueta) colgado adentro: es suyo
		_geoms(c, out)

static func _aabb_world(gi: GeometryInstance3D, root: Node3D) -> AABB:
	var xf := _rel(root, gi)
	return xf * gi.get_aabb()

static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

# Reparte y pone los códigos iniciales. Guarda meta "aff" = {dueño: [GeometryInstance3D]} y "aff_usable_default".
static func tag(root: Node3D) -> void:
	var owners := {}
	var claimed := {}
	var nodes: Dictionary = root.get_meta("nodes_index", {})
	var chars: Dictionary = root.get_meta("chars_index", {})
	var props := root.get_node_or_null("Props")
	# siluetas: el maniquí colgado del cuerpo del nodo
	for nid in nodes:
		var b: Node3D = nodes[nid]
		if b.has_meta("silhouette"):
			var lst: Array = []
			_geoms(b, lst)
			owners["n:" + str(nid)] = lst
			for g in lst: claimed[g] = true
	# nodos con prop: por prop, sus nodos y sus mallas
	var by_prop := {}
	for nid in nodes:
		var b2: Node3D = nodes[nid]
		if b2.has_meta("silhouette"): continue
		var pid := str(b2.get_meta("prop", ""))
		if pid == "": continue
		if not by_prop.has(pid): by_prop[pid] = []
		by_prop[pid].append(str(nid))
	for pid in by_prop:
		var src: Node3D = null
		if props != null:
			src = props.get_node_or_null(NodePath(str(pid).replace(".", "_")))
		if src == null and chars.has(pid):
			src = chars[pid]
		if src == null: continue
		var geoms: Array = []
		_geoms(src, geoms)
		if geoms.is_empty(): continue
		var nids: Array = by_prop[pid]
		var boxes := {}
		for nid in nids:
			var b3: Node3D = nodes[nid]
			var s: Vector3 = b3.get_meta("size", Vector3(0.2, 0.2, 0.2))
			var c := _rel(root, b3).origin
			boxes[nid] = AABB(c - s * 0.5, s).grow(GROW)
		var whole := false
		if nids.size() == 1 and not chars.has(pid):
			var tot := AABB()
			var first := true
			for g in geoms:
				var a := _aabb_world(g, root)
				if first: tot = a; first = false
				else: tot = tot.merge(a)
			var bx: AABB = boxes[nids[0]]
			whole = tot.get_volume() <= maxf(bx.get_volume(), 1e-6) * ARCH_RATIO
		for g in geoms:
			if claimed.has(g): continue
			var best := ""
			var bv := INF
			if whole:
				best = str(nids[0])
			else:
				var cen := _aabb_world(g, root).get_center()
				for nid in nids:
					var bb: AABB = boxes[nid]
					if bb.has_point(cen) and bb.get_volume() < bv:
						best = str(nid); bv = bb.get_volume()
			if best == "": continue
			var key := "n:" + best
			if not owners.has(key): owners[key] = []
			owners[key].append(g)
			claimed[g] = true
		# segunda pasada (props compartidos con mallas grandes: las mesas de la Sala, ventanas, el precipicio): un nodo que
		# quedó sin malla toma las libres que tocan su ancla y no son mucho más grandes; si no, la libre más cercana
		if chars.has(pid): continue
		for nid in nids:
			var key2 := "n:" + str(nid)
			if owners.has(key2) and not (owners[key2] as Array).is_empty(): continue
			var bb2: AABB = boxes[nid]
			var got: Array = []
			var near_g = null
			var near_d := INF
			for g in geoms:
				if claimed.has(g): continue
				var a := _aabb_world(g, root)
				if a.intersects(bb2) and a.get_volume() <= maxf(bb2.get_volume(), 1e-6) * ARCH_RATIO:
					got.append(g)
				var dd := a.get_center().distance_to(bb2.get_center())
				if dd < near_d and bb2.grow(0.5).has_point(a.get_center()):
					near_d = dd; near_g = g
			if got.is_empty() and near_g != null: got = [near_g]
			if got.is_empty(): continue
			owners[key2] = got
			for g in got: claimed[g] = true
	# personajes: el resto de su maniquí
	for cid in chars:
		var lst2: Array = []
		var all: Array = []
		_geoms(chars[cid], all)
		for g in all:
			if not claimed.has(g):
				lst2.append(g)
				claimed[g] = true
		owners["c:" + str(cid)] = lst2
	for k in owners:
		for g in owners[k]:
			(g as GeometryInstance3D).set_meta("aff_orig", (g as GeometryInstance3D).material_override)
	root.set_meta("aff", owners)
	# un nodo que ES un personaje (Harris y Pell en la lámina del prólogo: el nodo lleva el examen y el maniquí es del
	# personaje) se realza bajo el mouse con las mallas del personaje
	var alias := {}
	for nid in nodes:
		var pid2 := str((nodes[nid] as Node3D).get_meta("prop", ""))
		if pid2 != "" and chars.has(pid2) and (not owners.has("n:" + str(nid)) or (owners["n:" + str(nid)] as Array).is_empty()):
			alias["n:" + str(nid)] = "c:" + pid2
	root.set_meta("aff_alias", alias)
	# nada usable por defecto: lo decide la pantalla de juego con las banderas y la fase (WorldRoot.set_usable), así
	# nunca se marca algo que todavía no se puede usar (ni siquiera un cuadro, al armar el diorama)
	var usable := {}
	root.set_meta("aff_usable", usable)
	root.set_meta("aff_hover", "")
	apply(root, usable, "")

# Rehace los códigos: hover (3) pisa usable (2) pisa examinable (1).
static func apply(root: Node3D, usable: Dictionary, hover: String) -> void:
	if root == null or not root.has_meta("aff"): return
	hover = str((root.get_meta("aff_alias", {}) as Dictionary).get(hover, hover))
	root.set_meta("aff_usable", usable)
	root.set_meta("aff_hover", hover)
	var owners: Dictionary = root.get_meta("aff")
	for k in owners:
		var code := 3 if k == hover else (2 if usable.has(k) else 1)
		var vid := vid_of(str(k))
		for g in owners[k]:
			if not is_instance_valid(g): continue
			var gi := g as GeometryInstance3D
			var orig = gi.get_meta("aff_orig", null)
			if orig is Material:
				gi.material_override = coded_mat(orig, code, vid)

# Sólo el dueño bajo el mouse (barato: dos dueños por cambio).
static func set_hover(root: Node3D, hover: String) -> void:
	if root == null or not root.has_meta("aff"): return
	hover = str((root.get_meta("aff_alias", {}) as Dictionary).get(hover, hover))
	var prev := str(root.get_meta("aff_hover", ""))
	if prev == hover: return
	root.set_meta("aff_hover", hover)
	var usable: Dictionary = root.get_meta("aff_usable", {})
	var owners: Dictionary = root.get_meta("aff")
	for k in [prev, hover]:
		if k == "" or not owners.has(k): continue
		var code := 3 if k == hover else (2 if usable.has(k) else 1)
		var vid := vid_of(str(k))
		for g in owners[k]:
			if not is_instance_valid(g): continue
			var gi := g as GeometryInstance3D
			var orig = gi.get_meta("aff_orig", null)
			if orig is Material:
				gi.material_override = coded_mat(orig, code, vid)

# Código actual de una GeometryInstance3D (tests).
static func code_of(gi: GeometryInstance3D) -> int:
	var m = gi.material_override
	if m is BaseMaterial3D:
		return code_of_rough((m as BaseMaterial3D).roughness)
	return 0

static func owners(root: Node3D) -> Dictionary:
	return root.get_meta("aff", {}) if root != null else {}

static func key_of(kind: String, id: String) -> String:
	if kind == "node": return "n:" + id
	if kind == "char": return "c:" + id
	return ""
