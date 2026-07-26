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
      locale,
      normalization: "utf8-nfc-lf-v1",
      contentHash: "0".repeat(64),
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
          order: 0,
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
  assert.equal(report.fixtureCount, 3);
  assert.equal(report.contentPackageCount, 0);
  assert.deepEqual(
    report.products.map((product) => product.productID),
    ["jingang", "lengyan", "tanjing", "yuanjue"]
  );
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
    assert.equal(report.contentPackageCount, 2);
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
    await expectValidationIssue(root, "has no approved canonical source reference");
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
    locale: "zh-Hant",
    normalization: "utf8-nfc-lf-v1",
    contentHash: "0".repeat(64),
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
        order: 0,
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
    contentVersion: first.contentVersion,
    editionID: first.editionID,
    bookID: first.bookID,
    productID: first.productID,
    schemaVersion: first.schemaVersion,
    contentHash: "f".repeat(64)
  };
  assert.equal(contentHashForPackage(first), contentHashForPackage(reordered));
});
