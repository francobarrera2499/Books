# ui/kit/restyler.gd — hijo invisible que reaplica un estilo cuando ThemeInstaller emite theme_changed. Dueño: W1-THEME.
# Uso interno de widgets.gd (Widgets.restyle(node, fn)). Se libera con su padre; la conexión se corta en _exit_tree.
extends Node

var fn: Callable

func _init(p_fn: Callable = Callable()) -> void:
	fn = p_fn
	name = "Restyler"

func _enter_tree() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and not ti.theme_changed.is_connected(_on_theme):
		ti.theme_changed.connect(_on_theme)

func _exit_tree() -> void:
	var ti := get_node_or_null("/root/ThemeInstaller")
	if ti != null and ti.theme_changed.is_connected(_on_theme):
		ti.theme_changed.disconnect(_on_theme)

func _on_theme() -> void:
	if fn.is_valid():
		fn.call()
