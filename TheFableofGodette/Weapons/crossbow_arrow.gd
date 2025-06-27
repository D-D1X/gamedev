extends RigidBody3D

var stuck := false
var hit_object = null
var hit_position := Vector3.ZERO
var hit_normal := Vector3.ZERO
@onready var player := get_tree().get_first_node_in_group("Player")

signal cleanup(arrow)

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	cleanup.connect(player._on_crossbow_arrow_cleanup)
	

func launch(direction: Vector3, speed: float):
	# Set initial velocity
	linear_velocity = direction * speed
	
	# Align arrow with velocity
	look_at(global_position + direction)

func _on_body_entered(body):
	if stuck: return
	
	# Don't stick to certain objects
	if body.is_in_group("Player") or body.is_in_group("Arrow"):
		return
		
	# Store hit data
	hit_object = body
	hit_position = global_position
	hit_normal = (global_position - body.global_position).normalized()
	
	print("hit: ", body)
	
	if body.has_method("hit") and body.has_method("take_damage"):
		if body.has_method("process_blocking"):
			if not body.blocking:
				body.take_damage(3, linear_velocity.normalized() * 8.0)
		else:
			body.take_damage(3, linear_velocity.normalized() * 8.0)
		queue_free()
		return
	
	if body.has_method("smash"):
		body.call_deferred("smash")
		return
	# Stick the arrow
	stuck = true
	
	# Stop physics simulation
	freeze = true
	
	set_collision_layer_value(4,0)
	
		
	# Try to parent to hit object if possible
	if body is CollisionObject3D:
		print("hit body")
		var original_transform = global_transform
		call_deferred("_safe_reparent", body, original_transform)
	
	


func _safe_reparent(new_parent, original_transform):
	reparent(new_parent)
	global_transform = original_transform

func _on_timer_timeout() -> void:
	cleanup.emit(self)
	queue_free()
