extends Marker3D


func _on_area_3d_body_entered(body: Node3D):
	if body.is_in_group("Player"):
		body.set_safe_position(global_position)
