# ui/notebook/notebook_model.gd — lógica pura del cuaderno (sin nodos; testeable headless). Dueño: W3-NOTEBOOK.
# Contrato: ARCHITECTURE §6.5 (GDD§14.1, §8.1–8.3, §7.4, §13).
# Entradas: lo que devuelve GameSim (q_clips, q_index, q_pairs, q_diary, q_marginalia; sin etiquetas ocultas) y
# text_fn = Callable(key: String, vars: Dictionary) -> String (ui_text). Nada aquí distingue lo importante: todo filtro
# y todo orden se derivan de lo visible (texto, entidades del epígrafe, línea de fuente, fecha de la crónica).
#   fold(s)                              minúsculas sin tildes (ñ -> n), para buscar
#   haystack(clip) / matches(clip, q)    búsqueda por texto: todas las palabras de q en texto+epígrafe+fuente+entidades
#   kinds_of(index_rows)                 {id: kind}
#   clip_ent_ids(clip, kinds, kind)      entidades del recorte de ese kind ("" = todas)
#   caption_text(clip)                   epígrafe legible: entidades separadas por «; » (sus etiquetas llevan comas)
#   month_key(clip)                      "AAAA-MM" de la fecha de la crónica o ""
#   apply_filters(clips, f, kinds)       f = {q, persona, lugar, fecha, ent} (vacío = sin filtro); AND entre todos
#   groups(clips)                        [{key:"AAAA-MM"|"", clips:[…]}] cronológico; sin fecha al final
#   filter_options(clips, index_rows)    {persona:[{id,label}], lugar:[…], fecha:[{key,label?}]} sólo lo presente
#   month_label(text_fn, key) / day_label(text_fn, date)    «Mayo de 1891» / «4 de mayo»
#   index_sections(rows, text_fn, q)     [{letter, rows}] (orden de q_index; cifras -> nb.indice.cifras)
#   diary_days(entries, schedule)        [{day, label, entries}] en el orden de q_diary
#   recibido_stamp(text_fn, schedule, day)   «Recibido 27-mar» (sello del diario, GDD§7.4 JUG-15)
#   speaker_label(repo, known, who)      quién dijo la línea (nombre sólo si el personaje está en el índice)
extends RefCounted

const FOLD := {"á": "a", "à": "a", "â": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "í": "i", "ì": "i",
	"î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "ö": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ñ": "n", "ç": "c"}
const FILTER_KEYS := ["persona", "lugar", "fecha", "ent"]

static func fold(s: String) -> String:
	var t := s.to_lower()
	var out := PackedStringArray()
	for k in t.length():
		var c := t[k]
		out.append(FOLD.get(c, c))
	return "".join(out)

static func _words(s: String) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for k in s.length():
		var c := s[k]
		var w := c.to_upper() != c.to_lower() or (s.unicode_at(k) >= 48 and s.unicode_at(k) <= 57)
		if w:
			cur += c
		elif cur != "":
			out.append(cur)
			cur = ""
	if cur != "":
		out.append(cur)
	return out

static func haystack(c: Dictionary) -> String:
	var parts: Array = [String(c.get("text", "")), String(c.get("caption", "")), String(c.get("src_line", ""))]
	for e in c.get("ents", []):
		if typeof(e) == TYPE_DICTIONARY:
			parts.append(String(e.get("label", "")))
	return fold(" ".join(PackedStringArray(parts)))

static func matches(c: Dictionary, q: String) -> bool:
	var ws := _words(fold(q))
	if ws.is_empty():
		return true
	var h := haystack(c)
	for w in ws:
		if not h.contains(w):
			return false
	return true

static func kinds_of(index_rows: Array) -> Dictionary:
	var out := {}
	for r in index_rows:
		if typeof(r) == TYPE_DICTIONARY:
			out[String(r.get("id", ""))] = String(r.get("kind", ""))
	return out

static func clip_ent_ids(c: Dictionary, kinds: Dictionary, kind := "") -> Array:
	var out: Array = []
	for e in c.get("ents", []):
		var id := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
		if id == "" or out.has(id):
			continue
		if kind == "" or String(kinds.get(id, "")) == kind:
			out.append(id)
	if kind == "lugar" or kind == "":
		var p := String(c.get("place", ""))
		if p != "" and not out.has(p):
			out.append(p)
	return out

# Epígrafe tal como se lee en la tarjeta. Las etiquetas del índice llevan comas («Holmes, Sherlock», «Watson, John H.,
# doctor»): el caption del sim las une con «, » y no se ve dónde termina cada entidad. Si el caption es exactamente esas
# etiquetas (más, opcionalmente, el lugar al final), se separan con «; » como en un índice de imprenta. Una lámina (lista
# de sustantivos) o un caption distinto quedan tal cual. Lista TODAS las entidades, en el mismo orden: no destaca nada.
static func caption_text(c: Dictionary) -> String:
	var cap := String(c.get("caption", ""))
	if String(c.get("kind", "text")) == "plate":
		return cap
	var labels: Array = []
	for e in c.get("ents", []):
		var lb := String(e.get("label", "")) if typeof(e) == TYPE_DICTIONARY else ""
		if lb != "" and not labels.has(lb):
			labels.append(lb)
	if labels.is_empty():
		return cap
	var joined := ", ".join(PackedStringArray(labels))
	if cap == joined:
		return "; ".join(PackedStringArray(labels))
	if cap.begins_with(joined + ", "):
		return "; ".join(PackedStringArray(labels)) + "; " + cap.substr(joined.length() + 2)
	return cap

static func month_key(c: Dictionary) -> String:
	var d := String(c.get("chron_date", ""))
	if d.length() >= 7 and d.substr(4, 1) == "-":
		return d.substr(0, 7)
	return ""

static func apply_filters(clips: Array, f: Dictionary, kinds: Dictionary) -> Array:
	var out: Array = []
	var q := String(f.get("q", ""))
	for c in clips:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if String(f.get("persona", "")) != "" and not clip_ent_ids(c, kinds, "persona").has(String(f.persona)):
			continue
		if String(f.get("lugar", "")) != "" and not clip_ent_ids(c, kinds, "lugar").has(String(f.lugar)):
			continue
		if String(f.get("fecha", "")) != "" and month_key(c) != String(f.fecha):
			continue
		if String(f.get("ent", "")) != "" and not clip_ent_ids(c, kinds, "").has(String(f.ent)):
			continue
		if q != "" and not matches(c, q):
			continue
		out.append(c)
	return out

static func active_filters(f: Dictionary) -> Array:
	var out: Array = []
	for k in FILTER_KEYS:
		if String(f.get(k, "")) != "":
			out.append(k)
	return out

# Agrupado por el calendario de la crónica: meses en orden; dentro, por fecha de la crónica y luego por id (orden de
# recorte). Lo que no trae fecha de crónica va al final.
static func groups(clips: Array) -> Array:
	var by := {}
	for c in clips:
		var k := month_key(c)
		if not by.has(k):
			by[k] = []
		by[k].append(c)
	var keys: Array = by.keys()
	keys.sort_custom(func(a, b):
		if a == "":
			return false
		if b == "":
			return true
		return a < b)
	var out: Array = []
	for k in keys:
		var arr: Array = by[k]
		arr.sort_custom(func(a, b):
			var da := String(a.get("chron_date", ""))
			var db := String(b.get("chron_date", ""))
			if da != db:
				return da < db
			return String(a.get("id", "")) < String(b.get("id", "")))
		out.append({"key": k, "clips": arr})
	return out

static func filter_options(clips: Array, index_rows: Array) -> Dictionary:
	var kinds := kinds_of(index_rows)
	var present := {"persona": {}, "lugar": {}}
	var months := {}
	for c in clips:
		for k in ["persona", "lugar"]:
			for id in clip_ent_ids(c, kinds, k):
				present[k][id] = true
		var m := month_key(c)
		if m != "":
			months[m] = true
	var out := {"persona": [], "lugar": [], "fecha": []}
	for r in index_rows:
		var id := String(r.get("id", ""))
		for k in ["persona", "lugar"]:
			if present[k].has(id):
				out[k].append({"id": id, "label": String(r.get("label", id))})
	# un lugar que sólo llega por p: y no está en el índice
	for id in present.lugar:
		var found := false
		for o in out.lugar:
			if o.id == id:
				found = true
		if not found:
			out.lugar.append({"id": String(id), "label": String(id)})
	var mk: Array = months.keys()
	mk.sort()
	for m in mk:
		out.fecha.append({"key": String(m)})
	return out

static func _t(text_fn: Callable, key: String, vars := {}) -> String:
	if text_fn.is_valid():
		var s = text_fn.call(key, vars)
		if s is String:
			return s
	return key

static func month_label(text_fn: Callable, key: String) -> String:
	if key == "":
		return _t(text_fn, "nb.sin_fecha")
	var y := key.substr(0, 4)
	var m := key.substr(5, 2).to_int()
	var mes := _t(text_fn, "core.mes.%d" % m)
	var s := _t(text_fn, "nb.mes_anio", {"mes": mes, "a": y})
	return s.substr(0, 1).to_upper() + s.substr(1)

static func day_label(text_fn: Callable, date: String) -> String:
	if date.length() < 10:
		return ""
	var d := date.substr(8, 2).to_int()
	var m := date.substr(5, 2).to_int()
	return _t(text_fn, "nb.dia_mes", {"d": d, "mes": _t(text_fn, "core.mes_corto.%d" % m)})

# Letra de sección del índice: primera letra o cifra de la etiqueta (como Index.sort_key: se saltan comillas y signos).
static func letter_of(label: String) -> String:
	var t := fold(label)
	for k in t.length():
		var c := t[k]
		if c.to_upper() != c.to_lower():
			return c.to_upper()
		if t.unicode_at(k) >= 48 and t.unicode_at(k) <= 57:
			return "#"
	return "#"

static func index_sections(rows: Array, text_fn: Callable, q := "") -> Array:
	var out: Array = []
	var ws := _words(fold(q))
	var cur := {}
	var digits: Array = []
	for r in rows:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		var lb := String(r.get("label", r.get("id", "")))
		if not ws.is_empty():
			var h := fold(lb)
			var ok := true
			for w in ws:
				if not h.contains(w):
					ok = false
			if not ok:
				continue
		var letter := letter_of(lb)
		if letter == "#":
			digits.append(r)
			continue
		if cur.is_empty() or cur.letter != letter:
			cur = {"letter": letter, "rows": []}
			out.append(cur)
		cur.rows.append(r)
	if not digits.is_empty():
		out.append({"letter": _t(text_fn, "nb.indice.cifras"), "rows": digits})
	return out

static func _sched_day(schedule: Dictionary, day: int) -> Dictionary:
	for d in schedule.get("days", []):
		if int(d.get("day", -1)) == day:
			return d
	return {}

static func diary_days(entries: Array, schedule: Dictionary) -> Array:
	var out: Array = []
	var cur := {}
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var day := int(e.get("day", 0))
		if cur.is_empty() or int(cur.day) != day:
			var sd := _sched_day(schedule, day)
			cur = {"day": day, "label": String(sd.get("label", str(day))), "entries": []}
			out.append(cur)
		cur.entries.append(e)
	return out

static func recibido_stamp(text_fn: Callable, schedule: Dictionary, day: int) -> String:
	var date := String(_sched_day(schedule, day).get("date", ""))
	var fecha := date
	if date.length() >= 10:
		fecha = _t(text_fn, "core.fecha.sello", {"d": date.substr(8, 2).to_int(), "mes_corto": _t(text_fn, "core.mes_corto.%d" % date.substr(5, 2).to_int())})
	return _t(text_fn, "nb.diario.recibido") + "\n" + fecha

# Quién dijo una línea del diario. El nombre sólo si el personaje ya está en el índice (se presentó, §6.7); si no, su
# sustantivo («librero», «caballero»). Lisle es «yo».
static func speaker_label(repo, known: Dictionary, who: String, text_fn := Callable()) -> String:
	if who == "":
		return ""
	if who == "lisle":
		return _t(text_fn, "nb.diario.yo")
	if repo == null:
		return who
	var en: Dictionary = repo.entity(who)
	var dl: Dictionary = repo.dialogue(who) if repo.has_method("dialogue") else {}
	if known.has(who) or bool(dl.get("known", false)):
		if dl.has("label"):
			return String(dl.label)
		return String(en.get("name", who))
	if en.has("noun"):
		return String(en.noun)
	return String(dl.get("trait", who))
