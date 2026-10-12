# Autoload ThemeInstaller. Dueño: W1-THEME. Contrato: docs/ARCHITECTURE.md §2.2 y §6.2.
# STUB con firmas definitivas. Reglas: prohibido SystemFont; fuentes por load_dynamic_font desde data/fonts.json
# (res://assets/fonts/*.ttf o "embedded" = copia de ThemeDB.fallback_font.data); allow_system_fallback=false; MSDF.
# Instala sobre ThemeDB.get_default_theme() y ThemeDB.fallback_font (no root.theme). Nunca push_error en _ready.
extends Node

signal theme_changed

const SLOTS := ["imprenta", "maquina", "manuscrito", "ui"]
const FONTS_JSON := "res://data/fonts.json"

var theme: Theme = null          # Theme compartido (type variations de §6.2)
var text_scale := 1.0            # accesibilidad: 0.8..1.6
var high_contrast := false

func _ready() -> void:
	pass  # W1-THEME: install()

func install() -> void:
	pass

func font(slot: String, italic := false) -> Font:
	return ThemeDB.fallback_font

func set_slot(slot: String, path: String) -> void:
	pass

func set_text_scale(f: float) -> void:
	text_scale = clampf(f, 0.8, 1.6)
	theme_changed.emit()

func set_high_contrast(on: bool) -> void:
	high_contrast = on
	theme_changed.emit()

func px(kind: String) -> int:
	return int(round(18.0 * text_scale))
