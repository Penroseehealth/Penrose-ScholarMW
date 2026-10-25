# Gram staining workflow animation

Plain HTML / CSS / JS. No libraries, no build step.

- `index.html`      page markup and the whole SVG scene (bench, bottles, tap, burner, slide, microscope field)
- `gram-stain.css`  theme tokens (light/dark via CSS variables) and animation keyframes
- `gram-stain.js`   one IIFE: the 11 steps, bottle/drop/rinse/flame logic, controls
- `assets/slide.webp`      cut-out photo of the slide (stain removed)
- `assets/smear-mask.png`  grey-scale mask used to recolour the smear

To embed in another page: either use an `<iframe src="gram-stain/index.html">`, or copy the
`<main>` block into your page, include the CSS and JS, and keep the element ids (the script finds
everything by id). Serve over http(s); opening via file:// may block the mask image in some browsers.
