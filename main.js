const canvas = document.getElementById("gpu");
const statsEl = document.getElementById("stats");
const fallback = document.getElementById("fallback");

// Sheep uniforms: resolution(2) time seed mouse(2) theme mirrors intensity layout ring pad
const SHEEP_FLOATS = 12;
const SHEEP_BYTES = SHEEP_FLOATS * 4;

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

const LAYOUTS = [
  { id: 0, name: "kaleido" },
  { id: 1, name: "tunnel" },
  { id: 2, name: "hybrid" },
  { id: 3, name: "flock" },
  { id: 4, name: "truchet" },
];

// Prefer flock / hybrid / truchet — living field of sheep
const LAYOUT_SEQ = [3, 2, 4, 3, 1, 3, 2, 0, 4, 3, 2, 1, 3, 4];

const MIRROR_SEQ = [3, 4, 5, 6, 4, 8, 5, 3, 7, 4, 6, 5, 4, 3];

const RING_SEQ = [0, 0, 1, 0, 2, 0, 0, 1, 2, 0, 1, 0];

/** Dual-sheep mix modes */
const MIX = {
  HEX: 0,
  IRIS: 1,
  WEDGE: 2,
  STORM: 3,
};

const MIX_NAMES = ["hex", "iris", "wedge", "storm"];

const SHEEP_DWELL = 11;
const SHEEP_FADE = 3.2;
const RING_DWELL = 6.5;
const RING_FADE = 2.2;

const state = {
  time: 0,
  seed: Math.random() * 10,
  autoTheme: true,
  pinnedTheme: 0,
  intensity: 0.95,
  paused: false,
  mouse: [0.5, 0.5],
  last: performance.now(),
  frames: 0,
  fps: 0,
  fpsWindowStart: performance.now(),
  // Current / next sheep genomes
  sheepA: makeSheep(0),
  sheepB: makeSheep(1),
  sheepMix: 0,
  mixMode: MIX.HEX,
  pinnedMixMode: null, // null = auto pick
  ringAmount: 0,
  // Quality: dual half-res during transitions (toggle with Q)
  dualHalfRes: true,
  presentMode: "default",
  layoutIdx: 0,
  themeIdx: 0,
  mirrorIdx: 0,
};

function makeSheep(i) {
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
  if (layoutA === 3 || layoutB === 3) return MIX.HEX;
  const roll = Math.floor((state.seed * 17 + state.time * 0.3) % 4);
  // Weight toward iris/wedge over storm
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

function buildSheepFromIndices(themeId, layoutId, mirrorId, seed) {
  return {
    theme: themeId,
    layout: layoutId,
    mirrors: mirrorId,
    seed,
  };
}

function updateGenome(dt) {
  if (!state.paused) state.time += dt;

  const cycle = SHEEP_DWELL + SHEEP_FADE;
  const t = state.time + state.seed;
  const idx = Math.floor(t / cycle);
  const local = t - idx * cycle;
  const mix = local <= SHEEP_DWELL ? 0 : smoothstep(0, SHEEP_FADE, local - SHEEP_DWELL);

  // Stable per-slot genomes from indices
  const themeIds = THEMES.map((th) => th.id);
  const themeA = state.autoTheme
    ? themeIds[idx % themeIds.length]
    : state.pinnedTheme;
  const themeB = state.autoTheme
    ? themeIds[(idx + 1) % themeIds.length]
    : state.pinnedTheme;

  const layoutA = LAYOUT_SEQ[idx % LAYOUT_SEQ.length];
  const layoutB = LAYOUT_SEQ[(idx + 1) % LAYOUT_SEQ.length];
  const mirrorsA = MIRROR_SEQ[idx % MIRROR_SEQ.length];
  const mirrorsB = MIRROR_SEQ[(idx + 1) % MIRROR_SEQ.length];

  // Seed drifts per sheep slot so remixed flocks differ
  const seedA = state.seed + idx * 1.618;
  const seedB = state.seed + (idx + 1) * 1.618;

  state.sheepA = buildSheepFromIndices(themeA, layoutA, mirrorsA, seedA);
  state.sheepB = buildSheepFromIndices(themeB, layoutB, mirrorsB, seedB);
  state.sheepMix = state.autoTheme || layoutA !== layoutB || mirrorsA !== mirrorsB ? mix : 0;
  // When theme pinned, still allow layout dual transitions
  if (!state.autoTheme) {
    state.sheepA.theme = state.pinnedTheme;
    state.sheepB.theme = state.pinnedTheme;
  }

  state.mixMode = pickMixMode(state.sheepA.layout, state.sheepB.layout);
  state.layoutIdx = idx;
  updateRingAmount(state.time);
}

function themeLabel() {
  const a = THEMES[state.sheepA.theme]?.name ?? "?";
  const b = THEMES[state.sheepB.theme]?.name ?? "?";
  if (!state.autoTheme) return a;
  if (state.sheepMix < 0.02) return a;
  if (state.sheepMix > 0.98) return b;
  return `${a}→${b}`;
}

function mirrorsLabel() {
  const a = state.sheepA.mirrors;
  const b = state.sheepB.mirrors;
  // Genome morph underneath during fade
  if (state.sheepMix < 0.02) return `${a}`;
  if (state.sheepMix > 0.98) return `${b}`;
  const m = Math.round(a + (b - a) * state.sheepMix);
  return `${a}→${b}(~${m})`;
}

function layoutLabel() {
  const a = LAYOUTS[state.sheepA.layout]?.name ?? "?";
  const b = LAYOUTS[state.sheepB.layout]?.name ?? "?";
  if (state.sheepMix < 0.02) return a;
  if (state.sheepMix > 0.98) return b;
  return `${a}→${b}`;
}

function mixLabel() {
  if (state.sheepMix < 0.02 || state.sheepMix > 0.98) return "—";
  return MIX_NAMES[state.mixMode] ?? "?";
}

function ringLabel() {
  if (state.ringAmount < 0.15) return "quiet";
  if (state.ringAmount < 1.1) return "sparse";
  return "storm";
}

function qualityLabel() {
  return state.dualHalfRes ? "½res×2" : "full×2";
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

  const [sheepCode, compCode] = await Promise.all([
    fetch("shader.wgsl").then((r) => r.text()),
    fetch("composite.wgsl").then((r) => r.text()),
  ]);

  const sheepModule = device.createShaderModule({ code: sheepCode });
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

  if (!(await checkModule(sheepModule, "sheep")) || !(await checkModule(compModule, "composite"))) {
    showFallback();
    fallback.querySelector("p").textContent =
      "Shader compile failed — see console for WGSL errors.";
    return;
  }

  // Sheep pass → rgba16float (or rgba8unorm fallback) offscreen, or straight to canvas
  const offscreenFormat = "rgba16float";
  let sheepTargetsFormat = offscreenFormat;
  try {
    // Probe: some adapters may not filter rgba16float
    device.createTexture({
      size: [4, 4],
      format: offscreenFormat,
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
    }).destroy();
  } catch {
    sheepTargetsFormat = "rgba8unorm";
  }

  const sheepPipelineScreen = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: sheepModule, entryPoint: "vs_main" },
    fragment: {
      module: sheepModule,
      entryPoint: "fs_main",
      targets: [{ format }],
    },
    primitive: { topology: "triangle-list" },
  });

  const sheepPipelineOff = device.createRenderPipeline({
    layout: "auto",
    vertex: { module: sheepModule, entryPoint: "vs_main" },
    fragment: {
      module: sheepModule,
      entryPoint: "fs_main",
      targets: [{ format: sheepTargetsFormat }],
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

  const sheepUniformBuffer = device.createBuffer({
    size: SHEEP_BYTES,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });
  const sheepUniformBufferB = device.createBuffer({
    size: SHEEP_BYTES,
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

  const sheepBindA = device.createBindGroup({
    layout: sheepPipelineOff.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: sheepUniformBuffer } }],
  });
  const sheepBindB = device.createBindGroup({
    layout: sheepPipelineOff.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: sheepUniformBufferB } }],
  });
  const sheepBindScreen = device.createBindGroup({
    layout: sheepPipelineScreen.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: sheepUniformBuffer } }],
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
      format: sheepTargetsFormat,
      usage,
    });
    rtB = device.createTexture({
      size: [w, h],
      format: sheepTargetsFormat,
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

  const sheepUniforms = new Float32Array(SHEEP_FLOATS);
  const sheepUniformsB = new Float32Array(SHEEP_FLOATS);
  const compUniforms = new Float32Array(COMP_FLOATS);

  function writeSheep(buf, arr, sheep, w, h) {
    // Genome morph underneath: lerp mirrors / theme seed feel during fade
    const morph = state.sheepMix;
    const theme =
      sheep === state.sheepA
        ? state.sheepA.theme + (state.sheepB.theme - state.sheepA.theme) * morph * 0.35
        : state.sheepB.theme + (state.sheepA.theme - state.sheepB.theme) * (1 - morph) * 0.15;
    const mirrors =
      sheep === state.sheepA
        ? state.sheepA.mirrors + (state.sheepB.mirrors - state.sheepA.mirrors) * morph * 0.4
        : state.sheepB.mirrors + (state.sheepA.mirrors - state.sheepB.mirrors) * (1 - morph) * 0.2;

    arr[0] = w;
    arr[1] = h;
    arr[2] = state.time;
    arr[3] = sheep.seed;
    arr[4] = state.mouse[0];
    arr[5] = state.mouse[1];
    arr[6] = theme;
    arr[7] = mirrors;
    arr[8] = state.intensity;
    arr[9] = sheep.layout;
    arr[10] = state.ringAmount;
    arr[11] = 0;
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
    state.seed = Math.random() * 10;
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
      // Jump toward next sheep morph (layout/genome)
      state.time += SHEEP_DWELL * 0.92;
    } else if (e.key === "c" || e.key === "C") {
      state.time += RING_DWELL * 0.95;
    } else if (e.key === "r" || e.key === "R") {
      state.seed = Math.random() * 10;
      state.autoTheme = true;
      state.time += SHEEP_DWELL * 0.85;
    } else if (e.key === "x" || e.key === "X") {
      // Force next transition + cycle mix mode
      state.pinnedMixMode =
        state.pinnedMixMode == null
          ? MIX.HEX
          : (state.pinnedMixMode + 1) % 4;
      state.time += SHEEP_DWELL * 0.95;
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
    } else if (e.key === "f" || e.key === "F") {
      // Jump to flock (mandala flowers) sheep
      // Advance until layout A is flock
      for (let i = 0; i < LAYOUT_SEQ.length; i++) {
        state.time += SHEEP_DWELL + SHEEP_FADE;
        updateGenome(0);
        if (state.sheepA.layout === 3 && state.sheepMix < 0.05) break;
      }
    } else if (e.key === "u" || e.key === "U") {
      // Jump to truchet sheep
      for (let i = 0; i < LAYOUT_SEQ.length; i++) {
        state.time += SHEEP_DWELL + SHEEP_FADE;
        updateGenome(0);
        if (state.sheepA.layout === 4 && state.sheepMix < 0.05) break;
      }
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

    const transitioning = state.sheepMix > 0.001 && state.sheepMix < 0.999;

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
      // Single sheep → screen (full res, cheapest path)
      const sheep = state.sheepMix >= 0.5 ? state.sheepB : state.sheepA;
      writeSheep(sheepUniformBuffer, sheepUniforms, sheep, canvas.width, canvas.height);
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
      pass.setPipeline(sheepPipelineScreen);
      pass.setBindGroup(0, sheepBindScreen);
      pass.draw(3);
      pass.end();
    } else {
      // Dual-render A+B (both advance in time) → composite
      ensureTargets(canvas.width, canvas.height);
      writeSheep(sheepUniformBuffer, sheepUniforms, state.sheepA, rtW, rtH);
      writeSheep(sheepUniformBufferB, sheepUniformsB, state.sheepB, rtW, rtH);

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
        pass.setPipeline(sheepPipelineOff);
        pass.setBindGroup(0, sheepBindA);
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
        pass.setPipeline(sheepPipelineOff);
        pass.setBindGroup(0, sheepBindB);
        pass.draw(3);
        pass.end();
      }

      compUniforms[0] = canvas.width;
      compUniforms[1] = canvas.height;
      compUniforms[2] = state.sheepMix;
      compUniforms[3] = state.mixMode;
      compUniforms[4] = state.time;
      compUniforms[5] = state.seed;
      compUniforms[6] = state.sheepA.mirrors;
      compUniforms[7] = state.sheepB.mirrors;
      compUniforms[8] = state.sheepMix; // genome morph factor
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
