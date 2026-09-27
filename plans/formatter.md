# Makeup → Emerge formatter

Completed:
- Standalone Mix project in ../makeup_emerge; Hex Makeup ~> 1.2 and Makeup Elixir ~> 1.0, adjacent Emerge checkout.
- Emerge.UI column of paragraphs containing styled el/text spans, one paragraph per source line.
- Bundled Makeup themes, custom Style structs, container/paragraph attrs, and Makeup.highlight integration.
- Multiline tokens, empty lines, CRLF across tokens, Unicode/chardata, and explicit style resets covered.
- Raster testing exposed Emerge's collapsing of repeated and whitespace-only spans. Default U+200B anchoring preserves visible spaces; preserve_whitespace: false opts out. Documented text-leaf changes and tab limitations.
- 21 ExUnit tests pass, including all bundled styles and offscreen raster tests of color, indentation, font inheritance, and blank lines.
- Emerge cargo test passed: 1467 unit tests + 14 integration tests. No Rust changes.
- README includes local setup, tree usage, standalone paragraphs, API options, and limitations.

## Font inheritance

- Removed font_family/font_size formatter options and defaults; inherit from Emerge ancestors.
- Blank lines use an invisible U+200B span to inherit font metrics rather than a fixed minimum. Kept line_height as an optional explicit override.
- Updated examples and added tree/raster tests for inherited fonts and blank-line sizing.
- Validation passed: 21 ExUnit tests, format check, compilation with warnings as errors, and Emerge cargo test.

## API simplification

- Removed the separate MakeupEmerge wrapper module and redundant formatter delegate.
- Exposed Makeup.Formatters.Emerge directly through Makeup.highlight/2.
- Updated examples/tests to use formatter_options and validate the standard Makeup entry point.
- Validation passed: 19 ExUnit tests, format check, compilation with warnings as errors, and Emerge cargo test.
