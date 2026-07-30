# kscope

WebGPU kaleidoscope inspired by [kishimisu’s shader art intro](https://www.youtube.com/watch?v=f4s1h2YETNY) and the dreamy neon aesthetic of [Electric Sheep](https://electricsheep.org) / [flam3](https://github.com/scottdraves/flam3).

Built for **high resolution and high refresh** (4K @ 120Hz class hardware): one fullscreen triangle, a cheap fragment shader, no IFS histogram, no multipass bloom.

## What runs on the GPU

Fragment-only techniques that stay fast at 4K:

- Layout morphs: **kaleido ↔ polar tunnel** (4djBRm-style) ↔ **hybrid kaleido-tunnel** (tfBXzD-inspired)
- Dihedral folds with **evolving mirror counts** (3→16)
- Six theme genomes that auto-interpolate; episodic **quiet / sparse / storm** circle fields
- Extra flam3 UV warps: ex, exponential, cross, blade (+ prior swirl/spherical/horseshoe/…)
- Tunnel ribs, angular lanes, vanishing-point bloom — still single-pass, no raymarch
- Soft filmic remap (log-density nod without a histogram)

Intentionally **not** ported from Electric Sheep: chaos-game IFS accumulation, density estimation filters, and heavy tone-mapping passes — those fight 4K@120.

## Run

```bash
npm start
```

Open `http://localhost:8787` in Chrome / Edge (WebGPU).

## Controls

| Input | Action |
| --- | --- |
| Move mouse | Parallax drift |
| Click | Remix palette seed |
| `0` | Auto theme transitions (default) |
| `1`–`6` | Pin theme: ribbon / gothic / bloom / spiral / heart / curl |
| `R` | Remix seed + jump toward next morph |
| Space | Pause |
| `+` / `-` | Intensity |
