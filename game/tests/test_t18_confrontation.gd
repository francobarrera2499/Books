# T18 (W2-SCENES): confrontación del librero (GDD §8.8, ARCHITECTURE §5.7): un grupo refutador por afirmación,
# callar no cuenta como error, ≤3 errores (el 3.º termina), una sola vez; 4 aciertos -> completa y errata del librero.
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Confrontation = preload("res://core/scenes/confrontation.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const J = preload("res://core/util/j.gd")

# ítem de cada grupo (índice = afirmación - 1) y uno que no es de ninguno
const BY_STEP := ["RCH", "RCR", "RCA", "RCL"]

var rp

func before_each() -> void:
	Fakes.install()
	rp = Fakes.repo()

func after_each() -> void:
	Fakes.uninstall()

func _st():
	var st = Fakes.state(rp, {"day": 10, "slot": "M", "phase": "confront", "place": "L1", "visit_id": "S.HC07", "scene": "HC07", "chars": ["librero"]})
	Fakes.clip(st, "RCH", "Un trabajo inteligente, inteligente.", ["adjetivos_repetidos"], ["a:harris_es_moran"], "S.M7")
	Fakes.clip(st, "RCC", "Más arriba hay una cornisa.", ["cornisa"], ["a:cornisa_existe"], "D05")
	Fakes.clip(st, "RCR", "En la pared, una marca reciente.", ["raspadura"], ["a:raspadura_registrada"], "D05")
	Fakes.clip(st, "RCA", "Asiento 214: los guías hablaron al Journal.", [{"id": "act.5", "label": "asiento 214, mar. 27"}], ["a:ancla_kbm", "a:me_vigila_de_cerca"], "R.HA1.1")
	Fakes.clip(st, "RCL", "Dirección de su puño: esquina de Church Street.", ["librero"], ["a:librero_falso"], "D33")
	Fakes.clip(st, "RCX", "Un perro perdido.", ["perro"], ["a:ruido", "e:perro"], "D15.0327")
	Fakes.clip(st, "RCCAM", "La guillotina engrasada.", ["guillotina"], ["a:harris_es_moran", "f:secreto_camden"], "N.L8")
	Fakes.entry(st, "ASH", "T3", [{"fields": {"persona": "harris"}, "support": ["RCH"]}, {"fields": {"es": "moran"}, "support": ["RCX"]}])
	return st

func _go(st, step: int, id := "") -> Dictionary:
	var item := {} if id == "" else {"kind": "entry" if id.begins_with("AS") else "clip", "id": id}
	return Confrontation.act_confront(st, rp, {"step": step, "item": item})

func _texts(r: Dictionary) -> Array:
	return r.lines.map(func(l): return String(l.id))

func test_start_says_first_statement_idempotent():
	var st = _st()
	Confrontation.start(st, rp)
	Confrontation.start(st, rp)
	var s: Dictionary = Confrontation.status(st)
	eq(s.step, 1)
	eq(s.statement.id, "conf.1")
	eq(s.statement.who, "librero")
	eq(s.statement.origin, "S.HC07")
	eq(s.statement.text, "Su patrón, señor, es un caballero que llora a un hermano. (fixture librero)", "dialogue/librero.json primero")
	eq(s.patience, ["paquete", "sombrero"])
	eq(Dialogue.said(st, {"scene": "HC07"}).size(), 1, "una sola vez")

func test_one_group_per_statement():
	for k in range(1, 5):
		for wrong in BY_STEP:
			if wrong == BY_STEP[k - 1]:
				continue
			var st = _st()
			for s in range(1, k):
				ok(_go(st, s).ok, "callar hasta %d" % k)
			var r := _go(st, k, wrong)
			ok(r.ok, str(r))
			no(r.hit, "afirmación %d no se refuta con %s" % [k, wrong])
			eq(r.errors, 1)
			eq(r.step, k, "un error no avanza")
			var r2 := _go(st, k, BY_STEP[k - 1])
			ok(r2.hit, "afirmación %d se refuta con %s" % [k, BY_STEP[k - 1]])
	# grupo con dos etiquetas (2: cornisa_existe | raspadura_registrada)
	var st2 = _st()
	_go(st2, 1)
	ok(_go(st2, 2, "RCC").hit, "cornisa_existe también refuta la 2")
	# asiento: etiquetas por Validator.entry_tags
	var st3 = _st()
	ok(_go(st3, 1, "ASH").hit, "un asiento con harris_es_moran refuta la 1")

func test_silence_is_not_an_error():
	var st = _st()
	var r := {}
	for s in range(1, 5):
		r = _go(st, s)
		ok(r.ok)
		no(r.hit)
		eq(r.errors, 0, "callar no cuenta")
	ok(r.done)
	eq(_texts(r), ["conf.fin"])
	eq(Confrontation.status(st).estado, "")
	no(st.flags.has("confront_estado"), "parcial: el flag no se escribe")
	no(st.flags.has("errata_ofrecida"))

func test_three_errors_and_he_leaves():
	var st = _st()
	var r1 := _go(st, 1, "RCX")
	eq(_texts(r1), ["conf.1.no", "conf.paquete"])
	eq(Confrontation.status(st).patience, ["sombrero"])
	var r2 := _go(st, 1, "RCC")
	eq(_texts(r2), ["conf.1.no", "conf.sombrero"])
	eq(Confrontation.status(st).patience, [])
	no(r2.done)
	var r3 := _go(st, 1, "RCL")
	eq(_texts(r3), ["conf.1.no", "conf.se_va"])
	ok(r3.done)
	eq(r3.errors, 3)
	eq(r3.lines[-1].text, "Buenos días, señor.")
	eq(st.flags.confront_estado, "incompleta")
	var before := J.stringify_canon(st.scenes)
	eq(_go(st, 1, "RCH").err, "terminada", "no se repite")
	eq(_go(st, 2).err, "terminada")
	eq(J.stringify_canon(st.scenes), before)

func test_errors_across_statements_count_together():
	var st = _st()
	_go(st, 1, "RCX")
	ok(_go(st, 1, "RCH").hit)
	_go(st, 2, "RCX")
	ok(_go(st, 2, "RCR").hit)
	var r := _go(st, 3, "RCX")
	ok(r.done, "tercer error en total")
	eq(st.flags.confront_estado, "incompleta")

func test_four_hits_complete_and_offer():
	var st = _st()
	var r := {}
	for s in range(1, 5):
		r = _go(st, s, BY_STEP[s - 1])
		ok(r.hit, "acierto %d" % s)
		if s == 3:
			eq(r.line.text, "Asiento 214, el martes 27. Bien leído, señor.", "cita el acto real del ítem, dicho en voz alta")
		if s == 2:
			eq(r.lines[-1].text, "Nadie lo lee a usted, señor. Usted lee demasiado.", "ui_text")
	ok(r.done)
	eq(_texts(r), ["conf.4.si", "conf.nota", "conf.oferta", "conf.silencio"])
	ok(String(r.lines[1].text).contains("Faltan cinco tomos en un estante de Kensington."))
	eq(st.flags.confront_estado, "completa")
	eq(st.flags.errata_ofrecida, "librero")
	eq(Confrontation.status(st).hits, 4)
	ok(Confrontation.status(st).done)
	eq(Confrontation.status(st).statement, {})

func test_mycroft_offer_wins():
	var st = _st()
	st.flags["errata_ofrecida"] = "mycroft"
	var r := {}
	for s in range(1, 5):
		r = _go(st, s, BY_STEP[s - 1])
	eq(_texts(r), ["conf.4.si", "conf.nota", "conf.silencio"], "sin oferta si Mycroft ya la hizo")
	eq(st.flags.errata_ofrecida, "mycroft")

func test_text_sources_by_priority():
	var st = _st()
	var r := _go(st, 1)
	eq(r.lines[0].id, "conf.2")
	eq(r.lines[0].text, "El relato del doctor es exacto en lo esencial: uno cayó y el otro no volvió. (fixture HC07)", "scenes/HC07 si no está en librero.json")

func test_camden_material_never_hits():
	var st = _st()
	var r := _go(st, 1, "RCCAM")
	no(r.hit, "secreto_camden: el librero no lo lee")
	eq(r.errors, 1)

func test_bad_actions_do_not_mutate():
	var st = _st()
	Confrontation.start(st, rp)
	var before := J.stringify_canon({"s": st.scenes, "f": st.flags, "q": st.seq})
	eq(_go(st, 2).err, "paso")
	eq(_go(st, 1, "RCNADA").err, "no_existe")
	eq(Confrontation.act_confront(st, rp, {"step": 1, "item": {"kind": "pair", "id": "RCH"}}).err, "forma")
	eq(Confrontation.act_confront(st, rp, {"step": 1, "item": "x"}).err, "forma")
	eq(J.stringify_canon({"s": st.scenes, "f": st.flags, "q": st.seq}), before)
	eq(st.pending_events, [], "la confrontación no es pública")

func test_lazy_start_without_start_call():
	var st = _st()
	var r := _go(st, 1, "RCH")
	ok(r.ok and r.hit, str(r))
	eq(Confrontation.status(st).step, 2)

func test_real_texts_resolve():
	var r = repo()
	var st = Fakes.state(r, {"day": 10, "phase": "confront"})
	var ids: Array = []
	for k in range(1, 5):
		ids.append_array(["conf.%d" % k, "conf.%d.si" % k, "conf.%d.no" % k])
	ids.append_array(["conf.paquete", "conf.sombrero", "conf.se_va", "conf.nota", "conf.oferta", "conf.silencio", "conf.fin"])
	for id in ids:
		var ln: Dictionary = Confrontation._say(st, r, id, {"acto": "Asiento 214"})
		ok(String(ln.text).strip_edges() != "", "texto de " + id)
		no(String(ln.text).contains("${"), "sin placeholders: " + id)
