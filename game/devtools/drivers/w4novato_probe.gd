# devtools/drivers/w4novato_probe.gd — W4 playtest (diagnóstico): ¿el paso «aviso» del tutorial se puede completar
# si el novato recortó OTRA línea del encargo (Pell: «recorte una línea del encargo, la que guste»)?
# Para cada tramo de D23@L1: partida nueva, ese recorte + los dos de REDH (abril/octubre), cotejo, folio, asiento,
# práctica; luego Composers.options de cada forma de aviso: ¿alguna forma tiene todos sus huecos con opciones?
# ./godot.sh --headless -s devtools/drivers/w4novato_probe.gd
extends SceneTree

const GameSim = preload("res://core/sim/game_sim.gd")
const Composers = preload("res://core/scenes/composers.gd")

func _find(v: Dictionary, tid: String) -> Dictionary:
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			for tr in pages[pi][bi].get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					return {"part": pi, "block": bi, "from": int(tr.from), "to": int(tr.to)}
	return {}

func _clip(sim, view: String, w: Dictionary) -> String:
	var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": int(w.part), "block": int(w.block)}, "from": int(w.from), "len": int(w.to) - int(w.from)})
	return String(r.get("clip", "")) if bool(r.get("ok", false)) else "ERR:" + String(r.get("err", ""))

func _init() -> void:
	var DR = load("res://core/data/data_repo.gd")
	var repo = DR.fresh("res://data")
	var probe = GameSim.new(repo, 7)
	var v: Dictionary = probe.q_view("D23@L1")
	var redh: Dictionary = probe.q_view("D01.REDH@tomo")
	var tramos: Array = []
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		var words := 0
		for bi in (pages[pi] as Array).size():
			var blk: Dictionary = pages[pi][bi]
			words += String(blk.get("parsed", {}).get("plain", "")).split(" ", false).size()
			for tr in blk.get("parsed", {}).get("tramos", []):
				tramos.append({"id": String(tr.id), "part": pi, "block": bi, "from": int(tr.from), "to": int(tr.to)})
		print("PROBE D23 hoja %d: %d palabras" % [pi + 1, words])
	print("PROBE D23 tramos: ", tramos.map(func(t): return "%s@h%d" % [t.id, int(t.part) + 1]))
	var ok_n := 0
	for t in tramos:
		var sim = GameSim.new(repo, 7)
		var c0 := _clip(sim, "D23@L1", t)
		var ca := _clip(sim, "D01.REDH@tomo", _find(redh, "abril"))
		var co := _clip(sim, "D01.REDH@tomo", _find(redh, "octubre"))
		sim.apply({"t": "link", "a": ca, "b": co, "note": ""})
		var rf: Dictionary = sim.apply({"t": "folio_open", "clip": ca})
		var re: Dictionary = sim.apply({"t": "entry_new", "folio": String(rf.get("folio", "")), "template": "T1"})
		var e := String(re.get("entry", ""))
		for x in [[0, "fuente_a", "redh"], [0, "dice_a", "abril_27_1890"], [1, "fuente_b", "redh"], [1, "dice_b", "octubre_9_1890"]]:
			sim.apply({"t": "entry_set", "entry": e, "line": int(x[0]), "field": String(x[1]), "value": String(x[2])})
		sim.apply({"t": "entry_support_add", "entry": e, "line": 0, "item": ca})
		sim.apply({"t": "entry_support_add", "entry": e, "line": 1, "item": co})
		var rp: Dictionary = sim.apply({"t": "practice", "entry": e})
		var tut: Dictionary = sim.q_tutorial()
		var forms: Array = repo.lists().get("ad_forms", [])
		var fillable: Array = []
		var detail: Array = []
		for f in forms:
			var fid := String(f.get("id", ""))
			var all_ok := true
			var counts: Array = []
			for slot in (f.get("slots", {}) as Dictionary).keys():
				var opts: Array = Composers.options(sim.st, repo, fid, String(slot))
				counts.append("%s=%d" % [slot, opts.size()])
				if opts.is_empty():
					all_ok = false
			detail.append("%s(%s)" % [fid, ",".join(counts)])
			if all_ok:
				fillable.append(fid)
		if not fillable.is_empty():
			ok_n += 1
		print("PROBE recorte %s@h%d [%s] práctica=%s paso=%s -> formas completables %s · %s" % [t.id, int(t.part) + 1, c0, str(rp.get("ok", false)), str(tut.get("step", {}).get("id", "?") if typeof(tut.get("step", {})) == TYPE_DICTIONARY else "?"), str(fillable), " ".join(detail)])
	print("PROBE RESUMEN %d de %d tramos de D23 dejan un aviso completable" % [ok_n, tramos.size()])
	quit(0)
