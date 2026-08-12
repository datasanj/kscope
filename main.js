const canvas = document.getElementById("gpu");
const statsEl = document.getElementById("stats");
const fallback = document.getElementById("fallback");

// Effect uniforms: res(2) time seed mouse(2) theme mirrors intensity layout ring audio quality pad
const EFFECT_FLOATS = 16;
const EFFECT_BYTES = EFFECT_FLOATS * 4;

// Composite: resolution(2) progress mode time seed mirrorsA mirrorsB morph pad(3)
const COMP_FLOATS = 12;
const COMP_BYTES = COMP_FLOATS * 4;

const THEMES = [
  { id: 0, name: "gulabi" },
  { id: 1, name: "laal" },
  { id: 2, name: "kesar" },
  { id: 3, name: "hari" },
  { id: 4, name: "rang" },
  { id: 5, name: "neela" },
];

// Colorful survivors only — boring kaleido/tunnel/hybrid stay gone
const LAYOUTS = [
  { id: 0, name: "flock" },
  { id: 1, name: "truchet" },
  { id: 2, name: "starnest" },
  { id: 3, name: "golden" },
  { id: 4, name: "logspiral" },
  { id: 5, name: "apollo" },
  { id: 6, name: "eel" },
  { id: 7, name: "eelaudio" },
  { id: 8, name: "reflect" },
  { id: 9, name: "bubble" },
  { id: 10, name: "gulal_pulse" },
  // Corrective pass — mrange CC0 (Shaderfuse SoTW quotes author CC0:). See EFFECTS_ADDED.md
  { id: 11, name: "neonwave" },
  { id: 12, name: "ai_heart" },
  { id: 13, name: "mandelbulb" },
  { id: 14, name: "twinkle_tun" },
  { id: 15, name: "starry_pl" },
  { id: 16, name: "clearly_bug" },
  { id: 17, name: "beats4d" },
];

const LAYOUT_FLOCK = 0;
const LAYOUT_TRUCHET = 1;

// Auto: prior colorful set + CC0 mrange ports
const LAYOUT_SEQ = [
  0, 11, 2, 10, 14, 1, 12, 5, 15, 3, 13, 6, 16, 4, 17, 9, 8, 7,
  0, 14, 11, 2, 12, 10, 15, 5, 13, 3, 16, 6, 17, 4, 9, 8,
];

const MIRROR_SEQ = [3, 4, 5, 6, 4, 8, 5, 3, 7, 4, 6, 5, 4, 3];

// Bias toward colorful ring energy (less empty quiet)
const RING_SEQ = [1, 2, 1, 2, 0, 1, 2, 1, 2, 1, 0, 2];

// Theme auto seq leans on rang (full Holi riot) while still visiting all powders
const THEME_SEQ = [4, 0, 4, 1, 4, 2, 4, 3, 4, 5, 4, 0, 4, 2];

/** Dual-effect mix modes */
const MIX = {
  HEX: 0,
  IRIS: 1,
  WEDGE: 2,
  STORM: 3,
};

const MIX_NAMES = ["hex", "iris", "wedge", "storm"];

const EFFECT_DWELL = 11;
const EFFECT_FADE = 3.2;
const RING_DWELL = 6.5;
const RING_FADE = 2.2;

const state = {
  time: 0,
  seed: Math.random() * 10,
  autoTheme: true,
  pinnedTheme: 4, // rang — full Holi riot default bias
  intensity: 1.05,
  paused: false,
  mouse: [0.5, 0.5],
  last: performance.now(),
  frames: 0,
  fps: 0,
  fpsWindowStart: performance.now(),
  // Current / next effect genomes
  effectA: makeEffect(0),
  effectB: makeEffect(1),
  effectMix: 0,
  mixMode: MIX.HEX,
  pinnedMixMode: null, // null = auto pick
  ringAmount: 0,
  // Quality: dual half-res during transitions (toggle with Q)
  dualHalfRes: true,
  // Raymarch quality inside heavy layouts (toggle with V)
  highQuality: false,
  audioLevel: 0,
  audioEnabled: false,
  presentMode: "default",
  layoutIdx: 0,
  themeIdx: 0,
  mirrorIdx: 0,
};

function makeEffect(i) {
  return {
    theme: THEMES[i % THEMES.length].id,
    layout: LAYOUT_SEQ[i % LAYOUT_SEQ.length],
    mirrors: MIRROR_SEQ[i % MIRROR_SEQ.length],
    seed: Math.random() * 10,
  };
}

function showFallback() {
  fallback.hidden = false;
}

function smoothstep(e0, e1, x) {
  const t = Math.min(1, Math.max(0, (x - e0) / (e1 - e0)));
  return t * t * (3 - 2 * t);
}

function stagedPair(time, dwell, fade, sequence, offset = 0) {
  const cycle = dwell + fade;
  const t = Math.max(0, time + offset);
  const idx = Math.floor(t / cycle) % sequence.length;
  const next = (idx + 1) % sequence.length;
  const local = t - Math.floor(t / cycle) * cycle;
  const mix = local <= dwell ? 0 : smoothstep(0, fade, local - dwell);
  return { a: sequence[idx], b: sequence[next], mix, idx, next, local, dwell };
}

function pickMixMode(layoutA, layoutB) {
  if (state.pinnedMixMode != null) return state.pinnedMixMode;
  // Prefer hex takeover when Mandala flock is involved
  if (layoutA === LAYOUT_FLOCK || layoutB === LAYOUT_FLOCK) return MIX.HEX;
  const roll = Math.floor((state.seed * 17 + state.time * 0.3) % 4);
  // Weight toward iris/wedge/storm color pops
  const weighted = [MIX.IRIS, MIX.WEDGE, MIX.HEX, MIX.STORM, MIX.IRIS, MIX.WEDGE];
  return weighted[roll % weighted.length];
}

function updateRingAmount(time) {
  const pair = stagedPair(time, RING_DWELL, RING_FADE, RING_SEQ, state.seed * 2.3);
  const map = (v) => (v === 0 ? 0 : v === 1 ? 0.65 : 1.45);
  let amount = map(pair.a) * (1 - pair.mix) + map(pair.b) * pair.mix;
  if (amount > 1.0) {
    amount += 0.1 * Math.sin(time * 2.2);
  } else if (amount > 0.2) {
    amount *= 0.88 + 0.12 * Math.sin(time * 1.1);
  }
  state.ringAmount = Math.max(0, amount);
}

function buildEffectFromIndices(themeId, layoutId, mirrorId, seed) {
  return {
    theme: themeId,
    layout: layoutId,
    mirrors: mirrorId,
    seed,
  };
}

function updateGenome(dt) {
  if (!state.paused) state.time += dt;

  const cycle = EFFECT_DWELL + EFFECT_FADE;
  const t = state.time + state.seed;
  const idx = Math.floor(t / cycle);
  const local = t - idx * cycle;
  const mix = local <= EFFECT_DWELL ? 0 : smoothstep(0, EFFECT_FADE, local - EFFECT_DWELL);

  // Stable per-slot genomes — rang-heavy Holi sequence in auto mode
  const themeA = state.autoTheme
    ? THEME_SEQ[idx % THEME_SEQ.length]
    : state.pinnedTheme;
  const themeB = state.autoTheme
    ? THEME_SEQ[(idx + 1) % THEME_SEQ.length]
    : state.pinnedTheme;

  const layoutA = LAYOUT_SEQ[idx % LAYOUT_SEQ.length];
  const layoutB = LAYOUT_SEQ[(idx + 1) % LAYOUT_SEQ.length];
  const mirrorsA = MIRROR_SEQ[idx % MIRROR_SEQ.length];
  const mirrorsB = MIRROR_SEQ[(idx + 1) % MIRROR_SEQ.length];

  // Seed drifts per effect slot so remixed layouts differ
  const seedA = state.seed + idx * 1.618;
  const seedB = state.seed + (idx + 1) * 1.618;

  state.effectA = buildEffectFromIndices(themeA, layoutA, mirrorsA, seedA);
  state.effectB = buildEffectFromIndices(themeB, layoutB, mirrorsB, seedB);
  state.effectMix = state.autoTheme || layoutA !== layoutB || mirrorsA !== mirrorsB ? mix : 0;
  // When theme pinned, still allow layout dual transitions
  if (!state.autoTheme) {
    state.effectA.theme = state.pinnedTheme;
    state.effectB.theme = state.pinnedTheme;
  }

  state.mixMode = pickMixMode(state.effectA.layout, state.effectB.layout);
  state.layoutIdx = idx;
  updateRingAmount(state.time);
}

function themeLabel() {
  const a = THEMES[state.effectA.theme]?.name ?? "?";
  const b = THEMES[state.effectB.theme]?.name ?? "?";
  if (!state.autoTheme) return a;
  if (state.effectMix < 0.02) return a;
  if (state.effectMix > 0.98) return b;
  return `${a}→${b}`;
}

function mirrorsLabel() {
  const a = state.effectA.mirrors;
  const b = state.effectB.mirrors;
  // Genome morph underneath during fade
  if (state.effectMix < 0.02) return `${a}`;
  if (state.effectMix > 0.98) return `${b}`;
  const m = Math.round(a + (b - a) * state.effectMix);
  return `${a}→${b}(~${m})`;
}

function layoutLabel() {
  const a = LAYOUTS[state.effectA.layout]?.name ?? "?";
  const b = LAYOUTS[state.effectB.layout]?.name ?? "?";
  if (state.effectMix < 0.02) return a;
  if (state.effectMix > 0.98) return b;
  return `${a}→${b}`;
}

function mixLabel() {
  if (state.effectMix < 0.02 || state.effectMix > 0.98) return "—";
  return MIX_NAMES[state.mixMode] ?? "?";
}

function ringLabel() {
  if (state.ringAmount < 0.15) return "quiet";
  if (state.ringAmount < 1.1) return "sparse";
  return "storm";
}

function qualityLabel() {
  const dual = state.dualHalfRes ? "½res×2" : "full×2";
  const rq = state.highQuality ? "HQ" : "LQ";
  return `${dual}/${rq}`;
}


function jumpToLayout(layoutId) {
  for (let i = 0; i < LAYOUT_SEQ.length * 3; i++) {
    state.time += EFFECT_DWELL + EFFECT_FADE;
    updateGenome(0);
    if (state.effectA.layout === layoutId && state.effectMix < 0.05) break;
  }
}

let audioCtx = null;
let analyser = null;
let audioData = null;
async function toggleMicAudio() {
  try {
    if (state.audioEnabled && audioCtx) {
      await audioCtx.close();
      audioCtx = null;
      analyser = null;
      state.audioEnabled = false;
      state.audioLevel = 0;
      return;
    }
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    const src = audioCtx.createMediaStreamSource(stream);
    analyser = audioCtx.createAnalyser();
    analyser.fftSize = 256;
    src.connect(analyser);
    audioData = new Uint8Array(analyser.frequencyBinCount);
    state.audioEnabled = true;
  } catch (err) {
    console.warn("Mic audio unavailable — eelaudio uses time-driven faux beat.", err);
    state.audioEnabled = false;
  }
}

function sampleAudioLevel() {
  if (!state.audioEnabled || !analyser || !audioData) {
    // Faux reactivity always available for eelaudio layout
    const faux = 0.55 + 0.45 * Math.sin(state.time * 2.7) * Math.sin(state.time * 1.3 + 1.7);
    state.audioLevel = state.effectA.layout === 7 || state.effectB.layout === 7 ? faux * 0.85 : 0;
    return;
  }
  analyser.getByteFrequencyData(audioData);
  let sum = 0;
  const n = Math.min(32, audioData.length);
  for (let i = 0; i < n; i++) sum += audioData[i];
  state.audioLevel = Math.min(1.2, (sum / n / 255) * 1.8);
}

async function init() {
  if (!navigator.gpu) {
    showFallback();
    return;
  }

  const adapter = await navigator.gpu.requestAdapter({
    powerPreference: "high-performance",
  });
  if (!adapter) {
    showFallback();
    return;
  }

  const device = await adapter.requestDevice();
  const context = canvas.getContext("webgpu");
  const format = navigator.gpu.getPreferredCanvasFormat();

  const config = {
    device,
    format,
    alphaMode: "opaque",
    usage: GPUTextureUsage.RENDER_ATTACHMENT,
  };
  state.presentMode = "default";
  let configured = false;
  for (const presentMode of ["mailbox", "immediate", "fifo"]) {
    try {
      context.configure({ ...config, presentMode });
      state.presentMode = presentMode;
      configured = true;
      break;
    } catch {
      // presentMode not universally supported
    }
  }
  if (!configured) context.configure(config);

  const [effectCode, compCode] = await Promise.all([
    fetch("shader.wgsl").then((r) => r.text()),
    fetch("composite.wgsl").then((r) => r.text()),
  ]);

  const effectModule = device.createShaderModule({ code: effectCode });
  const compModule = device.createShaderModule({ code: compCode });

  async function checkModule(module, label) {
    const info = await module.getCompilationInfo?.();
    if (!info?.messages?.length) return true;
    for (const m of info.messages) {
      console[m.type === "error" ? "error" : "warn"](
        `[WGSL ${label} ${m.type}] L${m.lineNum}:${m.linePos} ${m.message}`
      );
    }
    return !info.messages.some((m) => m.type === "error");
  }

  if (!(await checkModule(effectModule, "effect")) || !(await checkModule(compModule, "composite"))) {
    showFallback();
    fallback.querySelector("p").textContent =
      "Shader compile failed — see console for WGSL errors.";
    return;
  }

  // Effect pass → rgba16float (or rgba8unorm fallback) offscreen, or straight to canvas
  const offscreenFormat = "rgba16float";
  let effectTargetsFormat = offscreenFormat;
  try {
    // Probe: some adapters may not filter rgba16float
    device.createTexture({
      size: [4, 4],
      format: offscreenFormat,
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
    }).destroy();
  } catch {
    effectTargetsFormat = "rgba8unorm";
  }

  const effectPipelineScreen = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: effectModule, entryPoint: "vs_main" },
    fragment: {
      module: effectModule,
      entryPoint: "fs_main",
      targets: [{ format }],
    },
    primitive: { topology: "triangle-list" },
  });

  const effectPipelineOff = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: effectModule, entryPoint: "vs_main" },
    fragment: {
      module: effectModule,
      entryPoint: "fs_main",
      targets: [{ format: effectTargetsFormat }],
    },
    primitive: { topology: "triangle-list" },
  });

  const compPipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: compModule, entryPoint: "vs_main" },
    fragment: {
      module: compModule,
      entryPoint: "fs_main",
      targets: [{ format }],
    },
    primitive: { topology: "triangle-list" },
  });

  const effectUniformBuffer = device.createBuffer({
    size: EFFECT_BYTES,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  const effectUniformBufferB = device.createBuffer({
    size: EFFECT_BYTES,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  const compUniformBuffer = device.createBuffer({
    size: COMP_BYTES,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  const sampler = device.createSampler({
    magFilter: "linear",
    minFilter: "linear",
  });

  const effectBindA = device.createBindGroup({
    layout: effectPipelineOff.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: effectUniformBuffer } }],
  });
  const effectBindB = device.createBindGroup({
    layout: effectPipelineOff.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: effectUniformBufferB } }],
  });
  const effectBindScreen = device.createBindGroup({
    layout: effectPipelineScreen.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: effectUniformBuffer } }],
  });

  let rtA = null;
  let rtB = null;
  let rtW = 0;
  let rtH = 0;
  let compBind = null;

  function ensureTargets(fullW, fullH) {
    const scale = state.dualHalfRes ? 0.5 : 1.0;
    const w = Math.max(1, Math.floor(fullW * scale));
    const h = Math.max(1, Math.floor(fullH * scale));
    if (rtA && rtW === w && rtH === h) return;
    rtA?.destroy();
    rtB?.destroy();
    rtW = w;
    rtH = h;
    const usage =
      GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING;
    rtA = device.createTexture({
      size: [w, h],
      format: effectTargetsFormat,
      usage,
    });
    rtB = device.createTexture({
      size: [w, h],
      format: effectTargetsFormat,
      usage,
    });
    compBind = device.createBindGroup({
      layout: compPipeline.getBindGroupLayout(0),
      entries: [
        { binding: 0, resource: { buffer: compUniformBuffer } },
        { binding: 1, resource: sampler },
        { binding: 2, resource: rtA.createView() },
        { binding: 3, resource: rtB.createView() },
      ],
    });
  }

  const effectUniforms = new Float32Array(EFFECT_FLOATS);
  const effectUniformsB = new Float32Array(EFFECT_FLOATS);
  const compUniforms = new Float32Array(COMP_FLOATS);

  function writeEffect(buf, arr, effect, w, h) {
    // Genome morph underneath: lerp mirrors / theme seed feel during fade
    const morph = state.effectMix;
    const theme =
      effect === state.effectA
        ? state.effectA.theme + (state.effectB.theme - state.effectA.theme) * morph * 0.35
        : state.effectB.theme + (state.effectA.theme - state.effectB.theme) * (1 - morph) * 0.15;
    const mirrors =
      effect === state.effectA
        ? state.effectA.mirrors + (state.effectB.mirrors - state.effectA.mirrors) * morph * 0.4
        : state.effectB.mirrors + (state.effectA.mirrors - state.effectB.mirrors) * (1 - morph) * 0.2;

    arr[0] = w;
    arr[1] = h;
    arr[2] = state.time;
    arr[3] = effect.seed;
    arr[4] = state.mouse[0];
    arr[5] = state.mouse[1];
    arr[6] = theme;
    arr[7] = mirrors;
    arr[8] = state.intensity;
    arr[9] = effect.layout;
    arr[10] = state.ringAmount;
    arr[11] = state.audioLevel;
    arr[12] = state.highQuality ? 1 : 0;
    arr[13] = 0;
    arr[14] = 0;
    arr[15] = 0;
    device.queue.writeBuffer(buf, 0, arr);
  }

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const maxDim = 3840;
    let w = Math.floor(window.innerWidth * dpr);
    let h = Math.floor(window.innerHeight * dpr);
    const scale = Math.min(1, maxDim / Math.max(w, h));
    w = Math.max(1, Math.floor(w * scale));
    h = Math.max(1, Math.floor(h * scale));
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w;
      canvas.height = h;
      rtA?.destroy();
      rtB?.destroy();
      rtA = rtB = null;
      rtW = rtH = 0;
    }
  }

  resize();
  window.addEventListener("resize", resize);

  canvas.addEventListener("pointermove", (e) => {
    const rect = canvas.getBoundingClientRect();
    state.mouse[0] = (e.clientX - rect.left) / rect.width;
    state.mouse[1] = 1 - (e.clientY - rect.top) / rect.height;
  });

  canvas.addEventListener("click", () => {
    // Advance dual-effect morph to the next layout (same as T) — not a color remix
    state.time += EFFECT_DWELL * 0.92;
  });

  window.addEventListener("keydown", (e) => {
    if (e.code === "Space") {
      e.preventDefault();
      state.paused = !state.paused;
    } else if (e.key === "0") {
      state.autoTheme = true;
    } else if (e.key >= "1" && e.key <= "6") {
      state.autoTheme = false;
      state.pinnedTheme = Number(e.key) - 1;
    } else if (e.key === "t" || e.key === "T") {
      // Jump toward next effect morph (layout/genome)
      state.time += EFFECT_DWELL * 0.92;
    } else if (e.key === "c" || e.key === "C") {
      state.time += RING_DWELL * 0.95;
    } else if (e.key === "r" || e.key === "R") {
      state.seed = Math.random() * 10;
      state.autoTheme = true;
      state.time += EFFECT_DWELL * 0.85;
    } else if (e.key === "x" || e.key === "X") {
      // Force next transition + cycle mix mode
      state.pinnedMixMode =
        state.pinnedMixMode == null
          ? MIX.HEX
          : (state.pinnedMixMode + 1) % 4;
      state.time += EFFECT_DWELL * 0.95;
    } else if (e.key === "m" || e.key === "M") {
      // Pin / cycle mix mode without jumping time
      state.pinnedMixMode =
        state.pinnedMixMode == null
          ? MIX.HEX
          : (state.pinnedMixMode + 1) % 4;
      state.mixMode = state.pinnedMixMode;
    } else if (e.key === "q" || e.key === "Q") {
      state.dualHalfRes = !state.dualHalfRes;
      rtA?.destroy();
      rtB?.destroy();
      rtA = rtB = null;
      rtW = rtH = 0;
    } else if (e.key === "v" || e.key === "V") {
      state.highQuality = !state.highQuality;
    } else if (e.key === "a" || e.key === "A") {
      // Optional mic for eelaudio — safe no-op if denied/unavailable
      toggleMicAudio();
    } else if ("fuglesbyhndikzwo".includes(e.key.toLowerCase()) && e.key.length === 1) {
      const map = {
        f: 0, // flock
        u: 1, // truchet
        s: 2, // starnest
        g: 3, // golden
        l: 4, // logspiral
        e: 6, // eel
        b: 9, // bubble
        y: 8, // reflect (self)
        h: 10, // gulal_pulse
        n: 11, // neonwave
        i: 12, // ai_heart
        d: 13, // mandelbulb
        k: 14, // twinkle_tun
        z: 15, // starry_pl
        w: 16, // clearly_bug
        o: 17, // beats4d
      };
      const k = e.key.toLowerCase();
      if (map[k] != null) jumpToLayout(map[k]);
    } else if (e.key === "p" || e.key === "P") {
      jumpToLayout(5); // apollo
    } else if (e.key === "j" || e.key === "J") {
      jumpToLayout(7); // eelaudio
    } else if (e.key === "+" || e.key === "=") {
      state.intensity = Math.min(1.8, state.intensity + 0.06);
    } else if (e.key === "-" || e.key === "_") {
      state.intensity = Math.max(0.35, state.intensity - 0.06);
    }
  });

  function frame(now) {
    const dt = Math.min(0.05, (now - state.last) / 1000);
    state.last = now;
    updateGenome(dt);

    const transitioning = state.effectMix > 0.001 && state.effectMix < 0.999;

    state.frames += 1;
    if (now - state.fpsWindowStart >= 500) {
      state.fps = (state.frames * 1000) / (now - state.fpsWindowStart);
      state.frames = 0;
      state.fpsWindowStart = now;
      const mix = mixLabel();
      const q = transitioning ? qualityLabel() : "1pass";
      statsEl.textContent = `${state.fps.toFixed(0)} fps · ${canvas.width}×${canvas.height} · ${layoutLabel()} · ${themeLabel()} · ×${mirrorsLabel()} · ${ringLabel()} · ${mix} · ${q}`;
    }

    const encoder = device.createCommandEncoder();
    const view = context.getCurrentTexture().createView();

    if (!transitioning) {
      // Single effect → screen (full res, cheapest path)
      const effect = state.effectMix >= 0.5 ? state.effectB : state.effectA;
      writeEffect(effectUniformBuffer, effectUniforms, effect, canvas.width, canvas.height);
      const pass = encoder.beginRenderPass({
        colorAttachments: [
          {
            view,
            clearValue: { r: 0.01, g: 0.015, b: 0.04, a: 1 },
            loadOp: "clear",
            storeOp: "store",
          },
        ],
      });
      pass.setPipeline(effectPipelineScreen);
      pass.setBindGroup(0, effectBindScreen);
      pass.draw(3);
      pass.end();
    } else {
      // Dual-render A+B (both advance in time) → composite
      ensureTargets(canvas.width, canvas.height);
      writeEffect(effectUniformBuffer, effectUniforms, state.effectA, rtW, rtH);
      writeEffect(effectUniformBufferB, effectUniformsB, state.effectB, rtW, rtH);

      const clear = { r: 0.01, g: 0.015, b: 0.04, a: 1 };
      {
        const pass = encoder.beginRenderPass({
          colorAttachments: [
            {
              view: rtA.createView(),
              clearValue: clear,
              loadOp: "clear",
              storeOp: "store",
            },
          ],
        });
        pass.setPipeline(effectPipelineOff);
        pass.setBindGroup(0, effectBindA);
        pass.draw(3);
        pass.end();
      }
      {
        const pass = encoder.beginRenderPass({
          colorAttachments: [
            {
              view: rtB.createView(),
              clearValue: clear,
              loadOp: "clear",
              storeOp: "store",
            },
          ],
        });
        pass.setPipeline(effectPipelineOff);
        pass.setBindGroup(0, effectBindB);
        pass.draw(3);
        pass.end();
      }

      compUniforms[0] = canvas.width;
      compUniforms[1] = canvas.height;
      compUniforms[2] = state.effectMix;
      compUniforms[3] = state.mixMode;
      compUniforms[4] = state.time;
      compUniforms[5] = state.seed;
      compUniforms[6] = state.effectA.mirrors;
      compUniforms[7] = state.effectB.mirrors;
      compUniforms[8] = state.effectMix; // genome morph factor
      compUniforms[9] = 0;
      compUniforms[10] = 0;
      compUniforms[11] = 0;
      device.queue.writeBuffer(compUniformBuffer, 0, compUniforms);

      const pass = encoder.beginRenderPass({
        colorAttachments: [
          {
            view,
            clearValue: clear,
            loadOp: "clear",
            storeOp: "store",
          },
        ],
      });
      pass.setPipeline(compPipeline);
      pass.setBindGroup(0, compBind);
      pass.draw(3);
      pass.end();
    }

    device.queue.submit([encoder.finish()]);
    requestAnimationFrame(frame);
  }

  requestAnimationFrame(frame);
}

init().catch((err) => {
  console.error(err);
  showFallback();
});
