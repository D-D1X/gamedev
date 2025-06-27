extends CharacterBody3D

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var player_detection = get_tree().get_first_node_in_group("PlayerDetection")
@onready var raycast = $LineOfSight/RayCast3D
@onready var raycast_2 = $LineOfSight/RayCast3D2
@onready var terrain_raycast = $LineOfSight/TerrainRayCast3D
@onready var skin = $WarriorSkin
@onready var nav := $NavigationAgent3D
@export var patrol_zone: Area3D
@onready var flash_loop_running := false
var speed := 2.0
var rotation_speed := 2.0
var sweep_speed := 8.0
var sweep_range := 4.0
var sweep_direciton := 1
var idle_walk_timer := 0.0
var idle_pause_timer := 0.0
var attack_timer := 2.5
var is_paused := false
var invulnerable := false
var idle_walk_direction := Vector3.ZERO
var direction: Vector3
enum EnemyState { IDLE, CHASING, ATTACKING, BLOCKING, HIT }
var in_range := false
var in_reach := false
var attacking := false
var gravity := 9.8
var hit_stun := false
var blocking := false
var action_cooldown := 0.0
var initial_position := Vector3.ZERO
var hp := 5
var dead := false
var chosen_attack : String
var being_revived := false
var current_state: EnemyState = EnemyState.IDLE
var move_state := "Idle"
var last_known_player_position: Vector3
var hit_direction: Vector3
var last_position: Vector3
var is_returning_to_zone := false
var navigation_ready := false
var stuck_threshold := 10.0
var stuck_timer := 0.0
var current_target: Vector3
var is_in_temporary_move: bool = false
var awake : bool = true
var knockback_velocity := Vector3.ZERO
var is_knocked_back := false
var knockback_timer := 0.5
var circle_angle: float = 0.0
var surround_radius: float = 3.0 
var separation_force_strength: float = 1.5
var chase_timer = Timer.new()
var burn := false
var frozen := false
var icon
var icon2
var detected := false
var checked := false
var sidestep_velocity := Vector3.ZERO
var sidestep_timer := 0.0
var sidestep_duration := 0.8
var is_sidesteping := false
var chasing := false

signal is_dead
signal enemy_detected
signal enemy_left

func _ready() -> void:
	icon = skin.get_node("Icon")
	icon2 = skin.get_node("Icon2")
	if is_in_group("Predead"):
		icon.hide()
		icon2.hide()
	await get_tree().process_frame
	chase_timer.one_shot = true
	chase_timer.connect("timeout", _on_chase_update_timer_timeout)
	add_child(chase_timer)
	set_state(EnemyState.IDLE)
	$Effects.hide()
	$Revive.hide()
	raycast.enabled = true
	raycast_2.enabled = true
	skin.set_defend_state("Idle_Combat")
	nav.set_navigation_map(get_world_3d().navigation_map)
	set_new_patrol_target()
	last_position = global_transform.origin

func set_state(new_state: EnemyState):
	# Handle valid state transitions
	if new_state != current_state:
		print("Changing state from %s to %s" % [EnemyState.keys()[current_state], EnemyState.keys()[new_state]])
		current_state = new_state
		enter_state(new_state)
	else:
		print("Invalid state transition from %s to %s" % [EnemyState.keys()[current_state], EnemyState.keys()[new_state]])
		
func enter_state(new_state: EnemyState):
	match new_state:
		EnemyState.IDLE:
			update_move_state("Idle")
		EnemyState.CHASING:
			update_move_state("Walking")
			circle_angle = randf_range(0, 2*PI)	
			chase_timer.wait_time = randf_range(1.0, 2.0)
			chase_timer.start()
		EnemyState.ATTACKING:
			pass
		EnemyState.BLOCKING:
			pass
			
func _process(_delta: float) -> void:
	if is_in_group("Predead"):
		return
	var group = get_parent()
	var mage_alive = false

	# Check if any mage siblings are still alive
	for child in group.get_children():
		if child.name.begins_with("Mage") and child.is_inside_tree() and not child.is_queued_for_deletion():
			if child.has_method("check_if_dead") and not child.check_if_dead():
				mage_alive = true
				break

	# If no mage is alive and this warrior is still in the "WithMage" group, remove it
	if not mage_alive and is_in_group("WithMage"):
		remove_from_group("WithMage")
	if not mage_alive and dead:
		dead = false
		await fade_out_effect()
		call_deferred("queue_free")

func _physics_process(delta: float) -> void:
	if is_knocked_back:
		velocity = knockback_velocity
		move_and_slide()
		return
	if not awake or is_in_group("Predead") or not Globals.scene_ready:
		return
	velocity.y -= gravity * delta
	if frozen:
		update_move_state("Freeze")
		velocity.x = 0
		velocity.z = 0
		is_in_temporary_move = false  
	else:
		if is_sidesteping:
			velocity = sidestep_velocity
			sidestep_timer -= delta
			if sidestep_timer <= 0:
				is_sidesteping = false
				is_in_temporary_move = false
				velocity = Vector3.ZERO
				if current_state == EnemyState.ATTACKING:
					update_move_state("Idle_Combat")
				else:
					update_move_state("Idle")
		else:
			if Globals.player_dead: current_state = EnemyState.IDLE
			match current_state:
				EnemyState.IDLE:
					process_idle(delta)
				EnemyState.CHASING:
					process_chasing(delta)
				EnemyState.ATTACKING:
					process_attacking(delta)
				EnemyState.BLOCKING:
					process_blocking(delta)
	move_and_slide()

func update_move_state(new_move_state: String):
	if move_state != new_move_state:
		print("Updating move state to: ", new_move_state)
		move_state = new_move_state
		skin.set_move_state(new_move_state)

func update_animations():
	# Handle combat stance transitions
	var combat_state = "Idle_Combat" if in_reach and (current_state == EnemyState.ATTACKING or current_state == EnemyState.BLOCKING) else move_state
	skin.set_move_state(combat_state)

func process_idle(delta: float) -> void:
	if detected and not checked and not in_range:
		print("idle detection")
		checked = true
		$Timers/DetectTimer.start()
	# idle behavior
	speed = 2.0
	handle_idle_behavior(delta)
		
	# raycast sweeping logic
	var new_target_pos = raycast.target_position
	var new_target_pos_2 = raycast_2.target_position
	
	new_target_pos.x += sweep_speed * sweep_direciton * delta
	new_target_pos_2.x += sweep_speed * -sweep_direciton * delta
	
	if new_target_pos.x > sweep_range:
		new_target_pos.x = sweep_range
		new_target_pos_2.x = -sweep_range
		sweep_direciton = -1
	elif new_target_pos.x < -sweep_range:
		new_target_pos.x = -sweep_range
		new_target_pos_2.x = sweep_range
		sweep_direciton = 1
	
	raycast.target_position = new_target_pos
	raycast_2.target_position = new_target_pos_2
	
	var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
	
	if raycast.is_colliding() and (raycast.get_collider() == player or raycast.get_collider() == player_detection) and not Globals.player_dead:
		if distance_to_player < 6.0:
			set_state(EnemyState.ATTACKING)
			$Timers/ChangeTimer.start()
		else:
			chasing = true
			set_state(EnemyState.CHASING)
	
	if raycast_2.is_colliding() and (raycast.get_collider() == player or raycast.get_collider() == player_detection) and not Globals.player_dead:
		if distance_to_player < 6.0:
			set_state(EnemyState.ATTACKING)
			$Timers/ChangeTimer.start()
		else:
			chasing = true
			set_state(EnemyState.CHASING)
			
func handle_idle_behavior(delta):
	if is_paused or !patrol_zone:
		return
	if nav.is_navigation_finished():
		is_paused = true
		update_move_state("Idle")
		velocity.x = 0.0
		velocity.z = 0.0
		await get_tree().create_timer(3.0).timeout
		set_new_patrol_target()
		is_paused = false
	
	var next_path_pos = nav.get_next_path_position()
	direction = global_position.direction_to(next_path_pos)

	if direction != Vector3.ZERO:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
		var new_velocity = direction * speed
		nav.set_velocity(new_velocity)
		update_move_state("Walking")
	
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
	if !patrol_zone:
		print("No patrol zone assigned!")
		return
		
	var shape = patrol_zone.get_child(0).shape
	var random_point = Vector3.ZERO

	# Get random point within zone bounds (simplified)
	if shape is BoxShape3D:
		var extents = shape.size / 2.0
		random_point = patrol_zone.global_position + Vector3(
			randf_range(-extents.x, extents.x),
			0,
			randf_range(-extents.z, extents.z)
		)
	elif shape is SphereShape3D:
		var radius = shape.radius
		var angle = randf_range(0.0, TAU)
		var distance = sqrt(randf()) * radius
		random_point = patrol_zone.global_position + Vector3(
			cos(angle) * distance,
			0,
			sin(angle) * distance
		)
	else:
		print("Unsupported shape for patrol zone: ", shape)
		return
	
	# Get valid navigation point
	current_target = NavigationServer3D.map_get_closest_point(
		get_world_3d().navigation_map,
		random_point
	)
	
	print("New patrol target set to: ", current_target)
	nav.target_position = current_target
	
func process_chasing(delta: float) -> void:
	if not detected:
		detected = true
		emit_signal("enemy_detected")
	speed = 3.0
	# calculate the direction to the player
	var player_pos = player.global_position
	var offset = Vector3(cos(circle_angle), 0, sin(circle_angle)) * surround_radius
	nav.target_position = player_pos + offset
	
	# Get separation force and adjust direction
	var separation = calculate_separation_force()
	var next_path_pos = nav.get_next_path_position()
	var target_dir = (next_path_pos - global_position).normalized()
	direction = (target_dir + separation).normalized()
	
	# Rotate towards movement direction
	if direction != Vector3.ZERO:
		var target_rot = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	
	# Apply velocity
	if chasing:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Periodically adjust angle to prevent clustering
	if chase_timer.is_stopped():
		chase_timer.start(randf_range(1.0, 2.0))

func calculate_separation_force() -> Vector3:
	var force = Vector3.ZERO
	var separation_distance = 2.0  # Check within 2 meters
	var enemies = get_tree().get_nodes_in_group("Entity")  # Ensure enemies are in this group
	
	for enemy in enemies:
		if enemy != self && is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < separation_distance && dist > 0:
				var push_dir = (global_position - enemy.global_position).normalized()
				force += push_dir * (1.0 - dist/separation_distance) * separation_force_strength
	return force
	
func _on_chase_update_timer_timeout() -> void:
	print("Timeout")
	# Randomly adjust angle to create movement variation
	circle_angle += randf_range(-PI/4, PI/4)  # Adjust up to 45 degrees
	circle_angle = wrapf(circle_angle, 0, 2*PI) 
	
func process_attacking(delta: float) -> void:
	chasing = false
	if not detected:
		detected = true
		emit_signal("enemy_detected")
	blocking = false
	skin.set_defend_state("Idle_Combat")
	if not is_in_temporary_move:
		direction = (player.global_transform.origin - global_transform.origin).normalized()
		var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin) 
		if distance_to_player >= 4.0:
			update_move_state("Walking")
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			update_move_state("Idle_Combat")
			velocity.x = 0
			velocity.z = 0 
	else:
		velocity.x = 0
		velocity.z = 0 
	# rotate
	var target_rotation = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed*delta)
	
	if attacking:
		return
	if not invulnerable:
		attack_timer -= delta
		if attack_timer <= 0:
			attack_timer = randf_range(3.0, 5.0)
			initial_position = global_transform.origin
			attacking = true
			chosen_attack = skin.attack()
			print("Chosen attack: ", chosen_attack)
			if chosen_attack == "Nill":
				print("attack_failed")
				attacking = false
				skin.attacking = false
				$WarriorSkin/AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

			await get_tree().create_timer(0.1).timeout
			if chosen_attack in ["Jump_Chop", "Chop", "Slash"]:
				print("moving")
				move_towards_player()
		
func process_blocking(delta: float) -> void:
	chasing = false
	if not detected:
		detected = true
		emit_signal("enemy_detected")
	if not invulnerable:
		if not is_in_temporary_move:
			velocity.x = 0
			velocity.z = 0 
			direction = (player.global_transform.origin - global_transform.origin).normalized()
			var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin) 
			# If player is too close, back up
			if distance_to_player < 2.5:
				update_move_state("Walking")
				var move_direction = -direction * speed * 0.8
				velocity = Vector3(move_direction.x, 0, move_direction.z)
			else:
				update_move_state("Idle")
		# rotate
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed*delta)

		
		if not blocking:
			blocking = true
			skin.set_defend_state("Blocking")
			skin.defend(true, hp)
			await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
			blocking = false
			skin.defend(false, hp)
			skin.set_defend_state("Idle_Combat")

func choose_new_idle_direction() -> void:
	idle_walk_direction = get_random_idle_direction()
	idle_walk_timer = randf_range(2.0, 5.0)

func get_random_idle_direction() -> Vector3:
	var random_angle = randf() * PI * 2
	return Vector3(sin(random_angle), 0, cos(random_angle)).normalized() 

func move_in_idle_direction(delta: float) -> void:
	if idle_walk_direction != Vector3.ZERO: 
		velocity.x = idle_walk_direction.x * speed
		velocity.z = idle_walk_direction.z * speed
		var target_rotation = atan2(idle_walk_direction.x, idle_walk_direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func check_obstacles() -> void:
	if terrain_raycast.is_colliding():
		idle_walk_direction = get_random_idle_direction()

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		in_range = false
		if current_state == EnemyState.CHASING:
			chasing = false
			update_move_state("Cheer")
			await get_tree().create_timer(1.6).timeout
			update_move_state("Idle_Combat")
			await get_tree().create_timer(2.0).timeout
			if not in_range:
				set_state(EnemyState.IDLE)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		in_range = true
		if current_state == EnemyState.CHASING:
			update_move_state("Walking")
		

func _on_stop_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		in_reach = true
		#print("Stop area entered")
		if current_state == EnemyState.CHASING:
			set_state(EnemyState.ATTACKING)
			$Timers/ChangeTimer.start()
			$Timers/StrafeTimer.start()

func _on_stop_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		if current_state == EnemyState.ATTACKING or current_state == EnemyState.BLOCKING:
			chasing = true
			set_state(EnemyState.CHASING)
		in_reach = false
		$Timers/ChangeTimer.stop()
		
func projectile_hit(_hit_position: Vector3):
	hit()
	
func fireball_hit() -> void:
	burn = true
	if frozen:
		frozen = false
		skin.clear_frozen()
	hit()
	if not dead:
		start_burn_flash()
	var i = 0
	while i < 2 and not dead:
		await get_tree().create_timer(2.5).timeout
		hit()
		i += 1
	burn = false

func start_burn_flash() -> void:
	spawn_flash_loop()

func spawn_flash_loop() -> void:
	if flash_loop_running:
		return # already flashing
	flash_loop_running = true
	call_deferred("_flash_loop")

func _flash_loop() -> void:
	while burn:
		skin.flash_red()
		await get_tree().create_timer(0.8).timeout # flash every 0.8 seconds
	flash_loop_running = false
	
func iceball_hit() -> void:
	if frozen: return
	if burn:
		burn = false
	frozen = true
	hit()
	update_move_state("Idle_Combat")
	if hp > 0:
		skin.frozen()
	$Timers/FreezeTimer.start()
		
func hit(amount:=1) -> void:
	if invulnerable:
		return
	hp -= amount
	invulnerable = true
	hit_stun = true
	velocity = Vector3.ZERO
	if hp > 0:
		$Audio/Hit.play()
		on_squish_and_stretch(1.2,0.15)
		skin._on_hit()
		$Timers/InvulTimer.start()
	if hp <= 0:
		$Audio/Die.play()
		if frozen:
			frozen = false
			skin.clear_frozen()
		die()
		
func face_direction(f_direction: Vector3):
	var target_rotation = atan2(f_direction.x, f_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * get_physics_process_delta_time())

func die() -> void:
	icon.hide()
	icon2.hide()
	$Timers/ChangeTimer.stop()
	if current_state != EnemyState.IDLE:
		emit_signal("enemy_left")
	if is_in_group("WithMage"):
		dead = true
		set_physics_process(false)
		$Timers/BlockTimer.stop()
		$Timers/ChangeTimer.stop()
		$Timers/StrafeTimer.stop()
		$CollisionShape3D.call_deferred("set_disabled", true)
		await get_tree().physics_frame
		skin.death(true)
		skin.set_death_state("Death")
		await get_tree().create_timer(2).timeout
		skin.set_death_state("Death_Pose")
	elif is_in_group("Predead"):
		dead = true
		set_physics_process(false)
		$Timers/BlockTimer.stop()
		$Timers/ChangeTimer.stop()
		$Timers/StrafeTimer.stop()
		# Do NOT disable collision for Predead skeletons
		collision_layer = 0
		await get_tree().physics_frame
		
		skin.death(true)
		skin.set_death_state("Death")
		await get_tree().create_timer(2).timeout
		skin.set_death_state("Death_Pose")
	else:
		dead = true
		$Arrow.hide()
		emit_signal("is_dead")
		set_physics_process(false)
		set_process(false)
		var bone = skin.get_node("Rig/Skeleton3D/RightHandSlot/Bone")
		bone.queue_free()
		collision_layer = 0
		collision_mask = 0
		$CollisionShape3D.set_deferred("disabled", true)
		await get_tree().physics_frame
		remove_from_group("Entity")
		skin.death(true)
		skin.set_death_state("Death")
		print("die function called")
		# Start the fade effect
		await fade_out_effect()
		print("fade out complete")
		# Finally remove the mage
		queue_free()

func fade_out_effect():
	print("Fade out effect")
	# Get all mesh instances in the skin
	var meshes = get_all_meshes($WarriorSkin)
	var materials = []
	
	# Duplicate materials to avoid affecting other instances
	for mesh in meshes:
		for surface in range(mesh.get_surface_override_material_count()):
			var mat = mesh.get_surface_override_material(surface)
			if mat == null:
				mat = mesh.mesh.surface_get_material(surface)
				print("Using default material for:", mesh.name)
			if mat is StandardMaterial3D:
				print("Found material on", mesh.name)
				var new_mat = mat.duplicate()
				new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				new_mat.flags_transparent = true
				new_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
				mesh.set_surface_override_material(surface, new_mat)  # Ensure material is reassigned
				materials.append(new_mat)
			else:
				print("No valid material found for", mesh.name)	
	if materials.is_empty():
		push_warning("No materials found for fading")
		queue_free()
		return
		
	print("Materials successfully assigned. Starting fade to black...")
	# Create fade tween
	var tween = create_tween().set_parallel(true)
	tween.tween_interval(1.0)  # Short delay before fading
	
	# First: Fade to black
	for mat in materials:
		tween.tween_property(mat, "albedo_color", Color.BLACK, 2.0)
	
	await tween.finished
	print("Blackout complete. Starting transparency fade...")
	$Particles/Death.emitting = true
	$Effects.show()
	$Effects/AnimatedSprite3D.play("death")
	$Audio/Puff.play()
	drop_items()
	# Second: Fade transparency
	var tween2 = create_tween().set_parallel(true)
	for mat in materials:
		tween2.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	
	await tween2.finished
	await get_tree().create_timer(3.0).timeout
	print("Fade complete")

func get_all_meshes(node: Node) -> Array:
	var meshes = []
	if node is MeshInstance3D:
		print("Found mesh:", node.name)
		meshes.append(node)
	for child in node.get_children():
		meshes.append_array(get_all_meshes(child))
	return meshes
	
func drop_items():
	var item_scenes = [
		preload("res://scenes/items/green_rupee.tscn"),
		preload("res://scenes/items/mana_bottle.tscn"),
		preload("res://scenes/items/heart.tscn")
	]
	
	var drop_position = $WarriorSkin.global_transform.origin if is_inside_tree() else global_transform.origin

	for i in range(randi() % 3 + 1):
		var item_scene = item_scenes[randi() % item_scenes.size()]
		var item = item_scene.instantiate()
		
		# Special handling for hearts
		if item.item_type == "heart":
			item.mass = 0.3  # Make hearts lighter
			item.apply_impulse(Vector3(
				randf_range(-0.5, 0.5),  # Less horizontal spread
				randf_range(4, 6),     # Higher upward force
				randf_range(-0.5, 0.5)
			))
			item.apply_torque_impulse(Vector3(
				randf_range(-0.2, 0.2),  # Gentle rotation
				randf_range(-0.1, 0.1),
				randf_range(-0.2, 0.2)
			))
		else:
			item.mass = 0.6
			item.apply_impulse(Vector3(
				randf_range(-2.0, 2.0),
				randf_range(6, 8),
				randf_range(-2.0, 2.0)
			))
			item.apply_torque_impulse(Vector3(
				randf_range(-1, 1),
				randf_range(-0.5, 0.5),
				randf_range(-1, 1)
			))
		
		var item_container = get_tree().current_scene.get_node("Items")
		item_container.add_child(item)
		item.global_transform.origin = drop_position

func check_if_dead() -> bool:
	return hp <= 0

func mark_for_resurrection(value: bool) -> void:
	being_revived = value	
	
func revive() -> void:
	dead = false
	skin.set_death_state("Ressurect")
	$Audio/Revive.play()
	await get_tree().create_timer(2.7).timeout
	skin.set_death_state("Idle_Combat")
	skin.death(false)
	hp = 5
	if is_in_group("Predead"):
		remove_from_group("Predead")
	set_state(EnemyState.IDLE)
	set_physics_process(true)
	set_process(true)
	$CollisionShape3D.disabled = false
	collision_layer = 4
	collision_mask = 15
	being_revived = false
	icon.show()
	icon2.show()
	$Timers/StrafeTimer.start()
	$Timers/InvulTimer.start()

func _on_invul_timer_timeout() -> void:
	invulnerable = false
	hit_stun = false
	if in_reach:
		set_state(EnemyState.BLOCKING)
		$Timers/ChangeTimer.start()
	elif in_range and not in_reach:
		chasing = true
		set_state(EnemyState.CHASING)
	else:
		set_state(EnemyState.IDLE)


func on_squish_and_stretch(value: float, duration: float = 0.1):
	var tween = create_tween()
	tween.tween_property(skin, "squish_and_stretch", value, duration)
	tween.tween_property(skin, "squish_and_stretch", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)
	
func move_towards_player(): 
	if frozen: return
	is_in_temporary_move = true
	var attack_tween = create_tween()
	if chosen_attack == 'Jump_Chop':
		attack_tween.tween_property(self, "global_position", player.global_position - direction * 1.75, 1.0)
	else:
		attack_tween.tween_property(self, "global_position", player.global_position - direction * 1.5, 0.3)
	await attack_tween.finished
	move_back_to_position()

func move_back_to_position():
	var retreat_tween = create_tween()
	update_move_state("Walking")
	if chosen_attack == 'Jump_Chop':
		retreat_tween.tween_property(self, "global_position", initial_position, 1.0)
	else:
		retreat_tween.tween_property(self, "global_position", initial_position, 0.6)
	await retreat_tween.finished
	if current_state == EnemyState.ATTACKING:
		update_move_state("Idle_Combat") 
	elif current_state == EnemyState.CHASING:
		update_move_state("Walking")
	else:
		update_move_state("Idle")
	attacking = false
	is_in_temporary_move = false

func sidestep():
	if (current_state == EnemyState.ATTACKING or current_state == EnemyState.BLOCKING) and not attacking and not dead and not frozen:
		is_sidesteping = true
		is_in_temporary_move = true
		sidestep_timer = sidestep_duration
		
		var direction_to_player = (player.global_transform.origin - global_transform.origin).normalized()
		var strafe_dir = direction_to_player.cross(Vector3.UP).normalized()
		
		if randi_range(0, 1) == 0:
			strafe_dir *= -1
			update_move_state("Strafe_Left")
		else:
			update_move_state("Strafe_Right")
		
		sidestep_velocity = strafe_dir * 3.5


func _on_warrior_skin_blocked(body) -> void:
	if body.is_in_group("PWeapon"):
		#print(body)
		if skin.defend_state_machine.get_current_node() == "Blocking":
			invulnerable = true
			#print(skin)
			velocity = Vector3.ZERO
			skin.set_defend_state("Block_Hit")
			$Timers/BlockTimer.start()

func _on_block_timer_timeout() -> void:
	invulnerable = false
	if blocking and current_state == EnemyState.BLOCKING:
		skin.set_defend_state("Blocking")

func _on_change_timer_timeout() -> void:
	if in_reach:
		if randi_range(0, 20) < 17:
			set_state(EnemyState.ATTACKING)
			skin.defend(false, hp)
			$Timers/ChangeTimer.wait_time = randf_range(3.0, 7.0)
		else:
			set_state(EnemyState.BLOCKING)
			$Timers/ChangeTimer.wait_time = randf_range(2.0, 4.0)
		
	
	$Timers/ChangeTimer.start()

func take_damage(amount: int, knockback: Vector3):
	hit(amount)
	# Apply knockback
	knockback_velocity = knockback
	is_knocked_back = true
	await get_tree().create_timer(knockback_timer).timeout
	is_knocked_back = false

func _on_strafe_timer_timeout() -> void:
	if dead or frozen: return
	if randi_range(0, 10) < 8:
		sidestep()
	$Timers/StrafeTimer.wait_time = randf_range(3.0, 7.0)
	$Timers/StrafeTimer.start()
	
func _on_freeze_timer_timeout() -> void:
	frozen = false
	skin.clear_frozen()

func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	if not dead:
		var blend_weight = 0.3
		velocity.x = lerp(velocity.x, safe_velocity.x, blend_weight)
		velocity.z = lerp(velocity.z, safe_velocity.z, blend_weight)


func _on_detect_timer_timeout() -> void:
	checked = false
	detected = false
	emit_signal("enemy_left")

func is_engaged() -> bool:
	return not current_state == EnemyState.IDLE and not dead
