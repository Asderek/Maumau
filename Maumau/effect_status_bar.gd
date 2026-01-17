extends PanelContainer

class_name EffectStatusBar


# UI References
var icon_container: HBoxContainer
var icons: Dictionary = {} # Map effect_key -> TextureRect OR Control

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
	
	# Slot 5: Silence (King)
	_add_icon_slot("silence", "cardSpadesK.png", "Silence (King)")
	
	# Slot 6: Direction (Queen)
	# Use procedural arrow instead of image
	var arrow = DirectionArrow.new()
	arrow.tooltip_text = "Play Direction"
	_add_custom_element("direction", arrow)
	
	# Initialize state
	reset_all()

func _add_custom_element(key: String, node: Control) -> void:
	var wrapper = VBoxContainer.new()
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(node)
	icon_container.add_child(wrapper)
	icons[key] = node

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
	# Force WIDTH and HEIGHT so it doesn't collapse to 0
	texture_rect.custom_minimum_size = Vector2(55, 55)
	
	# Load Texture
	var full_path = asset_path + image_filename
	print("DEBUG: Loading icon from: " + full_path)
	var texture = _load_texture_safe(full_path)
	
	if texture:
		texture_rect.texture = texture
		print("DEBUG: Successfully loaded icon: " + image_filename)
	else:
		push_warning("Icon not found after fallback: " + full_path)
		print("DEBUG: FAILED to load icon: " + image_filename)
		
	texture_rect.tooltip_text = tooltip
	
	wrapper.add_child(texture_rect)
	icon_container.add_child(wrapper)
	
	# Store reference
	icons[key] = texture_rect

func _load_texture_safe(path: String) -> Texture2D:
	# 1. Try Standard Resource Load
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
			
	# 2. Fallback: Load Image from File System (Bypasses Import Cache glitches)
	print("DEBUG: ResourceLoader failed for " + path + ". Trying Image load...")
	var img = Image.new()
	var global_path = ProjectSettings.globalize_path(path)
	var err = img.load(global_path)
	if err == OK:
		return ImageTexture.create_from_image(img)
	else:
		# Fallback 2.5: Try relative path mapping if ProjectSettings fails or runs in editor
		# Sometimes globalize_path is weird.
		print("DEBUG: Image load failed with error " + str(err) + " at " + global_path)
		return null

func update_status(active_effects: Dictionary, play_direction: int) -> void:
	# 1. Update Boolean Effects
	_set_icon_state("locked", active_effects.get("locked", false))
	_set_icon_state("eight_black", active_effects.get("eight_black", false))
	_set_icon_state("eight_red", active_effects.get("eight_red", false))
	_set_icon_state("silence", active_effects.get("silence", false))
	
	# 2. Update Direction Icon
	if icons.has("direction"):
		var icon = icons["direction"]
		if icon.has_method("set_visible"): # Check for base Control method
			# Ensure it's visible (Control property) but our custom "state" logic handled modulate usually?
			# Actually our inner class handles drawing. We don't need _set_icon_state for it unless we modulate it.
			icon.modulate = Color(1, 1, 1, 1) # Always fully visible
			
		if icon is DirectionArrow:
			# Clockwise (1) = Pass Left (Green Left)
			# Counter (-1) = Pass Right (Green Right)
			if play_direction == 1:
				icon.pointing_left = true
			else:
				icon.pointing_left = false

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
