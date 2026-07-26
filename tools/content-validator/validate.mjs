#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile, readdir, stat } from "node:fs/promises";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";

const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const defaultRepositoryRoot = resolve(moduleDirectory, "../..");

const schemaFiles = {
  common: "common.schema.json",
  product: "product-manifest.schema.json",
  book: "book-manifest.schema.json",
  source: "source-manifest.schema.json",
  audio: "audio-artifact-manifest.schema.json",
  content: "content-package.schema.json",
  behavior: "behavior-fixture.schema.json"
};

const schemaIDs = {
  product: "urn:fuxuan:classic-apps:contracts:product-manifest:v1",
  book: "urn:fuxuan:classic-apps:contracts:book-manifest:v1",
  source: "urn:fuxuan:classic-apps:contracts:source-manifest:v1",
  audio: "urn:fuxuan:classic-apps:contracts:audio-artifact-manifest:v1",
  content: "urn:fuxuan:classic-apps:contracts:content-package:v1",
  behavior: "urn:fuxuan:classic-apps:contracts:behavior-fixture:v1"
};

export class ContractValidationError extends Error {
  constructor(issues) {
    super(`Contract validation failed with ${issues.length} issue(s)`);
    this.name = "ContractValidationError";
    this.issues = issues;
  }
}

function addIssue(issues, label, message) {
  issues.push(`${label}: ${message}`);
}

function requireCondition(condition, issues, label, message) {
  if (!condition) {
    addIssue(issues, label, message);
  }
  return condition;
}

function hasUnpairedSurrogate(value) {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = value.charCodeAt(index + 1);
      if (!(next >= 0xdc00 && next <= 0xdfff)) {
        return true;
      }
      index += 1;
    } else if (code >= 0xdc00 && code <= 0xdfff) {
      return true;
    }
  }
  return false;
}

function validateStringTree(value, pointer, issues, label) {
  if (typeof value === "string") {
    requireCondition(value === value.normalize("NFC"), issues, label, `${pointer} is not NFC`);
    requireCondition(!hasUnpairedSurrogate(value), issues, label, `${pointer} contains an unpaired surrogate`);
    requireCondition(!value.includes("\u0000"), issues, label, `${pointer} contains NUL`);
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((item, index) => validateStringTree(item, `${pointer}/${index}`, issues, label));
    return;
  }

  if (value && typeof value === "object") {
    for (const [key, child] of Object.entries(value)) {
      validateStringTree(key, `${pointer}/<key>`, issues, label);
      validateStringTree(child, `${pointer}/${key}`, issues, label);
    }
  }
}

async function readJSON(path, repositoryRoot, issues, cache) {
  const absolutePath = resolve(path);
  if (cache.has(absolutePath)) {
    return cache.get(absolutePath);
  }

  const label = relative(repositoryRoot, absolutePath) || absolutePath;
  let bytes;
  try {
    bytes = await readFile(absolutePath);
  } catch (error) {
    addIssue(issues, label, `cannot read file (${error.code ?? error.message})`);
    cache.set(absolutePath, null);
    return null;
  }

  requireCondition(
    !(bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf),
    issues,
    label,
    "UTF-8 BOM is not allowed"
  );

  let raw;
  try {
    raw = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  } catch {
    addIssue(issues, label, "is not valid UTF-8");
    cache.set(absolutePath, null);
    return null;
  }

  requireCondition(!raw.includes("\r"), issues, label, "must use LF line endings");
  requireCondition(raw === raw.normalize("NFC"), issues, label, "literal JSON text is not NFC");
  requireCondition(
    raw.endsWith("\n") && !/\n[ \t]*\n$/u.test(raw),
    issues,
    label,
    "must end with exactly one LF"
  );

  let data;
  try {
    data = JSON.parse(raw);
  } catch (error) {
    addIssue(issues, label, `invalid JSON (${error.message})`);
    cache.set(absolutePath, null);
    return null;
  }

  validateStringTree(data, "#", issues, label);
  const result = { data, raw, bytes, path: absolutePath, label };
  cache.set(absolutePath, result);
  return result;
}

function formatSchemaError(error) {
  const location = error.instancePath || "#";
  const parameters = error.params ? ` ${JSON.stringify(error.params)}` : "";
  return `${location} ${error.message ?? "is invalid"}${parameters}`;
}

function validateWithSchema(ajv, schemaID, document, issues) {
  if (!document) {
    return false;
  }
  const validate = ajv.getSchema(schemaID);
  if (!validate) {
    addIssue(issues, document.label, `validator did not compile schema ${schemaID}`);
    return false;
  }
  const valid = validate(document.data);
  if (!valid) {
    for (const error of validate.errors ?? []) {
      addIssue(issues, document.label, formatSchemaError(error));
    }
  }
  return valid;
}

function resolveContained(baseDirectory, candidate, issues, label) {
  if (typeof candidate !== "string" || isAbsolute(candidate) || candidate.includes("\\")) {
    addIssue(issues, label, `unsafe relative path: ${String(candidate)}`);
    return null;
  }

  const segments = candidate.split("/");
  if (segments.includes("..") || segments.includes(".") || segments.includes("")) {
    addIssue(issues, label, `unsafe relative path: ${candidate}`);
    return null;
  }

  const absolute = resolve(baseDirectory, candidate);
  const relation = relative(baseDirectory, absolute);
  if (relation === ".." || relation.startsWith(`..${sep}`) || isAbsolute(relation)) {
    addIssue(issues, label, `path escapes its root: ${candidate}`);
    return null;
  }
  return absolute;
}

function localesMatch(localized, locales, issues, label) {
  const actual = Object.keys(localized ?? {}).sort();
  const expected = [...(locales ?? [])].sort();
  requireCondition(
    JSON.stringify(actual) === JSON.stringify(expected),
    issues,
    label,
    `localizations ${JSON.stringify(actual)} do not match supported locales ${JSON.stringify(expected)}`
  );
}

async function sha256File(path) {
  const bytes = await readFile(path);
  return {
    bytes: bytes.length,
    sha256: createHash("sha256").update(bytes).digest("hex")
  };
}

function stableJSONStringify(value) {
  if (value === null || typeof value === "boolean" || typeof value === "string") {
    return JSON.stringify(value);
  }
  if (typeof value === "number") {
    if (!Number.isSafeInteger(value)) {
      throw new TypeError("canonical JSON numbers must be safe integers");
    }
    return String(value);
  }
  if (Array.isArray(value)) {
    return `[${value.map(stableJSONStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${stableJSONStringify(value[key])}`)
      .join(",")}}`;
  }
  throw new TypeError(`unsupported canonical JSON value: ${typeof value}`);
}

export function contentHashForPackage(contentPackage) {
  const payload = structuredClone(contentPackage);
  delete payload.contentHash;
  return createHash("sha256").update(stableJSONStringify(payload), "utf8").digest("hex");
}

function assertUnique(values, issues, label, description) {
  const seen = new Set();
  for (const value of values) {
    if (seen.has(value)) {
      addIssue(issues, label, `duplicate ${description}: ${value}`);
    }
    seen.add(value);
  }
}

function validateApprovals(sourceManifest, issues, label) {
  if (sourceManifest.releaseEligibility !== "eligible") {
    return;
  }

  requireCondition(sourceManifest.reviewStatus === "approved", issues, label, "eligible source must be approved");
  for (const [kind, approval] of Object.entries(sourceManifest.approvals)) {
    requireCondition(approval.status === "approved", issues, label, `eligible source requires approved ${kind}`);
    requireCondition(Boolean(approval.reviewedBy), issues, label, `approved ${kind} must record reviewedBy`);
    requireCondition(Boolean(approval.reviewedAt), issues, label, `approved ${kind} must record reviewedAt`);
  }

  const releaseInputs = sourceManifest.sources.filter((source) =>
    ["canonical-input", "transcription-base"].includes(source.role)
  );
  requireCondition(releaseInputs.length > 0, issues, label, "eligible source needs a canonical input or transcription base");
  for (const source of releaseInputs) {
    requireCondition(
      Boolean(source.canonicalIdentifier),
      issues,
      label,
      `${source.sourceID} must record an archival or canonical identifier`
    );
    requireCondition(
      ["public-domain", "product-license"].includes(source.rights.status),
      issues,
      label,
      `${source.sourceID} is not rights-approved release input`
    );
    requireCondition(
      source.rights.commercialUse === "permitted" && source.rights.redistribution === "permitted",
      issues,
      label,
      `${source.sourceID} does not permit commercial use and redistribution`
    );
  }
}

async function validateSourceManifest({ sourceDocument, repositoryRoot, issues }) {
  const sourceManifest = sourceDocument.data;
  const sourceIDs = sourceManifest.sources.map((source) => source.sourceID);
  assertUnique(sourceIDs, issues, sourceDocument.label, "sourceID");
  validateApprovals(sourceManifest, issues, sourceDocument.label);
  if (sourceManifest.reviewStatus === "approved") {
    requireCondition(
      sourceManifest.approvals.textAccuracy.status === "approved",
      issues,
      sourceDocument.label,
      "approved source review requires approved text accuracy"
    );
  }

  const localArtifacts = new Map();
  for (const source of sourceManifest.sources) {
    requireCondition(
      source.sourceID.startsWith(`${sourceManifest.productID}.source.`),
      issues,
      sourceDocument.label,
      `sourceID is outside product namespace: ${source.sourceID}`
    );
    assertUnique(
      source.artifacts.map((artifact) => artifact.locator),
      issues,
      sourceDocument.label,
      `artifact locator in ${source.sourceID}`
    );

    const isCBETA = source.sourceURI === "https://github.com/cbeta-org/xml-p5";
    if (isCBETA) {
      requireCondition(
        /^[a-f0-9]{40}$/.test(source.revision ?? ""),
        issues,
        sourceDocument.label,
        `${source.sourceID} must pin a full CBETA commit`
      );
      requireCondition(
        source.role === "collation-reference" || source.rights.status === "product-license",
        issues,
        sourceDocument.label,
        `${source.sourceID} may only be a collation reference without product permission`
      );
    }

    for (const artifact of source.artifacts) {
      if (/^[a-z][a-z0-9+.-]*:\/\//i.test(artifact.locator)) {
        if (isCBETA) {
          requireCondition(
            artifact.locator.includes(`/${source.revision}/`),
            issues,
            sourceDocument.label,
            `${source.sourceID} artifact URL is not pinned to its revision`
          );
          requireCondition(
            Boolean(artifact.pathWithinSource) && artifact.locator.endsWith(`/${artifact.pathWithinSource}`),
            issues,
            sourceDocument.label,
            `${source.sourceID} artifact path does not match its source path`
          );
        }
        continue;
      }

      const artifactPath = resolveContained(repositoryRoot, artifact.locator, issues, sourceDocument.label);
      if (!artifactPath) {
        continue;
      }
      try {
        const actual = await sha256File(artifactPath);
        requireCondition(actual.bytes === artifact.bytes, issues, sourceDocument.label, `${artifact.locator} byte count changed`);
        requireCondition(actual.sha256 === artifact.sha256, issues, sourceDocument.label, `${artifact.locator} SHA-256 changed`);
        localArtifacts.set(artifact.locator, artifact);
      } catch (error) {
        addIssue(issues, sourceDocument.label, `cannot verify ${artifact.locator} (${error.code ?? error.message})`);
      }
    }
  }
  return localArtifacts;
}

function validateContentText(value, issues, label, pointer) {
  requireCondition(!value.includes("\r"), issues, label, `${pointer} contains CR`);
  requireCondition(!/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/u.test(value), issues, label, `${pointer} contains a control character`);
  requireCondition(!value.includes("\t"), issues, label, `${pointer} contains a tab`);
}

function validateContentPackageSemantics({ contentDocument, book, source, locale, issues }) {
  const content = contentDocument.data;
  requireCondition(content.productID === book.productID, issues, contentDocument.label, "productID does not match book");
  requireCondition(content.bookID === book.bookID, issues, contentDocument.label, "bookID does not match book");
  requireCondition(content.editionID === book.editionID, issues, contentDocument.label, "editionID does not match book");
  requireCondition(content.contentVersion === book.contentVersion, issues, contentDocument.label, "contentVersion does not match book");
  requireCondition(content.locale === locale, issues, contentDocument.label, `locale does not match manifest key ${locale}`);
  requireCondition(content.contentHash === contentHashForPackage(content), issues, contentDocument.label, "contentHash does not match canonical payload");

  const sectionIDs = content.sections.map((section) => section.sectionID);
  const paragraphIDs = content.paragraphs.map((paragraph) => paragraph.paragraphID);
  assertUnique(sectionIDs, issues, contentDocument.label, "sectionID");
  assertUnique(paragraphIDs, issues, contentDocument.label, "paragraphID");
  const sectionSet = new Set(sectionIDs);
  const sourceSet = new Set(source.sources.map((entry) => entry.sourceID));
  const releaseSourceSet = new Set(
    source.sources
      .filter((entry) => ["canonical-input", "transcription-base"].includes(entry.role))
      .map((entry) => entry.sourceID)
  );

  for (const section of content.sections) {
    requireCondition(section.sectionID.startsWith(`${content.productID}.s`), issues, contentDocument.label, `sectionID outside product namespace: ${section.sectionID}`);
    if (section.parentSectionID !== null) {
      requireCondition(sectionSet.has(section.parentSectionID), issues, contentDocument.label, `unknown parent section: ${section.parentSectionID}`);
      requireCondition(section.parentSectionID !== section.sectionID, issues, contentDocument.label, `section cannot parent itself: ${section.sectionID}`);
    }
    validateContentText(section.title, issues, contentDocument.label, section.sectionID);
    assertUnique(
      section.sourceReferences.map((reference) => `${reference.sourceID}:${reference.locator}`),
      issues,
      contentDocument.label,
      `source reference in ${section.sectionID}`
    );
    for (const reference of section.sourceReferences) {
      requireCondition(sourceSet.has(reference.sourceID), issues, contentDocument.label, `unknown source reference: ${reference.sourceID}`);
    }
    requireCondition(
      section.sourceReferences.some((reference) => releaseSourceSet.has(reference.sourceID)),
      issues,
      contentDocument.label,
      `${section.sectionID} has no approved canonical source reference`
    );
  }

  for (const section of content.sections) {
    const visited = new Set([section.sectionID]);
    let parent = section.parentSectionID;
    while (parent !== null) {
      if (visited.has(parent)) {
        addIssue(issues, contentDocument.label, `section parent cycle includes ${parent}`);
        break;
      }
      visited.add(parent);
      parent = content.sections.find((candidate) => candidate.sectionID === parent)?.parentSectionID ?? null;
    }
  }

  for (const paragraph of content.paragraphs) {
    requireCondition(paragraph.paragraphID.startsWith(`${content.productID}.p`), issues, contentDocument.label, `paragraphID outside product namespace: ${paragraph.paragraphID}`);
    requireCondition(sectionSet.has(paragraph.sectionID), issues, contentDocument.label, `unknown paragraph section: ${paragraph.sectionID}`);
    validateContentText(paragraph.text, issues, contentDocument.label, paragraph.paragraphID);
    assertUnique(
      paragraph.sourceReferences.map((reference) => `${reference.sourceID}:${reference.locator}`),
      issues,
      contentDocument.label,
      `source reference in ${paragraph.paragraphID}`
    );
    for (const reference of paragraph.sourceReferences) {
      requireCondition(sourceSet.has(reference.sourceID), issues, contentDocument.label, `unknown source reference: ${reference.sourceID}`);
    }
    requireCondition(
      paragraph.sourceReferences.some((reference) => releaseSourceSet.has(reference.sourceID)),
      issues,
      contentDocument.label,
      `${paragraph.paragraphID} has no approved canonical source reference`
    );
  }

  const sectionOrders = content.sections.map((section) => `${section.parentSectionID ?? "root"}:${section.order}`);
  const paragraphOrders = content.paragraphs.map((paragraph) => `${paragraph.sectionID}:${paragraph.order}`);
  assertUnique(sectionOrders, issues, contentDocument.label, "section sibling order");
  assertUnique(paragraphOrders, issues, contentDocument.label, "paragraph order within section");

  return {
    sectionStructure: content.sections.map(({ sectionID, parentSectionID, order, sourceReferences }) => ({
      sectionID,
      parentSectionID,
      order,
      sourceReferences
    })),
    paragraphStructure: content.paragraphs.map(({ paragraphID, sectionID, order, sourceReferences }) => ({
      paragraphID,
      sectionID,
      order,
      sourceReferences
    }))
  };
}

async function validateAudioManifest({ audioDocument, product, book, repositoryRoot, issues, readCache }) {
  const audio = audioDocument.data;
  requireCondition(audio.productID === product.productID, issues, audioDocument.label, "productID does not match product");
  requireCondition(audio.catalogID.startsWith(`${product.productID}.audio`), issues, audioDocument.label, "catalogID is outside product namespace");
  requireCondition(audio.contentVersion === book.contentVersion, issues, audioDocument.label, "contentVersion does not match book");
  localesMatch(audio.performers, product.supportedLocales, issues, audioDocument.label);
  requireCondition(
    JSON.stringify([...audio.supportedLocales].sort()) === JSON.stringify([...product.supportedLocales].sort()),
    issues,
    audioDocument.label,
    "supported locales do not match product"
  );

  assertUnique(audio.artifacts.map((artifact) => artifact.artifactID), issues, audioDocument.label, "audio artifactID");
  assertUnique(audio.artifacts.map((artifact) => artifact.legacyTrackID).filter(Boolean), issues, audioDocument.label, "legacy track ID");
  const fileNames = [];
  for (const artifact of audio.artifacts) {
    requireCondition(artifact.artifactID.startsWith(`${product.productID}.audio.`), issues, audioDocument.label, `artifactID outside product namespace: ${artifact.artifactID}`);
    requireCondition(artifact.rightsReference === audio.rights.rightsID, issues, audioDocument.label, `${artifact.artifactID} has an unknown rights reference`);
    requireCondition(artifact.contentMapping.bookID === book.bookID, issues, audioDocument.label, `${artifact.artifactID} maps to another book`);
    localesMatch(artifact.titles, product.supportedLocales, issues, audioDocument.label);
    assertUnique(artifact.renditions.map((rendition) => rendition.renditionID), issues, audioDocument.label, `renditionID in ${artifact.artifactID}`);
    fileNames.push(...artifact.renditions.map((rendition) => rendition.fileName));

    if (audio.contractState === "release-ready") {
      requireCondition(artifact.contentMapping.status === "mapped", issues, audioDocument.label, `${artifact.artifactID} lacks canonical content mapping`);
      for (const rendition of artifact.renditions) {
        requireCondition(Boolean(rendition.codec), issues, audioDocument.label, `${artifact.artifactID} lacks codec metadata`);
        requireCondition(Number.isInteger(rendition.durationMilliseconds), issues, audioDocument.label, `${artifact.artifactID} lacks duration metadata`);
      }
    }
  }
  assertUnique(fileNames, issues, audioDocument.label, "audio rendition filename");

  if (audio.rights.reuseEligibility === "eligible") {
    requireCondition(audio.rights.status !== "legacy-unverified", issues, audioDocument.label, "unverified audio rights cannot be reusable");
  }

  if (!audio.compatibility) {
    return;
  }

  const deliveryPath = resolveContained(repositoryRoot, audio.compatibility.deliveryManifest, issues, audioDocument.label);
  const deliveryDocument = deliveryPath
    ? await readJSON(deliveryPath, repositoryRoot, issues, readCache)
    : null;
  if (!deliveryDocument) {
    return;
  }
  const delivery = deliveryDocument.data;
  requireCondition(Array.isArray(delivery.tracks), issues, deliveryDocument.label, "legacy delivery manifest has no tracks");
  if (!Array.isArray(delivery.tracks)) {
    return;
  }
  requireCondition(delivery.tracks.length === audio.artifacts.length, issues, audioDocument.label, "legacy delivery track count differs from artifact manifest");
  for (let index = 0; index < Math.min(delivery.tracks.length, audio.artifacts.length); index += 1) {
    const track = delivery.tracks[index];
    const artifact = audio.artifacts[index];
    const rendition = artifact.renditions[0];
    requireCondition(artifact.legacyTrackID === track.id, issues, audioDocument.label, `legacy track order/ID differs at index ${index}`);
    requireCondition(rendition.fileName === `${track.id}.${delivery.fileExtension}`, issues, audioDocument.label, `${artifact.artifactID} filename differs from delivery catalog`);
    requireCondition(rendition.bytes === track.bytes, issues, audioDocument.label, `${artifact.artifactID} byte count differs from delivery catalog`);
    requireCondition(rendition.sha256 === track.sha256, issues, audioDocument.label, `${artifact.artifactID} SHA-256 differs from delivery catalog`);
    for (const locale of product.supportedLocales) {
      requireCondition(
        artifact.titles[locale] === track.titles?.[locale],
        issues,
        audioDocument.label,
        `${artifact.artifactID} ${locale} title differs from delivery catalog`
      );
    }
  }
  for (const locale of product.supportedLocales) {
    requireCondition(audio.performers[locale] === delivery.localizations?.[locale]?.artist, issues, audioDocument.label, `${locale} performer differs from delivery catalog`);
  }

  // The compatibility catalog has its own generator/schema and is validated by
  // verify.sh audio-catalog. It is intentionally not validated as an artifact manifest.
}

function expectedAudioDecision(input) {
  if (
    input.savedArtifactID === input.requestedArtifactID &&
    Number.isFinite(input.savedTimeSeconds) &&
    input.savedTimeSeconds > 0
  ) {
    return { startMode: "resume", seekTimeSeconds: input.savedTimeSeconds };
  }
  return { startMode: "beginning" };
}

function sanitizeFileNameComponent(rawValue) {
  return rawValue
    .replace(/[《》「」]/gu, "")
    .replace(/[\/\\?%*|"<>:：\n\r\t]/gu, "-")
    .replace(/\s+/gu, "-")
    .replace(/-+/gu, "-")
    .replace(/^[- ]+|[- ]+$/gu, "");
}

function expectedShareFileName(input) {
  const sourceName = sanitizeFileNameComponent(input.source ?? "");
  const baseName = sourceName || input.defaultBaseName;
  const simplified = input.locale === "zh-Hans";
  let descriptor;
  let extension;
  if (input.kind === "text") {
    descriptor = simplified ? "经文" : "經文";
    extension = "txt";
  } else {
    descriptor = simplified ? "分享图" : "分享圖";
    extension = "jpg";
    if (input.pageNumber !== undefined || input.pageCount !== undefined) {
      const width = Math.max(2, String(input.pageCount).length);
      descriptor += `-${String(input.pageNumber).padStart(width, "0")}-${String(input.pageCount).padStart(width, "0")}`;
    }
  }
  return `${baseName}-${descriptor}-${input.uniqueSuffix}.${extension}`;
}

function expectedDeepLink(input) {
  try {
    const url = new URL(input.url);
    const path = url.searchParams.get("path");
    if (url.protocol === "lengyan:" && url.hostname === "verse" && path) {
      return { accepted: true, productID: "lengyan", legacyPath: path };
    }
  } catch {
    // Invalid URL is a rejected deep link.
  }
  return { accepted: false };
}

function validateBehaviorFixture(document, issues) {
  const fixture = document.data;
  assertUnique(fixture.cases.map((entry) => entry.name), issues, document.label, "behavior case name");
  for (const entry of fixture.cases) {
    let expected;
    switch (fixture.behavior) {
      case "audio-start-decision":
        expected = expectedAudioDecision(entry.input);
        break;
      case "share-file-name":
        expected = { fileName: expectedShareFileName(entry.input) };
        if (entry.input.pageNumber !== undefined) {
          requireCondition(
            entry.input.pageNumber <= entry.input.pageCount,
            issues,
            document.label,
            `${entry.name} pageNumber exceeds pageCount`
          );
        }
        requireCondition(
          !/[12][0-9]{3}[-_]?[01][0-9][-_]?[0-3][0-9]/u.test(entry.expected.fileName),
          issues,
          document.label,
          `${entry.name} unexpectedly embeds a date`
        );
        break;
      case "deep-link":
        expected = expectedDeepLink(entry.input);
        break;
      default:
        continue;
    }
    requireCondition(
      JSON.stringify(entry.expected) === JSON.stringify(expected),
      issues,
      document.label,
      `${entry.name} expected ${JSON.stringify(entry.expected)} but contract produces ${JSON.stringify(expected)}`
    );
  }
}

async function buildSchemaValidator(repositoryRoot, issues, readCache) {
  const ajv = new Ajv2020({
    allErrors: true,
    allowUnionTypes: true,
    strict: true
  });
  for (const fileName of Object.values(schemaFiles)) {
    const schemaDocument = await readJSON(
      join(repositoryRoot, "Contracts", "Schemas", fileName),
      repositoryRoot,
      issues,
      readCache
    );
    if (schemaDocument) {
      try {
        ajv.addSchema(schemaDocument.data);
      } catch (error) {
        addIssue(issues, schemaDocument.label, `cannot compile schema (${error.message})`);
      }
    }
  }
  return ajv;
}

export async function validateRepository({ repositoryRoot = defaultRepositoryRoot } = {}) {
  const root = resolve(repositoryRoot);
  const issues = [];
  const warnings = [];
  const readCache = new Map();
  const ajv = await buildSchemaValidator(root, issues, readCache);

  const productsDirectory = join(root, "Products");
  let productEntries = [];
  try {
    productEntries = (await readdir(productsDirectory, { withFileTypes: true }))
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
      .sort((left, right) => left.name.localeCompare(right.name));
  } catch (error) {
    addIssue(issues, "Products", `cannot list products (${error.code ?? error.message})`);
  }
  requireCondition(productEntries.length > 0, issues, "Products", "no product manifests found");

  const productIDs = new Set();
  const summaries = [];
  let contentPackageCount = 0;
  let audioArtifactCount = 0;

  for (const entry of productEntries) {
    const productDirectory = join(productsDirectory, entry.name);
    const productDocument = await readJSON(join(productDirectory, "product.json"), root, issues, readCache);
    if (!validateWithSchema(ajv, schemaIDs.product, productDocument, issues)) {
      continue;
    }
    const product = productDocument.data;
    requireCondition(product.productID === entry.name, issues, productDocument.label, "productID must match directory name");
    requireCondition(!productIDs.has(product.productID), issues, productDocument.label, `duplicate productID ${product.productID}`);
    productIDs.add(product.productID);
    requireCondition(product.supportedLocales.includes(product.defaultLocale), issues, productDocument.label, "default locale is not supported");
    localesMatch(product.titles, product.supportedLocales, issues, productDocument.label);
    requireCondition(
      !product.manifests.audio || product.features.audio,
      issues,
      productDocument.label,
      "audio manifest requires the audio capability"
    );
    if (["production", "development"].includes(product.lifecycle)) {
      requireCondition(
        product.features.audio === Boolean(product.manifests.audio),
        issues,
        productDocument.label,
        "audio feature and audio manifest link must agree"
      );
    }

    const bookPath = resolveContained(productDirectory, product.manifests.book, issues, productDocument.label);
    const sourcePath = resolveContained(productDirectory, product.manifests.source, issues, productDocument.label);
    const bookDocument = bookPath ? await readJSON(bookPath, root, issues, readCache) : null;
    const sourceDocument = sourcePath ? await readJSON(sourcePath, root, issues, readCache) : null;
    const bookValid = validateWithSchema(ajv, schemaIDs.book, bookDocument, issues);
    const sourceValid = validateWithSchema(ajv, schemaIDs.source, sourceDocument, issues);
    if (!bookValid || !sourceValid) {
      continue;
    }
    const book = bookDocument.data;
    const source = sourceDocument.data;

    for (const document of [bookDocument, sourceDocument]) {
      requireCondition(document.data.productID === product.productID, issues, document.label, "productID does not match product");
      requireCondition(document.data.bookID === book.bookID, issues, document.label, "bookID does not match book");
      requireCondition(document.data.editionID === book.editionID, issues, document.label, "editionID does not match book");
    }
    requireCondition(book.sourceManifest === product.manifests.source, issues, bookDocument.label, "sourceManifest does not match product link");
    requireCondition(book.supportedLocales.includes(book.canonicalLocale), issues, bookDocument.label, "canonical locale is not supported");
    requireCondition(
      JSON.stringify([...book.supportedLocales].sort()) === JSON.stringify([...product.supportedLocales].sort()),
      issues,
      bookDocument.label,
      "supported locales do not match product"
    );
    localesMatch(book.titles, book.supportedLocales, issues, bookDocument.label);

    const localArtifacts = await validateSourceManifest({ sourceDocument, repositoryRoot: root, issues });
    if (product.lifecycle === "source-review") {
      requireCondition(
        book.contractState === "source-review" && source.releaseEligibility === "blocked",
        issues,
        productDocument.label,
        "source-review product cannot expose canonical-ready content"
      );
    }
    if (book.contractState === "source-review") {
      requireCondition(!book.contentPackages, issues, bookDocument.label, "source-review book cannot expose canonical content");
      requireCondition(source.releaseEligibility === "blocked", issues, sourceDocument.label, "source-review book must remain release-blocked");
      try {
        const unapprovedContent = await readdir(join(productDirectory, "Content"), { recursive: true });
        requireCondition(
          unapprovedContent.length === 0,
          issues,
          bookDocument.label,
          `source-review product contains unapproved content files: ${unapprovedContent.join(", ")}`
        );
      } catch (error) {
        if (error.code !== "ENOENT") {
          addIssue(issues, bookDocument.label, `cannot inspect candidate content directory (${error.code ?? error.message})`);
        }
      }
    }
    if (book.contractState === "canonical-ready") {
      requireCondition(source.releaseEligibility === "eligible", issues, sourceDocument.label, "canonical-ready book needs eligible source");
      localesMatch(book.contentPackages, book.supportedLocales, issues, bookDocument.label);
    }
    if (book.legacyCompatibility) {
      const declared = new Set(book.legacyCompatibility.sourceArtifacts);
      requireCondition(declared.size === book.legacyCompatibility.sourceArtifacts.length, issues, bookDocument.label, "duplicate legacy source artifact");
      for (const locator of declared) {
        requireCondition(localArtifacts.has(locator), issues, bookDocument.label, `legacy artifact is not hash-locked in source manifest: ${locator}`);
      }
    }

    const contentStructures = [];
    for (const [locale, contentLink] of Object.entries(book.contentPackages ?? {})) {
      const contentPath = resolveContained(productDirectory, contentLink, issues, bookDocument.label);
      const contentDocument = contentPath ? await readJSON(contentPath, root, issues, readCache) : null;
      if (validateWithSchema(ajv, schemaIDs.content, contentDocument, issues)) {
        contentStructures.push(
          validateContentPackageSemantics({ contentDocument, book, source, locale, issues })
        );
        contentPackageCount += 1;
      }
    }
    if (contentStructures.length > 1) {
      const reference = JSON.stringify(contentStructures[0]);
      for (const structure of contentStructures.slice(1)) {
        requireCondition(JSON.stringify(structure) === reference, issues, bookDocument.label, "localized content packages have different stable structure");
      }
    }

    let productAudioCount = 0;
    if (product.manifests.audio) {
      const audioPath = resolveContained(productDirectory, product.manifests.audio, issues, productDocument.label);
      const audioDocument = audioPath ? await readJSON(audioPath, root, issues, readCache) : null;
      if (validateWithSchema(ajv, schemaIDs.audio, audioDocument, issues)) {
        await validateAudioManifest({
          audioDocument,
          product,
          book,
          repositoryRoot: root,
          issues,
          readCache
        });
        productAudioCount = audioDocument.data.artifacts.length;
        audioArtifactCount += productAudioCount;
      }
    }

    if (source.releaseEligibility === "blocked") {
      warnings.push(`${product.productID}: release blocked (${source.reviewStatus})`);
    }
    summaries.push({
      productID: product.productID,
      lifecycle: product.lifecycle,
      contractState: book.contractState,
      releaseEligibility: source.releaseEligibility,
      audioArtifacts: productAudioCount
    });
  }

  const fixturesDirectory = join(root, "Contracts", "BehaviorFixtures");
  let fixtureEntries = [];
  try {
    fixtureEntries = (await readdir(fixturesDirectory, { withFileTypes: true }))
      .filter((entry) => entry.isFile() && entry.name.endsWith(".json"))
      .sort((left, right) => left.name.localeCompare(right.name));
  } catch (error) {
    addIssue(issues, "Contracts/BehaviorFixtures", `cannot list fixtures (${error.code ?? error.message})`);
  }
  requireCondition(fixtureEntries.length > 0, issues, "Contracts/BehaviorFixtures", "no behavior fixtures found");
  const fixtureIDs = [];
  for (const entry of fixtureEntries) {
    const fixtureDocument = await readJSON(join(fixturesDirectory, entry.name), root, issues, readCache);
    if (validateWithSchema(ajv, schemaIDs.behavior, fixtureDocument, issues)) {
      fixtureIDs.push(fixtureDocument.data.fixtureID);
      validateBehaviorFixture(fixtureDocument, issues);
    }
  }
  assertUnique(fixtureIDs, issues, "Contracts/BehaviorFixtures", "fixtureID");

  if (issues.length > 0) {
    throw new ContractValidationError(issues);
  }

  return {
    products: summaries,
    productCount: summaries.length,
    contentPackageCount,
    audioArtifactCount,
    fixtureCount: fixtureIDs.length,
    warnings
  };
}

function printReport(report) {
  console.log(
    `Validated ${report.productCount} products, ${report.contentPackageCount} canonical content packages, ` +
      `${report.audioArtifactCount} audio artifacts, and ${report.fixtureCount} behavior fixtures.`
  );
  for (const product of report.products) {
    console.log(
      `- ${product.productID}: ${product.contractState}, source ${product.releaseEligibility}, ` +
        `${product.audioArtifacts} audio artifacts`
    );
  }
  for (const warning of report.warnings) {
    console.log(`BLOCKED (recorded): ${warning}`);
  }
}

async function main() {
  const repositoryRoot = process.argv[2] ? resolve(process.argv[2]) : defaultRepositoryRoot;
  try {
    const repositoryStat = await stat(repositoryRoot);
    if (!repositoryStat.isDirectory()) {
      throw new Error(`${repositoryRoot} is not a directory`);
    }
    printReport(await validateRepository({ repositoryRoot }));
  } catch (error) {
    if (error instanceof ContractValidationError) {
      console.error(error.message);
      for (const issue of error.issues) {
        console.error(`- ${issue}`);
      }
    } else {
      console.error(error.stack ?? error.message);
    }
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main();
}
