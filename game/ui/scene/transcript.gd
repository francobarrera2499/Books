# ui/scene/transcript.gd — las líneas dichas de una escena, recortables con la tijera (§6.7, GDD §8.1). Dueño: W3-SCENEUI.
# Uso: var tr = Transcript.new(link); tr.set_lines(uids, chars); tr.set_tijera(true)
#   link = SimLink (consultas q_line, acción clip_text). chars = q_scene().chars (rótulos de quien habla).
#   set_lines(uids, chars) agrega en orden las líneas nuevas (aparecen con un fundido de 0,3 s, escalonado) y quita las que
#   ya no están; clear() vacía. set_caption(text): epígrafe gris que se ve mientras no hay líneas.
#   set_tijera(on): selección habilitada (sólo en modo tijera, §6.4); al soltar el botón sobre una línea con texto
#   seleccionado -> SelectionMapper.map -> link.act({"t":"clip_text","src":{"kind":"line","ref":uid},"from","len"}).
# Señales: clipped(res, text, canvas_pos) (recorte aceptado) · failed(err) (código de error del sim) · tijera_changed(on).
# Cada línea: rótulo de quien habla (columna fija, lápiz) + RichTextLabel armado con TextBuilder (get_parsed_text() ==
# parsed.plain, condición del mapeo de la selección). Las frases de Lisle van en itálica y en lápiz.
# add_echo(who, text): fila LOCAL (no viene del sim, no es recortable, no figura en uids()): lo que Lisle mostró o calló
#   en la confrontación, que el sim no registra como línea dicha. Se agrega al final; las líneas nuevas del sim van después.
# Extras para tests/drivers: rows() -> [{uid, who, rtl, local}], rtl_of(uid), uids() (sólo líneas del sim).
extends VBoxContainer

signal clipped(res: Dictionary, text: String, canvas_pos: Vector2)
signal failed(err: String)
signal tijera_changed(on: bool)

const TextBuilder = preload("res://ui/reader/text_builder.gd")
const SelectionMapper = preload("res://ui/reader/selection_mapper.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")

const WHO_W := 168.0
const FADE_S := 0.3
const STAGGER_S := 0.14

var link
var tijera := false
var animate := true
var narration := false         # set_narration(on): todo como voz de Lisle (Park Lane)
var _row_target: Control = null
var _row_frames := 0
var scroll: ScrollContainer
var _list: VBoxContainer
var _caption: Label
var _rows: Array = []          # [{uid, who, row, rtl, parsed}]
var _chars: Array = []
var _busy := false

func _init(p_link = null) -> void:
	link = p_link if p_link != null else SimLink.new()
	name = "Transcripcion"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	scroll = ScrollContainer.new()
	scroll.name = "Rollo"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = false
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 9)
	scroll.add_child(_list)
	_caption = Widgets.caption("")
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.modulate = Color(1, 1, 1, 0.75)
	_caption.visible = false
	_list.add_child(_caption)

func _ready() -> void:
	var t := SimLink.ti()
	if t != null and not t.theme_changed.is_connected(_rebuild_all):
		t.theme_changed.connect(_rebuild_all)

func _exit_tree() -> void:
	var t := SimLink.ti()
	if t != null and t.theme_changed.is_connected(_rebuild_all):
		t.theme_changed.disconnect(_rebuild_all)
	_set_cursor(false)

# ------------------------------------------------------------------ API
func set_caption(text: String) -> void:
	_caption.text = text
	_caption.visible = text != "" and _rows.is_empty()

func clear() -> void:
	for r in _rows:
		r.row.queue_free()
	_rows.clear()
	_caption.visible = _caption.text != ""

func uids() -> Array:
	var out: Array = []
	for r in _rows:
		if not bool(r.get("local", false)):
			out.append(r.uid)
	return out

var _echo_n := 0
func add_echo(who: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	_echo_n += 1
	var r := _make_row("eco.%d" % _echo_n, who, {"plain": text, "styles": []}, true)
	_rows.append(r)
	_list.add_child(r.row)
	if animate:
		r.row.modulate.a = 0.0
		r.row.create_tween().tween_property(r.row, "modulate:a", 1.0, FADE_S)
	_relabel()
	_caption.visible = false
	_scroll_to_end.call_deferred()

func rows() -> Array:
	return _rows.duplicate()

# Narración (Park Lane, HC08): lo que Lisle ve en la calle lo cuenta Lisle; las acotaciones de otros (el caballero de
# luto, el anciano que tropieza) van como su voz, sin rótulo con el nombre (W4: «El doctor Watson» y «El librero viejo»
# resolvían lo que el texto deja en suspenso).
func set_narration(on: bool) -> void:
	if narration == on:
		return
	narration = on
	for r in _rows:
		r.who_label.text = link.who_label(disp_who(String(r.who)), _chars)
		_build_rtl(r)
	_relabel()

func disp_who(who: String) -> String:
	return "lisle" if narration and who != "" else who

func rtl_of(uid: String) -> RichTextLabel:
	for r in _rows:
		if r.uid == uid:
			return r.rtl
	return null

func set_lines(p_uids: Array, chars: Array = []) -> void:
	_chars = chars.duplicate(true)
	var want: Array = []
	for u in p_uids:
		want.append(String(u))
	# fuera las que ya no están (otra visita)
	var keep: Array = []
	for r in _rows:
		if want.has(r.uid) or bool(r.get("local", false)):
			keep.append(r)
		else:
			r.row.queue_free()
	_rows = keep
	var have := {}
	for r in _rows:
		have[r.uid] = true
	var added := 0
	var first_new: Control = null
	for u in want:
		if have.has(u):
			continue
		var ln: Dictionary = link.qd("q_line", [u])
		if ln.is_empty() or typeof(ln.get("parsed")) != TYPE_DICTIONARY or String(ln.parsed.get("plain", "")).strip_edges() == "":
			continue
		var r := _make_row(u, String(ln.get("who", "")), ln.parsed)
		_rows.append(r)
		_list.add_child(r.row)
		if first_new == null:
			first_new = r.row
		if animate:
			r.row.modulate.a = 0.0
			var tw: Tween = r.row.create_tween()
			tw.tween_interval(STAGGER_S * added)
			tw.tween_property(r.row, "modulate:a", 1.0, FADE_S)
		added += 1
	_relabel()
	_caption.visible = _caption.text != "" and _rows.is_empty()
	if added > 0:
		# a la PRIMERA línea nueva, no al final (W4: los nueve renglones de Mycroft llegaban juntos y sólo se veían los
		# cuatro últimos; el principio, su deducción sobre Lisle, quedaba arriba sin leer). Se lee hacia abajo con la rueda.
		_scroll_to_row.call_deferred(first_new)

# Los rótulos de quien habla pueden haber cambiado (alguien se presentó); como en un libreto, no se repite el rótulo de
# quien sigue hablando.
func _relabel() -> void:
	var prev := "<nadie>"
	for r in _rows:
		var dw := disp_who(String(r.who))
		r.who_label.text = link.who_label(dw, _chars) if dw != prev else ""
		prev = dw

func set_tijera(on: bool) -> void:
	if tijera == on:
		return
	tijera = on
	for r in _rows:
		_apply_tijera(r.rtl)
	_set_cursor(on)
	tijera_changed.emit(on)

func scroll_to_end() -> void:
	_scroll_to_end()

# ------------------------------------------------------------------ armado
func _make_row(uid: String, who: String, parsed: Dictionary, local := false) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wl := Label.new()
	wl.theme_type_variation = "SmallLabel"
	wl.custom_minimum_size = Vector2(WHO_W, 0)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wl.text = link.who_label(disp_who(who), _chars)
	row.add_child(wl)
	var rtl := TextBuilder.make_rtl("imprenta")
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.name = ("Eco_" if local else "Linea_") + uid.replace(".", "_")
	if local:
		rtl.set_meta("local", true)
	row.add_child(rtl)
	var r := {"uid": uid, "who": who, "row": row, "rtl": rtl, "parsed": parsed, "who_label": wl, "local": local}
	_build_rtl(r)
	if not local:
		rtl.gui_input.connect(_on_rtl_input.bind(uid))
	return r

func _build_rtl(r: Dictionary) -> void:
	var rtl: RichTextLabel = r.rtl
	var fs := int(round(SimLink.px("doc") * 0.92))
	TextBuilder.build(rtl, r.parsed, {"slot": "imprenta", "size": fs})
	rtl.add_theme_color_override("font_selected_color", Color(0, 0, 0, 0))
	var wl: Label = r.who_label
	wl.add_theme_font_size_override("font_size", SimLink.px("small"))
	if disp_who(String(r.who)) == "lisle":
		rtl.add_theme_font_override("normal_font", SimLink.font("imprenta", true))
		rtl.add_theme_color_override("default_color", Paper.ink("lapiz"))
		wl.add_theme_color_override("font_color", Paper.ink("tenue"))
	else:
		rtl.remove_theme_font_override("normal_font")
		rtl.add_theme_color_override("default_color", Paper.ink("negra"))
		wl.add_theme_color_override("font_color", Paper.ink("lapiz"))
	_apply_tijera(rtl)

func _apply_tijera(rtl: RichTextLabel) -> void:
	var on := tijera and not bool(rtl.get_meta("local", false))
	if not on:
		rtl.deselect()
	rtl.selection_enabled = on
	rtl.mouse_default_cursor_shape = Control.CURSOR_IBEAM if on else Control.CURSOR_ARROW

func _rebuild_all() -> void:
	for r in _rows:
		_build_rtl(r)

func _scroll_to_end() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree():
		var sb := scroll.get_v_scroll_bar()
		scroll.scroll_vertical = int(sb.max_value)

# La fila queda arriba de la ventana del rollo, con su renglón entero (nada cortado bajo el encabezado). Si todo lo
# nuevo cabe debajo de lo que ya se veía, se baja sólo lo necesario para mostrarlo entero.
func _scroll_to_row(row: Control) -> void:
	# dos cuadros después (alto real de las filas); por _process y no con await: la transcripción puede liberarse antes
	_row_target = row
	_row_frames = 2
	set_process(true)

func _process(_dt: float) -> void:
	if _row_frames <= 0:
		set_process(false)
		return
	_row_frames -= 1
	if _row_frames == 0:
		set_process(false)
		_do_scroll_to_row(_row_target)

func _do_scroll_to_row(row: Control) -> void:
	if not is_inside_tree() or row == null or not is_instance_valid(row):
		return
	var view_h := scroll.size.y
	var top := row.position.y
	var bottom := _list.get_combined_minimum_size().y
	var cur := float(scroll.scroll_vertical)
	var target := cur
	if bottom - cur > view_h:
		target = top if bottom - top > view_h else bottom - view_h
	if top < cur:
		target = top
	scroll.scroll_vertical = int(maxf(0.0, target))   # ScrollContainer acota al máximo

func scroll_pos() -> int:
	return scroll.scroll_vertical

# ------------------------------------------------------------------ tijera
func _on_rtl_input(ev: InputEvent, uid: String) -> void:
	if not tijera:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		var rtl := rtl_of(uid)
		if rtl == null:
			return
		if ev.pressed:
			for r in _rows:
				if r.uid != uid:
					(r.rtl as RichTextLabel).deselect()
		else:
			var pos: Vector2 = rtl.get_global_transform_with_canvas() * ev.position
			_try_clip.call_deferred(uid, pos)

func _try_clip(uid: String, pos: Vector2) -> void:
	if _busy:
		return
	var rtl := rtl_of(uid)
	if rtl == null:
		return
	var sel := rtl.get_selected_text()
	if sel == "":
		return
	var parsed: Dictionary = {}
	for r in _rows:
		if r.uid == uid:
			parsed = r.parsed
	var m := SelectionMapper.map(rtl, parsed)
	if not m.ok:
		rtl.deselect()
		failed.emit("no_cuadra")
		return
	_busy = true
	var res: Dictionary = link.act({"t": "clip_text", "src": {"kind": "line", "ref": uid}, "from": int(m.from), "len": int(m.len)})
	_busy = false
	rtl.deselect()
	if bool(res.get("ok", false)):
		var txt := String(res.get("text", ""))
		if txt == "" and res.has("clip"):
			txt = String(link.qd("q_clip", [String(res.clip)]).get("text", ""))
		if txt == "":
			txt = SelectionMapper.preview(parsed, int(m.from), int(m.len)).text
		link.play("sfx.tijera")
		clipped.emit(res, txt, pos)
	else:
		failed.emit(String(res.get("err", "")))

# Recorta [from, from+len) de la línea uid sin mouse (drivers y tests).
func clip_range(uid: String, from: int, length: int) -> Dictionary:
	var res: Dictionary = link.act({"t": "clip_text", "src": {"kind": "line", "ref": uid}, "from": from, "len": length})
	if bool(res.get("ok", false)):
		clipped.emit(res, String(res.get("text", "")), global_position + size * 0.5)
	else:
		failed.emit(String(res.get("err", "")))
	return res

var _cursor_set := false
func _set_cursor(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if on:
		var tex = load("res://ui/reader/document_reader.gd").scissors_texture()
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_IBEAM, Vector2(3, 3))
		_cursor_set = true
	elif _cursor_set:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
		_cursor_set = false
