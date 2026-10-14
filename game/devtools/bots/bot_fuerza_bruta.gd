# devtools/bots/bot_fuerza_bruta.gd — fuerza bruta (§9.3; GDD_v3 §1.9, T10): sin ningún oráculo. Sale cada franja a un
# lugar abierto al azar, pide papeletas al azar del catálogo, recorta TODO lo legible con recortes legales máximos (una
# oración, ≤15 palabras; cada nodo del diorama por separado) y en cada pregunta abierta prueba una respuesta al azar
# (entre las opciones del índice) con DOS recortes al azar de papeles distintos, hasta MAX_TRIES intentos por pregunta.
# GDD_v3 §1.9: p ≈ 2·10⁻⁴ por intento; presupuesto de T10: cierra ≤5 % de las preguntas en 20 semillas.
extends "res://devtools/bots/bot_base.gd"

const MAX_TRIES := 100

func _init_bot() -> void:
	bot_name = "fuerza_bruta"
	deduce = false
	value_mode = "random"
	max_attempts = MAX_TRIES

func pol_desk_extra() -> void:
	clip_everything(self)
	random_tries(self, MAX_TRIES, false)

func pol_in_visit() -> void:
	clip_everything(self)
	var v: Dictionary = sim.st.world.get("visit", {})
	if WorldModel.place_needs_seat(repo, String(v.get("place", ""))):
		random_slips(self)
		clip_everything(self)

func pol_outing() -> Dictionary:
	return random_outing(self)

func pol_confirm() -> Array:
	return []

# Intentos al azar en cada pregunta abierta: respuesta al azar (o la del canon si `knows`) y un par al azar de recortes
# de orígenes distintos; hasta max_tries por pregunta en total (per_call por llamada). Devuelve las que cerró.
static func random_tries(b, max_tries: int, knows: bool, per_call := 10) -> Array:
	var closed: Array = []
	var ids: Array = b._clip_ids()
	if ids.size() < 2:
		return closed
	var dv: Dictionary = b.sim.q_dossier()
	for h in dv.get("open", []):
		var q := String(h.id)
		var n := 0
		var guard := 0
		while int(b.attempt.get(q, 0)) < max_tries and n < per_call and guard < per_call * 4:
			guard += 1
			var ans := ""
			if knows:
				for v in b._valid_answers(q):
					if b._answer_ok(q, String(v)):
						ans = String(v)
						break
				if ans == "":
					break
			else:
				var opts: Array = b.sim.q_answer_options(q)
				if opts.is_empty():
					break
				ans = String(b.rnd_pick(opts, "ans").id)
			var c1 := String(b.rnd_pick(ids, "p1"))
			var c2 := String(b.rnd_pick(ids, "p2"))
			var o1 := String(Clipper.get_clip(b.sim.st, c1).get("origin", ""))
			var o2 := String(Clipper.get_clip(b.sim.st, c2).get("origin", ""))
			if c1 == c2 or o1 == o2:
				continue
			n += 1
			if not b._write_sheet(q, ans, c1, c2):
				break
			var r: Dictionary = b.act({"t": "dq_confirm", "q": q}, true)
			if bool(r.get("inked", false)):
				closed.append(q)
				break
	return closed

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
