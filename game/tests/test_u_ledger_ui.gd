# W3-LEDGER: el libro mayor (ui/ledger/*; ARCHITECTURE §6.6, GDD§8). GameSim REAL sobre la estructura de data/ + el
# contenido mínimo de tests/fixtures/integ (el mismo dataset que tests/test_i_integration.gd, modo «fixture»).
# Vista-modelo (páginas, rótulos, opciones por tipo, tarjetas, chequeo formal por línea, sello y lote, sin etiquetas
# ocultas) y la UI headless con la API que usan los clics: prólogo (folio -> asiento -> práctica C1 en tinta) con el
# tutorial que habilita cada verbo; día 1 (folio de FINA -> C2 y C3 -> sello con confirmación -> tinta); pasada seca
# (todo o nada, tampón seco, «Alguno no se sostiene.»); el formal no gasta; arrastrar y soltar (según, campo, nuevo
# folio); electores; tinta no editable; acoplado angosto; el autoload Game (act y guardado).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const Integ = preload("res://tests/test_i_integration.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const Validator = preload("res://core/deduction/validator.gd")
const Ledger = preload("res://ui/ledger/ledger.gd")
const Model = preload("res://ui/ledger/ledger_model.gd")
const Widgets = preload("res://ui/kit/widgets.gd")

static var _repo_cache = null

var _t = null
var _lg = null

func _integ():
	if _t == null:
		_t = Integ.new()
		_t._cur = _cur
	return _t

func _r():
	if _repo_cache == null:
		_repo_cache = _integ()._repo("fixture")
	return _repo_cache

func after_each() -> void:
	if _lg != null and is_instance_valid(_lg):
		_lg.get_parent().remove_child(_lg)
		_lg.free()
	_lg = null
	_t = null

func _ledger(sim) -> Node:
	_lg = Ledger.new()
	_lg.sounds = false
	_lg.sim = sim
	tree.root.add_child(_lg)
	return _lg

func _act(sim, a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	ok(bool(r.get("ok", false)), "%s -> %s" % [str(a), str(r)])
	return r

func _find(n: Node, nm: String) -> Node:
	if n.name == nm:
		return n
	for c in n.get_children():
		var f := _find(c, nm)
		if f != null:
			return f
	return null

func _all_text(n: Node, out: Array) -> void:
	if n is Label:
		out.append(String(n.text))
	elif n is Button:
		out.append(String(n.text))
	elif n is RichTextLabel:
		out.append(n.get_parsed_text())
	for c in n.get_children():
		_all_text(c, out)

# Prólogo hasta el paso «folio» (recortar y vincular los hacen el lector y el cuaderno: aquí, el sim).
func _prologue(sim) -> Dictionary:
	var t = _integ()
	var c_aviso: String = t._clip_tramo(sim, "D23@L1", "aviso")
	var c_abril: String = t._clip_tramo(sim, "D01.REDH@tomo", "abril")
	var c_oct: String = t._clip_tramo(sim, "D01.REDH@tomo", "octubre")
	return {"aviso": c_aviso, "abril": c_abril, "oct": c_oct}

# Día 1 por la mañana: Sala de Lectura (D05: marque, corniche) y la tienda de Crane (D03: sheer). Deja el escritorio.
func _day1(sim) -> Dictionary:
	var t = _integ()
	_act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	_act(sim, {"t": "slip", "doc": "D05"})
	var c_marque: String = t._clip_tramo(sim, "D05@BM", "marque")
	var c_corniche: String = t._clip_tramo(sim, "D05@BM", "corniche")
	_act(sim, {"t": "leave"})
	_act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	var c_sheer: String = t._clip_tramo(sim, "D03@Crane", "sheer")
	_act(sim, {"t": "leave"})
	return {"marque": c_marque, "corniche": c_corniche, "sheer": c_sheer}

# Prólogo completo por la UI del libro + aviso + dormir. Devuelve los recortes.
func _through_prologue(sim, lg) -> Dictionary:
	var c := _prologue(sim)
	_act(sim, {"t": "link", "a": c.abril, "b": c.oct, "note": ""})
	var fo: Dictionary = lg.new_folio_from(c.abril)
	var e: String = lg.new_entry("T1").get("entry", "")
	lg.set_field(e, 0, "fuente_a", "redh")
	lg.set_field(e, 0, "dice_a", "abril_27_1890")
	lg.set_field(e, 1, "fuente_b", "redh")
	lg.set_field(e, 1, "dice_b", "octubre_9_1890")
	lg.add_support(e, 0, c.abril)
	lg.add_support(e, 1, c.oct)
	lg.practice(e)
	_act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_act(sim, {"t": "sleep"})
	c["folio"] = String(fo.get("folio", ""))
	c["practice_entry"] = e
	return c

# Arrastre nativo de Godot sobre un control: force_drag + movimiento + soltar el botón en su centro.
func _drop_on(target: Control, data: Dictionary) -> void:
	var vp := target.get_viewport()
	var at: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var src := Control.new()
	tree.root.add_child(src)
	src.force_drag(data, null)
	for p in [at + Vector2(3, 3), at]:
		var mm := InputEventMouseMotion.new()
		mm.position = p
		mm.global_position = p
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mm, true)
		await tree.process_frame
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = at
	mb.global_position = at
	vp.push_input(mb, true)
	await tree.process_frame
	await tree.process_frame
	src.queue_free()

# ---------------------------------------------------------------- vista-modelo
func test_model_templates_and_labels():
	var sim = GameSim.new(_r(), 7)
	var ts := Model.templates(sim)
	eq(ts.size(), 9, "nueve plantillas")
	eq(String(ts[0].id), "T1", "orden T1…T9")
	eq(String(ts[8].id), "T9", "orden T1…T9")
	ok(String(ts[4].shape).contains("(A o contra)"), "las líneas opcionales van entre paréntesis")
	eq(Model.field_label("Qué o a quién: ___"), "Qué o a quién:", "el rótulo conserva el artículo y los dos puntos")
	eq(Model.value_text(sim, {"list": "verbos"}, "separarse_de"), "separarse de", "verbos: «_» -> espacio")
	eq(Model.value_text(sim, {"list": "medios"}, "la_calle"), "la calle", "medios: su rótulo")
	eq(Model.value_text(sim, {"kinds": ["persona"]}, "watson"), "el doctor Watson", "entidad: su nombre")
	eq(Model.num_of("AS012"), 12)
	eq(Model.short("uno dos tres cuatro cinco seis", 14), "uno dos tres…")

func test_model_field_options_by_kind_and_list():
	var sim = GameSim.new(_r(), 7)
	_prologue(sim)
	var idx: Array = sim.q_index()
	var per := Model.field_options(sim, {"kinds": ["persona"]})
	ok(not per.is_empty(), "hay personas en el índice tras recortar el encargo")
	for o in per:
		var k := ""
		for r in idx:
			if String(r.id) == String(o.id):
				k = String(r.kind)
		eq(k, "persona", "sólo personas para «Persona:» (%s)" % o.id)
	var rel := Model.field_options(sim, {"list": "relaciones"})
	eq(rel.size(), 6, "seis relaciones")
	eq(String(rel[0].text), "lee a", "rótulo de lista")
	var with_clear := Model.field_options(sim, {"list": "relaciones"}, "lee_a")
	ok(bool(with_clear[0].get("clear", false)) and String(with_clear[0].id) == "", "«Dejar en blanco» primero si hay valor")
	var med := Model.field_options(sim, {"list": "medios"})
	ok(med.size() >= 5, "los cinco medios")
	for o in med:
		if not ["sala_lectura", "consultorio", "221b", "la_calle", "columna"].has(String(o.id)):
			ok(idx.any(func(r): return String(r.id) == String(o.id)), "un vigía como medio sólo si está en el índice: %s" % o.id)

func test_model_pages_entries_and_cards():
	var sim = _integ()._walk(_r())
	ok(sim != null and _integ()._errs.is_empty(), "recorrido de integración: %s" % str(_integ()._errs.slice(0, 4)))
	if sim == null:
		return
	var ps := Model.pages(sim)
	var ids: Array = ps.map(func(p): return String(p.id))
	eq(ids, ["reglas", "varios", "FO001", "FO002", "FO003", "erratas"], "páginas en orden: reglas, varios, folios, erratas")
	ok(String(ps[2].head.text) != "" and String(ps[2].head_short) != "", "el folio muestra el recorte que lo abrió")
	var fo3: Array = Model.page_entries(sim, "FO003")
	eq(fo3.size(), 1, "folio de C6 con un asiento")
	var vm := Model.entry_vm(sim, String(fo3[0]))
	eq(String(vm.tname), "Relación", "T6 = Relación")
	eq(String(vm.ink), "lapiz", "a lápiz")
	eq(String(vm.lines[0].fields[0].text), "el señor Mycroft Holmes", "valor por su nombre")
	eq((vm.lines[0].support as Array).size(), 2, "dos tiras en el según de la línea 1")
	ok(not bool(vm.lines[0].falta_segun) and (vm.notes as Array).is_empty(), "C6 completo: sin avisos formales")
	ok(not vm.has("cid") and not str(vm).contains("a:acto") and not str(vm).contains("ancla_"), "la vista-modelo no trae la conclusión ni etiquetas ocultas")
	var fo2: Array = Model.page_entries(sim, "FO002")
	for e in fo2:
		var v2 := Model.entry_vm(sim, String(e))
		eq(String(v2.ink), "tinta", "C2/C3 en tinta")
		no(bool(v2.editable), "la tinta no se edita")
	var summ := Model.entry_summary(vm)
	ok(summ.contains("Persona: el señor Mycroft Holmes"), "resumen del renglón: " + summ)
	var opts := Model.support_options(sim, [])
	ok(opts.size() >= 10, "elector de recortes con todo lo recortado")
	ok(int(String(opts[0].id).substr(2)) > int(String(opts[1].id).substr(2)), "más nuevos primero")
	for o in opts:
		ok(not o.has("tags") and not str(o).contains("a:"), "sin etiquetas ocultas en el elector")

func test_model_formal_notes_per_line_and_entry():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var e := String(_act(sim, {"t": "entry_new", "folio": "varios", "template": "T5"}).get("entry", ""))
	var vm0 := Model.entry_vm(sim, e)
	no(bool(vm0.started), "asiento en blanco: sin empezar")
	ok((vm0.notes as Array).is_empty() and not bool(vm0.lines[0].falta_segun), "en blanco no se reprocha nada")
	_act(sim, {"t": "entry_set", "entry": e, "line": 0, "field": "persona", "value": "mycroft"})
	var vm1 := Model.entry_vm(sim, e)
	ok(bool(vm1.lines[0].falta_segun), "línea llena sin según -> «Falta un según.» junto a la línea")
	has(vm1.notes, "una_fuente", "una sola fuente (aviso del asiento)")
	no((vm1.notes as Array).has("falta_segun"), "falta_segun va junto a la línea, no al pie")
	var clips: Array = sim.q_clips()
	_act(sim, {"t": "entry_support_add", "entry": e, "line": 0, "item": String(clips[0].id)})
	var vm2 := Model.entry_vm(sim, e)
	no(bool(vm2.lines[0].falta_segun), "con según ya no falta")
	for i in range(1, 5):
		_act(sim, {"t": "entry_support_add", "entry": e, "line": 1, "item": String(clips[i].id)})
	has(Model.entry_vm(sim, e).notes, "demasiado_papel", "más de cuatro recortes")

func test_model_seal_state_and_lot():
	var sim = GameSim.new(_r(), 7)
	var st := Model.seal_state(sim, [])
	eq(String(st.reason), "practica", "prólogo: sólo práctica")
	ok(bool(st.dry), "tampón seco en el prólogo (sin pasadas)")
	var w = _integ()._walk(_r())
	if w == null:
		fail("recorrido")
		return
	var st2 := Model.seal_state(w, [])
	eq(int(st2.lot_size), 2, "lote de dos")
	eq(String(st2.reason), "lote", "sin marcar: falta el lote")
	no(bool(st2.dry), "día 4 por la mañana: tampón entintado")
	var fo3: Array = Model.page_entries(w, "FO003")
	var varios: Array = Model.page_entries(w, "varios")
	ok(bool(Model.seal_state(w, [fo3[0], varios[0]]).ready), "dos marcados: listo")
	no(Model.lot_eligible(w, String(Model.page_entries(w, "FO002")[0])), "la tinta no va al sello")
	no(Model.lot_eligible(w, String(Model.page_entries(w, "FO001")[0])), "la práctica no va al sello")
	eq(Model.clean_lot(w, [fo3[0], "AS999", fo3[0], varios[0]]), [fo3[0], varios[0]], "lote limpio")
	_act(w, {"t": "go", "place": "L1", "area": "tienda"})
	eq(String(Model.seal_state(w, [fo3[0], varios[0]]).reason), "fuera", "de visita: el sello no sale del escritorio")

# ---------------------------------------------------------------- UI
# GDD_v2 §B.6.1, §C.3: la primera página es «Lo que me preguntaron» (citas textuales) con «Cómo se anota una conclusión»
# plegado debajo; ya no están el «Modo de asentar» ni la lista de plantillas; al principio no hay sello ni «Nueva hoja».
func test_ui_first_page_questions_and_folded_rules():
	var sim = GameSim.new(_r(), 7)
	var lg = _ledger(sim)
	lg.open()
	eq(String(lg.page), "reglas", "la primera vez abre en la primera página")
	var txt: Array = []
	_all_text(lg, txt)
	var all := "\n".join(PackedStringArray(txt))
	if sim.repo.texts().has("preg.titulo"):
		ok(all.contains(sim.repo.text("preg.titulo")), "título «Lo que me preguntaron»")
	for q in sim.q_questions():
		ok(all.contains(String(q.text).strip_edges()), "la pregunta citada tal cual: %s" % String(q.text).left(40))
	for k in range(1, 5):
		no(all.contains(sim.repo.text("ledger.modo.%d" % k).replace("<i>", "").replace("</i>", "")), "sin «Modo de asentar» %d" % k)
	var fold = _find(lg, "ComoSeAnota")
	ok(fold != null, "«Cómo se anota una conclusión» está")
	no(bool(fold.get_meta("open", true)), "y está plegado")
	no((fold.get_meta("content") as Control).visible, "las reglas no se ven de entrada")
	Widgets.set_fold(fold, true)
	ok((fold.get_meta("content") as Control).visible, "se despliegan con un clic")
	var txt2: Array = []
	_all_text(fold.get_meta("content"), txt2)
	var all2 := "\n".join(PackedStringArray(txt2))
	for k in range(1, 6):
		ok(all2.contains(sim.repo.text("rules.%d" % k).replace("<i>", "").replace("</i>", "")), "regla %d" % k)
	Widgets.set_fold(fold, false)
	var st: Dictionary = lg.debug_state()
	no(st.seal, "prólogo: sin sello")
	no(st.new_folio, "prólogo: sin «Nueva hoja»")
	no(st.nb_tab, "el cuaderno no es una pestaña del libro")
	eq(st.tabs, ["reglas"], "una sola página: %s" % str(st.tabs))

# GDD_v2 §B.7, §C.2–C.3: día 1, «Primera conclusión». «Nueva hoja» aparece cuando la guía llega a la hoja (lg.hoja_nueva);
# el elector de tipos muestra tres y «Más tipos…»; hasta la práctica no hay sello ni «Al sello» (cada conclusión ofrece el
# sello de práctica); «Práctica» y el sello aparecen después, con sus banderas.
func test_ui_day1_first_conclusion_reveal():
	var sim = GameSim.new(_r(), 7)
	var lg = _ledger(sim)
	lg.open()
	var c := _prologue(sim)
	_act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_act(sim, {"t": "sleep"})
	eq(String(sim.q_clock().phase), "desk", "día 1")
	lg.refresh()
	no(lg.debug_state().new_folio, "antes de juntar los recortes, sin «Nueva hoja»")
	no(lg.debug_state().seal, "sin sello antes de practicar")
	_act(sim, {"t": "link", "a": c.abril, "b": c.oct, "note": "dos fechas"})
	lg.refresh()
	ok(lg.debug_state().new_folio and lg._new_folio.enabled, "paso «hoja»: «Nueva hoja» a la vista")
	ok(_find(lg, "AyudaHoja") != null, "una línea de ayuda hasta la primera hoja")
	lg.on_new_folio(lg._new_folio)
	ok(lg.picker() != null, "clic en «Nueva hoja» -> elector de recortes")
	ok(lg.picker().pick_id(c.abril), "elegir el recorte")
	await tree.process_frame
	eq(sim.q_ledger().folios.size(), 1, "hoja abierta")
	eq(String(lg.page), String(sim.q_ledger().folios[0].id), "el libro pasa a la hoja nueva")
	lg.refresh()
	eq(_find(lg, "AyudaHoja"), null, "la ayuda de la hoja se fue con el primer uso")
	var add: Button = _find(lg, "NuevoAsiento")
	ok(add != null and not add.disabled, "«Nueva conclusión»")
	ok(_find(lg, "AyudaConclusion") != null, "una línea de ayuda hasta la primera conclusión")
	lg.on_new_entry(add)
	ok(lg.picker() != null, "elector de tipos")
	eq(lg.picker().visible_ids(), ["T1", "T2", "T5", Model.MORE_ID], "tres tipos y «Más tipos…»")
	eq(lg.picker().options.size(), 10, "los nueve tipos están (seis plegados)")
	lg.picker().pick_id(Model.MORE_ID)
	eq(lg.picker().visible_ids().size(), 9, "«Más tipos…» despliega los nueve")
	lg.picker().pick_id("T1")
	await tree.process_frame
	var e: String = lg.selected
	ok(e != "" and not bool(sim.q_entry(e).get("practice", false)), "conclusión del día 1 (no es de la página de práctica)")
	lg.refresh()
	eq(_find(lg, "AlSello"), null, "sin sello todavía: sin casilla «Al sello»")
	ok(_find(lg, "AyudaPruebas") != null, "ayuda de «Pruebas» hasta la primera prueba")
	var v: Button = _find(_find(lg, "Campo_fuente_a"), "Valor")
	lg.on_field(e, 0, "fuente_a", {"kinds": ["documento", "persona"]}, "", v)
	ok(lg.picker() != null and lg.picker().pick_id("redh"), "elector del campo con el documento recortado")
	await tree.process_frame
	eq(String(sim.q_entry(e).lines[0].fields.get("fuente_a", "")), "redh", "campo escrito")
	lg.set_field(e, 0, "dice_a", "abril_27_1890")
	lg.set_field(e, 1, "fuente_b", "redh")
	lg.set_field(e, 1, "dice_b", "octubre_9_1890")
	lg.refresh()
	ok(_find(lg, "FaltaSegun") != null, "Lisle: «Falta un según.» junto a la línea")
	lg.on_support_add(e, 0, _find(lg, "Anadir"))
	ok(lg.picker() != null and lg.picker().pick_id(c.abril), "elector del según")
	await tree.process_frame
	lg.add_support(e, 1, c.oct)
	lg.refresh()
	eq(_find(lg, "FaltaSegun"), null, "ya no falta según")
	eq(_find(lg, "AyudaPruebas"), null, "la ayuda de «Pruebas» se fue")
	var pb: Button = _find(lg, "Practicar")
	ok(pb != null and not pb.disabled, "paso «practicar»: el sello de práctica")
	no(_find(lg, "AlSello") != null, "la práctica no va al sello del lote")
	var r: Dictionary = lg.practice(e)
	ok(bool(r.get("inked", false)), "C1.10 en tinta: %s" % str(r))
	eq(lg.last_note(), sim.repo.text("practice.ok").replace("<i>", "").replace("</i>", ""), "Lisle: práctica en tinta")
	lg.refresh()
	ok(_find(lg, "VistoGrande") != null, "la conclusión muestra el sello")
	await tree.process_frame
	await tree.process_frame
	# la cabecera con el sello («CONFIRMADO» + «confirmada · práctica») cabe en la hoja: la página no se ensancha
	# (antes la hoja derecha crecía ~35 px y tapaba las pestañas)
	ok(lg._left.size.x <= Ledger.PAGE_L.size.x + 0.5 and lg._right.size.x <= Ledger.PAGE_R.size.x + 0.5,
		"las hojas no se ensanchan con el sello: %s / %s" % [str(lg._left.size.x), str(lg._right.size.x)])
	ok(sim.st.ded.sealed.is_empty(), "la práctica no sella nada")
	ok(lg.debug_state().tabs.has("erratas"), "aparece «Práctica» (lg.practica): %s" % str(lg.debug_state().tabs))
	eq(lg.debug_state().tabs[lg.debug_state().tabs.size() - 1], "erratas", "«Práctica» va al final")
	no(lg.debug_state().seal, "sin un borrador que confirmar, todavía sin sello")
	var e2: String = lg.new_entry("T2").get("entry", "")
	lg.refresh()
	ok(e2 != "" and lg.debug_state().seal, "práctica hecha y un borrador: aparece el sello (lg.sello)")
	ok(_find(lg, "AlSello") != null, "y la casilla «Al sello»")
	no(lg.debug_state().tabs.has("varios"), "sin conclusiones sueltas no hay «Varios»")

func test_ui_day1_folio_entries_and_inked_pass():
	var sim = GameSim.new(_r(), 7)
	var lg = _ledger(sim)
	lg.open()
	_through_prologue(sim, lg)
	eq(String(sim.q_clock().phase), "desk", "día 1, escritorio")
	var c := _day1(sim)
	var fo: Dictionary = lg.new_folio_from(c.sheer)
	ok(bool(fo.get("ok", false)), "folio con FINA: %s" % str(fo))
	var e2: String = lg.new_entry("T2").get("entry", "")
	lg.set_field(e2, 0, "fuente", "fina")
	lg.set_field(e2, 0, "calla", "raspadura")
	lg.set_field(e2, 1, "consta_en", "journal_de_geneve")
	lg.add_support(e2, 0, c.sheer)
	lg.add_support(e2, 1, c.marque)
	var e3: String = lg.new_entry("T1").get("entry", "")
	lg.set_field(e3, 0, "fuente_a", "fina")
	lg.set_field(e3, 0, "dice_a", "a_pique")
	lg.set_field(e3, 1, "fuente_b", "journal_de_geneve")
	lg.set_field(e3, 1, "dice_b", "cornisa")
	lg.add_support(e3, 0, c.sheer)
	lg.add_support(e3, 1, c.corniche)
	no(bool(sim.q_entry(e2).practice), "después del prólogo, un folio no es de práctica")
	lg.stamp()
	eq(lg.confirm_dialog(), null, "sin lote marcado no hay confirmación")
	eq(lg.last_note(), sim.repo.text("pass.lote", {"n": "dos"}), "Lisle: se pasa de dos en dos")
	ok(lg.toggle_lot(e2) and lg.toggle_lot(e3), "marcar dos")
	var e_extra: String = lg.new_entry("T3").get("entry", "")
	no(lg.toggle_lot(e_extra), "un tercero no entra en el lote")
	lg.delete_entry(e_extra)
	lg.refresh()
	eq(lg._seal.cards.size(), 2, "el sello muestra los dos marcados")
	var left_before: int = int(sim.q_clock().passes_left)
	eq(left_before, 1, "una pasada en la franja")
	lg.stamp()
	ok(lg.confirm_dialog() != null, "confirmación en dos pasos antes de estampar")
	eq(int(sim.q_clock().passes_left), 1, "confirmar no se adelanta: nada gastado todavía")
	lg.confirm_dialog().ok_button.pressed.emit()
	await tree.process_frame
	eq(String(sim.q_entry(e2).ink), "tinta", "C2 en tinta")
	eq(String(sim.q_entry(e3).ink), "tinta", "C3 en tinta")
	eq(sim.st.ded.sealed.keys().size(), 2, "dos sellados")
	eq(int(sim.q_clock().passes_left), 0, "la pasada se gastó")
	eq(lg.lot, [], "el lote se vacía")
	eq(lg.last_note(), sim.repo.text("pass.ok"), "«Visto.»")
	ok(bool(Model.seal_state(sim, []).dry), "el tampón queda seco")
	# la impresión cae sobre los papelitos de lo pasado: mientras dura, las ranuras los conservan; después, vacías
	ok(lg._seal.holding(), "impresión sobre los asientos pasados")
	var s0: Control = lg._seal.slot_node(0)
	ok(s0 != null and s0.has_meta("eid") and [e2, e3].has(String(s0.get_meta("eid"))), "la ranura sigue mostrando lo pasado")
	ok(bool(lg._seal.pad.dry), "el tampón ya se ve seco")
	lg._seal.release_hold()
	await tree.process_frame
	var s0b: Control = lg._seal.slot_node(0)
	ok(s0b != null and not s0b.has_meta("eid"), "terminada la impresión, ranuras vacías")
	lg.refresh()
	eq(_find(lg, "Valor"), null, "en tinta no hay blancos editables")
	eq(_find(lg, "Borrar"), null, "la tinta no se borra")
	lg.stamp()
	eq(lg.confirm_dialog(), null, "sin pasada no hay confirmación")
	eq(lg.last_note(), sim.repo.text("pass.sin_pasada"), "Lisle: el tampón está seco")

func test_ui_dry_pass_all_or_nothing_and_formal():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var lg = _ledger(sim)
	lg.open("FO003")
	var as6 := String(Model.page_entries(sim, "FO003")[0])
	var bad := String(Model.page_entries(sim, "varios")[0])
	ok(bool(Validator.entry_ok(sim.st, sim.repo, as6).ok), "C6 válido (control)")
	# formal: una línea llena sin según no moja el sello y no gasta
	var loose: String = String(sim.apply({"t": "entry_new", "folio": "varios", "template": "T7"}).get("entry", ""))
	lg.set_field(loose, 0, "persona", "mycroft")
	lg.toggle_lot(as6)
	ok(lg.toggle_lot(loose), "marcar el asiento incompleto")
	lg.stamp()
	eq(lg.confirm_dialog(), null, "el formal se ve antes de confirmar")
	eq(String(lg.selected), loose, "se abre el asiento que falla")
	ok(lg.last_note().contains(sim.repo.text("pass.formal")), "«El plumín no toma tinta.»: " + lg.last_note())
	eq(int(sim.q_clock().passes_left), 1, "el formal no gasta")
	lg.toggle_lot(loose)
	lg.delete_entry(loose)
	ok(lg.toggle_lot(bad), "marcar el flojo")
	lg.stamp()
	ok(lg.confirm_dialog() != null, "confirmación")
	# §6.1: el texto final completo antes de confirmar (nada recortado con «…»)
	var finals: Array = []
	for n in lg.confirm_dialog().find_children("TextoFinal_*", "Label", true, false):
		finals.append(String(n.text))
	eq(finals, [Model.entry_summary(Model.entry_vm(sim, as6)), Model.entry_summary(Model.entry_vm(sim, bad))], "la confirmación muestra lo que se entinta, entero")
	var r: Dictionary = lg.confirm_stamp()
	ok(bool(r.get("ok", false)) and not bool(r.get("inked", true)), "todo o nada: no entinta: %s" % str(r))
	eq(lg.last_note(), sim.repo.text("pass.fail"), "Lisle dice sólo «Alguno no se sostiene.»")
	eq(String(sim.q_entry(as6).ink), "lapiz", "el bueno tampoco se entinta")
	eq(int(sim.q_clock().passes_left), 0, "la pasada se gastó")
	ok(bool(Model.seal_state(sim, []).dry), "tampón seco")
	var txt: Array = []
	_all_text(lg, txt)
	var all := " ".join(PackedStringArray(txt))
	var rx := RegEx.new()
	rx.compile("\\bC1?[0-9]a?\\b|\\ba:|\\bf:|refutado|ancla_|acto_")
	var m := rx.search(all)
	ok(m == null, "nada en pantalla nombra conclusiones ni etiquetas ocultas: %s" % (m.get_string() if m != null else ""))
	ok(not all.contains("C6") and not all.contains("cid"), "sin pistas de contenido")

func test_ui_drag_and_drop_targets():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var lg = _ledger(sim)
	lg.open("varios")
	var e: String = lg.new_entry("T7").get("entry", "")
	lg.refresh()
	var clips: Array = sim.q_clips()
	var cid := String(clips[0].id)
	ok(lg.can_drop_support({"kind": "clip", "id": cid}), "una tira se suelta en el según")
	ok(lg.can_drop_support({"kind": "pair", "id": "PR001"}), "un par también")
	no(lg.can_drop_support({"kind": "ent", "id": "watson"}), "un chip del índice no va al según")
	ok(lg.can_drop_field({"kind": "ent", "id": "watson"}, {"kinds": ["persona"]}), "un chip del índice va a un campo")
	no(lg.can_drop_field({"kind": "clip", "id": cid}, {"kinds": ["persona"]}), "una tira no va a un campo")
	lg.drop_support(e, 0, {"kind": "clip", "id": cid})
	eq(sim.q_entry(e).lines[0].support, [cid], "soltar en el según -> entry_support_add")
	lg.drop_field(e, 0, "persona", {"kind": "ent", "id": "mycroft"})
	eq(String(sim.q_entry(e).lines[0].fields.get("persona", "")), "mycroft", "soltar en el campo -> entry_set")
	var before: int = sim.q_ledger().folios.size()
	ok(lg.can_drop_folio({"kind": "clip", "id": cid}), "una tira abre folio")
	lg.drop_folio({"kind": "clip", "id": cid})
	eq(sim.q_ledger().folios.size(), before + 1, "soltar en «Nuevo folio» -> folio_open")
	# arrastre real del motor: la tira del encabezado del folio hasta el según de un asiento
	lg.open("varios")
	lg.select_entry(e)
	lg.refresh()
	await tree.process_frame
	await tree.process_frame
	var slot: Control = _find(lg, "Ranura")
	ok(slot != null, "ranura del según")
	var dragged: Variant = lg.drag_entry(e, slot)
	eq(dragged, {"kind": "entry", "id": e}, "un asiento se arrastra para presentarlo")
	# soltar de verdad (DnD nativo, §6.3): el motor llama a la ranura por set_drag_forwarding
	var cid2 := String(clips[1].id)
	await _drop_on(slot, {"kind": "clip", "id": cid2})
	ok((sim.q_entry(e).lines[0].support as Array).has(cid2), "arrastre del motor hasta el según: %s" % str(sim.q_entry(e).lines[0].support))
	var field: Control = _find(_find(lg, "Campo_estado"), "Valor")
	await _drop_on(field, {"kind": "ent", "id": "mycroft"})
	eq(String(sim.q_entry(e).lines[1].fields.get("estado", "")), "", "un chip de persona no entra en «Estado» (lista cerrada)")
	await _drop_on(lg._new_folio, {"kind": "clip", "id": cid2})
	eq(sim.q_ledger().folios.size(), before + 2, "arrastre del motor hasta «Nuevo folio»")

func test_ui_field_errors_in_lisle_voice():
	var sim = GameSim.new(_r(), 7)
	var lg = _ledger(sim)
	lg.open()
	_through_prologue(sim, lg)
	var e: String = lg.new_entry("T3").get("entry", "")
	var r: Dictionary = lg.set_field(e, 0, "persona", "moran")
	no(bool(r.get("ok", false)), "Moran no está en el índice")
	eq(lg.last_note(), sim.repo.text("entry.no_indexado"), "Lisle: no puede escribir lo que no tiene en el índice")
	var r2: Dictionary = lg.set_field(e, 0, "persona", "")
	ok(bool(r2.get("ok", false)), "dejar en blanco")

func test_ui_compact_dock_single_page():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var lg = _ledger(sim)
	lg.open("FO003")
	no(lg.compact, "pantalla entera: dos páginas")
	lg.dock(Rect2(760, 0, 840, 900))
	await tree.process_frame
	ok(lg.compact, "acoplado angosto: una página")
	no(lg._right.visible, "sin página derecha")
	lg.on_select(String(Model.page_entries(sim, "FO003")[0]))
	ok(bool(lg.debug_state().compact_entry), "el asiento ocupa la página")
	ok(_find(lg, "VolverALaPagina") != null, "renglón para volver a la lista")
	lg.back()
	no(bool(lg.debug_state().compact_entry), "volver: la lista")
	ok(lg.is_open(), "volver no cierra el libro si hay un asiento abierto")
	lg.dock(Rect2())
	await tree.process_frame
	no(lg.compact, "de nuevo a pantalla entera")
	lg.back()
	no(lg.is_open(), "volver cierra el libro")

func test_ui_game_autoload_path():
	var g = tree.root.get_node("Game")
	var prev_repo = g.repo_override
	var prev_path: String = g.save_path
	g.repo_override = _r()
	# no tmp_dir(): vaciaría el dataset combinado que comparten los tests de este archivo
	var dir := ProjectSettings.globalize_path("res://").path_join("../.work/tests/test_u_ledger_ui_game").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	g.save_path = dir.path_join("partida.jsonl")
	ok(g.new_session(7), "partida nueva")
	_lg = Ledger.new()
	_lg.sounds = false
	tree.root.add_child(_lg)
	_lg.open()
	var c := _prologue(g.sim)
	g.act({"t": "link", "a": c.abril, "b": c.oct, "note": ""})
	var fo: Dictionary = _lg.new_folio_from(c.abril)
	ok(bool(fo.get("ok", false)), "sin sim propio el libro usa Game.act: %s" % str(fo))
	ok(g.sim.q_ledger().folios.size() == 1, "folio en la sesión del autoload")
	ok(FileAccess.file_exists(g.save_path) or g.flush(), "registro de la sesión en disco")
	await tree.process_frame
	eq(String(_lg.page), String(fo.folio), "el libro sigue al folio")
	g.end_session()
	g.repo_override = prev_repo
	g.save_path = prev_path

# ---------------------------------------------------------------- Shell (protocolo por duck typing de ui/shell.gd)
class FakeShell extends Node:
	signal panel_opened(kind: String)
	signal panel_closed(kind: String)
	var open_kinds: Array = []
	var pops := 0
	var scene_panel: Node = null
	func is_open(kind: String) -> bool:
		return open_kinds.has(kind)
	func panel(kind: String) -> Node:
		return scene_panel if kind == "scene" else null
	func open_kind(kind: String) -> void:
		open_kinds.append(kind)
		panel_opened.emit(kind)
	func close_kind(kind: String) -> void:
		open_kinds.erase(kind)
		panel_closed.emit(kind)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	tree.root.push_input(ev)
	await tree.process_frame
	var up := ev.duplicate()
	up.pressed = false
	tree.root.push_input(up)
	await tree.process_frame

func test_ui_shell_back_and_side_dock():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	var lg = _ledger(sim)
	lg.handle_back = false
	lg.set_shell(sh)
	lg.open("FO003")
	await tree.process_frame
	no(lg.side, "escritorio sin cuaderno: el libro a pantalla entera")
	no(lg.compact, "dos páginas")
	sh.open_kind("notebook")
	await tree.process_frame
	await tree.process_frame
	ok(lg.side, "con el cuaderno abierto, el libro se acopla a la derecha")
	var vp: Vector2 = lg.get_viewport().get_visible_rect().size
	var r: Rect2 = lg.debug_state().rect
	ok(r.position.x >= vp.x * 0.5 - 0.5 and is_equal_approx(r.end.x, vp.x), "mitad derecha: %s en %s" % [str(r), str(vp)])
	ok(r.position.x >= 18.0 + maxf(560.0, vp.x * 0.5 - 30.0), "no pisa el cuaderno en su modo «left»")
	sh.close_kind("notebook")
	await tree.process_frame
	await tree.process_frame
	no(lg.side, "sin cuaderno vuelve a pantalla entera")
	# volver: el elector primero (no cierra el libro), luego el libro; back() devuelve bool para Shell.pop
	lg.on_new_entry(_find(lg, "NuevoAsiento"))
	ok(lg.picker() != null, "elector abierto")
	eq(lg.back(), true, "back() consume el elector")
	ok(lg.is_open() and lg.picker() == null, "el libro sigue abierto")
	# Esc con Shell: sin nada adentro, el libro no lo consume (la pila del Shell decide)
	await _key(KEY_ESCAPE)
	ok(lg.is_open(), "Esc con Shell y sin nada adentro: lo decide el InputRouter, no el libro")
	lg.on_new_entry(_find(lg, "NuevoAsiento"))
	await _key(KEY_ESCAPE)
	ok(lg.is_open() and lg.picker() == null, "Esc con Shell y elector abierto: cierra sólo el elector")
	await _key(KEY_L)
	ok(lg.is_open(), "L con Shell: lo alterna el InputRouter, no el libro")
	var closed := [false]
	lg.closed.connect(func(): closed[0] = true)
	eq(lg.back(), true, "back() sin nada adentro cierra el libro (consumido)")
	ok(not lg.is_open() and closed[0], "cerrado y con la señal closed (el Shell lo saca de la pila)")
	eq(lg.back(), false, "cerrado: nada que consumir")
	sh.queue_free()

func test_ui_side_dock_when_away_and_backdrop():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	_act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	var lg = _ledger(sim)
	lg.handle_back = false
	lg.set_shell(sh)
	lg.open("varios")
	await tree.process_frame
	ok(lg.side, "de visita: el libro a la derecha, el 3D a la izquierda para presentar")
	ok(lg.compact, "media pantalla: una sola página")
	# durante un arrastre el fondo deja pasar el ratón; al terminar vuelve a parar los clics
	lg.notification(Node.NOTIFICATION_DRAG_BEGIN)
	eq(lg._back.mouse_filter, Control.MOUSE_FILTER_IGNORE, "arrastre: el fondo deja pasar")
	lg.notification(Node.NOTIFICATION_DRAG_END)
	eq(lg._back.mouse_filter, Control.MOUSE_FILTER_STOP, "fin del arrastre")
	# clic en el fondo = cerrar
	lg._on_backdrop()
	no(lg.is_open(), "clic en el fondo cierra el libro")
	sh.queue_free()

func test_ui_header_drag_ink_animation_and_hint():
	var sim = GameSim.new(_r(), 7)
	var lg = _ledger(sim)
	lg.open()
	_through_prologue(sim, lg)
	var c := _day1(sim)
	lg.new_folio_from(c.sheer)
	var e2: String = lg.new_entry("T2").get("entry", "")
	lg.refresh()
	ok(_find(lg, "Ayuda") != null, "un asiento en blanco dice cómo se llena")
	lg.set_field(e2, 0, "fuente", "fina")
	lg.refresh()
	eq(_find(lg, "Ayuda"), null, "al escribir algo, la ayuda desaparece")
	lg.set_field(e2, 0, "calla", "raspadura")
	lg.set_field(e2, 1, "consta_en", "journal_de_geneve")
	lg.add_support(e2, 0, c.sheer)
	lg.add_support(e2, 1, c.marque)
	var e3: String = lg.new_entry("T1").get("entry", "")
	lg.set_field(e3, 0, "fuente_a", "fina")
	lg.set_field(e3, 0, "dice_a", "a_pique")
	lg.set_field(e3, 1, "fuente_b", "journal_de_geneve")
	lg.set_field(e3, 1, "dice_b", "cornisa")
	lg.add_support(e3, 0, c.sheer)
	lg.add_support(e3, 1, c.corniche)
	lg.select_entry(e2)
	lg.refresh()
	await tree.process_frame
	await tree.process_frame
	# arrastre real desde la cabecera del asiento abierto: presentar
	var head: Control = _find(lg, "Cabecera")
	ok(head != null, "cabecera del asiento")
	var vp := head.get_viewport()
	var at: Vector2 = head.get_global_transform_with_canvas() * Vector2(40, head.size.y * 0.5)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = at
	mb.global_position = at
	vp.push_input(mb, true)
	await tree.process_frame
	for k in range(1, 5):
		var mm := InputEventMouseMotion.new()
		mm.position = at + Vector2(12 * k, 4 * k)
		mm.global_position = mm.position
		mm.relative = Vector2(12, 4)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		vp.push_input(mm, true)
		await tree.process_frame
	ok(vp.gui_is_dragging(), "la cabecera inicia un arrastre")
	eq(vp.gui_get_drag_data(), {"kind": "entry", "id": e2}, "datos de presentar un asiento")
	var up := mb.duplicate()
	up.pressed = false
	up.position = at + Vector2(600, 300)
	up.global_position = up.position
	vp.push_input(up, true)
	await tree.process_frame
	await tree.process_frame
	# pasada en tinta: la tinta se escribe (visible_ratio sube) y cae el «Visto»
	lg.toggle_lot(e2)
	lg.toggle_lot(e3)
	lg.stamp()
	ok(lg.confirm_dialog() != null, "confirmación")
	lg.confirm_dialog().ok_button.pressed.emit()
	var inked: Array = []
	_collect_ink(lg, inked)
	ok(not inked.is_empty(), "renglones en tinta a la vista")
	ok(inked.any(func(l): return l.visible_ratio < 1.0), "recién entintado: la tinta se está escribiendo")
	for i in 40:
		await tree.process_frame
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		await tree.process_frame
	var inked2: Array = []
	_collect_ink(lg, inked2)
	ok(inked2.all(func(l): return l.visible_ratio >= 1.0), "al rato, toda la tinta escrita")
	eq(String(sim.q_entry(e2).ink), "tinta", "C2 en tinta")

func _collect_ink(n: Node, out: Array) -> void:
	if n is Label and n.get_theme_font("font") == _lg.font("imprenta") and n.get_parent() != null and String(n.get_parent().name).begins_with("Campo_"):
		out.append(n)
	for ch in n.get_children():
		_collect_ink(ch, out)

# ---------------------------------------------------------------- sello: ranuras clicables, página de erratas, banda
func test_ui_seal_slots_choose_and_remove():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var lg = _ledger(sim)
	lg.open("varios")
	await tree.process_frame
	var opts := Model.lot_options(sim, [])
	var ids: Array = opts.map(func(o): return String(o.id))
	var as6 := String(Model.page_entries(sim, "FO003")[0])
	var as4 := String(Model.page_entries(sim, "varios")[0])
	ok(ids.has(as6) and ids.has(as4), "el elector del sello ofrece los asientos a lápiz: %s" % str(ids))
	for fid in ["FO001", "FO002"]:
		for e in Model.page_entries(sim, fid):
			no(ids.has(String(e)), "ni la práctica ni la tinta van al sello (%s)" % e)
	var s0: Control = lg._seal.slot_node(0)
	var t0: Label = _find(s0, "Texto") if s0 != null else null
	ok(t0 != null and t0.text == sim.repo.text("ledger.sello.hueco"), "ranura vacía con su texto")
	lg.on_lot_add(s0)
	ok(lg.picker() != null, "clic en la ranura vacía -> elector de asientos")
	ok(lg.picker().pick_id(as6), "elegir el asiento de Relación")
	await tree.process_frame
	eq(lg.lot, [as6], "queda marcado para el sello")
	await tree.process_frame
	var s0b: Control = lg._seal.slot_node(0)
	ok(s0b != null and s0b.has_meta("eid") and String(s0b.get_meta("eid")) == as6, "la ranura muestra el asiento")
	lg.on_lot_add(lg._seal.slot_node(1))
	ok(lg.picker() != null and not lg.picker().options.any(func(o): return String(o.id) == as6), "el elector no repite lo ya marcado")
	lg.back()
	var x: Button = _find(s0b, "Quitar")
	ok(x != null, "cruz para sacarlo del sello")
	x.pressed.emit()
	eq(lg.lot, [], "sacado del lote")

func test_ui_erratas_page_is_practice():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var lg = _ledger(sim)
	lg.open("erratas")
	eq(String(lg.page), "erratas", "página «Erratas inocentes»")
	var r: Dictionary = lg.new_entry("T1")
	ok(bool(r.get("ok", false)), "asiento en la página de erratas: %s" % str(r))
	var e := String(r.get("entry", ""))
	ok(bool(sim.q_entry(e).get("practice", false)), "todo asiento de «Erratas inocentes» es de práctica")
	eq(String(lg.page), "erratas", "sigue en la página de erratas")
	lg.refresh()
	ok(_find(lg, "Practicar") != null, "«Pasar en limpio» propio de la práctica")
	eq(_find(lg, "AlSello"), null, "la práctica no va al lote")
	no(lg.toggle_lot(e), "ni por la API")
	eq(lg.last_note(), sim.repo.text("ledger.lote.practica"), "Lisle: la práctica se pasa aparte")
	# práctica que no cumple la forma: Lisle dice por qué (como en el sello), no sólo que el plumín no toma tinta
	lg.set_field(e, 0, "fuente_a", "redh")
	var rp: Dictionary = lg.practice(e)
	no(bool(rp.get("ok", false)), "sin según no se practica")
	eq(lg.last_note(), "%s %s" % [sim.repo.text("pass.formal"), lg.plain(sim.repo.text("formal.falta_segun"))], "Lisle: «El plumín no toma tinta. Falta un según.»")
	eq(String(sim.q_entry(e).ink), "lapiz", "sigue a lápiz")

class FakeScene extends Node:
	var band: PanelContainer
	var visible := true
	func _init() -> void:
		band = PanelContainer.new()
		band.position = Vector2(24, 614)
		band.size = Vector2(1552, 262)
		add_child(band)

func test_ui_visit_hides_seal_and_stays_above_scene_band():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	var sc := FakeScene.new()
	tree.root.add_child(sc)
	_act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	var lg = _ledger(sim)
	lg.handle_back = false
	lg.set_shell(sh)
	lg.open("FO003")
	await tree.process_frame
	await tree.process_frame
	ok(lg.side and lg.compact, "de visita: acoplado a la derecha, una página")
	no(lg._seal.visible, "el sello no sale del escritorio")
	var full_scale: float = lg._stage.scale.x
	sh.scene_panel = sc
	sh.open_kind("scene")
	await tree.process_frame
	await tree.process_frame
	var band_top: float = sc.band.get_global_rect().position.y
	var r: Rect2 = lg.debug_state().rect
	ok(r.end.y <= band_top, "el libro termina arriba de la banda de la escena: %s / %s" % [str(r), band_top])
	var book_bottom: float = lg._stage.position.y + lg._book.size.y * lg._stage.scale.y
	ok(book_bottom <= band_top + 0.5, "el dibujo del libro tampoco la pisa: %s" % book_bottom)
	ok(lg._stage.scale.x >= full_scale - 0.01, "la letra no se achica: el libro se acorta (%s -> %s)" % [full_scale, lg._stage.scale.x])
	ok(lg._book.size.y < 860.0, "libro más corto")
	sh.close_kind("scene")
	await tree.process_frame
	await tree.process_frame
	ok(is_equal_approx(lg._book.size.y, 860.0), "sin escena vuelve al alto completo")
	_act(sim, {"t": "leave"})
	lg.refresh()
	ok(lg._seal.visible, "de vuelta en el escritorio, el sello a la vista")
	sc.queue_free()
	sh.queue_free()

# Regresión (capturas del Shell): tras acoplarse junto al cuaderno y volver a pantalla entera, el papel del sello
# quedaba vacío (su contenido fuera de lugar). El sello, su tampón y las ranuras tienen que verse dentro de su papel.
func _seal_inside(lg, what: String) -> void:
	var sr: Rect2 = lg._seal.get_global_rect()
	for n in [lg._seal.stamp_box, lg._seal.pad, lg._seal.slot_node(0)]:
		if n == null:
			fail("%s: falta un nodo del sello" % what)
			continue
		var r: Rect2 = n.get_global_rect()
		ok(sr.grow(1.0).encloses(r), "%s: %s dentro del sello (%s en %s)" % [what, n.name, str(r), str(sr)])
	ok(lg._seal.size.y <= Ledger.SEAL_R.size.y + 1.0, "%s: el sello conserva su alto (%s)" % [what, lg._seal.size.y])

func test_ui_seal_stays_in_its_paper_after_docking():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var sh := FakeShell.new()
	tree.root.add_child(sh)
	var lg = _ledger(sim)
	lg.handle_back = false
	lg.set_shell(sh)
	lg.open()
	for _i in 3:
		await tree.process_frame
	_seal_inside(lg, "pantalla entera")
	sh.open_kind("notebook")
	for _i in 3:
		await tree.process_frame
	ok(lg.compact, "acoplado")
	_seal_inside(lg, "acoplado")
	lg.show_page("varios")
	lg.toggle_lot(String(Model.page_entries(sim, "varios")[0]))
	lg.toggle_lot(String(Model.page_entries(sim, "FO003")[0]))
	lg.refresh()
	for _i in 3:
		await tree.process_frame
	_seal_inside(lg, "acoplado con lote")
	sh.close_kind("notebook")
	for _i in 4:
		await tree.process_frame
	no(lg.compact, "de nuevo a pantalla entera")
	_seal_inside(lg, "pantalla entera otra vez")
	lg.lot.clear()
	lg.refresh()
	for _i in 3:
		await tree.process_frame
	_seal_inside(lg, "sin lote")
	# subtítulos del Shell (abajo a la derecha): el sello sube y deja libre esa franja; sin subtítulos, vuelve abajo
	var au = tree.root.get_node_or_null("Audio")
	if au != null:
		var prev: bool = au.subtitles_on
		var vp: Vector2 = lg.get_viewport().get_visible_rect().size
		au.subtitles_on = true
		lg.dock(Rect2())
		await tree.process_frame
		ok(lg._seal.get_global_rect().end.y <= vp.y - Ledger.SUBS_RESERVE + 1.0, "con subtítulos el sello deja libre la franja de abajo: %s" % str(lg._seal.get_global_rect()))
		_seal_inside(lg, "con subtítulos")
		au.subtitles_on = false
		lg.dock(Rect2())
		await tree.process_frame
		ok(is_equal_approx(lg._seal.position.y + lg._seal.size.y, lg._hd), "sin subtítulos, el sello al pie del canto")
		au.subtitles_on = prev
	# la nota de Lisle no sobrevive al libro cerrado
	lg.say("Una nota.")
	ok(lg._note.visible, "nota a la vista")
	lg.close()
	no(lg._note.visible, "al cerrar, la nota se va")
	lg.open()
	no(lg._note.visible, "al reabrir no queda una línea vieja")
	sh.queue_free()

func test_ui_final_report_lot_of_one():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	var as6 := String(Model.page_entries(sim, "FO003")[0])
	for _i in 300:
		var ph := String(sim.q_clock().phase)
		if ph == "final_report" or ph == "done":
			break
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if sim.q_report_status().due else {"t": "sleep"}
			"confront":
				a = {"t": "confront", "step": int(sim.q_confront().get("step", 1)), "item": {}}
			_:
				break
		if not bool(sim.apply(a).get("ok", false)):
			break
	eq(String(sim.q_clock().phase), "final_report", "día 10, antes del informe")
	if String(sim.q_clock().phase) != "final_report":
		return
	var lg = _ledger(sim)
	lg.open("FO003")
	await tree.process_frame
	eq(int(Model.seal_state(sim, []).lot_size), 1, "el último día el lote es de uno")
	eq(lg._seal.cards.size(), 0, "nada marcado")
	ok(lg._seal.slot_node(0) != null and lg._seal.slot_node(1) == null, "una sola ranura")
	ok(lg.toggle_lot(as6), "marcar uno")
	no(lg.toggle_lot(String(Model.page_entries(sim, "varios")[0])), "un segundo no entra")
	lg.stamp()
	ok(lg.confirm_dialog() != null, "confirmación")
	var r: Dictionary = lg.confirm_stamp()
	ok(bool(r.get("ok", false)) and bool(r.get("inked", false)), "C6 en tinta en el informe final: %s" % str(r))
	eq(String(sim.q_entry(as6).ink), "tinta")

# Lote de cero (todo lo que cuenta ya está sellado): el sello no ofrece ranuras ni abre una confirmación vacía, y
# Lisle lo dice con su línea (antes: confirmación sin nada y la clave «ledger.n.0» a la vista).
func test_ui_lot_of_zero_has_no_empty_confirmation():
	var sim = _integ()._walk(_r())
	if sim == null:
		fail("recorrido")
		return
	for cid in sim.repo.conclusions_meta().get("lot_counts", []):
		sim.st.ded.sealed[String(cid)] = "AS999"
	eq(int(sim.q_clock().lot_size), 0, "lote de cero")
	var st := Model.seal_state(sim, [])
	eq(String(st.reason), "nada", "el sello no tiene qué pasar")
	no(bool(st.ready), "no se puede estampar")
	var lg = _ledger(sim)
	lg.open("FO003")
	await tree.process_frame
	ok(_find(lg._seal, "SinLote") != null and lg._seal.slot_node(0) == null, "sin ranuras: la línea de Lisle")
	var nada: String = sim.repo.text("ledger.sello.nada")
	no(lg.toggle_lot(String(Model.page_entries(sim, "FO003")[0])), "nada entra al sello")
	eq(lg.last_note(), nada, "Lisle: no queda nada que pasar")
	lg.stamp()
	eq(lg.confirm_dialog(), null, "sin confirmación vacía")
	eq(lg.last_note(), nada, "Lisle lo dice al estampar")
	no(lg.last_note().contains("ledger."), "nunca una clave a la vista")
	eq(Model.err_text(sim, "lote", {"lot_size": 0}), nada, "el error «lote» con cero tampoco muestra «ledger.n.0»")
	# con la pasada de la franja ya gastada tampoco promete «la franja que viene»
	sim.st.clock["passes_used"] = 99
	eq(String(Model.seal_state(sim, []).reason), "nada", "lote de cero antes que tampón seco")
	ok(bool(Model.seal_state(sim, []).dry), "el tampón se ve seco igual")
