class_name SixEffect
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
	# Wan Wan 6: Targeted Chain Reaction (You pick a victim -> Victim picks another -> The second victim draws 1)
	print("Effect: 6 [WAN WAN]")
	manager.log_message("Wan Wan 6! Pick a victim, they will pass the curse!")
	
	manager.discard_pile.input_disabled = true
	
	# Step 1: Current Player Chooses Victim 1
	manager._show_player_selector(manager.current_player, func(victim_1_idx):
		
		# Intercept Targeting 1
		manager.apply_targeted_effect(victim_1_idx, manager.current_player, func(final_v1):
			
			# Step 2: Victim 1 Chooses Victim 2
			# Note: Wait a moment for UI clarity?
			# get_tree().create_timer(1.0).timeout... (async needed)
			
			manager.log_message("Player %d must choose the next victim!" % final_v1)
			
			# Exclude current_player (Caster) from revenge logic
			manager._show_player_selector(final_v1, func(victim_2_idx):
				
				# Intercept Targeting 2
				manager.apply_targeted_effect(victim_2_idx, final_v1, func(final_v2):
					
					manager.log_message("Player %d takes 1 card!" % final_v2)
					manager.distribute_cards(manager.hands_array[final_v2 - 1], 1)
					
					# End Chain
					manager.discard_pile.input_disabled = false
					manager.cycle_turn(1)
				)
			, manager.current_player) # Exclude Caster
		)
	)

static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Check 666 [MAU MAU]")
	
	var beast_summoned = false
	var authors = {}
	if manager.play_history.size() >= 3:
		# Check last 3 cards
		var h1 = manager.play_history[manager.play_history.size() - 1]
		var h2 = manager.play_history[manager.play_history.size() - 2]
		var h3 = manager.play_history[manager.play_history.size() - 3]
		
		var c1 = h1.card_name
		var c2 = h2.card_name
		var c3 = h3.card_name
		
		if "6" in c1 and "6" in c2 and "6" in c3:
			beast_summoned = true
			authors[h1.player] = true
			authors[h2.player] = true
			authors[h3.player] = true
			
	if beast_summoned:
		manager._print_game_event("Effect Triggered", "666 COMPLETED!")
		
		# --- Phase 2: The Demon is Summoned (Game Over) ---
		if manager.devil_awakened:
			manager.log_message("!!! 666 - THE DEMON IS SUMMONED !!!")
			manager.log_message("!!! GAME OVER - THE DEMON WINS !!!")
			#if Alert: Alert.text = "GAME OVER: DEMON WINS"
			# Stop game state/input?
			# For now, just a major log event.
			return
			
		# --- Phase 1: The Devil Awakens ---
		manager.log_message("!!! 666 - THE DEVIL AWAKENS !!!")
		manager.devil_awakened = true
		
		# 1. Remove Top 3 Cards (The 6s) from the game
		manager.discard_pile.remove_top_cards(3)
		manager.log_message("The 3 Sixes are consumed by the void...")
		
		# 2. Identify Victims
		var victims = []
		for p_idx in range(1, manager.num_players + 1):
			if not authors.has(p_idx):
				victims.append(manager.hands_array[p_idx - 1])

		# Fallback: Everyone suffers if all participated
		if victims.is_empty():
			manager.log_message("All are sinners! The spoils effectively vanish (or go to everyone).")
			# User said: "Distributes to Victims". If no victims, logic implies fallback or nothing.
			# Let's fallback to everyone to keep game moving / punishment real.
			victims = manager.hands_array.duplicate()
			
		# 3. Distribute Remaining Pile
		var penalty_pool = manager.discard_pile.collect_all_cards()
		
		if penalty_pool.is_empty():
			manager.log_message("The void was hungry... no other cards to distribute.")
		else:
			penalty_pool.shuffle()
			manager.log_message("The Beast distributes %d remaining cards!" % penalty_pool.size())
			
			var v_idx = 0
			for card in penalty_pool:
				var victim_hand = victims[v_idx % victims.size()]
				victim_hand.move_cards([card])
				v_idx += 1
				
		manager.cycle_turn(1) 
		# Pile is now empty. Next player plays on empty pile (Any card valid).
	else:
		# Normal 6
		manager.log_message("Player %d played a 6..." % manager.current_player)
		manager.cycle_turn(1)
