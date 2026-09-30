extends Area2D
# One spray shot.
# Scratch version: the "Small Bullet" sprite, created with "create clone of myself".

const SPEED := 750.0   # pixels per second

var direction := Vector2.RIGHT

# The shoot sound plays from main.gd, not from here — a bullet that hits
# something up close gets freed almost instantly, which would cut its own
# sound off before it finishes.


func _ready() -> void:
	# Scratch: "if touching Roach ... delete this clone". Godot gives us a signal instead.
	area_entered.connect(_on_area_entered)
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta

	# Scratch: "repeat until touching edge, then delete this clone".
	if not get_viewport_rect().grow(40).has_point(position):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("roach") or area.is_in_group("boss"):
		area.hit()
		# call_deferred avoids a physics-engine warning about deleting a node
		# from inside its own collision signal while it's still processing overlaps.
		call_deferred("queue_free")
