extends Node3D

@onready var move_state_machine = $AnimationTree.get("parameters/MoveStateMachine/playback")
@onready var defend_state_machine = $AnimationTree.get("parameters/BlockStateMachine/playback")
@onready var attack_state_machine = $AnimationTree.get("parameters/AttackStateMachine/playback")
@onready var extra_animation = $AnimationTree.get_tree_root().get_node('ExtraAnimation')
@onready var spell_animation = $AnimationTree.get_tree_root().get_node('SpellAnimation')
@onready var face_material: StandardMaterial3D = $Rig/Skeleton3D/Godette_Head.get_surface_override_material(0)
@onready var time_scale = $AnimationTree.get("parameters/RunTimeScale/scale")
@onready var skeleton = $Rig/Skeleton3D
@onready var trail1 = $Rig/Skeleton3D/RightHandSlot/Sword/sword_1handed2/sword_1handed/Trail3D
@onready var trail2 = $Rig/Skeleton3D/RightHandSlot/Sword/sword_1handed2/sword_1handed/Trail3D2
@onready var slash1 = $Slash
@onready var slash2 = $Slash2
signal blocking_state
signal idle_state
signal blocked(body:Node3D)


var original_rotation
var attacking := false
var damage := false
var attack_reset_timer : Timer
var queued_attack := false
var attack_stage := 0
var squish_and_stretch := 1.0:
	set(value):
		squish_and_stretch = value
		var negative = 1.0 + (1.0 - squish_and_stretch)
		scale = Vector3(negative, squish_and_stretch, negative)
var hit_anims = ["Hit_A", "Hit_B"]
const faces = {
	'default': Vector3.ZERO,
	'blink': Vector3(0,0.5,0),
	'angry': Vector3(0.5,0.5,0),
	'happy': Vector3(0.5,0,0)
}
var rng = RandomNumberGenerator.new()
var stab := false

func _ready() -> void:
	await get_tree().process_frame
	if Globals.main_menu:
		$Rig/Skeleton3D/LeftHandSlot/PlayerShield.hide()
		$AnimationTree.active = false
		$AnimationPlayer.play("Sit_Floor_Idle")
		return
	if Globals.new_game:
		set_move_state("Lie_Idle")
		$BlinkTimer.stop()
		change_face('blink')
	if get_tree().current_scene.is_in_group("Dungeon"):
		$DungeonArrow.show()
		$OverworldArrow.hide()
	else:
		$DungeonArrow.hide()
		$OverworldArrow.show()
	$AnimationTree.set("parameters/ShieldBlend/blend_amount", 0)

func _process(_delta: float) -> void:
	if Globals.player_dead: $AnimationTree.set("parameters/ShieldBlend/blend_amount", 0)
	if defend_state_machine.get_current_node() == "Blocking":
		blocking_state.emit()
	elif defend_state_machine.get_current_node() == "Idle":
		idle_state.emit()
	if get_move_state() == "Running_C":
		time_scale = 1.1
		$GPUParticles3D.emitting = true
	else:
		time_scale = 1.0
		$GPUParticles3D.emitting = false
		
func set_move_state(state_name: String) -> void:
	move_state_machine.travel(state_name)
	
func get_move_state() -> String:
	return move_state_machine.get_current_node()
	
func pit_get_up_state(state_name: String) -> void:
	move_state_machine.travel(state_name)  # Move to the animation state
	await get_tree().process_frame  # Allow state transition to take effect

	
func set_defend_state(state_name: String) -> void:
	defend_state_machine.travel(state_name)


func attack() -> void:
	if attacking:
		var one_shot_active = $AnimationTree.get("parameters/AttackOneShot/active")
		if not one_shot_active:
			# The animation finished without queuing another attack, reset.
			attacking = false
			attack_stage = 0
		elif $ComboTimer.time_left > 0 and not stab:
			print("QUEUE")
			queued_attack = true
			return
		else:
			return
	_start_attack_sequence()


func _start_attack_sequence():
	print("Attack animation")
	attacking = true
	match attack_stage:
		0:
			stab = false
			$AnimationTree.set("parameters/ExtraTimeScale/scale", 1.25)
			attack_state_machine.travel('Chop')
		1:
			$AnimationTree.set("parameters/ExtraTimeScale/scale", 1.25)
			attack_state_machine.travel('Slash')
		2:
			stab = true
			$AnimationTree.set("parameters/ExtraTimeScale/scale", 1.5)
			slash2.hide()
			attack_state_machine.travel('Stab')
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _on_animation_finished():
	print("Animation finished")
	if queued_attack:
		attack_stage = (attack_stage + 1) % 3
		queued_attack = false
		_start_attack_sequence()
	else:
		attack_stage = 0
		attacking = false

func _attack_toggle(value: bool) -> void:
	attacking = value
	if attacking:
		await get_tree().create_timer(1.0).timeout
		attacking = false
	print("Attack toggle: ", value)
		
func _force_reset_attack():
	if attacking: 
		trail1._trailEnabled = false
		trail2._trailEnabled = false
		print("Force resetting attack state!")
		attacking = false
		attack_reset_timer.stop()
		# Reset animation state
		$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func defend(forward: bool) -> void:
	if not Globals.player_dead:
		var tween = create_tween()
		tween.tween_method(_defend_trans, 1.0 - float(forward), float(forward), 0.25)
	else:
		$AnimationTree.set("parameters/ShieldBlend/blend_amount", 0)
	
func _defend_trans(value: float) -> void:
	$AnimationTree.set("parameters/ShieldBlend/blend_amount", value)
	
func switch_weapon(weapon_active: int) -> void:
	if weapon_active == 0:
		$Rig/Skeleton3D/RightHandSlot/Sword.show()
		$Rig/Skeleton3D/RightHandSlot/wand2.hide()
		$Rig/Skeleton3D/RightHandSlot/Crossbow.hide()
	elif weapon_active == 1:
		$Rig/Skeleton3D/RightHandSlot/Sword.hide()
		$Rig/Skeleton3D/RightHandSlot/wand2.show()
		$Rig/Skeleton3D/RightHandSlot/Crossbow.hide()
	else:
		$Rig/Skeleton3D/RightHandSlot/Sword.hide()
		$Rig/Skeleton3D/RightHandSlot/wand2.hide()
		$Rig/Skeleton3D/RightHandSlot/Crossbow.show()
		
func face_position(target_pos: Vector3) -> void:
	var direction = (target_pos - global_position).normalized()
	var target_rot = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rot, 0.2)

func interact() -> void:
	if not attacking:
		extra_animation.animation = "Interact"
		$AnimationTree.set("parameters/ExtraOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func face_camera() -> void:
	var current_rot = $Rig.rotation_degrees.y
	var target_rot = current_rot + 180  # Flip direction

	# Normalize rotation to shortest path
	target_rot = fmod(target_rot - current_rot + 180, 360) - 180

	var tween = create_tween()
	tween.tween_property($Rig, "rotation_degrees:y", current_rot + target_rot, 0.5)
	await tween.finished

func raise(crossbow:bool) -> void:
	$AnimationTree.active = false  # Temporarily disable the AnimationTree if it conflicts
	$AnimationPlayer.play("Spellcast_Summon")
	$AnimationPlayer.seek(2.0, true)
	await get_tree().create_timer(1.0).timeout
	if crossbow:
		$CrossbowGet.play()
	else:
		$ItemGet.play()
	await get_tree().create_timer(0.5).timeout
	$AnimationPlayer.pause()
	$BlinkTimer.stop()
	change_face('happy')

func reset_rotation():
	$AnimationTree.active = true
	change_face('default')
	$BlinkTimer.start()
	var current_rot = $Rig.rotation_degrees.y
	var target_rot = current_rot + 180  # Flip direction

	# Normalize rotation to shortest path
	target_rot = fmod(target_rot - current_rot + 180, 360) - 180

	var tween = create_tween()
	tween.tween_property($Rig, "rotation_degrees:y", current_rot + target_rot, 0.5)
	await tween.finished

func cast_spell(toggle: bool, amount: int) -> void:
	if not attacking:
		if toggle and amount > 0:
			spell_animation.animation = 'Spellcast_Raise'
			$AnimationTree.set("parameters/SpellOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		else:
			spell_animation.animation = 'Spellcast_Shoot'
			$AnimationTree.set("parameters/SpellOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	

func shoot_magic() -> void:
	get_parent().shoot_magic($Rig/Skeleton3D/RightHandSlot/wand2/wand/Marker3D.global_position)

func hit() -> void:
	extra_animation.animation = hit_anims[randi() % 2]
	$AnimationTree.set("parameters/ExtraOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	$HitStunTimer.start()

func _on_hit_stun_timer_timeout() -> void:
	attack_stage = 0
	attacking = false

func change_face(expression) -> void:
	face_material.uv1_offset = faces[expression]

func get_up() -> void:
	print("Starting get_up function")

	# Make sure we're working with the correct animation
	extra_animation.animation = "Death_B"
	extra_animation.play_mode = 1
	$AnimationTree.set("parameters/ExtraOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	print("Started animation backward playback")

	# Wait for the animation to complete
	await get_tree().create_timer(2.5).timeout
	
	print("Animation completed")
	
func _on_blink_timer_timeout() -> void:
	change_face('blink')
	await get_tree().create_timer(0.2).timeout
	change_face('default')
	$BlinkTimer.wait_time = rng.randf_range(1.5,3.0)
	
func can_damage(value: bool):
	damage = value
	$Rig/Skeleton3D/RightHandSlot/Sword.can_damage = value


func _on_player_shield_blocked(body) -> void:
	blocked.emit(body)

func flash_red(value := 0.2):
	var target_color = Color(0.941, 0.255, 0.576, 0.294)
	var target_emission = Color(0.941, 0.255, 0.576)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material.albedo_color = target_color
				material.emission = target_emission
				var tween = create_tween()
				var target_alpha_color = Color(target_color.r, target_color.g, target_color.b, 0.0)
				tween.tween_property(material, "albedo_color", target_alpha_color, value)
				tween.tween_callback(func(): material.albedo_color.a = 0.0)
			else:
				print("Material is not a StandardMaterial3D or is null")

func frozen() -> void:
	var frozen_color = Color(0.6, 0.8, 1.0, 0.4) # Icey blue with some transparency
	var frozen_emission = Color(0.6, 0.8, 1.0)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material.emission = frozen_emission
				var tween = create_tween()
				tween.tween_property(material, "albedo_color", frozen_color, 0.5)
			else:
				print("Material is not a StandardMaterial3D or is null")

func clear_frozen() -> void:
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material.albedo_color.a = 0.0 # Reset to fully transparent overlay

func _on_combo_timer():
	$ComboTimer.start()

#func _on_reset_timer():
	#attack_reset_timer.start()
	

func _trail_trigger(value: bool):
	if value:
		trail1._trailEnabled = true
		trail2._trailEnabled = true
	else:
		trail1._trailEnabled = false
		trail2._trailEnabled = false
		
func vertical_slash(value: float):
	slash1.material_override.set_shader_parameter('progress', value)
	
func horizontal_slash(value: float):
	slash2.material_override.set_shader_parameter('progress', value)

func show_slash():
	slash2.show()

func heal(value: float):
	var material = $HealCircle/Heal.mesh.surface_get_material(0)
	if material is ShaderMaterial:
		material.set_shader_parameter('time', value)

func pitch_slash(resource:AudioStream):
	$SwordSwings.stream = resource
	$SwordSwings.pitch_scale = randf_range(0.9, 1.1)
	$SwordSwings.play()

func pitch_grunt(resource:AudioStream):
	$Grunts.stream = resource
	$Grunts.pitch_scale = randf_range(0.95, 1.05)
	$Grunts.play()

func open_eyes():
	change_face('default')
	$BlinkTimer.start()

func sit():
	$AnimationPlayer.play("Sit_Floor_Pose")
	$SitTimer.start()
	

func _on_sit_timer_timeout() -> void:
	$SitTimer.wait_time = randf_range(4.5, 7.5)
	$AnimationPlayer.play("Sit_Floor_Idle")
