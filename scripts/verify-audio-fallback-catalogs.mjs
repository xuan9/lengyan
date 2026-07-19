#!/usr/bin/env node

import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

import { AUDIO_ASSETS } from "../CloudflareAudioFallback/src/catalog.mjs";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(scriptDirectory);
const checksumPath = path.join(repositoryRoot, "BackgroundAssets/audio-source-sha256.txt");
const swiftCatalogPath = path.join(
  repositoryRoot,
  "lengyan/Domain/AudioAssets/AudioAssetCatalog.swift",
);
const sourceDirectory = path.join(repositoryRoot, "lengyan/屏東能淨協會讀誦");

const checksumLines = (await readFile(checksumPath, "utf8"))
  .trim()
  .split(/\r?\n/)
  .map((line) => {
    const match = /^([a-f0-9]{64})\s+([a-z0-9]+)\.m4a$/.exec(line.trim());
    assert.ok(match, `Invalid checksum line: ${line}`);
    return { id: match[2], sha256: match[1] };
  });
assert.equal(checksumLines.length, 11);

const swiftSource = await readFile(swiftCatalogPath, "utf8");
const swiftEntries = new Map();
for (const match of swiftSource.matchAll(
  /"([a-z0-9]+)":\s*\("([a-f0-9]{64})",\s*([0-9_]+)\)/g,
)) {
  swiftEntries.set(match[1], {
    sha256: match[2],
    bytes: Number(match[3].replaceAll("_", "")),
  });
}
assert.equal(swiftEntries.size, 11, "Swift CDN catalog must contain 11 entries");
assert.equal(Object.keys(AUDIO_ASSETS).length, 11, "Edge catalog must contain 11 entries");

for (const expected of checksumLines) {
  const source = path.join(sourceDirectory, `${expected.id}.m4a`);
  const sourceBytes = (await stat(source)).size;
  const swift = swiftEntries.get(expected.id);
  const edgePath = `/audio/v1/${expected.sha256}/${expected.id}.m4a`;
  const edge = AUDIO_ASSETS[edgePath];

  assert.ok(swift, `Swift catalog missing ${expected.id}`);
  assert.ok(edge, `Edge catalog missing ${edgePath}`);
  assert.deepEqual(swift, { sha256: expected.sha256, bytes: sourceBytes });
  assert.equal(edge.id, expected.id);
  assert.equal(edge.key, edgePath.slice(1));
  assert.equal(edge.sha256, expected.sha256);
  assert.equal(edge.bytes, sourceBytes);
}

console.log("Verified 11 exact source, checksum, Swift and static-asset catalog mappings.");
