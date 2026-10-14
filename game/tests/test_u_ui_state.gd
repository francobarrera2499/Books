# CORE-EXPEDIENTE (GDD_v2 §C.2; GDD_v3 §6.9): q_ui() — banderas de revelado progresivo de la interfaz, sólo del estado. Un caso por bandera:
# apagada al principio y encendida cuando corresponde. Además: determinista, igual tras replay (persiste al cargar) y
# ciega a etiquetas ocultas y a lo sellado (el revelado nunca depende de lo importante).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 240.0
const GameSim = preload("res://core/sim/game_sim.gd")
const UiState = preload("res://core/sim/ui_state.gd")
const Kit = preload("res://tests/fixtures/sim/sim_kit.gd")

const FLAGS := ["desk.tijera", "desk.tintero", "desk.calendario", "desk.mapa", "desk.bandeja", "desk.pendientes",
	"hud.cuaderno", "hud.cintas", "nb.diario", "nb.indice", "nb.curiosidades", "nb.buscar", "nb.filtros",
	"nb.agrupar", "exp.pasar", "sc.donde", "sc.decir", "sc.pagar", "sc.encargar", "cmp.telegrama", "cmp.carta", "cmp.quemar",
	"cmp.trampa", "map.recuerdos", "tray.anteriores", "cat.mesa"]
# Encendidas desde el principio: el expediente (paso «read»), Mostrar (Q1 está en la carpeta) y, en el prólogo con Pell
# en la buhardilla, nada más.
const ON_AT_START := ["desk.expediente", "sc.mostrar"]
const RETIRED := ["hud.libro", "nb.pares", "lg.hoja_nueva", "lg.varios", "lg.practica", "lg.sello", "look.ayuda"]

func _f(s) -> Dictionary:
	return s.q_ui()

func test_all_flags_present_and_off_at_start():
	var s = Kit.new_sim()
	var f := _f(s)
	for k in FLAGS:
		ok(f.has(k), "bandera " + k)
		if k != "sc.decir":
			no(bool(f.get(k, true)), "apagada al empezar: " + k)
	for k in ON_AT_START:
		ok(bool(f.get(k, false)), "encendida al empezar: " + k)
	for k in RETIRED:
		no(f.has(k), "retirada en v3: " + k)
	var forms := 0
	for k in f:
		if String(k).begins_with("cmp.forma."):
			forms += 1
	ok(forms >= 1, "una bandera por forma de aviso")

# Prólogo v2 paso a paso (sim con dobles): tijera, tintero, calendario, cuaderno.
func test_prologue_flags():
	var s = Kit.new_sim()
	ok(s.apply({"t": "read", "view": "D23@L1", "part": 0}).ok)
	ok(bool(_f(s)["desk.tijera"]), "abrir el encargo habilita la tijera")
	no(bool(_f(s)["desk.tintero"]))
	no(bool(_f(s)["hud.cuaderno"]))
	ok(s.apply(Kit.prologue_v2()[1]).ok)
	ok(bool(_f(s)["hud.cuaderno"]), "≥1 recorte: cinta del cuaderno")
	ok(bool(_f(s)["sc.mostrar"]))
	ok(bool(_f(s)["desk.tintero"]), "paso del aviso: tintero")
	no(bool(_f(s)["desk.calendario"]))
	no(bool(_f(s)["desk.mapa"]), "en el prólogo no hay mapa")
	no(bool(_f(s)["hud.cintas"]), "en la buhardilla no hay cintas")
	ok(s.apply(Kit.prologue_v2()[2]).ok)
	ok(s.apply(Kit.prologue_v2()[3]).ok)
	ok(bool(_f(s)["desk.calendario"]), "paso de dormir: calendario")
	ok(s.apply(Kit.prologue_v2()[4]).ok)
	var f := _f(s)
	for k in ["desk.mapa", "desk.bandeja", "desk.pendientes", "nb.diario", "map.recuerdos"]:
		ok(bool(f[k]), "día 1: " + k)
	no(bool(f["tray.anteriores"]), "días anteriores desde el 2")
	no(bool(f["exp.pasar"]), "ninguna hoja completa")

# GDD_v3 §6.9: «Pasar en limpio» aparece por hoja cuando tiene respuesta y dos pruebas; las cintas sólo fuera de casa.
func test_day1_dossier_flags():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue_v2())
	var g := Kit.day1_guide()
	for a in g.slice(0, 4):
		ok(s.apply(a).ok, str(a))
	no(bool(_f(s)["exp.pasar"]), "falta una prueba")
	no(bool(_f(s).get("exp.pasar.Q1", true)))
	ok(s.apply(g[4]).ok)
	ok(bool(_f(s)["exp.pasar"]), "tres ranuras llenas: «Pasar en limpio»")
	ok(bool(_f(s)["exp.pasar.Q1"]))
	ok(s.apply({"t": "go", "place": "L1", "area": "tienda"}).ok)
	ok(bool(_f(s)["hud.cintas"]), "en la tienda: cintas Cuaderno y Expediente")
	ok(s.apply({"t": "leave"}).ok)
	no(bool(_f(s)["hud.cintas"]))
	eq(Kit.advance_to(s, 2, "M"), "")
	ok(bool(_f(s)["tray.anteriores"]), "día 2: días anteriores")

func test_notebook_thresholds():
	var s = Kit.new_sim()
	var clips := {}
	for i in 9:
		clips["RC%04d" % (i + 1)] = {"id": "RC%04d" % (i + 1), "chron_date": "1891-05-04", "tags": [], "ents": []}
	s.st.ded["clips"] = clips
	no(bool(_f(s)["nb.buscar"]), "9 recortes: sin buscador")
	no(bool(_f(s)["nb.agrupar"]), "un solo mes de crónica")
	clips["RC0010"] = {"id": "RC0010", "chron_date": "1890-04-27", "tags": [], "ents": []}
	ok(bool(_f(s)["nb.buscar"]), "10 recortes: buscador")
	ok(bool(_f(s)["nb.agrupar"]), "dos meses de crónica: encabezados por fecha")
	no(bool(_f(s)["nb.filtros"]))
	for i in range(10, 20):
		clips["RC%04d" % (i + 1)] = {"id": "RC%04d" % (i + 1), "tags": [], "ents": []}
	ok(bool(_f(s)["nb.filtros"]), "20 recortes: filtros")
	var idx := {}
	for i in 11:
		idx["e%d" % i] = {}
	s.st.ded["index"] = idx
	no(bool(_f(s)["nb.indice"]), "11 entradas: sin pestaña Índice")
	idx["e11"] = {}
	ok(bool(_f(s)["nb.indice"]), "12 entradas: pestaña Índice")
	no(bool(_f(s)["nb.curiosidades"]))
	s.st.world.eggs["EE1"] = {"tk": 11}
	ok(bool(_f(s)["nb.curiosidades"]), "una curiosidad")

func test_scene_catalog_and_report_flags():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue_v2())
	no(bool(_f(s)["cat.mesa"]))
	ok(s.apply({"t": "go", "place": "L2", "area": "sala", "seat": 214}).ok)
	no(bool(_f(s)["cat.mesa"]), "sin pedidos: «Sobre mi mesa» no está")
	s.st.world.slips[String(s.st.world.visit.id)] = ["D05@BM"]
	ok(bool(_f(s)["cat.mesa"]), "un pedido en la visita")
	ok(s.apply({"t": "leave"}).ok)
	no(bool(_f(s)["sc.pagar"]))
	s.st.world.visit = {"id": "S.x", "chars": [{"id": "wiggins", "sil": true}]}
	ok(bool(_f(s)["sc.pagar"]) and bool(_f(s)["sc.encargar"]), "silueta con la que se habla: pagar y encargar")
	s.st.world.visit = {}
	no(bool(_f(s)["cmp.quemar"]))
	s.st.clock.phase = "final_report"
	ok(bool(_f(s)["cmp.quemar"]), "informe final: quemarlo")
	no(bool(_f(s)["cmp.trampa"]))
	s.st.flags["errata_ofrecida"] = "librero"
	ok(bool(_f(s)["cmp.trampa"]), "si se ofreció: informe trampa")

func test_composer_and_assertion_flags_real_data():
	var s = GameSim.new(repo(), 7)
	var f0 := _f(s)
	no(bool(f0["cmp.telegrama"]) or bool(f0["cmp.carta"]), "sin destinos en el índice")
	no(bool(f0.get("cmp.forma.testigo", true)), "la forma testigo pide un suceso indexado")
	# Harris nombra lo de Suiza en t_ad: tras recortar el encargo la forma testigo se llena
	var v: Dictionary = s.q_view("D23@L1")
	var done := false
	for pi in (v.pages as Array).size():
		for bi in (v.pages[pi] as Array).size():
			for tr in v.pages[pi][bi].parsed.tramos:
				if not done and String(tr.id) == "aviso":
					var sp: Array = load("res://devtools/bots/bot_base.gd").best_window(v.pages[pi][bi].parsed, int(tr.from), int(tr.to))
					done = s.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}).ok
	ok(done)
	ok(bool(_f(s).get("cmp.forma.testigo", false)), "testigo con su blanco lleno")
	# un destino posible (persona del índice) habilita telegrama y carta fuera del prólogo
	ok(s.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok)
	ok(s.apply({"t": "sleep"}).ok)
	load("res://core/deduction/index.gd").add_entities(s.st, s.repo, ["watson"])
	ok(bool(_f(s)["cmp.telegrama"]) and bool(_f(s)["cmp.carta"]), "Watson en el índice: telegrama y carta")
	eq(bool(_f(s)["sc.decir"]), not s.q_assertions().is_empty(), "Decir = hay afirmaciones")

func test_deterministic_persistent_and_blind():
	var s = Kit.new_sim()
	Kit.run(s, Kit.prologue_v2())
	Kit.run(s, Kit.day1_guide())
	var f := _f(s)
	eq(_f(s), f, "determinista")
	var s2 = GameSim.replay(s.repo, 7, s.actions_log(), load("res://tests/fixtures/sim/fakes.gd").new().handlers())
	eq(_f(s2), f, "igual tras cargar (replay)")
	for id in s2.st.ded.get("clips", {}):
		s2.st.ded.clips[id]["tags"] = ["a:otra", "c:falso"]
	eq(_f(s2), f, "ciega a etiquetas ocultas")
