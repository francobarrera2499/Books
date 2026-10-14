# devtools/bots/bot_base.gd — motor común de los bots (ARCHITECTURE §9.3, GDD §15.5 T10/T24; GDD_v3 §1.9, §2.4).
# Contrato §9.3: sim, seed, stats; setup(sim, seed) · step() -> bool (una decisión, ≥1 apply; false = terminó) ·
#   play(max_steps) -> {ending, rank, inked, words_read, est_minutes, acts, steps, …} · act(a) (sim.apply + estadística;
#   un ok:false es fallo del bot salvo en bots «al azar» o en intentos marcados may_fail) · read(view) (palabras leídas) ·
#   clip_ref(ref) (oráculo: recorta el fragmento de contrato §4.8 desde su ejemplar).
# Juega SÓLO por GameSim.apply (la puerta de §3.1); lee con q_* y, como oráculo, con core/graph (RouteDB, Feasibility),
#   Dossier.check (para no pasar en limpio a ciegas) y el estado interno de recortes (Clipper.get_clip) — los bots que
#   modelan a un jugador honesto (pesca, fuerza bruta, sabelotodo) no usan las etiquetas ocultas para elegir.
# Motor (lo heredan todos; cada bot cambia la política con los ganchos «pol_*»):
#   prólogo  : tutorial (abrir el expediente y leer el encargo, recortar, aviso de testigos, dormir); día 1 guiado
#              (GDD_v3 §6.9): leer «El problema final», una hoja con respuesta y dos pruebas, pasar en limpio.
#   objetivos: Feasibility.plan (rutas ★ elegibles, mínimo de salidas) desde 1.M → targets {pregunta: ruta} + itinerario
#              {idx: (lugar, área)}; replanifica si una salida no se pudo hacer o faltan fragmentos.
#   cosecha  : en cada paso recorta todo fragmento pendiente obtenible AHORA (documentos legibles, láminas archivadas,
#              la buhardilla, siluetas, líneas dichas, diario, rastros entregados, avisos impresos). En la Sala de Lectura
#              pide papeletas (≤3) de lo que falta; baja a la tienda de Crane (gratis) si hay ejemplares de Crane pendientes.
#   hojas    : con los dos fragmentos de la ruta y la pregunta abierta, escribe la respuesta (oráculo: una respuesta
#              válida que esté en el índice) y las dos pruebas, verifica con Dossier.check y pasa en limpio (dq_confirm;
#              sin límite de intentos, GDD_v3 §1.6). Intrusiones: examina lo que cambió en la pieza (nace Q8).
#   confrontación: con conf_cover (deductor), además un recorte por grupo refutador de fuentes gratuitas (_conf_plan).
#   oráculo   : stats.oracle registra rutas ★ planificadas cuyos fragmentos no se pudieron obtener en su ventana.
#   informes, confrontación, Mycroft, noche y epílogo: ganchos.
# Estadística (stats): acts, steps, errors (ok:false inesperados), words_read, words_by_day, est_minutes,
#   est_minutes_act {I, II, III}, confirms, confirms_inked, inked, outings, blocked (novato), oracle (fallas del oráculo),
#   ending, rank, franjas (= salidas con costo), verbs {t: {free, costly}}, places {L.área: n}, runaway, attempts {q: n}.
#   log: [{t, ok, err, tk, day, slot, phase, free, costly, taught, place?, area?, char?, form?, mode?, silent?, q?}] (T24).
# Salvaguardas (carga del PC): MAX_ACTS_PER_STEP apply por paso y budget_ms de reloj por partida; si se exceden, la
#   partida se corta con stats.errors «runaway: …» y result().runaway (los tests lo exigen vacío).
extends RefCounted

const J = preload("res://core/util/j.gd")
const Det = preload("res://core/util/det.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const Av = preload("res://core/graph/availability.gd")
const Feasibility = preload("res://core/graph/feasibility.gd")
const Validator = preload("res://core/deduction/validator.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const Index = preload("res://core/deduction/index.gd")
const MoranAgent = preload("res://core/react/moran_agent.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Confrontation = preload("res://core/scenes/confrontation.gd")
const Deps = preload("res://core/scenes/deps.gd")
const Composers = preload("res://core/scenes/composers.gd")
const Actions = preload("res://core/sim/actions.gd")
const Clock = preload("res://core/sim/clock.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

const WPM := 180.0
const REREAD := 1.3
const SEAT := 214
const HUB := "L1"
const SHOP := "tienda"
# Verbos con contexto gratuito propio (T24): su primer uso con costo debe ir precedido de un uso gratis.
const FREE_TWIN := {"ask": "ask", "assert": "assert", "present": "present", "go": "go"}
const COSTLY := ["slip", "order_copy", "compose_ad", "compose_telegram", "compose_letter", "report_submit",
	"confront", "night_choice", "publish_errata", "end_slot"]
const TALK := ["ask", "assert", "present", "pay", "task"]
const CONF_GROUPS = Confrontation.GROUPS   # grupos refutadores de las cuatro afirmaciones (W2-SCENES)
# Tramos de la partida (GDD §7.7): prólogo, actos I–III, epílogo (minutos del novato por tramo).
const ACTS := {"P": [0, 0], "I": [1, 4], "II": [5, 7], "III": [8, 10], "E": [11, 11]}
# Modelo de tiempo de juego (W4-BALANCE; supuestos, no mediciones): minutos por acto ACEPTADO, más 3 min de deliberación
# por conclusión sellada ese día. play_minutes = lectura (palabras/WPM × REREAD) + interacción + deliberación.
const T_ACT := {"go_costly": 1.0, "go_free": 0.5, "clip": 0.3, "dq_answer": 0.3, "dq_proof": 0.3, "dq_confirm": 0.7,
	"examine": 0.2, "ask_donde": 0.3, "slip": 0.5, "ask": 0.4, "assert": 0.4,
	"present": 0.4, "pay": 0.2, "task": 0.3, "compose_ad": 1.5, "compose_telegram": 1.5, "compose_letter": 1.5,
	"report_submit": 1.5, "confront": 1.0, "night_choice": 0.5, "publish_errata": 0.5}
const T_THINK_PER_SEAL := 3.0
# Peso de las palabras de la línea física en el modelo de lectura (0 = no cuenta, 1 = como el texto). Ver _read_parsed.
const PACE_FISICA := 1.0

var sim
var repo
var seed: int = 0
var stats := {}
var bot_name := "base"
var random_bot := false      # bots al azar: un ok:false no es fallo
var only_taught := false     # novato: sólo verbos ya enseñados (Tutorial.verbs_taught)
var reads_all := false       # novato: lee todo lo legible en cada paso
var emit_reads := false      # novato: cada hoja que lee por primera vez emite la acción libre `read` (GDD_v2 §B.4)
var _read_emitted := {}
var deduce := true           # junta fragmentos y escribe hojas (pasivo: false)
var focus: Array = []        # preguntas objetivo ([] = todas las obligatorias nacidas)
var fillers := false         # (v3: sin lotes; se conserva por compatibilidad de los bots viejos)
var idle_until_day := 0      # > 1: los días 1..idle_until_day-1 sólo pasa franjas, duerme e informa «nada» (sondas del oráculo)
var value_mode := "oracle"   # respuesta de las hojas: "oracle" (respuestas válidas) | "random" (pesca: opción al azar)
var max_attempts := 0        # > 0: tope de dq_confirm por pregunta (bots al azar de T10, GDD_v3 §1.9)
var log: Array = []
var rnd_n := 0               # contador de sorteos (Det con la semilla del bot)
var attempt := {}            # qid -> nº de intentos de dq_confirm
var waits := {}              # qid -> motivo transitorio por el que todavía no hay hoja
var replan_next := false     # replanificar en el próximo escritorio (se salteó una salida del itinerario)
var seen_clips := {}         # recortes legales máximos ya hechos (fuerza_bruta, recorta_todo)

var targets := {}            # qid -> {rid, frags:[{ref, copy, key, desc, want:[]}]}
var itinerary := {}          # idx -> {place, area, refs}
var clip_of := {}            # key de fragmento -> id de recorte
var sheet_of := {}           # qid -> {answer, proofs} escritos por el bot (a lápiz)
var bad_sheet := {}          # qid -> motivo (oráculo no pudo armar una hoja que cierre)
var read_sig := {}
var _slot_flags := {}        # "<tk>|<qué>" -> true (una vez por franja)
var _planned := false
var _no_progress := 0
# Material de la confrontación (GDD §8.8; errata a medida): con conf_cover, el oráculo junta además, de fuentes GRATUITAS
# (lo legible, la tienda de Crane, láminas, líneas), un recorte por afirmación cuyo grupo refutador no cubra ya lo que
# tiene (la ruta ★ elegida para C12 puede no traer «librero_falso» antes del día 10). Sin papeletas extra (K-BM).
var conf_cover := false
var conf_frags: Array = []   # [{…frag, grp:n}] candidatos (fragmentos de rutas de cualquier conclusión con a: del grupo)
var _conf_ok := {}           # n -> id del recorte/asiento que ya refuta la afirmación n
var _conf_fail := {}         # key -> intentos fallidos con la fuente legible (tope 3)
# Salvaguardas contra bucles (carga del PC): tope de apply por paso y presupuesto de reloj por partida (devtools, no core;
# el reloj sólo corta, no decide nada del juego). budget_ms <= 0 = sin presupuesto.
const MAX_ACTS_PER_STEP := 3000
var budget_ms := 120000
var _step_acts := 0
var _runaway := ""
var _t0 := 0
var apply_us := 0            # tiempo dentro de sim.apply (perfil; no entra en el resultado canónico)
var play_ms := 0

# ======================================================================= contrato §9.3
func setup(p_sim, p_seed: int) -> void:
	sim = p_sim
	repo = p_sim.repo
	seed = p_seed
	stats = {"bot": bot_name, "seed": p_seed, "acts": 0, "ok_acts": 0, "steps": 0, "errors": [], "words_read": 0, "words_by_day": {},
		"confirms": 0, "confirms_inked": 0, "inked": [], "outings": 0, "blocked": {}, "oracle": [], "reports": [],
		"confront": [], "mycroft": []}
	log = []
	_init_bot()

func play(max_steps := 20000) -> Dictionary:
	var n := 0
	_t0 = Time.get_ticks_msec()
	while n < max_steps:
		n += 1
		if not step():
			break
		if budget_ms > 0 and Time.get_ticks_msec() - _t0 > budget_ms:
			_runaway = "presupuesto de %d ms agotado en el paso %d" % [budget_ms, n]
			_err("runaway: " + _runaway)
			break
	play_ms = Time.get_ticks_msec() - _t0
	return result()

func step() -> bool:
	if _runaway != "":
		return false
	stats.steps = int(stats.steps) + 1
	_step_acts = 0
	var c: Dictionary = sim.q_clock()
	var ph := String(c.phase)
	if ph == "done":
		return false
	var before := int(stats.ok_acts)
	if idle_until_day > 1 and ph != "prologue" and int(c.day) >= 1 and int(c.day) < idle_until_day and _idle_step(ph):
		return String(sim.q_clock().phase) != "done"
	# el novato también lee el día 10 y el epílogo (la confrontación, Park Lane, la elección de la noche, el epílogo)
	var late_phase := ["confront", "final_report", "parklane", "night_choice", "epilogue"].has(ph)
	if reads_all and late_phase:
		_read_late()
	match ph:
		"prologue":
			_do_prologue()
		"desk":
			_do_desk()
		"visit":
			_do_visit()
		"scene":
			_do_scene()
		"night":
			_do_night()
		"confront":
			_do_confront()
		"final_report":
			_do_final_report()
		"parklane":
			_harvest()
			act({"t": "leave"})
		"night_choice":
			act({"t": "night_choice", "where": pol_night_choice()})
		"epilogue":
			if not bool(sim.st.clock.get("errata_decided", false)):
				act({"t": "publish_errata", "yes": pol_publish_errata()})
			else:
				act({"t": "leave"})
		_:
			_err("fase desconocida " + ph)
			return false
	if reads_all and late_phase:
		_read_late()
	if _runaway != "":
		return false
	# salvaguarda: pasos seguidos sin ningún apply aceptado no pueden repetirse sin fin
	if int(stats.ok_acts) == before:
		_no_progress += 1
		if _no_progress > 3:
			_err("sin progreso en %s (%s)" % [ph, String(c.get("date_label", ""))])
			return false
	else:
		_no_progress = 0
	return String(sim.q_clock().phase) != "done"

# idle_until_day: el jugador que deja pasar los primeros días (sólo fin de franja, dormir e informes vacíos).
func _idle_step(ph: String) -> bool:
	match ph:
		"desk":
			act({"t": "end_slot"})
		"visit", "scene", "parklane":
			act({"t": "leave"})
		"night":
			if bool(sim.q_report_status().get("due", false)):
				act({"t": "report_submit", "mode": "nada", "items": []})
			else:
				act({"t": "sleep"})
		_:
			return false
	return true

func _read_late() -> void:
	_read_all()
	var cs: Dictionary = sim.q_confront()
	var stmt = cs.get("statement", {})
	if typeof(stmt) == TYPE_DICTIONARY and String(stmt.get("text", "")) != "":
		_read_parsed("conf|" + String(stmt.get("uid", "")), repo.parse_text(String(stmt.text), {}, String(stmt.get("act", ""))))

func act(a: Dictionary, may_fail := false) -> Dictionary:
	var t := String(a.get("t", ""))
	if _runaway != "":
		return {"ok": false, "err": "bot_runaway"}
	_step_acts += 1
	if _step_acts > MAX_ACTS_PER_STEP:
		_runaway = "más de %d apply en un paso (último: %s)" % [MAX_ACTS_PER_STEP, J.stringify_canon(a).left(200)]
		_err("runaway: " + _runaway)
		return {"ok": false, "err": "bot_runaway"}
	var c: Dictionary = sim.q_clock()
	var taught := _taught(t)
	if only_taught and String(c.phase) != "prologue" and not taught:
		stats.blocked[t] = int(stats.blocked.get(t, 0)) + 1
		return {"ok": false, "err": "no_ensenado", "skipped": true}
	var free := _free_use(a, c)
	var t_us := Time.get_ticks_usec()
	var r: Dictionary = sim.apply(a)
	apply_us += Time.get_ticks_usec() - t_us
	stats.acts = int(stats.acts) + 1
	var ok := bool(r.get("ok", false))
	if ok:
		stats.ok_acts = int(stats.ok_acts) + 1
	var le := {"t": t, "ok": ok, "err": String(r.get("err", "")), "tk": int(c.tk), "day": int(c.day), "slot": String(c.slot),
		"phase": String(c.phase), "free": free, "costly": _costly(a, c, free), "taught": taught}
	for k in ["place", "area", "char", "form", "mode", "q"]:
		if a.has(k):
			le[k] = String(a[k])
	if t == "confront":
		le["silent"] = (a.get("item", {}) as Dictionary).is_empty()
	log.append(le)
	if not ok and not may_fail and not random_bot:
		_err("%s -> %s (fase %s, %s)" % [J.stringify_canon(a), String(r.get("err", "")), c.phase, c.get("date_label", "")])
	if ok and t == "go" and not free:
		stats.outings = int(stats.outings) + 1
	if ok and t == "dq_confirm":
		stats.confirms = int(stats.confirms) + 1
		var qk := String(a.get("q", ""))
		attempt[qk] = int(attempt.get(qk, 0)) + 1
		if bool(r.get("inked", false)):
			stats.confirms_inked = int(stats.confirms_inked) + 1
	return r

func read(view: String) -> void:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for b in pages[pi]:
			_read_parsed(String(view) + "|" + String(b.get("doc", "")) + "|" + String(b.get("part", "")), b.get("parsed", {}))
		if emit_reads and not _read_emitted.has(view + "|" + str(pi)):
			_read_emitted[view + "|" + str(pi)] = true
			act({"t": "read", "view": view, "part": pi}, true)

func clip_ref(ref: String) -> String:
	var f := _frag(ref, "")
	return _try_frag(f)

func result() -> Dictionary:
	var en: Dictionary = sim.q_ending()
	if en.is_empty():
		en = load("res://core/sim/endings.gd").evaluate(sim.st, repo)
	var sealed: Array = Dossier.inked(sim.st).keys()
	sealed.sort()
	stats["inked"] = sealed
	stats["ending"] = String(en.get("ending", ""))
	stats["rank"] = int(en.get("rank", 0))
	stats["variants"] = (en.get("variants", []) as Array).map(func(v): return String(v.get("id", "")))
	var words := 0
	var by_act := {}
	for a0 in ACTS:
		by_act[a0] = 0
	for dk in stats.words_by_day:
		var d := int(dk)
		words += int(stats.words_by_day[dk])
		for a in ACTS:
			if d >= int(ACTS[a][0]) and d <= int(ACTS[a][1]):
				by_act[a] = int(by_act[a]) + int(stats.words_by_day[dk])
	stats["words_read"] = words
	stats["est_minutes"] = snappedf(words / WPM * REREAD, 0.1)
	var em := {}
	for a in by_act:
		em[a] = snappedf(int(by_act[a]) / WPM * REREAD, 0.1)
	stats["est_minutes_act"] = em
	# minutos de juego por tramo: lectura + interacción (T_ACT por acto aceptado) + deliberación (T_THINK_PER_SEAL)
	var pm := {}
	for a in ACTS:
		pm[a] = float(em.get(a, 0.0))
	for e in log:
		if not bool(e.ok):
			continue
		var t0 := String(e.t)
		var cat := t0
		if t0 == "go":
			cat = "go_costly" if bool(e.get("costly", false)) else "go_free"
		elif t0.begins_with("clip_"):
			cat = "clip"
		var ak := _act_of_day(int(e.day))
		if ak != "":
			pm[ak] = float(pm[ak]) + float(T_ACT.get(cat, 0.0))
	for qk in Dossier.inked(sim.st):
		var ak2 := _act_of_day(TimeKey.day_of(int(Dossier.inked(sim.st)[qk].get("tk", 0))))
		if ak2 != "":
			pm[ak2] = float(pm[ak2]) + T_THINK_PER_SEAL
	var pm_total := 0.0
	for a in pm:
		pm[a] = snappedf(float(pm[a]), 0.1)
		pm_total += float(pm[a])
	stats["play_minutes_act"] = pm
	stats["play_minutes"] = snappedf(pm_total, 0.1)
	stats["phase"] = String(sim.q_clock().phase)
	stats["flags"] = {"moran_credito": bool(sim.st.flags.get("moran_credito", false)), "holmes_entregado": bool(sim.st.flags.get("holmes_entregado", false)),
		"watson_expuesto": bool(sim.st.flags.get("watson_expuesto", false)), "errata_ofrecida": String(sim.st.flags.get("errata_ofrecida", "")),
		"informe_final": String(sim.st.flags.get("informe_final", "")), "confront_estado": String(sim.st.flags.get("confront_estado", "")),
		"moran_credito_perdido": bool(sim.st.flags.get("moran_credito_perdido", false))}
	# obligatorias sin tinta y por qué (para el informe del bot; sólo los bots que deducen)
	var unsealed := {}
	if deduce:
		for cid in RouteDB.mandatory(repo):
			var c := String(cid)
			if sealed.has(c):
				continue
			if bad_sheet.has(c):
				unsealed[c] = "hoja inválida: " + String(bad_sheet[c]).left(160)
			elif not Dossier.is_born(sim.st, c):
				unsealed[c] = "no nació"
			elif not Dossier.is_open(sim.st, c):
				unsealed[c] = "en espera (tope de abiertas)"
			elif waits.has(c):
				unsealed[c] = String(waits[c])
			elif targets.has(c):
				var miss: Array = []
				for f in targets[c].frags:
					if not clip_of.has(f.key):
						miss.append(String(f.ref))
				unsealed[c] = "%s: faltan %s" % [targets[c].rid, str(miss)]
				# el plan (Feasibility) daba la ruta ★ por obtenible y su ventana ya pasó: falla del oráculo (contenido,
				# disponibilidad o sim; p. ej. un nodo de diorama que ninguna lámina de la partida llega a mostrar)
				if not miss.is_empty() and value_mode == "oracle" and (String(sim.q_clock().phase) == "done" or _idx() > RouteDB.last_idx(repo, c)):
					_oracle("%s (%s): fragmentos de la ruta ★ planificada no obtenibles en su ventana: %s" % [c, targets[c].rid, str(miss)])
			else:
				unsealed[c] = "sin ruta"
	stats["unsealed"] = unsealed
	# verbos usados (ok): {t: {free, costly}} y salidas con costo por lugar
	var verbs := {}
	var places := {}
	for e in log:
		if not bool(e.ok):
			continue
		var t := String(e.t)
		if not verbs.has(t):
			verbs[t] = {"free": 0, "costly": 0}
		verbs[t]["costly" if bool(e.costly) else "free"] += 1
		if t == "go" and bool(e.costly):
			var pk := String(e.get("place", "")) + "." + String(e.get("area", ""))
			places[pk] = int(places.get(pk, 0)) + 1
	stats["verbs"] = verbs
	stats["franjas"] = int(stats.outings)   # franjas gastadas en salidas con costo (§9.3)
	return {"bot": bot_name, "seed": seed, "ending": stats.ending, "rank": stats.rank, "inked": sealed, "sealed": sealed, "words_read": words,
		"verbs": verbs, "places": places, "ads": int(stats.get("ads", 0)),
		"est_minutes": stats.est_minutes, "est_minutes_act": em, "play_minutes": stats.play_minutes, "play_minutes_act": stats.play_minutes_act,
		"acts": stats.acts, "steps": stats.steps,
		"outings": stats.outings, "franjas": stats.franjas, "confirms": stats.confirms, "confirms_inked": stats.confirms_inked,
		"attempts": attempt.duplicate(), "born": Dossier.inked(sim.st).keys() + _born_open(), "errors": stats.errors.duplicate(),
		"oracle": stats.oracle.duplicate(), "flags": stats.flags, "variants": stats.variants, "phase": stats.phase,
		"blocked": stats.blocked.duplicate(), "reports": stats.reports.duplicate(), "confront": stats.confront.duplicate(),
		"mycroft": stats.mycroft.duplicate(), "unsealed": unsealed, "runaway": _runaway}

func _born_open() -> Array:
	var out: Array = []
	var d = sim.st.ded.get("dossier", {})
	for q in (d.get("born", {}) as Dictionary).keys():
		if not Dossier.inked(sim.st).has(q):
			out.append(String(q))
	out.sort()
	return out

func _act_of_day(d: int) -> String:
	for a in ACTS:
		if d >= int(ACTS[a][0]) and d <= int(ACTS[a][1]):
			return String(a)
	return "E" if d > 10 else ""

# ======================================================================= ganchos de política
func _init_bot() -> void:
	pass

# Salida de esta franja (desk, sin salir aún): {place, area, seat?} o {} = quedarse.
func pol_outing() -> Dictionary:
	if not deduce:
		return {}
	var i := _idx()
	if itinerary.has(i):
		var u: Dictionary = itinerary[i]
		var p := String(u.place)
		var a := String(u.area)
		if p == "*":
			return _any_outing()
		return {"place": p, "area": a}
	return {}

# Algo extra que hacer en la visita (después de cosechar, antes de irse). Puede hacer varios apply.
func pol_in_visit() -> void:
	pass

# Informe n: {mode, items}. final = informe de las 12 h del día 10.
func pol_report(n: int, final: bool) -> Dictionary:
	return {"mode": "nada", "items": []}

# Ítem de la confrontación para la afirmación step ({} = callar).
func pol_confront(step_n: int) -> Dictionary:
	return {}

func pol_night_choice() -> String:
	return "casa"

func pol_publish_errata() -> bool:
	return false

func pol_values_mode() -> String:
	return value_mode

# Hojas a pasar en limpio ahora (preguntas abiertas). Por defecto: las hojas que el bot escribió y (oráculo) cierran.
func pol_confirm() -> Array:
	var out: Array = []
	for q in _sorted(sheet_of.keys()):
		if not Dossier.is_open(sim.st, String(q)):
			continue
		if max_attempts > 0 and int(attempt.get(q, 0)) >= max_attempts:
			continue
		if value_mode == "oracle" and not bool(Dossier.check(sim.st, repo, String(q)).get("ok", false)):
			continue
		out.append(String(q))
	return out

# Azar determinista con la semilla del bot (cada sorteo distinto).
func rnd_pick(arr: Array, tag := ""):
	rnd_n += 1
	return Det.pick(seed, [bot_name, tag, rnd_n], arr)

func rnd01(tag := "") -> float:
	rnd_n += 1
	return Det.rand01(seed, [bot_name, tag, rnd_n])

# ======================================================================= utilidades
func _err(msg: String) -> void:
	stats.errors.append(msg)

func _oracle(msg: String) -> void:
	if not stats.oracle.has(msg):
		stats.oracle.append(msg)

func _c() -> Dictionary:
	return sim.q_clock()

func _tk() -> int:
	return int(sim.q_clock().tk)

func _idx() -> int:
	var c: Dictionary = sim.q_clock()
	return TimeKey.idx(int(c.day), String(c.slot))

func _once(what: String) -> bool:
	var k := "%d|%s" % [_tk(), what]
	if _slot_flags.has(k):
		return false
	_slot_flags[k] = true
	return true

func _taught(t: String) -> bool:
	return (sim.q_tutorial().get("taught", []) as Array).has(t)

func _free_use(a: Dictionary, c: Dictionary) -> bool:
	var t := String(a.get("t", ""))
	if t == "go":
		return Clock.is_free(repo, String(a.get("place", "")), String(a.get("area", "")))
	if TALK.has(t):
		var v: Dictionary = sim.st.world.get("visit", {})
		return bool(v.get("free", false))
	return not COSTLY.has(t)

func _costly(a: Dictionary, c: Dictionary, free: bool) -> bool:
	var t := String(a.get("t", ""))
	if t == "go" or TALK.has(t):
		return not free
	return COSTLY.has(t)

func _words(parsed) -> int:
	if typeof(parsed) != TYPE_DICTIONARY:
		return 0
	var w = parsed.get("words", null)
	if typeof(w) == TYPE_ARRAY:
		return (w as Array).size()
	return Markup.words_of(String(parsed.get("plain", ""))).size()

# Firma por TEXTO, renglón por renglón (no por vista): el mismo documento leído en @tomo, @BM y @Crane cuenta una vez,
# y un aviso que el mundo inserta en una columna ya leída suma sólo su renglón (W4-BALANCE a). key queda por compatibilidad.
func _read_parsed(_key: String, parsed) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d := str(int(sim.q_clock().day))
	var plain := String(parsed.get("plain", ""))
	# GDD_v2 §C.5: la línea de descripción física (tramo #fisica, una línea de interfaz en todos los papeles por igual) se
	# mira de un vistazo: cuenta como palabras_fisica, aparte de la lectura (PACE_FISICA de peso).
	var fis: Array = []
	for tr in parsed.get("tramos", []):
		if String(tr.get("id", "")) == "fisica":
			fis.append([int(tr.from), int(tr.to)])
	var at := 0
	for ln in plain.split(String.chr(10)):
		var a0 := at
		at += String(ln).length() + 1
		var t := String(ln).strip_edges()
		if t == "":
			continue
		var sig := t.md5_text()
		if read_sig.has(sig):
			continue
		read_sig[sig] = true
		var n := Markup.words_of(t).size()
		var is_fis := false
		for f in fis:
			if a0 >= int(f[0]) - 1 and a0 + String(ln).length() <= int(f[1]) + 1:
				is_fis = true
		if is_fis:
			stats["words_fisica"] = int(stats.get("words_fisica", 0)) + n
			if not stats.has("words_fisica_by_day"):
				stats["words_fisica_by_day"] = {}
			stats.words_fisica_by_day[d] = int(stats.words_fisica_by_day.get(d, 0)) + n
			n = int(round(n * PACE_FISICA))
		stats.words_by_day[d] = int(stats.words_by_day.get(d, 0)) + n

# Lee todo lo legible ahora (documentos, líneas de la escena en curso y el examen de cada objeto del diorama).
func _read_all() -> void:
	for x in sim.q_accessible():
		read(String(x.view))
	var sc: Dictionary = sim.q_scene()
	for ln in sc.get("lines", []):
		_read_parsed("line|" + String(ln.uid), ln.get("parsed", {}))
	var snap: Dictionary = sim.q_visit_plate()
	if not snap.is_empty():
		for nid in (snap.get("nodes", []) as Array) + (snap.get("silhouettes", []) as Array):
			var n := String(nid)
			var ex := String(Clipper.node_def(sim.st, repo, snap, n).get("examine", ""))
			if ex != "":
				_read_parsed("node|" + String(snap.get("id", "")) + "|" + n, repo.parse_text(ex))

func _known(ent: String) -> bool:
	return Index.has(sim.st, ent)

func _any_outing() -> Dictionary:
	var c: Dictionary = _c()
	for pref in [["L3", "calle"], ["L2", "sala"], ["L5", "porteria"], ["L7", "exterior"]]:
		if Clock.place_open(repo, sim.st, pref[0], pref[1], int(c.day), String(c.slot)).open:
			return {"place": pref[0], "area": pref[1]}
	return {}

func _go(place: String, area: String) -> Dictionary:
	var a := {"t": "go", "place": place, "area": area}
	if WorldModel.place_needs_seat(repo, place):
		a["seat"] = SEAT
	return act(a, true)

# ======================================================================= prólogo (tutorial, GDD_v3 §6.9)
# Prólogo: abrir el expediente y leer el encargo (read), recortar (el aviso al pie y lo que pide el aviso de testigos), el
# aviso de testigos y dormir. El día 1 guiado (leer FINA, una hoja, pasar en limpio) va en _day1().
func _do_prologue() -> void:
	var tut: Dictionary = sim.q_tutorial()
	var sid := String(tut.step.get("id", "")) if typeof(tut.get("step")) == TYPE_DICTIONARY else ""
	if reads_all:
		_read_all()
	match sid:
		"read":
			_prologue_read()
		"clip":
			_prologue_clips()
		"ad":
			_prologue_ad()
		"sleep", "":
			act({"t": "sleep"})

# Abre el encargo (D23) o, si el dataset no lo tiene, el primer papel legible.
func _prologue_read() -> void:
	var first := ""
	for x in sim.q_accessible():
		if first == "":
			first = String(x.view)
		if String(x.doc) == "D23":
			first = String(x.view)
			break
	if first == "":
		_err("prólogo: nada legible para abrir")
		act({"t": "sleep"}, true)
		return
	act({"t": "read", "view": first, "part": 0})

# Recortes del prólogo: una oración del encargo (Pell pide el aviso al pie) y lo que pide el aviso de testigos.
func _prologue_clips() -> void:
	_ensure_testigo()
	if _clip_ids().is_empty():
		for x in sim.q_accessible():
			if String(x.doc) == "D23" and _clip_first_sentence(String(x.view)) != "":
				break
	if _clip_ids().is_empty():
		for x in sim.q_accessible():
			if _clip_first_sentence(String(x.view)) != "":
				break

# Día 1 guiado (GDD_v3 §6.9): 5 leer «El problema final» · 6 una hoja con respuesta y dos pruebas · 7 pasar en limpio.
# Una vez por franja; el deductor usa lo que tenga a mano (la hoja puede no cerrar: «Algo no cierra.»).
func _day1() -> void:
	var st1: Dictionary = sim.q_tutorial().get("day1", {})
	if st1.is_empty() or not _once("day1"):
		return
	# 5: leer FINA (cualquier ejemplar legible; el del cliente está en casa)
	if String(st1.get("id", "")) == "d1_leer":
		for x in sim.q_accessible():
			if String(x.doc) == "D03":
				_read_view_all(String(x.view))
				break
	st1 = sim.q_tutorial().get("day1", {})
	if String(st1.get("id", "")) == "d1_pruebas":
		_day1_sheet()
	st1 = sim.q_tutorial().get("day1", {})
	if String(st1.get("id", "")) == "d1_pasar":
		var q := _day1_question()
		if q != "":
			var r := act({"t": "dq_confirm", "q": q}, true)
			if bool(r.get("inked", false)):
				if not stats.inked.has(q):
					stats.inked.append(q)
				sheet_of.erase(q)
			else:
				pol_after_fail(q)   # la hoja de práctica no cerró: el plan la rearma con la ruta

# Emite `read` de todas las hojas de una vista (como el lector al hojearla).
func _read_view_all(view: String) -> void:
	var v: Dictionary = sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		act({"t": "read", "view": view, "part": pi}, true)

func _day1_question() -> String:
	var dv: Dictionary = sim.q_dossier()
	for h in dv.get("open", []):
		return String(h.id)
	return ""

# Una hoja completa: la pregunta abierta más antigua, una respuesta (oráculo si puede) y dos recortes de papeles distintos.
func _day1_sheet() -> void:
	var q := _day1_question()
	if q == "":
		return
	var ids := _clip_ids()
	if ids.size() < 2:
		for x in sim.q_accessible():
			if _clip_ids().size() >= 2:
				break
			_clip_first_sentence(String(x.view), _clip_ids())
		ids = _clip_ids()
	var pair := _two_origins(ids)
	if pair.size() < 2:
		for x in sim.q_accessible():
			_clip_first_sentence(String(x.view), _clip_ids())
			pair = _two_origins(_clip_ids())
			if pair.size() >= 2:
				break
	if pair.size() < 2:
		_err("día 1: no hay dos recortes de papeles distintos")
		return
	var opts: Array = sim.q_answer_options(q)
	if opts.is_empty():
		_err("día 1: %s no ofrece respuestas" % q)
		return
	var ans := String(opts[0].id)
	for v in _valid_answers(q):
		for o in opts:
			if String(o.id) == String(v):
				ans = String(v)
	_write_sheet(q, ans, pair[0], pair[1])

# Dos recortes de orígenes distintos (los primeros).
func _two_origins(ids: Array) -> Array:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var oa := String(Clipper.get_clip(sim.st, String(ids[i])).get("origin", ""))
			var ob := String(Clipper.get_clip(sim.st, String(ids[j])).get("origin", ""))
			if oa != ob:
				return [String(ids[i]), String(ids[j])]
	return []

# La forma «testigo» sólo ofrece sucesos indexados (R8): asegura uno recortando algo legible que lo nombre.
func _ensure_testigo() -> void:
	if not Composers.options(sim.st, repo, "testigo", "suceso").is_empty():
		return
	var form := {}
	for f in repo.lists().get("ad_forms", []):
		if String(f.get("id", "")) == "testigo":
			form = f
	for o in form.get("slots", {}).get("suceso", {}).get("options", []):
		if _ensure_indexed(String(o)):
			return

func _prologue_ad() -> void:
	_ensure_testigo()
	var opts := Composers.options(sim.st, repo, "testigo", "suceso")
	if opts.is_empty():
		_err("prólogo: la forma «testigo» no ofrece ningún suceso indexado (R8)")
		act({"t": "compose_ad", "form": "testigo", "fields": {}}, true)
		return
	act({"t": "compose_ad", "form": "testigo", "fields": {"suceso": String(opts[0].id)}})

# ======================================================================= escritorio
func _do_desk() -> void:
	if not _planned or ((replan_next or _overdue()) and _once("replan")):
		_planned = true
		replan_next = false
		if deduce:
			_replan()
	if reads_all:
		_read_all()
	if deduce:
		_harvest()
	if deduce or reads_all:
		_examine_intrusions()
	if deduce or value_mode != "oracle":
		_day1()
	if deduce:
		_build_sheets()
		_confirm_now()
	pol_desk_extra()
	if String(sim.q_clock().phase) != "desk":
		return
	# tienda de Crane (gratis): ejemplares de Crane pendientes
	if deduce and _crane_pending() and Clock.place_open(repo, sim.st, HUB, SHOP, int(_c().day), String(_c().slot)).open and _once("crane"):
		if bool(_go(HUB, SHOP).get("ok", false)):
			return
	# salida de la franja
	if not bool(_c().outing_done) and _once("outing"):
		var o := pol_outing()
		if not o.is_empty():
			if deduce and WorldModel.place_needs_seat(repo, String(o.place)):
				_prep_catalog()
			var r2 := _go(String(o.place), String(o.get("area", "")))
			if bool(r2.get("ok", false)):
				return
			_oracle("salida %s.%s rechazada en %s: %s" % [o.place, o.get("area", ""), _c().date_label + " " + String(_c().slot), r2.get("err", "")])
			if deduce:
				_replan()
	act({"t": "end_slot"})

# Gancho: algo más en el escritorio (avisos, cartas…). Puede hacer apply.
func pol_desk_extra() -> void:
	pass

# Pasa en limpio las hojas listas (pol_confirm). Sin límite de intentos (GDD_v3 §1.6).
func _confirm_now() -> void:
	for q in pol_confirm():
		var r := act({"t": "dq_confirm", "q": String(q)}, true)
		if bool(r.get("inked", false)):
			if not stats.inked.has(String(q)):
				stats.inked.append(String(q))
			sheet_of.erase(String(q))
		elif bool(r.get("ok", false)):
			pol_after_fail(String(q))

# Gancho: la hoja no cerró («Algo no cierra.»). Los bots sin oráculo prueban otra cosa.
func pol_after_fail(q: String) -> void:
	sheet_of.erase(q)

# Intrusiones (GDD_v3 §4.4): mira lo que cambió en la pieza (nodos con aviso) y busca el papel que falta.
func _examine_intrusions() -> void:
	if String(sim.q_clock().phase) != "desk":
		return
	var hub: Dictionary = sim.q_hub_plate()
	var defs: Dictionary = hub.get("node_defs", {}) if typeof(hub.get("node_defs")) == TYPE_DICTIONARY else {}
	for nid in hub.get("nodes", []):
		var nd = defs.get(String(nid), {})
		if typeof(nd) == TYPE_DICTIONARY and String(nd.get("aviso", "")) != "" and _once("examine|" + String(nid)):
			act({"t": "examine", "ref": "hub/" + String(nid)}, true)
	for m in sim.q_missing():
		if _once("missing|" + String(m.copy)):
			act({"t": "examine", "ref": "missing/" + String(m.copy)}, true)

# ¿Quedó atrás alguna salida del itinerario sin sus fragmentos? (se replanifica)
func _overdue() -> bool:
	if not deduce:
		return false
	var i := _idx()
	for k in itinerary:
		if int(k) < i:
			for ref in itinerary[k].get("refs", []):
				for f in _pending_targets():
					if String(f.ref) == String(ref):
						return true
	return false

# ======================================================================= visita
func _do_visit() -> void:
	var v: Dictionary = sim.st.world.get("visit", {})
	if reads_all:
		_read_all()
	if deduce:
		_slips()
		_harvest()
	pol_in_visit()
	if String(sim.q_clock().phase) != "visit":
		return
	if reads_all:
		_read_all()
	if deduce:
		_harvest()
	act({"t": "leave"})

# Papeletas de la Sala de Lectura: lo que falta de ejemplares BM, priorizando lo del itinerario. Como el jugador, sólo se
# pide lo que el catálogo muestra buscando una entidad del índice (R8; ui/desk/catalog.gd): lo que no, espera.
func _slips() -> void:
	var v: Dictionary = sim.st.world.get("visit", {})
	if v.is_empty() or not WorldModel.place_needs_seat(repo, String(v.get("place", ""))):
		return
	for did in _bm_wants(String(v.id)):
		if (sim.st.world.get("slips", {}).get(String(v.id), []) as Array).size() >= WorldModel.SLIPS_PER_VISIT:
			break
		if not _catalog_ok(did):
			stats["catalog_waits"] = int(stats.get("catalog_waits", 0)) + 1
			continue
		act({"t": "slip", "doc": did})

# Documentos BM pendientes de las rutas (sin pedir en esta visita, con su ejemplar en ventana ahora).
func _bm_wants(visit_id := "") -> Array:
	var used: Array = sim.st.world.get("slips", {}).get(visit_id, []) if visit_id != "" else []
	var want: Array = []
	for f in _pending():
		if f.desc.kind != "doc":
			continue
		var cp := String(f.copy)
		if cp == "" or not cp.ends_with("@BM"):
			continue
		var did := cp.get_slice("@", 0)
		if want.has(did) or used.has(cp) or not WorldModel.copy_available(sim.st, repo, cp, _tk()):
			continue
		want.append(did)
	return want

# ¿Se puede pedir por el catálogo? Un documento sin ficha de catálogo (sólo en datasets de fixtures: en data/ real todo
# ejemplar BM la tiene, T7) se pide directo.
func _catalog_ok(did: String) -> bool:
	return typeof(repo.doc(did).get("catalog")) != TYPE_DICTIONARY or _catalog_ent(did) != ""

# Entidad del índice cuya búsqueda en el catálogo lista el documento ("" si ninguna).
func _catalog_ent(did: String) -> String:
	for x in sim.q_index():
		if String(x.get("kind", "")) == "act_ref":
			continue
		for r in sim.q_catalog(String(x.get("id", ""))):
			if String(r.get("doc", "")) == did:
				return String(x.get("id", ""))
	return ""

# Antes de salir a la Sala de Lectura: para cada documento a pedir que el catálogo todavía no muestre, indexa alguna de
# sus entidades de catálogo recortando lo legible en el escritorio (como el jugador que busca por lo que ya leyó).
func _prep_catalog() -> void:
	for did in _bm_wants():
		if _catalog_ok(did):
			continue
		for e in repo.doc(did).get("catalog", {}).get("entities", []):
			if _ensure_indexed(String(e)) and _catalog_ent(did) != "":
				break

# ======================================================================= escena fija
func _do_scene() -> void:
	if reads_all:
		_read_all()
	if deduce:
		_harvest()
	act({"t": "leave"})

# ======================================================================= noche e informes
func _do_night() -> void:
	if reads_all:
		_read_all()
	if deduce:
		_harvest()
		_build_sheets()
		_confirm_now()
	var rs: Dictionary = sim.q_report_status()
	if bool(rs.get("due", false)):
		_report(int(rs.n), false)
		return
	act({"t": "sleep"})

func _report(n: int, final: bool) -> void:
	var p := pol_report(n, final)
	var mode := String(p.get("mode", "nada"))
	var items: Array = p.get("items", [])
	if mode == "errata" and not bool(sim.q_report_status().get("offered_erratum", false)):
		mode = "nada"
	var r := act({"t": "report_submit", "mode": mode, "items": items}, random_bot)
	if not bool(r.get("ok", false)):
		act({"t": "report_submit", "mode": "nada", "items": []})
		mode = "nada"
		items = []
	var cats: Array = []
	for it in items:
		for ct in MoranAgent.report_cats(sim.st, repo, it):
			if not cats.has(ct):
				cats.append(ct)
	stats.reports.append({"n": n, "mode": mode, "items": items.size(), "cats": cats})

# ======================================================================= confrontación e informe final
func _do_confront() -> void:
	if deduce:
		_harvest()
	var cs: Dictionary = sim.q_confront()
	var step_n := int(cs.get("step", 1))
	if step_n <= 0:
		step_n = 1
	var item := pol_confront(step_n)
	var r := act({"t": "confront", "step": step_n, "item": item}, true)
	stats.confront.append({"step": step_n, "item": item, "hit": bool(r.get("hit", false)), "ok": bool(r.get("ok", false)), "err": String(r.get("err", ""))})
	if not bool(r.get("ok", false)):
		if not random_bot and not item.is_empty() and bot_name != "confront_azar":
			_err("confront %s -> %s" % [str(item), String(r.get("err", ""))])
		act({"t": "confront", "step": step_n, "item": {}})

func _do_final_report() -> void:
	if deduce:
		_harvest()
		_build_sheets()
	if deduce or value_mode != "oracle":
		_confirm_now()
	_report(int(sim.q_report_status().get("n", 4)), true)

# ======================================================================= objetivos y plan (oráculo)
func _need() -> Array:
	var out: Array = []
	var sealed: Dictionary = Dossier.inked(sim.st)
	var pool: Array = focus if not focus.is_empty() else RouteDB.mandatory(repo)
	if focus.is_empty():
		for q in RouteDB.from_birth(repo):
			if Dossier.is_born(sim.st, String(q)):
				pool = pool + [q]
	for cid in pool:
		var c := String(cid)
		if sealed.has(c):
			continue
		if targets.has(c) and _complete(c):
			continue
		out.append(c)
	return out

func _complete(cid: String) -> bool:
	if not targets.has(cid):
		return false
	for f in targets[cid].frags:
		if not clip_of.has(f.key):
			return false
	return true

# GDD_v2 §B.4: el grafo sólo cuenta con la hora garantizada de cada lugar (schedule.reveal.by). Un jugador que ya tiene el
# lugar en el mapa antes (lo leyó, lo oyó o lo recortó) puede ir antes: el plan del bot usa un repo envuelto sin la
# garantía de esos lugares (lo que ve en el mapa, no un oráculo). Uno por conjunto de lugares revelados antes de hora.
var _plan_repos := {}
func _plan_repo():
	var rv = repo.schedule().get("reveal", {})
	if typeof(rv) != TYPE_DICTIONARY or rv.is_empty():
		return repo
	var early: Array = []
	var revealed: Dictionary = sim.st.world.get("revealed", {})
	for L in revealed:
		if rv.has(L) and int(revealed[L]) < TimeKey.of(rv[L].get("by", "")):
			early.append(String(L))
	if early.is_empty():
		return repo
	early.sort()
	var key := ",".join(early)
	if not _plan_repos.has(key):
		var sch: Dictionary = repo.schedule().duplicate(true)
		for L in early:
			sch.reveal.erase(L)
		_plan_repos[key] = load("res://tests/fixtures/graph/patch_repo.gd").new(repo, {"schedule": sch})
	return _plan_repos[key]

# Replanifica desde la franja actual: Feasibility.plan sobre lo que falta. Lo que ya tiene todos sus fragmentos no se toca.
func _replan() -> void:
	if conf_cover and conf_frags.is_empty():
		_conf_plan()
	var need := _need()
	var i := maxi(0, _idx())
	itinerary = {}
	if need.is_empty():
		return
	var prepo = _plan_repo()
	var p: Dictionary = Feasibility.plan(prepo, i, [], need)
	var ok_need: Array = need.duplicate()
	if not bool(p.get("ok", false)):
		# sin plan conjunto: se planifica lo factible de a una conclusión y el resto queda sin ruta (oráculo)
		ok_need = []
		for cid in need:
			var p1: Dictionary = Feasibility.plan(prepo, i, [], ok_need + [cid])
			if bool(p1.get("ok", false)):
				ok_need.append(cid)
			else:
				_oracle("sin ruta ★ factible para %s desde %s: %s" % [cid, TimeKey.label(TimeKey.tk(int(_c().day), String(_c().slot))), str(p1.get("unmet", []))])
		p = Feasibility.plan(prepo, i, [], ok_need) if not ok_need.is_empty() else {"ok": true, "plan": [], "routes": {}}
	for cid in p.get("routes", {}):
		_set_target(String(cid), String(p.routes[cid]))
	for x in p.get("plan", []):
		itinerary[int(x.idx)] = {"place": String(x.place), "area": String(x.area), "refs": x.get("refs", [])}

# Candidatos de material para cada afirmación de la confrontación: fragmentos de rutas (de cualquier conclusión) que
# llevan una etiqueta a: de su grupo refutador; un documento, en cada uno de sus ejemplares salvo la Sala de Lectura.
func _conf_plan() -> void:
	conf_frags = []
	var seen := {}
	# candidatos: fragmentos de rutas y, como en v3 el librero no tiene pregunta (GDD_v3 §1.10, C12), cualquier tramo de
	# documento con la etiqueta del grupo
	var cands: Array = []
	for uid in RouteDB.units(repo):
		for r in RouteDB.routes(repo, String(uid)):
			for f in r.get("frags", []):
				cands.append({"ref": String(f.get("ref", "")), "copy": String(f.get("copy", ""))})
	for fd0 in RouteDB.all_frags(repo):
		if String(fd0.get("kind", "")) != "doc" or String(fd0.get("ref", "")) == "":
			continue
		var any_hit := false
		for g0 in CONF_GROUPS:
			for t0 in (fd0.get("tags_any", []) as Array) + (fd0.get("tags", []) as Array):
				if _tags_hit([String(t0)], g0):
					any_hit = true
		if any_hit:
			cands.append({"ref": String(fd0.ref), "copy": ""})
	for gi in CONF_GROUPS.size():
		var grp: Array = CONF_GROUPS[gi]
		if true:
			for f in cands:
				if true:
					var ref := String(f.get("ref", ""))
					var copies: Array = [String(f.get("copy", ""))]
					var d0: Dictionary = RouteDB.resolve(repo, ref, "")
					if String(d0.get("kind", "")) == "doc":
						for cp in repo.doc(String(d0.get("doc", ""))).get("copies", []):
							if not copies.has(String(cp.get("id", ""))):
								copies.append(String(cp.get("id", "")))
					for cp2 in copies:
						if String(cp2).ends_with("@BM"):
							continue
						var fd := _frag(ref, String(cp2), "")
						var want: Array = []
						for t in (fd.desc.get("tags_any", []) as Array) + (fd.desc.get("tags", []) as Array):
							if _tags_hit([String(t)], grp) and not want.has(String(t)):
								want.append(String(t))
						if want.is_empty():
							continue
						fd.key = "CONF%d|%s|%s" % [gi + 1, ref, String(fd.copy)]
						if seen.has(fd.key):
							continue
						seen[fd.key] = true
						fd.want = want
						fd["grp"] = gi + 1
						conf_frags.append(fd)

# ¿La afirmación n ya tiene con qué refutarla? (se recuerda el ítem; se revalida que siga existiendo)
func _conf_covered(n: int) -> bool:
	if _conf_ok.has(n):
		var id := String(_conf_ok[n])
		if sim.st.ded.get("clips", {}).has(id) or Dossier.inked(sim.st).has(id):
			return true
		_conf_ok.erase(n)
	var it := _confront_item(n)
	if it.is_empty():
		return false
	_conf_ok[n] = String(it.id)
	return true

func _conf_pending() -> Array:
	var out: Array = []
	if not conf_cover or conf_frags.is_empty() or int(_c().day) > 10:
		return out
	var cov := {}
	for f in conf_frags:
		var n := int(f.grp)
		if not cov.has(n):
			cov[n] = _conf_covered(n)
		if bool(cov[n]) or clip_of.has(f.key) or int(_conf_fail.get(f.key, 0)) >= 3:
			continue
		out.append(f)
	return out

func _set_target(cid: String, rid: String) -> void:
	if targets.has(cid) and String(targets[cid].rid) == rid:
		return
	var r: Dictionary = RouteDB.route_by_id(repo, rid)
	if r.is_empty():
		for rr in RouteDB.routes(repo, cid):
			if String(rr.id) == rid:
				r = rr
	if r.is_empty():
		_oracle("ruta %s inexistente" % rid)
		return
	var frs: Array = []
	for f in r.get("frags", []):
		var fd := _frag(String(f.ref), String(f.get("copy", "")), cid)
		fd["sub"] = String(f.get("sub", ""))
		frs.append(fd)
	targets[cid] = {"rid": rid, "frags": frs}

# Descriptor de trabajo de un fragmento: {ref, copy, key, cid, desc, want:[etiquetas a: de la conclusión]}.
func _frag(ref: String, copy: String, cid := "") -> Dictionary:
	var d: Dictionary = RouteDB.resolve(repo, ref, copy)
	var cp := copy
	if cp == "" and String(d.get("exemplar", "")).begins_with("copy:"):
		cp = String(d.exemplar).substr(5)
	if cp == "" and d.get("kind", "") == "doc":
		# documento con varios ejemplares: el primero legible o, si ninguno, el primero declarado
		for c in repo.doc(String(d.get("doc", ""))).get("copies", []):
			if cp == "":
				cp = String(c.get("id", ""))
	var want: Array = []
	var ct: Array = RouteDB.conc_tags(repo, cid) if cid != "" else []
	for t in (d.get("tags_any", []) as Array) + (d.get("tags", []) as Array):
		var s := String(t)
		if not s.begins_with("a:"):
			continue
		if ct.is_empty() or ct.has(s.substr(2)):
			if not want.has(s):
				want.append(s)
	return {"ref": ref, "copy": cp, "key": cid + "|" + ref + "|" + cp, "cid": cid, "desc": d, "want": want}

func _pending_targets() -> Array:
	var out: Array = []
	for cid in _sorted(targets.keys()):
		if Dossier.inked(sim.st).has(cid):
			continue
		for f in targets[cid].frags:
			if not clip_of.has(f.key):
				out.append(f)
	return out

# Fragmentos pendientes: los de las rutas objetivo y, al final, el material de la confrontación (conf_cover).
func _pending() -> Array:
	return _pending_targets() + _conf_pending()

func _crane_pending() -> bool:
	for f in _pending():
		var cp := String(f.copy)
		if f.desc.kind == "doc" and cp.ends_with("@Crane") and WorldModel.copy_available(sim.st, repo, cp, _tk()):
			return true
	return false

# ======================================================================= cosecha de fragmentos
func _harvest() -> void:
	for f in _pending_targets():
		_try_frag(f)
	for f in _conf_pending():
		if _try_frag(f) == "" and String(f.desc.get("kind", "")) == "doc" and String(f.copy) != "" and not sim.q_view(String(f.copy)).is_empty():
			_conf_fail[f.key] = int(_conf_fail.get(f.key, 0)) + 1

# Intenta recortar el fragmento ahora. Devuelve el id del recorte o "".
func _try_frag(f: Dictionary) -> String:
	if clip_of.has(f.key):
		return String(clip_of[f.key])
	# el mismo ref/ejemplar ya recortado para otra conclusión sirve igual (el recorte es el mismo papel)
	for k in clip_of:
		var ks := String(k)
		if ks.get_slice("|", 1) == String(f.ref) and ks.get_slice("|", 2) == String(f.copy) and _clip_has_any(String(clip_of[k]), f.want):
			clip_of[f.key] = clip_of[k]
			return String(clip_of[k])
	var id := ""
	var d: Dictionary = f.desc
	match String(d.get("kind", "")):
		"doc":
			id = _try_doc(f)
		"node":
			id = _try_node(f)
		"sil":
			id = _try_sil(f)
		"scene", "line":
			id = _try_line(f)
		"react":
			id = _try_react(f)
		"journal":
			id = _try_journal(f)
		"ad":
			id = _try_ad(f)
		"measure":
			id = _try_measure(f)
	if id != "":
		clip_of[f.key] = id
	return id

func _clip_has_any(clip_id: String, want: Array) -> bool:
	if want.is_empty():
		return true
	var tags: Array = Clipper.get_clip(sim.st, clip_id).get("tags", [])
	for t in want:
		if tags.has(t):
			return true
	return false

func _try_doc(f: Dictionary) -> String:
	var view := String(f.copy)
	if view == "" or sim.q_view(view).is_empty():
		return ""
	return _clip_tramo(view, String(f.ref).get_slice("#", 1))

# Recorta el tramo #tid de una vista legible: entero si mide ≤15 palabras; si no, la ventana legal de 15 palabras que
# más lo cubre (GDD_v3 §6.2: hereda sus etiquetas si cubre ≥50 %).
func _clip_tramo(view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var p: Dictionary = pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				if String(t.get("id", "")) == tid:
					var span := best_window(p, int(t.from), int(t.to))
					var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(span[0]), "len": int(span[1]) - int(span[0])}, true)
					return String(r.get("clip", ""))
	return ""

# [from, to) del recorte legal (≤15 palabras, una oración) que más cubre [a, b).
static func best_window(p: Dictionary, a: int, b: int) -> Array:
	var words: Array = p.get("words", [])
	var idx: Array = []
	for k in words.size():
		if int(words[k][0]) >= a and int(words[k][1]) <= b:
			idx.append(k)
	if idx.size() <= ClipRules.MAX_WORDS:
		return [a, b]
	var best := [int(words[idx[0]][0]), int(words[idx[ClipRules.MAX_WORDS - 1]][1])]
	var bcov := -1
	for st in range(0, idx.size() - ClipRules.MAX_WORDS + 1):
		var f := int(words[idx[st]][0])
		var e := int(words[idx[st + ClipRules.MAX_WORDS - 1]][1])
		var sn: Dictionary = ClipRules.snap(p, f, e - f)
		if not bool(sn.get("ok", false)):
			continue
		var cov := mini(int(sn.to), b) - maxi(int(sn.from), a)
		if cov > bcov:
			bcov = cov
			best = [int(sn.from), int(sn.to)]
	return best

# Recorta en una vista el primer tramo (de un bloque cuyo doc pase el filtro) que lleve alguna etiqueta pedida.
func _clip_tagged(view: String, want: Array, doc_filter := "") -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var blk: Dictionary = pages[pi][bi]
			var segs: Array = blk.get("segs", [])
			if doc_filter != "" and segs.is_empty() and not String(blk.get("doc", "")).begins_with(doc_filter):
				continue
			var p: Dictionary = blk.get("parsed", {})
			for t in p.get("tramos", []):
				if doc_filter != "" and not segs.is_empty():
					# número del Times con avisos insertados (WorldModel._merge_inserts): el doc del tramo es el de su seg
					var dd := String(blk.get("doc", ""))
					for sg in segs:
						if int(t.from) >= int(sg.from) and int(t.to) <= int(sg.to):
							dd = String(sg.doc)
					if not dd.begins_with(doc_filter):
						continue
				if _tramo_has(t, want):
					var sp := best_window(p, int(t.from), int(t.to))
					var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}, true)
					var id := String(r.get("clip", ""))
					if id != "":
						return id
	return ""

func _tramo_has(t: Dictionary, want: Array) -> bool:
	var flat := RouteDB.flat_tags(t.get("tags", {}))
	if want.is_empty():
		for x in flat:
			if String(x).begins_with("a:"):
				return true
		return false
	for w in want:
		if flat.has(w):
			return true
	return false

func _plates_sorted() -> Array:
	var ps: Array = sim.st.world.get("plates", {}).keys()
	ps.sort()
	var cur := String(sim.st.world.get("visit", {}).get("plate", ""))
	if cur != "" and ps.has(cur):
		ps.erase(cur)
		ps.push_front(cur)
	return ps

func _clip_node(pid: String, nid: String) -> String:
	var r := act({"t": "clip_plate", "plate": pid, "hits": [{"node": nid, "cover": 0.9, "tight": true}], "touched": [nid], "area_frac": 0.05}, true)
	return String(r.get("clip", ""))

func _try_node(f: Dictionary) -> String:
	var ref := String(f.ref).substr(2)
	var nid := ref.get_slice(".", ref.get_slice_count(".") - 1)
	var owner := ref.substr(0, ref.length() - nid.length() - 1)
	# lámina fija archivada (copy "PL.prologo" o el origen de la lámina)
	var cands: Array = []
	if String(f.copy).begins_with("PL."):
		cands.append(String(f.copy))
	for pid in _plates_sorted():
		var snap: Dictionary = sim.st.world.plates[pid]
		if String(snap.get("place", "")) == owner or String(pid) == owner or String(snap.get("origin", "")) == "PL." + owner:
			cands.append(String(pid))
	for pid in cands:
		var snap2: Dictionary = sim.q_plate(pid)
		if snap2.is_empty() or not (snap2.get("nodes", []) as Array).has(nid):
			continue
		var id := _clip_node(pid, nid)
		if id != "" and _clip_has_any(id, f.want):
			return id
	# la buhardilla de ahora (desde el escritorio): el texto de su tarjeta de examen (GDD_v3 §6.2)
	if owner == HUB and String(sim.q_clock().phase) == "desk":
		var hub: Dictionary = sim.q_hub_plate()
		if (hub.get("nodes", []) as Array).has(nid):
			var id2 := _clip_exam("hub/" + nid, f.want)
			if id2 != "":
				return id2
	return ""

# Recorta del texto del examen de un nodo (src kind node) el pedazo legal que hereda alguna etiqueta pedida.
func _clip_exam(ref: String, want: Array) -> String:
	var pid := ref.get_slice("/", 0)
	var nid := ref.get_slice("/", 1)
	var snap: Dictionary = sim.q_hub_plate() if pid == "hub" else sim.q_plate(pid)
	var ex := String(Clipper.node_def(sim.st, repo, snap, nid).get("examine", ""))
	if ex == "":
		return ""
	var p: Dictionary = repo.parse_text(ex)
	var plain := String(p.get("plain", ""))
	var spans: Array = [{"from": 0, "to": plain.length()}]
	spans.append_array(ClipRules.max_legal_clips(p))
	for sp in spans:
		var r := act({"t": "clip_text", "src": {"kind": "node", "ref": ref}, "from": int(sp.from), "len": int(sp.to) - int(sp.from)}, true)
		var id := String(r.get("clip", ""))
		if id != "" and _clip_has_any(id, want):
			return id
	return ""

func _try_sil(f: Dictionary) -> String:
	var nid := String(f.ref).get_slice(".", String(f.ref).get_slice_count(".") - 1)
	for pid in _plates_sorted():
		var snap: Dictionary = sim.st.world.plates[pid]
		if String(snap.get("place", "")) == HUB:
			continue   # la silueta vista desde el escritorio no cita un acto «go» (Availability.sil_srcs salta el hub, D1)
		if (snap.get("silhouettes", []) as Array).has(nid):
			var id := _clip_node(String(pid), nid)
			if id != "" and _clip_has_any(id, f.want):
				return id
	return ""

# Líneas dichas (S:<escena>.<línea> / L:<personaje>.<línea>): de st.world.lines o st.scenes.lines.
func _said_lines() -> Array:
	var out: Array = []
	for src in [sim.st.world.get("lines", {}), sim.st.scenes.get("lines", {}) if typeof(sim.st.scenes) == TYPE_DICTIONARY else {}]:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var ks: Array = src.keys()
		ks.sort()
		for k in ks:
			out.append(src[k])
	return out

func _try_line(f: Dictionary) -> String:
	for uid in _line_uids(f):
		var id := _clip_line(String(uid), f.want)
		if id != "":
			return id
	return ""

# uids de las líneas dichas que corresponden a un fragmento S:<escena>.<línea> / L:<personaje>.<línea>.
func _line_uids(f: Dictionary) -> Array:
	var out: Array = []
	var ref := String(f.ref)
	var rest := ref.substr(2)
	var owner := rest.get_slice(".", 0)
	var lid := rest.substr(owner.length() + 1)
	var is_scene := ref.begins_with("S:")
	var star := lid.ends_with("*")
	for rec in _said_lines():
		var rid := String(rec.get("id", ""))
		var ok := rid.begins_with(lid.trim_suffix("*")) if star else rid == lid
		if not ok:
			continue
		if is_scene and String(rec.get("scene", "")) != owner:
			continue
		if not is_scene and String(rec.get("who", "")) != owner:
			continue
		out.append(String(rec.uid))
	return out

func _clip_line(uid: String, want: Array) -> String:
	var ln: Dictionary = sim.q_line(uid)
	var p: Dictionary = ln.get("parsed", {})
	for t in p.get("tramos", []):
		if _tramo_has(t, want):
			var sp := best_window(p, int(t.from), int(t.to))
			var r := act({"t": "clip_text", "src": {"kind": "line", "ref": uid}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}, true)
			var id := String(r.get("clip", ""))
			if id != "":
				return id
	return ""

func _try_react(f: Dictionary) -> String:
	var ref := String(f.ref).substr(2)
	var rid := ref.get_slice(".", 0)
	var sel := ref.substr(rid.length() + 1)
	for inst in sim.st.react.get("delivered", []):
		if String(inst.get("rid", "")) != rid or String(inst.get("view", "")) == "":
			continue
		if sel != "*" and sel != "" and not ["col", "columna", "carta", "noticia", "texto"].has(sel) and String(inst.get("tpl", "")) != sel and not String(inst.get("tpl", "")).begins_with(sel + "."):
			# selector = id de tramo: se busca igual por etiqueta
			pass
		for view in _inst_views(inst):
			var id := _clip_tagged(String(view), f.want, String(inst.get("view", "")) if String(view) != String(inst.get("view", "")) else "")
			if id != "":
				return id
	return ""

# Vistas donde se lee una instancia entregada: ella misma (bandeja) o el número del Times donde quedó insertada.
func _inst_views(inst: Dictionary) -> Array:
	var iid := String(inst.get("view", ""))
	var out: Array = []
	var docs: Dictionary = sim.st.world.get("docs", {})
	if docs.has(iid) and String(docs[iid].get("where", "")) == "tray":
		out.append(iid)
	var ins: Dictionary = sim.st.world.get("inserts", {})
	for did in _sorted(ins.keys()):
		for part in ins[did]:
			if (ins[did][part] as Array).has(iid):
				for c in repo.doc(String(did)).get("copies", []):
					var cid := String(c.get("id", ""))
					if not out.has(cid):
						out.append(cid)
	return out

func _try_journal(f: Dictionary) -> String:
	var key := String(f.ref).substr(2)
	for e in sim.q_diary():
		var ek := String(e.get("key", ""))
		var et := String(e.get("type", ""))
		if not (ek == key or ek.begins_with(key + ".") or et == key):
			continue
		var p: Dictionary = e.get("parsed", {})
		for t in p.get("tramos", []):
			if _tramo_has(t, f.want):
				var sp := best_window(p, int(t.from), int(t.to))
				var r := act({"t": "clip_text", "src": {"kind": "diary", "ref": String(e.id)}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}, true)
				var id := String(r.get("clip", ""))
				if id != "":
					return id
	return ""

func _try_ad(f: Dictionary) -> String:
	var views: Array = []
	if String(f.copy) != "":
		views.append(String(f.copy))
	else:
		for x in sim.q_accessible():
			if String(x.doc).begins_with("D15."):
				views.append(String(x.view))
	for view in views:
		if sim.q_view(String(view)).is_empty():
			continue
		var id := _clip_tagged(String(view), f.want, "AD")
		if id != "":
			return id
	return ""

func _try_measure(f: Dictionary) -> String:
	var ref := String(f.ref).substr(2)
	var src := {}
	if repo.doc(ref).is_empty():
		var sid := ref.get_slice(".", 0)
		if not repo.scene(sid).is_empty():
			src = {"kind": "scene", "ref": sid}
		elif not repo.reaction(sid).is_empty():
			# carta de una reacción (M:HA1.carta, voz A): la instancia entregada que se puede leer ahora
			for x in sim.q_accessible():
				if String(x.view).begins_with("R.%s." % sid):
					src = {"kind": "doc", "ref": String(x.view)}
					break
			if src.is_empty():
				return ""
		else:
			return ""
	else:
		var view := String(f.copy)
		if view == "":
			for x in sim.q_accessible():
				if String(x.doc) == ref:
					view = String(x.view)
		if view == "" or sim.q_view(view).is_empty():
			return ""
		src = {"kind": "doc", "ref": view}
	return ""   # v3: sin refs M: (la regla no existe)

# Recorta la primera oración de una vista (prólogo sin práctica; recorta_todo usa max_legal_clips) que no dé un
# recorte ya existente (except).
func _clip_first_sentence(view: String, except: Array = []) -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var p: Dictionary = pages[pi][bi].get("parsed", {})
			for s in ClipRules.max_legal_clips(p):
				var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(s.from), "len": int(s.to) - int(s.from)}, true)
				if String(r.get("clip", "")) != "" and not except.has(String(r.clip)):
					return String(r.clip)
	return ""

static func _uniq(a: Array) -> Array:
	var out: Array = []
	for x in a:
		if not out.has(x):
			out.append(x)
	return out

# Lleva una entidad al índice recortando algo legible que la nombre (oración que la menciona o tramo con e:).
func _ensure_indexed(ent: String) -> bool:
	if _known(ent):
		return true
	var views: Array = []
	for x in sim.q_accessible():
		views.append(String(x.view))
	for view in views:
		var v: Dictionary = sim.q_view(String(view))
		var pages: Array = v.get("pages", [])
		for pi in pages.size():
			for bi in (pages[pi] as Array).size():
				var blk: Dictionary = pages[pi][bi]
				var p: Dictionary = blk.get("parsed", {})
				var spans: Array = []
				for t in p.get("tramos", []):
					if RouteDB.flat_tags(t.get("tags", {})).has("e:" + ent):
						spans.append([int(t.from), int(t.to)])
				for m in p.get("mentions", []):
					if String(m.ent) == ent:
						spans.append([int(m.from), int(m.to)])
				var dm: Dictionary = repo.doc(String(v.get("doc", "")))
				if String(dm.get("entity", "")) == ent or (sim.st.world.get("docs", {}).has(String(blk.get("doc", ""))) and String(sim.st.world.docs[String(blk.doc)].get("meta", {}).get("entity", "")) == ent):
					spans.append([0, mini(40, String(p.get("plain", "")).length())])
				for sg in blk.get("segs", []):
					# aviso insertado en la columna: la entidad de su documento runtime (el recorte cae dentro del seg)
					var idoc = sim.st.world.get("docs", {}).get(String(sg.doc))
					if typeof(idoc) == TYPE_DICTIONARY and String(idoc.get("meta", {}).get("entity", "")) == ent:
						spans.append([int(sg.from), mini(int(sg.from) + 40, int(sg.to))])
				for sp in spans:
					var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": String(view), "part": pi, "block": bi}, "from": int(sp[0]), "len": maxi(1, int(sp[1]) - int(sp[0]))}, true)
					if String(r.get("clip", "")) != "" and _known(ent):
						return true
	return _known(ent)

func _clip_ids() -> Array:
	var ids: Array = sim.st.ded.get("clips", {}).keys()
	ids.sort()
	return ids

# ======================================================================= hojas del Expediente
# Respuestas válidas (variante principal primero) de una pregunta, con los alias vigentes ya resueltos.
func _valid_answers(q: String) -> Array:
	var out: Array = []
	var qd: Dictionary = repo.question(q)
	var groups: Array = Dossier.alias_groups(repo, sim.st)
	var vs: Array = (qd.get("variantes", []) as Array).duplicate()
	vs.sort_custom(func(a, b): return bool(a.get("principal", false)) and not bool(b.get("principal", false)))
	for v in vs:
		for r0 in v.get("respuestas", []):
			var s0 := String(r0)
			if s0.begins_with("@alias:"):
				var x := s0.substr(7)
				var on := false
				for g in groups:
					if g.has(x):
						on = true
				if not on:
					continue
				s0 = x
			if not out.has(s0):
				out.append(s0)
	return out

# Escribe la hoja (lápiz): respuesta y dos pruebas.
func _write_sheet(q: String, answer: String, c1: String, c2: String) -> bool:
	var ok := true
	ok = bool(act({"t": "dq_answer", "q": q, "value": answer}, true).get("ok", false)) and ok
	ok = bool(act({"t": "dq_proof", "q": q, "slot": 0, "clip": c1}, true).get("ok", false)) and ok
	ok = bool(act({"t": "dq_proof", "q": q, "slot": 1, "clip": c2}, true).get("ok", false)) and ok
	if ok:
		sheet_of[q] = {"answer": answer, "proofs": [c1, c2]}
	return ok

# Respuesta del oráculo: una respuesta válida que esté (o se pueda poner) en el índice, prefiriendo la que nombran las
# pruebas. "" si ninguna.
func _oracle_answer(q: String, clips: Array) -> String:
	var vals := _valid_answers(q)
	for cl in clips:
		var ents: Array = Clipper.get_clip(sim.st, String(cl)).get("ents", [])
		for v in vals:
			if ents.has(v) and _answer_ok(q, String(v)):
				return String(v)
	for v in vals:
		if _answer_ok(q, String(v)):
			return String(v)
	for v in vals:
		if _ensure_indexed(String(v)) and _answer_ok(q, String(v)):
			return String(v)
	return ""

func _answer_ok(q: String, v: String) -> bool:
	for o in sim.q_answer_options(q):
		if String(o.id) == v:
			return true
	return false

# Escribe las hojas de las preguntas abiertas cuya ruta objetivo ya tiene sus dos recortes (oráculo: sólo si cierra).
func _build_sheets() -> void:
	for q in _sorted(targets.keys()):
		if sheet_of.has(q) or bad_sheet.has(q) or Dossier.inked(sim.st).has(q) or not _complete(q):
			continue
		if not Dossier.is_open(sim.st, q):
			waits[q] = "la pregunta no está abierta (no nació o espera lugar)"
			continue
		var clips: Array = []
		for f in targets[q].frags:
			var cl := String(clip_of[f.key])
			if not clips.has(cl):
				clips.append(cl)
		if clips.size() != 2:
			bad_sheet[q] = "la ruta %s no da dos recortes distintos" % targets[q].rid
			continue
		var ans := ""
		if value_mode == "oracle":
			ans = _oracle_answer(q, clips)
		else:
			var opts: Array = sim.q_answer_options(q)
			if not opts.is_empty():
				ans = String(Det.pick(seed, [bot_name, q, int(attempt.get(q, 0)), "ans"], opts).id)
		if ans == "":
			waits[q] = "ninguna respuesta válida está en el índice"
			continue
		waits.erase(q)
		if value_mode == "oracle":
			var ev: Dictionary = Dossier.check(sim.st, repo, q, {"answer": ans, "proofs": clips})
			if not bool(ev.get("ok", false)):
				bad_sheet[q] = "check %s" % str(ev)
				_oracle("%s (%s): la hoja armada no cierra: %s" % [q, targets[q].rid, str(ev)])
				continue
		_write_sheet(q, ans, String(clips[0]), String(clips[1]))

# ======================================================================= informes y confrontación (ayudas)
# Ítems (preguntas y recortes) con sus categorías de Moran: [{item:{kind,id}, cats:[...]}].
func _report_candidates() -> Array:
	var out: Array = []
	var dv: Dictionary = sim.q_dossier()
	for h in (dv.get("inked", []) as Array) + (dv.get("open", []) as Array):
		var it := {"kind": "pregunta", "id": String(h.id)}
		out.append({"item": it, "cats": MoranAgent.report_cats(sim.st, repo, it)})
	for cl in _clip_ids():
		var it2 := {"kind": "clip", "id": String(cl)}
		out.append({"item": it2, "cats": MoranAgent.report_cats(sim.st, repo, it2)})
	return out

# Ítem que refuta la afirmación step_n (grupo propio; nunca material secreto_camden). Recortes antes que preguntas.
func _confront_item(step_n: int) -> Dictionary:
	if step_n < 1 or step_n > CONF_GROUPS.size():
		return {}
	var grp: Array = CONF_GROUPS[step_n - 1]
	for cl in _clip_ids():
		var it := {"kind": "clip", "id": String(cl)}
		if Deps.item_camden(sim.st, repo, it):
			continue
		if _tags_hit(Clipper.get_clip(sim.st, String(cl)).get("tags", []), grp):
			return it
	for q in _sorted(Dossier.inked(sim.st).keys()):
		var it2 := {"kind": "pregunta", "id": String(q)}
		if Deps.item_camden(sim.st, repo, it2):
			continue
		if _tags_hit(Deps.item_tags(sim.st, it2), grp):
			return it2
	return {}

static func _tags_hit(tags: Array, grp: Array) -> bool:
	for t in tags:
		var s := String(t)
		if not s.begins_with("a:"):
			continue
		var v := s.substr(2)
		for g in grp:
			var gs := String(g)
			if (gs.ends_with("*") and v.begins_with(gs.trim_suffix("*"))) or v == gs:
				return true
	return false

static func _sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out
