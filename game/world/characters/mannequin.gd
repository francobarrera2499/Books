# world/characters/mannequin.gd — W1-3D. Contrato: docs/ARCHITECTURE.md §7.4 (GDD§4: un rasgo legible en silueta).
# Mannequin.make(char_id, trait, pose) -> Node3D. Pies en y=0, mira a +Z. Poses: de_pie, sentado, encorvado, apoyado.
# Meta del nodo devuelto: char_id, trait, pose, aabb (AABB local para colisión/ancla).
# Cada rasgo cambia la silueta entera (alto, ancho, abrigo, brazos, sombrero), no sólo un accesorio:
# el driver devtools/drivers/w13d_siluetas.gd exige IoU < 0,85 entre todo par.
extends RefCounted

const M = preload("res://world/materials.gd")

# rasgo → cuerpo. h alto; sh ancho de hombros; g radio del torso; coat: frock|long|jacket|dress|shirt|cape;
# arms r/l: side|hip|pocket|cane|forehead|carry|behind|front|mouth|under_arm|hold_front|crossed|belly; hat; pose por defecto.
const TRAITS := {
	"bombin_crespon": {"h": 1.78, "sh": 0.46, "g": 0.15, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "cane", "l": "side"}, "hat": "bowler_crepe", "mustache": "small", "pose": "de_pie"},
	"esfera_panuelo": {"h": 1.84, "sh": 0.5, "g": 0.17, "coat": "frock", "coat_mat": "tela_oscura", "sphere": 0.4, "arms": {"r": "belly", "l": "belly"}, "kerchief": true, "pose": "de_pie"},
	"fajo_bajo_brazo": {"h": 1.71, "sh": 0.34, "g": 0.11, "coat": "jacket", "coat_mat": "tela_media", "arms": {"r": "side", "l": "under_arm"}, "bundle": true, "pose": "de_pie", "lean": 4.0},
	"cofia": {"h": 1.6, "sh": 0.38, "g": 0.13, "coat": "dress", "coat_mat": "tela_oscura", "arms": {"r": "front", "l": "front"}, "hat": "cofia", "apron": true, "pose": "de_pie"},
	"gorra_larga": {"h": 1.86, "sh": 0.4, "g": 0.115, "coat": "jacket", "coat_mat": "tela_media", "arms": {"r": "pocket", "l": "pocket"}, "hat": "long_cap", "pose": "de_pie", "lean": -3.0},
	"chistera_bigote": {"h": 1.84, "sh": 0.5, "g": 0.16, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "behind", "l": "behind"}, "hat": "opera_hat", "mustache": "huge", "cheroot": true, "pose": "de_pie"},
	"cartera": {"h": 1.67, "sh": 0.4, "g": 0.135, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "carry", "l": "forehead"}, "case": true, "pose": "de_pie", "stoop": 10.0},
	"mangas_ligas": {"h": 1.74, "sh": 0.44, "g": 0.14, "coat": "shirt", "coat_mat": "vela", "arms": {"r": "hip", "l": "hip"}, "puffed": true, "pencil": true, "pose": "de_pie"},
	"bajo_agachado": {"h": 1.55, "sh": 0.4, "g": 0.13, "coat": "jacket", "coat_mat": "tela_media", "arms": {"r": "mouth", "l": "mouth"}, "hat": "flat_cap", "pose": "encorvado"},
	"joroba_libros": {"h": 1.66, "sh": 0.42, "g": 0.14, "coat": "long", "coat_mat": "tela_media", "arms": {"r": "hold_front", "l": "hold_front"}, "hump": true, "whiskers": true, "books": true, "pose": "encorvado"},
	"abrigo_cochero": {"h": 1.8, "sh": 0.48, "g": 0.15, "coat": "cape", "coat_mat": "tela_oscura", "arms": {"r": "hidden", "l": "hidden"}, "hat": "low_hat", "muffler": true, "pose": "de_pie"},
	"dos_bombines": {"pair": true, "h": 1.76, "sh": 0.44, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "crossed", "l": "crossed"}, "hat": "bowler", "pose": "apoyado"},
	"": {"h": 1.74, "sh": 0.42, "g": 0.14, "coat": "frock", "coat_mat": "tela_oscura", "arms": {"r": "side", "l": "side"}, "hat": "", "pose": "de_pie"},
}

# silueta por id de quien aparece en `silhouettes` de un lugar (§4.11)
const SIL_TRAITS := {"wiggins": "gorra_larga", "m3_hombres": "dos_bombines", "cochero": "abrigo_cochero", "parker": "bajo_agachado",
	"cotter": "fajo_bajo_brazo", "watson": "bombin_crespon", "mycroft": "esfera_panuelo", "hudson": "cofia", "mrs_hudson": "cofia",
	"harris": "chistera_bigote", "moran": "chistera_bigote", "pell": "cartera", "crane": "mangas_ligas", "librero": "joroba_libros",
	"chico_pell": "gorra_larga"}
const SIL_NOUNS := {"wiggins": "muchacho de gorra", "m3_hombres": "dos hombres apoyados", "cochero": "hombre de abrigo",
	"parker": "hombrecito agachado", "cotter": "escribiente", "chico_pell": "muchacho"}

static func traits() -> Array:
	var t: Array = TRAITS.keys()
	t.erase("")
	t.sort()
	return t

static func default_pose(trt: String) -> String:
	return str(TRAITS.get(trt, TRAITS[""]).get("pose", "de_pie"))

static func make(char_id: String, trt: String, pose: String = "") -> Node3D:
	var spec: Dictionary = TRAITS.get(trt, TRAITS[""])
	if pose == "": pose = str(spec.get("pose", "de_pie"))
	var root := Node3D.new()
	root.name = char_id if char_id != "" else "figure"
	var seed := char_id.hash() & 0xFFFF
	if bool(spec.get("pair", false)):
		var a := Node3D.new(); a.position = Vector3(-0.33, 0, 0); a.rotation_degrees = Vector3(0, 12, 0); root.add_child(a)
		_body(a, spec, pose, seed)
		var b := Node3D.new(); b.position = Vector3(0.36, 0, -0.08); b.rotation_degrees = Vector3(0, -10, 0); root.add_child(b)
		var s2: Dictionary = spec.duplicate(true)
		s2["h"] = float(spec["h"]) * 0.95
		s2["arms"] = {"r": "pocket", "l": "side"}
		_body(b, s2, pose, seed + 7)
	else:
		_body(root, spec, pose, seed)
	root.set_meta("char_id", char_id)
	root.set_meta("trait", trt)
	root.set_meta("pose", pose)
	root.set_meta("aabb", M.aabb_of(root))
	return root

# ---------------------------------------------------------------------------------------------
static func _cap(parent: Node3D, r: float, a: Vector3, b: Vector3, mat: String, sx: float = 1.0, sz: float = 1.0) -> MeshInstance3D:
	var mi := M.capsule_ab(parent, r, a, b, mat)
	if sx != 1.0 or sz != 1.0:
		mi.basis = Basis(mi.basis.x * sx, mi.basis.y, mi.basis.z * sz)
	return mi

static func _body(root: Node3D, s: Dictionary, pose: String, seed: int) -> void:
	var H := float(s.get("h", 1.74))
	var shw := float(s.get("sh", 0.42))
	var g := float(s.get("g", 0.14))
	var coat := str(s.get("coat", "frock"))
	var cm := str(s.get("coat_mat", "tela_oscura"))
	var tm := "tela_media" if cm != "tela_media" else "tela_oscura"
	var skin := "piel"
	var leg := H * 0.5
	var torso := H * 0.3
	var head_r := H * 0.064
	var stoop := float(s.get("stoop", 0.0))
	var lean := float(s.get("lean", 0.0))
	var hip := Vector3(0, leg, 0)
	var seated := pose == "sentado"
	match pose:
		"encorvado": stoop += 28.0; hip = Vector3(0, leg * 0.9, -0.04)
		"apoyado": lean -= 7.0; hip = Vector3(0, leg * 0.98, -0.05)
		"sentado": hip = Vector3(0, 0.47, -0.08)
	var hw := shw * 0.22
	# ---- piernas
	if coat != "dress":
		for side: float in [-1.0, 1.0]:
			var hp := hip + Vector3(side * hw, 0, 0)
			var knee: Vector3; var ankle: Vector3
			if seated:
				knee = hp + Vector3(side * 0.02, 0.0, 0.46)
				ankle = Vector3(side * hw * 1.1, 0.07, knee.z + 0.04)
			elif pose == "encorvado":
				knee = Vector3(side * hw * 1.05, leg * 0.5, 0.07)
				ankle = Vector3(side * hw * 1.1, 0.07, -0.02)
			elif pose == "apoyado" and side < 0:
				knee = Vector3(side * hw * 0.6, leg * 0.52, 0.12)
				ankle = Vector3(side * hw * 0.2 + 0.08, 0.2, -0.16)
			else:
				knee = Vector3(side * hw * 1.05, leg * 0.52, 0.01)
				ankle = Vector3(side * hw * 1.1, 0.07, 0.0)
			if (coat == "long" or coat == "cape") and not seated:
				# bajo un abrigo largo sólo asoman las botas y el tobillo
				var hem := Vector3(ankle.x, H * (0.2 if coat == "long" else 0.14), ankle.z + 0.01)
				_cap(root, H * 0.034, hem, ankle, tm)
			else:
				_cap(root, H * 0.044, hp, knee, tm)
				_cap(root, H * 0.037, knee, ankle, tm)
			M.box(root, Vector3(0.1, 0.07, 0.25), ankle + Vector3(0, -0.035, 0.06), "madera_negra")
	# ---- tronco (en marco inclinado)
	var up := Node3D.new(); up.name = "upper"; up.position = hip; root.add_child(up)
	up.rotation_degrees = Vector3(stoop + lean, 0, 0)
	var sh_y := torso
	var sph := float(s.get("sphere", 0.0))
	if sph > 0.0:
		M.sphere(up, sph, Vector3(0, torso * 0.45, 0.06), cm, Vector3(1.0, 1.05, 0.95), 20)
		_cap(up, g, Vector3(0, torso * 0.5, 0), Vector3(0, sh_y - g * 0.6, -0.02), cm, shw / (2.0 * g), 0.8)
	else:
		_cap(up, g, Vector3(0, g * 0.7, 0), Vector3(0, sh_y - g * 0.55, 0), cm, shw / (2.0 * g), 0.72)
	if bool(s.get("hump", false)):
		M.sphere(up, g * 1.25, Vector3(0, sh_y - 0.1, -g * 0.85), cm, Vector3(1.25, 1.0, 1.0), 14)
	if bool(s.get("apron", false)):
		M.box(up, Vector3(shw * 0.62, torso * 0.5, 0.02), Vector3(0, torso * 0.3, g * 0.76), "vela")
	if coat == "shirt":
		# chaleco oscuro sobre la camisa clara
		_cap(up, g * 1.02, Vector3(0, g * 0.8, 0.01), Vector3(0, sh_y - g * 1.2, 0.01), "tela_oscura", shw / (2.0 * g) * 0.82, 0.74)
	# ---- faldones / falda / abrigo (cuelgan desde la cintura)
	var waist := hip + Vector3(0, 0.06, 0)
	match coat:
		"frock":
			var bot := H * 0.27 if not seated else 0.42
			M.cyl(root, g * 1.05 * shw / 0.42, g * 1.35 * shw / 0.42, waist.y - bot, Vector3(0, (waist.y + bot) / 2, waist.z), cm, Vector3(-lean * 0.3, 0, 0), 14).scale = Vector3(1, 1, 0.8)
		"long":
			var bot2 := H * 0.09 if not seated else 0.4
			M.cyl(root, g * 1.1, g * 1.9, waist.y - bot2, Vector3(0, (waist.y + bot2) / 2, waist.z), cm, Vector3.ZERO, 14).scale = Vector3(1, 1, 0.85)
		"dress":
			M.cyl(root, g * 1.1, 0.4, waist.y, Vector3(0, waist.y / 2, waist.z), cm, Vector3.ZERO, 20)
			if bool(s.get("apron", false)):
				var r_top := g * 1.1
				var y0 := 0.12; var y1 := waist.y * 0.96
				var yc := (y0 + y1) * 0.5
				var rc := 0.4 + (r_top - 0.4) * (yc / waist.y)
				var th := atan((0.4 - r_top) / waist.y)
				M.box(root, Vector3(0.3, (y1 - y0) / cos(th), 0.012), Vector3(0, yc, waist.z + rc + 0.008), "vela", Vector3(-rad_to_deg(th), 0, 0))
		"cape":
			M.cyl(root, g * 1.15, 0.36, H * 0.72, Vector3(0, H * 0.36 + 0.04, 0), cm, Vector3.ZERO, 18).scale = Vector3(1, 1, 0.85)
			# esclavina sobre los hombros
			M.cyl(up, shw * 0.36, shw * 0.82, torso * 0.55, Vector3(0, sh_y - torso * 0.22, 0), cm, Vector3.ZERO, 18).scale = Vector3(1, 1, 0.82)
		"jacket":
			M.cyl(root, g * 1.0, g * 1.12, 0.16, Vector3(0, waist.y - 0.05, waist.z), cm, Vector3.ZERO, 12).scale = Vector3(shw / (2.0 * g) * 0.9, 1, 0.75)
		"shirt":
			pass
	# ---- cabeza
	var neck_top := Vector3(0, sh_y + H * 0.03, 0)
	_cap(up, H * 0.03, Vector3(0, sh_y - 0.05, 0), neck_top, skin)
	var hc := neck_top + Vector3(0, head_r * 0.92, 0.01)
	var head := Node3D.new(); head.name = "head"; head.position = hc; up.add_child(head)
	if pose == "encorvado": head.rotation_degrees = Vector3(-stoop * 0.6, 0, 0)
	M.sphere(head, head_r, Vector3.ZERO, skin, Vector3(0.92, 1.08, 0.98))
	M.box(head, Vector3(head_r * 0.25, head_r * 0.35, head_r * 0.3), Vector3(0, -head_r * 0.05, head_r * 0.95), skin)
	# ojos: dos puntos de tinta (W4: sin rasgos, una figura de frente se leía de espaldas en el grabado)
	for ex: float in [-1.0, 1.0]:
		M.sphere(head, head_r * 0.12, Vector3(ex * head_r * 0.33, head_r * 0.14, head_r * 0.9), "madera_negra", Vector3(1.0, 0.75, 0.55), 8)
	match str(s.get("mustache", "")):
		"small":
			M.capsule(head, head_r * 0.12, head_r * 0.7, Vector3(0, -head_r * 0.38, head_r * 0.9), "madera_media", Vector3(0, 0, 90))
		"huge":
			for side: float in [-1.0, 1.0]:
				_cap(head, head_r * 0.15, Vector3(side * head_r * 0.08, -head_r * 0.38, head_r * 0.95), Vector3(side * head_r * 1.35, -head_r * 0.3, head_r * 0.7), "madera_media")
	if bool(s.get("whiskers", false)):
		for side: float in [-1.0, 1.0]:
			M.sphere(head, head_r * 0.42, Vector3(side * head_r * 0.82, -head_r * 0.3, head_r * 0.15), "vela", Vector3(0.7, 1.3, 1.0))
		M.sphere(head, head_r * 0.6, Vector3(0, head_r * 0.6, -head_r * 0.2), "vela", Vector3(1.4, 0.6, 1.3))
	if bool(s.get("pencil", false)):
		M.cyl(head, 0.005, 0.005, 0.12, Vector3(head_r * 0.95, head_r * 0.15, 0), "madera_clara", Vector3(70, 0, 0), 6)
	if bool(s.get("cheroot", false)):
		M.cyl(head, 0.008, 0.008, 0.1, Vector3(head_r * 0.25, -head_r * 0.5, head_r * 1.25), "madera_oscura", Vector3(80, 20, 0), 6)
	if bool(s.get("muffler", false)):
		M.torus(up, H * 0.03, H * 0.06, Vector3(0, sh_y + 0.01, 0.0), "tela_media", Vector3.ZERO, Vector3(1, 1.6, 1))
	_hat(head, str(s.get("hat", "")), head_r)
	# ---- brazos
	var ua := H * 0.17
	var fa := H * 0.155
	var arm_r := H * 0.03
	var puffed := bool(s.get("puffed", false))
	var arms: Dictionary = s.get("arms", {"r": "side", "l": "side"})
	for side: float in [-1.0, 1.0]:
		var kind := str(arms.get("r" if side > 0 else "l", "side"))
		if kind == "hidden": continue
		var shp := Vector3(side * shw * 0.5, sh_y - 0.04, 0)
		var x := side
		var el: Vector3; var hd: Vector3
		match kind:
			"hip": el = shp + Vector3(x * 0.22, -ua * 0.72, -0.05); hd = Vector3(x * shw * 0.33, torso * 0.3, 0.04)
			"pocket": el = shp + Vector3(x * 0.07, -ua * 0.95, -0.03); hd = Vector3(x * shw * 0.38, -0.02, 0.07)
			"cane": el = shp + Vector3(x * 0.03, -ua * 0.97, 0.06); hd = shp + Vector3(x * 0.06, -ua - fa * 0.72, fa * 0.55)
			"forehead":
				# se seca la frente: mano en la frente y el codo doblado, adelante y afuera (IK de dos huesos con los largos
				# reales del brazo; antes el codo caía casi en la recta hombro-frente y el brazo se veía como un palo)
				hd = hc + Vector3(x * 0.05, head_r * 0.3, head_r * 1.0)
				el = _elbow(shp, hd, ua, fa, Vector3(x * 1.0, -0.35, 0.55))
			"carry": el = shp + Vector3(x * 0.05, -ua, 0.02); hd = shp + Vector3(x * 0.09, -ua - fa, 0.05)
			"behind": el = shp + Vector3(x * 0.07, -ua * 0.92, -0.13); hd = Vector3(x * 0.05, torso * 0.2, -g - 0.07)
			"front": el = shp + Vector3(x * 0.04, -ua * 0.95, 0.08); hd = Vector3(x * 0.04, torso * 0.22, g + 0.12)
			"mouth": el = shp + Vector3(x * 0.09, -ua * 0.55, 0.22); hd = hc + Vector3(x * 0.03, -head_r * 0.55, head_r * 1.1)
			"under_arm": el = shp + Vector3(x * 0.1, -ua * 0.92, -0.04); hd = shp + Vector3(x * 0.02, -ua * 0.62, 0.2)
			"hold_front": el = shp + Vector3(x * 0.06, -ua * 0.88, 0.14); hd = Vector3(x * 0.13, torso * 0.42, g + 0.24)
			"crossed": el = shp + Vector3(x * 0.06, -ua * 0.85, 0.13); hd = Vector3(-x * 0.1, torso * 0.62, g + 0.08)
			"belly": el = shp + Vector3(x * 0.16, -ua * 0.8, 0.08); hd = Vector3(x * 0.1, torso * 0.4, sph + 0.08)
			_: el = shp + Vector3(x * 0.04, -ua, 0.0); hd = shp + Vector3(x * 0.07, -ua - fa, 0.03)
		var sleeve := cm if coat != "cape" else cm
		if coat == "shirt": sleeve = "vela"
		_cap(up, arm_r * (1.9 if puffed else 1.0), shp, el, sleeve)
		_cap(up, arm_r * (1.6 if puffed else 0.92), el, hd, sleeve)
		if puffed:
			var band := M.cyl(up, arm_r * 2.0, arm_r * 2.0, 0.035, shp.lerp(el, 0.6), "tela_oscura", Vector3.ZERO, 12)
			_orient_y(band, el - shp)
		M.sphere(up, arm_r * 1.25, hd, skin, Vector3(0.9, 1.1, 0.8), 10)
		# accesorios en la mano
		if kind == "cane":
			var tip := Vector3(hd.x + x * 0.02, -hip.y + 0.0, hd.z + 0.18)
			M.rod_ab(up, 0.012, hd + Vector3(0, 0.03, 0), tip, "madera_negra")
			M.capsule_ab(up, 0.016, hd + Vector3(0, 0.03, 0), hd + Vector3(0, 0.05, -0.08), "madera_negra")
		elif kind == "carry" and bool(s.get("case", false)):
			M.box(up, Vector3(0.11, 0.3, 0.4), hd + Vector3(x * 0.03, -0.19, 0.0), "cuero")
			M.box(up, Vector3(0.02, 0.05, 0.12), hd + Vector3(x * 0.03, -0.02, 0.0), "cuero")
		elif kind == "under_arm" and bool(s.get("bundle", false)):
			M.box(up, Vector3(0.09, 0.26, 0.36), shp + Vector3(x * 0.03, -ua * 0.62, 0.06), "papel", Vector3(-12, 0, 0))
			M.box(up, Vector3(0.095, 0.02, 0.37), shp + Vector3(x * 0.03, -ua * 0.62, 0.06), "lienzo", Vector3(-12, 0, 0))
		elif kind == "mouth":
			pass
		if kind == "forehead":
			# pañuelo blanco chico en la mano
			M.box(up, Vector3(0.07, 0.055, 0.015), hd + Vector3(x * 0.01, -0.035, 0.035), "vela", Vector3(0, 0, x * 12.0))
	if bool(s.get("books", false)):
		var bc := Vector3(0, torso * 0.45, g + 0.25)
		for k in 4:
			M.box(up, Vector3(0.3 - k * 0.02, 0.05, 0.22 - k * 0.01), bc + Vector3((k % 2) * 0.02, k * 0.05, 0), ["cuero", "tela_media", "caoba", "papel_viejo"][k], Vector3(0, k * 7.0, 0))
	if bool(s.get("kerchief", false)):
		M.prism(up, Vector3(0.12, 0.12, 0.03), Vector3(-shw * 0.2, torso * 0.78, 0.16), "pintura_roja", Vector3(-15, 0, 180))
		M.prism(up, Vector3(0.2, 0.26, 0.03), Vector3(shw * 0.35, torso * 0.1, sph + 0.1), "pintura_roja", Vector3(0, 0, 180))

# Codo de un brazo de largos ua (hombro-codo) y fa (codo-mano) entre el hombro s y la mano h, del lado de hint.
static func _elbow(s: Vector3, h: Vector3, ua: float, fa: float, hint: Vector3) -> Vector3:
	var d := h - s
	var dl := d.length()
	if dl < 0.0001:
		return s + hint.normalized() * ua
	var u := d / dl
	dl = clampf(dl, absf(ua - fa) + 0.001, ua + fa - 0.001)
	var a := (ua * ua - fa * fa + dl * dl) / (2.0 * dl)
	var r := sqrt(maxf(0.0, ua * ua - a * a))
	var p := hint - u * hint.dot(u)
	if p.length() < 0.0001:
		p = Vector3(0, -1, 0) - u * (-u.y)
	return s + u * a + p.normalized() * r

static func _orient_y(mi: Node3D, dir: Vector3) -> void:
	var l := dir.length()
	if l < 0.0001: return
	var up := dir / l
	var ref := Vector3.FORWARD if absf(up.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	mi.basis = Basis(x, up, z)

static func _hat(head: Node3D, hat: String, r: float) -> void:
	var top := r * 0.78
	match hat:
		"bowler", "bowler_crepe":
			M.cyl(head, r * 1.08, r * 1.08, r * 0.5, Vector3(0, top + r * 0.12, 0), "fieltro", Vector3.ZERO, 20)
			M.hemi(head, r * 1.08, Vector3(0, top + r * 0.36, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.95, 1))
			M.torus(head, r * 1.0, r * 1.62, Vector3(0, top - 0.005, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.35, 1))
			if hat == "bowler_crepe":
				M.cyl(head, r * 1.11, r * 1.11, r * 0.36, Vector3(0, top + r * 0.16, 0), "crespon", Vector3.ZERO, 20)
				for sx2: float in [-1.0, 1.0]:
					M.box(head, Vector3(r * 0.16, r * 0.62, 0.006), Vector3(sx2 * r * 0.12, top + r * 0.02 - r * 0.28, -r * 1.12), "crespon", Vector3(12, 0, sx2 * 8))
		"opera_hat":
			M.cyl(head, r * 1.06, r * 0.98, r * 2.4, Vector3(0, top + r * 1.2, 0), "fieltro", Vector3.ZERO, 20)
			M.torus(head, r * 0.95, r * 1.6, Vector3(0, top, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.3, 1.05))
			M.cyl(head, r * 1.07, r * 1.07, r * 0.3, Vector3(0, top + r * 0.2, 0), "crespon", Vector3.ZERO, 20)
		"cofia":
			M.cyl(head, r * 0.95, r * 0.95, r * 0.18, Vector3(0, top + r * 0.05, -r * 0.1), "vela", Vector3(-20, 0, 0), 20)
			M.torus(head, r * 0.85, r * 1.25, Vector3(0, top - r * 0.05, -r * 0.08), "vela", Vector3(-20, 0, 0), Vector3(1, 0.5, 1))
			M.sphere(head, r * 0.5, Vector3(0, r * 0.1, -r * 1.05), "madera_media")
		"long_cap":
			M.hemi(head, r * 1.06, Vector3(0, top - r * 0.2, -r * 0.05), "tela_media", Vector3.ZERO, Vector3(1.05, 0.65, 1.15))
			M.box(head, Vector3(r * 1.4, r * 0.08, r * 1.9), Vector3(0, top - r * 0.15, r * 1.45), "tela_oscura", Vector3(-8, 0, 0))
		"flat_cap":
			M.hemi(head, r * 1.08, Vector3(0, top - r * 0.15, 0), "tela_media", Vector3.ZERO, Vector3(1.1, 0.45, 1.25))
			M.box(head, Vector3(r * 1.2, r * 0.06, r * 0.7), Vector3(0, top - r * 0.12, r * 1.05), "tela_media")
		"low_hat":
			# sombrero bajo de cochero (copa baja y redondeada, ala corta curvada)
			M.cyl(head, r * 0.98, r * 1.06, r * 0.7, Vector3(0, top + r * 0.25, 0), "fieltro", Vector3.ZERO, 20)
			M.hemi(head, r * 0.98, Vector3(0, top + r * 0.6, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.4, 1))
			M.torus(head, r * 1.0, r * 1.55, Vector3(0, top - r * 0.02, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.35, 1))
		"top":
			M.cyl(head, r * 1.04, r * 1.0, r * 1.9, Vector3(0, top + r * 0.95, 0), "fieltro", Vector3.ZERO, 20)
			M.torus(head, r * 0.95, r * 1.5, Vector3(0, top, 0), "fieltro", Vector3.ZERO, Vector3(1, 0.3, 1))
		"bonnet":
			M.hemi(head, r * 1.15, Vector3(0, top - r * 0.5, -r * 0.1), "tela_oscura", Vector3(-25, 0, 0), Vector3(1.05, 1.0, 1.2))
		_:
			M.hemi(head, r * 1.01, Vector3(0, r * 0.05, -r * 0.05), "madera_media", Vector3(-10, 0, 0), Vector3(1, 0.85, 1.05))
