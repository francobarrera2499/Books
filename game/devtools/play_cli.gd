# devtools/play_cli.gd — jugar el sim por texto (W3-BOTS; ARCHITECTURE §9.3). Para agentes y revisores de contenido.
#   ./godot.sh --headless -s devtools/play_cli.gd -- [--data=real|fixture|<root>] [--seed=N]
#        [--script res://…|<ruta del proyecto>] [--do '<comando>']… [--state] [--doc <id>] [--strict]
# Sin --script/--do: imprime el estado inicial (prólogo). Cada comando se reproduce desde cero en cada corrida (el sim es
# determinista): para seguir jugando, agregar líneas al script y volver a correrlo (o save/load del registro).
# --doc <id>: revisión de un documento (sin jugar): tramos con sus etiquetas; un RECORTE DE PRUEBA exacto de cada tramo
#   (ClipRules.snap + inherit) debe caber en una oración, ≤40 palabras y heredar las etiquetas del tramo; los fragmentos
#   de contrato (§4.8, rutas de conclusions.json) que apuntan al documento deben existir y llevar alguna etiqueta a: de su
#   conclusión; Markup.lint por parte. Código de salida 1 si algo falla.
# --strict: una acción rechazada (ok:false) o un comando inválido dan código de salida 1.
# Comandos (uno por línea; «#» comenta; también --do repetible):
#   {"t": …}                      acción (GameSim.apply, §3.5); imprime el resultado
#   q <consulta> [args…]          GameSim.q_<consulta>(args) en JSON (clock, places, tray, accessible, view <vista>,
#                                 catalog <ent>, clips, clip <id>, index, pairs, diary, ledger, entry <id>, scene,
#                                 topics <char>, assertions, visit_plate, plate <id>, report_status, confront, ending,
#                                 epilogue, tutorial, line <uid>, act <id>, preview <json>)
#   read <vista>                  texto de una vista como lo ve el jugador (páginas y bloques numerados)
#   tags <vista>                  ídem con los tramos marcados ⟦#id etiquetas|…⟧ (vista de desarrollo: revela lo oculto)
#   clip <fuente> <texto exacto>  recorta ese texto: fuente = <vista> | <vista>:<pág>:<bloque> | line:<uid> | diary:<id>
#   node <lámina> <nodo>          recorte ajustado de un nodo (o silueta) de una lámina
#   bot <nombre> [hasta <tk>]     el bot (devtools/bots) juega desde aquí hasta la franja (p. ej. «4.dawn», «7.N») o el fin
#   state                         resumen del estado (reloj, visita, lugares, bandeja, legible, índice, libro mayor…)
#   hash | log [n]                state_hash | últimas n acciones aceptadas
#   save <archivo> | load <archivo>   registro de acciones en .work/play/<archivo> (load reproduce desde cero)
#   echo <texto> | help
# Lógica en devtools/bots/play_session.gd (la usan también los tests).
extends SceneTree

const BotData = preload("res://devtools/bots/bot_data.gd")
const PlaySession = preload("res://devtools/bots/play_session.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var data := "real"
	var script_path := ""
	var doc_id := ""
	var show_state := false
	var strict := false
	var seed := 1
	var bad := 0
	var cmds: Array = []
	var i := 0
	while i < args.size():
		var a := String(args[i])
		var val := ""
		if a.contains("="):
			val = a.substr(a.find("=") + 1)
			a = a.get_slice("=", 0)
		elif i + 1 < args.size() and ["--script", "--doc", "--do", "--data", "--seed"].has(a):
			i += 1
			val = String(args[i])
		match a:
			"--data":
				data = val
			"--seed":
				seed = int(val)
			"--script":
				script_path = val
			"--doc":
				doc_id = val
			"--do":
				cmds.append(val)
			"--state":
				show_state = true
			"--strict":
				strict = true
			"--help", "-h":
				PlaySession.new()._help()
				quit(0)
				return
			_:
				print("argumento desconocido: ", a)
				bad += 1
		i += 1
	var repo = BotData.repo(data)
	var errs: Array = repo.errors()
	if not errs.is_empty():
		print("AVISO: data «%s» con %d errores de carga; primeros: %s" % [data, errs.size(), str(errs.slice(0, 5))])
	var s = PlaySession.new(repo, seed)
	s.strict = strict
	s.fails = bad
	if doc_id != "":
		s.review_doc(doc_id)
		quit(1 if s.fails > 0 else 0)
		return
	if script_path != "":
		var lines: Array = s._read_script(script_path)
		if lines.is_empty():
			print("script vacío o inexistente: ", script_path)
			s.fails += 1
		cmds = lines + cmds
	for c in cmds:
		s.exec(String(c))
	if show_state or cmds.is_empty():
		s._p(s.state_text())
	quit(1 if s.fails > 0 else 0)
