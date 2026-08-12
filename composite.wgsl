// Dual-sheep transition composite — samples A/B textures and mixes with
// hex takeover / polar iris / kaleido wedge / additive storm.

struct CompositeUniforms {
  resolution: vec2f,
  progress: f32,   // 0 = all A, 1 = all B
  mode: f32,       // 0 hex, 1 iris, 2 wedge, 3 storm
  time: f32,
  seed: f32,
  mirrors_a: f32,
  mirrors_b: f32,
  // genome morph underneath (0→1 with progress)
  morph: f32,
  _pad0: f32,
  _pad1: f32,
  _pad2: f32,
}

@group(0) @binding(0) var<uniform> u: CompositeUniforms;
@group(0) @binding(1) var samp: sampler;
@group(0) @binding(2) var tex_a: texture_2d<f32>;
@group(0) @binding(3) var tex_b: texture_2d<f32>;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

struct VSOut {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
}

@vertex
fn vs_main(@builtin(vertex_index) vi: u32) -> VSOut {
  var pos = array<vec2f, 3>(
    vec2f(-1.0, -1.0),
    vec2f(3.0, -1.0),
    vec2f(-1.0, 3.0),
  );
  var out: VSOut;
  out.position = vec4f(pos[vi], 0.0, 1.0);
  out.uv = pos[vi] * 0.5 + 0.5;
  return out;
}

fn hash21(p: vec2f) -> f32 {
  return fract(sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453);
}

fn mod1(x: f32, y: f32) -> f32 {
  return x - y * floor(x / y);
}

fn mod2(p: vec2f, s: vec2f) -> vec2f {
  return vec2f(mod1(p.x, s.x), mod1(p.y, s.y));
}

fn sd_hex(p_in: vec2f, r: f32) -> f32 {
  let k = vec3f(-sqrt(3.0) * 0.5, 0.5, sqrt(1.0 / 3.0));
  var p = abs(p_in);
  p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
  p -= vec2f(clamp(p.x, -k.z * r, k.z * r), r);
  return length(p) * sign(p.y);
}

struct HexTile {
  local: vec2f,
  id: vec2f,
}

fn hextile(p_in: vec2f) -> HexTile {
  let sz = vec2f(1.0, sqrt(3.0));
  let hsz = 0.5 * sz;
  let p1 = mod2(p_in, sz) - hsz;
  let p2 = mod2(p_in - hsz, sz) - hsz;
  let p3 = select(p2, p1, dot(p1, p1) < dot(p2, p2));
  var n = (p3 - p_in + hsz) / sz;
  n -= vec2f(0.5);
  var out: HexTile;
  out.local = p3;
  out.id = round(n * 2.0) * 0.5;
  return out;
}

fn smoothstep3(e0: f32, e1: f32, x: f32) -> f32 {
  let t = clamp((x - e0) / (e1 - e0), 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

// Hex cell takeover: stable hash schedule flips A→B cell-by-cell
fn mix_hex(uv: vec2f, p: f32) -> f32 {
  let aspect = u.resolution.x / max(u.resolution.y, 1.0);
  var q = (uv * 2.0 - 1.0) * vec2f(aspect, 1.0);
  q *= 3.2;
  let tile = hextile(q);
  let h = hash21(tile.id + vec2f(u.seed * 3.1, u.seed * 1.7));
  // Soft edge so cells bloom rather than hard-cut
  let edge = sd_hex(tile.local.yx, 0.48);
  let gate = smoothstep3(h - 0.08, h + 0.12, p);
  let soft = smoothstep3(0.08, -0.02, edge);
  return mix(gate * 0.85, gate, soft);
}

// Polar iris / tunnel swallow: A collapses inward while B blooms out
fn mix_iris(uv: vec2f, p: f32) -> f32 {
  let aspect = u.resolution.x / max(u.resolution.y, 1.0);
  let q = (uv * 2.0 - 1.0) * vec2f(aspect, 1.0);
  let r = length(q);
  // Radius threshold grows with progress — B blooms from center
  let radius = mix(-0.15, 1.55, p * p * (3.0 - 2.0 * p));
  let band = smoothstep3(radius + 0.18, radius - 0.12, r);
  // Mild angular swirl so it feels like a tunnel swallow
  let ang = atan2(q.y, q.x);
  let swirl = 0.5 + 0.5 * sin(ang * 3.0 + u.time * 2.0 + p * 6.0);
  return clamp(band * (0.85 + 0.15 * swirl), 0.0, 1.0);
}

// Kaleido wedge wipe: B reveals wedge-by-wedge as segment count morphs
fn mix_wedge(uv: vec2f, p: f32) -> f32 {
  let aspect = u.resolution.x / max(u.resolution.y, 1.0);
  let q = (uv * 2.0 - 1.0) * vec2f(aspect, 1.0);
  let segs = mix(max(u.mirrors_a, 3.0), max(u.mirrors_b, 3.0), u.morph);
  var ang = atan2(q.y, q.x);
  if (ang < 0.0) { ang += TAU; }
  let slice = TAU / segs;
  let idx = floor(ang / slice);
  // Wedges unlock in a spiral order driven by hash + progress
  let order = fract(idx * 0.6180339887 + u.seed * 0.13);
  let local = fract(ang / slice);
  let unlock = smoothstep3(order - 0.05, order + 0.2, p);
  // Leading edge sweeps within the active wedge
  let edge = smoothstep3(0.0, 0.35, local + (p - order) * 2.0);
  return clamp(unlock * mix(0.35, 1.0, edge), 0.0, 1.0);
}

// Additive storm: both nearly full briefly, then A decays
fn mix_storm(uv: vec2f, p: f32) -> vec3f {
  // Returns weights (wa, wb, add) — not a single mix factor
  let rise = smoothstep3(0.0, 0.25, p);
  let peak = 1.0 - abs(p - 0.45) * 2.2;
  let add = clamp(peak, 0.0, 1.0) * rise;
  let wa = 1.0 - smoothstep3(0.35, 0.95, p);
  let wb = smoothstep3(0.08, 0.55, p);
  // Slight spatial sparkle so storm isn't flat
  let spark = hash21(floor(uv * u.resolution * 0.08) + u.time);
  return vec3f(wa, wb, add * (0.7 + 0.3 * spark));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let a = textureSample(tex_a, samp, uv).rgb;
  let b = textureSample(tex_b, samp, uv).rgb;
  let p = clamp(u.progress, 0.0, 1.0);
  let mode = floor(u.mode + 0.5);

  var col: vec3f;
  if (mode < 0.5) {
    let m = mix_hex(uv, p);
    col = mix(a, b, m);
  } else if (mode < 1.5) {
    let m = mix_iris(uv, p);
    col = mix(a, b, m);
  } else if (mode < 2.5) {
    let m = mix_wedge(uv, p);
    col = mix(a, b, m);
  } else {
    let w = mix_storm(uv, p);
    col = a * w.x + b * w.y;
    // Brief additive flare
    col += (a * 0.55 + b * 0.55) * w.z;
    col = col / (1.0 + max(col - vec3f(1.0), vec3f(0.0)) * 1.8);
  }

  return vec4f(col, 1.0);
}
