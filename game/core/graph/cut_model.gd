# core/graph/cut_model.gd — cortes derivados de reacciones (§4.9 corta[] + efecto[]; §5.6). Dueño: W2-GRAPH.
# Contrato §3.8: cuts_for(repo, rid, soft := false) -> [{target:{copy|access|place|char|...}, from_idx, to_idx}]
#                apply_cuts(masks, cuts) -> Dictionary
# Corte (dict; campos extra compatibles): {rid, soft, src:"corta"|"efecto", target, days (-1 = permanente),
#   moments:[idx de inicio posibles: más temprano, más tardío, más tardío+1 si D2 lo puede diferir], from_idx, to_idx
#   (ventana en el momento más temprano; -1 si la reacción no puede dispararse), spare:[escenas exentas], rel:true}.
#   rel = la ventana es relativa a la entrega: Invariant.runtime_guard la re-ancla al día de resolución.
# target (uno por corte): {copy} · {copies:"informadas"|[ids]} (originales P informados; peor caso: todo P en posesión) ·
#   {access:"L4.consulta"|"L5.forasteros", lost?} · {place} · {char} (líneas de diálogo) · {channel} (sólo opcionales) ·
#   {route, srcs:[claves]} (corta[].ref: partes no-I de la ruta/subruta) · {cond, lost} (flag que apaga un when/needs) ·
#   {task} (acceso "task:x": encargo de un personaje; sin fuentes modeladas, no quita bits; static_check lo anota).
#   Los efectos `flag` se traducen comparando la disponibilidad con y sin el flag (needs de áreas y when de nodos,
#   personajes, líneas, partes de documentos y escenas): así T5' compara alcanzabilidad real.
# spare: escenas automáticas (sin tk) del lugar donde ocurre el acto disparador y disponibles en TODA franja en que ese
#   acto puede ocurrir: sus líneas ya se dijeron (HB12 cierra la Sala de Forasteros sólo después de que Mycroft dijo
#   HC06 (a)–(f)); el corte no las toca. HB6 (primera visita a 221B, desde el día 1) no exime a HC05 (días 8–9).
# Además (tests T2/T5): static_check (D9/T2), footprint (ley de la huella, T5), derived_check (T5'), hb11_check.
extends RefCounted

const TimeKey = preload("res://core/util/timekey.gd")
const J = preload("res://core/util/j.gd")
const Av = preload("res://core/graph/availability.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

static func has_soft(repo, rid: String) -> bool:
	return typeof(repo.reaction(rid).get("variante_blanda")) == TYPE_DICTIONARY

static func deferrable(r: Dictionary, day: int) -> bool:
	if int(r.get("nivel", 0)) < 3 or String(r.get("tipo", "")) == "columna" or bool(r.get("exento_d2", false)):
		return false
	if String(r.get("voz", "")) == "B":
		return false
	if r.has("exento_d2_desde_dia") and day >= int(r.exento_d2_desde_dia):
		return false
	return true

# {due:[tk], moments:[idx]}: momentos de inicio de los cortes (§5.6 acotación 3).
static func timing(repo, rid: String) -> Dictionary:
	var due := Av.react_due(repo, rid)
	if due.is_empty():
		return {"due": [], "moments": []}
	var r: Dictionary = repo.reaction(rid)
	var first := TimeKey.idx_at_or_after(due[0])
	var lastd: int = due[due.size() - 1]
	var lastm := TimeKey.idx_at_or_after(lastd)
	var moments: Array = []
	for m in [first, lastm]:
		if m < TimeKey.idx_count() and not moments.has(m):
			moments.append(m)
	var dl := TimeKey.day_of(lastd)
	if dl < 10 and deferrable(r, dl):
		var nm := TimeKey.idx_at_or_after(TimeKey.tk(dl + 1, "dawn"))
		if nm < TimeKey.idx_count() and not moments.has(nm):
			moments.append(nm)
	return {"due": due, "moments": moments}

# Último índice de una ventana de `days` días que empieza en start (days < 0: hasta el final).
static func window_end(start: int, days: int) -> int:
	if start < 0:
		return -1
	var nn := TimeKey.idx_count()
	if days < 0:
		return nn - 1
	var d0 := int(TimeKey.from_idx(start).day)
	var last := start - 1
	for i in range(start, nn):
		if int(TimeKey.from_idx(i).day) <= d0 + days - 1:
			last = i
		else:
			break
	return last

static func at(cut: Dictionary, start: int) -> Dictionary:
	var c: Dictionary = cut.duplicate()
	c["from_idx"] = start
	c["to_idx"] = window_end(start, int(cut.get("days", -1)))
	return c

# Sólo si la escena estaba disponible en TODA franja en que el acto disparador puede ocurrir: entonces sus líneas ya se
# dijeron en esa visita (HB12 tras HC06 (a)–(f)). HB6 (primera visita a 221B, quizá el día 2) no exime a HC05 (días 8–9).
static func spare_scenes(repo, r: Dictionary) -> Array:
	var spots := Av.trigger_spots(repo, r)
	var out: Array = []
	if spots.is_empty() or not repo.has_method("scenes"):
		return out
	var trig := Av.trigger_mask(repo, r)
	if trig == 0:
		return out
	for sid in Av.sorted_keys(repo.scenes()):
		var s: Dictionary = repo.scene(String(sid))
		if s.has("tk"):
			continue
		var sa := String(s.get("area", "*"))
		for sp in spots:
			if String(s.get("place", "")) == String(sp[0]) and (sa == "*" or sa == "" or sa == String(sp[1]) or String(sp[1]) == "*"):
				var sm := 0
				for src in Av.scene_srcs(repo, String(sid), {}):
					sm |= int(src.mask)
				if (trig & ~sm) == 0 and not out.has(String(sid)):
					out.append(String(sid))
	return out

static func _days_of(v) -> int:
	if typeof(v) != TYPE_DICTIONARY:
		return -1
	if bool(v.get("permanente", false)):
		return -1
	if v.has("dias") and v.dias != null:
		return int(v.dias)
	return -1

static func _access_target(s: String) -> Dictionary:
	if s.begins_with("canal:"):
		return {"channel": s.substr(6)}
	if s.begins_with("char:"):
		return {"char": s.substr(5)}
	if s.begins_with("task:"):
		# encargo de un personaje (M4: task:seguir_chico_pell). Ninguna fuente declara de qué encargo sale: el corte no
		# quita bits (static_check lo informa en notes) y la ruta que alimenta debe cortarse también por ref.
		return {"task": s.substr(5)}
	if s.contains("."):
		return {"access": s}
	return {"place": s}

# Objetivo de corte que no nombra nada de data/ (lugar o área inexistente): "" si es válido.
static func target_problem(repo, t: Dictionary) -> String:
	if t.has("place"):
		var p := String(t.place)
		if repo.place(p).is_empty() and not repo.schedule().get("places", {}).has(p):
			return "lugar '%s' inexistente" % p
	if t.has("access") and not String(t.access).begins_with("canal:") and not String(t.access).begins_with("char:") and not String(t.access).begins_with("task:"):
		var acc := String(t.access)
		var p2 := acc.get_slice(".", 0)
		var a := acc.substr(p2.length() + 1)
		if repo.place(p2).is_empty() and not repo.schedule().get("places", {}).has(p2):
			return "lugar '%s' inexistente" % p2
		var areas := Av.areas_of(repo, p2)
		if a != "" and a != "*" and not areas.is_empty() and not areas.has(a):
			return "área '%s' inexistente en schedule.places.%s %s" % [a, p2, str(areas)]
	return ""

static func _route_target(repo, id: String) -> Dictionary:
	var rt := RouteDB.route_by_id(repo, id)
	if rt.is_empty() or not rt.missing.is_empty():
		var keys0: Array = []
		for f in rt.get("frags", []):
			if String(f.cls) != "I":
				keys0.append_array(f.srcs)
		return {"route": id, "srcs": keys0, "missing": true}
	var keys: Array = []
	for f in rt.frags:
		if String(f.cls) != "I":
			for k in f.srcs:
				if not keys.has(k):
					keys.append(k)
	return {"route": id, "srcs": keys}

static func _targets_corta(repo, c: Dictionary) -> Array:
	if c.has("ref"):
		return [_route_target(repo, String(c.ref))]
	if c.has("copy"):
		return [{"copy": String(c.copy)}]
	if c.has("copias"):
		return [{"copies": c.copias}]
	if c.has("acceso"):
		return [_access_target(String(c.acceso))]
	if c.has("place"):
		return [{"place": String(c.place)}]
	if c.has("char"):
		return [{"char": String(c.char)}]
	if c.has("node"):
		return [{"node": String(c.node)}]
	return []

# Condiciones (when/needs) presentes en data/ (para traducir flags en cortes concretos).
static func all_conds(repo) -> Array:
	var g := Av.gcache(repo)
	if g.has("all_conds"):
		return g["all_conds"]
	var seen := {}
	var add := func(c):
		if typeof(c) == TYPE_DICTIONARY and not c.is_empty():
			seen[J.stringify_canon(c)] = c
	for pid in Av.sorted_keys(repo.places()):
		var p: Dictionary = repo.place(String(pid))
		for nd in p.get("nodes", []):
			if typeof(nd) == TYPE_DICTIONARY:
				add.call(nd.get("when"))
		for ch in p.get("characters", []):
			if typeof(ch) == TYPE_DICTIONARY:
				add.call(ch.get("when"))
	for did in Av.sorted_keys(repo.docs()):
		for pt in repo.doc(String(did)).get("parts", []):
			if typeof(pt) == TYPE_DICTIONARY:
				add.call(pt.get("when"))
	if repo.has_method("dialogues"):
		for ch in Av.sorted_keys(repo.dialogues()):
			for l in repo.dialogue(String(ch)).get("lines", []):
				if typeof(l) == TYPE_DICTIONARY:
					add.call(l.get("when"))
	if repo.has_method("scenes"):
		for sid in Av.sorted_keys(repo.scenes()):
			var s: Dictionary = repo.scene(String(sid))
			add.call(s.get("when"))
			for l in s.get("lines", []):
				if typeof(l) == TYPE_DICTIONARY:
					add.call(l.get("when"))
	var out: Array = []
	for k in Av.sorted_keys(seen):
		out.append(seen[k])
	g["all_conds"] = out
	return out

static func flag_targets(repo, flags: Dictionary) -> Array:
	var out: Array = []
	var places = repo.schedule().get("places", {})
	if typeof(places) == TYPE_DICTIONARY:
		for pid in Av.sorted_keys(places):
			for a in Av.areas_of(repo, String(pid)):
				var ad = places[pid].areas[a]
				if typeof(ad) != TYPE_DICTIONARY or not ad.has("needs"):
					continue
				var lost := Av.area_open(repo, String(pid), String(a), {}) & ~Av.area_open(repo, String(pid), String(a), flags)
				if lost != 0:
					out.append({"access": "%s.%s" % [pid, a], "lost": lost, "flag": flags})
	for c in all_conds(repo):
		var lost2 := Av.cond_mask(repo, c, {}) & ~Av.cond_mask(repo, c, flags)
		if lost2 != 0:
			out.append({"cond": J.stringify_canon(c), "lost": lost2, "flag": flags})
	return out

# [{t: target, days}]
static func _targets_effect(repo, e: Dictionary) -> Array:
	var op := String(e.get("op", ""))
	var days := -1
	if e.has("dias") and e.dias != null:
		days = int(e.dias)
	match op:
		"retirar":
			if e.has("copy"):
				return [{"t": {"copy": String(e.copy)}, "days": days}]
			if e.has("copias"):
				return [{"t": {"copies": e.copias}, "days": days}]
		"cerrar":
			var tg := String(e.get("target", e.get("acceso", "")))
			if tg != "":
				return [{"t": _access_target(tg), "days": days}]
		"arrancar":
			if e.has("copy"):
				return [{"t": {"copy": String(e.copy)}, "days": -1}]
		"flag":
			var out: Array = []
			if e.has("name"):
				for t in flag_targets(repo, {String(e.name): e.get("value", true)}):
					out.append({"t": t, "days": -1})
			return out
	return []

static func _mk(rid: String, soft: bool, src: String, target: Dictionary, days: int, tm: Dictionary, spare: Array) -> Dictionary:
	var moments: Array = tm.get("moments", [])
	var start: int = moments[0] if not moments.is_empty() else -1
	return {"rid": rid, "soft": soft, "src": src, "target": target, "days": days, "moments": moments,
		"from_idx": start, "to_idx": window_end(start, days), "spare": spare, "rel": true}

static func cuts_for(repo, rid: String, soft := false) -> Array:
	var cc := Av.sub(repo, "cuts")
	var ck := rid + ("|soft" if soft else "")
	if cc.has(ck):
		return cc[ck]
	var out: Array = []
	cc[ck] = out
	var r: Dictionary = repo.reaction(rid)
	if r.is_empty():
		return out
	var corta: Array = r.get("corta", [])
	var efecto: Array = r.get("efecto", [])
	if soft:
		var vb = r.get("variante_blanda")
		if typeof(vb) != TYPE_DICTIONARY:
			return out
		corta = vb.get("corta", [])
		efecto = vb.get("efecto", [])
	var tm := timing(repo, rid)
	var spare := spare_scenes(repo, r)
	var seen := {}
	for c in corta:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		for t in _targets_corta(repo, c):
			var x := _mk(rid, soft, "corta", t, _days_of(c.get("ventana")), tm, spare)
			var k := "c|" + J.stringify_canon([t, x.days])
			if not seen.has(k):
				seen[k] = true
				out.append(x)
	for e in efecto:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		for td in _targets_effect(repo, e):
			var y := _mk(rid, soft, "efecto", td.t, int(td.days), tm, spare)
			var k2 := "e|" + J.stringify_canon([td.t, y.days])
			if not seen.has(k2):
				seen[k2] = true
				out.append(y)
	return out

# Bits que el corte puede quitar a la fuente (0 = no la toca).
static func hit(cut: Dictionary, s: Dictionary) -> int:
	var all := Av.full_mask()
	var t = cut.get("target", {})
	if typeof(t) != TYPE_DICTIONARY:
		return 0
	var sc := String(s.get("scene", ""))
	if sc != "" and cut.get("spare", []).has(sc):
		return 0
	if t.has("srcs"):
		return all if t.srcs.has(String(s.get("key", ""))) else 0
	if t.has("copy"):
		return all if String(s.get("copy", "")) == String(t.copy) else 0
	if t.has("copies"):
		var v = t.copies
		if typeof(v) == TYPE_ARRAY:
			var scp := String(s.get("copy", ""))
			var srd := String(s.get("rid", ""))
			return all if (scp != "" and v.has(scp)) or (srd != "" and v.has(srd)) else 0
		return all if String(s.get("cls", "")) == "P" and ["copy", "react"].has(String(s.get("kind", ""))) else 0
	if t.has("access") and (String(t.access).begins_with("canal:") or String(t.access).begins_with("char:") or String(t.access).begins_with("task:")):
		# forma de runtime de Director (§4.9 acceso "canal:K-H" / "char:x" / "task:x")
		var nt := _access_target(String(t.access))
		var c2: Dictionary = cut.duplicate()
		c2["target"] = nt
		return hit(c2, s)
	if t.has("access"):
		var acc := String(t.access)
		var p := acc.get_slice(".", 0)
		var a := acc.substr(p.length() + 1)
		if String(s.get("place", "")) != p:
			return 0
		var sa := String(s.get("area", ""))
		if a != "" and sa != a and sa != "*":
			return 0
		return int(t.get("lost", all))
	if t.has("place"):
		return all if String(s.get("place", "")) == String(t.place) else 0
	if t.has("char"):
		return all if String(s.get("kind", "")) == "line" and String(s.get("char", "")) == String(t.char) else 0
	if t.has("channel"):
		# HB11: sólo reacciones opcionales nuevas del canal; columna, garantizadas y `garantizada_si` siguen.
		# channel "*" = el canal del acto (cualquiera); una reacción de canal "*" sólo cae ante "*".
		if String(s.get("kind", "")) != "react" or String(s.get("tipo", "")) != "opcional" or bool(s.get("garantizada_si", false)):
			return 0
		return all if String(t.channel) == "*" or String(s.get("channel", "")) == String(t.channel) else 0
	if t.has("cond"):
		return int(t.lost) if s.get("ck", []).has(String(t.cond)) else 0
	if t.has("node"):
		return all if String(s.get("node", "")) == String(t.node) else 0
	# {task}: sin modelo de fuentes por encargo (ver _access_target).
	return 0

# masks: {clave: int | fuente(dict con "mask")}. Con int, la clave es una clave de fuente o un id de ejemplar.
static func apply_cuts(masks: Dictionary, cuts: Array) -> Dictionary:
	var out := {}
	var keys: Array = masks.keys()
	keys.sort()
	for k in keys:
		out[k] = masks[k]
	for c in cuts:
		var f := int(c.get("from_idx", -1))
		if f < 0:
			continue
		var win := Av.range_mask(f, int(c.get("to_idx", f)))
		if win == 0:
			continue
		for k in keys:
			var v = out[k]
			if typeof(v) == TYPE_DICTIONARY:
				var lost := hit(c, v)
				if lost != 0:
					var d: Dictionary = v.duplicate()
					d["mask"] = int(d.get("mask", 0)) & ~(win & lost)
					out[k] = d
			else:
				# máscara suelta: la clave es un id de ejemplar ("D29a@L4") o una clave de fuente
				var lost2 := hit(c, {"key": String(k), "copy": String(k)})
				if lost2 != 0:
					out[k] = int(v) & ~(win & lost2)
	return out

# ---------------- T2 / D9 ----------------
static func _universe_i(repo) -> Array:
	var seen := {}
	var out: Array = []
	for c in repo.conclusions():
		for r in RouteDB.routes(repo, String(c.get("id", ""))):
			for f in r.frags:
				if String(f.missing) == "" and String(f.cls) == "I" and not seen.has(f.key):
					seen[f.key] = true
					out.append(f)
	for d in RouteDB.all_frags(repo):
		if String(d.missing) != "" or String(d.cls) != "I" or seen.has(d.key):
			continue
		for t in d.tags_any:
			if String(t).begins_with("a:refuta_"):
				seen[d.key] = true
				out.append(d)
				break
	return out

# T2: ningún efecto apunta a un ítem I ni cierra la única fuente de un fragmento I (D9). {errors, pending, notes}
# Un objetivo que no nombra nada de data/ (lugar/área inexistente) es error: el corte no quitaría nada y T3/D1 no lo verían.
static func static_check(repo) -> Dictionary:
	var res := {"errors": [], "pending": [], "notes": []}
	var univ := _universe_i(repo)
	for r in repo.reactions():
		var rid := String(r.get("id", ""))
		for soft in [false, true]:
			if soft and not has_soft(repo, rid):
				continue
			var tag := rid + (" (variante_blanda)" if soft else "")
			for c in cuts_for(repo, rid, soft):
				var t: Dictionary = c.target
				var tp := target_problem(repo, t)
				if tp != "":
					res.errors.append("%s: objetivo de corte desconocido %s: %s" % [tag, J.stringify_canon(_short(t)), tp])
				if t.has("task"):
					var nt := "%s: corta el encargo '%s' (sin fuentes modeladas: la ruta que alimenta debe figurar en corta[] por ref)" % [tag, t.task]
					if not res.notes.has(nt):
						res.notes.append(nt)
				if c.moments.is_empty() and String(c.src) == "corta":
					var nm := "%s: la reacción no puede dispararse según su disparador y el calendario (sus cortes no se modelan en T3)" % tag
					if not res.notes.has(nm):
						res.notes.append(nm)
				if t.has("copy"):
					var cp: Dictionary = repo.copy(String(t.copy))
					if cp.is_empty():
						res.pending.append("%s: ejemplar %s inexistente" % [tag, t.copy])
					elif String(cp.copy.get("class", "I")) == "I":
						res.errors.append("%s: %s apunta al ejemplar I %s" % [tag, c.src, t.copy])
				if t.has("copies") and typeof(t.copies) == TYPE_ARRAY:
					for cid in t.copies:
						var cp2: Dictionary = repo.copy(String(cid))
						if not cp2.is_empty() and String(cp2.copy.get("class", "I")) == "I":
							res.errors.append("%s: retira el ejemplar I %s" % [tag, cid])
				if t.has("route"):
					if t.get("missing", false):
						res.pending.append("%s: ruta %s inexistente" % [tag, t.route])
					else:
						var rt := RouteDB.route_by_id(repo, String(t.route))
						if bool(rt.get("star", false)):
							res.errors.append("%s: corta la ruta sólo-I %s" % [tag, t.route])
						elif t.srcs.is_empty():
							res.errors.append("%s: corta la ruta %s, que no tiene partes no-I (apunta a ítems I)" % [tag, t.route])
				var perm := at(c, 0)
				perm["to_idx"] = TimeKey.idx_count() - 1
				for f in univ:
					var base := 0
					var after := 0
					for sk in f.srcs:
						var s := Av.src(repo, String(sk))
						var m := int(s.get("mask", 0))
						base |= m
						after |= m & ~hit(perm, s)
					if base != 0 and after == 0:
						res.errors.append("%s: %s cierra la única fuente de %s (clase I)" % [tag, J.stringify_canon(_short(t)), f.ref])
	return res

static func _short(t: Dictionary) -> Dictionary:
	var o := {}
	for k in t:
		if not ["srcs", "lost", "flag"].has(k):
			o[k] = t[k]
	if t.has("flag"):
		o["flag"] = t.flag
	return o

# ---------------- T5 ----------------
static func _rastro_tags(repo, r: Dictionary) -> Array:
	var out: Array = []
	var codes := RouteDB.channel_codes(repo)
	for t in r.get("rastro", []):
		if typeof(t) != TYPE_DICTIONARY:
			continue
		for tg in t.get("tags", []):
			out.append(String(tg))
		if t.has("texto"):
			for ch in codes:
				var pt := RouteDB._parse(repo, String(t.texto), {"ch": ch})
				for tr in pt.get("tramos", []):
					out.append_array(RouteDB.flat_tags(tr.tags))
	var d = r.get("doc")
	if typeof(d) == TYPE_DICTIONARY and typeof(d.get("measure")) == TYPE_DICTIONARY:
		for tg in d.measure.get("tags", []):
			var s := String(tg)
			out.append(s if s.contains(":") else "a:" + s)
	return RouteDB.uniq(out)

# Ley de la huella: Holmes (lado holmes/mycroft) que corta → etiquetas de C6/C7/C8; Moran que corta → C10/C13.
static func footprint(repo) -> Dictionary:
	var res := {"errors": [], "pending": []}
	var sets := {"holmes": ["C6", "C7", "C8"], "moran": ["C10", "C13"]}
	var want := {}
	for side in sets:
		var tags := {}
		for cid in sets[side]:
			if repo.conclusion(cid).is_empty():
				res.pending.append("conclusión %s inexistente (ley de la huella, lado %s)" % [cid, side])
			for t in RouteDB.conc_tags(repo, cid):
				tags["a:" + String(t)] = true
		want[side] = tags
	for r in repo.reactions():
		if r.get("corta", []).is_empty():
			continue
		var lado := String(r.get("lado", ""))
		var side := "moran" if lado == "moran" else ("holmes" if lado == "holmes" or lado == "mycroft" else "")
		if side == "":
			continue
		var found := false
		for t in _rastro_tags(repo, r):
			if want[side].has(t):
				found = true
				break
		if not found:
			res.errors.append("%s (lado %s) corta y su rastro no agrega etiquetas de %s" % [r.get("id", "?"), lado, str(sets[side])])
	return res

# Fragmentos con etiquetas a: (rutas, subrutas, tramos, nodos, líneas, escenas, rastros): lo que puede sostener una
# conclusión o una refutación. Las líneas genéricas sin etiquetas no cuentan como corte.
static func universe_frags(repo) -> Array:
	var g := Av.gcache(repo)
	if g.has("univ_frags"):
		return g["univ_frags"]
	var frs: Array = []
	for c in repo.conclusions():
		var cid := String(c.get("id", ""))
		for r in RouteDB.routes(repo, cid):
			frs.append_array(r.frags)
		var subs = c.get("subroutes", {})
		if typeof(subs) == TYPE_DICTIONARY:
			for k in Av.sorted_keys(subs):
				frs.append_array(RouteDB.route_by_id(repo, cid + "." + String(k)).get("frags", []))
	frs.append_array(RouteDB.all_frags(repo))
	var seen := {}
	var out: Array = []
	for f in frs:
		if String(f.missing) != "" or seen.has(f.key):
			continue
		for t in f.tags_any:
			if String(t).begins_with("a:"):
				seen[f.key] = true
				out.append(f)
				break
	g["univ_frags"] = out
	return out

static func universe_srcs(repo) -> Array:
	var g := Av.gcache(repo)
	if g.has("univ_srcs"):
		return g["univ_srcs"]
	var frs: Array = []
	for c in repo.conclusions():
		var cid := String(c.get("id", ""))
		for r in RouteDB.routes(repo, cid):
			frs.append_array(r.frags)
		var subs = c.get("subroutes", {})
		if typeof(subs) == TYPE_DICTIONARY:
			for k in Av.sorted_keys(subs):
				frs.append_array(RouteDB.route_by_id(repo, cid + "." + String(k)).get("frags", []))
	frs.append_array(RouteDB.all_frags(repo))
	var seen := {}
	for f in frs:
		if String(f.missing) != "":
			continue
		var tagged := false
		for t in f.tags_any:
			if String(t).begins_with("a:"):
				tagged = true
				break
		if tagged:
			for k in f.srcs:
				seen[String(k)] = true
	var keys: Array = seen.keys()
	keys.sort()
	g["univ_srcs"] = keys
	return keys

# T5': lo que el efecto quita ⊆ lo que corta[] declara (misma ventana, momento más temprano). Variante blanda aparte.
static func derived_check(repo) -> Dictionary:
	var res := {"errors": [], "pending": []}
	var frs := universe_frags(repo)
	for r in repo.reactions():
		var rid := String(r.get("id", ""))
		for soft in [false, true]:
			if soft and not has_soft(repo, rid):
				continue
			var eff: Array = []
			var decl: Array = []
			for c in cuts_for(repo, rid, soft):
				var start := int(c.from_idx)
				var cc := at(c, start if start >= 0 else 0)
				if c.src == "efecto":
					eff.append(cc)
				else:
					decl.append(cc)
			if eff.is_empty():
				continue
			# alcanzabilidad del fragmento (OR de sus fuentes) con y sin la reacción
			for f in frs:
				var base := 0
				var after_e := 0
				var after_d := 0
				for k in f.srcs:
					var s := Av.src(repo, String(k))
					var m := int(s.get("mask", 0))
					base |= m
					var le := 0
					for c in eff:
						le |= Av.range_mask(int(c.from_idx), int(c.to_idx)) & hit(c, s)
					var ld := 0
					for c in decl:
						ld |= Av.range_mask(int(c.from_idx), int(c.to_idx)) & hit(c, s)
					after_e |= m & ~le
					after_d |= m & ~ld
				var extra := (base & ~after_e) & after_d
				if extra != 0:
					res.errors.append("%s%s: el efecto quita %s en %s sin figurar en corta[]" % [rid, " (variante_blanda)" if soft else "", f.ref, Av.labels(extra)])
	return res

static func _has_gte2(cond) -> bool:
	if typeof(cond) == TYPE_ARRAY:
		for c in cond:
			if _has_gte2(c):
				return true
		return false
	if typeof(cond) != TYPE_DICTIONARY:
		return false
	for k in cond:
		var v = cond[k]
		if (k == "counter" or k == "event_count") and typeof(v) == TYPE_DICTIONARY:
			if (v.has("gte") and int(v.gte) >= 2) or (v.has("gt") and int(v.gt) >= 1):
				return true
		if k == "all" or k == "any":
			if _has_gte2(v):
				return true
	return false

# HB11: una reacción que cierra un canal exige ≥2 reacciones previas de ese canal (n_in ≥ 2 o condición ≥2).
static func hb11_check(repo) -> Dictionary:
	var res := {"errors": [], "checked": []}
	for r in repo.reactions():
		var rid := String(r.get("id", ""))
		var closes := false
		for c in cuts_for(repo, rid, false):
			if c.target.has("channel"):
				closes = true
		if not closes:
			continue
		res.checked.append(rid)
		var disp = r.get("disparador", {})
		var nin: Array = disp.get("n_in", []) if typeof(disp) == TYPE_DICTIONARY else []
		var ok_n := not nin.is_empty()
		for x in nin:
			if int(x) < 2:
				ok_n = false
		if not ok_n and not _has_gte2(r.get("condiciones", {})):
			res.errors.append("%s cierra un canal sin exigir ≥2 reacciones previas del canal (disparador.n_in ≥ 2 o condición counter/event_count ≥ 2)" % rid)
	return res
