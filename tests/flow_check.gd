extends Node
## Teste funcional do fluxo da reforma: 5 tarefas -> crossfade -> história ->
## baú (+100 moedas). Roda no main loop normal (precisa do autoload).
## Uso: godot --headless --path <projeto> res://tests/flow_check.tscn

var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs = get_node("/root/GameState")
	gs.reset_progress()
	gs.stars = 5
	var ps: PackedScene = load("res://scenes/renovation.tscn")
	var ren = ps.instantiate()
	get_tree().root.add_child(ren)
	await get_tree().process_frame
	await get_tree().process_frame
	# Completa as 5 tarefas chamando o handler (equivale ao toque).
	for t in ["task_rubble", "task_chairs", "task_deck", "task_plants", "task_flag"]:
		var row: Dictionary = ren._task_rows[t]
		ren._on_task_pressed(t, row["button"])
		await get_tree().process_frame
	_check(gs.stars == 0, "5 tarefas consumiram 5 estrelas")
	_check(ren._all_done(), "todas as tarefas marcadas")
	# Aguarda crossfade (0.8 + 1.4 + 0.4s).
	await get_tree().create_timer(3.0).timeout
	_check(ren._overlay.visible, "overlay da historia visivel apos crossfade")
	_check(ren._dlg_index == 0, "dialogo comeca na linha 0")
	# Avança as 7 falas.
	for i in 7:
		ren._on_overlay_tap()
		await get_tree().process_frame
	_check(ren._overlay.get_node("Chest").visible, "bau aparece apos o dialogo")
	_check(not ren._overlay.get_node("Dialog").visible, "dialogo some apos o fim")
	ren._on_chest_opened()
	await get_tree().process_frame
	_check(gs.coins == 220, "bau deu +100 moedas (120+100)")
	_check(gs.chest_claimed, "bau marcado como resgatado")
	# Reentrar: sem história de novo, bau já resgatado.
	ren.queue_free()
	await get_tree().process_frame
	gs.reset_progress()
	if _fails == 0:
		print("ALL_FLOW_CHECKS_PASSED")
	else:
		printerr("FLOW_CHECKS_FAILED: ", _fails)
	get_tree().quit(_fails)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		_fails += 1
		printerr("FAIL: ", name)
