extends Control

@onready var heart_container = $Hearts/MarginContainer/HBoxContainer
@onready var spell_texture = $Spells/MarginContainer/TextureRect
@onready var mana = $Mana/MarginContainer/TextureProgressBar
@onready var rupees = $Rupees/MarginContainer/HBoxContainer/Label
@onready var keys = $Keys/MarginContainer/HBoxContainer/Label
@onready var arrows = $Crosshair/CenterContainer/MarginContainer2/Label
@onready var stamina_bar = $Stamina/CenterContainer/MarginContainer/TextureProgressBar


var heart_scene: PackedScene = preload("res://scenes/entities/player/heart.tscn")
var fire_texture = preload("res://graphics/ui/fire.png")
var ice_texture = preload("res://graphics/ui/snowflake (1).png")
var heal_texture = preload("res://graphics/ui/heal.png")

@onready var buttons := [$Pause/VBoxContainer/Resume, $Pause/VBoxContainer/Controls, $Pause/VBoxContainer/Save, $Pause/VBoxContainer/MainMenu]
@onready var gameover_buttons := [$GameOver/CenterContainer/MarginContainer2/HBoxContainer/Retry, $GameOver/CenterContainer/MarginContainer2/HBoxContainer/MainMenu]

@onready var GOmat = $GameOver/CenterContainer/MarginContainer/Label.material
@onready var overlay = $ColorRect
@onready var gameover_container = $GameOver/CenterContainer/MarginContainer2
@onready var retry = $GameOver/CenterContainer/MarginContainer2/HBoxContainer/Retry
@onready var mainmenu = $GameOver/CenterContainer/MarginContainer2/HBoxContainer/MainMenu

@onready var item_panel := $ItemPanel
@onready var item_description := $ItemPanel/MarginContainer/MarginContainer/HBoxContainer/text
@onready var price := $Price/MarginContainer/HBoxContainer/Label

@onready var player = get_tree().get_first_node_in_group("Player")
@onready var oldman = get_tree().get_first_node_in_group("Oldman")
@onready var wait_for_input = $ItemPanel/MarginContainer/MarginContainer/TextIcon/AnimationPlayer
signal chest_done
signal close_dialogue

var stamina_upgraded := false
var paused := false
var controls := false
var gameover := false
var selected_index := 0
var move_cooldown := 0.2
var move_timer := 0.0
var axis_deadzone := 0.5

const SAVE_PATH := "user://savegame.json"

func _ready() -> void:
	update_rupees(0)
	if Globals.max_mana == 200:
		upgrade_mana()
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$GameOver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_container.modulate = Color(1,1,1,0)
	$Price.hide()
	$Crosshair.hide()
	$Panel.hide()
	$Pause.hide()
	item_panel.hide()
	if not Globals.spells:
		$Mana.hide()
		$Spells.hide()
	overlay.show()
	if Globals.new_game:
		set_process_unhandled_input(false)
		set_process(false)
		$Hearts.hide()
		$Rupees.hide()
		overlay.modulate = Color(1,1,1,1)
	else:
		overlay.modulate = Color(1,1,1,0)

func _process(delta: float) -> void: 
	if move_timer > 0:
		move_timer -= delta
	if Input.is_action_just_pressed("accept") and controls:
		controls = false
		$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$Panel.hide()

func _unhandled_input(event: InputEvent) -> void:
	if Globals.controller and (paused or gameover) and !controls:
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
	if paused:
		selected_index = (selected_index + 1) % buttons.size()
		buttons[selected_index].grab_focus()
	else:
		selected_index = (selected_index + 1) % gameover_buttons.size()
		gameover_buttons[selected_index].grab_focus()

func select_previous():
	if paused:
		selected_index = (selected_index - 1 + buttons.size()) % buttons.size()
		buttons[selected_index].grab_focus()
	else:
		selected_index = (selected_index - 1 + gameover_buttons.size()) % gameover_buttons.size()
		gameover_buttons[selected_index].grab_focus()

func setup(value: int) -> void:
	for child in heart_container.get_children():
		child.queue_free()
	for i in value:
		var heart = heart_scene.instantiate()
		heart_container.add_child(heart)
		heart.change_alpha(1.0)
		await get_tree().create_timer(0.3).timeout

func update_health(value: int, direction: int) -> void:
	if direction == 0:
		return
	for child in heart_container.get_children():
		heart_container.remove_child(child)
		child.free()  # Immediately frees the node (no flashing)
	# Add hearts for current health
	if direction > 0:
		for i in value - 1:
			var heart = heart_scene.instantiate()
			heart_container.add_child(heart)
		var extra_heart = heart_scene.instantiate()
		heart_container.add_child(extra_heart)
		extra_heart.change_alpha(1.0)
	else:
		for i in value:
			var heart = heart_scene.instantiate()
			heart_container.add_child(heart)
		var extra_heart = heart_scene.instantiate()
		heart_container.add_child(extra_heart)
		extra_heart.change_alpha(0.0)

func update_spell(spells, current_spells) -> void:
	if current_spells == spells.FIREBALL:
		spell_texture.texture = fire_texture
	elif current_spells == spells.ICEBALL:
		spell_texture.texture = ice_texture
	elif current_spells == spells.HEAL:
		spell_texture.texture = heal_texture
		
func show_mana() -> void:
	$Mana.show()

func update_mana(value:int) -> void:
	mana.value = value

func upgrade_mana() -> void:
	mana.max_value = Globals.max_mana
	mana.value = Globals.max_mana
	var bar = mana.get_parent()
	bar.scale.x = 1.75 

func update_rupees(value:int) -> void:
	Globals.rupee_value += value
	if Globals.rupee_value < 0:
		Globals.rupee_value = 0
	var rupees_text = str(Globals.rupee_value)
	rupees.text = rupees_text

func update_keys() -> void:
	var key_text = str(Globals.keys)
	keys.text = key_text

func update_arrows(value:int) -> void:
	var arrow_text = str(value)
	arrows.text = arrow_text
	
func update_stamina(current: int, target: int) -> void:
	var tween = create_tween()
	tween.tween_method(_change_stamina, current, target, 0.25)
	
func _change_stamina(value:int):
	stamina_bar.value = value
	
func upgrade_stamina():
	stamina_upgraded = true
	stamina_bar.max_value = Globals.max_stamina
	

func stamina_color(value:bool):
	if value:
		if stamina_upgraded:
			stamina_bar.tint_progress = "ffff00"
		else:
			stamina_bar.tint_progress = "00f159"
	else:
		stamina_bar.tint_progress = "a52708"

func game_over() -> void:
	$GameOver/GameOver.play()
	$GameOver.mouse_filter = Control.MOUSE_FILTER_STOP
	$Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	selected_index = 0
	gameover = true
	if Globals.controller:
		gameover_buttons[selected_index].grab_focus()
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 2.75)
	tween.tween_method(_change_time, 0.0, 1.0, 2.5)
	await tween.finished
	var tween2 = create_tween()
	tween2.tween_property(gameover_container, "modulate:a", 1.0, 1.0)
	await tween2.finished
	if not Globals.controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	retry.disabled = false
	mainmenu.disabled = false
	
func _change_time(value: float) -> void:
	GOmat.set_shader_parameter('time', value)
	
func show_shop_item(info:String, item_price:int) -> void:
	item_panel.visible = true
	$Price.show()
	price.text = str(item_price)
	item_description.text = info
	
func hide_shop() -> void:
	$Price.hide()
	price.text = ""
	item_panel.visible = false
	item_description.text = ""

func show_chest_item(item: ItemData) -> void:
	item_panel.visible = true
	item_panel.process_mode = PROCESS_MODE_ALWAYS
	await type_text(item.description)
	
	process_mode = PROCESS_MODE_ALWAYS
	wait_for_input.play("waiting_for_input")
	await wait_for_accept()
	hide_chest_item()

func cutscene_text(text: Array, duration: float, toggle: bool) -> void:
	item_panel.visible = true
	item_panel.process_mode = PROCESS_MODE_ALWAYS
	for message in text:
		type_text(message)
		await get_tree().create_timer(duration).timeout
	item_panel.visible = false
	if toggle:
		var tween = create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, 2.75)
	



func dialogue(text: Array) -> void:
	item_panel.visible = true
	item_panel.process_mode = PROCESS_MODE_ALWAYS
	for message in text:
		oldman.emote()
		await type_text(message)
	
		wait_for_input.play("waiting_for_input")
		await wait_for_accept()
		wait_for_input.stop()
	exit_dialogue()

func type_text(text: String) -> void:
	var displayed_text = ""
	var index = 0
	var speed = 0.025  # Adjust typing speed
	var skip_requested = false
	
	flush_input()
	
	while index < text.length() and not skip_requested:
		if Input.is_action_just_pressed("accept"):
			skip_requested = true
		
		displayed_text += text[index]
		item_description.text = displayed_text
		index += 1
		await get_tree().create_timer(speed if not skip_requested else 0.0).timeout
	
	item_description.text = text 
	
	while Input.is_action_pressed("accept"):
		await get_tree().process_frame

func wait_for_accept() -> void:
	flush_input()
	while not Input.is_action_just_pressed("accept"):
		await get_tree().process_frame
	# Wait for release to prevent instant skip
	while Input.is_action_pressed("accept"):
		await get_tree().process_frame

func flush_input() -> void:
	# Clear any lingering input state
	Input.action_release("accept")
	# Force Godot to update input state
	Input.parse_input_event(InputEventAction.new().duplicate())
	
func hide_chest_item() -> void:
	$Accept.play()
	wait_for_input.stop()
	item_panel.visible = false
	emit_signal("chest_done")  # Call camera reset

func exit_dialogue() -> void:
	$Accept.play()
	item_panel.visible = false
	emit_signal("close_dialogue")

func _on_dungeon_warp() -> void:
	$Warp.show()
	var mat = $Warp/TextureRect.material
	if mat is ShaderMaterial:
		var tween_in = create_tween()
		tween_in.tween_method(
			func(val): mat.set_shader_parameter("alpha", val),
			mat.get_shader_parameter("alpha"),
			1.0,
			1.25
		)
		await get_tree().create_timer(2.5).timeout
		var tween_out = create_tween()
		tween_out.tween_method(
			func(val): mat.set_shader_parameter("alpha", val),
			mat.get_shader_parameter("alpha"),
			0.0,
			1.25
		)
		await tween_out.finished
		$Warp.hide()

func _dungeon_fade(on: float):
	var tween = create_tween()
	tween.tween_property($DungeonName, "modulate:a", on, 2.0)

func reset_ui():
	$Stamina.show()
	$Hearts.show()
	$Rupees.show()
	if Globals.spells:
		$Mana.show()
		if player.weapon_mode == player.WeaponMode.SPELLS:
			$Spells.show()
	if get_tree().current_scene.is_in_group("Dungeon"):
		$Keys.show()

func hide_ui():
	$Stamina.hide()
	$Hearts.hide()
	$Rupees.hide()
	$Mana.hide()
	$Keys.hide()
	$Spells.hide()

func pause():
	$Pause.show()
	if not Globals.controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$Pause/MarginContainer.hide()
	paused = true
	$Pause.mouse_filter = Control.MOUSE_FILTER_STOP
	if Globals.controller:
		buttons[selected_index].grab_focus()
	
	
func _on_resume_pressed() -> void:
	$Pause/MarginContainer.hide()
	paused = false
	player.resume_game()

func set_mouse():
	$Pause.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_save_pressed() -> void:
	save_game()

func _on_main_menu_pressed() -> void:
	Globals.main_menu = true
	SceneLoader.load_scene("res://scenes/levels/main_menu.tscn")

func save_game():
	SceneLoader.save_game(player)
	$Pause/MarginContainer.show()
	$Accept.play()
	print("Game Saved!")


func _on_retry_pressed() -> void:
	Globals.player_dead = false
	SceneLoader.load_game()

func _on_controls_pressed() -> void:
	$Pause/MarginContainer.hide()
	$Panel.show()
	controls = true
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_resume_focus_entered() -> void:
	$Click.play()

func _on_resume_mouse_entered() -> void:
	$Click.play()

func _on_controls_focus_entered() -> void:
	$Click.play()

func _on_controls_mouse_entered() -> void:
	$Click.play()

func _on_save_focus_entered() -> void:
	$Click.play()

func _on_save_mouse_entered() -> void:
	$Click.play()

func _on_main_menu_focus_entered() -> void:
	if gameover:
		$Click.play()

func _on_main_menu_mouse_entered() -> void:
	if gameover:
		$Click.play()

func _on_retry_focus_entered() -> void:
	if gameover:
		$Click.play()

func _on_retry_mouse_entered() -> void:
	if gameover:
		$Click.play()

func credits() -> void:
	overlay.show()
	var tween = create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 2.0)
	
func opening() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	$Cutscene.play()
