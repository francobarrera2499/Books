# Humo del título SIN --fast (como un jugador): DBG_MODE=new|continue ./godot.sh -s devtools/shot.gd -- res://main.tscn <prefijo> res://devtools/drivers/title_smoke.gd
extends RefCounted
func _find_btn(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text.strip_edges() == txt and (n as Button).is_visible_in_tree(): return n
	for c in n.get_children():
		var r = _find_btn(c, txt)
		if r != null: return r
	return null
func _screen(tool) -> String:
	var sh = tool.root.find_child("Shell", true, false)
	if sh == null: return "no-shell"
	return str(sh.get("screen")) if "screen" in sh else "?"
func _click(tool, txt: String) -> bool:
	var b := _find_btn(tool.root, txt)
	if b == null:
		print("DBG no button '%s'" % txt); return false
	var p: Vector2 = b.get_global_rect().get_center()
	print("DBG click '%s' at %s" % [txt, str(p)])
	tool.root.warp_mouse(p)
	await tool.frames(2)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = p; e.global_position = p
		Input.parse_input_event(e)
		await tool.frames(2)
	return true
func drive(tool, scene) -> void:
	var mode := OS.get_environment("DBG_MODE")
	await tool.frames(40)
	if mode == "continue":
		await _click(tool, "Continuar")
		await tool.frames(10)
		await tool.snap("c1_confirm")
		await _click(tool, "Seguir")
	else:
		await _click(tool, "Partida nueva")
		await tool.frames(10)
		await tool.snap("n1_confirm")
		await _click(tool, "Empezar de nuevo")
	for k in [60, 180, 360]:
		await tool.frames(k)
		await tool.snap(mode + "_t%d" % k)
	print("DBG final screen=%s" % _screen(tool))
