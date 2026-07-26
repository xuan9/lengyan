import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { buildLengyanMigrationArtifacts } from "../../../scripts/generate-lengyan-content.mjs";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(testDirectory, "../../..");

async function readJSON(relativePath) {
  return JSON.parse(await readFile(join(repositoryRoot, relativePath), "utf8"));
}

test("Lengyan migration assigns complete stable identity without changing visible text", async () => {
  const { outputs, report } = await buildLengyanMigrationArtifacts();
  const traditional = JSON.parse(outputs.get("Products/lengyan/Content/content-zh-Hant.json"));
  const simplified = JSON.parse(outputs.get("Products/lengyan/Content/content-zh-Hans.json"));
  const legacyMap = JSON.parse(outputs.get("Products/lengyan/Content/legacy-path-map.json"));
  const legacyTraditional = await readJSON("lengyan/data/lengyanjing-content.json");
  const legacySimplified = await readJSON("lengyan/data/simplified/lengyanjing-content.json");

  assert.equal(report.sections, 1669);
  assert.equal(report.leafSections, 1155);
  assert.equal(report.paragraphs, 1262);
  assert.equal(report.mappedVolumePaths, 1155);
  assert.equal(report.boundedVolumeAssignments.length, 22);
  assert.equal(report.unresolvedVolumePaths.length, 0);
  assert.deepEqual(
    report.boundedVolumeAssignments.reduce((counts, assignment) => {
      counts[assignment.assignedVolume] = (counts[assignment.assignedVolume] ?? 0) + 1;
      return counts;
    }, {}),
    { 4: 1, 6: 2, 8: 10, 9: 9 }
  );
  assert.equal(
    report.boundedVolumeAssignments.filter(
      (assignment) => assignment.legacyVolumeHint !== assignment.assignedVolume
    ).length,
    21
  );
  assert.equal(report.traditionalCRLFReplacements, 288);
  assert.equal(report.simplifiedCRLFReplacements, 288);
  assert.equal(report.traditionalContentHash, "1b2fe086bc8cc0a7a577e59cf2c721d83e3fbf14d55fc0ef0cf9f1d4923c948a");
  assert.equal(report.simplifiedContentHash, "294c679ba78c2f3b389ae987dde1575372c93baeab540a9f3e221f4742789c21");
  assert.equal(report.legacyMappingHash, "3f8b7c959ff28f0636fbe84811127db7ccecfba75ee812cc8baf4c79edb9cd0f");

  assert.deepEqual(
    traditional.sections.map((section) => section.sectionID),
    simplified.sections.map((section) => section.sectionID)
  );
  assert.deepEqual(
    traditional.paragraphs.map((paragraph) => paragraph.paragraphID),
    simplified.paragraphs.map((paragraph) => paragraph.paragraphID)
  );
  assert.equal(legacyMap.paths.length, traditional.sections.length);

  const traditionalByID = new Map(
    traditional.paragraphs.map((paragraph) => [paragraph.paragraphID, paragraph])
  );
  const simplifiedByID = new Map(
    simplified.paragraphs.map((paragraph) => [paragraph.paragraphID, paragraph])
  );
  for (const mapping of legacyMap.paths) {
    const traditionalEntries = legacyTraditional[mapping.legacyPath] ?? [];
    const simplifiedEntries = legacySimplified[mapping.legacyPath] ?? [];
    assert.equal(mapping.directParagraphIDs.length, traditionalEntries.length);
    assert.equal(mapping.directParagraphIDs.length, simplifiedEntries.length);
    for (let index = 0; index < mapping.directParagraphIDs.length; index += 1) {
      const paragraphID = mapping.directParagraphIDs[index];
      assert.equal(
        traditionalByID.get(paragraphID).text,
        traditionalEntries[index].content.replace(/\r\n/gu, "\n")
      );
      assert.equal(
        simplifiedByID.get(paragraphID).text,
        simplifiedEntries[index].content.replace(/\r\n/gu, "\n")
      );
    }
  }

  assert.ok(traditional.paragraphs.every((paragraph) => !paragraph.text.includes("\r")));
  assert.ok(simplified.paragraphs.every((paragraph) => !paragraph.text.includes("\r")));
  assert.equal(
    traditional.paragraphs.filter((paragraph) => paragraph.volumeID === null).length,
    0
  );
  assert.equal(
    simplified.paragraphs.filter((paragraph) => paragraph.volumeID === null).length,
    0
  );
});

test("checked-in Lengyan migration files are byte-for-byte generated output", async () => {
  const { outputs } = await buildLengyanMigrationArtifacts();
  for (const [relativePath, expected] of outputs) {
    assert.equal(await readFile(join(repositoryRoot, relativePath), "utf8"), expected);
  }
});
