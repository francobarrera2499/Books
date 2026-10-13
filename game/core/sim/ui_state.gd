# core/sim/ui_state.gd — revelado progresivo de la interfaz (GDD_v2 §C.2). Dueño: PROGRESIÓN.
# flags(st, repo) -> {bandera: bool}: fuente ÚNICA de qué controles existen ya. Sólo del estado de la partida
# (determinista, persiste al cargar, se prueba sin pantalla). Las vistas lo consumen y no deciden por su cuenta.
# Reglas (§C.1): nada visible que todavía no se pueda usar; lo que apareció no vuelve a desaparecer (salvo paneles
# contextuales: sc.*, cat.mesa, cmp.forma.*, cmp.quemar/trampa); NUNCA mira etiquetas ocultas ni conclusiones
# selladas (el revelado no depende de lo importante); sin contadores.
extends RefCounted

const Tutorial = preload("res://core/sim/tutorial.gd")
const Composers = preload("res://core/scenes/composers.gd")
const Index = preload("res://core/deduction/index.gd")

const INDICE_MIN := 12
const BUSCAR_MIN := 10
const FILTROS_MIN := 20

static func _n(d) -> int:
	return (d as Dictionary).size() if typeof(d) == TYPE_DICTIONARY else 0

static func _ded(st, k: String) -> Dictionary:
	var d = st.ded.get(k, {}) if typeof(st.ded) == TYPE_DICTIONARY else {}
	return d if typeof(d) == TYPE_DICTIONARY else {}

static func flags(st, repo) -> Dictionary:
	var c: Dictionary = st.clock
	var ph := String(c.get("phase", ""))
	var day := int(c.get("day", 0))
	var pro := ph == "prologue"
	var tstep := int(st.world.get("tutorial", {}).get("step", 0))
	var tut_done := Tutorial.complete(st) or not pro
	var clips := _ded(st, "clips")
	var pairs := _ded(st, "pairs")
	var entries := _ded(st, "entries")
	var taught: Array = Tutorial.verbs_taught(st)
	var f := {}
	# ---- escritorio y HUD ----
	f["desk.tijera"] = not pro or tstep >= Tutorial.step_index_of("clip_text")
	f["desk.tintero"] = not pro or tstep >= Tutorial.step_index_of("compose_ad")
	f["desk.calendario"] = not pro or tstep >= Tutorial.step_index_of("sleep") or tut_done
	f["desk.mapa"] = not pro
	f["desk.bandeja"] = day >= 1
	f["desk.pendientes"] = day >= 1 and not pro
	f["hud.cuaderno"] = clips.size() >= 1
	f["hud.libro"] = (not pro and day >= 1) or entries.size() >= 1
	# ---- cuaderno ----
	# una vez visto, no se va (§C.1): deshacer el último par no esconde la pestaña
	f["nb.pares"] = pairs.size() >= 1 or int(st.seq.get("pair", 0)) >= 1
	f["nb.diario"] = day >= 1 and not (st.world.get("diary", []) as Array).is_empty()
	f["nb.indice"] = _ded(st, "index").size() >= INDICE_MIN
	f["nb.curiosidades"] = _n(st.world.get("eggs", {})) >= 1
	f["nb.buscar"] = clips.size() >= BUSCAR_MIN
	f["nb.filtros"] = clips.size() >= FILTROS_MIN
	f["nb.agrupar"] = _months(clips) >= 2
	# ---- libro de conclusiones ----
	var varios := false
	var practica := false
	var draft := false
	var inked := false
	for eid in entries:
		var e = entries[eid]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var fo := String(e.get("folio", "varios"))
		var is_pr := bool(e.get("practice", false)) or fo == "erratas"
		if fo == "varios" or fo == "":
			varios = true
		if is_pr:
			practica = true
		elif String(e.get("ink", "lapiz")) != "tinta":
			draft = true
		else:
			inked = true
	# «Nueva hoja»: la enseña el día 1 (después de juntar el primer par); quien no juntó nada la tiene igual desde el día 2
	# con un recorte (sin ella no podría escribir conclusiones)
	f["lg.hoja_nueva"] = taught.has("folio_open") or int(st.seq.get("folio", 0)) >= 1 or (not pro and day >= 2 and clips.size() >= 1)
	f["lg.varios"] = varios
	f["lg.practica"] = practica or Tutorial.practice_done(st)
	# el sello no se va al confirmar el último borrador (lo confirmado queda)
	f["lg.sello"] = Tutorial.practice_done(st) and (draft or inked)
	# ---- escena ----
	f["sc.mostrar"] = clips.size() >= 1 or entries.size() >= 1
	f["sc.decir"] = _assertions_any(st, repo)
	var sil := false
	for ch in st.world.get("visit", {}).get("chars", []):
		if typeof(ch) == TYPE_DICTIONARY and bool(ch.get("sil", false)):
			sil = true
	f["sc.pagar"] = sil
	f["sc.encargar"] = sil
	# ---- compositores ----
	var mail := false
	if not pro:
		mail = not Composers.mail_options(st, repo, "to").is_empty()
	f["cmp.telegrama"] = mail
	f["cmp.carta"] = mail
	for fm in repo.lists().get("ad_forms", []):
		if typeof(fm) != TYPE_DICTIONARY:
			continue
		var fid := String(fm.get("id", ""))
		var full := true
		for slot in _sorted(fm.get("slots", {}).keys()):
			if Composers.options(st, repo, fid, String(slot)).is_empty():
				full = false
				break
		f["cmp.forma." + fid] = full
	f["cmp.quemar"] = ph == "final_report"
	f["cmp.trampa"] = ph == "final_report" and String(st.flags.get("errata_ofrecida", "")) != ""
	# ---- mapa, bandeja, catálogo, mirar alrededor ----
	f["map.recuerdos"] = _n(st.world.get("plates", {})) >= 1 and not pro
	f["tray.anteriores"] = day >= 2 and not pro
	var vid := String(st.world.get("visit", {}).get("id", ""))
	f["cat.mesa"] = vid != "" and not (st.world.get("slips", {}).get(vid, []) as Array).is_empty()
	f["look.ayuda"] = day == 1 and not pro
	return f

static func _months(clips: Dictionary) -> int:
	var seen := {}
	for id in clips:
		var c = clips[id]
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var d := String(c.get("chron_date", ""))
		if d.length() >= 7:
			seen[d.substr(0, 7)] = true
		if seen.size() >= 2:
			break
	return seen.size()

static func _assertions_any(st, repo) -> bool:
	for x in repo.lists().get("assertions", []):
		if typeof(x) != TYPE_DICTIONARY:
			continue
		var ok := true
		for r in x.get("requires", []):
			if not Index.has(st, String(r)):
				ok = false
				break
		if ok:
			return true
	return false

static func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b
