extends Node3D

@onready var walk_state_machine = $AnimationTree.get("parameters/WalkStateMachine/playback")
@onready var attack_state_machine = $AnimationTree.get("parameters/AttackStateMachine/playback")
@onready var defend_state_machine = $AnimationTree.get("parameters/DefendStateMachine/playback")
@onready var death_state_machine = $AnimationTree.get("parameters/DeathStateMachine/playback")
@onready var extra_animation = $AnimationTree.get_tree_root().get_node('ExtraAnimation')
@onready var weapon = $Rig/Skeleton3D/RightHandSlot/Bone
@onready var skeleton = $Rig/Skeleton3D
var attacking := false
var chosen_attack : String
var hit_anims = ["Hit_A", "Hit_B"]

signal blocking_state
signal idle_state
signal blocked(body)

func _process(_delta: float) -> void:
	if defend_state_machine.get_current_node() == "Blocking":
		blocking_state.emit()
	if defend_state_machine.get_current_node() == "Idle_Combat":
		idle_state.emit()

func set_move_state(state_name:String) -> void:
	walk_state_machine.travel(state_name)
	
func set_defend_state(state_name:String) -> void:
	defend_state_machine.travel(state_name)
	
func set_death_state(state_name:String) -> void:
	death_state_machine.travel(state_name)

func attack():
	if attacking:
		return "Nill"
	attacking = true
	var attack_stage = randi() % 3
	match attack_stage:
		0:
			attack_state_machine.travel('Chop')
			chosen_attack = 'Chop'
		1:
			attack_state_machine.travel('Slash')
			chosen_attack = 'Slash'
		2:
			attack_state_machine.travel('Jump_Chop')
			chosen_attack = 'Jump_Chop'
	print("Attacking with:", chosen_attack)
	$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	return chosen_attack

func _attack_toggle(value: bool) -> void:
	attacking = value
	if weapon and is_instance_valid(weapon):
		weapon.is_blocked = false
	if !value:
		attacking = false
		$AnimationTree.set("parameters/AttackOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)

func defend(forward: bool, hp: int) -> void:
	if hp > 0:
		var tween = create_tween()
		tween.tween_method(_defend_trans, 1.0 - float(forward), float(forward), 0.25)
	else:
		$AnimationTree.set("parameters/ShieldBlend/blend_amount", 0)
	
func _defend_trans(value: float) -> void:
	$AnimationTree.set("parameters/ShieldBlend/blend_amount", value)
	
var squish_and_stretch := 1.0:
	set(value):
		squish_and_stretch = value
		var negative = 1.0 + (1.0 - squish_and_stretch)
		scale = Vector3(negative, squish_and_stretch, negative)
	
func can_damage(value: bool):
	if weapon and is_instance_valid(weapon) and not weapon.is_blocked:
		weapon.can_damage = value

func _on_hit():
	extra_animation.animation = hit_anims[randi() % 2]
	$AnimationTree.set("parameters/ExtraOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
func death(forward: bool) -> void:
	var tween = create_tween()
	tween.tween_method(_death_trans, 1.0 - float(forward), float(forward), 0.25)
	
func _death_trans(value: float) -> void:
	$AnimationTree.set("parameters/DeathBlend/blend_amount", value)

func _on_enemy_shield_blocked(body) -> void:
	print("emit")
	blocked.emit(body)

func flash_red(value := 0.2):
	var target_color = Color(0.941, 0.255, 0.576, 0.294)
	var target_emission = Color(0.941, 0.255, 0.576)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material = material.duplicate()
				child.set_material_overlay(material)
				material.albedo_color = target_color
				material.emission = target_emission
				var tween = create_tween()
				var target_alpha_color = Color(target_color.r, target_color.g, target_color.b, 0.0)
				tween.tween_property(material, "albedo_color", target_alpha_color, value)
				tween.tween_callback(func(): material.albedo_color.a = 0.0)
			else:
				print("Material is not a StandardMaterial3D or is null")
	var hat_mesh = $Rig/Skeleton3D/Skeleton_Warrior_Helmet/Skeleton_Warrior_Helmet
	var hat = hat_mesh.get_material_overlay()
	if hat is StandardMaterial3D:
		hat = hat.duplicate()
		hat_mesh.set_material_overlay(hat)
		hat.albedo_color = target_color
		hat.emission = target_emission
		var tween = create_tween()
		var target_alpha_color = Color(target_color.r, target_color.g, target_color.b, 0.0)
		tween.tween_property(hat, "albedo_color", target_alpha_color, value)
		tween.tween_callback(func(): hat.albedo_color.a = 0.0)
	else:
		print("Material is not a StandardMaterial3D or is null")

func frozen() -> void:
	var frozen_color = Color(0.6, 0.8, 1.0, 0.4) # Icey blue with some transparency
	var frozen_emission = Color(0.6, 0.8, 1.0)
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material = material.duplicate()
				child.set_material_overlay(material)
				material.emission = frozen_emission
				var tween = create_tween()
				tween.tween_property(material, "albedo_color", frozen_color, 0.5)
			else:
				print("Material is not a StandardMaterial3D or is null")
	var hat_mesh = $Rig/Skeleton3D/Skeleton_Warrior_Helmet/Skeleton_Warrior_Helmet
	var hat = hat_mesh.get_material_overlay()
	if hat is StandardMaterial3D:
		hat = hat.duplicate()
		hat_mesh.set_material_overlay(hat)
		hat.emission = frozen_emission
		var tween = create_tween()
		tween.tween_property(hat, "albedo_color", frozen_color, 0.5)
	else:
		print("Material is not a StandardMaterial3D or is null")

func clear_frozen() -> void:
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is StandardMaterial3D:
				material.albedo_color.a = 0.0 # Reset to fully transparent overlay
	var hat = $Rig/Skeleton3D/Skeleton_Warrior_Helmet/Skeleton_Warrior_Helmet.get_material_overlay()
	if hat is StandardMaterial3D:
		hat.albedo_color.a = 0.0

func pitch_slash():
	$Swing.pitch_scale = randf_range(0.9, 1.1)
	$Swing.play()
