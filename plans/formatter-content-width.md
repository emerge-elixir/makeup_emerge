# Fix paragraph intrinsic width in Emerge

Supersedes the formatter-only row-layout proposal. Keep paragraph output and automatic wrapping; fix the native measurement inconsistency instead.

## Confirmed cause

The formatter adds U+200B anchors around whitespace. Emerge's paragraph resolve pass removes them before measuring/painting words, but its bottom-up intrinsic pass still measures the raw text leaves, then sums their widths for the paragraph.

Consequently a content-sized wrapper reserves width for invisible anchors. The supplied App example measured approximately 541 px with anchors versus 356 px without them. Explicit shrink attributes did not change this. This is not justification for replacing paragraphs or changing fill/shrink defaults.

## Scope and invariant

For paragraph inline text, intrinsic sizing, wrapping, positioning, and painting must agree about the width of U+200B. It contributes no advance or ink. Real spaces still contribute their normal font-dependent advance; anchor-only blank lines retain inherited font height.

Keep the formatter API, paragraph tree shape, theme styles, inherited fonts, whitespace preservation, and automatic wrapping unchanged. No hardcoded widths, formatter-side font measurement, substitute Unicode characters, hidden measurement overlays, or new layout options.

## Implementation steps

1. Add failing native intrinsic-size tests and an offscreen regression using the supplied App example in its original content-sized `el`, inside a fill-width column.
2. Trace measurement of paragraph-owned direct text and `el`-wrapped text through `measure_element`, text intrinsic caches, and the paragraph aggregation step in `native/emerge_skia/src/tree/layout.rs`.
3. Centralize the existing zero-width handling and apply it consistently when measuring those inline text contributions, not just when building render fragments. Preserve anchors until paragraph whitespace splitting has identified the runs; stripping them before splitting would reintroduce whitespace collapsing.
4. Preserve actual text data and inherited typography. Avoid unrelated changes to text-input cursor indexing, standalone text semantics, ordinary paragraph whitespace behavior, or explicit sizing attributes.
5. Keep measurement caches correct: if measurement depends on paragraph ownership, include that dependency in cache validity and handle reparenting between paragraph and ordinary containers. Check fresh layout against retained relayout after content/font changes.
6. Verify wrapper padding/borders, real trailing spaces, and glyph overhang remain included where required. Correct content width is a layout extent, not necessarily the last visible pixel.

## Regression coverage

- Native tests with deliberately nonzero mock widths for U+200B, proving normalization happens before font measurement.
- Direct and styled `el`-wrapped paragraph text; mixed token styles; repeated/leading/trailing spaces; whitespace-only and anchor-only lines; empty input and trailing newlines.
- Correct intrinsic width propagated through paragraph → column → content-sized `el`.
- Render the supplied App and slide fixtures at multiple inherited font sizes. Compare both text placement and background/container edges against equivalent source without extra anchors. Previous tests constrained the whole block to fill width and missed the error.
- Wide and narrow parents, exact-fit wrapping thresholds, explicit fill overrides, and inherited font/size changes.
- Fresh versus cached/retained layout after text changes and ownership changes. Keep existing indentation and blank-line tests passing.

## Validation

Run Emerge `cargo test` and `mix test`; run makeup_emerge `mix format --check-formatted`, `mix test`, and `mix docs`. Inspect both example renders. Document rebuilding/restarting the native dependency if needed.

Planning only: no implementation changes have been made for this intrinsic-width fix.
