extends CharacterBody2D

var speed:int = 500
var direction:int = 1
var distance:int = 300
var start_position = Vector2()


func _ready():
	start_position = global_position

func _process(_delta):
	velocity.x = speed * direction
	move_and_slide()
	
	if abs(global_position.x - start_position.x) >= distance:
		direction *= -1

func on_hit():
	print("damage")
