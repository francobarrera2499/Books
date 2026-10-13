# devtools/drivers/w4fix_catcheck.gd — ¿cada papeleta de un registro se puede pedir por el catálogo (alguna entidad del
# índice de ese momento lista el documento)? Recorre los guiones slice_* y el registro del deductor sobre data/ real.
extends SceneTree
const BotData = preload("res://devtools/bots/bot_data.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const J = preload("res://core/util/j.gd")
func _init():
	_run.call_deferred()
func _check(repo, name: String, actions: Array, seed: int) -> void:
	var sim = GameSim.new(repo, seed)
	var miss: Array = []
	for a in actions:
		if String(a.get("t", "")) == "slip":
			var did := String(a.doc)
			var found := ""
			for x in sim.q_index():
				if found == "" and String(x.get("kind", "")) != "act_ref":
					for r in sim.q_catalog(String(x.get("id", ""))):
						if String(r.get("doc", "")) == did:
							found = String(x.id)
			if found == "":
				var ents: Array = repo.doc(did).get("catalog", {}).get("entities", [])
				miss.append("%s %s (entidades %s)" % [sim.q_clock().date_label + " " + String(sim.q_clock().slot), did, str(ents)])
		sim.apply(a)
	print("CATCHECK %s: %d papeletas sin entidad del índice: %s" % [name, miss.size(), str(miss)])
func _run():
	var repo = BotData.repo("real")
	for f in ["f1", "f2", "f3a", "f4"]:
		var acts: Array = []
		for ln in FileAccess.get_file_as_string("res://devtools/scripts/slice_%s.jsonl" % f).split("\n"):
			var s := ln.strip_edges()
			if s == "" or s.begins_with("#"):
				continue
			var v = J.parse_str(s)
			if typeof(v) == TYPE_DICTIONARY:
				acts.append(v)
		_check(repo, "slice_" + f, acts, 1)
	for nm in ["deductor", "novato", "solo_bm"]:
		var out: Array = []
		RunBots.run_one(repo, nm, 1, 20000, 600000, out)
		_check(repo, nm, out[0].sim.actions_log(), 1)
	quit(0)
