# ui/desk/examine_card.gd — epígrafe de un objeto examinado (GDD§5 «todo lo visible se puede examinar», §14.5 láminas
# de Paget). Dueño: W3-SHELL. Tarjeta de papel abajo al centro: sustantivo, examen neutro (recortable con la tijera,
# src node) y, si el objeto sirve para algo, enlaces en tinta (abrir, leer, bajar…). Mismo trato para todo objeto:
# nada distingue lo importante. show_card(title, parsed, links, src) · hide_card() · set_scissors(on).
# links = [{text, cb: Callable, disabled?: bool}]. Pocos enlaces van en una fila; muchos (los tomos de la Strand, un
# estante) van en lista, uno por renglón, bajo un encabezado (head) y en un desplazable de alto acotado: la tarjeta
# nunca se sale de la pantalla.
# v2 (GDD_v2 §C.1/§C.3): note = una línea chica no recortable bajo el examen; las listas largas nunca pasan de ≤7
# renglones a la vista.
# v3 (GDD_v3 §6.2, §6.7): todo lo del 3D se recorta del texto de esta tarjeta. La tijera es un ícono suelto (sin
# recuadro ni la palabra) arriba a la derecha de la tarjeta, cuando la tijera existe para Lisle (scissors_ok) y hay texto
# recortable: clic -> scissors_toggled(on) (la pantalla de juego la toma o la deja, como C).
extends PanelContainer

signal clipped(result: Dictionary)
signal closed
signal scissors_toggled(on: bool)

const Cursors = preload("res://ui/desk/cursors.gd")

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")
const ClipLabel = preload("res://ui/desk/clip_label.gd")

const MAX_W := 620.0
const LIST_FROM := 4            # desde cuántos enlaces van en lista
const LIST_MAX_H := 280.0       # alto máximo de la lista (unos ocho renglones); el resto, con la rueda
const TOP_GAP := 24.0

var title_label: Label
var body: RichTextLabel
var links_box: HFlowContainer
var links_head: Label
var links_scroll: ScrollContainer
var links_list: VBoxContainer
var note_label: Label
var node_id := ""
var scissors_btn: TextureButton
var scissors_ok: Callable = Callable()   # () -> bool: ¿la tijera ya está en la mano de Lisle? (desk.tijera)
var _scissors_on := false
var bottom_inset := 0.0:        # alto que tapa una banda de abajo (panel de escena): la tarjeta va encima
	set(v):
		bottom_inset = v
		if visible and is_inside_tree():
			_place()
var _tw: Tween = null

func _init() -> void:
	name = "ExamineCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 20, "shadow": true, "shadow_size": 10})))

func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	title_label = Widgets.label("", "SourceLine")
	title_label.uppercase = true
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	scissors_btn = TextureButton.new()
	scissors_btn.name = "Tijera"
	scissors_btn.texture_normal = Cursors.scissors_icon(28)
	scissors_btn.ignore_texture_size = true
	scissors_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	scissors_btn.custom_minimum_size = Vector2(28, 28)
	scissors_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	scissors_btn.focus_mode = Control.FOCUS_NONE
	scissors_btn.tooltip_text = "C"
	scissors_btn.visible = false
	scissors_btn.pressed.connect(func(): scissors_toggled.emit(not _scissors_on))
	head.add_child(scissors_btn)
	body = ClipLabel.new()
	body.custom_minimum_size = Vector2(MAX_W - 40.0, 0)
	body.clipped.connect(func(r): clipped.emit(r))
	v.add_child(body)
	note_label = Widgets.label("", "Caption")
	note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_label.visible = false
	v.add_child(note_label)
	links_box = HFlowContainer.new()
	links_box.add_theme_constant_override("h_separation", 18)
	links_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(links_box)
	links_head = Widgets.label("", "SourceLine")
	links_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	links_head.visible = false
	v.add_child(links_head)
	links_scroll = ScrollContainer.new()
	links_scroll.name = "Enlaces"
	links_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	links_scroll.visible = false
	v.add_child(links_scroll)
	links_list = VBoxContainer.new()
	links_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	links_list.add_theme_constant_override("separation", 0)
	links_scroll.add_child(links_list)
	get_viewport().size_changed.connect(_place)

func _place() -> void:
	var vs := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1600, 900)
	if links_scroll.visible:
		# la lista se acota al alto libre (encima de la banda de abajo, debajo del borde) y se desplaza con la rueda
		links_scroll.custom_minimum_size.y = 0.0
		var need := minf(links_list.get_combined_minimum_size().y, LIST_MAX_H)
		links_scroll.custom_minimum_size.y = need
		reset_size()
		var free := vs.y - 34.0 - bottom_inset - TOP_GAP
		var over := size.y - free
		if over > 0.0:
			links_scroll.custom_minimum_size.y = maxf(120.0, need - over)
	reset_size()
	var w := minf(MAX_W, vs.x - 80.0)
	size.x = w
	position = Vector2((vs.x - w) * 0.5, maxf(TOP_GAP, vs.y - size.y - 34.0 - bottom_inset))

func show_card(p_title: String, parsed: Dictionary, links: Array, src := {}, p_node := "", head := "", note := "") -> void:
	node_id = p_node
	title_label.text = p_title
	title_label.visible = true
	(body as ClipLabel).setup(parsed, src)
	body.visible = String(parsed.get("plain", "")) != ""
	scissors_btn.visible = body.visible and not src.is_empty() and (not scissors_ok.is_valid() or bool(scissors_ok.call()))
	_paint_scissors()
	note_label.text = note
	note_label.visible = note != ""
	for c in links_box.get_children() + links_list.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	var as_list := links.size() >= LIST_FROM
	for l in links:
		var txt := String(l.get("short", l.get("text", ""))) if as_list else String(l.get("text", ""))
		var b := Widgets.ink_button(txt)
		b.disabled = bool(l.get("disabled", false))
		var cb: Callable = l.get("cb", Callable())
		if cb.is_valid():
			b.pressed.connect(cb)
		if as_list:
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.clip_text = true
			links_list.add_child(b)
		else:
			links_box.add_child(b)
	links_box.visible = not links.is_empty() and not as_list
	links_scroll.visible = as_list
	links_scroll.scroll_vertical = 0
	links_head.text = head
	links_head.visible = as_list and head != ""
	visible = true
	modulate.a = 0.0
	_place.call_deferred()
	_replace_later()
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = Widgets.fade(self, 1.0, 0.18)

# El texto (RichTextLabel con fit_content) mide su alto recién después del primer acomodo: se vuelve a ubicar un cuadro
# más tarde (si no, una tarjeta corta quedaba con el alto de la anterior).
func _replace_later() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if visible and is_inside_tree():
		_place()

func hide_card() -> void:
	if not visible:
		return
	visible = false
	node_id = ""
	(body as ClipLabel).set_scissors(false)
	closed.emit()

func set_scissors(on: bool) -> void:
	_scissors_on = on
	if body != null:
		(body as ClipLabel).set_scissors(on)
	_paint_scissors()

# Con la tijera en la mano el ícono se ve «tomado» (tinta llena); si no, tenue.
func _paint_scissors() -> void:
	if scissors_btn == null:
		return
	scissors_btn.modulate = Color(1, 1, 1, 1.0) if _scissors_on else Color(1, 1, 1, 0.62)
	scissors_btn.rotation_degrees = -18.0 if _scissors_on else 0.0
	scissors_btn.pivot_offset = scissors_btn.custom_minimum_size * 0.5

func back() -> bool:
	if visible:
		hide_card()
		return true
	return false
