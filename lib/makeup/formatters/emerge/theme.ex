defmodule Makeup.Formatters.Emerge.Theme do
  @moduledoc false

  alias Emerge.UI.{Background, Border, Color, Font}
  alias Makeup.Styles.HTML.{Style, StyleMap, TokenStyle}

  def resolve(%Style{} = style), do: style

  def resolve(name) when is_atom(name) do
    if name in names() do
      apply(StyleMap, name, [])
    else
      raise ArgumentError, "unknown Makeup style: #{inspect(name)}"
    end
  end

  def resolve(other) do
    raise ArgumentError, "expected a Makeup style name or Style struct, got: #{inspect(other)}"
  end

  defp names do
    for {name, 0} <- StyleMap.__info__(:functions),
        String.ends_with?(Atom.to_string(name), "_style"),
        do: name
  end

  def background(value) when value in [nil, ""], do: []
  def background(color), do: [Background.color(color(color))]

  def attrs(nil), do: []

  def attrs(%TokenStyle{} = style) do
    Enum.flat_map(Map.from_struct(style), fn
      {_key, value} when value in [nil, ""] -> []
      {:color, value} -> [Font.color(color(value))]
      {:background_color, value} -> background(value)
      {:border, value} -> [Border.width(1), Border.solid(), Border.color(color(value))]
      {:font_weight, "bold"} -> [Font.bold()]
      {:font_weight, "normal"} -> [Font.regular()]
      {:font_style, value} when value in ["italic", "oblique"] -> [Font.italic()]
      {:font_style, "normal"} -> [font_style: :normal]
      {:text_decoration, "underline"} -> [Font.underline()]
      {:text_decoration, "none"} -> [font_underline: false]
      {:literal, _value} -> []
      {key, value} -> raise ArgumentError, "unsupported Makeup style #{key}: #{inspect(value)}"
    end)
  end

  defp color("#" <> hex) when byte_size(hex) in [3, 6] do
    hex =
      if byte_size(hex) == 3 do
        for <<digit <- hex>>, into: "", do: <<digit, digit>>
      else
        hex
      end

    case Integer.parse(hex, 16) do
      {value, ""} ->
        <<r, g, b>> = <<value::24>>
        Color.color_rgb(r, g, b)

      _ ->
        raise ArgumentError, "invalid Makeup hex color: ##{hex}"
    end
  end

  defp color(value) do
    raise ArgumentError, "expected a #RGB or #RRGGBB Makeup color, got: #{inspect(value)}"
  end
end
