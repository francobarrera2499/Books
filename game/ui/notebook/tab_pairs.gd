# ui/notebook/tab_pairs.gd — pestaña Cotejos (los pares, GDD§8.3). Dueño: W3-NOTEBOOK. Contrato: ARCHITECTURE §6.5.
# Cada par: sus dos tiras unidas por un sujetapapeles, sus líneas de fuente y la nota libre a lápiz. Se arrastra como
# {"kind":"pair","id"} (ranura «según» del libro mayor, presentar). «Separar» pide confirmación (unlink quita el par de los
# asientos a lápiz; en tinta el sim lo impide). Soltar un recorte sobre un par: el sim responde (no se anidan). Nada valida
# un par: es privado (GDD§8.3).
extends VBoxContainer

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const ClipCard = preload("res://ui/notebook/clip_card.gd")

var nb
var scissors := false
var _scroll: ScrollContainer
var _list: VBoxContainer
var _cards := {}
var _empty: Label

# Sujetapapeles a lápiz entre las dos tiras.
class Clasp extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(26, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	func _draw() -> void:
		var c := Paper.ink("lapiz")
		var x := size.x * 0.5
		var pts := PackedVector2Array([Vector2(x - 4, 38), Vector2(x - 4, 8), Vector2(x, 3), Vector2(x + 4, 8), Vector2(x + 4, 34),
			Vector2(x + 1, 37), Vector2(x - 1, 34), Vector2(x - 1, 12)])
		draw_polyline(pts, c, 1.4, true)
		draw_line(Vector2(2, 22), Vector2(size.x - 2, 22), Color(c, 0.35), 1.0)

class PairCard extends VBoxContainer:
	var nb
	var pair := {}
	var id := ""
	func _init(p_nb, p_pair: Dictionary) -> void:
		nb = p_nb
		pair = p_pair
		id = String(pair.get("id", ""))
		name = "Par_" + id
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_theme_constant_override("separation", 4)
	func _get_drag_data(_at: Vector2):
		var txt := "%s · %s" % [_short(pair.get("_a", {})), _short(pair.get("_b", {}))]
		if is_inside_tree() and get_viewport().gui_is_dragging():
			set_drag_preview(Widgets.chip(txt, {"kind": "pair", "id": id}))
		return {"kind": "pair", "id": id}
	static func _short(c: Dictionary) -> String:
		var a := String(c.get("text", ""))
		if a == "":
			a = String(c.get("caption", ""))
		return "«" + (a.left(20).strip_edges() + "…" if a.length() > 20 else a) + "»"
	func _can_drop_data(_at: Vector2, data) -> bool:
		return typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) in ["clip", "pair"] and String(data.get("id", "")) != id
	func _drop_data(_at: Vector2, data) -> void:
		nb.request_link(String(data.get("id", "")), id)

func _init(p_nb) -> void:
	nb = p_nb
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll = nb.scroll_box()
	_scroll.name = "Lista"
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 22)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list)

func refresh() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_cards.clear()
	var by := {}
	for c in nb.clips():
		by[String(c.id)] = c
	var pairs = nb.q("q_pairs")
	if not pairs is Array:
		pairs = []
	var wide: bool = nb.is_wide()
	var bw: float = nb.body_width()
	var sw: float = minf(nb.STRIP_W * nb._scale(), (bw - 40.0) * 0.5) if wide else minf(bw - 8.0, nb.strip_width(false))
	for p in pairs:
		var ca: Dictionary = by.get(String(p.get("a", "")), {})
		var cb: Dictionary = by.get(String(p.get("b", "")), {})
		if ca.is_empty() or cb.is_empty():
			continue
		var pp: Dictionary = p.duplicate()
		pp["_a"] = ca
		pp["_b"] = cb
		var card := PairCard.new(nb, pp)
		var strips: Container = HBoxContainer.new() if wide else VBoxContainer.new()
		strips.add_theme_constant_override("separation", 6 if wide else 10)
		strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cols := [ca, cb]
		for i in 2:
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 2)
			col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var s := ClipCard.strip_for(nb, cols[i], sw)
			s.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			col.add_child(s)
			var src := Widgets.source_line(String(cols[i].get("src_line", "")))
			src.custom_minimum_size = Vector2(sw, 0)
			src.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(src)
			strips.add_child(col)
			if i == 0 and wide:
				strips.add_child(Clasp.new())
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 12)
		foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var note_text := String(p.get("note", "")).strip_edges()
		var note := Widgets.marginal(note_text if note_text != "" else nb.t("nb.cotejo.sin_nota"))
		note.add_theme_font_size_override("font_size", nb._px("ui"))
		note.name = "Nota"
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if note_text == "":
			note.add_theme_color_override("font_color", Paper.ink("tenue"))
		foot.add_child(note)
		var pid := String(p.get("id", ""))
		var sep := Widgets.ink_button(nb.t("nb.cotejo.separar"), func(): nb.request_unlink(pid))
		sep.name = "Separar"
		sep.add_theme_font_size_override("font_size", nb._px("small"))
		foot.add_child(sep)
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(strips)
		inner.add_child(foot)
		# angosto (acoplado junto al libro mayor): las dos tiras van una bajo la otra y el sujetapapeles pasa al margen,
		# para que se vea qué dos tiras forman el par
		var margin: Control = null
		if not wide:
			var holder := HBoxContainer.new()
			holder.name = "Sujetapapeles"
			holder.alignment = BoxContainer.ALIGNMENT_END
			holder.add_child(Clasp.new())
			margin = holder
		card.add_child(nb.margin_row(margin, inner))
		_list.add_child(card)
		_cards[pid] = card
	if _cards.is_empty():
		_empty = nb.empty_line(nb.t("nb.vacio.cotejos"))
		_list.add_child(nb.margin_row(null, _empty))
	else:
		_empty = null
	_restore.call_deferred(keep)

func _restore(v: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = v

func card(id: String):
	return _cards.get(id)

func debug_state() -> Dictionary:
	return {"pairs": _cards.keys(), "empty": _empty.text if _empty != null else ""}
