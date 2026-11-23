// Builds STL files for every part of every model in ./src/<model>/<model>.scad,
// snapshots the source and regenerates the main README.md.
//
// Convention: every model lives in its own folder src/<model>/ and has a main file <model>.scad that defines
//     parts = ["lid", "base", ...];   // list of parts – one STL per item
//     part  = "all";                  // selected part, overridden by this script via -D
//     model_version = "1.2.0";        // semantic version of the model
// and renders exactly one part in a branch on `part` (see src/zbminir2-cord-floor-switch/).
// The changelog lives in the header comment of the .scad file:
//     // CHANGELOG (newest first ...)
//     // 1.2.0 - summary of the change
//     //   optional indented continuation lines
// Optional per-model documentation: src/<model>/README.md (the first paragraph under the title is used as the
// description in the main README).
//
// Optional: `preview_part = "all";` names the part that shows the ASSEMBLED (and coloured, via color()) object. It is
// rendered straight from the .scad into images/<base>-preview.png (it is not exported to STL, as STL has no colour).
// This is the only image that is generated; models without `preview_part` get no image.
// Optional presets: src/<model>/<model>.json (OpenSCAD Customizer parameter sets). When it holds any set besides
// "design default values", every set is built as its own variant; <base> = <model>-<preset-slug> (e.g.
// name-letter-anna). Without presets <base> = <model>.
//
// Output (generated, keep it – older versions stay untouched when you bump model_version):
//     dist/<model>/v<version>/
//         <base>-<part>.stl           one STL per part (and per preset)
//         <model>-v<version>.scad     snapshot of the source (+ <model>-v<version>.json snapshot of the presets)
//         images/<base>-preview.png   assembled / coloured preview (only with preview_part)
//
// Usage:
//     npm run build                      # all models -> dist/<model>/v<model_version>/
//     npm run build -- <model>           # one model
//     npm run build -- <model> <part>    # one part only (STL only; no preview, source snapshot or README refresh)
//     add --force to overwrite a version folder that was built from a different source
//     npm run build -- <model> --preset="Anna"   # one preset only (rebuilt even if up to date)
//     npm run build -- --readme          # only regenerate README.md (no OpenSCAD run)
// With presets a build is incremental: only variants whose files are missing or whose preset parameters changed
// are rebuilt, so adding a preset never needs a version bump (a changed .scad still does).
// An optional src/README.footer.md (e.g. the license section) is appended verbatim to README.md.
// Safety guard: if dist/<model>/v<version>/ already holds a source snapshot that differs from the current .scad,
// the build is refused (bump model_version instead, or pass --force). Rebuilding unchanged source is always allowed.
// A full model build is made in a temporary folder that replaces the version folder only when every part succeeded.
// The main README.md is regenerated at the end of every full build. The OpenSCAD path can be overridden with the
// OPENSCAD environment variable.

import { spawnSync } from 'node:child_process';
import {
    copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync,
} from 'node:fs';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(root, 'src');
const outRoot = join(root, 'dist');

// Title of the generated README = "name" from package.json (falls back to the folder name)
function packageName() {
    try {
        return JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).name || basename(root);
    } catch {
        return basename(root);
    }
}

const args = process.argv.slice(2);
const force = args.includes('--force');
const readmeOnly = args.includes('--readme');
const onlyPreset = args.find((a) => a.startsWith('--preset='))?.slice('--preset='.length) || null;
const [onlyModel, onlyPart] = args.filter((a) => !a.startsWith('--'));

function findOpenScad() {
    const candidates = [
        process.env.OPENSCAD,
        'openscad',
        'C:\\Program Files\\OpenSCAD\\openscad.exe',
        'C:\\Program Files\\OpenSCAD (Nightly)\\openscad.exe',
        'C:\\Program Files (x86)\\OpenSCAD\\openscad.exe',
        '/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD',
    ].filter(Boolean);
    for (const c of candidates) {
        const r = spawnSync(c, ['--version'], { encoding: 'utf8' });
        if (!r.error) return c;
    }
    console.error('OpenSCAD not found. Install it or set the OPENSCAD environment variable to the openscad(.exe) path.');
    process.exit(1);
}

// --- reading model metadata from the .scad source ---

const stripComments = (src) => src.replace(/\/\*[\s\S]*?\*\/|\/\/.*$/gm, '');

// Reads the array `parts = [ "a", "b" ];` (comments are ignored)
function readParts(src) {
    const m = stripComments(src).match(/^\s*parts\s*=\s*\[([^\]]*)\]\s*;/m);
    return m ? [...m[1].matchAll(/"([^"]+)"/g)].map((x) => x[1]) : null;
}

// Reads `model_version = "1.2.3";`
function readVersion(src) {
    const m = stripComments(src).match(/^\s*model_version\s*=\s*"(\d+\.\d+\.\d+)"\s*;/m);
    return m ? m[1] : null;
}

// Reads the CHANGELOG block from the header comments: [{ version, summary, details: [] }, ...]
function readChangelog(src) {
    const lines = src.split(/\r?\n/);
    const start = lines.findIndex((l) => /^\/\/\s*CHANGELOG\b/.test(l));
    if (start < 0) return [];
    const entries = [];
    for (const line of lines.slice(start + 1)) {
        if (!line.startsWith('//')) break;
        const body = line.replace(/^\/\/ ?/, '');
        const head = body.match(/^(\d+\.\d+\.\d+)\s*[-–]\s*(.*)$/);
        if (head) entries.push({ version: head[1], summary: head[2].trim(), details: [] });
        else if (body.trim() && entries.length) entries[entries.length - 1].details.push(body.trim());
    }
    return entries;
}

const compareVersions = (a, b) => {
    const pa = a.split('.').map(Number);
    const pb = b.split('.').map(Number);
    return pa[0] - pb[0] || pa[1] - pb[1] || pa[2] - pb[2];
};

function listModels() {
    if (!existsSync(srcDir)) return []; // no ./src/ yet = no models
    return readdirSync(srcDir)
        .filter((d) => statSync(join(srcDir, d)).isDirectory() && existsSync(join(srcDir, d, `${d}.scad`)))
        .sort();
}

// --- building ---

let failed = 0;
let built = 0;

const normText = (t) => t.replace(/\r\n/g, '\n');

// Optional `preview_part = "all";` – name of the part (rendered with -D part=...) that shows the ASSEMBLED, coloured
// object. It is rendered straight from the .scad (preview mode, so color() works) into images/<base>-preview.png.
function readPreviewPart(src) {
    const m = stripComments(src).match(/^\s*preview_part\s*=\s*"([^"]+)"\s*;/m);
    return m ? m[1] : null;
}

// --- presets (Customizer parameter sets in src/<model>/<model>.json) ---

const DEFAULT_SET = 'design default values'; // set that OpenSCAD creates automatically – not built as a preset

function readPresetFile(file) {
    try {
        return JSON.parse(readFileSync(file, 'utf8')).parameterSets ?? {};
    } catch {
        return {};
    }
}

const slugify = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

// One variant = one built set of files. Without presets there is a single variant with base = model name,
// with presets there is one variant per preset with base = <model>-<preset-slug>.
function listVariants(name) {
    const presets = Object.keys(readPresetFile(join(srcDir, name, `${name}.json`))).filter((p) => p !== DEFAULT_SET);
    if (!presets.length) return [{ preset: null, base: name }];
    const seen = new Set();
    return presets.map((preset) => {
        const slug = slugify(preset);
        if (!slug || seen.has(slug)) throw new Error(`preset name "${preset}" gives an empty or duplicate file name "${slug}"`);
        seen.add(slug);
        return { preset, base: `${name}-${slug}` };
    });
}

// True when every expected output of the variant exists in `dir`
function variantComplete(dir, v, version, parts, previewPart) {
    return parts.every((p) => existsSync(join(dir, `${v.base}-${p}.stl`)))
        && (!previewPart || existsSync(join(dir, 'images', `${v.base}-preview.png`)));
}

// Renders the assembled / coloured preview PNG directly from the .scad (preview mode keeps color())
function renderPreview(openscad, file, presetArgs, previewPart, pngFile) {
    mkdirSync(dirname(pngFile), { recursive: true });
    const r = spawnSync(openscad, [
        '-o', pngFile, ...presetArgs, '-D', `part="${previewPart}"`, '--preview', '--imgsize=900,700',
        '--autocenter', '--viewall', '--projection=p', '--camera=0,0,0,55,0,25,500', '--colorscheme=Tomorrow', file,
    ], { encoding: 'utf8' });
    if (r.status !== 0 || !existsSync(pngFile)) {
        console.warn(`  ! preview ${basename(pngFile)} failed: ${(r.stderr || String(r.error || '')).trim().split('\n').pop()}`);
        return false;
    }
    return true;
}

function buildModel(openscad, name) {
    const file = join(srcDir, name, `${name}.scad`);
    const jsonFile = join(srcDir, name, `${name}.json`);
    const src = readFileSync(file, 'utf8');
    const parts = readParts(src);
    const version = readVersion(src);
    const previewPart = readPreviewPart(src);
    if (!parts || parts.length === 0) {
        console.warn(`! ${name}: missing parts = [...] array, skipping`);
        return;
    }
    if (!version) {
        console.error(`! ${name}: missing model_version = "x.y.z"; – skipping`);
        failed++;
        return;
    }
    if (onlyPart && !parts.includes(onlyPart)) {
        console.error(`! ${name}: part "${onlyPart}" is not in the list (${parts.join(', ')})`);
        failed++;
        return;
    }
    let variants;
    try {
        variants = listVariants(name);
    } catch (e) {
        console.error(`! ${name}: ${e.message}`);
        failed++;
        return;
    }
    if (onlyPreset) {
        variants = variants.filter((v) => v.preset === onlyPreset);
        if (!variants.length) {
            console.error(`! ${name}: preset "${onlyPreset}" not found in ${name}.json`);
            failed++;
            return;
        }
    }
    const outDir = join(outRoot, name, `v${version}`);
    // Safety guard: never silently overwrite a version that was built from a DIFFERENT source.
    // The snapshot <model>-v<version>.scad in the version folder is compared with the current source.
    // (Only the .scad counts – adding or editing presets in the .json never needs a version bump.)
    const snapshot = join(outDir, `${name}-v${version}.scad`);
    const snapshotJson = join(outDir, `${name}-v${version}.json`);
    const hasSnapshot = existsSync(snapshot);
    const sameSource = hasSnapshot && normText(readFileSync(snapshot, 'utf8')) === normText(src);
    if (hasSnapshot && !sameSource && !force) {
        console.error(
            `! ${name}: version ${version} was already built from a different source (${snapshot}).\n`
            + '  Bump model_version (and add a changelog entry) to keep the old version, or run with --force to overwrite it.',
        );
        failed++;
        return;
    }
    // Which variants need building. OpenSCAD's STL output is not byte-stable between runs, so a variant is rebuilt
    // only when its files are missing, its preset parameters changed, or the source changed (rebuilding would
    // otherwise only create noise in git). An explicit part / --preset= always builds what was asked for.
    const incremental = sameSource && !force;
    const oldSets = incremental ? readPresetFile(snapshotJson) : {};
    const newSets = readPresetFile(jsonFile);
    const isStale = (v) => !incremental
        || !variantComplete(outDir, v, version, parts, previewPart)
        || (v.preset !== null && JSON.stringify(oldSets[v.preset]) !== JSON.stringify(newSets[v.preset]));
    const todo = onlyPart || onlyPreset ? variants : variants.filter(isStale);
    if (!todo.length) {
        console.log(`${name} v${version}: up to date (source and presets unchanged) – skipped, use --force to rebuild`);
        return;
    }
    // full build = clean temporary folder that replaces the version folder on success;
    // incremental / single part / single preset = written in place into the existing version folder
    const inPlace = Boolean(onlyPart || onlyPreset || incremental);
    const workDir = inPlace ? outDir : `${outDir}.building`;
    if (!inPlace) rmSync(workDir, { recursive: true, force: true });
    mkdirSync(workDir, { recursive: true });

    let modelFailed = false;
    for (const v of todo) {
        const presetArgs = v.preset ? ['-p', jsonFile, '-P', v.preset] : [];
        let variantFailed = false;
        for (const part of parts.filter((p) => !onlyPart || p === onlyPart)) {
            const out = join(workDir, `${v.base}-${part}.stl`);
            const t0 = Date.now();
            process.stdout.write(`${v.base} v${version} / ${part} ... `);
            const r = spawnSync(openscad, ['-o', out, ...presetArgs, '-D', `part="${part}"`, file], { encoding: 'utf8' });
            const sec = ((Date.now() - t0) / 1000).toFixed(1);
            if (r.status !== 0 || !existsSync(out)) {
                failed++;
                variantFailed = true;
                console.log(`ERROR (${sec} s)`);
                console.error((r.stderr || String(r.error || '')).trim());
            } else {
                built++;
                console.log(`OK (${sec} s) -> ${join(outDir, basename(out))}`);
            }
        }
        if (onlyPart) continue; // a single part does not refresh preview / source snapshot
        if (variantFailed) {
            modelFailed = true;
            continue;
        }
        if (previewPart) {
            process.stdout.write(`${v.base} v${version} / ${previewPart} (preview) ... `);
            console.log(renderPreview(openscad, file, presetArgs, previewPart, join(workDir, 'images', `${v.base}-preview.png`)) ? 'OK' : 'failed');
        }
    }
    if (onlyPart) return;

    if (modelFailed) {
        if (!inPlace) rmSync(workDir, { recursive: true, force: true });
        console.error(`! ${name}: build failed${inPlace ? ', the source snapshot was not refreshed' : `, the existing v${version} folder was left untouched`}.`);
        return;
    }
    // snapshot of the source (+ presets), then swap the finished folder in
    copyFileSync(file, join(workDir, `${name}-v${version}.scad`));
    if (existsSync(jsonFile)) copyFileSync(jsonFile, join(workDir, `${name}-v${version}.json`));
    if (!inPlace) {
        rmSync(outDir, { recursive: true, force: true });
        renameSync(workDir, outDir);
    }
    console.log(`  + ${name}-v${version}.scad${existsSync(jsonFile) ? ', .json' : ''}, images/`);
}

// --- main README.md (generated) ---

function firstParagraph(mdFile) {
    if (!existsSync(mdFile)) return '';
    const lines = readFileSync(mdFile, 'utf8').split(/\r?\n/);
    const i = lines.findIndex((l) => /^#\s/.test(l));
    const out = [];
    for (const l of lines.slice(i + 1)) {
        if (!l.trim()) {
            if (out.length) break;
            continue;
        }
        if (/^#/.test(l)) break;
        out.push(l.trim());
    }
    return out.join(' ');
}

function generateReadme() {
    const rel = (...p) => p.join('/');
    const lines = [
        `# ${packageName()}`,
        '',
        '<!-- GENERATED by scripts/build-stl.mjs – do not edit. Edit src/<model>/README.md and the changelog in the .scad header instead. -->',
        '',
        'Parametric OpenSCAD models for 3D printing. Every model lives in `src/<model>/` and is built into STL files and a source snapshot per version under `dist/<model>/`.',
        '',
    ];
    const names = listModels();
    if (names.length === 0) lines.push('_No models yet. Add one as `src/<model>/<model>.scad`, then run `npm run build`._');
    else lines.push('| Model | Description | Version | Parts |', '|---|---|---|---|');
    const sections = [];
    for (const name of names) {
        const src = readFileSync(join(srcDir, name, `${name}.scad`), 'utf8');
        const version = readVersion(src) ?? '?';
        const parts = readParts(src) ?? [];
        const changelog = readChangelog(src);
        const desc = firstParagraph(join(srcDir, name, 'README.md'));
        const isBuilt = existsSync(join(outRoot, name, `v${version}`));
        const releases = existsSync(join(outRoot, name))
            ? readdirSync(join(outRoot, name))
                .filter((d) => /^v\d+\.\d+\.\d+$/.test(d))
                .map((d) => d.slice(1))
                .sort(compareVersions)
                .reverse()
            : [];
        const hasDoc = existsSync(join(srcDir, name, 'README.md'));
                const imgRel = rel('dist', name, `v${version}`, 'images');
        // assembled preview of every variant/preset (only models with `preview_part` have images)
        const variants = (() => {
            try {
                return listVariants(name);
            } catch {
                return [{ preset: null, base: name }];
            }
        })();
        const imgDir = join(outRoot, name, `v${version}`, 'images');
        const images = [];
        for (const v of variants) {
            if (existsSync(join(imgDir, `${v.base}-preview.png`))) images.push(`${v.base}-preview`);
        }

        lines.push(
            `| [${name}](#${name}) | ${desc || '–'} | ${version}${isBuilt ? '' : ' *(not built yet)*'} | ${parts.map((p) => `\`${p}\``).join(', ')} |`,
        );

        const s = [`## ${name}`, ''];
        if (desc) s.push(desc, '');
        if (images.length)
            s.push(
                images
                    .map((img) => `<img src="${imgRel}/${img}.png" alt="${img.replace(`${name}-`, `${name} `)}" width="${images.length > 2 ? 230 : 340}">`)
                    .join(' '),
                '',
            );
        s.push(`- Source: [\`${rel('src', name, `${name}.scad`)}\`](${rel('src', name, `${name}.scad`)})`);
        if (hasDoc) s.push(`- Documentation: [\`${rel('src', name, 'README.md')}\`](${rel('src', name, 'README.md')})`);
        s.push(`- Current version: **${version}**${isBuilt ? '' : ' *(not built yet – `npm run build`)*'}`);
        s.push(`- Parts: ${parts.map((p) => `\`${p}\``).join(', ')}`);
        s.push('');
        if (releases.length) {
            s.push('| Version | Download (STL) | Source | Changes |', '|---|---|---|---|');
            for (const v of releases) {
                const dir = rel('dist', name, `v${v}`);
                const entry = changelog.find((e) => e.version === v);
                const stls = readdirSync(join(outRoot, name, `v${v}`)).filter((f) => f.endsWith('.stl')).sort();
                const links = stls.map((z) => `[${z}](${dir}/${z})`).join('<br>');
                s.push(
                    `| ${v} | ${links} | [${name}-v${v}.scad](${dir}/${name}-v${v}.scad) | ${entry ? entry.summary : ''} |`,
                );
            }
            s.push('');
        }
        const pending = changelog.filter((e) => !releases.includes(e.version));
        if (pending.length) {
            s.push('Changes not built yet:', '');
            for (const e of pending) s.push(`- **${e.version}** – ${e.summary}`);
            s.push('');
        }
        sections.push(s.join('\n'));
    }
    lines.push('', ...sections.map((x) => `${x}`));
    // optional hand-written footer (e.g. the license section) appended verbatim
    const footer = join(srcDir, 'README.footer.md');
    if (existsSync(footer)) lines.push('', readFileSync(footer, 'utf8').trim());
    writeFileSync(join(root, 'README.md'), `${lines.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd()}\n`);
    console.log('README.md regenerated');
}

// --- run ---

if (readmeOnly) {
    // npm run build -- --readme : only regenerate README.md (no OpenSCAD needed)
    generateReadme();
    process.exit(0);
}

const models = listModels().filter((name) => !onlyModel || name === onlyModel);

if (models.length === 0 && onlyModel) {
    console.error(`Model "${onlyModel}" not found in ./src/.`);
    process.exit(1);
}
if (models.length === 0) console.log('No model (src/<model>/<model>.scad) found – only the README is regenerated.');

const openscad = models.length ? findOpenScad() : null; // OpenSCAD is only needed when there is something to build
for (const name of models) buildModel(openscad, name);
if (!onlyPart) generateReadme();

console.log(`\nDone: ${built} generated, ${failed} errors.`);
process.exit(failed ? 1 : 0);
