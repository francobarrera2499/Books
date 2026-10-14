# ui/scene/confrontation_view.gd — la confrontación con el librero (día 10, tienda de Crane; GDD §8.8, ARCHITECTURE §5.7,
# §6.7; T18). Dueño: W3-SCENEUI. CanvasLayer propio (capa 40). Al estilo Ace Attorney:
#   - arriba, la afirmación vigente del librero (q_confront().statement), con su número romano (I–IV);
#   - a su lado, la paciencia a la vista: el paquete y el sombrero sobre el mostrador (1.er error: recoge el paquete;
#     2.º: se pone el sombrero; 3.º: se va). Se dibujan por código; desaparecen con una animación de 0,4 s;
#   - «Refutar…»: selector de recortes y asientos -> 2.º paso con la frase de Lisle -> «Mostrar» / «Guardar»;
#     también se puede soltar un recorte o asiento sobre la afirmación (DnD §6.3);
#   - «Callar»: dos pasos («Dejar pasar lo que dice» -> «Callar» / «Volver»); callar no es error;
#   - abajo, la transcripción (líneas de origen S.HC07, recortables con la tijera) con lo que Lisle mostró o calló como
#     filas locales (Transcript.add_echo: el sim no lo registra; no recortables; se pierden al recargar la partida);
#   - terminada (cuatro aciertos, tres errores o la última afirmación), «Seguir» emite finished: Shell vuelve al escritorio
#     (la fase ya es final_report).
# Uso (Shell): var cv = preload("res://ui/scene/confrontation_view.gd").new(); add_child(cv); cv.refresh()
#   refresh() · refute(item) -> bool (2.º paso) · ask_silence() · confirm_silence() · debug_state()
# Config: sim, act_fn, sounds, handle_keys (como ScenePanel). Señales: finished · answered(res) · clipped(res) · closed.
# Protocolo de la pila de Shell: open() · close() · back() -> bool (selector, 2.º paso, callar pendiente o tijera) ·
#   handle_back (= handle_keys) · toggle_tijera() / tijera. «Seguir» emite finished y cierra.
# GDD_v2 §C.3: el selector lista primero las conclusiones confirmadas y después los recortes, lo más reciente primero
#   (ItemPicker merged); «Tijera» con desk.tijera.
extends CanvasLayer

signal finished
signal answered(res: Dictionary)
signal clipped(res: Dictionary)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")
const Transcript = preload("res://ui/scene/transcript.gd")
const ItemPicker = preload("res://ui/scene/item_picker.gd")
const PresentBar = preload("res://ui/scene/present_bar.gd")
const LisleNote = preload("res://ui/scene/lisle_note.gd")
const TextBuilder = preload("res://ui/reader/text_builder.gd")

const LAYER := 40
const WHO := "librero"
const ORIGIN := "S.HC07"
const BAND_H := 236.0
const MARGIN := 24.0
const BANNER_W := 1060.0
const ROMAN := ["", "I", "II", "III", "IV", "V"]

# El mostrador con lo que el librero todavía no recogió (paciencia a la vista).
class Patience extends Control:
	var items := {"paquete": 1.0, "sombrero": 1.0}   # 1 = sobre el mostrador; 0 = recogido
	var lift := {"paquete": 0.0, "sombrero": 0.0}
	var caption := ""
	func _init() -> void:
		custom_minimum_size = Vector2(196, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func set_present(present: Array, animate := true) -> void:
		for k in items:
			var want := 1.0 if present.has(k) else 0.0
			if is_equal_approx(items[k], want):
				continue
			if animate and is_inside_tree() and want < items[k]:
				var tw := create_tween()
				tw.set_parallel(true)
				tw.tween_method(func(v): items[k] = v; queue_redraw(), items[k], want, 0.4)
				tw.tween_method(func(v): lift[k] = v; queue_redraw(), 0.0, 1.0, 0.4)
			else:
				items[k] = want
				lift[k] = 0.0 if want > 0.0 else 1.0
		queue_redraw()
	func _draw() -> void:
		var hc := Paper.hc_on()
		var ink := Paper.ink("negra")
		var wood := Color("6b5238") if not hc else Color(0, 0, 0)
		var brown := Color("b08a5a") if not hc else Color(0.85, 0.85, 0.85)
		var y := size.y - 22.0
		# mostrador: tabla con canto
		draw_rect(Rect2(Vector2(4, y), Vector2(size.x - 8, 5)), wood)
		draw_line(Vector2(4, y + 9), Vector2(size.x - 4, y + 9), Color(wood, 0.6), 1.0)
		# paquete atado con hilo
		var a: float = items["paquete"]
		if a > 0.01:
			var up: float = lift["paquete"] * 26.0
			var r := Rect2(Vector2(26, y - 34 - up), Vector2(62, 34))
			draw_rect(r, Color(brown, a))
			draw_rect(r, Color(ink, a), false, 1.5)
			draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y), Color(ink, a), 1.2)
			draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.5), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Color(ink, a), 1.2)
			var c := Vector2(r.position.x + r.size.x * 0.5, r.position.y)
			draw_arc(c + Vector2(-6, -4), 5.0, 0.0, TAU, 12, Color(ink, a), 1.2)
			draw_arc(c + Vector2(6, -4), 5.0, 0.0, TAU, 12, Color(ink, a), 1.2)
		# sombrero de copa baja, gastado
		var b: float = items["sombrero"]
		if b > 0.01:
			var up2: float = lift["sombrero"] * 30.0
			var bx := 118.0
			var by := y - up2
			var brim := PackedVector2Array([Vector2(bx - 4, by - 2), Vector2(bx + 62, by - 2), Vector2(bx + 58, by - 8), Vector2(bx, by - 8)])
			draw_colored_polygon(brim, Color(ink, b))
			var crown := PackedVector2Array([Vector2(bx + 10, by - 8), Vector2(bx + 48, by - 8), Vector2(bx + 45, by - 36), Vector2(bx + 13, by - 36)])
			draw_colored_polygon(crown, Color(ink, b))
			draw_line(Vector2(bx + 11, by - 14), Vector2(bx + 47, by - 14), Color(brown if not hc else Color(1, 1, 1), b * 0.8), 2.0)
		if caption != "":
			var f := get_theme_font("font", "SourceLine")
			var fs := get_theme_font_size("font_size", "SourceLine")
			draw_string(f, Vector2(4, size.y - 1), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, fs, Paper.ink("lapiz"))

var link
var shell = null
var handle_keys := true
var animate := true              # false: la paciencia cambia sin tween (tests)
var strip_target := Vector2(-1, -1)
var status := {}
var root: Control
var banner: PanelContainer
var band: PanelContainer         # la transcripción al pie (el Shell, el cuaderno y el libro mayor se acomodan arriba de ella)
var transcript
var picker
var confirm_bar
var note
var patience: Patience
var _roman: Label
var _who: Label
var _quote: RichTextLabel
var _buttons: HBoxContainer
var _silence_row: HBoxContainer
var _b_refute: Button
var _b_silence: Button
var _b_follow: Button
var _title: Label
var _tijera_btn: BaseButton
var _plate_btn: Button
var _fly: Control
var _refresh_queued := false
var _connected := false
var _first := true

var sim:
	get: return link.sim_override
	set(v): link.sim_override = v
var act_fn: Callable:
	get: return link.act_fn
	set(v): link.act_fn = v
var sounds: bool:
	get: return link.sounds
	set(v): link.sounds = v
var handle_back: bool:
	get: return handle_keys
	set(v): handle_keys = v
var tijera: bool:
	get: return transcript != null and transcript.tijera

func _init() -> void:
	layer = LAYER
	name = "ConfrontationView"
	link = SimLink.new()
	_build()

func _ready() -> void:
	if link.uses_game():
		var g := SimLink.autoload("Game")
		if g != null and g.has_signal("sim_changed"):
			g.sim_changed.connect(_on_sim_changed)
			_connected = true
	refresh()

func _exit_tree() -> void:
	var g := SimLink.autoload("Game")
	if _connected and g != null and g.sim_changed.is_connected(_on_sim_changed):
		g.sim_changed.disconnect(_on_sim_changed)
	_connected = false

func _on_sim_changed(kind: String, _p: Dictionary) -> void:
	if ["confront", "line", "clock", "scene", "visit"].has(kind) and not _refresh_queued:
		_refresh_queued = true
		(func():
			_refresh_queued = false
			refresh()).call_deferred()

# ------------------------------------------------------------------ armado
func _build() -> void:
	root = Control.new()
	root.name = "Raiz"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	# --- la afirmación
	banner = Widgets.sheet("strand", {"pad": 26})
	banner.name = "Afirmacion"
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -BANNER_W * 0.5
	banner.offset_right = BANNER_W * 0.5
	banner.offset_top = MARGIN + 6.0
	banner.custom_minimum_size = Vector2(BANNER_W, 0)
	root.add_child(banner)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 22)
	banner.add_child(bh)
	_roman = Widgets.heading("")
	_roman.custom_minimum_size = Vector2(64, 0)
	_roman.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roman.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bh.add_child(_roman)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	bh.add_child(mid)
	_who = Widgets.small("")
	_who.uppercase = true
	mid.add_child(_who)
	_quote = TextBuilder.make_rtl("imprenta")
	_quote.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_quote)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 18)
	_b_silence = Widgets.ink_button(link.t("sceneui.conf.callar"), ask_silence)
	_b_refute = Widgets.button(link.t("sceneui.conf.refutar"), open_refute)
	_b_follow = Widgets.button(link.t("sceneui.conf.seguir"), _on_follow)
	_buttons.add_child(_b_silence)
	_buttons.add_child(_b_refute)
	_buttons.add_child(_b_follow)
	mid.add_child(_buttons)
	_silence_row = HBoxContainer.new()
	_silence_row.alignment = BoxContainer.ALIGNMENT_END
	_silence_row.add_theme_constant_override("separation", 18)
	var sq := Label.new()
	sq.text = link.t("sceneui.conf.callar.confirm")
	sq.theme_type_variation = "Caption"
	_silence_row.add_child(sq)
	_silence_row.add_child(Widgets.ink_button(link.t("sceneui.back"), cancel_silence))
	_silence_row.add_child(Widgets.button(link.t("sceneui.conf.callar"), confirm_silence))
	_silence_row.visible = false
	mid.add_child(_silence_row)
	patience = Patience.new()
	patience.caption = link.t("sceneui.conf.mostrador")
	patience.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bh.add_child(patience)
	# --- la transcripción
	band = Widgets.sheet("cuaderno", {"pad": 22})
	band.name = "Banda"
	band.mouse_filter = Control.MOUSE_FILTER_STOP
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = MARGIN
	band.offset_right = -MARGIN
	band.offset_top = -(BAND_H + MARGIN)
	band.offset_bottom = -MARGIN
	root.add_child(band)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	band.add_child(bv)
	var head := HBoxContainer.new()
	_title = Widgets.source_line("")
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_title)
	_tijera_btn = preload("res://ui/desk/cursors.gd").scissors_button(26)   # GDD_v3 §6.7: ícono suelto
	_tijera_btn.toggled.connect(func(on): transcript.set_tijera(on))
	# la tienda del día 10 también se recorta (sus dedos y su sombra, GDD §8.8 IV): rectángulo sobre la lámina, como en
	# cualquier visita (W4: sólo se podía después, desde «Láminas de lo visto»)
	_plate_btn = Widgets.ink_button(link.t("sceneui.conf.lamina"), _plate_scissors)
	_plate_btn.name = "TijeraLamina"
	head.add_child(_plate_btn)
	head.add_child(_tijera_btn)
	bv.add_child(head)
	transcript = Transcript.new(link)
	transcript.clipped.connect(_on_clipped)
	transcript.failed.connect(func(e): note.say(link.t("reader.no_cuadra") if e == "no_cuadra" else link.err_text(e)))
	transcript.tijera_changed.connect(func(on): preload("res://ui/desk/cursors.gd").paint_scissors(_tijera_btn, on))
	bv.add_child(transcript)
	# --- subpaneles
	picker = ItemPicker.new(link)
	picker.picked.connect(func(it): refute(it))
	_dock(picker, 640.0)
	confirm_bar = PresentBar.new(link)
	confirm_bar.done.connect(func(res): _on_answered(res, confirm_bar.phrase()))
	confirm_bar.failed.connect(func(e): note.say(link.err_text(e)); refresh())
	_dock(confirm_bar, 760.0)
	note = LisleNote.new()
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = MARGIN + 18.0
	note.offset_bottom = -(BAND_H + MARGIN + 12.0)
	note.offset_top = note.offset_bottom
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(note)
	_fly = Control.new()
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fly)
	banner.set_drag_forwarding(Callable(), _banner_can_drop, _banner_drop)
	Widgets.restyle(banner, _restyle_quote)

func _dock(c: Control, w: float) -> void:
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_right = -MARGIN
	c.offset_left = -MARGIN - w
	c.offset_bottom = -(BAND_H + MARGIN + 12.0)
	c.offset_top = c.offset_bottom
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.custom_minimum_size = Vector2(w, 0)
	root.add_child(c)

func _restyle_quote() -> void:
	_quote_text(String(_quote.get_meta("raw", "")))

# ------------------------------------------------------------------ API
func open() -> void:
	visible = true
	refresh()

func close() -> void:
	picker.close()
	confirm_bar.visible = false
	cancel_silence()
	transcript.set_tijera(false)
	if visible:
		visible = false
		closed.emit()

func back() -> bool:
	if picker.visible:
		picker.close()
		return true
	if confirm_bar.visible:
		confirm_bar.keep()
		return true
	if _silence_row.visible:
		cancel_silence()
		return true
	if transcript.tijera:
		transcript.set_tijera(false)
		return true
	# mientras dura la confrontación no hay adónde volver: el librero espera
	return not bool(status.get("done", false))

func toggle_tijera() -> void:
	transcript.set_tijera(not transcript.tijera)

# Tijera de rectángulo sobre la lámina de la tienda (la de la pantalla de juego); sin pantalla de juego no hace nada.
func _plate_scissors() -> void:
	var gs = shell.game_screen if shell != null and is_instance_valid(shell) and "game_screen" in shell else null
	if gs == null or not gs.has_method("set_scissors"):
		return
	transcript.set_tijera(false)
	picker.close()
	gs.set_scissors(not bool(gs.scissors_on))

func refresh() -> void:
	status = link.qd("q_confront")
	var done := bool(status.get("done", false))
	var step := int(status.get("step", 0))
	var stmt = status.get("statement", {})
	var sc: Dictionary = link.qd("q_scene")
	var chars: Array = sc.get("chars", [])
	# el librero no se presenta: «Anciano encorvado» toda la escena (W4: el rótulo pasaba a «El librero viejo» a mitad de
	# la confrontación, en cuanto algo lo ponía en el índice)
	var r = link.repo()
	if r != null and not link.who_override.has(WHO):
		var noun := String(r.entity(WHO).get("noun", ""))
		if noun != "":
			link.who_override[WHO] = noun
	_who.text = link.who_label(WHO, chars)
	var raw := ""
	if typeof(stmt) == TYPE_DICTIONARY and not stmt.is_empty():
		raw = String(stmt.get("text", ""))
	elif done:
		raw = _last_librero_text()
	_quote_text(raw)
	_roman.text = ROMAN[clampi(step, 0, ROMAN.size() - 1)] if not done else ""
	patience.set_present(status.get("patience", ["paquete", "sombrero"]), animate and not _first)
	_first = false
	_b_refute.visible = not done
	_b_silence.visible = not done
	_b_follow.visible = done
	if done:
		_silence_row.visible = false
		picker.close()
		confirm_bar.visible = false
	_buttons.visible = not _silence_row.visible
	transcript.set_lines(_uids(), chars)
	_title.text = _title_text()
	_tijera_btn.visible = link.flag("desk.tijera")

func open_refute() -> void:
	if bool(status.get("done", false)):
		return
	cancel_silence()
	confirm_bar.visible = false
	picker.open(link.t("sceneui.conf.picker"), ["pregunta", "clip"], {"merged": true})
	picker.fit_height(_free_height())

# Alto libre entre la afirmación (arriba) y la banda de la transcripción (abajo): el selector no tapa la afirmación ni
# sus botones aunque ésta ocupe dos líneas. 0 = sin medida (fuera del árbol).
func _free_height() -> float:
	if not root.is_inside_tree() or root.size.y <= 0.0:
		return 0.0
	var top := banner.position.y + banner.size.y + 14.0
	var bottom := root.size.y - (BAND_H + MARGIN + 12.0)
	return maxf(bottom - top, 0.0)

func refute(item: Dictionary) -> bool:
	if bool(status.get("done", false)) or not ["clip", "pregunta"].has(String(item.get("kind", ""))):
		return false
	picker.close()
	cancel_silence()
	confirm_bar.open_confront(int(status.get("step", 1)), WHO, _who_cap(), item)
	return true

func ask_silence() -> void:
	if bool(status.get("done", false)):
		return
	picker.close()
	confirm_bar.visible = false
	_silence_row.visible = true
	_buttons.visible = false

func cancel_silence() -> void:
	_silence_row.visible = false
	_buttons.visible = true

func confirm_silence() -> void:
	cancel_silence()
	var res: Dictionary = link.act({"t": "confront", "step": int(status.get("step", 1)), "item": {}})
	if bool(res.get("ok", false)):
		_on_answered(res, link.t("sceneui.conf.eco.callar"))
	else:
		note.say(link.err_text(String(res.get("err", ""))))
		refresh()

func debug_state() -> Dictionary:
	return {"step": int(status.get("step", 0)), "errors": int(status.get("errors", 0)), "done": bool(status.get("done", false)),
		"patience": patience.items.duplicate(), "quote": String(_quote.get_parsed_text()), "lines": transcript.uids(),
		"silence_pending": _silence_row.visible, "picker": picker.visible, "confirm": confirm_bar.visible, "note": note.text()}

# ------------------------------------------------------------------ internos
func _who_cap() -> String:
	var s: String = _who.text
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s

func _quote_text(raw: String) -> void:
	_quote.set_meta("raw", raw)
	var r = link.repo()
	var parsed: Dictionary = r.parse_text(raw) if r != null and raw != "" else {"plain": raw, "styles": []}
	var p2: Dictionary = parsed.duplicate()
	if raw != "":
		# la afirmación entre comillas (sólo para mostrarla; no es recortable aquí: lo es en la transcripción)
		p2["plain"] = "«" + String(parsed.plain) + "»"
		var st2: Array = []
		for s in parsed.get("styles", []):
			var s2: Dictionary = s.duplicate()
			s2["from"] = int(s.from) + 1
			s2["to"] = int(s.to) + 1
			st2.append(s2)
		p2["styles"] = st2
	TextBuilder.build(_quote, p2, {"slot": "imprenta", "size": int(round(SimLink.px("doc") * 1.24))})

func _uids() -> Array:
	var seen := {}
	var out: Array = []
	for e in link.qa("q_diary"):
		if String(e.get("kind", "")) == "line" and String(e.get("origin", "")) == ORIGIN and String(e.get("line", "")) != "":
			var u := String(e.line)
			if not seen.has(u):
				seen[u] = true
				out.append(u)
	var sc: Dictionary = link.qd("q_scene")
	if String(sc.get("id", "")) == ORIGIN or String(sc.get("scene", "")) == "HC07":
		for ln in sc.get("lines", []):
			var u2 := String(ln.get("uid", ""))
			if u2 != "" and not seen.has(u2):
				seen[u2] = true
				out.append(u2)
	out.sort()
	return out

func _last_librero_text() -> String:
	var uids := _uids()
	for i in range(uids.size() - 1, -1, -1):
		var ln: Dictionary = link.qd("q_line", [String(uids[i])])
		if String(ln.get("who", "")) == WHO:
			return String(ln.get("text", ""))
	return ""

func _title_text() -> String:
	var c: Dictionary = link.qd("q_clock")
	var when := String(c.get("date_label", ""))
	var sl := String(c.get("slot_label", ""))
	if sl != "" and when != "":
		when += ", " + sl
	var place: String = link.t("sceneui.lugar.L1.tienda")
	return place + " · " + when if when != "" else place

# echo: lo que Lisle mostró (su frase) o «(Calla.)»; el sim no lo registra como línea, así que la transcripción lo
# muestra como fila local (no recortable) justo antes de la respuesta del librero.
func _on_answered(res: Dictionary, echo := "") -> void:
	if echo != "":
		transcript.add_echo("lisle", echo)
	answered.emit(res)
	refresh()

func _on_follow() -> void:
	transcript.set_tijera(false)
	finished.emit()
	close()

func _on_clipped(res: Dictionary, text: String, pos: Vector2) -> void:
	clipped.emit(res)
	var strip := Widgets.chip(SimLink.short(text, 60))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fly.add_child(strip)
	strip.position = pos - strip.get_combined_minimum_size() * 0.5
	var vp := root.get_viewport_rect().size if root.is_inside_tree() else Vector2(1600, 900)
	var tw := strip.create_tween()
	tw.set_parallel(true)
	tw.tween_property(strip, "position", (strip_target if strip_target.x >= 0.0 else Vector2(64.0, vp.y - 40.0)), 0.4)
	tw.tween_property(strip, "modulate:a", 0.0, 0.18).set_delay(0.22)
	tw.chain().tween_callback(strip.queue_free)

func _banner_can_drop(_at: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and ["clip", "pregunta"].has(String(data.get("kind", ""))) and not bool(status.get("done", false))

func _banner_drop(_at: Vector2, data) -> void:
	refute({"kind": String(data.get("kind", "")), "id": String(data.get("id", ""))})

func _unhandled_input(ev: InputEvent) -> void:
	if not visible or not handle_keys:
		return
	if ev.is_action_pressed("fe_volver"):
		if back():
			get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("fe_tijera"):
		toggle_tijera()
		get_viewport().set_input_as_handled()
