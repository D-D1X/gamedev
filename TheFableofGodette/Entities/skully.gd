extends CharacterBody3D

# Movement settings
@export var move_speed := 5.0
@export var bounce_factor := 0.8

@onready var skull := $Meshes/Skull
@onready var player := get_tree().get_first_node_in_group("Player")
var can_hit := true
var is_stunned := false
var awake := true
var moving := false
var last_move_direction: Vector3 = Vector3.ZERO

signal is_dead

func _ready():
	# Start moving forward
	if not is_in_group("Path"):
		velocity = Vector3.FORWARD.rotated(Vector3.UP, rotation.y) * move_speed

func _physics_process(delta):
	if not is_stunned:
		# Handle movement and collisions
		var collision = move_and_collide(velocity * delta)

		skull.look_at(player.global_position)
		skull.rotation.y += PI

		if collision:
			if is_in_group("test"):
				print("collision", velocity)
			$WallBounce.pitch_scale = randf_range(0.95, 1.05)
			$WallBounce.play()
			# Calculate bounce direction
			var normal = collision.get_normal()
			velocity = velocity.bounce(normal) * bounce_factor
			
			# Keep movement horizontal
			velocity.y = 0
			if velocity.length() < 0.1:
				velocity = last_move_direction * move_speed
			else:
				# Apply random horizontal curve
				velocity = velocity.normalized() * move_speed
				velocity = velocity.rotated(Vector3.UP, randf_range(-0.2, 0.2))
				last_move_direction = velocity.normalized()
		if velocity.length() < 0.05 and not moving:
			moving = true
			velocity = last_move_direction * move_speed
		
			

func _on_hitbox_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and can_hit:
		print("hit")
		can_hit = false
		var knockback_direction = (body.global_position - global_position).normalized()
		if is_in_group("PitSkull"):
			body.hit()
		else:
			body.take_damage(1, knockback_direction * 15.0)
		$Hit.play()
		$Timer.start()

func hit() -> void:
	is_stunned = true
	velocity = Vector3.ZERO
	$StunTimer.start()

func _on_timer_timeout() -> void:
	can_hit = true


func _on_stun_timer_timeout() -> void:
	is_stunned = false
	if last_move_direction == Vector3.ZERO:
		last_move_direction = Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
	velocity = last_move_direction * move_speed
