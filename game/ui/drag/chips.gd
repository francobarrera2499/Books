# ui/drag/chips.gd — datos y vista previa del arrastre (ARCHITECTURE §6.3). Dueño: UI-MUNDO (v3). Estática.
# Datos de arrastre (DnD nativo de Godot): {"kind": "clip"|"pregunta"|"ent", "id": String}.
#   data(kind, id) -> Dictionary · valid(d) -> bool · label(d, sim = Game.sim) -> String (texto del chip, sin pistas:
#   el mismo trato para todo) · preview(d) -> Control (Widgets.chip) · ghost() -> Control invisible para
#   set_drag_preview (la vista previa la dibuja DragLayer en la capa 120, por encima de libros y modales).
# Destinos (GDD_v3 §6.1, §6.10): ranuras de pruebas del expediente (clip) y su respuesta (ent) · sobre del informe ·
#   personaje en 3D (present: un recorte o una pregunta). Sin pares ni asientos (v3).
extends RefCounted

const Widgets = preload("res://ui/kit/widgets.gd")

const KINDS := ["clip", "pregunta", "ent"]
const PRESENTABLE := ["clip", "pregunta"]
const MAX_WORDS := 7

static func data(kind: String, id: String) -> Dictionary:
	return {"kind": kind, "id": id}

static func valid(d) -> bool:
	return typeof(d) == TYPE_DICTIONARY and KINDS.has(String(d.get("kind", ""))) and String(d.get("id", "")) != ""

static func presentable(d) -> bool:
	return valid(d) and PRESENTABLE.has(String(d.kind))

static func _sim():
	var ml = Engine.get_main_loop()
	if ml is SceneTree and ml.root != null:
		var g = ml.root.get_node_or_null("Game")
		if g != null:
			return g.get("sim")
	return null

# Primeras palabras entre comillas (las tiras se reconocen por su texto, como en el cuaderno).
static func excerpt(text: String, words := MAX_WORDS) -> String:
	var parts := text.strip_edges().split(" ", false)
	if parts.size() <= words:
		return "«%s»" % " ".join(parts)
	return "«%s…»" % " ".join(parts.slice(0, words))

static func label(d: Dictionary, sim = null) -> String:
	if not valid(d):
		return ""
	if sim == null:
		sim = _sim()
	var id := String(d.id)
	match String(d.kind):
		"clip":
			if sim != null:
				var c: Dictionary = sim.q_clip(id)
				if not c.is_empty():
					var t := String(c.get("text", ""))
					if t == "" or String(c.get("kind", "")) == "plate":
						t = String(c.get("caption", t))
					return excerpt(t)
			return Widgets.t("shell.chip.clip", {"id": id})
		"pregunta":
			if sim != null and sim.has_method("q_dossier"):
				var dq: Dictionary = sim.q_dossier()
				for h in (dq.get("open", []) as Array) + (dq.get("inked", []) as Array):
					if typeof(h) == TYPE_DICTIONARY and String(h.get("id", "")) == id:
						return String(h.get("text", id))
			return id
		"ent":
			if sim != null:
				for x in sim.q_index():
					if String(x.get("id", "")) == id:
						return String(x.get("label", id))
				if sim.repo != null:
					var en: Dictionary = sim.repo.entity(id)
					if not en.is_empty():
						return preload("res://core/deduction/index.gd").display(sim.repo, id)
			return id
	return id

static func preview(d: Dictionary) -> Control:
	var c := Widgets.chip(label(d), d)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.modulate.a = 0.92
	return c

static func ghost() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(1, 1)
	c.modulate.a = 0.0
	return c
