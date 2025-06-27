extends Node3D

var gates : Array = []
var arrows : Array = []
var trigger := true
var boss_fight := false
@onready var boss := $Boss
@onready var player := get_tree().get_first_node_in_group("Player")
@onready var arrow_scene := preload("res://scenes/items/arrows.tscn")


func _ready() -> void:
	for child in get_children():
		if child.name.begins_with("Gate"):
			gates.append(child)
		if child.name.begins_with("Marker3D"):
			arrows.append(child)

func _process(_delta) -> void:
	if player.arrow_count == 0 and trigger and boss_fight:
		trigger = false
		$Timer.start()
		
		var drop_position = global_transform.origin
		var arrow = arrow_scene.instantiate()
	
		add_child(arrow)
		arrow.global_transform.origin = drop_position
		
		

func _on_gate_timer_timeout() -> void:
	if gates.is_empty() or not boss_fight:
		return
	
	var random_gate = gates.pick_random()
	if random_gate.has_method("boss_room_trigger"):
		random_gate.boss_room_trigger()
	if boss.shield:
		$GateTimer.start()
	else:
		$GateTimer.stop()


func _on_boss_start_timer() -> void:
	$GateTimer.start()


func _on_timer_timeout() -> void:
	trigger = true


func _on_boss_is_dead() -> void:
	$GateTimer.stop()
	boss_fight = false


func _on_dungeon_trigger_4() -> void:
	boss_fight = true
