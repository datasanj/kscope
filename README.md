# kscope

WebGPU kaleidoscope inspired by [kishimisu’s shader art intro](https://www.youtube.com/watch?v=f4s1h2YETNY) and the dreamy neon aesthetic of [Electric Sheep](https://electricsheep.org) / [flam3](https://github.com/scottdraves/flam3).

Built for **high resolution and high refresh** (4K @ 120Hz class hardware): fragment-only sheep, dual-texture transitions only while morphing, no IFS histogram.

## What runs on the GPU

- Layouts: **kaleido** · **polar tunnel** · **hybrid** · **flock** (Mandala flowers hex field) · **truchet** (original polar-fold + cell arcs)
- **Dual-sheep transitions** — current genome A and next genome B both advance in time, rendered to textures, then composited (not a boring global alpha dissolve as the only mode)
- Mix modes: **hex cell takeover** (default when flock is involved) · **polar iris / tunnel swallow** · **kaleido wedge wipe** · **additive storm**
- Genome morph underneath: mirrors / petal feel / palette seeds lerp during the blend
- Holi gulal powder palettes (gulabi / laal / kesar / hari / rang / neela)
- Mouse parallax, episodic quiet / sparse / storm rings, flam3 UV warps
- Quality toggle: dual half-res during transitions (default) vs full dual (`Q`) — dual full shaders at 4K are heavy; half-res keeps FPS sane

Intentionally **not** ported from Electric Sheep: chaos-game IFS accumulation, density estimation filters, and heavy tone-mapping passes.

## Attribution

See **[ATTRIBUTION.md](./ATTRIBUTION.md)**.

- **Flock / Mandala flowers:** adapted from [Mandala flowers](https://www.shadertoy.com/view/NlcSRB) by Mårten Rånge — **CC0**
- **Truchet layout:** original WGSL inspired by the *idea* of [7lKSWW](https://www.shadertoy.com/view/7lKSWW) — **not** a verbatim paste; that Shadertoy’s live license is unconfirmed for commercial reuse

## Run

```bash
npm start
```

Open `http://localhost:8787` in Chrome / Edge (WebGPU).

## Controls

| Input | Action |
| --- | --- |
| Move mouse | Strong parallax / orbit / swirl |
| Click | Remix palette seed |
| `0` | Auto theme transitions (default) |
| `1`–`6` | Pin Holi mix: gulabi / laal / kesar / hari / rang / neela |
| `T` | Jump toward next sheep / layout morph (triggers dual transition) |
| `X` | Jump into transition + cycle mix mode (hex → iris → wedge → storm) |
| `M` | Pin / cycle mix mode without jumping |
| `F` | Jump to **flock** (Mandala flowers) sheep |
| `U` | Jump to **truchet** sheep |
| `C` | Jump toward next ring episode |
| `Q` | Toggle dual-transition quality: half-res (default) ↔ full-res |
| `R` | Remix seed + jump toward next morph |
| Space | Pause |
| `+` / `-` | Intensity |

### Trying each transition

1. Press `M` until the HUD mix name shows the mode you want (`hex` / `iris` / `wedge` / `storm`), or use `X` to jump + cycle.
2. Press `T` (or wait for auto sheep dwell ~11s) to enter a dual-render crossfade.
3. For **hex takeover**, press `F` first so a flock sheep is involved (hex is also auto-preferred whenever flock is in the A/B pair).
4. Watch the HUD: during a fade it shows the mix name and `½res×2` or `full×2`.

Auto mode also rotates layouts through flock and truchet on its own; dual transitions fire whenever the sheep genome slot advances.
