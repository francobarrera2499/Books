# devtools/drivers/w4qa_text.gd — W4-QA: barrido de texto visible (ortografía, tipografía, anacronismos, inglés, glifos).
# CLI: ./godot.sh --headless -s devtools/drivers/w4qa_text.gd
# Escribe en .work/w4qa/: vocab.txt (palabra, frecuencia, primera aparición), accents.txt (variantes con/sin tilde),
# typo.txt (tipografía con archivo:línea), anachronisms.txt, english.txt, glyphs.txt (literales de .gd vs fuentes).
# No es un test: produce material para revisión humana/IA. Sale con 0.
extends SceneTree

const Markup = preload("res://core/text/markup.gd")

var OUT := ProjectSettings.globalize_path("res://").path_join("../.work/w4qa")
const SKIP_KEYS := ["src_en", "id", "ids", "ref", "refs", "tags", "file", "italic", "font", "paper", "src_type", "class",
	"holder", "area", "via", "from", "to", "origin", "entity", "kind", "trait", "sensor", "char", "who", "op", "tipo",
	"lado", "voz", "canal", "actor", "evento", "contador", "plate", "place", "tk", "when", "weekday", "date", "chron_date",
	"knowable", "sil", "pose", "shape", "build", "mesh", "color", "ink", "audio", "sfx", "bus", "key", "slot", "ent", "doc",
	"topic", "assertion", "channel", "match", "inserts", "do", "screen", "icon"]
const ENG := ["the", "and", "of", "with", "which", "was", "were", "his", "her", "him", "she", "this", "that", "from",
	"have", "had", "been", "would", "could", "should", "there", "their", "they", "what", "when", "where", "who", "you",
	"your", "not", "but", "for", "are", "our", "it", "is", "in", "to", "at", "on", "by", "an", "as", "be", "or", "my"]
# Anacronismos ampliados (marzo–abril de 1894). [patrón, nota]. Revisión manual de cada acierto.
const ANACH := [
	["(?i)\\btaxis?\\b|taxímetro", "taxi (1907)"], ["(?i)\\bautob[úu]s", "autobús (s. XX)"], ["(?i)\\bmetro\\b(?! cuadrado| de)", "metro (transporte)"],
	["(?i)\\bsubte\\b", "subte"], ["(?i)\\bavi[óo]n|aeroplano|aviador", "aviación"], ["(?i)\\bradio\\b(?!s)", "radio"],
	["(?i)\\bcine\\b|pel[íi]cula", "cine"], ["(?i)bol[íi]grafo|birome", "bolígrafo"], ["(?i)fotocopi", "fotocopia"],
	["(?i)\\bclips?\\b", "clip (1899)"], ["(?i)linterna el[ée]ctrica", "linterna eléctrica (1899)"], ["(?i)\\bokey|\\bOK\\b", "OK"],
	["(?i)estr[ée]s\\b", "estrés"], ["(?i)\\bchequea|chequeo", "chequear"], ["(?i)\\bl[íi]der", "líder"], ["(?i)\\bfin de semana", "fin de semana"],
	["(?i)\\bt[íi]quet", "tíquet"], ["(?i)\\bimplementa", "implementar"], ["(?i)\\bcontactar|contacto con", "contactar"],
	["(?i)\\bagendar|agenda\\b", "agenda"], ["(?i)asesino en serie|serial", "asesino en serie"], ["(?i)escena del crimen", "escena del crimen"],
	["(?i)\\bADN\\b|\\bDNA\\b", "ADN"], ["(?i)\\bperfil (psicol|criminal)", "perfil criminal"], ["(?i)psic[óo]pata", "psicópata"],
	["(?i)su[ée]ter|\\bjersey", "suéter/jersey"], ["(?i)\\bsmoking\\b", "smoking"], ["(?i)tel[ée]fono m[óo]vil|celular", "móvil"],
	["(?i)\\bnevera|frigor[íi]fic|heladera", "nevera"], ["(?i)ascensor el[ée]ctrico", "ascensor eléctrico"], ["(?i)\\bplástico", "plástico"],
	["(?i)cremallera|\\bzipper|\\bcierre relámpago", "cremallera"], ["(?i)\\bpasaporte", "pasaporte (no exigido en 1894)"],
	["(?i)\\bdetective privado", "detective privado (revisar)"], ["(?i)\\bforense", "forense (revisar)"], ["(?i)huellas? digital", "huella digital"],
	["(?i)\\bdactil", "dactiloscopia"], ["(?i)\\bpolic[íi]a cient[íi]fica", "policía científica"], ["(?i)\\bservicio secreto|MI5|MI6", "servicio secreto"],
	["(?i)\\bimpresora|\\bfotocopiadora|\\bcomputador|\\bordenador", "máquinas modernas"], ["(?i)\\bmotocicleta|\\bmoto\\b", "motocicleta"],
	["(?i)\\bcami[óo]n|camioneta", "camión"], ["(?i)\\bcoche (a motor|de motor)|automotor", "automóvil"], ["(?i)\\bgasolina|nafta", "gasolina"],
	["(?i)\\btel[ée]fono", "teléfono (existía; revisar uso)"], ["(?i)\\bbombilla|lamparita", "bombilla (revisar)"], ["(?i)luz el[ée]ctrica", "luz eléctrica (revisar)"],
	["(?i)\\bfutbol|f[úu]tbol", "fútbol"], ["(?i)\\bweekend\\b|\\bteenager\\b|\\bdeadline\\b", "inglés moderno"], ["(?i)\\bsherlockian|holmesian", "holmesiano"],
	["(?i)\\bdetectivesco", "detectivesco"], ["(?i)\\bbiro\\b|\\bpaperclip", "paperclip"], ["(?i)\\bstrand magazine\\b", "Strand Magazine (revisar nombre)"],
	["(?i)\\bkodak|instant[áa]nea", "Kodak/instantánea (1888, revisar)"], ["(?i)\\bgram[óo]fono", "gramófono (1887, revisar)"], ["(?i)\\bmetropolitano", "metropolitano (revisar)"],
	["(?i)\\bguardarropa|\\bvestidor", "revisar"], ["(?i)\\bcigarrillo", "cigarrillo (existía; revisar)"], ["(?i)\\bmedia hora|minutos", "(ok)"],
	["(?i)\\bsherlock holmes ha vuelto|regres[óo] Holmes", "spoiler"], ["(?i)\\b19[0-9][0-9]\\b", "año ≥1900"], ["(?i)\\b189[5-9]\\b", "año >1894"],
	["(?i)\\bsiglo XX\\b|siglo veinte", "siglo XX"], ["(?i)\\bnovecientos", "1900+"], ["(?i)\\bcarpeta\\b|\\bfolder", "carpeta (revisar)"],
	["(?i)\\bsobre de manila|\\bpost-?it|\\bcinta adhesiva|\\bscotch|\\bceloh?[áa]n|\\bcelo\\b", "material de oficina moderno"],
	["(?i)\\bgrapadora|\\bgrapa", "grapa (revisar)"], ["(?i)\\bfoto\\b", "foto (abreviatura tardía)"], ["(?i)\\bbici\\b", "bici"],
	["(?i)\\bcaf[ée] instant|\\bnescaf", "café instantáneo"], ["(?i)\\btelevis|\\btele\\b", "televisión"], ["(?i)\\binternet|\\bemail|correo electr", "correo electrónico"],
	# Reloj: en 1894 no se usa el de 24 horas (ni en Londres ni en español); «las cinco menos cuarto de la tarde», «10.20 a. m.».
	["(?<![\\d:.,])(1[3-9]|2[0-4])(:[0-5]\\d)? ?h(?![\\p{L}])|(?<![\\d:.,])(1[3-9]|2[0-3]):[0-5]\\d(?![\\d])", "reloj de 24 horas"],
	["(?<![\\d:.,])(0?\\d|1[0-2])(:[0-5]\\d)? h(?![\\p{L}])", "abreviatura «h» (estilo moderno; revisar)"],
	# london_period §7 que T07 no cubre (revisión manual de cada acierto).
	["(?i)old bailey|newgate", "Old Bailey actual (1907) / Newgate en pie (revisar)"], ["(?i)harrod", "fachada de Harrods (~1905; revisar)"],
	["(?i)antropom[ée]tric|bertillon", "departamento antropométrico (1895)"], ["(?i)tower bridge|puente de la torre", "Tower Bridge (abre 30-jun-1894; revisar)"],
	["(?i)old head|vieja cabeza", "monedas «Old Head» (1895)"], ["(?i)\\bgol(es)?\\b", "gol (voz española posterior; revisar)"],
]

const W := "(?<![\\p{L}])"
const E := "(?![\\p{L}])"
const SUSPECT := [
	["¿\\s*(que|como|cuando|donde|quien|quienes|cual|cuales|cuanto|cuanta|cuantos|cuantas|adonde)" + E, "interrogativo sin tilde"],
	["¡\\s*(que|como|cuanto|cuanta|cuantos|cuantas)" + E, "exclamativo sin tilde"],
	["(?i)" + W + "por que(?=\\s*[?¿]|\\s*\\.)", "«por que» ¿«por qué»?"],
	["(?i)" + W + "(a|para|de|por|en|sin|contra|hacia|sobre|ante|tras|entre|desde|hasta) mi(?=[\\s]*[.,;:!?»)—]|$)", "mi ¿mí?"],
	["(?i)" + W + "(yo|lo|ya lo|no lo|bien lo|le) se(?=[\\s]*[.,;:!?»)—]|$)", "se ¿sé?"],
	["(?i)" + W + "no se(?=[\\s]*[.,;:!?»)—]|$)", "no se ¿no sé?"],
	["(?i)" + W + "(que|dijo que|digo que|creo que|pues|claro que|eso) si(?=[\\s]*[.,;:!?»)—]|$)", "si ¿sí?"],
	["(?i)" + W + "(en|de|por|para|a) si(?= mism| sol)" , "si ¿sí?"],
	["(?i)" + W + "(de|a|con|para|por|sin|que|según|como|contra|hacia|entre|sobre|ante|tras) el(?=[\\s]*[.,;:!?»)—]|$)", "el ¿él?"],
	["(?i)" + W + "hacia (años|tiempo|frío|calor|mucho|poco|rato|días|meses|semanas|una hora|dos|tres|cuatro|cinco|diez|veinte)" + E, "hacia ¿hacía?"],
	["(?i)" + W + "esta (en|aquí|allí|allá|ahí|bien|mal|claro|cerrad[oa]|abiert[oa]|muert[oa]|viv[oa]|segur[oa]|list[oa]|lejos|cerca|escrit[oa]|hech[oa]|dich[oa]|usted|siempre|todavía|ya)" + E, "esta ¿está?"],
	["(?i)" + W + "este (usted|bien|mal|aquí|allí|listo|seguro)" + E, "este ¿esté?"],
	["(?i)" + W + "mas" + E, "mas ¿más?"],
	["(?i)" + W + "aun (no|sin|así|más|menos|hoy|ahora|está|estaba|queda|quedan|vive)" + E, "aun ¿aún?"],
	["(?i)" + W + "tu (eres|sabes|tienes|mismo|misma|dices|lo|la|no)" + E, "tu ¿tú?"],
	["(?i)" + W + "(un|el|una|del|al) te" + E, "te ¿té?"],
	["(?i)" + W + "haber si" + E, "haber si ¿a ver si?"],
	["(?i)" + W + "(he|ha|has|han|hemos|había|habían|haber) echo" + E, "echo ¿hecho?"],
	["(?i)" + W + "halla (un|una|uno|algo|algún|nadie)" + E + "|" + W + "que halla" + E, "halla ¿haya?"],
	["(?i)" + W + "porque(?=\\s*\\?)", "porque ¿por qué?"],
	["(?i)" + W + "sobretodo" + E, "sobretodo"],
	["(?i)" + W + "a parte" + E, "a parte ¿aparte?"],
	["(?i)" + W + "o sea" + E, "o sea (registro)"],
	["(?i)" + W + "(fué|dió|vió|fuí|fuíste)" + E, "tilde antigua"],
	["(?i)" + W + "(guión|truhán|guiándolo)" + E, "tilde"],
	["(?i)" + W + "(ustedes|vosotros|vos|os)" + E, "trato (neutro)"],
	["(?i)" + W + "(tenés|sabés|querés|podés|vení|mirá|decime|andá)" + E, "voseo"],
	["(?i)" + W + "(acá|allá|ahorita|recién|platicar|manejar|carro|computadora|celular|plata|chamba|pibe|chaval|vale|coger|guay|tío|tía)" + E, "regionalismo (revisar)"],
]

var _ctx := {}
var _sus: Array = []
var _vocab := {}       # lower -> {n, forms:{}, at}
var _typo: Array = []
var _anach: Array = []
var _eng: Array = []
var _rx := {}

func _re(p: String) -> RegEx:
	if not _rx.has(p):
		var r := RegEx.new()
		r.compile(p)
		_rx[p] = r
	return _rx[p]

func _init() -> void:
	_go.call_deferred()

func _go() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var repo = load("res://core/data/data_repo.gd").fresh("res://data")
	_ctx = repo.markup_ctx().duplicate()
	_ctx["allow_placeholders"] = true
	var files: Array = []
	_walk("res://data", ["json"], files)
	files.sort()
	var n_str := 0
	var budget := {}
	DirAccess.make_dir_recursive_absolute(OUT.path_join("plain"))
	for p in files:
		var rel := String(p).trim_prefix("res://data/")
		var dump := PackedStringArray()
		for t in _json_strings(FileAccess.get_file_as_string(p)):
			if t.skip or not _looks_text(t.s, t.key):
				continue
			n_str += 1
			_analyze(t.s, "%s:%d" % [String(p).trim_prefix("res://"), t.line], t.key)
			var pl := _plain(t.s)
			dump.append("%d\t%s\t%s" % [t.line, t.key, pl.replace("\n", " ⏎ ")])
			var b := _bucket(rel, t.key)
			if b != "":
				budget[b] = int(budget.get(b, 0)) + Markup.words_of(pl.replace("Xph", "")).size()
		var f := FileAccess.open(OUT.path_join("plain").path_join(rel.replace("/", "_") + ".txt"), FileAccess.WRITE)
		f.store_string("\n".join(dump) + "\n")
		f.close()
	var bl: Array = []
	var bk: Array = budget.keys()
	bk.sort()
	var tot := 0
	for k in bk:
		bl.append("%-60s %6d" % [k, budget[k]])
		if not k.begins_with("(fuera"):
			tot += int(budget[k])
	bl.append("%-60s %6d" % ["TOTAL (sin «fuera de tabla»)", tot])
	_write("budget.txt", bl)
	_write("vocab.txt", _vocab_lines())
	_write("accents.txt", _accent_lines())
	_write("typo.txt", _typo)
	_write("anachronisms.txt", _anach)
	_write("english.txt", _eng)
	_write("suspects.txt", _sus)
	var g := _glyphs()
	_write("glyphs.txt", g)
	print("w4qa_text: %d cadenas; vocab %d; typo %d; anach %d; eng %d; glyphs %d" % [n_str, _vocab.size(), _typo.size(), _anach.size(), _eng.size(), g.size()])
	quit(0)

# Bloques de GDD §15.1 (presupuesto 25.600). "" = no cuenta (interno).
func _bucket(rel: String, key: String) -> String:
	if rel.begins_with("docs/"):
		if key != "text":
			return ""
		if rel.begins_with("docs/D01/"):
			return "1 Corpus D01 (7.200)"
		if rel in ["docs/D43.json", "docs/D44.json"]:
			return "2 STUD+SIGN D43/D44 (1.200)"
		if rel == "docs/D03.json":
			return "3 FINA D03 (2.300)"
		if rel.begins_with("docs/D15/"):
			return "5 Times D15 (2.000)"
		return "4 Documentos inventados (5.900)"
	if rel == "reactions/moran.json":
		return "(fuera de tabla) Moran: notas y avisos (no son voces A/B)"
	if rel.begins_with("reactions/"):
		return "6 Voces A y B / reacciones (1.700)"
	if rel.begins_with("scenes/END.") or rel == "scenes/EPI.json":
		return "8 Diario, interfaz, reglas, epílogo (1.300)"
	if rel.begins_with("dialogue/") or rel.begins_with("scenes/"):
		return "7 Diálogos y escenas (4.000)"
	if rel.begins_with("ui_text/") or rel in ["lists.json", "conclusions.json", "audio.json", "map.json", "endings.json", "schedule.json"]:
		return "8 Diario, interfaz, reglas, epílogo (1.300)"
	if rel.begins_with("places/") or rel.begins_with("plates/"):
		return "(fuera de tabla) lugares y láminas: examen"
	if rel.begins_with("entities/"):
		return "(fuera de tabla) índice: entidades"
	if rel.begins_with("catalog/"):
		return "(fuera de tabla) catálogo del BM"
	return ""

func _write(name: String, lines: Array) -> void:
	var f := FileAccess.open(OUT.path_join(name), FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(lines)) + "\n")
	f.close()

func _walk(dir: String, exts: Array, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if exts.has(f.get_extension()):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_walk(dir.path_join(d), exts, out)

# ---------------------------------------------------------------- JSON con números de línea
func _json_strings(src: String) -> Array:
	var out: Array = []
	var stack: Array = []   # {obj, key, expect_key, skip, cur_skip, arr_key}
	var line := 1
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == "\n":
			line += 1
		elif c == "{" or c == "[":
			var sk := false
			var k := ""
			if not stack.is_empty():
				var top: Dictionary = stack.back()
				sk = top.cur_skip if top.obj else top.skip
				k = top.key if top.obj else top.arr_key
			stack.append({"obj": c == "{", "key": "", "expect_key": c == "{", "skip": sk, "cur_skip": sk, "arr_key": k})
		elif c == "}" or c == "]":
			stack.pop_back()
		elif c == ":":
			if not stack.is_empty() and stack.back().obj:
				stack.back().expect_key = false
		elif c == ",":
			if not stack.is_empty() and stack.back().obj:
				stack.back().expect_key = true
		elif c == "\"":
			var start_line := line
			var buf := PackedStringArray()
			i += 1
			while i < n and src[i] != "\"":
				if src[i] == "\\" and i + 1 < n:
					var e := src[i + 1]
					match e:
						"n": buf.append("\n")
						"t": buf.append("\t")
						"r": buf.append("")
						"b", "f": buf.append("")
						"u":
							buf.append(char(src.substr(i + 2, 4).hex_to_int()))
							i += 4
						_: buf.append(e)
					i += 2
					continue
				if src[i] == "\n":
					line += 1
				buf.append(src[i])
				i += 1
			var s := "".join(buf)
			if not stack.is_empty():
				var top: Dictionary = stack.back()
				if top.obj and top.expect_key:
					top.key = s
					top.cur_skip = top.skip or s.begins_with("_") or SKIP_KEYS.has(s)
				else:
					out.append({"line": start_line, "s": s, "key": top.key if top.obj else top.arr_key,
						"skip": top.cur_skip if top.obj else top.skip})
		i += 1
	return out

func _looks_text(s: String, key: String) -> bool:
	if s.strip_edges() == "":
		return false
	if s.contains(" ") or s.contains("\n"):
		return true
	for i in s.length():
		if s.unicode_at(i) > 127:
			return true
	if _re("^[A-Z][a-z]+[.,;:!?]?$").search(s) != null:
		return true
	return key in ["text", "name", "label", "title", "closing", "intro", "addr", "caption", "noun", "index"]

# ---------------------------------------------------------------- análisis
func _plain(s: String) -> String:
	var t := s
	if t.contains("{{") or t.contains("[[") or t.contains("<") or t.contains("\\"):
		var pt: Dictionary = Markup.parse(t, _ctx)
		t = String(pt.get("plain", t))
	t = _re("\\$\\{[^}]*\\}").sub(t, "Xph", true)
	t = _re("%[sd0-9.]*[sdf]").sub(t, "Xph", true)
	return t

static func _fold(w: String) -> String:
	var t := w.to_lower()
	for p in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ü", "u"], ["à", "a"], ["è", "e"], ["ì", "i"], ["ò", "o"], ["ù", "u"]]:
		t = t.replace(p[0], p[1])
	return t

func _flag(arr: Array, at: String, code: String, plain: String, from: int, to: int) -> void:
	var a := maxi(0, from - 30)
	var b := mini(plain.length(), to + 30)
	arr.append("%s [%s] …%s…" % [at, code, plain.substr(a, b - a).replace("\n", "⏎")])

func _analyze(raw: String, at: String, key: String) -> void:
	var plain := _plain(raw)
	# vocabulario
	for m in _re("[\\p{L}]+(?:['’][\\p{L}]+)*").search_all(plain):
		var w := m.get_string()
		if w == "Xph":
			continue
		var lw := w.to_lower()
		if not _vocab.has(lw):
			_vocab[lw] = {"n": 0, "forms": {}, "at": at}
		_vocab[lw].n += 1
		_vocab[lw].forms[w] = true
	# tipografía
	var checks := [
		["  +(?=\\S)", "doble espacio"],
		["(?<=\\S) +[,;:.!?»)](?!\\.)", "espacio antes de signo"],
		["[,;](?=[\\p{L}])", "falta espacio tras , ;"],
		["[\\p{Ll}][.!?](?=[\\p{Lu}][\\p{Ll}])", "falta espacio tras punto"],
		["\\.\\.\\.", "tres puntos (usar …)"],
		["\"", "comilla recta"],
		["(?<![\\p{L}])'|'(?![\\p{L}])", "apóstrofo/comilla simple recta"],
		["(^|\\s)-(?=\\S)|\\s-\\s|--", "guion como raya"],
		["(?i)(?<![\\p{L}])([\\p{L}]+) \\1(?![\\p{L}])", "palabra repetida"],
		["« | »", "espacio dentro de comillas"],
		["[^\\s(«\"“\\[—¡¿\\n]¿|[^\\s(«\"“\\[—¡¿\\n]¡", "¿¡ pegado a la palabra anterior"],
		["\\s[,.]", "espacio antes de coma/punto"],
		["[\\p{L}]—[\\p{L}]", "raya entre letras (¿falta espacio?)"],
		["\\(\\s|\\s\\)", "espacio junto a paréntesis"],
	]
	for c in checks:
		for m in _re(c[0]).search_all(plain):
			if c[1] == "palabra repetida" and m.get_string(1) == "Xph":
				continue   # dos marcadores de formato seguidos (${a} ${b}, %s %s), no una palabra repetida
			_flag(_typo, at, c[1], plain, m.get_start(), m.get_end())
	# minúscula tras punto (salvo abreviaturas e iniciales)
	for m in _re("([\\p{L}.º]+)\\. ([\\p{Ll}])").search_all(plain):
		var tok := m.get_string(1) + "."
		var abbrev: Array = _ctx.get("abbrev", [])
		if abbrev.has(tok) or tok.length() <= 2 or tok.count(".") >= 2:
			continue
		_flag(_typo, at, "minúscula tras punto", plain, m.get_start(), m.get_end())
	# balance
	if plain.count("«") != plain.count("»"):
		_flag(_typo, at, "«» desparejas %d/%d" % [plain.count("«"), plain.count("»")], plain, 0, mini(plain.length(), 60))
	if plain.count("¿") != plain.count("?"):
		_flag(_typo, at, "¿? desparejas %d/%d" % [plain.count("¿"), plain.count("?")], plain, 0, mini(plain.length(), 60))
	if plain.count("¡") != plain.count("!"):
		_flag(_typo, at, "¡! desparejas %d/%d" % [plain.count("¡"), plain.count("!")], plain, 0, mini(plain.length(), 60))
	if plain.count("(") != plain.count(")"):
		_flag(_typo, at, "() desparejos", plain, 0, mini(plain.length(), 60))
	if plain.count("“") != plain.count("”"):
		_flag(_typo, at, "“” desparejas", plain, 0, mini(plain.length(), 60))
	# sospechas de tilde diacrítica u homófonos (revisión manual)
	for a in SUSPECT:
		for m in _re(a[0]).search_all(plain):
			_flag(_sus, at, a[1], plain, m.get_start(), m.get_end())
	# anacronismos
	for a in ANACH:
		for m in _re(a[0]).search_all(plain):
			_flag(_anach, at, a[1], plain, m.get_start(), m.get_end())
	# inglés
	var nw := 0
	var ne := 0
	var hits := []
	for m in _re("[\\p{L}]+").search_all(plain):
		nw += 1
		var lw := m.get_string().to_lower()
		if ENG.has(lw):
			ne += 1
			hits.append(lw)
	if ne >= 2:
		_eng.append("%s [%d/%d: %s] %s" % [at, ne, nw, ",".join(PackedStringArray(hits)), plain.left(200).replace("\n", "⏎")])

func _vocab_lines() -> Array:
	var ks: Array = _vocab.keys()
	ks.sort()
	var out: Array = []
	for k in ks:
		var v: Dictionary = _vocab[k]
		var forms: Array = v.forms.keys()
		forms.sort()
		out.append("%s\t%d\t%s\t%s" % [k, v.n, "|".join(PackedStringArray(forms)), v.at])
	return out

func _accent_lines() -> Array:
	var groups := {}
	for k in _vocab:
		var f := _fold(k)
		if not groups.has(f):
			groups[f] = []
		groups[f].append(k)
	var ks: Array = groups.keys()
	ks.sort()
	var out: Array = []
	for f in ks:
		var g: Array = groups[f]
		if g.size() < 2:
			continue
		g.sort()
		var parts := PackedStringArray()
		for w in g:
			parts.append("%s×%d (%s)" % [w, _vocab[w].n, _vocab[w].at])
		out.append(" | ".join(parts))
	return out

# ---------------------------------------------------------------- glifos de literales en .gd
func _glyphs() -> Array:
	var fonts := {
		"imprenta": load("res://assets/fonts/IMFeENrm28P.ttf"),
		"imprenta_it": load("res://assets/fonts/IMFeENit28P.ttf"),
		"maquina": load("res://assets/fonts/SpecialElite-Regular.ttf"),
		"manuscrito": load("res://assets/fonts/HomemadeApple-Regular.ttf"),
	}
	var files: Array = []
	_walk("res://", ["gd"], files)
	files.sort()
	var seen := {}   # code -> [at...]
	for p in files:
		var ps := String(p)
		if ps.begins_with("res://tests") or ps.begins_with("res://devtools") or ps.begins_with("res://.godot"):
			continue
		var lines := FileAccess.get_file_as_string(ps).split("\n")
		for ln in lines.size():
			for lit in _literals(lines[ln]):
				for i in lit.length():
					var c: int = lit.unicode_at(i)
					if c < 128:
						continue
					if not seen.has(c):
						seen[c] = []
					if seen[c].size() < 4:
						seen[c].append("%s:%d" % [ps.trim_prefix("res://"), ln + 1])
	var out: Array = []
	var codes: Array = seen.keys()
	codes.sort()
	for c in codes:
		var miss := PackedStringArray()
		for fk in fonts:
			if fonts[fk] == null or not fonts[fk].has_char(c):
				miss.append(fk)
		out.append("U+%04X %s  falta en: %s  usado en: %s" % [c, char(c), ",".join(miss) if not miss.is_empty() else "-", ", ".join(PackedStringArray(seen[c]))])
	# además, glifos de data/ contra cada fuente (T21 ya lo exige; aquí se listan los que caen a la embebida)
	return out

# Literales de texto de una línea de GDScript (sin comentarios); decodifica \uXXXX.
func _literals(line: String) -> Array:
	var out: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "#":
			break
		if c == "\"" or c == "'":
			var q := c
			var buf := PackedStringArray()
			i += 1
			while i < n and line[i] != q:
				if line[i] == "\\" and i + 1 < n:
					if line[i + 1] == "u" and i + 5 < n:
						buf.append(char(line.substr(i + 2, 4).hex_to_int()))
						i += 6
						continue
					buf.append(line[i + 1])
					i += 2
					continue
				buf.append(line[i])
				i += 1
			out.append("".join(buf))
		i += 1
	return out
