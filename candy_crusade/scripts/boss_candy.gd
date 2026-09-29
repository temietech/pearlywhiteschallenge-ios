extends CharacterBody3D
class_name BossCandy

const FLIGHT_TIME := 1.35

var _start := Vector3.ZERO
var _end := Vector3.ZERO
var _elapsed := 0.0
var _arc_height := 2.0
var _popped := false


func _ready() -> void:
	add_to_group("boss_candies")


func launch(start: Vector3, target: Vector3, arc_height: float) -> void:
	_start = start
	_end = target
	global_position = start
	_arc_height = arc_height
	scale = Vector3.ONE


func _physics_process(delta: float) -> void:
	if _popped:
		return
	_elapsed += delta
	var t := clampf(_elapsed / FLIGHT_TIME, 0.0, 1.0)
	global_position = _start.lerp(_end, t)
	global_position.y += sin(t * PI) * _arc_height
	rotation += Vector3(5.0, 8.0, 2.0) * delta

	# Swell dynamically as it flies straight into the camera screen
	var growth := lerpf(1.0, 3.4, t * t)
	scale = Vector3.ONE * growth

	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("has_active_shield") and player.has_active_shield():
		var shield_z := -1.6
		if player.has_method("get_shield_z"):
			shield_z = player.get_shield_z()
		if global_position.z >= shield_z:
			if player.has_method("take_candy_hit"):
				player.take_candy_hit()
			pop(true)
			return

	if t >= 1.0:
		if player and player.has_method("take_candy_hit"):
			player.take_candy_hit()
		pop(true)


func pop(on_screen_impact: bool = false) -> void:
	if _popped:
		return
	_popped = true
	var burst := CPUParticles3D.new()
	burst.amount = 28 if on_screen_impact else 20
	burst.lifetime = 0.55
	burst.one_shot = true
	burst.explosiveness = 0.95
	var sm := SphereMesh.new()
	var sz_multiplier: float = maxf(1.0, scale.x * 0.7)
	sm.radius = 0.035 * sz_multiplier
	sm.height = sm.radius * 2.0
	burst.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.3, 0.65) if on_screen_impact else Color(1.0, 0.4, 0.8)
	burst.material_override = mat
	burst.gravity = Vector3(0, -9.8, 0)
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.10 * sz_multiplier
	burst.direction = Vector3.UP
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 5.0
	var p := get_parent()
	if p != null:
		p.add_child(burst)
		burst.global_position = global_position
		get_tree().create_timer(1.0).timeout.connect(burst.queue_free)
	queue_free()
