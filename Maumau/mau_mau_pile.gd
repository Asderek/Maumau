class_name MauMauPile
extends Pile

@onready var Alert = get_node_or_null("Alert")

signal card_played(card: Card)

# The active suit that must be followed. Defaults to the top card's suit.
var active_suit: String = ""
var input_disabled: bool = false # Used to block play during effects/animations

func add_card(card: Card, index: int = -1) -> void:
	super.add_card(card, index)
	# Default behavior: active suit becomes the suit of the played card
	# This can be overwritten by specific effects (like Jack) later in the frame
	active_suit = card.card_info["suit"]
	
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

	# 2. Only single card drops allowed
	if _cards.size() > 1:
		if Alert: Alert.text = "Jogada invalida: Apenas uma carta por vez."
		return false
	
	# 3. Jack is always wildcard (can be played on anything)
	if candidate_value == "J":
		if Alert: Alert.text = "Coringa (J)! Pode jogar."
		return true

	# 4. Check against Active Suit
	if candidate_suit == active_suit:
		if Alert: Alert.text = "Naipe correto (" + active_suit + ")."
		return true;
	
	# 5. Check against Rank (Value) - only physically works if values match top card
	# Let's stick to: Rank matching is valid against the TOP CARD.
	if not top.is_empty() and candidate_value == top[0].card_info["value"]:
		if Alert: Alert.text = "Mesmo valor. Jogada valida."
		return true;
		
		
	if Alert:
		Alert.text = "Jogada invalida! Precisa de " + active_suit + " ou J."
	return false;
