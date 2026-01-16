extends PanelContainer

class_name EffectStatusBar

# UI References
var icon_container: HBoxContainer
var icons: Dictionary = {} # Map effect_key -> TextureRect

# Assets (Preload or load dynamically)
# We will load generic card images to represent the effects
var asset_path = "res://Maumau/assets/images/cards/"

func _ready() -> void:
	setup_ui()

func setup_ui() -> void:
	# 1. Style the Background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.3, 0.8) # Tech Blue/Dark background
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.0, 0.8, 1.0) # Cyan Border
	style.corner_radius_top_right = 10
	style.corner_radius_top_left = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	add_theme_stylebox_override("panel", style)
	
	# Position/Size is handled by parent (Manager), but we respect it.
	# Remove internal minimum size to allow flexible sizing down
	# custom_minimum_size = Vector2(300, 80) 
	
	# 2. Container
	icon_container = HBoxContainer.new()
	icon_container.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_container.add_theme_constant_override("separation", 20)
	icon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL # Fill available height
	icon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(icon_container)
	
	# 3. Create Slots
	# Slot 1: Locked (Spade 4)
	_add_icon_slot("locked", "cardSpades4.png", "Lock (Spade 4)")
	
	# Slot 2: Black 8 (Club 8)
	_add_icon_slot("eight_black", "cardClubs8.png", "Masquerade (Black)")
	
	# Slot 3: Red 8 (Heart 8)
	_add_icon_slot("eight_red", "cardHearts8.png", "Masquerade (Red)")
	
	# Slot 4: Active Suit (Dynamic)
	_add_icon_slot("active_suit", "cardJoker.png", "Active Suit")
	
	# Initialize state
	reset_all()

func _add_icon_slot(key: String, image_filename: String, tooltip: String) -> void:
	# Wrapper
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Icon
	var texture_rect = TextureRect.new()
	# "Ignore Size" is the key to scaling down properly within a small container
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Fill available space
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Initial Min Size (Generic, allows shrinking but starts reasonable)
	# Force WIDTH so it doesn't collapse to 0
	texture_rect.custom_minimum_size = Vector2(40, 0)
	
	# Load Texture
	var texture = load(asset_path + image_filename)
	if texture:
		texture_rect.texture = texture
	else:
		push_warning("Icon not found: " + asset_path + image_filename)
		
	texture_rect.tooltip_text = tooltip
	
	wrapper.add_child(texture_rect)
	icon_container.add_child(wrapper)
	
	# Store reference
	icons[key] = texture_rect

func update_status(active_effects: Dictionary, current_active_suit: String) -> void:
	# 1. Update Boolean Effects
	_set_icon_state("locked", active_effects.get("locked", false))
	_set_icon_state("eight_black", active_effects.get("eight_black", false))
	_set_icon_state("eight_red", active_effects.get("eight_red", false))
	
	# 2. Update Active Suit
	var suit_icon = icons["active_suit"]
	if current_active_suit == "":
		_set_icon_state("active_suit", false)
		suit_icon.texture = load(asset_path + "cardJoker.png") 
		suit_icon.tooltip_text = "No Active Suit"
	else:
		_set_icon_state("active_suit", true)
		# Load representative card for the suit (e.g., Ace)
		var suit_card_img = "card" + current_active_suit.capitalize() + "A.png"
		suit_icon.texture = load(asset_path + suit_card_img)
		suit_icon.tooltip_text = "Required Suit: " + current_active_suit
		# Always fully visible if active
		suit_icon.modulate = Color(1.0, 1.0, 1.0, 1.0) 

func _set_icon_state(key: String, is_active: bool) -> void:
	if not icons.has(key): return
	
	var icon = icons[key]
	if is_active:
		icon.modulate = Color(1.2, 1.2, 1.2, 1.0) # Bright/Overbright
	else:
		# Increase brightness of inactive icons so they are visible against blue bg
		icon.modulate = Color(0.6, 0.6, 0.6, 0.8)

func reset_all() -> void:
	for key in icons:
		_set_icon_state(key, false)
