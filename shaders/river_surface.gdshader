shader_type canvas_item;
render_mode unshaded;

// Three low-cost, texture-free water layers. The draw surface is restricted
// to the actual river width, avoiding full-screen fragment overdraw on phones.
// No framebuffer sampling, branching texture fetches, or dependent loops.
uniform float strength : hint_range(0.0, 1.0) = 0.48;
uniform vec4 highlight_color : source_color = vec4(0.76, 0.97, 0.94, 1.0);
uniform float current_speed : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec2 p = UV;
	float t = TIME * current_speed;
	// Fade before the water reaches the horizon / bottom UI area.
	float vertical = smoothstep(0.07, 0.19, p.y) * (1.0 - smoothstep(0.81, 0.94, p.y));
	// Soft banks inside the cropped river rect, with slow organic breathing.
	float bank_wobble = sin(p.y * 17.0 + t * 0.27) * 0.012;
	float banks = smoothstep(0.01, 0.10, p.x + bank_wobble) *
		(1.0 - smoothstep(0.90, 0.99, p.x + bank_wobble));
	// Two traveling waves and a very faint slow parallax drift.
	float wave_a = sin(p.y * 91.0 - t * 2.05 + sin(p.x * 15.0) * 1.1);
	float wave_b = sin(p.x * 43.0 + p.y * 53.0 + t * 1.2);
	float drift = sin(p.y * 17.0 + p.x * 9.0 - t * 0.42);
	float crest = max(0.0, wave_a * 0.48 + wave_b * 0.44 + drift * 0.08);
	// Cubic sharpening avoids expensive pow() on mobile GPUs.
	float highlight = crest * crest * crest;
	float alpha = min(highlight * 0.15 * strength * vertical * banks, 0.10);
	COLOR = vec4(highlight_color.rgb, alpha);
}
