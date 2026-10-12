# core/sim/game_state.gd — estado canónico de la partida. Dueño: W2-SIM. Contrato: ARCHITECTURE §3.3.
# Sólo Dictionary/Array/String/int/float/bool/null. canon() = todo salvo los transitorios, con claves ordenadas.
# Cada sub-diccionario lo inicializa su dueño (init_state) y sólo él lo escribe; los demás leen por funciones del dueño.
# Transitorios (fuera de canon, nunca se guardan): notes, pending_events, now_tk, handlers.
#   now_tk: tk que GameSim está resolviendo (Director.on_time / llegadas); -1 fuera de esa fase. WorldModel.deliver
#           lo usa para el sello «Recibido».
#   handlers: costura de tests (t -> Callable(st, repo, a) -> Dictionary) que reemplaza al manejador de OTRO paquete
#           dentro de PlayerActions.dispatch. El juego nunca lo usa.
extends RefCounted

var seed: int
var clock := {}    # W2-SIM    {day, slot, phase, outing_done, passes_used, ads_by_day:{}, d10:{}, scene, deferred:[], reports_done:{}, errata_decided}
var world := {}    # W2-SIM    {visit, visits:[], plates:{}, docs:{}, tray:[], copies:{}, closures:[], silhouettes:{}, diary:[],
                   #            questions:{}, slips:{}, seat, mem_clips:{}, outbox:[], tutorial:{}, eggs:{}, coins_d,
                   #            acts:{}, lines:{}, inserts:{}, place_variants:{}, orders:{}, lines_seen:{}, eggs_sig}
                   #            (formatos completos en core/sim/world_model.gd y core/sim/clock.gd)
var ded := {}      # W2-DED
var react := {}    # W2-REACT
var scenes := {}   # W2-SCENES
var flags := {}    # registro §3.9 (un escritor por flag)
var events := []   # eventos públicos numerados (append-only; W2-SIM)
var seq := {}      # contadores de ids: clip, pair, folio, entry, inst, ev, ...
var notes := []            # TRANSITORIO: avisos para la UI (fuera de canon())
var pending_events := []   # TRANSITORIO: eventos encolados por módulos durante apply
var now_tk := -1           # TRANSITORIO
var handlers := {}         # TRANSITORIO (tests)

func canon() -> Dictionary:
	return _sorted({"seed": seed, "clock": clock, "world": world, "ded": ded, "react": react, "scenes": scenes, "flags": flags, "events": events, "seq": seq})

static func _sorted(v):
	if typeof(v) == TYPE_DICTIONARY:
		var ks: Array = v.keys()
		ks.sort()
		var d := {}
		for k in ks:
			d[k] = _sorted(v[k])
		return d
	if typeof(v) == TYPE_ARRAY:
		var a := []
		for x in v:
			a.append(_sorted(x))
		return a
	return v

func next_id(kind: String, prefix: String, width: int) -> String:
	var n: int = int(seq.get(kind, 0)) + 1
	seq[kind] = n
	return prefix + str(n).pad_zeros(width)

func note(kind: String, payload := {}) -> void:
	notes.append({"kind": kind, "payload": payload})

func push_event(ev: Dictionary) -> void:
	pending_events.append(ev)

# act que recibirá el último evento encolado (GameSim numera pending_events en orden desde seq.ev + 1).
func pending_act() -> String:
	return "act.%d" % (int(seq.get("ev", 0)) + pending_events.size())

# Copia profunda del estado canónico (sin transitorios salvo handlers): base de can() y de la restauración ante error.
func clone():
	var c = load("res://core/sim/game_state.gd").new()
	c.seed = seed
	c.load_canon(snapshot())
	c.handlers = handlers
	return c

func snapshot() -> Dictionary:
	return {"seed": seed, "clock": clock.duplicate(true), "world": world.duplicate(true), "ded": ded.duplicate(true),
		"react": react.duplicate(true), "scenes": scenes.duplicate(true), "flags": flags.duplicate(true),
		"events": events.duplicate(true), "seq": seq.duplicate(true)}

func load_canon(d: Dictionary) -> void:
	seed = int(d.get("seed", seed))
	clock = d.get("clock", {})
	world = d.get("world", {})
	ded = d.get("ded", {})
	react = d.get("react", {})
	scenes = d.get("scenes", {})
	flags = d.get("flags", {})
	events = d.get("events", [])
	seq = d.get("seq", {})
