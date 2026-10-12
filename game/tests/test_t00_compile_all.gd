# T00 (W1-ENG): todo .gd de res:// (salvo tests/fixtures y .godot) carga y compila (can_instantiate).
# Un archivo ajeno a medio hacer falla acá: el mensaje nombra el archivo (no es falla del dueño de T00).
extends "res://tests/test_base.gd"

const Lint = preload("res://devtools/lint.gd")

func test_all_scripts_compile():
	var files: Array = Lint.gd_files("res://", ["res://.godot", "res://tests/fixtures"])
	ok(files.size() > 40, "se esperan muchos scripts, hay %d" % files.size())
	var bad: Array = []
	for p in files:
		var s = load(p)
		if s == null or not (s is Script) or not s.can_instantiate():
			bad.append(p)
	for b in bad:
		fail("no compila: " + b)
		# el motor ya registró el error de parseo; se excusa para informar una línea clara por archivo
		expect_error(b.get_file())

func test_core_stubs_present():
	# §3.8: todo módulo de core/ existe con sus funciones (stub de W1-ENG o la versión del dueño).
	var mods := {
		"res://core/util/j.gd": ["parse_file", "parse_str", "stringify_canon", "write_atomic"],
		"res://core/util/det.gd": ["h32", "rand01", "pick", "shuffle"],
		"res://core/util/log.gd": ["d", "i", "w", "e", "bug"],
		"res://core/util/cond.gd": ["eval"],
		"res://core/util/timekey.gd": ["tk", "parse", "label", "idx", "idx_count", "from_idx"],
		"res://core/data/data_repo.gd": ["load_dir", "errors", "doc", "docs", "copy", "parsed", "entity", "entities", "lists", "template", "conclusion", "conclusions", "reaction", "reactions", "schedule", "place", "places", "plate", "dialogue", "scene", "canon", "endings", "eggs", "catalog", "text", "content_hash"],
		"res://core/data/schema.gd": ["check"],
		"res://core/text/markup.gd": ["fill", "parse", "lint"],
		"res://core/text/clip_rules.gd": ["snap", "inherit", "max_legal_clips"],
		"res://core/save/event_log.gd": ["write", "read"],
		"res://core/sim/game_sim.gd": ["apply", "can", "actions_log", "canon", "state_hash", "replay", "clip_text", "clip_plate", "clip_measure", "link", "folio_open", "entry_new", "entry_set", "entry_support_add", "pass_clean", "go", "slip", "ask", "assert_claim", "present", "leave", "end_slot", "sleep", "compose_ad", "report_submit", "confront", "q_clock", "q_view", "q_plate"],
		"res://core/sim/game_state.gd": ["canon", "next_id", "note", "push_event"],
		"res://core/sim/actions.gd": ["normalize", "shape_error", "is_commit"],
		"res://core/sim/player_actions.gd": ["dispatch", "act_folio_open"],
		"res://core/sim/clock.gd": ["init_state", "place_open", "passes_left", "crossed_tks", "act_go", "act_leave", "act_end_slot", "act_sleep", "act_night_choice", "act_publish_errata"],
		"res://core/sim/world_model.gd": ["init_state", "accessible", "view_accessible", "view", "start_visit", "snapshot", "instantiate_doc", "deliver", "act_slip", "act_order_copy"],
		"res://core/sim/diary.gd": ["on_event", "on_arrival", "on_line"],
		"res://core/sim/tutorial.gd": ["init_state", "allowed", "after", "step", "verbs_taught"],
		"res://core/sim/endings.gd": ["evaluate", "blue_pencil"],
		"res://core/deduction/clipper.gd": ["init_state", "act_clip_text", "act_clip_plate", "act_clip_measure", "act_link", "act_unlink", "get_clip", "visible"],
		"res://core/deduction/index.gd": ["add_entities", "known", "has"],
		"res://core/deduction/ledger.gd": ["init_state", "create_folio", "act_entry_new", "act_entry_set", "act_entry_support_add", "act_entry_support_remove", "act_entry_delete", "formal_check", "entry_clips"],
		"res://core/deduction/validator.gd": ["values_match", "which_conclusion", "entry_ok", "lot_size", "entry_tags", "act_pass_clean", "act_practice"],
		"res://core/react/reaction_db.gd": ["compile", "candidates"],
		"res://core/react/sensors.gd": ["observe"],
		"res://core/react/latency.gd": ["due_tk", "voice_b_day"],
		"res://core/react/holmes_agent.gd": ["init_state", "observe"],
		"res://core/react/moran_agent.gd": ["init_state", "observe", "report_cats", "has_credit"],
		"res://core/react/director.gd": ["init_state", "on_public_event", "on_time", "immediate", "debug_queue"],
		"res://core/react/effects.gd": ["apply", "instance_text"],
		"res://core/graph/route_db.gd": ["routes", "frag"],
		"res://core/graph/availability.gd": ["open_mask", "frag_mask", "from_mask"],
		"res://core/graph/cut_model.gd": ["cuts_for", "apply_cuts"],
		"res://core/graph/invariant.gd": ["check", "runtime_guard", "t3"],
		"res://core/graph/feasibility.gd": ["plan"],
		"res://core/scenes/dialogue.gd": ["init_state", "respond", "preview", "topics", "act_ask", "act_assert", "act_present", "act_pay", "act_task"],
		"res://core/scenes/confrontation.gd": ["init_state", "start", "act_confront", "status"],
		"res://core/scenes/composers.gd": ["forms", "preview_ad", "act_compose_ad", "act_compose_telegram", "act_compose_letter", "act_report_submit"],
	}
	for p in mods:
		if not ResourceLoader.exists(p):
			fail("falta " + p)
			continue
		var s: Script = load(p)
		if s == null or not s.can_instantiate():
			continue  # lo informa test_all_scripts_compile
		var names := {}
		for m in s.get_script_method_list():
			names[String(m.name)] = true
		for fn in mods[p]:
			ok(names.has(fn), "%s: falta %s()" % [p.get_file(), fn])
