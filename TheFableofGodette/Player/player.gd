extends CharacterBody3D

@export var jump_height := 2.25
@export var jump_time_to_peak := 0.5
@export var jump_time_to_descent := 0.4

@onready var jump_velocity := ((2.0*jump_height) / jump_time_to_peak) * -1.0 
@onready var jump_gravity := ((-2.0*jump_height) / (jump_time_to_peak * jump_time_to_peak)) * -1.0 
@onready var fall_gravity := ((-2.0*jump_height) / (jump_time_to_descent * jump_time_to_descent)) * -1.0 

@export var base_speed := 4.0
@export var run_speed := 6.5
@export var defend_speed := 2.0
@export var aim_speed := 3.0
var jumping := false
var speed_modifier := 1.0

@onready var held_item_slot = $ItemPickUp
var held_item = null

@export var target_range: float = 10.0
var current_target: Node3D = null
var is_targeting = false
var new_state = "Idle"
var locked_on := false
var block_hit := false

signal spell_cast(type: String, pos: Vector3, direction: Vector2, size: float, caster: Node3D)
signal targeting(targeting: bool, current: Node3D)
signal map_open
signal map_close

@onready var camera = $CameraController/Shake/Camera3D
@onready var chest_camera = $GodetteSkin/Camera3D
@onready var spring_arm = $CameraController
@onready var item_spawn = $GodetteSkin/Rig/ItemSpawn
@onready var crossbow_camera_pos = $GodetteSkin/Yaw/Pitch/CrossbowAimPosition
@onready var fp_yaw = $GodetteSkin/Yaw
@onready var fp_pitch = $GodetteSkin/Yaw/Pitch
var original_camera_transform: Transform3D
var original_camera_fov
var original_spring_length: float
var original_spring_position
var original_map_cam_pos
var is_aiming := false
@onready var skin = $GodetteSkin
@onready var sword = $GodetteSkin/Rig/Skeleton3D/RightHandSlot/Sword
@onready var shield = $GodetteSkin/Rig/Skeleton3D/LeftHandSlot/PlayerShield
@onready var crossbow = $GodetteSkin/Rig/Skeleton3D/RightHandSlot/Crossbow
@onready var head_crossbow = $GodetteSkin/Yaw/Pitch/Crossbow2
@onready var crossbow_anim = $GodetteSkin/Yaw/Pitch/Crossbow2/AnimationPlayer
@onready var crosshair = $UI/Crosshair
@onready var crossbow_fire = $GodetteSkin/Yaw/Pitch/Crossbow2/Fire
@onready var crossbow_reload = $GodetteSkin/Yaw/Pitch/Crossbow2/Reload
@onready var crossbow_reload_2 = $GodetteSkin/Yaw/Pitch/Crossbow2/Reload2
@onready var head = $GodetteSkin/Rig/Skeleton3D/Godette_Head
@onready var ui = $UI
@onready var pause_menu = $UI/Pause
@onready var top_bar = $UI/LockOn/TopBar
@onready var bottom_bar = $UI/LockOn/BottomBar
@onready var raycast = $GodetteSkin/RayCast3D
@onready var flash_loop_running := false
@onready var minimap := $MapRoot/MarginContainer/PanelContainer/SubViewportContainer/SubViewport/Minimap
@onready var panel := $MapRoot/MarginContainer/PanelContainer
@onready var map_ui := $MapRoot/MapUI
@onready var fade := $MapRoot/FadeRect
@onready var combat_music := $Music/Combat
@onready var boss_music := $Music/BossBattle
@onready var boss_music_loop := $Music/BossBattleLoop
@onready var shop_music := $Music/Shopping
@onready var default_music := $Music/Default
@onready var music_tween := create_tween()
var default_volume : float
var in_combat := false
var shop_camera : Camera3D
var movement_input := Vector2.ZERO
var is_knockback := false
var knockback_velocity := Vector3.ZERO
var knockback_duration := 0.2
var defend := false:
	set(value):
			if not defend and value and not Globals.player_dead:
				skin.set_defend_state("Blocking")
				skin.defend(true)
				Globals.blocking = true
			if defend and not value:
				Globals.blocking = false
				skin.set_defend_state("Idle")
				skin.defend(false)
			defend = value
var weapon_active := true:
	set(value):
		weapon_active = value
		if weapon_mode != WeaponMode.CROSSBOW:
			if weapon_active:
				ui.get_node("Spells").hide()
			else:
				ui.get_node("Spells").show()
enum WeaponMode {SWORD, SPELLS, CROSSBOW}
var weapon_mode := WeaponMode.SWORD:  
	set(value):
		weapon_mode = value
		match weapon_mode:
			WeaponMode.SWORD:
				$Switch/Sword.play()
				ui.get_node("Spells").hide()
				weapon_active = true
				is_aiming = false
				if Globals.shield:
					shield.show()
				skin.switch_weapon(0)
			WeaponMode.SPELLS:  
				$Switch/Wand.play()
				ui.get_node("Spells").show()
				weapon_active = false
				if Globals.shield:
					shield.show()
				skin.switch_weapon(1)
			WeaponMode.CROSSBOW:
				$Switch/Crossbow.play()
				ui.get_node("Spells").hide()
				weapon_active = false
				is_aiming = false
				shield.hide()
				skin.switch_weapon(2)
var invulnerable := false
var is_invulnerable := false
var game_over := false
var health = 5:
	set(value):
		value = min(value,Globals.max_health)
		ui.update_health(value, value - health)
		health = value
		if health <= 0:
			if frozen:
				await $Timers/FreezeTimer.timeout
			default_music.stop()
			boss_music.stop()
			combat_music.stop()
			shop_music.stop()
			Globals.player_dead = true
			collision_layer = 0
			collision_mask = 0
			$CollisionShape3D.set_deferred("disabled", true)        
			game_over = true
			skin.set_move_state("Death_B")
			skin.set_defend_state("Death_B")
			await get_tree().create_timer(3.0).timeout
			ui.game_over()
var mana = 100:
	set(value):
		mana = min(Globals.max_mana,value)
		ui.update_mana(mana)
var arrow_count = 10:
	set(value):
		arrow_count = min(25, value)
		ui.update_arrows(arrow_count)
var stamina = 100:
	set(value):
		ui.update_stamina(stamina, value)
		stamina = clamp(value, 0, Globals.max_stamina)
		var stamina_ui = ui.get_node("Stamina")
		var target_alpha = 1.0 if stamina < Globals.max_stamina else 0.0
		var tween = create_tween()
		tween.tween_property(stamina_ui, "modulate:a", target_alpha, 0.25)
var stamina_available := true
var exertion := true
@export var max_arrows := 10
var can_shoot := true
var arrows := []
var arrow_scene = preload("res://scenes/Weapons/crossbow_arrow.tscn")
enum spells {FIREBALL, ICEBALL, HEAL}
var available_spells := []
var current_spell = spells.FIREBALL
var last_safe_position: Vector3
var is_falling := false
var door_opening := false
var burn := false
var frozen := false
var heal := false
var shop_active := false
var shop : Node3D
var help_text : Control
var interacting := false
var enemies_nearby := 0
var in_grass := false
var big_chest := false
var music_tweens := {}

func _ready() -> void:
	if Globals.new_game:
		$MapRoot.hide()
		set_physics_process(false)
		Globals.camera_locked = true
		$CutsceneCamera/Camera.make_current()
		skin.set_move_state("Lie_Idle")
	for entity in get_tree().get_nodes_in_group("Entity"):
		print("ENTITY")
		if entity.has_signal("enemy_detected"):
			entity.connect("enemy_detected", on_enemy_detected)
		if entity.has_signal("enemy_left"):
			entity.connect("enemy_left", on_enemy_left)
	for chest in get_tree().get_nodes_in_group("Locked"):
		if chest.has_signal("unlock"):
			chest.connect("unlock", puzzle_solved)
	help_text = ui.get_node("HelpText")
	call_deferred("_init_after_scene_ready")
	
	
func _init_after_scene_ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if get_tree().current_scene.is_in_group("Dungeon"):
		if not Globals.crossbow:
			$CutsceneCamera/Camera.make_current()
		default_music.stream = $Music/Dungeon.stream
		default_volume = -5.0
	else:
		for grass in get_tree().get_nodes_in_group("Grass"):
			if grass.has_signal("in_grass"):
				grass.connect("in_grass", enter_grass)
			if grass.has_signal("out_grass"):
				grass.connect("out_grass", left_grass)
		default_music.stream = $Music/Overworld.stream
		default_volume = 0.0
	if not Globals.new_game:
		default_music.play()
	last_safe_position = global_position
	if Globals.shield:
		shield.show()
	else:
		shield.hide()
	if Globals.sword:
		sword.show()
	else:
		sword.hide()
	crossbow.hide()
	head_crossbow.hide()
	mana = Globals.max_mana
	health = Globals.max_health
	ui.setup(health)
	
func _input(event):
	if event.is_action_pressed("unstuck"):
		unstuck()
	if event.is_action_pressed("map"):
		if (get_tree().current_scene.name == "Dungeon" and Globals.dungeon_map == true) or (get_tree().current_scene.name == "Overworld" and Globals.map == true):
			if not minimap.map_mode:
				$MapRoot.show()
				open_map()
				emit_signal("map_open")
			else:
				close_map()
				emit_signal("map_close")
	if event.is_action_pressed("hide_map"):
		if (get_tree().current_scene.name == "Dungeon" and Globals.dungeon_map == true) or (get_tree().current_scene.name == "Overworld" and Globals.map == true):
			if not minimap.map_mode:
				if $MapRoot.visible:
					$MapRoot.hide()
				else:
					$MapRoot.show()
	if not Globals.controller:
		if event is InputEventMouseMotion and is_aiming:
			fp_yaw.rotation.y = clamp(
				fp_yaw.rotation.y + deg_to_rad(-event.relative.x * 0.25),
				deg_to_rad(-45),
				deg_to_rad(45))
			
			# Vertical rotation (PITCH)
			fp_pitch.rotation.x = clamp(
				fp_pitch.rotation.x + deg_to_rad(-event.relative.y * 0.25),
				deg_to_rad(-45),
				deg_to_rad(30)
			)

func _unhandled_input(event):
	if not game_over:
		if event.is_action_pressed("ui_cancel") and not Globals.camera_locked and is_on_floor(): 
			if get_tree().paused:
				resume_game()
			else:
				pause_game()


func _physics_process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set("player_position", global_position)
	if Globals.cinematic or door_opening: return
	if is_falling:
		jump_logic(delta)
		return
	if game_over:
		show_cinematic_bars(false)
		return
	if not locked_on:
		find_closest_target(false)	
	if is_aiming:
		ability_logic(delta)
		if Globals.controller:
			var right_stick_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
			var right_stick_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

			# Apply deadzone
			if abs(right_stick_x) < 0.15:
				right_stick_x = 0
			if abs(right_stick_y) < 0.15:
				right_stick_y = 0
			
			# Apply sensitivity adjustment
			var controller_sensitivity = 1.5 
			
			# Update yaw (horizontal rotation)
			fp_yaw.rotation.y = clamp(
				fp_yaw.rotation.y + deg_to_rad(-right_stick_x * controller_sensitivity * delta * 60.0),
				deg_to_rad(-45),
				deg_to_rad(45))
			
			# Update pitch (vertical rotation)
			fp_pitch.rotation.x = clamp(
				fp_pitch.rotation.x + deg_to_rad(-right_stick_y * controller_sensitivity * delta * 60.0),
				deg_to_rad(-45),
				deg_to_rad(30))
		return
	if raycast.is_colliding() and not interacting:
		help_text.show()
	else:
		help_text.hide()
	if not frozen:
		if shop_active:
			handle_shop_input()
		else:
			move_logic(delta)
			jump_logic(delta)
			ability_logic(delta)
			interact_logic(delta)
			move_and_slide()
	if is_on_floor():
		jumping = false
	if is_targeting and is_instance_valid(current_target):
		targeting.emit(is_targeting, current_target)
	else:
		targeting.emit(false, null)


func set_safe_position(new_position: Vector3):
	last_safe_position = new_position
		
func move_logic(delta) -> void:
	if is_knockback:
		velocity = knockback_velocity
		velocity.y -= 9.8 * delta
		move_and_slide()
		knockback_velocity = velocity * 0.9  # Add damping
		return
	
	if is_targeting and current_target and is_instance_valid(current_target):
		if global_position.distance_to(current_target.global_position) > target_range:
			current_target.get_node("Arrow").hide()
			is_targeting = false
			current_target = null
	# Z-targeting movement
	if is_targeting and current_target and is_instance_valid(current_target) and Input.is_action_pressed("lock_on"):
		movement_input = Input.get_vector("left", "right", "forward", "backward")
		var target_dir = (current_target.global_position - global_position).normalized()
		var target_dir_2d = Vector2(target_dir.x, target_dir.z).normalized()
		var right_dir = target_dir_2d.orthogonal()
		var move_dir = target_dir_2d * movement_input.y + right_dir * movement_input.x
		if movement_input != Vector2.ZERO:
			if Input.is_action_pressed("forward") or Input.is_action_pressed("backward"):
				new_state = "Running_A"
			elif Input.is_action_pressed("left"):
				new_state = "Strafe_Left"
			elif Input.is_action_pressed("right"):
				new_state = "Strafe_Right"
		else:
			new_state = "Idle"
		if skin.get_move_state() != new_state:
			skin.set_move_state(new_state)
		if not is_knockback:
			velocity.x = -move_dir.x * base_speed
			velocity.z = -move_dir.y * base_speed
	# regular movement
	else:
		movement_input = Input.get_vector("left","right","forward","backward").rotated(-camera.global_rotation.y)
		var vel_2d = Vector2(velocity.x, velocity.z)
		
		var acceleration = run_speed * 4.0 if Input.is_action_pressed("run") and stamina_available else base_speed * 3.0
		acceleration = defend_speed * 3.0 if defend else acceleration
		var deceleration = base_speed * 2.0
		var rotation_speed = 6.0 if movement_input != Vector2.ZERO else 12.0
		
		if movement_input != Vector2.ZERO:
			if in_grass and !$Grass.playing:
				if randi_range(0,1) == 1:
					$Grass.stream = $Grass2.stream
				else:
					$Grass.stream = $Grass1.stream
				$Grass.pitch_scale = randf_range(0.95,1.05)
				$Grass.play()
			var target_speed = run_speed if Input.is_action_pressed("run") and stamina_available else base_speed
			target_speed = defend_speed if defend else target_speed
			vel_2d = vel_2d.move_toward(movement_input * target_speed, acceleration * delta)
			vel_2d = vel_2d.limit_length(target_speed) * speed_modifier
			
			# Set animation state
			if Input.is_action_pressed("lock_on") and not is_targeting:
				skin.set_move_state("Running_A")
			else:
				skin.set_move_state('Running_C' if Input.is_action_pressed("run") and stamina_available else 'Running_A')
			if Input.is_action_pressed("run") and stamina_available:
				if skin.move_state_machine.get_current_node() == "Running_C" or not is_on_floor():
					stamina -= 0.2
					exertion = true
			else:
				exertion = false
			var target_angle = -movement_input.angle() + PI/2
			skin.rotation.y = rotate_toward(skin.rotation.y, target_angle, rotation_speed * delta) 
		else:
			vel_2d = vel_2d.move_toward(Vector2.ZERO, deceleration * delta)
			skin.set_move_state("Idle")
			exertion = false
			
		if stamina <= 0:
			stamina_available = false
			ui.stamina_color(false)
		if stamina >= 100:
			stamina_available = true
			ui.stamina_color(true)
		
		velocity.x = vel_2d.x
		velocity.z = vel_2d.y
	
func jump_logic(delta) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			$Jump.pitch_scale = randf_range(0.90,1.05)
			$Jump.play()
			jumping = true
			skin.set_move_state("Jump_Start")
			on_squish_and_stretch(1.1,0.4)
			velocity.y = -jump_velocity
	else:
		skin.set_move_state("Jump_Idle")
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y -= gravity * delta

func ability_logic(_delta) -> void:
	# attack
	if Globals.sword and !weapon_mode == WeaponMode.CROSSBOW:
		if Input.is_action_just_pressed("ability"):
			print("Player Attacking: ", skin.attacking)
			if weapon_active:
				skin.attack()
			else:
				if not skin.attacking:
					skin.cast_spell(heal, mana)
					print("cast spell")
					if heal:
						stop_movement(0.3, 2.0)
					else:
						stop_movement(0.3, 0.8)
		
	# defend
	if Globals.shield and not weapon_mode == WeaponMode.CROSSBOW:
		defend = Input.is_action_pressed("block")
	
	var available_weapons = []
	if Globals.sword:
		available_weapons.append(WeaponMode.SWORD)
	if Globals.crossbow:
		available_weapons.append(WeaponMode.CROSSBOW)
	if Globals.spells:
		available_weapons.append(WeaponMode.SPELLS)
	
	# switch weapon/spell
	if available_weapons.size() > 1 and Input.is_action_just_pressed('switch weapon') and not skin.attacking and not defend and not is_aiming:
		skin.attacking = false
		on_squish_and_stretch(1.05,0.15)

		var current_index := available_weapons.find(weapon_mode)
		current_index = (current_index + 1) % available_weapons.size()
		weapon_mode = available_weapons[current_index]
		
		if is_aiming:
			exit_aim_mode()
	if Globals.spells:
		if Input.is_action_just_pressed("switch spell") and not skin.attacking:
			available_spells = get_unlocked_spells()
			var index = available_spells.find(current_spell)
			if index == -1:
				index = 0
			current_spell = available_spells[(index + 1) % available_spells.size()]
			ui.update_spell(spells, current_spell)
			heal = current_spell == spells.HEAL
	
	if weapon_mode == WeaponMode.CROSSBOW:
		if Input.is_action_just_pressed("block") and not is_aiming and can_shoot:
			skin.defend(true)
			enter_aim_mode()
		elif Input.is_action_just_pressed("ability") and is_aiming and can_shoot and arrow_count > 0:
			fire_arrow()
		elif Input.is_action_just_pressed("block") and is_aiming:
			exit_aim_mode()
	
	# Z-targeting
	if Input.is_action_just_pressed("lock_on"):
		$LockOn.play()
		camera.get_parent().get_parent().pivot_camera()
		show_cinematic_bars(true)
		find_closest_target(true)
		locked_on = true
		
	if Input.is_action_pressed("lock_on"):
		validate_current_target()
	
	if Input.is_action_just_released("lock_on"):
		$LockOff.play()
		if current_target and is_instance_valid(current_target):
			current_target.get_node("Arrow").hide()
		show_cinematic_bars(false)
		is_targeting = false
		current_target = null
		locked_on = false


func interact_logic(_delta) -> void:
	if Input.is_action_just_pressed("interact") and raycast.is_colliding():
		help_text.hide()
		interacting = true
		current_target = null 
		show_cinematic_bars(false)
		var interact_hitbox = raycast.get_collider()
		var interactable = interact_hitbox.get_parent().get_parent()
		if interactable.is_in_group("Chest") and !interactable.is_open and !interactable.is_in_group("Locked"):
			original_camera_transform = camera.global_transform
			original_camera_fov = camera.fov
			Globals.camera_locked = true
			skin.set_move_state("Idle")
			set_physics_process(false)
			await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
			await cinematic_camera_sequence()
			await skin.interact()
			interactable.open()
			await skin.face_camera()
			if interactable.is_in_group("BigChest"):
				big_chest = true
				await skin.raise(true)
			else:
				await skin.raise(false)
			var chest_item = interactable.contained_item.model.instantiate()
			chest_item.process_mode = PROCESS_MODE_ALWAYS
			get_tree().current_scene.add_child(chest_item)
			chest_item.global_position = item_spawn.global_position
			chest_item.global_rotation = item_spawn.global_rotation
			ui.show_chest_item(interactable.contained_item)
			get_tree().paused = true
			await ui.chest_done
			get_tree().paused = false
			interactable.chest_opened()
			chest_item.queue_free()
		elif interactable.is_in_group("DungeonDoor") and !interactable.is_open:
			door_opening = true
			original_camera_transform = camera.global_transform
			original_camera_fov = camera.fov
			Globals.camera_locked = true
			skin.set_move_state("Idle")
			set_physics_process(false)
			await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
			await cinematic_camera_sequence()
			await skin.interact()
			interactable.open()
			await return_to_normal_camera()
			Globals.camera_locked = false
			door_opening = false
			interacting = false
		elif interactable.is_in_group("Door") and !interactable.is_open:
			if Globals.keys > 0:
				door_opening = true
				original_camera_transform = camera.global_transform
				original_camera_fov = camera.fov
				Globals.camera_locked = true
				skin.set_move_state("Idle")
				set_physics_process(false)
				await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
				await cinematic_camera_sequence()
				await skin.interact()
				interactable.open()
				await return_to_normal_camera()
				Globals.camera_locked = false
				Globals.keys -= 1
				ui.update_keys()
				door_opening = false
				interacting = false
			else:
				interactable.locked()
		elif interactable.is_in_group("BigDoor") and !interactable.is_open:
			if Globals.bigkey:
				door_opening = true
				original_camera_transform = camera.global_transform
				original_camera_fov = camera.fov
				Globals.camera_locked = true
				skin.set_move_state("Idle")
				set_physics_process(false)
				await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
				await cinematic_camera_sequence()
				await skin.interact()
				interactable.open()
				await return_to_normal_camera()
				Globals.camera_locked = false
				door_opening = false
				interacting = false
		elif interactable.is_in_group("Shop") and interactable.in_range and not shop_active:
			shop = interactable
			shop_active = true
			shop_music.play()
			_fade_music(default_music, -80)
			_fade_music(shop_music, -15)
			original_camera_transform = camera.global_transform
			original_camera_fov = camera.fov
			shop_camera = interactable.get_node("Camera3D")
			Globals.camera_locked = true
			skin.set_move_state("Idle")
			await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
			await cinematic_camera_sequence("shop")
		elif interactable.is_in_group("Oldman"):
			original_camera_transform = camera.global_transform
			original_camera_fov = camera.fov
			Globals.camera_locked = true
			skin.set_move_state("Idle")
			set_physics_process(false)
			await skin.face_position(interactable.get_node("Marker3D").global_transform.origin)
			interactable.talk()
			get_tree().paused = true
			await ui.close_dialogue
			get_tree().paused = false
		else:
			interacting = false
		
	
func handle_shop_input():
	if Input.is_action_just_pressed("ui_cancel"):
		interacting = false
		exit_shop()
	if Input.is_action_just_pressed("ui_left"):
		$Click.play()
		shop.move_selection(Vector2i(-1, 0))
	elif Input.is_action_just_pressed("ui_right"):
		$Click.play()
		shop.move_selection(Vector2i(1, 0))
	elif Input.is_action_just_pressed("ui_up"):
		$Click.play()
		shop.move_selection(Vector2i(0, -1))
	elif Input.is_action_just_pressed("ui_down"):
		$Click.play()
		shop.move_selection(Vector2i(0, 1))

	if Input.is_action_just_pressed("accept"):
		var item = shop.get_selected_item()
		if item and not item.bought and Globals.rupee_value >= item.price:
			item.buy()
			$Buy.play()
			ui.update_rupees(-item.price)
			if item.item_name == "wand":
				ui.show_mana()
				Globals.spells = true
				Globals.fireball = true
			elif item.item_name == "heal":
				Globals.heal_spell = true
			elif item.item_name == "ice":
				Globals.iceball = true
			elif item.item_name == "mana":
				Globals.max_mana = 200
				mana = Globals.max_mana
				ui.upgrade_mana()
			elif item.item_name == "stamina":
				Globals.max_stamina = 200
				stamina = Globals.max_stamina
				ui.upgrade_stamina()
			elif item.item_name == "map":
				Globals.treasure_map = true
		# Add item to inventory
		else:
			$Error.play()
			pass
func exit_shop():
	default_music.play()
	_fade_music(shop_music, -80)
	_fade_music(default_music, default_volume)
	set_physics_process(false)
	shop.reset_item_pos()
	await return_to_normal_camera()
	Globals.camera_locked = false
	set_physics_process(true)
	shop_active = false
			
			
func cinematic_camera_sequence(type:= "chest") -> void:
	if type == "shop":
		var tween = create_tween().set_parallel()
		tween.tween_property(camera, "global_transform", shop_camera.global_transform, 1.0)
		tween.tween_property(camera, "fov", 75, 0.8)
		await tween.finished
		
	elif type == "chest":
		var tween = create_tween().set_parallel()
		tween.tween_property(camera, "global_transform", chest_camera.global_transform, 1.0)
		tween.tween_property(camera, "fov", 70, 0.8)
		await tween.finished

func return_to_normal_camera():
	var tween = create_tween().set_parallel()
	tween.tween_property(camera, "global_transform", original_camera_transform, 1.0)
	tween.tween_property(camera, "fov", original_camera_fov, 0.8)
	await tween.finished
	camera.make_current() # Restore main camera
	set_physics_process(true)

func stop_movement(start_duration: float, end_duration: float) -> void:
	print("Stop moving called")
	var tween = create_tween()
	tween.tween_property(self, "speed_modifier", 0.0, start_duration)
	tween.tween_property(self, "speed_modifier", 1.0, end_duration)

func get_unlocked_spells():
	var unlocked := []
	if Globals.fireball:
		unlocked.append(spells.FIREBALL)
	if Globals.iceball:
		unlocked.append(spells.ICEBALL)
	if Globals.heal_spell:
		unlocked.append(spells.HEAL)
	return unlocked

func projectile_hit(_hit_position: Vector3) -> void:
	hit()

func fireball_hit() -> void:
	burn = true
	if frozen:
		frozen = false
		skin.clear_frozen()
	hit()
	start_burn_flash()
	var i = 0
	while i < 2 and not Globals.player_dead:
		await get_tree().create_timer(2.5).timeout
		hit()
		i += 1
	burn = false

func start_burn_flash() -> void:
	spawn_flash_loop()

func spawn_flash_loop() -> void:
	if flash_loop_running:
		return # already flashing
	flash_loop_running = true
	call_deferred("_flash_loop")

func _flash_loop() -> void:
	while burn:
		skin.flash_red()
		await get_tree().create_timer(0.8).timeout # flash every 0.8 seconds
	flash_loop_running = false
	
func iceball_hit() -> void:
	if frozen: return
	if burn:
		burn = false
	frozen = true
	hit()
	skin.set_move_state("Dodge_Forward")
	skin.frozen()
	$Timers/FreezeTimer.start()
	
	

func take_damage(_amount: int, knockback: Vector3):
	if is_invulnerable: return

	is_invulnerable = true

	# Apply knockback
	apply_knockback(knockback)
	move_and_slide()
	hit()
	
	# Invulnerability frames
	await get_tree().create_timer(0.5).timeout
	is_invulnerable = false

func hit() -> void:
	print("hit")
	if not invulnerable:
		invulnerable = true
		on_squish_and_stretch(0.9,0.2)
		skin.attacking = false
		skin.attack_stage = 0
		if not frozen:
			skin.hit()
		stop_movement(0.3, 0.4)
		$Timers/InvulTimer.start()
		health -= 1
		if health > 0:
			$Hurt.pitch_scale = randf_range(0.9,1.1)
			if randi_range(0,1) == 1:
				$Hurt.stream = load("res://audio/577968__birdofthenorth__female-hurt.wav")
			else:
				$Hurt.stream = load("res://audio/577969__birdofthenorth__female-hurt-2.wav")
		else:
			$Hurt.stream = load("res://audio/hit2.wav")
		$Hurt.play()
				

func on_squish_and_stretch(value: float, duration: float = 0.1):
	var tween = create_tween()
	tween.tween_property(skin, "squish_and_stretch", value, duration)
	tween.tween_property(skin, "squish_and_stretch", 1.0, duration * 0.6).set_ease(Tween.EASE_OUT)


func _on_invul_timer_timeout() -> void:
	invulnerable = false
	
func shoot_magic(pos: Vector3) -> void:
	if current_spell == spells.FIREBALL and mana >= 10:
		mana -= 10
		if current_target:
			var to_enemy = (current_target.global_position - global_position).normalized()
			spell_cast.emit('fireball', pos, to_enemy, 1.0, $".")
		else:
			var facing_direction = skin.global_transform.basis.z.normalized()
			var dir_3d = Vector3(facing_direction.x,0,facing_direction.z)
			spell_cast.emit('fireball', pos, dir_3d, 1.0, $".")
	if current_spell == spells.ICEBALL and mana >= 10:
		mana -= 10
		if current_target:
			var to_enemy = (current_target.global_position - global_position).normalized()
			spell_cast.emit('iceball', pos, to_enemy, 1.0, $".")
		else:
			var facing_direction = skin.global_transform.basis.z.normalized()
			var dir_3d = Vector3(facing_direction.x,0,facing_direction.z)
			spell_cast.emit('iceball', pos, dir_3d, 1.0, $".")
	if current_spell == spells.HEAL and mana >= 20:
		mana -= 20
		health += 1

func enter_aim_mode() -> void:
	if is_aiming:
		return
	skin.set_defend_state("Aiming")
	skin.set_move_state("Idle")
	if arrow_count > 0:
		crossbow_anim.play("StylizedCrossbowRig|Firing")
		crossbow_anim.stop()
	else:
		crossbow_anim.play("StylizedCrossbowRig|Reloading")
		crossbow_reload.play()
		await get_tree().create_timer(1.0).timeout
		crossbow_reload.play()
		await get_tree().create_timer(1.0).timeout
		crossbow_reload_2.play()
		crossbow_anim.stop()
	is_aiming = true
	original_camera_fov = camera.fov
	original_camera_transform = camera.global_transform
	original_spring_length = spring_arm.spring_length
	original_spring_position = spring_arm.position

	var tween = create_tween().set_parallel(true)
	tween.tween_property(camera, "global_transform", crossbow_camera_pos.global_transform, 0.3)
	#tween.tween_property(spring_arm, "rotation", target_rotation, 0.3)
	#tween.tween_property(spring_arm, "spring_length", 0, 0.3)
	#tween.tween_property(spring_arm, "position", target_position, 0.3)
	#tween.tween_property(camera, "fov", 70, 0.3)
	
	head_crossbow.show()
	crossbow.hide()
	await tween.finished
	crosshair.show()
	head.hide()
	crossbow_camera_pos.make_current()
	spring_arm.set_collision_mask(0)	
	# Adjust player controls/speed while aiming
	speed_modifier = aim_speed / base_speed

func exit_aim_mode() -> void:
	if not is_aiming: return
	is_aiming = false
	can_shoot = true
	head.show()
	spring_arm.set_collision_mask(1)
	await get_tree().process_frame
	camera.global_transform = original_camera_transform
	camera.make_current()
	crosshair.hide()
	head_crossbow.hide()
	crossbow.show()
	
	# Reset movement speed
	speed_modifier = 1.0
	skin.defend(false)

func fire_arrow() -> void:
	can_shoot = false
	# Play animation/sound
	skin.set_defend_state("Shoot")
	crossbow_anim.play("StylizedCrossbowRig|Firing")
	crossbow_fire.play()
	
	# Instantiate arrow
	await get_tree().create_timer(0.24).timeout
	var arrow = arrow_scene.instantiate()
	get_tree().current_scene.add_child(arrow)

	# Position arrow at crossbow tip
	var spawn_point = $GodetteSkin/Yaw/Pitch/Crossbow2/ArrowSpawn
	arrow.global_transform = spawn_point.global_transform

	# Set velocity based on camera direction
	var direction = fp_pitch.global_transform.basis.z.normalized()
	print("Arrow direction: ", direction)
	arrow.launch(direction, 30.0) # 30.0 is arrow speed

	# Add to arrows array and manage array size
	arrows.append(arrow)
	_cleanup_old_arrows()
	
	arrow_count -= 1
	
	# Emit signal
	await get_tree().create_timer(0.3).timeout
	skin.set_defend_state("Reload")
	if arrow_count > 0:
		crossbow_anim.play("StylizedCrossbowRig|Reloading")
		if not can_shoot:
			crossbow_reload.play()
			await get_tree().create_timer(1.0).timeout
			crossbow_reload.play()
			await get_tree().create_timer(1.0).timeout
			crossbow_reload_2.play()
		await get_tree().create_timer(1.7).timeout
	can_shoot = true

func _cleanup_old_arrows() -> void:
	# First remove any freed arrows from the array
	arrows = arrows.filter(func(a): return is_instance_valid(a))

	# Then free excess arrows if needed
	while arrows.size() > max_arrows:
		var oldest_arrow = arrows.pop_front()
		if is_instance_valid(oldest_arrow):
			oldest_arrow.queue_free()

func _on_crossbow_arrow_cleanup(arrow) -> void:
	# Safely remove from array
	var idx = arrows.find(arrow)
	if idx != -1:
		arrows.remove_at(idx)

func update_aim_camera_position() -> void:
	if not is_aiming:
		return
		
	# Instead of using the skin rotation directly, use the raw player rotation
	# This prevents feedback loops from occurring
	var player_forward = -global_transform.basis.z
	player_forward.y = 0
	player_forward = player_forward.normalized()

	# Calculate aim position using the crossbow position as reference
	var aim_position = crossbow_camera_pos.global_position

	# Apply smoothing to prevent jarring movements
	var smoothing_factor = 0.2  # Lower = smoother but slower
	spring_arm.global_position = spring_arm.global_position.lerp(aim_position, smoothing_factor)

	# Keep rotation simplified - don't directly set it equal to player rotation
	# Instead calculate it from the camera-to-player vector
	var look_dir = (global_position - spring_arm.global_position).normalized()
	look_dir.y = 0  # Keep camera level horizontally

	if look_dir.length() > 0.01:
		# Create a smooth rotation for the camera
		var current_rot = spring_arm.global_transform.basis.get_rotation_quaternion()
		var target_rot = Quaternion(Basis.looking_at(look_dir, Vector3.UP))
		spring_arm.global_transform.basis = Basis(current_rot.slerp(target_rot, smoothing_factor))

		# Apply a consistent aiming pitch
		spring_arm.rotation.x = lerp(spring_arm.rotation.x, -0.1, smoothing_factor)

func _on_stamina_timer_timeout() -> void:
	if not exertion:
		stamina += 1

func validate_current_target():
	if current_target and current_target != null:
		var is_dead = current_target.has_method("check_if_dead") && current_target.check_if_dead()
		var in_range = global_position.distance_to(current_target.global_position) <= target_range
		
		if !is_dead && in_range:
			return  # Target is still valid
		# Target is invalid, find new one immediately
		find_closest_target(true)

func find_closest_target(find_new: bool = false):
	var was_targeting = is_targeting

	# Check current target validity
	if current_target and not find_new:
		var target_valid = is_instance_valid(current_target)
		var is_dead = target_valid and current_target.has_method("check_if_dead") and current_target.check_if_dead()
		var out_of_range = target_valid and global_position.distance_to(current_target.global_position) > target_range

		if not target_valid or is_dead or out_of_range:
			if target_valid and current_target.has_node("Arrow"):
				current_target.get_node("Arrow").hide()
			current_target = null
			is_targeting = false
			Globals.entity_nearby = false

	var targets = get_tree().get_nodes_in_group("Entity").filter(func(t): return is_instance_valid(t))
	var closest_dist = target_range
	var closest_target = null

	# Hide all valid target indicators
	for target in targets:
		if is_instance_valid(target) and target.has_node("Arrow"):
			target.get_node("Arrow").hide()

	# Find closest valid target
	for target in targets:
		if not is_instance_valid(target):
			continue
		if target == current_target: 
			continue
		if target.has_method("check_if_dead") and target.check_if_dead():
			continue
		
		var dist = global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_target = target

	# Update target and indicators with safety checks
	if is_instance_valid(closest_target):
		Globals.entity_nearby = true
		if closest_target.has_node("Arrow"):
			var arrow = closest_target.get_node("Arrow")
			arrow.show()
			var anim = arrow.get_node("AnimatedSprite3D")
			if anim:
				anim.play("indicator")
	else:
		Globals.entity_nearby = false
		
	if find_new:
		current_target = closest_target
		if is_instance_valid(current_target):
			if not current_target.is_in_group("Oldman"):
				# Safe signal connection
				if current_target.is_dead.is_connected(_on_target_died):
					current_target.is_dead.disconnect(_on_target_died)
				current_target.is_dead.connect(_on_target_died)
			print("target")
			is_targeting = true
			if current_target.has_node("Arrow"):
				var arrow = current_target.get_node("Arrow")
				var anim = arrow.get_node("AnimatedSprite3D")
				if anim:
					anim.play("attack")
					$Target.play()
		else:
			is_targeting = false
	elif is_instance_valid(current_target) and !is_targeting:
		current_target = null

	# Cleanup invalid targets
	if was_targeting and !is_targeting and Input.is_action_pressed("lock_on"):
		find_closest_target(true)

func _on_target_died(_entity = null):
	if current_target and is_instance_valid(current_target):
		if current_target.has_node("Arrow"):
			var arrow = current_target.get_node("Arrow")
			if arrow:
				print("TARGET DIED")
				arrow.hide()
		# Even if already invalid, make sure to clear the reference
		current_target = null

	is_targeting = false
	Globals.entity_nearby = false

	# Try to find a new target if we're still in aim/lock mode
	if Input.is_action_pressed("lock_on"):
		find_closest_target(true)

func show_cinematic_bars(raise: bool) -> void:
	var viewport = get_viewport()
	await get_tree().process_frame
	
	var tween = create_tween()
	tween.set_parallel(true)

	# Wait one frame for viewport to update
	var viewport_size = viewport.get_visible_rect().size
	
	if raise:
		tween.tween_property(top_bar, "position:y", 0, 0.5).set_trans(Tween.TRANS_SINE)
		var target_bottom_y = viewport_size.y - bottom_bar.size.y
		tween.tween_property(bottom_bar, "position:y", target_bottom_y, 0.5).set_trans(Tween.TRANS_SINE)
	else:
		tween.tween_property(top_bar, "position:y", -top_bar.size.y, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(bottom_bar, "position:y", viewport_size.y, 0.5).set_trans(Tween.TRANS_SINE)

func fall_into_pit(pit_position: Vector3):
	if is_falling: return
	is_falling = true

	# Disable controls and physics
	set_process_input(false)
	set_process_unhandled_input(false)
	set_physics_process(false)
	velocity = Vector3.ZERO
	
	Input.flush_buffered_events()

	# Start death sequence
	start_pit_sequence(pit_position)

func start_pit_sequence(_pit_position: Vector3):
	# Detach camera while preserving its global position
	var original_parent = camera.get_parent()
	camera.reparent(get_tree().current_scene, true) # true = keep global transform
	
	# Store reference to original camera position and rotation for later restoration
	var original_camera_local_pos = Vector3.ZERO
	var original_camera_local_rot = Vector3.ZERO
	
	$Fall.play()
	
	# Tween camera to look down
	var tween = create_tween().set_parallel()
	tween.tween_property(camera, "position", 
		camera.position + Vector3(0, 5, 0), 1.0)
	tween.tween_property(camera, "rotation_degrees",
		Vector3(-75, -180, 0), 1.0)
	await tween.finished
	
	# Fade to black
	$UI/FadeAnimation.play("fade_out")
	await $UI/FadeAnimation.animation_finished
	
	# Reset player
	global_position = last_safe_position
	velocity = Vector3.ZERO
	skin.rotation = Vector3.ZERO

	camera.global_position = last_safe_position + Vector3(0, 1.5, 2) # Position above and behind player
	camera.rotation_degrees = Vector3(0, 0, 0) # Reset rotation completely
	
	# Now reparent back to original parent
	camera.reparent(original_parent)
	camera.position = original_camera_local_pos
	camera.rotation_degrees = original_camera_local_rot
	camera.get_parent().get_parent().pivot_camera()
	skin.set_move_state("Idle")
	skin.set_move_state("Death")
	# Fade back inw
	$UI/FadeAnimation.play_backwards("fade_out")
	await $UI/FadeAnimation.animation_finished
	await get_tree().create_timer(2.0).timeout
	
	var was_processing = is_processing()
	set_physics_process(false)  
	
	await skin.get_up()
		
	var idle_tween = create_tween()
	idle_tween.tween_callback(func(): skin.set_move_state("Idle"))
	await idle_tween.finished
	health -= 1
	# Re-enable processing
	set_process(was_processing)
	# Re-enable controls
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	is_falling = false

func _on_godette_skin_blocked(body: Node3D) -> void:
	print("blocked called")
	if body.is_in_group("Weapon"):
		print(body)
		if skin.defend_state_machine.get_current_node() == "Blocking":
			print(skin)
			stop_movement(0.3,0.4)
			skin.set_defend_state("Block_Hit")
			$Timers/BlockTimer.start()
		
func set_held_item(item):
	# Remove previous held item
	if is_instance_valid(held_item):
		held_item.queue_free()
	
	held_item = item
	item.hold_above_player() 

func _on_block_timer_timeout() -> void:
	if defend:
		skin.set_defend_state("Blocking")

func apply_knockback(force: Vector3):
	is_knockback = true
	knockback_velocity = force
	await get_tree().create_timer(knockback_duration).timeout
	is_knockback = false

func _on_chest_6_opened(_item: Variant) -> void:
	weapon_mode = WeaponMode.SWORD
	Globals.sword = true

func _on_chest_3_opened(_item: Variant) -> void:
	shield.show()
	Globals.shield = true

func _on_dungeonchest_opened(_item: Variant) -> void:
	ui.update_rupees(50)

func _on_chest_2_opened(_item: Variant) -> void:
	ui.update_rupees(20)

func _on_dungeonchest_2_opened(_item: Variant) -> void:
	Globals.max_health += 1
	health = Globals.max_health

func _on_dungeonchest_3_opened(_item: Variant) -> void:
	Globals.keys += 1
	ui.update_keys()

func _on_dungeonchest_4_opened(_item: Variant) -> void:
	Globals.max_health += 1
	health = Globals.max_health

func _on_dungeonchest_5_opened(_item: Variant) -> void:
	Globals.bigkey = true
	
func _on_dungeonchest_6_opened(_item: Variant) -> void:
	Globals.dungeon_map = true
	$MapRoot.show()

func _on_dungeonchest_7_opened(_item: Variant) -> void:
	Globals.compass = true

func _on_ui_chest_done() -> void:
	interacting = false
	set_physics_process(false)
	await skin.reset_rotation()
	await return_to_normal_camera()
	set_physics_process(true)
	Globals.camera_locked = false
	if big_chest:
		ui.save_game()
		big_chest = false
	
	

func _on_ui_close_dialogue() -> void:
	interacting = false
	set_physics_process(true)
	Globals.camera_locked = false

func _on_big_chest_opened(_item: Variant) -> void:
	Globals.crossbow = true
	await get_tree().create_timer(2.5).timeout
	var entities = %Room4.get_children()
	for entity in entities:
		if entity.is_in_group("Predead"):
			entity.remove_from_group("Predead")
			entity.revive()

func pause_game():
	skin.set_move_state("Idle")
	set_physics_process(false)
	set_process_input(false)
	get_tree().paused = true
	ui.pause()

func resume_game():
	set_physics_process(true)
	set_process_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ui.set_mouse()
	get_tree().paused = false
	pause_menu.visible = false

func open_map():
	fade.modulate.a = 0.0
	fade.visible = true
	$MapOpen.play()
	# Fade in to black over 0.5 seconds
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tween.finished

	# Pause the game except UI
	get_tree().paused = true
	set_physics_process(false)
	
	panel.size_flags_horizontal = Control.SIZE_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	original_map_cam_pos = minimap.global_position
	# Enable camera controls
	minimap.map_mode = true
	map_ui.show()
	if not Globals.controller:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var tween2 = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, 0.5)
	await tween2.finished

func close_map():
	$MapClose.play()
	# Fade to black before returning
	
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await tween.finished
	map_ui.hide()
	minimap.map_mode = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Reset camera position
	minimap.global_position = original_map_cam_pos
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	get_tree().paused = false
	set_physics_process(true)

	# Fade out from black
	var tween2 = create_tween()
	tween2.tween_property(fade, "modulate:a", 0.0, 0.5)
	await tween2.finished
	fade.visible = false

func _on_freeze_timer_timeout() -> void:
	frozen = false
	skin.clear_frozen()

func unstuck():
	var unstuck_direction = -global_transform.basis.z.normalized() # Move backward
	var test_position = global_position + unstuck_direction * 2.0

	var space_state = get_world_3d().direct_space_state
	var ray_params := PhysicsRayQueryParameters3D.new()
	ray_params.from = global_position
	ray_params.to = test_position
	ray_params.exclude = [self]

	var result = space_state.intersect_ray(ray_params)

	if result:
		print("Blocked behind, trying up")
		# Try moving up if backward is blocked
		global_position += Vector3.UP * 2.0
	else:
		global_position = test_position

	print("Unstuck triggered")

func _fade_music(player: AudioStreamPlayer, target_db: float):
	if music_tweens.has(player) and music_tweens[player].is_valid():
		music_tweens[player].kill()
	var tween := create_tween()
	music_tweens[player] = tween

	tween.tween_property(player, "volume_db", target_db, 2.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if target_db <= -80.0:
		tween.tween_callback(Callable(player, "stop"))

func enter_combat():
	print("Enter combat")
	if in_combat or game_over:
		return
	in_combat = true
	combat_music.play()
	_fade_music(default_music, -80.0)
	_fade_music(combat_music, 0.0)
	$Timers/CombatTimer.start()
	
func exit_combat():
	print("Exit combat")
	if not in_combat:
		return
	in_combat = false
	$Timers/CombatTimer.stop()
	if not Globals.player_dead:
		default_music.play()
		_fade_music(combat_music, -80.0)
		_fade_music(default_music, default_volume)

func on_enemy_detected():
	print("detected")
	enemies_nearby += 1
	if enemies_nearby == 1:
		enter_combat()

func on_enemy_left():
	enemies_nearby -= 1
	if enemies_nearby <= 0:
		enemies_nearby = 0
		exit_combat()

func _wake_up():
	skin.set_move_state("Lie_StandUp")

func _fade():
	$UI/FadeAnimation.play("fade_out")
	await $UI/FadeAnimation.animation_finished
	await get_tree().create_timer(2.0).timeout
	$UI/FadeAnimation.play_backwards("fade_out")
	await $UI/FadeAnimation.animation_finished

func cutscene():
	Globals.cinematic = true
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	skin.set_move_state("Idle")
	await get_tree().create_timer(1.0).timeout
	Globals.camera_locked = true
	$CutsceneCamera/Camera.make_current()

func reset_camera():
	Globals.camera_locked = false
	Globals.cinematic = false
	camera.make_current() # Restore main camera
	set_physics_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)

func add_map():
	Globals.map = true
	$MapRoot.show()

func enter_grass():
	in_grass = true
	
func left_grass():
	in_grass = false
	
func sit():
	skin.set_move_state("Sit_Chair_Idle")
	
func idle():
	skin.set_move_state("Idle")
	
func play_music():
	default_music.play()

func save():
	ui.save_game()

func cheer():
	skin.set_move_state("Cheer")

func hide_map():
	$MapRoot.hide()

func show_map():
	if (get_tree().current_scene.name == "Dungeon" and Globals.dungeon_map == true) or (get_tree().current_scene.name == "Overworld" and Globals.map == true):
		$MapRoot.show()

func play_boss_music():
	_fade_music(default_music, -80.0)
	if not boss_music.playing:
		boss_music.play()
	_fade_music(boss_music, -2.0)
	
func stop_boss_music():
	_fade_music(boss_music, -80.0)
	_fade_music(boss_music_loop, -80.0)
	if boss_music.playing:
		boss_music.stop()
	if boss_music_loop.playing:
		boss_music_loop.stop()

func _on_boss_battle_finished() -> void:
	boss_music_loop.play()

func show_keys():
	var keys = ui.get_node("Keys")
	keys.show()

func puzzle_solved():
	$PuzzleSolve.play()

func hide_arrow():
	$GodetteSkin/DungeonArrow.hide()
	$GodetteSkin/OverworldArrow.hide()

func _on_combat_timer_timeout() -> void:
	for entity in get_tree().get_nodes_in_group("Entity"):
		if entity.has_method("is_engaged") and entity.is_engaged():
			return  # Still in combat
	print("timer exit")
	exit_combat()
