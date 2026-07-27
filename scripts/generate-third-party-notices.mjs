#!/usr/bin/env node

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryRoot = path.dirname(scriptDirectory);
const manifestRelativePath = "ThirdParty/runtime-notices.json";
const outputRelativePaths = Object.freeze({
  audit: "ThirdParty/runtime-inventory.generated.json",
  android: "android/libraries/ui/src/main/assets/third-party-notices.json",
  ios: "lengyan/Resources/third-party-notices.json",
});

function parseMode(argumentsList) {
  if (argumentsList.length === 0) return "--write";
  assert.deepEqual(
    argumentsList,
    [argumentsList[0]],
    "usage: scripts/generate-third-party-notices.mjs [--check|--write]",
  );
  assert.ok(
    ["--check", "--write"].includes(argumentsList[0]),
    "usage: scripts/generate-third-party-notices.mjs [--check|--write]",
  );
  return argumentsList[0];
}

function exactKeys(value, expected, label) {
  assert.ok(value && typeof value === "object" && !Array.isArray(value), `${label} must be an object`);
  assert.deepEqual(Object.keys(value).sort(), [...expected].sort(), `${label} has unexpected keys`);
}

function repositoryPath(relativePath, label) {
  assert.equal(typeof relativePath, "string", `${label} must be a string`);
  assert.ok(relativePath.length > 0, `${label} must not be empty`);
  assert.equal(relativePath.includes("\\"), false, `${label} must use forward slashes`);
  assert.equal(path.posix.isAbsolute(relativePath), false, `${label} must be repository-relative`);
  const normalized = path.posix.normalize(relativePath);
  assert.ok(normalized !== ".." && !normalized.startsWith("../"), `${label} must stay in the repository`);
  return path.join(repositoryRoot, normalized);
}

async function readJSON(relativePath) {
  return JSON.parse(await readFile(repositoryPath(relativePath, relativePath), "utf8"));
}

function serializedJSON(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function uniqueSorted(values) {
  return [...new Set(values)].sort();
}

function compareCodePoints(left, right) {
  if (left < right) return -1;
  if (left > right) return 1;
  return 0;
}

function compareVersions(left, right) {
  const leftParts = left.split(".");
  const rightParts = right.split(".");
  const numeric = (parts) => parts.every((part) => /^\d+$/.test(part));
  if (numeric(leftParts) && numeric(rightParts)) {
    const sharedLength = Math.min(leftParts.length, rightParts.length);
    for (let index = 0; index < sharedLength; index += 1) {
      const leftNumber = BigInt(leftParts[index]);
      const rightNumber = BigInt(rightParts[index]);
      if (leftNumber < rightNumber) return -1;
      if (leftNumber > rightNumber) return 1;
    }
    if (leftParts.length !== rightParts.length) return leftParts.length - rightParts.length;
  }
  return compareCodePoints(left, right);
}

function assertCanonicalHTTPS(value, label) {
  assert.equal(typeof value, "string", `${label} must be a string`);
  const url = new URL(value);
  assert.equal(url.protocol, "https:", `${label} must use HTTPS`);
  assert.ok(url.hostname.length > 0, `${label} must include a host`);
  assert.equal(url.username, "", `${label} must not include credentials`);
  assert.equal(url.password, "", `${label} must not include credentials`);
  assert.equal(url.toString(), value, `${label} must be canonical`);
}

function parseCoordinate(coordinate) {
  const parts = coordinate.split(":");
  assert.equal(parts.length, 3, `invalid locked dependency coordinate: ${coordinate}`);
  assert.ok(parts.every((part) => part.length > 0), `invalid locked dependency coordinate: ${coordinate}`);
  return { group: parts[0], artifact: parts[1], version: parts[2] };
}

async function androidRuntimeCoordinates(lockfilePath, configuration) {
  const raw = await readFile(repositoryPath(lockfilePath, "androidRuntimeLockfile"), "utf8");
  const coordinates = [];
  for (const line of raw.split("\n")) {
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    assert.ok(separator > 0, `invalid Gradle lockfile line: ${line}`);
    const coordinate = line.slice(0, separator);
    const configurations = line.slice(separator + 1).split(",").filter(Boolean);
    if (configurations.includes(configuration)) {
      parseCoordinate(coordinate);
      coordinates.push(coordinate);
    }
  }
  assert.ok(coordinates.length > 0, `no coordinates use ${configuration}`);
  assert.equal(new Set(coordinates).size, coordinates.length, "runtime lockfile has duplicate coordinates");
  return coordinates.sort();
}

async function regularFiles(directoryPath, prefix = "") {
  const files = [];
  const entries = await readdir(directoryPath, { withFileTypes: true });
  entries.sort((left, right) => compareCodePoints(left.name, right.name));
  for (const entry of entries) {
    const relativePath = prefix ? `${prefix}/${entry.name}` : entry.name;
    const absolutePath = path.join(directoryPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...await regularFiles(absolutePath, relativePath));
    } else {
      assert.ok(entry.isFile(), `vendored source contains unsupported entry: ${relativePath}`);
      files.push(relativePath);
    }
  }
  return files;
}

async function vendoredSourceRecord(relativeDirectory) {
  const directoryPath = repositoryPath(relativeDirectory, "iosVendoredSourceDirectory");
  const filePaths = await regularFiles(directoryPath);
  assert.ok(filePaths.length > 0, `${relativeDirectory} has no vendored source files`);
  const aggregate = createHash("sha256");
  const files = [];
  for (const relativePath of filePaths) {
    const content = await readFile(path.join(directoryPath, relativePath));
    aggregate.update(relativePath, "utf8");
    aggregate.update("\0");
    aggregate.update(content);
    aggregate.update("\0");
    files.push({ path: relativePath, sha256: sha256(content) });
  }
  return {
    directory: relativeDirectory,
    sourceSHA256: aggregate.digest("hex"),
    files,
  };
}

const mode = parseMode(process.argv.slice(2));
const manifest = await readJSON(manifestRelativePath);
exactKeys(
  manifest,
  [
    "schemaVersion",
    "androidRuntimeLockfile",
    "androidRuntimeConfiguration",
    "licenses",
    "components",
  ],
  "third-party notice manifest",
);
assert.equal(manifest.schemaVersion, 1, "unsupported third-party notice schemaVersion");
assert.match(manifest.androidRuntimeConfiguration, /^[A-Za-z][A-Za-z0-9]*$/, "invalid runtime configuration");
assert.ok(Array.isArray(manifest.licenses) && manifest.licenses.length > 0, "licenses must not be empty");
assert.ok(Array.isArray(manifest.components) && manifest.components.length > 0, "components must not be empty");

const licenses = [];
const licenseByID = new Map();
for (const [index, license] of manifest.licenses.entries()) {
  exactKeys(license, ["licenseID", "name", "textPath", "canonicalURL"], `licenses[${index}]`);
  assert.match(license.licenseID, /^[A-Za-z0-9.-]+$/, `licenses[${index}] has invalid SPDX ID`);
  assert.ok(!licenseByID.has(license.licenseID), `duplicate license ID: ${license.licenseID}`);
  assertCanonicalHTTPS(license.canonicalURL, `${license.licenseID} URL`);
  const text = await readFile(repositoryPath(license.textPath, `${license.licenseID} textPath`), "utf8");
  assert.ok(text.length > 200, `${license.licenseID} license text is unexpectedly short`);
  assert.ok(text.endsWith("\n"), `${license.licenseID} license text must end with a newline`);
  const record = {
    licenseID: license.licenseID,
    name: license.name,
    canonicalURL: license.canonicalURL,
    textPath: license.textPath,
    textSHA256: sha256(text),
    text,
  };
  licenses.push(record);
  licenseByID.set(record.licenseID, record);
}

const componentKeys = [
  "componentID",
  "displayName",
  "platforms",
  "licenseID",
  "homepage",
  "notice",
  "androidCoordinatePrefixes",
  "iosVendoredSourceDirectory",
  "version",
  "upstreamRevision",
];
const componentByID = new Map();
const androidCoordinatePrefixes = new Set();
for (const [index, component] of manifest.components.entries()) {
  exactKeys(component, componentKeys, `components[${index}]`);
  assert.match(component.componentID, /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/, "invalid component ID");
  assert.ok(!componentByID.has(component.componentID), `duplicate component ID: ${component.componentID}`);
  assert.ok(component.displayName.length > 0, `${component.componentID} displayName is empty`);
  assert.deepEqual(uniqueSorted(component.platforms), component.platforms, `${component.componentID} platforms must be sorted and unique`);
  assert.ok(component.platforms.length > 0, `${component.componentID} has no platform`);
  assert.ok(component.platforms.every((platform) => ["android", "ios"].includes(platform)), `${component.componentID} has an unknown platform`);
  assert.ok(licenseByID.has(component.licenseID), `${component.componentID} uses an unknown license`);
  assertCanonicalHTTPS(component.homepage, `${component.componentID} homepage`);
  assert.equal(typeof component.notice, "string", `${component.componentID} notice must be a string`);
  assert.ok(Array.isArray(component.androidCoordinatePrefixes), `${component.componentID} prefixes must be an array`);
  assert.deepEqual(
    uniqueSorted(component.androidCoordinatePrefixes),
    component.androidCoordinatePrefixes,
    `${component.componentID} prefixes must be sorted and unique`,
  );
  for (const prefix of component.androidCoordinatePrefixes) {
    assert.equal(typeof prefix, "string", `${component.componentID} has a non-string Android prefix`);
    assert.match(prefix, /^[A-Za-z0-9_.-]+(?::[A-Za-z0-9_.-]*:?)?$/, `${component.componentID} has an invalid Android prefix`);
    assert.ok(!androidCoordinatePrefixes.has(prefix), `duplicate Android coordinate prefix: ${prefix}`);
    androidCoordinatePrefixes.add(prefix);
  }

  if (component.platforms.includes("android")) {
    assert.ok(component.androidCoordinatePrefixes.length > 0, `${component.componentID} has no Android prefix`);
    assert.equal(component.iosVendoredSourceDirectory, null, `${component.componentID} mixes Android and iOS inputs`);
    assert.equal(component.version, null, `${component.componentID} Android version comes from the lockfile`);
    assert.equal(component.upstreamRevision, null, `${component.componentID} Android revision comes from the lockfile`);
  } else {
    assert.deepEqual(component.androidCoordinatePrefixes, [], `${component.componentID} has unused Android prefixes`);
  }

  if (component.platforms.includes("ios")) {
    assert.equal(typeof component.iosVendoredSourceDirectory, "string", `${component.componentID} has no vendored source`);
    assert.match(component.version, /^[0-9]+\.[0-9]+\.[0-9]+\+local$/, `${component.componentID} version must record local changes`);
    assert.match(component.upstreamRevision, /^[0-9a-f]{40}$/, `${component.componentID} revision must be a full commit`);
  } else {
    assert.equal(component.iosVendoredSourceDirectory, null, `${component.componentID} has an unused iOS source`);
  }
  componentByID.set(component.componentID, component);
}

const runtimeCoordinates = await androidRuntimeCoordinates(
  manifest.androidRuntimeLockfile,
  manifest.androidRuntimeConfiguration,
);
const androidComponents = new Map();
for (const coordinate of runtimeCoordinates) {
  const matches = manifest.components.filter((component) => (
    component.platforms.includes("android")
      && component.androidCoordinatePrefixes.some((prefix) => coordinate.startsWith(prefix))
  ));
  assert.equal(
    matches.length,
    1,
    `${coordinate} must map to exactly one Android runtime notice; matched ${matches.map((item) => item.componentID).join(", ") || "none"}`,
  );
  const records = androidComponents.get(matches[0].componentID) || [];
  records.push(coordinate);
  androidComponents.set(matches[0].componentID, records);
}

for (const component of manifest.components.filter((item) => item.platforms.includes("android"))) {
  assert.ok(androidComponents.has(component.componentID), `${component.componentID} maps no release runtime coordinate`);
}

const androidAuditComponents = manifest.components
  .filter((component) => component.platforms.includes("android"))
  .map((component) => {
    const coordinates = androidComponents.get(component.componentID).sort();
    return {
      componentID: component.componentID,
      displayName: component.displayName,
      licenseID: component.licenseID,
      homepage: component.homepage,
      notice: component.notice,
      versions: uniqueSorted(coordinates.map((coordinate) => parseCoordinate(coordinate).version))
        .sort(compareVersions),
      coordinates,
    };
  });

const iosAuditComponents = [];
for (const component of manifest.components.filter((item) => item.platforms.includes("ios"))) {
  iosAuditComponents.push({
    componentID: component.componentID,
    displayName: component.displayName,
    licenseID: component.licenseID,
    homepage: component.homepage,
    notice: component.notice,
    version: component.version,
    upstreamRevision: component.upstreamRevision,
    source: await vendoredSourceRecord(component.iosVendoredSourceDirectory),
  });
}

const auditCore = {
  schemaVersion: 1,
  generatedFrom: manifestRelativePath,
  licenses: licenses.map(({ text: _text, ...license }) => license),
  android: {
    lockfile: manifest.androidRuntimeLockfile,
    configuration: manifest.androidRuntimeConfiguration,
    coordinateCount: runtimeCoordinates.length,
    components: androidAuditComponents,
  },
  ios: {
    components: iosAuditComponents,
  },
};
const inventorySHA256 = sha256(serializedJSON(auditCore));
const audit = { ...auditCore, inventorySHA256 };

function platformDocument(platform, components) {
  const licenseIDs = new Set(components.map((component) => component.licenseID));
  return {
    schemaVersion: 1,
    inventorySHA256,
    components: components.map((component) => ({
      componentID: component.componentID,
      displayName: component.displayName,
      versions: component.versions || [component.version],
      moduleCount: component.coordinates?.length || 1,
      licenseID: component.licenseID,
      homepage: component.homepage,
      notice: component.notice,
    })),
    licenses: licenses
      .filter((license) => licenseIDs.has(license.licenseID))
      .map((license) => ({
        licenseID: license.licenseID,
        name: license.name,
        canonicalURL: license.canonicalURL,
        text: license.text,
      })),
    platform,
  };
}

const outputs = new Map([
  [repositoryPath(outputRelativePaths.audit, "audit output"), serializedJSON(audit)],
  [
    repositoryPath(outputRelativePaths.android, "Android output"),
    serializedJSON(platformDocument("android", androidAuditComponents)),
  ],
  [
    repositoryPath(outputRelativePaths.ios, "iOS output"),
    serializedJSON(platformDocument("ios", iosAuditComponents)),
  ],
]);

if (mode === "--write") {
  let changed = 0;
  for (const [outputPath, content] of outputs) {
    await mkdir(path.dirname(outputPath), { recursive: true });
    const current = await readFile(outputPath, "utf8").catch(() => null);
    if (current !== content) {
      await writeFile(outputPath, content, "utf8");
      changed += 1;
    }
  }
  console.log(`Generated ${outputs.size} third-party notice files (${changed} changed).`);
} else {
  const stale = [];
  for (const [outputPath, expected] of outputs) {
    const actual = await readFile(outputPath, "utf8").catch(() => null);
    if (actual !== expected) stale.push(path.relative(repositoryRoot, outputPath));
  }
  if (stale.length > 0) {
    console.error("Generated third-party notice files are stale:");
    for (const outputPath of stale) console.error(`  ${outputPath}`);
    console.error("Run scripts/generate-third-party-notices.mjs --write");
    process.exit(1);
  }
  console.log(
    `Third-party notices cover ${runtimeCoordinates.length} Android runtime coordinates and ${iosAuditComponents.length} iOS vendored component.`,
  );
}
