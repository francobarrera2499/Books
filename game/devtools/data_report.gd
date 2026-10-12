# devtools/data_report.gd — palabras reales por documento vs el presupuesto declarado (`words`, §4.4, GDD§6/§15.1).
# Dueño: W1-ENG. CLI (desde la raíz): ./godot.sh --headless -s devtools/data_report.gd [-- <root>] [-- --tol=15]
# Imprime una fila por doc: id, palabras reales (Markup: palabras del texto plano de todas las partes), declaradas,
# desvío %, y marca "!!" si |desvío| > tolerancia (15 % por defecto, aceptación de contenido §10). Total al final.
# Sale con 0 siempre (es un informe); los tests usan report() directamente.
extends SceneTree

const Markup = preload("res://core/text/markup.gd")

static func doc_words(repo, id: String) -> int:
	var n := 0
	for p in repo.doc(id).get("parts", []):
		if typeof(p) == TYPE_DICTIONARY:
			n += repo.parsed(id, String(p.get("id", ""))).get("words", []).size()
	return n

# [{id, real, declared, delta_pct, ok}] ordenado por id (natural).
static func report(repo, tol_pct := 15.0) -> Array:
	var ids: Array = repo.docs().keys()
	ids.sort_custom(func(a, b): return String(a).naturalnocasecmp_to(String(b)) < 0)
	var out: Array = []
	for id in ids:
		var real := doc_words(repo, id)
		var dec := int(repo.doc(id).get("words", 0))
		var delta := 0.0
		if dec > 0:
			delta = 100.0 * float(real - dec) / float(dec)
		elif real > 0:
			delta = 100.0
		out.append({"id": id, "real": real, "declared": dec, "delta_pct": delta, "ok": absf(delta) <= tol_pct})
	return out

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	var root := "res://data"
	var tol := 15.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("res://"):
			root = a
		elif a.begins_with("--tol="):
			tol = a.substr(6).to_float()
	var repo = load("res://core/data/data_repo.gd").fresh(root)
	var rows := report(repo, tol)
	var tr := 0
	var td := 0
	var bad := 0
	print("%-12s %8s %8s %8s" % ["doc", "reales", "declar.", "desvío"])
	for r in rows:
		tr += r.real
		td += r.declared
		if not r.ok:
			bad += 1
		print("%-12s %8d %8d %+7.1f%% %s" % [r.id, r.real, r.declared, r.delta_pct, "" if r.ok else "!!"])
	print("TOTAL: %d docs, %d palabras reales, %d declaradas, %d fuera de ±%.0f %%" % [rows.size(), tr, td, bad, tol])
	if not repo.errors().is_empty():
		print("(DataRepo informa %d errores; ver devtools/lint.gd data)" % repo.errors().size())
	quit(0)
