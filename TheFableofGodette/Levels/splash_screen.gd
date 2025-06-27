extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func switch_scene():
	SceneLoader.load_scene("res://scenes/levels/main_menu.tscn")
