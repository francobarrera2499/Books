# devtools/drivers/v3cont_shots.gd — CONTENIDO (GDD_v3 §3, §5.1): las seis crónicas del cliente en el juego REAL, SIN
# --fast, con mouse real (base de UI-MUNDO): clic en el estante de la pieza, clic en cada crónica de la lista, hoja 1
# (ficha de Lisle), la hoja con marquitas, las hojas con notas al margen y la última (tarjeta del cliente con el clip);
# después baja a la tienda (CRANE.intro). El plano con «qué hay» y «Me lo dijo Crane.» lo captura v3mundo_crane.gd.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3cont res://devtools/drivers/v3cont_shots.gd --mute
# Capturas: .work/shots/v3cont_<crónica>_<1|marcas|margen<n>|tarjeta>.png, v3cont_estante.png, v3cont_tienda.png
# Salida: «V3M OK|FALLA …» y «V3M RESUMEN n fallas».
extends "res://devtools/drivers/v3mundo_base.gd"

const CHRON := [["D03@tomo", "fina", "«El problema final»"], ["D01.GREE@tomo", "gree", "«El intérprete griego»"],
	["D43@tomo", "stud", "«Estudio en escarlata»"], ["D44@tomo", "sign", "«El signo de los cuatro»"],
	["D01.SCAN@tomo", "scan", "«Escándalo en Bohemia»"], ["D01.TWIS@tomo", "twis", "«El hombre del labio retorcido»"]]

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(480.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 480 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3cont.jsonl"):
		_summary()
		return
	var w = shell.world
	for ch in CHRON:
		await _open_estante(w)
		var btn := _link_for(String(ch[2]))
		_check(btn != null, "el estante lista «%s»" % ch[2])
		if btn == null:
			continue
		if ch[1] == "fina":
			await _snap("estante")
		await _click_ctrl(btn)
		await _settle()
		await _wait(0.5)
		var rd = shell.reader
		_check(shell.reader_open() and rd != null, "%s abierto en el lector" % ch[0])
		if rd == null or not shell.reader_open():
			continue
		var v: Dictionary = rd.view
		_check(String(v.get("view", "")) == String(ch[0]), "%s: la vista es el ejemplar del cliente (%s)" % [ch[0], v.get("view", "")])
		_check(v.get("ficha") != null, "%s: ficha de Lisle" % ch[0])
		await _snap("%s_1" % ch[1])
		var n: int = rd.page_count()
		# hoja con la primera marquita
		var mp := -1
		for m in v.get("marks", []):
			mp = int(m.get("page", -1))
			break
		if mp > 0:
			for _i in mp:
				await _key(KEY_RIGHT)
				await tool.frames(4)
			await _wait(0.3)
			await _snap("%s_marcas" % ch[1])
		# hojas con nota al margen (FINA: #fina_fo junto a #sheer y #nov93 al pie), con ↓ hasta el final de la hoja
		var mg := 0
		for pi in (v.get("pages", []) as Array).size():
			var has_m := false
			for b in v.pages[pi]:
				if String(b.get("slot", "")) == "margen":
					has_m = true
			if not has_m:
				continue
			while rd.page_idx < pi:
				await _key(KEY_RIGHT)
				await tool.frames(4)
			while rd.page_idx > pi:  # TWIS: la marquita (#viejo, hoja 2) queda después de la nota (#mi_james, hoja 1)
				await _key(KEY_LEFT)
				await tool.frames(4)
			for _k in 40:
				await _key(KEY_DOWN)
			await _wait(0.3)
			mg += 1
			await _snap("%s_margen%d" % [ch[1], mg])
		for _i in n:
			if rd.page_idx >= n - 1:
				break
			await _key(KEY_RIGHT)
			await tool.frames(4)
		await _wait(0.4)
		_check(rd.page_idx == n - 1 and bool(rd.page.card), "%s: la última hoja es la tarjeta" % ch[0])
		await _snap("%s_tarjeta" % ch[1])
		await _key(KEY_ESCAPE)
		await _settle()
		await _wait(0.3)
	# la tienda: Crane se presenta
	w.set_frame("puerta")
	await _wait(1.4)
	var pd := _safe_point("puerta")
	_check(pd.x >= 0.0, "la puerta a la vista")
	if pd.x >= 0.0:
		await _click(pd)
		await _settle()
		await _wait(1.5)
		await _snap("tienda")
		var lb: Control = gs()._leave_btn
		if lb != null and lb.is_visible_in_tree():
			await _click_ctrl(lb)
		await _settle()
		await _wait(0.6)
	_summary()
	g.end_session()

func _open_estante(w) -> void:
	for _k in 3:
		if shell.top() == null: break
		await _click(Vector2(800, 450), MOUSE_BUTTON_RIGHT)
		await _settle()
	w.set_frame("estante")
	await _wait(1.4)
	var p := _safe_point("estante")
	_check(p.x >= 0.0, "el estante a la vista")
	if p.x >= 0.0:
		await _click(p)
		await _settle()
		await _wait(0.5)

func _link_for(sub: String) -> Control:
	var exam = gs().exam
	for c in exam.links_list.get_children() + exam.links_box.get_children():
		if c is Button and (c as Button).text.begins_with(sub) and (c as Control).is_visible_in_tree():
			return c
	return null
