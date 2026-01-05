extends Node

@export var num_players = 1;
@export var num_cards_in_hand = 5;
@export var hand_scene: PackedScene;
@onready var card_manager := $CardManager;
var hands_array: Array[Hand] = [];

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for player in range(num_players):
		hands_array.append(hand_scene.instantiate());
		card_manager.add_child(hands_array[-1]);
		hands_array[-1].position.x = 50 * player;
		hands_array[-1].position.y = 50 * player;
		
		
	# instanciar hands
	# distribuir cards para cada hand
	pass # Replace with function body.
