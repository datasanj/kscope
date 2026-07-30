const canvas = document.getElementById("gpu");
const statsEl = document.getElementById("stats");
const fallback = document.getElementById("fallback");

// resolution(2) time seed mouse(2) themeA/B/mix mirrorsA/B/mix intensity
// layoutA/B/mix ringAmount pad(3) = 20 floats / 80 bytes
const UNIFORM_FLOATS = 20;
const UNIFORM_BYTES = UNIFORM_FLOATS * 4;

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
];

// Prefer hybrid/tunnel more often than flat kaleido
const LAYOUT_SEQ = [2, 1, 2, 0, 2, 1, 2, 1, 0, 2];

// Few mirrors → wide Octagrams-scale wedges (3–6)
const MIRROR_SEQ = [3, 4, 5, 3, 4, 6, 3, 5, 4, 3, 5, 4, 6, 4];

// Ring episodes: 0 quiet, 1 sparse, 2 storm — long quiet stretches
const RING_SEQ = [0, 0, 1, 0, 2, 0, 0, 1, 2, 0, 1, 0];

const THEME_DWELL = 14;
const THEME_FADE = 4.5;
const MIRROR_DWELL = 9;
const MIRROR_FADE = 2.8;
const LAYOUT_DWELL = 11;
const LAYOUT_FADE = 3.5;
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
  themeA: 0,
  themeB: 1,
  themeMix: 0,
  mirrorsA: 3,
  mirrorsB: 4,
  mirrorMix: 0,
  layoutA: 2,
  layoutB: 1,
  layoutMix: 0,
  ringAmount: 0,
};

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
  return { a: sequence[idx], b: sequence[next], mix };
}

/** Ring amount: mostly quiet, occasional sparse pulses, rare multi-circle storms */
function updateRingAmount(time) {
  const pair = stagedPair(time, RING_DWELL, RING_FADE, RING_SEQ, state.seed * 2.3);
  const from = pair.a;
  const to = pair.b;
  // Map enum → intensity; add a little breath so storms feel alive
  // Cap storms lower — fewer additive rings / less whiteout
  const map = (v) => (v === 0 ? 0 : v === 1 ? 0.65 : 1.45);
  let amount = map(from) * (1 - pair.mix) + map(to) * pair.mix;
  if (amount > 1.0) {
    amount += 0.1 * Math.sin(time * 2.2);
  } else if (amount > 0.2) {
    amount *= 0.88 + 0.12 * Math.sin(time * 1.1);
  }
  state.ringAmount = Math.max(0, amount);
}

function updateGenome(dt) {
  if (!state.paused) state.time += dt;

  if (state.autoTheme) {
    const themeIds = THEMES.map((t) => t.id);
    const pair = stagedPair(state.time, THEME_DWELL, THEME_FADE, themeIds, state.seed);
    state.themeA = pair.a;
    state.themeB = pair.b;
    state.themeMix = pair.mix;
  } else {
    state.themeA = state.pinnedTheme;
    state.themeB = state.pinnedTheme;
    state.themeMix = 0;
  }

  const mirrors = stagedPair(
    state.time,
    MIRROR_DWELL,
    MIRROR_FADE,
    MIRROR_SEQ,
    state.seed * 1.7 + 3.1
  );
  state.mirrorsA = mirrors.a;
  state.mirrorsB = mirrors.b;
  state.mirrorMix = mirrors.mix;

  const layout = stagedPair(
    state.time,
    LAYOUT_DWELL,
    LAYOUT_FADE,
    LAYOUT_SEQ,
    state.seed * 0.9 + 7.7
  );
  state.layoutA = layout.a;
  state.layoutB = layout.b;
  state.layoutMix = layout.mix;

  updateRingAmount(state.time);
}

function themeLabel() {
  const a = THEMES[state.themeA]?.name ?? "?";
  const b = THEMES[state.themeB]?.name ?? "?";
  if (!state.autoTheme) return a;
  if (state.themeMix < 0.02) return a;
  if (state.themeMix > 0.98) return b;
  return `${a}→${b}`;
}

function mirrorsLabel() {
  const a = state.mirrorsA;
  const b = state.mirrorsB;
  if (state.mirrorMix < 0.02) return `${a}`;
  if (state.mirrorMix > 0.98) return `${b}`;
  return `${a}→${b}`;
}

function layoutLabel() {
  const a = LAYOUTS[state.layoutA]?.name ?? "?";
  const b = LAYOUTS[state.layoutB]?.name ?? "?";
  if (state.layoutMix < 0.02) return a;
  if (state.layoutMix > 0.98) return b;
  return `${a}→${b}`;
}

function ringLabel() {
  if (state.ringAmount < 0.15) return "quiet";
  if (state.ringAmount < 1.1) return "sparse";
  return "storm";
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

  const shaderCode = await fetch("shader.wgsl").then((r) => r.text());
  const module = device.createShaderModule({ code: shaderCode });

  const info = await module.getCompilationInfo?.();
  if (info?.messages?.length) {
    for (const m of info.messages) {
      console[m.type === "error" ? "error" : "warn"](
        `[WGSL ${m.type}] L${m.lineNum}:${m.linePos} ${m.message}`
      );
    }
    if (info.messages.some((m) => m.type === "error")) {
      showFallback();
      fallback.querySelector("p").textContent =
        "Shader compile failed — see console for WGSL errors.";
      return;
    }
  }

  const pipeline = device.createRenderPipeline({
    layout: "auto",
    vertex: { module, entryPoint: "vs_main" },
    fragment: {
      module,
      entryPoint: "fs_main",
      targets: [{ format }],
    },
    primitive: { topology: "triangle-list" },
  });

  const uniformBuffer = device.createBuffer({
    size: UNIFORM_BYTES,
    usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
  });

  const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [{ binding: 0, resource: { buffer: uniformBuffer } }],
  });

  const uniforms = new Float32Array(UNIFORM_FLOATS);

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
      // Jump toward next layout morph
      state.time += LAYOUT_DWELL * 0.9;
    } else if (e.key === "c" || e.key === "C") {
      // Jump toward next ring episode
      state.time += RING_DWELL * 0.95;
    } else if (e.key === "r" || e.key === "R") {
      state.seed = Math.random() * 10;
      state.autoTheme = true;
      state.time += THEME_DWELL * 0.85;
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

    state.frames += 1;
    if (now - state.fpsWindowStart >= 500) {
      state.fps = (state.frames * 1000) / (now - state.fpsWindowStart);
      state.frames = 0;
      state.fpsWindowStart = now;
      statsEl.textContent = `${state.fps.toFixed(0)} fps · ${canvas.width}×${canvas.height} · ${layoutLabel()} · ${themeLabel()} · ×${mirrorsLabel()} · ${ringLabel()}`;
    }

    uniforms[0] = canvas.width;
    uniforms[1] = canvas.height;
    uniforms[2] = state.time;
    uniforms[3] = state.seed;
    uniforms[4] = state.mouse[0];
    uniforms[5] = state.mouse[1];
    uniforms[6] = state.themeA;
    uniforms[7] = state.themeB;
    uniforms[8] = state.themeMix;
    uniforms[9] = state.mirrorsA;
    uniforms[10] = state.mirrorsB;
    uniforms[11] = state.mirrorMix;
    uniforms[12] = state.intensity;
    uniforms[13] = state.layoutA;
    uniforms[14] = state.layoutB;
    uniforms[15] = state.layoutMix;
    uniforms[16] = state.ringAmount;
    uniforms[17] = 0;
    uniforms[18] = 0;
    uniforms[19] = 0;
    device.queue.writeBuffer(uniformBuffer, 0, uniforms);

    const encoder = device.createCommandEncoder();
    const view = context.getCurrentTexture().createView();
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
    pass.setPipeline(pipeline);
    pass.setBindGroup(0, bindGroup);
    pass.draw(3);
    pass.end();
    device.queue.submit([encoder.finish()]);

    requestAnimationFrame(frame);
  }

  requestAnimationFrame(frame);
}

init().catch((err) => {
  console.error(err);
  showFallback();
});
