# tests/fixtures/v3/v3_fixture.gd — fixtures de la v3 para las interfaces (GDD_v3 §7.1, CORE-EXPEDIENTE). Sobre data/
# real, sin esperar al contenido de los otros paquetes:
#   sim(repo, seed)       GameSim en el escritorio del día 1 (prólogo hecho) con: Q1 abierta en lápiz (respuesta y una
#                         prueba), Q2 en tinta (texto de Lisle), Q3 abierta vacía, y recortes de ejemplo para arrastrar
#                         (ids en sim.get_meta("v3_clips")). Usar con sim_override.
#   fina_view(repo)       q_view v3 de «El problema final» del cliente (D03@tomo): ficha de Lisle, marquitas, la nota a lápiz
#                         del margen (D01N#fina_fo junto a #sheer) y la tarjeta del cliente (NC.FINA) como última hoja. Si los
#                         datos todavía no traen el bloque v3 (CONTENIDO), se arma uno equivalente (marcado "_sintetico").
#   clips(sim)            [q_clip] de los recortes de ejemplo.
# Nada de esto se usa en el juego.
extends RefCounted

const GameSim = preload("res://core/sim/game_sim.gd")
const Clipper = preload("res://core/deduction/clipper.gd")
const Dossier = preload("res://core/deduction/dossier.gd")
const Index = preload("res://core/deduction/index.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

static func _inject(s, origin: String, text: String, tags: Array, ents: Array, src_line: String) -> String:
	return Clipper.inject(s.st, s.repo, {"origin": origin, "doc": origin, "text": text, "tags": tags, "ents": ents,
		"src_line": src_line, "src_type": "cronica", "title": src_line})

static func sim(repo, seed := 1894):
	var s = GameSim.new(repo, seed)
	s.st.clock.day = 1
	s.st.clock.slot = "M"
	s.st.clock.phase = "desk"
	s.st.world.tutorial.done = true
	s.st.world.tutorial.step = 4
	var d: Dictionary = s.st.ded.dossier
	d.seen["leer D03#sheer"] = 11
	d.seen["llega voz:A"] = 12
	Dossier.update(s.st, s.repo)
	var ids := {}
	ids["sheer"] = _inject(s, "D03", "No había más que una pared a pique, de roca negra.", ["a:fina_a_pique", "a:fina_impreso_sin_raspadura"], ["pared", "reichenbach", "fina"], "«El problema final», crónica")
	ids["corniche"] = _inject(s, "D05", "Más arriba del sendero hay una cornisa que no se ve desde abajo.", ["a:cornisa_existe"], ["cornisa", "pared", "sendero"], "Journal de Genève, diario")
	ids["marque"] = _inject(s, "D02", "En la roca había una raspadura fresca, como de clavo de bota.", ["a:raspadura_registrada"], ["raspadura", "roca", "pared"], "Prueba de imprenta de Lisle")
	ids["ruido"] = _inject(s, "D21", "Hoy llovió toda la mañana sobre Holywell Street.", [], [], "Notas de lectura de Lisle")
	Index.add_entities(s.st, s.repo, ["cornisa", "raspadura", "mycroft", "holmes"])
	# Q2 en tinta
	Dossier.act_answer(s.st, s.repo, {"q": "Q2", "value": "cornisa"})
	Dossier.act_proof(s.st, s.repo, {"q": "Q2", "slot": 0, "clip": ids.sheer})
	Dossier.act_proof(s.st, s.repo, {"q": "Q2", "slot": 1, "clip": ids.corniche})
	Dossier.act_confirm(s.st, s.repo, {"q": "Q2"})
	# Q1 en lápiz: respuesta y una prueba
	Dossier.act_answer(s.st, s.repo, {"q": "Q1", "value": "raspadura"})
	Dossier.act_proof(s.st, s.repo, {"q": "Q1", "slot": 0, "clip": ids.marque})
	s.st.notes.clear()
	s.set_meta("v3_clips", ids)
	return s

static func clips(s) -> Array:
	var out: Array = []
	for k in s.get_meta("v3_clips", {}):
		out.append(s.q_clip(String(s.get_meta("v3_clips")[k])))
	return out

# q_view v3 de FINA del cliente. Con datos v3 reales, la vista de WorldModel; si no, una equivalente armada acá.
static func fina_view(repo) -> Dictionary:
	var s = sim(repo)
	var v: Dictionary = WorldModel.view_any(s.st, repo, "D03@tomo")
	if v.is_empty():
		return {}
	if v.get("ficha") != null and not (v.get("marks", []) as Array).is_empty():
		return v
	v["_sintetico"] = true
	v["ficha"] = {"trata": "Watson cuenta cómo Holmes y el profesor Moriarty cayeron juntos en la cascada de Reichenbach, en Suiza.",
		"cuando": "Pasó en abril y mayo de 1891; salió en la Strand en diciembre de 1893.",
		"por_que": "El cliente quiere saber qué no contó el doctor en esta crónica."}
	var pages: Array = v.pages
	var marks: Array = []
	var sheer_page := -1
	for pi in pages.size():
		for t in pages[pi][0].get("parsed", {}).get("tramos", []):
			var tid := String(t.get("id", ""))
			if tid == "sheer" or tid == "a_mycroft":
				marks.append({"page": pi, "block": 0, "tramo": tid})
				if tid == "sheer":
					sheer_page = pi
	v["marks"] = marks
	if sheer_page >= 0:
		var seg := WorldModel.tramo_markup(repo, "D01N", "fina_fo")
		var parsed: Dictionary = repo.parse_text(seg) if seg != "" else repo.parse_text("<f=manuscrito><ink=lapiz>suprimido a pedido del F.O.</ink></f>")
		pages[sheer_page].append({"doc": "D01N", "origin": "D01N", "copy": "D01N@tomo", "part": "fina_fo", "parsed": parsed,
			"slot": "margen", "hand": "lapiz", "anchor": {"block": 0, "tramo": "sheer"}})
	var nc: Dictionary = repo.doc("NC.FINA")
	if not nc.is_empty():
		var card: Array = []
		for p in nc.get("parts", []):
			card.append({"doc": "NC.FINA", "origin": "NC.FINA", "copy": "NC.FINA@tomo", "part": String(p.id),
				"parsed": repo.parsed("NC.FINA", String(p.id)), "slot": "tarjeta", "hand": "mano_harris"})
		pages.append(card)
	else:
		pages.append([{"doc": "NC.FINA", "origin": "NC.FINA", "copy": "NC.FINA@tomo", "part": "p1", "slot": "tarjeta", "hand": "mano_harris",
			"parsed": repo.parse_text("El sendero y la carta, señor: ahí el doctor se apura. {{#tic a:rasgo_de_harris e:adjetivos_repetidos|Léalos despacio, despacio.}} —H.")}])
	return v
