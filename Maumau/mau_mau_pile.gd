class_name MauMauPile
extends Pile

@onready var Alert = get_node_or_null("Alert")

signal card_played(card: Card, player_index: int)

# The active suit that must be followed. Defaults to the top card's suit.
var active_suit: String = ""
var input_disabled: bool = false # Used to block play during effects/animations

# Rule 8s: Suit Masquerade State
var active_effect_eight_black: bool = false
var active_effect_eight_red: bool = false
# Rule 4s: Lock State (Prevents Joker)
var active_effect_locked: bool = false
# Penalty Stacking
var pending_penalty: int = 0
var penalty_type: String = "" # "7" or "joker"

# Rule 2: Free Play (Next card can be anything)
var free_play_active: bool = false

func add_card(card: Card, index: int = -1) -> void:
	# Capture the player who played this card (Source Hand)
	var player_index = -1
	var manager = card_manager.get_parent()
	if manager and card.card_container:
		if manager.hands_array:
			# Fix: Manual search to avoid TypedArray error
			var hand_idx = -1
			for i in range(manager.hands_array.size()):
				if manager.hands_array[i] == card.card_container:
					hand_idx = i
					break
					
			if hand_idx != -1:
				player_index = hand_idx + 1 # 1-based index
	
	super.add_card(card, index)
	# Default behavior: active suit resets to empty.
	# Normal matching checks the card itself (Step 5).
	# Special effects (Jack/Joker) will overwrite this later in the frame via Manager.
	active_suit = ""
	
	# If this was a free play, consume it.
	if free_play_active:
		print("DEBUG: Consuming Free Play.")
		free_play_active = false
	
	print("DEBUG: Emit card_played signal for ", card.card_name, " | Player: ", player_index)
	card_played.emit(card, player_index)


func _card_can_be_added(_cards: Array) -> bool:
	if input_disabled:
		return false
		
	if _cards.is_empty():
		return false

	var card = _cards[0]
	var manager = card_manager.get_parent()
	
	# --- Turn Validation & Jump-In Check ---
	# We must check if the player playing the card is the current player.
	# If not, we check if it's a valid Jump-In.
	if manager and card.card_container:
		var hand_index = -1
		if manager.hands_array:
			# Fix: Manual search to avoid TypedArray error if card_container type doesn't strictly match Hand
			for i in range(manager.hands_array.size()):
				if manager.hands_array[i] == card.card_container:
					hand_index = i
					break
			
		if hand_index != -1:
			var player_id = hand_index + 1
			if player_id != manager.current_player:
				# Not my turn. Check Jump-In.
				var top_list = get_top_cards(1)
				if top_list.is_empty(): return false # Can't jump in on empty
				
				var top_card = top_list[0]
				if _is_jump_in_valid(card, top_card):
					# Continue to Card Validation (Must still match suit/rank, which it does if Identical)
					pass 
				else:
					if Alert: Alert.text = "Espere sua vez!"
					return false
	var top = get_top_cards(1)
	var candidate = card	
	var candidate_suit = candidate.card_info["suit"]
	var candidate_value = candidate.card_info["value"]

	# 1. Empty pile accepts anything
	if top.is_empty():
		return true;
		
	var player_mode = manager._get_effective_mode(manager.current_player)
	
	# Wan Wan 2: Universal Wildcard (Has all values/suits)
	if candidate_value == "2" and player_mode == manager.MODE_WANWAN:
		if Alert: Alert.text = "Wan Wan 2! Mimicry allowed."
		return true
		
	# 2. Active Penalty Check (Stacking 7s or Jokers)
	# This MUST come before Wildcards/FreePlay/etc.
	if pending_penalty > 0:
		# If there is a penalty stack, player MUST play a matching card (Stacking)
		# e.g. If source is "7", must play "7". If "joker", must play "joker".
		
		# Stacking Validation: Only allowed if player is in MAU MAU mode.
		# Wan Wan cards (7/Joker) are "different" and cannot stack on Mau Mau penalties.
		# Note: Wan Wan 2 (handled above) bypasses this and CAN stack via specific effect logic.
		var is_maumau = (player_mode == manager.MODE_MAUMAU)
		
		var type_match = false
		if penalty_type == "7" and candidate_value == "7":
			if is_maumau: type_match = true
		elif penalty_type == "joker" and candidate_value == "joker":
			if is_maumau: type_match = true
			
		if not type_match:
			if Alert: Alert.text = "Penalidade Ativa! Jogue " + penalty_type + " ou compre cartas."
			return false
			
		# If match, allow it.
		return true
		
	# 1.5 Free Play Active (Rule 2)
	if free_play_active:
		if Alert: Alert.text = "Free Play! Any card allowed."
		return true

	# 2. Only single card drops allowed
	if _cards.size() > 1:
		if Alert: Alert.text = "Jogada invalida: Apenas uma carta por vez."
		return false
	
	# 3. Jack and Joker are wildcards (can be played on anything)
	if candidate_value == "J" or candidate_value == "joker":
		# RULE: If effects are Locked (Spade 4), Joker cannot be played.
		if active_effect_locked and candidate_value == "joker":
			if Alert: Alert.text = "Bloqueado! Efeito do 4 de Espadas proíbe Coringa."
			return false
			
		# RULE: If effects are Locked (Spade 4), Jack acts as NORMAL card (not wildcard).
		if active_effect_locked and candidate_value == "J":
			# Fall through to standard validation (must match suit or rank)
			pass
		else:
			if Alert: Alert.text = "Coringa! Pode jogar."
			return true

	# 4. Check against Active Suit
	# If Active Suit is set (from Jack), we MUST match it (unless playing another wildcard)
	if active_suit != "":
		# LOGIC FIX: The Active Suit is the REQUIREMENT. The Requirement is subject to Masquerade.
		# The Candidate Card is the PHYSICAL card you play. It is NOT subject to masquerade when checking if it MATCHES.
		# Example: Requirement "Spade". Black 8 Active (Spade->Club). Effective Requirement "Club".
		# You must play a PHYSICAL Club.
		
		var effective_requirement = _get_effective_suit(active_suit)

		# If we play a wildcard, it's checked in step 3.
		if candidate_suit == effective_requirement:
			return true
		else:
			if Alert: Alert.text = "Invalido! Naipe pedido: " + active_suit + " (" + effective_requirement + ")"
			return false

	# 5. Standard MauMau Validation (Suit OR Rank)
	if not top.is_empty():
		var top_card = top[0]
		var top_suit = top_card.card_info["suit"]
		var top_value = top_card.card_info["value"]
		
		# --- Rule 8s: Masquerade Logic ---
		# Determine effective suits for Top Card (The "Table" State)
		var effective_top_suit = _get_effective_suit(top_suit)
		
		# LOGIC FIX: Determine match against PHYSICAL candidate
		# "Heart on Heart is illegal" (Red 8 Active: Heart->Diamond).
		# Top: Heart (Eff: Diamond). Candidate: Heart. Match? No.
		# Top: Heart (Eff: Diamond). Candidate: Diamond. Match? Yes.
		
		if candidate_suit == effective_top_suit:
			return true
		
		if candidate_value == top_value:
			return true
			
		if Alert: Alert.text = "Naipe ou Valor incompativel."
		return false
		
	return true
		
		
	if Alert:
		Alert.text = "Jogada invalida! Precisa de " + active_suit + " ou J."
	return false;

# Helper to calculate suit under Masquerade rules
func _get_effective_suit(base_suit: String) -> String:
	if active_effect_eight_black:
		if base_suit == "club": return "spade"
		if base_suit == "spade": return "club"
		
	if active_effect_eight_red:
		if base_suit == "heart": return "diamond"
		if base_suit == "diamond": return "heart"
		
	return base_suit


func _is_jump_in_valid(card: Card, top_card: Card) -> bool:
	if not GameGlobals.is_rule_active("jump_in"):
		return false
		
	# Exact Match Strategy (Requires Double Deck)
	# Same Suit AND Same Rank
	
	# 1. Compare Names (e.g. "heart_7" == "heart_7")
	if card.card_name == top_card.card_name:
		return true
		
	return false


# Collect cards for Rule 666 Penalty
# Removes all cards from the pile EXCEPT the top 'keep_count' cards.
# Returns the removed cards as an Array.
func collect_penalty_cards(keep_count: int = 1) -> Array[Card]:
	if _held_cards.size() <= keep_count:
		return []
		
	var pool: Array[Card] = []
	# The top cards are at the END of the array
	var cards_to_remove_count = _held_cards.size() - keep_count
	
	# Slice the bottom cards (0 to size-keep)
	var cards_to_take = _held_cards.slice(0, cards_to_remove_count)
	
	for card in cards_to_take:
		remove_card(card)
		pool.append(card)
		
	return pool

# Removes the top 'count' cards from the pile and deletes them (removes from game).
func remove_top_cards(count: int) -> void:
	if _held_cards.is_empty(): return
	
	var actual_count = min(count, _held_cards.size())
	# Top cards are at the END
	for i in range(actual_count):
		var card = _held_cards.pop_back()
		# Remove visually from container
		remove_child(card) # Or proper removal logic that card logic handles? 
		# Card.gd typically handles input events. 
		# If we just queue_free, it's gone.
		card.queue_free()
		
	# Re-organize pile visual?
	_update_target_positions() 

# Collect ALL cards from the pile (Empty the pile)
func collect_all_cards() -> Array[Card]:
	return collect_penalty_cards(0)
