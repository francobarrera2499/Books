# world/picker.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.6 (clic).
# Clic: project_ray_origin/normal → intersect_ray (máscara 1|2|4) → primer impacto; nodo → node, personaje → char.
# Reglas de desempate (para que un ancla metida dentro de su propio prop o personaje se pueda clicar):
#  - si el primer impacto es un oclusor del prop P y detrás (≤ 1,5 m) hay un nodo con prop == P → ese nodo;
#  - si es el cuerpo de un personaje C y detrás (≤ 0,6 m) hay un nodo con prop == C → ese nodo;
#  - entre nodos anidados casi a la misma profundidad (≤ 0,3 m) gana el de menor volumen.
extends RefCounted

const LAYER_OCC := 1
const LAYER_NODE := 2
const LAYER_CHAR := 4
const MASK_ALL := 7

# todos los impactos a lo largo del segmento, en orden (re-lanza excluyendo cada impacto)
static func ray_all(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int, exclude: Array, max_hits: int = 12) -> Array:
	var out: Array = []
	var ex: Array[RID] = []
	for r in exclude: ex.append(r)
	for i in max_hits:
		var q := PhysicsRayQueryParameters3D.create(from, to, mask, ex)
		q.collide_with_areas = false
		q.hit_from_inside = false
		var h := space.intersect_ray(q)
		if h.is_empty(): break
		h["dist"] = from.distance_to(h["position"])
		out.append(h)
		ex.append(h["rid"])
	return out

static func pick(cam: Camera3D, screen_pos: Vector2, exclude: Array = []) -> Dictionary:
	var none := {"kind": "none", "id": ""}
	if cam == null or not cam.is_inside_tree(): return none
	var space := cam.get_world_3d().direct_space_state
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hits := ray_all(space, from, from + dir * 200.0, MASK_ALL, exclude, 12)
	if hits.is_empty(): return none
	var first: Dictionary = hits[0]
	var col: Object = first["collider"]
	if col.has_meta("node_id"):
		var best: Object = col
		var bv := _vol(col)
		for h in hits.slice(1):
			if float(h["dist"]) - float(first["dist"]) > 0.3: break
			var c2: Object = h["collider"]
			if c2.has_meta("node_id") and _vol(c2) < bv:
				best = c2; bv = _vol(c2)
			elif not c2.has_meta("node_id"):
				break
		return {"kind": "node", "id": str(best.get_meta("node_id")), "body": best}
	if col.has_meta("char_id"):
		var cid := str(col.get_meta("char_id"))
		for h in hits.slice(1):
			if float(h["dist"]) - float(first["dist"]) > 0.6: break
			var c3: Object = h["collider"]
			if c3.has_meta("node_id") and str(c3.get_meta("prop", "")) == cid:
				return {"kind": "node", "id": str(c3.get_meta("node_id")), "body": c3}
		return {"kind": "char", "id": cid, "body": col}
	if col.has_meta("prop_id"):
		var pid := str(col.get_meta("prop_id"))
		for h in hits.slice(1):
			if float(h["dist"]) - float(first["dist"]) > 1.5: break
			var c4: Object = h["collider"]
			if c4.has_meta("node_id") and str(c4.get_meta("prop", "")) == pid:
				return {"kind": "node", "id": str(c4.get_meta("node_id")), "body": c4}
			if c4.has_meta("prop_id") and str(c4.get_meta("prop_id")) != pid:
				break
	return none

static func pick_character(cam: Camera3D, screen_pos: Vector2, exclude: Array = []) -> String:
	var r := pick(cam, screen_pos, exclude)
	if r["kind"] == "char": return str(r["id"])
	# soltar sobre una parte del personaje que es un nodo (manos, sombra) también cuenta como el personaje
	if r["kind"] == "node" and r.has("body"):
		var b: Object = r["body"]
		var p := str(b.get_meta("prop", ""))
		if p != "" and b.get_parent() != null:
			var root: Node = b.get_parent().get_parent()
			if root != null and root.has_meta("chars_index") and (root.get_meta("chars_index") as Dictionary).has(p):
				return p
	return ""

static func _vol(o: Object) -> float:
	var s: Vector3 = o.get_meta("size", Vector3.ONE)
	return s.x * s.y * s.z
