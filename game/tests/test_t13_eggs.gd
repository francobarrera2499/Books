# T13 — easter eggs (GDD §13, §15.5; ARCHITECTURE §4.16, §9.2). Dueño: W2-STRUCT.
#  - 13 huevos EE01…EE13, cada uno con nota y un disparador que W2-SIM sabe leer (clip_tag, pair_tags, pairs_over) o
#    «final» (EE12, la ficha del final);
#  - las notas de Marginalia no tienen tramos ni etiquetas (no son fuentes);
#  - todo fragmento con x:EE.. existe como huevo y NO lleva etiquetas de C2–C13 (grupos resueltos + tags_extra);
#  - ningún disparador pairs_over usa un fragmento de ruta de C2–C13, y ninguna ruta de C2–C13 usa un fragmento x:;
#  - ninguna reacción se dispara por un huevo (no agregan fragmentos a ninguna ruta);
#  - cada huevo tiene su fragmento en el contenido (faltantes → pending_content).
# Negativos sobre tests/fixtures/struct_bad.
extends "res://tests/test_base.gd"

const Markup = preload("res://core/text/markup.gd")

const TIMEOUT_S := 60.0
const KINDS := ["clip_tag", "pair_tags", "pairs_over", "final"]
const CH_CODES := ["kbm", "kw", "kh", "ks", "kt"]

var _rp = null

func before_each() -> void:
	_rp = repo()

# ---------------- fragmentos de data/ ----------------
# [{ref, tags:["a:x", …]}]: tramos de docs, líneas de escenas y diálogos, nodos, rastros de reacciones.
func _frags() -> Array:
	if _rp.cache.has("t13_frags"):
		return _rp.cache["t13_frags"]
	var out: Array = []
	var tctx: Dictionary = _rp.markup_ctx().duplicate()
	tctx["allow_placeholders"] = true
	var ids: Array = _rp.docs().keys()
	ids.sort()
	for id in ids:
		for p in _rp.doc(id).get("parts", []):
			for t in _rp.parsed(id, String(p.id)).get("tramos", []):
				out.append({"ref": "%s#%s" % [id, t.id], "tags": _pref(t.tags)})
	var sids: Array = _rp.scenes().keys()
	sids.sort()
	for sid in sids:
		var sc: Dictionary = _rp.scene(sid)
		var lines: Array = sc.get("lines", []).duplicate()
		for v in sc.get("variants", []):
			lines.append_array(v.get("append", []))
			for lid in v.get("replace", {}):
				lines.append({"id": lid, "text": v.replace[lid]})
		for ln in lines:
			var texts: Array = []
			if ln.has("text"):
				texts.append(String(ln.text))
			if typeof(ln.get("tpl")) == TYPE_DICTIONARY:
				for code in ln.tpl:
					texts.append(String(ln.tpl[code]))
			for tx in texts:
				out.append({"ref": "S:%s.%s" % [sid, ln.id], "tags": _text_tags(tx, tctx)})
	var cids: Array = _rp.dialogues().keys()
	cids.sort()
	for cid in cids:
		for ln in _rp.dialogue(cid).get("lines", []):
			out.append({"ref": "L:%s.%s" % [cid, ln.id], "tags": _text_tags(String(ln.get("text", "")), tctx)})
	for coll in [_rp.places(), _rp.plates()]:
		var pids: Array = coll.keys()
		pids.sort()
		for pid in pids:
			for nd in coll[pid].get("nodes", []):
				var tg: Array = []
				for x in nd.get("tags", []):
					tg.append(String(x))
				tg.append_array(_text_tags(String(nd.get("examine", "")), tctx))
				out.append({"ref": "N:%s.%s" % [pid, nd.id], "tags": tg})
	for r in _rp.reactions():
		for rs in r.get("rastro", []):
			if rs.has("texto"):
				var pt := Markup.parse(String(rs.texto), tctx)
				for t in pt.tramos:
					out.append({"ref": "R:%s.%s" % [r.id, t.id if String(t.id) != "" else rs.tpl], "tags": _pref(t.tags)})
			if rs.has("nodo"):
				var tg2: Array = []
				for x in rs.get("tags", []):
					tg2.append(String(x))
				out.append({"ref": String(rs.nodo), "tags": tg2})
	_rp.cache["t13_frags"] = out
	return out

static func _pref(tags: Dictionary) -> Array:
	var out: Array = []
	for p in tags:
		for v in tags[p]:
			out.append("%s:%s" % [p, v])
	return out

static func _text_tags(tx: String, ctx: Dictionary) -> Array:
	var out: Array = []
	for t in Markup.parse(tx, ctx).tramos:
		out.append_array(_pref(t.tags))
	return out

# Etiquetas a: de las conclusiones C2–C13 (grupos con ${ch:x} expandido a todos los canales + tags_extra).
func _conc_tags() -> Array:
	var out: Array = []
	for cid in _rp.conclusions_meta().get("mandatory", []):
		var c: Dictionary = _rp.conclusion(cid)
		var raw: Array = c.get("tags_extra", []).duplicate()
		for g in c.get("groups", []):
			raw.append_array(g.get("tags", []))
		for t in raw:
			var s := String(t)
			if s.contains("${ch:"):
				var pre := s.substr(0, s.find("${ch:"))
				for code in CH_CODES:
					out.append("a:" + pre + code)
			else:
				out.append(s if s.contains(":") else "a:" + s)
	return out

func _route_refs() -> Array:
	var out: Array = []
	for cid in _rp.conclusions_meta().get("mandatory", []):
		var c: Dictionary = _rp.conclusion(cid)
		for r in c.get("routes", []):
			for f in r.get("frags", []):
				out.append(String(f.ref))
		for k in c.get("subroutes", {}):
			for f in c.subroutes[k].get("frags", []):
				out.append(String(f.ref))
	return out

func _egg_ids() -> Array:
	var out: Array = []
	for e in _rp.eggs():
		out.append(String(e.get("id", "")))
	return out

# ---------------- verificadores (devuelven violaciones) ----------------
func _bad_inventory() -> Array:
	var bad: Array = []
	var seen := {}
	for e in _rp.eggs():
		var id := String(e.get("id", ""))
		if seen.has(id):
			bad.append("%s duplicado" % id)
		seen[id] = true
		if String(e.get("name", "")) == "" or String(e.get("note", "")) == "":
			bad.append("%s sin nombre o sin nota" % id)
		var tr = e.get("trigger", {})
		if typeof(tr) != TYPE_DICTIONARY or tr.size() != 1 or not KINDS.has(String(tr.keys()[0])):
			bad.append("%s: disparador desconocido %s" % [id, str(tr)])
			continue
		var k := String(tr.keys()[0])
		if k == "clip_tag" and not String(tr.clip_tag).contains(":"):
			bad.append("%s: clip_tag sin prefijo" % id)
		if k == "pair_tags" and (typeof(tr.pair_tags) != TYPE_ARRAY or tr.pair_tags.size() < 2):
			bad.append("%s: pair_tags necesita dos etiquetas" % id)
		if k == "pairs_over" and (typeof(tr.pairs_over) != TYPE_ARRAY or tr.pairs_over.size() < 2):
			bad.append("%s: pairs_over necesita ≥2 fragmentos" % id)
	return bad

func _bad_notes() -> Array:
	var bad: Array = []
	var ctx: Dictionary = _rp.markup_ctx()
	for e in _rp.eggs():
		var note := String(e.get("note", ""))
		var pt := Markup.parse(note, ctx)
		if not pt.tramos.is_empty():
			bad.append("%s: la nota tiene tramos (sería una fuente)" % e.id)
		for er in Markup.lint(note, ctx):
			bad.append("%s: %s" % [e.id, er])
	return bad

func _bad_x_fragments() -> Array:
	var bad: Array = []
	var eggs := _egg_ids()
	var ctags := _conc_tags()
	for f in _frags():
		var xs: Array = []
		for t in f.tags:
			if String(t).begins_with("x:"):
				xs.append(String(t).substr(2))
		if xs.is_empty():
			continue
		for x in xs:
			if not eggs.has(x):
				bad.append("%s: x:%s no es un huevo" % [f.ref, x])
		for t in f.tags:
			if ctags.has(String(t)):
				bad.append("%s: huevo con etiqueta %s de C2–C13" % [f.ref, t])
	return bad

func _bad_route_links() -> Array:
	var bad: Array = []
	var routes := _route_refs()
	for e in _rp.eggs():
		for ref in e.get("trigger", {}).get("pairs_over", []):
			if routes.has(String(ref)):
				bad.append("%s: pairs_over usa el fragmento de ruta %s" % [e.id, ref])
	var xfr := {}
	for f in _frags():
		for t in f.tags:
			if String(t).begins_with("x:"):
				xfr[f.ref] = true
	for ref in routes:
		if xfr.has(ref):
			bad.append("ruta de C2–C13 con un fragmento de huevo: %s" % ref)
	return bad

func _bad_reactions() -> Array:
	var bad: Array = []
	for r in _rp.reactions():
		var d: Dictionary = r.get("disparador", {})
		var ev = d.get("evento", "")
		var evs: Array = ev if typeof(ev) == TYPE_ARRAY else [ev]
		if evs.has("egg") or JSON.stringify(d.get("match", {})).contains("EE"):
			bad.append("%s: se dispara por un huevo" % r.id)
	return bad

# {missing:[…]} fuentes que todavía no existen en el contenido.
func _missing_sources() -> Array:
	var all_tags := {}
	var refs := {}
	for f in _frags():
		refs[f.ref] = true
		for t in f.tags:
			all_tags[String(t)] = true
	var missing: Array = []
	for e in _rp.eggs():
		var tr: Dictionary = e.get("trigger", {})
		if tr.has("clip_tag") and String(tr.clip_tag).begins_with("x:") and not all_tags.has(String(tr.clip_tag)):
			missing.append("%s (%s)" % [e.id, tr.clip_tag])
		for t in tr.get("pair_tags", []):
			var s := String(t)
			if s.begins_with("x:") and not all_tags.has(s):
				missing.append("%s (%s)" % [e.id, s])
			if s.begins_with("e:") and _rp.entity(s.substr(2)).is_empty():
				missing.append("%s (entidad %s)" % [e.id, s])
		for ref in tr.get("pairs_over", []):
			if not refs.has(String(ref)):
				missing.append("%s (%s)" % [e.id, ref])
	return missing

# ---------------- tests ----------------
func test_eggs_inventory() -> void:
	eq(_bad_inventory(), [], "huevos y disparadores")
	var ids := _egg_ids()
	ids.sort()
	var want: Array = []
	for i in range(1, 14):
		want.append("EE%02d" % i)
	eq(ids, want, "los 13 huevos de GDD §13")

func test_eggs_notes_are_not_sources() -> void:
	eq(_bad_notes(), [], "notas de Marginalia sin tramos ni errores")

func test_egg_fragments_without_conclusion_tags() -> void:
	eq(_bad_x_fragments(), [], "fragmentos de huevo sin etiquetas de C2–C13")

func test_eggs_not_on_routes() -> void:
	eq(_bad_route_links(), [], "huevos fuera de las rutas")

func test_no_reaction_triggered_by_eggs() -> void:
	eq(_bad_reactions(), [], "ninguna reacción por un huevo")

func test_egg_sources_exist() -> void:
	var m := _missing_sources()
	if not m.is_empty():
		pending_content("fuentes de huevos sin contenido todavía: %s" % ", ".join(PackedStringArray(m)))

func test_checks_detect_violations_on_fixture() -> void:
	var real = _rp
	_rp = fixture_repo("struct_bad")
	ok(_has_sub(_bad_inventory(), "EE03: disparador desconocido"), "disparador desconocido")
	ok(_has_sub(_bad_notes(), "EE01: la nota tiene tramos"), "nota con tramo")
	var x := _bad_x_fragments()
	ok(_has_sub(x, "D91#raro: huevo con etiqueta a:sin_raspadura"), "huevo con etiqueta de conclusión: %s" % str(x))
	ok(_has_sub(x, "x:EE99 no es un huevo"), "x: sin huevo")
	var rl := _bad_route_links()
	ok(_has_sub(rl, "EE02: pairs_over usa el fragmento de ruta D91#raro"), "pairs_over sobre una ruta: %s" % str(rl))
	ok(_has_sub(rl, "ruta de C2–C13 con un fragmento de huevo: D91#raro"), "ruta con huevo")
	ok(_has_sub(_bad_reactions(), "HX1"), "reacción por un huevo")
	_rp = real

static func _has_sub(arr: Array, sub: String) -> bool:
	for v in arr:
		if String(v).contains(sub):
			return true
	return false
