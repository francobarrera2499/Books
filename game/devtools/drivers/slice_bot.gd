# devtools/drivers/slice_bot.gd — el jugador del guion de W4-SLICE (ARCHITECTURE §10 ola 4). NO es un bot de T10: es el
# autor de devtools/scripts/slice_*.jsonl (lo usa devtools/drivers/slice_record.gd). Juega como el deductor (oráculo de
# rutas ★ para no perder el mejor final) y agrega los «golpes» del guion, para que la partida recorra la rebanada
# vertical de GDD §15.6 H3 y se vea como una investigación (cada día pasa algo):
#   1.M  Kensington: a Watson «La pared era a pique, ¿no?» (cebo K-W → HB1 por carta «—S.» el 4) y una pregunta.
#   2.N  informe 1 = un asiento verdadero (crédito ante Moran) + un recorte de un original P (M1: registran la buhardilla
#        y se llevan ESE original un día; HB10 lo devuelve por el mostrador de Crane).
#   actos ciegos: un telegrama a Meiringen (respuesta D27), una carta a Bath (D28), una copia pedida en Somerset House.
#   un anuncio «Al corresponsal S.» (cebo por la columna, K-T) el primer día que la forma existe.
#   franjas libres del plan: un paseo por el mundo (TOUR) con una pregunta a quien esté (temas que rotan).
#   final: según `ending` — "F1" errata a medida · "F2" informe fiel (un asiento que dice que Holmes vive) · "F3a" quemar ·
#        "F4" un lector distraído (pocas conclusiones, sin los golpes del escritorio ni de las visitas ni paseo; el informe 1
#        sí es el de f1 —crédito y M1—, los demás «Sin novedad»; confrontación callada).
#   1903: como la pantalla del epílogo (W4-EPILOGUE): publicar o no la fe de erratas (sólo fuera de F1), la tijera sobre
#        la Strand de octubre y cerrar el libro (leave).
# Todo por GameSim.apply (bot_base.act). Determinista con la semilla.
extends "res://devtools/bots/bot_deductor.gd"

var ending := "F1"
var beats_done := {}         # nombre -> true
var notes: Array = []        # [{n: índice de acción, text}] comentarios para el guion (slice_record los intercala)
var _topic_n := 0

# Paseo: franjas en que el plan no sale → lugar/área (sólo si está abierto).
const TOUR := [
	{"day": 2, "slot": "N", "place": "L3", "area": "calle", "why": "Baker Street de noche, desde la acera de enfrente"},
	{"day": 3, "slot": "T", "place": "L3", "area": "calle", "why": "Baker Street de día; Wiggins en la esquina"},
	{"day": 3, "slot": "N", "place": "L5", "area": "porteria", "why": "la portería del Diógenes"},
	{"day": 4, "slot": "M", "place": "L4", "area": "consulta", "why": "otra vez el doctor"},
	{"day": 4, "slot": "T", "place": "L3", "area": "interior", "why": "el vestíbulo de Mrs. Hudson"},
	{"day": 4, "slot": "N", "place": "L2", "area": "sala", "why": "la Sala de Periódicos"},
	{"day": 5, "slot": "T", "place": "L7", "area": "exterior", "why": "Park Lane 427, la casa del crimen"},
	{"day": 5, "slot": "N", "place": "L3", "area": "calle", "why": "Baker Street el sábado por la noche"},
	{"day": 6, "slot": "T", "place": "L4", "area": "estudio", "why": "el estudio de Watson, el domingo"},
	{"day": 7, "slot": "T", "place": "L8", "area": "interior", "why": "la casa vacía de enfrente, con el chico del agente"},
	{"day": 7, "slot": "N", "place": "L7", "area": "exterior", "why": "Park Lane de noche"},
	{"day": 9, "slot": "M", "place": "L5", "area": "porteria", "why": "la portería del club"},
	{"day": 9, "slot": "T", "place": "L3", "area": "calle", "why": "Baker Street la víspera"},
]
# Temas para preguntar en el paseo (rotan; el primero que el personaje admita desde la posición del turno).
const TOPICS := ["fina", "reichenbach", "baker_street", "park_lane", "ronald_adair", "cornisa", "journal_de_geneve", "times"]
const TELEGRAM_TO := ["steiler", "englischer_hof", "meiringen", "steiler_joven"]
const TELEGRAM_PARTS := ["cornisa", "reichenbach", "pared"]
const LETTER_TO := ["bath", "coronel_moriarty"]
const LETTER_PARTS := ["cartas_del_coronel", "coronel_moriarty", "profesor_moriarty", "reichenbach"]
const AD_BAIT := "as.cayeron"

func _init_bot() -> void:
	super._init_bot()
	bot_name = "slice"
	if ending == "F4":
		focus = ["C2", "C3", "C4"]
		fillers = false
		conf_cover = false

func note(text: String) -> void:
	notes.append({"n": sim.actions_log().size(), "text": text})

func _rich() -> bool:
	return ending != "F4"

# ------------------------------------------------------------------ escritorio
func pol_desk_extra() -> void:
	if not _rich():
		return
	var c: Dictionary = _c()
	var day := int(c.day)
	if day < 1 or String(c.phase) != "desk":
		return
	if not beats_done.has("telegram") and day >= 2:
		if _first_ok(TELEGRAM_TO, Composers.mail_options(sim.st, repo, "to")) == "":
			_ensure_indexed("steiler")   # el posadero, en la crónica (D03): un recorte lo pone en el índice
		var to := _first_ok(TELEGRAM_TO, Composers.mail_options(sim.st, repo, "to"))
		var part := _first_ok(TELEGRAM_PARTS, Composers.mail_options(sim.st, repo, "parts"))
		if to != "" and part != "":
			beats_done["telegram"] = true
			note("Acto ciego: telegrama a %s sobre %s (contesta Meiringen; nadie más lo ve)." % [to, part])
			act({"t": "compose_telegram", "to": to, "parts": [part]}, true)
	if not beats_done.has("letter") and day >= 3:
		if _first_ok(LETTER_TO, Composers.mail_options(sim.st, repo, "to")) == "":
			_ensure_indexed("coronel_moriarty")   # el encargo (D23) lo nombra
		var to2 := _first_ok(LETTER_TO, Composers.mail_options(sim.st, repo, "to"))
		var part2 := _first_ok(LETTER_PARTS, Composers.mail_options(sim.st, repo, "parts"))
		if to2 != "" and part2 != "":
			beats_done["letter"] = true
			note("Acto ciego: carta a %s sobre %s (Bath contesta; nadie más la ve)." % [to2, part2])
			act({"t": "compose_letter", "to": to2, "parts": [part2]}, true)
	if not beats_done.has("ad") and day >= 4 and ["M", "T"].has(String(c.slot)):
		_ensure_indexed("profesor_moriarty")
		var opts := Composers.options(sim.st, repo, "al_corresponsal", "frase")
		for o in opts:
			if String(o.id) == AD_BAIT:
				beats_done["ad"] = true
				note("Anuncio en la columna: «Al corresponsal S.: cayeron los dos» (cebo por el Times).")
				act({"t": "compose_ad", "form": "al_corresponsal", "fields": {"frase": AD_BAIT}}, true)
				break

static func _first_ok(want: Array, opts: Array) -> String:
	var ids: Array = []
	for o in opts:
		ids.append(String(o.get("id", "")))
	for w in want:
		if ids.has(String(w)):
			return String(w)
	return ""

# ------------------------------------------------------------------ salidas
func pol_outing() -> Dictionary:
	var c: Dictionary = _c()
	var day := int(c.day)
	var slot := String(c.slot)
	if _rich() and day == 1 and slot == "M" and not beats_done.has("watson_cebo"):
		note("Golpe del guion: Kensington, a Watson con la pared «a pique» (cebo K-W).")
		return {"place": "L4", "area": "consulta"}
	var planned := super.pol_outing()
	if not planned.is_empty() or not _rich():
		return planned
	for t in TOUR:
		if int(t.day) == day and String(t.slot) == slot and Clock.place_open(repo, sim.st, String(t.place), String(t.area), day, slot).open:
			note("Paseo del guion: %s." % String(t.why))
			return {"place": String(t.place), "area": String(t.area)}
	return {}

func pol_in_visit() -> void:
	if not _rich():
		return
	var v: Dictionary = sim.st.world.get("visit", {})
	var place := String(v.get("place", ""))
	var c: Dictionary = _c()
	if place == "L4" and int(c.day) == 1 and not beats_done.has("watson_cebo"):
		beats_done["watson_cebo"] = true
		var r := act({"t": "assert", "char": "watson", "assertion": "as.pared"}, true)
		if not bool(r.get("ok", false)):
			_err("guion: el cebo a Watson fue rechazado: " + String(r.get("err", "")))
		_ask("watson")
		return
	if place == "L6" and not beats_done.has("order_copy"):
		for x in sim.q_accessible():
			var did := String(x.get("doc", ""))
			if did != "" and String(repo.doc(did).get("clip_mode", "normal")) == "memoria":
				var r2 := act({"t": "order_copy", "doc": did}, true)
				if bool(r2.get("ok", false)):
					beats_done["order_copy"] = true
					note("Acto ciego: copia oficial de %s pedida en Somerset House." % did)
					break
	if place == "L1":
		return
	var key := "talk|" + String(v.get("id", ""))
	if beats_done.has(key):
		return
	beats_done[key] = true
	for ch in sim.q_scene().get("chars", []):
		if bool(ch.get("can_ask", false)):
			_ask(String(ch.id))

func _ask(cid: String) -> void:
	var tops: Array = []
	for t in sim.q_topics(cid):
		tops.append(String(t.get("id", "")) if typeof(t) == TYPE_DICTIONARY else String(t))
	for k in TOPICS.size():
		var want := String(TOPICS[(_topic_n + k) % TOPICS.size()])
		if tops.has(want):
			_topic_n += k + 1
			act({"t": "ask", "char": cid, "topic": want}, true)
			return

# ------------------------------------------------------------------ informes
func pol_report(n: int, final: bool) -> Dictionary:
	if final:
		match ending:
			"F1":
				if bool(sim.q_report_status().get("offered_erratum", false)):
					note("Informe final: la errata a medida que ofreció el librero.")
					return {"mode": "errata", "items": []}
				_err("guion F1: nadie ofreció la errata a medida")
				return {"mode": "nada", "items": []}
			"F2":
				var it := _item_with("holmes_vive")
				note("Informe final fiel: lo que Lisle sabe de Holmes, a Moran.")
				return {"mode": "items", "items": [it] if not it.is_empty() else []}
			"F3a":
				note("Informe final: Lisle lo quema.")
				return {"mode": "quemar", "items": []}
			_:
				return {"mode": "nada", "items": []}
	if n == 1:
		var items: Array = []
		var cr := credit_item()
		if not cr.is_empty():
			items.append(cr)
		var p := _p_original()
		if not p.is_empty():
			items.append(p)
		if items.is_empty():
			return {"mode": "nada", "items": []}
		note("Informe 1: un dato verdadero y un recorte de un original (crédito y M1).")
		return {"mode": "items", "items": items}
	return super.pol_report(n, final)

# Un recorte de un ejemplar de clase P que Moran sólo lee como «original» (nada sobre Holmes ni Watson).
func _p_original() -> Dictionary:
	for cl in _clip_ids():
		var it := {"kind": "clip", "id": String(cl)}
		if MoranAgent.report_cats(sim.st, repo, it) == ["original_p"]:
			return it
	return {}

# Un ítem cuyas categorías incluyen `want` (asientos antes que recortes).
func _item_with(want: String) -> Dictionary:
	var best := {}
	for c in _report_candidates():
		if not (c.cats as Array).has(want):
			continue
		if best.is_empty() or (String(best.item.kind) != "entry" and String(c.item.kind) == "entry"):
			best = c
	return best.get("item", {})

func pol_night_choice() -> String:
	return "baker_street" if ending == "F1" else "casa"

# Epílogo (oct. 1903) como lo juega la pantalla del epílogo (W4-EPILOGUE, ui/epilogue/epilogue_screen.gd): en F2/F3/F4 la
# oferta de publicar la fe de erratas (dos pasos; en F1 no se ofrece), después el último gesto —la tijera sobre la
# oración del hombre alto de anteojos de color en la Strand de octubre (tramo `_corte` de ui_text/epilogue_ui.json sobre
# `_ids.revista`)— y, al cerrar el libro, leave.
var _cut_done := false

func step() -> bool:
	if String(sim.q_clock().phase) != "epilogue" or _runaway != "":
		return super.step()
	stats.steps = int(stats.steps) + 1
	var final_id := String(sim.q_epilogue().get("ending", {}).get("ending", ""))
	if final_id != "F1" and not bool(sim.st.clock.get("errata_decided", false)):
		var yes := pol_publish_errata()
		note("1903: %s la fe de erratas." % ("publica" if yes else "guarda"))
		act({"t": "publish_errata", "yes": yes})
		return true
	if not _cut_done:
		_cut_done = true
		var ui: Dictionary = repo.files().get("ui_text/epilogue_ui.json", {})
		var view := String(ui.get("_ids", {}).get("revista", "D38@L1"))
		var tid := String(ui.get("_corte", "hombre_alto"))
		note("1903: la tijera sobre «A tall, thin man with coloured glasses…» (%s#%s)." % [view, tid])
		if _clip_tramo(view, tid) == "":
			_err("guion: el corte final (%s#%s) no se pudo hacer" % [view, tid])
		return true
	act({"t": "leave"})
	return String(sim.q_clock().phase) != "done"

func pol_publish_errata() -> bool:
	return ending == "F2"

func pol_confront(step_n: int) -> Dictionary:
	if ending == "F4":
		return {}
	return super.pol_confront(step_n)
