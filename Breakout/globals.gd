extends Node

signal stat_change

var max_health = 100
var max_grenade = 10
var max_laser = 50

var laser_amount = 25:
	set(value):
		laser_amount = value
		stat_change.emit()
		
var grenade_amount = 5:
	set(value):
		grenade_amount = value
		stat_change.emit()
		
var health = max_health:
	set(value):
		health = value
		stat_change.emit()
