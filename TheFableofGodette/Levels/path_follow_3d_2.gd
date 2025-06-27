extends PathFollow3D

@export var speed: float = 5.0

func _ready() -> void:
	progress = 5.75

func _process(delta: float) -> void:
	progress += speed * delta
