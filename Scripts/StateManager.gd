extends Node
class_name StateManager

var parent
var states : Dictionary
var current_state : Dictionary
var current_state_key : String

var state_stack := []

func _init(_parent, _states : Dictionary):
	
	parent = _parent
	states = _states
	
	# For each state, if there are no "data", "updates" or "draw" keys, create them
	for key in states:
		var state = states[key]
		if not "data" in states:
			state.data = {}
		if not "updates" in states:
			state.updates = []
		if not "draw" in states:
			state.draw = false
			
	
func process(delta) -> void:
	
	for update in current_state.updates:
		if parent.call(update, current_state.data, delta) == "break":
			break
			
	if current_state.draw:
		parent.update()
		
		
func set_state(new_state : String, data := {}) -> void:
	
	if current_state != null:
		if "on_leave" in current_state:
			parent.call(current_state.on_leave, current_state.data)
		state_stack.append(current_state_key)
			
	if new_state == "previous":
		var previous_state = state_stack.pop_back()
		current_state = states[previous_state]
		current_state_key = previous_state
	else:
		current_state = states[new_state]
		current_state_key = new_state
		
	for key in data:
		current_state.data[key] = data[key]
	
	if "on_enter" in current_state:
		parent.call(current_state.on_enter, current_state.data)
	
		
func handle_event(event) -> void:
	
	# If this state has no action events, return
	if not "actions" in current_state:
		return
		
	var suffix = ""
	for action in current_state.actions:
		
		var echo = action.get("echo", 0)
		
		if event.is_action(action.name):
			if event.is_pressed():
				if action.pressed == -1:
					suffix = ""
				elif action.pressed == 1:
					suffix = "_pressed"
				else:
					continue
					
			else:
				if action.pressed == -1:
					suffix = ""
				elif action.pressed == 0:
					suffix = "_released"
				else:
					continue
					
			if event.is_echo():
				if echo == 0:
					continue
					
			# Check if modifiers match
			var all_modifiers_match = true
			if "modifiers" in action:
				for modifier in action.modifiers:
					if not event.get(modifier):
						all_modifiers_match = false
						break
						
			if not all_modifiers_match:
				continue
				
			var action_name = "%s_%s%s" % [current_state_key, action.name, suffix]
			parent.process_event(action_name, current_state.data)
			get_tree().set_input_as_handled()
			return