# core/deduction/dossier.gd — el Expediente Holmes (GDD_v3 §1). Dueño: CORE-EXPEDIENTE. Reemplaza a ledger.gd.
# Preguntas (data/dossier.json) que NACEN de lo que hace el jugador; cada una se responde con UNA respuesta (entidad del
# índice cuyo kind está en `acepta`) y DOS pruebas (recortes de papeles distintos). Lápiz gratis y sin límite; «Pasar en
# limpio» (dq_confirm, comprometida) de a una: si cierra, tinta con el texto de Lisle; si no, sólo «Algo no cierra.».
# Estado st.ded.dossier = {
#   born:    {qid: {tk, via, origin, n}}      nacidas (abiertas, en espera o en tinta); n = orden de nacimiento
#   open:    {qid: {tk, n}}                   a la vista y sin tinta (tk = cuándo se mostró; n = orden de aparición)
#   waiting: [qid]                            nacidas que esperan lugar (tope max_abiertas; todas se muestran a mostrar_todas)
#   drafts:  {qid: {answer: "", proofs: ["", ""]}}   el lápiz
#   inked:   {qid: {tk, variant, answer, proofs: [c1, c2], n}}
#   attempts:{qid: int}                       sólo tests/bots (no público, T8)
#   noticed: {rid: tk}                        intrusiones notadas (acción examine, §4.4)
#   seen:    {clave de disparador: tk}        actos y entregas visibles ya ocurridos (leer/llega/dicho), por los ganchos
#   seen_how:{clave de disparador: "columna"} la entrega vino en los avisos del Times (origen_columna, playtest v3)
#   looked:  {qid: tk}                        hojas que el jugador ya abrió (examine «sheet/<qid>»: Pendientes deja de
#                                             anunciar «Una pregunta nueva…» por esa hoja; playtest v3)
#   shown_n: int }
# Disparadores (§1.7): inicio · leer <doc>#<tramo> | leer R:<rid>.* · llega voz:A|voz:B|R:<rid>.*|<doc> ·
#   dicho S:<escena>.<línea> · tinta <Qn> · nota <rid>. Nada lee etiquetas ocultas (T8, test_u_dossier::test_births_blind).
# Ganchos (los llama core/sim, que está aguas arriba): on_read (Reveal.act_read), on_arrival (WorldModel.deliver y
#   llegadas estáticas), on_line (líneas dichas), act_examine (acción examine). update() convierte lo visto en nacimientos.
# T14: sólo este archivo escribe st.ded.dossier.inked.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const L = preload("res://core/util/log.gd")
const Index = preload("res://core/deduction/index.gd")
const Validator = preload("res://core/deduction/validator.gd")

const REFUTADO := "f:refutado"
const TRIGGERS := ["inicio", "leer", "llega", "dicho", "tinta", "nota"]
const FORMAL := ["falta_respuesta", "faltan_pruebas", "mismo_papel"]
const DEFAULT_MAX := 3

# ---------------- estado ----------------
static func _d(st) -> Dictionary:
	var ded: Dictionary = Index.ensure(st)
	var d = ded.get("dossier")
	if typeof(d) != TYPE_DICTIONARY:
		d = {}
		ded["dossier"] = d
	for k in ["born", "open", "drafts", "inked", "attempts", "noticed", "seen", "seen_how", "looked"]:
		if typeof(d.get(k)) != TYPE_DICTIONARY:
			d[k] = {}
	if typeof(d.get("waiting")) != TYPE_ARRAY:
		d["waiting"] = []
	if not d.has("shown_n"):
		d["shown_n"] = 0
	return d

static func init_state(st, repo) -> void:
	_d(st)
	update(st, repo)

static func _now(st) -> int:
	if st is Object and int(st.get("now_tk")) >= 0:
		return int(st.now_tk)
	var c = st.clock if typeof(st.clock) == TYPE_DICTIONARY else {}
	if c.is_empty():
		return 0
	var slot := String(c.get("slot", "N"))
	if String(c.get("phase", "")) == "night":
		slot = "night"
	if not TimeKey.ORD.has(slot):
		slot = "N"
	return TimeKey.tk(int(c.get("day", 0)), slot)

static func _note(st, kind: String, payload: Dictionary) -> void:
	if st is Object and st.has_method("note"):
		st.note(kind, payload)

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}

# ---------------- datos ----------------
static func meta(repo) -> Dictionary:
	return repo.dossier() if repo.has_method("dossier") else {}

static func questions(repo) -> Array:
	return repo.questions() if repo.has_method("questions") else []

static func question(repo, qid: String) -> Dictionary:
	return repo.question(qid) if repo.has_method("question") else {}

static func principal(q: Dictionary) -> Dictionary:
	for v in q.get("variantes", []):
		if typeof(v) == TYPE_DICTIONARY and bool(v.get("principal", false)):
			return v
	var vs: Array = q.get("variantes", [])
	return vs[0] if not vs.is_empty() and typeof(vs[0]) == TYPE_DICTIONARY else {}

static func variant(q: Dictionary, vid: String) -> Dictionary:
	if vid == "":
		return principal(q)
	for v in q.get("variantes", []):
		if typeof(v) == TYPE_DICTIONARY and String(v.get("id", "")) == vid:
			return v
	return {}

static func max_open(repo) -> int:
	return int(meta(repo).get("max_abiertas", DEFAULT_MAX))

static func show_all_tk(repo) -> int:
	var s = meta(repo).get("mostrar_todas", "8.dawn")
	return TimeKey.of(s) if s != null else -1

# ---------------- ganchos (los llama core/sim) ----------------
# col: la entrega vino insertada en los avisos del Times (la línea de origen lo dice: origen_columna).
static func _see(st, key: String, col := false) -> void:
	var d := _d(st)
	var seen: Dictionary = d.seen
	if not seen.has(key):
		seen[key] = _now(st)
		if col:
			d.seen_how[key] = "columna"

# Acción read de una hoja: bloques ya resueltos por WorldModel.view (cada uno con su doc y su parsed).
static func on_read(st, repo, view: String, blocks: Array) -> void:
	var docs = st.world.get("docs", {}) if typeof(st.world) == TYPE_DICTIONARY else {}
	if typeof(docs) == TYPE_DICTIONARY and typeof(docs.get(view)) == TYPE_DICTIONARY:
		var rid := String(docs[view].get("rid", ""))
		if rid != "":
			_see(st, "leer R:%s.*" % rid)
	for b in blocks:
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var did := String(b.get("doc", ""))
		if typeof(docs) == TYPE_DICTIONARY and typeof(docs.get(did)) == TYPE_DICTIONARY:
			var rid2 := String(docs[did].get("rid", ""))
			if rid2 != "":
				_see(st, "leer R:%s.*" % rid2)
			continue
		# Marca del copista al margen de un original devuelto (HA5/HA6, §4.2): el bloque lleva el id de la instancia de la
		# reacción («R.<rid>.<n>», Director._make_inst), que no es un documento de st.world.docs. Leerla es `leer R:<rid>.*`
		# (Q8: «el papel devuelto con la marca», §4.4). Verificador v3: antes este disparador no se cumplía nunca.
		var rid3 := instance_rid(did)
		if rid3 != "":
			_see(st, "leer R:%s.*" % rid3)
			continue
		var pt = b.get("parsed", {})
		if typeof(pt) != TYPE_DICTIONARY:
			continue
		for t in pt.get("tramos", []):
			var tid := String(t.get("id", "")) if typeof(t) == TYPE_DICTIONARY else ""
			if tid != "" and did != "":
				_see(st, "leer %s#%s" % [did, tid])

# Reacción de un id de instancia «R.<rid>.<n>» ("" si no tiene esa forma).
static func instance_rid(iid: String) -> String:
	if not iid.begins_with("R."):
		return ""
	var last := iid.rfind(".")
	if last <= 2 or not iid.substr(last + 1).is_valid_int():
		return ""
	return iid.substr(2, last - 2)

# Entrega en la bandeja, el mostrador o la columna: un ejemplar estático (su documento) o una instancia (su reacción y voz).
static func on_arrival(st, repo, view: String) -> void:
	var docs = st.world.get("docs", {}) if typeof(st.world) == TYPE_DICTIONARY else {}
	if typeof(docs) == TYPE_DICTIONARY and typeof(docs.get(view)) == TYPE_DICTIONARY:
		var rid := String(docs[view].get("rid", ""))
		if rid != "":
			var col := String(docs[view].get("where", "")) == "insert"
			_see(st, "llega R:%s.*" % rid, col)
			var meta = docs[view].get("meta", {})
			var voz := arrival_voice(repo.reaction(rid), meta if typeof(meta) == TYPE_DICTIONARY else {})
			if voz != "":
				_see(st, "llega voz:" + voz, col)
		return
	var cp: Dictionary = repo.copy(view)
	if not cp.is_empty():
		_see(st, "llega " + String(cp.doc))

# Voz con la que cuenta una entrega para `llega voz:<v>` ("" = ninguna). GDD_v3 §1.3 Q3: «llega voz:A» es «la primera
# carta a máquina» (origen «…al recibir la primera carta a máquina»; HA0/HA1 la garantizan el 2.dawn). La voz A también
# entrega papeles que no son cartas a máquina (HC01, el 1.dawn: un recorte del St James's con «No lo es.» a lápiz, letra
# de imprenta y de mano); ésos no cuentan como voz A (su nacimiento es el de Q2: «leer R:HC01.*»). Sólo mira lo visible
# del papel (letra de máquina), nunca etiquetas (T8).
static func arrival_voice(r: Dictionary, meta: Dictionary) -> String:
	var voz := String(r.get("voz", ""))
	if voz != "A":
		return voz
	# la letra del papel entregado (la instancia lleva la máquina de la voz aunque no esté escrita a máquina: HC01)
	var d = meta if typeof(meta) == TYPE_DICTIONARY and meta.has("font") else r.get("doc", {})
	if typeof(d) == TYPE_DICTIONARY and String(d.get("font", "")) == "maquina":
		return "A"
	return ""

# Línea dicha (escena, diálogo): {id, scene, origin}.
static func on_line(st, rec: Dictionary) -> void:
	var lid := String(rec.get("id", ""))
	if lid == "":
		return
	var sc := String(rec.get("scene", ""))
	var org := String(rec.get("origin", ""))
	var scenes: Array = []
	if sc != "":
		scenes.append(sc)
	if org.begins_with("S.") and org.count(".") == 1:
		scenes.append(org.substr(2))
	for s in scenes:
		_see(st, "dicho S:%s.%s" % [s, lid])
		var u := lid.rfind("_")
		if u > 0:
			_see(st, "dicho S:%s.%s_*" % [s, lid.substr(0, u)])

# ---------------- nacimiento y tope ----------------
static func _trigger_key(n: Dictionary) -> String:
	for k in TRIGGERS:
		if n.has(k):
			return k
	return ""

static func _fired(st, repo, n: Dictionary) -> int:
	var d := _d(st)
	match _trigger_key(n):
		"inicio":
			return _now(st)
		"leer":
			return int(d.seen.get("leer " + String(n.leer), -1))
		"llega":
			return int(d.seen.get("llega " + String(n.llega), -1))
		"dicho":
			return int(d.seen.get("dicho " + String(n.dicho), -1))
		"tinta":
			var ik = d.inked.get(String(n.tinta))
			return int(ik.get("tk", -1)) if typeof(ik) == TYPE_DICTIONARY else -1
		"nota":
			return int(d.noticed.get(String(n.nota), -1))
	return -1

# Nacimientos y tope de abiertas. GameSim la llama después de cada apply y en cada tk cruzado. Devuelve las que se
# mostraron ahora.
static func update(st, repo) -> Array:
	var d := _d(st)
	var newborn: Array = []
	for q in questions(repo):
		var qid := String(q.get("id", ""))
		if qid == "" or d.born.has(qid):
			continue
		for n in q.get("nace", []):
			if typeof(n) != TYPE_DICTIONARY:
				continue
			var t := _fired(st, repo, n)
			if t >= 0:
				var k := _trigger_key(n)
				var org := String(n.get("origen", ""))
				# playtest v3: lo que llegó en los avisos del Times no está en la bandeja a la vista: la línea dice dónde
				if String(n.get("origen_columna", "")) != "" and String(d.seen_how.get("%s %s" % [k, str(n.get(k, ""))], "")) == "columna":
					org = String(n.origen_columna)
				newborn.append({"qid": qid, "tk": t, "via": "%s %s" % [k, str(n.get(k, ""))], "origin": org,
					"orden": int(q.get("orden", 0))})
				break
	newborn.sort_custom(func(a, b):
		if int(a.tk) != int(b.tk):
			return int(a.tk) < int(b.tk)
		return int(a.orden) < int(b.orden))
	for nb in newborn:
		d.born[nb.qid] = {"tk": int(nb.tk), "via": String(nb.via), "origin": String(nb.origin), "n": d.born.size()}
		d.waiting.append(nb.qid)
		L.d("dossier", "nace %s (%s)" % [nb.qid, nb.via])
	return _release(st, repo)

static func _release(st, repo) -> Array:
	var d := _d(st)
	var out: Array = []
	var all := show_all_tk(repo)
	var now := _now(st)
	var cap := max_open(repo)
	while not d.waiting.is_empty():
		if d.open.size() >= cap and not (all >= 0 and now >= all):
			break
		var qid := String(d.waiting.pop_front())
		if d.inked.has(qid) or d.open.has(qid):
			continue
		d.shown_n = int(d.shown_n) + 1
		d.open[qid] = {"tk": now, "n": int(d.shown_n)}
		if not d.drafts.has(qid):
			d.drafts[qid] = {"answer": "", "proofs": ["", ""]}
		out.append(qid)
		_note(st, "dossier", {"shown": qid})
	return out

# Lo que se mostró (tk) — Pendientes («Una pregunta nueva en el expediente.» la mañana siguiente).
static func shown_tks(st) -> Array:
	var out: Array = []
	var d := _d(st)
	for qid in d.open:
		out.append(int(d.open[qid].get("tk", -1)))
	for qid in d.inked:
		out.append(int(d.inked[qid].get("shown_tk", -1)))
	return out

# Lo mostrado que el jugador todavía no abrió (Pendientes: «Una pregunta nueva en el expediente.» se va al abrir la hoja).
static func news_tks(st) -> Array:
	var out: Array = []
	var d := _d(st)
	for qid in d.open:
		if not d.looked.has(qid):
			out.append(int(d.open[qid].get("tk", -1)))
	return out

# Examine «sheet/<qid>» (la UI lo emite la primera vez que abre una hoja): la hoja ya se vio. Libre y ciega.
static func act_look(st, repo, qid: String) -> Dictionary:
	var d := _d(st)
	if not d.open.has(qid) and not d.inked.has(qid):
		return {"ok": false, "err": "no_abierta"}
	if not d.looked.has(qid):
		d.looked[qid] = _now(st)
		_note(st, "dossier", {"looked": qid})
	return {"ok": true}

static func looked(st, qid: String) -> bool:
	return _d(st).looked.has(qid)

static func is_open(st, qid: String) -> bool:
	return _d(st).open.has(qid)

static func is_born(st, qid: String) -> bool:
	return _d(st).born.has(qid)

static func inked(st) -> Dictionary:
	if typeof(st.ded) != TYPE_DICTIONARY or typeof(st.ded.get("dossier")) != TYPE_DICTIONARY:
		return {}
	var ik = st.ded.dossier.get("inked", {})
	return ik if typeof(ik) == TYPE_DICTIONARY else {}

# ---------------- alias ----------------
static func alias_groups(repo, st) -> Array:
	var out: Array = []
	var ik := inked(st) if st != null else {}
	for r in meta(repo).get("alias", []):
		if typeof(r) == TYPE_DICTIONARY and ik.has(String(r.get("cuando_tinta", ""))):
			var g: Array = []
			for x in r.get("equiv", []):
				g.append(String(x))
			g.sort()
			if not g.is_empty():
				out.append(g)
	return out

static func canon(v: String, groups: Array) -> String:
	for g in groups:
		if g.has(v):
			return g[0]
	return v

static func _in_groups(v: String, groups: Array) -> bool:
	for g in groups:
		if g.has(v):
			return true
	return false

# ¿La respuesta vale para la lista de respuestas de una variante, con los alias vigentes?
static func answer_ok(v: Dictionary, answer: String, groups: Array) -> bool:
	if answer == "":
		return false
	var ca := canon(answer, groups)
	for r in v.get("respuestas", []):
		var s := String(r)
		if s.begins_with("@alias:"):
			var x := s.substr(7)
			if _in_groups(x, groups) and canon(x, groups) == ca:
				return true
			continue
		if s == answer or (_in_groups(s, groups) and canon(s, groups) == ca):
			return true
	return false

# ---------------- acciones ----------------
static func _draft(st, qid: String) -> Dictionary:
	var d := _d(st)
	if not d.drafts.has(qid):
		d.drafts[qid] = {"answer": "", "proofs": ["", ""]}
	return d.drafts[qid]

static func _guard(st, qid: String) -> String:
	var d := _d(st)
	if d.inked.has(qid):
		return "en_tinta"
	if not d.open.has(qid):
		return "no_abierta"
	return ""

static func act_answer(st, repo, a) -> Dictionary:
	var qid := String(a.get("q", ""))
	var g := _guard(st, qid)
	if g != "":
		return _err(g)
	var v := String(a.get("value", ""))
	var dr := _draft(st, qid)
	if v == "":
		dr.answer = ""
		_note(st, "dossier", {"q": qid})
		return {"ok": true}
	if not knows(st, v):
		return _err("no_indexado")
	var acc: Array = question(repo, qid).get("acepta", [])
	if not acc.has(Index.kind(repo, v)):
		return _err("fuera_de_lista")
	dr.answer = v
	_note(st, "dossier", {"q": qid})
	return {"ok": true}

static func act_proof(st, repo, a) -> Dictionary:
	var qid := String(a.get("q", ""))
	var g := _guard(st, qid)
	if g != "":
		return _err(g)
	var slot := int(a.get("slot", -1))
	if slot < 0 or slot > 1:
		return _err("no_existe")
	var cid := String(a.get("clip", ""))
	var dr := _draft(st, qid)
	var pr: Array = dr.proofs
	if cid == "":
		pr[slot] = ""
		_note(st, "dossier", {"q": qid})
		return {"ok": true}
	var clips = st.ded.get("clips", {})
	if typeof(clips) != TYPE_DICTIONARY or not clips.has(cid) or dropped(clips.get(cid)):
		return _err("no_existe")
	if String(pr[1 - slot]) == cid:
		pr[1 - slot] = ""
	pr[slot] = cid
	_note(st, "dossier", {"q": qid})
	return {"ok": true}

static func _clip(st, cid: String) -> Dictionary:
	var clips = st.ded.get("clips", {}) if typeof(st.ded) == TYPE_DICTIONARY else {}
	var c = clips.get(cid) if typeof(clips) == TYPE_DICTIONARY else null
	return c if typeof(c) == TYPE_DICTIONARY else {}

# Recorte tirado por el jugador (Clipper.act_drop): no se borra (los recortes nunca se borran: huevos, invariante), sólo
# deja de ofrecerse y no sirve de prueba.
static func dropped(c) -> bool:
	return typeof(c) == TYPE_DICTIONARY and c.has("dropped")

# ¿El recorte es prueba de una hoja en tinta? (no se puede tirar)
static func inked_proof(st, cid: String) -> bool:
	var ik := inked(st)
	for qid in ik:
		if (ik[qid].get("proofs", []) as Array).has(cid):
			return true
	return false

# Saca un recorte tirado de los borradores (lápiz). Devuelve las hojas tocadas.
static func forget_clip(st, cid: String) -> Array:
	var out: Array = []
	var d := _d(st)
	for qid in d.drafts:
		var pr: Array = d.drafts[qid].get("proofs", [])
		for i in pr.size():
			if String(pr[i]) == cid:
				pr[i] = ""
				if not out.has(qid):
					out.append(qid)
	return out

# Chequeo de forma (visible, no gasta): falta_respuesta · faltan_pruebas · mismo_papel (mismo origin).
static func formal_codes(st, answer: String, proofs: Array, repo = null, groups = null) -> Array:
	var out: Array = []
	if answer == "":
		out.append("falta_respuesta")
	var have: Array = []
	for p in proofs:
		if String(p) != "" and not _clip(st, String(p)).is_empty():
			have.append(String(p))
	if have.size() < 2:
		out.append("faltan_pruebas")
	elif String(_clip(st, have[0]).get("origin", "")) == String(_clip(st, have[1]).get("origin", "")):
		out.append("mismo_papel")
	return out

# Playtest v3: la regla del enlace es pública (renglón fijo en la hoja: «las dos pruebas tienen que tocarse»). Si las
# dos pruebas no comparten NINGUNA entidad (ni bajo alias), ninguna variante puede cerrar (todas enlazan por
# claves.entities): el intento cuenta igual, pero Lisle dice «no se tocan» en vez de sólo «Algo no cierra.». No dice nada
# de la respuesta ni de los rótulos; es lo mismo que se ve en las tarjetas.
static func _share_any(st, repo, ca: Dictionary, cb: Dictionary, gs = null) -> bool:
	var groups: Array = gs if gs is Array else (alias_groups(repo, st) if repo != null else [])
	var ea := {}
	for e in ca.get("ents", []):
		ea[canon(_eid(e), groups)] = true
	for e in cb.get("ents", []):
		if ea.has(canon(_eid(e), groups)):
			return true
	return false

static func _in_window(v: Dictionary, now: int) -> bool:
	var w = v.get("valida", {})
	if typeof(w) != TYPE_DICTIONARY:
		return true
	if w.get("desde") != null and String(w.get("desde", "")) != "" and now < TimeKey.of(w.desde):
		return false
	if w.get("hasta") != null and String(w.get("hasta", "")) != "" and now > TimeKey.of(w.hasta):
		return false
	return true

static func _covers(v: Dictionary, ta: Array, tb: Array) -> bool:
	var gs: Array = v.get("grupos", [])
	if gs.size() != 2:
		return false
	var g1: Array = gs[0].get("tags", [])
	var g2: Array = gs[1].get("tags", [])
	return (_hit(ta, g1) and _hit(tb, g2)) or (_hit(ta, g2) and _hit(tb, g1))

static func _hit(tags: Array, group: Array) -> bool:
	for t in group:
		if Validator.tag_match(tags, String(t)):
			return true
	return false

static func _linked(repo, v: Dictionary, ca: Dictionary, cb: Dictionary, groups: Array) -> bool:
	var keys = v.get("claves", {})
	var kents := {}
	for e in keys.get("entities", []):
		kents[canon(String(e), groups)] = true
	var kinds: Array = keys.get("kinds", [])
	var ea := {}
	var ka := false
	for e0 in ca.get("ents", []):
		var e := _eid(e0)
		var ce := canon(e, groups)
		if kents.has(ce):
			ea[ce] = true
		if not kinds.is_empty() and kinds.has(Index.kind(repo, e)):
			ka = true
	var kb := false
	for e1 in cb.get("ents", []):
		var e2 := _eid(e1)
		var ce2 := canon(e2, groups)
		if ea.has(ce2):
			return true
		if not kinds.is_empty() and kinds.has(Index.kind(repo, e2)):
			kb = true
	return ka and kb

# Entidad de un recorte: id (las internas son ids; {id, label} en las visibles y en algunos dobles de tests).
static func _eid(e) -> String:
	return String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)

# Condiciones 3–5 de §1.6 para un par de recortes (internos, con etiquetas) y una variante; sin respuesta ni ventana.
static func proofs_ok(repo, v: Dictionary, ca: Dictionary, cb: Dictionary, groups: Array) -> bool:
	if ca.is_empty() or cb.is_empty():
		return false
	var ta: Array = ca.get("tags", [])
	var tb: Array = cb.get("tags", [])
	if ta.has(REFUTADO) or tb.has(REFUTADO):
		return false
	if not _covers(v, ta, tb):
		return false
	return _linked(repo, v, ca, cb, groups)

# {ok, variant, formal:[]}. Con la hoja en tinta evalúa lo entintado. opts: exclude_origins (prefijos de origen o de
# escena, p. ej. "S.HC06": esas pruebas no cuentan, HB12), answer/proofs (otra respuesta o pruebas: bots y tests),
# tk (otra hora), groups (otros alias).
static func check(st, repo, qid: String, opts := {}) -> Dictionary:
	var q := question(repo, qid)
	if q.is_empty():
		return {"ok": false, "variant": "", "formal": []}
	var d := _d(st)
	var src: Dictionary = d.inked.get(qid, d.drafts.get(qid, {}))
	var answer := String(opts.get("answer", src.get("answer", "")))
	var proofs: Array = (opts.get("proofs", src.get("proofs", ["", ""])) as Array).duplicate()
	var formal := formal_codes(st, answer, proofs, repo, opts.get("groups"))
	if not formal.is_empty():
		return {"ok": false, "variant": "", "formal": formal}
	var ca := _clip(st, String(proofs[0]))
	var cb := _clip(st, String(proofs[1]))
	for p in opts.get("exclude_origins", []):
		var ps := String(p)
		for c in [ca, cb]:
			var o := String(c.get("origin", ""))
			var sc := String(c.get("scene", ""))
			if o.begins_with(ps) or (sc != "" and (sc == ps or ("S." + sc).begins_with(ps))):
				return {"ok": false, "variant": "", "formal": []}
	var groups: Array = opts.get("groups", alias_groups(repo, st))
	var now := int(opts.get("tk", _now(st)))
	for v in q.get("variantes", []):
		if typeof(v) != TYPE_DICTIONARY:
			continue
		if not answer_ok(v, answer, groups) or not _in_window(v, now):
			continue
		if proofs_ok(repo, v, ca, cb, groups):
			return {"ok": true, "variant": String(v.get("id", "")), "formal": []}
	return {"ok": false, "variant": "", "formal": []}

static func act_confirm(st, repo, a) -> Dictionary:
	var qid := String(a.get("q", ""))
	var g := _guard(st, qid)
	if g != "":
		return _err(g)
	var d := _d(st)
	var dr := _draft(st, qid)
	var formal := formal_codes(st, String(dr.answer), dr.proofs, repo)
	if not formal.is_empty():
		return {"ok": false, "err": "formal", "formal": formal}
	d.attempts[qid] = int(d.attempts.get(qid, 0)) + 1
	var r := check(st, repo, qid)
	if not bool(r.ok):
		_note(st, "dossier", {"q": qid, "inked": false})
		var msg := _text(repo, "v3core.no_cierra", "Algo no cierra.")
		if not _share_any(st, repo, _clip(st, String(dr.proofs[0])), _clip(st, String(dr.proofs[1]))):
			msg = _text(repo, "v3core.no_se_tocan", "Algo no cierra: estas dos pruebas no se tocan.")
		return {"ok": true, "inked": false, "msg": msg, "text": "", "no_link": msg != _text(repo, "v3core.no_cierra", "Algo no cierra.")}
	var first: bool = (d.inked as Dictionary).is_empty()
	var v := variant(question(repo, qid), String(r.variant))
	var shown_tk := int(d.open.get(qid, {}).get("tk", _now(st)))
	d.inked[qid] = {"tk": _now(st), "variant": String(r.variant), "answer": String(dr.answer), "proofs": (dr.proofs as Array).duplicate(),
		"n": d.inked.size() + 1, "shown_tk": shown_tk}
	d.open.erase(qid)
	d.drafts.erase(qid)
	_note(st, "dossier", {"q": qid, "inked": true})
	L.i("dossier", "%s en tinta (variante %s)" % [qid, r.variant])
	# lo que nace al entintar (tinta Qn) y lo que espera lugar
	update(st, repo)
	return {"ok": true, "inked": true, "msg": "", "text": String(v.get("tinta", "")), "variant": String(r.variant), "first": first}

# Acción libre examine {ref: "hub/<nodo>" | "missing/<copia>"} (§4.4): la UI la emite al abrir la tarjeta de un nodo
# con `aviso` o al tocar un faltante del estante. Registra la intrusión notada (noticed[rid]).
static func act_examine(st, repo, a, rid: String) -> Dictionary:
	if rid == "":
		return {"ok": true, "noticed": ""}
	var d := _d(st)
	if not d.noticed.has(rid):
		d.noticed[rid] = _now(st)
		_note(st, "dossier", {"noticed": rid})
	update(st, repo)
	return {"ok": true, "noticed": rid}

static func _text(repo, key: String, def: String) -> String:
	var t: String = repo.text(key)
	return def if t == key else t

# ---------------- consultas ----------------
static func _answer_view(st, repo, ans: String) -> Variant:
	if ans == "":
		return null
	return {"id": ans, "label": Index.label(st, repo, ans)}

static func _proof_view(st, cid: String) -> Variant:
	if cid == "":
		return null
	var C = load("res://core/deduction/clipper.gd")
	var v: Dictionary = C.visible(st, cid)
	return v if not v.is_empty() else null

static func sheet(st, repo, qid: String) -> Dictionary:
	var d := _d(st)
	var q := question(repo, qid)
	var b: Dictionary = d.born.get(qid, {})
	var ik = d.inked.get(qid)
	var src: Dictionary = ik if typeof(ik) == TYPE_DICTIONARY else d.drafts.get(qid, {"answer": "", "proofs": ["", ""]})
	var pr: Array = src.get("proofs", ["", ""])
	var inked_now := typeof(ik) == TYPE_DICTIONARY
	var v := variant(q, String(ik.get("variant", ""))) if inked_now else {}
	return {"id": qid, "text": String(q.get("texto", "")), "origin": String(b.get("origin", "")),
		"doubts": (q.get("dudas", []) as Array).duplicate(), "proof_labels": (q.get("pruebas", []) as Array).duplicate(),
		"looked": d.looked.has(qid), "state": "tinta" if inked_now else "lapiz",
		"answer": _answer_view(st, repo, String(src.get("answer", ""))),
		"proofs": [_proof_view(st, String(pr[0])), _proof_view(st, String(pr[1]))],
		"formal": [] if inked_now else formal_codes(st, String(src.get("answer", "")), pr, repo),
		"ink_text": String(v.get("tinta", "")) if inked_now else "", "variant": String(ik.get("variant", "")) if inked_now else ""}

# q_dossier: {open:[H], inked:[H]} — open en orden de aparición, inked en orden de tinta. Las en espera no aparecen.
static func view(st, repo) -> Dictionary:
	var d := _d(st)
	var op: Array = d.open.keys()
	op.sort_custom(func(a, b): return int(d.open[a].get("n", 0)) < int(d.open[b].get("n", 0)))
	var ik: Array = d.inked.keys()
	ik.sort_custom(func(a, b): return int(d.inked[a].get("n", 0)) < int(d.inked[b].get("n", 0)))
	var out := {"open": [], "inked": []}
	for qid in op:
		out.open.append(sheet(st, repo, String(qid)))
	for qid in ik:
		out.inked.append(sheet(st, repo, String(qid)))
	return out

# ¿El jugador conoce la entidad? Índice (recortes) o lo leído/oído (st.world.known; playtest v3: el selector ofrecía
# sólo lo recortado y se respondía por descarte entre 4 o 5 opciones; GDD_v3 §1.9 cuenta con ~25).
static func knows(st, ent: String) -> bool:
	if Index.has(st, ent):
		return true
	var w = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
	var k = w.get("known", {})
	return typeof(k) == TYPE_DICTIONARY and k.has(ent)

# q_answer_options(q): lo que el jugador conoce (índice ∪ leído/oído) con kind ∈ acepta, ordenado por label.
static func answer_options(st, repo, qid: String) -> Array:
	var acc: Array = question(repo, qid).get("acepta", [])
	var out: Array = []
	var ids: Array = Index.known(st, repo)
	var w = st.world if typeof(st.world) == TYPE_DICTIONARY else {}
	var kn = w.get("known", {})
	if typeof(kn) == TYPE_DICTIONARY:
		var extra: Array = kn.keys()
		extra.sort()
		for e in extra:
			if not ids.has(e) and not repo.entity(String(e)).is_empty():
				ids.append(e)
	for id in ids:
		var k := Index.kind(repo, String(id))
		if acc.has(k):
			out.append({"id": String(id), "label": Index.label(st, repo, String(id)), "kind": k})
	out.sort_custom(func(a, b):
		var ka := Index.sort_key(String(a.label))
		var kb := Index.sort_key(String(b.label))
		if ka == kb:
			return String(a.id) < String(b.id)
		return ka < kb)
	return out

# Ítem «pregunta» de informes, Mostrar y confrontación: {q, answer, inked, variant, tags (unión de las de sus pruebas)}.
static func item_view(st, repo, qid: String) -> Dictionary:
	var d := _d(st)
	var ik = d.inked.get(qid)
	var src: Dictionary = ik if typeof(ik) == TYPE_DICTIONARY else d.drafts.get(qid, {})
	if src.is_empty() and not d.born.has(qid):
		return {}
	var tags: Array = []
	for p in src.get("proofs", []):
		for t in _clip(st, String(p)).get("tags", []):
			if not tags.has(t):
				tags.append(t)
	tags.sort()
	var vid := ""
	if typeof(ik) == TYPE_DICTIONARY:
		vid = String(ik.get("variant", ""))
	else:
		var r := check(st, repo, qid)
		vid = String(r.variant) if bool(r.ok) else ""
	return {"q": qid, "answer": String(src.get("answer", "")), "inked": typeof(ik) == TYPE_DICTIONARY, "variant": vid, "tags": tags}

# Preguntas obligatorias nacidas (Q4 y Q8 pueden no nacer: entonces no cuentan para los finales).
static func mandatory_born(st, repo) -> Array:
	var out: Array = []
	var d := _d(st)
	for q in questions(repo):
		if bool(q.get("obligatoria", false)) and d.born.has(String(q.id)):
			out.append(String(q.id))
	return out

static func inked_count(st, repo) -> int:
	var n := 0
	var ik := inked(st)
	for q in questions(repo):
		if bool(q.get("obligatoria", false)) and ik.has(String(q.id)):
			n += 1
	return n

# Lápiz azul (post-créditos): por pregunta obligatoria nacida sin tinta, missing; por hoja en lápiz completa que no
# cierra, wrong. [{kind, q, note}]
static func blue_pencil(st, repo) -> Array:
	var out: Array = []
	var d := _d(st)
	for qid in mandatory_born(st, repo):
		if d.inked.has(qid):
			continue
		var q := question(repo, qid)
		var bp: Dictionary = q.get("blue_pencil", {})
		out.append({"kind": "missing", "q": qid, "note": String(bp.get("missing", ""))})
		var dr: Dictionary = d.drafts.get(qid, {})
		if formal_codes(st, String(dr.get("answer", "")), dr.get("proofs", ["", ""]), repo).is_empty() and not bool(check(st, repo, qid).ok):
			out.append({"kind": "wrong", "q": qid, "note": String(bp.get("wrong", ""))})
	return out
