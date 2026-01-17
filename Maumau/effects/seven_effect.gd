class_name SevenEffect
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
	print("Effect: 7 [WAN WAN] -> Neutral")
	manager.log_message("Wan Wan 7: Just a number.")
	manager.cycle_turn(1)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	manager._print_game_event("Effect Triggered", "Stacking 7 (+2)")
	manager.log_message("Effect: +2 Cards! Stack or Draw!")
	
	manager.pending_penalty += 2
	manager.penalty_type = "7"
	
	# Sync failure to pile
	manager.discard_pile.pending_penalty = manager.pending_penalty
	manager.discard_pile.penalty_type = manager.penalty_type
	
	# Intercept Targeting
	var target_idx = manager.get_next_player_index()
	
	manager.apply_targeted_effect(target_idx, manager.current_player, func(final_target):
		if final_target == manager.current_player: # Reflected
			manager.log_message("Reflected! Player %d takes the penalty!" % manager.current_player)
			manager.distribute_cards(manager.hands_array[manager.current_player - 1], manager.pending_penalty)
			
			# Clear Penalty
			manager.pending_penalty = 0
			manager.penalty_type = ""
			manager.discard_pile.pending_penalty = 0
			manager.discard_pile.penalty_type = ""
			
			manager.cycle_turn(1) # Next player's turn
		else:
			# Normal flow: Pass penalty to next
			manager.cycle_turn(1, true)
	)
