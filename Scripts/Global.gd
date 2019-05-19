extends Node

var timers := []


func time_func(target, func_name, runs := 1, use_milliseconds := true):
	
	assert(runs > 0)
	
	var time_elapsed := 0
	
	for i in runs:
	
		var last_time = 0
		if use_milliseconds:
			last_time = OS.get_system_time_msecs()
		else:
			last_time = OS.get_ticks_usec()
		
		target.call(func_name)
		
		var now = 0
		if use_milliseconds:
			now = OS.get_system_time_msecs() - last_time
		else:
			now = OS.get_ticks_usec() - last_time
		
		time_elapsed += now
		
	var text := "run" if runs == 1 else "runs"
	var foo := "milliseconds" if use_milliseconds else "microseconds"
	print("%s %s of %s took %s %s on average." % [runs, text, func_name, foo, time_elapsed / float(runs)])
	

func start_timer(use_milliseconds := true, text = ""):
	
	if use_milliseconds:
		timers.append([OS.get_system_time_msecs(), true, text])
	else:
		timers.append([OS.get_ticks_usec(), false, text])
	
func end_timer():
	
	var timer = timers.pop_back()
	if timer[1]:
		var now = OS.get_system_time_msecs() - timer[0]
		print("(%s) Time elapsed: %s milliseconds" %  [timer[2], now])
	else:
		var now = OS.get_ticks_usec() - timer[0]
		print("(%s) Time elapsed: %s microseconds" % [timer[2], now])
	

class SafeYield extends Node:
	
	signal done
	
	var who_yields
	
	var object_to_track
	var var_name
	var wanted_value
	
	func _init(_who_yields):
		
		who_yields = weakref(_who_yields)
		Global.add_child(self)
		set_process(false)
		
		
	func _process(delta):
		
		if object_to_track.get(var_name) == wanted_value:
			if safe_to_call():
				emit_signal("done")
			queue_free()
		
		
	func wait(object, signal_name):
		
		yield(object, signal_name)
		if safe_to_call():
			emit_signal("done")
		queue_free()
		
	func wait_timer(duration):
		
		yield(get_tree().create_timer(duration), "timeout")
		if safe_to_call():
			emit_signal("done")
		queue_free()
		
		
	func track_var(_object_to_track, _var_name : String, _wanted_value):
		
		set_process(true)
		object_to_track = _object_to_track
		var_name = _var_name
		wanted_value = _wanted_value
		
			
	func safe_to_call() -> bool:
		
		if who_yields.get_ref():
			return true
		return false
	
		