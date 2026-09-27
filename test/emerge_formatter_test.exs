defmodule Makeup.Formatters.EmergeTest do
  use ExUnit.Case, async: true

  alias Emerge.Engine.Element
  alias Emerge.UI.{Background, Color, Font, Size, Space}
  alias Makeup.Formatters.Emerge, as: Formatter
  alias Makeup.Styles.HTML.{Style, StyleMap}

  defmodule TestLexer do
    def lex(source, opts), do: [{Keyword.fetch!(opts, :tag), %{}, source}]
  end

  test "highlights Elixir into paragraphs of styled el/text elements" do
    source = "defmodule Hello do\n  IO.puts(\"héllo <&>\")\nend\n"
    tree = Makeup.highlight(source, formatter: Makeup.Formatters.Emerge)

    assert %Element{type: :column, children: paragraphs} = tree
    assert length(paragraphs) == 4
    assert source_text(tree) == source
    assert Enum.all?(paragraphs, &(&1.type == :paragraph))

    spans = Enum.flat_map(paragraphs, & &1.children)

    assert Enum.all?(spans, fn span ->
             match?(%Element{type: :el, children: [%Element{type: :text}]}, span)
           end)

    assert Enum.any?(spans, &Map.has_key?(&1.attrs, :font_color))
    assert Enum.any?(spans, &(&1.attrs[:font_weight] == :bold))
  end

  test "Makeup.highlight uses the formatter and forwards theme options" do
    source = "IO.puts(:hello)"

    assert Makeup.highlight(source,
             formatter: Formatter,
             formatter_options: [style: :monokai_style]
           ) ==
             Formatter.format_as_binary(Makeup.Lexers.ElixirLexer.lex(source),
               style: :monokai_style
             )
  end

  test "accepts registered language names" do
    assert Makeup.highlight("x = 42", formatter: Formatter, lexer: "elixir") ==
             Makeup.highlight("x = 42", formatter: Formatter, lexer: Makeup.Lexers.ElixirLexer)
  end

  test "passes lexer options independently of formatter options" do
    tree =
      Makeup.highlight("custom",
        formatter: Formatter,
        lexer: TestLexer,
        lexer_options: [tag: :keyword],
        formatter_options: [line_height: 28]
      )

    assert source_text(tree) == "custom"
    assert hd(tree.children).attrs.height == {:max, {:px, 28}, :content}
    assert hd(hd(tree.children).children).attrs.font_weight == :bold
  end

  test "format_inner returns standalone styled paragraphs" do
    tokens = [{:text, %{}, "hello\nworld"}]
    paragraphs = Formatter.format_inner(tokens)

    assert paragraphs == Formatter.format_as_binary(tokens).children
    Enum.each(paragraphs, &assert_inherited_fonts/1)
  end

  test "preserves empty input, empty tokens, and consecutive/trailing blank lines" do
    for tokens <- [[], [{:text, %{}, ""}]] do
      assert [%Element{type: :paragraph, children: [span], attrs: attrs}] =
               Formatter.format_as_binary(tokens).children

      assert hd(span.children).attrs.content == "\u200B"
      refute Map.has_key?(attrs, :height)
      assert_inherited_fonts(span)
    end

    tree = Formatter.format_as_binary([{:text, %{}, "\n  first\n\n\nlast\n"}])
    assert Enum.map(tree.children, &text/1) == ["", "  first", "", "", "last", ""]
  end

  test "preserves whitespace, Unicode, and HTML metacharacters without escaping" do
    source = "  \t<&>\"' λ😀  "
    assert source_text(Formatter.format_as_binary([{:text, %{}, source}])) == source
  end

  test "anchors whitespace for paragraph layout, with an opt-out for literal leaf text" do
    tokens = [{:text, %{}, "  a  b"}]
    [paragraph] = Formatter.format_as_binary(tokens).children
    [span] = paragraph.children
    [leaf] = span.children
    assert leaf.attrs.content == "\u200B \u200B\u200B \u200Ba\u200B \u200B\u200B \u200Bb"

    [paragraph] = Formatter.format_as_binary(tokens, preserve_whitespace: false).children
    assert hd(hd(paragraph.children).children).attrs.content == "  a  b"
  end

  test "multiline tokens retain their style on every line" do
    tree = Formatter.format_as_binary([{:comment, %{}, "# one\n# two\n"}])
    [first, second, last] = tree.children
    assert text(first) == "# one"
    assert text(second) == "# two"
    assert text(last) == ""
    assert hd(first.children).attrs == hd(second.children).attrs
    assert hd(first.children).attrs.font_style == :italic
  end

  test "normalizes CRLF and CR, including CRLF across tokens and empty tokens" do
    tokens = [
      {:text, %{}, "a\r"},
      {:text, %{}, ""},
      {:keyword, %{}, "\nb\r\nc\rd\n"}
    ]

    assert source_text(Formatter.format_as_binary(tokens)) == "a\nb\nc\nd\n"
  end

  test "line splitting is independent of lexer token boundaries" do
    for source <- ["", "a\n\nb\n", "a\r\nb\rc\n", "\r\n\r\r\n", "é\tλ"] do
      whole = Formatter.format_as_binary([{:text, %{}, source}])

      split =
        Formatter.format_as_binary(
          for value <- String.to_charlist(source), do: {:text, %{}, value}
        )

      assert source_text(whole) == source_text(split)
    end
  end

  test "supports nested chardata and integer Unicode token values" do
    tokens = [{:text, %{}, ["hé", [32, 955]]}, {:text, %{}, 128_512}]
    assert source_text(Formatter.format_as_binary(tokens)) == "hé λ😀"
  end

  test "unknown token types fall back to the paragraph's text style" do
    theme = theme(%{text: "#123456"})
    tree = Formatter.format_as_binary([{:custom_token, %{}, "value"}], style: theme)
    [paragraph] = tree.children
    assert paragraph.attrs.font_color == Color.color_rgb(18, 52, 86)
    refute Map.has_key?(hd(paragraph.children).attrs, :font_color)
  end

  test "translates styles and Makeup token inheritance, including explicit resets" do
    style =
      theme(%{
        text: "#123",
        string: "bold italic underline #aBc bg:#012345 border:#F00",
        string_doc: "nobold noitalic"
      })

    tokens = [{:string, %{}, "s"}, {:string_doc, %{}, "d"}]
    [paragraph] = Formatter.format_as_binary(tokens, style: style).children
    [string, doc] = paragraph.children

    assert paragraph.attrs.font_color == Color.color_rgb(17, 34, 51)
    assert string.attrs.font_color == Color.color_rgb(170, 187, 204)
    assert string.attrs.background == Color.color_rgb(1, 35, 69)
    assert string.attrs.font_weight == :bold
    assert string.attrs.font_style == :italic
    assert string.attrs.font_underline
    assert string.attrs.border_width == 1
    assert string.attrs.border_color == Color.color_rgb(255, 0, 0)
    assert string.attrs.border_style == :solid
    assert doc.attrs.font_weight == :regular
    assert doc.attrs.font_style == :normal
    assert doc.attrs.font_color == string.attrs.font_color
  end

  test "uses the theme background and allows container/paragraph overrides" do
    tree =
      Makeup.highlight("42", formatter: Formatter, formatter_options: [style: :monokai_style])

    assert tree.attrs.background == Color.color_rgb(39, 40, 34)

    tree =
      Makeup.highlight("42",
        formatter: Formatter,
        formatter_options: [
          style: :monokai_style,
          line_height: 28,
          attrs: [Background.color(:white), Space.padding(12), Size.width(Size.px(400))],
          paragraph_attrs: [Font.size(24)]
        ]
      )

    assert tree.attrs.background == :white
    assert tree.attrs.padding == 12
    assert tree.attrs.width == {:px, 400}
    refute Map.has_key?(hd(tree.children).attrs, :font)
    assert hd(tree.children).attrs.font_size == 24
    assert hd(tree.children).attrs.height == {:max, {:px, 28}, :content}
  end

  test "accepts every bundled Makeup theme and standard token type" do
    tokens = for tag <- Makeup.Token.Utils.standard_token_types(), do: {tag, %{}, "x"}

    for {name, 0} <- StyleMap.__info__(:functions),
        String.ends_with?(Atom.to_string(name), "_style") do
      assert %Element{type: :column} = Formatter.format_as_binary(tokens, style: name)
    end
  end

  test "does not attach HTML metadata or global keys" do
    tokens = [{:name, %{group_id: "group", selectable: false}, "name"}]

    assert Formatter.format_as_binary(tokens) ==
             Formatter.format_as_binary([{:name, %{}, "name"}])
  end

  test "rejects invalid themes and dimensions with useful errors" do
    assert_raise ArgumentError, ~r/unknown Makeup style/, fn ->
      Formatter.format_as_binary([], style: :missing_style)
    end

    assert_raise ArgumentError, ~r/expected a Makeup style name/, fn ->
      Formatter.format_as_binary([], style: "monokai")
    end

    for opts <- [[line_height: 0], [line_height: "16"], [line_height: -1]] do
      assert_raise ArgumentError, ~r/must be a positive number/, fn ->
        Formatter.format_as_binary([], opts)
      end
    end
  end

  test "font family and size are inherited throughout the highlighted subtree" do
    highlighted =
      Makeup.highlight("def hello, do: :world\n\n",
        formatter: Formatter,
        formatter_options: [style: :monokai_style]
      )

    parent = Emerge.UI.el([Font.family("monospace"), Font.size(22)], highlighted)
    assert parent.attrs.font == "monospace"
    assert parent.attrs.font_size == 22
    assert_inherited_fonts(highlighted)
  end

  defp assert_inherited_fonts(element) do
    refute Map.has_key?(element.attrs, :font)
    refute Map.has_key?(element.attrs, :font_size)
    Enum.each(element.children, &assert_inherited_fonts/1)
  end

  defp theme(styles) do
    Style.make_style(
      short_name: "test",
      long_name: "Test",
      background_color: "#fff",
      highlight_color: "#ffc",
      styles: styles
    )
  end

  defp source_text(%Element{type: :column, children: paragraphs}) do
    Enum.map_join(paragraphs, "\n", &text/1)
  end

  defp text(%Element{type: :text, attrs: %{content: content}}),
    do: String.replace(content, "\u200B", "")

  defp text(%Element{children: children}), do: Enum.map_join(children, &text/1)
end
