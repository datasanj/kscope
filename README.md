# kscope

WebGPU Holi-powder kaleidoscope — colorful effects inspired by the Electric Sheep
screensaver, built for high resolution / high refresh (4K @ 120Hz class).

Fragment-only effects; dual-texture transitions only while morphing; no IFS histogram.
**Boring kaleido / thin tunnel / hybrid layouts are gone.**

Removable catalog for this PR’s new CC0 ports: **[EFFECTS_ADDED.md](./EFFECTS_ADDED.md)**.

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
| `gulal_pulse` | Original Holi radial energy rings (inspired by Quasar *feel*; not a port) |
| `neonwave` | Neonwave sunrise (**CC0** mrange) → Holi |
| `ai_heart` | AI not included (**CC0** mrange) → Holi |
| `mandelbulb` | Inside the mandelbulb II (**CC0** mrange) → Holi |
| `twinkle_tun` | Trailing the Twinkling Tunnel (**CC0** mrange) → Holi |
| `starry_pl` | Starry planes (**CC0** mrange) → Holi |
| `clearly_bug` | Clearly a bug (**CC0** mrange) → Holi |
| `beats4d` | 4D Beats (**CC0** mrange) → Holi |

Dual-effect transitions: **hex** (default when flock involved) · **iris** · **wedge** · **storm**.

Holi gulal rainbow on everything (gulabi / laal / kesar / hari / **rang** default / neela). Filmic ceiling avoids whiteout.

## Quality

| Key | Effect |
| --- | --- |
| `Q` | Dual-transition half-res (default) ↔ full dual |
| `V` | Raymarch **LQ** (default, 4K-friendlier) ↔ **HQ** caps |

Heavy layouts (`starnest`, `reflect`, `bubble`, eels, `mandelbulb`, tunnels) use iteration caps; HQ raises them.

## Controls

| Input | Action |
| --- | --- |
| Mouse | Parallax / orbit |
| Click | **Next effect** dual fade (same as `T` — not color remix) |
| `0` | Auto Holi themes (rang-heavy) |
| `1`–`6` | Pin Holi bias / color (still multi-hue) |
| `T` | Next effect dual fade |
| `X` / `M` | Cycle mix mode (hex→iris→wedge→storm) |
| `F` flock · `U` truchet · `S` starnest · `G` golden · `L` logspiral · `P` apollo · `E` eel · `J` eelaudio · `Y` reflect · `B` bubble · `H` gulal_pulse · `N` neonwave · `I` ai_heart · `D` mandelbulb · `K` twinkle_tun · `Z` starry_pl · `W` clearly_bug · `O` beats4d | Jump layout |
| `A` | Toggle optional mic for `eelaudio` (fallback: time faux-beat) |
| `Q` / `V` | Dual res / raymarch quality |
| `R` | Remix seed + jump morph |
| Space · `+`/`-` | Pause · intensity |

## Attribution

Full titles, authors, URLs, licenses: **[ATTRIBUTION.md](./ATTRIBUTION.md)**.
Removable list for new ports: **[EFFECTS_ADDED.md](./EFFECTS_ADDED.md)**.

Highlights:

- Mandala flowers — mrange **CC0** — https://www.shadertoy.com/view/NlcSRB (via glsl-to-mp4)
- Star Nest — Kali **MIT** — prefer [`references/StarNest.md`](./references/StarNest.md) (not Shadertoy.com); credit https://www.shadertoy.com/view/XlfGRj
- Apollian with a twist / Electric Eel — mrange **CC0** (Shaderfuse ports)
- New SoTW **CC0** mrange ports: Neonwave, AI not included, Mandelbulb II, Twinkling Tunnel, Starry planes, Clearly a bug, 4D Beats
- `gulal_pulse` — original; Quasar *feel* only; upstream **NC-SA** — not a port
- Do **not** paste Truchet 7lKSWW or NC-SA material

## Run

```bash
npm start
```

Open `http://localhost:8787` (Chrome / Edge WebGPU). Live: https://kscope.pages.dev
