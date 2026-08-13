# Attribution & licenses

kscope ships a **60fps Holi-rainbow** set. Heavy raymarch layouts were **removed for FPS**
(see EFFECTS_ADDED.md). Sources from mirrors (**not** live Shadertoy.com) where noted.

## Live layouts

### Mandala flowers / flock — CC0

- **[Mandala flowers](https://www.shadertoy.com/view/NlcSRB)** by **Mårten Rånge (mrange)**
- Header typo `CCO` = **CC0**; confirmed in [`nabeel-oz/glsl-to-mp4`](https://github.com/nabeel-oz/glsl-to-mp4) README
- Holi palettes replace `hsv2rgb`; unknown `hash` → Dave Hoskins MIT; Art of Code `hextile` rewritten (axial)

### Truchet — idea only

Original WGSL inspired by the *idea* of [7lKSWW](https://www.shadertoy.com/view/7lKSWW).
**Do not paste 7lKSWW.**

### Golden / logspiral / apollo / eel — CC0 mrange

| HUD | Title | URL | License | Notes |
| --- | --- | --- | --- | --- |
| `golden` | Golden apollian | https://www.shadertoy.com/view/WlcfRS | **CC0** mrange | Adapted φ-scale + Holi |
| `logspiral` | Logarithmic spiral of spheres | https://www.shadertoy.com/view/msGXRD | **CC0** mrange | Holi adaptation |
| `apollo` | Apollian with a twist | https://www.shadertoy.com/view/Wl3fzM | **CC0** mrange | Shaderfuse kernel → WGSL + Holi |
| `eel` / `eelaudio` | Electric Eel Universe (+ audio fork) | https://www.shadertoy.com/view/cdV3DW · https://www.shadertoy.com/view/cddSRM | **CC0** body (+ MIT IQ cylinder) | Shaderfuse; faux beat / optional mic |

### gulal_pulse — original

- Inspired by the *radial-ring aesthetic* of **[Quasar](https://www.shadertoy.com/view/msGyzc)** (kishimisu) — **CC BY-NC-SA**, **not** a port
- Holi powders + IQ cosine palette (**MIT**)

### Live Shaderfuse SoTW CC0 ports

Author `CC0:` on Shadertoy description (prefer over Fuse packaging NC-SA lines).

| HUD | Title | Shaderfuse | Shadertoy |
| --- | --- | --- | --- |
| `neonwave` | Neonwave sunrise | [NeonwaveSunrise](https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/NeonwaveSunrise/) | [7dyyRy](https://www.shadertoy.com/view/7dyyRy) |
| `ai_heart` | AI not included | [AiNotIncluded](https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/AiNotIncluded/) | [ctd3Rl](https://www.shadertoy.com/view/ctd3Rl) |
| `starry_pl` | Starry planes | [StarryPlanes](https://nmbr73.github.io/Shaderfuse/ShaderOfTheWeek/StarryPlanes/) | [MfjyWK](https://www.shadertoy.com/view/MfjyWK) |

## Removed for FPS (not live)

| HUD | Title | License | Notes |
| --- | --- | --- | --- |
| `starnest` | Star Nest | **MIT** Kali — [XlfGRj](https://www.shadertoy.com/view/XlfGRj) / [`references/StarNest.md`](./references/StarNest.md) | Culled — nested volume too heavy |
| `reflect` | Let’s self reflect | **CC0** — [XfyXRV](https://www.shadertoy.com/view/XfyXRV) | Culled — multi-bounce |
| `bubble` | Reflective bubble tunnel | **CC0** — [wcyXzV](https://www.shadertoy.com/view/wcyXzV) | Culled — raymarch |
| `mandelbulb` | Inside the mandelbulb II | **CC0** — [mtScRc](https://www.shadertoy.com/view/mtScRc) | Culled — DE + march |
| `twinkle_tun` | Trailing the Twinkling Tunnel | **CC0** — [WfcGWj](https://www.shadertoy.com/view/WfcGWj) | Culled |
| `clearly_bug` | Clearly a bug | **CC0** — [33cGDj](https://www.shadertoy.com/view/33cGDj) | Culled |
| `beats4d` | 4D Beats | **CC0** — [tfK3Dy](https://www.shadertoy.com/view/tfK3Dy) | Culled after animation pass — still too costly |

## Rejected weak toys (never re-add)

RainbowKaleidoscope, zebiv kaleidoscope, mm-dream, WebGL-Shader-Playground presets, brogli fold, Godot Simple Kaleidoscope.

## Other

- Dave Hoskins “Hash without Sine” — **MIT** — https://www.shadertoy.com/view/4djSRW
- Inigo Quilez cosine palette / helpers — **MIT**
- Electric Sheep / flam3 aesthetic (historical inspiration only)
- Dual-effect transition composites are original to kscope
