# Rag

A library to make building performant RAG systems in Elixir easy.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `rag` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:rag, "~> 0.1.0"}
  ]
end
```

Then, run `mix rag.install <vector_store>` to install required dependencies and generate a RAG system that you can further customize to your needs.
Currently supported options for `<vector_store>`:
- `pgvector`
- `chroma`
- `sqlite_vec`

Brought to you by bitcrowd.
