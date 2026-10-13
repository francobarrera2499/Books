# ui/input_router.gd — atajos del input map hacia la Shell (ARCHITECTURE §6.1, §6.3). Dueño: W3-SHELL.
# _input: fe_cuaderno (Tab) salvo foco en LineEdit/TextEdit (se marca manejado antes de que la GUI mueva el foco).
# _unhandled_input: fe_tijera (C), fe_libro_mayor (L), fe_mapa (M), fe_volver (Esc = pop()). El clic derecho se toma
# en _input (antes que la GUI, que lo tragaba sobre todo Control con STOP) y hace lo mismo que Esc.
# Esc (tecla, no el clic derecho) sin nada que cerrar en la pantalla de juego abre las Opciones (pausa con «Volver al
# título»): así siempre hay salida sin un botón permanente en pantalla.
# Sólo en la pantalla de juego y fuera de transiciones (fundidos, ritual del amanecer). Mouse primero: todo lo que hace
# un atajo también se hace con un clic en el escritorio (cuaderno, libro mayor, mapa, tijera).
# La decisión vive en Shell/GameScreen (shortcut(name) -> bool); este nodo sólo traduce eventos.
extends Node

var shell = null
var enabled := true

const ACTIONS := ["fe_tijera", "fe_libro_mayor", "fe_mapa", "fe_volver"]

func _init() -> void:
	name = "InputRouter"

func _typing() -> bool:
	if not is_inside_tree():
		return false
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _input(ev: InputEvent) -> void:
	if not enabled or shell == null:
		return
	# Clic derecho = volver, SIEMPRE (W4): se toma antes que la GUI, porque un Control con MOUSE_FILTER_STOP (tijera
	# sobre el 3D, mapa, bandeja, tarjeta de examen, epílogo) se lo tragaba y nunca llegaba a _unhandled_input. Los
	# menús emergentes (ventanas embebidas) lo reciben antes que este nodo; sobre un campo de texto se deja pasar.
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		if not is_inside_tree() or get_viewport().gui_is_dragging():
			return
		var hov := get_viewport().gui_get_hovered_control()
		if hov is LineEdit or hov is TextEdit:
			return
		if shortcut("fe_volver"):
			get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("fe_cuaderno") and ev.is_action_pressed("fe_cuaderno") and not ev.is_echo():
		if _typing():
			return
		get_viewport().set_input_as_handled()
		shortcut("fe_cuaderno")

func _unhandled_input(ev: InputEvent) -> void:
	if not enabled or shell == null:
		return
	for a in ACTIONS:
		if InputMap.has_action(a) and ev.is_action_pressed(a) and not ev.is_echo():
			if a != "fe_volver" and _typing():
				return
			if shortcut(a, ev is InputEventKey):
				get_viewport().set_input_as_handled()
			return

# Traduce un atajo; true si se usó. También lo usan los tests y los drivers (sin eventos de teclado).
# menu_ok: el volver vino de una tecla (Esc) -> sin nada que cerrar abre las Opciones.
func shortcut(a: String, menu_ok := false) -> bool:
	if shell == null:
		return false
	if shell.is_busy():
		return true   # transición: se consume y no hace nada
	var gs = shell.game_screen
	if a == "fe_volver":
		# primero lo que está encima de la pila o es un modo de la mano (confirmación propia, tijera sobre el 3D)
		if gs != null and gs.has_method("front_back") and bool(gs.front_back()):
			return true
		if shell.pop():
			return true
		if gs != null and gs.has_method("back") and bool(gs.back()):
			return true
		if gs == null and shell.screen != null and shell.screen.has_method("back") and bool(shell.screen.back()):
			return true
		if menu_ok and gs != null:
			return shell.open_panel("options") != null
		return false
	if gs == null:
		return false
	match a:
		"fe_cuaderno":
			return gs.shortcut_panel("notebook")
		"fe_libro_mayor":
			return gs.shortcut_panel("ledger")
		"fe_mapa":
			return gs.shortcut_panel("map")
		"fe_tijera":
			return gs.toggle_scissors()
	return false
