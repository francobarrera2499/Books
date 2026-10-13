# ui/epilogue/epilogue_model.gd — vista-modelo del epílogo (pura: sin nodos; sólo lee la GameSim). Dueño: W4-EPILOGUE.
# Contrato: ARCHITECTURE §2.3 (Epilogue -> Credits -> BluePencil), §3.7 (q_epilogue, q_scene, q_blue_pencil, q_view,
# q_ledger…), §4.15 (variantes acumulables); GDD §12.2–12.3. Todo lo que el epílogo muestra sale de aquí (testeable sin
# ventana). `sim` = GameSim (sim.repo = DataRepo). Datos: ui_text/epilogo.json (W3-CT-LISLE: texto, colofón, lápiz azul;
# su _orden y la regla de variantes «clave@v» reemplaza / «clave+v» agrega) y ui_text/epilogue_ui.json (este WP:
# rótulos y datos de presentación _lente, _corte, _subraya, _nota_azul, _sonido, _encuadre, _ids, _noche, _final,
# _estante). Ninguna etiqueta oculta se muestra: los ids de tramo sólo sirven para posar la lupa y reconocer el corte.
#   info(sim) -> {ending, card, card_base, card_adds, scene, epi:[ids], noche_final, publica, decided, offer, after_final}
#   night(sim) -> {place, area, frame, tk, lines:[{id, parsed, sounds, frame}]}      (HC09 según noche_final)
#   end_lines(sim) -> [{id, who, parsed}]                                             (END.<final>)
#   reading_beats(sim) / closing_beats(sim) -> [beat]   beat = {kind: date|para|line|offer|ficha, key, parsed, lens, …}
#   cut_target(sim) -> {doc, view, tramo, page, from, to, text}                       (el último gesto)
#   concordance(sim) -> {title, head, body}  ·  credits(sim) -> [parsed]  ·  pencil(sim) -> {...}
#   snapshot(sim, place, area, tk, slot, frame) -> lámina de §3.7 para WorldRoot.show_plate
#   shelf_volumes(place_def, prop_id, n) -> [{size, pos}] (local del prop l4.bookcase: los tomos que cierran el hueco)
extends RefCounted

const WorldModel = preload("res://core/sim/world_model.gd")
const Cond = preload("res://core/util/cond.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const Diary = preload("res://core/sim/diary.gd")
const LedgerModel = preload("res://ui/ledger/ledger_model.gd")

const EPI_FILE := "ui_text/epilogo.json"
const UI_FILE := "ui_text/epilogue_ui.json"
const KEY_PUBLICAR := "epilogo.12.publicar"
const KEY_TIJERA := "epilogo.13.tijera"
const KEY_LLEGA := "epilogo.02.llega"
const DEF_IDS := {"revista": "D38@L1", "concordancia": "D21", "tramo_concordancia": "fina", "noche": "HC09"}

# ---------------------------------------------------------------- datos
static func repo_of(sim):
	if sim != null and sim.repo != null:
		return sim.repo
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null and ml.root.get_node_or_null("Data") != null:
		return ml.root.get_node("Data").repo()
	return null

static func tx(sim, key: String, vars := {}) -> String:
	var repo = repo_of(sim)
	if repo == null:
		return key
	return String(repo.text(key, vars))

static func has_tx(sim, key: String) -> bool:
	var repo = repo_of(sim)
	return repo != null and repo.texts().has(key)

static func parse(sim, src: String) -> Dictionary:
	var repo = repo_of(sim)
	if repo == null:
		return Markup.parse(src)
	return repo.parse_text(src)

static func _file(sim, rel: String) -> Dictionary:
	var repo = repo_of(sim)
	if repo == null:
		return {}
	var f = repo.files().get(rel, {})
	return f if typeof(f) == TYPE_DICTIONARY else {}

static func cfg(sim, key: String, default = null):
	var v = _file(sim, UI_FILE).get(key, null)
	return default if v == null else v

static func ids(sim) -> Dictionary:
	var out := DEF_IDS.duplicate()
	var c = cfg(sim, "_ids", {})
	if typeof(c) == TYPE_DICTIONARY:
		out.merge(c, true)
	return out

static func orden(sim) -> Array:
	var o = _file(sim, EPI_FILE).get("_orden", [])
	return o if typeof(o) == TYPE_ARRAY else []

static func _tk(v, default: int) -> int:
	if typeof(v) == TYPE_STRING and String(v) != "":
		var t := TimeKey.parse(String(v))
		return t if t >= 0 else default
	if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
		return int(v)
	return default

# ---------------------------------------------------------------- final y variantes
static func info(sim) -> Dictionary:
	var q: Dictionary = sim.q_epilogue() if sim != null else {}
	var e: Dictionary = q.get("ending", {})
	var ending := String(e.get("ending", ""))
	var st = sim.st if sim != null else null
	var decided := false
	var flags := {}
	if st != null:
		decided = bool(st.clock.get("errata_decided", false))
		flags = st.flags
	var epi: Array = []
	for v in e.get("epilogue", []):
		epi.append(String(v))
	return {"ending": ending, "card": String(e.get("card", "")), "card_base": String(e.get("card_base", "")),
		"card_adds": (e.get("card_adds", []) as Array).duplicate(), "scene": String(e.get("scene", "")), "epi": epi,
		"noche_final": String(flags.get("noche_final", "")), "publica": bool(flags.get("publica_errata", false)),
		"decided": decided, "offer": ending != "" and ending != "F1" and not decided, "after_final": not q.is_empty(),
		"offered_ending": ending != "" and ending != "F1"}

static func has_variant(sim, v: String) -> bool:
	return info(sim).epi.has(v)

# ---------------------------------------------------------------- la noche del jueves (HC09)
static func night(sim) -> Dictionary:
	if sim == null:
		return {}
	var inf := info(sim)
	var where := String(inf.noche_final)
	var set_cfg = cfg(sim, "_noche", {}).get(where, {}) if typeof(cfg(sim, "_noche", {})) == TYPE_DICTIONARY else {}
	if typeof(set_cfg) != TYPE_DICTIONARY:
		set_cfg = {}
	var sid := String(ids(sim).noche)
	var snd: Dictionary = cfg(sim, "_sonido", {})
	var frm: Dictionary = cfg(sim, "_encuadre", {})
	var lines: Array = []
	if where != "" and not sim.repo.scene(sid).is_empty():
		for ln in WorldModel.scene_lines(sim.st, sim.repo, sid):
			var key := "%s.%s" % [sid, String(ln.id)]
			var sounds: Array = []
			var s = snd.get(key, [])
			if typeof(s) == TYPE_ARRAY:
				for x in s:
					sounds.append(String(x))
			elif typeof(s) == TYPE_STRING and String(s) != "":
				sounds.append(String(s))
			lines.append({"id": String(ln.id), "who": String(ln.who), "parsed": parse(sim, String(ln.text)), "sounds": sounds,
				"frame": String(frm.get(key, ""))})
	return {"where": where, "place": String(set_cfg.get("place", "")), "area": String(set_cfg.get("area", "")),
		"frame": String(set_cfg.get("frame", "")), "tk": _tk(set_cfg.get("tk", ""), TimeKey.tk(10, "night")),
		"slot": "night", "lines": lines}

# ---------------------------------------------------------------- la escena del final (END.F1…F4)
static func end_lines(sim) -> Array:
	var out: Array = []
	if sim == null:
		return out
	var sid := String(info(sim).scene)
	if sid == "" or sim.repo.scene(sid).is_empty():
		return out
	for ln in WorldModel.scene_lines(sim.st, sim.repo, sid):
		out.append({"id": String(ln.id), "who": String(ln.who), "parsed": parse(sim, String(ln.text))})
	return out

# ---------------------------------------------------------------- texto del epílogo (1903)
static func _lens_of(sim, key: String) -> String:
	var m = cfg(sim, "_lente", {})
	return String(m.get(key, "")) if typeof(m) == TYPE_DICTIONARY else ""

static func _beat(sim, kind: String, key: String) -> Dictionary:
	return {"kind": kind, "key": key, "parsed": parse(sim, tx(sim, key)), "lens": _lens_of(sim, key)}

# Párrafos de una clave de _orden con sus variantes (regla de epilogo.json: «k@v» reemplaza la base, «k+v» se agrega
# después, en el orden de endings.json variants = orden de info.epi).
static func _key_beats(sim, k: String, epi: Array) -> Array:
	var out: Array = []
	var base_key := k if has_tx(sim, k) else ""
	for v in epi:
		if has_tx(sim, k + "@" + String(v)):
			base_key = k + "@" + String(v)
	if base_key != "":
		var kind := "para"
		if k.ends_with(".fecha"):
			kind = "date"
		elif k.ends_with(".ficha"):
			kind = "ficha"
		var b := _beat(sim, kind, base_key)
		if String(b.lens) == "":
			b.lens = _lens_of(sim, k)
		out.append(b)
	for v in epi:
		var ak := k + "+" + String(v)
		if has_tx(sim, ak):
			out.append(_beat(sim, "ficha" if k.ends_with(".ficha") else "para", ak))
	return out

static func _crane_lines(sim) -> Array:
	var out: Array = []
	var sc: Dictionary = sim.q_scene() if sim != null else {}
	for ln in sc.get("lines", []):
		var who := String(ln.get("who", ""))
		out.append({"kind": "line", "key": String(ln.get("uid", "")), "who": who, "name": Diary.char_label(sim.repo, who) if who != "" else "",
			"parsed": ln.get("parsed", {}), "lens": ""})
	return out

static func _beats(sim, first: int, last: int) -> Array:
	var out: Array = []
	var inf := info(sim)
	var o := orden(sim)
	for i in range(maxi(first, 0), mini(last, o.size())):
		var k := String(o[i])
		if k == KEY_PUBLICAR:
			if bool(inf.offer):
				out.append({"kind": "offer", "key": k + ".oferta", "parsed": parse(sim, tx(sim, k + ".oferta")), "lens": "",
					"yes": tx(sim, k + ".si"), "no": tx(sim, k + ".no")})
			elif bool(inf.decided) and bool(inf.offered_ending) and not bool(inf.publica):
				out.append(_beat(sim, "para", k + ".guardada"))
		out.append_array(_key_beats(sim, k, inf.epi))
		if k == KEY_LLEGA:
			out.append_array(_crane_lines(sim))
	return out

static func _split(sim) -> int:
	var o := orden(sim)
	var i := o.find(KEY_TIJERA)
	return i if i >= 0 else o.size()

# Hasta la tijera (sin incluirla): la lectura de la Strand y la decisión sobre la fe de erratas.
static func reading_beats(sim) -> Array:
	return _beats(sim, 0, _split(sim))

# Desde la tijera: lo que sigue al último gesto (se calcula después del corte y de la decisión: la posdata depende de ella).
static func closing_beats(sim) -> Array:
	return _beats(sim, _split(sim), orden(sim).size())

# ---------------------------------------------------------------- la Strand (D38) y el corte
static func strand_view(sim) -> Dictionary:
	if sim == null:
		return {}
	var v: Dictionary = sim.q_view(String(ids(sim).revista))
	if v.is_empty() or (v.get("pages", []) as Array).is_empty():
		return {}
	# como el lector (ViewModel): sin nulos para PageView
	for k in ["machine", "paper", "font", "title", "src_line"]:
		if v.get(k) == null:
			v[k] = "imprenta" if k == "font" else ""
	if typeof(v.get("paper_mm")) != TYPE_ARRAY:
		v["paper_mm"] = [170, 250]
	return v

static func doc_of_view(view_id: String) -> String:
	return view_id.get_slice("@", 0)

# Índice de hoja (q_view.pages) de una parte del documento: las hojas siguen el orden de las partes.
static func page_of_part(sim, doc_id: String, part_id: String) -> int:
	var d: Dictionary = sim.repo.doc(doc_id)
	var i := 0
	for p in d.get("parts", []):
		if typeof(p) == TYPE_DICTIONARY:
			if String(p.get("id", "")) == part_id:
				return i
			i += 1
	return -1

# Tramo de la revista -> {tramo, page, from, to} (vacío si no existe).
static func tramo_at(sim, tid: String) -> Dictionary:
	if sim == null or tid == "":
		return {}
	var doc := doc_of_view(String(ids(sim).revista))
	var t: Dictionary = sim.repo.doc_tramo(doc, tid)
	if t.is_empty():
		return {}
	var pg := page_of_part(sim, doc, String(t.get("part", "")))
	if pg < 0:
		return {}
	return {"tramo": tid, "page": pg, "from": int(t.from), "to": int(t.to)}

static func cut_target(sim) -> Dictionary:
	var tid := String(cfg(sim, "_corte", ""))
	var t := tramo_at(sim, tid)
	if t.is_empty():
		return {}
	var v := strand_view(sim)
	var text := ""
	if not v.is_empty() and int(t.page) < (v.pages as Array).size() and not (v.pages[int(t.page)] as Array).is_empty():
		var plain := String(v.pages[int(t.page)][0].get("parsed", {}).get("plain", ""))
		text = plain.substr(int(t.from), int(t.to) - int(t.from))
	t["view"] = String(ids(sim).revista)
	t["text"] = text
	return t

# ¿La selección [from, from+len) de la hoja `page` toca el tramo del corte? (una palabra basta: Lisle corta «entre punto
# y punto»; el corte real es siempre la oración entera).
static func hits_cut(sim, page: int, from: int, length: int) -> bool:
	var t := cut_target(sim)
	if t.is_empty() or int(t.page) != page or length <= 0:
		return false
	return mini(from + length, int(t.to)) - maxi(from, int(t.from)) > 0

# Marcas de variante sobre la revista: [{kind:"subraya"|"nota_azul", tramo, page, from, to}]
static func page_marks(sim) -> Array:
	var out: Array = []
	var epi: Array = info(sim).epi
	for spec in [["_subraya", "subraya"], ["_nota_azul", "nota_azul"]]:
		var m = cfg(sim, spec[0], {})
		if typeof(m) != TYPE_DICTIONARY:
			continue
		for v in m:
			if epi.has(String(v)):
				var t := tramo_at(sim, String(m[v]))
				if not t.is_empty():
					t["kind"] = spec[1]
					t["variant"] = String(v)
					out.append(t)
	return out

# ---------------------------------------------------------------- concordancia (D21, última hoja) y ficha
static func concordance(sim) -> Dictionary:
	var out := {"title": tx(sim, "epilogue.concordancia.titulo"), "head": "", "body": ""}
	var repo = repo_of(sim)
	if repo == null:
		return out
	var did := String(ids(sim).concordancia)
	var t: Dictionary = repo.doc_tramo(did, String(ids(sim).tramo_concordancia))
	if t.is_empty():
		return out
	var pt: Dictionary = repo.parsed(did, String(t.get("part", "")))
	var plain := String(pt.get("plain", ""))
	var nl := plain.find("\n")
	out.head = plain.left(nl).strip_edges() if nl > 0 else ""
	out.body = plain.substr(int(t.from)).strip_edges()
	return out

# ---------------------------------------------------------------- colofón
static func credits(sim) -> Array:
	var out: Array = []
	for i in range(1, 40):
		var k := "epilogo.creditos.%02d" % i
		if not has_tx(sim, k):
			if i > 1:
				break
			continue
		out.append(parse(sim, tx(sim, k)))
	return out

# ---------------------------------------------------------------- lápiz azul (post-créditos)
# {title, header, pages:[{id, title, rows:[{eid, n, summary, ink, practice, wrong, note}]}], missing:[notas],
#  nothing, nada, sign}
static func pencil(sim) -> Dictionary:
	var bp: Array = sim.q_blue_pencil() if sim != null else []
	var wrong := {}
	var missing: Array = []
	for it in bp:
		if String(it.get("kind", "")) == "wrong":
			wrong[String(it.get("entry", ""))] = String(it.get("note", ""))
		elif String(it.get("kind", "")) == "missing":
			var n := String(it.get("note", ""))
			if n != "" and not missing.has(n):
				missing.append(n)
	var pages: Array = []
	if sim != null:
		for p in LedgerModel.pages(sim):
			if String(p.get("kind", "")) == "rules":
				continue
			var rows: Array = []
			for eid in LedgerModel.page_entries(sim, String(p.id)):
				var vm := LedgerModel.entry_vm(sim, String(eid))
				if vm.is_empty():
					continue
				var summ := LedgerModel.entry_summary(vm)
				rows.append({"eid": String(eid), "n": int(vm.n), "tname": String(vm.tname), "summary": summ, "ink": String(vm.ink),
					"practice": bool(vm.practice), "wrong": wrong.has(String(eid)), "note": String(wrong.get(String(eid), ""))})
			if rows.is_empty():
				continue
			var title := String(p.get("title", ""))
			if String(p.get("kind", "")) == "folio" and String(p.get("head_short", "")) != "":
				title = "%s · %s" % [title, String(p.head_short)]
			pages.append({"id": String(p.id), "kind": String(p.kind), "title": title, "rows": rows})
	var nothing := bp.is_empty()
	return {"title": tx(sim, "epilogo.lapiz.titulo"), "header": tx(sim, "epilogo.lapiz.encabezado"), "pages": pages,
		"missing": missing, "nothing": nothing, "nada": tx(sim, "epilogo.lapiz.nada"),
		"sign": tx(sim, "epilogo.lapiz.firma_tirese" if nothing else "epilogo.lapiz.firma_corrijase"),
		"wrong_n": wrong.size(), "empty": tx(sim, "epilogue.lapiz.sin_asientos")}

# ---------------------------------------------------------------- láminas del epílogo
# Instantánea de un lugar a una hora dada (los `when` de los nodos con ctx.tk: la noche del jueves no es «ahora»).
static func snapshot(sim, place: String, area: String, tk: int, slot: String, frame: String) -> Dictionary:
	var repo = repo_of(sim)
	if repo == null:
		return {}
	var pl: Dictionary = repo.place(place)
	if pl.is_empty():
		return {}
	var ctx := {"st": sim.st if sim != null else null, "repo": repo, "tk": tk}
	var nodes: Array = []
	for nd in pl.get("nodes", []):
		if typeof(nd) != TYPE_DICTIONARY:
			continue
		var na := String(nd.get("area", "*"))
		if area != "" and na != "*" and na != "" and na != area:
			continue
		if nd.has("when") and ctx.st != null and not Cond.eval(nd.when, ctx):
			continue
		var nid := String(nd.get("id", ""))
		if nid != "" and not nodes.has(nid):
			nodes.append(nid)
	var variant := ""
	if sim != null and sim.st != null:
		variant = String(sim.st.world.get("place_variants", {}).get(place, ""))
	return {"id": "EPI.%s.%s" % [place, slot], "place": place, "area": area, "day": TimeKey.day_of(tk), "slot": slot,
		"variant": variant, "nodes": nodes, "chars": [], "silhouettes": [], "frame": frame}

static func setting(sim, key: String) -> Dictionary:
	var c = cfg(sim, key, {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

# Tomos que cierran el hueco del segundo estante (geometría de world/props/l4.gd build_bookcase, en local del prop):
# mismo estante (s = 1), entre gap_from y gap_to, apoyados en la tabla y al ras del frente de los otros lomos.
static func shelf_volumes(place_def: Dictionary, prop_id: String, n: int) -> Array:
	var p := {}
	for pr in place_def.get("props", []):
		if typeof(pr) == TYPE_DICTIONARY and String(pr.get("id", "")) == prop_id:
			p = pr.get("p", {}) if typeof(pr.get("p", {})) == TYPE_DICTIONARY else {}
	if p.is_empty() or n <= 0:
		return []
	var h := float(p.get("h", 2.3))
	var bh := float(p.get("base_h", 0.85))
	var d := float(p.get("d", 0.36))
	var g0 := float(p.get("gap_from", 0.12))
	var g1 := float(p.get("gap_to", 0.45))
	var y0 := bh + 0.02
	var top := h - 0.1
	var sh := (top - y0) / 3.0
	var sy := top - sh * 2.0
	var t := (g1 - g0) / float(n)
	var vh := minf(sh - 0.06, 0.27)
	var depth := minf(d - 0.12, 0.2)
	var front := d / 2.0 - 0.03 - (d - 0.08) / 2.0 + 0.01 + (d - 0.08) / 2.0
	var out: Array = []
	for i in n:
		var x := g0 + t * (float(i) + 0.5)
		out.append({"size": Vector3(t - 0.004, vh, depth), "pos": Vector3(x, sy + 0.022 + vh / 2.0, front - depth / 2.0)})
	return out
