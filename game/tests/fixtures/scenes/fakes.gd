# Dobles de prueba de W2-SCENES: reemplazan Index/Clipper/Ledger/Validator (W2-DED) y Director/Effects/MoranAgent
# (W2-REACT) en core/scenes/deps.gd para probar diálogo, confrontación, compositores y finales sin depender de su avance.
# Estado de los dobles (los tests lo arman a mano; sólo los dobles lo leen):
#   st.ded.index {ent:true} · st.ded.clips {id: {id,text,ents:[{id,label}],tags:["a:x"],origin,copy,cls,src_kind,view}}
#   st.ded.entries {id: {id,template,lines:[{fields,support}],ink, fake_cid?, fake_ok?}} · st.ded.pairs · st.ded.sealed
#   st.react.imm_calls / imm_lines {reaction: [line|{line,who}]} / eff_calls / cats {item_id: [cats]}
# Uso: before_each -> Fakes.install(); after_each -> Fakes.uninstall().
extends RefCounted

const Deps = preload("res://core/scenes/deps.gd")
const GS = "res://core/sim/game_state.gd"

class FIndex:
	static func has(st, ent: String) -> bool:
		return st.ded.get("index", {}).has(ent)
	static func known(st, repo) -> Array:
		var ks: Array = st.ded.get("index", {}).keys()
		ks.sort()
		return ks
	static func add_entities(st, repo, ents: Array) -> void:
		if not st.ded.has("index"):
			st.ded["index"] = {}
		for e in ents:
			st.ded.index[String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)] = true
		if not st.react.has("added"):
			st.react["added"] = []
		st.react.added.append_array(ents)

class FClipper:
	static func get_clip(st, id: String) -> Dictionary:
		var c = st.ded.get("clips", {}).get(id)
		return c.duplicate(true) if typeof(c) == TYPE_DICTIONARY else {}
	static func visible(st, id: String) -> Dictionary:
		var c := get_clip(st, id)
		if c.is_empty():
			return {}
		return {"id": id, "text": String(c.get("text", "")), "ents": c.get("ents", []).duplicate(true), "origin": String(c.get("origin", "")),
			"src_line": String(c.get("src_line", "")), "caption": "", "chron_date": ""}

class FLedger:
	static func entry_clips(st, entry_id: String) -> Array:
		var e = st.ded.get("entries", {}).get(entry_id, {})
		var out: Array = []
		for ln in e.get("lines", []):
			for it in ln.get("support", []):
				var p = st.ded.get("pairs", {}).get(String(it))
				var ids: Array = [String(p.a), String(p.b)] if typeof(p) == TYPE_DICTIONARY else [String(it)]
				for c in ids:
					if not out.has(c):
						out.append(c)
		return out

class FValidator:
	static func entry_tags(st, entry_id: String) -> Array:
		var out: Array = []
		for c in FLedger.entry_clips(st, entry_id):
			for t in st.ded.get("clips", {}).get(c, {}).get("tags", []):
				if not out.has(t):
					out.append(t)
		out.sort()
		return out
	# ok si fake_ok != false y los recortes (pares expandidos) tienen ≥2 orígenes distintos.
	static func entry_ok(st, repo, entry_id: String) -> Dictionary:
		var e = st.ded.get("entries", {}).get(entry_id, {})
		var origins := {}
		for c in FLedger.entry_clips(st, entry_id):
			origins[String(st.ded.get("clips", {}).get(c, {}).get("origin", ""))] = true
		var okk: bool = bool(e.get("fake_ok", true)) and origins.size() >= 2
		return {"ok": okk, "cid": String(e.get("fake_cid", "")), "failed": [] if okk else [3]}
	static func which_conclusion(repo, entry: Dictionary, sealed: Dictionary) -> String:
		return String(entry.get("fake_cid", ""))
	static func values_match(repo, entry: Dictionary, cid: String, sealed: Dictionary) -> bool:
		return String(entry.get("fake_cid", "")) == cid

class FDirector:
	# Simula HolmesAgent/Effects para HB4: cuenta hb4_veces y, a la 2.ª, cierra la consulta 2 días.
	static func immediate(st, repo, ev: Dictionary) -> Array:
		if not st.react.has("imm_calls"):
			st.react["imm_calls"] = []
		st.react.imm_calls.append(ev.duplicate(true))
		var r := String(ev.get("_reaction", ""))
		if r == "HB4":
			var n := int(st.flags.get("hb4_veces", 0)) + 1
			st.flags["hb4_veces"] = n
			if n == 2:
				st.flags["consulta_cerrada_hasta"] = int(ev.get("day", 0)) + 2
		return st.react.get("imm_lines", {}).get(r, []).duplicate(true)

class FEffects:
	static func apply(st, repo, inst: Dictionary, soft: bool) -> void:
		if not st.react.has("eff_calls"):
			st.react["eff_calls"] = []
		st.react.eff_calls.append(inst.duplicate(true))

class FMoran:
	static func report_cats(st, repo, item: Dictionary) -> Array:
		return st.react.get("cats", {}).get(String(item.get("id", "")), []).duplicate()

static func install() -> void:
	Deps.Index = FIndex
	Deps.Clipper = FClipper
	Deps.Ledger = FLedger
	Deps.Validator = FValidator
	Deps.Director = FDirector
	Deps.Effects = FEffects
	Deps.MoranAgent = FMoran

static func uninstall() -> void:
	Deps.reset()

static func repo():
	return load("res://core/data/data_repo.gd").load_dir("res://tests/fixtures/scenes/data")

# GameState con reloj, visita y deducción de dobles. opts: {day, slot, phase, chars, visit_id, place, scene, index:[ents]}
static func state(repo, opts := {}):
	var st = load(GS).new()
	st.seed = int(opts.get("seed", 7))
	st.clock = {"day": int(opts.get("day", 3)), "slot": String(opts.get("slot", "M")), "phase": String(opts.get("phase", "visit"))}
	var chars: Array = opts.get("chars", [])
	st.world = {"visit": {"id": String(opts.get("visit_id", "S.L4.%d.%s" % [st.clock.day, st.clock.slot])), "place": String(opts.get("place", "L4")),
		"area": "consulta", "chars": chars.map(func(c): return {"id": c, "pose": "de_pie"})}}
	if opts.has("scene"):
		st.world.visit["scene"] = String(opts.scene)
	var idx := {}
	for e in opts.get("index", []):
		idx[String(e)] = true
	st.ded = {"index": idx, "clips": {}, "entries": {}, "pairs": {}, "sealed": {}}
	st.react = {}
	st.flags = {}
	st.events = []
	st.seq = {}
	load("res://core/scenes/dialogue.gd").init_state(st, repo)
	load("res://core/scenes/confrontation.gd").init_state(st, repo)
	return st

static func clip(st, id: String, text: String, ents: Array, tags: Array, origin: String, extra := {}) -> String:
	var es: Array = []
	for e in ents:
		es.append(e if typeof(e) == TYPE_DICTIONARY else {"id": String(e), "label": String(e)})
	var c := {"id": id, "text": text, "ents": es, "tags": tags.duplicate(), "origin": origin, "copy": "", "cls": "I", "src_kind": "doc", "view": ""}
	for k in extra:
		c[k] = extra[k]
	st.ded.clips[id] = c
	for e in es:
		st.ded.index[String(e.id)] = true
	return id

# lines: [{fields:{}, support:[]}]
static func entry(st, id: String, template: String, lines: Array, ink := "lapiz", extra := {}) -> String:
	var e := {"id": id, "folio": "varios", "template": template, "lines": lines.duplicate(true), "ink": ink}
	for k in extra:
		e[k] = extra[k]
	st.ded.entries[id] = e
	return id
