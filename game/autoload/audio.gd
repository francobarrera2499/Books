# Autoload Audio. Dueño: W1-AUDIO. Contrato: docs/ARCHITECTURE.md §2.2 y §8.
# Banco de AudioStreamWAV procedurales (audio/proc_audio.gd), deterministas (semilla por id). warm() genera TODO
# (en paralelo con WorkerThreadPool; el resultado es idéntico al de la generación en serie). Nada se genera en _ready:
# sin warm(), cada id se genera perezosamente al primer play()/stream(). Sin AudioStreamGenerator.
# Buses "Amb" y "Sfx" (en _ready; livianos); 2 reproductores de ambiente con fundido cruzado; pool de 8 para sueltos;
# los sueltos suenan por AudioStreamRandomizer (variantes y tono). Cada play emite subtitle(texto) si subtitles_on.
# Config: data/audio.json (captions, ambience, events), leído sin DataRepo (excepción documentada §2.1).
extends Node

signal subtitle(text: String, seconds: float)

const Bank = preload("res://audio/sound_bank.gd")
const Proc = preload("res://audio/proc_audio.gd")
const Synth = preload("res://audio/synth.gd")
const CONFIG_PATH := "res://data/audio.json"
const POOL_SIZE := 8
const AMB_BUS := "Amb"
const SFX_BUS := "Sfx"
const SILENT_DB := -80.0

var subtitles_on := true
var threaded := true            # warm() en paralelo (los tests comparan contra la serie)
var last_warm_ms := -1.0        # duración de la última warm() (diagnóstico, T28)

var _bank := {}                  # id -> AudioStreamWAV (variante 0)
var _vars := {}                  # id -> Array de AudioStreamWAV (todas las variantes)
var _rand := {}                  # id -> AudioStreamRandomizer
var _cfg = null                  # audio.json parseado (perezoso)
var _nodes_ready := false
var _pool: Array = []
var _pool_next := 0
var _amb: Array = []
var _amb_cur := 0
var _amb_id := ""
var _tweens := {}                # AudioStreamPlayer -> Tween

class _WarmJob:
	extends RefCounted
	const P = preload("res://audio/proc_audio.gd")
	var jobs: Array = []
	var out: Array = []
	var mutex := Mutex.new()
	func run(i: int) -> void:
		var j: Array = jobs[i]
		var b: PackedByteArray = P.pcm(String(j[0]), int(j[1]))
		mutex.lock()
		out[i] = b
		mutex.unlock()

# ---------------------------------------------------------------- generación
func warm() -> void:
	var t0 := Time.get_ticks_usec()
	var jobs: Array = []
	for id in Bank.ids():
		for v in Bank.variants(id):
			if not _has_variant(id, v): jobs.append([id, v, float(Bank.entry(id).get("dur", 1.0)) + float(Bank.entry(id).get("fade", 0.0))])
	jobs.sort_custom(func(a, b): return a[2] > b[2])   # los largos primero (reparto entre hilos)
	var out: Array = []
	out.resize(jobs.size())
	if threaded and jobs.size() > 1 and OS.get_processor_count() > 1:
		var w := _WarmJob.new()
		w.jobs = jobs
		w.out = out
		var gid := WorkerThreadPool.add_group_task(w.run, jobs.size(), -1, true, "Audio.warm")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	else:
		for i in jobs.size():
			out[i] = Proc.pcm(String(jobs[i][0]), int(jobs[i][1]))
	for i in jobs.size():
		_store(String(jobs[i][0]), int(jobs[i][1]), out[i])
	last_warm_ms = float(Time.get_ticks_usec() - t0) / 1000.0

func is_warm() -> bool:
	for id in Bank.ids():
		for v in Bank.variants(id):
			if not _has_variant(id, v): return false
	return true

func _has_variant(id: String, v: int) -> bool:
	return _vars.has(id) and v < _vars[id].size() and _vars[id][v] != null

func _store(id: String, v: int, bytes: PackedByteArray) -> void:
	if not _vars.has(id):
		var arr: Array = []
		arr.resize(Bank.variants(id))
		_vars[id] = arr
	_vars[id][v] = Proc.wav_from_pcm(id, bytes)
	if v == 0: _bank[id] = _vars[id][0]

func _ensure(id: String, all_variants := false) -> void:
	var nv: int = Bank.variants(id) if all_variants else 1
	for v in nv:
		if not _has_variant(id, v): _store(id, v, Proc.pcm(id, v))

func stream(id: String) -> AudioStream:
	var key := Bank.resolve(id)
	if not Bank.BANK.has(key): return null
	_ensure(key)
	return _bank.get(key, null)

func has_sound(id: String) -> bool:
	return Bank.has(id)

func ids() -> Array:
	return Bank.ids()

# AudioStreamRandomizer con todas las variantes (sueltos).
func _randomizer(key: String) -> AudioStream:
	if _rand.has(key): return _rand[key]
	_ensure(key, true)
	var r := AudioStreamRandomizer.new()
	var vs: Array = _vars[key]
	for w in vs: r.add_stream(-1, w, 1.0)
	r.random_pitch = float(Bank.entry(key).get("pitch", 1.0))
	r.random_volume_offset_db = 1.5 if r.random_pitch > 1.0 else 0.0
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if vs.size() > 1 else AudioStreamRandomizer.PLAYBACK_RANDOM
	_rand[key] = r
	return r

# ---------------------------------------------------------------- configuración (data/audio.json)
func _config() -> Dictionary:
	if _cfg == null:
		_cfg = {}
		if FileAccess.file_exists(CONFIG_PATH):
			var v = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
			if v is Dictionary: _cfg = v
			else: push_warning("Audio: data/audio.json inválido")
	return _cfg

func caption(id: String) -> String:
	return String(_config().get("captions", {}).get(Bank.resolve(id), ""))

func reload_config() -> void:
	_cfg = null

# {id, db} del ambiente para place ("L1" o "L1.tienda") y slot ("M", o "10.N" = franja de un día concreto).
# Busca primero el área y luego el lugar; dentro, slot exacto → franja sin día → "*". "" = silencio.
func ambience_for(place: String, slot: String) -> Dictionary:
	var amb: Dictionary = _config().get("ambience", {})
	var places := [place]
	if place.contains("."): places.append(place.get_slice(".", 0))
	var slots := [slot]
	if slot.contains("."): slots.append(slot.get_slice(".", 1))
	slots.append("*")
	for p in places:
		if not amb.has(p): continue
		var row: Dictionary = amb[p]
		for s in slots:
			if row.has(s):
				var v = row[s]
				if v is Dictionary: return {"id": String(v.get("id", "")), "db": float(v.get("db", 0.0))}
				return {"id": String(v), "db": 0.0}
	return {"id": "", "db": 0.0}

func event_ids(name: String) -> Array:
	return _config().get("events", {}).get(name, []).duplicate()

# ---------------------------------------------------------------- buses y nodos
# Los buses "Amb"/"Sfx" existen desde _ready (liviano: sin generar audio ni crear reproductores) para que Opciones
# pueda leer y fijar su volumen antes del primer sonido; el −3 dB inicial de Amb se pone sólo al crearlo (nunca pisa
# lo que haya fijado el jugador).
func _ready() -> void:
	_ensure_buses()

func _ensure_buses() -> void:
	for b in [AMB_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			if b == AMB_BUS: AudioServer.set_bus_volume_db(i, -3.0)

# Reproductores: perezosos (al primer play / play_amb), nunca en _ready.
func _ensure_nodes() -> void:
	if _nodes_ready: return
	_nodes_ready = true
	_ensure_buses()
	for k in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % k
		p.bus = SFX_BUS
		add_child(p)
		_pool.append(p)
	for k in 2:
		var p := AudioStreamPlayer.new()
		p.name = "Amb%d" % k
		p.bus = AMB_BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_amb.append(p)

func _pick_player() -> AudioStreamPlayer:
	for k in POOL_SIZE:
		var p: AudioStreamPlayer = _pool[(_pool_next + k) % POOL_SIZE]
		if not p.playing:
			_pool_next = (_pool_next + k + 1) % POOL_SIZE
			return p
	var q: AudioStreamPlayer = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % POOL_SIZE
	return q

func _emit_caption(key: String, seconds: float) -> void:
	if not subtitles_on: return
	var t := caption(key)
	if t != "": subtitle.emit(t, clampf(seconds, 2.0, 6.0))

# ---------------------------------------------------------------- reproducción
func play(id: String, volume_db := 0.0) -> void:
	var key := Bank.resolve(id)
	if not Bank.BANK.has(key):
		push_warning("Audio.play: id desconocido " + id)
		return
	if Bank.is_loop(key):
		_play_amb(key, 1.0, volume_db)
		return
	var s := _randomizer(key)
	_ensure_nodes()
	if is_inside_tree():
		var p := _pick_player()
		p.stop()
		p.stream = s
		p.volume_db = volume_db
		p.play()
	_emit_caption(key, _bank[key].get_length())

func play_amb(id: String, fade_s := 1.0) -> void:
	_play_amb(id, fade_s, 0.0)

func _play_amb(id: String, fade_s: float, db: float) -> void:
	var key := Bank.resolve(id)
	if not Bank.BANK.has(key):
		push_warning("Audio.play_amb: id desconocido " + id)
		return
	_ensure_nodes()
	var cur: AudioStreamPlayer = _amb[_amb_cur]
	if key == _amb_id and cur.playing:
		_fade(cur, db, fade_s, false)
		return
	var w := stream(key)
	_amb_cur = 1 - _amb_cur
	var nw: AudioStreamPlayer = _amb[_amb_cur]
	_kill_tween(nw)
	nw.stream = w
	nw.volume_db = SILENT_DB if fade_s > 0.0 else db
	if is_inside_tree(): nw.play()
	_fade(nw, db, fade_s, false)
	_fade(cur, SILENT_DB, fade_s, true)
	_amb_id = key
	_emit_caption(key, 4.0)

func stop_amb(fade_s := 1.0) -> void:
	if not _nodes_ready: return
	_fade(_amb[_amb_cur], SILENT_DB, fade_s, true)
	_amb_id = ""

func current_amb() -> String:
	return _amb_id

func set_place_ambience(place: String, slot: String) -> void:
	var e := ambience_for(place, slot)
	if String(e["id"]) == "" or not Bank.has(String(e["id"])): stop_amb(1.0)
	else: _play_amb(String(e["id"]), 1.0, float(e["db"]))

# Secuencia nombrada de data/audio.json (p. ej. "dawn"): cada sonido empieza al 75 % del anterior.
# Devuelve la duración total aproximada (s).
func play_event(name: String) -> float:
	var ids_list := event_ids(name)
	var starts: Array = []
	var t := 0.0
	var total := 0.0
	for id in ids_list:
		starts.append(t)
		var w := stream(String(id))
		var d: float = w.get_length() if w != null else 1.0
		total = maxf(total, t + d)
		t += d * 0.75
	if ids_list.is_empty(): return 0.0
	play(String(ids_list[0]))
	if ids_list.size() > 1 and is_inside_tree():
		var tw := create_tween()   # ligado al nodo: si el nodo se libera, la secuencia muere con él
		for k in range(1, ids_list.size()):
			tw.tween_interval(maxf(0.01, float(starts[k]) - float(starts[k - 1])))
			tw.tween_callback(play.bind(String(ids_list[k])))
	return total

# ---------------------------------------------------------------- fundidos
func _kill_tween(p: AudioStreamPlayer) -> void:
	if _tweens.has(p):
		var tw = _tweens[p]
		if tw != null and tw.is_valid(): tw.kill()
		_tweens.erase(p)

func _fade(p: AudioStreamPlayer, to_db: float, secs: float, stop_after: bool) -> void:
	_kill_tween(p)
	if secs <= 0.0 or not is_inside_tree():
		p.volume_db = to_db
		if stop_after: p.stop()
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: p.volume_db = linear_to_db(maxf(v, 1e-4)),
		db_to_linear(p.volume_db), db_to_linear(to_db), secs).set_trans(Tween.TRANS_SINE)
	if stop_after: tw.tween_callback(p.stop)
	_tweens[p] = tw
