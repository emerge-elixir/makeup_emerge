defmodule MakeupEmerge.MixProject do
  use Mix.Project

  def project do
    [
      app: :makeup_emerge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: "Makeup syntax highlighting as Emerge.UI paragraphs",
      name: "Makeup Emerge",
      docs: [main: "readme", extras: ["README.md"]],
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [
      {:emerge, path: "../emerge-animation"},
      # The local Emerge checkout may need to build its native renderer.
      {:rustler, "~> 0.38.0", runtime: false},
      {:makeup, "~> 1.2"},
      {:makeup_elixir, "~> 1.0", optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end
end
