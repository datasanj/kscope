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

// Holi gulal powder swatches — neon-max saturation (no pastel / mud)
fn holi_powder(i: f32) -> vec3f {
  let k = i32(floor(i)) % 7;
  if (k == 0) { return vec3f(1.00, 0.06, 0.52); } // gulabi pink
  if (k == 1) { return vec3f(1.00, 0.38, 0.00); } // kesar saffron
  if (k == 2) { return vec3f(1.00, 0.92, 0.02); } // haldi yellow
  if (k == 3) { return vec3f(0.02, 1.00, 0.18); } // hari green
  if (k == 4) { return vec3f(0.08, 0.22, 1.00); } // neela electric blue
  if (k == 5) { return vec3f(1.00, 0.04, 0.08); } // laal red
  return vec3f(0.82, 0.02, 1.00);                 // fuchsia / violet
}

// Mouse → Holi color cycle (not pan). X+Y drive palette phase + theme bias mix.
fn mouse_color_phase() -> f32 {
  return fract(u.mouse.x * 0.92 + u.mouse.y * 0.48 + u.mouse.x * u.mouse.y * 0.15);
}

fn mouse_theme_mix(theme: f32) -> f32 {
  // Smoothly walk theme bias across powders while keeping pinned theme as anchor
  return theme + mouse_color_phase() * 5.0;
}

fn rainbow(t: f32) -> vec3f {
  let x = fract(t + u.seed * 0.017 + mouse_color_phase());
  let n = x * 7.0;
  let i = floor(n);
  let f = fract(n);
  // Sharp powder borders — wide pure lanes, short blend (avoids brown mud)
  let s = smoothstep(0.12, 0.88, f);
  let a = holi_powder(i);
  let b = holi_powder(i + 1.0);
  return mix(a, b, s) * 1.15;
}

fn palette_theme(t: f32, theme: f32) -> vec3f {
  // Dominant powder + one accent — never 5-way average (that washed to gray-brown).
  // Mouse phase shifts hue lanes; pinned themes still nudge bias. Always multi-hue.
  let phase = mouse_color_phase();
  let tt = t + phase;
  let theme_m = mouse_theme_mix(theme);
  var col = rainbow(tt) * 0.78
    + rainbow(tt + 0.42) * 0.32;
  col += holi_powder(floor(tt * 7.0 + theme_m)) * 0.28;

  let th = mod1(floor(theme_m + 0.5), 6.0);
  var bias = vec3f(1.14, 1.06, 1.12); // rang — loud full riot
  var accent = 0.0;
  if (th < 0.5) {
    // gulabi — pink-forward, keep saffron/green/blue sparks
    bias = vec3f(1.28, 0.82, 1.18);
    accent = 0.05;
  } else if (th < 1.5) {
    bias = vec3f(1.32, 0.78, 0.88);
    accent = 0.72;
  } else if (th < 2.5) {
    bias = vec3f(1.26, 1.12, 0.72);
    accent = 0.22;
  } else if (th < 3.5) {
    bias = vec3f(0.78, 1.30, 0.88);
    accent = 0.42;
  } else if (th < 4.5) {
    bias = vec3f(1.18, 1.08, 1.16);
    accent = 0.0;
  } else {
    bias = vec3f(0.82, 0.88, 1.32);
    accent = 0.58;
  }

  col *= bias;
  // Extra gulal sparks so every theme stays a riot (not a washed pastel)
  col += rainbow(tt * 1.7 + accent) * 0.38;
  col += holi_powder(floor(tt * 7.0 + theme_m + 2.0)) * 0.20;
  col += rainbow(tt * 0.55 + 0.41 + theme_m * 0.09) * 0.12;
  // Soft knee only past HDR white — midtones keep full chroma
  col = col / (1.0 + max(col - vec3f(1.25), vec3f(0.0)) * 0.75);
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
  // Chroma-preserving soft knee — old path crushed at 0.68 and killed gulal.
  // Only compress extreme HDR; then restore / boost saturation.
  let knee = 1.35;
  var out = c / (1.0 + max(c - vec3f(knee), vec3f(0.0)) * 1.05);
  let luma = max(dot(out, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  let mapped = luma / (1.0 + max(luma - 1.25, 0.0) * 0.5);
  out *= mapped / luma;
  let l2 = max(dot(out, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  out = mix(vec3f(l2), out, 1.38);
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
  let rgb = palette_theme(hue_t + u.theme * 0.05, u.theme) * 0.78
    + palette_theme(hue_t + 0.28, u.theme) * 0.32;
  var out: CLogo;
  out.color = rgb * max(s.x, 0.42) + rainbow(hue_t + 0.5) * s.x * 0.4;
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

  // Original Lissajous drift across the infinite hex field
  // (Mouse drives Holi color cycle globally — not pan/orbit.)
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

  // Soft vignette — keep corners dark for contrast, don't crush mid-powder
  let vig = 0.78 + 0.22 * pow(19.0 * q.x * q.y * (1.0 - q.x) * (1.0 - q.y), 0.7);
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
  p = rotate2(p, t * 0.05);

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
  var col = (c0 * 0.55 + c1 * 0.45) * (0.42 + line * 1.35);
  col += c2 * soft_glow(length(f) - 0.22, 9.0) * 0.65;
  col += c3 * soft_glow(stroke - w * 0.5, 16.0) * 0.5;
  col += rainbow(lane + 0.5) * soft_glow(min(d_arc_a, d_arc_b) - 0.12, 11.0) * 0.55;

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
  // Hard sat lift — Electric-Sheep-alive gulal, not pastel
  let luma = max(dot(final_color, vec3f(0.2126, 0.7152, 0.0722)), 1e-4);
  final_color = mix(vec3f(luma), final_color, 1.48);
  // Crush muddy floor toward deep black vs neon powder
  final_color = max(final_color - vec3f(0.025), vec3f(0.0)) * 1.14;
  final_color = filmic_holi(final_color);
  // Slightly steeper than linear — punchier contrast (0.94 was lifting shadows dull)
  final_color = pow(clamp(final_color, vec3f(0.0), vec3f(1.0)), vec3f(1.06));
  // Near-black void + tiny powder sparkle (no gray-brown pedestal)
  let spark = rainbow(u.time * 0.02 + u.seed) * 0.01;
  final_color = clamp(final_color * 0.995 + spark, vec3f(0.0), vec3f(1.0));
  return vec4f(final_color, 1.0);
}

// ---------------------------------------------------------------------------
// Extra colorful effect layouts (Holi-rainbow biased). Sources / licenses in
// ATTRIBUTION.md. Quality uniform: 0 = cheaper iteration caps, 1 = fuller.
// ---------------------------------------------------------------------------

fn quality_steps(base: i32, hi: i32) -> i32 {
  return select(base, hi, u.quality > 0.5);
}

fn screen_p(uv_in: vec2f) -> vec2f {
  // Aspect-correct screen coords — no mouse pan/parallax (mouse → color only)
  return (uv_in * 2.0 - 1.0) * vec2f(u.resolution.x / max(u.resolution.y, 1.0), 1.0);
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
  col = mix(col * (1.0 - tanh(0.75 * l)) * 0.72, col, smoothstep(0.02, -0.02, -d));
  col += rainbow(l * 0.8 + t * 0.1) * exp(-(12.0 + 80.0 * tanh(l)) * max(d, 0.0)) * 1.25;
  col += holi_powder(2.0) * soft_glow(d, 40.0) * 1.05;
  return col * 1.28;
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
  col *= (1.0 - tanh(0.75 * l)) * 0.72;
  col = mix(col, palette_theme(l * 1.1 + t * 0.05, u.theme), smoothstep(-aa, aa, -d));
  col += 0.85 * rainbow(l + t * 0.08) * exp(-(10.0 + 100.0 * tanh(l)) * max(d, 0.0));
  // Soft dual “lights”
  col += palette(0.1) * (1.0 - exp(-15.0 * max(d + 0.02, 0.0))) * 0.28;
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
  var dro = normalize(vec3f(1.0, 0.0, 3.0) + vec3f(0.0, 0.0, u.mirrors * 0.02));
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

  // Multi-hue: IQ cosine lanes (MIT) remixed with Holi powders — loud rainbow, not gray mid
  let hue = r * 0.52 - t * 0.07 + ang / TAU + u.seed * 0.03;
  let cos_col = iq_cos_palette(
    hue,
    vec3f(0.55, 0.35, 0.45),
    vec3f(0.55, 0.55, 0.55),
    vec3f(1.0, 1.0, 1.0),
    vec3f(0.00, 0.33, 0.67),
  );
  // Prefer Holi palette; cosine only for shimmer (gray a=0.55 was washing the look)
  var col = mix(cos_col, palette_theme(hue, u.theme), 0.82);
  col += holi_powder(floor(hue * 7.0 + 1.0)) * 0.55;
  col += rainbow(hue * 1.4 + 0.2) * 0.35;

  col *= rings * 1.55 + spokes * 0.5;
  col += palette_theme(hue + 0.18, u.theme) * core * 1.35;
  // Outer storm ring from ring_amount genome
  col += palette(hue + 0.45) * soft_glow(r - (0.78 + 0.12 * sin(t * 0.6)), 4.2) * u.ring_amount * 0.5;
  // Soft falloff glow toward edges
  col += rainbow(ang / TAU + t * 0.04) * (0.05 / (r + 0.22)) * 0.55;
  return col;
}


// ===========================================================================
// Corrective pass — mrange CC0 ports (Shaderfuse SoTW quotes author CC0:).
// Holi remap. Rejected toy-kaleido MIT set removed. See EFFECTS_ADDED.md.
// ===========================================================================

fn vnoise2(p: vec2f) -> f32 {
  let i = floor(p);
  let f = fract(p);
  let u = f * f * (3.0 - 2.0 * f);
  let a = hash21(i);
  let b = hash21(i + vec2f(1.0, 0.0));
  let c = hash21(i + vec2f(0.0, 1.0));
  let d = hash21(i + vec2f(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn hifbm(p_in: vec2f) -> f32 {
  // Continuous value-noise FBM (no UV snapping) — hills stay soft at full res
  var p = p_in;
  var sum = 0.0;
  var a = 1.0;
  var norm = 0.0;
  for (var i = 0; i < 6; i++) {
    sum += a * vnoise2(p);
    norm += a;
    a *= 0.5;
    p = p * 2.03 + vec2f(17.1, 9.3);
  }
  return sum / max(norm, 1e-4);
}

fn tanh_approx(x: f32) -> f32 {
  let x2 = x * x;
  return clamp(x * (27.0 + x2) / (27.0 + 9.0 * x2), -1.0, 1.0);
}

// ---- 11 neonwave — Neonwave sunrise (CC0 mrange 7dyyRy) ----
// https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/NeonwaveSunrise/
// Stacked heightmapped planes + Holi sky (hsv→Holi).

fn neonwave_effect(uv_in: vec2f) -> vec3f {
  let t = u.time * 0.25;
  var p = screen_p(uv_in);
  var ro = vec3f(0.0, 0.0, t);
  var dro = normalize(vec3f(0.0, 0.09, 1.0));
  dro = rot_yz(dro, 0.04 * sin(u.time * 0.11));
  dro = rot_xz(dro, 0.05 * cos(u.time * 0.09));
  let ww = normalize(dro);
  let uu = normalize(cross(vec3f(0.0, 1.0, 0.0), ww));
  let vv = cross(ww, uu);
  let rd = normalize(p.x * uu + p.y * vv + 2.0 * ww);

  // Holi sky + sun glow
  let ldir = normalize(vec3f(0.15, 0.35, 1.0));
  let lf = pow(max(dot(ldir, rd), 0.0), 48.0);
  var sky = palette_theme(0.08 + rd.y * 0.2, u.theme) * (0.12 + 0.7 * lf);
  sky += holi_powder(1.0) * lf * 1.05;
  sky += rainbow(atan2(rd.x, rd.z) / TAU + t * 0.05) * smoothstep(0.2, 0.0, abs(rd.y + 0.05)) * 0.55;
  sky += palette(0.7) * pow(hash21(floor(rd.xz * 80.0)), 24.0) * step(0.0, rd.y) * 0.7;

  let plane_dist = 1.05;
  let furthest = quality_steps(8, 12);
  let fade_from = max(furthest - 2, 0);
  let fade_dist = plane_dist * f32(fade_from);
  let max_dist = plane_dist * f32(furthest);
  let nz = floor(ro.z / plane_dist);
  var acol = vec4f(0.0);
  for (var i = 1; i <= 14; i++) {
    if (i > furthest) { break; }
    let pz = plane_dist * nz + plane_dist * f32(i);
    let pd = (pz - ro.z) / rd.z;
    if (pd <= 0.0 || acol.w > 0.95) { break; }
    let pp = ro + rd * pd;
    if (pp.y > 10.0) { break; }
    // Continuous heightfield — denser domain, no cell snapping
    let stp = vec2f(0.72, 0.48);
    let he = hifbm(vec2f(pp.x, pp.z) * stp) * 2.2 - 1.55;
    let d = pp.y - he;
    // Wider AA so silhouette edges never stair-step
    let aa = max(0.035 * pd, 0.012);
    let cover = smoothstep(aa, -aa, d);
    let h = hash21(vec2f(nz + f32(i), u.seed));
    var pcol = palette_theme(0.15 + h * 0.5 + pp.z * 0.04 + t * 0.08, u.theme);
    pcol += holi_powder(floor(h * 7.0)) * 0.55;
    pcol *= 0.72 + 0.45 * soft_glow(d, 6.0);
    let fade_in = smoothstep(max_dist, fade_dist, pd);
    pcol = mix(sky, pcol, fade_in);
    let pw = cover * fade_in * 0.85;
    acol = vec4f(mix(acol.xyz, pcol, pw), acol.w + pw * (1.0 - acol.w));
  }
  var col = mix(sky, acol.xyz, clamp(acol.w, 0.0, 1.0));
  col *= smoothstep(0.0, 0.35, abs(p.y) + 0.2);
  return col;
}

// ---- 12 ai_heart — AI not included (CC0 mrange ctd3Rl) ----
// https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/AiNotIncluded/
// Heart DE + heightfield shading + Holi lightning filaments.

fn pmin_k(a: f32, b: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

fn pabs_k(a: f32, k: f32) -> f32 {
  return -pmin_k(a, -a, k);
}

fn heart2(p_in: vec2f) -> f32 {
  var p = p_in;
  p.x = pabs_k(p.x, 0.05);
  if (p.y + p.x > 1.0) {
    return length(p - vec2f(0.25, 0.75)) - 0.35355339;
  }
  return sqrt(min(dot(p - vec2f(0.0, 1.0), p - vec2f(0.0, 1.0)),
    dot(p - 0.5 * max(p.x + p.y, 0.0), p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

fn ai_heart_effect(uv_in: vec2f) -> vec3f {
  let t = u.time;
  var p = screen_p(uv_in) * 1.15;
  p.y += 0.15;
  var hp = p;
  hp.y += 0.6;
  let d = heart2(hp);
  var h = tanh_approx(-20.0 * d);
  h -= 3.0 * length(p);
  h = pmin_k(h, 0.0, 1.0) * 0.25;

  // Fake lighting via height diffs
  let e = 4.0 / max(u.resolution.y, 1.0);
  let nx = (tanh_approx(-20.0 * heart2(hp + vec2f(e, 0.0))) - tanh_approx(-20.0 * heart2(hp - vec2f(e, 0.0))));
  let ny = (tanh_approx(-20.0 * heart2(hp + vec2f(0.0, e))) - tanh_approx(-20.0 * heart2(hp - vec2f(0.0, e))));
  let n = normalize(vec3f(nx, ny, 2.0 * e));
  let ldir = normalize(vec3f(0.4, 0.7, 0.55));
  let diff = max(dot(n, ldir), 0.0);

  var col = palette_theme(0.05 + h * 0.4 + t * 0.03, u.theme) * (0.35 + 0.9 * diff);
  col += holi_powder(5.0) * soft_glow(d, 18.0) * 1.1;
  col += rainbow(atan2(p.y, p.x) / TAU + t * 0.05) * soft_glow(d - 0.02, 8.0) * 0.55;

  // Lightning / plasma filaments (Holi)
  let st = t * 0.005;
  var fbmv = vnoise2(p * 3.0 + vec2f(cos(st * 40.0), sin(st * 28.0)));
  fbmv += 0.5 * vnoise2(p * 6.0 - vec2f(sin(st * 30.0), cos(st * 22.0)));
  fbmv = fbmv / 1.5;
  let bolt = exp(-35.0 * abs(fbmv - 0.45));
  col += palette_theme(0.55 + fbmv * 0.3, u.theme) * bolt * (0.35 + 0.65 * soft_glow(d, 4.0));
  col += palette(0.2) * (0.04 / (length(p) + 0.2));
  return col;
}

// ---- 15 starry_pl — Starry planes (CC0 mrange MfjyWK) ----
// https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/StarryPlanes/
// Path-following star cutouts on stacked planes → Holi.

fn star5(p_in: vec2f, r: f32, rf: f32, sm: f32) -> f32 {
  var p = -p_in;
  let k1 = vec2f(0.809016994375, -0.587785252292);
  let k2 = vec2f(-k1.x, k1.y);
  p.x = abs(p.x);
  p -= 2.0 * max(dot(k1, p), 0.0) * k1;
  p -= 2.0 * max(dot(k2, p), 0.0) * k2;
  p.x = pabs_k(p.x, sm);
  p.y -= r;
  let ba = rf * vec2f(-k1.y, k1.x) - vec2f(0.0, 1.0);
  let h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
  return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

fn starry_pl_effect(uv_in: vec2f) -> vec3f {
  let t = u.time * 0.55;
  var p = screen_p(uv_in);
  let path_a = vec2f(0.31, 0.27);
  let path_b = vec2f(0.55, 0.4);
  var ro = vec3f(path_b * sin(path_a * t), t);
  let ww = normalize(vec3f(path_a * path_b * cos(path_a * t), 1.0));
  let uu = normalize(cross(vec3f(0.0, 1.0, 0.0), ww));
  let vv = cross(ww, uu);
  let rd = normalize(p.x * uu + p.y * vv + 1.8 * ww);

  var sky = palette_theme(0.6 + rd.y * 0.15, u.theme) * 0.22;
  sky += rainbow(atan2(rd.x, rd.z) / TAU) * 0.16;
  let plane_dist = 0.5;
  let furthest = quality_steps(10, 16);
  var acol = vec4f(0.0);
  let nz = floor(ro.z / plane_dist);
  for (var i = 1; i <= 18; i++) {
    if (i > furthest) { break; }
    let pz = plane_dist * nz + plane_dist * f32(i);
    let pd = (pz - ro.z) / rd.z;
    if (pd <= 0.0 || acol.w > 0.95) { break; }
    let pp = ro + rd * pd;
    var p2 = pp.xy - path_b * sin(path_a * pp.z);
    let spin = 0.5 * pp.z;
    p2 = rotate2(p2, spin);
    let d0 = star5(p2, 0.45, 1.6, 0.2) - 0.02;
    let aa = max(0.03 * pd, 0.01);
    let cover = smoothstep(aa, -aa, d0);
    var pcol = palette_theme(0.2 + f32(i) * 0.07 + pp.z * 0.05, u.theme);
    pcol += holi_powder(f32(i % 7)) * 0.65;
    pcol *= 0.85 + 0.35 * soft_glow(d0, 10.0);
    let fade = smoothstep(plane_dist * f32(furthest), plane_dist * f32(max(furthest - 3, 1)), pd);
    pcol = mix(sky, pcol, fade);
    let pw = cover * fade * 0.9;
    acol = vec4f(mix(acol.xyz, pcol, pw), acol.w + pw * (1.0 - acol.w));
  }
  return mix(sky, acol.xyz, clamp(acol.w, 0.0, 1.0));
}

@fragment
fn fs_main(@location(0) uv_in: vec2f) -> @location(0) vec4f {
  let lo = i32(floor(u.layout_mode + 0.5));
  var col: vec3f;
  // Reindexed after FPS cull — see EFFECTS_ADDED.md
  // 0 flock 1 truchet 2 golden 3 logspiral 4 apollo
  // 5 eel 6 eelaudio 7 gulal_pulse 8 neonwave 9 ai_heart 10 starry_pl
  switch lo {
    case 1: { col = truchet_effect(uv_in); }
    case 2: { col = golden_effect(uv_in); }
    case 3: { col = logspiral_effect(uv_in); }
    case 4: { col = apollo_twist_effect(uv_in); }
    case 5: { col = eel_effect(uv_in); }
    case 6: { col = eelaudio_effect(uv_in); }
    case 7: { col = gulal_pulse_effect(uv_in); }
    case 8: { col = neonwave_effect(uv_in); }
    case 9: { col = ai_heart_effect(uv_in); }
    case 10: { col = starry_pl_effect(uv_in); }
    default: { col = flock_effect(uv_in); }
  }
  return finish(col);
}
