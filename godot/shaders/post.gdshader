// Film grain + vignette (+ heartbeat as the meter climbs). Same numbers as the HTML version.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float heartbeat = 0.0;   // 0..1 extra vignette
uniform float seed = 0.0;        // changes every frame so the grain crawls

float rand(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec2 px = (SCREEN_UV - 0.5) * vec2(960.0, 540.0);
	float vig = 0.75 * clamp((length(px) - 189.0) / (595.0 - 189.0), 0.0, 1.0);
	vig = 1.0 - (1.0 - vig) * (1.0 - vig * heartbeat);
	float g = rand(floor(SCREEN_UV * vec2(960.0, 540.0)) + seed);
	col = mix(col, vec3(g), 0.06);
	COLOR = vec4(col * (1.0 - vig), 1.0);
}
