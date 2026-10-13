# devtools/bots/play_session.gd — sesión de juego por texto (W3-BOTS; ARCHITECTURE §9.3): la lógica de devtools/play_cli.gd
# (comandos, vistas de texto, resumen de estado, revisión --doc) en un RefCounted que también usan los tests (T10).
# Toda salida pasa por _p(): se acumula en `out` y, si echo = true, se imprime.
extends RefCounted

const BotData = preload("res://devtools/bots/bot_data.gd")
const RunBots = preload("res://devtools/bots/run_bots.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")
const Markup = preload("res://core/text/markup.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const INHERIT := ["a", "c", "f", "d", "p", "x"]

var repo
var sim
var seed := 1
var fails := 0
var strict := false

var echo := true
var out: PackedStringArray = []

func _init(p_repo = null, p_seed := 1) -> void:
	seed = p_seed
	if p_repo != null:
		repo = p_repo
		sim = GameSim.new(repo, seed)

func _p(s) -> void:
	var t := str(s)
	out.append(t)
	if echo:
		print(t)

func _help() -> void:
	var f := FileAccess.open("res://devtools/play_cli.gd", FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var ln := f.get_line()
		if not ln.begins_with("#"):
			break
		_p(ln)

# Ruta absoluta de un archivo del proyecto (res://… o relativa a C:\Dev\books / absoluta dentro de él).
func _abs(p: String) -> String:
	if p.begins_with("res://"):
		return ProjectSettings.globalize_path(p)
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var ap := p if (p.is_absolute_path() and not p.begins_with("res://")) else root.path_join(p)
	ap = ap.replace("\\", "/").simplify_path()
	var rt := root.replace("\\", "/").to_lower().trim_suffix("/") + "/"
	if not (ap.to_lower() + "/").begins_with(rt):
		_p("ruta fuera del proyecto (prohibido): " + p)
		return ""
	return ap

func _read_script(p: String) -> Array:
	var ap := _abs(p)
	if ap == "" or not FileAccess.file_exists(ap):
		return []
	var out: Array = []
	for ln in FileAccess.get_file_as_string(ap).split("\n"):
		out.append(String(ln).strip_edges())
	return out

func _out(v) -> String:
	return JSON.stringify(v, "  ", true)

func _bad(msg: String) -> void:
	_p("  ✗ " + msg)
	if strict:
		fails += 1

# ------------------------------------------------------------------ comandos
func exec(cmd: String) -> void:
	var c := cmd.strip_edges()
	if c == "" or c.begins_with("#"):
		return
	_p("> " + c)
	if c.begins_with("{"):
		var a = JSON.parse_string(c)
		if typeof(a) != TYPE_DICTIONARY:
			_bad("JSON inválido")
			return
		_apply(a)
		return
	var sp := c.find(" ")
	var verb := c if sp < 0 else c.substr(0, sp)
	var rest := "" if sp < 0 else c.substr(sp + 1).strip_edges()
	match verb:
		"q":
			_query(rest)
		"read":
			_p(view_text(rest, false))
		"tags":
			_p(view_text(rest, true))
		"clip":
			_clip(rest)
		"node":
			var p := rest.split(" ", false)
			if p.size() < 2:
				_bad("uso: node <lámina> <nodo>")
				return
			_apply({"t": "clip_plate", "plate": p[0], "hits": [{"node": p[1], "cover": 0.9, "tight": true}], "touched": [p[1]], "area_frac": 0.05})
		"bot":
			_bot(rest)
		"state":
			_p(state_text())
		"hash":
			_p("  " + sim.state_hash())
		"log":
			var lg: Array = sim.actions_log()
			var n := int(rest) if rest.is_valid_int() else 20
			_p("  %d acciones aceptadas; últimas %d:" % [lg.size(), mini(n, lg.size())])
			for a in lg.slice(maxi(0, lg.size() - n)):
				_p("  " + J.stringify_canon(a))
		"save":
			_save(rest)
		"load":
			_load(rest)
		"echo":
			_p("  " + rest)
		"help":
			_help()
		_:
			_bad("comando desconocido: " + verb + " (help)")

func _apply(a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if bool(r.get("ok", false)):
		var shown := r.duplicate()
		shown.erase("ok")
		_p("  ok " + (J.stringify_canon(shown) if not shown.is_empty() else ""))
		var c: Dictionary = sim.q_clock()
		_p("  [%s · %s · %s]" % [c.date_label, c.slot_label, c.phase])
	else:
		_bad("rechazada: " + J.stringify_canon(r))
	return r

func _query(rest: String) -> void:
	var p := rest.split(" ", false)
	if p.is_empty():
		_bad("uso: q <consulta> [args]")
		return
	var m := "q_" + p[0]
	if not sim.has_method(m):
		_bad("consulta desconocida: " + m)
		return
	var args: Array = []
	var tail := rest.substr(p[0].length()).strip_edges()
	if tail.begins_with("{"):
		args.append(JSON.parse_string(tail))
	else:
		for x in p.slice(1):
			args.append(int(x) if String(x).is_valid_int() and m != "q_view" else String(x))
	_p(_out(sim.callv(m, args)))

func _clip(rest: String) -> void:
	var sp := rest.find(" ")
	if sp < 0:
		_bad("uso: clip <fuente> <texto exacto>")
		return
	var src := rest.substr(0, sp)
	var text := rest.substr(sp + 1).strip_edges().trim_prefix("«").trim_suffix("»").trim_prefix("\"").trim_suffix("\"")
	var cands: Array = []   # [{src, parsed}]
	if src.begins_with("line:"):
		cands.append({"src": {"kind": "line", "ref": src.substr(5)}, "parsed": sim.q_line(src.substr(5)).get("parsed", {})})
	elif src.begins_with("diary:"):
		var did := src.substr(6)
		for e in sim.q_diary():
			if String(e.get("id", "")) == did:
				cands.append({"src": {"kind": "diary", "ref": did}, "parsed": e.get("parsed", {})})
	else:
		var parts := src.split(":")
		var view := String(parts[0])
		var v: Dictionary = sim.q_view(view)
		var pages: Array = v.get("pages", [])
		for pi in pages.size():
			for bi in (pages[pi] as Array).size():
				if parts.size() >= 3 and (int(parts[1]) != pi or int(parts[2]) != bi):
					continue
				cands.append({"src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "parsed": pages[pi][bi].get("parsed", {})})
		if pages.is_empty():
			_bad("vista no legible ahora: " + view)
			return
	for cd in cands:
		var plain := String(cd.parsed.get("plain", ""))
		var at := plain.find(text)
		if at >= 0:
			_apply({"t": "clip_text", "src": cd.src, "from": at, "len": text.length()})
			return
	_bad("texto no encontrado en " + src)

func _bot(rest: String) -> void:
	var p := rest.split(" ", false)
	if p.is_empty():
		_bad("uso: bot <nombre> [hasta <tk>]")
		return
	var b = RunBots.make(p[0])
	if b == null:
		_bad("bot desconocido: %s (%s)" % [p[0], ", ".join(PackedStringArray(RunBots.BOTS))])
		return
	var until := 1 << 30
	if p.size() >= 3 and ["hasta", "until"].has(p[1]):
		until = TimeKey.of(p[2])
	b.setup(sim, seed)
	var n0: int = sim.actions_log().size()
	var steps := 0
	while steps < 20000 and int(sim.q_clock().tk) < until and String(sim.q_clock().phase) != "done":
		steps += 1
		if not b.step():
			break
	var c: Dictionary = sim.q_clock()
	_p("  bot %s: %d pasos, %d acciones aceptadas; ahora %s · %s · %s" % [p[0], steps, sim.actions_log().size() - n0, c.date_label, c.slot_label, c.phase])
	if not (b.stats.errors as Array).is_empty():
		_bad("errores del bot: " + str((b.stats.errors as Array).slice(0, 5)))

func _play_dir() -> String:
	var d := ProjectSettings.globalize_path("res://").path_join("../.work/play").simplify_path()
	DirAccess.make_dir_recursive_absolute(d)
	return d

func _save(name: String) -> void:
	if name == "":
		_bad("uso: save <archivo>")
		return
	var p := _play_dir().path_join(name.get_file())
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		_bad("no se pudo escribir " + p)
		return
	f.store_string(JSON.stringify({"seed": seed, "actions": sim.actions_log()}, "  "))
	f.close()
	_p("  guardado: %s (%d acciones)" % [p, sim.actions_log().size()])

func _load(name: String) -> void:
	var p := name if name.begins_with("res://") else _play_dir().path_join(name.get_file())
	if not FileAccess.file_exists(p):
		_bad("no existe " + p)
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(d) != TYPE_DICTIONARY:
		_bad("registro inválido")
		return
	seed = int(d.get("seed", seed))
	sim = GameSim.replay(repo, seed, d.get("actions", []))
	var c: Dictionary = sim.q_clock()
	_p("  reproducido: %d acciones; %s · %s · %s" % [sim.actions_log().size(), c.date_label, c.slot_label, c.phase])

# ------------------------------------------------------------------ vistas de texto
func view_text(view: String, dev: bool) -> String:
	var v: Dictionary = sim.q_view(view)
	if v.is_empty():
		return "  (no legible ahora: %s)" % view
	var out: PackedStringArray = []
	out.append("  %s — %s" % [String(v.get("title", view)), String(v.get("src_line", ""))])
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var b: Dictionary = pages[pi][bi]
			out.append("  — %s:%d:%d (%s)" % [view, pi, bi, String(b.get("doc", ""))])
			var pt: Dictionary = b.get("parsed", {})
			out.append(_marked(pt) if dev else "  " + String(pt.get("plain", "")).replace("\n", "\n  "))
	return "\n".join(out)

func _marked(pt: Dictionary) -> String:
	var plain := String(pt.get("plain", ""))
	var marks := {}
	for t in pt.get("tramos", []):
		var tg := ", ".join(PackedStringArray(RouteDB.flat_tags(t.get("tags", {}))))
		var o := int(t.from)
		var e := int(t.to)
		marks[o] = String(marks.get(o, "")) + "⟦#%s %s|" % [String(t.get("id", "")), tg]
		marks[e] = "⟧" + String(marks.get(e, ""))
	var s := ""
	for k in plain.length() + 1:
		if marks.has(k):
			s += String(marks[k])
		if k < plain.length():
			s += plain[k]
	return "  " + s.replace("\n", "\n  ")

func state_text() -> String:
	var o: PackedStringArray = []
	var c: Dictionary = sim.q_clock()
	o.append("ESTADO · %s · %s · fase %s · pasadas %d (lote %d) · salió %s%s" % [c.date_label, c.slot_label, c.phase,
		int(c.passes_left), int(c.lot_size), "sí" if bool(c.outing_done) else "no", " · INFORME PENDIENTE" if bool(c.report_due) else ""])
	if String(c.phase) == "prologue":
		var tut: Dictionary = sim.q_tutorial()
		o.append("Tutorial: paso %s (%s)" % [str(tut.get("step", {}).get("id", "")) if typeof(tut.get("step")) == TYPE_DICTIONARY else "", "completo" if bool(tut.get("complete", false)) else "en curso"])
	var sc: Dictionary = sim.q_scene()
	if not sc.is_empty():
		var who: PackedStringArray = []
		for ch in sc.get("chars", []):
			who.append(String(ch.get("id", "")))
		o.append("Escena %s en %s: %s" % [String(sc.get("id", "")), String(sc.get("place", "")), ", ".join(who)])
		for ln in sc.get("lines", []):
			o.append("  [%s] %s: %s" % [String(ln.get("uid", "")), String(ln.get("who", "")), String(ln.get("parsed", {}).get("plain", "")).left(160)])
	var pl: PackedStringArray = []
	for p in sim.q_places():
		if bool(p.get("can_go", false)):
			pl.append("%s.%s%s" % [p.id, p.area, " (gratis)" if bool(p.get("free", false)) else ""])
	o.append("Salidas posibles: " + (", ".join(pl) if not pl.is_empty() else "—"))
	var tr: PackedStringArray = []
	for t in sim.q_tray():
		tr.append("%s «%s»" % [t.view, String(t.get("title", "")).left(50)])
	o.append("Bandeja: " + (", ".join(tr) if not tr.is_empty() else "—"))
	var ac: PackedStringArray = []
	for x in sim.q_accessible():
		ac.append(String(x.view))
	o.append("Legible ahora (%d): %s" % [ac.size(), ", ".join(ac)])
	var ix: PackedStringArray = []
	for e in sim.q_index():
		ix.append(String(e.get("id", "")))
	o.append("Índice (%d): %s" % [ix.size(), ", ".join(ix)])
	var cl: Array = sim.q_clips()
	o.append("Recortes (%d):" % cl.size())
	for x in cl:
		o.append("  %s «%s» — %s" % [x.id, String(x.get("text", "")).left(90), String(x.get("src_line", "")).left(60)])
	var lg: Dictionary = sim.q_ledger()
	var ents: Array = (lg.get("varios", []) as Array) + (lg.get("erratas", []) as Array)
	for f in lg.get("folios", []):
		ents.append_array(f.get("entries", []))
	if not ents.is_empty():
		o.append("Asientos (%d):" % ents.size())
		for eid in ents:
			var e: Dictionary = sim.q_entry(String(eid))
			o.append("  %s %s %s %s formal=%s" % [eid, e.get("template", ""), e.get("ink", ""), J.stringify_canon(e.get("lines", [])).left(160), str(e.get("formal", []))])
	var sealed: Array = sim.st.ded.get("sealed", {}).keys()
	sealed.sort()
	o.append("Sellados: " + (", ".join(PackedStringArray(sealed)) if not sealed.is_empty() else "—"))
	var fl: PackedStringArray = []
	var fk: Array = sim.st.flags.keys()
	fk.sort()
	for k in fk:
		var v = sim.st.flags[k]
		if v != null and not (typeof(v) == TYPE_BOOL and v == false) and str(v) != "" and str(v) != "0":
			fl.append("%s=%s" % [k, str(v)])
	o.append("Banderas: " + (", ".join(fl) if not fl.is_empty() else "—"))
	return "\n".join(o)

# ------------------------------------------------------------------ revisión de documento (--doc)
func review_doc(id: String) -> void:
	var d: Dictionary = repo.doc(id)
	if d.is_empty():
		_p("FALLA: documento %s inexistente en la data" % id)
		fails += 1
		return
	_p("DOC %s — %s (%s, clase %s, %s)" % [id, String(d.get("title", "")), String(d.get("src_type", "")), String(d.get("class", "")), String(d.get("date", ""))])
	for cp in d.get("copies", []):
		_p("  ejemplar %s: %s vía %s, %s…%s" % [cp.get("id", ""), cp.get("holder", ""), cp.get("via", ""), cp.get("from", ""), cp.get("to", "")])
	var words := 0
	var ctx: Dictionary = repo.markup_ctx()
	for p in d.get("parts", []):
		var pid := String(p.get("id", ""))
		var pt: Dictionary = repo.parsed(id, pid)
		words += (pt.get("words", []) as Array).size()
		_p("— parte %s: %d palabras, %d oraciones, %d tramos" % [pid, (pt.get("words", []) as Array).size(), (pt.get("sentences", []) as Array).size(), (pt.get("tramos", []) as Array).size()])
		for e in Markup.lint(String(p.get("text", "")), ctx):
			_p("  FALLA lint: " + String(e))
			fails += 1
		for t in pt.get("tramos", []):
			var res := tramo_check(pt, t)
			var tags := ", ".join(PackedStringArray(RouteDB.flat_tags(t.get("tags", {}))))
			var txt := String(pt.get("plain", "")).substr(int(t.from), int(t.to) - int(t.from))
			_p("  %s #%s [%s] «%s»%s" % ["OK   " if res == "" else "FALLA", String(t.get("id", "")), tags, txt.left(120), "" if res == "" else " — " + res])
			if res != "":
				fails += 1
	_p("  palabras: %d (declaradas: %s)" % [words, str(d.get("words", "?"))])
	# fragmentos de contrato que apuntan a este documento
	var seen := {}
	var n := 0
	for c in repo.conclusions():
		var cid := String(c.get("id", ""))
		var ct: Array = RouteDB.conc_tags(repo, cid)
		for r in RouteDB.routes(repo, cid):
			for f in r.get("frags", []):
				var ref := String(f.get("ref", ""))
				if not ref.begins_with(id + "#"):
					continue
				var k := cid + "|" + ref + "|" + String(f.get("copy", ""))
				if seen.has(k):
					continue
				seen[k] = true
				n += 1
				var msg := frag_check(cid, ct, ref, String(f.get("copy", "")))
				_p("  %s %s %s%s%s" % ["OK   " if msg == "" else "FALLA", String(r.get("id", cid)), ref, (" (" + String(f.copy) + ")") if String(f.get("copy", "")) != "" else "", "" if msg == "" else " — " + msg])
				if msg != "":
					fails += 1
	_p("  fragmentos de contrato que lo citan: %d" % n)
	_p("RESULTADO: " + ("OK" if fails == 0 else "%d fallas" % fails))

# "" si un recorte exacto del tramo es legal y hereda sus etiquetas (y el propio tramo).
func tramo_check(pt: Dictionary, t: Dictionary) -> String:
	var s: Dictionary = ClipRules.snap(pt, int(t.from), int(t.to) - int(t.from))
	if not bool(s.get("ok", false)):
		return "el recorte de prueba no es legal: " + String(s.get("err", ""))
	var inh: Dictionary = ClipRules.inherit(pt, int(s.from), int(s.to))
	if String(inh.get("tramo", "")) != String(t.get("id", "")):
		return "el recorte de prueba hereda #%s" % String(inh.get("tramo", ""))
	var miss: Array = []
	for pre in INHERIT:
		for v in t.get("tags", {}).get(pre, []):
			if not (inh.get("tags", []) as Array).has(pre + ":" + String(v)):
				miss.append(pre + ":" + String(v))
	for e in t.get("tags", {}).get("e", []):
		if not (inh.get("ents", []) as Array).has(e):
			miss.append("e:" + String(e))
	if not miss.is_empty():
		return "no hereda " + str(miss)
	return ""

func frag_check(cid: String, ct: Array, ref: String, copy: String) -> String:
	var did := ref.get_slice("#", 0)
	var tid := ref.get_slice("#", 1)
	var hit: Dictionary = RouteDB.find_tramo(repo, did, tid)
	if hit.is_empty():
		return "no existe el tramo #" + tid
	if copy != "" and repo.copy(copy).is_empty():
		return "ejemplar %s inexistente" % copy
	var a_tags: Array = []
	for x in RouteDB.flat_tags(hit.tramo.get("tags", {})):
		if String(x).begins_with("a:"):
			a_tags.append(String(x).substr(2))
	if ct.is_empty():
		return ""
	for x in a_tags:
		if ct.has(x):
			return tramo_check(hit.parsed, hit.tramo)
	return "el tramo no lleva ninguna etiqueta a: de %s (lleva %s)" % [cid, str(a_tags)]
