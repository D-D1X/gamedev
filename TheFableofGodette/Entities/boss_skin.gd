extends Node3D

@onready var walk_state_machine = $AnimationTree.get("parameters/WalkStateMachine/playback")
@onready var attack_state_machine = $AnimationTree.get("parameters/AttackStateMachine/playback")
@onready var raycast = $Rig/Skeleton3D/Nagonford_Axe/Nagonford_Axe/RayCast3D
@onready var skeleton = $Rig/Skeleton3D
@onready var sparks = $Rig/Skeleton3D/Nagonford_Axe/Nagonford_Axe/Sparks
@onready var impact = $Rig/Skeleton3D/Nagonford_Axe/Nagonford_Axe/Impact
var attacking := false
var can_damage := false
signal attack_finished
		
		
func _process(_delta: float) -> void:
	if can_damage:
		var collider = raycast.get_collider()
		if collider and 'hit' in collider:
			impact.emitting = true
			sparks.emitting = true
			collider.hit()

func set_move_state(state_name:String) -> void:
	walk_state_machine.travel(state_name)
	

func range_attack() -> void:
	if not attacking:
		attack_state_machine.travel('Stab')
		$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
func melee_attack() -> void: 
	if not attacking:
		var attack_stage = randi() % 2
		match attack_stage :
			0:
				attack_state_machine.travel("Slice")
			1:
				attack_state_machine.travel("Spin")
		$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		
func _attack_toggle(value: float) -> void:
	attacking = true
	await get_tree().create_timer(value).timeout
	attacking = false
	
func _cast_spell() -> void:
	get_parent().cast_spell($Rig/Skeleton3D/Nagonford_Axe/Nagonford_Axe/Marker3D.global_position)

	
func _spin_trans(value: float) -> void:
	$AnimationTree.set("parameters/Blend2/blend_amount", value)

var squish_and_stretch := 1.0:
	set(value):
		squish_and_stretch = value
		var negative = 1.0 + (1.0 - squish_and_stretch)
		scale = Vector3(negative, squish_and_stretch, negative)
		

func _can_damage(value: bool) -> void:
	can_damage = value

func shield():
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is ShaderMaterial:
				var tween = create_tween()
				tween.tween_method(
					func(value):
						material.set_shader_parameter("alpha", value),
					0.0,
					0.1,
					1.0
				)
			else:
				print("Material is not a StandardMaterial3D or is null")
	var cape = $Rig/Skeleton3D/Nagonford_Cape/Nagonford_Cape.get_material_overlay()
	if cape is ShaderMaterial:
		var tween = create_tween()
		tween.tween_method(
			func(value):
				cape.set_shader_parameter("alpha", value),
			0.0,
			0.05,
			1.0
		)
	else:
		print("Material is not a StandardMaterial3D or is null")

func shield_off():
	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var material = child.get_material_overlay()
			if material is ShaderMaterial:
				var tween = create_tween()
				tween.tween_method(
					func(value):
						material.set_shader_parameter("alpha", value),
					0.1,
					0.0,
					1.0
				)
			else:
				print("Material is not a StandardMaterial3D or is null")
	var cape = $Rig/Skeleton3D/Nagonford_Cape/Nagonford_Cape.get_material_overlay()
	if cape is ShaderMaterial:
		var tween = create_tween()
		tween.tween_method(
			func(value):
				cape.set_shader_parameter("alpha", value),
			0.05,
			0.0,
			1.0
		)
	else:
		print("Material is not a StandardMaterial3D or is null")

func _attack_finished():
	emit_signal("attack_finished")

func set_axe(value: bool):
	$Rig/Skeleton3D/Nagonford_Axe.override_pose = value

func pitch_slash(resource:AudioStream):
	$Swing.stream = resource
	$Swing.pitch_scale = randf_range(0.9, 1.1)
	$Swing.play()

func pitch_grunt(resource:AudioStream):
	$Grunts.stream = resource
	$Grunts.pitch_scale = randf_range(0.9, 1.1)
	$Grunts.play()

func jump_idle():
	set_move_state("Jump_Idle")
	
func jump_land():
	set_move_state("Jump_Land")

func stab():
	set_move_state("Stab")

func death():
	set_move_state("Death")
	
func death_pose():
	set_move_state("Death_Pose")
