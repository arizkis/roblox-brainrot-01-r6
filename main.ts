// Brainrot Bazaar — the make.fun entrypoint: hands the game in for judging.
// Node 22, standard library only, erasable TypeScript: run it as `node main.ts` — no flags, no build,
// no install.
//
// What it does, in order:
//   1. Logs the game title and how many Luau source files ship under src/.
//   2. Copies the four artifacts the grader reads, from beside this file into the output directory:
//      game.rbxl (the Rojo-built place), src/ (the Luau sources), screenshots/ (PNG/JPEG stills; the
//      first by name is the cover) and PLAY.json (the published place binding).
//   3. Writes dossier.json into the output directory: the canonical summary of the place and its
//      scripts, built by the vendored make.fun library (vendor/makefun-roblox.ts) under the scorer's
//      own caps, so the dossier we hand in is byte-for-byte the one the scorer would build itself.
//
// The dotted-name rule: every file and directory whose name starts with a dot (.git, .DS_Store,
// .gitkeep, ...) is skipped at any depth while copying, because the grader refuses an output holding
// any name outside letters, digits, . _ and -.
//
// The output directory is MAKEFUN_OUTPUT_DIR when set, else /output (the grader's container).
// MAKEFUN_OUTPUT_DIR is the stand-in for trying it locally:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** How many .luau files sit under dir, dot-names excluded to match what actually gets copied. */
function countLuau(dir: string): number {
  let n = 0;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('.')) continue;
    if (entry.isDirectory()) n += countLuau(join(dir, entry.name));
    else if (entry.name.endsWith('.luau')) n += 1;
  }
  return n;
}

console.log(`Brainrot Bazaar — shipping ${countLuau(join(here, 'src'))} Luau source files`);

mkdirSync(out, { recursive: true });

/** cpSync's filter: refuse every file and directory whose name starts with a dot, at any depth. */
const skipDotted = (path: string): boolean => !basename(path).startsWith('.');

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: skipDotted });
cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: skipDotted });

// The scorer's caps: only text_max_bytes shapes the dossier's bytes; the rest refuse exactly what the
// scorer would refuse — at most 4 screenshots of 256 KiB each, a place of at most 500000 instances
// whose scripts hold at most 8 MiB of source and whose script paths come to at most 1048576 characters.
const dossier = buildDossier(out, {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
});
writeFileSync(join(out, 'dossier.json'), dossier);
console.log(`Wrote ${join(out, 'dossier.json')} (${dossier.length} bytes)`);
