# world/rect_clip.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.6 (recorte por rectángulo en 3D) y §5.1.
# RectClip.clip(cam, rect, diorama, exclude) -> {hits:[{node,cover,tight}], touched:[node], area_frac, occluded:[node]}
#  - A = rectángulo de pantalla de las 8 esquinas del anchor (se descartan las que quedan detrás de la cámara);
#  - cover = área(A ∩ R) / área(A);  tight = área(R) ≤ 3 × área(A ∩ viewport);
#  - oclusión: hasta 5 puntos del anchor (centro + centros de las caras hacia la cámara + puntos de la cara principal);
#    rayo desde la cámara contra GEOMETRÍA (oclusores capa 1 y personajes capa 4; no contra otras anclas), excluyendo
#    los oclusores del propio prop del nodo; ocluido si en los 5 hay geometría antes de entrar al anchor.
#  - hits = nodos NO ocluidos con cover > 0, ordenados por cover (desc; empate por id). `touched` = los mismos ids
#    (todo lo visible que el rectángulo tocó, relevante o no). Los ocluidos no se informan como tocados (no se ven);
#    van aparte en `occluded` (sólo diagnóstico/tests). El sim aplica los topes (≤2 hits con cover ≥ 0,5, tight).
#  - nodos cuyo cuerpo está en `exclude` (WorldRoot: montados en un muro cortado, invisibles) no se consideran.
#  - visible_points(): cuántos de los puntos de muestra se ven (T29 exige mayoría para «sin tapar»).
# Requiere ≥1 physics_frame tras construir el diorama. Headless: fijar root.size = 1600×900 antes de proyectar.
extends RefCounted

const LAYER_OCC := 1
const LAYER_CHAR := 4

static func clip(cam: Camera3D, rect: Rect2, diorama: Node3D, exclude: Array = []) -> Dictionary:
	var out := {"hits": [], "touched": [], "area_frac": 0.0, "occluded": []}
	if cam == null or diorama == null or not cam.is_inside_tree(): return out
	var vp := cam.get_viewport().get_visible_rect()
	var r := rect.abs()
	var r_vp := r.intersection(vp)
	out["area_frac"] = (r_vp.get_area() / vp.get_area()) if vp.get_area() > 0 else 0.0
	var idx: Dictionary = diorama.get_meta("nodes_index", {})
	var ids: Array = idx.keys()
	ids.sort()
	var hits: Array = []
	for nid in ids:
		var body: Node3D = idx[nid]
		if body == null or not is_instance_valid(body) or not body.is_inside_tree(): continue
		# nodos ocultos por el corte de muros (WorldRoot.excluded_rids): no se ven, no se tocan
		if body is CollisionObject3D and exclude.has((body as CollisionObject3D).get_rid()): continue
		var a := screen_rect(cam, body)
		if a.get_area() <= 0.0: continue
		var inter := a.intersection(r)
		if inter.get_area() <= 0.0: continue
		if is_occluded(cam, body, diorama, exclude):
			out["occluded"].append(nid)
			continue
		var a_vp := a.intersection(vp)
		var cover := inter.get_area() / a.get_area()
		var tight := r.get_area() <= 3.0 * a_vp.get_area()
		hits.append({"node": str(nid), "cover": cover, "tight": tight})
		out["touched"].append(str(nid))
	hits.sort_custom(func(x, y):
		if absf(float(x["cover"]) - float(y["cover"])) > 0.000001: return float(x["cover"]) > float(y["cover"])
		return str(x["node"]) < str(y["node"]))
	out["hits"] = hits
	return out

static func _corners(body: Node3D) -> Array:
	var s: Vector3 = body.get_meta("size", Vector3(0.2, 0.2, 0.2))
	var h := s * 0.5
	var xf := body.global_transform
	var out: Array = []
	for i in 8:
		out.append(xf * Vector3(h.x * (1 if i & 1 else -1), h.y * (1 if i & 2 else -1), h.z * (1 if i & 4 else -1)))
	return out

# rectángulo de pantalla del anchor (Rect2 vacío si queda entero detrás de la cámara)
static func screen_rect(cam: Camera3D, body: Node3D) -> Rect2:
	var pts: Array = []
	for c in _corners(body):
		if cam.is_position_behind(c): continue
		pts.append(cam.unproject_position(c))
	if pts.is_empty(): return Rect2()
	var lo: Vector2 = pts[0]; var hi: Vector2 = pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y)); hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)

static func own_bodies(body: Node3D, diorama: Node3D) -> Array:
	var out: Array = []
	var p := str(body.get_meta("prop", ""))
	if p == "": return out
	var pb: Dictionary = diorama.get_meta("prop_bodies", {})
	for b in pb.get(p, []):
		if is_instance_valid(b): out.append((b as CollisionObject3D).get_rid())
	var ci: Dictionary = diorama.get_meta("chars_index", {})
	if ci.has(p) and is_instance_valid(ci[p]): out.append((ci[p] as CollisionObject3D).get_rid())
	return out

static func sample_points(cam_local: Vector3, half: Vector3) -> Array:
	var pts: Array = [Vector3.ZERO]
	var faces: Array = []
	for i in 3:
		if absf(cam_local[i]) > half[i]:
			var p := Vector3.ZERO
			p[i] = signf(cam_local[i]) * half[i] * 0.98
			faces.append({"p": p, "w": (absf(cam_local[i]) - half[i]) / maxf(half[i], 0.001), "axis": i})
	faces.sort_custom(func(a, b): return a["w"] > b["w"])
	for f in faces: pts.append(f["p"])
	if not faces.is_empty():
		var f0: Dictionary = faces[0]
		var ax: int = f0["axis"]
		var o1 := (ax + 1) % 3
		var o2 := (ax + 2) % 3
		var extra: Array = []
		for sgn: float in [1.0, -1.0]:
			var q: Vector3 = f0["p"]
			q[o1] = sgn * half[o1] * 0.5
			extra.append(q)
			var q2: Vector3 = f0["p"]
			q2[o2] = sgn * half[o2] * 0.5
			extra.append(q2)
		for q in extra:
			if pts.size() >= 5: break
			pts.append(q)
	return pts

static func is_occluded(cam: Camera3D, body: Node3D, diorama: Node3D, exclude: Array = []) -> bool:
	return visible_points(cam, body, diorama, exclude, true).x == 0

# Vector2i(puntos de muestra sin tapar, puntos probados). first_only: corta en el primero visible (para is_occluded).
# Cámara dentro del ancla → todo visible. Sirve también para exigir «sin tapar» (T29: Wiggins) con más rigor que «no ocluido».
static func visible_points(cam: Camera3D, body: Node3D, diorama: Node3D, exclude: Array = [], first_only := false) -> Vector2i:
	var s: Vector3 = body.get_meta("size", Vector3(0.2, 0.2, 0.2))
	var half := s * 0.5
	var xf := body.global_transform
	var inv := xf.affine_inverse()
	var cam_pos := cam.global_position
	var cl := inv * cam_pos
	var pts := sample_points(cl, half)
	if absf(cl.x) <= half.x and absf(cl.y) <= half.y and absf(cl.z) <= half.z: return Vector2i(pts.size(), pts.size())
	var ex: Array[RID] = []
	for r in exclude: ex.append(r)
	for r in own_bodies(body, diorama): ex.append(r)
	if body is CollisionObject3D: ex.append((body as CollisionObject3D).get_rid())
	var space := cam.get_world_3d().direct_space_state
	var vis := 0
	for pl: Vector3 in pts:
		var pw: Vector3 = xf * pl
		var dl := (pl - cl)
		var t_in := ray_box_entry(cl, dl.normalized(), half)
		if t_in < 0.0: t_in = dl.length()
		# distancia en coords globales (sin escala en los cuerpos: igual a la local)
		var q := PhysicsRayQueryParameters3D.create(cam_pos, pw, LAYER_OCC | LAYER_CHAR, ex)
		q.hit_from_inside = false
		var h := space.intersect_ray(q)
		if h.is_empty() or cam_pos.distance_to(h["position"]) >= t_in - 0.01:
			vis += 1
			if first_only: return Vector2i(vis, pts.size())
	return Vector2i(vis, pts.size())

# distancia de entrada de un rayo (origen o, dirección unitaria d) a una caja centrada [-half, half]; -1 si no entra
static func ray_box_entry(o: Vector3, d: Vector3, half: Vector3) -> float:
	var tmin := -INF
	var tmax := INF
	for i in 3:
		if absf(d[i]) < 1e-9:
			if o[i] < -half[i] or o[i] > half[i]: return -1.0
		else:
			var t1 := (-half[i] - o[i]) / d[i]
			var t2 := (half[i] - o[i]) / d[i]
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0): return -1.0
	return maxf(tmin, 0.0)
