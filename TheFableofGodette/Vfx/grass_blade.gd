extends Node3D

@onready var player = get_tree().get_first_node_in_group("Player")
var skin : Node3D
var sword : Node3D
var marker : Marker3D
var particles : GPUParticles3D
var grass : Node3D
var cooldown := false
var in_range := false
signal in_grass
signal out_grass

func _ready() -> void:
	skin = player.get_node("GodetteSkin")
	sword = skin.get_node("Rig/Skeleton3D/RightHandSlot/Sword")
	marker = sword.get_node("Marker3D")
	particles = sword.get_node("Particles/Grass")
	grass = sword.get_node("Grass")
	
func _process(_delta: float) -> void:
	if in_range and skin.damage and not cooldown:
		cooldown = true
		particles.emitting = true
		grass.play()
		
		if randi_range(0,3) == 1:
			drop_item()
		$Timer.start()



func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group("PWeapon"):
		in_range = true
		emit_signal("in_grass")
	

func drop_item():
	var item_scenes = []
	if Globals.crossbow and Globals.spells:
		item_scenes = [
		preload("res://scenes/items/green_rupee.tscn"),
		preload("res://scenes/items/mana_bottle.tscn"),
		preload("res://scenes/items/heart.tscn"),
		preload("res://scenes/items/arrows.tscn"),
		preload("res://scenes/items/blue_rupee.tscn")
	]
	elif Globals.crossbow:
		item_scenes = [
		preload("res://scenes/items/green_rupee.tscn"),
		preload("res://scenes/items/heart.tscn"),
		preload("res://scenes/items/arrows.tscn"),
		preload("res://scenes/items/blue_rupee.tscn")
	]
	elif Globals.spells:
		item_scenes = [
		preload("res://scenes/items/green_rupee.tscn"),
		preload("res://scenes/items/mana_bottle.tscn"),
		preload("res://scenes/items/heart.tscn"),
		preload("res://scenes/items/blue_rupee.tscn")
	]
	else:
		item_scenes = [
		preload("res://scenes/items/green_rupee.tscn"),
		preload("res://scenes/items/heart.tscn"),
		preload("res://scenes/items/blue_rupee.tscn")
	]
	
	var drop_position = marker.global_transform.origin

	var item_scene = item_scenes[randi() % item_scenes.size()]
	var item = item_scene.instantiate()
	
	get_parent().add_child(item)
	item.global_transform.origin = drop_position
	
	# Special handling for hearts
	if item.item_type == "heart":
		item.mass = 0.3  # Make hearts lighter
		item.apply_impulse(Vector3(
			randf_range(-0.5, 0.5),  # Less horizontal spread
			randf_range(4, 6),     # Higher upward force
			randf_range(-0.5, 0.5)
		))
		item.apply_torque_impulse(Vector3(
			randf_range(-0.2, 0.2),  # Gentle rotation
			randf_range(-0.1, 0.1),
			randf_range(-0.2, 0.2)
		))
	else:
		item.mass = 0.6
		item.apply_impulse(Vector3(
			randf_range(-2.0, 2.0),
			randf_range(6, 8),
			randf_range(-2.0, 2.0)
		))
		item.apply_torque_impulse(Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 0.5),
			randf_range(-1, 1)
		))


func _on_area_3d_area_exited(area: Area3D) -> void:
	if area.is_in_group("PWeapon"):
		in_range = false
		emit_signal("out_grass")


func _on_timer_timeout() -> void:
	particles.emitting = false
	cooldown = false
