extends Control


var main_menu
var game

func _ready():
	
	randomize()
	init_main_menu()
	
	
func init_main_menu():
	
	main_menu = load("res://Scenes/MainMenu.tscn").instance()
	add_child(main_menu)
	main_menu.connect("start_game", self, "start_game")
	
	
func start_game():
	
	main_menu.queue_free()
	
	game = load("res://Scripts/Game.gd").new()
	game.tilemap = $TileMap
	add_child(game)