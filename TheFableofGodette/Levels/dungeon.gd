extends Node3D

var slime_count := 0
var opened_2 = false
var big_key := false
var fireball_scene: PackedScene = preload("res://scenes/vfx/fireball.tscn") 
var iceball_scene: PackedScene = preload("res://scenes/vfx/iceball.tscn")
@onready var player := get_tree().get_first_node_in_group("Player")
var spell : Node
signal open_door_2
signal open_gate
signal open_gate2
signal open_gate3
signal trigger
signal trigger2
signal trigger3
signal trigger4
signal warp
signal unlit
signal unlock
@onready var barrier := $Room7/MapRoom/StaticBody3D3
var current_room : Node3D
@export var green_pillar : PackedScene
@onready var skully1 := $Room3/Path3D/PathFollow3D/Skully
@onready var skully2 := $Room3/Path3D/PathFollow3D2/Skully
var released = false
@onready var ui := get_tree().get_first_node_in_group("UI")
@onready var arrow_scene := preload("res://scenes/items/arrows.tscn")
var brazier_lit := 0 
var triggered1 := false
var triggered2 := false
var triggered3 := false
var triggered4 := false
var skeletons : bool
var skeletons2 : bool
var gate_open := false
var gate_open2 := false
var gate_open3 := false
var light_room : bool
var room_lit := false
var button_pressed := false
var flag := true
var stair_opened := false
const scenes = {
	'dungeon': "res://scenes/levels/dungeon.tscn",
	'overworld': "res://scenes/levels/overworld.tscn"
}

func _ready():
	ui.overlay.modulate = Color(1,1,1,1)
	await _wait_for_player()
	if not Globals.dungeon_map:
		$Entities/Player/MapRoot.hide()
	$Room1/Walkway/Group.global_position = Vector3(20.0,0.0,0.0)
	for entity in get_tree().get_nodes_in_group("Entity"):
		if entity.has_signal("spell_cast"):
			entity.connect("spell_cast", cast_spell)
		if entity.is_in_group("Predead"):
			entity.hp = 1
			entity.hit()
			
	player.connect("spell_cast", cast_spell)
	_replace_pillars(get_tree().get_current_scene())

	set_room_active($Room3, false)
	set_room_active($Room5, false)
	set_room_active($Room6, false)
	set_room_active($Room7, false)
	set_room_active($Room8, false)
	set_room_active($Room9, false)
	set_room_active($Room10, false)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	if Globals.bigkey:
		player.hide_map()
		current_room = $Room4
		set_room_active($Room4, true)
		set_room_active($Room1, false)
		set_room_active($Room2, true)
		$Room1/Slime.die()
		$Room1/Slime2.die()
		$Room6/CompassRoom/DoorTrigger.queue_free()
		$Room2/DoorTrigger2.queue_free()
		for entity in $Room6/SkeletonRoom.get_children():
			entity.queue_free()
		for entity in $Room3.get_children():
			if entity.is_in_group("Entity"):
				entity.queue_free()
		await get_tree().process_frame
		set_player_position("Room4/Checkpoint")
		ui.overlay.modulate = Color(1,1,1,0)
		player.show_map()
	elif Globals.crossbow:
		player.hide_map()
		current_room = $Room4
		set_room_active($Room4, true)
		set_room_active($Room1, false)
		set_room_active($Room2, true)
		$Room1/Slime.die()
		$Room1/Slime2.die()
		$Room6/CompassRoom/DoorTrigger.queue_free()
		for entity in $Room6/SkeletonRoom.get_children():
			entity.queue_free()
		await get_tree().process_frame
		set_player_position("Room4/Checkpoint")
		ui.overlay.modulate = Color(1,1,1,0)
		player.show_map()
	else:
		current_room = $Room1
		set_room_active($Room1, true)
		set_room_active($Room2, true)
		set_room_active($Room4, false)
		Globals.cinematic = true
		Globals.camera_locked = true
		await get_tree().process_frame
		ui.overlay.modulate = Color(1,1,1,0)
		$AnimationPlayer.play("enter")
		await $AnimationPlayer.animation_finished
		await get_tree().create_timer(2.0).timeout
		ui.save_game()

func _wait_for_player() -> void:
	while not has_node("Entities/Player"):
		await get_tree().process_frame

func find_nodes_on_layer(node: Node, layer: int):
	if node is PhysicsBody3D or node is Area3D:
		if node.collision_layer & (1 << (layer - 1)):
			print("- ", node.name, " (", node.get_path(), ")")
	
	for child in node.get_children():
		find_nodes_on_layer(child, layer)
		
func _process(_delta: float) -> void:
	big_key = true
	skeletons = true
	skeletons2 = true
	light_room = true
	if current_room == $Room4 and player.arrow_count == 0 and flag:
		flag = false
		$Room4/BowRoom/ArrowTimer.start()
		
		var drop_position = $Room4/BowRoom/Marker3D2.global_transform.origin
		var arrow = arrow_scene.instantiate()
		
		add_child(arrow)
		arrow.global_transform.origin = drop_position
		
	if slime_count == 2 and !opened_2:
		opened_2 = true
		emit_signal("open_door_2")
	for child in $Room3.get_children():
		if child.is_in_group("Entity"):
			big_key = false
			break
	for child in $Room6/SkeletonRoom.get_children():
		if child.is_in_group("Entity"):
			skeletons = false
			break
	for child in $Room8/BigDoorRoom/Braziers.get_children():
		if child.is_in_group("Unlit"):
			light_room = false
			break
	for child in $Room10/Group1.get_children():
		if child.is_in_group("Entity"):
			skeletons2 = false
			break
	if skeletons and not gate_open:
		gate_open = true
		emit_signal("open_gate")
	if skeletons2 and not gate_open2:
		gate_open2 = true
		emit_signal("open_gate2")
	if big_key and not released:
		release_skully()
	if light_room and not room_lit:
		room_lit = true
		$WorldEnvironment/Fog/FogVolume7.hide()
	if brazier_lit == 1 and $Timer.is_stopped():
		print("Timer start")
		$Timer.start()
	if brazier_lit == 2:
		emit_signal("unlock")

func release_skully() -> void:
	skully1.reparent($Room3/KeyRoom)
	skully2.reparent($Room3/KeyRoom)
	skully1.velocity = Vector3.FORWARD.rotated(Vector3.UP, randf_range(-0.4, 0.4)) * 5.0
	skully2.velocity = Vector3.FORWARD.rotated(Vector3.UP, randf_range(-0.4, 0.4)) * 5.0
	released = true

func _on_kill_barrier_body_entered(body: Node3D):
	if body.is_in_group("Player"):
		body.fall_into_pit(global_position)
	elif body.is_in_group("Entity"):
		body.die()
		

func _replace_pillars(root: Node):
	# Get every node in the "pillar" group
	for child in root.get_children():
		if child.name.begins_with("pillar"):
			var parent = child.get_parent()
			var old_index = parent.get_children().find(child)
			var xform  = child.transform
			
			var new_pillar = green_pillar.instantiate()
			parent.add_child(new_pillar)
			new_pillar.transform = xform
			parent.move_child(new_pillar, old_index)
			child.queue_free()
		else:
			_replace_pillars(child)

func _on_slime_is_dead() -> void:
	slime_count += 1


func _on_slime_2_is_dead() -> void:
	slime_count += 1


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Cannonball") and is_instance_valid(body):
		var dust = body.get_node("GPUParticles3D")
		dust.emitting = false
		body.get_node("Ball").hide()
		await get_tree().create_timer(0.35).timeout
		body.call_deferred("queue_free")


func _on_barrier_check_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and is_instance_valid(barrier) and barrier:
		barrier.queue_free()


func _on_door_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		var skin = body.get_node("GodetteSkin")
		skin.set_move_state("Idle")
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
		body.show_cinematic_bars(true)
		Globals.camera_locked = true
		if current_room == $Room5 and not triggered1:
			triggered1 = true
			emit_signal("trigger")
		elif current_room == $Room6 and not triggered2:
			triggered2 = true
			emit_signal("trigger2")
		elif current_room == $Room3 and not triggered3:
			triggered3 = true
			emit_signal("trigger3")
			$Room2/DoorTrigger2.collision_mask = 0
		elif current_room == $Room10 and not triggered4:
			triggered4 = true
			$Room10/DoorTrigger.collision_mask = 0
		await get_tree().create_timer(1.0).timeout
		body.set_physics_process(true)
		body.show_cinematic_bars(false)
		Globals.camera_locked = false
		if current_room == $Room5:
			$Room5/PitRoom/DoorTrigger.call_deferred("queue_free")
		if current_room == $Room3:
			$Room2/DoorTrigger2.call_deferred("queue_free")
		if current_room == $Room6:
			$Room6/CompassRoom/DoorTrigger.call_deferred("queue_free")
		if current_room == $Room10:
			boss_cutscene()
			$Room10/DoorTrigger.call_deferred("queue_free")
			
func set_room_active(room: Node, active: bool) -> void:
	for child in room.get_children():
		if child.is_in_group("Entity"):
			child.awake = active
		if child.has_method("_process"):
			child.set_process(active)
		if child.has_method("_physics_process"):
			child.set_physics_process(active)
		if child.is_in_group("Cannon"):
			if active:
				child.get_node("Timer").start()
			else:
				child.get_node("Timer").stop()
		set_room_active(child, active)


func _on_roomtrans_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if current_room != $Room2:
			if $WorldEnvironment/Fog/FogVolume3.is_visible:
				$WorldEnvironment/Fog/FogVolume3.hide()
				$Entities/Player/OmniLight3D.hide()
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room2
			set_room_active(current_room, true)
		


func _on_roomtrans_2_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if current_room == $Room2:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room1
			set_room_active(current_room, true)



func _on_roomtrans_3_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if current_room != $Room3:
			set_room_active(current_room, false)
			current_room = $Room3
			set_room_active(current_room, true)


func _on_roomtrans_4_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if current_room != $Room4:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room4
			set_room_active(current_room, true)


func _on_roomtrans_5_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room5:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room5
			set_room_active(current_room, true)
			$WorldEnvironment/Fog/FogVolume3.show()
			$Entities/Player/OmniLight3D.show()

func _on_roomtrans_6_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room6:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room6
			set_room_active(current_room, true)
			

func _on_roomtrans_7_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room7:
			if $WorldEnvironment/Fog/FogVolume3.is_visible:
				$Entities/Player/OmniLight3D.hide()
				$WorldEnvironment/Fog/FogVolume3.hide()
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room7
			set_room_active(current_room, true)

func _on_roomtrans_8_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room8:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room8
			set_room_active(current_room, true)

func _on_roomtrans_9_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room9:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room9
			set_room_active(current_room, true)
			
func _on_roomtrans_10_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if current_room != $Room10:
			set_room_active(current_room, false)
			await get_tree().process_frame
			current_room = $Room10
			set_room_active(current_room, true)

func _on_pressure_plate_button_pressed() -> void:
	var box = $Room3/KeyRoom/CSGBox3D
	var mat = box.material

	if mat is ShaderMaterial:
		var tween = create_tween()
		tween.tween_method(
			func(val): mat.set_shader_parameter("alpha", val),
			mat.get_shader_parameter("alpha"),
			0.0,
			1.0
		)
	box.use_collision = false


func cast_spell(type: String, pos: Vector3, direction: Vector3, size: float, caster: Node3D) -> void:
	if type == "fireball":
		print("Fireball")
		var fireball = fireball_scene.instantiate()
		$Projectiles.add_child(fireball)
		fireball.global_position = pos
		fireball.setup(direction, size, caster)
	elif type == "iceball":
		print("iceball")
		var iceball = iceball_scene.instantiate()
		$Projectiles.add_child(iceball)
		iceball.global_position = pos
		iceball.setup(direction, size, caster)
	if type == "resurrection":
		print("Resurrect")


func _on_taunt_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if is_instance_valid($Room3/Mage):
			var skin = $Room3/Mage.get_node("Skeleton_Mage_Skin")
			skin.set_move_state("Taunt")


func _on_taunt_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if is_instance_valid($Room3/Mage):
			var skin = $Room3/Mage.get_node("Skeleton_Mage_Skin")
			skin.set_move_state("Idle")


func _on_warp_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
		emit_signal("warp")
		$Warp.play()
		await get_tree().create_timer(2.5).timeout
		body.global_position = $Room4/WarpRoom/Marker3D.global_position
		body.set_physics_process(true)
		
		


func _on_warp_2_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO
		emit_signal("warp")
		$Warp.play()
		await get_tree().create_timer(2.5).timeout
		body.global_position = $Room4/BowRoom/Marker3D.global_position
		body.set_physics_process(true)


func _on_brazier_lit(body: Node3D) -> void:
	brazier_lit += 1



func _on_timer_timeout() -> void:
	if !brazier_lit == 2:
		brazier_lit = 0
		emit_signal("unlit")


func _on_trigger_2() -> void:
	await get_tree().create_timer(2.5).timeout
	for child in $Room6/SkeletonRoom.get_children():
		if child.has_method("revive"):
			child.remove_from_group("Predead")
			child.revive()
			await get_tree().create_timer(10.0).timeout


func _on_target_button_pressed() -> void:
	if not button_pressed:
		button_pressed = true
		player.exit_aim_mode()
		await get_tree().process_frame
		var skin = player.get_node("GodetteSkin")
		skin.set_move_state("Idle")
		player.set_physics_process(false)
		player.velocity = Vector3.ZERO
		player.show_cinematic_bars(true)
		Globals.camera_locked = true
		await get_tree().create_timer(0.5).timeout
		$Entities/Player/CameraController/Shake.start_shake(2.0, 0.01)
		$Rumble.play()
		await get_tree().create_timer(2.0).timeout
		$Rumble.stop()
		player.puzzle_solved()
		player.set_physics_process(true)
		player.show_cinematic_bars(false)
		Globals.camera_locked = false
		$Room1/Walkway/Group.global_position = Vector3.ZERO

func _on_exit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		SceneLoader.load_scene("res://scenes/levels/overworld.tscn")
		
func _reset_player():
	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)
	Globals.cinematic = false

func set_player_position(target_path: NodePath):
	var marker = get_node(target_path) as Marker3D
	player.reset_camera()
	player.global_transform = marker.global_transform

func boss_cutscene():
	player._fade()
	player.cutscene()
	await get_tree().create_timer(2.0).timeout
	$AnimationPlayer.play("boss")

func _on_boss_cutscene_finished():
	emit_signal("trigger4")


func _on_boss_is_dead() -> void:
	player.hide_arrow()
	player.stop_boss_music()
	player._fade()
	player.cutscene()
	await get_tree().create_timer(3.0).timeout
	$AnimationPlayer.play("credits")


func _on_brazier_3_lit(_body: Node3D) -> void:
	if not stair_opened:
		stair_opened = true
		$Rumble.play()
		var tween = create_tween()
		var target_position = $Room2/BallRoom/Stairwell/StaticBody3D.position + Vector3(0, 0, 6)
		tween.tween_property($Room2/BallRoom/Stairwell/StaticBody3D, "position", target_position, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await tween.finished
		$Rumble.stop()
		player.puzzle_solved()

func _on_arrow_timer_timeout() -> void:
	flag = true
