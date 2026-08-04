extends MultiMeshInstance2D
class_name ParticleFluidRenderer2D

@export var particle_diameter_pixels: float = 16.0

var _mesh: QuadMesh

func _ready() -> void:
	_ensure_resources()

func update_snapshot(snapshot: ParticleFluidSnapshot2D, pixels_per_meter: float) -> void:
	_ensure_resources()
	if snapshot == null:
		multimesh.instance_count = 0
		return
	multimesh.instance_count = snapshot.count()
	for index: int in range(snapshot.count()):
		var position_pixels := snapshot.positions_meters[index] * pixels_per_meter
		multimesh.set_instance_transform_2d(index, Transform2D(0.0, position_pixels))
		multimesh.set_instance_color(index, snapshot.display_colors_srgb[index])

func _ensure_resources() -> void:
	if multimesh != null:
		return
	_mesh = QuadMesh.new()
	_mesh.size = Vector2.ONE * particle_diameter_pixels
	var particle_multimesh := MultiMesh.new()
	particle_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	particle_multimesh.use_colors = true
	particle_multimesh.mesh = _mesh
	multimesh = particle_multimesh
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float edge = 1.0 - smoothstep(0.72, 1.0, length(p));
	COLOR = COLOR * vec4(1.0, 1.0, 1.0, edge);
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
