# core/scenes/composers.gd — anuncios, telegramas, cartas e informes (§5.7, §3.2, §3.5; GDD §7.3, §8.2). Dueño: W2-SCENES.
# Anuncios: formas cerradas de lists.ad_forms. Un valor se ofrece/acepta sólo si su entidad está en el índice; nunca
#   un lugar de Londres (lists.london_places, si forbid_kinds_lugar_londres) ni una entidad secreto_camden
#   (lists.camden_entities, si forbid_tags tiene secreto_camden). Slots: options | kinds | assertions. form.when (DSL).
#   ${slot} = name de la entidad o ad_text de la afirmación; luego lists.contracciones.
#   compose_ad: desk en schedule.ads.office_slots (prólogo: uno, sale el día prologue_pub_day); per_day por día;
#   pub_day = siguiente día con times (sáb -> lun). El evento `ad` lo emite on_dawn(día de publicación).
# Telegramas/cartas: {to, parts:[1..3]} con las mismas piezas (entidades del índice o ids de afirmación), mismas
#   prohibiciones. Quedan pendientes; on_end_slot emite `telegram`/`letter` y los marca enviados.
# Informes: report_status / report_submit (0–3 ítems; «Sin novedad» = nada; quemar y errata sólo en el final; errata
#   sólo con errata_ofrecida). Evento `report` {n, mode, final, items:[{kind, cats, values?, copies, cls}]} con
#   cats = MoranAgent.report_cats. Escribe el flag informe_final (§3.9). Ids: AD.<n>, TG.<n>, LT.<n>, RP.<n>.
#   Anuncio: result.ad = ref de fragmento ("AD:prologo" el del prólogo, si no "AD:<n>"; es lo que lleva event.ad y lo
#   que cita HC10.ancla_de) y result.ad_id = instancia "AD.<n>".
# Dinero (sabor): cost_d en el resultado (schedule.money_d: ad, telegram_word, telegram_min, letter). W2-SIM lo descuenta.
# Emisión: los resultados traen `event` (payload listo). W2-SIM elige UN camino: o empuja result.event él mismo
#   (clock.ads_by_day al amanecer de pub_day / world.outbox en end_slot) o llama on_dawn / on_end_slot. Nunca ambos.
# Extensiones al contrato: options, preview, report_status, on_dawn, due_ads, on_end_slot, pending_mail, ad_markup,
#   ads, mail, reports.
extends RefCounted

const Deps = preload("res://core/scenes/deps.gd")
const Markup = preload("res://core/text/markup.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")

const MODES := ["items", "nada", "quemar", "errata"]
const MAX_ITEMS := 3
const MAX_PARTS := 3

# ---------------- contrato §3.8 ----------------
static func forms(repo) -> Array:
	var out: Array = []
	for f in repo.lists().get("ad_forms", []):
		if typeof(f) == TYPE_DICTIONARY:
			out.append(f.duplicate(true))
	return out

static func preview_ad(st, repo, form: String, fields: Dictionary) -> Dictionary:
	var f := _form(repo, form)
	if f.is_empty():
		return {"ok": false, "text": "", "err": "forma"}
	if f.has("when") and not Cond.eval(f.when, {"st": st, "repo": repo}):
		return {"ok": false, "text": "", "err": "forma"}
	var vars := {}
	var slots: Dictionary = f.get("slots", {})
	for sname in _sorted(slots.keys()):
		var val := String(fields.get(sname, ""))
		if val == "" or not _slot_ok(st, repo, f, slots[sname], val):
			return {"ok": false, "text": "", "err": "forma"}
		vars[sname] = _piece_text(repo, val)
	return {"ok": true, "text": Deps.fill(repo, String(f.get("text", "")), vars), "err": ""}

static func act_compose_ad(st, repo, a) -> Dictionary:
	var form := String(a.get("form", ""))
	var fields = a.get("fields", {})
	if typeof(fields) != TYPE_DICTIONARY:
		return _err("forma")
	var ph := Deps.phase(st)
	var day := Deps.day(st)
	var cfg: Dictionary = repo.schedule().get("ads", {})
	var prologue := ph == "prologue"
	if not prologue:
		var office: Array = cfg.get("office_slots", ["M", "T"])
		if ph != "desk" or not office.has(String(Deps.clock(st).get("slot", ""))):
			return _err("oficina_cerrada")
	var per_day := int(cfg.get("per_day", 1))
	var n_today := 0
	for ad in Deps.sc(st, "ads"):
		if int(ad.get("day", -1)) == day:
			n_today += 1
	if n_today >= per_day:
		return _err("uno_por_dia")
	var pv := preview_ad(st, repo, form, fields)
	if not pv.ok:
		return _err(String(pv.err))
	var pub := int(cfg.get("prologue_pub_day", 1)) if prologue else _next_times_day(repo, day)
	if pub < 0:
		return _err("oficina_cerrada")
	var S := Deps.ensure(st)
	var f := _form(repo, form)
	var id: String = st.next_id("ad", "AD.", 1)
	var ref := "AD:prologo" if prologue else "AD:" + id.get_slice(".", 1)
	var rec := {"id": id, "ref": ref, "form": form, "fields": _clean_fields(fields, f), "text": String(pv.text), "day": day,
		"slot": Deps.slot(st), "pub_day": pub, "prologue": prologue, "assertion": "", "bait": false, "bait_topic": "",
		"canary": "", "to_s": bool(f.get("to_s", false)), "says_alive": false, "published": false,
		"cost_d": int(repo.schedule().get("money_d", {}).get("ad", 30))}
	var slots: Dictionary = f.get("slots", {})
	for sname in _sorted(slots.keys()):
		var spec: Dictionary = slots[sname]
		var val := String(fields.get(sname, ""))
		if spec.has("assertions"):
			var asr := _assertion(repo, val)
			rec["assertion"] = val
			rec["says_alive"] = bool(asr.get("says_alive", false))
			if String(asr.get("kind", "")) == "cebo":
				rec["bait"] = true
				rec["bait_topic"] = String(asr.get("topic", ""))
			if String(asr.get("kind", "")) == "canario":
				rec["canary"] = val
		if bool(f.get("canary", false)) and rec.canary == "":
			rec["canary"] = "%s:%s" % [form, val]
	S.ads.append(rec)
	return {"ok": true, "ad": ref, "ad_id": id, "ref": ref, "text": rec.text, "pub_day": pub, "cost_d": rec.cost_d, "event": _ad_event(rec)}

static func act_compose_telegram(st, repo, a) -> Dictionary:
	return _compose_mail(st, repo, a, "telegram")

static func act_compose_letter(st, repo, a) -> Dictionary:
	return _compose_mail(st, repo, a, "letter")

static func act_report_submit(st, repo, a) -> Dictionary:
	var status := report_status(st, repo)
	if not bool(status.due):
		return _err("sin_informe")
	var mode := String(a.get("mode", ""))
	var items_in = a.get("items", [])
	if not MODES.has(mode) or typeof(items_in) != TYPE_ARRAY or items_in.size() > MAX_ITEMS:
		return _err("forma")
	var final := bool(status.final)
	if mode == "quemar" and not final:
		return _err("quemar_solo_final")
	if mode == "errata" and (not final or String(Deps.flags(st).get("errata_ofrecida", "")) == ""):
		return _err("errata_no_ofrecida")
	if mode != "items" and not items_in.is_empty():
		return _err("forma")
	var items: Array = []
	var seen := {}
	for it in items_in:
		if typeof(it) != TYPE_DICTIONARY or not ["clip", "entry"].has(String(it.get("kind", ""))):
			return _err("forma")
		var key := "%s|%s" % [String(it.kind), String(it.get("id", ""))]
		if seen.has(key):
			return _err("forma")
		seen[key] = true
		if not Deps.item_exists(st, it):
			return _err("no_existe")
		items.append({"kind": String(it.kind), "id": String(it.id)})
	if mode == "items" and items.is_empty():
		mode = "nada"
	var n := int(status.n)
	var text := _report_text(st, repo, n, final, mode, items)
	var ev_items: Array = []
	for it in items:
		ev_items.append(_report_item(st, repo, it))
	var S := Deps.ensure(st)
	var rid := "RP.%d" % n
	var rec := {"id": rid, "n": n, "mode": mode, "items": items, "day": Deps.day(st), "final": final, "text": text}
	S.reports[str(n)] = rec
	if final:
		S["final"] = rec.duplicate(true)
		st.flags["informe_final"] = mode
	st.push_event({"type": "report", "n": n, "mode": mode, "final": final, "items": ev_items, "report": rid})
	return {"ok": true, "report": rid, "n": n, "mode": mode, "text": text}

# ---------------- extensiones ----------------
# Valores ofrecibles para un slot de una forma: [{id, label}] (índice + prohibiciones). Lo usa ad_composer (W3-SCENEUI).
static func options(st, repo, form_id: String, slot: String) -> Array:
	var f := _form(repo, form_id)
	var spec = f.get("slots", {}).get(slot, null)
	if typeof(spec) != TYPE_DICTIONARY:
		return []
	var cands: Array = []
	if spec.has("options"):
		cands = spec.options.duplicate()
	elif spec.has("assertions"):
		for asr in repo.lists().get("assertions", []):
			if typeof(asr) == TYPE_DICTIONARY and spec.assertions.has(String(asr.get("kind", ""))):
				cands.append(String(asr.id))
	else:
		for k in Deps.index().known(st, repo):
			cands.append(String(k.get("id", "")) if typeof(k) == TYPE_DICTIONARY else String(k))
	var out: Array = []
	for c in cands:
		if _slot_ok(st, repo, f, spec, String(c)):
			out.append({"id": String(c), "label": _piece_label(repo, String(c))})
	return out

# Destinos/piezas válidas para telegramas y cartas: [{id, label}].
static func mail_options(st, repo, what := "to") -> Array:
	var out: Array = []
	for k in Deps.index().known(st, repo):
		var id := String(k.get("id", "")) if typeof(k) == TYPE_DICTIONARY else String(k)
		if (what == "to" and _to_ok(st, repo, id)) or (what == "parts" and _part_ok(st, repo, id)):
			out.append({"id": id, "label": _piece_label(repo, id)})
	if what == "parts":
		for asr in repo.lists().get("assertions", []):
			if typeof(asr) == TYPE_DICTIONARY and _part_ok(st, repo, String(asr.get("id", ""))):
				out.append({"id": String(asr.id), "label": _piece_label(repo, String(asr.id))})
	return out

# Texto final de un compositor (q_preview): compose_ad / compose_telegram / compose_letter / report_submit.
static func preview(st, repo, a: Dictionary) -> String:
	match String(a.get("t", "")):
		"compose_ad":
			var fields = a.get("fields", {})
			return String(preview_ad(st, repo, String(a.get("form", "")), fields if typeof(fields) == TYPE_DICTIONARY else {}).text)
		"compose_telegram":
			return String(_build_mail(st, repo, a, "telegram").get("text", ""))
		"compose_letter":
			return String(_build_mail(st, repo, a, "letter").get("text", ""))
		"report_submit":
			var status := report_status(st, repo)
			var items: Array = []
			for it in a.get("items", []):
				if typeof(it) == TYPE_DICTIONARY:
					items.append({"kind": String(it.get("kind", "")), "id": String(it.get("id", ""))})
			var mode := String(a.get("mode", "nada"))
			if mode == "items" and items.is_empty():
				mode = "nada"
			return _report_text(st, repo, int(status.n), bool(status.final), mode, items)
	return ""

# {due, n, final, offered_erratum, submitted:[n], via_h}. Debido: noche de schedule.reports[tk] o fase final_report.
static func report_status(st, repo) -> Dictionary:
	var sub: Dictionary = Deps.sc(st, "reports")
	var day := Deps.day(st)
	var ph := Deps.phase(st)
	var due := false
	var n := 0
	var final := false
	for r in repo.schedule().get("reports", []):
		var rn := int(r.get("n", 0))
		if sub.has(str(rn)):
			continue
		var tk := TimeKey.of(r.get("tk", ""))
		var is_final := bool(r.get("final", false))
		if (is_final and ph == "final_report") or (not is_final and ph == "night" and TimeKey.day_of(tk) == day):
			due = true
			n = rn
			final = is_final
			break
	var done: Array = []
	for k in _sorted(sub.keys()):
		done.append(int(k))
	return {"due": due, "n": n, "final": final, "offered_erratum": String(Deps.flags(st).get("errata_ofrecida", "")) != "",
		"submitted": done, "via_h": bool(Deps.flags(st).get("pell_despedido", false))}

# Anuncios que salen el día `day` (sin mutar): payloads de evento `ad`.
static func due_ads(st, day: int) -> Array:
	var out: Array = []
	for ad in Deps.sc(st, "ads"):
		if int(ad.get("pub_day", -1)) == day and not bool(ad.get("published", false)):
			out.append(_ad_event(ad))
	return out

# Amanecer del día `day` (W2-SIM, al resolver dawn): emite `ad` por cada anuncio que se publica y lo marca.
static func on_dawn(st, repo, day: int) -> Array:
	var out: Array = []
	var S := Deps.ensure(st)
	for ad in S.ads:
		if int(ad.get("pub_day", -1)) == day and not bool(ad.get("published", false)):
			ad["published"] = true
			var ev := _ad_event(ad)
			st.push_event(ev)
			out.append(ev)
	return out

static func pending_mail(st) -> Array:
	var out: Array = []
	for m in Deps.sc(st, "mail"):
		if not bool(m.get("sent", false)):
			out.append(m.duplicate(true))
	return out

# end_slot (W2-SIM): emite `telegram`/`letter` de lo pendiente y lo marca enviado.
static func on_end_slot(st, repo) -> Array:
	var out: Array = []
	var S := Deps.ensure(st)
	for m in S.mail:
		if bool(m.get("sent", false)):
			continue
		m["sent"] = true
		m["sent_tk"] = Deps.now_tk(st)
		var ev := {"type": String(m.kind), "to": String(m.to), "text": String(m.text), "id": String(m.id), "parts": m.parts.duplicate()}
		st.push_event(ev)
		out.append(ev)
	return out

# Bloque de marcado del anuncio impreso en el Times del día (W2-SIM lo inserta en D15.<MMDD>): un tramo sobre la
# primera oración con a:acto_kt y la entidad del acto. act = "act.<seq>" del evento `ad`.
static func ad_markup(st, repo, ad_id: String, act: String) -> String:
	for ad in Deps.sc(st, "ads"):
		if String(ad.get("id", "")) != ad_id and String(ad.get("ref", "")) != ad_id:
			continue
		var text := Markup.escape(String(ad.get("text", "")))
		var cut := _first_sentence_end(text)
		var head := text.substr(0, cut)
		var tail := text.substr(cut)
		var mention := "[[%s|%s]]" % [act, head] if act != "" else head
		return "{{#ad a:acto_kt|%s}}%s" % [mention, tail]
	return ""

static func ads(st) -> Array:
	return Deps.sc(st, "ads").duplicate(true)

static func mail(st) -> Array:
	return Deps.sc(st, "mail").duplicate(true)

static func reports(st) -> Dictionary:
	return Deps.sc(st, "reports").duplicate(true)

# ---------------- internos: anuncios ----------------
static func _form(repo, id: String) -> Dictionary:
	for f in repo.lists().get("ad_forms", []):
		if typeof(f) == TYPE_DICTIONARY and String(f.get("id", "")) == id:
			return f
	return {}

static func _assertion(repo, id: String) -> Dictionary:
	for asr in repo.lists().get("assertions", []):
		if typeof(asr) == TYPE_DICTIONARY and String(asr.get("id", "")) == id:
			return asr
	return {}

static func _forbidden(repo, f: Dictionary, ent: String) -> bool:
	var lst: Dictionary = repo.lists()
	if bool(f.get("forbid_kinds_lugar_londres", false)) and lst.get("london_places", []).has(ent):
		return true
	if f.get("forbid_tags", []).has("secreto_camden") and lst.get("camden_entities", []).has(ent):
		return true
	return false

static func _slot_ok(st, repo, f: Dictionary, spec, val: String) -> bool:
	if typeof(spec) != TYPE_DICTIONARY or val == "":
		return false
	if spec.has("assertions"):
		var asr := _assertion(repo, val)
		if asr.is_empty() or not spec.assertions.has(String(asr.get("kind", ""))):
			return false
		for r in asr.get("requires", []):
			if not Deps.index().has(st, String(r)) or _forbidden(repo, f, String(r)):
				return false
		return true
	if repo.entity(val).is_empty() or not Deps.index().has(st, val) or _forbidden(repo, f, val):
		return false
	if spec.has("options"):
		return spec.options.has(val)
	if spec.has("kinds"):
		return spec.kinds.has(String(repo.entity(val).get("kind", "")))
	return false

# Cómo se imprime en un anuncio el valor de un hueco (entidad o afirmación). Pública para la UI (ad_composer).
static func piece_text(repo, val: String) -> String:
	return _piece_text(repo, val)

static func _piece_text(repo, val: String) -> String:
	var asr := _assertion(repo, val)
	if not asr.is_empty():
		return String(asr.get("ad_text", asr.get("topic", val)))
	return Deps.ent_name(repo, val)

static func _piece_label(repo, val: String) -> String:
	var asr := _assertion(repo, val)
	if not asr.is_empty():
		var t := String(asr.get("ad_text", ""))
		return Deps.cap_first(t) if t != "" else Deps.cap_first(Markup.fill(String(asr.get("phrase", val)), {"addr": ""}).replace(", .", ".").replace(", ?", "?"))
	var e: Dictionary = repo.entity(val)
	return String(e.get("index", e.get("name", val)))

static func _clean_fields(fields: Dictionary, f: Dictionary) -> Dictionary:
	var out := {}
	for k in f.get("slots", {}):
		out[k] = String(fields.get(k, ""))
	return out

static func _next_times_day(repo, day: int) -> int:
	var rows: Array = repo.schedule().get("days", []).duplicate()
	rows.sort_custom(func(x, y): return int(x.get("day", 0)) < int(y.get("day", 0)))
	for r in rows:
		if int(r.get("day", -1)) > day and bool(r.get("times", false)):
			return int(r.day)
	return -1

static func _ad_event(ad: Dictionary) -> Dictionary:
	var d := int(ad.get("pub_day", 0))
	return {"type": "ad", "ad": String(ad.get("ref", "")), "ad_id": String(ad.get("id", "")), "form": String(ad.get("form", "")),
		"text": String(ad.get("text", "")), "assertion": String(ad.get("assertion", "")), "bait": bool(ad.get("bait", false)),
		"bait_topic": String(ad.get("bait_topic", "")), "canary": String(ad.get("canary", "")), "to_s": bool(ad.get("to_s", false)),
		"says_alive": bool(ad.get("says_alive", false)), "pub_day": d, "day": d, "slot": "dawn", "tk": TimeKey.tk(d, "dawn")}

static func _first_sentence_end(text: String) -> int:
	var parsed := Markup.parse(text)
	var sents: Array = parsed.get("sentences", [])
	if sents.is_empty():
		return text.length()
	return int(sents[0][1])

# ---------------- internos: correo ----------------
static func _to_ok(st, repo, id: String) -> bool:
	var e: Dictionary = repo.entity(id)
	if e.is_empty() or not ["persona", "lugar"].has(String(e.get("kind", ""))) or not Deps.index().has(st, id):
		return false
	return not _mail_forbidden(repo, id)

static func _part_ok(st, repo, id: String) -> bool:
	var asr := _assertion(repo, id)
	if not asr.is_empty():
		if String(asr.get("ad_text", "")) == "":
			return false
		for r in asr.get("requires", []):
			if not Deps.index().has(st, String(r)) or _mail_forbidden(repo, String(r)):
				return false
		return true
	if repo.entity(id).is_empty() or not Deps.index().has(st, id) or id.begins_with("act."):
		return false
	return not _mail_forbidden(repo, id)

static func _mail_forbidden(repo, id: String) -> bool:
	var lst: Dictionary = repo.lists()
	return lst.get("london_places", []).has(id) or lst.get("camden_entities", []).has(id)

static func _build_mail(st, repo, a: Dictionary, kind: String) -> Dictionary:
	var to := String(a.get("to", ""))
	var parts_in = a.get("parts", [])
	if not _to_ok(st, repo, to) or typeof(parts_in) != TYPE_ARRAY or parts_in.is_empty() or parts_in.size() > MAX_PARTS:
		return {"ok": false, "err": "forma", "text": ""}
	var parts: Array = []
	var texts: Array = []
	for p in parts_in:
		var ps := String(p)
		if parts.has(ps) or not _part_ok(st, repo, ps):
			return {"ok": false, "err": "forma", "text": ""}
		parts.append(ps)
		var pt := _piece_text(repo, ps)
		texts.append(("«%s»" % pt) if not _assertion(repo, ps).is_empty() else pt)
	var money: Dictionary = repo.schedule().get("money_d", {})
	var text := ""
	var cost := 0
	if kind == "telegram":
		var up: Array = []
		for t in texts:
			up.append(String(t).to_upper())
		text = Deps.txt(repo, "scenes.telegram", {"destino": Deps.ent_name(repo, to).to_upper(), "piezas": Deps.join_and(repo, up).to_upper()},
			"${destino}. RUEGO NOTICIAS SOBRE ${piezas}. E. L., HOLYWELL STREET, LONDRES.")
		var words := Markup.words_of(text).size()
		cost = maxi(int(money.get("telegram_min", 6)), words * int(money.get("telegram_word", 3)))
	else:
		text = Deps.txt(repo, "scenes.letter", {"destinatario": Deps.ent_name(repo, to), "piezas": Deps.join_and(repo, texts)},
			"Muy señor mío: le escribo a propósito de ${piezas}. Su seguro servidor, E. L., Holywell Street.")
		cost = int(money.get("letter", 1))
	return {"ok": true, "err": "", "text": text, "to": to, "parts": parts, "cost_d": cost}

static func _compose_mail(st, repo, a, kind: String) -> Dictionary:
	var b := _build_mail(st, repo, a, kind)
	if not bool(b.ok):
		return _err(String(b.err))
	var S := Deps.ensure(st)
	var id: String = st.next_id(kind, "TG." if kind == "telegram" else "LT.", 1)
	S.mail.append({"id": id, "kind": kind, "to": String(b.to), "parts": b.parts, "text": String(b.text), "day": Deps.day(st),
		"slot": Deps.slot(st), "sent": false, "cost_d": int(b.cost_d)})
	return {"ok": true, "id": id, "text": String(b.text), "cost_d": int(b.cost_d), "to": String(b.to),
		"event": {"type": kind, "to": String(b.to), "text": String(b.text), "id": id, "parts": b.parts.duplicate()}}

# ---------------- internos: informes ----------------
static func _report_item(st, repo, it: Dictionary) -> Dictionary:
	var cats = Deps.moran().report_cats(st, repo, {"kind": it.kind, "id": it.id})
	var clips: Array = []
	var out := {"kind": String(it.kind), "cats": cats.duplicate() if typeof(cats) == TYPE_ARRAY else [], "copies": [], "cls": []}
	if it.kind == "entry":
		clips = Deps.entry_clip_ids(st, String(it.id))
		out["values"] = Deps.entry_values(Deps.entry(st, String(it.id)))
	else:
		clips = [String(it.id)]
	for cid in clips:
		var c: Dictionary = Deps.clipper().get_clip(st, cid)
		var cp := String(c.get("copy", ""))
		if cp != "" and not out.copies.has(cp):
			out.copies.append(cp)
		var cl := String(c.get("cls", ""))
		if cl != "" and not out.cls.has(cl):
			out.cls.append(cl)
	return out

static func _report_text(st, repo, n: int, final: bool, mode: String, items: Array) -> String:
	var lines := PackedStringArray()
	var hk := "scenes.report.final" if final else ("scenes.report.h" if bool(Deps.flags(st).get("pell_despedido", false)) else "scenes.report.header")
	lines.append(Deps.txt(repo, hk, {"n": n}, "Informe n.º ${n}."))
	match mode:
		"nada":
			lines.append(Deps.txt(repo, "scenes.report.nada", {}, "Sin novedad."))
		"quemar":
			lines.append(Deps.txt(repo, "scenes.report.quemar", {}, "(Lo quemo en la estufa.)"))
		"errata":
			lines.append(Deps.txt(repo, "scenes.report.errata", {}, ""))
		_:
			var k := 0
			for it in items:
				k += 1
				var body := ""
				if it.kind == "entry":
					body = Deps.entry_summary(repo, Deps.entry(st, String(it.id)))
				else:
					var v: Dictionary = Deps.clipper().visible(st, String(it.id))
					body = "«%s»" % String(v.get("text", ""))
					if String(v.get("src_line", "")) != "":
						body += " (%s)" % String(v.src_line)
				lines.append("%d. %s" % [k, body])
	return "\n".join(lines)

static func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}
