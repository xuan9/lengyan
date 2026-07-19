import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { AUDIO_ASSETS, CATALOG_VERSION } from "../src/catalog.mjs";

const MAXIMUM_STATIC_ASSET_BYTES = 25 * 1024 * 1024;

test("catalog exposes exactly 11 immutable content-addressed assets", () => {
  assert.equal(CATALOG_VERSION, "v1");
  assert.equal(Object.keys(AUDIO_ASSETS).length, 11);

  const identifiers = new Set();
  const hashes = new Set();
  for (const [assetPath, asset] of Object.entries(AUDIO_ASSETS)) {
    assert.match(
      assetPath,
      new RegExp(`^/audio/v1/${asset.sha256}/${asset.id}\\.m4a$`),
    );
    assert.equal(asset.key, assetPath.slice(1));
    assert.ok(asset.bytes > 0);
    assert.ok(asset.bytes <= MAXIMUM_STATIC_ASSET_BYTES);
    identifiers.add(asset.id);
    hashes.add(asset.sha256);
  }

  assert.equal(identifiers.size, 11);
  assert.equal(hashes.size, 11);
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
    catalogVersion: "v1",
    assetCount: 11,
    storage: "workers-static-assets",
  });
});
