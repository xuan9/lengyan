import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { AUDIO_ASSETS, CATALOG_VERSION } from "../src/catalog.mjs";

const MAXIMUM_STATIC_ASSET_BYTES = 25 * 1024 * 1024;
const manifest = JSON.parse(
  await readFile(new URL("../../AudioAssets/audio-manifest.json", import.meta.url), "utf8"),
);

test("catalog exposes every artifact-derived immutable content-addressed asset", () => {
  assert.equal(CATALOG_VERSION, manifest.catalogVersion);
  assert.equal(Object.keys(AUDIO_ASSETS).length, manifest.tracks.length);

  const identifiers = new Set();
  const hashes = new Set();
  for (const [assetPath, asset] of Object.entries(AUDIO_ASSETS)) {
    assert.equal(
      assetPath,
      `/${manifest.cdnPathPrefix}/${manifest.catalogVersion}/${asset.sha256}/${asset.id}.${manifest.fileExtension}`,
    );
    assert.equal(asset.key, assetPath.slice(1));
    assert.ok(asset.bytes > 0);
    assert.ok(asset.bytes <= MAXIMUM_STATIC_ASSET_BYTES);
    identifiers.add(asset.id);
    hashes.add(asset.sha256);
  }

  assert.equal(identifiers.size, manifest.tracks.length);
  assert.equal(hashes.size, manifest.tracks.length);
});

test("deployment is assets-only with no executable Worker or R2 binding", async () => {
  const configuration = JSON.parse(
    await readFile(new URL("../wrangler.jsonc", import.meta.url), "utf8"),
  );

  assert.equal(configuration.main, undefined);
  assert.equal(configuration.r2_buckets, undefined);
  assert.equal(configuration.assets.run_worker_first, false);
  assert.equal(configuration.assets.not_found_handling, "none");
  assert.equal(configuration.workers_dev, true);
  assert.equal(configuration.preview_urls, false);
});

test("static health contract declares the asset backend", async () => {
  const health = JSON.parse(
    await readFile(new URL("../static/lengyan-audio-fallback", import.meta.url), "utf8"),
  );

  assert.deepEqual(health, {
    service: "lengyan-audio-fallback",
    status: "ok",
    catalogVersion: manifest.catalogVersion,
    assetCount: manifest.tracks.length,
    storage: "workers-static-assets",
  });
});
