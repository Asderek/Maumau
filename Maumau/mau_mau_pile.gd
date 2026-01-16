class_name MauMauPile
extends Pile

@onready var Alert = get_node_or_null("Alert")

signal card_played(card: Card)

# The active suit that must be followed. Defaults to the top card's suit.
var active_suit: String = ""
var input_disabled: bool = false # Used to block play during effects/animations

# Rule 8s: Suit Masquerade State
var active_effect_eight_black: bool = false
var active_effect_eight_red: bool = false

# Rule 2: Free Play (Next card can be anything)
var free_play_active: bool = false

func add_card(card: Card, index: int = -1) -> void:
	super.add_card(card, index)
	# Default behavior: active suit resets to empty.
	# Normal matching checks the card itself (Step 5).
	# Special effects (Jack/Joker) will overwrite this later in the frame via Manager.
	active_suit = ""
	
	# If this was a free play, consume it.
	# BUT wait, the CARD played usually sets new rules.
	# The effect of the "2" (free play) was set by the PREVIOUS card.
	# So if we just played a standard card on top of a 2, we consume the flag.
	if free_play_active:
		print("DEBUG: Consuming Free Play.")
		free_play_active = false
	
	print("DEBUG: Emit card_played signal for ", card.card_name, " | Active Suit: ", active_suit)
	card_played.emit(card)


func _card_can_be_added(_cards: Array) -> bool:
	if input_disabled:
		return false
		
	var top = get_top_cards(1)	
	
	if _cards.is_empty():
		return false

	var candidate = _cards[0]
	var candidate_suit = candidate.card_info["suit"]
	var candidate_value = candidate.card_info["value"]

	# 1. Empty pile accepts anything
	if top.is_empty():
		return true;
		
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
		if Alert: Alert.text = "Coringa! Pode jogar."
		return true

	# 4. Check against Active Suit
	# If Active Suit is set (from Jack), we MUST match it (unless playing another wildcard)
	if active_suit != "":
		# If we play a wildcard, it's checked in step 3.
		if candidate_suit == active_suit:
			return true
		else:
			if Alert: Alert.text = "Invalido! Naipe pedido: " + active_suit
			return false

	# 5. Standard MauMau Validation (Suit OR Rank)
	if not top.is_empty():
		var top_card = top[0]
		var top_suit = top_card.card_info["suit"]
		var top_value = top_card.card_info["value"]
		
		# --- Rule 8s: Masquerade Logic ---
		# If effect is active, SWAP the effective suit of the TOP card (not the candidate)
		# "Black cards on top count as opposite suit"
		
		var effective_top_suit = top_suit
		
		if active_effect_eight_black:
			if top_suit == "club": effective_top_suit = "spade"
			elif top_suit == "spade": effective_top_suit = "club"
			
		if active_effect_eight_red:
			if top_suit == "heart": effective_top_suit = "diamond"
			elif top_suit == "diamond": effective_top_suit = "heart"
			
		# ---------------------------------
		
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
