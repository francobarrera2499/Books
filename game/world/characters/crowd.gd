# world/characters/crowd.gd — W1-3D. Multitud congelada / transeúntes genéricos (GDD§5 L7; noche del 5: abrigados).
# Crowd.make(p) -> Node3D. p: {n, seed, w, d, face:[x,z] (punto al que miran, opcional), wrapped (abrigados), kids}
# Determinista (Materials.rnd). Las figuras NO son personajes con nombre: no llevan rasgo de §7.4.
extends RefCounted

const M = preload("res://world/materials.gd")
const MQ = preload("res://world/characters/mannequin.gd")

const KINDS := [
	{"h": 1.76, "sh": 0.44, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "side", "l": "pocket"}, "hat": "top"},
	{"h": 1.72, "sh": 0.42, "g": 0.14, "coat": "frock", "coat_mat": "tela_media", "arms": {"r": "side", "l": "side"}, "hat": "bowler"},
	{"h": 1.62, "sh": 0.38, "g": 0.13, "coat": "dress", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "bonnet"},
	{"h": 1.68, "sh": 0.4, "g": 0.13, "coat": "jacket", "coat_mat": "tela_media", "arms": {"r": "pocket", "l": "pocket"}, "hat": "flat_cap"},
	{"h": 1.6, "sh": 0.38, "g": 0.13, "coat": "dress", "coat_mat": "tela_media", "arms": {"r": "side", "l": "front"}, "hat": "bonnet"},
	{"h": 1.78, "sh": 0.46, "g": 0.15, "coat": "long", "coat_mat": "tela_oscura", "arms": {"r": "behind", "l": "behind"}, "hat": "bowler"},
]

static func make(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "crowd"
	var n := clampi(M.pi_(p, "n", 12), 0, 200)
	var seed := M.pi_(p, "seed", 1894)
	var w := M.pf(p, "w", 6.0); var d := M.pf(p, "d", 3.0)
	var face = p.get("face", null)
	var wrapped := M.pb(p, "wrapped", false)
	var placed: Array = []
	for i in n:
		var pos := Vector3.ZERO
		for tries in 12:
			pos = Vector3((M.rnd(seed, i, tries * 2) - 0.5) * w, 0, (M.rnd(seed, i, tries * 2 + 1) - 0.5) * d)
			var okp := true
			for q in placed:
				if (q as Vector3).distance_to(pos) < 0.55: okp = false; break
			if okp: break
		placed.append(pos)
		var spec: Dictionary = (KINDS[int(M.rnd(seed, i, 40) * KINDS.size()) % KINDS.size()] as Dictionary).duplicate(true)
		spec["h"] = float(spec["h"]) * M.rr(seed, i, 41, 0.94, 1.05)
		if wrapped and spec["coat"] != "dress":
			spec["coat"] = "long"; spec["muffler"] = true
		var fig := Node3D.new(); fig.name = "f%d" % i
		MQ._body(fig, spec, "de_pie", seed + i)
		fig.position = pos
		var yaw := M.rr(seed, i, 42, -40, 40)
		if face is Array and face.size() >= 2:
			var tgt := Vector3(float(face[0]), 0, float(face[1]))
			var dir := tgt - pos
			yaw = rad_to_deg(atan2(dir.x, dir.z)) + M.rr(seed, i, 43, -12, 12)
		fig.rotation_degrees = Vector3(0, yaw, 0)
		root.add_child(fig)
	root.set_meta("occ", [])
	root.set_meta("aabb", M.aabb_of(root))
	return root
