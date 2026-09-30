extends Node2D
# The game controller: spawns roaches, counts kills, triggers the boss, handles game over.
# Scratch version: the Stage plus the "when backdrop switches to ..." scripts.

const BulletScene := preload("res://bullet.tscn")
const RoachScene := preload("res://roach.tscn")
const KingRoachScene := preload("res://king_roach.tscn")
const PickupScene := preload("res://pickup.tscn")

const ShootSfx: AudioStream = preload("res://audio/bullet.mp3")

const SHOOT_DELAY := 0.12  #fire rate
const BOSS_THRESHOLD := 25 #how many roaches for boss to spawn

var exterminated := 0         #"Exterminated" variable
var shoot_timer := 0.0
var game_over := false
var won := false
var boss_spawned := false
var boss: Area2D = null

@onready var player: Area2D = $Player
@onready var spawn_timer: Timer = $SpawnTimer
@onready var health_label: Label = $HUD/HealthLabel
@onready var kills_label: Label = $HUD/KillsLabel
@onready var ammo_label: Label = $HUD/AmmoLabel
@onready var boss_health_label: Label = $HUD/BossHealthLabel
@onready var message_label: Label = $HUD/MessageLabel


func _ready() -> void:
	_setup_input()
	player.position = get_viewport_rect().size / 2.0
	player.health_changed.connect(_on_player_health_changed)
	player.ammo_changed.connect(_on_player_ammo_changed)
	player.died.connect(_on_player_died)
	spawn_timer.timeout.connect(_spawn_roach)
	message_label.text = "Let's kill some bugs!\nWASD to move, left click to spray"
	boss_health_label.visible = false
	_update_hud()


# Creates the keyboard/mouse actions in code so the project works out of the box.
# Later you can move these to Project > Project Settings > Input Map.
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("restart", [KEY_R])
	_add_mouse_action("shoot", MOUSE_BUTTON_LEFT)


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _add_mouse_action(action: String, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	if game_over:
		return

	# Left click fires, same delay-and-fire loop as before, now gated on ammo.
	# Shooting still works after winning, so you can keep mopping up stragglers.
	shoot_timer -= delta
	if Input.is_action_pressed("shoot") and shoot_timer <= 0.0:
		if player.spend_ammo():
			_shoot()
			shoot_timer = SHOOT_DELAY

	# Scratch: "wait until Exterminated > 35" then show the King Roach.
	if not won and not boss_spawned and exterminated >= BOSS_THRESHOLD:
		_spawn_boss()


func _shoot() -> void:
	var bullet := BulletScene.instantiate()   # instantiate() is Godot's "create clone"
	bullet.position = player.position + player.facing * 30.0
	bullet.direction = player.facing
	add_child(bullet)
	_play_one_shot(ShootSfx, -6.0)


# A sound that plays once and cleans itself up, independent of whatever
# fired it. Used for shots (bullet dies fast) and any other short one-off.
func _play_one_shot(stream: AudioStream, volume_db: float = 0.0) -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _spawn_roach() -> void:
	if boss_spawned:
		return   # Scratch's roach spawner also stops once the boss phase begins
	_spawn_roach_at(_random_edge_position())


# Picks a random point just off one of the four screen edges.
# Scratch spawned at x=200 with a random y; here we pick a random edge instead.
func _random_edge_position() -> Vector2:
	var size := get_viewport_rect().size
	match randi() % 4:
		0: return Vector2(-30, randf_range(0, size.y))
		1: return Vector2(size.x + 30, randf_range(0, size.y))
		2: return Vector2(randf_range(0, size.x), -30)
		_: return Vector2(randf_range(0, size.x), size.y + 30)


func _spawn_roach_at(pos: Vector2) -> void:
	var roach := RoachScene.instantiate()
	roach.position = pos
	roach.target = player
	roach.died.connect(_on_roach_died)
	roach.spawn_pickup.connect(_on_roach_spawn_pickup)
	add_child(roach)


# Called when a roach's death roll drops a pickup.
func _on_roach_spawn_pickup(kind: String, at_position: Vector2) -> void:
	var pickup := PickupScene.instantiate()
	pickup.kind = kind
	pickup.position = at_position
	add_child(pickup)


# Called when the King Roach calls in reinforcements as it takes damage.
func _on_boss_spawn_roaches(count: int) -> void:
	for i in count:
		_spawn_roach_at(_random_edge_position())


func _spawn_boss() -> void:
	boss_spawned = true
	spawn_timer.stop()
	message_label.text = "The King Roach appears!"

	boss = KingRoachScene.instantiate()
	boss.position = Vector2(get_viewport_rect().size.x - 150, 120)
	boss.target = player
	boss.died.connect(_on_boss_died)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.spawn_roaches.connect(_on_boss_spawn_roaches)
	add_child(boss)

	boss_health_label.visible = true


func _on_roach_died() -> void:
	exterminated += 1
	if not boss_spawned:
		message_label.text = ""
	_update_hud()


func _on_boss_health_changed(current: float, max_health: float) -> void:
	boss_health_label.text = "King Roach: %d / %d" % [int(current), int(max_health)]


func _on_boss_died() -> void:
	won = true
	player.invulnerable = true   # a leftover roach can't undo the win
	message_label.text = "Exterminated! You win.\nPress R to play again."
	boss_health_label.visible = false


func _on_player_health_changed(_new_health: float) -> void:
	_update_hud()


func _on_player_ammo_changed(_new_ammo: int) -> void:
	_update_hud()


func _on_player_died() -> void:
	if won:
		return   # already won; a late hit shouldn't be possible now, but just in case
	game_over = true
	spawn_timer.stop()
	message_label.text = "Game over. You exterminated %d.\nPress R to try again." % exterminated


func _update_hud() -> void:
	health_label.text = "Health: %d" % int(player.health)
	kills_label.text = "Exterminated: %d" % exterminated
	ammo_label.text = "Ammo: %d" % player.ammo
