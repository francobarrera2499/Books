# ui/scene/ask_panel.gd — preguntar y afirmar con la frase exacta antes de hablar (GDD §8.7, ARCHITECTURE §5.7, §6.7).
# Dueño: W3-SCENEUI.
# Uso: var a = AskPanel.new(link); add_child(a); a.open("watson", "El doctor Watson", "ask")
#   open(char, label, mode "ask"|"assert") · close() · choose(id) (tema o afirmación) · confirm() · phrase() (lo que dirá).
# Señales: said(res) (acción aceptada) · failed(err) · closed (Volver / fe_volver).
# Paso 1: elegir un tema del índice (q_topics(char), con búsqueda) o una afirmación disponible ante ese personaje
#   (q_assertions filtradas por el canal del personaje, igual que Dialogue: assertion.channels vs dialogue.sensor).
#   También se puede soltar un chip del índice ({"kind":"ent","id"}) sobre el panel.
# Paso 2: se ve la frase exacta de Lisle (q_preview) y se confirma con «Preguntar» / «Decirlo»; «Volver» no gasta nada.
# Sin contador de preguntas restantes (§6.1): si el personaje ya no contesta, el panel no se ofrece (lo decide ScenePanel).
extends PanelContainer

signal said(res: Dictionary)
signal failed(err: String)
signal closed

const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const SimLink = preload("res://ui/scene/sim_link.gd")

var link
var char_id := ""
var char_label := ""
var mode := "ask"
var options: Array = []        # [{id, label}]
var chosen := ""
var _title: Label
var _tabs := {}
var _search: LineEdit
var _list: ItemList
var _phrase: Label
var _ok: Button
var _empty: Label
var _shown: Array = []         # ids en el orden del ItemList

func _init(p_link = null) -> void:
	link = p_link if p_link != null else SimLink.new()
	name = "Preguntar"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 22, "margin_v": 18, "shadow_size": 12, "shadow_y": 5})))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_title = Widgets.doc_title("")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for m in ["ask", "assert"]:
		var b := Widgets.ink_tab(link.t("sceneui.verb." + m), group)
		b.pressed.connect(set_mode.bind(m))
		_tabs[m] = b
		bar.add_child(b)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(14, 0)
	bar.add_child(sp)
	_search = LineEdit.new()
	_search.placeholder_text = link.t("sceneui.ask.search")
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_t): _fill_list())
	bar.add_child(_search)
	v.add_child(bar)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 236)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.auto_height = false
	_list.focus_mode = Control.FOCUS_NONE
	_list.allow_reselect = true
	_list.item_selected.connect(func(i): choose(String(_shown[i])))
	_list.item_activated.connect(func(i): choose(String(_shown[i])); confirm())
	v.add_child(_list)
	_empty = Widgets.caption("")
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	v.add_child(_empty)
	v.add_child(Widgets.rule())
	_phrase = Label.new()
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phrase.custom_minimum_size = Vector2(0, 52)
	_phrase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	Widgets.restyle(_phrase, func():
		_phrase.add_theme_font_override("font", SimLink.font("imprenta", true))
		_phrase.add_theme_font_size_override("font_size", SimLink.px("doc")))
	v.add_child(_phrase)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 18)
	row.add_child(Widgets.ink_button(link.t("sceneui.back"), _on_back))
	_ok = Widgets.button(link.t("sceneui.ask.ok"), confirm)
	row.add_child(_ok)
	v.add_child(row)

func open(p_char: String, p_label: String, p_mode := "ask") -> void:
	char_id = p_char
	char_label = p_label
	_search.text = ""
	visible = true
	set_mode(p_mode)
	link.play("sfx.papel")

func close() -> void:
	visible = false

func set_mode(m: String) -> void:
	mode = m
	if _tabs.has(m):
		_tabs[m].set_pressed_no_signal(true)
	_tabs["assert"].visible = not _assertions().is_empty() or m == "assert"
	_tabs["ask"].visible = not link.qa("q_topics", [char_id]).is_empty() or m == "ask"
	_title.text = link.t("sceneui.ask.title", {"quien": SimLink.cap(char_label)})
	_search.visible = m == "ask"
	_ok.text = link.t("sceneui.%s.ok" % m)
	options = link.qa("q_topics", [char_id]) if m == "ask" else _assertions()
	chosen = ""
	_fill_list()
	_update_phrase()

func choose(id: String) -> void:
	var found := false
	for o in options:
		if String(o.id) == id:
			found = true
	if not found:
		failed.emit("no_indexado")
		return
	chosen = id
	var i := _shown.find(id)
	if i >= 0 and not _list.is_selected(i):
		_list.select(i)
		_list.ensure_current_is_visible()
	_update_phrase()

func action() -> Dictionary:
	if chosen == "":
		return {}
	if mode == "ask":
		return {"t": "ask", "char": char_id, "topic": chosen}
	return {"t": "assert", "char": char_id, "assertion": chosen}

func phrase() -> String:
	var a := action()
	return link.preview(a) if not a.is_empty() else ""

func confirm() -> void:
	var a := action()
	if a.is_empty():
		return
	var res: Dictionary = link.act(a)
	if bool(res.get("ok", false)):
		close()
		said.emit(res)
	else:
		failed.emit(String(res.get("err", "")))

# Afirmaciones disponibles ante este personaje: requires en el índice (q_assertions) y canal compatible.
func _assertions() -> Array:
	return assertions_for(char_id)

func assertions_for(cid: String) -> Array:
	var r = link.repo()
	var sensor = r.dialogue(cid).get("sensor", null) if r != null else null
	var ch := "" if sensor == null else String(sensor).replace("-", "").to_lower()
	var out: Array = []
	for x in link.qa("q_assertions"):
		var chans: Array = x.get("channels", [])
		if ch != "" and not chans.is_empty() and not chans.has(ch):
			continue
		var ph: String = link.preview({"t": "assert", "char": cid, "assertion": String(x.id)})
		out.append({"id": String(x.id), "label": ph if ph != "" else String(x.get("phrase", x.id))})
	return out

func _fill_list() -> void:
	_list.clear()
	_shown.clear()
	var q := _search.text.strip_edges().to_lower()
	for o in options:
		var lab := String(o.get("label", o.id))
		if q != "" and not lab.to_lower().contains(q):
			continue
		_list.add_item(lab)
		_shown.append(String(o.id))
	var i := _shown.find(chosen)
	if i >= 0:
		_list.select(i)
	_empty.visible = _shown.is_empty()
	_list.visible = not _shown.is_empty()
	if _empty.visible:
		_empty.text = link.t("sceneui.%s.none" % mode) if q == "" else link.t("sceneui.picker.nada_busqueda")

func _update_phrase() -> void:
	var ph := phrase()
	if ph == "":
		_phrase.text = link.t("sceneui.%s.pick" % mode)
		_phrase.add_theme_color_override("font_color", Paper.ink("tenue"))
		_ok.disabled = true
	else:
		_phrase.text = "—" + ph
		_phrase.add_theme_color_override("font_color", Paper.ink("negra"))
		_ok.disabled = false

func _on_back() -> void:
	close()
	closed.emit()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_on_back()
		accept_event()

func _can_drop_data(_at: Vector2, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "ent" and mode == "ask"

func _drop_data(_at: Vector2, data) -> void:
	choose(String(data.get("id", "")))
