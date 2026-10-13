# Autoload ThemeInstaller. Dueño: W1-THEME. Contrato: docs/ARCHITECTURE.md §2.2 y §6.2.
# Fuentes por ranura desde data/fonts.json (lectura directa, excepción §2.1): FontFile.new() + load_dynamic_font(path)
# (si el .ttf no está como archivo suelto, p. ej. exportado, se copia el `data` del FontFile importado), o
# "embedded" = copia de los bytes de la fuente embebida de Godot (capturados antes de reemplazar el fallback).
# Cada FontFile: allow_system_fallback=false, MSDF, fallbacks=[] (salvo la copia SIN MSDF, rasterizada a 3×, que usan
# las negritas: embolden sobre MSDF deja artefactos con IM Fell). Cada ranura se entrega como FontVariation
# (máquina: liga=0; itálica sin archivo: variation_transform con inclinación 0,2; negrita: variation_embolden 0,6).
# install(): arma el Theme (ui/kit/theme_builder.gd), lo fusiona en ThemeDB.get_default_theme(), reemplaza toda fuente
# ajena del tema por defecto e instala ThemeDB.fallback_font (no root.theme). Nunca push_error: avisos con L.w.
# API extra (no contractual): font_bold(slot, italic), slot_paths(), reload_config(), is_ours(font), root_file(font).
extends Node

const L = preload("res://core/util/log.gd")
const ThemeBuilder = preload("res://ui/kit/theme_builder.gd")

signal theme_changed

const SLOTS := ["imprenta", "maquina", "manuscrito", "ui"]
const FONTS_JSON := "res://data/fonts.json"
const BASE_PX := {"doc": 21, "ui": 19, "small": 15, "title": 34, "caption": 16}
const SLANT := 0.2
const EMBOLDEN := 0.6
# Las negritas van sobre una copia rasterizada (sin MSDF); se rasterizan a 3× para que el zoom del lector (hasta 300 %,
# Control.scale) y la lupa no las muestren borrosas junto al texto MSDF (verificado en captura).
const RASTER_OVERSAMPLING := 3.0

static var _embedded_data := PackedByteArray()   # bytes de la fuente embebida original (proceso)

var theme: Theme = null          # Theme compartido (type variations de §6.2), ya fusionado en el tema por defecto
var text_scale := 1.0            # accesibilidad: 0.8..1.6
var high_contrast := false

var _slots := {}                 # slot -> {"file": path, "italic": path?}
var _config := {}                # copia de las ranuras de fonts.json (para restaurar la itálica propia en set_slot)
var _fallback := "embedded"
var _files := {}                 # path -> FontFile
var _fonts := {}                 # "slot|i|b" -> FontVariation

func _ready() -> void:
	install()

# ------------------------------------------------------------------ API contractual

func install() -> void:
	_capture_embedded()
	if _slots.is_empty():
		_load_config()
	if _fonts.is_empty():
		_build_fonts()
	theme = ThemeBuilder.build(self)
	var dt := ThemeDB.get_default_theme()
	if dt != null:
		dt.merge_with(theme)
		dt.default_font = font("ui")
		dt.default_font_size = px("ui")
		_replace_foreign_fonts(dt)
	ThemeDB.fallback_font = font("ui")
	ThemeDB.fallback_font_size = px("ui")
	theme_changed.emit()

func font(slot: String, italic := false) -> Font:
	return _font_for(slot, italic, false)

func set_slot(slot: String, path: String) -> void:
	if not SLOTS.has(slot):
		L.w("theme", "ranura desconocida: %s" % slot)
		return
	if _slots.is_empty():
		_load_config()
	var entry := {"file": path}
	# si el archivo es uno que fonts.json empareja con su itálica (p. ej. volver de "embedded" a IM Fell), se conserva
	# esa itálica en vez de sintetizarla
	for s in SLOTS:
		var c: Dictionary = _config.get(s, {})
		if str(c.get("file", "")) == path and c.has("italic"):
			entry["italic"] = str(c["italic"])
			break
	_slots[slot] = entry
	_fonts.clear()
	install()

func set_text_scale(f: float) -> void:
	text_scale = clampf(f, 0.8, 1.6)
	install()

func set_high_contrast(on: bool) -> void:
	high_contrast = on
	install()

func px(kind: String) -> int:
	return int(round(float(BASE_PX.get(kind, BASE_PX["ui"])) * text_scale))

# ------------------------------------------------------------------ API extra

func font_bold(slot: String, italic := false) -> Font:
	return _font_for(slot, italic, true)

func slot_paths() -> Dictionary:
	if _slots.is_empty():
		_load_config()
	return _slots.duplicate(true)

# Relee data/fonts.json (descarta set_slot previos) y reinstala.
func reload_config() -> void:
	_slots.clear()
	_fonts.clear()
	_load_config()
	install()

static func is_ours(f: Font) -> bool:
	return f != null and f.has_meta("fe_slot")

# Recorre base_font hasta el FontFile raíz (o null).
static func root_file(f: Font) -> FontFile:
	var cur: Font = f
	var guard := 0
	while cur != null and guard < 8:
		if cur is FontFile:
			return cur
		if cur is FontVariation:
			cur = (cur as FontVariation).base_font
		else:
			return null
		guard += 1
	return null

static func embedded_size() -> int:
	return _embedded_data.size()

# ------------------------------------------------------------------ interno

func _capture_embedded() -> void:
	if _embedded_data.size() > 0:
		return
	var fb := ThemeDB.fallback_font
	if fb is FontFile and not fb.has_meta("fe_slot"):
		_embedded_data = (fb as FontFile).data
	if _embedded_data.size() == 0:
		var dt := ThemeDB.get_default_theme()
		if dt != null and dt.default_font is FontFile and not dt.default_font.has_meta("fe_slot"):
			_embedded_data = (dt.default_font as FontFile).data

func _load_config() -> void:
	_slots.clear()
	var cfg = null
	if FileAccess.file_exists(FONTS_JSON):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(FONTS_JSON))
	if cfg is Dictionary and cfg.get("slots") is Dictionary:
		_fallback = str(cfg.get("fallback", "embedded"))
		for s in SLOTS:
			var e = cfg["slots"].get(s)
			if e is Dictionary and e.has("file"):
				_slots[s] = {"file": str(e["file"])}
				if e.has("italic"):
					_slots[s]["italic"] = str(e["italic"])
			else:
				_slots[s] = {"file": _fallback}
	else:
		L.w("theme", "fonts.json ausente o inválido: se usa la fuente embebida")
		_fallback = "embedded"
		for s in SLOTS:
			_slots[s] = {"file": "embedded"}
	_config = _slots.duplicate(true)

func _file(path: String) -> FontFile:
	if _files.has(path):
		return _files[path]
	var ff := FontFile.new()
	var ok := false
	if path == "embedded":
		ff.data = _embedded_data
		ok = _embedded_data.size() > 0
	elif FileAccess.file_exists(path):
		ok = ff.load_dynamic_font(path) == OK
	elif ResourceLoader.exists(path):
		var res = load(path)
		if res is FontFile and (res as FontFile).data.size() > 0:
			ff.data = (res as FontFile).data
			ok = true
	if not ok:
		if path != "embedded":
			L.w("theme", "no se pudo cargar %s: se usa %s" % [path, _fallback])
			var alt := _fallback if _fallback != path else "embedded"
			var alt_ff := _file(alt)
			_files[path] = alt_ff
			return alt_ff
		L.w("theme", "fuente embebida no disponible")
	ff.allow_system_fallback = false
	ff.multichannel_signed_distance_field = true
	ff.fallbacks = []
	ff.set_meta("fe_slot", "file")
	ff.set_meta("fe_src", path)
	_files[path] = ff
	return ff

# Copia sin MSDF del mismo FontFile, para las negritas: variation_embolden sobre MSDF deja artefactos
# (contornos superpuestos de IM Fell; verificado en captura w1theme_x_bold). Mismos datos, sin fallback del sistema.
func _raster(path: String) -> FontFile:
	var key := path + "|raster"
	if _files.has(key):
		return _files[key]
	var src := _file(path)
	var ff := FontFile.new()
	ff.data = src.data
	ff.allow_system_fallback = false
	ff.multichannel_signed_distance_field = false
	ff.oversampling = RASTER_OVERSAMPLING
	ff.fallbacks = []
	ff.set_meta("fe_slot", "file")
	ff.set_meta("fe_src", src.get_meta("fe_src", path))
	ff.set_meta("fe_raster", true)
	_files[key] = ff
	return ff

const HAND_SPACE_PX := 11

func _build_fonts() -> void:
	_fonts.clear()
	var liga := TextServerManager.get_primary_interface().name_to_tag("liga")
	for s in SLOTS:
		var e: Dictionary = _slots.get(s, {"file": "embedded"})
		var reg_p := str(e.get("file", "embedded"))
		var ita_p := str(e.get("italic", ""))
		var reg := _file(reg_p)
		var ita: FontFile = null
		if ita_p != "":
			ita = _file(ita_p)
		for it in [false, true]:
			for b in [false, true]:
				var fv := FontVariation.new()
				var synth: bool = it and ita == null
				fv.base_font = ita if (it and ita != null) else reg
				if b:
					fv.base_font = _raster(ita_p) if (it and ita != null) else _raster(reg_p)
				fv.fallbacks = []
				if synth:
					fv.variation_transform = Transform2D(Vector2(1.0, SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
				if b:
					fv.variation_embolden = EMBOLDEN
				if s == "maquina":
					fv.opentype_features = {liga: 0}
				if s == "manuscrito":
					# Homemade Apple: la «S» y la «G» mayúsculas arrancan con un rasgo hacia atrás que se come el espacio
					# anterior («Lector.Sabe», «enSuiza»; a 32 px la «S» dibuja 18 px a la izquierda de su origen y el espacio
					# mide 11): aire fijo en el espacio, en toda letra manuscrita (W4)
					fv.spacing_space = HAND_SPACE_PX
				fv.set_meta("fe_slot", s)
				fv.set_meta("fe_italic", it)
				fv.set_meta("fe_bold", b)
				_fonts["%s|%d|%d" % [s, int(it), int(b)]] = fv

func _font_for(slot: String, italic: bool, bold: bool) -> Font:
	if _fonts.is_empty():
		_capture_embedded()
		if _slots.is_empty():
			_load_config()
		_build_fonts()
	var s := slot if SLOTS.has(slot) else "ui"
	return _fonts["%s|%d|%d" % [s, int(italic), int(bold)]]

func _replace_foreign_fonts(dt: Theme) -> void:
	for ty in dt.get_font_type_list():
		for n in dt.get_font_list(ty):
			if not dt.has_font(n, ty):
				continue
			var f := dt.get_font(n, ty)
			if is_ours(f):
				continue
			var nm := String(n)
			var it := nm.contains("italic")
			var bo := nm.contains("bold")
			var rep: Font
			if nm.contains("mono"):
				rep = font("maquina")
			elif bo:
				rep = font_bold("ui", it)
			else:
				rep = font("ui", it)
			dt.set_font(n, ty, rep)
