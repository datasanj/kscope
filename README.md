# kscope

WebGPU Holi-powder kaleidoscope — colorful effects inspired by the Electric Sheep
screensaver, built for high resolution / high refresh (4K @ 120Hz class).

Fragment-only effects; dual-texture transitions only while morphing; no IFS histogram.
**Heavy raymarch layouts that dropped below ~60fps were removed** (see EFFECTS_ADDED.md).

Live catalog: **[EFFECTS_ADDED.md](./EFFECTS_ADDED.md)**.

## Layouts (auto-cycled)

| HUD name | What |
| --- | --- |
| `flock` | Mandala flowers hex field (CC0 mrange) |
| `truchet` | Polar-fold + Truchet cells (idea-only Holi) |
| `golden` | Golden apollian (CC0 mrange) → Holi/φ |
| `logspiral` | Log spiral of spheres (CC0 mrange) → Holi |
| `apollo` | Apollian with a twist (CC0 mrange) |
| `eel` | Electric Eel Universe (CC0 mrange) |
| `eelaudio` | Eel audio fork — faux beat, optional mic |
| `gulal_pulse` | Original Holi radial energy rings (Quasar *feel*; not a port) |
| `neonwave` | Neonwave sunrise (**CC0** mrange) → Holi |
| `ai_heart` | AI not included (**CC0** mrange) → Holi |
| `starry_pl` | Starry planes (**CC0** mrange) → Holi |

Dual-effect transitions: **hex** (default when flock involved) · **iris** · **wedge** · **storm**.

Holi gulal rainbow on everything (gulabi / laal / kesar / hari / **rang** default / neela). Filmic ceiling avoids whiteout.

## Quality

Dual-effect transitions always render at **full canvas resolution** (½res path removed — it upscaled into a visible pixel grid). Linear filtering kept on the composite sampler. Canvas buffer tracks CSS size × DPR (capped at 3840).

| Key | Effect |
| --- | --- |
| `V` | Quality **LQ** (default) ↔ **HQ** caps on remaining layouts |

## Controls

| Input | Action |
| --- | --- |
| Mouse move | **Holi color cycle** (palette / powder phase — not pan/orbit) |
| Click | **Next effect** dual fade (same as `T` — not color remix) |
| `0` | Auto Holi themes (rang-heavy) |
| `1`–`6` | Pin Holi bias / color (still multi-hue) |
| `T` | Next effect dual fade |
| `X` / `M` | Cycle mix mode (hex→iris→wedge→storm) |
| `F` flock · `U` truchet · `G` golden · `L` logspiral · `P` apollo · `E` eel · `J` eelaudio · `H` gulal_pulse · `N` neonwave · `I` ai_heart · `Z` starry_pl | Jump layout |
| `A` | Toggle optional mic for `eelaudio` (fallback: time faux-beat) |
| `V` | Layout quality caps |
| `R` | Remix seed + jump morph |
| Space · `+`/`-` | Pause · intensity |

## Attribution

Full titles, authors, URLs, licenses: **[ATTRIBUTION.md](./ATTRIBUTION.md)**.
FPS cull + removable list: **[EFFECTS_ADDED.md](./EFFECTS_ADDED.md)**.

Highlights:

- Mandala flowers — mrange **CC0** — https://www.shadertoy.com/view/NlcSRB (via glsl-to-mp4)
- Apollian with a twist / Electric Eel — mrange **CC0** (Shaderfuse ports)
- Neonwave / AI not included / Starry planes — mrange **CC0** (Shaderfuse SoTW author `CC0:`)
- Removed for FPS: starnest, reflect, bubble, mandelbulb, twinkle_tun, clearly_bug, beats4d
- Do **not** paste Truchet 7lKSWW or NC-SA material; do not re-add weak MIT kaleido toys

## Run

```bash
npm start
```

Open `http://localhost:8787` (Chrome / Edge WebGPU). Live: https://kscope.pages.dev
