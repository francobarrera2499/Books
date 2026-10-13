# core/sim/guide.gd — guía indirecta (GDD_v2 §B.6). Dueño: PROGRESIÓN.
# lines(st, repo)     -> tira «Pendientes» del calendario: ≤3 líneas [{key, vars}] (texto en ui_text, voz de Lisle), en
#                        este orden de prioridad: 1 obligación con hora HOY (informe de hoy, informe final, Sala de
#                        Visitas, dos confirmaciones esta noche) · 2 primera conclusión pendiente (desde el día 1 hasta
#                        practicar): la nota de Lisle del paso en curso (tut.d1.<paso>, GDD_v2 §B.7 «los pasos quedan en
#                        Pendientes hasta que se hagan»; si falta el texto, pend.practica; primero como en el día 1 de
#                        §B.6.3) · 3 novedades (lugar nuevo en el plano; novedades de Crane) · 3b el informe de mañana · 4 papeles de hoy sin abrir · 5 lugares
#                        conocidos sin visitar (≤2 nombres) · 6 una pregunta en rotación fija (día mod n).
#                        Los lugares se nombran con su rótulo del plano (map.json label: lo que el jugador busca en el
#                        mapa). La ayuda de «mirar alrededor» (look.ayuda) NO va acá: la pone la interfaz hasta su primer
#                        uso, que el sim no conoce.
# questions(st, repo) -> «Lo que me preguntaron»: citas TEXTUALES (lists.preguntas) ya dichas o entregadas
#                        [{id, who, quien, tk, dia, text}] en orden de aparición. Nunca marcadas resueltas ni pendientes.
# stock_now(st, repo) -> novedades de la tienda de Crane ya en la mesa (schedule.stock), lo más nuevo primero.
# Reglas duras: nunca nombra un documento como importante ni una conclusión ni cuenta progreso; no lee etiquetas ocultas
# ni lo sellado (dos estados que sólo difieren en eso dan la misma tira; test_u_guide). No es recortable (interfaz).
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const Clock = preload("res://core/sim/clock.gd")
const Diary = preload("res://core/sim/diary.gd")
const WorldModel = preload("res://core/sim/world_model.gd")
const Reveal = preload("res://core/sim/reveal.gd")
const Tutorial = preload("res://core/sim/tutorial.gd")

const MAX_LINES := 3
const MAX_PLACES := 2
const QUOTE_WORDS := 9
const VISITAS := ["L5", "forasteros"]

static func _now(st) -> int:
	return Reveal.now_tk(st)

static func _l(key: String, vars := {}) -> Dictionary:
	return {"key": key, "vars": vars}

static func join(repo, names: Array) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return String(names[0])
	var head := PackedStringArray()
	for i in names.size() - 1:
		head.append(String(names[i]))
	return ", ".join(head) + repo.text("pend.y") + String(names[-1])

static func day_label(repo, day: int) -> String:
	var info := Clock.day_info(repo, day)
	var date := String(info.get("date", ""))
	if day == TimeKey.DAY_P or date.length() < 10:
		var wd0 := String(info.get("weekday", ""))
		if wd0 != "" and date.length() >= 10:
			return "%s %d" % [repo.text("core.wd." + wd0), date.substr(8, 2).to_int()]
		return String(info.get("label", str(day)))
	return "%s %d" % [repo.text("core.wd." + String(info.get("weekday", ""))), date.substr(8, 2).to_int()]

# ---------------- Pendientes ----------------
static func lines(st, repo) -> Array:
	var c: Dictionary = st.clock
	var ph := String(c.get("phase", ""))
	var day := int(c.get("day", 0))
	if ph == "prologue" or ph == "done" or ph == "epilogue" or day < 1 or day > 10:
		return []
	var out: Array = []
	# 1 obligaciones con hora (hoy); el informe de mañana va después de las novedades (3b)
	var ob := _obligations(st, repo, day, ph)
	out.append_array(ob.today)
	# 2 primera conclusión pendiente (notas de Lisle: el paso en curso). Va antes que las novedades, como en el día 1 de
	# §B.6.3: sin la práctica no hay sello (pass_clean -> practica_pendiente) y el libro no muestra cómo confirmar, así que
	# no puede quedar debajo de la tercera línea los días con dos novedades.
	if not Tutorial.practice_done(st):
		out.append(_practice_line(st, repo))
	# 3 novedades desde ayer
	var news := Reveal.revealed_on(st, repo, day)
	if not news.is_empty():
		var names: Array = []
		for L in news:
			names.append(place_label(repo, String(L)))
		out.append(_l("pend.lugar_nuevo", {"lugares": join(repo, names)}))
	for s in stock_now(st, repo):
		if bool(s.get("new", false)) and String(s.get("line", "")) != "":
			out.append(_l(String(s.line)))
	# 3b el informe de mañana
	out.append_array(ob.later)
	# 4 papeles de hoy sin abrir
	var sa := _unopened(st, repo, day)
	if not sa.is_empty():
		out.append(sa)
	# 5 lugares conocidos sin visitar
	var nv := _not_visited(st, repo, day)
	if not nv.is_empty():
		out.append(_l("pend.sin_visitar", {"lugares": to_places(repo, nv)}))
	# 6 una pregunta en rotación fija
	var qs := questions(st, repo)
	if not qs.is_empty():
		var q: Dictionary = qs[day % qs.size()]
		out.append(_l("pend.pregunta", {"quien": _cap(String(q.quien)), "cita": short_quote(String(q.text))}))
	return out.slice(0, MAX_LINES)

# «al Museo Británico ni a Kensington» (destinos de «Todavía no fui…»): «al» delante de un rótulo que es un sustantivo
# común (Museo, Club), «a» delante de un nombre propio; « ni » entre los dos.
const AL_PREFIX := ["Museo ", "Club "]
static func to_places(repo, names: Array) -> String:
	var parts := PackedStringArray()
	for n in names:
		var s := String(n)
		var al := false
		for pre in AL_PREFIX:
			if s.begins_with(String(pre)):
				al = true
		parts.append(("al " if al else "a ") + s)
	var sep: String = repo.text("pend.ni")
	return (sep if sep != "pend.ni" else " ni ").join(parts)

# Rótulo del lugar en el plano (map.json places.<L>.label: «Museo Británico», «Kensington»); si no hay, su nombre.
static func place_label(repo, p: String) -> String:
	var m = repo.map().get("places", {}).get(p, {}) if repo.has_method("map") else {}
	if typeof(m) == TYPE_DICTIONARY and String(m.get("label", "")) != "":
		return String(m.label)
	return Diary.place_name(repo, p)

# Paso en curso de la primera conclusión: su nota de Lisle (tut.d1.<paso>, ui_text); sin texto, la línea genérica.
static func _practice_line(st, repo) -> Dictionary:
	var s := Tutorial.day1_step(st)
	var k := String(s.get("line_key", ""))
	if k != "" and repo.text(k) != k and repo.text(k).strip_edges() != "":
		return _l(k)
	return _l("pend.practica", {"paso": String(s.get("id", ""))})

# {today: obligaciones con hora de hoy (y el informe final de mañana), later: el informe ordinario de mañana}.
static func _obligations(st, repo, day: int, ph: String) -> Dictionary:
	var out: Array = []
	var later: Array = []
	var today_n := 0
	var tomorrow_n := 0
	for r in repo.schedule().get("reports", []):
		if bool(r.get("final", false)):
			continue
		var t := TimeKey.of(r.get("tk", ""))
		var n := int(r.get("n", 0))
		if TimeKey.day_of(t) == day and not Clock.report_done(st, n):
			today_n = n
		elif TimeKey.day_of(t) == day + 1:
			tomorrow_n = n
	if today_n > 0:
		out.append(_l("pend.informe_hoy", {"n": today_n}))
	elif tomorrow_n > 0:
		var wd := String(Clock.day_info(repo, day + 1).get("weekday", ""))
		later.append(_l("pend.informe_manana", {"n": tomorrow_n, "dia": repo.text("core.wd." + wd)}))
	for r in repo.schedule().get("reports", []):
		if bool(r.get("final", false)):
			var fd := TimeKey.day_of(TimeKey.of(r.get("tk", "")))
			if fd == day + 1 or (fd == day and ph == "final_report"):
				out.append(_l("pend.informe_final", {"n": int(r.get("n", 0))}))
	# Sala de Visitas abierta hoy (días 8 y 9) en un lugar ya conocido y sin cerrar
	if Reveal.place_known(st, repo, VISITAS[0]) and not Clock.area_spec(repo, VISITAS[0], VISITAS[1]).is_empty():
		var open_today := false
		for s in Clock.day_slots(repo, day):
			if TimeKey.tk(day, s) >= _now(st) or String(st.clock.get("slot", "")) == s:
				if Clock.place_open(repo, st, VISITAS[0], VISITAS[1], day, s).open:
					open_today = true
		if open_today:
			out.append(_l("pend.visitas"))
	var pn := Clock.passes_for(repo, day, "N")
	if pn >= 2 and TimeKey.tk(day, "N") >= _now(st):
		out.append(_l("pend.confirmar_noche", {"n": pn}))
	return {"today": out, "later": later}

static func _unopened(st, repo, day: int) -> Dictionary:
	var times := false
	var others := 0
	var tid := WorldModel.times_doc(repo, day)
	for it in st.world.get("tray", []):
		if typeof(it) != TYPE_DICTIONARY or int(it.get("day", -1)) != day:
			continue
		var v := String(it.get("view", ""))
		if Reveal.was_read(st, v):
			continue
		var cp: Dictionary = repo.copy(v)
		if not cp.is_empty() and tid != "" and String(cp.get("doc", "")) == tid:
			times = true
		else:
			others += 1
	if not times and others == 0:
		return {}
	var parts: Array = []
	if times:
		parts.append(repo.text("pend.sin_abrir.times"))
	if others == 1:
		parts.append(repo.text("pend.sin_abrir.uno"))
	elif others > 1:
		parts.append(repo.text("pend.sin_abrir.varios", {"n": others}))
	return _l("pend.sin_abrir", {"lista": join(repo, parts)})

static func _not_visited(st, repo, day: int) -> Array:
	var visited := {}
	for vid in st.world.get("visits", []):
		var p := String(vid).get_slice(".", 1)
		if p != "":
			visited[p] = true
	var out: Array = []
	var ps: Array = repo.schedule().get("places", {}).keys()
	ps.sort()
	for p in ps:
		if String(p) == Clock.HOME or visited.has(p) or not Reveal.place_known(st, repo, String(p)):
			continue
		if _reachable(st, repo, String(p), day):
			out.append(place_label(repo, String(p)))
		if out.size() >= MAX_PLACES:
			break
	return out

# ¿Abre alguna de sus áreas desde ahora hasta el último día? (no se sugiere un lugar al que ya no se puede ir)
static func _reachable(st, repo, p: String, day: int) -> bool:
	var now := _now(st)
	for d in range(day, Clock.last_day(repo) + 1):
		if Clock.is_fixed_day(repo, d):
			continue
		for s in Clock.day_slots(repo, d):
			if TimeKey.tk(d, s) < now:
				continue
			for a in Clock.areas_of(repo, p):
				if Clock.place_open(repo, st, p, String(a), d, String(s)).open:
					return true
	return false

static func short_quote(text: String) -> String:
	var ws := text.strip_edges().split(" ", false)
	if ws.size() <= QUOTE_WORDS:
		return text.strip_edges()
	return " ".join(ws.slice(0, QUOTE_WORDS)).rstrip(",;:") + "…"

# ---------------- Lo que me preguntaron ----------------
static func questions(st, repo) -> Array:
	var out: Array = []
	var i := 0
	for q in repo.lists().get("preguntas", []):
		i += 1
		if typeof(q) != TYPE_DICTIONARY:
			continue
		var src := String(q.get("src", ""))
		var hit := {}
		if src.begins_with("S:"):
			hit = _q_line(st, repo, src.substr(2))
		elif src.begins_with("R:"):
			hit = _q_react(st, repo, src.substr(2).get_slice(".", 0))
		elif src.contains("#"):
			hit = _q_doc(st, repo, src.get_slice("#", 0), src.get_slice("#", 1))
		if hit.is_empty() or String(hit.get("text", "")).strip_edges() == "":
			continue
		var who := String(hit.get("who", "")) if String(hit.get("who", "")) != "" and src.begins_with("R:") else String(q.get("who", hit.get("who", "")))
		var tk := int(hit.get("tk", 0))
		out.append({"id": String(q.get("id", "")), "who": who, "quien": Diary.char_label(repo, who) if who != "" else "",
			"tk": tk, "dia": day_label(repo, TimeKey.day_of(tk)), "text": String(hit.text), "_i": i})
	out.sort_custom(func(a, b):
		if int(a.tk) != int(b.tk):
			return int(a.tk) < int(b.tk)
		return int(a._i) < int(b._i))
	for x in out:
		x.erase("_i")
	return out

static func _q_line(st, repo, ref: String) -> Dictionary:
	var sid := ref.get_slice(".", 0)
	var lid := ref.substr(sid.length() + 1)
	var best := {}
	for src in [st.world.get("lines", {}), st.scenes.get("lines", {}) if typeof(st.scenes) == TYPE_DICTIONARY else {}]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var uids: Array = src.keys()
		uids.sort()
		for uid in uids:
			var rec = src[uid]
			if typeof(rec) != TYPE_DICTIONARY or String(rec.get("id", "")) != lid:
				continue
			var sc := String(rec.get("scene", ""))
			var org := String(rec.get("origin", ""))
			if sc != sid and not org.ends_with(sid) and not org.contains("." + sid + "."):
				continue
			if best.is_empty() or int(rec.get("tk", 0)) < int(best.tk):
				var pt: Dictionary = repo.parse_text(String(rec.get("text", "")), {}, String(rec.get("act", "")))
				best = {"text": _line_quote(repo, pt), "tk": int(rec.get("tk", 0)), "who": String(rec.get("who", ""))}
	return best

# De una línea dicha, la pregunta: el tramo que pregunta (o el primero); sin tramos, la oración con «?» (o la primera).
static func _line_quote(repo, pt: Dictionary) -> String:
	var plain := String(pt.get("plain", ""))
	var pick := ""
	for tr in pt.get("tramos", []):
		var t := plain.substr(int(tr.from), int(tr.to) - int(tr.from)).strip_edges()
		if t == "":
			continue
		if pick == "":
			pick = t
		if t.contains("?"):
			return t
	return pick if pick != "" else _question_sentence(repo, plain)

static func _q_react(st, repo, rid: String) -> Dictionary:
	var docs: Dictionary = st.world.get("docs", {})
	var ids: Array = docs.keys()
	ids.sort()
	for iid in ids:
		var d = docs[iid]
		if typeof(d) != TYPE_DICTIONARY or String(d.get("rid", "")) != rid or not bool(d.get("delivered", false)):
			continue
		var plains: Array = []
		for b in d.get("blocks", []):
			plains.append(_without_fisica(repo.parse_text(String(b.get("text", "")), {}, String(b.get("act", "")))))
		# quién la firma: las notas del lado del mayor van firmadas «—H.» cuando Pell ya no está (Effects._firma)
		var who := ""
		if not plains.is_empty() and String(plains[-1]).strip_edges().ends_with("—H."):
			who = "harris"
		for plain in plains:
			var q := _question_sentence(repo, String(plain))
			if q != "":
				return {"text": q, "who": who, "tk": int(d.get("created_tk", TimeKey.tk(int(d.get("day", 0)), "dawn")))}
	return {}

# El texto llano de un bloque sin la línea de descripción física (GDD_v2 §C.5: Effects la antepone a todo papel
# generado; no es lo que el personaje preguntó).
static func _without_fisica(pt: Dictionary) -> String:
	var plain := String(pt.get("plain", ""))
	for tr in pt.get("tramos", []):
		if typeof(tr) == TYPE_DICTIONARY and String(tr.get("id", "")) == "fisica":
			return (plain.substr(0, int(tr.from)) + plain.substr(int(tr.to))).strip_edges()
	return plain

static func _question_sentence(repo, plain: String) -> String:
	var sents := Markup.sentences_of(plain, repo.lists().get("abbrev", Markup.DEFAULT_ABBREV))
	var first := ""
	for s in sents:
		var t := plain.substr(int(s[0]), int(s[1]) - int(s[0])).strip_edges()
		if t == "":
			continue
		if first == "":
			first = t
		if t.contains("?"):
			return t
	return first

static func _q_doc(st, repo, did: String, tid: String) -> Dictionary:
	var tr: Dictionary = repo.doc_tramo(did, tid)
	if tr.is_empty():
		return {}
	var d: Dictionary = repo.doc(did)
	var now := _now(st)
	var given := -1
	for cp in d.get("copies", []):
		if typeof(cp) != TYPE_DICTIONARY:
			continue
		var h := String(cp.get("holder", ""))
		if h != "L1" and h != "tomo":
			continue
		var f := TimeKey.of(cp.get("from", "P.N")) if cp.has("from") else TimeKey.parse("P.N")
		if f <= now and (given < 0 or f < given):
			given = f
		if Reveal.was_read(st, String(cp.get("id", ""))) and given < 0:
			given = now
	if given < 0:
		return {}
	var pt: Dictionary = repo.parsed(did, String(tr.get("part", "")))
	var plain := String(pt.get("plain", ""))
	return {"text": plain.substr(int(tr.from), int(tr.to) - int(tr.from)).strip_edges(), "tk": given}

# ---------------- novedades de Crane ----------------
static func stock_now(st, repo) -> Array:
	var now := _now(st)
	var day := int(st.clock.get("day", 0))
	var out: Array = []
	for e in repo.schedule().get("stock", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var t := TimeKey.of(e.get("tk", ""))
		if t < 0 or t > now:
			continue
		out.append({"tk": t, "day": TimeKey.day_of(t), "copies": (e.get("copies", []) as Array).duplicate(),
			"line": String(e.get("line", "")), "new": TimeKey.day_of(t) == day})
	out.sort_custom(func(a, b): return int(a.tk) > int(b.tk))
	return out

# Mayúscula inicial (la línea de Pendientes empieza con quien preguntó: «El señor Pell: …»).
static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if s != "" else s
