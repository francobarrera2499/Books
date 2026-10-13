# Diagnóstico W3-CT-MORAN: rutas del contrato que tocan D09/D10/D11/D16/D17/D32/D39 sobre data/ real.
# ./godot.sh --headless -s devtools/drivers/w3ctmoran_check.gd
# Imprime, por ruta, cada fragmento con origen, etiquetas y entidades (las que cuentan para el enlace por claves marcadas
# con *), el resultado de RouteDB.linked y los errores de RouteDB.lint de la conclusión.
extends SceneTree

const Repo = preload("res://core/data/data_repo.gd")
const RouteDB = preload("res://core/graph/route_db.gd")

const MINE := ["D09", "D10", "D11", "D16", "D17", "D32", "D39"]

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
			var refs: Array = []
			for f in rt.get("frags", []):
				refs.append(String(f.get("ref", "")))
			var any := false
			for x in refs:
				if _mine(x):
					any = true
			if not any:
				continue
			touched = true
			print("\n", cid, " ", rt.get("id", "?"), " linked=", RouteDB.linked(r, c, rt.frags), " from=", rt.get("from", ""))
			for f in rt.frags:
				var es: Array = []
				for e in f.get("ents", []):
					es.append(("*" if kents.has(e) else "") + String(e))
				print("   ", f.get("ref", ""), " @", f.get("copy", ""), " orig=", f.get("origin", ""), " cls=", f.get("cls", f.get("class", "")), " tags=", f.get("tags", []), " ents=", es, (" ERR=" + str(f.err)) if f.has("err") and String(f.err) != "" else "")
		if touched:
			var l: Dictionary = RouteDB.lint(r, cid)
			print(" LINT ", cid, " errors=", l.get("errors", []), " pending=", (l.get("pending", []) as Array).slice(0, 6))
	quit()

func _mine_err(e: String) -> bool:
	for d in MINE:
		if e.contains("docs/" + d) or e.contains(d + "#") or e.contains(d + "@"):
			return true
	return e.contains("ct_moran")
