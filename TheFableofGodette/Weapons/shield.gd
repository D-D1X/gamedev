extends Node3D

signal blocked(body:Node3D)
var blocking := false
@export var block_angle := 95 
@export var bounce_force := 2.5
@export var upward_force := 2.0
@onready var player := get_tree().get_first_node_in_group("Player")
var skin
var can_bounce := true
var marker

func _ready() -> void:
	skin = player.get_node("GodetteSkin")
	marker = player.get_node("Marker3D")

func _on_area_3d_body_entered(body: Node3D) -> void:
	var attack_direction = (body.global_position - global_position).normalized()
	var player_forward = global_transform.basis.z.normalized() 
	var angle = rad_to_deg(acos(player_forward.dot(attack_direction)))

	# Check if attack is within blockable range
	if blocking and body.is_in_group("Weapon"):
		if angle <= block_angle:
			print("Blocked attack from front, angle: ", angle)
			blocked.emit(body)
			# Notify the weapon directly to prevent damage
			body.get_parent().can_damage = false
			body.get_parent().is_blocked = true
		else:
			print("Attack from side/back, angle: ", angle) 


func _on_godette_skin_blocking_state() -> void:
	blocking = true


func _on_godette_skin_idle_state() -> void:
	blocking = false


func _on_area_3d_area_entered(area: Area3D) -> void:
	var attack_direction = (area.global_position - global_position).normalized()
	var player_forward = global_transform.basis.z.normalized() 
	var angle = rad_to_deg(acos(player_forward.dot(attack_direction)))
	print("Area entered")
	# Check if attack is within blockable range
	if blocking:
		if angle <= block_angle:
			if area.is_in_group("Projectile"): 
				$Block.pitch_scale = randf_range(0.95, 1.05)
				$Block.play()
				area.bounce_off_shield(marker)
		if area.is_in_group("Weapon"):
			var body = area.get_parent()
			var skeleton = body.get_parent().get_parent().get_parent().get_parent()
			if angle <= block_angle and skeleton.attacking:
				$Block.pitch_scale = randf_range(0.95, 1.05)
				$Block.play()
				print("Blocked attack from front, angle: ", angle)
				blocked.emit(body)
				# Notify the weapon directly to prevent damage
				body.can_damage = false
				body.is_blocked = true
			else:
				print("Attack from side/back, angle: ", angle) 



func _on_area_3d_2_area_entered(area: Area3D) -> void:
	if area.is_in_group("Slime") and can_bounce and blocking:
		print("SLIME BOUNCE")
		var slime = area.get_parent()
		if slime.is_stunned:
			return
		
		# Calculate bounce direction directly from relative positions
		var bounce_vec = calculate_directional_bounce(slime.global_position)
		
		# Apply bounce with modified vector
		slime.bounce_off(bounce_vec)
		start_cooldown()

func calculate_directional_bounce(slime_position: Vector3) -> Vector3:
	var to_slime = (slime_position - skin.global_position).normalized()
	var away_direction = to_slime

	# Apply force multipliers
	var horizontal_force = bounce_force * 10.0
	var vertical_force = bounce_force * 8.0

	var upward_component = clamp(away_direction.y, 0.6, 1.0)

	# Create final force vector with emphasis on backward motion
	return Vector3(
		away_direction.x * horizontal_force,
		max(0.5, away_direction.y) * vertical_force,  # Ensure minimum upward
		away_direction.z * horizontal_force
	)

func start_cooldown():
	can_bounce = false
	await get_tree().create_timer(0.5).timeout
	can_bounce = true


func _on_area_3d_2_body_entered(body: Node3D) -> void:
	if body.is_in_group("Slime"):
		print("SLIME")
		var collision = body.get_last_slide_collision()
		if collision:
			# Calculate bounce direction from collision normal
			var normal = collision.get_normal()
			var bounce_vec = Vector3(
				normal.x + randf_range(-0.3, 0.3),
				upward_force / bounce_force,
				normal.z + randf_range(-0.3, 0.3)
			).normalized()
			
			body.bounce_off(bounce_vec * bounce_force)
			start_cooldown()
