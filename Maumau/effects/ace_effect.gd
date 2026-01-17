class_name AceEffect

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == manager.MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

# Ace (Mau Mau): Skip next player
static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Skip (Ace) [MAU MAU]")
	manager.log_message("Effect: Skip Next Player!")
	manager.cycle_turn(2)

# Ace (Wan Wan): Play card from victim's hand using Victim's Mode
static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: Ace [WAN WAN]")
	manager.log_message("Wan Wan Ace! Steal a fate!")
	
	manager.discard_pile.input_disabled = true
	
	manager._show_player_selector(manager.current_player, func(target_idx):
		
		manager.apply_targeted_effect(target_idx, manager.current_player, func(final_target):
			# Show Blind Hand Selector
			manager._show_blind_hand_selector(final_target, func(picked_card: Node):
				
				manager.log_message("Player %d played %s from Player %d's hand!" % [manager.current_player, picked_card.card_name, final_target])
				
				# 1. Move Card to Discard
				var target_hand = manager.hands_array[final_target - 1]
				target_hand.remove_card(picked_card)
				
				# Suppress signal
				if manager.discard_pile.card_played.is_connected(manager._on_card_played):
					manager.discard_pile.card_played.disconnect(manager._on_card_played)
				
				manager.discard_pile.add_card(picked_card) 
				
				if not manager.discard_pile.card_played.is_connected(manager._on_card_played):
					manager.discard_pile.card_played.connect(manager._on_card_played)
				
				# 2. Determine Effect based on FINAL TARGET's Mode
				var target_mode = manager._get_effective_mode(final_target)
				
				# 3. Dispatch Effect (Must handle dependencies manually or circular imports?)
				# Ideally, Manager should expose a generic 'execute_card_effect(card, mode)' method?
				# For now, we manually dispatch similar to before, but we need access to other Effects if we modularize them too!
				# If we modularize Ace first, others are still in Manager usually.
				# But wait, Ace calls 10, K, etc.
				# If we modularize everything, we need centralized access.
				# Manager.card_effects maps keys to Callables.
				# We can check card rank and invoke `manager.card_effects[key].call(picked_card)`.
				# BUT `card_effects` might use `current_player` mode (Proxies).
				# We specifically need TARGET MODE logic.
				# The Proxies I wrote earlier use `current_player`.
				# This is the problem I found in Step 2066.
				# "My proxies use current_player... Ace Steal (Target Mode) requires target logic".
				
				# Solution: We must implement the Logic Switch here explicitly, calling correct sub-functions.
				# But if they are in other files...
				# Maybe pass `mode` to effects? `execute(manager, card, force_mode="")`?
				# If I update all effects to accept optional mode override, proxies can use it.
				
				# For now, I will keep the Switch Dispatcher here, pointing to Manager functions (until they move).
				# As I move them, I update this file.
				
				# Re-enable input before dispatching (delegate might disable it again if async)
				manager.discard_pile.input_disabled = false
				
				var rank = picked_card.card_info["value"]
				
				# Dispatcher Switch
				# Dispatcher Switch
				if rank == "J":
					if target_mode == manager.MODE_WANWAN: JackEffect._execute_wanwan(manager, picked_card)
					else: JackEffect._execute_maumau(manager, picked_card)
				elif rank == "Q":
					if target_mode == manager.MODE_WANWAN: QueenEffect._execute_wanwan(manager, picked_card)
					else: QueenEffect._execute_maumau(manager, picked_card)
				elif rank == "8":
					EightEffect.execute(manager, picked_card)
				elif rank == "6":
					if target_mode == manager.MODE_WANWAN: SixEffect._execute_wanwan(manager, picked_card)
					else: SixEffect._execute_maumau(manager, picked_card)
				elif rank == "A":
					# Recursion! Call this script's functions.
					# Since AceEffect is a static class, we can just call execute.
					AceEffect.execute(manager, picked_card)
				elif rank == "7":
					SevenEffect.execute(manager, picked_card)
				elif rank == "9":
					NineEffect.execute(manager, picked_card)
				elif rank == "10":
					TenEffect.execute(manager, picked_card)
				elif rank == "K":
					if target_mode == manager.MODE_WANWAN: KingEffect._execute_wanwan(manager, picked_card)
					else: KingEffect._execute_maumau(manager, picked_card)
				elif "joker" in picked_card.card_name.to_lower():
					JokerEffect.execute(manager, picked_card)
				else:
					# Number cards 4, 5
					if rank == "4":
						if target_mode == manager.MODE_WANWAN: FourEffect._execute_wanwan_neutral(manager, picked_card, "4")
						else:
							var suit = picked_card.card_info["suit"]
							if suit == "club": FourEffect._execute_club_4_maumau(manager, picked_card)
							elif suit == "spade": FourEffect._execute_spade_4_maumau(manager, picked_card)
							else: FourEffect._execute_red_4_maumau(manager, picked_card)
					elif rank == "5":
						if target_mode == manager.MODE_WANWAN: FiveEffect._execute_wanwan_neutral(manager, picked_card, "5")
						else:
							var suit = picked_card.card_info["suit"]
							if suit == "diamond": FiveEffect._execute_rotate_right_1_maumau(manager, picked_card)
							elif suit == "heart": FiveEffect._execute_rotate_left_2_maumau(manager, picked_card)
							else: manager.cycle_turn(1)
					else:
						manager.cycle_turn(1)
			)
		)
	, manager.current_player)
