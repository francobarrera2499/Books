# core/scenes/dialogue.gd — preguntar, afirmar, presentar, pagar y encargar (§4.12, §5.7; GDD §8.7). Dueño: CORE-EXPEDIENTE.
# v3: se presentan recortes o preguntas del Expediente ({kind: "clip" | "pregunta", id}); HB12 (Mycroft) vale con Q3 en
#   tinta cuyas pruebas no salen de S.HC06 (GDD_v3 §6.10). «¿Dónde consigo…?» (GDD_v3 §5.2): donde_items (q_donde) y
#   act_ask_donde (acción comprometida y NO pública: Crane no es canal); el ítem que revela un lugar lo suma al plano con
#   «Me lo dijo Crane.» (Reveal.reveal, cargado en tiempo de llamada: scenes no precarga sim).
# Respuesta por capas (§4.12): afirmacion -> tema -> documento -> entidad -> tipo -> generica (Det.pick).
#   `match` SÓLO sobre propiedades visibles (T20b): topic, ents, docs, kinds, assertion. `when` = DSL §4.18 (estado).
#   Líneas con `reaction` y sin `match` sólo se usan como respuesta especial (HB4, HB6, HB8, M4, HB12).
#   Ids reservados (sólo por id, nunca por capas): "conf.*" (confrontación), "pago" (pagar), "tarea.<task>" (encargo).
# Resultados especiales al presentar (§5.7): Watson + Mary/«vive» -> HB4 · Mrs. Hudson -> HB6 · Pell + moran_autor -> M4
#   · Wiggins (chelín o «vieja tarifa», día ≥3) -> HB8 · Mycroft -> HB12 (escribe errata_ofrecida / forasteros_cerrada).
#   Línea de la respuesta especial: la del personaje con id == sub (hb4.1, hb4.2, hb12.ok, hb12.err1, hb12.err2, hb8, m4,
#   hb6) o con el id que la reacción declara en su efecto `linea` (vieja_tarifa, hb12_exito, hb12_error_1/2); si no hay,
#   ui_text scenes.<sub>; si tampoco, la respuesta por capas.
#   Siempre se llama Director.immediate(ev + {day, slot, tk, _reaction, _visit}); sus `line` se agregan después. Las
#   claves extra llevan «_» para que Director.sig empareje immediate() con on_public_event() (sin doble observación).
#   Presentar a Pell: el evento show lleva item.cats (MoranAgent.report_cats) para la regla M4 del Director.
#   Effects de una línea: Effects.apply(st, repo, {iid:"LINE.<uid>", rid:"", efecto:[ops], char, line, anchor}, false).
# Líneas dichas: st.scenes.lines[uid] = {uid, who, to, text (marcado ya rellenado), origin, visit, place, tk, id,
#   kind: frase|respuesta|inmediata|cierre|escena|confrontacion, scene, act}. uid = st.next_id("line","LN.",4) (mismo
#   contador y formato que WorldModel.say_line de W2-SIM, que guarda las líneas de escena en st.world.lines).
#   Clipper.find_record (W2-DED) ya busca ahí: src {kind:"line", ref:uid} recorta sin pegamento.
#   Los act_* las devuelven en `lines`: W2-SIM llama Diary.on_line con cada una (scenes no puede precargar sim).
# Preguntas: ≤ max_questions (def. 3; Crane 99) por personaje y visita; ask y assert cuentan; al agotar, `closing`.
# Extensiones al contrato §3.8: assertions, scene_chars, present_ok, budget_left, said, line, say_line,
#   scene_lines, play_scene (escenas fijas/automáticas §4.13: variantes, when, gen acts_by_channel).
extends RefCounted

const Deps = preload("res://core/scenes/deps.gd")
const Markup = preload("res://core/text/markup.gd")
const Cond = preload("res://core/util/cond.gd")
const Det = preload("res://core/util/det.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const L = preload("res://core/util/log.gd")

const LAYERS := ["afirmacion", "tema", "documento", "entidad", "tipo"]   # luego "generica"
const SUBS := {"HB4": ["hb4.1", "hb4.2"], "HB12": ["hb12.ok", "hb12.err1", "hb12.err2"], "HB8": ["hb8"], "M4": ["m4"], "HB6": ["hb6"]}
const SUB_RESULT := {"hb12.ok": "exito", "hb12.err1": "error_1", "hb12.err2": "error_2"}   # efecto.resultado de HB12
const SPECIAL_HB4_CHARS := ["watson"]      # HB4: Watson + Mary/«vive» (§5.7)
const HB8_ENTS := ["vieja_tarifa"]          # «the old scale of pay» (D44, GDD HB8)
const SHILLING_D := 12
const TASKS := ["seguir_chico_pell", "seguir_parker"]   # §3.5
const HB12_QUESTION := "Q3"
const HB12_EXCLUDED_ORIGIN := "S.HC06"      # §12.1.4
const HB12_EXCLUDED_SCENE := "HC06"
const CHANNELS := ["kbm", "kw", "kh", "ks", "kt"]
const L3_INTERIOR := ["interior", "vestibulo", "salita"]

static func init_state(st, repo) -> void:
	if typeof(st.scenes) != TYPE_DICTIONARY:
		st.scenes = {}
	var d := Deps.defaults()
	for k in ["dialogue", "lines", "mycroft", "reports", "final", "ending", "ads", "mail"]:
		st.scenes[k] = d[k]
	if not st.scenes.has("confront"):
		st.scenes["confront"] = d.confront

# Respuesta por capas (sin efectos). visible = {topic?, ents:[id|{id,label}], kind?, docs|doc_ids?, assertion?}.
# Devuelve {id, layer, text (marcado sin rellenar), effects, reaction} o {} si el personaje no tiene datos.
static func respond(st, repo, char_id: String, visible: Dictionary) -> Dictionary:
	var dlg: Dictionary = repo.dialogue(char_id)
	var v := _norm_visible(repo, visible)
	var ctx := {"st": st, "repo": repo, "char": char_id}
	var lines: Array = dlg.get("lines", [])
	for layer in LAYERS:
		for ln in lines:
			if typeof(ln) != TYPE_DICTIONARY or String(ln.get("layer", "")) != layer or _reserved(String(ln.get("id", ""))):
				continue
			if not _match(layer, ln.get("match", {}), v):
				continue
			if not Cond.eval(ln.get("when", {}), ctx):
				continue
			return _resp(ln)
	var gen: Array = []
	for ln in lines:
		if typeof(ln) == TYPE_DICTIONARY and String(ln.get("layer", "")) == "generica" and String(ln.get("reaction", "")) == "" \
				and not _reserved(String(ln.get("id", ""))) and Cond.eval(ln.get("when", {}), ctx):
			gen.append(ln)
	if gen.is_empty():
		return {}
	return _resp(Det.pick(_seed(st), ["dlg", char_id, v.key], gen))

# Frase exacta de Lisle (ask, assert, present, pay, task). "" si no aplica.
static func preview(st, repo, a: Dictionary) -> String:
	var ch := String(a.get("char", ""))
	var addr := _addr(repo, ch, st)
	match String(a.get("t", "")):
		"ask":
			var topic := String(a.get("topic", ""))
			var ph = repo.dialogue(ch).get("ask_phrase", {})
			if typeof(ph) != TYPE_DICTIONARY:
				ph = {}
			var tpl := String(ph.get(topic, ph.get("default", _raw(repo, "scenes.ask", "¿Qué sabe usted de ${topic}, ${addr}?"))))
			return Deps.cap_first(_fill(repo, tpl, {"topic": Deps.ent_name(repo, topic), "addr": addr}))
		"assert":
			var asr := _assertion(repo, String(a.get("assertion", "")))
			if asr.is_empty():
				return ""
			return Deps.cap_first(_fill(repo, String(asr.get("phrase", "")), {"addr": addr}))
		"present":
			var item = a.get("item", {})
			if typeof(item) != TYPE_DICTIONARY:
				return ""
			if String(item.get("kind", "")) == "pregunta":
				return Deps.txt(repo, "v3core.present.pregunta", {"addr": addr, "resumen": Deps.question_summary(st, repo, String(item.get("id", "")))}, "Mire esto que anoté, ${addr}: ${resumen}")
			var v: Dictionary = Deps.clipper().visible(st, String(item.get("id", "")))
			return Deps.txt(repo, "scenes.present.clip", {"addr": addr, "texto": String(v.get("text", ""))}, "Mire esto, ${addr}: «${texto}»")
		"pay":
			return Deps.txt(repo, "scenes.pay", {"addr": addr, "monto": Deps.money(int(a.get("amount_d", 0)))}, "Tome, ${addr}: ${monto}")
		"task":
			return Deps.txt(repo, "scenes.task." + String(a.get("task", "")), {"addr": addr}, "")
	return ""

# Temas preguntables ahora: entidades del índice (sin act_ref). [{id, label}] ordenado por etiqueta.
static func topics(st, repo, char_id: String) -> Array:
	if _check_char(st, repo, char_id) != "" or budget_left(st, repo, char_id) <= 0:
		return []
	var out: Array = []
	for k in Deps.index().known(st, repo):
		var id := String(k.get("id", "")) if typeof(k) == TYPE_DICTIONARY else String(k)
		if id == "" or id.begins_with("act."):
			continue
		var label := String(k.get("label", "")) if typeof(k) == TYPE_DICTIONARY else ""
		if label == "":
			label = Deps.index().display(repo, id)
		out.append({"id": id, "label": label})
	# playtest v3: también lo que Lisle conoce por haberlo leído u oído (st.world.known), como el selector de respuestas
	# (GDD_v3 §1.9): «Sherlock Holmes» no salía en el 221B porque nadie lo había recortado.
	var seen := {}
	for x in out:
		seen[String(x.id)] = true
	var kn = st.world.get("known", {}) if typeof(st.world) == TYPE_DICTIONARY else {}
	if typeof(kn) == TYPE_DICTIONARY:
		for e in kn:
			var eid := String(e)
			if eid == "" or eid.begins_with("act.") or seen.has(eid) or repo.entity(eid).is_empty():
				continue
			seen[eid] = true
			out.append({"id": eid, "label": Deps.index().display(repo, eid)})
	out.sort_custom(func(x, y): return String(x.label).naturalnocasecmp_to(String(y.label)) < 0)
	return out

static func act_ask(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var topic := String(a.get("topic", ""))
	var e := _check_char(st, repo, ch)
	if e != "":
		return _err(e)
	if topic == "" or topic.begins_with("act.") or not (Deps.index().has(st, topic) or _known(st, topic)):
		return _err("no_indexado")   # los actos (act_ref) no son temas: topics() tampoco los ofrece
	if budget_left(st, repo, ch) <= 0:
		return _err("sin_preguntas")
	var visible := {"topic": topic, "ents": [topic], "kind": String(repo.entity(topic).get("kind", ""))}
	var special := ""
	if SPECIAL_HB4_CHARS.has(ch) and _touches_group(repo, "mary", [topic]):
		special = "HB4"
	var phrase := preview(st, repo, {"t": "ask", "char": ch, "topic": topic})
	var ev := {"type": "say", "kind": "ask", "topic": topic, "assertion": "", "bait": false, "bait_topic": "", "canary": "",
		"says_alive": false, "phrase": phrase, "ents": _pub_ents(repo, [topic])}
	return _speak(st, repo, ch, "ask", visible, phrase, special, ev, {})

static func act_assert(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var aid := String(a.get("assertion", ""))
	var asr := _assertion(repo, aid)
	if asr.is_empty():
		return _err("forma")
	var e := _check_char(st, repo, ch)
	if e != "":
		return _err(e)
	for r in asr.get("requires", []):
		if not Deps.index().has(st, String(r)):
			return _err("no_indexado")
	if not _assert_channel_ok(repo, ch, asr):
		return _err("forma")
	if budget_left(st, repo, ch) <= 0:
		return _err("sin_preguntas")
	var kind := String(asr.get("kind", ""))
	var topic := String(asr.get("topic", ""))
	var reqs: Array = []
	for r in asr.get("requires", []):
		reqs.append(String(r))
	var says_alive := bool(asr.get("says_alive", false))
	var special := ""
	if SPECIAL_HB4_CHARS.has(ch) and (says_alive or _touches_group(repo, "mary", [topic] + reqs)):
		special = "HB4"
	var visible := {"assertion": aid, "topic": topic, "ents": reqs, "kind": ""}
	var phrase := preview(st, repo, {"t": "assert", "char": ch, "assertion": aid})
	var ev := {"type": "say", "kind": "assert", "topic": topic, "assertion": aid, "bait": kind == "cebo",
		"bait_topic": topic if kind == "cebo" else "", "canary": aid if kind == "canario" else "", "says_alive": says_alive,
		"phrase": phrase, "ents": _pub_ents(repo, reqs)}
	return _speak(st, repo, ch, "assert", visible, phrase, special, ev, {})


static func act_present(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var item = a.get("item", {})
	if typeof(item) != TYPE_DICTIONARY or not ["clip", "pregunta"].has(String(item.get("kind", ""))):
		return _err("forma")
	var e := _check_char(st, repo, ch)
	if e != "":
		return _err(e)
	if not Deps.item_exists(st, item):
		return _err("no_existe")
	var vis := _visible_item(st, repo, item)
	if vis.is_empty():
		return _err("no_existe")
	var camden := Deps.item_camden(st, repo, item)
	var tokens: Array = vis.ents.duplicate()
	if String(vis.get("answer", "")) != "" and not tokens.has(String(vis.answer)):
		tokens.append(String(vis.answer))
	var special := ""
	var outcome := ""
	var opts := {}
	var pell_cats: Array = []
	match ch:
		"watson":
			if _touches_group(repo, "mary", tokens) or _says_alive(repo, tokens):
				special = "HB4"
			elif String(item.get("kind", "")) == "pregunta":
				# una pregunta cuya respuesta dice que vive (Moran la leería «holmes_vive»: Q5 con holmes, GDD_v3 §6.10)
				var wc = Deps.moran().report_cats(st, repo, {"kind": "pregunta", "id": String(item.get("id", ""))})
				if typeof(wc) == TYPE_ARRAY and wc.has("holmes_vive"):
					special = "HB4"
		"mrs_hudson":
			special = "HB6"
		"pell":
			var pc = Deps.moran().report_cats(st, repo, {"kind": item.kind, "id": item.id})
			if typeof(pc) == TYPE_ARRAY:
				pell_cats = pc.duplicate()
			if pell_cats.has("moran_autor"):
				special = "M4"
		"wiggins":
			if _hb8_open(st):
				for t in tokens:
					if HB8_ENTS.has(t):
						special = "HB8"
		"mycroft":
			var r := _hb12(st, repo, item, camden)
			if String(r.sub) != "":
				special = "HB12"
				opts["sub"] = r.sub
			outcome = String(r.outcome)
	var phrase := preview(st, repo, {"t": "present", "char": ch, "item": item})
	var ev := {"type": "show", "item": _pub_item(repo, item, vis, camden)}
	# Pell es lector de Moran (no sensor de Holmes): el evento lleva las categorías que Moran leería (§5.4 report_cats),
	# para que la regla M4 (match {type: show, char: pell, cat: moran_autor}) dispare en el Director.
	if ch == "pell" and not camden:
		ev.item["cats"] = pell_cats.duplicate()
	var res := _speak(st, repo, ch, "present", vis, phrase, special, ev, opts)
	if outcome != "":
		res["outcome"] = outcome
	return res

static func act_pay(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var amount := int(a.get("amount_d", 0))
	if amount <= 0:
		return _err("forma")
	var e := _check_char(st, repo, ch)
	if e != "":
		return _err(e)
	var special := ""
	if ch == "wiggins" and amount >= SHILLING_D and _hb8_open(st):
		special = "HB8"
	var phrase := preview(st, repo, {"t": "pay", "char": ch, "amount_d": amount})
	var ev := {"type": "pay", "amount_d": amount}
	var res := _speak(st, repo, ch, "pay", {"ents": []}, phrase, special, ev, {"fixed": {"id": "pago", "ui": "scenes.pay.gracias"}})
	res["amount_d"] = amount
	return res

static func act_task(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var task := String(a.get("task", ""))
	if not TASKS.has(task) or ch != "wiggins":
		return _err("forma")
	var e := _check_char(st, repo, ch)
	if e != "":
		return _err(e)
	var f := Deps.flags(st)
	if not bool(f.get("wiggins_aliado", false)) or bool(f.get("wiggins_quemado", false)):
		return _err("no_aliado")
	var dk := str(Deps.day(st))
	if Deps.sc(st, "dialogue").get("tasks", {}).has(dk):
		return _err("uno_por_dia")
	var S := Deps.ensure(st)
	S.dialogue.tasks[dk] = task
	var phrase := preview(st, repo, {"t": "task", "char": ch, "task": task})
	var ev := {"type": "task", "task": task}
	var res := _speak(st, repo, ch, "task", {"ents": []}, phrase, "", ev, {"fixed": {"id": "tarea." + task, "ui": "scenes.task.ok"}})
	res["task"] = task
	return res

# ---------------- extensiones ----------------
static func budget_left(st, repo, char_id: String) -> int:
	var mx := int(repo.dialogue(char_id).get("max_questions", 3))
	var used := int(Deps.sc(st, "dialogue").get("asked", {}).get(_budget_key(st, char_id), 0))
	return mx - used

# Afirmaciones disponibles (requires en el índice; canal del personaje si se indica). [{id, kind, topic, phrase}]
static func assertions(st, repo, char_id := "") -> Array:
	var out: Array = []
	for asr in repo.lists().get("assertions", []):
		if typeof(asr) != TYPE_DICTIONARY:
			continue
		var okk := true
		for r in asr.get("requires", []):
			if not Deps.index().has(st, String(r)):
				okk = false
				break
		if not okk or (char_id != "" and not _assert_channel_ok(repo, char_id, asr)):
			continue
		out.append({"id": String(asr.id), "kind": String(asr.get("kind", "")), "topic": String(asr.get("topic", "")),
			"phrase": Deps.cap_first(_fill(repo, String(asr.get("phrase", "")), {"addr": _addr(repo, char_id, st)}))})
	return out

# Personajes presentes para el panel de escena: [{id, label, trait, can_ask, can_present}] (nombre sólo si se presentó).
static func scene_chars(st, repo) -> Array:
	var out: Array = []
	var intro: Dictionary = Deps.sc(st, "dialogue").get("introduced", {})
	for c in Deps.chars_present(st):
		var dlg: Dictionary = repo.dialogue(c)
		var label := String(dlg.get("label", Deps.ent_name(repo, c)))
		if not intro.has(c):
			var noun := String(repo.entity(c).get("noun", ""))
			if noun != "":
				label = noun
		var okc := _check_char(st, repo, c) == ""
		out.append({"id": c, "label": label, "trait": String(dlg.get("trait", "")), "can_ask": okc and budget_left(st, repo, c) > 0,
			"can_present": okc})
	return out

static func present_ok(st, repo, char_id: String) -> bool:
	return _check_char(st, repo, char_id) == ""

# Líneas dichas en orden de uid; filtro opcional {visit, origin, scene, who}.
static func said(st, filter := {}) -> Array:
	var s: Dictionary = Deps.sc(st, "lines")
	var ks: Array = s.keys()
	ks.sort()
	var out: Array = []
	for k in ks:
		var ln: Dictionary = s[k]
		var okk := true
		for f in filter:
			if String(ln.get(f, "")) != String(filter[f]):
				okk = false
		if okk:
			out.append(ln.duplicate())
	return out

static func line(st, uid: String) -> Dictionary:
	var ln = Deps.sc(st, "lines").get(uid, {})
	return ln.duplicate() if typeof(ln) == TYPE_DICTIONARY else {}

# Registra una línea dicha (marcado ya rellenado). meta: {origin?, id?, kind?, scene?, to?}.
static func say_line(st, repo, who: String, text: String, meta := {}) -> Dictionary:
	var S := Deps.ensure(st)
	var uid: String = st.next_id("line", "LN.", 4)
	var ln := {"uid": uid, "who": who, "text": text, "origin": String(meta.get("origin", Deps.origin(st, repo))),
		"visit": Deps.visit_key(st), "place": String(meta.get("place", Deps.visit(st).get("place", ""))), "tk": Deps.now_tk(st),
		"id": String(meta.get("id", "")),
		"kind": String(meta.get("kind", "respuesta")), "scene": String(meta.get("scene", Deps.visit(st).get("scene", ""))),
		"to": String(meta.get("to", "")), "act": String(meta.get("act", ""))}
	S.lines[uid] = ln
	return ln.duplicate()

# Líneas resueltas de una escena (§4.13) sin mutar: when de escena y línea, variantes (replace/append) en orden,
# gen acts_by_channel (un acto por canal usado: b_kbm, b_kw…; si ninguno, fallback). Omite ids "conf.*" (HC07).
static func scene_lines(st, repo, scene_id: String) -> Array:
	var scn: Dictionary = repo.scene(scene_id)
	if scn.is_empty():
		return []
	var ctx := {"st": st, "repo": repo}
	if not Cond.eval(scn.get("when", {}), ctx):
		return []
	var lines: Array = []
	for ln in scn.get("lines", []):
		if typeof(ln) == TYPE_DICTIONARY and not String(ln.get("id", "")).begins_with("conf."):
			lines.append(ln.duplicate(true))
	for v in scn.get("variants", []):
		if typeof(v) != TYPE_DICTIONARY or not Cond.eval(v.get("when", {}), ctx):
			continue
		var rep: Dictionary = v.get("replace", {})
		for ln in lines:
			if rep.has(String(ln.get("id", ""))):
				ln["text"] = rep[String(ln.id)]
		for ap in v.get("append", []):
			if typeof(ap) == TYPE_DICTIONARY:
				lines.append(ap.duplicate(true))
	var vars := {"addr": "", "lisle": "señor Lisle"}
	var out: Array = []
	for ln in lines:
		if not Cond.eval(ln.get("when", {}), ctx):
			continue
		if String(ln.get("gen", "")) == "acts_by_channel":
			out.append_array(_gen_acts(st, repo, ln))
		elif ln.has("text"):
			out.append({"id": String(ln.get("id", "")), "who": String(ln.get("who", "")), "text": _fill(repo, String(ln.text), vars)})
	return out

# Dice una escena: registra sus líneas con el origen de la escena (scene.origin o "S.<id>"). Para W2-SIM.
static func play_scene(st, repo, scene_id: String) -> Array:
	var scn: Dictionary = repo.scene(scene_id)
	var org := String(scn.get("origin", ""))
	if org == "":
		org = "S." + scene_id
	var out: Array = []
	for ln in scene_lines(st, repo, scene_id):
		out.append(say_line(st, repo, String(ln.who), String(ln.text), {"origin": org, "scene": scene_id, "id": String(ln.id), "kind": "escena"}))
	return out

# ---------------- núcleo ----------------
static func _speak(st, repo, ch: String, kind: String, visible: Dictionary, phrase: String, special: String, ev: Dictionary, opts: Dictionary) -> Dictionary:
	var S := Deps.ensure(st)
	_introduce(st, repo, ch)
	var ldef := {}
	if special != "":
		ldef = _special_line(st, repo, ch, special, _special_sub(st, special, opts))
	if ldef.is_empty() and opts.has("fixed"):
		ldef = _fixed_line(repo, ch, opts.fixed)
	if ldef.is_empty():
		ldef = respond(st, repo, ch, visible)
		if special == "" and String(ldef.get("reaction", "")) != "":
			special = String(ldef.reaction)
	if kind == "ask" or kind == "assert":
		var bk := _budget_key(st, ch)
		S.dialogue.asked[bk] = int(S.dialogue.asked.get(bk, 0)) + 1
	ev["char"] = ch
	st.push_event(ev)
	# Claves extra con «_»: Director.sig las ignora (igual que day/slot/tk), así immediate() y on_public_event() emparejan
	# el mismo evento y no se observa dos veces (contadores de Ley 2, inmediatas sin una_vez_por como HB12).
	var imm_ev: Dictionary = ev.duplicate(true)
	imm_ev.merge({"day": Deps.day(st), "slot": Deps.slot(st), "tk": Deps.now_tk(st), "_reaction": special, "_visit": Deps.visit_key(st)}, true)
	var imm = Deps.director().immediate(st, repo, imm_ev)
	var meta := {"origin": Deps.origin(st, repo)}
	var out: Array = []
	if phrase != "":
		out.append(say_line(st, repo, "lisle", Markup.escape(phrase), {"origin": meta.origin, "kind": "frase", "to": ch}))
	var vars := _line_vars(st, repo, ch)
	var main := {}
	if ldef.is_empty():
		main = say_line(st, repo, ch, Markup.escape(Deps.txt(repo, "scenes.dlg.mudo", {}, "No contesta.")), {"origin": meta.origin, "kind": "respuesta"})
	else:
		main = say_line(st, repo, ch, _fill(repo, String(ldef.get("text", "")), vars), {"origin": meta.origin, "kind": "respuesta", "id": String(ldef.get("id", ""))})
		var effs = ldef.get("effects", [])
		if typeof(effs) == TYPE_ARRAY and not effs.is_empty():
			Deps.effects().apply(st, repo, {"iid": "LINE." + String(main.uid), "rid": "", "efecto": effs.duplicate(true), "char": ch,
				"line": String(ldef.get("id", "")), "anchor": {"phrase": phrase}, "tk": Deps.now_tk(st)}, false)
	out.append(main)
	if typeof(imm) == TYPE_ARRAY:
		for it in imm:
			var t := _imm_text(it)
			if t != "":
				var who := String(it.get("who", ch)) if typeof(it) == TYPE_DICTIONARY else ch
				out.append(say_line(st, repo, who, _fill(repo, t, vars), {"origin": meta.origin, "kind": "inmediata"}))
	var closing := false
	if (kind == "ask" or kind == "assert") and budget_left(st, repo, ch) <= 0:
		var ct := String(repo.dialogue(ch).get("closing", ""))
		if ct != "":
			out.append(say_line(st, repo, ch, _fill(repo, ct, vars), {"origin": meta.origin, "kind": "cierre"}))
			closing = true
	return {"ok": true, "line": main, "lines": out, "phrase": phrase, "outcome": special, "closing": closing}

static func _special_sub(st, special: String, opts: Dictionary) -> String:
	match special:
		"HB4":
			return "hb4.2" if int(Deps.flags(st).get("hb4_veces", 0)) >= 1 else "hb4.1"
		"HB12":
			return String(opts.get("sub", ""))
		"HB8":
			return "hb8"
		"M4":
			return "m4"
		"HB6":
			return "hb6"
	return ""

# Ids aceptados para un sub: el propio (hb12.ok…) y los que la reacción declara en sus efectos `linea {char, line,
# resultado?}` (reactions/*.json de W2-STRUCT: HB8 -> "vieja_tarifa", contrato §4.8 L:wiggins.vieja_tarifa; HB12 ->
# "hb12_exito" / "hb12_error_1" / "hb12_error_2" por `resultado`). Así sirve cualquiera de las dos convenciones.
static func _special_ids(repo, ch: String, special: String, sub: String) -> Array:
	var out: Array = []
	if sub != "":
		out.append(sub)
	var want := String(SUB_RESULT.get(sub, ""))
	var rule: Dictionary = repo.reaction(special) if special != "" else {}
	var effs = rule.get("efecto", [])
	if typeof(effs) != TYPE_ARRAY:
		return out
	for e in effs:
		if typeof(e) != TYPE_DICTIONARY or String(e.get("op", "")) != "linea" or String(e.get("char", "")) != ch:
			continue
		var res := String(e.get("resultado", ""))
		if res != "" and res != want:
			continue
		var lid := String(e.get("line", ""))
		if lid != "" and not out.has(lid):
			out.append(lid)
	return out

# Línea de respuesta especial: (1) id ∈ _special_ids(sub) (con o sin `reaction`); (2) sólo si el especial tiene un único
# sub o es el primero (hb4.1): una línea con reaction == special cuyo id no sea de ningún otro sub (nunca la del éxito
# para un error de HB12, ni el gesto de HB4 para la 2.ª vez); (3) ui_text scenes.<sub>; (4) {}.
static func _special_line(st, repo, ch: String, special: String, sub: String) -> Dictionary:
	var ctx := {"st": st, "repo": repo, "char": ch}
	var subs: Array = SUBS.get(special, [])
	var ids := _special_ids(repo, ch, special, sub)
	var known: Array = []
	for s in subs:
		for k in _special_ids(repo, ch, special, String(s)):
			if not known.has(k):
				known.append(k)
	var allow_generic := subs.size() <= 1 or (subs.size() > 0 and sub == String(subs[0]))
	var lines: Array = repo.dialogue(ch).get("lines", [])
	for want in ids:
		for ln in lines:
			if typeof(ln) == TYPE_DICTIONARY and String(ln.get("id", "")) == String(want) and Cond.eval(ln.get("when", {}), ctx):
				return _resp(ln)
	if allow_generic:
		for ln in lines:
			if typeof(ln) != TYPE_DICTIONARY or String(ln.get("reaction", "")) != special:
				continue
			if known.has(String(ln.get("id", ""))) or not Cond.eval(ln.get("when", {}), ctx):
				continue
			return _resp(ln)
	if sub != "" and Deps.has_txt(repo, "scenes." + sub):
		return {"id": sub, "layer": "especial", "text": String(repo.texts()["scenes." + sub]), "effects": [], "reaction": special}
	return {}

static func _fixed_line(repo, ch: String, fixed: Dictionary) -> Dictionary:
	for ln in repo.dialogue(ch).get("lines", []):
		if typeof(ln) == TYPE_DICTIONARY and String(ln.get("id", "")) == String(fixed.get("id", "")):
			return _resp(ln)
	var key := String(fixed.get("ui", ""))
	if key != "" and Deps.has_txt(repo, key):
		return {"id": String(fixed.get("id", "")), "layer": "fija", "text": String(repo.texts()[key]), "effects": [], "reaction": ""}
	return {}

static func _reserved(id: String) -> bool:
	return id.begins_with("conf.") or id.begins_with("tarea.") or id == "pago"

static func _resp(ln: Dictionary) -> Dictionary:
	var effs = ln.get("effects", [])
	return {"id": String(ln.get("id", "")), "layer": String(ln.get("layer", "")), "text": String(ln.get("text", "")),
		"effects": effs.duplicate(true) if typeof(effs) == TYPE_ARRAY else [], "reaction": String(ln.get("reaction", ""))}

static func _norm_visible(repo, visible: Dictionary) -> Dictionary:
	var ents := Deps.ent_ids(visible.get("ents", []))
	var topic := String(visible.get("topic", ""))
	var kinds: Array = []
	var k0 := String(visible.get("kind", ""))
	if k0 != "":
		kinds.append(k0)
	for e in ents:
		var k := String(repo.entity(e).get("kind", ""))
		if k != "" and not kinds.has(k):
			kinds.append(k)
	var docs: Array = []
	for d in visible.get("docs", visible.get("doc_ids", [])):
		if not docs.has(String(d)):
			docs.append(String(d))
	var asr_id := String(visible.get("assertion", ""))
	var asr_keys: Array = []
	if asr_id != "":
		asr_keys.append(asr_id)
		var asr := _assertion(repo, asr_id)
		for f in ["topic", "kind"]:
			if String(asr.get(f, "")) != "":
				asr_keys.append(String(asr[f]))
	var topics: Array = [topic] if topic != "" else ents.duplicate()
	var se := ents.duplicate()
	se.sort()
	var sd := docs.duplicate()
	sd.sort()
	return {"topics": topics, "ents": ents, "kinds": kinds, "docs": docs, "assertion": asr_keys,
		"key": "%s|%s|%s|%s" % [asr_id, topic, ",".join(PackedStringArray(se)), ",".join(PackedStringArray(sd))]}

static func _match(layer: String, m, v: Dictionary) -> bool:
	if typeof(m) != TYPE_DICTIONARY or m.is_empty():
		return false
	match layer:
		"afirmacion":
			return _inter(m.get("assertion", []), v.assertion)
		"tema":
			return _inter(m.get("topic", []), v.topics)
		"documento":
			return _inter(m.get("doc", []), v.docs)
		"entidad":
			return _inter(m.get("ent", []), v.ents)
		"tipo":
			return _inter(m.get("kind", []), v.kinds)
	return false

static func _inter(want, have: Array) -> bool:
	if typeof(want) == TYPE_STRING:
		want = [want]
	if typeof(want) != TYPE_ARRAY:
		return false
	for w in want:
		if have.has(String(w)):
			return true
	return false

# Propiedades visibles de un ítem presentado. Recorte: Clipper.visible (nunca get_clip). Pregunta: su texto, la
# respuesta (lápiz o tinta) y los orígenes de sus pruebas (GDD_v3 §6.10). {item_kind, ents, docs, origins, src_types,
# text?, answer?, ink?, q?}
static func _visible_item(st, repo, item: Dictionary) -> Dictionary:
	var id := String(item.get("id", ""))
	if String(item.get("kind", "")) == "pregunta":
		var qi := Deps.question_item(st, repo, id)
		if qi.is_empty():
			return {}
		var ans := String(qi.get("answer", ""))
		var ents: Array = [ans] if ans != "" and not repo.entity(ans).is_empty() else []
		var origins: Array = []
		for cid in Deps.question_proofs(st, id):
			var o := String(Deps.clipper().visible(st, cid).get("origin", ""))
			if o != "" and not origins.has(o):
				origins.append(o)
		var r := _docs_of(repo, origins, [])
		return {"item_kind": "pregunta", "ents": ents, "docs": r.docs, "origins": origins, "src_types": r.src_types,
			"answer": ans, "ink": "tinta" if bool(qi.get("inked", false)) else "lapiz", "q": id}
	var v: Dictionary = Deps.clipper().visible(st, id)
	if v.is_empty():
		return {}
	var ents2 := Deps.ent_ids(v.get("ents", []))
	var org := String(v.get("origin", ""))
	var r2 := _docs_of(repo, ([org] if org != "" else []) + Array(v.get("doc_ids", [])), ents2)
	return {"item_kind": "clip", "ents": ents2, "docs": r2.docs, "origins": [org] if org != "" else [], "src_types": r2.src_types,
		"text": String(v.get("text", ""))}

static func _docs_of(repo, origins: Array, ents: Array) -> Dictionary:
	var docs: Array = []
	var srcs: Array = []
	for o in origins:
		if not repo.doc(o).is_empty() and not docs.has(o):
			docs.append(o)
	for e in ents:
		var d := String(repo.entity(e).get("doc", ""))
		if d != "" and not docs.has(d):
			docs.append(d)
	for d in docs:
		var s := String(repo.doc(d).get("src_type", ""))
		if s != "" and not srcs.has(s):
			srcs.append(s)
	for o in origins:
		if String(o).begins_with("S.") and not srcs.has("escena"):
			srcs.append("escena")
	return {"docs": docs, "src_types": srcs}

# Ítem del evento público `show` (§3.6, sólo lo visible). Material secreto_camden: retenido (D10, T22).
static func _pub_item(repo, item: Dictionary, vis: Dictionary, camden: bool) -> Dictionary:
	var kind := String(item.get("kind", ""))
	if camden:
		return {"kind": kind, "withheld": true, "doc_ids": [], "ents": [], "origins": [], "src_types": []}
	var it := {"kind": kind, "doc_ids": vis.docs.duplicate(), "ents": _pub_ents(repo, vis.ents), "origins": vis.origins.duplicate(),
		"src_types": vis.src_types.duplicate()}
	if kind == "pregunta":
		var camden_ents: Array = repo.lists().get("camden_entities", [])
		it["q"] = String(vis.get("q", ""))
		it["answer"] = "" if camden_ents.has(String(vis.get("answer", ""))) else String(vis.get("answer", ""))
	return it

static func _pub_ents(repo, ents: Array) -> Array:
	var camden_ents: Array = repo.lists().get("camden_entities", [])
	var out: Array = []
	for e in ents:
		if not camden_ents.has(String(e)) and not out.has(String(e)):
			out.append(String(e))
	return out

# ---------------- especiales ----------------
static func _touches_group(repo, group: String, tokens: Array) -> bool:
	var g: Array = repo.lists().get("topic_groups", {}).get(group, [])
	for t in tokens:
		if g.has(String(t)):
			return true
	return false

# «Afirma que vive»: para alguna afirmación says_alive, su grupo de tema (o el tema) toca los tokens y sus requires
# están todos entre los tokens (p. ej. asiento T7 {persona: holmes, estado: vivo}).
static func _says_alive(repo, tokens: Array) -> bool:
	var groups: Dictionary = repo.lists().get("topic_groups", {})
	for asr in repo.lists().get("assertions", []):
		if typeof(asr) != TYPE_DICTIONARY or not bool(asr.get("says_alive", false)):
			continue
		var topic := String(asr.get("topic", ""))
		var g: Array = groups.get(topic, [topic])
		var hit := false
		for t in tokens:
			if g.has(String(t)):
				hit = true
		if not hit:
			continue
		var all_req := true
		for r in asr.get("requires", []):
			if not tokens.has(String(r)):
				all_req = false
		if all_req:
			return true
	return false

static func _hb8_open(st) -> bool:
	var f := Deps.flags(st)
	return Deps.day(st) >= 3 and not bool(f.get("wiggins_aliado", false)) and not bool(f.get("wiggins_quemado", false))

# HB12 (GDD §9.6, §12.1.4; GDD_v3 §6.10): éxito si es Q3 EN TINTA y vale sin pruebas de origen S.HC06;
# material secreto_camden = error sin leerlo; 1.er error tolerado; 2.º -> forasteros_cerrada (Mycroft se va).
static func _hb12(st, repo, item: Dictionary, camden: bool) -> Dictionary:
	var S := Deps.ensure(st)
	var M: Dictionary = S.mycroft
	M["presented"] = int(M.get("presented", 0)) + 1
	if bool(M.get("ok", false)):
		return {"sub": "", "outcome": ""}
	if not camden and String(item.get("kind", "")) == "pregunta" and _hb12_valid(st, repo, String(item.get("id", ""))):
		M["ok"] = true
		if String(Deps.flags(st).get("errata_ofrecida", "")) == "":
			st.flags["errata_ofrecida"] = "mycroft"
		return {"sub": "hb12.ok", "outcome": "HB12"}
	M["errors"] = int(M.get("errors", 0)) + 1
	if int(M.errors) >= 2:
		st.flags["forasteros_cerrada"] = true
		M["gone"] = true
		return {"sub": "hb12.err2", "outcome": "HB12_cerrada"}
	return {"sub": "hb12.err1", "outcome": "HB12_error"}

static func _hb12_valid(st, repo, qid: String) -> bool:
	if qid != HB12_QUESTION or not Deps.question_inked(st, qid):
		return false
	for clip_id in Deps.question_proofs(st, qid):
		if _from_hc06(st, clip_id):
			return false
	return bool(Deps.dossier().check(st, repo, qid, {"exclude_origins": [HB12_EXCLUDED_ORIGIN]}).get("ok", false))

# Recorte de origen S.HC06, o de una línea dicha (st.world.lines / st.scenes.lines) de la escena HC06.
static func _from_hc06(st, clip_id: String) -> bool:
	var c: Dictionary = Deps.clipper().get_clip(st, clip_id)
	if c.is_empty():
		c = Deps.clipper().visible(st, clip_id)
	if String(c.get("origin", "")) == HB12_EXCLUDED_ORIGIN or String(c.get("scene", "")) == HB12_EXCLUDED_SCENE:
		return true   # Clipper guarda `scene` de la línea dicha (también si se recortó desde el diario)
	var ref := String(c.get("view", ""))
	if ref == "" or not ["line", "diary"].has(String(c.get("src_kind", "line"))):
		return false
	var rec := Deps.line_record(st, ref)
	return String(rec.get("scene", "")) == HB12_EXCLUDED_SCENE or String(rec.get("origin", "")) == HB12_EXCLUDED_ORIGIN

# ---------------- «¿Dónde consigo…?» (GDD_v3 §5.2) ----------------
const DONDE_SCENE := "CRANE"   # scenes/CRANE.json (CRANE.intro): desde que Crane se presentó, el panel ofrece la lista

static func _donde_field(it: Dictionary, keys: Array, def = ""):
	for k in keys:
		if it.has(k) and it[k] != null:
			return it[k]
	return def

# ¿Ya se presentó Crane? (se dijo alguna línea de la escena CRANE).
static func crane_presented(st) -> bool:
	for src in [st.world.get("lines", {}) if typeof(st.world) == TYPE_DICTIONARY else {}, Deps.sc(st, "lines")]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		for uid in src:
			var r = src[uid]
			if typeof(r) == TYPE_DICTIONARY and String(r.get("scene", "")) == DONDE_SCENE:
				return true
	return false

static func _known(st, ent: String) -> bool:
	var k = st.world.get("known", {}) if typeof(st.world) == TYPE_DICTIONARY else {}
	return typeof(k) == TYPE_DICTIONARY and k.has(ent)

static func _donde_asked(st) -> Dictionary:
	var d = Deps.sc(st, "dialogue").get("donde", {})
	return d if typeof(d) == TYPE_DICTIONARY else {}

# Ítems ofrecidos ahora: [{id, phrase, asked}] en el orden del archivo, los ya preguntados al final (plegados en la UI).
static func donde_items(st, repo, char_id: String) -> Array:
	if not crane_presented(st):
		return []
	var asked := _donde_asked(st)
	var fresh: Array = []
	var old: Array = []
	for it in repo.dialogue(char_id).get("donde", []):
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var req = _donde_field(it, ["requiere", "requires"], [])
		var ok: bool = typeof(req) != TYPE_ARRAY or (req as Array).is_empty()
		if not ok:
			for e in req:
				if _known(st, String(e)):
					ok = true
					break
		if not ok:
			continue
		var row := {"id": String(it.get("id", "")), "phrase": String(_donde_field(it, ["frase", "phrase"], "")), "asked": asked.has(String(it.get("id", "")))}
		if row.asked:
			old.append(row)
		else:
			fresh.append(row)
	return fresh + old

static func _donde_item(repo, char_id: String, iid: String) -> Dictionary:
	for it in repo.dialogue(char_id).get("donde", []):
		if typeof(it) == TYPE_DICTIONARY and String(it.get("id", "")) == iid:
			return it
	return {}

# ask_donde {char, item}: Crane contesta en personaje (línea recortable); si el ítem revela un lugar que no estaba en el
# plano, entra con via "crane". Gratis, sin límite, sin evento público. -> {ok, line:{uid, who, text}, revealed: L | ""}
static func act_ask_donde(st, repo, a) -> Dictionary:
	var ch := String(a.get("char", ""))
	var iid := String(a.get("item", ""))
	if not Deps.chars_present(st).has(ch):
		return _err("no_esta")
	var offered := false
	for row in donde_items(st, repo, ch):
		if String(row.id) == iid:
			offered = true
	if not offered:
		return _err("no_existe")
	var it := _donde_item(repo, ch, iid)
	var text := String(_donde_field(it, ["texto", "text", "respuesta"], ""))
	var ctx := {"st": st, "repo": repo, "tk": Deps.now_tk(st)}
	for vv in _donde_field(it, ["variantes", "variants"], []):
		if typeof(vv) == TYPE_DICTIONARY and Cond.eval(vv.get("when", {}), ctx):
			text = String(_donde_field(vv, ["texto", "text"], text))
			break
	var S := Deps.ensure(st)
	if typeof(S.dialogue.get("donde")) != TYPE_DICTIONARY:
		S.dialogue["donde"] = {}
	if not S.dialogue.donde.has(iid):
		S.dialogue.donde[iid] = Deps.now_tk(st)
	var lines: Array = []
	if text.strip_edges() != "":
		lines.append(say_line(st, repo, ch, text, {"id": iid, "kind": "respuesta"}))
	var revealed := ""
	var rv = _donde_field(it, ["revela", "reveals"], null)
	if rv != null and String(rv) != "":
		var L0 := String(rv).get_slice(".", 0)
		var Rv = load("res://core/sim/reveal.gd")
		if Rv != null and bool(Rv.call("reveal", st, repo, L0, {"via": "crane", "ref": iid})):
			revealed = L0
	return {"ok": true, "line": lines[0] if not lines.is_empty() else {}, "lines": lines, "revealed": revealed}

# ---------------- utilidades ----------------
static func _check_char(st, repo, ch: String) -> String:
	if ch == "" or not Deps.chars_present(st).has(ch):
		return "no_esta"
	if ch == "mycroft" and bool(Deps.sc(st, "mycroft").get("gone", false)):
		return "no_esta"
	return ""

static func _budget_key(st, ch: String) -> String:
	return Deps.visit_key(st) + "|" + ch

static func _introduce(st, repo, ch: String) -> void:
	var S := Deps.ensure(st)
	if S.dialogue.introduced.has(ch):
		return
	S.dialogue.introduced[ch] = true
	if not repo.entity(ch).is_empty():
		Deps.index().add_entities(st, repo, [ch])

static func _assertion(repo, id: String) -> Dictionary:
	for asr in repo.lists().get("assertions", []):
		if typeof(asr) == TYPE_DICTIONARY and String(asr.get("id", "")) == id:
			return asr
	return {}

# Canal del personaje (sensor K-W -> "kw") contra assertion.channels; sin sensor o sin channels = libre.
static func _assert_channel_ok(repo, ch: String, asr: Dictionary) -> bool:
	var chans: Array = asr.get("channels", [])
	var sensor = repo.dialogue(ch).get("sensor", null)
	if chans.is_empty() or sensor == null or String(sensor) == "":
		return true
	return chans.has(String(sensor).replace("-", "").to_lower())

# st (opcional): si Lisle todavía no sabe quién es (ni en el índice —se presentó— ni `known`), el trato anónimo
# (addr_anon: playtest v3, «Perdone, Mrs. Hudson…» con el panel llamándola «Casera con cofia»).
static func _addr(repo, ch: String, st = null) -> String:
	var dl: Dictionary = repo.dialogue(ch)
	var a := String(dl.get("addr", ""))
	var anon := String(dl.get("addr_anon", ""))
	if st != null and anon != "" and not bool(dl.get("known", false)) and not Deps.index().has(st, ch):
		return anon
	return a if a != "" else Deps.txt(repo, "scenes.addr", {}, "señor")

static func _raw(repo, key: String, def: String) -> String:
	return String(repo.texts().get(key, def)) if repo.has_method("texts") else def

static func _fill(repo, tpl: String, vars: Dictionary) -> String:
	return Deps.fill(repo, tpl, vars)

static func _seed(st) -> int:
	return int(st.seed) if st != null and st.get("seed") != null else 0

static func _line_vars(st, repo, ch: String) -> Dictionary:
	var v := {"addr": _addr(repo, ch), "fecha": _date_label(repo, Deps.day(st))}
	# HB4 2.ª: la consulta queda cerrada dos días (Effects la cierra recién al amanecer siguiente, voz A): reabre el día
	# después de `consulta_cerrada_hasta` (o de hoy + 2 si aún no se escribió); el domingo la consulta no atiende.
	var hasta = Deps.flags(st).get("consulta_cerrada_hasta", null)
	var until := Deps.day(st) + 2
	if hasta != null and int(hasta) >= Deps.day(st):
		until = int(hasta)
	var d := until + 1
	while d < 11 and Cond.wd_norm(String(Deps.day_row(repo, d).get("weekday", ""))) == "dom":
		d += 1
	v["reabre"] = Deps.weekday_name(repo, d)
	return v

static func _date_label(repo, d: int) -> String:
	var date := String(Deps.day_row(repo, d).get("date", ""))
	var dom := int(date.get_slice("-", 2)) if date.count("-") == 2 else 0
	var wd := Deps.weekday_name(repo, d)
	return "%s %d" % [wd, dom] if dom > 0 else wd

static func _imm_text(it) -> String:
	if typeof(it) == TYPE_STRING:
		return String(it)
	if typeof(it) != TYPE_DICTIONARY:
		return ""
	var ln = it.get("line", "")
	if typeof(ln) == TYPE_DICTIONARY:
		return String(ln.get("text", ""))
	return String(ln) if ln != null else ""

static func _err(code: String) -> Dictionary:
	return {"ok": false, "err": code}

# ---------------- gen acts_by_channel (HC06 (b)) ----------------
static func _gen_acts(st, repo, ln: Dictionary) -> Array:
	var tpl = ln.get("tpl", {})
	var out: Array = []
	if typeof(tpl) == TYPE_DICTIONARY:
		for ch in CHANNELS:
			if not tpl.has(ch):
				continue
			var ev := _first_act(st, repo, ch)
			if ev.is_empty():
				continue
			var act := String(ev.get("act", "act.%d" % int(ev.get("seq", 0))))
			var text := _bind_act(_fill(repo, String(tpl[ch]), _ev_vars(repo, ev)), act)
			out.append({"id": "%s_%s" % [String(ln.get("id", "")), ch], "who": String(ln.get("who", "")), "text": text, "act": act})
	if out.is_empty() and ln.has("fallback"):
		out.append({"id": String(ln.get("id", "")), "who": String(ln.get("who", "")), "text": _fill(repo, String(ln.fallback), {})})
	return out

static func _bind_act(text: String, act: String) -> String:
	return text.replace("[[@act|", "[[" + act + "|").replace("[[@act]]", "[[" + act + "]]")

static func _first_act(st, repo, ch: String) -> Dictionary:
	var evs = st.events if typeof(st.events) == TYPE_ARRAY else []
	for ev in evs:
		if typeof(ev) == TYPE_DICTIONARY and _ev_channels(repo, ev).has(ch):
			return ev
	return {}

# Canales que observan un evento público (aproximación de lists.sensors para citar actos; la ceguera la impone react/).
static func _ev_channels(repo, ev: Dictionary) -> Array:
	var out: Array = []
	var sens: Dictionary = repo.lists().get("sensors", {})
	match String(ev.get("type", "")):
		"slip":
			out.append("kbm")
		"ad":
			out.append("kt")
		"go":
			if String(ev.get("place", "")) == "L3" and L3_INTERIOR.has(String(ev.get("area", ""))):
				out.append("kh")
			if int(ev.get("day", 0)) >= 3:
				out.append("ks")
		"say", "show":
			var toks: Array = []
			if String(ev.get("topic", "")) != "":
				toks.append(String(ev.topic))
			toks.append_array(Deps.ent_ids(ev.get("ents", [])))
			var item = ev.get("item", {})
			if typeof(item) == TYPE_DICTIONARY:
				toks.append_array(Deps.ent_ids(item.get("ents", [])))
			var who := String(ev.get("char", ""))
			if who == "watson" and _toks_in_sensor(repo, sens.get("K-W", {}), toks):
				out.append("kw")
			if who == "mrs_hudson" and _toks_in_sensor(repo, sens.get("K-H", {}), toks):
				out.append("kh")
	return out

static func _toks_in_sensor(repo, s, toks: Array) -> bool:
	if typeof(s) != TYPE_DICTIONARY:
		return false
	for g in s.get("topics", []):
		if _touches_group(repo, String(g), toks):
			return true
	return false

static func _ev_vars(repo, ev: Dictionary) -> Dictionary:
	var streets = ev.get("streets", [])
	var d := int(ev.get("day", 0))
	return {"seat": ev.get("seat", ""), "title": String(ev.get("title", "")), "titulo": String(ev.get("title", "")),
		"hour": String(ev.get("hour", "")), "phrase": String(ev.get("phrase", "")), "frase": String(ev.get("phrase", "")),
		"streets": Deps.join_and(repo, streets) if typeof(streets) == TYPE_ARRAY else String(streets), "text": String(ev.get("text", "")),
		"texto": String(ev.get("text", "")), "act_day": d, "fecha": _date_label(repo, d),
		"franja": Deps.txt(repo, "scenes.slot." + String(ev.get("slot", "")), {}, String(ev.get("slot", "")))}
