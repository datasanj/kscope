# Attribution & licenses

Boring kaleido/tunnel/hybrid layouts were removed. kscope ships **colorful Holi-rainbow
layouts only**. Sources were ingested from mirrors (**not** live Shadertoy.com).

## Mandala flowers / flock — CC0

- **[Mandala flowers](https://www.shadertoy.com/view/NlcSRB)** by **Mårten Rånge (mrange)**
- Header typo `CCO` = **CC0**; confirmed in [`nabeel-oz/glsl-to-mp4`](https://github.com/nabeel-oz/glsl-to-mp4) README
- Source: `references/MandalaFlowers.md` (+ optional `generators/mandala_flowers.py`)
- Holi palettes replace `hsv2rgb`; unknown `hash` → Dave Hoskins MIT; Art of Code `hextile` rewritten (axial)

### Helper licenses (Mandala flowers listing)

| Helper | License | Notes |
| --- | --- | --- |
| `smoothKaleidoscope`, `toPolar`, `toRect`, `pabs`, `pmax` | **CC0** mrange | Ported |
| `hex`, `pmin` | **MIT** IQ | Ported |
| `modPolar`, `modMirror1` | **MIT** (hg_sdf dual MIT/NC — we use MIT) | Ported |
| `hsv2rgb` | WTFPL | Unused (Holi instead) |
| `hextile` / `hash` | Unknown | Rewritten |

## Truchet — idea only

Original WGSL inspired by the *idea* of [7lKSWW](https://www.shadertoy.com/view/7lKSWW).
**Do not paste 7lKSWW.** License unconfirmed for commercial reuse.

## Shippable colorful layouts (8 newcomers)

| Layout (HUD) | Title | URL | License / author | Source used |
| --- | --- | --- | --- | --- |
| `starnest` | Star Nest | https://www.shadertoy.com/view/XlfGRj | **MIT** — Pablo Roman Andrioli (Kali) | **Prefer in-repo** [`references/StarNest.md`](./references/StarNest.md) (copied from [`nabeel-oz/glsl-to-mp4`](https://github.com/nabeel-oz/glsl-to-mp4) `references/StarNest.md`). Header: `// Star Nest by Pablo Roman Andrioli` / `// License: MIT` + full Image-pass GLSL. **Do not fetch from Shadertoy.com.** WGSL port keeps the MIT volume; Holi remap is a kscope post step. |
| `golden` | Golden apollian | https://www.shadertoy.com/view/WlcfRS | **CC0** — mrange | Apollonian DE family adapted with φ-scale + Holi/golden bias (full Image listing not in mirrors; technique aligned with secured Apollian-with-a-twist) |
| `logspiral` | Logarithmic spiral of spheres | https://www.shadertoy.com/view/msGXRD | **CC0** — mrange | Holi log-polar sphere packing inspired by the CC0 title (mirror Image listing unavailable; original WGSL adaptation) |
| `apollo` | Apollian with a twist | https://www.shadertoy.com/view/Wl3fzM | **CC0** — mrange | Shaderfuse `ApollianWithATwist.fuse` kernel → WGSL + Holi |
| `eel` | Electric Eel Universe | https://www.shadertoy.com/view/cdV3DW | **CC0** body (+ MIT IQ cylinder; WTFPL hsv unused; hg_sdf MIT path) — mrange | Shaderfuse `ElectricEelUniverse.fuse` (non-audio path) → WGSL + Holi |
| `eelaudio` | Electric Eel audio fork | https://www.shadertoy.com/view/cddSRM | Same lineage as eel (**CC0**) | Time-driven **faux-reactive** beat by default; optional mic via `A` (AnalyserNode). Does not require mic. |
| `reflect` | Let's self reflect | https://www.shadertoy.com/view/XfyXRV | **CC0** — author | Shaderfuse `LetSSelfReflect.fuse` (CC0 description); quality-gated recursive mirror/Holi solid (full polyhedra+refraction simplified for 4K) |
| `bubble` | Reflective bubble tunnel | https://www.shadertoy.com/view/wcyXzV | **CC0** — mrange | Holi reflective bubble corridor adaptation (CC0 title; mirror Image listing unavailable) |

### Electric Eel component notes

From the Shaderfuse port of cdV3DW:

- Body: **CC0** mrange
- `rayCylinder`: **MIT** — Inigo Quilez
- `mod1` (hg_sdf): **MIT** path (dual-licensed MIT OR CC-BY-NC-4.0 — we use MIT)
- `hsv2rgb`: WTFPL — unused (Holi powders instead)
- Unknown hash → Dave Hoskins **MIT** in kscope

## gulal_pulse — original (inspired by Quasar aesthetic)

- HUD: `gulal_pulse`
- Inspired by the **radial-ring aesthetic** of **[Quasar](https://www.shadertoy.com/view/msGyzc)** by **kishimisu**
- Upstream Quasar is **CC BY-NC-SA** — **not** pasted, translated, or line-ported
- kscope ships an **original** WGSL concentric / pulsing Holi energy-ring effect
- Color uses Holi powders + Inigo Quilez **cosine palette** (**MIT**) — not Quasar’s color code

## Other

- Dave Hoskins “Hash without Sine” — **MIT** — https://www.shadertoy.com/view/4djSRW
- Inigo Quilez cosine palette — **MIT** — https://iquilezles.org/articles/palettes/
- Electric Sheep / flam3 aesthetic (closed-form UV ideas only in retired classic path)
- Dual-effect transition composites are original to kscope
