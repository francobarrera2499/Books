# T7 — fechas, días de la semana y conocimiento (GDD §2.4, §15.5; ARCHITECTURE §4.14, §9.2). Dueño: W2-STRUCT.
#  - schedule.days = calendario real de 1894 (Pascua el 25-mar, días de la semana por algoritmo propio) y 1903-10-01;
#  - toda fecha con día de la semana escrita en data/ coincide con el calendario;
#  - knowable: nadie dice un hecho de canon_bible (h:F.x) antes de poder saberlo (docs por su date; líneas, nodos y
#    rastros por el primer día en que pueden aparecer);
#  - nadie relaciona a Moran con Adair antes del mar. 3 (día 8); ningún texto público de 1894 da un paradero de Holmes;
#    el poder de Mycroft no es público; lint de anacronismos (london_period §7, GDD §2.4);
#  - toda cita src_en está en tests/fixtures/canon (docs y canon_bible); ninguna ruta de conclusión obligatoria ni
#    refutación usa un fragmento ⚠ (w:).
# Además (test_struct_*): autocontroles de aceptación de W2-STRUCT sobre sus propios datos (esquema, inventario de
# reacciones GDD §9.6–9.7, contrato de refs §4.8, rutas ★, selección de rastro, finales). Contenido ajeno faltante
# → pending_content.
extends "res://tests/test_base.gd"

const Markup = preload("res://core/text/markup.gd")
const TimeKey = preload("res://core/util/timekey.gd")
const Cond = preload("res://core/util/cond.gd")

const TIMEOUT_S := 60.0
const MESES := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
const DIAS := ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
const WD_CODE := ["dom", "lun", "mar", "mie", "jue", "vie", "sab"]
const PUBLIC_SRC := ["cronica", "prensa_extranjera", "prensa_londres", "libro"]
const MORAN_IDS := ["moran", "autor_heavy_game"]
const ADAIR_IDS := ["ronald_adair", "asesinato_de_adair", "suceso_park_lane", "park_lane_427"]
const HOLMES_IDS := ["holmes", "sigerson", "corresponsal_s"]
const FOREIGN_1894 := ["montpellier", "grenoble", "paris", "lyon", "francia"]
const POWER_IDS := ["foreign_office", "pedido_del_fo"]
const MY_FILES := ["schedule.json", "conclusions.json", "reactions/", "endings.json", "easter_eggs.json", "entities/struct.json"]
const EPILOGUE_FILES := ["docs/D38.json", "ui_text/epilogo.json", "ui_text/epilogue_ui.json", "scenes/EPI.json"]
# Anacronismos (marzo–abril de 1894): [patrón, sensible a mayúsculas]. Términos del GDD §2.4 y london_period §7.
# Marylebone: sólo la ESTACIÓN (1899; GDD §2.5); el barrio, Marylebone Road y Marylebone Lane (FINA, Vere Street) existen.
# Bóers: sólo la GUERRA de 1899 (london_period §7); la primera guerra (1880–81) y el pueblo bóer existen.
const ANACHRONISMS := [
	["Daily Mail", false], ["(estaci[óo]n|terminal) (de )?Marylebone|Marylebone (Station|station)", false], ["Twopenny Tube", false], ["Central London Railway", false],
	["tranv[ií]as? el[ée]ctric", false], ["[óo]mnibus a motor", false], ["autom[óo]vil", false], ["Kingsway", true],
	["Aldwych", true], ["Westminster Cathedral", false], ["catedral de Westminster", false], ["Tate Gallery", false],
	["Victoria and Albert", false], ["Admiralty Arch", false], ["Victoria Memorial", false], ["\\bRitz\\b", true],
	["Selfridge", true], ["cinemat[óo]grafo", false], ["rayos X", true], ["Marconi", true], ["telegraf[íi]a sin hilos", false],
	["huellas dactilares", false], ["Royal Borough", false], ["guerra (de los |anglo-?)?b[óo]ers?\\b|\\bBoer War\\b", false], ["jubileo de diamante", false],
	["horario de verano", false], ["oficina de prensa", false], ["Shinwell", true], ["\\bMercer\\b", true], ["\\bHopkins\\b", true],
	["Langdale", true], ["Porlock", true], ["Baskerville", false], ["Valley of Fear", false], ["valle del (miedo|terror)", false],
	["Return of Sherlock Holmes", false], ["regreso de Sherlock Holmes", false], ["Empty House", false],
]
# Contrato §4.8 (refs por conclusión; L:hudson.* = L:mrs_hudson.*).
const CONTRACT := {
	"C1": ["D43#hombro", "D44#pierna", "D43#john_h", "D01.TWIS#james", "D01.SPEC#hudson", "D01.SCAN#turner", "D01.SCAN#boda", "D44#conoce_mary", "D01.FIVE#madre", "D44#madre_muerta", "D01.FIVE#una_mujer", "D01.SCAN#marzo_1888", "D44#july7", "D44#septiembre", "D01.REDH#abril", "D01.REDH#octubre"],
	"C2": ["D02#clausula", "D05#marque", "D04#clausula", "D29a#tachadura", "D01N#fina_fo", "D03#sheer"],
	"C3": ["D05#corniche", "N:RB.foto.linea", "D08#kanzel", "R:D27.texto", "D03#sheer"],
	"C4": ["D03#a_mycroft", "D18#calendars", "D19#indice", "D30#recibo", "D29b#surcos", "L:mrs_hudson.mycroft_paga"],
	"C5": ["D09#desague", "D11#desague", "D09#cruel", "D10#cruel", "R:D28.anglo", "D10#portada", "D09#nota_redactor", "D10#frontispicio"],
	"C6": ["J:go", "N:*.sil_wiggins", "AD:prologo", "R:HC10.texto", "AD:*", "R:HB1.col", "S:HC06.b_kbm", "S:HC06.b_kw", "S:HC06.b_kh", "R:HA1.*", "R:HB1.carta", "R:HB4.carta", "L:mrs_hudson.ordenes"],
	"C7": ["R:HA1.fisica", "R:HA0.fisica", "D46#fisica", "R:HA1.fisica", "R:HC04.tarjeta", "S:HC06.b_*", "D31#para_mholmes", "R:HA0.*", "R:HA1.*", "D30#recibo", "N:L2.cotter_canastilla", "N:L2.cesto_tiras", "D01.GREE#founders", "L:watson.escribi_mycroft", "R:HB5.recibo", "R:HB1.carta", "R:HC01.sobre", "D01.GREE#pall_mall", "L:wiggins.vieja_tarifa", "D01.GREE#whitehall", "R:HA1.giro", "S:HC06.a"],
	"C8": ["D13#muestra97", "D12#n97", "D14#opusculo", "D44#oficios_mano", "S:HC06.c", "D31#telegramas", "R:HC01.no_lo_es", "D12#dedicatoria", "D13#jartum", "D34#ruinas", "D35#califa"],
	"C9": ["S:HC05.jueves_a", "N:L3.ventanas_abiertas", "N:L3.shag", "S:HC06.e", "N:L3.cajon", "R:HB*.col", "D31#ruta"],
	"C10": ["N:PRO.harris", "D16#moran", "S:M7.inteligente", "D10#adjetivos", "D23#cruel", "L:wiggins.conduit", "D17#moran_conduit", "D10#cabrito_atado", "S:M6.donde", "D11#no_bala", "S:M7.donde_duerme", "R:HB7.col", "R:M2.nota", "R:HB9.carta", "D11#hacerlo_balar"],
	"C11": ["D15.0403#whist", "D15.0403#nadie_oyo", "D03#air_guns", "D10#bala_blanda", "N:L7.linea_de_tiro", "D11#mejor_tiro", "D16#moran"],
	"C12": ["N:L1.librero_dedos", "D14#amarillo", "N:L1.librero_sombra", "D33#direccion", "D17#church_street", "D12#dedicatoria", "R:D37.precio", "N:PARK.libros", "D33#tree_worship"],
	"C13": ["N:L8.guillotina", "N:L8.ceniza", "S:M7.trichinopolis", "S:AGENTE.militar", "S:PRO.cace_india", "D10#apostarse", "D32#llave_harris", "N:PRO.harris", "R:M10.linea"],
	"C14": ["D01N#mi_james", "D01N#nov93", "D18#mary", "D20#subasta", "D45#duelo", "N:L4.hueco_estante", "N:L4.crespon"],
	"_pistas_falsas": ["D03#baston", "D05#baton", "D03#hopeless", "D19#presume", "D03#steiler", "R:D27.texto", "D18#calendars", "D19#indice", "D04#cajista", "D01N#fina_fo", "D34#ruinas", "D35#califa", "D05#corniche", "D15.0403#nada_falta", "N:L7.azafranes", "N:L3.cajon", "D15.0405#meunier"],
}
# GDD §9.6–9.7 (+ respuestas, §10 W2-STRUCT).
const HOLMES_RIDS := ["HC01", "HC02", "HC03", "HC04", "HC05", "HC06", "HC07", "HC08", "HC09", "HC10", "HA0", "HA1", "HA2", "HA3", "HA4",
	"HB1", "HB2", "HB2b", "HB3", "HB4", "HB5", "HB6", "HB7", "HB8", "HB8b", "HB9", "HB10", "HB11", "HB12", "HB13"]
const MORAN_RIDS := ["M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "M9", "M10", "M11", "M12"]
const OTHER_RIDS := ["HB14", "D27", "D28", "D37", "L6copia"]

var _rp = null

func before_each() -> void:
	_rp = repo()

# ---------------- calendario ----------------
static func _ymd(s: String) -> Array:
	return [int(s.substr(0, 4)), int(s.substr(5, 2)), int(s.substr(8, 2))]

static func _dow(y: int, m: int, d: int) -> int:   # 0 = domingo (Sakamoto)
	var t := [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
	if m < 3:
		y -= 1
	return (y + floori(y / 4.0) - floori(y / 100.0) + floori(y / 400.0) + int(t[m - 1]) + d) % 7

static func _easter(y: int) -> Array:              # algoritmo gregoriano anónimo -> [mes, día]
	var a := y % 19
	var b := floori(y / 100.0)
	var c := y % 100
	var d := floori(b / 4.0)
	var e := b % 4
	var f := floori((b + 8) / 25.0)
	var g := floori((b - f + 1) / 3.0)
	var h := (19 * a + b - d - g + 15) % 30
	var i := floori(c / 4.0)
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := floori((a + 11 * h + 22 * l) / 451.0)
	var mo := floori((h + l - 7 * m + 114) / 31.0)
	var da := ((h + l - 7 * m + 114) % 31) + 1
	return [mo, da]

static func _add_days(s: String, n: int) -> String:
	var dim := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var p := _ymd(s)
	var y: int = p[0]
	var m: int = p[1]
	var d: int = p[2] + n
	while true:
		var lim: int = dim[m - 1] + (1 if m == 2 and (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 0)
		if d <= lim:
			break
		d -= lim
		m += 1
		if m > 12:
			m = 1
			y += 1
	return "%04d-%02d-%02d" % [y, m, d]

static func _valid_date(s) -> bool:
	if typeof(s) != TYPE_STRING or not Markup._is_date(s):
		return false
	if s == "9999-12-31":
		return true
	var p := _ymd(s)
	if p[1] < 1 or p[1] > 12 or p[2] < 1:
		return false
	return _add_days("%04d-%02d-01" % [p[0], p[1]], p[2] - 1).substr(5, 2) == s.substr(5, 2)

func _day_date(day: int) -> String:
	for d in _rp.schedule().get("days", []):
		if int(d.get("day", -1)) == clampi(day, 0, 11):
			return String(d.get("date", ""))
	return ""

func test_calendar_days_real_1894() -> void:
	var days: Array = _rp.schedule().get("days", [])
	eq(days.size(), 12, "días P, 1..10, E")
	var e := _easter(1894)
	eq(e, [3, 25], "Pascua de 1894")
	for i in days.size():
		var d: Dictionary = days[i]
		eq(int(d.day), i, "días consecutivos")
		ok(_valid_date(d.date), "fecha válida %s" % str(d.date))
		var p := _ymd(String(d.date))
		var wd := _dow(p[0], p[1], p[2])
		eq(Cond.wd_norm(String(d.weekday)), WD_CODE[wd], "día de la semana de %s" % d.date)
		if d.has("label"):
			var lab := String(d.label).to_lower()
			if i >= 1 and i <= 10:
				ok(lab.begins_with(DIAS[wd]) and lab.contains("%d de %s" % [p[2], MESES[p[1] - 1]]), "label de %s: %s" % [d.date, d.label])
	eq(String(days[0].date), "1894-03-%02d" % (e[1] + 1), "P = lunes de Pascua")
	for i in range(1, 11):
		eq(String(days[i].date), _add_days("1894-03-26", i), "día %d" % i)
	eq(String(days[11].date), "1903-10-01", "E = octubre de 1903")
	eq(Cond.wd_norm(String(days[11].weekday)), "jue")
	for d in days:
		var sunday := Cond.wd_norm(String(d.weekday)) == "dom"
		if sunday or int(d.day) == 0 or int(d.day) == 11:
			no(bool(d.get("mail", false)) or bool(d.get("times", false)), "sin correo ni Times el día %d" % d.day)
		elif int(d.day) >= 1 and int(d.day) <= 10:
			ok(bool(d.mail) and bool(d.times), "correo y Times el día %d" % d.day)
	eq(days[6].slots, ["T"], "domingo: sólo T")
	for i in [1, 2, 3, 4, 5, 7, 8, 9, 10]:
		eq(days[i].slots, ["M", "T", "N"], "franjas del día %d" % i)
	ok(bool(days[10].get("fixed", false)), "día 10 fijo")
	eq(TimeKey.idx_count(), 29)

# Toda «<día> <n> de <mes>[ de <año>]» escrita en data/ coincide con el calendario (sin año: 1894 si es ene.–abr.).
func test_dates_with_weekday_in_texts() -> void:
	var r := _bad_weekdays()
	eq(r.bad, [], "días de la semana")
	ok(int(r.n) >= 5, "se verificaron fechas (%d)" % r.n)

func _bad_weekdays() -> Dictionary:
	var rx := RegEx.new()
	rx.compile("(?i)\\b(domingo|lunes|martes|mi[ée]rcoles|jueves|viernes|s[áa]bado)[ ,]+(\\d{1,2}) de (enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)(?: de (\\d{4}))?")
	var bad: Array = []
	var n := 0
	for s in _all_strings(true):
		for m in rx.search_all(String(s.v)):
			var wd := m.get_string(1).to_lower().replace("é", "e").replace("á", "a")
			var dd := int(m.get_string(2))
			var mo := MESES.find(m.get_string(3).to_lower()) + 1
			var y := int(m.get_string(4)) if m.get_string(4) != "" else (1894 if mo <= 4 else 0)
			if y == 0:
				continue
			n += 1
			var want: String = DIAS[_dow(y, mo, dd)].replace("é", "e").replace("á", "a")
			if wd != want:
				bad.append("%s %s: «%s» es %s" % [s.rel, s.path, m.get_string(0), DIAS[_dow(y, mo, dd)]])
	return {"bad": bad, "n": n}

func test_canon_bible_dates() -> void:
	var facts: Array = _rp.canon()
	if facts.is_empty():
		pending_content("canon_bible.json vacío (W1-BIBLE)")
		return
	var bad: Array = []
	for f in facts:
		for k in ["event", "published"]:
			if f.get(k) != null and not _valid_date(f.get(k)):
				bad.append("%s.%s %s" % [f.id, k, str(f.get(k))])
		var kn: Dictionary = f.get("knowable", {})
		if not kn.has("publico"):
			bad.append("%s: knowable sin publico" % f.id)
		for who in kn:
			if not _valid_date(kn[who]):
				bad.append("%s.knowable.%s %s" % [f.id, who, str(kn[who])])
		if not ["C", "BG", "H", "INV"].has(String(f.get("mark", ""))):
			bad.append("%s: mark %s" % [f.id, str(f.get("mark"))])
	eq(bad, [], "fechas de canon_bible")

# ---------------- unidades de texto de data/ ----------------
# {kind, ref, rel, who, day, date, public, parsed?, tags_decl?, place?}
func _units() -> Array:
	if _rp.cache.has("t07_units"):
		return _rp.cache["t07_units"]
	var out: Array = []
	var ctx: Dictionary = _rp.markup_ctx()
	var tctx: Dictionary = ctx.duplicate()
	tctx["allow_placeholders"] = true
	var ids: Array = _rp.docs().keys()
	ids.sort()
	for id in ids:
		var d: Dictionary = _rp.doc(id)
		for p in d.get("parts", []):
			out.append({"kind": "doc", "ref": id, "doc": id, "part": String(p.id), "who": "", "date": String(d.get("date", "")),
				"public": PUBLIC_SRC.has(String(d.get("src_type", ""))), "parsed": _rp.parsed(id, String(p.id)), "src_type": String(d.get("src_type", ""))})
	var sids: Array = _rp.scenes().keys()
	sids.sort()
	for sid in sids:
		var sc: Dictionary = _rp.scene(sid)
		var day := _day_of_scene(sc)
		var lines: Array = sc.get("lines", []).duplicate()
		for v in sc.get("variants", []):
			lines.append_array(v.get("append", []))
			for lid in v.get("replace", {}):
				lines.append({"id": lid, "who": _who_of_line(sc, lid), "text": v.replace[lid]})
		for ln in lines:
			var texts := {}
			if ln.has("text"):
				texts[String(ln.id)] = String(ln.text)
			if typeof(ln.get("tpl")) == TYPE_DICTIONARY:
				for code in ln.tpl:
					texts["%s_%s" % [ln.id, code]] = String(ln.tpl[code])
			if ln.has("fallback"):
				texts["%s_fallback" % ln.id] = String(ln.fallback)
			for lid in texts:
				out.append({"kind": "scene", "ref": "S:%s.%s" % [sid, lid], "who": String(ln.get("who", "")), "day": day,
					"date": _day_date(day), "public": false, "parsed": Markup.parse(Markup.fill(texts[lid], {}), tctx)})
	var cids: Array = _rp.dialogues().keys()
	cids.sort()
	for cid in cids:
		var dl: Dictionary = _rp.dialogue(cid)
		for ln in dl.get("lines", []):
			var day2 := maxi(1, _cond_min_day(ln.get("when", {})))
			out.append({"kind": "line", "ref": "L:%s.%s" % [cid, ln.id], "who": cid, "day": day2, "date": _day_date(day2),
				"public": false, "parsed": Markup.parse(String(ln.get("text", "")), tctx)})
	for coll in [_rp.places(), _rp.plates()]:
		var pids: Array = coll.keys()
		pids.sort()
		for pid in pids:
			var pl: Dictionary = coll[pid]
			var base := 0 if pl.get("fixed", false) else 1
			for nd in pl.get("nodes", []):
				var day3 := maxi(base, _cond_min_day(nd.get("when", {})))
				out.append({"kind": "node", "ref": "N:%s.%s" % [pid, nd.id], "who": "", "place": pid, "day": day3, "date": _day_date(day3),
					"public": false, "parsed": Markup.parse(String(nd.get("examine", "")), ctx), "tags_decl": nd.get("tags", [])})
			# nodos de variantes (RB.foto/journal/fina, L1 registrada…): ref N:<lugar>.<variante>.<nodo> (RouteDB._node)
			var vs = pl.get("variants", {})
			if typeof(vs) == TYPE_DICTIONARY:
				var vids: Array = vs.keys()
				vids.sort()
				for vid in vids:
					if typeof(vs[vid]) != TYPE_DICTIONARY:
						continue
					for lst in ["add_nodes", "nodes"]:
						for nd2 in vs[vid].get(lst, []):
							if typeof(nd2) != TYPE_DICTIONARY:
								continue
							var day5 := maxi(base, _cond_min_day(nd2.get("when", {})))
							out.append({"kind": "node", "ref": "N:%s.%s.%s" % [pid, vid, nd2.id], "who": "", "place": pid, "day": day5,
								"date": _day_date(day5), "public": false, "parsed": Markup.parse(String(nd2.get("examine", "")), ctx),
								"tags_decl": nd2.get("tags", [])})
	for r in _rp.reactions():
		var rid := String(r.id)
		var day4 := _earliest_day(r)
		var pub_r := false
		for e in r.get("efecto", []):
			if ["columna", "noticia"].has(String(e.get("op", ""))) and not e.has("si_canal"):
				pub_r = true
		for rs in r.get("rastro", []):
			var tpl := String(rs.get("tpl", ""))
			if rs.has("texto"):
				var pub := pub_r or tpl.ends_with(".col")
				out.append({"kind": "rastro", "ref": "R:%s.%s" % [rid, tpl], "rid": rid, "tpl": tpl, "who": _who_of_reaction(r),
					"day": day4, "date": _day_date(day4), "public": pub, "parsed": Markup.parse(String(rs.texto), tctx)})
			elif rs.has("nodo"):
				out.append({"kind": "nodo", "ref": String(rs.nodo), "rid": rid, "tpl": tpl, "who": _who_of_reaction(r), "day": day4,
					"date": _day_date(day4), "public": false, "tags_decl": rs.get("tags", [])})
	_rp.cache["t07_units"] = out
	return out

static func _who_of_line(sc: Dictionary, lid: String) -> String:
	for ln in sc.get("lines", []):
		if String(ln.get("id", "")) == lid:
			return String(ln.get("who", ""))
	return ""

func _day_of_scene(sc: Dictionary) -> int:
	var t := TimeKey.of(sc.get("tk", ""))
	if t >= 0:
		return TimeKey.day_of(t)
	return maxi(1, _cond_min_day(sc.get("when", {})))

static func _cond_min_day(c) -> int:
	if typeof(c) != TYPE_DICTIONARY:
		return 0
	var best := 0
	var d = c.get("day")
	if typeof(d) == TYPE_INT:
		best = d
	elif typeof(d) == TYPE_DICTIONARY:
		best = int(d.get("gte", d.get("eq", 0)))
	var t = c.get("tk")
	if typeof(t) == TYPE_DICTIONARY and t.has("gte"):
		best = maxi(best, TimeKey.day_of(TimeKey.of(t.gte)))
	for sub in c.get("all", []):
		best = maxi(best, _cond_min_day(sub))
	return best

static func _who_of_reaction(r: Dictionary) -> String:
	match String(r.get("lado", "")):
		"holmes":
			return "holmes"
		"mycroft":
			return "mycroft"
		"moran":
			return "moran"
	var a: Array = r.get("actor", [])
	return String(a[0]) if not a.is_empty() else ""

# Primer día en que la reacción puede entregar su rastro (para knowable y Moran–Adair).
func _earliest_day(r: Dictionary) -> int:
	var d: Dictionary = r.get("disparador", {})
	var ev = d.get("evento", "")
	var evs: Array = ev if typeof(ev) == TYPE_ARRAY else [ev]
	var lat: Dictionary = r.get("latencia", {})
	if evs.has("tiempo"):
		var t := TimeKey.of(d.get("tk", lat.get("tk", "")))
		return TimeKey.day_of(t) if t >= 0 else 1
	var base := 1
	if evs.has("report") or evs.has("reaccion"):
		base = 2
	base = maxi(base, _cond_min_day(r.get("condiciones", {})))
	match String(lat.get("tipo", "")):
		"voz_a", "siguiente_salida", "siguiente_comunicacion":
			return base + 1
		"voz_b":
			var vb: Dictionary = _rp.schedule().get("voice_b", {})
			for k in range(base, 10):
				if vb.has(str(k)):
					return TimeKey.day_of(TimeKey.of(vb[str(k)]))
			return 10
		"dias":
			return base + int(lat.get("n", 1))
		"fija":
			var t2 := TimeKey.of(lat.get("tk", ""))
			return TimeKey.day_of(t2) if t2 >= 0 else base
	return base

static func _unit_tags(u: Dictionary) -> Array:
	var out: Array = []
	if u.has("parsed"):
		for t in u.parsed.get("tramos", []):
			for p in t.tags:
				for v in t.tags[p]:
					out.append("%s:%s" % [p, v])
	for t in u.get("tags_decl", []):
		out.append(String(t))
	return out

# Entidades por párrafo (\n) de una unidad: menciones + e: de los tramos del párrafo.
static func _paragraph_ents(u: Dictionary) -> Array:
	var out: Array = []
	if not u.has("parsed"):
		var s: Array = []
		for t in u.get("tags_decl", []):
			if String(t).begins_with("e:"):
				s.append(String(t).substr(2))
		return [s]
	var pt: Dictionary = u.parsed
	var plain: String = pt.get("plain", "")
	var start := 0
	while start <= plain.length():
		var nl := plain.find("\n", start)
		var end := plain.length() if nl < 0 else nl
		var ents: Array = []
		for m in pt.get("mentions", []):
			if int(m.from) >= start and int(m.from) < end + 1:
				ents.append(String(m.ent))
		for t in pt.get("tramos", []):
			if int(t.from) >= start and int(t.from) < end + 1:
				for e in t.tags.e:
					ents.append(String(e))
		out.append(ents)
		if nl < 0:
			break
		start = nl + 1
	return out

static func _any_in(a: Array, b: Array) -> bool:
	for x in a:
		if b.has(x):
			return true
	return false

# ---------------- knowable ----------------
func _facts() -> Dictionary:
	var out := {}
	for f in _rp.canon():
		out[String(f.id)] = f
	return out

func test_knowable_dates() -> void:
	var r := _bad_knowable()
	eq(r.bad, [], "knowable")
	ok(int(r.n) > 0, "hay etiquetas h: que verificar")

func _bad_knowable() -> Dictionary:
	var facts := _facts()
	var bad: Array = []
	var n := 0
	for u in _units():
		for tg in _unit_tags(u):
			if not String(tg).begins_with("h:"):
				continue
			var fid := String(tg).substr(2)
			n += 1
			if not facts.has(fid):
				bad.append("%s: h:%s no existe en canon_bible" % [u.ref, fid])
				continue
			var f: Dictionary = facts[fid]
			var kn: Dictionary = f.knowable
			var pub := String(kn.get("publico", "9999-12-31"))
			var key := String(u.get("doc", u.get("who", "")))
			var thr := String(kn.get(key, pub))
			if u.kind == "node":
				thr = String(kn.get(String(u.get("place", "")), f.get("event") if f.get("event") != null else pub))
			var date := String(u.get("date", ""))
			if date == "" or date < thr:
				bad.append("%s (%s, %s): h:%s se puede saber desde %s" % [u.ref, key if key != "" else u.kind, date, fid, thr])
	return {"bad": bad, "n": n}

# ---------------- Moran–Adair, paradero, Mycroft ----------------
func test_moran_adair_not_before_day8() -> void:
	eq(_bad_moran_adair(), [], "nadie relaciona a Moran con Adair antes del 3 de abril")

# El catálogo de la Sala de Lectura tampoco: la ficha del Daily Graphic del 3 de abril (D16, Moran y Adair) no se lista
# antes de que exista su ejemplar en la Biblioteca (8.M), y nunca se lista un documento cuyo ejemplar BM no está.
func test_catalog_moran_adair_not_before_day8() -> void:
	var r = repo()
	var sim = load("res://core/sim/game_sim.gd").new(r, 1)
	for day in [1, 7]:
		sim.st.clock.day = day
		sim.st.clock.slot = "M"
		for ent in ["moran", "ronald_adair", "park_lane", "asesinato_de_adair", "daily_graphic"]:
			for x in sim.q_catalog(ent):
				ok(String(x.get("doc", "")) != "D16", "día %d: q_catalog(%s) no lista D16" % [day, ent])
	sim.st.clock.day = 8
	var found := false
	for x in sim.q_catalog("moran"):
		if String(x.get("doc", "")) == "D16":
			found = true
	ok(found, "desde el 8.M, D16 aparece buscando a Moran")
	# ninguna ficha de documento el día 1 con su ejemplar BM fuera de ventana
	sim.st.clock.day = 1
	var WM = load("res://core/sim/world_model.gd")
	var tk1: int = load("res://core/util/timekey.gd").tk(1, "M")
	var bad: Array = []
	for ent in r.catalog().keys():
		for x in sim.q_catalog(String(ent)):
			var did := String(x.get("doc", ""))
			if did != "" and not WM.catalog_listed(r, did, tk1) and not bad.has(did):
				bad.append(did)
	eq(bad, [], "fichas del día 1 sin ejemplar en la Biblioteca")
	# todo ejemplar de la Biblioteca que se pide con papeleta tiene ficha de catálogo (la UI sólo pide por el catálogo)
	var sin_ficha: Array = []
	for did in r.docs().keys():
		for c in r.doc(String(did)).get("copies", []):
			if String(c.get("holder", "")) == "BM" and String(c.get("via", "slip")) == "slip" and typeof(r.doc(String(did)).get("catalog")) != TYPE_DICTIONARY and not sin_ficha.has(did):
				sin_ficha.append(did)
	eq(sin_ficha, [], "ejemplares BM sin ficha de catálogo (no se pueden pedir)")

func _bad_moran_adair() -> Array:
	var bad: Array = []
	for u in _units():
		var date := String(u.get("date", ""))
		if date == "" or date >= "1894-04-03":
			continue
		for ents in _paragraph_ents(u):
			if _any_in(ents, MORAN_IDS) and _any_in(ents, ADAIR_IDS):
				bad.append("%s (%s)" % [u.ref, date])
	return bad

func test_no_public_whereabouts_of_holmes_1894() -> void:
	var r := _bad_whereabouts()
	eq(r.bad, [], "ningún paradero público de Holmes en 1894")
	ok(int(r.n) > 0, "hay textos públicos de 1894 (columna)")

func _bad_whereabouts() -> Dictionary:
	var bad: Array = []
	var n := 0
	for u in _units():
		if not bool(u.get("public", false)):
			continue
		var date := String(u.get("date", ""))
		if date < "1894-01-01" or date > "1894-12-31":
			continue
		n += 1
		for ents in _paragraph_ents(u):
			if _any_in(ents, HOLMES_IDS) and _any_in(ents, FOREIGN_1894):
				bad.append("%s: paradero de Holmes" % u.ref)
		if _unit_tags(u).has("c:paradero_extranjero"):
			bad.append("%s: c:paradero_extranjero en texto público" % u.ref)
	return {"bad": bad, "n": n}

func test_mycroft_power_not_public() -> void:
	eq(_bad_mycroft(), [], "el poder de Mycroft no es público")

func _bad_mycroft() -> Array:
	var bad: Array = []
	for u in _units():
		if not bool(u.get("public", false)) or String(u.get("date", "")) >= "1903-10-01":
			continue
		for ents in _paragraph_ents(u):
			if ents.has("mycroft") and _any_in(ents, POWER_IDS):
				bad.append("%s: Mycroft y el Foreign Office" % u.ref)
		for tg in _unit_tags(u):
			if ["h:F.mycroft_poder", "h:F.pedido_fo"].has(String(tg)):
				bad.append("%s: %s en texto público" % [u.ref, tg])
	return bad

# ---------------- anacronismos ----------------
func _all_strings(include_bible: bool) -> Array:
	var out: Array = []
	var files: Dictionary = _rp.files()
	var rels: Array = files.keys()
	rels.sort()
	for rel in rels:
		if not include_bible and rel == "canon_bible.json":
			continue
		_walk(files[rel], rel, "", out)
	return out

static func _walk(v, rel: String, path: String, out: Array) -> void:
	match typeof(v):
		TYPE_STRING:
			out.append({"rel": rel, "path": path, "v": v})
		TYPE_ARRAY:
			for i in v.size():
				_walk(v[i], rel, "%s[%d]" % [path, i], out)
		TYPE_DICTIONARY:
			var ks: Array = v.keys()
			ks.sort()
			for k in ks:
				if String(k).begins_with("_"):
					continue
				_walk(v[k], rel, path + "." + String(k), out)

func test_anachronisms() -> void:
	eq(_bad_anachronisms(), [], "anacronismos")

# Los patrones atrapan el anacronismo y no el topónimo de época (falsos positivos en citas de Doyle).
func test_anachronism_patterns_precise() -> void:
	var hits := func(s: String) -> bool:
		for a in ANACHRONISMS:
			var rx := RegEx.new()
			rx.compile(("" if a[1] else "(?i)") + String(a[0]))
			if rx.search(s) != null:
				return true
		return false
	for bad in ["Llegó a la estación de Marylebone.", "en la terminal de Marylebone", "Marylebone Station", "la guerra de los bóers", "the Boer War", "el Daily Mail"]:
		ok(hits.call(bad), "anacronismo detectado: " + bad)
	for good in ["La camioneta dobló por Marylebone Lane.", "en Marylebone Road, cerca de la estación de Baker Street", "un colono bóer del Transvaal"]:
		no(hits.call(good), "no es anacronismo: " + good)

func _bad_anachronisms() -> Array:
	var rxs: Array = []
	for a in ANACHRONISMS:
		var rx := RegEx.new()
		rx.compile(("" if a[1] else "(?i)") + String(a[0]))
		rxs.append(rx)
	var bad: Array = []
	for s in _all_strings(false):
		if EPILOGUE_FILES.has(String(s.rel)) or String(s.rel).begins_with("scenes/END."):
			continue
		for i in rxs.size():
			var m: RegExMatch = rxs[i].search(String(s.v))
			if m != null:
				bad.append("%s %s: «%s»" % [s.rel, s.path, m.get_string(0)])
	return bad

# ---------------- citas de Doyle ----------------
static func _norm(s: String) -> String:
	var t := s.replace("’", "'").replace("‘", "'").replace("“", "\"").replace("”", "\"").replace("—", "-").replace("–", "-")
	t = t.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while t.contains("  "):
		t = t.replace("  ", " ")
	return t.strip_edges()

func _canon_texts() -> Dictionary:
	var out := {}
	var dir := "res://tests/fixtures/canon"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".txt"):
			out[f.get_basename().to_lower()] = _norm(FileAccess.get_file_as_string(dir.path_join(f)))
	return out

func test_src_en_in_canon_fixtures() -> void:
	ok(not _canon_texts().is_empty(), "tests/fixtures/canon/*.txt (W1-BIBLE)")
	var r := _bad_src_en()
	eq(r.bad, [], "citas src_en")
	ok(int(r.n) > 0, "hay citas que verificar")

func _bad_src_en() -> Dictionary:
	var canon := _canon_texts()
	var all := " ".join(PackedStringArray(canon.values()))
	var bad: Array = []
	var n := 0
	var ids: Array = _rp.docs().keys()
	ids.sort()
	for id in ids:
		var se: Dictionary = _rp.doc(id).get("src_en", {})
		for q in se:
			n += 1
			if not all.contains(_norm(String(se[q]))):
				bad.append("%s q:%s no está en fixtures/canon" % [id, q])
	for f in _rp.canon():
		if f.get("src_en") == null or String(f.get("src_en", "")) == "":
			continue
		n += 1
		var src := String(f.get("src", "")).to_lower()
		var hay: String = canon.get(src, all)
		if not hay.contains(_norm(String(f.src_en))):
			bad.append("canon_bible %s: src_en no está en %s.txt" % [f.id, src])
	return {"bad": bad, "n": n}

# ---------------- ⚠ en rutas y refutaciones ----------------
func _frag_index() -> Dictionary:
	var idx := {}
	for u in _units():
		var tags := _unit_tags(u)
		match String(u.kind):
			"doc":
				for t in u.parsed.get("tramos", []):
					if String(t.id) != "":
						var tl: Array = []
						for p in t.tags:
							for v in t.tags[p]:
								tl.append("%s:%s" % [p, v])
						idx["%s#%s" % [u.doc, t.id]] = tl
			"rastro":
				idx[u.ref] = tags
				for t in u.parsed.get("tramos", []):
					if String(t.id) != "":
						var k := "R:%s.%s" % [u.rid, t.id]
						var prev: Array = idx.get(k, [])
						for x in tags:
							if not prev.has(x):
								prev.append(x)
						idx[k] = prev
			_:
				idx[u.ref] = tags
	return idx

static func _conc_refs(c: Dictionary, with_apoyo := false) -> Array:
	var out: Array = []
	for r in c.get("routes", []):
		for f in r.get("frags", []):
			out.append(String(f.ref))
	for k in c.get("subroutes", {}):
		for f in c.subroutes[k].get("frags", []):
			out.append(String(f.ref))
	if with_apoyo:
		for a in c.get("_apoyo", []):
			for x in a.get("frags", []):
				out.append(String(x))
	return out

func test_no_unverified_in_routes() -> void:
	var r := _bad_unverified()
	eq(r.bad, [], "ninguna ruta ni refutación con ⚠")
	if r.bad.is_empty() and int(r.missing) > 0:
		pending_content("%d fragmentos de ruta/refutación sin contenido todavía (%d verificados)" % [r.missing, r.resolved])

func _bad_unverified() -> Dictionary:
	var idx := _frag_index()
	var mand: Array = _rp.conclusions_meta().get("mandatory", [])
	var bad: Array = []
	var resolved := 0
	var missing := 0
	var refs := {}
	for cid in mand:
		for r in _conc_refs(_rp.conclusion(cid)):
			refs[r] = cid
	for pf in _rp.files().get("conclusions.json", {}).get("_pistas_falsas", []):
		for r in pf.get("refutaciones", []):
			refs[String(r)] = "refutación %s" % pf.id
	for k in idx:
		for t in idx[k]:
			if String(t).begins_with("a:refuta_"):
				refs[k] = "refutación"
	var keys: Array = refs.keys()
	keys.sort()
	for r in keys:
		if r.begins_with("J:") or r.begins_with("AD:") or r.begins_with("M:") or (r.contains("*") and not r.begins_with("R:")):
			continue
		if r.begins_with("R:"):
			var rid: String = String(r).substr(2).get_slice(".", 0).trim_suffix("*")
			for u in _units():
				if String(u.get("rid", "")).begins_with(rid):
					for t in _unit_tags(u):
						if String(t).begins_with("w:"):
							bad.append("%s (%s) usa un dato ⚠ (%s)" % [r, refs[r], t])
			resolved += 1
			continue
		if not idx.has(r):
			missing += 1
			continue
		resolved += 1
		for t in idx[r]:
			if String(t).begins_with("w:"):
				bad.append("%s (%s) usa un dato ⚠ (%s)" % [r, refs[r], t])
	return {"bad": bad, "missing": missing, "resolved": resolved}

# Negativos: cada verificador encuentra la violación sembrada en tests/fixtures/struct_bad (W2-STRUCT).
static func _has_sub(arr: Array, sub: String) -> bool:
	for x in arr:
		if String(x).contains(sub):
			return true
	return false

func test_checks_detect_violations_on_fixture() -> void:
	var real = _rp
	_rp = fixture_repo("struct_bad")
	var w := _bad_weekdays()
	ok(_has_sub(w.bad, "lunes 27 de marzo de 1894"), "día de la semana falso: %s" % str(w.bad))
	var k := _bad_knowable()
	ok(_has_sub(k.bad, "h:F.secreto"), "hecho dicho antes de tiempo: %s" % str(k.bad))
	ok(_has_sub(_bad_moran_adair(), "D90"), "Moran con Adair antes del 3 de abril")
	ok(_has_sub(_bad_whereabouts().bad, "D90: paradero"), "paradero de Holmes en público")
	ok(_has_sub(_bad_mycroft(), "D90: Mycroft"), "poder de Mycroft en público")
	ok(_has_sub(_bad_anachronisms(), "Daily Mail"), "anacronismo")
	ok(_has_sub(_bad_src_en().bad, "D90 q:q1"), "cita inventada")
	var u := _bad_unverified()
	ok(_has_sub(u.bad, "D91#raro"), "ruta con ⚠: %s" % str(u.bad))
	ok(_has_sub(u.bad, "D91#refuta"), "refutación con ⚠: %s" % str(u.bad))
	_rp = real

# ================= autocontroles de W2-STRUCT =================
func _mine(rel: String) -> bool:
	for f in MY_FILES:
		if rel == f or (f.ends_with("/") and rel.begins_with(f)):
			return true
	return false

func test_struct_files_valid() -> void:
	var bad: Array = []
	for e in _rp.errors():
		var rel := String(e).get_slice(":", 0)
		if _mine(rel) or String(e).begins_with("conclusions "):
			bad.append(e)
	for rel in ["schedule.json", "conclusions.json", "endings.json", "easter_eggs.json", "entities/struct.json", "reactions/columna.json",
			"reactions/mycroft.json", "reactions/holmes.json", "reactions/moran.json", "reactions/respuestas.json"]:
		ok(_rp.files().has(rel), "existe data/%s" % rel)
	# conclusiones con contenido ajeno faltante no son errores de W2-STRUCT: el repo sólo informa tramos de docs existentes
	var own: Array = []
	for e in bad:
		if not String(e).contains("el documento no tiene el tramo") and not String(e).contains("ejemplar '"):
			own.append(e)
	eq(own, [], "datos de W2-STRUCT válidos contra §4")
	var foreign: Array = []
	for e in bad:
		if not own.has(e):
			foreign.append(e)
	if own.is_empty() and not foreign.is_empty():
		pending_content("el contenido existente no cumple refs del contrato §4.8: %s" % str(foreign))

func test_struct_reaction_inventory() -> void:
	var ids := {}
	for r in _rp.reactions():
		ids[String(r.id)] = r
	for rid in HOLMES_RIDS + MORAN_RIDS + OTHER_RIDS:
		ok(ids.has(rid), "reacción %s" % rid)
	eq(ids.size(), HOLMES_RIDS.size() + MORAN_RIDS.size() + OTHER_RIDS.size(), "sin reacciones de más")
	eq(HOLMES_RIDS.size(), 30, "Holmes: 30 (GDD §15.2)")
	eq(MORAN_RIDS.size(), 12, "Moran: 12")
	var cols := 0
	var gars := 0
	for rid in HOLMES_RIDS:
		var r: Dictionary = ids.get(rid, {})
		if String(r.get("tipo", "")) == "columna":
			cols += 1
		if String(r.get("tipo", "")) == "garantizada_por_acto" or r.has("garantizada_si"):
			gars += 1
	eq(cols, 11, "Holmes: 11 de columna")
	eq(gars, 3, "Holmes: 3 garantizadas por acto (HA1, HA3, HB1 en K-T)")
	var mcols := 0
	for rid in MORAN_RIDS:
		if String(ids.get(rid, {}).get("tipo", "")) == "columna":
			mcols += 1
	eq(mcols, 3, "Moran: 3 de columna (M6–M8)")

func test_struct_cuts_have_soft_variant_and_footprint() -> void:
	var c6 := ["acto_", "ancla_", "me_vigila_de_cerca", "vinculo_mycroft", "identidad_holmes", "actividad_posterior_a_mayo_1891"]
	var c10 := ["harris_es_moran", "cebo", "busca_a_holmes", "tirador", "escondite_preparado"]
	var bad: Array = []
	for r in _rp.reactions():
		if r.get("corta", []).is_empty():
			continue
		if typeof(r.get("variante_blanda")) != TYPE_DICTIONARY:
			bad.append("%s: corta sin variante_blanda" % r.id)
		var tags: Array = []
		for u in _units():
			if String(u.get("rid", "")) == String(r.id):
				tags.append_array(_unit_tags(u))
		var want: Array = c10 if String(r.lado) == "moran" else c6
		var hit := false
		for t in tags:
			for w in want:
				if String(t).begins_with("a:" + w):
					hit = true
		if not hit:
			bad.append("%s: corta sin dejar huella (T5)" % r.id)
	eq(bad, [], "D1 y ley de la huella")

func test_struct_contract_refs() -> void:
	var bad: Array = []
	var concs := {}
	for c in _rp.conclusions():
		var base := String(c.id).get_slice(".", 0)
		if not concs.has(base):
			concs[base] = []
		concs[base].append_array(_conc_refs(c, true))
	for cid in CONTRACT:
		if cid == "_pistas_falsas":
			continue
		var have: Array = concs.get(cid, [])
		for ref in CONTRACT[cid]:
			if not _satisfied(String(ref), have):
				bad.append("%s: falta %s" % [cid, ref])
	var pf: Array = []
	for p in _rp.files().get("conclusions.json", {}).get("_pistas_falsas", []):
		pf.append_array(p.get("refutaciones", []))
		pf.append_array(p.get("origen", []))
	for ref in CONTRACT["_pistas_falsas"]:
		if not pf.has(ref):
			bad.append("pistas falsas: falta %s" % ref)
	eq(bad, [], "toda ruta de §10.4 con las refs del contrato §4.8")
	var rx := RegEx.new()
	rx.compile("^(D\\d+[A-Za-z]?(\\.[A-Z0-9]+)?#[a-z0-9_]+|N:[A-Za-z0-9*]+(\\.[a-z0-9_]+)+|S:[A-Z0-9.]+\\.[a-z0-9_*]+|L:[a-z_]+\\.[a-z0-9_]+|R:[A-Za-z0-9*]+\\.[A-Za-z0-9_.*]+|J:[a-z_.A-Z0-9]+|AD:[a-z*]+|M:[A-Za-z0-9.]+)$")
	var bad2: Array = []
	for c in _rp.conclusions():
		for r in _conc_refs(c, true):
			if rx.search(r) == null:
				bad2.append("%s: %s" % [c.id, r])
	eq(bad2, [], "sintaxis de ref (§4.8)")

# Una ref del contrato con selector (R:<rid>.col|carta|*) se cumple con un ejemplo concreto de esa reacción.
static func _satisfied(ref: String, have: Array) -> bool:
	if have.has(ref):
		return true
	if not ref.begins_with("R:"):
		return false
	var body := ref.substr(2)
	var rid := body.get_slice(".", 0)
	var sel := body.substr(rid.length() + 1)
	for h in have:
		var hs := String(h)
		if not hs.begins_with("R:%s." % rid):
			continue
		var tpl := hs.substr(rid.length() + 3)
		if sel == "*" or (sel == "col" and tpl.ends_with(".col")) or (sel == "carta" and (tpl.ends_with(".kw") or tpl.ends_with(".kh"))):
			return true
	return false

func _r_ref_ok(ref: String) -> bool:
	var body := ref.substr(2)
	var dot := body.find(".")
	var rid := body.substr(0, dot)
	var sel := body.substr(dot + 1)
	var rs: Array = []
	for r in _rp.reactions():
		if rid == String(r.id) or (rid.ends_with("*") and String(r.id).begins_with(rid.trim_suffix("*"))):
			rs.append(r)
	if rs.is_empty():
		return false
	for r in rs:
		if sel == "*":
			return true
		# GDD_v2 §C.5: R:<rid>.fisica = la descripción física del papel que entrega (plantilla de data/fisica.json)
		if sel == "fisica" and typeof(r.get("doc")) == TYPE_DICTIONARY and _rp.has_method("fisica") 				and _rp.fisica().get("plantillas", {}).has(String(r.doc.get("entity", ""))):
			return true
		var ops: Array = []
		for e in r.get("efecto", []):
			ops.append(String(e.get("op", "")))
		if sel == "col" and ops.has("columna"):
			return true
		if sel == "carta" and ops.has("carta"):
			return true
		if sel == "noticia" and ops.has("noticia"):
			return true
		for x in r.get("rastro", []):
			if String(x.get("tpl", "")) == sel:
				return true
			if x.has("texto"):
				var pt := Markup.parse(String(x.texto), {"allow_placeholders": true})
				for t in pt.tramos:
					if String(t.id) == sel:
						return true
	return false

func test_struct_reaction_refs_resolve() -> void:
	var bad: Array = []
	var refs: Array = []
	for c in _rp.conclusions():
		refs.append_array(_conc_refs(c, true))
	for p in _rp.files().get("conclusions.json", {}).get("_pistas_falsas", []):
		refs.append_array(p.get("refutaciones", []))
		refs.append_array(p.get("origen", []))
	for r in refs:
		if String(r).begins_with("R:") and not _r_ref_ok(String(r)):
			bad.append(r)
	eq(bad, [], "toda ref R: apunta a un rastro de reactions/")
	# HA1 y HA0: el tramo #giro en TODA plantilla (C7.R8)
	for rid in ["HA1", "HA0"]:
		for x in _rp.reaction(rid).get("rastro", []):
			ok(String(x.get("texto", "")).contains("{{#giro "), "%s.%s lleva #giro" % [rid, x.tpl])

static func _route_keys(frags: Array) -> Array:
	var out: Array = []
	for f in frags:
		var ref := String(f.ref)
		if ref.begins_with("J:"):
			continue
		out.append(String(f.get("copy", "")) if String(f.get("copy", "")) != "" else ref)
	return out

func test_struct_star_routes_disjoint() -> void:
	var bad: Array = []
	for cid in _rp.conclusions_meta().get("mandatory", []):
		var c: Dictionary = _rp.conclusion(cid)
		var stars: Array = []
		for r in c.get("routes", []):
			if not bool(r.get("star", false)):
				continue
			var frags: Array = []
			if r.has("pair"):
				for k in r.pair:
					var sr: Dictionary = c.get("subroutes", {}).get(k, {})
					if not bool(sr.get("star", false)):
						bad.append("%s %s: subruta %s no es ★" % [cid, r.id, k])
					frags.append_array(sr.get("frags", []))
			else:
				frags = r.get("frags", [])
			stars.append(_route_keys(frags))
		var found := false
		for i in stars.size():
			for j in range(i + 1, stars.size()):
				if not _any_in(stars[i], stars[j]):
					found = true
		if not found:
			bad.append("%s: no hay dos rutas ★ sin ejemplar común" % cid)
	eq(bad, [], "≥2 rutas ★ disjuntas por conclusión obligatoria")

func test_struct_conclusion_shape() -> void:
	var meta: Dictionary = _rp.conclusions_meta()
	eq(meta.mandatory, ["C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11", "C12", "C13"])
	eq(meta.lot_counts, ["C2", "C3", "C4", "C5", "C6", "C7", "C8", "C9", "C10", "C11", "C12", "C13", "C14"])
	var lists: Dictionary = _rp.lists()
	var bad: Array = []
	var practice := 0
	for c in _rp.conclusions():
		var tpl: Dictionary = _rp.template(String(c.template))
		if tpl.is_empty():
			bad.append("%s: plantilla %s" % [c.id, c.template])
			continue
		var fields := {}
		for li in tpl.lines.size():
			for f in tpl.lines[li].fields:
				fields[String(f.id)] = li
		for g in c.groups:
			if int(g.line) < 0 or int(g.line) >= tpl.lines.size():
				bad.append("%s: grupo %s en línea %d" % [c.id, g.id, g.line])
		for f in c.answers:
			if not fields.has(f):
				bad.append("%s: campo %s no está en %s" % [c.id, f, c.template])
				continue
			var acc = c.answers[f]
			if typeof(acc) == TYPE_DICTIONARY:
				if not lists.has(String(acc.get("list", ""))):
					bad.append("%s.%s: lista %s" % [c.id, f, acc])
				continue
			for v in acc:
				var s := String(v).trim_prefix("@alias:")
				var in_list := false
				for ln in lists.keys():
					if typeof(lists[ln]) == TYPE_ARRAY and lists[ln].has(s):
						in_list = true
				if _rp.entity(s).is_empty() and not in_list:
					bad.append("%s.%s: valor %s inexistente" % [c.id, f, s])
		for e in c.get("keys", {}).get("entities", []):
			if _rp.entity(String(e)).is_empty():
				bad.append("%s: clave %s inexistente" % [c.id, e])
		var v: Dictionary = c.get("validate", {})
		if TimeKey.of(v.get("from", "")) < 0:
			bad.append("%s: validate.from" % c.id)
		if String(c.kind) == "practica":
			practice += 1
			eq(String(c.get("practice_origins", "")), "pasajes", "%s practice_origins" % c.id)
	eq(practice, 8, "C1: ocho pares INC (C1.01…C1.10)")
	eq(String(_rp.conclusion("C12").validate.until), "10.M")
	eq(String(_rp.conclusion("C13").validate.until), "10.M")
	eq(bad, [], "forma de conclusions.json")

func test_struct_schedule_rules() -> void:
	var sch: Dictionary = _rp.schedule()
	var bad: Array = []
	for e in sch.get("column", []):
		var r: Dictionary = _rp.reaction(String(e.r))
		if r.is_empty():
			bad.append("column: %s no existe" % e.r)
		elif String(r.tipo) != "columna":
			bad.append("column: %s no es de columna" % e.r)
	for r in _rp.reactions():
		if String(r.tipo) == "columna" and String(r.get("disparador", {}).get("evento", "")) == "tiempo":
			var inc := false
			for e in sch.column:
				if String(e.r) == String(r.id):
					inc = true
			if not inc:
				bad.append("%s: columna con tiempo fuera de schedule.column" % r.id)
			var t := TimeKey.of(r.disparador.tk)
			for op in r.get("efecto", []):
				if String(op.get("op", "")) == "columna" and not bool(_day_row(TimeKey.day_of(t)).get("times", false)):
					bad.append("%s: columna un día sin Times" % r.id)
	for k in range(1, 10):
		ok(sch.voice_b.has(str(k)), "voice_b[%d]" % k)
	eq(sch.voice_b.get("6", ""), "10.dawn", "domingo → tanda del jueves")
	eq(sch.voice_b.get("9", ""), "10.M", "miércoles → en persona")
	eq(int(sch.passes.get("9.N", 0)), 2)
	eq(int(sch.passes.get("P.N", -1)), 0)
	eq(sch.reports.size(), 4)
	ok(bool(sch.reports[3].get("final", false)), "informe final")
	ok(bool(sch.places.L1.areas.tienda.get("free", false)), "tienda de Crane free")
	eq(sch.places.L5.areas.forasteros.needs, {"not": {"flag": "forasteros_cerrada"}})
	for p in ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8"]:
		ok(sch.places.has(p), "horario de %s" % p)
	eq(bad, [], "schedule.column y reacciones de columna")

func _day_row(day: int) -> Dictionary:
	for d in _rp.schedule().get("days", []):
		if int(d.day) == day:
			return d
	return {}

func test_struct_endings() -> void:
	var en: Dictionary = _rp.endings()
	var got := {}
	for e in en.get("endings", []):
		got[String(e.id)] = [int(e.order), int(e.rank)]
		eq(Cond.validate(e.cond), [], "cond de %s" % e.id)
	eq(got, {"F1": [1, 1], "F4": [2, 5], "F2": [3, 4], "F3a": [4, 2], "F3b": [5, 3]}, "orden GDD §12.1 y rank §12.1.2")
	var vids: Array = []
	for v in en.get("variants", []):
		vids.append(String(v.id))
		eq(Cond.validate(v.cond), [], "cond de %s" % v.id)
	for want in ["V.confront_completa", "V.confront_incompleta", "V.C12", "V.C14", "V.expuesto", "V.C11", "V.F1", "V.publica"]:
		has(vids, want, "variante GDD §12.2")
	# F1 con todo lo pedido; F3b siempre
	var st := {"flags": {"informe_final": "errata", "moran_credito": true}, "ded": {"sealed": {}}, "events": []}
	for c in ["C2", "C3", "C4", "C5", "C6", "C7", "C8", "C10"]:
		st.ded.sealed[c] = "AS"
	ok(Cond.eval(en.endings[0].cond, {"st": st, "repo": _rp}), "F1 con C6, C7, C10 y 8 selladas, errata y crédito")
	st.flags["holmes_entregado"] = true
	no(Cond.eval(en.endings[0].cond, {"st": st, "repo": _rp}), "F1 no si entregó a Holmes")
	ok(Cond.eval(en.endings[4].cond, {"st": st, "repo": _rp}), "F3b siempre")

# Cada combinación de canal × tema × n (HB1/HB2) y de flags/contadores (notas de Moran, HB10) elige UNA plantilla.
func test_struct_rastro_selection_unique() -> void:
	var bad: Array = []
	for rid in ["HB1", "HB2"]:
		var r: Dictionary = _rp.reaction(rid)
		var ns: Array = [1, 2] if rid == "HB1" else [3]
		for ch in ["K-T", "K-W", "K-H"]:
			for topic in ["pared", "cayeron", "nota_falsa", "testamento", "mintio"]:
				for n in ns:
					var ctx := {"st": {"flags": {}}, "repo": _rp, "anchor": {"channel": ch, "bait_topic": topic}, "counters": {"n": n}}
					var c := _cands(r, ctx)
					if c.size() != 1:
						bad.append("%s %s %s %d: %s" % [rid, ch, topic, n, str(c)])
					elif (ch == "K-T") != String(c[0]).ends_with(".col"):
						bad.append("%s %s %s %d: %s" % [rid, ch, topic, n, c[0]])
	var ha4: Dictionary = _rp.reaction("HA4")
	for ch2 in ["K-H", "K-W"]:
		for topic2 in ["lisle_mudanza", "lisle_ojos", "lisle_viaje", "lisle_boda"]:
			var c3 := _cands(ha4, {"st": {"flags": {}}, "repo": _rp, "anchor": {"channel": ch2, "topic": topic2}, "counters": {"n": 1}})
			if c3.size() != 1:
				bad.append("HA4 %s %s: %s" % [ch2, topic2, str(c3)])
	eq(_cands(ha4, {"st": {"flags": {}}, "repo": _rp, "anchor": {"channel": "K-T", "topic": ""}, "counters": {"n": 1}}), ["K-T"], "HA4 en la columna")
	for rid in ["M2", "M5", "M6", "M8", "M9", "HB10"]:
		var r2: Dictionary = _rp.reaction(rid)
		for desp in [false, true]:
			for rs in [0, 1]:
				var st := {"flags": {"pell_despedido": desp, "wiggins_aliado": desp}, "react": {"counters": {"moran.respuesta_s": rs}}}
				var c2 := _cands(r2, {"st": st, "repo": _rp, "anchor": {}, "counters": {"n": 1}}, true)
				if c2.size() != 1:
					bad.append("%s despedido=%s respuesta_s=%d: %s" % [rid, desp, rs, str(c2)])
	eq(bad, [], "selección de rastro sin ambigüedad")

static func _cands(r: Dictionary, ctx: Dictionary, texts_only := false) -> Array:
	var out: Array = []
	for x in r.get("rastro", []):
		if texts_only and not x.has("texto") and not x.has("when"):
			continue
		if Cond.eval(x.get("when", {}), ctx):
			out.append(String(x.tpl))
	return out

# Todo rastro con texto, llenado con las variables del motor (W2-REACT: ${seat} ${title} ${hour} ${hora} ${phrase} ${text}
# ${streets} ${itinerario} ${act_day} ${act_date} ${ch} ${addr} ${n} ${topic} ${channel}), parsea sin errores.
const RASTRO_VARS := {"seat": "214", "title": "Journal de Genève", "hour": "10:00", "hora": "las diez", "phrase": "La pared era a pique",
	"text": "Se busca testigo", "streets": "Kensington High Street", "itinerario": "Kensington High Street a las diez",
	"act_day": "martes", "act_date": "27 de marzo", "ch": "kw", "addr": "doctor", "n": "1", "topic": "pared", "channel": "K-W"}

func test_struct_rastro_render() -> void:
	var bad: Array = []
	var n := 0
	for r in _rp.reactions():
		for rs in r.get("rastro", []):
			var srcs: Array = []
			if rs.has("texto"):
				srcs.append(String(rs.texto))
			if typeof(rs.get("tono")) == TYPE_DICTIONARY:
				for k in rs.tono:
					srcs.append(String(rs.tono[k]))
			for src in srcs:
				n += 1
				var filled := Markup.fill(src, RASTRO_VARS)
				if filled.contains("${"):
					bad.append("%s.%s: placeholder desconocido en «%s»" % [r.id, rs.tpl, filled])
				var pt: Dictionary = _rp.parse_text(filled, {}, "act.1")
				for e in pt.errors:
					bad.append("%s.%s: %s" % [r.id, rs.tpl, e])
				var ctx: Dictionary = _rp.markup_ctx().duplicate()
				ctx["entities"] = _rp.entities()
				for e in Markup.lint(filled, ctx):
					bad.append("%s.%s: %s" % [r.id, rs.tpl, e])
	eq(bad, [], "rastros renderizables")
	ok(n >= 70, "rastros con texto: %d" % n)

# La gramática operativa del motor de reacciones (W2-REACT, reaction_db.gd lint) acepta todas las reacciones.
func test_struct_reaction_grammar() -> void:
	var path := "res://core/react/reaction_db.gd"
	var scr = load(path)
	var has_lint := false
	for m in scr.get_script_method_list():
		if String(m.get("name", "")) == "lint":
			has_lint = true
	if not has_lint:
		skip("reaction_db.lint todavía no existe (W2-REACT)")
		return
	eq(scr.lint(_rp), [], "reaction_db.lint sobre data/reactions")

# Encadenados sobre los datos reales con el Director real (arnés de W2-REACT, sólo lectura): reglas de GDD §9.6–9.7 que
# dependen de cómo W2-STRUCT escribe disparadores y condiciones.
const REACT_HARNESS := "res://tests/fixtures/react/harness.gd"

static func _rep(n: int, cats: Array, copies := []) -> Dictionary:
	return {"n": n, "mode": "items", "items": [{"kind": "clip", "cats": cats, "copies": copies, "cls": ["P"] if not copies.is_empty() else ["I"]}]}

func _delivered_day(h, rid: String) -> int:
	for i in h.delivered():
		if String(i.rid) == rid:
			return TimeKey.day_of(int(i.get("delivered_tk", -10)))
	return -1

func test_struct_reaction_chains() -> void:
	if not ResourceLoader.exists(REACT_HARNESS):
		skip("arnés de W2-REACT ausente")
		return
	var HS = load(REACT_HARNESS)
	# A) HB9: «si DESPUÉS de esta carta otro informe vuelve a entregar watson_privado» → watson_expuesto. Con D2 difiriendo
	#    M3/HB9, el informe 2 llega antes del aviso: no expone. M5 no actúa antes del 2-abr (día 7: llave, chico, árbol).
	var h = HS.new(_rp)
	h.ev("say", {"char": "watson", "kind": "ask", "topic": "mary_watson", "phrase": "¿Y su esposa, doctor?", "ents": ["mary_watson"]}, "2.M")
	h.ev("report", _rep(1, ["original_p", "watson_privado", "baker_street"], ["D02@L1"]), "2.night")
	h.ev("say", {"char": "watson", "kind": "assert", "topic": "vive", "assertion": "as.vive", "phrase": "Holmes vive, doctor.", "ents": ["holmes"], "says_alive": true}, "4.M")
	h.ev("report", _rep(2, ["watson_privado", "holmes_vive"]), "5.night")
	h.advance_to("10.night")
	var warn := _delivered_day(h, "HB9")
	if bool(h.st.flags.get("watson_expuesto", false)):
		ok(warn >= 0 and warn <= 5, "watson_expuesto sólo con un informe posterior al aviso (aviso el día %d)" % warn)
	for i in h.delivered():
		if String(i.rid) == "M5":
			ok(int(i.anchor.get("day", 0)) >= 7, "M5 por un informe del día %s" % str(i.anchor.get("day")))
	# … y si el informe llega después del aviso, sí expone
	var h2 = HS.new(_rp)
	h2.ev("report", _rep(1, ["watson_privado"]), "2.night")
	h2.ev("report", _rep(2, ["watson_privado"]), "5.night")
	h2.advance_to("10.night")
	ok(_delivered_day(h2, "HB9") >= 0 and _delivered_day(h2, "HB9") <= 5, "aviso HB9 antes del informe 2")
	ok(bool(h2.st.flags.get("watson_expuesto", false)), "reincidencia tras el aviso → watson_expuesto")
	# B) Lo que se le dice a Wiggins (K-S) no es cebo ni canario de Holmes: sólo HB8b.
	var h3 = HS.new(_rp)
	h3.ev("pay", {"char": "wiggins", "amount_d": 12}, "3.M")
	h3.ev("say", {"char": "wiggins", "kind": "assert", "topic": "pared", "assertion": "as.pared", "bait_topic": "pared", "phrase": "La pared era a pique, jefe.", "ents": ["pared"]}, "3.T")
	h3.ev("say", {"char": "wiggins", "kind": "assert", "topic": "lisle_viaje", "assertion": "cn.edimburgo", "canary": "lisle_viaje", "phrase": "Me voy a Edimburgo, jefe.", "ents": []}, "4.M")
	h3.ev("say", {"char": "wiggins", "kind": "assert", "topic": "lisle_boda", "assertion": "cn.boda", "canary": "lisle_boda", "phrase": "Me caso, jefe.", "ents": []}, "5.M")
	h3.advance_to("10.night")
	for rid in ["HB1", "HB2", "HA4", "HB11"]:
		eq(_delivered_day(h3, rid), -1, "%s no responde a Wiggins" % rid)
	ok(_delivered_day(h3, "HB8b") >= 0, "HB8b: dos engaños a Wiggins")
	no(bool(h3.st.flags.get("canal_cerrado.K-S", false)), "K-S no se cierra por canarios")
	# C) Una sola firma al pie de las notas de Moran (con líneas pendientes de M10–M12 adjuntas) y señalador sin firma.
	var h4 = HS.new(_rp)
	h4.ev("slip", {"seat": 214, "doc": "D05", "title": "Journal de Genève", "hour": "10:00", "topic": "holmes_prensa_1891"}, "1.M")
	h4.ev("slip", {"seat": 214, "doc": "D06", "title": "Times, 7-may-1891", "hour": "10:20", "topic": "holmes_prensa_1891"}, "1.M")
	h4.ev("report", _rep(2, ["falso_verificable", "paradero_extranjero"]), "5.night")
	h4.advance_to("10.night")
	var seen_m9 := false
	for hh in [h, h3, h4]:
		for i in hh.delivered():
			var t := String(i.get("text", ""))
			if String(i.get("lado", "")) == "moran" and t != "":
				eq(t.count("\n—J. Pell") + t.count("\n—H."), 1, "%s: una firma — %s" % [i.iid, t])
				seen_m9 = seen_m9 or String(i.rid) == "M9"
			if String(i.rid) == "HA2":
				no(t.contains("Un amigo de la exactitud"), "el señalador no va firmado: " + t)
	ok(seen_m9, "M9 entregada (con la línea de M12)")
	HS.cleanup()
