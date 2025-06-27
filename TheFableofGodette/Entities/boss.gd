extends CharacterBody3D

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var skin = $BossSkin
@onready var attack_timer = $AttackTimer
var speed_modifier := 1.0
@export var notice_radius := 30.0
@export var attack_radius := 3.0
@onready var action_delay_timer = $ActionDelayTimer
var can_act := true
var speed := 1.5
var rotation_speed := 1.0
var direction: Vector3
var state := "Idle"
var in_range := false
var in_reach := false
var gravity := 9.8
var invulnerable := false
var lock_rotation := false
var spin_speed := 1.75
var spinning := false
var rng = RandomNumberGenerator.new()
var last_movement_input := Vector2(0,1)
var hp := 20
var shield := false
var active = false
var awake := true

signal spell_cast(type: String, pos: Vector3, direction: Vector2, size: float, caster: Node3D)
signal start_timer
signal is_dead

func _ready():
	invulnerable = true
	set_physics_process(false)
	skin.shield_off()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if global_position.distance_to(player.global_position) < notice_radius:
		var target_dir = (player.global_position - global_position).normalized()
		var target_vec2 = Vector2(target_dir.x, target_dir.z)
		var target_angle = -target_vec2.angle() + PI/2
		rotation.y = rotate_toward(rotation.y, target_angle, delta * rotation_speed)
		if global_position.distance_to(player.global_position) > attack_radius and can_act:
			velocity = Vector3(target_vec2.x, 0, target_vec2.y) * speed * speed_modifier
			skin.set_move_state('Walking_A')
		else:
			velocity = Vector3.ZERO
			skin.set_move_state('Idle')
		if not is_on_floor():
			velocity.y -= 2
		else:
			velocity.y = 0
		last_movement_input = target_vec2
		move_and_slide()

func spin_attack() -> void:
	$SpinTimer.start()
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "speed", spin_speed, 1.0)
	tween.tween_method(skin._spin_trans, 0.0, 1.0, 0.2)
	attack_timer.stop()
	spinning = true
	skin._can_damage(true)
	skin.attacking = true


func _on_range_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		in_range = true
		

func _on_range_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		in_range = false


func _on_melee_area_3d_body_entered(body: Node3D) -> void:
	if body == player:
		skin.set_move_state("Idle")
		in_reach = true
		
func _on_melee_area_3d_body_exited(body: Node3D) -> void:
	if body == player:
		in_reach = false
	
func stop_movement(start_duration: float, end_duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "speed", 0.0, start_duration)
	tween.tween_property(self, "speed", speed, end_duration)
	

func _on_attack_timer_timeout() -> void:
	skin.set_move_state("Idle")
	attack_timer.wait_time = rng.randf_range(4.0, 6.0)
	if in_range:
		if in_reach:
			stop_movement(1.5,1.5)
			skin.melee_attack()
		else:
			if rng.randi() % 2:
				stop_movement(1.5,1.5)
				skin.range_attack()
				can_act = false
				action_delay_timer.start(rng.randf_range(2.0, 4.0))
			else:
				spin_attack()


func _on_hit_area_3d_body_entered(body: Node3D) -> void:
	if spinning and body == player:
		skin.attacking = false
		await get_tree().create_timer(rng.randf_range(1.0,2.0)).timeout
		var tween = create_tween()
		tween.tween_property(self, "speed", speed, 0.5)
		tween.tween_method(skin._spin_trans, 1.0, 0.0, 0.3)
		skin.set_axe(false)
		spinning = false
		skin._can_damage(false)
		can_act = false
		action_delay_timer.start(rng.randf_range(4.0, 6.0))
		
func projectile_hit() -> void:
	hit()
	
func iceball_hit():
	hit()
	
func fireball_hit():
	hit()
	
func take_damage(_amount: int, _knockback: Vector3):
	hit()

func hit() -> void:
	if not invulnerable:
		invulnerable = true
		hp -= 1
		print("boss was hit")
		if hp > 0:
			if randi_range(0,1) == 1:
				$Hit.play()
			else:
				$Hit2.play()
			on_squish_and_stretch(1.2,0.15)
			$InvulTimer.start()
		if hp < 0:
			die()

func die():
	$Arrow.hide()
	active = false
	$AttackTimer.stop()
	$InvulTimer.stop()
	$ShieldTimer.stop()
	$ActionDelayTimer.stop()
	$SpinTimer.stop()
	set_physics_process(false)
	$CollisionShape3D.set_deferred("disabled", true)
	$RangeArea3D/CollisionShape3D.set_deferred("disabled", true)
	$HitArea3D/CollisionShape3D.set_deferred("disabled", true)
	$MeleeArea3D/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().physics_frame
	emit_signal("is_dead")
	remove_from_group("Entity")

func fade_out_effect():
	print("Fade out effect")
	# Get all mesh instances in the skin
	var meshes = get_all_meshes($BossSkin)
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
	tween.tween_interval(0.5)  # Short delay before fading
	
	# First: Fade to black
	for mat in materials:
		tween.tween_property(mat, "albedo_color", Color.BLACK, 2.0)
	
	await tween.finished
	print("Blackout complete. Starting transparency fade...")
	$Particles/Death.emitting = true
	$Effects.show()
	$Effects/AnimatedSprite3D.play("death")
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

func _on_invul_timer_timeout() -> void:
	if not shield:
		invulnerable = false

func on_squish_and_stretch(value: float, duration: float = 0.1):
	var tween = create_tween()
	tween.tween_property(skin, "squish_and_stretch", value, duration)
	tween.tween_property(skin, "squish_and_stretch", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)
	

func cast_spell(pos:Vector3) -> void:
	var to_player = player.global_position - global_position
	var direction_3d = to_player.normalized()
	if randi_range(0,1) == 1:
		spell_cast.emit('fireball', pos, direction_3d, 2.0, $".")
	else:
		spell_cast.emit('iceball', pos, direction_3d, 2.0, $".")


func _on_shield_timer_timeout() -> void:
	invulnerable = true
	shield = true
	skin.shield()
	start_timer.emit()
	


func _on_target_button_pressed() -> void:
	invulnerable = false
	shield = false
	skin.shield_off()
	$ShieldTimer.start()


func _on_dungeon_trigger_4() -> void:
	$ShieldTimer.start()


func _on_action_delay_timer_timeout() -> void:
	can_act = true
	attack_timer.start()


func _on_spin_timer_timeout() -> void:
	if spinning:
		skin.attacking = false
		await get_tree().create_timer(rng.randf_range(1.0,2.0)).timeout
		var tween = create_tween()
		tween.tween_property(self, "speed", speed, 0.5)
		tween.tween_method(skin._spin_trans, 1.0, 0.0, 0.3)
		skin.set_axe(false)
		spinning = false
		skin._can_damage(false)
		can_act = false
		action_delay_timer.start(rng.randf_range(4.0, 6.0))

func _on_boss_skin_attack_finished() -> void:
	can_act = false
	skin.set_move_state("Idle")
	action_delay_timer.start(rng.randf_range(2.0, 4.0))
	
func _trigger_boss_fight():
	active = true
	invulnerable = false
	attack_timer.start()
	set_physics_process(true)

func death():
	$Death.play()
