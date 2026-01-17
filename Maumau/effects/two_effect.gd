class_name TwoEffect

static func execute(manager: Node, card: Node) -> void:
	var mode = manager._get_effective_mode(manager.current_player)
	if mode == manager.MODE_WANWAN:
		_execute_wanwan(manager, card)
	else:
		_execute_maumau(manager, card)

# 2 (Mau Mau): Double Play (Play again)
static func _execute_maumau(manager: Node, _card: Node) -> void:
	print("Effect: Double Play (2) [MAU MAU]")
	manager.log_message("Player %d plays again! (Any Card)" % manager.current_player)
	
	# Enable Free Play for the follow-up card
	manager.discard_pile.free_play_active = true
	manager._update_hud_effects()
	
	# Visual feedback
	if manager.hud_layer:
		var bubble = manager.speech_bubble_scene.instantiate()
		manager.hud_layer.add_child(bubble)
		var current_hand = manager.hands_array[manager.current_player - 1]
		bubble.global_position = current_hand.get_global_transform_with_canvas().origin + Vector2(0, -100)
		bubble.show_message("I play again!", 1.5)
	
	# Do NOT cycle turn. Player plays again.

# 2 (Wan Wan): Mimic (Transform into any card)
static func _execute_wanwan(manager: Node, _card: Node) -> void:
	print("Effect: Mimic (2) [WAN WAN]")
	manager.log_message("Wan Wan 2! Mimicry!")
	
	manager.discard_pile.input_disabled = true
	
	manager._show_mimic_selector(func(selected_rank: String, selected_suit: String):
		manager.log_message("The 2 becomes a %s %s!" % [selected_suit.capitalize(), selected_rank])
		
		# Set Active Suit
		manager.discard_pile.active_suit = selected_suit
		
		var card = _card
		
		# --- Effect Logic ---
		# Re-enable input before dispatching so delegates can re-disable if needed
		manager.discard_pile.input_disabled = false
		
		# --- Effect Logic ---
		if selected_rank == "J":
			JackEffect.execute(manager, card)
		elif selected_rank == "Q":
			QueenEffect.execute(manager, card)
		elif selected_rank == "8":
			EightEffect.execute(manager, card)
		elif selected_rank == "6":
			if manager._get_effective_mode(manager.current_player) == manager.MODE_WANWAN: SixEffect._execute_wanwan(manager, card)
			else: SixEffect._execute_maumau(manager, card)
		elif selected_rank == "A":
			AceEffect.execute(manager, card)
		elif selected_rank == "7":
			SevenEffect.execute(manager, card)
		elif selected_rank == "9":
			NineEffect.execute(manager, card)
		elif selected_rank == "10":
			TenEffect.execute(manager, card)
		elif selected_rank == "K":
			KingEffect.execute(manager, card)
		elif selected_rank == "Joker":
			JokerEffect.execute(manager, card) 
		else:
			# Number cards
			if selected_rank == "4":
				if selected_suit == "club": FourEffect.execute_club(manager, card)
				elif selected_suit == "spade": FourEffect.execute_spade(manager, card)
				else: FourEffect.execute_red(manager, card)
			elif selected_rank == "5":
				if selected_suit == "diamond": FiveEffect.execute_diamond(manager, card)
				elif selected_suit == "heart": FiveEffect.execute_heart(manager, card)
				else: manager.cycle_turn(1) # Default
			else:
				manager.cycle_turn(1)
	)
