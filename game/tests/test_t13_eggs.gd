# T13 — easter eggs y curiosidades (GDD §13, §15.5; GDD_v3 §3.6; ARCHITECTURE §4.16, §9.2). Dueño: CORE-EXPEDIENTE.
#  - huevos EE01…EE14 y curiosidades EE-INC01/02/06/09, cada uno con nota y un disparador que WorldModel sabe leer
#    (clip_tag, clips_tag, clips_all, clips_over, all) o «final» (EE12, la ficha del final); sin pares (v3);
#  - las notas de Marginalia no tienen tramos ni etiquetas (no son fuentes);
#  - todo fragmento con x:EE.. existe como huevo y NO lleva etiquetas de grupo de ninguna pregunta del expediente;
#    las etiquetas de los disparadores (clips_tag, clip_tag a:) tampoco son de preguntas;
#  - ningún disparador clips_over usa un fragmento de ruta del expediente, y ninguna ruta usa un fragmento x:;
#  - ninguna reacción se dispara por un huevo (no agregan fragmentos a ninguna ruta);
#  - cada huevo tiene su fragmento en el contenido (faltantes → pending_content).
# Negativos sobre tests/fixtures/struct_bad.
extends "res://tests/test_base.gd"

const Markup = preload("res://core/text/markup.gd")

const TIMEOUT_S := 60.0
const KINDS := ["clip_tag", "clips_tag", "clips_all", "clips_over", "all", "final"]
const WANT := ["EE-INC01", "EE-INC02", "EE-INC06", "EE-INC09", "EE01", "EE02", "EE03", "EE04", "EE05", "EE06", "EE07", "EE08",
	"EE09", "EE10", "EE11", "EE12", "EE13", "EE14"]
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

# Etiquetas de grupo de todas las variantes de todas las preguntas del expediente (sin prefijo = a:).
func _conc_tags() -> Array:
	var out: Array = []
	for q in _rp.questions():
		for v in q.get("variantes", []):
			for g in v.get("grupos", []):
				for t in g.get("tags", []):
					var s := String(t)
					out.append(s if s.contains(":") else "a:" + s)
	return out

func _route_refs() -> Array:
	var out: Array = []
	for q in _rp.questions():
		for v in q.get("variantes", []):
			for r in v.get("rutas", []):
				for f in r.get("frags", []):
					out.append(String(f.ref))
	return out

# Disparadores hoja (expande «all»).
static func _leaves(tr) -> Array:
	if typeof(tr) != TYPE_DICTIONARY:
		return []
	if tr.has("all") and typeof(tr.all) == TYPE_ARRAY:
		var out: Array = []
		for sub in tr.all:
			out.append_array(_leaves(sub))
		return out
	return [tr]

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
		var main := ""
		if typeof(tr) == TYPE_DICTIONARY:
			for k in KINDS:
				if tr.has(k):
					main = k
		if main == "":
			bad.append("%s: disparador desconocido %s" % [id, str(tr)])
			continue
		if main == "all" and (typeof(tr.all) != TYPE_ARRAY or tr.all.size() < 2):
			bad.append("%s: all necesita ≥2 disparadores" % id)
		for lf in _leaves(tr):
			var k := ""
			for kk in KINDS:
				if lf.has(kk):
					k = kk
			if k == "" or k == "all":
				bad.append("%s: disparador desconocido %s" % [id, str(lf)])
			elif k == "clip_tag" and not String(lf.clip_tag).contains(":"):
				bad.append("%s: clip_tag sin prefijo" % id)
			elif k == "clips_tag" and (not String(lf.clips_tag).contains(":") or int(lf.get("n", 0)) < 2):
				bad.append("%s: clips_tag necesita prefijo y n ≥ 2" % id)
			elif k == "clips_all" and (typeof(lf.clips_all) != TYPE_ARRAY or lf.clips_all.size() < 2):
				bad.append("%s: clips_all necesita dos etiquetas" % id)
			elif k == "clips_over" and (typeof(lf.clips_over) != TYPE_ARRAY or lf.clips_over.is_empty()):
				bad.append("%s: clips_over necesita fragmentos" % id)
			for x in ["pairs_over", "pair_tags"]:
				if lf.has(x):
					bad.append("%s: %s no existe en v3 (sin pares)" % [id, x])
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
				bad.append("%s: huevo con etiqueta %s de una pregunta" % [f.ref, t])
	for e in _rp.eggs():
		for lf in _leaves(e.get("trigger", {})):
			var ts: Array = [lf.get("clip_tag", ""), lf.get("clips_tag", "")]
			ts.append_array(lf.get("clips_all", []))
			for t in ts:
				if String(t).begins_with("a:") and ctags.has(String(t)):
					bad.append("%s: el disparador usa la etiqueta %s de una pregunta" % [e.id, t])
	return bad

func _bad_route_links() -> Array:
	var bad: Array = []
	var routes := _route_refs()
	for e in _rp.eggs():
		for lf in _leaves(e.get("trigger", {})):
			for ref in lf.get("clips_over", []):
				if routes.has(String(ref)):
					bad.append("%s: clips_over usa el fragmento de ruta %s" % [e.id, ref])
	var xfr := {}
	for f in _frags():
		for t in f.tags:
			if String(t).begins_with("x:"):
				xfr[f.ref] = true
	for ref in routes:
		if xfr.has(ref):
			bad.append("ruta del expediente con un fragmento de huevo: %s" % ref)
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
		for tr in _leaves(e.get("trigger", {})):
			var tags: Array = []
			if tr.has("clip_tag"):
				tags.append(String(tr.clip_tag))
			if tr.has("clips_tag"):
				tags.append(String(tr.clips_tag))
			tags.append_array(tr.get("clips_all", []))
			for t in tags:
				var s := String(t)
				if (s.begins_with("x:") or s.begins_with("a:")) and not all_tags.has(s):
					missing.append("%s (%s)" % [e.id, s])
				if s.begins_with("e:") and _rp.entity(s.substr(2)).is_empty():
					missing.append("%s (entidad %s)" % [e.id, s])
			for ref in tr.get("clips_over", []):
				if not refs.has(String(ref)):
					missing.append("%s (%s)" % [e.id, ref])
	return missing

# ---------------- tests ----------------
func test_eggs_inventory() -> void:
	eq(_bad_inventory(), [], "huevos y disparadores")
	var ids := _egg_ids()
	ids.sort()
	eq(ids, WANT, "los 14 huevos (GDD §13 + EE14) y las 4 curiosidades INC (GDD_v3 §3.6)")

func test_eggs_notes_are_not_sources() -> void:
	eq(_bad_notes(), [], "notas de Marginalia sin tramos ni errores")

func test_egg_fragments_without_conclusion_tags() -> void:
	eq(_bad_x_fragments(), [], "fragmentos de huevo sin etiquetas de preguntas")

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
	ok(_has_sub(x, "D91#raro: huevo con etiqueta a:sin_raspadura"), "huevo con etiqueta de pregunta: %s" % str(x))
	ok(_has_sub(x, "x:EE99 no es un huevo"), "x: sin huevo")
	var rl := _bad_route_links()
	ok(_has_sub(rl, "EE02: clips_over usa el fragmento de ruta D91#raro"), "clips_over sobre una ruta: %s" % str(rl))
	ok(_has_sub(rl, "ruta del expediente con un fragmento de huevo: D91#raro"), "ruta con huevo")
	ok(_has_sub(_bad_reactions(), "HX1"), "reacción por un huevo")
	_rp = real

static func _has_sub(arr: Array, sub: String) -> bool:
	for v in arr:
		if String(v).contains(sub):
			return true
	return false
