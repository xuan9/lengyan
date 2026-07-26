import { createHash } from "node:crypto";

export function stableJSONStringify(value) {
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

export function hashCanonicalDocument(document, omittedTopLevelKey) {
  const payload = structuredClone(document);
  delete payload[omittedTopLevelKey];
  return createHash("sha256").update(stableJSONStringify(payload), "utf8").digest("hex");
}

export function contentHashForPackage(contentPackage) {
  return hashCanonicalDocument(contentPackage, "contentHash");
}

export function mappingHashForLegacyMap(legacyMap) {
  return hashCanonicalDocument(legacyMap, "mappingHash");
}
