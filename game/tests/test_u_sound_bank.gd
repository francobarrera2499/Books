# W4-AUDIO (ARCHITECTURE §8, §10 ola 4; GDD §7.1, §14.6, HC09): mezcla del banco (audio/sound_bank.gd), recetas de la
# ola 4 (audio/proc_audio.gd) y ambientes por lugar y franja (data/audio.json) sobre los datos reales.
# No se puede escuchar: se mide. Sonoridad ≈ LUFS mono (ponderación K, audio/analysis.gd): sueltos = ventana de 0,4 s
# más fuerte; bucles = integrada; nivel efectivo de un ambiente = bucle − 3 dB del bus Amb + db del lugar.
extends "res://tests/test_base.gd"

const Proc = preload("res://audio/proc_audio.gd")
const Bank = preload("res://audio/sound_bank.gd")
const Synth = preload("res://audio/synth.gd")
const An = preload("res://audio/analysis.gd")
const AudioScript = preload("res://autoload/audio.gd")
const TIMEOUT_S := 120.0
const AMB_BUS_DB := -3.0
const W4_LOOPS := ["amb.calle_parker", "amb.noche_parker", "amb.casa_vacia", "amb.noche"]
const EPI_UI := "ui_text/epilogue_ui.json"

# Mezcla: rango de sonoridad máxima (dB) de cada suelto. Todo suelto nuevo tiene que entrar aquí.
const MIX := {
	# foley del escritorio (lo hace el jugador con su clic: debajo de todo lo que pasa en el mundo)
	"sfx.papel": [-30.0, -25.0], "sfx.pagina": [-30.0, -25.0], "sfx.plumin": [-31.0, -26.0], "sfx.secante": [-31.0, -25.0],
	"sfx.sobre": [-30.0, -25.0], "sfx.tijera": [-26.0, -21.0], "sfx.sello": [-24.0, -19.0], "sfx.sello_seco": [-26.0, -21.0],
	# amanecer (GDD §7.1): St Clement Danes a un paso; el lechero y la persiana, abajo
	"bells.st_clement": [-19.0, -15.0], "evt.lechero": [-25.0, -20.0], "evt.persiana_crane": [-25.0, -20.0],
	# la noche del 5 (HC09): los cuartos y el arpa, lejos; el silbido, el vidrio y el silbato, cerca
	"clock.cuartos": [-24.0, -19.0], "harp.parker": [-25.0, -20.0], "shot.silbido": [-19.0, -15.0],
	"glass.tintineo": [-18.0, -14.0], "whistle.policia": [-19.0, -15.0], "evt.carrera": [-23.0, -19.0],
	"bells.horas": [-25.0, -20.0], "evt.cerrojo": [-30.0, -25.0],
	# calle y casa
	"hooves.madera": [-24.0, -20.0], "hooves.granito": [-24.0, -20.0], "evt.golpe_puerta": [-23.0, -19.0], "evt.ladrillo": [-25.0, -20.0],
	# v3 (GDD_v3 §4.3): la corriente de aire al entrar con la ventana abierta, sin alerta (playtest v3: −8 dB, ≈ −29)
	"evt.corriente": [-31.0, -26.0],
}
const FOLEY := ["sfx.papel", "sfx.pagina", "sfx.plumin", "sfx.secante", "sfx.sobre"]
const DAWN := ["bells.st_clement", "evt.lechero", "evt.persiana_crane"]
const NIGHT_NEAR := ["shot.silbido", "glass.tintineo", "whistle.policia"]
const NIGHT_FAR := ["clock.cuartos", "harp.parker"]

static var _inst = null
static var _xs := {}
static var _ls := {}

func _audio():
	if _inst == null:
		_inst = AudioScript.new()
		_inst.warm()
	return _inst

func _x(id: String) -> PackedFloat32Array:
	if not _xs.has(id):
		var w: AudioStreamWAV = _audio().stream(id)
		var f := Synth.wav_to_floats(w)
		if Bank.is_loop(id): f = f.slice(0, w.loop_end)
		_xs[id] = f
	return _xs[id]

func _loud(id: String) -> float:
	if not _ls.has(id):
		_ls[id] = An.loudness_int(_x(id)) if Bank.is_loop(id) else An.loudness_max(_x(id))
	return float(_ls[id])

# Nivel efectivo del ambiente de place/slot (dB); -INF si no hay.
func _amb_eff(place: String, slot: String) -> float:
	var e: Dictionary = _audio().ambience_for(place, slot)
	if String(e.id) == "": return -INF
	return _loud(Bank.resolve(String(e.id))) + AMB_BUS_DB + float(e.db)

func _amb_id(place: String, slot: String) -> String:
	return String(_audio().ambience_for(place, slot).id)

func _rms(x: PackedFloat32Array, t0: float, t1: float) -> float:
	var a := clampi(int(t0 * 44100), 0, x.size())
	var b := clampi(int(t1 * 44100), a, x.size())
	return Synth.rms(x.slice(a, b))

# Armónico de 98 Hz (5..13) más fuerte en [t0, t1]: la nota que elige la boca.
func _harm(x: PackedFloat32Array, t0: float, t1: float) -> int:
	var a := int(t0 * 44100)
	var n := int((t1 - t0) * 44100)
	var best := 0
	var bv := -1.0
	for h in range(5, 14):
		var v := An.goertzel(x, float(h) * Proc.PARKER_F0, a, n)
		if v > bv:
			bv = v
			best = h
	return best

# ---------------------------------------------------------------- mezcla
func test_mix_levels_in_range() -> void:
	for id in Bank.ids():
		if Bank.is_loop(id): continue
		ok(MIX.has(id), "%s sin lugar en la mezcla (MIX)" % id)
		if not MIX.has(id): continue
		var l := _loud(id)
		ok(l >= float(MIX[id][0]) and l <= float(MIX[id][1]), "%s sonoridad %.1f dB fuera de [%.0f, %.0f]" % [id, l, MIX[id][0], MIX[id][1]])
	# el nivel se fija con level (pico normalizado); gain queda neutro y el pico no toca el limitador
	for id in Bank.ids():
		eq(float(Bank.entry(id).get("gain", 1.0)), 1.0, id + " gain neutro")
		if not Bank.is_loop(id): ok(float(Bank.entry(id).get("level", 0.6)) <= 0.85, id + " level ≤ 0,85 (rodilla del limitador)")

func test_mix_hierarchy_and_masking() -> void:
	var foley_max := -INF
	for id in FOLEY: foley_max = maxf(foley_max, _loud(id))
	for id in DAWN + NIGHT_NEAR + NIGHT_FAR + ["evt.carrera", "sfx.sello"]:
		ok(_loud(id) > foley_max + 2.0, "%s (%.1f) por encima del foley del clic (%.1f)" % [id, _loud(id), foley_max])
	for id in NIGHT_NEAR + NIGHT_FAR + ["evt.carrera"]:
		ok(_loud("glass.tintineo") >= _loud(id) - 0.01, "el vidrio es lo más fuerte de la noche (vs %s)" % id)
	for f in NIGHT_FAR:
		for c in NIGHT_NEAR:
			ok(_loud(c) - _loud(f) >= 3.0, "%s (lejos) al menos 3 dB debajo de %s" % [f, c])
	# la noche del 5 en Baker Street: el viento no tapa nada
	var wind := _amb_eff("L3", "10.night")
	for id in NIGHT_NEAR: ok(_loud(id) - wind >= 12.0, "%s %.1f dB sobre el viento" % [id, _loud(id) - wind])
	for id in NIGHT_FAR + ["evt.carrera"]: ok(_loud(id) - wind >= 7.0, "%s %.1f dB sobre el viento" % [id, _loud(id) - wind])
	# en casa esa noche: la hora y el cerrojo sobre el viento tras la ventana
	var wind_home := _amb_eff("L1", "10.night")
	for id in ["bells.horas", "evt.cerrojo"]: ok(_loud(id) - wind_home >= 6.0, "%s sobre el viento de la buhardilla" % id)
	# el amanecer sobre la calle temprana; el foley sobre la calle de día
	var dawn := _amb_eff("L1", "dawn")
	ok(_loud("bells.st_clement") - dawn >= 20.0, "campanas 20 dB sobre la calle del amanecer")
	for id in ["evt.lechero", "evt.persiana_crane"]: ok(_loud(id) - dawn >= 15.0, id + " sobre la calle del amanecer")
	for id in FOLEY: ok(_loud(id) - _amb_eff("L1", "1.M") >= 8.0, id + " 8 dB sobre la calle de la mañana")

func test_ambience_levels_and_order() -> void:
	var cfg: Dictionary = _audio()._config()
	for p in cfg.get("ambience", {}):
		for s in cfg["ambience"][p]:
			var e := _amb_eff(String(p), String(s))
			ok(e > -53.0 and e < -28.0, "ambiente %s/%s a nivel de fondo (%.1f dB)" % [p, s, e])
	ok(_amb_eff("L1", "1.dawn") < _amb_eff("L1", "1.M") - 2.0, "el amanecer, más quieto que la mañana")
	ok(_amb_eff("L1", "6.T") < _amb_eff("L1", "5.T") - 4.0, "el domingo, Holywell Street callada")
	ok(_amb_eff("L1", "6.dawn") <= _amb_eff("L1", "6.T"), "el amanecer del domingo, no más ruidoso que su tarde")
	ok(_amb_eff("L1", "6.dawn") < _amb_eff("L1", "5.dawn") - 2.0, "el amanecer del domingo, más quieto que el del sábado")
	ok(_amb_eff("L3", "6.T") < _amb_eff("L3", "5.T") - 2.0, "el domingo, Baker Street callada")
	ok(_amb_eff("L3", "5.N") < _amb_eff("L3", "5.M") - 3.0, "Baker Street de noche, más rala")
	ok(_amb_eff("L3", "10.night") > _amb_eff("L3", "9.night") + 6.0, "la noche del 5: viento")
	ok(_amb_eff("L5", "8.T") <= _amb_eff("L2", "1.M") - 3.0, "el Diógenes, lo más callado")
	ok(_amb_eff("L5.forasteros", "8.T") <= _amb_eff("L5.porteria", "8.T"), "la Sala de Forasteros no más ruidosa que la portería")

# ---------------------------------------------------------------- ambientes por lugar y franja (datos reales)
func test_every_place_area_slot_has_ambience() -> void:
	var r = repo()
	var days: Array = []
	for d in r.schedule().get("days", []):
		if not (d.get("slots", []) as Array).is_empty(): days.append(d)
	ok(days.size() >= 10, "calendario con franjas")
	var n := 0
	for pid in r.places():
		var pl: Dictionary = r.place(pid)
		var keys := [String(pid)]
		for a in pl.get("areas", {}): keys.append("%s.%s" % [pid, a])
		var slots: Array = ["M", "T", "N"]
		if String(pid) == "L1": slots = ["dawn", "M", "T", "N", "night"]
		for k in keys:
			for d in days:
				for s in slots:
					var id := _amb_id(k, "%d.%s" % [int(d.day), s])
					ok(id != "" and Bank.has(id), "ambiente para %s el día %d (%s): '%s'" % [k, int(d.day), s, id])
					n += 1
	ok(n > 300, "combinaciones revisadas (%d)" % n)
	# láminas fijas de un lugar (prólogo, M7, Park Lane) por su origen; las de documento (RB) no tienen ambiente
	for plid in r.plates():
		var pd: Dictionary = r.plate(plid)
		if pd.get("place", null) == null or String(pd.get("origin", "")) == "": continue
		for s in pd.get("light", {"*": ""}):
			var id := _amb_id(String(pd.origin), String(s))
			ok(id != "" and Bank.has(id), "ambiente para la lámina %s (%s)" % [plid, s])
	# confrontación del día 10 (GameScreen: L1.tienda) y la noche del epílogo (HC09: L3 o L1, 10.night)
	eq(_amb_id("L1.tienda", "10.M"), "amb.tienda", "confrontación en la tienda")
	eq(_amb_id("L3", "10.night"), "amb.viento", "HC09 en Baker Street")
	eq(_amb_id("L1", "10.night"), "amb.viento", "HC09 en casa")

func test_ambience_follows_the_world() -> void:
	var r = repo()
	# Parker toca en Baker Street exactamente cuando está (nodo parker, when.slot), salvo la noche del 5 (HC09)
	var pk := {}
	for nd in r.place("L3").get("nodes", []):
		if String(nd.get("id", "")) == "parker": pk = nd
	ok(not pk.is_empty(), "L3 tiene el nodo parker")
	var when: Array = pk.get("when", {}).get("slot", [])
	ok(not when.is_empty(), "parker tiene franjas")
	for day in range(1, 10):
		for s in ["M", "T", "N", "night"]:
			var id := _amb_id("L3", "%d.%s" % [day, s])
			eq(id.contains("parker"), when.has(s), "L3 %d.%s: se oye el arpa ⇔ Parker está (%s)" % [day, s, id])
	no(_amb_id("L3", "10.night").contains("parker"), "la noche del 5 el arpa no es ambiente: suena en HC09 y se calla")
	# toda lámina o lugar que dice que se oye el arpa de boca la hace sonar
	for plid in r.plates():
		var pd: Dictionary = r.plate(plid)
		if String(pd.get("origin", "")) == "": continue
		var says := false
		for nd in pd.get("nodes", []):
			if (nd.get("tags", []) as Array).has("e:arpa_de_boca") and String(nd.get("examine", "")).contains("se oye"): says = true
		if says:
			ok(_amb_id(String(pd.origin), "N").contains("parker"), "la lámina %s dice que se oye el arpa: suena" % plid)
	# cada área con su sonido: el vestíbulo de Mrs. Hudson no es la calle; la casa vacía, vacía
	eq(_amb_id("L3.interior", "3.M"), "amb.vestibulo", "vestíbulo del 221B: su propio sonido (playtest v3), no la tienda")
	eq(_amb_id("L4", "3.M"), "amb.consultorio", "consultorio de Watson: su propio sonido (playtest v3), no la tienda")
	ne(_audio().caption("amb.vestibulo"), _audio().caption("amb.tienda"), "subtítulos distintos")
	ne(_audio().caption("amb.consultorio"), _audio().caption("amb.tienda"), "subtítulos distintos")
	eq(_amb_id("L3.calle", "3.M"), "amb.calle", "Baker Street de día")
	eq(_amb_id("L8.interior", "8.T"), "amb.casa_vacia", "Camden House")
	eq(_amb_id("PL.prologo", "0.N"), "amb.noche_parker", "prólogo: la noche y, abajo, Parker de vez en cuando (v3: sin gas)")
	eq(_amb_id("L1", "4.N"), "amb.noche", "la buhardilla de noche: casi silencio (v3: sin gas)")
	eq(_amb_id("L7", "10.T"), "amb.parque", "Park Lane a las 18 h")

func test_dawn_and_night_cues_exist() -> void:
	var a = _audio()
	eq(a.event_ids("dawn"), ["bells.st_clement", "evt.lechero", "evt.persiana_crane"], "amanecer: campanas, lechero, persiana")
	eq(a.event_ids("dawn_domingo"), ["bells.st_clement", "evt.lechero"], "domingo: Crane no abre")
	# la noche final (HC09) según epilogue_ui.json (_sonido): todo id existe, se subtitula y no es foley mudo
	var f = repo().files().get(EPI_UI, {})
	var snd: Dictionary = f.get("_sonido", {}) if typeof(f) == TYPE_DICTIONARY else {}
	ok(not snd.is_empty(), "epilogue_ui.json tiene _sonido")
	var used := []
	for k in snd:
		var v = snd[k]
		for id in (v if typeof(v) == TYPE_ARRAY else [v]):
			ok(Bank.has(String(id)), "%s → %s existe" % [k, id])
			ok(a.caption(String(id)) != "" and not a.quiet(String(id)), "%s se subtitula" % id)
			used.append(String(id))
	for id in ["clock.cuartos", "harp.parker", "shot.silbido", "glass.tintineo", "whistle.policia"]:
		has(used, id, "HC09 en Baker Street:")
	for id in a.event_ids("noche_final") + a.event_ids("noche_casa"):
		ok(Bank.has(String(id)) and a.caption(String(id)) != "", "evento de la noche %s" % id)

# ---------------------------------------------------------------- recetas
func test_harp_plays_the_tune_and_falls_silent_mid_bar() -> void:
	var x := _x("harp.parker")
	var t0 := 0.05
	var nc: int = Proc.PARKER_CUT_NOTES
	ok(int(Proc.PARKER_TUNE[nc][0]) % 6 != 0, "se calla a mitad de un compás de 6/8")
	eq(int(Proc.PARKER_TUNE[nc][1]), 11, "se calla justo antes de la nota falsa")
	var cut := t0 + Proc.parker_note_time(nc - 1) + 0.09
	var playing := _rms(x, 0.1, cut - 0.1)
	var after := _rms(x, cut + 0.3, float(x.size()) / 44100.0 - 0.05)
	var soon := _rms(x, cut + 0.1, cut + 0.2)
	ok(linear_to_db(after / playing) <= -30.0, "después se oye el silencio (%.1f dB)" % linear_to_db(after / playing))
	ok(linear_to_db(soon / playing) <= -15.0, "se calla en seco (%.1f dB a los 0,1 s)" % linear_to_db(soon / playing))
	# cada pellizco donde la tonada lo pone, con la boca en su armónico
	var lo := x.duplicate()
	Synth.lp(lo, 300.0)   # el bordón sigue a la lengüeta: ahí se ve cada pellizco
	var hits := 0
	for k in nc:
		var t := t0 + Proc.parker_note_time(k)
		var pre := _rms(lo, t - 0.06, t - 0.03)
		var at := _rms(lo, t - 0.02, t + 0.04)
		ok(at > pre * 1.3, "pellizco %d en %.2f s" % [k, t])
		var len_s := float(Proc.PARKER_TUNE[k][2]) * Proc.PARKER_EIGHTH
		if _harm(x, t + 0.05, t + minf(0.17, len_s - 0.02)) == int(Proc.PARKER_TUNE[k][1]): hits += 1
	ok(hits >= nc - 2, "la boca canta la tonada (%d/%d notas)" % [hits, nc])
	# 98 Hz (la lengüeta) y el formante de la boca 400–1600 Hz (las firmas de T28)
	var ac := An.autocorr_peak(x.slice(int(0.1 * 44100), int(0.5 * 44100)), 380, 520)
	near(44100.0 / float(ac["lag"]), 98.0, 3.0, "arpa a 98 Hz")

func test_parker_tune_is_always_the_same() -> void:
	# Baker Street de noche (desde 0,4 s) y el prólogo (desde 10,5 s, tras la ventana): la misma tonada, con la nota falsa
	for c in [["amb.calle_parker", 0.4], ["amb.noche_parker", 10.5]]:
		var x := _x(String(c[0]))
		var hits := 0
		var nt: int = Proc.PARKER_TUNE.size()
		for k in nt:
			var t: float = float(c[1]) + Proc.parker_note_time(k)
			var len_s := float(Proc.PARKER_TUNE[k][2]) * Proc.PARKER_EIGHTH
			if _harm(x, t + 0.05, t + minf(0.17, len_s - 0.02)) == int(Proc.PARKER_TUNE[k][1]): hits += 1
		ok(hits >= nt - 3, "%s: la tonada de Parker (%d/%d notas)" % [c[0], hits, nt])
		# la nota falsa (armónico 11) donde va un la (9)
		var kf := -1
		for k in nt:
			if int(Proc.PARKER_TUNE[k][1]) == 11: kf = k
		ok(kf >= 0, "la tonada tiene su nota falsa")
		var tf: float = float(c[1]) + Proc.parker_note_time(maxi(kf, 0))
		var a := int((tf + 0.05) * 44100)
		ok(An.goertzel(x, 11.0 * Proc.PARKER_F0, a, 4410) > 2.0 * An.goertzel(x, 9.0 * Proc.PARKER_F0, a, 4410), "%s: siempre mal" % c[0])
		# Parker toca y descansa: el arpa se destaca en su banda sobre la pausa
		var sp_on := An.avg_spectrum(x, 2048, float(c[1]) + 0.2, float(c[1]) + 4.6)
		var sp_off := An.avg_spectrum(x, 2048, float(c[1]) + 5.4, float(c[1]) + 6.8)
		var on_e := An.band_ratio(sp_on, 2048, 550.0, 1250.0) * Synth.rms(x.slice(int((float(c[1]) + 0.2) * 44100), int((float(c[1]) + 4.6) * 44100)))
		var off_e := An.band_ratio(sp_off, 2048, 550.0, 1250.0) * Synth.rms(x.slice(int((float(c[1]) + 5.4) * 44100), int((float(c[1]) + 6.8) * 44100)))
		ok(on_e > 3.0 * off_e, "%s: el arpa se oye sobre el fondo" % c[0])

func test_glass_long_silvery_tinkle() -> void:
	var g := _x("glass.tintineo")
	ok(float(g.size()) / 44100.0 >= 2.8, "largo (≥ 2,8 s)")
	var e := An.env_rms(g, 0.05)
	var mx := 0.0
	for v in e: mx = maxf(mx, v)
	ok(e[int(2.0 / 0.05)] > mx * db_to_linear(-42.0), "todavía tintinea a los 2 s")
	ok(_rms(g, 1.0, 1.6) > 1.5 * _rms(g, 0.5, 0.95), "los trozos llegan a la vereda después de caer (al segundo)")
	ok(An.band_ratio(An.avg_spectrum(g, 2048, 0.05, 2.4), 2048, 2800.0, 9500.0) > 0.5, "plata: parciales 3–9 kHz")

func test_bells_and_hour() -> void:
	var b := _x("bells.st_clement")
	for p in Proc.RING:
		ok(An.goertzel(b, float(p) * 2.0, 0, 88200 * 2) > 8.0 * An.goertzel(b, float(p) * 2.07, 0, 88200 * 2), "nominal de la campana %.0f Hz" % p)
	eq(Proc.RING.size(), 6, "seis campanas")
	var h := _x("bells.horas")
	var hh := h.duplicate()
	Synth.hp(hh, 1500.0)   # el golpe del badajo y los parciales altos marcan cada campanada
	var on := An.onsets(hh, 0.01, 6.0, 1.0)
	# HC09 en casa: «Dan las once en St Clement Danes»; quien cuente los golpes tiene que contar once
	eq(Proc.HOUR_STROKES, 11, "la campana da las once")
	eq(on.size(), 11, "la hora: once golpes que se cuentan")
	if on.size() == 11:
		for k in 10: near(float(on[k + 1]) - float(on[k]), Proc.HOUR_GAP, 0.08, "golpes lentos")
		var last := float(on[10])
		ok(last + 1.5 < float(h.size()) / 44100.0, "la última tiene donde sonar")
		var he := An.env_rms(h, 0.1)
		var hm := 0.0
		for v in he: hm = maxf(hm, v)
		ok(he[int((last + 1.5) / 0.1)] > hm * db_to_linear(-30.0), "la última queda sonando")
		# ninguna campanada se pierde en el viento: cada golpe dentro de 6 dB del más fuerte
		var pk: Array = []
		for t in on: pk.append(_rms(h, float(t), float(t) + 0.3))
		var pmax := 0.0
		for v in pk: pmax = maxf(pmax, float(v))
		for k in pk.size(): ok(float(pk[k]) > pmax * db_to_linear(-6.0), "golpe %d audible (%.1f dB)" % [k + 1, linear_to_db(float(pk[k]) / pmax)])
	ok(_centroid(h) < 1200.0, "campana grande (grave)")

func _centroid(x: PackedFloat32Array) -> float:
	return An.centroid(An.avg_spectrum(x, 2048), 2048)

func test_bolts_and_running_feet() -> void:
	var c := _x("evt.cerrojo")
	eq(An.onsets(c, 0.005, 10.0, 0.5).size(), 2, "dos cerrojos")
	ok(_centroid(c) < 2500.0, "a través del piso (apagado)")
	var r := _x("evt.carrera")
	ok(An.onsets(r, 0.005, 8.0, 0.08).size() >= 10, "pasos de carrera")
	ok(_rms(r, 1.2, 2.0) > db_to_linear(6.0) * _rms(r, 0.0, 0.8), "se acercan")

func test_w4_loops_seamless_and_quiet() -> void:
	for id in W4_LOOPS:
		ok(Bank.is_loop(id), id + " es bucle")
		var w: AudioStreamWAV = _audio().stream(id)
		var x := _x(id)
		var le: int = w.loop_end
		var jump := absf(x[le - 1] - x[0])
		ok(jump < 0.02, "%s salto en el bucle %.4f" % [id, jump])
		var s := 0.0
		for i in range(le - 2000, le - 1): s += (x[i + 1] - x[i]) * (x[i + 1] - x[i])
		var step := sqrt(s / 1999.0)
		ok(jump <= 4.0 * step + 0.0005, "%s salto %.5f vs paso típico %.5f (como T28)" % [id, jump, step])
		for g in Synth.LOOP_GUARD: eq(w.data.decode_s16((le + g) * 2), w.data.decode_s16(g * 2), id + " guarda = cabeza")
		var rr := linear_to_db(Synth.rms(x))
		ok(rr > -52.0 and rr < -20.0, "%s a nivel de fondo (%.1f dBFS)" % [id, rr])
		var m := 0.0
		for v in x: m += v
		ok(absf(m / float(x.size())) < 0.005, id + " sin continua")
		ok(_audio().caption(id) != "", id + " con subtítulo")

func test_zz_cleanup() -> void:
	if _inst != null:
		_inst.free()
		_inst = null
	_xs.clear()
	_ls.clear()
	ok(true)
