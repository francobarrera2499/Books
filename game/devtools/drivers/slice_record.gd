# devtools/drivers/slice_record.gd — escribe los guiones de W4-SLICE (devtools/scripts/slice_<final>.jsonl).
#   ./godot.sh --headless -s devtools/drivers/slice_record.gd -- [f1|f2|f3a|f4|all] [--seed=1] [--dry]
# Juega con devtools/drivers/slice_bot.gd sobre data/ real, reproduce el registro desde cero (GameSim.replay: 0 rechazos)
# y lo escribe anotado: una línea JSON por acción (lo que aplica Shell.run_script / GameSim.apply) y comentarios «#» con la
# franja, lo que llegó al amanecer y los golpes del guion. Cabecera: seed, expect (final), content (hash de data/).
# --dry: sólo imprime el resumen. Salida: «SLICE <final> OK|FALLA …». Sólo escribe bajo devtools/scripts/.
extends SceneTree

const BotData = preload("res://devtools/bots/bot_data.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const SliceBot = preload("res://devtools/drivers/slice_bot.gd")

const ENDINGS := {"f1": "F1", "f2": "F2", "f3a": "F3a", "f4": "F4"}
const TITLES := {
	"f1": "el camino del mejor final (F1 «Al menos un lector»): crédito ante Moran, C6/C7/C10 y ocho más, confrontación completa y la errata a medida",
	"f2": "la misma investigación que f1 hasta el informe final; el informe es fiel (un asiento que dice que Holmes vive) → F2 «El informe fiel», y en 1903 publica la fe de erratas",
	"f3a": "la misma investigación que f1 hasta el informe final; Lisle quema el informe → F3a «El silencio»",
	"f4": "un lector distraído: tres conclusiones, el informe 1 como f1 (crédito y M1) y los demás «Sin novedad», confrontación callada → F4 «Ve, pero no observa»",
}
const MAX_STEPS := 20000

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var which := "all"
	var seed := 1
	var dry := false
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--seed="):
			seed = int(s.substr(7))
		elif s == "--dry":
			dry = true
		elif not s.begins_with("--"):
			which = s
	var repo = BotData.repo("real")
	if not repo.errors().is_empty():
		print("SLICE data con errores: ", str(repo.errors().slice(0, 5)))
	var keys: Array = ENDINGS.keys() if which == "all" else [which]
	var bad := 0
	for k in keys:
		if not ENDINGS.has(k):
			print("SLICE desconocido: ", k)
			bad += 1
			continue
		var r := record(repo, String(k), seed)
		print("SLICE %s %s %s" % [k, "OK" if bool(r.ok) else "FALLA", J.stringify_canon(r.summary)])
		if not bool(r.ok):
			bad += 1
		elif not dry:
			var p := ProjectSettings.globalize_path("res://devtools/scripts").path_join("slice_%s.jsonl" % k)
			DirAccess.make_dir_recursive_absolute(p.get_base_dir())
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(r.text)
			f.close()
			print("SLICE escrito ", p, " (", (r.actions as Array).size(), " acciones)")
	quit(1 if bad > 0 else 0)

# Juega y anota. {ok, summary, text, actions}.
static func record(repo, key: String, seed: int) -> Dictionary:
	var sim = GameSim.new(repo, seed)
	var b = SliceBot.new()
	b.ending = String(ENDINGS[key])
	b.setup(sim, seed)
	var res: Dictionary = b.play(MAX_STEPS)
	var actions: Array = sim.actions_log()
	var text := annotate(repo, seed, key, actions, b.notes)
	var re = GameSim.replay(repo, seed, actions)
	var en: Dictionary = re.q_ending()
	var sealed: Array = re.st.ded.get("sealed", {}).keys()
	sealed.sort()
	var summary := {"ending": String(en.get("ending", "")), "want": String(ENDINGS[key]), "actions": actions.size(),
		"replay_errors": int(re.replay_errors), "bot_errors": (b.stats.errors as Array).slice(0, 5), "oracle": (b.stats.oracle as Array).slice(0, 3),
		"sealed": sealed, "phase": String(re.q_clock().phase), "same_hash": re.state_hash() == sim.state_hash(),
		"variants": en.get("variants", []), "reports": b.stats.reports}
	var ok: bool = summary.ending == summary.want and summary.replay_errors == 0 and summary.phase == "done" and summary.same_hash \
		and (b.stats.errors as Array).is_empty()
	return {"ok": ok, "summary": summary, "text": text, "actions": actions}

# Texto JSONL anotado: reproduce acción por acción para escribir la franja y lo que llegó antes de cada una.
static func annotate(repo, seed: int, key: String, actions: Array, notes: Array) -> String:
	var out: PackedStringArray = []
	out.append("# devtools/scripts/slice_%s.jsonl — guion de W4-SLICE: %s." % [key, String(TITLES.get(key, key))])
	out.append("# Generado por devtools/drivers/slice_record.gd (jugador: devtools/drivers/slice_bot.gd); no editar a mano: regenerar.")
	out.append("# Una acción de GameSim.apply por línea (ARCHITECTURE §3.5); «#» comenta. Juego: ./godot.sh -- --new --seed=%d --script=res://devtools/scripts/slice_%s.jsonl" % [seed, key])
	out.append("# seed: %d" % seed)
	out.append("# expect: %s" % String(ENDINGS[key]))
	out.append("# content: %s" % String(repo.content_hash()))
	var sim = GameSim.new(repo, seed)
	var nd := 0
	var last := ""
	var by_n := {}
	for x in notes:
		var n := int(x.n)
		if not by_n.has(n):
			by_n[n] = []
		by_n[n].append(String(x.text))
	for i in actions.size():
		var c: Dictionary = sim.q_clock()
		var head := "%s|%s" % [str(c.tk), String(c.phase)]
		if head != last:
			last = head
			out.append("# ── %s · %s, %s · %s" % [TimeKey.label(int(c.tk)), String(c.date_label), String(c.slot_label), String(c.phase)])
			var dl: Array = sim.st.react.delivered
			while nd < dl.size():
				var inst: Dictionary = dl[nd]
				out.append("#    llegó %s%s" % [String(inst.get("iid", "")), (" (" + String(inst.how) + ")") if String(inst.get("how", "")) != "" else ""])
				nd += 1
		for t in by_n.get(i, []):
			out.append("# guion: " + String(t))
		var a: Dictionary = actions[i]
		out.append(J.stringify_canon(a))
		var r: Dictionary = sim.apply(a)
		if not bool(r.get("ok", false)):
			out.append("# ¡RECHAZADA! " + String(r.get("err", "")))
	var c2: Dictionary = sim.q_clock()
	out.append("# ── fin · %s · final %s" % [String(c2.phase), String(sim.q_ending().get("ending", ""))])
	return "\n".join(out) + "\n"
