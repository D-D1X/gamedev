extends Control

@onready var buttons = [$Control/NewGameButton, $Control/ContinueButton, $Control/OptionsButton, $Control/ExitButton]
@onready var resolution_button := $OptionsPanel/VBoxContainer/ResolutionButton
@onready var subviewport := $SubViewportContainer/MainMenuViewport

var resolutions = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var options := false
var selected_index := 0
var move_cooldown := 0.2
var move_timer := 0.0
var axis_deadzone := 0.5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for res in resolutions:
		resolution_button.add_item("%dx%d" % [res.x, res.y])
	
	resolution_button.connect("item_selected", _on_resolution_selected)
	
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var is_fullscreen = config.get_value("display", "fullscreen", false)
		toggle_fullscreen(is_fullscreen)
		var saved_res = config.get_value("display", "resolution", Vector2i(1280, 720))
		if saved_res in resolutions:
			var index = resolutions.find(saved_res)
			resolution_button.select(index)
			DisplayServer.window_set_size(saved_res)
	else:
		var current_res = DisplayServer.window_get_size()
		for i in resolutions.size():
			if resolutions[i] == current_res:
				resolution_button.select(i)
				break
	
	if Globals.controller:
		buttons[selected_index].grab_focus()
	$OptionsPanel.hide()
	$Credits.hide()
	Globals.main_menu = true
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if move_timer > 0:
		move_timer -= delta
		

func _unhandled_input(event):
	if Globals.controller and not options:
		if event is InputEventJoypadMotion and move_timer <= 0:
			if event.axis == JOY_AXIS_LEFT_Y:
				if event.axis_value < -axis_deadzone:
					select_previous()
					move_timer = move_cooldown
				elif event.axis_value > axis_deadzone:
					select_next()
					move_timer = move_cooldown
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
			var focused = get_viewport().gui_get_focus_owner()
			if focused and focused is TextureButton:
				focused.set_pressed_no_signal(true)  # Show press visual
				await get_tree().create_timer(0.1).timeout
				focused.set_pressed_no_signal(false)
				focused.emit_signal("pressed")

func select_next():
	selected_index = (selected_index + 1) % buttons.size()
	buttons[selected_index].grab_focus()

func select_previous():
	selected_index = (selected_index - 1 + buttons.size()) % buttons.size()
	buttons[selected_index].grab_focus()

func _on_options_button_pressed() -> void:
	options = true
	$OptionsPanel.mouse_filter = MOUSE_FILTER_STOP
	$OptionsPanel.show()

func _on_new_game_button_pressed() -> void:
	Globals.new_game = true
	Globals.main_menu = false
	SceneLoader.load_scene("res://scenes/levels/overworld.tscn")

func _on_continue_button_pressed() -> void:
	Globals.main_menu = false
	SceneLoader.load_game()

func _on_controller_toggle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		Globals.controller = true
	else:
		Globals.controller = false

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_resolution_selected(index):
	var new_res = resolutions[index]
	DisplayServer.window_set_size(new_res)
	print("Resolution changed to: ", new_res)

func toggle_fullscreen(enable: bool):
	if enable:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_apply_pressed() -> void:
	var config = ConfigFile.new()
	config.set_value("display", "resolution", resolutions[resolution_button.get_selected_id()])
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	config.save("user://settings.cfg")
	$OptionsPanel.hide()
	$OptionsPanel.mouse_filter = MOUSE_FILTER_IGNORE
	options = false
	$Audio/Accept.play()


func _on_new_game_button_focus_entered() -> void:
	$Audio/Click.play()

func _on_continue_button_focus_entered() -> void:
	$Audio/Click.play()

func _on_options_button_focus_entered() -> void:
	$Audio/Click.play()

func _on_exit_button_focus_entered() -> void:
	$Audio/Click.play()

func _on_new_game_button_mouse_entered() -> void:
	$Audio/Click.play()

func _on_continue_button_mouse_entered() -> void:
	$Audio/Click.play()

func _on_options_button_mouse_entered() -> void:
	$Audio/Click.play()

func _on_exit_button_mouse_entered() -> void:
	$Audio/Click.play()

func _on_credits_button_pressed() -> void:
	$Credits.show()

func _on_close_button_pressed() -> void:
	$Credits.hide()
