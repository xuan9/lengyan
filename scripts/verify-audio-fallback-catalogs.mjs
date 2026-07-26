#!/usr/bin/env node

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { readFile, readdir, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import {
  AUDIO_ASSETS,
  CATALOG_VERSION,
} from "../CloudflareAudioFallback/src/catalog.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(scriptDirectory);
const manifestPath = path.join(repositoryRoot, "AudioAssets/audio-manifest.json");
const manifest = JSON.parse(await readFile(manifestPath, "utf8"));
const sourceDirectory = path.join(repositoryRoot, manifest.sourceDirectory);
const run = promisify(execFile);

await run(process.execPath, [
  path.join(scriptDirectory, "generate-audio-manifest.mjs"),
  "--check",
]);

assert.equal(CATALOG_VERSION, manifest.catalogVersion);
assert.equal(Object.keys(AUDIO_ASSETS).length, manifest.tracks.length);

for (const expected of manifest.tracks) {
  const fileName = `${expected.id}.${manifest.fileExtension}`;
  const source = path.join(sourceDirectory, fileName);
  const sourceBytes = (await stat(source)).size;
  const sourceHash = createHash("sha256")
    .update(await readFile(source))
    .digest("hex");
  const edgePath = `/${manifest.cdnPathPrefix}/${manifest.catalogVersion}/${expected.sha256}/${fileName}`;
  const edge = AUDIO_ASSETS[edgePath];

  assert.ok(edge, `Edge catalog missing ${edgePath}`);
  assert.equal(sourceBytes, expected.bytes);
  assert.equal(sourceHash, expected.sha256);
  assert.equal(edge.id, expected.id);
  assert.equal(edge.key, edgePath.slice(1));
  assert.equal(edge.sha256, expected.sha256);
  assert.equal(edge.bytes, expected.bytes);
}

const sourceFiles = (await readdir(sourceDirectory))
  .filter((fileName) => fileName.endsWith(`.${manifest.fileExtension}`))
  .sort();
assert.deepEqual(
  sourceFiles,
  manifest.tracks.map((track) => `${track.id}.${manifest.fileExtension}`).sort(),
);

console.log(`Verified ${manifest.tracks.length} exact artifact-derived, source, and generated catalog mappings.`);
