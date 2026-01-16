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
# UI Scenes for Effects
var suit_selector_scene: PackedScene = preload("res://Maumau/suit_selector.tscn")
var speech_bubble_scene: PackedScene = preload("res://Maumau/speech_bubble.tscn")

var player_labels: Array[Label] = []

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
	_register_card_effects()
	setup_game()
	setup_ui()

var top_bar_height: float = 0.0

func setup_game() -> void:
	var screen_size = get_viewport().get_visible_rect().size
	
	# Calculate Top Bar Height (5% of screen)
	top_bar_height = screen_size.y * 0.05
	
	# Define available play area below the top bar
	var available_rect = Rect2(0, top_bar_height, screen_size.x, screen_size.y - top_bar_height)
	var center_point = available_rect.get_center()

	# 1. Instantiate and Shuffle Deck
	deck = deck_scene.instantiate()
	deck.name = "Deck"
	deck.stack_direction = Pile.PileDirection.CENTER
	deck.card_face_up = false
	card_manager.add_child(deck)
	
	# Position Deck (Center Left of available area)
	deck.position = center_point - (base_offset_deck * layout_scale)
	
	# Populate Deck
	populate_deck()
	
	# Shuffle Deck
	deck.shuffle()
	
	deck.card_pressed.connect(_on_deck_card_pressed)

	# 2. Instantiate Discard Pile
	discard_pile = discard_pile_scene.instantiate()
	discard_pile.name = "DiscardPile"
	discard_pile.stack_direction = Pile.PileDirection.RIGHT
	card_manager.add_child(discard_pile)
	
	# Position Discard Pile (Center Right of available area)
	discard_pile.position = center_point + (base_offset_discard * layout_scale)
	
	if not discard_pile.card_played.is_connected(_on_card_played):
		discard_pile.card_played.connect(_on_card_played)
		print("DEBUG: Manager connected to DiscardPile signal.")
	else:
		print("DEBUG: Manager ALREADY connected to DiscardPile signal. Skipping.")
	
	
	
	# 3. Instantiate Hands with positioning
	for player in range(num_players):
		var hand = hand_scene.instantiate()
		hands_array.append(hand)
		card_manager.add_child(hand)
		
		# Configure Hand
		hand.max_hand_spread = 400
		hand.card_face_up = true # DEBUG: All cards face up
		#if player == 0:
		#	hand.card_face_up = true
		#else:
		#	hand.card_face_up = false # Opponent cards face down
			
		# Position Hands (Simple Cross Layout)
		# Reverting to manual Vector2 positioning for stability
		var scaled_padding = base_padding_hand * layout_scale
		match player:
			0: # Bottom (Player)
				# Reset anchors to default to avoid conflict
				hand.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				hand.position = Vector2(center_point.x, screen_size.y - scaled_padding)
				hand.rotation = 0
			1: # Left
				hand.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				hand.position = Vector2(scaled_padding, center_point.y)
				hand.rotation = deg_to_rad(90)
				for card in hand._held_cards:
					card.rotation_degrees = 0
				
			2: # Top
				hand.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				# Position at exact horizontal center + offset
				# Push down by top_bar_height + padding + extra margin (50)
				# Move right by 40px to fix visual center
				hand.position = Vector2(center_point.x + 40, top_bar_height + scaled_padding + 50)
				hand.rotation = deg_to_rad(180)
			3: # Right
				hand.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
				hand.position = Vector2(screen_size.x - scaled_padding, center_point.y)
				hand.rotation = deg_to_rad(270)
				for card in hand._held_cards:
					card.rotation_degrees -= 90
				
	# 4. Deal Initial Cards
	deal_initial_cards()
	
	# 5. Start Game (First card to discard)
	var initial_card = deck.get_top_cards(1)
	if not initial_card.is_empty():
		discard_pile.move_cards(initial_card)

	# Randomize first player
	current_player = (randi() % num_players) + 1
	print("Randomly selected start player: ", current_player)

	# 6. Current Player UI
	player_label = Label.new()
	card_manager.add_child(player_label)
	# Position relative to deck, which is already correctly positioned in available area
	player_label.position = deck.position + (base_offset_label * layout_scale) 
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_turn_ui()
	update_player_stats()

var play_direction: int = 1 # 1 for clockwise, -1 for counter-clockwise
var last_player_who_played: int = -1

var selected_card_index = 0

func _process(_delta: float) -> void:
	# Handle highlights every frame
	handle_highlight()
	
	if hands_array.size() <= 1: return
	
	# Cycle Turn (Space)
	if Input.is_action_just_pressed("ui_accept"): 
		cycle_turn()

func cycle_turn(steps: int = 1) -> void:
	# Update last player BEFORE moving turn
	last_player_who_played = current_player
	
	# Calculate new player index with direction
	var new_index = current_player + (steps * play_direction)
	
	# Wrap around logic (1-based index)
	while new_index > num_players:
		new_index -= num_players
	while new_index < 1:
		new_index += num_players
		
	current_player = new_index
	update_turn_ui()

func get_next_player_index(steps: int = 1) -> int:
	var next_index = current_player + (steps * play_direction)
	while next_index > num_players:
		next_index -= num_players
	while next_index < 1:
		next_index += num_players
	return next_index

func distribute_cards(target_hand: Hand, count: int) -> void:
	var cards_to_deal = deck.get_top_cards(count)
	if cards_to_deal.is_empty():
		# TODO: Handle deck empty (reshuffle discard pile)
		push_warning("Deck empty! Cannot deal " + str(count) + " cards.")
		return
	
	for c in cards_to_deal:
		c.set_helper_display(false) # Reset any highlight (like Red invalid)
		
	target_hand.move_cards(cards_to_deal)
	update_player_stats()

func update_turn_ui() -> void:
	var player_name = ""
	match current_player:
		1: player_name = "Down"
		2: player_name = "Left"
		3: player_name = "Up"
		4: player_name = "Right"
	
	#player_label.text = "Current Player: " + player_name
	
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
			update_player_stats()

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
	# var deck_top_cards = deck.get_top_cards(1)
	# if not deck_top_cards.is_empty():
	# 	var top_card = deck_top_cards[0]
	# 	if is_dragging:
	# 		# Usually you can't drop cards ONTO the deck in MauMau, so this is likely invalid (Red)
	# 		# Force false to show "Invalid" (Red) immediately
	# 		# top_card.set_helper_display(true, false) # REMOVED: Causing persistent Red bug if dealt immediately
	# 		pass


func _on_card_played(card: Card) -> void:
	print("Brain Function Triggered! Card Played: ", card.card_name, " | Handler Frame: ", Engine.get_process_frames())
	log_message("Player %d played %s" % [current_player, card.card_name.replace("_", " ").capitalize()])
	
	# Dispatch to specific effect handler
	if card_effects.has(card.card_name):
		print("DEBUG: Dispatching to specific handler for ", card.card_name)
		card_effects[card.card_name].call(card)
	else:
		print("DEBUG: Using default handler for ", card.card_name)
		_effect_default(card)


# --- Card Effect System ---

var card_effects: Dictionary = {}

func _register_card_effects() -> void:
	# Generic rules by value
	var suits = ["club", "diamond", "heart", "spade"]
	var special_values = ["A", "7", "9", "Q", "J"]
	
	for suit in suits:
		for value in special_values:
			var card_name = suit + "_" + value
			
			match value:
				"A": card_effects[card_name] = _effect_skip
				"7": card_effects[card_name] = _effect_draw_2_skip
				"9": card_effects[card_name] = _effect_draw_last_player
				"Q": card_effects[card_name] = _effect_reverse
				"J": card_effects[card_name] = _effect_jack
				
	# Specific rules by name
	card_effects["diamond_5"] = _effect_rotate_right_1
	card_effects["heart_5"] = _effect_rotate_left_2

# Default effect: just pass the turn
func _effect_default(_card: Card) -> void:
	cycle_turn(1)

# --- Effect Handlers ---

# Ace: Skip next player
func _effect_skip(_card: Card) -> void:
	print("Effect: Skip (Ace)")
	log_message("Effect: Skip Next Player!")
	cycle_turn(2)

# 7: Next player draws 2 and is skipped
func _effect_draw_2_skip(_card: Card) -> void:
	print("Effect: Draw 2 & Skip (7)")
	log_message("Effect: Next player draws 2 and skips!")
	var next_player_idx = get_next_player_index(1)
	var next_hand = hands_array[next_player_idx - 1]
	distribute_cards(next_hand, 2)
	cycle_turn(2) # Skip

# 9: Last player who played draws 1
func _effect_draw_last_player(_card: Card) -> void:
	print("Effect: Last Player Draws (9)")
	log_message("Effect: Last player draws 1 card!")
	if last_player_who_played != -1:
		var target_hand = hands_array[last_player_who_played - 1]
		distribute_cards(target_hand, 1)
	else:
		print("No previous player to punish!")
	cycle_turn(1)

# Q: Reverse direction
func _effect_reverse(_card: Card) -> void:
	print("Effect: Reverse (Q)")
	log_message("Effect: Direction Reversed!")
	play_direction *= -1
	cycle_turn(1) # Move to next in new direction
	
# J: Wildcard with Suit Selection
func _effect_jack(_card: Card) -> void:
	print("Effect: Jack (Wildcard) - Choosing Suit")
	log_message("Player %d is choosing a suit..." % current_player)
	
	# Block input to prevent other players from playing prematurely
	discard_pile.input_disabled = true
	
	# Do NOT cycle turn yet. Wait for selection.
	
	var selector = suit_selector_scene.instantiate()
	# Add to HUD (CanvasLayer)
	if hud_layer:
		hud_layer.add_child(selector)
	else:
		print("ERROR: HUD Layer missing!")
		# Unblock if error
		discard_pile.input_disabled = false
		return
	
	selector.suit_selected.connect(_on_suit_selected)

func _on_suit_selected(suit: String) -> void:
	print("Suit Selected: ", suit)
	log_message("Player %d chose %s!" % [current_player, suit.capitalize()])
	
	# 1. Update Discard Pile Active Suit
	discard_pile.active_suit = suit
	
	# 2. Show Speech Bubble
	var bubble = speech_bubble_scene.instantiate()
	# add_child(bubble) # REMOVED: Don't add to manager directly
	# Let's put it in HUD but mapped to hand position, or just add to Hand node?
	# Adding to Hand node is easiest if Hand is a Control/Node2D.
	
	var current_hand = hands_array[current_player - 1]
	# current_hand is a Node2D (CardContainer). 
	# bubble is a Control. 
	# We can add bubble to the HUD and position it at the hand's screen position.
	if hud_layer:
		hud_layer.add_child(bubble)
		bubble.global_position = current_hand.get_global_transform_with_canvas().origin
		
		# Offset slightly
		bubble.global_position += Vector2(0, -100) # Above hand
		
		bubble.show_message("I choose " + suit.capitalize() + "!", 2.0)
	
	# 3. Wait 2 seconds then cycle turn
	await get_tree().create_timer(2.0).timeout
	cycle_turn(1)
	
	# Unblock input
	discard_pile.input_disabled = false

# 5 Diamond: Rotate hands Right (1 step)
func _effect_rotate_right_1(_card: Card) -> void:
	print("Effect: Rotate Hands Right (5D)")
	_rotate_hands_content(1)
	cycle_turn(1)

# 5 Heart: Rotate hands Left (2 steps)
func _effect_rotate_left_2(_card: Card) -> void:
	print("Effect: Rotate Hands Left 2 (5H)")
	_rotate_hands_content(-2) # Negative for left/counter-clockwise relative to array
	cycle_turn(1)

# Helper for rotation
func _rotate_hands_content(steps: int) -> void:
	# 1. Collect all cards from all hands
	var all_cards_content: Array[Array] = []
	for hand in hands_array:
		all_cards_content.append(hand._held_cards.duplicate())
	
	# 2. Redistribute based on shift
	for i in range(hands_array.size()):
		var target_hand_idx = (i + steps) % hands_array.size()
		# Handle negative modulo
		if target_hand_idx < 0:
			target_hand_idx += hands_array.size()
			
		var target_hand = hands_array[target_hand_idx]
		var cards_to_move = all_cards_content[i]
		
		# Move cards to this hand. move_cards handles removing from previous hand.
		target_hand.move_cards(cards_to_move)

# --- UI Setup ---
var hud_layer: CanvasLayer

func setup_ui() -> void:
	# Use member variable so we can access it later for effects
	hud_layer = CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	
	# canvas_layer = hud_layer # REMOVED: Redundant and caused scope error
	
	var top_bar = PanelContainer.new()
	# Height determined in setup_game (top_bar_height), need to ensure it's calculated before UI if we depend on it, 
	# but actually we can re-calculate or just use anchors.
	# Let's use custom_minimum_size with the value we already have or calculate it again.
	var screen_size = get_viewport().get_visible_rect().size
	# Recalculate if needed, but safe to assume it's set if setup_game runs first.
	# Actually, best to be explicit or use anchors percent!
	
	# Using set_anchors_and_offsets_preset to ensure changes apply
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	
	# Force the height to be exactly what we used for logic: screen_size.y * 0.05
	# PRESET_TOP_WIDE sets Top, Left, Right to 0. Bottom remains flexible.
	top_bar.custom_minimum_size = Vector2(0, screen_size.y * 0.05)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# Add Background Style (Dark Red)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.DARK_RED # Dark Red
	top_bar.add_theme_stylebox_override("panel", style_box)
	
	hud_layer.add_child(top_bar)
	
	var hbox = HBoxContainer.new()
	# hbox.anchors_preset = Control.PRESET_FULL_RECT # Can't use this directly inside container easily without layout mode
	# Container automatically arranges children.
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	top_bar.add_child(hbox)
	
	# Add Player Names
	player_labels.clear()
	for i in range(1, num_players + 1):
		var label = Label.new()
		label.text = "Player " + str(i)
		# Add outline to make text pop against dark red
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		hbox.add_child(label)
		player_labels.append(label)
		
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer)
	
	# Pass Turn Button
	var pass_btn = Button.new()
	pass_btn.text = "Pass Turn"
	pass_btn.pressed.connect(_on_pass_turn_pressed)
	hbox.add_child(pass_btn)
	
	# --- Game Log UI ---
	var log_panel = PanelContainer.new()
	# Position below top bar
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	log_panel.position.y = top_bar.custom_minimum_size.y
	log_panel.custom_minimum_size = Vector2(300, 150)
	
	# Semi-transparent background
	var log_bg = StyleBoxFlat.new()
	log_bg.bg_color = Color(0, 0, 0, 0.5)
	log_bg.content_margin_left = 10
	log_bg.content_margin_top = 10
	log_bg.content_margin_right = 10
	log_bg.content_margin_bottom = 10
	log_panel.add_theme_stylebox_override("panel", log_bg)
	
	hud_layer.add_child(log_panel)
	
	game_log_label = RichTextLabel.new()
	game_log_label.scroll_following = true
	game_log_label.text = "[b]Game Log Started[/b]"
	log_panel.add_child(game_log_label)
	
	update_player_stats()

var game_log_label: RichTextLabel

func log_message(text: String) -> void:
	if game_log_label:
		game_log_label.text += "\n" + text
		# Optional: Prune old lines if too long? For now let it scroll.
		
func update_player_stats() -> void:
	if player_labels.size() != hands_array.size():
		return # Mismatch or not ready
		
	for i in range(hands_array.size()):
		var count = hands_array[i].get_card_count()
		var p_index = i + 1
		player_labels[i].text = "Player %d (%d)" % [p_index, count]

func _on_pass_turn_pressed() -> void:
	print("Pass Turn Pressed")
	cycle_turn()
