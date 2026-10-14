# devtools/drivers/v3exp_medio.gd — UI-EXPEDIENTE (GDD_v3 §6.1–§6.2): la carpeta y el cuaderno a MITAD de partida, con
# datos REALES (el bot deductor juega por el sim hasta el escritorio del día V3EXP_DIA, 4 por defecto) y desde ahí todo
# con el mouse real, SIN --fast: el cuaderno queda en la pestaña Diario -> clic en la carpeta 3D -> la carpeta abre con
# el cuaderno acoplado EN RECORTES (de ahí salen las pruebas) -> cada hoja abierta -> «En tinta» desplegado y una hoja en
# tinta -> clic en una ranura vacía con el cuaderno en otra pestaña lo vuelve a Recortes -> Esc cierra.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3exp_medio res://devtools/drivers/v3exp_medio.gd --mute
# Salida: «V3M OK|FALLA <qué>», «V3M RESUMEN n fallas».
extends "res://devtools/drivers/v3mundo_base.gd"

const ClipCard = preload("res://ui/notebook/clip_card.gd")

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(400.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 400 s")
		tool.quit(2))
	var dia := int(OS.get_environment("V3EXP_DIA")) if OS.get_environment("V3EXP_DIA") != "" else 4
	if not await _boot_day(scene, dia, "user://saves/v3exp_medio.jsonl"):
		_summary()
		return
	# el jugador dejó el cuaderno en el Diario
	shell.open_panel("notebook", ["diario"])
	await _wait(0.6)
	var nb = shell.panel("notebook")
	print("V3M cuaderno abierto en: %s (pestañas %s)" % [nb.tab, str(nb.debug_state().tabs)])
	await _snap("00_cuaderno_diario")
	await _key(KEY_ESCAPE)
	await _wait(0.6)
	var p := _safe_point("expediente")
	_check(p.x >= 0.0, "la carpeta del expediente se ve en el escritorio")
	if p.x < 0.0:
		_summary()
		return
	await _move(p)
	await _wait(0.3)
	await _click(p)
	await _wait(1.0)
	_check(shell.is_open("dossier"), "clic en la carpeta abre el expediente")
	if not shell.is_open("dossier"):
		_summary()
		return
	var ex = shell.panel("dossier")
	nb = shell.panel("notebook") if shell.is_open("notebook") else null
	_check(nb != null and String(nb.layout) == "left", "el cuaderno se acopla a la izquierda")
	if nb != null:
		_check(String(nb.tab) == "recortes", "el cuaderno acoplado muestra Recortes (está en «%s»)" % nb.tab)
	var d: Dictionary = g.sim.q_dossier()
	print("V3M abiertas: %s · en tinta: %s" % [str(d.open.map(func(h): return h.id)), str(d.inked.map(func(h): return h.id))])
	await _snap("01_carpeta")
	if nb != null:
		var ids: Array = nb.page("recortes").visible_ids()
		var maxw := 0
		for cid in ids:
			var c = nb.page("recortes").card(cid)
			if c != null:
				maxw = maxi(maxw, ClipCard.shown_text(c.clip).strip_edges().split(" ", false).size())
		print("V3M recortes: %d · máx palabras %d" % [ids.size(), maxw])
		_check(maxw <= 15, "ninguna tarjeta del cuaderno pasa de 15 palabras")
	for h in d.open:
		var r: Rect2 = ex.row_rect(String(h.id))
		if r.size.x <= 0.0:
			_check(false, "renglón de %s en el índice" % h.id)
			continue
		await _click(r.get_center())
		await _wait(0.5)
		_check(String(ex.debug_state().selected) == String(h.id), "clic en %s la muestra" % h.id)
		await _snap("02_hoja_%s" % h.id)
	if not d.inked.is_empty():
		var fr: Rect2 = ex.rect_of("en_tinta")
		_check(fr.size.x > 0.0, "«En tinta» en el índice")
		if fr.size.x > 0.0 and bool(ex.debug_state().ink_folded):
			await _click(fr.get_center())
			await _wait(0.5)
		var q0 := String(d.inked[0].id)
		var rr: Rect2 = ex.row_rect(q0)
		if rr.size.x > 0.0:
			await _click(rr.get_center())
			await _wait(0.6)
			_check(String(ex.debug_state().state) == "tinta", "una hoja en tinta (%s)" % q0)
			await _snap("03_tinta_%s" % q0)
	# con el cuaderno en otra pestaña, clic en una ranura vacía lo vuelve a Recortes
	if nb != null and not d.open.is_empty():
		await _click(ex.row_rect(String(d.open[0].id)).get_center())
		await _wait(0.4)
		if nb.tab_available("diario"):
			nb.show_tab("diario")
			await _wait(0.3)
		var pr: Rect2 = ex.rect_of("prueba", 0)
		if pr.size.x > 0.0 and String(ex.debug_state().proofs[0]) == "":
			await _click(pr.get_center())
			await _wait(0.5)
			_check(String(nb.tab) == "recortes", "clic en una prueba vacía muestra los recortes del cuaderno")
			await _snap("04_pista_prueba")
	await _key(KEY_ESCAPE)
	await _wait(0.8)
	_check(not shell.is_open("dossier") and not shell.is_open("notebook"), "Esc cierra la carpeta y el cuaderno")
	_summary()
	g.end_session()

# Partida nueva hasta el escritorio del día `dia` (el bot deductor juega por el sim). false si no se pudo.
func _boot_day(scene, dia: int, save: String) -> bool:
	await tool.frames(10)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	vp = tool.root.get_viewport()
	if shell == null:
		_check(false, "Shell")
		return false
	g.save_path = save
	for suf in ["", ".bak", ".tmp", ".fin"]:
		var p := ProjectSettings.globalize_path(g.save_path + suf)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	await _settle_window()
	await shell.new_game(1894)
	await _settle()
	var bot = Bot.new()
	bot.setup(g.sim, 1)
	for _i in 4000:
		var c: Dictionary = g.sim.q_clock()
		if int(c.day) >= dia and String(c.phase) == "desk": break
		if not bot.step(): break
	await _settle()
	await _focus()
	for _k in 4:
		if shell.top() == null: break
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _settle()
	var c2: Dictionary = g.sim.q_clock()
	var ok := int(c2.day) == dia and String(c2.phase) == "desk"
	_check(ok, "día %d en el escritorio (%s)" % [dia, str([c2.day, c2.phase])])
	return ok
