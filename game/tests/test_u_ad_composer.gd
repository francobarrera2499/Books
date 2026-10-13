# W3-SCENEUI: compositor de anuncios (ui/compose/ad_composer.gd) sobre una GameSim REAL (tests/fixtures/w3sceneui/world.gd).
# Verifica: formas cerradas (lists.ad_forms; when por estado), huecos con sólo lo que Composers.options permite (o un chip
#   soltado), texto final exacto (q_preview compose_ad) siempre visible, incompleto -> «Faltan palabras.» y «Enviar»
#   deshabilitado, dos pasos (confirmación con el texto y el día de salida), errores como notas de Lisle sin cerrar,
#   protocolo de la pila de Shell (open(arg), back, closed).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const AdComposer = preload("res://ui/compose/ad_composer.gd")
const Composers = preload("res://core/scenes/composers.gd")

static var _world = null
var ac = null
var sim = null
var acts: Array = []
var old_size := Vector2i.ZERO

func world():
	if _world == null:
		_world = W.new()
	return _world

func before_each() -> void:
	acts = []
	old_size = tree.root.size
	tree.root.size = Vector2i(1600, 900)

func after_each() -> void:
	if ac != null and is_instance_valid(ac):
		ac.free()
	ac = null
	if old_size != Vector2i.ZERO:
		tree.root.size = old_size

func rec_act(a: Dictionary) -> Dictionary:
	acts.append(a.duplicate(true))
	return sim.apply(a)

func mount(state: String) -> void:
	sim = world().sim_at(state)
	eq(world().errs, [], "camino a %s sin acciones rechazadas" % state)
	ac = AdComposer.new()
	ac.sim = sim
	ac.act_fn = rec_act
	ac.sounds = false
	ac.close_delay = 0.0
	tree.root.add_child(ac)
	ac.open()

func rtl_text() -> String:
	return AdComposer.undisplay(ac.final_rtl.get_parsed_text())

# ------------------------------------------------------------------
func test_prologue_witness_ad() -> void:
	mount("prologue_ad")
	ok(ac.is_open(), "abierto")
	eq(ac._sub.text, sim.repo.text("sceneui.ad.sub.prologo"), "subtítulo del prólogo (lo lleva Pell)")
	var av: Array = ac.forms_available()
	has(av, "testigo", "forma «Se busca testigo»")
	no(av.has("al_corresponsal"), "«Al corresponsal S.» sólo desde el día 4")
	ac.choose_form("testigo")
	ok(ac.send_button.disabled, "incompleto: «Enviar» deshabilitado")
	eq(rtl_text(), sim.repo.text("sceneui.final.incompleto"), "incompleto: «Faltan palabras.»")
	var opts: Array = ac._blanks.suceso.options.map(func(o): return String(o.id))
	eq(opts, Composers.options(sim.st, sim.repo, "testigo", "suceso").map(func(o): return String(o.id)), "el hueco ofrece lo que Composers permite")
	has(opts, "suceso_reichenbach", "Reichenbach indexado (D23)")
	no(ac.set_field("suceso", "pared"), "un valor fuera de la lista no entra")
	ok(ac.set_field("suceso", "suceso_reichenbach"), "valor de la lista")
	var want: String = sim.q_preview({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	ok(want != "", "texto final del sim")
	eq(ac.final_text(), want, "texto final exacto")
	eq(rtl_text(), want, "el texto final está a la vista")
	no(ac.send_button.disabled, "completo: se puede enviar")
	# dos pasos
	ac.send()
	ok(ac.confirm_open(), "confirmación")
	eq(acts.size(), 0, "abrir la confirmación no gasta")
	var cf_text := AdComposer.undisplay(_texts(ac._confirm))
	ok(cf_text.contains(want), "la confirmación repite el texto final")
	ok(cf_text.contains(sim.repo.text("sceneui.ad.confirm.pub", {"fecha": ac.link.day_label(1)})) or cf_text.contains(ac.link.day_label(1)), "y dice cuándo sale: " + cf_text)
	ok(ac.back(), "back cierra la confirmación")
	no(ac.confirm_open(), "confirmación cerrada")
	eq(acts.size(), 0, "volver no gasta")
	var got := []
	ac.sent.connect(func(r): got.append(r))
	var res: Dictionary = ac.confirm_send()
	ok(bool(res.get("ok", false)), "aviso aceptado: %s" % str(res))
	eq(acts.back(), {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}, "acción compose_ad")
	eq(got.size(), 1, "sent")
	no(ac.is_open(), "se cierra")

func test_a_proposito_and_one_per_day() -> void:
	mount("day1_desk_T")
	eq(ac._sub.text, sim.repo.text("sceneui.ad.sub"), "subtítulo de la oficina")
	ac.choose_form("a_proposito")
	ok(ac._blanks.has("fuente") and ac._blanks.has("afirmacion"), "dos huecos en línea")
	var sb = ac._blanks.fuente.get_theme_stylebox("normal")
	ok(sb is StyleBoxFlat and sb.content_margin_left <= 4.0 and sb.border_width_bottom == 1, "el hueco es un subrayado del renglón, sin caja")
	ok(ac.set_field("fuente", "fina"), "fuente: FINA (indexada)")
	# el hueco muestra la palabra tal como se imprime, nunca la forma de catálogo del índice («…, El (Strand, …)»)
	var idx_label: String = String(sim.repo.entity("fina").get("index", ""))
	ok(ac.final_text() == "" and ac._blanks.fuente.text != idx_label, "el hueco lleno no muestra el rótulo del índice (%s)" % idx_label)
	ok(sim.q_preview({"t": "compose_ad", "form": "a_proposito", "fields": {"fuente": "fina", "afirmacion": "as.pared"}}).contains(ac._blanks.fuente.text), "muestra lo que saldrá impreso: " + ac._blanks.fuente.text)
	ok(ac.send_button.disabled, "falta la afirmación")
	ok(ac.set_field("afirmacion", "as.pared"), "afirmación de la lista")
	var a := {"t": "compose_ad", "form": "a_proposito", "fields": {"fuente": "fina", "afirmacion": "as.pared"}}
	eq(ac.final_text(), sim.q_preview(a), "texto final exacto")
	# cambiar de forma conserva lo que sirva y limpia lo demás
	ac.choose_form("testigo")
	eq(ac.fields, {}, "otra forma: sin campos ajenos")
	ac.choose_form("a_proposito")
	ac.set_field("fuente", "fina")
	ac.set_field("afirmacion", "as.pared")
	ok(bool(ac.confirm_send().get("ok", false)), "primer aviso del día")
	ac.open()
	ac.choose_form("a_proposito")
	ac.set_field("fuente", "fina")
	ac.set_field("afirmacion", "as.pared")
	var r2: Dictionary = ac.confirm_send()
	eq(String(r2.get("err", "")), "uno_por_dia", "un aviso por día")
	eq(ac.note.text(), sim.repo.text("sim.err.uno_por_dia"), "nota de Lisle")
	ok(ac.is_open(), "el compositor sigue abierto")

func test_chip_drop_on_blank() -> void:
	mount("day1_desk_T")
	ac.choose_form("a_proposito")
	var b = ac._blanks.fuente
	ok(b._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"}), "acepta un chip del índice válido")
	no(b._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "no_existe_x"}), "no acepta lo que la forma no permite")
	no(b._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": "RC0001"}), "no acepta recortes")
	b._drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"})
	eq(String(ac.fields.get("fuente", "")), "fina", "soltar llena el hueco")

func test_shell_open_and_back() -> void:
	mount("day1_desk_T")
	ac.close()
	no(ac.is_open(), "cerrado")
	var closed := [0]
	ac.closed.connect(func(): closed[0] += 1)
	ac.open("")
	ok(ac.is_open(), "open(arg) de la pila de Shell")
	no(ac.back(), "sin confirmación: back no consume (la pila lo cierra)")
	ac.handle_back = false
	ac._back()
	no(ac.is_open(), "clic derecho: vuelve aunque handle_back sea false")
	eq(closed[0], 1, "closed")

func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is RichTextLabel:
		out += (n as RichTextLabel).get_parsed_text() + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out
