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
var effect_status_bar: EffectStatusBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_register_card_effects()
	setup_game()
	setup_ui()

var top_bar_height: float = 0.0

func setup_game() -> void:
	# Initialize player count from Globals
	num_players = GameGlobals.num_players
	print("Starting game with ", num_players, " players.")
	
	var screen_size = get_viewport().get_visible_rect().size
	
	# Calculate Top Bar Height (5% of screen)
	top_bar_height = screen_size.y * 0.05
	
	# Define available play area below the top bar
	var available_rect = Rect2(0, top_bar_height, screen_size.x, screen_size.y - top_bar_height)
	var center_point = available_rect.get_center()

	# --- Dynamic Scaling for Crowded Tables ---
	var global_scale_factor = Vector2.ONE
	if num_players >= 8:
		# User requested scaling for 8+ players to avoid crowding
		# "Move Camera Back" effect = Scale Down Everything
		global_scale_factor = Vector2(0.75, 0.75)
		print("Large table detected (" + str(num_players) + " players). Scaling elements by 0.75x")

	# 1. Instantiate and Shuffle Deck
	deck = deck_scene.instantiate()
	deck.name = "Deck"
	card_manager.add_child(deck)
	
	# Configure Deck
	deck.stack_direction = Pile.PileDirection.CENTER 
	deck.card_face_up = false
	deck.allow_card_movement = false 
	deck.scale = global_scale_factor # Apply Scaler.add_child(deck)
	
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
	discard_pile.scale = global_scale_factor # Apply Scale
	card_manager.add_child(discard_pile)
	
	# Position Discard Pile (Center Right of available area)
	discard_pile.position = center_point + (base_offset_discard * layout_scale)
	
	# Note: Signal connection moved to AFTER initial deal to prevent first card from triggering turns/effects
	
	
	
	# 3. Instantiate Hands with positioning
	for player in range(num_players):
		var hand = hand_scene.instantiate()
		hands_array.append(hand)
		
		# Apply Scale
		hand.scale = global_scale_factor
		
		card_manager.add_child(hand)
		
		# Configure Hand
		hand.max_hand_spread = 400
		hand.card_face_up = true # DEBUG: All cards face up
		#if player == 0:
		#	hand.card_face_up = true
		#else:
		#	hand.card_face_up = false # Opponent cards face down
			
		# Position Hands (Dynamic Layout)
		var transform_data = _get_hand_transform(player, num_players, center_point, screen_size)
		
		hand.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		hand.position = transform_data["position"]
		hand.rotation = transform_data["rotation"]
		
		# Adjust card rotations for side players if needed (cleanup previous)
		for card in hand._held_cards:
			card.rotation_degrees = 0
			# If hand is rotated 90 or 270 (Left/Right), we might typically rotate cards?
			# But if the entire Hand node is rotated, the cards rotate with it.
			# Previous logic had "card.rotation_degrees -= 90".
			# Let's rely on Node rotation first. If visuals are odd, we can revisit.
			pass
			
		# Correction for visual "facing":
		# The Hand script arranges cards along X axis.
		# If Hand is rotated, X axis rotates.
		# So cards should align naturally along the table edge.
		# However, for Left/Right players, the cards might look "sideways" if we don't counter-rotate?
		# Let's stick to Node rotation: It represents the player's perspective.
		
		# Fix for Right Player (Index 3 in 4-player):
		# Previous logic: rotation 270. card rotation -90.
		# If we just rotate Hand 270, cards are sideways pointing IN.
		# That seems correct for a "sitting at table" view.
				
	# 4. Randomize first player (Default)
	current_player = (randi() % num_players) + 1
	print("Randomly selected start player: ", current_player)

	# 5. Run Debug Scenarios (Overrides Random Player & Pre-seeds Cards)
	_run_debug_scenarios()

	# 6. Deal Initial Cards (Fills remainder)
	deal_initial_cards()
	
	# 7. Start Game (First card to discard)
	var initial_card = deck.get_top_cards(1)
	if not initial_card.is_empty():
		discard_pile.move_cards(initial_card)

	# Connect Signal NOW, after initial card is placed
	if not discard_pile.card_played.is_connected(_on_card_played):
		discard_pile.card_played.connect(_on_card_played)
		print("DEBUG: Manager connected to DiscardPile signal (Post-Setup).")

	# 8. Current Player UI
	player_label = Label.new()
	card_manager.add_child(player_label)
	# Position relative to deck, which is already correctly positioned in available area
	player_label.position = deck.position + (base_offset_label * layout_scale) 
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	update_turn_ui()
	update_player_stats()

var play_direction: int = 1 # 1 for clockwise, -1 for counter-clockwise
var last_player_who_played: int = -1
var pending_turn_skip: int = 1 # Default to 1 (Next player). Joker sets this to 2 (Skip).
var active_effects: Dictionary = {
	"locked": false,          # Spade 4
	"eight_black": false,     # Black 8s
	"eight_red": false,       # Red 8s
}

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

# Modified to fill hands up to the limit, allowing for pre-seeded debug cards
func deal_initial_cards() -> void:
	
	# Round-robin deal until everyone has 'num_cards_in_hand'
	var cards_needed = true
	while cards_needed:
		cards_needed = false
		for player_hand in hands_array:
			if player_hand._held_cards.size() < num_cards_in_hand:
				cards_needed = true
				var card_array = deck.get_top_cards(1)
				if card_array.is_empty():
					push_warning("Deck empty during initial deal!")
					return
				player_hand.move_cards(card_array)

# --- Debug Helpers ---

func _run_debug_scenarios() -> void:
	# pass
	# Example: Give Player 1 (Index 0) a Heart 9
	# debug_move_card_to_hand(0, "heart_9")
	# debug_move_card_to_hand(1, "club_A")
	# debug_move_card_to_hand(0,"heart_9")
	# debug_move_card_to_hand(0,"club_9")
	# debug_move_card_to_hand(0,"spade_9")
	# debug_move_card_to_hand(0,"diamond_9")
	
	debug_move_card_to_hand(0, "joker")
	debug_move_card_to_hand(0, "club_2")
	
	debug_set_starting_player(0)

func debug_set_starting_player(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= num_players:
		printerr("Debug Error: Invalid starting player index ", player_idx)
		return
	
	# Convert 0-based index to 1-based logic used by game
	current_player = player_idx + 1
	print("DEBUG: Force starting player to: ", current_player)
	update_turn_ui()

func debug_move_card_to_hand(player_idx: int, card_name: String) -> void:
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
			# Add a small delay/tween here if we wanted visuals, but logic is instant for now
		
func populate_deck() -> void:
	var card_data = card_manager.card_factory.preloaded_cards
	if card_data.is_empty():
		push_error("No cards preloaded! Check CardFactory configuration.")
		return
		
	for card_name in card_data.keys():
		# Include all cards found in factory
			
			
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
		# RULE: If effects are blocked (Spade 4), only Red 4s can trigger their effect (Unlock).
		if active_effects["locked"]:
			if card.card_name.begins_with("heart_4") or card.card_name.begins_with("diamond_4"):
				print("DEBUG: Effect Dispatch: Red 4 Unblocker!")
				card_effects[card.card_name].call(card)
			else:
				print("DEBUG: Effect Dispatch: BLOCKED by Spade 4!")
				log_message("Effect BLOCKED by Spade 4!")
				_effect_default(card) # Just cycle turn, no effect
		else:
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
	card_effects["joker"] = _effect_joker
	
	card_effects["club_4"] = _effect_club_4
	card_effects["spade_4"] = _effect_spade_4
	card_effects["heart_4"] = _effect_red_4
	card_effects["diamond_4"] = _effect_red_4
	
	# Register 8s
	# Black 8s
	card_effects["club_8"] = _effect_eight_black
	card_effects["spade_8"] = _effect_eight_black
	# Red 8s
	card_effects["heart_8"] = _effect_eight_red
	card_effects["diamond_8"] = _effect_eight_red

	# Register all 2s for Double Play
	for suit in suits:
		card_effects[suit + "_2"] = _effect_play_again

# Default effect: just pass the turn
func _effect_default(_card: Card) -> void:
	cycle_turn(1)

# --- Effect Handlers ---

# 2: Double Play (Play again)
func _effect_play_again(_card: Card) -> void:
	print("Effect: Double Play (2)")
	log_message("Player %d plays again! (Any Card)" % current_player)
	
	# Enable Free Play for the follow-up card
	discard_pile.free_play_active = true
	
	# Update HUD (Maybe add an icon for "Free Play" later)
	_update_hud_effects()
	
	# Do NOT cycle turn.
	# Visual feedback
	if hud_layer:
		var bubble = speech_bubble_scene.instantiate()
		hud_layer.add_child(bubble)
		var current_hand = hands_array[current_player - 1]
		bubble.global_position = current_hand.get_global_transform_with_canvas().origin + Vector2(0, -100)
		bubble.show_message("I play again!", 1.5)
	
	# TODO: Check if player has NO cards left (win) or NO valid cards (draw).
	# Win check happens elsewhere usually check_win_condition().
	# If he has no valid cards, he must draw. Logic to be enforced by player interaction.

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
	
	_update_hud_effects()
	
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
	
	# Cycle turn by pending amount (1 for Jack, 2 for Joker)
	cycle_turn(pending_turn_skip)
	# Reset back to default
	pending_turn_skip = 1
	
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

# Joker: Draw 4 + Skip + Choose Suit
func _effect_joker(_card: Card) -> void:
	print("Effect: Joker (Apocalypse)")
	log_message("Joker played! Next +4, Skip, Suit Select!")
	
	# 1. Next player draws 4
	var next_player_idx = get_next_player_index(1)
	var next_hand = hands_array[next_player_idx - 1]
	distribute_cards(next_hand, 4)
	
	# 2. Skip that player (so turn moves to Player+2)
	# BUT we also need to select a suit. 
	# Effect Jack does NOT cycle turn immediately. It waits for UI.
	# We should do the same here.
	
	# Pre-calculate the NEXT turn cycle to be +2 (Skip)
	# But _on_suit_selected cycles by 1.
	# We can update a flag or just handle it differently.
	# Easier: Let's reuse logic.
	# We can override _on_suit_selected behavior? No.
	
	# Let's initiate suit selection first.
	_effect_jack(_card)
	
	# However, _effect_jack calls cycle_turn(1) at the end of selection.
	# We want cycle_turn(2).
	# This implies we need a state variable "pending_turn_skip".
	pending_turn_skip = 2 # Set to 2 so when suit is selected, we skip.

# Club 4: Clears Active Effects (8s, Kings, Queens/Direction)
# DOES NOT clear Spade 4 Lock.
# DOES NOT clear Jack/Joker Active Suit.
func _effect_club_4(_card: Card) -> void:
	print("Effect: Clear Active Effects (Club 4)")
	log_message("Effects Cleared (8s, Direction)")
	
	# Clear 8s Masquerade
	active_effects["eight_black"] = false
	active_effects["eight_red"] = false
	discard_pile.active_effect_eight_black = false
	discard_pile.active_effect_eight_red = false
	
	# Clear Direction (Queen Effect) - Reset to Clockwise
	play_direction = 1
	
	# Clear Silence (King Effect - Future)
	# active_effects["silenced"] = false
	
	_update_hud_effects()
	cycle_turn(1)

# Spade 4: Locks Effects (Only Red 4s can unlock)
func _effect_spade_4(_card: Card) -> void:
	print("Effect: LOCK Effects (Spade 4)")
	log_message("Effects are now LOCKED!")
	active_effects["locked"] = true
	_update_hud_effects()
	cycle_turn(1)

# Red 4: Unlocks Effects
func _effect_red_4(_card: Card) -> void:
	print("Effect: UNLOCK Effects (Red 4)")
	if active_effects["locked"]:
		log_message("Effects are now UNLOCKED!")
		active_effects["locked"] = false
	else:
		log_message("Red 4 played (Nothing locked).")
	_update_hud_effects()
	cycle_turn(1)
	
# 8 Black: Toggle Black Masquerade
func _effect_eight_black(_card: Card) -> void:
	print("Effect: 8 Black (Masquerade)")
	log_message("Black 8! Black cards swap suits!")
	
	# Toggle state (or set true? Usually it applies until cleared?)
	# Rule says: "Once played, the black cards on top count as opposite."
	# This implies it's a persistent state.
	active_effects["eight_black"] = true
	discard_pile.active_effect_eight_black = true
	
	_update_hud_effects()
	cycle_turn(1)

# 8 Red: Toggle Red Masquerade
func _effect_eight_red(_card: Card) -> void:
	print("Effect: 8 Red (Masquerade)")
	log_message("Red 8! Red cards swap suits!")
	
	active_effects["eight_red"] = true
	discard_pile.active_effect_eight_red = true
	
	_update_hud_effects()
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
	
	# Spacer Left (to balance Right spacer and center content)
	var spacer_left = Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_left)
	
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
	
	# --- Effect Status Bar (Bottom Center) ---
	# Load script directly since we don't have a scene file yet, or use class_name
	effect_status_bar = EffectStatusBar.new()
	hud_layer.add_child(effect_status_bar)
	
	# Calculate Max Height (10% of screen)
	var bar_height = screen_size.y * 0.10
	var bar_width = screen_size.x * 0.2 # 20% Width (Reduced from 40%)
	
	# Position: Bottom Left
	effect_status_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	effect_status_bar.grow_horizontal = Control.GROW_DIRECTION_END # Grow Right
	effect_status_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN # Grow Up
	
	# Explicit Offsets
	var margin_side = 20.0
	var margin_bottom = 20.0
	
	effect_status_bar.offset_left = margin_side
	effect_status_bar.offset_right = margin_side + bar_width
	effect_status_bar.offset_bottom = -margin_bottom
	effect_status_bar.offset_top = -margin_bottom - bar_height
	
	# Size Constraints
	effect_status_bar.custom_minimum_size = Vector2(bar_width, bar_height) # Force Min size
	
	# Initialize
	_update_hud_effects()
	
	# Spacer Right
	var spacer_right = Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer_right)
	
	# Settings/Gear Button
	var settings_btn = Button.new()
	settings_btn.text = "⚙" # Gear emoji as icon for now
	settings_btn.pressed.connect(_on_settings_pressed)
	hbox.add_child(settings_btn)
	
	# Spacer End
	var spacer_end = Control.new()
	spacer_end.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(spacer_end)
	
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
	
	# --- Options Menu UI ---
	_setup_options_menu()
	
	update_player_stats()

var game_log_label: RichTextLabel
var options_menu: PanelContainer

func _setup_options_menu() -> void:
	options_menu = PanelContainer.new()
	options_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options_menu.visible = false # Hidden default
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 20
	style.content_margin_top = 20
	style.content_margin_right = 20
	style.content_margin_bottom = 20
	options_menu.add_theme_stylebox_override("panel", style)
	
	hud_layer.add_child(options_menu)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	options_menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var btn_quit = Button.new()
	btn_quit.text = "Quit Game"
	btn_quit.pressed.connect(_on_quit_game_pressed)
	vbox.add_child(btn_quit)
	
	var btn_ops = Button.new()
	btn_ops.text = "Options"
	btn_ops.pressed.connect(_on_options_pressed)
	vbox.add_child(btn_ops)
	
	var btn_close = Button.new()
	btn_close.text = "Close Window"
	btn_close.pressed.connect(_on_close_menu_pressed)
	vbox.add_child(btn_close)

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

func _update_hud_effects() -> void:
	if effect_status_bar:
		var current_suit = ""
		if discard_pile:
			current_suit = discard_pile.active_suit
		effect_status_bar.update_status(active_effects, current_suit)
		
# --- Options Menu Callbacks ---
func _on_settings_pressed() -> void:
	if options_menu:
		options_menu.visible = !options_menu.visible
		# Optional: Pause game? 
		# get_tree().paused = options_menu.visible

func _on_quit_game_pressed() -> void:
	print("Quit Game Pressed")
	# Switch to Main Menu
	get_tree().change_scene_to_file("res://Maumau/MainMenu.tscn")

func _on_options_pressed() -> void:
	print("Options Pressed placeholder")

func _on_close_menu_pressed() -> void:
	if options_menu:
		options_menu.visible = false

# --- Dynamic Layout Helper ---
func _get_hand_transform(player_idx: int, total_players: int, center: Vector2, screen_size: Vector2) -> Dictionary:
	var result = {"position": Vector2.ZERO, "rotation": 0.0, "face_up": false}
	var scaled_padding = base_padding_hand * layout_scale
	
	# Default: Face center(ish) but we handle specifics per case
	
	if total_players <= 4:
		# Specific Fixed Layouts
		match total_players:
			1: # Just Bottom
				result.position = Vector2(center.x, screen_size.y - scaled_padding)
				result.rotation = 0
				result.face_up = true
			2: # Bottom, Top
				if player_idx == 0: # Bottom
					result.position = Vector2(center.x, screen_size.y - scaled_padding)
					result.rotation = 0
					result.face_up = true
				else: # Top
					result.position = Vector2(center.x, top_bar_height + scaled_padding + 50) 
					result.rotation = deg_to_rad(180)
			3: # Bottom, Left, Top
				match player_idx:
					0: # Bottom
						result.position = Vector2(center.x, screen_size.y - scaled_padding)
						result.rotation = 0
						result.face_up = true
					1: # Left
						result.position = Vector2(scaled_padding, center.y)
						result.rotation = deg_to_rad(90)
					2: # Top
						result.position = Vector2(center.x, top_bar_height + scaled_padding + 50)
						result.rotation = deg_to_rad(180)
			4: # Bottom, Left, Top, Right
				match player_idx:
					0: # Bottom
						result.position = Vector2(center.x, screen_size.y - scaled_padding)
						result.rotation = 0
						result.face_up = true
					1: # Left
						result.position = Vector2(scaled_padding, center.y)
						result.rotation = deg_to_rad(90)
					2: # Top
						result.position = Vector2(center.x, top_bar_height + scaled_padding + 50)
						result.rotation = deg_to_rad(180)
					3: # Right
						result.position = Vector2(screen_size.x - scaled_padding, center.y)
						result.rotation = deg_to_rad(270)
	else:
		# 5+ Players: Ellipse Distribution
		# P0 is always bottom (90 degrees in math terms if 0 is right? No, Godot 0 degrees is Right, 90 is Down)
		# Let's map indexes to angles.
		# We want P0 at 90 deg (Bottom).
		# We want P1, P2... distributed clockwise? Or Counter-Clockwise?
		# Standard table dealing is usually clockwise (Left player is next).
		
		var rx = (screen_size.x / 2.0) - scaled_padding
		var ry = (screen_size.y / 2.0) - scaled_padding - (top_bar_height/2)
		
		# Angle step
		var angle_step = (PI * 2) / total_players
		
		# Start angle: P0 at Bottom (PI/2 or 90 deg)
		var current_angle = PI / 2.0 + (player_idx * angle_step)
		
		# Calculate Position on Ellipse
		# x = center.x + rx * cos(angle)
		# y = center.y + ry * sin(angle)
		result.position = Vector2(
			center.x + rx * cos(current_angle),
			center.y + ry * sin(current_angle)
		)
		
		# Rotation: Card "bottom" should face OUTWARDS or INWARDS?
		# Usually Hand connects to screen edge. 
		# Rotation = Angle - 90 deg (PI/2) seems standard so "Up" vector points to center?
		# Let's try: Look at center.
		# Godot Sprite: Right is 0. Down is 90.
		# If at Bottom (90deg), valid rotation is 0. (90 - 90 = 0).
		# If at Top (270deg), valid rotation is 180. (270 - 90 = 180).
		# So: rotation = angle - PI/2
		result.rotation = current_angle - (PI / 2.0)
		
		# Logic for face up: Only local player?
		result.face_up = (player_idx == 0)

	return result
