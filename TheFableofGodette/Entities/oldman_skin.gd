extends Node3D

@onready var player := get_tree().get_first_node_in_group("Player")
@onready var move_state_machine = $AnimationTree.get("parameters/StateMachine/playback")
@onready var emote_animation = $AnimationTree.get_tree_root().get_node('Animation')
@onready var head = $Rig/Skeleton3D/Godette_Head 
@onready var axe = $Rig/Skeleton3D/LeftHandSlot/axe_1handed2
var in_range := false
var original_axe_pos : Vector3
@export var turn_speed = 5.0

func _ready() -> void:
	$axe_1handed2.hide()
	axe.show()
	original_axe_pos = axe.global_transform.origin

func _process(delta) -> void:
	if in_range:
		var to_player = (player.global_position - head.global_position)
		
		var target_angle = atan2(to_player.x, to_player.z)
		var base_angle = global_transform.basis.get_euler().y
		var relative_angle = wrapf(target_angle - base_angle, -PI, PI)
		var clamped_angle = clamp(relative_angle, deg_to_rad(-45), deg_to_rad(45))

		head.rotation.y = lerp_angle(head.rotation.y, clamped_angle, delta * turn_speed)
	else:
		head.rotation.y = lerp_angle(head.rotation.y, 0.0, delta * turn_speed)

func set_move_state(state_name: String) -> void:
	move_state_machine.travel(state_name)

func set_emote():	
	var rng = randi_range(0,2)
	if randi_range(0,1) == 1:	
		emote_animation.animation = "Interact"
	else:
		emote_animation.animation = "Use_Item"
	if rng == 2:
		$Dialogue/mumble.play()
	elif rng == 1:
		$Dialogue/mumble2.play()
	else:
		$Dialogue/mumble3.play()
	$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	
func _shock_trans(value: float) -> void:
	$AnimationTree.set("parameters/Blend2/blend_amount", value)

func reset_axe():
	axe.show()

func hide_axe():
	axe.hide()
	$axe_1handed2.show()

func cheer():
	emote_animation.animation = "Cheer"
	$AnimationTree.set("parameters/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func shock():
	$Shock.play()
