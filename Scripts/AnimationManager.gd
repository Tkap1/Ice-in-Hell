extends Node
class_name AnimationManager


var animation_players = []
var parent

func _init(_parent):
	parent = _parent

	
func play(animation_name : String, animation : Animation):
	
	# Find an inactive animation player and make it play the requested animation
	for animation_player in animation_players:
		if not animation_player.is_playing():
			if not animation_player.has_animation(animation_name):
				animation_player.add_animation(animation_name, animation)
			animation_player.play(animation_name)
			return
			
	# If there are no inactive animation players, create one
	var animation_player = AnimationPlayer.new()
	parent.add_child(animation_player)
	animation_player.add_animation(animation_name, animation)
	animation_player.play(animation_name)
	animation_players.append(animation_player)
	
	
func stop(animation_name : String, reset := false):
	
	# Find the player that is playing the requested animation and stop it
	for animation_player in animation_players:
		if animation_player.is_playing():
			if animation_player.current_animation == animation_name:
				animation_player.stop(reset)
				