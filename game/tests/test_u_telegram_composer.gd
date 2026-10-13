# W3-SCENEUI: telegramas y cartas (ui/compose/telegram_composer.gd) sobre una GameSim REAL (tests/fixtures/w3sceneui/world.gd).
# Verifica: open("telegram"|"letter") desde la pila de Shell (papel ante + máquina / carta + manuscrito), destino y piezas
#   sólo de Composers.mail_options, cada pieza llena abre la siguiente y no se repiten, texto final exacto (q_preview)
#   visible, dos pasos y envío (sale al cerrar la franja: evento al end_slot).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const TC = preload("res://ui/compose/telegram_composer.gd")
const Composers = preload("res://core/scenes/composers.gd")

static var _world = null
var tc = null
var sim = null
var acts: Array = []

func world():
	if _world == null:
		_world = W.new()
	return _world

func before_each() -> void:
	acts = []

func after_each() -> void:
	if tc != null and is_instance_valid(tc):
		tc.free()
	tc = null

func rec_act(a: Dictionary) -> Dictionary:
	acts.append(a.duplicate(true))
	return sim.apply(a)

func mount(mode: String) -> void:
	sim = world().sim_at("day1_desk_T")
	eq(world().errs, [], "camino sin acciones rechazadas")
	tc = TC.new()
	tc.sim = sim
	tc.act_fn = rec_act
	tc.sounds = false
	tc.close_delay = 0.0
	tree.root.add_child(tc)
	tc.open(mode)

# ------------------------------------------------------------------
func test_telegram_pieces_and_final_text() -> void:
	mount("telegram")
	eq(tc.mode, "telegram", "modo telegrama")
	eq(tc._title.text, sim.repo.text("sceneui.tg.title"), "título")
	eq(tc._final_slot(), "maquina", "texto final a máquina")
	var to_ids: Array = tc._to.options.map(func(o): return String(o.id))
	eq(to_ids, Composers.mail_options(sim.st, sim.repo, "to").map(func(o): return String(o.id)), "destinos = mail_options")
	has(to_ids, "meiringen", "Meiringen (recortado de D08)")
	ok(tc.send_button.disabled, "vacío: no se envía")
	ok(tc.set_to("meiringen"), "destino")
	ok(tc.send_button.disabled, "sin piezas: no se envía")
	ok(tc._parts[0].visible, "la primera pieza")
	no(tc._parts[1].visible, "la segunda aparece después")
	ok(tc.set_part(0, "cornisa"), "pieza 1")
	tc.refresh()
	ok(tc._parts[1].visible, "la segunda pieza se abre")
	var p1: Array = tc._parts[1].options.map(func(o): return String(o.id))
	no(p1.has("cornisa"), "no se repite una pieza")
	ok(tc.set_part(1, "nidero"), "pieza 2")
	tc.refresh()
	var a := {"t": "compose_telegram", "to": "meiringen", "parts": ["cornisa", "nidero"]}
	eq(tc._action(), a, "acción")
	var want: String = sim.q_preview(a)
	ok(want != "", "texto final del sim")
	eq(tc.final_text(), want, "texto final exacto")
	eq(TC.undisplay(tc.final_rtl.get_parsed_text()), want, "a la vista")
	no(tc.send_button.disabled, "se puede enviar")
	# vaciar una pieza desde su propio menú
	tc._parts[1]._on_id(-1)
	eq(tc.parts(), ["cornisa"], "pieza 2 vaciada")
	tc.set_part(1, "nidero")
	tc.send()
	ok(tc.confirm_open(), "dos pasos")
	eq(acts.size(), 0, "nada gastado")
	var res: Dictionary = tc.confirm_send()
	ok(bool(res.get("ok", false)), "telegrama aceptado: %s" % str(res))
	eq(acts.back(), a, "compose_telegram")
	no(tc.is_open(), "cerrado tras enviar")

func test_letter_mode() -> void:
	mount("letter")
	eq(tc.mode, "letter", "modo carta")
	eq(tc._title.text, sim.repo.text("sceneui.lt.title"), "título")
	eq(tc._final_slot(), "manuscrito", "texto final manuscrito")
	var f: Font = tc.final_rtl.get_theme_font("normal_font")
	ok(f is FontVariation and (f as FontVariation).spacing_space > 0, "la letra manuscrita con aire entre palabras")
	ok(tc.set_to("watson"), "destino: el doctor")
	var popts: Array = tc._parts[0].options.map(func(o): return String(o.id))
	has(popts, "as.pared", "una afirmación como pieza")
	ok(tc.set_part(0, "as.pared"), "pieza")
	tc.refresh()
	var a := {"t": "compose_letter", "to": "watson", "parts": ["as.pared"]}
	eq(tc.final_text(), sim.q_preview(a), "texto final exacto")
	ok(bool(tc.confirm_send().get("ok", false)), "carta aceptada")
	eq(acts.back(), a, "compose_letter")

func test_reopen_switches_mode_and_clears() -> void:
	mount("telegram")
	tc.set_to("meiringen")
	tc.close()
	tc.open("letter")
	eq(tc.mode, "letter", "la pila de Shell pasa el modo")
	eq(String(tc._to.value), "", "reabrir limpia el destino")
	eq(tc.parts(), [], "y las piezas")
	tc.close()
	tc.open_mode("telegram")
	eq(tc.mode, "telegram", "open_mode")
