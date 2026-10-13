# ui/scene/sim_link.gd — enlace común de W3-SCENEUI con la sesión (escena, confrontación y compositores). Dueño: W3-SCENEUI.
# Una instancia por componente (o compartida entre un componente y sus subpaneles). Nada aquí muta estado salvo act().
#   sim_override: GameSim inyectada (tests, drivers); si es null se usa Game.sim (autoload).
#   act_fn: Callable(a) -> Dictionary; si no es válido se usa Game.act(a) (único camino de la UI para mutar, §2.2).
#   sounds: reproducir Audio.play en aperturas y envíos (false en tests).
# Lecturas: sim(), repo(), q(name, args...) (consultas q_* de §3.7 con respaldo vacío), t(key, vars) (ui_text), err_text(code)
#   (voz de Lisle para un código de error de §3.5), who_label(who, chars) (nombre visible de quien habla: el nombre sólo si
#   se presentó, si no el sustantivo de la entidad), item_text(item) (texto breve de un recorte o asiento), entry_summary(e).
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Deps = preload("res://core/scenes/deps.gd")
const UiFlags = preload("res://ui/kit/ui_flags.gd")

const ERR_PREFIXES := ["sceneui.err.", "sim.err.", "clip.", "entry.", "pass.", "core.err."]

var sim_override = null
var act_fn: Callable = Callable()
var sounds := true
var last_act: Dictionary = {}      # última acción enviada (tests, depuración)

static func autoload(n: String) -> Node:
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		return ml.root.get_node_or_null(n)
	return null

static func ti() -> Node:
	return autoload("ThemeInstaller")

static func px(kind: String) -> int:
	var t := ti()
	if t == null:
		return {"doc": 21, "ui": 19, "small": 15, "title": 34, "caption": 16}.get(kind, 19)
	return int(t.px(kind))

static func font(slot: String, italic := false) -> Font:
	var t := ti()
	return t.font(slot, italic) if t != null else ThemeDB.fallback_font

func sim():
	if sim_override != null:
		return sim_override
	var g := autoload("Game")
	if g != null:
		return g.get("sim")
	return null

func uses_game() -> bool:
	return sim_override == null

# Revelado progresivo (GDD_v2 §C.2): q_ui() de la partida; sin partida, {} (todo visible).
func flags() -> Dictionary:
	return UiFlags.of(sim())

func flag(name: String, f = null) -> bool:
	return UiFlags.on(f if typeof(f) == TYPE_DICTIONARY else flags(), name)

func repo():
	var s = sim()
	if s != null and s.get("repo") != null:
		return s.repo
	var d := autoload("Data")
	return d.repo() if d != null else null

func q(name: String, args: Array = []):
	var s = sim()
	if s == null or not s.has_method(name):
		return null
	return s.callv(name, args)

func qa(name: String, args: Array = []) -> Array:
	var r = q(name, args)
	return r if typeof(r) == TYPE_ARRAY else []

func qd(name: String, args: Array = []) -> Dictionary:
	var r = q(name, args)
	return r if typeof(r) == TYPE_DICTIONARY else {}

func preview(a: Dictionary) -> String:
	var r = q("q_preview", [a])
	return String(r) if r != null else ""

func can(a: Dictionary) -> bool:
	var s = sim()
	if s == null or not s.has_method("can"):
		return false
	return bool(s.can(a).get("ok", false))

func act(a: Dictionary) -> Dictionary:
	last_act = a.duplicate(true)
	var r = null
	if act_fn.is_valid():
		r = act_fn.call(a)
	else:
		var g := autoload("Game")
		if g == null or g.get("sim") == null:
			return {"ok": false, "err": "no_sim"}
		r = g.act(a)
	return r if typeof(r) == TYPE_DICTIONARY else {"ok": false, "err": "desconocido"}

# ui_text con Deps.fill (contracciones de lists en las junturas: «a ${quien}» + «el doctor» -> «al doctor»).
func t(key: String, vars := {}) -> String:
	var r = repo()
	if r != null and r.has_method("texts") and r.texts().has(key):
		return Deps.fill(r, String(r.texts()[key]), vars) if not vars.is_empty() else String(r.texts()[key])
	return Widgets.t(key, vars)

func has_t(key: String) -> bool:
	var r = repo()
	return r != null and r.has_method("texts") and r.texts().has(key)

func err_text(code: String) -> String:
	if code == "":
		return ""
	for p in ERR_PREFIXES:
		if has_t(p + code):
			return t(p + code, {"n": "tres"})
	return t("core.err.desconocido")

func play(id: String) -> void:
	if not sounds:
		return
	var au := autoload("Audio")
	if au != null and au.has_method("play"):
		au.play(id)

# Rótulos fijos por quien habla (la confrontación: el librero es «Anciano encorvado» toda la escena, W4).
var who_override := {}

static var _intro_cache := {}     # {"sim": id, "n": líneas, "set": {who: true}}

# Se presentó él mismo en una línea dicha: el que habla se nombra con un vínculo a su propia entidad («[[pell|Josiah
# Pell]], procurador…»). GDD: el nombre se conoce cuando el personaje se presenta (W4: Pell seguía siendo «Procurador con
# cartera» el día 5). El índice del sim no lo registra porque las líneas de una escena fija no presentan a nadie.
static func introduced_by_line(s, who: String) -> bool:
	if s == null or who == "" or not (s is Object) or s.get("st") == null:
		return false
	var stv = s.get("st")
	var w = stv.get("world")
	var lines = w.get("lines", {}) if typeof(w) == TYPE_DICTIONARY else {}
	if typeof(lines) != TYPE_DICTIONARY:
		return false
	var sid := (s as Object).get_instance_id()
	if _intro_cache.is_empty() or int(_intro_cache.get("sim", 0)) != sid or int(_intro_cache.get("n", -1)) != lines.size():
		# por escena (origen de la línea): quiénes hablan y a quiénes se nombra con vínculo. Presentado = habla en esa
		# escena y alguien de esa escena (él mismo u otro: «El caballero es el [[harris|mayor Harris]]») lo nombra.
		var speakers := {}
		var named := {}
		for uid in lines:
			var rec = lines[uid]
			if typeof(rec) != TYPE_DICTIONARY:
				continue
			var org := String(rec.get("origin", rec.get("scene", "")))
			var wh := String(rec.get("who", ""))
			if not speakers.has(org):
				speakers[org] = {}
				named[org] = {}
			if wh != "":
				speakers[org][wh] = true
			var tx := String(rec.get("text", ""))
			var k := tx.find("[[")
			while k >= 0:
				var e := tx.find("]]", k)
				if e < 0:
					break
				var ent := tx.substr(k + 2, e - k - 2).get_slice("|", 0).strip_edges()
				if ent != "":
					named[org][ent] = true
				k = tx.find("[[", e)
		var found := {}
		for org in speakers:
			for wh in speakers[org]:
				if named[org].has(wh):
					found[wh] = true
		_intro_cache = {"sim": sid, "n": lines.size(), "set": found}
	return (_intro_cache.get("set", {}) as Dictionary).has(who)

# Nombre propio de un personaje (rótulo del diálogo o nombre de la entidad).
static func proper_name(r, who: String) -> String:
	if r == null:
		return who
	var dl: Dictionary = r.dialogue(who)
	var en: Dictionary = r.entity(who)
	return String(dl.get("label", en.get("name", who)))

# Nombre visible de quien habla. chars = q_scene().chars (ya resuelve «nombre sólo si se presentó»).
func who_label(who: String, chars: Array = []) -> String:
	if who == "" or who == "lisle":
		return t("sceneui.who.lisle")
	if who_override.has(who):
		return Deps.cap_first(String(who_override[who]))
	if introduced_by_line(sim(), who):
		return Deps.cap_first(proper_name(repo(), who))
	for c in chars:
		if typeof(c) == TYPE_DICTIONARY and String(c.get("id", "")) == who and String(c.get("label", "")) != "":
			return Deps.cap_first(String(c.label))
	var r = repo()
	if r == null:
		return who
	var known := false
	for x in qa("q_index"):
		if typeof(x) == TYPE_DICTIONARY and String(x.get("id", "")) == who:
			known = true
			break
	var dl: Dictionary = r.dialogue(who)
	var en: Dictionary = r.entity(who)
	var lab := ""
	if known or bool(dl.get("known", false)):
		lab = String(dl.get("label", en.get("name", who)))
	else:
		lab = String(en.get("noun", dl.get("label", en.get("name", who))))
	return Deps.cap_first(lab)

# Etiqueta de una entidad del índice del jugador (runtime act.* incluidas).
func ent_label(id: String) -> String:
	for x in qa("q_index"):
		if typeof(x) == TYPE_DICTIONARY and String(x.get("id", "")) == id:
			return String(x.get("label", id))
	var r = repo()
	if r != null:
		var e: Dictionary = r.entity(id)
		if not e.is_empty():
			return preload("res://core/deduction/index.gd").display(r, id)
	return id

# Resumen de un asiento (q_entry): «Fuente: «El problema final» · Calla: la raspadura».
func entry_summary(e: Dictionary) -> String:
	var r = repo()
	if r == null or e.is_empty():
		return ""
	return Deps.entry_summary(r, e)

func template_name(tid: String) -> String:
	var tpls: Dictionary = qd("q_templates")
	var tp = tpls.get(tid, {})
	return String(tp.get("name", tid)) if typeof(tp) == TYPE_DICTIONARY else tid

# {kind, id} -> {title, body, source, ink} para tarjetas breves (selector, barra de presentar, ranuras del informe).
func item_info(item: Dictionary) -> Dictionary:
	var id := String(item.get("id", ""))
	if String(item.get("kind", "")) == "entry":
		var e: Dictionary = qd("q_entry", [id])
		if e.is_empty():
			return {"title": id, "body": "", "source": "", "ink": "lapiz", "ok": false}
		var ink := String(e.get("ink", "lapiz"))
		return {"title": template_name(String(e.get("template", ""))), "body": entry_summary(e),
			"source": t("sceneui.picker.tinta") if ink == "tinta" else t("sceneui.picker.lapiz"), "ink": ink, "ok": true}
	var c: Dictionary = qd("q_clip", [id])
	if c.is_empty():
		return {"title": id, "body": "", "source": "", "ink": "negra", "ok": false}
	var body := String(c.get("text", ""))
	if body == "":
		body = String(c.get("caption", ""))
	elif not body.contains("«") and not body.contains("»"):
		body = "«%s»" % body   # un recorte que ya trae comillas (cita, aviso) no se envuelve otra vez: «…»» no
	return {"title": "", "body": body, "source": String(c.get("src_line", "")), "ink": "negra", "ok": true, "caption": String(c.get("caption", ""))}

static func short(s: String, n := 90) -> String:
	var x := s.strip_edges().replace("\n", " ")
	if x.length() <= n:
		return x
	var cut := x.left(n)
	var sp := cut.rfind(" ")
	if sp > n * 0.6:
		cut = cut.left(sp)
	return cut + "…"

static func cap(s: String) -> String:
	return Deps.cap_first(s)

# «martes 27 de marzo» para un día del calendario (schedule.days; ui_text core.fecha.dia).
func day_label(day: int) -> String:
	var r = repo()
	if r == null:
		return str(day)
	for row in r.schedule().get("days", []):
		if int(row.get("day", -1)) != day:
			continue
		var date := String(row.get("date", ""))
		if date.length() < 10:
			return String(row.get("label", str(day)))
		return r.text("core.fecha.dia", {"wd": r.text("core.wd." + String(row.get("weekday", ""))),
			"d": date.substr(8, 2).to_int(), "mes": r.text("core.mes." + str(date.substr(5, 2).to_int()))})
	return str(day)

func st():
	var s = sim()
	return s.st if s != null and s.get("st") != null else null
