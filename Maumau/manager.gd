extends Node

const MODE_MAUMAU = "MAU_MAU"
const MODE_WANWAN = "WAN_WAN"

@export var num_players = 1;
@export var num_cards_in_hand = 5;
@export var current_player: int = 1;
@export var hand_scene: PackedScene;
@onready var card_manager := $CardManager;
var hands_array: Array[Hand] = [];
var player_modes: Dictionary = {}
var player_items: Dictionary = {} # Map[player_idx] -> Array[String] (e.g. "mirror_force")

# Called when the node enters the scene tree for the first time.
@export var deck_scene: PackedScene = preload("res://addons/card-framework/pile.tscn")
@export var discard_pile_scene: PackedScene = preload("res://Maumau/mau_mau_pile.tscn")
@export var simon_popup_scene: PackedScene = preload("res://Maumau/simon_says_popup.tscn")

# UI Scenes for Effects
var suit_selector_scene: PackedScene = preload("res://Maumau/suit_selector.tscn")
var speech_bubble_scene: PackedScene = preload("res://Maumau/speech_bubble.tscn")
var die_scene: PackedScene = preload("res://Maumau/die.tscn")
var simon_popup: Control

# Effect Modules
const AceEffect = preload("res://Maumau/effects/ace_effect.gd")
const TwoEffect = preload("res://Maumau/effects/two_effect.gd")
const FourEffect = preload("res://Maumau/effects/four_effect.gd")
const FiveEffect = preload("res://Maumau/effects/five_effect.gd")
const SevenEffect = preload("res://Maumau/effects/seven_effect.gd")
const EightEffect = preload("res://Maumau/effects/eight_effect.gd")
const NineEffect = preload("res://Maumau/effects/nine_effect.gd")
const TenEffect = preload("res://Maumau/effects/ten_effect.gd")
const JackEffect = preload("res://Maumau/effects/jack_effect.gd")
const QueenEffect = preload("res://Maumau/effects/queen_effect.gd")
const KingEffect = preload("res://Maumau/effects/king_effect.gd")
const JokerEffect = preload("res://Maumau/effects/joker_effect.gd")
const SixEffect = preload("res://Maumau/effects/six_effect.gd")

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
	
	# 7. Roll for Game Modes (Mau Mau vs Wan Wan)
	_roll_initial_modes()
	
	# 8. Start Game (First card to discard)
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
	var all_dragged_cards = card_manager.current_dragged_cards
	
	# FILTER: Only validate cards that are genuinely being held by the mouse.
	# "Ghosts" can appear if an effect interrupts a drag (like Silence Broken or Turn Mismatch) 
	# and the card_manager list doesn't clear instantly.
	var dragged_cards = []
	for c in all_dragged_cards:
		if c.current_state == c.DraggableState.HOLDING:
			dragged_cards.append(c)
	
	# Failsafe: Only consider dragging if Mouse Left is actually pressed.
	var is_dragging = not dragged_cards.is_empty() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Handle Highlight for Discard Pile
	var discard_top_cards = discard_pile.get_top_cards(1)
	if not discard_top_cards.is_empty():
		var top_card = discard_top_cards[0]
		# Only highlight if dragging
		if is_dragging:
			
			# Priority 1: If input is disabled (e.g. Suit Selection open), hide highlight.
			# Priority 2: If Silence is active, hide highlight.
			if discard_pile.input_disabled or active_effects.get("silence", false):
				top_card.set_helper_display(false)
			else:
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
	var was_swap_active = active_effects.get("swap_next_mode", false)
	if was_swap_active:
		print("DEBUG: Swap Mode Active for this card!")
		
	if card_effects.has(card.card_name):
		# RULE: If effects are blocked (Spade 4), only Red 4s can trigger their effect (Unlock).
		if active_effects.get("locked", false):
			if card.card_name.begins_with("heart_4") or card.card_name.begins_with("diamond_4"):
				print("DEBUG: Effect Dispatch: Red 4 Unblocker!")
				card_effects[card.card_name].call(card)
			else:
				print("DEBUG: Effect Dispatch: BLOCKED by Spade 4!")
				log_message("Effect BLOCKED by Spade 4!")
				_effect_default(card)
		else:
			print("DEBUG: Dispatching to specific handler for ", card.card_name)
			card_effects[card.card_name].call(card)
	else:
		print("DEBUG: Using default handler for ", card.card_name)
		_effect_default(card)
		
	# Cleanup Swap Mode (Consumed)
	if was_swap_active:
		active_effects["swap_next_mode"] = false
		log_message("Mode Swap consumed.")


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
				"A": card_effects[card_name] = func(c): AceEffect.execute(self, c)
				"7": card_effects[card_name] = func(c): SevenEffect.execute(self, c)
				"9": card_effects[card_name] = func(c): NineEffect.execute(self, c)
				"Q": card_effects[card_name] = func(c): QueenEffect.execute(self, c)
				"J": card_effects[card_name] = func(c): JackEffect.execute(self, c)
				"6": card_effects[card_name] = func(c): SixEffect.execute(self, c)
				"10": card_effects[card_name] = func(c): TenEffect.execute(self, c)
				"K": card_effects[card_name] = func(c): KingEffect.execute(self, c)
				
	# Specific rules by name
	if GameGlobals.is_rule_active("5"):
		card_effects["diamond_5"] = func(c): FiveEffect.execute_diamond(self, c)
		card_effects["heart_5"] = func(c): FiveEffect.execute_heart(self, c)
	
	# Jokers
	if GameGlobals.is_rule_active("joker"):
		card_effects["joker_red"] = func(c): JokerEffect.execute(self, c)
		card_effects["joker_black"] = func(c): JokerEffect.execute(self, c)
	
	# 4s (Lock & Unlock)
	if GameGlobals.is_rule_active("4"):
		card_effects["club_4"] = func(c): FourEffect.execute_club(self, c)
		card_effects["spade_4"] = func(c): FourEffect.execute_spade(self, c)
		card_effects["heart_4"] = func(c): FourEffect.execute_red(self, c)
		card_effects["diamond_4"] = func(c): FourEffect.execute_red(self, c)
	
	# Register 8s
	if GameGlobals.is_rule_active("8"):
		for suit in suits:
			# 8s currently in Manager (not fully extracted yet)
			card_effects[suit + "_8"] = func(c): EightEffect.execute(self, c)

	# Register 2s
	if GameGlobals.is_rule_active("2"):
		for suit in suits:
			card_effects[suit + "_2"] = func(c): TwoEffect.execute(self, c)
			
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


func _show_mimic_selector(on_final_selection: Callable) -> void:
	var popup = PanelContainer.new()
	popup.name = "MimicSelector"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	for k in ["top", "bottom", "left", "right"]: margin.add_theme_constant_override("margin_" + k, 10)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	# Title
	var label = Label.new()
	label.text = "MIMICRY: Choose Suit & Rank"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# State
	var selection = {"suit": "", "rank": ""}
	var suit_buttons = {}
	var rank_buttons = {}
	
	# --- 3. Confirm Button (Created early for closure access) ---
	var confirm_btn = Button.new()
	confirm_btn.text = "Select Suit & Rank..."
	confirm_btn.disabled = true
	confirm_btn.custom_minimum_size = Vector2(0, 50)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	
	# Helper to update UI state
	var update_ui = func():
		# Highlights
		for s in suit_buttons:
			suit_buttons[s].modulate = Color(1, 1, 0) if s == selection.suit else Color(1, 1, 1)
		for r in rank_buttons:
			rank_buttons[r].modulate = Color(1, 1, 0) if r == selection.rank else Color(1, 1, 1)
			
		# Confirm Button
		if selection.suit != "" and selection.rank != "":
			confirm_btn.disabled = false
			confirm_btn.text = "MIMIC %s %s" % [selection.suit.capitalize(), selection.rank]
		else:
			confirm_btn.disabled = true
			confirm_btn.text = "Select Suit & Rank..."

	# --- 1. Suit Selection ---
	var suit_container = HBoxContainer.new()
	suit_container.alignment = BoxContainer.ALIGNMENT_CENTER
	suit_container.add_theme_constant_override("separation", 10)
	vbox.add_child(suit_container)
	
	var suits = ["spade", "heart", "club", "diamond"]
	for s in suits:
		var btn = Button.new()
		btn.text = s.capitalize()
		btn.custom_minimum_size = Vector2(70, 40)
		btn.pressed.connect(func():
			selection.suit = s
			update_ui.call()
		)
		suit_container.add_child(btn)
		suit_buttons[s] = btn
		
	# --- 2. Rank Selection ---
	var grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)
	
	# Ranks (No 2)
	var ranks = ["A", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "Joker"]
	for r in ranks:
		var btn = Button.new()
		btn.text = r
		btn.custom_minimum_size = Vector2(40, 40)
		btn.pressed.connect(func():
			selection.rank = r
			update_ui.call()
		)
		grid.add_child(btn)
		rank_buttons[r] = btn
		
	# Add Confirm Button at the end
	confirm_btn.pressed.connect(func():
		popup.queue_free()
		on_final_selection.call(selection.rank, selection.suit)
	)
	vbox.add_child(confirm_btn)
		
	hud_layer.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH

	# If he has no valid cards, he must draw. Logic to be enforced by player interaction.

	# Ace (Handled by Modular Effect)
	# Functions removed.

func _show_blind_hand_selector(target_idx: int, on_selected: Callable) -> void:
	var target_hand = hands_array[target_idx - 1]
	var cards = target_hand._held_cards
	
	if cards.is_empty():
		log_message("Target has no cards!")
		cycle_turn(1)
		return
		
	var popup = PanelContainer.new()
	popup.name = "HandSelector"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	for k in ["top", "bottom", "left", "right"]: margin.add_theme_constant_override("margin_" + k, 20)
	popup.add_child(margin)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	margin.add_child(grid)
	
	for c in cards:
		var btn = Button.new()
		btn.text = "?"
		btn.custom_minimum_size = Vector2(50, 70)
		btn.pressed.connect(func():
			popup.queue_free()
			on_selected.call(c)
		)
		grid.add_child(btn)
		
	hud_layer.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH

# 7: Next player draws 2 and is skipped
# K: The Silence (King)


# 9: Last player who played draws 1
# 9: Last player who played draws 1 (Stacking allowed via History)


func _show_player_selector(picker_idx: int, on_selected: Callable, excluded_idx: int = -1) -> void:
	# Quick Procedural UI
	var popup = PanelContainer.new()
	popup.name = "PlayerSelector"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.0, 0.0, 0.9)
	style.border_width_bottom = 2
	style.border_color = Color.RED
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	popup.add_theme_stylebox_override("panel", style)
	
	# 1. Main Container (Padding)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	var label = Label.new()
	label.text = "PLAYER %d, CHOOSE A VICTIM" % picker_idx
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(label)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	vbox.add_child(grid)
	
	for i in range(1, num_players + 1):
		# Exclusion check
		if i == excluded_idx:
			continue
			
		var btn = Button.new()
		btn.text = "Player %d" % i
		btn.custom_minimum_size = Vector2(100, 60) # Bigger buttons
		btn.pressed.connect(func(): 
			popup.queue_free()
			on_selected.call(i)
		)
		grid.add_child(btn)
		
	hud_layer.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# 5s (Handled by Modular Effect)

# Joker: Draw 4 + Skip + Choose Suit (Stacking)
# Joker: Draw 4 + Skip + Choose Suit (Stacking)
# Joker: Draw 4 + Skip + Choose Suit (Stacking)


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
		_update_player_mode_ui(i + 1)

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
			# Re-evaluated modes on debug roll if desired? 
			# User said: "On a even... mau mau, on a odd... wan wan".
			# Does 'D' debug roll trigger mode change? User: "When the game starts all players roll... (function 'D')... we'll need to store the value".
			# So yes, 'D' should update mode? Or creates separate function?
			# Let's update mode here to verify behavior dynamically.
			if val % 2 == 0:
				_set_player_mode(p_idx, MODE_MAUMAU)
			else:
				_set_player_mode(p_idx, MODE_WANWAN)
			
	# Debug: Roll Die for specific player (1-9)
	elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
		var p_idx = event.keycode - KEY_0
		if p_idx >= 1 and p_idx <= num_players:
			# Update mode for specific player too
			var val = randi() % 6 + 1
			show_dice_roll(p_idx, val)
			if val % 2 == 0:
				_set_player_mode(p_idx, MODE_MAUMAU)
			else:
				_set_player_mode(p_idx, MODE_WANWAN)

func _get_effective_mode(p_idx: int) -> String:
	var base_mode = player_modes.get(p_idx, MODE_MAUMAU)
	var swap_active = active_effects.get("swap_next_mode", false)
	
	if not swap_active:
		return base_mode
		
	# Invert
	if base_mode == MODE_MAUMAU:
		return MODE_WANWAN
	else:
		return MODE_MAUMAU

# --- Wan Wan / Game Mode Logic ---

func _roll_initial_modes() -> void:
	log_message("Rolling for Game Modes...")
	# Wait a bit for UI to settle?
	await get_tree().create_timer(1.0).timeout
	
	for p_idx in range(1, num_players + 1):
		var val = randi() % 6 + 1
		show_dice_roll(p_idx, val)
		
		if val % 2 == 0:
			_set_player_mode(p_idx, MODE_MAUMAU)
		else:
			_set_player_mode(p_idx, MODE_WANWAN)
			
func _set_player_mode(p_idx: int, mode: String) -> void:
	player_modes[p_idx] = mode
	# print("Player %d is now in %s mode" % [p_idx, mode])
	_update_player_mode_ui(p_idx)

func _update_player_mode_ui(p_idx: int) -> void:
	if p_idx < 1 or p_idx > player_labels.size(): return
	
	var label = player_labels[p_idx - 1]
	var mode = player_modes.get(p_idx, MODE_MAUMAU)
	var items = player_items.get(p_idx, [])
	
	var text = "Player %d" % p_idx
	if mode == MODE_MAUMAU:
		label.modulate = Color.WHITE
		text += " (MAU)"
	else:
		label.modulate = Color(1.0, 0.2, 0.2)
		text += " (WAN)"
		
	# Show Items
	if "mirror_force" in items:
		text += " 🛡️"
		# Optional: Show count if > 1?
		var count = items.count("mirror_force")
		if count > 1:
			text += "x%d" % count
			
	# Show Card Count
	var hand_count = hands_array[p_idx - 1].get_card_count()
	text += " (%d)" % hand_count
			
	label.text = text

func show_dice_roll(player_idx: int, value: int) -> void:
	if not die_scene: return
	
	# Instantiate transient die
	var die = die_scene.instantiate()
	if not die: return
	
	# Add to HUD
	if hud_layer:
		hud_layer.add_child(die)
		die.scale = Vector2(0.6, 0.6) # Small (30% of previous 2.0)
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
	get_tree().create_timer(4.0).timeout.connect(func(): 
		if is_instance_valid(die): die.queue_free()
	)

# --- Item System / Targeting ---

func apply_targeted_effect(target_idx: int, source_idx: int, effect_callback: Callable) -> void:
	# Check if target has Mirror Force
	var items = player_items.get(target_idx, [])
	
	if "mirror_force" in items:
		log_message("Player %d has a Mirror Force! Asking to use..." % target_idx)
		_show_reflection_popup(target_idx, source_idx, effect_callback)
	else:
		# No items, apply directly
		effect_callback.call(target_idx)

func _show_reflection_popup(target_idx: int, source_idx: int, callback: Callable) -> void:
	# Block Input
	if discard_pile: discard_pile.input_disabled = true
	
	var popup = PanelContainer.new()
	popup.name = "MirrorForcePopup"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.2, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color.CYAN
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)
	
	var label = Label.new()
	label.text = "PLAYER %d!\nUSE MIRROR FORCE?" % target_idx
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(label)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(hbox)
	
	# YES Button
	var btn_yes = Button.new()
	btn_yes.text = "REFLECT"
	btn_yes.custom_minimum_size = Vector2(100, 50)
	btn_yes.modulate = Color(0.5, 1.0, 0.5) # Greenish
	btn_yes.pressed.connect(func(): _on_reflection_decision(target_idx, source_idx, callback, true, popup))
	hbox.add_child(btn_yes)
	
	# NO Button
	var btn_no = Button.new()
	btn_no.text = "NO"
	btn_no.custom_minimum_size = Vector2(100, 50)
	btn_no.modulate = Color(1.0, 0.5, 0.5) # Reddish
	btn_no.pressed.connect(func(): _on_reflection_decision(target_idx, source_idx, callback, false, popup))
	hbox.add_child(btn_no)
	
	hud_layer.add_child(popup)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
func _on_reflection_decision(target_idx: int, source_idx: int, callback: Callable, used_mirror: bool, popup: Control) -> void:
	popup.queue_free()
	if discard_pile: discard_pile.input_disabled = false
	
	if used_mirror:
		log_message("Player %d USED Mirror Force! Effect Reflected!" % target_idx)
		
		# Remove Item
		var items = player_items.get(target_idx, [])
		if "mirror_force" in items:
			items.erase("mirror_force") # Removes first occurrence
			player_items[target_idx] = items
			_update_player_mode_ui(target_idx)
			
		# Callback with SOURCE as target
		callback.call(source_idx)
	else:
		log_message("Player %d held the Mirror Force." % target_idx)
		# Callback with ORIGINAL TARGET
		callback.call(target_idx)
