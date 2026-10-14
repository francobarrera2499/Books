# Integración (ola 2; CORE-EXPEDIENTE v3, ARCHITECTURE §12.2, GDD_v3): una GameSim REAL (sin dobles) sobre los datos
# estructurales reales de data/ (lists, entities, schedule, dossier, corpus, reactions, places, plates, endings, eggs,
# ui_text) + el contenido mínimo de tests/fixtures/integ/ (docs, dialogue, scenes). Recorre prólogo -> amanecer del día 4
# con acciones de §3.5 y comprueba que encajan sim ↔ ded ↔ react ↔ scenes ↔ graph: tutorial del prólogo (leer, recortar,
# aviso, dormir), Q1 al empezar, Q2 al leer la hoja de #sheer, «Algo no cierra.» y tinta de Q1 y Q2 (texto exacto),
# Q4 por tinta Q1, Q3 con la voz A, Q5 con la voz B (HC10); aviso del prólogo impreso (AD:prologo), HC01, HA1, HB1, HC02,
# HB13, HC10; recortes de 15 palabras; Q1 en tinta como crédito ante Moran; convenciones de estado de Cond (inked*);
# contrato RouteDB ↔ recorte real; D1 sin violaciones; guardado/replay idéntico (GameSim.replay, EventLog, autoload Game).
# Variante «m1»: el informe 1 lleva un original P (M1 en la primera salida, HB10 lo devuelve).
# Humo: calendario completo de un pasivo hasta el epílogo (F4). Alcanzabilidad: cada variante de cada pregunta tiene
#   una respuesta indexable. data/ real sin errores (FAIL: puerta de los redactores).
# Dos modos: «fixture» (estructura de data/ + contenido de integ/) y «real» (data/ pisa a integ/).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120
const DataRepo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const BotBase = preload("res://devtools/bots/bot_base.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Invariant = preload("res://core/graph/invariant.gd")
const Director = preload("res://core/react/director.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Markup = preload("res://core/text/markup.gd")
const Cond = preload("res://core/util/cond.gd")
const ClipRules = preload("res://core/text/clip_rules.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const FIX := "res://tests/fixtures/integ"
const SEED := 1894
const LEN_RULE := "(máx. 30, GDD_v3 §6.2)"
# Modo «fixture»: de data/ sólo se toman los datos estructurales (W1/W2); el contenido de la ola 3 (docs, diálogos,
# escenas, catálogo y sus entidades) sale únicamente de tests/fixtures/integ, para que un archivo de contenido a medio
# hacer no rompa la prueba del motor (ese contenido lo juzgan test_real_data_loads_clean y el modo «real»).
const CONTENT_DIRS := ["docs/", "dialogue/", "scenes/", "catalog/"]
const STRUCT_ENTITIES := ["entities/core.json", "entities/struct.json", "entities/places_a.json", "entities/places_b.json", "entities/places_c.json", "entities/v2_fisica.json",
	"entities/v3_core.json", "entities/v3_reacciones.json", "entities/v3_contenido.json"]
# Archivos de contenido que el recorrido necesita (rutas relativas a data/).
const NEEDED := ["docs/D23.json", "docs/D03.json", "docs/D05.json", "docs/D15/0327.json",
	"docs/D15/0328.json", "docs/D15/0329.json", "docs/D15/0330.json", "dialogue/watson.json", "scenes/PRO.json"]

var _errs: Array = []
var _from_real: Array = []
var _frags: Array = []   # [{ref, copy, clip}] fragmentos del contrato §4.8 recortados en el recorrido

# ---------------- dataset combinado ----------------
static func _rel_files(root: String, rel := "") -> Array:
	var out: Array = []
	var dir := root.path_join(rel) if rel != "" else root
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d.begins_with("_"):
			continue
		out.append_array(_rel_files(root, rel.path_join(d) if rel != "" else d))
	return out

# mode "fixture": integ pisa a data · "real": data pisa a integ. Devuelve la ruta absoluta del dataset.
func _build(mode: String) -> String:
	var dst := tmp_dir().path_join("data_" + mode)
	DirAccess.make_dir_recursive_absolute(dst)
	var real := ProjectSettings.globalize_path("res://data")
	var fix := ProjectSettings.globalize_path(FIX)
	var first := real if mode == "fixture" else fix
	var second := fix if mode == "fixture" else real
	_from_real = []
	for rel in _rel_files(first):
		if mode == "fixture" and first == real and not _structural(rel):
			continue
		var to := dst.path_join(rel)
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		DirAccess.copy_absolute(first.path_join(rel), to)
	for rel in _rel_files(second):
		var to2 := dst.path_join(rel)
		DirAccess.make_dir_recursive_absolute(to2.get_base_dir())
		DirAccess.copy_absolute(second.path_join(rel), to2)
	if mode == "real":
		for rel in NEEDED:
			if FileAccess.file_exists(real.path_join(rel)):
				_from_real.append(rel)
	return dst

static func _structural(rel: String) -> bool:
	for d in CONTENT_DIRS:
		if rel.begins_with(d):
			return false
	if rel.begins_with("entities/"):
		return STRUCT_ENTITIES.has(rel)
	return true

func _repo(mode: String):
	var root := _build(mode)
	DataRepo.clear_cache(root)
	return DataRepo.fresh(root)

# ---------------- utilidades del recorrido ----------------
func _e(msg: String) -> void:
	_errs.append(msg)

func _chk(cond: bool, msg: String) -> void:
	if not cond:
		_e(msg)

func _act(sim, a: Dictionary) -> Dictionary:
	var r: Dictionary = sim.apply(a)
	if not r.get("ok", false):
		_e("%s -> %s (clock %s)" % [J.stringify_canon(a), J.stringify_canon(r), J.stringify_canon(sim.q_clock().duplicate().merged({"tutorial": {}}, true))])
	return r

# Recorta exactamente el tramo #tid de una vista legible ahora (oráculo, como clip_ref de los bots §9.3).
func _clip_tramo(sim, view: String, tid: String) -> String:
	var v: Dictionary = sim.q_view(view)
	if v.is_empty():
		_e("vista %s inaccesible para recortar #%s" % [view, tid])
		return ""
	var pages: Array = v.pages
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var p: Dictionary = pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				if String(t.id) == tid:
					var sp: Array = BotBase.best_window(p, int(t.from), int(t.to))
					var r := _act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])})
					return String(r.get("clip", ""))
	_e("vista %s sin tramo #%s" % [view, tid])
	return ""

# Recorta un bloque runtime insertado (aviso, columna «—S.») por su primer tramo con la etiqueta pedida.
func _clip_tagged(sim, view: String, tag: String) -> String:
	var v: Dictionary = sim.q_view(view)
	for pi in (v.get("pages", []) as Array).size():
		for bi in (v.pages[pi] as Array).size():
			var p: Dictionary = v.pages[pi][bi].get("parsed", {})
			for t in p.get("tramos", []):
				if RDB._as_arr(t.tags.get(tag.get_slice(":", 0), [])).has(tag.get_slice(":", 1)):
					var sp: Array = BotBase.best_window(p, int(t.from), int(t.to))
					var r := _act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])})
					return String(r.get("clip", ""))
	_e("vista %s sin tramo con %s" % [view, tag])
	return ""

func _frag(ref: String, copy: String, clip: String) -> void:
	if clip != "":
		_frags.append({"ref": ref, "copy": copy, "clip": clip})

func _cond(sim, c: Dictionary) -> bool:
	return Cond.eval(c, {"st": sim.st, "repo": sim.repo})

func _delivered(sim, rid: String) -> Array:
	var out: Array = []
	for inst in sim.st.react.delivered:
		if String(inst.rid) == rid:
			out.append(inst)
	return out

func _queued(sim, rid: String) -> Array:
	var out: Array = []
	for inst in sim.st.react.queue:
		if String(inst.rid) == rid:
			out.append(inst)
	return out

func _tray_views(sim, day: int) -> Array:
	var out: Array = []
	for it in sim.q_tray(day):
		out.append(String(it.view))
	return out

func _diary_by(sim, pred: Callable) -> Array:
	var out: Array = []
	for e in sim.q_diary():
		if pred.call(e):
			out.append(e)
	return out

func _clip_tags(sim, id: String) -> Array:
	return Clipper.get_clip(sim.st, id).get("tags", [])

func _expect_phase(sim, phase: String, day: int, slot: String, where: String) -> void:
	var c: Dictionary = sim.q_clock()
	_chk(String(c.phase) == phase and int(c.day) == day and String(c.slot) == slot,
		"%s: se esperaba %s %d.%s y hay %s %d.%s" % [where, phase, day, slot, c.phase, int(c.day), c.slot])

# Invariante de rutas (D1) sobre el estado real: ninguna pregunta obligatoria sin tinta queda sin ruta.
func _guard(sim, where: String) -> void:
	var g: Dictionary = Invariant.runtime_guard(sim.st, sim.repo, [])
	_chk(bool(g.get("ok", false)), "%s: runtime_guard viola %s" % [where, str(g.get("violated", []))])

# ---------------- el recorrido ----------------
# Devuelve la GameSim al final (amanecer/escritorio del día 4) o null si se cortó. Deja los problemas en _errs.
# variant: "nada" (informe 1 «sin novedad») · "m1" (el informe 1 lleva un original P: M1 en la primera salida del 3,
#   retira ESE ejemplar y registra la buhardilla; HB10 lo devuelve por el mostrador de Crane).
func _walk(repo, variant := "nada"):
	_errs = []
	_frags = []
	# El largo de los tramos etiquetados (≤30 palabras, GDD_v3 §6.2) es de CONTENIDO: lo juzgan test_dataset_loads_clean y
	# test_real_data_loads_clean; no cambia lo que hace el motor, así que no corta el recorrido.
	var errs: Array = (repo.errors() as Array).filter(func(e): return not String(e).contains(LEN_RULE))
	if not errs.is_empty():
		_e("errores de carga del dataset: %s" % str(errs.slice(0, 8)))
		return null
	var sim = GameSim.new(repo, SEED)
	# --- prólogo (P, noche): tutorial con instructor; un verbo por paso (GDD_v3 §6.9) ---
	_expect_phase(sim, "prologue", 0, "N", "inicio")
	var t0: Dictionary = sim.q_tutorial()
	_chk(String(t0.step.get("id", "")) == "read", "el tutorial empieza por abrir el encargo: %s" % str(t0))
	_chk(String(sim.can({"t": "go", "place": "L2", "area": "sala", "seat": 214}).err) == "fase", "en el prólogo no se sale")
	_chk(String(sim.can({"t": "dq_confirm", "q": "Q1"}).err) == "tutorial", "en el prólogo no se adelanta un paso")
	var dv0: Dictionary = sim.q_dossier()
	_chk((dv0.get("open", []) as Array).map(func(h): return String(h.id)) == ["Q1"], "partida nueva: el expediente abre con Q1: %s" % str(dv0.get("open", [])))
	_act(sim, {"t": "read", "view": "D23@L1", "part": 0})
	var c_aviso := _clip_tramo(sim, "D23@L1", "aviso")
	_chk(c_aviso != "" and sim.q_index().any(func(x): return String(x.id) == "suceso_reichenbach"), "el recorte del encargo indexa suceso_reichenbach")
	_chk(not sim.q_clip(c_aviso).has("tags"), "q_clip no muestra etiquetas ocultas")
	var c_sheer_tomo := _clip_tramo(sim, "D03@tomo", "sheer")
	_chk(_clip_tags(sim, c_sheer_tomo).has("a:fina_impreso_sin_raspadura"), "ClipRules.inherit hereda las a: con prefijo: %s" % str(_clip_tags(sim, c_sheer_tomo)))
	var ra := _act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_chk(String(ra.get("ad", "")) == "AD:prologo" and int(ra.get("pub_day", -1)) == 1, "aviso del prólogo -> AD:prologo, sale el día 1: %s" % str(ra))
	_chk(bool(sim.q_tutorial().complete), "tutorial completo antes de dormir")
	var taught: Array = sim.q_tutorial().taught
	for v in ["read", "clip_text", "compose_ad"]:
		_chk(taught.has(v), "verbo enseñado en el prólogo: " + v)
	var pro_lines: Array = _diary_by(sim, func(e): return String(e.kind) == "line" and String(e.origin) == "S.PRO")
	_chk(pro_lines.size() >= 3, "las líneas del prólogo (escena e instructor) van al diario con origen S.PRO: %d" % pro_lines.size())
	_act(sim, {"t": "sleep"})
	# --- día 1, amanecer: bandeja, aviso impreso, HC01 ---
	_expect_phase(sim, "desk", 1, "M", "día 1")
	var tray1 := _tray_views(sim, 1)
	_chk(tray1.has("D15.0327@L1"), "el Times del martes llega a la bandeja: %s" % str(tray1))
	var hc01 := _delivered(sim, "HC01")
	_chk(hc01.size() == 1 and int(hc01[0].delivered_tk) == TimeKey.tk(1, "dawn"), "HC01 entregada al amanecer del día 1")
	var ad_ev := {}
	for ev in sim.st.events:
		if String(ev.type) == "ad":
			ad_ev = ev
	_chk(String(ad_ev.get("ad", "")) == "AD:prologo" and int(ad_ev.get("tk", -1)) == TimeKey.tk(1, "dawn"), "evento ad del prólogo al amanecer del día 1: %s" % str(ad_ev))
	var ins: Array = sim.st.world.inserts.get("D15.0327", {}).get("p2", [])
	_chk(ins.size() == 1, "el aviso quedó impreso en la columna (p2) del Times del día 1: %s" % str(sim.st.world.inserts))
	_chk(_diary_by(sim, func(e): return String(e.get("type", "")) == "ad").size() == 1, "el diario anota «sale mi aviso»")
	_chk(String(sim.q_tutorial().day1.get("id", "")) == "d1_leer", "día 1 guiado: leer «El problema final»")
	# --- día 1 M: Kensington, cebo a Watson (K-W) ---
	_act(sim, {"t": "go", "place": "L4", "area": "consulta"})
	_chk(sim.q_scene().chars.any(func(c): return String(c.id) == "watson"), "Watson está en la consulta por la mañana")
	_chk(sim.q_assertions().any(func(x): return String(x.id) == "as.pared"), "as.pared afirmable (reichenbach y pared en el índice)")
	_chk(_cond(sim, {"char_present": "watson"}) and not _cond(sim, {"char_present": "mrs_hudson"}), "Cond char_present lee st.world.visit.chars")
	var rs := _act(sim, {"t": "assert", "char": "watson", "assertion": "as.pared"})
	_chk(typeof(rs.get("line")) == TYPE_DICTIONARY and String(rs.line.get("text", "")) != "", "Watson contesta con la línea de afirmación: %s" % str(rs.get("line")))
	var hb1q := _queued(sim, "HB1")
	_chk(hb1q.size() == 1 and int(hb1q[0].due_tk) == TimeKey.tk(4, "dawn") and String(hb1q[0].channel) == "K-W",
		"HB1 (Ley 2, cebo 1, K-W) en cola para la voz B del día 1 -> 4.dawn: %s" % str(hb1q))
	_chk(sim.q_diary().any(func(e): return String(e.kind) == "line" and String(e.who) == "watson"), "la respuesta de Watson queda en el diario")
	var wl: Array = sim.q_scene().lines.filter(func(l): return String(l.who) == "watson")
	if wl.size() >= 1:
		var pw: Dictionary = wl[0].parsed
		var s1: Array = pw.sentences[0]
		var sp: Array = BotBase.best_window(pw, int(s1[0]), int(s1[1]))
		var c_w := String(_act(sim, {"t": "clip_text", "src": {"kind": "line", "ref": String(wl[0].uid)}, "from": int(sp[0]), "len": int(sp[1]) - int(sp[0])}).get("clip", ""))
		var cw: Dictionary = Clipper.get_clip(sim.st, c_w)
		_chk(String(cw.get("origin", "")) == "S.L4.1.M" and (cw.get("ents", []) as Array).has("watson"), "recorte de lo dicho por Watson: origen = visita, entidad watson: %s" % str([cw.get("origin", ""), cw.get("ents", [])]))
	else:
		_e("la visita debería tener una línea de Watson: %s" % str(sim.q_scene().lines))
	_act(sim, {"t": "leave"})
	_chk(String(sim.can({"t": "go", "place": "L2", "area": "sala", "seat": 214}).err) == "ya_salio", "una salida por franja")
	_act(sim, {"t": "end_slot"})
	# --- día 1 T: Sala de Lectura (papeleta -> HA1), tienda de Crane (gratis) ---
	_act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	_act(sim, {"t": "slip", "doc": "D05"})
	var ha1q := _queued(sim, "HA1")
	_chk(ha1q.size() == 1 and int(ha1q[0].due_tk) == TimeKey.tk(2, "dawn"), "HA1 garantizada (papeleta de tema holmes) -> 2.dawn: %s" % str(ha1q))
	var c_marque := _clip_tramo(sim, "D05@BM", "marque")
	var c_corniche := _clip_tramo(sim, "D05@BM", "corniche")
	_frag("D05#marque", "D05@BM", c_marque)
	_frag("D05#corniche", "D05@BM", c_corniche)
	_chk(_clip_tags(sim, c_marque).has("a:raspadura_registrada"), "D05#marque hereda a:raspadura_registrada")
	_act(sim, {"t": "leave"})
	_chk(String(sim.can({"t": "clip_text", "src": {"kind": "doc", "ref": "D05@BM", "part": 0, "block": 0}, "from": 0, "len": 9}).err) == "inaccesible",
		"fuera de la Sala la papeleta ya no es legible")
	_act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	var c_sheer := _clip_tramo(sim, "D03@Crane", "sheer")
	_frag("D03#sheer", "D03@Crane", c_sheer)
	_frag("D03#a_mycroft", "D03@Crane", _clip_tramo(sim, "D03@Crane", "a_mycroft"))
	_chk(sim.q_index().any(func(x): return String(x.id) == "mycroft"), "D03#a_mycroft indexa a Mycroft")
	_act(sim, {"t": "leave"})
	# --- el Expediente (GDD_v3 §1): leer la hoja de #sheer hace nacer Q2; Q1 y Q2 en tinta ---
	_chk(not Dossier.is_born(sim.st, "Q2"), "Q2 todavía no nació (recortar no es leer)")
	for pi in (sim.q_view("D03@tomo").get("pages", []) as Array).size():
		_act(sim, {"t": "read", "view": "D03@tomo", "part": pi})
	_chk(Dossier.is_open(sim.st, "Q2"), "leer la hoja de D03#sheer hace nacer Q2: %s" % str(sim.q_dossier().get("open", [])))
	# hoja mala: la respuesta y dos pruebas que no cubren los dos grupos -> «Algo no cierra.» (cuenta el intento)
	_act(sim, {"t": "dq_answer", "q": "Q1", "value": "raspadura"})
	_act(sim, {"t": "dq_proof", "q": "Q1", "slot": 0, "clip": c_sheer_tomo})
	_act(sim, {"t": "dq_proof", "q": "Q1", "slot": 1, "clip": c_corniche})
	var p1 := _act(sim, {"t": "dq_confirm", "q": "Q1"})
	_chk(bool(p1.get("ok", false)) and not bool(p1.get("inked", true)) and String(p1.get("msg", "")) == "Algo no cierra.", "hoja que no cierra: %s" % str(p1))
	_chk(int(sim.st.ded.dossier.attempts.get("Q1", 0)) == 1 and not Dossier.inked(sim.st).has("Q1"), "el intento cuenta; Q1 sigue en lápiz")
	# error de forma: no cuenta
	_act(sim, {"t": "dq_proof", "q": "Q1", "slot": 1, "clip": ""})
	_chk(String(sim.can({"t": "dq_confirm", "q": "Q1"}).err) == "formal", "falta una prueba: error de forma")
	_act(sim, {"t": "dq_proof", "q": "Q1", "slot": 1, "clip": c_marque})
	var ok1: Dictionary = Dossier.check(sim.st, sim.repo, "Q1")
	_chk(bool(ok1.get("ok", false)), "Q1 cierra con #sheer + #marque: %s" % str(ok1))
	var p2 := _act(sim, {"t": "dq_confirm", "q": "Q1"})
	_chk(bool(p2.get("inked", false)) and String(p2.get("text", "")) == String(repo.question("Q1").variantes[0].tinta), "Q1 en tinta con el texto de Lisle: %s" % str(p2))
	_chk(Dossier.is_born(sim.st, "Q4"), "tinta Q1 hace nacer Q4")
	_act(sim, {"t": "dq_answer", "q": "Q2", "value": "cornisa"})
	_act(sim, {"t": "dq_proof", "q": "Q2", "slot": 0, "clip": c_corniche})
	_act(sim, {"t": "dq_proof", "q": "Q2", "slot": 1, "clip": c_sheer})
	var p3 := _act(sim, {"t": "dq_confirm", "q": "Q2"})
	_chk(bool(p3.get("inked", false)), "Q2 en tinta (grupos en cualquier orden): %s" % str(p3))
	_chk(String(sim.can({"t": "dq_answer", "q": "Q1", "value": "cornisa"}).err) != "", "la tinta no se edita")
	_chk(sim.q_tutorial().day1.is_empty(), "día 1 guiado completo")
	_guard(sim, "tras entintar Q1/Q2")
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_expect_phase(sim, "night", 1, "night", "noche 1")
	_chk(_queued(sim, "HB13").is_empty() and _delivered(sim, "HB13").is_empty(), "día 1 con actos observados: sin HB13")
	_act(sim, {"t": "sleep"})
	# --- día 2: HA1 entregada; HA0 no (hubo papeleta); inactividad ---
	_expect_phase(sim, "desk", 2, "M", "día 2")
	var ha1 := _delivered(sim, "HA1")
	_chk(ha1.size() == 1 and String(ha1[0].get("how", "")) == "correo", "HA1 al amanecer del 2, por correo: %s" % str(ha1.map(func(i): return [i.tpl, i.get("how", "")])))
	_chk(_delivered(sim, "HA0").is_empty() and _queued(sim, "HA0").is_empty(), "HA0 no (hubo papeleta de tema holmes el día 1)")
	_chk(Dossier.is_born(sim.st, "Q3"), "Q3 nació con la primera carta a máquina (voz A): %s" % str(sim.st.ded.dossier.born.keys()))
	if ha1.size() == 1:
		var v_ha1 := String(ha1[0].view)
		_chk(_tray_views(sim, 2).has(v_ha1), "la carta de HA1 en la bandeja del día 2")
		var c_ancla := _clip_tagged(sim, v_ha1, "a:ancla_kbm")
		_frag("R:HA1.*", "", c_ancla)
		var ents: Array = Clipper.get_clip(sim.st, c_ancla).get("ents", [])
		_chk(ents.any(func(e): return String(e).begins_with("act.")), "el ancla de HA1 cita el acto (entidad act_ref): %s" % str(ents))
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_expect_phase(sim, "night", 2, "night", "noche 2")
	var hb13q := _queued(sim, "HB13")
	_chk(hb13q.size() == 1 and int(hb13q[0].due_tk) == TimeKey.tk(3, "dawn"), "HB13: dos franjas sin actos observados -> voz A al amanecer del 3: %s" % str(hb13q))
	_chk(String(sim.can({"t": "sleep"}).err) == "informe_pendiente", "noche de informe: no se duerme sin entregarlo")
	_chk(sim.q_report_status().due and int(sim.q_report_status().n) == 1, "informe 1 debido")
	if variant == "m1":
		_act(sim, {"t": "report_submit", "mode": "items", "items": [{"kind": "clip", "id": c_sheer_tomo}]})
		var rev: Dictionary = sim.st.events[-1]
		_chk(String(rev.type) == "report" and RDB.cats_of(rev).has("original_p"), "el informe lleva original_p (recorte de un ejemplar P): %s" % str(rev.get("items", [])))
		_chk(_queued(sim, "M1").size() == 1, "M1 espera la primera salida del día 3: %s" % str(_queued(sim, "M1")))
		_chk(int(sim.st.flags.get("informes_vacios", 0)) == 0, "un informe con elementos no es vacío")
	else:
		var rq := _act(sim, {"t": "report_submit", "mode": "items", "items": [{"kind": "pregunta", "id": "Q1"}]})
		var rev2: Dictionary = sim.st.events[-1]
		_chk(bool(rq.get("ok", false)) and String(rev2.type) == "report" and RDB.cats_of(rev2).has("verdadero"), "Q1 en tinta: Moran la lee «verdadero» (crédito): %s" % str(rev2.get("items", [])))
	_chk(_diary_by(sim, func(e): return String(e.get("type", "")) == "report").size() == 1, "diario: entregué el informe 1")
	_act(sim, {"t": "sleep"})
	# --- día 3: HC02 (Wiggins), HB13 entregada; Baker Street (K-S) ---
	_expect_phase(sim, "desk", 3, "M", "día 3")
	_chk(_delivered(sim, "HC02").size() == 1, "HC02 al amanecer del 3")
	var hb13 := _delivered(sim, "HB13")
	_chk(hb13.size() == 1 and _tray_views(sim, 3).has(String(hb13[0].get("view", ""))), "HB13 entregada en la bandeja del 3: %s" % str(hb13))
	var rg := _act(sim, {"t": "go", "place": "L3", "area": "calle"})
	var plate := String(rg.get("plate", ""))
	_chk(plate == "PL.L3.3.M", "lámina de la visita: " + plate)
	var snap: Dictionary = sim.q_visit_plate()
	_chk((snap.get("silhouettes", []) as Array).has("sil_wiggins"), "la silueta de Wiggins está en la lámina desde el día 3: %s" % str(snap.get("silhouettes", [])))
	var rc := _act(sim, {"t": "clip_plate", "plate": plate, "hits": [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], "touched": ["sil_wiggins"], "area_frac": 0.05})
	var c_sil := String(rc.get("clip", ""))
	_frag("N:*.sil_wiggins", "", c_sil)
	var go_lines := _diary_by(sim, func(e): return String(e.get("type", "")) == "go" and int(e.day) == 3)
	_chk(go_lines.size() == 1 and String(go_lines[0].key) == "go.L3.calle", "diario: J:go de Baker Street (calle): %s" % str(go_lines))
	if go_lines.size() == 1:
		var plain := String(go_lines[0].parsed.plain)
		var spg: Array = BotBase.best_window(go_lines[0].parsed, 0, plain.length())
		var c_jgo := String(_act(sim, {"t": "clip_text", "src": {"kind": "diary", "ref": String(go_lines[0].id)}, "from": int(spg[0]), "len": int(spg[1]) - int(spg[0])}).get("clip", ""))
		_chk(c_jgo != "", "el diario se recorta (J:go)")
		var act_go := String(go_lines[0].act)
		_chk(Clipper.get_clip(sim.st, c_jgo).ents.has(act_go) and Clipper.get_clip(sim.st, c_sil).ents.has(act_go),
			"diario y silueta citan el mismo acto %s" % act_go)
	_act(sim, {"t": "leave"})
	if variant == "m1":
		var m1 := _delivered(sim, "M1")
		_chk(m1.size() == 1, "M1 se resuelve el día 3: %s" % str(m1.map(func(i): return [i.delivered_tk, i.get("soft", "")])))
		_chk(not sim.q_accessible().any(func(x): return String(x.view) == "D03@tomo"), "D03@tomo falta en la buhardilla el día 3")
		_chk(String(sim.q_hub_plate().variant) == "registrada", "variante «registrada» de L1")
		_chk(_queued(sim, "HB10").size() == 1, "HB10 (Ley 3: lo robado vuelve) en cola tras M1")
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_expect_phase(sim, "night", 3, "night", "noche 3")
	_act(sim, {"t": "sleep"})
	# --- día 4, amanecer: HC10 (columna «—S.»: nace Q5), HB1 (carta «—S.») ---
	_expect_phase(sim, "desk", 4, "M", "día 4")
	var hc10 := _delivered(sim, "HC10")
	_chk(hc10.size() == 1 and String(hc10[0].get("how", "")) == "columna", "HC10 en la columna del 30: %s" % str(hc10))
	_chk((sim.st.world.inserts.get("D15.0330", {}).get("p2", []) as Array).size() == 1, "HC10 insertada en D15.0330 (p2)")
	_chk(Dossier.is_born(sim.st, "Q5"), "Q5 nació con la respuesta de «S.» (voz B)")
	var hb1 := _delivered(sim, "HB1")
	_chk(hb1.size() == 1 and String(hb1[0].get("how", "")) == "correo", "HB1 al amanecer del 4, por correo (Ley 5): %s" % str(hb1.map(func(i): return [i.tpl, i.get("how", "")])))
	if variant == "m1":
		var hb10 := _delivered(sim, "HB10")
		_chk(hb10.size() == 1 and String(hb10[0].get("how", "")) == "mostrador_crane", "HB10 devuelve el original por el mostrador de Crane: %s" % str(hb10.map(func(i): return [i.get("how", ""), i.get("returned", [])])))
	var c_ad := _clip_tagged(sim, "D15.0327@L1", "a:acto_kt")
	_frag("AD:prologo", "D15.0327@L1", c_ad)
	var act_ad := String(ad_ev.get("act", ""))
	_chk(c_ad == "" or Clipper.get_clip(sim.st, c_ad).ents.has(act_ad), "el aviso impreso cita el acto %s" % act_ad)
	_guard(sim, "día 4")
	# --- invariantes de ceguera y de la sesión ---
	for inst in sim.st.react.delivered:
		if ["holmes", "mycroft"].has(String(inst.get("lado", ""))):
			_chk(not String(inst.get("text", "")).contains("secreto_camden"), "%s (bando de Holmes) no cita secreto_camden (T22)" % inst.iid)
	_chk(not sim.st.react.has("ded"), "react/ no copia st.ded")
	_state_conventions(sim, variant)
	_route_contract(sim)
	return sim

# (h) Convenciones de estado que asume Cond (§4.18) contra lo que escriben SIM, REACT, DED y SCENES.
func _state_conventions(sim, variant: String) -> void:
	var visits: Array = sim.st.world.visits
	_chk(visits.has("S.L4.1.M") and visits.has("S.L3.3.M"), "st.world.visits = S.<lugar>.<día>.<franja>: %s" % str(visits))
	_chk(_cond(sim, {"visited": "L4"}) and _cond(sim, {"visited": "L3"}) and _cond(sim, {"visited": "L1"}), "Cond visited sobre S.<L>.<d>.<s>")
	_chk(not _cond(sim, {"visited": "L5"}), "visited L5 falso")
	_chk(_cond(sim, {"inked_all": ["Q1", "Q2"]}) and _cond(sim, {"inked": "Q1"}) and _cond(sim, {"inked_count": {"gte": 2}}), "Cond inked* sobre st.ded.dossier.inked")
	_chk(_cond(sim, {"sealed_all": ["C2", "C3"]}), "compatibilidad: sealed* (C2/C3 v2) se lee como tinta de Q1/Q2")
	_chk(_cond(sim, {"counter": {"name": "fired.HB1", "eq": 1}}) and _cond(sim, {"counter": {"name": "delivered.HA1", "eq": 1}}), "Cond counter sobre st.react.counters (fired./delivered.)")
	_chk(_cond(sim, {"event_count": {"type": "slip", "where": {"day": 1, "topic": ["holmes_prensa_1891"]}, "gte": 1}}), "event_count con lista (HA0)")
	_chk(_cond(sim, {"all": [{"day": 4}, {"slot": ["M"]}, {"weekday": "vie"}, {"tk": {"gte": "4.dawn"}}]}), "día/franja/weekday/tk del reloj")
	_chk(_cond(sim, {"not": {"channel_closed": "K-W"}}), "channel_closed sobre canal_cerrado.K-x")
	_chk(not _cond(sim, {"report_final_cats_any": ["original_p"]}), "report_final_cats_any sólo mira el informe final")

# Contrato sim <-> graph: el modelo de rutas (RouteDB.resolve) promete las mismas etiquetas heredables y el mismo origen
# que el recorte real. Para fragmentos de un tramo (D#, AD:, J:, N:) las a:/c:/f:/p:/x: deben coincidir; para R: (varios
# tramos) las del recorte deben estar en tags_any del modelo.
func _route_contract(sim) -> void:
	for f in _frags:
		var d: Dictionary = RouteDB.resolve(sim.repo, String(f.ref), String(f.copy))
		if String(d.get("missing", "")) != "":
			_e("RouteDB %s: %s" % [f.ref, d.missing])
			continue
		var clip: Dictionary = Clipper.get_clip(sim.st, String(f.clip))
		var got: Array = []
		for t in clip.get("tags", []):
			var pre := String(t).get_slice(":", 0)
			if ClipRules.INHERIT.has(pre) and pre != "d":
				got.append(String(t))
		var model: Array = []
		for t in (d.tags_any if String(f.ref).begins_with("R:") else d.tags):
			var pre2 := String(t).get_slice(":", 0)
			if ClipRules.INHERIT.has(pre2) and pre2 != "d":
				model.append(String(t))
		got.sort()
		model.sort()
		if String(f.ref).begins_with("R:"):
			for t in got:
				_chk(model.has(t), "%s: el recorte trae %s y el modelo de rutas no (%s)" % [f.ref, t, str(model)])
		else:
			_chk(got == model, "%s: etiquetas del recorte %s != modelo de rutas %s" % [f.ref, str(got), str(model)])
		var o := String(clip.get("origin", ""))
		var mo := String(d.origin)
		_chk(o == mo or o.begins_with(mo + ".") or (mo.ends_with(".*") and o.begins_with(mo.trim_suffix("*"))),
			"%s: origen del recorte %s no corresponde al del modelo %s" % [f.ref, o, mo])
		_chk(String(f.copy) == "" or String(clip.get("cls", "")) == String(d.cls), "%s: clase %s != modelo %s" % [f.ref, clip.get("cls", ""), d.cls])

# ---------------- guardado y replay ----------------
func _save_replay(sim, repo) -> void:
	var alog: Array = sim.actions_log()
	var a = GameSim.replay(repo, SEED, alog)
	var b = GameSim.replay(repo, SEED, alog)
	_chk(a.replay_errors == 0 and b.replay_errors == 0, "replay sin acciones rechazadas")
	_chk(a.state_hash() == sim.state_hash(), "replay reproduce el estado vivo")
	_chk(a.state_hash() == b.state_hash(), "replay ×2 = mismo state_hash (T9)")
	var d := tmp_dir()
	var p1 := d.path_join("i1.jsonl")
	var p2 := d.path_join("i2.jsonl")
	var hdr := EventLog.make_header(SEED, repo.content_hash())
	_chk(EventLog.new(p1).write(hdr, alog), "EventLog.write")
	var r: Dictionary = EventLog.read(p1)
	_chk(bool(r.get("ok", false)) and (r.get("actions", []) as Array).size() == alog.size(), "EventLog.read: %s" % str(r.get("err", "")))
	_chk(EventLog.new(p2).write(r.header, r.actions), "EventLog.write 2")
	_chk(FileAccess.get_file_as_bytes(p1) == FileAccess.get_file_as_bytes(p2), "escribir -> leer -> escribir = mismos bytes")
	var c = GameSim.replay(repo, int(r.header.seed), r.actions)
	_chk(c.state_hash() == sim.state_hash(), "lo leído del disco reproduce el estado")
	# autoload Game: escribe ANTES de devolver cada acción comprometida; continuar = mismo estado
	var old := [Game.save_path, Game.repo_override, Game.sim_handlers]
	Game.save_path = d.path_join("partida.jsonl")
	Game.repo_override = repo
	Game.sim_handlers = {}
	_chk(Game.new_session(SEED), "Game.new_session")
	for x in alog:
		var rr: Dictionary = Game.act(x)
		if not rr.get("ok", false):
			_e("Game.act rechazó %s: %s" % [J.stringify_canon(x), str(rr)])
			break
	_chk(Game.flush(), "Game.flush")
	var h1: String = Game.sim.state_hash()
	_chk(h1 == sim.state_hash(), "Game.act reproduce el recorrido")
	Game.end_session()
	_chk(Game.continue_session(), "Game.continue_session")
	_chk(Game.sim != null and Game.sim.state_hash() == h1, "continuar = mismo estado")
	Game.end_session()
	Game.save_path = old[0]
	Game.repo_override = old[1]
	Game.sim_handlers = old[2]

# ---------------- alcanzabilidad de respuestas (validador <-> contenido) ----------------
# Entidades que el jugador puede llegar a tener en el índice: lo que entra al recortar (menciones, e:, entity del doc,
# clip_entities, máquina) en docs, lugares, láminas, diálogos, escenas y rastros de reacciones; más lisle (inicial).
static func _ents_of_text(repo, text: String, out: Dictionary) -> void:
	var ctx: Dictionary = repo.markup_ctx().duplicate()
	ctx["allow_placeholders"] = true
	var pt := Markup.parse(text, ctx)
	for m in pt.mentions:
		out[String(m.ent)] = true
	for t in pt.tramos:
		for e in t.tags.get("e", []):
			out[String(e)] = true

static func _tags_ents(tags, out: Dictionary) -> void:
	for t in RDB._as_arr(tags):
		if String(t).begins_with("e:"):
			out[String(t).substr(2)] = true

static func indexable(repo) -> Dictionary:
	var out := {"lisle": true}
	for did in repo.docs():
		var d: Dictionary = repo.doc(did)
		out[String(d.get("entity", ""))] = true
		for e in RDB._as_arr(d.get("clip_entities", [])):
			out[String(e)] = true
		if String(d.get("machine", "")) != "" and d.machine != null:
			out[String(Clipper.MACHINE_ENTS.get(String(d.machine), d.machine))] = true
		for p in d.get("parts", []):
			_ents_of_text(repo, String(p.get("text", "")), out)
	for src in [repo.places(), repo.plates()]:
		for pid in src:
			var pl: Dictionary = src[pid]
			for n in pl.get("nodes", []):
				_ents_of_text(repo, String(n.get("examine", "")), out)
				_tags_ents(n.get("tags", []), out)
			for vk in pl.get("variants", {}):
				for n in pl.variants[vk].get("add_nodes", []) if typeof(pl.variants[vk]) == TYPE_DICTIONARY else []:
					_ents_of_text(repo, String(n.get("examine", "")), out)
					_tags_ents(n.get("tags", []), out)
	for cid in repo.dialogues():
		var dl: Dictionary = repo.dialogue(cid)
		if not repo.entity(String(cid)).is_empty():
			out[String(cid)] = true
		for ln in dl.get("lines", []):
			_ents_of_text(repo, String(ln.get("text", "")), out)
	for sid in repo.scenes():
		var sc: Dictionary = repo.scene(sid)
		var lines: Array = (sc.get("lines", []) as Array).duplicate()
		for v in sc.get("variants", []):
			lines.append_array(v.get("append", []))
			for k in v.get("replace", {}):
				lines.append({"text": v.replace[k]})
		for ln in lines:
			_ents_of_text(repo, String(ln.get("text", ln.get("fallback", ""))), out)
			for k in ln.get("tpl", {}):
				_ents_of_text(repo, String(ln.tpl[k]), out)
			if not repo.entity(String(ln.get("who", ""))).is_empty():
				out[String(ln.who)] = true
	for r in repo.reactions():
		var dd = r.get("doc", {})
		if typeof(dd) == TYPE_DICTIONARY and String(dd.get("entity", "")) != "":
			out[String(dd.entity)] = true
		for rs in r.get("rastro", []):
			_ents_of_text(repo, String(rs.get("texto", "")), out)
			_tags_ents(rs.get("tags", []), out)
	return out

# [Qn(.v): respuestas] de variantes sin ninguna respuesta que algún contenido permita indexar.
static func unreachable_answers(repo, only := []) -> Array:
	var idx := indexable(repo)
	var out: Array = []
	for q in repo.questions():
		var qid := String(q.id)
		if not only.is_empty() and not only.has(qid):
			continue
		for v in q.get("variantes", []):
			var hit := false
			for a in v.get("respuestas", []):
				var vs := String(a)
				if vs.begins_with("@alias:"):
					vs = vs.substr(7)
				if idx.has(vs):
					hit = true
			if not hit:
				out.append("%s.%s: %s" % [qid, v.get("id", "?"), str(v.get("respuestas", []))])
	return out

# ---------------- tests ----------------
# Toda pregunta debe poder contestarse: cada variante tiene ≥1 respuesta que algún contenido indexa. En fixtures: Q1 y Q2
# (lo que el recorrido usa) siempre; sobre data/ real: pendiente mientras falte contenido.
func test_answers_indexable():
	eq(unreachable_answers(_repo("fixture"), ["Q1", "Q2"]), [], "fixtures de integración")
	var real := unreachable_answers(load("res://core/data/data_repo.gd").load_dir("res://data"))
	if not real.is_empty():
		pending_content("%d variantes sin respuesta indexable en data/ (p. ej. %s)" % [real.size(), str(real.slice(0, 6))])

# data/ real sin errores de esquema, marcado, entidades ni tramos del contrato (lo mismo que devtools/lint.gd -- data).
# Un archivo de contenido a medio hacer de la ola 3 falla AQUÍ con su ruta: es la puerta de cada redactor.
func test_real_data_loads_clean():
	var r = load("res://core/data/data_repo.gd").fresh("res://data")
	eq(r.errors(), [], "data/ sin errores")

func test_dataset_loads_clean():
	var repo = _repo("fixture")
	eq(repo.errors(), [], "datos reales + integ sin errores de esquema ni de entidades")
	var lint: Array = RDB.lint(repo)
	eq(lint, [], "gramática de reacciones (ReactionDB.lint) sobre datos reales")

func test_walk_prologue_to_day4_fixture_content():
	var repo = _repo("fixture")
	var sim = _walk(repo)
	if sim != null:
		_save_replay(sim, repo)
	for e in _errs:
		fail(e)

func test_walk_report_m1_fixture_content():
	var repo = _repo("fixture")
	var sim = _walk(repo, "m1")
	if sim != null:
		_save_replay(sim, repo)
	for e in _errs:
		fail(e)

# Calendario completo con un jugador que no hace nada (pasivo): prólogo -> día 10 (confrontación callando, informe final
# «sin novedad», Park Lane, noche) -> epílogo -> done. Con datos estructurales reales: ningún error del motor, el
# director resuelve todas las columnas (M6 sin escena = nota; HC03 en mano el domingo; M7…), final F4 (GDD§12.1).
func test_calendar_to_epilogue_smoke():
	var repo = _repo("fixture")
	_errs = []
	var sim = GameSim.new(repo, SEED)
	var full = _walk(repo)
	if full == null:
		for e in _errs:
			fail(e)
		return
	# el prólogo del recorrido (hasta el primer sleep inclusive)
	for a in full.actions_log():
		_act(sim, a)
		if String(a.t) == "sleep":
			break
	var phases := {}
	for _i in 400:
		var c: Dictionary = sim.q_clock()
		var ph := String(c.phase)
		phases[ph] = true
		if ph == "done":
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
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			"night_choice":
				a = {"t": "night_choice", "where": "casa"}
			"epilogue":
				a = {"t": "publish_errata", "yes": false} if not bool(sim.st.clock.get("errata_decided", false)) else {"t": "leave"}
			_:
				fail("fase inesperada " + ph)
				break
		var r := _act(sim, a)
		if not r.get("ok", false):
			break
	for ph in ["desk", "night", "confront", "final_report", "parklane", "night_choice", "epilogue", "done"]:
		ok(phases.has(ph), "pasó por la fase " + ph)
	var en: Dictionary = sim.q_ending()
	eq(String(en.get("ending", "")), "F4", "un pasivo termina en F4 (ve, pero no observa): %s" % str(en))
	ok(_delivered(sim, "HC03").size() == 1, "HC03 (domingo sin correo) registrada")
	var sunday: Array = sim.st.react.delivered.filter(func(i): return int(i.delivered_tk) == TimeKey.tk(6, "dawn") and String(i.get("voice", "")) == "A" and String(i.get("how", "")) != "")
	ok(not sunday.is_empty() and sunday.all(func(i): return String(i.how) == "en_mano"), "el domingo la voz A llega en mano, sin sello: %s" % str(sunday.map(func(i): return [i.iid, i.how])))
	for rid in ["HC01", "HC02", "HC10", "M6", "HC04", "HC05", "M8"]:
		ok(_delivered(sim, rid).size() == 1, "columna %s entregada" % rid)
	eq(sim.st.flags.get("informes_vacios", 0), 4, "cuatro informes vacíos")
	eq(sim.st.flags.get("noche_final", ""), "casa")
	_save_replay(sim, repo)
	for e in _errs:
		fail(e)

func test_walk_with_real_content():
	var repo = _repo("real")
	if _from_real.is_empty():
		skip("data/ todavía no trae ninguno de %s: el modo real es idéntico al de fixtures" % str(NEEDED))
		return
	var sim = _walk(repo)
	if sim != null:
		_save_replay(sim, repo)
	if not _errs.is_empty():
		pending_content("el recorrido de integración falla con contenido real de %s: %s" % [str(_from_real), str(_errs.slice(0, 6))])
