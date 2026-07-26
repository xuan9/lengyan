# Stable ID Rules

Stable IDs identify user-visible content across releases and platforms. They
are assigned once and are not derived from text, position, display locale, or a
hash.

## Version 1 Namespaces

- Product: `lengyan`, `jingang`, `yuanjue`, `tanjing`.
- Volume: `<productID>.vNNNNNN`, for example `lengyan.v000001`.
- Section: `<productID>.sNNNNNN`, for example `jingang.s000001`.
- Paragraph: `<productID>.pNNNNNN`, for example `jingang.p000001`.
- Audio artifact: `<productID>.audio.<assigned-id>`, for example
  `lengyan.audio.ly01`.
- Source: `<productID>.source.<assigned-id>`.

The six-digit volume, section, and paragraph suffix is an allocated identifier,
not an ordinal. Gaps are valid. Deleted IDs are retired permanently and cannot
be reused. Reordering content does not change IDs.

## Revisions And Resegmentation

- Punctuation, typography, and corrected source transcription retain an ID only
  when the passage has the same semantic identity.
- Splitting a paragraph retires the old canonical ID and creates new IDs. A
  versioned migration map records one-to-many replacements.
- Merging paragraphs creates a new ID and records many-to-one replacements.
- A source locator is evidence, not identity. Changing editions does not silently
  transplant old IDs without a reviewed edition migration.

## Lengyan Compatibility

The production app currently persists hierarchy paths such as `/A1/B1/...` in
favorites, reading progress, outline expansion, Widget links, and navigation.
Those strings remain legacy identities until a complete, validated mapping to
version 1 IDs exists. No migration may delete or reinterpret them in place.

New products use version 1 IDs from their first canonical import. They do not
copy Lengyan's hierarchy path scheme or `ly01` audio IDs into their own
namespaces.
