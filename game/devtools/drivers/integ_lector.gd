# Driver de capturas del integrador (ola 2): el lector (W2-READER) sobre documentos RUNTIME que produce la GameSim real
# del recorrido de tests/test_i_integration.gd (datos reales + tests/fixtures/integ).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn integ res://devtools/drivers/integ_lector.gd
# Capturas (.work/shots/integ_<nombre>.png):
#   times_aviso   D15.0327@L1, columna (p2) con el aviso del prólogo impreso (bloque runtime AD.1)
#   times_s       D15.0330@L1, columna con la respuesta «—S.» de HC10 (cita el aviso)
#   carta_s       R.HB1.*: carta «—S.» a máquina (K-W, Ley 5) con la Remington
#   carta_a       R.HA1.*: carta de la voz A (Cotter) con firma «Un amigo de la exactitud»
extends RefCounted

const Reader = preload("res://ui/reader/document_reader.gd")
const Integ = preload("res://tests/test_i_integration.gd")

var tool
var reader

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var t = Integ.new()
	t._cur = "integ_lector.gd::drive"
	var repo = t._repo("fixture")
	var sim = t._walk(repo)
	if sim == null or not t._errs.is_empty():
		print("RECORRIDO CON PROBLEMAS ", t._errs)
		if sim == null:
			return
	reader = Reader.new()
	reader.sounds = false
	reader.act_fn = func(a): return sim.apply(a)
	scene.add_child(reader)
	await tool.frames(4)
	await _show(sim.q_view("D15.0327@L1"), 1, "times_aviso")
	await _show(sim.q_view("D15.0330@L1"), 1, "times_s")
	for inst in sim.st.react.delivered:
		if String(inst.rid) == "HB1":
			await _show(sim.q_view(String(inst.view)), 0, "carta_s")
		if String(inst.rid) == "HA1":
			await _show(sim.q_view(String(inst.view)), 0, "carta_a")
	reader.close()
	await tool.frames(2)

func _show(v: Dictionary, page: int, name: String) -> void:
	if v.is_empty():
		print("SIN VISTA ", name)
		return
	reader.open_view(v)
	await tool.frames(3)
	if page > 0:
		reader.go_page(page)
	await tool.frames(6)
	await tool.snap(name)
