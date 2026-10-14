# devtools/bots/run_bots.gd — CLI de bots (W3-BOTS; ARCHITECTURE §9.3).
#   ./godot.sh --headless -s devtools/bots/run_bots.gd -- <bot|all> <n_partidas> [semilla] [--data=fixture|real|<root>]
#        [--max-steps=N] [--budget-ms=N] [--out=<archivo bajo .work/bots>] [--full]
# Imprime UNA línea JSON (stdout; la única que empieza con «{») con {data, content, skip?, results:{bot: {bot, n, seed0,
# runs:[...], summary:{...}}}}. Partida i: GameSim(repo, semilla+i) y el bot con la misma semilla. --full deja en runs los
# resultados completos (sin --full: ending, rank, sealed, words_read, est_minutes, est_minutes_act, acts, steps, errors[:3]).
# --budget-ms = presupuesto de reloj por partida (salvaguarda contra bucles; 0 = sin tope; por defecto 120000).
# También se usa como biblioteca (tests T10/T24, play_cli): make(name), run_one(repo, name, seed), run_many(...), summarize(...).
extends SceneTree

const BotData = preload("res://devtools/bots/bot_data.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")

const BOTS := ["deductor", "novato", "pasivo", "pesca", "fuerza_bruta", "sabelotodo", "recorta_todo", "cebo", "informa_todo",
	"solo_bm", "confront_azar", "mycroft_azar"]

static func make(name: String):
	var p := "res://devtools/bots/bot_%s.gd" % name
	if not BOTS.has(name) or not ResourceLoader.exists(p):
		return null
	return load(p).new()

# Una partida completa. Devuelve el resultado de bot.play (+ log_size). bot_out (opcional) recibe el bot jugado.
static func run_one(repo, name: String, seed: int, max_steps := 20000, budget_ms := 120000, bot_out: Array = []) -> Dictionary:
	var b = make(name)
	if b == null:
		return {"bot": name, "seed": seed, "errors": ["bot desconocido"], "ending": "", "rank": 0}
	var sim = GameSim.new(repo, seed)
	b.budget_ms = budget_ms
	b.setup(sim, seed)
	var r: Dictionary = b.play(max_steps)
	r["log_size"] = b.log.size()
	r["ms"] = b.play_ms
	r["apply_ms"] = b.apply_us / 1000
	bot_out.append(b)
	return r

static func short(r: Dictionary) -> Dictionary:
	var errs: Array = r.get("errors", [])
	return {"seed": r.get("seed", 0), "ending": r.get("ending", ""), "rank": r.get("rank", 0), "sealed": r.get("sealed", []),
		"words_read": r.get("words_read", 0), "est_minutes": r.get("est_minutes", 0.0), "est_minutes_act": r.get("est_minutes_act", {}),
		"play_minutes": r.get("play_minutes", 0.0), "play_minutes_act": r.get("play_minutes_act", {}),
		"acts": r.get("acts", 0), "steps": r.get("steps", 0), "phase": r.get("phase", ""), "errors": errs.slice(0, 3),
		"n_errors": errs.size(), "oracle": (r.get("oracle", []) as Array).slice(0, 3), "runaway": r.get("runaway", ""),
		"flags": r.get("flags", {}), "mycroft": (r.get("mycroft", []) as Array).size(), "blocked": r.get("blocked", {}), "ms": r.get("ms", 0), "apply_ms": r.get("apply_ms", 0)}

static func summarize(runs: Array) -> Dictionary:
	var endings := {}
	var best := 99
	var worst := 0
	var sealed_n: Array = []
	var c6_7_10 := 0
	var errs := 0
	var mins: Array = []
	var mins3: Array = []
	for r in runs:
		var e := String(r.get("ending", ""))
		endings[e] = int(endings.get(e, 0)) + 1
		var rk := int(r.get("rank", 0))
		if rk > 0:
			best = mini(best, rk)
			worst = maxi(worst, rk)
		var s: Array = r.get("sealed", [])
		sealed_n.append(s.size())
		if s.has("C6") and s.has("C7") and s.has("C10"):
			c6_7_10 += 1
		errs += int(r.get("n_errors", (r.get("errors", []) as Array).size()))
		mins.append(float(r.get("est_minutes", 0.0)))
		mins3.append(float(r.get("est_minutes_act", {}).get("III", 0.0)))
	var n := runs.size()
	return {"n": n, "endings": endings, "best_rank": best if best < 99 else 0, "worst_rank": worst,
		"sealed_mean": (_sum(sealed_n) / n) if n > 0 else 0.0, "sealed_max": (sealed_n.max() if n > 0 else 0),
		"c6_c7_c10": c6_7_10, "c6_c7_c10_rate": (float(c6_7_10) / n) if n > 0 else 0.0, "errors": errs,
		"est_minutes_mean": (_sum(mins) / n) if n > 0 else 0.0, "act3_minutes_mean": (_sum(mins3) / n) if n > 0 else 0.0,
		"act3_minutes_max": (mins3.max() if n > 0 else 0.0)}

static func _sum(a: Array) -> float:
	var t := 0.0
	for x in a:
		t += float(x)
	return t

static func run_many(repo, name: String, n: int, seed0: int, max_steps := 20000, full := false, budget_ms := 120000) -> Dictionary:
	var runs: Array = []
	for i in n:
		var r := run_one(repo, name, seed0 + i, max_steps, budget_ms)
		runs.append(r if full else short(r))
	return {"bot": name, "n": n, "seed0": seed0, "runs": runs, "summary": summarize(runs)}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var pos: Array = []
	var opts := {"data": "fixture", "max-steps": "20000", "budget-ms": "120000", "out": "", "full": ""}
	for a in args:
		if a.begins_with("--"):
			var kv := a.substr(2)
			if kv.contains("="):
				opts[kv.get_slice("=", 0)] = kv.substr(kv.find("=") + 1)
			else:
				opts[kv] = "1"
		else:
			pos.append(a)
	if pos.is_empty():
		print("uso: run_bots.gd -- <bot|all> <n_partidas> [semilla] [--data=fixture|real|<root>] [--max-steps=N] [--budget-ms=N] [--out=f] [--full]")
		print("bots: ", ", ".join(PackedStringArray(BOTS)))
		quit(1)
		return
	var name := String(pos[0])
	var n := int(pos[1]) if pos.size() > 1 else 1
	var seed0 := int(pos[2]) if pos.size() > 2 else 1
	var repo = BotData.repo(String(opts.data))
	var content := BotData.content_report(repo)
	var out := {"data": String(opts.data), "content": content}
	if not bool(content.ok):
		out["skip"] = "dataset no jugable: faltan rutas ★ completas de %s; errores %s" % [str(content.missing), str(content.errors)]
	var names: Array = BOTS if name == "all" else [name]
	var res := {}
	for nm in names:
		if make(String(nm)) == null:
			res[nm] = {"error": "bot desconocido"}
			continue
		res[nm] = run_many(repo, String(nm), n, seed0, int(opts["max-steps"]), opts.full != "", int(opts["budget-ms"]))
	out["results"] = res
	var txt := JSON.stringify(out)
	if String(opts.out) != "":
		var p := BotData.work_dir().path_join(String(opts.out).get_file())
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out, "  "))
			f.close()
	print(txt)
	quit(0)
