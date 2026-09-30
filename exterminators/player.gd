extends Area2D
# The exterminator.
# Scratch version: the "Exterminator" sprite plus its four "move" custom blocks,
# which each did: switch costume, move, and set direction.

signal health_changed(new_health)
signal ammo_changed(new_ammo)
signal died

const SPEED := 325.0             # pixels per SECOND (Scratch used "steps per frame")
const MAX_HEALTH := 150.0
const CONTACT_DAMAGE := 5.0      # damage per hit from a roach
const DAMAGE_COOLDOWN := 0.2     # seconds between hits (Scratch drained health every frame)

const MAX_AMMO := 180        # how much ammo you can carry at once
const START_AMMO := 100        # how much you start the run with

var health := MAX_HEALTH
var ammo := START_AMMO
var facing := Vector2.RIGHT      # the direction bullets fly, like Scratch's "point in direction"
var damage_timer := 0.0
var alive := true
var invulnerable := false        # set true once the fight is won, so a late hit can't "kill" you

@onready var sprite: Sprite2D = $Sprite2D

# Your four Scratch costumes, loaded straight from your sprite3 files.
const COSTUME_RIGHT := preload("res://art/exterminator_right.png")
const COSTUME_LEFT := preload("res://art/exterminator_left.png")
const COSTUME_UP := preload("res://art/exterminator_up.png")
const COSTUME_DOWN := preload("res://art/exterminator_down.png")


func _ready() -> void:
	add_to_group("player")   # lets pickups (and anything else) recognise you


func _physics_process(delta: float) -> void:
	if not alive:
		return

	# One line replaces your four move blocks, and diagonals work for free.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += input * SPEED * delta

	# Same idea as Scratch's "if on edge, bounce", but we simply stop at the edge.
	var screen := get_viewport_rect().size
	position = position.clamp(Vector2(30, 30), screen - Vector2(30, 30))

	# Aiming is separate from movement: the mouse decides which way you face
	# and which way you shoot, WASD only decides where you walk.
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		facing = to_mouse.normalized()
		_update_costume(facing)

	# Scratch: "if touching Roach, change health by -0.2" inside a forever loop.
	# Here a roach can only hurt us once per cooldown, so the fight isn't instant.
	damage_timer -= delta
	if damage_timer <= 0.0:
		for area in get_overlapping_areas():
			if area.is_in_group("roach") or area.is_in_group("boss"):
				take_damage(CONTACT_DAMAGE)
				damage_timer = DAMAGE_COOLDOWN
				break


# Scratch picked a costume per key (up/down/left/right). We have an analog
# input vector instead, so we pick whichever axis is stronger, same result.
func _update_costume(input: Vector2) -> void:
	if abs(input.x) > abs(input.y):
		sprite.texture = COSTUME_RIGHT if input.x > 0 else COSTUME_LEFT
	else:
		sprite.texture = COSTUME_DOWN if input.y > 0 else COSTUME_UP


func take_damage(amount: float) -> void:
	if invulnerable:
		return
	health = max(health - amount, 0.0)
	health_changed.emit(health)
	if health <= 0.0:
		alive = false
		died.emit()
		modulate = Color(1, 1, 1, 0.4)


# Called from main.gd right before firing a bullet. Returns false (and fires
# nothing) if you're out of ammo.
func spend_ammo() -> bool:
	if ammo <= 0:
		return false
	ammo -= 1
	ammo_changed.emit(ammo)
	return true


# Called by an ammo pickup on contact.
func add_ammo(amount: int) -> void:
	ammo = min(ammo + amount, MAX_AMMO)
	ammo_changed.emit(ammo)


# Called by a health pickup on contact.
func heal(amount: float) -> void:
	if not alive:
		return
	health = min(health + amount, MAX_HEALTH)
	health_changed.emit(health)
