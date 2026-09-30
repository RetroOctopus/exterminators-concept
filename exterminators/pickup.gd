extends Area2D
# A dropped pickup: an ammo refill (green, the same look as your bullets) or a
# health pack (the red variant). Roaches roll a chance to drop one when they
# die — see roach.gd's AMMO_DROP_CHANCE / HEALTH_DROP_CHANCE — and main.gd
# spawns whichever kind it rolled at the roach's death position.

const AMMO_RESTORE := 30.0
const HEALTH_RESTORE := 30.0

var kind := "ammo"   # "ammo" or "health", set by main.gd right after instantiating

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	if kind == "health":
		sprite.modulate = Color(1.0, 0.2, 0.2)   # red variant, same art as the ammo drop


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("player"):
		return
	if kind == "ammo":
		area.add_ammo(AMMO_RESTORE)
	else:
		area.heal(HEALTH_RESTORE)
	call_deferred("queue_free")
