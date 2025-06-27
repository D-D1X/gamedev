extends Camera3D


@export var player : Node3D
var offset : Vector3
var map_mode := false
var fixed_y: float
@export var bounds_min = Vector3(-200, 0, -100)
@export var bounds_max = Vector3(200, 0, 375)

func _ready() -> void:
	if get_tree().current_scene.name == "Overworld":
		global_position = player.global_position
		global_position.y += 105
	offset = global_position - player.global_position
	fixed_y = global_position.y


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if map_mode:
		var move = Vector3.ZERO
		if Input.is_action_pressed("ui_right"):
			move.z += 1
		if Input.is_action_pressed("ui_left"):
			move.z -= 1
		if Input.is_action_pressed("ui_down"):
			move.x -= 1
		if Input.is_action_pressed("ui_up"):
			move.x += 1
		global_translate(move * delta * 50)
		global_position.x = clamp(global_position.x, bounds_min.x, bounds_max.x)
		global_position.z = clamp(global_position.z, bounds_min.z, bounds_max.z)
	else:
		if not player.jumping:
			global_position = player.global_position + offset
		else:
			var target_position = player.global_position + offset
			target_position.y = fixed_y
			global_position = target_position
