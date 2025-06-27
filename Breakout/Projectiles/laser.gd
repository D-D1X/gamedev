extends Area2D

@export var speed: int = 1000
var direction: Vector2

func _ready():
	$SDTimer.start()

func _process(delta):
	position += direction * speed * delta
	
func _on_body_entered(body):
	if "on_hit" in body:
		body.on_hit()
	queue_free()

func _on_sd_timer_timeout():
	queue_free()
