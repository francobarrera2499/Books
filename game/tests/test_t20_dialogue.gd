# T20 (W2-SCENES): todo personaje × entidad del índice -> una línea (respaldo por capas, §4.12).
# T20b: ceguera del diálogo — la respuesta depende SÓLO de propiedades visibles (nunca de etiquetas ocultas a:/c:/f:/x:).
# Fixture propio (tests/fixtures/scenes/data) siempre; datos reales (res://data/dialogue) con pending_content si faltan.
extends "res://tests/test_base.gd"

const Fakes = preload("res://tests/fixtures/scenes/fakes.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")

const TIMEOUT_S := 60.0

func before_each() -> void:
	Fakes.install()

func after_each() -> void:
	Fakes.uninstall()

# Recorre personajes × entidades; devuelve los pares sin línea.
func _missing(r) -> Array:
	var st = Fakes.state(r)
	var out: Array = []
	var chars: Array = r.dialogues().keys()
	chars.sort()
	var ents: Array = r.entities().keys()
	ents.sort()
	for ch in chars:
		for e in ents:
			var kind := String(r.entity(e).get("kind", ""))
			var a: Dictionary = Dialogue.respond(st, r, ch, {"topic": e, "ents": [e], "kind": kind})
			var b: Dictionary = Dialogue.respond(st, r, ch, {"ents": [{"id": e, "label": e}]})
			if String(a.get("text", "")).strip_edges() == "" or String(b.get("text", "")).strip_edges() == "":
				out.append("%s × %s" % [ch, e])
	return out

func _generic_check(r) -> Array:
	var out: Array = []
	for ch in r.dialogues():
		var n := 0
		for ln in r.dialogue(ch).get("lines", []):
			if String(ln.get("layer", "")) == "generica" and String(ln.get("reaction", "")) == "" and not String(ln.get("id", "")).begins_with("conf.") \
					and not String(ln.get("id", "")).begins_with("tarea.") and String(ln.get("id", "")) != "pago" and ln.get("when", {}).is_empty():
				n += 1
		if n == 0:
			out.append(ch)
	return out

func test_t20_fixture_every_char_every_entity():
	var r = Fakes.repo()
	ok(r.dialogues().size() >= 6)
	eq(_missing(r), [], "sin línea")
	eq(_generic_check(r), [], "cada personaje con ≥1 genérica incondicional")

func test_t20_real_data():
	var r = repo()
	if r.dialogues().is_empty():
		pending_content("data/dialogue/*.json (W3-CT-DLG-A / W3-CT-DLG-B)")
		return
	var miss := _missing(r)
	eq(miss.size(), 0, "personaje × entidad sin línea: " + str(miss.slice(0, 20)))
	eq(_generic_check(r), [], "personajes sin genérica incondicional (la capa final de T20)")

# --- T20b ---
func test_t20b_respond_ignores_hidden_keys():
	var r = Fakes.repo()
	var st = Fakes.state(r)
	var base := {"topic": "pared", "ents": ["pared"], "kind": "concepto"}
	var noisy := base.duplicate(true)
	noisy["tags"] = ["a:cornisa_existe", "f:refutado", "c:holmes_vive", "x:EE02"]
	noisy["a"] = ["harris_es_moran"]
	noisy["f"] = ["secreto_camden"]
	for ch in r.dialogues():
		eq(Dialogue.respond(st, r, ch, noisy), Dialogue.respond(st, r, ch, base), "claves ocultas ignoradas: " + ch)
	var p := {"ents": [{"id": "perro", "label": "perro"}]}
	var p2 := {"ents": [{"id": "perro", "label": "perro", "tags": ["a:x"]}], "hidden": true}
	eq(Dialogue.respond(st, r, "watson", p2), Dialogue.respond(st, r, "watson", p), "genérica: misma clave visible")

# Dos recortes con lo visible idéntico y etiquetas ocultas distintas -> misma respuesta (todo personaje salvo Mycroft,
# cuyo HB12 depende por contrato del sello y de secreto_camden).
func test_t20b_present_is_blind():
	var r = Fakes.repo()
	var hidden := [[], ["a:cornisa_existe", "a:ancla_kw"], ["f:refutado", "c:holmes_vive"], ["x:EE01", "a:harris_es_moran", "c:camden"]]
	var visibles := [
		{"text": "Más arriba hay una cornisa.", "ents": ["cornisa", "reichenbach"], "origin": "D05"},
		{"text": "Mary.", "ents": ["mary_watson"], "origin": "D01N"},
		{"text": "La vieja tarifa.", "ents": ["vieja_tarifa"], "origin": "D44"},
		{"text": "Un perro.", "ents": ["perro"], "origin": "D15.0327"},
		{"text": "Moran.", "ents": ["moran", "journal_de_geneve"], "origin": "S.M7"},
	]
	for ch in ["watson", "mrs_hudson", "pell", "wiggins", "crane", "ujier"]:
		for v in visibles:
			var ref := ""
			for h in hidden:
				var st = Fakes.state(r, {"chars": [ch], "day": 4})
				Fakes.clip(st, "RC1", v.text, v.ents, h, v.origin)
				var res: Dictionary = Dialogue.act_present(st, r, {"char": ch, "item": {"kind": "clip", "id": "RC1"}})
				ok(res.ok, str(res))
				var got := "%s|%s|%s" % [res.line.get("id", ""), res.line.get("text", ""), res.outcome]
				if ref == "":
					ref = got
				else:
					eq(got, ref, "ceguera %s / %s" % [ch, v.text])
				no(str(st.pending_events).contains("cornisa_existe") or str(st.pending_events).contains("holmes_vive"), "evento sin etiquetas")

# Guardia de código: la respuesta por capas no puede tocar etiquetas internas ni get_clip.
func test_t20b_source_guard():
	var src := FileAccess.get_file_as_string("res://core/scenes/dialogue.gd")
	for fn in ["respond", "_norm_visible", "_match", "_visible_item", "_docs_of"]:
		var body := _body(src, fn)
		ok(body != "", "existe " + fn)
		no(body.contains("get_clip"), fn + " no usa get_clip")
		no(body.contains("tags"), fn + " no lee etiquetas")
		no(body.contains("item_camden"), fn + " no mira secreto_camden")

func _body(src: String, fn: String) -> String:
	var k := src.find("static func " + fn + "(")
	if k < 0:
		return ""
	var e := src.find("\nstatic func ", k + 10)
	return src.substr(k, (e if e > 0 else src.length()) - k)
