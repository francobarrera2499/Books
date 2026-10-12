# Escena principal (única .tscn del juego). Dueño: W3-SHELL. Contrato: docs/ARCHITECTURE.md §2.3.
# STUB: arranca un placeholder legible. W3-SHELL lo reemplaza por: parse de args -> Shell (ui/shell.gd).
# Args de usuario previstos (tras "--"): --new  --continue  --seed=N  --script=res://... (JSONL de acciones)  --screen=<id>
extends Node

func _ready() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var lab := Label.new()
	lab.text = "Fe de erratas\n(en construcción)"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.add_theme_color_override("font_color", Color("1b1712"))
	lab.add_theme_font_size_override("font_size", 40)
	cl.add_child(lab)
