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

fn palette_theme(t: f32, theme: f32) -> vec3f {
  var a = vec3f(0.50, 0.42, 0.55);
  var b = vec3f(0.48, 0.38, 0.42);
  var c = vec3f(1.00, 0.95, 0.80);
  var d = vec3f(0.15, 0.33, 0.67);

  let th = floor(theme + 0.5);
  if (th < 0.5) {
    a = vec3f(0.50, 0.40, 0.55); b = vec3f(0.50, 0.40, 0.45);
    c = vec3f(1.0, 1.0, 0.85); d = vec3f(0.00, 0.33, 0.67);
  } else if (th < 1.5) {
    a = vec3f(0.45, 0.28, 0.38); b = vec3f(0.55, 0.35, 0.40);
    c = vec3f(1.1, 0.7, 0.9); d = vec3f(0.55, 0.20, 0.40);
  } else if (th < 2.5) {
    a = vec3f(0.55, 0.45, 0.40); b = vec3f(0.45, 0.35, 0.30);
    c = vec3f(0.9, 0.85, 0.7); d = vec3f(0.10, 0.45, 0.20);
  } else if (th < 3.5) {
    a = vec3f(0.35, 0.50, 0.45); b = vec3f(0.40, 0.45, 0.35);
    c = vec3f(1.0, 1.1, 0.9); d = vec3f(0.30, 0.60, 0.10);
  } else if (th < 4.5) {
    a = vec3f(0.55, 0.35, 0.45); b = vec3f(0.50, 0.30, 0.40);
    c = vec3f(1.05, 0.75, 0.85); d = vec3f(0.70, 0.15, 0.50);
  } else {
    a = vec3f(0.40, 0.38, 0.50); b = vec3f(0.45, 0.40, 0.45);
    c = vec3f(0.95, 0.90, 1.05); d = vec3f(0.20, 0.50, 0.80);
  }

  d.x += u.seed * 0.05;
  return a + b * cos(6.28318 * (c * t + d));
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
  return mix(p, q, 0.58);
}

fn morph_variations(p: vec2f, t: f32) -> vec2f {
  return mix(
    theme_warp(p, u.theme_a, t),
    theme_warp(p, u.theme_b, t),
    u.theme_mix
  );
}

fn glow_ring(d: f32, width: f32, sharpness: f32) -> f32 {
  let g = sharpness / max(abs(d), 1e-4);
  return min(g, 12.0) * width;
}

// Classic demoscene tunnel UVs (Shadertoy 4djBRm / 4rknova style)
// t = (angle/π, 1/radius), scroll in depth
fn tunnel_uv(p: vec2f, t: f32) -> vec2f {
  let ang = atan2(p.x, p.y) / 3.14159265;
  let depth = 1.0 / max(length(p), 0.06);
  return vec2f(ang * 1.5, depth * 0.55) + t * vec2f(0.08, 0.85);
}

// Hybrid kaleidoscope tunnel (tfBXzD-inspired):
// fold → tunnel → re-fold angle lanes for recursive corridor feel
fn hybrid_tunnel_space(p: vec2f, segments: f32, t: f32) -> vec2f {
  var q = kaleido(p, segments);
  q = rotate2(q, t * 0.12);
  let ang = atan2(q.y, q.x);
  let depth = 1.0 / max(length(q), 0.05);
  let tz = depth + t * 1.15;
  // twist + mirror the angular lanes as we fly
  var a = ang + 0.55 * sin(tz * 0.35 + t * 0.4);
  let slice = 6.28318530718 / max(segments, 2.0);
  a = a - slice * floor(a / slice);
  a = abs(a - slice * 0.5);
  return vec2f(a / 3.14159265 * 2.2, tz * 0.35);
}

fn layout_space(p: vec2f, layout: f32, segments: f32, t: f32) -> vec2f {
  let lo = floor(layout + 0.5);
  if (lo < 0.5) {
    // flat kaleidoscope domain
    return kaleido(p, segments);
  } else if (lo < 1.5) {
    // pure polar tunnel
    let tuv = tunnel_uv(p, t);
    // wrap into a foldable 2D domain for the fractal pass
    return vec2f(fract(tuv.x) - 0.5, fract(tuv.y) - 0.5);
  }
  // hybrid
  let huv = hybrid_tunnel_space(p, segments, t);
  return vec2f(fract(huv.x) - 0.5, fract(huv.y * 0.65) - 0.5);
}

// Episodic ring field: quiet / sparse pulse / multi-circle storm
fn ring_field(d0: f32, t: f32, theme: f32, amount: f32) -> f32 {
  if (amount < 0.04) {
    return 0.0;
  }

  var g = 0.0;
  // Sparse: one slow breathing ring
  let sparse = amount * smoothstep(0.0, 0.7, amount);
  var d1 = d0 - (0.22 + 0.12 * sin(t * 0.55 + theme));
  d1 = abs(sin(d1 * 6.0 - t * 0.9)) / 6.0;
  g += glow_ring(d1, sparse, 0.014) * 0.85;

  // Storm: many simultaneous concentric frequencies
  let storm = smoothstep(0.85, 1.6, amount);
  if (storm > 0.0) {
    let freqs = array<f32, 4>(11.0, 17.0, 23.0, 31.0);
    let speeds = array<f32, 4>(1.1, -0.7, 1.6, -1.3);
    for (var k = 0; k < 4; k = k + 1) {
      var dk = sin(d0 * freqs[k] + t * speeds[k] + theme * 0.4 + f32(k)) / freqs[k];
      g += glow_ring(dk, storm * (0.55 - f32(k) * 0.08), 0.010 + f32(k) * 0.002);
    }
  }
  return g;
}

// Tunnel wall ribs / depth rings (cheap, no raymarch)
fn tunnel_structure(p: vec2f, t: f32, theme: f32, layout_w: f32) -> f32 {
  // Only contribute when layout leans tunnel/hybrid
  let w = smoothstep(0.15, 0.75, layout_w);
  if (w < 0.01) {
    return 0.0;
  }

  let r = max(length(p), 0.04);
  let ang = atan2(p.y, p.x);
  let depth = 1.0 / r + t * 1.2;

  // Depth rings flying past
  var rings = abs(sin(depth * 2.4 - t * 0.5));
  rings = pow(1.0 - rings, 8.0);

  // Angular lanes (sheep "pie"/fan feel)
  var lanes = abs(sin(ang * mix(u.mirrors_a, u.mirrors_b, u.mirror_mix) + depth * 0.4));
  lanes = pow(1.0 - lanes, 14.0);

  // Soft cylindrical wall emphasis
  let wall = smoothstep(0.03, 0.2, r) * (1.0 - smoothstep(0.95, 1.55, r));

  return (rings * 0.9 + lanes * 1.1 + rings * lanes * 0.6) * wall * w;
}

@fragment
fn fs_main(@location(0) uv_in: vec2f) -> @location(0) vec4f {
  let res = u.resolution;
  let t = u.time;
  let theme = mix(u.theme_a, u.theme_b, u.theme_mix);
  let segments = mix(u.mirrors_a, u.mirrors_b, u.mirror_mix);
  let layout = mix(u.layout_a, u.layout_b, u.layout_mix);
  // 0..2 weight used for tunnel structure fade
  let layout_w = layout;

  var uv = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  let uv0 = uv;

  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  uv += m * 0.07 * sin(t * 0.35);

  let rot = t * (0.06 + theme * 0.012);
  uv = rotate2(uv, rot);

  // Pre-fold mirrors (shared by all layouts)
  let ua = kaleido(uv, u.mirrors_a);
  let ub = kaleido(uv, u.mirrors_b);
  var folded = mix(ua, ub, u.mirror_mix);

  // Layout spaces morph (kaleido ↔ tunnel ↔ hybrid)
  let space_a = layout_space(folded, u.layout_a, u.mirrors_a, t);
  let space_b = layout_space(folded, u.layout_b, u.mirrors_b, t);
  var p = mix(space_a, space_b, u.layout_mix);

  p = morph_variations(p * (0.82 + 0.18 * sin(t * 0.13 + theme)), t);

  var final_color = vec3f(0.0);
  var q = p;

  // Fractal fold — filaments always on; circles gated by ring_amount
  for (var i = 0; i < 3; i = i + 1) {
    q = fract(q * 2.0) - 0.5;

    let fi = f32(i);
    let d0 = length(q);
    let col = palette(length(uv0) + t * 0.32 + fi * 0.22 + u.seed * 0.1);

    // Base filament: soft distance glow (sheep ribbon, not concentric circles)
    var filament = glow_ring(abs(q.x * q.y) * 2.2 - 0.04 * sin(t + fi), 0.55, 0.012);
    filament += glow_ring(abs(sin(q.x * 8.0 + t) * cos(q.y * 8.0 - t * 0.7)) * 0.12, 0.35, 0.01);

    // Circles: episodic — quiet, sparse, or storm
    let circles = ring_field(d0, t + fi * 0.7, theme, u.ring_amount);

    let fall = exp(-d0 * (1.35 + 0.1 * theme));
    final_color += col * (filament * 0.75 + circles) * (0.5 + 0.5 * fall);
  }

  // Tunnel ribs / depth rings over screen-space (layout-weighted)
  let tun = tunnel_structure(uv0 * (0.9 + 0.15 * sin(t * 0.2)), t, theme, layout_w);
  final_color += palette(length(uv0) * 0.4 + t * 0.2 + 0.3) * tun * 1.35;

  // Occasional outer halo only during ring storms
  let storm = smoothstep(1.0, 1.7, u.ring_amount);
  if (storm > 0.0) {
    var od = length(uv0) - (0.45 + 0.2 * sin(t * 0.7));
    od = abs(sin(od * 9.0 - t * 1.4)) / 9.0;
    final_color += palette(t * 0.15) * glow_ring(od, storm, 0.011) * 0.7;
  }

  // Vanishing-point bloom for tunnel layouts
  let tunnel_bloom = smoothstep(0.4, 1.2, layout_w);
  final_color += palette(t * 0.08 + 0.5) * (0.04 / (length(uv0) + 0.08)) * tunnel_bloom;

  final_color *= u.intensity;
  final_color = final_color / (1.0 + final_color * 0.35);
  final_color = pow(clamp(final_color, vec3f(0.0), vec3f(1.0)), vec3f(0.92));

  let pedestal = mix(vec3f(0.004, 0.006, 0.018), vec3f(0.012, 0.004, 0.010), theme / 5.0);
  final_color = pedestal + final_color;

  return vec4f(final_color, 1.0);
}
