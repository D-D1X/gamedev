extends PathFollow3D

@export var speed: float = 5.0
var loaded := false

func _process(delta: float) -> void:
	if loaded:
		progress -= speed * delta


func _on_door_trigger_body_entered(_body: Node3D) -> void:
	loaded = true
