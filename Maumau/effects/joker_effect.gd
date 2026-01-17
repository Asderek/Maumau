class_name JokerEffect
extends RefCounted

static func execute(manager: Node, card: Node) -> void:
	manager._print_game_event("Effect Triggered", "Stacking Joker (+4)")
	manager.log_message("Joker! +4 Cards! Stack or Draw!")
	
	manager.pending_penalty += 4
	manager.penalty_type = "joker"
	
	# Sync failure to pile
	manager.discard_pile.pending_penalty = manager.pending_penalty
	manager.discard_pile.penalty_type = manager.penalty_type
	
	var target_idx = manager.get_next_player_index()
	
	# Intercept Targeting
	manager.apply_targeted_effect(target_idx, manager.current_player, func(final_target):
		if final_target == manager.current_player: # Reflected
			manager.log_message("Reflected! Player %d takes the Joker penalty!" % manager.current_player)
			manager.distribute_cards(manager.hands_array[manager.current_player - 1], manager.pending_penalty)
			
			# Clear Penalty
			manager.pending_penalty = 0
			manager.penalty_type = ""
			manager.discard_pile.pending_penalty = 0
			manager.discard_pile.penalty_type = ""
			
			# Don't skip next player if reflected (Sender took hit)
			manager.pending_turn_skip = 1
		else:
			# Normal
			# Do NOT skip target immediately if stacking is allowed.
			# Pass turn to target (1 step) so they can Stack or Draw.
			manager.pending_turn_skip = 1
			
		# Proceed to Suit Selection (Sender chooses)
		# Use JackEffect's Maumau impl which handles Suit Selection.
		# Note: JackEffect._execute_maumau expects manager and card.
		JackEffect._execute_maumau(manager, card)
	)
