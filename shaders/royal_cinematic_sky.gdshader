shader_type sky;

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

	vec3 zenith = vec3(0.035, 0.16, 0.36);
	vec3 upper_blue = vec3(0.10, 0.34, 0.57);
	vec3 horizon_blue = vec3(0.48, 0.62, 0.69);
	vec3 warm_horizon = vec3(0.95, 0.58, 0.31);
	vec3 sky_color = mix(horizon_blue, upper_blue, smoothstep(0.02, 0.42, height));
	sky_color = mix(sky_color, zenith, smoothstep(0.38, 0.95, height));

	float horizon_glow = exp(-abs(dir.y) * 8.0);
	sky_color = mix(sky_color, warm_horizon, horizon_glow * 0.48);

	// Broad, soft procedural cloud banks; inexpensive 2D noise for mobile GPUs.
	vec2 cloud_uv = dir.xz / max(dir.y + 0.42, 0.18);
	cloud_uv = cloud_uv * 2.15 + vec2(0.0, TIME * 0.003);
	float clouds = cloud_noise(cloud_uv);
	float cloud_mask = smoothstep(0.49, 0.69, clouds) * smoothstep(-0.10, 0.10, dir.y);
	float cloud_light = smoothstep(0.40, 0.80, dir.y);
	vec3 cloud_color = mix(vec3(0.72, 0.62, 0.55), vec3(1.0, 0.83, 0.63), cloud_light);
	sky_color = mix(sky_color, cloud_color, cloud_mask * 0.72);

	// Warm sun disc and a restrained golden atmospheric halo.
	vec3 sun_dir = normalize(vec3(-0.28, 0.30, -0.91));
	float sun_dot = dot(dir, sun_dir);
	float halo = smoothstep(0.90, 0.997, sun_dot);
	float disc = smoothstep(0.9990, 0.99955, sun_dot);
	sky_color += vec3(1.0, 0.48, 0.16) * halo * 0.42;
	sky_color = mix(sky_color, vec3(1.0, 0.88, 0.66), disc);

	COLOR = sky_color;
}
