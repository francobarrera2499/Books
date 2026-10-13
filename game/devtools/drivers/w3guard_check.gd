# Driver del guardián de contenido (ola 3). Headless, sin capturas. Desde la raíz:
#   ./godot.sh --headless -s devtools/drivers/w3guard_check.gd
# Sobre data/ real: (1) refs de rutas/refutaciones que T7 no encuentra; (2) uniformidad del corpus D01 (palabras,
# tramos, menciones, etiquetas por historia); (3) chron_date en todo D01; (4) estado de RouteDB por conclusión.
extends SceneTree

const DataRepo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var rp = DataRepo.load_dir("res://data")
	var t = load("res://tests/test_t07_knowledge.gd").new()
	t._rp = rp
	var idx: Dictionary = t._frag_index()
	var refs := {}
	for cid in rp.conclusions_meta().get("mandatory", []):
		for r in t._conc_refs(rp.conclusion(cid)):
			refs[r] = cid
	for pf in rp.files().get("conclusions.json", {}).get("_pistas_falsas", []):
		for r in pf.get("refutaciones", []):
			refs[String(r)] = "refutación %s" % pf.id
	var ks: Array = refs.keys()
	ks.sort()
	print("== (1) refs sin fragmento en el índice de T7")
	for r in ks:
		if r.begins_with("J:") or r.begins_with("AD:") or r.begins_with("M:") or r.begins_with("R:") or r.contains("*"):
			continue
		if not idx.has(r):
			print("  falta: %s (%s)" % [r, refs[r]])
	print("== (2) uniformidad del corpus D01")
	var ids: Array = rp.docs().keys()
	ids.sort()
	for id in ids:
		if not (String(id).begins_with("D01.") or String(id) in ["D43", "D44", "D01N"]):
			continue
		var d: Dictionary = rp.doc(id)
		var words := 0
		var tramos := 0
		var named := 0
		var ments := 0
		var tags := 0
		var atags := 0
		for p in d.get("parts", []):
			var pt: Dictionary = rp.parsed(id, String(p.id))
			words += String(pt.get("plain", "")).split(" ", false).size()
			for tr in pt.get("tramos", []):
				tramos += 1
				if String(tr.id) != "":
					named += 1
				for k in tr.tags:
					tags += tr.tags[k].size()
					if k == "a":
						atags += tr.tags[k].size()
			ments += pt.get("mentions", []).size()
		print("  %-10s parts=%d words=%4d decl=%4d tramos=%2d con_id=%2d menc=%3d tags=%3d a:=%d chron=%s" % [id, d.get("parts", []).size(), words, int(d.get("words", 0)), tramos, named, ments, tags, atags, String(d.get("chron_date", "-"))])
	print("== (4) RouteDB.lint por conclusión (errores y pendientes)")
	for c in rp.conclusions():
		var res: Dictionary = RouteDB.lint(rp, String(c.id))
		for e in res.errors:
			print("  ERR " + String(e))
		for e in res.pending:
			print("  PEN " + String(e))
	quit(0)
