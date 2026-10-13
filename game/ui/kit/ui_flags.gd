# ui/kit/ui_flags.gd — banderas de revelado progresivo de la interfaz para las vistas (GDD_v2 §C.1–C.2). Dueño: DESPEJE-UI.
# La fuente única es GameSim.q_ui() (core/sim/ui_state.gd, PROGRESIÓN): sólo del estado, determinista, persiste al cargar.
# Las vistas NO deciden por su cuenta qué mostrar: leen estas banderas una vez por refresco.
#   of(sim) -> Dictionary     q_ui() de esa partida ({} si no hay partida o la partida no lo ofrece)
#   now() -> Dictionary       q_ui() de Game.sim
#   on(flags, name) -> bool   flags[name]; SIN partida (flags vacío: vistas sueltas, capturas, tests con dobles) todo
#                             visible, como antes del revelado progresivo
extends RefCounted

static func of(sim) -> Dictionary:
	if sim == null or not is_instance_valid(sim):
		return {}
	if not sim.has_method("q_ui"):
		return {}
	var f = sim.q_ui()
	return f if typeof(f) == TYPE_DICTIONARY else {}

static func now() -> Dictionary:
	var ml = Engine.get_main_loop()
	if not (ml is SceneTree) or ml.root == null:
		return {}
	var g = ml.root.get_node_or_null("Game")
	if g == null:
		return {}
	return of(g.get("sim"))

static func on(flags: Dictionary, name: String, default := true) -> bool:
	if flags.is_empty():
		return default
	return bool(flags.get(name, default))
