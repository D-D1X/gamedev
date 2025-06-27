extends Node3D

@export var horizontal_acceleration := 2.0
@export var vertical_acceleration := 1.0
@export var min_limit_x: float
@export var max_limit_x: float
@export var mouse_acceleration := 0.005
var is_targeting := false
var current_target: Node3D = null
@onready var skin = $"../GodetteSkin"
@onready var player = get_tree().get_first_node_in_group("Player")
var player_is_aiming := false

func _process(delta: float) -> void:
	if Globals.player_dead: return
	player_is_aiming = player and player.is_aiming

	if player_is_aiming:
		return
	if is_targeting and is_instance_valid(current_target) and Input.is_action_pressed("lock_on"):
		var direction = (current_target.global_position - global_position).normalized()
		var target_rotation = atan2(-direction.x, -direction.z)
		var player_rotation = atan2(direction.x, direction.z)
		var damping_factor = pow(0.05, delta)
		rotation.y = lerp_angle(rotation.y, target_rotation, 1.0 - damping_factor)
		skin.rotation.y = lerp_angle(skin.rotation.y, player_rotation, delta * 20.0)
		
		if Globals.controller:
			var joy_input = Input.get_action_strength("pan_up") - Input.get_action_strength("pan_down")
			rotation.x -= joy_input * delta * -vertical_acceleration

		# Clamp the vertical angle
		rotation.x = clamp(rotation.x, min_limit_x, max_limit_x)
	else:
		if !is_instance_valid(current_target):
			current_target = null
			is_targeting = false
		if Globals.controller:
			if Globals.camera_locked: return
			var joy_dir = Input.get_vector("pan_left","pan_right","pan_up","pan_down")
			rotate_from_vector(joy_dir * delta * Vector2(horizontal_acceleration, vertical_acceleration))

func _input(event: InputEvent) -> void:
	if Globals.camera_locked or player_is_aiming: return
	if not Globals.controller:
		if event is InputEventMouseMotion and not Globals.chest_opening:
			rotation.x -= event.relative.y * mouse_acceleration
			rotation.x = clamp(rotation.x, min_limit_x, max_limit_x)
			if not is_targeting:
				rotation.y -= event.relative.x * mouse_acceleration

func pivot_camera():
	if not Globals.entity_nearby:
		Globals.camera_locked = true
		
		# Get current rotation values
		var current_rot = global_transform.basis.get_euler()
		
		# Calculate the target Y rotation (horizontal rotation around player)
		# Use the player's forward direction for the Y rotation
		var target_y_rot = atan2(-skin.global_transform.basis.z.x, -skin.global_transform.basis.z.z)
		
		# Create a target rotation that preserves current X value (within limits)
		# Clamp X rotation to ensure it stays within spring arm limits
		var target_rot = Vector3(
			clamp(current_rot.x, -0.8, -0.2),  # Keep within min/max limits
			target_y_rot,  # Rotate horizontally to face behind player
			0  # Keep Z rotation at 0
		)
		
		# Create a tween to rotate the spring arm
		var tween = create_tween()
		tween.tween_method(
			func(t: float):
				# Interpolate between rotations
				var interp_rot = Vector3(
					lerp(current_rot.x, target_rot.x, t),
					lerp_angle(current_rot.y, target_rot.y, t),
					0
				)
				global_transform.basis = Basis.from_euler(interp_rot)
				,
				0.0,
				1.0,
				0.5
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		await tween.finished
		
		# Final adjustment to ensure correct orientation
		global_transform.basis = Basis.from_euler(target_rot)
		
		Globals.camera_locked = false


func rotate_from_vector(v: Vector2):
	if not Globals.player_dead and not Globals.chest_opening:
		if v.length() == 0: return
		rotation.y -= v.x
		rotation.x -= v.y
		rotation.x = clamp(rotation.x, min_limit_x, max_limit_x)


func _on_player_targeting(targeting: bool, current: Node3D) -> void:
	is_targeting = targeting
	current_target = current
