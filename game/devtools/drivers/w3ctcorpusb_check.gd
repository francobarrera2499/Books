# Driver de verificación de W3-CT-CORPUS-B (headless, sin capturas). Desde la raíz:
#   ./godot.sh --headless -s devtools/drivers/w3ctcorpusb_check.gd [-- --text]
# Revisa sólo los archivos del paquete (docs D01.{SILV,CARD,YELL,STOC,GLOR,MUSG,REIG,CROO,RESI,GREE,NAVA}, D43, D44,
# D01N y entities/corpus_b.json): errores de DataRepo, Markup.lint, src_en contra tests/fixtures/canon (misma
# normalización que T7), palabras reales contra `words`, tramos con sus etiquetas, campos de respuesta indexables
# (test_i_integration.unreachable_answers) de las conclusiones que tocan estos documentos, las rutas de conclusions.json
# que citan sus tramos (RouteDB.route_errors; también C1.xx y C14, que T1 no revisa) y violaciones de T4.
# Las rutas con «falta …» esperan contenido ajeno (D14, D18, siluetas); «!!» sin «falta» es un error de etiquetas.
# --text imprime además el texto plano de cada parte (revisión de lectura).
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const Markup = preload("res://core/text/markup.gd")

const MINE := ["D01.SILV", "D01.CARD", "D01.YELL", "D01.STOC", "D01.GLOR", "D01.MUSG", "D01.REIG", "D01.CROO",
	"D01.RESI", "D01.GREE", "D01.NAVA", "D43", "D44", "D01N"]
const MY_FILES := ["docs/D01/SILV", "docs/D01/CARD", "docs/D01/YELL", "docs/D01/STOC", "docs/D01/GLOR", "docs/D01/MUSG",
	"docs/D01/REIG", "docs/D01/CROO", "docs/D01/RESI", "docs/D01/GREE", "docs/D01/NAVA", "docs/D43", "docs/D44",
	"docs/D01N", "entities/corpus_b"]
const CONCS := ["C1.01", "C1.02", "C1.06", "C1.07", "C1.09", "C2", "C7", "C8", "C14"]

static func _norm(s: String) -> String:
	var t := s.replace("’", "'").replace("‘", "'").replace("“", "\"").replace("”", "\"").replace("—", "-").replace("–", "-")
	t = t.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.strip_edges()

func _init() -> void:
	_go.call_deferred()

func _mine_err(e: String) -> bool:
	for f in MY_FILES:
		if e.contains(f):
			return true
	for id in MINE:
		if e.contains(id + "#") or e.contains(id + "@"):
			return true
	return false

func _go() -> void:
	var show_text := OS.get_cmdline_user_args().has("--text")
	var repo = Repo.fresh("res://data")
	var all_err: Array = repo.errors()
	var bad := 0
	print("== DataRepo: %d errores en total" % all_err.size())
	for e in all_err:
		if _mine_err(String(e)):
			print("  MÍO  ", e)
			bad += 1
	var others := all_err.size() - bad
	if others > 0:
		print("  (%d errores ajenos)" % others)
	# canon
	var canon := ""
	for f in DirAccess.get_files_at("res://tests/fixtures/canon"):
		if f.ends_with(".txt"):
			canon += " " + _norm(FileAccess.get_file_as_string("res://tests/fixtures/canon/" + f))
	var ctx: Dictionary = repo.markup_ctx()
	var tot_real := 0
	for id in MINE:
		var d: Dictionary = repo.doc(id)
		if d.is_empty():
			print("-- %s: no existe" % id)
			continue
		var real := 0
		var ntr := 0
		var nid := 0
		for p in d.get("parts", []):
			for e in Markup.lint(String(p.text), ctx):
				print("  LINT %s/%s: %s" % [id, p.id, e])
				bad += 1
			var pt: Dictionary = repo.parsed(id, String(p.id))
			real += pt.words.size()
			for t in pt.tramos:
				ntr += 1
				if String(t.id) != "":
					nid += 1
				var tg: Array = []
				for k in t.tags:
					for v in t.tags[k]:
						tg.append("%s:%s" % [k, v])
				var wn := Markup.count_words(pt.words, t.from, t.to)
				if show_text or not (tg.filter(func(x): return String(x).begins_with("a:") or String(x).begins_with("x:"))).is_empty():
					print("    #%-14s %2dp  %s" % [t.id, wn, " ".join(tg)])
			if show_text:
				print("---- %s/%s ----\n%s\n" % [id, p.id, pt.plain])
		var se: Dictionary = d.get("src_en", {})
		for q in se:
			if not canon.contains(_norm(String(se[q]))):
				print("  SRC_EN %s q:%s no está en el canon: %s" % [id, q, se[q]])
				bad += 1
		var dec := int(d.get("words", 0))
		var dev := 100.0 * float(real - dec) / float(maxi(dec, 1))
		tot_real += real
		print("%-9s palabras %4d / %4d (%+5.1f%%)%s  tramos %d (%d con id)" % [id, real, dec, dev, "" if absf(dev) <= 15.0 else "  !!", ntr, nid])
	print("TOTAL palabras reales: %d" % tot_real)
	# indexables
	var Integ = load("res://tests/test_i_integration.gd")
	var un: Array = Integ.unreachable_answers(repo, CONCS)
	print("== Campos sin valor indexable (%s): %d" % [", ".join(CONCS), un.size()])
	for u in un:
		print("  ", u)
	# rutas del contrato que usan estos documentos (también las no obligatorias: C1.xx, C14)
	var RouteDB = load("res://core/graph/route_db.gd")
	var nroute := 0
	for cid in CONCS:
		var c: Dictionary = repo.conclusion(cid)
		var ctags: Array = RouteDB.conc_tags(repo, cid)
		var last: int = RouteDB.last_idx(repo, cid)
		for r in RouteDB.routes(repo, cid):
			var mine_r := false
			for f in r.get("frags", []):
				for id in MINE:
					if String(f.get("ref", "")).begins_with(id + "#"):
						mine_r = true
			if not mine_r:
				continue
			nroute += 1
			var errs: Array = []
			for m in r.get("missing", []):
				errs.append("falta " + String(m))
			if r.get("missing", []).is_empty():
				errs.append_array(RouteDB.route_errors(repo, c, r, ctags, last))
			var fr: Array = []
			for f in r.frags:
				fr.append("%s[%s]" % [f.ref, ",".join(PackedStringArray(f.tags.filter(func(t): return String(t).begins_with("a:"))))])
			print("  RUTA %-9s %s %s  %s" % [r.id, "★" if bool(r.star) else " ", "OK" if errs.is_empty() else "!! " + "; ".join(PackedStringArray(errs)), " + ".join(PackedStringArray(fr))])
	print("== Rutas que usan estos documentos: %d" % nroute)
	# T4
	var T4 = load("res://tests/test_t04_max_clips.gd")
	var v: Array = T4.scan(repo)
	var mine4 := 0
	for x in v:
		for id in MINE:
			if String(x).begins_with(id + "/") or String(x).begins_with(id + "#"):
				print("  T4 ", x)
				mine4 += 1
				break
	print("== T4: %d violaciones (%d mías)" % [v.size(), mine4])
	print("RESULTADO: %d problemas propios" % (bad + mine4))
	quit(0)
