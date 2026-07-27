import assert from "node:assert/strict";
import { cp, mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  ContractValidationError,
  contentHashForPackage,
  validateRepository
} from "../validate.mjs";
import { mappingHashForLegacyMap } from "../canonical-json.mjs";

const testDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(testDirectory, "../../..");

async function copyFilePreservingPath(sourceRoot, targetRoot, relativePath) {
  const target = join(targetRoot, relativePath);
  await mkdir(dirname(target), { recursive: true });
  await cp(join(sourceRoot, relativePath), target);
}

async function makeFixtureRepository() {
  const targetRoot = await mkdtemp(join(tmpdir(), "classic-content-validator-"));
  await cp(join(repositoryRoot, "Contracts"), join(targetRoot, "Contracts"), { recursive: true });
  await cp(join(repositoryRoot, "Products"), join(targetRoot, "Products"), { recursive: true });
  await copyFilePreservingPath(repositoryRoot, targetRoot, "AudioAssets/audio-manifest.json");

  const legacyArtifacts = [
    "lengyan/data/lengyanjing-chapter-map.json",
    "lengyan/data/lengyanjing-content.json",
    "lengyan/data/lengyanjing-index-tree.json",
    "lengyan/data/lengyanjing-index.json",
    "lengyan/data/lengyanjing-media.json",
    "lengyan/data/simplified/enhanced-lengyanjing-content.json",
    "lengyan/data/simplified/lengyanjing-content.json",
    "lengyan/data/simplified/lengyanjing-index-tree.json",
    "lengyan/data/simplified/lengyanjing-index.json",
    "lengyan/data/simplified/lengyanjing-media.json"
  ];
  for (const relativePath of legacyArtifacts) {
    await copyFilePreservingPath(repositoryRoot, targetRoot, relativePath);
  }
  return targetRoot;
}

async function mutateJSON(root, relativePath, mutation) {
  const path = join(root, relativePath);
  const data = JSON.parse(await readFile(path, "utf8"));
  mutation(data);
  await writeFile(path, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

async function expectValidationIssue(root, expectedText) {
  await assert.rejects(
    validateRepository({ repositoryRoot: root }),
    (error) => {
      assert.ok(error instanceof ContractValidationError);
      assert.ok(
        error.issues.some((issue) => issue.includes(expectedText)),
        `expected an issue containing ${JSON.stringify(expectedText)}; got:\n${error.issues.join("\n")}`
      );
      return true;
    }
  );
}

async function configureCanonicalJingang(root) {
  await mutateJSON(root, "Products/jingang/product.json", (product) => {
    product.lifecycle = "development";
    product.features.audio = false;
    product.features.dailyVerse = false;
  });
  await mutateJSON(root, "Products/jingang/book-manifest.json", (book) => {
    book.contractState = "canonical-ready";
    book.contentVersion = "test-1";
    book.contentPackages = {
      "zh-Hant": "Content/content-zh-Hant.json",
      "zh-Hans": "Content/content-zh-Hans.json"
    };
  });
  await mutateJSON(root, "Products/jingang/source-manifest.json", (source) => {
    source.reviewStatus = "approved";
    source.releaseEligibility = "eligible";
    for (const approval of Object.values(source.approvals)) {
      approval.status = "approved";
      approval.reviewedBy = "test-reviewer";
      approval.reviewedAt = "2026-07-26T00:00:00Z";
    }
    source.sources.push({
      sourceID: "jingang.source.public-domain-scan",
      role: "transcription-base",
      format: "scan-images",
      title: "Test-only public-domain scan",
      canonicalIdentifier: "test-fixture-scan-1",
      sourceURI: "https://example.invalid/public-domain-scan",
      retrievedOn: "2026-07-26",
      rights: {
        status: "public-domain",
        commercialUse: "permitted",
        redistribution: "permitted",
        statement: "Synthetic validator test fixture; not a real source approval."
      },
      artifacts: [
        {
          locator: "https://example.invalid/public-domain-scan/page-1.tiff",
          bytes: 1,
          sha256: "0".repeat(64)
        }
      ]
    });
  });

  const makeContent = (locale, title, text) => {
    const content = {
      schemaVersion: 1,
      productID: "jingang",
      bookID: "jingangjing",
      editionID: "cbeta-t08n0235-2026r1-reference",
      contentVersion: "test-1",
      contentStatus: "release-canonical",
      locale,
      normalization: "utf8-nfc-lf-v1",
      contentHash: "0".repeat(64),
      volumes: [
        {
          volumeID: "jingang.v000001",
          number: 1,
          order: 0,
          title,
          sourceReferences: [
            {
              sourceID: "jingang.source.public-domain-scan",
              locator: "page:1"
            }
          ]
        }
      ],
      sections: [
        {
          sectionID: "jingang.s000001",
          parentSectionID: null,
          order: 0,
          title,
          sourceReferences: [
            {
              sourceID: "jingang.source.public-domain-scan",
              locator: "page:1"
            }
          ]
        }
      ],
      paragraphs: [
        {
          paragraphID: "jingang.p000001",
          sectionID: "jingang.s000001",
          volumeID: "jingang.v000001",
          order: 0,
          textRole: "sutra",
          text,
          sourceReferences: [
            {
              sourceID: "jingang.source.public-domain-scan",
              locator: "page:1"
            }
          ]
        }
      ]
    };
    content.contentHash = contentHashForPackage(content);
    return content;
  };

  for (const [locale, title, text] of [
    ["zh-Hant", "測試章", "測試正文"],
    ["zh-Hans", "测试章", "测试正文"]
  ]) {
    const path = join(root, `Products/jingang/Content/content-${locale}.json`);
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, `${JSON.stringify(makeContent(locale, title, text), null, 2)}\n`, "utf8");
  }
}

test("validates the checked-in product contracts", async () => {
  const report = await validateRepository({ repositoryRoot });
  assert.equal(report.productCount, 4);
  assert.equal(report.audioArtifactCount, 11);
  assert.equal(report.fixtureCount, 8);
  assert.equal(report.contentPackageCount, 2);
  assert.equal(report.legacyPathMappingCount, 1669);
  assert.equal(report.audioDeliveryCount, 2);
  assert.equal(report.audioBuildInputCount, 1);
  assert.deepEqual(
    report.products.map((product) => product.productID),
    ["jingang", "lengyan", "tanjing", "yuanjue"]
  );
});

test("locks the reviewed Lengyan rendition metadata and stable volume mapping", async () => {
  const audio = JSON.parse(
    await readFile(join(repositoryRoot, "Products/lengyan/audio-artifacts.json"), "utf8")
  );
  const renditions = audio.artifacts.map((artifact) => artifact.renditions[0]);
  assert.equal(
    renditions.reduce((total, rendition) => total + rendition.bytes, 0),
    161420718
  );
  assert.equal(
    renditions.reduce((total, rendition) => total + rendition.durationMilliseconds, 0),
    29121172
  );
  assert.deepEqual([...new Set(renditions.map((rendition) => rendition.codec))], ["mp4a.40.29"]);
  assert.deepEqual([...new Set(renditions.map((rendition) => rendition.sampleRateHertz))], [22050]);
  assert.deepEqual([...new Set(renditions.map((rendition) => rendition.channels))], [2]);
  assert.deepEqual(
    audio.artifacts.slice(0, 10).map((artifact) => artifact.contentMapping.volumeID),
    Array.from(
      { length: 10 },
      (_, index) => `lengyan.v${String(index + 1).padStart(6, "0")}`
    )
  );
  assert.equal(audio.artifacts[10].contentMapping.status, "legacy-unmapped");
});

test("does not allow pending source review to become release eligible", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/jingang/source-manifest.json", (source) => {
      source.reviewStatus = "approved";
      source.releaseEligibility = "eligible";
      for (const approval of Object.values(source.approvals)) {
        approval.status = "approved";
        approval.reviewedBy = "test-reviewer";
        approval.reviewedAt = "2026-07-26T00:00:00Z";
      }
    });
    await expectValidationIssue(root, "eligible source needs a canonical input or transcription base");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects a changed legacy scripture artifact", async () => {
  const root = await makeFixtureRepository();
  try {
    const path = join(root, "lengyan/data/lengyanjing-content.json");
    const raw = await readFile(path, "utf8");
    await writeFile(path, `${raw.trimEnd()} \n`, "utf8");
    await expectValidationIssue(root, "byte count changed");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects duplicate audio artifact identity", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/audio-artifacts.json", (audio) => {
      audio.artifacts[1].artifactID = audio.artifacts[0].artifactID;
    });
    await expectValidationIssue(root, "duplicate audio artifactID");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects drift from the production audio delivery catalog", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/audio-artifacts.json", (audio) => {
      audio.artifacts[0].renditions[0].bytes += 1;
    });
    await expectValidationIssue(root, "byte count differs from delivery catalog");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects audio mapped to a volume outside the content package", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/audio-artifacts.json", (audio) => {
      audio.artifacts[0].contentMapping.volumeID = "lengyan.v999999";
    });
    await expectValidationIssue(root, "maps to an unknown volume");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects an active delivery rendition missing from its artifacts", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/Platform/ios/audio-delivery.json", (delivery) => {
      delivery.selectedRenditionID = "m4a-missing";
    });
    await expectValidationIssue(root, "lacks selected rendition m4a-missing");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects an Apple delivery provider attached to Android", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/Platform/android/audio-delivery.json", (delivery) => {
      delivery.providers = [
        {
          providerID: "invalid-apple-provider",
          kind: "apple-on-demand-resources",
          role: "primary",
          minimumOSMajor: 15,
          maximumOSMajor: 25,
          tagTemplate: "{legacyTrackID}",
          bundleFileTemplate: "{fileName}"
        }
      ];
    });
    await expectValidationIssue(root, "is Apple-specific but linked to android");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects an Android primary that cannot resume byte ranges", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/product.json", (product) => {
      product.platforms.android.state = "development";
    });
    await mutateJSON(root, "Products/lengyan/Platform/android/audio-delivery.json", (delivery) => {
      delivery.state = "development";
      delivery.selectedRenditionID = "m4a-legacy";
      delivery.providers = [
        {
          providerID: "android-primary",
          kind: "https",
          role: "primary",
          minimumOSMajor: 26,
          baseURLConfigurationKey: "AUDIO_BASE_URL",
          artifactKeySource: "rendition",
          activation: "always",
          byteRangeSupport: "unsupported",
          prefetchAllowed: true
        }
      ];
      delete delivery.releaseBlockers;
    });
    await expectValidationIssue(root, "Android primary must support byte ranges");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("does not require new products to define a legacy audio projection", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/Tooling/audio-input.json", (buildInput) => {
      delete buildInput.deliveryManifest;
      delete buildInput.selectedRenditionID;
      delete buildInput.legacyProjection;
    });
    const report = await validateRepository({ repositoryRoot: root });
    assert.equal(report.audioBuildInputCount, 1);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects a semantically incomplete legacy path map even with a valid hash", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/Content/legacy-path-map.json", (legacyMap) => {
      const leaf = legacyMap.paths.find((mapping) => mapping.directParagraphIDs.length > 0);
      leaf.directParagraphIDs = [];
      legacyMap.mappingHash = mappingHashForLegacyMap(legacyMap);
    });
    await expectValidationIssue(root, "direct paragraph mapping differs");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects a legacy map version detached from the content version", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/Content/legacy-path-map.json", (legacyMap) => {
      legacyMap.mappingVersion = "legacy-2";
      legacyMap.mappingHash = mappingHashForLegacyMap(legacyMap);
    });
    await expectValidationIssue(root, "mappingVersion does not match book contentVersion");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects fixture drift from executable naming behavior", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Contracts/BehaviorFixtures/share-file-name.json", (fixture) => {
      fixture.cases[0].expected.fileName = "text.jpg";
    });
    await expectValidationIssue(root, "but contract produces");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects drift from deterministic daily verse selection", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Contracts/BehaviorFixtures/daily-verse-selection.json", (fixture) => {
      fixture.cases[0].expected.selectedID = "p4";
    });
    await expectValidationIssue(root, "but contract produces");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects a featured daily verse paragraph outside the packaged content", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/lengyan/product.json", (product) => {
      product.featuredParagraphIDs.push("lengyan.p999999");
    });
    await expectValidationIssue(root, "featured paragraph lengyan.p999999 is missing");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects a search fixture that points at another result path", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Contracts/BehaviorFixtures/search-text.json", (fixture) => {
      fixture.cases[0].expected.resultPath = "/wrong/path";
    });
    await expectValidationIssue(root, "search result path differs from its source path");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("reports an incomplete matching search fixture without crashing", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Contracts/BehaviorFixtures/search-text.json", (fixture) => {
      fixture.cases[0].expected.snippet = null;
    });
    await expectValidationIssue(root, "search match/result fields disagree");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("detects legacy location fixture drift from the generated map", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Contracts/BehaviorFixtures/legacy-location-resolution.json", (fixture) => {
      fixture.cases[0].expected.sectionID = "lengyan.s999999";
    });
    await expectValidationIssue(root, "but contract produces");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects non-NFC manifest text", async () => {
  const root = await makeFixtureRepository();
  try {
    await mutateJSON(root, "Products/jingang/product.json", (product) => {
      product.titles["zh-Hant"] = "金剛經e\u0301";
    });
    await expectValidationIssue(root, "is not NFC");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects unapproved candidate content even when it is not linked", async () => {
  const root = await makeFixtureRepository();
  try {
    const path = join(root, "Products/jingang/Content/unapproved.json");
    await mkdir(dirname(path), { recursive: true });
    await writeFile(path, "{}\n", "utf8");
    await expectValidationIssue(root, "source-review product contains unapproved content files");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("accepts schema-valid canonical packages only after source and rights approval", async () => {
  const root = await makeFixtureRepository();
  try {
    await configureCanonicalJingang(root);
    const report = await validateRepository({ repositoryRoot: root });
    assert.equal(report.contentPackageCount, 4);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("rejects canonical content that cites only a restricted collation reference", async () => {
  const root = await makeFixtureRepository();
  try {
    await configureCanonicalJingang(root);
    await mutateJSON(root, "Products/jingang/Content/content-zh-Hant.json", (content) => {
      content.paragraphs[0].sourceReferences = [
        {
          sourceID: "jingang.source.cbeta-t08n0235",
          locator: "T08n0235_p0748c01"
        }
      ];
      content.contentHash = contentHashForPackage(content);
    });
    await expectValidationIssue(root, "has no source reference allowed for this content status");
  } finally {
    await rm(root, { recursive: true, force: true });
  }
});

test("canonical content hash ignores object formatting and key insertion order", () => {
  const first = {
    schemaVersion: 1,
    productID: "jingang",
    bookID: "jingangjing",
    editionID: "example-edition",
    contentVersion: "1",
    contentStatus: "release-canonical",
    locale: "zh-Hant",
    normalization: "utf8-nfc-lf-v1",
    contentHash: "0".repeat(64),
    volumes: [
      {
        volumeID: "jingang.v000001",
        number: 1,
        order: 0,
        title: "金剛經",
        sourceReferences: [{ sourceID: "jingang.source.example", locator: "p1" }]
      }
    ],
    sections: [
      {
        sectionID: "jingang.s000001",
        parentSectionID: null,
        order: 0,
        title: "金剛經",
        sourceReferences: [{ sourceID: "jingang.source.example", locator: "p1" }]
      }
    ],
    paragraphs: [
      {
        paragraphID: "jingang.p000001",
        sectionID: "jingang.s000001",
        volumeID: "jingang.v000001",
        order: 0,
        textRole: "sutra",
        text: "如是我聞",
        sourceReferences: [{ sourceID: "jingang.source.example", locator: "p1" }]
      }
    ]
  };
  const reordered = {
    paragraphs: first.paragraphs,
    sections: first.sections,
    normalization: first.normalization,
    locale: first.locale,
    contentStatus: first.contentStatus,
    contentVersion: first.contentVersion,
    editionID: first.editionID,
    bookID: first.bookID,
    productID: first.productID,
    schemaVersion: first.schemaVersion,
    volumes: first.volumes,
    contentHash: "f".repeat(64)
  };
  assert.equal(contentHashForPackage(first), contentHashForPackage(reordered));
});
