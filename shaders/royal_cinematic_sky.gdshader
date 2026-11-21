shader_type sky;

uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform float sun_height : hint_range(-1.0, 1.0) = 0.5;
uniform vec3 sun_direction = vec3(-0.28, 0.30, -0.91);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float cloud_noise(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise2(p) * amplitude;
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float height = clamp(dir.y * 0.5 + 0.5, 0.0, 1.0);
	float twilight = 1.0 - smoothstep(0.02, 0.42, abs(sun_height));

	vec3 night_zenith = vec3(0.006, 0.014, 0.045);
	vec3 night_horizon = vec3(0.035, 0.065, 0.12);
	vec3 day_zenith = vec3(0.035, 0.16, 0.36);
	vec3 day_upper = vec3(0.10, 0.34, 0.57);
	vec3 day_horizon = vec3(0.48, 0.62, 0.69);
	vec3 sky_color = mix(night_horizon, day_horizon, daylight);
	sky_color = mix(sky_color, mix(night_zenith, day_upper, daylight), smoothstep(0.02, 0.42, height));
	sky_color = mix(sky_color, mix(night_zenith * 0.72, day_zenith, daylight), smoothstep(0.38, 0.95, height));

	float horizon_glow = exp(-abs(dir.y) * 8.0);
	vec3 sunset_color = vec3(0.95, 0.34, 0.16);
	sky_color = mix(sky_color, sunset_color, horizon_glow * twilight * 0.72);

	// Procedural cloud banks stay inexpensive for mobile GPUs.
	vec2 cloud_uv = dir.xz / max(dir.y + 0.42, 0.18);
	cloud_uv = cloud_uv * 2.15 + vec2(0.0, TIME * 0.003);
	float clouds = cloud_noise(cloud_uv);
	float cloud_mask = smoothstep(0.49, 0.69, clouds) * smoothstep(-0.10, 0.10, dir.y);
	vec3 day_cloud = mix(vec3(0.72, 0.62, 0.55), vec3(1.0, 0.83, 0.63), smoothstep(0.40, 0.80, dir.y));
	vec3 night_cloud = vec3(0.045, 0.065, 0.11);
	vec3 cloud_color = mix(night_cloud, day_cloud, daylight);
	cloud_color = mix(cloud_color, vec3(0.88, 0.34, 0.22), twilight * 0.48);
	sky_color = mix(sky_color, cloud_color, cloud_mask * 0.72);

	// The sun follows the same automatic cycle as the directional city light.
	float sun_dot = dot(dir, normalize(sun_direction));
	float sun_visibility = smoothstep(-0.08, 0.08, sun_height);
	float sun_halo = smoothstep(0.90, 0.997, sun_dot) * sun_visibility;
	float sun_disc = smoothstep(0.9990, 0.99955, sun_dot) * sun_visibility;
	sky_color += mix(vec3(1.0, 0.28, 0.10), vec3(1.0, 0.48, 0.16), daylight) * sun_halo * 0.42;
	sky_color = mix(sky_color, vec3(1.0, 0.88, 0.66), sun_disc);

	// A soft moon and procedural stars appear automatically after sunset.
	vec3 moon_direction = -normalize(sun_direction);
	float moon_dot = dot(dir, moon_direction);
	float moon_halo = smoothstep(0.94, 0.999, moon_dot) * (1.0 - daylight);
	float moon_disc = smoothstep(0.99925, 0.99972, moon_dot) * (1.0 - daylight);
	sky_color += vec3(0.36, 0.48, 0.72) * moon_halo * 0.16;
	sky_color = mix(sky_color, vec3(0.78, 0.84, 1.0), moon_disc);

	vec2 star_uv = vec2(atan(dir.x, dir.z), asin(clamp(dir.y, -1.0, 1.0)));
	vec2 star_grid = star_uv * vec2(58.0, 30.0);
	vec2 star_cell = floor(star_grid);
	vec2 star_position = vec2(hash21(star_cell + vec2(3.1, 7.7)), hash21(star_cell + vec2(9.2, 2.4)));
	float star_seed = hash21(star_cell + vec2(21.7, 4.3));
	float star_distance = length(fract(star_grid) - star_position);
	float star_shape = 1.0 - smoothstep(0.018, 0.075, star_distance);
	float stars = star_shape * step(0.982, star_seed) * (1.0 - daylight);
	sky_color += vec3(0.62, 0.73, 1.0) * stars * 0.82;

	COLOR = sky_color;
}
