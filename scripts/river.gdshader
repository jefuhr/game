shader_type spatial;
render_mode cull_disabled;

varying vec3 river_position;

void vertex() {
	river_position = VERTEX;
}

void fragment() {
	float swell = sin(river_position.x * 0.3 + river_position.z * 0.7 + TIME * 0.65);
	float ripple = sin(river_position.z * 3.3 + sin(river_position.x * 0.5 + TIME) * 1.6 + TIME * 1.4);
	float glint = pow(max(0.0, swell * ripple), 10.0);
	ALBEDO = mix(vec3(0.12, 0.34, 0.39), vec3(0.27, 0.52, 0.54), swell * 0.18 + 0.45);
	ALBEDO += vec3(0.28, 0.24, 0.15) * glint * 0.5;
	ROUGHNESS = 0.48;
	SPECULAR = 0.35;
}
