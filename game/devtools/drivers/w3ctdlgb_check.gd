# Diagnóstico W3-CT-DLG-B sobre data/ real (sin ventana): recorre la partida y muestra lo que DICEN las escenas y los
# diálogos del paquete (PRO, M6, M7, HC06, HC07, HC08, HC09, EPI, END.* y respuestas de Mycroft, Crane, el portero).
# ./godot.sh --headless -s devtools/drivers/w3ctdlgb_check.gd [-- --deductor]
#   sin args: el bot pasivo hasta cada escena fija; en el día 8 (T) el camino entra a la Sala de Forasteros (HC06), pregunta
#   a Mycroft y le presenta dos recortes que no son asientos (HB12: error 1 y error 2 -> forasteros_cerrada); en el día 1
#   pregunta a Crane; al final elige pasar la noche en Baker Street (HC09) y entra al epílogo (EPI).
#   --deductor: una partida del bot deductor (oráculo de rutas) y las líneas del paquete que se dijeron + final y su escena.
# Salida: «[origen] who/id: texto plano». Código de salida 1 si algo esperado falta.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

var sim
var repo
var bad := 0
var said := {}   # "<scene>.<id>" -> true

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	repo = Repo.fresh("res://data")
	for e in repo.errors():
		print("DATA ERR ", e)
		bad += 1
	if OS.get_cmdline_user_args().has("--deductor"):
		_deductor()
	elif OS.get_cmdline_user_args().has("--hb12"):
		_hb12()
	else:
		_walk()
	print("\nRESULTADO: %s" % ("OK" if bad == 0 else "%d problemas" % bad))
	quit(1 if bad > 0 else 0)

func _chk(cond: bool, msg: String) -> void:
	if not cond:
		bad += 1
		print("  !! ", msg)

func _act(a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if not bool(r.get("ok", false)):
		print("  (rechazada) ", a, " -> ", r)
	return r

func _bot_until(tk: String) -> void:
	var b = RunBots.make("pasivo")
	b.setup(sim, 1894)
	var until := TimeKey.of(tk)
	var steps := 0
	while steps < 5000 and int(sim.q_clock().tk) < until and String(sim.q_clock().phase) != "done":
		steps += 1
		if not b.step():
			break

# Líneas del diario dichas desde la última marca (kind line), en orden.
var _seen_lines := {}
func _dump_new_lines(title: String) -> void:
	print("\n== ", title, " (", sim.q_clock().date_label, " · ", sim.q_clock().slot_label, " · ", sim.q_clock().phase, ")")
	var all: Dictionary = {}
	for uid in sim.st.world.get("lines", {}):
		all[uid] = sim.st.world.lines[uid]
	for uid in sim.st.scenes.get("lines", {}):
		if not all.has(uid):
			all[uid] = sim.st.scenes.lines[uid]
	var ks: Array = all.keys()
	ks.sort()
	for uid in ks:
		if _seen_lines.has(uid):
			continue
		_seen_lines[uid] = true
		var ln: Dictionary = all[uid]
		var pt: Dictionary = repo.parse_text(String(ln.get("text", "")), {}, String(ln.get("act", "")))
		var sc := String(ln.get("scene", ""))
		said["%s.%s" % [sc, String(ln.get("id", ""))]] = true
		for e in pt.get("errors", []):
			_chk(false, "línea %s con error de marcado: %s" % [uid, e])
		var tags: Array = []
		for t in pt.get("tramos", []):
			for p in t.tags:
				for v in t.tags[p]:
					if p in ["a", "c", "f", "x"]:
						tags.append("%s:%s" % [p, v])
		print("  [%s] %s/%s: %s%s" % [String(ln.get("origin", "")), String(ln.get("who", "")), String(ln.get("id", "")), String(pt.get("plain", "")),
			("   ⟦" + " ".join(PackedStringArray(tags)) + "⟧") if not tags.is_empty() else ""])

func _walk() -> void:
	sim = GameSim.new(repo, 1894)
	_dump_new_lines("prólogo")
	for id in ["presentacion", "encargo", "cace_india", "t_clip"]:
		_chk(said.has("PRO." + id), "PRO dice " + id)
	_bot_until("1.M")
	_dump_new_lines("tutorial (instructor)")
	for id in ["t_link", "t_folio", "t_entry", "t_practice", "t_ad", "t_sleep"]:
		_chk(said.has("PRO." + id), "PRO dice " + id)
	# día 1: la tienda de Crane (gratis): preguntas
	_act({"t": "go", "place": "L1", "area": "tienda"})
	for topic in ["lisle", "fina", "holmes", "tomos", "pell"]:
		if sim.q_index().any(func(x): return String(x.id) == topic):
			_act({"t": "ask", "char": "crane", "topic": topic})
	_dump_new_lines("Crane, día 1")
	_act({"t": "leave"})
	_bot_until("5.dawn")
	_dump_new_lines("M6")
	_chk(said.has("M6.donde"), "M6 dice donde")
	_bot_until("7.night")
	_dump_new_lines("M7")
	_chk(said.has("M7.inteligente") and said.has("M7.donde_duerme") and said.has("M7.trichinopolis"), "M7 dice sus tres líneas de contrato")
	_bot_until("8.T")
	_dump_new_lines("hasta el día 8")
	var r := _act({"t": "go", "place": "L5", "area": "forasteros"})
	_dump_new_lines("HC06, primera visita")
	for id in ["a", "c", "d", "e", "f", "g"]:
		_chk(said.has("HC06." + id), "HC06 dice (%s)" % id)
	_chk(said.keys().any(func(k): return String(k).begins_with("HC06.b")), "HC06 dice (b)")
	for topic in ["lisle", "holmes", "jueves"]:
		if sim.q_index().any(func(x): return String(x.id) == topic):
			_act({"t": "ask", "char": "mycroft", "topic": topic})
	_dump_new_lines("Mycroft, preguntas")
	var clips: Array = sim.q_clips()
	if clips.size() < 1:
		var lines: Array = sim.q_scene().get("lines", [])
		for ln in lines:
			if String(ln.id) == "e":
				_act({"t": "clip_text", "src": {"kind": "line", "ref": String(ln.uid)}, "from": 0, "len": 10})
		clips = sim.q_clips()
	if clips.size() >= 1:
		_act({"t": "present", "char": "mycroft", "item": {"kind": "clip", "id": String(clips[0].id)}})
		_act({"t": "present", "char": "mycroft", "item": {"kind": "clip", "id": String(clips[0].id)}})
		_dump_new_lines("HB12: dos errores")
		_chk(said.has(".hb12_error_1") or said.has("HC06.hb12_error_1") or _said_id("hb12_error_1"), "Mycroft dice hb12_error_1")
		_chk(_said_id("hb12_error_2"), "Mycroft dice hb12_error_2")
		_chk(bool(sim.st.flags.get("forasteros_cerrada", false)), "forasteros_cerrada tras el 2.º error")
	_act({"t": "leave"})
	_bot_until("10.M")
	_dump_new_lines("HC07 + confrontación (inicio)")
	for id in ["compra", "hojea", "conf.1"]:
		_chk(said.has("HC07." + id), "HC07 dice " + id)
	_bot_until("10.T")
	_dump_new_lines("confrontación (callar) e informe final")
	_dump_new_lines("HC08")
	_chk(said.has("HC08.luz") and said.has("HC08.se_va"), "HC08 dice luz y se_va")
	# Park Lane -> noche: Baker Street
	if String(sim.q_clock().phase) == "parklane":
		_act({"t": "leave"})
	if String(sim.q_clock().phase) == "night_choice":
		_act({"t": "night_choice", "where": "baker_street"})
	_dump_new_lines("HC09 (Baker Street) + EPI")
	_chk(said.has("HC09.bs_vidrio"), "HC09 dice bs_vidrio")
	_chk(said.has("EPI.vuelve"), "EPI dice vuelve")
	var en: Dictionary = sim.q_ending()
	print("\nFINAL: ", en.get("ending", ""), " escena ", en.get("scene", ""), " ficha «", en.get("card", ""), "»")
	_print_scene(String(en.get("scene", "")))

func _said_id(id: String) -> bool:
	for k in said:
		if String(k).ends_with("." + id):
			return true
	return false

# Líneas resueltas de una escena (sin decirlas) con el estado actual.
func _print_scene(sid: String) -> void:
	if sid == "":
		return
	var ls: Array = WorldModel.scene_lines(sim.st, repo, sid)
	_chk(not ls.is_empty(), "la escena %s tiene líneas con este estado" % sid)
	for ln in ls:
		print("  [S.%s] %s/%s: %s" % [sid, ln.who, ln.id, String(repo.parse_text(String(ln.text)).get("plain", ""))])

# --hb12: el deductor juega hasta el día 8 (T); entonces la Sala de Forasteros (HC06) y se le presenta a Mycroft el asiento
# sellado de C7 (o C6): HB12 con éxito (hb12_exito, errata_ofrecida = mycroft). Luego una pregunta por el doctor (duelo).
func _hb12() -> void:
	sim = GameSim.new(repo, 1894)
	var b = RunBots.make("deductor")
	b.setup(sim, 1894)
	var until := TimeKey.of("8.T")
	var steps := 0
	while steps < 20000 and int(sim.q_clock().tk) < until and String(sim.q_clock().phase) != "done":
		steps += 1
		if not b.step():
			break
	for uid in sim.st.world.get("lines", {}):
		_seen_lines[uid] = true
	for uid in sim.st.scenes.get("lines", {}):
		_seen_lines[uid] = true
	print("sellado hasta 8.T: ", sim.st.ded.sealed.keys(), " fase ", sim.q_clock().phase, " ", sim.q_clock().slot)
	if String(sim.q_clock().phase) == "visit":
		_act({"t": "leave"})
	_act({"t": "go", "place": "L5", "area": "forasteros"})
	_dump_new_lines("HC06 (deductor)")
	var entry := ""
	for cid in ["C7", "C6"]:
		if entry == "" and sim.st.ded.sealed.has(cid):
			var v = sim.st.ded.sealed[cid]
			entry = String(v.get("id", "")) if typeof(v) == TYPE_DICTIONARY else String(v)
	_chk(entry != "", "hay un asiento sellado de C6 o C7 para presentar")
	if entry != "":
		_act({"t": "present", "char": "mycroft", "item": {"kind": "entry", "id": entry}})
	if sim.q_index().any(func(x): return String(x.id) == "watson"):
		_act({"t": "ask", "char": "mycroft", "topic": "watson"})
	_dump_new_lines("HB12 con éxito + pregunta por el doctor")
	_chk(_said_id("hb12_exito"), "Mycroft dice hb12_exito")
	_chk(String(sim.st.flags.get("errata_ofrecida", "")) == "mycroft", "errata_ofrecida = mycroft")

func _deductor() -> void:
	sim = GameSim.new(repo, 1894)
	var b = RunBots.make("deductor")
	b.setup(sim, 1894)
	var res: Dictionary = b.play(20000)
	print("deductor: ", {"ending": res.get("ending", ""), "rank": res.get("rank", 0), "sealed": res.get("sealed", [])})
	_dump_new_lines("partida del deductor: líneas del paquete")
	var en: Dictionary = sim.q_ending()
	print("\nFINAL: ", en.get("ending", ""), " escena ", en.get("scene", ""), " ficha «", en.get("card", ""), "»")
	_print_scene(String(en.get("scene", "")))
