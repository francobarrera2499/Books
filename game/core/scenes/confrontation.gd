# core/scenes/confrontation.gd — la confrontación del día 10 en la tienda de Crane (GDD §8.8, §5.7; T18). Dueño: W2-SCENES.
# Cuatro afirmaciones del librero, en orden, cada una con su grupo refutador propio (GROUPS). Un ítem (recorte o
# asiento) acierta si sus etiquetas internas (Clipper.get_clip.tags / Validator.entry_tags) contienen una del grupo.
#   item {} = callar: no es error y pasa a la siguiente afirmación.
#   Error: NO avanza (se puede volver a intentar mientras dure la paciencia, como en Ace Attorney):
#     1.º recoge el paquete · 2.º se pone el sombrero · 3.º se va («Buenos días, señor.»): confront_estado = incompleta.
#   Acierto: avanza. 4 aciertos: nota en el tomo VI, oferta de la errata a medida (errata_ofrecida = librero si
#     Mycroft no la ofreció), pedido de silencio; confront_estado = completa.
#   Terminar las cuatro con algún silencio y <3 errores: se va sin más (confront_estado queda ""; ver informe W2-SCENES).
#   Material secreto_camden: el librero no lo lee (§2.4, D10): cuenta como error, nunca como acierto.
#   Una sola vez: terminada, todo act_confront da err "terminada".
# Textos (por id, en este orden): dialogue/librero.json (recomendado: WorldModel.start_scene de W2-SIM dice TODAS las
#   líneas de scenes/HC07.json al empezar), luego scenes/HC07.json, luego ui_text "scenes.<id>". Ids: "conf.<n>"
#   (afirmación), "conf.<n>.si", "conf.<n>.no", "conf.paquete", "conf.sombrero", "conf.se_va", "conf.nota",
#   "conf.oferta", "conf.silencio", "conf.fin". ${acto} en conf.3.si = etiqueta del acto citado (entidad act.<seq>).
# No hay evento público (§3.6). Las líneas quedan como dichas (origen S.HC07), recortables.
extends RefCounted

const Deps = preload("res://core/scenes/deps.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Markup = preload("res://core/text/markup.gd")

const GROUPS := [["harris_es_moran"], ["cornisa_existe", "raspadura_registrada"], ["ancla_*"], ["librero_falso"]]
const PATIENCE := ["paquete", "sombrero"]
const MAX_ERRORS := 3
const SCENE := "HC07"
const ORIGIN := "S.HC07"
const WHO := "librero"

static func init_state(st, repo) -> void:
	if typeof(st.scenes) != TYPE_DICTIONARY:
		st.scenes = {}
	st.scenes["confront"] = Deps.defaults().confront

# Empieza la confrontación (W2-SIM al entrar en fase confront). Idempotente. Dice la 1.ª afirmación.
static func start(st, repo) -> void:
	var S := Deps.ensure(st)
	var C: Dictionary = S.confront
	if bool(C.get("started", false)):
		return
	C["started"] = true
	C["step"] = 1
	C["statement"] = String(_say(st, repo, "conf.1", {}).uid)

static func act_confront(st, repo, a) -> Dictionary:
	var C0: Dictionary = Deps.sc(st, "confront")
	if bool(C0.get("done", false)):
		return {"ok": false, "err": "terminada"}
	var step := int(a.get("step", 0))
	var cur := int(C0.get("step", 0)) if bool(C0.get("started", false)) else 1
	if step != cur:
		return {"ok": false, "err": "paso"}
	var item = a.get("item", {})
	if item == null:
		item = {}
	if typeof(item) != TYPE_DICTIONARY:
		return {"ok": false, "err": "forma"}
	var silent: bool = item.is_empty()
	if not silent:
		if not ["clip", "entry"].has(String(item.get("kind", ""))):
			return {"ok": false, "err": "forma"}
		if not Deps.item_exists(st, item):
			return {"ok": false, "err": "no_existe"}
	# --- desde aquí la acción es válida y muta ---
	start(st, repo)
	var S := Deps.ensure(st)
	var C: Dictionary = S.confront
	var lines: Array = []
	var hit := false
	var camden := false
	if silent:
		C.answers.append({"step": step, "item": {}, "hit": false, "silent": true})
	else:
		camden = Deps.item_camden(st, repo, item)
		hit = not camden and _hits(Deps.item_tags(st, item), GROUPS[step - 1])
		C.answers.append({"step": step, "item": {"kind": String(item.kind), "id": String(item.id)}, "hit": hit, "silent": false})
	var line := {}
	if hit:
		C["hits"] = int(C.hits) + 1
		line = _say(st, repo, "conf.%d.si" % step, {"acto": _act_label(st, repo, item)})
		lines.append(line)
	elif not silent:
		C["errors"] = int(C.errors) + 1
		line = _say(st, repo, "conf.%d.no" % step, {})
		lines.append(line)
		var n := int(C.errors)
		if n < MAX_ERRORS:
			lines.append(_say(st, repo, "conf." + PATIENCE[n - 1], {}))
		else:
			lines.append(_say(st, repo, "conf.se_va", {}))
			_finish(st, repo, C, "incompleta")
			return _res(hit, line, lines, C)
	if hit or silent:
		if step >= GROUPS.size():
			if int(C.hits) >= GROUPS.size():
				lines.append(_say(st, repo, "conf.nota", {}))
				if String(Deps.flags(st).get("errata_ofrecida", "")) == "":
					st.flags["errata_ofrecida"] = "librero"
					lines.append(_say(st, repo, "conf.oferta", {}))
				lines.append(_say(st, repo, "conf.silencio", {}))
				_finish(st, repo, C, "completa")
			else:
				lines.append(_say(st, repo, "conf.fin", {}))
				_finish(st, repo, C, "")
		else:
			C["step"] = step + 1
			var stl := _say(st, repo, "conf.%d" % (step + 1), {})
			C["statement"] = String(stl.uid)
			lines.append(stl)
	return _res(hit, line, lines, C)

# {step, statement:{uid,who,text}|{}, errors, hits, done, patience:[restantes], estado, started}
static func status(st) -> Dictionary:
	var C: Dictionary = Deps.sc(st, "confront")
	var stmt := {}
	if String(C.get("statement", "")) != "" and not bool(C.get("done", false)):
		stmt = Dialogue.line(st, String(C.statement))
	var errors := int(C.get("errors", 0))
	var pat: Array = []
	for i in range(mini(errors, PATIENCE.size()), PATIENCE.size()):
		pat.append(PATIENCE[i])
	return {"step": int(C.get("step", 0)), "statement": stmt, "errors": errors, "hits": int(C.get("hits", 0)),
		"done": bool(C.get("done", false)), "patience": pat, "estado": String(C.get("estado", "")), "started": bool(C.get("started", false))}

# ---------------- internos ----------------
static func _finish(st, repo, C: Dictionary, estado: String) -> void:
	C["done"] = true
	C["estado"] = estado
	C["statement"] = ""
	if estado != "":
		st.flags["confront_estado"] = estado

static func _res(hit: bool, line: Dictionary, lines: Array, C: Dictionary) -> Dictionary:
	return {"ok": true, "hit": hit, "line": line, "lines": lines, "errors": int(C.errors), "done": bool(C.done), "step": int(C.step)}

static func _hits(tags: Array, group: Array) -> bool:
	var vals := Deps.tag_values(tags, "a")
	for g in group:
		var gs := String(g)
		if gs.ends_with("*"):
			var pre := gs.trim_suffix("*")
			for v in vals:
				if String(v).begins_with(pre):
					return true
		elif vals.has(gs):
			return true
	return false

static func _say(st, repo, id: String, vars: Dictionary) -> Dictionary:
	var text := ""
	var found := false
	for src in [repo.dialogue(WHO).get("lines", []), repo.scene(SCENE).get("lines", [])]:
		for ln in src:
			if typeof(ln) == TYPE_DICTIONARY and String(ln.get("id", "")) == id:
				text = String(ln.get("text", ""))
				found = true
				break
		if found:
			break
	if not found:
		text = String(repo.texts().get("scenes." + id, "")) if repo.has_method("texts") else ""
	text = Deps.cap_first(Deps.fill(repo, text, vars))
	return Dialogue.say_line(st, repo, WHO, text, {"origin": ORIGIN, "scene": SCENE, "id": id, "kind": "confrontacion"})

# La etiqueta del acto dicha en voz alta: «asiento 214, mar. 27» -> «asiento 214, el martes 27» (W4: el anciano no habla
# en abreviaturas de fichero). Días de scenes.wd.<código ASCII>.
const WD_ABBR := {"lun": "lun", "mar": "mar", "mié": "mie", "mie": "mie", "jue": "jue", "vie": "vie", "sáb": "sab", "sab": "sab", "dom": "dom"}

static func _spoken(repo, lab: String) -> String:
	var rx := RegEx.create_from_string("(lun|mar|mié|mie|jue|vie|sáb|sab|dom)[.] ([0-9]+)")
	var out := lab
	for m in rx.search_all(lab):
		var code := String(WD_ABBR.get(m.get_string(1), ""))
		var wd := Deps.txt(repo, "scenes.wd." + code, {}, "")
		if code != "" and wd != "":
			out = out.replace(m.get_string(0), "el %s %s" % [wd, m.get_string(2)])
	return out

# Etiqueta del acto propio citado por el ítem (entidad act.<seq> visible en el recorte o en los recortes del asiento).
static func _act_label(st, repo, item: Dictionary) -> String:
	var clips: Array = []
	if String(item.get("kind", "")) == "entry":
		clips = Deps.entry_clip_ids(st, String(item.get("id", "")))
	else:
		clips = [String(item.get("id", ""))]
	for cid in clips:
		var v: Dictionary = Deps.clipper().visible(st, cid)
		for e in v.get("ents", []):
			var id := String(e.get("id", "")) if typeof(e) == TYPE_DICTIONARY else String(e)
			if id.begins_with("act."):
				var lab := Deps.ent_label(v.ents, id)
				return Markup.escape(Deps.cap_first(_spoken(repo, lab if lab != "" else id)))
	return Deps.txt(repo, "scenes.conf.acto_def", {}, "Usted sabe cuándo")
