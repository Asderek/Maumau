extends Node

@export var num_players = 1;
@export var num_cards_in_hand = 5;
@export var current_player: int = 1;
@export var hand_scene: PackedScene;
@onready var card_manager := $CardManager;
var hands_array: Array[Hand] = [];

# Called when the node enters the scene tree for the first time.
@export var deck_scene: PackedScene = preload("res://addons/card-framework/pile.tscn")
@export var discard_pile_scene: PackedScene = preload("res://Maumau/mau_mau_pile.tscn")

@export_group("Layout Settings")
@export var layout_scale: float = 1.5
@export var base_offset_deck: Vector2 = Vector2(100, 0)
@export var base_offset_discard: Vector2 = Vector2(200, 0)
@export var base_padding_hand: float = 100.0
@export var base_offset_label: Vector2 = Vector2(0, -60)

var deck: Pile
var discard_pile: MauMauPile
var player_label: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	setup_game()

func setup_game() -> void:
	var screen_size = get_viewport().get_visible_rect().size

	# 1. Instantiate and Shuffle Deck
	deck = deck_scene.instantiate()
	deck.name = "Deck"
	deck.stack_direction = Pile.PileDirection.CENTER
	deck.card_face_up = false
	card_manager.add_child(deck)
	
	# Position Deck (Center Left)
	deck.position = (screen_size / 2) - (base_offset_deck * layout_scale)
	
	# Populate Deck
	populate_deck()
	
	# Shuffle Deck
	#deck.shuffle()
	
	deck.card_pressed.connect(_on_deck_card_pressed)

	# 2. Instantiate Discard Pile
	discard_pile = discard_pile_scene.instantiate()
	discard_pile.name = "DiscardPile"
	discard_pile.stack_direction = Pile.PileDirection.RIGHT
	card_manager.add_child(discard_pile)
	
	# Position Discard Pile (Center Right)
	discard_pile.position = (screen_size / 2) + (base_offset_discard * layout_scale)
	
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
		# Position Hands (Simple Cross Layout)
		var scaled_padding = base_padding_hand * layout_scale
		match player:
			0: # Bottom (Player)
				hand.position = Vector2(screen_size.x / 2, screen_size.y - scaled_padding)
				hand.rotation = 0
			1: # Left
				hand.position = Vector2(scaled_padding, screen_size.y / 2)
				hand.rotation = deg_to_rad(90)
				for card in hand._held_cards:
					card.rotation_degrees = 0
				
			2: # Top
				hand.position = Vector2(screen_size.x / 2, scaled_padding)
				hand.rotation = deg_to_rad(180)
			3: # Right
				hand.rotation = deg_to_rad(270)
				hand.position = Vector2(screen_size.x - scaled_padding, screen_size.y / 2)
				for card in hand._held_cards:
					card.rotation_degrees -= 90
				
	# 4. Deal Initial Cards
	deal_initial_cards()
	
	# 5. Start Game (First card to discard)
	var initial_card = deck.get_top_cards(1)
	if not initial_card.is_empty():
		discard_pile.move_cards(initial_card)

	# 6. Current Player UI
	player_label = Label.new()
	card_manager.add_child(player_label)
	player_label.position = deck.position + (base_offset_label * layout_scale) # Above deck
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_turn_ui()

var selected_card_index = 0

func _process(delta: float) -> void:
	# Handle highlights every frame
	handle_highlight()
	
	if hands_array.size() <= 1: return
	
	var hand_left = hands_array[1]
	
	# Hand Rotation (WASD)
	if Input.is_physical_key_pressed(KEY_A):
		hand_left.rotation_degrees -= 90 * delta
		hand_left.update_card_ui()
	if Input.is_physical_key_pressed(KEY_D):
		hand_left.rotation_degrees += 90 * delta
		hand_left.update_card_ui()
		
	# Card Selection (Up/Down)
	if Input.is_action_just_pressed("ui_up"):
		selected_card_index = min(selected_card_index + 1, hand_left.get_card_count() - 1)
		print("Selected card index: ", selected_card_index)
		
	if Input.is_action_just_pressed("ui_down"):
		selected_card_index = max(selected_card_index - 1, 0)
		print("Selected card index: ", selected_card_index)
		
		
	# Cycle Turn (Space)
	if Input.is_action_just_pressed("ui_accept"): 
		cycle_turn()

	# Rotate Selected Card (Left/Right)
	if hand_left.get_card_count() > 0:
		var cards = hand_left._held_cards
		if Input.is_physical_key_pressed(KEY_LEFT):
			for card in cards:
				card.rotation_degrees -= 90 * delta	
				print(card.rotation_degrees)
			for card in cards:
				card.rotation_degrees += 90 * delta	
				print(card.rotation_degrees)

func cycle_turn() -> void:
	current_player += 1
	if current_player > num_players:
		current_player = 1
	update_turn_ui()

func update_turn_ui() -> void:
	var player_name = ""
	match current_player:
		1: player_name = "Down"
		2: player_name = "Left"
		3: player_name = "Up"
		4: player_name = "Right"
	
	player_label.text = "Current Player: " + player_name
	
	for i in range(hands_array.size()):
		var hand = hands_array[i]
		if i == current_player - 1:
			hand.set_highlight(true)
		else:
			hand.set_highlight(false)

func _on_deck_card_pressed(_card: Card) -> void:
	if current_player >= 1 and current_player <= hands_array.size():
		var card_array = deck.get_top_cards(1)
		if not card_array.is_empty():
			hands_array[current_player - 1].move_cards(card_array)

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


func handle_highlight() -> void:
	# 1. Reset helper highlight on discard pile
	if discard_pile:
		for card in discard_pile._held_cards:
			card.set_helper_display(false)
			
	# Reset helper highlight on deck if needed (though usually hidden if face down/stacked)
	if deck:
		for card in deck._held_cards:
			card.set_helper_display(false)

	# Check if any card is currently being dragged (held)
	# Retrieve the actual cards from CardManager
	var dragged_cards = card_manager.current_dragged_cards
	var is_dragging = not dragged_cards.is_empty()
	
	# Handle Highlight for Discard Pile
	var discard_top_cards = discard_pile.get_top_cards(1)
	if not discard_top_cards.is_empty():
		var top_card = discard_top_cards[0]
		# Only highlight if dragging
		if is_dragging:
			# Use logic-only check (ignores mouse position) to show valid target immediately
			var can_accept = discard_pile._card_can_be_added(dragged_cards)
			top_card.set_helper_display(true, can_accept)
		
	# Handle Highlight for Deck (Draw Pile)
	var deck_top_cards = deck.get_top_cards(1)
	if not deck_top_cards.is_empty():
		var top_card = deck_top_cards[0]
		if is_dragging:
			# Usually you can't drop cards ONTO the deck in MauMau, so this is likely invalid (Red)
			# Force false to show "Invalid" (Red) immediately
			top_card.set_helper_display(true, false)
