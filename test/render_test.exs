defmodule Makeup.Formatters.Emerge.RenderTest do
  use ExUnit.Case

  alias Emerge.UI
  alias Emerge.UI.{Font, Size, Space}
  alias EmergeSkia.TreeRenderer
  alias Makeup.Formatters.Emerge, as: Formatter
  alias Makeup.Styles.HTML.Style

  test "the generated paragraphs render colored glyphs and preserve a blank line" do
    style =
      Style.make_style(
        short_name: "raster",
        long_name: "Raster test",
        background_color: "#ffffff",
        highlight_color: "#ffffcc",
        styles: %{keyword: "#ff0000"}
      )

    tree =
      Formatter.format_as_binary(
        [{:keyword, %{}, "Hello\n\n"}, {:whitespace, %{}, "  "}, {:keyword, %{}, "Hello"}],
        style: style,
        line_height: 30
      )

    pixels =
      TreeRenderer.render_to_pixels(
        UI.el([Font.family("monospace"), Font.size(20)], tree),
        [otp_app: :makeup_emerge, width: 240, height: 120],
        30_000
      )

    assert byte_size(pixels) == 240 * 120 * 4

    red_rows =
      for <<row::binary-size(960) <- pixels>> do
        for(<<r, g, b, a <- row>>, do: a > 128 and r > 180 and g < 100 and b < 100)
        |> Enum.any?()
      end

    assert red_rows |> Enum.take(30) |> Enum.any?()
    refute red_rows |> Enum.slice(30, 30) |> Enum.any?()
    assert red_rows |> Enum.slice(60, 30) |> Enum.any?()

    assert leftmost_red(binary_part(pixels, 60 * 960, 30 * 960)) >
             leftmost_red(binary_part(pixels, 0, 30 * 960)) + 5
  end

  test "inherited fonts match explicit fonts and blank lines follow font metrics" do
    for family <- ["monospace", "serif"], size <- [12, 28] do
      font_attrs = [Font.family(family), Font.size(size)]
      tokens = [{:text, %{}, "Hello\n\nHello"}]
      inherited = UI.el(font_attrs, Formatter.format_as_binary(tokens))
      explicit = UI.el([], Formatter.format_as_binary(tokens, paragraph_attrs: font_attrs))

      pixels = render(inherited)
      assert pixels == render(explicit)

      # An invisible blank line must occupy the same height as a text line,
      # using the inherited font instead of a fixed pixel minimum.
      contiguous =
        UI.el(font_attrs, Formatter.format_as_binary([{:text, %{}, "Hello\nHello"}]))
        |> render()
        |> ink_tops()

      assert [first, third] = ink_tops(pixels)
      assert [^first, second] = contiguous
      assert_in_delta third - first, 2 * (second - first), 2
    end
  end

  test "spaces use one cell instead of advancing zero-width anchor glyphs" do
    for size <- [12, 22, 32] do
      source = "X\n X\n  X\n   X\nX X\nX  X"
      assert_code_spacing(source, size)
    end
  end

  test "the supplied slide keeps indentation and token spacing identical to plain code" do
    source = File.read!(Path.join(__DIR__, "fixtures/slide.ex.txt"))
    assert_code_spacing(source, 22)
  end

  defp assert_code_spacing(source, size) do
    line_height = 48
    width = 1600
    lines = String.split(source, "\n")
    height = length(lines) * line_height

    theme =
      Style.make_style(
        short_name: "spacing",
        long_name: "Spacing",
        background_color: "#ffffff",
        highlight_color: "#ffffcc",
        styles: %{}
      )

    highlighted =
      Makeup.highlight(source,
        formatter: Formatter,
        formatter_options: [style: theme, line_height: line_height]
      )

    reference =
      UI.column(
        [Size.width(Size.fill()), Space.spacing(0)],
        Enum.map(lines, fn line ->
          UI.el([Size.height(Size.px(line_height))], UI.text(line))
        end)
      )

    frames =
      Enum.map([highlighted, reference], fn tree ->
        UI.el([Size.width(Size.fill()), Font.family("monospace"), Font.size(size)], tree)
        |> TreeRenderer.render_to_pixels(
          [otp_app: :makeup_emerge, width: width, height: height],
          30_000
        )
      end)

    [actual, expected] = Enum.map(frames, &line_extents(&1, width, line_height))

    for {line, {actual, expected}} <- Enum.zip(lines, Enum.zip(actual, expected)) do
      case {actual, expected} do
        {nil, nil} ->
          :ok

        {{left, right}, {expected_left, expected_right}} ->
          assert_in_delta left,
                          expected_left,
                          1,
                          "incorrect indent for #{inspect(line)} at #{size}px"

          assert_in_delta right,
                          expected_right,
                          1,
                          "incorrect spacing for #{inspect(line)} at #{size}px"

        _ ->
          flunk("incorrect line flow for #{inspect(line)}: #{inspect({actual, expected})}")
      end
    end
  end

  defp line_extents(pixels, width, line_height) do
    stride = width * line_height * 4

    for <<line::binary-size(^stride) <- pixels>> do
      {_, left, right} =
        for <<r, g, b, a <- line>>, reduce: {0, width, -1} do
          {i, left, right} ->
            if a > 128 and r < 100 and g < 100 and b < 100 do
              x = rem(i, width)
              {i + 1, min(left, x), max(right, x)}
            else
              {i + 1, left, right}
            end
        end

      if right >= 0, do: {left, right}
    end
  end

  defp render(tree) do
    TreeRenderer.render_to_pixels(
      tree,
      [otp_app: :makeup_emerge, width: 240, height: 120],
      30_000
    )
  end

  defp ink_tops(pixels) do
    for(<<row::binary-size(960) <- pixels>>, do: row)
    |> Enum.map(fn row ->
      for(<<r, g, b, a <- row>>, do: a > 128 and r < 100 and g < 100 and b < 100)
      |> Enum.any?()
    end)
    |> Enum.with_index()
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.flat_map(fn
      [{true, y} | _] -> [y]
      _ -> []
    end)
  end

  defp leftmost_red(pixels) do
    pixels
    |> then(fn pixels -> for <<r, g, b, a <- pixels>>, do: {r, g, b, a} end)
    |> Enum.with_index()
    |> Enum.filter(fn {{r, g, b, a}, _i} -> a > 128 and r > 180 and g < 100 and b < 100 end)
    |> Enum.map(fn {_pixel, i} -> rem(i, 240) end)
    |> Enum.min()
  end
end
