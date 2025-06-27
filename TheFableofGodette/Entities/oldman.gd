extends CharacterBody3D

@onready var player := get_tree().get_first_node_in_group("Player")
@onready var ui := get_tree().get_first_node_in_group("UI")
@onready var skin := $OldmanSkin
@onready var nav := $NavigationAgent3D
@export var patrol_zone: Area3D
@export var shop_position : Node3D
var dialogue := ["Take a look at what I have in stock for you!", "Im sure these items will come in handy on your journey", "All sales are final by the way"]
var last_position : Vector3
var original_position : Vector3
var is_returning_to_zone := false
var navigation_ready := false
var stuck_threshold := 10.0
var stuck_timer := 0.0
var is_paused := false
var direction: Vector3
var rotation_speed := 2.0
var idle_movement_speed := 0.75
var current_target: Vector3
var speed := 2.0
var gravity := 9.8


func _ready() -> void:
	if Globals.shop:
		global_position = shop_position.global_position
		rotation.y = -45
	await get_tree().process_frame
	original_position = global_transform.origin
	set_new_patrol_target()
	last_position = global_transform.origin
	
func _on_cutscene_triggered(cinematic: bool) -> void:
	if cinematic:
		velocity = Vector3.ZERO
		skin.set_move_state("Idle")
		nav.set_target_position(global_position)
		is_paused = true
	else:
		is_paused = false
		set_new_patrol_target()
	
func _physics_process(delta: float) -> void:
	velocity.y -= gravity * delta
	if Globals.cinematic: 
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	if not Globals.shop:
		handle_idle_behavior(delta)
		move_and_slide()
	
func handle_idle_behavior(delta):
	if is_paused or !patrol_zone:
		return
	if nav.is_navigation_finished():
		skin.set_move_state("Idle")
		is_paused = true
		velocity.x = 0.0
		velocity.z = 0.0
		await get_tree().create_timer(3.0).timeout
		set_new_patrol_target()
		is_paused = false
	
	var next_path_pos = nav.get_next_path_position()
	direction = next_path_pos - global_position
	direction.y = 0
	
	if direction.length() > 0.1 and not Globals.cinematic:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
		
		# Move directly toward the path target
		var horizontal_velocity = direction.normalized() * idle_movement_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		move_and_slide()
		
		skin.set_move_state("Walking")
	else:
		skin.set_move_state("Idle")
		velocity.x = 0
		velocity.z = 0
	
	var distance_moved = global_transform.origin.distance_to(last_position)
	if distance_moved < 0.01:  # adjust threshold as needed
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_transform.origin
	
	if stuck_timer > stuck_threshold and !has_reached_target():
		print("Stuck! Recovering and assigning new target...")
		recover_from_stuck()
		set_new_patrol_target()
		stuck_timer = 0.0 
		
func has_reached_target() -> bool:
	var target_position = nav.get_next_path_position()
	return global_transform.origin.distance_to(target_position) < 1.0

func recover_from_stuck():
	# Apply a random force or change direction
	velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * speed

func set_new_patrol_target():
	if !patrol_zone or !is_instance_valid(patrol_zone):
		print("NO ZONE")
		return
	
	var zone_shape = patrol_zone.get_child(0).shape
	if zone_shape is BoxShape3D:
		var extents = zone_shape.size / 2.0
		var attempts = 5
		var found_point = false
		
		for i in range(attempts):
			var random_point = patrol_zone.global_position + Vector3(
				randf_range(-extents.x, extents.x),
				0,
				randf_range(-extents.z, extents.z)
			)
			var closest_point = NavigationServer3D.map_get_closest_point(
				nav.get_navigation_map(),
				random_point
			)
			if closest_point != Vector3.ZERO:
				current_target = closest_point
				nav.target_position = current_target
				found_point = true
				break
		
		if not found_point:
			print("Failed to find a valid patrol target within patrol zone.")


func talk():	
	is_paused = true
	velocity.x = 0
	velocity.z = 0
	skin.set_move_state("Idle")
	direction = (player.global_position - global_position).normalized()
	var target_rot = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 0.2)
	ui.dialogue(dialogue)

func emote():
	skin.set_emote()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		skin.in_range = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		skin.in_range = false

#func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	#var blend_weight = 0.3
	#velocity.x = lerp(velocity.x, safe_velocity.x, blend_weight)
	#velocity.z = lerp(velocity.z, safe_velocity.z, blend_weight)

func idle():
	skin.set_move_state("Idle")

func shock():
	skin.hide_axe()
	var tween = create_tween()
	tween.tween_method(skin._shock_trans, 0.0, 1.0, 0.5)

func sit():
	var tween = create_tween()
	tween.tween_method(skin._shock_trans, 1.0, 0.0, 0.1)
	var axe2 = skin.get_node("axe_1handed2")
	axe2.hide()
	skin.set_move_state("Sit_Chair_Idle")

func reset_position():
	await get_tree().process_frame
	skin.reset_axe()
	global_position = original_position

func cheer():
	skin.cheer()
	var cheer = skin.get_node("Cheer")
	cheer.play()
	


func _on_ui_close_dialogue() -> void:
	if not Globals.shop:
		is_paused = false
		set_new_patrol_target()
