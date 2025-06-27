extends Node3D

var can_damage := false
var hit_objects := {}
@onready var attack_area: Area3D = $AttackArea
@onready var shape_cast: ShapeCast3D = $ShapeCast

func _process(_delta: float) -> void:
	if can_damage:
		_check_collisions()

func _check_collisions():
	# Broad phase detection with Area3D
	var potential_targets := []
	var area_targets = attack_area.get_overlapping_bodies()
	potential_targets.append_array(area_targets)
	
	# Precise phase with ShapeCast
	shape_cast.force_shapecast_update()
	if shape_cast.is_colliding():
		for i in range(shape_cast.get_collision_count()):  # Iterate through all collisions
			var body = shape_cast.get_collider(i) 
			if body not in potential_targets:
				potential_targets.append(body)
	
	for target in potential_targets:
		_process_hit(target)


func _process_hit(target):
	Engine.time_scale = 0.0001
	await get_tree().create_timer(0.1 * 0.0001).timeout
	Engine.time_scale = 1.0
	if is_instance_valid(target):
		if target.has_method("hit"):
			$Particles/Impact.emitting = true
			$Particles/Sparks.emitting = true
			target.hit()
			
			if target.has_method("knockback"):
				target.knockback(global_position)
		elif target.is_in_group("Destructable"):
			target.smash()

func is_attacking() -> bool:
	return can_damage
	
