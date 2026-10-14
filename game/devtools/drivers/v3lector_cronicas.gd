# devtools/drivers/v3lector_cronicas.gd — LECTOR (GDD_v3 §3.2, §6.7): las seis crónicas del cliente en el lector flotante,
# con datos reales (WorldModel.view_any sobre el sim de tests/fixtures/v3), sobre la buhardilla real. Para MIRAR: la ficha
# arriba de la hoja 1, cada marquita junto a su tramo (la hoja desplazada hasta ella), las notas al margen y la tarjeta.
#   ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://devtools/blank.tscn v3lcr res://devtools/drivers/v3lector_cronicas.gd
# Capturas (.work/shots/v3lcr_<código>_<n>.png): <código>_h1, <código>_m<tramo>, <código>_tarjeta.
# Salida: «V3LCR OK» o «V3LCR FALLA <n>».
extends RefCounted

const Base = preload("res://devtools/drivers/v3lector_shots.gd")
const Reader = preload("res://ui/reader/document_reader.gd")
const V3Fixture = preload("res://tests/fixtures/v3/v3_fixture.gd")
const WorldModel = preload("res://core/sim/world_model.gd")

const REFS := {"fina": "D03@tomo", "gree": "D01.GREE@tomo", "stud": "D43@tomo", "sign": "D44@tomo",
	"scan": "D01.SCAN@tomo", "twis": "D01.TWIS@tomo"}

var tool
var fails := 0

func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		print("V3LCR FALLA: ", what)

func drive(p_tool, scene) -> void:
	tool = p_tool
	tool.create_timer(300.0).timeout.connect(func():
		print("V3LCR VIGIA: se corta a los 300 s")
		tool.quit(2))
	for c in scene.get_children():
		c.queue_free()
	await tool.frames(2)
	var repo = tool.root.get_node("Data").repo()
	var sim = V3Fixture.sim(repo)
	var base = Base.new()
	base.tool = tool
	base.repo = repo
	base._room(scene)
	await tool.frames(60)
	var rd = Reader.new()
	rd.sounds = false
	rd.emit_read = false
	rd.act_fn = func(_a): return {"ok": false, "err": "desconocido"}
	scene.add_child(rd)
	await tool.frames(4)
	var vps: Vector2 = tool.root.get_viewport().get_visible_rect().size
	for code in REFS:
		var v: Dictionary = WorldModel.view_any(sim.st, repo, REFS[code])
		ok(not v.is_empty(), "%s: hay vista" % code)
		if v.is_empty():
			continue
		var marks: Array = v.get("marks", [])
		print("V3LCR %s: %d hojas, ficha %s, %d marquitas" % [code, v.pages.size(), v.get("ficha") != null, marks.size()])
		ok(v.get("ficha") != null, "%s: ficha" % code)
		ok(rd.open_view(v), "%s: abre" % code)
		await tool.frames(12)
		ok(rd.page.ficha_rtl != null, "%s: ficha arriba de la hoja 1" % code)
		await tool.snap("%s_h1" % code)
		for mk in marks:
			rd.go_page(int(mk.page))
			await tool.frames(6)
			var drawn := false
			for mr in rd.page.mark_rects():
				if String(mr.tramo) == String(mk.tramo):
					drawn = true
					# la marquita a media pantalla (como si el jugador hubiera bajado hasta ella)
					var y: float = rd._stage.position.y + (mr.rect as Rect2).position.y * rd.zoom
					rd._stage.position.y -= y - vps.y * 0.4
					rd._clamp_pan()
			ok(drawn, "%s: marquita #%s dibujada" % [code, mk.tramo])
			await tool.frames(4)
			await tool.snap("%s_m%s" % [code, mk.tramo])
		rd.go_page(rd.page_count() - 1)
		await tool.frames(6)
		ok(rd.page.card, "%s: la última hoja es la tarjeta" % code)
		await tool.snap("%s_tarjeta" % code)
		rd.close()
		await tool.frames(4)
	print("V3LCR OK" if fails == 0 else "V3LCR FALLA %d" % fails)
