#version 450

layout(location = 0) out vec4 frag_color;
layout(location = 0) uniform vec2 resolution;
layout(location = 1) uniform float time;

const float kGoldenAngle = 2.39996322973;
const int kFrostTaps = 16;
const float kFrostReach = 2.07846096908;

const float kBevel = 30.0;
const float kRefraction = 72.0;
const float kDispersion = 1.6;
const float kSaturation = 1.06;
const float kBrightness = 1.01;
const float kRim = 0.82;
const vec4 kTint = vec4(0.985, 0.992, 1.0, 0.045);
const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);
// Measured on iOS 27 by the FlClash pane: the dark line's width, the most it
// takes off a channel, and the highlight's tail.
const float kLine = 0.67;
const float kLineCap = 0.298;
const float kRimTail = 4.5;
const float kEndShade = 3.0;

float blob(vec2 p, vec2 center, float radius) {
  vec2 offset = (p - center) / max(radius, 1.0);
  return exp(-dot(offset, offset));
}

vec3 wallpaper(vec2 p) {
  vec2 size = max(resolution, vec2(1.0));
  vec2 uv = p / size;
  vec2 center = size * 0.5;
  float unit = min(size.x, size.y);
  float t = time;

  vec3 color = mix(
    vec3(0.52, 0.72, 1.00),
    vec3(1.00, 0.55, 0.66),
    clamp(uv.x * 0.65 + (1.0 - uv.y) * 0.35, 0.0, 1.0)
  );
  color = mix(color, vec3(0.975, 0.980, 0.990), 0.06);

  // A soft mesh gradient: four saturated fields drifting on their own orbits.
  // No edges, so the glass, not the wallpaper, carries structure. The speeds
  // keep a couple of seconds of motion visible.
  vec2 blueCenter = center + vec2(
    cos(t * 0.95),
    sin(t * 0.82 + 1.1)
  ) * unit * 0.34;
  vec2 cyanCenter = center + vec2(
    cos(t * 1.25 + 2.4),
    sin(t * 1.05 + 3.8)
  ) * unit * 0.30;
  vec2 violetCenter = center + vec2(
    cos(t * 0.88 + 4.1),
    sin(t * 1.35 + 2.2)
  ) * unit * 0.32;
  vec2 coralCenter = center + vec2(
    cos(t * 1.45 + 5.5),
    sin(t * 1.15 + 0.4)
  ) * unit * 0.28;

  float blue = blob(p, blueCenter, unit * 0.42 * (1.0 + 0.14 * sin(t * 0.90)));
  float cyan = blob(p, cyanCenter, unit * 0.38 * (1.0 + 0.14 * sin(t * 1.10 + 1.7)));
  float violet = blob(p, violetCenter, unit * 0.36 * (1.0 + 0.14 * sin(t * 0.82 + 3.1)));
  float coral = blob(p, coralCenter, unit * 0.34 * (1.0 + 0.14 * sin(t * 1.02 + 4.6)));

  // Analogous hues, not red/green/amber: their average stays a saturated
  // periwinkle instead of turning the middle of the wallpaper grey.
  vec3 fields =
      vec3(0.22, 0.52, 1.00) * blue +
      vec3(0.35, 0.78, 1.00) * cyan +
      vec3(0.62, 0.42, 1.00) * violet +
      vec3(1.00, 0.42, 0.58) * coral;
  float weight = blue + cyan + violet + coral;
  vec3 lobes = fields / max(weight, 1e-4);
  float cover = 1.0 - exp(-weight * 1.5);
  color = mix(color, lobes, cover * 0.68);

  // A bright band and a shadow band crossing the centre at different speeds.
  // They are what makes the light under the glass visibly change, not just the
  // hue: the pane's refraction and frost read luminance far better than hue.
  float lightPhase = t * 1.05;
  float light = exp(
    -pow((uv.x * 0.9 + uv.y * 0.5 - 0.5 - 0.34 * sin(lightPhase)) * 3.2, 2.0)
  );
  color += vec3(0.085) * light;

  float shadePhase = t * 0.78 + 2.1;
  float shade = exp(
    -pow((uv.x * 0.7 + uv.y * 0.8 - 0.5 - 0.34 * sin(shadePhase)) * 2.6, 2.0)
  );
  color *= 1.0 - 0.16 * shade;

  float sheen = exp(
    -pow((uv.x * 0.9 + uv.y * 0.5 - 0.55 - 0.20 * sin(t * 0.72)) * 4.0, 2.0)
  );
  color += vec3(0.045, 0.046, 0.048) * sheen;

  float vignette = 1.0 - smoothstep(
    0.45,
    1.05,
    length((uv - 0.5) * vec2(1.3, 1.0))
  );
  color *= 0.972 + 0.028 * vignette;
  return color;
}

// The engine's Gaussian read on a Vogel disc, as the Flutter pane does for the
// frost its capture does not hold.
vec3 frosted(vec2 p, float sigma) {
  float decay = exp(-1.6 / float(kFrostTaps));
  float weight = sqrt(decay);
  float total = weight;
  vec2 turn = vec2(cos(kGoldenAngle), sin(kGoldenAngle));
  vec2 ray = vec2(1.0, 0.0);
  float reach = sigma * kFrostReach;
  float spread = sqrt(0.5 / float(kFrostTaps));
  vec3 sum = wallpaper(p + ray * reach * spread) * weight;
  ray = vec2(ray.x * turn.x - ray.y * turn.y, ray.x * turn.y + ray.y * turn.x);
  for (int i = 1; i < kFrostTaps; i++) {
    spread = sqrt((float(i) + 0.5) / float(kFrostTaps));
    sum += wallpaper(p + ray * reach * spread) * weight;
    total += weight;
    weight *= decay;
    ray = vec2(ray.x * turn.x - ray.y * turn.y, ray.x * turn.y + ray.y * turn.x);
  }
  return sum / total;
}

float roundedBoxDistance(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 roundedBoxNormal(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  vec2 n = q.x > 0.0 && q.y > 0.0
      ? normalize(q)
      : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
  return n * vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
}

void main() {
  vec2 size = max(resolution, vec2(1.0));
  vec2 point = gl_FragCoord.xy;
  vec2 center = size * 0.5;
  float unit = min(size.x, size.y);
  vec2 halfSize = vec2(unit * 0.34, unit * 0.20);
  float radius = halfSize.y;
  vec2 local = point - center;

  float distance = roundedBoxDistance(local, halfSize, radius);
  float inset = max(-distance, 0.0);
  float coverage = 1.0 - smoothstep(-1.0, 1.0, distance);

  vec3 color = wallpaper(point);

  float shadow = exp(-max(distance, 0.0) / (unit * 0.035));
  color *= 1.0 - 0.16 * shadow * step(0.0, distance);

  vec2 normal = roundedBoxNormal(local, halfSize, radius);
  float rise = 1.0 - clamp(inset / kBevel, 0.0, 1.0);
  float depth = min(kRefraction, min(halfSize.x, halfSize.y))
      * (1.0 - sqrt(max(1.0 - rise * rise, 0.0)));
  vec2 shift = -normal * depth;

  if (distance < 1.5) {
    // Clear through the middle, frosted where the bevel starts: a wide, even
    // blur is what made the pane read as tinted plastic.
    float frost = 0.7 + 6.0 * rise * rise * rise;
    vec3 glass = frosted(point + shift, frost);

    if (kDispersion > 0.0 && inset < 7.0) {
      vec2 part = normal.yx * 0.5 * kDispersion
          * (0.6 + 0.4 * abs(normal.y) * max(1.0 - inset / 6.0, 0.0))
          * (1.0 - smoothstep(6.0, 7.0, inset));
      vec3 red = frosted(point + shift + part, frost);
      vec3 blue = frosted(point + shift - part, frost);
      glass = vec3(red.r, glass.g, blue.b);
    }

    glass = mix(vec3(dot(glass, kLuma)), glass, kSaturation) * kBrightness;
    glass = mix(glass, kTint.rgb, kTint.a);

    // A bright line just inside a dark outline, both about a pixel wide, with
    // a short tail. A broad gradient reads as tinted plastic.
    float within = max(inset - kLine, 0.0);
    float facing = normal.y * normal.y;
    float band = 1.0 - clamp(within / 1.3, 0.0, 1.0);
    float tail = 1.0 - clamp(within / kRimTail, 0.0, 1.0);
    float shine = min(kRim * facing * mix(band, tail, 0.35), 1.0);
    glass += (vec3(1.0) - glass) * shine;

    glass *= 1.0 - 0.10 * abs(normal.x) * exp(-inset / kEndShade);

    float lower = clamp(normal.y, 0.0, 1.0)
        * (1.0 - smoothstep(0.0, kBevel, inset));
    glass *= 1.0 - 0.06 * lower;

    color = mix(color, glass, coverage);
  }

  float hairline = 1.0 - smoothstep(0.0, kLine + 0.5, abs(distance + 0.33));
  float across = abs(normal.x);
  float darken = mix(0.55, 0.32, across * across * across);
  color = mix(color, color * (1.0 - darken * kLineCap), hairline);

  frag_color = vec4(color, 1.0);
}
