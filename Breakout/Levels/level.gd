extends Node2D

class_name LevelParent

var respawn_point: Vector2
var laser_scene: PackedScene = preload("res://scenes/projectiles/laser.tscn")
var grenade_scene: PackedScene = preload("res://scenes/projectiles/grenade.tscn")
var item_scene: PackedScene = preload("res://scenes/items/item.tscn")

func _ready():
	for container in get_tree().get_nodes_in_group("Container"):
		container.connect("open", Callable(self, "_on_container_opened"))
		print("Connected signal 'open' for container: ", container.name)
		
func _on_container_opened(pos, direction):
	var item = item_scene.instantiate() as Area2D
	item.global_position = pos
	item.direction = direction
	$Items.call_deferred('add_child',item,true)
	
func _on_gate_player_left(body):
	print("player has left gate")
	print(body)
	
func _on_player_laser(pos, direction):
	var laser = laser_scene.instantiate() as Area2D
	laser.position = pos
	laser.direction = direction
	laser.rotation = direction.angle()
	#laser.look_at(get_global_mouse_position())
	$Projectiles.add_child(laser,true)
	$UI.update_color(Globals.laser_amount, $UI.laser_label, $UI.laser_icon)
	

func _on_player_grenade_toss(pos, direction):
	var grenade = grenade_scene.instantiate() as RigidBody2D
	grenade.position = pos
	grenade.linear_velocity = direction * grenade.speed
	$Projectiles.add_child(grenade,true)
	$UI.update_color(Globals.grenade_amount, $UI.grenade_label, $UI.grenade_icon)


func _on_item_collected(pos: Vector2):
	respawn_point = pos
	$Items/ItemTimer.start()

func _on_item_timer_timeout():
	var item = item_scene.instantiate() as Area2D
	item.global_position = respawn_point
	$Items.add_child(item,true)
	item.connect("collected", Callable(self, "_on_item_collected"))
	
