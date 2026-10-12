# ui/reader/text_builder.gd — arma un RichTextLabel desde un ParsedText (§4.3). Dueño: W2-READER. Contrato: ARCHITECTURE §6.4.
# TextBuilder.build(rtl, parsed, opts := {}) -> void
#   Sólo add_text/push_*/pop, "\n" como único separador (sin [p] [ul] [table] [indent] [img], sin BBCode):
#   rtl.get_parsed_text() == parsed.plain (test_u_text_builder).
#   Por cada corrida de texto entre límites de estilo empuja, en este orden y sólo si hace falta:
#     fuente (ranura × itálica × negrita; tamaño por ranura) · color (tinta o marcador rasante) · tachado ·
#     efecto Remington (sólo texto en ranura "maquina" de un doc con machine) · efecto de versalitas (<sc>).
#   opts: slot ("imprenta"|"maquina"|"manuscrito"|"ui"; ranura base del bloque), size (px del cuerpo; por defecto
#         ThemeInstaller.px("doc") × factor de ranura), machine ("remington_cotter" o ""), hc (bool; por defecto
#         ThemeInstaller.high_contrast), fx (bool, true: efectos de máquina y versalitas), ti (nodo ThemeInstaller).
#   Devuelve (en meta del rtl): "fe_has_rasante" (bool), "fe_slot", "fe_size".
# Rasante (<rasante>, D29b): el texto se tiñe con MARKER (un verde que ninguna tinta usa); rasante.gdshader lo
# reconoce y dibuja sólo el relieve (surcos). En alto contraste se tiñe con la tinta "tenue" (texto tenue, sin shader).
# Colores fijos: quien use build() debe reconstruir en ThemeInstaller.theme_changed (lo hace DocumentReader).
extends RefCounted

const Paper = preload("res://ui/kit/paper.gd")
const FxRemington = preload("res://ui/reader/fx_remington.gd")
const FxSmallCaps = preload("res://ui/reader/fx_smallcaps.gd")

const MARKER := Color(0.0, 1.0, 0.0, 1.0)
const SLOT_FACTOR := {"imprenta": 1.0, "ui": 1.0, "maquina": 0.92, "manuscrito": 0.9}
const VARIATION := {"imprenta": "DocBody", "ui": "DocBody", "maquina": "DocTyped", "manuscrito": "DocHand"}
const SC_SPACING := 0.11          # espaciado extra de las versalitas (em)

static var _fx_rem: RichTextEffect = null
static var _fx_sc: RichTextEffect = null
static var _sc_fonts := {}        # "font_id|px" -> FontVariation con spacing_glyph

static func ti_node() -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null("ThemeInstaller")
	return null

static func variation(slot: String) -> String:
	return VARIATION.get(slot, "DocBody")

static func slot_size(slot: String, ti = null) -> int:
	var t = ti if ti != null else ti_node()
	var base := 21.0 if t == null else float(t.px("doc"))
	return int(round(base * float(SLOT_FACTOR.get(slot, 1.0))))

static func remington() -> RichTextEffect:
	if _fx_rem == null:
		_fx_rem = FxRemington.new()
	return _fx_rem

static func smallcaps() -> RichTextEffect:
	if _fx_sc == null:
		_fx_sc = FxSmallCaps.new()
	return _fx_sc

# Prepara un RichTextLabel de documento (lector y lupa): sin BBCode, sin menú, sin atajos, sin hilo, sin DnD.
static func make_rtl(slot := "imprenta") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.theme_type_variation = variation(slot)
	r.bbcode_enabled = false
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.selection_enabled = false
	r.drag_and_drop_selection_enabled = false
	r.context_menu_enabled = false
	r.shortcut_keys_enabled = false
	r.threaded = false
	r.deselect_on_focus_loss_enabled = true
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.focus_mode = Control.FOCUS_NONE
	return r

static func build(rtl: RichTextLabel, parsed: Dictionary, opts := {}) -> void:
	var ti = opts.get("ti", null)
	if ti == null:
		ti = ti_node()
	var slot := String(opts.get("slot", "imprenta"))
	if not SLOT_FACTOR.has(slot):
		slot = "imprenta"
	var hc: bool = bool(opts.get("hc", ti != null and bool(ti.high_contrast)))
	var machine := String(opts.get("machine", ""))
	var use_fx := bool(opts.get("fx", true))
	var base_px := int(opts.get("size", 0))
	var doc_px := 21.0 if ti == null else float(ti.px("doc"))
	if base_px > 0:
		doc_px = float(base_px) / float(SLOT_FACTOR.get(slot, 1.0))
	var plain: String = parsed.get("plain", "")
	var styles: Array = parsed.get("styles", [])
	rtl.clear()
	rtl.theme_type_variation = variation(slot)
	var px_base := int(round(doc_px * float(SLOT_FACTOR[slot])))
	rtl.add_theme_font_size_override("normal_font_size", px_base)
	rtl.add_theme_font_size_override("italics_font_size", px_base)
	rtl.add_theme_font_size_override("bold_font_size", px_base)
	rtl.add_theme_font_size_override("bold_italics_font_size", px_base)
	rtl.add_theme_font_size_override("mono_font_size", px_base)
	if use_fx and machine != "":
		var rem := remington()
		var has := false
		for e in rtl.custom_effects:
			if e == rem:
				has = true
		if not has:
			rtl.install_effect(rem)
	var cuts := {0: true, plain.length(): true}
	for s in styles:
		cuts[int(s.from)] = true
		cuts[int(s.to)] = true
	var pts: Array = cuts.keys()
	pts.sort()
	var has_rasante := false
	for k in range(pts.size() - 1):
		var a: int = pts[k]
		var b: int = pts[k + 1]
		if b <= a or a >= plain.length():
			continue
		# estado de la corrida: estilos que cubren [a, b) (están anidados; el orden de styles = orden de apertura)
		var st := {"slot": slot, "i": false, "b": false, "sc": false, "del": false, "ink": "", "rasante": false}
		for s in styles:
			if int(s.from) <= a and int(s.to) >= b and int(s.to) > int(s.from):
				match String(s.kind):
					"i": st.i = true
					"b": st.b = true
					"sc": st.sc = true
					"del": st.del = true
					"font":
						if SLOT_FACTOR.has(String(s.val)):
							st.slot = String(s.val)
					"ink": st.ink = String(s.val)
					"rasante": st.rasante = true
		var pushes := 0
		var run_px := int(round(doc_px * float(SLOT_FACTOR.get(st.slot, 1.0))))
		var font: Font = null
		if ti != null and (st.slot != slot or st.i or st.b or st.sc):
			font = ti.font_bold(st.slot, st.i) if st.b else ti.font(st.slot, st.i)
		if st.sc and use_fx and ti != null:
			font = _sc_font(font if font != null else ti.font(st.slot, st.i), run_px)
		if font != null:
			rtl.push_font(font, run_px)
			pushes += 1
		if st.rasante:
			has_rasante = true
			rtl.push_color(Paper.ink("tenue", 1) if hc else MARKER)
			pushes += 1
		elif st.ink != "":
			rtl.push_color(Paper.ink(st.ink, 1 if hc else 0))
			pushes += 1
		if st.del:
			rtl.push_strikethrough(Color(0, 0, 0, 0))
			pushes += 1
		if use_fx and machine != "" and st.slot == "maquina":
			rtl.push_customfx(remington(), {"size": run_px, "machine": machine})
			pushes += 1
		if use_fx and st.sc and ti != null:
			rtl.push_customfx(smallcaps(), {"size": run_px, "sp": _sc_sp(run_px)})
			pushes += 1
		rtl.add_text(plain.substr(a, b - a))
		for _p in pushes:
			rtl.pop()
	rtl.set_meta("fe_has_rasante", has_rasante)
	rtl.set_meta("fe_slot", slot)
	rtl.set_meta("fe_size", px_base)

static func _sc_sp(px: int) -> int:
	return maxi(1, int(round(float(px) * SC_SPACING)))

static func _sc_font(base: Font, px: int) -> Font:
	var key := "%d|%d" % [base.get_instance_id(), px]
	if _sc_fonts.has(key):
		return _sc_fonts[key]
	var fv := FontVariation.new()
	fv.base_font = base
	fv.spacing_glyph = _sc_sp(px)
	fv.fallbacks = []
	# sin ligaduras: «fi» tiene que llegar al efecto como dos glifos para volverse «FI»
	var ts := TextServerManager.get_primary_interface()
	fv.opentype_features = {ts.name_to_tag("liga"): 0, ts.name_to_tag("dlig"): 0, ts.name_to_tag("clig"): 0}
	if base.has_meta("fe_slot"):
		fv.set_meta("fe_slot", base.get_meta("fe_slot"))
	_sc_fonts[key] = fv
	return fv

static func clear_caches() -> void:
	_sc_fonts.clear()
