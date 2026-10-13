# devtools/bots/bot_fuerza_bruta.gd — fuerza bruta SIN las pruebas (W3-BOTS; §9.3, GDD §8.9 primer caso, §11, T10).
# No usa ningún oráculo: sale cada franja a un lugar abierto al azar, pide papeletas al azar del catálogo, recorta
# TODO lo legible con recortes legales máximos (una oración, ≤40 palabras; cada nodo del diorama por separado) y en cada
# pasada arma asientos nuevos con plantilla, valores y «según» al azar (cumpliendo sólo la forma: cada línea llena con
# su recorte, ≥2 orígenes, ≤4 recortes). GDD §8.9: ~10⁻¹⁰ por lote; nunca debe superar al deductor.
extends "res://devtools/bots/bot_base.gd"

const TEMPLATES := ["T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9"]

func _init_bot() -> void:
	bot_name = "fuerza_bruta"
	deduce = false
	value_mode = "random"

func pol_desk_extra() -> void:
	clip_everything(self)

func pol_in_visit() -> void:
	clip_everything(self)
	var v: Dictionary = sim.st.world.get("visit", {})
	if WorldModel.place_needs_seat(repo, String(v.get("place", ""))):
		random_slips(self)
		clip_everything(self)

func pol_outing() -> Dictionary:
	return random_outing(self)

func pol_lot(n: int) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < n and tries < 6 * maxi(n, 1):
		tries += 1
		var e := random_entry()
		if e != "" and not out.has(e):
			out.append(e)
	return out if out.size() == n else []

# Asiento nuevo con plantilla, valores y «según» al azar; "" si no hay con qué cumplir la forma.
func random_entry() -> String:
	var ids := _clip_ids()
	if ids.size() < 2:
		return ""
	var tid := String(rnd_pick(TEMPLATES, "tpl"))
	var tpl: Dictionary = repo.template(tid)
	var lines: Array = []
	var used: Array = []
	for li in (tpl.get("lines", []) as Array).size():
		var ln: Dictionary = tpl.lines[li]
		var row := {"fields": {}, "support": []}
		if bool(ln.get("optional", false)) and rnd01("opt") < 0.5:
			lines.append(row)
			continue
		for fd in ln.get("fields", []):
			var cands := _field_candidates(fd)
			if not cands.is_empty():
				row.fields[String(fd.id)] = String(rnd_pick(cands, "val"))
		if not row.fields.is_empty() and used.size() < Ledger.MAX_CLIPS:
			var cl := String(rnd_pick(ids, "segun"))
			row.support.append(cl)
			if not used.has(cl):
				used.append(cl)
		lines.append(row)
	if used.is_empty():
		return ""
	# ≥2 orígenes (si no, el chequeo formal lo rechaza sin gastar la pasada y el bot no aprendería nada)
	var origins := Ledger.origins_of(sim.st, used)
	if origins.size() < 2 and used.size() < Ledger.MAX_CLIPS:
		for k in 8:
			var cl2 := String(rnd_pick(ids, "segun2"))
			if not Ledger.origins_of(sim.st, [cl2]).is_empty() and not origins.has(Ledger.origins_of(sim.st, [cl2])[0]):
				for row2 in lines:
					if not (row2.fields as Dictionary).is_empty():
						row2.support.append(cl2)
						break
				used.append(cl2)
				break
	if Ledger.origins_of(sim.st, used).size() < 2:
		return ""
	return _write_entry({"template": tid, "lines": lines}, "varios")

# ---------------------------------------------------------------- utilidades compartidas (recorta_todo, solo_bm…)
# Recorta con recortes legales máximos todo lo legible ahora (documentos, líneas de la escena, nodos del diorama).
# Devuelve {view: [ids de recorte]} de lo recortado en esta llamada.
static func clip_everything(b) -> Dictionary:
	var made := {}
	var seen: Dictionary = b.seen_clips
	for x in b.sim.q_accessible():
		var view := String(x.view)
		var v: Dictionary = b.sim.q_view(view)
		var pages: Array = v.get("pages", [])
		for pi in pages.size():
			for bi in (pages[pi] as Array).size():
				var p: Dictionary = pages[pi][bi].get("parsed", {})
				for s in ClipRules.max_legal_clips(p):
					var k := "%s|%d|%d|%d|%d|%s" % [view, pi, bi, int(s.from), int(s.to), String(p.get("plain", "")).substr(int(s.from), int(s.to) - int(s.from)).md5_text()]
					if seen.has(k):
						continue
					seen[k] = true
					var r: Dictionary = b.act({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi}, "from": int(s.from), "len": int(s.to) - int(s.from)}, true)
					if String(r.get("clip", "")) != "":
						if not made.has(view):
							made[view] = []
						made[view].append(String(r.clip))
	var sc: Dictionary = b.sim.q_scene()
	for ln in sc.get("lines", []):
		var p2: Dictionary = ln.get("parsed", {})
		for s2 in ClipRules.max_legal_clips(p2):
			var k2 := "line|%s|%d|%d" % [String(ln.uid), int(s2.from), int(s2.to)]
			if seen.has(k2):
				continue
			seen[k2] = true
			var r2: Dictionary = b.act({"t": "clip_text", "src": {"kind": "line", "ref": String(ln.uid)}, "from": int(s2.from), "len": int(s2.to) - int(s2.from)}, true)
			if String(r2.get("clip", "")) != "":
				if not made.has("line|" + String(ln.uid)):
					made["line|" + String(ln.uid)] = []
				made["line|" + String(ln.uid)].append(String(r2.clip))
	var snap: Dictionary = b.sim.q_visit_plate()
	if not snap.is_empty():
		var pid := String(snap.get("id", ""))
		for nid in (snap.get("nodes", []) as Array) + (snap.get("silhouettes", []) as Array):
			var k3 := "node|%s|%s" % [pid, String(nid)]
			if seen.has(k3):
				continue
			seen[k3] = true
			var id: String = b._clip_node(pid, String(nid))
			if id != "":
				if not made.has(pid):
					made[pid] = []
				made[pid].append(id)
	return made

# Hasta 3 papeletas de documentos al azar del catálogo de entidades del índice (lo que un lector sin plan pediría).
static func random_slips(b) -> void:
	var v: Dictionary = b.sim.st.world.get("visit", {})
	var idx: Array = b.sim.q_index()
	for k in 12:
		if (b.sim.st.world.get("slips", {}).get(String(v.get("id", "")), []) as Array).size() >= WorldModel.SLIPS_PER_VISIT or idx.is_empty():
			return
		var ent = b.rnd_pick(idx, "cat")
		var docs: Array = []
		for c in b.sim.q_catalog(String(ent.get("id", ""))):
			if String(c.get("doc", "")) != "":
				docs.append(String(c.doc))
		if docs.is_empty():
			continue
		b.act({"t": "slip", "doc": String(b.rnd_pick(docs, "slip"))}, true)

# Una salida con costo a un lugar abierto al azar ({} = quedarse; 1 de cada 6 franjas se queda en casa).
static func random_outing(b) -> Dictionary:
	var opts: Array = []
	for p in b.sim.q_places():
		if bool(p.get("can_go", false)) and not bool(p.get("free", false)):
			opts.append({"place": String(p.id), "area": String(p.area)})
	if opts.is_empty() or b.rnd01("casa") < 1.0 / 6.0:
		return {}
	return b.rnd_pick(opts, "salida")
