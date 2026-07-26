# Canonical Data Encoding

Version 1 canonical JSON uses the following rules on every platform:

1. UTF-8 without a byte-order mark.
2. Unicode Normalization Form C (NFC) for every key and string value.
3. LF (`U+000A`) line endings. Canonical scripture text does not contain CR.
4. No unpaired surrogates, NUL, or non-text control characters. Tab is not used
   inside scripture text.
5. Source punctuation, variants, headings, and omissions are preserved. Any
   transformation is deterministic, documented, and independently reviewed.
6. Arrays preserve declared order. Display order is an explicit nonnegative
   integer and does not define stable identity.

`contentHash` is SHA-256 over the UTF-8 bytes of a compact deterministic JSON
serialization of the package with the top-level `contentHash` property omitted.
Object keys are recursively sorted in ascending Unicode scalar order; arrays
retain order; strings and integers use RFC 8259 JSON encoding with no optional
whitespace. Contract keys are ASCII, so UTF-8, Unicode-scalar, and ordinal key
sorting produce the same order.

The validator recomputes this value. Pretty-printing a file therefore does not
change its content hash, while text, structure, source references, and ordering
do.
