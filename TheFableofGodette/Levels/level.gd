extends Node3D

class_name level

const FPS_THRESHOLD = 30.0
const FPS_STABLE_TIME = 1.0 

var fps_timer := 0.0
var fps_stable := false
var removed := false

var fireball_scene: PackedScene = preload("res://scenes/vfx/fireball.tscn") 
var iceball_scene: PackedScene = preload("res://scenes/vfx/iceball.tscn")

var spell : Node
var village_safe := true
@export var test = false
const scenes = {
	'dungeon': "res://scenes/levels/dungeon.tscn",
	'overworld': "res://scenes/levels/overworld.tscn"
}
@onready var player = get_tree().get_first_node_in_group("Player")
@onready var oldman = get_tree().get_first_node_in_group("Oldman")
@onready var ui = get_tree().get_first_node_in_group("UI")
signal unlock
signal unlock_2

func _ready() -> void:
	player.connect("spell_cast", cast_spell)
	for entity in get_tree().get_nodes_in_group("Entity"):
		if entity.has_signal("spell_cast"):
			entity.connect("spell_cast", cast_spell)
		if entity.is_in_group("Predead"):
			entity.hp = 1
			entity.hit()
	if not test:
		$LoadingScreen.show()
		get_tree().paused = true
		player.set_physics_process(false)
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		if Globals.shop:
			oldman.global_transform.origin = $ShopPosition.global_transform.origin
			oldman.idle()
			for entity in $Entities/Group2.get_children():
				entity.queue_free()
		else:
			for entity in $Entities/Group2.get_children():
				entity.tree_exited.connect(_on_entity_exited)
		if Globals.orb_acquired:
			$CSGCylinder3D.queue_free()
			for entity in $Entities/Group1.get_children():
				entity.queue_free()
		else:
			for entity in $Entities/Group1.get_children():
				entity.tree_exited.connect(_on_entity_exited_2)
		if Globals.oldman:
			$CutsceneTrigger2.queue_free()
	else:
		Globals.sword = true
		Globals.shield = true

func _process(delta: float) -> void:
	if Engine.get_frames_per_second() >= FPS_THRESHOLD:
		fps_timer += delta
	else:
		fps_timer = 0.0
	
	fps_stable = fps_timer >= FPS_STABLE_TIME

func _on_scatter_finished():
	get_tree().paused = false
	await _wait_for_fps_stable()
	$LoadingScreen.queue_free()
	$NavigationRegion3D/Castle/StaticBody3D4.queue_free()
	Globals.scene_ready = true
	if Globals.new_game:
		Globals.cinematic = true
		ui.opening()
		$AnimationPlayer.play("wake_up")
	else:
		player.set_physics_process(true)
		player.set_process_input(true)
		player.set_process_unhandled_input(true)

func _wait_for_fps_stable() -> void:
	while not fps_stable:
		await get_tree().create_timer(0.25).timeout

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

func set_player_position(target_path: NodePath):
	var marker = get_node(target_path) as Marker3D
	player.reset_camera()
	player.global_transform = marker.global_transform

func _on_entity_exited():
	if $Entities/Group2.get_child_count() == 0:
		$Entities/Oldman.dialogue = ["Take a look at what I have in stock for you!", "Im sure these items will come in handy on your journey.", "All sales are final by the way!"]
		player._fade()
		player.cutscene()
		await get_tree().create_timer(2.0).timeout
		$AnimationPlayer.play("village")
		
func _on_entity_exited_2():
	if $Entities/Group1.get_child_count() == 0:
		emit_signal("unlock")

func _on_exit_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		SceneLoader.load_scene("res://scenes/levels/dungeon.tscn")


func _on_cutscene_trigger_2_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		Globals.oldman = true
		$Entities/Oldman.dialogue = ["The village is overrun with monsters. If you could clear them out I could assist you further.", "To the east lies the monsters hideout, I suspect they hold a key to the evil kings lair."]
		player._fade()
		player.cutscene()
		await get_tree().create_timer(2.0).timeout
		$AnimationPlayer.play("oldman")

func _on_cutscene_trigger_2_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		player.save()
		$CutsceneTrigger2.call_deferred("queue_free")


func _on_dungeon_chest_locked_opened(_item: Variant) -> void:
	await get_tree().create_timer(2.0).timeout
	Globals.cinematic = true
	player._fade()
	player.cutscene()
	await get_tree().create_timer(2.0).timeout
	$AnimationPlayer.play("barrier")
	$CSGCylinder3D.use_collision = false

func remove_barrier():
	var mat = $CSGCylinder3D.material
	if mat is ShaderMaterial:
		var tween = create_tween()
		tween.tween_method(
			func(val): mat.set_shader_parameter("alpha", val),
			mat.get_shader_parameter("alpha"),
			0.0,
			2.0
		)
	Globals.orb_acquired = true
	


func _on_skeleton_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior2.revive()
		$SkeletonTrigger.call_deferred("queue_free")

func _on_skeleton_trigger_2_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior.revive()
		$SkeletonTrigger2.call_deferred("queue_free")

func _on_skeleton_trigger_3_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior4.revive()
		$SkeletonTrigger3.call_deferred("queue_free")

func _on_skeleton_trigger_4_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior3.revive()
		$SkeletonTrigger4.call_deferred("queue_free")


func _on_skeleton_trigger_5_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior11.revive()
		$SkeletonTrigger5.call_deferred("queue_free")


func _on_skeleton_trigger_6_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		$Entities/Warrior12.revive()
		$SkeletonTrigger6.call_deferred("queue_free")

func new_game_flag() -> void:
	Globals.new_game = false
	
