extends RefCounted
class_name FluidStepResult2D

var snapshot: ParticleFluidSnapshot2D = ParticleFluidSnapshot2D.new()
var particle_count: int = 0
var total_mass: float = 0.0
var average_density_error_ratio: float = 0.0
var maximum_density_error_ratio: float = 0.0
var minimum_density: float = INF
var total_linear_momentum: Vector2 = Vector2.ZERO
var kinetic_energy: float = 0.0
var maximum_speed: float = 0.0
var quiescent_damping_active: bool = false
var substeps: int = 0
var average_neighbor_count: float = 0.0
var applied_external_acceleration: Vector2 = Vector2.ZERO
var active_force_field_count: int = 0
var applied_buoyant_body_count: int = 0
var profile_spatial_hash_microseconds: int = 0
var profile_density_microseconds: int = 0
var profile_forces_microseconds: int = 0
var profile_integration_microseconds: int = 0
var has_non_finite_state: bool = false
var warnings: PackedStringArray = PackedStringArray()
var container_reaction_force: Vector2 = Vector2.ZERO
var container_reaction_torque: float = 0.0
var body_forces: Dictionary = {}
var body_torques: Dictionary = {}
var body_submersion_ratios: Dictionary = {}
