# core/sim/diary.gd — diario de Lisle (D36, GDD§7.4). Dueño: W2-SIM. Contrato: ARCHITECTURE §3.8.
# st.world.diary: [{id:"DY.0001", kind:"act"|"arrival"|"private"|"line", tk, type, key, text (marcado), act, origin, who,
#                   line (uid de la línea dicha), view (llegada)}]
#   act/private/arrival: origin "D36". line: origin = escena de la línea (un recorte desde el diario conserva el origen).
# Plantillas: lists.diary (W1-BIBLE, ver su _diary_nota). Búsqueda: <tipo>.<lugar>.<área> -> <tipo>.<lugar> ->
#   <tipo>.<char> -> <tipo>. Cada plantilla es UNA oración: sus tags van en un tramo que cubre la línea entera.
#   ${fecha} = «Mar\. 27» (punto escapado: no corta la oración); lo que va dentro de [[@act|…]] es texto plano escapado y
#   recortado a su primera oración. Después de Markup.fill se aplican lists.contracciones.
# Registra además la entidad runtime del acto en st.world.acts (kind act_ref, etiqueta «asiento 214, mar. 27»).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const L = preload("res://core/util/log.gd")

const ORIGIN := "D36"
const TEXTO_MAX_WORDS := 20
const PLACE_EVENTS := ["say", "show", "pay", "task", "slip", "order_copy"]

# ---------------- fechas ----------------
static func _date_parts(repo, day: int) -> Dictionary:
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == day:
			var date := String(d.get("date", ""))
			return {"wd": String(d.get("weekday", "")), "y": date.substr(0, 4).to_int(), "m": date.substr(5, 2).to_int(), "d": date.substr(8, 2).to_int()}
	return {}

static func _wd_short(repo, wd: String) -> String:
	var s: String = repo.text("core.wd_corto." + wd)
	return wd + "." if s.begins_with("core.") else s

# «mar. 27» (texto plano; etiquetas de actos).
static func fecha_plain(repo, day: int) -> String:
	var p := _date_parts(repo, day)
	if p.is_empty():
		return str(day)
	return "%s %d" % [_wd_short(repo, String(p.wd)), int(p.d)]

# «Mar\. 27» (marcado: el punto escapado no corta la oración).
static func fecha_markup(repo, day: int) -> String:
	var s := fecha_plain(repo, day)
	s = s.substr(0, 1).to_upper() + s.substr(1)
	return Markup.escape(s).replace(".", "\\.")

# Franja para el diario: M/T/N con su letra; amanecer y noche en palabras (core.slot.dawn / core.slot.N).
static func franja(repo, slot: String) -> String:
	match slot:
		"M", "T", "N":
			return slot
		"dawn":
			return _txt(repo, "core.slot.dawn", "amanecer")
		"night":
			return _txt(repo, "core.slot.N", "noche")
	return slot

static func _txt(repo, key: String, def: String) -> String:
	var s: String = repo.text(key)
	return def if s == key else s

# ---------------- texto seguro ----------------
# Primera oración de s (abreviaturas de lists.abbrev), escapada para marcado; sin punto final si strip.
static func clause(repo, s: String, strip := false, max_words := 0) -> String:
	var t := s.strip_edges()
	var sents := Markup.sentences_of(t, repo.lists().get("abbrev", Markup.DEFAULT_ABBREV))
	if sents.size() > 0:
		t = t.substr(int(sents[0][0]), int(sents[0][1]) - int(sents[0][0]))
	if max_words > 0:
		var ws := Markup.words_of(t)
		if ws.size() > max_words:
			t = t.substr(0, int(ws[max_words - 1][1]))
	if strip:
		while t.length() > 0 and t[-1] in [".", " "]:
			t = t.substr(0, t.length() - 1)
	return Markup.escape(t)

static func _entity_name(repo, id: String) -> String:
	var e: Dictionary = repo.entity(id)
	return String(e.get("name", id)) if not e.is_empty() else id

static func char_label(repo, char_id: String) -> String:
	var dl: Dictionary = repo.dialogue(char_id)
	if dl.has("label"):
		return String(dl.label)
	return _entity_name(repo, char_id)

static func place_name(repo, place: String) -> String:
	var p: Dictionary = repo.place(place)
	if p.has("name"):
		return String(p.name)
	var m = repo.map().get("places", {}).get(place, {}) if repo.has_method("map") else {}
	if typeof(m) == TYPE_DICTIONARY and m.has("label"):
		return String(m.label)
	return place

# Dinero en palabras (para plantillas: «un chelín»; ver lists._diary_nota).
static func money_words(repo, d: int) -> String:
	var nums := ["cero", "un", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce",
		"trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte"]
	var s := int(d / 12)
	var p := d % 12
	var parts: Array = []
	if s > 0:
		var sw: String = nums[s] if s <= 20 else str(s)
		parts.append(sw + (" chelín" if s == 1 else " chelines"))
	if p > 0 or s == 0:
		var pw: String = nums[p] if p <= 20 else str(p)
		parts.append(("un penique" if p == 1 else pw + " peniques"))
	return " y ".join(PackedStringArray(parts))

# ---------------- plantillas ----------------
static func template_key(repo, ev: Dictionary, place: String, area: String) -> String:
	var tpl: Dictionary = repo.lists().get("diary", {})
	var t := String(ev.get("type", ""))
	var cands: Array = []
	if place != "":
		if area != "":
			cands.append("%s.%s.%s" % [t, place, area])
		cands.append("%s.%s" % [t, place])
	if String(ev.get("char", "")) != "":
		cands.append("%s.%s" % [t, String(ev.char)])
	cands.append(t)
	for c in cands:
		if tpl.has(c):
			return c
	return ""

static func compose(repo, key: String, vars: Dictionary) -> String:
	var tpl: Dictionary = repo.lists().get("diary", {}).get(key, {})
	if tpl.is_empty():
		return ""
	var text := Markup.contract(Markup.fill(String(tpl.get("text", "")), vars), repo.lists().get("contracciones", []))
	var tags: Array = tpl.get("tags", [])
	if tags.is_empty():
		return text
	return "{{#j " + " ".join(PackedStringArray(tags)) + "|" + text + "}}"

static func _vars(st, repo, ev: Dictionary, place: String) -> Dictionary:
	var day := int(ev.get("day", TimeKey.day_of(int(ev.get("tk", 0)))))
	var slot := String(ev.get("slot", TimeKey.slot_of(int(ev.get("tk", 0)))))
	var v := {"fecha": fecha_markup(repo, day), "franja": franja(repo, slot), "lugar": Markup.escape(place_name(repo, place)) if place != "" else ""}
	match String(ev.get("type", "")):
		"go":
			v.lugar = Markup.escape(place_name(repo, String(ev.get("place", place))))
		"slip", "order_copy":
			var d: Dictionary = repo.doc(String(ev.get("doc", "")))
			var title := clause(repo, String(ev.get("title", d.get("title", ""))))
			var ent := String(d.get("entity", ""))
			v["titulo"] = ("[[%s|%s]]" % [ent, title]) if ent != "" and not repo.entity(ent).is_empty() else title
			v["seat"] = str(int(ev.get("seat", 0)))
		"say":
			v["frase"] = clause(repo, String(ev.get("phrase", "")))
			v["quien"] = Markup.escape(char_label(repo, String(ev.get("char", ""))))
		"show":
			v["quien"] = Markup.escape(char_label(repo, String(ev.get("char", ""))))
			v["que"] = _shown(repo, ev.get("item", {}))
		"pay":
			v["quien"] = Markup.escape(char_label(repo, String(ev.get("char", ""))))
			v["monto"] = money_words(repo, int(ev.get("amount_d", 0)))
		"task":
			v["quien"] = Markup.escape(char_label(repo, String(ev.get("char", ""))))
			var tk_name := String(ev.get("task", ""))
			v["encargo"] = Markup.escape(_entity_name(repo, tk_name).replace("_", " "))
		"ad":
			v["texto"] = clause(repo, String(ev.get("text", "")), true, TEXTO_MAX_WORDS)
			v.fecha = fecha_markup(repo, int(ev.get("pub_day", day)))
		"telegram", "letter":
			v["texto"] = clause(repo, String(ev.get("text", "")), true, TEXTO_MAX_WORDS)
			v["destino"] = Markup.escape(_entity_name(repo, String(ev.get("to", ""))))
		"report":
			v["n"] = str(int(ev.get("n", 0)))
			v["resumen"] = _report_summary(repo, ev)
	return v

static func _shown(repo, item) -> String:
	if typeof(item) != TYPE_DICTIONARY:
		return ""
	if String(item.get("kind", "")) == "entry":
		return Markup.escape(_txt(repo, "sim.que.entry", "un asiento del libro mayor"))
	var names: Array = []
	for e in item.get("ents", []):
		var eid := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
		if eid.begins_with("act."):
			continue
		var lab := String(e.get("label", "")) if typeof(e) == TYPE_DICTIONARY else ""
		if lab == "":
			var en: Dictionary = repo.entity(eid)
			lab = String(en.get("noun", en.get("name", eid))) if not en.is_empty() else eid
		if not names.has(lab):
			names.append(lab)
		if names.size() >= 3:
			break
	if names.is_empty():
		return Markup.escape(_txt(repo, "sim.que.clip", "un recorte"))
	return Markup.escape(", ".join(PackedStringArray(names)))

static func _report_summary(repo, ev: Dictionary) -> String:
	var mode := String(ev.get("mode", "items"))
	var items: Array = ev.get("items", [])
	if mode == "nada" or (mode == "items" and items.is_empty()):
		return _txt(repo, "sim.resumen.nada", "sin novedad")
	if mode == "quemar":
		return _txt(repo, "sim.resumen.quemar", "lo quemé")
	if mode == "errata":
		return _txt(repo, "sim.resumen.errata", "la errata a medida")
	var clips := 0
	var entries := 0
	for it in items:
		if String(it.get("kind", "")) == "entry":
			entries += 1
		else:
			clips += 1
	var parts: Array = []
	if clips > 0:
		parts.append(_count(repo, clips, "recorte", "recortes"))
	if entries > 0:
		parts.append(_count(repo, entries, "asiento", "asientos"))
	return " y ".join(PackedStringArray(parts))

static func _count(repo, n: int, sing: String, plur: String) -> String:
	var nums := ["cero", "un", "dos", "tres"]
	return (nums[n] if n < nums.size() else str(n)) + " " + (sing if n == 1 else plur)

# ---------------- entradas ----------------
static func _add(st, entry: Dictionary) -> Dictionary:
	entry["id"] = st.next_id("diary", "DY.", 4)
	st.world.diary.append(entry)
	st.note("diary", {"id": entry.id})
	return entry

static func _act_label(st, repo, ev: Dictionary, place: String) -> String:
	var day := int(ev.get("day", 0))
	var t := String(ev.get("type", ""))
	var v := {"fecha": fecha_plain(repo, int(ev.get("pub_day", day)) if t == "ad" else day),
		"lugar": place_name(repo, String(ev.get("place", place))), "seat": str(int(ev.get("seat", 0))),
		"frase": Markup.parse(clause(repo, String(ev.get("phrase", "")), false, 8)).plain,
		"quien": char_label(repo, String(ev.get("char", ""))), "destino": _entity_name(repo, String(ev.get("to", ""))),
		"n": str(int(ev.get("n", 0)))}
	var key := "sim.act." + t
	var s: String = repo.text(key, v)
	if s == key:
		s = repo.text("sim.act.default", v)
		if s == "sim.act.default":
			s = t + ", " + String(v.fecha)
	return s

static func on_event(st, repo, ev: Dictionary) -> void:
	var place := String(ev.get("place", ""))
	var area := String(ev.get("area", ""))
	var vis: Dictionary = st.world.get("visit", {})
	if place == "" and PLACE_EVENTS.has(String(ev.get("type", ""))) and not vis.is_empty():
		place = String(vis.get("place", ""))
		area = String(vis.get("area", ""))
	var act := String(ev.get("act", ""))
	if act != "":
		st.world.acts[act] = {"id": act, "kind": "act_ref", "label": _act_label(st, repo, ev, place), "type": String(ev.get("type", "")),
			"tk": int(ev.get("tk", 0)), "seq": int(ev.get("seq", 0))}
	var key := template_key(repo, ev, place, area)
	if key == "":
		return
	var text := compose(repo, key, _vars(st, repo, ev, place))
	if text == "":
		return
	_add(st, {"kind": "act", "type": String(ev.get("type", "")), "key": key, "tk": int(ev.get("tk", 0)), "act": act, "text": text, "origin": ORIGIN})

# Línea privada (sin evento público): p. ej. "stay" (franja gastada en casa). Sin plantilla, no escribe nada.
static func on_private(st, repo, key: String, vars: Dictionary, tk: int) -> void:
	if not repo.lists().get("diary", {}).has(key):
		return
	var v := vars.duplicate()
	if not v.has("fecha"):
		v["fecha"] = fecha_markup(repo, TimeKey.day_of(tk))
	if not v.has("franja"):
		v["franja"] = franja(repo, TimeKey.slot_of(tk))
	var text := compose(repo, key, v)
	if text != "":
		_add(st, {"kind": "private", "type": key, "key": key, "tk": tk, "act": "", "text": text, "origin": ORIGIN})

static func _now(st) -> int:
	if int(st.now_tk) >= 0:
		return int(st.now_tk)
	return TimeKey.tk(int(st.clock.get("day", 0)), String(st.clock.get("slot", "N")))

# Llegada a la bandeja: una línea neutra, sin contenido («Recibido: sobre, matasellos S.W.»). Una por vista.
static func on_arrival(st, repo, view: String) -> void:
	var t := _now(st)
	# una línea por llegada a la bandeja (no más líneas que entradas de bandeja de esa vista): un original devuelto
	# vuelve a anotarse; una llamada repetida no duplica.
	var arrivals := 0
	for it in st.world.get("tray", []):
		if String(it.get("view", "")) == view:
			arrivals += 1
	var lines := 0
	for e in st.world.diary:
		if String(e.get("kind", "")) == "arrival" and String(e.get("view", "")) == view:
			lines += 1
	if lines >= maxi(1, arrivals):
		return
	var v := {"fecha": fecha_markup(repo, TimeKey.day_of(t)), "franja": franja(repo, TimeKey.slot_of(t)), "que": _arrival_what(st, repo, view)}
	var text := compose(repo, "arrival", v)
	if text == "":
		return
	_add(st, {"kind": "arrival", "type": "arrival", "key": "arrival", "tk": t, "act": "", "view": view, "text": text, "origin": ORIGIN})

static func _arrival_what(st, repo, view: String) -> String:
	var inst = st.world.get("docs", {}).get(view)
	if typeof(inst) == TYPE_DICTIONARY:
		var m: Dictionary = inst.get("meta", {})
		if m.has("recibido"):
			return Markup.escape(String(m.recibido))
		var how := String(inst.get("how", "correo"))
		if how == "correo":
			var title := String(m.get("title", ""))
			var k := title.find("matasellos")
			var base := _txt(repo, "sim.recibido.correo", "sobre")
			if k >= 0:
				var tail := title.substr(k)
				for stop in [",", ";", "("]:
					var j := tail.find(stop)
					if j > 0:
						tail = tail.substr(0, j)
				return Markup.escape(base + ", " + tail.strip_edges())
			return Markup.escape(base)
		return Markup.escape(_txt(repo, "sim.recibido." + how, how))
	var cp: Dictionary = repo.copy(view)
	if not cp.is_empty():
		# original devuelto en mano o en el mostrador: sólo cómo llegó (sin contenido)
		var how := ""
		for it in st.world.get("tray", []):
			if String(it.get("view", "")) == view and int(it.get("tk", -1)) == _now(st):
				how = String(it.get("how", ""))
		if how == "mostrador_crane" or how == "en_mano":
			return Markup.escape(_txt(repo, "sim.recibido." + how, how))
		var d: Dictionary = repo.doc(String(cp.doc))
		return Markup.escape(_entity_name(repo, String(d.get("entity", ""))) if d.has("entity") else String(d.get("title", "")))
	return Markup.escape(view)

# Línea dicha (escena, visita, diálogo): se copia tal cual (tramos y etiquetas incluidos) con el origen de su escena.
static func on_line(st, repo, line: Dictionary) -> void:
	if String(line.get("text", "")).strip_edges() == "":
		return
	_add(st, {"kind": "line", "type": "line", "key": "", "tk": int(line.get("tk", 0)), "act": String(line.get("act", "")),
		"text": String(line.get("text", "")), "origin": String(line.get("origin", "")), "who": String(line.get("who", "")),
		"line": String(line.get("uid", ""))})

static func get_line(st, repo, id: String) -> Dictionary:
	for e in st.world.get("diary", []):
		if String(e.get("id", "")) == id:
			var out: Dictionary = e.duplicate()
			out["parsed"] = repo.parse_text(String(e.text), {}, String(e.get("act", "")))
			return out
	return {}

# q_diary: [{id, kind, tk, day, slot, stamp, text, parsed, origin, who, act}] en orden cronológico (tk; a igual tk,
# orden de escritura).
static func entries(st, repo) -> Array:
	var out: Array = []
	var src: Array = (st.world.get("diary", []) as Array).duplicate()
	var order := {}
	for i in src.size():
		order[String(src[i].get("id", ""))] = i
	src.sort_custom(func(a, b):
		if int(a.get("tk", 0)) != int(b.get("tk", 0)):
			return int(a.get("tk", 0)) < int(b.get("tk", 0))
		return int(order[String(a.get("id", ""))]) < int(order[String(b.get("id", ""))]))
	for e in src:
		var t := int(e.get("tk", 0))
		var o: Dictionary = e.duplicate()
		o["day"] = TimeKey.day_of(t)
		o["slot"] = TimeKey.slot_of(t)
		o["stamp"] = fecha_plain(repo, TimeKey.day_of(t)) + ", " + franja(repo, TimeKey.slot_of(t))
		o["parsed"] = repo.parse_text(String(e.text), {}, String(e.get("act", "")))
		out.append(o)
	return out
