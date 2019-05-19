extends Control

signal keep_going
signal exit

onready var continue_button = find_node("ContinueButton")
onready var exit_button = find_node("ExitButton")


func _ready():
	
	continue_button.connect("pressed", self, "on_continue_pressed")
	exit_button.connect("pressed", self, "on_exit_pressed")
	
	
func on_continue_pressed():
	
	emit_signal("keep_going")

	
func on_exit_pressed():

	emit_signal("exit")