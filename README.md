# kscope

WebGPU Holi-powder kaleidoscope — a living flock of Electric Sheep–inspired
mandalas, built for high resolution and high refresh (4K @ 120Hz class hardware).

Fragment-only sheep, dual-texture transitions only while morphing, no IFS histogram.

## What runs on the GPU

**Colorful layouts only** (boring sparse kaleido / thin tunnel / hybrid removed):

- **flock** — Mandala flowers hex field (CC0 mrange) with riot Holi powder on every petal & glow
- **truchet** — original polar-fold + cell arcs, multi-hue Holi lanes (idea-only; not a 7lKSWW paste)

Also:

- **Dual-sheep transitions** — A and B both advance in time, then composite:
  **hex cell takeover** (default when flock is involved) · **polar iris** · **kaleido wedge** · **additive storm**
- Genome morph underneath (mirrors / palette seeds lerp during the blend)
- Holi gulal rainbow on everything: gulabi / laal / kesar / hari / **rang** (default bias) / neela — pinned themes still show multiple powders, never monochrome
- Mouse parallax, episodic ring energy, dual half-res quality toggle (`Q`)

## Attribution

See **[ATTRIBUTION.md](./ATTRIBUTION.md)** for the full helper-license table.

- **Flock / Mandala flowers:** adapted from [Mandala flowers](https://www.shadertoy.com/view/NlcSRB) by **Mårten Rånge (mrange)** — **CC0** (shader header typo `CCO`). Source ingested from [`nabeel-oz/glsl-to-mp4`](https://github.com/nabeel-oz/glsl-to-mp4) `references/MandalaFlowers.md` (not live Shadertoy.com).
- Prefer CC0 + MIT helpers from that listing; unknown `hash` / Art of Code `hextile` were **rewritten**; Holi palettes replace `hsv2rgb`.
- **Truchet layout:** original WGSL inspired by the *idea* of [7lKSWW](https://www.shadertoy.com/view/7lKSWW) — **do not paste** that shader; license unconfirmed for commercial reuse.

## Run

```bash
npm start
```

Open `http://localhost:8787` in Chrome / Edge (WebGPU). Live: [kscope.pages.dev](https://kscope.pages.dev).

## Controls

| Input | Action |
| --- | --- |
| Move mouse | Strong parallax / orbit / swirl |
| Click | Remix palette seed |
| `0` | Auto theme transitions (rang-heavy Holi riot; default) |
| `1`–`6` | Pin Holi bias: gulabi / laal / kesar / hari / rang / neela (still multi-hue) |
| `T` | Jump toward next sheep morph (flock ↔ truchet dual transition) |
| `X` | Jump into transition + cycle mix mode (hex → iris → wedge → storm) |
| `M` | Pin / cycle mix mode without jumping |
| `F` | Jump to **flock** (Mandala flowers) |
| `U` | Jump to **truchet** |
| `C` | Jump toward next ring episode |
| `Q` | Toggle dual-transition quality: half-res (default) ↔ full-res |
| `R` | Remix seed + jump toward next morph |
| Space | Pause |
| `+` / `-` | Intensity |

### Trying each transition

1. Press `M` until the HUD mix name shows the mode you want (`hex` / `iris` / `wedge` / `storm`), or use `X` to jump + cycle.
2. Press `T` (or wait for auto sheep dwell ~11s) to enter a dual-render crossfade.
3. For **hex takeover**, press `F` first (hex is also auto-preferred whenever flock is in the A/B pair).
4. Watch the HUD: during a fade it shows the mix name and `½res×2` or `full×2`.

Auto mode only cycles **flock** and **truchet** — never the removed sparse layouts.
