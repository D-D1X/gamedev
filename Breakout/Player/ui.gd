extends CanvasLayer

# colors
var green: Color = Color("3eab61")
var red: Color = Color("ba1b2bc3")
# var yellow: Color = Color("daae00dc")

@onready var laser_label: Label = $LaserCounter/MarginContainer/VBoxContainer/Label
@onready var grenade_label: Label = $GrenadeCounter/MarginContainer/VBoxContainer/Label
@onready var laser_icon: TextureRect = $LaserCounter/MarginContainer/VBoxContainer/TextureRect
@onready var grenade_icon: TextureRect = $GrenadeCounter/MarginContainer/VBoxContainer/TextureRect
@onready var health_bar: TextureProgressBar = $HealthBar/TextureProgressBar

func _ready():
	Globals.connect("stat_change", update_stats)
	update_laser_text()
	update_grenade_text()
	update_health_text()
	update_color(Globals.laser_amount, laser_label, laser_icon)
	update_color(Globals.grenade_amount, grenade_label, grenade_icon)
	
func update_laser_text():
	laser_label.text = str(Globals.laser_amount)

func update_grenade_text():
	grenade_label.text = str(Globals.grenade_amount)
	
func update_health_text():
	health_bar.value = Globals.health
	
func update_stats():
	update_laser_text()
	update_grenade_text()
	update_health_text()
	
func update_color(amount: int, label: Label, icon: TextureRect) -> void:
	if amount == 0:
		label.modulate = red
		icon.modulate = red
	else:
		label.modulate = green
		icon.modulate = green
