extends RefCounted
class_name PurpleStars

## Utility helper to spawn radiant purple star particle bursts from chests and defeated minions.

static var _star_texture: Texture2D = null

static func get_star_texture() -> Texture2D:
	if _star_texture == null:
		if ResourceLoader.exists("res://assets/candy_crusade/ui/star_candy.png"):
			_star_texture = load("res://assets/candy_crusade/ui/star_candy.png")
		elif ResourceLoader.exists("res://assets/candy_crusade/ui/star_candy.jpg"):
			_star_texture = load("res://assets/candy_crusade/ui/star_candy.jpg")
	return _star_texture


static func spawn_burst(pos: Vector3, tree: SceneTree, count: int = 10, scale_factor: float = 1.0) -> void:
	if tree == null or tree.current_scene == null:
		return
		
	var burst := CPUParticles3D.new()
	burst.name = "PurpleStarBurst"
	burst.amount = count
	burst.lifetime = 0.65
	burst.one_shot = true
	burst.explosiveness = 0.92
	
	var qm := QuadMesh.new()
	qm.size = Vector2(0.15 * scale_factor, 0.15 * scale_factor)
	burst.mesh = qm
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.88, 0.35, 1.0, 0.95)
	
	var tex := get_star_texture()
	if tex != null:
		mat.albedo_texture = tex
	burst.material_override = mat
	
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 1.2 * scale_factor
	burst.initial_velocity_max = 2.8 * scale_factor
	burst.gravity = Vector3(0, -1.8, 0)
	burst.angular_velocity_min = -180.0
	burst.angular_velocity_max = 180.0
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.3
	
	tree.current_scene.add_child(burst)
	burst.global_position = pos
	tree.create_timer(0.8).timeout.connect(burst.queue_free)
