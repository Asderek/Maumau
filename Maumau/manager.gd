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
@export var simon_popup_scene: PackedScene = preload("res://Maumau/simon_says_popup.tscn")

# UI Scenes for Effects
var suit_selector_scene: PackedScene = preload("res://Maumau/suit_selector.tscn")
var speech_bubble_scene: PackedScene = preload("res://Maumau/speech_bubble.tscn")
var die_scene: PackedScene = preload("res://Maumau/die.tscn")
var simon_popup: Control

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
		
		# Set Interaction Mode based on Jump-In Rule
		hand.allow_remote_interaction = GameGlobals.is_rule_active("jump_in")
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
	# Only if not already set by debug
	if discard_pile.get_card_count() == 0:
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
# History of last 3 plays: [{ "card_name": String, "player": int, "card_ref": Card }]
var play_history: Array = [] 
# Rule 666 State
var devil_awakened: bool = false
# Rule 10 (Simon Says) State
var word_chain: Array[String] = []
var simon_dict_mode: String = "PT" # or "EN"
var dict_en: Array[String] = ["Rat", "Car", "Dog", "Bus", "Sky", "Tea", "Cup", "Box", "Fox", "Bat", "Hat", "Sun", "Moon", "Run", "Fun", "Eat", "Cat", "Cow", "Pig", "Hen", "Pen", "Map", "Key", "Egg", "Pie"]
var dict_pt: Array[String] = ["Pao", "Sol", "Lua", "Flor", "Ceu", "Mar", "Rio", "Luz", "Cor", "Som", "Sal", "Mao", "Pe", "Dor", "Fim", "Sim", "Nao", "Voz", "Paz", "Gol", "Trem", "Boi", "Cao", "Lar", "Mel"]

var pending_turn_skip: int = 1 # Default to 1 (Next player). Joker sets this to 2 (Skip).
var active_effects: Dictionary = {
	"locked": false,          # Spade 4
	"eight_black": false,     # Black 8s
	"eight_red": false,       # Red 8s
	"silence": false          # King (The Silence)
}
# Stacking Penalties
var pending_penalty: int = 0
var penalty_type: String = "" # "7" or "joker"

var turn_counter: int = 1

func _print_game_event(action: String, details: String = "") -> void:
	print("Turn %d | Player %d: %s %s" % [turn_counter, current_player, action, details])


var selected_card_index = 0

func _process(_delta: float) -> void:
	# Handle highlights every frame
	if GameGlobals.show_play_highlights:
		handle_highlight()
	else:
		# Ensure highlights are cleared if disabled
		# (Though a full clear might be needed if toggled during play. 
		# For now, relying on handle_highlight clearing them if condition fails or just initial state)
		# Improved: Force clear if we toggle it off?
		# Let's just not run the logic. If it was active, it might stick?
		# Proper way: If disabled, we should run a "clear all highlights" once.
		# For simplicity: handle_highlight() manages states. If disabled, we rely on the fact they default to false?
		# Actually, if we stop calling it, the last state persists.
		# BETTER: Call handle_highlight but pass a flag? Or modifying handle_highlight internally?
		# Let's modify handle_highlight to check the global itself.
		handle_highlight() # It will check inside.
	
	if hands_array.size() <= 1: return
	
	# Cycle Turn (Space)
	if Input.is_action_just_pressed("ui_accept"): 
		cycle_turn(1, false)

# ... (cycle_turn, etc) ...

func update_turn_ui() -> void:
	# ...
	for i in range(hands_array.size()):
		var hand = hands_array[i]
		var is_current = (i == current_player - 1)
		
		# Logic: Enable input for current player
		hand.set_active(is_current)
		
		# Visual: Highlight if enabled in options
		if is_current and GameGlobals.show_current_player_highlight:
			hand.set_highlight(true)
		else:
			hand.set_highlight(false) 


# ...

func _update_hud_effects() -> void:
	if effect_status_bar:
		if GameGlobals.show_effect_status_bar:
			effect_status_bar.visible = true
			effect_status_bar.visible = true
			effect_status_bar.update_status(active_effects, play_direction)
		else:
			effect_status_bar.visible = false

# ...

func handle_highlight() -> void:
	# 1. Reset helper highlight on discard pile
	if discard_pile:
		for card in discard_pile._held_cards:
			card.set_helper_display(false)
			
	if deck:
		for card in deck._held_cards:
			card.set_helper_display(false)

	# Check Global Highlight Setting
	if not GameGlobals.show_play_highlights:
		return # Exit after clearing.

	# Check if any card is currently being dragged (held)
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


func cycle_turn(steps: int = 1, played_card: bool = false) -> void:
	# Update last player ONLY if they played a card (passed turns don't count)
	if played_card:
		last_player_who_played = current_player
	
	# Calculate new player index with direction
	var new_index = current_player + (steps * play_direction)
	
	# Wrap around logic (1-based index)
	while new_index > num_players:
		new_index -= num_players
	while new_index < 1:
		new_index += num_players
		
	current_player = new_index
	turn_counter += 1
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

func _on_deck_card_pressed(_card: Card) -> void:
	# Check if it is current player's turn (handled by UI input block mostly, but safeguard)
	# For now assuming UI handles turn blocking.
	
	var current_hand = hands_array[current_player - 1]
	
	# Penalty Logic
	if pending_penalty > 0:
		_print_game_event("ACCEPTS PENALTY", "Draws " + str(pending_penalty) + " cards (" + penalty_type + ")")
		log_message("Player %d accepts penalty! Draws %d cards." % [current_player, pending_penalty])
		distribute_cards(current_hand, pending_penalty)
		
		# Reset Penalty
		pending_penalty = 0
		penalty_type = ""
		discard_pile.pending_penalty = 0
		discard_pile.penalty_type = ""
		
		# Skip Turn (Penalty for not stacking)
		cycle_turn(1) # Wait, is it Skip (2) or just End Turn (1)?
		# Rule says: "sending to the next player. So the result is player 3 draws 4 and skips."
		# This usually means the player drawing loses their turn.
		# If I draw, my turn ends. The NEXT player plays.
		# So cycle_turn(1).
		return
	
	# Normal Draw
	distribute_cards(current_hand, 1)
	
	# After drawing, check if player can play? 
	# Usually MauMau allows playing the drawn card if valid.
	# Or pass immediately?
	# Implementation: Let them play.
	# (No cycle_turn here, player must choose to pass or play)
	
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
	# Use new separated Debug Scenarios script
	var debug_sys = DebugScenarios.new()
	debug_sys.run_debug_scenarios(self)

# Inline debug helpers removed. See debug_scenarios.gd
		
func populate_deck() -> void:
	var card_data = card_manager.card_factory.preloaded_cards
	if card_data.is_empty():
		push_error("No cards preloaded! Check CardFactory configuration.")
		return
		
	for i in range(2): # Double Deck
		for card_name in card_data.keys():
			# Include all cards found in factory
			var card = card_manager.card_factory.create_card(card_name, deck)
			if card == null:
				push_error("Failed to create card: " + card_name)
			else:
				# Connect King Rule Signal
				if not card.drag_started.is_connected(_on_card_drag_started):
					card.drag_started.connect(_on_card_drag_started)

	print("Deck populated with ", deck.get_card_count(), " cards (Double Deck).")




func _on_card_played(card: Card, player_source_index: int = -1) -> void:
	_print_game_event("Plays Card", card.card_name)
	
	# Detect Jump-In (Out of Turn Play)
	var is_jump_in = false
	if player_source_index != -1 and player_source_index != current_player:
		is_jump_in = true
		print("DEBUG: JUMP-IN DETECTED! Player ", player_source_index, " stole the turn from ", current_player)
		log_message("!!! PLAYER %d JUMPED IN !!!" % player_source_index)
		current_player = player_source_index
		
	# Optionally: Add visual flair here
		# ...
	
	# --- Update Play History (Last 3 Cards) ---
	var history_player = current_player
	if player_source_index != -1:
		history_player = player_source_index
		
	var play_event = {
		"card": card,
		"card_name": card.card_name,
		"player": history_player
	}
	play_history.append(play_event)
	if play_history.size() > 3:
		play_history.pop_front()
		
	print("DEBUG: History Updated: ", play_history.map(func(x): return str(x.player) + ":" + x.card_name))

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
	card_effects.clear() # Clear existing effects for rebuild
	
	# Generic rules by value
	var suits = ["club", "diamond", "heart", "spade"]
	var special_values = ["A", "7", "9", "Q", "J", "6", "10", "K"]
	
	for suit in suits:
		for value in special_values:
			var card_name = suit + "_" + value
			
			# Check Global Rule
			if not GameGlobals.is_rule_active(value):
				continue # Skip registration (Effect defaults to Pass)
			
			match value:
				"A": card_effects[card_name] = _effect_skip
				"7": card_effects[card_name] = _effect_draw_2_skip
				"9": card_effects[card_name] = _effect_draw_last_player
				"Q": card_effects[card_name] = _effect_reverse
				"J": card_effects[card_name] = _effect_jack
				"6": card_effects[card_name] = _effect_six
				"10": card_effects[card_name] = _effect_ten
				"K": card_effects[card_name] = _effect_king
				
	# Specific rules by name
	if GameGlobals.is_rule_active("5"):
		card_effects["diamond_5"] = _effect_rotate_right_1
		card_effects["heart_5"] = _effect_rotate_left_2
	
	# Jokers
	if GameGlobals.is_rule_active("joker"):
		card_effects["joker_red"] = _effect_joker
		card_effects["joker_black"] = _effect_joker
	
	# 4s (Lock & Unlock)
	if GameGlobals.is_rule_active("4"):
		card_effects["club_4"] = _effect_club_4
		card_effects["spade_4"] = _effect_spade_4
		card_effects["heart_4"] = _effect_red_4
		card_effects["diamond_4"] = _effect_red_4
	
	# Register 8s
	if GameGlobals.is_rule_active("8"):
		# Black 8s
		card_effects["club_8"] = _effect_eight_black
		card_effects["spade_8"] = _effect_eight_black
		# Red 8s
		card_effects["heart_8"] = _effect_eight_red
		card_effects["diamond_8"] = _effect_eight_red

	# Register all 2s for Double Play
	if GameGlobals.is_rule_active("2"):
		for suit in suits:
			card_effects[suit + "_2"] = _effect_play_again
			
	# --- Update Interaction based on Jump-In Rule ---
	# If Jump-In is enabled, players must be able to drag cards out of turn.
	var jump_in_active = GameGlobals.is_rule_active("jump_in")
	if hands_array:
		for hand in hands_array:
			hand.allow_remote_interaction = jump_in_active
			# If interaction was disabled by set_active(false), this override re-enables it.

# Default effect: just pass the turn
# Default effect: just pass the turn
func _effect_default(_card: Card) -> void:
	cycle_turn(1, true)


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
# K: The Silence (King)
func _effect_king(_card: Card) -> void:
	print("Effect: King (Silence)")
	
	if active_effects["silence"]:
		log_message("The King speaks! Silence is broken.")
		active_effects["silence"] = false
		_update_hud_effects()
		if hud_layer:
			var bubble = speech_bubble_scene.instantiate()
			hud_layer.add_child(bubble)
			bubble.global_position = hands_array[current_player - 1].get_global_transform_with_canvas().origin + Vector2(0, -100)
			bubble.show_message("Speak freely!", 2.0)
	else:
		log_message("The King commands SILENCE!")
		active_effects["silence"] = true
		_update_hud_effects()
		if hud_layer:
			var bubble = speech_bubble_scene.instantiate()
			hud_layer.add_child(bubble)
			bubble.global_position = hands_array[current_player - 1].get_global_transform_with_canvas().origin + Vector2(0, -100)
			bubble.show_message("Silence!", 2.0)
			
	cycle_turn(1)

func _on_card_drag_started(card: Card) -> void:
	if not active_effects["silence"]:
		return
		
	# Verify if move is valid
	var can_play = discard_pile._card_can_be_added([card])
	
	if not can_play:
		print("SILENCE BROKEN! Invalid drag attempt.")
		log_message("Silence Broken! Penalty: 2 Cards.")
		
		# Cancel Drag and Snap Back
		card.change_state(Card.DraggableState.IDLE)
		card.position = card.original_position
		card.rotation = card.original_hover_rotation
		card.scale = card.original_scale
		
		# Apply Penalty
		# Target is the owner of the card.
		# card.card_container should be the Hand.
		var owner_hand = card.card_container
		if owner_hand is Hand:
			distribute_cards(owner_hand, 2)
		else:
			# Fallback if weird parenting
			distribute_cards(hands_array[current_player - 1], 2)

# 7: Next player draws 2 (Stackable)
func _effect_draw_2_skip(_card: Card) -> void:
	_print_game_event("Effect Triggered", "Stacking 7 (+2)")
	log_message("Effect: +2 Cards! Stack or Draw!")
	
	pending_penalty += 2
	penalty_type = "7"
	
	# Sync failure to pile
	discard_pile.pending_penalty = pending_penalty
	discard_pile.penalty_type = penalty_type
	
	# Do NOT draw immediate. Do NOT skip immediate.
	# Pass control to next player to respond.
	cycle_turn(1, true)

# 9: Last player who played draws 1
# 9: Last player who played draws 1 (Stacking allowed via History)
func _effect_draw_last_player(_card: Card) -> void:
	print("Effect: Last Player Draws (9)")
	
	if play_history.size() < 2:
		print("History too short to apply Rule 9.")
		cycle_turn(1)
		return

	# 1. Calculate Stacking Streak
	# Count how many contiguous 9s are at the end of history
	var streak = 0
	for i in range(play_history.size() - 1, -1, -1):
		var hist_card_name = play_history[i].card_name
		if "9" in hist_card_name: # Simple check for rank 9
			streak += 1
		else:
			break
			
	var amount_to_draw = streak
	
	# 2. Identify Target
	# The target is likely the player of the PREVIOUS card in history.
	# Example: [P1:5, P2:9 (Current)]. Target P1. Amount 1.
	# Example: [P1:5, P2:9, P4:9 (Current)]. Target P2. Amount 2.
	
	# EXCEPTION: Self-Doubling (P2 plays 9, then P2 jumps in with 9)
	# Logic: [P1:5, P2:9, P2:9]. 
	# Default logic would target P2 (index -2). This is self-punishment.
	# User Rule: In this case, target P1 (index -3).
	
	var target_index_in_history = play_history.size() - 2
	
	if play_history.size() >= 2:
		var last_player_idx = play_history[play_history.size() - 1].player
		var prev_player_idx = play_history[play_history.size() - 2].player
		
		# Check for Self-Double (Same player played last 2 cards)
		if last_player_idx == prev_player_idx and "9" in play_history[play_history.size() - 1].card_name:
			# Self-Double Detected involving current card
			target_index_in_history = play_history.size() - 3
			print("DEBUG: Self-Doubling 9 detected! Redirecting target to history[-3].")

	if target_index_in_history < 0:
		print("History too short for Rule 9 target calculation (Start of Game?).")
		cycle_turn(1)
		return

	var target_entry = play_history[target_index_in_history]
	var target_player_idx = target_entry.player
	
	log_message("Effect: Player %d draws %d card(s)! (Rule 9)" % [target_player_idx, amount_to_draw])
	
	var target_hand = hands_array[target_player_idx - 1]
	distribute_cards(target_hand, amount_to_draw)
	
	cycle_turn(1)

# 6: Rule 666 (Mark of the Beast)
func _effect_six(_card: Card) -> void:
	print("Effect: Check 666")
	
	var beast_summoned = false
	var authors = {}
	if play_history.size() >= 3:
		# Check last 3 cards
		var h1 = play_history[play_history.size() - 1]
		var h2 = play_history[play_history.size() - 2]
		var h3 = play_history[play_history.size() - 3]
		
		var c1 = h1.card_name
		var c2 = h2.card_name
		var c3 = h3.card_name
		
		if "6" in c1 and "6" in c2 and "6" in c3:
			beast_summoned = true
			authors[h1.player] = true
			authors[h2.player] = true
			authors[h3.player] = true
			
	if beast_summoned:
		_print_game_event("Effect Triggered", "666 COMPLETED!")
		
		# --- Phase 2: The Demon is Summoned (Game Over) ---
		if devil_awakened:
			log_message("!!! 666 - THE DEMON IS SUMMONED !!!")
			log_message("!!! GAME OVER - THE DEMON WINS !!!")
			#if Alert: Alert.text = "GAME OVER: DEMON WINS"
			# Stop game state/input?
			# For now, just a major log event.
			return
			
		# --- Phase 1: The Devil Awakens ---
		log_message("!!! 666 - THE DEVIL AWAKENS !!!")
		devil_awakened = true
		
		# 1. Remove Top 3 Cards (The 6s) from the game
		discard_pile.remove_top_cards(3)
		log_message("The 3 Sixes are consumed by the void...")
		
		# 2. Identify Victims
		var victims = []
		for p_idx in range(1, num_players + 1):
			if not authors.has(p_idx):
				victims.append(hands_array[p_idx - 1])

		# Fallback: Everyone suffers if all participated
		if victims.is_empty():
			log_message("All are sinners! The spoils effectively vanish (or go to everyone).")
			# User said: "Distributes to Victims". If no victims, logic implies fallback or nothing.
			# Let's fallback to everyone to keep game moving / punishment real.
			victims = hands_array.duplicate()
			
		# 3. Distribute Remaining Pile
		var penalty_pool = discard_pile.collect_all_cards()
		
		if penalty_pool.is_empty():
			log_message("The void was hungry... no other cards to distribute.")
		else:
			penalty_pool.shuffle()
			log_message("The Beast distributes %d remaining cards!" % penalty_pool.size())
			
			var v_idx = 0
			for card in penalty_pool:
				var victim_hand = victims[v_idx % victims.size()]
				victim_hand.move_cards([card])
				v_idx += 1
				
		cycle_turn(1) 
		# Pile is now empty. Next player plays on empty pile (Any card valid).
	else:
		# Normal 6
		log_message("Player %d played a 6..." % current_player)
		cycle_turn(1)

# Q: Reverse direction
func _effect_reverse(_card: Card) -> void:
	print("Effect: Reverse (Q)")
	log_message("Effect: Direction Reversed!")
	play_direction *= -1
	_update_hud_effects()
	cycle_turn(1)
	
# J: Wildcard with Suit Selection
func _effect_jack(_card: Card) -> void:
	_print_game_event("Effect Triggered", "Jack/Joker Suit Selection")
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
	_print_game_event("Selection", "Chose Suit: " + suit)
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

# Joker: Draw 4 + Skip + Choose Suit (Stacking)
# Joker: Draw 4 + Skip + Choose Suit (Stacking)
func _effect_joker(_card: Card) -> void:
	_print_game_event("Effect Triggered", "Stacking Joker (+4)")
	log_message("Joker! +4 Cards! Stack or Draw!")
	
	pending_penalty += 4
	penalty_type = "joker"
	
	# Sync failure to pile
	discard_pile.pending_penalty = pending_penalty
	discard_pile.penalty_type = penalty_type
	
	# Pass control to Jack effect for Suit Selection, which then cycles turn.
	# Note: Joker skips 1 person, so generally next player is skipped.
	# But Jack effect sets pending_turn_skip = 1 (default).
	# Joker should set pending_turn_skip = 2 (Skip).
	pending_turn_skip = 2
	
	_effect_jack(_card)

# 10: Simon Says (Word Memory)
func _effect_ten(_card: Card) -> void:
	print("Effect: Simon Says (10)")
	
	# Block interaction
	_set_hands_interaction(false) 
	
	# Challenge Phase
	if not word_chain.is_empty():
		log_message("Simon Says: Recite the chain!")
		for i in range(word_chain.size()):
			var correct = word_chain[i]
			var options = _generate_simon_options(correct)
			
			log_message("Challenge %d/%d..." % [i + 1, word_chain.size()])
			simon_popup.start_challenge(correct, options)
			
			var success = await simon_popup.challenge_completed
			if not success:
				log_message("WRONG! The chain breaks!")
				var penalty = word_chain.size() + 1
				var victim_hand = hands_array[current_player - 1]
				distribute_cards(victim_hand, penalty)
				word_chain.clear()
				_finish_simon_turn(false)
				return # Exit immediately on failure
	
	# Input Phase (If success or empty)
	log_message("Simon Says: Add a new word!")
	simon_popup.start_input_mode()
	var new_word = await simon_popup.word_submitted
	log_message("Player wrote: " + new_word)
	word_chain.append(new_word)
	_finish_simon_turn(true)

func _finish_simon_turn(success: bool) -> void:
	# Restore interaction
	_set_hands_interaction(true)
	cycle_turn(1)

func _generate_simon_options(correct: String) -> Array[String]:
	var opts: Array[String] = [correct]
	var pool = dict_pt if simon_dict_mode == "PT" else dict_en
	pool.shuffle()
	
	for w in pool:
		if w != correct and opts.size() < 4:
			opts.append(w)
			
	opts.shuffle()
	return opts

func _set_hands_interaction(enabled: bool) -> void:
	for hand in hands_array:
		hand.allow_remote_interaction = enabled

# Club 4: Clears Active Effects (8s, Kings, Queens/Direction)
# DOES NOT clear Spade 4 Lock.
# DOES NOT clear Jack/Joker Active Suit.
func _effect_club_4(_card: Card) -> void:
	print("Effect: Clear Active Effects (Club 4)")
	log_message("Effects Cleared (8s, Direction)")
	
	# Clear 8s Masquerade
	active_effects["eight_black"] = false
	active_effects["eight_red"] = false
	discard_pile.active_effect_eight_red = false
	active_effects["silence"] = false
	
	# Note: Club 4 does NOT clear Spade 4 Lock (active_effects["locked"])
	# So we don't reset discard_pile.active_effect_locked here unless rule changes.
	
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
	discard_pile.active_effect_locked = true # Sync to pile
	_update_hud_effects()
	cycle_turn(1)

# Red 4: Unlocks Effects
func _effect_red_4(_card: Card) -> void:
	print("Effect: UNLOCK Effects (Red 4)")
	if active_effects["locked"]:
		log_message("Effects are now UNLOCKED!")
		active_effects["locked"] = false
		discard_pile.active_effect_locked = false # Sync to pile
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

	# --- Simon Says Popup ---
	if simon_popup_scene:
		simon_popup = simon_popup_scene.instantiate()
		hud_layer.add_child(simon_popup)
	
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
	log_panel = PanelContainer.new()
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
	
	log_panel.visible = GameGlobals.show_game_log # Respect initial setting
	
	hud_layer.add_child(log_panel)
	
	game_log_label = RichTextLabel.new()
	game_log_label.scroll_following = true
	game_log_label.text = "[b]Game Log Started[/b]"
	log_panel.add_child(game_log_label)
	
	# --- Options Menu UI ---
	_setup_options_menu()
	
	update_player_stats()

var game_log_label: RichTextLabel
var log_panel: PanelContainer
var options_menu: PanelContainer

func _setup_options_menu() -> void:
	options_menu = PanelContainer.new()
	options_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	options_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	vbox.add_theme_constant_override("separation", 10)
	options_menu.add_child(vbox)
	
	var title = Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	# --- Visual Settings ---
	var lbl_vis = Label.new(); lbl_vis.text = "Visual Assists"; vbox.add_child(lbl_vis)
	_add_checkbox(vbox, "Show Side Bar", GameGlobals.show_effect_status_bar, func(v): 
		GameGlobals.show_effect_status_bar = v
		_update_hud_effects()
	)
	_add_checkbox(vbox, "Show Play Assist", GameGlobals.show_play_highlights, func(v): GameGlobals.show_play_highlights = v)
	_add_checkbox(vbox, "Show Turn Highlight", GameGlobals.show_current_player_highlight, func(v): 
		GameGlobals.show_current_player_highlight = v
		update_turn_ui()
	)
	_add_checkbox(vbox, "Show Game Log", GameGlobals.show_game_log, func(v):
		GameGlobals.show_game_log = v
		if log_panel: log_panel.visible = v
	)

	vbox.add_child(HSeparator.new())

	vbox.add_child(HSeparator.new())
	
	# --- Rule Settings ---
	var lbl_rules = Label.new(); lbl_rules.text = "Active Rules (Requires Restart)"; vbox.add_child(lbl_rules)
	
	var rules_grid = GridContainer.new()
	rules_grid.columns = 2
	vbox.add_child(rules_grid)
	
	# Helper to create rule toggles
	var rule_keys = GameGlobals.active_rules.keys()
	rule_keys.sort()
	for key in rule_keys:
		if key == "0": continue # Skip typo
		
		var rule_name = "Rule " + key
		if key == "joker": rule_name = "Jokers"
		
		# Capture key for closure
		var current_key = key
		_add_checkbox(rules_grid, rule_name, GameGlobals.active_rules[key], func(v): 
			GameGlobals.active_rules[current_key] = v
			_register_card_effects() # Re-register immediately
			print("Rule " + current_key + " set to " + str(v))
		)

	vbox.add_child(HSeparator.new())

	var btn_close = Button.new()
	btn_close.text = "Close"
	btn_close.pressed.connect(_on_close_menu_pressed)
	vbox.add_child(btn_close)
	
	var btn_quit = Button.new()
	btn_quit.text = "Quit Game"
	btn_quit.pressed.connect(_on_quit_game_pressed)
	vbox.add_child(btn_quit)

func _add_checkbox(parent: Control, text: String, default_val: bool, callback: Callable) -> void:
	var cb = CheckBox.new()
	cb.text = text
	cb.button_pressed = default_val
	cb.toggled.connect(callback)
	parent.add_child(cb)

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
	cycle_turn(1, false)

		
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
func _input(event: InputEvent) -> void:
	if not event.is_pressed(): return
	if not event is InputEventKey: return
	
	# Debug: Roll Die with 'D' (All Players)
	if event.keycode == KEY_D:
		log_message("Debug: Rolling dice for ALL players!")
		for p_idx in range(1, num_players + 1):
			var val = randi() % 6 + 1
			show_dice_roll(p_idx, val)
			
	# Debug: Roll Die for specific player (1-9)
	elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
		var p_idx = event.keycode - KEY_0
		if p_idx >= 1 and p_idx <= num_players:
			log_message("Debug: Rolling die for Player %d" % p_idx)
			var val = randi() % 6 + 1
			show_dice_roll(p_idx, val)

func show_dice_roll(player_idx: int, value: int) -> void:
	if not die_scene: return
	
	# Instantiate transient die
	var die = die_scene.instantiate()
	if not die: return
	
	# Add to HUD
	if hud_layer:
		hud_layer.add_child(die)
		die.scale = Vector2(0.4, 0.4) # Small (20% of previous 2.0)
	else:
		return
	
	print("DEBUG: Rolling Die for Player %d -> %d" % [player_idx, value])
	
	# Position: 20% closer to center from Hand
	var center = get_viewport().get_visible_rect().get_center()
	
	if player_idx >= 1 and player_idx <= hands_array.size():
		var hand = hands_array[player_idx - 1]
		var hand_pos = hand.get_global_transform_with_canvas().origin
		
		var to_center = center - hand_pos
		var base_pos = hand_pos + (to_center * 0.2)
		
		# Add jitter
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		die.global_position = base_pos + offset
	else:
		# Fallback for spectator or unknown
		die.global_position = center
	
	die.rotation = 0 # Rotation handled by script but reset here
	
	# Call roll method on Die script
	if die.has_method("roll"):
		die.roll(value)
		
	# Cleanup after 4 seconds
	get_tree().create_timer(4.0).timeout.connect(func(): die.queue_free())
