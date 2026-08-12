# kscope

WebGPU Holi-powder kaleidoscope — a living flock of Electric Sheep–inspired
colorful shaders, built for high resolution / high refresh (4K @ 120Hz class).

Fragment-only sheep; dual-texture transitions only while morphing; no IFS histogram.
**Boring kaleido / thin tunnel / hybrid layouts are gone.**

## Layouts (auto-cycled)

| HUD name | What |
| --- | --- |
| `flock` | Mandala flowers hex field (CC0 mrange) |
| `truchet` | Polar-fold + Truchet cells (idea-only Holi) |
| `starnest` | Star Nest kaliset volume (MIT Kali; source `references/StarNest.md`) → Holi |
| `golden` | Golden apollian (CC0 mrange) → Holi/φ |
| `logspiral` | Log spiral of spheres (CC0 mrange) → Holi |
| `apollo` | Apollian with a twist (CC0 mrange) |
| `eel` | Electric Eel Universe (CC0 mrange) |
| `eelaudio` | Eel audio fork — faux beat, optional mic |
| `reflect` | Let’s self reflect (CC0) — quality-gated mirrors |
| `bubble` | Reflective bubble tunnel (CC0 mrange) |

Dual-sheep transitions: **hex** (default when flock involved) · **iris** · **wedge** · **storm**.

Holi gulal rainbow on everything (gulabi / laal / kesar / hari / **rang** default / neela). Filmic ceiling avoids whiteout.

## Quality

| Key | Effect |
| --- | --- |
| `Q` | Dual-transition half-res (default) ↔ full dual |
| `V` | Raymarch **LQ** (default, 4K-friendlier) ↔ **HQ** caps |

Heavy layouts (`starnest`, `reflect`, `bubble`, eels) use iteration caps; HQ raises them.

## Controls

| Input | Action |
| --- | --- |
| Mouse | Parallax / orbit |
| Click | Remix seed |
| `0` | Auto Holi themes (rang-heavy) |
| `1`–`6` | Pin Holi bias (still multi-hue) |
| `T` | Next sheep dual fade |
| `X` / `M` | Cycle mix mode (hex→iris→wedge→storm) |
| `F` flock · `U` truchet · `S` starnest · `G` golden · `L` logspiral · `P` apollo · `E` eel · `J` eelaudio · `Y` reflect · `B` bubble | Jump layout |
| `A` | Toggle optional mic for `eelaudio` (fallback: time faux-beat) |
| `Q` / `V` | Dual res / raymarch quality |
| `R` | Remix + jump morph |
| Space · `+`/`-` | Pause · intensity |

## Attribution

Full titles, authors, URLs, licenses: **[ATTRIBUTION.md](./ATTRIBUTION.md)**.

Highlights:

- Mandala flowers — mrange **CC0** — https://www.shadertoy.com/view/NlcSRB (via glsl-to-mp4)
- Star Nest — Kali **MIT** — https://www.shadertoy.com/view/XlfGRj
- Apollian with a twist / Electric Eel — mrange **CC0** (Shaderfuse ports)
- Do **not** paste Truchet 7lKSWW or NC-SA material

## Run

```bash
npm start
```

Open `http://localhost:8787` (Chrome / Edge WebGPU). Live: https://kscope.pages.dev
