#version 450

layout(location = 0) out vec4 frag_color;

layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform float time;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float n000 = hash13(cell + vec3(0.0, 0.0, 0.0));
    float n100 = hash13(cell + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(cell + vec3(0.0, 1.0, 0.0));
    float n110 = hash13(cell + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(cell + vec3(0.0, 0.0, 1.0));
    float n101 = hash13(cell + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(cell + vec3(0.0, 1.0, 1.0));
    float n111 = hash13(cell + vec3(1.0, 1.0, 1.0));

    float near_z = mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y);
    float far_z = mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y);
    return mix(near_z, far_z, f.z);
}

float fbm3(vec3 p) {
    float sum = 0.0;
    float weight = 0.52;
    mat3 turn = mat3(
        0.00, 0.80, 0.60,
       -0.80, 0.36, -0.48,
       -0.60, -0.48, 0.64
    );

    for (int octave = 0; octave < 5; octave++) {
        sum += value_noise(p) * weight;
        p = turn * p * 2.03 + vec3(3.1, 7.7, 1.9);
        weight *= 0.49;
    }
    return sum;
}

mat3 rotate_y(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(c, 0.0, -s, 0.0, 1.0, 0.0, s, 0.0, c);
}

vec2 sphere_hit(vec3 ray_origin, vec3 ray_direction, vec3 center, float radius) {
    vec3 offset = ray_origin - center;
    float projected = dot(offset, ray_direction);
    float discriminant = projected * projected - dot(offset, offset) + radius * radius;
    if (discriminant < 0.0) return vec2(-1.0);
    float root = sqrt(discriminant);
    return vec2(-projected - root, -projected + root);
}

float terrain(vec3 normal, float rotation) {
    vec3 sample_position = rotate_y(rotation) * normal;
    vec3 warp = vec3(
        fbm3(sample_position * 1.35 + vec3(2.7, 0.0, 0.0)),
        fbm3(sample_position * 1.35 + vec3(0.0, 5.1, 0.0)),
        fbm3(sample_position * 1.35 + vec3(0.0, 0.0, 8.4))
    );
    return fbm3(sample_position * 3.1 + (warp - 0.5) * 1.45);
}

vec3 planet_surface(vec3 normal, vec3 view_direction, float rotation) {
    float height = terrain(normal, rotation);
    float fine_detail = value_noise(rotate_y(rotation) * normal * 24.0);

    vec3 deep = vec3(0.025, 0.055, 0.090);
    vec3 ocean = vec3(0.035, 0.155, 0.205);
    vec3 mineral = vec3(0.62, 0.245, 0.095);
    vec3 highland = vec3(0.93, 0.665, 0.285);

    float shore = smoothstep(0.47, 0.535, height);
    vec3 albedo = mix(mix(deep, ocean, smoothstep(0.20, 0.50, height)), mineral, shore);
    albedo = mix(albedo, highland, smoothstep(0.64, 0.82, height));
    albedo *= 0.88 + fine_detail * 0.18;

    vec3 rotated_normal = rotate_y(rotation) * normal;
    vec3 relief = vec3(
        value_noise(rotated_normal * 18.0 + vec3(3.2, 0.0, 0.0)),
        value_noise(rotated_normal * 18.0 + vec3(0.0, 7.4, 0.0)),
        value_noise(rotated_normal * 18.0 + vec3(0.0, 0.0, 11.7))
    ) - 0.5;
    vec3 detailed_normal = normalize(normal + relief * 0.13 * smoothstep(0.42, 0.66, height));

    vec3 light_direction = normalize(vec3(-0.72, 0.48, 0.62));
    vec3 half_direction = normalize(light_direction + view_direction);
    float diffuse = max(dot(detailed_normal, light_direction), 0.0);
    float specular = pow(max(dot(detailed_normal, half_direction), 0.0), 46.0);
    float fresnel = pow(1.0 - max(dot(normal, view_direction), 0.0), 3.2);

    vec3 color = albedo * (diffuse * 0.82 + 0.08);
    color += vec3(1.0, 0.73, 0.40) * specular * 0.42;
    color += vec3(0.08, 0.62, 0.78) * fresnel * 0.52;

    float night = 1.0 - smoothstep(-0.22, 0.03, dot(normal, light_direction));
    float city_seed = value_noise(rotate_y(rotation) * normal * 48.0);
    float cities = smoothstep(0.83, 0.92, city_seed) * smoothstep(0.50, 0.62, height) * night;
    color += vec3(1.0, 0.42, 0.12) * cities * 1.25;
    return color;
}

vec3 star_field(vec2 pixel, vec2 uv, float seconds) {
    vec2 cell = floor(pixel / 34.0);
    vec2 point = fract(pixel / 34.0) - 0.5;
    float seed = hash12(cell);
    vec2 offset = vec2(hash12(cell + 19.7), hash12(cell + 73.1)) - 0.5;
    float radius = length(point - offset * 0.72);
    float star = (1.0 - smoothstep(0.012, 0.055, radius)) * step(0.875, seed);
    float pulse = 0.62 + 0.38 * sin(seconds * (0.45 + seed) + seed * 31.0);

    vec3 tint = mix(vec3(0.42, 0.64, 0.82), vec3(1.0, 0.67, 0.38), hash12(cell + 4.2));
    vec3 result = tint * star * pulse;
    float dust = value_noise(vec3(uv * vec2(3.0, 2.0), 2.4));
    result += vec3(0.07, 0.10, 0.16) * smoothstep(0.63, 0.88, dust) * 0.45;
    return result;
}

void main() {
    vec2 safe_resolution = max(resolution, vec2(1.0));
    vec2 uv = gl_FragCoord.xy / safe_resolution;
    vec2 p = (gl_FragCoord.xy * 2.0 - safe_resolution) / safe_resolution.y;
    float rotation = time * 0.055;

    vec3 color = mix(vec3(0.004, 0.007, 0.018), vec3(0.015, 0.020, 0.044), uv.y);
    color += star_field(gl_FragCoord.xy, uv, time);

    vec3 center = vec3(0.18, -0.06, 0.0);
    vec3 ray_origin = center + vec3(-0.72, 1.55, 3.25);
    vec3 camera_forward = normalize(center - ray_origin);
    vec3 camera_right = normalize(cross(camera_forward, vec3(0.0, 1.0, 0.0)));
    vec3 camera_up = cross(camera_right, camera_forward);
    vec3 ray_direction = normalize(camera_forward * 2.18 + camera_right * p.x - camera_up * p.y);
    float radius = 0.88;
    vec2 hit = sphere_hit(ray_origin, ray_direction, center, radius);

    vec2 star_position = vec2(-0.93, 0.54);
    float star_distance = length(p - star_position);
    float sun_disc = 1.0 - smoothstep(0.045, 0.053, star_distance);
    float sun_halo = 0.014 / max(star_distance * star_distance, 0.012);
    color += vec3(1.0, 0.38, 0.12) * sun_halo * 0.11;
    color = mix(color, vec3(1.0, 0.72, 0.34), sun_disc);

    vec3 ring_normal = normalize(vec3(0.06, 0.997, 0.02));
    float plane_denominator = dot(ray_direction, ring_normal);
    float plane_distance = dot(center - ray_origin, ring_normal) / plane_denominator;
    vec3 ring_point = ray_origin + ray_direction * plane_distance - center;
    float ring_radius = length(ring_point);
    float ring_band = smoothstep(1.06, 1.11, ring_radius) * (1.0 - smoothstep(1.37, 1.43, ring_radius));
    float ring_lines = 0.10 + 0.90 * smoothstep(0.75, 0.96, sin(ring_radius * 112.0) * 0.5 + 0.5);
    float ring_visible = step(0.0, plane_distance) * ring_band;
    float ring_opacity = ring_visible * (0.14 + ring_lines * 0.46);
    vec3 ring_color = mix(vec3(0.18, 0.34, 0.42), vec3(0.92, 0.49, 0.22), ring_lines);
    if (hit.x < 0.0) color = mix(color, ring_color, ring_opacity);

    if (hit.x > 0.0) {
        vec3 position = ray_origin + ray_direction * hit.x;
        vec3 normal = normalize(position - center);
        color = planet_surface(normal, normalize(ray_origin - position), rotation);
        float ring_in_front = step(plane_distance, hit.x);
        color = mix(color, ring_color, ring_opacity * ring_in_front);
    }

    vec3 offset = ray_origin - center;
    float along_ray = max(-dot(offset, ray_direction), 0.0);
    float closest_distance = length(offset + ray_direction * along_ray);
    float atmosphere = exp(-max(closest_distance - radius, 0.0) * 24.0);
    atmosphere *= 1.0 - smoothstep(radius, radius + 0.15, closest_distance);
    if (hit.x > 0.0) atmosphere *= 0.32;
    vec3 limb_normal = normalize(ray_origin + ray_direction * along_ray - center);
    float facing_light = 0.42 + 0.58 * max(dot(limb_normal, normalize(vec3(-0.72, 0.48, 0.62))), 0.0);
    color += vec3(0.06, 0.48, 0.72) * atmosphere * facing_light * 0.72;

    float vignette = 1.0 - smoothstep(0.52, 1.58, length(p * vec2(0.72, 1.0)));
    color *= 0.68 + vignette * 0.42;
    color = color / (color + vec3(0.88));
    color = pow(max(color, vec3(0.0)), vec3(0.86));

    float grain = hash12(gl_FragCoord.xy + fract(time) * 113.0) - 0.5;
    color += grain * 0.012;
    frag_color = vec4(color, 1.0);
}
