# ui/notebook/notebook.gd — el Cuaderno de Lisle (capa 20, «Libros»). Dueño: UI-EXPEDIENTE (antes W3-NOTEBOOK).
# Contrato: GDD_v3 §6.1–§6.3 (+ ARCHITECTURE §6.5, reglas de UI limpia §6.1 y arrastre §6.3).
# Pestañas: Recortes (búsqueda; filtros por persona, lugar y fecha DE LA CRÓNICA; agrupado por el calendario de la
# crónica; cada recorte es una TARJETA: texto en la letra de su documento, la fuente en chico y las entidades sólo al
# pasar el mouse) · Índice (alfabético por `index`; clic = filtra Recortes; los chips se arrastran) · Diario (D36, con
# sello «Recibido» en cada llegada; recortable con la tijera) · Marginalia (curiosidades; sin contador). Nada cuenta ni
# destaca. v3: sin pares ni cotejos (nada se suelta sobre un recorte) y sin la cinta del otro libro (una sola forma de
# hacer cada cosa): las pruebas se arrastran directo a las ranuras del Expediente Holmes.
#
# Uso (Shell): var nb = preload("res://ui/notebook/notebook.gd").new(); capa_libros.add_child(nb)
#   open(tab := "") · close() · toggle() · is_open() · show_tab(tab) · set_layout("full"|"left"|"right")
#   filter_entity(ent) (va a Recortes filtrado; lo usa el Índice y puede usarlo el Shell) · refresh() (lo hace solo con
#   Game.sim_changed) · set_thumb(clip_id, tex) (miniatura de un recorte de lámina; sesión) · debug_state() (tests) ·
#   ent_label(id) (etiqueta de índice de una entidad, esté o no en el índice del jugador) · card_width(wide)
# Con el Expediente abierto (Shell.is_open("dossier")), el cuaderno se acopla a la izquierda, más angosto, sin velo.
# Ancho: pestañas y «Volver» siempre dentro del libro (_fit_tabs: sangría y, si no alcanza, letra); set_layout rehace
#   las páginas si cambia el ancho del cuerpo (las tarjetas se arman con él).
# Señales: opened · closed · tab_changed(tab) · clipped(result) (tijera del diario) ·
#   source_requested(clip_id, copy) (doble clic en una tarjeta: el Shell puede abrir el lector si es legible).
# Config: act_fn (Callable(a) -> Dictionary; por defecto Game.act) · sim_override (GameSim; por defecto Game.sim) ·
#   handle_back (true: fe_volver = deja la tijera / cierra el formulario / cierra el cuaderno; el Shell lo pone en false
#   si maneja su pila y llama a back()) · handle_keys (fe_tijera en la pestaña Diario) · backdrop (velo que oscurece el
#   3D; clic en el velo cierra) · sounds.
# Todo texto sale de ui_text (data/ui_text/notebook.json, prefijo nb.) o de las consultas q_* del sim.
# GDD_v2 §C.3 (revelado progresivo, banderas de q_ui): al principio no hay pestañas, sólo la lista de recortes. Cada
#   pestaña aparece con su bandera (Índice nb.indice · Diario nb.diario · Curiosidades nb.curiosidades); con una sola
#   pestaña posible no se dibuja la fila de pestañas. La búsqueda, los filtros y la agrupación por mes los decide
#   tab_clips con nb.buscar / nb.filtros / nb.agrupar. Lo que apareció no vuelve a desaparecer (lo asegura q_ui).
extends Control

signal opened
signal closed
signal tab_changed(tab: String)
signal clipped(result: Dictionary)
signal source_requested(clip_id: String, copy: String)

const L = preload("res://core/util/log.gd")
const Paper = preload("res://ui/kit/paper.gd")
const Widgets = preload("res://ui/kit/widgets.gd")
const Sheet = preload("res://ui/kit/sheet.gd")
const Model = preload("res://ui/notebook/notebook_model.gd")
const TabClips = preload("res://ui/notebook/tab_clips.gd")
const TabIndex = preload("res://ui/notebook/tab_index.gd")
const TabDiary = preload("res://ui/notebook/tab_diary.gd")
const TabMarginalia = preload("res://ui/notebook/tab_marginalia.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")
# pestaña -> bandera de q_ui que la muestra ("" = siempre)
const TAB_FLAG := {"recortes": "", "indice": "nb.indice", "diario": "nb.diario", "marginalia": "nb.curiosidades"}

const TABS := ["recortes", "indice", "diario", "marginalia"]
# Lo que cambia algo del cuaderno (el expediente no: puede estar abierto al lado sin rehacerlo).
const REFRESH_KINDS := ["clip", "index", "diary", "egg", "line", "tray", "clock"]
const BOOK_MAX_W := 1180.0
const BOOK_MIN_W := 560.0
const PAD := 26.0                 # margen interior de la hoja
const MARGIN_COL := 100.0         # columna del margen (fechas, letras, quién habla, sellos)
const GUTTER := 22.0              # entre el margen y el cuerpo; la línea roja va en el medio
const STRIP_W := 470.0            # ancho de una columna de diario (la tira, GDD§8.1)
const CARD_W := 600.0             # ancho máximo de una tarjeta de recorte (GDD_v3 §6.2)
const LEFT_NARROW_K := 0.42       # junto al expediente: fracción del ancho de pantalla
const WIDE_MIN := 860.0           # ancho de cuerpo desde el que el epígrafe va al lado de la tira
const TAB_LEAD := PAD + MARGIN_COL + GUTTER * 0.5 - 6.0   # sangría de las pestañas: empiezan en la línea roja
const TAB_LEAD_MIN := 6.0
const TAB_FONT_MIN := 12
const FADE_S := 0.2
const VELO_A := 0.42
const NOTE_HOLD_S := 3.2
const FLY_S := 0.4

var act_fn: Callable = Callable()
var sim_override = null
var handle_back := true
var handle_keys := true
var backdrop := true
var sounds := true
var layout := "full"
var auto_layout := true           # con Shell: a la izquierda y sin velo si el expediente está abierto o hay escena
var narrow := false               # acoplado junto al expediente (más angosto: la carpeta necesita su lugar)
var shell = null                  # ui/shell.gd (lo pone Shell.open_panel); opcional
var tab := "recortes"
var filters := {"q": "", "persona": "", "lugar": "", "fecha": "", "ent": ""}

static var thumbs := {}           # clip_id -> Texture2D (miniaturas de láminas; sólo en la sesión)

var _built := false
var _open := false
var _velo: ColorRect
var _book: Control
var _tabs_row: HBoxContainer
var _tabs_lead: Control
var _tab_buttons := {}
var _tab_group: ButtonGroup
var _close_btn: Button
var _sheet: PanelContainer
var _content: Control
var _pages := {}
var _dirty := {}
var _note: PanelContainer
var _note_label: Label
var _note_tw: Tween = null
var _overlay: Control
var _overlay_panel: Control = null
var _fly: Control
var _fade_tw: Tween = null
var _refresh_pending := false
var _cache_look := {}
var flags := {}                   # q_ui() del último refresco (revelado progresivo)

func _init() -> void:
	name = "Cuaderno"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	for tb in TABS:
		_dirty[tb] = true

func _ready() -> void:
	_build()
	var game := _autoload("Game")
	if game != null:
		if game.has_signal("sim_changed") and not game.sim_changed.is_connected(_on_sim_changed):
			game.sim_changed.connect(_on_sim_changed)
		if game.has_signal("session_started") and not game.session_started.is_connected(_on_session_started):
			game.session_started.connect(_on_session_started)
	var ti := _autoload("ThemeInstaller")
	if ti != null and ti.has_signal("theme_changed") and not ti.theme_changed.is_connected(_on_theme_changed):
		ti.theme_changed.connect(_on_theme_changed)
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_vp_resized):
		vp.size_changed.connect(_on_vp_resized)

func _exit_tree() -> void:
	_set_cursor(false)

# Mientras se arrastra algo, el velo deja pasar el ratón (presentar sobre un personaje, soltar en el escritorio).
func _notification(what: int) -> void:
	if not _built:
		return
	if what == NOTIFICATION_DRAG_BEGIN:
		_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_velo.color.a = 0.18
	elif what == NOTIFICATION_DRAG_END:
		_velo.mouse_filter = Control.MOUSE_FILTER_STOP
		_velo.color.a = VELO_A

# ------------------------------------------------------------------ API
func open(p_tab := "") -> void:
	_build()
	if p_tab != "" and TABS.has(p_tab):
		tab = p_tab
	var was := _open
	_open = true
	visible = true
	_sync_flags()
	if not tab_available(tab):
		tab = "recortes"
	_sync_with_shell()
	_layout()
	show_tab(tab)
	if not was:
		if _fade_tw != null and _fade_tw.is_valid():
			_fade_tw.kill()
		modulate.a = 0.0
		_fade_tw = Widgets.fade(self, 1.0, FADE_S)
		_sfx("sfx.pagina")
		opened.emit()

func close() -> void:
	if not _open:
		return
	_open = false
	_close_overlay()
	_set_scissors(false)
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	if is_inside_tree():
		_fade_tw = Widgets.fade(self, 0.0, FADE_S)
		_fade_tw.tween_callback(func(): if not _open: visible = false)
	else:
		visible = false
	closed.emit()

func toggle(p_tab := "") -> void:
	if _open and (p_tab == "" or p_tab == tab):
		close()
	else:
		open(p_tab)

func is_open() -> bool:
	return _open

func show_tab(p_tab: String) -> void:
	_build()
	if not TABS.has(p_tab) or not tab_available(p_tab):
		return
	var changed := p_tab != tab
	if changed and tab == "diario":
		_set_scissors(false)
	tab = p_tab
	for tb in TABS:
		_pages[tb].visible = tb == tab
		var b: Button = _tab_buttons[tb]
		b.set_pressed_no_signal(tb == tab)
	if _dirty.get(tab, true):
		_refresh_tab(tab)
	if changed:
		tab_changed.emit(tab)

func set_layout(mode: String) -> void:
	if not ["full", "left", "right"].has(mode):
		return
	# las tiras se arman con el ancho del cuerpo: si cambia (no sólo ancho/angosto: con texto 1,3× los dos modos son
	# angostos y la tira del libro centrado no cabe acoplada), se rehacen las páginas
	var was_bw := body_width()
	layout = mode
	_layout()
	if absf(was_bw - body_width()) > 0.5:
		mark_all_dirty()
		if _open:
			_refresh_tab(tab)

func filter_entity(ent: String) -> void:
	var kinds := Model.kinds_of(index_rows())
	var k := String(kinds.get(ent, ""))
	for f in Model.FILTER_KEYS:
		filters[f] = ""
	if k == "persona" or k == "lugar":
		filters[k] = ent
	else:
		filters["ent"] = ent
	if not _open:
		open("recortes")
	else:
		show_tab("recortes")
	_pages["recortes"].sync_filters()

func clear_filters() -> void:
	for k in filters:
		filters[k] = ""
	if _built:
		_pages["recortes"].sync_filters()

func refresh() -> void:
	mark_all_dirty()
	_sync_flags()
	if _open:
		_refresh_tab(tab)

# ¿Esta pestaña ya existe? (GDD_v2 §C.2; sin partida, todas)
func tab_available(tb: String) -> bool:
	var f := String(TAB_FLAG.get(tb, ""))
	return f == "" or UiFlags.on(flags, f)

func available_tabs() -> Array:
	var out: Array = []
	for tb in TABS:
		if tab_available(tb):
			out.append(tb)
	return out

func flag(name: String) -> bool:
	return UiFlags.on(flags, name)

# Relee q_ui y muestra sólo las pestañas que existen; con una sola, sin fila de pestañas (queda «Volver»).
func _sync_flags() -> void:
	flags = UiFlags.of(sim())
	if not _built:
		return
	var av := available_tabs()
	for tb in TABS:
		(_tab_buttons[tb] as Button).visible = av.size() > 1 and av.has(tb)
	if not av.has(tab):
		show_tab("recortes")
	_fit_tabs.call_deferred()

func mark_all_dirty() -> void:
	for tb in TABS:
		_dirty[tb] = true

# Shell (protocolo por duck typing): guarda la referencia y sigue la apertura y cierre de los demás paneles.
func set_shell(s) -> void:
	shell = s
	if s != null and s.has_signal("panel_opened"):
		if not s.panel_opened.is_connected(_on_shell_panel):
			s.panel_opened.connect(_on_shell_panel)
		if not s.panel_closed.is_connected(_on_shell_panel):
			s.panel_closed.connect(_on_shell_panel)

func _on_shell_panel(_kind: String) -> void:
	if _open:
		_sync_with_shell.call_deferred()

# Dos paneles a la vez (§6.1): con el expediente abierto (GDD_v3 §6.1: las pruebas se arrastran de acá a sus ranuras), o
# en una visita/escena (presentar = soltar sobre el 3D), el cuaderno va a la izquierda y sin velo; si no, centrado y con
# el velo. Junto al expediente es más angosto (la carpeta lleva dos páginas).
func _sync_with_shell() -> void:
	if not auto_layout or shell == null or not shell.has_method("is_open"):
		return
	var phase := ""
	var c = q("q_clock")
	if c is Dictionary:
		phase = String(c.get("phase", ""))
	var dossier: bool = bool(shell.is_open("dossier"))
	var side: bool = dossier or bool(shell.is_open("scene")) or bool(shell.is_open("confront")) \
		or ["visit", "scene", "confront"].has(phase)
	var want := "left" if side else "full"
	backdrop = not side
	var was_bw := body_width()
	narrow = dossier
	# junto a la carpeta, un solo «Volver» (el de la carpeta: cierra las dos); GDD_v3 decisión 13
	if _close_btn != null:
		_close_btn.visible = not dossier
	if want != layout:
		set_layout(want)
	else:
		_layout()
		if absf(was_bw - body_width()) > 0.5:
			mark_all_dirty()
			if _open:
				_refresh_tab(tab)

# Doble clic en una tarjeta: con Shell, abre el original si está legible ahora (una lámina la abre el Shell por
# source_requested); si no, Lisle lo dice.
func open_source(clip_id: String, copy: String) -> void:
	source_requested.emit(clip_id, copy)
	if shell == null or not shell.has_method("open_reader") or copy == "":
		return
	var acc = q("q_accessible")
	var is_doc := false
	if acc is Array:
		for a in acc:
			if String(a.get("view", "")) == copy:
				is_doc = true
	# un recorte de lámina: la abre el Shell (source_requested -> open_plate); no es «inaccesible»
	var pl = q("q_plate", [copy])
	if not is_doc and pl is Dictionary and not pl.is_empty():
		return
	if is_doc:
		shell.open_reader(copy)
	else:
		say(err_text("inaccesible"))

func set_thumb(clip_id: String, tex: Texture2D) -> void:
	thumbs[clip_id] = tex
	_dirty["recortes"] = true

func thumb_of(clip_id: String) -> Texture2D:
	return thumbs.get(clip_id)

# Volver (Esc / clic derecho): el formulario abierto, después la tijera, después el cuaderno.
func back() -> bool:
	if not _open:
		return false
	if _overlay_panel != null:
		_close_overlay()
		return true
	if _pages.has("diario") and _pages["diario"].scissors:
		_set_scissors(false)
		return true
	close()
	return true

func page(tb: String):
	_build()
	return _pages.get(tb)

# Tijera (C) con el cuaderno arriba de la pila (GameScreen.toggle_scissors delega en el panel de arriba): en el Diario
# la toma o la deja; con una escena debajo (visita, confrontación), la tijera es la de sus líneas; si no, el único papel
# recortable del cuaderno es el Diario: se abre ahí con la tijera en la mano.
var tijera: bool:
	get:
		return _built and _pages["diario"].scissors

func toggle_tijera() -> void:
	if not _open:
		return
	if tab == "diario":
		_set_scissors(not tijera)
		return
	if shell != null and shell.has_method("is_open") and shell.has_method("panel"):
		for k in ["confront", "scene"]:
			if shell.is_open(k):
				var p = shell.panel(k)
				if p != null and p.has_method("toggle_tijera"):
					p.toggle_tijera()
					return
	if not tab_available("diario") or not flag("desk.tijera"):
		return
	show_tab("diario")
	_set_scissors(true)

func set_tijera(on: bool) -> void:
	if on and not tab_available("diario"):
		return
	if on and tab != "diario":
		show_tab("diario")
	_set_scissors(on)

# Miniatura de un recorte de lámina (la captura del rectángulo; sólo en la sesión). Estática: GameScreen puede
# guardarla aunque el cuaderno no exista todavía. Sin miniatura, la tarjeta dibuja un grabado de reemplazo.
static func store_thumb(clip_id: String, tex: Texture2D) -> void:
	if clip_id != "" and tex != null:
		thumbs[clip_id] = tex

func debug_state() -> Dictionary:
	var vis_tabs: Array = []
	if _built:
		for tb in TABS:
			if (_tab_buttons[tb] as Button).visible:
				vis_tabs.append(tb)
	var out := {"open": _open, "tab": tab, "layout": layout, "filters": filters.duplicate(), "overlay": _overlay_panel != null,
		"note": _note_label.text if _note != null and _note.visible else "", "wide": is_wide(), "tabs": vis_tabs,
		"narrow": narrow, "rect": book_rect()}
	for tb in TABS:
		if _pages.has(tb):
			out[tb] = _pages[tb].debug_state()
	return out

# ------------------------------------------------------------------ acceso al sim y a los textos
func sim():
	if sim_override != null:
		return sim_override
	var game := _autoload("Game")
	if game != null:
		return game.get("sim")
	return null

func repo():
	var s = sim()
	if s != null and s.get("repo") != null:
		return s.repo
	var data := _autoload("Data")
	return data.repo() if data != null else null

func t(key: String, vars := {}) -> String:
	var r = repo()
	if r != null:
		var s: String = r.text(key, vars)
		if s != key:
			return s
	return Widgets.t(key, vars)

func text_fn() -> Callable:
	return func(k: String, v: Dictionary) -> String: return t(k, v)

func act(a: Dictionary) -> Dictionary:
	var r = null
	if act_fn.is_valid():
		r = act_fn.call(a)
	else:
		var game := _autoload("Game")
		if game == null:
			return {"ok": false, "err": "no_sim"}
		r = game.act(a)
	if typeof(r) != TYPE_DICTIONARY:
		r = {"ok": false, "err": "desconocido"}
	if bool(r.get("ok", false)):
		_queue_refresh()
	return r

func q(fn_name: String, args := []):
	var s = sim()
	if s == null or not s.has_method(fn_name):
		return null
	return s.callv(fn_name, args)

func clips() -> Array:
	var r = q("q_clips")
	return r if r is Array else []

func index_rows() -> Array:
	var r = q("q_index")
	return r if r is Array else []

# Etiqueta de índice de una entidad que puede no estar en el índice del jugador (lugar `p:` de la crónica, visible como
# filtro): nunca el id crudo si el repo la conoce.
func ent_label(id: String) -> String:
	var r = repo()
	if r != null and id != "":
		var e: Dictionary = r.entity(id)
		if not e.is_empty():
			return preload("res://core/deduction/index.gd").display(r, id)
	return id

func known_ids() -> Dictionary:
	var out := {}
	for r in index_rows():
		out[String(r.get("id", ""))] = true
	return out

# Letra y papel del documento de origen de un recorte (ClipCard.look_for, cacheado).
func look_of(c: Dictionary) -> Dictionary:
	return preload("res://ui/notebook/clip_card.gd").look_for(sim(), c)

# ------------------------------------------------------------------ geometría
func book_rect() -> Rect2:
	var vp := _vp_size()
	var top := 26.0
	var h := vp.y - top - 24.0
	if layout != "full":
		# la banda de la escena (capa 40) tapa el pie de la pantalla: el cuaderno acoplado termina arriba de ella
		var bt := _scene_band_top()
		if bt > 0.0:
			h = maxf(320.0, bt - top - 14.0)
	match layout:
		"left":
			var w := maxf(BOOK_MIN_W, vp.x * 0.5 - 30.0)
			if narrow:
				w = clampf(vp.x * LEFT_NARROW_K, minf(BOOK_MIN_W, vp.x * 0.5 - 30.0), vp.x * 0.5 - 30.0)
			return Rect2(Vector2(18.0, top), Vector2(w, h))
		"right":
			var w2 := maxf(BOOK_MIN_W, vp.x * 0.5 - 30.0)
			return Rect2(Vector2(vp.x - w2 - 18.0, top), Vector2(w2, h))
	var w3 := clampf(vp.x - 200.0, BOOK_MIN_W, BOOK_MAX_W)
	return Rect2(Vector2((vp.x - w3) * 0.5, top), Vector2(w3, h))

const SCENE_BAND_FALLBACK := 290.0   # alto reservado si el panel de escena no expone su banda

# Borde superior (en el canvas) de la banda del panel de escena o de confrontación abierto; 0 = no hay.
func _scene_band_top() -> float:
	if shell == null or not shell.has_method("is_open") or not shell.has_method("panel"):
		return 0.0
	for k in ["confront", "scene"]:
		if not shell.is_open(k):
			continue
		var p = shell.panel(k)
		if p == null or not is_instance_valid(p):
			continue
		if "visible" in p and not p.visible:
			continue
		var b = p.get("band") if "band" in p else null
		if b is Control and is_instance_valid(b) and b.is_visible_in_tree() and b.size.y > 0.0:
			return b.get_global_rect().position.y
		return _vp_size().y - SCENE_BAND_FALLBACK
	return 0.0

func body_width() -> float:
	return book_rect().size.x - PAD * 2.0 - MARGIN_COL - GUTTER - 14.0

func is_wide() -> bool:
	return body_width() >= WIDE_MIN * _scale()

# Ancho de una tarjeta de recorte: hasta CARD_W (× escala de texto), nunca más que el cuerpo de la hoja.
func card_width(_wide := true) -> float:
	return roundf(minf(body_width() - 8.0, CARD_W * _scale()))

func strip_width(wide: bool) -> float:
	var w := STRIP_W * _scale()
	if not wide:
		w = minf(body_width() - 8.0, maxf(w, 520.0 * _scale()))
	return roundf(w)

func _scale() -> float:
	var ti := _autoload("ThemeInstaller")
	return float(ti.text_scale) if ti != null else 1.0

# Fila de página: [margen] [cuerpo]. El margen queda a la izquierda de la línea roja.
func margin_row(margin: Control, bodyc: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(GUTTER))
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	if margin == null:
		margin = Control.new()
	margin.custom_minimum_size.x = MARGIN_COL
	margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if margin.mouse_filter != Control.MOUSE_FILTER_STOP:
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(margin)
	bodyc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(bodyc)
	return h

# Texto del margen (fecha, letra, quién habla), a lápiz y alineado contra la línea roja.
func margin_text(text: String, variation := "Marginal") -> Label:
	var l := Widgets.label(text, variation)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(MARGIN_COL, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# Línea en blanco de Lisle (estado vacío o explicación de la forma, nunca del contenido).
func empty_line(text: String) -> Label:
	var l := Widgets.label(text, "Caption")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Paper.ink("lapiz"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func scroll_box() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.follow_focus = false
	return s

# ------------------------------------------------------------------ Lisle, formularios, vuelo de la tira
func say(text: String) -> void:
	if text == "" or _note == null:
		return
	_note_label.text = text
	_note.visible = true
	_note.reset_size()
	_place_note()
	if _note_tw != null and _note_tw.is_valid():
		_note_tw.kill()
	_note_tw = _note.create_tween()
	_note_tw.tween_property(_note, "modulate:a", 1.0, 0.2)
	_note_tw.tween_interval(NOTE_HOLD_S)
	_note_tw.tween_property(_note, "modulate:a", 0.0, 0.4)
	_note_tw.tween_callback(func(): _note.visible = false)

func err_text(err: String) -> String:
	for k in ["nb.err." + err, "clip." + err, "entry." + err, "sim.err." + err, "core.err." + err]:
		var s := t(k, {"n": "tres"})
		if s != k:
			return s
	return t("core.err.desconocido")

# Formulario sobre el libro (segundo panel como mucho, §6.1). Un solo formulario a la vez.
func show_overlay(panel: Control) -> void:
	_close_overlay()
	_overlay_panel = panel
	_overlay.visible = true
	_overlay.add_child(panel)
	panel.reset_size()
	_place_overlay.call_deferred()

func _close_overlay() -> void:
	if _overlay_panel != null:
		_overlay_panel.queue_free()
		_overlay_panel = null
	if _overlay != null:
		_overlay.visible = false

func overlay_panel() -> Control:
	return _overlay_panel

func _place_overlay() -> void:
	if _overlay_panel == null:
		return
	_overlay_panel.reset_size()
	var br := Rect2(Vector2.ZERO, _book.size)
	var sz := _overlay_panel.get_combined_minimum_size()
	_overlay_panel.size = sz
	_overlay_panel.position = (br.size - sz) * Vector2(0.5, 0.42)

# La tira recortada vuela hacia la pestaña Recortes.
func fly_strip(text: String, from_canvas: Vector2) -> void:
	if text == "" or _fly == null:
		return
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 10, "margin_v": 4, "radius": 0, "shadow_size": 6, "shadow_y": 3}))
	var l := Label.new()
	l.add_theme_font_override("font", _font("imprenta"))
	l.add_theme_font_size_override("font_size", _px("small"))
	l.add_theme_color_override("font_color", Paper.ink("negra"))
	l.text = text if text.length() <= 56 else text.left(53) + "…"
	strip.add_child(l)
	_fly.add_child(strip)
	strip.reset_size()
	var sz := strip.get_combined_minimum_size()
	strip.size = sz
	strip.pivot_offset = sz * 0.5
	var inv := _fly.get_global_transform_with_canvas().affine_inverse()
	strip.position = inv * from_canvas - sz * 0.5
	strip.rotation_degrees = -1.5
	var tb: Control = _tab_buttons["recortes"]
	if not tb.visible:
		tb = _close_btn if _close_btn.visible else _book
	var target: Vector2 = inv * (tb.get_global_transform_with_canvas() * (tb.size * 0.5)) - sz * 0.5
	var tw := strip.create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(strip, "position", target, FLY_S)
	tw.tween_property(strip, "scale", Vector2(0.35, 0.35), FLY_S)
	tw.tween_property(strip, "rotation_degrees", -8.0, FLY_S)
	tw.tween_property(strip, "modulate:a", 0.0, FLY_S * 0.45).set_delay(FLY_S * 0.55)
	tw.chain().tween_callback(strip.queue_free)

func on_clipped(res: Dictionary) -> void:
	_sfx("sfx.tijera")
	clipped.emit(res)

# ------------------------------------------------------------------ construcción
func _build() -> void:
	if _built:
		return
	_built = true
	_velo = ColorRect.new()
	_velo.name = "Velo"
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_velo.color = Color(0.08, 0.06, 0.04, VELO_A)
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.gui_input.connect(_on_velo_input)
	add_child(_velo)
	_book = Control.new()
	_book.name = "Libro"
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_book)
	var col := VBoxContainer.new()
	col.name = "Columna"
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	_book.add_child(col)
	# --- pestañas (arriba de la hoja) y Volver
	_tabs_row = HBoxContainer.new()
	_tabs_row.name = "Pestanas"
	_tabs_row.add_theme_constant_override("separation", 3)
	_tabs_row.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_tabs_row)
	var lead := Control.new()
	lead.name = "Sangria"
	lead.custom_minimum_size = Vector2(TAB_LEAD, 0)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs_row.add_child(lead)
	_tabs_lead = lead
	_tab_group = ButtonGroup.new()
	_tab_group.allow_unpress = false
	for tb in TABS:
		var b := TabButton.new()
		b.nb = self
		b.tab_id = tb
		b.text = t("nb.tab." + tb)
		b.theme_type_variation = "InkTab"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.button_group = _tab_group
		b.name = "Tab_" + tb
		b.pressed.connect(func(): show_tab(tb))
		_tabs_row.add_child(b)
		_tab_buttons[tb] = b
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs_row.add_child(fill)
	_close_btn = Widgets.button(t("nb.cerrar"), func(): close())
	_close_btn.name = "Volver"
	_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tabs_row.add_child(_close_btn)
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(8, 0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs_row.add_child(tail)
	# --- hoja
	_sheet = Sheet.new("cuaderno", {"margin_line": PAD + MARGIN_COL + GUTTER * 0.5, "margin_double": true, "pad": PAD})
	_sheet.name = "Hoja"
	_sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_sheet)
	_content = Control.new()
	_content.name = "Contenido"
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_sheet.add_child(_content)
	var scripts := {"recortes": TabClips, "indice": TabIndex, "diario": TabDiary, "marginalia": TabMarginalia}
	for tb in TABS:
		var p = scripts[tb].new(self)
		p.name = "Pagina_" + tb
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		_content.add_child(p)
		_pages[tb] = p
	# --- nota de Lisle (al pie del libro)
	_note = Widgets.paper_panel("carta", null, {"margin": 14, "margin_v": 8, "shadow_size": 6})
	_note.name = "NotaLisle"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note_label = Widgets.marginal("")
	_note_label.custom_minimum_size = Vector2(300, 0)
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_child(_note_label)
	_note.modulate.a = 0.0
	_note.visible = false
	_book.add_child(_note)
	# --- formularios
	_overlay = Control.new()
	_overlay.name = "Formulario"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(_on_overlay_input)
	var wash := ColorRect.new()
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(Paper.INKS["negra"], 0.18)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(wash)
	_book.add_child(_overlay)
	_fly = Control.new()
	_fly.name = "Vuelo"
	_fly.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fly)
	_layout()

# Pestaña del cuaderno: además de cambiar de página, recibe un chip del índice (filtra Recortes).
class TabButton extends Button:
	var nb
	var tab_id := ""
	func _can_drop_data(_at: Vector2, data) -> bool:
		return tab_id == "recortes" and typeof(data) == TYPE_DICTIONARY and String(data.get("kind", "")) == "ent"
	func _drop_data(_at: Vector2, data) -> void:
		nb.filter_entity(String(data.get("id", "")))

func _layout() -> void:
	if not _built:
		return
	_velo.visible = backdrop
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := book_rect()
	_book.position = r.position
	_book.size = r.size
	_fit_tabs()
	_place_note()
	_place_overlay()

# Pestañas y «Volver» caben siempre en el ancho del libro (acoplado a la izquierda con texto 1,3–1,6× no cabían): primero
# se achica la sangría (las pestañas dejan de alinearse con la línea roja); si ni así, la letra de las pestañas baja en
# proporción (mínimo TAB_FONT_MIN). Lo mismo para todas: ninguna se distingue.
func _fit_tabs() -> void:
	if not _built or not is_inside_tree():
		return
	var btns: Array = []
	for tb in TABS:
		if (_tab_buttons[tb] as Button).visible:
			btns.append(_tab_buttons[tb])
	if _close_btn.visible:
		btns.append(_close_btn)
	for b in btns:
		if b.has_theme_font_size_override("font_size"):
			b.remove_theme_font_size_override("font_size")
	var bw := book_rect().size.x
	var sep := float(_tabs_row.get_theme_constant("separation"))
	var fixed := 0.0
	var shown := 0
	for c in _tabs_row.get_children():
		if (c as Control).visible:
			shown += 1
	fixed = sep * float(maxi(0, shown - 1))
	for c in _tabs_row.get_children():
		if c != _tabs_lead and not btns.has(c) and (c as Control).visible:
			fixed += (c as Control).custom_minimum_size.x
	var widths := 0.0
	var texts := 0.0
	for b in btns:
		widths += (b as Control).get_combined_minimum_size().x
		texts += _btn_text_w(b, b.get_theme_font_size("font_size"))
	var room := bw - fixed - widths
	if room >= TAB_LEAD_MIN:
		_tabs_lead.custom_minimum_size.x = minf(TAB_LEAD, room)
		return
	_tabs_lead.custom_minimum_size.x = TAB_LEAD_MIN
	var k := (bw - fixed - TAB_LEAD_MIN - (widths - texts)) / maxf(1.0, texts)
	for b in btns:
		var fs: int = b.get_theme_font_size("font_size")
		b.add_theme_font_size_override("font_size", maxi(TAB_FONT_MIN, int(floor(float(fs) * k))))

static func _btn_text_w(b: Button, fs: int) -> float:
	var f: Font = b.get_theme_font("font")
	return f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f != null else 0.0

func _place_note() -> void:
	if _note == null or not _note.visible:
		return
	_note.reset_size()
	var sz := _note.get_combined_minimum_size()
	_note.size = sz
	_note.position = Vector2((_book.size.x - sz.x) * 0.5, _book.size.y - sz.y - 16.0)

func _refresh_tab(tb: String) -> void:
	if not _built:
		return
	_dirty[tb] = false
	_pages[tb].refresh()

func _queue_refresh() -> void:
	mark_all_dirty()
	if _refresh_pending:
		return
	_refresh_pending = true
	_do_refresh.call_deferred()

func _do_refresh() -> void:
	_refresh_pending = false
	_sync_flags()
	if _open and _dirty.get(tab, false):
		_refresh_tab(tab)

# ------------------------------------------------------------------ entrada
# Clic derecho sobre el cuaderno = volver (los controles de la hoja consumen los clics: se mira en _input si el puntero
# está sobre un control del cuaderno).
func _input(ev: InputEvent) -> void:
	# con Shell (handle_back = false) el clic derecho SOBRE el cuaderno sigue siendo volver: los controles de la hoja se
	# comen el clic y la pila nunca lo vería (Esc sí le llega y llama a back()).
	if not _open or not (handle_back or shell != null) or not is_visible_in_tree():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		var hov := get_viewport().gui_get_hovered_control()
		if hov != null and (hov == self or is_ancestor_of(hov)):
			# playtest v3: clic derecho SOBRE una tarjeta de recorte = «Tirar este recorte» (el resto, volver)
			var cid := _clip_id_of(hov)
			if cid != "":
				ask_drop(cid, (ev as InputEventMouseButton).global_position)
			else:
				back()
			get_viewport().set_input_as_handled()

# Id del recorte bajo el puntero (la tarjeta lleva meta «clip»; la fila, ClipCard.id); "" si no hay.
func _clip_id_of(n: Node) -> String:
	if tab != "recortes":
		return ""
	var c := n
	while c != null and c != self:
		if c.has_meta("clip") and String(c.get_meta("clip")) != "":
			return String(c.get_meta("clip"))
		if String(c.name).begins_with("Recorte_") and String(c.get("id")) != "":
			return String(c.get("id"))
		c = c.get_parent()
	return ""

# Clic derecho que resuelve el cuaderno (InputRouter lo pregunta antes de «volver»): sobre un recorte, el menú.
func context_click(hov: Node, at: Vector2) -> bool:
	if not _open or not is_visible_in_tree() or hov == null or not (hov == self or is_ancestor_of(hov)):
		return false
	var cid := _clip_id_of(hov)
	if cid == "":
		return false
	ask_drop(cid, at)
	return true

var _drop_menu: PopupMenu = null
var _drop_id := ""

# Menú del clic derecho sobre un recorte: una sola opción, «Tirar este recorte». Un recorte que es prueba de una hoja en
# tinta no se tira (Lisle lo dice).
func ask_drop(cid: String, at := Vector2(-1, -1)) -> void:
	_drop_id = cid
	if _drop_menu == null:
		_drop_menu = PopupMenu.new()
		_drop_menu.name = "MenuRecorte"
		_drop_menu.id_pressed.connect(func(_i): drop_clip(_drop_id))
		add_child(_drop_menu)
	_drop_menu.clear()
	_drop_menu.add_item(t("nb.recorte.tirar"), 0)
	_drop_menu.reset_size()
	var p := at if at.x >= 0.0 else get_viewport().get_mouse_position()
	var vp := get_viewport()
	if vp != null and vp.gui_embed_subwindows:
		_drop_menu.position = Vector2i(p)
	else:
		_drop_menu.position = Vector2i(get_viewport().get_screen_transform() * p)
	_drop_menu.popup()

func drop_menu() -> PopupMenu:
	return _drop_menu

func drop_clip(cid: String) -> Dictionary:
	if cid == "":
		return {"ok": false, "err": "no_existe"}
	var r := act({"t": "clip_drop", "clip": cid})
	if bool(r.get("ok", false)):
		say(t("nb.recorte.tirado"))
	elif String(r.get("err", "")) == "en_tinta":
		say(t("nb.recorte.en_tinta"))
	return r

func _unhandled_input(ev: InputEvent) -> void:
	if not _open or not is_visible_in_tree():
		return
	if handle_back and ev.is_action_pressed("fe_volver"):
		if _focus_is_text() and ev is InputEventKey:
			get_viewport().gui_release_focus()
		back()
		get_viewport().set_input_as_handled()
		return
	if handle_keys and ev.is_action_pressed("fe_tijera") and not _focus_is_text():
		if tab == "diario":
			_set_scissors(not _pages["diario"].scissors)
			get_viewport().set_input_as_handled()

func _focus_is_text() -> bool:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f is LineEdit or f is TextEdit

func _on_velo_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		close()
		accept_event()

func _on_overlay_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _overlay_panel != null:
		if not _overlay_panel.get_global_rect().has_point(_overlay.get_global_transform_with_canvas() * ev.position):
			_close_overlay()
			accept_event()

func _set_scissors(on: bool) -> void:
	if not _built:
		return
	_pages["diario"].set_scissors(on)
	_set_cursor(on and _open)

var _cursor_set := false
func _set_cursor(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if on:
		Input.set_custom_mouse_cursor(preload("res://ui/reader/document_reader.gd").scissors_texture(), Input.CURSOR_IBEAM, Vector2(3, 3))
		_cursor_set = true
	elif _cursor_set:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
		_cursor_set = false

# ------------------------------------------------------------------ señales
func _on_sim_changed(kind: String, _payload: Dictionary) -> void:
	if REFRESH_KINDS.has(kind):
		_queue_refresh()

func _on_session_started() -> void:
	clear_filters()
	_cache_look.clear()
	_queue_refresh()

func _on_theme_changed() -> void:
	if not _built:
		return
	_cache_look.clear()
	for tb in TABS:
		_tab_buttons[tb].text = t("nb.tab." + tb)
	_layout()
	_fit_tabs.call_deferred()   # por si los botones reciben el tema nuevo después de esta señal
	mark_all_dirty()
	if _open:
		_refresh_tab(tab)

func _on_vp_resized() -> void:
	_layout()
	mark_all_dirty()
	if _open:
		_queue_refresh()

# ------------------------------------------------------------------ utilidades
static func _autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

func _vp_size() -> Vector2:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size
	return Vector2(1600, 900)

func _font(slot: String, italic := false) -> Font:
	var ti := _autoload("ThemeInstaller")
	return ti.font(slot, italic) if ti != null else ThemeDB.fallback_font

func _px(kind: String) -> int:
	var ti := _autoload("ThemeInstaller")
	return int(ti.px(kind)) if ti != null else 17

func _sfx(id: String) -> void:
	if not sounds:
		return
	var au := _autoload("Audio")
	if au != null and au.has_method("play"):
		au.play(id)
