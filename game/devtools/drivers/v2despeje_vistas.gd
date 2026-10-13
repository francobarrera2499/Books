# devtools/drivers/v2despeje_vistas.gd — T31 con ventana (GDD_v2 §C, §F.3 DESPEJE-UI). Dueño: DESPEJE-UI.
# Juega SIN --fast (a la velocidad del juego, como un jugador) y saca una captura por vista al empezar y otra a mitad de
# partida (el bot deductor hasta el día 5, cargado como partida guardada):
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn v2d res://devtools/drivers/v2despeje_vistas.gd --mute
# Capturas: .work/shots/v2d_<NN>_<vista>.png. Registros de partida en .work/despeje/ (nunca .work/jugador/).
# Imprime «V2D <vista> <estado>» por captura (lo que quedó a la vista según el revelado) y «V2D OK|FALLA».
extends RefCounted

const RunBots = preload("res://devtools/bots/run_bots.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const SEED := 1894

var tool
var shell
var g
var n := 0
var fails: Array = []

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(20)
	shell = scene.get_node_or_null("Shell")
	g = tool.root.get_node("Game")
	if shell == null or g == null:
		print("V2D FALLA sin Shell/Game")
		return
	shell.sounds = false
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/despeje").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	g.save_path = dir.path_join("v2d_inicio.jsonl")
	await shell.new_game(SEED)
	await settle(90)
	await inicio()
	await mitad(dir)
	print("V2D ", "OK" if fails.is_empty() else "FALLA " + str(fails))

func settle(frames := 30) -> void:
	for i in 400:
		if not shell.is_busy():
			break
		await tool.frames(2)
	await tool.frames(frames)

func snap(what: String) -> void:
	n += 1
	await tool.snap("%02d_%s" % [n, what])

func act(a: Dictionary) -> Dictionary:
	var r: Dictionary = g.act(a)
	if not bool(r.get("ok", false)):
		fails.append("%s -> %s" % [str(a).left(100), str(r.get("err", ""))])
	return r

func clip_tramo(view: String, tid: String) -> String:
	var v: Dictionary = g.sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for t in v.pages[pi][bi].parsed.tramos:
				if String(t.id) == tid:
					return String(act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi},
						"from": int(t.from), "len": int(t.to) - int(t.from)}).get("clip", ""))
	return ""

func close_all() -> void:
	for i in 6:
		if shell.stack.is_empty():
			break
		shell.pop()
		await tool.frames(8)
	await settle(10)

# ------------------------------------------------------------------ al empezar
func inicio() -> void:
	# prólogo: el lector con el encargo (al abrirlo, la lectura enseña la tijera)
	shell.open_reader("D01.REDH@tomo")
	await settle(40)
	print("V2D lector_tomo_prologo ", shell.reader.tool_names())
	await snap("lector_tomo_prologo")
	await close_all()
	shell.open_reader("D23@L1")
	await settle(40)
	print("V2D lector_encargo ", shell.reader.tool_names())
	await snap("lector_encargo")
	clip_tramo("D23@L1", "aviso")
	await close_all()
	var nb = shell.open_panel("notebook")
	await settle(40)
	print("V2D cuaderno_prologo ", nb.debug_state().tabs, " buscar=", nb.page("recortes").debug_state().search)
	await snap("cuaderno_prologo")
	await close_all()
	var ad = shell.open_panel("ad")
	await settle(40)
	if ad != null:
		print("V2D aviso_prologo formas=", ad.forms_available())
		await snap("aviso_prologo")
	await close_all()
	var suceso := "suceso_reichenbach"
	act({"t": "compose_ad", "form": "testigo", "fields": {"suceso": suceso}})
	act({"t": "sleep"})
	await settle(180)
	await close_all()
	# día 1 al amanecer
	shell.game_screen.open_tray()
	await settle(40)
	print("V2D bandeja_dia1 anteriores=", shell.game_screen.tray.prev_toggle.visible)
	await snap("bandeja_dia1")
	await close_all()
	var lg = shell.open_panel("ledger")
	await settle(40)
	print("V2D libro_dia1 ", lg.debug_state().tabs, " sello=", lg.debug_state().seal, " hoja=", lg.debug_state().new_folio)
	await snap("libro_dia1")
	await close_all()
	nb = shell.open_panel("notebook")
	await settle(40)
	print("V2D cuaderno_dia1 ", nb.debug_state().tabs)
	await snap("cuaderno_dia1")
	await close_all()
	# el consultorio del doctor (de mañana): la escena y el selector de temas
	act({"t": "go", "place": "L4", "area": ""})
	await settle(200)
	var sp = shell.panel("scene")
	if sp != null and not sp.chars.is_empty():
		var cid := String(sp.chars[0].id)
		print("V2D escena_dia1 verbos=", sp._verbs(cid))
		await snap("escena_dia1")
		if sp._verbs(cid).has("ask"):
			sp.open_ask(cid, "ask")
			await settle(20)
			await snap("escena_preguntar_dia1")
			sp.close_sub()
		if sp._verbs(cid).has("present"):
			sp.open_picker(cid)
			await settle(20)
			await snap("escena_mostrar_dia1")
			sp.close_sub()
	else:
		fails.append("sin escena en L4")
	await close_all()
	act({"t": "leave"})
	await settle(160)
	await close_all()
	act({"t": "end_slot"})
	await settle(160)
	await close_all()
	# Sala de Lectura (de tarde): el catálogo
	act({"t": "go", "place": "L2", "area": "sala", "seat": 214})
	await settle(160)
	await close_all()
	shell.game_screen.open_catalog()
	await settle(40)
	await snap("catalogo_dia1")
	act({"t": "slip", "doc": "D05"})
	shell.game_screen.catalog.refresh()
	await settle(20)
	await close_all()
	shell.game_screen.open_catalog()
	await settle(30)
	await snap("catalogo_pedido")
	await close_all()
	act({"t": "leave"})
	await settle(160)
	await close_all()

# ------------------------------------------------------------------ a mitad de partida (deductor hasta el día 5)
func mitad(dir: String) -> void:
	var repo = g.sim.repo
	var sim = GameSim.new(repo, SEED)
	var b = RunBots.make("deductor")
	b.budget_ms = 120000
	b.setup(sim, SEED)
	for i in 20000:
		var c: Dictionary = sim.q_clock()
		if int(c.day) >= 5 and String(c.phase) == "desk":
			break
		if not b.step():
			break
	print("V2D mitad: día ", sim.q_clock().day, " fase ", sim.q_clock().phase, " acciones ", sim.actions_log().size(),
		" recortes ", sim.q_clips().size())
	var path := dir.path_join("v2d_mitad.jsonl")
	EventLog.new(path).write(EventLog.make_header(SEED, repo.content_hash()), sim.actions_log())
	g.save_path = path
	await shell.continue_game()
	await settle(240)
	await close_all()
	var nb = shell.open_panel("notebook")
	await settle(40)
	var nst: Dictionary = nb.debug_state()
	print("V2D cuaderno_dia5 ", nst.tabs, " buscar=", nst.recortes.search, " filtros=", nst.recortes.menus)
	await snap("cuaderno_dia5")
	if nb.tab_available("diario"):
		nb.show_tab("diario")
		await settle(20)
		await snap("cuaderno_diario_dia5")
	await close_all()
	var lg = shell.open_panel("ledger")
	await settle(40)
	print("V2D libro_dia5 ", lg.debug_state().tabs, " sello=", lg.debug_state().seal)
	await snap("libro_dia5")
	var fol: Array = g.sim.q_ledger().get("folios", [])
	if not fol.is_empty():
		lg.show_page(String(fol[0].id))
		await settle(20)
		await snap("libro_hoja_dia5")
		# un borrador nuevo: aparece el sello (lg.sello) con su línea de tinta; y el elector de tipos con «Más tipos…»
		lg.new_entry("T2")
		await settle(20)
		print("V2D libro_sello_dia5 sello=", lg.debug_state().seal)
		await snap("libro_sello_dia5")
		var add = lg.find_child("NuevoAsiento", true, false)
		if add != null:
			lg.on_new_entry(add)
			await settle(10)
			await snap("libro_tipos_dia5")
	await close_all()
	shell.game_screen.open_tray()
	await settle(40)
	await snap("bandeja_dia5")
	await close_all()
	var tray_v: Array = g.sim.q_tray()
	if not tray_v.is_empty():
		shell.open_reader(String(tray_v[0].view))
		await settle(40)
		print("V2D lector_dia5 ", shell.reader.tool_names())
		await snap("lector_dia5")
		await close_all()
	# una visita a mitad de partida: preguntar (temas por secciones) y mostrar (selector)
	var r: Dictionary = g.act({"t": "go", "place": "L4", "area": ""})
	if bool(r.get("ok", false)):
		await settle(200)
		var sp = shell.panel("scene")
		if sp != null and not sp.chars.is_empty():
			var cid := String(sp.chars[0].id)
			print("V2D escena_dia5 verbos=", sp._verbs(cid))
			if sp._verbs(cid).has("ask"):
				sp.open_ask(cid, "ask")
				await settle(20)
				print("V2D preguntar_dia5 ", sp.ask_panel.shown_ids().size(), " de ", g.sim.q_topics(cid).size())
				await snap("escena_preguntar_dia5")
				sp.close_sub()
			if sp._verbs(cid).has("present"):
				sp.open_picker(cid)
				await settle(20)
				await snap("escena_mostrar_dia5")
				sp.close_sub()
		await close_all()
