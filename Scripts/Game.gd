"""
TODO:
more enemy types
enemy scaling? with color based on difficulty
SCOPE leveling?
SCOPE enemies drop instant powerups
"""



extends Control

const ENEMY_FLASH_DURATION := 0.25
const PLAYER_DEATH_TIME := 2.0
const PICKUP_ATTRACT_RANGE := 200.0
const PICKUP_SPEED := 40.0
const HEART_HEAL := 10

# 20 = 20%
const CHANCE_TO_DROP_PICKUP := 40

var icon = preload("res://Assets/Textures/icon.png")
var enemy_flyer = preload("res://Assets/Resources/enemy_flyer.tres")
var enemy_melee = preload("res://Assets/Resources/enemy_melee.tres")
var font = preload("res://Assets/Resources/font64.tres")
var fireball = preload("res://Assets/Resources/fireball.tres")
var ice_blast_texture = preload("res://Assets/Resources/ice_blast.tres")
var ice_arrow_texture = preload("res://Assets/Resources/ice_arrow.tres")
var rotating_projectile_texture = preload("res://Assets/Resources/rotating_projectile.tres")
var heart = preload("res://Assets/Resources/heart.tres")

var music :={
	"file": preload("res://Assets/Sounds/music.ogg"),
	"volume": 5.0,
}

var sounds := {
	"enemy_hurt":
	{
		"file": preload("res://Assets/Sounds/enemy_hurt.wav"),
		"volume": -30.0,
		"pitch": 1.0,
	},
	"enemy_death":
	{
		"file": preload("res://Assets/Sounds/enemy_death.wav"),
		"volume": -30.0,
		"pitch": 1.0,
	},
	"player_pickup":
	{
		"file": preload("res://Assets/Sounds/player_pickup.wav"),
		"volume": -20.0,
		"pitch": 1.0,
	},
	"player_hurt":
	{
		"file": preload("res://Assets/Sounds/player_hurt.wav"),
		"volume": -20.0,
		"pitch": 1.0,
	},
	"player_death":
	{
		"file": preload("res://Assets/Sounds/player_death.wav"),
		"volume": -20.0,
		"pitch": 1.0,
	},
}



# Skills
var ice_blast := {
	"function_name":"ice_blast",
	"ready": true,
	"cooldown": 0.25,
	"cooldown_timer": 0.0,
	"max_range": 100.0,
	"active": false,
	"damage": 20,
	"projectile_texture": ice_blast_texture,
}

var ice_arrow := {
	"function_name":"ice_arrow",
	"ready": true,
	"cooldown": 1.0,
	"cooldown_timer": 0.0,
	"active": false,
	"projectile_speed": 1000.0,
	"damage": 40,
	"projectile_texture": ice_arrow_texture,
}

var rotating_projectiles := {
	"function_name":"rotating_projectiles",
	"ready": true,
	"cooldown": 8.0,
	"cooldown_timer": 0.0,
	"distance_from_caster": 116.0,
	"projectile_amount": 5,
	"projectiles": [],
	"active": false,
	"update_function": "update_rotating_projectiles",
	"projectile_speed": PI,
	"duration": 4.0,
	"timers": [],
	"damage": 20,
	"projectile_texture": rotating_projectile_texture,
}

var player := {
	"id": "player",
	"body": KinematicBody2D.new(),
	"texture": preload("res://Assets/Resources/player.tres"),
	"hitbox_size": Vector2(80, 95),
	"texture_size": Vector2(128, 128),
	"velocity": Vector2(),
	"speed": 400.0,
	"skills": [ice_blast, ice_arrow, rotating_projectiles],
	"damage": 1,
	"alive": true,
	"max_health": 100,
	"current_health": 100,
	"scale": 1.0,
}

# Enemy types
var enemy_types := [
	{
		"type": "flying_demon",
		"max_health": 40,
		"damage": 5,
		"speed": 100.0,
		"attack_range": 300.0,
		"attack_delay": 1.0,
		"projectile_speed": 200.0,
		"texture": enemy_flyer,
		"hitbox_size": Vector2(100, 100),
		"texture_size": Vector2(128, 128),
		"hitbox_function": "add_circle_collision",
		"difficulty_to_spawn": 10,
	},
	{
		"type": "enemy_melee",
		"max_health": 80,
		"damage": 10,
		"speed": 200.0,
		"attack_range": 150.0,
		"attack_delay": 0.5,
		"projectile_speed": 400.0,
		"texture": enemy_melee,
		"hitbox_size": Vector2(128, 128),
		"texture_size": Vector2(128, 128),
		"hitbox_function": "add_rect_collision",
		"difficulty_to_spawn": 11,
	},
]

var levels := []
var level_index := 0
var level_to_beat_to_win = 10
var window : Vector2
var layer_player := 1
var layer_enemy := 2
var layer_other := 3
var projectiles := []
var pickups := []
var mouse : Vector2
var timed_messages := []
var player_start_position : Vector2
var audio_manager : AudioManager
var enemy_audio : AudioManager
var music_player : AudioStreamPlayer
var enemy_death_particles_scene = preload("res://Scenes/EnemyDeathParticles.tscn")
var player_death_particles_scene = preload("res://Scenes/PlayerDeathParticles.tscn")
var particles := []
var frame_count := 0
var tilemap
var health_bar_size := Vector2(400,64)
var health_bar_color_under := Color(1, 0, 0, 0.5)
var health_bar_color_over := Color(0, 1, 0, 0.5)
var cooldown_color := Color(1, 0, 0, 0.5)
var pickup_color := Color(0.5, 2, 0.5)

enum {DEFAULT, PLAYER_DEATH}
var state := DEFAULT

# UI
var game_won_ui_scene = preload("res://Scenes/GameWonUI.tscn")
var game_won_ui

func _ready():
	
	window = get_viewport_rect().size
	player_start_position = window / 2.0
	
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_margins_preset(PRESET_WIDE)
	
	for key in player:
		if player[key] is Node:
			add_child(player[key])
			
	levels = init_levels()

	add_rect_collision(player.body, player.hitbox_size)
	player.body.set_collision_layer_bit(layer_player, true)
	player.body.set_collision_mask_bit(layer_other, true)
	
	player.body.set_meta("owner", player)
	player.body.position = player_start_position
	
	audio_manager = AudioManager.new()
	add_child(audio_manager)
	
	enemy_audio = AudioManager.new(false, 5)
	add_child(enemy_audio)
	
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.stream = music.file
	music_player.volume_db = music.volume
	music_player.playing = true
	music_player.pause_mode = PAUSE_MODE_PROCESS
	
	disable_default_layers(tilemap)
	tilemap.set_collision_layer_bit(layer_other, true)


func _physics_process(delta):
	
	mouse = get_global_mouse_position()
	
	match state:
		
		DEFAULT:
		
			var level_beaten = update_current_level(levels[level_index], delta)
			if level_beaten:
		
				level_index += 1
				timed_message("Level %s completed" % level_index, 2.0)
				
				# Create more levels if there are no more
				if level_index == levels.size():
					var spawns = (level_index + 1) * 10
					var delay = 5.0 / spawns
					levels.append(create_level(spawns, delay))
					
				if level_index == level_to_beat_to_win:
					game_won_ui = game_won_ui_scene.instance()
					add_child(game_won_ui)
					game_won_ui.pause_mode = PAUSE_MODE_PROCESS
					game_won_ui.connect("keep_going", self, "on_game_won_continue")
					game_won_ui.connect("exit", self, "on_game_won_exit")
					get_tree().paused = true
					
			update_player(player, delta)
			if frame_count % 2 == 0:
				update_enemies(levels[level_index].enemies, player, delta * 2.0)
				update_projectiles(projectiles, delta * 2.0)
			update_particles(particles, delta)
			update_pickups(pickups, delta)
			update_timed_messages(timed_messages, delta)
		
		PLAYER_DEATH:
		
			player.scale = lerp(player.scale, 0, 0.1)
			update_projectiles(projectiles, delta)
			update_particles(particles, delta)
			update_timed_messages(timed_messages, delta)
			
	update()
	
	frame_count += 1
	
	
func _draw():
	
	# Draw enemies
	for enemy in levels[level_index].enemies:
		var other_color := 1.0
		
		if enemy.took_damage_timer > 0.0:
			other_color = range_lerp(enemy.took_damage_timer, ENEMY_FLASH_DURATION, 0, 0, 1)
			
		draw_texture_rect(enemy.texture, Rect2(topleft_to_center(enemy.body.position, enemy.texture_size), enemy.texture_size), false, Color(1, other_color, other_color))
	
	# Draw player
	draw_set_transform(player.body.position, 0, Vector2(player.scale, player.scale))
	draw_texture_rect(player.texture, Rect2(-player.texture_size / 2.0, player.texture_size), false)
	
	# Draw projectiles
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 1))
	for projectile in projectiles:
		draw_set_transform(projectile.area.position, projectile.texture_rotation, Vector2(projectile.texture_scale, projectile.texture_scale))
		draw_texture_rect(projectile.texture, Rect2(-projectile.texture_size / 2.0, projectile.texture_size), false)
		
	# Draw pickups
	draw_set_transform(Vector2(0, 0), 0, Vector2(1, 1))
	for pickup in pickups:
		draw_texture_rect(pickup.texture, Rect2(topleft_to_center(pickup.area.position, pickup.size), pickup.size), false, pickup_color)
		
	# Draw health bar
	draw_rect(Rect2(Vector2(window.x / 2 - health_bar_size.x / 2.0, window.y - health_bar_size.y), health_bar_size), health_bar_color_under)
	var top_fill = player.current_health / float(player.max_health)
	draw_rect(Rect2(Vector2(window.x / 2 - health_bar_size.x / 2.0, window.y - health_bar_size.y), Vector2(health_bar_size.x * top_fill, health_bar_size.y)), health_bar_color_over)
	
	# Draw skill bar
	var pos = Vector2(window.x / 2.0, window.y - 128)
	var icon_size := Vector2(64, 64)
	var spacing := 10
	var size = Vector2(player.skills.size() * (icon_size.x + spacing), icon_size.y)
	for i in player.skills.size():
		var skill = player.skills[i]
		var extra_x = (icon_size.x + spacing) * i
		var final_x = pos.x - size.x / 2.0 + extra_x
		draw_texture_rect(skill.projectile_texture, Rect2(Vector2(final_x, pos.y), icon_size), false)
		if skill.cooldown_timer > 0.0:
			var percent = skill.cooldown_timer / skill.cooldown
			var foo = pos.y + size.y
			draw_rect(Rect2(Vector2(final_x, pos.y + icon_size.y * percent), Vector2(icon_size.x, foo - (pos.y + icon_size.y * percent))), cooldown_color)
		
	# Draw timed messages
	for message in timed_messages:
		var x = window.x / 2.0 - (font.get_string_size(message.text).x / 2.0)
		draw_string(font, Vector2(x, 128), message.text, message.color)
		
		
func topleft_to_center(position : Vector2, size : Vector2) -> Vector2:
	
	return position - size / 2
	
	
func update_player(player : Dictionary, delta : float):
	
	if not player.alive:
		on_player_death()
		return
	
	# TODO: remove
	if Input.is_action_pressed("ui_cancel"):
		restart()
	
	var direction := Vector2()
	if Input.is_action_pressed("move_left"):
		direction.x += -1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y += -1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
		
	direction = direction.normalized()
	
	player.velocity += direction * player.speed
	
	player.body.move_and_slide(player.velocity)
	player.velocity *= 0
	
	# Update skills
	for skill in player.skills:
		if not skill.ready:
			skill.cooldown_timer += delta
			if skill.cooldown_timer >= skill.cooldown:
				skill.ready = true
				skill.cooldown_timer = 0.0
				
		if skill.active:
			call(skill.update_function, player, skill, delta)
			
	# Skill input
	if Input.is_action_pressed("left_click"):
		if player.skills[0].ready:
			call(player.skills[0].function_name, player, mouse, player.skills[0], [layer_enemy, layer_other])
			
	if Input.is_action_pressed("right_click"):
		if player.skills[1].ready:
			call(player.skills[1].function_name, player, mouse, player.skills[1], [layer_enemy, layer_other])
			
	if Input.is_action_pressed("skill_q"):
		if player.skills[2].ready:
			call(player.skills[2].function_name, player, mouse, player.skills[2], [layer_enemy, layer_other])
	
	
func create_enemy(type : Dictionary, position : Vector2) -> Dictionary:
	
	var enemy := {
		"id": "enemy",
		"max_health": type.max_health,
		"speed": type.speed,
		"damage": type.damage,
		"attack_range": type.attack_range,
		"attack_delay": type.attack_delay,
		"projectile_speed": type.projectile_speed,
		"attack_timer": 0.0,
		"can_attack": false,
		"texture": type.texture,
		"body": KinematicBody2D.new(),
		"hitbox_size": type.hitbox_size,
		"texture_size": type.texture_size,
		"alive": true,
		"took_damage_timer": 0.0,
	}
	enemy.current_health = enemy.max_health
	
	for key in enemy:
		if enemy[key] is Node:
			add_child(enemy[key])
	
	call(type.hitbox_function, enemy.body, enemy.hitbox_size)
			
	enemy.body.set_collision_layer_bit(layer_enemy, true)
	enemy.body.position = position
	
	# Give the enemy's body a reference to the enemy for projectile collision purposes
	enemy.body.set_meta("owner", enemy)
	
	return enemy
	
	
func create_level(spawns : int, spawn_delay : float) -> Dictionary:
	
	var level := {
		"spawns": spawns,
		"spawned": 0,
		"spawn_delay": spawn_delay,
		"spawn_timer": 0.0,
		"enemies": [],
		"finished_spawning": false,
	}
	return level
	
	
func init_levels() -> Array:
	
	var levels := []
	
	levels.append(create_level(10, 5.0/10))
	levels.append(create_level(20, 5.0/20))
	levels.append(create_level(30, 5.0/30))
	levels.append(create_level(40, 5.0/40))
	levels.append(create_level(50, 5.0/50))
	levels.append(create_level(60, 5.0/60))
	levels.append(create_level(70, 5.0/70))
	levels.append(create_level(80, 5.0/80))
	levels.append(create_level(90, 5.0/90))
	levels.append(create_level(100, 5.0/100))
	
	return levels
	
	
func update_current_level(level : Dictionary, delta : float):
	
	if level.finished_spawning:
		if level.enemies.size() == 0:
			return true
		return false
	
	level.spawn_timer += delta
	if level.spawn_timer >= level.spawn_delay:
		
		
		# Pick random enemy type
		var choosen_type = ""
		var type_counter = []
		
		for type in enemy_types:
			type_counter.append([type.type, 0])
		
		while true:
			
			var random_index = randi() % enemy_types.size()
			type_counter[random_index][1] += 1
			
			if type_counter[random_index][1] >= enemy_types[random_index].difficulty_to_spawn:
				choosen_type = enemy_types[random_index]
				break
		
		# Pick random spawn position
		var choices := ["left", "top", "right", "bottom"]
		var choice = choices[randi() % choices.size()]
		var random_position := Vector2()
		
		if choice == "left":
			random_position.x = 64
			random_position.y = (randi() % int(window.y - 128)) + 64
			
		elif choice == "top":
			random_position.x = (randi() % int(window.x - 128)) + 64
			random_position.y = 0
			
		elif choice == "right":
			random_position.x = window.x - 64
			random_position.y = (randi() % int(window.y - 128)) + 64
			
		elif choice == "bottom":
			random_position.x = (randi() % int(window.x - 128)) + 64
			random_position.y = window.y - 64
				
		# Spawn enemy
		
		var enemy = create_enemy(choosen_type, random_position)
		level.enemies.append(enemy)
		level.spawned += 1
		if level.spawned == level.spawns:
			level.finished_spawning = true
		
		level.spawn_timer -= level.spawn_delay
		
	return false
	
	
func ice_blast(user : Dictionary, target : Vector2, skill : Dictionary, target_layers : Array):
	
	skill.ready = false
	
	var cast_position = (target - user.body.position).normalized() * min(target.distance_to(user.body.position), skill.max_range)
	
	var projectile_data := {
		"position": user.body.position + cast_position,
		"target_layers": target_layers,
		"damage": skill.damage,
		"persistent": true,
		"speed": 0,
		"texture": skill.projectile_texture.duplicate(),
		"duration": 0.25,
		"hitbox_size": Vector2(256, 256),
		"texture_size": Vector2(256, 256),
		"ignore_tilemap": true,
	}
	var projectile = create_projectile(projectile_data)
	projectiles.append(projectile)
	
	
func ice_arrow(user : Dictionary, target : Vector2, skill : Dictionary, target_layers : Array):
	
	skill.ready = false
	
	var projectile_data := {
		"position": user.body.position,
		"direction": (target - user.body.position).normalized(),
		"target_layers": target_layers,
		"damage": skill.damage,
		"persistent": true,
		"speed": skill.projectile_speed,
		"texture": skill.projectile_texture,
		"hitbox_size": Vector2(128, 128),
		"texture_size": Vector2(128, 128),
		"ignore_tilemap": true,
		"allow_rotation": true,
	}
	var projectile = create_projectile(projectile_data)
	projectiles.append(projectile)
	

func rotating_projectiles(user : Dictionary, target : Vector2, skill : Dictionary, target_layers : Array):
	
	skill.ready = false
	skill.active = true
	
	var instance_projectiles := []
	
	var step : float = PI * 2 / skill.projectile_amount
	for i in skill.projectile_amount:
		
		var projectile_position = user.body.position + polar2cartesian(skill.distance_from_caster, step * i)
		
		var projectile_data := {
			"position": projectile_position,
			"target_layers": target_layers,
			"damage": skill.damage,
			"persistent": true,
			"speed": 0,
			"texture": skill.projectile_texture,
			"hitbox_size": Vector2(48, 48),
			"texture_size": Vector2(48, 48),
			"ignore_tilemap": true,
		}
		var projectile = create_projectile(projectile_data)
		projectiles.append(projectile)
		projectile.angle = step * i
		instance_projectiles.append(projectile)
		
	skill.projectiles.append(instance_projectiles)
	skill.timers.append(0.0)
	
	user.speed *= 2.0
		
		
func update_rotating_projectiles(user : Dictionary, skill : Dictionary, delta : float):
	
	for i in range(skill.timers.size() - 1, -1, -1):
		
		var instance_projectiles = skill.projectiles[i]
		skill.timers[i] += delta
		
		if skill.timers[i] >= skill.duration:
		
			for projectile in instance_projectiles:
				projectiles.erase(projectile)
				destroy(projectile)
				
			skill.projectiles.remove(i)
			skill.timers.remove(i)
		
			if skill.timers.size() == 0:
				skill.active = false
				user.speed /= 2.0
		
			return
	
		for projectile in instance_projectiles:
			projectile.angle += skill.projectile_speed * delta
			projectile.area.position = user.body.position + polar2cartesian(skill.distance_from_caster, projectile.angle)
	
		
func create_projectile(projectile_data : Dictionary) -> Dictionary:
	
	var projectile := {
		"area": Area2D.new(),
		"damage": projectile_data.get("damage", 1),
		"speed": projectile_data.get("speed", 800.0),
		"texture": projectile_data.get("texture", icon),
		"direction": projectile_data.get("direction", Vector2(0, 0)),
		"hitbox_size": projectile_data.hitbox_size,
		"texture_size": projectile_data.texture_size,
		"texture_rotation": 0,
		"texture_scale": projectile_data.get("texture_scale", 1.0),
		"persistent": projectile_data.get("persistent", false),
		"targets_hit": [],
		"duration": projectile_data.get("duration", -1),
		"life_timer": 0.0,
		"ignore_tilemap": projectile_data.get("ignore_tilemap", false)
	}
	
	if projectile_data.get("allow_rotation", false):
		projectile.texture_rotation = projectile_data.direction.angle() + PI / 2.0
	
	for key in projectile:
		if projectile[key] is Node:
			add_child(projectile[key])
			
	var collision = CollisionShape2D.new()
	projectile.area.add_child(collision)
	collision.shape = CircleShape2D.new()
	collision.shape.radius = projectile.hitbox_size.x / 2.0
			
	disable_default_layers(projectile.area)
	for layer in projectile_data.target_layers:
		projectile.area.set_collision_mask_bit(layer, true)
	projectile.area.position = projectile_data.position
	
	if projectile.ignore_tilemap:
		projectile.area.set_collision_mask_bit(layer_other, false)
	
	return projectile
	
func update_projectiles(projectiles : Array, delta : float):
	
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile = projectiles[i]
		projectile.area.position += projectile.direction * projectile.speed * delta
		
		# Update timer if this is a timed projectile
		if projectile.duration > 0:
			projectile.life_timer += delta
			if projectile.life_timer >= projectile.duration:
				destroy(projectile)
				projectiles.remove(i)
				continue
		
		# If the projectile goes out of the map, destroy it
		if projectile.area.position.x > window.x * 1.2 or projectile.area.position.x < -window.x * 0.2 or projectile.area.position.y > window.y * 1.2 or projectile.area.position.y < -window.y * 0.2:
			destroy(projectile)
			projectiles.remove(i)
			continue
		
		for body in projectile.area.get_overlapping_bodies():
			
			if body in projectile.targets_hit:
				continue
			
			if body is TileMap:
				destroy(projectile)
				projectiles.remove(i)
				break
				
			else:
				var owner = body.get_meta("owner")
				if owner.alive:
					damage_entity(owner, projectile.damage)
					if not projectile.persistent:
						destroy(projectile)
						projectiles.remove(i)
						break
					else:
						projectile.targets_hit.append(body)

						
func damage_entity(entity : Dictionary, damage : int):
	
	entity.current_health -= damage
	
	if entity.current_health <= 0:
		
		entity.alive = false
		
		if entity.id == "enemy":
			enemy_audio.play_dict(sounds.enemy_death)
	else:
		
		if entity.id == "enemy":
			enemy_audio.play_dict(sounds.enemy_hurt)
			entity.took_damage_timer = ENEMY_FLASH_DURATION
			
		elif entity.id == "player":
			audio_manager.play_dict(sounds.player_hurt)
	
		
func destroy(game_object : Dictionary):
	
	for key in game_object:
		if game_object[key] is Node:
			game_object[key].queue_free()
			
	
func disable_default_layers(node):
	
	node.set_collision_layer_bit(0, false)
	node.set_collision_mask_bit(0, false)
	

func update_enemies(enemies : Array, player : Dictionary, delta : float):
	
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		
		if not enemy.alive:
			
			# Random chance to drop pickup
			var roll = (randi() % 100) + 1
			if roll <= CHANCE_TO_DROP_PICKUP:
				
				var pickup_data := {
					"position": enemy.body.position,
					"texture": heart,
				}
				var pickup = create_pickup(pickup_data)
				pickups.append(pickup)
				
			# Create particles
			var particle = enemy_death_particles_scene.instance()
			add_child(particle)
			particle.position = enemy.body.position
			particles.append([particle, particle.lifetime, 0.0])
			
			destroy(enemy)
			enemies.remove(i)
			
		else:
			enemy.attack_timer += delta
			if enemy.attack_timer >= enemy.attack_delay:
				enemy.can_attack = true
				enemy.attack_timer = 0
			
			
			var attacking := false
			if enemy.body.position.distance_to(player.body.position) <= enemy.attack_range:
				attacking = true
				
				if enemy.can_attack:
					var projectile_data := {
						"position": enemy.body.position,
						"direction": (player.body.position - enemy.body.position).normalized(),
						"speed": enemy.projectile_speed,
						"damage": enemy.damage,
						"target_layers": [layer_player, layer_other],
						"texture": fireball,
						"hitbox_size": Vector2(32, 32),
						"texture_size": Vector2(32, 32),
						"texture_scale": 1.5,
						"allow_rotation": true,
					}
					var projectile = create_projectile(projectile_data)
					projectiles.append(projectile)
					enemy.can_attack = false
					enemy.attack_timer = 0
					
			# If not in range to attack, move towards player
			if not attacking:
				# var temp_velocity = (player.body.position - enemy.body.position).normalized() * enemy.speed
				# enemy.body.move_and_slide(temp_velocity)
				enemy.body.position += (player.body.position - enemy.body.position).normalized() * enemy.speed * delta
				
			if enemy.took_damage_timer > 0:
				enemy.took_damage_timer = max(enemy.took_damage_timer - delta, 0)
			
			
			
func timed_message(text : String, duration : float, color := Color(1, 1, 1)) -> void:
	
	var message := {
		"text": text,
		"duration": duration,
		"timer": 0.0,
		"alpha_decay_start_time": duration * 0.8,
		"color": Color(color.r, color.g, color.b, 1),
	}
	timed_messages.append(message)
			
	
func update_timed_messages(messages : Array, delta : float):
	
	for i in range(messages.size() - 1, -1, -1):
		var message = messages[i]
		message.timer += delta
		if message.timer >= message.duration:
			messages.remove(i)
		else:
			message.color.a = clamp(range_lerp(message.timer, message.alpha_decay_start_time, message.duration, 1, 0), 0, 1)
			
			
func on_game_won_continue():
	
	get_tree().paused = false
	game_won_ui.queue_free()
	
	
func on_game_won_exit():
	
	get_tree().paused = false
	get_tree().quit()
	
	
func restart():

	# Restart player data
	player.body.position = player_start_position
	player.current_health = player.max_health
	player.alive = true
	player.scale = 1.0
	player.speed = 400.0
	
	var current_level = levels[level_index]
	
	# Remove enemies
	var enemies = current_level.enemies
	for i in range(enemies.size() - 1, -1, -1):
		destroy(enemies[i])
		enemies.remove(i)
		
	# Restart level data
	current_level.spawned = 0
	current_level.spawn_timer = 0.0
	current_level.finished_spawning = false
	
	# Clean up skills
	rotating_projectiles.timers.clear()
	rotating_projectiles.projectiles.clear()
	
	for skill in player.skills:
		skill.ready = true
		skill.active = false
		skill.cooldown_timer = 0.0
		
	# Remove projectiles
	for i in range(projectiles.size() - 1, -1, -1):
		destroy(projectiles[i])
		projectiles.remove(i)
	
	# Remove timed messages
	for i in range(timed_messages.size() - 1, -1, -1):
		timed_messages.remove(i)
	
	# Remove pickups
	for i in range(pickups.size() - 1, -1, -1):
		destroy(pickups[i])
		pickups.remove(i)
		
	# Remove particles
	for i in range(particles.size() - 1, -1, -1):
		particles[i][0].queue_free()
		particles.remove(i)
		
	
func on_player_death():
	
	state = PLAYER_DEATH
	audio_manager.play_dict(sounds.player_death)
	var particle = player_death_particles_scene.instance()
	add_child(particle)
	particle.position = player.body.position
	particles.append([particle, particle.lifetime, 0.0])
	
	yield(get_tree().create_timer(PLAYER_DEATH_TIME), "timeout")
	state = DEFAULT
	restart()
	timed_message("Retrying level %s" % (level_index + 1), 2.0)
	
	
func create_pickup(data : Dictionary) -> Dictionary:
	
	var pickup := {
		"area": Area2D.new(),
		"texture": data.texture,
		"size": Vector2(64, 64),
	}
	
	for key in pickup:
		if pickup[key] is Node:
			add_child(pickup[key])
			
	pickup.area.position = data.position
	add_rect_collision(pickup.area, pickup.size)
	pickup.area.set_collision_mask_bit(layer_player, true)
	
	pickup.area.connect("body_entered", self, "on_player_pickup", [pickup])
			
	return pickup
	
	
func add_rect_collision(node, size : Vector2):
	
	var collision = CollisionShape2D.new()
	node.add_child(collision)
	collision.shape = RectangleShape2D.new()
	collision.shape.extents = size / 2.0
	disable_default_layers(node)
	
	
func add_circle_collision(node, size : Vector2):
	
	var collision = CollisionShape2D.new()
	node.add_child(collision)
	collision.shape = CircleShape2D.new()
	collision.shape.radius = size.x / 2.0
	disable_default_layers(node)
	
	
func on_player_pickup(body, pickup : Dictionary):
	
	player.current_health = min(player.current_health + HEART_HEAL, player.max_health)
	destroy(pickup)
	pickups.erase(pickup)
	audio_manager.play_dict(sounds.player_pickup)
	
	
func update_particles(particles : Array, delta : float):
	
	for i in range(particles.size() - 1, -1, -1):
		var particle = particles[i]
		particle[2] += delta
		if particle[2] >= particle[1]:
			particle[0].queue_free()
			particles.remove(i)
			
			
func update_pickups(pickups : Array, delta : float):
	
	for pickup in pickups:
		var distance = pickup.area.position.distance_to(player.body.position)
		if distance <= PICKUP_ATTRACT_RANGE:
			var direction = (player.body.position - pickup.area.position).normalized()
			var speed_modifier = range_lerp(distance, 0, 200, 4.0, 1.0)
			pickup.area.position += direction * PICKUP_SPEED * delta * speed_modifier