defmodule AbsintheRelay.Mixfile do
  use Mix.Project

  @source_url "https://github.com/absinthe-graphql/absinthe_relay"
  @version "1.6.0"

  def project do
    [
      app: :absinthe_relay,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps(),
      xref: [
        exclude: [:ecto]
      ]
    ]
  end

  defp package do
    [
      description: "Relay framework support for Absinthe",
      files: ["lib", "mix.exs", "README*", "CHANGELOG*"],
      maintainers: ["Bruce Williams", "Ben Wilson"],
      licenses: ["MIT"],
      links: %{
        Changelog: "https://hexdocs.pm/absinthe_relay/changelog.html",
        GitHub: @source_url
      }
    ]
  end

  defp docs do
    [
      extras: ["CHANGELOG.md", "README.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:absinthe, ">= 1.7.10"},
      {:ecto, "~> 2.0 or ~> 3.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false}
    ]
  end
end
