// Electric-Sheep-inspired kaleidoscope — fragment-only, 4K@120 friendly.
// flam3 UV variations + theme/mirror morph + polar / hybrid tunnels.

struct Uniforms {
  resolution: vec2f,
  time: f32,
  seed: f32,
  mouse: vec2f,
  theme_a: f32,
  theme_b: f32,
  theme_mix: f32,
  mirrors_a: f32,
  mirrors_b: f32,
  mirror_mix: f32,
  intensity: f32,
  // layout: 0 kaleido, 1 tunnel, 2 hybrid — A/B morph like themes
  layout_a: f32,
  layout_b: f32,
  layout_mix: f32,
  // 0 = quiet / no rings, ~1 = sparse, ~2 = storm of many circles
  ring_amount: f32,
  _pad0: f32,
  _pad1: f32,
  _pad2: f32,
}

@group(0) @binding(0) var<uniform> u: Uniforms;

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

// Holi gulal powder swatches — vibrant, saturated, never cyan-only
fn holi_powder(i: f32) -> vec3f {
  let k = i32(floor(i)) % 7;
  // gulabi, kesar, hali, hari, neela/violet, laal, fuchsia
  if (k == 0) { return vec3f(0.98, 0.18, 0.62); } // gulabi pink
  if (k == 1) { return vec3f(1.00, 0.48, 0.08); } // kesar saffron
  if (k == 2) { return vec3f(0.98, 0.86, 0.12); } // haldi yellow
  if (k == 3) { return vec3f(0.18, 0.88, 0.32); } // hari green
  if (k == 4) { return vec3f(0.28, 0.38, 1.00); } // neela electric blue
  if (k == 5) { return vec3f(0.95, 0.12, 0.18); } // laal red
  return vec3f(0.92, 0.10, 0.88);                 // fuchsia / violet
}

// Smooth multi-powder ramp — several Holi colors visible at once
fn rainbow(t: f32) -> vec3f {
  let x = fract(t + u.seed * 0.017);
  let n = x * 7.0;
  let i = floor(n);
  let f = fract(n);
  let s = f * f * (3.0 - 2.0 * f);
  let a = holi_powder(i);
  let b = holi_powder(i + 1.0);
  // Soft lift so powders glow without washing to white
  return mix(a, b, s) * 0.92 + vec3f(0.04, 0.02, 0.03);
}

// Theme = Holi powder mix bias — still keeps multiple gulal hues on screen
fn palette_theme(t: f32, theme: f32) -> vec3f {
  var col = rainbow(t) * 0.48
    + rainbow(t + 0.31) * 0.30
    + rainbow(t + 0.58) * 0.22;

  let th = floor(theme + 0.5);
  var bias = vec3f(1.0);
  var accent = 0.0;
  if (th < 0.5) {
    // gulabi — pink / fuchsia / violet
    bias = vec3f(1.12, 0.82, 1.08);
    accent = 0.05;
  } else if (th < 1.5) {
    // laal — red / magenta / saffron ember
    bias = vec3f(1.18, 0.78, 0.88);
    accent = 0.72;
  } else if (th < 2.5) {
    // kesar — saffron / hali / warm rose
    bias = vec3f(1.14, 1.02, 0.72);
    accent = 0.22;
  } else if (th < 3.5) {
    // hari — green / yellow / teal-lime gulal
    bias = vec3f(0.78, 1.16, 0.88);
    accent = 0.42;
  } else if (th < 4.5) {
    // rang — full Holi riot (pink / yellow / green / blue)
    bias = vec3f(1.06, 0.98, 1.04);
    accent = 0.0;
  } else {
    // neela — electric blue / violet / fuchsia
    bias = vec3f(0.82, 0.88, 1.20);
    accent = 0.58;
  }

  col *= bias;
  col += rainbow(t * 1.55 + accent + theme * 0.12) * 0.20;
  // Soft channel ceiling before additive stack — keeps powder hue at peaks
  col = col / (1.0 + max(col - vec3f(0.95), vec3f(0.0)) * 1.4);
  return max(col, vec3f(0.0));
}

fn palette(t: f32) -> vec3f {
  return mix(
    palette_theme(t, u.theme_a),
    palette_theme(t, u.theme_b),
    u.theme_mix
  );
}

fn kaleido(p: vec2f, segments: f32) -> vec2f {
  let segs = max(segments, 2.0);
  let r = length(p);
  var a = atan2(p.y, p.x);
  let slice = 6.28318530718 / segs;
  a = a - slice * floor(a / slice);
  a = abs(a - slice * 0.5);
  return vec2f(cos(a), sin(a)) * r;
}

fn rotate2(p: vec2f, a: f32) -> vec2f {
  let c = cos(a);
  let s = sin(a);
  return mat2x2f(c, s, -s, c) * p;
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
  return vec2f(atan2(p.y, p.x) / 3.14159265, length(p) - 1.0);
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
  let a = atan2(p.y, p.x) / 3.14159265;
  return a * vec2f(sin(3.14159265 * r), cos(3.14159265 * r));
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
  let dy = 3.14159265 * p.y;
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
  // deterministic blade (flam3 uses random phase — time stands in)
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
  // Soft warp — keep shapes bold (Octagrams-scale), not lace
  return mix(p, q, 0.28);
}

fn morph_variations(p: vec2f, t: f32) -> vec2f {
  return mix(
    theme_warp(p, u.theme_a, t),
    theme_warp(p, u.theme_b, t),
    u.theme_mix
  );
}

// Octagrams-style soft glow: ac += exp(-d*k) — thick readable neon, not 1/r spikes
fn soft_glow(d: f32, k: f32) -> f32 {
  return exp(-abs(d) * k);
}

fn sd_box2(p: vec2f, b: vec2f) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec2f(0.0))) + min(max(q.x, q.y), 0.0);
}

// Luminance-weighted filmic remap — compresses brightness, preserves Holi hue
fn filmic_holi(c: vec3f) -> vec3f {
  let luma = max(dot(c, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  let mapped = luma * (1.02 / (1.0 + luma * 0.95));
  var out = c * (mapped / luma);
  out = out / (1.0 + max(out - vec3f(0.68), vec3f(0.0)) * 2.8);
  return out;
}

// Space modes return LARGE domains (no micro-fract tiling)
fn space_for_mode(p: vec2f, mode: f32, segments: f32, t: f32) -> vec2f {
  let lo = floor(mode + 0.5);
  if (lo < 0.5) {
    // Wide kaleido wedges — scale up so one form fills the frame
    return kaleido(p * 0.85, segments);
  } else if (lo < 1.5) {
    // Polar tunnel: coarse angle × depth, big cells
    let ang = atan2(p.x, p.y) / 3.14159265;
    let depth = 1.0 / max(length(p), 0.18);
    let tuv = vec2f(ang * 0.55, depth * 0.16) + t * vec2f(0.03, 0.22);
    return vec2f(tuv.x, tuv.y * 0.55) * 0.9;
  }
  // Hybrid: one big fold + slow depth scroll (Octagrams corridor feel, no raymarch)
  var q = kaleido(p * 0.75, segments);
  q = rotate2(q, t * 0.05);
  let depth = 1.0 / max(length(q), 0.16);
  let tz = depth * 0.22 + t * 0.35;
  return vec2f(q.x * 1.1, q.y * 1.1 + (fract(tz) - 0.5) * 0.35);
}

// Bold forms — scale language of tlVGDt / Octagrams: big arcs, thick plates, wide ribbons
// Cheap 2D SDFs + soft_glow (borrow aesthetic, not 99-step raymarch)
fn bold_forms(p: vec2f, t: f32, theme: f32, ring_amt: f32) -> f32 {
  let breath = 0.12 * sin(t * 0.4 + theme);
  var g = 0.0;

  // Large concentric arcs (primary readable shapes)
  let r = length(p);
  g += soft_glow(r - (0.62 + breath), 7.5) * 1.35;
  g += soft_glow(r - (1.15 + breath * 0.6), 5.5) * 0.75;

  // Thick radial ribbon (kaleido already mirrors it into a star)
  g += soft_glow(abs(p.y) - (0.10 + 0.04 * sin(t * 0.55)), 11.0) * 1.1;

  // Octagrams-inspired rotated plates / boxes — few, huge
  let s1 = 0.95 - abs(sin(t * 0.35)) * 0.25;
  let b1 = sd_box2(rotate2(p + vec2f(0.0, 0.35 * sin(t * 0.4)), 0.8), vec2f(0.72 * s1, 0.10));
  let b2 = sd_box2(rotate2(p - vec2f(0.0, 0.35 * sin(t * 0.4)), -0.8), vec2f(0.72 * s1, 0.10));
  let b3 = sd_box2(rotate2(p, t * 0.12), vec2f(0.48, 0.14 + 0.04 * cos(t * 0.3)));
  g += soft_glow(b1, 9.0) * 0.95;
  g += soft_glow(b2, 9.0) * 0.95;
  g += soft_glow(b3, 8.0) * 0.8;

  // Wide diamond wedge
  let dia = sd_box2(rotate2(p, 0.785 + t * 0.08), vec2f(0.55, 0.08));
  g += soft_glow(dia, 10.0) * 0.7;

  // Episodic outer halo (quiet / sparse / storm) — still large
  if (ring_amt > 0.04) {
    let sparse = ring_amt * smoothstep(0.0, 0.7, ring_amt);
    g += soft_glow(r - (0.88 + 0.2 * sin(t * 0.45)), 6.0) * sparse * 0.9;
    let storm = smoothstep(0.85, 1.5, ring_amt);
    g += soft_glow(r - (1.35 + 0.15 * cos(t * 0.3)), 4.5) * storm * 0.7;
  }

  return g;
}

// Tunnel / hybrid depth bands — sparse, thick (fills corridor like Octagrams slabs)
fn tunnel_bands(p: vec2f, t: f32, layout_w: f32) -> f32 {
  let w = smoothstep(0.2, 0.85, layout_w);
  if (w < 0.01) {
    return 0.0;
  }
  let r = max(length(p), 0.12);
  let depth = 1.0 / r + t * 0.45;
  // Few slow rings flying past
  let band = soft_glow(abs(sin(depth * 0.65)) * 1.4 - 0.7, 5.0);
  let lane = soft_glow(abs(sin(atan2(p.y, p.x) * 2.0 + depth * 0.15)) - 0.35, 6.5);
  let wall = smoothstep(0.08, 0.35, r) * (1.0 - smoothstep(1.2, 1.9, r));
  return (band * 1.1 + lane * 0.55) * wall * w;
}

@fragment
fn fs_main(@location(0) uv_in: vec2f) -> @location(0) vec4f {
  let res = u.resolution;
  let t = u.time;
  let theme = mix(u.theme_a, u.theme_b, u.theme_mix);
  let mode = mix(u.layout_a, u.layout_b, u.layout_mix);
  let layout_w = mode;

  var uv = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  let uv0 = uv;

  // Strong mouse parallax / orbit / swirl
  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  let mlen = length(m);
  uv += m * 0.34;
  uv = rotate2(uv, m.x * 0.58 + m.y * 0.24 + mlen * 0.2);
  uv += rotate2(m, t * 0.35) * 0.12 * sin(t * 0.5 + mlen);

  uv = rotate2(uv, t * (0.04 + theme * 0.008));

  let ua = kaleido(uv, u.mirrors_a);
  let ub = kaleido(uv, u.mirrors_b);
  var folded = mix(ua, ub, u.mirror_mix);
  folded = rotate2(folded, m.x * 0.38 - m.y * 0.22);
  folded += m.yx * vec2f(-0.16, 0.16);

  let space_a = space_for_mode(folded, u.layout_a, u.mirrors_a, t);
  let space_b = space_for_mode(folded, u.layout_b, u.mirrors_b, t);
  var p = mix(space_a, space_b, u.layout_mix);

  // Soft theme warp on a LARGE domain — no fract tiling
  p = morph_variations(p * (0.72 + 0.08 * sin(t * 0.1 + theme)), t);
  p += m * 0.1;

  // Single-pass bold field (tlVGDt scale language)
  let field = bold_forms(p, t, theme, u.ring_amount);
  let bands = tunnel_bands(uv0, t, layout_w);

  // Broad Holi color bands across big shapes (low spatial freq hue)
  let hue = length(uv0) * 0.35 + t * 0.12 + u.seed * 0.08 + atan2(p.y, p.x) * 0.04;
  let col_a = palette(hue);
  let col_b = palette(hue + 0.28);
  let col = col_a * 0.65 + col_b * 0.35;

  var final_color = col * (field * 0.55 + bands * 0.4);
  // Soft secondary tint on the brightest plates only
  final_color += rainbow(hue + 0.4) * field * 0.06;

  // Gentle center bloom for tunnel layouts
  let tunnel_bloom = smoothstep(0.45, 1.25, layout_w);
  final_color += palette(t * 0.06 + 0.45) * (0.02 / (length(uv0) + 0.18)) * tunnel_bloom;

  final_color *= u.intensity;
  final_color = filmic_holi(final_color);
  final_color = pow(clamp(final_color, vec3f(0.0), vec3f(1.0)), vec3f(0.96));

  let pedestal = mix(vec3f(0.012, 0.004, 0.010), vec3f(0.008, 0.005, 0.018), theme / 5.0);
  final_color = pedestal + final_color * 0.96;

  return vec4f(final_color, 1.0);
}
