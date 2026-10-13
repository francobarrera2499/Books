# Unitarios de world/lighting.gd (W1-POST): presets por franja, papel, entorno, lámparas de props.
extends "res://tests/test_base.gd"

const Lighting = preload("res://world/lighting.gd")
const EngravingPost = preload("res://world/post/engraving_post.gd")
const PRESETS := ["dia_ventana", "dorada_parklane", "electrica_fria", "farol_calle", "gas", "manana_perla", "noche_viento", "tarde"]

var _nodes: Array = []

func after_each() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()

func _lamp_scene() -> Node3D:
	var root := Node3D.new()
	_nodes.append(root)
	var props := Node3D.new()
	props.name = "Props"
	root.add_child(props)
	var g := MeshInstance3D.new()
	g.name = "gas_crane"
	g.mesh = SphereMesh.new()
	g.set_meta("light", {"kind": "gas", "shadow": true, "offset": [0, 0.1, 0]})
	props.add_child(g)
	var f := Node3D.new()
	f.name = "farol"
	f.set_meta("light", "farol")
	props.add_child(f)
	var e := Node3D.new()
	e.name = "arco"
	e.set_meta("light", "electrica")
	props.add_child(e)
	var p := Node3D.new()
	p.name = "pared"
	p.set_meta("light", true)  # true = gas
	props.add_child(p)
	var pre := Node3D.new()
	pre.name = "con_omni"
	pre.set_meta("light", "farol")
	var o := OmniLight3D.new()
	o.name = "Propia"
	pre.add_child(o)
	props.add_child(pre)
	var off := Node3D.new()
	off.name = "apagada"
	off.set_meta("light", false)
	props.add_child(off)
	return root

func _omni(root: Node, path: String) -> OmniLight3D:
	var n := root.get_node_or_null(path)
	if n == null:
		return null
	for c in n.get_children():
		if c is OmniLight3D:
			return c
	return null

func test_presets_exist() -> void:
	eq(Lighting.names(), PRESETS, "los 8 presets de §7.7")
	for p in PRESETS:
		ok(Lighting.has(p), p)
		var d: Dictionary = Lighting.PRESETS[p]
		ok(d.has("key") and d.has("amb") and d.has("post") and d.has("lamps"), "forma de " + p)

func test_paper_by_slot() -> void:
	ok(Lighting.paper_for("M").is_equal_approx(Color("e8e6e0")), "mañana gris perla")
	ok(Lighting.paper_for("dawn").is_equal_approx(Color("e8e6e0")), "amanecer = mañana")
	ok(Lighting.paper_for("T").is_equal_approx(Color("efe6d2")), "tarde")
	ok(Lighting.paper_for("N").is_equal_approx(Color("ecd9b4")), "noche ámbar de gas")
	ok(Lighting.paper_for("night").is_equal_approx(Color("ecd9b4")), "22 h = noche")
	ok(Lighting.INK.is_equal_approx(Color("1b1712")), "tinta")

func test_preset_for_place() -> void:
	var place := {"light": {"M": "dia_ventana", "T": "tarde", "N": "gas"}}
	eq(Lighting.preset_for(place, "M"), "dia_ventana")
	eq(Lighting.preset_for(place, "N"), "gas")
	eq(Lighting.preset_for(place, "night"), "gas", "22 h hereda N")
	eq(Lighting.preset_for(place, "dawn"), "dia_ventana", "amanecer hereda M")
	eq(Lighting.preset_for({}, "M"), "manana_perla", "sin light: la franja")
	eq(Lighting.preset_for({}, "N"), "gas")
	eq(Lighting.preset_for({"light": {"M": "inexistente"}}, "M"), "manana_perla", "preset desconocido en datos -> franja")

func test_look() -> void:
	var lk := Lighting.look("gas", "N")
	ok(lk.paper.is_equal_approx(Color("ecd9b4")), "papel de noche")
	ok(lk.ink.is_equal_approx(Color("1b1712")), "tinta")
	ok(lk.has("exposure") and lk.has("contrast"), "parámetros de post")
	eq(lk.preset, "gas")
	var lk2 := Lighting.look("tarde", "N")
	ok(lk2.paper.is_equal_approx(Color("ecd9b4")), "la hora se lee en el papel (franja), sea cual sea el preset")
	for p in ["manana_perla", "dia_ventana", "tarde", "gas", "farol_calle", "electrica_fria"]:
		for sl in ["M", "T", "N"]:
			ok(Lighting.look(p, sl).paper.is_equal_approx(Lighting.paper_for(sl)), "%s/%s: papel de la franja" % [p, sl])

func test_environment_is_flat() -> void:
	for p in PRESETS:
		var e := Lighting.make_environment(p)
		eq(e.tonemap_mode, Environment.TONE_MAPPER_LINEAR, p + " tonemap lineal")
		ok(not e.glow_enabled and not e.ssao_enabled and not e.ssil_enabled and not e.sdfgi_enabled and not e.ssr_enabled, p + " sin glow/SSAO/SSIL/SDFGI/SSR")
		ok(not e.fog_enabled and not e.volumetric_fog_enabled, p + " sin niebla")
		eq(e.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR, p + " ambiente de color")
		eq(e.background_mode, Environment.BG_COLOR, p + " fondo de color")
		var lights := Lighting.build_lights(p)
		_nodes.append(lights)
		var key := lights.get_node_or_null("Key")
		ok(key is DirectionalLight3D, p + " Key direccional")
		for c in lights.get_children():
			if c is Light3D:
				ok(not c.shadow_enabled, p + " direccionales sin sombra")

func test_night_darker_than_day() -> void:
	var day: Dictionary = Lighting.PRESETS["dia_ventana"]
	for p in ["gas", "farol_calle", "noche_viento"]:
		var n: Dictionary = Lighting.PRESETS[p]
		ok(float(n.key.energy) < float(day.key.energy) * 0.5, p + " key de noche débil")
		ok(not (n.lamps as Dictionary).is_empty(), p + " enciende lámparas")
	for p in ["manana_perla", "dia_ventana", "tarde", "dorada_parklane"]:
		ok((Lighting.PRESETS[p].lamps as Dictionary).is_empty(), p + " de día no hay lámparas")
	var gold: Dictionary = Lighting.PRESETS["dorada_parklane"]
	ok(float(gold.key.elev) < 12.0, "Park Lane: luz rasante")
	ok(gold.key.color.r > gold.key.color.b + 0.3, "Park Lane: dorada")
	var el: Dictionary = Lighting.PRESETS["electrica_fria"]
	ok(el.key.color.b >= el.key.color.r, "eléctrica fría")

func test_lamps_day_off() -> void:
	var root := _lamp_scene()
	var n := Lighting.light_props(root, "dia_ventana")
	eq(n, 0, "de día ninguna encendida")
	for path in ["Props/gas_crane", "Props/farol", "Props/arco", "Props/pared", "Props/con_omni"]:
		var o := _omni(root, path)
		ok(o != null, "omni en " + path)
		ok(o != null and not o.visible, "apagada " + path)
		ok(o != null and not o.shadow_enabled, "sin sombra de día " + path)
	ok(_omni(root, "Props/apagada") == null, "meta light=false se ignora")

func test_lamps_gas_night() -> void:
	var root := _lamp_scene()
	var n := Lighting.light_props(root, "gas")
	eq(n, 4, "gas + farol encendidas (gas_crane, farol, pared, con_omni)")
	var g := _omni(root, "Props/gas_crane")
	ok(g.visible and g.light_energy > 0.5, "gas encendida")
	ok(g.shadow_enabled, "la de la tienda de Crane proyecta sombra (pista)")
	ok(g.position.is_equal_approx(Vector3(0, 0.1, 0)), "offset de la llama")
	ok((root.get_node("Props/gas_crane") as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "la carcasa no se sombrea a sí misma")
	ok(not _omni(root, "Props/pared").shadow_enabled, "sin shadow:true no hay sombra")
	ok(not _omni(root, "Props/arco").visible, "la eléctrica no se enciende con gas")
	var own := root.get_node("Props/con_omni/Propia") as OmniLight3D
	ok(own.visible and own.light_energy > 0.5, "configura la OmniLight3D propia del prop")
	eq(root.get_node("Props/con_omni").get_child_count(), 1, "no duplica la omni propia")
	Lighting.light_props(root, "gas")
	eq(root.get_node("Props/gas_crane").get_child_count(), 1, "idempotente: no duplica LampLight")

func test_lamps_electric_and_street() -> void:
	var root := _lamp_scene()
	eq(Lighting.light_props(root, "electrica_fria"), 1, "sólo la eléctrica")
	ok(_omni(root, "Props/arco").visible, "arco encendido")
	eq(Lighting.light_props(root, "farol_calle"), 4, "faroles y gas (de noche todo pico de gas arde)")
	ok(_omni(root, "Props/farol").visible and not _omni(root, "Props/arco").visible, "farol sí, eléctrica no")

func test_w13d_light_anchor_convention() -> void:
	# street.light_anchor de W1-3D: Marker3D con metas sueltas light=true, color, energy, range
	var root := Node3D.new()
	_nodes.append(root)
	var mk := Marker3D.new()
	mk.name = "light_anchor"
	mk.set_meta("light", true)
	mk.set_meta("color", Color("ffc87a"))
	mk.set_meta("energy", 1.4)
	mk.set_meta("range", 7.0)
	root.add_child(mk)
	eq(Lighting.light_props(root, "noche_viento"), 1, "se enciende de noche")
	var o := _omni(root, "light_anchor")
	ok(o.light_color.is_equal_approx(Color("ffc87a")), "color del prop")
	near(o.omni_range, 7.0, 1e-4, "alcance del prop")
	near(o.light_energy, float(Lighting.LAMP_KINDS.gas.energy) * float(Lighting.PRESETS.noche_viento.lamps.gas), 1e-4, "energía = clase × preset (la suelta se ignora)")
	mk.set_meta("lamp_kind", "electrica")
	eq(Lighting.light_props(root, "noche_viento"), 0, "lamp_kind manda: eléctrica apagada en noche_viento")

func test_apply_replaces_and_flicker() -> void:
	var root := _lamp_scene()
	var lk := Lighting.apply(root, "tarde", "T")
	ok(lk.paper.is_equal_approx(Color("efe6d2")), "look de tarde")
	ok(root.get_node_or_null("Lights") != null and root.get_node_or_null("Env") is WorldEnvironment, "Lights + Env")
	Lighting.apply(root, "noche_viento", "N")
	var n_lights := 0
	var n_env := 0
	for c in root.get_children():
		if c.name.begins_with("Lights"):
			n_lights += 1
		if c is WorldEnvironment:
			n_env += 1
	eq(n_lights, 1, "un solo Lights")
	eq(n_env, 1, "un solo Env")
	var fl = root.get_node_or_null("Lights/Flicker")
	ok(fl != null, "noche_viento: parpadeo")
	if fl != null:
		fl.scan_root = root
		fl._ready()
		ok(fl.lamps.size() >= 2, "parpadean las lámparas encendidas")
		var ok_range := true
		for step in 20:
			fl._process(0.137)
			for l in fl.lamps:
				var base: float = l.get_meta("base_energy")
				if l.light_energy < base * 0.34 or l.light_energy > base * 1.06:
					ok_range = false
		ok(ok_range, "energía en [0,35; 1,05] × base")
	Lighting.apply(root, "gas", "N")
	ok(root.get_node_or_null("Lights/Flicker") == null, "gas: sin parpadeo")

func test_unknown_preset_falls_back() -> void:
	var lights := Lighting.build_lights("no_existe")
	_nodes.append(lights)
	ok(lights.get_node_or_null("Key") is DirectionalLight3D, "preset desconocido -> tarde (advertencia, no error)")

# Firmas que sondea DioramaBuilder (W1-3D): build(preset, slot), build_env(preset, slot), light_props(lights, diorama, preset)
func test_diorama_builder_signatures() -> void:
	var dio := _lamp_scene()
	var lights := Lighting.build("noche_viento", "N")
	ok(lights is Node3D and String(lights.name) == "Lights", "build -> Lights")
	ok(lights.get_node_or_null("Flicker") != null, "noche_viento trae parpadeo")
	eq(Lighting.light_props(lights, dio, "noche_viento"), 4, "forma de 3 argumentos: lámparas del diorama")
	ok(_omni(dio, "Props/farol").visible, "farol encendido en el diorama")
	var we := Lighting.build_env("noche_viento", "N")
	ok(we is WorldEnvironment and String(we.name) == "Env", "build_env(preset, slot)")
	we.free()
	dio.add_child(lights)
	var fl = lights.get_node("Flicker")
	fl._ready()
	ok(fl.lamps.size() >= 2, "el parpadeo encuentra las lámparas del diorama (padre de Lights)")
	var lit := Lighting.build_lights("tarde", {"azim": 30.0})
	_nodes.append(lit)
	near(lit.rotation_degrees.y, 30.0, 1e-4, "opts.azim gira las direccionales")

# ---------------------------------------------------------------------------------------------------------------------
# W4-STYLE: clima del calendario, papel teñido, calibración por preset, parpadeo con rachas.

func test_preset_for_snap_and_clima() -> void:
	var l1 := {"light": {"dawn": "manana_perla", "M": "manana_perla", "T": "tarde", "N": "gas", "night": "gas"}}
	var l3 := {"light": {"M": "manana_perla", "T": "tarde", "N": "farol_calle", "night": "noche_viento"}}
	var l2 := {"light": {"M": "electrica_fria", "N": "electrica_fria"}}
	eq(Lighting.preset_for(l1, "N", {"day": 9, "slot": "N"}), "gas", "día 9: gas de siempre")
	eq(Lighting.preset_for(l1, "N", {"day": 10, "slot": "N"}), "noche_viento", "noche del 5 (día 10 N): fría y ventosa")
	eq(Lighting.preset_for(l1, "night", {"day": 10, "slot": "night"}), "noche_viento", "y a las 22 h")
	eq(Lighting.preset_for(l3, "N", {"day": 10, "slot": "N"}), "noche_viento", "faroles de Baker Street con viento")
	eq(Lighting.preset_for(l3, "N", {"day": 4, "slot": "N"}), "farol_calle", "otras noches: farol")
	eq(Lighting.preset_for(l1, "M", {"day": 10, "slot": "M"}), "manana_perla", "el clima sólo toca la noche")
	eq(Lighting.preset_for(l2, "N", {"day": 10, "slot": "N"}), "electrica_fria", "la luz eléctrica no cambia con el viento")
	eq(Lighting.preset_for(l1, "N"), "gas", "sin instantánea no hay clima (firma de 2 argumentos intacta)")
	eq(Lighting.preset_for(l3, "night"), "noche_viento", "datos del lugar intactos")
	var ov := {"light": {"N": "gas", "10.N": "farol_calle", "3.T": "dorada_parklane"}}
	eq(Lighting.preset_for(ov, "N", {"day": 10}), "farol_calle", "place.light[\"10.N\"] manda sobre el clima")
	eq(Lighting.preset_for(ov, "night", {"day": 10}), "farol_calle", "\"10.N\" también vale a las 22 h")
	eq(Lighting.preset_for(ov, "T", {"day": 3}), "dorada_parklane", "excepción por día y franja")
	eq(Lighting.preset_for(ov, "T", {"day": 4}), "tarde", "sólo ese día")
	eq(Lighting.preset_for({"light": {"10.N": "inexistente", "N": "gas"}}, "N", {"day": 10}), "noche_viento", "excepción desconocida -> base + clima")
	eq(Lighting.clima(10, "N"), "viento")
	eq(Lighting.clima(9, "N"), "")
	for c in Lighting.CLIMA_PRESET:
		for base in Lighting.CLIMA_PRESET[c]:
			ok(Lighting.has(base) and Lighting.has(str(Lighting.CLIMA_PRESET[c][base])), "clima %s: %s existe" % [c, base])

func test_paper_tints_parklane_and_cold_night() -> void:
	var t := Lighting.paper_for("T")
	var gold := Lighting.look("dorada_parklane", "T").paper as Color
	ok(not gold.is_equal_approx(t), "Park Lane a las 18 h: el papel cambia")
	ok(gold.r - gold.b > (t.r - t.b) + 0.08, "Park Lane: papel dorado (r−b %.3f > %.3f)" % [gold.r - gold.b, t.r - t.b])
	ok(gold.get_luminance() > 0.75, "papel dorado claro, la tinta se sigue leyendo")
	var n := Lighting.paper_for("N")
	var cold := Lighting.look("noche_viento", "N").paper as Color
	ok(cold.r - cold.b < (n.r - n.b) - 0.05, "noche del 5: papel más frío que el ámbar de gas")
	ok(cold.get_luminance() > 0.75, "papel frío claro")
	ok(Lighting.paper_of("gas", "N").is_equal_approx(n), "paper_of sin tinte = papel de la franja")

func test_post_calibration_per_preset() -> void:
	for p in ["manana_perla", "dia_ventana", "tarde", "electrica_fria"]:
		var lk := Lighting.look(p, "M")
		ok(float(lk.get("gamma", 1.0)) < 1.0, p + ": de día los medios tonos se aclaran (gamma < 1)")
		ok(float(lk.get("tone_floor", 0.0)) == 0.0, p + ": el negro macizo se conserva (sin piso de tono)")
		ok(float(lk.get("white_line", 0.0)) >= 0.25, p + ": figura oscura en fondo oscuro: contornos en blanco")
		ok(float(lk.get("vignette", 0.0)) == 0.0, p + ": de día sin viñeta")
	for p in ["gas", "noche_viento"]:
		var lk2 := Lighting.look(p, "N")
		ok(float(lk2.get("vignette", 0.0)) > 0.2, p + ": de noche la periferia se hunde (viñeta)")
		ok(float(lk2.get("white_line", 0.0)) >= 0.25, p + ": contornos tallados en blanco en lo oscuro")
		ok(float(lk2.get("tone_floor", 0.0)) == 0.0, p + ": la noche conserva el negro")
	var lk3 := Lighting.look("dorada_parklane", "T")
	ok(float(lk3.contrast) >= 1.45, "Park Lane: contraste de luz rasante")
	for p in Lighting.names():
		for k in Lighting.look(p, "M"):
			if k in ["preset", "slot", "paper", "ink"]:
				continue
			ok(EngravingPost.LOOK_KEYS.has(k), "%s: la clave %s llega al shader" % [p, k])

func test_flicker_steps_with_gusts() -> void:
	var root := _lamp_scene()
	Lighting.apply(root, "noche_viento", "N")
	var fl = root.get_node("Lights/Flicker")
	fl.scan_root = root
	fl._ready()
	ok(fl.lamps.size() >= 2, "lámparas encendidas")
	var l: OmniLight3D = fl.lamps[0]
	var base: float = l.get_meta("base_energy")
	fl.t = 0.0
	fl._process(0.01)
	var e0 := l.light_energy
	fl._process(0.02)
	near(l.light_energy, e0, 1e-6, "dentro de un paso la llama no cambia (sin zumbido en la trama)")
	var lo := 9.0
	var hi := 0.0
	var changes := 0
	var prev := l.light_energy
	for i in 600:
		fl._process(0.05)
		lo = minf(lo, l.light_energy / base)
		hi = maxf(hi, l.light_energy / base)
		if not is_equal_approx(prev, l.light_energy):
			changes += 1
		prev = l.light_energy
	ok(lo >= 0.45 - 1e-4 and hi <= 1.0 + 1e-4, "energía en [0,45; 1] × base (%.2f–%.2f)" % [lo, hi])
	ok(hi - lo > 0.25, "las rachas se ven (%.2f–%.2f)" % [lo, hi])
	# 30 s de viento: la llama cambia unas pocas veces por racha, no en cada paso (en 1 bit, cada cambio mueve la trama)
	ok(changes > 4 and changes < 600 * 0.05 / Lighting.Flicker.STEP_S * 0.4, "cambios en 30 s: %d (escalonado, no zumbido)" % changes)
	var quiet := 0
	for i in 250:
		if is_equal_approx(Lighting.Flicker.gust_factor(i * 0.12, 1.0), 1.0):
			quiet += 1
	ok(quiet > 80, "entre rachas la llama está quieta (%d de 250 pasos a pleno)" % quiet)
