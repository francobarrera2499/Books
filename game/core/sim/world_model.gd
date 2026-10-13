# core/sim/world_model.gd — el mundo que el jugador toca: ejemplares, accesibilidad, visitas, láminas, documentos
# runtime, bandeja, líneas dichas, huevos (§3.3, §3.7, §4.4, §4.11). Dueño: W2-SIM. Contrato: ARCHITECTURE §3.8.
# No precarga clock.gd (evita ciclos): lee st.clock directamente.
#
# st.world (formatos, para lectores de otros paquetes):
#   visit: {} | {id:"S.L4.3.M", place, area, day, slot, tk, act, hour, seat, free, plate:"PL.L4.3.M", scene:"" | id,
#               chars:[{id,pose,trait}], lines:[uid], auto_pending:[scene ids]}
#   visits: ["S.L4.3.M", ...]                     (Cond `visited`)
#   plates: {"PL.L4.3.M": snapshot, "PL.prologo": snapshot}   snapshot = q_plate (§3.7) + act, hour, fixed
#   docs: {"R.HA1.1": {id, rid, tpl, blocks:[{text, act, rid}], meta:{title, src_type, class, font, machine, paper,
#          paper_mm, measure, firma, ...}, origin, created_tk, delivered, how, where:"tray"|"insert", in_doc, day}}
#   inserts: {"D15.0330": {"p2": ["R.HC10.1", ...]}}  bloques runtime agregados a un número del Times. q_view los compone
#            DENTRO del bloque de esa parte (sin renglón en blanco), entre los avisos y nunca al pie (_merge_inserts); el
#            bloque lleva segs [{from, to, doc}] con el documento runtime de cada tramo insertado (Clipper.seg_block).
#   tray: [{view, tk, day, slot, how}]           how: correo | en_mano | mostrador_crane | diario | columna | noticias
#   copies: {copy_id: {state:"retirada"|"arrancada", from_tk, until_tk (-1 = permanente)}}
#   closures: [{target:"L4.consulta"|"L5"|"canal:K-H", from_tk, until_tk}]
#   silhouettes: {who: {from_day, until_day}}    place_variants: {place: variant}
#   lines: {uid: {uid, id, who, text, scene, origin, place, tk, act}}   (líneas dichas; clip src kind "line")
#   acts: {"act.12": {id, kind:"act_ref", label, type, tk, seq}}        (entidad runtime del acto, §3.6)
#   slips: {visit_id: [copy ids | "~<doc o rótulo>" (papeleta gastada sin ejemplar)]}  questions: {visit_id: {char: n}}  mem_clips: {visit_id: n}  orders: {doc: {tk, arrives_tk}}
#   eggs: {EEid: {tk, visit}}  outbox: [eventos telegram/letter pendientes]  diary: [...] (Diary)  tutorial: {} (Tutorial)
#   seat: int  coins_d: int  lines_seen: {uid: true} (líneas de st.scenes.lines ya pasadas al diario)  eggs_sig: String
# API para Effects (W2-REACT; vía load() si su capa no puede precargar sim): instantiate_doc, deliver, withdraw_copy,
#   return_copy, close, set_place_variant, add_silhouette, remove_silhouette, add_coins.
# Además se respeta el estado de mundo de Effects (st.react.world, sus accesores): retiros y páginas arrancadas,
#   cierres de acceso, variantes de lugar, siluetas, nodos de rastro y líneas extra de escena.
# Líneas dichas por Dialogue/Confrontation (W2-SCENES, st.scenes.lines): sync_scene_lines las lleva al diario y a la visita.
# Anuncio publicado: print_ad lo imprime en la columna del Times de ese día (Composers.ad_markup) -> fragmento AD:<n>.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const Cond = preload("res://core/util/cond.gd")
const Det = preload("res://core/util/det.gd")
const L = preload("res://core/util/log.gd")
const Markup = preload("res://core/text/markup.gd")
const Diary = preload("res://core/sim/diary.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Effects = preload("res://core/react/effects.gd")
const Composers = preload("res://core/scenes/composers.gd")

const HOME := "L1"
# holder de un ejemplar (§4.4) -> lugar donde se lee. Los holders L2..L8 son su propio lugar.
const HOLDER_PLACE := {"L1": "L1", "tomo": "L1", "Crane": "L1", "BM": "L2"}
const SLIPS_PER_VISIT := 3
const MEMORY_CLIPS := 3

static func init_state(st, repo) -> void:
	var money: Dictionary = repo.schedule().get("money_d", {})
	st.world = {"visit": {}, "visits": [], "plates": {}, "docs": {}, "inserts": {}, "tray": [], "copies": {}, "closures": [],
		"silhouettes": {}, "place_variants": {}, "diary": [], "questions": {}, "slips": {}, "seat": 0, "mem_clips": {},
		"orders": {}, "outbox": [], "tutorial": {}, "eggs": {}, "coins_d": int(money.get("guinea", 252)), "acts": {}, "lines": {}}

# Prólogo: archiva la lámina fija del prólogo (origin PL.prologo) y dice las líneas de la escena PRO que no son del
# tutorial (ids "t_*": las dice el tutorial al llegar a su paso).
static func start_prologue(st, repo) -> void:
	var pid := _fixed_plate_for_origin(repo, "PL.prologo")
	if pid != "":
		archive_fixed_plate(st, repo, pid, "PL.prologo")
	var sc: Dictionary = repo.scene("PRO")
	if sc.is_empty():
		return
	st.world.visit = {"id": String(sc.get("origin", "S.PRO")), "scene": "PRO", "place": String(sc.get("place", HOME)),
		"area": String(sc.get("area", "")), "day": int(st.clock.day), "slot": String(st.clock.slot), "tk": _now(st),
		"chars": _scene_chars(repo, sc), "lines": [], "plate": "PL.prologo" if pid != "" else "", "auto_pending": [],
		"extra_n": Effects.scene_extra(st, "PRO").size()}
	for ln in scene_lines(st, repo, "PRO"):
		if String(ln.id).begins_with("t_"):
			continue
		say_line(st, repo, ln)

# ---------------- tiempo y lugar ----------------
static func _now(st) -> int:
	if int(st.now_tk) >= 0:
		return int(st.now_tk)
	return TimeKey.tk(int(st.clock.get("day", 0)), String(st.clock.get("slot", "N")))

static func _day(st) -> int:
	return TimeKey.day_of(_now(st))

# {place, area}: dónde está Lisle (visita/escena en curso; si no, la buhardilla).
static func location(st) -> Dictionary:
	var v = st.world.get("visit", {})
	if typeof(v) == TYPE_DICTIONARY and not v.is_empty():
		return {"place": String(v.get("place", HOME)), "area": String(v.get("area", ""))}
	if String(st.clock.get("phase", "")) == "done":
		return {"place": "", "area": ""}
	return {"place": HOME, "area": ""}

static func _area_free(repo, place: String, area: String) -> bool:
	var sp = repo.schedule().get("places", {}).get(place, {})
	if typeof(sp) != TYPE_DICTIONARY:
		return false
	var a = sp.get("areas", {}).get(area, {})
	return typeof(a) == TYPE_DICTIONARY and bool(a.get("free", false))

static func place_needs_seat(repo, place: String) -> bool:
	return HOLDER_PLACE.get("BM", "") == place

static func holder_place(holder: String) -> String:
	return String(HOLDER_PLACE.get(holder, holder))

# ---------------- cierres, retiros y variantes (API de efectos) ----------------
static func closed(st, place: String, area: String, t: int) -> bool:
	var day := TimeKey.day_of(t)
	if Effects.access_closed(st, place + "." + area, day) or Effects.access_closed(st, place, day):
		return true
	for c in st.world.get("closures", []):
		var tg := String(c.get("target", ""))
		if tg != place and tg != place + "." + area:
			continue
		var f := int(c.get("from_tk", -1))
		var u := int(c.get("until_tk", -1))
		if t >= f and (u < 0 or t <= u):
			return true
	return false

static func close(st, target: String, from_tk: int, until_tk := -1) -> void:
	st.world.closures.append({"target": target, "from_tk": from_tk, "until_tk": until_tk})
	st.note("visit", {"closed": target})

static func withdraw_copy(st, copy_id: String, until_tk := -1, kind := "retirada") -> void:
	st.world.copies[copy_id] = {"state": kind, "from_tk": _now(st), "until_tk": until_tk}
	st.note("tray", {"withdrawn": copy_id})

static func return_copy(st, copy_id: String) -> void:
	if st.world.copies.has(copy_id):
		st.world.copies.erase(copy_id)
		st.note("tray", {"returned": copy_id})

static func set_place_variant(st, place: String, variant: String) -> void:
	st.world.place_variants[place] = variant

static func add_silhouette(st, who: String, from_day: int, until_day := -1) -> void:
	st.world.silhouettes[who] = {"from_day": from_day, "until_day": until_day}

static func remove_silhouette(st, who: String) -> void:
	st.world.silhouettes.erase(who)

static func add_coins(st, d: int) -> void:
	st.world.coins_d = maxi(0, int(st.world.get("coins_d", 0)) + d)

# ---------------- ejemplares y accesibilidad ----------------
# Retiro propio (withdraw_copy) o de Effects (st.react.world: retirar M1/HB5, arrancar M5).
static func copy_withdrawn(st, copy_id: String, t: int) -> bool:
	if Effects.copy_withdrawn(st, copy_id, t) or Effects.torn(st, copy_id):
		return true
	var c = st.world.get("copies", {}).get(copy_id)
	if typeof(c) != TYPE_DICTIONARY:
		return false
	var u := int(c.get("until_tk", -1))
	return t >= int(c.get("from_tk", -1)) and (u < 0 or t <= u)

# Ventana from/to del ejemplar y sin retiro (independiente de dónde esté Lisle).
static func copy_available(st, repo, copy_id: String, t: int) -> bool:
	var cp: Dictionary = repo.copy(copy_id)
	if cp.is_empty():
		return false
	var c: Dictionary = cp.copy
	if c.has("from") and t < TimeKey.of(c.from):
		return false
	if c.has("to") and t > TimeKey.of(c.to):
		return false
	return not copy_withdrawn(st, copy_id, t)

static func copy_in_window(repo, copy_id: String, t: int) -> bool:
	var cp: Dictionary = repo.copy(copy_id)
	if cp.is_empty():
		return false
	var c: Dictionary = cp.copy
	return not ((c.has("from") and t < TimeKey.of(c.from)) or (c.has("to") and t > TimeKey.of(c.to)))

# ¿La ficha del catálogo de la Sala de Lectura lista este documento en t? Sí si no tiene ejemplar en la Biblioteca
# (se lista «No se presta») o si alguno de sus ejemplares BM está dentro de su ventana from/to.
static func catalog_listed(repo, did: String, t: int) -> bool:
	var bm: Array = []
	for c in repo.doc(did).get("copies", []):
		if String(c.get("holder", "")) == "BM":
			bm.append(String(c.get("id", "")))
	if bm.is_empty():
		return true
	for cid in bm:
		if copy_in_window(repo, cid, t):
			return true
	return false

static func copy_accessible(st, repo, copy_id: String) -> bool:
	var t := _now(st)
	if not copy_available(st, repo, copy_id, t):
		return false
	var c: Dictionary = repo.copy(copy_id).copy
	var holder := String(c.get("holder", ""))
	var loc := location(st)
	var here := holder_place(holder)
	if loc.place != here:
		return false
	match holder:
		"L1", "tomo":
			return true
		"Crane":
			# en la tienda; el día fijo (confrontación e informe final) Lisle está abajo o a un tramo de escalera
			return _area_free(repo, HOME, loc.area) or ["confront", "final_report"].has(String(st.clock.get("phase", "")))
		"BM":
			var v: Dictionary = st.world.get("visit", {})
			return (st.world.get("slips", {}).get(String(v.get("id", "")), []) as Array).has(copy_id)
	var ca := String(c.get("area", ""))
	return ca == "" or ca == "*" or ca == loc.area

static func instance_accessible(st, iid: String) -> bool:
	var d = st.world.get("docs", {}).get(iid)
	if typeof(d) != TYPE_DICTIONARY or not bool(d.get("delivered", false)) or String(d.get("where", "")) != "tray":
		return false
	# los originales recibidos también pueden faltar (M1 retira «esos originales»; Effects o withdraw_copy)
	if copy_withdrawn(st, iid, _now(st)):
		return false
	return location(st).place == HOME

static func view_accessible(st, repo, view: String) -> bool:
	if st.world.get("docs", {}).has(view):
		return instance_accessible(st, view)
	return copy_accessible(st, repo, view)

# [{view, doc, title, holder, via}] legible ahora (orden por view).
static func accessible(st, repo) -> Array:
	var out: Array = []
	var dids: Array = repo.docs().keys()
	dids.sort()
	for did in dids:
		var d: Dictionary = repo.doc(did)
		for c in d.get("copies", []):
			var cid := String(c.get("id", ""))
			if cid != "" and copy_accessible(st, repo, cid):
				out.append({"view": cid, "doc": did, "title": String(d.get("title", "")), "holder": String(c.get("holder", "")), "via": String(c.get("via", ""))})
	var iids: Array = st.world.get("docs", {}).keys()
	iids.sort()
	for iid in iids:
		if instance_accessible(st, iid):
			var m: Dictionary = st.world.docs[iid].get("meta", {})
			out.append({"view": iid, "doc": iid, "title": String(m.get("title", "")), "holder": HOME, "via": String(st.world.docs[iid].get("how", ""))})
	out.sort_custom(func(a, b): return String(a.view) < String(b.view))
	return out

# ---------------- vista de lectura (q_view) ----------------
static func view(st, repo, p_view: String) -> Dictionary:
	if not view_accessible(st, repo, p_view):
		return {}
	return view_any(st, repo, p_view)

# Igual que view() pero sin exigir accesibilidad (recortes ya tomados, devtools).
static func view_any(st, repo, p_view: String) -> Dictionary:
	if st.world.get("docs", {}).has(p_view):
		return _instance_view(st, repo, p_view)
	var cp: Dictionary = repo.copy(p_view)
	if cp.is_empty():
		return {}
	var did := String(cp.doc)
	var d: Dictionary = repo.doc(did)
	var t := _now(st)
	var pages: Array = []
	var origin := String(d.get("origin", did))
	var ins: Dictionary = st.world.get("inserts", {}).get(did, {})
	for p in d.get("parts", []):
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if p.has("when") and not Cond.eval(p.when, {"st": st, "repo": repo, "tk": t}):
			continue
		var pid := String(p.get("id", ""))
		var base: Dictionary = repo.parsed(did, pid)
		var iids: Array = ins.get(pid, [])
		if iids.is_empty():
			pages.append([{"doc": did, "origin": origin, "copy": p_view, "part": pid, "parsed": base}])
			continue
		# Lo que el mundo agrega a la columna o a las noticias se compone DENTRO de la parte (un solo bloque, sin
		# renglón en blanco), en un lugar determinista entre los avisos del día (nunca al pie): segs dice de qué
		# documento runtime es cada tramo insertado (Clipper lo usa para el recorte).
		var mg := _merge_inserts(st, repo, d, pid, base, iids)
		pages.append([{"doc": did, "origin": origin, "copy": p_view, "part": pid, "parsed": mg.parsed, "segs": mg.segs}])
	var cls := String(cp.copy.get("class", d.get("class", "I")))
	var out := {"view": p_view, "doc": did, "title": String(d.get("title", "")), "src_line": src_line(repo, d, {}),
		"paper": d.get("paper", ""), "paper_mm": d.get("paper_mm", null), "font": d.get("font", "imprenta"),
		"machine": d.get("machine", null), "class": cls, "measure": d.get("measure", null), "pages": pages}
	if d.has("plate") and d.plate != null:
		out["plate"] = d.plate
	return out

static func _instance_view(st, repo, iid: String) -> Dictionary:
	var inst: Dictionary = st.world.docs[iid]
	var m: Dictionary = inst.get("meta", {})
	var blocks: Array = []
	for b in inst.get("blocks", []):
		blocks.append({"doc": iid, "origin": String(inst.get("origin", iid)), "copy": iid, "part": "p1", "parsed": _parse_block(repo, b)})
	var firma := String(m.get("firma", ""))
	if firma != "" and not bool(m.get("firma_in_text", false)):
		var ft := firma if firma.begins_with("—") else "—" + firma
		blocks.append({"doc": iid, "origin": String(inst.get("origin", iid)), "copy": iid, "part": "p1", "parsed": repo.parse_text(Markup.escape(ft)), "firma": true})
	var pages: Array = [blocks]
	# copia oficial de un documento (meta.copia_de): una página por parte del original, después de la portada
	var cdoc := String(m.get("copia_de", ""))
	var od: Dictionary = repo.doc(cdoc) if cdoc != "" else {}
	if not od.is_empty():
		var ctx := {"st": st, "repo": repo, "tk": _now(st)}
		var org := String(od.get("origin", cdoc))
		var chron = od.get("chron_date", "")
		for p in od.get("parts", []):
			if typeof(p) != TYPE_DICTIONARY:
				continue
			if p.has("when") and not Cond.eval(p.when, ctx):
				continue
			var pid := String(p.get("id", ""))
			pages.append([{"doc": iid, "origin": org, "copy": iid, "part": "copia." + pid, "cls": "P", "chron_date": String(chron) if chron != null else "",
				"parsed": repo.parsed(cdoc, pid)}])
	return {"view": iid, "doc": iid, "title": String(m.get("title", "")), "src_line": src_line(repo, m, {"day": int(inst.get("day", 0))}),
		"paper": m.get("paper", "carta"), "paper_mm": m.get("paper_mm", null), "font": m.get("font", "maquina"),
		"machine": m.get("machine", null), "class": String(m.get("class", "P")), "measure": m.get("measure", null), "pages": pages}

static func _parse_block(repo, b: Dictionary) -> Dictionary:
	return repo.parse_text(String(b.get("text", "")), {}, String(b.get("act", "")))

# ---------------- inserciones en un número del Times (§12.2, GDD §9.9 «nada brilla») ----------------
# Lugar de cada inserción: unidades = renglones con tramo (columna: cada aviso; noticias: cada renglón que abre con
# versalitas). Se inserta ANTES de la unidad k, k en [lo, hi]: columna = después del tercer aviso y antes del
# penúltimo (nunca junto a DINERO, que cierra todos los días); noticias = después de la primera y nunca después de
# «El tiempo.». k sale de Det.h32(semilla, número, id): fijo para la partida, distinto entre partidas y avisos.
const INSERT_SKIP := {"columna": 3, "noticias": 1}
const INSERT_TAIL := {"columna": 2, "noticias": 1}

static func _insert_how(d: Dictionary, pid: String) -> String:
	var im = d.get("inserts", {})
	if typeof(im) == TYPE_DICTIONARY:
		for k in im:
			if String(im[k]) == pid:
				return String(k)
	for p in d.get("parts", []):
		if typeof(p) == TYPE_DICTIONARY and typeof(p.get("inserts")) == TYPE_DICTIONARY:
			for k in p.inserts:
				if String(p.inserts[k]) == pid:
					return String(k)
	return "columna"

# Inicio (índice en plain) de cada unidad de la parte.
static func insert_units(parsed: Dictionary, how: String) -> Array:
	var plain := String(parsed.get("plain", ""))
	var starts: Array = [0]
	for i in plain.length():
		if plain[i] == "\n":
			starts.append(i + 1)
	var out: Array = []
	for li in starts.size():
		var a: int = starts[li]
		var b: int = (starts[li + 1] - 1) if li + 1 < starts.size() else plain.length()
		if b <= a:
			continue
		var has_tramo := false
		for tr in parsed.get("tramos", []):
			if int(tr.from) < b and int(tr.to) > a:
				has_tramo = true
				break
		if not has_tramo:
			continue   # encabezado («Anuncios personales») o renglón sin contenido propio
		if how == "noticias":
			var opens_sc := false
			for s in parsed.get("styles", []):
				if String(s.get("kind", "")) == "sc" and int(s.from) == a:
					opens_sc = true
					break
			if not opens_sc:
				continue   # continuación de una noticia (la indagatoria del 3 de abril)
		out.append(a)
	return out

static func insert_pos(st, units: Array, how: String, did: String, iid: String, plain_len: int) -> int:
	var m := units.size()
	if m == 0:
		return plain_len
	var lo := mini(int(INSERT_SKIP.get(how, 3)), m - 1)
	var hi := maxi(lo, m - int(INSERT_TAIL.get(how, 2)))
	var k := lo + Det.h32([int(st.seed), "inserto", did, iid]) % (hi - lo + 1)
	return int(units[k])

static func _merge_inserts(st, repo, d: Dictionary, pid: String, base: Dictionary, iids: Array) -> Dictionary:
	var how := _insert_how(d, pid)
	var did := String(d.get("id", ""))
	var units := insert_units(base, how)
	var plain_len := String(base.get("plain", "")).length()
	# [pos en base, orden de entrega, iid, bloque parseado]
	var items: Array = []
	var order := 0
	for iid in iids:
		var inst: Dictionary = st.world.docs.get(String(iid), {})
		var pos := insert_pos(st, units, how, did, String(iid), plain_len)
		for b in inst.get("blocks", []):
			var bb: Dictionary = b.duplicate()
			var tx := String(bb.get("text", "")).strip_edges()
			while tx.contains("\n\n"):
				tx = tx.replace("\n\n", "\n")
			bb["text"] = tx
			if tx == "":
				continue
			items.append({"pos": pos, "n": order, "iid": String(iid), "parsed": _parse_block(repo, bb)})
			order += 1
	# de atrás hacia adelante: cada inserción sólo corre lo que queda después de ella; a igual lugar, el orden de entrega
	# (al final, sin corrimiento, va en orden directo)
	items.sort_custom(func(x, y): return x.pos > y.pos or (x.pos == y.pos and ((x.n > y.n) if x.pos < plain_len else (x.n < y.n))))
	var cur: Dictionary = base
	var segs: Array = []
	for it in items:
		# al final (parte sin unidades): siempre al final del texto ya armado, en orden de entrega
		var at: int = int(it.pos) if int(it.pos) < plain_len else String(cur.get("plain", "")).length()
		var sp := splice_parsed(cur, at, it.parsed)
		cur = sp.parsed
		for sg in segs:
			if int(sg.from) >= at:
				sg.from = int(sg.from) + int(sp.shift)
				sg.to = int(sg.to) + int(sp.shift)
		segs.append({"from": int(sp.from), "to": int(sp.to), "doc": String(it.iid)})
	segs.sort_custom(func(x, y): return int(x.from) < int(y.from))
	return {"parsed": cur, "segs": segs}

# Inserta el texto parseado `ins` en `base` al comienzo del renglón `at` (o al final, en renglón propio).
# -> {parsed, from, to (lo insertado en el nuevo plain), shift (cuánto se corrió lo que seguía)}
static func splice_parsed(base: Dictionary, at: int, ins: Dictionary) -> Dictionary:
	var bp := String(base.get("plain", ""))
	var ip := String(ins.get("plain", ""))
	var plain := ""
	var off := 0
	var shift := 0
	if at >= bp.length():
		at = bp.length()
		var lead := "\n" if bp != "" and not bp.ends_with("\n") else ""
		plain = bp + lead + ip
		off = at + lead.length()
	else:
		plain = bp.substr(0, at) + ip + "\n" + bp.substr(at)
		off = at
		shift = ip.length() + 1
	var out := {"plain": plain}
	for key in ["mentions", "tramos", "styles"]:
		var arr: Array = []
		for x in base.get(key, []):
			var y: Dictionary = x.duplicate(true)
			if int(y.from) >= at:
				y.from = int(y.from) + shift
				y.to = int(y.to) + shift
			elif int(y.to) > at:
				y.to = int(y.to) + shift
			arr.append(y)
		for x in ins.get(key, []):
			var y: Dictionary = x.duplicate(true)
			y.from = int(y.from) + off
			y.to = int(y.to) + off
			arr.append(y)
		arr.sort_custom(func(p, q): return int(p.from) < int(q.from) or (int(p.from) == int(q.from) and int(p.to) > int(q.to)))
		out[key] = arr
	for key in ["sentences", "words"]:
		var arr2: Array = []
		for x in base.get(key, []):
			if int(x[0]) >= at:
				arr2.append([int(x[0]) + shift, int(x[1]) + shift])
			else:
				arr2.append([int(x[0]), int(x[1])])
		for x in ins.get(key, []):
			arr2.append([int(x[0]) + off, int(x[1]) + off])
		arr2.sort_custom(func(p, q): return int(p[0]) < int(q[0]))
		out[key] = arr2
	var errs: Array = (base.get("errors", []) as Array).duplicate()
	errs.append_array(ins.get("errors", []))
	out["errors"] = errs
	return {"parsed": out, "from": off, "to": off + ip.length(), "shift": shift}

# Bloque de una vista (lo usa el recorte): part = índice de página (int) o id de parte; block = índice en la página.
static func block(st, repo, p_view: String, part, blk: int) -> Dictionary:
	var v := view_any(st, repo, p_view)
	if v.is_empty():
		return {}
	var pages: Array = v.pages
	var pi := -1
	if typeof(part) in [TYPE_INT, TYPE_FLOAT]:
		pi = int(part)
	else:
		for i in pages.size():
			if pages[i].size() > 0 and String(pages[i][0].get("part", "")) == String(part):
				pi = i
				break
	if pi < 0 or pi >= pages.size() or blk < 0 or blk >= pages[pi].size():
		return {}
	return pages[pi][blk]

# Línea de fuente (GDD§8.1): «título · tipo» en palabras de época.
static func src_line(repo, d: Dictionary, vars: Dictionary) -> String:
	var types: Dictionary = repo.lists().get("src_types", {})
	var tipo := Markup.fill(String(types.get(String(d.get("src_type", "")), "")), vars)
	var title := String(d.get("title", ""))
	if tipo == "" or tipo.contains("${"):
		return title
	return repo.text("sim.src_line", {"titulo": title, "tipo": tipo})

# ---------------- documentos runtime ----------------
# Dos formas de llamada:
#   (a) tpl = plantilla de rastro {tpl, texto, tags?}; meta = {rid, iid?, prefix?, act?, doc:{title, src_type, …}, origin?,
#       merge_into?}. El texto se rellena con vars.
#   (b) tpl = documento armado (Effects.doc_tpl de W2-REACT): {title, src_type, class, font, machine?, paper, paper_mm,
#       measure?, entity, origin, insert?, firma, parts:[{id, text}], …}; meta = {iid, rid, act, how, origin, …}. El texto
#       ya trae los bloques fusionados y la firma.
# Devuelve el id de la instancia ("R.HA1.1"; prefix "AD"/"TG"/"LT"/"RP" para anuncios, telegramas…).
const DOC_META_SKIP := ["parts", "copies", "words", "src_en", "id", "origin", "texto", "text", "tpl", "tags", "when", "tono", "nodo"]

static func instantiate_doc(st, repo, tpl: Dictionary, vars: Dictionary, meta: Dictionary) -> String:
	var built := typeof(tpl.get("parts")) == TYPE_ARRAY
	var src := ""
	if built:
		for p in tpl.parts:
			if typeof(p) == TYPE_DICTIONARY:
				src += ("\n\n" if src != "" else "") + String(p.get("text", ""))
	else:
		src = String(tpl.get("texto", tpl.get("text", "")))
	var text := contract(repo, Markup.fill(src, vars))
	var blk := {"text": text, "act": String(meta.get("act", "")), "rid": String(meta.get("rid", "")), "tpl": String(tpl.get("tpl", ""))}
	var into := String(meta.get("merge_into", ""))
	if into != "" and st.world.docs.has(into):
		st.world.docs[into].blocks.append(blk)
		return into
	var iid := String(meta.get("iid", ""))
	if iid == "" or st.world.docs.has(iid):
		var prefix := String(meta.get("prefix", "R." + String(meta.get("rid", "X"))))
		iid = prefix + "." + str(int(st.seq.get("inst." + prefix, 0)) + 1)
		st.seq["inst." + prefix] = int(st.seq.get("inst." + prefix, 0)) + 1
	var dm := {}
	if built:
		for k in tpl:
			if not DOC_META_SKIP.has(String(k)):
				dm[String(k)] = tpl[k].duplicate(true) if typeof(tpl[k]) in [TYPE_ARRAY, TYPE_DICTIONARY] else tpl[k]
		dm["firma_in_text"] = true
	elif typeof(meta.get("doc")) == TYPE_DICTIONARY:
		dm = meta.doc.duplicate(true)
	var origin := String(meta.get("origin", tpl.get("origin", iid) if built else iid))
	if origin == "":
		origin = iid
	# copia_de (Effects, p. ej. L6copia): el sobre trae además una copia P del documento pedido. Sus páginas se leen y se
	# recortan desde la instancia (sin tope «de memoria»), con el origen del documento original y su entidad como
	# entidad de recorte (enlace por claves).
	var cdoc := String(meta.get("copia_de", ""))
	if cdoc != "" and not repo.doc(cdoc).is_empty():
		var od: Dictionary = repo.doc(cdoc)
		dm["copia_de"] = cdoc
		var ce: Array = (dm.get("clip_entities", []) as Array).duplicate() if typeof(dm.get("clip_entities")) == TYPE_ARRAY else []
		for e in [od.get("entity", "")] + (od.get("clip_entities", []) if typeof(od.get("clip_entities")) == TYPE_ARRAY else []):
			if String(e) != "" and not ce.has(String(e)):
				ce.append(String(e))
		dm["clip_entities"] = ce
		if typeof(od.get("visible_cats")) == TYPE_ARRAY and not (od.visible_cats as Array).is_empty():
			dm["visible_cats"] = (od.visible_cats as Array).duplicate()
	st.world.docs[iid] = {"id": iid, "rid": String(meta.get("rid", "")), "tpl": String(tpl.get("tpl", "")), "blocks": [blk],
		"meta": dm, "origin": origin, "created_tk": _now(st), "delivered": false, "how": "",
		"where": "", "in_doc": "", "day": _day(st)}
	return iid

# how: correo | en_mano | mostrador_crane -> bandeja (+ línea «Recibido» del diario); columna | noticias -> se inserta en
# el Times del día (si ese número no existe, cae en la bandeja).
static func deliver(st, repo, p_view: String, how: String) -> void:
	var d = st.world.docs.get(p_view)
	if typeof(d) != TYPE_DICTIONARY:
		if not repo.copy(p_view).is_empty():
			# ejemplar estático devuelto (HB10 «devolver» los originales que retiró M1): vuelve a la bandeja con su sello;
			# se lee donde siempre (su holder), ya sin retiro.
			var t0 := _now(st)
			st.world.tray.append({"view": p_view, "tk": t0, "day": TimeKey.day_of(t0), "slot": TimeKey.slot_of(t0), "how": how})
			Diary.on_arrival(st, repo, p_view)
			st.note("tray", {"view": p_view, "how": how})
			return
		L.bug("world", "deliver de una instancia inexistente: " + p_view)
		return
	var t := _now(st)
	d.delivered = true
	d.how = how
	d.day = TimeKey.day_of(t)
	if how == "columna" or how == "noticias":
		var tid := times_doc(repo, TimeKey.day_of(t))
		var ins = d.get("meta", {}).get("insert", {})
		if typeof(ins) == TYPE_DICTIONARY and not repo.doc(String(ins.get("doc", ""))).is_empty():
			tid = String(ins.doc)
		if tid != "":
			var part := _insert_part(repo.doc(tid), how)
			if part != "":
				if not st.world.inserts.has(tid):
					st.world.inserts[tid] = {}
				if not st.world.inserts[tid].has(part):
					st.world.inserts[tid][part] = []
				st.world.inserts[tid][part].append(p_view)
				d.where = "insert"
				d.in_doc = tid
				st.note("tray", {"view": p_view, "how": how})
				return
	d.where = "tray"
	st.world.tray.append({"view": p_view, "tk": t, "day": TimeKey.day_of(t), "slot": TimeKey.slot_of(t), "how": how})
	Diary.on_arrival(st, repo, p_view)
	st.note("tray", {"view": p_view, "how": how})

# Número del Times de un día: doc "D15.<MMDD>" según schedule.days[].date.
static func times_doc(repo, day: int) -> String:
	for d in repo.schedule().get("days", []):
		if int(d.get("day", -1)) == day:
			var date := String(d.get("date", ""))
			if date.length() >= 10:
				var id := "D15." + date.substr(5, 2) + date.substr(8, 2)
				if not repo.doc(id).is_empty():
					return id
	return ""

static func _insert_part(d: Dictionary, how: String) -> String:
	var parts: Array = d.get("parts", [])
	if typeof(d.get("inserts")) == TYPE_DICTIONARY and d.inserts.has(how):
		return String(d.inserts[how])
	for p in parts:
		if typeof(p) == TYPE_DICTIONARY and typeof(p.get("inserts")) == TYPE_DICTIONARY and p.inserts.has(how):
			return String(p.inserts[how])
	if parts.size() > 0:
		return String(parts[-1].get("id", ""))
	return ""

# Llegadas estáticas al cruzar t: ejemplares de L1 (via desk) con from == t van a la bandeja; al amanecer, la guinea.
static func arrivals_at(st, repo, t: int) -> int:
	var n := 0
	var dids: Array = repo.docs().keys()
	dids.sort()
	for did in dids:
		var d: Dictionary = repo.doc(did)
		for c in d.get("copies", []):
			if String(c.get("holder", "")) != HOME or String(c.get("via", "")) != "desk" or not c.has("from"):
				continue
			if TimeKey.of(c.from) != t or t <= TimeKey.tk(TimeKey.DAY_P, "N"):
				continue
			var how := "diario" if String(d.get("src_type", "")) == "prensa_londres" else "correo"
			st.world.tray.append({"view": String(c.id), "tk": t, "day": TimeKey.day_of(t), "slot": TimeKey.slot_of(t), "how": how})
			Diary.on_arrival(st, repo, String(c.id))
			st.note("tray", {"view": String(c.id), "how": how})
			n += 1
	if TimeKey.slot_of(t) == "dawn" and TimeKey.day_of(t) >= 1 and TimeKey.day_of(t) < TimeKey.DAY_E:
		add_coins(st, int(repo.schedule().get("money_d", {}).get("guinea", 252)))
	return n

# Texto armado con ${…}: lists.contracciones en orden («a el» -> «al», «..» -> «.»), con borde de palabra
# (Markup.contract: «para el» no se vuelve «paral»).
static func contract(repo, s: String) -> String:
	return Markup.contract(s, repo.lists().get("contracciones", []))

# ---------------- visitas, escenas y láminas ----------------
static func start_visit(st, repo, place: String, area: String, opts := {}) -> Dictionary:
	var day := int(st.clock.day)
	var slot := String(st.clock.slot)
	var t := TimeKey.tk(day, slot)
	var base := "%s.%d.%s" % [place, day, slot]
	var vid := "S." + base
	var pid := "PL." + base
	var k := 2
	while (st.world.visits as Array).has(vid) or st.world.plates.has(pid):
		vid = "S.%s.%d" % [base, k]
		pid = "PL.%s.%d" % [base, k]
		k += 1
	var snap := snapshot(st, repo, place, area, place_variant(st, place))
	snap["id"] = pid
	snap["act"] = String(opts.get("act", ""))
	snap["hour"] = String(opts.get("hour", ""))
	st.world.plates[pid] = snap
	var chars: Array = (snap.chars as Array).duplicate(true)
	var psil = repo.place(place).get("silhouettes", {})
	for sil in snap.silhouettes:
		var who := String(sil).substr(4)
		if not sil_talks(psil, who, area):
			continue   # W4: en un interior la silueta se ve por la ventana, sin panel (silhouettes.<who>.talk)
		if not repo.dialogue(who).is_empty():
			chars.append({"id": who, "pose": "de_pie", "trait": String(repo.dialogue(who).get("trait", "")), "sil": true})
	var auto: Array = []
	var sids: Array = repo.scenes().keys()
	sids.sort()
	for sid in sids:
		var sc: Dictionary = repo.scene(sid)
		if not bool(sc.get("auto", false)) or String(sc.get("place", "")) != place:
			continue
		var sa := String(sc.get("area", ""))
		if sa != "" and sa != "*" and sa != area:
			continue
		if sc.has("when") and not Cond.eval(sc.when, {"st": st, "repo": repo, "tk": t}):
			continue
		auto.append(sid)
	var visit := {"id": vid, "place": place, "area": area, "day": day, "slot": slot, "tk": t, "act": String(opts.get("act", "")),
		"hour": String(opts.get("hour", "")), "seat": int(opts.get("seat", 0)), "free": bool(opts.get("free", false)),
		"plate": pid, "scene": "", "chars": chars, "lines": [], "auto_pending": auto}
	st.world.visit = visit
	st.world.visits.append(vid)
	st.note("visit", {"id": vid})
	return visit

# ¿Se le habla a la silueta <who> en esta área? silhouettes.<who>.talk = [áreas] (sin talk: en toda área).
static func sil_talks(psil, who: String, area: String) -> bool:
	if typeof(psil) != TYPE_DICTIONARY or typeof(psil.get(who)) != TYPE_DICTIONARY or not psil[who].has("talk"):
		return true
	var talk = psil[who].talk
	return typeof(talk) == TYPE_ARRAY and talk.has(area)

static func end_visit(st) -> void:
	if not st.world.get("visit", {}).is_empty():
		st.world.visit = {}
		st.note("visit", {})

# Líneas automáticas pendientes de la visita (se dicen después del evento del acto, para que el diario las ordene bien).
static func after_events(st, repo) -> void:
	var v: Dictionary = st.world.get("visit", {})
	if v.is_empty() or (v.get("auto_pending", []) as Array).is_empty():
		return
	var pend: Array = v.auto_pending
	v.auto_pending = []
	for sid in pend:
		say_scene_lines(st, repo, sid, String(v.get("id", "")))

# Escena fija (M6, M7, HC07, HC08, EPI…): la «visita» es la escena; dice sus líneas y archiva su lámina.
static func start_scene(st, repo, sid: String, opts := {}) -> Dictionary:
	var sc: Dictionary = repo.scene(sid)
	if sc.is_empty():
		return {}
	var origin := String(sc.get("origin", "S." + sid))
	var plate := String(sc.get("plate", ""))
	if plate != "":
		var fp := _fixed_plate_for_origin(repo, plate)
		if fp != "" and not st.world.plates.has(plate):
			archive_fixed_plate(st, repo, fp, plate)
		elif fp == "" and not st.world.plates.has(plate) and not repo.place(String(sc.get("place", ""))).is_empty():
			# lámina de un lugar del mapa en el momento de la escena (HC07: la tienda de Crane del día 10, con los nodos
			# del librero): instantánea del lugar y área, archivada con el id de la escena; su origen es el de una visita
			# (PL.<lugar>.<día>.<franja>, como RouteDB: PL.<lugar>).
			var place := String(sc.place)
			var snap := snapshot(st, repo, place, String(sc.get("area", "")), place_variant(st, place))
			snap["id"] = plate
			snap["origin"] = "PL.%s.%d.%s" % [place, int(st.clock.day), String(st.clock.slot)]
			snap["act"] = ""
			st.world.plates[plate] = snap
	var visit := {"id": origin, "scene": sid, "place": String(sc.get("place", HOME)), "area": String(sc.get("area", "")),
		"day": int(st.clock.day), "slot": String(st.clock.slot), "tk": _now(st), "act": "", "hour": "", "seat": 0,
		"free": true, "plate": plate if st.world.plates.has(plate) else "", "chars": _scene_chars(repo, sc), "lines": [], "auto_pending": [],
		"extra_n": Effects.scene_extra(st, sid).size()}
	st.world.visit = visit
	if not (st.world.visits as Array).has(origin):
		st.world.visits.append(origin)
	st.note("scene", {"id": sid})
	say_scene_lines(st, repo, sid, origin)
	# última línea propia de la escena (la despedida; las extras ya dichas van antes de ella, scene_lines): las líneas
	# que un efecto agregue después también van antes que ella (sync_scene_extra)
	var said: Array = visit.lines
	if said.size() - int(visit.extra_n) >= 2:
		visit["tail_uid"] = String(said[said.size() - 1])
	return visit

static func _scene_chars(repo, sc: Dictionary) -> Array:
	var out: Array = []
	var seen := {}
	for ln in sc.get("lines", []):
		var w := String(ln.get("who", ""))
		if w != "" and not seen.has(w):
			seen[w] = true
			out.append({"id": w, "pose": "de_pie", "trait": String(repo.dialogue(w).get("trait", ""))})
	return out

static func say_scene_lines(st, repo, sid: String, origin := "") -> void:
	var sc: Dictionary = repo.scene(sid)
	if sc.is_empty():
		return
	var org := origin if origin != "" else String(sc.get("origin", "S." + sid))
	for ln in scene_lines(st, repo, sid):
		var l2: Dictionary = ln.duplicate()
		l2["origin"] = org
		say_line(st, repo, l2)

# Líneas que un efecto agregó a la escena en curso DESPUÉS de empezarla (Effects.scene_extra): la «siguiente
# comunicación» de Moran (M10–M12) que el director resuelve en el mismo tk de M6 (amanecer) o M7 (22 h), cuando la
# escena ya se abrió. Se dicen una vez cada una (visit.extra_n = cuántas ya se dijeron) y se ubican antes de la última
# línea propia de la escena (visit.tail_uid: la despedida de Pell o de Harris), en la visita y en el diario: no
# llegan como un recado olvidado después del «bona fide».
static func sync_scene_extra(st, repo) -> void:
	var v: Dictionary = st.world.get("visit", {})
	if v.is_empty():
		return
	var sid := String(v.get("scene", ""))
	if sid == "":
		return
	var extra := Effects.scene_extra(st, sid)
	var n := int(v.get("extra_n", 0))
	if extra.size() <= n:
		return
	var who := ""
	for ln in repo.scene(sid).get("lines", []):
		if who == "" and typeof(ln) == TYPE_DICTIONARY and String(ln.get("who", "")) != "" and not String(ln.get("id", "")).begins_with("conf."):
			who = String(ln.who)
	var tail := String(v.get("tail_uid", ""))
	for i in range(n, extra.size()):
		var uid := say_line(st, repo, {"id": "extra.%d" % i, "who": who, "text": String(extra[i]), "scene": sid, "origin": String(v.get("id", ""))})
		if tail != "":
			_move_line_before(st, v, uid, tail)
	v["extra_n"] = extra.size()

static func _move_line_before(st, v: Dictionary, uid: String, tail: String) -> void:
	var said: Array = v.get("lines", [])
	if said.has(uid) and said.has(tail):
		said.erase(uid)
		said.insert(said.find(tail), uid)
	var dy: Array = st.world.get("diary", [])
	var iu := -1
	for i in dy.size():
		if String(dy[i].get("line", "")) == uid:
			iu = i
	if iu < 0:
		return
	var e = dy[iu]
	dy.remove_at(iu)
	for j in dy.size():
		if String(dy[j].get("line", "")) == tail:
			dy.insert(j, e)
			return
	dy.insert(iu, e)

# Una sola línea de una escena (líneas del tutorial "PRO.t_*"). "" si no existe.
static func say_scene_line(st, repo, sid: String, line_id: String) -> String:
	for ln in scene_lines(st, repo, sid):
		if String(ln.id) == line_id:
			return say_line(st, repo, ln)
	return ""

# Líneas vigentes de una escena: `when` de cada línea, variantes (replace/append) y líneas generadas (acts_by_channel).
static func scene_lines(st, repo, sid: String) -> Array:
	var sc: Dictionary = repo.scene(sid)
	var t := _now(st)
	var ctx := {"st": st, "repo": repo, "tk": t}
	var out: Array = []
	var origin := String(sc.get("origin", "S." + sid))
	if sc.has("when") and not Cond.eval(sc.when, ctx):
		return out
	for ln in sc.get("lines", []):
		if String(ln.get("id", "")).begins_with("conf."):
			continue   # líneas de la confrontación: las dice Confrontation paso a paso (W2-SCENES)
		if ln.has("when") and not Cond.eval(ln.when, ctx):
			continue
		if String(ln.get("gen", "")) == "acts_by_channel":
			out.append_array(_gen_acts_by_channel(st, repo, ln, sid, origin))
			continue
		out.append({"id": String(ln.id), "who": String(ln.get("who", "")), "text": String(ln.get("text", "")), "scene": sid, "origin": origin})
	for v in sc.get("variants", []):
		if not Cond.eval(v.get("when", {}), ctx):
			continue
		var rep: Dictionary = v.get("replace", {})
		for o in out:
			if rep.has(o.id):
				o.text = String(rep[o.id])
		for ln in v.get("append", []):
			if ln.has("when") and not Cond.eval(ln.when, ctx):
				continue
			out.append({"id": String(ln.id), "who": String(ln.get("who", "")), "text": String(ln.get("text", "")), "scene": sid, "origin": origin})
	# líneas que agregó un efecto (siguiente comunicación de Moran: M10, M11, M12 en M6/M7/M8): antes de la última línea
	# de la escena (la despedida), no después
	var extra := Effects.scene_extra(st, sid)
	var who := String(out[0].who) if out.size() > 0 else ""
	var ex: Array = []
	for i in extra.size():
		ex.append({"id": "extra.%d" % i, "who": who, "text": String(extra[i]), "scene": sid, "origin": origin})
	if ex.is_empty():
		return out
	if out.size() >= 2:
		var last = out.pop_back()
		out.append_array(ex)
		out.append(last)
	else:
		out.append_array(ex)
	return out

# Canal (código de lists.medios.ch) de un evento público: slip -> kbm; ad -> kt; say/show al personaje sensor -> su canal;
# go -> kh si en esa visita estaba el personaje de K-H en su lugar; si no, ks desde K-S.from_day.
static func channel_of(st, repo, ev: Dictionary) -> String:
	var sensors: Dictionary = repo.lists().get("sensors", {})
	var t := String(ev.get("type", ""))
	match t:
		"slip":
			return "kbm"
		"ad":
			return "kt"
		"say", "show":
			for k in _sorted_keys(sensors):
				if typeof(sensors[k]) == TYPE_DICTIONARY and String(sensors[k].get("char", "")) == String(ev.get("char", "")) and String(ev.get("char", "")) != "":
					return String(k).replace("-", "").to_lower()
			return ""
		"go":
			var kh = sensors.get("K-H", {})
			if typeof(kh) == TYPE_DICTIONARY and bool(kh.get("visits", false)) and String(kh.get("place", "")) == String(ev.get("place", "")):
				for vid in st.world.get("plates", {}):
					var p: Dictionary = st.world.plates[vid]
					if String(p.get("act", "")) == String(ev.get("act", "")):
						for ch in p.get("chars", []):
							if String(ch.get("id", "")) == String(kh.get("char", "")):
								return "kh"
			var ks = sensors.get("K-S", {})
			if int(ev.get("day", 0)) >= int(ks.get("from_day", 3) if typeof(ks) == TYPE_DICTIONARY else 3):
				return "ks"
	return ""

static func _gen_acts_by_channel(st, repo, ln: Dictionary, sid: String, origin: String) -> Array:
	var tpl: Dictionary = ln.get("tpl", {})
	var first := {}
	for ev in st.events:
		var ch := channel_of(st, repo, ev)
		if ch != "" and tpl.has(ch) and not first.has(ch):
			first[ch] = ev
	var out: Array = []
	for ch in _sorted_keys(tpl):
		if not first.has(ch):
			continue
		var ev: Dictionary = first[ch]
		var vars := {}
		for k in ev:
			vars[k] = ev[k] if typeof(ev[k]) != TYPE_ARRAY else ", ".join(PackedStringArray(ev[k]))
		vars["fecha"] = Diary.fecha_markup(repo, int(ev.get("day", 0)))
		vars["act_day"] = Diary.fecha_plain(repo, int(ev.get("day", 0)))
		out.append({"id": String(ln.id) + "_" + ch, "who": String(ln.get("who", "")), "text": contract(repo, Markup.fill(String(tpl[ch]), vars)),
			"scene": sid, "origin": origin, "act": String(ev.get("act", ""))})
	if out.is_empty() and ln.has("fallback"):
		out.append({"id": String(ln.id), "who": String(ln.get("who", "")), "text": String(ln.fallback), "scene": sid, "origin": origin})
	return out

# Registra una línea dicha (recortable ahora y desde el diario, con el origen de su escena).
static func say_line(st, repo, ln: Dictionary) -> String:
	var uid: String = st.next_id("line", "LN.", 4)
	var v: Dictionary = st.world.get("visit", {})
	var rec := {"uid": uid, "id": String(ln.get("id", "")), "who": String(ln.get("who", "")), "text": String(ln.get("text", "")),
		"scene": String(ln.get("scene", v.get("scene", ""))), "origin": String(ln.get("origin", v.get("id", ""))),
		"place": String(ln.get("place", v.get("place", HOME))), "tk": _now(st), "act": String(ln.get("act", ""))}
	st.world.lines[uid] = rec
	if not v.is_empty():
		v.lines.append(uid)
	Diary.on_line(st, repo, rec)
	st.note("line", {"uid": uid})
	return uid

static func line(st, repo, uid: String) -> Dictionary:
	var rec = st.world.get("lines", {}).get(uid)
	if typeof(rec) != TYPE_DICTIONARY:
		var sl = st.scenes.get("lines", {}) if typeof(st.scenes) == TYPE_DICTIONARY else {}
		rec = sl.get(uid) if typeof(sl) == TYPE_DICTIONARY else null
	if typeof(rec) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = rec.duplicate()
	out["parsed"] = repo.parse_text(String(rec.text), {}, String(rec.get("act", "")))
	return out

# Líneas que registraron Dialogue/Confrontation (W2-SCENES) en st.scenes.lines: al diario (con su origen) y a la
# visita en curso. Idempotente (st.world.lines_seen).
static func sync_scene_lines(st, repo) -> void:
	var sl = st.scenes.get("lines", {}) if typeof(st.scenes) == TYPE_DICTIONARY else {}
	if typeof(sl) != TYPE_DICTIONARY or sl.is_empty():
		return
	if typeof(st.world.get("lines_seen")) != TYPE_DICTIONARY:
		st.world["lines_seen"] = {}
	var seen: Dictionary = st.world.lines_seen
	if seen.size() >= sl.size():
		return
	var v: Dictionary = st.world.get("visit", {})
	for uid in _sorted_keys(sl):
		if seen.has(uid):
			continue
		seen[uid] = true
		if st.world.lines.has(uid):
			continue
		var rec: Dictionary = sl[uid]
		var r2 := {"uid": String(uid), "id": String(rec.get("id", "")), "who": String(rec.get("who", "")), "text": String(rec.get("text", "")),
			"origin": String(rec.get("origin", v.get("id", ""))), "tk": int(rec.get("tk", _now(st))), "act": String(rec.get("act", ""))}
		if r2.text.strip_edges() == "":
			continue   # línea sin texto (contenido pendiente): nada que mostrar ni recortar
		Diary.on_line(st, repo, r2)
		if not v.is_empty():
			v.lines.append(String(uid))
		st.note("line", {"uid": String(uid)})

# El anuncio publicado se imprime en la columna del Times de ese día (fragmento AD:prologo / AD:<n>): tramo con
# a:acto_kt sobre su primera oración y la entidad del acto (Composers.ad_markup; si no, una versión equivalente).
static func print_ad(st, repo, ev: Dictionary) -> void:
	var ad_id := String(ev.get("ad_id", ""))
	var ref := String(ev.get("ad", ""))
	var act := String(ev.get("act", ""))
	var markup := ""
	for k in [ad_id, ref]:
		if markup == "" and k != "":
			markup = Composers.ad_markup(st, repo, k, act)
	if markup == "":
		var text := Markup.escape(String(ev.get("text", "")))
		var sents := Markup.sentences_of(text, repo.lists().get("abbrev", Markup.DEFAULT_ABBREV))
		var cut := int(sents[0][1]) if sents.size() > 0 else text.length()
		var head := text.substr(0, cut)
		var mention := ("[[%s|%s]]" % [act, head]) if act != "" else head
		markup = "{{#ad a:acto_kt|%s}}%s" % [mention, text.substr(cut)]
	var iid := ad_id
	if iid == "" or st.world.docs.has(iid):
		iid = ""
	var day := int(ev.get("pub_day", ev.get("day", _day(st))))
	var tid := times_doc(repo, day)
	var inst := instantiate_doc(st, repo, {"tpl": "aviso", "texto": markup}, {}, {"iid": iid, "prefix": "AD", "rid": "", "act": act,
		"origin": tid if tid != "" else "", "doc": {"title": "Aviso en el Times", "src_type": "prensa_londres", "class": "I", "font": "imprenta",
		"paper": "diario_hueso", "entity": "times", "ad": ref}})
	deliver(st, repo, inst, "columna")

# Instantánea de un lugar o lámina fija: nodos presentes (área, `when`, variante), personajes, siluetas y encuadre.
static func snapshot(st, repo, place: String, area: String, variant: String) -> Dictionary:
	var pl: Dictionary = repo.place(place)
	if pl.is_empty():
		pl = repo.plate(place)
	var t := _now(st)
	if variant == "":
		variant = place_variant(st, place)
	var day := TimeKey.day_of(t)
	var ctx := {"st": st, "repo": repo, "tk": t}
	var nodes: Array = []
	var all_nodes: Array = (pl.get("nodes", []) as Array).duplicate()
	var vd = pl.get("variants", {}).get(variant, {}) if typeof(pl.get("variants", {})) == TYPE_DICTIONARY else {}
	if typeof(vd) == TYPE_DICTIONARY:
		all_nodes.append_array(vd.get("add_nodes", []))
	var node_defs := {}
	var base_ids := {}
	for n in pl.get("nodes", []):
		base_ids[String(n.get("id", ""))] = true
	for n in all_nodes:
		var nd: Dictionary = n if typeof(n) == TYPE_DICTIONARY else {"id": String(n)}
		var na := String(nd.get("area", "*"))
		if area != "" and na != "*" and na != "" and na != area:
			continue
		if nd.has("when") and not Cond.eval(nd.when, ctx):
			continue
		if not nodes.has(String(nd.id)):
			nodes.append(String(nd.id))
			if not base_ids.has(String(nd.id)) and typeof(n) == TYPE_DICTIONARY:
				node_defs[String(nd.id)] = nd.duplicate(true)
	# nodos que dejó un efecto (rastro `nodo`, p. ej. M1: ceniza en L1)
	for en in Effects.extra_nodes(st, place, t):
		var nid := String(en.get("node", ""))
		if nid != "" and not nodes.has(nid):
			nodes.append(nid)
			if not base_ids.has(nid) and not node_defs.has(nid):
				node_defs[nid] = {"id": nid, "tags": (en.get("tags", []) as Array).duplicate(), "examine": "", "cls": "C", "from_effect": String(en.get("rid", ""))}
	var chars: Array = []
	for ch in pl.get("characters", []):
		var ca := String(ch.get("area", "*"))
		if area != "" and ca != "*" and ca != "" and ca != area:
			continue
		if ch.has("when") and not Cond.eval(ch.when, ctx):
			continue
		chars.append({"id": String(ch.id), "pose": String(ch.get("pose", "de_pie")), "trait": String(ch.get("trait", ""))})
	var sils: Array = []
	var psil: Dictionary = pl.get("silhouettes", {}) if typeof(pl.get("silhouettes", {})) == TYPE_DICTIONARY else {}
	var whos: Array = []
	for who in _sorted_keys(st.world.get("silhouettes", {})):
		var s: Dictionary = st.world.silhouettes[who]
		if day < int(s.get("from_day", 0)) or (int(s.get("until_day", -1)) >= 0 and day > int(s.until_day)):
			continue
		whos.append(String(who))
	for who in Effects.silhouettes(st, place, day):
		if not whos.has(String(who)):
			whos.append(String(who))
	whos.sort()
	for who in whos:
		if psil.has(who):
			sils.append("sil_" + who)
	var frame := ""
	for f in pl.get("frames", []):
		var fa := String(f.get("area", "*"))
		if fa == "*" or fa == "" or fa == area or area == "":
			frame = String(f.id)
			break
	if frame == "" and (pl.get("frames", []) as Array).size() > 0:
		frame = String(pl.frames[0].id)
	var out := {"id": "", "place": place, "area": area, "day": day, "slot": TimeKey.slot_of(t), "variant": variant,
		"nodes": nodes, "chars": chars, "silhouettes": sils, "frame": frame}
	if not node_defs.is_empty():
		out["node_defs"] = node_defs
	return out

static func place_variant(st, place: String) -> String:
	var v := String(st.world.get("place_variants", {}).get(place, ""))
	if v == "":
		v = Effects.place_variant(st, place)
	return v

static func _fixed_plate_for_origin(repo, origin: String) -> String:
	var ids: Array = repo.plates().keys() if repo.has_method("plates") else []
	ids.sort()
	for id in ids:
		if String(repo.plate(id).get("origin", "")) == origin or id == origin:
			return id
	return ""

static func archive_fixed_plate(st, repo, plate_id: String, archive_id: String) -> String:
	var snap := snapshot(st, repo, plate_id, "", "")
	snap["id"] = archive_id
	snap["fixed"] = true
	snap["act"] = ""
	st.world.plates[archive_id] = snap
	return archive_id

# ---------------- hub (la buhardilla que se ve desde el escritorio) ----------------
const HUB_PLATE := "hub"

# Instantánea de la buhardilla ahora (lo que se ve desde el escritorio y la ventana: área buhardilla y nodos «*», con
# siluetas y variante). {} si Lisle no está en casa (visita, escena o prólogo, que tienen su propia lámina).
static func hub_snapshot(st, repo) -> Dictionary:
	if not st.world.get("visit", {}).is_empty() or String(location(st).place) != HOME:
		return {}
	var snap := snapshot(st, repo, HOME, "buhardilla", place_variant(st, HOME))
	snap["id"] = HUB_PLATE
	snap["hub"] = true
	return snap

# Recortar el hub archiva la instantánea de ahora como una lámina de visita (PL.L1.<día>.<franja>[.k], origen igual al
# id: RouteDB da PL.L1); si en esta franja ya se archivó una igual, se reutiliza. {} si no está en casa.
# Devuelve {id, created}; quien la crea la borra si el recorte falla (nada cambia en una acción rechazada).
static func archive_hub(st, repo) -> Dictionary:
	var snap := hub_snapshot(st, repo)
	if snap.is_empty():
		return {}
	var t := _now(st)
	var base := "PL.%s.%d.%s" % [HOME, TimeKey.day_of(t), TimeKey.slot_of(t)]
	var pid := base
	var k := 2
	while st.world.plates.has(pid):
		var old: Dictionary = st.world.plates[pid]
		if bool(old.get("hub", false)) and old.get("nodes", []) == snap.nodes and old.get("silhouettes", []) == snap.silhouettes \
				and String(old.get("variant", "")) == String(snap.variant):
			return {"id": pid, "created": false}
		pid = "%s.%d" % [base, k]
		k += 1
	snap["id"] = pid
	snap["act"] = ""
	st.world.plates[pid] = snap
	return {"id": pid, "created": true}

# Lámina por id: archivada (visitas, prólogo, M7) o fija de documento ("RB.foto" -> lámina RB con variante foto);
# "hub" = la buhardilla de ahora (hub_snapshot).
static func plate_snapshot(st, repo, id: String) -> Dictionary:
	if st.world.get("plates", {}).has(id):
		return st.world.plates[id].duplicate(true)
	if id == HUB_PLATE:
		return hub_snapshot(st, repo)
	var pid := _fixed_plate_for_origin(repo, id)
	var variant := ""
	if pid == "" and id.contains("."):
		var base := id.get_slice(".", 0)
		var p2 := _fixed_plate_for_origin(repo, base)
		if p2 == "":
			for k in repo.plates().keys():
				if String(k).to_upper().begins_with(base.to_upper()):
					p2 = String(k)
		if p2 != "":
			pid = p2
			variant = id.substr(base.length() + 1)
	if pid == "":
		return {}
	var snap := snapshot(st, repo, pid, "", variant)
	snap["id"] = id
	snap["fixed"] = true
	return snap

# ---------------- acciones de visita ----------------
# Papeleta. {doc} pide el ejemplar BM del documento; si no se sirve hoy (fuera de su ventana) o es una ficha de ruido
# del catálogo ({doc: "", noise: <rótulo>}), la papeleta se gasta igual y el ujier vuelve sin nada ({ok, view: ""}):
# pedir nunca es gratis, para que el costo no distinga lo que importa de lo que no (W4).
static func act_slip(st, repo, a) -> Dictionary:
	var v: Dictionary = st.world.get("visit", {})
	var did := String(a.get("doc", ""))
	var noise := String(a.get("noise", "")).strip_edges()
	if v.is_empty() or not place_needs_seat(repo, String(v.get("place", ""))):
		return {"ok": false, "err": "no_esta"}
	var d: Dictionary = repo.doc(did) if did != "" else {}
	if did != "" and d.is_empty():
		return {"ok": false, "err": "no_esta"}
	if did == "" and noise == "":
		return {"ok": false, "err": "forma"}
	var copy_id := ""
	var bm := false
	for c in d.get("copies", []):
		if String(c.get("holder", "")) == "BM" and String(c.get("via", "slip")) == "slip":
			bm = true
			if copy_available(st, repo, String(c.id), _now(st)):
				copy_id = String(c.id)
				break
	if did != "" and not bm:
		return {"ok": false, "err": "no_esta"}
	var vid := String(v.id)
	var used: Array = st.world.slips.get(vid, [])
	var token := copy_id if copy_id != "" else "~" + (did if did != "" else noise)
	if used.has(token):
		return {"ok": false, "err": "ya_pedido"}
	if used.size() >= SLIPS_PER_VISIT:
		return {"ok": false, "err": "sin_papeletas"}
	if not st.world.slips.has(vid):
		st.world.slips[vid] = []
	st.world.slips[vid].append(token)
	var hour := _plus_minutes(String(v.get("hour", "")), 10 * st.world.slips[vid].size())
	st.push_event({"type": "slip", "seat": int(st.world.get("seat", 0)), "doc": did, "title": String(d.get("title", noise)),
		"hour": hour, "topic": String(d.get("slip_topic", "otros"))})
	st.note("visit", {"slip": copy_id})
	return {"ok": true, "view": copy_id}

static func act_order_copy(st, repo, a) -> Dictionary:
	var v: Dictionary = st.world.get("visit", {})
	var did := String(a.get("doc", ""))
	if v.is_empty():
		return {"ok": false, "err": "no_esta"}
	var d: Dictionary = repo.doc(did)
	var here := false
	for c in d.get("copies", []):
		if holder_place(String(c.get("holder", ""))) == String(v.place) and copy_available(st, repo, String(c.id), _now(st)):
			here = true
	if not here or String(d.get("clip_mode", "normal")) != "memoria":
		return {"ok": false, "err": "no_esta"}
	if st.world.orders.has(did):
		return {"ok": false, "err": "ya_pedido"}
	var day := int(st.clock.day)
	var arr := _mail_day_at_or_after(repo, day + 2)
	var arrives := TimeKey.tk(arr, "dawn") if arr >= 0 else -1
	st.world.orders[did] = {"tk": _now(st), "arrives_tk": arrives}
	add_coins(st, -int(repo.schedule().get("money_d", {}).get("somerset", 12)))
	st.push_event({"type": "order_copy", "doc": did, "arrives_tk": arrives})
	return {"ok": true, "arrives_tk": arrives}

static func _mail_day_at_or_after(repo, day: int) -> int:
	var best := -1
	for d in repo.schedule().get("days", []):
		var dd := int(d.get("day", -1))
		if dd >= day and bool(d.get("mail", false)) and (best < 0 or dd < best):
			best = dd
	return best

static func _plus_minutes(hhmm: String, m: int) -> String:
	if not hhmm.contains(":"):
		return hhmm
	var h := hhmm.get_slice(":", 0).to_int()
	var mm := hhmm.get_slice(":", 1).to_int() + m
	return "%d:%02d" % [h + int(mm / 60), mm % 60]

# ---------------- huevos de pascua (Marginalia; ≤1 por visita, sin contador) ----------------
static func egg_unit(st) -> String:
	var v: Dictionary = st.world.get("visit", {})
	if not v.is_empty():
		return String(v.get("id", ""))
	return "F.%d.%s" % [int(st.clock.get("day", 0)), String(st.clock.get("slot", ""))]

static func check_eggs(st, repo) -> void:
	var unit := egg_unit(st)
	var found: Dictionary = st.world.get("eggs", {})
	# el resultado sólo cambia con la unidad de visita o con recortes/pares nuevos: firma para no recalcular
	var sig := "%s|%d|%d|%d|%d" % [unit, _clips(st).size(), _pairs(st).size(), int(st.seq.get("clip", 0)), int(st.seq.get("pair", 0))]
	if String(st.world.get("eggs_sig", "")) == sig or found.size() >= repo.eggs().size():
		return
	st.world["eggs_sig"] = sig
	for k in found:
		if String(found[k].get("visit", "")) == unit:
			return
	var eggs: Array = repo.eggs().duplicate()
	eggs.sort_custom(func(a, b): return String(a.get("id", "")) < String(b.get("id", "")))
	for egg in eggs:
		var eid := String(egg.get("id", ""))
		if eid == "" or found.has(eid):
			continue
		if _egg_triggered(st, egg.get("trigger", {})):
			found[eid] = {"tk": _now(st), "visit": unit}
			st.note("egg", {"id": eid})
			return

static func _clip_tags(clip: Dictionary) -> Array:
	var out: Array = []
	var tg = clip.get("tags", [])
	if typeof(tg) == TYPE_DICTIONARY:
		for p in tg:
			for v in tg[p]:
				out.append(String(p) + ":" + String(v))
	elif typeof(tg) == TYPE_ARRAY:
		for x in tg:
			out.append(String(x))
	for e in clip.get("ents", []):
		var eid := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
		if not out.has("e:" + eid):
			out.append("e:" + eid)
	return out

static func _clips(st) -> Dictionary:
	var c = st.ded.get("clips", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}

static func _pairs(st) -> Dictionary:
	var p = st.ded.get("pairs", {})
	return p if typeof(p) == TYPE_DICTIONARY else {}

static func _clip(st, id: String) -> Dictionary:
	var raw = _clips(st).get(id, {})
	if typeof(raw) == TYPE_DICTIONARY and not raw.is_empty():
		return raw
	return Clipper.get_clip(st, id)

# Etiquetas de todos los recortes, incremental (los recortes nunca se borran): antes, cada recorte nuevo volvía a
# recorrer todos los anteriores por cada huevo (carga cuadrática al reanudar una partida larga). Caché transitoria por
# estado (no es canon): se rehace si el diccionario de recortes cambió de identidad (restauración) o se achicó.
static var _tag_cache := {}

static func _all_clip_tags(st) -> Dictionary:
	var clips := _clips(st)
	var key: int = st.get_instance_id() if st is Object else 0
	var c = _tag_cache.get(key)
	if typeof(c) != TYPE_DICTIONARY or not is_same(c.clips, clips) or int(c.n) > clips.size():
		if _tag_cache.size() > 64:
			_tag_cache.clear()
		c = {"clips": clips, "n": 0, "tags": {}}
		_tag_cache[key] = c
	if int(c.n) < clips.size():
		var ids: Array = clips.keys()
		for i in range(int(c.n), ids.size()):
			for t in _clip_tags(_clip(st, String(ids[i]))):
				c.tags[t] = true
		c.n = ids.size()
	return c.tags

static func _egg_triggered(st, trig: Dictionary) -> bool:
	if trig.has("clip_tag"):
		return _all_clip_tags(st).has(String(trig.clip_tag))
	if trig.has("pair_tags"):
		for pid in _sorted_keys(_pairs(st)):
			var p = _pairs(st)[pid]
			var tags: Array = _clip_tags(_clip(st, String(p.get("a", "")))) + _clip_tags(_clip(st, String(p.get("b", ""))))
			var all_in := true
			for w in trig.pair_tags:
				if not tags.has(String(w)):
					all_in = false
			if all_in:
				return true
		return false
	if trig.has("pairs_over"):
		var paired := {}
		for pid in _pairs(st):
			var p = _pairs(st)[pid]
			paired[String(p.get("a", ""))] = true
			paired[String(p.get("b", ""))] = true
		for ref in trig.pairs_over:
			var r := String(ref)
			var did := r.get_slice("#", 0)
			var tid := r.get_slice("#", 1)
			var hit := false
			for cid in paired:
				var c := _clip(st, cid)
				var corg := String(c.get("origin", c.get("doc", "")))
				if (corg == did or String(c.get("doc", "")) == did) and String(c.get("tramo", "")) == tid:
					hit = true
			if not hit:
				return false
		return true
	return false

static func _sorted_keys(d) -> Array:
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var k: Array = d.keys()
	k.sort()
	return k
