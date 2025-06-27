extends Area3D

var direction: Vector3
var speed := 8.0
var caster: Node3D
var has_hit := false

func _ready() -> void:
	if is_in_group("Fireball"):
		$FireStart.play()
	elif is_in_group("Iceball"):
		$IceStart.play()
	scale = Vector3(0.1,0.1,0.1)


func _process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	if has_hit:
		return
	has_hit = true
	if "hit" in body:
		if body.has_method("projectile_hit"):
			call_deferred("_deferred_hit", body)
	elif body.is_in_group("Shield"): 
		bounce_off_shield(body)
	else:
		hide()
		collision_layer = 0
		collision_mask = 0
		$CollisionShape3D.set_deferred("disabled", true)
		await get_tree().create_timer(2.15).timeout
		queue_free()

func _deferred_hit(body:Node3D):
	if is_in_group("Fireball"):
		$Hit.play()
		body.fireball_hit()
	elif is_in_group("Iceball"):
		$Freeze.play()
		body.iceball_hit()
	hide()
	collision_mask = 0
	await get_tree().create_timer(2.05).timeout
	queue_free()

func setup(new_direction: Vector3, size: float, _caster: Node3D) -> void:
	direction = new_direction.normalized()
	caster = _caster
	var horizontal_direction = Vector2(direction.x, direction.z).normalized()
	$Trail.rotation.y = atan2(horizontal_direction.x, horizontal_direction.y)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * size, 0.5)

func bounce_off_shield(shield: Node3D) -> void:
	# Reflect direction off the shield
	var shield_normal = (global_position - shield.global_position).normalized()
	direction = direction.bounce(shield_normal).normalized()
	var height_adjustment = Vector3(0,1.0,0)
	
	# Hard-aim directly at the caster now
	direction = (caster.global_position - global_position + height_adjustment).normalized()
	
	# Update trail rotation (horizontal only)
	var horizontal_direction = Vector2(direction.x, direction.z).normalized()
	$Trail.rotation.y = atan2(horizontal_direction.x, horizontal_direction.y)

	# Reset hit flag for new trajectory
	has_hit = false
	speed *= 1.2


func _on_timer_timeout() -> void:
	queue_free()
