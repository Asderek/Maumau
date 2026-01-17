extends Node

# Global settings for the game
var num_players: int = 4

# Visual / Difficulty Settings
var show_effect_status_bar: bool = true
var show_play_highlights: bool = true
var show_current_player_highlight: bool = true
var show_game_log: bool = true

# Active Rules (Table Configuration)
# If true, the card has its special effect. If false, it acts as a normal card.
var active_rules: Dictionary = {
	"2": true,      # Double Play
	"4": true,      # Lock/Red 4 Unlock
	"5": true,      # Rotate Hands
	"7": true,      # Draw 2 Stack
	"8": true,      # Masquerade
	"9": true,      # Last Player Draws
	"Q": true,
	"J": true,
	"A": true,
	"joker": true,  # Draw 4 Stack
	"jump_in": true, # Doubling / Interception
	"6": true,       # Rule 666
	"10": true       # Simon Says
}

func is_rule_active(rule_key: String) -> bool:
	return active_rules.get(rule_key, true) # Default to true if not found
