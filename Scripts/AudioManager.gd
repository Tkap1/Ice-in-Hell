# Script for managing multiple sounds at once.
# It will find AudioStreamPlayers that are not being used and play the requested sound,
# if there are no unused AudioStreamPlayers, it will create one.
# Can pass audios as a Dictionary for convenience, like this:

# var hello_sound = {"file": preload("file_path"), "volume": 5.0, "pitch": 1.5}
# audio_manager.play_dict(hello_sound)

# Currently does not clean up AudioStreamPlayers that are not being used,
# but it is unlikely to cause memory issues unless a huge amount of sounds were played at the same time with no limit set.

extends Node
class_name AudioManager

var audio_players = []

# If greather than 0, it will limit the amount of sounds that can be playing at the same time
var max_audios := 0

# If true, the sounds will be paused when the tree is paused
var allow_pause := false


func _init(_allow_pause := allow_pause, _max_audios := max_audios):
	
	allow_pause = _allow_pause
	max_audios = max(0, _max_audios)
	
	
func _ready():
	
	if not allow_pause:
		pause_mode = PAUSE_MODE_PROCESS
		
		
func play(sound_file, volume := 0.0, pitch_scale := 1.0, delay := 0.0, start_position := 0.0) -> void:
	
	if delay > 0.0:
		var s_yield = Global.SafeYield.new(self)
		s_yield.wait_timer(delay)
		yield(s_yield, "done")
	
	# Find an audio player that is not playing and make it play the requested audio
	for audio_player in audio_players:
		if not audio_player.playing:
			audio_player.stream = sound_file
			audio_player.volume_db = volume
			audio_player.pitch_scale = pitch_scale
			audio_player.play(start_position)
			return
	
	# No unused audio players.
	# If there is a limit and we have reached it, select the oldest "AudioSteamPlayer",
	if max_audios > 0 and audio_players.size() == max_audios:
		
		var audio_player = audio_players.pop_back()
		audio_players.append(audio_player)
		audio_player.stream = sound_file
		audio_player.volume_db = volume
		audio_player.pitch_scale = pitch_scale
		audio_player.play()
		
	# Else, create a new one and make it play the requested audio.
	else:
		var audio_player = AudioStreamPlayer.new()
		add_child(audio_player)
		audio_players.append(audio_player)
		audio_player.stream = sound_file
		audio_player.volume_db = volume
		audio_player.pitch_scale = pitch_scale
		audio_player.play(start_position)
		
		
func seek(sound_file, seek_position : float) -> void:
	
	for audio_player in audio_players:
		if audio_player.stream == sound_file:
			audio_player.seek(seek_position)
			
			
func stop(sound_file) -> void:
	
	for audio_player in audio_players:
		if audio_player.playing:
			if audio_player.stream == sound_file:
				audio_player.stop()
	
	
func play_dict(sound_dict : Dictionary, delay := 0.0, start_position := 0.0) -> void:
	
	play(sound_dict.file, sound_dict.volume, sound_dict.pitch, delay, start_position)
	
	
func seek_dict(sound_dict : Dictionary, seek_position : float):
	
	seek(sound_dict.file, seek_position)
	
	
func stop_dict(sound_dict):
	
	stop(sound_dict.file)