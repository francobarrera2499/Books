# core/react/moran_agent.gd — Moran, el otro lector (GDD§7.3, §9.7; ARCHITECTURE §5.4). Dueño: W2-REACT.
# Ve: los informes (lo que cada elemento DICE: cats calculadas al componer el informe con report_cats), lo que ve Parker
# en Baker Street (go a L3/L8), la columna (entregas de voz B en la columna: evento interno «reaccion») y, desde M11,
# lo que ve su hombre. Nunca st.ded (salvo report_cats/report_item, que leen los elementos del propio informe).
# observe(st, repo, ev, opts) -> candidatas de reglas lado moran (motor genérico de ReactionDB.collect). Además,
# por cada informe escribe los flags que el registro §3.9 le asigna:
#   moran_credito (cat verdadero en informes 1–3) · moran_credito_perdido (falso_verificable, M9) ·
#   holmes_entregado (paradero_extranjero, regreso_jueves, baker_street o camden) · informes_vacios (+1 si vacío)
# st.react.moran = {reports:[{n, mode, cats, tk}], credit, lost, following, delivered_holmes, next_lines:[]}
# report_cats(st, repo, item): asiento → por VALORES (Validator.values_match contra entry_conclusions, aunque el
#   fundamento sea falso; entry_template_values); recorte → por etiquetas c:, visible_cats del doc, clase del
#   ejemplar (P → original_p) y voz del documento runtime de origen (clip_voice). Nunca por a: ocultas.
# Extensión: report_item(st, repo, item) -> {kind, id, cats, values, copies, cls} (lo que Composers mete en el evento).
extends RefCounted

const RDB = preload("res://core/react/reaction_db.gd")
# deduction/ se carga en tiempo de ejecución (sólo report_cats): un módulo ajeno a medio hacer no rompe react/.
const CLIPPER_PATH := "res://core/deduction/clipper.gd"
const VALIDATOR_PATH := "res://core/deduction/validator.gd"

const ENTREGA_CATS := ["paradero_extranjero", "regreso_jueves", "baker_street", "camden"]

static func init_state(st, repo) -> void:
	if typeof(st.react) != TYPE_DICTIONARY:
		st.react = {}
	if typeof(st.react.get("moran")) != TYPE_DICTIONARY:
		st.react["moran"] = {}
	var m: Dictionary = st.react.moran
	if typeof(m.get("reports")) != TYPE_ARRAY:
		m["reports"] = []
	if typeof(m.get("next_lines")) != TYPE_ARRAY:
		m["next_lines"] = []
	for k in ["credit", "lost", "following", "delivered_holmes"]:
		if not m.has(k):
			m[k] = false
	for k in ["counters", "once"]:
		if typeof(st.react.get(k)) != TYPE_DICTIONARY:
			st.react[k] = {}
	if typeof(st.react.get("queue")) != TYPE_ARRAY:
		st.react["queue"] = []

static func observe(st, repo, ev: Dictionary, opts := {}) -> Array:
	init_state(st, repo)
	if String(ev.get("type", "")) == "report":
		_on_report(st, repo, ev)
	var bumped = opts.get("bumped")
	if typeof(bumped) != TYPE_DICTIONARY:
		bumped = {}
	return RDB.collect(st, repo, ev, null, ["moran"], bumped, String(opts.get("mode", "all")), RDB._as_arr(opts.get("skip", [])))

static func _on_report(st, repo, ev: Dictionary) -> void:
	var m: Dictionary = st.react.moran
	var cats := RDB.cats_of(ev)
	var n := int(ev.get("n", 0))
	var mode := String(ev.get("mode", "items"))
	var items := RDB._as_arr(ev.get("items", []))
	m.reports.append({"n": n, "mode": mode, "cats": cats.duplicate(), "tk": int(ev.get("tk", 0))})
	var final_n := 4
	for r in repo.schedule().get("reports", []):
		if typeof(r) == TYPE_DICTIONARY and bool(r.get("final", false)):
			final_n = int(r.get("n", 4))
	if mode == "nada" or (mode == "items" and items.is_empty()):
		st.flags["informes_vacios"] = int(st.flags.get("informes_vacios", 0)) + 1
	if cats.has("verdadero") and n < final_n:
		m.credit = true
		st.flags["moran_credito"] = true
	if cats.has("falso_verificable"):
		m.lost = true
		st.flags["moran_credito_perdido"] = true
	for c in ENTREGA_CATS:
		if cats.has(c):
			m.delivered_holmes = true
			st.flags["holmes_entregado"] = true
			break
	if cats.has("respuesta_s"):
		st.react.counters["moran.respuesta_s"] = int(st.react.counters.get("moran.respuesta_s", 0)) + 1

static func has_credit(st) -> bool:
	if typeof(st.react) != TYPE_DICTIONARY or typeof(st.react.get("moran")) != TYPE_DICTIONARY:
		return false
	return bool(st.react.moran.get("credit", false)) and not bool(st.react.moran.get("lost", false))

# ---------------- lo que Moran lee de un elemento del informe ----------------
static func _clip(st, item: Dictionary) -> Dictionary:
	var c = item.get("clip")
	if typeof(c) == TYPE_DICTIONARY and not c.is_empty():
		return c
	var id := String(item.get("id", ""))
	var cl = load(CLIPPER_PATH)
	var g = cl.get_clip(st, id) if cl != null else {}
	if typeof(g) == TYPE_DICTIONARY and not g.is_empty():
		return g
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var cs = ded.get("clips", {})
	return cs.get(id, {}) if typeof(cs) == TYPE_DICTIONARY else {}

static func _entry(st, item: Dictionary) -> Dictionary:
	var e = item.get("entry")
	if typeof(e) == TYPE_DICTIONARY and not e.is_empty():
		return e
	var id := String(item.get("id", ""))
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var es = ded.get("entries", {})
	return es.get(id, {}) if typeof(es) == TYPE_DICTIONARY else {}

static func _sealed(st) -> Dictionary:
	var ded = st.ded if typeof(st.ded) == TYPE_DICTIONARY else {}
	var s = ded.get("sealed", {})
	return s if typeof(s) == TYPE_DICTIONARY else {}

static func report_cats(st, repo, item: Dictionary) -> Array:
	var out: Array = []
	var rc: Array = repo.lists().get("report_cats", [])
	var kind := String(item.get("kind", ""))
	if kind == "clip":
		var clip := _clip(st, item)
		if clip.is_empty():
			return out
		var tags := RDB._as_arr(clip.get("tags", []))
		var dcats := _doc_cats(repo, clip)
		var cls := String(clip.get("cls", ""))
		var voice := _clip_voice(repo, clip)
		for c in rc:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var hit := false
			for t in RDB._as_arr(c.get("clip_tags", [])):
				if tags.has(t):
					hit = true
			for t in RDB._as_arr(c.get("clip_doc_cats", [])):
				if dcats.has(t):
					hit = true
			if RDB._as_arr(c.get("clip_copy_class", [])).has(cls) and cls != "":
				hit = true
			if voice != "" and RDB._as_arr(c.get("clip_voice", [])).has(voice):
				hit = true
			if hit and not out.has(String(c.cat)):
				out.append(String(c.cat))
	elif kind == "entry":
		var entry := _entry(st, item)
		if entry.is_empty():
			return out
		var sealed := _sealed(st)
		var val = load(VALIDATOR_PATH)
		for c in rc:
			if typeof(c) != TYPE_DICTIONARY:
				continue
			var hit := false
			for cid in RDB._as_arr(c.get("entry_conclusions", [])):
				if val != null and val.values_match(repo, entry, String(cid), sealed):
					hit = true
					break
			if not hit and typeof(c.get("entry_template_values")) == TYPE_DICTIONARY:
				hit = _template_values_hit(repo, entry, c.entry_template_values)
			if hit and not out.has(String(c.cat)):
				out.append(String(c.cat))
	return out

static func report_item(st, repo, item: Dictionary) -> Dictionary:
	var kind := String(item.get("kind", ""))
	var out := {"kind": kind, "id": String(item.get("id", "")), "cats": report_cats(st, repo, item), "values": {}, "copies": [], "cls": []}
	if kind == "clip":
		var clip := _clip(st, item)
		if String(clip.get("copy", "")) != "":
			out.copies.append(String(clip.copy))
		if String(clip.get("cls", "")) != "":
			out.cls.append(String(clip.cls))
	elif kind == "entry":
		out["values"] = entry_values(_entry(st, item))
	return out

static func entry_values(entry: Dictionary) -> Dictionary:
	var vals := {}
	for ln in RDB._as_arr(entry.get("lines", [])):
		if typeof(ln) == TYPE_DICTIONARY and typeof(ln.get("fields")) == TYPE_DICTIONARY:
			for f in ln.fields:
				if String(ln.fields[f]) != "":
					vals[f] = ln.fields[f]
	return vals

static func _template_values_hit(repo, entry: Dictionary, spec: Dictionary) -> bool:
	var tpl := String(entry.get("template", ""))
	if not spec.has(tpl):
		return false
	var vals := entry_values(entry)
	var fs: Dictionary = spec[tpl]
	for f in fs:
		if not vals.has(f):
			continue
		var want := _expand(repo, RDB._as_arr(fs[f]))
		if want.has(String(vals[f])):
			return true
	return false

# "@londres_falso" = lugar de lists.london_places que no es un paradero verdadero (Baker Street/221B ni Camden House).
static func _expand(repo, vals: Array) -> Array:
	var out: Array = []
	for v in vals:
		if String(v) != "@londres_falso":
			out.append(String(v))
			continue
		var truth: Array = []
		for c in repo.lists().get("report_cats", []):
			if typeof(c) == TYPE_DICTIONARY and String(c.get("cat", "")) == "baker_street":
				var etv = c.get("entry_template_values", {})
				for t in etv:
					for f in etv[t]:
						for x in etv[t][f]:
							truth.append(String(x))
		for x in repo.lists().get("camden_entities", []):
			truth.append(String(x))
		for p in repo.lists().get("london_places", []):
			if not truth.has(String(p)):
				out.append(String(p))
	return out

static func _doc_cats(repo, clip: Dictionary) -> Array:
	var out: Array = []
	for c in RDB._as_arr(clip.get("doc_cats", [])):
		out.append(c)
	var did := String(clip.get("doc", ""))
	if did == "":
		for k in ["view", "copy"]:
			var v := String(clip.get(k, ""))
			if v.contains("@"):
				did = v.get_slice("@", 0)
				break
	if did == "":
		did = String(clip.get("origin", ""))
	for c in RDB._as_arr(repo.doc(did).get("visible_cats", [])):
		if not out.has(c):
			out.append(c)
	return out

static func _clip_voice(repo, clip: Dictionary) -> String:
	for k in ["voice"]:
		if String(clip.get(k, "")) != "":
			return String(clip[k])
	for k in ["view", "origin"]:
		var v := String(clip.get(k, ""))
		if v.begins_with("R."):
			var rid := v.get_slice(".", 1)
			var r: Dictionary = repo.reaction(rid)
			if not r.is_empty():
				return RDB.voice(r)
	return ""
