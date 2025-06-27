extends Node3D

signal blocked(body)
var blocking := false
var audio_flag := false
@export var block_angle := 90 

func _on_area_3d_body_entered(body: Node3D) -> void:
	var attack_direction = (body.global_position - global_position).normalized()
	var player_forward = global_transform.basis.z.normalized() 
	var angle = rad_to_deg(acos(player_forward.dot(attack_direction)))

	# Check if attack is within blockable range
	if blocking and body.is_in_group("PWeapon"):
		if angle <= block_angle:
			blocked.emit(body)


func _on_warrior_skin_blocking_state() -> void:
	blocking = true


func _on_warrior_skin_idle_state() -> void:
	blocking = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	var attack_direction = (area.global_position - global_position).normalized()
	var player_forward = global_transform.basis.z.normalized() 
	var angle = rad_to_deg(acos(player_forward.dot(attack_direction)))

	# Check if attack is within blockable range
	if blocking:
		if angle <= block_angle * 0.5:
			if area.is_in_group("Projectile"): 
				area.bounce_off_shield(self)
		if area.is_in_group("PWeapon"):
			var body = area.get_parent()
			if angle <= block_angle:
				if not audio_flag:
					$Block.pitch_scale = randf_range(0.9, 1.1)
					$Block.play()
					audio_flag = true
					$Timer.start()

				print("Blocked attack from front, angle: ", angle)
				blocked.emit(body)
			else:
				print("Attack from side/back, angle: ", angle) 


func _on_timer_timeout() -> void:
	audio_flag = false
