# Driver de verificación de W3-CT-CORPUS-A (headless, sin capturas). Desde la raíz:
#   ./godot.sh --headless -s devtools/drivers/w3ctcorpusa_check.gd [-- --text]
# Sobre data/ real, sólo los archivos del paquete (docs D01.{SCAN,REDH,IDEN,BOSC,FIVE,TWIS,BLUE,SPEC,ENGR,NOBL,BERY,COPP} y
# entities/corpus_a.json): errores de DataRepo, palabras reales contra `words`, src_en contra tests/fixtures/canon (misma
# normalización que T7), q: <-> src_en, chron_date presente, tramos del contrato §4.8 con sus grupos.
# Dinámico (GameSim real): dataset = estructura real + fixtures de integración + ESTOS documentos y entidades (aísla
# el paquete de errores ajenos de data/): (1) el recorrido de test_i_integration con el REDH real (tutorial y práctica
# C1.10 desde el tomo); (2) en el mismo prólogo, prácticas C1.03 (SPEC#hudson + SCAN#turner) y C1.08 (FIVE#una_mujer +
# SCAN#marzo_1888) desde los tomos (rutas R2, P.N) -> deben entintar con su cid; (3) sobre data/ real, C1.02, C1.06 y
# C1.07 con los otros lados en D43/D44 (BM y Crane, día 1; usa devtools/bots/play_session.gd para llegar a 1.M).
# --text imprime además el texto plano de cada parte (revisión de lectura). Sale con 1 si hay hallazgos.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

const CODES := ["SCAN", "REDH", "IDEN", "BOSC", "FIVE", "TWIS", "BLUE", "SPEC", "ENGR", "NOBL", "BERY", "COPP"]
const CONTRACT := {"D01.SCAN": {"turner": "inc03", "boda": "inc06", "marzo_1888": "inc08"}, "D01.REDH": {"abril": "inc10", "octubre": "inc10"},
	"D01.SPEC": {"hudson": "inc03"}, "D01.TWIS": {"james": "inc02"}, "D01.FIVE": {"madre": "inc07", "una_mujer": "inc08"}}

const DataRepo = preload("res://core/data/data_repo.gd")
const SEED := 1894

# El script del test se carga en tiempo de ejecución (usa el autoload Game, que no existe al parsear este driver).
var t = null

func _dataset() -> String:
	var root: String = t._build("fixture")
	var real := ProjectSettings.globalize_path("res://data")
	for c in CODES:
		var rel := "docs/D01/%s.json" % c
		DirAccess.make_dir_recursive_absolute(root.path_join(rel).get_base_dir())
		DirAccess.copy_absolute(real.path_join(rel), root.path_join(rel))
	DirAccess.copy_absolute(real.path_join("entities/corpus_a.json"), root.path_join("entities/corpus_a.json"))
	return root

func _practice_pair(sim, cid: String, va: String, ta: String, vb: String, tb: String, fa: String, da: String, fb: String, db: String) -> void:
	var a: String = t._clip_tramo(sim, va, ta)
	var b: String = t._clip_tramo(sim, vb, tb)
	var fo := String(t._act(sim, {"t": "folio_open", "clip": a}).get("folio", ""))
	var en := String(t._act(sim, {"t": "entry_new", "folio": fo, "template": "T1"}).get("entry", ""))
	t._eset(sim, en, 0, "fuente_a", fa)
	t._eset(sim, en, 0, "dice_a", da)
	t._eset(sim, en, 1, "fuente_b", fb)
	t._eset(sim, en, 1, "dice_b", db)
	t._support(sim, en, 0, a)
	t._support(sim, en, 1, b)
	var f: Array = sim.q_entry(en).get("formal", [])
	t._chk(f.is_empty(), "%s: errores formales %s" % [cid, str(f)])
	var r: Dictionary = t._act(sim, {"t": "practice", "entry": en})
	t._chk(bool(r.get("inked", false)), "%s no entinta: %s" % [cid, str(r)])
	var got := String(sim.st.ded.entries.get(en, {}).get("cid", ""))
	t._chk(got == cid, "%s: cid %s" % [cid, got])
	print("práctica %s: inked=%s cid=%s" % [cid, str(r.get("inked", false)), got])

func _dynamic() -> Array:
	t = load("res://tests/test_i_integration.gd").new()
	t.tree = self
	t._cur = "w3ctcorpusa_check::walk"
	var root := _dataset()
	DataRepo.clear_cache(root)
	var repo = DataRepo.fresh(root)
	var out: Array = []
	for e in repo.errors():
		out.append("dataset: " + str(e))
	if not out.is_empty():
		return out
	t._walk(repo)
	print("recorrido de integración con el REDH real: %d errores" % t._errs.size())
	for e in t._errs:
		out.append("recorrido: " + str(e))
	t._errs = []
	var sim = GameSim.new(repo, SEED)
	t._clip_tramo(sim, "D23@L1", "aviso")
	var c1: String = t._clip_tramo(sim, "D01.REDH@tomo", "abril")
	var c2: String = t._clip_tramo(sim, "D01.REDH@tomo", "octubre")
	t._act(sim, {"t": "link", "a": c1, "b": c2, "note": "dos fechas"})
	_practice_pair(sim, "C1.10", "D01.REDH@tomo", "abril", "D01.REDH@tomo", "octubre", "redh", "abril_27_1890", "redh", "octubre_9_1890")
	t._act(sim, {"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}})
	_practice_pair(sim, "C1.03", "D01.SPEC@tomo", "hudson", "D01.SCAN@tomo", "turner", "spec", "mrs_hudson", "scan", "mrs_turner")
	_practice_pair(sim, "C1.08", "D01.FIVE@tomo", "una_mujer", "D01.SCAN@tomo", "marzo_1888", "five", "ano_87", "scan", "marzo_1888")
	for e in t._errs:
		out.append("prácticas: " + str(e))
	t._errs = []
	out.append_array(_real_pairs())
	return out

# (3) Sobre data/ REAL (si carga limpio y existen D43/D44): el bot pasivo llega a 1.M y se practican en la página
# «erratas» los pares cuyo otro lado es de corpus B: C1.02 (D43#john_h + TWIS#james, BM), C1.06 (SCAN#boda del tomo +
# D44#conoce_mary de Crane), C1.07 (FIVE#madre del BM + D44#madre_muerta de Crane). Deben entintar con su cid.
func _real_pairs() -> Array:
	var out: Array = []
	var repo = DataRepo.fresh("res://data")
	if not repo.errors().is_empty() or repo.doc("D43").is_empty() or repo.doc("D44").is_empty():
		print("pares C1 con D43/D44 sobre data/ real: omitido (data/ con errores o sin D43/D44)")
		return out
	var ps = load("res://devtools/bots/play_session.gd").new(repo, SEED)
	ps.echo = false
	ps.exec("bot pasivo hasta 1.M")
	var sim = ps.sim
	t._act(sim, {"t": "go", "place": "L2", "area": "sala", "seat": 214})
	for d in ["D01.TWIS", "D43", "D01.FIVE"]:
		t._act(sim, {"t": "slip", "doc": d})
	var james: String = t._clip_tramo(sim, "D01.TWIS@BM", "james")
	var john_h: String = t._clip_tramo(sim, "D43@BM", "john_h")
	var madre: String = t._clip_tramo(sim, "D01.FIVE@BM", "madre")
	t._act(sim, {"t": "leave"})
	t._act(sim, {"t": "end_slot"})
	t._act(sim, {"t": "go", "place": "L1", "area": "tienda"})
	var conoce: String = t._clip_tramo(sim, "D44@Crane", "conoce_mary")
	var muerta: String = t._clip_tramo(sim, "D44@Crane", "madre_muerta")
	t._act(sim, {"t": "leave"})
	var boda: String = t._clip_tramo(sim, "D01.SCAN@tomo", "boda")
	_practice_erratas(sim, "C1.02", john_h, james, "stud", "john_h", "twis", "james")
	_practice_erratas(sim, "C1.06", boda, conoce, "scan", "boda_de_watson", "sign", "mary_watson")
	_practice_erratas(sim, "C1.07", madre, muerta, "five", "madre_de_mary", "sign", "mary_watson")
	for e in t._errs:
		out.append("pares C1 (data/ real): " + str(e))
	return out

func _practice_erratas(sim, cid: String, a: String, b: String, fa: String, da: String, fb: String, db: String) -> void:
	var en := String(t._act(sim, {"t": "entry_new", "folio": "erratas", "template": "T1"}).get("entry", ""))
	t._eset(sim, en, 0, "fuente_a", fa)
	t._eset(sim, en, 0, "dice_a", da)
	t._eset(sim, en, 1, "fuente_b", fb)
	t._eset(sim, en, 1, "dice_b", db)
	t._support(sim, en, 0, a)
	t._support(sim, en, 1, b)
	var r: Dictionary = t._act(sim, {"t": "practice", "entry": en})
	var got := String(sim.st.ded.entries.get(en, {}).get("cid", ""))
	t._chk(bool(r.get("inked", false)) and got == cid, "%s (data/ real) no entinta: %s cid=%s" % [cid, str(r), got])
	print("práctica %s (data/ real): inked=%s cid=%s" % [cid, str(r.get("inked", false)), got])

static func _norm(s: String) -> String:
	var t := s.replace("’", "'").replace("‘", "'").replace("“", "\"").replace("”", "\"").replace("—", "-").replace("–", "-")
	t = t.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.strip_edges()

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var text := OS.get_cmdline_user_args().has("--text")
	var bad: Array = []
	var repo = Repo.fresh("res://data")
	for e in repo.errors():
		var s := String(e)
		if s.contains("corpus_a") or CODES.any(func(c): return s.contains("D01/%s." % c) or s.contains("D01.%s" % c)):
			bad.append("DataRepo: " + s)
	var canon := ""
	for c in CODES:
		canon += " " + _norm(FileAccess.get_file_as_string("res://tests/fixtures/canon/%s.txt" % c.to_lower()))
	var tot := 0
	for c in CODES:
		var id: String = "D01." + String(c)
		var d: Dictionary = repo.doc(id)
		if d.is_empty():
			bad.append("%s: no existe" % id)
			continue
		if String(d.get("chron_date", "")) == "":
			bad.append("%s: sin chron_date" % id)
		var words := 0
		var qs := {}
		var tramos := {}
		for p in d.parts:
			var pd: Dictionary = repo.parsed(id, String(p.id))
			words += (pd.get("words", []) as Array).size()
			for t in pd.get("tramos", []):
				tramos[String(t.id)] = t.tags
				for q in t.tags.get("q", []):
					qs[String(q)] = true
			if text:
				print("---- %s %s\n%s" % [id, p.id, pd.get("plain", "")])
		tot += words
		var dec := int(d.get("words", 0))
		var dev: float = 100.0 * float(words - dec) / float(maxi(dec, 1))
		print("%-9s palabras %4d / %d (%+.1f %%), tramos %d" % [id, words, dec, dev, tramos.size()])
		if absf(dev) > 15.0:
			bad.append("%s: %d palabras, fuera de ±15 %% de %d" % [id, words, dec])
		var se: Dictionary = d.get("src_en", {})
		for q in qs:
			if not se.has(q):
				bad.append("%s: q:%s sin src_en" % [id, q])
		for q in se:
			if not qs.has(q):
				bad.append("%s: src_en %s sin q:" % [id, q])
			elif not canon.contains(_norm(String(se[q]))):
				bad.append("%s: src_en %s no está en fixtures/canon" % [id, q])
		for tid in CONTRACT.get(id, {}):
			if not tramos.has(tid):
				bad.append("%s: falta el tramo #%s del contrato" % [id, tid])
			elif not (tramos[tid].get("a", []) as Array).has(CONTRACT[id][tid]):
				bad.append("%s#%s: sin a:%s" % [id, tid, CONTRACT[id][tid]])
	print("TOTAL corpus A: %d palabras" % tot)
	bad.append_array(_dynamic())
	for b in bad:
		print("!! ", b)
	print("W3-CT-CORPUS-A: %d hallazgos" % bad.size())
	quit(1 if not bad.is_empty() else 0)
