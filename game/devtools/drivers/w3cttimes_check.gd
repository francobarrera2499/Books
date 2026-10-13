# W3-CT-TIMES: chequeo headless del contenido propio (D15.*, D40–D42, catalog/noise.json, entities/ct_times.json).
# ./godot.sh --headless -s devtools/drivers/w3cttimes_check.gd [-- <ruta absoluta del dataset>]
# Imprime PASS/FAIL por regla y termina con código 1 si alguna falla. Reglas (ARCHITECTURE §10 ola 3, §12.2 R1–R6, GDD §2, §6):
#  - un número del Times por día con Times del schedule (1–5, 7–10): entity times_<MMDD>, origin, ejemplar @L1 desde <día>.dawn
#    (holder L1, area buhardilla, via desk), inserts {columna: p2, noticias: p1} (R6; test_i_integration usa p2)
#  - columna con 11–12 avisos estáticos (~12 por número con los runtime)
#  - Moran no aparece (mención ni e:) en ningún texto del Times antes del 3-abr ni en D40–D42 (GDD §2.4, T7)
#  - tramos de contrato con sus etiquetas y menciones de R4; pistas falsas en su origen
#  - ningún tramo con dos grupos de C11 (T4); ningún c:, f:afirma_que_vive ni f:secreto_camden en el Times
#  - catálogo de ruido: entidades existentes, etiquetas únicas, cada entidad buscable con ≥2 resultados
#  - presupuesto: total del paquete dentro de ±15 % de 2.300 palabras; ningún número > 1.000 palabras (T11)
extends SceneTree
const DataRepo = preload("res://core/data/data_repo.gd")

var fails := 0

func _init() -> void:
	_run.call_deferred()

func ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		fails += 1
		print("FAIL ", msg)

func _tramo(repo, did: String, tid: String) -> Dictionary:
	for p in repo.doc(did).get("parts", []):
		var pt: Dictionary = repo.parsed(did, String(p.id))
		for t in pt.get("tramos", []):
			if String(t.id) == tid:
				var ents: Array = []
				for m in pt.mentions:
					if int(m.from) >= int(t.from) and int(m.to) <= int(t.to):
						ents.append(String(m.ent))
				return {"tags": t.tags, "ents": ents}
	return {}

func _has(tr: Dictionary, pfx: String, v: String) -> bool:
	return (tr.get("tags", {}).get(pfx, []) as Array).has(v)

func _words(repo, did: String) -> int:
	var n := 0
	for p in repo.doc(did).get("parts", []):
		n += (repo.parsed(did, String(p.id)).get("words", []) as Array).size()
	return n

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var root := "res://data" if args.is_empty() else String(args[0])
	DataRepo.clear_cache(root)
	var repo = DataRepo.fresh(root)
	var mine_err: Array = []
	for e in repo.errors():
		var s := String(e)
		if s.contains("D15") or s.contains("D40") or s.contains("D41") or s.contains("D42") or s.contains("ct_times") or s.contains("catalog"):
			mine_err.append(s)
	ok(mine_err.is_empty(), "carga sin errores propios %s" % str(mine_err))
	# --- números del Times ---
	var issues: Array = []
	for d in repo.schedule().get("days", []):
		var date := String(d.get("date", ""))
		var day := int(d.get("day", -1))
		if day < 1 or day > 10 or date.length() < 10:
			continue
		var mmdd := date.substr(5, 2) + date.substr(8, 2)
		var did := "D15." + mmdd
		if String(d.get("weekday", "")) == "dom":
			ok(repo.doc(did).is_empty(), "%s: el domingo no hay Times" % did)
			continue
		var doc: Dictionary = repo.doc(did)
		ok(not doc.is_empty(), "%s existe (día %d)" % [did, day])
		if doc.is_empty():
			continue
		issues.append(did)
		ok(String(doc.get("entity", "")) == "times_" + mmdd and String(doc.get("origin", "")) == did, "%s: entity y origin" % did)
		var cps: Array = doc.get("copies", [])
		ok(cps.size() == 1 and String(cps[0].id) == did + "@L1" and String(cps[0].holder) == "L1" and String(cps[0].get("area", "")) == "buhardilla" \
			and String(cps[0].via) == "desk" and String(cps[0].from) == "%d.dawn" % day and String(cps[0].to) == "10.N", "%s: ejemplar @L1 desde %d.dawn" % [did, day])
		ok(doc.get("inserts", {}) == {"columna": "p2", "noticias": "p1"}, "%s: inserts columna p2 / noticias p1" % did)
		var col: Dictionary = repo.parsed(did, "p2")
		var lines := String(col.get("plain", "")).split("\n", false).size() - 1
		ok(lines >= 11 and lines <= 12, "%s: %d avisos estáticos en la columna" % [did, lines])
		var w := _words(repo, did)
		ok(w <= 1000, "%s: %d palabras (T11 ≤1.000 por mañana)" % [did, w])
		var early := mmdd < "0403"
		for p in doc.get("parts", []):
			var pt: Dictionary = repo.parsed(did, String(p.id))
			for m in pt.mentions:
				if early and String(m.ent) == "moran":
					ok(false, "%s: menciona a Moran antes del 3-abr" % did)
			for t in pt.tramos:
				var tg: Dictionary = t.tags
				if early and (tg.get("e", []) as Array).has("moran"):
					ok(false, "%s#%s: e:moran antes del 3-abr" % [did, t.id])
				var c11 := 0
				for a in tg.get("a", []):
					if ["autor_moran", "arma_de_aire", "disparo_desde_fuera"].has(String(a)):
						c11 += 1
				if c11 > 1:
					ok(false, "%s#%s: dos grupos de C11 en un tramo (T4)" % [did, t.id])
				if not (tg.get("c", []) as Array).is_empty() or (tg.get("f", []) as Array).has("afirma_que_vive") or (tg.get("f", []) as Array).has("secreto_camden"):
					ok(false, "%s#%s: etiqueta c:/afirma_que_vive/secreto_camden en el Times" % [did, t.id])
	ok(issues.size() == 9, "nueve números del Times (%d)" % issues.size())
	for did in ["D40", "D41", "D42"]:
		for p in repo.doc(did).get("parts", []):
			for m in repo.parsed(did, String(p.id)).mentions:
				ok(String(m.ent) != "moran", "%s no menciona a Moran" % did)
	# --- contrato §4.8 ---
	var w1 := _tramo(repo, "D15.0403", "whist")
	ok(_has(w1, "a", "autor_moran") and w1.get("ents", []).has("moran") and w1.get("ents", []).has("ronald_adair"), "D15.0403#whist: a:autor_moran + moran + ronald_adair (R4)")
	var w2 := _tramo(repo, "D15.0403", "nadie_oyo")
	ok(_has(w2, "a", "disparo_desde_fuera") and _has(w2, "e", "ventana_abierta") and w2.get("ents", []).has("disparo"), "D15.0403#nadie_oyo: a:disparo_desde_fuera + e:ventana_abierta + disparo")
	ok(_has(_tramo(repo, "D15.0403", "nada_falta"), "a", "refuta_anarquistas"), "D15.0403#nada_falta: a:refuta_anarquistas")
	var w3 := _tramo(repo, "D15.0405", "meunier")
	ok(_has(w3, "a", "refuta_meunier") and _has(w3, "x", "EE10") and w3.get("ents", []).has("theodule_meunier"), "D15.0405#meunier: a:refuta_meunier + x:EE10 + Théodule")
	ok(_has(_tramo(repo, "D15.0331", "anarquistas"), "a", "falsa_anarquistas") and _has(_tramo(repo, "D15.0331", "anarquistas"), "f", "refutado"), "D15.0331: origen de falsa_anarquistas")
	ok(_has(_tramo(repo, "D15.0405", "detenido"), "a", "falsa_meunier") and _has(_tramo(repo, "D15.0405", "detenido"), "f", "refutado"), "D15.0405: origen de falsa_meunier")
	ok(_has(_tramo(repo, "D41", "retrato"), "x", "EE05"), "D41#retrato: x:EE05")
	ok(_has(_tramo(repo, "D15.0331", "adair"), "e", "suceso_park_lane"), "D15.0331#adair: e:suceso_park_lane (forma «testigo»)")
	# --- catálogo de ruido ---
	var nz: Array = []
	var fa := FileAccess.open(ProjectSettings.globalize_path(root).path_join("catalog/noise.json"), FileAccess.READ)
	if fa != null:
		nz = JSON.parse_string(fa.get_as_text()).get("noise", [])
	ok(nz.size() >= 40, "catálogo de ruido: %d entradas" % nz.size())
	var labels := {}
	var bad: Array = []
	for x in nz:
		labels[String(x.label)] = true
		for e in x.entities:
			if repo.entity(String(e)).is_empty():
				bad.append(String(e))
	ok(labels.size() == nz.size(), "catálogo: etiquetas únicas")
	ok(bad.is_empty(), "catálogo: entidades existentes %s" % str(bad))
	var cat: Dictionary = repo.catalog()
	var thin: Array = []
	for e in ["holmes", "watson", "moran", "reichenbach", "meiringen", "suiza", "tigre", "india", "himalaya", "park_lane", "ronald_adair",
			"indagatoria", "whist", "times", "strand", "mycroft", "sigerson", "jartum", "tibet", "monografia_cenizas", "opusculo_oficios",
			"profesor_moriarty", "coronel_moriarty", "kensington", "paddington", "baker_street", "anarquistas", "herida", "fusil_de_aire"]:
		if (cat.get(e, []) as Array).size() < 2:
			thin.append(e)
	ok(thin.is_empty(), "catálogo: ≥2 resultados por entidad buscable %s" % str(thin))
	# --- presupuesto ---
	var total := 0
	for did in issues + ["D40", "D41", "D42"]:
		var w := _words(repo, did)
		var decl := int(repo.doc(did).get("words", 0))
		total += w
		ok(decl > 0 and absf(float(w - decl) / float(decl)) <= 0.15, "%s: %d palabras, declaradas %d (±15 %%)" % [did, w, decl])
	ok(absf(float(total - 2300) / 2300.0) <= 0.15, "paquete: %d palabras frente a ≈2.300 (±15 %%)" % total)
	print("W3-CT-TIMES CHECK: %d fallas" % fails)
	quit(1 if fails > 0 else 0)
