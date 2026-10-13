# W3-SCENEUI: el informe a Moran (ui/compose/report_composer.gd) sobre una GameSim REAL (tests/fixtures/w3sceneui/world.gd).
# Verifica: sobre con tres ranuras (selector o DnD), sin repetidos, «Sin novedad», «Quemarlo» sólo en el final, «La errata
#   a medida» sólo si alguien la ofreció, texto final exacto (q_preview report_submit) visible, dos pasos y envío; sin
#   informe debido, sobre en blanco y nota de Lisle.
extends "res://tests/test_base.gd"

const TIMEOUT_S := 90
const W = preload("res://tests/fixtures/w3sceneui/world.gd")
const RC = preload("res://ui/compose/report_composer.gd")

static var _world = null
var rc = null
var sim = null
var acts: Array = []

func world():
	if _world == null:
		_world = W.new()
	return _world

func before_each() -> void:
	acts = []

func after_each() -> void:
	if rc != null and is_instance_valid(rc):
		rc.free()
	rc = null

func rec_act(a: Dictionary) -> Dictionary:
	acts.append(a.duplicate(true))
	return sim.apply(a)

func mount(state: String) -> void:
	sim = world().sim_at(state)
	eq(world().errs, [], "camino a %s sin acciones rechazadas" % state)
	rc = RC.new()
	rc.sim = sim
	rc.act_fn = rec_act
	rc.sounds = false
	rc.close_delay = 0.0
	tree.root.add_child(rc)
	rc.open()

func clip(n: String) -> String:
	return String(world().clips.get(n, ""))

# ------------------------------------------------------------------
func test_first_report_items() -> void:
	mount("day2_report")
	ok(bool(rc.status.due), "informe debido")
	eq(rc._title.text, sim.repo.text("sceneui.rep.title", {"n": 1}), "Informe n.º 1")
	no(rc._modes.quemar.visible, "sin «Quemarlo» antes del final")
	no(rc._modes.errata.visible, "sin errata a medida")
	ok(rc.send_button.disabled, "sobre vacío: elegir algo o «Sin novedad»")
	eq(rc.final_rtl.get_parsed_text(), sim.repo.text("sceneui.rep.vacio"), "la caja del texto final dice que el sobre está vacío")
	ok(rc.add_item({"kind": "clip", "id": clip("marque")}), "un recorte al sobre")
	ok(rc.add_item({"kind": "entry", "id": clip("practica")}), "un asiento al sobre")
	no(rc.add_item({"kind": "clip", "id": clip("marque")}), "no se repite")
	eq(rc.note.text(), sim.repo.text("sceneui.rep.repetido"), "nota de Lisle")
	ok(rc._slots[2].choose.visible, "la tercera ranura ofrece «Elegir…»")
	no(rc._slots[1].choose.visible, "una ranura llena no")
	ok(rc._slots[0].remove.visible, "«Quitar» en la llena")
	var a := {"t": "report_submit", "mode": "items", "items": [{"kind": "clip", "id": clip("marque")}, {"kind": "entry", "id": clip("practica")}]}
	eq(rc._action(), a, "acción")
	var want: String = sim.q_preview(a)
	ok(want != "", "texto final del sim")
	eq(rc.final_text(), want, "texto final exacto")
	eq(RC.undisplay(rc.final_rtl.get_parsed_text()), want, "a la vista")
	# selector para la tercera ranura
	rc.open_picker(2)
	ok(rc.picker.visible, "selector")
	ok(rc.back(), "back cierra el selector")
	no(rc.picker.visible, "cerrado")
	rc.open_picker(2)
	rc.picker.pick("clip", clip("kanzel"))
	eq(rc.items.size(), 3, "tres papeles")
	no(rc.add_item({"kind": "clip", "id": clip("corniche")}), "no caben más de tres")
	rc.remove_item(2)
	eq(rc.items.size(), 2, "quitar")
	rc.send()
	ok(rc.confirm_open(), "dos pasos")
	eq(acts.size(), 0, "nada gastado")
	var res: Dictionary = rc.confirm_send()
	ok(bool(res.get("ok", false)), "informe entregado: %s" % str(res))
	eq(acts.back(), a, "report_submit")
	no(bool(sim.q_report_status().due), "ya no se debe")

func test_nada_mode() -> void:
	mount("day2_report")
	rc.add_item({"kind": "clip", "id": clip("marque")})
	rc.set_mode("nada")
	eq(rc.items, [], "«Sin novedad» vacía el sobre")
	no(rc.slots_enabled(), "ranuras deshabilitadas")
	no(rc.add_item({"kind": "clip", "id": clip("kanzel")}) and rc.mode == "nada", "agregar vuelve a modo papeles")
	rc.set_mode("nada")
	var a := {"t": "report_submit", "mode": "nada", "items": []}
	eq(rc._action(), a, "acción nada")
	eq(rc.final_text(), sim.q_preview(a), "texto final exacto")
	rc.set_mode("quemar")
	eq(rc.mode, "nada", "quemar no se permite antes del final")
	ok(bool(rc.confirm_send().get("ok", false)), "«Sin novedad» entregado")

func test_final_report_burn() -> void:
	mount("day10_final")
	ok(bool(rc.status.final), "informe final")
	eq(rc._title.text, sim.repo.text("sceneui.rep.title.final"), "título del final")
	ok(rc._modes.quemar.visible, "«Quemarlo»")
	no(rc._modes.errata.visible, "nadie ofreció la errata")
	rc.set_mode("errata")
	eq(rc.mode, "items", "errata no ofrecida: no se elige")
	rc.set_mode("quemar")
	var a := {"t": "report_submit", "mode": "quemar", "items": []}
	eq(rc._action(), a, "acción quemar")
	eq(rc.send_button.text, sim.repo.text("sceneui.rep.send.quemar"), "el botón dice «Quemarlo»")
	eq(rc.final_text(), sim.q_preview(a), "texto final exacto")
	ok(rc._confirm_extra() == sim.repo.text("sceneui.rep.confirm.quemar"), "la confirmación dice que no llegará a nadie")
	ok(bool(rc.confirm_send().get("ok", false)), "quemado")
	eq(String(sim.st.flags.get("informe_final", "")), "quemar", "informe_final = quemar")

func test_pell_dismissed_goes_to_h() -> void:
	mount("day2_report")
	eq(rc._confirm_extra(), sim.repo.text("sceneui.rep.confirm.chico"), "antes de M4: el chico de Pell espera")
	rc.close()
	sim.st.flags["pell_despedido"] = true   # M4 (lo escribe Effects; aquí se fuerza el estado)
	rc.open()
	eq(rc._sub.text, sim.repo.text("sceneui.rep.sub.h"), "el subtítulo ya no nombra al chico")
	eq(rc._confirm_extra(), sim.repo.text("sceneui.rep.confirm.h"), "la confirmación tampoco")
	rc.set_mode("nada")
	ok(rc.final_text().contains("H."), "y el texto final del sim va a nombre de H.: %s" % rc.final_text())

func test_not_due() -> void:
	mount("day1_desk_T")
	no(bool(rc.status.due), "no hay informe")
	eq(rc.note.text(), sim.repo.text("sim.err.sin_informe"), "nota de Lisle")
	no(rc.slots_enabled(), "ranuras deshabilitadas")
	ok(rc.send_button.disabled, "no se entrega")
	eq(rc.final_rtl.get_parsed_text(), sim.repo.text("sceneui.rep.no_debido"), "texto final: no hay informe")
	no(rc.add_item({"kind": "clip", "id": clip("marque")}) and rc._action().size() > 0, "nada que entregar")

func test_slot_drop() -> void:
	mount("day2_report")
	var s0 = rc._slots[0].panel
	ok(s0._can_drop_data(Vector2.ZERO, {"kind": "clip", "id": clip("marque")}), "la ranura acepta un recorte")
	ok(s0._can_drop_data(Vector2.ZERO, {"kind": "entry", "id": clip("practica")}), "y un asiento")
	no(s0._can_drop_data(Vector2.ZERO, {"kind": "ent", "id": "fina"}), "no un chip del índice")
	s0._drop_data(Vector2.ZERO, {"kind": "clip", "id": clip("marque")})
	eq(rc.items, [{"kind": "clip", "id": clip("marque")}], "soltar llena la ranura")
