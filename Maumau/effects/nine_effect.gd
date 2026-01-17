class_name NineEffect
extends RefCounted

static func execute(manager: Node, _card: Node) -> void:
	print("Effect: Last Player Draws (9)")
	
	if manager.play_history.size() < 2:
		print("History too short to apply Rule 9.")
		manager.cycle_turn(1)
		return

	# 1. Calculate Stacking Streak
	# Count how many contiguous 9s are at the end of history
	var streak = 0
	for i in range(manager.play_history.size() - 1, -1, -1):
		var hist_card_name = manager.play_history[i].card_name
		if "9" in hist_card_name: # Simple check for rank 9
			streak += 1
		else:
			break
			
	var amount_to_draw = streak
	
	# 2. Identify Target
	# The target is likely the player of the PREVIOUS card in history.
	# Example: [P1:5, P2:9 (Current)]. Target P1. Amount 1.
	# Example: [P1:5, P2:9, P4:9 (Current)]. Target P2. Amount 2.
	
	# EXCEPTION: Self-Doubling (P2 plays 9, then P2 jumps in with 9)
	# Logic: [P1:5, P2:9, P2:9]. 
	# Default logic would target P2 (index -2). This is self-punishment.
	# User Rule: In this case, target P1 (index -3).
	
	var target_index_in_history = manager.play_history.size() - 2
	
	if manager.play_history.size() >= 2:
		var last_player_idx = manager.play_history[manager.play_history.size() - 1].player
		var prev_player_idx = manager.play_history[manager.play_history.size() - 2].player
		
		# Check for Self-Double (Same player played last 2 cards)
		if last_player_idx == prev_player_idx and "9" in manager.play_history[manager.play_history.size() - 1].card_name:
			# Self-Double Detected involving current card
			target_index_in_history = manager.play_history.size() - 3
			print("DEBUG: Self-Doubling 9 detected! Redirecting target to history[-3].")

	if target_index_in_history < 0:
		print("History too short for Rule 9 target calculation (Start of Game?).")
		manager.cycle_turn(1)
		return

	var target_entry = manager.play_history[target_index_in_history]
	var target_player_idx = target_entry.player
	
	# Intercept Targeting (Rule 9)
	manager.apply_targeted_effect(target_player_idx, manager.current_player, func(final_target):
		manager.log_message("Effect: Player %d draws %d card(s)! (Rule 9)" % [final_target, amount_to_draw])
		
		var target_hand = manager.hands_array[final_target - 1]
		manager.distribute_cards(target_hand, amount_to_draw)
		
		manager.cycle_turn(1)
	)
