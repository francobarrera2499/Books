# devtools/drivers/v3cont_check.gd — CONTENIDO (GDD_v3 §7.2 P6): recorre con el sim REAL lo que escribió el paquete y
# lo comprueba con el motor de los otros paquetes (sin ventana; acciones reales, nada a mano en el estado salvo lo
# que se indica):
#   1. prólogo: el encargo v3 (una pregunta; seis crónicas) y la línea t_read de Pell (abrir el expediente);
#   2. las seis crónicas del cliente (holder tomo): ficha de Lisle, marquitas, notas al margen y tarjeta NC.* como
#      última hoja; recortar el #tic de la tarjeta y el margen D01N#fina_fo da recortes con su origen y etiquetas;
#   3. leer la hoja de D03#sheer hace nacer Q2;
#   4. la primera bajada a la tienda (1.M) dice CRANE.intro; «¿Dónde consigo…?» ofrece los ítems; preguntar
#      donde.registros (con «testamento» conocido) pone Somerset House en el plano con «Me lo dijo Crane.» y su «qué hay»;
#   5. la segunda bajada no repite la presentación (once) [si el motor todavía no aplica once, AVISO, no falla];
#   6. el plano: cada lugar revelado tiene su línea plano.que_hay.<L> en ui_text.
#   ./godot.sh --headless -s devtools/drivers/v3cont_check.gd
# Salida: «V3CONT OK» o «V3CONT FALLA <n>» con una línea «V3CONT FALLA: …» por chequeo.
extends SceneTree

const GameSim = preload("res://core/sim/game_sim.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
const BotBase = preload("res://devtools/bots/bot_base.gd")

var fails := 0
var repo
var sim

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("V3CONT FALLA: ", what)

func note(s: String) -> void:
	print("V3CONT ", s)

func _init() -> void:
	repo = load("res://core/data/data_repo.gd").load_dir("res://data")
	ok(repo.errors().is_empty(), "datos sin errores: %s" % str(repo.errors().slice(0, 5)))
	sim = GameSim.new(repo, 1894)
	_prologue()
	_chronicles()
	_crane()
	_map_lines()
	print("V3CONT OK" if fails == 0 else "V3CONT FALLA %d" % fails)
	quit(0 if fails == 0 else 1)

# recorta la mejor ventana legal (≤15 palabras) de un tramo de una vista; devuelve el id del recorte
func _clip(view: String, tid: String, block_doc := "") -> String:
	var v: Dictionary = sim.q_view(view)
	var pages: Array = v.get("pages", [])
	for pi in pages.size():
		for bi in (pages[pi] as Array).size():
			var b: Dictionary = pages[pi][bi]
			if block_doc != "" and String(b.get("doc", "")) != block_doc:
				continue
			for tr in b.get("parsed", {}).get("tramos", []):
				if String(tr.id) == tid:
					var sp: Array = BotBase.best_window(b.parsed, int(tr.from), int(tr.to))
					var r: Dictionary = sim.apply({"t": "clip_text", "src": {"kind": "doc", "ref": view, "part": pi, "block": bi},
						"from": int(sp[0]), "len": int(sp[1]) - int(sp[0])})
					ok(bool(r.get("ok", false)), "recortar %s#%s en %s: %s" % [block_doc, tid, view, str(r)])
					return String(r.get("clip", ""))
	ok(false, "no encontré el tramo #%s (%s) en %s" % [tid, block_doc, view])
	return ""

func _prologue() -> void:
	var lines: Array = []
	for uid in sim.st.world.get("lines", {}):
		lines.append(sim.st.world.lines[uid])
	var t_read := false
	for ln in repo.scene("PRO").lines:
		if String(ln.id) == "t_read":
			t_read = String(ln.text).contains("abra el expediente")
	ok(t_read, "PRO.t_read pide abrir el expediente")
	var v: Dictionary = sim.q_view("D23@L1")
	ok(not v.is_empty(), "el encargo se lee en el prólogo")
	var plain := ""
	for pg in v.get("pages", []):
		for b in pg:
			plain += String(b.parsed.plain) + "\n"
	ok(plain.contains("Primero: la familia quiere saber qué no contó el doctor en «El problema final»."), "D23: una sola pregunta, la del cliente")
	ok(plain.contains("seis crónicas del doctor") and plain.contains("«Estudio en escarlata»") and plain.contains("«El signo de los cuatro»"), "D23: las seis crónicas en el punto Quinto")
	ok(plain.contains("por lo menos seis respuestas confirmadas, con sus pruebas"), "D23: la meta v3")
	ok(not plain.contains("conclusi"), "D23 sin «conclusión»")
	# prólogo como lo hace el novato
	ok(sim.apply({"t": "read", "view": "D23@L1", "part": 0}).ok, "leer el encargo")
	ok(_clip("D23@L1", "aviso") != "", "recortar el aviso")
	ok(sim.apply({"t": "compose_ad", "form": "testigo", "fields": {"suceso": "suceso_reichenbach"}}).ok, "el aviso")
	ok(sim.apply({"t": "sleep"}).ok, "dormir")
	var c: Dictionary = sim.q_clock()
	note("día %s %s (%s)" % [c.day, c.slot, c.phase])

func _chronicles() -> void:
	var specs := {"D03@tomo": ["NC.FINA", ["sheer", "a_mycroft"], ["fina_fo", "nov93"]],
		"D01.GREE@tomo": ["NC.GREE", ["pall_mall", "whitehall", "club", "horario"], []],
		"D43@tomo": ["NC.STUD", ["oyen_todo", "wiggins_solo"], []],
		"D44@tomo": ["NC.SIGN", ["ceniza_negra", "oficios_mano", "conoce_mary"], []],
		"D01.SCAN@tomo": ["NC.SCAN", ["mozo", "clerigo"], []],
		"D01.TWIS@tomo": ["NC.TWIS", ["viejo", "james"], ["mi_james"]]}
	for view in specs:
		var sp: Array = specs[view]
		var v: Dictionary = sim.q_view(view)
		ok(not v.is_empty(), "%s a la vista en casa" % view)
		if v.is_empty():
			continue
		var fi = v.get("ficha")
		ok(typeof(fi) == TYPE_DICTIONARY and String(fi.get("trata", "")) != "" and String(fi.get("por_que", "")) != "", "%s: ficha de Lisle" % view)
		var marks: Array = []
		for m in v.get("marks", []):
			marks.append(String(m.tramo))
		for t in sp[1]:
			ok(marks.has(t), "%s: marquita en #%s (tiene %s)" % [view, t, str(marks)])
		var margin: Array = []
		var card := false
		var pages: Array = v.get("pages", [])
		for pg in pages:
			for b in pg:
				if String(b.get("slot", "")) == "margen":
					margin.append(String(b.get("part", "")))
		for b in pages[-1]:
			if String(b.get("slot", "")) == "tarjeta" and String(b.get("doc", "")) == sp[0]:
				card = true
		for t in sp[2]:
			ok(margin.has(t), "%s: nota al margen D01N#%s (tiene %s)" % [view, t, str(margin)])
		ok(card, "%s: la última hoja es la tarjeta %s" % [view, sp[0]])
		note("%s: %d hojas, marquitas %s, margen %s" % [view, pages.size(), str(marks), str(margin)])
	# recortes de la tarjeta y del margen
	var c1 := _clip("D03@tomo", "tic", "NC.FINA")
	var k1: Dictionary = sim.st.ded.get("clips", {}).get(c1, {}) if c1 != "" else {}   # interno: CON etiquetas (q_clip las oculta, T8)
	ok(String(k1.get("origin", "")) == "NC.FINA", "el recorte del #tic sale de la tarjeta: %s" % str(k1.get("origin", "")))
	ok(str(k1.get("tags", [])).contains("rasgo_de_harris"), "el #tic hereda rasgo_de_harris: %s" % str(k1.get("tags", [])))
	var c2 := _clip("D03@tomo", "fina_fo", "D01N")
	var k2: Dictionary = sim.st.ded.get("clips", {}).get(c2, {}) if c2 != "" else {}
	ok(String(k2.get("origin", "")) == "D01N", "el recorte del margen sale de D01N: %s" % str(k2.get("origin", "")))
	ok(str(k2.get("tags", [])).contains("raspadura_registrada"), "fina_fo hereda raspadura_registrada: %s" % str(k2.get("tags", [])))
	# leer la hoja de #sheer hace nacer Q2
	var v3: Dictionary = sim.q_view("D03@tomo")
	var sheer_page := -1
	for pi in (v3.get("pages", []) as Array).size():
		for b in v3.pages[pi]:
			for tr in b.get("parsed", {}).get("tramos", []):
				if String(tr.id) == "sheer" and String(b.get("doc", "")) == "D03":
					sheer_page = pi
	ok(sheer_page >= 0, "la hoja de #sheer")
	for pi in range(0, sheer_page + 1):
		sim.apply({"t": "read", "view": "D03@tomo", "part": pi})
	var open_ids: Array = []
	for h in sim.q_dossier().get("open", []):
		open_ids.append(String(h.id))
	ok(open_ids.has("Q1") and open_ids.has("Q2"), "Q1 y Q2 abiertas tras leer #sheer: %s" % str(open_ids))

func _crane_lines() -> int:
	var n := 0
	for uid in sim.st.world.get("lines", {}):
		if String(sim.st.world.lines[uid].get("scene", "")) == "CRANE":
			n += 1
	return n

func _crane() -> void:
	var c: Dictionary = sim.q_clock()
	ok(int(c.day) >= 1 and String(c.phase) == "desk", "en casa el día 1: %s" % str(c))
	ok(sim.q_donde().is_empty(), "antes de la presentación no hay «¿Dónde consigo…?»")
	var r: Dictionary = sim.apply({"t": "go", "place": "L1", "area": "tienda"})
	ok(bool(r.get("ok", false)), "bajar a la tienda: %s" % str(r))
	ok(_crane_lines() == 1, "CRANE.intro se dijo (líneas: %d)" % _crane_lines())
	ok(Dialogue.crane_presented(sim.st), "Crane presentado")
	var items: Array = sim.q_donde()
	var ids: Array = items.map(func(x): return String(x.id))
	note("¿Dónde consigo…? %s" % str(ids))
	ok(ids.has("donde.diarios") and ids.has("donde.direcciones"), "ítems sin requisito a la vista")
	ok(items.size() <= 7, "como mucho 7 ítems al principio (%d)" % items.size())
	# conocer «testamento» (lo nombra el bibliotecario o D19): se simula sabido para preguntar por los registros
	sim.st.world.known["testamento"] = 0
	ids = sim.q_donde().map(func(x): return String(x.id))
	ok(ids.has("donde.registros"), "conocido «testamento», se ofrece donde.registros")
	var known_before: bool = sim.q_place_known("L6")
	var a: Dictionary = sim.apply({"t": "ask_donde", "char": "crane", "item": "donde.registros"})
	ok(bool(a.get("ok", false)), "preguntar donde.registros: %s" % str(a))
	var txt := String(a.get("line", {}).get("text", ""))
	ok(txt.contains("Somerset House"), "Crane contesta en personaje: %s" % txt)
	if not known_before:
		ok(String(a.get("revealed", "")) == "L6", "Somerset House entra al plano: %s" % str(a.get("revealed", "")))
		var why := {}
		for p in sim.q_places():
			if String(p.id) == "L6":
				why = p.por_que
				ok(repo.text(String(p.que_hay)) != String(p.que_hay), "L6 tiene su «qué hay»")
		ok(String(why.get("text", "")) == "Me lo dijo Crane.", "por qué está: %s" % str(why))
	ok(sim.apply({"t": "leave"}).ok, "subir")
	# segunda bajada: sin repetir la presentación
	ok(sim.apply({"t": "go", "place": "L1", "area": "tienda"}).ok, "bajar otra vez")
	if _crane_lines() > 1:
		note("AVISO: CRANE.intro se repitió (once todavía no lo aplica WorldModel.start_visit: diff propuesto a CORE)")
	ok(sim.apply({"t": "leave"}).ok, "subir otra vez")

func _map_lines() -> void:
	for L in ["L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8"]:
		var k: String = "plano.que_hay." + String(L)
		ok(repo.text(k) != k, "ui_text %s" % k)
		if L != "L1":
			var k2: String = "plano.por_que." + String(L)
			ok(repo.text(k2) != k2, "ui_text %s" % k2)
