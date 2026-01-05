extends Node

@export var num_players = 1;
@export var num_cards_in_hand = 5;
@export var hand_scene: PackedScene;
@onready var card_manager := $CardManager;
var hands_array: Array[Hand] = [];

# Called when the node enters the scene tree for the first time.
@export var deck_scene: PackedScene = preload("res://addons/card-framework/pile.tscn")
@export var discard_pile_scene: PackedScene = preload("res://Maumau/mau_mau_pile.tscn")

var deck: Pile
var discard_pile: MauMauPile

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_game()

func setup_game() -> void:
	var screen_size = get_viewport().get_visible_rect().size

	# 1. Instantiate and Shuffle Deck
	deck = deck_scene.instantiate()
	deck.name = "Deck"
	deck.layout = Pile.PileDirection.DOWN
	deck.card_face_up = false
	card_manager.add_child(deck)
	
	# Position Deck (Center Left)
	deck.position = (screen_size / 2) - Vector2(100, 0)
	
	# Populate Deck
	populate_deck()
	
	# Shuffle Deck
	deck.shuffle()
	
	# 2. Instantiate Discard Pile
	discard_pile = discard_pile_scene.instantiate()
	discard_pile.name = "DiscardPile"
	card_manager.add_child(discard_pile)
	
	# Position Discard Pile (Center Right)
	discard_pile.position = (screen_size / 2) + Vector2(100, 0)
	
	# 3. Instantiate Hands with positioning
	for player in range(num_players):
		var hand = hand_scene.instantiate()
		hands_array.append(hand)
		card_manager.add_child(hand)
		
		# Configure Hand
		hand.max_hand_spread = 400
		if player == 0:
			hand.card_face_up = true
		else:
			hand.card_face_up = false # Opponent cards face down
			
		# Position Hands (Simple Cross Layout)
		match player:
			0: # Bottom (Player)
				hand.position = Vector2(screen_size.x / 2, screen_size.y - 100)
				hand.rotation = 0
			1: # Left
				hand.position = Vector2(100, screen_size.y / 2)
				hand.rotation = deg_to_rad(90)
			2: # Top
				hand.position = Vector2(screen_size.x / 2, 100)
				hand.rotation = deg_to_rad(180)
			3: # Right
				hand.position = Vector2(screen_size.x - 100, screen_size.y / 2)
				hand.rotation = deg_to_rad(-90)
				
	# 4. Deal Initial Cards
	deal_initial_cards()
	
	# 5. Start Game (First card to discard)
	var initial_card = deck.get_top_cards(1)
	if not initial_card.is_empty():
		discard_pile.move_cards(initial_card)

func deal_initial_cards() -> void:
	for i in range(num_cards_in_hand):
		for player_hand in hands_array:
			var card_array = deck.get_top_cards(1)
			if card_array.is_empty():
				push_warning("Deck empty during initial deal!")
				break
			player_hand.move_cards(card_array)
			# Add a small delay/tween here if we wanted visuals, but logic is instant for now
		
func populate_deck() -> void:
	var card_data = card_manager.card_factory.preloaded_cards
	if card_data.is_empty():
		push_error("No cards preloaded! Check CardFactory configuration.")
		return
		
	for card_name in card_data.keys():
		# Exclude jokers if they exist in valid set but we want 52 cards
		if "Joker" in card_name:
			continue
			
		var card = card_manager.card_factory.create_card(card_name, deck)
		if card == null:
			push_error("Failed to create card: " + card_name)

	print("Deck populated with ", deck.get_card_count(), " cards.")
