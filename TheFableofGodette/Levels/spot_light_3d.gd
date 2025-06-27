extends SpotLight3D

@export var player : Node3D
var offset : Vector3
var mapmode := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	offset = global_position - player.global_position


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if mapmode:
		hide()
	else:
		show()
	var target_position = player.global_position + offset
	global_position.x = target_position.x
	global_position.z = target_position.z


func _on_player_map_open() -> void:
	mapmode = true


func _on_player_map_close() -> void:
	mapmode = false
