extends Area2D
# A cockroach.
# Scratch version: the "Roach" sprite, cloned on a timer, chasing "point towards Exterminator".
#
# Each roach gets its own personality on spawn: a random speed, and an
# "aggression" score that decides how often it presses the attack versus
# dodging sideways or darting in for a hit-and-run pounce, then retreating.
# On death it also has a chance to drop an ammo or health pickup.

signal died
signal spawn_pickup(kind: String, at_position: Vector2)

enum State { CHASE, DODGE, POUNCE, RETREAT }

const BASE_SPEED := 185.0   # pixels per second, before per-roach variation
const DODGE_SPEED_MULT := 0.8
const POUNCE_SPEED_MULT := 2.4
const RETREAT_SPEED_MULT := 1.6

const AMMO_DROP_CHANCE := 0.30    # % chance to drop an ammo pickup on death
const HEALTH_DROP_CHANCE := 0.15  # % chance to drop a health pickup on death (independent roll)

# One of these two is picked per roach on spawn, so each roach keeps the same
# voice for its whole life instead of switching noises every time it barks.
const NOISE_1 := preload("res://audio/roach_noise_1.mp3")
const NOISE_2 := preload("res://audio/roach_noise_2.mp3")
const NOISE_INTERVAL_MIN := 2.5   # seconds between barks, per roach
const NOISE_INTERVAL_MAX := 6.0

var target: Node2D          # the player, set by main.gd when this roach is spawned
var health := 10

var speed_mult := 1.0       # randomized per roach: some are faster or slower
var aggression := 0.5       # 0 = timid (dodges/retreats more), 1 = relentless (pounces more)

var state := State.CHASE
var state_timer := 0.0
var retreat_dir := Vector2.RIGHT

var noise_timer := 0.0
@onready var noise_player: AudioStreamPlayer = AudioStreamPlayer.new()


func _ready() -> void:
	add_to_group("roach")   # lets bullets and the player recognise a roach
	speed_mult = randf_range(0.75, 1.5)
	aggression = randf_range(0.0, 1.0)
	_pick_new_state()

	add_child(noise_player)
	noise_player.stream = NOISE_1 if randf() < 0.5 else NOISE_2
	noise_player.volume_db = -10.0
	noise_timer = randf_range(NOISE_INTERVAL_MIN, NOISE_INTERVAL_MAX)


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	state_timer -= delta
	if state_timer <= 0.0:
		_pick_new_state()

	noise_timer -= delta
	if noise_timer <= 0.0:
		noise_player.play()
		noise_timer = randf_range(NOISE_INTERVAL_MIN, NOISE_INTERVAL_MAX)

	var to_player := target.global_position - global_position
	rotation = to_player.angle()   # always face you, even mid-dodge or mid-retreat

	match state:
		State.CHASE:
			position += to_player.normalized() * BASE_SPEED * speed_mult * delta
		State.DODGE:
			# strafes sideways instead of coming straight in, like it's avoiding your spray
			var side := to_player.normalized().rotated(PI / 2.0 * (1 if randf() < 0.5 else -1))
			position += side * BASE_SPEED * speed_mult * DODGE_SPEED_MULT * delta
		State.POUNCE:
			# a fast, committed rush straight at you
			position += to_player.normalized() * BASE_SPEED * speed_mult * POUNCE_SPEED_MULT * delta
		State.RETREAT:
			# darts back to a safe distance in a straight line, then circles in again
			position += retreat_dir * BASE_SPEED * speed_mult * RETREAT_SPEED_MULT * delta


# Chooses the next behaviour. Aggression skews the odds: a high-aggression
# roach pounces often and barely retreats, a low-aggression one dodges and
# flees more and spends longer just circling at a distance.
func _pick_new_state() -> void:
	var was_pouncing := state == State.POUNCE
	var roll := randf()

	if was_pouncing:
		# always disengage briefly after committing to a pounce, timid roaches
		# retreat further and longer than aggressive ones
		state = State.RETREAT
		retreat_dir = -(target.global_position - global_position).normalized()
		state_timer = lerp(0.2, 0.9, 1.0 - aggression)
		return

	if roll < 0.15 + (1.0 - aggression) * 0.25:
		state = State.DODGE
		state_timer = randf_range(0.3, 0.6)
	elif roll < 0.35 + aggression * 0.35:
		state = State.POUNCE
		state_timer = randf_range(0.4, 0.7)
	else:
		state = State.CHASE
		state_timer = randf_range(0.6, 1.4)


func hit() -> void:
	health -= 4
	if health <= 0:
		died.emit()   # main.gd listens for this to add to the "Exterminated" counter
		# Two independent rolls, so in principle both, either, or neither could drop.
		if randf() < AMMO_DROP_CHANCE:
			spawn_pickup.emit("ammo", global_position)
		if randf() < HEALTH_DROP_CHANCE:
			spawn_pickup.emit("health", global_position + Vector2(12, 12))
		call_deferred("queue_free")
