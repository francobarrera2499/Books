# ui/layers.gd — capas de la pantalla (ARCHITECTURE §2.3). Dueño: W3-SHELL. Estática.
# Números de CanvasLayer del contrato y fábricas mínimas. El 3D (WorldRoot) no es capa: vive debajo de todas.
#   5 DropCatcher3D · 10 HUD · 20 libros (cuaderno, libro mayor) · 30 lector (DocumentReader es su propia capa) ·
#   40 escena · 50 mapa · 60 modal (compositores, confirmaciones) · 90 subtítulos · 100 fundido · 120 arrastre.
extends RefCounted

const DROP := 5
const HUD := 10
const BOOKS := 20
const READER := 30
const SCENE := 40
const MAP := 50
const MODAL := 60
const SUBS := 90
const FADE := 100
const DRAG := 120

const ALL := {"drop": DROP, "hud": HUD, "books": BOOKS, "reader": READER, "scene": SCENE, "map": MAP, "modal": MODAL,
	"subs": SUBS, "fade": FADE, "drag": DRAG}

# CanvasLayer con un Control raíz a pantalla completa que no come el mouse (los hijos deciden).
static func make(parent: Node, n: int, p_name: String) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.layer = n
	cl.name = p_name
	parent.add_child(cl)
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(root)
	return cl

static func root_of(cl: CanvasLayer) -> Control:
	return cl.get_node_or_null("Root") as Control

static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c

# Tamaño del área visible del canvas (con stretch canvas_items es el tamaño de diseño ajustado a la ventana).
static func vp_size(n: Node) -> Vector2:
	if n != null and n.is_inside_tree():
		return n.get_viewport().get_visible_rect().size
	return Vector2(1600, 900)
