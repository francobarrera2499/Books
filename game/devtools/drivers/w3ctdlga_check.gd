# Diagnóstico W3-CT-DLG-A: fragmentos del contrato (§4.8) y rastros que viven en dialogue/{watson,mrs_hudson,wiggins,
# chico_del_agente,ujier}.json y scenes/{HC05,AGENTE}.json, sobre data/ real.
# ./godot.sh --headless -s devtools/drivers/w3ctdlga_check.gd
# Imprime: errores de carga propios; por ref, lo que promete RouteDB (etiquetas, entidades, origen, faltante); por ruta
# de conclusions.json que usa un ref propio, el enlace por claves; y, por personaje, la respuesta por capas a cada
# afirmación y a una muestra de temas (Dialogue.respond con un estado mínimo), para revisar voz y cobertura.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const PlaySession = preload("res://devtools/bots/play_session.gd")
const Clipper = preload("res://core/deduction/clipper.gd")

const FILES := ["dialogue/watson.json", "dialogue/mrs_hudson.json", "dialogue/wiggins.json", "dialogue/chico_del_agente.json",
	"dialogue/ujier.json", "scenes/HC05.json", "scenes/AGENTE.json", "entities/dlg_a.json"]
const REFS := ["L:watson.escribi_mycroft", "L:mrs_hudson.mycroft_paga", "L:mrs_hudson.ordenes", "L:wiggins.vieja_tarifa",
	"L:wiggins.conduit", "L:chico_del_agente.vino_un_caballero", "S:HC05.jueves_a", "S:HC05.jueves_b", "S:AGENTE.militar"]
const CHARS := ["watson", "mrs_hudson", "wiggins", "chico_del_agente", "ujier"]
const TOPICS := ["holmes", "mycroft", "watson", "mrs_hudson", "wiggins", "lisle", "fina", "reichenbach", "221b", "alquiler",
	"camden_house", "harris", "jueves", "papeleta", "cotter", "tomos", "mary_watson", "journal_de_geneve", "perro_perdido"]

func _init() -> void:
	_run.call_deferred()

func _mine(ref: String) -> bool:
	return REFS.has(ref) or ref.begins_with("S:HC05.") or ref.begins_with("S:AGENTE.")

func _run() -> void:
	var r = Repo.fresh("res://data")
	var errs: Array = []
	for e in r.errors():
		for f in FILES:
			if String(e).contains(f):
				errs.append(e)
	print("ERRORES PROPIOS: ", errs.size())
	for e in errs:
		print("  ", e)
	print("\n== fragmentos")
	for ref in REFS:
		var d: Dictionary = RouteDB.resolve(r, ref)
		print(ref, " origin=", d.get("origin", ""), " cls=", d.get("cls", ""), " tags=", d.get("tags", []), " ents=", d.get("ents", []),
			(" FALTA=" + String(d.missing)) if String(d.get("missing", "")) != "" else "")
	print("\n== rutas")
	for c in r.conclusions():
		var cid := String(c.id)
		var kents: Array = c.get("keys", {}).get("entities", [])
		for rt in RouteDB.routes(r, cid):
			var refs: Array = []
			var any := false
			for f in rt.get("frags", []):
				refs.append(String(f.get("ref", "")))
				if _mine(String(f.get("ref", ""))):
					any = true
			if not any:
				continue
			print(cid, " ", rt.get("id", "?"), " linked=", RouteDB.linked(r, c, rt.frags), " refs=", refs)
			for f in rt.frags:
				var es: Array = []
				for e in f.get("ents", []):
					es.append(("*" if kents.has(e) else "") + String(e))
				print("    ", f.get("ref", ""), " tags=", f.get("tags", []), " ents=", es)
	print("\n== respuestas por capas")
	Fakes.install()
	var st = Fakes.state(r, {"chars": CHARS, "day": 8})
	for ch in CHARS:
		print("-- ", ch)
		for asr in r.lists().get("assertions", []):
			var res: Dictionary = Dialogue.respond(st, r, ch, {"assertion": String(asr.id), "topic": String(asr.get("topic", "")), "ents": asr.get("requires", []), "kind": ""})
			print("  [", asr.id, "] ", res.get("id", "—"), ": ", String(res.get("text", "")).left(110))
		for t in TOPICS:
			if r.entity(t).is_empty():
				continue
			var res2: Dictionary = Dialogue.respond(st, r, ch, {"topic": t, "ents": [t], "kind": String(r.entity(t).get("kind", ""))})
			print("  (", t, ") ", res2.get("id", "—"), ": ", String(res2.get("text", "")).left(110))
	Fakes.uninstall()
	print("\n== recortes reales (GameSim + bot pasivo) frente al modelo de rutas")
	_real_clip(r, ["bot pasivo hasta 7.M", '{"t": "go", "place": "L3", "area": "agente"}'], "militar", "militar", "S:AGENTE.militar")
	_real_clip(r, ["bot pasivo hasta 8.M", '{"t": "go", "place": "L3", "area": "interior"}'], "jueves_a", "jueves", "S:HC05.jueves_a")
	_real_clip(r, ["bot pasivo hasta 8.M", '{"t": "go", "place": "L3", "area": "interior"}'], "jueves_b", "preparativos", "S:HC05.jueves_b")
	# HB6: primera visita al interior el día 2; la orden llega a la mañana siguiente (voz A); 2.ª visita el día 3.
	_real_clip(r, ["bot pasivo hasta 2.M", '{"t": "go", "place": "L3", "area": "interior"}', '{"t": "leave"}', "bot pasivo hasta 3.M",
		'{"t": "go", "place": "L3", "area": "interior"}', '{"t": "ask", "char": "mrs_hudson", "topic": "lisle"}'], "ordenes", "ordenes", "L:mrs_hudson.ordenes")
	# HB8 + encargo el día 3; al día siguiente Wiggins informa (conduit) a cualquier pregunta de su lista.
	_real_clip(r, ["bot pasivo hasta 3.M", '{"t": "go", "place": "L4", "area": "consulta"}', '{"t": "pay", "char": "wiggins", "amount_d": 12}',
		'{"t": "task", "char": "wiggins", "task": "seguir_chico_pell"}', '{"t": "leave"}', "bot pasivo hasta 4.M",
		'{"t": "go", "place": "L4", "area": "consulta"}', '{"t": "ask", "char": "wiggins", "topic": "lisle"}'], "conduit", "conduit", "L:wiggins.conduit")
	quit()

# Recorta el tramo #tid de la línea dicha `lid` de la visita en curso y compara con RouteDB.resolve(ref).
func _real_clip(r, cmds: Array, lid: String, tid: String, ref: String) -> void:
	var ps = PlaySession.new(r, 1)
	ps.echo = false
	for c in cmds:
		ps.exec(String(c))
	var sim = ps.sim
	var found := false
	for l in sim.q_scene().get("lines", []):
		if String(l.get("id", "")) != lid:
			continue
		found = true
		for t in l.get("parsed", {}).get("tramos", []):
			if String(t.id) != tid:
				continue
			var res: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "line", "ref": String(l.uid)}, "from": int(t.from), "len": int(t.to) - int(t.from)})
			var c: Dictionary = Clipper.get_clip(sim.st, String(res.get("clip", "")))
			var d: Dictionary = RouteDB.resolve(r, ref)
			print(ref, " ok=", res.get("ok", false), " err=", res.get("err", ""), "\n    real:   origin=", c.get("origin", ""), " tags=", c.get("tags", []), " ents=", c.get("ents", []),
				"\n    modelo: origin=", d.get("origin", ""), " tags=", d.get("tags", []), " ents=", d.get("ents", []))
	if not found:
		print(ref, ": la línea ", lid, " no se dijo en la visita (fallas del camino: ", ps.fails, ") ", "\n".join(ps.out.slice(maxi(0, ps.out.size() - 4))))
