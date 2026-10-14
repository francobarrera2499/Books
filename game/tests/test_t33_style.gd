# T33 — estilo del texto visible (GDD_v2 §A.3, §F.3). Dueño: TEXTOS-UI. Excepciones justificadas en
# tests/fixtures/style_exceptions.json (clave -> {regla: motivo}).
# - test_ui_text: todo data/ui_text/*.json con las reglas generales (vosotros, peninsularismos, latinismos, jerga de
#   corrector, título viejo) MÁS los términos viejos del glosario §A.1, botones ≤3 palabras, ayudas ≤12 palabras y
#   errores en la voz de Lisle de una sola oración.
# - test_prologo: data/scenes/PRO.json (prólogo y tutorial) con las mismas reglas de texto.
# - test_dialogos y test_documentos: reglas generales sobre dialogue/, scenes/ (salvo PRO), reactions/, docs/, places/,
#   plates/ y entities/ (los dueños son TEXTOS-DIÁLOGOS y TEXTOS-DOCUMENTOS; GDD_v2 §F.3).
# - test_v3_vocabulario (CONTENIDO, GDD_v3 §7.2 P6): ningún texto visible de los archivos de CONTENIDO dice «conclusión»,
#   «libro de conclusiones» ni «errata»; «asiento» sólo como la silla de la Sala de Lectura (o el asiento de una silla).
#   v3 vuelve a usar «Pasar en limpio» (decisión 2 del usuario: el botón de la hoja del Expediente): sale del glosario.
# Las variables ${…}, el marcado [[ent|superficie]], {{#tramo …|…}} y las etiquetas <…> no cuentan: se mira la superficie.
extends "res://tests/test_base.gd"

const EXC_PATH := "res://tests/fixtures/style_exceptions.json"
# [nombre, patrón, sensible a mayúsculas]
const GENERAL := [
	["vosotros", "\\bvosotr[oa]s\\b", false], ["os (vosotros)", "(^|[\\s¡¿«—])os\\b", false], ["vuestro", "\\bvuestr[oa]s?\\b", false],
	["vale (interjección)", "(^|[\\s¡¿«—])vale[!.,]", false], ["coger", "\\bcog(er|e|es|ió|í|iendo|ido|erlo|erla)\\b", false],
	["acera", "\\baceras?\\b", false], ["ordenador", "\\bordenador", false], ["gafas", "\\bgafas\\b", false],
	["zumo", "\\bzumos?\\b", false], ["patata", "\\bpatatas?\\b", false], ["chaval", "\\bchaval", false],
	["enfadar", "\\benfad", false], ["aparcar", "\\baparc", false], ["conducir", "\\bconduc(ir|e|es|ía|iendo)\\b", false],
	["in extenso", "\\bin extenso\\b", false], ["ad cautelam", "\\bad cautelam\\b", false], ["ad fontes", "\\bad fontes\\b", false],
	["sic", "\\bsic\\b", false], ["dele", "\\bdele\\b", false], ["véase", "\\bv[ée]ase\\b", false], ["galerada", "\\bgaleradas?\\b", false],
	["cajista", "\\bcajistas?\\b", false], ["pliego", "\\bpliegos?\\b", false],
	["título viejo", "fe de erratas", false],
]
# Términos viejos del glosario §A.1 (sólo textos de interfaz y tutorial).
const GLOSARIO := [
	["errata", "\\berratas?\\b", false], ["libro mayor", "\\blibro mayor\\b", false], ["asiento", "\\basientos?\\b", false],
	["folio", "\\bfolios?\\b", false], ["plantilla", "\\bplantillas?\\b", false], ["según", "\\bsegún\\b", false],
	["conclusión (v3: pregunta)", "\\bconclusi[óo]n(es)?\\b", false], ["lote", "\\blotes?\\b", false],
	["Visto (sello)", "\\bVisto\\b", true], ["tampón", "\\btamp[óo]n", false], ["franja", "\\bfranjas?\\b", false],
	["cotejar", "\\bcotej", false], ["marginalia", "\\bmarginalia\\b", false], ["lámina", "\\bl[áa]minas?\\b", false],
	["papeleta", "\\bpapeletas?\\b", false], ["ujier", "\\bujier", false], ["concordancia", "\\bconcordancia", false],
	["procurador", "\\bprocurador", false], ["Forasteros", "\\bforasteros\\b", false], ["agente de fincas", "agente de fincas", false],
	["Baedeker", "\\bbaedeker\\b", false], ["Afirmar", "\\bafirmar\\b", false], ["Presentar", "\\bpresentar\\b", false],
	["Refutar", "\\brefut", false], ["Callar", "\\bcallar\\b", false], ["sólo (con tilde)", "\\bsólo\\b", false],
	["demostrativo con tilde", "\\b[Éé]s[aeo]s?\\b|\\b[Éé]st[aeo]s?\\b", true],
]
# Botones (≤3 palabras); una variable cuenta como una palabra.
const BUTTONS := ["kit.confirm.ok", "kit.confirm.back", "kit.close",
	"ledger.tab.reglas", "ledger.tab.varios", "ledger.tab.erratas", "ledger.tab.folio", "ledger.tab.nuevo_folio",
	"ledger.nuevo_asiento", "ledger.al_sello", "ledger.pasar_practica", "ledger.borrar", "ledger.borrar.ok", "ledger.sello.ok",
	"ledger.sello.quitar", "ledger.sello.titulo", "ledger.picker.borrar", "ledger.cerrar", "ledger.segun.add",
	"nb.tab.recortes", "nb.tab.indice", "nb.tab.cotejos", "nb.tab.diario", "nb.tab.marginalia", "nb.cerrar", "nb.filtro.quitar",
	"nb.cotejo.ok", "nb.cotejo.separar", "nb.cotejo.separar_ok", "nb.diario.tijera",
	"reader.tool.tijera", "reader.plate", "reader.close",
	"sceneui.verb.ask", "sceneui.verb.assert", "sceneui.verb.present", "sceneui.verb.pay", "sceneui.verb.task", "sceneui.back",
	"sceneui.tijera", "sceneui.conf.lamina", "sceneui.continue", "sceneui.leave", "sceneui.leave.free", "sceneui.leave.ok",
	"sceneui.ask.ok", "sceneui.assert.ok", "sceneui.present.ok", "sceneui.present.keep", "sceneui.pay.ok", "sceneui.task.ok",
	"sceneui.conf.refutar", "sceneui.conf.callar", "sceneui.conf.seguir", "sceneui.ad.send", "sceneui.mail.send",
	"sceneui.rep.choose", "sceneui.rep.remove", "sceneui.rep.nada", "sceneui.rep.quemar", "sceneui.rep.errata", "sceneui.rep.send",
	"sceneui.rep.send.quemar", "sceneui.rep.picker",
	"shell.title.continuar", "shell.title.nueva", "shell.title.nueva_ok", "shell.title.opciones", "shell.title.salir",
	"shell.title.seguir", "shell.title.volver", "shell.opt.titulo", "shell.hud.cuaderno", "shell.hud.libro",
	"shell.cal.cerrar_ok", "shell.cal.dormir", "shell.leave.ok", "shell.nav.subir", "shell.nav.volver", "shell.nav.bajar",
	"shell.nav.lamina", "shell.nav.seguir", "shell.speech.seguir", "shell.map.laminas", "shell.noche.baker", "shell.noche.casa",
	"shell.noche.ir", "shell.compose.ad", "shell.compose.telegram", "shell.compose.letter", "shell.present.mostrar",
	"shell.present.guardar", "shell.copia.corto", "shell.copia.ok", "shell.cat.leer", "shell.cat.pedir", "shell.map.ir",
	"shell.map.volver", "shell.fb.report_ok", "shell.fb.callar", "shell.fb.errata_si", "shell.fb.errata_no",
	"epilogue.seguir", "epilogue.tijera", "epilogue.tijera.dejar", "epilogue.publicar.ok", "epilogue.cerrar",
	"v2d.lg.mas_tipos", "v2d.cat.cambiar", "v2d.tray.anteriores", "v2d.sc.todo", "cam.tomos.volver", "cam.estantes.volver",
	"exp.pasar", "exp.volver", "exp.encargo", "exp.en_tinta", "exp.picker.borrar", "mundo.hud.expediente", "mundo.donde.ok"]
# Ayudas de una línea (≤12 palabras).
const HELPS := ["ledger.asiento.ayuda", "ledger.sello.tip", "ledger.erratas.sub", "ledger.tab.nuevo_folio.sub", "ledger.elija",
	"nb.diario.tijera_ayuda", "nb.vacio.cotejos", "v2d.lg.ayuda.hoja", "v2d.lg.ayuda.conclusion", "v2d.lg.ayuda.pruebas",
	"v2d.cat.ayuda", "cam.ayuda.mirar", "pend.mirar", "shell.pro.dormir", "sceneui.ask.pick", "sceneui.assert.pick", "shell.cat.elija",
	"reader.tijera_ayuda"]
# Errores en la voz de Lisle: una sola oración.
const ERR_PREFIX := ["clip.", "entry.", "formal.", "pass.", "practice.fail", "sim.err.", "sceneui.err.", "nb.err.", "core.err.", "ledger.err.",
	"exp.err.", "exp.formal.", "v3core.formal."]
# GDD_v3 §7.2 P6: vocabulario retirado en todo texto visible de CONTENIDO.
const V3 := [["conclusión", "\\bconclusi[óo]n(es)?\\b", false], ["errata", "\\berratas?\\b", false]]
# «asiento» sólo como silla (Sala de Lectura, butaca): estas palabras en el mismo texto lo autorizan.
const ASIENTO_OK := ["sala de lectura", "pedido", "número", "seat", "lámpara", "sillón", "silla", "mampara", "chapa", "lejos de"]
# Archivos de data/ que no son de CONTENIDO (GDD_v3 §7.2).
const NOT_MINE := ["places/L1.json", "entities/v3_core.json", "entities/v3_reacciones.json"]

static func words(s: String) -> int:
	var t := s
	var rv := RegEx.new()
	rv.compile("\\$\\{[^}]+\\}")
	t = rv.sub(t, "X", true)
	var n := 0
	for w in t.split(" ", false):
		var c := w.strip_edges().trim_prefix("+").trim_suffix("…").trim_suffix(".").strip_edges()
		if c != "" and c != "·" and c != "+":
			n += 1
	return n

static func plain_txt(s: String) -> String:
	var r := RegEx.new()
	r.compile("\\[\\[[^|\\]]*\\|([^\\]]*)\\]\\]")
	var t := r.sub(s, "$1", true)
	r.compile("\\{\\{#\\w+[^|]*\\|")
	t = r.sub(t, "", true)
	t = t.replace("}}", "")
	r.compile("<[^>]+>")
	return r.sub(t, "", true)

static func mk_rx(pat: String, cs: bool) -> RegEx:
	var r := RegEx.new()
	var e := r.compile(("(*UCP)" if true else "") + ("" if cs else "(?i)") + pat)
	if e != OK:
		r.compile(("" if cs else "(?i)") + pat)
	return r

static func exempt(exc: Dictionary, key: String, rule: String) -> bool:
	var e = exc.get(key, null)
	if typeof(e) == TYPE_DICTIONARY:
		return e.has(rule) or e.has("*")
	return false

# entries: [{rel, key, text, ui:bool}] ; ui=true aplica también el glosario y las reglas de botones/ayudas/errores.
static func check_entries(entries: Array, exc: Dictionary) -> Array:
	var out: Array = []
	var gen: Array = []
	for g in GENERAL:
		gen.append([g[0], mk_rx(g[1], g[2])])
	var glo: Array = []
	for g in GLOSARIO:
		glo.append([g[0], mk_rx(g[1], g[2])])
	var sent := RegEx.new()
	sent.compile("[.!?…](\\s|$)")
	for it in entries:
		var key := String(it.key)
		var txt := plain_txt(String(it.text))
		var nov := RegEx.new()
		nov.compile("\\$\\{[^}]+\\}")
		var scan := nov.sub(txt, "X", true)
		var rules: Array = gen + (glo if bool(it.get("ui", false)) else [])
		for r in rules:
			if (r[1] as RegEx).search(scan) != null and not exempt(exc, key, r[0]):
				out.append("%s · %s: «%s» (%s)" % [it.rel, key, r[0], txt.left(90)])
		if not bool(it.get("ui", false)):
			continue
		if BUTTONS.has(key) and words(txt) > 3 and not exempt(exc, key, "botón"):
			out.append("%s · %s: botón de %d palabras (%s)" % [it.rel, key, words(txt), txt])
		if HELPS.has(key) and words(txt) > 12 and not exempt(exc, key, "ayuda"):
			out.append("%s · %s: ayuda de %d palabras (%s)" % [it.rel, key, words(txt), txt])
		var is_err := false
		for p in ERR_PREFIX:
			if key.begins_with(p):
				is_err = true
		if is_err and sent.search_all(txt.strip_edges()).size() > 1 and not exempt(exc, key, "una oración"):
			out.append("%s · %s: error de más de una oración (%s)" % [it.rel, key, txt])
	return out

# ---------------------------------------------------------------- recolección
static func read_json(p: String):
	if not FileAccess.file_exists(p):
		return null
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(p)) != OK:
		return null
	return j.data

func exc_map() -> Dictionary:
	var e = read_json(EXC_PATH)
	return e if typeof(e) == TYPE_DICTIONARY else {}

static func collect(v, rel: String, path: String, out: Array) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v:
				if String(k).begins_with("_"):
					continue
				collect(v[k], rel, path + "." + String(k), out)
		TYPE_ARRAY:
			for i in v.size():
				collect(v[i], rel, path + "[%d]" % i, out)
		TYPE_STRING:
			var s := String(v)
			if s.contains(" ") and s.length() > 12:
				out.append({"rel": rel, "key": rel + path, "text": s, "ui": false})

static func walk(dir: String, rel: String, skip: Array, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sd in d.get_directories():
		walk(dir.path_join(sd), rel + "/" + sd, skip, out)
	for fn in d.get_files():
		if fn.ends_with(".json") and not skip.has(rel + "/" + fn):
			collect(read_json(dir.path_join(fn)), rel + "/" + fn, "", out)

func report(found: Array) -> void:
	for f in found:
		fail(f)

# ---------------------------------------------------------------- tests
func test_ui_text():
	var out: Array = []
	var d := DirAccess.open("res://data/ui_text")
	ok(d != null, "data/ui_text")
	if d == null:
		return
	for fn in d.get_files():
		if not fn.ends_with(".json"):
			continue
		var data = read_json("res://data/ui_text/" + fn)
		ok(typeof(data) == TYPE_DICTIONARY and typeof(data.get("text")) == TYPE_DICTIONARY, "ui_text/%s es JSON con «text»" % fn)
		if typeof(data) != TYPE_DICTIONARY:
			continue
		for k in data.get("text", {}):
			out.append({"rel": "ui_text/" + fn, "key": String(k), "text": String(data.text[k]), "ui": true})
	ok(out.size() > 400, "hay textos de interfaz (%d)" % out.size())
	report(check_entries(out, exc_map()))

func test_prologo():
	var pro = read_json("res://data/scenes/PRO.json")
	if typeof(pro) != TYPE_DICTIONARY:
		pending_content("data/scenes/PRO.json")
		return
	var out: Array = []
	for ln in pro.get("lines", []):
		out.append({"rel": "scenes/PRO.json", "key": "PRO." + String(ln.get("id", "")), "text": String(ln.get("text", "")), "ui": true})
	report(check_entries(out, exc_map()))

func test_dialogos():
	var out: Array = []
	walk("res://data/dialogue", "dialogue", [], out)
	walk("res://data/scenes", "scenes", ["scenes/PRO.json"], out)
	walk("res://data/reactions", "reactions", [], out)
	report(check_entries(out, exc_map()))

func test_documentos():
	var out: Array = []
	for sub in ["docs", "places", "plates", "entities"]:
		walk("res://data/" + sub, sub, [], out)
	for fn in ["endings.json", "easter_eggs.json"]:
		collect(read_json("res://data/" + fn), fn, "", out)
	report(check_entries(out, exc_map()))

# GDD_v3 §7.2 P6: «conclusión», «errata» y «asiento» (salvo la silla) no aparecen en ningún texto visible de CONTENIDO.
func test_v3_vocabulario():
	var out: Array = []
	var skip: Array = NOT_MINE.duplicate()
	var corpus = read_json("res://data/corpus.json")
	if typeof(corpus) == TYPE_DICTIONARY:
		for did in corpus.get("inactivas", []):   # crónicas desactivadas (GDD_v3 §3.5): no se ven en esta iteración
			skip.append("docs/" + String(did).replace(".", "/") + ".json")
	for sub in ["docs", "dialogue", "scenes", "places", "plates", "entities", "ui_text", "catalog"]:
		walk("res://data/" + sub, sub, skip, out)
	ok(out.size() > 1000, "textos de CONTENIDO: %d" % out.size())
	report(check_v3(out, exc_map()))

static func check_v3(entries: Array, exc: Dictionary) -> Array:
	var bad: Array = []
	var rules: Array = []
	for g in V3:
		rules.append([g[0], mk_rx(g[1], g[2])])
	var asi := mk_rx("\\basientos?\\b", false)
	for it in entries:
		var rel := String(it.rel)
		if rel.begins_with("ui_text/v3_") and rel != "ui_text/v3_plano.json":
			continue   # textos de interfaz de otros paquetes (test_ui_text los mira con el glosario)
		var key := String(it.key)
		if rel.begins_with("ui_text/") and key.contains(".text."):
			key = key.get_slice(".text.", 1)   # textos de interfaz: la excepción va por clave de ui_text
		var txt := plain_txt(String(it.text))
		for r in rules:
			if (r[1] as RegEx).search(txt) != null and not exempt(exc, key, r[0]):
				bad.append("%s · %s: «%s» (%s)" % [rel, key, r[0], txt.left(90)])
		if asi.search(txt) != null and not exempt(exc, key, "asiento"):
			var low := txt.to_lower()
			var okk := false
			for w in ASIENTO_OK:
				if low.contains(w):
					okk = true
			if not okk:
				bad.append("%s · %s: «asiento» que no es la silla (%s)" % [rel, key, txt.left(90)])
	return bad

# Las reglas mismas (para que un cambio en los patrones no las deje mudas).
func test_reglas_detectan():
	var probe := [
		{"rel": "x", "key": "a", "text": "Os ruego que cojáis la acera, vale.", "ui": false},
		{"rel": "x", "key": "b", "text": "Véase el Journal, sic.", "ui": false},
		{"rel": "x", "key": "c", "text": "Pasar en limpio el asiento del libro mayor.", "ui": true},
		{"rel": "x", "key": "kit.close", "text": "Cerrar esta ventana ahora", "ui": true},
		{"rel": "x", "key": "d", "text": "Mire usted la vereda; ese chico vale un chelín.", "ui": true},
	]
	var f: Array = check_entries(probe, {})
	ok(f.any(func(s): return String(s).contains("· a:")), "vosotros/peninsularismos: %s" % str(f))
	ok(f.any(func(s): return String(s).contains("· b:")), "latinismos y jerga")
	ok(f.any(func(s): return String(s).contains("· c:")), "glosario viejo")
	ok(f.any(func(s): return String(s).contains("kit.close")), "botón largo")
	no(f.any(func(s): return String(s).contains("· d:")), "texto neutro sin hallazgos: %s" % str(f))
	var v3 := check_v3([
		{"rel": "docs/x.json", "key": "e", "text": "Seis conclusiones confirmadas en el libro.", "ui": false},
		{"rel": "docs/x.json", "key": "f", "text": "Una fe de erratas del doctor.", "ui": false},
		{"rel": "docs/x.json", "key": "g", "text": "Seis asientos pasados a tinta.", "ui": false},
		{"rel": "docs/x.json", "key": "h", "text": "Pido el libro para el asiento 214 de la Sala de Lectura.", "ui": false},
	], {})
	for k in ["e", "f", "g"]:
		ok(v3.any(func(s): return String(s).contains("· %s:" % k)), "vocabulario v3 detecta %s: %s" % [k, str(v3)])
	no(v3.any(func(s): return String(s).contains("· h:")), "el asiento de la Sala de Lectura vale")
