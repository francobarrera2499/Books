# Integración de la ola 2 (integrador; ARCHITECTURE §12.2): una GameSim REAL (sin dobles) sobre los datos estructurales
# reales de data/ (lists, entities, schedule, conclusions, reactions, places, plates, endings, eggs, ui_text) + el
# contenido mínimo de tests/fixtures/integ/ (docs, dialogue, scenes que data/ todavía no tiene, escritos contra §4.8).
# Recorre prólogo -> amanecer del día 4 con acciones de §3.5 y comprueba que encajan sim ↔ ded ↔ react ↔ scenes ↔ graph:
#   tutorial completo (C1 práctica en tinta), aviso del prólogo impreso en el Times (AD:prologo), HC01, HA1, HB1 (cebo a
#   Watson), HC02 (silueta de Wiggins), HB13 (inactividad), HC10 (columna que cita el aviso), M10; diario con sus
#   etiquetas; líneas de diálogo y siluetas recortables por texto; pasada en limpio todo-o-nada (falla y luego sella C2 y
#   C3); asiento C6 válido con fragmentos runtime (J:go + N:*.sil_wiggins + AD:prologo + R:HC10.texto); convenciones de
#   estado de Cond; contrato RouteDB ↔ recorte real (etiquetas y origen de cada fragmento); D1 sin violaciones;
#   guardado/replay idéntico (GameSim.replay, EventLog, autoload Game).
# Variante «m1»: el informe 1 lleva un original P (M1 en la primera salida, retiro de un día, HB10 lo devuelve).
# Humo: calendario completo de un pasivo hasta el epílogo (F4). Alcanzabilidad: cada campo exigido por el validador tiene
#   un valor indexable (pendiente sobre data/ hasta la ola 4). data/ real sin errores (FAIL: puerta de los redactores).
# Dos modos: «fixture» (estructura de data/ + contenido de integ/: siempre debe pasar) y «real» (data/ pisa a integ/:
#   cuando los redactores de la ola 3 publiquen esos archivos, el mismo recorrido valida SU contenido; si falla por
#   contenido real -> pending_content, que en modo estricto (ola 4) es FAIL).
extends "res://tests/test_base.gd"

const TIMEOUT_S := 120
const DataRepo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")
const EventLog = preload("res://core/save/event_log.gd")
const J = preload("res://core/util/j.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Validator = preload("res://core/deduction/validator.gd")
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
# Modo «fixture»: de data/ sólo se toman los datos estructurales (W1/W2); el contenido de la ola 3 (docs, diálogos,
# escenas, catálogo y sus entidades) sale únicamente de tests/fixtures/integ, para que un archivo de contenido a medio
# hacer no rompa la prueba del motor (ese contenido lo juzgan test_real_data_loads_clean y el modo «real»).
const CONTENT_DIRS := ["docs/", "dialogue/", "scenes/", "catalog/"]
const STRUCT_ENTITIES := ["entities/core.json", "entities/struct.json", "entities/places_a.json", "entities/places_b.json", "entities/places_c.json"]
# Archivos de contenido que el recorrido necesita (rutas relativas a data/).
const NEEDED := ["docs/D23.json", "docs/D01/REDH.json", "docs/D03.json", "docs/D05.json", "docs/D15/0327.json",
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
					var r := _act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(t.from), "len": int(t.to) - int(t.from)})
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
					var r := _act(sim, {"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(t.from), "len": int(t.to) - int(t.from)})
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

func _eset(sim, entry: String, line: int, field: String, value: String) -> void:
	_act(sim, {"t": "entry_set", "entry": entry, "line": line, "field": field, "value": value})

func _support(sim, entry: String, line: int, item: String) -> void:
	_act(sim, {"t": "entry_support_add", "entry": entry, "line": line, "item": item})

func _expect_phase(sim, phase: String, day: int, slot: String, where: String) -> void:
	var c: Dictionary = sim.q_clock()
	_chk(String(c.phase) == phase and int(c.day) == day and String(c.slot) == slot,
		"%s: se esperaba %s %d.%s y hay %s %d.%s" % [where, phase, day, slot, c.phase, int(c.day), c.slot])

# Invariante de rutas (D1) sobre el estado real: ninguna conclusión obligatoria sin sellar queda sin ruta.
func _guard(sim, where: String) -> void:
	var g: Dictionary = Invariant.runtime_guard(sim.st, sim.repo, [])
	_chk(bool(g.get("ok", false)), "%s: runtime_guard viola %s" % [where, str(g.get("violated", []))])

# ---------------- el recorrido ----------------
# Devuelve la GameSim al final (amanecer/escritorio del día 4) o null si se cortó. Deja los problemas en _errs.
# variant: "nada" (informe 1 «sin novedad») · "m1" (el informe 1 lleva un original P: M1 en la primera salida del 3,
#   retira ESE ejemplar un día y registra la buhardilla; HB10 lo devuelve por el mostrador de Crane al amanecer del 4).
func _walk(repo, variant := "nada"):
	_errs = []
	_frags = []
	var errs: Array = repo.errors()
	if not errs.is_empty():
		_e("errores de carga del dataset: %s" % str(errs.slice(0, 8)))
		return null
	var sim = GameSim.new(repo, SEED)
	# --- prólogo (P, noche): tutorial con instructor; un verbo por paso ---
	_expect_phase(sim, "prologue", 0, "N", "inicio")
	var t0: Dictionary = sim.q_tutorial()
	_chk(String(t0.step.get("id", "")) == "clip", "el tutorial empieza por recortar: %s" % str(t0))
	_chk(String(sim.can({"t": "go", "place": "L2", "area": "sala", "seat": 214}).err) == "fase", "en el prólogo no se sale")
	_chk(String(sim.can({"t": "folio_open", "clip": "RC0001"}).err) == "tutorial", "en el prólogo no se adelanta un paso")
	var c_aviso := _clip_tramo(sim, "D23@L1", "aviso")
	_chk(sim.q_index().any(func(x): return String(x.id) == "suceso_reichenbach"), "el recorte del encargo indexa suceso_reichenbach")
	var c_sheer_tomo := _clip_tramo(sim, "D03@tomo", "sheer")
	var c_abril := _clip_tramo(sim, "D01.REDH@tomo", "abril")
	var c_oct := _clip_tramo(sim, "D01.REDH@tomo", "octubre")
	_frag("D01.REDH#abril", "D01.REDH@tomo", c_abril)
	_frag("D01.REDH#octubre", "D01.REDH@tomo", c_oct)
	_chk(_clip_tags(sim, c_abril).has("a:inc10"), "ClipRules.inherit hereda a:inc10 con prefijo: %s" % str(_clip_tags(sim, c_abril)))
	_chk(not sim.q_clip(c_abril).has("tags"), "q_clip no muestra etiquetas ocultas")
	var pr := String(_act(sim, {"t": "link", "a": c_abril, "b": c_oct, "note": "dos fechas"}).get("pair", ""))
	var fo := String(_act(sim, {"t": "folio_open", "clip": c_abril}).get("folio", ""))
	var as_p := String(_act(sim, {"t": "entry_new", "folio": fo, "template": "T1"}).get("entry", ""))
	_eset(sim, as_p, 0, "fuente_a", "redh")
	_eset(sim, as_p, 0, "dice_a", "abril_27_1890")
	_eset(sim, as_p, 1, "fuente_b", "redh")
	_eset(sim, as_p, 1, "dice_b", "octubre_9_1890")
	_support(sim, as_p, 0, c_abril)
	_support(sim, as_p, 1, c_oct)
	_chk((sim.q_entry(as_p).formal as Array).is_empty(), "práctica sin errores formales: %s" % str(sim.q_entry(as_p).formal))
	var rp := _act(sim, {"t": "practice", "entry": as_p})
	_chk(bool(rp.get("inked", false)), "la práctica C1.10 entinta (inc10): %s" % str(rp))
	_chk(String(sim.st.ded.entries.get(as_p, {}).get("cid", "")) == "C1.10", "práctica = C1.10")
	_chk(sim.st.ded.sealed.is_empty(), "la práctica no sella nada")
	var ra := _act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_chk(String(ra.get("ad", "")) == "AD:prologo" and int(ra.get("pub_day", -1)) == 1, "aviso del prólogo -> AD:prologo, sale el día 1: %s" % str(ra))
	_chk(bool(sim.q_tutorial().complete), "tutorial completo antes de dormir")
	var taught: Array = sim.q_tutorial().taught
	for v in ["clip_text", "link", "folio_open", "entry_set", "practice", "pass_clean", "compose_ad"]:
		_chk(taught.has(v), "verbo enseñado en el prólogo: " + v)
	var pro_lines: Array = _diary_by(sim, func(e): return String(e.kind) == "line" and String(e.origin) == "S.PRO")
	_chk(pro_lines.size() >= 7, "las líneas del prólogo (escena e instructor) van al diario con origen S.PRO: %d" % pro_lines.size())
	_act(sim, {"t": "sleep"})
	# --- día 1, amanecer: bandeja, aviso impreso, HC01 ---
	_expect_phase(sim, "desk", 1, "M", "día 1")
	var tray1 := _tray_views(sim, 1)
	_chk(tray1.has("D15.0327@L1"), "el Times del martes llega a la bandeja: %s" % str(tray1))
	var hc01 := _delivered(sim, "HC01")
	_chk(hc01.size() == 1 and int(hc01[0].delivered_tk) == TimeKey.tk(1, "dawn"), "HC01 entregada al amanecer del día 1")
	if hc01.size() == 1:
		_chk(tray1.has(String(hc01[0].view)), "el sobre de HC01 está en la bandeja (%s)" % str(hc01[0].get("view", "")))
	var ad_ev := {}
	for ev in sim.st.events:
		if String(ev.type) == "ad":
			ad_ev = ev
	_chk(String(ad_ev.get("ad", "")) == "AD:prologo" and int(ad_ev.get("tk", -1)) == TimeKey.tk(1, "dawn"), "evento ad del prólogo al amanecer del día 1: %s" % str(ad_ev))
	var ins: Array = sim.st.world.inserts.get("D15.0327", {}).get("p2", [])
	_chk(ins.size() == 1, "el aviso quedó impreso en la columna (p2) del Times del día 1: %s" % str(sim.st.world.inserts))
	_chk(_diary_by(sim, func(e): return String(e.get("type", "")) == "ad").size() == 1, "el diario anota «sale mi aviso»")
	# --- día 1 M: Kensington, cebo a Watson (K-W) ---
	_act(sim, {"t": "go", "place": "L4", "area": "consulta"})
	_chk(sim.q_scene().chars.any(func(c): return String(c.id) == "watson"), "Watson está en la consulta por la mañana")
	_chk(sim.q_assertions().any(func(x): return String(x.id) == "as.pared"), "as.pared afirmable (reichenbach y pared en el índice)")
	_chk(_cond(sim, {"char_present": "watson"}) and not _cond(sim, {"char_present": "mrs_hudson"}), "Cond char_present lee st.world.visit.chars")
	var preview: String = sim.q_preview({"t": "assert", "char": "watson", "assertion": "as.pared"})
	_chk(preview.begins_with("La pared era a pique"), "frase exacta de Lisle antes de afirmar: " + preview)
	var rs := _act(sim, {"t": "assert", "char": "watson", "assertion": "as.pared"})
	_chk(String(rs.get("line", {}).get("text", "")).contains("sendero estrecho") if typeof(rs.get("line")) == TYPE_DICTIONARY else false, "Watson contesta con la línea de afirmación: %s" % str(rs.get("line")))
	var hb1q := _queued(sim, "HB1")
	_chk(hb1q.size() == 1 and int(hb1q[0].due_tk) == TimeKey.tk(4, "dawn") and String(hb1q[0].channel) == "K-W",
		"HB1 (Ley 2, cebo 1, K-W) en cola para la voz B del día 1 -> 4.dawn: %s" % str(hb1q))
	_chk(_diary_by(sim, func(e): return String(e.get("key", "")) == "say.watson").size() == 1, "diario: «le dije al doctor»")
	_chk(sim.q_diary().any(func(e): return String(e.kind) == "line" and String(e.who) == "watson"), "la respuesta de Watson queda en el diario")
	# las líneas dichas por Dialogue (st.scenes.lines) se recortan como las de escena (src kind "line")
	var wl: Array = sim.q_scene().lines.filter(func(l): return String(l.who) == "watson")
	if wl.size() == 1:
		var pw: Dictionary = wl[0].parsed
		var s1: Array = pw.sentences[1] if (pw.sentences as Array).size() > 1 else pw.sentences[0]
		var c_w := String(_act(sim, {"t": "clip_text", "src": {"kind": "line", "ref": String(wl[0].uid)}, "from": int(s1[0]), "len": int(s1[1]) - int(s1[0])}).get("clip", ""))
		var cw: Dictionary = Clipper.get_clip(sim.st, c_w)
		_chk(String(cw.get("origin", "")) == "S.L4.1.M" and (cw.get("ents", []) as Array).has("watson"), "recorte de lo dicho por Watson: origen = visita, entidad watson: %s" % str([cw.get("origin", ""), cw.get("ents", [])]))
	else:
		_e("la visita debería tener una línea de Watson: %s" % str(sim.q_scene().lines))
	var ra2 := _act(sim, {"t": "ask", "char": "watson", "topic": "fina"})
	var l2 = ra2.get("line", {})
	_chk(typeof(l2) == TYPE_DICTIONARY and String(l2.get("id", "")) == "escribi_mycroft", "capa tema con when (event_count roca): escribi_mycroft: %s" % str(l2))
	if typeof(l2) == TYPE_DICTIONARY and String(l2.get("uid", "")) != "":
		var pl2: Dictionary = sim.q_line(String(l2.uid)).get("parsed", {})
		for t in pl2.get("tramos", []):
			if String(t.id) == "escribi":
				_frag("L:watson.escribi_mycroft", "", String(_act(sim, {"t": "clip_text", "src": {"kind": "line", "ref": String(l2.uid)}, "from": int(t.from), "len": int(t.to) - int(t.from)}).get("clip", "")))
	_chk(int(sim.st.react.counters.get("hb5=", 0)) == 1 and _queued(sim, "HB5").is_empty(), "HB5 cuenta la 1.ª insistencia (fina) y espera la 2.ª")
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
	# --- asientos C2 y C3 (y uno flojo para probar el todo o nada) ---
	var fo2 := String(_act(sim, {"t": "folio_open", "clip": c_sheer}).get("folio", ""))
	var as2 := String(_act(sim, {"t": "entry_new", "folio": fo2, "template": "T2"}).get("entry", ""))
	_eset(sim, as2, 0, "fuente", "fina")
	_eset(sim, as2, 0, "calla", "raspadura")
	_eset(sim, as2, 1, "consta_en", "journal_de_geneve")
	_support(sim, as2, 0, c_sheer)
	_support(sim, as2, 1, c_marque)
	var as3 := String(_act(sim, {"t": "entry_new", "folio": fo2, "template": "T1"}).get("entry", ""))
	_eset(sim, as3, 0, "fuente_a", "fina")
	_eset(sim, as3, 0, "dice_a", "a_pique")
	_eset(sim, as3, 1, "fuente_b", "journal_de_geneve")
	_eset(sim, as3, 1, "dice_b", "cornisa")
	_support(sim, as3, 0, c_sheer)
	_support(sim, as3, 1, c_corniche)
	for id in [as2, as3]:
		_chk((sim.q_entry(id).formal as Array).is_empty(), "%s sin errores formales: %s" % [id, str(sim.q_entry(id).formal)])
	var ok2: Dictionary = Validator.entry_ok(sim.st, sim.repo, as2)
	var ok3: Dictionary = Validator.entry_ok(sim.st, sim.repo, as3)
	_chk(bool(ok2.ok) and String(ok2.cid) == "C2", "C2 válido: %s" % str(ok2))
	_chk(bool(ok3.ok) and String(ok3.cid) == "C3", "C3 válido: %s" % str(ok3))
	# asiento flojo: valores de C3, formalmente correcto (dos orígenes) pero sin a_pique ni cornisa en su «según»
	var as_bad := String(_act(sim, {"t": "entry_new", "folio": "varios", "template": "T1"}).get("entry", ""))
	_eset(sim, as_bad, 0, "fuente_a", "fina")
	_eset(sim, as_bad, 0, "dice_a", "a_pique")
	_eset(sim, as_bad, 1, "fuente_b", "journal_de_geneve")
	_eset(sim, as_bad, 1, "dice_b", "cornisa")
	_support(sim, as_bad, 0, c_marque)
	_support(sim, as_bad, 1, c_sheer_tomo)
	_chk((sim.q_entry(as_bad).formal as Array).is_empty(), "el asiento flojo pasa el chequeo formal")
	var bad: Dictionary = Validator.entry_ok(sim.st, sim.repo, as_bad)
	_chk(not bool(bad.ok) and String(bad.cid) == "C3", "el asiento flojo es C3 por valores pero no se sostiene: %s" % str(bad))
	_chk(String(sim.can({"t": "pass_clean", "entries": [as2]}).err) == "lote", "lote de 2 (calendario)")
	var p1 := _act(sim, {"t": "pass_clean", "entries": [as2, as_bad]})
	_chk(p1.get("ok", false) and not bool(p1.get("inked", true)), "pasada todo o nada: falla con un asiento flojo: %s" % str(p1))
	_chk(sim.st.ded.sealed.is_empty() and String(sim.st.ded.entries[as2].ink) == "lapiz", "nada se selló; C2 sigue a lápiz")
	_chk(int(sim.q_clock().passes_left) == 0, "la pasada fallida se gastó")
	_chk(String(sim.can({"t": "pass_clean", "entries": [as2, as3]}).err) == "sin_pasada", "sin pasada hasta la franja siguiente")
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_expect_phase(sim, "night", 1, "night", "noche 1")
	_chk(_queued(sim, "HB13").is_empty() and _delivered(sim, "HB13").is_empty(), "día 1 con actos observados: sin HB13")
	_act(sim, {"t": "sleep"})
	# --- día 2: HA1 entregada; HA0 no (hubo papeleta); pasada buena; inactividad ---
	_expect_phase(sim, "desk", 2, "M", "día 2")
	var ha1 := _delivered(sim, "HA1")
	_chk(ha1.size() == 1 and String(ha1[0].tpl) == "holmes_prensa_1891" and String(ha1[0].how) == "correo",
		"HA1 al amanecer del 2, plantilla por tema y por correo: %s" % str(ha1.map(func(i): return [i.tpl, i.get("how", "")])))
	_chk(_delivered(sim, "HA0").is_empty() and _queued(sim, "HA0").is_empty(), "HA0 no (hubo papeleta de tema holmes el día 1)")
	if ha1.size() == 1:
		var v_ha1 := String(ha1[0].view)
		_chk(_tray_views(sim, 2).has(v_ha1), "la carta de HA1 en la bandeja del día 2")
		var c_giro := _clip_tagged(sim, v_ha1, "e:giro_ahorrare")
		_frag("R:HA1.giro", "", c_giro)
		_chk(_clip_tags(sim, c_giro).has("a:me_vigila_de_cerca"), "el giro de la voz A lleva me_vigila_de_cerca (C7)")
		var c_ancla := _clip_tagged(sim, v_ha1, "a:ancla_kbm")
		_frag("R:HA1.*", "", c_ancla)
		var ents: Array = Clipper.get_clip(sim.st, c_ancla).get("ents", [])
		_chk(ents.any(func(e): return String(e).begins_with("act.")), "el ancla de HA1 cita el acto (entidad act_ref): %s" % str(ents))
	var p2 := _act(sim, {"t": "pass_clean", "entries": [as2, as3]})
	_chk(bool(p2.get("inked", false)) and p2.get("sealed", []) == ["C2", "C3"], "pasada buena: C2 y C3 sellados: %s" % str(p2))
	_chk(sim.st.ded.sealed.get("C2", "") == as2 and sim.st.ded.sealed.get("C3", "") == as3, "st.ded.sealed cid -> asiento")
	_chk(String(sim.q_entry(as2).ink) == "tinta", "C2 en tinta")
	_chk(String(sim.can({"t": "entry_set", "entry": as2, "line": 0, "field": "calla", "value": ""}).err) == "en_tinta", "la tinta no se edita")
	_guard(sim, "tras sellar C2/C3")
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
		var m1q := _queued(sim, "M1")
		_chk(m1q.size() == 1 and String(m1q[0].get("mode", "")) == "salida" and RDB._as_arr(m1q[0].anchor.get("copies", [])) == ["D03@tomo"],
			"M1 espera la primera salida del día 3 y se llevará ESE original (D03@tomo): %s" % str(m1q.map(func(i): return [i.get("mode", ""), i.anchor.get("copies", [])])))
		_chk(int(sim.st.flags.get("informes_vacios", 0)) == 0, "un informe con elementos no es vacío")
	else:
		_act(sim, {"t": "report_submit", "mode": "nada", "items": []})
		_chk(int(sim.st.flags.get("informes_vacios", 0)) == 1, "Moran anota el informe vacío (informes_vacios)")
	_chk(_diary_by(sim, func(e): return String(e.get("type", "")) == "report").size() == 1, "diario: entregué el informe 1")
	_act(sim, {"t": "sleep"})
	# --- día 3: HC02 (Wiggins), HB13 entregada; Baker Street (K-S) ---
	_expect_phase(sim, "desk", 3, "M", "día 3")
	_chk(_delivered(sim, "HC02").size() == 1, "HC02 al amanecer del 3")
	var hb13 := _delivered(sim, "HB13")
	_chk(hb13.size() == 1 and _tray_views(sim, 3).has(String(hb13[0].get("view", ""))), "HB13 entregada en la bandeja del 3: %s" % str(hb13))
	if hb13.size() == 1:
		var t13 := String(hb13[0].get("text", ""))
		_chk(not t13.contains("{{") or t13.contains("a:me_vigila_de_cerca"), "HB13 sólo con la etiqueta de C7 (T16)")
	var rg := _act(sim, {"t": "go", "place": "L3", "area": "calle"})
	var plate := String(rg.get("plate", ""))
	_chk(plate == "PL.L3.3.M", "lámina de la visita: " + plate)
	var snap: Dictionary = sim.q_visit_plate()
	_chk((snap.get("silhouettes", []) as Array).has("sil_wiggins"), "la silueta de Wiggins está en la lámina desde el día 3: %s" % str(snap.get("silhouettes", [])))
	_chk(_queued(sim, "HA3").size() == 1, "HA3 (primer go desde el día 3, K-S) en cola")
	_chk(RDB._as_arr(sim.st.react.moran.get("next_lines", [])).size() == 1, "M10: Parker ve a Lisle en Baker Street; línea para la próxima comunicación")
	var rc := _act(sim, {"t": "clip_plate", "plate": plate, "hits": [{"node": "sil_wiggins", "cover": 0.9, "tight": true}], "touched": ["sil_wiggins"], "area_frac": 0.05})
	var c_sil := String(rc.get("clip", ""))
	_frag("N:*.sil_wiggins", "", c_sil)
	_chk(_clip_tags(sim, c_sil).has("a:ancla_ks"), "N:*.sil_wiggins -> a:ancla_ks: %s" % str(_clip_tags(sim, c_sil)))
	# accesibilidad (§3.5 src kind "node"): la silueta también se recorta por su texto de examen, con la misma etiqueta y acto
	var sil_txt := String(sim.repo.text("sim.sil.wiggins"))
	var rn := _act(sim, {"t": "clip_text", "src": {"kind": "node", "ref": plate + "/sil_wiggins"}, "from": 0, "len": Markup.parse(sil_txt, sim.repo.markup_ctx()).plain.length()})
	var cn: Dictionary = Clipper.get_clip(sim.st, String(rn.get("clip", "")))
	_chk((cn.get("tags", []) as Array).has("a:ancla_ks") and (cn.get("ents", []) as Array).any(func(e): return String(e).begins_with("act.")),
		"recorte de texto de la silueta: a:ancla_ks y el acto de la visita: %s" % str([cn.get("tags", []), cn.get("ents", [])]))
	var go_lines := _diary_by(sim, func(e): return String(e.get("type", "")) == "go" and int(e.day) == 3)
	_chk(go_lines.size() == 1 and String(go_lines[0].key) == "go.L3.calle", "diario: J:go de Baker Street (calle): %s" % str(go_lines))
	var c_jgo := ""
	if go_lines.size() == 1:
		var plain := String(go_lines[0].parsed.plain)
		c_jgo = String(_act(sim, {"t": "clip_text", "src": {"kind": "diary", "ref": String(go_lines[0].id)}, "from": 0, "len": plain.length()}).get("clip", ""))
		_chk(_clip_tags(sim, c_jgo).has("a:acto_ks"), "J:go -> a:acto_ks")
		_frag("J:go", "", c_jgo)
		var act_go := String(go_lines[0].act)
		_chk(Clipper.get_clip(sim.st, c_jgo).ents.has(act_go) and Clipper.get_clip(sim.st, c_sil).ents.has(act_go),
			"diario y silueta citan el mismo acto %s" % act_go)
	_act(sim, {"t": "leave"})
	if variant == "m1":
		var m1 := _delivered(sim, "M1")
		_chk(m1.size() == 1 and int(m1[0].delivered_tk) == TimeKey.tk(3, "M") and not bool(m1[0].get("soft", true)),
			"M1 se resuelve en la primera salida del 3, sin variante blanda (C2/C3 sellados): %s" % str(m1.map(func(i): return [i.delivered_tk, i.get("soft", "")])))
		_chk(not sim.q_accessible().any(func(x): return String(x.view) == "D03@tomo"), "D03@tomo falta en la buhardilla el día 3")
		_chk(sim.q_accessible().any(func(x): return String(x.view) == "D01.REDH@tomo"), "los demás tomos siguen ahí")
		_chk((sim.q_hub_plate().nodes as Array).has("ceniza_registro"), "la buhardilla registrada muestra la ceniza (N:L1.ceniza_registro)")
		_chk(String(sim.q_hub_plate().variant) == "registrada", "variante «registrada» de L1")
		_chk(_queued(sim, "HB10").size() == 1, "HB10 (Ley 3: lo robado vuelve) en cola tras M1")
		_chk(bool(sim.st.react.strong_days.get("3", false)), "M1 es la disparada fuerte del día 3 (D2)")
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_act(sim, {"t": "end_slot"})
	_expect_phase(sim, "night", 3, "night", "noche 3")
	_act(sim, {"t": "sleep"})
	# --- día 4, amanecer: HC10 (columna que cita AD:prologo), HB1 (carta «—S.»), HA3 ---
	_expect_phase(sim, "desk", 4, "M", "día 4")
	var hc10 := _delivered(sim, "HC10")
	_chk(hc10.size() == 1 and String(hc10[0].get("how", "")) == "columna", "HC10 en la columna del 30: %s" % str(hc10))
	_chk((sim.st.world.inserts.get("D15.0330", {}).get("p2", []) as Array).size() == 1, "HC10 insertada en D15.0330 (p2)")
	var hb1 := _delivered(sim, "HB1")
	_chk(hb1.size() == 1 and String(hb1[0].tpl) == "pared.1.kw" and String(hb1[0].get("how", "")) == "correo",
		"HB1 al amanecer del 4: carta «—S.» por K-W (Ley 5): %s" % str(hb1.map(func(i): return [i.tpl, i.get("how", "")])))
	_chk(_delivered(sim, "HA3").size() == 1, "HA3 entregada")
	if variant == "m1":
		var hb10 := _delivered(sim, "HB10")
		_chk(hb10.size() == 1 and String(hb10[0].get("how", "")) == "mostrador_crane" and RDB._as_arr(hb10[0].get("returned", [])) == ["D03@tomo"],
			"HB10 devuelve D03@tomo con tarjeta en el mostrador de Crane: %s" % str(hb10.map(func(i): return [i.get("how", ""), i.get("returned", [])])))
		_chk(sim.q_accessible().any(func(x): return String(x.view) == "D03@tomo"), "D03@tomo vuelve el día 4")
	# --- asiento C6 con fragmentos runtime: K-S (J:go + silueta) y K-T (AD:prologo + R:HC10.texto) ---
	var c_ad := _clip_tagged(sim, "D15.0327@L1", "a:acto_kt")
	var c_hc10 := _clip_tagged(sim, "D15.0330@L1", "a:ancla_kt")
	_frag("AD:prologo", "D15.0327@L1", c_ad)
	_frag("R:HC10.texto", "D15.0330@L1", c_hc10)
	var act_ad := String(ad_ev.get("act", ""))
	_chk(Clipper.get_clip(sim.st, c_ad).ents.has(act_ad) and Clipper.get_clip(sim.st, c_hc10).ents.has(act_ad),
		"el aviso impreso y la columna de HC10 citan el mismo acto %s" % act_ad)
	var fo6 := String(_act(sim, {"t": "folio_open", "clip": c_hc10}).get("folio", ""))
	var as6 := String(_act(sim, {"t": "entry_new", "folio": fo6, "template": "T6"}).get("entry", ""))
	_eset(sim, as6, 0, "persona", "mycroft")
	_eset(sim, as6, 0, "relacion", "lee_a")
	_eset(sim, as6, 0, "a_quien", "lisle")
	_eset(sim, as6, 0, "por_medio", "la_calle")
	_eset(sim, as6, 1, "y_de", "columna")
	_support(sim, as6, 0, c_jgo)
	_support(sim, as6, 0, c_sil)
	_support(sim, as6, 1, c_ad)
	_support(sim, as6, 1, c_hc10)
	_chk((sim.q_entry(as6).formal as Array).is_empty(), "C6 sin errores formales: %s" % str(sim.q_entry(as6).formal))
	var ok6: Dictionary = Validator.entry_ok(sim.st, sim.repo, as6)
	_chk(bool(ok6.ok) and String(ok6.cid) == "C6", "C6 válido con J:go + sil_wiggins + AD:prologo + R:HC10.texto: %s" % str(ok6))
	_guard(sim, "día 4")
	# página «Erratas inocentes»: un asiento ahí es de práctica y q_ledger lo lista aparte
	var as_e := String(_act(sim, {"t": "entry_new", "folio": "erratas", "template": "T1"}).get("entry", ""))
	_chk((sim.q_ledger().get("erratas", []) as Array).has(as_e) and bool(sim.st.ded.entries.get(as_e, {}).get("practice", false)), "q_ledger.erratas lista la práctica: %s" % str(sim.q_ledger().get("erratas", null)))
	_act(sim, {"t": "entry_delete", "entry": as_e})
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
	_chk(_cond(sim, {"sealed_all": ["C2", "C3"]}) and _cond(sim, {"sealed_count": {"of": "mandatory", "eq": 2}}), "Cond sealed* sobre st.ded.sealed")
	_chk(_cond(sim, {"counter": {"name": "fired.HB1", "eq": 1}}) and _cond(sim, {"counter": {"name": "delivered.HA1", "eq": 1}}), "Cond counter sobre st.react.counters (fired./delivered.)")
	_chk(_cond(sim, {"counter": {"name": "cebo=pared", "eq": 1}}), "contador de la Ley 2 «cebo=pared»: %s" % str(sim.st.react.counters))
	_chk(_cond(sim, {"event_count": {"type": "say", "where": {"char": "watson", "topic_group": "roca"}, "gte": 1}}), "Cond event_count sobre st.events (say a Watson, grupo roca)")
	_chk(_cond(sim, {"event_count": {"type": "slip", "where": {"day": 1, "topic": ["holmes_prensa_1891"]}, "gte": 1}}), "event_count con lista (HA0)")
	_chk(_cond(sim, {"all": [{"day": 4}, {"slot": ["M"]}, {"weekday": "vie"}, {"tk": {"gte": "4.dawn"}}]}), "día/franja/weekday/tk del reloj")
	if variant == "nada":
		_chk(_cond(sim, {"flag_gte": {"informes_vacios": 1}}), "flag_gte sobre st.flags (MoranAgent)")
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

# [cid.campo: valores] de campos que el validador exige y ningún contenido permite indexar.
static func unreachable_answers(repo, only := []) -> Array:
	var idx := indexable(repo)
	var out: Array = []
	for c in repo.conclusions():
		var cid := String(c.id)
		if not only.is_empty() and not only.has(cid):
			continue
		var tpl: Dictionary = repo.template(String(c.get("template", "")))
		var accepts := {}
		for ln in tpl.get("lines", []):
			for f in ln.get("fields", []):
				accepts[String(f.id)] = f.get("accept", {})
		var ans: Dictionary = c.get("answers", {})
		for f in ans:
			if String(f).begins_with("_") or typeof(ans[f]) != TYPE_ARRAY:
				continue
			if typeof(accepts.get(f)) == TYPE_DICTIONARY and accepts[f].has("list"):
				continue   # lista cerrada: se elige del menú, no del índice
			var hit := false
			for v in ans[f]:
				var vs := String(v)
				if vs.begins_with("@alias:"):
					vs = vs.substr(7)
				if idx.has(vs):
					hit = true
			if not hit:
				out.append("%s.%s: %s" % [cid, f, str(ans[f])])
	return out

# ---------------- tests ----------------
# Toda conclusión debe poder escribirse (GDD: ninguna conclusión sin pista alcanzable): cada campo que el validador exige
# tiene ≥1 valor aceptado que algún contenido indexa. En fixtures: C1.10, C2, C3 y C6 (lo que el recorrido usa) siempre;
# sobre data/ real: pendiente hasta que la ola 3 escriba el contenido (estricto en la ola 4).
func test_answers_indexable():
	eq(unreachable_answers(_repo("fixture"), ["C1.10", "C2", "C3", "C6"]), [], "fixtures de integración")
	var real := unreachable_answers(load("res://core/data/data_repo.gd").load_dir("res://data"))
	if not real.is_empty():
		pending_content("%d campos de conclusiones sin valor indexable en data/ (p. ej. %s)" % [real.size(), str(real.slice(0, 6))])

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
