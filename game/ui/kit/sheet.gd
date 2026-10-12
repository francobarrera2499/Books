# ui/kit/sheet.gd — hoja de papel con contenido. Dueño: W1-THEME. Contrato: ARCHITECTURE §6.2.
# Uso: const Sheet = preload("res://ui/kit/sheet.gd"); var s = Sheet.new("libro_mayor", {"ruled": true, "margin_line": 64, "margin_double": true})
# PanelContainer que dibuja, por debajo de sus hijos: papel con borde y sombra (Paper.style), grano y manchas
# tileables (sin archivos), y si se pide renglones azules y margen rojo (simple o doble). Los márgenes de contenido
# salen de la variación de tema "Sheet" (o de opts.pad). Se redibuja con NOTIFICATION_THEME_CHANGED (alto contraste,
# escala) sin tocar overrides. Opciones: ruled, rule_step (px; 0 = 1,62 × px("doc")), rule_top, margin_line (x),
# margin_double, grain, shadow, pad (int: margen interior uniforme).
extends PanelContainer

const Paper = preload("res://ui/kit/paper.gd")

var paper_name := "cuaderno"
var ruled := false
var rule_step := 0.0
var rule_top := 0.0
var margin_line := 0.0
var margin_double := false
var grain := true
var shadow := true

func _init(p_paper := "cuaderno", opts := {}) -> void:
	paper_name = p_paper
	ruled = bool(opts.get("ruled", false))
	rule_step = float(opts.get("rule_step", 0.0))
	rule_top = float(opts.get("rule_top", 0.0))
	margin_line = float(opts.get("margin_line", 0.0))
	margin_double = bool(opts.get("margin_double", false))
	grain = bool(opts.get("grain", true))
	shadow = bool(opts.get("shadow", true))
	theme_type_variation = "Sheet"
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if opts.has("pad"):
		var p := float(opts["pad"])
		add_theme_stylebox_override("panel", Paper.empty([p, p * 0.8, p, p * 0.8]))

func set_paper(p_paper: String) -> void:
	paper_name = p_paper
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
		queue_redraw()

func line_step() -> float:
	if rule_step > 0.0:
		return rule_step
	var ti := Paper._ti()
	var px := 21.0 if ti == null else float(ti.px("doc"))
	return roundf(px * 1.62)

func _draw() -> void:
	var hc := Paper.hc_on()
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(Paper.style(paper_name, {"shadow": shadow, "margin": 0}), r)
	if not hc and grain:
		var inner := r.grow(-1.0)
		draw_texture_rect(Paper.mottle_texture(), inner, true, Color(1, 1, 1, 0.09))
		draw_texture_rect(Paper.grain_texture(), inner, true, Color(1, 1, 1, 0.06))
	if ruled:
		var col: Color = Color(0, 0, 0, 0.35) if hc else Color(Paper.RULE_BLUE, 0.5)
		var st := line_step()
		var y := rule_top if rule_top > 0.0 else st * 1.5
		while y < size.y - 6.0:
			draw_line(Vector2(6, y), Vector2(size.x - 6, y), col, 1.0)
			y += st
	if margin_line > 0.0:
		var mc: Color = Color(0, 0, 0, 0.55) if hc else Color(Paper.INKS["roja"], 0.5)
		draw_line(Vector2(margin_line, 3), Vector2(margin_line, size.y - 3), mc, 1.0)
		if margin_double:
			draw_line(Vector2(margin_line + 3, 3), Vector2(margin_line + 3, size.y - 3), mc, 1.0)
