class_name KingEffect
extends RefCounted

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: King [WAN WAN] -> Neutral")
	manager.log_message("Wan Wan King: Just a passing breeze.")
	manager.cycle_turn(1)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Silence (King) [MAU MAU]")
	
	var is_silent = manager.active_effects["silence"]
	manager.active_effects["silence"] = not is_silent
	
	if not is_silent:
		manager.log_message("SILENCE! King commands quiet.")
	else:
		manager.log_message("The King speaks! Silence lifted.")
		
	manager._update_hud_effects()
	manager.cycle_turn(1)
