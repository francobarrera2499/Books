# W4-EPILOGUE: capturas del epílogo con data/ real. Un bot juega la partida hasta el epílogo (deductor -> F1, Baker
# Street; pasivo -> F4, en casa; informa -> F2, publica) y se recorre la pantalla del epílogo con capturas por estadio.
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w4epi res://devtools/drivers/w4epilogue_shots.gd [f1|f4|f2|f3x|f1w] [lento]
extends RefCounted

const RunBots = preload("res://devtools/bots/run_bots.gd")
const Model = preload("res://ui/epilogue/epilogue_model.gd")

var tool
var shell
var g
var s
var mode := "f1"
var shots := {}

func drive(p_tool, scene) -> void:
	tool = p_tool
	var args := OS.get_cmdline_user_args()
	if args.size() > 3:
		mode = String(args[3])
	await tool.frames(4)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	shell.fast = not (args.size() > 4 and String(args[4]) == "lento")
	if not shell.fast:
		mode += "_lento"
	g.save_path = "user://saves/w4epilogue_%s.jsonl" % mode
	var base := mode.trim_suffix("_lento")
	var bot: String = {"f1": "deductor", "f4": "pasivo", "f2": "informa_todo", "f3x": "deductor", "f1w": "deductor"}.get(base, "deductor")
	var seed := 1 if base in ["f1", "f3x", "f1w"] else 3
	g.new_session(seed)
	var b = RunBots.make(bot)
	b.budget_ms = 300000
	b.setup(g.sim, seed)
	for i in 20000:
		if String(g.sim.q_clock().phase) == "epilogue":
			break
		if not b.step():
			break
	if base == "f3x":
		# variante de captura: el doctor expuesto (HB9 2.ª) -> subrayado en 1903, sin F1, con oferta
		g.sim.st.flags["watson_expuesto"] = true
	if base == "f1w":
		# variante de captura: un asiento sellado vuelto a lápiz y sin sus «según» (como test_pencil_wrong_entries_get_notes)
		# -> el lápiz azul lo tacha y le pone su «Dele: …» al margen
		var sealed: Dictionary = g.sim.st.ded.sealed
		var cid := String(sealed.keys()[0])
		var eid := String(sealed[cid])
		sealed.erase(cid)
		var e: Dictionary = g.sim.st.ded.entries[eid]
		e["ink"] = "lapiz"
		for ln in e.lines:
			ln["support"] = []
	print("[w4epi] fase ", g.sim.q_clock().phase, " final ", Model.info(g.sim).ending, " variantes ", Model.info(g.sim).epi)
	shell.show_epilogue()
	s = shell.screen
	await tool.frames(50)
	var last_stage := ""
	for i in 1500:
		var st: Dictionary = s.state()
		var stage := String(st.stage)
		if stage != last_stage:
			last_stage = stage
			await tool.frames(40 if stage in ["noche", "final", "estante"] else 6)
			await _snap("%s_a" % stage)
		await _per_beat(st)
		if stage == "lapiz" or bool(st.done):
			break
		if stage == "tijera":
			await _scissors()
			continue
		if bool(st.offer):
			await _offer()
			continue
		s.advance()
		await tool.frames(3)
	await _lapiz()
	g.end_session()

func _snap(n: String) -> void:
	if shots.has(n):
		return
	shots[n] = true
	if DisplayServer.get_name() == "headless":
		print("[w4epi] (headless) ", mode, "_", n, " ", s.state().stage if s != null else "")
		return
	await tool.snap("%s_%s" % [mode, n])

func _per_beat(st: Dictionary) -> void:
	var stage := String(st.stage)
	var keys: Array = st.keys
	var last := String(keys[-1]) if not keys.is_empty() else ""
	match stage:
		"noche":
			if int(st.beat) == 3:
				await tool.frames(30)
				await _snap("noche_vidrio")
			elif int(st.beat) == 4:
				await tool.frames(40)
				await _snap("noche_silbato")
		"final":
			if int(st.beat) == int(st.beats) - 1:
				await _snap("final_fin")
		"lectura":
			if last == "epilogo.03.leer":
				await tool.frames(4)
				await _snap("lectura_lupa")
			elif last.ends_with("+nota_de_s_h") and last.begins_with("epilogo.04"):
				await tool.frames(4)
				await _snap("lectura_nota_azul")
			elif last == "epilogo.06.desmayo+subraya_first_and_last":
				await _snap("lectura_subraya")
			elif last == "epilogo.09.meses":
				await tool.frames(4)
				await _snap("lectura_hoja2")
			elif int(st.beat) == int(st.beats) - 1:
				await _snap("lectura_fin")
		"concordancia":
			if String(st.ficha) != "":
				await tool.frames(4)
				await _snap("concordancia_ficha")
			if last.begins_with("epilogo.15"):
				await _snap("concordancia_posdata")
		"creditos":
			if s._credits != null and s._credits.strips().size() == 4:
				await _snap("creditos_4")

func _offer() -> void:
	await _snap("lectura_oferta")
	s.choose_publish(not mode.begins_with("f4"))
	await tool.frames(4)
	await _snap("lectura_confirmar")
	s.confirm(true)
	await tool.frames(4)

func _scissors() -> void:
	var cut: Dictionary = Model.cut_target(g.sim)
	await tool.frames(4)
	await _snap("tijera_a")
	s.set_scissors(true)
	var r: Rect2 = s._strand.tramo_rect(int(cut.from), int(cut.to))
	s._strand.follow(r.position + Vector2(r.size.x * 0.45, 12))
	await tool.frames(4)
	await _snap("tijera_lupa")
	var cur := Model.tramo_at(g.sim, "curiosos")
	s.do_cut(int(cur.page), int(cur.from), 8)
	await tool.frames(6)
	await _snap("tijera_otra")
	s.do_cut(int(cut.page), int(cut.from) + 5, 4)
	await tool.frames(3)
	await _snap("tijera_vuelo")
	await tool.frames(30)

func _lapiz() -> void:
	await tool.frames(20)
	await _snap("lapiz_arriba")
	var p = s._pencil
	if p != null:
		var sc: ScrollContainer = p.get_node("Desplazar")
		sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
		await tool.frames(6)
		await _snap("lapiz_abajo")
