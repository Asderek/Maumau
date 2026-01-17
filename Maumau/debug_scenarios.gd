class_name DebugScenarios
extends RefCounted

# Main entry point for running debug setups
func run_debug_scenarios(manager: Node) -> void:
	# --- SCENARIO: Spade 4 (Lock) vs Joker ---
	# _set_starting_player(manager,0) # Kept for reference
	
	# --- SCENARIO: 9 Card Draw Bug ---
	# _scenario_9_draw_bug(manager)
	
	# --- SCENARIO: All Nines ---
	# _scenario_all_nines(manager)
	
	# --- SCENARIO: Stacking 7s ---
	# Goal: P1 plays 7 (+2), P2 plays 7 (+4), P3 draws.
	_scenario_stacking_7s(manager)


# --- Scenario Definitions ---

func _scenario_stacking_7s(manager: Node) -> void:
	_move_card_to_discard(manager, "club_5")
	
	_move_card_to_hand(manager, 0, "club_7")
	_move_card_to_hand(manager, 0, "joker_black")
	
	_move_card_to_hand(manager, 1, "diamond_7")
	_move_card_to_hand(manager, 1, "joker_red")
	# P3 (Index 2) Empty
	
	_set_starting_player(manager, 0)

func _scenario_all_nines(manager: Node) -> void:
	_move_card_to_discard(manager, "club_3")
	
	var suits = ["club", "diamond", "heart", "spade"]
	var count = 0
	for i in range(manager.hands_array.size()):
		var suit = suits[count % suits.size()]
		_move_card_to_hand(manager, i, suit + "_9")
		count += 1
		
	_set_starting_player(manager, 0)

func _scenario_9_draw_bug(manager: Node) -> void:
	# P1 (Player 0) Hand: Random card to play.
	# P2 (Player 1) Hand: Empty (Forces pass).
	# P3 (Player 2) Hand: Spade 9 (To trigger effect).
	
	_move_card_to_discard(manager, "club_3")
	
	_move_card_to_hand(manager, 0, "spade_5")
	_move_card_to_hand(manager, 2, "spade_9")
	
	_set_starting_player(manager, 0)

func _scenario_8_jack_bug(manager: Node) -> void:
	_move_card_to_discard(manager, "club_3")
	_move_card_to_hand(manager, 0, "club_8")
	_move_card_to_hand(manager, 1, "diamond_J")
	_move_card_to_hand(manager, 2, "club_5")
	_move_card_to_hand(manager, 2, "spade_5")


# --- Helpers ---

func _move_card_to_discard(manager: Node, card_name: String) -> void:
	var deck = manager.deck
	var discard_pile = manager.discard_pile
	
	# Find card in deck
	var target_card: Card = null
	for card in deck._held_cards:
		if card.card_name == card_name:
			target_card = card
			break
			
	if target_card:
		print("DEBUG: Moving ", card_name, " to Discard Pile")
		discard_pile.move_cards([target_card])
	else:
		printerr("Debug Error: Card not found in deck for discard: ", card_name)

func _move_card_to_hand(manager: Node, player_idx: int, card_name: String) -> void:
	var deck = manager.deck
	var hands_array = manager.hands_array
	
	if player_idx < 0 or player_idx >= hands_array.size():
		printerr("Debug Error: Invalid player index ", player_idx)
		return
		
	# Find card in deck
	var target_card: Card = null
	for card in deck._held_cards:
		if card.card_name == card_name:
			target_card = card
			break
			
	if target_card:
		print("DEBUG: Moving ", card_name, " to Player ", (player_idx + 1))
		hands_array[player_idx].move_cards([target_card])
	else:
		printerr("Debug Error: Card not found in deck: ", card_name)

func _set_starting_player(manager: Node, player_idx: int) -> void:
	if player_idx < 0 or player_idx >= manager.num_players:
		printerr("Debug Error: Invalid starting player index ", player_idx)
		return
	
	# Convert 0-based index to 1-based logic used by game
	manager.current_player = player_idx + 1
	print("DEBUG: Force starting player to: ", manager.current_player)
	manager.update_turn_ui()
