// Builds STL files for every part of every model in ./src/<model>/<model>.scad, packs them into a zip,
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
// Output (generated, keep it – older versions stay untouched when you bump model_version):
//     dist/<model>/v<version>/
//         <model>-<part>.stl          one STL per part
//         <model>-v<version>.zip      all STL files in one zip
//         <model>-v<version>.scad     snapshot of the source
//         images/<model>-<part>.png   preview of every part, rendered from the STL
//
// Usage:
//     npm run build                      # all models -> dist/<model>/v<model_version>/
//     npm run build -- <model>           # one model
//     npm run build -- <model> <part>    # one part only (STL + image; no zip, source snapshot or README refresh)
//     add --force to overwrite a version folder that was built from a different source
// Safety guard: if dist/<model>/v<version>/ already holds a source snapshot that differs from the current .scad,
// the build is refused (bump model_version instead, or pass --force). Rebuilding unchanged source is always allowed.
// A full model build is made in a temporary folder that replaces the version folder only when every part succeeded.
// The main README.md is regenerated at the end of every full build. The OpenSCAD path can be overridden with the
// OPENSCAD environment variable.

import { spawnSync } from 'node:child_process';
import {
    copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { crc32, deflateRawSync } from 'node:zlib';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(root, 'src');
const outRoot = join(root, 'dist');

const args = process.argv.slice(2);
const force = args.includes('--force');
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
    if (!existsSync(srcDir)) {
        console.error(`Source directory not found: ${srcDir}`);
        process.exit(1);
    }
    return readdirSync(srcDir)
        .filter((d) => statSync(join(srcDir, d)).isDirectory() && existsSync(join(srcDir, d, `${d}.scad`)))
        .sort();
}

// --- minimal zip writer (stored in memory, deflate, no dependencies) ---

function makeZip(entries) {
    const now = new Date();
    const dosTime = (now.getHours() << 11) | (now.getMinutes() << 5) | (now.getSeconds() >> 1);
    const dosDate = ((now.getFullYear() - 1980) << 9) | ((now.getMonth() + 1) << 5) | now.getDate();
    const chunks = [];
    const central = [];
    let offset = 0;
    for (const { name, data } of entries) {
        const nameBuf = Buffer.from(name, 'utf8');
        const packed = deflateRawSync(data);
        const crc = crc32(data);
        const local = Buffer.alloc(30);
        local.writeUInt32LE(0x04034b50, 0);
        local.writeUInt16LE(20, 4);
        local.writeUInt16LE(0x0800, 6); // UTF-8 names
        local.writeUInt16LE(8, 8); // deflate
        local.writeUInt16LE(dosTime, 10);
        local.writeUInt16LE(dosDate, 12);
        local.writeUInt32LE(crc, 14);
        local.writeUInt32LE(packed.length, 18);
        local.writeUInt32LE(data.length, 22);
        local.writeUInt16LE(nameBuf.length, 26);
        chunks.push(local, nameBuf, packed);

        const cd = Buffer.alloc(46);
        cd.writeUInt32LE(0x02014b50, 0);
        cd.writeUInt16LE(20, 4);
        cd.writeUInt16LE(20, 6);
        cd.writeUInt16LE(0x0800, 8);
        cd.writeUInt16LE(8, 10);
        cd.writeUInt16LE(dosTime, 12);
        cd.writeUInt16LE(dosDate, 14);
        cd.writeUInt32LE(crc, 16);
        cd.writeUInt32LE(packed.length, 20);
        cd.writeUInt32LE(data.length, 24);
        cd.writeUInt16LE(nameBuf.length, 28);
        cd.writeUInt32LE(offset, 42);
        central.push(cd, nameBuf);
        offset += local.length + nameBuf.length + packed.length;
    }
    const cdBuf = Buffer.concat(central);
    const end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0);
    end.writeUInt16LE(entries.length, 8);
    end.writeUInt16LE(entries.length, 10);
    end.writeUInt32LE(cdBuf.length, 12);
    end.writeUInt32LE(offset, 16);
    return Buffer.concat([...chunks, cdBuf, end]);
}

// --- images ---

// Renders a PNG of a built STL (import() of the STL, so it is fast and always matches the file in the zip).
// Images go to src/<model>/images/<model>-<part>.png and are refreshed on every build. A failure only warns.
function renderImage(openscad, stlFile, pngFile) {
    mkdirSync(dirname(pngFile), { recursive: true });
    const tmp = join(tmpdir(), `scad-preview-${process.pid}.scad`);
    writeFileSync(tmp, `import("${stlFile.replace(/\\/g, '/')}");\n`);
    const r = spawnSync(openscad, [
        '-o', pngFile, '--imgsize=900,700', '--autocenter', '--viewall', '--projection=p',
        '--camera=0,0,0,55,0,25,500', '--colorscheme=Tomorrow', tmp,
    ], { encoding: 'utf8' });
    rmSync(tmp, { force: true });
    if (r.status !== 0 || !existsSync(pngFile)) {
        console.warn(`  ! image ${basename(pngFile)} failed: ${(r.stderr || String(r.error || '')).trim().split('\n').pop()}`);
        return false;
    }
    return true;
}

// --- building ---

let failed = 0;
let built = 0;

function buildModel(openscad, name) {
    const file = join(srcDir, name, `${name}.scad`);
    const src = readFileSync(file, 'utf8');
    const parts = readParts(src);
    const version = readVersion(src);
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
    const outDir = join(outRoot, name, `v${version}`);
    // Safety guard: never silently overwrite a version that was built from a DIFFERENT source.
    // The snapshot <model>-v<version>.scad in the version folder is compared with the current source.
    const snapshot = join(outDir, `${name}-v${version}.scad`);
    if (existsSync(snapshot) && !force) {
        const norm = (t) => t.replace(/\r\n/g, '\n');
        if (norm(readFileSync(snapshot, 'utf8')) !== norm(src)) {
            console.error(
                `! ${name}: version ${version} was already built from a different source (${snapshot}).\n`
                + '  Bump model_version (and add a changelog entry) to keep the old version, or run with --force to overwrite it.',
            );
            failed++;
            return;
        }
    }
    // full build = clean temporary folder that replaces the version folder on success; one part = written in place
    const workDir = onlyPart ? outDir : `${outDir}.building`;
    if (!onlyPart) rmSync(workDir, { recursive: true, force: true });
    mkdirSync(workDir, { recursive: true });

    let modelFailed = false;
    for (const part of parts.filter((p) => !onlyPart || p === onlyPart)) {
        const out = join(workDir, `${name}-${part}.stl`);
        const t0 = Date.now();
        process.stdout.write(`${name} v${version} / ${part} ... `);
        const r = spawnSync(openscad, ['-o', out, '-D', `part="${part}"`, file], { encoding: 'utf8' });
        const sec = ((Date.now() - t0) / 1000).toFixed(1);
        if (r.status !== 0 || !existsSync(out)) {
            failed++;
            modelFailed = true;
            console.log(`ERROR (${sec} s)`);
            console.error((r.stderr || String(r.error || '')).trim());
        } else {
            built++;
            console.log(`OK (${sec} s) -> ${join(outDir, basename(out))}`);
            renderImage(openscad, out, join(workDir, 'images', `${name}-${part}.png`));
        }
    }
    if (onlyPart) return; // a single part does not refresh zip / source snapshot

    if (modelFailed) {
        rmSync(workDir, { recursive: true, force: true });
        console.error(`! ${name}: build failed, the existing v${version} folder was left untouched.`);
        return;
    }
    // zip of all STL files + snapshot of the source, then swap the finished folder in
    const stls = parts.map((p) => `${name}-${p}.stl`);
    const zipName = `${name}-v${version}.zip`;
    writeFileSync(
        join(workDir, zipName),
        makeZip(stls.map((n) => ({ name: n, data: readFileSync(join(workDir, n)) }))),
    );
    copyFileSync(file, join(workDir, `${name}-v${version}.scad`));
    rmSync(outDir, { recursive: true, force: true });
    renameSync(workDir, outDir);
    console.log(`  + ${zipName}, ${name}-v${version}.scad, images/`);
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
        '# scad',
        '',
        '<!-- GENERATED by scripts/build-stl.mjs – do not edit. Edit src/<model>/README.md and the changelog in the .scad header instead. -->',
        '',
        'Parametric OpenSCAD models for 3D printing. Every model lives in `src/<model>/` and is built into STL files, a zip and a source snapshot per version under `dist/<model>/`.',
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
        // images of the parts of the current version (<model>-<part>.png, in the order of `parts`)
        const imgRel = rel('dist', name, `v${version}`, 'images');
        const images = parts.filter((p) => existsSync(join(outRoot, name, `v${version}`, 'images', `${name}-${p}.png`)));

        lines.push(
            `| [${name}](#${name}) | ${desc || '–'} | ${version}${isBuilt ? '' : ' *(not built yet)*'} | ${parts.map((p) => `\`${p}\``).join(', ')} |`,
        );

        const s = [`## ${name}`, ''];
        if (desc) s.push(desc, '');
        if (images.length)
            s.push(
                images
                    .map((p) => `<img src="${imgRel}/${name}-${p}.png" alt="${name} ${p}" width="${images.length > 2 ? 230 : 340}">`)
                    .join(' '),
                '',
            );
        s.push(`- Source: [\`${rel('src', name, `${name}.scad`)}\`](${rel('src', name, `${name}.scad`)})`);
        if (hasDoc) s.push(`- Documentation: [\`${rel('src', name, 'README.md')}\`](${rel('src', name, 'README.md')})`);
        s.push(`- Current version: **${version}**${isBuilt ? '' : ' *(not built yet – `npm run build`)*'}`);
        s.push(`- Parts: ${parts.map((p) => `\`${p}\``).join(', ')}`);
        s.push('');
        if (releases.length) {
            s.push('| Version | Download (zip of all STL) | Source | Changes |', '|---|---|---|---|');
            for (const v of releases) {
                const dir = rel('dist', name, `v${v}`);
                const entry = changelog.find((e) => e.version === v);
                s.push(
                    `| ${v} | [${name}-v${v}.zip](${dir}/${name}-v${v}.zip) | [${name}-v${v}.scad](${dir}/${name}-v${v}.scad) | ${entry ? entry.summary : ''} |`,
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
    writeFileSync(join(root, 'README.md'), `${lines.join('\n').replace(/\n{3,}/g, '\n\n').trimEnd()}\n`);
    console.log('README.md regenerated');
}

// --- run ---

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
