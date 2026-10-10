// Renders a Samsung Notes .sdocx with @twango/sdocx (GPL-3.0, run as a
// separate program by server.py).
//   node render.mjs <note.sdocx>                 -> {"page_count": N}
//   node render.mjs <note.sdocx> <page> <out.svg> -> also writes that page as
//                                                   SVG (skipped if out of range)
import { readFileSync, writeFileSync } from "node:fs";
import { initSync, DocumentSession } from "@twango/sdocx";

initSync({ module: readFileSync(new URL("./node_modules/@twango/sdocx/sdocx_bg.wasm", import.meta.url)) });

const [file, page, out] = process.argv.slice(2);
const doc = new DocumentSession(new Uint8Array(readFileSync(file)));
if (page !== undefined && Number(page) < doc.page_count) {
  const i = Number(page);
  let svg = doc.render_svg(i, "light");
  // Pages written on a tablet can use a wider canvas (e.g. 1600 px) than the
  // note's page size (1080 px); sdocx clips to the page size and loses the
  // right/bottom of the writing. Grow the viewport to cover every stroke.
  const p = doc.inspection().document.pages[i];
  if (p) {
    let maxX = p.width, maxY = p.height;
    for (const o of p.objects) {
      const b = Object.values(o.content)[0]?.bbox;
      if (b) { maxX = Math.max(maxX, b.x_max); maxY = Math.max(maxY, b.y_max); }
    }
    const w = Math.ceil(Math.max(maxX + 16, p.background?.width ?? 0, p.width));
    const h = Math.ceil(Math.max(maxY + 16, (p.height * w) / p.width));
    if (w > p.width || h > p.height) {
      const dims = (s) => s
        .replaceAll(`height="${p.height}"`, `height="${h}"`)
        .replaceAll(`width="${p.width}"`, `width="${w}"`);
      svg = dims(svg).replace(/viewBox="[^"]*"/, `viewBox="0 0 ${w} ${h}"`);
    }
  }
  writeFileSync(out, svg);
}
console.log(JSON.stringify({ page_count: doc.page_count }));
