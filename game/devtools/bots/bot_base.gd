# devtools/bots/bot_base.gd — motor común de los bots (W3-BOTS; ARCHITECTURE §9.3, GDD §15.5 T10/T24).
# Contrato §9.3: sim, seed, stats; setup(sim, seed) · step() -> bool (una decisión, ≥1 apply; false = terminó) ·
#   play(max_steps) -> {ending, rank, sealed, words_read, est_minutes, acts, steps, …} · act(a) (sim.apply + estadística;
#   un ok:false es fallo del bot salvo en bots «al azar» o en intentos marcados may_fail) · read(view) (palabras leídas) ·
#   clip_ref(ref) (oráculo: recorta el fragmento de contrato §4.8 desde su ejemplar).
# Juega SÓLO por GameSim.apply (la puerta de §3.1); lee con q_* y, como oráculo, con core/graph (RouteDB, Feasibility),
#   Validator (para no pasar en limpio a ciegas) y el estado interno de recortes (Clipper.get_clip) — los bots que
#   modelan a un jugador honesto (pesca, recorta_todo, fuerza bruta) no usan las etiquetas ocultas para elegir valores.
# Motor (lo heredan todos; cada bot cambia la política con los ganchos «pol_*»):
#   prólogo  : tutorial v2 (abrir el encargo, recortar, aviso de testigos, dormir); día 1: la primera conclusión C1 de
#              práctica (juntar, hoja, conclusión, practicar) antes de cualquier confirmación (GDD_v2 §B.7).
#   objetivos: Feasibility.plan (rutas ★ elegibles, mínimo de salidas) desde 1.M → targets {cid: ruta} + itinerario
#              {idx: (lugar, área)}; replanifica si una salida no se pudo hacer o faltan fragmentos.
#   cosecha  : en cada paso recorta todo fragmento pendiente obtenible AHORA (documentos legibles, láminas archivadas,
#              siluetas, líneas dichas, diario, rastros entregados, avisos impresos, medidas). En la Sala de Lectura pide
#              papeletas (≤3) de lo que falta; baja a la tienda de Crane (gratis) si hay ejemplares de Crane pendientes.
#   asientos : con todos los fragmentos de la ruta, arma el asiento (valores indexados de answers; «según» por grupo) y lo
#              verifica con Validator.evaluate antes de escribirlo. Pasa en limpio lotes de lot_size con conclusiones
#              distintas y válidas (oráculo).
#   confrontación: con conf_cover (deductor), además un recorte por grupo refutador de fuentes gratuitas (_conf_plan).
#   oráculo   : stats.oracle registra rutas ★ planificadas cuyos fragmentos no se pudieron obtener en su ventana.
#   informes, confrontación, Mycroft, noche y epílogo: ganchos.
# Estadística (stats): acts, steps, errors (ok:false inesperados), words_read, words_by_day, est_minutes,
#   est_minutes_act {I, II, III}, passes, passes_inked, sealed, outings, blocked (novato), oracle (fallas del oráculo),
#   ending, rank, franjas (= salidas con costo), verbs {t: {free, costly}}, places {L.área: n}, runaway. log: [{t, ok, err,
#   tk, day, slot, phase, free, costly, taught, place?, area?, char?, form?, mode?, silent?}] (T24).
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
const Ledger = preload("res://core/deduction/ledger.gd")
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
const FREE_TWIN := {"pass_clean": "practice", "ask": "ask", "assert": "assert", "present": "present", "go": "go"}
const COSTLY := ["slip", "order_copy", "pass_clean", "compose_ad", "compose_telegram", "compose_letter", "report_submit",
	"confront", "night_choice", "publish_errata", "end_slot"]
const TALK := ["ask", "assert", "present", "pay", "task"]
const CONF_GROUPS = Confrontation.GROUPS   # grupos refutadores de las cuatro afirmaciones (W2-SCENES)
# Tramos de la partida (GDD §7.7): prólogo, actos I–III, epílogo (minutos del novato por tramo).
const ACTS := {"P": [0, 0], "I": [1, 4], "II": [5, 7], "III": [8, 10], "E": [11, 11]}
# Modelo de tiempo de juego (W4-BALANCE; supuestos, no mediciones): minutos por acto ACEPTADO, más 3 min de deliberación
# por conclusión sellada ese día. play_minutes = lectura (palabras/WPM × REREAD) + interacción + deliberación.
const T_ACT := {"go_costly": 1.0, "go_free": 0.5, "clip": 0.3, "link": 0.15, "folio_open": 0.2, "entry_new": 0.5,
	"entry_set": 0.3, "entry_support_add": 0.3, "pass_clean": 0.7, "practice": 0.5, "slip": 0.5, "ask": 0.4, "assert": 0.4,
	"present": 0.4, "pay": 0.2, "task": 0.3, "compose_ad": 1.5, "compose_telegram": 1.5, "compose_letter": 1.5,
	"report_submit": 1.5, "confront": 1.0, "night_choice": 0.5, "publish_errata": 0.5}
const T_THINK_PER_SEAL := 3.0
# Peso de las palabras de la línea física en el modelo de lectura (0 = no cuenta, 1 = como el texto). Ver _read_parsed.
const PACE_FISICA := 1.0
# Conclusiones opcionales que el oráculo usa de compañeras de lote (C10a no cuenta para el tamaño del lote, pero sella).
const FILLERS := ["C10a", "C14"]

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
var deduce := true           # junta fragmentos y asienta (pasivo: false)
var focus: Array = []        # conclusiones objetivo ([] = todas las obligatorias)
var fillers := true          # el oráculo agrega opcionales factibles (FILLERS) como compañeras de lote
var idle_until_day := 0      # > 1: los días 1..idle_until_day-1 sólo pasa franjas, duerme e informa «nada» (sondas del oráculo)
var value_mode := "oracle"   # valores de los asientos: "oracle" (answers) | "random" (pesca: candidatos al azar)
var log: Array = []
var rnd_n := 0               # contador de sorteos (Det con la semilla del bot)
var attempt := {}            # cid -> nº de juego de valores (pesca)
var waits := {}              # cid -> motivo transitorio por el que todavía no hay asiento
var replan_next := false     # replanificar en el próximo escritorio (se salteó una salida del itinerario)
var seen_clips := {}         # recortes legales máximos ya hechos (fuerza_bruta, recorta_todo)

var targets := {}            # cid -> {rid, subs:[], frags:[{ref, copy, key, desc, want:[]}]}
var itinerary := {}          # idx -> {place, area, refs}
var clip_of := {}            # key de fragmento -> id de recorte
var entry_of := {}           # cid -> id de asiento
var bad_entry := {}          # cid -> motivo (oráculo no pudo armar un asiento válido)
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
		"passes": 0, "passes_inked": 0, "sealed": [], "outings": 0, "blocked": {}, "oracle": [], "reports": [],
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
	for k in ["place", "area", "char", "form", "mode"]:
		if a.has(k):
			le[k] = String(a[k])
	if t == "confront":
		le["silent"] = (a.get("item", {}) as Dictionary).is_empty()
	log.append(le)
	if not ok and not may_fail and not random_bot:
		_err("%s -> %s (fase %s, %s)" % [J.stringify_canon(a), String(r.get("err", "")), c.phase, c.get("date_label", "")])
	if ok and t == "go" and not free:
		stats.outings = int(stats.outings) + 1
	if ok and t == "pass_clean":
		stats.passes = int(stats.passes) + 1
		if bool(r.get("inked", false)):
			stats.passes_inked = int(stats.passes_inked) + 1
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
	var sealed: Array = sim.st.ded.get("sealed", {}).keys()
	sealed.sort()
	stats["sealed"] = sealed
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
	for ps in sim.st.ded.get("passes", []):
		if not bool(ps.get("inked", false)):
			continue
		var ak2 := _act_of_day(TimeKey.day_of(int(ps.get("tk", 0))))
		if ak2 != "":
			pm[ak2] = float(pm[ak2]) + T_THINK_PER_SEAL * float((ps.get("entries", []) as Array).size())
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
	# obligatorias sin sellar y por qué (para el informe del bot; sólo los bots que deducen)
	var unsealed := {}
	if deduce:
		for cid in RouteDB.mandatory(repo):
			var c := String(cid)
			if sealed.has(c):
				continue
			if bad_entry.has(c):
				unsealed[c] = "asiento inválido: " + String(bad_entry[c]).left(160)
			elif entry_of.has(c):
				unsealed[c] = "asiento %s sin pasar en limpio" % entry_of[c]
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
	return {"bot": bot_name, "seed": seed, "ending": stats.ending, "rank": stats.rank, "sealed": sealed, "words_read": words,
		"verbs": verbs, "places": places, "ads": int(stats.get("ads", 0)),
		"est_minutes": stats.est_minutes, "est_minutes_act": em, "play_minutes": stats.play_minutes, "play_minutes_act": stats.play_minutes_act,
		"acts": stats.acts, "steps": stats.steps,
		"outings": stats.outings, "franjas": stats.franjas, "passes": stats.passes, "passes_inked": stats.passes_inked, "errors": stats.errors.duplicate(),
		"oracle": stats.oracle.duplicate(), "flags": stats.flags, "variants": stats.variants, "phase": stats.phase,
		"blocked": stats.blocked.duplicate(), "reports": stats.reports.duplicate(), "confront": stats.confront.duplicate(),
		"mycroft": stats.mycroft.duplicate(), "unsealed": unsealed, "runaway": _runaway}

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

# Valores de un campo de asiento (candidatos ya filtrados por aceptación). Por defecto, el oráculo (answers).
func pol_values_mode() -> String:
	return "oracle"

# Pasada en limpio de esta franja: lista de asientos (tamaño lot_size) o [].
func pol_lot(n: int) -> Array:
	if value_mode == "oracle":
		return _oracle_lot(n)
	return _blind_lot(n)

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

# ======================================================================= prólogo (tutorial, GDD_v2 §B.7)
# Prólogo: abrir el encargo (read), recortar (los fragmentos de la práctica y lo que pide el aviso), el aviso de
# testigos y dormir. La primera conclusión (juntar, hoja, conclusión, práctica) es del día 1 (_first_conclusion): sin
# práctica no se confirma (practica_pendiente).
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

# Día 1 (o el primer escritorio sin práctica): la primera conclusión guiada por las notas de Lisle. Una vez por franja.
func _first_conclusion() -> void:
	if bool(sim.q_tutorial().get("practice_done", false)) or not _once("first_conclusion"):
		return
	if _practice_clips().size() < 2:
		_prologue_clips()
	var pc := _uniq(_practice_clips())
	if pc.size() >= 2:
		act({"t": "link", "a": pc[0], "b": pc[1], "note": "dos fechas"})
	else:
		var ids := _uniq(pc + _clip_ids())
		if ids.size() < 2:
			for x in sim.q_accessible():
				if _clip_ids().size() >= 2:
					break
				_clip_first_sentence(String(x.view), _clip_ids())
			ids = _uniq(pc + _clip_ids())
		if ids.size() >= 2:
			act({"t": "link", "a": ids[0], "b": ids[1], "note": ""})
	var pc2 := _practice_clips()
	var cl := _clip_ids()
	if pc2.is_empty() and cl.is_empty():
		_err("primera conclusión: sin recortes")
		return
	var head: String = pc2[0] if not pc2.is_empty() else String(cl[0])
	stats["practice_folio"] = String(act({"t": "folio_open", "clip": head}).get("folio", ""))
	_prologue_entry()
	var eid := String(stats.get("practice_entry", ""))
	for tries in 3:
		var r := act({"t": "practice", "entry": eid}, true)
		if bool(r.get("ok", false)):
			return
		# chequeo formal: se arregla la FORMA de las pruebas (dos pasajes, ≤4 recortes) y se reintenta
		_fix_practice_support(eid, r.get("formal", []))
	_err("primera conclusión: la práctica no pasa el chequeo formal tras 3 intentos")

# Recortes del prólogo: los fragmentos de una C1 practicable desde P.N y lo que pide el aviso de testigos.
func _prologue_clips() -> void:
	var plan := _practice_plan()
	stats["practice_cid"] = String(plan.get("cid", ""))
	for f in plan.get("frags", []):
		_try_frag(f)
	_ensure_testigo()
	if _clip_ids().is_empty():
		# nada practicable: un recorte cualquiera del primer documento legible (el tutorial pide recortar)
		for x in sim.q_accessible():
			if _clip_first_sentence(String(x.view)) != "":
				break

# {cid, rid, frags} de una conclusión de práctica cuyos fragmentos son legibles en el prólogo.
func _practice_plan() -> Dictionary:
	for c in repo.conclusions():
		if String(c.get("kind", "")) != "practica":
			continue
		for r in RouteDB.routes(repo, String(c.id)):
			if not (r.get("missing", []) as Array).is_empty():
				continue
			var fr: Array = []
			var ok := true
			for f in r.frags:
				var fd := _frag(String(f.ref), String(f.get("copy", "")), String(c.id))
				var cp := String(fd.copy)
				if fd.desc.kind != "doc" or cp == "" or sim.q_view(cp).is_empty():
					ok = false
					break
				fr.append(fd)
			if ok and fr.size() >= 2:
				return {"cid": String(c.id), "rid": String(r.id), "frags": fr}
	return {}

func _practice_clips() -> Array:
	var out: Array = []
	var cid := String(stats.get("practice_cid", ""))
	if cid == "":
		return out
	for k in clip_of:
		if String(k).begins_with(cid + "|"):
			out.append(String(clip_of[k]))
	out.sort()
	return out

func _prologue_entry() -> void:
	var cid := String(stats.get("practice_cid", ""))
	var folio := String(stats.get("practice_folio", "varios"))
	var plan := _practice_plan_cached()
	var spec := {}
	if cid != "" and not plan.is_empty():
		spec = _entry_spec(cid, plan.frags, [])
	if spec.is_empty():
		# sin práctica posible: un asiento cualquiera con un campo y su «según» (el paso lo exige)
		var ids := _clip_ids()
		var e := String(act({"t": "entry_new", "folio": folio if folio != "" else "varios", "template": "T1"}).get("entry", ""))
		var cands := _field_candidates(_field_def("T1", 0, "fuente_a"))
		if not cands.is_empty():
			act({"t": "entry_set", "entry": e, "line": 0, "field": "fuente_a", "value": String(cands[0])})
		if not ids.is_empty():
			act({"t": "entry_support_add", "entry": e, "line": 0, "item": String(ids[0])})
		stats["practice_entry"] = e
		return
	stats["practice_entry"] = _write_entry(spec, folio)

# Repara la forma de un asiento de práctica: «según» en cada línea llena, ≥2 pasajes distintos, ≤ MAX_CLIPS recortes.
func _fix_practice_support(eid: String, formal: Array) -> void:
	var e: Dictionary = sim.st.ded.get("entries", {}).get(eid, {})
	if e.is_empty():
		return
	var lines: Array = e.get("lines", [])
	var codes: Array = []
	for f in formal:
		codes.append(String(f.get("code", "")) if typeof(f) == TYPE_DICTIONARY else String(f))
	var used: Array = Ledger.entry_clips_of(sim.st, e)
	if codes.has("demasiado_papel"):
		for li in lines.size():
			for it in (lines[li].get("support", []) as Array).duplicate():
				if Ledger.entry_clips_of(sim.st, sim.st.ded.entries[eid]).size() <= Ledger.MAX_CLIPS:
					break
				if (lines[li].support as Array).size() > 1:
					act({"t": "entry_support_remove", "entry": eid, "line": li, "item": String(it)}, true)
		used = Ledger.entry_clips_of(sim.st, sim.st.ded.entries[eid])
	if codes.has("falta_segun"):
		for li in lines.size():
			var filled := false
			for f in lines[li].get("fields", {}):
				if String(lines[li].fields[f]) != "":
					filled = true
			if filled and (lines[li].get("support", []) as Array).is_empty() and not _clip_ids().is_empty():
				act({"t": "entry_support_add", "entry": eid, "line": li, "item": String(used[0] if not used.is_empty() else _clip_ids()[0])}, true)
		used = Ledger.entry_clips_of(sim.st, sim.st.ded.entries[eid])
	if codes.has("una_fuente") and used.size() < Ledger.MAX_CLIPS:
		var have: Array = Ledger.passages_of(sim.st, used)
		var li0 := 0
		for li in lines.size():
			if not (lines[li].get("support", []) as Array).is_empty():
				li0 = li
				break
		var added := false
		for cl in _clip_ids():
			if used.has(cl):
				continue
			var p: Array = Ledger.passages_of(sim.st, [cl])
			if not p.is_empty() and not have.has(p[0]):
				act({"t": "entry_support_add", "entry": eid, "line": li0, "item": String(cl)}, true)
				added = true
				break
		if not added:
			# ningún recorte de otro pasaje: se recorta una oración de otra vista legible
			for x in sim.q_accessible():
				var nc := _clip_first_sentence(String(x.view), _clip_ids())
				if nc == "":
					continue
				var p2: Array = Ledger.passages_of(sim.st, [nc])
				if not p2.is_empty() and not have.has(p2[0]):
					act({"t": "entry_support_add", "entry": eid, "line": li0, "item": nc}, true)
					break

var _pplan := {}
func _practice_plan_cached() -> Dictionary:
	if _pplan.is_empty():
		var cid := String(stats.get("practice_cid", ""))
		for c in repo.conclusions():
			if String(c.id) != cid:
				continue
			for r in RouteDB.routes(repo, cid):
				var fr: Array = []
				var all := true
				for f in r.frags:
					var fd := _frag(String(f.ref), String(f.get("copy", "")), cid)
					if not clip_of.has(fd.key):
						all = false
						break
					fr.append(fd)
				if all and fr.size() >= 2:
					_pplan = {"cid": cid, "rid": String(r.id), "frags": fr}
					return _pplan
	return _pplan

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
		_build_entries()
	if deduce or value_mode != "oracle":
		_first_conclusion()
	pol_desk_extra()
	if String(sim.q_clock().phase) != "desk":
		return
	# tienda de Crane (gratis): ejemplares de Crane pendientes
	if deduce and _crane_pending() and Clock.place_open(repo, sim.st, HUB, SHOP, int(_c().day), String(_c().slot)).open and _once("crane"):
		if bool(_go(HUB, SHOP).get("ok", false)):
			return
	# pasada en limpio
	if int(_c().passes_left) > 0 and _once("pass"):
		var lot := pol_lot(int(_c().lot_size))
		if not lot.is_empty():
			var r := act({"t": "pass_clean", "entries": lot}, random_bot)
			_after_pass(lot, r)
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

func _after_pass(lot: Array, r: Dictionary) -> void:
	if not bool(r.get("ok", false)):
		return
	var by_entry := {}
	for cid in entry_of:
		by_entry[String(entry_of[cid])] = String(cid)
	if bool(r.get("inked", false)):
		for cid in r.get("sealed", []):
			if not stats.sealed.has(String(cid)):
				stats.sealed.append(String(cid))
		# un asiento entintado que selló otra conclusión (valores al azar) deja a la suya sin asiento
		var sealed: Dictionary = sim.st.ded.get("sealed", {})
		for e in lot:
			var tc := String(by_entry.get(String(e), ""))
			if tc != "" and not sealed.has(tc):
				entry_of.erase(tc)
		return
	# pasada fallida: los bots sin oráculo de valores prueban otro juego de valores en los asientos del lote
	if value_mode != "oracle":
		for e in lot:
			var tc2 := String(by_entry.get(String(e), ""))
			if tc2 == "":
				continue
			attempt[tc2] = int(attempt.get(tc2, 0)) + 1
			_reroll(String(e), tc2)

# Otro juego de valores al azar para un asiento a lápiz (mismo «según»).
func _reroll(eid: String, cid: String) -> void:
	var e: Dictionary = sim.st.ded.get("entries", {}).get(eid, {})
	if e.is_empty() or String(e.get("ink", "")) == "tinta":
		return
	var tid := String(e.get("template", ""))
	var lines: Array = e.get("lines", [])
	for li in lines.size():
		for fid in _sorted((lines[li].get("fields", {}) as Dictionary).keys()):
			var fd := _field_def(tid, li, String(fid))
			var cands := _field_candidates(fd)
			if cands.is_empty():
				continue
			var v := String(Det.pick(seed, [bot_name, cid, int(attempt.get(cid, 0)), li, String(fid)], cands))
			if v != String(lines[li].fields[fid]):
				act({"t": "entry_set", "entry": eid, "line": li, "field": String(fid), "value": v})

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
		_build_entries()
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
	if deduce or value_mode != "oracle":
		_first_conclusion()
	if deduce:
		_harvest()
		_build_entries()
		if int(_c().passes_left) > 0 and _once("pass"):
			var lot := pol_lot(int(_c().lot_size))
			if not lot.is_empty():
				var r := act({"t": "pass_clean", "entries": lot}, random_bot)
				_after_pass(lot, r)
				return
	_report(int(sim.q_report_status().get("n", 4)), true)

# ======================================================================= objetivos y plan (oráculo)
func _need() -> Array:
	var out: Array = []
	var sealed: Dictionary = sim.st.ded.get("sealed", {})
	for cid in (focus if not focus.is_empty() else RouteDB.mandatory(repo)):
		var c := String(cid)
		if sealed.has(c) or entry_of.has(c):
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
	# opcionales como compañeras de lote, si caben sin romper el plan de las obligatorias
	if fillers and focus.is_empty() and value_mode == "oracle":
		var sealed: Dictionary = sim.st.ded.get("sealed", {})
		for fc in FILLERS:
			if repo.conclusion(fc).is_empty() or sealed.has(fc) or entry_of.has(fc) or (targets.has(fc) and _complete(fc)):
				continue
			var p2: Dictionary = Feasibility.plan(prepo, i, [], ok_need + [fc])
			if bool(p2.get("ok", false)):
				ok_need.append(fc)
				p = p2
	for cid in p.get("routes", {}):
		_set_target(String(cid), String(p.routes[cid]))
	for x in p.get("plan", []):
		itinerary[int(x.idx)] = {"place": String(x.place), "area": String(x.area), "refs": x.get("refs", [])}

# Candidatos de material para cada afirmación de la confrontación: fragmentos de rutas (de cualquier conclusión) que
# llevan una etiqueta a: de su grupo refutador; un documento, en cada uno de sus ejemplares salvo la Sala de Lectura.
func _conf_plan() -> void:
	conf_frags = []
	var seen := {}
	for gi in CONF_GROUPS.size():
		var grp: Array = CONF_GROUPS[gi]
		for c in repo.conclusions():
			var cid := String(c.get("id", ""))
			for r in RouteDB.routes(repo, cid):
				for f in r.get("frags", []):
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
		if sim.st.ded.get("clips", {}).has(id) or sim.st.ded.get("entries", {}).has(id):
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
	targets[cid] = {"rid": rid, "subs": (r.get("subs", []) as Array).duplicate(), "frags": frs}

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
		if sim.st.ded.get("sealed", {}).has(cid) or entry_of.has(cid):
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

# Recorta exactamente el tramo #tid de una vista legible.
func _clip_tramo(view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var p: Dictionary = pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				if String(t.get("id", "")) == tid:
					var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(t.from), "len": int(t.to) - int(t.from)}, true)
					return String(r.get("clip", ""))
	return ""

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
					var r := act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(t.from), "len": int(t.to) - int(t.from)}, true)
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
			var r := act({"t": "clip_text", "src": {"kind": "line", "ref": uid}, "from": int(t.from), "len": int(t.to) - int(t.from)}, true)
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
				var r := act({"t": "clip_text", "src": {"kind": "diary", "ref": String(e.id)}, "from": int(t.from), "len": int(t.to) - int(t.from)}, true)
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
	var r := act({"t": "clip_measure", "src": src}, true)
	return String(r.get("clip", ""))

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

# ======================================================================= asientos
func _field_def(tpl_id: String, line: int, field: String) -> Dictionary:
	var tpl: Dictionary = repo.template(tpl_id)
	var lines: Array = tpl.get("lines", [])
	if line < 0 or line >= lines.size():
		return {}
	for fd in lines[line].get("fields", []):
		if String(fd.get("id", "")) == field:
			return fd
	return {}

# Valores aceptables AHORA por un campo (índice con el kind correcto o lista cerrada). Orden estable.
func _field_candidates(fd: Dictionary) -> Array:
	var acc: Dictionary = fd.get("accept", {})
	var out: Array = []
	if acc.has("list"):
		for x in repo.lists().get(String(acc.list), []):
			out.append(String(x.get("id", "")) if typeof(x) == TYPE_DICTIONARY else String(x))
			# medios: también valen los sensores ya indexados (GDD §8.2)
			if typeof(x) == TYPE_DICTIONARY:
				for en in x.get("entities", []):
					if _known(String(en)) and not out.has(String(en)):
						out.append(String(en))
		return out
	for e in Index.known(sim.st, repo):
		var id := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
		if id.begins_with("act.") or id == "":
			continue
		if Ledger.accept_error(sim.st, repo, acc, id) == "":
			out.append(id)
	return out

# Especificación de asiento {cid, template, lines:[{fields, support}]} con valores del oráculo y «según» por grupo.
# frags = fragmentos de la ruta (con clip en clip_of). {} si falta algo (valor no indexado, recorte faltante).
func _entry_spec(cid: String, frags: Array, subs: Array) -> Dictionary:
	var c: Dictionary = repo.conclusion(cid)
	var tid := String(c.get("template", ""))
	var tpl: Dictionary = repo.template(tid)
	if tpl.is_empty():
		return {}
	var clips: Array = []
	var by_sub := {}
	for f in frags:
		if not clip_of.has(f.key):
			return {}
		var cl := String(clip_of[f.key])
		if not clips.has(cl):
			clips.append(cl)
		var sb := String(f.get("sub", f.desc.get("sub", "")))
		if sb != "":
			if not by_sub.has(sb):
				by_sub[sb] = []
			by_sub[sb].append(cl)
	var lines: Array = []
	for ln in tpl.get("lines", []):
		lines.append({"fields": {}, "support": []})
	var ans: Dictionary = c.get("answers", {})
	var sealed: Dictionary = sim.st.ded.get("sealed", {})
	var alias_on := not Validator.alias_groups(repo, sealed).is_empty()
	# 1) medios por canal de subruta (C6: por_medio = canal de la 1.ª subruta, y_de = de la 2.ª)
	var ch_vals := []
	for sb in subs:
		var code := RouteDB.sub_channel(repo, String(sb))
		for m in repo.lists().get("medios", []):
			if typeof(m) == TYPE_DICTIONARY and String(m.get("ch", "")) == code:
				ch_vals.append(String(m.id))
	var list_fields_seen := 0
	for li in (tpl.lines as Array).size():
		for fd in tpl.lines[li].get("fields", []):
			var fid := String(fd.get("id", ""))
			var want = ans.get(fid)
			if typeof(want) == TYPE_DICTIONARY and want.has("list"):
				var v := ""
				if list_fields_seen < ch_vals.size():
					v = String(ch_vals[list_fields_seen])
				list_fields_seen += 1
				if v == "":
					var lc := _field_candidates(fd)
					v = String(lc[0]) if not lc.is_empty() else ""
				if v == "":
					_oracle("%s.%s: lista sin valores" % [cid, fid])
					return {}
				lines[li].fields[fid] = v
	var spec := {"cid": cid, "template": tid, "lines": lines}
	# 2) «según»: por grupo, un recorte con su etiqueta (resuelta con los medios ya elegidos)
	var gt: Dictionary = Validator.group_tags(repo, cid, spec)
	var used_cl := {}
	for g in gt.groups:
		var li2 := int(g.line)
		var got := ""
		var any := ""
		for cl in clips:
			var tags: Array = Clipper.get_clip(sim.st, String(cl)).get("tags", [])
			var hit := false
			for t in g.tags:
				if Validator.tag_match(tags, String(t)):
					hit = true
					break
			if not hit:
				continue
			if any == "":
				any = String(cl)
			# grupos de líneas distintas con la misma etiqueta (pares INC, C6): un recorte distinto por línea
			if (lines[li2].support as Array).has(String(cl)) or not used_cl.has(String(cl)):
				got = String(cl)
				break
		if got == "":
			got = any
		if got != "":
			used_cl[got] = true
		if got == "":
			_oracle("%s: ningún recorte de la ruta lleva el grupo %s (%s)" % [cid, g.id, str(g.tags)])
			return {}
		if not lines[li2].support.has(got):
			lines[li2].support.append(got)
	# 2b) el resto de los recortes de la ruta también va al «según» (dan el 2.º origen y el enlace por claves): a la línea
	#     de un grupo cuya etiqueta lleven, si no a la primera línea con «según»
	for cl in clips:
		var placed := false
		for ln0 in lines:
			if (ln0.support as Array).has(String(cl)):
				placed = true
		if placed:
			continue
		var tags2: Array = Clipper.get_clip(sim.st, String(cl)).get("tags", [])
		var dest := -1
		for g in gt.groups:
			for t in g.tags:
				if dest < 0 and Validator.tag_match(tags2, String(t)):
					dest = int(g.line)
		if dest < 0:
			for li4 in lines.size():
				if dest < 0 and not (lines[li4].support as Array).is_empty():
					dest = li4
		lines[maxi(dest, 0)].support.append(String(cl))
	# 3) valores: por campo, el primer valor aceptado e indexado, prefiriendo los que nombra el «según» de su línea
	#    (constraints.distinct: los campos del mismo grupo no repiten valor)
	var distinct_of := {}
	for con in c.get("constraints", []):
		if typeof(con) == TYPE_DICTIONARY and con.has("distinct"):
			for f0 in con.distinct:
				distinct_of[String(f0)] = con.distinct
	var taken := {}
	for li in (tpl.lines as Array).size():
		for fd in tpl.lines[li].get("fields", []):
			var fid := String(fd.get("id", ""))
			var want = ans.get(fid)
			if typeof(want) != TYPE_ARRAY or fid.begins_with("_"):
				continue
			var vals: Array = []
			for x in want:
				var s := String(x)
				if s.begins_with("@alias:"):
					if not alias_on:
						continue
					s = s.substr(7)
				vals.append(s)
			var pref: Array = (lines[li].support as Array) + clips
			if distinct_of.has(fid):
				var ex: Array = []
				for f1 in distinct_of[fid]:
					if taken.has(String(f1)):
						ex.append(String(taken[String(f1)]))
				vals = vals.filter(func(x): return not ex.has(String(x)))
			var v2 := _pick_value(fd, vals, pref)
			if v2 == "":
				waits[cid] = "%s: ningún valor aceptado está en el índice (%s)" % [fid, str(want)]
				return {}
			lines[li].fields[fid] = v2
			taken[fid] = v2
	# 4) líneas llenas sin grupo: un recorte que ya sostiene (cuenta una vez)
	for li3 in lines.size():
		if not lines[li3].fields.is_empty() and lines[li3].support.is_empty():
			lines[li3].support.append(String(clips[0]))
	waits.erase(cid)
	# 5) pesca: mismos campos y mismo «según», valores al azar entre los aceptables ahora
	if value_mode == "random":
		for li5 in lines.size():
			for fid5 in _sorted((lines[li5].fields as Dictionary).keys()):
				var cands := _field_candidates(_field_def(tid, li5, String(fid5)))
				if not cands.is_empty():
					lines[li5].fields[fid5] = String(Det.pick(seed, [bot_name, cid, int(attempt.get(cid, 0)), li5, String(fid5)], cands))
	return spec

# Primer valor aceptado e indexado; prefiere los que nombran los recortes dados (en orden: los de su línea primero).
func _pick_value(fd: Dictionary, vals: Array, clips: Array) -> String:
	var acc: Dictionary = fd.get("accept", {})
	for cl in clips:
		var ents: Array = Clipper.get_clip(sim.st, String(cl)).get("ents", [])
		for v in vals:
			if ents.has(v) and Ledger.accept_error(sim.st, repo, acc, String(v)) == "":
				return String(v)
	for v in vals:
		if Ledger.accept_error(sim.st, repo, acc, String(v)) == "":
			return String(v)
	for v in vals:
		if not acc.has("list") and _ensure_indexed(String(v)) and Ledger.accept_error(sim.st, repo, acc, String(v)) == "":
			return String(v)
	return ""

# Escribe un asiento a partir de una especificación. Devuelve el id ("" si algo falló).
func _write_entry(spec: Dictionary, folio := "") -> String:
	var fo := folio
	if fo == "":
		var head := ""
		for ln in spec.lines:
			for s in ln.support:
				if head == "":
					head = String(s)
		fo = String(act({"t": "folio_open", "clip": head}, true).get("folio", "")) if head != "" else "varios"
		if fo == "":
			fo = "varios"
	var e := String(act({"t": "entry_new", "folio": fo, "template": String(spec.template)}).get("entry", ""))
	if e == "":
		return ""
	for li in (spec.lines as Array).size():
		var ln: Dictionary = spec.lines[li]
		for fid in _sorted(ln.fields.keys()):
			act({"t": "entry_set", "entry": e, "line": li, "field": String(fid), "value": String(ln.fields[fid])})
		for s in ln.support:
			act({"t": "entry_support_add", "entry": e, "line": li, "item": String(s)})
	return e

# Arma los asientos de las conclusiones con todos sus fragmentos (oráculo: sólo si Validator los da por buenos).
func _build_entries() -> void:
	for cid in _sorted(targets.keys()):
		if entry_of.has(cid) or bad_entry.has(cid) or sim.st.ded.get("sealed", {}).has(cid) or not _complete(cid):
			continue
		var spec := _entry_spec(cid, targets[cid].frags, targets[cid].get("subs", []))
		if spec.is_empty():
			continue
		if value_mode == "oracle":
			var ev: Dictionary = Validator.evaluate(sim.st, repo, spec, {"practice": false})
			if not bool(ev.get("ok", false)) or String(ev.get("cid", "")) != cid:
				bad_entry[cid] = "evaluate %s" % str(ev)
				_oracle("%s (%s): el asiento armado no valida: %s" % [cid, targets[cid].rid, str(ev)])
				continue
		var e := _write_entry(spec)
		if e != "":
			entry_of[cid] = e

# Lote del oráculo: asientos válidos, conclusiones distintas, sin sellar, en ventana; prioridad a la ventana más corta.
func _oracle_lot(n: int) -> Array:
	if n <= 0:
		return []
	var ready: Array = []
	var sealed: Dictionary = sim.st.ded.get("sealed", {})
	var tk := Clipper.now_tk(sim.st)
	for cid in _sorted(entry_of.keys()):
		if sealed.has(cid):
			continue
		var e := String(entry_of[cid])
		var r: Dictionary = Validator.entry_ok(sim.st, repo, e)
		if not bool(r.get("ok", false)) or String(r.cid) != cid or not Validator._in_window(repo, cid, tk):
			continue
		ready.append({"cid": cid, "e": e, "last": RouteDB.last_idx(repo, cid)})
	if ready.size() < n:
		return []
	# prioridad: obligatorias de ventana más corta; las opcionales (FILLERS) sólo completan el lote
	ready.sort_custom(func(a, b):
		var fa := FILLERS.has(String(a.cid))
		var fb := FILLERS.has(String(b.cid))
		if fa != fb:
			return fb
		return int(a.last) < int(b.last) or (int(a.last) == int(b.last) and String(a.cid) < String(b.cid)))
	var out: Array = []
	for i in n:
		out.append(String(ready[i].e))
	# una obligatoria con una opcional de compañera sólo si hace falta: los lotes son exactos, y si quedan por sellar
	# (antes de la pasada final, cuyo lote de 1 es de las que sólo valen ahí: C12) un número impar de obligatorias más,
	# ésta se puede emparejar con una de ellas; la opcional queda para la última pasada doble.
	if n == 2 and not FILLERS.has(String(ready[0].cid)) and FILLERS.has(String(ready[1].cid)) and not _filler_needed(String(ready[0].cid)):
		return []
	# no se gasta un lote sólo de opcionales mientras falten obligatorias
	var all_fill := true
	for i in n:
		if not FILLERS.has(String(ready[i].cid)):
			all_fill = false
	if all_fill:
		for cid in RouteDB.mandatory(repo):
			if not sealed.has(String(cid)):
				return []
	return out

# ¿Hace falta una opcional para pasar ya la obligatoria cid? Sí si no queda otra pasada doble antes de la final, o si
# las demás obligatorias por sellar antes de la final (las que no sólo valen en ella) son pares: ésta quedaría sola.
func _filler_needed(cid: String) -> bool:
	var fin := RouteDB.final_idx(repo)
	var later := false
	for i in range(_idx() + 1, fin):
		var x := TimeKey.from_idx(i)
		if not x.is_empty() and Clock.passes_for(repo, int(x.day), String(x.slot)) > 0:
			later = true
			break
	if not later:
		return true
	var sealed: Dictionary = sim.st.ded.get("sealed", {})
	var k := 0
	for m in RouteDB.mandatory(repo):
		var ms := String(m)
		if ms == cid or sealed.has(ms):
			continue
		var v = repo.conclusion(ms).get("validate", {})
		var vf = v.get("from") if typeof(v) == TYPE_DICTIONARY else null
		if vf != null and TimeKey.idx_at_or_after(TimeKey.of(vf)) >= fin:
			continue
		k += 1
	return k % 2 == 0

# Lote sin oráculo de valores (pesca): asientos a lápiz de conclusiones (propias) distintas y sin sellar, al azar.
func _blind_lot(n: int) -> Array:
	if n <= 0:
		return []
	var sealed: Dictionary = sim.st.ded.get("sealed", {})
	var cands: Array = []
	for cid in _sorted(entry_of.keys()):
		if sealed.has(cid):
			continue
		var e: Dictionary = sim.st.ded.get("entries", {}).get(String(entry_of[cid]), {})
		if e.is_empty() or String(e.get("ink", "")) == "tinta":
			continue
		cands.append(String(entry_of[cid]))
	if cands.size() < n:
		return []
	rnd_n += 1
	return Det.shuffle(seed, [bot_name, "lote", rnd_n], cands).slice(0, n)

# ======================================================================= informes y confrontación (ayudas)
# Ítems (asientos y recortes) con sus categorías de Moran: [{item:{kind,id}, cats:[...]}].
func _report_candidates() -> Array:
	var out: Array = []
	for eid in _sorted(sim.st.ded.get("entries", {}).keys()):
		var e: Dictionary = sim.st.ded.entries[eid]
		if bool(e.get("practice", false)):
			continue
		var it := {"kind": "entry", "id": String(eid)}
		out.append({"item": it, "cats": MoranAgent.report_cats(sim.st, repo, it)})
	for cl in _clip_ids():
		var it2 := {"kind": "clip", "id": String(cl)}
		out.append({"item": it2, "cats": MoranAgent.report_cats(sim.st, repo, it2)})
	return out

# Ítem que refuta la afirmación step_n (grupo propio; nunca material secreto_camden). Recortes antes que asientos.
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
	for eid in _sorted(sim.st.ded.get("entries", {}).keys()):
		var it2 := {"kind": "entry", "id": String(eid)}
		if Deps.item_camden(sim.st, repo, it2):
			continue
		if _tags_hit(Validator.entry_tags(sim.st, String(eid)), grp):
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
