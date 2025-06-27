extends MeshInstance3D


func _on_kill_barrier_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.fall_into_pit(global_position)
	if body.is_in_group("Entity"):
		if body.has_method("out_of_bounds"):
			body.out_of_bounds()
		body.die()
