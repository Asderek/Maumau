class_name QueenEffect
extends RefCounted

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Reverse (Q) [MAU MAU]")
	manager.log_message("Effect: Direction Reversed!")
	manager.play_direction *= -1
	manager._update_hud_effects()
	manager.cycle_turn(1)
	
static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: Queen (Q) [WAN WAN]")
	manager.log_message("Wan Wan Queen! Choose a victim to roll!")
	
	# Block input
	manager.discard_pile.input_disabled = true
	
	# Show Player Selector
	manager._show_player_selector(manager.current_player, func(target_idx):
		# Intercept Targeting (Wan Wan Queen)
		manager.apply_targeted_effect(target_idx, manager.current_player, func(final_target):
			manager.log_message("Player %d targets Player %d!" % [manager.current_player, final_target])
			
			# Roll Die for Target
			var val = randi() % 6 + 1
			manager.show_dice_roll(final_target, val)
			
			# Apply Mode Change
			if val % 2 == 0:
				manager._set_player_mode(final_target, manager.MODE_MAUMAU)
			else:
				manager._set_player_mode(final_target, manager.MODE_WANWAN)
				
			# Wait for roll animation
			await manager.get_tree().create_timer(3.0).timeout
			
			manager.discard_pile.input_disabled = false
			manager.cycle_turn(1)
		)
	)
