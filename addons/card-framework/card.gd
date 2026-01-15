## A card object that represents a single playing card with drag-and-drop functionality.
##
## The Card class extends DraggableObject to provide interactive card behavior including
## hover effects, drag operations, and visual state management. Cards can display
## different faces (front/back) and integrate with the card framework's container system.
##
## Key Features:
## - Visual state management (front/back face display)
## - Drag-and-drop interaction with state machine
## - Integration with CardContainer for organized card management
## - Hover animation and visual feedback
##
## Usage:
## [codeblock]
## var card = card_factory.create_card("ace_spades", target_container)
## card.show_front = true
## card.move(target_position, 0)
## [/codeblock]
class_name Card
extends DraggableObject

# Static counters for global card state tracking
static var hovering_card_count: int = 0
static var holding_card_count: int = 0


## The name of the card.
@export var card_name: String
## The size of the card.
@export var card_size: Vector2 = CardFrameworkSettings.LAYOUT_DEFAULT_CARD_SIZE
## The texture for the front face of the card.
@export var front_image: Texture2D
## The texture for the back face of the card.
@export var back_image: Texture2D
## Whether the front face of the card is shown.
## If true, the front face is visible; otherwise, the back face is visible.
@export var show_front: bool = true:
	set(value):
		if value:
			front_face_texture.visible = true
			back_face_texture.visible = false
		else:
			front_face_texture.visible = false
			back_face_texture.visible = true

@export_group("Highlight Styles")
@export var active_player_color: Color = Color.KHAKI
@export var active_player_width: int = 6
@export var helper_display_color: Color = Color.GREEN
@export var helper_display_invalid_color: Color = Color.RED
@export var helper_display_width: int = 6


# Card data and container reference
var card_info: Dictionary
var card_container: CardContainer


@onready var front_face_texture: TextureRect = $FrontFace/TextureRect
@onready var back_face_texture: TextureRect = $BackFace/TextureRect


func _ready() -> void:
	super._ready()
	front_face_texture.size = card_size
	back_face_texture.size = card_size
	if front_image:
		front_face_texture.texture = front_image
	if back_image:
		back_face_texture.texture = back_image
	pivot_offset = card_size / 2


func _on_move_done() -> void:
	card_container.on_card_move_done(self)


## Sets the front and back face textures for this card.
##
## @param front_face: The texture to use for the front face
## @param back_face: The texture to use for the back face
func set_faces(front_face: Texture2D, back_face: Texture2D) -> void:
	front_face_texture.texture = front_face
	back_face_texture.texture = back_face


## Returns the card to its original position with smooth animation.
func return_card() -> void:
	super.return_to_original()


# Override state entry to add card-specific logic
func _enter_state(state: DraggableState, from_state: DraggableState) -> void:
	super._enter_state(state, from_state)
	
	match state:
		DraggableState.HOVERING:
			hovering_card_count += 1
		DraggableState.HOLDING:
			holding_card_count += 1
			if card_container:
				card_container.hold_card(self)
				if card_container.card_manager:
					card_container.card_manager.on_card_drag_started(self)

# Override state exit to add card-specific logic
func _exit_state(state: DraggableState) -> void:
	match state:
		DraggableState.HOVERING:
			hovering_card_count -= 1
		DraggableState.HOLDING:
			holding_card_count -= 1
			if card_container and card_container.card_manager:
				card_container.card_manager.on_card_drag_ended(self)
	
	super._exit_state(state)

## Legacy compatibility method for holding state.
## @deprecated Use state machine transitions instead
func set_holding() -> void:
	if card_container:
		card_container.hold_card(self)


## Returns a string representation of this card.
func get_string() -> String:
	return card_name


## Checks if this card can start hovering based on global card state.
## Prevents multiple cards from hovering simultaneously.
func _can_start_hovering() -> bool:
	return hovering_card_count == 0 and holding_card_count == 0


## Handles mouse press events with container notification.
func _handle_mouse_pressed() -> void:
	card_container.on_card_pressed(self)
	super._handle_mouse_pressed()


## Handles mouse release events and releases held cards.
func _handle_mouse_released() -> void:

	super._handle_mouse_released()
	if card_container:
		card_container.release_holding_cards()


var active_highlight_node: Panel
var helper_highlight_node: Panel

## Controls whether the card shows the Active Player highlight.
var _is_active_player_display: bool = false
var is_active_player_display: bool:
	get: return _is_active_player_display
	set(value):
		set_active_player_display(value)

## Controls whether the card shows the Helper highlight (Drop Target).
var _is_helper_display: bool = false
var is_helper_display: bool:
	get: return _is_helper_display
	set(value):
		set_helper_display(value)

## Shows or hides the Active Player highlight (Turn indicator).
func set_active_player_display(active: bool) -> void:
	if active == _is_active_player_display and active_highlight_node and active_highlight_node.visible == active:
		return
		
	if not active_highlight_node:
		active_highlight_node = _create_highlight_panel("ActivePlayerHighlight", active_player_color, active_player_width)
		add_child(active_highlight_node)
	
	active_highlight_node.visible = active
	_is_active_player_display = active

## Shows or hides the Helper highlight (Drag target indicator).
func set_helper_display(active: bool, is_valid: bool = true) -> void:
	if active == _is_helper_display and helper_highlight_node and helper_highlight_node.visible == active:
		# Check if validity changed while still active
		var target_color = helper_display_color if is_valid else helper_display_invalid_color
		var style = helper_highlight_node.get_theme_stylebox("panel") as StyleBoxFlat
		if style and style.border_color != target_color:
			style.border_color = target_color
		return

	if not helper_highlight_node:
		helper_highlight_node = _create_highlight_panel("HelperHighlight", helper_display_color, helper_display_width)
		add_child(helper_highlight_node)
		
	# Update color based on validity
	var style = helper_highlight_node.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = helper_display_color if is_valid else helper_display_invalid_color
		
	helper_highlight_node.visible = active
	_is_helper_display = active

## Helper to create highlight panels
func _create_highlight_panel(p_name: String, p_color: Color, p_width: int) -> Panel:
	var node = Panel.new()
	node.editor_description = p_name
	
	var style = StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = p_width
	style.border_width_top = p_width
	style.border_width_right = p_width
	style.border_width_bottom = p_width
	style.border_color = p_color
	
	node.add_theme_stylebox_override("panel", style)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = card_size
	return node

## Deprecated: Compatibility Alias for show_highlight
## Redirects to set_active_player_display (assuming old logic meant turn highlight)
func show_highlight(active: bool) -> void:
	set_active_player_display(active)
