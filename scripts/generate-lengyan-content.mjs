#!/usr/bin/env node

import { isDeepStrictEqual } from "node:util";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  contentHashForPackage,
  mappingHashForLegacyMap
} from "../tools/content-validator/canonical-json.mjs";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(scriptDirectory, "..");
const productDirectory = join(repositoryRoot, "Products", "lengyan");
const contentDirectory = join(productDirectory, "Content");
const legacySourceID = "lengyan.source.legacy-repository-json";

const inputPaths = {
  chapterMap: "lengyan/data/lengyanjing-chapter-map.json",
  traditionalContent: "lengyan/data/lengyanjing-content.json",
  traditionalTree: "lengyan/data/lengyanjing-index-tree.json",
  traditionalIndex: "lengyan/data/lengyanjing-index.json",
  traditionalMedia: "lengyan/data/lengyanjing-media.json",
  simplifiedEnhancedContent: "lengyan/data/simplified/enhanced-lengyanjing-content.json",
  simplifiedContent: "lengyan/data/simplified/lengyanjing-content.json",
  simplifiedTree: "lengyan/data/simplified/lengyanjing-index-tree.json",
  simplifiedIndex: "lengyan/data/simplified/lengyanjing-index.json",
  simplifiedMedia: "lengyan/data/simplified/lengyanjing-media.json"
};

const outputPaths = {
  traditionalContent: "Products/lengyan/Content/content-zh-Hant.json",
  simplifiedContent: "Products/lengyan/Content/content-zh-Hans.json",
  legacyMap: "Products/lengyan/Content/legacy-path-map.json"
};

function invariant(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function readJSON(relativePath) {
  const raw = await readFile(join(repositoryRoot, relativePath), "utf8");
  return JSON.parse(raw);
}

function stableSectionID(index) {
  return `lengyan.s${String(index + 1).padStart(6, "0")}`;
}

function stableParagraphID(index) {
  return `lengyan.p${String(index + 1).padStart(6, "0")}`;
}

function stableVolumeID(number) {
  return `lengyan.v${String(number).padStart(6, "0")}`;
}

function flattenTree(root, label) {
  const records = [];
  const paths = new Set();

  function visit(node, parentRecord, order) {
    invariant(isObject(node), `${label}: tree node must be an object`);
    invariant(typeof node.id === "string" && node.id.length > 0, `${label}: node id is missing`);
    invariant(typeof node.name === "string" && node.name.length > 0, `${label}: ${node.id} name is missing`);
    invariant(typeof node.path === "string", `${label}: ${node.id} path is missing`);

    const expectedPath = parentRecord ? `${parentRecord.path}/${node.id}` : "";
    invariant(node.path === expectedPath, `${label}: expected ${expectedPath || "<root>"}, found ${node.path}`);
    invariant(!paths.has(node.path), `${label}: duplicate path ${node.path || "<root>"}`);
    paths.add(node.path);

    const children = node.children ?? [];
    invariant(Array.isArray(children), `${label}: ${node.path || "<root>"} children must be an array`);
    const record = {
      index: records.length,
      sectionID: stableSectionID(records.length),
      id: node.id,
      name: node.name,
      title: node.title,
      path: node.path,
      parentPath: parentRecord?.path ?? null,
      parentSectionID: parentRecord?.sectionID ?? null,
      order,
      isLeaf: children.length === 0,
      childPaths: children.map((child) => child.path)
    };
    records.push(record);
    children.forEach((child, childOrder) => visit(child, record, childOrder));
  }

  visit(root, null, 0);
  return records;
}

function validateLocalizedTreeStructure(traditional, simplified) {
  invariant(traditional.length === simplified.length, "traditional and simplified trees have different node counts");
  for (let index = 0; index < traditional.length; index += 1) {
    const left = traditional[index];
    const right = simplified[index];
    for (const key of ["id", "path", "parentPath", "order", "isLeaf"]) {
      invariant(left[key] === right[key], `tree structure differs at ${left.path || "<root>"}: ${key}`);
    }
    invariant(
      isDeepStrictEqual(left.childPaths, right.childPaths),
      `tree child order differs at ${left.path || "<root>"}`
    );
  }
}

function validateFlatIndex(records, index, label) {
  invariant(Array.isArray(index), `${label}: flat index must be an array`);
  invariant(index.length === records.length, `${label}: flat index node count differs from tree`);
  for (let position = 0; position < records.length; position += 1) {
    const record = records[position];
    const item = index[position];
    invariant(isObject(item), `${label}: index ${position} must be an object`);
    invariant(item.id === record.id, `${label}: index id differs at ${position}`);
    invariant(item.name === record.name, `${label}: index name differs at ${record.path || "<root>"}`);
    invariant(item.path === record.path, `${label}: index path differs at ${position}`);
    invariant(item.title === record.title, `${label}: index title differs at ${record.path || "<root>"}`);
  }
}

function validateMedia(media, label) {
  invariant(Array.isArray(media) && media.length === 1, `${label}: expected one media catalog`);
  const catalog = media[0];
  invariant(isObject(catalog), `${label}: media catalog must be an object`);
  invariant(Array.isArray(catalog.files) && catalog.files.length === 11, `${label}: expected 11 media files`);
  invariant(Array.isArray(catalog.names) && catalog.names.length === 11, `${label}: expected 11 media names`);
  invariant(catalog.extension === "m4a", `${label}: unexpected media extension`);
  return catalog;
}

function validateChapterMap(chapterMap, pathSet) {
  invariant(isObject(chapterMap), "chapter map must be an object");
  invariant(
    isDeepStrictEqual(Object.keys(chapterMap).sort(), ["1", "10", "2", "3", "4", "5", "6", "7", "8", "9"]),
    "chapter map must contain exactly volumes 1 through 10"
  );

  const roots = [];
  const seenPaths = new Set();
  for (let number = 1; number <= 10; number += 1) {
    const paths = chapterMap[String(number)];
    invariant(Array.isArray(paths) && paths.length > 0, `volume ${number} has no chapter roots`);
    for (const path of paths) {
      invariant(pathSet.has(path), `volume ${number} references unknown path ${path}`);
      invariant(!seenPaths.has(path), `chapter root appears more than once: ${path}`);
      seenPaths.add(path);
      roots.push({ number, path });
    }
  }
  return roots;
}

function mappedVolumeForPath(path, chapterRoots) {
  const matches = chapterRoots.filter((root) => path === root.path || path.startsWith(`${root.path}/`));
  invariant(matches.length <= 1, `path belongs to multiple volumes: ${path}`);
  return matches[0]?.number ?? null;
}

function sourceReference(relativePath, locator) {
  return {
    sourceID: legacySourceID,
    locator: `${relativePath}#${locator}`
  };
}

function sectionSourceReference(treePath, legacyPath) {
  return sourceReference(treePath, `outline-path=${encodeURIComponent(legacyPath || "ROOT")}`);
}

function paragraphSourceReference(contentPath, legacyPath, entryIndex) {
  return sourceReference(
    contentPath,
    `outline-path=${encodeURIComponent(legacyPath)}&entry=${entryIndex}`
  );
}

function normalizeLegacyLineEndings(text, label) {
  const replacements = text.match(/\r\n/gu)?.length ?? 0;
  const normalized = text.replace(/\r\n/gu, "\n");
  invariant(!normalized.includes("\r"), `${label}: unsupported bare CR in legacy text`);
  return { text: normalized, replacements };
}

function buildSections(records, treePath) {
  return records.map((record) => ({
    sectionID: record.sectionID,
    parentSectionID: record.parentSectionID,
    order: record.order,
    title: record.name,
    ...(record.title ? { subtitle: record.title } : {}),
    sourceReferences: [sectionSourceReference(treePath, record.path)],
    legacyIDs: [record.path || "ROOT"]
  }));
}

function buildVolumes(mediaCatalog, mediaPath, chapterMapPath) {
  return Array.from({ length: 10 }, (_, index) => {
    const number = index + 1;
    return {
      volumeID: stableVolumeID(number),
      number,
      order: index,
      title: mediaCatalog.names[index],
      sourceReferences: [
        sourceReference(chapterMapPath, `volume=${number}`),
        sourceReference(mediaPath, `name-index=${index}`)
      ]
    };
  });
}

function serializeJSON(value) {
  return `${JSON.stringify(value, null, 2)}\n`;
}

export async function buildLengyanMigrationArtifacts() {
  const inputs = {};
  for (const [key, path] of Object.entries(inputPaths)) {
    inputs[key] = await readJSON(path);
  }

  const traditionalRecords = flattenTree(inputs.traditionalTree, "traditional tree");
  const simplifiedRecords = flattenTree(inputs.simplifiedTree, "simplified tree");
  validateLocalizedTreeStructure(traditionalRecords, simplifiedRecords);
  validateFlatIndex(traditionalRecords, inputs.traditionalIndex, "traditional index");
  validateFlatIndex(simplifiedRecords, inputs.simplifiedIndex, "simplified index");

  const leafRecords = traditionalRecords.filter((record) => record.isLeaf);
  const leafPaths = new Set(leafRecords.map((record) => record.path));
  const traditionalContentPaths = Object.keys(inputs.traditionalContent);
  const simplifiedContentPaths = Object.keys(inputs.simplifiedContent);
  const enhancedContentPaths = Object.keys(inputs.simplifiedEnhancedContent);
  const expectedContentPaths = [...leafPaths].sort();
  invariant(
    isDeepStrictEqual([...traditionalContentPaths].sort(), expectedContentPaths),
    "traditional content paths do not exactly match tree leaves"
  );
  invariant(
    isDeepStrictEqual([...simplifiedContentPaths].sort(), expectedContentPaths),
    "simplified content paths do not exactly match tree leaves"
  );
  invariant(
    isDeepStrictEqual([...enhancedContentPaths].sort(), expectedContentPaths),
    "enhanced content paths do not exactly match tree leaves"
  );

  const chapterRoots = validateChapterMap(
    inputs.chapterMap,
    new Set(traditionalRecords.map((record) => record.path))
  );
  const traditionalMedia = validateMedia(inputs.traditionalMedia, "traditional media");
  const simplifiedMedia = validateMedia(inputs.simplifiedMedia, "simplified media");
  invariant(
    isDeepStrictEqual(traditionalMedia.files, simplifiedMedia.files),
    "traditional and simplified media file IDs differ"
  );

  const paragraphIDsByPath = new Map();
  const traditionalParagraphs = [];
  const simplifiedParagraphs = [];
  const unresolvedVolumePaths = [];
  let traditionalCRLFReplacements = 0;
  let simplifiedCRLFReplacements = 0;

  for (const leaf of leafRecords) {
    const traditionalEntries = inputs.traditionalContent[leaf.path];
    const simplifiedEntries = inputs.simplifiedContent[leaf.path];
    const enhancedEntry = inputs.simplifiedEnhancedContent[leaf.path];
    invariant(Array.isArray(traditionalEntries) && traditionalEntries.length > 0, `${leaf.path}: traditional content is empty`);
    invariant(Array.isArray(simplifiedEntries), `${leaf.path}: simplified content is not an array`);
    invariant(isObject(enhancedEntry), `${leaf.path}: enhanced content record is missing`);
    invariant(isDeepStrictEqual(enhancedEntry.content, simplifiedEntries), `${leaf.path}: enhanced/simple content differs`);
    invariant(Number.isInteger(enhancedEntry.chapter) && enhancedEntry.chapter >= 1 && enhancedEntry.chapter <= 10, `${leaf.path}: invalid enhanced chapter hint`);
    invariant(traditionalEntries.length === simplifiedEntries.length, `${leaf.path}: locale entry counts differ`);

    const mappedVolume = mappedVolumeForPath(leaf.path, chapterRoots);
    if (mappedVolume === null) {
      unresolvedVolumePaths.push({
        legacyPath: leaf.path,
        legacyVolumeHint: enhancedEntry.chapter
      });
    } else {
      invariant(
        mappedVolume === enhancedEntry.chapter,
        `${leaf.path}: chapter map ${mappedVolume} differs from enhanced hint ${enhancedEntry.chapter}`
      );
    }

    const directParagraphIDs = [];
    for (let entryIndex = 0; entryIndex < traditionalEntries.length; entryIndex += 1) {
      const traditionalEntry = traditionalEntries[entryIndex];
      const simplifiedEntry = simplifiedEntries[entryIndex];
      invariant(isObject(traditionalEntry) && isObject(simplifiedEntry), `${leaf.path}: paragraph entry must be an object`);
      invariant(typeof traditionalEntry.type === "string" && traditionalEntry.type.length > 0, `${leaf.path}: paragraph type is missing`);
      invariant(traditionalEntry.type === simplifiedEntry.type, `${leaf.path}: locale paragraph types differ`);
      invariant(typeof traditionalEntry.content === "string" && traditionalEntry.content.length > 0, `${leaf.path}: traditional paragraph text is empty`);
      invariant(typeof simplifiedEntry.content === "string" && simplifiedEntry.content.length > 0, `${leaf.path}: simplified paragraph text is empty`);

      const normalizedTraditional = normalizeLegacyLineEndings(
        traditionalEntry.content,
        `${leaf.path} traditional entry ${entryIndex}`
      );
      const normalizedSimplified = normalizeLegacyLineEndings(
        simplifiedEntry.content,
        `${leaf.path} simplified entry ${entryIndex}`
      );
      traditionalCRLFReplacements += normalizedTraditional.replacements;
      simplifiedCRLFReplacements += normalizedSimplified.replacements;

      const paragraphID = stableParagraphID(traditionalParagraphs.length);
      directParagraphIDs.push(paragraphID);
      const shared = {
        paragraphID,
        sectionID: leaf.sectionID,
        volumeID: mappedVolume === null ? null : stableVolumeID(mappedVolume),
        order: entryIndex,
        textRole: traditionalEntry.type,
        legacyVolumeHint: enhancedEntry.chapter
      };
      traditionalParagraphs.push({
        ...shared,
        text: normalizedTraditional.text,
        sourceReferences: [
          paragraphSourceReference(inputPaths.traditionalContent, leaf.path, entryIndex)
        ]
      });
      simplifiedParagraphs.push({
        ...shared,
        text: normalizedSimplified.text,
        sourceReferences: [
          paragraphSourceReference(inputPaths.simplifiedContent, leaf.path, entryIndex)
        ]
      });
    }
    paragraphIDsByPath.set(leaf.path, directParagraphIDs);
  }

  const descendantsByPath = new Map(
    traditionalRecords.map((record) => [record.path, [...(paragraphIDsByPath.get(record.path) ?? [])]])
  );
  for (const record of [...traditionalRecords].reverse()) {
    if (record.parentPath !== null) {
      descendantsByPath.get(record.parentPath).unshift(...descendantsByPath.get(record.path));
    }
  }

  const legacyMap = {
    schemaVersion: 1,
    productID: "lengyan",
    bookID: "lengyanjing",
    editionID: "legacy-repository-v1",
    mappingVersion: "legacy-1",
    stableIDScheme: "fuxuan-classics-v1",
    normalization: "utf8-nfc-lf-v1",
    mappingHash: "0".repeat(64),
    paths: traditionalRecords.map((record) => {
      const descendants = descendantsByPath.get(record.path);
      return {
        legacyPath: record.path,
        legacyNodeID: record.id,
        parentLegacyPath: record.parentPath,
        sectionID: record.sectionID,
        order: record.order,
        directParagraphIDs: paragraphIDsByPath.get(record.path) ?? [],
        firstDescendantParagraphID: descendants[0] ?? null,
        descendantParagraphCount: descendants.length
      };
    })
  };
  legacyMap.mappingHash = mappingHashForLegacyMap(legacyMap);

  const commonPackage = {
    schemaVersion: 1,
    productID: "lengyan",
    bookID: "lengyanjing",
    editionID: "legacy-repository-v1",
    contentVersion: "legacy-1",
    contentStatus: "legacy-migration",
    normalization: "utf8-nfc-lf-v1"
  };
  const traditionalPackage = {
    ...commonPackage,
    locale: "zh-Hant",
    contentHash: "0".repeat(64),
    volumes: buildVolumes(
      traditionalMedia,
      inputPaths.traditionalMedia,
      inputPaths.chapterMap
    ),
    sections: buildSections(traditionalRecords, inputPaths.traditionalTree),
    paragraphs: traditionalParagraphs
  };
  traditionalPackage.contentHash = contentHashForPackage(traditionalPackage);

  const simplifiedPackage = {
    ...commonPackage,
    locale: "zh-Hans",
    contentHash: "0".repeat(64),
    volumes: buildVolumes(
      simplifiedMedia,
      inputPaths.simplifiedMedia,
      inputPaths.chapterMap
    ),
    sections: buildSections(simplifiedRecords, inputPaths.simplifiedTree),
    paragraphs: simplifiedParagraphs
  };
  simplifiedPackage.contentHash = contentHashForPackage(simplifiedPackage);

  const outputs = new Map([
    [outputPaths.traditionalContent, serializeJSON(traditionalPackage)],
    [outputPaths.simplifiedContent, serializeJSON(simplifiedPackage)],
    [outputPaths.legacyMap, serializeJSON(legacyMap)]
  ]);
  return {
    outputs,
    report: {
      sections: traditionalRecords.length,
      leafSections: leafRecords.length,
      paragraphs: traditionalParagraphs.length,
      mappedVolumePaths: leafRecords.length - unresolvedVolumePaths.length,
      unresolvedVolumePaths,
      traditionalCRLFReplacements,
      simplifiedCRLFReplacements,
      traditionalContentHash: traditionalPackage.contentHash,
      simplifiedContentHash: simplifiedPackage.contentHash,
      legacyMappingHash: legacyMap.mappingHash
    }
  };
}

async function writeArtifacts(outputs) {
  await mkdir(contentDirectory, { recursive: true });
  for (const [relativePath, raw] of outputs) {
    await writeFile(join(repositoryRoot, relativePath), raw, "utf8");
    console.log(`Wrote ${relativePath}`);
  }
}

async function checkArtifacts(outputs) {
  const mismatches = [];
  for (const [relativePath, expected] of outputs) {
    try {
      const actual = await readFile(join(repositoryRoot, relativePath), "utf8");
      if (actual !== expected) {
        mismatches.push(`${relativePath} differs from generated output`);
      }
    } catch (error) {
      mismatches.push(`${relativePath} cannot be read (${error.code ?? error.message})`);
    }
  }
  if (mismatches.length > 0) {
    throw new Error(mismatches.join("\n"));
  }
  console.log(`Lengyan migration content and ${outputs.size} generated files are consistent.`);
}

async function main() {
  const argumentsSet = new Set(process.argv.slice(2));
  const allowedArguments = new Set(["--check"]);
  for (const argument of argumentsSet) {
    invariant(allowedArguments.has(argument), `unknown argument: ${argument}`);
  }
  const { outputs, report } = await buildLengyanMigrationArtifacts();
  if (argumentsSet.has("--check")) {
    await checkArtifacts(outputs);
  } else {
    await writeArtifacts(outputs);
  }
  console.log(
    `Mapped ${report.sections} sections and ${report.paragraphs} paragraphs; ` +
      `${report.unresolvedVolumePaths.length} legacy paths retain unresolved volume mapping.`
  );
  console.log(
    `Normalized CRLF to LF ${report.traditionalCRLFReplacements} times in zh-Hant and ` +
      `${report.simplifiedCRLFReplacements} times in zh-Hans.`
  );
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    await main();
  } catch (error) {
    console.error(error.stack ?? error.message);
    process.exitCode = 1;
  }
}
