# core/scenes/deps.gd — dependencias externas y utilidades comunes de W2-SCENES. Dueño: W2-SCENES.
# Dependencias (dirección §1: scenes -> {deduction, react, text, data, util}; nunca sim):
#   Index, Clipper, Ledger, Validator (W2-DED) · Director, Effects, MoranAgent (W2-REACT).
#   Acceso por index()/clipper()/ledger()/validator()/director()/effects()/moran() (perezoso). Los tests asignan las
#   `static var` (Index, Clipper, …) a dobles (tests/fixtures/scenes/fakes.gd) y llaman reset().
# Estado propio: st.scenes (§3.3). ensure(st) crea claves faltantes; SÓLO desde init_state/act_* (las consultas no mutan).
# Lecturas de estado ajeno sin función del dueño en el contrato §3.8 (sólo lectura, documentadas):
#   st.ded.entries[id] (forma §5.2), st.ded.pairs[id] (forma §5.1), st.ded.sealed (cid -> entry), st.world.visit
#   ({id, place, area, chars:[id|{id}], scene?, origin?}, igual que Cond.char_present), st.clock, st.events, st.flags.
extends RefCounted

const Markup = preload("res://core/text/markup.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const P_INDEX := "res://core/deduction/index.gd"
const P_CLIPPER := "res://core/deduction/clipper.gd"
const P_LEDGER := "res://core/deduction/ledger.gd"
const P_VALIDATOR := "res://core/deduction/validator.gd"
const P_DIRECTOR := "res://core/react/director.gd"
const P_EFFECTS := "res://core/react/effects.gd"
const P_MORAN := "res://core/react/moran_agent.gd"

# Carga perezosa (load al primer uso, cacheado): los tests que instalan dobles nunca cargan los módulos reales, y un
# error de compilación ajeno (otro WP a medio hacer) no rompe la carga de core/scenes.
static var Index = null
static var Clipper = null
static var Ledger = null
static var Validator = null
static var Director = null
static var Effects = null
static var MoranAgent = null

static func index():
	if Index == null:
		Index = load(P_INDEX)
	return Index

static func clipper():
	if Clipper == null:
		Clipper = load(P_CLIPPER)
	return Clipper

static func ledger():
	if Ledger == null:
		Ledger = load(P_LEDGER)
	return Ledger

static func validator():
	if Validator == null:
		Validator = load(P_VALIDATOR)
	return Validator

static func director():
	if Director == null:
		Director = load(P_DIRECTOR)
	return Director

static func effects():
	if Effects == null:
		Effects = load(P_EFFECTS)
	return Effects

static func moran():
	if MoranAgent == null:
		MoranAgent = load(P_MORAN)
	return MoranAgent

static func reset() -> void:
	Index = null
	Clipper = null
	Ledger = null
	Validator = null
	Director = null
	Effects = null
	MoranAgent = null

# ---------------- estado st.scenes ----------------
static func defaults() -> Dictionary:
	return {
		"dialogue": {"asked": {}, "introduced": {}, "tasks": {}},
		"lines": {},
		"confront": {"started": false, "step": 0, "hits": 0, "errors": 0, "done": false, "answers": [], "statement": "", "estado": ""},
		"mycroft": {"presented": 0, "errors": 0, "ok": false, "gone": false},
		"reports": {},
		"final": {},
		"ending": {},
		"ads": [],
		"mail": [],
	}

# Crea lo que falte (también sub-claves de dialogue/confront/mycroft). Devuelve st.scenes.
static func ensure(st) -> Dictionary:
	if typeof(st.scenes) != TYPE_DICTIONARY:
		st.scenes = {}
	var d := defaults()
	for k in d:
		if not st.scenes.has(k):
			st.scenes[k] = d[k]
		elif typeof(d[k]) == TYPE_DICTIONARY and typeof(st.scenes[k]) == TYPE_DICTIONARY:
			for kk in d[k]:
				if not st.scenes[k].has(kk):
					st.scenes[k][kk] = d[k][kk]
	return st.scenes

# Lectura sin mutar (consultas).
static func sc(st, key: String) -> Variant:
	var s = st.scenes if st != null else {}
	if typeof(s) == TYPE_DICTIONARY and s.has(key):
		return s[key]
	return defaults()[key]

# ---------------- reloj y visita ----------------
static func clock(st) -> Dictionary:
	return st.clock if typeof(st.clock) == TYPE_DICTIONARY else {}

static func day(st) -> int:
	return int(clock(st).get("day", 0))

static func slot(st) -> String:
	var c := clock(st)
	if String(c.get("phase", "")) == "night":
		return "night"
	var s := String(c.get("slot", ""))
	return s if TimeKey.ORD.has(s) else "dawn"

static func phase(st) -> String:
	return String(clock(st).get("phase", ""))

static func now_tk(st) -> int:
	return TimeKey.tk(day(st), slot(st))

static func visit(st) -> Dictionary:
	var w = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
	var v = w.get("visit", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}

static func visit_key(st) -> String:
	var v := visit(st)
	var id := String(v.get("id", ""))
	if id != "":
		return id
	return "S.%s.%d.%s" % [String(v.get("place", "L1")), day(st), slot(st)]

# Origen de lo dicho en la visita actual (§5.1 paso 5): visit.origin > escena de la visita > id de la visita.
static func origin(st, repo) -> String:
	var v := visit(st)
	if String(v.get("origin", "")) != "":
		return String(v.origin)
	var scn := String(v.get("scene", ""))
	if scn != "":
		var o := String(repo.scene(scn).get("origin", ""))
		return o if o != "" else "S." + scn
	return visit_key(st)

static func chars_present(st) -> Array:
	var out: Array = []
	for c in visit(st).get("chars", []):
		out.append(String(c.get("id", "")) if typeof(c) == TYPE_DICTIONARY else String(c))
	return out

static func flags(st) -> Dictionary:
	return st.flags if typeof(st.flags) == TYPE_DICTIONARY else {}

# ---------------- deducción (lecturas) ----------------
static func entry(st, id: String) -> Dictionary:
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var e = ded.get("entries", {}).get(id, {})
	return e if typeof(e) == TYPE_DICTIONARY else {}

static func pair(st, id: String) -> Dictionary:
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var p = ded.get("pairs", {}).get(id, {})
	return p if typeof(p) == TYPE_DICTIONARY else {}

static func sealed(st) -> Dictionary:
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var s = ded.get("sealed", {})
	return s if typeof(s) == TYPE_DICTIONARY else {}

# sealed[cid] puede ser el id del asiento o el asiento entero (el contrato no lo fija): devuelve el id.
static func sealed_entry_id(v) -> String:
	if typeof(v) == TYPE_DICTIONARY:
		return String(v.get("id", ""))
	return String(v) if v != null else ""

# {campo: valor} de todas las líneas (los ids de campo son únicos por plantilla).
static func entry_values(e: Dictionary) -> Dictionary:
	var out := {}
	for ln in e.get("lines", []):
		if typeof(ln) != TYPE_DICTIONARY:
			continue
		var f = ln.get("fields", {})
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var ks: Array = f.keys()
		ks.sort()
		for k in ks:
			if String(f[k]) != "":
				out[k] = String(f[k])
	return out

# Ids de entidades de una lista [id | {id,label}].
static func ent_ids(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for e in arr:
		var id := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
		if id != "" and not out.has(id):
			out.append(id)
	return out

static func ent_label(arr, id: String) -> String:
	if typeof(arr) == TYPE_ARRAY:
		for e in arr:
			if typeof(e) == TYPE_DICTIONARY and String(e.get("id", "")) == id:
				return String(e.get("label", ""))
	return ""

# Valores de etiquetas con prefijo ("a:x" -> "x"); sin prefijo cuenta como a:.
static func tag_values(tags, prefix := "a") -> Array:
	var out: Array = []
	if typeof(tags) == TYPE_DICTIONARY:   # forma ParsedText {a:[..], ..}
		for v in tags.get(prefix, []):
			out.append(String(v))
		return out
	if typeof(tags) != TYPE_ARRAY:
		return out
	for t in tags:
		var s := String(t)
		var k := s.find(":")
		if k < 0:
			if prefix == "a":
				out.append(s)
		elif s.substr(0, k) == prefix:
			out.append(s.substr(k + 1))
	return out

static func has_camden_tag(tags) -> bool:
	return tag_values(tags, "f").has("secreto_camden")

# Recortes únicos de un asiento (pares expandidos) por Ledger.entry_clips.
static func entry_clip_ids(st, entry_id: String) -> Array:
	var out: Array = []
	for c in ledger().entry_clips(st, entry_id):
		var id := String(c.get("id", "")) if typeof(c) == TYPE_DICTIONARY else String(c)
		if id != "" and not out.has(id):
			out.append(id)
	return out

# ¿El ítem {kind,id} lleva material secreto_camden (f: de algún recorte)?
static func item_camden(st, repo, item: Dictionary) -> bool:
	var camden: Array = repo.lists().get("camden_entities", [])
	var ids: Array = []
	if String(item.get("kind", "")) == "entry":
		ids = entry_clip_ids(st, String(item.get("id", "")))
	else:
		ids = [String(item.get("id", ""))]
	for cid in ids:
		var c: Dictionary = clipper().get_clip(st, cid)
		if has_camden_tag(c.get("tags", [])):
			return true
	return false

# Etiquetas internas de un ítem (confrontación, HB12): recorte -> get_clip.tags; asiento -> Validator.entry_tags.
static func item_tags(st, item: Dictionary) -> Array:
	if String(item.get("kind", "")) == "entry":
		return validator().entry_tags(st, String(item.get("id", "")))
	var c: Dictionary = clipper().get_clip(st, String(item.get("id", "")))
	var t = c.get("tags", [])
	return t if typeof(t) == TYPE_ARRAY else []

static func item_exists(st, item: Dictionary) -> bool:
	var id := String(item.get("id", ""))
	if id == "":
		return false
	match String(item.get("kind", "")):
		"clip":
			return not clipper().get_clip(st, id).is_empty() or not clipper().visible(st, id).is_empty()
		"entry":
			return not entry(st, id).is_empty()
	return false

# Registro de una línea dicha por uid: st.scenes.lines (Dialogue) o st.world.lines (WorldModel de W2-SIM).
static func line_record(st, uid: String) -> Dictionary:
	var own = sc(st, "lines").get(uid)
	if typeof(own) == TYPE_DICTIONARY:
		return own
	var w = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
	var wl = w.get("lines", {})
	if typeof(wl) == TYPE_DICTIONARY and typeof(wl.get(uid)) == TYPE_DICTIONARY:
		return wl[uid]
	return {}

# ---------------- texto ----------------
# ui_text con fallback: si la clave no existe devuelve def (rellenado).
static func txt(repo, key: String, vars := {}, def := "") -> String:
	var t: Dictionary = repo.texts() if repo.has_method("texts") else {}
	var src := String(t.get(key, def))
	return fill(repo, src, vars)

static func has_txt(repo, key: String) -> bool:
	return repo.has_method("texts") and repo.texts().has(key)

# Markup.fill + lists.contracciones (["de el ", "del "], ["..", "."], …) SÓLO en las junturas plantilla/valor (con
# borde de palabra a la izquierda): «A propósito de ${fuente}» + «el Journal» -> «del Journal», pero «Se toca el
# crespón» queda intacto. Placeholders sin valor quedan como están.
static func fill(repo, tpl: String, vars: Dictionary) -> String:
	if tpl.find("${") < 0:
		return tpl
	var out := ""
	var joints: Array = []
	var i := 0
	var n := tpl.length()
	while i < n:
		var k := tpl.find("${", i)
		var e := tpl.find("}", k + 2) if k >= 0 else -1
		if k < 0 or e < 0:
			out += tpl.substr(i)
			break
		out += tpl.substr(i, k - i)
		var name := tpl.substr(k + 2, e - k - 2)
		if vars.has(name):
			joints.append(out.length())
			out += Markup.fill("${v}", {"v": vars[name]})
			joints.append(out.length())
		else:
			out += tpl.substr(k, e - k + 1)
		i = e + 1
	return _contract_at(repo, out, joints)

static func _contract_at(repo, s: String, joints: Array) -> String:
	var out := s
	for pr in repo.lists().get("contracciones", []):
		if typeof(pr) != TYPE_ARRAY or pr.size() != 2:
			continue
		var a := String(pr[0])
		var b := String(pr[1])
		var from := 0
		while true:
			var m := out.find(a, from)
			if m < 0:
				break
			var straddles := false
			for j in joints:
				if m < int(j) and int(j) < m + a.length():
					straddles = true
			var bound := m == 0 or not Markup.is_word_char(out[m - 1]) or a[0] == "."
			if straddles and bound:
				out = out.substr(0, m) + b + out.substr(m + a.length())
				var shift := b.length() - a.length()
				for q in joints.size():
					if int(joints[q]) > m:
						joints[q] = int(joints[q]) + shift
				from = m + b.length()
			else:
				from = m + 1
	return out


static func ent_name(repo, id: String) -> String:
	var e: Dictionary = repo.entity(id)
	return String(e.get("name", id)) if not e.is_empty() else id

static func cap_first(s: String) -> String:
	if s == "":
		return s
	var i := 0
	while i < s.length() and Markup.OPENERS.contains(s[i]):
		i += 1
	if i >= s.length():
		return s
	return s.substr(0, i) + s[i].to_upper() + s.substr(i + 1)

# "2s. 6d." / "1s." / "6d." (§4.2).
static func money(d: int) -> String:
	var s := int(d / 12)
	var p := d % 12
	if s > 0 and p > 0:
		return "%ds. %dd." % [s, p]
	if s > 0:
		return "%ds." % s
	return "%dd." % p

static func day_row(repo, d: int) -> Dictionary:
	for r in repo.schedule().get("days", []):
		if int(r.get("day", -1)) == d:
			return r
	return {}

# Nombre del día de la semana desde ui_text scenes.wd.<abrev normalizada>.
static func weekday_name(repo, d: int) -> String:
	var wd := String(day_row(repo, d).get("weekday", "")).to_lower().replace("é", "e").replace("á", "a")
	return txt(repo, "scenes.wd." + wd, {}, wd)

# Une piezas: "a", "a y b", "a, b y c".
static func join_and(repo, parts: Array) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return String(parts[0])
	var y := txt(repo, "scenes.y", {}, " y ")
	var head := PackedStringArray()
	for i in parts.size() - 1:
		head.append(String(parts[i]))
	return ", ".join(head) + y + String(parts[-1])

# Resumen legible de un asiento: «Persona: X · Hizo: matar · …» con los rótulos de la plantilla.
static func entry_summary(repo, e: Dictionary) -> String:
	var tpl: Dictionary = repo.template(String(e.get("template", "")))
	var vals := entry_values(e)
	var parts := PackedStringArray()
	for ln in tpl.get("lines", []):
		for f in ln.get("fields", []):
			var v := String(vals.get(f.get("id", ""), ""))
			if v == "":
				continue
			parts.append(String(f.get("label", "")).replace("___", value_label(repo, f, v)))
	return " · ".join(parts)

# Etiqueta de un valor de campo: entidad -> name; lista cerrada -> label (medios) o el id con espacios.
static func value_label(repo, field: Dictionary, v: String) -> String:
	var lst := String(field.get("accept", {}).get("list", ""))
	if lst != "":
		for it in repo.lists().get(lst, []):
			if typeof(it) == TYPE_DICTIONARY and String(it.get("id", "")) == v:
				return String(it.get("label", v))
		if not repo.entity(v).is_empty():
			return ent_name(repo, v)
		return v.replace("_", " ")
	return ent_name(repo, v)
