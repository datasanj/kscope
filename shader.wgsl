// Holi kaleidoscope inspired by Electric Sheep (screensaver) — fragment-only, 4K@120 friendly.
// Units are effects (not sheep).
// Colorful layouts only (flock/truchet + 8 shippable shaders + gulal_pulse). Boring kaleido/tunnel/hybrid gone.
// See ATTRIBUTION.md for titles, authors, URLs, licenses.

struct Uniforms {
  resolution: vec2f,
  time: f32,
  seed: f32,
  mouse: vec2f,
  theme: f32,
  mirrors: f32,
  intensity: f32,
  // 0–10 prior colorful set; 11–23 MIT-port pass (see EFFECTS_ADDED.md)
  layout_mode: f32,
  ring_amount: f32,
  // 0..1 faux/mic audio drive for eelaudio; unused otherwise
  audio_level: f32,
  // 0 half-cost raymarch, 1 full (still capped for 4K)
  quality: f32,
  _pad1: f32,
  _pad2: f32,
  _pad3: f32,
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
  // Punchy gulal — slight lift, still short of whiteout
  return mix(a, b, s) * 1.05 + vec3f(0.03, 0.015, 0.025);
}

fn palette_theme(t: f32, theme: f32) -> vec3f {
  // Always a multi-powder Holi rainbow — never monochrome.
  // "rang" (full riot) is the base; pinned themes only nudge the bias.
  var col = rainbow(t) * 0.34
    + rainbow(t + 0.14) * 0.22
    + rainbow(t + 0.33) * 0.18
    + rainbow(t + 0.52) * 0.14
    + rainbow(t + 0.71) * 0.12;

  let th = floor(theme + 0.5);
  var bias = vec3f(1.08, 1.02, 1.06); // rang-like default
  var accent = 0.0;
  if (th < 0.5) {
    // gulabi — still keep saffron/green/blue sparks
    bias = vec3f(1.16, 0.90, 1.10);
    accent = 0.05;
  } else if (th < 1.5) {
    bias = vec3f(1.18, 0.88, 0.95);
    accent = 0.72;
  } else if (th < 2.5) {
    bias = vec3f(1.14, 1.06, 0.82);
    accent = 0.22;
  } else if (th < 3.5) {
    bias = vec3f(0.88, 1.16, 0.95);
    accent = 0.42;
  } else if (th < 4.5) {
    bias = vec3f(1.10, 1.04, 1.08);
    accent = 0.0;
  } else {
    bias = vec3f(0.92, 0.95, 1.18);
    accent = 0.58;
  }

  col *= bias;
  // Extra gulal lanes so every theme stays a riot
  col += rainbow(t * 1.7 + accent) * 0.28;
  col += rainbow(t * 0.55 + 0.41 + theme * 0.09) * 0.18;
  col += holi_powder(floor(t * 7.0 + theme + 2.0)) * 0.10;
  // Soft channel ceiling — vivid powder, not whiteout
  col = col / (1.0 + max(col - vec3f(0.92), vec3f(0.0)) * 1.55);
  return max(col, vec3f(0.0));
}

fn palette(t: f32) -> vec3f {
  return palette_theme(t, u.theme);
}

// Cosine palette — Inigo Quilez (MIT) — https://iquilezles.org/articles/palettes/
// Used for gulal_pulse multi-hue lanes; Holi powders still dominate the mix.
fn iq_cos_palette(t: f32, a: vec3f, b: vec3f, c: vec3f, d: vec3f) -> vec3f {
  return a + b * cos(TAU * (c * t + d));
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

fn mod3(p: vec2f, s: f32) -> vec2f { return vec2f(mod1(p.x, s), mod1(p.y, s)); }
fn mod3v(p: vec3f, s: f32) -> vec3f { return vec3f(mod1(p.x, s), mod1(p.y, s), mod1(p.z, s)); }

fn rot_xz(v: vec3f, a: f32) -> vec3f {
  let r = rotate2(v.xz, a);
  return vec3f(r.x, v.y, r.y);
}
fn rot_xy(v: vec3f, a: f32) -> vec3f {
  let r = rotate2(v.xy, a);
  return vec3f(r.x, r.y, v.z);
}
fn rot_yz(v: vec3f, a: f32) -> vec3f {
  let r = rotate2(v.yz, a);
  return vec3f(v.x, r.x, r.y);
}

// Hash without Sine — Dave Hoskins (MIT) — https://www.shadertoy.com/view/4djSRW
// Replaces the unknown sin-hash from the Mandala flowers listing.
fn hash21(p_in: vec2f) -> f32 {
  var p3 = fract(vec3f(p_in.x, p_in.y, p_in.x) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

fn hash22(p_in: vec2f) -> vec2f {
  var p3 = fract(vec3f(p_in.x, p_in.y, p_in.x) * vec3f(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

// GLSL-style mod (floor-based) — needed for polar folds with negative angles
fn mod1(x: f32, y: f32) -> f32 {
  return x - y * floor(x / y);
}

fn soft_glow(d: f32, k: f32) -> f32 {
  return exp(-abs(d) * k);
}

fn filmic_holi(c: vec3f) -> vec3f {
  let luma = max(dot(c, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  let mapped = luma * (1.02 / (1.0 + luma * 0.95));
  var out = c * (mapped / luma);
  out = out / (1.0 + max(out - vec3f(0.68), vec3f(0.0)) * 2.8);
  return out;
}

// ---------------------------------------------------------------------------
// Mandala flowers flock — WGSL port of Mårten Rånge "Mandala flowers" (CC0)
// Source ingested from nabeel-oz/glsl-to-mp4 references/MandalaFlowers.md
// (Shadertoy NlcSRB Image pass; header typo "CCO" = CC0). See ATTRIBUTION.md.
// Holi powder palettes replace hsv2rgb; hash/hextile rewritten (clear licenses).
// ---------------------------------------------------------------------------

const LOGO_RADIUS: f32 = 0.25;
const LOGO_OFF: f32 = 0.25;
const LOGO_DX: f32 = 0.5 / sqrt(3.0);
const LOGO_WIDTH: f32 = 0.1;

// License: MIT, Inigo Quilez — https://iquilezles.org/articles/distfunctions2d
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

// Axial / cube-round hex tiling — original reimplementation for kscope
// (standard geometry; not the Art of Code hextile listing).
fn axial_round(a: vec2f) -> vec2f {
  var x = a.x;
  var z = a.y;
  var y = -x - z;
  var rx = round(x);
  var ry = round(y);
  var rz = round(z);
  let x_diff = abs(rx - x);
  let y_diff = abs(ry - y);
  let z_diff = abs(rz - z);
  if (x_diff > y_diff && x_diff > z_diff) {
    rx = -ry - rz;
  } else if (y_diff > z_diff) {
    ry = -rx - rz;
  } else {
    rz = -rx - ry;
  }
  return vec2f(rx, rz);
}

fn hex_tile(p_in: vec2f) -> HexTile {
  // Pointy-top; size chosen so cell radius ≈ 0.5 (matches IQ hex(r=0.5) borders)
  let size = 0.5;
  let q = (sqrt(3.0) / 3.0 * p_in.x - (1.0 / 3.0) * p_in.y) / size;
  let r = ((2.0 / 3.0) * p_in.y) / size;
  let id = axial_round(vec2f(q, r));
  let center = vec2f(
    size * (sqrt(3.0) * id.x + sqrt(3.0) * 0.5 * id.y),
    size * (1.5 * id.y),
  );
  var out: HexTile;
  out.local = p_in - center;
  out.id = id;
  return out;
}

// License: MIT, Inigo Quilez — https://iquilezles.org/articles/smin
fn pmin(a: f32, b: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// License: CC0, Mårten Rånge — https://github.com/mrange/glsl-snippets
fn pmax(a: f32, b: f32, k: f32) -> f32 {
  return -pmin(-a, -b, k);
}

// License: CC0, Mårten Rånge — https://github.com/mrange/glsl-snippets
fn pabs(a: f32, k: f32) -> f32 {
  return pmax(a, -a, k);
}

// License: MIT (hg_sdf dual-licensed MIT OR CC-BY-NC-4.0 — we use MIT), mercury
fn mod_mirror1(p_in: f32, size: f32) -> vec2f {
  let halfsize = size * 0.5;
  let c = floor((p_in + halfsize) / size);
  var p = mod1(p_in + halfsize, size) - halfsize;
  p *= (mod1(c, 2.0) * 2.0 - 1.0);
  return vec2f(p, c);
}

// License: CC0, Mårten Rånge
fn to_polar(p: vec2f) -> vec2f {
  return vec2f(length(p), atan2(p.y, p.x));
}

// License: CC0, Mårten Rånge
fn to_rect(p: vec2f) -> vec2f {
  return vec2f(p.x * cos(p.y), p.x * sin(p.y));
}

// License: CC0, Mårten Rånge — smoothKaleidoscope
fn smooth_kaleidoscope(p_in: vec2f, sm: f32, rep: f32) -> vec2f {
  var hpp = to_polar(p_in);
  let mm = mod_mirror1(hpp.y, TAU / rep);
  hpp.y = mm.x;
  let sa = PI / rep - pabs(PI / rep - abs(hpp.y), sm);
  hpp.y = sign(hpp.y) * sa;
  return to_rect(hpp);
}

// License: MIT (hg_sdf), mercury — modPolar (returns folded p)
fn mod_polar(p_in: vec2f, repetitions: f32) -> vec2f {
  let angle = TAU / repetitions;
  var a = atan2(p_in.y, p_in.x) + angle * 0.5;
  let r = length(p_in);
  var c = floor(a / angle);
  a = mod1(a, angle) - angle * 0.5;
  if (abs(c) >= repetitions * 0.5) {
    c = abs(c);
  }
  return vec2f(cos(a), sin(a)) * r;
}

fn stripes(d_in: f32) -> f32 {
  let cc = 0.42;
  var d = abs(d_in) - LOGO_WIDTH * cc;
  d = abs(d) - LOGO_WIDTH * cc * 0.5;
  return d;
}

// Mandala flowers merge of two stroke layers (CC0 body)
fn merge_stroke(s0: vec4f, s1: vec4f) -> vec4f {
  let dt = s0.z < s1.z;
  var b = select(s1, s0, dt);
  let t = select(s0, s1, dt);
  b.x *= 1.0 - exp(-max(80.0 * t.w, 0.0));
  return vec4f(
    mix(b.xy, t.xy, t.y),
    select(t.z, b.z, b.w < t.w),
    min(b.w, t.w),
  );
}

fn figure_8(aa: f32, p: vec2f) -> vec4f {
  let p1 = p - vec2f(LOGO_DX, -LOGO_OFF);
  let d1 = abs(length(p1) - LOGO_RADIUS);
  let a1 = atan2(-p1.x, -p1.y);
  let s1 = stripes(d1);
  let o1 = d1 - LOGO_WIDTH;

  let p2 = p - vec2f(LOGO_DX, LOGO_OFF);
  let d2 = abs(length(p2) - LOGO_RADIUS);
  let a2 = atan2(p2.x, p2.y);
  let s2 = stripes(d2);
  let o2 = d2 - LOGO_WIDTH;

  let c0 = vec4f(smoothstep(aa, -aa, s1), smoothstep(aa, -aa, o1), a1, o1);
  let c1 = vec4f(smoothstep(aa, -aa, s2), smoothstep(aa, -aa, o2), a2, o2);
  return merge_stroke(c0, c1);
}

fn figure_half_8(aa: f32, p: vec2f) -> vec4f {
  let p1 = p - vec2f(LOGO_DX, -LOGO_OFF);
  let d1 = abs(length(p1) - LOGO_RADIUS);
  let a1 = atan2(-p1.x, -p1.y);
  let s1 = stripes(d1);
  let o1 = d1 - LOGO_WIDTH;
  return vec4f(smoothstep(aa, -aa, s1), smoothstep(aa, -aa, o1), a1, o1);
}

struct CLogo {
  color: vec3f,
  cover: f32,
  dist: f32,
}

// clogo petal assembly from Mandala flowers (CC0), Holi-colored
fn clogo(p_in: vec2f, z: f32, t: f32) -> CLogo {
  let iz = 1.0 / z;
  var p = p_in * iz;
  let aa = iz * 2.0 / max(u.resolution.y, 1.0);
  p = mod_polar(p, 3.0);

  var s0 = figure_8(aa, p);
  var s1 = figure_half_8(aa, rotate2(p, TAU / 3.0));
  let p_rot = rotate2(p, 2.0 * TAU / 3.0);
  var s2 = figure_half_8(aa, vec2f(p_rot.x, -p_rot.y));
  s1.z -= PI;

  var s = merge_stroke(s0, s1);
  s = merge_stroke(s, s2);

  // Riot Holi on angular petals — several gulal hues in one flower
  let hue_t = fract(s.z / PI + t * 0.5);
  let rgb = palette_theme(hue_t + u.theme * 0.05, u.theme) * 0.72
    + palette_theme(hue_t + 0.28, u.theme) * 0.28;
  var out: CLogo;
  out.color = rgb * max(s.x, 0.35) + rainbow(hue_t + 0.5) * s.x * 0.25;
  out.cover = s.y;
  out.dist = s.w;
  return out;
}

fn flock_effect(uv_in: vec2f) -> vec3f {
  let res = u.resolution;
  let t = u.time;
  let aa = 2.0 / max(res.y, 1.0);
  let q = uv_in;

  var p = (uv_in * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);

  // kscope mouse parallax (adaptation)
  let m = (u.mouse * 2.0 - 1.0) * vec2f(res.x / res.y, 1.0);
  p += m * 0.22;
  p = rotate2(p, m.x * 0.2 + m.y * 0.1);

  // Original Lissajous drift across the infinite hex field
  let a = TAU * t / 300.0;
  p += 10.0 * vec2f(sin(a), sin(sqrt(0.5) * a));

  let tile = hex_tile(p);
  var hp = tile.local;
  let np = tile.id + vec2f(u.seed * 1.7, u.seed * 0.9);

  var hd = sd_hex(hp.yx, 0.5);
  hd = abs(hd) - 2.0 * aa;

  var cp = hp;
  let h = hash21(np);
  let hh = fract(137.0 * h);
  // Per-cell unique smoothness + petal/mirror count (living flock)
  let sm = mix(mix(0.025, 0.25, hh), 0.025, h);
  // Original 16–60 even reps; genome mirrors nudge the range
  let rep = 2.0 * floor(mix(8.0, 30.0, h) + u.mirrors * 0.15);
  cp = smooth_kaleidoscope(cp, sm, rep);
  cp = rotate2(cp, t * 0.2 + TAU * h);

  let logo = clogo(cp, 0.6, t);
  // Multi-powder glow halo (replaces single hsv tint)
  let gcol = palette_theme(h + u.theme * 0.08, u.theme) * 1.8
    + rainbow(h + 0.37 + t * 0.04) * 1.1
    + holi_powder(floor(h * 7.0 + 3.0)) * 0.55;

  var col = vec3f(0.0);
  col += gcol * exp(-42.0 * max(logo.dist, 0.0));
  // Colorful hex seams instead of dull grey borders
  let border = palette_theme(h * 1.3 + t * 0.06, u.theme);
  col = mix(col, border * 0.55, smoothstep(aa, -aa, hd) * 0.65);
  col = mix(col, logo.color, logo.cover);
  // Cell floor wash — every hex holds Holi powder
  col += rainbow(h + np.x * 0.05 + t * 0.03) * soft_glow(length(hp) - 0.35, 6.0) * 0.22;

  // Ring episodes add more gulal, never sparse grey
  let ring = max(u.ring_amount, 0.35);
  col += palette(h + 0.35) * soft_glow(sd_hex(hp.yx, 0.48), 14.0) * ring * 0.35;
  col += rainbow(h + 0.6) * soft_glow(sd_hex(hp.yx, 0.35), 10.0) * 0.12;

  // Soft vignette (lighter than IQ postProcess — finish() handles filmic/Holi)
  let vig = 0.62 + 0.38 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);
  col *= vig;

  return col;
}

// ---------------------------------------------------------------------------
// Truchet + kaleidoscope — ORIGINAL WGSL inspired by the *idea* of combining
// smooth polar folds with Truchet-like cell arcs. NOT a paste of Shadertoy
// 7lKSWW (license unconfirmed for commercial paste). Holi genomes color lanes.
// ---------------------------------------------------------------------------

fn truchet_effect(uv_in: vec2f) -> vec3f {
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
  let w = 0.10 + 0.04 * sin(t * 1.4 + h * 10.0);
  let line = soft_glow(stroke - w, 22.0) + soft_glow(stroke, 7.0) * 0.55;

  // Loud multi-powder Holi per cell — never a thin single-hue neon
  let lane = (cell.x + cell.y * 0.37) * 0.11 + h * 0.55 + u.theme * 0.08 + t * 0.05;
  let c0 = palette_theme(lane, u.theme);
  let c1 = palette_theme(lane + 0.22, u.theme);
  let c2 = holi_powder(floor(h * 7.0));
  let c3 = holi_powder(floor(h * 7.0 + 3.0));
  var col = (c0 * 0.55 + c1 * 0.45) * (0.25 + line * 1.15);
  col += c2 * soft_glow(length(f) - 0.22, 9.0) * 0.45;
  col += c3 * soft_glow(stroke - w * 0.5, 16.0) * 0.35;
  col += rainbow(lane + 0.5) * soft_glow(min(d_arc_a, d_arc_b) - 0.12, 11.0) * 0.4;

  // Nested polar Holi bands
  let pr = length(q);
  col += palette(pr * 0.4 + t * 0.08) * soft_glow(abs(sin(pr * 5.0 - t)) - 0.1, 6.5) * 0.55;
  col += rainbow(atan2(q.y, q.x) / TAU + t * 0.05) * soft_glow(abs(q.y), 14.0) * 0.28;
  col += rainbow(pr * 0.2 + h) * 0.08;

  let ring = max(u.ring_amount, 0.4);
  col += palette(h + 0.5) * soft_glow(pr - (0.7 + 0.2 * sin(t)), 5.5) * ring * 0.55;

  return col;
}

fn finish(col_in: vec3f) -> vec4f {
  var final_color = col_in * u.intensity;
  // Slight saturation lift so gulal reads loud before filmic clamp
  let luma = max(dot(final_color, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  final_color = mix(vec3f(luma), final_color, 1.22);
  final_color = filmic_holi(final_color);
  final_color = pow(clamp(final_color, vec3f(0.0), vec3f(1.0)), vec3f(0.94));
  // Warm Holi pedestal — never cold cyan void
  let pedestal = vec3f(0.035, 0.012, 0.028) + rainbow(u.time * 0.02 + u.seed) * 0.03;
  final_color = pedestal + final_color * 0.97;
  return vec4f(final_color, 1.0);
}

// ---------------------------------------------------------------------------
// Extra colorful effect layouts (Holi-rainbow biased). Sources / licenses in
// ATTRIBUTION.md. Quality uniform: 0 = cheaper iteration caps, 1 = fuller.
// ---------------------------------------------------------------------------

fn quality_steps(base: i32, hi: i32) -> i32 {
  return select(base, hi, u.quality > 0.5);
}

fn mouse_aspect() -> vec2f {
  return (u.mouse * 2.0 - 1.0) * vec2f(u.resolution.x / max(u.resolution.y, 1.0), 1.0);
}

fn screen_p(uv_in: vec2f) -> vec2f {
  var p = (uv_in * 2.0 - 1.0) * vec2f(u.resolution.x / max(u.resolution.y, 1.0), 1.0);
  let m = mouse_aspect();
  p += m * 0.2;
  return p;
}

// ---- 2 Star Nest — MIT, Pablo Roman Andrioli (Kali) ----
// Primary source (prefer over Shadertoy.com):
//   references/StarNest.md  (from nabeel-oz/glsl-to-mp4)
//   begins: // Star Nest by Pablo Roman Andrioli / // License: MIT
//   Shadertoy URL for credit: https://www.shadertoy.com/view/XlfGRj
// Faithful WGSL port of that Image-pass; Holi powder remap after the MIT volume.

fn starnest_effect(uv_in: vec2f) -> vec3f {
  // --- constants from StarNest.md Image pass ---
  let iterations = quality_steps(13, 17); // original 17
  let formuparam = 0.53;
  let volsteps = quality_steps(14, 20);   // original 20
  let stepsize = 0.1;
  let zoom = 0.800;
  let tile = 0.850;
  let speed = 0.010;
  let brightness = 0.0015;
  let darkmatter = 0.300;
  let distfading = 0.730;
  let saturation = 0.850;

  // get coords and direction (StarNest.md)
  var uv = uv_in - vec2f(0.5);
  uv.y *= u.resolution.y / max(u.resolution.x, 1.0);
  var dir = vec3f(uv * zoom, 1.0);
  let time = u.time * speed + 0.25;

  // mouse rotation — u.mouse is already 0..1 (matches iMouse.xy/iResolution.xy)
  let a1 = 0.5 + u.mouse.x * 2.0;
  let a2 = 0.8 + u.mouse.y * 2.0;
  dir = rot_xz(dir, a1);
  dir = rot_xy(dir, a2);
  var origin = vec3f(1.0, 0.5, 0.5);
  origin += vec3f(time * 2.0, time, -2.0);
  origin = rot_xz(origin, a1);
  origin = rot_xy(origin, a2);

  // volumetric rendering
  var s = 0.1;
  var fade = 1.0;
  var v = vec3f(0.0);
  for (var r = 0; r < 20; r++) {
    if (r >= volsteps) { break; }
    var p = origin + s * dir * 0.5;
    // tiling fold — GLSL-style mod (floor-based)
    p = abs(vec3f(tile) - mod3v(p, tile * 2.0));
    var pa = 0.0;
    var a = 0.0;
    for (var i = 0; i < 17; i++) {
      if (i >= iterations) { break; }
      // the magic formula
      let r2 = max(dot(p, p), 1e-6);
      p = abs(p) / r2 - formuparam;
      let lp = length(p);
      a += abs(lp - pa); // absolute sum of average change
      pa = lp;
    }
    let dm = max(0.0, darkmatter - a * a * 0.001); // dark matter
    a = a * a * a; // add contrast
    if (r > 6) { fade *= 1.0 - dm; } // dark matter, don't render near
    v += vec3f(fade);
    v += vec3f(s, s * s, s * s * s * s) * a * brightness * fade; // coloring based on distance
    fade *= distfading; // distance fading
    s += stepsize;
  }
  // original color adjust
  v = mix(vec3f(length(v)), v, saturation);
  v *= 0.01;

  // kscope adaptation: Holi powder remap (keep MIT volume structure)
  let lum = max(length(v), 1e-4);
  var col = v * 0.35;
  col += palette_theme(lum * 3.0 + u.time * 0.04 + u.seed * 0.1, u.theme) * lum * 2.4;
  col += rainbow(lum * 2.0 + v.x * 4.0) * lum * 1.2;
  col += holi_powder(floor(lum * 11.0 + u.theme)) * lum * 0.55;
  return col;
}

// ---- 3 Golden Apollian (CC0 mrange WlcfRS) — Holi/golden apollonian field ----
// Technique aligned with secured Apollian-with-a-twist (CC0); φ-scaled fold.

fn apollonian_de(p_in: vec4f, s: f32) -> f32 {
  var p = p_in;
  var scale = 1.0;
  for (var i = 0; i < 7; i++) {
    p = -1.0 + 2.0 * fract(0.5 * p + 0.5);
    let r2 = max(dot(p, p), 1e-4);
    let k = s / r2;
    p *= k;
    scale *= k;
  }
  return abs(p.y) / scale;
}

fn golden_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  p = rotate2(p, t * 0.08);
  let phi = 1.6180339887;
  let tm = 0.2 * t;
  let r = 0.5;
  var pp = vec4f(p.x, p.y, 0.0, 0.0)
    + vec4f(r * (0.5 + 0.5 * sin(tm * sqrt(3.0))), r * (0.5 + 0.5 * sin(tm * sqrt(1.5))), r * (0.5 + 0.5 * sin(tm * sqrt(2.0))), 0.0);
  pp.w = 0.125 * (1.0 - tanh(length(pp.xyz)));
  let yz = rotate2(pp.yz, tm);
  pp = vec4f(pp.x, yz.x, yz.y, pp.w);
  let xz = rotate2(pp.xz, tm * sqrt(0.5));
  pp = vec4f(xz.x, pp.y, xz.y, pp.w);
  let z = 4.0;
  pp /= z;
  let d = apollonian_de(pp, 1.15 * phi / 1.5) * z * 0.5;
  let l = length(p);
  // Golden + Holi riot
  var col = palette_theme(0.22 + l * 0.7 - t * 0.08, u.theme);
  col = mix(col, holi_powder(1.0) * 1.2, 0.35); // kesar gold lean
  col = mix(col * (1.0 - tanh(0.75 * l)) * 0.55, col, smoothstep(0.02, -0.02, -d));
  col += rainbow(l * 0.8 + t * 0.1) * exp(-(12.0 + 80.0 * tanh(l)) * max(d, 0.0));
  col += holi_powder(2.0) * soft_glow(d, 40.0) * 0.8;
  return col * 1.15;
}

// ---- 4 Log spiral of spheres (CC0 mrange msGXRD) — Holi log-polar spheres ----

fn logspiral_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  p = rotate2(p, t * 0.05);
  let r0 = max(length(p), 1e-3);
  var lp = vec2f(log(r0), atan2(p.y, p.x));
  lp *= 1.35;
  lp.x += t * 0.35;
  lp.y += t * 0.12;
  let cell = floor(lp);
  var f = fract(lp) - 0.5;
  let h = hash21(cell + u.seed);
  // Sphere in log cell → concentric spiral beads
  let rad = 0.28 + 0.1 * sin(h * 20.0 + t);
  let d = length(f) - rad;
  let lane = cell.x * 0.08 + cell.y * 0.13 + h + t * 0.04;
  var col = palette_theme(lane, u.theme) * soft_glow(d, 18.0);
  col += rainbow(lane + 0.3) * soft_glow(d + 0.08, 10.0) * 0.8;
  col += holi_powder(floor(h * 7.0)) * soft_glow(abs(d) - 0.02, 40.0) * 0.9;
  // Radial Holi wash
  col += palette(r0 * 0.4 + t * 0.06) * (0.08 / (r0 + 0.15));
  return col;
}

// ---- 5 Apollian with a twist (CC0 mrange Wl3fzM) — from Shaderfuse kernel ----

fn apollo_twist_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let aa = 2.0 / max(u.resolution.y, 1.0);
  var p = screen_p(uv_in);
  let zoom = 0.5;
  p /= zoom;
  p = rotate2(p, t * 0.1);
  let tm = 0.2 * t;
  let r = 0.5;
  var pp = vec4f(p.x, p.y, 0.0, 0.0)
    + vec4f(r * (0.5 + 0.5 * sin(tm * sqrt(3.0))), r * (0.5 + 0.5 * sin(tm * sqrt(1.5))), r * (0.5 + 0.5 * sin(tm * sqrt(2.0))), 0.0);
  pp.w = 0.125 * (1.0 - tanh(length(pp.xyz)));
  let yz = rotate2(pp.yz, tm);
  pp = vec4f(pp.x, yz.x, yz.y, pp.w);
  let xz = rotate2(pp.xz, tm * sqrt(0.5));
  pp = vec4f(xz.x, pp.y, xz.y, pp.w);
  let z = 4.0;
  let d = apollonian_de(pp / z, 1.2) * z * zoom;
  let l = length(p * zoom);
  var col = palette_theme(0.75 * l - 0.3 * t + 0.3, u.theme);
  col *= (1.0 - tanh(0.75 * l)) * 0.5;
  col = mix(col, palette_theme(l * 1.1 + t * 0.05, u.theme), smoothstep(-aa, aa, -d));
  col += 0.55 * rainbow(l + t * 0.08) * exp(-(10.0 + 100.0 * tanh(l)) * max(d, 0.0));
  // Soft dual “lights”
  col += palette(0.1) * (1.0 - exp(-15.0 * max(d + 0.02, 0.0))) * 0.15;
  return col;
}

// ---- 6 Electric Eel Universe (CC0 mrange cdV3DW) — Holi cylinder eels ----
// From Shaderfuse ElectricEelUniverse.fuse (non-audio path). Helpers: MIT IQ cylinder.

fn ray_cylinder(ro: vec3f, rd: vec3f, cr: f32) -> vec2f {
  let ca = vec3f(0.0, 0.0, 1.0);
  let oc = ro;
  let card = dot(ca, rd);
  let caoc = dot(ca, oc);
  let a = 1.0 - card * card;
  let b = dot(oc, rd) - caoc * card;
  let c = dot(oc, oc) - caoc * caoc - cr * cr;
  let h = b * b - a * c;
  if (h < 0.0) { return vec2f(-1.0); }
  let hs = sqrt(h);
  return vec2f(-b - hs, -b + hs) / a;
}

fn dfcos2(p_in: vec2f, freq: f32) -> f32 {
  var x = p_in.x * freq;
  let y = p_in.y;
  let x1 = abs(mod1(x + PI, TAU) - PI);
  let x2 = abs(mod1(x, TAU) - PI);
  let a = 0.18 * freq;
  let xx1 = x1 / max(y * a + 1.0 - a, 1.0);
  let xx2 = x2 / max(-y * a + 1.0 - a, 1.0);
  let dcos = sqrt(xx1 * xx1 + 1.0) * 0.8 - 1.8;
  let dcos2v = sqrt(xx2 * xx2 + 1.0) * 0.8 - 1.8;
  return mix(-dcos2v - 1.0, dcos + 1.0, clamp(y * 0.5 + 0.5, 0.0, 1.0)) / max(freq * 0.8, 1.0)
    + max(abs(y) - 1.0, 0.0) * sign(y);
}

fn eel_core(uv_in: vec2f, audio: f32) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  let pp = p;
  let speed = 1.5 + audio * 3.5;
  let tm = speed * t + 12.3;
  var ro = vec3f(select(0.0, 1.0, audio > 0.05), 0.0, tm);
  var dro = normalize(vec3f(1.0, 0.0, 3.0) + vec3f(mouse_aspect() * vec2f(0.5), u.mirrors * 0.02));
  dro = rot_xz(dro, 0.2 * sin(0.05 * tm));
  dro = rot_yz(dro, 0.2 * sin(0.05 * tm * sqrt(0.5)));
  let ww = normalize(dro);
  let uu = normalize(cross(vec3f(0.0, 1.0, 0.0), ww));
  let vv = cross(ww, uu);
  var rd = normalize(-p.x * uu + p.y * vv + 2.0 * ww);
  rd = rot_xy(vec3f(rd.y, rd.x, rd.z), 0.1 * t);
  rd = vec3f(rd.y, rd.x, rd.z);

  // Holi sky / sun
  let ldir = normalize(vec3f(0.0, 0.0, -1.0));
  var col = palette_theme(0.6 + audio * 0.4, u.theme) * (0.004 / (1.00001 + dot(rd, ldir)));
  col *= 1.0 + audio * 1.5;

  let mm = 4.0;
  let a0 = atan2(rd.y, rd.x);
  for (var i = 0.0; i < 4.0; i += 1.0) {
    var ma = a0;
    let sz = 27.0 + i * 6.0;
    let slices = TAU / sz;
    let na = floor((ma + slices * 0.5) / slices);
    ma = mod1(ma + slices * 0.5, slices) - slices * 0.5;
    let h1 = hash21(vec2f(na + 13.0 * i, 123.4 + u.seed));
    let h2 = fract(h1 * 3677.0);
    let h3 = fract(h1 * 8677.0);
    let tr = mix(0.5, 3.0, h1);
    let tc = ray_cylinder(ro, rd, tr);
    if (tc.y < 0.0) { continue; }
    var tcp = ro + tc.y * rd;
    if (i == 2.0 && audio > 0.05) { tcp *= 2.0; }
    var tcp2 = vec2f(tcp.z, atan2(tcp.y, tcp.x));
    let zz = mix(0.025, 0.05, sqrt(h1)) * 27.0 / sz;
    tcp2.y = mod1(tcp2.y + slices * 0.5, slices) - slices * 0.5;
    let fo = smoothstep(0.5 * slices, 0.25 * slices, abs(tcp2.y));
    tcp2.x += -h2 * t * (1.0 + audio * 2.0);
    tcp2.y *= tr * PI / mix(3.0, 4.0, step(0.05, audio));
    tcp2 /= zz;
    var d = abs(dfcos2(tcp2, 2.0 * zz)) * zz;
    d *= mix(1.0, 0.55 + audio, step(0.05, audio));
    // Holi eel glow (was neon cos palette)
    var bcol = palette_theme(h3 + h2 * tcp.z * 0.05 + i * 0.1, u.theme) * 0.00008;
    bcol /= max(d * d, 5e-7 * tc.y * tc.y);
    bcol *= exp(-0.04 * tc.y * tc.y);
    bcol *= smoothstep(-0.5, 1.0, sin(mix(0.125, 1.0, h2) * tcp.z));
    bcol *= fo;
    bcol *= 1.0 + audio * 2.0;
    col += bcol * 40.0; // lift into Holi-visible range before filmic
  }
  col -= rainbow(0.2) * length(pp) * 0.05;
  return max(col, vec3f(0.0));
}

fn eel_effect(uv_in: vec2f) -> vec3f {
  return eel_core(uv_in, 0.0);
}

// ---- 7 Electric Eel audio fork (CC0 lineage cddSRM) — time/mic faux-reactive ----

fn eelaudio_effect(uv_in: vec2f) -> vec3f {
  // Prefer live audio_level; otherwise a lively faux beat so no-mic still works
  let faux = 0.55 + 0.45 * sin(u.time * 2.7) * sin(u.time * 1.3 + 1.7);
  let drive = max(u.audio_level, faux * 0.85);
  return eel_core(uv_in, clamp(drive, 0.0, 1.2));
}

// ---- 8 Let's self reflect (CC0 XfyXRV) — quality-gated mirrored Holi solid ----
// Full polyhedra+refraction port is heavy; this captures recursive mirror glow.

fn reflect_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  let steps = quality_steps(24, 40);
  var ro = vec3f(0.0, 0.15, -2.6);
  ro = rot_xz(ro, t * 0.15 + mouse_aspect().x);
  var rd = normalize(vec3f(p, 1.6));
  rd = rot_xz(rd, t * 0.15 + mouse_aspect().x);

  var col = vec3f(0.0);
  var atten = 1.0;
  var pos = ro;
  var dir = rd;
  for (var bounce = 0; bounce < 5; bounce++) {
    if (atten < 0.08) { break; }
    var tHit = 0.0;
    var hit = false;
    var n = vec3f(0.0, 1.0, 0.0);
    for (var i = 0; i < 40; i++) {
      if (i >= steps) { break; }
      let q = pos + dir * tHit;
      // Rounded octahedron / box hybrid
      let b = abs(q) - vec3f(0.85);
      let dBox = length(max(b, vec3f(0.0))) + min(max(b.x, max(b.y, b.z)), 0.0) - 0.08;
      let dSph = length(q) - 1.05;
      let d = mix(dBox, dSph, 0.35);
      if (d < 0.002) {
        hit = true;
        // cheap normal
        let e = 0.002;
        let qx = pos + dir * tHit;
        n = normalize(vec3f(
          length(abs(qx + vec3f(e, 0.0, 0.0))) - length(abs(qx - vec3f(e, 0.0, 0.0))),
          length(abs(qx + vec3f(0.0, e, 0.0))) - length(abs(qx - vec3f(0.0, e, 0.0))),
          length(abs(qx + vec3f(0.0, 0.0, e))) - length(abs(qx - vec3f(0.0, 0.0, e))),
        ));
        break;
      }
      tHit += d;
      if (tHit > 8.0) { break; }
    }
    let env = palette_theme(atan2(dir.z, dir.x) / TAU + dir.y * 0.3 + t * 0.04, u.theme);
    if (!hit) {
      col += env * atten * 0.85;
      break;
    }
    let fre = pow(1.0 - max(dot(-dir, n), 0.0), 3.0);
    col += env * fre * atten * 0.55;
    col += rainbow(tHit * 0.2 + f32(bounce) * 0.15) * atten * 0.2;
    dir = reflect(dir, n);
    pos = pos + dir * tHit + n * 0.01;
    atten *= 0.72;
  }
  col += palette(t * 0.05) * 0.05;
  return col;
}

// ---- 9 Reflective bubble tunnel (CC0 mrange wcyXzV) — Holi bubble corridor ----

fn bubble_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  let steps = quality_steps(28, 48);
  var ro = vec3f(0.0, 0.0, t * 0.8);
  var rd = normalize(vec3f(p, 1.4));
  rd = rot_xy(rd, mouse_aspect().x * 0.4);

  var col = vec3f(0.0);
  var travel = 0.0;
  for (var i = 0; i < 48; i++) {
    if (i >= steps) { break; }
    let q = ro + rd * travel;
    // Tunnel cylinder
    let tunnel = length(q.xy) - 1.15;
    // Bubbles along path
    let cellz = floor(q.z * 1.2);
    let fz = fract(q.z * 1.2) - 0.5;
    let h = hash21(vec2f(cellz, u.seed));
    let h2 = hash22(vec2f(cellz * 1.7, u.seed + 2.0));
    let center = vec3f((h2.x - 0.5) * 0.7, (h2.y - 0.5) * 0.7, (cellz + fz) / 1.2);
    let bub = length(q - center) - (0.18 + 0.1 * h);
    let d = min(abs(tunnel) * 0.5, bub);
    if (d < 0.002) {
      var n: vec3f;
      if (bub < abs(tunnel) * 0.5) {
        n = normalize(q - center);
      } else {
        n = normalize(vec3f(q.xy, 0.0));
      }
      let rdir = reflect(rd, n);
      let env = palette_theme(atan2(rdir.y, rdir.x) / TAU + rdir.z * 0.2 + t * 0.05, u.theme);
      let fres = pow(1.0 - max(dot(-rd, n), 0.0), 2.5);
      col = env * (0.45 + fres);
      col += rainbow(h + t * 0.08) * fres;
      col += holi_powder(floor(h * 7.0)) * soft_glow(bub, 30.0) * 0.5;
      break;
    }
    travel += d;
    if (travel > 12.0) {
      col = palette(t * 0.04 + length(p)) * 0.15;
      break;
    }
  }
  // Tunnel Holi fog
  col += rainbow(p.x * 0.3 + t * 0.05) * 0.06;
  return col;
}

// ---- 10 gulal_pulse — original Holi radial energy rings ----
// Inspired by the *feel* of concentric / radial-ring energy (kishimisu Quasar,
// Shadertoy msGyzc). Clean-room WGSL — not a paste, translate, or line-port.
// Upstream Quasar is CC BY-NC-SA; do not vendor its GLSL. See ATTRIBUTION.md.

fn gulal_pulse_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  // Slow orbital drift + kaleido wedges from genome mirrors
  p = rotate2(p, t * 0.055 + u.seed * 0.31);
  p = kaleido(p, max(u.mirrors, 3.0));

  let r = length(p);
  let ang = atan2(p.y, p.x);
  // Breathing shell spacing — hypnotic center pull without copying Quasar
  let breath = 0.5 + 0.5 * sin(t * 1.05 + u.seed * 1.7);
  let shell_n = mix(4.8, 8.2, breath);
  let wave = r * shell_n - t * (1.35 + 0.25 * breath);

  // Soft concentric shells + a slower secondary pulse
  var rings = exp(-7.5 * abs(sin(wave)));
  rings += 0.5 * exp(-11.0 * abs(sin(wave * 0.5 + ang * 0.35)));
  rings += 0.32 * exp(-16.0 * abs(fract(r * mix(2.6, 4.8, breath) - t * 0.38) - 0.5) * 2.0);

  // Mild radial filaments (energy spokes), mirror-count driven
  let spokes = exp(-5.5 * abs(sin(ang * max(u.mirrors, 3.0) - r * 2.4 + t * 0.9)));

  // Bright soft core
  let core = 0.14 / (r * r * 16.0 + 0.07);

  // Multi-hue: IQ cosine lanes (MIT) remixed with Holi powders — loud rainbow, not cyan-only
  let hue = r * 0.52 - t * 0.07 + ang / TAU + u.seed * 0.03;
  let cos_col = iq_cos_palette(
    hue,
    vec3f(0.55, 0.48, 0.55),
    vec3f(0.55, 0.50, 0.55),
    vec3f(1.0, 1.0, 0.95),
    vec3f(0.00, 0.33, 0.67),
  );
  var col = mix(cos_col, palette_theme(hue, u.theme), 0.62);
  col += holi_powder(floor(hue * 7.0 + 1.0)) * 0.38;
  col += rainbow(hue * 1.4 + 0.2) * 0.22;

  col *= rings * 1.4 + spokes * 0.42;
  col += palette_theme(hue + 0.18, u.theme) * core * 1.15;
  // Outer storm ring from ring_amount genome
  col += palette(hue + 0.45) * soft_glow(r - (0.78 + 0.12 * sin(t * 0.6)), 4.2) * u.ring_amount * 0.5;
  // Soft falloff glow toward edges
  col += rainbow(ang / TAU + t * 0.04) * (0.05 / (r + 0.22)) * 0.55;
  return col;
}

// ===========================================================================
// MIT-clear ports (this pass). Holi remap. See EFFECTS_ADDED.md / ATTRIBUTION.md.
// ===========================================================================

// ---- 11 rainbow_nest — Timmoth RainbowKaleidoscope (MIT) ----
// https://github.com/Timmoth/RainbowKaleidoscope  src/fragmentShader.glsl
// Holi remap of hsl2rgb path; fixed iteration cap for 4K.
fn rainbow_nest_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in) * 0.85;
  p = rotate2(p, t * 0.04 + u.seed);
  var pp = vec3f(p.x, p.y, 0.0);
  var f = t;
  let iters = quality_steps(18, 28);
  let shrink = 0.4 + sin(t * 0.1) / 20.0;
  for (var i = 0; i < 32; i++) {
    if (i >= iters) { break; }
    f += 0.5 / max(length(pp), 1e-4);
    let dp = dot(pp, pp);
    pp = abs(pp) / max(dp, 1e-4) - vec3f(shrink);
  }
  // Original used hsl2rgb(sin(f),…); Holi powder lanes instead
  var col = palette_theme(sin(f) * 0.5 + 0.5 + u.seed * 0.02, u.theme);
  col += holi_powder(floor(f * 0.35 + 3.0)) * 0.35;
  col += rainbow(f * 0.08) * 0.25;
  col *= 0.55 + 0.55 * soft_glow(length(p) - 0.9, 2.5);
  return col;
}

// ---- 12 glass_shard — zebiv-code/kaleidoscope (MIT) ----
// https://github.com/zebiv-code/kaleidoscope  web/js/shaders.js
// Shard chamber + polar fold; Holi tints; shard count quality-gated.
fn shard_sdf(q: vec2f, s: f32, typ: f32) -> f32 {
  if (typ < 1.0) {
    // triangle-ish
    let k = 1.73205080757;
    var p = q;
    p.x = abs(p.x) - s;
    p.y = p.y + s / k;
    if (p.x + k * p.y > 0.0) {
      p = vec2f(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    }
    p.x -= clamp(p.x, -2.0 * s, 0.0);
    return -length(p) * sign(p.y);
  } else if (typ < 2.0) {
    let ab = vec2f(s, s * 0.55);
    return (length(q / ab) - 1.0) * min(ab.x, ab.y);
  } else if (typ < 3.0) {
    let d = abs(q) - vec2f(s * 0.9, s * 0.45);
    return length(max(d, vec2f(0.0))) + min(max(d.x, d.y), 0.0) - s * 0.12;
  } else if (typ < 4.0) {
    return sd_hex(q, s * 0.85);
  }
  return max(length(q) - s, -(length(q - vec2f(s * 0.55, 0.0)) - s * 0.8));
}

fn glass_shard_effect(uv_in: vec2f) -> vec3f {
  let t = u.time * 0.55;
  var uv = screen_p(uv_in);
  let rr = length(uv);
  var p = uv * 0.95;
  // old-glass wobble
  p += 0.012 * (vec2f(hash21(p * 3.0 + t * 0.2), hash21(p * 3.0 + 7.7 - t * 0.15)) - 0.5) * 2.0;

  let segs = max(u.mirrors, 3.0);
  let seg = PI / segs;
  var a = atan2(p.y, p.x);
  a = abs(mod1(a, 2.0 * seg) - seg);
  let folded = vec2f(cos(a), sin(a)) * length(p);

  // backlight
  var col = mix(vec3f(0.99, 0.96, 0.89), vec3f(0.68, 0.75, 0.88), smoothstep(0.0, 1.4, length(folded)));
  col = mix(col, palette_theme(0.15 + u.theme * 0.05, u.theme), 0.35);
  col *= 0.90 + 0.10 * hash21(folded * 9.0 + u.seed * 13.0);

  let n_shards = quality_steps(10, 18);
  let px = 0.004;
  for (var i = 0; i < 24; i++) {
    if (i >= n_shards) { break; }
    let fi = f32(i);
    let h = hash21(vec2f(fi * 7.13, u.seed * 101.0));
    let h2 = hash22(vec2f(fi * 3.71, u.seed * 57.0));
    let h3 = hash22(vec2f(fi * 9.23, u.seed * 23.0));
    let rc = 0.06 + 0.92 * h2.x;
    let dir = select(-1.0, 1.0, h < 0.5);
    let th = h2.y * TAU + t * (0.08 + 0.22 * h3.x) * dir;
    let c = vec2f(cos(th), sin(th)) * rc
      + 0.16 * vec2f(cos(t * 0.7 + fi * 2.1), sin(t * 0.9 + fi * 1.7));
    let phi = h3.y * TAU + t * (0.15 + 0.45 * h) * select(-1.0, 1.0, h2.x < 0.5);
    let q = rotate2(folded - c, phi);
    let s = 0.08 + 0.22 * fract(h * 5.0);
    let typ = floor(fract(h * 13.0) * 5.0);
    let d = shard_sdf(q, s, typ);
    let cov = smoothstep(px, -px, d);
    var tint = palette_theme(fi * 0.11 + h + u.theme * 0.05, u.theme);
    tint = clamp(tint + (h2.y - 0.5) * 0.16, vec3f(0.0), vec3f(1.2));
    let density = 0.66 + 0.28 * h3.y;
    col *= mix(vec3f(1.0), tint, density * cov);
    col += tint * hash21(q * 14.0 + t * 0.6 + fi) * cov * 0.12;
    let edge = smoothstep(0.020, 0.0, abs(d + 0.005));
    let glint = 0.5 + 0.5 * sin(phi * 3.0 + th * 2.0 + t * 1.4 + fi);
    col += vec3f(1.0, 0.98, 0.90) * edge * glint * 0.55;
  }
  // seam glow
  let m = abs(mod1(atan2(p.y, p.x), 2.0 * seg) - seg);
  let dE = min(m, seg - m) * length(p);
  col += palette(0.7) * smoothstep(0.014, 0.0, dE) * 0.2;
  col *= 1.0 - 0.35 * smoothstep(0.62, 0.985, rr);
  return col;
}

// ---- 13 dream_fold — modelmiser/mm-dream (MIT) ----
// https://github.com/modelmiser/mm-dream  src/dream.wgsl
// Fold + Holi synthetic bars (no CRT/CPU bar uniforms).
fn dream_fold_coords(sx: f32, sy: f32, fc: f32, angle: f32, t: f32) -> vec2f {
  let r = sqrt(sx * sx + sy * sy);
  let theta = atan2(sy, sx);
  let sector = TAU / max(fc, 2.0);
  let t_shifted = theta - angle;
  var t_in = t_shifted - sector * floor(t_shifted / sector);
  var t_folded = select(t_in, sector - t_in, t_in > sector * 0.5);
  t_folded += angle;
  let r_threshold = 0.4 + 0.2 * sin(t * 0.3);
  let folded_r = abs(r - r_threshold) + r_threshold * 0.5;
  return vec2f(folded_r * cos(t_folded), folded_r * sin(t_folded));
}

fn dream_fold_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in);
  let fc = max(u.mirrors, 3.0);
  let angle = t * 0.12 + u.seed;
  let f = dream_fold_coords(p.x, p.y, fc, angle, t);
  // Synthetic Holi bars in folded space
  let y = (f.y * 0.5 + 0.5) * 10.0;
  let x = f.x * 0.5 + 0.5;
  var col = vec3f(0.0);
  var sum_w = 0.0;
  for (var i = 0; i < 10; i++) {
    let fi = f32(i);
    let bar_y = fi + 0.5 + 0.35 * sin(t * 1.2 + fi * 0.7 + x * TAU * 1.618);
    let dist = abs(y - bar_y);
    let half = 0.55;
    if (dist < half) {
      let intensity = cos(dist / half * PI_2);
      let bloom = pow(1.0 - dist / half, 3.0);
      var c = palette_theme(fi * 0.09 + t * 0.03 + u.theme * 0.04, u.theme);
      c += holi_powder(fi) * bloom * 0.45;
      col += c * intensity;
      sum_w += intensity;
    }
  }
  if (sum_w > 0.0) {
    col /= sum_w;
  }
  // Screen-blend a rotated sample (mm-dream H+V idea)
  let f2 = dream_fold_coords(p.y, -p.x, fc, -angle * 0.7, t);
  let y2 = (f2.y * 0.5 + 0.5) * 10.0;
  var col2 = palette_theme(y2 * 0.08 + 0.2, u.theme) * soft_glow(fract(y2) - 0.5, 8.0);
  col = vec3f(1.0) - (vec3f(1.0) - col) * (vec3f(1.0) - col2 * 0.65);
  col += rainbow(atan2(p.y, p.x) / TAU + t * 0.04) * 0.08;
  return col;
}

// ---- 14–22 WebGL-Shader-Playground presets (README MIT badge) ----
// https://github.com/heyimjames/WebGL-Shader-Playground  main.js SHADERS.*
// Holi palette remap; no LICENSE file in upstream — badge + user listing.

fn play_kaleido_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var st = screen_p(uv_in);
  st = kaleido(st, max(u.mirrors, 3.0));
  let d = length(st);
  var color = vec3f(0.0);
  let complexity = 1.2;
  for (var i = 0; i < 3; i++) {
    let fi = f32(i);
    var p = st * (2.0 + fi * complexity);
    p = fract(p + t * 0.1 + fi * 0.1);
    var pattern = sin(p.x * 10.0) * sin(p.y * 10.0);
    pattern += sin(distance(p, vec2f(0.5)) * 20.0 - t * 2.0);
    color += palette_theme(pattern * 0.15 + fi * 0.2 + t * 0.05, u.theme) / (3.0 + d * 2.0);
  }
  let m = mouse_aspect() * 0.5;
  color += (1.0 - smoothstep(0.0, 0.5, length(st - m))) * palette(0.4) * 0.25;
  return color;
}

fn play_plasma_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let st = uv_in;
  let freq = 4.5;
  var v = sin((st.x + t) * freq);
  v += sin((st.y + t) * freq);
  v += sin((st.x + st.y + t) * freq);
  v += sin(sqrt(st.x * st.x + st.y * st.y + 1.0) * freq);
  v *= 0.5;
  var col = palette_theme(v * 0.35 + 0.5 + t * 0.03, u.theme);
  col += rainbow(v * 0.2 + u.theme * 0.05) * 0.35;
  return col;
}

fn play_lava_effect(uv_in: vec2f) -> vec3f {
  let t = u.time * 0.7;
  let st = uv_in;
  let size = 0.22;
  let b1 = smoothstep(size, size * 0.5, length(st - vec2f(0.5 + sin(t) * 0.3, 0.5 + cos(t * 0.7) * 0.3)));
  let b2 = smoothstep(size * 0.8, size * 0.4, length(st - vec2f(0.5 + cos(t * 0.8) * 0.3, 0.5 + sin(t * 0.9) * 0.3)));
  let b3 = smoothstep(size * 1.2, size * 0.6, length(st - vec2f(0.5 + sin(t * 1.1) * 0.2, 0.5 + cos(t * 1.3) * 0.2)));
  let b4 = smoothstep(size * 0.9, size * 0.45, length(st - vec2f(0.5 + cos(t * 0.6) * 0.25, 0.5 + sin(t * 0.5) * 0.25)));
  var blobs = smoothstep(0.4, 0.6, b1 + b2 + b3 + b4);
  var col = mix(palette_theme(0.75, u.theme) * 0.35, palette_theme(0.05 + t * 0.02, u.theme), blobs);
  col = mix(col, holi_powder(1.0) * 1.1, 0.5 + 0.5 * sin(blobs * PI + t));
  col += rainbow(st.y + t * 0.05) * 0.08;
  return col;
}

fn play_aurora_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let st = uv_in;
  let x = st.x;
  let y = st.y;
  var bands = sin(x * 3.0 + t) * 0.1 + sin(x * 5.0 - t * 0.7) * 0.15 + sin(x * 7.0 + t * 1.3) * 0.1 + 0.5;
  bands += sin(x * 2.0 + t * 0.1) * sin(t * 0.2) * 0.12;
  var aurora = exp(-abs(y - bands) * 5.0);
  aurora += exp(-abs(y - bands) * 10.0) * 0.5;
  aurora += exp(-abs(y - bands) * 20.0) * 0.25;
  var col = palette_theme(bands + t * 0.04, u.theme) * aurora * 1.35;
  col += holi_powder(3.0) * aurora * 0.35;
  col += holi_powder(0.0) * aurora * 0.2;
  let stars = pow(hash21(floor(st * 100.0)), 20.0) * (1.0 - aurora);
  col += vec3f(stars);
  col += rainbow(x * 0.3) * (1.0 - y) * 0.08;
  return col;
}

fn play_galaxy_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let st = screen_p(uv_in);
  let r = length(st);
  let a = atan2(st.y, st.x);
  let arms = clamp(u.mirrors, 3.0, 8.0);
  var spiral = 0.0;
  for (var i = 0; i < 8; i++) {
    if (f32(i) >= arms) { break; }
    let arm_angle = a + f32(i) * TAU / arms + r * 2.2 + t * 0.1;
    var arm = sin(arm_angle) * 0.5 + 0.5;
    arm = pow(arm, 3.0) * exp(-r * 2.0);
    spiral += arm;
  }
  var stars = 0.0;
  var star_pos = st * 50.0;
  for (var i = 0; i < 3; i++) {
    let n = hash21(floor(star_pos) + f32(i) * 100.0);
    stars += pow(n, 20.0);
    star_pos *= 2.0;
  }
  let core = exp(-r * 3.0);
  var col = palette_theme(0.6 + spiral * 0.3, u.theme) * spiral;
  col += rainbow(a / TAU + t * 0.02) * stars * 0.9;
  col += holi_powder(1.0) * core * 0.9;
  col += palette(hash21(st * 5.0 + t * 0.05)) * (1.0 - r) * 0.2;
  return col;
}

fn play_holo_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let st = uv_in;
  let wf = 8.0;
  let wave1 = sin(st.x * wf + t) * 0.5 + 0.5;
  let wave2 = sin(st.y * wf * 0.7 + t * 1.3) * 0.5 + 0.5;
  let wave3 = sin((st.x + st.y) * wf * 0.5 + t * 0.8) * 0.5 + 0.5;
  let interference = wave1 * wave2 * wave3;
  let hue = interference + st.x * 0.3 + st.y * 0.2 + t * 0.1;
  var col = palette_theme(hue, u.theme);
  col += rainbow(hue * 1.2) * 0.35;
  let sheen = pow(wave1 * wave2, 2.0);
  col += vec3f(sheen) * 0.2;
  let sparkle = pow(hash21(floor(st * 100.0) + floor(t * 10.0)), 20.0);
  col += vec3f(sparkle);
  col *= 1.0 - length(st - 0.5) * 0.45;
  return col;
}

fn play_waves_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  let st = uv_in;
  let m = u.mouse;
  var wave = 0.0;
  let count = 6.0;
  for (var i = 0; i < 10; i++) {
    if (f32(i) >= count) { break; }
    let fi = f32(i);
    let center = vec2f(0.5 + 0.4 * sin(t * 0.3 + fi), 0.5 + 0.4 * cos(t * 0.3 + fi * 1.3));
    wave += sin(distance(st, center) * 20.0 - t * 2.2) / (fi + 1.0);
  }
  wave += sin(distance(st, m) * 30.0 - t * 3.3);
  var col = palette_theme(0.5 + 0.35 * wave, u.theme);
  col += rainbow(wave * 0.15 + t * 0.03) * 0.4;
  return col;
}

fn play_voronoi_effect(uv_in: vec2f) -> vec3f {
  let t = u.time * 0.8;
  var st = uv_in * mix(4.0, 7.0, fract(u.seed));
  // Mild kaleido so it matches Holi vibe
  let p0 = screen_p(uv_in);
  let folded = kaleido(p0, max(u.mirrors, 3.0));
  st = (folded * 0.5 + 0.5) * 5.5;
  let i_st = floor(st);
  let f_st = fract(st);
  var m_dist = 1.0;
  var m_point = vec2f(0.0);
  for (var y = -1; y <= 1; y++) {
    for (var x = -1; x <= 1; x++) {
      let neighbor = vec2f(f32(x), f32(y));
      var point = hash22(i_st + neighbor);
      point = 0.5 + 0.5 * sin(t + TAU * point);
      let diff = neighbor + point - f_st;
      let dist = length(diff);
      if (dist < m_dist) {
        m_dist = dist;
        m_point = point;
      }
    }
  }
  var col = palette_theme(m_dist * 1.2 + m_point.x * 0.4 + t * 0.02, u.theme);
  col += holi_powder(floor(m_point.y * 7.0)) * (1.0 - m_dist) * 0.55;
  col += rainbow(m_point.x + m_point.y) * soft_glow(m_dist - 0.15, 12.0) * 0.5;
  return col;
}

fn play_neon_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var st = uv_in * 2.0 - 1.0;
  st.y = st.y * 0.5 + 0.5;
  let perspective = st.y * 0.5 + 0.15;
  st.x /= max(perspective, 0.05);
  st = st * 0.5 + 0.5;
  st.y += t * 0.12;
  let grid = fract(st * 12.0);
  let lw = 0.06;
  let line_x = smoothstep(0.0, lw, grid.x) * smoothstep(1.0, 1.0 - lw, grid.x);
  let line_y = smoothstep(0.0, lw, grid.y) * smoothstep(1.0, 1.0 - lw, grid.y);
  let lines = 1.0 - max(line_x, line_y);
  var col = palette_theme(st.y + t * 0.05, u.theme) * lines * 1.4;
  col += holi_powder(6.0) * lines * 0.45;
  col += rainbow(st.x + t * 0.08) * lines * 0.35;
  col *= 1.0 - clamp(st.y * 0.45, 0.0, 0.85);
  return col;
}

// ---- 23 fold_mirror — brogli/Kaleidoscope fold (MIT), Holi generative fill ----
// https://github.com/brogli/Kaleidoscope — polar slice fold (was texture sample).
fn fold_mirror_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var position = screen_p(uv_in) * 1.35;
  let r = length(position);
  var angle = atan2(position.x, position.y);
  if (angle < 0.0) { angle += TAU; }
  let slices = max(u.mirrors, 3.0);
  let slice = TAU / slices;
  angle = mod1(angle, slice);
  angle = abs(angle - 0.5 * slice);
  angle += t * 0.15 + u.seed;
  position = vec2f(cos(angle), sin(angle)) * r;
  // brogli bounce fold
  position = max(min(position, 2.0 - position), -position);
  // Generative Holi fill instead of sampling a scene texture
  let q = position * 0.8;
  let pattern = sin(q.x * 6.0 + t) * cos(q.y * 6.0 - t * 0.7)
    + sin(length(q) * 10.0 - t * 1.5);
  var col = palette_theme(pattern * 0.12 + angle * 0.1 + t * 0.04, u.theme);
  col += holi_powder(floor(pattern * 2.0 + 4.0)) * 0.4;
  col += rainbow(r * 0.4 + t * 0.05) * soft_glow(abs(pattern) - 0.3, 4.0) * 0.55;
  col += palette(0.2) * (0.08 / (r + 0.2));
  return col;
}

@fragment
fn fs_main(@location(0) uv_in: vec2f) -> @location(0) vec4f {
  let lo = i32(floor(u.layout_mode + 0.5));
  var col: vec3f;
  switch lo {
    case 1: { col = truchet_effect(uv_in); }
    case 2: { col = starnest_effect(uv_in); }
    case 3: { col = golden_effect(uv_in); }
    case 4: { col = logspiral_effect(uv_in); }
    case 5: { col = apollo_twist_effect(uv_in); }
    case 6: { col = eel_effect(uv_in); }
    case 7: { col = eelaudio_effect(uv_in); }
    case 8: { col = reflect_effect(uv_in); }
    case 9: { col = bubble_effect(uv_in); }
    case 10: { col = gulal_pulse_effect(uv_in); }
    case 11: { col = rainbow_nest_effect(uv_in); }
    case 12: { col = glass_shard_effect(uv_in); }
    case 13: { col = dream_fold_effect(uv_in); }
    case 14: { col = play_kaleido_effect(uv_in); }
    case 15: { col = play_plasma_effect(uv_in); }
    case 16: { col = play_lava_effect(uv_in); }
    case 17: { col = play_aurora_effect(uv_in); }
    case 18: { col = play_galaxy_effect(uv_in); }
    case 19: { col = play_holo_effect(uv_in); }
    case 20: { col = play_waves_effect(uv_in); }
    case 21: { col = play_voronoi_effect(uv_in); }
    case 22: { col = play_neon_effect(uv_in); }
    case 23: { col = fold_mirror_effect(uv_in); }
    default: { col = flock_effect(uv_in); }
  }
  return finish(col);
}
