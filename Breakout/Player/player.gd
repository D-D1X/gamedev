extends CharacterBody2D

var distance: int = 300
var can_laser: bool =  true
var can_grenade: bool =  true
var grenade_position = Vector2()
signal laser(pos, direction)
signal grenade_toss(pos, direction)
@export var max_speed: int = 500
var speed: int = max_speed

func _process(_delta):
	# input
	# movement
	var direction = Input.get_vector("left", "right", "up", "down")
	velocity = direction * speed
	move_and_slide()
	
	# rotate
	look_at(get_global_mouse_position())
	var player_direction =(get_global_mouse_position() - position).normalized()
	
	# shooting
	if Input.is_action_pressed("primary action") and can_laser and Globals.laser_amount > 0:
		Globals.laser_amount -= 1
		var laser_markers = $LaserStartPos.get_children()
		var selected_laser = laser_markers[randi() % laser_markers.size()]
		can_laser = false
		$LaserTimer.start()
		laser.emit(selected_laser.global_position, player_direction)
		$GPUParticles2D.emitting = true
		$GPUParticles2D2.emitting = true
		$GPUParticles2D3.emitting = true

	if Input.is_action_pressed("secondary action") and can_grenade and Globals.grenade_amount > 0:
		Globals.grenade_amount -= 1
		var grenade_markers = $GrenadeStartPos.get_children()
		var selected_grenade = grenade_markers[randi() % grenade_markers.size()]
		can_grenade = false
		$GrenadeTimer.start()
		grenade_toss.emit(selected_grenade.global_position, player_direction)

func _on_timer_timeout():
	can_laser = true

func _on_timer_2_timeout():
	can_grenade = true
