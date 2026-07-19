export const CATALOG_VERSION = "v1";

const entries = [
  ["ly01", "981ed4e96be6bf23694d3ad4dda4958fc987295fa895d229df1138f87674ae5a", 11_408_933],
  ["ly02", "86e26f96f26f51c7d94bb9763ae8da5cdc2d7c29f4e3f963ffbc19629725f472", 14_772_155],
  ["ly03", "b2170f364da0d44dd7b1242c73b784eb0f8243e19946591cbdeee90a7b670d55", 15_582_450],
  ["ly04", "34dbd536f603b32ac4fc0316201cd65fe8fbbee504196470fce2b4ac4fa7c840", 16_602_673],
  ["ly05", "f8669fe34c8bd95093679c7d25e16dfdb72cc8d15601987dbaf49bb3dde6151c", 13_012_100],
  ["ly06", "53ce455f3a20cc09e49f05ae2632fafd8c1c686529d5bf9ecdd32f3465a39828", 14_330_690],
  ["ly07", "c4b879afc23d06fbcf4af2ed81d5b9680797fa0860a0f9804531da95668813a7", 16_483_037],
  ["ly08", "7a31de382ed9bfc523ec4a49792055249d378a32c8d5cde8b8b3bea928b01e96", 15_602_303],
  ["ly09", "a0f8ad5c1cdde15243d150e510368f43d327fe42f5ef1e362e704971cedde801", 21_116_150],
  ["ly10", "e531560f540e74fd3088201de8e164007dfb71434ec55f43d751c92b11feff2c", 16_590_672],
  ["lyz1", "33734314186b1229a08b85169c6b481ed9401cf94ae636f4b36340f11d1db2e0", 5_919_555],
];

export const AUDIO_ASSETS = Object.freeze(Object.fromEntries(entries.map(
  ([id, sha256, bytes]) => {
    const key = `audio/${CATALOG_VERSION}/${sha256}/${id}.m4a`;
    return [
      `/${key}`,
      Object.freeze({ id, sha256, bytes, key }),
    ];
  },
)));
