extends Area2D
# The King Roach boss.
# Scratch version: "ROACHKING2" — appears once Exterminated crosses BOSS_THRESHOLD
# (see main.gd), has its own health bar, and loses health per bullet hit.
#
# Instead of walking at one flat speed the whole fight, it now cycles through:
# chase -> windup (a telegraphed pause) -> lunge (a fast committed rush)
# -> recover (briefly slower) -> back to chase.
#
# It also calls in reinforcements as it takes damage, more often and in
# bigger waves the lower its health gets.

signal died
signal health_changed(current: float, max: float)
signal spawn_roaches(count: int)   # tells main.gd to bring in reinforcements

enum State { CHASE, WINDUP, LUNGE, RECOVER }

const SPEED := 200.0
const MAX_HEALTH := 250.0
const DAMAGE_PER_HIT := 1.0

const LUNGE_SPEED_MULT := 3.0   # how much faster the lunge itself is than normal chasing
const WINDUP_TIME := 0.35       # brief pause before lunging, so you can see it coming
const LUNGE_TIME := 0.5
const RECOVER_TIME := 0.8       # slower right after a lunge, a small window to punish it
const RECOVER_SPEED_MULT := 0.4
const LUNGE_COOLDOWN := 2.5     # seconds of normal chasing between lunges

const WINDUP_SFX := preload("res://audio/king_roach_windup.mp3")     # plays the instant he freezes before lunging
const RECOVER_SFX := preload("res://audio/king_roach_recover.mp3")   # plays during the post-lunge slowdown
const AMBIENT_SFX := preload("res://audio/king_roach_ambient.mp3")   # random growl while he's alive, any state
const AMBIENT_INTERVAL_MIN := 4.0
const AMBIENT_INTERVAL_MAX := 9.0

var target: Node2D
var health := MAX_HEALTH

var state := State.CHASE
var state_timer := LUNGE_COOLDOWN
var lunge_dir := Vector2.RIGHT
var damage_since_spawn := 0.0   # tracks progress toward the next reinforcement wave

var ambient_timer := 0.0
@onready var windup_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var recover_player: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var ambient_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_to_group("boss")
	health_changed.emit(health, MAX_HEALTH)

	add_child(windup_player)
	windup_player.stream = WINDUP_SFX
	add_child(recover_player)
	recover_player.stream = RECOVER_SFX
	add_child(ambient_player)
	ambient_player.stream = AMBIENT_SFX
	ambient_timer = randf_range(AMBIENT_INTERVAL_MIN, AMBIENT_INTERVAL_MAX)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	var to_player := target.global_position - global_position
	rotation = to_player.angle()
	state_timer -= delta

	ambient_timer -= delta
	if ambient_timer <= 0.0:
		ambient_player.play()
		ambient_timer = randf_range(AMBIENT_INTERVAL_MIN, AMBIENT_INTERVAL_MAX)

	match state:
		State.CHASE:
			position += to_player.normalized() * SPEED * delta
			if state_timer <= 0.0:
				state = State.WINDUP
				state_timer = WINDUP_TIME
				lunge_dir = to_player.normalized()   # aims where you are right now, not where you end up
				windup_player.play()   # the freeze-before-lunge telegraph
		State.WINDUP:
			pass   # holds still for a moment, telegraphing the attack
			if state_timer <= 0.0:
				state = State.LUNGE
				state_timer = LUNGE_TIME
		State.LUNGE:
			position += lunge_dir * SPEED * LUNGE_SPEED_MULT * delta
			if state_timer <= 0.0:
				state = State.RECOVER
				state_timer = RECOVER_TIME
				recover_player.play()   # plays through the post-lunge slowdown
		State.RECOVER:
			position += to_player.normalized() * SPEED * RECOVER_SPEED_MULT * delta
			if state_timer <= 0.0:
				state = State.CHASE
				state_timer = LUNGE_COOLDOWN


func hit() -> void:
	health = max(health - DAMAGE_PER_HIT, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	_check_swarm_spawn(DAMAGE_PER_HIT)
	if health <= 0.0:
		died.emit()
		call_deferred("queue_free")


# The lower King Roach's health drops, the more often taking damage calls in
# reinforcements. Each bracket has its own "damage needed per wave" and
# "roaches per wave", so the fight escalates in stages instead of all at once.
func _check_swarm_spawn(damage: float) -> void:
	var threshold := 0.0
	var wave_size := 0

	if health <= 35.0:
		threshold = 1.0
		wave_size = 1
	elif health <= 75.0:
		threshold = 3.0
		wave_size = 2
	elif health <= 120.0:
		threshold = 5.0
		wave_size = 2
	elif health <= 200.0:
		threshold = 10.0
		wave_size = 1
	else:
		return   # above 200 health: no reinforcements yet

	damage_since_spawn += damage
	while damage_since_spawn >= threshold:
		damage_since_spawn -= threshold
		spawn_roaches.emit(wave_size)
