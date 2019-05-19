extends Control

signal start_game

onready var start_button = find_node("StartButton")

func _ready():
	
	start_button.connect("pressed", self, "on_start_pressed")


func on_start_pressed():
	
	emit_signal("start_game")