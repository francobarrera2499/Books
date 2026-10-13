# Driver de capturas W3-LEDGER (ARCHITECTURE §9.4, §6.6). Libro mayor sobre una GameSim REAL: el recorrido de
# tests/test_i_integration.gd (estructura de data/ + contenido de tests/fixtures/integ) hasta el escritorio del día 4,
# con folios, asientos a lápiz y en tinta, práctica C1 y recortes de verdad.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn w3ledger res://devtools/drivers/w3ledger_shots.gd
# Capturas (.work/shots/w3ledger_<nombre>.png):
#   reglas         primera página: reglas del asiento + modo de asentar y plantillas
#   folio_c6       folio abierto con la columna de HC10; asiento de Relación (C6) a lápiz, completo
#   folio_tinta    folio de FINA: dos asientos en tinta con su «Visto»
#   varios         «Varios» con un asiento flojo a lápiz
#   prologo_folio  folio del prólogo: la práctica C1.10 en tinta
#   campo          elector de un campo (índice filtrado por tipo) · lista  elector de lista cerrada (relaciones)
#   segun          elector de recortes para el «según» · plantilla  elector de plantilla (Nuevo asiento)
#   nuevo          asiento recién abierto, en blanco · formal  asiento con «Falta un según» y «Una sola fuente»
#   lote           dos asientos marcados «Al sello» · confirma  confirmación del sello (dos pasos)
#   seco           pasada fallida: golpe seco, «Alguno no se sostiene.», tampón seco
#   hc             alto contraste · escala  texto a 1,4 · acoplado / acoplado_asiento  una sola página (dock angosto)
#   sin_lote       lote de cero (forzado): el sello sin ranuras, Lisle lo dice y no hay confirmación vacía
#   (segunda partida nueva, todo por la API de la UI)
#   practica       prólogo: asiento de práctica C1.10 listo, «Pasar en limpio» propio, sello en «sólo práctica»
#   practica_tinta la práctica en tinta · lote_tinta  día 1: C2 y C3 a lápiz, marcados al sello
#   tinta_escribiendo / tinta_visto  pasada en tinta: la tinta se escribe y cae el «Visto» · erratas  «Erratas inocentes»
extends RefCounted

const Ledger = preload("res://ui/ledger/ledger.gd")
const Integ = preload("res://tests/test_i_integration.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

var tool
var lg
var sim

func drive(p_tool, scene) -> void:
	tool = p_tool
	for c in scene.get_children():
		c.queue_free()
	var t = Integ.new()
	t._cur = "w3ledger_shots.gd::drive"
	var repo = t._repo("fixture")
	sim = t._walk(repo)
	if sim == null or not t._errs.is_empty():
		print("RECORRIDO CON PROBLEMAS ", t._errs)
		if sim == null:
			return
	lg = Ledger.new()
	lg.sounds = false
	lg.sim = sim
	scene.add_child(lg)
	await tool.frames(2)
	lg.open()
	await _snap("reglas")
	var folios: Array = sim.q_ledger().folios
	for fo in folios:
		print("FOLIO ", fo.id, " ", fo.entries)
	lg.show_page(String(folios[2].id))
	await _snap("folio_c6")
	lg.show_page(String(folios[1].id))
	await _snap("folio_tinta")
	lg.show_page("varios")
	await _snap("varios")
	lg.show_page(String(folios[0].id))
	await _snap("prologo_folio")
	# electores
	lg.show_page(String(folios[2].id))
	await tool.frames(3)
	var as6 := String(folios[2].entries[0])
	var b := _find(lg, "Campo_persona")
	if b != null:
		lg.on_field(as6, 0, "persona", {"kinds": ["persona"]}, "mycroft", b.get_node("Valor"))
	await _snap("campo")
	lg.back()
	var b2 := _find(lg, "Campo_relacion")
	if b2 != null:
		lg.on_field(as6, 0, "relacion", {"list": "relaciones"}, "lee_a", b2.get_node("Valor"))
	await _snap("lista")
	lg.back()
	var add := _find(lg, "Anadir")
	lg.on_support_add(as6, 1, add)
	await _snap("segun")
	lg.back()
	lg.on_new_entry(_find(lg, "NuevoAsiento"))
	await _snap("plantilla")
	lg.back()
	var r: Dictionary = lg.new_entry("T5")
	await _snap("nuevo")
	var e := String(r.get("entry", ""))
	lg.set_field(e, 0, "persona", "mycroft")
	lg.set_field(e, 0, "hizo", "pagar")
	lg.add_support(e, 1, String(sim.q_clips()[0].id))
	await _snap("formal")
	lg.delete_entry(e)
	# lote y sello
	lg.toggle_lot(as6)
	lg.toggle_lot(String(sim.q_ledger().varios[0]))
	lg.refresh()
	await _snap("lote")
	lg.stamp()
	await _snap("confirma")
	lg.confirm_stamp()
	await tool.frames(20)
	await _snap("seco")
	await tool.frames(150)
	var ti = tool.root.get_node("ThemeInstaller")
	ti.set_high_contrast(true)
	lg.show_page(String(folios[2].id))
	await _snap("hc")
	ti.set_high_contrast(false)
	ti.set_text_scale(1.4)
	await _snap("escala")
	ti.set_text_scale(1.0)
	lg.dock(Rect2(760, 0, 840, 900))
	await _snap("acoplado")
	lg.on_select(String(folios[2].entries[0]))
	await _snap("acoplado_asiento")
	lg.dock(Rect2())
	await _snap("completo_otra_vez")
	# lote de cero (todo lo que cuenta, sellado; aquí forzado en el estado): sin ranuras ni confirmación vacía
	for cid in sim.repo.conclusions_meta().get("lot_counts", []):
		sim.st.ded.sealed[String(cid)] = "AS999"
	await tool.frames(150)
	lg.refresh()
	lg.stamp()
	await _snap("sin_lote")
	# --- segunda partida, todo por la API de la UI: prólogo (práctica C1.10) y día 1 (pasada EN TINTA de C2 y C3)
	var sim2 = GameSim.new(repo, Integ.SEED)
	lg.set_sim(sim2)
	lg.open("reglas")
	var c_aviso: String = t._clip_tramo(sim2, "D23@L1", "aviso")
	var c_abril: String = t._clip_tramo(sim2, "D01.REDH@tomo", "abril")
	var c_oct: String = t._clip_tramo(sim2, "D01.REDH@tomo", "octubre")
	sim2.apply({"t": "link", "a": c_abril, "b": c_oct, "note": ""})
	var fo: Dictionary = lg.new_folio_from(c_abril)
	var ep: String = lg.new_entry("T1").get("entry", "")
	lg.set_field(ep, 0, "fuente_a", "redh")
	lg.set_field(ep, 0, "dice_a", "abril_27_1890")
	lg.set_field(ep, 1, "fuente_b", "redh")
	lg.set_field(ep, 1, "dice_b", "octubre_9_1890")
	lg.add_support(ep, 0, c_abril)
	lg.add_support(ep, 1, c_oct)
	await _snap("practica")
	lg.practice(ep)
	await tool.frames(4)
	await _snap("practica_tinta")
	sim2.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	sim2.apply({"t": "sleep"})
	for a in [{"t": "go", "place": "L2", "area": "sala", "seat": 214}, {"t": "slip", "doc": "D05"}]:
		sim2.apply(a)
	var c_marque: String = t._clip_tramo(sim2, "D05@BM", "marque")
	var c_corniche: String = t._clip_tramo(sim2, "D05@BM", "corniche")
	sim2.apply({"t": "leave"})
	sim2.apply({"t": "go", "place": "L1", "area": "tienda"})
	var c_sheer: String = t._clip_tramo(sim2, "D03@Crane", "sheer")
	sim2.apply({"t": "leave"})
	lg.new_folio_from(c_sheer)
	var e2: String = lg.new_entry("T2").get("entry", "")
	lg.set_field(e2, 0, "fuente", "fina")
	lg.set_field(e2, 0, "calla", "raspadura")
	lg.set_field(e2, 1, "consta_en", "journal_de_geneve")
	lg.add_support(e2, 0, c_sheer)
	lg.add_support(e2, 1, c_marque)
	var e3: String = lg.new_entry("T1").get("entry", "")
	lg.set_field(e3, 0, "fuente_a", "fina")
	lg.set_field(e3, 0, "dice_a", "a_pique")
	lg.set_field(e3, 1, "fuente_b", "journal_de_geneve")
	lg.set_field(e3, 1, "dice_b", "cornisa")
	lg.add_support(e3, 0, c_sheer)
	lg.add_support(e3, 1, c_corniche)
	lg.toggle_lot(e2)
	lg.toggle_lot(e3)
	lg.select_entry(e3)
	await _snap("lote_tinta")
	lg.stamp()
	await tool.frames(4)
	lg.confirm_stamp()
	await tool.frames(9)
	await tool.snap("tinta_escribiendo")
	await tool.frames(70)
	await tool.snap("tinta_visto")
	lg.show_page("erratas")
	await _snap("erratas")
	print("PASADA EN TINTA ", sim2.q_entry(e2).ink, " ", sim2.q_entry(e3).ink, " folio ", fo.get("folio", ""), " aviso ", c_aviso != "")

func _snap(nm: String) -> void:
	await tool.frames(6)
	await tool.snap(nm)

func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var f := _find(c, nm)
		if f != null:
			return f
	return null
