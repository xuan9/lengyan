#!/usr/bin/env node

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import {
  mkdir,
  readFile,
  readdir,
  stat,
  unlink,
  writeFile,
} from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(scriptDirectory);
const manifestPath = path.join(repositoryRoot, "AudioAssets/audio-manifest.json");
const manifestDirectory = path.join(repositoryRoot, "BackgroundAssets/Manifests");
const supportedLocales = ["zh-Hant", "zh-Hans"];

const mode = process.argv[2] ?? "--write";
if (!["--check", "--write"].includes(mode) || process.argv.length > 3) {
  console.error("usage: scripts/generate-audio-manifest.mjs [--check|--write]");
  process.exit(64);
}

function exactKeys(value, expected, label) {
  assert.ok(value && typeof value === "object" && !Array.isArray(value), `${label} must be an object`);
  assert.deepEqual(Object.keys(value).sort(), [...expected].sort(), `${label} has unexpected keys`);
}

function relativeRepositoryPath(value, label) {
  assert.equal(typeof value, "string", `${label} must be a string`);
  assert.ok(value.length > 0, `${label} must not be empty`);
  assert.equal(path.isAbsolute(value), false, `${label} must be repository-relative`);
  const normalized = path.normalize(value);
  assert.ok(normalized !== ".." && !normalized.startsWith(`..${path.sep}`), `${label} must stay inside the repository`);
  return normalized;
}

async function sha256(filePath) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(filePath)) {
    hash.update(chunk);
  }
  return hash.digest("hex");
}

function swiftInteger(value) {
  return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, "_");
}

function json(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
exactKeys(
  manifest,
  [
    "schemaVersion",
    "catalogVersion",
    "sourceDirectory",
    "fileExtension",
    "cdnPathPrefix",
    "apple",
    "localizations",
    "tracks",
  ],
  "audio manifest",
);
assert.equal(manifest.schemaVersion, 1, "unsupported audio manifest schemaVersion");
assert.match(manifest.catalogVersion, /^v[1-9][0-9]*$/, "catalogVersion must look like v1");
assert.match(manifest.fileExtension, /^[a-z0-9]+$/, "fileExtension is invalid");
assert.match(manifest.cdnPathPrefix, /^[a-z0-9][a-z0-9/-]*$/, "cdnPathPrefix is invalid");

const sourceDirectory = path.join(
  repositoryRoot,
  relativeRepositoryPath(manifest.sourceDirectory, "sourceDirectory"),
);
exactKeys(
  manifest.apple,
  ["assetPackIDPrefix", "relativeDirectory", "downloadPolicy", "platforms"],
  "apple configuration",
);
assert.match(manifest.apple.assetPackIDPrefix, /^[A-Za-z0-9.-]+\.$/, "assetPackIDPrefix is invalid");
assert.match(manifest.apple.relativeDirectory, /^[A-Za-z0-9_-]+$/, "apple.relativeDirectory is invalid");
assert.equal(manifest.apple.downloadPolicy, "onDemand", "only onDemand packs are supported");
assert.deepEqual(manifest.apple.platforms, ["iOS"], "production packs must target iOS");

exactKeys(manifest.localizations, supportedLocales, "localizations");
for (const locale of supportedLocales) {
  exactKeys(manifest.localizations[locale], ["artist"], `localizations.${locale}`);
  assert.ok(manifest.localizations[locale].artist.length > 0, `${locale} artist must not be empty`);
}

assert.ok(Array.isArray(manifest.tracks) && manifest.tracks.length > 0, "tracks must not be empty");
const identifiers = new Set();
const hashes = new Set();
for (const [index, track] of manifest.tracks.entries()) {
  const label = `tracks[${index}]`;
  exactKeys(track, ["id", "sha256", "bytes", "titles"], label);
  assert.match(track.id, /^[a-z0-9]+$/, `${label}.id is invalid`);
  assert.match(track.sha256, /^[a-f0-9]{64}$/, `${label}.sha256 is invalid`);
  assert.ok(Number.isSafeInteger(track.bytes) && track.bytes > 0, `${label}.bytes is invalid`);
  assert.equal(identifiers.has(track.id), false, `duplicate track id: ${track.id}`);
  assert.equal(hashes.has(track.sha256), false, `duplicate track hash: ${track.sha256}`);
  identifiers.add(track.id);
  hashes.add(track.sha256);
  exactKeys(track.titles, supportedLocales, `${label}.titles`);
  for (const locale of supportedLocales) {
    assert.ok(track.titles[locale].length > 0, `${label}.titles.${locale} must not be empty`);
  }

  const sourcePath = path.join(sourceDirectory, `${track.id}.${manifest.fileExtension}`);
  const sourceStat = await stat(sourcePath);
  assert.equal(sourceStat.isFile(), true, `audio source is not a file: ${sourcePath}`);
  assert.equal(sourceStat.size, track.bytes, `audio byte count changed: ${track.id}`);
  assert.equal(await sha256(sourcePath), track.sha256, `audio SHA-256 changed: ${track.id}`);
}

const sourceFileNames = (await readdir(sourceDirectory))
  .filter((fileName) => fileName.endsWith(`.${manifest.fileExtension}`))
  .sort();
const expectedSourceFileNames = manifest.tracks
  .map((track) => `${track.id}.${manifest.fileExtension}`)
  .sort();
assert.deepEqual(sourceFileNames, expectedSourceFileNames, "audio source directory and manifest differ");

const swiftTracks = manifest.tracks.map((track) => (
  `        Track(
            id: ${JSON.stringify(track.id)},
            sha256: ${JSON.stringify(track.sha256)},
            bytes: ${swiftInteger(track.bytes)}
        )`
)).join(",\n");
const generatedSwift = `//
//  AudioManifest.generated.swift
//  Generated by scripts/generate-audio-manifest.mjs. Do not edit.
//

enum GeneratedAudioManifest {
    struct Track: Sendable {
        let id: String
        let sha256: String
        let bytes: Int64
    }

    static let catalogVersion = ${JSON.stringify(manifest.catalogVersion)}
    static let fileExtension = ${JSON.stringify(manifest.fileExtension)}
    static let cdnPathPrefix = ${JSON.stringify(manifest.cdnPathPrefix)}
    static let appleAssetPackIDPrefix = ${JSON.stringify(manifest.apple.assetPackIDPrefix)}
    static let appleRelativeDirectory = ${JSON.stringify(manifest.apple.relativeDirectory)}
    static let nowPlayingArtist = ${JSON.stringify(manifest.localizations["zh-Hant"].artist)}

    static let tracks: [Track] = [
${swiftTracks}
    ]
}
`;

const nodeEntries = manifest.tracks.map((track) => (
  `  [${JSON.stringify(track.id)}, ${JSON.stringify(track.sha256)}, ${swiftInteger(track.bytes)}],`
)).join("\n");
const generatedNodeCatalog = `// Generated by scripts/generate-audio-manifest.mjs. Do not edit.

export const CATALOG_VERSION = ${JSON.stringify(manifest.catalogVersion)};

const entries = [
${nodeEntries}
];

export const AUDIO_ASSETS = Object.freeze(Object.fromEntries(entries.map(
  ([id, sha256, bytes]) => {
    const key = \`${manifest.cdnPathPrefix}/\${CATALOG_VERSION}/\${sha256}/\${id}.${manifest.fileExtension}\`;
    return [
      \`/\${key}\`,
      Object.freeze({ id, sha256, bytes, key }),
    ];
  },
)));
`;

const outputs = new Map([
  [
    path.join(repositoryRoot, "lengyan/Domain/AudioAssets/AudioManifest.generated.swift"),
    generatedSwift,
  ],
  [
    path.join(repositoryRoot, "CloudflareAudioFallback/src/catalog.mjs"),
    generatedNodeCatalog,
  ],
  [
    path.join(repositoryRoot, "BackgroundAssets/audio-source-sha256.txt"),
    `${manifest.tracks.map((track) => `${track.sha256}  ${track.id}.${manifest.fileExtension}`).join("\n")}\n`,
  ],
  [
    path.join(repositoryRoot, "CloudflareAudioFallback/static/lengyan-audio-fallback"),
    json({
      service: "lengyan-audio-fallback",
      status: "ok",
      catalogVersion: manifest.catalogVersion,
      assetCount: manifest.tracks.length,
      storage: "workers-static-assets",
    }),
  ],
]);

for (const locale of supportedLocales) {
  const mediaPath = locale === "zh-Hant"
    ? "lengyan/data/lengyanjing-media.json"
    : "lengyan/data/simplified/lengyanjing-media.json";
  outputs.set(
    path.join(repositoryRoot, mediaPath),
    json([{
      name: manifest.localizations[locale].artist,
      extension: manifest.fileExtension,
      files: manifest.tracks.map((track) => track.id),
      names: manifest.tracks.map((track) => track.titles[locale]),
    }]),
  );
}

const expectedAppleManifestNames = new Set();
for (const track of manifest.tracks) {
  const assetPackID = `${manifest.apple.assetPackIDPrefix}${track.id}`;
  const manifestName = `${assetPackID}.json`;
  expectedAppleManifestNames.add(manifestName);
  outputs.set(
    path.join(manifestDirectory, manifestName),
    json({
      assetPackID,
      downloadPolicy: { [manifest.apple.downloadPolicy]: {} },
      fileSelectors: [{
        file: `${manifest.apple.relativeDirectory}/${track.id}.${manifest.fileExtension}`,
      }],
      platforms: manifest.apple.platforms,
    }),
  );
}

await mkdir(manifestDirectory, { recursive: true });
const actualAppleManifestNames = new Set(
  (await readdir(manifestDirectory)).filter((fileName) => fileName.endsWith(".json")),
);
const staleAppleManifestNames = [...actualAppleManifestNames]
  .filter((fileName) => !expectedAppleManifestNames.has(fileName));

if (mode === "--write") {
  for (const fileName of staleAppleManifestNames) {
    assert.ok(
      fileName.startsWith(manifest.apple.assetPackIDPrefix),
      `refusing to remove an unmanaged Apple manifest: ${fileName}`,
    );
    await unlink(path.join(manifestDirectory, fileName));
  }
} else {
  assert.deepEqual(
    [...actualAppleManifestNames].sort(),
    [...expectedAppleManifestNames].sort(),
    "BackgroundAssets/Manifests differs from the canonical manifest",
  );
}

if (mode === "--write") {
  let changed = staleAppleManifestNames.length;
  for (const [outputPath, content] of outputs) {
    await mkdir(path.dirname(outputPath), { recursive: true });
    const current = await readFile(outputPath, "utf8").catch(() => null);
    if (current !== content) {
      await writeFile(outputPath, content, "utf8");
      changed += 1;
    }
  }
  console.log(`Generated ${outputs.size} audio catalog files (${changed} changed).`);
} else {
  const stale = [];
  for (const [outputPath, expected] of outputs) {
    const actual = await readFile(outputPath, "utf8").catch(() => null);
    if (actual !== expected) {
      stale.push(path.relative(repositoryRoot, outputPath));
    }
  }
  if (stale.length > 0) {
    console.error("Generated audio catalog files are stale:");
    for (const outputPath of stale) {
      console.error(`  ${outputPath}`);
    }
    console.error("Run scripts/generate-audio-manifest.mjs --write");
    process.exit(1);
  }
  console.log(`Audio manifest and ${outputs.size} generated files are consistent.`);
}
