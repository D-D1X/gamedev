extends Camera3D
#
#@export var mouse_sensitivity := 0.003
#@export var vertical_limit_up := deg_to_rad(50)
#@export var vertical_limit_down := deg_to_rad(-30)
#
#@onready var player = get_tree().get_first_node_in_group("Player")
#var yaw := 0.0
#var pitch := 0.0
#
#func _process(delta: float) -> void:
	#if Globals.player_dead:
		#return
	#rotation.y = yaw
	#rotation.x = pitch  # Vertical look is local to camera
#
#func _input(event: InputEvent) -> void:
	#if Globals.player_dead:
		#return
#
	#if event is InputEventMouseMotion and not Globals.chest_opening:
		#yaw -= event.relative.x * mouse_sensitivity
		#pitch -= event.relative.y * mouse_sensitivity
		#pitch = clamp(pitch, vertical_limit_down, vertical_limit_up)
