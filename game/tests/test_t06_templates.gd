# T06 (W2-DED, GDD§8.4, R7): plantillas genéricas y listas cerradas comunes.
# - Rótulos «Campo: ___»: el artículo va dentro del rótulo (nada entre «:» y el blanco; el rótulo no termina en artículo),
#   sin primera persona ni presuposiciones («Me usa como», «Lo que hago llega a»).
# - T1–T9 con el nombre, las líneas, los campos y la opcionalidad de GDD§8.4 (ids de lists._templates_nota).
# - Cada campo acepta tipos de entidad (kinds ⊆ §4.5) o UNA lista cerrada (verbos, relaciones, medios, estados), las
#   mismas listas para todas las conclusiones: ninguna conclusión define listas propias; {"list": X} coincide con la
#   lista del campo; los valores de campos de lista están en esa lista; los de campos de entidad son entidades del kind.
# - Listas de GDD§8.2 completas: 16 verbos, 6 relaciones, 5 medios (canales distintos), 3 estados.
extends "res://tests/test_base.gd"

const ENT_KINDS := ["persona", "lugar", "documento", "objeto", "fecha", "concepto", "suceso"]
const LISTS := ["verbos", "relaciones", "medios", "estados"]
const ARTICLES := ["el", "la", "los", "las", "un", "una", "unos", "unas", "del", "al", "lo"]
const VERBOS := ["ceder", "vender", "comprar", "matar", "disparar", "ocultar", "suprimir", "vigilar", "pagar", "escribir",
	"dictar", "volver", "preparar", "separarse_de", "seguir", "hallar"]
const RELACIONES := ["lee_a", "paga_a", "vigila_a", "obedece_a", "usa_a", "busca_a"]
const ESTADOS := ["vivo", "muerto", "desconocido"]
const MEDIOS := ["sala_lectura", "consultorio", "221b", "la_calle", "columna"]
const EXPECTED := {
	"T1": {"name": "Errata", "lines": [["fuente_a", "dice_a"], ["fuente_b", "dice_b"]], "opt": [false, false]},
	"T2": {"name": "Omisión", "lines": [["fuente", "calla"], ["consta_en"]], "opt": [false, false]},
	"T3": {"name": "Identidad", "lines": [["persona"], ["es"]], "opt": [false, false]},
	"T4": {"name": "Autoría", "lines": [["documento"], ["redacto"]], "opt": [false, false]},
	"T5": {"name": "Hecho", "lines": [["persona", "hizo", "que"], ["a"], ["con"], ["donde"], ["cuando"]], "opt": [false, true, true, true, true]},
	"T6": {"name": "Relación", "lines": [["persona", "relacion", "a_quien", "por_medio"], ["y_de"]], "opt": [false, true]},
	"T7": {"name": "Estado", "lines": [["persona"], ["estado"]], "opt": [false, false]},
	"T8": {"name": "Paradero", "lines": [["persona"], ["lugar"], ["dia"]], "opt": [false, false, false]},
	"T9": {"name": "Propósito", "lines": [["persona"], ["usa_a", "como"], ["para", "a_quien"]], "opt": [false, false, false]},
}
const LIST_FIELDS := {"T5.hizo": "verbos", "T6.relacion": "relaciones", "T6.por_medio": "medios", "T6.y_de": "medios",
	"T7.estado": "estados", "T9.para": "verbos"}

func test_real_lists_and_conclusions():
	var r = repo()
	if r.lists().is_empty():
		pending_content("data/lists.json")
		return
	for v in check(r.lists(), r.conclusions(), func(id): return String(r.entity(id).get("kind", ""))):
		fail(v)

func test_fixture_ded():
	var r = fixture_repo("ded")
	eq(check(r.lists(), r.conclusions(), func(id): return String(r.entity(id).get("kind", ""))), [])

func test_detects_bad_templates():
	var r = fixture_repo("ded")
	var lists: Dictionary = r.lists().duplicate(true)
	lists.templates.T3.lines[0].fields[0].label = "Persona: el ___"
	lists.templates.T9.lines[1].fields[0].label = "Me usa a: ___"
	lists.templates.T4.lines[1].fields[0].label = "Lo redactó el: ___"
	lists.templates.T2.lines[0].fields[0].accept = {"kinds": ["documento"], "list": "verbos"}
	lists.templates.T8.lines[2].fields[0].accept = {"kinds": ["dia_de_la_semana"]}
	lists.templates.T7.lines.append({"fields": [{"id": "extra", "label": "Extra: ___", "accept": {"kinds": ["persona"]}}]})
	lists.verbos.erase("hallar")
	lists.medios[1].ch = "kbm"
	var v := check(lists, r.conclusions(), func(id): return String(r.entity(id).get("kind", "")))
	for needle in ["T3.persona", "T9.usa_a", "T4.redacto", "T2.fuente", "T8.dia", "T7: líneas", "verbos", "canales"]:
		ok(str(v).contains(needle), "detecta %s: %s" % [needle, str(v)])

func test_detects_private_lists_in_conclusions():
	var r = fixture_repo("ded")
	var concs: Array = r.conclusions().duplicate(true)
	for c in concs:
		if c.id == "C6":
			c.answers["relacion"] = ["ama_a"]
			c.answers["por_medio"] = {"list": "mis_medios"}
		if c.id == "C2":
			c.answers["calla"] = {"options": ["raspadura"]}
			c.answers["inventado"] = ["fina"]
		if c.id == "C10":
			c.answers["a_quien"] = ["cebo"]
	var v := check(r.lists(), concs, func(id): return String(r.entity(id).get("kind", "")))
	for needle in ["C6.relacion", "C6.por_medio", "C2.calla", "C2.inventado", "C10.a_quien"]:
		ok(str(v).contains(needle), "detecta %s: %s" % [needle, str(v)])

# ---------------- verificador ----------------
static var _rx_label: RegEx = null
static var _rx_first: RegEx = null

static func _rx(which: String) -> RegEx:
	if _rx_label == null:
		_rx_label = RegEx.new()
		_rx_label.compile("^[^_:\\s][^_:]*: ___$")
		_rx_first = RegEx.new()
		_rx_first.compile("(?i)(^|[^\\pL])(me|mi|mis|yo|nos|nuestro|nuestra|nuestros|nuestras|conmigo|lo que hago)([^\\pL]|$)")
	return _rx_label if which == "label" else _rx_first

static func check(lists: Dictionary, conclusions: Array, kind_of: Callable) -> Array:
	var out: Array = []
	var tpls = lists.get("templates", {})
	if typeof(tpls) != TYPE_DICTIONARY:
		return ["lists.templates ausente"]
	var field_accept := {}
	for tid in EXPECTED:
		var exp: Dictionary = EXPECTED[tid]
		var t = tpls.get(tid)
		if typeof(t) != TYPE_DICTIONARY:
			out.append("%s: falta la plantilla" % tid)
			continue
		if String(t.get("name", "")) != exp.name:
			out.append("%s: nombre «%s» (GDD§8.4: «%s»)" % [tid, t.get("name", ""), exp.name])
		var lines: Array = t.get("lines", [])
		if lines.size() != exp.lines.size():
			out.append("%s: líneas %d (GDD§8.4: %d)" % [tid, lines.size(), exp.lines.size()])
		for i in mini(lines.size(), exp.lines.size()):
			var ln: Dictionary = lines[i]
			if bool(ln.get("optional", false)) != exp.opt[i]:
				out.append("%s: línea %d optional=%s" % [tid, i, str(ln.get("optional", false))])
			var ids: Array = []
			for f in ln.get("fields", []):
				ids.append(String(f.get("id", "")))
			if ids != exp.lines[i]:
				out.append("%s: línea %d campos %s (esperado %s)" % [tid, i, str(ids), str(exp.lines[i])])
			for f in ln.get("fields", []):
				var fid := "%s.%s" % [tid, f.get("id", "")]
				_check_label(fid, String(f.get("label", "")), out)
				var acc = f.get("accept", {})
				field_accept[fid] = acc
				_check_accept(fid, acc, lists, out)
	for k in tpls:
		if not EXPECTED.has(k):
			out.append("%s: plantilla fuera de GDD§8.4" % k)
	_check_lists(lists, out)
	for c in conclusions:
		_check_conclusion(c, tpls, lists, field_accept, kind_of, out)
	return out

static func _check_label(fid: String, label: String, out: Array) -> void:
	if _rx("label").search(label) == null:
		out.append("%s: rótulo «%s» no tiene la forma «Campo: ___»" % [fid, label])
		return
	var head := label.trim_suffix(": ___").strip_edges()
	var words := head.to_lower().replace(",", " ").split(" ", false)
	if not words.is_empty() and ARTICLES.has(words[words.size() - 1]):
		out.append("%s: rótulo «%s» termina en artículo (el artículo va dentro del rótulo, no junto al blanco)" % [fid, label])
	if _rx("first").search(label) != null:
		out.append("%s: rótulo «%s» presupone (primera persona)" % [fid, label])

static func _check_accept(fid: String, acc, lists: Dictionary, out: Array) -> void:
	if typeof(acc) != TYPE_DICTIONARY:
		out.append("%s: accept no es objeto" % fid)
		return
	var has_k: bool = acc.has("kinds")
	var has_l: bool = acc.has("list")
	if has_k == has_l:
		out.append("%s: accept debe tener kinds O list (uno solo)" % fid)
		return
	if has_l:
		var ln := String(acc.list)
		if not LISTS.has(ln) or typeof(lists.get(ln)) != TYPE_ARRAY:
			out.append("%s: lista «%s» no es una lista cerrada común" % [fid, ln])
		elif LIST_FIELDS.get(fid, "") != ln:
			out.append("%s: lista «%s» (GDD§8.4: %s)" % [fid, ln, LIST_FIELDS.get(fid, "entidades")])
	else:
		if LIST_FIELDS.has(fid):
			out.append("%s: debe aceptar la lista %s" % [fid, LIST_FIELDS[fid]])
		if typeof(acc.kinds) != TYPE_ARRAY or acc.kinds.is_empty():
			out.append("%s: kinds vacío" % fid)
		else:
			for k in acc.kinds:
				if not ENT_KINDS.has(String(k)):
					out.append("%s: kind «%s» desconocido" % [fid, k])

static func _ids(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for x in arr:
		out.append(String(x.get("id", "")) if typeof(x) == TYPE_DICTIONARY else String(x))
	return out

static func _same_set(a: Array, b: Array) -> bool:
	var x := a.duplicate()
	var y := b.duplicate()
	x.sort()
	y.sort()
	return x == y

static func _check_lists(lists: Dictionary, out: Array) -> void:
	for pair in [["verbos", VERBOS], ["relaciones", RELACIONES], ["estados", ESTADOS], ["medios", MEDIOS]]:
		if not _same_set(_ids(lists.get(pair[0])), pair[1]):
			out.append("lists.%s = %s (GDD§8.2: %s)" % [pair[0], str(_ids(lists.get(pair[0]))), str(pair[1])])
	var chs := {}
	for m in lists.get("medios", []):
		if typeof(m) == TYPE_DICTIONARY:
			chs[String(m.get("ch", ""))] = true
	if chs.size() != lists.get("medios", []).size() or chs.has(""):
		out.append("lists.medios: canales repetidos o vacíos %s" % str(chs.keys()))

static func _check_conclusion(c: Dictionary, tpls: Dictionary, lists: Dictionary, field_accept: Dictionary, kind_of: Callable, out: Array) -> void:
	var cid := String(c.get("id", "?"))
	var tid := String(c.get("template", ""))
	if not tpls.has(tid):
		out.append("%s: plantilla «%s» inexistente" % [cid, tid])
		return
	var ans = c.get("answers", {})
	if typeof(ans) != TYPE_DICTIONARY:
		out.append("%s: answers no es objeto" % cid)
		return
	var ks: Array = ans.keys()
	ks.sort()
	for f in ks:
		if String(f).begins_with("_"):
			continue
		var fid := "%s.%s" % [tid, f]
		var where := "%s.%s" % [cid, f]
		if not field_accept.has(fid):
			out.append("%s: el campo no existe en %s" % [where, tid])
			continue
		var acc: Dictionary = field_accept[fid]
		var a = ans[f]
		if typeof(a) == TYPE_DICTIONARY:
			if a.keys() != ["list"]:
				out.append("%s: respuesta con forma propia %s (sólo valores o {\"list\": X})" % [where, str(a)])
			elif String(a.list) != String(acc.get("list", "")):
				out.append("%s: lista «%s» distinta de la del campo («%s»)" % [where, a.list, acc.get("list", "")])
			continue
		if typeof(a) != TYPE_ARRAY:
			out.append("%s: respuesta no es lista" % where)
			continue
		for v in a:
			var s := String(v)
			if acc.has("list"):
				if not _ids(lists.get(String(acc.list))).has(s) and not _medio_entity(lists, String(acc.list), s):
					out.append("%s: «%s» no está en la lista común %s" % [where, s, acc.list])
			else:
				var ent := s.substr(7) if s.begins_with("@alias:") else s
				var k := String(kind_of.call(ent))
				if k == "":
					out.append("%s: «%s» no es una entidad" % [where, s])
				elif not acc.get("kinds", []).has(k):
					out.append("%s: «%s» es %s; el campo acepta %s" % [where, s, k, str(acc.get("kinds", []))])

static func _medio_entity(lists: Dictionary, ln: String, v: String) -> bool:
	if ln != "medios":
		return false
	for m in lists.get("medios", []):
		if typeof(m) == TYPE_DICTIONARY and m.get("entities", []).has(v):
			return true
	return false
