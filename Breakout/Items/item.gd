extends Area2D

signal collected(pos)

var rotation_speed: int = 4
var available_options: Array = ['laser', 'laser', 'laser', 'grenade', 'health']
var type = available_options[randi()%len(available_options)]

var direction: Vector2
var distance: int = randi_range(150,200)

func _ready():
	if type == 'laser':
		$Sprite2D.modulate = Color('83ffff')
	elif type == 'grenade':
		$Sprite2D.modulate = Color('ff863f')
	elif type == 'health':
		$Sprite2D.modulate = Color('6bff67')
		
	# tween
	var target_pos = position + direction * distance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.5)
	tween.tween_property(self, "scale", Vector2(1,1), 0.3).from(Vector2(0,0))

func _process(delta):
	rotation += rotation_speed * delta

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if type == 'laser':
			Globals.laser_amount += 5
			if Globals.laser_amount > Globals.max_laser:
				Globals.laser_amount = Globals.max_laser
		elif type == 'grenade' and Globals.grenade_amount < Globals.max_grenade:
			Globals.grenade_amount += 1
		elif type == 'health':
			Globals.health += 10
			if Globals.health > Globals.max_health:
				Globals.health = Globals.max_health
	collected.emit(global_position)
	queue_free()
