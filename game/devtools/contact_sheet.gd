# devtools/contact_sheet.gd — hoja de contacto 3x2 de las 6 tomas de referencia de un look (devtools/drivers/look_compare.gd).
#   ./godot.sh --headless -s devtools/contact_sheet.gd -- <id> [<id> ...]     (sin ids: todo look con look_<id>_1.png)
# Lee .work/shots/look_<id>_<n>.png (n = 1..6) y look_<id>.json (rótulo y preset de luz por toma, opcional) y escribe
# .work/shots/sheet_<id>.png: encabezado con el id y el nombre del look, tomas a la mitad (800x450, caja 2x2) con su
# número, rótulo y preset. Texto con IM Fell (assets/fonts) rasterizado en CPU por el TextServer: corre en headless.
extends SceneTree

const Looks = preload("res://world/post/looks.gd")
const LC = preload("res://devtools/drivers/look_compare.gd")

const CELL := Vector2i(800, 450)
const GAP := 14
const HEAD := 64
const CAP := 34
const BG := Color("34302b")
const FG := Color("f2ede3")
const DIM := Color("b9b1a3")
const FONT := "res://assets/fonts/IMFeENrm28P.ttf"
const FONT_IT := "res://assets/fonts/IMFeENit28P.ttf"

var _fonts := {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var dir := LC.shots_dir()
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if not String(a).begins_with("--"):
			ids.append(String(a))
	if ids.is_empty():
		for f in DirAccess.get_files_at(dir):
			if f.begins_with("look_") and f.ends_with("_1.png"):
				ids.append(f.trim_prefix("look_").trim_suffix("_1.png"))
	var rc := 0
	for id in ids:
		var out := make_sheet(str(id), dir)
		if out == "":
			rc = 1
		else:
			print("HOJA ", out)
	quit(rc)

func make_sheet(id: String, dir: String) -> String:
	var meta := {}
	var mp := dir.path_join("look_%s.json" % id)
	if FileAccess.file_exists(mp):
		var d = JSON.parse_string(FileAccess.get_file_as_string(mp))
		if d is Dictionary:
			meta = d
	var shots: Array = meta.get("shots", [])
	var w := 3 * CELL.x + 4 * GAP
	var h := HEAD + 2 * (CELL.y + CAP) + 3 * GAP
	var sheet := Image.create(w, h, false, Image.FORMAT_RGB8)
	sheet.fill(BG)
	var nm := str(meta.get("name", Looks.label(id) if Looks.has(id) else id))
	var x := draw_text(sheet, "Look: %s" % id, Vector2i(GAP, 44), 36, FG, false)
	draw_text(sheet, "— %s" % nm, Vector2i(x + 16, 44), 30, DIM, true)
	var found := 0
	for n in range(1, 7):
		var col := (n - 1) % 3
		var row := (n - 1) / 3
		var pos := Vector2i(GAP + col * (CELL.x + GAP), HEAD + GAP + row * (CELL.y + CAP + GAP))
		var p := dir.path_join("look_%s_%d.png" % [id, n])
		var cap := str((LC.SHOTS[n - 1] as Array)[7]) if n - 1 < LC.SHOTS.size() else ""
		var preset := ""
		for s in shots:
			if s is Dictionary and int(s.get("n", 0)) == n:
				cap = str(s.get("caption", cap))
				preset = str(s.get("preset", ""))
		if FileAccess.file_exists(p):
			var im := Image.load_from_file(p)
			im.convert(Image.FORMAT_RGB8)
			if im.get_size() == CELL * 2:
				im.shrink_x2()
			elif im.get_size() != CELL:
				im.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, CELL), pos)
			found += 1
		else:
			sheet.fill_rect(Rect2i(pos, CELL), Color("5a2a2a"))
			draw_text(sheet, "falta look_%s_%d.png" % [id, n], pos + Vector2i(20, 40), 24, FG, false)
		var cx := draw_text(sheet, "%d · %s" % [n, cap], pos + Vector2i(0, CELL.y + 25), 22, FG, false)
		if preset != "":
			draw_text(sheet, "(%s)" % preset, Vector2i(cx + 10, pos.y + CELL.y + 25), 20, DIM, true)
	if found == 0:
		printerr("contact_sheet: no hay tomas look_%s_*.png en %s" % [id, dir])
		return ""
	var out := dir.path_join("sheet_%s.png" % id)
	sheet.save_png(out)
	return out

# Texto sobre una Image (línea base en pos.y) con los glifos del TextServer (CPU). Devuelve la x final.
func draw_text(img: Image, text: String, pos: Vector2i, px: int, color: Color, italic: bool) -> int:
	var ts := TextServerManager.get_primary_interface()
	var font := _font(italic)
	if font == null:
		return pos.x
	# texto conformado (HarfBuzz: avances y kerning de la fuente); cada glifo se rasteriza en la caché del TextServer
	var sh := ts.create_shaped_text()
	ts.shaped_text_add_string(sh, text, font.get_rids(), px)
	var x := float(pos.x)
	for gl in ts.shaped_text_get_glyphs(sh):
		var rid: RID = gl.get("font_rid", RID())
		var g := int(gl.get("index", 0))
		var gx := x + (gl.get("offset", Vector2.ZERO) as Vector2).x
		if rid.is_valid() and g != 0:
			var sz := Vector2i(int(gl.get("font_size", px)), 0)
			ts.font_render_glyph(rid, sz, g)
			var ti := ts.font_get_glyph_texture_idx(rid, sz, g)
			if ti >= 0:
				var uv := ts.font_get_glyph_uv_rect(rid, sz, g)
				var off := ts.font_get_glyph_offset(rid, sz, g)
				var gsz := ts.font_get_glyph_size(rid, sz, g)
				var tex: Image = ts.font_get_texture_image(rid, sz, ti)
				if tex != null and uv.size.x > 0 and uv.size.y > 0:
					_blit_glyph(img, tex, Rect2i(uv), Vector2(gx, pos.y) + off, gsz, color)
		x += float(gl.get("advance", 0.0)) * int(gl.get("repeat", 1))
	ts.free_rid(sh)
	return int(ceil(x))

func _blit_glyph(img: Image, tex: Image, uv: Rect2i, at: Vector2, gsz: Vector2, color: Color) -> void:
	var sx := float(uv.size.x) / maxf(1.0, gsz.x)
	var sy := float(uv.size.y) / maxf(1.0, gsz.y)
	var w := int(round(gsz.x))
	var h := int(round(gsz.y))
	var ox := int(round(at.x))
	var oy := int(round(at.y))
	for yy in h:
		for xx in w:
			var tx := uv.position.x + int(xx * sx)
			var ty := uv.position.y + int(yy * sy)
			if tx < 0 or ty < 0 or tx >= tex.get_width() or ty >= tex.get_height():
				continue
			var a := tex.get_pixel(tx, ty).a
			if a <= 0.0:
				continue
			var px := ox + xx
			var py := oy + yy
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(color, a))

func _font(italic: bool) -> FontFile:
	var key := "it" if italic else "rm"
	if _fonts.has(key):
		return _fonts[key]
	var f := FontFile.new()
	var path := FONT_IT if italic else FONT
	if f.load_dynamic_font(path) != OK:
		# importado (sin el .ttf suelto): los bytes del recurso
		var imp = load(path)
		if imp is FontFile:
			f.data = (imp as FontFile).data
	f.multichannel_signed_distance_field = false
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.allow_system_fallback = false
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_fonts[key] = f
	return f
