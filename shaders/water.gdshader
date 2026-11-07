shader_type spatial;
// 호수 수면. gl_compatibility에서 되는 기능만 쓴다 (화면/깊이 텍스처 없음).
// 정점 물결 + 시선 각도에 따른 색 변화(가까운 데는 맑고, 먼 데는 하늘을 반사해 밝게).
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 deep_color : source_color = vec4(0.09, 0.24, 0.30, 0.94);
uniform vec4 shallow_color : source_color = vec4(0.20, 0.42, 0.46, 0.88);
uniform vec4 sky_tint : source_color = vec4(0.55, 0.66, 0.76, 1.0);
// 하늘 반사 세기. 높으면 수면이 하얗게 번쩍인다.
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.45;
uniform float wave_height = 0.018;
uniform float wave_speed = 0.7;
uniform float wave_scale = 0.9;

varying float v_wave;

void vertex() {
	float t = TIME * wave_speed;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * wave_scale;
	float a = sin(w.x * 1.3 + t) * 0.6 + sin(w.z * 1.7 - t * 1.2) * 0.4;
	float b = sin((w.x + w.z) * 2.3 + t * 1.7) * 0.25;
	v_wave = a + b;
	VERTEX.y += v_wave * wave_height;
	// 물결 기울기로 법선을 흔든다 (반사광이 일렁이게).
	NORMAL = normalize(vec3(-cos(w.x * 1.3 + t) * 0.06, 1.0, -cos(w.z * 1.7 - t * 1.2) * 0.05));
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 4.0);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, 0.35 + 0.15 * v_wave);
	ALBEDO = mix(base, sky_tint.rgb, fresnel * sky_reflect);
	ALPHA = mix(deep_color.a, 1.0, fresnel);
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
