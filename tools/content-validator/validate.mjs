#!/usr/bin/env node

import { createHash } from "node:crypto";
import { readFile, readdir, stat } from "node:fs/promises";
import { dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import Ajv2020 from "ajv/dist/2020.js";

import {
  contentHashForPackage,
  mappingHashForLegacyMap
} from "./canonical-json.mjs";

export { contentHashForPackage } from "./canonical-json.mjs";

const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const defaultRepositoryRoot = resolve(moduleDirectory, "../..");

const schemaFiles = {
  common: "common.schema.json",
  product: "product-manifest.schema.json",
  book: "book-manifest.schema.json",
  source: "source-manifest.schema.json",
  audio: "audio-artifact-manifest.schema.json",
  audioDelivery: "audio-delivery.schema.json",
  audioBuildInput: "audio-build-input.schema.json",
  content: "content-package.schema.json",
  legacyMap: "legacy-map.schema.json",
  behavior: "behavior-fixture.schema.json"
};

const schemaIDs = {
  product: "urn:fuxuan:classic-apps:contracts:product-manifest:v1",
  book: "urn:fuxuan:classic-apps:contracts:book-manifest:v1",
  source: "urn:fuxuan:classic-apps:contracts:source-manifest:v1",
  audio: "urn:fuxuan:classic-apps:contracts:audio-artifact-manifest:v1",
  audioDelivery: "urn:fuxuan:classic-apps:contracts:audio-delivery:v1",
  audioBuildInput: "urn:fuxuan:classic-apps:contracts:audio-build-input:v1",
  content: "urn:fuxuan:classic-apps:contracts:content-package:v1",
  legacyMap: "urn:fuxuan:classic-apps:contracts:legacy-map:v1",
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

function validatePackageSourceReferences({
  references,
  sourceSet,
  acceptableSourceSet,
  issues,
  label,
  pointer
}) {
  assertUnique(
    references.map((reference) => `${reference.sourceID}:${reference.locator}`),
    issues,
    label,
    `source reference in ${pointer}`
  );
  for (const reference of references) {
    requireCondition(sourceSet.has(reference.sourceID), issues, label, `unknown source reference: ${reference.sourceID}`);
  }
  requireCondition(
    references.some((reference) => acceptableSourceSet.has(reference.sourceID)),
    issues,
    label,
    `${pointer} has no source reference allowed for this content status`
  );
}

function validateContentPackageSemantics({ contentDocument, book, source, locale, issues }) {
  const content = contentDocument.data;
  requireCondition(content.productID === book.productID, issues, contentDocument.label, "productID does not match book");
  requireCondition(content.bookID === book.bookID, issues, contentDocument.label, "bookID does not match book");
  requireCondition(content.editionID === book.editionID, issues, contentDocument.label, "editionID does not match book");
  requireCondition(content.contentVersion === book.contentVersion, issues, contentDocument.label, "contentVersion does not match book");
  requireCondition(content.locale === locale, issues, contentDocument.label, `locale does not match manifest key ${locale}`);
  if (content.contentStatus === "legacy-migration") {
    requireCondition(book.contractState === "legacy-migration", issues, contentDocument.label, "legacy content requires a legacy-migration book");
    requireCondition(source.releaseEligibility === "blocked", issues, contentDocument.label, "legacy migration content cannot use an eligible source manifest");
  } else {
    requireCondition(book.contractState === "canonical-ready", issues, contentDocument.label, "release content requires a canonical-ready book");
    requireCondition(source.releaseEligibility === "eligible", issues, contentDocument.label, "release content requires an eligible source manifest");
  }
  try {
    requireCondition(content.contentHash === contentHashForPackage(content), issues, contentDocument.label, "contentHash does not match canonical payload");
  } catch (error) {
    addIssue(issues, contentDocument.label, `cannot compute contentHash (${error.message})`);
  }

  const volumeIDs = content.volumes.map((volume) => volume.volumeID);
  const sectionIDs = content.sections.map((section) => section.sectionID);
  const paragraphIDs = content.paragraphs.map((paragraph) => paragraph.paragraphID);
  assertUnique(volumeIDs, issues, contentDocument.label, "volumeID");
  assertUnique(content.volumes.map((volume) => volume.number), issues, contentDocument.label, "volume number");
  assertUnique(content.volumes.map((volume) => volume.order), issues, contentDocument.label, "volume order");
  assertUnique(sectionIDs, issues, contentDocument.label, "sectionID");
  assertUnique(paragraphIDs, issues, contentDocument.label, "paragraphID");
  const volumeSet = new Set(volumeIDs);
  const sectionSet = new Set(sectionIDs);
  const sourceSet = new Set(source.sources.map((entry) => entry.sourceID));
  const acceptableSourceSet = new Set(
    source.sources
      .filter((entry) =>
        content.contentStatus === "legacy-migration"
          ? entry.role === "legacy-runtime-input"
          : ["canonical-input", "transcription-base"].includes(entry.role)
      )
      .map((entry) => entry.sourceID)
  );
  requireCondition(acceptableSourceSet.size > 0, issues, contentDocument.label, "content status has no eligible source role");

  for (const volume of content.volumes) {
    requireCondition(volume.volumeID.startsWith(`${content.productID}.v`), issues, contentDocument.label, `volumeID outside product namespace: ${volume.volumeID}`);
    validateContentText(volume.title, issues, contentDocument.label, volume.volumeID);
    validatePackageSourceReferences({
      references: volume.sourceReferences,
      sourceSet,
      acceptableSourceSet,
      issues,
      label: contentDocument.label,
      pointer: volume.volumeID
    });
  }

  for (const section of content.sections) {
    requireCondition(section.sectionID.startsWith(`${content.productID}.s`), issues, contentDocument.label, `sectionID outside product namespace: ${section.sectionID}`);
    if (section.parentSectionID !== null) {
      requireCondition(sectionSet.has(section.parentSectionID), issues, contentDocument.label, `unknown parent section: ${section.parentSectionID}`);
      requireCondition(section.parentSectionID !== section.sectionID, issues, contentDocument.label, `section cannot parent itself: ${section.sectionID}`);
    }
    validateContentText(section.title, issues, contentDocument.label, section.sectionID);
    if (section.subtitle) {
      validateContentText(section.subtitle, issues, contentDocument.label, `${section.sectionID} subtitle`);
    }
    validatePackageSourceReferences({
      references: section.sourceReferences,
      sourceSet,
      acceptableSourceSet,
      issues,
      label: contentDocument.label,
      pointer: section.sectionID
    });
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

  const volumeUsage = new Map(volumeIDs.map((volumeID) => [volumeID, 0]));
  for (const paragraph of content.paragraphs) {
    requireCondition(paragraph.paragraphID.startsWith(`${content.productID}.p`), issues, contentDocument.label, `paragraphID outside product namespace: ${paragraph.paragraphID}`);
    requireCondition(sectionSet.has(paragraph.sectionID), issues, contentDocument.label, `unknown paragraph section: ${paragraph.sectionID}`);
    if (paragraph.volumeID === null) {
      requireCondition(content.contentStatus === "legacy-migration", issues, contentDocument.label, `${paragraph.paragraphID} has no volume mapping`);
    } else {
      requireCondition(volumeSet.has(paragraph.volumeID), issues, contentDocument.label, `unknown paragraph volume: ${paragraph.volumeID}`);
      volumeUsage.set(paragraph.volumeID, (volumeUsage.get(paragraph.volumeID) ?? 0) + 1);
    }
    if (content.contentStatus === "release-canonical") {
      requireCondition(paragraph.legacyVolumeHint === undefined, issues, contentDocument.label, `${paragraph.paragraphID} carries legacy-only volume metadata`);
    }
    validateContentText(paragraph.text, issues, contentDocument.label, paragraph.paragraphID);
    validatePackageSourceReferences({
      references: paragraph.sourceReferences,
      sourceSet,
      acceptableSourceSet,
      issues,
      label: contentDocument.label,
      pointer: paragraph.paragraphID
    });
  }
  for (const [volumeID, count] of volumeUsage) {
    requireCondition(count > 0, issues, contentDocument.label, `${volumeID} has no mapped paragraphs`);
  }

  const sectionOrders = content.sections.map((section) => `${section.parentSectionID ?? "root"}:${section.order}`);
  const paragraphOrders = content.paragraphs.map((paragraph) => `${paragraph.sectionID}:${paragraph.order}`);
  assertUnique(sectionOrders, issues, contentDocument.label, "section sibling order");
  assertUnique(paragraphOrders, issues, contentDocument.label, "paragraph order within section");

  return {
    volumeStructure: content.volumes.map(({ volumeID, number, order, sourceReferences }) => ({
      volumeID,
      number,
      order,
      sourceIDs: sourceReferences.map((reference) => reference.sourceID)
    })),
    sectionStructure: content.sections.map(({ sectionID, parentSectionID, order, sourceReferences, legacyIDs }) => ({
      sectionID,
      parentSectionID,
      order,
      sourceIDs: sourceReferences.map((reference) => reference.sourceID),
      legacyIDs
    })),
    paragraphStructure: content.paragraphs.map(({ paragraphID, sectionID, volumeID, order, textRole, legacyVolumeHint, sourceReferences }) => ({
      paragraphID,
      sectionID,
      volumeID,
      order,
      textRole,
      legacyVolumeHint,
      sourceIDs: sourceReferences.map((reference) => reference.sourceID)
    }))
  };
}

function validateLegacyMapSemantics({ legacyDocument, book, contentDocuments, issues }) {
  const legacyMap = legacyDocument.data;
  requireCondition(legacyMap.productID === book.productID, issues, legacyDocument.label, "productID does not match book");
  requireCondition(legacyMap.bookID === book.bookID, issues, legacyDocument.label, "bookID does not match book");
  requireCondition(legacyMap.editionID === book.editionID, issues, legacyDocument.label, "editionID does not match book");
  requireCondition(legacyMap.mappingVersion === book.contentVersion, issues, legacyDocument.label, "mappingVersion does not match book contentVersion");
  requireCondition(legacyMap.stableIDScheme === book.stableIDScheme, issues, legacyDocument.label, "stable ID scheme does not match book");
  requireCondition(legacyMap.normalization === book.normalization, issues, legacyDocument.label, "normalization does not match book");
  try {
    requireCondition(
      legacyMap.mappingHash === mappingHashForLegacyMap(legacyMap),
      issues,
      legacyDocument.label,
      "mappingHash does not match canonical payload"
    );
  } catch (error) {
    addIssue(issues, legacyDocument.label, `cannot compute mappingHash (${error.message})`);
  }

  requireCondition(contentDocuments.length > 0, issues, legacyDocument.label, "legacy map has no content package to map");
  if (contentDocuments.length === 0) {
    return 0;
  }
  const content = contentDocuments[0].data;
  requireCondition(content.contentStatus === "legacy-migration", issues, legacyDocument.label, "legacy map requires migration content");
  const sectionByID = new Map(content.sections.map((section) => [section.sectionID, section]));
  const paragraphByID = new Map(content.paragraphs.map((paragraph) => [paragraph.paragraphID, paragraph]));
  const mappingByPath = new Map(legacyMap.paths.map((mapping) => [mapping.legacyPath, mapping]));
  assertUnique(legacyMap.paths.map((mapping) => mapping.legacyPath), issues, legacyDocument.label, "legacy path");
  assertUnique(legacyMap.paths.map((mapping) => mapping.sectionID), issues, legacyDocument.label, "mapped sectionID");
  requireCondition(legacyMap.paths.length === content.sections.length, issues, legacyDocument.label, "legacy path count does not match section count");

  const directParagraphsBySection = new Map(content.sections.map((section) => [section.sectionID, []]));
  const descendantParagraphsBySection = new Map(content.sections.map((section) => [section.sectionID, []]));
  for (const paragraph of content.paragraphs) {
    directParagraphsBySection.get(paragraph.sectionID)?.push(paragraph.paragraphID);
    let sectionID = paragraph.sectionID;
    const visited = new Set();
    while (sectionID !== null && !visited.has(sectionID)) {
      visited.add(sectionID);
      descendantParagraphsBySection.get(sectionID)?.push(paragraph.paragraphID);
      sectionID = sectionByID.get(sectionID)?.parentSectionID ?? null;
    }
  }

  for (let index = 0; index < legacyMap.paths.length; index += 1) {
    const mapping = legacyMap.paths[index];
    const section = sectionByID.get(mapping.sectionID);
    requireCondition(Boolean(section), issues, legacyDocument.label, `unknown mapped section: ${mapping.sectionID}`);
    if (!section) {
      continue;
    }
    requireCondition(
      content.sections[index]?.sectionID === mapping.sectionID,
      issues,
      legacyDocument.label,
      `mapping order differs at index ${index}`
    );
    requireCondition(
      mapping.legacyNodeID === (mapping.legacyPath ? mapping.legacyPath.split("/").at(-1) : "ROOT"),
      issues,
      legacyDocument.label,
      `legacyNodeID does not match path ${mapping.legacyPath || "<root>"}`
    );
    requireCondition(
      section.legacyIDs?.includes(mapping.legacyPath || "ROOT"),
      issues,
      legacyDocument.label,
      `${mapping.sectionID} does not retain its legacy identity`
    );
    requireCondition(section.order === mapping.order, issues, legacyDocument.label, `${mapping.legacyPath || "<root>"} order differs from section`);

    if (mapping.legacyPath === "") {
      requireCondition(mapping.parentLegacyPath === null, issues, legacyDocument.label, "root legacy path must have null parent");
      requireCondition(section.parentSectionID === null, issues, legacyDocument.label, "root mapped section must have null parent");
    } else {
      const slashIndex = mapping.legacyPath.lastIndexOf("/");
      const expectedParentPath = slashIndex === 0 ? "" : mapping.legacyPath.slice(0, slashIndex);
      requireCondition(mapping.parentLegacyPath === expectedParentPath, issues, legacyDocument.label, `${mapping.legacyPath} parent path is inconsistent`);
      const parentMapping = mappingByPath.get(mapping.parentLegacyPath);
      requireCondition(Boolean(parentMapping), issues, legacyDocument.label, `${mapping.legacyPath} parent mapping is missing`);
      requireCondition(
        parentMapping?.sectionID === section.parentSectionID,
        issues,
        legacyDocument.label,
        `${mapping.legacyPath} parent section differs from content`
      );
    }

    const expectedDirect = directParagraphsBySection.get(mapping.sectionID) ?? [];
    const expectedDescendants = descendantParagraphsBySection.get(mapping.sectionID) ?? [];
    requireCondition(
      JSON.stringify(mapping.directParagraphIDs) === JSON.stringify(expectedDirect),
      issues,
      legacyDocument.label,
      `${mapping.legacyPath || "<root>"} direct paragraph mapping differs`
    );
    requireCondition(
      mapping.firstDescendantParagraphID === (expectedDescendants[0] ?? null),
      issues,
      legacyDocument.label,
      `${mapping.legacyPath || "<root>"} first descendant mapping differs`
    );
    requireCondition(
      mapping.descendantParagraphCount === expectedDescendants.length,
      issues,
      legacyDocument.label,
      `${mapping.legacyPath || "<root>"} descendant paragraph count differs`
    );
    for (const paragraphID of mapping.directParagraphIDs) {
      requireCondition(paragraphByID.has(paragraphID), issues, legacyDocument.label, `unknown mapped paragraph: ${paragraphID}`);
    }
  }

  const mappedDirectParagraphs = legacyMap.paths.flatMap((mapping) => mapping.directParagraphIDs);
  assertUnique(mappedDirectParagraphs, issues, legacyDocument.label, "directly mapped paragraphID");
  requireCondition(
    JSON.stringify(mappedDirectParagraphs) === JSON.stringify(content.paragraphs.map((paragraph) => paragraph.paragraphID)),
    issues,
    legacyDocument.label,
    "legacy map does not cover every paragraph in canonical order"
  );
  return legacyMap.paths.length;
}

function validateAudioManifest({ audioDocument, product, book, contentDocuments, issues }) {
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
  const volumeByID = new Map(
    (contentDocuments[0]?.data.volumes ?? []).map((volume) => [volume.volumeID, volume])
  );
  const fileNames = [];
  const artifactKeys = [];
  const renditionHashes = [];
  for (const artifact of audio.artifacts) {
    requireCondition(artifact.artifactID.startsWith(`${product.productID}.audio.`), issues, audioDocument.label, `artifactID outside product namespace: ${artifact.artifactID}`);
    requireCondition(artifact.rightsReference === audio.rights.rightsID, issues, audioDocument.label, `${artifact.artifactID} has an unknown rights reference`);
    requireCondition(artifact.contentMapping.bookID === book.bookID, issues, audioDocument.label, `${artifact.artifactID} maps to another book`);
    if (artifact.contentMapping.status === "mapped") {
      const volume = volumeByID.get(artifact.contentMapping.volumeID);
      requireCondition(Boolean(volume), issues, audioDocument.label, `${artifact.artifactID} maps to an unknown volume`);
      if (artifact.contentMapping.legacyVolume !== undefined && volume) {
        requireCondition(
          artifact.contentMapping.legacyVolume === volume.number,
          issues,
          audioDocument.label,
          `${artifact.artifactID} legacy volume differs from stable volume`
        );
      }
    } else {
      requireCondition(
        artifact.contentMapping.volumeID === undefined,
        issues,
        audioDocument.label,
        `${artifact.artifactID} is unmapped but declares a stable volume`
      );
    }
    localesMatch(artifact.titles, product.supportedLocales, issues, audioDocument.label);
    assertUnique(artifact.renditions.map((rendition) => rendition.renditionID), issues, audioDocument.label, `renditionID in ${artifact.artifactID}`);
    fileNames.push(...artifact.renditions.map((rendition) => rendition.fileName));
    artifactKeys.push(...artifact.renditions.map((rendition) => rendition.artifactKey));
    renditionHashes.push(...artifact.renditions.map((rendition) => rendition.sha256));

    for (const rendition of artifact.renditions) {
      requireCondition(
        rendition.fileName.endsWith(`.${rendition.fileExtension}`),
        issues,
        audioDocument.label,
        `${artifact.artifactID} filename and extension differ`
      );
      requireCondition(
        rendition.artifactKey.endsWith(
          `/${audio.catalogVersion}/${rendition.sha256}/${rendition.fileName}`
        ),
        issues,
        audioDocument.label,
        `${artifact.artifactID} artifact key is not content-addressed for this catalog`
      );
    }

    if (audio.contractState === "release-ready") {
      requireCondition(artifact.contentMapping.status === "mapped", issues, audioDocument.label, `${artifact.artifactID} lacks canonical content mapping`);
    }
  }
  assertUnique(fileNames, issues, audioDocument.label, "audio rendition filename");
  assertUnique(artifactKeys, issues, audioDocument.label, "audio rendition artifact key");
  assertUnique(renditionHashes, issues, audioDocument.label, "audio rendition SHA-256");

  if (audio.rights.reuseEligibility === "eligible") {
    requireCondition(audio.rights.status !== "legacy-unverified", issues, audioDocument.label, "unverified audio rights cannot be reusable");
  }

  return audio;
}

function validateAudioDelivery({ deliveryDocument, product, platformID, audio, issues }) {
  const delivery = deliveryDocument.data;
  const platform = product.platforms[platformID];
  requireCondition(delivery.productID === product.productID, issues, deliveryDocument.label, "productID does not match product");
  requireCondition(delivery.platform === platformID, issues, deliveryDocument.label, "platform does not match product link");
  requireCondition(delivery.state === platform.state, issues, deliveryDocument.label, "delivery state does not match product platform state");
  requireCondition(delivery.artifactManifest === product.manifests.audio, issues, deliveryDocument.label, "artifactManifest does not match product audio link");
  assertUnique(delivery.providers.map((provider) => provider.providerID), issues, deliveryDocument.label, "audio providerID");

  if (["production", "development"].includes(delivery.state)) {
    requireCondition(
      delivery.providers.some((provider) => provider.role === "primary"),
      issues,
      deliveryDocument.label,
      "active delivery has no primary provider"
    );
    requireCondition(
      delivery.releaseBlockers === undefined,
      issues,
      deliveryDocument.label,
      "active delivery still declares release blockers"
    );
  }

  if (delivery.selectedRenditionID !== null) {
    for (const artifact of audio.artifacts) {
      requireCondition(
        artifact.renditions.some(
          (rendition) => rendition.renditionID === delivery.selectedRenditionID
        ),
        issues,
        deliveryDocument.label,
        `${artifact.artifactID} lacks selected rendition ${delivery.selectedRenditionID}`
      );
    }
  }

  for (const provider of delivery.providers) {
    if (provider.kind.startsWith("apple-")) {
      requireCondition(
        platformID === "ios",
        issues,
        deliveryDocument.label,
        `${provider.providerID} is Apple-specific but linked to ${platformID}`
      );
    }
    if (provider.kind === "apple-on-demand-resources") {
      requireCondition(
        provider.minimumOSMajor <= provider.maximumOSMajor,
        issues,
        deliveryDocument.label,
        `${provider.providerID} has an invalid OS range`
      );
    }
    if (provider.kind === "https" && provider.role === "fallback") {
      requireCondition(
        provider.prefetchAllowed === false,
        issues,
        deliveryDocument.label,
        `${provider.providerID} fallback must not be used for prefetch`
      );
    }
    if (
      platformID === "android" &&
      ["production", "development"].includes(delivery.state) &&
      provider.kind === "https" &&
      provider.role === "primary"
    ) {
      requireCondition(
        provider.byteRangeSupport === "supported",
        issues,
        deliveryDocument.label,
        `${provider.providerID} Android primary must support byte ranges`
      );
    }
  }

  return delivery;
}

async function validateAudioBuildInput({
  buildDocument,
  product,
  audio,
  deliveryByPlatform,
  repositoryRoot,
  issues,
  readCache
}) {
  const build = buildDocument.data;
  requireCondition(build.productID === product.productID, issues, buildDocument.label, "productID does not match product");
  requireCondition(build.artifactManifest === product.manifests.audio, issues, buildDocument.label, "artifactManifest does not match product audio link");
  resolveContained(repositoryRoot, build.sourceDirectory, issues, buildDocument.label);

  const matchingPlatforms = build.deliveryManifest === undefined
    ? []
    : Object.entries(product.platforms)
      .filter(([, platform]) => platform.audioDelivery === build.deliveryManifest)
      .map(([platformID]) => platformID);
  if (build.deliveryManifest !== undefined) {
    requireCondition(
      matchingPlatforms.length === 1,
      issues,
      buildDocument.label,
      "deliveryManifest does not match exactly one product platform link"
    );
  }
  const selectedPlatformID = matchingPlatforms[0];
  const selectedDelivery = selectedPlatformID
    ? deliveryByPlatform.get(selectedPlatformID)
    : undefined;
  if (build.selectedRenditionID !== undefined) {
    requireCondition(
      build.selectedRenditionID === selectedDelivery?.selectedRenditionID,
      issues,
      buildDocument.label,
      "selected rendition differs from linked platform delivery"
    );
    for (const artifact of audio.artifacts) {
      requireCondition(
        artifact.renditions.some(
          (rendition) => rendition.renditionID === build.selectedRenditionID
        ),
        issues,
        buildDocument.label,
        `${artifact.artifactID} lacks build-input rendition ${build.selectedRenditionID}`
      );
    }
  }

  if (!build.legacyProjection) {
    return;
  }
  requireCondition(
    selectedPlatformID === "ios",
    issues,
    buildDocument.label,
    "legacy projection requires the iOS delivery contract"
  );
  localesMatch(build.legacyProjection.mediaIndexes, product.supportedLocales, issues, buildDocument.label);

  for (const [key, value] of Object.entries(build.legacyProjection)) {
    if (key === "mediaIndexes") {
      for (const mediaPath of Object.values(value)) {
        resolveContained(repositoryRoot, mediaPath, issues, buildDocument.label);
      }
    } else {
      resolveContained(repositoryRoot, value, issues, buildDocument.label);
    }
  }

  const projectionPath = resolveContained(
    repositoryRoot,
    build.legacyProjection.manifest,
    issues,
    buildDocument.label
  );
  const projectionDocument = projectionPath
    ? await readJSON(projectionPath, repositoryRoot, issues, readCache)
    : null;
  if (!projectionDocument) {
    return;
  }
  const projection = projectionDocument.data;
  requireCondition(projection.sourceDirectory === build.sourceDirectory, issues, projectionDocument.label, "legacy sourceDirectory differs from build input");
  requireCondition(projection.catalogVersion === audio.catalogVersion, issues, projectionDocument.label, "legacy catalogVersion differs from artifact manifest");
  requireCondition(Array.isArray(projection.tracks), issues, projectionDocument.label, "legacy delivery manifest has no tracks");
  if (!Array.isArray(projection.tracks)) {
    return;
  }

  const selected = audio.artifacts.map((artifact) => ({
    artifact,
    rendition: artifact.renditions.find(
      (rendition) => rendition.renditionID === build.selectedRenditionID
    )
  }));
  requireCondition(projection.tracks.length === selected.length, issues, buildDocument.label, "legacy delivery track count differs from artifact manifest");
  for (let index = 0; index < Math.min(projection.tracks.length, selected.length); index += 1) {
    const track = projection.tracks[index];
    const { artifact, rendition } = selected[index];
    if (!rendition) {
      continue;
    }
    requireCondition(artifact.legacyTrackID === track.id, issues, buildDocument.label, `legacy track order/ID differs at index ${index}`);
    requireCondition(rendition.fileName === `${track.id}.${projection.fileExtension}`, issues, buildDocument.label, `${artifact.artifactID} filename differs from delivery catalog`);
    requireCondition(rendition.bytes === track.bytes, issues, buildDocument.label, `${artifact.artifactID} byte count differs from delivery catalog`);
    requireCondition(rendition.sha256 === track.sha256, issues, buildDocument.label, `${artifact.artifactID} SHA-256 differs from delivery catalog`);
    requireCondition(
      rendition.artifactKey === `${projection.cdnPathPrefix}/${projection.catalogVersion}/${track.sha256}/${rendition.fileName}`,
      issues,
      buildDocument.label,
      `${artifact.artifactID} artifact key differs from delivery catalog`
    );
    for (const locale of product.supportedLocales) {
      requireCondition(
        artifact.titles[locale] === track.titles?.[locale],
        issues,
        buildDocument.label,
        `${artifact.artifactID} ${locale} title differs from delivery catalog`
      );
    }
  }
  for (const locale of product.supportedLocales) {
    requireCondition(
      audio.performers[locale] === projection.localizations?.[locale]?.artist,
      issues,
      buildDocument.label,
      `${locale} performer differs from delivery catalog`
    );
  }

  const managedProvider = selectedDelivery?.providers.find(
    (provider) => provider.kind === "apple-managed-background-assets"
  );
  if (managedProvider) {
    requireCondition(
      managedProvider.assetPackIDTemplate === `${projection.apple?.assetPackIDPrefix}{legacyTrackID}`,
      issues,
      buildDocument.label,
      "managed asset-pack template differs from delivery catalog"
    );
    requireCondition(
      managedProvider.relativePathTemplate === `${projection.apple?.relativeDirectory}/{fileName}`,
      issues,
      buildDocument.label,
      "managed relative-path template differs from delivery catalog"
    );
    requireCondition(
      managedProvider.downloadPolicy === projection.apple?.downloadPolicy,
      issues,
      buildDocument.label,
      "managed download policy differs from delivery catalog"
    );
    requireCondition(
      JSON.stringify(managedProvider.platforms) === JSON.stringify(projection.apple?.platforms),
      issues,
      buildDocument.label,
      "managed platforms differ from delivery catalog"
    );
  }
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

function uniqueInOrder(values) {
  const seen = new Set();
  return values.filter((value) => {
    if (seen.has(value)) {
      return false;
    }
    seen.add(value);
    return true;
  });
}

function localDateKey(instant, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    calendar: "gregory",
    numberingSystem: "latn",
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(new Date(instant));
  const value = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${value.year}-${value.month}-${value.day}`;
}

function fnv1a64(value) {
  let hash = 14_695_981_039_346_656_037n;
  for (const byte of Buffer.from(value, "utf8")) {
    hash ^= BigInt(byte);
    hash = BigInt.asUintN(64, hash * 1_099_511_628_211n);
  }
  return hash;
}

function expectedDailyVerseSelection(input) {
  const localDate = localDateKey(input.instant, input.timeZone);
  const uniqueCandidates = uniqueInOrder(input.candidateIDs.filter(Boolean));
  const filtered = uniqueCandidates.filter((candidate) => candidate !== input.excludedID);
  const eligible = filtered.length > 0 ? filtered : uniqueCandidates;
  const dayNumber = Math.floor(Date.parse(`${localDate}T00:00:00Z`) / 86_400_000);
  const dayIndex = ((dayNumber % eligible.length) + eligible.length) % eligible.length;
  const offset = Number(
    fnv1a64(`${input.productID}\0${input.contentVersion}`) % BigInt(eligible.length)
  );
  return {
    localDate,
    selectedID: eligible[(dayIndex + offset) % eligible.length]
  };
}

function expectedReadingResume(input) {
  if (input.mode === "chapter") {
    if (!Number.isInteger(input.chapter) || input.chapter < 0 || input.chapter >= 10) {
      return { target: null };
    }
    const offset = Number.isFinite(input.chapterOffset) && input.chapterOffset > 0
      ? input.chapterOffset
      : 0;
    return {
      target: {
        mode: "chapter",
        chapter: input.chapter,
        chapterOffset: offset
      }
    };
  }
  if (!input.path || input.path === "/") {
    return { target: null };
  }
  if (input.mode === "paged") {
    return {
      target: {
        mode: "paged",
        path: input.path,
        pageIndex: Math.max(input.pageIndex ?? 0, 0)
      }
    };
  }
  return { target: { mode: "tree", path: input.path } };
}

function expectedLegacyFavorites(input) {
  const source = input.storedUserLikes ?? input.legacyLikes.filter(
    (path) => !input.curatedLegacyPaths.includes(path)
  );
  return { userLikes: uniqueInOrder(source) };
}

function expectedLegacyLocation(input, legacyLocationsByProduct) {
  if (!input.legacyPath || input.legacyPath === "/") {
    return { status: "invalid", sectionID: null, paragraphID: null };
  }
  const location = legacyLocationsByProduct.get(input.productID)?.get(input.legacyPath);
  if (!location) {
    return { status: "unresolved", sectionID: null, paragraphID: null };
  }
  return {
    status: "mapped",
    sectionID: location.sectionID,
    paragraphID: location.directParagraphIDs[0] ?? location.firstDescendantParagraphID ?? null
  };
}

function validateSearchFixtureCase(entry, issues, label) {
  const { input, expected } = entry;
  const hasResult = typeof expected.resultPath === "string"
    && typeof expected.snippet === "string";
  requireCondition(
    expected.matches === hasResult,
    issues,
    label,
    `${entry.name} search match/result fields disagree`
  );
  if (expected.matches) {
    if (!hasResult) {
      return;
    }
    requireCondition(
      expected.resultPath === input.path,
      issues,
      label,
      `${entry.name} search result path differs from its source path`
    );
    requireCondition(
      expected.normalizedQuery.length > 0 && expected.normalizedText.includes(expected.normalizedQuery),
      issues,
      label,
      `${entry.name} normalized search strings do not contain the match`
    );
    requireCondition(
      !expected.snippet.includes("\n") && expected.snippet.length <= input.maxLength + 3,
      issues,
      label,
      `${entry.name} search snippet is not display-safe`
    );
  } else {
    requireCondition(
      expected.resultPath === null && expected.snippet === null,
      issues,
      label,
      `${entry.name} nonmatching search case still has a result`
    );
    requireCondition(
      expected.normalizedQuery.length > 0
        && !expected.normalizedText.includes(expected.normalizedQuery),
      issues,
      label,
      `${entry.name} is marked nonmatching but normalized text contains the query`
    );
  }
}

function validateBehaviorFixture(document, issues, { legacyLocationsByProduct }) {
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
      case "search-text":
        validateSearchFixtureCase(entry, issues, document.label);
        continue;
      case "daily-verse-selection":
        try {
          expected = expectedDailyVerseSelection(entry.input);
        } catch (error) {
          addIssue(
            issues,
            document.label,
            `${entry.name} cannot evaluate date/time zone (${error.message})`
          );
          continue;
        }
        break;
      case "reading-resume":
        expected = expectedReadingResume(entry.input);
        break;
      case "legacy-favorites-migration":
        expected = expectedLegacyFavorites(entry.input);
        break;
      case "legacy-location-resolution":
        expected = expectedLegacyLocation(entry.input, legacyLocationsByProduct);
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
  let audioDeliveryCount = 0;
  let audioBuildInputCount = 0;
  let legacyPathMappingCount = 0;
  const legacyLocationsByProduct = new Map();

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
    requireCondition(
      !product.manifests.audioBuild || product.manifests.audio,
      issues,
      productDocument.label,
      "audio build input requires an audio artifact manifest"
    );
    for (const [platformID, platform] of Object.entries(product.platforms)) {
      requireCondition(
        !platform.audioDelivery || product.features.audio,
        issues,
        productDocument.label,
        `${platformID} audio delivery requires the audio capability`
      );
      if (
        product.features.audio &&
        ["production", "development"].includes(product.lifecycle) &&
        ["production", "development"].includes(platform.state)
      ) {
        requireCondition(
          Boolean(platform.audioDelivery),
          issues,
          productDocument.label,
          `${platformID} active audio product has no delivery manifest`
        );
      }
    }
    if (["production", "development"].includes(product.lifecycle)) {
      requireCondition(
        product.features.audio === Boolean(product.manifests.audio),
        issues,
        productDocument.label,
        "audio feature and audio manifest link must agree"
      );
      if (product.features.audio) {
        requireCondition(
          Boolean(product.manifests.audioBuild),
          issues,
          productDocument.label,
          "active audio product has no reproducible build input"
        );
      }
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
    }
    if (book.contentPackages) {
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
    const contentDocuments = [];
    for (const [locale, contentLink] of Object.entries(book.contentPackages ?? {})) {
      const contentPath = resolveContained(productDirectory, contentLink, issues, bookDocument.label);
      const contentDocument = contentPath ? await readJSON(contentPath, root, issues, readCache) : null;
      if (validateWithSchema(ajv, schemaIDs.content, contentDocument, issues)) {
        contentDocuments.push(contentDocument);
        contentStructures.push(
          validateContentPackageSemantics({ contentDocument, book, source, locale, issues })
        );
        contentPackageCount += 1;
      }
    }
    let productLegacyPathCount = 0;
    if (book.legacyCompatibility?.mappingArtifact) {
      const legacyMapPath = resolveContained(
        productDirectory,
        book.legacyCompatibility.mappingArtifact,
        issues,
        bookDocument.label
      );
      const legacyDocument = legacyMapPath
        ? await readJSON(legacyMapPath, root, issues, readCache)
        : null;
      if (validateWithSchema(ajv, schemaIDs.legacyMap, legacyDocument, issues)) {
        legacyLocationsByProduct.set(
          product.productID,
          new Map(legacyDocument.data.paths.map((entry) => [entry.legacyPath, entry]))
        );
        productLegacyPathCount = validateLegacyMapSemantics({
          legacyDocument,
          book,
          contentDocuments,
          issues
        });
        legacyPathMappingCount += productLegacyPathCount;
      }
    }
    if (contentStructures.length > 1) {
      const reference = JSON.stringify(contentStructures[0]);
      for (const structure of contentStructures.slice(1)) {
        requireCondition(JSON.stringify(structure) === reference, issues, bookDocument.label, "localized content packages have different stable structure");
      }
    }

    let productAudioCount = 0;
    let audio = null;
    if (product.manifests.audio) {
      const audioPath = resolveContained(productDirectory, product.manifests.audio, issues, productDocument.label);
      const audioDocument = audioPath ? await readJSON(audioPath, root, issues, readCache) : null;
      if (validateWithSchema(ajv, schemaIDs.audio, audioDocument, issues)) {
        audio = validateAudioManifest({
          audioDocument,
          product,
          book,
          contentDocuments,
          issues
        });
        productAudioCount = audioDocument.data.artifacts.length;
        audioArtifactCount += productAudioCount;
      }
    }

    const deliveryByPlatform = new Map();
    for (const [platformID, platform] of Object.entries(product.platforms)) {
      if (!platform.audioDelivery) {
        continue;
      }
      const deliveryPath = resolveContained(
        productDirectory,
        platform.audioDelivery,
        issues,
        productDocument.label
      );
      const deliveryDocument = deliveryPath
        ? await readJSON(deliveryPath, root, issues, readCache)
        : null;
      if (validateWithSchema(ajv, schemaIDs.audioDelivery, deliveryDocument, issues)) {
        if (audio) {
          const delivery = validateAudioDelivery({
            deliveryDocument,
            product,
            platformID,
            audio,
            issues
          });
          deliveryByPlatform.set(platformID, delivery);
        }
        audioDeliveryCount += 1;
      }
    }

    if (product.manifests.audioBuild) {
      const buildPath = resolveContained(
        productDirectory,
        product.manifests.audioBuild,
        issues,
        productDocument.label
      );
      const buildDocument = buildPath
        ? await readJSON(buildPath, root, issues, readCache)
        : null;
      if (validateWithSchema(ajv, schemaIDs.audioBuildInput, buildDocument, issues)) {
        if (audio) {
          await validateAudioBuildInput({
            buildDocument,
            product,
            audio,
            deliveryByPlatform,
            repositoryRoot: root,
            issues,
            readCache
          });
        }
        audioBuildInputCount += 1;
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
      audioArtifacts: productAudioCount,
      legacyPaths: productLegacyPathCount
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
      validateBehaviorFixture(fixtureDocument, issues, { legacyLocationsByProduct });
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
    audioDeliveryCount,
    audioBuildInputCount,
    legacyPathMappingCount,
    fixtureCount: fixtureIDs.length,
    warnings
  };
}

function printReport(report) {
  const audioBuildLabel = report.audioBuildInputCount === 1
    ? "audio build-input manifest"
    : "audio build-input manifests";
  console.log(
    `Validated ${report.productCount} products, ${report.contentPackageCount} structured content packages, ` +
      `${report.audioArtifactCount} audio artifacts, ${report.audioDeliveryCount} delivery manifests, ` +
      `${report.audioBuildInputCount} ${audioBuildLabel}, ${report.legacyPathMappingCount} legacy path mappings, ` +
      `and ${report.fixtureCount} behavior fixtures.`
  );
  for (const product of report.products) {
    console.log(
      `- ${product.productID}: ${product.contractState}, source ${product.releaseEligibility}, ` +
        `${product.audioArtifacts} audio artifacts, ${product.legacyPaths} legacy paths`
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
