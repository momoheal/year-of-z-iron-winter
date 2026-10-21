shader_type canvas_item;
// SHD_VisionFog_90Deg: Aleksei's 90-degree directional sightcone,
// 1.8m close-awareness halo, cracked right eyeglass refraction,
// and high-grain monochrome Soviet newsprint fog outside the cone.

uniform vec2 player_screen_uv = vec2(0.5, 0.5);
uniform vec2 aim_direction = vec2(1.0, 0.0);
uniform float cone_half_angle_deg : hint_range(15.0, 90.0) = 45.0;
uniform float vision_radius_uv : hint_range(0.05, 0.8) = 0.36;
uniform float close_halo_uv : hint_range(0.01, 0.2) = 0.055;
uniform bool glasses_cracked = false;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_pixel = uv - player_screen_uv;
	float dist = length(to_pixel);
	vec2 dir = normalize(to_pixel + vec2(0.0001));

	float effective_radius = glasses_cracked ? (vision_radius_uv * 0.6) : vision_radius_uv;
	if (glasses_cracked && dir.x > 0.0) {
		uv += vec2(0.0035, -0.002) * sin(dist * 45.0);
	}

	vec4 scene_col = texture(SCREEN_TEXTURE, uv);
	float cos_angle = dot(dir, normalize(aim_direction));
	float cos_threshold = cos(radians(cone_half_angle_deg));

	bool in_cone = (dist <= effective_radius && cos_angle >= cos_threshold) || (dist <= close_halo_uv);

	if (in_cone) {
		float edge_fade = smoothstep(effective_radius, effective_radius * 0.82, dist);
		COLOR = vec4(scene_col.rgb * mix(0.45, 1.0, edge_fade), 1.0);
	}} else {{
		float luma = dot(scene_col.rgb, vec3(0.299, 0.587, 0.114));
		float grain = (hash(uv * TIME * 60.0) - 0.5) * 0.12;
		vec3 newsprint_fog = vec3(luma * 0.32 + grain) * vec3(0.82, 0.88, 0.95);
		COLOR = vec4(newsprint_fog, 1.0);
	}
}
