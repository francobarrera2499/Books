# W3-NOTEBOOK: el cuaderno dentro del juego de verdad (Shell + GameScreen + WorldRoot + InputRouter), con la partida
# del recorrido de integración (datos reales + fixtures/integ) cargada en el autoload Game por guardar -> continuar.
# Comprueba con eventos reales: Tab abre sobre el escritorio 3D · L abre el libro mayor y el cuaderno se acopla a la
# izquierda · clic derecho sobre el cuaderno vuelve (con Shell) · C en el cuaderno = tijera del Diario · Esc la deja y
# después cierra · visita a Kensington con Watson: el cuaderno acoplado termina arriba de la banda de la escena.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3notebook res://devtools/drivers/w3notebook_shell.gd
# Capturas (.work/shots/w3notebook_shell_<n>.png): 1_escritorio, 2_tab, 3_dos_libros, 4_tijera, 5_visita.
# Imprime SHELL OK|FALLA por paso.
extends RefCounted

const Integ = preload("res://tests/test_i_integration.gd")
const NbWalk = preload("res://tests/fixtures/w3notebook/nb_walk.gd")
const ShellScript = preload("res://ui/shell.gd")

var tool
var shell
var game
var _last := Vector2.ZERO

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var sim = NbWalk.sim()
	if sim == null:
		print("SIN RECORRIDO ", NbWalk.errs)
		return
	var repo = NbWalk.repo()
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/tests/w3notebook_shell")
	DirAccess.make_dir_recursive_absolute(dir)
	var save := dir.path_join("partida.jsonl")
	for f in [save, save + ".tmp", save + ".bak"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(f)
	game = tool.root.get_node("Game")
	game.save_path = save
	game.repo_override = repo
	game.sim_handlers = {}
	game.new_session(Integ.SEED)
	for x in sim.actions_log():
		var r: Dictionary = game.act(x)
		if not bool(r.get("ok", false)):
			print("RECHAZADA ", x, " ", r)
			break
	game.flush()
	_check(game.sim.state_hash() == sim.state_hash(), "la partida guardada reproduce el recorrido")
	game.end_session()
	shell = ShellScript.new()
	scene.add_child(shell)
	await tool.frames(2)
	await _settle_window()
	shell.boot({"continue": true, "save": save, "fast": true, "mute": true, "new": false, "seed": 0, "script": "", "screen": "", "data": ""})
	await tool.frames(90)
	var gs = shell.game_screen
	_check(gs != null and game.sim != null, "pantalla de juego con la partida")
	if gs == null:
		return
	print("RELOJ ", game.sim.q_clock())
	await _close_tray(gs)
	await tool.snap("shell_1_escritorio")
	# Tab
	await _key(KEY_TAB)
	await tool.frames(12)
	var nb = shell.panel("notebook")
	_check(nb != null and nb.is_open(), "Tab abre el cuaderno")
	if nb == null:
		return
	_check(nb.layout == "full", "solo: centrado y con velo")
	await tool.snap("shell_2_tab")
	# L: el libro mayor al lado
	await _key(KEY_L)
	await tool.frames(14)
	_check(shell.is_open("ledger"), "L abre el libro mayor")
	_check(nb.is_open() and nb.layout == "left", "el cuaderno se acopla a la izquierda")
	await tool.snap("shell_3_dos_libros")
	# clic derecho sobre el cuaderno: vuelve (lo cierra; el libro mayor sigue)
	var p: Vector2 = nb.book_rect().get_center()
	await _rclick(p)
	await tool.frames(12)
	_check(not nb.is_open(), "clic derecho sobre el cuaderno lo cierra")
	_check(shell.is_open("ledger"), "el libro mayor sigue abierto")
	await _key(KEY_ESCAPE)
	await tool.frames(12)
	# C dentro del cuaderno: la tijera del Diario
	await _key(KEY_TAB)
	await tool.frames(12)
	_check(nb.is_open(), "Tab otra vez")
	await _key(KEY_C)
	await tool.frames(10)
	_check(nb.tab == "diario" and nb.tijera, "C: Diario con la tijera en la mano")
	await tool.snap("shell_4_tijera")
	await _key(KEY_ESCAPE)
	await tool.frames(6)
	_check(nb.is_open() and not nb.tijera, "Esc deja la tijera")
	await _key(KEY_ESCAPE)
	await tool.frames(14)
	_check(not nb.is_open(), "Esc otra vez cierra el cuaderno")
	# visita: Kensington, hablar con Watson, abrir el cuaderno
	var c: Dictionary = game.sim.q_clock()
	if String(c.phase) == "desk" and not bool(c.get("outing_done", false)):
		var r: Dictionary = game.act({"t": "go", "place": "L4"})
		_check(bool(r.get("ok", false)), "go L4: %s" % str(r.get("err", "")))
		await tool.frames(60)
		gs.on_char("watson")
		await tool.frames(20)
		_check(shell.is_open("scene"), "panel de escena abierto")
		await _key(KEY_TAB)
		await tool.frames(14)
		_check(nb.is_open() and nb.layout == "left", "en la visita el cuaderno va a la izquierda")
		var sp = shell.panel("scene")
		var band = sp.get("band") if sp != null and "band" in sp else null
		if band is Control:
			_check(nb.book_rect().end.y <= band.get_global_rect().position.y - 8.0, "termina arriba de la banda de la escena")
		await tool.snap("shell_5_visita")
	else:
		print("SHELL (sin visita: fase ", c.phase, ")")
	game.end_session()

func _close_tray(gs) -> void:
	for _i in 6:
		var top = shell.top()
		if top == null:
			break
		shell.pop()
		await tool.frames(8)
	if gs.has_method("back"):
		for _i in 3:
			if not gs.back():
				break
			await tool.frames(6)
	await tool.frames(20)

func _check(cnd: bool, what: String) -> void:
	print("SHELL %s %s" % ["OK" if cnd else "FALLA", what])

func _settle_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_move_to_foreground()
	var last := DisplayServer.window_get_position()
	var still := 0
	for _i in 120:
		await tool.frames(1)
		var p := DisplayServer.window_get_position()
		still = still + 1 if p == last else 0
		last = p
		if still >= 10 and DisplayServer.window_is_focused():
			break
	await tool.create_timer(0.2).timeout

func _key(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.physical_keycode = code
	k.pressed = true
	Input.parse_input_event(k)
	await tool.frames(2)
	var u := k.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await tool.frames(2)

func _mm(pos: Vector2) -> void:
	Input.warp_mouse(pos)
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = pos - _last
	_last = pos
	Input.parse_input_event(e)

func _rclick(p: Vector2) -> void:
	_mm(p)
	await tool.frames(3)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = pressed
		e.position = p
		e.global_position = p
		e.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
		Input.parse_input_event(e)
		await tool.frames(1)
