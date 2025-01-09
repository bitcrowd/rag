# Rag

<!-- README START -->

A library to make building performant RAG (Retrieval Augmented Generation) systems in Elixir easy.

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

Then, run `mix rag.install --vector-store <vector_store>` to install required dependencies and generate a RAG system that you can further customize to your needs.

Currently supported options for `<vector_store>`:
- `pgvector`
- `chroma`

Brought to you by [bitcrowd](https://bitcrowd.net/en).

![bitcrowd logo](https://github.com/bitcrowd/rag/blob/main/.github/images/bitcrowd_logo.png?raw=true "bitcrowd logo")
<!-- README END -->
