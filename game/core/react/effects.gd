# core/react/effects.gd — aplica una instancia de reacción al mundo (ARCHITECTURE §5.3, §4.9). Dueño: W2-REACT.
# apply(st, repo, inst, soft): soft = variante_blanda (D1). Efectos documentales (carta, columna, noticia) crean el
#   documento runtime con WorldModel.instantiate_doc y lo entregan con WorldModel.deliver (sin aviso de «reacción»):
#   voz A por correo (matasellos S.W.) o en mano si ese día no hay correo (domingo, HC03); voz B en la columna del Times
#   del día si contesta algo publicado o carta «—S.» si contesta algo privado (Ley 5: lo de K-W/K-H nunca sale en la
#   columna, T23); Moran por nota en mano (Pell o «H.» si pell_despedido); respuestas por correo.
#   Las cartas de voz A (y las de voz B) de una misma mañana van en UNA carta: el Director marca merged_into/blocks.
# Efectos de mundo: el estado vive en st.react.world (dueño W2-REACT) y se consulta con los accesores de abajo
#   (WorldModel/Clock/Dialogue/UI): withdrawn, closed, variants, silhouettes, nodes, lines, torn, scenes, scene_extra,
#   events, payments. Flags: sólo los que el registro §3.9 asigna a Effects (EFFECT_FLAGS, canal_cerrado.*).
# v3 (GDD_v3 §4): retirar/devolver copias "relacionada" (HA5/HA6: el original del acto, que vuelve solo al amanecer con
#   una marca a lápiz: st.react.world.marcas[copia] = [{tk, texto, mano, iid}], accesor marcas()); alterar_lugar con
#   `dias` (capas con ventana; conviven: place_variant = "registrada+techos"); rastros N: de una variante con duración
#   llevan to_tk; withdrawn[c].rid (examine «missing/<copia>»: withdrawn_by).
# Dependencia: react no precarga sim/ (§1); WorldModel se carga con load() en tiempo de ejecución. `sink` (tests) lo
#   reemplaza: objeto con instantiate_doc(st, repo, tpl, vars, meta) -> String y deliver(st, repo, view, how).
extends RefCounted

const L = preload("res://core/util/log.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Markup = preload("res://core/text/markup.gd")
const RDB = preload("res://core/react/reaction_db.gd")
const Latency = preload("res://core/react/latency.gd")

const EFFECT_FLAGS := ["watson_avisado", "watson_expuesto", "consulta_cerrada_hasta", "hudson_cerrada", "wiggins_aliado",
	"wiggins_quemado", "pell_despedido", "seguido_por_cochero"]
const WORLD_KEYS := {"withdrawn": {}, "closed": {}, "variants": {}, "silhouettes": [], "nodes": [], "lines": [], "torn": {},
	"scenes": {}, "scene_extra": {}, "events": [], "payments": [], "marcas": {}, "returns": []}
# v3 (GDD_v3 §4): variantes de lugar que conviven (techos + registrada): el nombre compuesto es la lista ordenada unida
# con "+" ("registrada+techos"); data/places/L1.json define esa combinación como una variante más.
const VARIANT_JOIN := "+"
# Tope de intrusiones por partida (GDD_v3 §4.1; el usuario: «2-3 por partida»): contador "intrusiones" (lo suma
# alterar_lugar en L1). Lo miran las condiciones de HA6/M1 al disparar y el Director al entregar (dos en cola a la vez).
const MAX_INTRUSIONES := 3

# ¿La regla cambia la pieza (alterar_lugar en L1, también en su variante blanda)? = es una intrusión.
static func alters_home(rule: Dictionary) -> bool:
	var effs: Array = RDB._as_arr(rule.get("efecto", [])).duplicate()
	if typeof(rule.get("variante_blanda")) == TYPE_DICTIONARY:
		effs.append_array(RDB._as_arr(rule.variante_blanda.get("efecto", [])))
	for e in effs:
		if typeof(e) == TYPE_DICTIONARY and String(e.get("op", "")) == "alterar_lugar" and String(e.get("place", "")) == "L1":
			return true
	return false
const WM_PATH := "res://core/sim/world_model.gd"

static var sink = null
static var _wm = null

static func init_world(st) -> void:
	if typeof(st.react) != TYPE_DICTIONARY:
		st.react = {}
	if typeof(st.react.get("world")) != TYPE_DICTIONARY:
		st.react["world"] = {}
	var w: Dictionary = st.react.world
	for k in WORLD_KEYS:
		if typeof(w.get(k)) != typeof(WORLD_KEYS[k]):
			w[k] = WORLD_KEYS[k].duplicate()

# ---------------- aplicar ----------------
static func apply(st, repo, inst: Dictionary, soft: bool) -> void:
	init_world(st)
	var rule := rule_of(repo, inst)
	if rule.is_empty():
		L.w("effects", "reacción inexistente: %s" % inst.get("rid", ""))
		return
	inst["soft"] = soft
	if not inst.has("due_tk"):
		inst["due_tk"] = int(inst.get("tk", inst.get("anchor", {}).get("tk", 0)))
	if inst.get("vars", {}).is_empty():
		inst["vars"] = RDB.vars_for(st, repo, rule, inst)
	var overflow := bool(inst.get("overflow", false))
	var effs := RDB.effects_for(st, repo, rule, inst, soft)
	var applied: Array = []
	var day := TimeKey.day_of(int(inst.get("due_tk", 0)))
	var is_moran := RDB.lado(rule) == "moran"
	var has_scene := false
	for e in effs:
		if String(e.get("op", "")) == "escena":
			has_scene = true
	# documento
	var de := RDB.doc_effect(st, repo, rule, inst, soft)
	if not de.is_empty() and not overflow and String(inst.get("merged_into", "")) == "" and _blank(instance_text(st, repo, inst)) \
			and not (is_moran and not RDB._as_arr(st.react.get("moran", {}).get("next_lines", [])).is_empty()):
		# Ningún rastro con texto para este ancla/canal (p. ej. una regla «*» sin plantilla para ese canal): no se
		# entrega un sobre vacío a la bandeja; los efectos de mundo siguen.
		L.w("effects", "%s: documento sin texto (tpl «%s», canal %s); no se entrega" % [inst.get("iid", ""), inst.get("tpl", ""), inst.get("channel", "")])
		de = {}
	if not de.is_empty() and not overflow:
		if String(inst.get("merged_into", "")) == "":
			if is_moran:
				_take_next_lines(st, repo, inst)
			var how := Latency.how_for(st, repo, rule, inst, de)
			var text := instance_text(st, repo, inst)
			var tpl := doc_tpl(st, repo, rule, inst, de, how, text)
			_fisica_hook(repo, tpl, inst)
			var meta := {"iid": String(inst.iid), "rid": String(inst.rid), "act": String(inst.get("anchor", {}).get("act", "")),
				"how": how, "tk": int(inst.get("due_tk", 0)), "day": day, "channel": String(inst.get("channel", "")),
				"voice": String(inst.get("voice", "")), "lado": RDB.lado(rule), "origin": String(tpl.get("origin", inst.iid)),
				"blocks": inst.get("blocks", []).duplicate(), "en_persona": bool(inst.get("en_persona", false)),
				"insert": tpl.get("insert", {}), "soft": soft}
			if de.has("copia_de"):
				meta["copia_de"] = RDB._s(inst.get("anchor", {}).get(String(de.copia_de), ""))
			var view := _instantiate(st, repo, tpl, inst.vars, meta)
			if view == "":
				view = String(inst.iid)
			_deliver(st, repo, view, how)
			inst["view"] = view
			inst["how"] = how
			inst["text"] = text
			inst["words"] = Markup.parse(text).words.size()
			applied.append(String(de.op))
		else:
			inst["how"] = "fusionada"
			applied.append("fusionada")
	elif is_moran and has_scene and not overflow:
		_take_next_lines(st, repo, inst)
	# efectos de mundo
	for e in effs:
		var op := String(e.get("op", ""))
		if RDB.DOC_OPS.has(op):
			continue
		if overflow and op != "flag" and op != "cerrar":
			continue
		if _apply_op(st, repo, rule, inst, e):
			applied.append(op)
	# rastros que son fragmentos del mundo (N: nodo de lugar, S: línea de escena, L: línea de diálogo, M: medida); los
	# definen sus dueños (lugares, escenas, diálogos): aquí queda constancia y los N: se ofrecen a WorldModel.snapshot.
	# Variante blanda (D1): un rastro-fragmento queda si la variante conserva el efecto que lo produce (M1 blanda: la
	# buhardilla igual queda registrada, con ceniza y pisada, §12.1.3) y cae si no (HB5 blanda: sin préstamo no hay recibo).
	if not overflow:
		var var_to: Dictionary = inst.get("_var_to", {}) if typeof(inst.get("_var_to")) == TYPE_DICTIONARY else {}
		for r in RDB.nodo_rastros(st, repo, rule, inst):
			if soft and not _node_in_effects(String(r.nodo), effs):
				continue
			var ref := String(r.nodo)
			var kind := ref.get_slice(":", 0)
			var body := ref.substr(kind.length() + 1)
			var place := body.get_slice(".", 0) if kind == "N" else ""
			var rec := {"ref": ref, "kind": kind, "place": place, "node": body.substr(body.find(".") + 1) if body.contains(".") else body,
				"tags": RDB._as_arr(r.get("tags", [])).duplicate(), "from_tk": int(inst.get("due_tk", 0)), "rid": String(inst.get("rid", "")),
				"iid": String(inst.get("iid", ""))}
			# v3: el rastro de una variante con duración (la ventana abierta, el registro) dura lo que la variante
			if var_to.has(place):
				rec["to_tk"] = int(var_to[place])
			st.react.world.nodes.append(rec)
			applied.append("nodo")
	inst.erase("_var_to")
	inst["applied"] = applied

# Regla de la instancia; sin rid, efectos en línea (Dialogue: {iid:"LINE.<uid>", rid:"", efecto:[ops], char, line, anchor}).
static func rule_of(repo, inst: Dictionary) -> Dictionary:
	var rid := String(inst.get("rid", ""))
	if rid != "":
		return repo.reaction(rid)
	if typeof(inst.get("efecto")) == TYPE_ARRAY:
		return {"id": "", "tipo": "linea", "lado": String(inst.get("lado", "")), "voz": "", "nivel": 0, "efecto": inst.efecto, "rastro": []}
	return {}

# ¿Algún efecto (ya filtrado) produce el fragmento `ref`? N:<lugar>.x ← alterar_lugar/silueta/cerrar en ese lugar;
# L:<char>.<línea> ← linea de ese personaje y línea; S:<escena>.x ← escena; M:… ← documento de la reacción.
static func _node_in_effects(ref: String, effs: Array) -> bool:
	var kind := ref.get_slice(":", 0)
	var body := ref.substr(kind.length() + 1)
	var head := body.get_slice(".", 0)
	var tail := body.substr(head.length() + 1) if body.contains(".") else ""
	for e in effs:
		var op := String(e.get("op", ""))
		match kind:
			"N":
				if ["alterar_lugar", "silueta", "cerrar"].has(op) and String(e.get("place", String(e.get("target", "")).get_slice(".", 0))) == head:
					return true
			"L":
				if op == "linea" and String(e.get("char", "")) == head and (tail == "" or String(e.get("line", "")) == tail):
					return true
			"S":
				if op == "escena" and String(e.get("scene", "")) == head:
					return true
			"M":
				if RDB.DOC_OPS.has(op):
					return true
	return false

static func _blank(text: String) -> bool:
	return text.strip_edges() == ""

# Líneas pendientes de M10–M12 que se adjuntan a esta comunicación de Moran. Cada una puede traer dos voces
# ({pell, h}: «El mayor celebra…» / «Celebro…»): habla Harris si Pell ya no está (M4: notas «H.») o si la comunicación
# es Harris en persona (canal en_persona: M7); si no, Pell transmite.
static func _take_next_lines(st, repo, inst: Dictionary) -> void:
	var m = st.react.get("moran", {})
	if typeof(m) != TYPE_DICTIONARY:
		return
	var nl: Array = m.get("next_lines", [])
	if nl.is_empty():
		return
	var harris := harris_voice(st, repo, inst)
	var out: Array = []
	for x in nl:
		if typeof(x) == TYPE_DICTIONARY:
			out.append(String(x.get("h", x.get("pell", ""))) if harris else String(x.get("pell", x.get("h", ""))))
		else:
			out.append(String(x))
	inst["extra_lines"] = out
	m["next_lines"] = []

static func harris_voice(st, repo, inst: Dictionary) -> bool:
	if bool(st.flags.get("pell_despedido", false)):
		return true
	var rule := rule_of(repo, inst)
	return RDB.lado(rule) == "moran" and String(rule.get("canal", "")) == "en_persona"

static func _apply_op(st, repo, rule: Dictionary, inst: Dictionary, e: Dictionary) -> bool:
	var w: Dictionary = st.react.world
	var tk := int(inst.get("due_tk", 0))
	var day := TimeKey.day_of(tk)
	var a: Dictionary = inst.get("anchor", {})
	var rid := String(inst.get("rid", ""))
	match String(e.get("op", "")):
		"escena":
			var sc := String(e.get("scene", rid))
			w.scenes[sc] = {"tk": tk, "iid": String(inst.iid)}
			var extra: Array = inst.get("extra_lines", [])
			if not extra.is_empty():
				if not w.scene_extra.has(sc):
					w.scene_extra[sc] = []
				w.scene_extra[sc].append_array(extra)
			st.note("scene", {"scene": sc})
		"linea":
			w.lines.append({"char": String(e.get("char", "")), "line": String(e.get("line", "")), "from_tk": tk, "rid": rid})
		"retirar":
			var copies: Array = []
			if String(e.get("copias", "")) == "informadas":
				copies = RDB._as_arr(a.get("copies", [])).duplicate()
			elif String(e.get("copias", "")) == "relacionada":
				# v3 (HA5/HA6): el original relacionado con el acto, si todavía está en casa cuando entran
				for c in RDB._as_arr(a.get("relacionada", [])):
					if RDB.copy_at_home(st, repo, String(c), tk):
						copies.append(String(c))
			if e.has("copy"):
				copies.append(String(e.copy))
			var to_tk := -1
			if e.get("dias") != null and e.has("dias"):
				to_tk = TimeKey.tk(day + int(e.dias), "dawn")
			for c in copies:
				w.withdrawn[String(c)] = {"from_tk": tk, "to_tk": to_tk, "by": String(inst.iid), "rid": rid}
			inst["withdrawn"] = copies
		"cerrar":
			var target := _fill_name(String(e.get("target", "")), inst).replace("canal:*", "canal:" + String(inst.get("channel", "")))
			var dias = e.get("dias")
			if target.begins_with("canal:"):
				_set_flag(st, "canal_cerrado." + target.trim_prefix("canal:"), true)
			elif target == "L4.consulta":
				var base := int(a.get("day", day))
				_set_flag(st, "consulta_cerrada_hasta", base + (int(dias) if dias != null else 99))
			w.closed[target] = {"from_day": day, "to_day": (int(a.get("day", day)) + int(dias)) if dias != null else -1, "by": String(inst.iid)}
		"silueta":
			var desde := _day_spec(e.get("desde"), day)
			w.silhouettes.append({"who": String(e.get("who", "")), "place": String(e.get("place", "*")), "desde": desde,
				"reemplaza": String(e.get("reemplaza", "")), "rid": rid})
		"flag":
			var name := _fill_name(String(e.get("name", "")), inst)
			return _set_flag(st, name, e.get("value", true))
		"alterar_lugar":
			# v3: dias = la variante dura hasta el amanecer de (día + dias) (GDD_v3 §4.3: «hasta el final del día siguiente»
			# = dias 2); sin dias, para siempre. Varias variantes conviven (capas): place_variant las combina.
			var place := String(e.get("place", ""))
			var vto := -1
			if e.get("dias") != null and e.has("dias"):
				vto = TimeKey.tk(day + int(e.dias), "dawn")
			var prev = w.variants.get(place)
			var layers: Array = []
			if typeof(prev) == TYPE_DICTIONARY:
				if typeof(prev.get("layers")) == TYPE_ARRAY:
					layers = (prev.layers as Array).duplicate(true)
				elif String(prev.get("variant", "")) != "":
					layers.append({"variant": String(prev.variant), "from_tk": int(prev.get("from_tk", 0)), "to_tk": int(prev.get("to_tk", -1)), "rid": String(prev.get("rid", ""))})
			layers.append({"variant": String(e.get("variant", "")), "from_tk": tk, "to_tk": vto, "rid": rid})
			w.variants[place] = {"variant": String(e.get("variant", "")), "from_tk": tk, "to_tk": vto, "rid": rid, "layers": layers}
			# v3 (GDD_v3 §4.1; el usuario: «2-3 por partida»): cada cambio de la pieza es una intrusión; HA6 y M1 no
			# disparan con 3 ya ocurridas (condición {"counter": {"name": "intrusiones", "lt": 3}})
			if place == "L1" and String(e.get("variant", "")) != "":
				st.react.counters["intrusiones"] = int(st.react.counters.get("intrusiones", 0)) + 1
			if vto >= 0:
				if typeof(inst.get("_var_to")) != TYPE_DICTIONARY:
					inst["_var_to"] = {}
				inst._var_to[place] = vto
		"devolver":
			# Los originales vuelven intactos (Ley 3). No son documentos runtime: no se «entregan» con deliver (WorldModel
			# sólo entrega instancias de st.world.docs); se levanta el retiro y se avisa a WorldModel con return_copy. El
			# paquete del mostrador de Crane es el documento de la propia reacción (HB10: carta con entrega mostrador_crane).
			# v3 (HA5/HA6): copias "relacionada" + al "amanecer": vuelve solo al amanecer siguiente a su lugar del estante,
			# con una marca chica a lápiz (marca {texto, mano}) que WorldModel.view muestra al margen (Effects.marcas).
			var back: Array = []
			if String(e.get("copias", "")) == "relacionada":
				back = RDB._as_arr(inst.get("withdrawn", [])).duplicate()
			else:
				back = RDB._as_arr(a.get("copies", [])).duplicate()
			if String(e.get("al", "")) == "amanecer":
				var rtk := TimeKey.tk(day + 1, "dawn")
				var mk = e.get("marca", {})
				# entraron de noche mientras Lisle dormía (se aplica al amanecer): «la mañana siguiente» (Crane oyó los pasos,
				# techos.manana) es ésta; lo que se llevaron igual falta todo el día y vuelve al amanecer siguiente
				var ya := TimeKey.slot_of(tk) == "dawn"
				if ya:
					st.react.counters["techos.manana"] = int(st.react.counters.get("techos.manana", 0)) + 1
				for c in back:
					w.returns.append({"copy": String(c), "tk": rtk, "iid": String(inst.iid), "rid": rid,
						"marca": mk.duplicate(true) if typeof(mk) == TYPE_DICTIONARY else {}, "cuenta": not ya})
				# la mañana siguiente cuenta aunque no se hayan llevado nada (variante blanda: sólo la ventana)
				w.returns.append({"copy": "", "tk": rtk, "iid": String(inst.iid), "rid": rid, "marca": {}, "cuenta": not ya})
				inst["returns_at"] = rtk
				return true
			for c in back:
				w.withdrawn.erase(String(c))
				_return_copy(st, String(c))
			inst["returned"] = back
		"paga":
			w.payments.append({"amount_d": int(e.get("amount_d", 0)), "tk": tk, "rid": rid})
		"arrancar":
			w.torn[String(e.get("copy", ""))] = {"tk": tk, "rid": rid, "part": String(e.get("part", ""))}
		"linea_siguiente_comunicacion":
			var src := String(e.get("text", ""))
			if src == "" and e.has("tpl"):
				src = String(RDB.rastro_by_tpl(rule, String(e.tpl)).get("texto", ""))
			if src == "":
				var r := RDB.select_rastro(st, repo, rule, inst)
				src = String(r.get("texto", ""))
			if src != "":
				# voz de Harris (`<tpl>_h`, primera persona) para cuando la comunicación sea suya (M7, notas «H.»)
				var txt := Markup.fill(src, inst.get("vars", {}))
				var rh := RDB.rastro_by_tpl(rule, String(e.get("tpl", "")) + "_h") if e.has("tpl") else {}
				if rh.has("texto"):
					st.react.moran.next_lines.append({"pell": txt, "h": Markup.fill(String(rh.texto), inst.get("vars", {}))})
				else:
					st.react.moran.next_lines.append(txt)
		"evento_mundo":
			w.events.append({"id": String(e.get("id", "")), "tk": tk, "rid": rid})
		_:
			L.w("effects", "op desconocida: %s (%s)" % [e.get("op", ""), rid])
			return false
	return true

# desde: int (día) | "3.dawn" (tk) | "+1" (relativo al día de entrega) | null (el día de entrega)
static func _day_spec(v, day: int) -> int:
	match typeof(v):
		TYPE_NIL:
			return day
		TYPE_INT, TYPE_FLOAT:
			return int(v)
		TYPE_STRING:
			var s := String(v)
			if s.begins_with("+"):
				return day + int(s.substr(1))
			if s.contains("."):
				var t := TimeKey.of(s)
				return TimeKey.day_of(t) if t >= 0 else day
			if s.is_valid_int():
				return int(s)
	return day

static func _fill_name(s: String, inst: Dictionary) -> String:
	return s.replace("${channel}", String(inst.get("channel", ""))).replace("${ch}", RDB.ch_code(String(inst.get("channel", ""))))

static func _set_flag(st, name: String, value) -> bool:
	if not (EFFECT_FLAGS.has(name) or name.begins_with("canal_cerrado.")):
		L.w("effects", "flag fuera del registro de Effects: %s (lo escribe su dueño)" % name)
		return false
	st.flags[name] = value
	st.note("flag", {"name": name, "value": value})
	return true

# ---------------- texto ----------------
# Texto en marcado (con ${…} resueltos; [[@act|…]] se resuelve al parsear con ctx.act = anchor.act).
static func instance_text(st, repo, inst: Dictionary) -> String:
	var parts := PackedStringArray()
	for b in _blocks(st, inst):
		var t := _block_text(st, repo, b)
		if t != "":
			parts.append(t)
	var txt := "\n\n".join(parts)
	for ln in RDB._as_arr(inst.get("extra_lines", [])):
		txt += ("\n\n" if txt != "" else "") + String(ln)
	var rule := rule_of(repo, inst)
	var firma := _firma(st, repo, rule, inst)
	if firma != "" and txt != "" and not txt.strip_edges().ends_with(firma.trim_prefix("—")):
		txt += "\n—" + firma.trim_prefix("—")
	return txt

static func _blocks(st, inst: Dictionary) -> Array:
	var out: Array = [inst]
	for iid in RDB._as_arr(inst.get("blocks", [])):
		var b := find(st, String(iid))
		if not b.is_empty() and String(b.iid) != String(inst.iid):
			out.append(b)
	return out

static func _block_text(st, repo, inst: Dictionary) -> String:
	var rule := rule_of(repo, inst)
	if rule.is_empty():
		return ""
	var r := RDB.rastro_by_tpl(rule, String(inst.get("tpl", "")))
	if r.is_empty():
		r = RDB.select_rastro(st, repo, rule, inst)
	var src := ""
	if typeof(r.get("tono")) == TYPE_DICTIONARY:
		var tono := String(inst.get("tono", "bajo"))
		src = String(r.tono.get(tono, r.get("texto", "")))
	else:
		src = String(r.get("texto", ""))
	if src == "":
		return ""
	var vars: Dictionary = inst.get("vars", {})
	if vars.is_empty():
		vars = RDB.vars_for(st, repo, rule, inst)
	return Markup.fill(src, vars)

static func _firma(st, repo, rule: Dictionary, inst: Dictionary) -> String:
	if rule.is_empty():
		return ""
	var de := RDB.doc_effect(st, repo, rule, inst, bool(inst.get("soft", false)))
	if de.has("firma"):
		return String(de.firma)
	if ["columna", "noticia"].has(String(de.get("op", ""))):
		return ""
	var d = rule.get("doc", {})
	if typeof(d) == TYPE_DICTIONARY and d.has("firma"):
		if RDB.lado(rule) == "moran" and _flag(st, "pell_despedido"):
			return "H."
		return String(d.firma)
	if RDB.lado(rule) == "moran":
		return "H." if _flag(st, "pell_despedido") else "J. Pell"
	if RDB.voice(rule) == "A" and not RDB.is_column(rule):
		return "Un amigo de la exactitud"
	return ""

static func _flag(st, name: String) -> bool:
	return RDB._flag(st, name)

# ---------------- documento runtime ----------------
static func doc_tpl(st, repo, rule: Dictionary, inst: Dictionary, de: Dictionary, how: String, text: String) -> Dictionary:
	var day := TimeKey.day_of(int(inst.get("due_tk", 0)))
	var date := String(RDB.day_row(repo, day).get("date", ""))
	var op := String(de.get("op", "carta"))
	var t := {}
	if op == "columna" or op == "noticia":
		var md := RDB.mmdd(repo, day)
		var ent := "times_" + md
		if repo.entity(ent).is_empty():
			ent = "times"
		t = {"title": "The Times, %s, %s" % [RDB.date_text(repo, day), "columna de anuncios" if op == "columna" else "noticias"],
			"src_type": "prensa_londres", "class": "I", "font": "imprenta", "paper": "diario", "paper_mm": [380, 540],
			"entity": ent, "origin": "D15." + md, "insert": {"doc": "D15." + md, "part": "columna" if op == "columna" else "noticias"}}
	elif RDB.lado(rule) == "moran":
		var h := _flag(st, "pell_despedido")
		t = {"title": "Nota firmada «H.», lista de correos" if h else "Nota de Pell, en mano", "src_type": "carta_recibida", "class": "P",
			"font": "manuscrito", "paper": "nota", "paper_mm": [180, 115], "entity": "notas_de_pell"}
	elif RDB.voice(rule) == "A" or RDB.voice(rule) == "B":
		var b := RDB.voice(rule) == "B"
		var title := "Carta a máquina, matasellos S.W."
		if how == "en_mano":
			title = "Carta a máquina, sin sello, en mano"
		elif how == "mostrador_crane":
			title = "Tarjeta a máquina, en el mostrador de Crane"
		t = {"title": title, "src_type": "carta_recibida", "class": "P", "font": "maquina", "machine": "remington_cotter",
			"paper": "diogenes_recortado", "paper_mm": [203, 244],
			"entity": "respuestas_s" if b else "cartas_a_maquina"}
	else:
		t = {"title": "Carta", "src_type": "carta_recibida", "class": "P", "font": "maquina", "paper": "carta", "paper_mm": [210, 270],
			"entity": "cartas_a_maquina"}
	if bool(inst.get("en_persona", false)):
		# día 9 → 10.M: la respuesta llega «en persona» (el librero de HC07 deja una nota a lápiz en el mostrador)
		t = {"title": "Nota a lápiz, dejada en el mostrador de Crane", "src_type": "carta_recibida", "class": "P", "font": "manuscrito",
			"paper": "nota", "paper_mm": [150, 95], "entity": "respuestas_s"}
	elif op == "carta":
		var d = rule.get("doc", {})
		if typeof(d) == TYPE_DICTIONARY:
			for k in d:
				if String(k) == "firma" or String(k).begins_with("_"):
					continue
				t[k] = d[k].duplicate(true) if typeof(d[k]) in [TYPE_ARRAY, TYPE_DICTIONARY] else d[k]
		if de.has("title"):
			t["title"] = String(de.title)
		if RDB.lado(rule) == "moran" and _flag(st, "pell_despedido"):
			t["title"] = "Nota firmada «H.», lista de correos"
		elif how == "en_mano" and RDB.lado(rule) != "moran":
			# HC03: el domingo la carta llega por debajo de la puerta, sin sello
			var tt := String(t.get("title", "Carta"))
			if tt.contains("matasellos S.W."):
				tt = tt.replace("matasellos S.W.", "sin sello, en mano")
			elif not tt.contains("en mano"):
				tt += ", sin sello, en mano"
			t["title"] = tt
	if repo.entity(String(t.get("entity", ""))).is_empty() and not repo.entities().is_empty():
		t["entity"] = "cartas_a_maquina" if not repo.entity("cartas_a_maquina").is_empty() else String(t.get("entity", ""))
	t["id"] = String(inst.iid)
	t["date"] = date
	t["chron_date"] = date
	if not t.has("origin"):
		t["origin"] = String(inst.iid)
	t["parts"] = [{"id": "p1", "text": text}]
	t["copies"] = []
	t["words"] = Markup.parse(text).words.size()
	t["src_en"] = {}
	t["firma"] = _firma(st, repo, rule, inst)
	return t

# GDD_v2 §C.5.2 (gancho de PROGRESIÓN): un documento generado que llega como papel propio (carta, nota, tarjeta,
# telegrama, copia) lleva al principio la línea de descripción física de su plantilla (data/fisica.json plantillas, por
# doc.entity), igual que los documentos estáticos. Lo que se inserta en un número del Times (columna, noticias) no: ese
# papel ya tiene la suya. La nota «en persona» del día 10 (a lápiz) no usa la plantilla de las cartas a máquina.
static func _fisica_hook(repo, tpl: Dictionary, inst: Dictionary) -> void:
	if repo == null or not repo.has_method("fisica_tpl_line") or bool(inst.get("en_persona", false)):
		return
	if typeof(tpl.get("insert")) == TYPE_DICTIONARY and not (tpl.insert as Dictionary).is_empty():
		return
	var parts = tpl.get("parts", [])
	if typeof(parts) != TYPE_ARRAY or parts.is_empty() or typeof(parts[0]) != TYPE_DICTIONARY:
		return
	var ent := String(tpl.get("entity", ""))
	var ln := String(repo.fisica_tpl_line(ent, tpl.get("paper_mm", [])))
	if ln == "":
		return
	parts[0]["text"] = ln + "\n" + String(parts[0].get("text", ""))
	var spec = repo.fisica().get("plantillas", {}).get(ent, {})
	if typeof(spec) == TYPE_DICTIONARY and typeof(spec.get("mm")) == TYPE_ARRAY and (spec.mm as Array).size() == 2:
		tpl["paper_mm"] = (spec.mm as Array).duplicate()

static func _instantiate(st, repo, tpl: Dictionary, vars: Dictionary, meta: Dictionary) -> String:
	if sink != null:
		return String(sink.instantiate_doc(st, repo, tpl, vars, meta))
	var wm = _world_model()
	if wm == null:
		return ""
	return String(wm.instantiate_doc(st, repo, tpl, vars, meta))

static func _deliver(st, repo, view: String, how: String) -> void:
	if sink != null:
		sink.deliver(st, repo, view, how)
		return
	var wm = _world_model()
	if wm != null:
		wm.deliver(st, repo, view, how)

static func _return_copy(st, copy_id: String) -> void:
	if sink != null:
		if sink.has_method("return_copy"):
			sink.return_copy(st, copy_id)
		return
	var wm = _world_model()
	if wm != null and wm.has_method("return_copy"):
		wm.return_copy(st, copy_id)

static func _world_model():
	if _wm == null and ResourceLoader.exists(WM_PATH):
		_wm = load(WM_PATH)
	return _wm

# ---------------- búsqueda ----------------
static func find(st, iid: String) -> Dictionary:
	if typeof(st.react) != TYPE_DICTIONARY:
		return {}
	for k in ["queue", "delivered"]:
		for i in st.react.get(k, []):
			if String(i.get("iid", "")) == iid:
				return i
	return {}

# ---------------- accesores del estado de mundo (para WorldModel, Clock, Dialogue y la UI) ----------------
static func _w(st) -> Dictionary:
	if typeof(st.react) != TYPE_DICTIONARY or typeof(st.react.get("world")) != TYPE_DICTIONARY:
		return WORLD_KEYS.duplicate(true)
	return st.react.world

# ¿El ejemplar está retirado (M1, HB5) en ese tk? to_tk -1 = permanente.
static func copy_withdrawn(st, copy_id: String, tk: int) -> bool:
	var w := _w(st)
	var r = w.withdrawn.get(copy_id)
	if typeof(r) != TYPE_DICTIONARY:
		return false
	if tk < int(r.from_tk):
		return false
	return int(r.to_tk) < 0 or tk < int(r.to_tk)

static func withdrawn(st, tk: int) -> Array:
	var out: Array = []
	var ks: Array = _w(st).withdrawn.keys()
	ks.sort()
	for c in ks:
		if copy_withdrawn(st, String(c), tk):
			out.append(String(c))
	return out

# target: "L4.consulta", "L5.forasteros", "L3.recibos", "canal:K-H"… ; to_day -1 = permanente
static func access_closed(st, target: String, day: int) -> bool:
	var r = _w(st).closed.get(target)
	if typeof(r) != TYPE_DICTIONARY:
		return false
	return day >= int(r.from_day) and (int(r.to_day) < 0 or day <= int(r.to_day))

# Variante del lugar en tk (-1 = ahora). v3: capas con ventana from/to; si conviven varias, nombre compuesto ordenado
# ("registrada+techos"). Un registro sin capas (formato anterior) vale siempre.
static func place_variant(st, place: String, tk := -1) -> String:
	var r = _w(st).variants.get(place)
	if typeof(r) != TYPE_DICTIONARY:
		return ""
	if typeof(r.get("layers")) != TYPE_ARRAY:
		return String(r.get("variant", ""))
	var t := tk if tk >= 0 else _now(st)
	var names: Array = []
	for l in r.layers:
		if typeof(l) != TYPE_DICTIONARY:
			continue
		var f := int(l.get("from_tk", 0))
		var u := int(l.get("to_tk", -1))
		if t >= f and (u < 0 or t < u) and String(l.get("variant", "")) != "" and not names.has(String(l.variant)):
			names.append(String(l.variant))
	names.sort()
	return VARIANT_JOIN.join(PackedStringArray(names))

# Variantes activas por separado (["registrada", "techos"]).
static func place_variants(st, place: String, tk := -1) -> Array:
	var v := place_variant(st, place, tk)
	return [] if v == "" else Array(v.split(VARIANT_JOIN, false))

static func _now(st) -> int:
	if st.get("now_tk") != null and int(st.now_tk) >= 0:
		return int(st.now_tk)
	var c = st.clock if typeof(st.clock) == TYPE_DICTIONARY else {}
	var slot := String(c.get("slot", "M"))
	return TimeKey.tk(int(c.get("day", 0)), slot if TimeKey.ORD.has(slot) else "M")

# v3 (GDD_v3 §4.2): al amanecer, lo que se llevaron los de Holmes vuelve a su lugar con la marca a lápiz. Lo llama el
# Director en on_time(dawn). Cuenta la «mañana siguiente» de cada intrusión por los techos en st.react.counters
# ["techos.manana"] (lo usa la línea de Crane pasos_techo: {"counter": {"name": "techos.manana", "gte": 1}}).
static func process_returns(st, repo, tk: int) -> void:
	init_world(st)
	var w: Dictionary = st.react.world
	var keep: Array = []
	var counted := {}
	for r in w.returns:
		if typeof(r) != TYPE_DICTIONARY:
			continue
		if int(r.get("tk", 0)) > tk:
			keep.append(r)
			continue
		var iid := String(r.get("iid", ""))
		if not counted.has(iid) and bool(r.get("cuenta", true)):
			counted[iid] = true
			st.react.counters["techos.manana"] = int(st.react.counters.get("techos.manana", 0)) + 1
		var c := String(r.get("copy", ""))
		if c == "":
			continue
		var wd = w.withdrawn.get(c)
		# si entretanto otro (M1) se lo llevó, vuelve cuando ése lo devuelva
		if typeof(wd) == TYPE_DICTIONARY and String(wd.get("by", "")) == iid:
			w.withdrawn.erase(c)
		var mk: Dictionary = r.get("marca", {}) if typeof(r.get("marca")) == TYPE_DICTIONARY else {}
		if String(mk.get("texto", "")) != "":
			if typeof(w.marcas.get(c)) != TYPE_ARRAY:
				w.marcas[c] = []
			w.marcas[c].append({"tk": int(r.tk), "texto": String(mk.texto), "mano": String(mk.get("mano", "copista")), "iid": iid})
		_return_copy(st, c)
		st.note("tray", {"returned": c, "by": iid})
	w.returns = keep

# Marcas a lápiz de un ejemplar visibles en tk (-1 = ahora): [{tk, texto, mano, iid}] (origen del bloque = iid, P, sin
# etiquetas). WorldModel.view (CORE) las arma como bloques «margen».
static func marcas(st, copy_id: String, tk := -1) -> Array:
	var m = _w(st).marcas.get(copy_id)
	if typeof(m) != TYPE_ARRAY:
		return []
	var t := tk if tk >= 0 else _now(st)
	var out: Array = []
	for x in m:
		if typeof(x) == TYPE_DICTIONARY and int(x.get("tk", 0)) <= t:
			out.append(x.duplicate(true))
	return out

# Pendientes de volver (para depuración y tests): [{copy, tk, iid, rid}].
static func pending_returns(st) -> Array:
	var out: Array = []
	for r in _w(st).returns:
		if typeof(r) == TYPE_DICTIONARY and String(r.get("copy", "")) != "":
			out.append(r.duplicate(true))
	return out

# Quién se llevó un ejemplar que falta ahora ("" si no falta): rid de la reacción (HA5, HA6, M1, HB5…). Para
# examine {ref: "missing/<copia>"} (GDD_v3 §4.4).
static func withdrawn_by(st, copy_id: String, tk := -1) -> String:
	var t := tk if tk >= 0 else _now(st)
	if not copy_withdrawn(st, copy_id, t):
		return ""
	var r: Dictionary = _w(st).withdrawn.get(copy_id, {})
	var rid := String(r.get("rid", ""))
	if rid == "":
		rid = String(r.get("by", "")).get_slice(".", 1)
	return rid

# Siluetas visibles en un lugar y día (HC02 Wiggins desde el 3, M3 en L4, M11 cochero, HB8b reemplaza a Wiggins).
static func silhouettes(st, place: String, day: int) -> Array:
	var out: Array = []
	var gone: Array = []
	for s in _w(st).silhouettes:
		if (String(s.place) == "*" or String(s.place) == place) and day >= int(s.desde):
			if not out.has(String(s.who)):
				out.append(String(s.who))
			if String(s.get("reemplaza", "")) != "":
				gone.append(String(s.reemplaza))
	for g in gone:
		out.erase(g)
	return out

static func extra_nodes(st, place: String, tk: int) -> Array:
	var out: Array = []
	for n in _w(st).nodes:
		if String(n.place) == place and tk >= int(n.from_tk) and (int(n.get("to_tk", -1)) < 0 or tk < int(n.get("to_tk", -1))):
			out.append(n.duplicate(true))
	return out

static func lines(st, char_id: String, tk := -1) -> Array:
	var out: Array = []
	for l in _w(st).lines:
		if String(l.char) == char_id and (tk < 0 or tk >= int(l.from_tk)):
			out.append(String(l.line))
	return out

static func torn(st, copy_id: String) -> bool:
	return _w(st).torn.has(copy_id)

static func scene_extra(st, scene_id: String) -> Array:
	return RDB._as_arr(_w(st).scene_extra.get(scene_id, [])).duplicate()

static func world_events(st) -> Array:
	return _w(st).events.duplicate(true)

static func payments(st) -> Array:
	return _w(st).payments.duplicate(true)
