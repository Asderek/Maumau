extends Sprite2D

class_name Die

signal roll_finished(value: int)

# Config
@export var rotation_speed: float = 15.0 # Radians per second
@export var roll_duration: float = 1.0
@export var shake_intensity: float = 10.0

var _is_rolling: bool = false
var _time_elapsed: float = 0.0
var _final_value: int = 1
var _target_frame: int = 0

func _ready() -> void:
	# Setup spritesheet properties manually if not set in editor
	# Vertical Strip 1x6
	hframes = 6
	vframes = 1
	frame = 0
	# Center pivot usually default for Sprite2D

func roll(target_value: int) -> void:
	if _is_rolling: return
	
	_is_rolling = true
	_time_elapsed = 0.0
	_final_value = clamp(target_value, 1, 6)
	
	# Map value 1-6 to frame index
	# Assuming spritesheet is 1 2 3 (row 1), 4 5 6 (row 2)
	# So indices: 0, 1, 2, 3, 4, 5
	_target_frame = _final_value - 1
	
	set_process(true)
	
func _process(delta: float) -> void:
	if not _is_rolling:
		set_process(false)
		return
		
	_time_elapsed += delta
	
	# Phase 1: Rolling
	if _time_elapsed < roll_duration:
		# Random frame swap
		if Engine.get_frames_drawn() % 5 == 0: # Swap every few frames
			frame = randi() % 6
			
		# Rotation
		rotation += rotation_speed * delta
		
		# Shake / Jitter position
		# position = initial_pos + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
		
	else:
		# Phase 2: Stop
		_is_rolling = false
		frame = _target_frame
		rotation = 0 # Snap to upright? or keep random angle? User said "rotate on its axis".
		# Let's snap to 0 for readability or nearest 90 degrees?
		# Let's do a tween to 0 for polish.
		
		var tween = create_tween()
		tween.tween_property(self, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): emit_signal("roll_finished", _final_value))
