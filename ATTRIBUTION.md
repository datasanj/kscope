# Attribution & licenses

Source for Mandala flowers was ingested from
[`nabeel-oz/glsl-to-mp4`](https://github.com/nabeel-oz/glsl-to-mp4)
(`references/MandalaFlowers.md`, optional `generators/mandala_flowers.py`) —
**not** scraped from live Shadertoy.com. The listing is the Image-pass GLSL for
[https://www.shadertoy.com/view/NlcSRB](https://www.shadertoy.com/view/NlcSRB).

## Mandala flowers (CC0) — Mårten Rånge

The **flock** layout is adapted from:

- **[Mandala flowers](https://www.shadertoy.com/view/NlcSRB)** by **Mårten Rånge (mrange)**
- Shader header: `// CCO: Mandala flowers` (typo for **CC0**)
- Confirmed in glsl-to-mp4 README: **"Mandala flowers" by Mårten Rånge (CC0)**
- **Safe to adapt**

kscope adaptations: WGSL port, Holi powder palettes instead of `hsv2rgb`, mouse
parallax, sheep-genome integration / dual transitions, lighter vignette (full IQ
`postProcess` gamma stack omitted — we use the existing Holi filmic finish).

### Helper licenses inside the Mandala flowers listing

| Helper | License | Author / source | kscope use |
| --- | --- | --- | --- |
| `smoothKaleidoscope`, `toPolar`, `toRect`, `pabs`, `pmax` | **CC0** | mrange [glsl-snippets](https://github.com/mrange/glsl-snippets) | Ported |
| Mandala flowers body (`clogo`, `figure_8`, `merge`, `stripes`, `effect`) | **CC0** | Mårten Rånge | Ported |
| `hex`, `pmin` | **MIT** | Inigo Quilez | Ported |
| `postProcess` | **MIT** | Inigo Quilez | Not fully ported (vignette idea only; filmic Holi finish instead) |
| `modPolar`, `modMirror1` | **MIT OR CC-BY-NC-4.0** (hg_sdf) | mercury | Ported **under MIT** — do not rely on NC |
| `hsv2rgb` | **WTFPL** | sam hocevar | **Not used** — Holi `palette_theme` instead |
| `hextile` | Unknown / Art of Code (Martijn Steinrucken) | YouTube hex tiling | **Rewritten** — axial/cube-round hex tiling (original for kscope) |
| `hash` | Unknown | — | **Replaced** — Dave Hoskins “Hash without Sine” (**MIT**, [4djSRW](https://www.shadertoy.com/view/4djSRW)) |
| `fast_atan2` | P. Gilcher / Shadertoy flSXRV | — | **Not used** — standard `atan2` |

Prefer **CC0 + MIT** helpers; unclear pieces were rewritten as noted above.

## Truchet + kaleidoscope — idea only, not a source paste

The **truchet** layout is an **original WGSL reimplementation** of the *idea* of
combining smooth polar / kaleidoscope folds with Truchet-like cell patterns,
loosely inspired by [Truchet + Kaleidoscope FTW](https://www.shadertoy.com/view/7lKSWW).

**Do not paste 7lKSWW source verbatim.** Live Shadertoy license for that shader
is unconfirmed from our side (some Godot ports claim a CC0 header; Shaderfuse
lists CC BY-NC-SA 3.0 default for related conversions). kscope’s Truchet path
uses original distances, Holi genome multi-hue coloring, and this repo’s fold
helpers.

## Other inspirations (aesthetic / technique, not copied engines)

- Electric Sheep / flam3 — dreamy IFS aesthetic; closed-form UV variations only
- kishimisu shader art intro
- Octagrams-scale bold forms ([tlVGDt](https://www.shadertoy.com/view/tlVGDt) aesthetic)
- Dave Hoskins hash (MIT) as above
