shader_type spatial;
// 찌 주변에 퍼지는 물결 링. 스크립트가 크기(scale)와 fade를 트윈한다.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ring_color : source_color = vec4(0.92, 0.96, 1.0, 1.0);

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float ring = smoothstep(0.70, 0.86, r) * (1.0 - smoothstep(0.90, 1.0, r));
	ALBEDO = ring_color.rgb;
	ALPHA = ring * fade * 0.7;
}
