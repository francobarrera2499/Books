# ui/desk/fallback.gd — respaldos mínimos de la Shell para paneles de otros paquetes que todavía no existen
# (W3-NOTEBOOK, W3-LEDGER, W3-SCENEUI, W4-EPILOGUE), para que la partida nunca quede trabada; y el dataset de desarrollo
# (--data=fixture). Dueño: W3-SHELL. Placeholders que se entienden (design.md): una hoja que dice qué falta.
#   make(kind, shell) -> Node   (report: «Sin novedad»; scene: las líneas dichas; confront: callar; resto: hoja)
#   data_repo(spec, dst := "") -> DataRepo  spec "fixture" = data/ estructural + tests/fixtures/integ (como test_i_integration),
#                                 armado en .work/w3shell/data_fixture/; otra cosa = ruta de un dataset.
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")
const Paper = preload("res://ui/kit/paper.gd")

const FIX := "res://tests/fixtures/integ"
const CONTENT_DIRS := ["docs/", "dialogue/", "scenes/", "catalog/"]
const STRUCT_ENTITIES := ["entities/core.json", "entities/struct.json", "entities/places_a.json", "entities/places_b.json", "entities/places_c.json", "entities/v2_fisica.json",
	"entities/v3_core.json", "entities/v3_reacciones.json", "entities/v3_contenido.json"]  # v3 (GDD_v3 §7.1): las nombran dossier.json y reactions/

static func make(kind: String, shell) -> Node:
	match kind:
		"report":
			var r := Report.new()
			r.shell = shell
			return r
		"scene":
			var s := Lines.new()
			s.shell = shell
			return s
		"confront":
			var c := Confront.new()
			c.shell = shell
			return c
	var p := Sheet.new()
	p.kind = kind
	return p

# ------------------------------------------------------------------ dataset de desarrollo
static func _rel_files(root: String, rel := "") -> Array:
	var out: Array = []
	var dir := root.path_join(rel) if rel != "" else root
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(rel.path_join(f) if rel != "" else f)
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d.begins_with("_"):
			continue
		out.append_array(_rel_files(root, rel.path_join(d) if rel != "" else d))
	return out

static func _structural(rel: String) -> bool:
	for d in CONTENT_DIRS:
		if rel.begins_with(d):
			return false
	if rel.begins_with("entities/"):
		return STRUCT_ENTITIES.has(rel)
	return true

# dst: carpeta destino (bajo .work/); "" = .work/w3shell/data_fixture (los tests pasan su tmp_dir()).
static func build_fixture_dir(p_dst := "") -> String:
	var dst := p_dst if p_dst != "" else ProjectSettings.globalize_path("res://").path_join("../.work/w3shell/data_fixture").simplify_path()
	if not dst.replace("\\", "/").contains("/.work/"):
		return ""
	_wipe(dst)
	DirAccess.make_dir_recursive_absolute(dst)
	var real := ProjectSettings.globalize_path("res://data")
	var fix := ProjectSettings.globalize_path(FIX)
	for rel in _rel_files(real):
		if not _structural(rel):
			continue
		var to := dst.path_join(rel)
		DirAccess.make_dir_recursive_absolute(to.get_base_dir())
		DirAccess.copy_absolute(real.path_join(rel), to)
	for rel in _rel_files(fix):
		var to2 := dst.path_join(rel)
		DirAccess.make_dir_recursive_absolute(to2.get_base_dir())
		DirAccess.copy_absolute(fix.path_join(rel), to2)
	return dst

static func _wipe(p: String) -> void:
	if not DirAccess.dir_exists_absolute(p):
		return
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))
	for d in DirAccess.get_directories_at(p):
		_wipe(p.path_join(d))
		DirAccess.remove_absolute(p.path_join(d))

static func data_repo(spec: String, dst := ""):
	var DR = load("res://core/data/data_repo.gd")
	var root := spec
	if spec == "fixture":
		root = build_fixture_dir(dst)
		if root == "":
			return null
	DR.clear_cache(root)
	return DR.fresh(root)

# ------------------------------------------------------------------ hojas
class Centered:
	static func center(c: Control) -> void:
		if c == null or not is_instance_valid(c) or not c.is_inside_tree():
			return
		var vs := c.get_viewport().get_visible_rect().size
		c.reset_size()
		c.position = ((vs - c.size) * 0.5).floor()

class Sheet extends PanelContainer:
	func _cc(c: Control) -> void:
		Centered.center(c)
	signal closed
	var kind := ""
	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("cuaderno", {"margin": 28, "shadow": true, "shadow_size": 12})))
	func _ready() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		add_child(v)
		v.add_child(Widgets.heading(Widgets.t("shell.fb." + kind)))
		var b := Widgets.marginal(Widgets.t("shell.fb.pendiente"))
		b.custom_minimum_size = Vector2(420, 0)
		v.add_child(b)
		v.add_child(Widgets.ink_button(Widgets.t("kit.close"), close))
	func open() -> void:
		visible = true
		_cc.call_deferred(self)
	func close() -> void:
		visible = false
		closed.emit()

# Informe sin compositor: sólo «Sin novedad» (modo nada), con su confirmación. El compositor real es de W3-SCENEUI.
class Report extends Control:
	func _cc(c: Control) -> void:
		Centered.center(c)
	signal closed
	var shell = null
	var _c: Control = null
	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func open() -> void:
		if _c != null and is_instance_valid(_c):
			_c.queue_free()
		_c = Widgets.confirm(Widgets.t("shell.fb.report_body"), Widgets.t("shell.fb.report_ok"), Widgets.t("kit.confirm.back"), Widgets.t("shell.fb.report"))
		add_child(_c)
		_c.decided.connect(_decided)
		visible = true
		_cc.call_deferred(_c)
	func _decided(ok: bool) -> void:
		if ok and shell != null:
			var r: Dictionary = shell.act({"t": "report_submit", "mode": "nada", "items": []})
			if not bool(r.get("ok", false)):
				shell.note(shell.err_text(String(r.get("err", ""))))
			else:
				shell.play("sfx.sobre")
		close()
	func close() -> void:
		if _c != null and is_instance_valid(_c):
			_c.queue_free()
		_c = null
		visible = false
		closed.emit()

# Escena sin panel: las líneas dichas, recortables (src line).
class Lines extends PanelContainer:
	func _cc(c: Control) -> void:
		Centered.center(c)
	signal closed
	const ClipLabel = preload("res://ui/desk/clip_label.gd")
	var shell = null
	var _box: VBoxContainer
	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 24, "shadow": true, "shadow_size": 12})))
	func _ready() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var h := Widgets.heading(Widgets.t("shell.fb.scene"))
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(h)
		top.add_child(Widgets.ink_button(Widgets.t("kit.close"), close))
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(620, 380)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(sc)
		_box = VBoxContainer.new()
		_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_box.add_theme_constant_override("separation", 10)
		sc.add_child(_box)
	func open(_who = null) -> void:
		for c in _box.get_children():
			c.queue_free()
		var sim = shell.sim() if shell != null else null
		if sim != null:
			var labels := {}
			for ch in sim.q_scene().get("chars", []):
				labels[String(ch.id)] = String(ch.get("label", ch.id))
			for ln in sim.q_scene().get("lines", []):
				var who := Widgets.label(String(labels.get(String(ln.who), ln.who)), "SourceLine")
				who.uppercase = true
				_box.add_child(who)
				var t := ClipLabel.new()
				t.custom_minimum_size = Vector2(580, 0)
				t.setup(ln.get("parsed", {}), {"kind": "line", "ref": String(ln.uid)})
				_box.add_child(t)
		visible = true
		_cc.call_deferred(self)
	func close() -> void:
		visible = false
		closed.emit()

# Confrontación sin vista propia: la afirmación del librero y «Callar» (no es error, T18).
class Confront extends PanelContainer:
	func _cc(c: Control) -> void:
		Centered.center(c)
	signal closed
	var shell = null
	var _text: Label
	func _init() -> void:
		visible = false
		mouse_filter = Control.MOUSE_FILTER_STOP
		Widgets.restyle(self, func(): add_theme_stylebox_override("panel", Paper.style("carta", {"margin": 24, "shadow": true, "shadow_size": 12})))
	func _ready() -> void:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		add_child(v)
		v.add_child(Widgets.heading(Widgets.t("shell.fb.confront")))
		_text = Widgets.caption("")
		_text.custom_minimum_size = Vector2(480, 0)
		v.add_child(_text)
		v.add_child(Widgets.ink_button(Widgets.t("shell.fb.callar"), _hush))
	func open() -> void:
		_refresh()
		visible = true
		_cc.call_deferred(self)
	func _refresh() -> void:
		var sim = shell.sim() if shell != null else null
		if sim == null:
			return
		var q: Dictionary = sim.q_confront()
		_text.text = String(q.get("statement", ""))
		if bool(q.get("done", false)):
			close()
	func _hush() -> void:
		var sim = shell.sim() if shell != null else null
		if sim == null:
			return
		var q: Dictionary = sim.q_confront()
		var r: Dictionary = shell.act({"t": "confront", "step": int(q.get("step", 0)), "item": {}})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
		_refresh()
	func close() -> void:
		visible = false
		closed.emit()

# Epílogo sin pantalla de W4-EPILOGUE: las líneas del epílogo, la decisión de la errata y el fin.
class Epilogue extends Control:
	var shell = null
	var _box: VBoxContainer
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _ready() -> void:
		var bg := ColorRect.new()
		bg.color = Paper.MESA
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var cc := CenterContainer.new()
		cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(cc)
		var sheet := Widgets.sheet("strand", {"pad": 36})
		cc.add_child(sheet)
		_box = VBoxContainer.new()
		_box.add_theme_constant_override("separation", 12)
		_box.custom_minimum_size = Vector2(620, 0)
		sheet.add_child(_box)
		_fill()
	func _fill() -> void:
		for c in _box.get_children():
			c.queue_free()
		_box.add_child(Widgets.heading(Widgets.t("shell.fb.epilogue")))
		var sim = shell.sim() if shell != null else null
		if sim == null:
			return
		for ln in sim.q_scene().get("lines", []):
			var r := Widgets.rich("DocBody")
			r.add_text(String(ln.get("parsed", {}).get("plain", "")))
			_box.add_child(r)
		var c: Dictionary = sim.q_clock()
		if String(c.phase) == "epilogue":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 20)
			row.add_child(Widgets.ink_button(Widgets.t("shell.fb.errata_si"), func(): _errata(true)))
			row.add_child(Widgets.ink_button(Widgets.t("shell.fb.errata_no"), func(): _errata(false)))
			row.add_child(Widgets.button(Widgets.t("shell.fb.fin"), _end))
			_box.add_child(row)
		else:
			_box.add_child(Widgets.button(Widgets.t("shell.fb.fin"), _end))
	func _errata(yes: bool) -> void:
		var r: Dictionary = shell.act({"t": "publish_errata", "yes": yes})
		if not bool(r.get("ok", false)):
			shell.note(shell.err_text(String(r.get("err", ""))))
	func _end() -> void:
		var sim = shell.sim()
		if sim != null and String(sim.q_clock().phase) == "epilogue":
			shell.act({"t": "leave"})
		shell.quit_to_title()
