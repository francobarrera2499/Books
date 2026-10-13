# Iluminación por franja (W1-POST). Contrato: docs/ARCHITECTURE.md §7.7 · GDD §14.4-14.5 · GDD §2.1 (luz y clima).
# Biblioteca estática (sin class_name): const Lighting = preload("res://world/lighting.gd")
#
#   Lighting.names() -> Array                         presets: manana_perla dia_ventana tarde gas farol_calle
#                                                     electrica_fria dorada_parklane noche_viento
#   Lighting.preset_for(place: Dictionary, slot, snap={}) -> String
#                                                     place.light["<día>.<franja>"] > place.light[slot] (§4.11) > el de la
#                                                     franja; luego el clima del día (CLIMA: la noche del 5 fría y ventosa)
#   Lighting.paper_for(slot) -> Color                 papel de la franja: mañana gris perla, tarde, noche ámbar de gas
#   Lighting.look(preset, slot) -> Dictionary         {paper, ink, exposure, contrast, haze, gamma, tone_floor, vignette, ...}
#                                                     -> EngravingPost.set_look. El papel es el de la franja; un preset con
#                                                     `paper` lo tiñe (Park Lane dorado, la noche fría del 5).
#   Lighting.build_lights(preset, opts={}) -> Node3D  nodo "Lights": DirectionalLight3D "Key" (+ "Fill"); opts.azim gira en Y
#   Lighting.make_environment(preset) -> Environment  tonemap lineal, sin glow/SSAO/SSIL/SDFGI/SSR/niebla
#   Lighting.build_env(preset) -> WorldEnvironment    nodo "Env"
#   Lighting.light_props(root, preset) -> int         configura las lámparas de los props (ver abajo); devuelve encendidas
#   Lighting.apply(root, preset, slot, opts={}) -> Dictionary  reemplaza root/Lights y root/Env, enciende lámparas; devuelve look
#
# Lámparas de props: todo Node3D con meta "light" = true | "gas" | "farol" | "electrica" | Dictionary
#   {kind, energy?, range?, color?, shadow?: bool, offset?: [x,y,z]}. El nodo marca la llama (u `offset` local).
#   Si el prop ya trae OmniLight3D hijos, se configuran ésos; si no, se crea el hijo "LampLight".
#   Cada preset decide qué clases se encienden (de día, ninguna). Sombras: SÓLO lámparas con shadow:true
#   (la de gas de la tienda de Crane: la sombra del librero llega al techo). Las direccionales nunca hacen sombra.
# noche_viento: los faroles parpadean con las rachas (nodo "Flicker" bajo Lights; tiempo real: es visual, no lógica).
extends RefCounted

const INK := Color("1b1712")
const PAPER := {"manana": Color("e8e6e0"), "tarde": Color("efe6d2"), "noche": Color("ecd9b4")}
const SLOT_TONE := {"dawn": "manana", "M": "manana", "T": "tarde", "N": "noche", "night": "noche"}
const SLOT_PRESET := {"dawn": "manana_perla", "M": "manana_perla", "T": "tarde", "N": "gas", "night": "gas"}
const LAMP_KINDS := {
	"gas": {"color": Color("ffb45e"), "energy": 2.4, "range": 6.5, "attenuation": 1.1},
	"farol": {"color": Color("ffc274"), "energy": 3.2, "range": 9.0, "attenuation": 1.0},
	"electrica": {"color": Color("eef3ff"), "energy": 1.6, "range": 12.0, "attenuation": 0.9},
}
# key/fill: {color, energy, elev (grados sobre el horizonte), azim (grados, giro en Y; 0 = luz hacia -Z)}
# amb: ambiente de color; sky: fondo 3D; lamps: clases encendidas (+ multiplicador); post: parámetros del grabado;
# paper (opcional): {tint, mix} tiñe el papel de la franja.
# Calibración W4-STYLE (capturas devtools/drivers/w4style_lugares.gd; T27 con ventana): gamma < 1 aclara los medios
# tonos de día (paredes y pisos en sombra legibles) sin tocar el negro: lo macizo (paño, levitas, madera oscura) sigue
# negro y sus contornos se tallan en blanco hasta white_line 0,3 (grabado a la contra: así se leen una figura oscura
# en un sillón oscuro); de noche el gas deja la periferia en sombra (vignette). Las direccionales no hacen sombra (§7.7).
const PRESETS := {
	"manana_perla": {
		"key": {"color": Color("e4e7ea"), "energy": 0.9, "elev": 38.0, "azim": -35.0},
		"fill": {"color": Color("d8dde2"), "energy": 0.32, "elev": 20.0, "azim": 150.0},
		"amb": {"color": Color("d4d6d8"), "energy": 0.56},
		"sky": Color("dfe1e2"), "lamps": {},
		"post": {"exposure": 1.45, "contrast": 1.3, "haze": 0.3, "haze_range": Vector2(12.0, 60.0), "gamma": 0.88, "white_line": 0.3},
	},
	"dia_ventana": {
		"key": {"color": Color("f4f0e6"), "energy": 1.15, "elev": 30.0, "azim": 60.0},
		"fill": {"color": Color("d6d2c8"), "energy": 0.26, "elev": 15.0, "azim": -120.0},
		"amb": {"color": Color("ccc6ba"), "energy": 0.5},
		"sky": Color("ece8dc"), "lamps": {},
		"post": {"exposure": 1.4, "contrast": 1.35, "haze": 0.15, "gamma": 0.84, "white_line": 0.3},
	},
	"tarde": {
		"key": {"color": Color("f3dcb4"), "energy": 1.05, "elev": 22.0, "azim": 72.0},
		"fill": {"color": Color("c8c0b4"), "energy": 0.26, "elev": 28.0, "azim": -110.0},
		"amb": {"color": Color("c4b8a6"), "energy": 0.58},
		"sky": Color("efe2c8"), "lamps": {},
		"post": {"exposure": 1.4, "contrast": 1.38, "haze": 0.2, "gamma": 0.82, "white_line": 0.3},
	},
	"gas": {
		"key": {"color": Color("8c98aa"), "energy": 0.06, "elev": 30.0, "azim": 40.0},
		"fill": {},
		"amb": {"color": Color("7a6448"), "energy": 0.27},
		"sky": Color("2a2620"), "lamps": {"gas": 1.0, "farol": 1.0},
		"post": {"exposure": 1.3, "contrast": 1.25, "white_line": 0.28, "gamma": 1.0, "vignette": 0.42},
	},
	"farol_calle": {
		"key": {"color": Color("ffcb8c"), "energy": 0.45, "elev": 9.0, "azim": -75.0},
		"fill": {},
		"amb": {"color": Color("5a5048"), "energy": 0.27},
		"sky": Color("201e1c"), "lamps": {"farol": 1.0, "gas": 1.0},
		"post": {"exposure": 1.4, "contrast": 1.2, "white_line": 0.28, "gamma": 0.92, "vignette": 0.25},
	},
	"electrica_fria": {
		"key": {"color": Color("e6eef6"), "energy": 1.0, "elev": 68.0, "azim": 20.0},
		"fill": {"color": Color("dae2ea"), "energy": 0.32, "elev": 30.0, "azim": -150.0},
		"amb": {"color": Color("ccd4da"), "energy": 0.72},
		"sky": Color("e6eaee"), "lamps": {"electrica": 1.0},
		"post": {"exposure": 1.5, "contrast": 1.3, "haze": 0.12, "gamma": 0.8, "white_line": 0.3},
	},
	"dorada_parklane": {
		"key": {"color": Color("ffc56a"), "energy": 1.8, "elev": 7.0, "azim": -72.0},
		"fill": {"color": Color("b0a8a0"), "energy": 0.14, "elev": 40.0, "azim": 110.0},
		"amb": {"color": Color("a08c70"), "energy": 0.52},
		"sky": Color("f2d8a4"), "lamps": {},
		"post": {"exposure": 1.3, "contrast": 1.5, "haze": 0.35, "haze_range": Vector2(16.0, 80.0), "gamma": 0.92, "white_line": 0.3},
		"paper": {"tint": Color("f3c878"), "mix": 0.42},
	},
	"noche_viento": {
		"key": {"color": Color("7c8698"), "energy": 0.05, "elev": 35.0, "azim": -20.0},
		"fill": {},
		"amb": {"color": Color("4a4850"), "energy": 0.24},
		"sky": Color("1c1c20"), "lamps": {"farol": 1.0, "gas": 0.9}, "flicker": true,
		"post": {"exposure": 1.4, "contrast": 1.25, "white_line": 0.3, "haze": 0.15, "gamma": 1.0, "vignette": 0.4},
		"paper": {"tint": Color("d4d9e2"), "mix": 0.4},
	},
}
# Clima del calendario (GDD §2.1 «Luz y clima» [H, C]; §14.4): la noche del jueves 5 de abril (día 10, N y 22 h) es
# fría y ventosa. Con clima, los presets nocturnos de base pasan a su variante (faroles y gas que parpadean, papel frío).
# Un lugar puede fijar otra cosa con place.light["10.N"].
const CLIMA := {10: {"N": "viento", "night": "viento"}}
const CLIMA_PRESET := {"viento": {"gas": "noche_viento", "farol_calle": "noche_viento", "noche_viento": "noche_viento"}}

static func names() -> Array:
	var a := PRESETS.keys()
	a.sort()
	return a

static func has(preset: String) -> bool:
	return PRESETS.has(preset)

static func tone_for(slot: String) -> String:
	return SLOT_TONE.get(slot, "tarde")

static func paper_for(slot: String) -> Color:
	return PAPER[tone_for(slot)]

# snap (opcional) = la instantánea que se construye (§4.11: {day, slot, ...}); sin snap no hay clima ni excepciones por día.
static func preset_for(place: Dictionary, slot: String, snap := {}) -> String:
	var lt = place.get("light", {})
	if not (lt is Dictionary):
		lt = {}
	var day := int(snap.get("day", -1)) if snap is Dictionary else -1
	if day >= 0:
		var alias := "N" if slot == "night" else ("M" if slot == "dawn" else slot)
		for k in ["%d.%s" % [day, slot], "%d.%s" % [day, alias]]:
			if lt.has(k) and PRESETS.has(str(lt[k])):
				return str(lt[k])
	var base: String = SLOT_PRESET.get(slot, "tarde")
	if lt.has(slot) and PRESETS.has(str(lt[slot])):
		base = str(lt[slot])
	elif slot == "night" and lt.has("N") and PRESETS.has(str(lt["N"])):
		base = str(lt["N"])
	elif slot == "dawn" and lt.has("M") and PRESETS.has(str(lt["M"])):
		base = str(lt["M"])
	var cl := clima(day, slot)
	if cl != "" and (CLIMA_PRESET.get(cl, {}) as Dictionary).has(base):
		return str(CLIMA_PRESET[cl][base])
	return base

# Clima de un día y franja ("" si es el de siempre).
static func clima(day: int, slot: String) -> String:
	return str((CLIMA.get(day, {}) as Dictionary).get(slot, ""))

static func _p(preset: String) -> Dictionary:
	if PRESETS.has(preset):
		return PRESETS[preset]
	push_warning("Lighting: preset desconocido '%s'; uso 'tarde'" % preset)
	return PRESETS["tarde"]

static func look(preset: String, slot: String) -> Dictionary:
	var lk := {"preset": preset, "slot": slot, "paper": paper_of(preset, slot), "ink": INK}
	var post: Dictionary = _p(preset).get("post", {})
	for k in post:
		lk[k] = post[k]
	return lk

# Papel de la franja, teñido por el preset si lo pide (la hora se lee en el papel; Park Lane a las 18 h, dorado; la
# noche del 5, fría).
static func paper_of(preset: String, slot: String) -> Color:
	var c := paper_for(slot)
	var pp = _p(preset).get("paper", {})
	if pp is Dictionary and pp.has("tint"):
		c = c.lerp(pp.tint, float(pp.get("mix", 0.0)))
	return c

static func _dir_light(nm: String, d: Dictionary) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = nm
	l.light_color = d.get("color", Color.WHITE)
	l.light_energy = float(d.get("energy", 1.0))
	l.rotation_degrees = Vector3(-float(d.get("elev", 45.0)), float(d.get("azim", 0.0)), 0.0)
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	return l

# opts.azim (grados): gira todo el juego de direccionales en Y (lugares orientados de otro modo; p. ej. place.light_azim)
static func build_lights(preset: String, opts := {}) -> Node3D:
	var p := _p(preset)
	var root := Node3D.new()
	root.name = "Lights"
	root.set_meta("preset", preset)
	root.rotation_degrees.y = float(opts.get("azim", 0.0))
	root.add_child(_dir_light("Key", p.key))
	var fill: Dictionary = p.get("fill", {})
	if not fill.is_empty():
		root.add_child(_dir_light("Fill", fill))
	if bool(p.get("flicker", false)):
		var f := Flicker.new()
		f.name = "Flicker"
		root.add_child(f)
	return root

# Alias para DioramaBuilder (W1-3D): Lighting.build(preset, slot) -> nodo "Lights".
static func build(preset: String, slot := "", opts := {}) -> Node3D:
	return build_lights(preset, opts)

static func make_environment(preset: String) -> Environment:
	var p := _p(preset)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = p.get("sky", Color("efe6d2"))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = p.amb.color
	e.ambient_light_energy = float(p.amb.energy)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	e.glow_enabled = false
	e.ssao_enabled = false
	e.ssil_enabled = false
	e.sdfgi_enabled = false
	e.ssr_enabled = false
	e.fog_enabled = false
	e.volumetric_fog_enabled = false
	e.adjustment_enabled = false
	return e

static func build_env(preset: String, slot := "") -> WorldEnvironment:
	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = make_environment(preset)
	return we

static func _lamp_spec(meta) -> Dictionary:
	var s := {"kind": "gas"}
	if meta is String:
		s.kind = meta
	elif meta is Dictionary:
		for k in meta:
			s[k] = meta[k]
	if not LAMP_KINDS.has(str(s.kind)):
		s.kind = "gas"
	return s

static func _lamp_nodes(root: Node, out: Array) -> void:
	if root is Node3D and root.has_meta("light"):
		var m = root.get_meta("light")
		if not (m is bool and m == false):
			out.append(root)
	for c in root.get_children():
		_lamp_nodes(c, out)

# la carcasa de la lámpara (vidrio, farol) no proyecta sombra de su propia luz
static func _no_self_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_self_shadow(c)

# Dos formas: light_props(root, preset) o, como la llama DioramaBuilder, light_props(lights, diorama, preset)
# (las lámparas se buscan en el diorama; las OmniLight3D cuelgan de cada lámpara).
static func light_props(p_a: Node, p_b, p_c = null) -> int:
	var root: Node = p_a
	var preset := str(p_b)
	if p_b is Node:
		root = p_b
		preset = str(p_c)
	var p := _p(preset)
	var lit: Dictionary = p.get("lamps", {})
	var nodes: Array = []
	_lamp_nodes(root, nodes)
	var n_on := 0
	for nd in nodes:
		var s := _lamp_spec(nd.get_meta("light"))
		# convención de W1-3D (street.light_anchor): metas sueltas color / range / shadow / lamp_kind. La energía
		# suelta se ignora a propósito: la decide la clase de lámpara × el preset (sólo un Dictionary la fija).
		for k in ["color", "range", "shadow"]:
			if not s.has(k) and nd.has_meta(k):
				s[k] = nd.get_meta(k)
		if nd.has_meta("lamp_kind") and LAMP_KINDS.has(str(nd.get_meta("lamp_kind"))):
			s.kind = str(nd.get_meta("lamp_kind"))
		var base: Dictionary = LAMP_KINDS[s.kind]
		var on := lit.has(s.kind)
		_no_self_shadow(nd)
		var omnis: Array = []
		for c in nd.get_children():
			if c is OmniLight3D:
				omnis.append(c)
		if omnis.is_empty():
			var o := OmniLight3D.new()
			o.name = "LampLight"
			var off = s.get("offset", [0.0, 0.0, 0.0])
			if off is Array and off.size() == 3:
				o.position = Vector3(float(off[0]), float(off[1]), float(off[2]))
			nd.add_child(o)
			omnis.append(o)
		for o in omnis:
			var colr = s.get("color", base.color)
			o.light_color = colr if colr is Color else Color(str(colr))
			o.light_energy = float(s.get("energy", base.energy)) * float(lit.get(s.kind, 0.0))
			o.omni_range = float(s.get("range", base.range))
			o.omni_attenuation = float(base.attenuation)
			o.light_specular = 0.0
			o.shadow_enabled = on and bool(s.get("shadow", false))
			o.visible = on
			o.set_meta("lamp_kind", s.kind)
			o.set_meta("base_energy", o.light_energy)
		if on:
			n_on += 1
	return n_on

static func apply(root: Node3D, preset: String, slot: String, opts := {}) -> Dictionary:
	for nm in ["Lights", "Env"]:
		var old := root.get_node_or_null(nm)
		if old != null:
			root.remove_child(old)
			old.queue_free()
	var lights := build_lights(preset, opts)
	light_props(root, preset)
	var f := lights.get_node_or_null("Flicker")
	if f != null:
		f.scan_root = root
	root.add_child(lights)
	root.add_child(build_env(preset))
	return look(preset, slot)

# Parpadeo de faroles (noche del 5). Visual: usa tiempo real. Fase por lámpara derivada del nombre (estable).
class Flicker extends Node:
	var scan_root: Node = null
	var lamps: Array = []
	var phases: Array = []
	var t := 0.0

	func _ready() -> void:
		lamps.clear()
		phases.clear()
		var sc: Node = scan_root
		if sc == null:
			sc = get_parent()
			if sc != null and sc.get_parent() != null:
				sc = sc.get_parent()  # Lights cuelga del diorama: las lámparas están en el diorama
		_collect(sc)
		for i in lamps.size():
			phases.append(float(hash(str(lamps[i].get_parent().name) + str(i)) % 1000) / 1000.0 * TAU)

	func _collect(n: Node) -> void:
		if n is OmniLight3D and n.visible and n.has_meta("base_energy"):
			lamps.append(n)
		for c in n.get_children():
			_collect(c)

	# En 1 bit cualquier cambio de tono mueve la trama: nada de zumbido continuo. La llama está quieta entre rachas; la
	# racha (dos senos lentos por lámpara, desfasados) la baja de golpe y la deja volver. La energía se cuantiza en
	# LEVELS escalones y se evalúa cada STEP_S: la trama «late» con el viento unas veces por racha y si no, no se mueve.
	const STEP_S := 0.12
	const LEVELS := 8.0

	func _process(dt: float) -> void:
		t += dt
		var tq := floorf(t / STEP_S) * STEP_S
		for i in lamps.size():
			var l: OmniLight3D = lamps[i]
			if not is_instance_valid(l):
				continue
			l.light_energy = float(l.get_meta("base_energy")) * gust_factor(tq, phases[i])

	static func gust_factor(tq: float, ph: float) -> float:
		var gust := 0.5 + 0.5 * sin(tq * 0.9 + ph) * sin(tq * 0.31 + ph * 2.0)
		var w := 1.0 - 0.55 * pow(gust, 4.0)
		return clampf(roundf(w * LEVELS) / LEVELS, 0.45, 1.0)
