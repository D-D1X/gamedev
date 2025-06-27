extends LevelParent


func _ready():
	super._ready()
	$Player/PointLight2D.visible = false

func _input(event):
	if event.is_action_pressed("flashlight"):
		$Player/PointLight2D.visible = !$Player/PointLight2D.visible

func _on_exit_gate_area_body_entered(_body):
	var tween = create_tween()
	tween.tween_property($Player,"speed",0,0.5)
	TransitionLayer.change_scene("res://scenes/levels/outside.tscn")
