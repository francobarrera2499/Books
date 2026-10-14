# ui/reader/view_model.gd — forma de vista del lector (§3.7 q_view) y respaldo desde el DataRepo. Dueño: W2-READER.
# La verdad la da Game.sim.q_view(view) = {view, title, src_line, paper, paper_mm, font, machine, pages:[[{doc, origin,
#   copy, parsed}]]}. normalize(v) completa lo que falte (papel, medidas por defecto, ranura) sin inventar texto.
# from_repo(repo, ref): arma esa misma forma leyendo el DataRepo (ref = ejemplar "D05@BM" o documento "D05"); sólo para
#   tests, capturas y --screen=reader:<id> cuando no hay partida (Game.sim == null). Ignora parts[].when y la
#   accesibilidad: no se usa con una partida en curso.
# Extras de respaldo (fuera de §3.7): doc, measure, plate, pages[i][j].part (id de la parte).
# v3 (GDD_v3 §6.7, dueño LECTOR): normalize conserva ficha ({trata, cuando, por_que} o null) y marks ([{page, block,
#   tramo}]) y, en cada bloque, slot ("cuerpo"|"margen"|"tarjeta"), hand y anchor. Los bloques inválidos se descartan
#   SIN renumerar (un bloque vacío ocupa su lugar), porque el recorte y las anclas usan el índice de q_view.
extends RefCounted

const DEFAULT_MM := {
	"diario_hueso": [300, 420], "strand": [170, 250], "diogenes_recortado": [178, 219], "telegrama": [200, 128],
	"carta": [178, 229], "registro": [250, 350], "libro_mayor": [250, 350], "cuaderno": [180, 230], "tarjeta": [127, 76],
}

static func normalize(v: Dictionary) -> Dictionary:
	var out := v.duplicate()
	var paper := "" if out.get("paper") == null else str(out.get("paper"))
	if paper == "":
		paper = "carta"
	out["paper"] = paper
	var mm = out.get("paper_mm")
	if typeof(mm) != TYPE_ARRAY or mm.size() != 2 or float(mm[0]) <= 0.0 or float(mm[1]) <= 0.0:
		mm = DEFAULT_MM.get(paper, [178, 229])
	out["paper_mm"] = [float(mm[0]), float(mm[1])]
	var font := "imprenta" if out.get("font") == null else str(out.get("font"))
	if not ["imprenta", "maquina", "manuscrito", "ui"].has(font):
		font = "imprenta"
	out["font"] = font
	var m = out.get("machine")
	out["machine"] = "" if m == null else String(m)
	for k in ["title", "src_line", "view", "plate", "doc"]:
		out[k] = "" if out.get(k) == null else str(out.get(k))
	var pages: Array = []
	for pg in out.get("pages", []):
		var blocks: Array = []
		var list = pg.get("blocks", []) if typeof(pg) == TYPE_DICTIONARY else pg
		if typeof(list) != TYPE_ARRAY:
			continue
		for b in list:
			if typeof(b) == TYPE_DICTIONARY and typeof(b.get("parsed")) == TYPE_DICTIONARY:
				blocks.append(b)
			else:
				# un hueco vacío conserva los índices de los bloques que siguen (se quitan los del final)
				blocks.append({"parsed": {"plain": "", "styles": [], "tramos": [], "mentions": []}, "slot": "cuerpo", "_vacio": true})
		while not blocks.is_empty() and bool(blocks[-1].get("_vacio", false)):
			blocks.pop_back()
		pages.append(blocks)
	out["pages"] = pages
	var fi = out.get("ficha")
	out["ficha"] = fi if typeof(fi) == TYPE_DICTIONARY and not (fi as Dictionary).is_empty() else null
	var mk = out.get("marks")
	out["marks"] = mk if typeof(mk) == TYPE_ARRAY else []
	return out

static func src_line(repo, d: Dictionary) -> String:
	var t := String(d.get("title", ""))
	var st := String(d.get("src_type", ""))
	var lab := String(repo.lists().get("src_types", {}).get(st, st)) if repo != null else st
	if lab.contains("${"):
		lab = st.replace("_", " ")
	if t == "":
		return lab
	return t if lab == "" else "%s — %s" % [t, lab]

static func from_repo(repo, ref: String) -> Dictionary:
	if repo == null:
		return {}
	var doc_id := ref
	var copy_id := ""
	if ref.contains("@"):
		var c: Dictionary = repo.copy(ref)
		if c.is_empty():
			return {}
		doc_id = String(c.doc)
		copy_id = ref
	var d: Dictionary = repo.doc(doc_id)
	if d.is_empty():
		return {}
	if copy_id == "":
		var cps: Array = d.get("copies", [])
		if not cps.is_empty() and typeof(cps[0]) == TYPE_DICTIONARY:
			copy_id = String(cps[0].get("id", ""))
	var pages: Array = []
	for p in d.get("parts", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var pid := String(p.get("id", ""))
		pages.append([{"doc": doc_id, "origin": String(d.get("origin", doc_id)), "copy": copy_id,
			"parsed": repo.parsed(doc_id, pid), "part": pid}])
	var pl = d.get("plate")
	return normalize({
		"view": ref, "title": String(d.get("title", "")), "src_line": src_line(repo, d), "paper": str(d.get("paper", "")),
		"paper_mm": d.get("paper_mm"), "font": str(d.get("font", "imprenta")), "machine": d.get("machine"),
		"pages": pages, "doc": doc_id, "measure": d.get("measure"), "plate": "" if pl == null else str(pl),
	})
