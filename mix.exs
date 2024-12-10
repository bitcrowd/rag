defmodule Rag.MixProject do
  use Mix.Project

  @source_url "https://github.com/bitcrowd/rag"
  @version "0.1.0"

  def project do
    [
      app: :rag,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Rag",
      package: package(),
      docs: docs(),
      description: "A library to make building performant RAG systems in Elixir easy",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.0"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.4", runtime: false},
      {:mimic, "~> 1.10", only: :test},
      {:req, "~> 0.5.0"},
      {:ecto, "~> 3.12", optional: true},
      {:ecto_sql, "~> 3.12", optional: true},
      {:ecto_sqlite3, ">= 0.0.0", optional: true},
      {:pgvector, "~> 0.3.0", optional: true},
      {:chroma, "~> 0.1.3", optional: true},
      {:sqlite_vec, "~> 0.1.0", optional: true},
      {:bumblebee,
       github: "joelpaulkoch/bumblebee", branch: "jina-embeddings-v2", optional: true},
      {:langchain, "~> 0.3.0-rc.0", optional: true},
      {:text_chunker, "~> 0.3.1"},
      {:nx, "~> 0.9.0", optional: true},
      {:exla, "~> 0.9.1", optional: true},
      {:axon, "~> 0.7.0", optional: true}
    ]
  end

  defp package do
    [
      maintainers: ["Joel Koch"],
      licenses: ["MIT"],
      files: ~w(lib mix.exs README.md LICENSE),
      links: %{
        GitHub: @source_url
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        {"README.md", title: "README"}
      ]
    ]
  end
end
