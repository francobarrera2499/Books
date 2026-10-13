# Post-proceso del 3D (W1-POST; nombre histórico «grabado»). Contrato: docs/ARCHITECTURE.md §7.8 · GDD §14.5.
# Un MeshInstance3D con QuadMesh 2x2 que cuelga de la Camera3D activa y dibuja el shader del LOOK activo a pantalla
# completa (vértice en el plano cercano: POSITION = vec4(VERTEX.xy, 1, 1)). Sólo afecta al 3D: toda CanvasLayer
# (lector, HUD, libros, subtítulos) se dibuja después y queda intacta.
# Looks (world/post/looks.gd): el quad nace con Looks.current() y cambia de shader solo cuando cambia la selección
# (Looks.serial: Opciones «Estilo de imagen», --look=<id>). Por defecto 'aguada' (looks/aguada.gdshader + aguada.json);
# 'grabado' = looks/grabado.gdshader con DEFAULTS/LOOK_KEYS/PAPER/INK de aquí y Lighting.look (alternativa en Opciones).
# set_look_id(id) fija otro look en este quad · set_preset(preset, slot) = Looks.params del look. Recién creado (sin
# preset), el quad usa el papel de tarde y la tinta de su look (Looks.params(id, "tarde", "T")).
#
# API (sin class_name; usar con preload):
#   const EngravingPost = preload("res://world/post/engraving_post.gd")
#   var post = EngravingPost.attach(camera)        # crea o reutiliza el hijo "EngravingPost" de la cámara
#   post.set_look(Lighting.look(preset, slot))     # papel por franja + parámetros del preset (en otro look: se
#                                                  # traduce a Looks.params(look_id, preset, slot))
#   post.set_preset(preset, slot) · post.set_look_id(id) · post.look_id
#   post.set_slot(slot, preset := "")              # sólo la franja: conserva el preset actual (o el de la franja)
#   post.set_palette(paper, ink) · post.set_paper(c) · post.set_style("dos_tintas"|"sepia")
#   post.set_high_contrast(on) · post.set_enabled(on) · post.reanchor() · post.set_param(n, v) / post.param(n)
#   EngravingPost.find(camera) -> nodo o null · EngravingPost.detach(camera)
# Capa de render 20 (LAYER): una cámara que no deba grabar (miniaturas) la excluye de su cull_mask.
# Trama: umbral Bayer 8x8 procedural. hatch=1 (por defecto, «talla»): rayado por cara (pisos/cielo horizontal, caras X
# a 45°, caras Z a -45°; cruzado bajo hatch_below) cuyas filas se reparten con los 64 umbrales Bayer -> lee como
# grabado de época. hatch=0: Bayer 8x8 puro (Obra Dinn). Ambos reproducen el tono en toda la escala (T27 con ventana:
# gris 0,5 -> 0,5 ± 0,06; rampa 0,1…0,9 ± 0,03; cada preset ± 0,03).
# W4-STYLE: el look de cada preset trae además gamma (< 1 aclara los medios tonos de día; el negro macizo se conserva),
# tone_floor (disponible, 0 en todos los presets), vignette (noche de gas) y el halo de siluetas (halo, halo_rel,
# halo_abs, halo_thick: filete de papel del lado lejano de un borde de oclusión, sólo tras algo de ≥ halo_thick px).
# debug_view: 0 grabado · 1 tono continuo · 2 contornos · 3 color 3D · 4 profundidad (máscaras de figura en drivers).
# Contornos tallados en blanco bajo `white_line` (noches legibles). Lo transparente (vidrio alfa, Label3D sin
# alpha_cut) NO entra a la textura de pantalla: los rótulos 3D deben usar alpha_cut = ALPHA_CUT_DISCARD.
# Trama anclada: en cada cambio de pose (NOTIFICATION_TRANSFORM_CHANGED, también si la mueve un Tween) acumula el giro incremental de la cámara (yaw, pitch en su propio espacio) en
# `anchor_rad`; el shader lo pasa a píxeles con el FOV y el alto del viewport y desplaza la rejilla Bayer
# entera: con cámara quieta la trama no se mueve; al girar acompaña al mundo; al trasladarse «nada» (aceptado).
extends MeshInstance3D

const Lighting = preload("res://world/lighting.gd")
const Looks = preload("res://world/post/looks.gd")
const SHADER_PATH := "res://world/post/looks/grabado.gdshader"   # look 'grabado'
const NODE_NAME := "EngravingPost"
const LAYER := 1 << 19
const PAPER := Color("efe6d2")
const INK := Color("1b1712")
const PALETTES := {
	"dos_tintas": {"paper": Color("efe6d2"), "ink": Color("1b1712")},
	"sepia": {"paper": Color("f1e3c6"), "ink": Color("4a2f1c")},
	"alto_contraste": {"paper": Color("ffffff"), "ink": Color("000000")},
}
# valores por defecto del shader del look 'grabado' (los presets de Lighting.look pisan algunos)
const DEFAULTS := {
	"edge_depth": 0.08, "edge_normal": 0.35, "cell_px": 2.0, "grain": 0.05,
	"exposure": 1.0, "contrast": 1.5, "hatch": 1.0, "hatch_below": 0.4, "hatch_period": 3.0, "white_line": 0.16,
	"haze": 0.0, "haze_range": Vector2(14.0, 70.0), "edge_far": 90.0,
	"gamma": 1.0, "tone_floor": 0.0, "vignette": 0.0, "halo": 1.0, "halo_rel": 0.06, "halo_abs": 0.12, "halo_thick": 3.0,
}
const LOOK_KEYS := ["edge_depth", "edge_normal", "cell_px", "grain", "exposure", "contrast", "hatch", "hatch_period",
	"hatch_below", "white_line", "haze", "haze_range", "edge_far", "gamma", "tone_floor", "vignette", "halo", "halo_rel", "halo_abs",
	"halo_thick"]

var mat: ShaderMaterial
var anchor_rad := Vector2.ZERO
var style := "dos_tintas"
var high_contrast := false
var _paper := PAPER
var _ink := INK
var _last_basis := Basis.IDENTITY
var _have_last := false
var _look := {}
var look_id := ""
var _keys: Array = LOOK_KEYS
var _defaults: Dictionary = DEFAULTS
var _base := {"paper": PAPER, "ink": INK}   # papel/tinta del look antes de conocer el preset (tarde)
var _serial := -1

static func attach(cam: Camera3D) -> MeshInstance3D:
	var ex := cam.get_node_or_null(NODE_NAME) as MeshInstance3D
	if ex != null:
		return ex
	var n: MeshInstance3D = load("res://world/post/engraving_post.gd").new()
	cam.add_child(n)
	return n

static func find(cam: Camera3D) -> MeshInstance3D:
	if cam == null:
		return null
	return cam.get_node_or_null(NODE_NAME) as MeshInstance3D

static func detach(cam: Camera3D) -> void:
	var ex := find(cam)
	if ex != null:
		cam.remove_child(ex)
		ex.queue_free()

func _init() -> void:
	name = NODE_NAME
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 2.0)
	mesh = q
	extra_cull_margin = 16384.0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	ignore_occlusion_culling = true
	layers = LAYER
	mat = ShaderMaterial.new()
	mat.render_priority = Material.RENDER_PRIORITY_MAX
	material_override = mat
	_serial = Looks.serial
	_use_look(Looks.current())
	# El ancla se actualiza con NOTIFICATION_TRANSFORM_CHANGED (la misma notificación con la que la Camera3D manda su
	# pose al RenderingServer): sigue a la cámara aunque la mueva un Tween (corre después de los _process) o la física.
	# _process queda de respaldo (p. ej. si sólo cambia el FOV o se reparenta).
	set_notify_transform(true)
	process_priority = 100000

func _ready() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and "high_contrast" in ti:
		set_high_contrast(bool(ti.high_contrast))
		if ti.has_signal("theme_changed") and not ti.theme_changed.is_connected(_on_theme_changed):
			ti.theme_changed.connect(_on_theme_changed)
	reanchor()

func _on_theme_changed() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and "high_contrast" in ti:
		set_high_contrast(bool(ti.high_contrast))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		update_anchor()

func _process(_dt: float) -> void:
	if _serial != Looks.serial:
		_serial = Looks.serial
		if Looks.current() != look_id:
			set_look_id(Looks.current())
	update_anchor()

# Cambia el shader del quad al del look `id` (desconocido -> Looks.DEFAULT) y fija sus defaults.
func _use_look(id: String) -> void:
	if not Looks.has(id):
		id = Looks.DEFAULT
	look_id = id
	var path := Looks.shader_path(id)
	if mat.shader == null or mat.shader.resource_path != path:
		mat.shader = load(path)
	if path == SHADER_PATH:
		_keys = LOOK_KEYS
		_defaults = DEFAULTS
	else:
		_keys = []
		for k in Looks.uniforms(id):
			if not Looks.RESERVED.has(k):
				_keys.append(k)
		_defaults = Looks.defaults(id)
	for k in _keys:
		mat.set_shader_parameter(k, _defaults.get(k, null))  # null: el default del shader
	for k in _defaults:
		mat.set_shader_parameter(k, _defaults[k])
	mat.set_shader_parameter("anchor_rad", anchor_rad)
	var bp := Looks.params(id, "tarde", "T")
	_base = {"paper": bp.get("paper", PAPER), "ink": bp.get("ink", INK)}
	if not _look.has("paper"):
		_paper = _base.paper
		_ink = _base.ink
	_apply_palette()

# Fija el look de este quad (sin esperar a la selección global) y rehace los parámetros de su preset y franja.
func set_look_id(id: String) -> void:
	_use_look(id)
	var p := str(_look.get("preset", ""))
	if p != "":
		set_look(Looks.params(look_id, p, str(_look.get("slot", "M"))))
	else:
		var lk := _look.duplicate()
		lk.erase("look")
		set_look(lk)

# preset de Lighting + franja -> parámetros del look activo de este quad
func set_preset(preset: String, slot: String) -> void:
	set_look(Looks.params(look_id, preset, slot))

# Acumula el giro incremental de la cámara desde el último frame (en el espacio de la cámara anterior).
func update_anchor() -> void:
	var cam := get_parent() as Camera3D
	if cam == null or not cam.is_inside_tree():
		return
	var b := cam.global_transform.basis.orthonormalized()
	if _have_last:
		var d := _last_basis.inverse() * b
		var f := -d.z
		var yaw := atan2(f.x, -f.z)
		var pitch := asin(clampf(f.y, -1.0, 1.0))
		anchor_rad += Vector2(yaw, pitch)
	_last_basis = b
	_have_last = true
	mat.set_shader_parameter("anchor_rad", anchor_rad)

func reanchor() -> void:
	anchor_rad = Vector2.ZERO
	_have_last = false
	mat.set_shader_parameter("anchor_rad", anchor_rad)
	update_anchor()

func set_enabled(on: bool) -> void:
	visible = on

func set_param(n: String, v) -> void:
	mat.set_shader_parameter(n, v)

func param(n: String):
	return mat.get_shader_parameter(n)

func set_paper(c: Color) -> void:
	_paper = c
	_apply_palette()

func set_ink(c: Color) -> void:
	_ink = c
	_apply_palette()

func set_palette(p: Color, i: Color) -> void:
	_paper = p
	_ink = i
	_apply_palette()

# "dos_tintas" (por defecto, GDD §16.3) o "sepia": sólo cambia papel y tinta. El papel de la franja manda en dos tintas.
func set_style(s: String) -> void:
	if not PALETTES.has(s):
		push_warning("EngravingPost: estilo desconocido " + s)
		return
	style = s
	if s != "dos_tintas":
		_paper = PALETTES[s].paper
		_ink = PALETTES[s].ink
	else:
		_paper = _look.get("paper", _base.paper)
		_ink = _look.get("ink", _base.ink)
	_apply_palette()

# Sólo la franja (WorldRoot la llama cuando todavía no conoce el preset del lugar): conserva el preset del look
# actual (o `preset` si se da) y cambia el papel; sin preset previo usa el de la franja (Lighting.SLOT_PRESET).
func set_slot(slot: String, preset := "") -> void:
	var p := preset
	if p == "" or not Lighting.has(p):
		p = str(_look.get("preset", ""))
	if p == "" or not Lighting.has(p):
		p = str(Lighting.SLOT_PRESET.get(slot, "tarde"))
	set_look(Looks.params(look_id, p, slot))

# look = Looks.params(id, preset, slot) o Lighting.look(preset, slot): {paper, ink, exposure, contrast, haze, ...}.
# Con "look" distinto del de este quad, cambia de shader; un Lighting.look (con preset, sin "look") en un look que no
# es de base lighting se traduce a Looks.params de ese look. Un diccionario suelto (sin preset) se aplica tal cual.
func set_look(look: Dictionary) -> void:
	var want := str(look.get("look", ""))
	if want != "" and want != look_id and Looks.has(want):
		_use_look(want)
	elif want == "" and look.has("preset") and not Looks.is_base(look_id) and Looks.has(look_id):
		look = Looks.params(look_id, str(look.preset), str(look.get("slot", "M")))
	_look = look.duplicate()
	for k in _keys:
		mat.set_shader_parameter(k, look.get(k, _defaults.get(k, null)))
	if look.has("paper"):
		_paper = look.paper
	if look.has("ink"):
		_ink = look.ink
	if style == "sepia":
		_paper = PALETTES.sepia.paper
		_ink = PALETTES.sepia.ink
	_apply_palette()

func set_high_contrast(on: bool) -> void:
	high_contrast = on
	_apply_palette()

func _apply_palette() -> void:
	if mat == null:
		return
	if high_contrast:
		var hc := Looks.high_contrast(look_id) if look_id != "" and not Looks.is_base(look_id) else PALETTES.alto_contraste
		mat.set_shader_parameter("paper", hc.paper)
		mat.set_shader_parameter("ink", hc.ink)
		mat.set_shader_parameter("grain", float(hc.get("grain", 0.0)))
	else:
		mat.set_shader_parameter("paper", _paper)
		mat.set_shader_parameter("ink", _ink)
		mat.set_shader_parameter("grain", _look.get("grain", _defaults.get("grain", null)))

func current_paper() -> Color:
	return mat.get_shader_parameter("paper")

func current_ink() -> Color:
	return mat.get_shader_parameter("ink")
