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

function parseArguments(argumentsList) {
  let mode = "--write";
  let productID = "lengyan";
  let modeSeen = false;
  for (let index = 0; index < argumentsList.length; index += 1) {
    const argument = argumentsList[index];
    if (["--check", "--write"].includes(argument) && !modeSeen) {
      mode = argument;
      modeSeen = true;
    } else if (argument === "--product" && argumentsList[index + 1]) {
      productID = argumentsList[index + 1];
      index += 1;
    } else {
      throw new Error(
        "usage: scripts/generate-audio-manifest.mjs [--check|--write] [--product PRODUCT_ID]",
      );
    }
  }
  assert.match(productID, /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/, "invalid product ID");
  return { mode, productID };
}

function exactKeys(value, expected, label) {
  assert.ok(value && typeof value === "object" && !Array.isArray(value), `${label} must be an object`);
  assert.deepEqual(Object.keys(value).sort(), [...expected].sort(), `${label} has unexpected keys`);
}

function repositoryRelativePath(value, label) {
  assert.equal(typeof value, "string", `${label} must be a string`);
  assert.ok(value.length > 0, `${label} must not be empty`);
  assert.equal(value.includes("\\"), false, `${label} must use forward slashes`);
  assert.equal(path.posix.isAbsolute(value), false, `${label} must be repository-relative`);
  const normalized = path.posix.normalize(value);
  assert.ok(normalized !== ".." && !normalized.startsWith("../"), `${label} must stay inside the repository`);
  return normalized;
}

function productRelativePath(productDirectory, value, label) {
  return path.join(productDirectory, repositoryRelativePath(value, label));
}

async function readJSON(filePath) {
  return JSON.parse(await readFile(filePath, "utf8"));
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

function requiredProvider(delivery, kind) {
  const matches = delivery.providers.filter((provider) => provider.kind === kind);
  assert.equal(matches.length, 1, `iOS delivery must define exactly one ${kind} provider`);
  return matches[0];
}

const { mode, productID } = parseArguments(process.argv.slice(2));
const productDirectory = path.join(repositoryRoot, "Products", productID);
const product = await readJSON(path.join(productDirectory, "product.json"));
assert.equal(product.productID, productID, "product manifest ID does not match its directory");
assert.ok(product.manifests?.audio, "product manifest has no audio artifact link");
assert.ok(product.manifests?.audioBuild, "product manifest has no audio build-input link");
assert.ok(product.platforms?.ios?.audioDelivery, "product manifest has no iOS audio delivery link");

const artifactPath = productRelativePath(
  productDirectory,
  product.manifests.audio,
  "product.manifests.audio",
);
const buildInputPath = productRelativePath(
  productDirectory,
  product.manifests.audioBuild,
  "product.manifests.audioBuild",
);
const deliveryPath = productRelativePath(
  productDirectory,
  product.platforms.ios.audioDelivery,
  "product.platforms.ios.audioDelivery",
);
const [artifactManifest, buildInput, delivery] = await Promise.all([
  readJSON(artifactPath),
  readJSON(buildInputPath),
  readJSON(deliveryPath),
]);

exactKeys(
  buildInput,
  [
    "schemaVersion",
    "productID",
    "artifactManifest",
    "deliveryManifest",
    "selectedRenditionID",
    "sourceDirectory",
    "legacyProjection",
  ],
  "audio build input",
);
exactKeys(
  buildInput.legacyProjection,
  [
    "manifest",
    "swiftCatalog",
    "nodeCatalog",
    "checksumCatalog",
    "healthDocument",
    "appleManifestDirectory",
    "mediaIndexes",
  ],
  "audio build input legacy projection",
);
assert.equal(buildInput.schemaVersion, 1, "unsupported audio build-input schemaVersion");
assert.equal(buildInput.productID, productID, "audio build-input productID differs");
assert.equal(buildInput.artifactManifest, product.manifests.audio, "audio build-input artifact link differs");
assert.equal(
  buildInput.deliveryManifest,
  product.platforms.ios.audioDelivery,
  "audio build-input delivery link differs",
);

assert.equal(artifactManifest.schemaVersion, 1, "unsupported audio artifact schemaVersion");
assert.equal(artifactManifest.productID, productID, "audio artifact productID differs");
assert.match(artifactManifest.catalogVersion, /^v[1-9][0-9]*$/, "catalogVersion must look like v1");
assert.ok(
  Array.isArray(artifactManifest.artifacts) && artifactManifest.artifacts.length > 0,
  "audio artifacts must not be empty",
);

assert.equal(delivery.schemaVersion, 1, "unsupported audio delivery schemaVersion");
assert.equal(delivery.productID, productID, "iOS delivery productID differs");
assert.equal(delivery.platform, "ios", "audio generator requires iOS delivery");
assert.equal(delivery.state, "production", "legacy projection requires production iOS delivery");
assert.equal(delivery.artifactManifest, product.manifests.audio, "iOS delivery artifact link differs");
assert.equal(
  delivery.selectedRenditionID,
  buildInput.selectedRenditionID,
  "build-input and iOS selected rendition differ",
);

const odrProvider = requiredProvider(delivery, "apple-on-demand-resources");
const managedProvider = requiredProvider(delivery, "apple-managed-background-assets");
const httpsProvider = requiredProvider(delivery, "https");
assert.equal(odrProvider.tagTemplate, "{legacyTrackID}", "legacy ODR tag template changed");
assert.equal(odrProvider.bundleFileTemplate, "{fileName}", "legacy ODR file template changed");
assert.equal(odrProvider.role, "primary", "legacy ODR must remain a primary provider");
assert.equal(odrProvider.minimumOSMajor, 15, "legacy ODR minimum OS changed");
assert.equal(odrProvider.maximumOSMajor, 25, "legacy ODR maximum OS changed");
assert.equal(managedProvider.role, "primary", "Managed Background Assets must remain primary");
assert.equal(managedProvider.minimumOSMajor, 26, "Managed Background Assets minimum OS changed");
assert.equal(httpsProvider.artifactKeySource, "rendition", "HTTPS provider must use rendition artifact keys");
assert.equal(httpsProvider.role, "fallback", "legacy HTTPS route must remain a fallback");
assert.equal(httpsProvider.minimumOSMajor, 15, "legacy HTTPS fallback minimum OS changed");
assert.equal(
  httpsProvider.baseURLConfigurationKey,
  "LengyanCDNAudioFallbackBaseURL",
  "legacy HTTPS base-URL key changed",
);
assert.equal(
  httpsProvider.enabledConfigurationKey,
  "LengyanCDNAudioFallbackEnabled",
  "legacy HTTPS enabled key changed",
);
assert.equal(
  httpsProvider.stallTimeoutConfigurationKey,
  "LengyanCDNAudioFallbackStallTimeoutSeconds",
  "legacy HTTPS stall-timeout key changed",
);
assert.equal(
  httpsProvider.activation,
  "user-playback-after-primary-failure-or-stall",
  "legacy HTTPS activation policy changed",
);
assert.equal(httpsProvider.byteRangeSupport, "unsupported", "legacy HTTPS range evidence changed");
assert.equal(httpsProvider.prefetchAllowed, false, "legacy HTTPS fallback must not prefetch");

const assetPackMarker = "{legacyTrackID}";
assert.ok(
  managedProvider.assetPackIDTemplate.endsWith(assetPackMarker),
  "managed asset pack template must end with {legacyTrackID}",
);
const assetPackIDPrefix = managedProvider.assetPackIDTemplate.slice(0, -assetPackMarker.length);
assert.match(assetPackIDPrefix, /^[A-Za-z0-9.-]+\.$/, "managed asset pack prefix is invalid");

const relativePathMarker = "/{fileName}";
assert.ok(
  managedProvider.relativePathTemplate.endsWith(relativePathMarker),
  "managed relative path template must end with /{fileName}",
);
const appleRelativeDirectory = managedProvider.relativePathTemplate.slice(
  0,
  -relativePathMarker.length,
);
assert.match(appleRelativeDirectory, /^[A-Za-z0-9_-]+$/, "managed relative directory is invalid");

const supportedLocales = artifactManifest.supportedLocales;
assert.deepEqual(
  [...supportedLocales].sort(),
  [...product.supportedLocales].sort(),
  "artifact and product locales differ",
);
assert.deepEqual(
  Object.keys(artifactManifest.performers).sort(),
  [...supportedLocales].sort(),
  "performer locales differ",
);
assert.deepEqual(
  Object.keys(buildInput.legacyProjection.mediaIndexes).sort(),
  [...supportedLocales].sort(),
  "media-index locales differ",
);

const sourceDirectory = path.join(
  repositoryRoot,
  repositoryRelativePath(buildInput.sourceDirectory, "sourceDirectory"),
);
const identifiers = new Set();
const hashes = new Set();
const fileNames = new Set();
const selectedTracks = [];
let fileExtension = null;
let cdnPathPrefix = null;

for (const [index, artifact] of artifactManifest.artifacts.entries()) {
  const label = `artifacts[${index}]`;
  assert.match(artifact.legacyTrackID, /^[a-z0-9]+$/, `${label}.legacyTrackID is invalid`);
  assert.equal(identifiers.has(artifact.legacyTrackID), false, `duplicate legacy track ID: ${artifact.legacyTrackID}`);
  identifiers.add(artifact.legacyTrackID);
  assert.deepEqual(Object.keys(artifact.titles).sort(), [...supportedLocales].sort(), `${label} title locales differ`);

  const renditions = artifact.renditions.filter(
    (rendition) => rendition.renditionID === delivery.selectedRenditionID,
  );
  assert.equal(renditions.length, 1, `${label} must have exactly one selected rendition`);
  const rendition = renditions[0];
  assert.match(rendition.sha256, /^[a-f0-9]{64}$/, `${label} SHA-256 is invalid`);
  assert.ok(Number.isSafeInteger(rendition.bytes) && rendition.bytes > 0, `${label} byte count is invalid`);
  assert.equal(hashes.has(rendition.sha256), false, `duplicate audio hash: ${rendition.sha256}`);
  assert.equal(fileNames.has(rendition.fileName), false, `duplicate audio filename: ${rendition.fileName}`);
  hashes.add(rendition.sha256);
  fileNames.add(rendition.fileName);

  const expectedExtension = path.posix.extname(rendition.fileName).slice(1);
  assert.equal(expectedExtension, rendition.fileExtension, `${label} filename extension differs`);
  fileExtension ??= rendition.fileExtension;
  assert.equal(rendition.fileExtension, fileExtension, "legacy projection requires one file extension");

  const keySuffix = `/${artifactManifest.catalogVersion}/${rendition.sha256}/${rendition.fileName}`;
  assert.ok(rendition.artifactKey.endsWith(keySuffix), `${label} artifact key is not immutable`);
  const prefix = rendition.artifactKey.slice(0, -keySuffix.length);
  assert.match(prefix, /^[a-z0-9][a-z0-9/-]*$/, `${label} artifact key prefix is invalid`);
  cdnPathPrefix ??= prefix;
  assert.equal(prefix, cdnPathPrefix, "legacy projection requires one artifact-key prefix");

  const sourcePath = path.join(sourceDirectory, rendition.fileName);
  const sourceStat = await stat(sourcePath);
  assert.equal(sourceStat.isFile(), true, `audio source is not a file: ${sourcePath}`);
  assert.equal(sourceStat.size, rendition.bytes, `audio byte count changed: ${artifact.legacyTrackID}`);
  assert.equal(await sha256(sourcePath), rendition.sha256, `audio SHA-256 changed: ${artifact.legacyTrackID}`);

  selectedTracks.push({ artifact, rendition });
}

const sourceFileNames = (await readdir(sourceDirectory))
  .filter((fileName) => fileName.endsWith(`.${fileExtension}`))
  .sort();
assert.deepEqual(sourceFileNames, [...fileNames].sort(), "audio source directory and artifact manifest differ");

const legacyManifest = {
  schemaVersion: 1,
  catalogVersion: artifactManifest.catalogVersion,
  sourceDirectory: buildInput.sourceDirectory,
  fileExtension,
  cdnPathPrefix,
  apple: {
    assetPackIDPrefix,
    relativeDirectory: appleRelativeDirectory,
    downloadPolicy: managedProvider.downloadPolicy,
    platforms: managedProvider.platforms,
  },
  localizations: Object.fromEntries(
    supportedLocales.map((locale) => [locale, { artist: artifactManifest.performers[locale] }]),
  ),
  tracks: selectedTracks.map(({ artifact, rendition }) => ({
    id: artifact.legacyTrackID,
    sha256: rendition.sha256,
    bytes: rendition.bytes,
    titles: artifact.titles,
  })),
};

const swiftTracks = legacyManifest.tracks.map((track) => (
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

    static let catalogVersion = ${JSON.stringify(legacyManifest.catalogVersion)}
    static let fileExtension = ${JSON.stringify(legacyManifest.fileExtension)}
    static let cdnPathPrefix = ${JSON.stringify(legacyManifest.cdnPathPrefix)}
    static let appleAssetPackIDPrefix = ${JSON.stringify(legacyManifest.apple.assetPackIDPrefix)}
    static let appleRelativeDirectory = ${JSON.stringify(legacyManifest.apple.relativeDirectory)}
    static let nowPlayingArtist = ${JSON.stringify(legacyManifest.localizations["zh-Hant"].artist)}

    static let tracks: [Track] = [
${swiftTracks}
    ]
}
`;

const nodeEntries = legacyManifest.tracks.map((track) => (
  `  [${JSON.stringify(track.id)}, ${JSON.stringify(track.sha256)}, ${swiftInteger(track.bytes)}],`
)).join("\n");
const generatedNodeCatalog = `// Generated by scripts/generate-audio-manifest.mjs. Do not edit.

export const CATALOG_VERSION = ${JSON.stringify(legacyManifest.catalogVersion)};

const entries = [
${nodeEntries}
];

export const AUDIO_ASSETS = Object.freeze(Object.fromEntries(entries.map(
  ([id, sha256, bytes]) => {
    const key = \`${legacyManifest.cdnPathPrefix}/\${CATALOG_VERSION}/\${sha256}/\${id}.${legacyManifest.fileExtension}\`;
    return [
      \`/\${key}\`,
      Object.freeze({ id, sha256, bytes, key }),
    ];
  },
)));
`;

const projection = buildInput.legacyProjection;
const outputPath = (value, label) => path.join(
  repositoryRoot,
  repositoryRelativePath(value, label),
);
const manifestDirectory = outputPath(
  projection.appleManifestDirectory,
  "legacyProjection.appleManifestDirectory",
);
const outputs = new Map([
  [outputPath(projection.manifest, "legacyProjection.manifest"), json(legacyManifest)],
  [outputPath(projection.swiftCatalog, "legacyProjection.swiftCatalog"), generatedSwift],
  [outputPath(projection.nodeCatalog, "legacyProjection.nodeCatalog"), generatedNodeCatalog],
  [
    outputPath(projection.checksumCatalog, "legacyProjection.checksumCatalog"),
    `${legacyManifest.tracks.map((track) => `${track.sha256}  ${track.id}.${legacyManifest.fileExtension}`).join("\n")}\n`,
  ],
  [
    outputPath(projection.healthDocument, "legacyProjection.healthDocument"),
    json({
      service: `${productID}-audio-fallback`,
      status: "ok",
      catalogVersion: legacyManifest.catalogVersion,
      assetCount: legacyManifest.tracks.length,
      storage: "workers-static-assets",
    }),
  ],
]);

for (const locale of supportedLocales) {
  outputs.set(
    outputPath(projection.mediaIndexes[locale], `legacyProjection.mediaIndexes.${locale}`),
    json([{
      name: legacyManifest.localizations[locale].artist,
      extension: legacyManifest.fileExtension,
      files: legacyManifest.tracks.map((track) => track.id),
      names: legacyManifest.tracks.map((track) => track.titles[locale]),
    }]),
  );
}

const expectedAppleManifestNames = new Set();
for (const track of legacyManifest.tracks) {
  const assetPackID = `${legacyManifest.apple.assetPackIDPrefix}${track.id}`;
  const manifestName = `${assetPackID}.json`;
  expectedAppleManifestNames.add(manifestName);
  outputs.set(
    path.join(manifestDirectory, manifestName),
    json({
      assetPackID,
      downloadPolicy: { [legacyManifest.apple.downloadPolicy]: {} },
      fileSelectors: [{
        file: `${legacyManifest.apple.relativeDirectory}/${track.id}.${legacyManifest.fileExtension}`,
      }],
      platforms: legacyManifest.apple.platforms,
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
      fileName.startsWith(legacyManifest.apple.assetPackIDPrefix),
      `refusing to remove an unmanaged Apple manifest: ${fileName}`,
    );
    await unlink(path.join(manifestDirectory, fileName));
  }
} else {
  assert.deepEqual(
    [...actualAppleManifestNames].sort(),
    [...expectedAppleManifestNames].sort(),
    "Apple manifest directory differs from the audio contracts",
  );
}

if (mode === "--write") {
  let changed = staleAppleManifestNames.length;
  for (const [generatedPath, content] of outputs) {
    await mkdir(path.dirname(generatedPath), { recursive: true });
    const current = await readFile(generatedPath, "utf8").catch(() => null);
    if (current !== content) {
      await writeFile(generatedPath, content, "utf8");
      changed += 1;
    }
  }
  console.log(`Generated ${outputs.size} audio compatibility files for ${productID} (${changed} changed).`);
} else {
  const stale = [];
  for (const [generatedPath, expected] of outputs) {
    const actual = await readFile(generatedPath, "utf8").catch(() => null);
    if (actual !== expected) {
      stale.push(path.relative(repositoryRoot, generatedPath));
    }
  }
  if (stale.length > 0) {
    console.error("Generated audio compatibility files are stale:");
    for (const generatedPath of stale) {
      console.error(`  ${generatedPath}`);
    }
    console.error("Run scripts/generate-audio-manifest.mjs --write");
    process.exit(1);
  }
  console.log(
    `Audio artifact, delivery, build input, and ${outputs.size} generated compatibility files are consistent.`,
  );
}
