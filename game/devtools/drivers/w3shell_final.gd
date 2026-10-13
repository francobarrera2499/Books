# W3-SHELL: el final del calendario con capturas (pasivo, dataset fixture): día 10 confrontación en la tienda de Crane,
# informe final, Park Lane (lámina PARK), noche del jueves (elegir), epílogo (W4-EPILOGUE o respaldo propio).
# ./godot.sh -s devtools/shot.gd --resolution 1600x900 -- res://main.tscn w3shell_fin res://devtools/drivers/w3shell_final.gd
extends RefCounted

const Fallback = preload("res://ui/desk/fallback.gd")
const W = preload("res://tests/fixtures/w3shell/walk.gd")

var tool
var shell
var g

func act(a: Dictionary) -> Dictionary:
	return g.act(a)

func drive(p_tool, scene) -> void:
	tool = p_tool
	await tool.frames(4)
	shell = scene.get_node_or_null("Shell")
	g = scene.get_tree().root.get_node("Game")
	g.repo_override = Fallback.data_repo("fixture")
	g.save_path = "user://saves/w3shell_final.jsonl"
	shell.fast = true
	shell.new_game(1894)
	await _until(func(): return shell.game_screen != null and shell.game_screen.idle(), 900)
	W.tutorial(g.sim, act)
	act({"t": "sleep"})
	var shots := {"confront": "1_confrontacion", "final_report": "2_informe_final", "parklane": "3_park_lane", "night_choice": "4_noche_jueves"}
	for i in 400:
		await _until(func(): return shell.screen_id != "game" or shell.game_screen.idle(), 900)
		await tool.frames(4)
		if shell.screen_id != "game":
			break
		var ph := String(g.sim.q_clock().phase)
		if shots.has(ph):
			await tool.frames(30)
			await tool.snap(String(shots[ph]))
			shots.erase(ph)
		var a := {}
		match ph:
			"desk":
				a = {"t": "end_slot"}
			"visit", "scene", "parklane":
				a = {"t": "leave"}
			"night":
				a = {"t": "report_submit", "mode": "nada", "items": []} if bool(g.sim.q_report_status().due) else {"t": "sleep"}
			"confront":
				a = {"t": "confront", "step": int(g.sim.q_confront().get("step", 1)), "item": {}}
			"final_report":
				a = {"t": "report_submit", "mode": "nada", "items": []}
			"night_choice":
				a = {"t": "night_choice", "where": "casa"}
			_:
				break
		if not bool(act(a).get("ok", false)):
			print("[w3shell_fin] no avanza en ", ph)
			break
	await tool.frames(40)
	print("[w3shell_fin] pantalla ", shell.screen_id, " fase ", g.sim.q_clock().phase if g.sim != null else "")
	await tool.snap("5_epilogo")
	g.end_session()

func _until(f: Callable, max_frames: int) -> void:
	var i := 0
	while not f.call() and i < max_frames:
		await tool.frames(1)
		i += 1
