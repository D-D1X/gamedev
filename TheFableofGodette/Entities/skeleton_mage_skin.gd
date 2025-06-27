extends Node3D

@onready var walk_state_machine = $AnimationTree.get("parameters/WalkStateMachine/playback")
@onready var attack_state_machine = $AnimationTree.get("parameters/SpellStateMachine/playback")
@onready var death_state_machine = $AnimationTree.get("parameters/DeathStateMachine/playback")
@onready var skeleton = $Rig/Skeleton3D
var attacking := false
var skeletons_available := false
var cooldown_timer := 0.0

func _physics_process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
		
func set_move_state(state_name:String) -> void:
	walk_state_machine.travel(state_name)

func set_death_state(state_name:String) -> void:
	death_state_machine.travel(state_name)
	
func set_attack_state(state_name:String) -> void:
	attack_state_machine.travel(state_name)
	$AnimationTree.set("parameters/SpellOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	

func attack() -> void:
	if cooldown_timer <= 0 and attacking:
		attacking = false
	if not attacking and cooldown_timer <= 0:
		cooldown_timer = 5.0
		var attack_stage = randi() % 2
		match attack_stage:
			0:
				attack_state_machine.travel('Spellcast_Long')
			1:
				attack_state_machine.travel('Spellcast_Shoot')
		$AnimationTree.set("parameters/SpellOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _attack_toggle(value: bool) -> void:
	attacking = value
	
func _cast_spell() -> void:
	get_parent().cast_spell($Rig/Skeleton3D/RightHandSlot/wand2/wand/Marker3D.global_position)
	
var squish_and_stretch := 1.0:
	set(value):
		squish_and_stretch = value
		var negative = 1.0 + (1.0 - squish_and_stretch)
		scale = Vector3(negative, squish_and_stretch, negative)

func death(forward: bool) -> void:
	var tween = create_tween()
	tween.tween_method(_death_trans, 1.0 - float(forward), float(forward), 0.25)
	
func _death_trans(value: float) -> void:
	$AnimationTree.set("parameters/DeathBlend/blend_amount", value)
	
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
	var hat_mesh = $Rig/Skeleton3D/Skeleton_Mage_Hat/Skeleton_Mage_Hat
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
	var hat_mesh = $Rig/Skeleton3D/Skeleton_Mage_Hat/Skeleton_Mage_Hat
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
	var hat = $Rig/Skeleton3D/Skeleton_Mage_Hat/Skeleton_Mage_Hat.get_material_overlay()
	if hat is StandardMaterial3D:
		hat.albedo_color.a = 0.0
