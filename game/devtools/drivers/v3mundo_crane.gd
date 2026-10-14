# devtools/drivers/v3mundo_crane.gd — UI-MUNDO (GDD_v3 §5.1–§5.3): Crane como guía, con el mouse real y SIN --fast.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v3mundo_crane res://devtools/drivers/v3mundo_crane.gd --mute
# Recorrido (día 1): clic en la puerta -> la tienda; Crane se presenta (CRANE.intro) -> su bloque ofrece «¿Dónde
# consigo…?» -> la lista (Lisle se enteró de un testamento: aparece «¿Dónde se ve si alguien murió…?») -> «Preguntar» ->
# Crane contesta y Somerset House entra al plano -> «Subir» -> el plano de la pared: Somerset House con «qué hay» y
# «Me lo dijo Crane.». Si los datos todavía no traen CRANE.intro o la sección donde, se informa RESPALDO y se agregan
# en memoria (sólo para la captura).
extends "res://devtools/drivers/v3mundo_base.gd"

const Widgets = preload("res://ui/kit/widgets.gd")

var respaldos := 0

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3M VIGIA: se corta a los 300 s")
		tool.quit(2))
	if not await _boot_day1(scene, "user://saves/v3mundo_crane.jsonl"):
		_summary()
		return
	var repo = g.sim.repo
	if (repo.scene("CRANE") as Dictionary).is_empty():
		respaldos += 1
		print("V3M RESPALDO sin scenes/CRANE.json (CONTENIDO): se agrega en memoria")
		repo.scenes()["CRANE"] = {"id": "CRANE", "place": "L1", "area": "tienda", "auto": true, "origin": "S.CRANE",
			"lines": [{"id": "intro", "who": "crane", "text": "Abel Crane, librero de viejo, para servirle. Si busca algo impreso en Londres, señor, pregúnteme dónde."}]}
	if not repo.dialogue("crane").has("donde"):
		respaldos += 1
		print("V3M RESPALDO sin la sección donde de crane.json (CONTENIDO): se agrega en memoria")
		repo.dialogue("crane")["donde"] = [
			{"id": "donde.diarios", "frase": "¿Dónde consigo diarios viejos, de cualquier año?", "requiere": [], "texto": "En el Museo Británico, señor.", "revela": "L2"},
			{"id": "donde.registros", "frase": "¿Dónde se ve si alguien murió, o qué dejó al morir?", "requiere": ["testamento"], "texto": "En Somerset House, en el Strand.", "revela": "L6"}]
	var w = shell.world
	await _focus()
	# la puerta: la tienda
	w.set_frame("puerta")
	await _wait(1.6)
	await _click(_safe_point("puerta"))
	await _settle()
	await _wait(1.0)
	_check(String(g.sim.q_scene().get("area", "")) == "tienda", "la puerta baja a la tienda")
	var sp = shell.panel("scene")
	_check(sp != null and shell.is_open("scene"), "la banda de la escena con Crane")
	if sp == null:
		_summary()
		return
	var said_intro := false
	for r in sp.transcript.rows():
		if String(r.who) == "crane":
			said_intro = true
	_check(said_intro, "Crane se presenta al bajar")
	_check(bool(g.sim.q_ui().get("sc.donde", false)), "desde entonces, «¿Dónde consigo…?»")
	await _snap("01_crane_se_presenta")
	# Lisle se entera de algo de un testamento (para que el ítem de Somerset House aparezca)
	g.sim.st.world.known["testamento"] = int(g.sim.q_clock().tk)
	sp.refresh()
	await tool.frames(4)
	var vb: Button = sp.band.find_child("Verbo_donde", true, false)
	_check(vb != null and vb.is_visible_in_tree(), "el verbo «¿Dónde consigo…?» en el bloque de Crane")
	if vb == null:
		_summary()
		return
	await _click_ctrl(vb)
	await _wait(0.6)
	var ap = sp.ask_panel
	_check(ap.visible and ap.mode == "donde", "la lista de lo que se puede pedir")
	var ids: Array = ap.shown_ids()
	print("V3M donde: %s" % str(ids))
	_check(ids.has("donde.registros"), "«¿Dónde se ve si alguien murió…?» en la lista")
	await _snap("02_donde_lista")
	var i := ids.find("donde.registros")
	if i >= 0:
		var r: Rect2 = ap._list.get_item_rect(i)
		var p: Vector2 = ap._list.get_global_rect().position + r.get_center()
		await _click(p)
		await _wait(0.4)
		_check(ap.chosen == "donde.registros", "elegido")
		await _snap("03_donde_frase")
		await _click_ctrl(ap._ok)
		await _wait(1.0)
		_check(g.sim.q_place_known("L6"), "Somerset House entra al plano")
		await _snap("04_crane_contesta")
	# subir y mirar el plano
	var lb: Control = gs()._leave_btn
	if lb != null and lb.is_visible_in_tree():
		await _click_ctrl(lb)
	else:
		sp.leave()
	await _settle()
	await _wait(0.6)
	_check(String(g.sim.q_clock().phase) == "desk", "de vuelta en la pieza")
	w.set_frame("mapa")
	await _wait(1.6)
	await _click(_safe_point("mapa"))
	await _wait(1.0)
	var ms = shell.panel("map")
	_check(shell.is_open("map"), "el plano")
	var m6 = ms.marker("L6") if ms != null else null
	_check(m6 != null, "Somerset House en el plano")
	if m6 != null:
		var c: Vector2 = (m6 as Control).get_global_rect().position + (m6 as Control).get_meta("origin", Vector2(12, 12))
		await _move(c)
		await _wait(0.5)
		var txt: String = ms._hover.text
		print("V3M L6: %s" % txt.replace("\n", " | "))
		_check(txt.contains(Widgets.t("v3core.por_que.crane")), "«Me lo dijo Crane.» al pasar el mouse")
		await _snap("05_plano_somerset")
	print("V3M RESPALDOS %d" % respaldos)
	_summary()
	g.end_session()
