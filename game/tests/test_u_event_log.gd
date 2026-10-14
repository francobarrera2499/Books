# Unit: core/save/event_log.gd (W1-ENG). §5.5: JSONL canónico, atómico con .bak, última línea truncada, bytes idénticos.
extends "res://tests/test_base.gd"

const EventLog = preload("res://core/save/event_log.gd")
const J = preload("res://core/util/j.gd")

const ACTIONS := [
	{"t": "clip_text", "src": {"kind": "doc", "ref": "D05@BM", "part": "p1", "block": 0}, "from": 12.0, "len": 30},
	{"t": "go", "place": "L2", "area": "sala", "seat": 214.0},
	{"t": "link", "a": "RC0001", "b": "RC0002", "note": "«contradice»"},
	{"t": "sleep"},
]

func _hdr() -> Dictionary:
	return EventLog.make_header(1234, "abc123")

func _bytes(p: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(p)

func test_header_shape():
	var h := _hdr()
	eq(h, {"v": 3, "seed": 1234, "content": "abc123", "engine": "4.7.2"})

func test_write_read_roundtrip():
	var p := tmp_dir().path_join("partida.jsonl")
	var log := EventLog.new(p)
	ok(log.write(_hdr(), ACTIONS))
	var r := EventLog.read(p)
	ok(r.ok, str(r))
	eq(r.err, "")
	eq(r.header, _hdr())
	eq(r.actions.size(), 4)
	eq(typeof(r.actions[1].seat), TYPE_INT, "enteros vuelven como int")
	eq(r.actions[1].seat, 214)
	eq(r.actions[2].note, "«contradice»")
	eq(r.dropped, 0)
	eq(r.recovered, "")

func test_canonical_lines():
	var txt := EventLog.to_text(_hdr(), ACTIONS)
	var lines := txt.split("\n")
	eq(lines[0], "{\"content\":\"abc123\",\"engine\":\"4.7.2\",\"seed\":1234,\"v\":3}")
	eq(lines[2], "{\"area\":\"sala\",\"place\":\"L2\",\"seat\":214,\"t\":\"go\"}", "claves ordenadas, int sin .0")
	ok(txt.ends_with("\n"))
	eq(lines.size(), 6, "cabecera + 4 + vacío final")

func test_bytes_identical_write_read_write():
	var d := tmp_dir()
	var p1 := d.path_join("a.jsonl")
	var p2 := d.path_join("b.jsonl")
	EventLog.new(p1).write(_hdr(), ACTIONS)
	var r := EventLog.read(p1)
	EventLog.new(p2).write(r.header, r.actions)
	eq(_bytes(p1), _bytes(p2), "guardar -> cargar -> guardar = mismos bytes (T9)")

func test_atomic_bak():
	var p := tmp_dir().path_join("s/partida.jsonl")
	var log := EventLog.new(p)
	ok(log.write(_hdr(), ACTIONS.slice(0, 1)))
	ok(log.write(_hdr(), ACTIONS.slice(0, 2)))
	eq(EventLog.read(p).actions.size(), 2)
	eq(EventLog.read(p + ".bak").actions.size(), 1, ".bak = versión anterior")
	no(FileAccess.file_exists(p + ".tmp"))

func test_truncated_last_line_dropped():
	var p := tmp_dir().path_join("t.jsonl")
	EventLog.new(p).write(_hdr(), ACTIONS)
	var f := FileAccess.open(p, FileAccess.READ_WRITE)
	f.seek_end()
	f.store_string("{\"t\":\"pass_clean\",\"entr")
	f.close()
	var r := EventLog.read(p)
	ok(r.ok)
	eq(r.actions.size(), 4)
	eq(r.dropped, 1)

func test_corrupt_middle_line_fails():
	var p := tmp_dir().path_join("c.jsonl")
	var txt := EventLog.to_text(_hdr(), ACTIONS).replace("\"t\":\"go\"", "\"t\":go")
	J.write_atomic(p, txt)
	var r := EventLog.read(p)
	no(r.ok)
	eq(r.err, "linea_3")

func test_bad_header_and_empty():
	var d := tmp_dir()
	J.write_atomic(d.path_join("h.jsonl"), "{\"x\":1}\n")
	eq(EventLog.read(d.path_join("h.jsonl")).err, "cabecera")
	J.write_atomic(d.path_join("e.jsonl"), "\n\n")
	eq(EventLog.read(d.path_join("e.jsonl")).err, "vacio")
	eq(EventLog.read(d.path_join("nada.jsonl")).err, "no_existe")

func test_recover_from_bak_and_tmp():
	var d := tmp_dir()
	var p := d.path_join("r.jsonl")
	var log := EventLog.new(p)
	log.write(_hdr(), ACTIONS.slice(0, 1))
	log.write(_hdr(), ACTIONS.slice(0, 3))
	# corte entre "path -> .bak" y ".tmp -> path": no hay path, hay .bak (y quizá .tmp)
	DirAccess.remove_absolute(p)
	var r := EventLog.read(p)
	ok(r.ok)
	eq(r.recovered, "bak")
	eq(r.actions.size(), 1)
	J.write_atomic(d.path_join("x.jsonl"), "tmp")
	DirAccess.rename_absolute(d.path_join("x.jsonl"), p + ".tmp")
	J.write_atomic(d.path_join("y.jsonl"), EventLog.to_text(_hdr(), ACTIONS))
	DirAccess.rename_absolute(d.path_join("y.jsonl"), p + ".tmp")
	var r2 := EventLog.read(p)
	ok(r2.ok)
	eq(r2.recovered, "tmp", ".tmp completo es lo más nuevo")
	eq(r2.actions.size(), 4)

func test_user_path_works():
	# user:// cae en .work/appdata por godot.sh; se limpia al final.
	var p := "user://tests_w1eng/u.jsonl"
	ok(EventLog.new(p).write(_hdr(), ACTIONS))
	eq(EventLog.read(p).actions.size(), 4)
	var abs_dir := ProjectSettings.globalize_path("user://tests_w1eng")
	for f in DirAccess.get_files_at(abs_dir):
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)
