shader_type canvas_item;
render_mode unshaded;

// Lightweight mobile water shader: two sine waves, no texture reads,
// branching loops or framebuffer access. The overlay is hidden in menus.
uniform float river_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 0.48;
uniform vec4 highlight_color : source_color = vec4(0.76, 0.97, 0.94, 1.0);

void fragment() {
	vec2 p = UV;
	float y_mask = smoothstep(0.19, 0.25, p.y) * (1.0 - smoothstep(0.73, 0.79, p.y));
	float x_mask = smoothstep(0.13, 0.22, p.x) * (1.0 - smoothstep(0.78, 0.87, p.x));
	float bank = sin(p.y * 29.0 + river_time * 0.3) * 0.012;
	float river_mask = smoothstep(0.0, 0.06, x_mask + bank);
	float wave_a = sin(p.y * 95.0 - river_time * 2.1 + sin(p.x * 21.0) * 1.3);
	float wave_b = sin(p.x * 47.0 + p.y * 55.0 + river_time * 1.35);
	float crest = pow(max(0.0, wave_a * 0.5 + wave_b * 0.5), 3.0);
	float alpha = clamp(crest * 0.11 * strength * y_mask * river_mask, 0.0, 0.085);
	COLOR = vec4(highlight_color.rgb, alpha);
}
