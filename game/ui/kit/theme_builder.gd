# ui/kit/theme_builder.gd — arma el Theme único del juego. Dueño: W1-THEME. Contrato: ARCHITECTURE §6.2.
# ThemeBuilder.build(ti) -> Theme  (ti = autoload ThemeInstaller: font(), font_bold(), px(), high_contrast)
# ThemeInstaller lo fusiona sobre ThemeDB.get_default_theme(): todo Control (también bajo CanvasLayer) lo hereda.
# Tipos base estilizados en papel/tinta (Label, Button, LineEdit, TextEdit, RichTextLabel, PanelContainer, Panel,
# PopupMenu, OptionButton, CheckBox, CheckButton, sliders, scrollbars, TabBar/TabContainer, ItemList, Tree, Tooltip,
# separadores, Window/AcceptDialog) y variaciones:
#   §6.2: DocBody DocTyped DocHand (RichTextLabel) · SourceLine Caption StampLabel Subtitle (Label) · PaperPanel SlotSegun
#         Chip (PanelContainer) · InkButton InkTab (Button)
#   extra: Heading SmallLabel ChipLabel Marginal Blank (Label) · Sheet (PanelContainer, panel vacío) · InkRule (HSeparator)
#          DocTitle (Label, título de documento) · ConfirmPanel (PanelContainer)
# Reglas de UI limpia (§6.1): sin brillos ni contornos de interés; el foco no se dibuja en botones (mouse primero).
extends RefCounted

const Paper = preload("res://ui/kit/paper.gd")

const VARIATIONS := {
	"DocBody": "RichTextLabel", "DocTyped": "RichTextLabel", "DocHand": "RichTextLabel",
	"SourceLine": "Label", "Caption": "Label", "PaperPanel": "PanelContainer", "InkButton": "Button",
	"InkTab": "Button", "SlotSegun": "PanelContainer", "Chip": "PanelContainer", "StampLabel": "Label",
	"Subtitle": "Label",
	"Heading": "Label", "DocTitle": "Label", "SmallLabel": "Label", "ChipLabel": "Label", "Marginal": "Label",
	"Blank": "Label", "Sheet": "PanelContainer", "InkRule": "HSeparator", "ConfirmPanel": "PanelContainer",
}
const REQUIRED := ["DocBody", "DocTyped", "DocHand", "SourceLine", "Caption", "PaperPanel", "InkButton", "InkTab",
	"SlotSegun", "Chip", "StampLabel", "Subtitle"]

static func build(ti) -> Theme:
	var hc: bool = ti.high_contrast
	var h := 1 if hc else 0
	var t := Theme.new()
	var ui: int = ti.px("ui")
	var doc: int = ti.px("doc")
	var small: int = ti.px("small")
	var title: int = ti.px("title")
	var cap: int = ti.px("caption")
	var negra := Paper.ink("negra", h)
	var lapiz := Paper.ink("lapiz", h)
	var tenue := Paper.ink("tenue", h)
	var roja := Paper.ink("roja", h)
	var cuaderno := Paper.paper("cuaderno", h)
	var sel: Color = Color(0, 0, 0, 0.22) if hc else Paper.SELECTION
	var f_ui: Font = ti.font("ui")
	var f_ui_i: Font = ti.font("ui", true)
	var f_imp: Font = ti.font("imprenta")
	var f_imp_i: Font = ti.font("imprenta", true)
	var f_mq: Font = ti.font("maquina")
	var f_hand: Font = ti.font("manuscrito")

	t.default_font = f_ui
	t.default_font_size = ui

	# --- Label y variaciones de Label
	_label(t, "Label", f_ui, ui, negra)
	t.set_constant("line_spacing", "Label", 2)
	for v in ["Heading", "DocTitle", "SourceLine", "Caption", "SmallLabel", "ChipLabel", "Marginal", "Blank", "StampLabel", "Subtitle"]:
		t.set_type_variation(v, VARIATIONS[v])
	_label(t, "Heading", f_imp, title, negra)
	_label(t, "DocTitle", f_imp, int(round(title * 0.82)), negra)
	_label(t, "SourceLine", f_imp_i, small, lapiz)
	_label(t, "Caption", f_imp_i, cap, negra)
	_label(t, "SmallLabel", f_ui, small, lapiz)
	_label(t, "ChipLabel", f_ui, small, negra)
	_label(t, "Marginal", f_hand, small, lapiz)
	t.set_constant("line_spacing", "Marginal", -int(round(small * 0.35)))
	_label(t, "Blank", f_ui, ui, negra)
	t.set_stylebox("normal", "Blank", Paper.flat(Color(0, 0, 0, 0), lapiz, [0, 0, 0, 1], 0, [4, 0, 4, 1]))
	_label(t, "StampLabel", f_imp, int(round(title * 0.78)), roja)
	t.set_stylebox("normal", "StampLabel", Paper.flat(Color(0, 0, 0, 0), roja, [3, 3, 3, 3], 7, [14, 1, 14, 3]))
	_label(t, "Subtitle", f_ui_i, ui, negra)
	var sub := Paper.style("cuaderno", {"margin": 18, "margin_v": 7, "radius": 3, "shadow_size": 5}, h)
	sub.bg_color.a = 1.0 if hc else 0.95
	t.set_stylebox("normal", "Subtitle", sub)

	# --- RichTextLabel (base y documentos)
	_rich(t, "RichTextLabel", f_ui, f_ui_i, ti.font_bold("ui"), ti.font_bold("ui", true), f_mq, ui, negra, sel, 3)
	for v in ["DocBody", "DocTyped", "DocHand"]:
		t.set_type_variation(v, "RichTextLabel")
	_rich(t, "DocBody", f_imp, f_imp_i, ti.font_bold("imprenta"), ti.font_bold("imprenta", true), f_mq, doc, negra, sel, int(round(doc * 0.2)))
	_rich(t, "DocTyped", f_mq, ti.font("maquina", true), ti.font_bold("maquina"), ti.font_bold("maquina", true), f_mq, int(round(doc * 0.92)), negra, sel, int(round(doc * 0.45)))
	_rich(t, "DocHand", f_hand, ti.font("manuscrito", true), ti.font_bold("manuscrito"), ti.font_bold("manuscrito", true), f_mq, int(round(doc * 0.9)), negra, sel, -int(round(doc * 0.3)))

	# --- Paneles
	t.set_stylebox("panel", "PanelContainer", Paper.style("cuaderno", {}, h))
	t.set_stylebox("panel", "Panel", Paper.style("cuaderno", {}, h))
	t.set_type_variation("PaperPanel", "PanelContainer")
	t.set_stylebox("panel", "PaperPanel", Paper.style("cuaderno", {"margin": 22}, h))
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", Paper.empty([28, 22, 28, 22]))
	t.set_type_variation("ConfirmPanel", "PanelContainer")
	t.set_stylebox("panel", "ConfirmPanel", Paper.style("carta", {"margin": 28, "shadow_size": 14, "shadow_y": 6}, h))
	t.set_type_variation("SlotSegun", "PanelContainer")
	var slot := Paper.flat(Color(0, 0, 0, 0.0) if hc else Color(Paper.INKS["tenue"], 0.07), lapiz, [1, 0, 0, 1], 0, [10, 3, 10, 3])
	t.set_stylebox("panel", "SlotSegun", slot)
	t.set_type_variation("Chip", "PanelContainer")
	var chip := Paper.style("diario_hueso", {"margin": 9, "margin_v": 3, "radius": 1, "shadow_size": 2, "shadow_y": 1}, h)
	t.set_stylebox("panel", "Chip", chip)
	t.set_stylebox("panel", "ScrollContainer", Paper.empty())

	# --- Botones
	var btn_n := Paper.flat(Paper.shade("cuaderno", 0.035, h), Color(tenue, 0.9), [1, 1, 1, 1], 3, [16, 5, 16, 6])
	var btn_h := Paper.flat(Paper.shade("cuaderno", 0.075, h), negra, [1, 1, 1, 1], 3, [16, 5, 16, 6])
	var btn_p := Paper.flat(Paper.shade("cuaderno", 0.13, h), negra, [1, 1, 1, 1], 3, [16, 6, 16, 5])
	var btn_d := Paper.flat(Color(0, 0, 0, 0), Color(tenue, 0.5), [1, 1, 1, 1], 3, [16, 5, 16, 6])
	for ty in ["Button", "OptionButton", "MenuButton", "ColorPickerButton"]:
		_button(t, ty, f_ui, ui, negra, tenue, btn_n, btn_h, btn_p, btn_d)
	t.set_icon("arrow", "OptionButton", Paper.icon("chevron_down", ui, negra))
	t.set_constant("arrow_margin", "OptionButton", 8)
	t.set_type_variation("InkButton", "Button")
	var ink_n := Paper.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), [0, 0, 0, 1], 0, [6, 3, 6, 4])
	var ink_h := Paper.flat(Color(0, 0, 0, 0), lapiz, [0, 0, 0, 1], 0, [6, 3, 6, 4])
	var ink_p := Paper.flat(Color(0, 0, 0, 0), negra, [0, 0, 0, 2], 0, [6, 3, 6, 3])
	_button(t, "InkButton", f_imp, ui, negra, tenue, ink_n, ink_h, ink_p, ink_n)
	t.set_color("font_hover_color", "InkButton", negra)
	t.set_type_variation("InkTab", "Button")
	var tab_un := _tab_box(Paper.shade("cuaderno", 0.075, h), Paper.edge("cuaderno", h), false)
	var tab_hv := _tab_box(Paper.shade("cuaderno", 0.035, h), Paper.edge("cuaderno", h), false)
	var tab_se := _tab_box(cuaderno, Paper.edge("cuaderno", h), true)
	_button(t, "InkTab", f_imp, ui, negra, tenue, tab_un, tab_hv, tab_se, tab_un)
	t.set_color("font_color", "InkTab", lapiz)
	t.set_stylebox("hover_pressed", "InkTab", tab_se)
	t.set_color("font_pressed_color", "InkTab", negra)
	t.set_color("font_hover_pressed_color", "InkTab", negra)
	_button(t, "LinkButton", f_ui, ui, negra, tenue, Paper.empty(), Paper.empty(), Paper.empty(), Paper.empty())

	# --- Casillas
	var isz := int(round(ui * 1.05))
	for ty in ["CheckBox", "CheckButton"]:
		_button(t, ty, f_ui, ui, negra, tenue, Paper.empty([2, 2, 2, 2]), Paper.empty([2, 2, 2, 2]), Paper.empty([2, 2, 2, 2]), Paper.empty([2, 2, 2, 2]))
		t.set_icon("checked", ty, Paper.icon("box_checked", isz, negra))
		t.set_icon("unchecked", ty, Paper.icon("box", isz, negra))
		t.set_icon("checked_disabled", ty, Paper.icon("box_checked", isz, tenue))
		t.set_icon("unchecked_disabled", ty, Paper.icon("box", isz, tenue))
		t.set_constant("h_separation", ty, 6)
	t.set_icon("radio_checked", "CheckBox", Paper.icon("radio_checked", isz, negra))
	t.set_icon("radio_unchecked", "CheckBox", Paper.icon("radio", isz, negra))
	t.set_icon("radio_checked_disabled", "CheckBox", Paper.icon("radio_checked", isz, tenue))
	t.set_icon("radio_unchecked_disabled", "CheckBox", Paper.icon("radio", isz, tenue))

	# --- Campos de texto: renglón a lápiz
	var le_n := Paper.flat(Color(0, 0, 0, 0), lapiz, [0, 0, 0, 1], 0, [4, 3, 4, 4])
	var le_f := Paper.flat(Color(0, 0, 0, 0.0), negra, [0, 0, 0, 2], 0, [4, 3, 4, 3])
	var le_ro := Paper.flat(Color(0, 0, 0, 0), Color(tenue, 0.6), [0, 0, 0, 1], 0, [4, 3, 4, 4])
	for ty in ["LineEdit", "TextEdit"]:
		t.set_font("font", ty, f_ui)
		t.set_font_size("font_size", ty, ui)
		t.set_color("font_color", ty, negra)
		t.set_color("font_placeholder_color", ty, tenue)
		t.set_color("font_uneditable_color", ty, lapiz)
		t.set_color("font_selected_color", ty, negra)
		t.set_color("caret_color", ty, negra)
		t.set_color("selection_color", ty, sel)
		t.set_color("clear_button_color", ty, lapiz)
		t.set_color("clear_button_color_pressed", ty, negra)
		t.set_stylebox("normal", ty, le_n)
		t.set_stylebox("focus", ty, le_f)
		t.set_stylebox("read_only", ty, le_ro)
	t.set_stylebox("normal", "TextEdit", Paper.flat(Color(1, 1, 1, 0.0) if hc else Color(1, 1, 1, 0.22), Color(tenue, 0.8), [1, 1, 1, 1], 2, [8, 6, 8, 6]))
	t.set_stylebox("focus", "TextEdit", Paper.flat(Color(0, 0, 0, 0), negra, [1, 1, 1, 1], 2, [8, 6, 8, 6]))
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	t.set_color("current_line_color", "TextEdit", Color(0, 0, 0, 0))

	# --- Menús emergentes y tooltips
	var pop := Paper.style("carta", {"margin": 6, "shadow_size": 8}, h)
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("panel", "PopupPanel", pop)
	t.set_stylebox("hover", "PopupMenu", Paper.flat(Paper.shade("carta", 0.08, h), Color(0, 0, 0, 0), [0, 0, 0, 0], 2))
	t.set_stylebox("separator", "PopupMenu", _line(Color(tenue, 0.7)))
	t.set_stylebox("labeled_separator_left", "PopupMenu", _line(Color(tenue, 0.7)))
	t.set_stylebox("labeled_separator_right", "PopupMenu", _line(Color(tenue, 0.7)))
	t.set_font("font", "PopupMenu", f_ui)
	t.set_font("font_separator", "PopupMenu", f_ui_i)
	t.set_font_size("font_size", "PopupMenu", ui)
	t.set_font_size("font_separator_size", "PopupMenu", small)
	for c in ["font_color", "font_hover_color", "font_accelerator_color", "font_separator_color"]:
		t.set_color(c, "PopupMenu", negra if c != "font_accelerator_color" else lapiz)
	t.set_color("font_disabled_color", "PopupMenu", tenue)
	t.set_constant("v_separation", "PopupMenu", 6)
	t.set_constant("item_start_padding", "PopupMenu", 10)
	t.set_constant("item_end_padding", "PopupMenu", 10)
	t.set_icon("checked", "PopupMenu", Paper.icon("box_checked", isz, negra))
	t.set_icon("unchecked", "PopupMenu", Paper.icon("box", isz, negra))
	t.set_icon("radio_checked", "PopupMenu", Paper.icon("radio_checked", isz, negra))
	t.set_icon("radio_unchecked", "PopupMenu", Paper.icon("radio", isz, negra))
	t.set_icon("submenu", "PopupMenu", Paper.icon("chevron_right", isz, negra))
	t.set_stylebox("panel", "TooltipPanel", Paper.style("carta", {"margin": 10, "margin_v": 6, "shadow_size": 4}, h))
	t.set_font("font", "TooltipLabel", f_ui)
	t.set_font_size("font_size", "TooltipLabel", small)
	t.set_color("font_color", "TooltipLabel", negra)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))

	# --- Sliders y barras
	for ty in ["HSlider", "VSlider"]:
		var horiz: bool = ty == "HSlider"
		var line := Paper.flat(Color(tenue, 0.8), Color(0, 0, 0, 0), [0, 0, 0, 0], 1, [0, 1, 0, 1] if horiz else [1, 0, 1, 0])
		var fill := Paper.flat(negra, Color(0, 0, 0, 0), [0, 0, 0, 0], 1, [0, 1, 0, 1] if horiz else [1, 0, 1, 0])
		t.set_stylebox("slider", ty, line)
		t.set_stylebox("grabber_area", ty, fill)
		t.set_stylebox("grabber_area_highlight", ty, fill)
		t.set_icon("grabber", ty, Paper.icon("dot", isz, negra))
		t.set_icon("grabber_highlight", ty, Paper.icon("dot_ring", isz, negra))
		t.set_icon("grabber_disabled", ty, Paper.icon("dot", isz, tenue))
	for ty in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", ty, Paper.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), [0, 0, 0, 0], 0, [4, 4, 4, 4]))
		t.set_stylebox("scroll_focus", ty, Paper.flat(Color(0, 0, 0, 0), Color(0, 0, 0, 0), [0, 0, 0, 0], 0, [4, 4, 4, 4]))
		t.set_stylebox("grabber", ty, Paper.flat(Color(tenue, 0.55), Color(0, 0, 0, 0), [0, 0, 0, 0], 3, [3, 3, 3, 3]))
		t.set_stylebox("grabber_highlight", ty, Paper.flat(Color(lapiz, 0.7), Color(0, 0, 0, 0), [0, 0, 0, 0], 3, [3, 3, 3, 3]))
		t.set_stylebox("grabber_pressed", ty, Paper.flat(Color(negra, 0.8), Color(0, 0, 0, 0), [0, 0, 0, 0], 3, [3, 3, 3, 3]))
	t.set_stylebox("background", "ProgressBar", Paper.flat(Color(tenue, 0.25), Color(tenue, 0.8), [1, 1, 1, 1], 2))
	t.set_stylebox("fill", "ProgressBar", Paper.flat(Color(negra, 0.8), Color(0, 0, 0, 0), [0, 0, 0, 0], 2))
	t.set_color("font_color", "ProgressBar", negra)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0))

	# --- Pestañas (TabBar / TabContainer) con la misma forma que InkTab
	for ty in ["TabBar", "TabContainer"]:
		t.set_font("font", ty, f_imp)
		t.set_font_size("font_size", ty, ui)
		t.set_color("font_selected_color", ty, negra)
		t.set_color("font_hovered_color", ty, negra)
		t.set_color("font_unselected_color", ty, lapiz)
		t.set_color("font_disabled_color", ty, tenue)
		t.set_color("font_outline_color", ty, Color(0, 0, 0, 0))
		t.set_stylebox("tab_selected", ty, tab_se)
		t.set_stylebox("tab_unselected", ty, tab_un)
		t.set_stylebox("tab_hovered", ty, tab_hv)
		t.set_stylebox("tab_disabled", ty, tab_un)
		t.set_stylebox("tab_focus", ty, Paper.empty())
		t.set_constant("h_separation", ty, 4)
	t.set_stylebox("panel", "TabContainer", Paper.style("cuaderno", {"radius": 1}, h))
	t.set_stylebox("tabbar_background", "TabContainer", Paper.empty())

	# --- Listas
	for ty in ["ItemList", "Tree"]:
		t.set_font("font", ty, f_ui)
		t.set_font_size("font_size", ty, ui)
		t.set_color("font_color", ty, negra)
		t.set_color("font_selected_color", ty, negra)
		t.set_color("font_hovered_color", ty, negra)
		t.set_color("guide_color", ty, Color(tenue, 0.4))
		t.set_stylebox("panel", ty, Paper.empty([4, 4, 4, 4]))
		t.set_stylebox("focus", ty, Paper.empty())
		t.set_stylebox("selected", ty, Paper.flat(sel, Color(0, 0, 0, 0)))
		t.set_stylebox("selected_focus", ty, Paper.flat(sel, Color(0, 0, 0, 0)))
		t.set_stylebox("hovered", ty, Paper.flat(Color(negra, 0.06), Color(0, 0, 0, 0)))
		t.set_stylebox("cursor", ty, Paper.empty())
		t.set_stylebox("cursor_unfocused", ty, Paper.empty())
	t.set_font("title_button_font", "Tree", f_ui_i)
	t.set_color("title_button_color", "Tree", negra)

	# --- Separadores y reglas
	for ty in ["HSeparator", "VSeparator"]:
		var sl := StyleBoxLine.new()
		sl.color = Color(tenue, 0.8)
		sl.thickness = 1
		sl.vertical = ty == "VSeparator"
		t.set_stylebox("separator", ty, sl)
		t.set_constant("separation", ty, 10)
	t.set_type_variation("InkRule", "HSeparator")
	var rule := StyleBoxLine.new()
	rule.color = negra
	rule.thickness = 1
	t.set_stylebox("separator", "InkRule", rule)
	t.set_constant("separation", "InkRule", 14)

	# --- Ventanas incrustadas (por si algún WP usa AcceptDialog)
	t.set_stylebox("embedded_border", "Window", Paper.style("carta", {"margin": 8, "shadow_size": 10}, h))
	t.set_stylebox("embedded_unfocused_border", "Window", Paper.style("carta", {"margin": 8, "shadow_size": 10}, h))
	t.set_font("title_font", "Window", f_imp)
	t.set_font_size("title_font_size", "Window", ui)
	t.set_color("title_color", "Window", negra)
	t.set_color("title_outline_modulate", "Window", Color(0, 0, 0, 0))
	t.set_icon("close", "Window", Paper.icon("cross", isz, negra))
	t.set_icon("close_pressed", "Window", Paper.icon("cross", isz, lapiz))
	t.set_stylebox("panel", "AcceptDialog", Paper.style("carta", {"margin": 12, "shadow": false}, h))

	# --- Otros tipos con fuente propia en el tema por defecto (todas las ranuras sin fallback del sistema)
	for ty in ["MenuBar", "GraphNodeTitleLabel", "GraphFrameTitleLabel", "FoldableContainer", "CodeEdit", "ProgressBar"]:
		t.set_font("font", ty, f_ui)
		t.set_font_size("font_size", ty, ui)
	t.set_font_size("title_button_font_size", "Tree", ui)
	# tamaños fijos del tema por defecto de Godot (variaciones Header* de Label): también siguen text_scale
	var sc: float = ti.text_scale
	for hv in [["HeaderSmall", 20], ["HeaderMedium", 24], ["HeaderLarge", 28]]:
		t.set_type_variation(hv[0], "Label")
		_label(t, hv[0], f_imp, int(round(hv[1] * sc)), negra)
	t.set_color("font_color", "MenuBar", negra)
	t.set_color("font_color", "FoldableContainer", negra)
	return t

static func _label(t: Theme, ty: String, f: Font, sz: int, col: Color) -> void:
	t.set_font("font", ty, f)
	t.set_font_size("font_size", ty, sz)
	t.set_color("font_color", ty, col)
	t.set_color("font_shadow_color", ty, Color(0, 0, 0, 0))
	t.set_color("font_outline_color", ty, Color(0, 0, 0, 0))
	t.set_constant("outline_size", ty, 0)
	if not t.has_stylebox("normal", ty):
		t.set_stylebox("normal", ty, Paper.empty())

static func _rich(t: Theme, ty: String, n: Font, i: Font, b: Font, bi: Font, mono: Font, sz: int, col: Color, sel: Color, ls: int) -> void:
	t.set_font("normal_font", ty, n)
	t.set_font("italics_font", ty, i)
	t.set_font("bold_font", ty, b)
	t.set_font("bold_italics_font", ty, bi)
	t.set_font("mono_font", ty, mono)
	for k in ["normal_font_size", "italics_font_size", "bold_font_size", "bold_italics_font_size", "mono_font_size"]:
		t.set_font_size(k, ty, sz)
	t.set_color("default_color", ty, col)
	t.set_color("font_selected_color", ty, col)
	t.set_color("selection_color", ty, sel)
	t.set_color("font_shadow_color", ty, Color(0, 0, 0, 0))
	t.set_color("font_outline_color", ty, Color(0, 0, 0, 0))
	t.set_constant("line_separation", ty, ls)
	t.set_constant("outline_size", ty, 0)
	t.set_stylebox("normal", ty, Paper.empty())
	t.set_stylebox("focus", ty, Paper.empty())

static func _button(t: Theme, ty: String, f: Font, sz: int, col: Color, dis: Color, n: StyleBox, hv: StyleBox, p: StyleBox, d: StyleBox) -> void:
	t.set_font("font", ty, f)
	t.set_font_size("font_size", ty, sz)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, ty, col)
	t.set_color("font_disabled_color", ty, dis)
	t.set_color("font_outline_color", ty, Color(0, 0, 0, 0))
	t.set_color("icon_normal_color", ty, col)
	t.set_color("icon_hover_color", ty, col)
	t.set_color("icon_pressed_color", ty, col)
	t.set_color("icon_disabled_color", ty, dis)
	t.set_stylebox("normal", ty, n)
	t.set_stylebox("hover", ty, hv)
	t.set_stylebox("pressed", ty, p)
	t.set_stylebox("hover_pressed", ty, p)
	t.set_stylebox("disabled", ty, d)
	t.set_stylebox("focus", ty, Paper.empty())
	t.set_constant("h_separation", ty, 6)

static func _tab_box(bg: Color, border: Color, selected: bool) -> StyleBoxFlat:
	var sb := Paper.flat(bg, border, [1, 1, 1, 0 if selected else 1], 0, [18, 5 if selected else 4, 18, 6 if selected else 4])
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.anti_aliasing = true
	if not selected:
		sb.expand_margin_top = -2.0
	return sb

static func _line(col: Color) -> StyleBoxLine:
	var sl := StyleBoxLine.new()
	sl.color = col
	sl.thickness = 1
	sl.grow_begin = -6.0
	sl.grow_end = -6.0
	return sl
