# Chequeo W3-CT-LISLE (headless) sobre data/ real: D21, D23, D38 y ui_text/epilogo.json.
# ./godot.sh --headless -s devtools/drivers/w3ctlisle_check.gd
# Sale con 1 si algo falla (imprime «FALLA ...»); con 0 si todo está en regla. Comprueba:
#   errores propios del DataRepo · palabras por documento vs `words` (±15 %) · tramos ≤40 palabras
#   rutas del contrato que usan D23#cruel (RouteDB.linked, sin errores de fragmento)
#   R8: en el prólogo D21@L1 y D23@L1 se leen y recortar D23@L1#aviso indexa suceso_reichenbach
#   D38: sólo en el epílogo (E.dawn), #hombre_alto con e:lisle, una cita q: por tramo con su src_en
#   epilogo.json: claves de _orden (base o variantes), sufijos @/+ = ids de endings.json variants[].epilogue (y
#   todos usados), texto sin errores de Markup ni ${…}, claves de publicar/créditos/lápiz, ecos con D21 y D01N.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const Markup = preload("res://core/text/markup.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const GameSim = preload("res://core/sim/game_sim.gd")

const MINE := ["D21", "D23", "D38"]
const EPI := "res://data/ui_text/epilogo.json"
var fails: Array = []

func _init() -> void:
	_run.call_deferred()

func _f(msg: String) -> void:
	fails.append(msg)
	print("FALLA ", msg)

func _mine_err(e: String) -> bool:
	for d in MINE:
		if e.contains("docs/" + d) or e.contains(d + "#") or e.contains(d + "@"):
			return true
	return e.contains("epilogo")

func _run() -> void:
	var r = Repo.fresh("res://data")
	for e in r.errors():
		if _mine_err(String(e)):
			_f("repo: " + String(e))
	_docs(r)
	_routes(r)
	_prologue(r)
	_d38(r)
	_epilogue(r)
	print("\nW3-CT-LISLE: ", "OK" if fails.is_empty() else "%d fallas" % fails.size())
	quit(0 if fails.is_empty() else 1)

func _docs(r) -> void:
	for id in MINE:
		var d: Dictionary = r.doc(id)
		if d.is_empty():
			_f("%s no existe" % id)
			continue
		var n := 0
		var nt := 0
		for p in d.get("parts", []):
			var pt: Dictionary = r.parsed(id, String(p.id))
			n += (pt.get("words", []) as Array).size()
			for e in pt.get("errors", []):
				_f("%s/%s: %s" % [id, p.id, e])
			for t in pt.get("tramos", []):
				nt += 1
				var wn := Markup.count_words(pt.words, int(t.from), int(t.to))
				if wn > 40:
					_f("%s#%s: %d palabras" % [id, t.id, wn])
		var dec := int(d.get("words", 0))
		var dev := 100.0 * float(n - dec) / float(max(dec, 1))
		print("%s: %d palabras (presupuesto %d, %+.1f %%), %d tramos" % [id, n, dec, dev, nt])
		if absf(dev) > 15.0:
			_f("%s fuera de presupuesto: %+.1f %%" % [id, dev])

func _routes(r) -> void:
	var seen := 0
	for c in r.conclusions():
		for rt in RouteDB.routes(r, String(c.id)):
			var mine := false
			for f in rt.get("frags", []):
				for d in MINE:
					if String(f.get("ref", "")).begins_with(d + "#"):
						mine = true
			if not mine:
				continue
			seen += 1
			var ok: bool = RouteDB.linked(r, c, rt.frags)
			print("ruta %s %s: linked=%s" % [c.id, rt.get("id", "?"), ok])
			if not ok:
				_f("ruta %s %s no enlaza" % [c.id, rt.get("id", "?")])
			for f in rt.frags:
				if String(f.get("err", "")) != "":
					_f("ruta %s %s: %s %s" % [c.id, rt.get("id", "?"), f.get("ref", ""), f.err])
	if seen < 2:
		_f("se esperaban ≥2 rutas con D23#cruel (C10 Ic, C10a.R3): %d" % seen)

func _prologue(r) -> void:
	var sim = GameSim.new(r, 1894)
	for v in ["D21@L1", "D23@L1"]:
		if sim.q_view(v).is_empty():
			_f("%s no se lee en el prólogo" % v)
	var v: Dictionary = sim.q_view("D23@L1")
	var hit := false
	for i in (v.get("pages", []) as Array).size():
		for j in (v.pages[i] as Array).size():
			for t in v.pages[i][j].get("parsed", {}).get("tramos", []):
				if String(t.id) == "aviso":
					hit = true
					var res: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": "D23@L1", "part": i, "block": j}, "from": int(t.from), "len": int(t.to) - int(t.from)})
					if not bool(res.get("ok", false)):
						_f("recortar D23@L1#aviso: %s" % str(res))
	if not hit:
		_f("D23@L1 sin tramo #aviso en la vista")
	if not sim.q_index().any(func(x): return String(x.id) == "suceso_reichenbach"):
		_f("R8: el recorte de #aviso no indexa suceso_reichenbach")
	if not sim.q_view("D38@L1").is_empty():
		_f("D38@L1 legible en el prólogo (sólo epílogo)")

func _d38(r) -> void:
	var d: Dictionary = r.doc("D38")
	var cps: Array = d.get("copies", [])
	if cps.size() != 1 or String(cps[0].get("from", "")) != "E.dawn":
		_f("D38: un solo ejemplar, desde E.dawn: %s" % str(cps))
	var t: Dictionary = r.doc_tramo("D38", "hombre_alto")
	if t.is_empty() or not (t.get("tags", {}).get("e", []) as Array).has("lisle"):
		_f("D38#hombre_alto con e:lisle: %s" % str(t))
	var src: Dictionary = d.get("src_en", {})
	for p in d.get("parts", []):
		for tr in r.parsed("D38", String(p.id)).get("tramos", []):
			var q: Array = tr.tags.get("q", [])
			if q.size() != 1 or not src.has(String(q[0])):
				_f("D38#%s: cita q: sin src_en (%s)" % [tr.id, str(q)])
			if not (tr.tags.get("a", []) as Array).is_empty() or not (tr.tags.get("c", []) as Array).is_empty():
				_f("D38#%s: 1903 no lleva a: ni c:" % tr.id)

func _epilogue(r) -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(EPI))
	if typeof(raw) != TYPE_DICTIONARY:
		_f("epilogo.json ilegible")
		return
	var tx: Dictionary = raw.get("text", {})
	var ids := {}
	for v in r.endings().get("variants", []):
		if String(v.get("epilogue", "")) != "":
			ids[String(v.epilogue)] = false
	var ctx: Dictionary = r.markup_ctx()
	var words := 0
	for k in tx:
		var s := String(tx[k])
		if s.contains("${"):
			_f("%s: placeholder" % k)
		var pt: Dictionary = Markup.parse(s, ctx)
		for e in pt.get("errors", []):
			_f("%s: %s" % [k, e])
		words += (pt.get("words", []) as Array).size()
		var sk := String(k)
		for sep in ["@", "+"]:
			if sk.contains(sep):
				var vid := sk.get_slice(sep, 1)
				if not ids.has(vid):
					_f("%s: variante «%s» no está en endings.json" % [k, vid])
				else:
					ids[vid] = true
	for vid in ids:
		if not ids[vid]:
			_f("variante de endings.json sin texto en epilogo.json: " + vid)
	for base in raw.get("_orden", []):
		var b := String(base)
		var any := tx.has(b)
		for k in tx:
			if String(k).begins_with(b + "@") or String(k).begins_with(b + "+") or String(k).begins_with(b + "."):
				any = true
		if not any:
			_f("_orden: %s sin texto" % b)
	for k in ["epilogo.titulo", "epilogo.12.publicar.oferta", "epilogo.12.publicar.si", "epilogo.12.publicar.no",
			"epilogo.12.publicar.guardada", "epilogo.creditos.01", "epilogo.lapiz.titulo", "epilogo.lapiz.encabezado",
			"epilogo.lapiz.nada", "epilogo.lapiz.firma_tirese", "epilogo.lapiz.firma_corrijase"]:
		if not tx.has(k):
			_f("falta " + k)
	var nc := 0
	while tx.has("epilogo.creditos.%02d" % (nc + 1)):
		nc += 1
	for k in tx:
		if String(k).begins_with("epilogo.creditos.") and int(String(k).get_slice(".", 2)) > nc:
			_f("créditos no contiguos: " + k)
	print("epilogo.json: %d claves, %d palabras, %d créditos" % [tx.size(), words, nc])
	# ecos que el epílogo retoma de D21, D01N y D38 (si alguien edita una punta, que no quede suelta)
	var d21 := _plain(r, "D21")
	var echoes := [
		[d21.contains("no queda nada que concordar"), String(tx.get("epilogo.13.tijera", "")).contains("no quedaba nada que concordar"), "D21#fin ↔ 13.tijera"],
		[d21.contains("las fechas cierran"), String(tx.get("epilogo.14.ficha", "")).contains("Las fechas cierran"), "D21#fina_fecha ↔ 14.ficha"],
		[d21.contains("lo llama James; sic"), String(tx.get("epilogo.05.hueco", "")).contains("mi James"), "D21#twis_james ↔ 05.hueco"],
		[_plain(r, "D01N").contains("mi James"), String(tx.get("epilogo.10.duelo", "")).contains("mi James"), "D01N#mi_james ↔ 10.duelo"],
		[_plain(r, "D38").contains("anteojos de color"), String(tx.get("epilogo.04.park_lane", "")).contains("anteojos de color"), "D38#hombre_alto ↔ 04.park_lane"],
	]
	for e in echoes:
		if not (e[0] and e[1]):
			_f("eco roto: %s (%s, %s)" % [e[2], e[0], e[1]])

func _plain(r, id: String) -> String:
	var s := ""
	for p in r.doc(id).get("parts", []):
		s += String(r.parsed(id, String(p.id)).get("plain", "")) + "\n"
	return s
