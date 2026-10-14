# W4-SLICE · la partida completa por la UI REAL, headless (ARCHITECTURE §10 ola 4): la Shell de main.tscn con el autoload
# Game y data/ real juega devtools/scripts/slice_f1.jsonl (prólogo → día 10 → epílogo, F1) y slice_f4.jsonl (F4) con
# devtools/drivers/slice_ui_runner.gd: cada acción la hace su widget (mapa, calendario, panel de escena, expediente,
# cuaderno, compositores, informe, confrontación, elección nocturna; ver el runner) y el registro debe recibir EXACTAMENTE
# la acción del guion (sin respaldos por Game.act para esos verbos); en cada paso la pantalla está en el modo de su fase;
# ningún error del motor (el runner de tests cuenta los push_error); el estado final es el mismo, byte a byte, que el de
# la reproducción headless del guion. La versión con ventana y capturas de cada día: devtools/drivers/slice_ui.gd.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 600
const Shell = preload("res://ui/shell.gd")
const Runner = preload("res://devtools/drivers/slice_ui_runner.gd")
const S = preload("res://devtools/drivers/slice_script.gd")

# CORE-EXPEDIENTE (v3): los guiones grabados con el libro de conclusiones (pares, asientos, pasadas por lote) ya no se
# reproducen. Hasta regenerarlos con devtools/drivers/slice_record.gd sobre data/ v3 completa (CONTENIDO y REACCIONES),
# la rebanada queda como contenido pendiente.
const V2_ACTS := ["link", "unlink", "folio_open", "entry_new", "entry_set", "entry_support_add", "entry_delete", "practice", "pass_clean", "clip_measure"]

func _stale() -> bool:
	for key in ["f1", "f4"]:
		var sc := S.load_script(S.path(key))
		if not bool(sc.ok):
			continue
		for a in sc.actions:
			if V2_ACTS.has(String(a.get("t", ""))):
				pending_content("devtools/scripts/slice_%s.jsonl es un guion v2 (%s): regenerar con slice_record.gd cuando data/ v3 esté completa" % [key, String(a.t)])
				return true
	return false
const GameSim = preload("res://core/sim/game_sim.gd")

var sh = null
var g = null
var old_size := Vector2i.ZERO

func before_each() -> void:
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)
	g = tree.root.get_node("Game")
	g.repo_override = null

func after_each() -> void:
	if g != null and g.sim != null:
		g.end_session()
	if sh != null and is_instance_valid(sh):
		sh.free()
	sh = null
	if g != null:
		g.save_path = g.SAVE_PATH
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

# «tool» del runner (como devtools/shot.gd, sin capturas)
func frames(n: int) -> void:
	for i in n:
		await tree.process_frame

func snap(_name := "") -> void:
	pass

func _play(key: String) -> Dictionary:
	sh = Shell.new()
	tree.root.add_child(sh)
	await frames(2)
	var r = Runner.new()
	r.snaps = false
	r.setup(self, sh, g)
	r.save_path = tmp_dir().path_join("slice_%s.jsonl" % key)
	var res: Dictionary = await r.run(key)
	print("  perfil %s: %s" % [key, JSON.stringify(res.get("prof", {}))])
	return res

func _check(key: String, res: Dictionary, must_ui: Array) -> void:
	var sc := S.load_script(S.path(key))
	eq(res.get("fails", ["?"]), [], "%s: la UI juega el guion sin fallas" % key)
	eq(res.get("fallbacks", {"?": 1}), {}, "%s: ningún verbo cayó al respaldo de Game.act" % key)
	eq(String(res.get("ending", "")), String(sc.expect), "%s: final por la UI" % key)
	eq(int(res.get("log", 0)), (sc.actions as Array).size(), "%s: el registro tiene todas las acciones del guion" % key)
	var via: Dictionary = res.get("via_ui", {})
	for t in must_ui:
		ok(int(via.get(t, 0)) >= 1, "%s: «%s» se hizo con su widget (%s)" % [key, t, str(via)])
	# el registro real puede traer, además, las hojas del expediente que la carpeta mostró (examine «sheet/<qid>», playtest
	# v3): sin ellas es el guion, y la partida por la UI = la reproducción headless de ese registro
	var full: Array = res.get("full_log", [])
	var bare: Array = full.filter(func(x): return not (String(x.get("t", "")) == "examine" and String(x.get("ref", "")).begins_with("sheet/")))
	eq(bare.size(), (sc.actions as Array).size(), "%s: sin las hojas mostradas, el registro es el guion" % key)
	var re = GameSim.replay(repo(), int(sc.seed), full if not full.is_empty() else sc.actions)
	eq(String(res.get("hash", "")), re.state_hash(), "%s: la partida por la UI = la reproducción headless del registro" % key)

func test_f1_through_the_ui() -> void:
	if _stale():
		return
	var res := await _play("f1")
	_check("f1", res, ["go", "leave", "end_slot", "sleep", "ask", "assert", "report_submit", "confront", "night_choice",
		"compose_ad", "compose_telegram", "compose_letter", "dq_answer", "dq_proof", "dq_confirm"])

func test_f4_through_the_ui() -> void:
	if _stale():
		return
	var res := await _play("f4")
	_check("f4", res, ["go", "end_slot", "sleep", "report_submit", "confront", "night_choice", "dq_answer", "dq_proof", "dq_confirm"])
