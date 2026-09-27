defmodule Makeup.Formatters.Emerge do
  @moduledoc """
  Formats Makeup tokens into Emerge.UI paragraphs containing styled text spans.

  ## Options

    * `:style` — a Makeup theme atom (default `:default_style`) or a
      `Makeup.Styles.HTML.Style` built with `Style.make_style/1`.
    * `:line_height` — optional minimum paragraph height in logical pixels.
      By default line height follows the inherited font's metrics.
    * `:preserve_whitespace` — insert zero-width space anchors around whitespace
      so Emerge paragraphs retain space-only tokens and repeated spaces (default `true`).
      Set to `false` to keep nonempty source text unmodified.
    * `:attrs` — column attributes, overriding defaults (including theme background).
    * `:paragraph_attrs` — paragraph attributes, overriding defaults.

  Each source line becomes a paragraph. Long lines wrap at the available width.
  Unicode and HTML metacharacters are not escaped. By default whitespace is
  surrounded by U+200B anchors to prevent Emerge's paragraph whitespace collapsing.
  LF, CRLF, and CR become paragraph boundaries. Tabs are retained, but Emerge
  paragraphs render them as a single space, not as tab stops.
  Empty input produces one blank paragraph; a trailing newline adds a blank one.
  Blank paragraphs contain an invisible U+200B span to reserve a line using the
  inherited font's metrics.

  Foreground/background colors, bold, italic, underline, and token borders are
  translated from Makeup themes. Token metadata (including HTML hover groups and
  `:selectable`) is ignored. No CSS or JavaScript is generated.

  ## Makeup integration

      el([Font.family("monospace"), Font.size(22)],
        Makeup.highlight(source,
          formatter: Makeup.Formatters.Emerge,
          formatter_options: [style: :monokai_style]
        )
      )

  Font family and size are inherited from the surrounding Emerge UI. This
  formatter does not set them; use parent attributes as in the example above.

  Makeup calls `format_as_binary/2`; despite that callback's name, this formatter
  returns an Emerge.UI element, **not a binary**.
  """

  alias Emerge.UI
  alias Emerge.UI.{Font, Size, Space}
  alias Makeup.Formatters.Emerge.Theme

  @doc "Makeup.highlight/2 callback. Formats tokens into a UI column, not a binary."
  @spec format_as_binary(list(), keyword()) :: UI.t()
  def format_as_binary(tokens, opts \\ []) do
    theme = Theme.resolve(Keyword.get(opts, :style, :default_style))

    attrs =
      [Size.width(Size.fill()), Space.spacing(0)]
      |> Keyword.merge(Theme.background(theme.background_color))
      |> Keyword.merge(Keyword.get(opts, :attrs, []))

    UI.column(attrs, paragraphs(tokens, theme, opts))
  end

  @doc "Returns standalone styled paragraphs, for embedding in your own container."
  @spec format_inner(list(), keyword()) :: [UI.t()]
  def format_inner(tokens, opts \\ []) do
    theme = Theme.resolve(Keyword.get(opts, :style, :default_style))
    paragraphs(tokens, theme, opts)
  end

  defp paragraphs(tokens, theme, opts) do
    paragraph_attrs =
      [Size.width(Size.fill()), Font.color(:black), Font.align_left()]
      |> Keyword.merge(line_height_attrs(opts))
      |> Keyword.merge(Theme.attrs(theme.styles[:text]))
      |> Keyword.merge(Keyword.get(opts, :paragraph_attrs, []))

    styles = Map.new(theme.styles, fn {tag, style} -> {tag, Theme.attrs(style)} end)
    preserve_whitespace = Keyword.get(opts, :preserve_whitespace, true)

    unless is_boolean(preserve_whitespace) do
      raise ArgumentError, "preserve_whitespace must be a boolean"
    end

    {lines, spans, _pending_cr} =
      Enum.reduce(tokens, {[], [], false}, fn {tag, _meta, value}, acc ->
        append_token(value_to_binary(value), Map.get(styles, tag, []), acc)
      end)

    [Enum.reverse(spans) | lines]
    |> Enum.reverse()
    |> Enum.map(fn spans ->
      # A non-whitespace, zero-width glyph gives blank lines inherited font metrics.
      spans = if spans == [], do: [{[], "\u200B"}], else: spans

      spans =
        Enum.map(spans, fn {attrs, value} ->
          value = if preserve_whitespace, do: anchor_whitespace(value), else: value
          UI.el(attrs, UI.text(value))
        end)

      UI.paragraph(paragraph_attrs, spans)
    end)
  end

  # Both lists are built in reverse: no repeated append or random access on BEAM lists.
  defp append_token("", _attrs, state), do: state

  defp append_token(value, attrs, {lines, spans, pending_cr}) do
    # A CRLF pair may straddle lexer token boundaries.
    normalized =
      case {pending_cr, value} do
        {true, "\n" <> rest} -> rest
        _ -> value
      end

    [first | rest] = String.split(normalized, ["\r\n", "\n", "\r"])

    {lines, spans} =
      Enum.reduce(rest, {lines, prepend_span(first, attrs, spans)}, fn part, {lines, spans} ->
        {[Enum.reverse(spans) | lines], prepend_span(part, attrs, [])}
      end)

    {lines, spans, String.ends_with?(value, "\r")}
  end

  defp prepend_span("", _attrs, spans), do: spans
  defp prepend_span(value, attrs, spans), do: [{attrs, value} | spans]

  # Paragraph layout splits on Unicode whitespace, dropping whitespace-only
  # children and collapsing runs. U+200B is a zero-width, non-whitespace glyph:
  # it keeps each authored space between words without changing visible text.
  defp anchor_whitespace(value) do
    String.replace(value, ~r/\s/u, fn space -> "\u200B" <> space <> "\u200B" end)
  end

  # Makeup lexers may emit binaries, Unicode codepoints, or nested chardata.
  defp value_to_binary(value) when is_integer(value), do: <<value::utf8>>
  defp value_to_binary(value), do: IO.chardata_to_string(value)

  defp line_height_attrs(opts) do
    case Keyword.get(opts, :line_height) do
      nil ->
        []

      value when is_number(value) and value > 0 ->
        [Size.height(Size.max(Size.px(value), Size.content()))]

      other ->
        raise ArgumentError, "line_height must be a positive number, got: #{inspect(other)}"
    end
  end
end
