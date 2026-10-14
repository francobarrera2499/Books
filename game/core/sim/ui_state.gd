# core/sim/ui_state.gd — revelado progresivo de la interfaz (GDD_v2 §C.2; GDD_v3 §6.9). Dueño: CORE-EXPEDIENTE.
# v3: sin lg.*, nb.pares, hud.libro ni look.ayuda; desk.expediente (desde el paso read), hud.cintas (cintas «Cuaderno» y
#   «Expediente» sólo fuera de la buhardilla), exp.pasar / exp.pasar.<Q> (la hoja tiene respuesta y dos pruebas: aparece
#   «Pasar en limpio»), sc.donde (Crane ya se presentó: «¿Dónde consigo…?»).
# flags(st, repo) -> {bandera: bool}: fuente ÚNICA de qué controles existen ya. Sólo del estado de la partida
# (determinista, persiste al cargar, se prueba sin pantalla). Las vistas lo consumen y no deciden por su cuenta.
# Reglas (§C.1): nada visible que todavía no se pueda usar; lo que apareció no vuelve a desaparecer (salvo paneles
# contextuales: sc.*, cat.mesa, cmp.forma.*, cmp.quemar/trampa); NUNCA mira etiquetas ocultas ni conclusiones
# selladas (el revelado no depende de lo importante); sin contadores.
extends RefCounted

const Tutorial = preload("res://core/sim/tutorial.gd")
const Dialogue = preload("res://core/scenes/dialogue.gd")
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
	var dos := _ded(st, "dossier")
	var f := {}
	# ---- escritorio y HUD ----
	f["desk.tijera"] = not pro or tstep >= Tutorial.step_index_of("clip_text")
	f["desk.tintero"] = not pro or tstep >= Tutorial.step_index_of("compose_ad")
	f["desk.calendario"] = not pro or tstep >= Tutorial.step_index_of("sleep") or tut_done
	f["desk.mapa"] = not pro
	f["desk.expediente"] = true
	f["desk.bandeja"] = day >= 1
	f["desk.pendientes"] = day >= 1 and not pro
	f["hud.cuaderno"] = clips.size() >= 1
	f["hud.cintas"] = not _in_attic(st)
	# ---- cuaderno ----
	f["nb.diario"] = day >= 1 and not (st.world.get("diary", []) as Array).is_empty()
	f["nb.indice"] = _ded(st, "index").size() >= INDICE_MIN
	f["nb.curiosidades"] = _n(st.world.get("eggs", {})) >= 1
	f["nb.buscar"] = clips.size() >= BUSCAR_MIN
	f["nb.filtros"] = clips.size() >= FILTROS_MIN
	f["nb.agrupar"] = _months(clips) >= 2
	# ---- expediente ----
	var any_full := false
	var drafts = dos.get("drafts", {})
	var openq = dos.get("open", {})
	if typeof(openq) == TYPE_DICTIONARY:
		for qid in openq:
			var dr = drafts.get(qid, {}) if typeof(drafts) == TYPE_DICTIONARY else {}
			var full := false
			if typeof(dr) == TYPE_DICTIONARY and String(dr.get("answer", "")) != "":
				var pr: Array = dr.get("proofs", [])
				full = pr.size() == 2 and String(pr[0]) != "" and String(pr[1]) != ""
			f["exp.pasar." + String(qid)] = full
			any_full = any_full or full
	f["exp.pasar"] = any_full
	# ---- escena ----
	f["sc.mostrar"] = clips.size() >= 1 or _n(dos.get("open", {})) + _n(dos.get("inked", {})) >= 1
	f["sc.donde"] = Dialogue.crane_presented(st)
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
	return f

# ¿Lisle está en la buhardilla? (sin visita, o una escena en L1 fuera de la tienda: prólogo, M6, M7)
static func _in_attic(st) -> bool:
	var v = st.world.get("visit", {})
	if typeof(v) != TYPE_DICTIONARY or v.is_empty():
		return true
	return String(v.get("place", "")) == "L1" and ["", "buhardilla"].has(String(v.get("area", "")))

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
