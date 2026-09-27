# Makeup Emerge

[Makeup](https://hex.pm/packages/makeup) syntax highlighting as **Emerge.UI trees**, not HTML or generated Elixir source strings.

Each source line becomes a `paragraph/2` containing styled `el/2` + `text/1` spans. The full result is a `column/2`, ready to embed in an Emerge render function. Long lines wrap, indentation is retained, and empty lines keep their height.

## Local setup

This project uses Hex dependencies `makeup ~> 1.2` and `makeup_elixir ~> 1.0`, and the adjacent `../emerge-animation` checkout for Emerge. Rustler is included because that local checkout may build its native renderer.

```sh
mix deps.get
mix test
```

In a sibling application, add:

```elixir
{:makeup_emerge, path: "../makeup_emerge"},
{:makeup_elixir, "~> 1.0"}
```

The Elixir lexer is optional for downstream applications; add it explicitly when highlighting Elixir. Other languages require their own Makeup lexer packages. If your application already depends on Emerge, use the same Emerge checkout (with `override: true` on your application's Emerge dependency if needed).

## Highlight source

```elixir
use Emerge.UI

code = ~S"""
defmodule Hello do
  def greet(name), do: "Hello, #{name}!"
end
"""

column([width(fill()), spacing(16)], [
  text("Example"),
  el([Font.family("monospace"), Font.size(22)],
    Makeup.highlight(code,
      formatter: Makeup.Formatters.Emerge,
      formatter_options: [
        style: :monokai_style,
        attrs: [padding(16), Border.rounded(8)]
      ]
    )
  )
])
```

Font family and size are inherited from the surrounding Emerge UI; the formatter does not set either. Use a monospace font family available to your Emerge application. The example's `code` can also be a module attribute or a string loaded from a file. Use a literal `~S` heredoc if the displayed source contains interpolation that should not run in the host application.

## Build your own paragraph container

```elixir
alias Makeup.Formatters.Emerge, as: EmergeFormatter

tokens = Makeup.Lexers.ElixirLexer.lex(code)

column([width(fill()), spacing(0), Font.family("monospace"), Font.size(22)],
  EmergeFormatter.format_inner(tokens,
    style: :default_style,
    paragraph_attrs: [width(fill())]
  )
)
```

Each returned paragraph includes the theme text style and inherits font family and size from its parent. The theme's overall background belongs to the full column; `format_inner/2` leaves the outer background to you.

Conceptually the output is:

```elixir
paragraph([...], [
  el([Font.bold(), Font.color(...)], text("defmodule")),
  el([...], text(" Hello do"))
])
```

## API

Use Makeup's standard entry point:

```elixir
Makeup.highlight(code,
  formatter: Makeup.Formatters.Emerge,
  formatter_options: [style: :monokai_style]
)
```

`Makeup.highlight/2` accepts `lexer: Makeup.Lexers.ElixirLexer` (the default) or a registered name such as `"elixir"`, plus `lexer_options: [...]`. Put Emerge-specific options in `:formatter_options`.

For already-lexed tokens, `Makeup.Formatters.Emerge.format_as_binary/2` returns a column and `Makeup.Formatters.Emerge.format_inner/2` returns a list of paragraphs. Despite Makeup's `format_as_binary/2` callback name, the result is an **Emerge.UI element**, not a binary.

Formatter options:

| Option | Default | Purpose |
| --- | --- | --- |
| `:style` | `:default_style` | Any bundled Makeup theme atom or `Makeup.Styles.HTML.Style` struct |
| `:line_height` | Inherited font metrics | Optional minimum paragraph height in logical pixels, including blank lines |
| `:preserve_whitespace` | `true` | Add invisible anchors to preserve spaces in paragraph layout |
| `:attrs` | `[]` | Override column attrs, including background |
| `:paragraph_attrs` | `[]` | Override paragraph attrs, including font and sizing |

Colors, token backgrounds, bold/normal, italic/normal, underline, and borders are mapped from Makeup themes. Token subtype inheritance is resolved by Makeup's `Style.make_style/1`. Foreground colors support `#RGB` and `#RRGGBB`.

Text is never HTML-escaped. LF, CRLF, and CR become paragraph boundaries, including newlines inside multiline tokens. Trailing newlines and blank input produce blank paragraphs containing an invisible U+200B span. This reserves a line using the inherited font's metrics, without a hardcoded font size or minimum height.

**Native renderer updates:** use the updated Emerge checkout with zero-width paragraph anchor handling. If spaces appear three times too wide with an older native build, run `mix deps.compile emerge --force` in your app and restart it.

**Whitespace:** Emerge paragraphs normally collapse repeated whitespace and discard whitespace-only spans. By default the formatter inserts invisible U+200B anchors around whitespace to keep spaces and indentation visible. This means text leaf strings contain additional invisible characters; keep the original source for copying or editing. Set `preserve_whitespace: false` for unmodified nonempty source text, accepting Emerge's whitespace collapsing; blank-line placeholders still remain. Tabs remain literal tabs, but Emerge paragraphs draw them as a single space, not expanded tab stops; expand tabs in the source beforehand if needed.

HTML-specific metadata such as hover groups and `:selectable` is ignored. This library does not open a window or start a renderer.

## Documentation

```sh
mix deps.get
mix docs
```

Open `doc/index.html` for the generated documentation.

## Tests

```sh
mix format --check-formatted
mix test
```

Tests cover the real Elixir lexer, all bundled Makeup themes, token inheritance, Unicode and whitespace preservation, multiline tokens, customization, and offscreen raster renders covering inherited fonts and blank-line sizing. No display server is required.
