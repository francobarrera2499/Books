# devtools/drivers/v3exp_check.gd — UI-EXPEDIENTE: compila (headless) los scripts del paquete antes de una corrida con
# ventana (un driver que no compila deja a shot.gd colgado con la ventana abierta).
#   ./godot.sh --headless -s devtools/drivers/v3exp_check.gd
extends SceneTree

const FILES := ["res://ui/expediente/expediente.gd", "res://ui/expediente/expediente_model.gd", "res://ui/expediente/answer_picker.gd",
	"res://ui/notebook/notebook.gd", "res://ui/notebook/clip_card.gd", "res://ui/notebook/tab_clips.gd", "res://ui/epilogue/blue_pencil.gd",
	"res://devtools/drivers/v3exp_fake.gd", "res://devtools/drivers/v3exp_flujo.gd", "res://devtools/drivers/v3exp_vista.gd",
	"res://devtools/drivers/v3exp_dia1.gd"]

func _init() -> void:
	var bad := 0
	for f in FILES:
		var s = load(f)
		var good: bool = s != null and s is Script and s.can_instantiate()
		print("V3EXP_CHECK %s %s" % ["OK" if good else "MAL", f])
		if not good:
			bad += 1
	print("V3EXP_CHECK %d mal" % bad)
	quit(1 if bad > 0 else 0)
