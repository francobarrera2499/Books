# ui/desk/clip_label.gd — texto recortable fuera del lector: examen de un objeto, líneas dichas (ARCHITECTURE §5.1, §6.4).
# Dueño: W3-SHELL. RichTextLabel armado con TextBuilder (W2-READER: get_parsed_text() == parsed.plain). Con la tijera
# (set_scissors(true)) se selecciona arrastrando; al soltar -> SelectionMapper.map -> cut_requested(src, from, len) y,
# si auto_act, Game.act({"t":"clip_text","src":src,…}) -> clipped(result) (ok o error: la línea de Lisle la pone quien
# lo hospeda). src = {"kind":"node","ref":"<lámina>/<nodo>"} o {"kind":"line","ref":<uid>}. Sin tijera no se
# selecciona nada (el texto no se resalta solo).
extends RichTextLabel

signal clipped(result: Dictionary)

const TextBuilder = preload("res://ui/reader/text_builder.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")

var parsed := {}
var src := {}
var slot := "imprenta"
var size_px := 0
var auto_act := true
var act_fn: Callable = Callable()
var scissors := false

func _init() -> void:
	bbcode_enabled = false
	fit_content = true
	scroll_active = false
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_enabled = false
	context_menu_enabled = false
	shortcut_keys_enabled = false
	drag_and_drop_selection_enabled = false
	threaded = false
	mouse_filter = Control.MOUSE_FILTER_PASS

func _ready() -> void:
	gui_input.connect(_on_input)

func setup(p_parsed: Dictionary, p_src: Dictionary, p_slot := "imprenta", p_size := 0) -> void:
	parsed = p_parsed
	src = p_src
	slot = p_slot
	size_px = p_size
	rebuild()

func rebuild() -> void:
	clear()
	theme_type_variation = TextBuilder.variation(slot)
	var o := {"slot": slot}
	if size_px > 0:
		o["size"] = size_px
	TextBuilder.build(self, parsed, o)

func set_scissors(on: bool) -> void:
	scissors = on and not src.is_empty()
	selection_enabled = scissors
	if not scissors:
		deselect()
	mouse_default_cursor_shape = Control.CURSOR_IBEAM if scissors else Control.CURSOR_ARROW

func _on_input(ev: InputEvent) -> void:
	if not scissors:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_try_cut.call_deferred()

func _try_cut() -> void:
	if get_selected_text() == "":
		return
	var m := SelectionMapper.map(self, parsed)
	deselect()
	if not bool(m.get("ok", false)):
		return
	if not auto_act:
		return
	var a := {"t": "clip_text", "src": src.duplicate(), "from": int(m.from), "len": int(m.len)}
	var r := {}
	if act_fn.is_valid():
		r = act_fn.call(a)
	else:
		var g = get_tree().root.get_node_or_null("Game")
		r = g.act(a) if g != null else {"ok": false, "err": "no_sim"}
	r["text"] = String(m.get("text", ""))
	clipped.emit(r)
