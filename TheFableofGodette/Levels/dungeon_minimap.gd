extends Camera3D


@export var player : Node3D
var offset : Vector3
var map_mode := false
var fixed_y: float
@export var bounds_min = Vector3(-200, 0, -100)
@export var bounds_max = Vector3(200, 0, 375)
@export var floor_heights := [Vector3(0,50,0), Vector3(12, 65, 200)]
var current_floor := 0
var floor_bounds := []

func _ready() -> void:
	offset = global_position - player.global_position
	fixed_y = global_position.y
	
	floor_bounds = [
		{ "min": Vector3(-65, 0, -5), "max": Vector3(70, 0, 130) },
		{ "min": Vector3(-65, 0, 180), "max": Vector3(15, 0, 200) },
	]
	
	update_floor_constraints()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if map_mode:
		$SpotLight3D.show()
		for i in $"../../../../../MapUI".get_children():
			i.show()
		if Input.is_action_just_pressed("floor_up"):
			current_floor = clamp(current_floor + 1, 0, floor_heights.size() - 1)
			$"../../../../../MapUI/Label".text = "2F"
			update_floor_constraints()
		if Input.is_action_just_pressed("floor_down"):
			current_floor = clamp(current_floor -1, 0, floor_heights.size() - 1)
			$"../../../../../MapUI/Label".text = "1F"
			update_floor_constraints()
		var move = Vector3.ZERO
		if Input.is_action_pressed("ui_right"):
			move.z += 1
		if Input.is_action_pressed("ui_left"):
			move.z -= 1
		if Input.is_action_pressed("ui_down"):
			move.x -= 1
		if Input.is_action_pressed("ui_up"):
			move.x += 1
		global_translate(move * delta * 25)
		global_position.x = clamp(global_position.x, bounds_min.x, bounds_max.x)
		global_position.z = clamp(global_position.z, bounds_min.z, bounds_max.z)
	else:
		$SpotLight3D.hide()
		for i in $"../../../../../MapUI".get_children():
			i.hide()
		if not player.jumping:
			global_position = player.global_position + offset
		else:
			var target_position = player.global_position + offset
			target_position.y = fixed_y
			global_position = target_position

func recalculate_offset():
	global_position = player.global_position
	global_position.y += 50
	offset = global_position - player.global_position

func update_floor_constraints():
	global_position = floor_heights[current_floor]
	bounds_min = floor_bounds[current_floor]["min"]
	bounds_max = floor_bounds[current_floor]["max"]
	
