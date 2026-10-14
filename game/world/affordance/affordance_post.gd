# world/affordance/affordance_post.gd — quad del contorno bajo el mouse (GDD_v3 §6.5). Dueño: UI-MUNDO.
# MeshInstance3D con QuadMesh 2x2 colgado de la cámara (mismo patrón que world/post/engraving_post.gd, que no se toca):
# dibuja affordance.gdshader DESPUÉS del look (misma render_priority máxima, sorting_offset mayor) leyendo sólo el
# buffer normal_roughness. Capa de render 20 (como el look): una cámara de miniaturas la excluye.
# API: attach(cam) -> nodo · find(cam) · set_high_contrast(on) · set_param(n, v) · param(n).
extends MeshInstance3D

const NODE_NAME := "AffordancePost"
const LAYER := 1 << 19
const SHADER := "res://world/affordance/affordance.gdshader"

var mat: ShaderMaterial

static func attach(cam: Camera3D) -> MeshInstance3D:
	var ex := cam.get_node_or_null(NODE_NAME) as MeshInstance3D
	if ex != null:
		return ex
	var n: MeshInstance3D = load("res://world/affordance/affordance_post.gd").new()
	cam.add_child(n)
	return n

static func find(cam: Camera3D) -> MeshInstance3D:
	return cam.get_node_or_null(NODE_NAME) as MeshInstance3D if cam != null else null

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
	sorting_offset = 50.0   # encima del look (que también está en la prioridad máxima)
	mat = ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.render_priority = Material.RENDER_PRIORITY_MAX
	material_override = mat

func _ready() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and "high_contrast" in ti:
		set_high_contrast(bool(ti.high_contrast))
		if ti.has_signal("theme_changed") and not ti.theme_changed.is_connected(_on_theme):
			ti.theme_changed.connect(_on_theme)

func _on_theme() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and "high_contrast" in ti:
		set_high_contrast(bool(ti.high_contrast))

func set_high_contrast(on: bool) -> void:
	mat.set_shader_parameter("high_contrast", on)

func set_param(n: String, v) -> void:
	mat.set_shader_parameter(n, v)

func param(n: String):
	return mat.get_shader_parameter(n)
