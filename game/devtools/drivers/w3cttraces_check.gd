# Diagnóstico W3-CT-TRACES: rutas del contrato que tocan D12, D13, D14, D18, D19, D20, D22, D30, D31, D33, D34, D35,
# D45 sobre data/ real, y las pistas falsas que refutan (falsa_jartum, falsa_herencia, falsa_rio_cuerpo).
# ./godot.sh --headless -s devtools/drivers/w3cttraces_check.gd
# Imprime por ruta cada fragmento (origen, clase, etiquetas, entidades; * = clave de la conclusión), linked, grupos que
# faltan y el lint de la conclusión; luego las pistas falsas y los errores de DataRepo atribuibles a estos archivos.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const MINE := ["D12", "D13", "D14", "D18", "D19", "D20", "D22", "D30", "D31", "D33", "D34", "D35", "D45"]
const LEADS := ["falsa_jartum", "falsa_herencia", "falsa_rio_cuerpo"]

func _init() -> void:
	_run.call_deferred()

func _mine(ref: String) -> bool:
	for d in MINE:
		if ref.begins_with(d + "#") or ref.begins_with(d + "@"):
			return true
	return false

func _run() -> void:
	var r = Repo.fresh("res://data")
	var errs: Array = []
	for e in r.errors():
		if _mine_err(String(e)):
			errs.append(e)
	print("ERRORES PROPIOS: ", errs.size())
	for e in errs:
		print("  ", e)
	for c in r.conclusions():
		var cid := String(c.id)
		var kents: Array = c.get("keys", {}).get("entities", [])
		var touched := false
		for rt in RouteDB.routes(r, cid):
			var any := false
			for f in rt.get("frags", []):
				if _mine(String(f.get("ref", ""))):
					any = true
			if not any:
				continue
			touched = true
			print("\n", cid, " ", rt.get("id", "?"), " linked=", RouteDB.linked(r, c, rt.frags), " faltan=", RouteDB.missing_groups(r, c, rt), " from=", rt.get("from", ""))
			for f in rt.frags:
				var es: Array = []
				for e in f.get("ents", []):
					es.append(("*" if kents.has(e) else "") + String(e))
				print("   ", f.get("ref", ""), " @", f.get("copy", ""), " orig=", f.get("origin", ""), " cls=", f.get("cls", ""), " mask=", f.get("mask", 0), " tags=", f.get("tags", []), " ents=", es, (" FALTA=" + String(f.missing)) if String(f.get("missing", "")) != "" else "")
		if touched:
			var l: Dictionary = RouteDB.lint(r, cid)
			print(" LINT ", cid, " errors=", l.get("errors", []), " pending=", (l.get("pending", []) as Array).slice(0, 6))
	var fl: Dictionary = RouteDB.false_leads(r)
	print("\nPISTAS FALSAS: errores=", fl.get("errors", []), " pendientes=", fl.get("pending", []))
	for x in fl.get("leads", {}):
		if LEADS.has("falsa_" + String(x)) or LEADS.has(String(x)):
			print("  ", x, " -> ", fl.leads[x])
	quit()

func _mine_err(e: String) -> bool:
	for d in MINE:
		if e.contains("docs/" + d) or e.contains(d + "#") or e.contains(d + "@"):
			return true
	return e.contains("ct_traces")
