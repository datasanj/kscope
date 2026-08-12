# Attribution & licenses

## Mandala flowers (CC0)

The **flock** layout (hexagonally tiled smooth-kaleidoscope mandalas) is adapted from:

- **[Mandala flowers](https://www.shadertoy.com/view/NlcSRB)** by **Mårten Rånge (mrange)**
- License: **CC0** (public domain dedication) — safe to adapt

Adaptations in this repo include: WGSL port, Holi powder palettes instead of HSV cycling, mouse parallax, integration with kscope sheep genomes / dual transitions, and a simplified petal motif for 4K cost.

Related helper ideas used in the original (hex tiling, smooth kaleidoscope, soft min/abs) are credited in the Shadertoy source comments (IQ, mercury hg_sdf, Art of Code, mrange glsl-snippets).

## Truchet + kaleidoscope — idea only, not a source paste

The **truchet** layout is an **original WGSL reimplementation** of the *idea* of combining smooth polar / kaleidoscope folds with Truchet-like cell patterns, loosely inspired by:

- [Truchet + Kaleidoscope FTW](https://www.shadertoy.com/view/7lKSWW) (Shadertoy)

**Do not treat this as a cleared commercial paste of 7lKSWW.** Live Shadertoy license for that shader is unconfirmed from our side (some Godot ports claim a CC0 header; Shaderfuse lists CC BY-NC-SA 3.0 default for related conversions). kscope’s Truchet path uses original distances, Holi genome coloring, and this repo’s fold helpers — not a verbatim port.

## Other inspirations (aesthetic / technique, not copied engines)

- Electric Sheep / flam3 — dreamy IFS aesthetic; we use closed-form UV variations only
- kishimisu shader art intro
- Octagrams-scale bold forms ([tlVGDt](https://www.shadertoy.com/view/tlVGDt) aesthetic)
