# Unitarios de world/lighting.gd (W1-POST): presets por franja, papel, entorno, lámparas de props.
extends "res://tests/test_base.gd"

const Lighting = preload("res://world/lighting.gd")
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
	var lk2 := Lighting.look("dorada_parklane", "N")
	ok(lk2.paper.is_equal_approx(Color("ecd9b4")), "la hora se lee en el papel (franja)")

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
