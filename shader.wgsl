// Electric-Sheep-inspired kaleidoscope — fragment-only, 4K@120 friendly.
// flam3 UV variations + Holi palettes + layout flock (Mandala flowers CC0) / truchet.
//
// Mandala flowers layout adapted from:
//   "Mandala flowers" by Mårten Rånge (CC0) — https://www.shadertoy.com/view/NlcSRB
// Truchet layout is an original WGSL reimplementation of the *idea* only
// (smooth polar fold + cell patterns + Holi colors) — not a paste of 7lKSWW.

struct Uniforms {
  resolution: vec2f,
  time: f32,
  seed: f32,
  mouse: vec2f,
  theme: f32,
  mirrors: f32,
  intensity: f32,
  // 0 kaleido, 1 tunnel, 2 hybrid, 3 flock (mandala flowers), 4 truchet
  layout_mode: f32,
  ring_amount: f32,
  _pad0: f32,
}

@group(0) @binding(0) var<uniform> u: Uniforms;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;
const PI_2: f32 = 1.57079632679;

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

// Holi gulal powder swatches — vibrant, saturated
fn holi_powder(i: f32) -> vec3f {
  let k = i32(floor(i)) % 7;
  if (k == 0) { return vec3f(0.98, 0.18, 0.62); } // gulabi pink
  if (k == 1) { return vec3f(1.00, 0.48, 0.08); } // kesar saffron
  if (k == 2) { return vec3f(0.98, 0.86, 0.12); } // haldi yellow
  if (k == 3) { return vec3f(0.18, 0.88, 0.32); } // hari green
  if (k == 4) { return vec3f(0.28, 0.38, 1.00); } // neela electric blue
  if (k == 5) { return vec3f(0.95, 0.12, 0.18); } // laal red
  return vec3f(0.92, 0.10, 0.88);                 // fuchsia / violet
}

fn rainbow(t: f32) -> vec3f {
  let x = fract(t + u.seed * 0.017);
  let n = x * 7.0;
  let i = floor(n);
  let f = fract(n);
  let s = f * f * (3.0 - 2.0 * f);
  let a = holi_powder(i);
  let b = holi_powder(i + 1.0);
  return mix(a, b, s) * 0.92 + vec3f(0.04, 0.02, 0.03);
}

fn palette_theme(t: f32, theme: f32) -> vec3f {
  var col = rainbow(t) * 0.48
    + rainbow(t + 0.31) * 0.30
    + rainbow(t + 0.58) * 0.22;

  let th = floor(theme + 0.5);
  var bias = vec3f(1.0);
  var accent = 0.0;
  if (th < 0.5) {
    bias = vec3f(1.12, 0.82, 1.08);
    accent = 0.05;
  } else if (th < 1.5) {
    bias = vec3f(1.18, 0.78, 0.88);
    accent = 0.72;
  } else if (th < 2.5) {
    bias = vec3f(1.14, 1.02, 0.72);
    accent = 0.22;
  } else if (th < 3.5) {
    bias = vec3f(0.78, 1.16, 0.88);
    accent = 0.42;
  } else if (th < 4.5) {
    bias = vec3f(1.06, 0.98, 1.04);
    accent = 0.0;
  } else {
    bias = vec3f(0.82, 0.88, 1.20);
    accent = 0.58;
  }

  col *= bias;
  col += rainbow(t * 1.55 + accent + theme * 0.12) * 0.20;
  col = col / (1.0 + max(col - vec3f(0.95), vec3f(0.0)) * 1.4);
  return max(col, vec3f(0.0));
}

fn palette(t: f32) -> vec3f {
  return palette_theme(t, u.theme);
}

fn kaleido(p: vec2f, segments: f32) -> vec2f {
  let segs = max(segments, 2.0);
  let r = length(p);
  var a = atan2(p.y, p.x);
  let slice = TAU / segs;
  a = a - slice * floor(a / slice);
  a = abs(a - slice * 0.5);
  return vec2f(cos(a), sin(a)) * r;
}

fn rotate2(p: vec2f, a: f32) -> vec2f {
  let c = cos(a);
  let s = sin(a);
  return mat2x2f(c, s, -s, c) * p;
}

fn hash21(p: vec2f) -> f32 {
  let a = dot(p, vec2f(127.1, 311.7));
  return fract(sin(a) * 43758.5453123);
}

fn hash22(p: vec2f) -> vec2f {
  let n = sin(dot(p, vec2f(127.1, 311.7))) * 43758.5453;
  return fract(vec2f(n, n * 1.2154));
}

// GLSL-style mod (floor-based) — required for hex tiling with negative coords
fn mod1(x: f32, y: f32) -> f32 {
  return x - y * floor(x / y);
}

fn mod2(p: vec2f, s: vec2f) -> vec2f {
  return vec2f(mod1(p.x, s.x), mod1(p.y, s.y));
}

// --- flam3-inspired closed-form UV variations ---

fn var_sinusoidal(p: vec2f) -> vec2f { return vec2f(sin(p.x), sin(p.y)); }

fn var_spherical(p: vec2f) -> vec2f {
  let r2 = max(dot(p, p), 1e-4);
  return p / r2;
}

fn var_swirl(p: vec2f) -> vec2f {
  let r2 = dot(p, p);
  let s = sin(r2);
  let c = cos(r2);
  return vec2f(c * p.x - s * p.y, s * p.x + c * p.y);
}

fn var_horseshoe(p: vec2f) -> vec2f {
  let r = max(length(p), 1e-4);
  return vec2f((p.x - p.y) * (p.x + p.y), 2.0 * p.x * p.y) / r;
}

fn var_polar(p: vec2f) -> vec2f {
  return vec2f(atan2(p.y, p.x) / PI, length(p) - 1.0);
}

fn var_handkerchief(p: vec2f) -> vec2f {
  let r = length(p);
  let a = atan2(p.y, p.x);
  return r * vec2f(sin(a + r), cos(a - r));
}

fn var_heart(p: vec2f) -> vec2f {
  let r = length(p);
  let a = atan2(p.y, p.x);
  let aa = a * r;
  return r * vec2f(sin(aa), -cos(aa));
}

fn var_disc(p: vec2f) -> vec2f {
  let r = length(p);
  let a = atan2(p.y, p.x) / PI;
  return a * vec2f(sin(PI * r), cos(PI * r));
}

fn var_spiral(p: vec2f) -> vec2f {
  let r = max(length(p), 1e-4);
  let a = atan2(p.y, p.x);
  let sr = sin(r);
  let cr = cos(r);
  return vec2f(cr + sr, sr - cr) * (a / r) * 0.5;
}

fn var_hyperbolic(p: vec2f) -> vec2f {
  let r = max(length(p), 1e-4);
  let a = atan2(p.y, p.x);
  return vec2f(sin(a) / r, r * cos(a)) * 0.5;
}

fn var_diamond(p: vec2f) -> vec2f {
  let r = length(p);
  let a = atan2(p.y, p.x);
  return vec2f(sin(a) * cos(r), cos(a) * sin(r));
}

fn var_ex(p: vec2f) -> vec2f {
  let r = length(p);
  let a = atan2(p.x, p.y);
  let n0 = sin(a + r);
  let n1 = cos(a - r);
  let m0 = n0 * n0 * n0 * r;
  let m1 = n1 * n1 * n1 * r;
  return vec2f(m0 + m1, m0 - m1) * 0.5;
}

fn var_bent(p: vec2f) -> vec2f {
  return vec2f(
    select(p.x * 2.0, p.x, p.x >= 0.0),
    select(p.y * 0.5, p.y, p.y >= 0.0)
  );
}

fn var_waves(p: vec2f) -> vec2f {
  return vec2f(p.x + 0.35 * sin(p.y * 2.2), p.y + 0.35 * sin(p.x * 1.9));
}

fn var_fisheye(p: vec2f) -> vec2f {
  return p * (2.0 / (length(p) + 1.0));
}

fn var_eyefish(p: vec2f) -> vec2f {
  return p * (2.0 / (length(p) + 1.0));
}

fn var_exponential(p: vec2f) -> vec2f {
  let dx = exp(clamp(p.x - 1.0, -4.0, 4.0));
  let dy = PI * p.y;
  return dx * vec2f(cos(dy), sin(dy));
}

fn var_bubble(p: vec2f) -> vec2f {
  return p * (4.0 / (dot(p, p) + 4.0));
}

fn var_curl(p: vec2f) -> vec2f {
  let c1 = 0.35;
  let c2 = 0.25;
  let t1 = 1.0 + c1 * p.x + c2 * (p.x * p.x - p.y * p.y);
  let t2 = c1 * p.y + 2.0 * c2 * p.x * p.y;
  let d = max(t1 * t1 + t2 * t2, 1e-4);
  return vec2f(p.x * t1 + p.y * t2, p.y * t1 - p.x * t2) / d;
}

fn var_cross(p: vec2f) -> vec2f {
  let d = max((p.x * p.x - p.y * p.y) * (p.x * p.x - p.y * p.y), 1e-4);
  return p * (sqrt(1.0 / d) * 0.55);
}

fn var_blade(p: vec2f) -> vec2f {
  let r = length(p);
  let ph = r * (1.7 + u.seed * 0.2) + u.time * 0.6;
  return r * vec2f(cos(ph) * (cos(ph) + sin(ph)), sin(ph) * (cos(ph) - sin(ph))) * 0.55;
}

fn var_flower(p: vec2f) -> vec2f {
  let a = atan2(p.y, p.x);
  let r = length(p);
  let petals = 0.55 + 0.45 * abs(cos(a * 3.0));
  return (petals * cos(r * 2.0) / max(r, 1e-3)) * vec2f(cos(a), sin(a));
}

fn theme_warp(p: vec2f, theme: f32, t: f32) -> vec2f {
  let w = 0.5 + 0.5 * sin(t * 0.17 + theme);
  let w2 = 0.5 + 0.5 * cos(t * 0.11 + theme * 1.7);
  let th = floor(theme + 0.5);
  var q = p;

  if (th < 0.5) {
    q = mix(var_swirl(p * 1.15), var_spherical(p) * 0.55, w * 0.65);
    q = mix(q, var_ex(p * 0.9), w2 * 0.25);
  } else if (th < 1.5) {
    let a = mix(var_horseshoe(p), var_handkerchief(p), w);
    q = mix(a, mix(var_polar(p) * 0.85, var_cross(p), w2), 0.5);
  } else if (th < 2.5) {
    let a = mix(var_disc(p * 0.9), var_bubble(p), w);
    q = mix(a, var_sinusoidal(p * 1.35) * 0.7, w2 * 0.4);
  } else if (th < 3.5) {
    let a = mix(var_spiral(p), var_hyperbolic(p) * 0.7, w);
    q = mix(a, mix(var_diamond(p), var_blade(p), w2), 0.55);
  } else if (th < 4.5) {
    let a = mix(var_heart(p * 0.95), var_eyefish(p), w);
    q = mix(a, mix(var_fisheye(p * 0.85), var_exponential(p * 0.55), w2), 0.5);
  } else {
    let a = mix(var_curl(p), var_waves(p), w);
    q = mix(a, mix(var_bent(p), var_flower(p * 0.8), w2), 0.5);
  }
  return mix(p, q, 0.28);
}

fn soft_glow(d: f32, k: f32) -> f32 {
  return exp(-abs(d) * k);
}

fn sd_box2(p: vec2f, b: vec2f) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
}

fn filmic_holi(c: vec3f) -> vec3f {
  let luma = max(dot(c, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  let mapped = luma * (1.02 / (1.0 + luma * 0.95));
  var out = c * (mapped / luma);
  out = out / (1.0 + max(out - vec3f(0.68), vec3f(0.0)) * 2.8);
  return out;
}

fn space_for_mode(p: vec2f, mode: f32, segments: f32, t: f32) -> vec2f {
  let lo = floor(mode + 0.5);
  if (lo < 0.5) {
    return kaleido(p * 0.85, segments);
  } else if (lo < 1.5) {
    let ang = atan2(p.x, p.y) / PI;
    let depth = 1.0 / max(length(p), 0.18);
    let tuv = vec2f(ang * 0.55, depth * 0.16) + t * vec2f(0.03, 0.22);
    return vec2f(tuv.x, tuv.y * 0.55) * 0.9;
  }
  var q = kaleido(p * 0.75, segments);
  q = rotate2(q, t * 0.05);
  let depth = 1.0 / max(length(q), 0.16);
  let tz = depth * 0.22 + t * 0.35;
  return vec2f(q.x * 1.1, q.y * 1.1 + (fract(tz) - 0.5) * 0.35);
}

fn bold_forms(p: vec2f, t: f32, theme: f32, ring_amt: f32) -> f32 {
  let breath = 0.12 * sin(t * 0.4 + theme);
  var g = 0.0;

  let r = length(p);
  g += soft_glow(r - (0.62 + breath), 7.5) * 1.35;
  g += soft_glow(r - (1.15 + breath * 0.6), 5.5) * 0.75;
  g += soft_glow(abs(p.y) - (0.10 + 0.04 * sin(t * 0.55)), 11.0) * 1.1;

  let s1 = 0.95 - abs(sin(t * 0.35)) * 0.25;
  let b1 = sd_box2(rotate2(p + vec2f(0.0, 0.35 * sin(t * 0.4)), 0.8), vec2f(0.72 * s1, 0.10));
  let b2 = sd_box2(rotate2(p - vec2f(0.0, 0.35 * sin(t * 0.4)), -0.8), vec2f(0.72 * s1, 0.10));
  let b3 = sd_box2(rotate2(p, t * 0.12), vec2f(0.48, 0.14 + 0.04 * cos(t * 0.3)));
  g += soft_glow(b1, 9.0) * 0.95;
  g += soft_glow(b2, 9.0) * 0.95;
  g += soft_glow(b3, 8.0) * 0.8;

  let dia = sd_box2(rotate2(p, 0.785 + t * 0.08), vec2f(0.55, 0.08));
  g += soft_glow(dia, 10.0) * 0.7;

  if (ring_amt > 0.04) {
    let sparse = ring_amt * smoothstep(0.0, 0.7, ring_amt);
    g += soft_glow(r - (0.88 + 0.2 * sin(t * 0.45)), 6.0) * sparse * 0.9;
    let storm = smoothstep(0.85, 1.5, ring_amt);
    g += soft_glow(r - (1.35 + 0.15 * cos(t * 0.3)), 4.5) * storm * 0.7;
  }

  return g;
}

fn tunnel_bands(p: vec2f, t: f32, layout_w: f32) -> f32 {
  let w = smoothstep(0.2, 0.85, layout_w);
  if (w < 0.01) {
    return 0.0;
  }
  let r = max(length(p), 0.12);
  let depth = 1.0 / r + t * 0.45;
  let band = soft_glow(abs(sin(depth * 0.65)) * 1.4 - 0.7, 5.0);
  let lane = soft_glow(abs(sin(atan2(p.y, p.x) * 2.0 + depth * 0.15)) - 0.35, 6.5);
  let wall = smoothstep(0.08, 0.35, r) * (1.0 - smoothstep(1.2, 1.9, r));
  return (band * 1.1 + lane * 0.55) * wall * w;
}

fn classic_sheep(uv_in: vec2f) -> vec3f {
  let res = u.resolution;
  let t = u.time;
  let theme = u.theme;
  let mode = u.layout_mode;

  var uv = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  let uv0 = uv;

  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  let mlen = length(m);
  uv += m * 0.34;
  uv = rotate2(uv, m.x * 0.58 + m.y * 0.24 + mlen * 0.2);
  uv += rotate2(m, t * 0.35) * 0.12 * sin(t * 0.5 + mlen);
  uv = rotate2(uv, t * (0.04 + theme * 0.008));

  var folded = kaleido(uv, u.mirrors);
  folded = rotate2(folded, m.x * 0.38 - m.y * 0.22);
  folded += m.yx * vec2f(-0.16, 0.16);

  var p = space_for_mode(folded, mode, u.mirrors, t);
  p = theme_warp(p * (0.72 + 0.08 * sin(t * 0.1 + theme)), theme, t);
  p += m * 0.1;

  let field = bold_forms(p, t, theme, u.ring_amount);
  let bands = tunnel_bands(uv0, t, mode);

  let hue = length(uv0) * 0.35 + t * 0.12 + u.seed * 0.08 + atan2(p.y, p.x) * 0.04;
  let col = palette(hue) * 0.65 + palette(hue + 0.28) * 0.35;

  var final_color = col * (field * 0.55 + bands * 0.4);
  final_color += rainbow(hue + 0.4) * field * 0.06;

  let tunnel_bloom = smoothstep(0.45, 1.25, mode);
  final_color += palette(t * 0.06 + 0.45) * (0.02 / (length(uv0) + 0.18)) * tunnel_bloom;

  return final_color;
}

// ---------------------------------------------------------------------------
// Mandala flowers flock — adapted from Mårten Rånge CC0 (Shadertoy NlcSRB).
// Hex field of smooth-kaleidoscope mandalas; Holi powder colors instead of HSV.
// See ATTRIBUTION.md.
// ---------------------------------------------------------------------------

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

fn pmin(a: f32, b: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

fn pmax(a: f32, b: f32, k: f32) -> f32 {
  return -pmin(-a, -b, k);
}

fn pabs(a: f32, k: f32) -> f32 {
  return pmax(a, -a, k);
}

fn mod_mirror1(p_in: f32, size: f32) -> vec2f {
  let halfsize = size * 0.5;
  let c = floor((p_in + halfsize) / size);
  var p = mod1(p_in + halfsize, size) - halfsize;
  p *= (mod1(c, 2.0) * 2.0 - 1.0);
  return vec2f(p, c);
}

fn smooth_kaleidoscope(p_in: vec2f, sm: f32, rep: f32) -> vec2f {
  let r = length(p_in);
  var ang = atan2(p_in.y, p_in.x);
  let mm = mod_mirror1(ang, TAU / rep);
  ang = mm.x;
  let sa = PI / rep - pabs(PI / rep - abs(ang), sm);
  ang = sign(ang) * sa;
  return vec2f(cos(ang), sin(ang)) * r;
}

fn petal_motif(p_in: vec2f, petals: f32, t: f32) -> vec2f {
  // returns (fill, distance) — figure-8 / arc petals, Holi-friendly
  let logo_radius = 0.25;
  let logo_off = 0.25;
  let logo_dx = 0.5 / sqrt(3.0);
  let logo_width = 0.09;

  var p = kaleido(p_in, max(petals, 3.0));
  let p1 = p - vec2f(logo_dx, -logo_off);
  let p2 = p - vec2f(logo_dx, logo_off);
  let d1 = abs(length(p1) - logo_radius);
  let d2 = abs(length(p2) - logo_radius);
  var d = min(d1, d2) - logo_width;
  // striped ribbon inside arcs
  let stripe = abs(abs(min(d1, d2)) - logo_width * 0.42) - logo_width * 0.21;
  let fill = smoothstep(0.02, -0.02, stripe);
  let body = smoothstep(0.02, -0.02, d);
  // radial spokes for extra petal read
  let spoke = soft_glow(abs(p.y) - 0.02, 28.0) * smoothstep(0.55, 0.12, length(p));
  let glow_d = d;
  return vec2f(max(fill, body * 0.85) + spoke * 0.35, glow_d);
}

fn flock_sheep(uv_in: vec2f) -> vec3f {
  let res = u.resolution;
  let t = u.time;
  let aa = 2.0 / max(res.y, 1.0);

  var p = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);

  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  p += m * 0.28;
  p = rotate2(p, m.x * 0.25 + m.y * 0.12);

  // Slow Lissajous drift — flock wandering across the hex field
  let a = TAU * t / 280.0;
  p += 8.5 * vec2f(sin(a), sin(sqrt(0.5) * a));
  p *= 1.15 + 0.08 * sin(t * 0.11 + u.seed);

  let tile = hextile(p);
  var hp = tile.local;
  let np = tile.id + vec2f(u.seed * 0.13, u.seed * 0.07);

  let hd = abs(sd_hex(hp.yx, 0.5)) - 2.0 * aa;
  var cp = hp;

  let h = hash21(np);
  let hh = fract(137.0 * h);
  // Per-cell unique petal/mirror count + smoothness (living flock)
  let sm = mix(mix(0.025, 0.22, hh), 0.03, h);
  let base_rep = mix(6.0, 14.0, h) + u.mirrors * 0.35;
  let rep = 2.0 * floor(clamp(base_rep, 4.0, 18.0));
  cp = smooth_kaleidoscope(cp, sm, rep);
  let spin = t * (0.14 + 0.22 * h) + TAU * h + u.seed;
  cp = rotate2(cp, spin);

  let motif = petal_motif(cp * 1.65, rep * 0.5, t);
  let fill = motif.x;
  let d = motif.y;

  // Holi glow tint per cell (genome-driven, multi-hue lanes)
  let gcol = palette_theme(h + u.theme * 0.07 + t * 0.03, u.theme) * 1.35;
  let petal_col = palette_theme(h * 1.7 + fract(spin * 0.08) + 0.2, u.theme);

  var col = gcol * exp(-42.0 * max(d, 0.0));
  col = mix(col, vec3f(0.10, 0.04, 0.08), smoothstep(aa, -aa, hd) * 0.55);
  col = mix(col, petal_col, clamp(fill, 0.0, 1.0));

  // Soft neighbor bleed so the flock reads as continuous sheep, not stamps
  let breath = 0.04 + 0.03 * sin(t * 1.3 + h * 20.0);
  col += rainbow(h + t * 0.05) * soft_glow(length(hp) - (0.42 + breath), 10.0) * 0.12;

  if (u.ring_amount > 0.2) {
    col += palette(h + 0.4) * soft_glow(sd_hex(hp.yx, 0.48), 14.0) * u.ring_amount * 0.25;
  }

  return col;
}

// ---------------------------------------------------------------------------
// Truchet + kaleidoscope — ORIGINAL WGSL inspired by the *idea* of combining
// smooth polar folds with Truchet-like cell arcs. NOT a paste of Shadertoy
// 7lKSWW (license unconfirmed for commercial paste). Holi genomes color lanes.
// ---------------------------------------------------------------------------

fn truchet_sheep(uv_in: vec2f) -> vec3f {
  let res = u.resolution;
  let t = u.time;
  var p = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);

  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  p += m * 0.3;
  p = rotate2(p, t * 0.05 + m.x * 0.4);

  // Smooth polar fold first (kaleido wedge), then cell Truchet in folded space
  let segs = max(u.mirrors, 3.0);
  var q = kaleido(p * 1.05, segs);
  // Soften fold seam with a slight radial breath
  q += 0.04 * sin(q.yx * 3.0 + t * 0.7);

  let scale = 2.4 + 0.35 * sin(t * 0.2 + u.seed);
  var gp = q * scale + vec2f(t * 0.15, -t * 0.08);
  let cell = floor(gp);
  var f = fract(gp) - 0.5;

  let h = hash21(cell + vec2f(u.seed * 2.1, u.seed));
  let h2 = hash22(cell * 1.17 + u.seed);

  // Rotate / flip cell for Truchet variety
  if (h > 0.5) {
    f = vec2f(f.y, -f.x);
  }
  if (h2.x > 0.5) {
    f = vec2f(-f.x, f.y);
  }

  // Arc pair + diagonal bar — classic Truchet vocabulary, original distances
  let r = 0.5;
  let d_arc_a = abs(length(f - vec2f(-0.5, -0.5)) - r);
  let d_arc_b = abs(length(f - vec2f(0.5, 0.5)) - r);
  let d_diag = abs(f.x - f.y) * 0.7071;
  let stroke = select(min(d_arc_a, d_arc_b), d_diag, h2.y > 0.62);
  let w = 0.07 + 0.03 * sin(t * 1.4 + h * 10.0);
  let line = soft_glow(stroke - w, 28.0) + soft_glow(stroke, 9.0) * 0.35;

  // Multi-hue Holi lanes — not a thin neon ramp
  let lane = (cell.x + cell.y * 0.37) * 0.08 + h * 0.5 + u.theme * 0.11 + t * 0.04;
  let c0 = palette_theme(lane, u.theme);
  let c1 = palette_theme(lane + 0.33, u.theme);
  let c2 = holi_powder(floor(h * 7.0 + u.theme));
  var col = mix(c0, c1, clamp(line, 0.0, 1.0)) * line;
  col += c2 * soft_glow(length(f) - 0.18, 12.0) * 0.2;

  // Nested polar rings for kaleido depth
  let pr = length(q);
  col += palette(pr * 0.4 + t * 0.08) * soft_glow(abs(sin(pr * 5.0 - t)) - 0.15, 8.0) * 0.35;
  col += rainbow(atan2(q.y, q.x) / TAU + t * 0.05) * soft_glow(abs(q.y), 18.0) * 0.15;

  if (u.ring_amount > 0.15) {
    col += palette(h + 0.5) * soft_glow(pr - (0.7 + 0.2 * sin(t)), 6.0) * u.ring_amount * 0.4;
  }

  return col;
}

fn finish(col_in: vec3f) -> vec4f {
  var final_color = col_in * u.intensity;
  final_color = filmic_holi(final_color);
  final_color = pow(clamp(final_color, vec3f(0.0), vec3f(1.0)), vec3f(0.96));
  let pedestal = mix(vec3f(0.012, 0.004, 0.010), vec3f(0.008, 0.005, 0.018), u.theme / 5.0);
  final_color = pedestal + final_color * 0.96;
  return vec4f(final_color, 1.0);
}

@fragment
fn fs_main(@location(0) uv_in: vec2f) -> @location(0) vec4f {
  let lo = floor(u.layout_mode + 0.5);
  var col: vec3f;
  if (lo > 3.5) {
    col = truchet_sheep(uv_in);
  } else if (lo > 2.5) {
    col = flock_sheep(uv_in);
  } else {
    col = classic_sheep(uv_in);
  }
  return finish(col);
}
