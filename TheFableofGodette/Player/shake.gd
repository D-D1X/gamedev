extends Node3D

var shake_magnitude = 0.05
var shake_duration = 0.3
var shake_timer = 0.0
var original_rotation: Vector3

func _ready():
	original_rotation = rotation
	set_process(false)

func start_shake(duration: float = 0.3, magnitude: float = 0.05):
	shake_duration = duration
	shake_magnitude = magnitude
	shake_timer = duration
	original_rotation = rotation
	set_process(true)

func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		var rot_offset = Vector3(
			randf_range(-shake_magnitude, shake_magnitude),
			randf_range(-shake_magnitude, shake_magnitude),
			0 # keep Z at 0 unless you want camera tilt
		)
		rotation = original_rotation + rot_offset
	else:
		rotation = original_rotation
		set_process(false)
