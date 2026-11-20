// Brainrot Bazaar — the make.fun entrypoint (Node 22, standard library only, no build step).
//
// What this program does: it hands the game in for judging. From the directory this file lives in,
// it copies the four artifacts the grader reads — game.rbxl (the Rojo-built place), src/ (the Luau
// sources), screenshots/ (PNG/JPEG stills; the first by name is the cover) and PLAY.json (the
// published place binding) — into the output directory, then writes dossier.json there: the
// canonical summary of the place and its scripts, produced by the vendored make.fun library
// (vendor/makefun-roblox.ts) under the scorer's own caps, so the dossier we hand in is byte-for-byte
// the one the scorer would build itself.
//
// Every file and directory whose name starts with a dot (.git, .DS_Store, .gitkeep, ...) is skipped
// at any depth while copying: the grader refuses an output holding a name outside letters, digits,
// . _ and -.
//
// The output directory is MAKEFUN_OUTPUT_DIR when set, else /output. To try it locally:
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
