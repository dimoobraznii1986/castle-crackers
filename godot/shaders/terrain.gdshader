// Paints the ground from a mask texture.
// Red channel = ground (1) or air (0). Green channel = burn marks from explosions.
// The colors come from the map theme (scripts/themes.gd).
shader_type canvas_item;

uniform vec3 edge_col = vec3(0.12, 0.36, 0.09);
uniform vec3 grass_col = vec3(0.36, 0.72, 0.2);
uniform vec3 root_col = vec3(0.23, 0.35, 0.13);
uniform vec3 soil_dark = vec3(0.4, 0.25, 0.14);
uniform vec3 soil_light = vec3(0.62, 0.4, 0.24);
uniform vec3 stone_col = vec3(0.24, 0.16, 0.1);
uniform vec3 stone_hi = vec3(0.78, 0.66, 0.5);
uniform vec3 outline_col = vec3(0.2, 0.12, 0.06);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.r < 0.5) {
		discard;
	}
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV / ps);

	// how deep is this pixel under the surface?
	float since = 99.0;
	for (int k = 1; k <= 16; k++) {
		if (texture(TEXTURE, UV - vec2(0.0, float(k)) * ps).r < 0.5) {
			since = float(k);
			break;
		}
	}
	bool edge = texture(TEXTURE, UV + vec2(ps.x * 2.0, 0.0)).r < 0.5
		|| texture(TEXTURE, UV - vec2(ps.x * 2.0, 0.0)).r < 0.5
		|| texture(TEXTURE, UV + vec2(0.0, ps.y * 2.0)).r < 0.5;

	float grain = hash(px) * 0.06 - 0.03;
	vec3 col;
	if (since <= 3.0) {
		col = edge_col;                                             // top edge
	} else if (since <= 12.0) {
		float n = vnoise(px / 3.0) * 0.13;
		col = grass_col + vec3(n * 0.5, n, 0.0) - 0.05 + grain;    // grass / snow / sand
	} else if (since <= 15.0) {
		col = root_col;
	} else {
		float n = vnoise(px / vec2(22.0, 14.0));
		float n2 = vnoise(px / 6.0 + 40.0);
		float band = 0.5 + 0.5 * sin(px.y * 0.045 + n * 5.0);
		col = mix(soil_dark, soil_light, 0.55 * band + 0.45 * n2) + grain;  // soil layers
		float peb = vnoise(px / 7.0 + 13.0);
		if (peb > 0.8) {
			col = mix(col, stone_col, 0.6);                         // stones
		} else if (peb > 0.76) {
			col = mix(col, stone_hi, 0.35);
		}
		if (edge) {
			col = mix(col, outline_col, 0.75);                      // cartoon outline
		}
	}
	col = mix(col, vec3(0.16, 0.10, 0.05), m.g * 0.6);             // burn marks
	COLOR = vec4(col, 1.0);
}
