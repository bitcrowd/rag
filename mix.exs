defmodule Rag.MixProject do
  use Mix.Project

  def project do
    [
      app: :rag,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:chroma, "~> 0.1.3"},
      {:sqlite_vec, github: "joelpaulkoch/sqlite_vec"},
      {:bumblebee, github: "joelpaulkoch/bumblebee", branch: "jina-embeddings-v2-base-code"},
      {:langchain, "~> 0.3.0-rc.0"},
      {:text_chunker, "~> 0.3.1"},
      {:nx, "~> 0.9.0"},
      {:exla, "~> 0.9.1"},
      {:axon, "~> 0.7.0"}
    ]
  end
end
