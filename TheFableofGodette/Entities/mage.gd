extends CharacterBody3D

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var player_detection = get_tree().get_first_node_in_group("PlayerDetection")
@onready var raycast = $LineOfSight/RayCast3D
@onready var raycast_2 = $LineOfSight/RayCast3D2
@onready var terrain_raycast = $LineOfSight/TerrainRayCast3D
@onready var skin = $Skeleton_Mage_Skin
@onready var nav := $NavigationAgent3D
@onready var flash_loop_running := false
@export var patrol_zone: Area3D
@export var attack_trigger_distance := 8.0
var speed := 2.0
var rotation_speed := 2.0
var sweep_speed := 8.0
var sweep_range := 4.0
var sweep_direciton := 1
var idle_walk_timer := 0.0
var idle_pause_timer := 0.0
var attack_timer := 0.0
var is_paused := false
var idle_walk_direction := Vector3.ZERO
var player_found := false
var direction: Vector3
enum States {IDLE, CHASING, ATTACKING, RESURRECTING}
var current_state := States.IDLE
var res_dis := 5.0
var in_range := false
var in_reach := false
var attacking := false
var gravity := 9.8
var lock_rotation := false
var invulnerable := false
var last_movement_input := Vector2(0,1)
var hp := 7
var dead_warrior: Node3D = null
var resurrecting := false
@export var resurrection_range := 12.0
var last_position: Vector3
var is_returning_to_zone := false
var navigation_ready := false
var stuck_threshold := 10.0
var stuck_timer := 0.0
var current_target: Vector3
var awake := true
var stop := false
var knockback_velocity := Vector3.ZERO
var is_knocked_back := false
var knockback_timer := 0.5
var is_sidestepping := false
var sidestep_direction := Vector3.ZERO
var sidestep_duration := 0.5
var reposition_cooldown := 0.0
var flank_angle := 0.0
var base_flank_distance := 5.0
var burn := false
var frozen := false
var dead := false
var checked := false
var detected := false
var last_state_change := 0.0

signal is_dead
signal spell_cast(type: String, pos: Vector3, direction: Vector2, size: float, caster: Node3D)
signal enemy_detected
signal enemy_left


func _ready() -> void:
	await get_tree().process_frame
	$Effects.hide()
	raycast.enabled = true
	raycast_2.enabled = true
	nav.set_navigation_map(get_world_3d().navigation_map)
	set_new_patrol_target()
	last_position = global_transform.origin
	


func _physics_process(delta: float) -> void:
	if player == null || !is_instance_valid(player):
		set_state(States.IDLE)
		return
	if is_knocked_back:
		velocity = knockback_velocity
		move_and_slide()
		return
	if not awake or not Globals.scene_ready:
		if not stop:
			skin.set_move_state("Idle")
			stop = true
		return
	velocity.y -= gravity * delta
	if check_for_dead_warrior() and current_state != States.RESURRECTING:
		set_state(States.RESURRECTING)
	if Globals.player_dead: current_state = States.IDLE
	if frozen:
		velocity.x = 0
		velocity.z = 0
		skin.set_move_state("Freeze")
	else:
		match current_state:
				States.IDLE:
					resurrecting = false
					process_idle(delta)
				States.CHASING:
					process_chasing(delta)
				States.ATTACKING:
					process_attacking(delta)
				States.RESURRECTING:
					process_resurrecting(delta)
		move_and_slide()			
			
func set_state(new_state: States):
	if current_state == new_state:
		return
		
	var now = Time.get_ticks_msec()
	if now - last_state_change < 500:  # 0.5 second cooldown
		return
	last_state_change = now
	
	match current_state:
		States.RESURRECTING:
			skin.set_move_state("Idle")
			if dead_warrior:
				dead_warrior.mark_for_resurrection(false)
	
	match new_state:
		States.RESURRECTING:
			skin.set_move_state("Walking")
	print("MAGE: switching to: ", current_state)
	current_state = new_state
			
func process_idle(delta: float) -> void:
	if detected and not checked and not in_range:
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
		
	
	if raycast.is_colliding() and (raycast.get_collider() == player or raycast.get_collider() == player_detection)  and not Globals.player_dead:
		if in_reach:
			set_state(States.ATTACKING)
		else:
			set_state(States.CHASING)
			skin.set_move_state("Walking")
	
	if raycast_2.is_colliding() and (raycast.get_collider() == player or raycast.get_collider() == player_detection) and not Globals.player_dead:
		if in_reach:
			set_state(States.ATTACKING)
		else:
			set_state(States.CHASING)
			skin.set_move_state("Walking")

func handle_idle_behavior(delta):
	if is_paused or !patrol_zone:
		return
	if nav.is_navigation_finished():
		is_paused = true
		skin.set_move_state("Idle")
		velocity.x = 0.0
		velocity.z = 0.0
		await get_tree().create_timer(3.0).timeout
		set_new_patrol_target()
		is_paused = false
	
	var next_path_pos = nav.get_next_path_position()
	direction = global_position.direction_to(next_path_pos)

	if direction != Vector3.ZERO and awake:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
		var new_velocity = direction * speed
		nav.set_velocity(new_velocity)
		skin.set_move_state("Walking")
	
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
	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > 8.0:
		nav.target_position = player.global_position
		nav.set_velocity(Vector3.ZERO)
		var next_path_pos = nav.get_next_path_position()
		direction = global_position.direction_to(next_path_pos)
	else:
		direction = global_position.direction_to(player.global_position)

	var target_rotation = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed*delta)
	# move
	if in_range and not in_reach:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if attacking:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = 2.0
				skin.attack()
	else:
		velocity.x = 0
		velocity.z = 0 
	
	if not velocity.x == 0 or not velocity.z == 0:
		last_movement_input = Vector2(direction.x, direction.z)

func can_attack() -> bool:
	return (
		!Globals.player_dead &&
		player != null &&
		is_instance_valid(player)
	)

func process_attacking(delta: float) -> void:
	if not detected:
		detected = true
		emit_signal("enemy_detected")
	if is_sidestepping:
		handle_sidestep_movement(delta)
		return
	if not lock_rotation:
		direction = (player.global_transform.origin - global_transform.origin).normalized()
		# rotate
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed*delta)
		last_movement_input = Vector2(direction.x, direction.z)
	
	velocity.x = 0
	velocity.z = 0
	velocity.y -= gravity * delta 
	
	# Handle sidestepping movement
	if is_sidestepping:
		velocity.x = sidestep_direction.x * speed
		velocity.z = sidestep_direction.z * speed
		return

	var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)
	
	if distance_to_player < 4.0:
		var _back_position = skin.global_transform.origin - direction.normalized() * 0.5
		var ray_origin = global_transform.origin + Vector3.UP
		var ray_target = ray_origin + Vector3.DOWN * 2.0

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
		query.exclude = [self]

		var space_state = get_world_3d().direct_space_state
		var result = space_state.intersect_ray(query)

		if result:
			# Safe to move back
			skin.set_move_state("Walking")
			var move_direction = -direction * speed 
			velocity.x = move_direction.x
			velocity.z = move_direction.z
		else:
			# Don't move, avoid falling off
			skin.set_move_state("Idle")
			velocity.x = 0
			velocity.z = 0
	else:
		skin.set_move_state("Idle")
	
	if player.frozen:
		return
	
	if attacking:
		attack_timer -= delta
		reposition_cooldown -= delta
		if attack_timer <= 0:
			if has_clear_shot() and reposition_cooldown <= 0:
				# Clear shot available
				attack_timer = 2.0
				skin.attack()
			else:
				print("FLANKING")
				# Find flanking position
				var flank_pos = calculate_flanking_position()
				nav.target_position = flank_pos
				reposition_cooldown = 4.0  # Prevent constant repositioning
				skin.set_move_state("Walking")

func has_clear_shot() -> bool:
	# Check multiple points on the player to account for aiming
	var clear_points = 0
	var check_points = [
		Vector3(0, 0, 0),      # Center
		Vector3(0, 1, 0),      # Head
		Vector3(0, 0.5, 0.5)   # Upper body
	]
	
	for point in check_points:
		var start = global_position + Vector3.UP
		var end = player.global_position + point
		var query = PhysicsRayQueryParameters3D.create(start, end)
		query.collision_mask = 1|2  # Check against both terrain and entities
		query.exclude = [self]
		
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result.is_empty() or result.collider == player:
			clear_points += 1
	
	# Require at least 2 clear points to consider it a valid shot
	return clear_points >= 2

func calculate_flanking_position() -> Vector3:
	# Calculate positions around the player in a circle
	flank_angle += randf_range(-PI/2, PI/2)  # Vary angle each time
	var player_pos = player.global_position
	var flank_dir = Vector3(cos(flank_angle), 0, sin(flank_angle))

	# Adjust distance based on number of nearby enemies
	var nearby_enemies = get_tree().get_nodes_in_group("Enemy").filter(
		func(e): return e != self and e.global_position.distance_to(player_pos) < 6.0
	)
	var flank_distance = base_flank_distance + nearby_enemies.size() * 0.5
	
	return player_pos + (flank_dir * flank_distance)

func handle_sidestep_movement(delta: float):
	# Smoothly move to flanking position
	var next_pos = nav.get_next_path_position()
	var move_dir = (next_pos - global_position).normalized()
	
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	
	# Face the player while moving
	var look_dir = (player.global_position - global_position).normalized()
	var target_rot = atan2(look_dir.x, look_dir.z)
	rotation.y = lerp_angle(rotation.y, target_rot, rotation_speed * delta)
	
	if nav.is_navigation_finished():
		is_sidestepping = false
		skin.set_move_state("Idle")
	return 2.0  # Full distance available

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
		if not lock_rotation:
			var target_rotation = atan2(idle_walk_direction.x, idle_walk_direction.z)
			rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func check_obstacles() -> void:
	if terrain_raycast.is_colliding():
		idle_walk_direction = get_random_idle_direction()

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		in_range = false
		if current_state == States.CHASING:
			skin.set_move_state("Taunt")
			set_physics_process(false)
			await get_tree().create_timer(3.0).timeout
			set_physics_process(true)
		if not in_range:
			set_state(States.IDLE)
			player_found = false
		

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		in_range = true
		if current_state == States.CHASING:
			skin.set_move_state("Walking")
		

func _on_stop_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		in_reach = true
		if current_state == States.CHASING && can_attack():
			set_state(States.ATTACKING)
			skin.set_move_state("Idle")
			
func _on_stop_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		in_reach = false
		if current_state == States.ATTACKING:
			set_state(States.CHASING)
			skin.set_move_state("Walking")

func projectile_hit(_hit_position: Vector3):
	hit()

func face_direction(f_direction: Vector3):
	var target_rotation = atan2(f_direction.x, f_direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * get_physics_process_delta_time())

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
	if hp > 0:
		skin.frozen()
	$Timers/FreezeTimer.start()

func hit(amount := 1) -> void:
	if not invulnerable:
		if current_state == States.RESURRECTING:
			dead_warrior.mark_for_resurrection(false)
			dead_warrior = null
			if global_transform.origin.distance_to(player.global_transform.origin)  < 5.0:
				set_state(States.ATTACKING)
			else:
				set_state(States.CHASING)
		hp -= amount
		invulnerable = true
		if hp > 0:
			$Audio/Hit.play()
			on_squish_and_stretch(1.2,0.15)
			$Timers/InvulTimer.start()
		if hp <= 0:
			$Audio/Die.play()
			if frozen:
				frozen = false
				skin.clear_frozen()
			die()

# Add to the mage's script
func die() -> void:
	if current_state != States.IDLE:
		emit_signal("enemy_left")
	$Arrow.hide()
	dead = true
	emit_signal("is_dead")
	set_physics_process(false)
	set_process(false)
	collision_layer = 0
	collision_mask = 0
	$CollisionShape3D.set_deferred("disabled", true)
	await get_tree().physics_frame
	remove_from_group("Entity")
	skin.death(true)
	skin.set_death_state("Death")
	print("die function called")
	# Start the fade effect
	fade_out_effect()
	await get_tree().create_timer(7.0).timeout
	print("fade out complete")
	# Finally remove the mage
	queue_free()
	
	
func fade_out_effect():
	print("Fade out effect")
	# Get all mesh instances in the skin
	var meshes = get_all_meshes($Skeleton_Mage_Skin)
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
	
	var drop_position = $Skeleton_Mage_Skin.global_transform.origin  # Mage's death location

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
		
func _on_invul_timer_timeout() -> void:
	invulnerable = false
	if in_reach:
		set_state(States.ATTACKING)
	else:
		set_state(States.CHASING)

func on_squish_and_stretch(value: float, duration: float = 0.1):
	var tween = create_tween()
	tween.tween_property(skin, "squish_and_stretch", value, duration)
	tween.tween_property(skin, "squish_and_stretch", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)
	
func cast_spell(pos: Vector3) -> void:
	var to_player = player.global_position - global_position
	var direction_3d = to_player.normalized()
	if is_in_group("Ice"):
		spell_cast.emit("iceball", pos, direction_3d, 1.0, $".")
	else:
		print("FIRE")
		spell_cast.emit("fireball", pos, direction_3d, 1.0, $".")

func check_for_dead_warrior() -> bool:
	if dead_warrior and dead_warrior.check_if_dead():
		return true
	var entities = get_tree().get_nodes_in_group("WithMage")
	for entity in entities:
		if entity is CharacterBody3D and entity.has_method("check_if_dead") and entity.check_if_dead():
			if global_position.distance_to(entity.global_position) <= resurrection_range:
				dead_warrior = entity
				dead_warrior.mark_for_resurrection(true)
				return true
	return false
	
func process_resurrecting(_delta: float):
	if !dead_warrior or !dead_warrior.check_if_dead():
		set_state(States.IDLE)
		return
	var corpse_pos = dead_warrior.get_node("WarriorSkin/Rig/Skeleton3D/Skeleton_Warrior_Helmet")
	var to_corpse = corpse_pos.global_position - global_position
	var distance = to_corpse.length()
	
	if distance > res_dis:
		var dir = to_corpse.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		skin.set_move_state("Walking")
		
	else:
		velocity.x = 0
		velocity.z = 0
		skin.set_move_state("Idle")
		perform_resurrection_ritual()
	
func perform_resurrection_ritual():
	if !dead_warrior or resurrecting:
		return
	resurrecting = true
	if is_instance_valid(dead_warrior):
		var dir = (dead_warrior.global_position - global_position).normalized()
		rotation.y = atan2(dir.x, dir.z)
	
	skin.set_attack_state("Spellcast_Raise")
	print("SPELLCAST")
	await get_tree().create_timer(1.0).timeout
	$Audio/Ritual.play()
	var revive_circle
	if is_instance_valid(dead_warrior) and dead_warrior.check_if_dead():
		revive_circle = dead_warrior.get_node("Revive")
		revive_circle.show()
		revive_circle.get_node("AnimatedSprite3D").play("circle")
	await get_tree().create_timer(2.0).timeout
	
	spell_cast.emit("resurrection", global_position, Vector3.ZERO, 1.5, self)
	if is_instance_valid(dead_warrior) and dead_warrior.check_if_dead():
		var revive_particles = dead_warrior.get_node("Particles/Revive")
		revive_particles.emitting = true
		$Audio/Revive.play()
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(dead_warrior) and dead_warrior.check_if_dead():
		if dead_warrior:
			$Audio/Ritual.stop()
			dead_warrior.revive()
			dead_warrior = null
	if is_instance_valid(revive_circle):
		revive_circle.hide()
	if in_range:
		set_state(States.CHASING)
	else:
		set_state(States.IDLE)

func take_damage(amount: int, knockback: Vector3):
	hit(amount)
	# Apply knockback
	knockback_velocity = knockback
	is_knocked_back = true
	set_physics_process(true)
	await get_tree().create_timer(knockback_timer).timeout
	is_knocked_back = false
	
func _on_navigation_agent_3d_velocity_computed(safe_velocity: Vector3) -> void:
	var blend_weight = 0.3
	if is_sidestepping:
		velocity.x = lerp(velocity.x, safe_velocity.x, 0.5)
		velocity.z = lerp(velocity.z, safe_velocity.z, 0.5)
	else:
		velocity.x = lerp(velocity.x, safe_velocity.x, blend_weight)
		velocity.z = lerp(velocity.z, safe_velocity.z, blend_weight)

func check_if_dead() -> bool:
	return hp <= 0
	
func _on_freeze_timer_timeout() -> void:
	frozen = false
	skin.clear_frozen()

func _on_detect_timer_timeout() -> void:
	checked = false
	detected = false
	emit_signal("enemy_left")

#func move_to_dead_warrior(delta: float) -> void:
	#if not dead_warrior:
		#resurrecting = false
		#return
		#
	#direction = (dead_warrior.global_transform.origin - global_transform.origin).normalized()
	#velocity.x = direction.x * speed
	#velocity.z = direction.z * speed
	#
	#var target_rotation = atan2(direction.x, direction.z)
	#rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed*delta)
	#
	#skin.set_move_state("Walking")
	#if global_position.distance_to(dead_warrior.global_position) < 2.0:
		#cast_resurrection()
	#
#
#func cast_resurrection() -> void:
	#if not dead_warrior:
		#resurrecting = false
		#return
	#resurrecting = false
	#velocity = Vector3.ZERO
	#skin.set_move_state("Idle")
	#skin.set_attack_state("Spellcast_Raise")
	#var revive = dead_warrior.get_node("Effects")
	#var revive_circle = dead_warrior.get_node("Revive")
	#revive_circle.show()
	#revive_circle.get_node("AnimatedSprite3D").play("circle")
	#spell_cast.emit("resurrection", dead_warrior.global_position, Vector2.ZERO, 1.5, $".")
	#
	#await get_tree().create_timer(3.0).timeout
	#revive_circle.hide()
	#revive.show()
	#revive.get_node("AnimatedSprite3D").play("revive")
	#await get_tree().create_timer(1.0).timeout
	#revive.hide()
	#if dead_warrior:
		#dead_warrior.revive()
		#dead_warrior = null


func _on_attack_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		attacking = true


func _on_attack_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		attacking = false

func is_engaged() -> bool:
	return not current_state == States.IDLE and not dead
