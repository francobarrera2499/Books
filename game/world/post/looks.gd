# Registro de LOOKS de post-proceso intercambiables (estilo de imagen del 3D). Contrato: docs/ARCHITECTURE.md §7.8.
# Biblioteca estática (sin class_name): const Looks = preload("res://world/post/looks.gd")
#
# Un look = world/post/looks/<id>.gdshader + world/post/looks/<id>.json, descubiertos solos (basta con agregar el par).
# El shader sigue la plantilla del quad de pantalla de §7.8 (lo dibuja world/post/engraving_post.gd, que cambia de shader
# según el look) y DEBE declarar los uniforms `paper`, `ink` y `grain` (alto contraste y estilos de paleta); conviene
# además `debug_view` (3 = color 3D crudo, 4 = profundidad codificada: medidas de siluetas de los drivers) y, si dibuja
# una trama de pantalla, `anchor_rad` (giro acumulado de la cámara: trama anclada, estable al orbitar).
# JSON del look:
#   {"name": "rótulo en Opciones", "desc": "…", "order": n (orden en Opciones; menor primero),
#    "base": "lighting"            -> los parámetros son Lighting.look(preset, slot) tal cual (el look 'grabado': su
#                                     calibración vive en world/lighting.gd PRESETS.*.post / paper, probada por T27);
#    sin base: "ink": "#rrggbb", "paper": {"manana"|"tarde"|"noche": "#rrggbb"} (papel por franja; falta = Lighting.PAPER),
#              "defaults": {uniform: valor} (todo preset), "presets": {"<preset de Lighting>"|"*": {uniform: valor,
#              "paper": {"tint": "#rrggbb", "mix": 0..1}}} (un preset sin "paper" hereda el tinte del de Lighting: Park
#              Lane dorado y la noche fría del 5 se leen en todos los looks), "high_contrast": {"paper", "ink", "grain"}}
#   Los valores JSON se convierten al tipo del uniform (color "#hex" o [r,g,b(,a)], vec2/3/4 como listas, int, bool).
#   La luz 3D (direccionales, ambiente, lámparas, sombra de Crane) es de Lighting y la comparten todos los looks.
#
#   Looks.ids() -> Array                     ids por "order" y nombre ('aguada' = DEFAULT, primero; 'grabado' alternativa)
#   Looks.has(id) · Looks.info(id) -> Dictionary (el JSON + "id", "shader") · Looks.shader_path(id) · Looks.label(id)
#   Looks.is_base(id) -> bool                el look toma Lighting.look tal cual
#   Looks.params(id, preset, slot) -> Dictionary  {look, preset, slot, paper, ink, <uniforms>} -> EngravingPost.set_look
#   Looks.uniforms(id) -> Dictionary         nombre -> tipo (Variant.Type) de los uniforms ajustables (sin texturas)
#   Selección (estado de proceso): Looks.current() = override de sesión (--look=<id>, drivers) > elección del jugador
#   (Opciones, persistida en user://opciones.cfg; "" = el default) > DEFAULT. set_override(id) · set_choice(id) ·
#   choice() · `serial` cambia con cada selección: los quads vivos (EngravingPost) cambian de shader solos.
#   Looks.rescan(dir := DIR) vuelve a leer el directorio (tests: res://tests/fixtures/looks; volver con rescan()).
extends RefCounted

const Lighting = preload("res://world/lighting.gd")

const DIR := "res://world/post/looks"
const DEFAULT := "aguada"   # elegido por el usuario (iteración de feedback); 'grabado' queda como alternativa en Opciones
# uniforms que el quad maneja aparte (no son parámetros del look)
const RESERVED := ["paper", "ink", "anchor_rad", "debug_view"]

static var serial := 0
static var dir := DIR
static var _override := ""
static var _choice := ""
static var _cache := {}        # id -> info
static var _ids: Array = []
static var _loaded := false
static var _types := {}        # id -> {uniform: type}

static func rescan(p_dir := DIR) -> void:
	dir = p_dir
	_cache.clear()
	_ids.clear()
	_types.clear()
	_loaded = false
	_load()

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var seen := {}
	for f0 in DirAccess.get_files_at(dir):
		var f := String(f0).trim_suffix(".remap")
		if not f.ends_with(".json"):
			continue
		var id := f.get_basename()
		if seen.has(id):
			continue
		seen[id] = true
		var shp := dir.path_join(id + ".gdshader")
		if not ResourceLoader.exists(shp):
			push_warning("Looks: %s.json sin %s" % [id, shp])
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
		if not (d is Dictionary):
			push_warning("Looks: %s.json no es un objeto JSON" % id)
			continue
		var inf: Dictionary = d
		inf["id"] = id
		inf["shader"] = shp
		_cache[id] = inf
	_ids = _cache.keys()
	_ids.sort_custom(func(a, b):
		var oa := float(_cache[a].get("order", 100))
		var ob := float(_cache[b].get("order", 100))
		return oa < ob if oa != ob else String(a) < String(b))

static func ids() -> Array:
	_load()
	return _ids.duplicate()

static func has(id: String) -> bool:
	_load()
	return _cache.has(id)

static func info(id: String) -> Dictionary:
	_load()
	return _cache.get(id, {})

static func shader_path(id: String) -> String:
	return str(info(id).get("shader", DIR.path_join(DEFAULT + ".gdshader")))

static func label(id: String) -> String:
	return str(info(id).get("name", id))

static func is_base(id: String) -> bool:
	return str(info(id).get("base", "")) == "lighting"

# ---------------------------------------------------------------------------------------------------------------------
# selección
static func current() -> String:
	_load()
	if _override != "" and _cache.has(_override):
		return _override
	if _choice != "" and _cache.has(_choice):
		return _choice
	if _cache.has(DEFAULT) or _ids.is_empty():
		return DEFAULT
	return str(_ids[0])

# Sesión (--look=<id>, drivers de capturas): gana sobre la elección del jugador y no se guarda. "" la quita.
static func set_override(id: String) -> bool:
	if id != "" and not has(id):
		push_warning("Looks: look desconocido '%s' (hay: %s)" % [id, ", ".join(ids())])
		return false
	_override = id
	serial += 1
	return true

# Elección del jugador (Opciones; se persiste). "" = seguir el default. Elegir en Opciones quita el override de sesión.
static func set_choice(id: String) -> void:
	if id != "" and not has(id):
		id = ""
	_choice = id
	_override = ""
	serial += 1

static func choice() -> String:
	return _choice

# ---------------------------------------------------------------------------------------------------------------------
# parámetros
static func params(id: String, preset: String, slot: String) -> Dictionary:
	var inf := info(id)
	if inf.is_empty():
		id = DEFAULT
		inf = info(id)
	var lk: Dictionary
	if inf.is_empty() or str(inf.get("base", "")) == "lighting":
		lk = Lighting.look(preset, slot)
	else:
		var types := uniforms(id)
		var pres: Dictionary = inf.get("presets", {}) if inf.get("presets", {}) is Dictionary else {}
		var pp: Dictionary = pres.get(preset, {}) if pres.get(preset, {}) is Dictionary else {}
		var star: Dictionary = pres.get("*", {}) if pres.get("*", {}) is Dictionary else {}
		var tone := Lighting.tone_for(slot)
		var papers: Dictionary = inf.get("paper", {}) if inf.get("paper", {}) is Dictionary else {}
		var paper: Color = conv(papers[tone], TYPE_COLOR) if papers.has(tone) else Lighting.PAPER[tone]
		var tint = pp.get("paper", star.get("paper", null))
		if tint == null and Lighting.has(preset):
			tint = Lighting.PRESETS[preset].get("paper", null)
		if tint is Dictionary and tint.has("tint"):
			paper = paper.lerp(conv(tint.tint, TYPE_COLOR), float(tint.get("mix", 0.0)))
		lk = {"preset": preset, "slot": slot, "paper": paper,
			"ink": conv(inf["ink"], TYPE_COLOR) if inf.has("ink") else Lighting.INK}
		for src in [inf.get("defaults", {}), star, pp]:
			if not (src is Dictionary):
				continue
			for k in src:
				if k == "paper":
					continue
				lk[k] = conv(src[k], int(types.get(k, -1)))
	lk["look"] = id
	return lk

# Defaults del look (sin preset): lo que el quad fija al cambiar de shader. Un uniform sin default -> el del shader.
static func defaults(id: String) -> Dictionary:
	var out := {}
	var d = info(id).get("defaults", {})
	if d is Dictionary:
		var types := uniforms(id)
		for k in d:
			out[k] = conv(d[k], int(types.get(k, -1)))
	return out

static func high_contrast(id: String) -> Dictionary:
	var hc = info(id).get("high_contrast", {})
	var out := {"paper": Color.WHITE, "ink": Color.BLACK, "grain": 0.0}
	if hc is Dictionary:
		for k in hc:
			out[k] = conv(hc[k], TYPE_COLOR if k in ["paper", "ink"] else TYPE_FLOAT)
	return out

static func uniforms(id: String) -> Dictionary:
	if _types.has(id):
		return _types[id]
	var out := {}
	var sh = load(shader_path(id))
	if sh is Shader:
		for u in (sh as Shader).get_shader_uniform_list():
			var t := int(u.get("type", TYPE_NIL))
			if t == TYPE_OBJECT or t == TYPE_NIL:
				continue
			out[str(u.name)] = t
	_types[id] = out
	return out

# JSON -> tipo del uniform (type < 0: se adivina: "#hex" color, listas de 2/3/4 -> vec2/vec3/color)
static func conv(v, type: int):
	match type:
		TYPE_COLOR:
			if v is Color:
				return v
			if v is String:
				return Color(v)
			if v is Array and v.size() >= 3:
				return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]) if v.size() > 3 else 1.0)
		TYPE_VECTOR2:
			if v is Array and v.size() >= 2:
				return Vector2(float(v[0]), float(v[1]))
		TYPE_VECTOR3:
			if v is Array and v.size() >= 3:
				return Vector3(float(v[0]), float(v[1]), float(v[2]))
		TYPE_VECTOR4:
			if v is Array and v.size() >= 4:
				return Vector4(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		TYPE_INT:
			return int(v)
		TYPE_BOOL:
			return bool(v)
		TYPE_FLOAT:
			return float(v)
		-1:
			if v is String and (v.begins_with("#") or v.is_valid_html_color()):
				return Color(v)
			if v is Array:
				if v.size() == 2:
					return Vector2(float(v[0]), float(v[1]))
				if v.size() == 3:
					return Vector3(float(v[0]), float(v[1]), float(v[2]))
				if v.size() == 4:
					return Color(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
	return v
